## Form B Report — PA.13 — Route A recon: how black is POP's playfield? (decides the opaque-black lever)
**Class:** RECON — measurement only. `wip`. **Prod byte-identity: N/A.**

### 0 — Receipt / status (C-35 stamp)
t0=2026-07-26T15:18:49Z (HEAD `02dc4c0`, wip). Tracked tree **clean** at receipt.
**Gates PASS:** oracle `.hdv` md5 `c4f0b13e49b77dd0fbc5063e27e53a24` ✔; vendored source `ec78dbf` ✔;
`oracle/source/` not modified.

---

### 1 — Summary

**Verdict: FIDELITY-FIRST. Do not pull the aggressive edge-opaque lever.**

Measured at the game's **own** character placements, the prince's body band is **86.1% black (dungeon) /
84.3% (palace)** — so **~1 in 7 edge-opaque pixels would sit over lit background** and visibly depart from
the oracle. That is below the ~90% threshold the dispatch set for "near-free", and P1.3 already proved the
p90 frame fits at **every** model without the lever (worst 0.99×). We would be spending fidelity we do not
need to spend.

**The refinement that decides it:** the background ink is **floor-hugging**. Lit fraction by height —
**feet/shins 25.3%**, knees/hips 12.1%, torso 8.9%, head/shoulders 9.8%. So the prince's *upper* body does
sit against ~90% black, but his **feet sit against 25% lit** — and the character-floor contact line is the
most-scrutinised part of a platformer sprite. The lever's error is concentrated exactly where it shows most.

**Two dispatch premises corrected, both from source:**
- **`.PAL` is the PALACE theme, not palettes.** `FRAMEADV.S:2` — `EditorDisk = 0 ;1 = dunj, 2 = palace` —
  plus `* Add stripe (palace bg set only)`. So both themes' real tile data is present and both were measured
  (the dispatch hoped a second theme "likely exists"; it does).
- **The level data is fully decodable**, so this is a census of the *real world*, not a tile-type estimate:
  15 levels × 24 screens × 30 blocks = **10,800 real blocks**, layout confirmed from `EQ.S` and validated
  independently (§3.2).

**A silent decode failure nearly inverted the verdict** (§3.4): `bgtable2 = $8400` is the *runtime* load
address, not the file's pointer base — both `IMG.BGTAB*` files are built at `$6000`. Decoded at `$8400`,
bgtable2 yielded **zero images**, and every `$8x–$Ax` piece silently scored 0% ink, i.e. **more black**.
That is the direction that would have argued *for* the lever.

---

### 2 — Files modified
- `harness/tools/playfield_census.py` — **new.** Per-piece-type census + real-level block frequencies.
- `harness/tools/playfield_band.py` — **new.** Rasterizes the prince's body band over the real world.
- `reports/20260726-151849-pa-13-playfield-blackness.md` — this report.

No production code, no compiler change, no lever implementation. `oracle/source/`, Karateka untouched.

---

### 3 — Reasoning

#### 3.1 — What "black" means here, and why the question is answerable at all
POP's Apple II backgrounds are **1bpp HGR masks**: a pixel is ON (lit) or OFF. OFF *is* black — there is no
separate black index, and any region no piece is drawn over is black by construction. So blackness is
directly countable from the tile bitmaps; no palette interpretation is involved.

#### 3.2 — The geometry and the level format, established from source and then validated

| Fact | Source | Value |
|---|---|---|
| Screen grid | `FRAMEADV.S` (`colno` 0-9, `rowno` 0-2) | 10 × 3 = 30 blocks |
| Block width | `FRAMEADV.S` `XCO = colno*4` | 4 bytes = **28 px** |
| Block height / floor slab | `TABLES.S` | `BlockHeight = 63`, `DHeight = 3` |
| Section anchors | `BGDATA.S` | A & B at `BlockBot-3`; C & D at `BlockBot` |
| Piece IDs | `BGDATA.S` | 0 `space` … 29 `archtop4` |
| Level layout | `EQ.S` `dum blueprnt` | `BLUETYPE 24*30` + `BLUESPEC 24*30` + `LINKLOC 256` + `LINKMAP 256` + `MAP 96` + `INFO 256` = **2304** |
| Piece-ID mask | `EQ.S` | `idmask = %00011111` |
| Image ID decode | `GRAFIX.S:828` `and #$7f` | bit 7 = table, **low 7 bits** = index |

