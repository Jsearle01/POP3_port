* ---------------------------------------------------------------
* src/engine/msys_player.s — P4.19: MSYS, INTERPRETED. The note stream, not a recording.
*
* ★★★ WHAT CHANGED, AND WHY THE WHOLE FRONT END IS NEW. Every player this project has
* built so far replayed a CAPTURE: rows of (period, width, count) recorded off the
* oracle's speaker. `s_Title` costs 18,018 bytes that way and 92 as data (P4.16) — 196x —
* because the format has SUBROUTINES and a capture records the expansion. This walks the
* data instead. All thirteen songs together are 1,024 bytes, once.
*
* ★★ THE BACK END IS THE ONE THAT ALREADY WORKS. FIRQ + GIME timer + a full-scale DAC
* pulse whose WIDTH is the amplitude — song_probe.s, gated on Jay's ear at P4.5/P4.6. The
* pulse train is not an approximation of the Apple's speaker; it is what the Apple's
* speaker actually emits (7.8-22.5 us inside 1,061-9,883 us, P4.4).
*
* ---------------------------------------------------------------
* THE GRAMMAR, AS DECODED AND VALIDATED (P4.19 §3, harness/tools/msys_decode.py)
* ---------------------------------------------------------------
* Events are TWO BYTES and byte 1 discriminates. The stream pointer PRE-INCREMENTS by two,
* which is why every song's first two bytes are dead padding.
*
*   byte1 & $3F != 0                   a NOTE
*       byte0 bits 7..2   pitch, >>2, + transpose   -> msys_period / msys_length
*       byte0 bits 1..0   instrument index, LOW two bits
*       byte1 bits 7..6   instrument index, HIGH two bits   -> 16 instruments
*       byte1 bits 5..0   DURATION in ticks           ★★★ SIX BITS, NOT EIGHT
*   byte1 = $C0                        CALL  (backward; depth ONE, enforced)
*   byte1 = $40                        start the SECOND VOICE
*   byte1 = $80                        song chaining / the conditional alternate
*   byte1 = $00, byte0 = $00           end of stream
*                          $FE         return
*                          $FD         set the "has played" flag
*                          $FF         pause
*                          1..8        voice select — the amplitude transform
*                          >= 9        instrument select — harmonic pattern + transpose
*
* ★★★ THE DURATION IS SIX BITS AND THAT IS THE FACT THE WALK CAUGHT. `NMSYSM` does
* `AND #%00111111` and then `JMP NTVJNK`, whose first instruction is `STA R+10` — the
* accumulator still holds the MASKED value [MSYS.S:369-371, 439]. P4.18 §3A read it as the
* whole byte. Decoded that way `s_Princess` runs 1,477 frames against a traced 761; masked,
* it runs 758. ★ A grammar that parses without error and produces the wrong count is
* exactly the failure the dispatch named, and this is where it was.
*
* ---------------------------------------------------------------
* THE THREE CLOCKS, AND WHICH IS WHICH
* ---------------------------------------------------------------
*   SEGMENT   one FIRQ. One full square-wave period of the note. The pulse fires here.
*   TICK      `msys_length[pitch]` segments. The ENVELOPE steps here, and the note's
*             six-bit duration counts these.
*   PAD       one extra silent segment per tick, MSYS_PAD_TICKS long.
*
* ★★ NOTE x LENGTH IS VERY NEARLY CONSTANT ACROSS THE WHOLE PITCH TABLE, so a tick is
* ~30-40 ms at EVERY pitch. The expensive work — the envelope step, the note fetch, the
* whole event walk — therefore runs at a near-constant ~28 Hz no matter what is playing.
* ★★★ AND IT RUNS INSIDE THE PAD, where the DAC is parked and a long handler cannot
* distort a pulse. The oracle's caller overhead became the port's decode budget.
*
* ---------------------------------------------------------------
* WHAT THIS DELIBERATELY DOES NOT REPRODUCE (CLAUDE.md §2I)
* ---------------------------------------------------------------
* ★ MSYS spends most of its instructions on TIMING TRICKS — `MADJLP` subtracts the pulse
* width from the delay so the period is independent of the amplitude, `MDLOOP` counts the
* period out in 5-cycle steps, `MVDIT` counts the width. On a DAC and a hardware timer all
* three are a table lookup and a store. They are not ported and they are not missed: the
* output is the same pitch and the same duty.
* ★ The oracle has no timer, so it has no quantisation. This player does, and the divider
* (gen_msys_tables.py) holds it to 10 cents worst case — below the 12 cents Jay ruled
* inaudible at P4.6.
*
* ---------------------------------------------------------------
* TWO VOICES, AND WHY MONOPHONIC SURVIVED
* ---------------------------------------------------------------
* ★★★ `MMPLAY` IS A SECOND STREAM AND NOT A SECOND SOUND. `MPLAY` toggles `R+21` and jumps
* to `MMPLAY` on alternate calls [MSYS.S:464-470] — so the two voices TIME-SHARE one
* speaker a tick at a time. They share `VTBL`. They never sound together. P4.3's
* "one pitch at a time" is correct, and the port needs ONE FIRQ stream, not two.
* Nine of the eleven captured title songs use it, so it is built, not deferred.
*
* ---------------------------------------------------------------
* ENTRY POINTS
* ---------------------------------------------------------------
*   msys_init            once, after HAL_sys_init. Mux + sound enable + DAC parked.
*   msys_play    A = id  start a song. Returns immediately; the FIRQ does the rest.
*   msys_stop            TEAR DOWN. Safe at any time, idempotent.
*   msys_playing         A != 0 while a song is sounding.
*   msys_ticks           16-bit: ticks elapsed. The PLAN-duration assert reads this.
* ---------------------------------------------------------------

