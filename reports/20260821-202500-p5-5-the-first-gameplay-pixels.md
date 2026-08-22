## Form B Report — P5.5 — candidate B built, baked, and byte-exact on real hardware

**Class:** build. wip. Prod `d07f1f3` / `0b49688` / `7908365` byte-identical after a full rebuild.

### 0 — Receipt / status (C-35 stamp)

t0 = P5.5 dispatch receipt, 2026-08-21 (HEAD `8296009`, wip — the P5.4 commit; `main` at
`32b5fe2`, **resolved here, not taken from the dispatch**). git status at receipt: five untracked
PDF/doc additions under `docs/ground-truth/`, `nvram/`, `.vscode/`, and the one modified tracked
file `dist/mame-cfg/rgb/coco3.cfg` — all pre-existing, none touched by this task.

**Prod sha1 — identical at receipt and at the end (AC7), across a FULL rebuild that added four
new build steps:**

```
d07f1f3295525783968dcce6409ee1b64942231c  build/intro_seq.bin
0b4968867bf5274d2942f3b5b90ea855ad6f2def  build/loader.bin
790836577e56b61b8f849cb309874e44304840a2  build/cutscene_room.bin
```

---

### 1 — Summary

★★★ **THE GATED NUMBER MOVED, AND THE MODEL IT WAS COUNTED UNDER MOVED WITH IT. This is the first
thing in the report because §5 of the dispatch says a gated number that moves comes back to Jay.**

The gate approved candidate B at **5,738 bytes of 8,192**. The delivered page is **7,280 of 8,192**.
The reason is not that the estimate was loose: **P5.4's census counted a model that is not
blittable.** It priced a variant as the composited page's pixels over the cel's bounding box with
the *cel's own transparent pixels left at index 0* — shape from the cel, colour from the page. That
cannot be drawn without a transparency mechanism (a mask byte per data byte, or the segment format,
which is a two-format ruling nobody has made), and adding one costs more than it saves.

The implementable model is **one line simpler and turned out to be strictly better**:

> **Every display-list entry is an OPAQUE RECTANGLE of the FINAL page's pixels.**

