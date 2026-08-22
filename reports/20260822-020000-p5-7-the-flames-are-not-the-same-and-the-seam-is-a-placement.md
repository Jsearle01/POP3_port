## Form B Report — P5.7 — the flames are not the same, and the cutscene's zero seam is a placement

**Class:** recon (Phases 1-3) + proposal (Phase 4, no code). `wip`. Prod byte-identical at both ends.

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-22T01:51:28Z (HEAD `a4f519a`, wip; **`main` at `32b5fe2`, resolved here**).

`git status` at receipt — the standing untracked set: `.vscode/`, `nvram/`,
`POP-idioms-coco3-markers.md`, `content/intro/broderbund_splash_render.bin`, nineteen files under
`docs/ground-truth/`, `docs/project/pop-coco3-design-v0_7.pdf`. One modified tracked file,
`dist/mame-cfg/rgb/coco3.cfg` — **★ dirty, and left dirty; Jay's ruling, not touched.**

**Prod sha1 — identical at both ends (AC11). Nothing rebuilt:**

```
d07f1f3295525783968dcce6409ee1b64942231c  build/intro_seq.bin
0b4968867bf5274d2942f3b5b90ea855ad6f2def  build/loader.bin
790836577e56b61b8f849cb309874e44304840a2  build/cutscene_room.bin
```

**AC10 — the stop observed:** `git status --porcelain src/` → **0 lines** at both ends.

---

### 1 — Summary

**Jay's lead is a clean NO, at both levels, and it is a useful no.** The dungeon's torches and the
princess room's torches are **nine frames each on an 18-state cycle** — the same *shape*, which is
almost certainly what prompted the question — but different tables, different image numbers,
different dimensions, and **zero byte matches**. The port's nine flame cels carry `ORIGIN:
IMG.CHTAB6.A` in their own headers: they are the princess room's, and **the dungeon's flames have
never been converted.**

★ **The §1 premise about the mechanism is also wrong, and inverting it is the most useful thing
here.** The dispatch read `opacity.s` beside `converted.s` as "masked sprites over an
already-converted background." **All nine sidecars say `OPAQUE throughout`**, and cite the oracle
line that settles it: `PSETUPFLAME` sets `OPACITY = sta`, a plain store [`GAMEBG.S:761`]. So the
cutscene's flame is **an opaque rectangle carrying its own black pixels** — which is *exactly*
P5.5's opaque-rectangle bake model, one level up. **The port already ships the animated-block model;
what it has not shipped is that model in a lit context.**

**AC3 — the seam is ZERO, and the mechanism does not earn it. The placement does.** Measured
exhaustively over every boundary-neighbour combination: **0 px differ when the adjacent pixels are
dark, 1–3 px of 91 when a neighbour is lit.** Both shipped torches sit with **dark boundary pixels
on all 13 rows**, so the shipped error is exactly zero. **A dungeon torch on a lit wall lands in the
1–3 px case.**

**AC8 — §5.228: P5.6's division does NOT survive if W1 is the character requirement, and the
animated blocks are not why.** The animated class is *cheap*: 6,105 B level-wide, and **the phase
multiplier is 1, not 4** — every block-aligned piece is phase 0 and every flame phase 3, on every
column of every screen. The problem is that P5.6 had already spent all 8 blocks. Characters at W1
plus their animated cels is 8 blocks; the tile page needs a ninth.

★ **One of the dispatch's figures I can confirm rather than correct:** the 28-block census
(11 torch, 5 spikes, 5 loose, 4 gate, 2 exit, 1 slicer) reproduces **exactly** from an independent
blueprint walk — after excluding the D-row of the screen above, which is what my first count got
wrong (31, not 28).

---

### 2 — Files modified

- `harness/tools/animated_blocks.py` — **new.** Sizes the 28 blocks per kind from the oracle's own
  tables, derives the phase multiplier, and finds the joint character+scenery maximum.
- `reports/20260822-020000-p5-7-...md` — this report.

Nothing under `src/`, `link/`, `content/`. `build.bat` untouched. No bake, no renderer.

---

### 3 — Reasoning

#### 3A — AC1: are they the same cels? Two questions, answered separately

*Authority: Mechner source for the tables; the vendored image files for the bytes.*

**QUESTION 1 — the ORACLE level: same table, same image numbers?** **No.**

| | dungeon torch | princess-room torch |
|---|---|---|
| setup routine | `SETUPFLAME` [`GAMEBG.S:735`] | `PSETUPFLAME` [`GAMEBG.S:758`] |
| image list | `torchflame` [`GAMEBG.S:147-148`] | `ptorchflame` [`GAMEBG.S:150`] |
| **table** | **`bgtable1`** | **`chtable6`** |
| distinct images | **9** — `$52 $53 $54 $55 $56 $61 $62 $63 $64` | **9** — `#1`…`#9` |
| cycle | 18 states | 18 states |
| plane | `ADDBACK` (background) | `ADDMID` via `initlay` (mid) |
| opacity | `sta` (opaque) | `sta` (opaque) |
| dimensions | 1–2 bytes × 15–16 rows | **1 byte × 13 rows, uniformly** |
| Apple bytes / CoCo3 bytes | 186 / **372** | 117 / **234** |