* ★★★ ITS OWN SECTION, `msys`, AT $0A00 — AND THE ADDRESS IS THE RESULT OF A SEARCH, NOT
* A PREFERENCE (P4.19; `harness/tools/intro_map.py` derives the map). This player is
* 4,417 B and there is nowhere else for it:
*   `code`  the kernel ends at $7D44 and the stack top is $7F00. 444 bytes.
*           ★ Placed there it pushed hal_build.o to $8A41, which under DECB is ROM —
*           LOADM wrote nothing, the probe read back garbage, and the failure presented
*           as "the LOADM/EXEC did not take" rather than as an overflow.
*   `prog`  the engine runs to $2462 and the scene program is READ to $2500. 157 bytes.
*   every other gap between $2000 and the trace ring: 3,951 B in FIVE pieces,
*           largest 1,625 — the cutscene's peel buffers at $6C00..$727F split the
*           biggest candidate in half, and a resident player must survive the scene.
*
* ★★ $0A00..$1FFF is 5,632 B and free, above everything DECB uses ($0600-$09FF is
* DBUF0/DBUF1/FAT/FCBs, which LOADM itself needs). The link script's own region map said
* otherwise for many dispatches — it still listed the intro bundle at $0A00 and the
* caption save buffer at $1C00, both of which moved (P3.7 to $3000, P3.25 to $5400) — and
* that stale block is why the first answer to "where does this go" was "nowhere".
                ifdef   OBJTARGET
                section msys
                export  msys_entry
                export  msys_init
                export  msys_play
                export  msys_stop
                export  msys_playing
                export  msys_ticks
                export  msys_song_page
                export  msys_period
                export  msys_v1
                else
                setdp   0
                endc

