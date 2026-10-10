* src/engine/kidrun_probe.s
*
* POP CoCo3 - THE KID RUNS (P5.31): the first motion in the gameplay arc.
*
* Built as tile_probe.s -DCHAR_PROBE -DWALK_PROBE with THIS file in char_probe.s's place: it
* exports the same char_probe_draw hook, which tile_probe calls once the page is drawn. Instead
* of returning after one picture, it animates the kid across LEVEL0 screen 1's top floor, driven
* by the oracle's own sequence (`startrun`, SEQTABLE.S:159-177, transcribed below), and only
* returns if the harness asked it to stop after N steps (wk_stop), so a step can be captured.
*
* ---------------------------------------------------------------
* ONE ANIMATION STEP, IN DRAWALL'S ORDER [GRAFIX.S:485-505]
* ---------------------------------------------------------------
*   SNGPEEL   restore what THIS buffer's last draw covered -- saved two steps ago, on this
*             page. ★ THE PEEL IS PER PAGE: the oracle's own SNGPEEL opens `ldx PAGE / beq
*             :1 / ldx #maxpeel` (§5.313), and char_draw.s:107 says it -- "PEEL IS PER BUFFER".
*             The buffers alternate, so the other page's save is not this page's.
*   DRAWBACK  (nothing: the background does not change on this screen)
*   DRAWMID   save what the new frame will cover, into this page's peel; draw the kid
*   DRAWFORE  the page's FOREGROUND list over him -- every step, culled to the kid's own
*             rectangle (fore_draw_rect). Outside that rectangle nothing changed this step, and
*             the restore put back pixels that already included the foreground.
*   then the VBL-synced flip, paced to WK_SPEED display frames per step.
*
* ★ WHAT THE FOREGROUND PASS HERE DOES AND DOES NOT TEST. It runs every step, so a piece over a
* MOVING kid is redrawn correctly as he moves (he starts behind screen 1's post, $45). It is
* still SURE's static list (P5.30 §3A): FAST re-points the plane per dirty-buffer class
* [FRAMEADV.S:399-439], and NOTHING here models that -- there is no per-piece plane table and
* no dirty-buffer class, so a piece that the running engine would put in the MID plane is still
* drawn as foreground. On screen 1 every fore entry is a wall front or the post, which FAST also
* puts in front; a screen whose running assignment differs is untested.
*
* ---------------------------------------------------------------
* THE SEQUENCER -- ANIMCHAR [COLL.S:994], ONLY WHAT `startrun` USES
* ---------------------------------------------------------------
* Bytes are read until a FRAME byte ($01..$F0): opcodes PRECEDE the frame they affect, and
* ANIMCHAR returns on the frame, so a `goto` costs no step (char_draw.s:1577, seq_graph.py).
*   IMPLEMENTED   frame bytes; goto (-1); chx (-5); act (-7, operand consumed, CharAction is
*                 not modelled); tap (-14, operand consumed -- the footstep SOUND is not played)
*   NOT IMPLEMENTED  aboutface (-2), up (-3), down (-4), chy (-6), setfall (-8), ifwtless (-9),
*                 die (-10), jaru (-11), jard (-12), effect (-13), nextlevel (-15). Any of them
*                 stops the walk with wk_err = the opcode: a partial interpreter must not pass
*                 silently for a whole one.
*
* ★ POSITION. chx moves the kid: CharX := ADDCHARX(delta), which NEGATES the delta when facing
* left [CTRLSUBS.S:353-363]. Fdx only offsets one frame's DRAW: FCharX = 2*(ADDCHARX(Fdx) -
* ScrnLeft) + parity [CTRLSUBS.S:807-839], ScrnLeft = 58. Facing left, the image's left edge is
* Apple px 2*(CharX - Fdx - 58) + PL, PL = 1 iff bit7(Fcheck) == bit7(CharFace) = 1; port px is
* that + 20. Its bottom row is CharY + Fdy [CTRLSUBS.S:823-828].
* ★ COLOUR (P5.29): facing left, the image's left column is X, so swap = PL.
*
* WRAP. The demo's kid starts this run at CharX 191, CharY 55, facing left (P5.21's oracle trace,
* display frame 7949) -- so does this one. At CharX < WK_XMIN (the floor ends at the pit) he is put
* back at 191 and the sequence restarts: a harness loop, NOT oracle behaviour (the oracle's
* AutoCtrl stops him with runstop, which is out of scope).
*
                ifdef   OBJTARGET
                section prog
                export  char_probe_draw
                export  wk_stop
                export  wk_steps
                export  wk_t_seq,wk_t_erase,wk_t_save,wk_t_draw,wk_t_fore,wk_t_end
                export  wk_frame,wk_x,wk_k
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
WK_FACE         equ     $FF             ; CharFace = -1, facing left, for the whole walk
WK_PEEL         equ     400             ; the largest run cel's rows * (w0+1) (kidrun_plan.py checks)

