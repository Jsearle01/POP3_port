## Form B Report — P5.8 — the foreground plane observed, and the first error only Jay can rule on

**Class:** recon (Phases 1-3) + proposal (Phase 4, no code). `wip`. Prod byte-identical at both ends.

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-22T02:20:28Z (HEAD `b73d752`, wip; **`main` at `32b5fe2`, resolved here**).

`git status` at receipt — the standing untracked set: `.vscode/`, `nvram/`,
`POP-idioms-coco3-markers.md`, `content/intro/broderbund_splash_render.bin`, nineteen files under
`docs/ground-truth/`, `docs/project/pop-coco3-design-v0_7.pdf`. One modified tracked file,
`dist/mame-cfg/rgb/coco3.cfg` — **★ dirty, left dirty, not touched.**

**Prod sha1 — identical at both ends (AC14). Nothing rebuilt:**

```
d07f1f3295525783968dcce6409ee1b64942231c  build/intro_seq.bin
0b4968867bf5274d2942f3b5b90ea855ad6f2def  build/loader.bin
790836577e56b61b8f849cb309874e44304840a2  build/cutscene_room.bin
```

**AC13 — the stop observed:** `git status --porcelain src/` → **0 lines** at both ends.

---

### 1 — Summary

**★★ §5.170 IS CLOSED. `DRAWFORE` runs, on every screen the demo visits, and it is busy.**
Write-tapped on `fgX` [`GRAFIX.S:603`]: **screen 1 peaks at 16 entries, screen 2 at 14, screen 4 at
19.** The call order was decoded from the machine's own bytes — `DRAWALL`'s body read through the
jump table at `$0403`, its `JSR` operands walked in sequence — putting **`DRAWMID` ($075A) sixth and
`DRAWFORE` ($06ED) seventh**. Characters draw in `DRAWMID`. The foreground really does draw after
them.

**Every one of §1's mechanism claims holds this time**, which is worth saying given the record it was
flagged against: `drawgatebf` does use `ora` + `addfore`; `gatebotORA`/`gatebotSTA` are separate image
data; `maddfore` is a two-pass mask-then-or, **caught live** as `$46/mask` immediately followed by
`$46/ora` at the same XCO/YCO; and `blit_core.s`'s `$C0` merge is exactly those two passes in one
operation.

**But the plane's contents are not what the framing expected.** The gate is a minority. **15 of
screen 1's 16 foreground entries are `$83` — the WALL BLOCK's front piece [`fronti[20]`], drawn
`sta`, fully opaque.** The foreground plane's main job on a dungeon screen is not transparency at
all; it is putting **walls in front of the prince** so he can walk behind them. P5.0's original claim
was right.

**★ AC7 — the calibration point now exists, and it is bigger than P5.7's.** The gate bar `$46` is 1
byte × 60 rows — almost entirely edge — so the keyed-conversion error reaches **60 px of 420 (14.3%)**
and is **100% black↔lit**, the visible kind. `posts $45` is **55 px of 1,239 (4.4%)**, also 100%
black↔lit, and **never reaches zero in any of 25 contexts.** These are the first errors this project
has that only Jay can rule on.

**★ And one correction to my own method, because it nearly produced the opposite report.** My first
run *sampled* `fgX` at six frame boundaries and read **0 on all four samples that were on a real
screen** — the list is built, consumed and cleared inside one frame, so a boundary read always sees
zero. I was one step from filing "the foreground plane is unused in play." **The write tap is what
found 43 non-empty writes on that same screen.**

---

### 2 — Files modified

- `harness/tools/oracle_fore_trace.lua` — **new.** Write-taps `fgX`, decodes `DRAWALL`'s call order
  from live memory, dumps the fore list and the kid's box at each screen's peak.
- `reports/20260822-024500-p5-8-...md` — this report.

Nothing under `src/`, `link/`, `content/`. `build.bat` untouched. No bake, no renderer.

---

### 3 — Reasoning

#### 3A — AC1: the plane census, and the mechanism §1 missed

*Authority: source for the call sites, trace for what actually runs.*

**★ The plane is not a property of the piece. For most kinds it is chosen by a self-modifying jump.**

```
add
]add    jmp addback          ;self-mod
setback lda #addback / sta ]add+1 ...
setmid  lda #addmidezfast / sta ]add+1 ...
```
[`FRAMEADV.S:1161-1174`]

