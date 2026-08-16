## Form B Report — P3.101 — the oracle slows at the exit and the port does not, and there is a 100-frame block

**Class:** recon (instrument + measurement) + harness sweep. wip. Prod untouched; **no `src/` or `content/` change.**

**★★★ TWO DIVERGENCES, BOTH MEASURED ON BOTH MACHINES, NEITHER ATTRIBUTED.**
**(1) The oracle's walk-out is 7.4% SLOWER than its walk-in. The port's is 1.2% FASTER. Same six
cels, same engine, and the oracle runs both halves at the same nominal `SPEED 7` — so its
slowdown is the oracle overrunning its own floor, and the port does not reproduce it.**
**(2) The port's walk-out contains a 101-frame block, `f4702..f4802`, where every step takes 10
frames instead of the modal 8 — ten consecutive steps, 1.67 s, 25% slow, then it snaps back. The
oracle's walk-out has nothing of that shape anywhere.** §6 HARD-STOP 3 applies to both: **nothing
was fixed.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-16T14:40:55-04:00 (HEAD `bf6635d`, wip). Karateka untouched. `main` untouched. Oracle
source read-only — the `.hdv` is copied to `build/` before any run; `git status oracle/` clean. No
`src/` or `content/` change, so no prod `.bin` moved. Pre-existing and not mine:
`dist/mame-cfg/rgb/coco3.cfg`, the untracked `docs/ground-truth/*.pdf`.

---

### 1 — Summary

| | |
|---|---|
| **★★★ measured** | step timing for all six walk cels, **entry and exit, on both machines** |
| **★★★ divergence 1** | oracle exit/entry **1.074**; port exit/entry **0.988** — the oracle slows, the port doesn't |
| **★★★ divergence 2** | port exit holds ten consecutive steps at **10f** where the mode is 8f, `f4702..f4802` |
| **★★ confirmed** | that block is a **loop-cost** event: 0.255 → **0.198** → 0.252 iterations/frame |
| **★★ excluded** | it is **not** extra draws — 3 draws per character per iteration throughout, unchanged |
| **★ excluded** | not the beat, not the scenery flags, not the sand, not the peel gate, not a disk read |
| **★★★ NOT established** | **why**, for either divergence. **Nothing fixed** |
| **★ controls** | three seeds; **the third was a no-op and reported the counter as broken** |
| **swept** | **eight more MAME paths** had no `-ramsize`; `run_block_budget.sh` had it hardcoded |
| **corrected** | P3.87's *"exit 10.00 f/play vs entry 8.00"* — **measures 8.14 vs 8.24 today** |

### 2 — Files modified

- `harness/tools/port_exit_column.lua` — timing report, `cad_idx`/`vm_due` taps, cadence seed
- `harness/tools/oracle_exit_column.lua` — arms at the **entry**, SPEED history, timing report
- `harness/tools/port_exit_stall.lua` — NEW; iterations/frame across the block, seeded
- `harness/smoke/run_exit_column.sh` — second (timing) control run
- `harness/smoke/run_exit_stall.sh` — NEW
- `harness/smoke/ramsize.sh` — the sweep recorded, with the grep that finds the stragglers
- `harness/smoke/run_change_census.sh`, `run_erase_addr_probe.sh`, `run_erase_trace.sh`,
  `run_frame_baseline.sh`, `run_peel_census.sh`, `run_peel_skip_cost.sh`, `run_peel_trace.sh` —
  now source `ramsize.sh`, pass `$RAMOPT`
- `harness/tools/run_block_budget.sh` — `-ramsize 128K` hardcoded → the shared home
- `mame-idioms-coco3-port.md` — §10: three new gotchas (§2A.3)
- `reports/20260816-144055-…md` — this

(explicit-path staging only)

### 3 — Reasoning

**3A — THE TWO TIMING SEQUENCES, SIDE BY SIDE. This is the deliverable.**

