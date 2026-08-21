# demo-move-graph.md — the kid's move graph, and the PEAK resident cel set

**Authorship:** Clyde-authored operational state, the same class as `project-state.md`,
`demo-memory-map.md` and the two `mame-idioms-*.md` files. **Not** an authored-authoritative doc
under `CLAUDE.md §2D`.

**Produced:** P5.1 (2026-08-20), against HEAD `7dfb0b2` on `wip`.
**Regenerate:** `python harness/tools/seq_graph.py --out <file>` (the table below),
`ctrl_edges.py` (which frames reach a controller), `peak_residency.py` (the peaks),
`tile_working_set.py` (the tiles).

---

## 0. ★★★ WHAT THIS CORRECTS

P5.0 reported **211 cels / 50,890 B** as the kid's residency requirement and argued it from an
assertion — *"he can enter any move at any moment and the oracle never pages `chtable1/2/3/5`"* —
without reading the move graph. It also reported **178 tiles / 21,450 B** for the dungeon and
**31 cels / 9,350 B** for the guard. All three are **sums**. None is a peak.

| | P5.0 | P5.1, measured | window |
|---|---|---|---|
| the kid | 50,890 B | **8,219 B** | mid-move, controller cannot intervene (**exact**) |
| | | **40,141 B** armed / 39,523 unarmed | one control decision (upper bound within a routine) |
| | | 51,630 B | fixpoint — which is where P5.0's figure actually sits |
| the guard | 9,350 B | **3,985 B** | mid-move |
| | | **21,295 B** | everything `GuardCtrl`/`FightCtrl`/collision can select — *and P5.0's 9,350 was an UNDERCOUNT, see §4* |
| the dungeon tiles | 21,450 B | **7,202 B** blueprint-determined / **14,147 B** with every state-dependent image and the meters | the whole demo LEVEL, all 24 screens |
| **all three, union** | **81,690 B** | **26,533 B** at W0 / **64,071 B** at W1 | |

★ **Every character figure here includes the SWORD cels** that P5.0's census skipped — see §4b.
The sword adds 618 B at the binding window, which is small and is stated rather than buried.

---

## 1. The graph, and what a node is

`SEQTABLE.S` (`org $3000`) holds **114 `dw <label>` entries** followed by byte streams. Positive
bytes (`$01-$F0`) are frame numbers; negative bytes (`$F1-$FF`) are opcodes. The operand counts
come from **`ANIMCHAR` [`COLL.S:994`]**, read off its dispatch chain rather than from the equate
list: `chx/chy/act/tap/effect` take 1, `setfall` takes 2, `goto`/`ifwtless` take a 2-byte
address, and `aboutface/up/down/die/jaru/jard/nextlevel` take none. **`die` is a no-op inside
`ANIMCHAR`.** ANIMCHAR returns on the first frame byte, so **a `goto` costs no animation frame**.

Streams jump into each other's middles — `running` is `act,1 / goto runcyc1`, and `runcyc1` sits
inside `startrun`'s body — so the graph is over **labels**, not sequence numbers: every seqtab
entry plus every `goto`/`ifwtless` target, **154 nodes**. A node's body runs from its label to the
first *unconditional* `goto`, falling through any intervening labels.

**Structural check:** every one of the 154 bodies terminates in a `goto`. **None runs off the end
into the next sequence** — so fall-through between sequences is not an edge class, which was an
open question before the walk was run.

### 1.1 — The union check (AC3)

| | frames | cels | CoCo3 B |
|---|---|---|---|
| named by some sequence stream | 224 | 210 | 50,888 |
| defined in `Fdef` | 234 | **211** | **50,890** |
| P5.0's figure | | 211 | 50,890 |

**PASS.** The tool reproduces P5.0 exactly on the `Fdef` total.

Four `Fdef` frames are defined and named by **no** stream: **161, 175, 176, 206**. Each is
explained: `161` (blocking) is written **directly** by `AUTO.S:968` — `lda #161 / sta OpPosn` —
bypassing the sequence table; `175`/`176` are commented out of the `stabbed` stream
(`SEQTABLE.S:247  ; db 175`); `206` is marked `;unused` in `FRAMEDEF.S`. *A frame number can be
poked straight into `CharPosn`/`OpPosn`, so the sequence table is not the only writer.*

---

## 2. ★★★ THE CONTROLLER DISPATCHES ON THE FRAME NUMBER, AND ONLY 36 FRAMES REACH IT

This is the finding that makes "peak" a smaller question than "sum". `GENCTRL`
[`CTRL.S:686-733`], after the `CharAction`/`CharSword`/`CharID` guards:

```
 ldx CharPosn
 cpx #15   beq :standing      15              -> standing
 cpx #48   beq :turning       48              -> turning
 cpx #50   bcc :0
 cpx #53   bcc :standing      50,51,52        -> standing
:0
 cpx #4    bcc :starting      1,2,3           -> starting
 cpx #67   bcc :4
 cpx #70   bcc :stjumpup      67,68,69        -> stjumpup
:4 cpx #15 bcs :2
 jmp :running                 4..14           -> arunning
:2 cpx #87 bcc :1
 cpx #100  bcs :1
 jmp :hanging                 87..99          -> hanging
:1 cpx #109 beq :crouching    109             -> crouching
:3 rts                        EVERYTHING ELSE -> no transition at all
```

