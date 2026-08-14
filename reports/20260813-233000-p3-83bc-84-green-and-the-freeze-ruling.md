## Form B Report — P3.83b/c + P3.84 — green on both sizes, and Jay's freeze ruling

**Class:** build. wip. Prod untouched.
**★ BOTH SUITES FULLY GREEN, BOTH MEMORY SIZES — the baseline the re-encode has been waiting
for since P3.79.** Covers the three commits after P3.83's report.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-13T20:03:57-04:00 (P3.83's stamp; this continues it). Now at `22c9e31`, pushed.
POP `main` untouched at `635f986`. Karateka untouched (`wip` `ac2b768`, `main` `5eb92b1`).
`hal_sync_check` OK. `src/` clean.

```
room   8/8 in-emulator, room intact, flames flicker, 78 bytes byte-identical   (128K + 512K)
walk   guard clean, page sigs clean, staged reads clean, beats_visited 18 of 18,
       stability: all captures agree (0), STABLE, PASS                          (128K + 512K)
intro  17/17 PASS
```

---

### 1 — Summary

| | |
|---|---|
| **`db4244a`** | the stale torch comments corrected; **the harness sweep made mechanical** |
| **`b5b79b7`** | the clipped-blast fix — **green** |
| **`22c9e31`** | the drive held across the schedule; **one inference retracted** |

**★ JAY'S RULING ON THE FREEZE:** *"imnot super happy with the time but it is what it is."*
**Accepted at ~2.7–2.9 s per staged read, ~5.6 s total.** This **supersedes** the 1.7 s
accepted at P3.75 §4A, which was costed when a page was thought to be one track.

### 2 — Files modified

- `src/engine/blit_core.s` — the scratch-row path for a clipped blast; the fast path widened.
- `src/engine/cutscene_room.s`, `src/engine/char_draw.s` — the drive held across the
  schedule; the torch-0 comment.
- `src/engine/flame_cels.s` — two stale comments.
- `harness/tools/harness_offsets_check.py` (new), `verify_room_flame_pixels.py`, `build.bat`.
- `harness/tools/bake_scene.py`, `content/cutscene/chars/cel_pages.s` — `CEL_N_READS`.

### 3 — Reasoning

**3A — The clipped blast (P3.83 §3D, built).** `cel_blit_prep` bakes each blast's groups in
the order `blit_blast` consumes them — high destination address first, because `pshs`
descends — so which source byte belongs to which column depends on the segment's **full**
length. A clipped blast is now blasted **in full into a 16-byte scratch row** and the kept
part copied out. Paid only at a screen edge.

Two details that are the whole correctness of it: a **fully off-screen** blast goes through
the same branch rather than being skipped, because `U` must be consumed or the next
segment's opcode is read from the middle of this one's data; and **MERGE needs none of it**,
because its `(mask,src)` pairs are forward-ordered. The two paths look symmetrical and are
not, which is why this took four dispatches.

**3B — ★★ THE HARNESS SWEEP, MECHANICAL AT LAST.** All five stale checkers this project has
found were found **by accident** while chasing something else. `harness_offsets_check.py`
runs on every build as a blocking gate and checks what a checker can be stale *about*:
record layouts read out of engine memory, the position file's field count (writers vs
readers), whether runners still **derive** strides rather than carry literals, and literals
shadowing live symbols.

**It found one immediately:** `verify_room_flame_pixels.py` required `len(f) == 7` while
both writers have emitted 9 fields since P3.71 — so it skipped every position line and the
character-footprint exclusion it guards had been **dead for eleven dispatches**. It never
fired only because nobody happened to stand in front of a torch.

**It is demonstrated to fire:** seeding `walk_test.lua`'s `CH_CEL` back to `3` reproduces
P3.80's exact bug and exits 1. Anything it cannot resolve reports **UNCHECKED**, never pass.

**3C — The drive, and what it actually bought.** Jay: *"are you leaving the motor running
during the scene"* — no; `room_load_cels` released it after startup, so the first staged
read paid `dr_spinup` again. The bundle now holds it across the schedule and releases on the
last read, counting from the pack's `CEL_N_READS`.

```
read 1   3.19 -> 2.85 s      read 2   2.89 -> 2.75 s      total 6.08 -> 5.60 s
```

**★ Read 2 was already warm** — nothing released the drive between the two — so the ~0.4 s
applies once, not twice. A second run gave 2.72 / 2.92: ±0.1 s is seek and rotational
variation.

**★★ AND THE OPTION I OFFERED DOES NOT EXIST.** Hiding the spin-up needs the motor started
early with the flame loop running through it, but `dr_spinup` keys on the driver's own
`dr_motor_on`, **not** on `DSKREG` — *"that is why the flag is the driver's and not the
caller's"* (disk_read.s). Poking `DSKREG` early spins the motor and the driver still burns
the loop. It needs an exported `disk_read_motor_on`: a HAL change and a Karateka back-port
under §2G, a separate gated task. **I described the offer before reading the flag, and Jay
agreed to something that was not available.**

**3D — ★★★ ONE INFERENCE RETRACTED.** Seeing the flip cadence at 3–4 frames against P3.78's
2–3, I attributed ~18,000 cy/frame to the clip's per-segment trim and widened its fast path
to `lead == 0 and keep >= width`. **The cadence did not move.** The comparison was never
like-for-like: P3.78's histogram came from a build where the scene **stalled early**, so it
sampled two standing characters, while this one plays Vraise/Pback/Vexit/Pslump. **The
trim's cost is UNMEASURED, not 0.6 frames.** The wider fast path is kept because it is
correct and strictly cheaper, not because it bought anything measurable.