A **step** is the first draw of a new cel. Both machines draw each cel more than once per step
(two pages), so counting draws as steps halves every interval — the same "wrong width" shape as
P3.100's high-byte tap. Both rates come from each machine's own refresh, read from the machine:
**coco3 59.922748 Hz, apple2e 60.000000 Hz**.

| | **port** | **oracle** | port/oracle |
|---|---|---|---|
| **ENTRY** | **8.24 f/cel** = 137.6 ms | **5.97 f/cel** = 99.5 ms | 1.383 |
| **EXIT** | **8.14 f/cel** = 135.8 ms | **6.41 f/cel** = 106.9 ms | 1.268 |
| **exit / entry** | **0.988** | **1.074** | |

★★★ **The relation is INVERTED.** The oracle's walk-out is 7.4% slower than its walk-in; the
port's is 1.2% *faster*. The port is slow in absolute terms in both halves — that is P3.87's
accepted slip — but the **shape** of the scene's own tempo change is not reproduced, and a
comparative complaint ("the exit looks worse than the entry") is a claim about exactly that shape.

**And the oracle's slowdown is not a policy.** PlayCut0 writes `SPEED` five times and the trace
caught every one: `f140:1 f2681:12 f3597:7 f4732:12 f4886:7 f5243:12`. **`f3597` opens the entry
walk and `f4886` opens the exit walk, and both are 7** [SUBS.S:683, :752]. `lda SPEED / jsr pause`
is a **minimum**, not a target, so the oracle's exit is 7% slower **because its own exit frames
cost more** — the same mechanism the port has, producing a different number.

**Interval distributions, which the means hide:**

| | histogram | modal |
|---|---|---|
| oracle entry | 5f×7, 6f×21, 7f×6 | 6 |
| oracle exit | 5f×4, 6f×13, 7f×16, 8f×1 | 7 |
| port entry | 8f×29, **10f×4** | 8 |
| port exit | 7f×5, 8f×120, 9f×4, **10f×10** | 8 |

**3B — ★★★ THE 101-FRAME BLOCK, WHICH IS THE SHARPER DIVERGENCE.**

The port's exit intervals, in order:
`8,8,8,8,8,7,9,8,8,8,7,8,8,9,7,9,7,8,9,8,8,8,7,8,8,`**`10,10,10,10,10,10,10,10,10,10`**`,8,8,8,8,8,8,8`

**Named as a frame index and an interval, per AC3: from `f4702` to `f4802`, ten consecutive steps
at 10 frames against a modal 8** — 1.67 s at 80% rate, inside one beat, with clean 8s either side.
The oracle's longest excursion anywhere in its exit is a single 8 among 6s and 7s.

**It is a cost event, and that is measured rather than assumed.** `vm_nextframe` fires at the first
**loop iteration** at or after the due frame [char_draw.s:1993-2009], so the achieved interval *is*
the iteration rate. Counting iterations per frame across the window:

```
# BEFORE the 10-block  f4400..4701   0.255 it/f  (302 frames)
# INSIDE  the 10-block f4702..4802   0.198 it/f  (101 frames)
# AFTER   the 10-block f4803..5300   0.251 it/f  (498 frames)
```

0.255 it/f = 3.9 frames per iteration → a 6-frame request first clears at 7.8 ≈ **8**.
0.198 it/f = 5.05 frames per iteration → it first clears at 10.1 ≈ **10**. The arithmetic closes.

**What the block is NOT**, all sampled per frame across the same window and all unchanged across
its boundaries: the beat (18427 throughout, and 18427 continues past the block), `vm_scenery`,
`sc_flow` (the sand), `ch_anymove` (1 everywhere), `probe_loads` (12 — no staged disk read), and
**the number of draws: 3 per character per iteration inside and out** (viz/f and pri/f fall 0.75 →
0.60 together, which is 3× the iteration rate in both cases). **So it is cost per draw, not extra
draws, and not any state the scene publishes.**

**3C — THE LEAD I AM NOT ACTING ON, AND WHY.**