**36 of 240 frame slots reach a controller. From the other 204 the sequence runs to completion
and the only reachable cels are the intra-table closure.**

And the routines are small — except one:

| routine | targets | reachable cels | CoCo3 B | entered from frames |
|---|---|---|---|---|
| **`standing`** | **30** | 144 | **33,194** | 15, 50, 51, 52 |
| `arunning` | 4 | 40 | 11,759 | 4-14 |
| `crouching` | 5 | 48 | 10,176 | 109 |
| `FightCtrl` | 12 | 33 | 9,028 | (`CharSword == 2`) |
| `starting` | 1 | 19 | 4,572 | 1, 2, 3 |
| `stjumpup` | 1 | 19 | 4,572 | 67, 68, 69 |
| `hanging` | 5 | 21 | 4,183 | 87-99 |
| `turning` | 1 | 14 | 3,902 | 48 |
| `Stairs` | 1 | 13 | 2,235 | (guard) |
| `GuardCtrl` | 3 | 6 | 1,445 | (guard) |

**`standing` is the hub and it is the binding constraint.** Standing itself needs **one cel, 164
bytes** — and the 30 things the player may ask for next need 33,194.

### 2.1 — The control edge set is complete (AC1)

Six `jumpseq` call sites had no `lda #<seqname>` in reach. All six resolve, and none is left
unenumerated:

| site | what it is |
|---|---|
| `CTRLSUBS.S:36`, `:81` | `jmp OPJUMPSEQ` / `jmp JUMPSEQ` — the module's **own jump table** at its head, not call sites. Excluded on case: real callers use the lowercase equate. |
| `CTRL.S:1859` | `DoStepfwd`: `adc #stepfwd1-1 / jmp jumpseq` with A = `getfwddist` (0-13) → **sequences 29-42**, computed and enumerated. |
| `SUBS.S:1023`, `:1032` | `pjumpseq`/`kjumpseq`/`mjumpseq`/`vjumpseq` — **trampolines** that swap the loaded character and pass A through. Not target selectors; their callers are, and are scanned like any other region. |
| `AUTO.S:1058` | `chgshadposn`: A is the 8th byte of a 7-byte `shadpos*` record (`shadpos6a hex … / db stand`). **Enumerable, and shadow-only.** |

**No genuinely unenumerable site remains.** What is *not* modelled is the **guards inside** each
routine — whether `standing` actually picks `DoStartrun` depends on the joystick, `gotsword`,
`EnemyAlert` and the block underfoot. So every W1/W2 figure below is an **upper bound within a
routine**; the partition **between** routines is exact.

The involuntary edges — the transitions the kid does not choose — were enumerated separately and
are added at every window: `bump`, `hardbump`, `bumpfall`, `bumpengfwd/back` (`COLL.S`),
`crush`, `hardland` (`MOVER.S`), `stabbed`, `stabkill`, `fightfall` (`MISC.S`), `halve`
(`COLL.S CHECKSLICE`), `dropdead` (`GENCTRL`'s dead path), plus the guard's and the cutscene's.

---

## 3. The peaks (AC4)

Every figure states its window. **CoCo3 4-colour packed bytes; the kid, through `Fdef`, because
`usealtsets` [`CTRLSUBS.S:1685`] returns immediately for `CharID 0`.**

| window | what it assumes | max | median | min | worst-case node |
|---|---|---|---|---|---|
| **W0 mid-move** | the current frame is not one of the 36; the controller **cannot** intervene. **EXACT — no guard is unmodelled, because there is no guard.** | **8,219 B** | 1,294 B | 114 B | `jumphangMed` |
| **W1 one decision** | the controller fires once; a routine's whole target set is taken | **40,141 B** (185 cels) | 19,516 B | 12,232 B | `runstop` |
| **W2 two decisions** | W1 iterated | 51,333 B (228 cels) | 50,731 B | | `turn` |
| **W∞ fixpoint** | = the whole moveset | 51,630 B | | | |

*(armed; the unarmed figures and the split are §4b.)*

★ **W2 is already the fixpoint for practical purposes**, and W∞ (51,630) is the sword-corrected
total minus the four frames no stream names. *P5.0's number was the fixpoint, correctly computed
and wrongly labelled.*

From `stand` specifically: **W0 = 1 cel / 164 B, W1 = 38,225 B, W2 = 228 cels / 51,333 B.**

**Start nodes are the kid's own states** — the intra-table closure of sequences 1-93. Sequences
94-114 are the princess, the vizier and the mouse [`SEQDATA.S`], selected only by the cutscene's
`startP*`/`startV*`/`PlayCut0`; including them as *targets* moves W1 by 3,727 B, and the figure
is printed both ways by the tool rather than assumed.

---

## 4. The guard — and a correction to P5.0's figure

`usealtsets` [`CTRLSUBS.S:1685-1707`] gives the enemy's mapping exactly:

```
 ldx CharID   beq ]rts        ; kid -> main set
 cpx #24      beq ]rts        ; mouse -> main set
 cpx #5       bcs :usealt2    ; princess & vizier -> altset2
 lda CharPosn
 ... frames 102-106 -> +70 -> 172-176
 cmp #150 bcc ]rts
 cmp #190 bcs ]rts            ; frames 150-189 -> ALTSET1 (index = frame-149)
```

**Everything outside 150-189 still comes from `Fdef`.** P5.0's guard figure counted only
`IMG.CHTAB4.GD` — the 31 cels `ALTSET1` names — and therefore missed every frame the guard shares
with the kid: bumping, falling, being stabbed, dropping dead.

| | cels | CoCo3 B |
|---|---|---|
| P5.0 (`ALTSET1` only) | 31 | 9,350 |
| **everything `GuardCtrl`/`FightCtrl`/collision can select, W0-closed** | **101** | **21,295** |
| per-start W0 | | max **3,985**, median 1,266, min 121 |

★ **The guard is armed unconditionally.** `SETUPSWORD`'s own first test is `lda CharID / cmp #2 /
bne :3 / lda CharLife / bmi :2` — *"live guard's sword is always visible"* — so the sword cels are
in the guard's set at every window.

*The correction cuts both ways: the guard's total is more than twice what P5.0 said, and its
mid-move peak is a fifth of it.*

---

## 4b. ★★★ THE SWORD, AND ARMED vs UNARMED (Addendum A.3 / A.5)

**Jay, on the running oracle: the demo contains a sword fight.** That makes an omission in
P5.0's census load-bearing.

`decodeim` [`CTRLSUBS.S:1017`] is the **character** decoder. It consumes `Fimage` and uses only
`Fsword`'s **top two bits**, as bits 0-1 of the table number. `Fsword`'s **low six bits** are a
`SWORDTAB` index, and `SETUPSWORD` [`CTRLSUBS.S:1590`] follows them:

```
 lda Fsword / and #$3f / beq ]rts    ; no sword for this frame
 jsr getswordframe
 lda (framepoint),y / beq ]rts       ; entry's image byte 0 -> nothing
 jsr decodeswim                      ; sta FCharImage / lda #2 / sta FCharTable
