* src/engine/xf_blit.s
*
* POP CoCo3 — THE RUNTIME SHIFT AND MIRROR (built P5.20, given a home here P5.28).
*
* xf_blit draws a cel stored ONCE -- phase 0, facing 0, in the shipped segment format
* (cel_blit_prep.py) -- at any of the four sub-byte phases and either facing.
*
* ★ ONE HOME. This file is the routine. src/harness/xform_probe.s INCLUDES it (the way it
* already includes blit_core.s and lz_unpack.s), so the probe that measured it byte-exact on
* every gameplay cel [P5.20: 4,640 cases; P5.27: 4,640 again from the bake, cycle for cycle;
* 2,048 more on the guard sets] is measuring THIS text, not a copy of it. It moved out of the
* harness at P5.28 because the first engine program to draw with it links it.
*
* ---------------------------------------------------------------
* WHAT THE INCLUDER OR THE BUILD MUST DEFINE (no defaults -- a wrong table address draws
* plausible garbage, so a missing one must fail to assemble)
* ---------------------------------------------------------------
*   XF_DPPAGE   the direct page the routine owns while it runs (18 bytes from $xx00; 14 before P5.34)
*   XF_M        256 B, natural order, PAGE-ALIGNED: the patched operand's low byte IS the
*               index, so the high byte must be the whole of the page
*   XF_T1       256 B, mirror, permuted (index b^$80; the routine uses base+128)
*   XF_T2       256 B, mirror + blue<->orange swap, permuted
*   XF_TABS     13 pairs x 512 B, F then C, permuted: pair (k-1)*3+t for the nine shift
*               pairs (t = 0 plain, 1 mirror, 2 mirror+swap), then pair 9+k for the four
*               SWAP-ONLY pairs (t = 3, k = 0..3; P5.29)
* The tables' contents are xform_probe_gen.tables_asm()'s; harness/tools/xf_tables.py emits
* the same bytes as a linkable section and checks them against it.
*
* Under OBJTARGET this is section `prog` and imports blit_cel_full (the identity case is the
* stored bake, drawn by the shipped blitter -- no table is touched for it).
*
* ---------------------------------------------------------------
* THE ONE IDEA: COMPOSE THE MIRROR INTO THE SHIFT TABLES, AND MIRROR BY WRITE DIRECTION
* ---------------------------------------------------------------
* A shifted output byte is the OR of two source bytes' halves:
*
*     out[q] = SHL_k[src[q-1]] | SHR_k[src[q]]          k = shift in pixels (2k bits)
*
* Reading the source ascending and writing ASCENDING, that is a carry loop: out = carry |
* F[b], carry' = C[b], with F = SHR_k and C = SHL_k.
*
* A mirror is the same loop reading the source ascending and writing DESCENDING, with the
* per-byte pixel reversal (and the optional blue<->orange swap) composed INTO the tables:
* F = SHL_k o T, C = SHR_k o T. So shift alone, and shift+mirror, are one loop at one cost
* per byte, differing in two table pointers and the sign of the write. The mirror's extra
* work moves to the generator, not the 6809.
*
* ★ THE CARRY LIVES IN A, NOT IN MEMORY. shift_row.s (P3.36-P3.41) says the spill "must
* travel through memory" because the 6809 has no register-to-register OR -- 8 cy/byte, 27%
* of its loop. It need not: `ora b,y` ORs the TABLE ENTRY into A, so the table read IS the
* memory operand, and the carry never leaves A. Per opaque byte:
*
*     ldb  n,u        5    source byte (constant offset -- see the `$80` note)
*     ora  b,y        5    A = carry | F[b]
*     sta  ,x+        6    (`sta ,-x` when mirrored -- same cost)
*     lda  b,s        5    A = C[b], the next carry
*                    21    against shift_row's 30
*
* ---------------------------------------------------------------
* THE `$80` PRE-REVERSAL (P5.20 AC1 -- answered BEFORE the routine existed, commit e6b83d8)
* ---------------------------------------------------------------
* A blast is stored groups-high-first, forward inside a group, 3-byte tail as [1,2,0]. The
* group ORDER cancels against a mirror; the in-group order does not; and no 6809 stack op
* writes ascending. So neither transform can use blit_blast's `pulu d,y`/`pshs d,y`. Both
* read the body in plain ASCENDING order -- the mirror comes from the WRITE direction -- so
* one read pattern serves both: the tail first (it is body[0..rem-1], at the END of the
* segment's data), then the groups walked backwards from the end, each at offsets 0..3.
* Any fixed in-group order costs nothing that way: `ldb 3,u` is 5 cy, `ldb ,u+` is 6.
*
* ---------------------------------------------------------------
* WHICH OUTPUT BYTES NEED A READ-MODIFY-WRITE
* ---------------------------------------------------------------
* ★★★ P5.34: THE PREMISE THIS SECTION WAS BUILT ON IS FALSE FOR GAMEPLAY STREAMS, AND THE
* ROUTINE NO LONGER USES IT. Until P5.34 it read: "Transparency is index 0 with no sidecar
* (P3.18 3B), so a merge's (mask,src) pair carries nothing the src byte does not ... dest =
* (dest AND M[out]) OR out, M = '11 where the pixel is 0'." True of the streams it was measured
* on (P5.20/P5.27); false since P5.33 baked the oracle's mask border [DrawNormal, GAMEBG.S:432;
* MASKTAB, HRTABLES.S:219] -- an OPAQUE BLACK pixel is src 00 with mask 00, and "the pixel is 0"
* made it transparent again at every byte that went through M (P5.33: 64,584 residual pixels,
* every one at one of the four sites below, none elsewhere).
*
* NOW: an OPACITY byte travels beside the colour byte. op = ~mask (11 where the cel is opaque,
* 00 where transparent): a merge byte's op is the complement of its own mask byte; a blast
* byte's op is $FF; a skip's is 0. It goes through the SAME F/C tables as the colour -- every
* table maps a byte of 00/11 pixels to one (P5.34 AC1: xf_opacity_premise.py, 448/448 checks
* over the tables as linked) -- and an output byte is written
*     dest = (dest AND M[out_op]) OR out_colour          (M[v] == ~v on those bytes, 16/16)
* so M is reached by the OPACITY, never by the colour. The four sites that write through M:
*   - every merge byte                       op_out = op_carry | F[~mask];  op_carry' = C[~mask]
*   - the FIRST output byte of a blast       op_out = op_carry | F[$FF];    after it: C[$FF]
*   - a skip's first byte, flushing a carry  op_out = op_carry               (then 0)
*   - the row's final carry                  op_out = op_carry
* ★ The flush/row-end condition is the OPACITY carry, not the colour carry: a carried half-byte
* of pure border is colour 0 and was skipped outright before P5.34.
* Interior blast bytes are opaque by construction (their op is $FF on both halves: F[$FF] |
* C[$FF] = $FF in every pair) and are stored directly, exactly as before -- the blast pays
* nothing per byte; its opacity carry out is the per-pair CONSTANT C[$FF], set once at its end.
*
* M is reached by a SELF-MODIFIED extended operand (`andb >XF_M` with its low byte
* patched), because the loop already holds all four pointers -- X dest, U source, Y and S
* the two tables -- and M would be a fifth. M is page-aligned so the low byte IS the index.
* ★ So this routine must run from RAM. True of every program in the port; stated because
* here it is load-bearing.
*
* ---------------------------------------------------------------
* S IS A TABLE POINTER, so interrupts are masked, exactly as blit_blast borrows S. The
* per-row IRQ/FIRQ window blit_cel opens (P4.29) is reproduced here, at the cost of putting
* the real stack back for it: `lds` / `andcc` / `orcc` / `lds`, 16 cy/row.
*
* ★ NO CLIP. This is the blit_cel_full analogue: the caller must place the frame wholly on
* screen (P5.20 §3F.2).
* ---------------------------------------------------------------

                ifdef   OBJTARGET
                section prog
                export  xf_blit
                import  blit_cel_full
                endc