Two cross-checks rather than assumption. **(a)** `TABLES.S`'s `BlockTable` spans 14 units per block in the
140-res coordinate system, = 28 px in 280-res — matching the `colno*4` derivation independently.
**(b)** The 2304-byte sum matches the file size exactly, and reading `INFO+64` (`KidStartScrn`) and
`INFO+65` (`KidStartBlock`) gives values in 1..24 and 0..29 for **15/15 levels**, with `KidStartFace` always
0 or 255. That validates the whole layout — including `BLUETYPE` at offset 0 — from the artifact's own
embedded data, not from my reading of `EQ.S`.

**Also a comment/code discrepancy:** `GRAFIX.S:199` documents "low 6 bits = image #"; the code at
`GRAFIX.S:828` does `and #$7f` — **7 bits**. Piece IDs like `$97`/`$A7` exceed 6 bits, so the comment is
simply wrong. `CLAUDE.md §2` ranks comments lowest; the code was used.

#### 3.3 — Why I measure the band, and why I let the game choose the sample

The prince stands on a block's 3-line floor slab (`D`) and his body occupies the band **above** it — exactly
the `A`/`B` section band (`BlockBot-3`). So "how black is the background behind him" = "how inked is that
band". Block is 28 px wide; his tallest cel is 41 lines (measured, P1.2). **Band = 28 × 41 px, block-local
y 3..43.**

I did **not** invent a walkability rule to decide which blocks he occupies. POP's level files carry the
answer: `KidStartScrn`/`KidStartBlock` and `GdStartBlock[24]` are the designers' own character placements.
Looking up those blocks' types across all 15 levels gives **57 real placements**: floor 52.6%, exit2 19.3%,
torch 17.5%, posts 7.0%, space 3.5%. Weighting band blackness by *that* is the sharpest available answer,
and it needs no guess about what "standable" means.

**Rasterized, not summed.** An earlier pass summed each piece's ink over the band area and produced
coverages above 100% (pieces are taller than the band; `B`/front spill into neighbours). The final
measurement stamps each contributing piece into a 28×41 bitmap at its real offset and clips — so overlap is
not double-counted and no fraction can exceed 100%.

**Contributors per `RedBlockSure` (`FRAMEADV.S`):** own `A` + own front + the **left neighbour's** `B`.
`drawb` opens `lda objid / cmp #block / beq ]rts` — B is suppressed when the block being drawn is a solid
`block`; that condition is honoured. `C` lands in the floor slab, not the band; `D` is the slab.

**What is excluded, and which way it biases.** `drawa`'s conditional mask (applied when the left neighbour
is `panelwif`/`panelwof`/`pillartop`/`block`/`archtop1`) and the gate/slicer special-case front pieces are
not modelled. Masking can only *remove* ink, so excluding it makes my ink an upper bound and my blackness a
**lower** bound. I then measured the exposure: **0 of 57 placements** have such a left neighbour, so the
correction here is nil and 86.08% cannot climb toward 90% by this route.

#### 3.4 — The silent decode failure, and why it mattered

`GAMEEQ.S` gives `bgtable1 = $6000`, `bgtable2 = $8400`, and I used those as the pointer bases. `bgtable2`
then decoded to **zero images** — because `$8400` is where the table is *loaded at runtime*, while the file's
own pointer table is built at `$6000` (its first pointer is `$6069`, landing just past its 103-byte header).

The failure was silent in the worst way: `resolve()` returned `None`, every `$8x–$Ax` piece scored **0% ink**,
and the census still printed a full, plausible table. And the bias had a direction — those pieces are
architecture (arches, bones, wall details), so their absence made the world look **blacker** than it is,
which is the direction that argues *for* pulling the lever. Caught by noticing `bgtable2: 0 images` in the
header line rather than by any check. Fixed; both tables now decode (dungeon 127+51, palace 127+50).

#### 3.5 — The verdict, against the threshold and the headroom

| | dungeon | palace |
|---|---|---|
| Band blackness at real placements | **86.08%** | **84.27%** |
| Lit (departure rate) | **13.92%** | **15.73%** |
| Threshold for "near-free" (dispatch §5.5) | ~90% | ~90% |

**Below threshold, in both themes, and the shortfall is not marginal** — ~1 in 7 rising to ~1 in 6 in the
palace. Combined with the floor-hugging distribution (25.3% lit at the feet), aggressive edge-opaque would
put a black fringe over lit scenery precisely at the character-floor contact line.

Against that: P1.3 measured the p90 frame at **0.96×–0.99× of budget across every model without the lever**.
The cycles are not needed. `CLAUDE.md`-adjacent standing guidance in the dispatch is explicit — recommend
pulling it *only* if the world is black enough to make it near-invisible. It is not.

**Recommendation: interior-black only (region 1 — always safe, needs no background analysis), keyed edge.**
Region 2 (edge) and region 3 (field) stay keyed.

---

### 4 — Verification (AC-by-AC)

