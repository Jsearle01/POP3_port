## Form B Report — P5.30 — the foreground plane drawn after the kid (Ruling 1, at the gate); Ruling 2's artifact does not exist at any real context we can composite

**Class:** build. `wip`. **Prod byte-identical** (§0). `tile_probe.bin` is **unchanged**; `probe.dmk` and
`char_probe.bin` moved. **Status: AT THE GATE for Ruling 1. Ruling 2 is reported, not pictured (§3D);
it needs Jay's direction before anything is built for it.**

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-10-10T09:48:28-04:00 (HEAD **`e7b76c8`**, wip, as the dispatch was drafted; `main`
**`32b5fe2`**). Tracked tree clean.

**AC1 — receipt vs a full rebuild at the end:**
```
08bcae4a6249828a64554c61db9ed7ace72e4081  intro_seq.bin      IDENTICAL
10bddbd5413d14b1fbf26aeadb874515fc32b3e8  loader.bin         IDENTICAL
d5b17b6d468f1bcdd66163a60d9ffa1e36197e15  cutscene_room.bin  IDENTICAL
92dc6d96778c71056ca37524779a5bcd1d61643c  flame_cels.bin     IDENTICAL
b7751d2f1aabc9bbfb86b8ee29b9996174c89140  tile_probe.bin     IDENTICAL   (the renderer ignores the new list)
6c8d6e98... -> aea3312060457779eaf5b747d5f8a4033a9a6141  probe.dmk       track 34's packed page now carries the fore list
2cdb3efd... -> 1998f2bce69ee0e5a45d1261182272fc09747d81  char_probe.bin  the fore pass, two new draws
```
**AC11 — `main` = `32b5fe2` at both ends.**

---

### 1 — Summary

**Ruling 1, plane ordering: built and predicted exactly.**
- **The page now carries a foreground list.** It names the variants the page already holds for each
  DRAWFORE entry, plus edge masks.
- **The character probe draws back → kid → foreground**, and a flattened control kid after it.
- **On screen 1's bottom row:**
  - `behind` overlaps the `$83` wall of block column 5, and the wall hides **33 bytes** of him;
  - `control` stands in front of the `$83` of block column 1, where the foreground pass would have
    hidden **9 bytes**.
- **Both match the offline prediction exactly: 15,360 / 15,360.** The tile probe's picture is
  unchanged, also 15,360 / 15,360.
- **Cost: +97 B** of list. The dispatch priced +774 B; the pixels were already in P5.5's page
  (§3A).

**Ruling 2, the 14.3% gate bar: measured at its real context, the artifact is 0 px.** It is 0 px at
all four `$46` placements in LEVEL0. The bar sits on BLACK in the composite, because the lit thing
that would surround it is the gate's own state-dependent B-section, which `bg_compose` does not draw.
P5.8's 14.3% was the worst of 25 synthetic contexts. Two further corrections:
- **`$46` is static**, the gate block's `drawfrnt` front piece. It does not move with gate state, so
  the "~8 states × 4 gates ≈ 3,840 B" premise does not apply to it. Its per-context cost is **282 B**
  for LEVEL0 (**+0 in the page bake**, which already holds it).
- **Posts `$45` do show a real artifact as keyed sprites: 21–29 px, all black↔lit.** But the oracle
  draws them `sta`, so nothing would key them; the page bake is exact for them at no cost.

**There is no picture that poses Ruling 2 as the dispatch framed it, so I did not build one** (§3D).

Phase 4 (all three items, each cheap):
- **`char` is now a suite.**
- **PNGs work without PIL.** The palette bug that would have stopped them even with PIL is fixed.
- **Six `ROOT` literals are derived from the file.** And **`C:\Projects\POP3_port` turned out to be a
  junction to this tree**, so P5.29's "stale clone" hazard was wrong (§3E).

---

### 2 — Files modified

- `harness/tools/bake_screen.py` — the FOREGROUND list (format and limits in its header): `fore` from
  `bake()`, `replay_fore()`, the fore-pass verify, `--omit`.