**Byte comparison: nine against nine, zero matches.** Not one princess flame equals any dungeon
flame.

**QUESTION 2 — the PORT level: are the port's flame bytes reusable for a dungeon torch?** **No, and
independently so.** Every one of the port's nine cels carries its own provenance:

```
* ORIGIN: IMG.CHTAB6.A
*         POP cel: #1 (1x13 bytes)
*   start_col=91  screen-col parity=ODD
```

They are the princess room's cels, converted **at column 91**. So the port-level answer fails twice
over: wrong source cels, and converted at a position a dungeon torch does not occupy. **The dungeon's
flames are unconverted work, not a reuse.**

★ **Why the shape matched anyway, which is the part worth keeping.** Nine frames, 18-state cycle,
opaque store, driven by the same `animtorch` state byte — Mechner wrote the same *animation* twice
against two different art sets. **The mechanism transfers; the pixels do not.** Jay's instinct was
about the right thing and landed one level off.

#### 3B — AC2: the cutscene's flame mechanism, from source

*Authority: source, plus the port's own generated sidecars.*

`PSETUPFLAME` [`GAMEBG.S:758-780`]: bounds-check against `torchLast+1` (18), take
`ptorchflame,x` into `IMAGE`, **`lda #sta / sta OPACITY`**, `jsr initlay`, point `TABLE` at
`chtable6`. The dungeon path is the same three moves with `torchflame`, `bgtable1`, and a `YCO`
adjustment of −43.

**`opacity.s` carries run-length regions, not a bitmask.** For every flame:

```
flame1_opacity_mixed:
        fcb     0,2,0,13,1      ; whole cel, opaque
        fcb     0,0,0,0,0       ; terminator
```

and the header states the reason rather than the format alone: *"PSETUPFLAME sets OPACITY = sta (a
plain store), so the oracle writes every pixel of the flame including its black ones. Keying them
lets whatever is behind show through, which is only invisible while the background happens to be
black."*

★ **So the sidecar exists to record that the cel is NOT keyed.** It is a decision receipt, not a
mask. The two stars (`star42`, `star43`) have **no `opacity.s` at all** — a third shape the
directory listing does not distinguish. **There is no masked blit in the cutscene's flames, so there
is no mask seam, and §3.1's question about "the boundary between written and unwritten" does not
arise.** The boundary that does exist is a *conversion* boundary, measured next.

#### 3C — AC3: the seam, measured

*Authority: exhaustive computation over the frozen colour model, plus the shipped room's own bytes.*

The port draws room-converted-once, then flame-converted-alone on top, opaquely. The oracle draws
flame-over-room in HGR, which would convert as one picture. The difference can only appear where the
conversion's context reaches across the cel's edge — **radius 1 pixel, measured exact over 24 screens
at P5.4.**

**Test:** convert `chtable6 #1` (1 Apple byte, 13 rows) in isolation at `start_col=91`, then convert
it again as the middle byte of a three-byte strip, over 25 neighbour pairs, and count differing
pixels in the cel's own 7×13 = 91-pixel footprint.

| left / right neighbour | differing pixels of 91 |
|---|---|
| both dark (`$00`, `$2A`) | **0** |
| one lit | 1–2 |
| both lit (`$7F`, `$FF`, `$55`) | **3** |

**Worst case 3 px of 91 = 3.3%, confined to the cel's edge columns.**

