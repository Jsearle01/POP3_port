* src/engine/char_probe.s
*
* POP CoCo3 - THE FIRST CHARACTER ON A GAMEPLAY SCREEN (P5.28; colour phase P5.29).
*
* Draws the list char_probe_plan.py generates from content/chars/probe_place.json onto the
* back buffer, after tile_probe.s has drawn LEVEL0 screen 1 there. Linked ONLY into the
* character probe (build.bat's -DCHAR_PROBE build of tile_probe.s); the tile probe that ships
* on probe.dmk does not see this file.
*
* ★ WHAT THIS EXERCISES, AND WHAT IT DOES NOT. The bake (content/chars), the registry
* (char_cels.s: apple_w), the frame table (frame_table.s: Fcheck), the transform (xf_blit)
* and the placement AND COLOUR arithmetic a draw needs -- over a real background, into a
* real framebuffer. Not motion, not clipping (xf_blit has none; the plan places every frame
* clear of the edges), and NOT PLANE ORDERING: the page is one flattened opaque pass, and the
* plan places every frame clear of the foreground rectangles.
*
* ---------------------------------------------------------------
* THE PLACEMENT ARITHMETIC (P5.20 §3B, and xform_probe_gen.cel_cases, which proved it)
* ---------------------------------------------------------------
* A draw names the REFERENCE's frame: byte column `col`, phase k, facing f, bottom row yco.
*   top    = yco - rows + 1                     rows from the stream's own header
*   f = 0  X = base + top*80 + col,   A = k
*   f = 1  the routine reverses all 4*w0 px of the stored frame, the bake's mirror the
*          7*apple_w it converted, so the routine's frame sits d = 4*w0 - 7*apple_w px left:
*          p = 4*col + k - d = 4*col + k + 7*apple_w - 4*w0
*          X = base + top*80 + p/4,   A = p mod 4
*
* ---------------------------------------------------------------
* ★★ THE COLOUR PHASE (P5.29) -- the oracle's rule, applied literally, step by step
* ---------------------------------------------------------------
* P5.28 swapped iff the mirror's width was even, and Jay saw the mirrored kid BLUE where the
* oracle has orange. The oracle decides the colour phase per FRAME and per FACING:
*
*   1. ODD X iff bit7(Fcheck) == bit7(CharFace)            [CTRLSUBS.S:833-839]
*      (X is doubled first, so CharX cannot touch the low bit). CharFace bit7 is 1 facing
*      left (f = 0), 0 facing right (f = 1).
*   2. The image's LEFT column is X facing left; facing right MLayGen lays the mirror
*      7*apple_w px left of X [HIRES.S:1202-1208], so its parity is X's XOR (apple_w odd).
*   3. The stored cel is coloured as if its left column were EVEN (content/chars, start_col 0),
*      so an odd left column means blue<->orange.
*   4. Mirroring an image of EVEN pixel width (7*apple_w even) reverses every pixel's column
*      parity, so the mirror swaps once more (bake_scene.py:626-631, Jay-gated at P3.72h).
*   swap = edge parity XOR (f = 1 AND apple_w even);   B = (swap ? 2 : 0) | (f ? 1 : 0)
*
* xform_probe_gen's "oracle" draw reaches the same flag by algebra (swap = PL); this file
* composes the four steps instead, so the prediction (converter-coloured at the oracle's
* column) checks the 6809's arithmetic rather than sharing it.
* ---------------------------------------------------------------

                ifdef   OBJTARGET
                section prog
                export  char_probe_draw
                import  xf_blit
                import  fore_draw
                endc

                include "src/hal.inc"

* entry: +0 stream, +2 &apple_w, +4 &frame row, +6 yco, +7 col, +8 phase, +9 facing,
*        +10 plane: 0 = MID (drawn before the foreground pass, as DRAWMID is before DRAWFORE),
*                   1 = FLAT (drawn after it -- P5.5's one undifferentiated pass, the CONTROL)
CP_ENT          equ     11

* ---------------------------------------------------------------
* P5.30: THE PLANE ORDER. DRAWALL draws DRAWMID (the characters) sixth and DRAWFORE seventh
* [GRAFIX.S:485-505; P5.8 §3C]. So: every MID draw, then the page's foreground list over them,
* then the FLAT draws -- which land on top of the foreground, the way every character drew
* before this dispatch, and are there only as the control beside the corrected draw.
* ---------------------------------------------------------------
char_probe_draw
                clr     cp_pass
                lbsr    cp_walk
                jsr     fore_draw
                lda     #1
                sta     cp_pass
                lbsr    cp_walk
                rts

cp_walk
                ldu     #cp_list
                stu     cp_cur
cp_next
                ldu     cp_cur
                ldx     ,u                      ; the stream
                lbeq    cp_done
                lda     10,u
                cmpa    cp_pass
                lbne    cp_skip
                lda     ,x                      ; rows
                sta     cp_rows
                lda     1,x                     ; w0
                sta     cp_w0
                lda     [2,u]                   ; apple_w, from the registry
                sta     cp_aw
* --- the colour phase, steps 1-4 ---
                ldx     4,u
                lda     3,x                     ; Fcheck, from the frame table
                tst     9,u
                bne     cp_fr
                eora    #$80                    ; facing left: CharFace bit7 = 1
cp_fr                                           ; bit7(A) clear iff bit7(Fcheck) == bit7(CharFace)
                clrb
                tsta
                bmi     cp_par0
                incb                            ; 1: ODD X                        (step 1)
cp_par0         tst     9,u
                beq     cp_swp                  ; facing left: edge = X           (step 2)
                lda     cp_aw
                anda    #1
                pshs    a
                eorb    ,s+                     ; facing right: edge = X ^ (apple_w odd)
                lda     cp_aw
                anda    #1
                eora    #1                      ; 1 iff apple_w even              (step 4)
                pshs    a
                eorb    ,s+
cp_swp          stb     cp_swap                 ; edge odd => swap                (step 3)
* --- dst = draw base + top * 80 ---
                lda     6,u                     ; yco
                suba    cp_rows
                inca                            ; top
                ldb     #80
                mul
                addd    HAL_gfx_draw_base
                std     cp_dst
                tst     9,u
                bne     cp_mir
* --- facing 0: the reference's frame IS the routine's ---
                ldb     7,u
                clra
                addd    cp_dst
                tfr     d,x
                lda     8,u                     ; k
                ldb     cp_swap
                lslb                            ; bit1 = swap, bit0 = 0 (no mirror)
                bra     cp_call
* --- facing 1: p = 4*col + k + 7*apple_w - 4*w0 ---
cp_mir
                ldb     7,u
                clra
                lslb
                rola
                lslb
                rola
                std     cp_p                    ; 4*col
                ldb     8,u
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
                ldb     cp_swap
                lslb
                orb     #1                      ; mirror, + swap
cp_call
                ldu     cp_cur
                ldu     ,u                      ; U = the stream
                jsr     xf_blit
                inc     char_probe_n
cp_skip
                ldu     cp_cur
                leau    CP_ENT,u
                stu     cp_cur
                lbra    cp_next
cp_done
                rts

cp_pass         rmb     1
cp_cur          rmb     2
cp_dst          rmb     2
cp_p            rmb     2
cp_t            rmb     2
cp_rows         rmb     1
cp_w0           rmb     1
cp_aw           rmb     1
cp_swap         rmb     1
char_probe_n    fcb     0                       ; draws completed

* --- generated: the draw list (here), then its streams, the registry and the frame table
*     (in section chdata -- see link/pop_charprobe.link) ---
                include "build/gen/char_probe_place.s"
