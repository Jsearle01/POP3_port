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
probe_frames    fcb     0               ; $0208  frames of flicker completed

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

* AND AGAIN INTO THE OTHER BUFFER. The flames are drawn per frame and the page is
* flipped per frame, so BOTH buffers have to hold the room -- otherwise every other
* frame shows a cleared screen. The oracle avoids this by drawing its flames straight
* onto the displayed page (`lay`, a direct hires call) and never flipping for them;
* our HAL maps only the back buffer, so the port flips instead and pays one extra
* one-track read (~1.3 s, once) to make that legal.
                ldx     HAL_gfx_draw_base
                leax    ROOM_LOAD_OFF,x
                lda     #DISK_ROOM_TRK
                ldb     #DISK_ROOM_SEC
                jsr     load_tracks
                bne     room_failed
                ldx     HAL_gfx_draw_base
                leau    ROOM_LOAD_OFF,x
                jsr     lz_unpack

                lda     #2
                sta     probe_status
                ldd     #ROOM_MAGIC
                std     probe_magic

* ---------------------------------------------------------------
* PHASE B — the torch flicker.
*
* The room is a still picture; the two torch flames are the only thing that moves,
* and they move EVERY frame. In the oracle `pburn` is called twice per frame and
* advances one torch each time, round-robin over a 2-entry table:
*
*     ptorchx     db 13,25,-1     ; byte columns, -1 ends the list
*     ptorchoff   db 0,6          ; SUB-BYTE offsets
*     ptorchy     db 113,113
*     ptorchstate db 1,6          ; initial flame frames
*
* Pixel X = ptorchx*7 + ptorchoff = 91 and 181, which under the 280->320 centring
* land at CoCo pixel 111 and 201 -- byte 27.75 and byte 50.25. MEASURED against the
* running oracle, the flames flicker in columns 27-29 and 50-51 and in rows 104-113,
* which confirms both the arithmetic and that ptorchy is the BASELINE: a 13-row cel
* ending at 113 starts at 101.
*
* SUB-BYTE IS ROUNDED, DELIBERATELY AND VISIBLY. A compiled sprite is byte-granular
* by construction, so torch 0 is placed at byte 28 (1 px right of true) and torch 1
* at byte 50 (1 px right). One pixel each. Doing better means pre-shifted phase
* variants, which is exactly what the parallel sub-byte recon exists to cost -- this
* does not pre-empt it.
* ---------------------------------------------------------------
                jsr     ps_savebg               ; the room under each star, once

                ldx     #FLAME_BASE             ; the flame code, off its own track
                lda     #DISK_FLAME_TRK
                ldb     #DISK_FLAME_SEC
                jsr     load_tracks
                bne     room_failed

room_hold
                lda     #3
                sta     probe_status
room_loop
                jsr     flicker
                jsr     HAL_time_vbl_wait
                inc     probe_frames
                bra     room_loop

room_failed
                lda     dr_status
                sta     probe_dskerr
room_dead
                jsr     HAL_time_vbl_wait
                bra     room_dead

* ---------------------------------------------------------------
* flicker — advance and redraw both torches, once per frame.
*
* Unrolled rather than looped over a table. There are exactly two torches, at fixed
* positions, forever; a loop here buys nothing and costs index arithmetic on every
* access, which is precisely where a first draft of this went wrong.
*
* Per torch the order is ERASE(previous) -> SAVE(new) -> DRAW(new). The save cannot
* be hoisted out of the loop even though the background never changes, because each
* cel has its OWN footprint: erase_flameN restores exactly the bytes save_flameN
* captured, so a save taken for one cel does not serve another.
* ---------------------------------------------------------------
* ---------------------------------------------------------------
* THE RATE. Measured on the running oracle, its flames change every 2-3 video frames
* under SPEED 7 and every 6 under SPEED 12 -- mean 2.6 frames, 22.8 Hz. The port
* redraws every frame, which is 60 Hz and 2-6x too fast; Jay saw it immediately.
*
* `play` is the reason: its loop is `pause SPEED` then NextFrame/FrameAdv, so ONE
* engine frame spans many video frames and everything the engine animates -- flames,
* stars, characters -- steps at that rate, not at the display's.
*
* So the STATE advances once every FLAME_DIV frames while the DRAW still happens every
* frame. Those have to stay separate: the page flips every frame, so a buffer that is
* not redrawn shows a stale flame. Skipping the draw would flicker between two states
* at 30 Hz, which is the opposite of the fix.
* ---------------------------------------------------------------
FLAME_DIV       equ     3               ; ~20 Hz, the oracle's SPEED-7 cadence

