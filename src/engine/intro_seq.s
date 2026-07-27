* src/engine/intro_seq.s
*
* POP CoCo3 — THE INTRO SCREEN SEQUENCER.
*
* One mechanism, driven by data, running both opening credits. P3.2 put a single
* still picture on screen; this turns it into the intro's structure.
*
* ---------------------------------------------------------------
* WHAT THE ORACLE ACTUALLY DOES (traced, not assumed — P3.3)
* ---------------------------------------------------------------
* The dispatch's model was that PubCredit and AuthorCredit are the same routine
* with different content. Reading MASTER.S:693-820 says otherwise, and the
* difference is the whole reason this file is shaped the way it is:
*
*   PubCredit      unpacksplash / setdhires / copy1to2 / tpause 44 /
*                  DeltaExpPop delPresents / PlaySongI / CleanScreen
*   AuthorCredit                            tpause 42 /
*                  DeltaExpPop delByline    / PlaySongI / CleanScreen
*
* AuthorCredit does NOT load a picture. It has no unpacksplash and no copy1to2 --
* it draws its byline straight onto the splash PubCredit left behind, which
* CleanScreen had restored to both pages. **The two credits are not two screens
* with different content. They are one screen with two different captions.**
*
* That is a stronger result than "same structure, different data", because it
* means the base image is stored ONCE. It is also why the descriptor below has a
* base pointer that is allowed to be zero: beat 2 genuinely has no picture of its
* own, and modelling it as though it did would have been a faithful-looking lie
* costing 26,880 bytes the machine does not have.
*
* TitleScreen (MASTER.S:823) is AuthorCredit's shape again -- tpause 38,
* DeltaExpPop delTitle, PlaySongI, CleanScreen. Three beats, one mechanism. The
* generalisation the dispatch asked for exists; it just isn't where the dispatch
* expected to find it.
*
* ---------------------------------------------------------------
* HOW THE CAPTION APPEARS AND DISAPPEARS (traced from the running oracle)
* ---------------------------------------------------------------
* Both transitions are PAGE FLIPS. Neither is a draw the player can see:
*
*   f401  flip to page 2 (the clean copy)   -- the visible page becomes the spare
*   f401-404  the caption is drawn onto page 1, now hidden
*   f405  flip to page 1                    -- the caption APPEARS, in one frame
*   f686  flip to page 2                    -- the caption VANISHES, in one frame
*   f686-697  page 1 is restored underneath (copy2to1)
*   f698  flip to page 1                    -- invisible; the pages are identical
*
* The screen checksum does not move once between f401 and f405 while four frames
* of drawing go on. That is textbook double buffering and it is exactly what P2.6
* built, so this file spends its flips rather than reinventing them.
*
* ONE DEVIATION, deliberate: the oracle restores the hidden page with copy2to1, a
* 16 KB two-bank copy taking 12 frames. Here the caption's own run list is
* replayed against the base image, which touches ~750 bytes and finishes inside a
* frame. Identical result, and it needs no second asset -- see patch_blit.
*
* ---------------------------------------------------------------
* TIMING — measured on screen, not derived from tpause
* ---------------------------------------------------------------
* tpause's units are a doubly-nested delay loop around a keyboard poll; converting
* them to frames means counting cycles through code the port does not run. The
* visible transitions are what has to match, so they were measured directly, and
* the beat table below carries those frame counts. Both machines are 60 Hz NTSC,
* so the numbers transfer 1:1.
*
*   f306 base appears   f405 "Presents" in   f686 out
*                       f782 "Mechner" in    f1065 out
*
* ---------------------------------------------------------------
* THE MEMORY WALL, stated because it shaped the design
* ---------------------------------------------------------------
* Program space is $0200..$77FF, 30,208 bytes. The base image is 26,880 of them.
* Bounding-rectangle captions (2,430 + 1,400) put the assets at 30,710 -- over
* budget before any code. The captions are therefore stored as sparse run lists
* (885 + 687 = 1,572), which is both what fits and what a delta actually is.
* [harness/tools/dhr_delta.py carries the arithmetic]
*
* The next beat, the title, is a much larger patch. This map does not have room
* for the whole intro and is not meant to: assets belong in high physical RAM,
* mapped through the MMU, which is a task of its own.
* ---------------------------------------------------------------

                include "src/hal.inc"

                ifdef   OBJTARGET
                section prog
                export  intro_seq_entry
                else
                org     $0200
                endc
                ifdef   OBJTARGET
                * setdp is not permitted for the object target (P2.4).
                else
                setdp   0
                endc

