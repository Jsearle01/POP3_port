* src/harness/shift_bench.s
*
* POP CoCo3 — EXECUTE the shift loop and measure it (P3.41).
*
* P3.39 assembled shift_row.s and counted 32 cy/byte inner, 59 cy/row. P3.40's 93%
* verdict rests on those figures. But P3.39 is exactly the dispatch that turned a
* COUNTED 98% into an ASSEMBLED 114%, so a counted-not-executed number is precisely
* the kind this project has learned to distrust. This runs it.
*
* ---------------------------------------------------------------
* HOW IT MEASURES, and why this way
* ---------------------------------------------------------------
* Not by a cycle counter -- by ELAPSED VIDEO FRAMES over a large iteration count.
* The VBL is the one clock the harness already reads reliably (every cadence and
* rate measurement in this project comes off it), and at 20,000 iterations a
* one-frame error is 0.006% of the result. A cycle counter would be more direct and
* is not obviously more trustworthy: it would be a new instrument, and instruments
* here have failed silently seven times.
*
*     cy/row = frames * CY_PER_FRAME / ITERATIONS
*
* The routine is called on a SEVEN-byte row, the width of the deciding frame's
* vizier cel (P3.38b), and again on a six-byte row for the princess's. Both are
* reported, because P3.21 was wrong by 2.2x from using one row width's rate for
* another's.
*
* ---------------------------------------------------------------
* WHAT IS MEASURED, EXACTLY
* ---------------------------------------------------------------
* The whole call: `sts`/table loads/`clr`/dispatch, the unrolled rungs, the spill
* tail, `lds`, `rts`. That is the per-row cost P3.39 counted as 59, and the inner
* rate falls out of the two widths:
*
*     cy(7) - cy(6) = the per-BYTE cost      (one extra rung)
*     cy(6) - 6*that = the per-ROW overhead
*
* So one measurement yields both figures P3.40 depends on, and neither is assumed.
*
* Interrupts are masked for the run, as the real caller must do -- S is a table
* pointer inside shift_row.
* ---------------------------------------------------------------

                ifdef   OBJTARGET
                section prog
                export  bench_entry
                import  shift_row
                import  sr_shr_tab
                import  sr_shl_tab
                else
                org     $3000
                endc

ITER            equ     20000           ; a one-frame error is 0.006% at this count
SRC             equ     $5000           ; source row
DST             equ     $5100           ; destination (row + spill byte)

bench_entry
                orcc    #$50            ; mask; shift_row borrows S
                lds     #$4F00
* DOUBLE SPEED, because the 29,859 cy/frame budget every figure in this arc is stated
* against is a DOUBLE-SPEED number ($FFD9; CLAUDE.md 2G). The CoCo3 boots at 0.89 MHz,
* so timing against video frames without this divides double-speed cycles by
* normal-speed frames -- a clean factor of two, and the first run of this benchmark
* reported 623.6 cy/row for a routine counted at 284 for exactly that reason.
                sta     $FFD9

* --- fill the shift tables for phase 1 (2-bit right shift) ---------------
* PERMUTED by 128, because accumulator-offset indexing is SIGNED: `ldb a,y` reads
* Y+A with A signed, so the entry for byte v lives at TAB + ((v + 128) AND $FF) and
* the bases are biased +128. This is the layout shift_row.s documents; building it
* here rather than assuming it means the benchmark exercises the real addressing.
* Walk the table LINEARLY and derive the byte value from the index, rather than
* indexing by the value. `stb a,y` with A = v+128 treats A as SIGNED, so every entry
* would land BELOW the table base -- on top of shift_row's own code. That is the exact
* trap the permuted layout exists to avoid, and the first version of this benchmark
* fell into it while building the table for it. The routine hung.
                ldx     #sr_shr_tab
                clra                            ; i = 0..255, the table slot
bt_fill
                tfr     a,b
                addb    #128                    ; v = (i + 128) AND $FF
                lsrb
                lsrb                            ; SHR[v] = v >> 2
                stb     ,x+
                inca
                bne     bt_fill

                ldx     #sr_shl_tab
                clra
bt_fill2
                tfr     a,b
                addb    #128
                lslb
                lslb
                lslb
                lslb
                lslb
                lslb                            ; SHL[v] = v << 6
                stb     ,x+
                inca
                bne     bt_fill2

* --- run 1: SEVEN-byte rows (the vizier cel's width) ---------------------
                lda     #1
                sta     bench_phase     ; observable: which run is live
                ldx     #ITER/256
                stx     bench_outer
                lda     #0
                sta     bench_inner
b7_loop
                ldx     #SRC
                ldu     #DST
                ldb     #7
                jsr     shift_row
                dec     bench_inner
                bne     b7_loop
                ldx     bench_outer
                leax    -1,x
                stx     bench_outer
                bne     b7_loop

                lda     #2
                sta     bench_phase     ; run 1 done — Lua timestamps this

* --- run 2: SIX-byte rows (the princess cel's width) ---------------------
                ldx     #ITER/256
                stx     bench_outer
                lda     #0
                sta     bench_inner
b6_loop
                ldx     #SRC
                ldu     #DST
                ldb     #6
                jsr     shift_row
                dec     bench_inner
                bne     b6_loop
                ldx     bench_outer
                leax    -1,x
                stx     bench_outer
                bne     b6_loop

                lda     #3
                sta     bench_phase     ; both runs done
bench_halt
                bra     bench_halt

bench_phase     fcb     0               ; 0 boot, 1 running w=7, 2 running w=6, 3 done
bench_outer     fdb     0
bench_inner     fcb     0