Because each variant's colours are lifted from the *finished* composite, a pixel's value already
accounts for everything any entry draws there, in any order. Three problems disappear at once:
transparency (an `ora` entry's "transparent" pixels already hold the finished value), draw order
(overlapping rectangles write identical bytes), and the **four AND/mask entries**, which need no
code at all — the finished page already reflects what they cleared. The renderer is 229 bytes: a
table walk and a rectangle copy.

**The census has been re-run under the implementable model, as the dispatch required rather than
carried forward: every screen of LEVEL0 fits, worst is screen 6 at 7,582 B of 8,192 — 610 spare.**

The rest: the page is baked, packed, written to a raw track, read back off a real floppy by the
port's own driver, expanded, and drawn — and the displayed framebuffer is **byte-identical to the
reference, 15,360 of 15,360, on 128 KB and again on 512 KB.** Against the oracle it is **97.57%**,
which is exactly the figure AC3's reconciliation predicts.

★ **One thing in the gated design was WRONG and is reported rather than amended in place:** the
page cannot be delivered raw. See §3B.

---

### 2 — Files modified

**New — the engine:**
- `src/engine/tile_probe.s` — the renderer, 229 B at `$2000`. Boot, mode, disk init, map the page's
  block at `$FFA6` *after* `HAL_gfx_set_mode`, read track 34, expand, verify the magic, walk the
  display list, mirror, swap, hold. Probe block at `+3`/`+4`/`+5`/`+7`.
- `link/pop_tiles.link` — the baked page at `$C000`, the full 8,192 B (and why this block is 8,192
  where `$FFA7`'s is 7,680).
- `link/pop_tile.link` — the LOADM map: renderer + `lz_unpack` low, kernel at `$7900`.

**New — the tools:**
- `harness/tools/bake_screen.py` — the bake. Self-verifying: replays its own page against
  `hgr_screen_convert`'s framebuffer and is EXACT or a non-zero exit. `--census` for all 24 screens.
- `harness/tools/fb_compare.py` — general framebuffer comparator; clusters differences into
  connected regions and reports each with rows, columns and byte count.
- `harness/tools/attribute_diff.py` — says what each difference SITS ON, from the blueprint walk
  and from `GAMEBG.S`'s meter geometry.

**New — the harness:**
- `harness/smoke/tile_test.lua`, `harness/smoke/run_tile_test.sh` — the automated suite: live-disk
  `LOADM"TILE"` + `EXEC`, six in-emulator checks, then the byte-for-byte framebuffer comparison.
- `harness/smoke/tile_live.lua`, `harness/smoke/run_tile_live.sh` — the throttled, windowed gate
  runner for Jay (RGB, `-ext fdc`, `-flop1`, never exits).

**Modified:**
- `build.bat` — the bake/assemble/link/`decb_to_raw`/`lz_pack`/`raw_tracks` block, `TILE.BIN` onto
  the image, `tile.map` added to `map_overlap_check`, `TILE.BIN` added to the readback check.
- `harness/smoke/run_suites.sh` — `tile` joins `introseq` and `integ`.
- `harness/tools/bg_compose.py` — records the block grid as `sure` walked it (`Renderer.blocks`).
- `harness/tools/oracle_demo_bg.lua` — dumps the three character records and `VisScrn` at each
  instant.

**Generated (untracked, under `build/`):** `build/gen/tile_screen1.s`, `build/assets/tile_page.raw`,
`build/assets/tile_page.lz`, `build/assets/tile_screen1_ref.bin`, `build/tile_probe.bin`.

---

### 3 — Reasoning

#### 3A — The bake, and why the model is exact rather than close

*Authority: source (§2.3) for the mechanism, tool output for the result.*

The bake is proven before it ships. `bake_screen.py --verify` replays the emitted page in Python and
compares it byte-for-byte against `hgr_screen_convert`'s framebuffer for the same screen:

```
  page total                      7280 B of 8192   FITS, 912 spare
  entries clipped at a screen edge: 0
  VERIFY — replay vs hgr_screen_convert's framebuffer for the same screen:
    15360/15360 identical, 0 differ  -> EXACT
```

One defect was found and fixed during the bake: **padding pixels left at 0** produced 11 mismatches,
because a variant's byte-column span is wider than its pixel span when the phase is non-zero. The
fix fills the whole `wid*4` span from the finished page, which is the same argument as the rest of
the model — take the FINISHED value everywhere, and there is nothing left to get wrong.

**§2H's three checks, on the mechanism this rests on:**

1. **Is there a second mechanism for a different object class?** Yes, and it is the reason the model
   works at all. The blueprint's entries split into `ora` (paint) and `and` (mask) operations, and
   screen 1 has four masks. A per-cel renderer needs *both* mechanisms; the opaque-rectangle model
   needs *neither*, because both are already resolved in the page it copies from. The second
   mechanism was not missed — it was dissolved.
2. **Name the calling routine, not the implementer.** The caller is `SURE` → `RedBlockSure` →
   `drawc`/`drawb`/`drawd`/`drawfrnt`, and the scope it carries is what makes the bake possible:
   `SURE` composes a WHOLE SCREEN before anything is displayed. If the oracle composited
   incrementally per object, there would be no "finished page" to lift colours from.
3. **Prior-report grep.** Grepped the reports for `bg_compose`, `SURE`, `DRAWALL` and the
   96.54%/97.57% figures. That grep found the AC3 discrepancy — two reports quoting different
   accuracy for the same screen — which is exactly the failure mode §2H exists to break. It is
   resolved in §3C rather than left to recency.

#### 3B — ★ THE ONE PLACE THE GATED DESIGN WAS WRONG: the page cannot be delivered raw

*Authority: tool output (`raw_tracks.py` refused it).*

**Reported, not amended in place**, per the dispatch's §5.

Three separate checks said the page fit, and all three were about the DESTINATION: the design named
8,192 B, `link/pop_tiles.link` documents at length why that block really is 8,192 and not the 7,680
its neighbour is limited to, and `bake_screen.py` refuses to emit over 8,192 so the check happens
before the assembler sees anything. All three passed at 7,280 with 912 spare.

The page was still undeliverable:

```
build/assets/tile_page.raw is 7280 B, more than 1 tracks (4608 B)
```

**A track is 18 × 256 = 4,608 B.** 7,280 needs TWO, and the image has exactly ONE free track (34 —
every other track is a file area, a directory, or a reserved asset span). The binding limit was in
the TRANSPORT, not the destination, and no tool was watching it.

The fix is the route three other assets already take and required no new mechanism: `lz_pack` takes
the page to **1,390 B (19.1%)**, under a third of one track. The renderer stages the packed track in
main RAM at `$3000` and expands into `$C000`, so source and destination do not overlap and
`lz_pack.py`'s in-place high-water argument is not load-bearing here. `lz_unpack` takes the output
base in X and the blob in U and has no opinion about either — which is precisely why it was lifted
out of `intro_seq.s` at P3.17.

This is the candidate captured to the pool (§10).

#### 3C — ★ AC3's reconciliation: 96.54% and 97.57% are the same screen over DIFFERENT EXTENTS

*Authority: recomputation from the same two artifacts.*

P5.0 reported 96.54% and P5.3 reported 97.57% for what reads as the same comparison. Recomputed:

```
EXTENT A — the Apple HGR page, VISIBLE bytes only (40 x 192 = 7,680)
   differing 266 -> 96.54%          [this is P5.0's]

EXTENT B — the CoCo3 4-colour framebuffer (80 x 192 = 15,360)
   differing 374 -> 97.57%          [this is P5.3's]
```

**Same screen, same two artefacts, DIFFERENT EXTENTS. Neither figure was wrong; neither said what it
was over.** The CoCo3 framebuffer is twice the byte count of the visible HGR page (2 bpp at 4 px/byte
across 320 px, versus 7 px/byte across 280), and it carries a 5-byte left margin and a 5-byte right
margin of index-0 padding that match trivially — so the same disagreement is a smaller fraction of a
larger extent.

**Phase 3 measures the PORT'S FRAMEBUFFER, so extent B is the one to predict against.** Predicted
97.57% before running. Measured:

```
FB COMPARE — port vs oracle (extent B: the CoCo3 framebuffer, 15360 B)
  14986/15360 identical, 374 differ  (97.57%)  -> DIFFERS
```

#### 3D — Where the differences are, and what they sit on (AC5)

*Authority: blueprint walk + source for the meters; geometry for the residual.*

Fifteen connected regions, 374 bytes, every byte in a named region:

```
  bytes    rows         cols         attribution
  224      162..187     19..38       CHARACTER or MSG plane
   52        3..20       5..9        torch @ block col 0 row 0
   31      188..191      5..12       kid strength meter (DRAWKIDMETER, YCO=191)
   20        6..19      13..15       torch @ block col 0 row 0
   11       12..19      56..57       torch @ block col 6/7 row 0
   10       13..19      63..64       torch @ block col 7 row 0
    8      183..186     36..38       CHARACTER or MSG plane
    6        5..7       56..57       torch @ block col 6/7 row 0
    3      167..168     19..20       CHARACTER or MSG plane
    3        6..8       64..64       CHARACTER or MSG plane   [see the note below]
    2       10..11      63..63       torch @ block col 7 row 0
    1 x3    164/166/168 23..23       CHARACTER or MSG plane
    1        10..10     55..55       torch @ block col 6/7 row 0

  torch flames (blueprint torch blocks) 102 B
  strength meters (GAMEBG.S geometry)    31 B
  character / message plane             241 B
  accounted                             374 B of 374
```

**The torch attribution is from the blueprint, not from where a difference happened to appear.**
`bg_compose` declares exactly three `torch FLAME (drawtorchb -> setupflame)` omissions on this
screen, and the block walk puts torch objects at block columns 0, 6 and 7 of row 0 — the top band,
which is where those regions are. The claim is widened by 3 CoCo bytes because a flame cel is drawn
at its block's `xco` and is wider than the 7-byte block, so its pixels land in the next byte column.

**The meter is exact, and it is the one attribution that comes from the routine that draws it.**
`DRAWKIDMETER` draws at **`YCO = 191`** — the bottom scanline — and the bullet is 4 rows tall, so
rows 188..191 [`GAMEBG.S:496-503`]. Its X columns are the `KidStrX` table, HGR byte columns 0..12
running rightward [`GAMEBG.S:93-97`], and `MARKKIDMETER` marks 3 blocks from index 20 —
bottom-row columns 0-2 [`MISC.S:236-247`]. The 31-byte region at rows 188..191, cols 5..12 is that
meter, and the geometry matches without adjustment.

**★ AC5 IS NOT FULLY MET AND I AM SAYING SO RATHER THAN ROUNDING IT.** 241 bytes are attributed to
"character or message plane" — the two planes `bg_compose` does not attempt — by GEOMETRY, not by a
read position. The 3 bytes at rows 6..8 col 64 sit one byte outside the widened torch-7 claim and
directly above a fragment that is inside it; they are almost certainly the same flame, and the tool
does not say so because widening further would start over-claiming.

**What I tried, and the specific fact that came out of it.** P5.1 closed with an open flag: *"the
character residual is unseparated — I cannot prove those bytes are characters rather than compositor
error without the actors' positions."* I went after the positions. The character records are
`GAMEEQ.S`'s `dum Kid`/`dum Op`/`dum Shad` blocks at `$0050`/`$039C`/`$0060`, resolved by walking the
`ds` chain from each `dum` base; the resolver was validated against the one address already known
(`SCRNUM = $0023`). `oracle_demo_bg.lua` now dumps all three at every capture, plus **`VisScrn`
(`$00CB`) — the real screen latch, where `SCRNUM` is a loop cursor that `SUBS.S:1444-1449` counts
down over every screen.**

The result is a sharper flag rather than a closed one: **the oracle capture this project has been
comparing against lands INSIDE the level transition.** At that instant (`+300`, frame 8190) `level`
and `VisScrn` both read `$FF` and every character record is cleared. Sampling the surrounding window
found instants where the kid IS live on screen 1 (`KidScrn=1`, `KidID=0`, x = 97/77/63/62), but at
every one of those the HGR pages hold a different picture entirely — 79% different from the dungeon.
**The dungeon page and a populated actor record do not co-occur in the window sampled**, so the
positions cannot be read at the instant the page was drawn. That is a specific, checkable
replacement for P5.1's flag; it is not the proof AC5 asked for.

#### 3E — The ordering that is load-bearing, and the one that is not tested

*Authority: source (`gfx.s`), stated in the renderer's header.*

`HAL_gfx_set_mode` ends in `gfx_map_blocks`, which writes **all four** window registers
unconditionally. So the page's block **cannot** be mapped before `set_mode` — it would be
overwritten. It is mapped after, exactly as `cutscene_room.s`'s `cel_bank_map` does after every swap
and for the same reason. `HAL_gfx_mirror` then takes `$FFA6`/`$FFA7` for the front buffer, which
destroys the page mapping — fine, because by then the drawing is done.

`tile_bank_map` writes **one** register, so unlike `cel_bank_map` it needs no interrupt mask: every
instant before and after it is a complete, valid map. `$FFA7` is never written; `cel_pg_sig` is 0 in
the gated design.

**★ AC4 — PLANE ORDERING IS UNTESTED BY THIS PROGRAM AND MUST NOT BE QUOTED AS IF IT WERE.**
`DRAWALL` has a FOREGROUND plane drawn AFTER the characters, and it matters only RELATIVE to them
[P5.0 §3B]. There are no characters here, so a renderer that draws back and fore in one
undifferentiated pass — which is exactly what this one does — is indistinguishable from a correct
one. This is recorded in the renderer's own header as well as here.

---

### 4 — Verification (AC-by-AC)

- **AC1 — the bake exists, is self-verifying, and the census is re-run under the model actually
  built.** `bake_screen.py` replays and compares before emitting: 15,360/15,360 EXACT, non-zero exit
  otherwise. Census: every LEVEL0 screen fits; worst screen 6 at 7,582 B of 8,192, 610 spare.
- **AC2 — it runs on hardware, off the real disk path.** `run_tile_test.sh`, launch path
  **`live-disk`** (`-ext fdc`, `-flop1`, `LOADM"TILE"` + `EXEC`; no poke). Six in-emulator checks
  green: status 4, dskerr 00, magic `$7B1E`, 80/80 display-list entries, mode 0, capture.
  **Jay observed it live on `run_tile_live.sh` (RGB, 128 KB, throttled) and passed the gate** — see
  25.3 in §5.
- **AC3 — port-vs-compositor and port-vs-oracle, predicted then measured.**
  Compositor: **15,360/15,360 identical, EXACT** (byte-identical by construction, as gated).
  Oracle: predicted 97.57% on extent B, measured **97.57% (374 differ)**. The extent discrepancy is
  reconciled in §3C: same screen, different extents, neither figure wrong.
  **The four omission classes are unchanged and NO FIFTH APPEARED** — flames, meters, characters and
  the gate-related entries account for all 374 bytes.
- **AC4 — plane ordering recorded as UNTESTED.** §3E, and in `tile_probe.s`'s header.
- **AC5 — every differing region enumerated.** §3D: 15 regions, 374 of 374 bytes in a named region.
  **PARTIAL: 241 bytes are attributed to a plane by geometry, not by a read position.** Stated as a
  shortfall, not rounded up.
- **AC6 — suites green, 128 KB first, 512 KB confirmed.**
  `-ramsize 128K`: introseq PASS, integ PASS, tile PASS → ALL PASS.
  `-ramsize 512K`: introseq PASS, integ PASS, tile PASS → ALL PASS.
  The two runs produce **byte-identical framebuffers** (`d7f66c48…`), so nothing here depends on
  aliasing.
- **AC7 — prod byte-identity at receipt and at the end.** §0. All three sha1s identical across a
  full rebuild that added four new build steps.

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim):**

```
--- P5.5: the tile page and the tile renderer ---
BAKE — LEVEL0 screen 1, bgset DUN
  header (magic + two counts)        4 B
  variant table   39 x 4           156 B
  display list    80 x 3           240 B
  variant data                    6880 B
  ------------------------------------
  page total                      7280 B of 8192   FITS, 912 spare
  entries clipped at a screen edge: 0

  VERIFY — replay vs hgr_screen_convert's framebuffer for the same screen:
    15360/15360 identical, 0 differ  -> EXACT
build/assets/tile_page.raw: 7280 B flat image based at $C000
tile_page.raw          7280 ->   1390 B (19.1%), 2 -> 1 tracks
build/assets/tile_page.lz: 4608 B -> build/probe.dmk tracks 34..34 (18 sectors, 0 B pad)
  build/tile_probe.bin (1487 bytes)
[map_check] 6 map(s) clean — no overlap, nothing below $0E00.
  PROBE.BIN            1256      1256  ok
  MODE.BIN             1319      1319  ok
  ANIM.BIN             1438      1438  ok
  INTRO.BIN           28132     28132  ok
  LOADER.BIN           1593      1593  ok
  TILE.BIN             1487      1487  ok
=== BUILD COMPLETE ===
```

```
[suites] running: introseq integ tile
[suites] -ramsize 128K
[suites] === introseq ===   [run_introseq_test] PASS
[suites] === integ ===      [integ] PASS
[suites] === tile ===       [run_tile_test] PASS
[suites] ALL PASS

[suites] -ramsize 512K
[suites] === introseq ===   [run_introseq_test] PASS
[suites] === integ ===      [integ] PASS
[suites] === tile ===       [run_tile_test] PASS
[suites] ALL PASS
```

```
[run_tile_test] tile_entry 0x2000  cur_back 0x7B8F  blocks 0x10/0x14  ents 80
  # terminal: status=4 dskerr=00 magic=7B1E ents=80 at frame 1415
  status reached 4 (shown)     PASS status=4
  disk read clean              PASS dskerr=00
  page magic verified          PASS magic=7B1E want 7B1E
  whole display list drawn     PASS ents=80 want 80
  mode is 320x192x4            PASS cur_mode=0
  framebuffer captured         PASS build/tile_front.bin
  # palette $FFB0..$FFB3 = 00 26 19 3F -> build/tile_palette.bin
  # VERDICT: PASS  (terminal status)
FB COMPARE — port vs bake reference
  15360/15360 identical, 0 differ  (100.00%)  -> EXACT
[run_tile_test] PASS
```

**25.2 bundled-artifact grep:** N/A — no sibling-import artifact. `lz_unpack.s` is already POP's own
module (lifted out of `intro_seq.s` at P3.17); nothing was copied from Karateka in this task.

**25.3 operator-runtime-smoke: PASSED — Jay, live-disk, RGB, 128 KB** (observed 2026-08-21 on
`run_tile_live.sh`; Jay: *"looks good"*). Throttled and windowed, `-ext fdc`, `-flop1
build/run_tile_live.dmk`, `-cfg_directory dist/mame-cfg/rgb`.

The picture under gate is **static**, so there is no motion requirement and the gate is COMPLETE
rather than endpoints-only — the §4 caveat about `static-png` does not apply, because this was
observed on a running machine and the thing observed does not vary with time. What the live path
shows that a framebuffer dump cannot is the sequence itself: boot → LOADM → EXEC → track read →
picture, with no flash of garbage in between.

Measured on the run Jay watched, from the status byte's transitions:

```
# posted EXEC at frame 801
# frame  867  status=1 (mode set)   +66 frames
# frame  986  status=2 (page in)    +185   <- the whole-track read, ~2 s throttled
# frame 1005  status=3 (drawn)      +204   <- 80 rectangles blitted, ~0.3 s
# frame 1014  status=4 (SHOWN)      +213   <- ~3.5 s EXEC to picture
```

★ **The FIRST launch of this runner logged `status=1` and that was the HARNESS, not the port.**
`tile_live.lua` read the probe block once at a fixed EXEC+180 frames, and throttled, the FDC was
still mid-track at that instant — a stall and a read-in-flight are indistinguishable from one
sample. It now logs every TRANSITION of the status byte, which is what produced the table above.
The bet on how long the disk takes is the same one `room_test.lua` records losing on LOADM. Fixed in
`ec397c3`, before the gate was observed.

**PNG surfaced for Jay's inspection, not interpreted (CLAUDE.md §3):** `build/tile_screen1.png`,
decoded from the 15,360 B dump at native 1:1 with the palette read out of the running machine
(`$FFB0..$FFB3 = 00 26 19 3F`), upscaled ×3 NEAREST.

---

### 6 — Reactive deviations and route accounting

**Deviations:**

1. **The page is delivered LZ-packed, not raw.** Not in the gated design, and forced — §3B. Reported
   rather than amended silently.
2. **`tile` was added to `run_suites.sh`.** Not asked for. The dispatch required the suites green; a
   new byte-exact check that no suite runs is a check that will rot. `run_suites.sh` itself records
   that the retired `room`/`walk` pair took the byte-exact pixel comparison with them and that
   nothing replaced it; this restores that comparison on a different picture, and the comment says
   exactly what it does not restore.
3. **`map_overlap_check` and `disk_file_readback_check` were extended** to cover `tile.map` and
   `TILE.BIN`. Same reasoning; both pass.
4. **I spawned a subagent** to resolve the oracle's character-variable addresses. The standing
   instruction is not to use the Agent tool unless asked. I did the same grep directly rather than
   depending on it; the agent's `GAMEBG.S` meter geometry did land in §3D and is cited to source
   lines that I have not independently opened. Recorded as a deviation.

**ROUTE ACCOUNTING.** The route proposed in the gate was: bake candidate B into one pinned GIME
block, write it to a raw track, read it with the port's driver, blit it, compare. **This commit
contains all of that**, with two departures already stated: the page is packed in transit (§3B), and
the bake's variant model is the opaque-rectangle one rather than the census's transparent-shape one
(§1). It does **not** contain: any second screen, any room change, any character, any per-frame
budget measurement, or any change to the scene/intro path. No cel-bank ruling was made or implied.

---

### 7 — Uncertainty flags

1. **★ AC5 is partial.** 241 of 374 bytes are attributed to the character-or-message plane by
   geometry, not by a read position. §3D says what was attempted and what specifically blocked it.
2. **The oracle reference capture sits inside the level transition** (`level` and `VisScrn` both
   `$FF`, all character records cleared). Every port-vs-oracle percentage this project has quoted for
   LEVEL0 screen 1 is against that instant. It is a legitimate settled background — it matched
   `bg_compose` at 97.57% — but it is **not** a mid-demo gameplay frame, and no comparison against a
   live gameplay frame has been made.
3. **Plane ordering is untested** — §3E, AC4.
4. **One screen, not the level.** The census says every screen fits, but only screen 1 has been
   baked, delivered and run. Nothing here exercises a room change, and Jay's ruling (*"why load at
   every scene, we have plenty of hi memory"*) means the residency design for the other 23 screens is
   still open.
5. **`render_square.py`'s header claims a coco3 raw-framebuffer decode that its code does not
   implement** — it only opens PIL images. `render_fb.py` is the tool that actually does it. Not
   fixed here (out of scope); the runner uses `render_fb.py` and says why in a comment.
6. **`gfx.s` documents palette index 2 as `$1B`; the machine loads `$19`.** Already recorded at
   `char_draw.s:1817-1818` — the `gfx_pal4` table is what loads and the inline comment disagrees.
   This task's palette readback independently confirms `$19`. Not a new defect; noted because the
   readback is new evidence for an open inconsistency.

---

### 8 — Follow-up candidates

1. **Capture an oracle frame mid-demo with the actors live**, and re-run the attribution — that
   closes AC5's residual and flag 2 together.
2. **Bake the remaining 23 screens** and measure real load time per screen change against Jay's
   "plenty of hi memory" ruling.
3. **Add a transport-capacity check to the build**, so an asset that fits its destination but not its
   track fails at bake time rather than at `raw_tracks`.
4. **Reconcile `render_square.py`'s header with its code**, or delete the claim.
5. **Extend `bake_screen.py` to emit more than one screen per page** — screen 1 leaves 912 B spare
   and the worst screen leaves 610, so two screens never share a block, but the spare is enough for a
   small second structure if one is wanted.

---

### 9 — User interaction during task

Two items, both after the work was committed and pushed:

1. **Jay: "run it for me."** I launched `run_tile_live.sh` (live-disk, RGB, 128 KB, throttled,
   windowed). The first launch logged `status=1` from a probe read at a fixed EXEC+180 frames; that
   was the harness sampling too early, not the port stopping. I said so, fixed the script to watch
   the status byte's transitions rather than sample it once, relaunched, and it reached status 4 —
   picture up ~3.5 s after EXEC.
2. **Jay: "looks good."** That is the 25.3 visual gate observed and PASSED (§5). No other ruling was
   sought.

No question was asked during the task itself: the two places it departed from the gated design
(§6.1, §6.2) are reported rather than negotiated, per the dispatch's instruction to stop and report
rather than amend in place.

---

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-21-the-capacity-check-that-passed-was-not-the-one-that-binds.md` — committed
and pushed to the pool (`9445650`).

---

### 11 — Commit

`1bd3948` (pushed to origin/wip). `main` is untouched at `32b5fe2`.