```

**`decodeswim` is three instructions and sends every sword image to table 2 — `IMG.CHTAB3`.**
`demo_frame_census.py` skipped `SWORDTAB` by construction; it no longer does.

`SWORDTAB` [`FRAMEDEF.S:429`] is 192 bytes = **64 slots, of which 50 are defined**, naming **34
distinct images** (two entries, 43 and 44, carry image 0 — the kid stabbed, no sword drawn).

### AC3b — `IMG.CHTAB3`'s true count

| | kid (`Fdef`) | opponent (`ALTSET1`) |
|---|---|---|
| chtable3 named by **character** frames | 35 cels, 7,768 B | 0 |
| chtable3 named by **sword** frames | 23 cels, 926 B | 17 cels, 692 B |
| **overlap — already counted** | **0** | **0** |
| **new — never counted** | **23 cels, 926 B** | **17 cels, 692 B** |
| **chtable3 TRUE total** | **58 cels, 8,694 B** | 17 cels, 692 B |

**The overlap is zero: not one sword cel was already counted.** The two decoders address
disjoint parts of `IMG.CHTAB3`.

### The restated figures, and the honest size of the correction

| | P5.0 | sword-corrected |
|---|---|---|
| kid, `Fdef` total | 50,890 B | **51,816 B** (+926) |
| guard, `ALTSET1` only | 9,350 B | **10,042 B** (+692) |
| **P5.0's 60,240 union** | 60,240 B | **61,582 B** (+1,342) |
| **P5.0's 81,690 total** | 81,690 B | **83,032 B** on P5.0's tile basis; **75,645 B** on P5.1's level-correct tiles |
| overflow vs the recruitable 65,536 | 16,154 B | **17,496 B** on P5.0's basis; **10,109 B** on P5.1's |

★ **A note that cuts against the correction's importance, and is worth making plainly (§5's
negative-result clause): the guard's `usealtsets` correction does not move the UNION at all.**
The extra guard cels are `Fdef` cels the kid already holds. It changes the guard's standalone
figure and nothing that shares a bank with the kid.

★ **And the sword is small.** 23 cels averaging 40 bytes: a sword is a thin sprite. **It adds
618 B at the binding W1 window.** It was a real omission, it is now counted, and it changes no
verdict. Saying so is the point.

### AC4b — the two modes, which cannot coexist

`GENCTRL` routes to `FightCtrl` only when `CharSword == 2` [`CTRL.S:678`], and `SETUPSWORD`
draws nothing when `CharSword == 0`. So armed and unarmed are **different resident sets**:

| | W1 max | W2 max | worst-case node |
|---|---|---|---|
| **unarmed** | **39,523 B** (171 cels) | 47,681 B (196 cels) | `runstop` / `strike` |
| **armed** | **40,141 B** (185 cels) | 51,333 B (228 cels) | `runstop` / `turn` |
| difference | **618 B** | 3,652 B | |

The larger is the requirement; their union is only needed if the **draw/sheathe transition**
(`engarde` / `resheathe` / `fastsheathe` / `pickupsword` / `turndraw`) cannot itself be a paging
point. It is a natural one — those sequences are long and reach no controller for most of it.

### A.2 — both halves of `DemoCtrl` run, and that is scope not measurement

`DemoCtrl` [`CTRL.S:587`] branches on `CharSword`: unarmed → `:preprog jmp demo`; armed →
`guardprog = 10 / jsr AutoCtrl / guardprog = 11` — **the guard AI driving the kid**
[`AUTO.S`, *"control kid in demo"*]. Jay's observation means both run in one demo.

★ **`demo` is a TRAMPOLINE, not a move stream.** `demo ds 3` [`GAMEEQ.S:305`] is a three-byte
`JMP` slot inside the `dum subs` jump table at `$E000`, so `jmp demo` is an indirection, not a
data pointer. The slot resolves to `SUBS.S:18 jmp DEMO` → `SUBS.S:1233`, which is three
instructions: `lda #<DemoProg1 / ldx #>DemoProg1 / jmp AutoPlayback`. **So the unarmed half is a
recorded input program replayed through `AutoPlayback`, and the armed half is the guard AI.**

