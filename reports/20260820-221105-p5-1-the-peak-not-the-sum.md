## Form B Report — P5.1 (RECON + infrastructure) — the peak, not the sum; the sword that was never counted; and `main` promoted

**Class:** recon (Phases 1-2) + infrastructure (Phase 3). `wip`, then promoted to `main`.
**Prod byte-identical** — no file under `src/`, `content/`, `link/` or `build.bat` was touched.

### 0 — Receipt / status (C-35 stamp)

t0 = **2026-08-21T01:33:40Z**, HEAD **`7dfb0b2`**, branch **`wip`**.

`git status` at receipt: one modified tracked file, `dist/mame-cfg/rgb/coco3.cfg`, plus the
**standing untracked set**, stated explicitly: `.vscode/`, `nvram/`,
`POP-idioms-coco3-markers.md`, `content/intro/broderbund_splash_render.bin`,
`docs/project/pop-coco3-design-v0_7.pdf`, and the nineteen files under `docs/ground-truth/`
(local-reference-only by standing Jay ruling — never committed). **None was touched by this
task.**

Prod sha1, **at receipt and again at the end, identical**:

```
d07f1f3295525783968dcce6409ee1b64942231c  build/intro_seq.bin
0b4968867bf5274d2942f3b5b90ea855ad6f2def  build/loader.bin
790836577e56b61b8f849cb309874e44304840a2  build/cutscene_room.bin
```

### 1 — Summary

P5.0's three figures were sums. All three are now measured as peaks, and the arithmetic moves a
long way. **The controller does not dispatch on the sequence — it dispatches on `CharPosn`, and
only 36 of 240 frame slots reach a controller at all** [`CTRL.S:686-733`]. From the other 204 the
sequence runs to completion, and the intra-table closure over **all 154 graph nodes** is at most
**8,219 B**. `standing` is the hub: 30 targets, 33,194 B, against 1-to-5 targets and 1,445-11,759 B
for every other routine. **Addendum A.3's omission is real and small**: `SWORDTAB` was skipped by
the census parser, `decodeswim` sends every sword image to `IMG.CHTAB3`, the overlap with
character-named cels is **zero**, and the correction is **+926 B for the kid, +692 B for the
guard, +618 B at the binding window** — it changes no verdict, which §5 says to state plainly.
Three further image sources were found by the same check (strength meters, impact star, text
glyphs). **The demo's path was measured rather than assumed** — screens 1 → 2 → 4 — and
`bg_compose.py` now holds on all three with **zero unexplained background bytes**. Combined
peak-at-any-instant: **26,533 B mid-move, 64,071 B at one control decision**, against P5.0's
81,690. **The shortfall against the recruitable 65,536 B bank dissolves at W1 with 2.2% to
spare; against the bank as it stands it does not; and the binding constraint has moved from
capacity to addressability.** Phase 3: `.gitattributes` clean, `project-state.md` brought current
after 25 days, and **`main` promoted to `05d3e4f` with 43/43 artifacts byte-identical from a
clean clone**.

### 2 — Files modified

Explicit-path staging only. Nothing under `src/`, `content/`, `link/` or `build.bat`.

- `demo-move-graph.md` — **new**, the AC1/AC2 artifact: the graph, the control dispatch, the
  peaks per window and per mode, the guard correction, the sword correction, the tile
  co-residency answer, the three-screen validation, and the per-sequence table.
- `project-state.md` — **AC7**, brought current (see §3F).
- `harness/tools/seq_graph.py` — **new.** Parses `SEQTABLE.S`, walks it with `ANIMCHAR`'s
  semantics, builds the label graph, attributes cels, runs the union check.
- `harness/tools/ctrl_edges.py` — **new.** The `CharPosn` dispatch, per-routine target sets via a
  region map and intra-file call graph, and the resolution of every unresolved call site.
- `harness/tools/peak_residency.py` — **new.** Composes the two into the peaks, per window and
  per armed/unarmed mode, with the guard's `usealtsets` mapping and the co-resident union.
- `harness/tools/tile_working_set.py` — **new.** Per-screen and per-level tile working set, with
  the state-dependent and directly-drawn image sets enumerated by name.
- `harness/tools/demo_frame_census.py` — **modified.** Stops skipping `SWORDTAB`; adds
  `decodeswim` and `sword_cel`.
