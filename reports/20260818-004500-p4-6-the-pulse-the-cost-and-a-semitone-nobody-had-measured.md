## Form B Report — P4.6 — fix the pulse, attribute the cost, build the A/B — and a pitch error twenty times larger than the one under test

**Class:** build + recon.  wip.  Prod unchanged — the shipping disk `build/probe.dmk` still
carries 6 files / 36,673 bytes / 13,824 B free, and no instrument is on it.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-18 00:45 (HEAD `a74e63e`, wip). Working tree carries the P4.6 changes listed in
§2 plus pre-existing untracked PDFs under `docs/ground-truth/` and `dist/mame-cfg/rgb/coco3.cfg`
(MAME rewrites it on every run; untouched by this task).

### 1 — Summary

The dispatch's premise was that the slice's pulse width blocked the ear gate. It did, and it
is fixed and now measured on the bus rather than modelled. **But measuring the output instead
of the pipeline turned up a much larger defect that nothing in the dispatch, the plan or the
harness suspected: the slice was playing 7.17% long — about 1.2 semitones flat — because the
GIME runs `nnn+2` ticks and the handler's restart latency had never been measured.** That is
twenty times the quantisation error the A/B was built to test. Both constants are now measured
by mechanism, folded into the packer, and the emitted duration is within 0.5%. The 2.3× cost
gap is attributed by ablation to four named pieces, none of them tuned; the cost is
re-reported at **5.5%**, which is *higher* than P4.5's 4.3% partly **because the song is no
longer playing slow.** The A/B is built as one binary with two tables and one code path, and
both renditions plus the oracle's are captured as WAV.

### 2 — Files modified

- `src/harness/song_probe.s` — new row format (`ticks/frac/width/count`); timer rewritten per
  interrupt with a Bresenham accumulator; two tables + `probe_mode` (0 = A once, 1 = A/gap/B/gap
  looping, 2 = B once); pulse counted in B so the close is `stb DAC` with the width load hoisted
  out of the pulse window; three build-time ablations (`SP_NODITHER`, `SP_NOCOUNT`, `SP_NOPULSE`).
- `harness/tools/pack_song.py` — two-pass quantisation against **two** measured latencies weighted
  per row by run length; `--dither`; pulse-width mapping corrected for the handler's own overhead;
  header rewritten to state what the file contains.
- `harness/smoke/song_live.lua` — `P_PULSE` fidelity tap on `$FF20` (emitted pulse and emitted
  period, attributed by mechanism), measured FIRQ rate, `probe_mode` poke.
- `harness/smoke/run_song_check.sh` — NEW. Headless liveness + fidelity + cost, with `P_ABLATE`.
- `harness/smoke/run_song_wav.sh` — NEW. Records and trims the oracle's and the port's renditions.
- `harness/tools/wav_trim.py` — NEW. Cuts a session recording to the part that makes noise.
- `harness/smoke/run_song_slice.sh` — the audible runner now drives the A/B (`probe_mode 1`).
- `content/sound/princess_speaker_pairs.txt` — NEW (tracked). **The build's input was living in
  `build/tmp/`, which is gitignored** — a clean checkout could not have rebuilt the song.
- `build.bat` — two tables; the three measured constants in one home.
- `mame-idioms-coco3-port.md` — §39 `-wavwrite`, §40 the GIME `nnn+2`, both measured here.

Explicit-path staging only.

### 3 — Reasoning

#### 3A — the pulse (§1), and the claim that was worse than the code

P4.5's fix carried the width per segment but mapped it as `5×n` cycles. **The emitted pulse is
the loop plus whatever closes it**, and the tap measured that constant at **12.00 cycles**, with
zero variance across all four widths — so every pulse ran ~6.6 µs wide, and the quietest one had
a *floor* of 9.5 µs against a 7.83 µs target that no table entry could reach. The handler now
counts in B, which leaves B=0 at loop exit so the close is `stb DAC`, and hoists the width load
above the open: **overhead 5.00 cycles, measured.** Emitted against the oracle's four widths:

| oracle | emitted | error | segments |
|---|---|---|---|
| 22.51 µs | 22.35 | −0.7% | 3,252 |
| 7.83 µs | 8.38 | +7.0% | 370 |
| 17.60 µs | 16.76 | −4.8% | 238 |
| 12.70 µs | 13.97 | +10.0% | 64 |

The dominant width — 83% of the song — is within 0.7%. **The residual is quantisation of a
5-cycle step, not a modelling error**, and it is stated in the generated file rather than implied.

