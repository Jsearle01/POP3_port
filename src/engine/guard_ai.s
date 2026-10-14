* src/engine/guard_ai.s
*
* POP CoCo3 - THE GUARD GOES EN GARDE (P5.37). Included by kidrun_probe.s -DGA_WINDOW, in section prog.
*
* ★★ A TEST BED, NOT A START-UP PATH, AND NOTHING HERE IS PROPOSED FOR SHIPPING. It runs the oracle's
* game frames 180-217 -- the window P5.36 measured -- with three §2I divergences, each one in the data
* engarde_plan.py emits and labels: the kid REPLAYED (ga_kid_tab), the scene SEEDED at the game-frame-179
* boundary (ga_shad0, ga_glob0, ga_mapseed), EnemyAlert REPLAYED (ga_ea_tab).
*
* TRANSCRIBED FROM THE SOURCE, routine by routine, each named with its file:line and its CALLER. The
* 6809 does not share a model with guard_model.py (the host transcription): both read the source, both
* are compared with the oracle's trace, not with each other (P5.37 §3.3).
*
* ★ BUILT -- what the window enters (P5.36 §3B): AUTOCTRL, DoRelease, GuardProg, Alert, EnGarde,
* DoEngarde (AUTO's latch and CTRL's sequence), DoAdvance (both), getopdist, GENCTRL, GuardCtrl,
* FightCtrl, clrall, jumpseq; RDBLOCK with getunderft / getinfront / get2infront / cmpspace / cmpbarr;
* the 16-byte records with Load/Save-with-Op; and what makes the record P5.37 §3.1 compares: ANIMCHAR
* and REREADBLOCKS (GetFrameInfo + GetBaseBlock -- BlockX is made there).
* ★ ALSO BUILT, AND NOT ENTERED BY THE WINDOW: DoRetreat (both) -- the MAP CONTROL (§3.4) takes it, and a
* control that traps instead of retreating would not show the map decided anything.
* ★ NOT BUILT -- every branch the window does not enter ends at ga_trap with a code in ga_err:
* FollowKid, InRange, GenFight, MaybeAdvance/Block/Strike, DoTurn, DoStrike, DoBlock, the kid's
* non-fight control (`demo`, AUTOPLAYBACK -- his walk IS the replay), CHECKSTRIKE/CHECKSTAB, and the
* physics after ANIMCHAR (gravity, addfall, getedges, enemycoll, checkfloor, checkpress, checkspikes,
* checkimpale, checkslice2 -- P5.37 §6). rndp is not built; RND is (P5.37 §2.3), and counts its calls.
*
* RECORDS [GAMEEQ.S:566-598], 16 bytes, the oracle's order. Seq is a PORT pointer, big-endian, into the
* emitted sequences (sq_XXXX = oracle address $XXXX); in the replayed kid it is the oracle's address and
* is never dereferenced.

C_POSN          equ     0
C_X             equ     1
C_Y             equ     2
C_FACE          equ     3
C_BX            equ     4
C_BY            equ     5
C_ACT           equ     6
C_XV            equ     7
C_YV            equ     8
C_SEQ           equ     9
C_SCRN          equ     11
C_REP           equ     12
C_ID            equ     13
C_SWORD         equ     14
C_LIFE          equ     15
GA_LOG          equ     $3800           ; the guard's record after each game frame (runtime-only, staging area)
GA_GPLOG        equ     $3A60           ; guardprog after each game frame (38 B)
GA_RLOG         equ     $3B00           ; every map read: gf-180, who, scrn, x, y, answer (6 B, 80 max)
GA_TQOUT        equ     $3600           ; the self-test's answers: objid, cmpbarr(objid) per query
*                                         (the peels sit at $3000-$359F: kidrun_probe.s WK_PEEL0..GD_PEEL1)
GA_RLMAX        equ     80
GA_CTL_EA       equ     $10             ; run modes (ga_mode): the EnemyAlert control
GA_CTL_MAP      equ     $20             ;                      the map control

* ===============================================================
* ga_init -- SEED the scene at the game-frame-179 boundary (★ §2I divergence 2), then the AC1 self-test.
* ===============================================================
ga_init
                ldx     #ga_shad0
                ldy     #ga_shad
                lbsr    ga_copy16
                ldx     #ga_kid_tab             ; the kid's record at 179 (★ §2I divergence 1)
                ldy     #ga_kid
                lbsr    ga_copy16
                stx     ga_kptr                 ; -> his record at 180
                ldx     #ga_glob0
                ldy     #ga_glob
                ldb     #GA_NGLOB