**Now the shipped case.** `ptorchx db 13,25` — Apple byte columns 13 and 25, i.e. pixels 91 and 175;
`+20` centring puts them at CoCo pixels 111 and 195, byte 27 and byte 48, both phase 3. Byte 27
matches `fb_region_diff.py`'s independently recorded torch box (`rows 104..113 cols 27..29`).
Reading `content/cutscene/princess_room.raw` at those positions:

```
torch0  rows 101..113, bytes 26..29 : 208 px, 208 dark (100%), 0 lit
        boundary pixels LIT on 0 of 13 rows   -> seam ZERO by placement
torch1  rows 101..113, bytes 47..50 : 208 px, 156 dark (75%), 52 lit
        boundary pixels LIT on 0 of 13 rows   -> seam ZERO by placement
```

> **★ AC3: the error is ZERO, and the reason is NOT that the mechanism avoids it.** Both torches
> happen to sit against dark pixels on every row, which is exactly the `left=$00 right=$00` case. The
> mechanism admits a 1–3 px error; the placement never exercises it. Torch1 is the instructive one:
> its neighbourhood is 25% lit, and the seam is still zero because the two pixels that decide it are
> not.

#### 3D — AC4: what Jay's cutscene gate actually covered

**It covered this art at this placement over this background.** He passed a room in which every
animated cel's boundary pixel is black on every row. That is a real pass and nothing here weakens it.

**What it did NOT establish**, and would be wrong to cite as if it had:

1. **Not that opaque animated cels are seam-free in general.** §3C measures 1–3 px per cel the moment
   a boundary pixel is lit.
2. **Not a calibration point for an accepted error.** The dispatch hoped for *"a measured error a
   human eye passed"*, and this project would benefit from one. **This is not it: the error is zero,
   so the gate says nothing about what Jay tolerates.** The calibration point does not exist yet.
3. **Not that the background composition transfers.** The cutscene's background is one fixed picture,
   converted once. A dungeon screen is composited from variants, and a torch sits *on a wall texture*
   — lit pixels, by construction. §4's placement is where the 1–3 px case becomes live.

#### 3E — AC5: the 28 blocks, sized

*Authority: the oracle's own tables, transcribed with source lines; `IMG.BGTAB1.DUN` for the bytes.*

**★ Every figure here is a SUM over the whole level, not a residency.** It is the distinct cel data
each kind can ever need. No frame is remotely this big — AC6 is the residency, two orders smaller.

| kind | placed | distinct cels | Apple B | **CoCo3 B** | source |
|---|---|---|---|---|---|
| torch | 11 | 9 | 186 | **372** | `torchflame` [GAMEBG.S:147] |
| spikes | 5 | 10 | 644 | **1,179** | `spikea`/`spikeb` [BGDATA.S:118] |
| loose | 5 | 7 | 220 | **394** | `loosea/b/d` [BGDATA.S:143] |
| gate | 4 | 19 | 441 | **882** | `gate8c/8b`, `gatebot*`, `gatecmask` [BGDATA.S:88] |
| exit | 2 | 4 | 378 | **693** | `stairs/door/doormask/toprepair` [BGDATA.S:110] |
| slicer | 1 | 14 of 17 | 1,387 | **2,585** | `slicertop/bot/bot2/frnt` [BGDATA.S:134] |
| **total** | **28** | **63** | **3,256** | **6,105** | |

**★ AND THE PHASE MULTIPLIER IS ONE, WHICH IS THE FINDING.** The reflex — the conversion is
position-dependent, so multiply by the phases a piece appears at — does not apply, for an arithmetic
reason:

> Block column *c* sits at Apple byte 4*c* = pixel 28*c*; the 280→320 centring adds 20.
> **28*c* mod 4 = 0 and 20 mod 4 = 0, so every block-aligned piece is phase 0.**
> `SETUPFLAME` does `inc XCO` [`GAMEBG.S:741`] = +7 px, so **every flame is at 28*c*+27, phase 3.**

Two phases exist across the entire class, and each kind uses exactly one, on every column of every
screen. **So 6,105 B is the storable figure, not 24,420 B.** This is precisely why the animated
blocks are cheap where the tile variants were not: **a tile variant multiplies by its neighbours; an
animated cel does not, because it is always drawn at the same offset inside its own block.**

