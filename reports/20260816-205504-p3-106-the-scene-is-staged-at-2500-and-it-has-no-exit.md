## Form B Report — P3.106 — the scene is staged at `$2500`, and it has no exit

**Class:** build (staging) + recon. wip. **Prod CHANGED — deliberately:** the disk gains
`scene_prog.raw` on track 24. `ROOM.BIN`, `INTROSEQ.BIN` and every content byte are unchanged.

**★★★ AC1 IS DONE AND GREEN. The scene's program is linked at `$2500`, its kernel segment is
dropped under an assertion, and it is on the disk as a driver-readable track. The intro-only
LOADM image is `$2000..$2432` — under the measured ceiling.**

**★★★ AND THE CALL SITE IS BLOCKED ON SOMETHING NEITHER P3.104 NOR P3.105 SAW, WHICH I FOUND BY
TRYING TO BUILD IT: `room_loop` IS AN UNCONDITIONAL `bra room_loop`. THE SCENE NEVER RETURNS.**
A call between beats 4 and 5 needs the scene to end and `rts`; it currently holds its last beat
forever. **That is a control-flow change to the scene, and the scene's gate is two dispatches
old — so it is a change that needs its own gate, not a line added at the end of a merge.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-16T20:55:04-04:00 (HEAD `91fa731`, wip). Karateka untouched. `main` untouched. Oracle
read-only and not run. Pre-existing and not mine: `dist/mame-cfg/rgb/coco3.cfg`.

---

### 1 — Summary

| | |
|---|---|
| **★★★ AC1 DONE** | scene linked `$2500..$297A`, raw **1,147 B**, on **track 24**; intro image **`$2000..$2432`** |
| **★★ the kernel drop is asserted** | `[kernel-identical] OK — $7900 is byte-identical in both images (1092 B)` |
| **★★★ BLOCKER FOUND** | **`room_loop` never exits.** The scene cannot be called and returned from |
| **★ P3.104's map corrected** | **track 17 is the RS-DOS DIRECTORY track** — free of assets is not free |
| **not done** | AC2 (reload), AC3 (assert), AC4 (read-before-reveal), AC5 (merge + suites), AC6, AC9 |
| **stated** | `SetupDHires`/`Prolog2` absent, not built |
| **green** | `introseq`, `room`, `walk` at 128 KB; `hal-sync` OK |

### 2 — Files modified

- `link/pop_scene.link` — NEW; the scene at `$2500`, with the staging argument
- `harness/tools/kernel_identical_check.py` — NEW; asserts the dropped kernel is the resident one
- `harness/tools/decb_to_raw.py` — `--span-end`, to drop segments at/above an address and say so
- `build.bat` — links `scene_prog.bin`, asserts, extracts, writes track 24
- `reports/20260816-205504-…md` — this

(explicit-path staging only)

### 3 — Reasoning

**3A — ★★★ AC1: THE SCENE, STAGED PAST THE HANDOVER. Green, and the numbers are the design's.**

```
  --- Link: the scene, STAGED PAST THE LOADM HANDOVER (P3.106) ---
    build/scene_prog.bin (2254 bytes)
  [kernel-identical] OK — $7900 is byte-identical in both images (1092 B).
    DROPPED seg $7900..$7D43 (1092 B) — at or above --span-end $7900
  build/assets/scene_prog.raw: 1147 B flat image based at $2500
  build/assets/scene_prog.raw: 1147 B -> build/probe.dmk tracks 24..24 (18 sectors, 3461 B pad)
  === BUILD COMPLETE ===
```

**1,147 B is exactly `$47B`** — `cutscene_room $03ED + lz_unpack $008E` — the figure P3.105
predicted from the maps. The image lands `$2500..$297A`, clearing the intro's code by 205 B and
`$3000` by more than `$600`.

★★ **Jay's reframing is the mechanism and it is written into the link script**: `LOADM` is a
BASIC command and BASIC is gone once the port has control, so the ceiling binds on what is
resident **at the handover**. `$2500` is above the ceiling and that is the point — nothing
`LOADM`s it.

**★ THE KERNEL SEGMENT IS DROPPED UNDER AN ASSERTION, NOT UNDER A COMMENT.** The scene must link
with `hal_build.o` (lwasm's object mode makes `HAL_sys_init` and friends externals
automatically), but the kernel is already resident at `$7900` — and `decb_to_raw` **fills gaps
between segments**, so without the drop the raw image would span `$2500..$7D43`: 21 KB of mostly
padding, and a track read that overwrites the kernel *while the kernel is executing the read*.
The two kernels are identical by construction; `kernel_identical_check.py` proves it against the
artefacts each build, because **"by construction" is the exact shape of assumption this project
has been bitten by four times.**