FB_STRIDE_XF    equ     80

* --- the direct page: EIGHTEEN bytes at XF_DPPAGE*256 (P5.34: +14..+17) ------------
* ★ NONE of these is touched inside XF_WINDOW, where DP = 0 (P5.31): the window is clra / tfr /
* andcc / orcc / lda / tfr and nothing else.
xf_ss           equ     XF_DPPAGE*256+0         ; the real stack while S walks a table
xf_rowbase      equ     XF_DPPAGE*256+2
xf_ctab         equ     XF_DPPAGE*256+4
xf_send         equ     XF_DPPAGE*256+6
xf_rows         equ     XF_DPPAGE*256+8
xf_w            equ     XF_DPPAGE*256+9
xf_t            equ     XF_DPPAGE*256+10
xf_n            equ     XF_DPPAGE*256+11
xf_g            equ     XF_DPPAGE*256+12
xf_o            equ     XF_DPPAGE*256+13
xf_oc           equ     XF_DPPAGE*256+14        ; P5.34: the OPACITY carry (op = 11 where opaque)
xf_cc           equ     XF_DPPAGE*256+15        ; P5.34: the colour carry, parked while A does op
xf_fff          equ     XF_DPPAGE*256+16        ; P5.34: F[$FF] of this call's pair -- a blast byte's op
xf_cff          equ     XF_DPPAGE*256+17        ; P5.34: C[$FF] -- a blast's opacity carry out

