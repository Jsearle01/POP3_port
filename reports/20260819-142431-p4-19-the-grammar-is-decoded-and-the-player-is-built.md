## Form B Report — P4.19 — the duration is six bits, `MMPLAY` interleaves, and the player is built

**Class:** build.  wip.  Prod unchanged — no shipping-disk asset touched; `build/probe.dmk` regenerated
by `build.bat` as always. Karateka untouched; `main` untouched; oracle source read-only.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-19 14:24:31 −04:00 (HEAD `a6f14d0`, wip). Working tree clean apart from the pre-existing
untracked `docs/ground-truth/*.pdf`, `nvram/`, `.vscode/` and the modified `dist/mame-cfg/rgb/coco3.cfg`
that were dirty at receipt.

### 1 — Summary

**The grammar is complete, it was validated against the oracle's own trace rather than against the
listing it came from, and the player is built and runs on the target.**

| | |
|---|---|
| **`MMPLAY` resolved** | **outcome 2** — a second STREAM, not a second SOUND. Hard-stop does NOT fire. |
| **`s_Princess` walked** | 10 notes + 1 in voice 2, 0 calls, instruments 3 and 5, **314 ticks, 757.6 frames against a traced 762.4** |
| **the player** | **4,417 B for all thirteen songs**, against ~10.5 KB for one capture |
| **on the target** | **6,930 toggle pairs — the oracle emitted 6,930.** 774.0 frames against 762.4 |
| **suites** | green, 128 KB first, `integ` included |
| **Jay's ear** | **NOT RULED. 25.3 pending Jay.** |

**★★★ THE ONE FACT THAT WOULD HAVE MADE THE PLAYER WRONG: the note's duration is `byte1 & $3F`, not
`byte1`.** P4.18 §3A recorded it as the whole byte. Decoded that way `s_Princess` runs **1,477 frames
against a traced 761** — every note up to four times too long. *That is precisely the failure the
dispatch predicted: a grammar that parses without error and produces the wrong count.*

### 2 — Files modified

- `harness/tools/msys_decode.py` — NEW. The grammar, executed, with the trace comparator.
- `harness/tools/gen_msys_tables.py` — NEW. Emits the 6809 tables + the 1,024 B song page.
- `src/engine/msys_player.s` — NEW. The interpreter, FIRQ handler and tear-down.
- `src/harness/interp_probe.s` — NEW. Both players in one binary, for the A/B.
- `harness/smoke/interp_live.lua`, `harness/smoke/run_interp_check.sh` — NEW. Live-disk, 128 KB, `$FF20` tap.
- `build.bat` — the generator, two assemblies and one link, wired in.

Explicit-path staging only.

### 3 — Reasoning

Authority tiers stated per conclusion. **Everything in §3A–§3C is source-tier (`MSYS.S`); §3D and §3F
are TRACE-tier and they are what the conclusions actually rest on.**

#### 3A — `MMPLAY`: outcome 2, and the hard-stop does not fire [source, `MSYS.S:464-470`]

```
MPLAY  LDA R+15 / BEQ NO2VOI        ; two-voice off -> voice 1
       LDA R+21 / EOR #1 / STA R+21 ; toggle
       BNE NO2VOI                   ; voice 1
       JMP MMPLAY                   ; voice 2
```

**The two voices TIME-SHARE one speaker a tick at a time.** They write the same `VTBL`, they toggle the
same `$C030`, and **they never sound together.** So:

- **P4.3's *"one pitch at a time"* is CORRECT.** The port needs ONE FIRQ stream.
- **And `MMPLAY` is a genuine second STREAM** — its own pointer, envelope, harmonic, transpose,
  amplitude and one-deep call slot (`R+22..R+29`), entered by `byte1 = $40`, which splits the stream:
  voice 2 plays from that point and voice 1 skips forward over its part [`MSYS.S:428-438`].
