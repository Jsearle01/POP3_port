* src/harness/anim_probe.s
*
* POP CoCo3 — P2.6 DOUBLE-BUFFERED ANIMATION PROBE.
*
* THIS IS NOT ENGINE CODE. It proves HAL_gfx_swap actually double-buffers, in
* BOTH modes, by animating.
*
* WHY A NEW FILE RATHER THAN EDITING mode_probe.s: the P2.5 probe is a
* Jay-gated artifact (25.3 discharged 2026-07-26). Rewriting it would destroy
* the thing that was gated. This extends the same 4-stage cycle with motion.
*
* WHY ANIMATION IS THE ONLY REAL TEST. Static content looks identical whether
* buffering is single, double, or broken. Only motion reveals a tear: a moving
* edge drawn into memory the GIME is scanning shows the frame split across two
* different positions. A byte check cannot see this — double-buffering
* correctness is a TEMPORAL property, so the gate is Jay's eye on live MAME.
*
* THE SEQUENCE (4 stages, one per mode switch, mirroring P2.5's cycle):
*   stage 1  16-colour  animate  stage 3  16-colour  animate   <- switched back
*   stage 2   4-colour  animate  stage 4   4-colour  animate   <- switched back
*
* THE CONTRAST STAGE (stage 5, the "a check that can't fail isn't a check" half):
*   the same animation with the swap DELIBERATELY DEFEATED — drawing straight
*   into the buffer the GIME is displaying. If stages 1-4 look smooth and this
*   one visibly tears, "smooth" is evidence that double-buffering is DOING
*   something rather than evidence that the animation happens to look fine.
*
* THE CC.I TRAP THIS PROBE EXISTS TO NOT FALL INTO:
*   HAL_time_vbl_wait does NOT wait while CC.I is set — it synthesises a counter
*   increment and returns immediately (Q001 N3=beta). So this probe MUST:
*     1. jsr HAL_time_init   -- installs the $010C handler, enables VBORD only
*     2. andcc #$EF          -- CLEAR CC.I; HAL_time_init deliberately will not
*   Get (2) wrong and everything still "works": the loop runs, the counters
*   advance, VOFFSET flips — at arbitrary raster positions, tearing every frame.
*   P2.5's probe hung for the mirror-image reason (polled $FF92 without arming
*   VBORD), which is why this dispatch studied the VBL path before writing code.
*
* STACK: moved to low RAM before any MMU work. The draw window remaps CPU
*   $6000-$DFFF, and DECB's stack sits inside that range — remapping the block
*   the stack lives in pulls the ground out from under the code doing the
*   remapping. $1F00 is in MMU block 0, which is never remapped.
*
* OBSERVABLE BLOCK (fixed addresses, harness reads without parsing symbols):
*   $0203  stage      1B  0 = not started, 1-5 = stage running/complete
*   $0204  vres       1B  HAL_gfx_cur_vres for the stage
*   $0205  stride     1B  HAL_gfx_cur_stride for the stage
*   $0206  magic      2B  $DB16 when all stages are done
*   $0208  swaps      2B  HAL_gfx_swaps snapshot (proves flips happened)
*   $020A  frames     2B  HAL frame counter snapshot (proves VBL IRQ is live)
*   $020C  backidx    1B  HAL_gfx_cur_back at the snapshot
* ---------------------------------------------------------------

                include "src/hal.inc"

                ifdef   OBJTARGET
                section prog
                export  anim_entry
                else
                org     $0200
                endc
                ifdef   OBJTARGET
                * setdp is not permitted for the object target (P2.4).
                else
                setdp   0
                endc

* ---------------------------------------------------------------
PROBE_MAGIC     equ     $DB16           ; "DB" = double buffer, 16 = the mode
STACK_TOP       equ     $1F00           ; MMU block 0 — never remapped
ANIM_FRAMES     equ     150             ; ~2.5 s of motion per stage
SCREEN_ROWS     equ     192
BAR_W           equ     16              ; moving bar width in BYTES
BAR_STEP        equ     4               ; bytes moved per frame

* HAL frame counter, DP $10/$11 [ref: src/hal/coco3-dsk/hal_globals.s]
frame_hi        equ     $10
frame_lo        equ     $11

* ---------------------------------------------------------------
anim_entry      jmp     anim_start      ; $0200 — EXEC address

probe_stage     fcb     0               ; $0203
probe_vres      fcb     0               ; $0204
probe_stride    fcb     0               ; $0205
probe_magic     fdb     0               ; $0206
probe_swaps     fdb     0               ; $0208
probe_frames    fdb     0               ; $020A
probe_backidx   fcb     0               ; $020C

* ---------------------------------------------------------------
anim_start
                orcc    #$50            ; mask while we set up
                lds     #STACK_TOP      ; stack OFF the remapped window (see header)
                clra
                tfr     a,dp            ; DP = 0