- `src/engine/fore_draw.s` — **new**: the 6809 foreground pass.
- `src/engine/char_probe.s` — the plane byte (+10), two walks with `fore_draw` between them.
- `harness/tools/char_probe_plan.py` — the prediction in plane order; `expect_fore` clearance.
- `harness/tools/char_probe_regions.py` — the `plane-swap` control.
- `content/chars/probe_place.json` — `behind` (mid) and `control` (flat).
- `harness/tools/gate_probe_plan.py` — **new**: Ruling 2's measurement and price (§3D).
- `build.bat` — `fore_draw.o` assembled and linked into the character probe.
- `harness/smoke/run_suites.sh` — `char` added (512 KB only, per CLAUDE.md §2K).
- `harness/tools/render_fb.py` — a standard-library PNG writer; the 4-byte palette accepted.
- `harness/tools/{cel_link,cel_table,bake_scene,bake_walk,beat_recost,gen_cel_table}.py` — `ROOT`
  derived from the file.
- This report.

**Not committed**, written and removed in-task: `src/engine/gate_probe.s` and `GATE_PROBE` /
`PAGE_PRELOADED` switches in `tile_probe.s`, the gate-bar probe dropped at §3D's finding.
`tile_probe.s` is byte-for-byte its committed text.

---

### 3 — Reasoning

#### 3A — Phase 1: the plane split (AC2, AC3)

*Authority: source for the plane (P5.8 §3C, DRAWALL decoded from live memory); the bake's own verify
for the data.*

**The display list is untouched, and the foreground becomes a second list beside it.** P5.5's page is
the WHOLE finished screen, back and fore flattened, so the pixels every foreground piece needs over a
character are already in it. The fore list is 1 + 6 B per entry: the variant id of the rectangle
already in the page, x, y, a left and a right **edge mask** that confine a redraw to the piece's own
7·w pixels, and a flags byte (bit 0 = keyed). `tile_probe.s` reads only the display list, so **its
binary does not move and its picture does not change** (tile suite EXACT).

```
BAKE — LEVEL0 screen 1, bgset DUN
  display list    80 x 3           240 B
  foreground list 1 + 16 x 6        97 B   (P5.30; its pixels are variants already above)
  page total                      7377 B of 8192   FITS, 815 spare            [was 7,280; LZ 1,390 -> 1,468 B, still 1 track]
  VERIFY — replay vs hgr_screen_convert's framebuffer:            15360/15360 -> EXACT
  VERIFY — finished page + the fore pass redrawn over it:         15360/15360 -> EXACT   (16 fore entries, 0 keyed)
```

**AC2 — +774 B against what was built: +97 B.** P5.8 §3H priced `$83` (420) + `$45` (354) as cel data
"new to the budget". In the page model that data was paid at P5.5: screen 1's fore entries point at
**six existing variants, 2,454 B** (five `$83` variants of 420 B and the `$45` at 354 B). **The `$83`
pieces are five variants, not one:** the finished page colours a wall front's edge pixels by its
neighbours, so the bake already holds them per context. **The split's own cost is the list.** The cast
blob is untouched: no stream changed, and the list lives in the tile page on track 34, not in the
cast (§8 of the dispatch: the 46 B margin stands).

**AC3 — no per-piece plane table.** The list is SURE's assignment for one static screen, every
`jmp add` piece in the background [FRAMEADV.S:53]. **The general case is NOT solved:** FAST re-points
the plane per dirty-buffer class [FRAMEADV.S:399-439; P5.8 §3A], so a running engine's plane
assignment is not this list. Stated in `bake_screen.py`'s and `fore_draw.s`'s headers.

**A limit this list carries, stated in both headers.** A KEYED fore piece (`ora`/`mask`, e.g. `$46`)
is redrawn OPAQUE from the finished page. That is exact with nothing behind it, and wrong where a
character stands behind its transparent pixels. Screen 1 has no keyed fore pieces; screen 2 has the
`$46` pair. A character behind a gate bar needs a keyed per-context draw, which is not built.

