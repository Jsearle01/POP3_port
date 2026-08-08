## Form B Report — P3.38b — the two follow-ups: the overrun is ONE step, and it fits
**Class:** recon (follow-up). wip. No `src/` change, no build, no lever pulled, no representation committed.

### 0 — Receipt / status (C-35 stamp)
t0=2026-08-08T17:36:53Z (the P3.38 receipt; this is its follow-up in the same session, no intervening
dispatch). HEAD at start `073dd5c`, wip, `git status --porcelain` clean of tracked modifications. Untracked
unchanged from P3.38. No HAL change; no build.

---

### 1 — Summary

**Both follow-ups changed the answer, and in the same direction.**

**The overlap is one step, not thirteen.** `Vraise` repeats cel 67 six times — a repeat is not a cel change,
so the vizier is fully static (fixed x, fixed cel) for five of those — and `Pback`'s tail is `:loop db 17`
with no `chx`, so the princess stops moving after five steps. **Exactly one step of thirteen has both
characters shifting: vizier cel 67 + princess cel 12.**

**And that step's cels are smaller than the walk mean the costing used.** Measured: 156 + 119 = **275 drawn
bytes**, against the assumed 2 × 178 = 356.

| | frame | % of 29,673 |
|---|---|---|
| at 30.0 cy/B (unrolled inner) | 27,902 | 94% |
| **at ~34 cy/B (all-in)** | **29,002** | **98% — fits** |
| threshold for this frame | | **36.4 cy/byte** |

**So the gap closes — by 671 cycles, 2.3%.** Reported and stopped, per HARD-STOP #3; the representation build
is a separate authorised dispatch.

**The margin is thin and I want that read as thin**, not as a clearance. §3D lists what could still eat it.

---

### 2 — Files modified
- `reports/20260808-134448-p3-38b-followup-heaviest-frame.md` — this report.

No `src/` change. The trace script is scratch (`…/scratchpad/p338/trace.py`); the cel conversions are scratch.

---

### 3 — Reasoning

#### 3A — The step trace, and the two details that carry it

| step | vizier (`Vraise`) | princess (`Pback`) | shifts |
|---|---|---|---|
| 1 | cel 67 **CHANGED** | cel 12 **moved** | **BOTH** |
| 2-5 | cel 67 (repeat) | cels 13-16 moved | princess |
| 6 | cel 67 (repeat) | cel 17 (static) | neither |
| 7-13 | cels 68-74 CHANGED | cel 17 (static) | vizier |

**BOTH: 1 step. Vizier only: 7. Princess only: 4. Neither: 1.**

Two details decide it, and both are the kind that a summary of a sequence loses:

- **`Vraise` repeats cel 67 six times** (`db 85,67,67,67,67,67,67`). A repeat is not a cel change, so no
  shift is needed — the bytes are identical to last frame's.
- **`Pback` stops moving.** Its `chx` values run out after five steps and it settles into `:loop db 17`.

**Alignment matters and is easy to get wrong:** the vizier is one step ahead, because `play 1` after
`vjumpseq Vraise` consumes cel 85 before `play 13` begins. Without that offset the trace puts the collision on
the wrong step.

#### 3B — The real heaviest frame, measured

Resolved through `ALTSET2` and converted at each cel's own derived `start_col` (the P3.24 parity rule), then
classified with the same `cel_blit_prep` routine used for every other byte count in this arc:

| cel | image | rows × width | footprint | **drawn** | vs 178 assumed |
|---|---|---|---|---|---|
| vizier 67 | chtab6.A #93 | 48 × 7 | 336 | **156** | −12% |
| princess 12 | chtab6.A #35 | 43 × 6 | 258 | **119** | −33% |
| | | | | **275** | vs 356 |