- `harness/tools/oracle_demo_bg.lua` — **modified.** `P_AFTER` takes a comma list, so one boot
  samples several instants.

### 3 — Reasoning

#### 3A — ★★★ The controller dispatches on the FRAME, and 204 of 240 frames reach nothing

**Authority: source, and exact — there is no guard to model at this level.**

`SEQTABLE.S` is 114 `dw` entries plus byte streams. Operand counts come from **`ANIMCHAR`
[`COLL.S:994`]**, read off its dispatch chain rather than from the equate list: `chx/chy/act/tap/
effect` 1, `setfall` 2, `goto`/`ifwtless` a 2-byte address, the rest 0, and **`die` is a no-op**.
ANIMCHAR returns on the first frame byte, so **a `goto` costs no animation frame**. Streams jump
into each other's middles, so the graph is over **labels**: 154 nodes. **Structural check: every
one of the 154 bodies terminates in a `goto`; none runs off the end** — fall-through between
sequences is not an edge class, which was open before the walk.

Then `GENCTRL` [`CTRL.S:686-733`], after the `CharAction`/`CharSword`/`CharID` guards:

```
15 -> standing   48 -> turning   50,51,52 -> standing   1,2,3 -> starting
67,68,69 -> stjumpup   4..14 -> arunning   87..99 -> hanging   109 -> crouching
EVERYTHING ELSE -> rts, no transition at all
```

**36 of 240.** And the routines are small except one — `standing`, 30 targets, 33,194 B, entered
from four frames; `arunning` 11,759; `crouching` 10,176; `FightCtrl` 9,028; the rest 1,445-4,572.
**Standing itself is one cel, 164 bytes.**

**AC1's completeness.** Six `jumpseq` sites had no `lda #<seqname>` in reach; all six resolve.
`CTRLSUBS.S:36,81` are the module's own **jump table**, not call sites (filtered on case — real
callers use the lowercase equate). `CTRL.S:1859` is computed, `adc #stepfwd1-1` with A =
`getfwddist` 0-13 → **sequences 29-42**, enumerated. `SUBS.S:1023,1032` are the
`pjumpseq`/`kjumpseq`/`mjumpseq`/`vjumpseq` **trampolines**, which pass A through; their callers
are scanned like any region. `AUTO.S:1058` is `chgshadposn`, whose A is the 8th byte of a
`shadpos*` record whose bytes are named sequences. **No genuinely unenumerable site remains.**
What is **not** modelled is the guard *inside* each routine, so W1/W2 are upper bounds within a
routine and exact between routines. Stated in the artifact and in the tool header.

#### 3B — AC3, AC4: the union check, then the peaks

The union check is what makes the peaks trustworthy: **`Fdef` total = 211 cels / 50,890 B,
reproducing P5.0 exactly. PASS.** Four `Fdef` frames are named by no stream — **161, 175, 176,
206** — and each is explained: 161 is written **directly** by `AUTO.S:968` (`lda #161 / sta
OpPosn`), 175/176 are commented out of `stabbed` (`SEQTABLE.S:247  ; db 175`), 206 is `;unused`.
*A frame number can be poked straight into `CharPosn`, so the sequence table is not the only
writer* — which is itself the first instance of the class Addendum A.3 is about.

| window | max | median | min | worst-case node |
|---|---|---|---|---|
| **W0 mid-move** — the controller cannot intervene. **EXACT** | **8,219 B** | 1,294 | 114 | `jumphangMed` |
| **W1 one decision** | **40,141 B** (185 cels) | 19,516 | 12,232 | `runstop` |
| W2 two decisions | 51,333 B | 50,731 | | `turn` |
| W∞ fixpoint | 51,630 B | | | |

**W2 is already the fixpoint for practical purposes, and W∞ is where P5.0's number actually
sits.** *P5.0's figure was correctly computed and wrongly labelled.* Start nodes are the kid's
own states (the closure of sequences 1-93); including the cutscene sequences as targets moves W1
by 3,727 B and the tool prints it both ways.

#### 3C — ★ AC3b: the sword, and the honest size of the correction

**Jay: the demo contains a sword fight.** That makes the omission load-bearing.