* ---------------------------------------------------------------
STACK_TOP       equ     $7F00           ; below the $8000 draw window, above the kernel
FB_STRIDE       equ     160             ; 320x192x16: 2 px/byte
SCREEN_ROWS     equ     192
SRC_STRIDE      equ     140             ; 280 virtual px at 4 bits = 140 bytes
LEFT_MARGIN     equ     10              ; 20 px / 2 px-per-byte -> the 280->320 centring
BEAT_SIZE       equ     8
BEAT_COUNT      equ     2
SEQ_MAGIC       equ     $5E92           ; "seq" done

* Beat descriptor — 8 bytes. The intro is DATA in this table, not code.
BEAT_BASE       equ     0               ; base image, or 0 = keep what is on the pages
BEAT_PATCH      equ     2               ; sparse caption patch
BEAT_PRE        equ     4               ; frames the clean base is held first
BEAT_HOLD       equ     6               ; frames the caption stays up

* ---------------------------------------------------------------
intro_seq_entry jmp     seq_start       ; $0200 — EXEC address

probe_status    fcb     0               ; $0203  0=boot 1=base up 2=beat1 3=beat2 4=done
probe_beat      fcb     0               ; $0204  beat index currently running
probe_phase     fcb     0               ; $0205  0=pre 1=caption up 2=cleared
probe_magic     fdb     0               ; $0206

* ---------------------------------------------------------------
seq_start
                orcc    #$50            ; mask while the machine comes up
                lds     #STACK_TOP      ; stack OFF the remapped draw window
                clra
                tfr     a,dp            ; DP = 0

* --- the canonical boot prefix, in order, before anything else ---
* [idioms §21a] Step 0 first, always. Skipping it is the P2.6 interrupt storm;
* hand-rolling any of it is the whole P2.5/P2.6/P2.7 family of failures.
                jsr     HAL_sys_init            ; step 0 — PIAs, MMU
                jsr     HAL_mem_size_detect     ; step 1 — discover before allocating
                jsr     HAL_time_init           ; step 2 — $010C VBL handler, VBORD
                andcc   #$EF                    ; opt in to real VBL waits (E1.c)

* --- the mode the ORACLE uses for the intro, not gameplay's ------
                lda     #GFX_MODE_320x192x16
                jsr     HAL_gfx_set_mode        ; clears both buffers, maps back @ draw_base

* --- the artwork's palette ---------------------------------------
* set_mode installs a diagnostic palette (P2.5) chosen to make the colour COUNT
* visible; this screen needs the Apple DHR palette the art was drawn against.
* Written from engine code because HAL_gfx_set_palette is still a P3 stub -- a
* layering compromise, flagged rather than hidden.
*
* MASKED (idioms §22): sixteen consecutive hardware writes are one logical update
* and an interrupt can observe them half-applied. Same rule that made
* gfx_map_blocks a critical section in P2.9.
*
* AFTER the mode registers, never before: palette writes do not latch until
* $FF98/$FF99 hold their final values (HAL_gfx_init Constraint B).
                pshs    cc
                orcc    #$50
                ldx     #splash_palette
                ldu     #$FFB0
                ldb     #16
sq_pal          lda     ,x+
                sta     ,u+
                decb
                bne     sq_pal
                puls    cc

* --- run the intro -----------------------------------------------
                jsr     seq_run
                lda     #4
                sta     probe_status
                ldd     #SEQ_MAGIC
                std     probe_magic
sq_hold         bra     sq_hold         ; the clean splash stays up; Jay observes here

* ---------------------------------------------------------------
* seq_run — walk the beat table.
*
* THE INVARIANT, which is what makes a beat composable: on entry to every beat
* and on exit from every beat, BOTH buffers hold the clean base image. That is
* what lets beat 2 carry no picture at all — it inherits a guaranteed state
* rather than a hopeful one, exactly as AuthorCredit inherits PubCredit's.
* Clobbers: everything
* ---------------------------------------------------------------
seq_run
                ldx     #beat_table
                clrb
sq_beat
                stb     probe_beat
                pshs    b,x

* -- the base picture, if this beat brings one --------------------
* Drawn into the back buffer, shown, then drawn into the other one, so both
* pages hold it. The oracle's copy1to2; cheaper here because the source is
* resident rather than freshly decompressed.
                ldd     BEAT_BASE,x
                beq     sq_nobase
                std     seq_base
                jsr     blit_base
                jsr     HAL_gfx_swap
                jsr     blit_base
                lda     #1
                sta     probe_status