`AutoCtrl`'s combat logic and `AutoPlayback`'s program format are both in the arc's scope.
**No work on either here** — recorded so the arc is planned at its real size.

## 5. Co-residency — a union, not a sum

The kid and the guard **share `Fdef` cels** for every frame outside 150-189, so adding their two
figures double-counts. The bank holds a *set*.

| window | kid | guard | **union** | saved to sharing |
|---|---|---|---|---|
| W0 | 8,219 | 3,985 | **12,204** (54 cels) | 0 |
| W1 | 40,141 | 21,295 | **49,742** (229 cels) | 11,694 |
| W2 | 51,333 | 21,295 | 60,898 (270 cels) | 11,730 |
| W∞ | 51,630 | 21,295 | 61,195 (271 cels) | 11,730 |

★ **And the impact star.** `SETUPCOMIX` draws `starimage = $41` from `startable = 0` — chtable1
image 65 [`GAMEBG.S:136-137`] — on a hit. No frame table names it. **+182 B at every window.**

---

## 6. The tiles — resident WHILE characters draw, and P5.0 had that wrong

**Question: must the tile data be readable while characters are being drawn, or only at
screen-composite time? Answer: while characters are being drawn.**

P5.0 §3F wrote that *"a screen is composited once and redrawn on room change, making the tiles a
load-time requirement, not a per-frame one."* The frame path says otherwise:

```
MainLoop -> FrameAdv [TOPCTRL.S:606]
              cutplan? no  -> DoFast [TOPCTRL.S:961]
                                jsr fast          ; FRAMEADV.S:189
                                  30 blocks, RedBlockFast
                                    redbuf/movebuf/floorbuf/wipebuf marked?
                                      -> RedBlockSure -> fastlay on bgtable1/2
                              -> PageFlip
```

`FAST` runs **every frame** and redraws the blocks the redraw buffers mark — the blocks the
characters have moved over — straight out of the tile tables. `MARKRED`/`MARKMOVE`/`MARKFLOOR`
[`CTRLSUBS.S`] are what set those marks, from the characters' own footprints.

*This does not contradict P3.88's "the oracle peels."* Both are true: `DRAWMID` saves each
character's underlayer and `SNGPEEL` restores it next frame, **and** the block-level redraw
handles what the peel cannot — the moving scenery (gates, spikes, flames, loose floors) and the
strength meters. **The peel is per-sprite; the block redraw is per-block; the tile tables serve
the second.**

**A room change costs one frame and no disk read.** `PrepCut` [`TOPCTRL.S:1039`] sets
`VisScrn` and `cutplan = 1`; `FrameAdv` then takes `DoCleanCut` [`TOPCTRL.S:891`], which draws
the background on page 2 (`drawbg` → `DoSure`), **copies it to page 1** (`copyscrn`), adds the
characters (`DoFast`) and flips — all inside one `jsr FrameAdv`, with a **black text screen shown
over the whole thing** (`lrclse` + `TEXTon`). The blueprint (2,304 B) and both tile tables are
already resident; nothing is read. *The port's `HAL_gfx_mirror` (P3.17) is the same move —
build once, copy, then composite — arrived at independently.*

**So the windows are NOT disjoint.** Tiles and characters are both live in the same frame.

### 6.1 — But the level needs a fraction of the tile FILES

`21,450 B` is the content of `IMG.BGTAB1.DUN + IMG.BGTAB2.DUN` — the tiles for **all fifteen
dungeon levels**. `LEVEL0` uses far less:

| | images | CoCo3 B |
|---|---|---|
| worst single screen (screen 6), blueprint-determined | 24 | 4,742 |
| populated screens, median | | 2,327 |
| **whole level, union over 24 screens, blueprint-determined** | **34** | **7,202** |
| **whole level, plus every state-dependent image its pieces unlock** | | **14,063** |
| ★ **+ the strength meters** (`bgtable2` 8-12, drawn every frame inside `FAST`) | 5 | **14,147** |
| *(a real level would add the text glyphs: 17,300 B — the DEMO shows none, see §10)* | | |
| the two files (all 15 levels) | 178 | 21,450 |