**And the file's claim is fixed, not only the code.** The generated table's own header called the
second byte `dac_level` when it was a width; it now names `frac` as a dither numerator with an
explicit *"NOT a DAC level"*, and carries the dither state, both latencies, the achieved period
error (mean, **signed** and worst) and the emitted microseconds per width. *A generated file that
overstates its own fidelity is a comment describing an unenforced discipline, and it is worse than
one, because it looks like evidence.*

#### 3B — ★★★ THE DEFECT NOBODY WAS LOOKING FOR: the period is not `ticks × 63.695`

Measuring the emitted *period* was meant to be a by-product of measuring the emitted *pulse*.
It was the finding of the dispatch.

The tap's first cut attributed each interval to the tick value read at its **end**, and reported
`ticks 96 → 1.5 ms` — an off-by-one that reads as a broken clock rather than a broken index. The
handler restarts the timer *before* it opens the pulse, so the value in force at rise *k* governs
*k → k+1*. Fixed, the offsets fell into **two clean populations, and they split by mechanism**:

| path | offset | n | what it is |
|---|---|---|---|
| free-running (`SP_NODITHER` control) | **+127.80 µs = 2.01 ticks** | 3,602 | the GIME's `nnn+2`, **no handler code in the path** |
| rewrite, steady | +170.24 µs | 3,602 | the above + FIRQ entry and prologue (~76 cyc) |
| rewrite, run advance | +225.22 µs | 320 | the above + `load_run` (~98 cyc) |

`SockmasterGime.md:83` documents `nnn+2` (1986 part) / `nnn+1` (1987); **MAME implements +2, and
the ablation measures it with nothing else in the way.** The tick itself is nominal — 63.759 µs
from 18 adjacent tick values, +0.10% — so the whole error is offset, not scale.

**Unmodelled, that left the slice playing +7.17% long: about 1.2 semitones flat.** After
correction, **−0.49%** (table A) and **+0.23%** (table B).

★ **This is the §2H pattern again and it cost nothing to catch only because the output was
instrumented.** The first mechanism — "the handler's restart adds latency" — was real, was not
the whole mechanism, and was not even the *larger* part: two thirds of the offset is the chip. The
three checks: **(1) a second mechanism, yes** — `load_run`, 55 µs, on one segment in every run;
**(2) the calling routine carries the scope** — the offset depends on whether `sp_ptr` moved, not
on the pitch, and in this song the two merely correlate because the low notes happen to be the
singleton runs; **(3) prior reports** — P4.2, P4.4 and P4.5 all compute periods as `ticks × 63.695`
and none of them measured one. Authority tier: **trace** (the running machine, on the bus),
corroborated by **SockmasterGime.md**.

#### 3C — `HM1..HM29` (§2): already reproduced, and NOT free

**The envelope is in the measurement.** The captured 6.5 s contains exactly **four distinct pulse
widths** (22.51 ×3,252 / 7.83 ×370 / 17.60 ×238 / 12.70 ×64) and **0 of 321 period-runs contains
more than one width** — the amplitude is constant within a held note. Whichever `HM` patterns MSYS
was running are therefore already in the recorded widths, and reproducing the widths reproduces
them. Nothing to decode; `MUSIC.SET*` stays undecoded and stays unneeded.

**★ HARD-STOP 3 APPLIES: amplitude is not free, and P4.4's finding needs a boundary.** P4.4 said
amplitude costs one `sta` on a 6-bit DAC. That is true of amplitude as a **LEVEL**. The slice
renders amplitude as **pulse WIDTH**, because that is what produces the oracle's timbre, and width
is time — it cannot be free. Measured by ablation: **`SP_NOPULSE` costs 1,365 cyc/f against the
full 1,650, so the width costs 285 cyc/frame ≈ 0.95% of the VBL budget, ≈28 cycles per interrupt**
— which is exactly the assembled `5 × (mean 6.6 − 1)`. The finding is not that P4.4 was wrong; it
is that *"amplitude is free"* was a statement about a representation the slice does not use.

#### 3D — the cost gap (§2), attributed by ablation, not tuned

+1,650 cyc/frame = **5.5%** at a **measured** 10.12 interrupts/frame → **163 cycles per interrupt**.