flicker
                dec     fl_div
                bne     fl_nostep
                lda     #FLAME_DIV
                sta     fl_div
                inc     fl_step         ; this frame advances the state
fl_nostep
* slot = buffer parity * 2 + torch. Each of the four slots owns a peel buffer and a
* "cel last drawn there", because a buffer is redrawn only every other frame and its
* erase must restore what was saved INTO IT, not into its twin.
                ldb     fl_buf
                lslb                            ; slot base for this buffer
                stb     fl_slot

                ldd     #TORCH0_OFF
                std     t_off
                lda     fl_slot
                jsr     slot_peel
                std     t_peel
                lda     fl_slot
                ldx     #fl_prev
                lda     a,x
                sta     t_prev
                lda     fl_state0
                tst     fl_step
                beq     fl_keep0
                jsr     next_flame
                sta     fl_state0
fl_keep0
                jsr     torch_step
                ldb     fl_slot
                ldx     #fl_prev
                abx
                sta     ,x

                ldd     #TORCH1_OFF
                std     t_off
                lda     fl_slot
                inca
                jsr     slot_peel
                std     t_peel
                lda     fl_slot
                inca
                ldx     #fl_prev
                lda     a,x
                sta     t_prev
                lda     fl_state1
                tst     fl_step
                beq     fl_keep1
                jsr     next_flame
                sta     fl_state1
fl_keep1
                jsr     torch_step
                ldb     fl_slot
                incb
                ldx     #fl_prev
                abx
                sta     ,x

                jsr     pstars                  ; and the window
                clr     fl_step
                jsr     HAL_gfx_swap            ; show this frame's flames
                lda     fl_buf
                eora    #1
                sta     fl_buf
                rts

* slot_peel — A = slot 0..3; returns D = that slot's peel buffer address.
slot_peel
                ldb     #PEEL_BYTES
                mul                             ; D = slot * PEEL_BYTES
                addd    #peel_base
                rts

* torch_step — A = the new STATE (0..17). Erases whatever is there, then draws the
* cel this state selects. Returns A = the cel number, for the caller to remember as
* the next frame's "previous".
torch_step
                pshs    a
                ldy     #ptorchflame
                lda     a,y                     ; state -> cel number 1..9
                sta     t_cel
                puls    a

                lda     t_prev                  ; erase what the last frame drew
                beq     ts_nosave               ; 0 = nothing drawn yet
                ldx     #erase_tab      ; a disk-resident table
                jsr     torch_call
ts_nosave
                lda     t_cel
                sta     t_prev
                ldx     #save_tab               ; capture the background this cel covers
                jsr     torch_call
                ldx     #draw_tab
                jsr     torch_call
                lda     t_cel
                rts

* torch_call — X = one of the three dispatch tables; t_cel selects the entry.
* The compiled routines take U = the cel origin in the framebuffer and Y = the peel
* cursor, so placing a sprite is setting U. [harness/tools/sprite_compiler.py]
torch_call
                pshs    x
                ldd     HAL_gfx_draw_base
                addd    t_off
                tfr     d,u                     ; U -> the cel origin
                ldy     t_peel                  ; Y -> this torch's peel slot
                puls    x
                lda     t_cel
                deca                            ; cels are 1..9; the tables are 0-based
                lsla                            ; two bytes per entry
                ldx     a,x
                jmp     ,x                      ; tail-call; the cel routine rts's

