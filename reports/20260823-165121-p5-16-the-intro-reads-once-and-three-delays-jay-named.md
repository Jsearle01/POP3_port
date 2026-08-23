## Form B Report — P5.16 — a RAM track cache, and the three delays Jay named from the screen

**Class:** build. `wip`. **`main` untouched** (`32b5fe23a49bf43e86c64f867ff59fb40c1ce0db`).
Prod binaries **changed** — `intro_seq.bin` carries the cache; that is the deliverable.

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-23T16:51:21Z (HEAD `1b359dc` at start → `b019264` at report, wip).

Working tree at receipt: the standing untracked set only. Six tracked files modified and
committed here; one new tool (`harness/tools/scene_fetch_probe.lua`) added.

---

### 1 — Summary

**This dispatch exists because P5.15 under-delivered and Jay caught it.** P5.15 removed the
cutscene's mid-scene read and listed the rest as follow-ups. Jay then watched the intro and
named three delays without being told where to look — *"between the first tilte screen and
prolog1, between the princess scene and prolog2, and between prolog2 and the silent title
screen"* — and, when told they were disk, replied: *"i thought your whole purpose of this was
to get rid of disk reads after the initial load?"* **He was right, and the scoping error was
mine:** I had scoped to what P5.13 labelled *visible* rather than to what he actually asked
for, which was **loading everything up front**.

All three were disk, not design: **16.8 s of drive time after the loading screen was gone.**
This delivers a **RAM track cache** that collapses them. Measured on P5.15's own tracer,
live-disk, 512 KB:

| | before | after |
|---|---|---|
| post-boot disk | **16.8 s**, three groups | **5.20 s**, one group |
| after frame 4653 | reads at beats 5 and 6 | **nothing for the remaining 123 s** |
| tracks read twice | the captions, the splash | **0 of 19** |
| total drive-engaged | 51.59 s | **45.98 s** |

**Two of the three delays are gone outright.** The third — title → prolog1 — drops from
7.81 s to 5.20 s and stays under the title beat 3 already holds up for exactly this reason.

★ **It is not zero, and §3F says precisely what is left and why**, including one thing I
could not root-cause and did not paper over.

---

### 2 — Files modified

- `src/engine/intro_seq.s` — the cache (`tc_preload`, `tc_fetch`, `tc_map`/`tc_unmap`,
  `tc_tab`); four call sites converted; the drive released after the scene preload (§3E).
- `harness/tools/map_overlap_check.py` — a **ceiling** check and a **load-address** check
  (§3C, §3D), both with the history that made them necessary.
- `build.bat` — `SCENE_BASE` `$2600` → `$2700`; both new checks wired to it.
- `link/pop_scene.link` — `section prog load 2600` → `2700` (§3D).
- `harness/smoke/introseq_test.lua` — expected load count 18 → 16, fully accounted.
- `harness/tools/scene_fetch_probe.lua` — **new.** A write-tap probe on `SCENE_BASE` (§3F).

Explicit-path staging, six named paths.

---

### 3 — Reasoning

#### 3A — the mechanism, and why one routine rather than five preloads

Authority: **source** for the design, **execution** for every number.

Every post-boot reader already takes a track, because `load_tracks`' contract is
`(X = destination, A = track, B = sectors)`. **So the track is the natural key**, and one
routine carrying that same signature and clobber set replaces the read at every site — a
call site changes by one word, `jsr load_tracks` → `jsr tc_fetch`. A miss falls through to
the disk, so a track nobody cached still works.

It must be a **copy, not a mapping**: the three destinations are `$DA00`, `$3000` and
`$2700`, none block-aligned, and during a draw all four MMU slots are the framebuffer —
there is no window to reveal a cached track *in*. So `tc_fetch` borrows `$FFA4/$FFA5`, whose
contents at that instant are the back buffer the caller is about to overwrite entirely.
9,216 B costs ~0.05 s against the 3.00 s read it replaces.

**The borrow cannot disturb the screen, and that is a GIME fact rather than a hope:** video
fetch runs from VOFFSET against *physical* blocks and does not go through the MMU.
`cel_preload` borrows `$FFA6/$FFA7` on the same argument.

#### 3B — what actually disappeared, and what merely moved

