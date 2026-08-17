## Form B Report — P4.4 — the speaker, measured

**Class:** recon (measurement). wip. **Nothing built. No `src/`, `content/`, `link/` or
`build.bat` change. No instrument on any disk — the oracle harness runs from a copy.**

**★★★ THE RATES THE MUSIC ACTUALLY USES: 101 Hz to 943 Hz, mean 603 Hz.** Measured from 7,850
`$C030` toggles on the running oracle. **And P4.3's pulse/rest structure is confirmed by
observation, not argument: 3,138 short intervals on odd positions and ZERO on even — perfect
alternation.**

**★★★ THE FLOOR, DERIVED FROM THOSE NUMBERS RATHER THAN INHERITED: at TINS=1 the GIME timer
bottoms out at 874 Hz and the music goes to 101 Hz — over the 4095 ceiling by 8.6×. TINS=0
reaches the whole range, at the cost of 2.0% error at the top. That is the real constraint, and
it is a different number from the 468 Hz that was carried into two dispatches.**

**★★ AND IT FITS: peak demand is 943 interrupts/s, which is P4.2's already-measured phase 1 —
`+808 cycles/frame, 3.6% of the VBL budget`. No extrapolation.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-16T23:51:40-04:00 (HEAD `40885a6`, wip). `git status` clean but for this report.
Karateka untouched. `main` untouched. **Oracle source read-only** — `run_oracle_trace.sh` copies
the `.hdv` to `build/` before the emulator opens it.

---

### 1 — Summary

| | |
|---|---|
| **★★★ rates USED** | **101 Hz … 943 Hz**, mean 603 Hz — the reached set, from one run |
| **★★★ structure confirmed** | 3,138 short on odd, **0 on even** — pulse/rest, exactly as P4.3 read it |
| **★★ pulse widths** | **7.8 … 22.5 µs**, mean 20.2 — 0.7–2.1% duty inside a segment |
| **★★★ the real floor** | **TINS=1 bottoms at 874 Hz**; the music needs 101 Hz. **TINS=0 or nothing** |
| **★★ the cost** | **943/s × ~55 cyc = 866 cyc/frame = 2.9%** — and P4.2 measured that point at **+808** |
| **★★ amplitude** | **free** — a DAC write is one `sta`. `HM1..HM29` cost **nothing extra** |
| **★ monophony** | **one FIRQ stream.** Bound, stated |
| **★ the trade** | TINS=0 costs **−2.02%** at the top of the range (≈⅓ semitone flat) |

### 2 — Files modified

- `harness/tools/oracle_speaker_intervals.lua` — NEW; the interval tracer
- `reports/20260816-235140-…md` — this

### 3 — Reasoning

**3A — ★★ THE TAP FIRES, AND THAT WAS NOT ASSUMED (AC1).**

Every previous oracle tool in this project uses **write** taps, because on the 6502 a read-tap on
a **code** address silently false-0s through the opcode-fetch bypass. `$C030` is a soft switch
read as **data** by `LDA`, so the bypass does not apply — **but that is an argument, and a tap
that never fires reads exactly like a machine making no sound.** So the tool reports the count
first and fails loudly on zero:

```
# ★ TOGGLES OBSERVED: 7850 (7849 intervals kept, cap 60000)
```

**3B — ★★★ THE STRUCTURE, OBSERVED (AC1).**

```
# RAW — the first 40 intervals, in microseconds, in order.
    7.8  2658.1  7.8  2658.1  7.8  2658.1  7.8  2658.1  7.8  2658.1
    7.8  2658.1  7.8  2658.1  7.8  2658.1  7.8  2658.1  7.8  2658.1
    7.8  2658.1  7.8  2658.1  7.8  7518.1  17.6  2648.3  17.6  2648.3
    17.6  2648.3  17.6  2648.3  17.6  2648.3  17.6  2648.3  17.6  2648.3

# ALTERNATION CHECK — median 22.5 us. Of the 7849 intervals,
#   3138 below-median fall on ODD positions and 0 on EVEN.
#   ★ STRONGLY ALTERNATING
```

★★★ **Zero on even is as clean as this gets.** The prediction was written into the tool *before
the run* — *"if they do not alternate, P4.3's reading is wrong and that is the finding"* — and the
data could have contradicted it. **It did not: pulse, then rest, then pulse.**

★ **And you can watch a note change in the raw line:** twelve segments of `7.8 / 2658.1`, then one
long `7518.1` rest, then `17.6 / 2648.3` — the pulse width steps 7.8 → 17.6 µs (the amplitude
changing) while the segment period stays ~2,656 µs (the pitch holding). **That is the compensator
doing exactly what P4.3 said it was for**, visible in eight numbers.

**3C — ★★★ THE RANGE ACTUALLY USED (AC2).**