### 4 — Verification

**25.1 fresh tool output (at `22c9e31`):** the suite results in §0, all four runs (room and
walk × 128 KB and 512 KB), `intro 17/17`, `hal_sync_check OK`, `[harness-offsets] all
checked offsets agree with the build`, `[sequences] … 9 sequences`, `ok cel_plan 19 rows`,
`ok cel_page_tab 5 rows`. Freeze figures from `read_cost.lua`, two independent runs.

**25.2:** N/A. **25.3: NOT OFFERED, and now worth offering** — the scene runs to its end
with every check green. That is the next thing to put in front of Jay.

### 5 — Acceptance criteria (P3.83's)

1. Two bytes attributed by split and fixed — **yes** (P3.83).
2. Stale flame comments corrected — **yes**. ★ One correction to P3.83's own report: it said
   "neither comment is right" of a pair; **the room's was right.** Only `flame_cels.s` was
   stale, plus two others the report had not found.
3. Two missing beats found on the machine; 18 of 18 — **yes**, and the fault was the checker.
4. Harness offsets swept — **yes** (§3B).
5. Both suites green both sizes — **yes.**
6. Re-encode landed — **no.** Green was reached at the end of this work; the re-encode is
   next and is now unblocked.
7. Verified by symbol from a freshly baked image — **yes**; `bake_scene` re-run before the
   build that produced these results.
8. Jay gates live — **not offered yet** (§4).
9. Route accounting; sync bridge; Karateka and `main` untouched — yes.

### 6 — Reactive deviations and route accounting

**Contains:** P3.83 §2 (comments), §3 (beats + sweep), the §3D clipped-blast fix, and an
unrequested drive change Jay asked for directly. **Does not contain:** the re-encode, the
grouping look, the turn-to-exit disappearance, the hourglass and flash, the live gate.

**One deviation:** the drive work (§3C) was not in the dispatch — Jay asked for it in
conversation and it is recorded here rather than smuggled into another section.

### 7 — Uncertainty flags

- **★ The trim's frame cost is unmeasured** (§3D). If it matters, the measurement is a
  like-for-like histogram over the same beats with and without the clip.
- **★ The freeze figures vary ±0.1 s run to run** (seek and rotational latency). Quote
  ~2.7–2.9 s, not a precise number.
- **Hiding the remaining spin-up is blocked on a HAL task** (§3C), ~0.4 s.
- ROOM.BIN has **6 bytes** of headroom under the LOADM ceiling.
- Carried: the turn-to-exit disappearance; the hourglass and flash unbuilt; 0.20 s per-call
  driver overhead; the `$2310..$2329` read-tap blindness; `PlayCut0`'s remaining sound sites.

### 8 — Follow-up candidates

1. **Offer the live gate** — the scene now completes with everything green.
2. **The re-encode**, against the green baseline: 38,424 → 28,101 B predicted, 5 pages → 4,
   3 loads → 2, **which removes one freeze entirely: ~5.6 s → ~2.8 s.** Measure, do not
   quote. Then one look at the grouping — the scene is one page from needing no staged read
   at all.
3. The turn-to-exit disappearance; the hourglass and flash.
4. The HAL motor task, if the last ~0.4 s is worth a back-port.

### 9 — User interaction during task

Jay asked whether the motor is left running (§3C) and, on the measured result, ruled:
*"imnot super happy with the time but it is what it is."* **Recorded as acceptance of
~5.6 s, superseding P3.75 §4A's 1.7 s.**

### 10 — Candidate(s) captured this task

None new. §3C and §3D are both instances of *proposing before checking* — one offered a
mechanism without reading the flag it depends on, the other attributed a cost from two
histograms that were not comparable. Closest existing row is
`2026-08-12-the-symptoms-shape-can-mislead-too`; better strengthened at reconcile time than
duplicated, on the P3.76 §9 precedent.

### 11 — Commits

`db4244a`, `b5b79b7`, `22c9e31` — pushed to origin/wip before this report.

---

### 12 — 25.3 GATE — OBSERVED BY JAY (recorded after the report above)

**Launch path: `live-disk`** — `run_room_live.sh`, real `LOADM"ROOM"` + `EXEC` off a mounted
floppy, **RGB**, 512 KB, normal speed. 78 seconds observed, which reaches the end of the
scene. Not a poke, not a still.

**Jay's words, verbatim: "looks fine."**

**What was under gate**, and none of it had been seen before: `Vraise` -> `Pback` ->
`Vexit` -> `Pslump`; the exit clipping at the right edge (the fault that took four
dispatches); and the two staged reads as they land in the scene.

**MOTION-BEARING AND GATED LIVE** — the scene is animation throughout and this was a running
machine, so it satisfies CLAUDE.md §4's requirement that motion is not gated on a still.

**Not self-certified**, and deliberately not inflated: *"looks fine"* is a pass, not
enthusiasm. The freeze duration was ruled on separately (§1, §9) and is accepted rather than
liked.

**Still absent from the gated scene** and known: the hourglass and its lightning flash, the
`s_Magic` hold between `Pback` and `Vexit`, `addglass1` state 1, `s_StTimer`, the 16-colour
swap and the `Prolog2` handoff.
