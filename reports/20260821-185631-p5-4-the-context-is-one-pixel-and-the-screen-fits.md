## Form B Report — P5.4 (RECON + PROPOSAL) — the context is ONE pixel, the level dedups 11.85×, and the per-screen set fits the pinned page

**Class:** Phase 1 recon, Phase 2 proposal (**no code**). `wip`.
**★★ THE STOP IS OBSERVED. No engine code, no renderer, no bake change. `git status --porcelain src/`
→ 0 lines.**

### 0 — Receipt / status (C-35 stamp)

t0 = **2026-08-21T22:49:02Z**. HEAD **`6aefc53`**, branch **`wip`**.
**`main` resolved here: `32b5fe2` = `origin/main`. Not moved.**

Standing untracked set, named and untouched: `.vscode/`, `nvram/`, `POP-idioms-coco3-markers.md`,
`content/intro/broderbund_splash_render.bin`, `docs/project/pop-coco3-design-v0_7.pdf`, the
nineteen files under `docs/ground-truth/`; plus the one modified tracked file
`dist/mame-cfg/rgb/coco3.cfg`.

**Prod sha1 — identical at receipt and at the end (AC8). Nothing rebuilt:**

```
d07f1f3295525783968dcce6409ee1b64942231c  build/intro_seq.bin
0b4968867bf5274d2942f3b5b90ea855ad6f2def  build/loader.bin
790836577e56b61b8f849cb309874e44304840a2  build/cutscene_room.bin
```

### 1 — Summary

**§2.1's hypothesis is refuted and the truth is better than it.** The dependence is **not** leftward
only — `run_len == 1` looks one pixel right and the colour-cell fill reads the classified index at
`c±1`. But the reach is **tiny**: reasoned bound two pixels each side, and **measured, radius ONE is
exact on all 24 screens of `LEVEL0`** (radius 0 costs 5,521 pixels). So a tile's conversion is
determined by its own pixels plus one neighbour pixel per edge — **a classifiable context, not a
per-placement one**, and that is why the census dedups so hard: **699 display-list entries → 225
per-screen variants → 59 distinct across the level, 11.85×.**

**★ The two figures, kept apart:** the **per-screen maximum is the residency requirement** — screen
6, **6,466 B raw**, which **FITS the pinned page with 1,726 B spare**. The **level total is a sum** —
14,028 B raw, which does not fit the pinned page but does fit both pages with 1,844 spare. **So
§1.1's warning was right about the level total and wrong about what binds: no screen overflows.**

**Two corrections to the dispatch's assumptions.** The **segment-stream form is 1.42× LARGER than
raw**, not smaller — measured and decomposed: skips do save 2,548 bytes on the worst screen, but
merges cost 1,752 extra and per-row headers 1,980. And **B's "unbudgeted ~1,920-entry display list"
is 699 entries for the whole level, 76 for the worst screen — 228 bytes**, not a burden.

**Recommendation: B**, with the **raw** form, **per screen**, in the pinned page — which is exactly
the shape already gated, with one extra table. **D is rejected on a mechanism the dispatch did not
raise:** it converts a whole screen at once, and moving scenery needs blocks redrawn *per frame*, so
D does not remove the variant problem — it narrows it to the animating pieces and adds a
0.15–0.9 s room-change cost. **A fifth candidate, E, was measured and is worse than B.**

### 2 — Files modified

Explicit-path staging. **Nothing under `src/`, `content/`, `link/` or `build.bat`.**

- `harness/tools/context_radius.py` — **new.** Measures the conversion's true reach.
- `harness/tools/variant_census.py` — **new.** The whole-level (image × context) census.

### 3 — Reasoning

#### 3A — AC1: the context bound, from the contract and then measured

**The hypothesis is refuted.** From `sprite_convert.py:103-131` and `:180-210`, each ON pixel is
classified from `(pos_in_run, run_len, gap_before_run, pal_bit)` and used as:

```
run_len == 1                  -> chroma at the pixel's own screen-column parity
pos_in_run == 0 and gap == 1  -> chroma at col-1, WHITE at col
otherwise                     -> WHITE
```

