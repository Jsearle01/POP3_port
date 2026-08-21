# demo-behaviour.md — what the demo does, and what the port must implement to do it

**Authorship:** Clyde-authored **operational recon**, the same class as `demo-memory-map.md` and
`demo-move-graph.md` — a transcription of the oracle's own data and an inventory of its routines,
with every figure cited to a source line. **It is not a decision record, a post-mortem, or a
behavioural model in the `CLAUDE.md §2D` sense**; nothing here is reasoning that lives in the
Orchestrator's context. *The placement under `docs/project/` was directed by the P5.3 dispatch and
is surfaced in that report's §7 rather than decided here.*

**Produced:** P5.3 Phase 1 (2026-08-21), against HEAD `4160c7f` on `wip`.
**Regenerate the counts:** the instruction figures in §5 come from
`oracle/source/01 POP Source/Source/AUTO.S` by line span; the spans are given so they can be
recounted.

---

## 1. The demo has THREE phases, not one

`DemoCtrl` [`CTRL.S:587`] is the whole of it, and it branches twice:

```
DemoCtrl
 lda milestone
 bne :finish                 ; PHASE 3
 lda CharSword
 beq :preprog                ; PHASE 1
 lda #10 / sta guardprog     ; PHASE 2
 jsr AutoCtrl
 lda #11 / sta guardprog
 rts
:preprog jmp demo
:finish  jsr clrall / sta clrbtn / lda #-1 / sta clrF / sta JSTKX  ;run o.s.
```

| phase | condition | what drives the kid |
|---|---|---|
| **1 — the walk** | `milestone == 0`, `CharSword == 0` | `DEMO` → `AUTOPLAYBACK(DemoProg1)`: a **recorded input script** |
| **2 — the fight** | `milestone == 0`, `CharSword != 0` | `AutoCtrl` with `guardprog = 10` — **the guard AI, driving the kid** |
| **3 — the exit** | `milestone != 0` | joystick forced hard forward (`JSTKX = -1`); he runs off screen |

★ **`demo` is a THREE-BYTE `JMP` SLOT, not a move stream.** `demo ds 3` [`GAMEEQ.S:305`] sits in the
`dum subs` jump table at `$E000`; it resolves to `SUBS.S:18 jmp DEMO` → `SUBS.S:1233`, which is
`lda #<DemoProg1 / ldx #>DemoProg1 / jmp AutoPlayback`. *Follow the vector: a `ds` slot is not the
end of a trace.*

**Phase 2 begins when the kid draws his sword**, which the ordinary `standing` controller does on
its own when a guard is in range [`CTRL.S:1049-1090`] — nothing in the demo script asks for it.
**Phase 3 begins when the guard dies**: **`DEADENEMY` [`SUBS.S:1699`]** — the enclosing routine, not
just the line — takes its `:demo` branch and does `lda #1 / sta milestone ;start demo, part 2 /
lda #0 / sta PreRecPtr / sta PlayCount` [`SUBS.S:1712-1717`], where every other level would cue
`s_Vict` instead.

★ **That `PreRecPtr`/`PlayCount` reset is dead.** Once `milestone` is non-zero `DemoCtrl` takes
`:finish` and never calls `demo` again, so nothing ever reads the reset values. Harmless; recorded
so the next reader does not infer a fourth phase from it.