`decodeim` [`CTRLSUBS.S:1017`] is the **character** decoder — it uses only `Fsword`'s top two
bits. The low six are a `SWORDTAB` index and `SETUPSWORD` [`CTRLSUBS.S:1590`] follows them
through **`decodeswim` [`CTRLSUBS.S:1050`], three instructions, every sword image to table 2 =
`IMG.CHTAB3`.** `demo_frame_census.py` skipped `SWORDTAB` by construction; it no longer does.
`SWORDTAB` is **64 slots, 50 defined, 34 distinct images**; entries 43 and 44 carry image 0 (the
kid stabbed — no sword drawn).

| | kid | opponent |
|---|---|---|
| chtable3 from **character** frames | 35 cels, 7,768 B | 0 |
| chtable3 from **sword** frames | 23 cels, 926 B | 17 cels, 692 B |
| **overlap — already counted** | **0** | **0** |
| **new — never counted** | **23 cels, 926 B** | **17 cels, 692 B** |
| **chtable3 true total** | **58 cels, 8,694 B** | 17 cels, 692 B |

**Restated:** kid `Fdef` total 50,890 → **51,816**; guard `ALTSET1` 9,350 → **10,042**; P5.0's
**60,240 → 61,582**; P5.0's **81,690 → 83,032** on its own tile basis, or **75,645** on P5.1's
level-correct tiles; the overflow vs 65,536 → **17,496** on P5.0's basis, **10,109** on P5.1's.

★★ **And now the negative half, which §5 requires be said as plainly as the positive.** The
sword adds **618 B at the binding W1 window** — 23 cels averaging 40 bytes, because a sword is a
thin sprite. **It was a real omission, it is now counted, and it changes no verdict.** Likewise
the guard's `usealtsets` correction (§3D) **does not move the union at all**: the extra guard
cels are `Fdef` cels the kid already holds.

**AC4b — the two modes cannot coexist.** `GENCTRL` routes to `FightCtrl` only at `CharSword == 2`
[`CTRL.S:678`] and `SETUPSWORD` draws nothing at `CharSword == 0`:

| | W1 max | W2 max |
|---|---|---|
| unarmed | **39,523 B** (171 cels) | 47,681 B |
| armed | **40,141 B** (185 cels) | 51,333 B |
| difference | **618 B** | 3,652 B |

The larger is the requirement; the union is needed only if the draw/sheathe transition cannot be
a paging point — and it is a natural one.

**A.2, corrected per your follow-up.** `demo ds 3` [`GAMEEQ.S:305`] is a **three-byte `JMP` slot
in the `dum subs` table**, not a move stream. It resolves to `SUBS.S:18 jmp DEMO` → `SUBS.S:1233`,
which is `lda #<DemoProg1 / ldx #>DemoProg1 / jmp AutoPlayback`. So the unarmed half is a
**recorded input program replayed through `AutoPlayback`** and the armed half is `AutoCtrl`.
*(One detail differs from the addendum: the routine is not unread — it is in the vendored
`SUBS.S`. `DemoProg1`'s format is not decoded and is arc scope, along with `AutoCtrl`'s combat
logic. No work on either here.)*

#### 3D — The guard, recomputed

`usealtsets` [`CTRLSUBS.S:1685-1707`]: `CharID 0 → main set`; frames 102-106 → +70 → 172-176;
frames 150-189 → `ALTSET1` at index `frame-149`; **everything else still comes from `Fdef`.**
P5.0 counted only `IMG.CHTAB4.GD` and so missed every frame the guard shares with the kid —
bumping, falling, being stabbed, dropping dead. **31 cels / 9,350 B → 101 cels / 21,295 B**, with
a per-start W0 max of **3,985 B**. And `SETUPSWORD`'s first test is *"live guard's sword is
always visible"*, so the guard is armed unconditionally.

#### 3E — AC5: the tiles are co-resident, and P5.0 had that wrong

**Question: must tile data be readable while characters are drawn? Answer: yes.** P5.0 §3F wrote
that a screen *"is composited once and redrawn on room change, making the tiles a load-time
requirement, not a per-frame one."* The frame path says otherwise:

```
MainLoop -> FrameAdv [TOPCTRL.S:606] -> DoFast [TOPCTRL.S:961] -> `jsr fast` [FRAMEADV.S:189]
              30 blocks, RedBlockFast, redbuf/movebuf/floorbuf/wipebuf marked
                 -> RedBlockSure -> fastlay on bgtable1/2      -> PageFlip
```

