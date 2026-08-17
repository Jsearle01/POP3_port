## Form B Report — P3.41 — executing the shift loop: the verdict holds, and three bugs surfaced
**Class:** build (instrument) + measure. wip. No representation committed; no lever pulled.

### 0 — Receipt / status (C-35 stamp)
This work follows Jay's *"execute it"* within the P3.40 session rather than a fresh dispatch, so the standing
receipt is P3.40's: t0=2026-08-08T18:08:27Z (HEAD `8bbf7fd` at that receipt, wip, clean of tracked
modifications). HEAD at report = `1c20d2c`. No HAL change; the benchmark is not linked into any shipped
target, so the regression surface is untouched.

---

### 1 — Summary

**The loop was executed and the stagger verdict holds.**

| | measured | counted (P3.39) | |
|---|---|---|---|
| per byte | **32.9 cy** | 32.0 | +3% |
| per row | **56.2 cy** | 59.0 | −5% |

| route | shift | frame | |
|---|---|---|---|
| both in one frame (today) | 14,162 | 33,814 | 114% — over |
| **stagger, vizier advances** | 7,830 | **27,482** | **93% — fits** |
| stagger, princess advances | 6,332 | 25,984 | 88% |

**Worst staggered frame 27,482 = 92.6%, 2,191 cycles spare.** P3.39's assembled figures were right within a
few percent, and **this is the first number in the arc to survive the next level of rigour** — counted became
assembled and moved 16 points; assembled became executed and moved less than one.

**Three bugs surfaced, each invisible to the level of rigour below it** (§3C), and one of them is mine
repeating a failure I had just written up.

---

### 2 — Files modified
- `src/engine/shift_row.s` — the DP bug **fixed** (24 direct-page references to extended). It was documented
  at P3.39 and left in the file.
- `src/harness/shift_bench.s` — **new.** The benchmark: table build, two timed runs at 7- and 6-byte rows.
- `harness/tools/shift_bench.lua` — **new.** Pokes the binary, starts it, times the phases off the VBL.

Commit `1c20d2c`. Explicit-path staging. Nothing linked into a shipped target.

---

### 3 — Reasoning

#### 3A — Method, and why frames rather than a cycle counter

**Elapsed video frames over 19,968 iterations at two row widths.** The VBL is the clock every rate and cadence
figure in this project is already measured against; at ~20,000 iterations a one-frame error is 0.006%. A cycle
counter would be more direct and not obviously more trustworthy — it would be a **new instrument**, and
instruments here have failed silently seven times.

**Two widths, so neither figure is assumed.** w=7 and w=6 differ by exactly one unrolled rung, so:

```
  cy(7) − cy(6)            = the per-BYTE cost
  cy(6) − 6×per-byte − 26  = the per-ROW overhead   (26 = the bench's own loop)
```

That matters because **P3.21 was wrong by 2.2× from applying one row width's rate to another's**, and P3.39
found per-row overhead to be 38% of the total. Measuring one width would have left the split unresolved.

**Launch path: poke.** This is a leaf-routine timing measurement, not a gate — nothing here is offered as a
25.3 observation, and §4's objection to poke concerns hiding load/launch bugs in gated behaviour.

#### 3B — Measured against counted

**+3% on the byte, −5% on the row**, and they partly cancel. The counted figures were sound; the value of
executing was not that it corrected them but that it **proved they were correctable-by-nothing** — and, as
§3C shows, that the routine as committed did not actually run.

#### 3C — Three bugs, and the level each needed

**1. The DP bug P3.39 documented and did not fix.** `orb <sr_carry` with DP=0 addresses `$00xx`; `sr_carry`
lives with the routine. **The machine hung on first execution.** P3.39 found this, costed the fix at
+2 cy/byte, folded that into its numbers — and left the file unchanged.

That is precisely the failure P3.39 captured as a pool candidate (*a lesson recorded is not a lesson
applied*), committed by me, one dispatch later, against the very file the lesson was about. **Writing it down
did not prevent the next instance**, which is a sharper version of the original finding than the original
made.

**2. My benchmark's table fill used signed indexing.** `stb a,y` with A = v+128 — and accumulator-offset
indexing is **signed**, so every entry landed *below* the table base, **on top of `shift_row`'s code**. The
routine hung again. **This is the exact trap the permuted-table layout exists to avoid**, described in
`shift_row.s`'s own header, and I fell into it while writing the code that builds that table.

**3. The benchmark never set double speed.** The 29,859 cy/frame budget every figure in this arc is stated
against is a **double-speed** number; the CoCo3 boots at 0.89 MHz. So the first *successful* run divided
double-speed cycles by normal-speed frames and reported **623.6 cy/row for a routine counted at 284** — a
clean factor of two.