gi_g            lda     ,x+
                sta     ,y+
                decb
                bne     gi_g
                lda     ga_visscrn0
                sta     ga_visscrn
                ldx     #ga_mapseed             ; the oracle's map at 179, where it differs from the file
gi_seed         ldd     ,x++
                cmpd    #$FFFF
                beq     gi_seeded
                tfr     d,y
                lda     ,x+
                sta     ga_bluetype,y
                bra     gi_seed
gi_seeded       ldx     #ga_ea_tab              ; ★ §2I divergence 3
                stx     ga_eaptr
* --- the run mode (kidrun_probe.s): 2 the gate, drawn; $10 / $20 the negative controls, logic only ---
                clr     ga_draw
                lda     ga_mode
                cmpa    #2
                bne     gi_nodraw
                inc     ga_draw
gi_nodraw       cmpa    #GA_CTL_MAP
                bne     gi_nomap
* ★ THE MAP CONTROL (P5.37 §3.4): a WRONG answer for the block two in front of the guard at game frame
* 208 -- screen 4 block (3,0) reads as SPACE. EnGarde must take :gap -> DoRetreat [AUTO.S:598-605].
                lda     #O_SPACE
                sta     ga_bluetype+(4-1)*30+0*10+3
gi_nomap
                clr     ga_gf
                clr     ga_nrl
                clr     ga_rlon                 ; the self-test's reads are not the window's
                ldd     #0
                std     ga_rnd_calls
* --- AC1 NARROW: every distinct query the oracle made in the window, answered on THIS map ---
                ldx     #ga_tq
                ldu     #GA_TQOUT
                lda     #GA_NTQ
                sta     ga_t0
gi_tq           lda     2,x
                sta     ga_rdy
                lda     ,x
                ldb     1,x
                pshs    x,u
                lbsr    ga_rdblock
                puls    x,u
                sta     ,u+
                lbsr    ga_cmpbarr
                sta     ,u+
                leax    3,x
                dec     ga_t0
                bne     gi_tq
                inc     ga_rlon                 ; from here, every read is the window's
                rts

ga_copy16       ldb     #16
gc_lp           lda     ,x+
                sta     ,y+
                decb
                bne     gc_lp
                rts

* ===============================================================
* ga_frame -- ONE GAME FRAME: MainLoop's DoKid then DoShad [TOPCTRL.S:512-514] -- the kid's controller
* sees both fighters PRECEDING; the guard's sees the kid UPCOMING. Called by kidrun_probe's step.
* ===============================================================
ga_frame
                ldx     ga_eaptr                ; ★ §2I: EnemyAlert, REPLAYED per game frame
                lda     ,x+
                stx     ga_eaptr
                ldb     ga_mode
                cmpb    #GA_CTL_EA              ; ★ the EnemyAlert CONTROL (P5.37 §3.4): forced to 1
                bne     gf_ea
                lda     #1
gf_ea           sta     ga_EnemyAlert
                lbsr    ga_dokid
                lbsr    ga_doshad
* --- the guard's record after this game frame, for engarde_test.py ---
                lda     ga_gf
                ldb     #16
                mul
                addd    #GA_LOG
                tfr     d,y
                ldx     #ga_shad
                lbsr    ga_copy16
                ldx     #GA_GPLOG
                ldb     ga_gf
                lda     ga_guardprog
                sta     b,x
                inc     ga_gf
                rts

* ---------------------------------------------------------------
* DoKid [TOPCTRL.S:637-692] -- ★ TEST BED: LoadKidwOp, rereadblocks, his controller ONLY on DemoCtrl's
* en-garde branch [CTRL.S:587-598], then the REPLAY. With CharSword = 0 DemoCtrl jumps to `demo`
* (AUTOPLAYBACK: the recorded walk) and GENCTRL takes its non-fight path -- not built; the replayed
* record IS that walk. Either way his record is then the oracle's (animchar + his physics = the replay).
* ---------------------------------------------------------------
ga_dokid
                ldx     #ga_kid                 ; LoadKidwOp [CTRLSUBS.S:1961-1972]
                ldy     #ga_char
                lbsr    ga_copy16
                ldx     #ga_shad
                ldy     #ga_op
                lbsr    ga_copy16
                lda     #$80                    ; map reads from here on are the kid's controller's
                sta     ga_who
                lbsr    ga_rereadblocks