* --- STEP 0 OF THE DOCUMENTED INIT ORDER, AND IT IS NOT OPTIONAL ---
* HAL_sys_init disables the PIA interrupt sources (PIA0 $FF01/$FF03 and PIA1
* $FF21/$FF23, bits 0-1). Those bypass the GIME's IRQENR entirely: the PIA
* asserts IRQ on horizontal sync at ~15.7 kHz, and a handler that ACKs only by
* reading $FF92 never clears it. The CPU then re-enters the handler immediately
* after every rti and the main program makes essentially no progress.
*
* MEASURED HERE, by skipping this call: the frame counter advanced normally
* (the VBL path was healthy) while HAL_gfx_set_mode's clear loop never finished
* -- 42% of sampled PCs sat in the ROM -> $010C dispatch path. It looks like a
* hung graphics routine and is actually an interrupt storm.
*
* This is not a new discovery. sys.s records the identical failure from
* karateka's R-boot investigation: "infinite interrupt loop at $0226, 833,172
* times per 30 seconds in MAME. The jsr broderbund_scene never executed."
* [ref: src/hal/coco3-dsk/sys.s — PIA IRQ bypass of GIME IRQENR]
* [ref: src/hal.inc — INIT ORDER, step 0]
                jsr     HAL_sys_init

* --- arm the VBL interrupt, THEN unmask. Both halves are required ---
* HAL_time_init installs the $010C handler, sets $FF93=0 / $FF92=$08 (VBORD
* only) and raises IEN in $FF90. It does NOT touch CC.I -- that is the E1.c
* invariant, and it is why the andcc below is not optional.
                jsr     HAL_time_init
                andcc   #$EF            ; CLEAR CC.I -- real VBL waits from here on

* --- stage 1: 16-colour ------------------------------------------
                lda     #GFX_MODE_320x192x16
                jsr     HAL_gfx_set_mode
                lda     #1
                jsr     run_stage

* --- stage 2: 4-colour -------------------------------------------
                lda     #GFX_MODE_320x192x4
                jsr     HAL_gfx_set_mode
                lda     #2
                jsr     run_stage

* --- stage 3: BACK to 16-colour ----------------------------------
                lda     #GFX_MODE_320x192x16
                jsr     HAL_gfx_set_mode
                lda     #3
                jsr     run_stage

* --- stage 4: BACK to 4-colour -----------------------------------
                lda     #GFX_MODE_320x192x4
                jsr     HAL_gfx_set_mode
                lda     #4
                jsr     run_stage

* --- stage 5: THE CONTRAST — same motion, buffering defeated -----
* 16-colour again, but tear_mode makes the draw target the buffer that is
* CURRENTLY DISPLAYED. Everything else is identical. If 1-4 are smooth and this
* one tears, the smoothness is attributable to the swap and not to luck.
                lda     #GFX_MODE_320x192x16
                jsr     HAL_gfx_set_mode
                lda     #$01
                sta     tear_mode
                lda     #5
                jsr     run_stage
                clr     tear_mode

                ldd     #PROBE_MAGIC
                std     probe_magic
anim_done       bra     anim_done       ; spin; harness/Jay observe here

* ---------------------------------------------------------------
* run_stage — animate one stage.
*   A = stage number.
*
* Each frame: clear the back buffer, draw the bar at the current x, swap.
* The bar sweeps right, wraps, and repeats for ANIM_FRAMES frames.
* ---------------------------------------------------------------
run_stage
                sta     probe_stage
                lda     HAL_gfx_cur_vres
                sta     probe_vres
                lda     HAL_gfx_cur_stride
                sta     probe_stride
                clr     bar_x
                clr     prev_x          ; both buffers start with nothing to erase
                clr     prev_x+1
                ldx     #ANIM_FRAMES
                stx     frame_ctr

rs_loop
                jsr     draw_frame

                lda     tear_mode
                bne     rs_no_swap      ; contrast stage: never flip, so the
                                        ; caller is drawing on the live screen
                jsr     HAL_gfx_swap
                bra     rs_after

rs_no_swap
* Defeat the double buffer honestly: still wait for VBL so the frame RATE
* matches the good stages (otherwise this would just look faster, not torn),
* but never swap -- so every draw lands in the buffer being scanned out.
                jsr     HAL_time_vbl_wait

rs_after
* Publish the observables every frame. These are what let the harness prove the
* mechanism without seeing the screen: swaps advancing, the HAL frame counter
* advancing (so the VBL IRQ is genuinely firing), and which buffer is the target.
                lda     HAL_gfx_swaps_hi
                ldb     HAL_gfx_swaps
                std     probe_swaps
                lda     <frame_hi
                ldb     <frame_lo
                std     probe_frames
                lda     HAL_gfx_cur_back
                sta     probe_backidx

* advance the bar
* Wrap so the bar always FITS: the last legal start is stride - BAR_W. Letting
* bar_x run to stride-1 would spill the bar into the next row, and on the final
* row past the end of the buffer.
                lda     HAL_gfx_cur_stride
                suba    #BAR_W          ; last start that still fits
                ldb     bar_x
                addb    #BAR_STEP
                pshs    a
                cmpb    ,s+
                bls     rs_x_ok
                clrb                    ; wrapped past the right edge