| direction | what needs it | distance |
|---|---|---|
| **RIGHT** | `run_len == 1` — does the run end immediately? | **1 pixel** |
| **RIGHT** | the colour-cell fill reads `src_indices[c+1]`, itself a classified value | **2 pixels** |
| **LEFT** | `pos_in_run == 0` — is this the run start? | 1 pixel |
| **LEFT** | `gap == 1` needs `prev_run_end == run_start-2` | 2 pixels |
| **LEFT** | the fill reads `src_indices[c-1]` | 2 pixels |
| **neither** | the screen-column parity comes from `start_col` — the **placement**, not a neighbour | — |

★ **`pal_bit` looks unbounded** — bit 7 of the byte containing the *run start*, which may be far
left — **but it is only read in the two branches that require the pixel to BE the run start**, so in
practice it comes from the pixel's own byte. *That is the one place the contract could have made
the context unbounded, and it does not.*

**Measured** (`context_radius.py`): the whole 280-pixel row converted at once, against 28-pixel tile
blocks converted with N pixels of true context each side, over **every row of all 24 screens**:

| radius | differing pixels | differing rows |
|---|---|---|
| **0** | **5,521** | 1,020 |
| **1** | **0** | **0 — EXACT** |

> **★★★ RADIUS 1 IS EXACT. The reasoned bound is 2; design to 2, since it costs nothing and the
> contract, not the sample, is what guarantees it.**

**This is the finding the rest of the dispatch rests on.** A context of one pixel per edge is a
*classification*, not a placement — which is why 699 entries collapse to 59.

#### 3B — AC2: the dedup (`variant_census.py`)

**The model being counted, stated because counting needs one and designing one is out of scope:** a
variant is the **converted composited page's** pixels over the cel's bounding box — shape from the
cel, colour from the page. **`sta` entries paint their whole box including black; `ora` entries
leave index-0 alone.** *That opacity distinction is not cosmetic: treating every entry as
transparent — which my first cut did — turned 51 of screen 1's 76 entries into merge segments the
oracle never performs, and moved the level total by 2,559 bytes.*

```
display-list entries, all 24 screens : 699
variants summed per screen           : 225   (3.11x within screens)
DISTINCT variants across the LEVEL   :  59   (a further 3.81x across screens)
overall                              : 699 -> 59   (11.85x)
```

**62 AND/mask entries are excluded and counted, not absorbed** — there is no bitwise AND on palette
indices; the blitter's `$C0` merge segment is where they would go and designing that is out of scope.

#### 3C — AC3/AC4: the two figures, and which binds what

> **★★★ THE PER-SCREEN MAXIMUM IS A RESIDENCY REQUIREMENT** — only one screen composites at a time
> and a room change rebuilds. **THE LEVEL TOTAL IS A SUM** — what the disk carries, or what a design
> that never reloads would hold. **They are different numbers over different extents.**

| | raw | segment |
|---|---|---|
| **per-screen MAX (residency)** — screen 6 | **6,466 B** | 9,207 B |
| per-screen median | 1,521 B | 2,311 B |
| per-screen min (screen 15, one entry) | 54 B | 90 B |
| **LEVEL TOTAL (sum)** | **14,028 B** | 20,244 B |

| figure | vs pinned 8,192 | vs both pages 15,872 |
|---|---|---|
| **per-screen max, raw** *(residency)* | **FITS, 1,726 spare** | FITS, 9,406 spare |
| per-screen max, segment *(residency)* | OVER by 1,015 | FITS, 6,665 spare |
| level total, raw *(sum)* | OVER by 5,836 | **FITS, 1,844 spare** |
| level total, segment *(sum)* | OVER by 12,052 | OVER by 4,372 |

**The full distribution** (entries / variants / raw B / segment B / blocks placed):

```
 1: 76/27/5454/8269/25   2: 67/24/5099/7787/20   3: 66/21/4224/6106/20
 4: 75/22/5065/7404/26   5: 70/19/4226/5709/25   6: 69/31/6466/9207/21
 7: 72/16/3699/5446/28   8: 50/10/1521/2311/17   9: 22/13/2367/3733/6
10-14: empty            15:  1/ 1/  54/  90/ 0  16-22: 7/3/542/993/0 each
23: 16/ 4/ 530/1002/ 0  24: 66/16/3289/5481/22
```