* unholy [MISC.S:450]: level 0 -> rts.  PLAYERCTRL [CTRL.S:554-569]: alive, KidStrength 4, stunned 0
                tst     ga_char+C_LIFE
                lbpl    ga_trap_dead
                tst     ga_KidStrength          ; strength run out -> CharLife := 0 -- not built
                lbeq    ga_trap_dead
                tst     ga_milestone            ; DemoCtrl :finish -- not built
                lbne    ga_trap_demofin
                tst     ga_char+C_SWORD
                beq     gk_replay               ; `jmp demo` -- the replayed walk
                lda     #10                     ; DemoCtrl: guardprog := 10, AutoCtrl, guardprog := 11
                sta     ga_guardprog
                lbsr    ga_autoctrl
                lda     #11
                sta     ga_guardprog
                lbsr    ga_genctrl              ; PLAYERCTRL :demo -> `jmp GenCtrl`
gk_replay       ldx     ga_kptr                 ; ★ §2I: SaveKid of the ORACLE's record for this frame
                ldy     #ga_kid
                lbsr    ga_copy16
                stx     ga_kptr
                clr     ga_who
                rts

* ---------------------------------------------------------------
* DoShad [TOPCTRL.S:701-740]. ★ The physics after animchar is NOT BUILT (P5.37 §1, §6); the second
* rereadblocks [:729] is -- it makes the record's BlockX, which §3.1 compares.
* ---------------------------------------------------------------
ga_doshad
                lda     ga_shad+C_FACE
                cmpa    #86                     ; "no character" code
                beq     gs_rts
                ldx     #ga_shad                ; LoadShadwOp [CTRLSUBS.S:1989-2000]
                ldy     #ga_char
                lbsr    ga_copy16
                ldx     #ga_kid
                ldy     #ga_op
                lbsr    ga_copy16
                lbsr    ga_rereadblocks
* unholy: level 0 -> rts
                lbsr    ga_shadctrl
                lda     ga_char+C_SCRN
                cmpa    ga_visscrn
                bne     gs_save
                lbsr    ga_animchar
                lda     ga_char+C_X
                cmpa    #O_SCRNLEFT-14
                blo     gs_save
                cmpa    #O_SCRNRIGHT+14
                bhs     gs_save                 ; offscreen: skip all this
                lbsr    ga_rereadblocks
gs_save         ldx     #ga_char                ; SaveShad [CTRLSUBS.S:1949-1957]
                ldy     #ga_shad
                lbsr    ga_copy16
gs_rts          rts

* ---------------------------------------------------------------
* SHADCTRL [CTRL.S:509-534], caller DoShad. ManCtrl = 0 (no deselected device).
* ---------------------------------------------------------------
ga_shadctrl
                lda     ga_char+C_ID
                cmpa    #24                     ; mouse
                lbeq    ga_trap_id
                tst     ga_char+C_LIFE
                lbpl    ga_trap_dead            ; :dead -- not built
                tst     ga_OppStrength
                lbeq    ga_trap_dead            ; life ran out -- deadenemy, not built
                lbsr    ga_autoctrl
                lbra    ga_genctrl

* ===============================================================
* AUTO.S -- callers: SHADCTRL (the guard), DemoCtrl (the kid in 215-217)
* ===============================================================
* AUTOCTRL [:160-193]
ga_autoctrl
                lbsr    ga_dorelease
                lda     ga_char+C_ID
                beq     ga_proc_guard           ; :5 KidProg = `jmp GuardProg` [:449-450] -- ★ the kid SKIPS
*                                                 the three decrements below (:164). Unexercised: all three
*                                                 are 0 across the window (P5.36 §3D).
                tst     ga_justblocked
                beq     ga_jb0
                dec     ga_justblocked
ga_jb0          tst     ga_gdtimer
                beq     ga_gt0
                dec     ga_gdtimer
ga_gt0          tst     ga_refract
                beq     ga_rf0
                dec     ga_refract
ga_rf0          lda     ga_char+C_ID
                cmpa    #24
                lbeq    ga_trap_id              ; MouseProg
                cmpa    #4
                lbeq    ga_trap_id              ; SkelProg
                cmpa    #2
                lblo    ga_trap_id              ; ShadowProg
*                                                 level 13 (VizierProg): level 0 here
* GuardProg [:455-460]
ga_proc_guard   lda     ga_char+C_SWORD
                cmpa    #2
                lblo    ga_alert
                lbra    ga_engarde

* Alert [:467-506], caller GuardProg
ga_alert
                tst     ga_kid+C_LIFE           ; KidLife
                bpl     al_rts                  ; kid's dead -- relax
                lbsr    ga_getopdist
                ldb     ga_op+C_BY
                cmpb    ga_char+C_BY
                bne     al_diff
                cmpa    #$F8                    ; -8: right on top of you -> en garde
                bhs     al_eng
