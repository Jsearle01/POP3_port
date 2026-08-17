## Form B Report — P4.3 — the player is PWM, not a square wave

**Class:** recon, bounded. wip. **Nothing built. No `src/`, `content/`, `link/` or `build.bat`
change. No instrument anywhere near the shipping disk.**

**★★★ HARD-STOP 2 FIRED, AND FOR A BETTER REASON THAN THE DISPATCH ANTICIPATED. The
period→frequency mapping CANNOT be derived by the obvious arithmetic, because `MSYS` is not a
square-wave generator. It is a one-bit PULSE-WIDTH MODULATOR: the note sets the SEGMENT RATE and
the amplitude sets the PULSE WIDTH inside it, and the loop is deliberately self-compensating so
that the amplitude does not affect the rate. Estimating a frequency from `NOTE` as if it were a
half-cycle count would be exactly the wrong number.**

**★★★ AND §2 IS ANSWERED, OPPOSITE TO THE HINT AND OPPOSITE TO MY OWN P4.1/P4.2 DESCRIPTIONS: it
is MONOPHONIC IN PITCH. `VTBL+1..+4` are not four voices — they are four AMPLITUDE levels derived
from one note (`amp/2`, `amp`, `1.5×amp`, `2×amp`), and `HM1..HM29` are per-song ENVELOPE patterns
selecting among them. One pitch at a time, shaped.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-16T23:30:47-04:00 (HEAD `115044a`, wip). `git status` clean but for this report.
Karateka untouched. `main` untouched. **Oracle source read-only and not executed** — this dispatch
ran no emulator.

---

### 1 — Summary

| | |
|---|---|
| **★★★ the mechanism** | **1-bit PWM**, not a square wave. Note → segment RATE; amplitude → pulse WIDTH |
| **★★★ voices (AC4)** | **ONE pitch at a time.** `VTBL+1..+4` are amplitude levels, not voices |
| **★★ `HM1..HM29`** | **envelope/timbre patterns**, 29 of them, selecting a level per segment |
| **★★★ AC1/AC2/AC3** | **cannot be answered as posed** — the floor question is malformed against a PWM engine. HARD-STOP 2 |
| **★★ the correction** | P4.1 and P4.2 both called it *"a bit-banged square wave"*. **Mine, twice, and wrong** |
| **★★ good news for the port** | the CoCo3's 6-bit DAC produces amplitude **directly** — MSYS's hardest trick is free on the target |
| **★ the route** | measure `$C030` intervals on the running oracle; the harness exists |

### 2 — Files modified

**None.** This report is the only new file.

### 3 — Reasoning

**3A — ★★★ WHAT THE LOOP ACTUALLY DOES.**

Read end to end [`MSYS.S:440-545`], the per-segment path is:

```
  LDA NOTE,X   / STA R+8          <- ★ THE PITCH
  LDA AMPTBL,X / STA R+11         <- ★ THE AMPLITUDE
  LDA ENVTBL,X / STA MVAR6+1      <- an ENVELOPE pointer, self-modified into MVAR6
NEWMM4
  LDA R+11 / STA VTBL+2           <- level 2 = amp
  LSR      / STA VTBL+1           <- level 1 = amp/2
  CLC / ADC R+11 / STA VTBL+3     <- level 3 = amp/2 + amp = 1.5x
  LDA R+11 / ASL / STA VTBL+4     <- level 4 = 2x
  INC VTBL+1..+4                  <- +1 each: the loop's own overhead compensation
MSEG
  LDY R+3 / LDA HM1,Y             <- the per-song pattern picks a LEVEL, 1..5
  LDA VTBL-1,Y / STA R+6          <- Y=1 -> VTBL+0 = $00 = SILENCE; Y=2..5 -> the four levels
  SEC / SBC R+8 / TAY
MADJLP INY / BNE MADJLP           <- 256-(level-R8) iterations   ★ THE COMPENSATOR
MLMDI  LDA R+8 / MDLOOP SBC #1 / BNE MDLOOP / DEY / BNE MLMDI   <- R8 iterations
  LDY R+6 / BEQ MFIZZLE           <- level 0 -> no toggle at all
M30A LDA $C030                    <- toggle
MVDIT DEY / BNE MVDIT             <- level iterations   ★ THE PULSE
M30B LDA $C030                    <- toggle back
MFIZZLE DEX / BNE MSEG
```

★★★ **`MADJLP` EXISTS TO CANCEL `MVDIT`.** Its iteration count is `256 − (level − R8)` and
`MVDIT`'s is `level`; their sum is `256 + R8`, **with `level` cancelling exactly**. So **the
segment duration is a function of `R+8` alone** — the note — **and is independent of the
amplitude.** That is not incidental; it is the entire reason the compensator is there.

**Therefore:** the speaker emits **one pulse per segment, of width = the selected level, at a rate
set by the note.** ★ That is pulse-width modulation on a one-bit output — the standard way to get
*volume* out of a speaker that has none — with a per-note envelope walking `ENVTBL` and a per-song
pattern (`HM*`) choosing among four fixed ratios of the current amplitude.