* --- the per-byte bodies. Y = F table, S = C table, A = carry, X = dest, U = segment ---
* _D: an interior blast byte, opaque by construction -- stored directly. (Unchanged at P5.34.)
* _B: a blast's FIRST output byte (its carry came from whatever preceded it): op_out =
*     op_carry | F[$FF], read-modify-write through M[op_out]. \2 names the patched instruction.
* _M: a merge byte: op = ~mask through the same F/C as the colour; M[op_out]; op_carry' = C[op].
* The colour carry is parked in xf_cc while A computes the opacity, and restored at the end.
* Every instance needs its own \label, since each patches its own operand.
XA_D            macro
                ldb     \1,u
                ora     b,y
                sta     ,x+
                lda     b,s
                endm
XA_B            macro
                ldb     \1,u
                ora     b,y                     ; A = colour out
                sta     <xf_o
                lda     b,s
                sta     <xf_cc                  ; the colour carry, parked
                lda     <xf_oc
                ora     <xf_fff                 ; op_out = op_carry | F[$FF]
                sta     \2+2
                ldb     ,x
\2              andb    >XF_M                   ; M[op_out] = ~op_out
                orb     <xf_o
                stb     ,x+
                lda     <xf_cc
                endm
XA_M            macro
                ldb     1,u                     ; src
                ora     b,y                     ; A = colour out
                sta     <xf_o
                lda     b,s
                sta     <xf_cc
                ldb     ,u                      ; mask
                comb                            ; op = ~mask: 11 where the cel is opaque
                lda     b,y
                ora     <xf_oc                  ; op_out = op_carry | F[op]
                sta     \1+2
                lda     b,s
                sta     <xf_oc                  ; op_carry' = C[op]
                ldb     ,x
\1              andb    >XF_M
                orb     <xf_o
                stb     ,x+
                lda     <xf_cc
                endm
XD_D            macro
                ldb     \1,u
                ora     b,y
                sta     ,-x
                lda     b,s
                endm
XD_B            macro
                ldb     \1,u
                ora     b,y
                sta     <xf_o
                lda     b,s
                sta     <xf_cc
                lda     <xf_oc
                ora     <xf_fff
                sta     \2+2
                ldb     ,-x
\2              andb    >XF_M
                orb     <xf_o
                stb     ,x
                lda     <xf_cc
                endm
