* src/engine/fore_draw.s
*
* POP CoCo3 - THE FOREGROUND PASS (P5.30).
*
* Draws the baked page's FOREGROUND list (harness/tools/bake_screen.py, format in its header)
* onto the draw buffer. Called AFTER the characters, so every foreground piece the oracle's
* DRAWFORE draws after DRAWMID [GRAFIX.S:484-505; P5.8 §3C, decoded from live memory] goes back
* over them.
*
* The page's display list is still the WHOLE finished screen (P5.5's model), so this pass
* re-writes pixels the page already put there; with no character on screen it changes nothing
* (bake_screen.py verifies exactly that). Its job is only what a character drew in the way.
*
* Each entry is a rectangle of a variant already in the page, written row by row: the first and
* last byte through the entry's edge masks (a piece whose Apple column is not 4-px aligned
* shares those bytes with its neighbours), the bytes between copied.
*
* ★ WHAT THIS IS NOT. It is SURE's plane assignment -- a whole-screen static composite, every
* `jmp add` piece in the background [FRAMEADV.S:53]. FAST re-points the plane per dirty-buffer
* class [FRAMEADV.S:399-439], so a running engine's plane assignment is not this list. And an
* entry flagged KEYED (bit0) is written OPAQUE here: exact with nothing behind it, wrong where a
* character stands behind its transparent pixels. Neither case is tested by P5.30's probe.
*
*   Entry: the page mapped at $C000 (as tile_probe.s leaves it after tile_draw)
*   Exit:  A,B,X,Y,U clobbered
*
                ifdef   OBJTARGET
                section prog
                export  fore_draw
                export  fore_draw_rect
                export  fd_rx0,fd_rx1,fd_ry0,fd_ry1
                endc

                include "src/hal.inc"

FD_PAGE         equ     $C000
FD_TAB          equ     FD_PAGE+4
FD_STRIDE       equ     80

* fore_draw       -- every entry (the whole screen)
* fore_draw_rect  -- P5.31: only entries that intersect fd_rx0..fd_rx1 (bytes) x fd_ry0..fd_ry1
*                    (rows), set by the caller: a moving character's own rectangle. Outside it
*                    nothing changed this step, so redrawing there would rewrite identical bytes.
fore_draw
                clr     fd_rx0
                lda     #FD_STRIDE-1
                sta     fd_rx1
                clr     fd_ry0
                lda     #191
                sta     fd_ry1
fore_draw_rect
* U = the fore section = FD_TAB + 4*n_variants + 3*n_entries
                lda     FD_PAGE+2
                ldb     #4
                mul
                addd    #FD_TAB
                std     fd_t2
                lda     FD_PAGE+3
                ldb     #3
                mul
                addd    fd_t2
                tfr     d,u
                lda     ,u+                     ; n_fore
                sta     fd_n
                lbeq    fd_done
fd_ent
* --- the variant's row: X = data, fd_w / fd_h ---
                lda     ,u
                ldb     #4
                mul
                addd    #FD_TAB
                tfr     d,x
                ldd     2,x
                sta     fd_w
                stb     fd_h
                ldx     ,x
* --- the cull: skip the entry unless it meets the rectangle ---
                lda     1,u                     ; x0
                cmpa    fd_rx1
                bhi     fd_skip
                adda    fd_w
                deca                            ; x1
                cmpa    fd_rx0
                blo     fd_skip
                lda     2,u                     ; y0
                cmpa    fd_ry1
                bhi     fd_skip
                adda    fd_h
                deca                            ; y1
                cmpa    fd_ry0
                blo     fd_skip
* --- Y = draw base + y*80 + x ---
                lda     2,u
                ldb     #FD_STRIDE
                mul
                addd    HAL_gfx_draw_base
                addb    1,u
                adca    #0
                tfr     d,y
                lda     3,u
                sta     fd_lm
                coma
                sta     fd_lmn
                lda     4,u
                sta     fd_rm
                coma
                sta     fd_rmn
fd_row
                ldb     fd_w
* first byte, through the left mask (for a one-byte entry the bake makes lm = both edges)
                lda     ,x+
                anda    fd_lm
                sta     fd_t
                lda     ,y
                anda    fd_lmn
                ora     fd_t
                sta     ,y+
                decb
                beq     fd_eol
fd_mid          cmpb    #1
                beq     fd_last
                lda     ,x+
                sta     ,y+
                decb
                bra     fd_mid
fd_last
                lda     ,x+
                anda    fd_rm
                sta     fd_t
                lda     ,y
                anda    fd_rmn
                ora     fd_t
                sta     ,y+
fd_eol
                ldb     fd_w
                negb
                sex
                addd    #FD_STRIDE
                leay    d,y
                dec     fd_h
                bne     fd_row
fd_skip         leau    6,u
                dec     fd_n
                lbne    fd_ent
fd_done
                rts

fd_rx0          rmb     1
fd_rx1          rmb     1
fd_ry0          rmb     1
fd_ry1          rmb     1

fd_t2           rmb     2
fd_n            rmb     1
fd_w            rmb     1
fd_h            rmb     1
fd_lm           rmb     1
fd_lmn          rmb     1
fd_rm           rmb     1
fd_rmn          rmb     1
fd_t            rmb     1
