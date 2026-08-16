## Form B Report — P3.102 — the grid absorbs the slowdown, and the block crosses a frame line

**Class:** recon (instrument + measurement). wip. Prod untouched; **no `src/` or `content/` change.**

**★★★ THE ORCHESTRATOR'S LEAD IS HALF RIGHT, AND THE HALF IT IS WRONG ABOUT IS THE IMPORTANT
HALF.** The port's exit iteration **does** cost more than its entry — **+2.5%**, invisible to the
rate because the grid rounds it away, exactly as predicted. **But the oracle's exit costs 7.4%
more than its entry, so the port is doing about ONE THIRD of the proportional extra work.** The
grid explains why the port shows **no** slowdown; it does **not** make the port faithful in work.

**★★★ AND THE 100-FRAME BLOCK IS ATTRIBUTED AT THE MECHANISM.** The port's exit iteration runs
**5.6% under a whole-frame boundary** (63.18 ms of work against a 66.75 ms four-frame budget). A
**+13% cost bump** at `f4700` pushes it over, the iteration becomes **5 frames instead of 4**, and
the step becomes **10 instead of 8**. The work then decays back through the line by `f4800` and the
step returns to 8. **The source of the +13% is not attributed** and nothing was fixed.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-16T19:29:12-04:00 (HEAD `a23682e`, wip). Karateka untouched. `main` untouched. Oracle
source read-only and not run this dispatch. No `src/` or `content/` change, so no prod `.bin`
moved. Pre-existing and not mine: `dist/mame-cfg/rgb/coco3.cfg`, the untracked
`docs/ground-truth/*.pdf`.

---

### 1 — Summary

| | |
|---|---|
| **★★★ §1's lead — tested** | **partly holds.** Exit work **is** higher (+2.5%) and the rate cannot show it |
| **★★★ §1's lead — refuted** | it does **not** account for the divergence: oracle **+7.4%**, port **+2.5%** |
| **★★★ the block — attributed** | work **63.18 → 71.7 ms** crosses the **66.75 ms** four-frame line; iteration 4→5 frames, step 8→10 |
| **★★ the margin** | the exit runs **5.6% under** the boundary — that is why a 13% bump costs a whole frame |
| **★★ excluded this dispatch** | **the princess** — her cel is 18 across both block boundaries |
| **★★★ NOT attributed** | **what costs the +13%.** Nothing fixed |
| **★ costed, not built** | a matched exit needs **8.85 frames**; the port can express **8 or 10** and **8 is already the closer of the two** |
| **★ controls** | seed fired and moved the measurement (61.6 → 38.2 ms); **its read-back check was itself wrong and is fixed** |

### 2 — Files modified

- `harness/tools/port_iter_cost.lua` — NEW; work vs slack per room-loop iteration, seeded
- `harness/smoke/run_iter_cost.sh` — NEW; control first, 128 KB, live-disk
- `reports/20260816-192912-…md` — this

(explicit-path staging only)

### 3 — Reasoning

**3A — WHY THE RATE COULD NOT ANSWER THIS, AND WHAT DOES.**

`room_loop` ends every iteration in `HAL_time_vbl_wait`, which spins on the frame counter
[hal/coco3-dsk/time.s:129-141]. So an iteration is **a whole number of video frames by
construction**, and the step fires at the first iteration boundary at or after `cad_tab`'s 6
[char_draw.s:1993-2009]. **The achievable step lengths are multiples of the iteration length. There
is nothing in between, and a 7.4% change in an 8-frame step is 0.59 frames — not expressible.**

The unquantised quantity underneath is reachable, and that is the measurement:

```
room_loop  [ ---------- WORK ---------- ][ --- SLACK --- ]  room_loop
           ^                              ^
           iteration start                HAL_time_vbl_wait entry
```

**TOTAL is quantised. WORK is not.**

**3B — THE ANSWER, WITH THE NUMBERS (AC1, AC2).**

| | **WORK ms/iter** | in frames | **TOTAL ms/iter** | slack ms | spin hits/iter |
|---|---|---|---|---|---|
| **ENTRY** (72 iters) | **61.649** | 3.69 | 68.607 | 6.957 | 1734 |
| **EXIT** (319 iters) | **63.184** | 3.79 | 67.799 | 4.615 | 1135 |

