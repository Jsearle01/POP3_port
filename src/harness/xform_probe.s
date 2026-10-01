* src/harness/xform_probe.s
*
* POP CoCo3 — P5.20: THE SHIFTED AND MIRRORED BLIT, AS A HARNESS PROBE. NOT INTEGRATED.
*
* ---------------------------------------------------------------
* WHAT THIS IS
* ---------------------------------------------------------------
* xf_blit draws a cel stored ONCE -- phase 0, facing 0, in the shipped segment format
* (cel_blit_prep.py) -- at any of the four sub-byte phases and either facing. It exists to
* turn two estimates into measurements: P5.10's ~14 cy/byte shift and P5.11's 6.8 / 20.6
* cy/byte mirror and joint. Nothing in the port links it; build.bat does not assemble it;
* it is poked and timed by harness/tools/xform_probe.lua and is not a launch-path artifact.
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
* THE `$80` PRE-REVERSAL (P5.20 AC1 -- answered BEFORE this file existed, commit e6b83d8)
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
* Transparency is index 0 with no sidecar (P3.18 3B), so a merge's (mask,src) pair carries
* nothing the src byte does not: the transparent pixels of src are already zero. An output
* byte is therefore written as  dest = (dest AND M[out]) OR out,  M = "11 where the pixel
* is 0". Only bytes that CAN be partial pay that: every merge byte, the FIRST byte of a
* blast (its carry came from whatever preceded it), a skip's first byte when a carry is
* pending, and the row's final carry. Interior blast bytes are opaque by construction and
* are stored directly.
*
* M is reached by a SELF-MODIFIED extended operand (`andb >XF_M` with its low byte
* patched), because the loop already holds all four pointers -- X dest, U source, Y and S
* the two tables -- and M would be a fifth. M is page-aligned so the low byte IS the index.
*
* ---------------------------------------------------------------
* S IS A TABLE POINTER, so interrupts are masked, exactly as blit_blast borrows S. The
* per-row IRQ/FIRQ window blit_cel opens (P4.29) is reproduced here, at the cost of putting
* the real stack back for it: `lds` / `andcc` / `orcc` / `lds`, 16 cy/row. It is kept
* because an integrated routine would need it for the music FIRQ, and a probe that omitted
* it would measure a routine the port could not ship.
* ---------------------------------------------------------------

FB_STRIDE_XF    equ     80

* --- the per-byte bodies. Y = F table, S = C table, A = carry, X = dest, U = segment ---
* _D: an interior blast byte, opaque by construction -- stored directly.
* _R: a byte that may be partial -- read-modify-write through M. \2 names the patched
*     instruction; every instance needs its own, since each patches itself.
XA_D            macro
                ldb     \1,u
                ora     b,y
                sta     ,x+
                lda     b,s
                endm
XA_R            macro
                ldb     \1,u
                ora     b,y
                sta     \2+2
                sta     <xf_o
                lda     b,s
                ldb     ,x
\2              andb    >XF_M
                orb     <xf_o
                stb     ,x+
                endm
XD_D            macro
                ldb     \1,u
                ora     b,y
                sta     ,-x
                lda     b,s
                endm
XD_R            macro
                ldb     \1,u
                ora     b,y
                sta     \2+2
                sta     <xf_o
                lda     b,s
                ldb     ,-x
\2              andb    >XF_M
                orb     <xf_o
                stb     ,x
                endm
* mirror alone: no carry, no shift -- Y = T
M0_D            macro
                ldb     \1,u
                lda     b,y
                sta     ,-x
                endm