al_diff         tst     ga_alertguard
                beq     al_ok
                clr     ga_alertguard
                cmpa    #128
                blo     al_eng
                cmpa    #$FC                    ; -4: overlapping -- stand still
                bhs     al_ok
                lbra    ga_trap_doturn          ; DoTurn -- not built
al_ok           cmpa    #128
                bhs     al_rts                  ; kid is behind you
al_eng          tst     ga_EnemyAlert
                beq     al_rts
*                                                 level 13 SongCue wait: level 0 here
                lbra    ga_a_doengarde
al_rts          rts

* EnGarde [:513-606], caller GuardProg
ga_engarde
                lda     ga_char+C_POSN
                cmpa    #166
                lbeq    eg_rts
                cmpa    #150
                blo     eg_rts                  ; wait till you're ready
                lda     ga_EnemyAlert
                cmpa    #2
                bhs     eg_ea2
                cmpa    #1
                beq     eg_rts                  ; in sight, but a gap or barrier: stay put
                lbra    ga_trap_ea0             ; EnemyAlert 0: FollowKid / DoDropguard -- not built
eg_ea2          lbsr    ga_getopdist            ; if kid is stunned, let him recover...
                bmi     eg_norec
                cmpa    #12
                blo     eg_norec
                lda     ga_op+C_POSN
                cmpa    #102
                blo     eg_norec
                cmpa    #118
                bhs     eg_norec
                lda     ga_op+C_ACT
                cmpa    #5
                beq     eg_rts
eg_norec        lbsr    ga_getopdist            ; advance to closest safe distance
                cmpa    #O_TOOFAR
                bhs     eg_oor
                lbra    ga_trap_inrange         ; InRange / :tooclose / :offg -- not built
eg_oor          tst     ga_refract              ; out of range
                bne     eg_rts
                lda     ga_char+C_FACE
                cmpa    ga_op+C_FACE
                beq     eg_nojump               ; chase him
                lda     ga_op+C_POSN
                cmpa    #7
                blo     eg_norun
                cmpa    #15
                blo     eg_runwait
eg_norun        cmpa    #34
                blo     eg_nojump
                cmpa    #44
                blo     eg_jumpwait             ; kid running towards you: stay put
eg_nojump       lbsr    ga_getinfront
                lbsr    ga_cmpspace             ; don't advance unless solid floor
                beq     eg_gap
                lbsr    ga_get2infront
                lbsr    ga_cmpspace
                bne     eg_solid
eg_gap          lbra    ga_a_doretreat
eg_solid        lbra    ga_a_doadvance
eg_jumpwait     lbsr    ga_getopdist
                cmpa    #O_JUMPTHRES
                bhs     eg_rts                  ; wait
                lbra    ga_trap_strike          ; DoStrike -- not built
eg_runwait      lbsr    ga_getopdist
                cmpa    #O_RUNTHRES
                bhs     eg_rts
                lbra    ga_trap_strike
eg_rts          rts

* DoRelease / DoAdvance (DoFwd) / DoRetreat (DoBack) / DoEngarde [:822-876] -- the AUTO latches
ga_dorelease    clr     ga_clrF
                clr     ga_clrB
                clr     ga_clrU
                clr     ga_clrD
                clr     ga_clrbtn
                clr     ga_JSTKX
                clr     ga_JSTKY
                clr     ga_btn
                rts
ga_a_doadvance  lda     #$FF
                sta     ga_clrF
                sta     ga_JSTKX
                rts
ga_a_doretreat  lda     #$FF                    ; ★ built for the MAP CONTROL; the window never enters it
                sta     ga_clrB
                lda     #1
                sta     ga_JSTKX
                rts
ga_a_doengarde  lda     #$FF
                sta     ga_clrD
                bra     ga_a_doadvance

* RND [GRAFIX.S:1386-1395]: RNDseed := (5 * RNDseed + 23) mod 256. The oracle's LCG, NOT the cutscene's
* xorshift. ★ NOTHING IN THIS WINDOW CALLS IT (rndp is not built) -- it counts its calls so the harness can
* assert zero (P5.37 §3.2). The flames keep their own RNG (P5.37 §6).
ga_rnd          ldd     ga_rnd_calls
                addd    #1
                std     ga_rnd_calls
                lda     ga_RNDseed
                ldb     #5
                mul
                addb    #23
                stb     ga_RNDseed
                tfr     b,a
                rts