The upper bound adds, by name from `BGDATA.S`/`GAMEBG.S`: the gate's 16 bar frames plus
`gatebotSTA/ORA/gateB1/gatecmask`; the **9 torch flames** (`GAMEBG.S:147 torchflame`); the
slicer's `slicertop/bot/bot2/gap/frnt`; the loose floor's `loosea/loosed/looseb`; the spikes'
`spikea/spikeb`; the exit's `stairs/door/doormask/toprepair`; and the climb-up masks
`CUmask/CUpiece/CUpost`.

---

## 6.2 — AC5b: the demo DOES change rooms mid-play, and the compositor holds on three screens

**Screen 1's left neighbour is SCREEN 2** — `MAP` [`CTRLSUBS.S:243`, `GETLEFT` reads
`MAP-4+scrn*4`] gives screen 1 `[left 2, right 0, up 0, down 7]`. The kid starts on screen 1
[`INFO.KidStartScrn = 1`] and Jay's observation — he moves left and fights near the left of the
second screen — is the blueprint's screen 2.

**Confirmed by watching the oracle rather than by inference.** `oracle_demo_bg.lua` now samples
several instants in one boot (`P_AFTER` takes a comma list), and each dump is identified by
scanning all 24 screens:

| frames after `Demo` arms | best-matching screen | match |
|---|---|---|
| +300 | **1** | 96.54% |
| +450 | **2** | **96.82%** |
| +750 | 2 | 94.80% |
| +900 | 2 | 95.24% |
| +1200 | **4** | 95.66% |

So the demo's path is **1 → 2 → … → 4**, it crosses screen boundaries **during play**, and
`bg_compose.py` is now validated on **three** screens rather than one (P5.0 §7 flag 4, closed).

Every differing byte, on all three, falls in a named category:

| | screen 1 | screen 2 | screen 4 |
|---|---|---|---|
| gate bars (live gate position) | 45 | 21 | — |
| torch flames (`setupflame`, animated) | 38 | 23 | 28 |
| loose floors (`drawlooseb`/`drawloosed`) | — | 144 | 124 |
| strength meters | 20 | 20 | 40 |
| characters (residual, unseparated) | 163 | 36 | 141 |
| **UNEXPLAINED background bytes** | **0** | **0** | **0** |

★ **The limitation in that table, stated rather than glossed:** the character bucket is a
*residual* — I do not have the actors' positions, so I cannot prove those bytes are characters
rather than a compositor error. What supports it is screen 1, where the kid was at the bottom of
the frame and **rows 24-159 were byte-identical**, and the fact that the residual is
character-sized on all three.

★ **A MAME reading gotcha, worth carrying.** POP toggles `setaux`/`setmain` constantly, and
`mem:read_u8` reads through whichever bank is switched in. At +300 the read landed in MAIN, so
the HGR pages were valid and `level`/`SCRNUM` read as garbage (255 / 24); at +600 it landed in
AUX, so `level`/`SCRNUM` read correctly (0 / 2) and the HGR dump was `topctrl`'s CODE. **The two
are anti-correlated** — a dump where the game variables look right is a dump where the screen
does not. Identify the screen by matching it, not by reading `SCRNUM`.

**And the transition itself:** `PrepCut` [`TOPCTRL.S:1039`] sets `VisScrn` and `cutplan = 1`;
`FrameAdv` takes `DoCleanCut` [`TOPCTRL.S:891`], which draws the background on page 2, copies it
to page 1, adds the characters and flips — **one `jsr FrameAdv`, one frame, no disk read**, with
a black text screen shown over it. Blueprint and tile tables are already resident.

---

## 6.3 — AC5c: what else names images, and was unwalked

`SWORDTAB` was skipped in a parser that reads four labels. Checking the same class elsewhere
found **three more image-naming sites, all in `GAMEBG.S`, none of them indexed by a blueprint or
a piece id** — which is exactly why the tile walk missed them:

| what | source | table | bytes |
|---|---|---|---|
| **strength meters** — `bullet $88 / bline 89,8a,8b / blank $8c` | `GAMEBG.S:99-101` | bgtable2 8-12 | **84** |
| **impact star (comix)** — `starimage = $41 / startable = 0` | `GAMEBG.S:136-137` | chtable1 #65 | **182** |
| **text glyphs** — `prchar` `sbc #"/"`, `pretext` sets `TABLE = bgtable2` | `GAMEBG.S:1134,1175` | bgtable2 1-10, $12-$2B | 1,560 + 3,368 |

The meters are drawn **every frame**, inside `FAST`'s `updatemeters`, and are folded into the
tile figure above. The star fires on a hit and is folded into the character figure.
★ **The glyphs cost the DEMO nothing**: `RESTART` suppresses the level banner at level 0
(`lda level / beq :nomsg`) and `timerequest` is never set. For a real level they take the tile
figure from 14,147 to **17,300 B**.

**Everything else checked and clear.** `FRAMEDEF.S` has exactly four labelled tables and all four
are now walked (`Fdef`, `ALTSET1`, `ALTSET2`, `SWORDTAB`). Every `BGDATA.S` table is walked by
`bg_compose.py` plus `tile_working_set.py`'s `STATE_IMAGES`. The remaining `GAMEBG.S` image lists
— `ptorchflame`, `stari`, `glassimg`, `flowimg`, `postimg`, `pmaski` — are all `chtable6`, i.e.
the princess room, already accounted for in the cutscene arc. **No other gameplay image-naming
table is unwalked.**

