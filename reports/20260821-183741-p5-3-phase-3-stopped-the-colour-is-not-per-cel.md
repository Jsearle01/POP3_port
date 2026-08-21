## Form B Report — P5.3 Phase 3 — STOPPED BEFORE THE BUILD: the tile colour is not a per-cel property, and §2.3's identity prediction cannot be met by the design the proposal implied

**Class:** Phase 3, **stopped at the first measurement**. `wip`.
**★★★ NO ENGINE CODE WAS WRITTEN. Nothing under `src/` was created, modified or deleted.**
**Prod byte-identical; nothing was rebuilt.**

### 0 — Receipt / status (C-35 stamp)

t0 = **2026-08-21T22:37:41Z** (Phase 3 release received). HEAD **`4872736`**, branch **`wip`**.
**`main` resolved here: `32b5fe2`. Not moved.**

Standing untracked set unchanged and untouched: `.vscode/`, `nvram/`,
`POP-idioms-coco3-markers.md`, `content/intro/broderbund_splash_render.bin`,
`docs/project/pop-coco3-design-v0_7.pdf`, the nineteen files under `docs/ground-truth/`; plus the
one modified tracked file `dist/mame-cfg/rgb/coco3.cfg`.

**Prod sha1 — identical at receipt and at the end (AC8):**

```
d07f1f3295525783968dcce6409ee1b64942231c  build/intro_seq.bin
0b4968867bf5274d2942f3b5b90ea855ad6f2def  build/loader.bin
790836577e56b61b8f849cb309874e44304840a2  build/cutscene_room.bin
```

`git status --porcelain src/` → **0 lines.**

### 1 — Summary

**I stopped, and the release is why.** §5 says *"§2.3's predicted numbers are the Orchestrator's
too. Check them against what you measure; if they do not hold, that finding outranks this
release."* I checked the central one before writing any engine code, and **it does not hold.**

A port that converts each tile cel to 4 colours **once, in isolation** — which is what "resolve
piece ids to cels through the port's own tables" implies, and what the gated arithmetic costed at
19 cels / 3,424 B — **cannot be byte-identical to `bg_compose.py`. Measured: 662 bytes differ,
95.69%.** The cause is not the four AND masks (23 bytes); **661 of the 662 are the colour model's
neighbour dependence across cel seams**, and **92% of the differing bytes sit on a block's first
or last byte**, 2 of every 7. **422 of the 662 differing pixels are black↔lit** — thin dark seams
down every block boundary, not a subtle hue swap. And it is not a wash: against the oracle's own
frame the per-cel route is **93.40% against the composited route's 97.57% — 639 bytes worse on a
screen whose entire explained delta is 374.**

**The fix is in the BAKING TOOL, not the port and not the bank path**, and I measured that too:
bake each cel's colours **from the composited page** and screen 1 needs **35 context variants,
6,211 B raw packed — which still fits the pinned page with 1,623 B spare.** So **the gated
proposal's conclusion stands: one pinned page, `cel_pg_sig = 0`, zero rotations.** What changes is
one line of its arithmetic and, with it, the structure §2.1 told me to confirm rather than
inherit: **the 178-entry image table becomes a 35-entry (image × context) table.** That is a gated
number moving, so it comes back to Jay rather than being amended in place.

### 2 — Files modified

Explicit-path staging. **Nothing under `src/`, `content/`, `link/` or `build.bat`.**

- `harness/tools/tile_composite_check.py` — **new.** Composites a screen in 4-colour space from
  per-cel conversions and diffs it against the HGR-composited reference.

### 3 — Reasoning

#### 3A — Why this was measured before anything was built

The release's step 1 is *"resolve piece ids to cels through the port's own tables, and composite
the background into the framebuffer."* The port has **no HGR framebuffer**. `bg_compose.py`
composites in Apple HGR space — 1 bit per pixel plus the palette bit — and converts the finished
page to 4 colours **once, at the end**. A port must convert **each cel once at bake time** and
composite the 4-colour results.

**Those are not the same operation.** The HGR→4-colour model is neighbour-dependent: a pixel's
colour depends on the run it belongs to, the gap before that run, and its screen-column parity
[`sprite_convert.convert_sprite_to_coco3`]. Two cels that abut in HGR have adjacent pixels, and
converting them separately cannot see across the seam.

**So the two could disagree at every cel boundary, and §2.3 predicts they will be identical.**
That is cheap to settle offline and expensive to discover after a renderer exists, so it was
settled first.

#### 3B — The measurement (`tile_composite_check.py`)

Screen 1's display list is **80 entries: 51 `sta`, 25 `ora`, 4 `and`**, and exactly **one** entry
sits at a non-zero sub-byte phase (a front piece; `blockxco` is a multiple of 4, so `xco*7` is a
multiple of 28 and every block section lands on phase 0).

