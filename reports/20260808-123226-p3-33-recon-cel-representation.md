## Form B Report — P3.33 RECON — the cel representation: pre-shifted has hit its ceiling
**Class:** recon. wip. No `src/` change; measurement scratch outside the repo.

### 0 — Receipt / status (C-35 stamp)
t0=2026-08-08T16:29:38Z (HEAD `d769bff`, wip). `git status --porcelain` showed **0** tracked modifications at
t0. Untracked = `.vscode/`, `nvram/`, `docs/ground-truth/*.pdf` (never committed, Jay's standing rule),
`POP-idioms-coco3-markers.md`, `content/intro/broderbund_splash_render.bin`, `content/cutscene/*`.
No prod binary touched.

---

### 1 — Summary

**Pre-shifted is over by 8,658 bytes at the cutscene's real requirement** — not by the 1,937 that `Vstop`
showed. The dispatch's read is confirmed: this is the representation, not the window.

**Raw bitmap + a runtime shifter is the only candidate that clears the window with margin** — 10,454 B
against 14,848, **4,394 spare** — and it does so by storing 12 distinct cels instead of 24 pre-shifted
variants.

**One measurement correction, and it matters.** My first pass compared all three candidates at *24 items*.
That is wrong: 24 is the count of **variants**, which only the pre-shifted scheme stores. The others store
**distinct cels** (12) and produce the variants by shifting. Comparing them at 24 charged them for work they
do not do and made both look hopeless. Corrected below.

**No representation reaches the full game inside this window** — HARD-STOP #3, stated as a measured result.
Even raw bitmaps are 24.1 KB per level against a 14.8 KB window. **The cutscene decision and the gameplay
decision are different decisions**, and nothing here should be read as settling the second.

**The time side is NOT measured, deliberately.** A runtime shifter cannot be costed honestly without building
one, and modelling has lost twice in this project. §3C gives the one bound instruction-counting supports and
costs the build instead.

---

### 2 — Files modified
- `reports/20260808-123226-p3-33-recon-cel-representation.md` — this report (only tracked change).

Measurement scratch, outside the repo: `…/scratchpad/p333/space.py`.

---

### 3 — Reasoning

#### 3A — What each representation actually costs, measured from the real cels

Measured on the six baked `Vwalk` cels, from the emitted `.s` files rather than re-derived, so the numbers are
what the assembler places:

| representation | total | per item | vs raw |
|---|---|---|---|
| pre-shifted, 2 phases | 8,850 B | **738 B/variant** | 4.48× |
| one-phase baked | 4,335 B | **722 B/cel** | 2.20× |
| raw bitmap | 1,974 B | **329 B/cel** | 1.00× |

Two things fall out that were not obvious:

**The segment stream costs 2.20× the bitmap it encodes.** `SEG_SKIP`/`SEG_BLAST`/`SEG_MERGE` headers plus the
per-byte `(mask,src)` pairs in merge runs more than double the data. That overhead is paid *per stored
variant*, so it compounds with the phase multiplier rather than being amortised by it.

**The phase multiplier here is 2.04×, not P3.18's 1.20×.** No contradiction: P3.18 measured **1.16 phases per
cel across the whole cutscene set**, where most cels are static and occupy one. The walk is the exception —
every walk cel occupies exactly two. **The average is right for the library and wrong for the content that
actually moves**, which is precisely the content a walk cycle is made of.

#### 3B — The cutscene, at the requirement that matters

24 variants (P3.32 §3E — two approach/stop pairs) from **12 distinct cels**, against the 14,848 B window:

| representation | stores | cel bytes | code | bundle | verdict |
|---|---|---|---|---|---|
| pre-shifted (today) | 24 variants | 17,700 | — | 23,506 | **OVER by 8,658** |
| one-phase + shifter | 12 cels | 8,670 | ~400 | 14,876 | **OVER by 28** |
| **raw bitmap + shifter** | 12 cels | 3,948 | ~700 | **10,454** | **FITS, 4,394 spare** |

**The one-phase row's verdict is not trustworthy and I will not present it as one.** It misses by 28 bytes
against a shifter code size I *estimated* at 400 — the only modelled number in the space table. A verdict
inside its own error bar is undetermined, not "nearly fits". It would take a build to resolve, and §3C says
what that costs.

**Raw bitmap's margin is large enough to survive an estimate being wrong**, which is the practical difference
between the two: 4,394 spare absorbs a shifter twice the size I guessed.

#### 3C — Time: what I did not measure, and why

**Measured, from P3.19, using the same method so the numbers are comparable:** opaque stack-blast **4.5
cy/byte** on real 4-9 byte rows, merge **22 cy/byte** (a 6809 floor — no 16-bit AND/OR against memory), and
the heaviest frame **19,579 cy against 29,673 available = 66%**.

**Not measured: any runtime shifter.** HARD-STOP #2 and the standing invariant both apply — modelling has lost
twice here (P3.21 by 2.2×, P3.22's 92%-of-budget prediction against a measured 10.0 Hz). I am not going to
produce a cy/byte figure for a routine that does not exist.

What instruction-counting *does* support is a **lower bound** on a table-driven shift, counting a concrete
sequence the way P3.19 counted its merge:

```
  lda ,x+                    6
  ldb a,y   (SHR table)      5
  orb <carry                 4
  stb ,u+                    6
                            21 cy/byte — and carry maintenance is extra
```

**21 cy/byte is a floor, not an estimate of the real thing.** Note what it means structurally: a shift pass is
a **separate pass** over the row — it does not replace the blast or the merge, it precedes them. So it *adds*
to the existing draw cost:

| bytes shifted per frame | added | frame total | % of 29,673 |
|---|---|---|---|
| 300 | 6,300 | 25,879 | 87% |
| 450 | 9,450 | 29,029 | **98%** |
| 600 | 12,600 | 32,179 | **108% — over** |

**So the time question is genuinely open and genuinely tight**, and it is the one that decides this. At the
heaviest frame's current footprint the shifted path lands between 87% and over-budget depending on how many
bytes actually pass through the shifter — and that number depends on design choices (shift once per cel or
once per row; cache the shifted row; skip transparent runs before shifting rather than after) that do not
exist yet.

**Cost to close it honestly: a build of roughly half a dispatch** — a row-shift pass with phase dispatch, plus
a cycle count of the heaviest frame through it. That is the measurement, and it should be taken before the
representation is committed to, not after.

#### 3D — The full game, and a finding the dispatch asked for plainly

| representation | ~600 distinct cels |
|---|---|
| pre-shifted, 2 phases | 885,000 B (864 KB) |
| pre-shifted, 1.2 avg | 531,000 B (519 KB) |
| one-phase + shifter | 433,500 B (423 KB) |
| raw bitmap + shifter | 197,400 B (193 KB) |

POP loads per level, so the resident requirement is roughly an eighth — about 75 cels:

| representation | per level | vs the 14,848 B window |
|---|---|---|
| pre-shifted, 1.2 avg | 64.8 KB | exceeds |
| one-phase | 52.9 KB | exceeds |
| raw bitmap | 24.1 KB | **exceeds** |

**No representation reaches gameplay inside the current window — including raw bitmaps, by 1.6×.** That is a
measured result, and it says the gameplay memory map is a separate problem from the cutscene's: the window is
what is wrong there, not the representation. **The cutscene decision does not settle it and should not be
made as though it does.**

Per §7 I am not reopening the 128 KB choice. The finding above is stated because the dispatch asked for it;
it bears on the *window*, and there are options untouched here (per-level streaming, banking the cel store
outside the `$3000`-`$6A00` window, the 512 KB variant Jay declined at P3.10 for reach). Which of those
applies is a gameplay-era question.

---

### 4 — Verification (AC-by-AC)

- **AC1 — each candidate measured on TIME.** **PARTIAL, deliberately.** The pre-shifted baseline is measured
  (P3.19's method, quoted). The two shifted candidates are **not** measured, because doing so honestly needs a
  build; the build is costed and a defensible lower bound is given instead of a model (§3C). This is
  HARD-STOP #2 followed, not an omission.
- **AC2 — each candidate measured on SPACE.** **MET** (§3B), at 24 variants against the 14,848 B window, with
  code cost included and the one-phase verdict flagged as inside its error bar. Fits-without-relocation is
  stated: raw bitmap clears with 4,394 spare, no relocation needed.
- **AC3 — ~600-cel extrapolation.** **MET** (§3D), per-level as well as total.
- **AC4 — decision framed for Jay.** **MET** (§5), with the open time question named as the thing that
  decides it.
- **AC5 — P3.19's strawman not inherited.** **MET.** The 54/88 figure is not used anywhere; §3C counts a
  fresh sequence and labels it a floor.
- **AC6 — NO BUILD.** **MET.** `git status` clean but for this report.
- **AC7 — §6 route accounting present**; sync bridge untouched (no HAL change); Karateka untouched; `main`
  untouched. **MET.**

---

### 5 — The decision, framed

| candidate | bundle at 24 variants | fits window? | heaviest frame | ~600 cels | the trade in one line |
|---|---|---|---|---|---|
| **pre-shifted (today)** | 23,506 | **no, −8,658** | 19,579 = 66% **measured** | 864 KB | fastest, and it has run out of space three cels into one scene |
| **one-phase + shifter** | 14,876 | **undetermined** (−28, inside the estimate) | unmeasured | 423 KB | halves the data, keeps the segment overhead, and lands on the line |
| **raw bitmap + shifter** | **10,454** | **yes, 4,394 spare** | unmeasured, 87-108% bounded | 193 KB | 4.5× less data with margin; pays for it in time, and the time is unmeasured |

**A hybrid is worth costing and I could not cost it here.** P3.18's 1.16-phases-per-cel average is the whole
argument for one: pre-shift the cels that occupy a single phase (most of the library, drawn fastest), and
runtime-shift the walk cels that occupy two. That splits the difference on both budgets rather than either.
Costing it needs the same shifter build as §3C, so it should be measured in the same dispatch rather than
guessed at here.

**My recommendation, and the reasoning:** measure the shifter before choosing. Space already rules out
pre-shifted for the cutscene, so the real choice is between raw-bitmap and a hybrid — and **that choice is
decided entirely by the number §3C could not produce.** Building the shifter is the next dispatch whichever
way it goes, because both surviving candidates need it.

---

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** I proposed no route in conversation this dispatch. What this report contains: the space
measurement for all three candidates, the game extrapolation, and a *bounded* time statement. What it does
**not** contain, and what I am not implying it does: any measured time figure for a shifted representation.
§5's recommendation is explicitly to go and measure that, not to adopt raw-bitmap on the strength of space
alone.

**Deviations:**
- **Corrected my own units mid-measurement** (§1, §3B) — the first table compared all three candidates at 24
  items; only pre-shifted stores 24. The corrected table changes raw-bitmap from "fits by 1,146" to "fits by
  4,394" and one-phase from "over by 8,298" to "over by 28", so the error was material and in both
  directions.
- **Declined to model the shifter's cy/byte** (§3C) per HARD-STOP #2, giving a counted floor and a build cost
  instead.

### 7 — Uncertainty flags
- **The time side is open**, and it decides the outcome (§3C). The 87-108% band is wide enough to contain both
  "comfortable" and "does not fit".
- **The ~400/~700 B shifter and scanner code sizes are estimates** — the only modelled numbers in the space
  table. The one-phase verdict rests entirely on one of them and is therefore undetermined.
- **The 2.04× phase multiplier is measured on walk cels only.** It is right for moving content and wrong for
  the library average (P3.18: 1.16). Which applies depends on what is being stored, and a hybrid's whole case
  turns on that distinction.
- **The per-level figure (~75 cels) is an assumption**, not a measurement — POP's actual per-level cel counts
  were not read out of the level data.
- Carried: the ~0.51-frame cadence overrun; `aboutface` unexercised and invalidating baked parity when it
  fires.

### 8 — Follow-up candidates
1. **Build a well-made row shifter and cycle-count it** — the measurement this recon could not make, needed by
   both surviving candidates. Count the heaviest frame through it, and count the hybrid at the same time.
2. **Then decide the representation**, with both budgets measured.
3. **Read POP's real per-level cel counts** out of the level data, replacing §3D's ~75 assumption before any
   gameplay-era memory decision.
4. Carried: `Vstop`/`Vraise`/`Vexit`, `PlayCut0` (E); F/G/H; parity-vs-turning before G.

### 9 — User interaction during task
None — dispatch executed as written.

### 10 — Candidate(s) captured this task
`seeds/POP/live/2026-08-08-an-average-is-the-wrong-statistic-for-the-content-that-moves.md`

### 11 — Commit
See below (pushed to origin/wip before this report was surfaced).