**Two of the reads vanish rather than move**, which is the part worth stating: the captions
were read at boot *and* again after the scene expanded its bundle over them; the splash was
read for beat 1 *and* again for beat 6's reprise. Beat 6's own row explains why — the splash
*"is not resident anywhere… so this beat reads it back"* — and the cache is exactly the
residence it was missing. `0 of 19 distinct tracks are read more than once` is the receipt.

That is why total drive time went **down** (51.59 → 45.98 s) rather than merely relocating.

#### 3C — ★★ the intro overran `SCENE_BASE`, and P4.47 predicted the repeat

The first cache build ran three beats and died at beat 4 with the drive engaged. The link
map, not the symptom:

```
prog (intro_seq.o)  load at 2000, length 0578   -> ends 2578
prog (lz_unpack.o)  load at 2578, length 008E   -> ends 2606
```

`lz_unpack` ended **six bytes past `SCENE_BASE` (`$2600`)**, and the scene program is read
there as a whole track — so beat 4 overwrote the tail of the routine `load_screen` calls
next. ~400 B of cache code had spent the 242 B of headroom P4.47 left.

★★★ **This is the SAME failure as P4.47, to the same object file**, and P4.47's own note says
why it recurred: *"the map tool LISTED the two regions overlapping and did not flag it."*
It then raised the constant and left the tool alone. **So the constant is half the fix and
the guard is the half that matters**: `map_check` now fails the build when a section runs
into the scene's read window. Verified in both directions — at `$2600` it reports exactly the
real problem, at `$2700` it passes and says so in the clean line.

★ **Scoped to the read window, not to "above an address."** The first cut flagged
`hal_build.o` at `$7900`, which the scene read cannot touch — and a check that reports safe
things teaches its reader to ignore it.

#### 3D — ★★ and `SCENE_BASE` had a third home the comment denies

Raising it did not fix the stall. `link/pop_scene.link:64` carries `section prog load 2600`
as a literal — while `build.bat` says of `SCENE_BASE`: *"Both assemblies take them from here
so there is one home."* **True of the two assemblies, false of the link script.** The scene
was **linked at `$2600` and read to `$2700`**: every absolute address inside it off by `$100`.
It ran far enough to issue its two preload reads off correctly-relative code and then died on
the first absolute jump — which looks nothing like a wrong link address.

`map_check` now asserts `scene.map`'s `prog` loads **exactly** at `SCENE_BASE`. It caught the
live mismatch on the very next build before I fixed the script.

#### 3E — a regression this change introduced, found and fixed before commit

`room_preloaded` deliberately does not release the drive (P3.84 made the scene hold it across
its staged schedule). That was harmless **only because the next thing the intro did was
`load_screen`, whose `load_tracks` ends every read with `disk_read_motor_off`.** The cache
turned that read into a RAM copy and **the release went with it**: measured, **18.37 s
engaged to transfer 9,216 B** — ~3 s of reading and fifteen of spinning.

The intro owns the beat, so the intro now asks for the release. **18.37 s → 3.40 s**, and
total drive time went from 60.95 s (above baseline) to 45.98 s (below it).

★ **Same shape as the bug P5.15 fixed one layer down, and the same lesson: a release that
happens as a SIDE EFFECT of the next operation survives exactly until that operation changes.**

#### 3F — ★★★ what is NOT delivered: the scene's program is not cached

**Caching it breaks the cutscene.** The scene is entered, `room_load_cels` fails, and
`cel_scene_done` is never even *cleared*. Bisected with the link address finally correct so
the test meant something: that row out and every other row in → **integ PASSES and the flag
sets at frame 9255**; that row in → it never sets.

**What it is not** — ruled out, not assumed:

- **not a bad copy.** `scene_fetch_probe.lua` write-tapped `SCENE_BASE` and caught the copy
  landing `$7E 27 1C` — a valid `jmp` — at the right beat, with `probe_status 5`.
- **not spin-up.** `disk_read_range` calls `dr_spinup` itself and `dr_spinup` is self-checking.
- **not the motor.** `load_tracks` releases the drive after every read, so it is off either way.

**The root cause is not established.** The surviving hypothesis is that `load_tracks` is the
only beat-4 operation that runs at normal CPU speed with interrupts masked, immediately
before the scene's own two reads — and it is written into `tc_tab` **as a hypothesis**, next
to the commented-out row, with the bisect that justifies leaving it out.