**P3.38 flagged this number as its largest open uncertainty and predicted it would go the wrong way** — that
`Vraise`'s cels are 48-58 rows against the walk's 47, so the frame would be *heavier* than costed. **That
prediction was wrong.** Cel 67 is indeed taller (48 rows) but narrower (7 bytes vs the walk's up to 10), and
more of it is transparent: 156 drawn of 336 footprint is 46%, against the walk cels' 47%. Row count is not
drawn-byte count, and I reasoned from the wrong one.

The princess's cel 12 is smaller still — 119 drawn — which is unsurprising once looked at rather than
assumed: `Pback` is her turning away, a narrower pose than the standing frame the mean was drawn from.

#### 3C — Why 178 was the wrong number to carry

178 B/cel is the **walk cels'** measured mean (P3.35), and it has been multiplied by two and used as the
heaviest frame in P3.36, P3.37 and P3.38. **Neither character in the actual heaviest frame is drawing a walk
cel.** The vizier is mid-`Vraise`; the princess is mid-`Pback`.

That is the same error P3.33 made with the phase multiplier — a mean measured over one population applied to
a different one — and it survived three dispatches because the number looked measured rather than assumed.
**It was measured. It was measured on the wrong cels.**

#### 3D — The margin is 671 cycles and here is what could eat it

I am not presenting 98% as a pass with room. Four things could move it:

- **`shift_row.s` is counted, not assembled** (P3.36 §3C). The 34.0 all-in figure is arithmetic over a written
  instruction sequence with seven elided identical rungs. Assembling it could move the rate.
- **34.0 was computed for 6-byte rows.** Cel 67 is 7 bytes wide and cel 12 is 6; at 7 bytes the all-in rate is
  ~33.4, which helps slightly — but the per-row setup estimate (~24 cy) is itself counted from written setup,
  not measured.
- **I have not proved this is the heaviest frame across the whole scene.** I traced `play 13` because P3.38
  identified it as the only both-shifting stretch. A single-character-shifting frame would need ~294 drawn
  bytes to reach the same cost; the largest cels I have measured are well under that, but **I did not
  enumerate every cel in the scene.**
- **The baseline 19,652 inherits P3.19's per-cel component figures** (P3.37 §7), which were not re-derived.

**Any one of these could turn 98% into over.** The honest statement is that the gap closes on current
measurements with 2.3% to spare, not that it is settled.

---

### 4 — Verification

- **Follow-up 1 — trace `play 13` step by step.** **DONE** (§3A): 1 of 13 steps has both shifting, with the
  vizier's one-step lead accounted for.
- **Follow-up 2 — measure `Vraise`/`Pback` drawn bytes.** **DONE** (§3B): 156 + 119 = 275, converted at
  derived parity and classified by the same routine as every other count in this arc.
- **Recomputed against P3.37's 19,652**, at both rates, with a threshold computed fresh (36.4) rather than
  inherited.
- **No build, no lever, no representation committed.** Reported and stopped on the gap closing, per
  HARD-STOP #3.

---

### 5 — What this means for the decision

**On current measurements the shifted representation fits the cutscene**, including its worst frame, at 98% of
one hardware frame.

That reverses the working conclusion of P3.33-P3.37 — **and it does so because two carried numbers were wrong
in the same direction**: the heaviest frame was assumed to be two walk cels (it is neither), and the overlap
was assumed to last thirteen steps (it lasts one).

**What I have not done, deliberately:** started the representation build, pulled any lever, or costed the
hybrid. §3D's four caveats should be closed before the decision is treated as final — in particular
assembling `shift_row.s`, which is the difference between a counted rate and a real one.

---

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** I proposed no route. This change contains one report: a step trace, two cel
measurements, and a recomputation. It contains no code, no lever, no representation, no hybrid costing, and
no recommendation to build. §5 states what the numbers say and stops there.

**Deviations:** none from the instruction. Both named follow-ups were executed; the result closed the gap, and
per HARD-STOP #3 I reported rather than continuing.

### 7 — Uncertainty flags
- **The 671 cy margin is 2.3%**, and §3D lists four things that could consume it. **This is not a settled
  fit.**
- **`shift_row.s` remains counted, not assembled** — the largest single unknown.
- **Not proved to be the scene's heaviest frame globally** (§3D) — only the heaviest both-shifting frame.
- **My P3.38 prediction that these cels would be heavier was wrong** (§3B); I reasoned from row count rather
  than drawn bytes. Worth noting because the same slip would recur on any cel not yet measured.
- Carried: the ~0.51-frame cadence overrun; `aboutface` unexercised and invalidating baked parity.

### 8 — Follow-up candidates
1. **Assemble and run `shift_row.s`** to convert the counted 30/34 into a measured rate — the difference
   between 98% and a real verdict.
2. **Enumerate the scene's cels for drawn bytes** to confirm no single-character frame exceeds ~294 (§3D).
3. **Then Jay's decision**, with the fit confirmed or refuted on measured rather than counted numbers.
4. Carried: `Vstop`/`Vraise`/`Vexit`, `PlayCut0` (E); F/G/H; parity-vs-turning before G.

### 9 — User interaction during task
Jay asked for the two follow-ups P3.38 §8 named. Both were done and both moved the answer.

### 10 — Candidate(s) captured this task
None new — §3C is a second instance of
`an-average-is-the-wrong-statistic-for-the-content-that-moves` (a mean measured over one population applied to
another), recorded here as an instance rather than duplicating the row.

### 11 — Commit
This report only; no `src/` change. Pushed to `origin/wip`. `main` untouched; no force-push.