`SURE` calls `setback` once [`FRAMEADV.S:53`, *"draw on bg plane"*] so a **whole-screen composite puts
every `jmp add` piece in the background**. `FAST`'s incremental phases re-point it per dirty-buffer
class: `redbuf`/`movebuf` → `setback` [`:399`, `:412`], `floorbuf`/`halfbuf` → `setmid` [`:426`,
`:439`]. **So the same piece lands in different planes depending on which redraw path reached it** —
a fact neither §1 nor P5.7 accounts for, and the reason a per-piece plane table would be wrong.

Per kind, with the `OPACITY` in force at the call site (`and=0, ora=1, sta=2, mask=4`
[`EQ.S:488-492`]):

| kind | routine | plane | OPACITY |
|---|---|---|---|
| torch | `drawtorchb` [`:1493`] | **`jmp addback`** — always background | `sta` (via `SETUPFLAME`) |
| spikes | `drawspikea`/`b` [`:1453`,`:1473`] | `jmp add` — back or mid | **`ora`** |
| loose | `drawloosed` [`:1365`] | `jmp add` | `sta` |
| loose | `drawlooseb` [`:1388`] | `jmp add` | **`ora`** |
| slicer | `drawslicera` [`:1548`] | `jmp add` ×2 | **`ora`** |
| slicer | `drawslicerf` [`:1590`] | **`jmp maddfore`** | `mask` then `ora` |
| gate | `drawgateb` [`:1814`] | **`addback`** ×4 | `ora` if below floor line, else `sta` |
| gate | `drawgatec` [`:1701`] | `jmp add` | — |
| gate | **`drawgatebf`** [`:1765`] | **`addfore`** ×2 | **`ora`** |
| exit | `drawexitb` [`:1616`] | `jmp add` | mixed |
| (static) | `drawfrnt` [`:754`] | **`addfore`** / `maddfore` | `sta`, or mask+ora |

★ **`drawgateb`'s two-image choice is a POSITION split, not a plane split**, and the source says why:
*"Bottom piece is partly below floor line — STA won't work. We need to redraw b.g., then OR gate
bottom on top."* [`FRAMEADV.S:1817-1818`] So `gatebotORA` is used **in the background plane too**,
whenever the gate bottom crosses the floor line. §1 read the pair as a background/foreground split;
it is used in three places, not two.

#### 3B — AC2: are the `ora` variants separate image data? **Yes.**

| image | table entry | w × h | Apple B |
|---|---|---|---|
| `gatebotSTA` `$43` | bgtable1 #67 | 3 × **12** | 36 |
| `gatebotORA` `$44` | bgtable1 #68 | 3 × **10** | 30 |

**Separate data, and the two-row difference is exactly the documented one.** `drawgatebf` does
`sbc #2 ;no 2 blank lines at bottom` [`FRAMEADV.S:1776-1777`] — the ORA variant is the STA variant
with its two blank bottom rows removed, because an OR of blank rows would paint nothing while an STA
of them would erase floor. **Two images of the same art, differing by the rows that opacity makes
meaningful.**

#### 3C — AC4: `DRAWFORE` observed

*Authority: trace.*

**The order, decoded from live memory rather than from the listing.** `$0403` holds `jmp DRAWALL`
[`GRAFIX.S:15-16`]; following it and walking the `JSR` operands:

```
# DRAWALL body at $065D (from the jump table at $0403)
# DRAWALL call order: $0679 -> $0725 -> $08CC -> $068E -> $06BF -> $075A -> $06ED -> jmp $07D9
#                     DOGEN   SNGPEEL  ZEROPEEL DRAWWIPE DRAWBACK DRAWMID  DRAWFORE  DRAWMSG
```

Seven calls and a terminating `jmp`, matching `GRAFIX.S:485-505` exactly. **`DRAWMID` is sixth,
`DRAWFORE` seventh.** Characters are mid-plane objects — `DRAWMID`'s own comment is *"& save
underlayers to now-clear peel list"*, which is the character peel-save — so **the foreground plane
draws after the characters.** §5.170's ordering claim is confirmed, and now from bytes.

**The plane is used, on every screen the demo visits:**

```
#   VisScrn   1 :   70 frames,   43 non-empty writes, peak 16
#   VisScrn   2 :  152 frames,  102 non-empty writes, peak 14
#   VisScrn   4 :  109 frames,  126 non-empty writes, peak 19
```

**Contents at each screen's peak:**

| screen | peak | contents |
|---|---|---|
| 1 | 16 | `$45/sta ×1`, **`$83/sta ×15`** |
| 2 | 14 | `$44/ora ×1`, `$46/mask ×1`, `$46/ora ×1`, `$83/sta ×11` |

