* src/engine/kidrun_probe.s
*
* POP CoCo3 - THE KID RUNS (P5.31), AND A GUARD STANDS IN HIS WAY (P5.32).
*
* Built as tile_probe.s -DCHAR_PROBE -DWALK_PROBE with THIS file in char_probe.s's place: it
* exports the same char_probe_draw hook, which tile_probe calls once the page is drawn. Instead
* of returning after one picture, it animates the kid across LEVEL0 screen 1's top floor, driven
* by the oracle's own sequence (`startrun`, SEQTABLE.S:159-177), past a guard driven by HIS own
* (`guardengarde`, SEQTABLE.S:214-236), and only returns if the harness asked it to stop after N
* steps (wk_stop), so a step can be captured.
*
* ---------------------------------------------------------------
* ONE ANIMATION STEP: THREE PASSES OVER ALL ACTORS (P3.32), IN DRAWALL'S ORDER [GRAFIX.S:485-505]
* ---------------------------------------------------------------
*   SEQ       every actor's sequencer
*   ERASE ALL restore what each actor's last draw on THIS page covered -- so the room is clean
*             everywhere any character was
*   SAVE ALL  every background captured against that clean room
*   DRAW ALL  and only now does anything reach the screen: the kid, then the guard, in front --
*             FRAMEADV.S:2191-2193, `compare`: "cmp #TypeShad / beq :xinfront ;enemy is always
*             in front"
*   DRAWFORE  the page's FOREGROUND list, culled to the union of the actors' new rectangles
*   then the VBL-synced flip, paced to WK_SPEED display frames per step.
*
* ★★★ WHY NOT A PER-ACTOR LOOP. P5.31's loop was erase->save->draw for its one character. Run that
* per actor and the second actor's SAVE captures the first's PIXELS as background and restores them
* a step later -- P3.32's overlap defect, found in the cutscene ("the vizier doesn't get corrupted,
* only the princess") and fixed there by exactly these three passes. The passes are the fix; there is
* no per-actor path through a step.
*
* ★★ THE PEEL IS PER PAGE AND PER ACTOR: four slots (actor x page). The oracle's SNGPEEL opens `ldx
* PAGE / beq :1 / ldx #maxpeel` (§5.313); char_draw.s:107 -- "PEEL IS PER BUFFER". Each actor record
* carries its own two (valid, offset, rows, width, buffer); nothing indexes another actor's.
*
* ★ NO PEEL-SKIP. The guard stands still, and P3.21's skip would not peel him -- "a static
* character's background never changes". P3.32: "That holds only while it is the ONLY THING on
* screen" -- the kid runs straight through him. Every actor peels every step (P5.32 §3.3).
*
* ---------------------------------------------------------------
* THE SEQUENCER -- ANIMCHAR [COLL.S:994], ONLY WHAT THESE TWO SEQUENCES USE
* ---------------------------------------------------------------
* Bytes are read until a FRAME byte ($01..$F0): opcodes PRECEDE the frame they affect, and
* ANIMCHAR returns on the frame, so a `goto` costs no step (char_draw.s:1577, seq_graph.py).
*   IMPLEMENTED   frame bytes; goto (-1); chx (-5, ADDCHARX: negated facing left); act (-7, operand
*                 consumed, CharAction is not modelled); tap (-14, operand consumed -- no sound)
*   NOT IMPLEMENTED  every other opcode stops the run with wk_err = the opcode.
*
* ★ THE FRAME ROW -- usealtsets [CTRLSUBS.S:1685-1711]: the kid (CharID 0) always reads Fdef; a guard
* reads ALTSET1 for frames 150..189 (row n-150 of alt1_tab; the oracle's `sbc #149` is 1-based) and
* Fdef otherwise. The falling substitution (102..106 -> 172..176) is not reachable from either
* sequence here and is not implemented.
*
* ★ POSITION [CTRLSUBS.S:805-839, ADDCHARX :353]: FCharX = 2*(ADDCHARX(Fdx) - 58) + PL, PL = 1 iff
* bit7(Fcheck) == bit7(CharFace); port px = FCharX + 20; bottom row = CharY + Fdy.
*   facing LEFT  (CharFace -1): ADDCHARX(Fdx) = CharX - Fdx; the image's LEFT edge is FCharX.
*   facing RIGHT (CharFace 0):  ADDCHARX(Fdx) = CharX + Fdx; MLayGen [HIRES.S:1178-1208] takes XCO as
*                the image's bottom-RIGHT corner ("XCO := XCO - WIDTH"), so the mirrored image ends
*                at FCharX. xf_blit mirrors its own 4*w0-px frame, so the frame starts at
*                FCharX - 4*w0 -- the reference (7*apple_w px) sits 4*w0 - 7*apple_w to its right,
*                char_probe.s's arithmetic for a mirrored draw.
* ★ COLOUR (P5.29): swap = PL, in both facings.
*
* WRAP. The demo's kid starts this run at CharX 191, CharY 55, facing left (P5.21's oracle trace,
* display frame 7949). At CharX < WK_XMIN he is put back at 191 and `startrun` restarts: a harness
* loop, NOT oracle behaviour. The guard does not wrap: `ready` holds frame 171 forever.
* THE SWORD. The guard's frames carry Fsword $C8 -- SWORDTAB entry 8, a CHTAB3 cel SETUPSWORD
* [CTRLSUBS.S:1590] would draw as a SEPARATE sprite. Not drawn: the sword is out of P5.32's scope.
*
                ifdef   OBJTARGET
                section prog
                export  char_probe_draw
                export  wk_stop,wk_nact
                export  wk_steps
                export  wk_t_seq,wk_t_erase,wk_t_save,wk_t_draw,wk_t_fore,wk_t_end
                export  wk_frame,wk_x,wk_k,gd_frame,gd_x
                import  xf_blit
                import  blit_save_full
                import  blit_erase_full
                import  fore_draw_rect
                import  fd_rx0,fd_rx1,fd_ry0,fd_ry1
                import  probe_status
                import  tile_bank_map
                endc

                include "src/hal.inc"