`FAST` runs **every frame** and redraws the blocks `MARKRED`/`MARKMOVE`/`MARKFLOOR` set from the
characters' own footprints. *This does not contradict P3.88's "the oracle peels":* `DRAWMID`
saves each character's underlayer and `SNGPEEL` restores it, **and** the block redraw handles
what the peel cannot — moving scenery and the meters. **The peel is per-sprite; the block redraw
is per-block; the tile tables serve the second.**

**A room change costs one frame and no disk read.** `PrepCut` [`TOPCTRL.S:1039`] sets `cutplan`;
`FrameAdv` takes `DoCleanCut` [`TOPCTRL.S:891`] — draw bg on page 2, `copyscrn` to page 1,
`DoFast` for characters, flip — inside one `jsr FrameAdv`, under a **black text screen**.
*The port's own `HAL_gfx_mirror` (P3.17) is the same move, arrived at independently.*

**But the level needs a fraction of the tile FILES.** `21,450 B` is `BGTAB1.DUN + BGTAB2.DUN` —
all fifteen dungeon levels. `LEVEL0`: worst single screen **4,742 B**, whole level **7,202 B**
blueprint-determined, **14,063 B** with every state-dependent image its pieces unlock (gate bars,
9 torch flames, slicer, loose floor, spikes, exit, climb-up masks — enumerated by name),
**14,147 B** once the strength meters are added.

**AC5b — the demo changes rooms mid-play, measured not assumed.** `MAP` gives screen 1
`[left 2, right 0, up 0, down 7]`, so **screen 1's left neighbour is screen 2** and Jay's "second
screen" is blueprint screen 2. Sampling one boot at seven instants and identifying each dump by
scanning all 24 screens: **+300 → screen 1 (96.54%), +450 → screen 2 (96.82%), +750/+900 →
screen 2, +1200 → screen 4 (95.66%).** Path 1 → 2 → … → 4. `bg_compose.py` is now validated on
**three** screens (P5.0 §7 flag 4, closed):

| | screen 1 | screen 2 | screen 4 |
|---|---|---|---|
| gate bars | 45 | 21 | — |
| torch flames | 38 | 23 | 28 |
| loose floors | — | 144 | 124 |
| strength meters | 20 | 20 | 40 |
| characters (residual) | 163 | 36 | 141 |
| **UNEXPLAINED background bytes** | **0** | **0** | **0** |

★ **The limitation, stated:** the character bucket is a *residual* — without the actors'
positions I cannot prove those bytes are characters rather than compositor error. What supports
it is screen 1, where the kid was at the bottom and **rows 24-159 were byte-identical**.

★ **A MAME gotcha worth carrying, and it cost two runs.** POP toggles `setaux`/`setmain`
constantly and `mem:read_u8` reads through whichever bank is switched in. At +300 the read landed
in MAIN — HGR pages valid, `level`/`SCRNUM` garbage (255/24); at +600 it landed in AUX —
`level`/`SCRNUM` correct (0/2) and the HGR dump was `topctrl`'s **code**. **The two are
anti-correlated.** Identify the screen by matching it, never by reading `SCRNUM`.