★ **Entries 13 and 14 on screen 2 are `maddfore` caught in the act** — the same image `$46` at the
same XCO 39 / YCO 62, first with `mask` then with `ora`. §1's reading of the two-pass, confirmed
live rather than inferred.

**What the images are:**

| image | source | w × h | what it is |
|---|---|---|---|
| **`$83`** | bgtable2 #3, `fronti[20]` and `blockfr` [`BGDATA.S:78,189`] | 4 × 60 | **the WALL BLOCK's front piece** |
| `$45` | bgtable1 #69, `fronti[3]` | 3 × 59 | **posts** |
| `$44` | bgtable1 #68 | 3 × 10 | gate bottom (ORA) |
| `$46` | bgtable1 #70, `fronti[4]` | 1 × 60 | **the gate bars** |

★ **§5.170 CLOSED.** Observed, ordered, and enumerated.

#### 3D — AC5: what a port that ignored the plane would get wrong

*Authority: trace — the fore list and the kid's record read from one machine state.*

At screen 1's fore-plane peak the wall pieces tile most of the two lower block rows:

```
$83 at YCO 188, XCO {0,4,20,24,28,32,36}     -> block columns 0,1,5,6,7,8,9
$83 at YCO 125, XCO {0,4,16,20,24,28,32,36}  -> block columns 0,1,4,5,6,7,8,9
kid: KidX 192 KidY 55 posn 45 | FCharX 15 FCharY 151 image 11
```

**15 of the 20 block cells in those two rows carry an opaque foreground wall piece.** A `$83` is 4
Apple bytes × 60 rows — a full block column, 28 px wide.

**So the error is not a seam. It is a whole character on the wrong side of a wall.** Where the
prince overlaps one of those 15 cells, *every byte of his cel* is drawn in front when the oracle
draws it behind. Using P5.2/P5.6's measured kid-cel figures, that is **up to 1,101 bytes per frame,
median 474** — and visually it is the prince standing on top of a wall he should be inside.

**★ A port that ignored the foreground plane would not look slightly wrong on screen 1; it would look
wrong wherever the prince stands, which is 15 cells of 20.** That is what makes this a defect rather
than a worry, and it is the answer §3.3 asked for.

#### 3E — AC6: `ora` in 4-colour, and whether `$C0` provides it

*Authority: source, both sides.*

On the Apple, `ora` is a bitwise OR of 1-bit-per-pixel data: set pixels paint, clear pixels leave the
background. **In 4-colour that operation is meaningless** — index 0 is a palette entry like any
other, and OR-ing index 1 with index 2 yields index 3 (white), a colour neither operand had.

**The correct 4-colour semantics of Apple `ora` is a KEYED COPY:** where the source pixel is index 0,
leave the destination; otherwise write the source. And that is exactly what `blit_core.s` already
expresses:

```
*   $00            end of row
*   $40|n          skip n transparent bytes
*   $80|n <data>   blast n opaque bytes (groups pre-reversed)
*   $C0|n <pairs>  merge n bytes as (mask,src): dest = (dest AND mask) OR src
*
* Transparency is index 0 and there is no opacity sidecar (P3.18 3B), so the mask
* is built from index-0 pixels at bake time.
```
[`src/engine/blit_core.s:42-52`, verbatim]

**`$40` skip** covers whole transparent bytes, **`$80` blast** whole opaque ones, and **`$C0` merge**
the mixed bytes where a 4-pixel group straddles the key. So:

> **AC6: yes. `$C0` merge provides `maddfore`'s mask-then-or in one pass, and `$40`/`$80` provide
> plain `ora` exactly. §1's claim holds.**

★ **And a consequence §1 did not draw: the oracle's separate `maska` mask images are not needed by
the port.** `addamask` loads `maska,x` and draws it with `and` [`FRAMEADV.S:1184-1193`] because the
Apple has no way to derive a mask from 1-bpp art at run time. The port's mask **is derived from the
cel's own index-0 pixels at bake time**, so the mask images are Apple-format overhead the port does
not carry. That is a real saving and it is already implemented.

#### 3F — AC7: the keyed-conversion error, and what it looks like

*Authority: exhaustive computation over the frozen colour model.*

Same method as P5.7 §3C: convert the cel in isolation, then as the middle of a three-byte strip over
25 boundary-neighbour pairs, and count differing pixels in the cel's own footprint. All three pieces
taken at their real position (XCO 39 → CoCo pixel 293, phase 1).