SEQ_GOTO        equ     $FF
SEQ_CHX         equ     $FB
SEQ_ACT         equ     $F9
SEQ_TAP         equ     $F2
SEQ_FIRSTOP     equ     $F1
WK_PEEL         equ     400             ; the kid's largest rows * (w0+1) (kidrun_plan.py checks)
GD_PEEL         equ     320             ; the guard's (kidrun_plan.py checks)

* --- the ACTOR RECORD. kid_rec's labels below are laid out in exactly this order. ---
A_SEQ           equ     0               ; 2  the sequence pointer
A_X             equ     2               ; 1  CharX
A_FACE          equ     3               ; 1  CharFace: $FF left, 0 right
A_FRAME         equ     4               ; 1
A_ROWS          equ     5               ; 1  the stream's rows
A_W0            equ     6               ; 1  the stream's phase-0 width in bytes
A_W             equ     7               ; 1  the frame's width on screen (w0, +1 at k>0)
A_K             equ     8               ; 1  phase
A_PL            equ     9               ; 1  PL -> the swap
A_COL           equ     10              ; 1  the frame's byte column
A_TOP           equ     11              ; 1  the frame's top row
A_STRM          equ     12              ; 2  the stream
A_OFF           equ     14              ; 2  the frame's offset in a page
A_IMG           equ     16              ; 2  image n -> stream table
A_SLOT          equ     18              ; 1  the table the frame row must name (0 = CHTAB1, 3 = CHTAB4)
A_NIMG          equ     19              ; 1  images in that table
A_ALT           equ     20              ; 1  usealtsets: 0 = the kid (Fdef only), 1 = a guard
A_MIR           equ     21              ; 1  xf_blit bit0: 1 = facing right
A_VALID         equ     22              ; 2  per page: a save exists to restore
A_PDST          equ     24              ; 4  per page: the saved frame's offset
A_PROWS         equ     28              ; 2  per page
A_PW            equ     30              ; 2  per page
A_PBUF          equ     32              ; 4  per page: the buffer -- THIS actor's, THIS page's
A_PX            equ     36              ; 2  port px of the frame's left edge
A_SIZE          equ     38