- **AC1 — census per theme, black index and contact-zone geometry defined and justified. MET.** §3.1 (what
  "black" is: OFF pixels in a 1bpp HGR mask), §3.2 (geometry table, all source-cited, two independent
  cross-checks). Both themes measured — **`.PAL` is the palace theme, not palettes** (§1).
- **AC2 — contact-zone focus honoured, distinction explicit. MET.** The primary number is the 28×41 band the
  prince's body occupies (§3.3), not gross frame pixels. Whole-world block-frequency numbers are reported
  separately in §5 as context, and are explicitly *not* the answer.
- **AC3 — edge-exposure fraction stated. MET.** **13.92% of the band is lit (dungeon) / 15.73% (palace)** —
  the departure rate for edge-opaque. Refined by height: feet/shins **25.31%**, knees/hips 12.06%, torso
  8.92%, head/shoulders 9.82%.
- **AC4 — verdict with the number, framed against p90 headroom. MET.** §3.5. Fidelity-first; 86.1%/84.3%
  against a ~90% threshold, with p90 at 0.96–0.99× without the lever.
- **AC5 — honest uncertainty. MET.** §7 — what a census cannot see, and explicitly whether it could flip
  the verdict (it could not, by the margin measured; §7.1 quantifies the one exclusion at 0/57).
- **AC6 — no production/compiler/lever code; status clean. MET.** §5.

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 — decode validated against the artifact's own embedded data (verbatim, abridged):**
```
    INFO offset = 2048; KidStartScrn = INFO+64 = 2112
    LEVEL0    KidStartScrn 1  KidStartBlock  9  KidStartFace 255   yes
    LEVEL13   KidStartScrn 23 KidStartBlock 19  KidStartFace   0   yes
    15/15 levels have KidStartScrn in 1..24 and KidStartBlock in 0..29
    -> BLUETYPE at offset 0 and the 2304-byte layout are CONFIRMED independently
```

**25.1 — world census, real blocks (verbatim, abridged):**
```
  DUNGEON  bgtable1: 127 images   bgtable2:  51 images
  PALACE   bgtable1: 127 images   bgtable2:  50 images
  levels    : 15 x 24 screens x 30 blocks = 10,800 real blocks

    rank piece            blocks  % of world
       1 block             4,267       39.5%
       2 space             3,215       29.8%
       3 floor             1,159       10.7%
       4 posts               632        5.9%
       5 torch               394        3.6%
         (top 10 = 95.3% of all blocks)
```

**25.1 — the game's OWN character placements (verbatim):**
```
=== character-occupied block types (57 placements across 15 levels) ===
    floor            30   52.6%
    exit2            11   19.3%
    torch            10   17.5%
    posts             4    7.0%
    space             2    3.5%
```

**25.1 — THE NUMBER: band blackness at those placements (verbatim):**
```
=== DUNGEON: band blackness AT THE GAME'S OWN CHARACTER PLACEMENTS ===
    piece        placements  band INKED%  band BLACK%
    floor                30        8.95%       91.05%
    exit2                11       22.56%       77.44%
    torch                10       10.21%       89.79%
    posts                 4       43.73%       56.27%
    space                 2        0.00%      100.00%
    -------------------------------------------------
    WEIGHTED             57       13.92%       86.08%  <== the number

=== PALACE ===
    WEIGHTED             57       15.73%       84.27%  <== the number
```

**25.1 — the two refinements that decide it (verbatim):**
```
=== (a) how often does drawa's MASK apply at a real placement? ===
    left neighbour is panelwif/panelwof/pillartop/block/archtop1 in 0/57 placements (0.0%)
    masking only REMOVES ink, so excluding it makes 86.08% a LOWER bound on blackness.
    At 0.0% exposure the correction is small; the bound cannot reach 90%.

=== (b) VERTICAL distribution of ink in the band (is it floor-hugging?) ===
    y  0-9   (feet/shins)      25.31%
    y 10-19  (knees/hips)      12.06%
    y 20-29  (torso)            8.92%
    y 30-40  (head/shoulders)   9.82%
    WHOLE BAND                 13.92%  => 86.08% black
```

**25.2 — recon artifacts:** `harness/tools/playfield_census.py`, `harness/tools/playfield_band.py`.

**25.3 — no real frames captured, and none needed.** §2(c) makes the oracle spot-check conditional on
(a)/(b) being **ambiguous**. They are not: 86.1%/84.3% sits clearly below the ~90% threshold in both themes,
and the one excluded term was measured at 0/57 exposure. **No PNG was generated, so none is surfaced**
(`CLAUDE.md §3`). **The fidelity call remains Jay's** — this recon supplies the number and a recommendation;
it does not self-certify a visual judgement. If Jay wants the census corroborated against real frames before
ruling, that is §8.1.