| comparison | differing bytes | match |
|---|---|---|
| per-cel 4-colour composite **vs** `bg_compose` (HGR→convert) | **662** | 95.69% |
| per-cel 4-colour composite vs `bg_compose` **with the AND masks removed from both** | 661 | — |
| `bg_compose` with AND **vs** without AND | **23** | — |

**★ So the masks account for 23 bytes and the seams for 661.** The AND ops were the obvious
suspect — there is no bitwise AND on palette indices — and they are almost the whole of the
*innocent* part.

**Where the 662 sit:**

```
differing bytes by tile-block column (7 fb bytes each):
  0:60  1:66  2:48  3:3  4:33  5:80  6:100  7:100  8:110  9:62

611 of 662 (92%) are a block's FIRST or LAST byte — 2 of every 7.
```

**What they look like** (662 differing pixels, 1.08% of the screen):

| reference → per-cel | pixels | |
|---|---|---|
| blue → **black** | 379 | **visible** — lit pixels lost at the seam |
| white → blue | 240 | chroma/white swap |
| black → **blue** | 43 | **visible** |

**422 of 662 are black↔lit.** A thin dark line down the left and right edge of most blocks is not
a subtle artefact; it is the kind of thing Jay's eye is the gate for.

#### 3C — And it is not a wash: per-cel is measurably less faithful to the ORACLE

The release's §2.3 rightly says the port-vs-oracle comparison is the real one, because the shared
packer makes port-vs-compositor agreement cheap [`§5.183`]. So both candidates were compared
against the oracle's own screen-1 frame, converted through the same function:

| | vs the oracle | differing bytes |
|---|---|---|
| `bg_compose` (HGR composite → convert) | **97.57%** | 374 |
| **per-cel convert → 4-colour composite** | **93.40%** | **1,013** |

**639 bytes worse**, on a screen whose entire *explained* delta — characters, meters, flames, gate
bars — is 374 bytes. **The seam artefact is nearly twice the size of everything else on the
screen.** This is a fidelity argument, not a bookkeeping one.

#### 3D — The fix is in the baking tool, and the gated page arithmetic survives

Nothing above indicts the bank path. The colour is a property of **what is baked into the page**,
not of how the page is mapped. If each cel's colour bytes are taken **from the composited page**
— its shape and transparency from the original cel, its colours from the finished conversion —
then the port's composite reproduces `bg_compose` **by construction**.

The cost is that a cel becomes **context-specific**: the same image beside different neighbours
converts differently. Measured on screen 1:

| | |
|---|---|
| distinct images placed | **16** |
| **distinct context variants needed** | **35** |
| raw packed bytes | **6,211 B** (×1.81 the 3,424 the proposal costed) |
| pinned page: 8,192 − magic 2 − table 356 | **7,834 B available** |
| **verdict** | **FITS, 1,623 B spare** |

and that is the **raw packed** figure; the blitter's segment-stream form skips runs of index 0
[`blit_core.s:41-48`] and screen 1 is 54% black, so the shipped figure is lower.

> **★★★ THE GATED CONCLUSION STANDS: one pinned page, `cel_pg_sig = 0`, `$FFA7` unused, zero
> rotations. What moves is one line of the arithmetic — 19 cels / 3,424 B becomes 35 variants /
> 6,211 B — and the table structure §2.1 asked me to confirm rather than inherit.**

#### 3E — §2.1, answered: the table is not what was gated

The release's §2.1: *"the pinned page now holds a structure it has never held: the tile pointer
table. 356 bytes, 178 entries… Confirm that explicitly rather than inheriting the cutscene's
arrangement."*

**Confirmed, and it is different from what was gated.** A **178-entry image table cannot index
context variants** — the index that resolves a piece id has to become an index over (image ×
context), which for screen 1 is 35 entries. Either:

- the table is keyed by **display-list position** (80 entries for screen 1), or
- the bake **de-duplicates** to 35 variants and the *renderer* is handed a per-entry variant id,
  which means the blueprint→cel resolution happens **at bake time**, not at run time.

**★ The second reading collapses part of the release's step 1.** *"Read screen 1's blueprint…
resolve piece ids to cels through the port's own tables"* presumes the resolution is a run-time
mapping from piece id to cel. **With context-correct colour it cannot be — the same piece id
resolves to different cels depending on its neighbours.** That is a change to what Phase 3 builds,
not just to what it packs, and it is why this is a stop rather than an amendment.

#### 3F — What I did NOT do, deliberately

- **No engine code.** Not one file under `src/`.
- **No amendment in place.** The obvious move — quietly switch the bake to context-correct cels
  and build — would have produced a port-vs-compositor comparison that is **byte-identical by
  construction and therefore worthless** [`§5.183`, which the release itself cites], plus a
  changed gated number nobody was told about. The release names that shape exactly: *"a build
  that quietly routes around it."*
- **No widening of §3D's six exclusions.** Untouched.
- **No hardware run, no suites.** Nothing was built, so there is nothing to run them against.

### 4 — Verification (AC-by-AC)