**★ The 28-block census, independently reproduced.** Walking the blueprint gives
`torch 11, spikes 5, loose 5, gate 4, exit 2, slicer 1 = 28` — §5.211 exactly. My first count said
31, because `bg_compose`'s block record includes the **D-row of the screen above**, which re-reads
another screen's blocks. Excluding `rowno == -1` reproduces the dispatch's figure and drops screens 5
and 7 from the animated list entirely.

#### 3F — AC6: the pair, added at the frame that maximises it

*Authority: trace.*

Per-frame animated scenery, over the 262 frames of 266 that draw any: **min 21, median 216, p90 453,
MAX 836 B.**

```
★ THE JOINT MAXIMUM — largest (characters + scenery) over ONE frame:
   frame 9328:  characters 1,828 B + scenery 94 B = 1,922 B
      scenery  $62 torch   64 B
      scenery  $55 torch   30 B
```

**Frame 9328 is the sword fight** — the same frame P5.6 named as the character worst case. The
scenery peak is a *different* frame:

| | frame | characters | scenery | total |
|---|---|---|---|---|
| joint maximum | **9328** | 1,828 | 94 | **1,922** |
| characters peak | 9328 | 1,828 | 94 | 1,922 |
| scenery peak | 8177 | 682 | 836 | 1,518 |

> **★ THE ERROR THIS AVOIDS, quantified: adding the two per-kind maxima gives 2,664 B — +742 B
> against the real joint peak of 1,922 B.** The naive sum invents a frame in which the fight and the
> busiest scenery happen together, and no such frame exists in the run. §5.222's error, made concrete.

**1,922 B against the 15,872 B window: fits with 13,950 spare. Against one 8,192 B block: fits with
6,270 spare.**

#### 3G — AC7: where can they live?

*Authority: blueprint walk + P5.5's bake + P5.6's partition.*

**Not in the tile page's spare.** Per screen, page plus the animated cels that screen's blocks need:

| screen | animated blocks owned | page B | animated B | sum vs 8,192 |
|---|---|---|---|---|
| 1 | spikes ×2, torch ×3 | 7,280 | 1,551 | 8,831 **OVER** |
| 2 | gate ×1, loose ×2, spikes ×2, torch ×2 | 6,432 | 2,827 | 9,259 **OVER** |
| **3** | gate ×2, loose ×1, slicer ×1, spikes ×1, torch ×2 | 5,622 | **5,412** | **11,034 OVER by 2,842** |
| 4 | gate ×1, loose ×2, torch ×2 | 5,676 | 1,648 | 7,324 fits |
| 6 | exit ×2, torch ×2 | 7,582 | 1,065 | 8,647 **OVER** |

Only screens 1, 2, 3, 4 and 6 carry animated blocks at all. **Four of the five overflow**, and the
610 B of spare P5.6 quoted for the worst page is two orders short of screen 3's 5,412 B.

**Not in the character blocks' slack either.** P5.6's first-use partition packs them 98–99% full:

| block | char B | spare | animated cels its frames draw | animated B | fits? |
|---|---|---|---|---|---|
| 0 | 8,047 | 145 | 36 | 2,293 | **NO** |
| 1 | 8,183 | 9 | 35 | 2,233 | **NO** |
| 2 | 8,110 | 82 | 30 | 1,620 | **NO** |
| 3 | 7,922 | 270 | 12 | 556 | **NO** |
| 4 | 3,880 | 4,312 | 9 | 372 | yes |

★ **That is a packing artifact, not a limit** — the partition was built to minimise character blocks
and left no room by construction. Repacked **jointly**, characters and the animated cels each block's
frames need come to 36,142 + 7,074 = **43,216 B = 6 blocks** for the demo run.

**The honest constraint is co-mapping, and it is why this is not free.** Scenery is drawn on **262 of
266 frames**, so its cels must be visible in the *same* frame as the characters'. With two registers
that means a frame's characters and its scenery together must lie in ≤2 blocks — which is why the
animated cels have to be *duplicated into* each character block rather than given a block of their
own. Giving them a dedicated block would consume one register permanently, leaving one for
characters, and P5.6 §3C already proved one register cannot hold them (a 34,618 B component).

#### 3H — AC8: does P5.6's division survive? (§5.228 answered)

**With the demo run's character set: yes.** 6 blocks (characters + their animated cels) + 1 (tile
page) = **7 of 8, one spare.**