The block's span is exactly the stretch where the vizier's cel **straddles the right clip edge**:
his column runs 67 → 75 across it, `VIS_R` is 74 [char_draw.s:320], and at col 75 the cel is wholly
off and the rate returns to 8. That fits well.

★ **It is not confirmed and I did not act on it.** The probe for the clip window is unsound:
`bc_lead`/`bc_keep` are **one shared window reused by every character's every pass**, so a tap on
them returns whichever draw ran last, not the vizier's. It read a constant 6 while the column ran
43 → 128, which is not a clip window, it is contamination. I first read it at the `ch_dest` write —
also wrong, because `co_setup` stores `ch_dest` *before* computing the window [1495 then 1497-1535]
— fixed that, and the number stayed uninformative for the other reason.

**§6 HARD-STOP 3 and §3 of the dispatch both apply: last-candidate-standing is not proof, and the
mirror anchor led on shape for four dispatches and was wrong.** The next test is named in §8 and it
is decisive rather than corroborative.

**3D — §2 CHECK ONE: WHAT THE EXIT DOES DIFFERENTLY FROM THE ENTRY.** Enumerated *before* any
attribution, per AC4. Six differences, and only the first two were ever on the table:

1. **Mirrored bakes.** `v48_m..v53_m` — 4,565 B of different data through a different blit path.
2. **The anchor flip.** `co_setup` subtracts `awid*7` — **exonerated as a position cause at
   P3.100**, but never measured as a *cost*.
3. **★ He leaves the screen.** The entry walks 197 → 120, never near an edge; the exit walks off the
   right edge entirely, so the clip window is live for the whole exit and never for the entry.
   **This is new to this dispatch and it is the one §3C is about.**
4. **★ The hourglass exists.** It is added at `addglass1` before Vexit and fills during it; the
   entry has no hourglass on screen at all.
5. **★ The princess is animating underneath.** PlayCut0 gives `Pslump` 28 plays *while* Vexit is
   still looping; during the entry she is standing.
6. **The sand is flowing** (`psandcount` 0 is set before the exit and never before the entry).

★★ **Four of these six were not in the frame before today**, which is §2H check one doing its job:
*"the exit differs from the entry in more than one way"* was assumed to mean two ways.

**3E — §2H's THREE CHECKS.**

1. **A second mechanism for a different object class?** Yes, and it is 3D.5: the princess's beats
   run *under* the vizier's walk-out, so "the exit costs more" and "the vizier costs more" are
   different claims. The per-character draw counts are recorded for that reason and they say the
   count is unchanged — which does not settle the cost.
2. **The calling routine.** The rate is not `cad_tab`'s and not `vm_nextframe`'s: both are correct
   and the achieved interval is set by **`room_loop`'s** iteration cost. Reading `vm_nextframe`
   alone would have made this a scheduling question, and it is a cost question.
3. **Grep the reports.** P3.87 records *"scene beats 16/17/18 after the hourglass — 10.00 10.00
   10.00"* against *"Vwalk 8.00"*, and the dispatch carries that forward as the exit's rate.
   **Measured today the exit is 8.14 f/cel and the entry 8.24** — so either the beats-16/17/18
   figure is a mean over a mix that includes the arm-lowering, the six standing holds and the turn
   (all of which are in those beats and none of which is the walk), or it has moved since P3.87
   shipped the feet fix. **Either way it should not be quoted as the walk-out's rate**, and the
   `10f` intervals it was presumably picking up are the 10 measured here — ten of 139.

### 4 — Verification (AC-by-AC)

- **AC1 — the six cels' exit timing on both machines, from the running machines, not computed.**
  §3A. Port: `build/tmp/port_exit_column_measure.log`, 140 steps / 139 consecutive intervals,
  step boundaries taken from the `ch_dest` draw tap and cross-checked against an independent
  `cad_idx` write tap in the same run. Oracle: `build/tmp/oracle_walk_timing.log`, 35 steps.
- **AC2 — the entry measured the same way.** §3A. Port 35 steps; oracle 36 steps. The oracle's
  entry required moving the arm from the **second** `SPEED 7` to the **first** — P3.99 armed on the
  second only and could not see the entry at all.
