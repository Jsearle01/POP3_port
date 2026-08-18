* ---------------------------------------------------------------
* song_probe.s — P4.5/P4.6: THE VERTICAL SLICE. One song, end to end, on the target.
*
* ★★★ WHAT THIS PLAYS IS A MEASUREMENT. Every row of the table was recorded off the running
* oracle's speaker by oracle_speaker_intervals.lua and packed by pack_song.py. `MUSIC.SET*`
* has still never been decoded (open since P4.1) and does not need to be for a slice: what
* the port must reproduce is what the Apple's speaker DID, and that is what these rows are.
*
* ★★ TINS=0, SINGLE MODE, AND THAT IS THE POINT. P4.4 measured the music at 101..943 Hz; the
* GIME timer at TINS=1 bottoms out at 874 Hz, so it cannot reach the low notes at all
* (8.6x past the 4095 ceiling). ★★★ AND P4.6 CLOSES THE HYBRID OFF ENTIRELY: 74.8% of this
* song sits at 600-800 Hz, whose periods are 1.25..1.67 ms against TINS=1's 1.144 ms
* ceiling — the hybrid cannot reach the band it would be built for. So the detune is
* answered by BETTER QUANTISATION, not by a second clock (see the dither, below).
*
* ---------------------------------------------------------------
* THE AUDIO PATH — three registers, and two of them are not the DAC
* ---------------------------------------------------------------
*   $FF20 bits 7-2   the 6-bit DAC
*   $FF23 bit 3      PIA1 CRB / CB2 = SOUND ENABLE. Nothing comes out without it.
*   $FF01 bit 3      PIA0 CRA / CA2 = mux SEL1  } both LOW selects the DAC as the
*   $FF03 bit 3      PIA0 CRB / CB2 = mux SEL2  } audio source (vs cassette/cartridge)
*
* ★ CB2/CA2 are driven by setting bit 5 (output mode) and bit 4, with bit 3 as the level —
* so "set CB2 high" is `ora #$38` and "set CA2 low" is `anda #$F7 / ora #$30`.
* ★★ HAL_sys_init leaves these alone: it only clears bits 0-1 of each control register
* (the IRQ enables, `anda #$FC`), so whatever DECB left is still there and this must set
* them explicitly rather than assume.
*
* ---------------------------------------------------------------
* THE ROW, AND WHY IT CARRIES A FRACTION
* ---------------------------------------------------------------
*   fdb ticks    GIME 12-bit timer, TINS=0 (63.695 us/tick) — the SEGMENT rate
*   fcb frac     dither numerator 0..255: this many 256ths of the segments in this run
*                take ticks+1 instead of ticks
*   fcb width    the pulse, in iterations of the handler's 5-cycle delay loop
*   fcb count    how many identical segments this row stands for (1..255)
*   fdb 0        terminates
*
* ★★★ AND THE FRACTION IS RETIRED — IT IS `SP_DITHER`, OFF BY DEFAULT, AND THE REASON IS
* JAY'S EAR. A single tick value can be no closer than half a tick, so table A's periods
* run 0.69% sharp on average (biased, not merely noisy: 2,936 of 3,924 segments share a
* handful of periods that all round the same way). A Bresenham accumulator alternates ticks
* and ticks+1 so the MEAN comes out right, at the price of up to one tick of per-segment
* jitter. P4.6 built both, from ONE code path with two tables, and played them back to back
* on a loop — his words: "it's going to be hard to gate something without knowing what it
* would sound like the other way."
*
* ★★ HE HEARD BOTH AND RULED: "i don't hear a difference." 0.69% is about 12 cents, an
* eighth of a semitone on a solo line, and that is the expected answer rather than a failed
* test — the two renditions measured 6474.7 ms and 6521.5 ms emitted, so they DID differ by
* the 0.72% they were built to differ by. So the accumulator and the per-interrupt timer
* write come out: 279 cyc/frame, 0.9% of the VBL budget, returned. `SP_DITHER` rebuilds the
* A/B if the question is ever reopened; the constants differ between the two paths and
* pack_song.py must be re-run, never reused.
*
* ---------------------------------------------------------------
* THE TEAR-DOWN IS PART OF THE PLAYER, NOT AN AFTERTHOUGHT
* ---------------------------------------------------------------
* ★★★ A FIRQ player that is merely SILENCED keeps firing into whatever runs next.
* `song_stop` masks FIRQ, clears FIRQENR, stops the timer, puts $FF90 back the way
* HAL_sys_init left it, and parks the DAC at zero. Called on the normal end AND safe to
* call at any time.
*
* Published for the harness:
*   $2003  probe_status  1B   0=boot 1=playing 2=finished 3=torn down
*   $2004  probe_runs    2B   runs consumed
*   $2006  probe_firqs   2B   FIRQ entries (wraps; liveness AND the measured rate)
*   $2008  probe_magic   2B   $50 4E once torn down
*   $200A  probe_mode    1B   POKED BEFORE EXEC. 0 = one pass of A, then stop (the
*                             headless/cost path). 1 = A, gap, B, gap, repeat (Jay's ear).
*                             2 = one pass of B, then stop (the same headless measurement,
*                             aimed at the dithered table).
*   $200B  probe_pass    1B   which table is sounding now: 0 = A, 1 = B
*
* Build-time ablations, for the cost split (P4.6 §2) — the shipping slice defines none:
*   SP_DITHER    (opt-IN) the accumulator + per-interrupt timer write + table B
*   SP_NOCOUNT   drop the probe_firqs increment
*   SP_NOPULSE   force the pulse to one iteration
* ---------------------------------------------------------------
                ifdef   OBJTARGET
                section prog
                export  probe_entry
                else
                org     $2000
                endc
                ifdef   OBJTARGET
                else
                setdp   0
                endc

                import  HAL_sys_init
                import  HAL_time_init
                import  HAL_time_vbl_wait
                import  HAL_gfx_set_mode

probe_entry     jmp     probe_start     ; $2000 — EXEC address

probe_status    fcb     0               ; $2003
probe_runs      fdb     0               ; $2004
probe_firqs     fdb     0               ; $2006
probe_magic     fdb     0               ; $2008
probe_mode      fcb     0               ; $200A
probe_pass      fcb     0               ; $200B

PROBE_MAGIC     equ     $504E
DAC             equ     $FF20
STACK_TOP       equ     $7F00
GAP_FRAMES      equ     90              ; ~1.5 s of silence between A and B

* ---------------------------------------------------------------
probe_start
                orcc    #$50
                lds     #STACK_TOP
                clra
                tfr     a,dp

                jsr     HAL_sys_init
                jsr     HAL_time_init
                lda     #0              ; GFX_MODE_320x192x4 — a screen so the run is visible
                jsr     HAL_gfx_set_mode

                jsr     audio_on
                lda     #1
                sta     probe_status
                andcc   #$EF            ; VBL IRQs on, so HAL_time_vbl_wait works

* ★ MODE 0 IS THE MEASURED PATH AND MODE 1 IS THE HEARD ONE, from one binary and one
* launch. The alternative was two programs, and two programs are how the thing measured
* and the thing demonstrated drift apart.
sp_pass
                ifdef   SP_DITHER
                lda     probe_mode
                cmpa    #2              ; ★ mode 2 plays TABLE B once and stops — the same
                bne     sp_a            ;   headless fidelity run, aimed at the other table
                lda     #1
                sta     probe_pass
                ldx     #song_b
                jsr     song_start
                jsr     sp_wait_end
                lda     #2
                sta     probe_status
                bra     sp_finish
                endc
sp_a
                clr     probe_pass
                ldx     #song_a
                jsr     song_start
                jsr     sp_wait_end
                lda     probe_mode
                bne     sp_loopb
                lda     #2              ; finished, not yet torn down
                sta     probe_status
                bra     sp_finish

sp_loopb        jsr     song_stop
                jsr     sp_gap
                ifdef   SP_DITHER
                lda     #1
                sta     probe_pass
                ldx     #song_b
                else
                ldx     #song_a         ; ★ no B to compare against — mode 1 just loops the song
                endc
                jsr     song_start
                jsr     sp_wait_end
                jsr     song_stop
                jsr     sp_gap
                bra     sp_pass

sp_finish
                jsr     song_stop
                lda     #3
                sta     probe_status
                ldd     #PROBE_MAGIC
                std     probe_magic
sp_hold         jsr     HAL_time_vbl_wait
                bra     sp_hold

* The foreground does NOTHING but wait. ★ That is deliberate: the whole claim of the
* interrupt architecture is that the music does not need the CPU's attention, and a
* foreground that helped would hide a failure of exactly that.
sp_wait_end     jsr     HAL_time_vbl_wait
                lda     sp_playing
                bne     sp_wait_end
                rts

sp_gap          lda     #GAP_FRAMES
                sta     sp_gapn
sp_gap1         jsr     HAL_time_vbl_wait
                dec     sp_gapn
                bne     sp_gap1
                rts

* ---------------------------------------------------------------
* audio_on — mux to the DAC and open the sound gate.
* ---------------------------------------------------------------
audio_on
                lda     $FF01
                anda    #$F7            ; CA2 low  = SEL1 0
                ora     #$30            ; CA2 as an output
                sta     $FF01
                lda     $FF03
                anda    #$F7            ; CB2 low  = SEL2 0
                ora     #$30
                sta     $FF03
                lda     $FF23
                ora     #$38            ; CB2 HIGH = sound enable
                sta     $FF23
                clr     DAC
                rts

* ---------------------------------------------------------------
* song_start — X = the table. Arm the timer FIRQ and load the first row.
* ---------------------------------------------------------------
song_start
                stx     sp_ptr
                clr     sp_acc
                lda     #1
                sta     sp_playing
                ldd     #0
                std     probe_runs
                std     probe_firqs

                lda     #$7E            ; JMP
                sta     $010F           ; the FIRQ dispatch slot ($FFF6 -> $FEF4 -> $010F)
                ldd     #firq_handler
                std     $0110

* TINS = 0 (63.695 us/tick), TR = 0 (the HAL's $FFA0-$FFA7 MMU set).
                clr     $FF91
* FEN on, everything else as HAL_sys_init left it ($6C).
                lda     #$6C+$10
                sta     $FF90
                bsr     load_run        ; the first row
                ldd     sp_ticks
                stb     $FF95           ; ★ LSB THEN MSB: writing $FF94 is what restarts the
                sta     $FF94           ;   timer, so a 16-bit STD would be wrong here
                lda     #$20            ; TMR
                sta     $FF93
                andcc   #$BF            ; unmask FIRQ
                rts

* ---------------------------------------------------------------
* song_stop — ★ TEAR DOWN, not silence. Safe to call at any time.
* ---------------------------------------------------------------
song_stop
                orcc    #$40            ; mask FIRQ first, so nothing fires mid-teardown
                clr     $FF93           ; no FIRQ sources
                clr     $FF94           ; timer MSB 0 = stopped (writing MSB is what acts)
                clr     $FF95
                lda     #$6C
                sta     $FF90           ; FEN back off, as HAL_sys_init left it
                clr     DAC             ; park the speaker
                clr     sp_playing
                rts

* ---------------------------------------------------------------
* load_run — advance sp_ptr to the next row. Returns C=1 on the terminator, having
* stopped the timer, so the handler can leave without emitting one more pulse.
* ---------------------------------------------------------------
load_run
                ldx     sp_ptr
                ldd     ,x++            ; D = ticks
                beq     lr_end
                std     sp_ticks
                lda     ,x+
                sta     sp_frac
                lda     ,x+
                sta     sp_width
                lda     ,x+
                sta     sp_count
                stx     sp_ptr
* ★ THE CHEAP PATH RELOADS HERE, ONCE PER RUN. With the dither the handler writes the
* timer every interrupt and this would be redundant; without it, nothing else ever
* changes the period, so the run boundary is the only place it can happen.
                ifndef  SP_DITHER
                ldd     sp_ticks
                stb     $FF95
                sta     $FF94
                endc
                ldd     probe_runs
                addd    #1
                std     probe_runs
                andcc   #$FE            ; C=0 — more to play
                rts
lr_end
                clr     $FF94           ; stop the timer; no further FIRQ
                clr     $FF95
                clr     DAC
                clr     sp_playing
                orcc    #$01            ; C=1 — the song is over
                rts

* ---------------------------------------------------------------
* firq_handler — one segment.
*
* ★ FIRQ stacks only PC and CC on the 6809, so everything used is saved by hand. A,B,X are
* all needed because the run-advance walks the table.
* ★★ The PULSE, not a square wave: the DAC goes to full scale and back to zero, so the
* output is a narrow pulse train at the segment rate — which is what the oracle's speaker
* actually emits (7.8-22.5 us inside 1,061-9,883 us, P4.4). A square wave of the same pitch
* would be the same NOTE with a different TIMBRE, and the mandate is that it sound right
* (CLAUDE.md §2I).
* ★★★ AND THE WIDTH IS THE AMPLITUDE, WHICH IS WHY IT IS CARRIED PER ROW. P4.5's first cut
* emitted a fixed ~4 us pulse and Jay heard it: "i need more volume." The Apple's own
* arrangement is one level and a varying duty, and that is what this reproduces — the four
* distinct widths in the captured 6.5 s ARE whichever of MSYS's HM1..HM29 patterns were
* running, with no decode in between.
* ★ The GIME source is acknowledged by READING $FF93; without it the FIRQ re-asserts
* immediately and the machine wedges.
* ★ THE TIMER IS WRITTEN FIRST, before the pulse, so the restart latency is a CONSTANT and
* pack_song.py can subtract it. Written after a variable-width pulse it would not be.
* ---------------------------------------------------------------
firq_handler
                pshs    a,b,x
                lda     $FF93           ; acknowledge
                dec     sp_count
                bne     fh_tick
                lbsr    load_run
                bcs     fh_out          ; terminator: timer already stopped
fh_tick
                ifdef   SP_DITHER
* ★ THE ACCUMULATOR. adda sets C; sta and ldd leave it alone, so the bcc below still tests
* the add. Carry => this segment takes ticks+1, which is how the mean period comes out
* right when no single tick value can.
                lda     sp_acc
                adda    sp_frac
                sta     sp_acc
                ldd     sp_ticks
                bcc     fh_tw
                addd    #1
fh_tw           stb     $FF95
                sta     $FF94           ; restarts the timer
                endc
* ★★ EVERYTHING THAT CAN BE HOISTED OUT OF THE PULSE IS, because the instructions inside it
* ARE the minimum amplitude. Measured at P4.6: `lda sp_width` + `clr DAC` put 12 cycles
* inside the window, so the quietest pulse the player could emit was 9.5 us against the
* oracle's 7.8 — 21% too loud at the bottom of the range, and unfixable from the table.
* Counting in B leaves B=0 at the loop exit, so the close is `stb DAC` (5 cyc) with the
* width load hoisted above the open.
                ifdef   SP_NOPULSE
                ldb     #1
                else
                ldb     sp_width
                endc
* ★★★ WIDTH 0 IS A REST, AND IT IS NOT AN EDGE CASE — IT IS HOW SILENCE EXISTS AT ALL.
* The GIME timer tops out at 4095 ticks = 261 ms, and the full cutscene contains rests of
* up to 6 SECONDS. Those are packed as a train of silent maximum-length segments, so a rest
* is many interrupts that emit nothing rather than one impossible timer value. Without this
* branch `ldb #0` would fall into the loop and count 256 iterations — the longest pulse in
* the table, exactly where the music wants none.
                beq     fh_quiet        ; 3 cyc on every sounding segment
                lda     #$FC            ; DAC at FULL SCALE — duty carries the amplitude
                sta     DAC             ; the pulse OPENS here
fh_pulse        decb                    ; 2 cyc
                bne     fh_pulse        ; 3 cyc  -> 5 cyc per iteration
                stb     DAC             ; B is 0 — the pulse CLOSES here
fh_quiet
                ifndef  SP_NOCOUNT
                ldd     probe_firqs
                addd    #1
                std     probe_firqs
                endc
fh_out          puls    a,b,x
                rti

* ---------------------------------------------------------------
sp_ptr          fdb     0
sp_ticks        fdb     0
sp_frac         fcb     0       ; dither numerator, 256ths of a tick
sp_acc          fcb     0
sp_width        fcb     1       ; the measured pulse width, in 5-cycle iterations
sp_count        fcb     0
sp_playing      fcb     0
sp_gapn         fcb     0

                include "build/gen/song_a.s"
                ifdef   SP_DITHER
                include "build/gen/song_b.s"
                endc

                ifdef   OBJTARGET
                else
                end     probe_entry
                endc