**AC5c — what else names images.** `SWORDTAB` was skipped in a parser reading four labels, so the
same class was checked elsewhere. **Three more sites, all `GAMEBG.S`, none indexed by a blueprint
or a piece id:** the **strength meters** (`bullet $88 / bline 89,8a,8b / blank $8c`
[`GAMEBG.S:99-101`] → bgtable2 8-12, **84 B**, drawn every frame inside `FAST`); the **impact
star** (`starimage = $41 / startable = 0` [`GAMEBG.S:136-137`] → chtable1 #65, **182 B**); the
**text glyphs** (`prchar` `sbc #"/"` with `pretext` setting `TABLE = bgtable2`
[`GAMEBG.S:1134,1175`] → 1,560 B digits + 3,368 B letters). ★ **The glyphs cost the DEMO
nothing** — `RESTART` suppresses the banner at level 0 (`lda level / beq :nomsg`) and
`timerequest` is never set; a real level takes the tile figure to **17,300 B**. **Everything else
is clear:** `FRAMEDEF.S` has exactly four labelled tables and all four are now walked; every
`BGDATA.S` table is walked; the remaining `GAMEBG.S` lists (`ptorchflame`, `stari`, `glassimg`,
`flowimg`, `postimg`, `pmaski`) are `chtable6`, i.e. the princess room. **No other gameplay
image-naming table is unwalked.**

#### 3F — ★★★ The combined answer, and what it settles

| window | chars (kid ∪ guard ∪ star) | tiles | **total** | vs 32,768 | vs recruited 65,536 | vs the 15,872 visible at once |
|---|---|---|---|---|---|---|
| **W0** mid-move | 12,386 | 14,147 | **26,533** | **FITS** (6,235 spare) | **FITS** | over by 10,661 |
| **W1** one decision | 49,924 | 14,147 | **64,071** | over by 31,303 | **FITS** (1,465 spare) | over by 48,199 |
| W2 | 61,080 | 14,147 | 75,227 | over by 42,459 | over by 9,691 | over by 59,355 |
| *P5.0* | *60,240* | *21,450* | *81,690* | *over by 48,922* | *over by 16,154* | — |

**THE SHORTFALL AGAINST THE RECRUITABLE BANK DISSOLVES AT W1 — BY 1,465 BYTES, WHICH IS 2.2% AND
IS NOT COMFORTABLE.** Against the bank as it stands it does not dissolve above W0.

**AND THE BINDING CONSTRAINT HAS MOVED FROM CAPACITY TO ADDRESSABILITY.** At most **15,872 B**
is CPU-visible at once — `$FFA4/$FFA5` must carry the back buffer, leaving `$C000-$DFFF` (8,192)
and `$E000-$FDFF` (7,680) [`demo-memory-map.md §4`]. **Every window, W0 included, exceeds it**,
and no amount of recruited RAM changes that.

**This is a measurement. It authorises nothing.** The four options P5.0 named stay unbuilt and
unranked (§4 of the dispatch); the choice is Jay's. **Stopping here, per the Phase 2/3 hard stop.**

#### 3G — Phase 3a: `.gitattributes`, and it is clean

**Contents** (read with `od -c`; CRLF in the working tree, which the file's own `*` rule
produces): a `* text=auto` default; `*.bat`/`*.cmd` `text eol=crlf`; `*.sh`/`*.lua`/`*.s`
`text eol=lf`; and **`*.bin *.dsk *.dmk *.hdv *.png *.pdf` `binary`.**

**Both halves are present, and were added in one commit:**
`fe333ff`, **2026-07-25 19:03:18 -0400**, *"P1.1: stand up the build -> test -> verify loop"* —
the only commit that has ever touched the file. **P3.108 is `862778c`/`34e93e0`, 2026-08-16 —
three weeks later.** `git merge-base --is-ancestor fe333ff main` confirms it was in the tree, and
`git show main:.gitattributes | md5sum` equals `git show HEAD:.gitattributes | md5sum`. **So the
`binary` clause was present at P3.108. No stop condition.**

`git check-attr -a`: `gfx.s` → `text: set, eol: lf`; `build.bat` → `text: set, eol: crlf`;
`CLAUDE.md` → `text: auto`; `sprite_convert.py` → `text: auto`.

**P3.108's comparison mode was BYTE mode.** Its §3A: *"SHA-1 every artifact `build.bat` produces
plus `probe.dmk` and `build/assets/*`; move `build/` aside entirely; rebuild; SHA again; join on
filename"* → `artifacts in BOTH builds: 36 / with differing sha1: 0`. Not `diff`, not `cat`.

★ **Residual gap, reported and deliberately NOT fixed.** `*.md`, `*.txt` and `*.py` are covered
only by `* text=auto` — normalised in the repo, **native in the working tree** — rather than
pinned `eol=lf`; git said so out loud during this task's own commit (*"LF will be replaced by
CRLF the next time Git touches it"* for two `.py` files). And `content/cutscene/princess_room.lz`
and `.raw` — production content — are not in the `binary` list, relying on git's NUL-byte
heuristic. **Changing line-ending policy immediately before a byte-identity promotion is the
wrong ordering**, so it is filed in `project-state.md §6` instead.

#### 3H — Phase 3b: `project-state.md`

It said *"Engine: nothing built yet"* through the whole P3 intro/cutscene arc and the whole P4
sound arc — **25 days and ~130 reports stale**, in the file the standing rules say to read first.
Brought current by **surgical edit, not rewrite**, so nothing was lost: a new §2.1 listing the ten
units that actually run (loader, kernel, intro sequencer, LZ unpacker, cutscene, blitter,
character driver, cel bank, MSYS player, sound effects) with their gate status; the retired-suite
rule recorded; §1's `PA.7/PA.9` row marked **SUPERSEDED at P3.54** (compiled sprites were true on
cycles and fatal on RAM — 8.2× packed bitmaps) and `PA.12` marked **CLOSED**; the §2 sprite-compiler
rows marked retired; the cost-model section banner-marked HISTORICAL; §5 rewritten as *what
closed and how* plus the open demo arc; §6 rewritten with the live open questions.