| piece | w × h | pixels | keyed (index-0) | contexts with **zero** error | **worst error** | character |
|---|---|---|---|---|---|---|
| **gate front `$46`** | 1 × 60 | 420 | 25% | 10 of 25 | **60 px = 14.3%** | **100% black↔lit** |
| **posts `$45`** | 3 × 59 | 1,239 | 38% | **0 of 25** | **55 px = 4.4%** | **100% black↔lit** |
| gate bottom `$44` | 3 × 10 | 210 | 87% | 10 of 25 | 1 px = 0.5% | 100% chroma |

**★ Three things in that table matter.**

1. **14.3% is an order above P5.7's flame figure (1–3 px of 91)**, and the reason is geometry: `$46`
   is **one byte wide and sixty rows tall**, so almost every pixel is an edge pixel. **A tall thin
   keyed cel is the worst possible shape for edge-context error**, and the gate bar is exactly that.
2. **`posts $45` never reaches zero — 0 of 25 contexts.** The flame's zero was a placement accident
   [P5.7 §3C]; the posts have no such accident available. **Whatever background they are placed on,
   they are wrong somewhere.**
3. **The error is 100% black↔lit for both large cases.** §5.202 found 422 of 662 black↔lit for tiles
   and called that visible; this is 100%. It is the visible kind, not a chroma swap.

> **★★ THIS IS THE CALIBRATION POINT §5.231 SAID DID NOT EXIST.** Up to 60 pixels of a gate bar, all
> black-versus-lit, at the cel's edge. **The number is stated; whether it is acceptable is Jay's, and
> this report does not decide it.**

#### 3G — AC8: is per-context baking available for foreground pieces?

**For the wall pieces and posts: YES, trivially** — `$83` and `$45` are drawn `sta`, fully opaque, at
block-aligned positions. **They are not keyed at all**, so they bake exactly like P5.5's tile
variants and carry **zero** conversion error. The 14.3% problem does not touch the 15 of 16 entries
that are walls.

**For the gate bars: YES, but over states rather than positions.** The background behind a gate bar
is the composited screen, which is fixed per screen. What moves is the **bar itself**: `drawgatebf`
places pieces at `gatebot-2` and then from `gatebot-12` stepping by 8 [`FRAMEADV.S:1770-1800`], and
`gate8b`/`gate8c` are **8-entry tables** [`BGDATA.S:94-95`]. So the context is enumerable over
**~8 vertical states per gate placement**, and `LEVEL0` has 4 gates → **~32 variants at 120 B each =
~3,840 B** if every state were baked.

★ **So the answer to §4.2's worry is that the context IS enumerable** — the gate's animation moves the
*piece*, not the *background*, and a moving piece over a fixed background is exactly the case
per-context baking handles. It is not the unbounded case the question anticipated.

#### 3H — AC3: the class re-sized by plane, and the budget effect

**P5.7 sized 28 animated blocks as one class at 6,105 B — a SUM over the level. The plane split does
not change that sum**, because the same cels are involved; it changes *where they must be drawable
from* and *what they must be drawn with*.

What the split **adds** is the class P5.7 never counted, because it was sizing *animated* blocks and
these are static:

| piece | plane | coco3 B | residency or sum |
|---|---|---|---|
| `$83` wall front | fore, `sta` | **420** | SUM — one cel, 15 placements |
| `$45` posts | fore, `sta` | **354** | SUM — one cel |
| `$44` gate bottom | fore, `ora` | 60 | already inside P5.7's gate 882 B |
| `$46` gate bars | fore, mask+ora | 120 | already inside P5.7's gate 882 B |
| **new to the budget** | | **774 B** | |

**Budget effect: +774 B, which is small and does not move the block count.** P5.7 found the division
over by one block at W1 with the animated class at 6,105 B; at 6,879 B it is over by the same one
block. **The plane split is not what breaks the budget, and it does not rescue it either.**

---

### 4 — Phase 4: the proposal (AC9-AC12)

#### 4.1 — AC9: does the two-format question resolve here? **Yes, and in the direction §5.210 left open.**

§5.210 measured the segment stream at **1.42× larger than raw for opaque tiles** and left the ruling
open. This dispatch supplies the missing half: **for a keyed piece, raw is not a candidate at all.**
A raw rectangle written opaquely over a character *erases* it — which is precisely the hazard Jay
named — so the choice for `$46` and `$44` is not raw-versus-segments, it is segments or a second
mechanism.

