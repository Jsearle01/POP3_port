## Form B Report — P5.15 — the cutscene's disk read is gone, and what the old scarcity was hiding

**Class:** build. `wip`. **`main` untouched.** Prod binaries **changed** — `intro_seq.bin` and
`cutscene_room.bin` both carry the new page schedule; that is the deliverable, not a side effect.

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-22T23:10:58Z (HEAD `5441e9a` at start, wip → `8cedebd` at report).

★★ **`main` = `32b5fe23a49bf43e86c64f867ff59fb40c1ce0db`, byte for byte the value P5.14 recorded at
its receipt.** Not moved, not merged, not touched.

`git status` at receipt — the standing untracked set (`.vscode/`, `nvram/`,
`POP-idioms-coco3-markers.md`, `content/intro/broderbund_splash_render.bin`, the `docs/ground-truth/`
PDFs, `docs/project/pop-coco3-design-v0_7.pdf`), plus two tracked files carried in from the previous
turn's work: `harness/tools/bake_scene.py` (the track-map correction) and `harness/tools/cel_pack.py`.
Both are committed here.

---

### 1 — Summary

**This was not a scope task. Jay asked for it directly: *"yes, reowrk the intro and then i'll gate
it."*** The thing being reworked is the 3.20-second freeze P5.13 measured at beat 12 of the cutscene —
the **only** disk read visible anywhere in the intro's 51 seconds of drive time. It is now gone,
measured on P5.13's own instrument, and the cost is two tracks moved into the black boot.

It did not go the way the plan said. The freeze existed because the scene packs into **four pages
against three rotating blocks**, so page 3 had to be re-read over page 0 mid-scene. 512 KB frees a
fourth block. Giving it one produced **five pages, still one read, and two tracks more than the disk
has** — worse in every dimension. Chasing that is §3A, and it is the substance of this report: **two
greedy stopping rules that the old scarcity had made invisible**, one in the packer and one in its
caller. Neither could have been wrong before, because until there was a fourth block there was only
ever one answer to find.

With both replaced: **four pages, four blocks, `reads: []`**, the same four page images on the same
four track pairs, and only page 3's block number changed. **512 KB: all three suites PASS. 128 KB:
introseq and integ FAIL** — and §3E is explicit that this is the first genuine spend of the permission
Jay granted at P5.14 and P5.14 declined to use.

---

### 2 — Files modified

- `harness/tools/cel_pack.py` — the page-budget search (§3B); `N_BLOCKS` derived from `ROT_BLOCKS`;
  `$18` added to `ROT_BLOCKS`; header corrected (it described three blocks, two mid-scene reads, and a
  128 KB bank); an env-gated `CEL_PACK_DEBUG` trace of the cap loop.
- `harness/tools/bake_scene.py` — the candidate loop scores instead of short-circuiting (§3C); **and
  the track-span map corrected from the previous turn** (§3D).
- `src/engine/char_draw.s` — `cel_load_startup` releases the drive when no staged read is owed (§3F).
- `harness/smoke/introseq_test.lua` — expected load count 16 → 18, with the accounting (§3G).
- `content/cutscene/chars/` — `cel_pack.json`, `cel_pages.s`, `cel_plan.s`, `cel_pg3.s` (real changes);
  `cel_pg0/1/2.s`, `cel_res.s`, `walk_scripts.s` (**line endings only** — proven, §3H).

Explicit-path staging; thirteen named paths, no `git add -A`.

---

### 3 — Reasoning

#### 3A — the fourth block made it worse, and that is a diagnosis, not a setback

Authority: **execution / tool output** throughout this section (§2 tier 2 — the running tool, not a
description of it).

Setting `ROT_BLOCKS = ($0D, $0E, $0F, $18)` and re-baking gave:

```
*** out of raw disk tracks: 2 more wanted ***
```

Five pages where three blocks gave four. **A relaxed constraint cannot make a genuinely optimal search
return a worse answer — the old solution is still legal.** So the degradation is proof the search is
not optimising page count, and it is available before any redesign. That is the whole of §3B and §3C;
the rest of this section is what the instrument said.

Instrumented (`CEL_PACK_DEBUG=1`), with four blocks:

```
[cap=4 n_rot=4 live_reads=[1, 8, 12, 20] needing=12] -> None
[cap=5 n_rot=4 live_reads=[1, 8, 12, 20] needing=12] -> 5 pages
```

and with three:

```
[cap=3 n_rot=3 live_reads=[1, 8, 12, 20] needing=12] -> None
[cap=4 n_rot=3 live_reads=[1, 8, 12, 20] needing=12] -> None
...  (every cap to 7)                                 -> None
[cap=3 n_rot=3 live_reads=[0, 1, 8, 12, 20] needing=12] -> None
...
```

**★ The two runs disagree about whether the first candidate read-point set packs at all.** Three
blocks: it never packs, and the bake walks on to later candidates. Four blocks: it packs, at five
pages — and the loop **stops there**. That is the second stopping rule, and it is the one that
mattered.

#### 3B — the packer's rule: longest-run-first is not fewest-pages

`cel_pack.search` took the longest run of beats that fit one block, then shortened only on backtrack.
Page count was never the objective — the search had no notion of it. And the refill constraint
(`if k >= n_rot`) is what previously **forced** a short first group; a larger `n_rot` defers it, lets
an early group run long, and pushes the tail into an extra page. **The added block relaxed the very
constraint that was accidentally producing the good answer.**

The fix is a page budget threaded through the recursion, tried from `n_rot` upward:

```python
for cap in range(n_rot, n_rot + len(live_reads) + 1):
    pages = search(0, [], cap)
    if pages is not None:
        break
```

`cap = n_rot` means a block per page and an empty read schedule; each widening step buys one page at
the cost of one mid-scene read. **So "no read" is now preferred rather than stumbled into.**

#### 3C — the caller's rule, which is the one that survived the fix

Fixing §3B alone still returned five pages. `bake_scene` searched **read-point candidate sets** and
took the first that packed:

> `# So: try candidate sets in increasing order and take the first that packs.`

★★ **That rule was written when NO candidate packed without a read** — so "first that packs" and
"best that packs" named the same set, and the difference between them could not show in any output.
It is not a rule that was ever observed to be wrong; it is a rule whose wrongness had no way to
appear. The fourth block is the event that separates them.

It now scores every candidate and takes the best — **fewest reads, then fewest pages**, then candidate
order for determinism. The comment two paragraphs above it already warned that the search *"is not
monotonic in this set"* (P3.96), which is precisely the reason the whole list must be walked.

#### 3D — §2H's three checks

1. **A second mechanism serving a different object class?** Yes, and it is §3C — the greedy rule in
   the packer had a twin in the caller, operating on read-point sets rather than beat groups. Fixing
   the first and reporting the result would have been the exact failure §2H names: I had a five-page
   answer in hand after the §3B fix and could have reported "four blocks needs a fifth page."
2. **The routine that CALLS it.** `search` is called by `pack`, which is called by `bake_scene`'s
   candidate loop — and **the caller carried the scope**, as §2H says it does. The page-count question
   is decided at that level, not inside the recursion.
3. **Prior-report grep.** P3.96 (the non-monotonic read-point search), P3.78 (the pin/rotate design),
   P4.25 (the preload move), P5.13 (span 15). No contradiction between them found; P3.96's
   non-monotonicity note is *consistent with* and *argues for* the §3C change, and it is cited above
   rather than paraphrased.

#### 3E — ★★ the 128 KB machine, and the permission this spends

**There is no fourth block at 128 KB and there never was.** The census, from the port's own literals
rather than from memory:

| blocks | claimed by |
|---|---|
| `$00-$07` | framebuffers A and B (aliases of `$10-$17`) |
| `$08-$0B` | the CPU's low map (aliases of `$38-$3B`, `sys.s:227-233`) |
| `$0C-$0F` | **the cel bank AND** the aliases of `$3C-$3F` — the CPU's own `$8000-$FFFF` |

All sixteen are spoken for. Every block `$10-$3F` aliases mod 16 onto one of them, so **no choice of
fourth block is safe at 128 KB** — `$18` aliases onto `$08`, the program's low memory. The freeze is
not a defect that was overlooked; **it is the price of 128 KB**, and removing it is exactly what
P5.14's target move buys.

Measured, not assumed — 128 KB suite:

```
introseq: intro_arrived PASS at frame 780 ... frame 2078 status=23 phase=29 swaps=33265  FAIL
integ:    the scene did not reach-and-return                                             FAIL
tile:     PASS
```

★ **This is the first actual spend of Jay's P5.14 permission** (*"I don't care if the 512kb conversion
disrupts the 128kb mapping in the wip"*). P5.14 spent none of it — that migration came out with all
three binaries byte-identical and 128 KB still green. **This one does not, and it says so rather than
letting the suite result speak for it.** The `main` invariant (*"MAIN binaries need to remain
untouched"*) is separately intact: `main` has not moved.

#### 3F — a defect this change introduces, found before it shipped

`cel_service_read` releases the drive on the read that takes `cel_rd_left` to zero, and its own note
says holding it past the last one *"would spin for the rest of the scene for nothing."* The next
sentence reasons in one direction only:

> `The count comes from the pack, so adding a read cannot leave the motor running.`

**`CEL_N_READS = 0` is the case it does not cover.** `cel_rd_req` is never raised, the decrement never
runs, and the release is never reached — the motor spins for the whole scene. Real, not hypothetical:
it is what happens on the standalone path, where the resident magic is absent and `cel_load_startup`
does the reads itself. `cel_load_startup` now asks for the release on the same condition the schedule
uses, placed so the existing `clra` still sets the caller's Z.

#### 3G — the load count, and why 18 is not two extra reads

`introseq_test.lua` asserted 16 completed loads and now asserts 18. **The two are not new disk.** Page
3's two tracks used to be read *during* the cutscene; they are now read in the intro's opening batch
with the other three pages. Same tracks, same bytes — read against a black screen instead of against a
running scene. The trace confirms it at the byte level: **126,720 bytes before and after, identical.**
The check's comment block now carries that accounting, and names what a 17 or a 19 would mean.

#### 3H — what actually changed in the content

Every regenerated file compared to HEAD with CR stripped (`cmp`, not `diff`):

```
cel_pack.json  *** CONTENT CHANGED ***      cel_pg0.s   LINE-ENDINGS ONLY
cel_pages.s    *** CONTENT CHANGED ***      cel_pg1.s   LINE-ENDINGS ONLY
cel_pg3.s      *** CONTENT CHANGED ***      cel_pg2.s   LINE-ENDINGS ONLY
cel_plan.s     *** CONTENT CHANGED ***      cel_res.s   LINE-ENDINGS ONLY
                                            walk_scripts.s  LINE-ENDINGS ONLY
```

**No pixel changed.** The entire semantic delta is four facts:

```
CEL_N_READS     1 -> 0
CEL_N_STARTUP   3 -> 4
page 3 block    $0D -> $18            (cel_pages.s, cel_pg3.s header, cel_plan.s)
beat 12         fcb 4,0,10 -> fcb 0,0,10     (the READ flag cleared)
```

§2B: `docs/project/protection-catalog.md` **does not exist yet** — no POP asset has been flagged
ALTERED/PROTECTED. Combined with the line-endings-only proof above, nothing hand-authored was
overwritten.

#### 3I — the track map, carried in from the previous turn

`bake_scene.py`'s allocator claimed `[[11,6],[20,5],[32,3]]`, which over-claimed tracks 24 and 32-34 —
**and P5.5 had already put the tile page on track 34, inside a span the allocator believed was free.**
Corrected to `[[11,6],[20,4]]` = ten tracks, with the full disk map written above it. Verified inert
(same five units on tracks 11/13/15/20/22) **and verified it now fails loudly** — the four-block
five-page attempt in §3A produced `*** out of raw disk tracks: 2 more wanted ***` instead of silently
overwriting the tile page. **That failure is the corrected map doing its job**, and it is why the map
was fixed first.

---

### 4 — Verification (AC-by-AC)

Jay's instruction was one line, so the acceptance criteria are the ones it implies.

- **AC1 — the mid-cutscene disk load is gone.** `cel_pack.json` reads `"reads": []`; `CEL_N_READS
  equ 0`. Measured on P5.13's instrument (§5): **no span in the trace has motion on both sides and
  none during** — the definition P5.13 used for "visible" — and frames 6881–7073, which the freeze
  occupied, now sit inside a **70.38 s gap containing zero disk activity and 110 page flips.**
- **AC2 — the four pages still fit the disk.** Five units, ten tracks, against the corrected
  ten-track map. Build: `--- cel image: 5 units placed, 10 tracks ---`.
- **AC3 — nothing else moved.** §3H: four files changed semantically, five by line endings alone, no
  pixel data touched.
- **AC4 — the change is inert where it should be.** At three blocks the new search and the new scoring
  reproduce today's schedule exactly: `59 candidate set(s) packed; [1, 8, 12, 16, 20] wins with 1
  read(s) and 4 page(s)`, same tracks 11/13/15/20/22, same blocks, same signatures.
- **AC5 — `main` untouched.** `32b5fe23a49bf43e86c64f867ff59fb40c1ce0db`, unchanged.

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim):**

`python harness/tools/bake_scene.py` —
```
  read-point search: 468 candidate set(s) packed; [1, 8, 12, 16, 20] wins with 0 read(s) and 4 page(s)
  cel_res.s      7,647 B  track 11 (+2)
  cel_pg0.s      7,292 B  track 13 (+2)  block $0D  sig $A53C
  cel_pg1.s      6,451 B  track 15 (+2)  block $0E  sig $A64D
  cel_pg2.s      7,205 B  track 20 (+2)  block $0F  sig $A75E
  cel_pg3.s      3,267 B  track 22 (+2)  block $18  sig $A86F
```

`./build.bat` —
```
--- cel image: 5 units placed, 10 tracks ---
[map_check] 6 map(s) clean — no overlap, nothing below $0E00.
  PROBE.BIN 1256 ok / MODE.BIN 1319 ok / ANIM.BIN 1438 ok
  INTRO.BIN 28132 ok / LOADER.BIN 1593 ok / TILE.BIN 1487 ok
# VERDICT: PASS - every file on the image matches its artefact.
=== BUILD COMPLETE ===
```

`./harness/smoke/run_suites.sh` (**512 KB — the target, reported first per §2K**) —
```
[suites] running: introseq integ tile
[suites] -ramsize 512K
[suites] === introseq ===   [run_introseq_test] PASS
[suites] === integ ===      [integ] PASS
[suites] === tile ===       [run_tile_test] PASS
[suites] ALL PASS
```

`MAME_RAM=128K ./harness/smoke/run_suites.sh` (**divergence is the informative part — §2K, §3E**) —
```
[suites] === introseq ===  FAIL   (frame 2078 status=23 phase=29 swaps=33265)
[suites] === integ ===     FAIL   (the scene did not reach-and-return)
[suites] === tile ===      PASS
[suites] FAIL
```

The load trace, `intro_load_trace.lua`, 512 KB, live-disk, headless, `P_SWAPS=$7B91` —
```
# FDC data-register reads (bytes transferred): 126720
  15    3975   4083    108  1.80    4608 |    1388   0   0 |   0   0   0 | music ran; screen static either side
  16    4083   4443    360  6.01   18432 |       0   0   0 |   0   0   0 | music quiet either side; screen static
  17    8660   8840    180  3.00    9216 |       1   0   0 |  11   0   0 | music ran; screen ran
# GAPS between spans -- disk idle.
  16       4443   8660    4217  70.38    110        <- the cutscene: 110 flips, zero disk
# 19 spans, 3091 frames engaged = 51.59 s of 200.3 s (25.8%)
```
No line in the span table carries the `STOPPED` verdict. Against P5.13's baseline: **126,720 bytes
both runs**, 51.18 s → 51.59 s engaged (**+0.41 s, all of it under the black boot**), and P5.13's
span 15 has no successor.

**25.2 bundled-artifact grep:** N/A — no sibling-import artefact; all changes are in-repo.

**25.3 operator-runtime-smoke: PASSED — Jay, live-disk, RGB, 512 KB (2026-08-23).** Jay, watching the cutscene run: *"torches run without stalling."* That is the gate this dispatch exists for, observed live on a running machine as a motion-bearing effect requires — not on a still. Gated on build `b019264`, which carries P5.16's cache on top of this change; the beat-12 behaviour under gate is this dispatch's.

**Original gate note:** This is a **motion-bearing** gate — the thing under gate
is the *absence* of a 3.20 s stall in a running cutscene, which §4's rules say a still cannot show. It
must be observed **live-disk, RGB, 512 KB**. `./harness/smoke/run_introseq_live.sh` is the runner.
**Jay deferred P5.14's gate until this rework was done; it is done, and both are now waiting on him.**

---

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** In the previous turn I proposed, and Jay approved with *"do both. your choice
with what to do first"*: **(a)** fix the packer's page-count preference, **(b)** fix the stale disk
track map. **This commit contains both**, in that order of dependency — (b) first, so a bad packing
would fail loudly rather than silently overwrite the tile page, which is exactly what it then did
(§3I).

**Beyond the proposed route, this commit also contains three things I did not describe in advance**,
each named here rather than left to the diff:

1. **The scoring change in `bake_scene`'s candidate loop (§3C).** Not part of the proposal — I did not
   know it existed. Fixing only the proposed half left the answer at five pages.
2. **The `char_draw.s` motor release (§3F).** A defect the change itself introduces.
3. **The `introseq_test.lua` expectation, 16 → 18 (§3G).** A consequence, not a choice.

Deviation from §2K's report order: none — 128 KB is reported, and reported as a failure.

---

### 7 — Uncertainty flags

1. **★ The 128 KB build now corrupts itself SILENTLY rather than refusing.** Nothing checks installed
   RAM before the preload writes block `$18`, so on a 128 KB machine the fourth page lands on the
   program's own low memory and the intro dies with garbage state — which reads as "the program
   crashed", not as "this build needs 512 KB." **This is a hazard on real hardware, not only in the
   suite.** A guard is cheap; I did not build one because it is beyond what Jay asked for. §8.1.
2. **The bake is now ~2m50s**, because the candidate sweep no longer stops early. It was seconds
   before. Bounded and deterministic, but it is a real cost paid on every content build, and an early
   exit would need a defensible lower bound on page count that I do not currently have.
3. **One observed run, one machine** — the same limitation P5.13 recorded. Drive-engaged time includes
   seek and rotational latency, so the +0.41 s figure is that machine's.
4. **The `run_introseq_live.sh` banner is now stale**: it says *"14.0 s of that is the CUTSCENE's eight
   cel pages"* and there are ten tracks now. I did not edit it — the file's own comment warns that a
   runner describing a run it no longer performs teaches its reader to skip it, so it should be
   corrected, but the number should come from the gate Jay is about to run rather than from me.
5. **`gfx.s:367` still says buffer B is at `$18-$1B` while `gfx.s:418` sets `GFX_DB_B_BLOCK equ $14`.**
   Flagged at P5.11, still unfixed, and it now matters more than it did: `$18` is the block this
   change hands to the cel bank. The code is right and the comment is wrong — but a header claiming
   `$18` belongs to the framebuffer is a live trap for the next reader. §8.2.

---

### 8 — Follow-up candidates

1. **A RAM-size guard that refuses instead of corrupting** (from §7.1). The loader can check installed
   RAM before the preload and stop with a legible message. Small, and it converts a silent crash into
   a statement.
2. **Correct `gfx.s`'s buffer-B header comment** (§7.5) — one line, and it now contradicts a block this
   change depends on.
3. **The intro's remaining 51 s of boot disk.** P5.13's §3H costed batching the whole schedule at
   −12 s wall clock. This dispatch removed the *visible* read; the *long* one is still there and is
   what Jay actually waits through.
4. **`run_introseq_live.sh`'s measured banner** (§7.4), to be re-derived from the gate run.

---

### 9 — User interaction during task

Jay, previous turn: *"yes, reowrk the intro and then i'll gate it."* — the instruction this dispatch
executes. And *"do both. your choice with what to do first"* — the two-fix authorisation accounted for
in §6. No interaction during the work itself.

---

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-22-more-resource-worse-result-means-a-greedy-stop.md` — *when adding a resource
makes the result worse, the bottleneck was never the resource; it is a greedy stopping rule the old
scarcity was hiding, and a monotone system cannot degrade under a relaxed constraint, so the diagnosis
is available before any redesign.* New row, pushed.

---

### 11 — Commit

`8cedebd` — pushed to `origin/wip` before this report.