- **WORK exit/entry = 1.025** (+1.535 ms/iteration)
- **TOTAL exit/entry = 0.988** — the number P3.101 reported as the divergence
- **the oracle's step-rate ratio for the same two walks = 1.074** [P3.101]

★★★ **So the grid IS masking a slowdown, and the slowdown it is masking is a third of the
oracle's.** Both halves are load-bearing:

1. **The lead holds as a mechanism.** The port's exit is genuinely dearer, both iterations still
   round to 4 frames (3.69 and 3.79 both ceil to 4), so the achieved rate is identical and the
   measured 0.988 carries **no information about the work at all**. The slack falls 6.96 → 4.62 ms
   and the spin count falls 1734 → 1135, which is the same fact from two other directions.
2. **The lead fails as an explanation.** 2.5% is not 7.4%. Had the port been doing the oracle's
   proportional extra work its exit iteration would cost ~66.2 ms — which is **0.5 ms under the
   four-frame line**, i.e. it would have been on the edge of jumping to 10 permanently.

**★ Treating the oracle's 1.074 as a WORK ratio is an inference, and it is a measured one.** The
oracle's `lda SPEED / jsr pause` is a floor, so its rate equals its work only if it is work-bound
rather than floor-bound. **It is: its intervals VARY** — entry `5,5,6,6,6,6,6,6,7,6,5,…`, exit
`6,6,8,6,5,6,7,7,7,7,7,6,…` [P3.101]. **A floor-bound loop produces a constant.** The oracle's own
work-vs-slack split is nevertheless not measured, and that is named in §8.

**3C — ★★★ THE BLOCK, ATTRIBUTED AT THE MECHANISM (AC3).**

A four-frame iteration is **66.753 ms** at the machine's own 59.922748 Hz. Across the walk-out, in
25-frame buckets:

```
    frames        iters  WORK ms   TOTAL ms  frames/iter
    4650 ..4674    6      63.739    66.753    4.00
    4675 ..4699    6      62.333    66.753    4.00
    4700 ..4724    5      71.659    83.440    5.00     <-- over the line
    4725 ..4749    5      71.781    83.441    5.00
    4750 ..4774    5      68.856    83.441    5.00
    4775 ..4799    5      67.000    83.441    5.00     <-- still over, barely
    4800 ..4824    7      63.589    66.752    4.00     <-- back under
    4825 ..4849    6      63.313    66.754    4.00
```

**`frames/iter` is 4.00 everywhere and 5.00 for exactly the block.** Work rises from ~63 ms to
71.7 ms (**+13%**), crosses 66.753, and the VBL lock rounds the iteration up. Two iterations per
step, so the step goes 8 → 10. **The arithmetic closes with no free parameter**, and it explains
why P3.101 could exclude the beat, the scenery, the sand, the peel gate, the disk read and the
draw count and still see a block: **none of those is the mechanism — the frame boundary is.**

★ **And the work DECAYS across the block** — 71.7, 71.8, 68.9, 67.0 — rather than stepping down.
Whatever costs the extra is tapering off, not switching off.

**3D — WHAT THE +13% IS, WHICH IS NOT ATTRIBUTED (AC3, HARD-STOP 3).**

Excluded before this dispatch [P3.101]: the beat, `vm_scenery`, `sc_flow`, `ch_anymove`,
`probe_loads`, and the draw count (3 per character per iteration throughout).

**Excluded by this dispatch: the princess.** Her cel reads **18 across both block boundaries** and
through the whole block — she is animating underneath the walk-out (PlayCut0 gives `Pslump` 28
plays while `Vexit` still loops), which is why she was a live candidate [P3.101 §3D.5], and her
state does not change where the cost does.

**Remaining, and the leading one is unchanged:**

1. **★ The clip path.** The block is the stretch where the vizier's cel straddles the right edge
   (`VIS_R` 74). The **rise-then-decay** shape fits a shrinking partially-clipped blit better than
   the step function a mode switch would give — but ★ **this is a second dispatch of the same fit
   and it is still not evidence.** My column sample this run was contaminated the same way P3.101's
   `bc_keep` was: `ch_col` read at the `room_loop` tap returned a constant 32 with `ch_w` 6, which
   is shared scratch holding whichever draw last touched it, not the vizier's.
2. The peel/save extents (`ch_w`/`ch_h`) per variant.
3. Something outside the character draw entirely — the flicker, the present path, the mapping.

