* src/engine/char_probe.s
*
* POP CoCo3 - THE FIRST CHARACTER ON A GAMEPLAY SCREEN (P5.28).
*
* Draws the list char_probe_plan.py generates from content/chars/probe_place.json onto the
* back buffer, after tile_probe.s has drawn LEVEL0 screen 1 there. Linked ONLY into the
* character probe (build.bat's -DCHAR_PROBE build of tile_probe.s); the tile probe that ships
* on probe.dmk does not see this file.
*
* ★ WHAT THIS EXERCISES, AND WHAT IT DOES NOT. The bake (content/chars), the registry
* (char_cels.s, apple_w read HERE at run time), the transform (xf_blit) and the placement
* arithmetic a mirrored draw needs -- over a real background, into a real framebuffer.
* Not motion, not clipping (xf_blit has none; the plan places every frame clear of the
* edges), and NOT PLANE ORDERING: the page is one flattened opaque pass (tile_probe.s's
* header), and the plan places every frame clear of the foreground rectangles, so a correct
* back/fore split would draw the same picture. That is the limit of the claim.
*
* ---------------------------------------------------------------
* THE PLACEMENT ARITHMETIC (P5.20 §3B, and xform_probe_gen.cel_cases, which proved it)
* ---------------------------------------------------------------
* A draw names the REFERENCE's frame: byte column `col`, phase k, facing f, bottom row yco.
*   top    = yco - rows + 1                     rows from the stream's own header
*   f = 0  X = base + top*80 + col,   A = k,   B = 0
*   f = 1  the routine reverses all 4*w0 px of the stored frame, the bake's mirror the
*          7*apple_w it converted, so the routine's frame sits d = 4*w0 - 7*apple_w px left:
*          p = 4*col + k - d = 4*col + k + 7*apple_w - 4*w0
*          X = base + top*80 + p/4,   A = p mod 4,
*          B = 1 | (2 if 7*apple_w is even)    -- the blue<->orange swap, i.e. apple_w even
* ---------------------------------------------------------------

                ifdef   OBJTARGET
                section prog
                export  char_probe_draw
                import  xf_blit
                endc

                include "src/hal.inc"

* entry: +0 stream, +2 &apple_w, +4 yco, +5 col, +6 phase, +7 facing
CP_ENT          equ     8

char_probe_draw
                ldu     #cp_list
                stu     cp_cur
cp_next
                ldu     cp_cur
                ldx     ,u                      ; the stream
                lbeq    cp_done
                lda     ,x                      ; rows
                sta     cp_rows
                lda     1,x                     ; w0
                sta     cp_w0
                lda     [2,u]                   ; apple_w, from the registry
                sta     cp_aw
* --- dst = draw base + top * 80 ---
                lda     4,u                     ; yco
                suba    cp_rows
                inca                            ; top
                ldb     #80
                mul
                addd    HAL_gfx_draw_base
                std     cp_dst
                tst     7,u
                bne     cp_mir
* --- facing 0: the reference's frame IS the routine's ---
                ldb     5,u
                clra
                addd    cp_dst
                tfr     d,x
                lda     6,u                     ; k
                clrb
                bra     cp_call
* --- facing 1: p = 4*col + k + 7*apple_w - 4*w0 ---
cp_mir
                ldb     5,u
                clra
                lslb
                rola
                lslb
                rola
                std     cp_p                    ; 4*col
                ldb     6,u
                clra
                addd    cp_p
                std     cp_p                    ; + k
                lda     cp_aw
                ldb     #7
                mul
                addd    cp_p
                std     cp_p                    ; + 7*apple_w
                ldb     cp_w0
                clra
                lslb
                rola
                lslb
                rola
                std     cp_t                    ; 4*w0
                ldd     cp_p
                subd    cp_t
                std     cp_p                    ; p
                lsra
                rorb
                lsra
                rorb                            ; p / 4 (p >= 0: the plan keeps it on screen)
                addd    cp_dst
                tfr     d,x
                lda     cp_p+1
                anda    #3                      ; k drawn = p mod 4
                ldb     cp_aw
                andb    #1
                eorb    #1                      ; 1 iff apple_w even
                lslb
                orb     #1                      ; mirror, + swap
cp_call
                ldu     cp_cur
                ldu     ,u                      ; U = the stream
                jsr     xf_blit
                inc     char_probe_n
                ldu     cp_cur
                leau    CP_ENT,u
                stu     cp_cur
                lbra    cp_next
cp_done
                rts

cp_cur          rmb     2
cp_dst          rmb     2
cp_p            rmb     2
cp_t            rmb     2
cp_rows         rmb     1
cp_w0           rmb     1
cp_aw           rmb     1
char_probe_n    fcb     0                       ; draws completed

* --- generated: the draw list, its streams and the registry ---
                include "build/gen/char_probe_place.s"
