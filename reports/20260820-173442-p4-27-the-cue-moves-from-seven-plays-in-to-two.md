## Form B Report — P4.27 — the cue moves from **seven plays in to two**

**Class:** build.  wip.  Prod changed — `content/cutscene/chars/cel_plan.s` (the beat schedule) and
`cel_pack.json`; `cel_pg0-3.s` one comment line each. **`cel_pages.s` UNCHANGED — no disk track moved.**
Karateka untouched; `main` untouched (`34e93e0`); oracle source read-only.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-20 17:34 (HEAD `84a84ad` at receipt, wip; `2c8c101` at report). Tree clean apart from the modified
`dist/mame-cfg/rgb/coco3.cfg` carried since P4.19 and the pre-existing untracked files.

### 1 — Summary

| | |
|---|---|
| **the edit** | the opening `Pstand` split into **three PLAN rows**, not two (§3A) |
| **★★★ reveal → cue** | **45 frames (0.75 s) → 15 frames (0.25 s).** Oracle: 10 |
| **`s_Princess` vs oracle** | **+0.9 s → +0.4 s** |
| **every downstream cue** | **UNCHANGED, at the same absolute frames** — the index shift proved harmless by measurement (§3C) |
| **the princess's animation** | **unchanged** — 116 plays to `Palert` either way, and the cue frames confirm it (§3D) |
| **suites** | **ALL PASS, 128 KB, `integ` included** |
| **★★ deviation from §1** | the dispatch's two-row form **drops the 761-frame song hold — 12.7 s out of the scene** (§3B) |
| **Jay's gate** | **OFFERED, run launched. PENDING JAY.** |

**★★★ THREE DISPATCHES AIMED AT THE LOADING PATH AND THE ANIMATION VM; THE FIX WAS FIVE PLAYS IN A DATA
ROW.** The row's own comment had described the correct structure the whole time.

### 2 — Files modified

- `harness/tools/bake_scene.py` — the PLAN's opening split into three rows; `SCENERY` keys **+1**.
- `content/cutscene/chars/cel_plan.s` — regenerated: beat 0 `Pstand plays 2`, beat 1 `s_Princess`, beat 2
  the 5-play hold, beat 3 `Palert`.
- `content/cutscene/chars/cel_pack.json` — regenerated; the derived read point followed on its own,
  `at_beat 10 → 11`.
- `content/cutscene/chars/cel_pg0-3.s` — **one comment line each** (verified: no non-comment line changed).

### 3 — Reasoning

#### 3A — the split, and why it is three rows

The oracle [`SUBS.S:658-672`]:
```
 lda #2 / jsr play          ; TWO plays
 lda #s_Princess / ldx #8 / jsr PlaySongI
 lda #5 / jsr play          ; then FIVE more
```
The PLAN now says the same thing:
```python
("p", "Pstand", 2),            # play 2 [SUBS.S:665-668]
("song", "s_Princess", 761),   # ★ THE CUE, HERE [SUBS.S:669-671]
("-", "", 5),                  # play 5 — she waits, no re-jump [SUBS.S:672]
```

**★★ THE TRAILING FIVE ARE A `"-"` ROW, NOT A SECOND `Pstand`.** `"-"` is play-without-jumping, and the
oracle does **not** call `pjumpseq` before that `play 5` — she is already standing. A second `Pstand` row
would emit a jumpseq and **restart her pose**, which is the P4.25b-2 failure wearing different clothes: a
change that is invisible in every number and visible to Jay's eye. ★ *The PLAN already uses `("-", "", 5)`
for exactly this pattern on the next row.*

#### 3B — ★★ WHERE THIS DEPARTS FROM THE DISPATCH, AND WHY

**§1 specified:** *"Beat 1 becomes: `Pstand`, 5 plays, song byte `s_Princess`."* That is **two** rows, and it
has no home for the existing `("song", "s_Princess", 761)` row — **761 frames is 12.7 s, and dropping it
removes the whole song hold from the scene.**

**The 761 already excludes these seven plays**, which is the fact that makes three rows correct and two
rows lossy. `bake_scene.py`'s own trace note:

> `s_Princess  room arrives f2688 -> her turn starts f3487 = 799 frames, of which play 2 + play 5 at the
> measured 5.38 f/play is ~38 -> 761 frames`

So the hold stays where it is and **only the cue moves.** Scene length is unchanged, and §3C's identical
downstream frames are the check on that rather than the argument for it.

★ *This is P4.26b §7's flagged question — "whether the trailing `play 5` is already absorbed into that hold
decides whether the edit is one line or three" — answered by reading the derivation instead of guessing.*

#### 3C — ★★★ THE INDEX SHIFT, CHECKED TWICE

HARD-STOP 2: *"every beat reference is by index, so a shift that misses one produces a wrong beat, not an
error."* **Two independent checks, and they agree:**

1. **Static.** `SCENERY`'s keys are PLAN positions **asserted against the beat NAMES**, so a missed shift
   fails the build naming the beat it found. Keys went 13-18 → 14-19; the build passes. The read points are
   **derived** (`PLAN[bi][0] == "song"`), so they followed on their own — `cel_pack.json` `at_beat 10 → 11`,
   and the packer's own search still places every read in a hold of ≥ 40 plays.
2. **★★ Dynamic, and this is the one that actually proves it.** Every downstream cue fires on the **same
   absolute frame** as before the edit:

| cue | before | after |
|---|---|---|
| `s_Vizier` | 6358 | **6359** |
| `s_Buildup` | 6951 | **6953** |
| `s_Magic` | 7624 | **7629** |

★ *If any consumer had missed the shift, a beat downstream would be running the wrong row and these would
not be within a handful of frames of each other.*

#### 3D — the princess's animation (AC4), by construction **and** by measurement

**Construction:** plays before `Palert` are `2 + 109 + 5 = 116`; they were `7 + 109 = 116`. **Identical.**
The sequence is `Pstand` throughout with no re-jump (§3A), so nothing about what beat 0 *does* changed —
only how many plays elapse before the cue.

**Measurement:** §3C's downstream frames. `s_Vizier` is six beats later and gated by accumulated play
counts; an animation-cadence change of even one step would have moved it by ~6 frames, as P4.25b-2's did.
It moved by 1.

#### 3E — §2H's three checks

1. **A second mechanism?** ★ **Yes, and it is the residual.** Two things set the cue's position: **which row
   carries it** (fixed here) and **`cad_tab`'s frames-per-play** (6, against the oracle's measured 5.0).
   Position was 35 frames of the error; rate is the remaining ~5.
2. **The calling routine.** The cue is emitted by `song_at(bi)` — correct code — whose caller is the PLAN
   walk. **The fact lives in the tuple, not the function.**
3. **Prior-report grep** (`PLAN|Pstand|SCENERY|song_at`): P3.78, P3.85, P4.23, P4.26, P4.26b. No
   contradiction found this time; P4.26b's finding is the basis and it held.

### 4 — Verification (AC-by-AC)

- **AC1 beat 0 split to match `play 2` → cue → `play 5`** — **PASS (§3A)**, as three rows, with §3B's reason
  for departing from §1's two.
- **AC2 arm → cue measured against the oracle's 10 frames** — **PASS. 15 frames (0.25 s)**, from 45.
- **AC3 all cue timings re-reported** — **PASS** (§5).
- **AC4 princess animation unchanged** — **PASS**, by construction and by measurement (§3D).
- **AC5 suites green 128 KB first, `integ` included** — **PASS.** ★ *512 KB not run and the reason is
  stated: this touches neither the MMU, the bank, the framebuffers nor the loader (§2K names those as what
  makes the confirmation informative).*
- **AC6 Jay gates by ear and eye** — **OFFERED; PENDING JAY** (§5).
- **AC7 route accounting; Karateka untouched; `main` untouched** — **PASS** (§6).

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output, verbatim.**