| build | cyc/frame | Δ | what that piece is |
|---|---|---|---|
| full | 1,650 | — | 163 cyc/interrupt |
| `SP_NOPULSE` | 1,365 | **−285** | the pulse width = the amplitude (28/int) |
| `SP_NODITHER` | 1,371 | **−279** | the per-interrupt timer rewrite + accumulator (31/int) |
| `SP_NOCOUNT` | 1,533 | **−117** | `probe_firqs`, harness-only (12/int) |
| residual | ≈930 | | FIRQ entry, the `$FFF6→$FEF4→$010F` chain, `pshs`/`puls`, the ack, the run countdown, the minimum pulse, `rti` — ≈92/int |

**Against P4.2's 51 cycles per interrupt**: that experiment toggled a DAC. It had no width, no
dither, no counter and no table to walk. *Counted ≠ assembled ≠ executed* — and here the executed
number is fully explained by what the executed handler does, with no residual to hand-wave.

★ **AND PART OF P4.5's LOWER FIGURE WAS THE BUG.** P4.5 measured 9.38 interrupts/frame; the
corrected build runs 10.12. **A song playing 7.2% slow costs 7.2% less per frame.** The cost did
not rise only because the player got heavier — it rose because the player got *right*.

Nothing was tuned toward the estimate. Levers named and left: the counter (117 cyc/f, comes out
when the slice stops being an instrument), the dither (279 cyc/f, **gated on Jay's ear** — if A
and B sound alike it comes out), and direct-page addressing for the hot variables (≈8 cyc/int,
unmeasured, and it would need the HAL's DP assumption checked first).

#### 3E — the A/B (§3), and why the hybrid is dead

**One binary, two tables, one code path.** `probe_mode 1` plays A, 1.5 s, B, 1.5 s, looping — so
the comparison is back-to-back and repeatable rather than remembered. A carries `frac=0`
everywhere and is exactly the as-built quantisation; B carries the fractional tick. Same
instructions execute for both.

| | mean \|err\| | signed mean | worst |
|---|---|---|---|
| A | 0.924% | **−0.689%** | 1.201% |
| B | 0.005% | −0.003% | 0.008% |

★ **A's error is BIASED, which a "±0.9%" would hide.** 2,936 of 3,924 segments share a handful of
periods, and they all round the same way — so the song runs **0.69% sharp overall**, not merely
noisy. **B's price is jitter**: right on average, up to one whole tick different segment to
segment. That is the trade, and it is exactly the kind of thing only an ear can rule on.

**★★ THE TINS HYBRID IS NOT A ROUTE — it cannot reach the band it would be built for.** 74.8% of
this song is 600–800 Hz, i.e. periods of 1.25–1.67 ms, against TINS=1's ceiling of 1.144 ms. So
HARD-STOP 4's "pre-compensating is the cheaper route" is stronger than stated: **it is the only
route**, and this closes an option that has been open since P4.3.

**★ And one correction to the dispatch's framing, from the histogram.** The dispatch says the band
errs ±1.4–2%. Measured on the actual periods, the 600–800 Hz band errs **0.367% mean, 1.376%
worst**; the 2.068% figure belongs to 943 Hz, which is 5.8% of the song. The detune does land on
three-quarters of the music — that part is right — but it lands there at about a sixth of the
quoted size. **Both the dispatch's number and mine were about the wrong quantity next to §3B's
7.17%.**

#### 3F — the oracle's rendition (§3), kept apart from the A/B

`build/tmp/oracle_princess_trim.wav` (27.8 s from 39.7 s) and `build/tmp/port_princess_trim.wav`
(23.1 s: A, gap, B, gap, loop). `-wavwrite` records from frame 0, so both are auto-trimmed against
each file's **own** idle level (0 on the Apple, −8192 on the CoCo3). **`-sound none` is not passed**
— it yields a valid, correctly-sized, silent file.

*port-vs-port isolates the detune. port-vs-oracle conflates it with every difference between a
6-bit DAC and a one-bit speaker, and this report claims nothing about which is which.*

#### 3G — the launch path (§4)

Unchanged from P4.5's fix: the frame notifier, `LOADM` at frame 300, `EXEC` 900 frames later.
It now serves **four** uses from one script — Jay's audible run, the headless liveness check, the
cost split, and the fidelity tap — so what is measured and what is demonstrated cannot drift.

### 4 — Verification (AC-by-AC)

- **AC1 pulse width per segment from the measurement; the data file corrected** — PASS. Overhead
  measured at 12.00 cyc, handler rewritten, re-measured at 5.00. Emitted widths 8.38/13.97/16.76/
  22.35 µs against 7.83/12.70/17.60/22.51, zero variance within each. Header rewritten (§3A).
- **AC2 `HM1..HM29` reproduced; is amplitude free** — PASS, and **the answer is no**. Four widths,
  none varying within a held note, already in the data. Width costs 285 cyc/f = 0.95% (§3C).
  **HARD-STOP 3 raised and reported.**
- **AC3 the cost gap attributed, not tuned** — PASS. Four builds, four measured deltas, residual
  ≈92 cyc/int matching the entry path. Nothing tuned (§3D).
- **AC4 cost re-reported after the fix** — PASS. **+1,650 cyc/frame = 5.5%**, at 10.12 interrupts/
  frame, up from 4.3% partly because the corrected song runs 7.2% faster (§3D).
- **AC5 A/B built, everything else identical** — PASS. One binary, two tables, one code path (§3E).
- **AC6 the oracle's rendition as WAV** — PASS (§3F).
- **AC7 the proven Lua launch path** — PASS (§3G).
- **AC8 Jay gates by ear, two questions kept apart** — **PENDING JAY.** Not self-certified.
- **AC9 suites green 128 KB; no instrument on the shipping disk; Karateka and `main` untouched** —
  PASS. `introseq` PASS, `integ` PASS at `-ramsize 128K`; `hal-sync OK`; `build/probe.dmk` still
  6 files / 36,673 B / 13,824 B free; `SONG.BIN` goes on a run-time copy.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim):**