* ===============================================================
* CTRL.S -- caller GenCtrl (SHADCTRL for the guard; PLAYERCTRL :demo for the kid)
* ===============================================================
* GENCTRL [:648-685]
ga_genctrl
                tst     ga_char+C_LIFE
                lbpl    ga_trap_dead            ; :dead -- not built
                lda     ga_char+C_ACT
                cmpa    #5                      ; mid-bump
                beq     ga_clrall
                cmpa    #4                      ; falling
                beq     ga_clrall
                lda     ga_char+C_SWORD
                cmpa    #2
                beq     ga_fightctrl
                lda     ga_char+C_ID
                cmpa    #2
                lblo    ga_trap_nonfight        ; the kid's/shadman's non-fight control -- not built
* GuardCtrl [:736-754]
                lda     ga_char+C_POSN
                cmpa    #166
                bne     gc_rts
                tst     ga_clrD
                bpl     gc_rts
                tst     ga_clrF
                lbmi    ga_c_doengarde
                lbra    ga_trap_doturn          ; alertturn -- not built
gc_rts          rts

* clrall [:625-632] -- returns A = 1
ga_clrall       clr     ga_clrB
                clr     ga_clrF
                clr     ga_clrU
                clr     ga_clrD
                lda     #1
                rts

* FightCtrl [:759-888], caller GENCTRL
ga_fightctrl
                lda     ga_char+C_ACT
                cmpa    #2
                bhs     fc_rts                  ; must be on level ground
                lbsr    ga_getunderft
                cmpa    #O_LOOSE
                beq     fc_skip                 ; unless you're standing on loose floor
                lda     ga_EnemyAlert
                cmpa    #2
                blo     fc_dropgd
fc_skip         lbsr    ga_getopdist            ; opponent behind you: turn to face him
                cmpa    #O_SWORDTHRES
                blo     fc_onalert
                cmpa    #128
                blo     fc_dropgd
                cmpa    #$FC                    ; overlapping
                bhs     fc_onalert
                lbra    ga_trap_doturn          ; DoTurnEng -- not built
fc_dropgd       lda     ga_char+C_ID            ; kid & shadman only
                bne     fc_1
                sta     ga_heroic               ; (A = 0)
                bra     fc_2
fc_1            cmpa    #2
                bhs     fc_onalert              ; guard: remain en garde
fc_2            lda     ga_char+C_POSN
                cmpa    #171                    ; wait for ready posn
                bne     fc_rts
                lbra    ga_trap_sheathe         ; resheathe -- not built
fc_onalert      lda     ga_char+C_POSN
                cmpa    #161                    ; successful block
                lbeq    ga_trap_block
                tst     ga_clrbtn
                lbmi    ga_trap_strike          ; fresh button press -- not built
                tst     ga_clrD
                lbmi    ga_trap_sheathe         ; down to lower your sword -- not built
                tst     ga_clrU
                lbmi    ga_trap_block           ; DoBlock -- not built
                tst     ga_clrF
                bmi     ga_c_doadvance
                tst     ga_clrB
                bmi     ga_c_doretreat
fc_rts          rts

* DoRetreat [:991-1004] -- ★ built for the MAP CONTROL; the window never enters it
ga_c_doretreat  lda     ga_char+C_POSN
                cmpa    #158
                beq     cr_1
                cmpa    #170
                beq     cr_1
                cmpa    #171
                bne     cr_rts
cr_1            lda     #1
                sta     ga_clrB
                lda     #O_RETREAT
                lbra    ga_jumpseq
cr_rts          rts

* DoAdvance [:1007-1024]
ga_c_doadvance  lda     ga_char+C_POSN
                cmpa    #158
                beq     ca_1
                cmpa    #170
                beq     ca_1
                cmpa    #171
                bne     cr_rts
ca_1            lda     #O_FASTADVANCE          ; "kid is faster"
                tst     ga_char+C_ID
                beq     ca_2
                lda     #O_ADVANCE
ca_2            ldb     #1
                stb     ga_clrF
                lbra    ga_jumpseq

* DoEngarde [:1607-1624], caller GuardCtrl
ga_c_doengarde  lbsr    ga_clrall               ; A = 1
                sta     ga_clrF
                sta     ga_clrbtn
                lda     #2
                sta     ga_char+C_SWORD
                lda     ga_char+C_ID
                cmpa    #2
                lblo    ga_trap_id              ; kid / shadman: `engarde`, offguard -- not built
                lda     #O_GUARDENGARDE
*               fall into jumpseq