**3B — ★★★ THE BLOCKER: THE SCENE HAS NO EXIT.**

`room_loop` ends `bra room_loop` — twice, on both its arms
[`cutscene_room.s:470`, `:536`]. There is no terminal test anywhere in it, and
`vm_beat_tick` walks the plan cursor by `PLAN_STRIDE` with no bound against `cel_plan_end`
[`char_draw.s:2071-2085`]. **The scene runs its last beat and then holds it forever, which is
exactly right for a standalone demo and exactly wrong for a subroutine.**

★★ **This is not a layout conflict and I am not calling a hard-stop on it.** It is a missing
mechanism, and it is squarely inside the merge's scope. What it is *not* is a line added at the
end of a build: the scene must

1. detect that the schedule is exhausted (`vm_beat` reaching `cel_plan_end`),
2. publish that to `room_loop`, and
3. leave `room_loop` by `rts` rather than `bra`,

and (3) changes what the scene *does at its end* — today it holds, and it would then leave.
★★★ **The scene's visual gate is two dispatches old and was earned on a scene that holds.
Changing its ending changes the thing under gate**, so it needs Jay's eye on the new ending, not
a green suite. The suites cannot see it at all: none of them runs past the last beat.

★ **I found this by trying to write the call site**, not by reading the source — which is
P3.104's *"a clean link and a successful boot are not the check"* one level earlier: the design
was sound and the thing it called did not have the shape a call requires.

**3C — ★ P3.104's TRACK MAP WAS WRONG, AND THE TOOL CAUGHT IT.**

P3.104 reported *"tracks 17 and 24 are free"*. Track 17 carries no asset — **because it is the
RS-DOS directory track.** `raw_tracks.py` refused it outright:

```
  tracks 17..17 cross the directory track 17 — that is silent corruption, pick another span
```

**"Free of assets" and "free" are different questions and only the first was asked.** The map was
built from the asset allocation, which cannot see the filesystem's own reservation. Track 24 is
genuinely free and is what shipped. ★ The correction is recorded in `build.bat` beside the write,
where the next person choosing a track will be, rather than only here.

**3D — §2H's THREE CHECKS.**

1. **A second mechanism for a different object class?** Yes, and it is §3B: the scene has two
   loop arms (`rl_draw` and the idle path), and **both** end `bra room_loop`. A terminal test
   added to one would leave the other holding forever — a scene that returns only when the torch
   happens to be due.
2. **The calling routine.** The blocker is not in `room_loop` but in what owns the plan cursor:
   `vm_beat_tick` advances it and nothing bounds it. Fixing the loop without bounding the cursor
   would make the scene return at a moment decided by garbage past `cel_plan_end`.
3. **Grep the reports.** P3.103's live runner banner says *"IT RUNS TO THE END NOW … the scene
   reaches its last beat"* — true, and it says nothing about what happens after, because until
   this dispatch nothing needed to.

### 4 — Verification (AC-by-AC)

- **AC1 — scene read by the driver at `$2500`; intro-only image under the MEASURED ceiling,
  sizes reported.** ★ **DONE.** §3A. `$2000..$2432` against `$2488..$2535`, with `$56..$103` to
  spare; the staged image `$2500..$297A` on track 24.
- **AC2 — captions displaced and reloaded before beat 5.** ★ **NOT DONE** — blocked by §3B.
- **AC3 — the `BEAT_PATCH = 0` dependency recorded at the beats.** ★ **NOT DONE.** It belongs
  beside the call site so a future editor hits it there, and the call site does not exist. **The
  dependency itself is unchanged and remains recorded in P3.105 §3A.**
- **AC4 — the return read verified to land unseen, as a measurement.** ★ **NOT DONE** — there is
  no return read yet.
- **AC5 — the merge; the scene's suites against the integrated build.** ★ **NOT DONE.** ★★ And a
  gap worth naming now: **the scene's suites launch it with `LOADM"ROOM"` + `EXEC`.** Once the
  scene is only reachable through the intro, that launch no longer exists, so the suites must be
  re-pointed at the integrated path (boot `INTROSEQ`, run through four beats, arm on the scene) —
  **re-pointed, not re-cited.** Their address inputs are already map-derived (`run_walk_test.sh`
  takes `room_entry` from the map), so the addresses will follow; **the launch will not.**
- **AC6 — entry state post-merge.** ★ **NOT DONE.** P3.104's pre-merge answer stands unchanged.
- **AC7 — `SetupDHires`/`Prolog2` stated absent.** **Both absent; neither built.**
- **AC8 — suites green, 128 KB first; build verified by symbol from a freshly baked image.** §5.
- **AC9 — Jay gates LIVE.** ★ **Nothing new to gate: no behaviour changed.** The staged image is
  built and placed but nothing calls it.