**3B — ★★★ WHY AC1-AC3 CANNOT BE ANSWERED AS POSED (HARD-STOP 2).**

The dispatch asks for the frequency of each of the 75 `NOTE` entries, compared against the 468 Hz
floor. That question assumes `NOTE` sets a half-cycle of a square wave — **which is what P4.1 and
P4.2 both said, and both were mine, and both were wrong.**

`NOTE` sets `R+8`, which appears **only** in the two delay loops that set the segment duration.
The naive formula `f = 1 / (2 × 5 × period × cycle_time)` is therefore not merely imprecise, it is
**measuring the wrong quantity** — it computes a pulse repetition rate from a value that does not
set one.

★★ **Deriving the true rate statically would need cycle-exact accounting of a 6502 loop that
contains self-modifying code** (`MVAR6 LDA $FFFF,Y` is patched from `ENVTBL/ENVTBH` per note), and
my own rough pass produced a range so narrow (~270-750 Hz across the whole 75-entry table) that it
is plainly wrong for a table spanning a melody. **I am not publishing that number.** HARD-STOP 2:
*"report what the loop does and what remains unknown; do not estimate a frequency."*

**What remains unknown, precisely:**
- the segment rate in Hz for each `NOTE` value;
- therefore whether any note falls below 468 Hz (**AC1, AC3 — unanswered**);
- therefore the lowest note the songs actually reach (**AC2 — unanswered**).

★ **AC2's distinction still stands and still matters** — *what is used is not what exists* — but it
cannot be applied to a table whose unit is not yet known.

**3C — ★★★ AC4: ONE PITCH AT A TIME, AND THE HINT WAS BACKWARDS.**