XD_M            macro
                ldb     1,u
                ora     b,y
                sta     <xf_o
                lda     b,s
                sta     <xf_cc
                ldb     ,u
                comb
                lda     b,y
                ora     <xf_oc
                sta     \1+2
                lda     b,s
                sta     <xf_oc
                ldb     ,-x
\1              andb    >XF_M
                orb     <xf_o
                stb     ,x
                lda     <xf_cc
                endm
* --- the per-row IRQ/FIRQ window (P4.29), WITH DP = 0 FOR ITS DURATION (P5.31) ---
* ★ The HAL's VBL handler increments its frame counter through the direct page and documents a
* "DP=0 invariant" [irq_vbl.s:21-22, 79]. This routine runs with DP = XF_DPPAGE, so a VBL that
* landed in the window used to increment XF_DPPAGE*256+$11 instead of $0011: the tick was LOST
* (P5.31's running kid measured steps of 5-8 frames against a requested 6) and a byte outside
* the routine's own 14 was written. Found by the first caller that paces itself on that counter.
* A is free at every row end (each row reloads it), so it carries the DP value: +16 cy per row.
XF_WINDOW       macro
                clra
                tfr     a,dp                    ; DP = 0: what an interrupt handler may assume
                andcc   #$AF
                orcc    #$50
                lda     #XF_DPPAGE
                tfr     a,dp                    ; and ours again
                endm
* mirror alone: no carry, no shift -- Y = T
M0_D            macro
                ldb     \1,u
                lda     b,y
                sta     ,-x
                endm

* ---------------------------------------------------------------
* xf_blit — draw a phase-0 facing-0 stream at phase k, optionally mirrored.
*
*   Entry: X = the output frame's byte 0, top row
*          U = stream: rows, width, segments (cel_blit_prep.py format)
*          A = k, 0..3
*          B = flags: bit0 mirror, bit1 blue<->orange swap -- with OR without the mirror
*              (P5.29: the oracle picks the colour phase per frame and per facing, so an
*              UNMIRRORED draw can need the swap too; see char_probe.s for the rule)
*   Exit:  A,B,X,Y,U clobbered. CC and DP restored.
*
* The output frame is w+1 bytes when k > 0 (the last carry lands in byte w), w when k = 0.
* A mirrored draw reverses the frame's 4w pixels; registering it against the oracle's
* mirror is the CALLER's arithmetic (the frame's pad, 4w - 7*apple_w), the same way the
* phase is: this routine draws a frame, it does not place a character.
* ---------------------------------------------------------------
xf_blit
                tsta
                bne     xf_go
                tstb
                bne     xf_go
                jmp     blit_cel_full           ; k=0 unmirrored: the stored bake IS the answer
xf_go
                pshs    cc,dp
                orcc    #$50
                sta     xf_k_x                  ; before DP is ours
                stb     xf_fl_x
                lda     #XF_DPPAGE
                tfr     a,dp
* Every direct-page operand below is forced with `<`, so the encoding does not depend on
* SETDP; lwasm refuses SETDP in an object target, and the probe's absolute build keeps it.
                ifndef  OBJTARGET
                setdp   XF_DPPAGE
                endc
                sts     <xf_ss
                stx     <xf_rowbase
                ldd     ,u++                    ; A = rows, B = width
                sta     <xf_rows
                stb     <xf_w
* t = 0 plain, 1 mirror, 2 mirror+swap, 3 swap alone (P5.29)
                lda     xf_fl_x
                anda    #1
                bne     xf_t_m
                lda     xf_fl_x
                anda    #2
                beq     xf_t_ok                 ; A = 0: plain
                lda     #3
                sta     <xf_t
                bra     xf_swap
xf_t_m          lda     xf_fl_x
                lsra
                anda    #1
                inca                            ; 1 or 2
xf_t_ok         sta     <xf_t
                lda     xf_k_x
                lbeq    xm0_go                  ; k=0 and mirrored