* ---------------------------------------------------------------
* pstars — the four stars outside the princess's window. [SUBS.S:360 pstars]
*
* Each frame: count down any lit star and put it out when it expires, then roughly
* one frame in 25 light a RANDOM star for 5-8 frames. So the window is mostly dark
* with occasional single points -- the oracle's own rates, ported.
*
* NOT compiled sprites, and deliberately. A star is ONE PIXEL: cels $2A/$2B convert
* to a single byte $10, one pixel of colour 1. A compiled sprite would be three
* generated routines and a dispatch to write one byte. The flames earn that machinery
* (13 rows, 9 cels, mixed RMW throughout); a star does not.
*
* The background under each star never changes, so it is saved ONCE and the star is
* just a masked write over it -- which also makes "erase" exact by construction.
* Both buffers converge because every frame redraws all four into the back buffer.
* ---------------------------------------------------------------
STAR_MASK       equ     $CF             ; clear sub-pixel 1 (bits 5-4)
STAR_LIT        equ     $10             ; ...and set it to colour 1

* ps_savebg — capture the room byte under each star. Called once, after the room is
* up and before any star is drawn, so "erase" is exact rather than approximate.
ps_savebg
                ldx     #0
ps_sloop
                pshs    x
                tfr     x,d
                lslb
                ldy     #star_off
                ldd     b,y
                addd    HAL_gfx_draw_base
                tfr     d,y
                lda     ,y
                puls    x
                sta     star_bg,x
                leax    1,x
                cmpx    #4
                blo     ps_sloop
                rts

pstars
                tst     fl_step                 ; engine-paced, like the flames
                bne     ps_run
                jmp     ps_draw                 ; redraw, but do not age or light
ps_run
                ldx     #0
ps_age
                lda     star_cnt,x              ; age the lit ones
                beq     ps_agenext
                deca
                sta     star_cnt,x
ps_agenext
                leax    1,x
                cmpx    #4
                blo     ps_age

                jsr     rnd                     ; a new twinkle? ~1 frame in 25
                cmpa    #10
                bhs     ps_draw
                jsr     rnd
                anda    #3
                adda    #5                      ; lit for 5..8 frames
                sta     ps_dur
                jsr     rnd
                anda    #3                      ; which of the four
                tfr     a,b
                ldx     #star_cnt
                abx
                lda     ps_dur
                sta     ,x

ps_draw
                ldx     #0
ps_dloop
                lda     star_bg,x               ; the room, under this star
                ldb     star_cnt,x
                beq     ps_dark
                anda    #STAR_MASK              ; lit: overwrite the one pixel
                ora     #STAR_LIT
ps_dark
                sta     ps_val
                pshs    x
                tfr     x,d                     ; B = star index 0..3
                lslb                            ; the offset table is 16-bit
                ldy     #star_off
                ldd     b,y
                addd    HAL_gfx_draw_base
                tfr     d,y                     ; Y -> this star's byte
                lda     ps_val
                sta     ,y
                puls    x
                leax    1,x
                cmpx    #4
                blo     ps_dloop
                rts

* ---------------------------------------------------------------
* next_flame — the oracle's GETFLAMEFRAME, ported. [MOVER.S:1084]
* A = current state; returns the next. A random draw below torchLast+1 JUMPS to that
* state (18 of 256 draws); otherwise it steps by one and wraps. So the flicker is
* mostly the designed 18-entry pattern with occasional jumps -- which is what makes
* it read as fire rather than as noise.
* ---------------------------------------------------------------
next_flame
                sta     fl_tmp
                jsr     rnd
                cmpa    fl_tmp
                beq     nf_step
                cmpa    #TORCHLAST+1
                blo     nf_done                 ; use the random state directly
                lda     fl_tmp
