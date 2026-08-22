## Form B Report — P5.6 — two residencies, and why the rotation is a register rather than a copy

**Class:** recon (Phases 1-2) + proposal (Phase 3, no code). `wip`. Prod byte-identical at both ends.

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-22T01:06:08Z (HEAD `93e0002`, wip; **`main` at `32b5fe2`, resolved here**).

`git status` at receipt — the standing untracked set, named: `.vscode/`, `nvram/`,
`POP-idioms-coco3-markers.md`, `content/intro/broderbund_splash_render.bin`, nineteen files under
`docs/ground-truth/`, `docs/project/pop-coco3-design-v0_7.pdf`. One modified tracked file:
`dist/mame-cfg/rgb/coco3.cfg`. **★ It is dirty and it stays dirty** — the ruling is Jay's, not this
dispatch's, and it was not touched.

**Prod sha1 — identical at both ends (AC9). Nothing was rebuilt:**

```
d07f1f3295525783968dcce6409ee1b64942231c  build/intro_seq.bin
0b4968867bf5274d2942f3b5b90ea855ad6f2def  build/loader.bin
790836577e56b61b8f849cb309874e44304840a2  build/cutscene_room.bin
```

**AC8 — the stop observed:** `git status --porcelain src/` → **0 lines**, at receipt and at the end.
No engine code, no bake change, no renderer change.

---

### 1 — Summary

**W0 does not survive as a window requirement. W1 does survive — as a RAM requirement, which is a
different thing, and the project has been using one word for both.** The window needs **one frame's
cels: 1,828 B at the worst frame measured**, against a 15,872-byte window. That is a **seventh of
W0** and a **twenty-seventh of W1**.

**Jay's framing survives the measurement, and the reason it survives is not the reason it was
proposed.** Characters cannot all be *mapped* — 49,924 B against a 15,872 B window — but they can
all be *resident*, in 7 of the 8 free physical blocks. What rotates per frame is then **an MMU
register, measured at 7 cycles**, not a byte of data. Tiles rotate by disk read, on room change.
So the expensive rotation lands on the rare event and the cheap one on the frequent event, which is
Jay's principle exactly, stated in the two currencies it actually spends.

**The contiguity answer is NO under the dispatch's premise and YES under the corrected one**, and
the difference is worth more than either answer:

- **One block ($FFA7 alone):** impossible. "Same block" is transitive, so the connected components
  of the co-occurrence graph are the finest partition anything can achieve, and one component is
  **34,618 B — 4.2× a block**. A covering with duplication works but costs **64% overhead and all 8
  free blocks**, leaving nothing for tiles.
- **Two blocks ($FFA6 + $FFA7):** **5 blocks, ZERO duplication, and 256 of 261 frames already clean.
  The 5 that are not cost 1,503 B — 4.16%.**

The premise that made the difference is that `$FFA6` is **not** spoken for by the tile page during
play: the port's peel restores background from the **framebuffer**, not from the page [§3E].

★ **Two of the dispatch's figures do not hold and are corrected in §4.2:** `$02/$03/$06/$07` is
**32,768 B, not 65,536** — the larger figure needs all eight free blocks, including `$0C-$0F`. And
the byte-level arithmetic that "fits with ~8,030 spare" fits in *bytes* while leaving **zero spare
blocks**, which is the unit that binds.

---

### 2 — Files modified

- `harness/tools/char_residency.py` — **new.** Window residency, RAM residency, the co-occurrence
  component proof, the temporal covering, the two-block partition, and the repair cost.
- `reports/20260822-011500-p5-6-...md` — this report.

Nothing under `src/`. Nothing under `link/`. `build.bat` untouched.

Measurement scratch, deliberately outside the repo (scratchpad, not committed):
`p56_switch.s` / `p56_switch.bin` — three candidate switch shapes, assembled so AC4's cycle counts
are **decoded from emitted bytes** rather than counted off a table by hand.

---

### 3 — Reasoning

