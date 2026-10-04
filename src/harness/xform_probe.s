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
XP_CASES        equ     $4200           ; generated: 12-byte records, then the streams
XP_PEEL         equ     $1800           ; P5.21: the peel buffer handed to blit_save/erase in Y
XP_PEEL_END     equ     $1C00           ;   (1 KB; the generator refuses a pose that needs more)
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
                std     xp_fn
                lda     10,y                    ; P5.21: the fill seed is per case, so an
                sta     xp_seed                 ;   erase lands on a DIFFERENT background
                lbsr    xp_fill                 ;   from the save it restores
                ldy     xp_cur
                ldx     4,y
                ldu     2,y
                lda     6,y
                ldb     7,y
                ldy     #XP_PEEL                ; blit_save/blit_erase take the peel in Y;
*                                                 the draws ignore it
xp_call         jsr     [xp_fn]
xp_ret          lda     #1
                sta     XP_STATUS
xp_wait         lda     XP_GO
                beq     xp_wait
                clr     XP_GO
                ldy     xp_cur
                leay    12,y                    ; fn, stream, dest, A, B, dump length, seed, pad
                bra     xp_next
xp_alldone
                lda     #2
                sta     XP_STATUS
xp_halt         bra     xp_halt

* The background: bg[o] = seed + $9D*o (mod 256) over the whole buffer (seed $5B unless the
* case record says otherwise). $9D is odd, so every
* byte value appears and every pixel position sees every index -- a mask that keeps the
* wrong pixel cannot hide behind a uniform fill. xform_probe_gen.py computes the same.
xp_fill
                ldx     #XP_BUF
                lda     xp_seed                 ; $5B for every P5.20 case
xp_fill_lp      sta     ,x+
                adda    #$9D
                cmpx    #XP_BUF+XP_BUFLEN
                blo     xp_fill_lp
                rts

* The calibration case: what the bracket costs with no routine inside it.
xp_null         rts

xp_cur          rmb     2
xp_fn           rmb     2
xp_seed         rmb     1

* ---------------------------------------------------------------
* xf_blit -- the routine itself lives in src/engine/xf_blit.s since P5.28 (ONE home: the
* first engine program to draw with it links that file, and this probe includes the same
* text). Its layout inputs are the XF_* equates above; its direct page is XF_DPPAGE's.
* ---------------------------------------------------------------
                include "src/engine/xf_blit.s"

* --- the shipped blitter, assembled from the SAME source, for the baseline cases ---------
                include "src/engine/blit_core.s"

* --- P5.22: the shipped LZ expander, timed on real gameplay-class blobs (X = out, U = blob) ---
                include "src/engine/lz_unpack.s"

xp_code_end
                ifgt    xp_code_end-(XF_DPPAGE*256)
                error   "probe code overruns the DP page"
                endc

* --- generated: tables, case records, streams, XP_BUFLEN ---------------------------
                include "build/xform/xf_gen.s"

                end     xp_entry