nf_step
                inca
                cmpa    #TORCHLAST+1
                blo     nf_done
                clra                            ; wrap
nf_done
                rts

* rnd — 8-bit xorshift. The oracle has its own generator and nothing here depends on
* matching its sequence, only on the jump happening at about the same RATE.
rnd
                lda     rnd_seed
                lsla
                bcc     rnd_no
                eora    #$1D
rnd_no
                sta     rnd_seed
                rts

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

* ---------------------------------------------------------------
* Torch data and state
* ---------------------------------------------------------------
TORCHLAST       equ     17              ; states 0..17 [MOVEDATA.S:42 torchLast]
FB_STRIDE_4C    equ     80              ; 320 px at 4 px/byte
FLAME_TOP       equ     101             ; ptorchy 113 is the BASELINE; 13 rows up
TORCH0_COL      equ     28              ; true px 111 -> byte 27.75, rounded
TORCH1_COL      equ     50              ; true px 201 -> byte 50.25, rounded
TORCH0_OFF      equ     FLAME_TOP*FB_STRIDE_4C+TORCH0_COL
TORCH1_OFF      equ     FLAME_TOP*FB_STRIDE_4C+TORCH1_COL
PEEL_BYTES      equ     26              ; 13 rows x 2 bytes — one cel's footprint

* The flames are a DISK-RESIDENT code bundle, not part of this program. A LOADM'd
* engine has to stay under $25FF -- above it is BASIC's program/variable area, which
* is DECB's own workspace -- and nine compiled cels put the image at $2C5A, at which
* point LOADM never returns. Measured: the text screen showed the command with no
* "OK", first segment in memory, second absent. So the flames go on a raw track and
* are read at run time, exactly as the intro reads every screen it shows.
* [src/engine/flame_cels.s, link/pop_flames.link]
FLAME_BASE      equ     $0A00
draw_tab        equ     FLAME_BASE+0
save_tab        equ     FLAME_BASE+18
erase_tab       equ     FLAME_BASE+36
DISK_FLAME_TRK  equ     30
DISK_FLAME_SEC  equ     1*SECS_PER_TRACK

* The oracle's flame pattern, verbatim. 18 states over 9 cels; the repeats and the
* out-of-order tail are what give the flicker its rhythm. [GAMEBG.S:150 ptorchflame]
ptorchflame     fcb     1,2,3,4,5,6,7,8,9,3,5,7,1,4,9,2,8,6

* Initial states are the oracle's too [SUBS.S:309 ptorchstate db 1,6] — the two
* torches start out of phase, which is why they never flicker in lockstep.
fl_state0       fcb     1
fl_state1       fcb     6
fl_buf          fcb     0               ; which buffer this frame draws into
fl_slot         fcb     0
fl_prev         fcb     0,0,0,0         ; cel last drawn, per (buffer, torch) slot
fl_tmp          fcb     0
rnd_seed        fcb     $A5             ; any non-zero seed; the shift register dies at 0

* The stars. starx=2 is an Apple BYTE column, so mono px 14 -> CoCo px 34; cel $2A
* trims one leading byte and $2B does not, which puts them at framebuffer bytes 9 and
* 8. stari 2a,2b,2b,2a and stary $62,$65,$6D,$72. [GAMEBG.S:113-115]
star_off        fdb     98*80+9,101*80+8,109*80+8,114*80+9
star_cnt        fcb     0,0,0,0         ; frames left lit
star_bg         fcb     0,0,0,0         ; the room byte under each, saved once
ps_dur          fcb     0
ps_val          fcb     0
fl_div          fcb     FLAME_DIV
fl_step         fcb     0

t_off           fdb     0               ; the torch being stepped: framebuffer offset,
t_peel          fdb     0               ;   peel slot,
t_cel           fcb     0               ;   cel to draw,
t_prev          fcb     0               ;   cel to erase

peel_base       rmb     PEEL_BYTES*4    ; one per (buffer, torch) slot