* --- fixed probe layout (the generator and the Lua agree on these) ---------------
XP_HS           equ     $1F00           ; status, go, then the cycle count (4, big-endian)
XP_STATUS       equ     XP_HS+0         ; 1 = a case is done and waiting; 2 = all done
XP_GO           equ     XP_HS+1         ; Lua sets it to release the next case
XP_CYC          equ     XP_HS+4         ; written by the debugger's bp action, not by code
XP_STACK        equ     $1F00
XF_DPPAGE       equ     $2C
XF_M            equ     $2D00           ; 256 B, natural order: M[b] = 11 per zero pixel
XF_T1           equ     $2E00           ; mirror, permuted (index b^$80), use base+128
XF_T2           equ     $2F00           ; mirror + blue<->orange swap, permuted
XF_TABS         equ     $3000           ; 9 pairs x 512 B: (k-1)*3+t, F then C, permuted
XP_CASES        equ     $4200           ; generated: 8-byte records, then the streams
XP_BUF          equ     $6C00           ; the destination, 80-byte stride (64 rows to $8000;
*                                         the tallest gameplay cel is 57, CHTAB2 #41)

                org     $2000
* ---------------------------------------------------------------
* THE DRIVER. One case per handshake: fill the destination with a hostile background,
* call, mark done, wait for the Lua to dump and release. The debugger brackets the call
* (bp at xp_call / xp_ret, action `pd@XP_CYC = totalcycles - temp0`), so the cycle count
* is the built binary's own, executed -- not a count of this source.
* ---------------------------------------------------------------
xp_entry
                orcc    #$50
                lds     #XP_STACK
* Silence every interrupt SOURCE, not just the mask: blit_cel opens an IRQ window on every
* row (andcc #$AF), so a masked CC alone would let BASIC's 60 Hz IRQ land inside a timed
* baseline. These are PIA registers -- outside the register ratchet's $FF80-$FFDF scope
* (register_owner_check.py:56).
                lda     $FF01
                anda    #$FE
                sta     $FF01
                lda     $FF03
                anda    #$FE
                sta     $FF03
                lda     $FF21
                anda    #$FE
                sta     $FF21
                lda     $FF23
                anda    #$FE
                sta     $FF23
                lda     $FF00                   ; clear any latched flags
                lda     $FF02
                lda     $FF20
                lda     $FF22
                clr     XP_STATUS
                clr     XP_GO
                ldy     #XP_CASES
xp_next
                sty     xp_cur
                ldd     ,y
                beq     xp_alldone
                lbsr    xp_fill
                ldy     xp_cur
                ldx     4,y
                ldu     2,y
                lda     6,y
                ldb     7,y
xp_call         jsr     [,y]
xp_ret          lda     #1
                sta     XP_STATUS
xp_wait         lda     XP_GO
                beq     xp_wait
                clr     XP_GO
                ldy     xp_cur
                leay    10,y                    ; fn, stream, dest, A, B, dump length
                bra     xp_next
xp_alldone
                lda     #2
                sta     XP_STATUS
xp_halt         bra     xp_halt

* The background: bg[o] = $5B + $9D*o (mod 256) over the whole buffer. $9D is odd, so every
* byte value appears and every pixel position sees every index -- a mask that keeps the
* wrong pixel cannot hide behind a uniform fill. xform_probe_gen.py computes the same.
xp_fill
                ldx     #XP_BUF
                lda     #$5B
xp_fill_lp      sta     ,x+
                adda    #$9D
                cmpx    #XP_BUF+XP_BUFLEN
                blo     xp_fill_lp
                rts

* The calibration case: what the bracket costs with no routine inside it.
xp_null         rts

xp_cur          rmb     2

* ---------------------------------------------------------------
* xf_blit — draw a phase-0 facing-0 stream at phase k, optionally mirrored.
*
*   Entry: X = the output frame's byte 0, top row
*          U = stream: rows, width, segments (cel_blit_prep.py format)
*          A = k, 0..3
*          B = flags: bit0 mirror, bit1 blue<->orange swap (with mirror)
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
                setdp   XF_DPPAGE
                sts     <xf_ss
                stx     <xf_rowbase
                ldd     ,u++                    ; A = rows, B = width
                sta     <xf_rows
                stb     <xf_w
* t = 0 plain, 1 mirror, 2 mirror+swap
                lda     xf_fl_x
                anda    #1
                beq     xf_t_ok
                lda     xf_fl_x
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
                lda     <xf_t
                lbne    xd_go                   ; mirrored -> descending writes
                lds     <xf_ctab
                lbra    xa_row

* ===============================================================
* ASCENDING (shift, facing 0). X walks the output row upward.
* ===============================================================
xa_row
                ldx     <xf_rowbase
                clra                            ; no carry into byte 0
xa_seg
                ldb     ,u+
                lbeq    xa_end
                cmpb    #$80
                bhs     xa_bm
* --- skip n: flush a pending carry into the first skipped byte, then step over the rest
                subb    #$40                    ; n
                tsta
                beq     xa_sk0
                stb     <xf_n
                sta     xa_mpk+2
                sta     <xf_o
                ldb     ,x
xa_mpk          andb    >XF_M
                orb     <xf_o
                stb     ,x
                ldb     <xf_n
xa_sk0          abx                             ; unsigned
                clra
                bra     xa_seg
xa_bm           cmpb    #$C0
                lbhs    xa_merge
* --- blast n: body read ascending -- the tail first, then the groups backwards
                subb    #$80
                stb     <xf_n
                leau    b,u                     ; U = this segment's end (n <= 63, signed-safe)
                stu     <xf_send
                andb    #3
                beq     xa_r0
                cmpb    #2
                blo     xa_r1
                beq     xa_r2
xa_r3           XA_R    -1,xa_mp3               ; body0 is the tail's LAST byte: [1,2,0]
                XA_D    -3
                XA_D    -2
                leau    -3,u
                bra     xa_grps
xa_r2           XA_R    -2,xa_mp2
                XA_D    -1
                leau    -2,u
                bra     xa_grps
xa_r1           XA_R    -1,xa_mp1
                leau    -1,u
xa_grps         ldb     <xf_n
                lsrb
                lsrb
                bra     xa_g
xa_r0           XA_R    -4,xa_mp0               ; no tail: body0 opens the last group
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
                lbra    xa_seg
* --- merge n: every byte can be partial
xa_merge        subb    #$C0
                stb     <xf_n
xa_mlp          XA_R    1,xa_mpm
                leau    2,u
                dec     <xf_n
                bne     xa_mlp
                lbra    xa_seg
* --- end of row: the last carry is the frame's extra byte
xa_end          tsta
                beq     xa_next
                sta     xa_mpe+2
                sta     <xf_o
                ldb     ,x
xa_mpe          andb    >XF_M
                orb     <xf_o
                stb     ,x
xa_next         ldx     <xf_rowbase
                leax    FB_STRIDE_XF,x
                stx     <xf_rowbase
                lds     <xf_ss                  ; the P4.29 window needs the real stack
                andcc   #$AF
                orcc    #$50
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
xd_seg
                ldb     ,u+
                lbeq    xd_end
                cmpb    #$80
                bhs     xd_bm
                subb    #$40
                tsta
                beq     xd_sk0
                stb     <xf_n
                sta     xd_mpk+2
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
                bra     xd_seg
xd_bm           cmpb    #$C0
                lbhs    xd_merge
                subb    #$80
                stb     <xf_n
                leau    b,u
                stu     <xf_send
                andb    #3
                beq     xd_r0
                cmpb    #2
                blo     xd_r1
                beq     xd_r2
xd_r3           XD_R    -1,xd_mp3
                XD_D    -3
                XD_D    -2
                leau    -3,u
                bra     xd_grps
xd_r2           XD_R    -2,xd_mp2
                XD_D    -1
                leau    -2,u
                bra     xd_grps
xd_r1           XD_R    -1,xd_mp1
                leau    -1,u
xd_grps         ldb     <xf_n
                lsrb
                lsrb
                bra     xd_g
xd_r0           XD_R    -4,xd_mp0
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
                lbra    xd_seg
xd_merge        subb    #$C0
                stb     <xf_n
xd_mlp          XD_R    1,xd_mpm
                leau    2,u
                dec     <xf_n
                bne     xd_mlp
                lbra    xd_seg
xd_end          tsta
                beq     xd_next
                sta     xd_mpe+2
                sta     <xf_o
                ldb     ,-x
xd_mpe          andb    >XF_M
                orb     <xf_o
                stb     ,x
xd_next         ldx     <xf_rowbase
                leax    FB_STRIDE_XF,x
                stx     <xf_rowbase
                lds     <xf_ss
                andcc   #$AF
                orcc    #$50
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
                andcc   #$AF
                orcc    #$50
                dec     <xf_rows
                lbne    xm0_row

xf_exit
                lds     <xf_ss
                puls    cc,dp,pc

* the F-table base for each (k, t): F at XF_TABS + 512*p, biased +128 for signed indexing
xf_ptab         fdb     XF_TABS+0*512+128,XF_TABS+1*512+128,XF_TABS+2*512+128
                fdb     XF_TABS+3*512+128,XF_TABS+4*512+128,XF_TABS+5*512+128
                fdb     XF_TABS+6*512+128,XF_TABS+7*512+128,XF_TABS+8*512+128

xf_k_x          rmb     1
xf_fl_x         rmb     1

* --- the shipped blitter, assembled from the SAME source, for the baseline cases ---------
                include "src/engine/blit_core.s"

xp_code_end
                ifgt    xp_code_end-(XF_DPPAGE*256)
                error   "probe code overruns the DP page"
                endc

* --- the direct page --------------------------------------------------------------
                org     XF_DPPAGE*256
xf_ss           rmb     2
xf_rowbase      rmb     2
xf_ctab         rmb     2
xf_send         rmb     2
xf_rows         rmb     1
xf_w            rmb     1
xf_t            rmb     1
xf_n            rmb     1
xf_g            rmb     1
xf_o            rmb     1

* --- generated: tables, case records, streams, XP_BUFLEN ---------------------------
                include "build/xform/xf_gen.s"

                end     xp_entry