* pair index p = (k-1)*3 + t
                deca
                tfr     a,b
                lsla
                pshs    b
                adda    ,s+                     ; 3*(k-1)
                adda    <xf_t
                ldy     #xf_ptab
                lsla
                ldy     a,y                     ; F table base (+128 bias already in)
                tfr     y,d
                adda    #1                      ; C = F + 256
                std     <xf_ctab
                bsr     xf_consts               ; P5.34: F[$FF], C[$FF] (S is still the real stack)
                lda     <xf_t
                lbne    xd_go                   ; mirrored -> descending writes
                lds     <xf_ctab
                lbra    xa_row

* --- swap alone (t = 3, P5.29): pair 9+k through the SAME ascending loop. For k = 0 the
* pair is F = S (the swap) and C = 0, so the loop's carry is always zero and the frame is w
* bytes, not w+1: an unshifted swapped draw with no loop of its own to verify. Every byte the
* loop treats as possibly partial still goes through M, so a merge keeps its background.
xf_swap         lda     xf_k_x
                adda    #9
                ldy     #xf_ptab
                lsla
                ldy     a,y
                tfr     y,d
                adda    #1                      ; C = F + 256
                std     <xf_ctab
                bsr     xf_consts
                lds     <xf_ctab
                lbra    xa_row

* --- P5.34: this call's pair's F[$FF] and C[$FF] -- a blast byte's opacity in and out. Y = F
* base (+128 bias), xf_ctab = C base (same bias); B = $FF is index -1 through the bias. X is
* free here (the frame base is already in xf_rowbase). Called before S becomes a table.
xf_consts       ldb     #$FF
                lda     b,y
                sta     <xf_fff
                ldx     <xf_ctab
                lda     b,x
                sta     <xf_cff
                rts

* ===============================================================
* ASCENDING (shift, facing 0). X walks the output row upward.
* ===============================================================
xa_row
                ldx     <xf_rowbase
                clra                            ; no carry into byte 0
                clr     <xf_oc                  ; ... colour or opacity
xa_seg
                ldb     ,u+
                lbeq    xa_end
                cmpb    #$80
                bhs     xa_bm
* --- skip n: flush a pending carry into the first skipped byte, then step over the rest.
* P5.34: pending means the OPACITY carry is non-zero -- a carried half of pure border is colour 0.
                subb    #$40                    ; n
                tst     <xf_oc
                beq     xa_sk0
                stb     <xf_n
                ldb     <xf_oc
                stb     xa_mpk+2                ; M[op_carry]
                sta     <xf_o
                ldb     ,x
xa_mpk          andb    >XF_M
                orb     <xf_o
                stb     ,x
                ldb     <xf_n
xa_sk0          abx                             ; unsigned
                clra
                clr     <xf_oc
                bra     xa_seg
xa_bm           cmpb    #$C0
                lbhs    xa_merge
* --- blast n: body read ascending -- the tail first, then the groups backwards
                subb    #$80
                stb     <xf_n
                leau    b,u                     ; U = this segment's end (n <= 63, signed-safe)
                stu     <xf_send
                andb    #3
                lbeq    xa_r0                   ; P5.34: long -- the opacity macros grew the bodies
                cmpb    #2
                blo     xa_r1
                beq     xa_r2
xa_r3           XA_B    -1,xa_mp3               ; body0 is the tail's LAST byte: [1,2,0]
                XA_D    -3
                XA_D    -2
                leau    -3,u
                bra     xa_grps
xa_r2           XA_B    -2,xa_mp2
                XA_D    -1
                leau    -2,u
                bra     xa_grps
xa_r1           XA_B    -1,xa_mp1
                leau    -1,u
xa_grps         ldb     <xf_n
                lsrb
                lsrb
                bra     xa_g
xa_r0           XA_B    -4,xa_mp0               ; no tail: body0 opens the last group
                XA_D    -3
                XA_D    -2
                XA_D    -1
                leau    -4,u
                ldb     <xf_n
                lsrb
                lsrb
                decb
xa_g            beq     xa_bdone
                stb     <xf_g
xa_glp          leau    -4,u
                XA_D    0
                XA_D    1
                XA_D    2
                XA_D    3
                dec     <xf_g
                bne     xa_glp