**With W1 as the character requirement: NO — over by one block.** Scaling the joint packing from the
run's 36,142 B to W1's 49,924 B, with animated duplication in proportion, lands at **8 blocks for
characters + scenery**, and the tile page needs a **ninth**.

> **★ §5.228 is answered: P5.6's division does not survive unchanged. And the animated blocks are not
> the cause — they are the straw.** The whole animated class is 6,105 B with a phase multiplier of 1,
> and its per-frame cost is 94 B at the joint peak. What breaks the division is that P5.6 had already
> committed all 8 blocks to W1 characters and one tile page, with **zero spare**, which its own §7.1
> flagged as having no margin to absorb an error. This is that error arriving.

---

### 4 — Phase 4: the proposal (AC9)

**What changes, stated as one sentence:** the tile page stops being permanently resident.

It is the only one of the three claimants that is **not needed during play** — §3D of P5.6
established that, and nothing here disturbs it. Characters are needed every frame; animated scenery
is needed on 262 of 266 frames; the tile page is needed on the room-change composite and never
again. **A block permanently held for something used once per room is the loosest byte in the
budget.**

Three ways to stop holding it, **costed, not chosen between:**

| option | cost | risk |
|---|---|---|
| **A.** Composite the screen directly from the packed page, expanded into the back framebuffer's own window during the room change | zero blocks — the buffer is about to be overwritten anyway | the composite must finish before the first flip; already true today |
| **B.** Keep the page resident but shrink characters to fit 7 blocks | needs W1 re-derived (P5.6 §8.1) | outside this dispatch, and the figure may not move |
| **C.** Accept one disk read per room change for a character block | a track read on a transition that already reads a track | doubles room-change latency |

**A is the one to measure first**, because the room change already has a black screen and a disk read
in it, and the page is already LZ-packed for exactly that path.

**WHAT I AM NOT PROPOSING:**

1. Not proposing to **build** any of it. No code, no bake change, no renderer change.
2. Not proposing to **choose** among A/B/C — they are costed so Jay can.
3. Not proposing to **convert the dungeon's nine flame cels**, though §3A shows that work is
   unstarted and unavoidable.
4. Not proposing a **seam remedy**. §3C bounds the error at 1–3 px per cel; whether that is
   acceptable on a lit dungeon wall is Jay's eye, and no port pixel exists to look at yet.
5. Not proposing to **re-derive W1** — §7 excludes it, and §3H is explicit that the answer hinges on it.
6. Not proposing **block recruitment as a decision**, the two-format ruling, the foreground plane,
   `AUTOCTRL`, sound, or anything past `LEVEL0`.
7. Not proposing the **joint repacking** as a mechanism — 6 blocks is a measurement of what fits, not
   a design for a packer.

---

### 5 — Verification (AC-by-AC)

- **AC1** — §3A. Oracle level and port level answered separately and labelled; **no** at both.
- **AC2** — §3B. `PSETUPFLAME` from source; `opacity.s` quoted; **opaque, not masked**.
- **AC3** — §3C. **Zero**, with the reason: 0 px on dark neighbours, 1–3 px on lit; both shipped
  torches have dark boundary pixels on all 13 rows.
- **AC4** — §3D. Three things the gate did not establish, including that **the hoped-for calibration
  point does not exist** because the error is zero.
- **AC5** — §3E. Per kind, with **SUM stated explicitly**, plus the phase multiplier derived as 1.
- **AC6** — §3F. Joint maximum **1,922 B at frame 9328**; the naive per-kind sum overstates by 742 B.
- **AC7** — §3G. Not the tile page's spare (screen 3 over by 2,842), not the current character
  partition's slack; joint repacking gives 6 blocks for the run.
- **AC8** — §3H. **Does not survive at W1 — over by one block.** Survives at the run's character set.
- **AC9** — §4, seven explicit non-proposals.
- **AC10** — §0. `git status --porcelain src/` → 0 lines.
- **AC11** — §0. Prod sha1 triple identical at both ends.
- **AC12** — **suites NOT run, and saying so.** Nothing was built: no source, link script, bake input
  or disk image changed, `build.bat` was not invoked, and the suites would have re-tested the exact
  artifacts P5.5 gated. The unchanged sha1 triple in §0 is the evidence.
- **AC13** — §6.

---

### 6 — Reactive deviations and route accounting

**Deviations:**