**Two exits, both to the attract loop.** `EndDemo` in the script → `jmp attractmode`
[`AUTO.S:1219`]; or `NextFrame`'s level-0 check — `lda level / bne :no0 / lda KidScrn / cmp #24 /
beq GOATTRACT` [`TOPCTRL.S:536-543`] — when he leaves via screen 24.

---

## 2. `DemoProg1`, transcribed [`SUBS.S:1194-1222`]

**Format** [`AUTO.S:1122-1129`]: pairs of `(frame #, command)`, one byte each. The oracle's own
note: *"255 frames = approx. 25-30 seconds."*

**Command encoding** — declared **twice**, identically, at `AUTO.S:1094-1103` and `SUBS.S:1182-1191`:

| name | value | meaning [`AUTO.S:1105-1115`] |
|---|---|---|
| `EndProg` | **-2** = `$FE` | end of programmed sequence |
| `EndDemo` | **-1** = `$FF` | end of demo |
| `Ctr` | 0 | centre joystick & release button |
| `Fwd` | 1 | joystick forward |
| `Back` | 2 | joystick back |
| `Up` | 3 | joystick up |
| `Down` | 4 | joystick down |
| `Upfwd` | 5 | joystick up **and** forward |
| `Press` | 6 | press & hold button |
| `Release` | 7 | release button |

**`AUTOPLAYBACK` tests `cmp #-1`**, i.e. `$FF`, so `EndDemo` is the only terminator the demo can
reach; `EndProg` (`$FE`) falls through the whole `cmp` chain to `]rts` and would be a silent no-op
here. (`ShadProg5`, the level-5 thief, is the sequence that ends on `EndProg` — `AUTOPLAYBACK` is
shared, so it is not demo-only code.)

### 2.1 — The 25 entries

★ **25 pairs, 50 bytes** — the P5.3 dispatch says twenty-nine. Counted twice from the listing.
`d1 = 65`, `d2 = 115`, `d3 = 193` are assembler equates, expanded here.

| # | frame | as written | command | value | Mechner's comment |
|---|---|---|---|---|---|
| 1 | 0 | `0` | `Ctr` | 0 | |
| 2 | 1 | `1` | `Fwd` | 1 | |
| 3 | 13 | `13` | `Ctr` | 0 | |
| 4 | 30 | `30` | `Fwd` | 1 | *start running…* |
| 5 | 37 | `37` | `Upfwd` | 5 | *jump 1st pit* |
| 6 | 47 | `47` | `Ctr` | 0 | |
| 7 | 48 | `48` | `Fwd` | 1 | *& keep running* |
| 8 | 65 | `d1` | `Ctr` | 0 | *stop* |
| 9 | 73 | `d1+8` | `Back` | 2 | *look back…* |
| 10 | 75 | `d1+10` | `Ctr` | 0 | |
| 11 | 99 | `d1+34` | `Back` | 2 | |
| 12 | 100 | `d1+35` | `Ctr` | 0 | |
| 13 | 115 | `d2` | `Upfwd` | 5 | *jump 2nd pit* |
| 14 | 128 | `d2+13` | `Press` | 6 | *& grab ledge* |
| 15 | 136 | `d2+21` | `Up` | 3 | |
| 16 | 157 | `d2+42` | `Release` | 7 | |
| 17 | 158 | `d2+43` | `Ctr` | 0 | |
| 18 | 159 | `d2+44` | `Fwd` | 1 | |
| 19 | 173 | `d2+58` | `Down` | 4 | |
| 20 | 177 | `d2+62` | `Ctr` | 0 | |
| 21 | 178 | `d2+63` | `Fwd` | 1 | |
| 22 | 188 | `d2+73` | `Ctr` | 0 | |
| 23 | 193 | `d3` | `Fwd` | 1 | |
| 24 | 205 | `d3+12` | `Ctr` | 0 | |
| 25 | **233** | `d3+40` | **`EndDemo`** | `$FF` | |

The label is `DemoProg1 ;up to fight w/1st guard` — **the script's own comment says it only covers
phase 1.** It stops being consulted the moment the sword comes out.

★ **A corroboration worth keeping.** 233 game frames at the ~9.5 game-fps measured at P5.2 is
**≈ 24.5 s**, and P5.1/P5.2 observed the demo running about 1,400 display frames ≈ 23 s before the
attract loop restarted. Two independent routes to the same length.

---

## 3. `AUTOPLAYBACK` [`AUTO.S:1149-1229`] — 81 lines, 50 instructions

★ The dispatch says *"roughly thirty lines"*; that describes the **cursor logic** only. The
command dispatch is another fifty lines and it is half the routine.

```
AUTOPLAYBACK
 sta ProgStart / stx ProgStart+1        ; A/X = the program's address

 lda PlayCount / cmp #254 / bcs :rts    ; (1) SATURATION
 inc PlayCount

 ldy PreRecPtr                          ; points at the NEXT entry's TIMESTAMP
 lda PlayCount / cmp (ProgStart),y
 bcs :next
 dey / lda (ProgStart),y / jmp :ex      ; (2) REPEAT the PREVIOUS command

:next iny / lda (ProgStart),y           ; the command
      iny / sty PreRecPtr               ; advance two bytes

:ex   cmp #-1 / beq :enddemo            ; then eight `cmp #n / beq` cases
```

**The two behaviours that are easy to miss, and both matter:**

1. **`PlayCount` saturates at 254 by DOING NOTHING.** `cmp #254 / bcs :rts` returns before the
   increment *and before the dispatch* — so at 254 the routine stops issuing commands entirely.
   It does not hold the last command; it issues none.
2. **Between timestamps it REPEATS the previous command.** `dey / lda (ProgStart),y` reads the
   command byte of the entry *before* the one `PreRecPtr` points at. So the script is a list of
   **changes**, and the input is held between them — which is why 25 entries drive 233 frames.

**★ Does 233 plus the saturation leave any interaction? NONE.** The script terminates at
`PlayCount == 233` with `EndDemo`, 21 frames below the 254 ceiling, and the terminator jumps to
`attractmode` rather than returning. The saturation is unreachable **on this program**. It is not
dead in general — `ShadProg5`'s last entry is at frame 255, which is above the ceiling, so for the
level-5 thief the saturation is what stops the sequence.

**Dispatch targets** [`AUTO.S:1206-1213`]: `Ctr→DoRelease`, `Fwd→DoFwd`, `Back→DoBack`,
`Up→DoUp`, `Down→DoDown`, **`Upfwd→jsr DoUp` then `jmp DoFwd`** (both, in that order),
`Press→DoPress`, `Release→DoRelBtn`.

**Entry state**, set by `RESTART` [`TOPCTRL.S:297-298`]: `PreRecPtr = 0`, `PlayCount = 0`. The
first call therefore increments to 1, compares against entry 1's timestamp of 0, takes `:next`,
and issues `Ctr` — the script's first command lands on the first frame.

---

## 4. `AUTOCTRL` [`AUTO.S:160-197`] — the inventory

**38 lines, 31 instructions, and it is a pure dispatcher on `CharID`:**

```
AUTOCTRL
 jsr DoRelease                       ; every entry starts from a clean input
 lda CharID / beq :5                 ; 0  -> KidProg          "control kid in demo"
 ... dec justblocked / dec gdtimer / dec refract    ; NOT for the kid — he skips these
 cmp #24 / beq :6                    ; 24 -> MouseProg
 cmp #4  / beq :3                    ; 4  -> SkelProg
 cmp #2  / bcc :1                    ; 1  -> ShadowProg
 lda level / cmp #13 / beq :4        ;    -> VizierProg
 jmp GuardProg                       ; 2,3 -> GuardProg
```

★ **The three timer decrements are skipped for the kid**, because the `beq :5` comes first. So in
the demo `justblocked`, `gdtimer` and `refract` tick only on the *enemy's* call, not the kid's.

★★ **AND `KidProg` IS `jmp GuardProg` — six lines, two instructions** [`AUTO.S:449-450`]. **There
is no separate kid-fighter AI.** The demo's kid is a guard, and the only thing that makes him fight
differently is `guardprog = 10` selecting a different column of the parameter table. That is the
single most useful fact in this document for sizing the arc.

### 4.1 — What `guardprog` 10 and 11 select

**`guardprog` is the row index into the fighter parameter table** [`AUTO.S:99-124`], and the source
labels the two demo columns itself [`AUTO.S:143-146`]: *"10: kid (demo) / 11: enemy (demo)"*.

**The table is 8 rows × 12 columns** (`numprogs = 12`). Its own comment block documents only five
of the eight rows; `impblockprob`, `specialcolor` and `extrastrength` are undocumented there.

| parameter | 10 — the demo's KID | 11 — the demo's ENEMY | meaning [`AUTO.S:100-104`] |
|---|---|---|---|
| `strikeprob` | **40** | **60** | probability ×255 of striking from the ready position |
| `restrikeprob` | **255** | **150** | ×255 of re-striking after blocking |
| `blockprob` | **255** | **255** | ×255 of blocking the opponent's strike |
| `impblockprob` | **255** | **175** | (undocumented in the comment block) |
| `advprob` | **100** | **100** | ×255 of advancing into striking range |
| `refractimer` | **0** | **0** | refractory period after being hit |
| `specialcolor` | **0** | **1** | |
| `extrastrength` | **0** | **0** | |

**Read as behaviour:** the demo kid **never fails to block** (255) and **always re-strikes after a
block** (255), but is **reluctant to open** (40/255 ≈ 16%). The enemy blocks perfectly too but
re-strikes less (150) and opens slightly more often (60). **Neither has a refractory period**, so
neither is stunned by a hit. It is tuned to look like a duel and to end with the kid winning.

For completeness, the same file gives level 0 a `basicstrength` of **4** and a `basiccolor` of
**1 = red** [`AUTO.S:127-134`].

### 4.2 — The fight core the two of them share

`GuardProg` [`AUTO.S:455`] splits on `CharSword`: below 2 → `Alert`, else → `EnGarde`. Everything
below that point is common to the kid, the enemy, and every guard in the game.

| routine | lines | insns | what it does |
|---|---|---|---|
| `Alert` | 46 | 31 | not en garde: turn to face, decide whether to draw |
| `EnGarde` | 125 | 85 | the main fight state machine |
| `FollowKid` | 56 | 39 | approach/retreat when out of range |
| `InRange` | 29 | 13 | range test |
| `GenFight` | 30 | 18 | the strike/block/advance decision |
| `MaybeAdvance` / `MaybeBlock` / `MaybeStrike` | 69 | 48 | the three probability rolls |
| `Do*` action primitives + `rndp` | 92 | 61 | translate a decision into joystick/button state |
| `CHECKSTRIKE` | 19 | 15 | did a strike land |

**The state it reads** (counted over `AUTO.S:455-932`): `CharPosn`, `CharFace`, `CharSword`,
`CharBlockY`, `OpPosn`, `OpFace`, `OpAction`, `OpBlockY`, `EnemyAlert`, `alertguard`, `refract`,
`justblocked`, `gdtimer`, `droppedout`, `level`, `guardprog`, the five probability rows, and the
input latches it writes — `JSTKX`, `JSTKY`, `btn`, `clrF`, `clrB`, `clrU`, `clrD`, `clrbtn`.

★ **The AI writes the same joystick latches the human player writes.** `DoFwd`, `DoPress` and the
rest set `JSTKX`/`btn`/`clr*`, and `GENCTRL` then reads them exactly as it reads a real stick.
**So the demo needs no separate control path** — it needs a writer for the latches, and the
existing controller consumes them unchanged.

---

## 5. ★★★ What the port must implement, and how big it is

**415 instructions of `AUTO.S`** plus 50 bytes of `DemoProg1` plus 96 bytes of parameter table.

**The size estimate below is an ESTIMATE and is labelled as one.** Instruction counts are measured
by line span; the byte figure applies **2.5 bytes per 6809 instruction**, which is a conservative
average for a mix of extended and immediate forms and is *not* a measurement of this code. Treat
the instruction column as the fact and the byte column as an order of magnitude.

| # | piece | source | insns | est. bytes | shared with real gameplay? |
|---|---|---|---|---|---|
| 1 | `DemoProg1` data | `SUBS.S:1194` | — | **50 B** | **DEMO-ONLY** |
| 2 | fighter parameter table | `AUTO.S:99-124` | — | **96 B** | **SHARED** (columns 0-9 are the game's) |
| 3 | `AUTOPLAYBACK` + command dispatch | `AUTO.S:1149` | 50 | ~125 B | **SHARED** — level 5's thief uses it |
| 4 | `DemoCtrl`'s three-way branch | `CTRL.S:587` | ~15 | ~38 B | **DEMO-ONLY** |
| 5 | `AUTOCTRL` dispatcher | `AUTO.S:160` | 31 | ~78 B | **SHARED** |
| 6 | `KidProg` + `GuardProg` | `AUTO.S:449` | 8 | ~20 B | **SHARED** |
| 7 | `Alert` | `AUTO.S:467` | 31 | ~78 B | **SHARED** |
| 8 | `EnGarde` | `AUTO.S:513` | 85 | ~213 B | **SHARED** |
| 9 | `FollowKid` / `InRange` / `GenFight` | `AUTO.S:638` | 70 | ~175 B | **SHARED** |
| 10 | `Maybe{Advance,Block,Strike}` | `AUTO.S:753` | 48 | ~120 B | **SHARED** |
| 11 | `Do*` primitives + `rndp` | `AUTO.S:822` | 61 | ~153 B | **SHARED** |
| 12 | `CHECKSTRIKE` | `AUTO.S:914` | 15 | ~38 B | **SHARED** |
| | **TOTAL** | | **415** | **~1,184 B** | **1,072 B shared / 88 B demo-only** |

### 5.1 — The three conclusions this yields

1. **The demo is 88 bytes of demo-only code and data.** Everything else — 91% — is the game's own
   fighting AI, which any level with a guard needs. **Building the demo is very nearly building
   gameplay combat**, and that is the arc's real size, not a demo-shaped subset of it.
2. **~1.2 KB is small against every budget in play.** `demo-memory-map.md §3` gives 25,697 B free
   below the draw window at `Demo` entry, largest run 20,072 B. **The AI is not a memory problem.**
3. **It is not, however, the whole of gameplay.** This document covers *what drives the characters*.
   It does not cover the frame loop, the collision system, `FrameAdv`, the tile renderer, or the
   sequence interpreter — those are `demo-move-graph.md`'s and P5.0's subject, and they are far
   larger than 1.2 KB.

### 5.2 — What is NOT needed for the demo, and why that is load-bearing

`AUTOCTRL` dispatches to five programs. **The demo reaches exactly one of them.** `MouseProg`,
`ShadowProg`, `SkelProg` and `VizierProg` are all level-specific (levels 4, 5, 6, 12, 13) and
`AUTO.S:220-448` — **229 lines** — is unreachable at level 0. A port that implements only
`KidProg`/`GuardProg` reproduces the demo exactly and defers a third of `AUTO.S`.