**The worst screen is 6, named by content:** 21 blocks placed, 69 entries, **31 variants** — the
most *varied* screen rather than the most crowded (screen 7 has 28 blocks and only 16 variants).
Variety, not density, is what costs.

**★ §1.1's extrapolation held up.** ×1.81 from screen 1 predicted ≈13,036 B for the level; measured
**14,028 B raw**, 7.6% low. Against P5.1's context-free 7,202 B the true level-wide ratio is **1.95×**.
**And §1.1's conclusion is confirmed:** *"the whole level's tiles fit the pinned page"* is **unsafe
and now refuted** — 14,028 does not fit 8,192. **But no screen overflows, and the screen is what
must be resident.**

#### 3D — ★ AC4, corrected: the segment form is LARGER than raw, not smaller

The dispatch expected the segment-stream figure to be lower *"since screen 1 is 54% black and
`blit_core.s:41-48` skips index-0 runs."* **Measured, it is 1.42× larger.** Decomposed on screen 6
(31 variants, 990 rows, 6,466 B raw):

| | bytes | cost |
|---|---|---|
| **skip** | 2,548 | **0** — the intuition was right, and it saves 2,548 |
| **blast** | 2,166 | 1:1 with raw |
| **merge** | 1,752 | **2:1 — costs 1,752 EXTRA** |
| per-row header + `SEG_END` | — | **2 × 990 rows = 1,980** |

**The black is BETWEEN the tiles, not inside their bounding boxes.** A tile's box is mostly opaque,
so skips are rare inside it, while every partially-lit byte becomes a 2-byte merge and every row
pays two bytes of framing. **For opaque background tiles the raw form is the cheaper
representation** — the opposite of the character case the format was designed for.

#### 3E — AC5: the candidates, costed

Resident / disk / room-change, for `LEVEL0`. **Room-change time excludes the disk seek**; §5.181
measured a room change as one frame and **no** disk read in the oracle.

**A — display-list-keyed table.** ~76 entries/screen × 24, run-time piece-id resolution retained,
the table mapping position → variant. **Resident:** one screen's variants (6,466 B worst) + a
76-entry position table. **It does not avoid the variants** — it only changes how they are indexed —
so it is B with a worse table. **Rejected: strictly dominated by B.**

**B — bake-time de-duplication, per-entry variant ids. ★ RECOMMENDED.**
**Resident, worst screen:** 6,466 B variants + 2 B magic + 31×2 B variant table + 76×3 B display
list = **6,762 B of 8,192 — fits with 1,430 B spare.** For **screen 1** specifically (Phase 3's
scope): 5,454 + 2 + 54 + 228 = **5,738 B, 2,454 spare.**
**Disk:** 59 variants, 14,028 B raw + 699×3 B of display lists = **16,125 B ≈ 4 tracks.**
**Room change:** one page read (≤6,466 B ≈ 2 tracks) — *or none at all*, since the level total of
14,028 B fits both pages with 1,844 spare, at the price of leaving nothing for characters.
**★ The dispatch's unbudgeted second-order cost is 228 bytes**, not 1,920 entries: 699 entries for
the whole level, 76 for the worst screen, three bytes each (variant id, x, y).

**C — runtime seam correction.** The radius-1 finding makes this far cheaper than the dispatch
assumed — the wrong pixels are confined to one pixel each side of every block seam. But **correcting
them requires the classifier**: to know what a seam pixel should be you must re-run run/gap/fill
across the boundary, which is the conversion, at run time, per screen. It trades bake-time bytes for
run-time cycles **and code that already exists in Python and would have to exist twice**. **Rejected
on one-home grounds, not on cost.**