1. **I tested §1's mechanism claim and it inverted** (§3B). The dispatch flagged §1 as the
   Orchestrator reading a directory listing; the listing was real and the inference from it was not.
2. **I corrected my own block census mid-task** (§3E): 31 before excluding the D-row, 28 after, which
   is §5.211's figure. Recorded rather than silently fixed, because the first number was mine.
3. **AC3 was measured without an oracle capture.** The princess room's Apple HGR page is not in the
   tree — `hgr_screen_convert.py`'s header records that the room was dumped from the running oracle
   and only the *converted* result kept. So the seam was measured as a **conversion** property
   (exhaustive over boundary neighbours, then evaluated against the shipped room's own bytes) rather
   than as a runtime framebuffer diff. **This is a different measurement from P5.5's and I am saying
   so**; it bounds the error exactly and does not depend on flame-phase alignment between two
   machines, but it is not a captured port-vs-oracle pair.

**ROUTE ACCOUNTING.** No route was proposed in conversation before this task. Within it, one plan
changed: I intended to measure AC3 as P5.5 did — capture the oracle, capture the port, diff — and
abandoned it when the Apple-side room proved absent from the tree, substituting the conversion-space
measurement above. **Both the intent and the substitution are stated rather than the result being
presented as though it were the original plan.**

**This report contains:** AC1-AC13, one new analysis tool, no engine change.
**It does not contain:** any build, any code, any adoption, and none of §4's seven non-proposals.

---

### 7 — Uncertainty flags

1. **★ §3H's W1 scaling is an extrapolation, not a measurement.** The 6-block joint packing is
   measured on the demo run's 36,142 B. The 8-block figure for W1 scales the animated duplication in
   proportion, and **W1's cel set may duplicate differently** — its moves are ones the demo never
   made. The direction is robust (W1 > run, so ≥ the run's block count) but the exact block count is
   not measured.
2. **Three slicer cels are missing.** `slicerbot2`'s `$8E $8F $90` (the "smeared" high-speed variants)
   are in neither `IMG.BGTAB1.DUN` nor `IMG.BGTAB2.DUN`. The slicer figure counts **14 of 17** images
   and is therefore a lower bound. `LEVEL0` has one slicer, so the level total moves little, but the
   figure should not be quoted as complete.
3. **The seam measurement covers a 1-byte-wide cel at one phase.** `chtable6 #1` at `start_col=91` is
   representative of the princess flames (all nine are 1×13) but **not** of the dungeon's, which are
   1–2 bytes and 15–16 rows at phase 3. The 1–3 px bound follows from the radius-1 property and
   should hold, but it was measured on the cutscene's cel, not the dungeon's.
4. **Per-screen animated need assumes a screen holds every frame of each kind it contains.** A screen
   with one spike is charged all ten spike images, because it animates through them. That is correct
   for residency and **overstates** what any single frame needs — which is what §3F measures
   separately.
5. **262 of 266 frames drawing scenery is the demo's behaviour on the screens it visited.** A screen
   with no animated blocks (18 of 24 on `LEVEL0`) draws none, so the co-mapping constraint in §3G is
   not universal — it binds only on the five screens that have them.

---

### 8 — Follow-up candidates

1. **Measure option A** (§4): can the room-change composite run out of the packed page expanded into
   the back buffer's own window, freeing the tile block entirely?
2. **Convert the dungeon's nine flame cels** and produce the first port pixel of a lit-context
   animated block — that is what makes §3C's 1–3 px bound something Jay can look at.
3. **Re-derive W1** (P5.6 §8.1, excluded here). §3H turns on it: at the run's figure the division
   survives, at W1 it does not.
4. **Find `slicerbot2`'s three images** (flag 2), or establish that `LEVEL0`'s slicer never uses them.
5. **Get a real calibration point** (§3D.2). The project still has no measured seam a human eye has
   passed, and every fidelity argument would be better for one.

---

### 9 — User interaction during task

None.

---

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-22-a-zero-error-can-be-a-property-of-the-sample.md` — §3C/§3D: the
cutscene's zero seam comes from where the flames sit, not from what the blit does, and a gate that
passed on a zero-error sample yields no calibration point. Pushed to the pool as `75f1272`.

---

### 11 — Commit

Recorded in the push that carries this report to `origin/wip`. **`main` is untouched at `32b5fe2`.**