```
#   short (the PULSE):   n=3138   min 7.8    max 22.5    mean 20.2 us
#   long  (the REST):    n=4711   min 22.5   max 9860.1  mean 1367.7 us
# ★★★ THE SEGMENT PERIOD — pulse + rest, which is what the NOTE sets.
#   n=3924   min 1060.9 us   max 9882.6 us   mean 1658.2 us
#   => RATE RANGE ACTUALLY USED: 101 Hz .. 943 Hz (mean 603 Hz)

# SEGMENT PERIOD HISTOGRAM
#      800..1600 us  3163   (625..1250 Hz)
#     1600..3200 us   601   (312..625 Hz)
#     3200..6400 us   111   (156..312 Hz)
#    6400..12800 us    49   (78..156 Hz)
```

★★ **Reached, not expressible** — the histogram shows the mass sitting at 625–1250 Hz with a thin
tail down to 78–156 Hz. **The low notes are rare and they are real**, which is precisely the
distinction AC2 asks for: a table entry no song touches is not a constraint, and these are
touched.

**3D — ★★★ THE FLOOR, DERIVED (AC6) — AND IT IS NOT 468 Hz.**

The 468 Hz figure was computed for a **tone generator** toggling at the note's frequency. For a
PWM engine the port's interrupt fires once per **segment**, so the floor is about segment rates:

```
  TINS=1 (279.365 ns):  max period    1,144.0 us  ->  LOWEST rate  874.1 Hz
  TINS=0 (63.695 us):   max period  260,831.0 us  ->  LOWEST rate    3.8 Hz

   101.2 Hz (music LOWEST ) TINS=1: needs 35,371 ticks -- OVER the 4095 ceiling
   101.2 Hz (music LOWEST ) TINS=0:    155 ticks ->  101.3 Hz  (+0.09%)
   942.6 Hz (music HIGHEST) TINS=1:  3,798 ticks ->  942.5 Hz  (-0.01%)
   942.6 Hz (music HIGHEST) TINS=0:     17 ticks ->  923.5 Hz  (-2.02%)
```

★★★ **So there IS a floor problem and it is worse than the one that was carried: TINS=1 cannot
reach the music's low notes at all — 8.6× past the ceiling — not merely 468 Hz-ish.** And **TINS=0
reaches the entire range**, at the cost of **−2.02% at the top**, which is about a third of a
semitone flat on the highest notes.

★ **A third option exists and I am not choosing it:** stay on TINS=1 and divide in software — one
fast interrupt with a countdown in the handler. It restores precision at the top and costs more
interrupts. **Costing it is a design step; §3 says do not build, and the trade is audible, which
makes it Jay's.**

**3E — ★★★ WHAT THE PORT MUST DO, IN THE TARGET'S TERMS (AC3).**

**Peak demand is 943 interrupts per second.** At P4.2's measured ~55 cycles per interrupt:

```
  943/s x ~55 cyc = 51,865 cyc/s = 866 cyc/frame = 2.9% of the 29,859-cycle VBL budget
```

★★ **And this needs no extrapolation at all: P4.2's phase 1 ran the timer at 936 Hz and measured
`+808 cycles/frame, 3.6%`.** The music's peak is 943 Hz. **The operating point P4.3 said was
unpriced turns out to be the point P4.2 already measured** — the cost envelope was right and only
the reasoning attached to it was wrong.

★ **Mean demand is lower still**: 603 Hz ⇒ ~554 cyc/frame ⇒ **1.9%**.

**3F — ★★ AMPLITUDE IS FREE, CONFIRMED (AC4).**

The Apple spends its whole architecture — the compensator, the four ratios, 29 patterns — on
making a one-bit speaker produce **volume**, and the measurement shows the result: pulses of
**7.8–22.5 µs inside segments of 1,061–9,883 µs**, a duty cycle of 0.7–2.1%.

★★★ **On the CoCo3 that entire mechanism collapses into the value written to `$FF20`.** The FIRQ
handler already stores a byte to set the level; **choosing WHICH level costs a table lookup inside
an interrupt that has to happen anyway.** So `HM1..HM29` are reproducible **at no additional
interrupt cost** — the pattern index advances per segment, in the same handler.

★ **Confirmed, with the caveat that matters:** free in *interrupt rate*, not free in *handler
cycles*. P4.2 measured ~55 cyc/interrupt for a handler that toggles a fixed value; a table walk
adds a few. **That is a small re-measurement, not a new question, and it is named in §7.**

**3G — MONOPHONY AS A BOUND (AC5).**

P4.3 established one pitch at a time from the arithmetic that loads `VTBL`. The measurement is
consistent — **a single alternating pulse/rest stream throughout, never two interleaved periods**.
★ **So: one FIRQ stream, one timer, one DAC level at a time.** The GIME has exactly one timer, and
that is now known to be enough.

**3H — §2H's THREE CHECKS.**

1. **A second mechanism for a different object class?** ★ Yes, and it is why §3D's answer is not
   one number: **the GIME timer has two clock sources**, and the floor is a different value under
   each. Reporting "the floor is 874 Hz" would have been the same error as "the floor is 468 Hz" —
   a real number for one configuration presented as a property.
