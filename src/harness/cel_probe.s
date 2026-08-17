* src/harness/cel_probe.s
*
* POP CoCo3 — P1.2 COLOUR SPOT-CHECK TARGET.
*
* NOT ENGINE CODE, NOT THE HAL, NOT A BLITTER. A harness-proof target in the
* same class as loop_probe.s: the smallest program that puts a CONVERTED POP CEL
* on the GIME screen so the P1.1 harness can read the framebuffer back and check
* that the palette indices the converter emitted are the palette indices that
* actually reach the display.
*
* What it does NOT do: transparency, sub-byte shifting, clipping, or any of the
* real blit. It is a byte-aligned rectangular copy. Deliberately — the point is
* to verify the CONVERTER's output end-to-end, not to prototype rendering.
*
* The cel .s is injected at build time:
*   lwasm --decb -DCELFILE=... is not usable for a filename, so build.bat writes
*   build/cel_include.s (a one-line `include` of the chosen cel) and this file
*   includes THAT. One home for the choice: build.bat.
*
* GIME init sequence, framebuffer geometry and VOFFSET constants are identical to
* src/harness/loop_probe.s — see that file's header for the citations. No $0100
* vector block (idiom §14e: a DECB-LOADM'd image must not touch $010C).
* ---------------------------------------------------------------

FB_A_BASE       equ     $8000
FB_B_BASE       equ     $C000
FB_WORDS        equ     $1E00
FB_STRIDE       equ     80              ; 320 px / 4 px per byte
VOFF_A          equ     $F000           ; phys $78000 / 8
BG_FILL         equ     $00             ; clear to black so the cel is unambiguous
PROBE_MAGIC     equ     $CE10

                org     $0200
                setdp   0

cel_entry       jmp     cel_start       ; $0200 — EXEC address

cel_status      fcb     0               ; $0203  0=start 1=running 2=complete
cel_h           fcb     0               ; $0204  cel height  (published for the harness)
cel_w           fcb     0               ; $0205  cel width in bytes
cel_magic       fdb     0               ; $0206  $CE10 when complete

cel_start
                orcc    #$50            ; mask IRQ/FIRQ for the whole run
                clra
                tfr     a,dp

* --- GIME: INIT0 first (framebuffers are ROM territory until MMUEN) ---
                lda     #$6C
                sta     $FF90

* --- clear both frames to BG_FILL ---
                ldx     #FB_A_BASE
                lda     #BG_FILL
                tfr     a,b
                ldy     #FB_WORDS
clr_a           std     ,x++
                leay    -1,y
                bne     clr_a
                ldx     #FB_B_BASE
                ldy     #FB_WORDS
clr_b           std     ,x++
                leay    -1,y
                bne     clr_b

* --- mode 320x192x4, VOFFSET -> frame A, VSCROL/HOFFSET, SAM ---
                ldd     #$8015
                std     $FF98
                ldd     #VOFF_A
                std     $FF9D
                clr     $FF9C
                clr     $FF9F
                clra
                sta     $FFD9
                sta     $FFDF

* --- palette LAST (idiom §9: after the video mode, or it does not take) ---
                ldx     #cel_palette
                ldy     #$FFB0
                ldb     #4
cp_loop         lda     ,x+
                sta     ,y+
                decb
                bne     cp_loop

                lda     #1
                sta     cel_status

* --- publish the cel dims, then copy it to frame A at (0,0) ---
* converted.s layout: fcb H,W then H rows of W bytes.
                ldx     #cel_data
                lda     ,x+
                sta     cel_h           ; H
                lda     ,x+
                sta     cel_w           ; W
                ldy     #FB_A_BASE      ; dest row pointer

                lda     cel_h
                sta     row_ctr
row_loop        ldb     cel_w
                stb     byte_ctr
                pshs    y               ; remember row start
byte_loop       lda     ,x+
                sta     ,y+
                dec     byte_ctr
                bne     byte_loop
                puls    y
                leay    FB_STRIDE,y     ; next scanline
                dec     row_ctr
                bne     row_loop

                lda     #2
                sta     cel_status
                ldd     #PROBE_MAGIC
                std     cel_magic

cel_done        bra     cel_done

row_ctr         fcb     0
byte_ctr        fcb     0

* Palette — same four entries as loop_probe.s, matching the converter's model:
*   0=Black 1=Orange 2=Blue 3=White   (RGB monitor format, CLAUDE.md §4)
cel_palette     fcb     $00             ; 0 Black
                fcb     $26             ; 1 Orange  R=3 G=1 B=0  [karateka MAME-verified RGB, CLAUDE.md §4]
                fcb     $19             ; 2 Blue    R=0 G=2 B=3  [karateka MAME-verified RGB, CLAUDE.md §4]
                fcb     $3F             ; 3 White

cel_data
                include "build/cel_include.s"

                end     cel_entry