xa_bdone        ldu     <xf_send
                ldb     <xf_cff                 ; P5.34: a blast's opacity carry out, a constant
                stb     <xf_oc
                lbra    xa_seg
* --- merge n: every byte can be partial
xa_merge        subb    #$C0
                stb     <xf_n
xa_mlp          XA_M    xa_mpm
                leau    2,u
                dec     <xf_n
                bne     xa_mlp
                lbra    xa_seg
* --- end of row: the last carry is the frame's extra byte (P5.34: if any of it is OPAQUE)
xa_end          tst     <xf_oc
                beq     xa_next
                ldb     <xf_oc
                stb     xa_mpe+2
                sta     <xf_o
                ldb     ,x
xa_mpe          andb    >XF_M
                orb     <xf_o
                stb     ,x
xa_next         ldx     <xf_rowbase
                leax    FB_STRIDE_XF,x
                stx     <xf_rowbase
                lds     <xf_ss                  ; the P4.29 window needs the real stack
                XF_WINDOW                       ; ... and DP = 0 (P5.31, see the macro)
                lds     <xf_ctab
                dec     <xf_rows
                lbne    xa_row
                lbra    xf_exit

* ===============================================================
* DESCENDING (mirror, k > 0). X starts one past output byte w and pre-decrements.
* ===============================================================
xd_go
                lds     <xf_ctab
                ldd     <xf_rowbase
                addb    <xf_w
                adca    #0
                addd    #1
                std     <xf_rowbase             ; the mirrored frame is written right to left
xd_row
                ldx     <xf_rowbase
                clra
                clr     <xf_oc
xd_seg
                ldb     ,u+
                lbeq    xd_end
                cmpb    #$80
                bhs     xd_bm
                subb    #$40
                tst     <xf_oc                  ; P5.34: the OPACITY carry decides the flush
                beq     xd_sk0
                stb     <xf_n
                ldb     <xf_oc
                stb     xd_mpk+2
                sta     <xf_o
                ldb     ,-x
xd_mpk          andb    >XF_M
                orb     <xf_o
                stb     ,x
                ldb     <xf_n
                decb
xd_sk0          negb
                leax    b,x                     ; n <= 63, so -n is a valid signed offset
                clra
                clr     <xf_oc
                bra     xd_seg
xd_bm           cmpb    #$C0
                lbhs    xd_merge
                subb    #$80
                stb     <xf_n
                leau    b,u
                stu     <xf_send
                andb    #3
                lbeq    xd_r0
                cmpb    #2
                blo     xd_r1
                beq     xd_r2
xd_r3           XD_B    -1,xd_mp3
                XD_D    -3
                XD_D    -2
                leau    -3,u
                bra     xd_grps
xd_r2           XD_B    -2,xd_mp2
                XD_D    -1
                leau    -2,u
                bra     xd_grps
xd_r1           XD_B    -1,xd_mp1
                leau    -1,u
xd_grps         ldb     <xf_n
                lsrb
                lsrb
                bra     xd_g
xd_r0           XD_B    -4,xd_mp0
                XD_D    -3
                XD_D    -2
                XD_D    -1
                leau    -4,u
                ldb     <xf_n
                lsrb
                lsrb
                decb
xd_g            beq     xd_bdone
                stb     <xf_g
xd_glp          leau    -4,u
                XD_D    0
                XD_D    1
                XD_D    2
                XD_D    3
                dec     <xf_g
                bne     xd_glp
xd_bdone        ldu     <xf_send
                ldb     <xf_cff                 ; P5.34: the blast's opacity carry out
                stb     <xf_oc
                lbra    xd_seg
xd_merge        subb    #$C0
                stb     <xf_n
xd_mlp          XD_M    xd_mpm
                leau    2,u
                dec     <xf_n
                bne     xd_mlp
                lbra    xd_seg
xd_end          tst     <xf_oc
                beq     xd_next
                ldb     <xf_oc
                stb     xd_mpe+2
                sta     <xf_o
                ldb     ,-x
