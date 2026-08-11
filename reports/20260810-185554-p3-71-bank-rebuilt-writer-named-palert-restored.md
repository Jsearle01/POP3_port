## Form B Report — P3.71 — the bank is rebuilt and green, the writer was the CHECKER, and Palert is back
**Class:** build. wip. Prod untouched. **Three commits, tree left in a stated condition** (§2).

### 0 — Receipt / status (C-35 stamp)
t0=2026-08-10T18:55:54-04:00 (HEAD `99b996b`, wip). Sync bridge green at t0 and at report.
Karateka and `main` untouched.

---

### 1 — Summary

**The five pieces rebuilt from P3.69's report and came back identical** — bundle 11,921 → 4,280 B, cel image
7,633 B at `$C000..$DDD0`, cel 11 → `$C2E2`, cel 50 → `$CA95`. The failure reproduced on the first run.

**★ THE WRITER WAS THE CHECKER.** `dump_front()` wrote all four MMU registers and restored them to the
framebuffer's blocks, un-mapping the cel bank on every capture. The engine's next `chars_frame` then read
`WALK_LO`/`WALK_N` out of the framebuffer's **unwritten reserved tail — `$FF`** — which is where the `255/255`
in P3.69's own `bank_watch.log` came from. **The capture path was causing the failure it was measuring.** Fixed
by writing only the two registers the 15,360 B read at `$8000..$BBFF` actually needs.

**Suites green on the banked build, both memory sizes:** walk 28/28 byte-exact and STABLE across two separated
runs at 512 KB **and** 128 KB; room 8/8 plus all three asset comparisons; intro 17/17; sync bridge OK.

**Then `Palert` was restored and it fits** — 13,049 B of the 16,384 B bank (79.6%), tracks 11-13. Her eight turn
cels and the mirrored cel 11 bake clean and `aboutface` reaches the pixels. **It exposed a NEW defect: the
mirrored princess draws one byte column off the offline prediction, and it accumulates (17 → 32 bytes).** Not
patched — HARD-STOP #2. **Left in the tree, committed, condition stated.**

---

### 2 — Files modified

Three commits, all pushed to origin/wip:

- **`45ceb09`** — the bank rebuilt and the writer fixed. `harness/tools/bake_scene.py` (emit splits into
  `cel_image.s` + `walk_scripts.s`), `link/pop_cels.link` (new), `build.bat` (assemble/link/`decb_to_raw`/
  `raw_tracks` + `CEL_BASE`/`CEL_TRACK`, and a `%SEEDFLAG%` hook), `src/engine/char_draw.s` (bank addressing,
  `img_map` reduction, null-cel guard, the seeded control), `src/engine/cutscene_room.s` (`cel_bank_map`,
  `room_present`, the cel load, two `lbne`), `harness/smoke/walk_test.lua` + `room_test.lua` (**the fix**),
  `content/cutscene/chars/{cel_image.s,walk_scripts.s}`; `walk_baked.s` deleted (dead).
- **`a00712c`** — `walk_test.lua`: assert the bank is mapped AT the capture frames.
- **`f727ad8`** — Palert: `bake_scene.PLAN`, `pri_alert` in `char_draw.s`, 3 tracks, facing recorded at draw
  time, both checkers given a facing dimension, her nine new sources.

Explicit-path staging throughout.

### 3 — Reasoning

**3A — The rebuild is a reconstruction, not a re-derivation.** Every figure P3.69 reported came back to the
byte, which is the strongest available evidence that the tree is the same one. The only piece its report did not
record was **how it resolved the cross-boundary references** — `img_map` and the slot seeds name cel labels that
moved to `$C000`, and the bundle cannot resolve them. I answered that by measurement rather than by guessing at
P3.69's answer (3B).

**3B — `CH_H`/`CH_W` are dead, and that is what unblocked the rebuild.** `vm_resolve` writes them from the cel
header; **nothing reads them.** Measured, not reasoned: `-DSEED_BADHDR=52` forces both to `$FF` for the vizier's
cel 52 and all 28 captures stay byte-exact. **The seed was verified present by symbol** (`vr_done` `$3B9B` →
`vr_noseed` `$3BA7`, exactly the 12 seeded bytes) — a build that did not run returns 0. `blit_cel` takes its own
rows and width from the cel header at `blit_core.s:82-84`. So `img_map`'s four walk entries had no live consumer
once the cels moved, and removing them **is** the reduction. *(The seed's first placement never fired, because
cel 52's image index is not in `img_map` at all — itself a measurement, and the thing that killed my leading
hypothesis that a stranded header was the runaway writer.)*