sq_nobase

* -- hold the clean base ------------------------------------------
                clr     probe_phase
                ldx     1,s             ; the beat pointer. PSHS B,X lays the
*                                       ; stack out low-to-high as B then X, so
*                                       ; the pointer is at 1,S and NOT at ,S.
                ldd     BEAT_PRE,x
                jsr     hold_frames

* -- draw the caption on the HIDDEN page, then reveal it ----------
                ldx     1,s
                ldd     BEAT_PATCH,x
                std     seq_patch
                clr     seq_undo
                jsr     patch_blit
                jsr     HAL_gfx_swap    ; the caption APPEARS, in one frame
* status before phase, so a per-frame observer never samples the pair mid-update
* and see a beat that has not started showing a phase that has.
                ldb     probe_beat
                addb    #2
                stb     probe_status
                lda     #1
                sta     probe_phase

                ldx     1,s
                ldd     BEAT_HOLD,x
                jsr     hold_frames

* -- hide it, then repair the page that carries it ----------------
* The flip is the disappearance. The repair happens afterwards, on the page
* nobody is looking at, which is why it can take as long as it likes.
                jsr     HAL_gfx_swap    ; the caption VANISHES, in one frame
                lda     #2
                sta     probe_phase
                lda     #1
                sta     seq_undo
                jsr     patch_blit      ; same runs, read from the base instead

                puls    b,x
                leax    BEAT_SIZE,x
                incb
                cmpb    #BEAT_COUNT
                blo     sq_beat
                rts

* ---------------------------------------------------------------
* hold_frames — wait D frames.
*
* 16-bit because the captions hold for 281 and 283 frames and HAL_time_delay
* takes a byte. Every wait is a real VBL: CC.I was cleared at boot, without which
* HAL_time_vbl_wait returns immediately and synthesises the count (Q001 N3=beta)
* — the loop still runs, the counters still advance, and the timing is fiction.
* Clobbers: A, B, CC
* ---------------------------------------------------------------
hold_frames
                pshs    y
                tfr     d,y             ; TFR does not touch CC on the 6809
hf_lp           cmpy    #0
                beq     hf_done
                jsr     HAL_time_vbl_wait
                leay    -1,y
                bra     hf_lp
hf_done         puls    y,pc

* ---------------------------------------------------------------
* blit_base — the base picture into the back buffer, centred.
*
* Under the display-faithful asset the virtual-resolution contract collapses to a
* straight copy: a source row is 140 bytes = 280 virtual pixels at 4 bits, and the
* 16-colour mode packs 2 pixels per byte, so 280 virtual pixels are also 140
* framebuffer bytes. The row lands on bytes 10..149 — the +20 px centring — with
* no expansion and no rounding. Margins are left alone; set_mode cleared them.
* Clobbers: A, B, X, Y, U, CC
* ---------------------------------------------------------------
blit_base
                ldx     seq_base
                ldu     HAL_gfx_draw_base
                leau    LEFT_MARGIN,u
                ldy     #SCREEN_ROWS
bb_row          pshs    y
                ldy     #SRC_STRIDE/2   ; 140 bytes = 70 word moves
bb_px           ldd     ,x++
                std     ,u++
                leay    -1,y
                bne     bb_px
                leau    (FB_STRIDE-SRC_STRIDE),u
                puls    y
                leay    -1,y
                bne     bb_row
                rts

* ---------------------------------------------------------------
* patch_blit — apply a sparse caption patch, or undo it.
*
* ONE ROUTINE, TWO SOURCES. seq_undo=0 fills each run from the patch's own pixel
* bytes; seq_undo=1 fills it from the base image instead and steps over them. The
* geometry is walked identically either way, so the repair is guaranteed to cover
* exactly what the caption covered — no second asset, no rectangle to keep in
* sync, and nothing to get wrong independently.
*
* Format [harness/tools/dhr_delta.py]:
*     fdb first_row / fcb n_rows / per row: fcb n_runs, per run: fcb col, len, data*
*
* Base source for framebuffer column C at row R:
*     seq_base + R*SRC_STRIDE + (C - LEFT_MARGIN)
* which is why pb_src is biased by -LEFT_MARGIN once per row and then simply
* indexed by the run's framebuffer column.
* Clobbers: everything
* ---------------------------------------------------------------
patch_blit
                ldx     seq_patch
                ldd     ,x++            ; first row, 16-bit; A is always 0 here
                stb     pb_row          ; rows are 0..191, so the low byte is the row
                lda     ,x+
                sta     pb_nrows