rs_x_ok
                stb     bar_x

                ldx     frame_ctr
                leax    -1,x
                stx     frame_ctr
                bne     rs_loop
                rts

* ---------------------------------------------------------------
* draw_frame — clear the draw target, then paint a vertical bar at bar_x.
*
* In the CONTRAST stage the draw target must be the buffer being DISPLAYED, not
* the hidden one. HAL_gfx_draw_base always maps the hidden buffer, so tear_mode
* maps the OTHER one in first -- the deliberate wrong thing, done explicitly.
* ---------------------------------------------------------------
draw_frame
                lda     tear_mode
                beq     df_draw
* Map the DISPLAYED buffer into the window. cur_back is the hidden one, so the
* displayed one is its opposite.
                lda     HAL_gfx_cur_back
                bne     df_tear_a
                lda     #$18            ; back=A(0) -> displayed is B, block $18
                bra     df_tear_map
df_tear_a
                lda     #$10            ; back=B(1) -> displayed is A, block $10
df_tear_map
                ldx     #$FFA3
                ldb     #4
df_tear_lp
                sta     ,x+
                inca
                decb
                bne     df_tear_lp

df_draw
* --- ERASE the bar this buffer still holds, then draw the new one ---
* Clearing the WHOLE buffer every frame is what makes this too slow to judge:
* 30,720 bytes is ~15,360 STD stores, about 6 frames of CPU at 1.78 MHz, so the
* animation ran at ~6 fps and every swap waited on a VBL that had long passed.
* Erasing only the 16 columns the bar occupied costs ~1/40th of that.
*
* THE SUBTLETY THAT MAKES THIS A DOUBLE-BUFFER PROBLEM: the bar position still
* on screen in THIS buffer is not last frame's, it is the one from TWO frames
* ago -- because the buffers alternate. So the old position is tracked PER
* BUFFER, indexed by HAL_gfx_cur_back. Getting this wrong leaves a trail of
* un-erased bars, which is itself a readable signal that the buffers are
* alternating.
                ldx     #prev_x
                lda     HAL_gfx_cur_back
                leax    a,x             ; A is 0 or 1 -- safely signed
                lda     ,x              ; old bar column in THIS buffer
                sta     paint_x
                clr     paint_col       ; $00 = background
                pshs    x
                jsr     paint_bar
                puls    x

                lda     bar_x
                sta     ,x              ; remember it for this buffer's next turn

* --- paint the bar: BAR_W bytes at bar_x on every row ---
* Colour byte differs per mode so the bar is visible in both: in 16-colour a
* byte is two 4-bit pixels, in 4-colour four 2-bit pixels. $FF is the top index
* in both cases (15 and 3), which is white in both palettes.
*
* OFFSETS GO THROUGH D, NOT A. 6809 accumulator-offset indexing is SIGNED: in
* `leax a,x` the A register is a two's-complement -128..+127 displacement. A
* 16-colour stride of 160 is therefore -96, and the draw pointer walks BACKWARD
* out of the framebuffer and through the kernel. Measured here before the fix:
* the probe completed one swap, then executed at $6001 -- it had overwritten
* itself. `clra / ldb <value> / leax d,x` gives a genuine 0..255 displacement
* because D is a 16-bit signed value and the high byte is zero.
                lda     bar_x
                sta     paint_x
                lda     #$FF            ; top palette index in BOTH modes
                sta     paint_col       ;   (15 in 16-colour, 3 in 4-colour)
                jsr     paint_bar
                rts

* ---------------------------------------------------------------
* paint_bar — fill BAR_W bytes at column paint_x with paint_col, on every row.
* Used for both the draw and the erase, so they can never disagree about
* geometry.
* ---------------------------------------------------------------
paint_bar
                ldx     HAL_gfx_draw_base
                clra
                ldb     paint_x
                leax    d,x             ; X -> first bar byte of row 0
                ldy     #SCREEN_ROWS
pb_row
                pshs    x               ; remember the row's bar start
                lda     paint_col
                ldb     #BAR_W
pb_px
                sta     ,x+
                decb
                bne     pb_px
                puls    x               ; back to the bar start...
                clra
                ldb     HAL_gfx_cur_stride
                leax    d,x             ; ...then down exactly one row
                leay    -1,y
                bne     pb_row
                rts

* ---------------------------------------------------------------
bar_x           fcb     0               ; bar column, in BYTES
frame_ctr       fdb     0               ; frames left in this stage
tear_mode       fcb     0               ; 1 = contrast stage, buffering defeated
paint_x         fcb     0               ; paint_bar: column
paint_col       fcb     0               ; paint_bar: byte value ($FF draw, $00 erase)
prev_x          fcb     0,0             ; last bar column PER BUFFER (index = cur_back)

                ifdef   OBJTARGET
                endsection
                else
                end     anim_entry
                endc