- **AC5 (hardware render)** — **NOT MET, and correctly not attempted.** See §3A-§3E.
- **AC6 (port-vs-compositor and port-vs-oracle deltas)** — **partially met, ahead of the build**:
  both deltas are measured for the *candidate design* (§3B, §3C) with every differing region
  enumerated and **zero unexplained** — masks 23, seams 661, of 662. What is not measured is a
  real port's output, because no port exists.
- **AC7 (plane ordering untested)** — **recorded, and now doubly so:** not only would a static
  screen fail to exercise it, no renderer was built at all. **Nothing in this report may be
  quoted as covering the foreground plane.**
- **AC8 (prod byte-identity)** — **MET.** §0; nothing was rebuilt.
- **AC9 (suites, 128 KB then 512 KB)** — **not run.** No build input changed; there is nothing new
  to test. They are required when Phase 3 actually builds.
- **AC10 (route accounting)** — §5.

### 5 — Reactive deviations and route accounting

**Deviation, and it is the whole report:** Phase 3 was released and **I stopped inside it**, before
writing engine code, on the authority of §5 (*"if [§2.3's numbers] do not hold, that finding
outranks this release"*) and §1 (*"If the build shows the gated proposal wrong, STOP AND REPORT
rather than amending it in place"*).

**ROUTE ACCOUNTING.** No route was proposed in conversation before this task. **What I built versus
what was released:** the release asked for a renderer, a hardware gate and two deltas; **I built
one offline measurement tool and no renderer.** That is a deliberate under-delivery against a
released instruction, and the reason is §3 in full. **Nothing else from the release was attempted
or partially done** — there is no half-built renderer, no touched `src/`, no changed build.

### 6 — Uncertainty flags

1. **The 35-variant / 6,211 B figure is for SCREEN 1 ONLY**, and it excludes the 4 AND entries and
   the 1 sub-byte-phase front piece (5 of 80). Those need their own answer: the masks have no
   4-colour equivalent as bitwise ops, though the blitter's `$C0|n` **merge** segment —
   `dest = (dest AND mask) OR src` [`blit_core.s:46`] — is the operation they exist to perform,
   so the likely answer is that mask+ORA pairs bake into one merge segment. **Not designed here.**
2. **The variant count does not obviously scale.** 16 images → 35 variants on one screen. The
   whole level is 24 screens, and P5.1 costed its blueprint-determined set at 7,202 B on the
   assumption of shared cels. **That assumption is now in doubt for the general case**, and §3D's
   exclusion 4 (*no claim past `LEVEL0`*) is doing more work than when it was written.
2b. **P5.1's and P5.0's tile figures assume isolated cels.** They are not wrong as *counts of
   distinct images*, but as *storage* figures they are lower bounds if colour must be
   context-correct. `demo-memory-map.md §6.1` and `demo-move-graph.md §6.1` both carry the
   assumption implicitly.
3. **I have not proven the context bake is byte-exact**, only that it is byte-exact *by
   construction* for the entries it covers, and I measured its variant count and size. A build
   would have to demonstrate it.
4. **The oracle frame used** is `build/oracle_demo_hgr2.bin`, P5.0's capture of the demo at
   +300 frames on screen 1. Its 374-byte delta from `bg_compose` is P5.0's four omission classes.
5. **Carried, untouched:** the placement question for `demo-behaviour.md`; the build's path
   contamination; the `.gitattributes` residual; the HAL audit items; the palette's two homes; the
   mislabelled 58,026 cy figure; `chtable7`/`chtable2`; P5.2's 4 unexplained w/h mismatches.

### 7 — Follow-up candidates

1. **The decision this stop is for.** Three routes, unranked and not chosen:
   **(a)** context-correct bake — 35 variants, 6,211 B, fits, byte-exact, but the piece-id→cel
   resolution moves to bake time; **(b)** accept per-cel isolation — simple, run-time resolution
   survives, costs 639 bytes of fidelity against the oracle and visible seams; **(c)** something
   between, e.g. converting cels with a padded context so that shared contexts collapse.
2. **Re-examine P5.0/P5.1's tile storage figures** under whichever route is chosen (§6 flag 2b).
3. **The AND masks and the merge segment** (§6 flag 1) — the blitter already has the operation.
4. **Everything from the P5.3 Phases 1-2 follow-up list** still stands, unchanged.

### 8 — User interaction during task

The Phase 3 gate release itself. **The stop is a response to its own §1 and §5, not a refusal of
it.**

### 9 — Candidate(s) captured this task

`seeds/POP/live/2026-08-21-combine-then-convert-is-not-convert-then-combine.md` — committed and
pushed to the pool (fire-and-forget). *A reorder of combine and convert is safe exactly when the
converted stage is context-free; this one reads neighbours, and the reference implementation
encoded one order by construction and would always have favoured itself.*

### 10 — Commit

See the commit that carries this report, pushed to `origin/wip`. **`main` was not moved.**

---

## ★★ PHASE 3 IS STOPPED PENDING A RULING ON §7.1. NO ENGINE CODE EXISTS.