```
[suites] -ramsize 128K
[run_introseq_test] PASS
[integ] PASS
[suites] ALL PASS
```
```
  reveal   frame 5436
  cue      frame 5451   (song id 7)
  delta    15 frames = +0.25 s
```
```
# song           frame       port     oracle      delta
  s_Princess      5451       0.6s       0.2s      +0.4s
  s_Vizier        6359      15.7s      16.7s      -1.0s
  s_Buildup       6953      25.6s      26.3s      -0.7s
  s_Magic         7629      36.9s      34.9s      +2.0s
```
```
  pg0    7292 B    pg1    6451 B    pg2    5674 B    pg3    6526 B      (all byte-identical to before)
# VERDICT: PASS - every file on the image matches its artefact.
=== BUILD COMPLETE ===
```
The regenerated schedule:
```
                fcb     0,0,0           ; beat 0  Pstand       plays 2     pinned-only
                fcb     0,0,7           ; beat 1  s_Princess   plays 109   pinned-only
                fcb     0,0,0           ; beat 2  (hold)       plays 5     pinned-only
                fcb     0,0,0           ; beat 3  Palert       plays 9
```

**25.3 operator-runtime-smoke: PENDING JAY — live-disk, RGB, 128 KB, `run_introseq_live.sh`, by EAR and
EYE.** The run was launched and completed at real speed; **a completed run is not a verdict and is not
recorded as one.** Not self-certified. The last recorded operator verdict remains the FAIL on `fe9b594`.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING. This commit contains** the three-row split, the `SCENERY` +1, the regenerated content,
and the measurements. **It contains no engine-source change at all** — `src/` was not touched.

**★★ ONE DEVIATION FROM THE DISPATCH'S SPEC, STATED RATHER THAN ABSORBED (§3B):** §1 specified a two-row
form that drops the 761-frame song hold. I built three rows. **The dispatch's own §5.4 says ask in place
rather than reverting; this is the same principle applied forward** — the specified shape would have removed
12.7 s from the scene, and the reason it looked right is that P4.26b left the question open.

**★ AND ONE THING I DID NOT DO:** the remaining 5-frame difference from the oracle (15 vs 10) is the step
rate — `cad_tab` 6 against the oracle's measured 5.0 — and **that is P3.87's ground, closed by Jay's
decision.** Not touched, and not proposed as a fix.

### 7 — Uncertainty flags

- **The oracle's 5.0 f/play is still from ONE interval** (2 plays, 10 frames), carried from P4.26b. It is
  enough to attribute the ~5-frame residual to rate rather than position; it is **not** a re-measurement of
  the pace.
- **`s_Magic` at +2.0 s is the largest remaining cue error** and is untouched by this change. **It may be the
  same class of defect** — a merged or mis-placed PLAN row — and §8 carries the check.
- **`vm_nextframe`'s comment still says "the 3,3,2,3,2 cycle"** against a flat-6 `cad_tab` (carried, P4.26 §7
  — Orchestrator's text, §2D).
- **The 512 KB confirmation was not run**, deliberately (§4 AC5).

### 8 — Follow-up candidates

- **★★ CHECK THE OTHER CUES FOR THE SAME MERGE, which P4.26b §8 raised and this dispatch did not cover.**
  `s_Vizier` **−1.0 s** and `s_Buildup` **−0.7 s** are *early* — the opposite sign — and `s_Magic` **+2.0 s**
  is the largest error left. **One grep of `SUBS.S` per cue**, exactly as this one was found.
- **Re-offer 25.3** if the gate below does not settle it.
- Carried: the 6-byte headroom to `SCENE_BASE`; the disk's 18-of-18 granules; pinning the `LOADM` ceiling;
  gameplay's colour mode; the per-cue control policy; the HAL audit; the stale `pop.link` stack comment;
  `Demo` unbuilt.

### 9 — User interaction during task

- Jay: ***"do the recon"*** (P4.26b) produced the finding this dispatch implements.
- The live gate was launched at the end of this task and completed; **no verdict given yet.**

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-20-escalating-fixes-are-evidence-the-layer-is-wrong.md` — committed and pushed.

### 11 — Commit

`2c8c101` (pushed to origin/wip before this report) + this report.