**★★ §5 HARD-STOP 3 applies and the clip was NOT acted on, for the second dispatch running.** The
decisive test is in §8 and it is a perturbation with a predicted direction, not a better probe.

**3E — §2H's THREE CHECKS.**

1. **A second mechanism for a different object class?** Yes, and it is why 3D.2 is on the list:
   the port's cost is not one blit but three passes over two characters, and the peel's extent is a
   property of the VARIANT rather than the cel number [char_draw.s:940-943]. The work figure here
   is whole-frame and does not separate them.
2. **The calling routine.** The step rate is neither `cad_tab`'s nor `vm_nextframe`'s — both are
   correct and both are ceilings applied to a number `room_loop` decides. Reading `vm_nextframe`
   alone makes this a scheduling question; it is a cost question, and P3.101 already had to make
   that correction once.
3. **Grep the reports.** P3.25 recorded *"0.84 iterations per video frame"* — **measured 0.245
   today** (4.08 frames per iteration), and the note at char_draw.s:1985-1992 that quotes it is
   describing a *counter* that has since been replaced by real VBL pacing. Not a contradiction,
   but the figure should not be quoted as current. P3.87's *"6/8/10, nothing between"* is
   confirmed and now has its cause: the iteration is 4 frames because the work is 3.79.

### 4 — Verification (AC-by-AC)

- **AC1 — §1's lead tested; exit iteration cost against entry's, independent of the rate.** §3B.
  `build/tmp/port_iter_cost_measure.log`, 1005 iterations to frame 5800, split by the vizier's own
  facing (the P3.100/P3.101 discriminator). **The unit is milliseconds, not cycles: `cpu.clock`
  is nil on this MAME binding, and the port switches the GIME to double speed at runtime, so a
  cycle figure would have been a guess.** The tool probes three accessors and prints "not exposed
  by MAME here" rather than inventing one.
- **AC2 — whether the grid explains 0.988 vs 1.074, plainly, with the numbers.** §3B. **It
  explains the port's flatness and not the divergence.** 2.5% against 7.4%.
- **AC3 — the block attributed by split, or candidates enumerated with the next split named.**
  §3C attributes the **mechanism** (work crosses the four-frame line). §3D enumerates what is left
  for the **source**, with the princess newly excluded, and §8 names the decisive test.
- **AC4 — nothing tuned, nothing fixed on shape; a matched exit costed, not built.** No `src/` or
  `content/` change; `cad_tab` untouched. **The costing:** a matched exit is
  `8.24 × 1.074 = 8.85` frames. The port's step is a whole number of 4-frame iterations, so its
  options are **8 or 10** — 8.85 is not expressible at any `cad_tab` value. ★ **And 8 is already
  the closer of the two:** |0.988 − 1.074| = 0.086 against |10/8.24 − 1.074| = 0.139. **So there
  is no tuning that improves this, and the current behaviour is the better of the port's two
  available options.** Reaching 8.85 needs a finer grid, i.e. a shorter iteration, i.e. less work
  per iteration — which is the standing per-iteration-draw item, blocked by the torch repaint.
  Whether a whole-frame slowdown reads better than none is Jay's eye (§2I), not this calculation.
- **AC5 — controls seeded, and the seeds confirmed to fire.** `# ★ SEED: ch_anymove -> 0 on every
  write; 3418 writes, 2278 of them CHANGED the value` →
  `[iter_cost] CONTROL PASSED: suppressing the peel cut measured work — it measures work.`
  (61.649 → 38.161 ms). ★ **The seed's own read-back check was wrong first and is fixed** — see §7.
- **AC6 — suites green, 128 KB first; build verified by symbol from a freshly baked image.** §5.
- **AC7 — route accounting; sync bridge; Karateka; `main`.** §6.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim).** `build.bat` re-run this dispatch: `=== BUILD COMPLETE ===`.
The tool resolves every address from `build/obj/room.map` and `build/obj/flames.map` and aborts
with `FAIL no room symbol …` / `FAIL no flames symbol …` otherwise.

All eight suites, **128 KB** (`ramsize.sh` — the sweep completed at P3.101):
```
probe      [run_probe_test] PASS        compiled   [run_compiled_test] PASS
mode       [run_mode_test] PASS         introseq   [run_introseq_test] PASS
cel        [run_cel_test] PASS          room       [run_room_test] PASS
anim       [run_anim_test] PASS         walk       [run_walk_test] PASS
```
`[hal-sync] OK -- HAL source aligned with karateka_coco3 (11 files compared…)`