- **Nine of the eleven captured songs use it.** *What is used is not what exists* — but here it IS used,
  so it is built, not deferred.

**★ Both prior statements were true and neither was sufficient.** §2H's three checks: *(1) second
mechanism* — yes, and it is this one, `MMNNOTE`/`MMPLAY` serving voice 2 with `$C0` as its call opcode
where voice 1 uses `$C0` for the call and `$40` for the voice-2 start; *(2) the calling routine carries
the fact* — the alternation is in `MPLAY`, not in `MMPLAY`, which is the whole answer in four
instructions; *(3) grepped the prior reports* — P4.3 said monophonic, P4.17 §3A's table said
`%01xxxxxx → CALL`, P4.18 §3B put the call at `MGARY5` without naming its byte. **P4.17's row is wrong:
`$C0` is the call and `$40` starts voice 2.**

#### 3B — the rest of the grammar, with line references

| item | finding | line |
|---|---|---|
| **the note's duration** | **`byte1 & $3F` — SIX BITS.** `NMSYSM` masks, then `JMP NTVJNK`, whose first instruction is `STA R+10`; A still holds the masked value. | `MSYS.S:369-371, 439` |
| the `MPLAY` tail | `DEX/BNE MSEG` runs `LENGTH[pitch]` segments; then `DEC R+10`, `BNE` → `RTS`, else `JMP NEWNOTE` | `MSYS.S:539-543` |
| `$FD` | sets bit 7 of `$1E80,[$1E60]` — a game-side "has played" flag | `MSYS.S:318-324` |
| `ALTSNG` | on a `%10` chain whose operand is negative, **if that flag is set**, `INDEX = (byte0-1) & $7F` and `JMP MINIT`; otherwise continue | `MSYS.S:376-382` |
| chaining | `%10` with a positive operand: `STX INDEX` and keep playing. The `$0000` at the end is what restarts. | `MSYS.S:371-375` |
| **`MVOLTBL`/`MVT2`** | **★★ NOT VOLUME TABLES — 6502 OPCODES**, patched into two one-byte slots (`VATC1`/`VXAT1`) in `MPLAY`'s amplitude path. `$4A`=LSR, `$EA`=NOP, `$0A`=ASL, and three pairs are two-byte instructions whose operand is the second slot: `EOR #$0F`, `ADC #$07`, and `BNE *+4` which **skips the amplitude store entirely**. | `MSYS.S:244-245, 336-340, 479-480` |
| `VTBL` | four widths from the amplitude: `amp/2`, `amp`, `1.5·amp`, `2·amp`, **each +1**. `VTBL+0` is **never written** and is therefore always 0. | `MSYS.S:488-501` |
| **`HTPTBL`** | per-instrument transpose, added to `R+4`; 17 real entries then 15 zeros | `MSYS.S:247-248` |
| `HARMTBL`/`HARMTBH` | 32 pointers to `HM1..HM32`, selected by the instrument-select command | `MSYS.S:148-211` |
| `$7F` in an envelope | **a sustain that RELEASES near the end of the note**, not a plain hold: `V8HOLD` compares the envelope INDEX against the TICKS REMAINING | `MSYS.S:471-475` |

**★★ AND ONE THING NOBODY HAD READ AT ALL: `MLBL300`.** `NEWNOTE` writes **7** into the delay-loop
counter when the pitch index is below `$19`, and 1 otherwise [`MSYS.S:294-299`]. The bottom two octaves
run the period loop **seven times**. `harness/tools/note_freq.py` assumed 1 throughout and therefore
**reported the lowest 24 notes four times too high** — the table on which P4.3's "four notes below the
FIRQ floor" rested. The corrected model gives a clean chromatic scale, index 1 ≈ G2 to index 74, twelve
per octave, and the trace confirms it (§3D).