#### 3A — AC1: the two residencies, each stating what it is a set OF and over what extent

*Authority: execution trace (the oracle's own `setimage` output, write-tapped) for both.*

Source: `build/tmp/frame_drawset.txt`, 266 gameplay frames (7930..9584, 4.44 s at 59.92 Hz), filtered
by `frame_drawset.py`'s exact validator — an address must be in its table's own pointer list **and**
the live (w,h) must equal the vendored file's. Costs are port-side packed 4-colour, `ceil(w*7/4)*h`.

**WINDOW residency — SET OF: the distinct cels ONE FRAME draws. INTERVAL: one frame. EXTENT: the
15,872 B window ($FFA6 8,192 + $FFA7 7,680).**

| set | min | median | p90 | p99 | MAX |
|---|---|---|---|---|---|
| character cels/frame | 164 | 543 | 1,284 | 1,633 | **1,828** |
| tile cels/frame | 30 | 254 | 1,330 | 3,439 | 3,700 |
| both kinds/frame | 268 | 1,005 | 2,002 | 3,439 | 3,700 |

★ **The worst character frame is 9328, and what is happening in it is a sword fight** — the kid and
the opponent both on screen, both armed:

```
  chtable5@$A9A7   kid        6x35   385 B
  chtable5@$B313   kid        6x34   374 B
  chtable4@$9D5A   opponent   5x38   342 B
  chtable5@$A8E7   kid        5x38   342 B
  chtable4@$9E1A   opponent   5x37   333 B
  chtable3@$1675   kid/sword  3x6     36 B
  chtable3@$1701   kid/sword  2x4     16 B
  TOTAL                             1,828 B   -> one block: FITS, 6,364 spare
```

**So §3.3's guess is confirmed: the fight IS the worst case**, and it is worst by *cel count* (seven
distinct cels in one frame, five of them large) rather than by any single cel being big.

**RAM residency — SET OF: every distinct cel the run ever draws. INTERVAL: the whole run. EXTENT:
physical RAM, so no disk read happens during play.**

| kind | distinct cels | bytes |
|---|---|---|
| kid | 90 | 24,257 |
| kid/sword | 40 | 4,014 |
| opponent | 23 | 7,871 |
| **characters (all three)** | **153** | **36,142** |
| tile | 62 | 6,984 |

★ **This is the RUN's union, not the move graph's.** The demo plays one path; a player at a decision
point can reach moves the demo never made. P5.1's W1 (49,924 B) is the graph-wide figure, and §3B
says which of the two is the requirement.

#### 3B — AC2: which of P5.1's figures survives, and as what

**W0 (12,386 B, mid-move) does NOT survive as a window requirement.** It was computed as a peak over
a MOVE-LENGTH interval on the premise that the window cannot be rearranged mid-move. P5.2 removed
that premise: the draw set is fully determined at the end of `NextFrame`, every frame, with no site
inside the draw path selecting an image. **The window can therefore be rearranged every frame, and
one frame is 1,828 B at worst — 14.8% of W0.** The Orchestrator's §1 reasoning is confirmed, and the
measured figure (1,828 B) is *lower* than the ~2,500 B it estimated from P5.2's subtotals, because
those subtotals were per-kind maxima over different frames and the true worst frame does not
maximise every kind at once.

**W0 does survive as a weak RAM bound**, and is subsumed by W1 — anything true of the mid-move set
is true of the decision set that contains it. It is not independently useful.

**W1 (49,924 B, one decision) SURVIVES, as a RAM requirement.** The question it answers is real and
nothing here displaces it: *what must be in physical RAM so that whichever move the player picks
cannot force a disk read?* That is a RAM-residency question over a decision interval, and 49,924 B
is its answer. **It is not, and never was, a window figure**, and the 15,872 B window it was
implicitly compared against is not the extent it lives over.

**Stated in the words the dispatch asked for: W1 is a RAM requirement and not a window requirement.
W0 is neither, except as a bound W1 already implies.**

#### 3C — AC3: contiguity, and the proof that a partition cannot work