> **The ruling that follows: raw for opaque, segments for keyed. That is not a compromise between two
> formats; it is each format used where the other cannot go.** Raw's 1.42× advantage is real and
> applies to the 15-of-16 opaque foreground pieces; segments' cost buys transparency for the few that
> need it.

★ **And the split is cheap because the keyed set is tiny.** On the demo's screens the keyed
foreground is `$44` (60 B) and `$46` (120 B) — **180 B of segment-format data against 774 B of raw**.
The two-format question turns out to be a question about 180 bytes.

#### 4.2 — AC10: where they live

Against P5.7's zero-spare budget and its co-mapping constraint — **foreground pieces draw in the same
frame as the characters they occlude, so the ≤2-blocks rule applies to them exactly as to animated
scenery.**

**They should live in the same place P5.7 put the animated cels: duplicated into the character
blocks whose frames draw them.** The reasoning is identical and the cost is smaller — 774 B of new
cel data, against 7,074 B for the animated class. It does not change P5.7's block count, and it does
not change P5.7's conclusion that **the division is over by one block at W1**.

#### 4.3 — AC11: the smallest artifact Jay could rule on

**One screen-2 gate bar, converted keyed, blitted over the baked screen, on hardware.** That is the
smallest thing that produces the error in §3F, because the error needs three ingredients and no
fewer: a **keyed** cel (so `$83` will not do), a **lit** background (so the cutscene's flames will not
do), and the **real** conversion (so a synthetic test will not do).

Concretely: screen 2's `$46` at XCO 39 / YCO 62, over P5.5's existing bake, drawn with `$C0` merge.
Everything it needs already exists except the cel conversion and one blit call.

**What Jay would be looking at:** a vertical gate bar on a dungeon wall with **up to 60 pixels along
its two edge columns showing black where the wall should show, or wall where black should be.** Not a
colour shift — a hard edge artifact.

#### 4.4 — AC12: what I am NOT proposing

1. Not proposing to **build** any of it. No code, no bake change, no renderer change.
2. Not proposing to **rule on the 14.3%.** The number is measured; acceptability is Jay's alone, and
   §5.231's point was precisely that this project has been substituting tool standards for that
   judgement.
3. Not proposing a **seam remedy** — per-context baking is shown *available* (§3G), not chosen.
4. Not proposing to **change `blit_core.s`.** §3E finds its format already correct for this job.
5. Not proposing to **convert the dungeon flames** [§5.229], choose among **A/B/C** [§5.235], or
   **re-derive W1** — all excluded, and §3H is explicit that the budget still turns on the last.
6. Not proposing a **plane-aware renderer**. §3A shows the plane is partly a run-time property of the
   redraw path, which is a design problem this dispatch only characterises.
7. Not proposing anything about **`maska` removal** as work — §3E notes the port already avoids it.

---

### 5 — Verification (AC-by-AC)

- **AC1** — §3A. All six kinds, per routine, with plane and `OPACITY` from the call sites, plus the
  self-modifying dispatcher §1 missed.
- **AC2** — §3B. **Separate image data**, differing by exactly the two blank rows the source names.
- **AC3** — §3H. Re-sized by plane; **+774 B**, each figure labelled; block count unchanged.
- **AC4** — §3C. **`DRAWFORE` observed in trace**, order decoded from live memory, contents
  enumerated for the demo's screens. **§5.170 closed.**
- **AC5** — §3D. 15 of 20 block cells carry an opaque wall piece; the error is a whole cel
  mis-layered, up to 1,101 B/frame.
- **AC6** — §3E. Keyed-copy semantics established; **`$C0` merge provides them**; `maska` unnecessary.
- **AC7** — §3F. **60 px of 420 (14.3%)** for the gate bar, **100% black↔lit**; posts never zero.
- **AC8** — §3G. Available: trivially for opaque pieces, over **~8 states per gate** for keyed ones.
- **AC9** — §4.1. **Resolved: raw for opaque, segments for keyed**, and the keyed set is 180 B.
- **AC10** — §4.2. Duplicated into the character blocks; no change to P5.7's block count.
- **AC11** — §4.3. One screen-2 gate bar over the existing bake.
- **AC12** — §4.4, seven non-proposals.
- **AC13** — §0. `git status --porcelain src/` → 0 lines.
- **AC14** — §0. Prod sha1 triple identical at both ends.
- **AC15** — **suites NOT run, and saying so.** Nothing was built — no source, link script, bake input
  or disk image changed, and `build.bat` was not invoked. The suites would have re-tested the exact
  artifacts P5.5 gated; the unchanged sha1 triple is the evidence.