**D — composite in HGR, convert once.**
**Buffer:** an HGR page is 8,192 B; `demo-memory-map.md §3` gives a free run of **20,072 B at
`$1B98-$69FF`**, so it lives in CPU RAM with room to spare — no MMU window needed, which matters
because windows are the scarce resource.
**Time:** 53,760 pixels per screen. Per-pixel classification at 15–30 cy is **0.8–1.6 M cycles =
27–54 video frames = 0.45–0.90 s**. ★ **The radius-1 finding admits a table-driven form** — a lookup
keyed on (byte, one context pixel each side, parity) — which collapses it to roughly 8,192 lookups,
**≈8–11 frames ≈ 0.15 s.** *Both are estimates with their basis stated, not measurements; measuring
would need a prototype, which is out of scope.* For comparison, P3.17 records Jay calling a 15-frame
reveal delay *"a visible delay but not horrible."*
**Fidelity:** D reproduces `bg_compose` **by construction**, so port-vs-compositor becomes worthless
as a check [§5.183] and **port-vs-oracle is the only real one.**
**Pipeline scope:** background only. **Character cels keep their existing per-cel conversion** — they
are drawn over a finished background and never composited in HGR.
**★★ AND THE MECHANISM THAT REJECTS IT, WHICH THE DISPATCH DID NOT RAISE.** D converts *a whole
screen at once*. That works only while the background is static. **Moving scenery — the torch
flames, gate bars, spikes, the slicer, loose floors — needs its blocks redrawn per frame**, and a
per-frame block redraw needs a 4-colour cel for that block, which is a context variant again.
`LEVEL0` places **28 such blocks** (11 torch, 5 spikes, 5 loose, 4 gate, 2 exit, 1 slicer). **So D
does not dissolve the variant problem; it narrows it to the animating pieces and buys that with a
per-room-change conversion.** It is a real option for a *static* screen and a partial one for
gameplay, and that asymmetry is the argument against adopting it now.

**E — per-cel context-free cels plus a per-screen SEAM PATCH.** *Not in the dispatch's list; measured
because the radius-1 finding suggests it.* Keep P5.1's 7,202 B of context-free cels resident for the
whole level and ship a patch of the framebuffer bytes that differ.
**Measured patch sizes:** max **1,103 bytes** (screen 7), median 473, min 27; as `(offset16, value8)`
triples that is **3,309 B worst, 1,419 B median**.
**Resident:** 7,202 + 3,309 = **10,511 B — over the pinned page, needs both.** **Worse than B on the
figure that binds**, and it also re-introduces the two-representation problem C has. **Rejected.**

#### 3F — AC6: the recommendation, and what is NOT proposed

> **★ RECOMMEND B: bake-time de-duplication with per-entry variant ids, the RAW form, PER SCREEN,
> in the pinned page.** For screen 1 that is **5,738 B of 8,192, 2,454 spare**; for the worst screen
> **6,762 B, 1,430 spare**. It is the shape already gated — one pinned page, `cel_pg_sig = 0`, zero
> rotations — **plus one table and a 228-byte display list.**

**Not proposed, so the gate stays bounded:**

1. **No character paging.** P5.1's W1 49,742 B is untouched.
2. **No block recruitment** (`$02/$03/$06/$07`).
3. **No claim past `LEVEL0`.** A palace bgset, or a level with more varied rooms than screen 6, is
   unmeasured.
4. **No answer for the 62 AND/mask entries.** The `$C0` merge segment is where they belong; that is
   a bake design.
5. **No segment-stream encoding change**, even though §3D shows it is the wrong representation for
   opaque tiles. Choosing raw for tiles and segments for characters is a two-format decision and
   belongs to whoever rules on the bake.
6. **No room-change read design.** Whether the level is fully resident (14,028 B in both pages, no
   read, no room for characters) or per-screen (one read per room change) is a gameplay-shaped
   choice and Phase 3 needs neither — it draws one screen.
7. **No prototype, so D's conversion time is an estimate.** If D is ever preferred, that number must
   be measured before it is believed.

### 4 — Verification (AC-by-AC)

- **AC1** — §3A. Hypothesis **refuted**; two-sided; leftward distance 2, rightward 2, `pal_bit`'s
  apparent unboundedness resolved; **measured radius 1 exact over all 24 screens.**
- **AC2** — §3B. 699 → 225 → **59**, 11.85× overall, with the per-screen and cross-screen factors
  separated; raw and segment bytes both given.
- **AC3** — §3C. **Per-screen max 6,466 B raw stated as the RESIDENCY requirement; level total
  14,028 B stated as a SUM**, each labelled in the tool's own output as well as here.
- **AC4** — §3C, §3D. Both against 8,192 and 15,872; full 24-screen distribution; worst screen 6
  named by content (21 blocks, 31 variants — variety not density); **the segment-form surprise
  measured and decomposed.**
