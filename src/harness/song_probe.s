* ---------------------------------------------------------------
* song_probe.s — P4.5: THE VERTICAL SLICE. One song, end to end, on the target.
*
* ★★★ WHAT THIS PLAYS IS A MEASUREMENT. Every row of the table was recorded off the running
* oracle's speaker by oracle_speaker_intervals.lua and packed by pack_song.py. `MUSIC.SET*`
* has still never been decoded (open since P4.1) and does not need to be for a slice: what
* the port must reproduce is what the Apple's speaker DID, and that is what these rows are.
*
* ★★ TINS=0, SINGLE MODE, AND THAT IS THE POINT. P4.4 measured the music at 101..943 Hz; the
* GIME timer at TINS=1 bottoms out at 874 Hz, so it cannot reach the low notes at all
* (8.6x past the 4095 ceiling). TINS=0 reaches the whole range at -2.02% at the very top.
* Jay: "I can't rule on the 3% without hearing it." So the WORSE case is what gets built and
* heard; the TINS hybrid is deliberately NOT here.
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
* THE TEAR-DOWN IS PART OF THE PLAYER, NOT AN AFTERTHOUGHT
* ---------------------------------------------------------------
* ★★★ A FIRQ player that is merely SILENCED keeps firing into whatever runs next. The
* dispatch calls this out because Jay's stop mechanism needs it: `song_stop` masks FIRQ,
* clears FIRQENR, puts $FF90 back the way HAL_sys_init left it, and parks the DAC at zero.
* It is called on the normal end AND is safe to call at any time.
*
* Published for the harness:
*   $2003  probe_status  1B   0=boot 1=playing 2=finished 3=torn down
*   $2004  probe_runs    2B   runs consumed
*   $2006  probe_firqs   2B   FIRQ entries (wraps; liveness)
*   $2008  probe_magic   2B   $50 4E once torn down
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

PROBE_MAGIC     equ     $504E
DAC             equ     $FF20
STACK_TOP       equ     $7F00

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

                bsr     audio_on
                bsr     song_start

                lda     #1
                sta     probe_status
                andcc   #$EF            ; VBL IRQs on, so HAL_time_vbl_wait works

* The foreground does NOTHING but wait. ★ That is deliberate: the whole claim of the
* interrupt architecture is that the music does not need the CPU's attention, and a
* foreground that helped would hide a failure of exactly that.
sp_wait         jsr     HAL_time_vbl_wait
                lda     sp_playing
                bne     sp_wait

                lda     #2
                sta     probe_status
                bsr     song_stop
                lda     #3
                sta     probe_status
                ldd     #PROBE_MAGIC
                std     probe_magic
sp_hold         jsr     HAL_time_vbl_wait
                bra     sp_hold

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
* song_start — arm the timer FIRQ and load the first run.
* ---------------------------------------------------------------
song_start
                ldx     #song_princess
                stx     sp_ptr
                clr     sp_count        ; forces the first interrupt to load a row
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
                bsr     load_run        ; sets the timer from the first row
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
* load_run — X = sp_ptr -> a row. Sets the timer and the level, or ends the song.
* Row: fdb ticks / fcb level / fcb count
* ★ LSB THEN MSB: writing $FF94 is what restarts the timer, so the MSB goes last —
* which also means a 16-bit STD would be wrong here [SockmasterGime.md].
* ---------------------------------------------------------------
load_run
                ldx     sp_ptr
                ldd     ,x++            ; D = ticks
                bne     lr_go
                clr     sp_playing      ; ticks 0 = terminator
                rts
lr_go
                stb     $FF95
                sta     $FF94
                lda     ,x+
                sta     sp_width
                lda     ,x+
                sta     sp_count
                stx     sp_ptr
                ldd     probe_runs
                addd    #1
                std     probe_runs
                rts

* ---------------------------------------------------------------
* firq_handler — one segment.
*
* ★ FIRQ stacks only PC and CC on the 6809, so everything used is saved by hand. A,B,X are
* all needed because the run-advance walks the table.
* ★★ The PULSE, not a square wave: the DAC goes to the level and straight back to zero, so
* the output is a narrow pulse train at the segment rate — which is what the oracle's
* speaker actually emits (7.8-22.5 us inside 1,061-9,883 us, P4.4). A square wave of the
* same pitch would be the same NOTE with a different TIMBRE, and the mandate is that it
* sound right (CLAUDE.md §2I).
* ★ The GIME source is acknowledged by READING $FF93; without it the FIRQ re-asserts
* immediately and the machine wedges.
* ---------------------------------------------------------------
firq_handler
                pshs    a,b,x
                lda     $FF93           ; acknowledge
* ★★★ THE PULSE IS HELD FOR ITS MEASURED WIDTH. The first cut wrote the DAC and cleared it
* on the next instruction — a ~4 us pulse against the oracle's measured 7.8-22.5, a 0.28%
* duty cycle against 0.55-1.6%. Jay: "i need more volume." It was 2-6x under AND less
* faithful than this file claimed, since reproducing the pulse is the whole reason this
* renders a pulse train rather than a square wave.
* ★ DAC at FULL SCALE, duty carries the amplitude — the Apple's own arrangement.
                lda     #$FC
                sta     DAC
                lda     sp_width        ; 3..8 iterations, from the measurement
fh_pulse        deca                    ; 2 cyc
                bne     fh_pulse        ; 3 cyc  -> 5 cyc per iteration
                clr     DAC
                ldd     probe_firqs
                addd    #1
                std     probe_firqs
                dec     sp_count
                bne     fh_out
                lbsr    load_run
fh_out          puls    a,b,x
                rti

* ---------------------------------------------------------------
sp_ptr          fdb     0
sp_width        fcb     1       ; the measured pulse width, in 5-cycle iterations
sp_count        fcb     0
sp_playing      fcb     0

                include "build/gen/song_princess.s"

                ifdef   OBJTARGET
                else
                end     probe_entry
                endc
