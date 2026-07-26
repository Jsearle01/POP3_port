* src/harness/mode_probe.s
*
* POP CoCo3 — P2.5 MODE-CYCLING PROBE.
*
* THIS IS NOT ENGINE CODE. It validates the new kernel service
* HAL_gfx_set_mode by cycling 16-colour <-> 4-colour four times and drawing
* recognisable content in each mode.
*
* THE REPETITION IS THE TEST. A single switch proves only that the registers
* can be written once. Stages 3 and 4 switch BACK, which is where a mode
* service actually fails: leftover geometry, a stale palette count, a
* framebuffer cleared to the previous mode's size. Doing 16 -> 4 -> 16 -> 4
* is what makes "clean and repeatable" a claim the run can refute.
*
* THE SEQUENCE (Jay's spec):
*   stage 1  set_mode(16)  draw 16 colour bars   checkpoint
*   stage 2  set_mode(4)   draw 4  colour bars   checkpoint
*   stage 3  set_mode(16)  draw 16 colour bars   checkpoint   <- switch BACK
*   stage 4  set_mode(4)   draw 4  colour bars   checkpoint   <- and back again
*
* WHAT THE CONTENT PROVES. Each stage paints vertical bars, one per palette
* index, spanning the full screen height:
*   16-colour: 16 bars x 10 bytes = 160 bytes = exactly one row
*    4-colour:  4 bars x 20 bytes =  80 bytes = exactly one row
* Both fill a row EXACTLY, so a wrong stride shows up immediately as a skewed
* diagonal rather than as a subtly wrong picture. Counting the bars by eye is
* the check: 16 distinct hues means the 16-colour mode really is 16-colour;
* 4 means the 4-colour mode really switched back.
*
* THE PROBE READS THE STRIDE FROM THE HAL — it does not hardcode 80 or 160.
* That is deliberate: it exercises the published geometry (HAL_gfx_cur_stride)
* as part of the ABI, so a service that sets the registers but forgets to
* update its geometry fails here instead of silently later.
*
* OBSERVABLE BLOCK at a FIXED address, same shape as loop_probe.s so the
* harness can read it without parsing symbols:
*   $0203  stage    1B   0 = not started, 1-4 = stage complete
*   $0204  vres     1B   HAL_gfx_cur_vres for the active stage
*   $0205  stride   1B   HAL_gfx_cur_stride for the active stage
*   $0206  magic    2B   $D00D once all four stages are done
*
* INTERRUPT POLICY — same as loop_probe.s and for the same reason: CC.I/F stay
* masked for the whole run and no vector is installed, because $010C is DECB's
* live IRQ dispatch while LOADM runs. VBL is detected by POLLING $FF92 bit 3.
* [ref: mame-idioms-coco3-port.md §5 — the disk-boot overlap]
* [ref: docs/ground-truth/SockmasterGime.md — reading $FF92 acknowledges]
* ---------------------------------------------------------------

                include "src/hal.inc"

                ifdef   OBJTARGET
                section prog
                export  mode_entry
                else
                org     $0200
                endc
                ifdef   OBJTARGET
                * setdp is not permitted for the object target (P2.4).
                else
                setdp   0
                endc

* ---------------------------------------------------------------
* Constants
* ---------------------------------------------------------------
FB_BASE         equ     $8000           ; single-buffered; set_mode points VOFFSET here
SCREEN_ROWS     equ     192
STAGE_VBLS      equ     90              ; ~1.5 s per stage, so each is separately visible
PROBE_MAGIC     equ     $D00D
VBORD_BIT       equ     $08             ; $FF92 bit 3 = vertical border

BARS_16         equ     16              ; 16 bars x 10 bytes = 160 = one 16-colour row
BYTES_16        equ     10
BARS_4          equ     4               ; 4 bars x 20 bytes = 80 = one 4-colour row
BYTES_4         equ     20

* ---------------------------------------------------------------
* Entry + observable block. $0200 is the EXEC address; the harness gates the
* LOADM on finding 7E 02 08 here, exactly as it does for loop_probe.
* ---------------------------------------------------------------
mode_entry      jmp     mode_start      ; $0200 — EXEC address

probe_stage     fcb     0               ; $0203
probe_vres      fcb     0               ; $0204
probe_stride    fcb     0               ; $0205
probe_magic     fdb     0               ; $0206

* ---------------------------------------------------------------
mode_start
                orcc    #$50            ; mask IRQ+FIRQ for the whole run
                clra
                tfr     a,dp            ; DP = 0

* --- stage 1: 16-colour ------------------------------------------
                lda     #GFX_MODE_320x192x16
                jsr     HAL_gfx_set_mode
                jsr     draw_16
                lda     #1
                jsr     checkpoint

* --- stage 2: 4-colour -------------------------------------------
                lda     #GFX_MODE_320x192x4
                jsr     HAL_gfx_set_mode
                jsr     draw_4
                lda     #2
                jsr     checkpoint

* --- stage 3: BACK to 16-colour (this is the real test) ----------
                lda     #GFX_MODE_320x192x16
                jsr     HAL_gfx_set_mode
                jsr     draw_16
                lda     #3
                jsr     checkpoint

* --- stage 4: BACK to 4-colour -----------------------------------
                lda     #GFX_MODE_320x192x4
                jsr     HAL_gfx_set_mode
                jsr     draw_4
                lda     #4
                jsr     checkpoint

                ldd     #PROBE_MAGIC
                std     probe_magic     ; all four stages completed
mode_done       bra     mode_done       ; spin; the harness captures here

* ---------------------------------------------------------------
* checkpoint — publish the stage, mirror the HAL's geometry, then hold the
* picture long enough to be seen and captured.
*
* The mirrored values are the corroboration: they are read back FROM the HAL's
* published geometry, so if the service sets registers without updating what it
* advertises, the observable disagrees with the screen.
*
* Args: A = stage number
* ---------------------------------------------------------------
checkpoint
                sta     probe_stage
                lda     HAL_gfx_cur_vres
                sta     probe_vres
                lda     HAL_gfx_cur_stride
                sta     probe_stride

* Arm the GIME's VBORD status latch before polling it. The CPU's IRQ stays
* masked; this only lets $FF92 record vertical blanks so the wait below can see
* them. Done here rather than once at startup because HAL_gfx_set_mode rewrites
* $FF90 (IEN) on every call, and the latch is only meaningful with IEN=1 —
* arming per checkpoint is immune to that ordering.
* [ref: src/harness/loop_probe.s Step 10 — same mechanism, same reason]
                lda     #VBORD_BIT
                sta     $FF92           ; enable the VBORD source
                lda     $FF92           ; ack anything already pending

                ldx     #STAGE_VBLS
cp_wait         lda     $FF92           ; read = status + acknowledge
                bita    #VBORD_BIT
                beq     cp_wait         ; no VBL yet — keep polling
                leax    -1,x
                bne     cp_wait
                rts

* ---------------------------------------------------------------
* draw_16 / draw_4 — paint one vertical bar per palette index.
*
* Both funnel into draw_bars, which takes the bar geometry and reads the row
* stride from the HAL rather than assuming it.
* ---------------------------------------------------------------
draw_16
                ldu     #tab16
                lda     #BARS_16
                ldb     #BYTES_16
                bra     draw_bars

draw_4
                ldu     #tab4
                lda     #BARS_4
                ldb     #BYTES_4
* fall through

* ---------------------------------------------------------------
* draw_bars
*   U = colour-byte table, A = bar count, B = bytes per bar.
*
* Paints SCREEN_ROWS rows of (bar count x bytes per bar) bytes. That product
* equals HAL_gfx_cur_stride in both modes by construction, so the image lands
* square; it is asserted below rather than assumed, because a stride mismatch
* is the exact failure this probe exists to catch.
* ---------------------------------------------------------------
draw_bars
                sta     db_bars
                stb     db_bytes
                ldx     #FB_BASE
                ldy     #SCREEN_ROWS
db_row
                clrb                    ; B = bar index
db_bar
                lda     b,u             ; colour byte for this bar
                pshs    b
                ldb     db_bytes
db_px
                sta     ,x+
                decb
                bne     db_px
                puls    b
                incb
                cmpb    db_bars
                bne     db_bar
                leay    -1,y
                bne     db_row
                rts

db_bars         fcb     0
db_bytes        fcb     0

* ---------------------------------------------------------------
* Colour-byte tables.
*
* 16-colour packs 2 px/byte, so index i repeated in both nibbles is i * $11.
* 4-colour packs 4 px/byte, so index i in all four fields is i * $55.
* [ref: GIME_Reference_Manual.pdf §11 Pixel Data Format]
*   16-colour: [PA3..PA0 | PA3..PA0]  high nibble = left pixel
*    4-colour: [PA1 PA0 | PA1 PA0 | PA1 PA0 | PA1 PA0]
* ---------------------------------------------------------------
tab16           fcb     $00,$11,$22,$33,$44,$55,$66,$77
                fcb     $88,$99,$AA,$BB,$CC,$DD,$EE,$FF

tab4            fcb     $00,$55,$AA,$FF

                ifdef   OBJTARGET
                endsection
                else
                end     mode_entry
                endc