★ **I said earlier in this session that the fix was "one mechanism, not six patches." That was
right for the screens and wrong here**, and the honest form of being wrong is a documented
exclusion rather than a theory shipped as a finding. The cost of leaving the row out is 1.8 s
of disk under a title that is already held up for it. The cost of guessing is the cutscene.

**Also not delivered:** the scene's own preload (`room_preloaded`) reads two tracks that the
cache cannot reach — the cutscene bundle has its **own** `load_tracks` and cannot see the
intro's cache. Moving it to boot is blocked by a hard address conflict: the scene's expanded
bundle (`FLAME_BASE`) and the intro's captions (`BUNDLE`) **both live at `$3000`**, which is
precisely why the preload sits at beat 4 at all. §8.1.

#### 3G — §2H's three checks

1. **A second mechanism for a different object class?** Yes, twice. The screens and the
   *scene program* behave differently through the same routine (§3F) — the whole reason this
   report has an exclusion. And `SCENE_BASE` had a second **home** (§3D) as well as a second
   failure mode (§3C).
2. **The routine that CALLS it.** `tc_fetch`'s callers carry the scope: `load_screen` (three
   beats), the boot batch, `sq_pre`, and `run_scene`'s exit. The beat-4 caller is where the
   drive release had to go (§3E) — the caller owned the fact, not the routine.
3. **Prior-report grep.** P4.47 (the `SCENE_BASE` raise — and it *predicted* §3C), P3.84 (the
   held drive), P4.25/P4.25b (the preload move), P5.13 (the schedule), P5.15. No contradiction
   found; P4.47's note is quoted rather than paraphrased because it names the failure exactly.

---

### 4 — Verification (AC-by-AC)

- **AC1 — the delays Jay named.** princess→prolog2 and prolog2→silent-title: **gone** (no span
  after frame 4653 in a 200 s run). title→prolog1: 7.81 s → **5.20 s**.
- **AC2 — nothing is read twice.** `0 of 19 distinct tracks are read more than once (0%)`.
- **AC3 — the extra boot cost is bounded.** Total drive-engaged **45.98 s vs 51.59 s** — the
  work moved under the loading screen *and* the total fell.
- **AC4 — the cutscene still runs.** integ PASS, `cel_scene_done` cleared and set.
- **AC5 — the build cannot repeat §3C or §3D silently.** Both guards verified failing on the
  real defect and passing when fixed.
- **AC6 — `main` untouched.** `32b5fe23a49bf43e86c64f867ff59fb40c1ce0db`.

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim):**

```
[map_check] 6 map(s) clean — no overlap, nothing below $0E00, introseq.map all below $2700,
            scene.map linked at $2700.
=== BUILD COMPLETE ===

[suites] -ramsize 512K
[suites] === introseq ===   [run_introseq_test] PASS
[suites] === integ ===      [integ] PASS
[suites] === tile ===       [run_tile_test] PASS
[suites] ALL PASS
```

The guards, each proven on the real defect:
```
[map_check] ★ introseq.map: section `prog` (lz_unpack.o) $2578..$2605 runs into $2600..$3800,
              which is OVERWRITTEN AT RUN TIME ...
[map_check] ★ scene.map: `prog` (cutscene_room.o) is LINKED at $2600 but is read to $2700 —
              every absolute address inside it is off by 256.
```

The shipping trace (`intro_load_trace.lua`, live-disk, headless, 512 KB):
```
  17    4341   4449    108  1.80    4608 |  music ran; screen static either side
  18    4449   4653    204  3.40    9216 |  music quiet either side; screen static either side
# GAPS between spans -- disk idle.
  16       2877   4341    1464  24.43      6
  ★ 0 of 19 distinct tracks are read more than once; 0 requests of 19 are re-reads (0%).
# 18 spans, 2755 frames engaged = 45.98 s of 200.3 s (23.0%)
```

**25.2 bundled-artifact grep:** N/A — no sibling-import artefact.

**25.3 operator-runtime-smoke: PENDING JAY.** Motion-bearing: what is under gate is the
*absence* of three stalls in a running sequence, which §4 says a still cannot show. Needs
**live-disk, RGB, 512 KB** — `./harness/smoke/run_introseq_live.sh`. **P5.14's and P5.15's
gates are also still open and this build carries all three.**

