* ---------------------------------------------------------------
* tone_probe.s — P4.2: WHAT DOES A TONE COST?
*
* ★★★ THIS IS AN INSTRUMENT, NOT A SOUND SYSTEM. It exists to answer one number that
* cannot be modelled: how much of a frame does generating a square wave consume, in each
* of the two architectures the design forks on. P4.1 §3F named the CPU cost first-class
* and unanswered; §2 of P4.2 says build the minimal thing and measure it, because
* modelling has lost twice here (P3.21 by 2.2x; P3.22's 92% prediction against a measured
* 10.0 Hz) and counted != assembled != executed (P3.39, P3.41).
*
* ★★ IT DOES NOT CLAIM TO MAKE AN AUDIBLE SOUND. The CPU cost of writing $FF20 in a loop
* is the same whether or not the analogue path is enabled, so the measurement stands
* without it — and claiming audibility would be a claim only Jay's ears can settle. The
* PIA sound-enable is deliberately NOT touched: this probe measures CYCLES.
*
* ---------------------------------------------------------------
* HOW THE COST IS MEASURED, AND WHY IT NEEDS NO CYCLE COUNTER
* ---------------------------------------------------------------
* MAME's Lua exposes neither `cpu.clock` nor `cpu:total_cycles()` on this build — both
* nil, probed at P3.102 and recorded in mame-idioms-coco3-port.md §0/§0a. The idioms file
* also gives the way round it, and it is this project's own established technique:
*
*   HAL_time_vbl_wait spins in a 2-instruction loop (cmpb <hal_frame_lo = 4 cyc,
*   beq taken = 3 cyc) = 7 cycles per iteration, burning every cycle the program is NOT
*   working. So spins*7 is the frame's IDLE cycles, and
*
*       work = 29,859 - spins*7          [VBL budget, gfx.s $FFD9 double speed]
*
* A read-tap on hal_vbl_spin counts them. ★ The absolute figure is only as good as the
* 7-cycle loop, but the DIFFERENCE between two phases in the same run is exact — and the
* difference is what this probe is for.
*
* ---------------------------------------------------------------
* THE PHASES — a cost CURVE, not one number
* ---------------------------------------------------------------
*   0  baseline      VBL wait only. The zero of the scale.
*   1  FIRQ, low     GIME timer FIRQ toggling the DAC, TMR = TMR_LO  (few interrupts)
*   2  FIRQ, mid     ...TMR_MID
*   3  FIRQ, high    ...TMR_HI                                        (many interrupts)
*   4  blocking      a bit-banged square wave in the foreground, TONE_HALFCYC toggles
*
* ★ Phases 1-3 give cost as a FUNCTION of tone frequency, which is what the design fork
* actually turns on: an interrupt player's cost is (rate x cycles-per-interrupt), so one
* frequency would not answer it. Phase 4 is the oracle's own shape for contrast.
*
* ---------------------------------------------------------------
* THE GIME TIMER, from the vendored reference [docs/ground-truth/SockmasterGime.md]
* ---------------------------------------------------------------
*   $FF90 bit 4  FEN    1 = GIME FIRQ enabled      (the HAL leaves this 0; $FF90 = $6C)
*   $FF91 bit 5  TINS   1 = 279.365 ns tick        "useful for interrupt driven sound"
*         bit 0  TR     MMU task select — MUST stay 0; the HAL uses $FFA0-$FFA7
*   $FF93 bit 5  TMR    1 = enable timer FIRQ
*   $FF94        timer bits 8-11   ★ WRITING $FF94 RESTARTS THE TIMER; writing $FF95 does
*   $FF95        timer bits 0-7      not. So the LSB is written FIRST, then the MSB.
*   FIRQ vector  $FFF6 -> $FEF4 -> $010F           the $01xx slot is changeable
*
* ★★ FIRQ, NOT IRQ, AND THAT IS DELIBERATE: the HAL owns $010C for its VBL handler
* [hal/coco3-dsk/irq_vbl.s], and the frame counter this probe measures against depends on
* it. Taking the FIRQ slot leaves that untouched, so the instrument does not perturb the
* clock it is measured by.
*
* Published for the harness:
*   $0203  probe_status  1B   0=not started, 1=running, 2=complete
*   $0204  probe_phase   1B   which phase is running, 0..NPHASE-1
*   $0205  probe_firqs   2B   FIRQ handler entries this phase (wraps; a liveness check)
*   $0207  probe_magic   2B   $B0CE once complete
* ---------------------------------------------------------------
                ifdef   OBJTARGET
                section prog
                export  probe_entry
                else
                org     $0200
                endc
                ifdef   OBJTARGET
                else
                setdp   0
                endc

                import  HAL_sys_init
                import  HAL_time_init
                import  HAL_time_vbl_wait
                import  HAL_gfx_set_mode