char_probe_draw
* --- both buffers hold the background; the mirror unmaps the page, so map it back ---
                jsr     HAL_gfx_mirror
                jsr     tile_bank_map
                ldx     #kid_tmpl
                ldy     #kid_rec
                bsr     wk_copy
                ldx     #gd_tmpl
                ldy     #gd_rec
                bsr     wk_copy
                clr     wk_steps
                clr     wk_steps+1
                jsr     HAL_time_frame_count
                std     wk_last
                bra     wk_loop

wk_copy         ldb     #A_SIZE
wc_lp           lda     ,x+
                sta     ,y+
                decb
                bne     wc_lp
                rts

* ===============================================================
wk_loop
wk_t_seq
                ldu     #kid_rec
                lbsr    wk_seq_one
                lda     wk_nact
                cmpa    #2
                blo     wk_t_erase
                ldu     #gd_rec
                lbsr    wk_seq_one

* --- ERASE ALL: the room clean everywhere any actor was (reverse draw order; either is clean) ---
wk_t_erase
                lda     wk_nact
                cmpa    #2
                blo     we_kid
                ldu     #gd_rec
                lbsr    wk_erase_one
we_kid          ldu     #kid_rec
                lbsr    wk_erase_one

* --- SAVE ALL, against that clean room ---
wk_t_save
                ldu     #kid_rec
                lbsr    wk_save_one
                lda     wk_nact
                cmpa    #2
                blo     wk_t_draw
                ldu     #gd_rec
                lbsr    wk_save_one

* --- DRAW ALL: the kid, then the guard -- "enemy is always in front" ---
wk_t_draw
                ldu     #kid_rec
                lbsr    wk_draw_one
                lda     wk_nact
                cmpa    #2
                blo     wk_t_fore
                ldu     #gd_rec
                lbsr    wk_draw_one

* --- DRAWFORE: the foreground list over them, culled to the union of their new rectangles ---
wk_t_fore
                ldu     #kid_rec
                lda     A_COL,u
                sta     fd_rx0
                adda    A_W,u
                deca
                sta     fd_rx1
                lda     A_TOP,u
                sta     fd_ry0
                adda    A_ROWS,u
                deca
                sta     fd_ry1
                lda     wk_nact
                cmpa    #2
                blo     wf_go
                ldu     #gd_rec
                lda     A_COL,u
                cmpa    fd_rx0
                bhs     wf_1
                sta     fd_rx0
wf_1            adda    A_W,u
                deca
                cmpa    fd_rx1
                bls     wf_2
                sta     fd_rx1
wf_2            lda     A_TOP,u
                cmpa    fd_ry0
                bhs     wf_3
                sta     fd_ry0
wf_3            adda    A_ROWS,u
                deca
                cmpa    fd_ry1
                bls     wf_go
                sta     fd_ry1
wf_go           jsr     fore_draw_rect
wk_t_end
* --- count; stop here if the harness asked for step N (no flip: tile_probe mirrors and shows it)
                ldd     wk_steps
                addd    #1
                std     wk_steps
                ldd     wk_stop
                beq     wk_pace
                cmpd    wk_steps
                bne     wk_pace
                rts