§2 suspected monophony from the absence of the words *voice*/*channel*, and warned that absence of
a word is not evidence. ★ **It was right to warn, and the conclusion happens to hold — but not for
the reason offered, and the intermediate evidence pointed the other way.**

`VTBL HEX 0001020304` is five bytes; `VTBL-1,Y` for `Y` in 1..5 reaches `VTBL+0..+4`; the harmony
tables use exactly 1..5. **That looks like five voices and is not.** `VTBL+1..+4` are loaded in one
block from a single `R+11` as `amp/2, amp, 1.5×amp, 2×amp`, and `VTBL+0` stays `$00` — which
`LDY R+6 / BEQ MFIZZLE` turns into **silence**.

★★ **So `HM1 DFB 1,3,128` is not "voices 1 and 3" — it is silence, then level 2 (`amp`), repeating.
A 50% duty cycle. And `HM13 DFB 5,2,3,2,4,2,3,2,128` walks 2×, ½×, 1×, ½×, 1.5×, ½×, 1×, ½× — an
amplitude wobble, i.e. a timbre.** Twenty-nine such patterns are the player's whole tonal palette.

**The one-bit speaker therefore carries exactly one pitch**, and §2's *"if it is one voice, that is
a large simplification and it should be stated as one"* applies: **the port needs one tone
generator.** ★ **And Jonassen's multi-voice work is interesting but not required by the mandate**,
exactly as the dispatch predicted for this branch.

**3D — ★★ WHAT THIS MEANS FOR THE TARGET, STATED BECAUSE IT IS GOOD NEWS AND EASY TO MISS.**

MSYS spends its entire architecture — the compensator, the four ratios, the 29 patterns — on
getting **amplitude** out of a one-bit output. ★★★ **The CoCo3 has a 6-bit DAC. Amplitude is a
value you write.** The hardest thing the oracle's player does is free on the target.

★ That does **not** collapse the design: the port still needs the right *rate*, the envelope walk,
and the `HM*` patterns if the timbre is to match. **But it means the port's player is plausibly
simpler than the oracle's, not harder** — and it means P4.2's FIRQ cost model needs revisiting,
because *"one interrupt per half-cycle"* was priced against a square wave that does not exist.
**Named, not re-priced — that is a measurement, not an inference.**

**3E — §2H's THREE CHECKS.**

1. **A second mechanism for a different object class?** ★★★ **Yes, and it is the finding.** I read
   `M30A/M30B` as "two toggles = one square-wave cycle" at P4.1 and repeated it at P4.2. The
   *second* mechanism is `MADJLP`, forty lines away, whose only job is to make the first one's
   duration not matter. **Reading the toggle without its compensator is what produced two
   dispatches of wrong description.**
2. **The calling routine.** `NOTE` is not consumed where it is stored — it is consumed in
   `MADJLP`/`MDLOOP`, which are the segment timer. Reading `NOTE`'s table alone says nothing about
   what its values mean.
3. **Grep the reports.** P4.1 §3D: *"two toggles bracketing a delay = one square-wave cycle."*
   P4.2 §3C: *"a one-bit speaker toggled by CPU timing, so the entire audio signal is described by
   frequency and duration."* ★ **Both mine, both wrong on the same point** — the signal also
   carries amplitude, which is the whole of what the pulse width encodes. **Corrected here rather
   than left to be cited.**

### 4 — Verification (AC-by-AC)

- **AC1 — period→frequency derived, 75 entries against the floor.** ★ **NOT ANSWERED — HARD-STOP
  2.** §3B gives what the loop does and why the naive derivation measures the wrong quantity.
- **AC2 — the lowest note the songs USE.** ★ **NOT ANSWERED**, and cannot be until AC1 is.
- **AC3 — sub-floor notes quantified.** ★ **NOT ANSWERED.** ★★ **And the floor question itself is
  malformed against a PWM engine** — the port's interrupt rate is a design variable, not a
  transcription of `NOTE`.
- **AC4 — the voice count established from the player.** ★ **ANSWERED: one pitch at a time**, with
  four amplitude levels and 29 envelope patterns. §3C. **Established from the arithmetic that
  loads `VTBL`, not from vocabulary.**
- **AC5 — nothing built; no instrument on the shipping disk.** **Nothing was built at all.**
- **AC6 — suites green, 128 KB first.** §5.
- **AC7 — route accounting; Karateka; `main`.** §6.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1** ★ **No build was run and the suites were not re-run, deliberately.** No file outside
`reports/` changed, so a suite result would be evidence about a build this dispatch did not
produce — the same reasoning as P3.105, and a green tick that means nothing is worse than no tick.
**The standing result is P4.2's:** `introseq` and `integ` PASS at 128 KB (`-ramsize 128K`), with
`probe cel compiled mode anim room walk` retired and what went with `room`/`walk` named in
`retired.sh`. `[hal-sync] OK`.

**25.2** N/A — nothing built or bundled.

**25.3 operator-runtime-smoke: N/A — no port behaviour changed.** Standing gates unchanged: the
flash, glass, sand, slump, the feet, the exit walk, and the integrated sequence (*"look good. mint
it."*) all PASSED.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** Against §4's seven criteria: **AC4, AC5, AC6, AC7 in full; AC1, AC2, AC3 NOT
ANSWERED** — stopped by HARD-STOP 2, on a premise failure rather than a difficulty.

★★ **Stating the shape honestly: the dispatch asked a well-formed question about a square-wave
player, and the player is not one.** The bounded read it asked for is what established that, so the
dispatch did its job; what it did not do is produce the three numbers, and no amount of further
reading of `NOTE` would have.

**Reactive deviations (§22.5):** none. Nothing was modified.

**★ A correction to my own two previous reports**, recorded rather than quietly superseded: P4.1
§3D and P4.2 §3C both describe the oracle's audio as a bit-banged square wave fully described by
frequency and duration. **It is a PWM engine and the signal carries amplitude too.** Neither report
is edited; this one supersedes both on that point, and §3E.3 quotes them so the next reader does
not inherit the wrong description by recency.

Oracle read-only and never executed. Karateka untouched. `main` untouched.

### 7 — Uncertainty flags

- **★★★ The segment rate in Hz is unknown**, so the 468 Hz floor is unchecked and AC1-AC3 stand
  open. §8.1 names the route.
- **★★ P4.2's FIRQ cost model was priced against a square wave.** The measured
  `+808/+1,923/+4,013` cycles per frame remain correct **for the rates measured** — that was a real
  measurement of real interrupts — but *which* rate the port needs is now an open question rather
  than "one interrupt per half-cycle of `NOTE`". **The cost curve survives; the operating point
  does not.**
- **★ I have not read `AMPTBL`, `ENVTBL`/`ENVTBH`, or `HARMTBL`'s indexing.** The envelope walk is
  established to exist (`MVAR6` is self-modified from `ENVTBL`) and is otherwise unread.
- **★ The `M20x` block [`MSYS.S:750`] is a second copy of this loop** and I have not established
  what distinguishes it from `M30x`. P4.1 flagged it; it is still open, and it is **not** shown to
  be a second voice.
- **★ `VTBL+0` is `$00` and never written**, so level 1 is silence — read from the initialiser and
  the `BEQ MFIZZLE`, not from a comment saying so.
- Carried: the `MUSIC.SET*` → `loadmusic1/2/3` mapping; no song decoded; tail silence (Jay's); the
  FIRQ tear-down on abort; `Demo` unbuilt; the cel bank does not survive the 16-colour mode.

### 8 — Follow-up candidates

1. **★★★ MEASURE the segment rate on the running oracle.** Tap `$C030` writes during a known song
   and take the intervals directly — the harness exists (`run_oracle_trace.sh`,
   `oracle_*_rate.lua`), it is this project's own standing invariant (*measure, don't model*), and
   it answers AC1-AC3 without any cycle-exact accounting. **This is the next dispatch and it is
   small.**
2. **Read `AMPTBL`/`ENVTBL`** to characterise the envelope, once the rate is known.
3. **Re-price the FIRQ operating point** against the measured rate (§7.2).
4. **Decode one song** — still the fact everything about note data rests on (carried from P4.1).

### 9 — User interaction during task

One: *"that was my fault. continue with what you were doing"* — after an interrupted dispatch
delivery. No scope change.

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-16-a-constraint-found-while-measuring-something-else.md`

### 11 — Commit

`1616ea1`  (pushed to origin/wip before this report)