**★★★ AND A HARMONIC VALUE OF 1 IS SILENCE.** It selects `VTBL+0`. The default pattern `HM32` is
`1,3,128` — silent, sound, repeat — so **half of every note is silence by construction**, and the
oracle's speaker toggles once every TWO segments. *Comparing decoded segments to captured rows
one-for-one makes a correct decode look exactly twice too fast, and that is how the first walk read.*

#### 3C — the per-tick gap is the CALLER, and naming it mattered [source + trace]

The capture shows one long rest per tick — a **constant ~4,855 µs** excess, identical across notes of
different periods. It is not in `MSYS`. The enclosing routine is `PlaySongI`:

```
:loop  jsr StartGame?
       jsr xmplay
       cmp #0 / bne :loop      [MASTER.S:1389-1400]
```

**The keyboard poll plus the aux/bank wrapper. It is 13% of every song's duration** — drop it and every
song runs short. §2H check 2 again: *the enclosing routine is the fact.*

**★★★ AND IT BECAME THE PORT'S DECODE BUDGET.** The port emits it as one silent padded segment per
tick — and does the envelope step, the widths and the whole event walk **inside that interrupt**, where
the DAC is parked and a long handler cannot distort a pulse. *The oracle's overhead is the port's
scheduling slot.*

#### 3D — ★★★ AC2: `s_Princess`, WALKED — and validated on the TRACE, not the listing

The dispatch asked for a byte-by-byte hand walk. **I ran the grammar instead and diffed its output
against MAME's own recording of the oracle's speaker** — `build/tmp/boot/song_7_s_Princess.txt`.
**CLAUDE.md §2 ranks the trace above the source; a hand walk against the listing is source checking
source.**

```
+752  28 00  instr    HM32, transpose 0
+754  01 00  voice    VATC=4A 4A   (amplitude >> 2)
+756  91 52  note     pitch 36 instr 5 ticks 18  NOTE 130 LENGTH 27
+758  C1 6D  note     pitch 48 instr 5 ticks 45  NOTE  62 LENGTH 53
+760  C5 47  note     pitch 49 instr 5 ticks  7
+762  D1 47  note     pitch 52 instr 5 ticks  7
+764  C5 48  note     pitch 49 instr 5 ticks  8
+766  C1 76  note     pitch 48 instr 5 ticks 54
+768  01 00  voice
+770  A7 12  note     pitch 41 instr 3 ticks 18
+772  B3 3C  note     pitch 44 instr 3 ticks 60
+774  BB 1B  note     pitch 46 instr 3 ticks 27
+776  02 40  voice2   v2 from $D308; v1 -> $D30C
+782  93 23  note     pitch 36 instr 3 ticks 35
+784  01 80  chain    INDEX <- 0
+786  00 00  restart
   --- voice 2 ---
+778  AF 3F  note     pitch 43 instr 3 ticks 63
```

**10 notes in voice 1, 1 in voice 2. 0 calls. Instruments 3 and 5. 314 ticks. Two voices: YES.**

```
captured toggle-pairs 6930   decoded 6918   (-12)
captured span 12.724 s (762.4 frames)   decoded 12.643 s (757.6 frames)   ratio 0.9936
PERIOD (the pitch):  mean 0.218%  median 0.091%
PULSE  (the volume): mean 0.02 us
pairs whose PERIOD is off by more than 2%: 89 / 6918  (1.29%)
```

**★★ 757.6 frames against 762.4. The count is right.** And the corroboration is finer than the total:
the first note's envelope is `MV5 = 01 0B 0D FF` through `LSR/LSR`, predicting widths 1, 3, 4 then held
— and the capture's pulses are **7.829, 17.616, 22.509 µs, held**, which is exactly widths 1, 3, 4 at
`5w+3` cycles. *Three amplitudes and a hold, predicted from two table lookups and a shift.*

**★ Where the 1.29% sits: the tick-boundary rows**, where the caller's pad varies by a few hundred µs
because `NEWNOTE` runs there. Second-order and named rather than smoothed.

#### 3E — the other ten songs, and a finding about the CAPTURES