xd_mpe          andb    >XF_M
                orb     <xf_o
                stb     ,x
xd_next         ldx     <xf_rowbase
                leax    FB_STRIDE_XF,x
                stx     <xf_rowbase
                lds     <xf_ss
                XF_WINDOW
                lds     <xf_ctab
                dec     <xf_rows
                lbne    xd_row
                lbra    xf_exit

* ===============================================================
* MIRROR ALONE (k = 0). No carry, so the segment structure survives intact: a skip is a
* skip, a blast is all-opaque bytes, a merge's own (mask,src) pair is still right once
* both go through T -- the swap maps 3->3 and 0->0, so T of a mask is the mirrored mask.
* S stays the real stack, so the row window is blit_cel's six cycles.
* ===============================================================
xm0_go
                lda     <xf_t
                cmpa    #2
                beq     xm0_t2
                ldy     #XF_T1+128
                bra     xm0_t
xm0_t2          ldy     #XF_T2+128
xm0_t           ldd     <xf_rowbase
                addb    <xf_w
                adca    #0
                std     <xf_rowbase             ; frame of w bytes, written right to left
xm0_row
                ldx     <xf_rowbase
xm0_seg
                ldb     ,u+
                lbeq    xm0_next
                cmpb    #$80
                bhs     xm0_bm
                subb    #$40
                negb
                leax    b,x
                bra     xm0_seg
xm0_bm          cmpb    #$C0
                bhs     xm0_merge
                subb    #$80
                stb     <xf_n
                leau    b,u
                stu     <xf_send
                andb    #3
                beq     xm0_r0
                cmpb    #2
                blo     xm0_r1
                beq     xm0_r2
xm0_r3          M0_D    -1
                M0_D    -3
                M0_D    -2
                leau    -3,u
                bra     xm0_grps
xm0_r2          M0_D    -2
                M0_D    -1
                leau    -2,u
                bra     xm0_grps
xm0_r1          M0_D    -1
                leau    -1,u
xm0_grps        ldb     <xf_n
                lsrb
                lsrb
                bra     xm0_g
xm0_r0          ldb     <xf_n
                lsrb
                lsrb
xm0_g           beq     xm0_bdone
                stb     <xf_g
xm0_glp         leau    -4,u
                M0_D    0
                M0_D    1
                M0_D    2
                M0_D    3
                dec     <xf_g
                bne     xm0_glp
xm0_bdone       ldu     <xf_send
                lbra    xm0_seg
xm0_merge       subb    #$C0
                stb     <xf_n
xm0_mlp         ldb     ,u                      ; mask
                lda     b,y                     ; T[mask]
                anda    ,-x                     ; keep the background where the cel is clear
                ldb     1,u                     ; src
                ora     b,y                     ; T[src]
                sta     ,x
                leau    2,u
                dec     <xf_n
                bne     xm0_mlp
                lbra    xm0_seg
xm0_next        ldx     <xf_rowbase
                leax    FB_STRIDE_XF,x
                stx     <xf_rowbase
                XF_WINDOW
                dec     <xf_rows
                lbne    xm0_row

xf_exit
                lds     <xf_ss
                puls    cc,dp,pc
                ifndef  OBJTARGET
                setdp   0                       ; the includer's code that follows is not ours
                endc

* the F-table base for each (k, t): F at XF_TABS + 512*p, biased +128 for signed indexing
xf_ptab         fdb     XF_TABS+0*512+128,XF_TABS+1*512+128,XF_TABS+2*512+128
                fdb     XF_TABS+3*512+128,XF_TABS+4*512+128,XF_TABS+5*512+128
                fdb     XF_TABS+6*512+128,XF_TABS+7*512+128,XF_TABS+8*512+128
* P5.29: the swap-only pairs, k = 0..3
                fdb     XF_TABS+9*512+128,XF_TABS+10*512+128,XF_TABS+11*512+128
                fdb     XF_TABS+12*512+128

xf_k_x          rmb     1
xf_fl_x         rmb     1