#### 3B — Phase 2: the draw (AC4, AC5)

*Authority: the prediction (tool); Jay for whether it looks right.*

**Order, as DRAWALL's:** `char_probe_draw` walks its list for the MID draws, calls `fore_draw`, then
walks it again for the FLAT draws. That is DRAWMID sixth and DRAWFORE seventh [GRAFIX.S:485-505],
with the control after.

**The two new draws** are frame 15 (`stand`), facing left, phase 0, on the bottom row's floor
(CharY = FloorY[block row 2] = 191 − 10 = **181**), one at each wall of the spike pit:

```
behind    mid  frame 15 CHTAB1 #15  rows 141..181  bytes 38..40  overlaps the $83 of block column 5 (bytes 40..46)
-- the foreground pass: 16 entries replayed over the MID draws --
control   flat frame 15 CHTAB1 #15  rows 141..181  bytes 18..20  overlaps the $83 of block column 1 (bytes 12..18)
```

```
FB COMPARE — port vs PREDICTED: 15360/15360 identical -> EXACT        [512 KB; also run in the char suite]

draw      frame aw   PL   frame bytes     bytes  changed  port | controls:  p528 opposite plane-swap
behind       15    2    0  38..40 r141..181    123       54     0 |             33       39         33
control      15    2    0  18..20 r141..181    123       88     0 |              0       28          9
outside every frame: 14259 B; port vs bare tile reference differ: 0
```
(The five P5.29 draws on the top row are unchanged and still exact.)

- **`plane-swap`** is the other plane order replayed over the prediction.
  - For `behind`: drawn flat, he would contradict **33 bytes** of the capture. That is how much of him
    the wall hides.
  - For `control`: with the foreground pass over him, **9 bytes** would differ. That is how much of him
    a correct port would hide behind that wall.
  - The two differ because of the cel's own pixel layout: the standing kid faces left, and more of his
    body falls in his right-hand byte.