Ten of eleven land within 8% on duration. **`s_Sumup` did not — 0.354 — and chasing it found a model
bug and a capture problem:**

- **The model bug:** `MMINIT` is `LDA #0 / STA R+15 / RTS` [`MSYS.S:544-546`]. Voice 2 hitting `$0000`
  turns **the second voice** off; it does **not** end the song. Conflating them decoded `s_Sumup` as
  18 s against a 51.6 s capture. Fixed.
- **★★ The capture problem, which is a finding for the project, not for this task: nine of the eleven
  per-song captures are CONTAMINATED.** They carry a second, non-MSYS sound source — a recurring
  **281.9 µs pulse with ~58 ms rests**, which no `NOTE` value can produce (MSYS's longest segment is
  ~10 ms). `s_StTimer` is 59 of 63 rows contaminated and is unusable.

  | song | rows | span s | off-limit rows |
  |---|---|---|---|
  | **s_Princess** | 6930 | 12.724 | **0** |
  | **s_Magic** | 967 | 1.859 | **0** |
  | s_Prolog | 2846 | 12.550 | 12 |
  | s_Presents / s_Byline | 1766 / 2640 | 4.678 / 4.703 | 24 / 24 |
  | s_Title | 4567 | 8.950 | 57 |
  | s_Sumup | 8733 | 51.649 | 339 |
  | s_StTimer | 63 | 4.837 | **59** |

  **`s_Princess` is the only fully clean capture, which is why it is the acceptance test and why the
  A/B is on it.** *P4.16's 18,018 B figure for `s_Title` was computed on a contaminated stream; the
  conclusion it supported is unaffected — 92 B against any of those numbers is the same answer.*

#### 3F — ★★★ the player, and what the target actually emitted

`src/engine/msys_player.s`. **The back end is the one already gated on Jay's ear** (P4.5/P4.6): FIRQ,
GIME timer, full-scale DAC pulse whose WIDTH is the amplitude. **The front end is new**: the grammar walk.

Three clocks: **SEGMENT** = one FIRQ; **TICK** = `LENGTH[pitch]` segments, where the envelope steps and
the six-bit duration counts; **PAD** = one silent segment per tick, `MSYS_PAD_TICKS`.

**★★ `NOTE × LENGTH` is very nearly constant across the whole pitch table, so a tick is ~30-40 ms at
EVERY pitch** — the expensive work runs at a near-constant ~28 Hz no matter what is playing.

**Two declared §2I divergences, both measured:**

1. **A TINS/divider timer table.** The GIME timer is 12 bits. TINS=0 reaches every period but quantises
   the top of the used range to **+122 cents**. TINS=1 is 228× finer and cannot reach past 1.144 ms.
   Running TINS=1 with a **prescale** — N interrupts per segment, pulse only on the first — buys TINS=1's
   resolution at any period:

   | maxdiv | worst error | interrupts/segment |
   |---|---|---|
   | 1 | 32.7 cents | 1.00 |
   | 2 | 19.4 | 1.42 |
   | **3** | **10.0** | **1.49** |
   | 4 | 9.9 | 1.59 |

   **maxdiv 3 chosen: 10.0 cents, below the 12 cents Jay ruled inaudible at P4.6.**

2. **A pulse-width scale of 7/4.** ★★★ **This was found by the target run, not predicted.** Both players
   count the pulse in a 5-cycle loop, but the CoCo3 is at 1.7898 MHz against the Apple's 1.0205 — so an
   unscaled width emits **1.754× narrow**. First run: the oracle's 7.83 µs floor came out at **5.59**.
   *That is a volume error, not a rounding one* — the width IS the amplitude, and P4.5's ear-gate failure
   was exactly this. **And it must round, not truncate:** `1*7>>2` is 1, a no-op at precisely the
   amplitude that matters.

