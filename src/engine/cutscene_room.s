* src/engine/cutscene_room.s
*
* POP CoCo3 — THE PRINCESS'S ROOM, static (P3.17 phase A).
*
* The first thing in this port to run in FOUR-COLOUR mode. Everything up to here —
* the whole static intro — is 16-colour; the cutscene is where the port crosses into
* gameplay's mode, and this program is that crossing with nothing else in it.
*
* ---------------------------------------------------------------
* WHERE THE ROOM COMES FROM, AND WHY IT IS ONE PICTURE
* ---------------------------------------------------------------
* The oracle does not build this room from tiles. cutprincess1 is three lines:
*
*     jsr LoadStage2          ; displaces bgtab1-2, chtab4
*     lda #pacProom
*     jsr SngExpand           ; SINGLE-hires expand
*     ...then copy page 1 to page 2
*
* -- one packed picture, expanded once and copied to both pages. That is the same
* shape as the intro's screens, and it is why the room never redraws: nothing after
* the expand touches it. (It is also why an early attempt to find a "block layout"
* found nothing: there isn't one.)
*
* So the asset is a captured, converted framebuffer, acquired the way P3.2 acquired
* its reference: dumped from the running oracle rather than unpacked out of the game's
* crunch format. CLAUDE.md §2 ranks the execution trace above the source, and it means
* SngExpand never has to be ported.
*
* THE ONE TRAP, AND IT COST A ROUND OF THIS DISPATCH. `mem:read_u8` in MAME reads
* through the CPU program space, which honours the RAMRD soft switch -- and POP sets
* RAMRDaux constantly, so a dump at $2000 returns AUX, where LoadStage2 parks
* bgtab1-2/chtab4. Image tables rendered as a picture look exactly like a broken
* converter. Two objective tests tell them apart and are now in the tooling: row-to-row
* coherence (26.8 for the real page vs 101.5 for the tables) and hires screen-hole
* occupancy (the display never reads those bytes, so they are near-empty on a real
* page). [harness/tools/oracle_ram_dump.lua]
*
* ---------------------------------------------------------------
* THE ASSET
* ---------------------------------------------------------------
* 4-colour is 80 bytes/row x 192 = 15,360 B, half the 16-colour framebuffer. LZ-packed
* it is 4,598 B -- ONE track, against the intro screens' two. That is what forced
* lz_unpack out of intro_seq.s and into a shared module: its old entry derived the
* blob address from a constant sized for 2-track screens. The caller passes the
* pointer now. [src/engine/lz_unpack.s]
* ---------------------------------------------------------------

                include "src/hal.inc"

                ifdef   OBJTARGET
                section prog
                export  room_entry
                import  disk_read_init
                import  disk_read_range
                import  lz_unpack
                else
                org     $0200
                endc

* --- disk_read.s's parameter block, derived from the SAME -DDR_VARBASE the kernel
* --- is assembled with (see intro_seq.s for why this is not an import).
                ifndef  DR_VARBASE
DR_VARBASE      equ     $1F00
                endc
dr_track        equ     DR_VARBASE+0
dr_sector       equ     DR_VARBASE+1
dr_dest         equ     DR_VARBASE+2
dr_status       equ     DR_VARBASE+4
dr_r_track      equ     DR_VARBASE+5
dr_r_count      equ     DR_VARBASE+6

STACK_TOP       equ     $7F00           ; below the $8000 draw window
SECS_PER_TRACK  equ     18
DISK_ROOM_TRK   equ     29              ; clear of the intro's spans and the directory
ROOM_TRACKS     equ     1
DISK_ROOM_SEC   equ     ROOM_TRACKS*SECS_PER_TRACK

* Where the packed blob is read to, as an offset from the framebuffer base: the top of
* the usable draw window ($8000-$FDFF = 32,256 B) less the blob. The window is four
* 8 KB blocks in BOTH modes, so a 15,360 B 4-colour picture leaves far more headroom
* than the 16-colour ones did -- lz_pack reports 16,895 B of in-place slack here
* against 1,535 for the intro screens.
ROOM_LOAD_OFF   equ     32256-ROOM_TRACKS*4608

SAM_SLOW        equ     $FFD8           ; the FDC needs normal speed (§2G disk rule)
SAM_FAST        equ     $FFD9
DSKREG          equ     $FF40

room_entry      jmp     room_start      ; $0200 — EXEC address

probe_status    fcb     0               ; $0203  0=boot 1=mode set 2=room up 3=holding
probe_loads     fcb     0               ; $0204  successful disk reads
probe_dskerr    fcb     0               ; $0205  WD1773 status of the first failure
probe_magic     fdb     0               ; $0206  set once the room is on screen

ROOM_MAGIC      equ     $4B00

room_start
                orcc    #$50            ; mask while the machine comes up
                lds     #STACK_TOP
                clra
                tfr     a,dp

                jsr     HAL_sys_init            ; PIAs, MMU, MC3=1
                jsr     HAL_mem_size_detect
                jsr     HAL_time_init
                andcc   #$EF                    ; opt in to real VBL waits

* THE MODE SWAP. GFX_MODE_320x192x4 is mode 0 and was the HAL's original reference
* mode -- the intro's 16-colour is the newer one. set_mode clears both buffers and
* maps the back one at HAL_gfx_draw_base, so nothing here needs to know block numbers.
                lda     #GFX_MODE_320x192x4
                jsr     HAL_gfx_set_mode
                lda     #1
                sta     probe_status

                jsr     disk_read_init

                ldx     HAL_gfx_draw_base
                leax    ROOM_LOAD_OFF,x         ; the blob lands high in the window
                lda     #DISK_ROOM_TRK
                ldb     #DISK_ROOM_SEC
                jsr     load_tracks
                bne     room_failed

                ldx     HAL_gfx_draw_base
                leau    ROOM_LOAD_OFF,x         ; U -> the blob; X -> the picture
                jsr     lz_unpack               ; expands down over itself

                jsr     HAL_gfx_swap            ; the room appears, in one frame
                lda     #2
                sta     probe_status
                ldd     #ROOM_MAGIC
                std     probe_magic

* Hold. Phase B's torch flicker becomes a per-frame body here; until then the room is
* simply displayed, which is the whole of what phase A claims.
room_hold
                lda     #3
                sta     probe_status
room_loop
                jsr     HAL_time_vbl_wait
                bra     room_loop

room_failed
                lda     dr_status
                sta     probe_dskerr
                bra     room_loop

* ---------------------------------------------------------------
* load_tracks — A = first track, B = sector count, X = destination.
* Returns Z set on success. Carried from intro_seq.s, including the two things that
* file learned the hard way: the FDC must run at NORMAL speed (double speed breaks
* it), and the drive must be RELEASED afterwards or it spins forever.
* ---------------------------------------------------------------
load_tracks
                pshs    cc
                orcc    #$50
                sta     dr_r_track
                stb     dr_r_count
                stx     dr_dest
                clr     lt_err
                sta     SAM_SLOW        ; value irrelevant — the SAM latches on the write
                jsr     disk_read_range
                bcc     lt_ok
                com     lt_err
lt_ok
                clr     DSKREG          ; motor off, no drive selected
                sta     SAM_FAST
                puls    cc
                tst     lt_err
                bne     lt_done
                inc     probe_loads
lt_done
                tst     lt_err
                rts

lt_err          fcb     0