* --- pace: WK_SPEED display frames per step, then the VBL-synced flip ---
* HAL_gfx_swap itself waits for the NEXT VBL, so wait for WK_SPEED-1 here and the flip lands on
* VBL last+WK_SPEED exactly. (P5.31's first build waited for WK_SPEED and then flipped one later.)
wk_pace         jsr     HAL_time_frame_count
                subd    wk_last
                cmpd    #WK_SPEED-1
                blo     wk_pace
                jsr     HAL_gfx_swap
* ★ THE SWAP UNMAPS THE PAGE (P5.31): HAL_gfx_swap ends in gfx_map_blocks, which writes ALL FOUR
* window registers $FFA4-$FFA7 [gfx.s:747-756]; map it back every flip or the next foreground pass
* reads its list from a framebuffer block.
                jsr     tile_bank_map
                jsr     HAL_time_frame_count
                std     wk_last
* the live log's "SHOWN", from the first flip on -- but NOT when the harness is stopping at a
* step: the verifier takes status 4 as "the picture is final" and would capture mid-run
                ldd     wk_stop
                bne     wk_wrap
                lda     #4
                sta     probe_status
wk_wrap
* --- the kid wraps at the pit's edge; the guard holds ---
                lda     wk_x
                cmpa    #WK_XMIN
                lbhs    wk_loop
                ldd     #wk_startrun
                std     wk_seq
                lda     #WK_X0
                sta     wk_x
                lbra    wk_loop

* ---------------------------------------------------------------
* wk_seq_one -- U = actor. ANIMCHAR to the next frame byte, then the frame's row, stream, PL,
* phase, column, top and width.
* ---------------------------------------------------------------
wk_seq_one
                ldy     A_SEQ,u
ws_next         ldb     ,y+
                cmpb    #SEQ_FIRSTOP
                blo     ws_frame
                cmpb    #SEQ_GOTO
                bne     ws_1
                ldy     ,y
                bra     ws_next
ws_1            cmpb    #SEQ_CHX
                bne     ws_2
                lda     ,y+                     ; the delta
                tst     A_FACE,u
                bpl     ws_chr                  ; ADDCHARX: facing right, CharX + delta
                nega                            ;           facing left,  CharX - delta
ws_chr          adda    A_X,u
                sta     A_X,u
                bra     ws_next
ws_2            cmpb    #SEQ_ACT
                beq     ws_skip1
                cmpb    #SEQ_TAP
                beq     ws_skip1
                stb     wk_err                  ; an opcode this probe does not implement
ws_halt         bra     ws_halt
ws_skip1        leay    1,y
                bra     ws_next
ws_frame        sty     A_SEQ,u
                stb     A_FRAME,u
* --- the frame's row: usealtsets, then image, Fdx, Fdy, Fcheck, slot ---
                tst     A_ALT,u
                beq     ws_main
                cmpb    #150
                blo     ws_main
                cmpb    #190
                bhs     ws_main
                subb    #150
                lda     #FRAME_ENTSZ
                mul
                addd    #alt1_tab
                bra     ws_row
ws_main         decb
                lda     #FRAME_ENTSZ
                mul
                addd    #fdef_tab
ws_row          tfr     d,x
                lda     4,x
                cmpa    A_SLOT,u
                lbne    ws_badslot
                ldb     ,x                      ; image
                lbeq    ws_badslot
                cmpb    A_NIMG,u
                lbhi    ws_badslot
                decb
                lslb
                ldy     A_IMG,u
                ldy     b,y                     ; the stream
                lbeq    ws_badslot              ; an image this probe did not link
                sty     A_STRM,u
                lda     ,y
                sta     A_ROWS,u
                lda     1,y
                sta     A_W0,u
* --- PL: bit7(Fcheck) == bit7(CharFace) -> odd X -> swap ---
                lda     3,x
                eora    A_FACE,u
                clrb
                tsta
                bmi     ws_even
                incb
ws_even         stb     A_PL,u
* --- FCharX = 2*(ADDCHARX(Fdx) - 58) + PL ; port px = FCharX + 20 ---
                clra
                ldb     A_X,u
                std     wk_t
                ldb     1,x                     ; Fdx, signed
                sex
                tst     A_FACE,u
                bpl     ws_fr
                pshs    d                       ; facing left: CharX - Fdx
                ldd     wk_t
                subd    ,s++
                bra     ws_fx
ws_fr           addd    wk_t                    ; facing right: CharX + Fdx
ws_fx           subd    #58
                lslb
                rola
                addb    A_PL,u
                adca    #0
                addd    #20
                tst     A_FACE,u
                bmi     ws_pxl
* facing right: the image ENDS at FCharX (MLayGen's XCO is its right edge), so xf_blit's mirrored
* 4*w0-px frame starts 4*w0 px left of it
                std     wk_t
                clra
                ldb     A_W0,u
                lslb
                rola
                lslb
                rola
                std     wk_t2
                ldd     wk_t
                subd    wk_t2
ws_pxl          std     A_PX,u
                andb    #3
                stb     A_K,u
                ldd     A_PX,u
                lsra
                rorb
                lsra
                rorb
                stb     A_COL,u
* --- top row = CharY + Fdy - rows + 1 ---
                ldb     2,x                     ; Fdy, signed
                sex
                addd    #WK_Y
                subb    A_ROWS,u
                sbca    #0
                addd    #1
                stb     A_TOP,u
* --- the frame's width on screen: w0, +1 at a non-zero phase ---
                lda     A_W0,u
                tst     A_K,u
                beq     ws_w
                inca
ws_w            sta     A_W,u
                rts

ws_badslot      lda     #$EE
                sta     wk_err
                lbra    ws_halt

* ---------------------------------------------------------------
* wk_erase_one -- U = actor. SNGPEEL: restore what THIS actor saved on THIS page, two steps ago.
* ---------------------------------------------------------------
wk_erase_one
                ldb     HAL_gfx_cur_back
                leax    A_VALID,u
                tst     b,x
                beq     we_none
                lslb
                leax    A_PDST,u
                ldd     b,x                     ; the saved frame's offset
                addd    HAL_gfx_draw_base
                std     wk_t
                ldb     HAL_gfx_cur_back
                lslb
                leax    A_PBUF,u
                ldy     b,x                     ; THIS actor's buffer for THIS page
                ldb     HAL_gfx_cur_back
                leax    A_PROWS,u
                lda     b,x
                leax    A_PW,u
                ldb     b,x
                ldx     wk_t
                pshs    u
                jsr     blit_erase_full
                puls    u
we_none         rts

* ---------------------------------------------------------------
* wk_save_one -- U = actor. Save under the frame this actor is about to draw, on this page.
* ---------------------------------------------------------------
wk_save_one
                lda     A_TOP,u
                ldb     #80
                mul
                addb    A_COL,u
                adca    #0
                std     A_OFF,u
                ldb     HAL_gfx_cur_back
                lslb
                leax    A_PDST,u
                ldy     A_OFF,u
                sty     b,x                     ; remember where, for this page's next restore
                ldb     HAL_gfx_cur_back
                leax    A_PROWS,u
                lda     A_ROWS,u
                sta     b,x
                leax    A_PW,u
                lda     A_W,u
                sta     b,x
                leax    A_VALID,u
                lda     #1
                sta     b,x
                lslb
                leax    A_PBUF,u
                ldy     b,x
                ldd     A_OFF,u
                addd    HAL_gfx_draw_base
                tfr     d,x
                lda     A_ROWS,u
                ldb     A_W,u
                pshs    u
                jsr     blit_save_full
                puls    u
                rts

* ---------------------------------------------------------------
* wk_draw_one -- U = actor. xf_blit: A = phase, B = bit1 swap (= PL) | bit0 mirror (facing right).
* ---------------------------------------------------------------
wk_draw_one
                ldd     A_OFF,u
                addd    HAL_gfx_draw_base
                tfr     d,x
                lda     A_K,u
                ldb     A_PL,u
                lslb
                orb     A_MIR,u
                pshs    u
                ldu     A_STRM,u
                jsr     xf_blit
                puls    u
                rts

* ---------------------------------------------------------------
* `startrun`, TRANSCRIBED BY HAND from SEQTABLE.S:159-177 (char_draw.s's precedent). The build
* walks this transcription and seq_graph.py's parse of the oracle file side by side and fails on
* any divergence (kidrun_plan.py) -- two derivations, so a wrong one cannot agree with itself.
* ---------------------------------------------------------------
wk_startrun     fcb     SEQ_ACT,1               ; startrun  db act,1
                fcb     1                       ; runstt1   db 1
                fcb     2                       ; runstt2   db 2
                fcb     3                       ; runstt3   db 3
                fcb     4,SEQ_CHX,8             ; runstt4   db 4,chx,8
                fcb     5,SEQ_CHX,3             ; runstt5   db 5,chx,3
                fcb     6,SEQ_CHX,3             ; runstt6   db 6,chx,3
wk_runcyc1      fcb     7,SEQ_CHX,5             ; runcyc1   db 7,chx,5
                fcb     8,SEQ_CHX,1             ; runcyc2   db 8,chx,1
                fcb     SEQ_TAP,1,9,SEQ_CHX,2   ; runcyc3   db tap,1,9,chx,2
                fcb     10,SEQ_CHX,4            ; runcyc4   db 10,chx,4
                fcb     11,SEQ_CHX,5            ; runcyc5   db 11,chx,5
                fcb     12,SEQ_CHX,2            ; runcyc6   db 12,chx,2
                fcb     SEQ_TAP,1,13,SEQ_CHX,3  ; runcyc7   db tap,1,13,chx,3
                fcb     14,SEQ_CHX,4            ; runcyc8   db 14,chx,4
                fcb     SEQ_GOTO                ;           db goto
                fdb     wk_runcyc1              ;           dw runcyc1
wk_startrun_end

* ---------------------------------------------------------------
* `guardengarde` -> `ready`, TRANSCRIBED BY HAND from SEQTABLE.S:214-236; checked the same way.
* ---------------------------------------------------------------
gd_guardengarde fcb     SEQ_GOTO                ; guardengarde db goto
                fdb     gd_ready                ;              dw ready
gd_ready        fcb     SEQ_ACT,1               ; ready     db act,1
                fcb     SEQ_TAP,0               ;           db tap,0
                fcb     158                     ;           db 158
                fcb     170                     ;           db 170
gd_loop         fcb     171                     ; :loop     db 171
                fcb     SEQ_GOTO                ;           db goto
                fdb     gd_loop                 ;           dw :loop
gd_guardengarde_end

* --- the actors' initial records (A_SIZE bytes each, in the record's order) ---
kid_tmpl        fdb     wk_startrun             ; A_SEQ
                fcb     WK_X0,$FF               ; A_X, A_FACE (left)
                fcb     0,0,0,0,0,0,0,0         ; FRAME ROWS W0 W K PL COL TOP
                fdb     0,0                     ; STRM OFF
                fdb     wk_img                  ; A_IMG
                fcb     0,WK_NIMG,0,0           ; SLOT (CHTAB1) NIMG ALT MIR
                fdb     0                       ; VALID
                fdb     0,0                     ; PDST
                fdb     0,0                     ; PROWS PW
                fdb     WK_PEEL0,WK_PEEL1       ; PBUF
                fdb     0                       ; PX
gd_tmpl         fdb     gd_guardengarde
                fcb     GD_X,0                  ; facing RIGHT, toward the kid
                fcb     0,0,0,0,0,0,0,0
                fdb     0,0
                fdb     gd_img
                fcb     3,GD_NIMG,1,1           ; SLOT 3 (chtable4 = CHTAB4.GD) NIMG, usealtsets, mirror
                fdb     0
                fdb     0,0
                fdb     0,0
                fdb     GD_PEEL0,GD_PEEL1
                fdb     0

* --- state ---
wk_stop         fdb     0               ; the loader copies the harness's "stop after step N" here
wk_nact         fcb     2               ; ... and the actor count: 2, or 1 for the one-actor control
wk_steps        fdb     0
wk_err          fcb     0
wk_last         rmb     2
wk_t            rmb     2
wk_t2           rmb     2
* --- the kid's record, labelled field by field (the harness reads wk_x / wk_frame / wk_k) ---
kid_rec
wk_seq          rmb     2
wk_x            rmb     1
wk_face         rmb     1
wk_frame        rmb     1
                rmb     3               ; ROWS W0 W
wk_k            rmb     1
                rmb     A_SIZE-A_K-1
gd_rec
                rmb     2
gd_x            rmb     1
                rmb     1
gd_frame        rmb     1
                rmb     A_SIZE-A_FRAME-1
* The four peel buffers live in the page's STAGING AREA ($3000-$41FF): the track read lands the
* packed page there and lz_unpack expands it into $C000 before the run starts, after which nothing
* uses it. Runtime only (link/pop_kidrun.link). $4100-$41FF is the cycle harness's scratch.
WK_PEEL0        equ     $3000
WK_PEEL1        equ     WK_PEEL0+WK_PEEL
GD_PEEL0        equ     WK_PEEL1+WK_PEEL
GD_PEEL1        equ     GD_PEEL0+GD_PEEL

                include "build/gen/kidrun_gen.s"