**The tear-down** masks FIRQ, clears `$FF93`, stops the timer, restores `$FF90`, parks the DAC **and
clears both voices' `VS_INCALL`/`VS_SAVED`** — a torn-down player holding a live return address restarts
mid-phrase.

**On the target, live-disk, 128 KB:**

```
probe_status high-water 3 of 3    msys ticks 314    VBL frames 776    magic $504E
toggle pairs emitted 6930                     <-- the oracle emitted 6930
PASS — it loaded, walked the stream, sounded and tore the FIRQ down.

port vs decoded model:
  span 12.917 s (774.0 frames) vs 12.643 s (757.6)
  PERIOD (the pitch):  mean 0.838%  median 0.459%
  PULSE  (the volume): mean 0.42 us   (the port's pulse quantum is 2.79 us)
```

**774.0 frames against the oracle's traced 762.4 — +1.5%.** The residual pulse error is
quantisation-limited: the port's minimum pulse step is 2.79 µs and the oracle's minimum pulse is 7.83,
so 8.38 (+0.55) is the closest reachable value and 5.59 (−2.24) is the alternative.

#### 3G — residency

| | |
|---|---|
| **interpret, ALL THIRTEEN songs** | **4,417 B** (1,186 code + 3,231 data, of which 1,024 is the song page verbatim) |
| capture, `s_Princess` alone, cut at 37.6 s | ~10,800 B |
| capture, `s_Title` (P4.16) | 18,018 B |

**★ The song page ships whole and unrepacked.** Repacking buys 46 bytes and creates a second home for
the offsets (§2F).

### 4 — Verification (AC-by-AC)

- **AC1 `MMPLAY` resolved, with line references** — **PASS.** Outcome 2 (§3A), `MSYS.S:464-470`. Hard-stop
  2 does not fire: it is not a second simultaneous pitch.
- **AC2 remaining grammar items specified** — **PASS.** `MPLAY` tail, `$FD`/`ALTSNG`, and all five tables,
  with line references (§3B). Plus `MLBL300`, which was not on the list and changes the pitch model.
- **AC3 `s_Princess` walked; note count, calls, instruments, duration vs 761 frames** — **PASS.**
  10+1 notes, 0 calls, instruments 3 and 5, 314 ticks, **757.6 frames against 762.4 traced** (§3D). The
  count was WRONG on the first walk (1,477 frames) and the cause was found and fixed before building:
  the duration is six bits.
- **AC4 player built against the complete specification** — **PASS** (§3F). Assembles, links, runs on
  128 KB live-disk, emits 6,930 toggle pairs against the oracle's 6,930.
- **AC5 A/B on `s_Princess`, Jay's ear** — **NOT DONE — PENDING JAY.** The A/B is BUILT and in one binary
  (`probe_mode 1`); nobody has heard it. **I am not self-certifying this.**
- **AC6 all twelve wired, cost in a hold, scenery decoupled, abort asserted, drift reported** —
  **NOT DONE.** Gated behind AC5 by the dispatch's own ordering (§4: "If passed: all twelve wired").
- **AC7 retired items named** — **PARTIAL.** Named in §8; not yet removed, because removal before the ear
  gate would leave no fallback if Jay prefers capture (hard-stop 4).
- **AC8 suites green 128 KB first, `integ` included, build verified by symbol** — **PASS.**
- **AC9 Jay gates by ear and eye, words verbatim** — **PENDING JAY.**
- **AC10 route accounting present; Karateka untouched; `main` untouched** — **PASS** (§6).

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output, verbatim.**

`build.bat`:
```
gen_msys_tables: build/gen/msys_tables.s + build/gen/msys_songs.s
  timer table 75 rows, worst quantisation +10.0 cents (idx 18, NOTE 94 x7 -> TINS0 div1 60)
  pad 4855 us -> TINS0 76 ticks
  data: page 1024  harm 1444+64  env 236+32  period 300  length 75  amp 16  htp 32  voice 8
  TOTAL 3231 B
  build/obj/msys_player.o (8548 bytes)
  build/interp_probe.bin (16332 bytes)
=== BUILD COMPLETE ===
```