* JUMPSEQ [CTRLSUBS.S:700-711]: A = sequence # (1..)
ga_jumpseq      tfr     a,b
                decb
                clra
                lslb
                rola
                ldx     #ga_seqtab
                ldd     d,x
                lbeq    ga_trap_seq             ; a sequence this build did not emit
                std     ga_char+C_SEQ
                rts

* ===============================================================
* CTRLSUBS.S
* ===============================================================
* GETOPDIST [:2052-2102] -- A = fwd distance to the opponent (+-127), flags from A
ga_getopdist
                lda     ga_char+C_SCRN
                cmpa    ga_op+C_SCRN
                bne     od_safe
                lda     ga_op+C_X
                cmpa    ga_char+C_X
                blo     od_neg
                suba    ga_char+C_X
                bpl     od_got
                lda     #127
                bra     od_got
od_neg          lda     ga_char+C_X
                suba    ga_op+C_X
                bpl     od_1
                lda     #127
od_1            nega
od_got          tst     ga_char+C_FACE          ; facing left: negate
                bpl     od_cont
                nega
od_cont         ldb     ga_char+C_FACE          ; facing opposite ways: add a width estimate
                eorb    ga_op+C_FACE
                bpl     od_done
                cmpa    #127-13                 ; estwidth = 13
                bhs     od_done
                adda    #13
od_done         tsta
                rts
od_safe         lda     #127
                rts

* GETUNDERFT / GETINFRONT / GET2INFRONT [:414-445] -- plus1 = -1,1 by CharFace+1
ga_getunderft   ldb     ga_char+C_BX
                bra     gu_rd
ga_getinfront   ldb     ga_char+C_BX
                lbsr    gi_step
                bra     gu_rd
ga_get2infront  ldb     ga_char+C_BX
                lbsr    gi_step
                lbsr    gi_step
gu_rd           lda     ga_char+C_BY
                sta     ga_rdy
                lda     ga_char+C_SCRN
*               fall into rdblock
* RDBLOCK [:149-173] -- A = screen, B = block x, ga_rdy = block y. Out: A = objid (idmask); tempscrn /
* tempblockx / tempblocky = the home block. Offscreen references traced home [handler :178-234,
* GETLEFT..GETDOWN :244-274]; screen 0 is a solid mass.
ga_rdblock      sta     ga_tscrn
                sta     ga_ra_s                 ; the ARGUMENTS, for the log (the oracle trace logs these)
                stb     ga_tbx
                stb     ga_ra_x
                lda     ga_rdy
                sta     ga_tby
rb_h            ldb     ga_tbx
                bpl     rb_1
                addb    #10                     ; offleft
                stb     ga_tbx
                clra
                lbsr    rb_adj
                bra     rb_h
rb_1            cmpb    #10
                blo     rb_2
                subb    #10                     ; offrt
                stb     ga_tbx
                lda     #1
                lbsr    rb_adj
                bra     rb_h
rb_2            ldb     ga_tby
                bpl     rb_3
                addb    #3                      ; offtop
                stb     ga_tby
                lda     #2
                lbsr    rb_adj
                bra     rb_h
rb_3            cmpb    #3
                blo     rb_4
                subb    #3                      ; offbot
                stb     ga_tby
                lda     #3
                lbsr    rb_adj
                bra     rb_h
rb_4            lda     ga_tscrn
                beq     rb_null
                deca                            ; calcblue: (scrn-1)*30
                ldb     #30
                mul
                addd    #ga_bluetype
                tfr     d,x
                lda     ga_tby
                ldb     #10
                mul
                addb    ga_tbx
                lda     b,x
                anda    #O_IDMASK
                bra     rb_log
rb_null         lda     #O_BLOCK
rb_log          tst     ga_rlon                 ; the harness's log of every map read in the window
                beq     rb_rts
                pshs    a,x
                ldb     ga_nrl
                cmpb    #GA_RLMAX
                bhs     rb_full
                inc     ga_nrl
                lda     #6
                mul
                addd    #GA_RLOG
                tfr     d,x
                lda     ga_gf
                sta     ,x
                lda     ga_who
                sta     1,x
                ldd     ga_ra_s                 ; screen, x
                std     2,x
                lda     ga_rdy                  ; y
                sta     4,x
                lda     ,s
                sta     5,x
rb_full         puls    a,x
rb_rts          tsta
                rts
* GETLEFT / GETRIGHT / GETUP / GETDOWN: A = which (0..3); tscrn := MAP[(tscrn-1)*4 + which], 0 stays 0
rb_adj          ldb     ga_tscrn
                beq     ra_rts
                decb
                lslb
                lslb
                pshs    a
                addb    ,s+
                ldx     #ga_bluemap
                lda     b,x
                sta     ga_tscrn
