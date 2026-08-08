* src/engine/shift_row.s
*
* POP CoCo3 — THE RUNTIME SUB-BYTE SHIFT LOOP (P3.36 written, P3.39 assembled).
*
* ---------------------------------------------------------------
* WHAT THIS IS FOR
* ---------------------------------------------------------------
* The cel-representation decision rests on this loop's real cost. P3.36 wrote it and
* counted 30 cy/byte unrolled, ~34 all-in on real rows; P3.38b then found the
* deciding frame needs only 275 drawn bytes, which put the frame at 98% of budget --
* a 2.3% margin resting on a COUNT of a sketch with seven elided rungs.
*
* P3.39 assembles it. A counted rate is not a measured one, and this project has had
* four carried figures corrected in a row.
*
* ---------------------------------------------------------------
* THE THREE THINGS THAT MAKE IT AS FAST AS IT IS
* ---------------------------------------------------------------
* 1. TABLES, NOT SHIFTS. An in-register 2-bit shift costs 8 cy at phase 1 and 24 at
*    phase 3, and must produce BOTH halves (the in-byte part and the spill). Two
*    lookups cost 10 cy flat at every phase.
*
* 2. A PERMUTED TABLE, because accumulator-offset indexing is SIGNED. `ldb a,y` reads
*    Y+A with A as a SIGNED byte, so a straight 256-entry table indexes backwards for
*    every value above 127 -- a correctness trap, not a speed one. The tables are
*    emitted rotated by 128 ($80..$FF first, then $00..$7F) with the bases biased
*    +128, so all 256 values are correct at the same 5 cycles, free at run time.
*
* 3. S AS A FOURTH POINTER. The loop needs four at once -- source, destination, SHR
*    table, SHL table -- and the 6809 has three index registers. S carries the SHL
*    base with interrupts masked, exactly as blit_blast borrows S for its
*    destination.
*
* AND THE ONE THAT CANNOT BE REMOVED: there is no register-to-register OR on the 6809
* (no `orb a`). The previous byte's spill must travel through memory -- `orb <sr_carry`
* / `stb <sr_carry` -- costing 8 cy per byte, 27% of the loop. It is the same
* constraint that makes the merge path a 22 cy/byte floor (P3.19).
*
* ---------------------------------------------------------------
* THE COUNT, per byte
* ---------------------------------------------------------------
*     lda     ,x+          6    the source byte
*     ldb     a,y          5    SHR[src] -- the in-byte part
*     orb     sr_carry    4    the previous byte's spill
*     stb     ,u+          6    the shifted byte
*     ldb     a,s          5    SHL[src] -- this byte's spill
*     stb     sr_carry    4    carried into the next iteration
*                         30 cy/byte, unrolled
*
* Entry: X = source row, U = destination, B = byte count (1..9),
*        interrupts masked by the caller.
* Exit:  the shifted row at U, one byte longer than the source.
* ---------------------------------------------------------------

                ifdef   OBJTARGET
                section prog
                export  shift_row
                export  sr_shr_tab
                export  sr_shl_tab
                endc

SR_MAXW         equ     9               ; widest cutscene cel row + the spill byte

shift_row
                sts     sr_saved_s              ; 7   park the real stack
                ldy     #sr_shr_tab+128         ; 4   the signed-index bias
                lds     #sr_shl_tab+128         ; 4
                clr     sr_carry               ; 6   nothing spills into byte 0
* Dispatch by width through a table of addresses rather than by arithmetic on the
* rung size: a rung is six instructions of differing lengths, so scaling the width by
* a constant would be wrong the moment an instruction's encoding changed.
                lslb                            ; 2   two bytes per entry
                ldx     #sr_jmptab              ; 3
                abx                             ; 3
                ldx     ,x                      ; 5
                jmp     ,x                      ; 3   ~37 cy of per-row setup

sr_jmptab       fdb     sr_done                 ; width 0 — nothing to do
                fdb     sr_w1,sr_w2,sr_w3,sr_w4
                fdb     sr_w5,sr_w6,sr_w7,sr_w8,sr_w9

* The unrolled ladder. A row of n bytes enters at sr_wN and falls through the
* remaining rungs, so the whole row runs without loop control -- which is worth 9 cy
* per byte (dec 6 + bne 3), 23% of a rolled loop, on rows that are only 4-9 bytes.
sr_w9           lda     ,x+
                ldb     a,y
                orb     sr_carry
                stb     ,u+
                ldb     a,s
                stb     sr_carry
sr_w8           lda     ,x+
                ldb     a,y
                orb     sr_carry
                stb     ,u+
                ldb     a,s
                stb     sr_carry
sr_w7           lda     ,x+
                ldb     a,y
                orb     sr_carry
                stb     ,u+
                ldb     a,s
                stb     sr_carry
sr_w6           lda     ,x+
                ldb     a,y
                orb     sr_carry
                stb     ,u+
                ldb     a,s
                stb     sr_carry
sr_w5           lda     ,x+
                ldb     a,y
                orb     sr_carry
                stb     ,u+
                ldb     a,s
                stb     sr_carry
sr_w4           lda     ,x+
                ldb     a,y
                orb     sr_carry
                stb     ,u+
                ldb     a,s
                stb     sr_carry
sr_w3           lda     ,x+
                ldb     a,y
                orb     sr_carry
                stb     ,u+
                ldb     a,s
                stb     sr_carry
sr_w2           lda     ,x+
                ldb     a,y
                orb     sr_carry
                stb     ,u+
                ldb     a,s
                stb     sr_carry
sr_w1           lda     ,x+
                ldb     a,y
                orb     sr_carry
                stb     ,u+
                ldb     a,s
                stb     sr_carry
* The spill past the last source byte is the row's extra byte.
                lda     sr_carry
                sta     ,u+
sr_done
                lds     sr_saved_s              ; 6   restore the real stack
                rts

sr_saved_s      rmb     2
sr_carry        rmb     1
sr_shr_tab      rmb     256                     ; permuted: $80..$FF then $00..$7F
sr_shl_tab      rmb     256