- **AC10 — route accounting; sync bridge; Karateka; `main`.** §6.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim).** `build.bat` run fresh, with the new steps: §3A's block,
ending `=== BUILD COMPLETE ===`, `6 File(s) 36581 bytes / 13824 bytes free`.
**Build verified by symbol from a freshly baked image:** `build/obj/scene.map` places `prog` at
`2500`; `decb_to_raw` refuses an image whose first segment is not exactly at the stated `--base`,
and it reported `1147 B flat image based at $2500`.

```
[suites] running: introseq room walk
[suites] retired at P3.103: probe cel compiled mode anim
[suites] -ramsize 128K
[suites] === introseq ===   [run_introseq_test] PASS
[suites] === room ===       [run_room_test] PASS
[suites] === walk ===       [run_walk_test] PASS
[suites] ALL PASS
```
`[hal-sync] OK -- HAL source aligned with karateka_coco3 (11 files compared…)`

★ **What those greens are and are not evidence for.** They are the STANDALONE builds, run because
the disk changed under them (a track reserved, 18,432 → 13,824 B free) and a regression there was
possible. **They are not evidence about an integrated scene**, which does not exist yet — §4a's
point, and I am not letting it pass unstated.

**25.2 bundled-artifact grep:** `scene_prog.raw` 1,147 B → track 24, `3461 B pad`, reserved in the
FAT. Every other asset's placement is unchanged.

**25.3 operator-runtime-smoke: N/A — no behaviour changed.** Standing gates unchanged: flash,
glass, sand, slump, the feet, and the exit walk (P3.103, Jay) all PASSED.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** No route proposed in advance. Against §6's ten criteria this change
contains **AC1, AC7, AC8, AC10 in full**; **AC2, AC3, AC4, AC5, AC6, AC9 NOT DONE**, all blocked
by §3B.

★★ **The honest shape: I built the half the design covered, and the other half turned out to need
a mechanism the design did not know was missing.** P3.105 costed the *staging* and was right about
every number; neither it nor P3.104 asked whether the thing being staged could be called and
returned from. **That question only gets asked by writing the `jsr`.**

**Reactive deviations (§22.5):**
1. `--span-end` on `decb_to_raw` and `kernel_identical_check.py` are new tooling not named in the
   dispatch. Both exist because linking the scene where its HAL calls resolve *and* not shipping a
   second kernel are in tension, and the resolution needed an assertion rather than a comment.
2. Track **24**, not 17 — §3C.

Oracle read-only and not run. Karateka untouched. `main` untouched. `hal-sync` OK.

### 7 — Uncertainty flags

- **★★★ The scene's exit is unbuilt and it changes the scene's ending**, which is under gate.
  §8.1 names the shape; **Jay should see the new ending before it is called from anywhere.**
- **★★ `$2500` is placed but never executed.** The image is on the disk and nothing reads it, so
  the address is verified by the linker and the extractor and **not by a machine**. The first
  `jsr` is where that gets tested, and DECB's post-handover workspace at that address has still
  not been re-checked (P3.105 flagged this; it is unchanged).
- **★ The intro-only ceiling margin is `$56..$103`** — 86 to 259 bytes. It fits; it is not roomy,
  and the ceiling is a bracket rather than a point.
- **★ The scene's suites will lose their launch path** when the standalone `ROOM.BIN` stops being
  the thing that ships (AC5). `ROOM.BIN` is still built and still tested today, so nothing is
  broken — but it will become a build that nothing ships, which is the stale-checker shape.
- Carried: the mirrored cels' chroma; the exit's +13% cause; P3.103's `mode`-cycling gap;
  `SetupDHires`/`Prolog2`.

### 8 — Follow-up candidates

1. **★ Give the scene an exit, and gate it.** Bound the plan cursor at `cel_plan_end` in
   `vm_beat_tick`, publish "done", and leave **both** arms of `room_loop` by `rts`. It changes
   what the scene does at its end, so it wants Jay's eye — and it is the whole of what blocks
   AC2–AC6.
2. Then the call site: load track 24 to `$2500`, `jsr`, reload the captions from tracks 25-26,
   with the `BEAT_PATCH = 0` assertion beside it (AC3) and the read-before-reveal measurement
   across the whole sequence (AC4).
3. **Re-point the scene's suites at the integrated launch** before quoting them as evidence about
   the integrated scene (AC5).
4. Retire `ROOM.BIN` once the integrated path is gated, so nothing tests a build that does not
   ship.

### 9 — User interaction during task

None.

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-16-a-component-verified-standalone-may-not-have-the-shape-a-caller-needs.md`

### 11 — Commit

See below — pushed to origin/wip before this report.