- **What the prediction is worth** (P5.29's lesson): the runtime equals the plan tool's composition of
  the tile reference, the bake's own fore list and the reference streams. **Whether that is how the
  ORACLE layers a kid against a wall is Ruling 1's question, and it is Jay's.** The mechanism is
  sourced (DRAWFORE after DRAWMID); the picture is the gate.

#### 3C — The PNG path (Phase 4.2)

`render_fb.py` now writes PNGs with `zlib` + `struct`. **It also had a second defect the PIL error
hid:** it refused palette files under 16 bytes, and the 2 bpp runners dump 4 (`$FFB0–$FFB3`). Fixed.
**Surfaced for Jay, not interpreted** (CLAUDE.md §3):
- **`build/char_screen1.png`**: the character probe's capture, all seven kids, 960×576 (×3, NEAREST),
  with the palette read from the machine.
- **`build/tile_screen1.png`**: the bare tile page.

#### 3D — ★ Phase 3: Ruling 2 measured at its real context, and why no picture was built (AC6, AC7)

*Authority: source (FRAMEADV.S) and the bake's own composites; no oracle capture.*

**What `$46` is.** `bgtable1 #70 = fronti[4]`: the **static front piece `drawfrnt` lays for a GATE
block**, with `maddfore` (mask, then ora) at the block's own position. On screen 2 that is XCO 39 /
YCO 62. `bg_compose` **includes** it: `fore_plane.py --screen 2` lists both halves.

**What it is NOT:** the dispatch's §1 quotes `bg_compose`'s omission *"gate bars over character
(DrawGateBF?: needs kid position)"* as this piece. That omission is `drawgatebf`
[FRAMEADV.S:829-842, 1765-1811], which lays **`$44` (`gatebotORA`) and `$37` (`gateB1`)** at
`gatebot`-relative rows, by gate STATE, and only when the kid is in the gate's block. **`$46` does not
move with the gate.**

**The measurement** (`gate_probe_plan.py`). Screen 2 is baked without the bar (`--omit 46`), then:
- **(A)** `$46` is converted in isolation by `sprite_convert` at its own Apple column (start_col 273,
  the real colour parity) and drawn keyed through the shipped blitter's semantics;
- **(B)** the with-bar composite is copied over the box where the two composites differ.

(B) reproduces the with-bar composite exactly. (A) against it:
```
gate_probe_plan: LEVEL0 screen 2, $46 at XCO 39 YCO 62 -> port byte 73 phase 1, rows 3..62, 3x60 stream 422 B
  per-context box: rows 3..33, bytes 73..74 = 62 B; prediction B == the with-bar composite: EXACT
  ★ AS A SPRITE vs the with-bar composite: 0 px differ over the bar's 420-px footprint (0 black<->lit), 0 bytes

PRICE — every $46 placement in LEVEL0 (static: one variant per placement, not per state)
  screen  2  XCO 39 YCO  62  per-context box (3, 33, 73, 74) =  62 B   sprite stream 422 B   sprite error  0 px
  screen  3  XCO  3 YCO  62  per-context box (3, 50, 10, 11) =  96 B   sprite stream 422 B   sprite error  0 px
  screen  3  XCO 39 YCO  62  per-context box (3, 33, 73, 74) =  62 B   sprite stream 422 B   sprite error  0 px
  screen  4  XCO 39 YCO  62  per-context box (3, 33, 73, 74) =  62 B   sprite stream 422 B   sprite error  0 px
  4 placement(s): per-context 282 B, as sprites 1688 B (static page bake: already in the page, +0 B)
```

**Why 0 px.** I read the framebuffer bytes around the bar (structured data, not a PNG):
- **rows 3..33**, where the bar adds pixels: the background under it is **all index 0, black**;
- **rows 36..62**: a background entry (`$0A` at XCO 36) **already draws the same bar pattern**, so the
  bar adds nothing there, which is why the box ends at row 33.

**A keyed edge over black has no neighbour to be wrong about.** P5.8 §3F's 14.3% was the worst of 25
*synthetic* lit neighbour pairs. Its own §7.1 said *"the real figure could be anywhere between 0 and
60 px."* **Measured at all four real placements, it is 0.**

**Where a lit context WOULD come from:** the gate's own **B-section** (`drawgateb`, the grill, drawn in
the BACKGROUND plane at the gate's live position). `bg_compose` omits it: *"gate B-section (drawgateb:
live gate position)"*. So whether a real gate puts lit pixels beside the bar depends on the gate's
state, and **no composite this toolchain can build has them.** A GATEA/GATEB probe would have shown
Jay **two identical pictures**. I wrote it, found that, and dropped it (§2). The dispatch says *"stop and
report rather than resolving ambiguity silently."*

**AC7 — the ~3,840 B estimate, confirmed or not: NOT, and the premise is wrong for `$46`.** The
estimate multiplied ~8 gate states by 4 gates by ~120 B. **`$46` has one context per placement, not per
state:**
- **per-context, as separate variants: 282 B** for LEVEL0's four placements;
- **as keyed sprites: 1,688 B**, which is *more*;
- **in the page model: +0 B**, already present.

The STATE-dependent pieces are `$44`/`$37` (DrawGateBF) and the B-section. They are where "~8 states"
belongs, and **they are not modelled, so they are not priced.**

**Posts `$45` (cheap, so included):**
```
screen  1 post XCO 37 YCO  61: keyed-sprite error  21 px of 1239 (21 black<->lit)
screen  4 post XCO  1 YCO  61: keyed-sprite error  29 px of 1239 (29 black<->lit)
screen  9 post XCO 37 YCO  61: keyed-sprite error  25 px of 1239 (25 black<->lit)
screen 24 post XCO 37 YCO  61: keyed-sprite error  25 px of 1239 (25 black<->lit)
```
**A real, visible artifact (1.7–2.3%, all black↔lit), but only for a choice nobody would make.** The
oracle draws posts `sta` (P5.8 §3B), the port's page bake already holds them per-context and exact,
and the fore list redraws them from there. P5.8's *"0 of 25 contexts reach zero"* is true of keyed
conversion. It is not a property of the port.