pb_rowlp
                lda     pb_row
                ldb     #FB_STRIDE
                mul                     ; 191*160 = 30,560, comfortably 16-bit
                addd    HAL_gfx_draw_base
                std     pb_dst
                lda     pb_row
                ldb     #SRC_STRIDE
                mul
                addd    seq_base
                subd    #LEFT_MARGIN    ; pre-bias: pb_src + framebuffer col = base byte
                std     pb_src
                lda     ,x+             ; runs in this row
                beq     pb_rownext
                sta     pb_nruns
pb_runlp
                clra
                ldb     ,x+             ; col, 0..159
                stb     pb_col
                addd    pb_dst
                tfr     d,u             ; U = destination
                ldb     ,x+
                stb     pb_len
                tst     seq_undo
                bne     pb_frombase

                ldb     pb_len          ; --- fill from the patch ---
pb_dcp          lda     ,x+
                sta     ,u+
                decb
                bne     pb_dcp
                bra     pb_runnext

pb_frombase                             ; --- fill from the base image ---
                clra
                ldb     pb_col
                addd    pb_src
                pshs    x               ; keep the patch stream pointer
                tfr     d,x
                ldb     pb_len
pb_ucp          lda     ,x+
                sta     ,u+
                decb
                bne     pb_ucp
                puls    x
                ldb     pb_len
                abx                     ; step over the patch's pixel bytes.
*                                       ; ABX is UNSIGNED. `leax b,x` is SIGNED
*                                       ; -128..+127 — the exact trap that sent the
*                                       ; P2.7 probe walking backwards into itself.
pb_runnext
                dec     pb_nruns
                bne     pb_runlp
pb_rownext
                inc     pb_row
                dec     pb_nrows
                bne     pb_rowlp
                rts

* ---------------------------------------------------------------
* State
* ---------------------------------------------------------------
seq_base        fdb     0               ; base image in force for the current beat
seq_patch       fdb     0
seq_undo        fcb     0
pb_row          fcb     0
pb_nrows        fcb     0
pb_nruns        fcb     0
pb_col          fcb     0
pb_len          fcb     0
pb_dst          fdb     0
pb_src          fdb     0

* ---------------------------------------------------------------
* THE INTRO, AS DATA
*
* Frame counts are the measured on-screen transitions (P3.3), not tpause units:
*   beat 1  base up f306, caption in f405 (+99), out f686 (+281)
*   beat 2  caption in f782 (+96 from the clear), out f1065 (+283)
*
* Beat 2's base pointer is 0 on purpose. It is not an omission and not an
* optimisation — AuthorCredit has no unpacksplash. The Mechner byline is a second
* caption on the Broderbund picture.
*
* The third beat is TitleScreen, structurally identical (fdb 0 / delta_title /
* 73 / 536). It is not here because the title patch does not fit in this memory
* map, not because the mechanism cannot express it.
* ---------------------------------------------------------------
beat_table
                fdb     splash_data     ; BEAT_BASE   the Broderbund splash
                fdb     delta_presents  ; BEAT_PATCH  "Broderbund Software Presents"
                fdb     99              ; BEAT_PRE
                fdb     281             ; BEAT_HOLD

                fdb     0               ; BEAT_BASE   none — inherit beat 1's picture
                fdb     delta_byline    ; BEAT_PATCH  "A Game by Jordan Mechner"
                fdb     96              ; BEAT_PRE
                fdb     283             ; BEAT_HOLD

* ---------------------------------------------------------------
* Assets. All three came out of the RUNNING oracle rather than POP's crunch
* format: CLAUDE.md §2 ranks the trace above the source, and it means UNPACK.S's
* 883 lines never have to be ported.
*   splash   — the unpacked double-hires page, converted by dhr_convert.py
*   patches  — the byte differences against it, encoded by dhr_delta.py
* ---------------------------------------------------------------
splash_palette
                includebin "content/intro/broderbund_splash.pal"

splash_data
                includebin "content/intro/broderbund_splash.bin"

delta_presents
                includebin "content/intro/delta_presents.bin"

delta_byline
                includebin "content/intro/delta_byline.bin"

                ifdef   OBJTARGET
                endsection
                else
                end     intro_seq_entry
                endc