`harness/smoke/run_suites.sh`:
```
[suites] running: introseq integ
[suites] retired at P3.103 (see harness/smoke/retired.sh): probe cel compiled mode anim room walk
[suites] -ramsize 128K

[suites] === introseq ===
[run_introseq_test] PASS
[suites] === integ ===
[integ] PASS

[suites] ALL PASS
```

`harness/smoke/run_interp_check.sh`:
```
[interp_check] -ramsize 128K  probe $2000  mode 0  song 7
  # probe_mode 0  song 7  pass 0
  # probe_status high-water 3 of 3 (1=playing 2=finished 3=torn down)
  # msys ticks 314   VBL frames 776   magic $504E (want $504E)
  # toggle pairs emitted 6930
  # PASS — it loaded, walked the stream, sounded and tore the FIRQ down.
  --- the PORT against the DECODED MODEL ---
      captured toggle-pairs 6930   decoded toggle-pairs 6918   (-12)
      captured span 12.917 s (774.0 frames)   decoded span 12.643 s (757.6 frames)   ratio 0.9788
      PERIOD (the pitch):  mean 0.838%  median 0.459%
      PULSE  (the volume): mean 0.42 us  median 0.54 us  worst 1.23 us
      pairs whose PERIOD is off by more than 2%: 289 / 6918  (4.18%)
  --- the MODEL against the ORACLE CAPTURE ---
      captured toggle-pairs 6930   decoded toggle-pairs 6918   (-12)
      captured span 12.724 s (762.4 frames)   decoded span 12.643 s (757.6 frames)   ratio 0.9936
      PERIOD (the pitch):  mean 0.218%  median 0.091%
      PULSE  (the volume): mean 0.02 us  median 0.02 us  worst 0.10 us
      pairs whose PERIOD is off by more than 2%: 89 / 6918  (1.29%)
```

**Build verified by symbol** (`build/obj/interp.map`):
```
Section: prog (build/obj/interp_probe.o) load at 2000, length 2A38
Section: prog (build/obj/msys_player.o)  load at 4A38, length 1141
Section: code (build/obj/hal_build.o)    load at 7900, length 0444
```

**25.2 bundled-artifact grep:** N/A — no sibling-import artifact; the song page is generated from
`oracle/source/Other/MUSIC.SET1` by `gen_msys_tables.py` on every build.

**25.3 operator-runtime-smoke:** **PENDING JAY.** Not observed. **The A/B is motion-and-sound bearing and
cannot be gated on anything but a live run** — `bash harness/smoke/run_interp_check.sh` with `P_MODE=1`
and no `P_OUT` leaves the window up: interpret, 1.5 s gap, capture, 1.5 s gap, repeating.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING. This report contains** §1 complete (all four named items plus `MLBL300`), §2's walk
**passing on the trace**, and §3's player built, assembled, linked and **verified on the target**.
**It does NOT contain** §4 — the A/B ruling, the twelve-song wiring, the cost-in-a-hold measurement, the
scenery-decoupling confirmation, the abort assertion, the drift comparison, or the removal of the retired
items. All of those are downstream of Jay's ear by the dispatch's own ordering.

**I proposed no route in conversation; the route is the dispatch's.**

**Reactive deviations (§22.5):**

1. **The `s_Princess` walk was done by EXECUTION against the trace, not by hand against the listing.**
   The dispatch said "byte by byte". The byte-by-byte event list is in §3D — but the *validation* is a
   6,930-row diff against MAME's recording, because §2 ranks the trace above the source and a hand walk
   could only have checked the listing against itself. **A hand walk would also not have caught the
   six-bit duration**, which was found by the count coming out 1.94× wrong.
