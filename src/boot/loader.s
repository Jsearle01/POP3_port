* src/boot/loader.s
*
* POP CoCo3 - THE STAGE-1 LOADER, and the "loading" screen (P4.46).
*
* ---------------------------------------------------------------
* WHY THIS IS ITS OWN BINARY AND NOT PART OF THE INTRO
* ---------------------------------------------------------------
* ★★★ THE SCREEN'S DATA MUST BE RESIDENT BEFORE THE FIRST DISK READ -- that is what a
* loading screen IS -- so it cannot be fetched from a track like the captions or the cels.
* Measured: the word is 263 B as a patch plus a 16-byte palette, and with this code it
* comes to roughly 430 B.
*
* ★★ THERE IS NO ROOM FOR THAT IN INTROSEQ. link/pop_engine.link's ceiling note is
* measured and blunt -- "prog ending $2487 boots; $2535 image corrupted... treat $2480 as
* the practical limit and do not spend the difference" -- and the intro's prog already ends
* $24FA. Three dispatches (P3.20 twice, P3.22) were spent hunting logic bugs in code that
* was fine, because a LOADM truncated on SIZE presents as a program that misbehaves.
*
* ★ So the loader is LOADM'd on its own, draws the screen, and reads the intro's program
* off a RAW TRACK -- which is the very thing the ceiling note prescribes: "put the code on
* a disk-resident track and reach it through a fixed table, the way the cutscene bundle
* does." INTROSEQ stops being a DECB file, which also takes the disk's file area from 18
* granules to 17 and off the boundary it was sitting on (P4.29's silent ROOM.BIN overwrite).
*
* ---------------------------------------------------------------
* THE HAND-OFF, AND THE ONE THING IT COSTS THE INTRO
* ---------------------------------------------------------------
* ★★★ `seq_start` CALLS `HAL_gfx_set_mode`, WHICH CLEARS BOTH BUFFERS. A loader that draws
* the screen and jumps to `intro_seq_entry` would have it wiped at the hand-off -- visible
* for this loader's own one-track read and then black for the ~27 s of batch reads that are
* the entire reason to want it.
*
* So the intro gains a SECOND ENTRY, `intro_seq_boot`, three bytes, placed AFTER the probe
* block so the harness's `probe_*` offsets do not move -- the same shape as the scene's
* `room_call` at +B, and for the same reason: two callers want genuinely different set-up,
* and one entry with a mode byte would be one routine pretending to be two.
*
* THIS LOADER THEREFORE OWNS THE BOOT: the canonical prefix, the mode, and the palette.
* `intro_seq_boot` resumes at `disk_read_init`, with the machine already up.
*
* ---------------------------------------------------------------
* MEMORY
* ---------------------------------------------------------------
*   $0E00-$1FFF   THIS LOADER. $0E00 is map_overlap_check's floor -- DECB's DBUF0 $0600,
*                 DBUF1 $0700, FAT $0800 and FCBs $094A all sit below it, and P3.4 measured
*                 $0D00 as loading-but-silently-damaged. The intro later reads its music
*                 player to $0A00..$1B97, over this code, long after it has finished.
*   $2000-$24FA   the intro's program, read here from a raw track.
*   $7900-$7D43   the HAL kernel. ★ IDENTICAL to the one inside INTROSEQ by construction --
*                 same object, same link address -- so the intro finds it already resident
*                 and its own kernel segment is never read. kernel_identical_check.py
*                 asserts that relationship for the scene and the same argument holds here.
*   $8000-$FDFF   the draw window.
* ---------------------------------------------------------------

                include "src/hal.inc"

                ifdef   OBJTARGET
                section prog
                export  boot_entry
                import  disk_read_init
                import  disk_read_range
                import  disk_read_motor_off
                endc

* --- the disk driver's parameter block, derived from the SAME -DDR_VARBASE the
* --- kernel was assembled with. lwasm's `export` carries labels but not absolute
* --- `equ` symbols, so this is the one fact that has to be passed to both.
                ifndef  DR_VARBASE
DR_VARBASE      equ     $6A00
                endc
* ★★★ THESE MUST MATCH disk_read.s:77-82 EXACTLY, AND THE FULL BLOCK IS LISTED EVEN
* though this loader only writes four of them -- a partial list is what got this wrong.
* P4.46 hand-typed `dr_status=+0, dr_dest=+3`; the driver has `dr_dest=+2, dr_status=+4`.
* `stx dr_dest` then landed the destination one byte high, so the driver read all 4608
* bytes correctly and wrote them to $??20 -- high byte whatever RAM happened to hold. The
* symptom was a machine that transferred the right byte count and then reset into BASIC.
dr_track        equ     DR_VARBASE+0
dr_sector       equ     DR_VARBASE+1
dr_dest         equ     DR_VARBASE+2
dr_status       equ     DR_VARBASE+4
dr_r_track      equ     DR_VARBASE+5
dr_r_count      equ     DR_VARBASE+6

STACK_TOP       equ     $7F00           ; below the draw window, above the kernel
FB_STRIDE       equ     160             ; 320x192x16: 2 px per byte
SAM_SLOW        equ     $FFD8
SAM_FAST        equ     $FFD9
PALETTE         equ     $FFB0

* Where the intro's program lives on disk and in memory. Both are passed in by
* build.bat so the loader, the raw-track placement and the link script cannot disagree.
                ifndef  INTRO_BASE
INTRO_BASE      equ     $2000
                endc
                ifndef  INTRO_TRK
INTRO_TRK       equ     33
                endc
                ifndef  INTRO_SEC
INTRO_SEC       equ     18              ; one whole track
                endc
* ★ The intro's SECOND entry, past its own set_mode. cutscene_room.s asserts the same kind
*   of offset against its own label; intro_seq.s does the same for this one, so a drift
*   becomes a build error rather than a jump into the middle of probe_magic.
                ifndef  INTRO_BOOT_OFF
INTRO_BOOT_OFF  equ     11
                endc

* ---------------------------------------------------------------
boot_entry
                orcc    #$50            ; mask while the machine comes up
                lds     #STACK_TOP
                clra
                tfr     a,dp            ; DP = 0

* --- the canonical boot prefix, in order [idioms §21a] -----------
                jsr     HAL_sys_init            ; step 0 - PIAs, MMU, MC3=1
                jsr     HAL_mem_size_detect     ; step 1 - discover before allocating
                jsr     HAL_time_init           ; step 2 - $010C VBL handler, VBORD
                andcc   #$EF                    ; opt in to real VBL waits

                lda     #GFX_MODE_320x192x16
                jsr     HAL_gfx_set_mode        ; clears both buffers, maps back @ draw_base

* --- the artwork's palette, not set_mode's diagnostic one --------
* MASKED: sixteen consecutive hardware writes are ONE logical update (idiom §22), and
* AFTER the mode registers, never before (HAL_gfx_init Constraint B / idiom §9).
                pshs    cc
                orcc    #$50
                ldx     #loading_pal
                ldu     #PALETTE
                ldb     #16
bt_pal          lda     ,x+
                sta     ,u+
                decb
                bne     bt_pal
                puls    cc

                bsr     draw_loading
                jsr     HAL_gfx_swap            ; ...and now it is on the screen

* --- the intro's program, off a raw track ------------------------
                jsr     disk_read_init
                ldx     #INTRO_BASE
                lda     #INTRO_TRK
                ldb     #INTRO_SEC
                bsr     load_tracks
                bne     bt_dead

* ★ CHECK WHAT LANDED. A whole-track read ends on RNF by design, so "no error" is a weak
* claim; the intro's entry opens with a JMP. Without this a bad read jumps into whatever is
* at $2000. The intro makes the same check on its music player for the same reason.
                lda     INTRO_BASE
                cmpa    #$7E
                bne     bt_dead
                jmp     INTRO_BASE+INTRO_BOOT_OFF

* No screen, and no pretending: leave the machine stopped rather than run the intro over a
* half-loaded image.
bt_dead         bra     bt_dead

* ---------------------------------------------------------------
* draw_loading - paint the patch into the BACK buffer.
*
* The format is patch_blit's, and deliberately so: the intro already speaks it, the
* generator already emits it, and a second bitmap format would be a second thing to get
* wrong. This is the apply direction only -- nothing is saved, because nothing here is ever
* lifted again. The first intro beat's splash overwrites the whole buffer.
*
*   fdb first_row / fcb n_rows / per row: fcb n_runs, per run: fcb col, len, data*
* ---------------------------------------------------------------
draw_loading
                ldx     #loading_patch
                ldd     ,x++                    ; D = first row
                std     dl_row
                lda     ,x+
                sta     dl_nrows

* ★ THE ROW BASE IS REACHED BY ADDITION, NOT BY A MULTIPLY. The 6809 has MUL, but it is
* 8x8 and a row offset is 91*160 = 14,560 -- so it would need splitting and shifting. This
* runs ONCE, at boot, for 91 iterations of a 5-cycle LEAU; the loop below then steps it by
* one stride per row and never multiplies at all.
                ldu     HAL_gfx_draw_base
                ldy     dl_row
                beq     dl_base_set
dl_base_lp      leau    FB_STRIDE,u
                leay    -1,y
                bne     dl_base_lp
dl_base_set     stu     dl_base

dl_rowlp
                lda     ,x+                     ; runs in this row
                sta     dl_nruns
                beq     dl_rownext              ; a row the word does not touch
dl_runlp
* ★★ THE COLUMN IS ADDED AS 16 BITS, AND THAT IS NOT PEDANTRY. `leau b,u` takes B as a
* SIGNED byte, so any column past 127 would subtract -- and this word starts at byte column
* 67 and runs to 92, which is safe, while a word placed further right would not be. The
* same trap took a walker backwards at P2.7 and cost P3.65 a dispatch; 16-bit costs one
* CLRA.
                ldb     ,x+                     ; byte column
                clra
                addd    dl_base
                tfr     d,u                     ; U -> the run's destination
                lda     ,x+                     ; length in bytes
                sta     dl_len
dl_copy         ldb     ,x+                     ; ...and the run itself
                stb     ,u+
                dec     dl_len
                bne     dl_copy
                dec     dl_nruns
                bne     dl_runlp
dl_rownext
                ldu     dl_base
                leau    FB_STRIDE,u             ; the next row, one stride on
                stu     dl_base
                dec     dl_nrows
                bne     dl_rowlp
                rts

dl_row          fdb     0
dl_base         fdb     0
dl_nrows        fcb     0
dl_nruns        fcb     0
dl_len          fcb     0

* ---------------------------------------------------------------
* load_tracks - A = first track, B = sector count, X = destination.
* Returns Z set on success. The three things this wrapper owns are the same three
* intro_seq.s's copy owns: SAM speed (the FDC cannot keep up at 1.78 MHz), the interrupt
* mask (disk_read_range needs IRQ+FIRQ masked and NMI live), and the carry, which has to
* survive the speed restore. Clobbers A, B, X, U.
* ---------------------------------------------------------------
load_tracks
                pshs    cc
                orcc    #$50
                sta     dr_r_track
                stb     dr_r_count
                stx     dr_dest
                clr     lt_err
                sta     SAM_SLOW        ; value irrelevant - the SAM latches on the write
                jsr     disk_read_range
                bcc     lt_ok
                com     lt_err
lt_ok
                jsr     disk_read_motor_off
                sta     SAM_FAST
                puls    cc
                tst     lt_err
                rts
lt_err          fcb     0

                include "build/gen/loading_data.s"

                ifdef   OBJTARGET
                endsection
                else
                end     boot_entry
                endc