- **AC3 — both sequences side by side; divergence as a frame index and an interval.** §3A, §3B.
  **`f4702`, 10 frames against a modal 8, ten consecutive steps to `f4802`.**
- **AC4 — the exit's differences from the entry enumerated before attribution.** §3D, six of them,
  written down before §3C's lead was tested and left untested-but-named rather than acted on.
- **AC5 — taps seeded and confirmed, including that the seed fires.** Three seeds this dispatch:
  - **column** (carried from P3.100): `# CONTROL PASSED: all 413 post-seed taps reported $A10A, both bytes.`
  - **timing**: `# SEEDED: cad_tab[0..5] 6 -> 12 at frame 2434; read-back CONFIRMS the write` →
    `# CONTROL PASSED: forcing cad_tab 6 -> 12 moved the MEASURED interval from 6.04 to 12.83 frames.`
  - **work counter**: `CONTROL PASSED: suppressing the peel raised the counter — it counts work.`
    (0.255 → 0.334 it/f)
- **AC6 — attributed → fix; not attributed → sequences and next split.** **Not attributed, for
  either divergence. Nothing fixed.** Sequences §3A/§3B, next split §8.
- **AC7 — the `-ramsize` sweep completed, all paths through the shared home.** §5.
- **AC8 — suites green, 128 KB first; build verified by symbol from a freshly baked image.** §5.
- **AC9 — route accounting; sync bridge; Karateka; `main`.** §6.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim).** `build.bat` re-run this dispatch: `=== BUILD COMPLETE ===`.
Every tool resolves its addresses out of `build/obj/flames.map` and `build/obj/room.map` and aborts
with `FAIL no symbol …` otherwise; `CP_DRAW` and `CAD_LEN` are **derived** from `CP_ERASE` (`equ 0`,
so its map value is the section base) rather than written as literals.

All eight suites, **128 KB** (`ramsize.sh`):
```
=== probe ===     [run_probe_test] PASS      === compiled === [run_compiled_test] PASS
=== mode ===      [run_mode_test] PASS       === introseq === [run_introseq_test] PASS
=== cel ===       [run_cel_test] PASS        === room ===     [run_room_test] PASS
=== anim ===      [run_anim_test] PASS       === walk ===     [run_walk_test] PASS
```
`[hal-sync] OK -- HAL source aligned with karateka_coco3 (11 files compared…)`

**★ THE `-ramsize` SWEEP IS COMPLETE, AND IT TOOK A THIRD PASS.** P3.98 routed ten runners; P3.100
found two more; this dispatch found **seven** with no `-ramsize` at all (`run_change_census`,
`run_erase_addr_probe`, `run_erase_trace`, `run_frame_baseline`, `run_peel_census`,
`run_peel_skip_cost`, `run_peel_trace`) plus `harness/tools/run_block_budget.sh`, which had
`-ramsize 128K` **hardcoded** — the right value in a second home, which no search for wrong answers
finds. The check that finds these is mechanical and now lives in `ramsize.sh`:
```
$ grep -rl '"$MAME" coco3' harness/ | while read f; do grep -q ramsize.sh "$f" || echo "$f"; done
(no output — sweep complete)
```
Re-reading §2K would have found none of the nine. `run_peel_trace.sh` spot-checked after the edit
and still produces its trace.

**25.2 bundled-artifact grep:** N/A — harness-only change, no sibling-import artifact.

**25.3 operator-runtime-smoke: N/A this dispatch — no `src/`/`content/` change, nothing new to put
on a screen.** Standing gates unchanged: flash, glass, sand, slump and the feet all **PASSED**
(Jay, live-disk, RGB, 128 KB). **The exit walk skip remains OPEN and unattributed.**

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** I proposed no route in advance. Against §5's list this change contains
**AC1–AC5, AC7, AC8, AC9 in full**, and **AC6 deliberately not exercised** — neither divergence is
attributed, so under HARD-STOP 3 nothing was fixed and in particular **§3C's clip lead was not
acted on despite fitting the block's span exactly**. Named as not-done rather than left absent:
the clip test is *identified* in §8 and *not run*; 3D's items 4, 5 and 6 are enumerated and none is
measured.