---

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** I proposed to Jay: *"preload the three screens into spare blocks at boot
and make `load_screen` source from RAM, so nothing reads disk after the initial load,"* and
flagged that the scene program + preload would move too, saying *"I'd say yes."*

**This commit contains:** the three screens ✔, the captions ✔ (not in the proposal — found by
enumerating readers rather than trusting the list), the boot preload ✔.

**It does NOT contain the half I said yes to:** the scene program is **excluded by
measurement** (§3F) and its preload is **blocked by an address conflict** (§3F). I described
a route to zero post-boot reads and am delivering 5.20 s, not zero. That is the gap, stated
here because no diff would show it.

**Three things beyond the route**, each named rather than left to the diff: the `SCENE_BASE`
ceiling + guard (§3C), the link-script second home + guard (§3D), the drive release (§3E).

---

### 7 — Uncertainty flags

1. **★ The scene-program cache failure has no root cause** (§3F). A clean bisect and three
   ruled-out candidates, not an explanation. Anyone re-adding that row without explaining it
   will break the cutscene, which is why the count in `introseq_test.lua` says so too.
2. **The 128 KB build is unchanged from P5.15 — still broken, and now more so.** The cache
   needs nine blocks that do not exist at 128 KB. Reported as a failure at P5.15 §3E; nothing
   here improves it, and it still corrupts silently rather than refusing (P5.15 §8.1).
3. **`run_introseq_live.sh`'s banner is now wrong three ways** — "eight cel pages" (ten since
   P5.15), the drive-time figure, and "black boot" (there has been a *loading screen* since
   P4.46, which Jay corrected me on). Deliberately not edited: the numbers should come from
   the gate run, not from me. §8.3.
4. **One observed run, one machine.** Drive-engaged time includes seek and latency.
5. **The `$2700` headroom is 250 B.** The guard makes overrunning it a build failure rather
   than a three-beat fuse, but the next thing added to the intro will meet it.

---

### 8 — Follow-up candidates

1. **The last 5.20 s** — the scene program (needs §3F's root cause) and its preload (needs the
   `$3000` conflict resolved, e.g. relocating `FLAME_BASE` or restoring captions from cache
   after a boot-time expand).
2. **The RAM-size guard** (carried from P5.15 §8.1) — refuse on 128 KB instead of corrupting.
   More urgent now: the cache adds nine blocks that machine does not have.
3. **`run_introseq_live.sh`'s banner** (§7.3), from the gate run.
4. **`gfx.s:367`'s buffer-B comment** — still says `$18-$1B` while the code says `$14`, and
   `$18` is now the cel bank's fourth block. Carried from P5.15 §8.2.

---

### 9 — User interaction during task

Jay, four times, and three of them corrected me:

1. *"there is a delay between the first tilte screen and prolog1, between the princess scene
   and prolog2, and between prolog2 and the silent title screen. are they programatic?"* —
   the question that started this. Answer: no, all disk (§1).
2. *"i thought your whole purpose of this was to get rid of disk reads after the initial
   load?"* — **the scoping correction this dispatch exists to answer.**
3. *"what is a blabk boot. you mean black creen during loading"* — correct, and my word was
   wrong: there has been a **loading screen** since his own P4.46. §7.3.
4. *"do it"*, *"so whats next"*, *"check"*, *"update your report"* — proceed, and report.

---

### 10 — Candidate(s) captured this task

None new. P5.15's captured row (`more-resource-worse-result-means-a-greedy-stop`) already
covers the closest general pattern here; §3C's *"a guard is the half of the fix that lasts"*
is a candidate I am holding until it has a second instance rather than capturing on one.

---

### 11 — Commit

`b019264` — pushed to `origin/wip` before this report.

---

## ADDENDUM — P5.16b: the gate, and the third delay taken to one read

**Commit `95eb951`.** Written after Jay gated `b019264` live.

### A.1 — the gate

**25.3 — P5.16: PASSED in part, and the part that failed was named precisely.** Jay,
live-disk, RGB, 512 KB, 2026-08-23, on three runs:

> *"torches run without stalling, whole thing ran."* → **P5.15 PASSED** (the beat-12 freeze)
> and **P5.14 PASSED** (the 512 KB target). Both stamped into their own reports.
>
> *"the sequence from princess trough to silent title looks good."* → **the two transitions
> this dispatch removed are confirmed gone.**
>
> *"there is still a long delay between the first title and prolog 1."* → **the third is
> not.** §3F predicted it would survive at 5.20 s and called that acceptable. Jay's ruling
> is that it is not, and §2.1 makes that the answer.

### A.2 — ★ and a claim in this report's own §1 was wrong

I told Jay the attract loop would repeat and that a second cycle would touch the disk zero
times. **The port's intro runs once and holds on the title; there is no cycle and no demo.**
Jay: *"also it does not loop back to the beginning as you inplied."*

★★ **P5.13 §3B established exactly that, in writing** — *"The intro runs once; there is no
cycle and no demo in the port"* — and I contradicted it from memory instead of grepping the
reports. **That is §2H's third check, the one it calls mechanical, not run.** Nothing
downstream depended on it; the error was in what I told Jay to expect while he was watching.

### A.3 — what the 3.40 s was, and why it was not the intro's to fix

`room_preloaded`'s two fetches — the cutscene's flame bundle (track 30) and room picture
(29). They stayed on disk because **that routine lives in the SCENE bundle**, which has its
own `load_tracks` and cannot see the intro's cache. §3F recorded this as blocked.

★ **It was not blocked; it was a missing argument.** The bundle already takes the disk as an
argument for the cels — *"the bundle has no HAL and no room; the disk arrives as arguments"* —
and the fix is that sentence applied one routine further. `room_preloaded` now takes **Y = the
reader**. The intro passes `tc_fetch`, which has `load_tracks`' contract and clobber set. A
caller that passes nothing gets `load_tracks` by default, so the standalone path is untouched.

**I had the precedent in front of me in §3A and did not apply it** — the same file, four lines
away from the code I was reading.

### A.4 — one home for the two tracks

This change hands a track number to a **second link unit**, which is exactly the drift
`link/pop_scene.link` cost a dispatch to find (§3D). So it does not get a comment:
`DISK_FLAME_TRK`/`DISK_ROOM_TRK` now live in `build.bat`, which `-D`s **both** assemblies and
supplies the `raw_tracks` calls that put them on the disk. `cutscene_room.s` keeps its
literals under `ifndef` so it still assembles alone.

★ **And the SIZE is derived, not written:** `lz_pack.py` emits `FLAME_TRACKS` for the bundle
it actually produced, so a bundle that outgrew a track would be cached at its real length
instead of half of one in silence. The room blob has no generated header, so `build.bat`
asserts it still fits one track.

### A.5 — measured

| | P5.13 | P5.15 | P5.16 | **P5.16b** |
|---|---|---|---|---|
| post-boot disk | 16.8 s, 3 groups | 16.8 s | 5.20 s, 2 spans | **1.80 s, 1 span** |
| title → prolog1 | 7.81 s | 7.81 s | 5.20 s | **1.80 s** |
| total drive-engaged | 51.18 s | 51.59 s | 45.98 s | **46.36 s** |
| re-reads | captions, splash | same | 0 of 19 | **0 of 19** |

**The title is now on screen ~12.6 s, of which 10.83 s is the oracle's own `BEAT_PRE` +
`BEAT_HOLD` for S_TITLE.** The removable part is down to 1.80 s.

`probe_loads` 16 → 18, and **it went up without a single extra read**: the scene's two tracks
were always fetched, by a routine that does not touch that counter. The check that would catch
a real regression is the trace, and it says 0 re-reads of 19.

**25.1:** `[map_check] 6 map(s) clean … introseq.map all below $2700, scene.map linked at
$2700.` / `=== BUILD COMPLETE ===` / `[suites] ALL PASS` (introseq, integ, tile — 512 KB).

**25.3 for P5.16b: PENDING JAY** — motion-bearing, same runner.

### A.6 — what is still not delivered

**The last 1.80 s is the scene's program**, and it is the one asset §3F could not cache: doing
so breaks the cutscene, with a clean bisect and no root cause. Everything else the intro
touches now comes from RAM. Removing it needs that root cause, or the absorb-into-the-hold
approach Jay has not ruled on — offered and deliberately not built, because it is the same
shape as the drift-free timing he refused at P3.87.