#### 3I — Phase 3c: the promotion, and one thing it does not prove

`main` was at **`34e93e0`**, not `635f986` as the dispatch states — `635f986` is *"P1.0: repo
bootstrap"*, the repository's first commit. `wip` was **117 commits ahead**, `main` zero ahead, so
the promotion was a **fast-forward**: `34e93e0..05d3e4f`, 148 files changed, pushed.

Verification: clean `git clone --branch main` into a scratch directory, full `build.bat` from an
empty `build/`, then **md5 every artifact and join on filename**:

```
artifacts in BOTH builds: 43
with differing md5:       0
only in the clean clone:  0
only in the working tree's build/: 153   (stale outputs accumulated across earlier dispatches)
```

★ **AND THE CHECK IS CONTAMINATED, WHICH I WILL NOT PRETEND OTHERWISE.** Three tools `build.bat`
invokes hardcode the repository root — `cel_link.py:26`, `cel_table.py:31`,
`chartable_audit.py:35`, all `ROOT = pathlib.Path("C:/Projects/POP3_port")`; the last also reads
`FRAMEDEF.S` and `Images/` through it. **A clone at any other path reaches back into the original
working tree through those three.** So 43/43 proves the *tracked tree* reproduces the artifacts;
it does **not** prove the clone is self-sufficient. P3.108's 36/36 was made under the same
contamination. Filed as a follow-up rather than fixed inside a promotion.

### 4 — Verification (AC-by-AC)

- **AC1 sequence graph + tool, control edges enumerated, unenumerable ones named** —
  `demo-move-graph.md` §1-§2 + `seq_graph.py`/`ctrl_edges.py`. 154 nodes; all six unresolved
  `jumpseq` sites resolved (§3A); **none left unenumerable**; the unmodelled part (guards *within*
  a routine) named as such.
- **AC2 per-sequence cel count and bytes** — `demo-move-graph.md` §9, 114 rows, generated.
- **AC3 union check** — **PASS**, 211 cels / 50,890 B, reproducing P5.0 exactly. The four
  stream-unnamed frames explained individually.
- **AC3b sword-corrected `IMG.CHTAB3`** — **35 → 58 cels, 7,768 → 8,694 B**; overlap **0**, new
  **23**; guard +17 / +692 B. §3C.
- **AC4 depth-1/2 peaks, worst case, distribution, window stated** — §3B, and every figure in the
  artifact carries its window.
- **AC4b per-mode peaks** — unarmed W1 39,523 / W2 47,681; armed W1 40,141 / W2 51,333. §3C.
- **AC5 tile co-residency + combined peak** — co-resident (**not** disjoint), with the frame path
  cited; combined 26,533 B (W0) / 64,071 B (W1). §3E, §3F.
- **AC5b screen 1's left neighbour named, rendered, matched** — screen **2**, 96.82%, zero
  unexplained; plus screen 4 at 95.66%. §3E.
- **AC5c no other image-naming table unwalked** — three found and quantified; the rest cleared
  by name. §3E.
- **AC6 `.gitattributes`** — both clauses, adding commit `fe333ff` 2026-07-25 vs P3.108
  2026-08-16, P3.108's mode = SHA-1 byte compare. §3G.
- **AC7 `project-state.md` current and true** — §3H.
- **AC8 promotion** — `main` = **`05d3e4f`**, 43/43 byte-identical from a clean clone, with the
  contamination caveat. §3I.
- **AC9 suites green, 128 KB first** — §5. 512 KB not run: nothing here touches the MMU, the
  bank, the framebuffers or the loader.
- **AC10 route accounting** — §6.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim):**