**So Ruling 2 as framed has nothing to rule on.** The question that remains is real but different: **a
moving gate** (the B-section behind `$46`, and `$44`/`$37` over the kid). Answering it needs
`drawgateb`/`drawgatebf` modelled per state. That is §8.1, for Jay to direct.

#### 3E — Phase 4 (AC8)

1. **`char` in `run_suites.sh`:** done, cheap (one more boot at 512 KB; 128 KB stays `tile` per
   CLAUDE.md §2K). It covers the bake, registry, frame table, every `xf_blit` path, the placement and
   colour arithmetic and the fore pass, byte for byte.
2. **PNG without PIL:** done (§3C).
3. **Six `ROOT` literals:** done. `cel_link`, `cel_table`, `bake_scene`, `bake_walk`, `beat_recost` and
   `gen_cel_table` now use `pathlib.Path(__file__).resolve().parents[2]`, and prod is identical after a
   full rebuild. **★ And a correction to P5.29 §7.2: `C:\Projects\POP3_port` is a JUNCTION to
   `C:\Users\jayse\DEV\POP3_port`, not a second clone.** Every file in it hashes equal to this tree's,
   including P5.29's own `cel_parity_rule.py` edit, and P5.30's new `fore_draw.s` appears there. **The
   shipping build was never running a stale tool on this machine.** The literal was still a hazard on
   any other machine, which is why the fix stands. 11 more tools carry it; they are not swept.

---

### 4 — Verification (AC-by-AC)

- **AC1** — §0: prod identical; `tile_probe.bin` unchanged; `probe.dmk` and `char_probe.bin` moved,
  with the reasons.
- **AC2** — §3A: the fore list is emitted; **+97 B built against +774 B priced**, with the reason.
- **AC3** — §3A: no per-piece plane table; the general case is stated as unsolved.
- **AC4** — §3B: `behind` is occluded by an `$83`, with `control` (flat) beside it.
- **AC5** — §3B: **15,360 / 15,360**; per draw port 0; plane-swap controls 33 / 9; the prediction's worth
  is stated.
- **AC6** — §3D: **not drawn on hardware.** As-sprite vs per-context was measured offline and is
  **identical (0 px)** at all four real placements; the probe pair was built and dropped.
- **AC7** — §3D: the estimate is **not confirmed** (the static premise); posts are included (21–29 px as
  keyed sprites, exact as baked).
- **AC8** — §3E: all three done.
- **AC9** — §5: Ruling 1 is put to Jay. Ruling 2 is put as a finding with bytes, and a direction asked.
- **AC10** — **512 KB: `introseq` PASS, `integ` PASS, `tile` PASS, `char` PASS, ALL PASS. 128 KB:
  `tile` PASS, ALL PASS.**
- **AC11** — §0.
- **AC12** — §6.
- **AC13** — §6.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1:**
```
build.bat: BAKE screen 1 ... foreground list 1 + 16 x 6 = 97 B; page 7377 B; both VERIFY EXACT
           tile_page.raw 7377 -> 1468 B (19.9%), 2 -> 1 tracks; build/tile_probe.bin (1500 bytes)
           char_probe_plan: 7 draws ... behind (mid) / fore pass / control (flat); predicted -> char_ref.bin
           [map_check] clean; CHAR.BIN 14108 ok, TILE.BIN 1500 ok; VERDICT: PASS; === BUILD COMPLETE ===
run_suites.sh 512K: [run_introseq_test] PASS / [integ] PASS / [run_tile_test] PASS / [run_char_test] PASS / ALL PASS
run_suites.sh 128K: [run_tile_test] PASS / ALL PASS
run_char_test.sh: status=4 dskerr=00 magic=7B1E ents=80; 15360/15360 identical -> EXACT
run_tile_test.sh: 15360/15360 identical -> EXACT
render_fb.py: build/char_front.bin: 15360 B, 2 bpp -> build/char_screen1.png (960x576)
```
**25.2:** N/A.