```
=== BUILD COMPLETE ===
[pack_song] song_a: 3924 segments -> 321 runs (1607 B) -> build/gen/song_a.s
[pack_song]   dither off; latency 170.24 us; pulse overhead 5.0 cyc
[pack_song]   period error mean |0.924%| signed -0.689% worst 1.201%; 6506.7 ms
[pack_song]   widths -> 2=8.4us, 4=14.0us, 5=16.8us, 7=22.3us
[pack_song] song_b: 3924 segments -> 321 runs (1607 B) -> build/gen/song_b.s
[pack_song]   dither on; latency 170.24 us; pulse overhead 5.0 cyc
[pack_song]   period error mean |0.005%| signed -0.003% worst 0.008%; 6506.7 ms
  build/song_probe.bin (4727 bytes)
```

```
[suites] running: introseq integ
[suites] -ramsize 128K
[suites] === introseq ===
[run_introseq_test] PASS
[suites] === integ ===
[integ] PASS
[suites] ALL PASS
```

```
# PASS — it loaded, played to the terminator and tore the FIRQ down.
# ★ FIRQ RATE, MEASURED: 10.12 interrupts/frame over 387 frames
#   playing   4017.0 spins/f ->   1740 cyc/f   (388 frames)
#   torn down 4252.7 spins/f ->     90 cyc/f   (152 frames)
#   THE PLAYER COSTS +1650 cyc/frame = 5.5% of the VBL budget
#   -> 163 cycles per interrupt, at 10.12 interrupts/frame
#     width 2   ->   8.38 us  (8.38..8.38, n=369)  overhead 5.0 cyc
#     width 4   ->  13.97 us  (13.97..13.97, n=66)  overhead 5.0 cyc
#     width 5   ->  16.76 us  (16.76..16.76, n=238)  overhead 5.0 cyc
#     width 7   ->  22.35 us  (22.35..22.35, n=3252)  overhead 5.0 cyc
#   TICK LENGTH from 18 adjacent pairs: 63.759 us  (nominal 63.695, +0.10%)
#     steady  n=3604  mean +171.27 us  = 307 cyc, 2.69 ticks
#     adv     n=320   mean +225.41 us  = 403 cyc, 3.54 ticks
#   ★★ TOTAL EMITTED DURATION 6474.7 ms vs 6506.7 ms measured off the oracle
#      = -0.49%.
```

```
########## nodither ##########   THE PLAYER COSTS +1371 cyc/frame = 4.6%   (132 cyc/int)
    steady  n=3602  mean +127.80 us  (121.2..137.5)  = 229 cyc, 2.01 ticks   <- the GIME's nnn+2
########## nocount  ##########   THE PLAYER COSTS +1533 cyc/frame = 5.1%
########## nopulse  ##########   THE PLAYER COSTS +1365 cyc/frame = 4.6%   (135 cyc/int)
########## table B  ##########   TOTAL EMITTED DURATION 6521.5 ms vs 6506.7 ms  (+0.23%)
```