ra_rts          rts
* (the log records the ARGUMENTS -- A, X, Y at RDBLOCK's entry -- as the oracle trace does)
gi_step         tst     ga_char+C_FACE
                bmi     gs_l
                incb
                rts
gs_l            decb
                rts

* CMPSPACE [:1506-1522] -- 0 = space (a solid block has no floor), 1 = floor; Z from A
ga_cmpspace     cmpa    #O_SPACE
                beq     cs_sp
                cmpa    #O_PILLARTOP
                beq     cs_sp
                cmpa    #O_PANELWOF
                beq     cs_sp
                cmpa    #O_BLOCK
                beq     cs_sp
                cmpa    #O_ARCHTOP1
                bhs     cs_sp
                lda     #1
                rts
cs_sp           clra
                rts

* CMPBARR [:1533-1563] -- 0 clear, else the barrier code. Its window callers are the kid's walk (DEMO ->
* DoStartrun, game frame 193: not built); here it answers the AC1 self-test.
ga_cmpbarr      cmpa    #O_PANELWIF
                beq     cb_1
                cmpa    #O_PANELWOF
                beq     cb_1
                cmpa    #O_GATE
                bne     cb_2
cb_1            lda     #1
                rts
cb_2            cmpa    #O_MIRROR
                beq     cb_3
                cmpa    #O_SLICER
                bne     cb_4
cb_3            lda     #3
                rts
cb_4            cmpa    #O_BLOCK
                bne     cb_0
                lda     #4
                rts
cb_0            clra
                rts

* ADDCHARX [:353-363] -- A = CharX + A in the facing direction
ga_addcharx     tst     ga_char+C_FACE
                bpl     ax_r
                nega
ax_r            adda    ga_char+C_X
                rts

* GETSEQ [:1629-1639] -- B = the next sequence byte
ga_getseq       ldx     ga_char+C_SEQ
                ldb     ,x+
                stx     ga_char+C_SEQ
                rts

* REREADBLOCKS [CTRL.S:1929-1931] = GETFRAMEINFO + GETBASEBLOCK [CTRLSUBS.S:666-670]:
* getbasex [:329-340] = ADDCHARX(Fdx - (Fcheck & Ffootmark)); GETBLOCKXP [:560-571] = BlockTable[A - angle].
* ★ BlockTable is COMPUTED, as TABLES.S:79-91 generates it: (x + 68) / 14 - 9 (block -5..14; §2I --
* the same 256 values, no 256-byte table).
ga_rereadblocks lbsr    ga_getframeinfo
                lda     3,x                     ; Fcheck
                anda    #O_FFOOTMARK
                nega
                adda    1,x                     ; + Fdx
                bsr     ga_addcharx
                suba    #O_ANGLE
                tfr     a,b
                clra
                addd    #68
                ldx     #-9
rr_div          subd    #14
                blo     rr_got
                leax    1,x
                bra     rr_div
rr_got          tfr     x,d
                stb     ga_char+C_BX
                rts

* GETFRAMEINFO [:1648-1674] + usealtsets [:1685-1715] -- X = the frame's row in frame_table.s
* (+0 image, +1 Fdx, +2 Fdy, +3 Fcheck, +4 slot)
ga_getframeinfo ldb     ga_char+C_POSN
                lda     ga_char+C_ID
                beq     fi_main                 ; kid: main set
                cmpa    #24
                beq     fi_main                 ; mouse: main set
                cmpa    #5
                lbhs    ga_trap_id              ; princess & vizier: alt set 2 -- not built
                cmpa    #2
                blo     fi_1
                cmpb    #102
                blo     fi_main
                cmpb    #107
                bhs     fi_1
                addb    #70                     ; frames 102-106 (falling): 172-176 altset
fi_1            cmpb    #150
                blo     fi_main
                cmpb    #190
                bhs     fi_main
                subb    #alt1_tab_first         ; frames 150-189: altset 1
                lda     #FRAME_ENTSZ
                mul
                addd    #alt1_tab
                tfr     d,x
                rts
fi_main         ldb     ga_char+C_POSN
                subb    #fdef_tab_first
                lda     #FRAME_ENTSZ
                mul
                addd    #fdef_tab
                tfr     d,x
                rts

* ANIMCHAR [COLL.S:994-1156], caller DoShad -- opcodes PRECEDE their frame; returns on the frame byte
ga_animchar
an_next         lbsr    ga_getseq
                cmpb    #O_CHX
                bne     an_1
                lbsr    ga_getseq
                tfr     b,a
                lbsr    ga_addcharx
                sta     ga_char+C_X
                bra     an_next