* ---------------------------------------------------------------
* ★★★ THE ENTRY TABLE, AT FIXED OFFSETS FROM THE BASE — because this unit is READ off a
* disk track, not linked. Its caller cannot see a linker symbol in it, exactly as the
* cutscene room cannot see one in the flame bundle ("Bundle entry points, at fixed offsets
* from FLAME_BASE. The room reaches everything through this table" — cutscene_room.s:161).
*
* ★★ IT MUST BE FIRST AND IT MUST NOT BE REORDERED. char_draw.s records what happens
* otherwise: a table entry moved from +58 to +40 "linked cleanly, booted, read the disk
* twice, stepped the VM, and only then jumped through $303A into cel data." Offsets are the
* interface; adding an entry goes on the END.
*
*   +0   msys_init      once, after HAL_sys_init
*   +3   msys_play      A = song id
*   +6   msys_stop      tear down; safe any time, idempotent
*   +9   msys_playing   A != 0 while sounding
*   +12  msys_ticks     16-bit, read directly — the PLAN-duration assert's input
* ---------------------------------------------------------------
msys_entry
                jmp     msys_init       ; +0
                jmp     msys_play       ; +3
                jmp     msys_stop       ; +6
                jmp     msys_playing    ; +9
msys_ticks      fdb     0               ; +12  ticks elapsed

DAC             equ     $FF20
FF90            equ     $FF90
FF91            equ     $FF91
FF93            equ     $FF93
FF94            equ     $FF94
FF95            equ     $FF95
HAL_FF90_IDLE   equ     $6C             ; what HAL_sys_init leaves in $FF90

* ---------------------------------------------------------------
* Voice state block. TWO of these; `msys_cur` points at the one the FIRQ is serving.
* ---------------------------------------------------------------
VS_PTR          equ     0       ; 2  stream pointer (points AT the current event)
VS_SAVED        equ     2       ; 2  the one-deep return slot
VS_INCALL       equ     4       ; 1  ★ a FLAG, not a stack pointer: depth is 1 BY
                                ;    CONSTRUCTION — a call while in a call RETURNS
VS_HARMP        equ     5       ; 2  active harmonic pattern
VS_HARMI        equ     7       ; 1  position in it
VS_HARMSEL      equ     8       ; 1  the instrument-select index ($AF); 0 resets HARMI
VS_ENVP         equ     9       ; 2  active envelope pattern
VS_ENVI         equ     11      ; 1  position in it
VS_AMP          equ     12      ; 1  current amplitude
VS_XPOSE        equ     13      ; 1  transpose
VS_VOICE        equ     14      ; 1  amplitude-transform selector 0..7
VS_PITCH        equ     15      ; 1  pitch index (0 = a rest: silent)
VS_SEGLEN       equ     16      ; 1  segments per tick
VS_TICKS        equ     17      ; 1  ticks left in this note (six bits: 1..63)
VS_FF91         equ     18      ; 1  TINS for this pitch
VS_DIV          equ     19      ; 1  interrupts per segment
VS_TIMER        equ     20      ; 2  the 12-bit timer count
VS_VTBL         equ     22      ; 5  the five pulse widths; VTBL+0 is ALWAYS zero
VS_SIZE         equ     27

* ---------------------------------------------------------------
msys_init
                pshs    a
                lda     $FF01
                anda    #$F7            ; CA2 low  = mux SEL1 0
                ora     #$30
                sta     $FF01
                lda     $FF03
                anda    #$F7            ; CB2 low  = mux SEL2 0
                ora     #$30
                sta     $FF03
                lda     $FF23
                ora     #$38            ; CB2 HIGH = sound enable
                sta     $FF23
                clr     DAC
                clr     msys_active
                puls    a,pc

* ---------------------------------------------------------------
* msys_play — A = song id (0..12). Arms the FIRQ and fetches the first event.
* ---------------------------------------------------------------
msys_play
                pshs    a,b,x,y,u
                sta     msys_index
                jsr     msys_stop_i             ; idempotent: never two live FIRQs
                ldd     #0
                std     msys_ticks
                clr     msys_two
                clr     msys_phase
                clr     msys_state

                ldx     #msys_v1                ; both blocks to MINIT's defaults
                ldb     #VS_SIZE*2
mp_clr          clr     ,x+
                decb
                bne     mp_clr
                ldx     #msys_v1
                bsr     voice_defaults
                ldx     #msys_v2
                bsr     voice_defaults

* the song pointer, from the address table: MADRLO at +$00, MADRHI at +$68
                ldx     #msys_song_page
                lda     msys_index
                ldb     a,x                     ; B = MADRLO[id]
                leax    $68,x
                lda     a,x                     ; A = MADRHI[id]   (A was still the id)
                ldx     #msys_v1
                std     VS_PTR,x                ; D = hi:lo
                stx     msys_cur

                lda     #1
                sta     msys_active
                jsr     new_note                ; the first sounding event
                bcc     mp_go
                clr     msys_active             ; a song that ends before it starts
                bra     mp_out
mp_go           jsr     tick_begin              ; envelope + widths + segment count
                jsr     firq_arm
mp_out          puls    a,b,x,y,u,pc

* X = a voice block. MINIT's initial state [MSYS.S:250-275].
voice_defaults
                pshs    a,y
                ldy     #msys_hm0
                sty     VS_HARMP,x
                ldy     #msys_mv0
                sty     VS_ENVP,x
                lda     #2                      ; transform 2 = identity ($EA,$EA)
                sta     VS_VOICE,x
                lda     #1
                sta     VS_DIV,x
                puls    a,y,pc

* ---------------------------------------------------------------
* msys_stop — ★ TEAR DOWN, not silence. Masks FIRQ, kills the timer, parks the DAC,
* and CLEARS THE RETURN SLOT — a torn-down player holding a live return address is a
* latent bug that only shows up when the next song starts mid-phrase.
* ---------------------------------------------------------------
msys_stop
                pshs    a,x
                jsr     msys_stop_i
                puls    a,x,pc

msys_stop_i
                orcc    #$40                    ; mask FIRQ before touching anything
                clr     FF93                    ; no FIRQ sources
                clr     FF94                    ; MSB 0 = timer stopped
                clr     FF95
                lda     #HAL_FF90_IDLE
                sta     FF90                    ; FEN back off, as HAL_sys_init left it
                clr     DAC                     ; park the speaker
                clr     msys_active
                clr     msys_two
                clr     msys_phase
                clr     msys_state
                ldx     #msys_v1
                clr     VS_INCALL,x
                clr     VS_SAVED,x
                clr     VS_SAVED+1,x
                ldx     #msys_v2
                clr     VS_INCALL,x
                clr     VS_SAVED,x
                clr     VS_SAVED+1,x
                rts

* ---------------------------------------------------------------
msys_playing    lda     msys_active
                rts

* ---------------------------------------------------------------
* firq_arm — install the handler and start the timer.
* ★ LSB THEN MSB: writing $FF94 is what restarts the timer, so a 16-bit STD is wrong.
* ---------------------------------------------------------------
firq_arm
                pshs    a,b,x
                lda     #$7E                    ; JMP
                sta     $010F                   ; FIRQ slot: $FFF6 -> $FEF4 -> $010F
                ldd     #firq_handler
                std     $0110
                ldx     msys_cur
                lda     VS_FF91,x
                sta     FF91
                lda     VS_DIV,x
                sta     msys_divn
                lda     #HAL_FF90_IDLE+$10      ; FEN on
                sta     FF90
                ldd     VS_TIMER,x
                stb     FF95
                sta     FF94
                lda     #$20                    ; TMR as the FIRQ source
                sta     FF93
                andcc   #$BF                    ; unmask FIRQ
                puls    a,b,x,pc

* ---------------------------------------------------------------
* firq_handler — ONE SEGMENT.
*
* ★ FIRQ stacks only PC and CC on the 6809, so everything used is saved by hand.
* ★★ The fast path is the SOUNDING segment: acknowledge, step the harmonic pattern,
* emit the pulse, return. The tick work is in the PAD and never runs here.
* ★ The GIME source is acknowledged by READING $FF93; without it the FIRQ re-asserts
* immediately and the machine wedges.
* ---------------------------------------------------------------
firq_handler
                pshs    a,b,x,y,u
                lda     FF93                    ; acknowledge

                dec     msys_divn               ; ★ the prescale: only the FIRST interrupt
                beq     fh_seg                  ;   of a segment sounds (gen_msys_tables.py)
                puls    a,b,x,y,u
                rti

fh_seg          ldx     msys_cur
                lda     VS_DIV,x
                sta     msys_divn
                tst     msys_state
                bne     fh_pad                  ; state 1 = the pad interrupt

* ---- a sounding segment ----------------------------------------
* ★★★ THE HARMONIC PATTERN IS WHERE SILENCE COMES FROM. A value of 1 selects VTBL+0,
* which is always zero, so that segment emits nothing — and the default pattern is
* `1,3,128`, silent/sound/repeat. Half of every note is silence by construction, which is
* why the oracle's speaker toggles once every TWO segments, and why comparing decoded
* segments to captured rows one-for-one makes a correct decode look twice too fast.
                ldy     VS_HARMP,x
                ldb     VS_HARMI,x
* ★★ ABX, NOT `lda b,y`. HM23 is 250 bytes and an indexed offset held in B is SIGNED —
* past 127 it would read BACKWARDS out of the table. ABX adds B unsigned.
fh_hm           pshs    x
                tfr     y,x
                abx
                lda     ,x
                puls    x
                bpl     fh_hmok
                anda    #$7F                    ; bit 7 = loop back to this index
                tfr     a,b
                bra     fh_hm
fh_hmok         incb
                stb     VS_HARMI,x
                deca                            ; pattern value 1..5 -> VTBL+0..+4
                leau    VS_VTBL,x
                ldb     a,u                     ; ★ VTBL+0 is never written: always 0
                beq     fh_quiet

                lda     #$FC                    ; DAC full scale — duty carries amplitude
                sta     DAC                     ; the pulse OPENS
fh_pulse        decb                            ; 2 cyc
                bne     fh_pulse                ; 3 cyc -> 5 cyc/iteration
                stb     DAC                     ; B is 0 — the pulse CLOSES
fh_quiet
                dec     msys_segn
                bne     fh_out

* the tick's segments are done -> switch the timer to the pad and do the work there
                lda     #1
                sta     msys_state
                sta     msys_divn
                lda     #MSYS_PAD_FF91
                sta     FF91
                ldd     #MSYS_PAD_TICKS
                stb     FF95
                sta     FF94
fh_out          puls    a,b,x,y,u
                rti

* ---- the pad interrupt: the DAC is parked, so the decode runs here -------------
fh_pad          clr     msys_state
                jsr     tick_advance
                tst     msys_active
                bne     fh_pad1
                clr     FF94                    ; the song ended: stop the timer dead
                clr     FF95
                clr     FF93
                clr     DAC
                bra     fh_out
fh_pad1         ldx     msys_cur
                lda     VS_FF91,x
                sta     FF91
                lda     VS_DIV,x
                sta     msys_divn
                ldd     VS_TIMER,x
                stb     FF95
                sta     FF94
                bra     fh_out

* ---------------------------------------------------------------
* tick_advance — one MPLAY call's worth of bookkeeping, minus the sound.
* ---------------------------------------------------------------
tick_advance
                pshs    a,b,x
                ldd     msys_ticks
                addd    #1
                std     msys_ticks

                ldx     msys_cur
                dec     VS_TICKS,x
                bne     ta_voice
                jsr     new_note
                bcc     ta_voice
* ---- this voice's stream ended ---------------------------------
* ★★ `MMINIT` IS `LDA #0 / STA R+15 / RTS` [MSYS.S:544-546] — voice 2 hitting `$0000`
* turns the SECOND VOICE off and returns. It does NOT end the song; voice 1 plays on.
* Conflating the two decoded s_Sumup as 18 s against a 51.6 s trace.
                cmpx    #msys_v2
                bne     ta_songend
                clr     msys_two
                ldx     #msys_v1
                stx     msys_cur
                bra     ta_begin
ta_songend      clr     msys_active
                bra     ta_out

ta_voice
* ★★ `MPLAY` toggles R+21 and jumps to MMPLAY on alternate calls [MSYS.S:464-470] — the
* two voices TIME-SHARE the speaker a tick at a time. Never together.
                tst     msys_two
                beq     ta_begin
                lda     msys_phase
                eora    #1
                sta     msys_phase
                bne     ta_v1
                ldx     #msys_v2
                stx     msys_cur
                bra     ta_begin
ta_v1           ldx     #msys_v1
                stx     msys_cur
ta_begin        jsr     tick_begin
ta_out          puls    a,b,x,pc

* ---------------------------------------------------------------
* tick_begin — the head of MPLAY: step the envelope, rebuild the pulse widths, reload
* the segment counter. `msys_cur` selects the voice.
* ---------------------------------------------------------------
tick_begin
                pshs    a,b,x,y
                ldx     msys_cur

* ---- the envelope step [MSYS.S:472-482] ------------------------
                ldy     VS_ENVP,x
                ldb     VS_ENVI,x
                lda     b,y
                bmi     tb_widths               ; bit 7 = pattern over, HOLD the amplitude
                cmpa    #$7F
                bne     tb_apply
* ★ $7F IS A SUSTAIN THAT RELEASES NEAR THE END OF THE NOTE, not a plain hold: `V8HOLD`
* compares the envelope INDEX against the TICKS REMAINING, so the pattern resumes only
* once the note has less left than the envelope has consumed [MSYS.S:471-475].
                cmpb    VS_TICKS,x
                blo     tb_widths
                incb
                stb     VS_ENVI,x
                lda     b,y
                bmi     tb_widths
                cmpa    #$7F
                beq     tb_widths
tb_apply        bsr     voice_apply             ; the MVOLTBL/MVT2 transform, as a function
                bcs     tb_widths               ; selector 7 = leave the amplitude alone
                sta     VS_AMP,x
                inc     VS_ENVI,x

* ---- the widths [NEWMM4, MSYS.S:488-508] ------------------------
tb_widths
                tst     VS_HARMSEL,x
                bne     tb_w1
                clr     VS_HARMI,x              ; harmonic index 0 restarts the pattern
tb_w1           clr     VS_VTBL,x               ; ★ VTBL+0 is ALWAYS zero = silence
                tst     VS_PITCH,x
                bne     tb_w2
                clr     VS_VTBL+1,x             ; a rest: every width zero
                clr     VS_VTBL+2,x
                clr     VS_VTBL+3,x
                clr     VS_VTBL+4,x
                bra     tb_seg
tb_w2           lda     VS_AMP,x
                sta     VS_VTBL+2,x             ; amp
                lsra
                sta     VS_VTBL+1,x             ; amp/2
                adda    VS_AMP,x
                sta     VS_VTBL+3,x             ; amp/2 + amp
                lda     VS_AMP,x
                lsla
                sta     VS_VTBL+4,x             ; amp*2
                inc     VS_VTBL+1,x             ; ...and each one +1
                inc     VS_VTBL+2,x
                inc     VS_VTBL+3,x
                inc     VS_VTBL+4,x
                bsr     scale_widths

tb_seg          lda     VS_SEGLEN,x
                bne     tb_seg1
                lda     #255                    ; LENGTH is never 0; do not count 256
tb_seg1         sta     msys_segn
                puls    a,b,x,y,pc

* ---------------------------------------------------------------
* scale_widths — VTBL+1..+4 *= MSYS_WIDTH_NUM / 4.  X = the voice.
*
* ★★★ THE PORT RUNS AT DOUBLE SPEED, SO AN UNSCALED WIDTH IS THE WRONG VOLUME. Both
* players count the pulse in a 5-cycle delay loop, but the CoCo3 is at 1.7898 MHz against
* the Apple's 1.0205 — so the same number emits a pulse 1.754x NARROW. Measured on the
* first target run: the oracle's 7.83 us floor came out at 5.59.
* ★★ AND THAT IS A VOLUME ERROR, NOT A ROUNDING ONE. The pulse width IS the amplitude
* (P4.5 — Jay heard the first cut in three seconds: "i need more volume"), and the period
* is already right, so an unscaled width is a 29% duty-cycle error at the bottom of the
* range with nothing else wrong to give it away.
* ★ Applied to each ENTRY rather than to the amplitude, because the oracle's `+1` per
* entry is part of the width it counts.
* ---------------------------------------------------------------
scale_widths
                pshs    a,b,y
                leay    VS_VTBL+1,x
                lda     #4
                sta     sw_n
sw_loop         lda     ,y
                ldb     #MSYS_WIDTH_NUM
                mul
                addd    #MSYS_WIDTH_ROUND       ; ★ ROUND: 1*7>>2 is 1, a no-op at exactly
                lsra                            ;   the amplitude P4.5's ear gate was about
                rorb
                lsra
                rorb
                tsta                            ; ★ 2*amp*7/4 can exceed a byte; clamp
                beq     sw_ok                   ;   rather than wrap a wide pulse to a
                ldb     #255                    ;   narrow one, which would read as a
sw_ok           stb     ,y+                     ;   random amplitude drop
                dec     sw_n
                bne     sw_loop
                puls    a,b,y,pc
sw_n            fcb     0

* ---------------------------------------------------------------
* voice_apply — A = the raw envelope value, X = the voice. Returns A transformed,
* or C set meaning "do not store".
*
* ★★ MVOLTBL/MVT2 ARE 6502 OPCODES [MSYS.S:244-245] patched into two one-byte slots in
* MPLAY's amplitude path. There is nothing to port; what ports is the function each pair
* computes. `msys_voice` maps the eight selects onto these seven cases plus "skip".
* ---------------------------------------------------------------
voice_apply
                pshs    b,y
                ldb     VS_VOICE,x
                cmpb    #7
                beq     va_skip
                leay    va_tab,pcr
                lslb
                ldy     b,y
                jmp     ,y
va_skip         puls    b,y
                orcc    #$01                    ; selector 7: the BNE skipped the store
                rts
va_tab          fdb     va_r2,va_r1,va_id,va_l1,va_l2,va_eor,va_add,va_id
va_r2           lsra
                lsra
                bra     va_done
va_r1           lsra
                bra     va_done
va_l1           lsla
                bra     va_done
va_l2           lsla
                lsla
                bra     va_done
va_eor          eora    #$0F
                bra     va_done
va_add          adda    #$07
va_id
va_done         puls    b,y
                andcc   #$FE                    ; C clear = store it
                rts

* ---------------------------------------------------------------
* new_note — NEWNOTE. Walk events until one produces sound.
* Operates on `msys_cur`. Returns C=1 if THIS STREAM ended (which for voice 2 means only
* that the second voice is over — see tick_advance).
* ---------------------------------------------------------------
new_note
                pshs    b,x,y,u
                ldx     msys_cur
                ldu     #2000                   ; ★ a runaway guard: a mis-decoded stream
                                                ;   must stop, not hang the machine
nn_loop         leau    -1,u
                cmpu    #0
                lbeq     nn_end
                clr     VS_ENVI,x
                clr     VS_HARMI,x

* the pointer PRE-INCREMENTS by two — which is why every song starts with a dead pair
                ldd     VS_PTR,x
                addd    #2
                std     VS_PTR,x
                subd    #MSYS_SONG_BASE
                cmpd    #1023
                lbhs     nn_end                  ; ran off the page
                tfr     d,y
                leay    msys_song_page,y
                lda     ,y                      ; byte 0
                ldb     1,y                     ; byte 1
                tstb
                lbeq    nn_cmd

* ---- byte1 != 0: pitch first, then the discriminator ------------
                pshs    a,b
                anda    #$FC
                sta     VS_PITCH,x
                beq     nn_b1
                lsra
                lsra
                adda    VS_XPOSE,x
                sta     VS_PITCH,x
nn_b1           puls    a,b                     ; A = byte0, B = byte1, both intact
                bitb    #$3F
                bne     nn_note
                andb    #$C0
                cmpb    #$C0
                beq     nn_call
                cmpb    #$80
                lbeq     nn_chain
                cmpb    #$40
                beq     nn_voice2
                bra     nn_loop

* ---- a NOTE ------------------------------------------------------
nn_note         ldb     1,y
                andb    #$3F                    ; ★★★ SIX BITS. See the header.
                stb     VS_TICKS,x
                beq     nn_loop                 ; a zero-length note sounds nothing
                ldb     1,y
                andb    #$C0
                lsrb
                lsrb
                lsrb
                lsrb                            ; byte1 bits 7..6 -> 0,4,8,12
                anda    #$03                    ; byte0 bits 1..0
                pshs    a
                orb     ,s+
                pshs    b                       ; B = the 4-bit instrument index
                ldy     #msys_amptbl
                lda     b,y
                sta     VS_AMP,x
                puls    b
                lslb
                ldy     #msys_envtbl
                ldy     b,y
                sty     VS_ENVP,x
                jsr     note_pitch
                lbra     nn_done

* ---- the CALL, and its depth ------------------------------------
* ★★★ DEPTH IS ONE, BY CONSTRUCTION. `R+24` is a BOOLEAN, not a stack pointer: a call
* while already in a call takes the RETURN path instead [MSYS.S:402-406]. So the whole
* return state is two bytes and a flag — and `msys_stop` clears both, or a torn-down
* player restarts mid-phrase.
* ★ Calls jump BACKWARD, and the operand is doubled first: it is an EVENT count.
nn_call         tst     VS_INCALL,x
                bne     nn_ret
                ldd     VS_PTR,x
                std     VS_SAVED,x
                ldb     #1
                stb     VS_INCALL,x
                ldb     ,y                      ; byte 0
                clra
                lslb
                rola                            ; D = byte0 * 2
                pshs    a,b
                ldd     VS_PTR,x
                subd    ,s++
                std     VS_PTR,x
                lbra    nn_loop

nn_ret          tst     VS_INCALL,x
                lbeq     nn_loop                 ; a return with nothing to return to
                ldd     VS_SAVED,x
                std     VS_PTR,x
                clr     VS_INCALL,x
                lbra    nn_loop

* ---- the second voice -------------------------------------------
* ★★ `%01` SPLITS THE STREAM. Voice 2 plays from HERE; voice 1 skips FORWARD over voice
* 2's part by byte0*2 bytes [MSYS.S:428-438]. Both then run, a tick each, alternating.
nn_voice2       cmpx    #msys_v1
                lbne    nn_loop                 ; voice 2 cannot start a third voice
                ldd     VS_PTR,x
                ldx     #msys_v2
                std     VS_PTR,x
                jsr     voice_defaults
                ldx     #msys_v1
                ldb     ,y                      ; byte 0
                clra
                lslb
                rola
                pshs    a,b
                ldd     VS_PTR,x
                addd    ,s++
                std     VS_PTR,x
                ldb     #1
                stb     msys_two
                stb     msys_phase
                ldx     #msys_v2
                stx     msys_cur
                jsr     new_note                ; prime voice 2
                ldx     #msys_v1
                stx     msys_cur
                bcc     nn_v2ok
                clr     msys_two                ; voice 2 was empty
nn_v2ok         lbra    nn_loop

* ---- song chaining and the conditional alternate ------------------
* ★ `%10` sets the NEXT song's index and keeps playing; the `$0000` at the end is what
* actually restarts. `ALTSNG` is the conditional half: with the "has played" flag set, a
* negative operand redirects to an alternate song instead [MSYS.S:376-382].
nn_chain        deca
                bpl     nn_ch1
                tst     msys_played
                lbeq    nn_loop                 ; flag clear: just carry on
                anda    #$7F
                sta     msys_index
                bra     nn_end
nn_ch1          sta     msys_index
                lbra    nn_loop

* ---- byte1 == 0: a command, discriminated on byte 0 ------------
nn_cmd          tsta
                beq     nn_end                  ; $00 00 — end of stream
                cmpa    #$FE
                lbeq    nn_ret
                cmpa    #$FD
                beq     nn_flag
                cmpa    #$FF
                beq     nn_pause
                cmpa    #9
                blo     nn_vsel
                bra     nn_isel

* ★ `$FD` marks the song as HAVING BEEN PLAYED, at `$1E80,[$1E60]` — game-side state the
* oracle's `ALTSNG` reads to choose a shorter alternate on later passes. The port keeps the
* flag so the mechanism is present; nothing in the intro sets a second `$1E60`, so the
* alternate never fires there. It is documented, not guessed at.
nn_flag         ldb     #$80
                stb     msys_played
                lbra    nn_loop

nn_pause        ldb     #$3F                    ; 63 ticks of silence (six-bit field)
                stb     VS_TICKS,x
                clr     VS_PITCH,x
                ldb     msys_length             ; LENGTH[0]
                stb     VS_SEGLEN,x
                clr     VS_FF91,x
                ldb     #1
                stb     VS_DIV,x
                ldd     msys_period+2           ; row 0's timer count
                std     VS_TIMER,x
                bra     nn_done

nn_vsel         deca                            ; select 1..8 -> index 0..7
                ldy     #msys_voice
                lda     a,y
                sta     VS_VOICE,x
                lbra    nn_loop

nn_isel         suba    #9
                clr     VS_XPOSE,x
                cmpa    #32
                blo     nn_is1
                ldb     #12                     ; an octave up, above 32
                stb     VS_XPOSE,x
                anda    #$1F
nn_is1          sta     VS_HARMSEL,x
                ldy     #msys_htptbl
                ldb     a,y
                addb    VS_XPOSE,x
                stb     VS_XPOSE,x
                lsla
                ldy     #msys_harmtbl
                ldy     a,y
                sty     VS_HARMP,x
                lbra    nn_loop

nn_end          puls    b,x,y,u
                orcc    #$01                    ; C=1 — this stream is over
                rts
nn_done         puls    b,x,y,u
                andcc   #$FE                    ; C=0 — a sounding event is loaded
                rts

* ---------------------------------------------------------------
* note_pitch — VS_PITCH is set; fill in SEGLEN, FF91, DIV and TIMER from the tables.
* ---------------------------------------------------------------
note_pitch
                pshs    a,b,y
                ldb     VS_PITCH,x
                cmpb    #75
                blo     np_ok
                clrb                            ; out of range -> a rest, never a wild read
                stb     VS_PITCH,x
np_ok           ldy     #msys_length
                lda     b,y
                sta     VS_SEGLEN,x
                lda     #MSYS_PERIOD_ROW
                mul                             ; D = pitch * 4
                ldy     #msys_period
                leay    d,y
                lda     ,y
                sta     VS_FF91,x
                lda     1,y
                sta     VS_DIV,x
                ldd     2,y
                std     VS_TIMER,x
                puls    a,b,y,pc

* ---------------------------------------------------------------
msys_cur        fdb     0
msys_active     fcb     0
msys_index      fcb     0
msys_two        fcb     0       ; two-voice enabled
msys_phase      fcb     0       ; which voice the next tick belongs to
msys_played     fcb     0       ; the `$FD` flag
msys_state      fcb     0       ; 0 = sounding segments, 1 = the pad
msys_segn       fcb     0       ; segments left in this tick
msys_divn       fcb     1       ; the prescale counter

msys_v1         rmb     VS_SIZE
msys_v2         rmb     VS_SIZE

                include "build/gen/msys_tables.s"
                include "build/gen/msys_songs.s"

                ifdef   OBJTARGET
                endsection
                endc