```
[song_wav] ORACLE (Apple II speaker) -> build/tmp/oracle_princess.wav  (32812 KB)
[wav_trim] oracle_princess.wav: 70.0s -> 27.8s (39.7..67.5s), 5ch 48000 Hz
[song_wav] PORT (CoCo3 DAC) — table A, 1.5 s gap, table B -> build/tmp/port_princess.wav
[wav_trim] port_princess.wav: 45.0s -> 23.1s (20.9..43.9s), 3ch 48000 Hz
```

**25.2 bundled-artifact grep:** N/A — harness instrument, not written to the shipping disk.
`build/probe.dmk`: 6 File(s), 36,673 bytes, 13,824 bytes free — unchanged from P4.5.

**25.3 operator-runtime-smoke:** **PENDING JAY** — `bash harness/smoke/run_song_slice.sh`
(live-disk, RGB, 128 KB, sound on, throttled). Two questions, kept apart:
1. **The detune, A vs B**, back to back on a loop, same code path.
2. **The timbre, port vs oracle**, from the two trimmed WAVs.

### 6 — Reactive deviations and route accounting

**Deviations:** three, all reported rather than absorbed.
1. **The pulse-width fix was already in `2bc8a0a`**, not outstanding as the dispatch assumed —
   what remained was that it was *mapped wrong* and that the file's claim was stale. Both done.
2. **The GIME `nnn+2` / latency finding was not in scope** and is much larger than the scoped
   defect. Fixing it was necessary for AC5 to mean anything (§3B).
3. **The build's input was untracked** (`build/tmp/speaker_pairs.txt`, gitignored). Promoted to
   `content/sound/`. Not asked for; a clean checkout could not rebuild the song without it.

**ROUTE ACCOUNTING.** I proposed nothing in conversation before this dispatch. Within it, what I
said I would build and did: the per-segment pulse mapping, the corrected data-file claims, the
four ablation builds, the A/B as one binary with two tables, both WAVs. **What I did NOT build,
having considered it:** a `TINS` hybrid of any kind (§3E — it cannot reach the band); a decode of
`MUSIC.SET*` (still not needed); any change to `main`; any tuning of the cost toward the estimate.
**And one thing I changed course on mid-task:** I first intended to fit tick-length *and* latency
together, and abandoned that fit — it was destroyed by two garbage samples and, once the
adjacent-tick check confirmed the clock was nominal, it was answering a question that did not
exist. The offset-by-mechanism split replaced it.

### 7 — Uncertainty flags

- **The `nnn+2` is MAME's.** `SockmasterGime.md` says the 1987 GIME does `nnn+1`, i.e. 63.7 µs less.
  **The constants are tuned to what MAME emits**, which is what Jay hears — but a real 1987 CoCo3
  would run this song ~64 µs/segment fast (≈4% sharp at 700 Hz). The three constants sit in one
  home in `build.bat`; **on real hardware they must be re-measured, not adjusted by argument.**
- **Table B is +0.23%, not 0.00%** as the packer predicts. The per-row *average* latency is an
  approximation (one segment per run takes the longer path). Small, and stated rather than smoothed.
- **The +7.0% and +10.0% pulse-width errors** at the two quietest levels are a 5-cycle quantum. A
  finer step would need a different pulse shape, and whether it matters is an ear question.
- **AC4 of P4.5 is still unanswered.** This renders a 6.5 s *capture window*, not a song against its
  beat. **Tail silence is still Jay's open item and this dispatch did not measure the delta.**
- **`SP_NODITHER`'s latency differs from the dither build's** (+195.8 vs +225.2 on the advance path)
  because `load_run` itself writes the timer there. Consistent; noted so it is not read as drift.

### 8 — Follow-up candidates

- **If A and B sound alike:** drop the dither, take back 279 cyc/f, and `SP_NODITHER` becomes the
  shipping build — but its latency constants differ and must be re-packed, not reused.
- Re-measure the three constants on a real CoCo3 before shipping audio.
- The remaining cost levers: the debug counter (117 cyc/f) and direct-page addressing (≈8 cyc/int).
- Still open and untouched: `MUSIC.SET*` → `loadmusic1/2/3`; the other four songs; tail silence;
  a song against its beat rather than a capture window; `Demo` unbuilt.

### 9 — User interaction during task

None. The dispatch was executed end to end.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-18-instrument-the-output-not-the-pipeline.md`

### 11 — Commit

See below — pushed to origin/wip before this report.