*Authority: trace, and a graph argument over it.*

**"Same block" is transitive.** If cels A and B are drawn in one frame they must share a block; if B
and C are drawn in another, they must too — so A, B and C are all in one block. The **connected
components** of the co-occurrence graph are therefore the finest partition ANY assignment can reach,
and a component larger than a block is a proof of impossibility rather than a failed strategy.

Measured over 153 character cels and 530 co-occurrence edges: **4 components**, and the largest is
**146 cels / 34,618 B — over one 8,192 B block by 26,426**. Three tiny components (719 B, 625 B,
180 B) fit trivially and are irrelevant.

> **★ AC3, the dispatch's question as asked: NO. One frame's character cels cannot be made to share
> a single 8 KB block by any partition, and this is a proof, not a search that gave up.**

**The covering (duplication allowed) works and is expensive.** A cel in two blocks breaks
transitivity. Tested strategy — **temporal**, because consecutive frames of an animation redraw
almost the same cels, so cels near in *time* are exactly the ones that must be near in *space*:
walk the frames in order, close a block when the next frame's set will not fit alongside it.

```
  8 blocks, 92-99% filled, 59,295 B held
  distinct cels 153 / 36,142 B   ->  247 slots / 59,295 B
  DUPLICATION   94 slots, 23,153 B = 64.1% overhead
  lower bound (union / block): 5 blocks
```

**8 blocks is the entire free budget (§4.2), leaving nothing for tiles.** So under the dispatch's
one-block premise the proposal is closed.

#### 3D — ★ AC3 continued: the premise is wrong, and correcting it changes the answer

The one-block question is the right question **only if `$FFA6` is spoken for by the tile page on
every frame.** Under the P5.5 design it is not.

**§2H check 1 — is there a second mechanism for a different object class?** Yes, and it is the whole
point. The ORACLE reads background cels every frame — 261 of 266 frames draw both a tile and a
character — because `ADDBACK` re-draws background under moved sprites. **The PORT does not.** Its
peel saves the background **out of the framebuffer** into a per-character, per-buffer peel buffer and
restores it there: *"PEEL IS PER BUFFER. The page flips every frame, so each character needs its own
saved background IN EACH BUFFER"* [`char_draw.s:107-110`], with the buffers sized to each
character's widest cel [`char_draw.s:118-131`]. **The tile page is read once per room change, into
the framebuffer, and not again.** The oracle's per-frame tile draws are therefore *not* a port window
requirement, and reading them as one is precisely the part-as-whole error §2H exists to catch.

**§2H check 2 — the calling routine.** The port's restore is called from the erase path in
`char_draw.s`, whose source is `slot_peel`'s saved buffer; the tile page's only reader is the
room-change composite. Two callers, two intervals, and only one of them is per-frame.

**§2H check 3 — prior-report grep.** Grepped for `peel`, `ADDBACK`, `$FFA6`, `cel_bank_map`. Found
the standing note that `$FFA6` holds the *cutscene's* pinned cel page — which is where the "$FFA6 is
spoken for" intuition comes from. **That is the cutscene's allocation, not the game's**, and P5.5
pinned the tile page there for a program that draws no characters at all.

**So during play both registers are free, the window is 15,872 B across TWO blocks, and a frame's set
may span them** — both are mapped at once and no cel straddles the boundary.

Re-measured on that premise: partition the 153 cels by first use into 8,192 B blocks with **no
duplication**, then count how many blocks each frame actually touches.

```
  partition: 5 blocks, no duplication, 36,142 B
     block 0   30 cels  8,047 B      block 3   35 cels  7,922 B
     block 1   28 cels  8,183 B      block 4   21 cels  3,880 B
     block 2   39 cels  8,110 B

  BLOCKS TOUCHED PER FRAME (261 character-drawing frames)
     1 block    187 frames  71.6%   -> one register suffices
     2 blocks    69 frames  26.4%   -> fits the two-register window
     3 blocks     5 frames   1.9%   ★ exceeds it
```