char_probe_draw
* --- both buffers hold the background; the mirror unmaps the page, so map it back ---
                jsr     HAL_gfx_mirror
                jsr     tile_bank_map
                clr     wk_valid
                clr     wk_valid+1
                clr     wk_steps
                clr     wk_steps+1
                jsr     HAL_time_frame_count
                std     wk_last
wk_restart
                lda     #WK_X0
                sta     wk_x
                ldu     #wk_startrun
                stu     wk_seq

* ===============================================================
wk_loop
wk_t_seq
* --- SEQUENCER: opcodes until a frame byte ---
                ldu     wk_seq
ws_next         ldb     ,u+
                cmpb    #SEQ_FIRSTOP
                blo     ws_frame
                cmpb    #SEQ_GOTO
                bne     ws_1
                ldu     ,u
                bra     ws_next
ws_1            cmpb    #SEQ_CHX
                bne     ws_2
                lda     wk_x
                suba    ,u+                     ; ADDCHARX facing left: CharX - delta
                sta     wk_x
                bra     ws_next
ws_2            cmpb    #SEQ_ACT
                beq     ws_skip1
                cmpb    #SEQ_TAP
                beq     ws_skip1
                stb     wk_err                  ; an opcode this walk does not implement
ws_halt         bra     ws_halt
ws_skip1        leau    1,u
                bra     ws_next
ws_frame        stu     wk_seq
                stb     wk_frame
* --- the frame's row: image, Fdx, Fdy, Fcheck, slot ---
                decb
                lda     #FRAME_ENTSZ
                mul
                addd    #fdef_tab
                tfr     d,x
                lda     4,x
                lbne    ws_badslot              ; the run's cels are all CHTAB1 (slot 0)
                ldb     ,x                      ; image
                cmpb    #WK_NIMG
                lbhi    ws_badslot
                decb
                lslb
                ldy     #wk_img
                ldy     b,y                     ; the stream
                sty     wk_strm
                lda     ,y
                sta     wk_rows
                lda     1,y
                sta     wk_w0
* --- swap / PL: bit7(Fcheck) == bit7(CharFace) -> odd X -> swap ---
                lda     3,x
                eora    #WK_FACE
                clrb
                tsta
                bmi     ws_even
                incb
ws_even         stb     wk_pl
* --- Apple px = 2*(CharX - Fdx - 58) + PL ; port px = that + 20 ---
                clra
                ldb     wk_x
                std     wk_t
                ldb     1,x                     ; Fdx, signed
                sex
                pshs    d
                ldd     wk_t
                subd    ,s++
                subd    #58
                lslb
                rola
                addb    wk_pl
                adca    #0
                addd    #20
                std     wk_px
                andb    #3
                stb     wk_k
                ldd     wk_px
                lsra
                rorb
                lsra
                rorb
                stb     wk_col
* --- top row = CharY + Fdy - rows + 1 ---
                ldb     2,x                     ; Fdy, signed
                sex
                addd    #WK_Y
                subb    wk_rows
                sbca    #0
                addd    #1
                stb     wk_top
* --- the frame's width on screen: w0, +1 at a non-zero phase ---
                lda     wk_w0
                tst     wk_k
                beq     ws_w
                inca
ws_w            sta     wk_w

* --- SNGPEEL: restore what this page saved two steps ago ---
wk_t_erase
                ldb     HAL_gfx_cur_back
                ldx     #wk_valid
                tst     b,x
                beq     we_none
                lslb
                ldx     #wk_pdst
                ldd     b,x                     ; the saved frame's offset in the buffer
                addd    HAL_gfx_draw_base
                tfr     d,x
                ldb     HAL_gfx_cur_back
                lslb
                ldy     #wk_pbuf
                ldy     b,y
                ldb     HAL_gfx_cur_back
                pshs    x
                ldx     #wk_prows
                lda     b,x
                ldx     #wk_pw
                ldb     b,x
                puls    x
                jsr     blit_erase_full