**25.2 bundled-artifact grep:** N/A — harness-only change, no sibling-import artifact.

**25.3 operator-runtime-smoke: N/A this dispatch — no `src/`/`content/` change, nothing new to put
on a screen.** Standing gates unchanged: flash, glass, sand, slump and the feet all **PASSED**
(Jay, live-disk, RGB, 128 KB). **The exit walk skip remains OPEN**; its mechanism is now known and
its source is not.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** I proposed no route in advance. Against §4's list this change contains
**AC1–AC7 in full**. **Named as not-done rather than left absent:** §3D.1's clip test is
*identified and not run* (it needs a source change, and §3/AC4 forbids building in this dispatch);
the oracle's own work-vs-slack split is *named and not measured*, which means §3B's step from the
oracle's rate ratio to a work ratio rests on an inference (a measured one — its intervals vary —
but an inference); and 3D.2 and 3D.3 are enumerated and untouched.

**Reactive deviations (§22.5):** none of substance. Two instrument corrections mid-dispatch, both
in §7. `cad_tab` was not touched, per §3's explicit instruction and P3.85c/d's precedent.

Oracle source read-only and not run. Karateka untouched. `main` untouched. `hal-sync` OK.

### 7 — Uncertainty flags

- **★★ The source of the +13% is not attributed.** The clip fits for a second dispatch and is
  still a fit. **"Last candidate standing" is not proof** — the mirror anchor led for four
  dispatches and was exonerated by measurement.
- **★★ THE SEED'S OWN VERIFICATION WAS BROKEN, AND IT CONDEMNED A SEED THAT HAD LANDED.** The
  read-back latched `seed_landed = false` on *any* frame where `ch_anymove` was non-zero —
  including boot frames **before the engine had ever written it**, when the byte held whatever DECB
  left there. One such frame produced `read-back DISAGREES — the seed did not land` in a run where
  the seed had cut measured work by 38%. **A verification that can fail before the thing it
  verifies exists is not a verification.** Now counted rather than latched, and only once the seed
  has fired. This is the **fourth** seed-mechanics fault in three dispatches (write discarded → no
  baseline → no-op perturbation → verification firing too early), and it is the first where the
  seed was fine and the CHECK was wrong.
- **★ My column sample is contaminated**, the same way P3.101's `bc_keep` was: `ch_col`/`ch_w`
  read at the `room_loop` tap are shared scratch and came back constant (32 / 6). **Nothing in
  this report rests on them** and the printed column should not be quoted.
- **★ `cpu.clock` is nil on this MAME binding**, so this dispatch reports milliseconds and no
  cycles. AC1 asked for cycles; ★ **I did not convert using a remembered 1.79 MHz**, because the
  port sets double speed at runtime and a stated cycle count from an unverified clock is a
  fabricated measurement.
- The oracle is inferred work-bound from its interval variance, not measured. §8.
- Carried, unchanged: the characters' per-iteration draw (which is now also the only route to a
  finer step grid); 0.20 s driver overhead; the `$2310..$2329` blindness; the scene is one page
  from a single load, no freeze; `PlayCut0`'s remaining sound sites stubbed as holds.

### 8 — Follow-up candidates

1. **★ THE DECISIVE CLIP TEST, and it is a seed rather than a better probe.** Rebuild with a
   different `VIS_R` and re-run this measurement. **If the work bump moves with it, the clip is
   attributed; if it does not, the clip is refuted after two dispatches of fitting.** It needs a
   throwaway source change, which is why it is a dispatch of its own rather than a deviation here.
2. **The oracle's own work-vs-slack**, the mirror of §3B. It would replace §3B's inference with a
   measurement and give the port's 2.5% a directly comparable number rather than a rate ratio.
3. **Per-pass cost inside the iteration** (erase / save / draw, per character) — 3D.2, and the
   thing that would say whether the +13% is in the blit at all.
4. Jay's eye on the trade in AC4: **8 frames (no slowdown, 8% fast relative) against 10 frames
   (25% slowdown, 13% slow relative)** — the port has exactly these two options and the closer of
   them is what it already does.

### 9 — User interaction during task

None.

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-16-a-quantised-timebase-cannot-express-a-small-change.md`

Committed and pushed to the pool (fire-and-forget, non-blocking).

### 11 — Commit

See below — pushed to origin/wip before this report.