probe_entry     jmp     probe_start     ; $0200 — EXEC address

probe_status    fcb     0               ; $0203
probe_phase     fcb     0               ; $0204
probe_firqs     fdb     0               ; $0205
probe_magic     fdb     0               ; $0207

PROBE_MAGIC     equ     $B0CE
FRAMES_PER      equ     120             ; per phase; long enough to average the jitter
NPHASE          equ     5

DAC             equ     $FF20           ; 6-bit DAC in bits 7-2
DAC_HI          equ     $FC             ; both levels are DAC-only bits; the low two bits
DAC_LO          equ     $00             ;   are not ours to write

* THE THREE TONE PERIODS, in 279.365 ns ticks. A square wave toggles twice per cycle, so
* the tone is 1 / (2 * N * 279.365ns).
*   3822 -> toggles at  936 Hz -> ~468 Hz tone   (low)
*   1791 -> toggles at 1999 Hz -> ~999 Hz tone   (mid)
*    895 -> toggles at 4000 Hz -> ~2000 Hz tone  (high)
* ★ 4095 is the timer's ceiling, so ~468 Hz is near the LOWEST tone this mechanism can
* produce at TINS=1 — itself a finding, and one the design has to live with.
TMR_LO          equ     3822
TMR_MID         equ     1791
TMR_HI          equ     895

* Foreground toggles per frame in phase 4. 300 toggles = ~150 cycles of square wave at
* whatever rate the loop achieves; the point is the COST, which scales linearly.
TONE_HALFCYC    equ     300

* ---------------------------------------------------------------
probe_start
                orcc    #$50            ; mask while the machine comes up
                lds     #$7F00
                clra
                tfr     a,dp

                jsr     HAL_sys_init
                jsr     HAL_time_init
* The mode is set because HAL_time_init's VBL depends on the GIME being in a CoCo3 mode,
* and because the frame budget this is measured against is the scene's own.
                lda     #0              ; GFX_MODE_320x192x4
                jsr     HAL_gfx_set_mode

* --- install the FIRQ handler at $010F, the changeable slot -----------------
                lda     #$7E            ; JMP
                sta     $010F
                ldd     #firq_handler
                std     $0110

                lda     #1
                sta     probe_status
                andcc   #$EF            ; opt in to real VBL waits (IRQ unmasked)

* --- phase 0: baseline -------------------------------------------------------
                clr     probe_phase
                bsr     run_frames

* --- phases 1..3: FIRQ-driven at three tone periods --------------------------
* ★ THE TIMER GOES IN X, NOT D. Written as `ldd #TMR_LO / lda #1` the second instruction
* clobbers D's high byte — the timer value would have been silently truncated to its low
* 8 bits and all three phases would have run at nearly the same rate, which is the shape
* of bug that produces a plausible flat cost curve.
                ldx     #TMR_LO
                lda     #1
                bsr     firq_phase
                ldx     #TMR_MID
                lda     #2
                bsr     firq_phase
                ldx     #TMR_HI
                lda     #3
                bsr     firq_phase

* --- phase 4: the oracle's shape — a foreground bit-bang ---------------------
                lda     #4
                sta     probe_phase
                ldx     #FRAMES_PER
tp_blk          pshs    x
                bsr     block_tone
                jsr     HAL_time_vbl_wait
                puls    x
                leax    -1,x
                bne     tp_blk

                lda     #2
                sta     probe_status
                ldd     #PROBE_MAGIC
                std     probe_magic