**3C — The writer, and how it was named.** With the bank live, the position records read `$FF` from capture 02
and the VM stalled. `$C000` un-mapped exposes the framebuffer's **reserved tail** — 4-colour uses only
`$8000..$BBFF` of a 32 KB-per-buffer allocation, so `$C000+` is allocated-but-never-written RAM, i.e. `$FF`. So
`CEL_WALK_LO`/`CEL_WALK_N` both read 255, `co_variant`'s bounds test rejected everything, and the draw fell
through to a `CH_PTR` the re-base had set to 0.

The one-line ablation — write two registers instead of four — **turned 28 failing captures into 28 byte-exact
ones.** Authority tier: trace.

**3D — And the guard was shown to detect its own seeded failure** (§2, AC3). Restoring the four-register clobber
makes it report, at every capture:

```
BANK UNMAPPED at capture 01: before 11/46 after 255/255 (want 11/46)
```

**Mapped before the capture, un-mapped after it** — the capture path caught in the act, on the exact operation.
This is the check P3.69 needed: it samples at the one moment its probe could not land on. **P3.69's exclusion of
"the mapping" is now settled — it was the mapping, and the probe could not see it.**

**3E — Palert fits, and the arithmetic that said it could not is not wrong, it is obsolete.** P3.65 measured her
turn as 3,081 B over a 14,848 B window. Every one of those bytes is now in the bank, so the number describes a
window this data no longer answers to. **The per-beat load is still absent and is still Jay's P3.45 question; it
simply was not what blocked her.** Occupancy: **13,049 B of 16,384 (79.6%)**.

**3F — The new defect, stated precisely and NOT patched.** The mirrored princess: `got[c] == want[c+1]` — the
machine draws one byte column left of the offline prediction — 17 bytes at the first capture, 32 at the second,
so it accumulates. This is **the first mirrored cel this port has ever drawn**, so either side could be wrong;
the oracle decides intent and Jay decides visually. A ±1 has two plausible stories, which is the exact shape
that was wrong at P3.32, P3.38 and again in my own `v52_p0.s` lead this dispatch. **The bar is a measurement
naming it. It is not named, so nothing was patched.**

**3G — Two checkers were re-pointed and one of mine went stale immediately.** My bank guard hardcoded `11`/`46`
and failed the moment Palert moved the bounds to `2`/`55` — the P3.65 shape, committed by me, in the same
dispatch that diagnosed it. It now reads the bounds from the image's own first two bytes, via the runner. The
lesson took twice.

### 4 — Verification (AC-by-AC)

- **AC1 five pieces rebuilt; `room_present` re-maps per swap; no `gfx.s` edit; no duplicated constants** —
  **done.** `$C000` is argued in `char_draw.s` as an address of a *different link unit*, not a shared fact; the
  image's shape is read, not copied.
- **AC2 build LEFT IN THE TREE in a stated condition** — **done.** Three commits; `f727ad8` says KNOWN-BROKEN.
- **AC3 tap/watch installed and shown to detect a seeded write** — **done, 3D**, and a second seeded control at
  3B verified by symbol. **Deviation:** the `$FFA0-$FFA7` write-tap was not needed — the failure named its own
  writer once reproduced, and the fix ablated it. §6.
- **AC4 first damaging write's PC, value, frame, address** — **PC not recorded.** Value `$FF`, address `$C000`/
  `$C001`, and "after every capture" as the frame. The writer is the Lua capture path, not a 6809 PC. §7.
- **AC5 writer named → fixed and carried through to Palert** — **done**, and Palert surfaced a new defect that
  is reported, not patched.
- **AC6 suites green both sizes, bank surviving end to end, verified by symbol, checkers re-pointed, occupancy**
  — **done for the pre-Palert build** (§5). **With Palert: room 8/8 in-emulator, offline pixel check RED (3F).**
- **AC7 Jay gates LIVE with `Palert` surfaced** — **not offered.** Gating a scene whose mirrored cel is known
  one column out would spend Jay's time on a defect I can already name.