**Reactive deviations (§22.5):**
1. `harness/tools/port_exit_stall.lua` and its runner are new work not named in the dispatch. They
   exist because §1's measurement produced a block that a timing table can show but not explain,
   and "what is the next split" is a worse answer when one run can say whether the block is a cost
   at all.
2. Three gotchas added to `mame-idioms-coco3-port.md` §10 (§2A.3 requires this and requires
   surfacing it here): `screen.refresh_attoseconds` is a **property, not a method**; a tap on
   **shared scratch** reads whoever wrote it last; **sampling order inside a routine** matters as
   much as the address.

Oracle source read-only. Karateka untouched. `main` untouched. `hal-sync` OK.

### 7 — Uncertainty flags

- **★★ Neither divergence is attributed.** §3C's clip lead fits the block's span and is **not
  evidence** — the probe for it reads shared scratch.
- **★★ THE THIRD SEED FAILURE IN TWO DISPATCHES, AND THIS ONE BLAMED THE INSTRUMENT.** The work
  counter's first seed forced `ch_anymove` **on**; it ran 2,773 substitutions and read back
  correctly, and `ch_anymove` was **already 1 on every frame of the window**. Nothing was
  perturbed, nothing changed, and the run printed *"the counter did not fall when the work rose —
  reject this probe"*. Forcing it **off** moved 0.255 → 0.334 at once. The three forms so far: the
  write was **discarded** (P3.100, language-card write protection); the seed had **no baseline**
  to compare against; the seed wrote a value **already held**. All three produce "no effect
  observed" and none is evidence about the instrument.
- **★ P3.87's `10.00 f/play` for the post-hourglass beats should not be quoted as the exit walk's
  rate** — §3E.3. I have not established which of the two explanations is right.
- **★ The oracle's exit intervals drift** (7,7,7,7,7,6 early → 6,6,6,5,5,5 late) and I have not
  explained it; the port's do not. Offered as something seen, not as a lead.
- The oracle's entry/exit split is by `vexit_at`, i.e. by PlayCut0's marker; the port's is by the
  engine's own facing. Both are sound and they are **different discriminators**, which is worth
  knowing if the two ever disagree at a boundary step.
- Carried, unchanged: the characters' per-iteration draw; 0.20 s driver overhead; the
  `$2310..$2329` blindness; the scene is one page from a single load, no freeze; `PlayCut0`'s
  remaining sound sites stubbed as holds; `Fdy` dropped at `cel_table+2`.

### 8 — Follow-up candidates

1. **★ THE DECISIVE CLIP TEST, and it is a seed rather than a better probe.** Change `VIS_R` and
   re-run the timing measurement. **If the 10-block moves with it, it is attributed; if it does
   not, the clip is refuted.** That is a perturbation with a predicted direction — the shape every
   control in this arc that worked has had, and the shape §3C's contaminated tap does not.
2. The hourglass and the princess's `Pslump` (3D.4, 3D.5) — the other two things live during the
   exit and dead during the entry, neither measured.
3. **The relative-tempo divergence separately from the block** (§3A). Even with the block removed
   the port's exit/entry ratio is 0.99 against the oracle's 1.07; the block is 10 of 139 intervals
   and cannot account for it.
4. Per-character clip instrumentation gated on `ch_idx` **and** `ch_cp`, if a clip number is ever
   needed again.

### 9 — User interaction during task

None.

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-16-a-rate-is-only-wrong-relative-to-something.md` (the dispatch's own)
- `seeds/POP/live/2026-08-16-a-perturbation-that-writes-a-value-already-held.md` (new, from §7)

Committed and pushed to the pool (fire-and-forget, non-blocking).

### 11 — Commit

`e97fb21`  (pushed to origin/wip before this report)