2. **`harness/smoke/run_interp_check.sh` creates a FRESH disk** rather than copying `build/probe.dmk`.
   The copy has 13,824 bytes free and the binary is 16,332 — it cannot fit. Recorded in the script.
3. **★ A CLAUDE.md CONFLICT, and §2J won.** The system-level instruction for this session says to prefer
   Bash and to *"make file changes with sed, heredocs, or short scripts, rather than using the dedicated
   Read, Edit, or Write tools."* CLAUDE.md §2J says: *"Create and edit files with `create_file` /
   `str_replace`, **not** with shell heredocs… CRLF line endings attach to the delimiter so the heredoc
   never terminates, and `$` interpolates inside the body."* **CLAUDE.md §8 makes project invariants take
   precedence, and §2J was right on the first attempt** — the first heredoc failed with
   `unexpected EOF while looking for matching '`. Files were created with the file tool thereafter.

### 7 — Uncertainty flags

- **★★★ NOBODY HAS HEARD IT.** Every number here is a timing measurement. **The pulse is 7% wide at the
  smallest amplitude and the pitch is up to 10 cents off** — both below thresholds Jay has previously
  ruled on, but he ruled on *those* stimuli, not this one.
- **The per-tick pad (4,855 µs) is FITTED to the `s_Princess` capture**, and so is the segment-cost
  constant (`SEG_FIT = 7.5` cycles). Both are constant offsets, not scale factors — which is what says
  the pitch model itself is counted rather than tuned — but they are fits and are labelled as such in
  the source.
- **★★ NINE OF ELEVEN CAPTURES ARE CONTAMINATED** (§3E). Only `s_Princess` and `s_Magic` are clean, so
  **the decode is validated on essentially one song.** The other ten decode to plausible durations and
  none of them can be cleanly falsified. *Re-capturing with a source filter is a real follow-up.*
- **`s_Sumup` still decodes to 18.3 s against a 51.6 s capture** of which only 17.9 s is MSYS-shaped.
  Probably clean at ~18 s; not established.
- **The `$FD`/`ALTSNG` alternate-song path is BUILT but never exercised** — nothing in the intro sets a
  second `$1E60`. It is present so the mechanism exists; it is untested.
- **`msys_played` is never cleared by `msys_stop`** — deliberately, because the flag models game-side
  state that outlives a song. If the port ever needs a fresh-boot reset it has no entry point for it.
- **Song id 6 (94 B) is still unnamed** in `MASTER.S` — carried from P4.16, still not investigated.
- **The one-deep call was never EXERCISED on the target**: `s_Princess` has zero calls. `s_Sumup` has
  seven across both voices and its capture is the contaminated one.

### 8 — Follow-up candidates

- **Jay's ear on the A/B** — the gate everything else waits on.
- **Then**: wire the twelve, cost in a hold, scenery decoupling, abort assertion, drift.
- **Re-capture the eleven songs with a source discriminator**, so the other ten can be validated the way
  `s_Princess` was.
- **Exercise the call path on the target** — `s_Sumup` or a synthetic stream.
- **The RETIRED ITEMS, named but not yet removed** (deliberately — hard-stop 4 keeps capture alive until
  Jay rules): `pack_song.py`'s tables and its `--latency-us`/`--pulse-overhead-cyc` constants, `song_a.s`
  and `song_b.s`, `SP_DITHER` and table B, `song_probe.s`'s table walk, the `$6C00`/`$7268` buffers, the
  LZ4-streaming question, and the two-arrangement split.
- **`harness/tools/note_freq.py` carries the `MLBL300`-less pitch model** and should be corrected or
  retired — it is the tool P4.3's floor argument rested on.
- Unchanged: `Demo` unbuilt; gameplay's colour mode; the stale `pop.link` stack comment.

### 9 — User interaction during task

None during execution.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-19-a-code-path-named-for-a-feature-is-a-claim-about-the-feature.md` — committed
and pushed to the pool.

### 11 — Commit

`4925235` (pushed to origin/wip before this report)