we_none

* --- DRAWMID: save under the new frame, then draw it ---
wk_t_save
                lda     wk_top
                ldb     #80
                mul
                addb    wk_col
                adca    #0
                std     wk_off
                ldb     HAL_gfx_cur_back
                lslb
                ldx     #wk_pdst
                ldy     wk_off
                sty     b,x                     ; remember where, for this page's next restore
                ldb     HAL_gfx_cur_back
                ldx     #wk_prows
                lda     wk_rows
                sta     b,x
                ldx     #wk_pw
                lda     wk_w
                sta     b,x
                ldx     #wk_valid
                lda     #1
                sta     b,x
                lslb
                ldy     #wk_pbuf
                ldy     b,y
                ldd     wk_off
                addd    HAL_gfx_draw_base
                tfr     d,x
                lda     wk_rows
                ldb     wk_w
                jsr     blit_save_full
wk_t_draw
                ldd     wk_off
                addd    HAL_gfx_draw_base
                tfr     d,x
                ldu     wk_strm
                lda     wk_k
                ldb     wk_pl
                lslb                            ; bit1 = swap, no mirror
                jsr     xf_blit

* --- DRAWFORE: the foreground list over him, culled to his rectangle ---
wk_t_fore
                lda     wk_col
                sta     fd_rx0
                adda    wk_w
                deca
                sta     fd_rx1
                lda     wk_top
                sta     fd_ry0
                adda    wk_rows
                deca
                sta     fd_ry1
                jsr     fore_draw_rect
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
* VBL last+WK_SPEED exactly. (The first build waited for WK_SPEED and then flipped one later.)
wk_pace         jsr     HAL_time_frame_count
                subd    wk_last
                cmpd    #WK_SPEED-1
                blo     wk_pace
                jsr     HAL_gfx_swap
* ★ THE SWAP UNMAPS THE PAGE. HAL_gfx_swap ends in gfx_map_blocks, which writes ALL FOUR window
* registers $FFA4-$FFA7 [gfx.s:747-756] -- so after every flip $C000 is a framebuffer block, not
* the tile page, and the next step's foreground pass would read its list from garbage. The first
* build did exactly that: steps whose kid touched no fore piece came out exact by luck, and the
* two where he stood behind the post (6 and 26) showed him in front of it. Map it back, every
* flip -- what cutscene_room.s's cel_bank_map does after every swap, for the same reason.
                jsr     tile_bank_map
                jsr     HAL_time_frame_count
                std     wk_last
* the live log's "SHOWN", from the first flip on -- but NOT when the harness is stopping at a
* step: the verifier takes status 4 as "the picture is final" and would capture mid-walk
                ldd     wk_stop
                bne     wk_wrap
                lda     #4
                sta     probe_status
wk_wrap
* --- wrap at the pit's edge ---
                lda     wk_x
                cmpa    #WK_XMIN
                lbhs    wk_loop
                lbra    wk_restart

ws_badslot      lda     #$EE
                sta     wk_err
                lbra    ws_halt

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

* --- state ---
wk_stop         fdb     0               ; the harness pokes N to stop after step N (0 = run forever)
wk_steps        fdb     0
wk_err          fcb     0
wk_last         rmb     2
wk_seq          rmb     2
wk_strm         rmb     2
wk_t            rmb     2
wk_px           rmb     2
wk_off          rmb     2
wk_x            rmb     1
wk_frame        rmb     1
wk_rows         rmb     1
wk_w0           rmb     1
wk_w            rmb     1
wk_k            rmb     1
wk_pl           rmb     1
wk_col          rmb     1
wk_top          rmb     1
* --- the peel, ONE PER PAGE ---
wk_valid        rmb     2               ; per page: a save exists to restore
wk_pdst         rmb     4               ; per page: the saved frame's offset in its buffer
wk_prows        rmb     2
wk_pw           rmb     2
wk_pbuf         fdb     WK_PEEL0,WK_PEEL1
* The two peel buffers live in the page's STAGING AREA ($3000-$41FF): the track read lands the
* packed page there and lz_unpack expands it into $C000 before the walk starts, after which nothing
* uses it. Runtime only -- no LOADM'd byte is placed there (link/pop_kidrun.link).
WK_PEEL0        equ     $3000
WK_PEEL1        equ     $3000+WK_PEEL

                include "build/gen/kidrun_gen.s"