**What made it findable was having a number to disbelieve.** 623.6 against a counted 284 is not a
catastrophic result, it is a wrong clock — but only if you have the 284. **A measurement with no prediction to
contradict would have been reported.**

**Each bug needed a different level:** (1) and (2) needed *execution* — no amount of counting or assembling
reaches a machine that hangs. (3) needed *a prior estimate*, which is the level below.

#### 3D — The verdict, at measured rates

Recomputed from P3.37's 19,652 with the measured 32.9 / 56.2, on P3.38b's frame (vizier cel 67: 48 rows,
156 drawn bytes; princess cel 12: 43 rows, 119):

- **both in one frame: 33,814 = 114%** — unchanged; the representation still fails without a stagger.
- **worst staggered frame: 27,482 = 92.6%**, 2,191 cy spare.

**P3.40's finding stands on execution.** The stagger's mechanism is unchanged: each frame draws both
characters (double buffering requires it) and only the advanced one re-shifts, reusing the other's cached
shifted bytes.

---

### 4 — Verification

- **Loop executed**, not counted: 19,968 iterations × 2 widths, timed off the VBL.
- **Both figures derived, not assumed** — per-byte from the width difference, per-row from the remainder.
- **The DP bug fixed** and the routine now runs to completion.
- **Regressions untouched** — neither `shift_row.s` nor the benchmark is linked into a shipped target; no
  `src/` behaviour changed. Karateka untouched; `main` untouched.
- **No representation committed; no lever pulled.**

---

### 5 — Where the decision stands

| candidate | space | time |
|---|---|---|
| pre-shifted | over by 8,658 B | 66% |
| shifted, no stagger | fits, 10,454 B | **114% — over, measured** |
| **shifted + stagger + cache** | fits (10,454 + 685 B cache, 4,394 spare) | **92.6% — fits, measured** |

**One route now clears both budgets on measured numbers.** Its cost is 16.7 ms of lateness on one character,
once, in the scene (P3.40 §5).

Authorising it is Jay's. This dispatch built an instrument and took a measurement; it did not build a
representation.

---

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** I proposed no route. This change contains: the DP fix to `shift_row.s`, a benchmark, a
timing script, and this report. It contains **no** representation, no stagger implementation, no cache, and no
change to any shipped target. §5's table reports what the measurements say; it does not authorise anything.

**Deviations:**
- **Fixed `shift_row.s`'s DP bug** rather than only measuring around it — the routine could not execute
  otherwise, so the fix was a precondition of the dispatch rather than scope creep.
- **Ran the benchmark at double speed** after the first result exposed the clock error (§3C.3).

### 7 — Uncertainty flags
- **The measurement is of the shift loop in isolation**, not of the loop inside the real draw path. Cache
  effects, the peel's interleaving and the VM's own work are the 19,652 baseline, which is P3.19's and still
  inherited (P3.37 §7).
- **Phase 1 only.** The tables are built for a 2-bit shift; phases 2 and 3 use the same instruction sequence
  and should cost the same, but I did not time them.
- **The 26 cy bench-loop overhead I subtracted is counted, not measured** — it is small and affects only the
  per-row split, not the per-byte figure or the totals.
- **The stagger itself is unbuilt.** 92.6% is the measured shift cost placed into an arithmetic model of a
  staggered frame, not a staggered frame that ran.
- **The scene's cels remain unenumerated** (P3.39 AC4) — staggering changes which frames are heaviest.
- Carried: the ~0.51-frame cadence overrun; `aboutface` unexercised and invalidating baked parity.

### 8 — Follow-up candidates
1. **Jay's decision on the stagger** — it is the one route measured inside both budgets.
2. **If authorised: build it and measure a real staggered frame**, since §7 notes 92.6% is still a model
   around a measured component.
3. **Enumerate the scene's cels** before relying on `play 13` remaining the worst case under a stagger.
4. Carried: `Vstop`/`Vraise`/`Vexit`, `PlayCut0` (E); F/G/H; parity-vs-turning before G.

### 9 — User interaction during task
Jay said *"execute it"* — the check P3.40 had named as outstanding. It found three bugs and confirmed the
verdict. He then asked whether I had reported, which I had not; this report is that.

### 10 — Candidate(s) captured this task
`seeds/POP/live/2026-08-08-each-level-of-rigour-finds-faults-the-level-below-cannot.md`

### 11 — Commit
`1c20d2c` — the DP fix, the benchmark, the timing script, and the measured figures.
This report follows. Both pushed to `origin/wip`. `main` untouched; no force-push.
