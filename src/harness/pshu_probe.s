* src/harness/pshu_probe.s
*
* POP CoCo3 — P1.3 PSHU BYTE-ORDER PROBE.
*
* Answers ONE question on real silicon (well, real emulated 6809): after
*   LDD #$A1A2 / LDX #$B1B2 / LDY #$C1C2 / PSHU D,X,Y
* which register's bytes land at which ADDRESS, ascending?
*
* WHY THIS EXISTS. The whole compiled-sprite emitter rests on mapping a run of
* cel bytes onto D/X/Y before a PSHU burst. Get the order wrong and every burst
* writes the right bytes in the wrong places. The PA.9 POC assigned
* chunk[0:2]->Y, [2:4]->X, [4:6]->D, and its simulator replayed the chunk list
* instead of modelling the registers — so its soundness check was structurally
* incapable of catching an inverted assignment. That is the P1.2-fix lesson
* verbatim: a checker downstream of the assumption cannot test the assumption.
* This probe is anchored OUTSIDE the compiler: it asks the CPU.
*
* No $0100 vector block (idiom §14e). Interrupts masked throughout.
* Observable block at a fixed address, same convention as loop_probe.s.
* ---------------------------------------------------------------


                org     $0200
                setdp   0

pshu_entry      jmp     pshu_start      ; $0200 — EXEC

pshu_status     fcb     0               ; $0203  0=start, 2=done
pshu_magic      fdb     0               ; $0204  $9E09 when done
pshu_buf        rmb     16              ; $0206  the 6 pushed bytes land here

pshu_start
                orcc    #$50            ; mask IRQ/FIRQ for the whole run
                clra
                tfr     a,dp

* Fill the landing zone with a canary so untouched bytes are obvious.
                ldx     #pshu_buf
                lda     #$5A
                ldb     #16
pp_fill         sta     ,x+
                decb
                bne     pp_fill

* U points ONE PAST the landing zone: PSHU pre-decrements, so the 6 bytes
* land at pshu_buf+2 .. pshu_buf+7 (leaving canaries either side as guards).
                ldu     #pshu_buf+8

                ldd     #$A1A2          ; A=$A1  B=$A2
                ldx     #$B1B2          ; XH=$B1 XL=$B2
                ldy     #$C1C2          ; YH=$C1 YL=$C2
                pshu    d,x,y

                lda     #2
                sta     pshu_status
                ldd     #$9E09
                std     pshu_magic

pshu_done       bra     pshu_done

                end     pshu_entry
