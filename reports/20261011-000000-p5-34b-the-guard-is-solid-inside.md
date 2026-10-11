## Form B Report — P5.34b — the guard solid inside: two §2I divergences from MASKTAB, by Jay's rulings
**Class:** build. wip. Prod byte-identical (the four sha1s as at P5.34's t0). `main` `32b5fe2`. Follows
`reports/20261010-141727-p5-34-xf-blit-carries-the-mask.md`, whose gate failed on occlusion.

### 0 — Receipt / status
Basis: P5.34's 25.3 — Jay: *"speed is fine, but there are still inner areas of the guard that are
tarnsparent"*; then his rulings **"b"** and **"2"**. HEAD at start `187e84c` (wip).

### 1 — Summary
The port drew the oracle's mask exactly (P5.34), and the see-through spots Jay saw are the oracle's own:
(1) **one-pixel seams at the 7-px Apple source-byte boundaries** — MASKTAB is applied per byte alone
[HIRES.S:954/1480], so a border never crosses one (CHTAB4.GD #20: 14 px, a line down column 14); (2) **pockets
closed above and below** — the mask works sideways only (#20: 5 px at rows 26-28 after (1)). By Jay's rulings,
both are now filled — **two deliberate §2I divergences from MASKTAB**, in the bake and the prediction only;
`xf_blit` and `blit_cel` unchanged. Enclosed transparent pixels in the guard's three frames: **0**.

### 2 — Files modified
- `harness/tools/char_mask.py` — `cleared(..., cross_bytes=True, fill_pockets=True)`: after the LITERAL
  per-byte MASKTAB route, a byte-boundary rule (lit bit 6 → next byte's bit 0, and the reverse) and a
  breadth-first flood from the grid edge (`_pockets`). Both flags documented as divergences; `False/False` is
  MLayMask as written.
- `harness/tools/bake_chars.py` — `border_rows`: dilation along the WHOLE row (not per byte), then enclosed
  transparent components found by union-find and filled. A different route to the same set.
- `content/chars/**/<tab>_<nnn>_p0.s`, `content/chars/char_cels.s` — re-baked. **No `_src.s` changed.**

### 3 — Reasoning
- **The order kept** (P5.33's): each time the PREDICTION moved first and failed against the standing bake —
  cross_bytes: **359/418 cels differ**; fill_pockets: **140/418** — and then the bake moved: **0/418**.
- **Why the Apple bits alone decide the silhouette:** every non-zero converted pixel lies in the dilated set
  (sprite_convert's chroma pixel sits at col-1 of a lit run; its colour fill needs non-zero neighbours, one of
  which must be lit), so pockets are found on the mask, not on the colours.
- **Mirror:** both rules are symmetric, so xf_blit's runtime mirror of the bake equals the prediction's
  mirrored route — byte-exact at every mirrored probe case.
- **Authority:** the seams and pockets are SOURCE facts (the oracle has them); filling them is Jay's ruling
  under CLAUDE.md §2I — the port looks right on the CoCo3's RGB, where a 1-px gap reads as a hole that the
  Apple's NTSC smear probably hid. The divergence is written where a reader of either file hits it.

### 4 — Verification
- Offline: 418/418 baked streams == `char_mask.compose` (BFS route vs union-find route).
- Enclosed transparent pixels: CHTAB4.GD #20 **14 → 5 → 0**, #8 5 → 1 → 0, #19 8 → 3 → 0; kid #8 1 → 0.
- Transform probe: **4,720/4,720** (2,360 xf_blit + 2,360 baseline), one run on its own (§6).
- Kid run, 13 steps: **15360/15360 each**; both-opaque cells 73+118+112+39+7+118 = **467, 0 wrong**; the
  guard's frame 0 wrong at all 13.
- P5.32's broken control on this bake: steps 15/16/17/19/21/40 wrong by **48/52/43/34/5/52 B, all inside the
  guard**; 12/22/46 exact — still discriminates. Source restored (`AC77A36A…`, no diff).
- Suites: 512 KB introseq, integ, tile, char, kidrun **ALL PASS**; 128 KB tile PASS.
- Prod: the four sha1s unchanged.

### 5 — Verdict-time evidence
**Size (§5.338's unit):** gameplay 290 — 97,170 B stream → **42,519 B LZ → 10 tracks** (P5.33's 43,723; the
fills turn merge runs into blasts); guard sets one run — **22,974 B → 5 tracks** (66 B under, back inside
§5.341's reservation).

**Cost (true clock 0.89 MHz, paced budget 6 × 14,930 = 89,580 cy):** one actor 46,753 (52%, worst 65%), two
actors **78,471 (88%, worst 90,664 = 101%)**; cadence **9.85 fps** two actors (oracle 9.65), 9.99 one. The clock
defect (P5.34 §top: tile_probe never restores $FFD9) is unchanged and still the follow-up that halves this.

**25.3: pending Jay** — live-disk, 512 KB, RGB, motion: does the guard look solid as the kid passes behind him.

### 6 — Deviations and route accounting
- **An instrument collision, mine:** a superseded probe run (the cross_bytes-only bake) was still running when
  the final one started; both copy batches through `build/xform/xf_gen.s`, so the final run assembled the old
  run's batch (`Undefined symbol c_chtab2_6_r00`). Stopped the old run and re-ran alone: 4,720/4,720.
- **I force-stopped a MAME process to clear it — it was P5.34's live gate window**, still open after Jay's
  verdict. Nothing lost; said to Jay at the time.
- Route: Jay ruled (b) then "2"; this contains both, nothing else. Not proposed: hole-filling beyond enclosed
  pockets (open concavities stay transparent, as the oracle's), any cutscene change, the clock fix.

### 7 — Uncertainty flags
- The oracle's own appearance at these pixels on real NTSC hardware is inferred, not observed.
- Worst two-actor step 101% of the pace at the true clock (unchanged in kind from P5.34).

### 8 — Follow-up candidates
1. Restore `$FFD9` after tile_probe's disk read (P5.34 §8.1).

### 9 — User interaction
"b" (cross the byte boundaries); "2." (also fill enclosed pockets).

### 10 — Candidate(s) captured
None.

### 11 — Commit
(the follow-up commit carries this line)