an_1            cmpb    #O_CHY
                bne     an_2
                lbsr    ga_getseq
                addb    ga_char+C_Y
                stb     ga_char+C_Y
                bra     an_next
an_2            cmpb    #O_ABOUTFACE
                bne     an_3
                com     ga_char+C_FACE
                bra     an_next
an_3            cmpb    #O_GOTO
                bne     an_4
                ldx     ga_char+C_SEQ
                ldd     ,x
                std     ga_char+C_SEQ
                bra     an_next
an_4            cmpb    #O_ACT
                bne     an_5
                lbsr    ga_getseq
                stb     ga_char+C_ACT
                bra     an_next
an_5            cmpb    #O_SETFALL
                bne     an_6
                lbsr    ga_getseq
                stb     ga_char+C_XV
                lbsr    ga_getseq
                stb     ga_char+C_YV
                bra     an_next
an_6            cmpb    #O_TAP
                bne     an_7
                lbsr    ga_getseq               ; sound #: 0 alerts; 1, 2 add a sound THEN fall into :0
                cmpb    #2
                bhi     an_next
                lda     #1
                sta     ga_alertguard
                bra     an_next
an_7            cmpb    #O_NEXTLEVEL
                lbhs    ga_trap_seqop           ; up, down, ifwtless, die, jaru, jard, effect, nextlevel
                stb     ga_char+C_POSN          ; a frame
                rts

* ---------------------------------------------------------------
* a branch this build does not contain: stop, with the reason in ga_err
* ---------------------------------------------------------------
ga_trap_dead    lda     #1
                bra     ga_trap
ga_trap_demofin lda     #2
                bra     ga_trap
ga_trap_id      lda     #3
                bra     ga_trap
ga_trap_doturn  lda     #4
                bra     ga_trap
ga_trap_ea0     lda     #5
                bra     ga_trap
ga_trap_inrange lda     #6
                bra     ga_trap
ga_trap_strike  lda     #7
                bra     ga_trap
ga_trap_nonfight lda    #8
                bra     ga_trap
ga_trap_sheathe lda     #9
                bra     ga_trap
ga_trap_block   lda     #10
                bra     ga_trap
ga_trap_seq     lda     #11
                bra     ga_trap
ga_trap_seqop   lda     #12
ga_trap         sta     ga_err
gt_halt         bra     gt_halt

* ---------------------------------------------------------------
* state
* ---------------------------------------------------------------
ga_char         rmb     16              ; Char [GAMEEQ.S:566]
ga_op           rmb     16              ; Op
ga_kid          rmb     16              ; Kid
ga_shad         rmb     16              ; Shad
ga_glob                                 ; in engarde_plan.GLOBALS' order
ga_justblocked  rmb     1
ga_gdtimer      rmb     1
ga_refract      rmb     1
ga_alertguard   rmb     1
ga_droppedout   rmb     1
ga_offguard     rmb     1
ga_heroic       rmb     1
ga_guardprog    rmb     1
ga_milestone    rmb     1
ga_RNDseed      rmb     1
ga_OppStrength  rmb     1
ga_KidStrength  rmb     1
ga_EnemyAlert   rmb     1
ga_clrF         rmb     1
ga_clrB         rmb     1
ga_clrU         rmb     1
ga_clrD         rmb     1
ga_clrbtn       rmb     1
ga_JSTKX        rmb     1
ga_JSTKY        rmb     1
ga_btn          rmb     1
ga_visscrn      rmb     1
ga_tscrn        rmb     1               ; tempscrn / tempblockx / tempblocky
ga_tbx          rmb     1
ga_tby          rmb     1
ga_ra_s         rmb     1               ; RDBLOCK's arguments: screen, x (adjacent: ldd/std)
ga_ra_x         rmb     1
ga_rdy          rmb     1               ; ... and y (the caller's)
ga_gf           rmb     1               ; game frames run since the seed (0 = game frame 180)
ga_who          rmb     1               ; 0 the guard's controller, $80 the kid's
ga_nrl          rmb     1
ga_rlon         rmb     1
ga_kptr         rmb     2
ga_eaptr        rmb     2
ga_rnd_calls    rmb     2
ga_err          rmb     1
ga_draw         fcb     1               ; 1 in the gate's mode; 0 for the controls (logic only)
ga_mode         fcb     2               ; the run mode, from the loader's actor byte (kidrun_probe.s)
ga_t0           rmb     1