```
$ cmd /c C:\Projects\POP3_port\build.bat
  PROBE.BIN            1256      1256  ok
  MODE.BIN             1319      1319  ok
  ANIM.BIN             1438      1438  ok
  INTRO.BIN           28132     28132  ok
  LOADER.BIN           1593      1593  ok
# VERDICT: PASS - every file on the image matches its artefact.
=== BUILD COMPLETE ===

$ bash harness/smoke/run_suites.sh
[suites] running: introseq integ
[suites] retired at P3.103 (see harness/smoke/retired.sh): probe cel compiled mode anim room walk
[suites] -ramsize 128K
[suites] === introseq ===   [run_introseq_test] PASS
[suites] === integ ===      [integ] PASS
[suites] ALL PASS

$ python harness/tools/peak_residency.py
  window                                 max B  median B     min B worst-case node
  W0  mid-move (EXACT)                    8219      1294       114 jumphangMed (36 cels)
  W1  + one control decision             40141     19516     12232 runstop (185 cels)
  W2  + two control decisions            51333     50731     50731 turn (228 cels)
  Winf fixpoint (= the whole moveset)    51630     51333     51333 impale:dead (229 cels)
  standing   30 targets -> 144 cels  33194 B   entered from frames [15, 50, 51, 52]
  unarmed  W1                    39523     18898   worst runstop (171 cels)
  armed    W1                    40141     19516   worst runstop (185 cels)
CO-RESIDENT PEAK — kid UNION guard, both at the same window
  W0    union  12204 B   W1    union  49742 B   W2    union  60898 B

$ python harness/tools/bg_compose.py --screen 2 --compare build/od_450_hgr2.bin
  vs build/od_450_hgr2.bin: 7436/7680 visible bytes match (96.82%), 244 differ

$ (clean clone of main, full build from an empty build/)
artifacts in BOTH builds: 43
with differing md5:       0
```

**25.2 bundled-artifact grep:** N/A — no bundled artifact and no sibling import; nothing under
`src/` or `content/` changed.

**25.3 operator-runtime-smoke:** **pending Jay.** Three PNGs are surfaced (§9) and are
**offline 1:1 renders of framebuffers the port has not produced on the machine** — weaker than
`static-png` and **not** a passed visual gate. P5.0's AC9 gate on the static background remains
open and this dispatch does not advance it.

### 6 — Reactive deviations and route accounting

**Deviations:**

1. **`main` was at `34e93e0`, not `635f986`.** The dispatch's figure is the repository's first
   commit. Proceeded on the actual state and reported it.
2. **Phase 3a's residual gap was reported, not fixed** (§3G) — changing line-ending policy
   immediately before a byte-identity promotion is the wrong ordering.
3. **The Phase 3c check is contaminated** by three hardcoded roots (§3I). Reported rather than
   fixed, and rather than claimed clean.