- **AC16** — §6.

---

### 6 — Reactive deviations and route accounting

**Deviations:**

1. **★ I nearly filed the opposite finding, and the method is the reason.** My first trace *sampled*
   `fgX` at six frame offsets and read **0 on all four samples taken on a real screen**. The fore list
   is built, consumed by `DRAWFORE` and cleared by `ZEROLSTS` **within one frame**, so a
   frame-boundary read always sees zero. §8's "a negative result is a result" was in reach and would
   have been **wrong**. The write tap found 43 non-empty writes on the same screen. The tool now
   carries this in its header, and the peak dump happens *inside* the tap for the same reason.
2. **AC7 was measured in conversion space, not from a captured port framebuffer** — the same
   substitution P5.7 §6.3 recorded, and for the same reason: no port pixel of a keyed foreground
   piece exists yet. §4.3 names the artifact that would produce one.
3. **I read `$83`'s identity from `fronti[20]` and `blockfr`**, not from a routine that names it. The
   index-to-name mapping is `PIECE_NAMES`, which is `bg_compose.py`'s transcription rather than a
   source table I re-verified. Flagged in §7.

**ROUTE ACCOUNTING.** No route was proposed in conversation before this task. Within it the plan
changed once, in §6.1: sample-then-report became tap-then-dump-at-peak after the samples disagreed
with the write counts. **Both are stated; the first is not deleted, because the disagreement is what
established that the list does not survive its frame.**

**This report contains:** AC1-AC16, one new trace tool, no engine change.
**It does not contain:** any build, any code, any adoption, and none of §4.4's seven non-proposals.

---

### 7 — Uncertainty flags

1. **★ The 14.3% is one cel at one phase against synthetic neighbours.** `$46` at XCO 39 → phase 1,
   over 25 representative neighbour bytes — not against screen 2's actual composited background at
   each of the gate's 8 vertical states. **The real figure could be anywhere between 0 and 60 px**
   depending on what the wall does at those rows. §4.3's artifact is what settles it, and the
   report's headline number should be read as *the bound*, not the observed error.
2. **`PIECE_NAMES` is a transcription.** `$83 = fronti[20] = block` rests on `bg_compose.py`'s name
   list, which I did not re-derive from source this task. The *behaviour* is independent of the name
   — 15 opaque 4×60 pieces at block columns in the foreground plane — but the word "wall" is one
   indirection from evidence.
3. **Screen 4's peak (19 entries) was not dumped.** The peak-dump fires on a new high-water mark and
   screen 4's arrived after the sampling window closed in the run that had content logging enabled.
   Its count is measured; its contents are not.
4. **The gate's "8 states" is inferred from table length** (`gate8b`/`gate8c` are 8 entries), not from
   observing `gatebot` take 8 distinct values. §3G's 3,840 B estimate scales directly with it.
5. **§3A's plane-per-redraw-path finding is characterised, not enumerated.** I established that
   `setback`/`setmid` re-point the dispatcher per `FAST` phase; I did not build the full table of
   which piece reaches which plane under which dirty-buffer class. That table is what a plane-aware
   renderer would need.
6. **AC5's 1,101 B is P5.2's max kid cel, not a measured overlap at the captured instant.** The kid's
   cel dimensions at `image 11` were not resolved (its table comes from `FCharTable`, which I did not
   read). The claim that *some* whole cel is mis-layered is solid; the exact byte count at that frame
   is not.

---

### 8 — Follow-up candidates

1. **Build §4.3's artifact** — one keyed gate bar over the existing bake, on hardware. It closes
   flag 1 and gives Jay the first error he can rule on.
2. **Enumerate the plane-per-redraw-path table** (flag 5), which a plane-aware renderer needs before
   it can be designed.
3. **Dump screen 4's fore-plane peak** (flag 3) — 19 entries, the busiest observed, contents unknown.
4. **Confirm `gatebot`'s state count** by trace rather than table length (flag 4).
5. **Re-derive W1** — still the figure the whole budget turns on, still excluded, now referenced by
   three consecutive reports.

---

### 9 — User interaction during task

None.

---

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-22-transient-state-cannot-be-sampled-tap-the-write.md` — §6.1: the fore
list is built, drained and cleared inside one frame, so polling it read zero four times and the
write tap read 43. Pushed to the pool as `43f7af8`.

---

### 11 — Commit

Recorded in the push that carries this report to `origin/wip`. **`main` is untouched at `32b5fe2`.**
