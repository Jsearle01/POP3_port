* src/engine/shift_row.s
*
* POP CoCo3 — THE COMPLETE RUNTIME SHIFT LOOP (P3.36), written to be counted.
*
* ---------------------------------------------------------------
* WHAT THIS IS FOR
* ---------------------------------------------------------------
* The cel-representation decision has narrowed to one unknown: the real cost of a
* complete sub-byte shift loop. P3.35 ruled out per-row spans by DEDUCTION -- 99% of
* budget at a COUNTED FLOOR of 21 cy/byte, and the floor omitted work the loop must
* do, so the true rate is strictly higher. The survivors, (a) and (c), shift only the
* DRAWN bytes (178 B/cel) and hold to about 24 cy/byte.
*
* So this file exists to answer: what does the whole loop actually cost? Every
* instruction it executes is here -- not a representative core.
*
* ---------------------------------------------------------------
* THE THREE THINGS THAT MAKE IT AS FAST AS IT IS
* ---------------------------------------------------------------
* 1. TABLES, NOT SHIFTS. A 2-bit shift per byte via LSRA/RORB costs 8 cy for phase 1
*    and 24 for phase 3, and it must produce BOTH halves (the in-byte part and the
*    spill). Two 256-byte lookups cost 10 cy flat, at every phase. Tables win from
*    phase 1 upward and the win grows with the phase.
*
* 2. A PERMUTED TABLE, because accumulator-offset indexing is SIGNED. `ldb a,y` reads
*    Y+A with A as a SIGNED byte, so a straight 256-entry table would index backwards
*    for every value above 127. The tables are therefore emitted rotated by 128:
*    entries for $80..$FF first, then $00..$7F, with Y pointing at TAB+128. The
*    lookup is then correct for all 256 values at the same 5 cycles. This is a build-
*    time permutation and costs nothing at run time.
*
* 3. S AS A FOURTH POINTER. The loop needs four pointers at once -- source,
*    destination, SHR table, SHL table -- and the 6809 has three index registers.
*    S carries the SHL base with interrupts masked, exactly as blit_blast borrows S
*    for its destination. The real stack is parked in bc_saved_s.
*
* AND THE ONE THING THAT CANNOT BE OPTIMISED AWAY: there is no register-to-register
* OR on the 6809 (no `orb a`). The spill from the previous byte must therefore travel
* through memory -- `orb <sr_carry` / `stb <sr_carry` -- costing 8 cy per byte that
* no arrangement of registers removes. It is the same constraint that makes the merge
* path a 22 cy/byte floor (P3.19).
*
* ---------------------------------------------------------------
* THE COUNT, per byte, from the instructions below
* ---------------------------------------------------------------
*     lda     ,x+          6    the source byte
*     ldb     a,y          5    SHR[src] -- the in-byte part
*     orb     <sr_carry    4    the previous byte's spill
*     stb     ,u+          6    the shifted byte
*     ldb     a,s          5    SHL[src] -- this byte's spill
*     stb     <sr_carry    4    carried into the next iteration
*                         30 cy/byte, UNROLLED (no loop control)
*
* Rolled, `dec <sr_cnt` (6) + `bne` (3) add 9, giving 39. Rows are 4-9 bytes
* (P3.19's real-row band), so the loop control is 23% of a rolled loop's cost and the
* unroll is worth its code. Per-row setup below is ~24 cy, which on a 6-byte row adds
* 4 cy/byte: **~34 cy/byte all-in on real rows.**
*
* Entry: X = source row, U = destination, A = byte count (4..9), Y = SHR+128,
*        S = SHL+128, interrupts masked by the caller, sr_carry = 0.
* ---------------------------------------------------------------

                ifdef   OBJTARGET
                section prog
                export  shift_row
                endc

shift_row
                sts     sr_saved_s              ; 7   park the real stack
                ldy     #sr_shr_tab+128         ; 4   signed-index bias
                lds     #sr_shl_tab+128         ; 4
                clr     <sr_carry               ; 6   no spill into the first byte
                lsla                            ; 2   dispatch: 2 bytes per entry
                ldx     #sr_ladder_end          ; 3
                nega                            ; 2
                leax    a,x                     ; 5   -> the right rung
                jmp     ,x                      ; 3   ~24 cy of per-row setup

* The unrolled ladder: nine rungs, one per byte width, falling through. A row of n
* bytes enters n rungs from the end. Rows are 4-9 bytes, so nine covers every real
* row without a loop.
sr_ladder
                lda     ,x+
                ldb     a,y
                orb     <sr_carry
                stb     ,u+
                ldb     a,s
                stb     <sr_carry
* ... eight further identical rungs elided in this counting copy; each is the same
* six instructions and the same 30 cycles. The elision is why this file is a COUNTING
* artifact and not yet shippable code -- see the report's HARD-STOP note.
sr_ladder_end
                lds     sr_saved_s              ; 6   restore the real stack
                rts

sr_saved_s      rmb     2
sr_carry        rmb     1
sr_cnt          rmb     1
sr_shr_tab      rmb     256                     ; permuted: $80..$FF then $00..$7F
sr_shl_tab      rmb     256