**`git status --porcelain` (tracked):**
```
A  harness/tools/playfield_band.py
A  harness/tools/playfield_census.py
A  reports/20260726-151849-pa-13-playfield-blackness.md
```

---

### 6 — Reactive deviations

1. **Two dispatch premises corrected** (§1): `.PAL` is the palace **theme**, not palettes (`EditorDisk`
   `1 = dunj, 2 = palace`); and the dispatch's "no static cel→placement map" is true for *cels* but the
   **level blueprints are fully decodable**, so this is a census of the real world rather than the
   tile-composition estimate §5.2 anticipated. Both make the answer stronger, so I took them.
2. **The sample frame is the game's own placement data, not a walkability rule I invented** (§3.3). I started
   toward classifying types as standable from `pieced != 0`, noticed that admits `block` (a solid wall the
   prince cannot stand on, 39.5% of the world and 65% inked — it would have badly skewed the number), and
   switched to `KidStartBlock`/`GdStartBlock`.
3. **Two measurement passes; the first is superseded.** `playfield_census.py`'s coverage column sums ink over
   band area and can exceed 100%. `playfield_band.py` rasterizes and clips. Both are committed — the census
   still carries the per-type/world-frequency data — but **the band rasterizer is the number**.
4. **The real-frame spot-check (§2(c)) was NOT run**, on its own stated condition (only if ambiguous). Stated
   rather than quietly skipped.
5. **No idiom filed.** The `bgtable2` base finding is POP-data-specific, not a MAME/build idiom; it is
   recorded in the tool's docstring and §3.4. Flagging the judgement in case the Orchestrator wants it in
   an idiom file anyway.

---

### 7 — Uncertainty flags

1. **`drawa` masking and gate/slicer special-case fronts are not modelled.** Both can only remove ink, so
   86.08% is a **lower** bound on blackness. Exposure measured at **0/57 placements**, so it cannot lift the
   result to the 90% threshold — but on a different placement sample it would matter.
2. **The band is a 28×41 rectangle, not the prince's actual silhouette.** I measured the blackness of the
   *region* his body occupies, not of the pixels immediately adjacent to his outline. If his silhouette
   systematically avoids the inked parts (e.g. he stands centred between lit floor edges), true edge
   exposure would be lower than 13.9%; if it hugs them, higher. **Closing this needs the per-cel placement
   work the dispatch ruled intractable.**
3. **57 placements is a small sample** — level-start and guard-start positions only. It is the game's own
   data and covers all 15 levels, but it is *starting* positions; where the prince spends most of his time
   (mid-room, on ledges, climbing) is not sampled. The world-wide standable figure (54.6% black) is much
   worse than the placement figure (86.1%), which suggests placements sit in blacker-than-average spots —
   so the true in-play number may be **lower** than 86.1%, strengthening the fidelity-first verdict rather
   than weakening it.
4. **Cutscenes, the title sequence and non-dungeon/palace contexts are outside this census entirely.**
5. **Guard cels are shorter than the prince's 41 lines**; using 41 for every placement slightly over-samples
   the upper band, which is the *blacker* part — a small optimistic bias in the same direction as (3).

---

### 8 — Follow-up candidates

1. **If Jay wants the verdict corroborated visually**, run the oracle and capture a handful of real frames
   across a dungeon and a palace room (§2(c) as written). Cheap, bounded, and would test §7.2 directly.
2. **Interior-black (region 1) is always safe and needs no background analysis** — it can be authored and
   measured whenever the art pipeline reaches it, independent of this verdict.
3. **If the cycle picture ever changes** (heavier scenes, added actors, a costlier engine), re-open the
   lever with §7.3's caveat in mind: the in-play number is likely *below* 86.1%, not above.
4. Standing: the **§2A.3 authorship ruling** (now **fourteen** deferrals).

---

### 9 — User interaction during task
**None.**

---

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-07-26-a-decode-that-fails-to-empty-biases-silently.md` — *"A decoder that returns
EMPTY on failure rather than raising produces a complete, plausible-looking result with a systematic hole —
and the hole has a direction, so it biases the conclusion rather than merely weakening it."* Fresh
single-instance row (`initiator: clyde`); no existing entry read or edited.

Arose from §3.4: `bgtable2` decoded at the wrong base yielded zero images, every `$8x–$Ax` architectural
piece scored 0% ink, the census printed a full table, and the bias ran toward *more black* — the direction
that argues for pulling the lever this report recommends against.

---

### 11 — Commit
`<hash>` — pushed to `origin/wip` before this report.