2. **The calling routine.** The segment period is what the port's interrupt must reproduce, and it
   is `pulse + rest` — **neither interval alone**. A tool that measured only the toggle rate would
   have reported ~1,175 toggles/s and been double the truth.
3. **Grep the reports.** P4.2's `+808 cyc/f at 936 Hz` is quoted here **as the answer**, not
   re-derived — it is the measurement that already covers the music's peak.

### 4 — Verification (AC-by-AC)

- **AC1 — intervals captured for one named song, characterised as rates and widths.** §3A-3C.
  ★ **Naming the song precisely, and NOT over-claiming:** the window arms on PlayCut0's `SPEED 12`
  at f2681 and runs 400 frames (6.7 s). By PlayCut0's own order that covers **`s_Princess`
  (title set, id 7)** and may reach into `s_Squeek`. **I have not verified the boundary**, so this
  is "the opening of PlayCut0, principally `s_Princess`" rather than a clean single-song capture.
- **AC2 — the range actually USED.** §3C. **101 … 943 Hz**, with the histogram showing where the
  mass sits.
- **AC3 — the port's job in target terms, against the measured envelope.** §3E. **2.9% peak,
  1.9% mean**, and it lands on P4.2's already-measured phase 1.
- **AC4 — is amplitude genuinely free.** §3F. **Yes for interrupt rate; a few cycles for the
  handler.** Stated with the distinction.
- **AC5 — monophony as a bound.** §3G.
- **AC6 — a PWM floor derived from the measurements.** §3D. **874 Hz at TINS=1 (fails), 3.8 Hz at
  TINS=0 (works, −2.02% at the top).** Not inherited.
- **AC7 — nothing built; no instrument on a shipping disk.** Nothing was built. The oracle runner
  copies the `.hdv`; **no CoCo3 disk was touched.**
- **AC8 — route accounting; suites green 128 KB; Karateka; `main`.** §5, §6.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1** ★ **No build run and suites not re-run, deliberately** — no file outside `reports/` and
`harness/tools/` changed, and the new Lua is an oracle-side tool that touches no CoCo3 artifact.
A suite result would be evidence about a build this dispatch did not produce. **The standing
result is P4.2's:** `introseq` and `integ` PASS at 128 KB, with `probe cel compiled mode anim room
walk` retired. `[hal-sync] OK`.

**25.2** N/A — nothing built or bundled.

**25.3 operator-runtime-smoke: N/A — no port behaviour changed.** Standing gates unchanged
including the integrated sequence (*"look good. mint it."*).

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** Against §4's eight criteria: **AC1–AC8 in full.** **Nothing built, nothing
chosen** — §3D names three options for the clock and costs none of them, because the trade is
audible.

**Reactive deviations (§22.5):** none.

Oracle source read-only, copied before the run. Karateka untouched. `main` untouched.

### 7 — Uncertainty flags

- **★★ One run, one window, one song.** 101–943 Hz is `s_Princess`'s reached set, not the
  cutscene's. `s_Vizier`, `s_Buildup`, `s_Magic` and `s_StTimer` are unmeasured, and **a lower
  note in any of them moves the floor argument, not the cost argument** (TINS=0 has room to 3.8 Hz).
- **★★ The song boundary is not verified** (AC1). The window may include `s_Squeek`.
- **★ The handler cost for a table-walking version is unmeasured** (§3F) — P4.2's ~55 cyc was a
  fixed-value toggler. Small, and it only moves 2.9% slightly.
- **★ The −2.02% at 943 Hz is arithmetic on the measured rate**, not a listening test. Whether a
  third of a semitone matters on the top notes is an ear question.
- **★ The pulse widths span only 7.8–22.5 µs** — a narrow amplitude range. Whether that is the
  song or the player's limit is unexamined; it bears on how many DAC levels the port needs.
- Carried: the `MUSIC.SET*` mapping; no song decoded into notes; tail silence (Jay's); the FIRQ
  tear-down on abort; `Demo` unbuilt; gameplay's colour mode and the cel bank's survival.

### 8 — Follow-up candidates

1. **Measure the other four cutscene songs** the same way — cheap, and it turns "the reached set"
   from one song into the scene's.
2. **Decode one song from `MUSIC.SET*`** — still the outstanding fact (carried from P4.1), and now
   checkable **against** this measurement: a decoded note should predict a measured segment period.
   ★ That makes the decode self-verifying, which it was not before.
3. **Re-measure the handler cost with a table walk** (§3F).
4. **Put the clock choice to Jay** — TINS=0 with −2.02% at the top, or TINS=1 with a software
   divider. Both reach the range; they differ in precision and cycles.

### 9 — User interaction during task

None.

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-16-predict-the-structure-before-the-run.md`

### 11 — Commit

See below — pushed to origin/wip before this report.