- **AC5** — §3E. Five candidates costed in resident bytes, disk bytes and room-change time; D's
  buffer location (`$1B98`, 20,072 B free), conversion cycles (two regimes, both labelled estimates)
  and pipeline scope (background only; characters unchanged) all stated.
- **AC6** — §3F. Recommendation **B**, with seven exclusions.
- **AC7** — **STOP OBSERVED.** `git status --porcelain src/` → 0 lines.
- **AC8** — §0. All three sha1s identical at receipt and at the end.
- **AC9** — **suites not run, and not required**: nothing was built and no build input changed, so
  they would re-report P5.2's result unchanged. Stated rather than omitted.
- **AC10** — §5.

### 5 — Reactive deviations and route accounting

**Deviations:**

1. **A fifth candidate (E) was measured and added**, per §6's *"if a fifth candidate is obviously
   better, that finding outranks this dispatch."* It is not better; it is reported anyway, because
   the negative is the useful part.
2. **The segment-stream expectation is corrected** (§3D), with the decomposition rather than the
   bare number.
3. **The dispatch's "~1,920 entries" for B is corrected to 699 for the level / 76 per screen**
   (§3E).
4. **My own P5.3 figure is corrected**: screen 1 was reported as 35 variants / 6,211 B; with the
   `sta`/`ora` opacity distinction it is **27 variants / 5,454 B**. The earlier figure treated every
   entry as transparent.

**ROUTE ACCOUNTING.** No route was proposed in conversation before this task. **What was released
versus what was built:** the dispatch asked for a census and a proposal and got both; **no build was
attempted, no `src/` file exists, and the recommendation is a recommendation, not an implementation.**
Nothing from §5's out-of-scope list was touched.

### 6 — Uncertainty flags

1. **Radius 1 is measured on `LEVEL0` dungeon tiles only.** The contract's bound is 2. **Design to
   2**; a palace bgset or character cels could exercise the second pixel.
2. **The bake model is mine, not a gated design** (§3B). A different transparency rule for `ora`
   entries would move the variant count and the byte totals.
3. **The 62 AND/mask entries are excluded from every figure.** They are ~8% of the 761 total
   entries; their eventual encoding will add to both the variant count and the bytes.
4. **D's conversion time is an ESTIMATE**, at 15–30 cy/pixel or a table-driven ≈8–11 frames. Neither
   is measured and the difference between them is 5×.
5. **`sta` variants include their own black**, so two `sta` cels that overlap store the same
   background twice. A bake that ordered them could dedup further; the census does not model that
   and its figures are therefore upper bounds within its model.
6. **Screen 6 is the worst of 24 screens of one level.** §3F exclusion 3.
7. **Carried, untouched:** the placement question for `demo-behaviour.md`; the build's path
   contamination; the `.gitattributes` residual; the HAL audit items; the palette's two homes; the
   mislabelled 58,026 cy figure; `chtable7`/`chtable2`; P5.2's 4 unexplained w/h mismatches.

### 7 — Follow-up candidates

1. **The gate on §3F's recommendation.** Phase 3 of dispatch 154 becomes releasable with one
   addition to what was already gated: a variant table and a 228-byte display list.
2. **The two-format question** (§3F exclusion 5) — raw for tiles, segments for characters. The
   measurement is in §3D; the decision is not made here.
3. **Re-measure P5.0/P5.1's tile storage** under whichever bake is chosen; both assume context-free
   cels and are lower bounds.
4. **If D is ever revisited**, measure the conversion rather than estimating it, and note that the
   28 animating blocks of `LEVEL0` are the part it does not solve.
5. Everything from P5.3's follow-up list still stands.

### 8 — User interaction during task

None.

### 9 — Candidate(s) captured this task

`seeds/POP/live/2026-08-21-measure-the-radius-of-a-dependence-before-pricing-it.md` — committed
and pushed to the pool (fire-and-forget). *A dependence with a bounded reach turns 'per-instance'
into 'classifiable': one pixel of context collapsed 699 placements to 59 variants, and the term
that looked unbounded was only ever read where the distance collapses.*

### 10 — Commit

See the commit that carries this report, pushed to `origin/wip`. **`main` was not moved.**

---

## ★★ STOPPED. NO ENGINE CODE. AWAITING A RULING ON §3F.