**The five frames that fail, named, with the repair:**

| frame | blocks | map | duplicate |
|---|---|---|---|
| 9082 | 0,1,2 | 1+2 | `chtable1@$664B` 266 B |
| 9115 | 0,1,2 | 2+0 | `chtable1@$6879` 234 B |
| 9360 | 1,3,4 | 3+4 | `chtable2@$9EE4` 315 B |
| 9372 | 1,3,4 | 4+1 | `chtable4@$98B3` 429 B |
| 9404 | 2,3,4 | 2+3 | `chtable5@$ACDF` 259 B |

**5 cels need a second home: 1,503 B, 4.16% of the set.** Duplication is legitimate here for the
reason it was not in §3C — it is five cels, not a partition-wide escape.

> **★ AC3, corrected: YES. With both registers, 5 blocks and 1,503 B of duplication cover the entire
> run, and 71.6% of frames need no switch at all.**

#### 3E — AC4: the per-switch cost, measured for THIS pattern

*Authority: emitted bytes, decoded by `cycle_count.py`, whose counts come from the vendored MC6809
manual and which refuses any opcode it does not know.*

**The dispatch offered 24 cy or 48 cy. Neither is this pattern's cost.** Three shapes assembled and
decoded:

| shape | body | as a subroutine |
|---|---|---|
| **A** — block is a constant at the site (`lda #blk` / `sta $FFA7`) | **7 cy** | 20 cy |
| **B** — block from a table (`lda blktab` / `sta $FFA7`) | **10 cy** | 23 cy |
| **C** — two registers under a mask (`cel_bank_map`'s shape) | 40 cy | **48 cy** |

C reproduces the real routine exactly: `cel_bank_map` decoded from `build/cutscene_room.bin` at
`$2322` is **40 cy body / 48 cy with the `jsr`**. So the 48 is right *for that routine* and does not
transfer, because **this pattern writes ONE register and therefore needs no interrupt mask** — the
argument is `vb_apply`'s own: *"That routine writes TWO registers, and between them the window is
half one page and half another — a state nothing may observe. This writes ONE, so every instant
before and after it is a complete, valid map."* [`char_draw.s:2177-2182`]

**The cadence, and what it costs:**

| | switches | per second | cycles/second |
|---|---|---|---|
| measured, 5-block partition | 7 over 4.44 s | 1.58 | **11-16** |
| worst case, a switch every drawing frame | 261 | 58.8 | 412-588 |

Against ~29,859 cy/frame × 59.92 = **1.79 M cy/s**, the measured cadence is **0.0009%** and even the
degenerate worst case is **0.03%**. ★ **The switch cost is not a consideration.** That is the useful
finding, and it is the opposite of the shape of question the dispatch asked — the number matters only
because it is small enough to stop thinking about.

#### 3F — AC5: the LEVEL0 total under the opaque-rectangle model

*Authority: `bake_screen.py`, the same code path P5.5 shipped, run over all 24 screens.*

19 of 24 screens have content; 761 display-list entries level-wide.

| | |
|---|---|
| **A — 24 independent pages** (each screen baked and stored separately) | **54,443 B** |
| mean / worst | 2,865 B / 7,582 B (screen 6) |
| **B — variant data deduped ACROSS the level** (one shared pool) | 104 unique variants, **20,293 B** |
| + display lists, 3 B × 761 | 2,283 B |
| + one global variant table, 104 × 4 (an 8-bit id still suffices at 104) | 416 B |
| + 19 per-screen headers, 4 B | 76 B |
| **B total** | **23,068 B** |
| dedup ratio A→B | **2.36×** |

★ **P5.4's 14,028 B is NOT the number this replaces — it is a different quantity.** It was counted
under the transparent-shape model P5.5 showed is not blittable. The comparable figure is **B, 23,068
B**, so the implementable model costs **1.64× more level-wide** than the model that could not be
drawn. Stated rather than buried: **the opaque model is bigger, and it is the one that works.**

---

### 4 — Phase 3: the budget and the proposal (AC6)

#### 4.1 — ★ The physical budget, corrected

*Authority: source — `src/hal/coco3-dsk/gfx.s:405-417`, quoted rather than recalled.*

On 128 KB the GIME masks every block number mod 16. The HAL's own map:

```
  CPU map   $38-$3B  ->  $08-$0B      program, kernel, stack
  buffer A  $10-$13  ->  $00-$03      but the framebuffer is 15,360 B = $0000-$3BFF,
                                      so only $00-$01 are USED
  buffer B  $14-$17  ->  $04-$07      likewise only $04-$05
  "On 128 KB that leaves $0C-$0F -- 32 KB, exactly one screen -- free."
```

| free blocks | count | bytes |
|---|---|---|
| `$02 $03 $06 $07` — the tails the framebuffers do not reach | 4 | **32,768** |
| `$0C $0D $0E $0F` — the HAL's documented free span | 4 | **32,768** |
| **total** | **8** | **65,536** |

★ **The dispatch attributes 65,536 B to `$02/$03/$06/$07` alone. Those four blocks are 32,768 B.**
The 65,536 figure is correct only for all eight. Two of two blocks visible at a time, eight resident.

#### 4.2 — What fits

| | blocks | bytes |
|---|---|---|
| characters, this run's union + repair | 5 | 37,645 |
| characters, **W1** (graph-wide, P5.1) | **7** | 49,924 |
| tiles, one screen's page (worst) | 1 | 7,582 |
| tiles, level-wide shared pool (§3F B) | 3 | 23,068 |

| combination | blocks of 8 | verdict |
|---|---|---|
| W1 chars + one screen's tiles | 7 + 1 = **8** | **fits exactly — zero spare blocks** |
| run chars + one screen's tiles | 5 + 1 = 6 | fits, 2 blocks spare |
| run chars + level tile pool | 5 + 3 = 8 | fits exactly |
| **W1 chars + level tile pool** | 7 + 3 = **10** | **★ OVER by 2 blocks (16,384 B)** |

★ **The dispatch's "57,506 of 65,536, fitting with ~8,030 spare" is right in bytes and misleading in
the unit that binds.** 49,924 B of characters needs **7 blocks** (57,344 B of capacity) because a cel
cannot straddle a block boundary; 7,582 B of tiles needs the eighth. The spare is **8,030 bytes
scattered inside eight full blocks, not a ninth block** — so the level-wide tile pool, which would be
the natural next want, does not fit. **Per-screen tile loading on room change is not a preference here.
It is forced.**

#### 4.3 — The proposal

**The window division, per frame during play:**

| register | holds | changes |
|---|---|---|
| `$FFA4`,`$FFA5` | the back framebuffer, 15,360 B | on every page flip (already) |
| `$FFA6`,`$FFA7` | **two of the five character blocks** | 1.58×/s measured, 7 cy each |

**On room change only:** `$FFA6` is pointed at the screen's tile page for the duration of the
composite, then returned to characters. The composite already happens under a black screen, and no
character is drawn during it.

**Physical residency, 8 blocks:**

- **7 blocks — every character cel W1 can reach.** Never loaded during play.
- **1 block — the current screen's tile page**, replaced by a disk read on room change.

**What rotates, and at what cost:**

| what | how often | what it costs |
|---|---|---|
| character block visible in the window | 1.58/s | **7 cycles** — an MMU register write |
| tile page contents | per room change | **one track read**, under the black screen that already exists |

**★ AND THIS IS THE ANSWER TO THE ARCHITECTURAL QUESTION.** The expensive rotation (disk) falls on
the rare event; the cheap rotation (a register) falls on the frequent one. Nothing is copied per
frame in either direction.

**WHAT I AM NOT PROPOSING** (the list that has kept the last two gates bounded):

1. Not proposing to **build** any of this. No code, no bake change, no renderer change.
2. Not proposing **block recruitment as a decision** — §4.1 costs it; adopting it is Jay's.
3. Not proposing a solution to the **animated-block problem**. It is real and it is next, and this
   proposal does not address it.
4. Not proposing the **level-wide shared tile pool** — §4.2 shows it does not fit beside W1, so it is
   measured and set aside, not designed.
5. Not proposing to **re-measure W1**. P5.1's 49,924 B is used as given; if it is wrong, §4.2 moves.
6. Not proposing any change to the **peel**, the **cel format**, or the two-format ruling.
7. Not proposing anything about a **second resident screen**, the **foreground plane**, `AUTOCTRL`,
   sound, or anything past `LEVEL0`.
8. Not proposing the **five duplicated cels** as a mechanism — they are a measured cost (1,503 B),
   and how a bake would emit them is a build question this dispatch excludes.

#### 4.4 — AC7: does Jay's framing survive?

> *"it might be worth considering have player cells in memory all the time. if they are large enough.
> then only swap scene data."*

**Yes — and the conditional in the middle of it is the part that needed measuring, so it was the
right thing to ask.**

- *"player cells in memory all the time"* — **holds.** 49,924 B in 7 of 8 free blocks. Never a disk
  read for a character during play.
- *"if they are large enough"* — **this is the clause that binds, and it binds on BLOCKS, not bytes.**
  They are large enough, with exactly one block to spare for everything else.
- *"then only swap scene data"* — **holds, and is forced rather than chosen** (§4.2).

**Where the framing needs one correction, and it is in the port's favour:** "have them in memory" and
"have them in the window" are different, and only the first is achievable — 49,924 B cannot be
mapped through a 15,872 B window. What the proposal buys is that the per-frame rotation stops being
a **copy** and becomes a **register write**: 7 cycles, 1.58 times a second, against a 1.79 M cy/s
budget. **The framing survives; the mechanism is cheaper than the word "swap" suggests.**

---

### 5 — Verification (AC-by-AC)

- **AC1** — §3A. Two residencies, each with its set, interval and extent stated; distributions given;
  worst window frame named by content (**9328, the sword fight, 1,828 B**).
- **AC2** — §3B. **W0 does not survive as a window requirement; it survives only as a bound W1
  implies. W1 survives as a RAM requirement, not a window requirement.**
- **AC3** — §3C/§3D. Strategy tested: connected components (a proof, not a search) → **NO** for one
  block; temporal partition → **YES** for two blocks, with the five failing frames named and a
  1,503 B repair.
- **AC4** — §3E. **7 cy** (constant) / **10 cy** (table), decoded from emitted bytes for this pattern;
  48 cy reproduced for `cel_bank_map` to show why it does not transfer. Cadence **1.58/s = 0.0009%**.
- **AC5** — §3F. **54,443 B** as independent pages; **23,068 B** deduped level-wide.
- **AC6** — §4.3, including eight explicit non-proposals.
- **AC7** — §4.4. Jay's framing survives, with one correction (resident ≠ mapped).
- **AC8** — §0. `git status --porcelain src/` → 0 lines.
- **AC9** — §0. Prod sha1 triple identical at both ends.
- **AC10** — **suites NOT run, and saying so rather than omitting it.** Nothing was built: no source,
  link script, bake input or disk image changed, so `build.bat` was not invoked and the suites would
  have re-tested the identical artifacts P5.5 already gated. The prod sha1 triple in §0 is the
  evidence that nothing moved.
- **AC11** — §6.

---

### 6 — Reactive deviations and route accounting

**Deviations:**

1. **I tested a premise the dispatch supplied rather than accepting it** (§3D). §3 frames the question
   as one 8 KB block; §7 instructs me to check anything of the Orchestrator's that I rely on. Under
   the corrected premise the answer inverts, so the check was load-bearing rather than pedantic.
2. **I assembled a measurement snippet** (`p56_switch.s`) to satisfy AC4's "for **this** access
   pattern rather than carried from either existing routine." It is in the **scratchpad, not the
   repo**, is not linked, is not built by `build.bat`, and `git status --porcelain src/` is 0. I read
   this as inside the stop (which forbids engine, bake and renderer changes) and am flagging it so
   the reading is Jay's to reject.
3. **I corrected two of the dispatch's figures** (§4.1, §4.2) rather than carrying them, as §7
   instructs.

**ROUTE ACCOUNTING.** No route was proposed in conversation before this task. Within it, one plan
changed and is recorded rather than quietly replaced: the contiguity question was first answered by
connected components, which returned a clean impossibility (§3C) — and I did **not** stop there,
because the impossibility is of a *partition*, and the dispatch asked whether an assignment *can
exist*. §3D re-asks it against the correct window. **Both answers are in the report; the first is not
deleted, because it is the proof that duplication or a second register is unavoidable.**

**This report contains:** AC1-AC11 in full, one new analysis tool, no engine change.
**It does not contain:** any build, any code, any adoption. §4.3's eight non-proposals list what was
deliberately left alone.

---

### 7 — Uncertainty flags

1. **★ The character figures are the DEMO's path, not the move graph's.** 36,142 B is what this
   4.44 s run touched. The proposal's 7-block character budget rests on **P5.1's W1 (49,924 B)**,
   which I used as given and did not re-derive. If W1 is wrong, §4.2's "fits exactly, zero spare
   blocks" is the first thing to move — and it has no margin to absorb an error.
2. **§3D's premise is verified for the PORT's peel as written, not for a port that grows.** The claim
   is that `$FFA6` is free during play because the peel restores from the framebuffer
   [`char_draw.s:107-131`]. That is true of the current peel. A future need to re-read tile pixels
   mid-frame — the foreground plane is the obvious candidate — would re-take `$FFA6` and collapse the
   answer back to §3C's.
3. **The 5-block partition is first-use ordering, and it is not proven optimal.** It is proven
   *sufficient* (5 blocks is also the lower bound, `ceil(36,142/8,192)`), and the repair is 4.16%. A
   better ordering might reach zero duplication; I did not search for one.
4. **The 15 full-screen composites include 12 that also draw a character.** That is the ORACLE's
   behaviour and §3D argues it does not transfer to the port. **If it does transfer** — if a room
   change ever needs the tile page and a character in the same frame — the window still holds both
   (8,192 + 1,828 ≤ 15,872), but the two-block character assignment loses `$FFA6` for that frame.
   Not measured, because no port frame does this today.
5. **`chtable3` is labelled "kid/sword" and carries both.** The kind split in §3A follows
   `frame_drawset.py`'s table map; a per-cel kid-vs-sword split inside chtable3 was not made and would
   change the per-kind subtotals but not any total.
6. **AC5's figure B assumes an 8-bit global variant id** (104 unique variants level-wide). A level
   with more than 255 would need 16-bit ids and 761 extra bytes. `LEVEL0` does not.

---

### 8 — Follow-up candidates

1. **Re-derive W1 under the per-frame framing**, since §3B shows the interval that produced it is not
   the interval the window cares about — the RAM figure may also be smaller than 49,924 B.
2. **Search for a zero-duplication cel ordering** (flag 3). 1,503 B is small, but zero is simpler.
3. **The animated-block problem** — real, next, excluded here by §6.
4. **Decide the tile residency**: one block reloaded per room change (forced today) versus the
   level-wide pool (needs 2 more blocks than exist). The second becomes possible only if W1 shrinks.
5. **Cost the room-change disk read** against the black screen it hides behind, so "forced" can be
   confirmed as "acceptable".

---

### 9 — User interaction during task

None.

---

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-22-an-impossibility-proof-is-about-the-shape-you-assumed.md` — the §3C/§3D
reversal: a correct impossibility proof about a partition, attached to a question the machine was
not asking. Pushed to the pool as `4269a5c`.

---

### 11 — Commit

`7495a95` (pushed to origin/wip). **`main` is untouched at `32b5fe2`.**