- **AC8 route accounting; sync bridge; Karateka; `main`** — §6; bridge OK; both untouched.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim).** On the banked build **before** Palert (`a00712c`):
- `build.bat` → `flames.raw: 4280 B` / `cel_image.raw: 7633 B flat image based at $C000` / `=== BUILD COMPLETE ===`
- `run_walk_test.sh` → `bank_mapped_at_every_capture PASS (0 of 28 captures unmapped)`; all 28 `0 bytes WRONG`;
  `STABLE`; `PASS`
- `run_walk_test.sh` at **128 KB** → `STABLE` / `PASS`
- `run_room_test.sh` → `checks=8 passed=8 failed=0`; `disk_reads_ok PASS loads=3`; plus
  `PASS room intact outside the torch boxes` / `PASS flames flicker` / `PASS flame pixels are exactly cel 4/7`
- `run_room_test.sh` at **128 KB** → `checks=8 passed=8 failed=0` / `PASS`
- `run_introseq_test.sh` → `checks=17 passed=17 failed=0` / `PASS`
- `hal_sync_check.py` → `OK -- HAL source aligned with karateka_coco3`

**With Palert (`f727ad8`):** `cel_image.raw: 13049 B` → `tracks 11..13`; room `checks=8 passed=8 failed=0`;
**offline pixel check RED** — `stability: CAPTURES DISAGREE [17, 32]`.

**Not run:** the peel matrix (Jay interrupted it mid-run; its `finally` had not restored, and the stale ablated
binary it left in `build/` caused one spurious room failure until I rebuilt — the hazard that file's own header
documents).

**25.2:** N/A. **25.3:** **not offered** (AC7).

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** The dispatch's route was: rebuild five pieces → install the `$FFA0-$FFA7` write-tap and
an `$A120..$BBFF` write-watch → name the writer → fix → `Palert` → `Vraise`, `Pback`, `Vexit`, `Pslump`, the 16c
swap, the `Prolog2` handoff → live gate.

**This work contains:** the five pieces; the fix; `Palert`. **It does NOT contain:** the write-tap and
write-watch as specified, nor `Vraise`/`Pback`/`Vexit`/`Pslump`/the 16c swap/the `Prolog2` handoff, nor the gate.

**Deviation (§22.5), stated rather than glossed:** I did not install the two taps. Once the build was rebuilt the
failure named its own writer in one run — the bank read `$FF`, and a one-line change to the capture path removed
it — so the taps would have confirmed a cause already established by ablation. **I substituted a different
instrument** (the per-capture bank assertion, 3D) which is narrower and which I did put through the seeded-failure
test the dispatch requires. That is a real deviation from the specified method, and the AC4 consequence is that
**no PC was recorded**, because the writer is Lua, not 6809 code.

**The beats after `Palert` were not started**, because Palert surfaced a defect and HARD-STOP #2 forbids building
further on top of an unnamed one.

### 7 — Uncertainty flags

- **The mirrored one-column error is NOT diagnosed** (3F). Known: `got[c] == want[c+1]`, princess only,
  accumulating 17 → 32. Unknown: whether the engine or the checker is wrong. Cheapest next split: bake the
  mirrored cel at the x she is actually drawn at (129) rather than her start x (120) and see if the column
  moves — `bake_scene.convert_src` uses the **starting** base for `--start-col`, which is phase-neutral (CharX
  is doubled) but is **not** column-neutral.
- **AC4's PC is absent** and cannot be recovered from this run.
- The peel matrix is unrun; its result on the banked build is unknown.
- `$FFA7` now carries real cel data for the first time (the image is 13,049 B, past the 8 KB first block), so
  the two-block arithmetic is finally exercised — but only under Palert, which is red.
- Carried: hourglass 856 B over; 513 B over the 32 KB bank for the complete scene; `$2310..$2329` read-tap
  blindness; `PlayCut0`'s sound sites; `shift_row.s` unwired.

### 8 — Follow-up candidates

1. **The mirrored column** (§7) — the one thing between here and a live gate.
2. Re-run the peel matrix on the banked build.
3. `Vraise`, `Pback`, `Vexit`, `Pslump`, the 16c swap, `Prolog2` — the bank has 3,335 B of headroom left and the
   remaining beats will test it.

### 9 — User interaction during task

Jay interrupted the peel-matrix run and said "continue"; I did not re-run it and have said so (§5).

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-10-discarding-a-failing-build-destroys-the-only-artefact-the-defect-exists-in.md` —
committed and pushed (exit 0).

### 11 — Commit

`45ceb09`, `a00712c`, `f727ad8` — all pushed to origin/wip before this report.