## 7. ★★★ THE COMBINED PEAK-AT-ANY-INSTANT (AC5), AND WHAT IT SETTLES

Characters and tiles come from different tables, so here the union **is** the sum.

| window | chars (kid ∪ guard) | tiles (level, upper) | **total** | vs bank 32,768 | vs recruited 65,536 | vs window 15,872 |
|---|---|---|---|---|---|---|
| **W0** mid-move | 12,386 | 14,147 | **26,533** | **FITS** (6,235 spare) | **FITS** | over by 10,661 |
| **W1** one decision | 49,924 | 14,147 | **64,071** | over by 31,303 | **FITS** (1,465 spare) | over by 48,199 |
| W2 | 61,080 | 14,147 | 75,227 | over by 42,459 | over by 9,691 | over by 59,355 |
| W∞ | 61,377 | 14,147 | 75,524 | over by 42,756 | over by 9,988 | over by 59,652 |
| *P5.0's figure* | *60,240* | *21,450* | *81,690* | *over by 48,922* | *over by 16,154* | — |
| *P5.0's basis, sword-corrected* | *61,582* | *21,450* | *83,032* | — | *over by 17,496* | — |

*(character columns include the sword cels and the +182 B impact star.)*

**THE SHORTFALL AGAINST THE RECRUITABLE BANK DISSOLVES AT W1 — WITH 1,465 BYTES TO SPARE, WHICH
IS 2.2% AND IS NOT COMFORTABLE.** Against the bank *as it stands* (32,768) it does not dissolve
at any window above W0.

**AND THE BINDING CONSTRAINT HAS MOVED FROM CAPACITY TO ADDRESSABILITY.** At most **15,872
bytes** are visible to the CPU at once — `$FFA4/$FFA5` must carry the back buffer, leaving
`$C000-$DFFF` (8,192) and `$E000-$FDFF` (7,680) [`demo-memory-map.md §4`]. **Every window,
including W0, exceeds it.** Capacity is now satisfiable; simultaneous visibility is not, and no
amount of recruited RAM changes that.

**This is a measurement. It authorises nothing.** The four options P5.0 named stay unbuilt and
unranked, and the choice is Jay's.

---

## 8. What the next dispatch can now test

The numbers above hand the paging question a concrete shape:

- **A swap that completes inside W0 is affordable**: 12,386 B of characters, and the port knows
  *exactly* when it is safe — the 204 frame slots that reach no controller.
- **A swap that must survive one control decision is not**: 49,924 B of characters.
- **`standing` alone costs 33,194 B**, so "keep the standing hub pinned and page the rest" is a
  shape the measurement supports — and pinning it is most of the bank.
- **The room-change frame is already a covered black screen** (§6), which is the natural place to
  hide a tile read, exactly as the cutscene hides its cel reads in the song holds.

---

## 9. AC2 — per-sequence cel count and CoCo3 bytes

Generated by `harness/tools/seq_graph.py --out`. `act` is the `CharAction` value(s) the body
sets; out-edges are the terminal `goto` plus any `ifwtless` targets. **The `cels`/`CoCo3 B`
columns are CHARACTER cels only** — the sword cels a frame's `Fsword&$3f` adds (§4b) are a
per-mode overlay and are counted there, not here.