**25.3 operator-runtime-smoke — RULING 1: PENDING JAY.** `run_char_live.sh`: **live-disk**
(`LOADM"CHAR"` + `EXEC`, `build/char_gate.dmk`), RGB, 512 KB, throttled. The picture is static, so a
live observation is complete for it. The script waits about 30 s at the BASIC prompt before typing EXEC
itself.

**What Jay is asked (Ruling 1, plane ordering).** On the **bottom row**, at the two walls of the spike
pit:
- **The RIGHT kid** (beside the wall on the pit's right): **does the wall hide his right side?** That is
  the corrected order: wall in front of the kid.
- **The LEFT kid** (beside the wall on the pit's left): he is drawn the OLD way, **in front of the
  wall**. That is the control, the defect as every build before this one would show it.

Does the occlusion look right? This is a defect being fixed, not a choice.

**Ruling 2: no picture, and the reason** (§3D). The gate bar's as-sprite and per-context forms are
**identical (0 px)** at every real placement in LEVEL0, and per-context costs +0 in the page bake, so
there is no artifact to accept or bytes to spend. **The question for Jay is whether to go further:**
model the gate's moving parts (the B-section behind the bar, and `$44`/`$37` over the kid) so that a
lit-context case can be shown, or close Ruling 2 here.

**What Jay is NOT asked:**
- motion or timing;
- clipping;
- **the running engine's plane assignment** (§3A: this is SURE's static case only);
- a character behind a KEYED fore piece (not built);
- the top row's five kids (P5.29, passed).

### 6 — Reactive deviations, non-proposals, route accounting

**Deviations:**
1. **No Ruling 2 picture** (§3D). Built, measured, found identical, dropped. Reported, not silently
   resolved.
2. **The fore list reuses the page's variants**, so the cost is 97 B, not 774 B (§3A).
3. **`tile_probe.bin` did not change.** The dispatch listed it as a subject; the renderer does not read
   the new list.

**AC12 — not proposed:**
- no per-context baking of anything (the hard stop, and §3D shows nothing to bake for `$46`);
- no gate-state modelling (§8.1);
- no keyed fore pieces over characters;
- no plane assignment for FAST;
- the remaining 11 `ROOT` tools are not swept.

**AC13 — ROUTE ACCOUNTING.** P5.28 §8.1 proposed the plane split or an overlap placement. **This change
does both:** the split (as a list beside the flattened page, not a re-bake into two pages) and the
overlap draw with its control. P5.29 §8.1 proposed fixing `cel_link.py`'s ROOT "as a prod-path change";
that is done, and **its premise (a stale clone) was wrong** (§3E).

### 7 — Uncertainty flags

1. **Ruling 2's 0 px is a statement about the composite, not the oracle.** The oracle's screen 2 has
   the gate's B-section in it at whatever state the gate is in. If that puts lit pixels beside the
   bar's left edge, the error returns. Only a gate-state model, or an oracle capture, can settle it.
2. **The fore list is SURE's case** (§3A). FAST's per-class plane re-pointing is not represented.
3. **The `$46` pair is flagged KEYED** in screen 2's list and redrawn opaque. That is exact with no
   character behind it, which is the only case tested.

### 8 — Follow-up candidates

1. **★ Model `drawgateb` / `drawgatebf` per gate state** (B-section, `$44`, `$37`). That is what Ruling 2
   actually needs, and the place where "~8 states" belongs.
2. **A keyed per-context fore draw** for `$46`/`$44` over a character (the limit in §3A).
3. **The plane-per-redraw-path table** for FAST (P5.8 §8.2), for a running engine.
4. Sweep the remaining 11 `ROOT` literals.

### 9 — User interaction during task

None.

### 10 — Candidate(s) captured this task

None.

### 11 — Commit

**`00f588f`**. This hash line follows in its own commit. Pushed to `origin/wip`. `main` untouched at
`32b5fe2`. Ruling 1's result, and Jay's direction on Ruling 2, will be recorded in a further commit.