4. **The addendum's A.2 wording was corrected twice** — once by you mid-turn (`demo` is a
   trampoline slot, not a move stream) and once by me on a detail (the routine *is* in the
   vendored `SUBS.S:1233`; `DemoProg1`'s format is what is unread).

**ROUTE ACCOUNTING.** No route was proposed in conversation before this task. Within the task, two
plans were formed and changed, and both are recorded rather than quietly replaced: the oracle
capture was first attempted via the `demo_arrive` **save state**, which restores and then makes
MAME exit before the autoboot script loads (exit 0, no log, no error) — the full boot is used
instead, and the failure is recorded in `oracle_demo_bg.lua`'s header; and the first attempt at
screen 2 sampled at +1500 frames, which overshot into the restarted attract loop, so the tool
grew a comma-list `P_AFTER` and the screen is now identified by **matching** rather than by
reading `SCRNUM` (§3E).

**What this commit contains:** AC1-AC10 in full, including every addendum item.
**What it does not contain:** no cel-bank decision, no tile renderer, no engine code, no ranking
of the four options — all out of scope by §4, and the Phase 2/3 hard stop was observed.

### 7 — Uncertainty flags

1. **The guards inside each control routine are not modelled.** W1/W2 are upper bounds within a
   routine, exact between routines. Modelling them means modelling 2,168 lines of `CTRL.S` against
   joystick and world state, and would be a guess wearing a number.
2. **The character residual in the screen-diff table is unseparated** (§3E). I cannot prove those
   bytes are characters rather than compositor error without the actors' positions.
3. **`bg_compose.py` still omits the state-dependent pieces** — gate bars, torch flames, slicer
   blade, loose-floor motion, exit door, flask. Enumerated at run time, not silently skipped, but
   omitted.
4. **The clean-clone check is contaminated** (§3I) — three `build.bat` tools hardcode
   `C:/Projects/POP3_port`.
5. **`.gitattributes` residual gap** (§3G): `.md`/`.txt`/`.py` normalised but not pinned;
   `content/cutscene/*.lz`/`.raw` not declared binary.
6. **The MAME bank-dependent read** (§3E) means any future read of a POP game variable from Lua
   must resolve the bank first.
7. **The oracle `auxram` share is still unavailable**, so the blueprint and tile tables could not
   be read out of the running machine; the vendored files stand in, and the 95-97% matches are
   what makes that safe.
8. **Carried, untouched:** the `chtable7`/`chtable2` extent contradiction; the 4-colour palette's
   two homes; the `s_Princess` fuzziness; the stale `pop.link` stack comment; the HAL audit items.

### 8 — Follow-up candidates

1. **The cel-bank architecture decision** — Jay's, and now framed by a measurement: a swap that
   completes inside **W0 (12,386 B of characters)** is affordable and the port knows *exactly*
   when it is safe (the 204 frame slots that reach no controller); one that must survive a control
   decision (**49,924 B**) is not; **`standing` alone is 33,194 B**, so "pin the hub, page the
   rest" is a shape the measurement supports.
2. **Addressability, not capacity, is now the constraint** — a third window at `$FFA3` is the
   only lever that touches it. Naming it is not proposing it.
3. **De-hardcode `cel_link.py` / `cel_table.py` / `chartable_audit.py`**, so the clean-clone
   check means what it says.
4. **`.gitattributes`**: pin `.md`/`.txt`/`.py`, declare `.lz`/`.raw` binary — *after* a
   promotion, never before one.
5. **`AutoCtrl`'s combat logic and `AutoPlayback`/`DemoProg1`'s format** — arc scope, surfaced by
   Jay's observation that both halves of `DemoCtrl` run.
6. **The foreground plane** (P5.0 §3B) — still the next build dispatch's business.
7. **Implement the omitted movable pieces in `bg_compose.py`**, which would shrink the residual
   bucket in §3E to characters alone.

### 9 — User interaction during task

Two mid-turn messages, both folded in rather than deferred:

1. **Addendum A** (Jay's ground truth: the demo contains a sword fight; `SWORDTAB` skipped;
   armed/unarmed split; the mid-play room change; AC3b/AC4b/AC5b/AC5c). Addressed in §3C and §3E.
2. **Addendum A correction**: `demo` is a three-byte trampoline slot in `GAMEEQ.S`'s `dum subs`
   block, not a move stream. Applied in §3C and in the artifact.

**PNGs surfaced for Jay, unread** (`CLAUDE.md §3` — surfaced before any interpretation; I have not
looked at their pixels):

- `build/demo_bg/port_composed_s2.png` — the composed **screen 2** in the port's 4-colour palette
- `build/demo_bg/oracle_frame_s2.png` — the oracle's own frame at +450 through the same conversion
- `build/demo_bg/port_composed_s4.png` — the composed screen 4

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-20-a-walk-inherits-the-blind-spot-of-the-decoder-it-was-modelled-on.md`
— committed and pushed to the pool (fire-and-forget). *A census inherits the blind spot of
whichever decoder it was modelled on: `decodeim` ignores six bits, `decodeswim` reads them, and
the walk followed only the first.*

### 11 — Commit

Phase 1-3 work: **`05d3e4f`** — pushed to `origin/wip`, then fast-forwarded to `origin/main`
(`34e93e0..05d3e4f`), which is the AC8 promotion the 43/43 clean-clone check verifies.
Addendum work + this report: **`6535f12`**, and this hash stamp itself: **`68c04df`** — each
pushed to `origin/wip` and fast-forwarded to `origin/main` in turn. **`wip`, `main` and
`origin/main` are all at `68c04df`**, which is the state the AC8 sums were taken one promotion
earlier at (`05d3e4f`); nothing under `src/`, `content/`, `link/` or `build.bat` changed between
them, so the artifacts are unchanged and the prod sha1 in §0 still holds.