| # | sequence | label | frames | cels | CoCo3 B | act | out-edges |
|---|---|---|---|---|---|---|---|
| 1 | `startrun` | `startrun` | 14 | 14 | 3902 | 1 | `runcyc1` |
| 2 | `stand` | `stand` | 1 | 1 | 164 | 0 | `stand` |
| 3 | `standjump` | `standjump` | 18 | 18 | 4408 | 1 | `stand` |
| 4 | `runjump` | `runjump` | 11 | 11 | 3937 | 1 | `runcyc1` |
| 5 | `turn` | `turn` | 8 | 8 | 1632 | 7 | `stand` |
| 6 | `runturn` | `runturn` | 13 | 13 | 3906 | 1 | `runcyc7` |
| 7 | `stepfall` | `stepfall` | 4 | 4 | 1078 | 3 | `freefall`, `stepfloat` |
| 8 | `jumphangMed` | `jumphangMed` | 14 | 14 | 3089 | 1,2 | `hang` |
| 9 | `hang` | `hang` | 13 | 13 | 4022 | 2 | `hangdrop` |
| 10 | `climbup` | `climbup` | 17 | 11 | 2147 | 1,5 | `stand` |
| 11 | `hangdrop` | `hangdrop` | 5 | 5 | 884 | 0,1,5 | `stand` |
| 12 | `freefall` | `freefall` | 1 | 1 | 216 | 4 | `freefall:loop` |
| 13 | `runstop` | `runstop` | 8 | 8 | 2138 | 1 | `stand` |
| 14 | `jumpup` | `jumpup` | 13 | 13 | 2865 | 0,1 | `hangdrop` |
| 15 | `fallhang` | `fallhang` | 1 | 1 | 224 | 3 | `hang` |
| 16 | `jumpbackhang` | `jumpbackhang` | 14 | 14 | 3089 | 1,2 | `hang` |
| 17 | `softland` | `softland` | 3 | 3 | 426 | 1,5 | `softland:crouch` |
| 18 | `jumpfall` | `jumpfall` | 4 | 4 | 1078 | 3 | `freefall` |
| 19 | `stepfall2` | `stepfall2` | 0 | 0 | 0 | — | `stepfall` |
| 20 | `medland` | `medland` | 12 | 12 | 2092 | 5 | `stand` |
| 21 | `rjumpfall` | `rjumpfall` | 4 | 4 | 1078 | 3 | `freefall` |
| 22 | `hardland` | `hardland` | 1 | 1 | 144 | 5 | `hardland:dead` |
| 23 | `hangfall` | `hangfall` | 1 | 1 | 216 | 3 | `freefall` |
| 24 | `jumphangLong` | `jumphangLong` | 14 | 14 | 3089 | 1,2 | `hang` |
| 25 | `hangstraight` | `hangstraight` | 3 | 3 | 772 | 6 | `hangstraight:loop` |
| 26 | `rdiveroll` | `rdiveroll` | 3 | 3 | 426 | 1 | `rdiveroll:crouch` |
| 27 | `sdiveroll` | `sdiveroll` | 5 | 5 | 672 | 1 | `crawl:crouch` |
| 28 | `highjump` | `highjump` | 13 | 13 | 2865 | 1 | `hangdrop` |
| 29 | `stepfwd1` | `step1` | 2 | 2 | 324 | 1 | `stand` |
| 30 | `?` | `step2` | 3 | 3 | 480 | 1 | `stand` |
| 31 | `?` | `step3` | 5 | 5 | 796 | 1 | `stand` |
| 32 | `?` | `step4` | 5 | 5 | 796 | 1 | `stand` |
| 33 | `?` | `step5` | 8 | 8 | 1530 | 1 | `stand` |
| 34 | `?` | `step6` | 8 | 8 | 1530 | 1 | `stand` |
| 35 | `?` | `step7` | 8 | 8 | 1530 | 1 | `stand` |
| 36 | `?` | `step8` | 11 | 11 | 2321 | 1 | `stand` |
| 37 | `?` | `step9` | 1 | 1 | 160 | 1 | `step10a` |
| 38 | `?` | `step10` | 11 | 11 | 2397 | 1 | `stand` |
| 39 | `?` | `step11` | 12 | 12 | 2663 | 1 | `stand` |
| 40 | `?` | `step12` | 12 | 12 | 2663 | 1 | `stand` |
| 41 | `?` | `step13` | 12 | 12 | 2663 | 1 | `stand` |
| 42 | `?` | `fullstep` | 12 | 12 | 2663 | 1 | `stand` |
| 43 | `turnrun` | `turnrun` | 0 | 0 | 0 | 1 | `runstt1` |
| 44 | `testfoot` | `testfoot` | 11 | 11 | 2342 | — | `stand` |
| 45 | `bumpfall` | `bumpfall` | 4 | 4 | 1078 | 5 | `freefall`, `bumpfloat` |
| 46 | `hardbump` | `hardbump` | 4 | 4 | 741 | 5 | `standup` |
| 47 | `bump` | `bump` | 3 | 3 | 606 | 5 | `stand` |
| 48 | `superhijump` | `superhijump` | 13 | 13 | 2865 | — | `freefall` |
| 49 | `standup` | `standup` | 10 | 10 | 1840 | 5 | `stand` |
| 50 | `stoop` | `stoop` | 3 | 3 | 426 | 1 | `stoop:crouch` |
| 51 | `impale` | `impale` | 1 | 1 | 297 | 1 | `impale:dead` |
| 52 | `crush` | `crush` | 0 | 0 | 0 | — | `medland` |
| 53 | `deadfall` | `deadfall` | 1 | 1 | 144 | 4 | `deadfall:loop` |
| 54 | `halve` | `halve` | 1 | 1 | 156 | 1 | `halve:dead` |
| 55 | `engarde` | `engarde` | 7 | 5 | 1281 | 1 | `ready:loop` |
| 56 | `advance` | `advance` | 3 | 3 | 1116 | 1 | `ready` |
| 57 | `retreat` | `retreat` | 2 | 2 | 592 | 1 | `ready` |
| 58 | `strike` | `strike` | 8 | 8 | 2579 | 1,5 | `ready` |
| 59 | `flee` | `flee` | 0 | 0 | 0 | 7 | `turn` |
| 60 | `turnengarde` | `turnengarde` | 0 | 0 | 0 | 5 | `retreat` |
| 61 | `strikeblock` | `strikeblock` | 2 | 2 | 639 | — | `blocking` |
| 62 | `readyblock` | `readyblock` | 2 | 2 | 525 | — | `ready` |
| 63 | `landengarde` | `landengarde` | 0 | 0 | 0 | 1 | `ready` |
| 64 | `bumpengfwd` | `bumpengfwd` | 0 | 0 | 0 | 5 | `ready` |
| 65 | `bumpengback` | `bumpengback` | 2 | 2 | 592 | 5 | `ready` |
| 66 | `blocktostrike` | `blocktostrike` | 1 | 1 | 273 | — | `guy4` |
| 67 | `strikeadv` | `strikeadv` | 2 | 2 | 770 | 1 | `ready` |
| 68 | `climbdown` | `climbdown` | 10 | 7 | 1389 | 1,3 | `hang1` |
| 69 | `blockedstrike` | `blockedstrike` | 1 | 1 | 374 | 1 | `guy7` |
| 70 | `climbstairs` | `climbstairs` | 12 | 12 | 2071 | 5 | `stand` |
| 71 | `dropdead` | `dropdead` | 6 | 6 | 893 | 1 | `dropdead:dead` |
| 72 | `stepback` | `stepback` | 0 | 0 | 0 | — | `stand` |
| 73 | `climbfail` | `climbfail` | 4 | 0 | 0 | — | `hangdrop` |
| 74 | `stabbed` | `stabbed` | 3 | 3 | 812 | 5 | `guy8` |
| 75 | `faststrike` | `faststrike` | 7 | 7 | 2334 | 1,5 | `ready` |
| 76 | `strikeret` | `strikeret` | 4 | 4 | 1218 | 1 | `retreat` |
| 77 | `alertstand` | `alertstand` | 1 | 1 | 164 | — | `alertstand:loop` |
| 78 | `drinkpotion` | `drinkpotion` | 15 | 15 | 3324 | 1 | `stand` |
| 79 | `crawl` | `crawl` | 5 | 5 | 672 | 1 | `crawl:crouch` |
| 80 | `alertturn` | `alertturn` | 0 | 0 | 0 | 5 | `goalertstand` |
| 81 | `fightfall` | `fightfall` | 4 | 4 | 1078 | 3 | `freefall` |
| 82 | `efightfall` | `efightfall` | 4 | 4 | 1078 | 3 | `freefall` |
| 83 | `efightfallfwd` | `efightfallfwd` | 4 | 4 | 1078 | 3 | `freefall` |
| 84 | `running` | `running` | 0 | 0 | 0 | 1 | `runcyc1` |
| 85 | `stabkill` | `stabkill` | 0 | 0 | 0 | 5 | `dropdead` |
| 86 | `fastadvance` | `fastadvance` | 2 | 2 | 792 | 1 | `ready` |
| 87 | `goalertstand` | `goalertstand` | 1 | 1 | 164 | 1 | `alertstand:loop` |
| 88 | `arise` | `arise` | 3 | 3 | 617 | 5 | `ready` |
| 89 | `turndraw` | `turndraw` | 2 | 2 | 312 | 7 | `engarde` |
| 90 | `guardengarde` | `guardengarde` | 0 | 0 | 0 | — | `ready` |
| 91 | `pickupsword` | `pickupsword` | 4 | 4 | 942 | 1 | `resheathe` |
| 92 | `resheathe` | `resheathe` | 15 | 15 | 3480 | 1,5 | `stand` |
| 93 | `fastsheathe` | `fastsheathe` | 5 | 5 | 1178 | 1 | `stand` |
| 94 | `Pstand` | `Pstand` | 1 | 1 | 266 | — | `Pstand` |
| 95 | `Vstand` | `Vstand` | 1 | 1 | 234 | — | `Vstand` |
| 96 | `Vapproach` | `Vwalk` | 6 | 6 | 1449 | — | `Vwalk1` |
| 97 | `Vstop` | `Vstop` | 2 | 2 | 695 | — | `Vstand` |
| 98 | `Palert` | `Palert` | 9 | 9 | 2511 | — | `Pstand` |
| 99 | `Pback` | `Pback` | 6 | 6 | 1442 | — | `Pback:loop` |
| 100 | `Vexit` | `Vexit` | 17 | 16 | 4284 | — | `Vwalk2` |
| 101 | `Mclimb` | `Mclimb` | 1 | 1 | 24 | — | `Mclimb` |
| 102 | `Vraise` | `Vraise` | 13 | 13 | 2531 | — | `Vraise:loop` |
| 103 | `Plie` | `Plie` | 1 | 1 | 231 | — | `Plie` |
| 104 | `patchfall` | `patchfall` | 0 | 0 | 0 | — | `fall1` |
| 105 | `Mscurry` | `Mscurry` | 2 | 2 | 48 | 1 | `Mscurry1:loop` |
| 106 | `Mstop` | `Mstop` | 1 | 1 | 24 | — | `Mstop:loop` |
| 107 | `Mleave` | `Mleave` | 2 | 2 | 64 | 0 | `Mscurry1` |
| 108 | `Pembrace` | `Pembrace` | 13 | 13 | 3402 | — | `Pembrace:loop` |
| 109 | `Pwaiting` | `Pwaiting` | 1 | 1 | 217 | — | `Pwaiting:loop` |
| 110 | `Pstroke` | `Pstroke` | 1 | 1 | 429 | — | `Pstroke:loop` |
| 111 | `Prise` | `Prise` | 12 | 12 | 3812 | — | `Prise:loop` |
| 112 | `Pcrouch` | `Pcrouch` | 15 | 15 | 4755 | — | `Pcrouch:loop` |
| 113 | `Pslump` | `Pslump` | 2 | 2 | 398 | — | `Pslump:loop` |
| 114 | `Mraise` | `Mraise` | 1 | 1 | 40 | — | `Mraise:loop` |