tp_hold         jsr     HAL_time_vbl_wait
                bra     tp_hold

* ---------------------------------------------------------------
* firq_phase — D = timer value, A(entry, on stack) = phase number.
* Arms the GIME timer FIRQ, runs FRAMES_PER frames doing nothing but waiting, then
* disarms. ★ THE MAIN LOOP DOES NO AUDIO WORK AT ALL — every cycle the handler steals is
* the cost, and it shows up as spins the main loop no longer gets.
* ---------------------------------------------------------------
firq_phase
                sta     probe_phase     ; A = the phase number, X = the timer value
                pshs    x
                ldd     #0
                std     probe_firqs

* TINS = 1 (279 ns), TR = 0 (the HAL's MMU set). Written whole, not read-modified:
* $FF91's other bits are unused per the reference.
                lda     #$20
                sta     $FF91
* FEN on, everything else as HAL_sys_init left it ($6C).
                lda     #$6C+$10
                sta     $FF90
* LSB first: writing $FF94 is what restarts the timer.
                ldd     ,s              ; the timer value, as pushed from X
                stb     $FF95
                sta     $FF94
                lda     #$20            ; TMR
                sta     $FF93           ; FIRQENR
                andcc   #$BF            ; unmask FIRQ

                ldx     #FRAMES_PER
fp_lp           jsr     HAL_time_vbl_wait
                leax    -1,x
                bne     fp_lp

                orcc    #$40            ; mask FIRQ
                clr     $FF93           ; no FIRQ sources
                lda     #$6C
                sta     $FF90           ; FEN back off
                puls    x,pc

* ---------------------------------------------------------------
* run_frames — FRAMES_PER frames of nothing but the VBL wait. The zero of the scale.
* ---------------------------------------------------------------
run_frames
                pshs    x
                ldx     #FRAMES_PER
rf_lp           jsr     HAL_time_vbl_wait
                leax    -1,x
                bne     rf_lp
                puls    x,pc

* ---------------------------------------------------------------
* block_tone — the ORACLE'S SHAPE: toggle the DAC in a foreground loop.
*
* This is `tone` from SOUND.S with the Apple's one-bit `bit spkr` replaced by a 6-bit DAC
* write, and it is deliberately the same structure — a delay between toggles setting the
* period, and a count of half-cycles setting the duration. What it costs here is what the
* oracle's mechanism costs on this machine.
* ---------------------------------------------------------------
block_tone
                pshs    a,b,x,y
                ldx     #TONE_HALFCYC
bt_lp           lda     #DAC_HI
                sta     DAC
                ldy     #24             ; the half-period delay
bt_d1           leay    -1,y
                bne     bt_d1
                lda     #DAC_LO
                sta     DAC
                ldy     #24
bt_d2           leay    -1,y
                bne     bt_d2
                leax    -1,x
                bne     bt_lp
                puls    a,b,x,y,pc

* ---------------------------------------------------------------
* firq_handler — one DAC toggle per timer expiry.
*
* ★ FIRQ stacks only PC and CC on the 6809, which is exactly why it is the right vector
* for this: the handler's cost is the cost of the sound, not of the entry sequence. A and
* DP are saved by hand because the handler uses them.
* ★ The GIME's interrupt source is acknowledged by READING $FF93 [the reference: "Reading
* from the register tells you which interrupts came in and acknowledges and resets the
* interrupt source"] — without it the FIRQ re-asserts immediately and the machine wedges.
* ---------------------------------------------------------------
firq_handler
                pshs    a
                lda     $FF93           ; acknowledge / clear the source
* eora #DAC_HI, not coma: the DAC is bits 7-2 and bits 1-0 are not ours to write.
                lda     tp_level
                eora    #DAC_HI
                sta     tp_level
                sta     DAC
                inc     probe_firqs+1
                bne     fh_out
                inc     probe_firqs
fh_out          puls    a
                rti

tp_level        fcb     DAC_LO

                ifdef   OBJTARGET
                else
                end     probe_entry
                endc
