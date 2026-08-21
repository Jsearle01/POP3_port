## Form B Report — P5.3 Phases 1-2 (RECON + PROPOSAL) — the demo is 91% gameplay AI, and screen 1 needs no rotating page at all

**Class:** Phase 1 recon, Phase 2 proposal (**no code**). `wip`.
**★★ THE STOP IS OBSERVED. Phase 3 has not begun. No file under `src/` was created, modified or
deleted.**

### 0 — Receipt / status (C-35 stamp)

t0 = **2026-08-21T22:14:42Z**. HEAD **`4160c7f`**, branch **`wip`**.

**`main` resolved here, not taken from the dispatch: `main` = `origin/main` = `32b5fe2`**, two
commits behind `wip` (P5.2's work and its hash stamp). **`main` was not moved.**

`git status` at receipt: one modified tracked file, `dist/mame-cfg/rgb/coco3.cfg`, plus the
**standing untracked set**, named in full: `.vscode/`, `nvram/`, `POP-idioms-coco3-markers.md`,
`content/intro/broderbund_splash_render.bin`, `docs/project/pop-coco3-design-v0_7.pdf`, and the
nineteen files under `docs/ground-truth/` (local-reference-only by standing Jay ruling). None was
touched.

**Prod byte-identity — identical at receipt and at the stop:**

```
d07f1f3295525783968dcce6409ee1b64942231c  build/intro_seq.bin
0b4968867bf5274d2942f3b5b90ea855ad6f2def  build/loader.bin
790836577e56b61b8f849cb309874e44304840a2  build/cutscene_room.bin
```

Nothing was rebuilt; no build input changed.

### 1 — Summary

**§1's four symbol resolutions all hold** — checked individually, and the Orchestrator's
self-correction is right. **Two of its figures do not:** `DemoProg1` is **25 pairs, not 29**, and
`AUTOPLAYBACK` is **81 lines / 50 instructions, not "roughly thirty"** — the ~30 describes the
cursor logic and omits the command dispatch, which is half the routine. Phase 1 delivers
`docs/project/demo-behaviour.md`, and its load-bearing finding is that **`KidProg` is `jmp
GuardProg`**: the demo's kid runs the *guard's* AI, differing only by `guardprog = 10` selecting a
different column of the fighter table. **The demo is 88 bytes of demo-only code and data against
~1,072 bytes of the game's own combat AI — 91% shared.** Building the demo is very nearly building
gameplay combat, and that is the arc's real size. Phase 2 proposes **extending** the cutscene's
bank machinery rather than replacing it, because the beat schedule enters at exactly **one** place —
who writes `cel_pg_block` and `cel_pg_sig` — and P5.2 established that "which page does this frame
need" is answerable before drawing. **And for Phase 3's actual scope the answer is smaller still:
screen 1's 19 tile cels are 3,424 B, which fits the 8,192-byte PINNED page with the tile table and
4,410 B to spare, so `cel_pg_sig = 0` and the rotating register goes unused.** That is a state the
existing guard already supports. **The whole demo LEVEL's blueprint-determined tile set — 7,202 B
across all 24 screens — also fits the pinned page**, which means tiles never rotate at level 0.

### 2 — Files modified

Explicit-path staging. **Nothing under `src/`, `content/`, `link/` or `build.bat`.**

- `docs/project/demo-behaviour.md` — **new**, the AC1 artifact.

### 3 — Reasoning

#### 3A — §1 checked, symbol by symbol (§7: "check them")

| §1's claim | verdict |
|---|---|
| `DemoProg1` at `SUBS.S:1194` | **HOLDS** — `DemoProg1 ;up to fight w/1st guard` |
| `AUTOPLAYBACK` at `AUTO.S:1149` | **HOLDS** |
| `AUTOCTRL` at `AUTO.S:160` | **HOLDS** |
| fighter params at `AUTO.S:99-115+` | **HOLDS** — the table runs to `:124`, and `AUTO.S:143-146` labels the columns *"10: kid (demo) / 11: enemy (demo)"* in the oracle's own words |
| `Press`/`Release` at `SUBS.S:1180-1191` | **HOLDS** — `Press = 6` at `:1190`, `Release = 7` at `:1191`. Also declared identically at `AUTO.S:1102-1103`; the equates live in **two** modules |
| `EndDemo` encoding | **HOLDS** — `EndDemo = -1` = `$FF`, and `AUTOPLAYBACK` tests `cmp #-1` |

**Two figures do not hold, and both are countable:**

1. ★ **`DemoProg1` is 25 pairs, not 29** — 50 bytes. Counted twice from the listing and transcribed
   entry by entry in the artifact §2.1. The `d1`/`d2`/`d3` equates make the list look longer than it
   is.
2. ★ **`AUTOPLAYBACK` is 81 lines / 50 instructions, not "roughly thirty."** The thirty covers
   `sta ProgStart` through `sty PreRecPtr`; the eight-case command dispatch and its `Do*` jumps are
   another fifty lines.

Neither changes §1's conclusion — everything *is* plaintext and was the whole time.

#### 3B — Phase 1: what the demo actually does (AC1)

**Authority: source. The full transcription is `docs/project/demo-behaviour.md`; this is what it
found.**

**★★★ THE DEMO HAS THREE PHASES, NOT ONE.** `DemoCtrl` [`CTRL.S:587`] branches twice:

| phase | condition | driver |
|---|---|---|
| 1 — the walk | `milestone == 0`, `CharSword == 0` | `AUTOPLAYBACK(DemoProg1)` — a recorded input script |
| 2 — the fight | `milestone == 0`, `CharSword != 0` | **`AutoCtrl` with `guardprog = 10`** |
| 3 — the exit | `milestone != 0` | `JSTKX = -1`; he runs off screen |

Phase 2 starts when the kid draws his sword — which the **ordinary `standing` controller** does on
its own when a guard is in range [`CTRL.S:1049-1090`]; nothing in the script asks for it. Phase 3
starts when the guard dies: **`DEADENEMY` [`SUBS.S:1699`]** — the enclosing routine, per *follow the
vector* — takes its `:demo` branch and sets `milestone = 1` where every other level would cue
`s_Vict`. Two exits, both to the attract loop: `EndDemo` → `jmp attractmode`, or `NextFrame`'s
level-0 check `lda KidScrn / cmp #24 / beq GOATTRACT`.

**The two `AUTOPLAYBACK` behaviours the dispatch asked to be named:**

1. **It REPEATS the previous command between timestamps.** `dey / lda (ProgStart),y` reads the
   command byte of the entry *before* the cursor. **The script is a list of CHANGES and the input is
   held between them** — which is how 25 entries drive 233 frames.
2. **`PlayCount` saturates at 254 by doing NOTHING.** `cmp #254 / bcs :rts` returns *before* the
   increment and *before* the dispatch, so at the ceiling it issues no command at all rather than
   holding the last one.

**★ Does 233 plus the saturation leave any interaction? NONE.** The script ends at `PlayCount 233`
with `EndDemo`, 21 frames below the ceiling, and the terminator jumps to `attractmode` rather than
returning. **The saturation is unreachable on this program** — though not dead in general:
`ShadProg5` (level 5's thief) ends at frame 255, *above* the ceiling, so there the saturation is
what stops the sequence. *`AUTOPLAYBACK` is therefore shared code, not demo-only.*

★ **A corroboration.** 233 game frames at the 9.5 game-fps measured at P5.2 is **≈ 24.5 s**, and
P5.1/P5.2 observed the demo running ~1,400 display frames ≈ **23 s** before the attract loop
restarted. Two independent routes, one length.

**`AUTOCTRL` [`AUTO.S:160`] — 38 lines, 31 instructions, a pure dispatcher on `CharID`.** It
decrements `justblocked`, `gdtimer` and `refract` first — **but not for the kid**, whose `beq :5`
comes before them. And then:

> **★★★ `KidProg` IS `jmp GuardProg`.** Two instructions [`AUTO.S:449`]. **There is no separate
> kid-fighter AI.** The demo's kid *is* a guard; the only difference is `guardprog = 10`.

**Columns 10 and 11 of the fighter table** [`AUTO.S:99-124`], which is 8 rows × 12 columns (its own
comment block documents only five of the eight — `impblockprob`, `specialcolor` and `extrastrength`
are undocumented there):

| | `strikeprob` | `restrikeprob` | `blockprob` | `impblockprob` | `advprob` | `refractimer` | `specialcolor` | `extrastrength` |
|---|---|---|---|---|---|---|---|---|
| **10 — kid** | 40 | **255** | **255** | **255** | 100 | 0 | 0 | 0 |
| **11 — enemy** | 60 | 150 | **255** | 175 | 100 | 0 | 1 | 0 |

Read as behaviour: **the demo kid never fails to block and always re-strikes after blocking, but
opens only ~16% of the time.** The enemy blocks perfectly too but re-strikes less and opens
slightly more. **Neither has a refractory period.** It is tuned to look like a duel and to end with
the kid winning.

#### 3C — Phase 1: the port-side implementation list (AC2)

**415 instructions of `AUTO.S`, plus 50 bytes of `DemoProg1` and 96 bytes of parameter table.**
Instruction counts are measured by line span (spans in the artifact so they can be recounted).
**★ The byte column is an ESTIMATE at 2.5 bytes per 6809 instruction and is labelled as one** —
the instruction column is the fact.

| piece | insns | est. B | shared or demo-only |
|---|---|---|---|
| `DemoProg1` data | — | 50 | **DEMO-ONLY** |
| `DemoCtrl`'s three-way branch | ~15 | ~38 | **DEMO-ONLY** |
| fighter parameter table | — | 96 | shared |
| `AUTOPLAYBACK` + dispatch | 50 | ~125 | shared (level 5) |
| `AUTOCTRL` dispatcher | 31 | ~78 | shared |
| `KidProg` + `GuardProg` | 8 | ~20 | shared |
| `Alert` | 31 | ~78 | shared |
| `EnGarde` | 85 | ~213 | shared |
| `FollowKid` / `InRange` / `GenFight` | 70 | ~175 | shared |
| `Maybe{Advance,Block,Strike}` | 48 | ~120 | shared |
| `Do*` primitives + `rndp` | 61 | ~153 | shared |
| `CHECKSTRIKE` | 15 | ~38 | shared |
| **TOTAL** | **415** | **~1,184** | **1,072 shared / 88 demo-only** |

**★★★ THE ARC'S SIZING, AS A FIGURE: the demo is 88 bytes of demo-only code and data. 91% of what
it needs is the game's own combat AI.** Building the demo is very nearly building gameplay combat.

Two things that follow:

- **~1.2 KB is nothing against the memory budget.** `demo-memory-map.md §3` gives 25,697 B free
  below the draw window at `Demo` entry, largest run 20,072 B. **The AI is not a memory problem.**
- **The AI writes the same joystick latches a human does** — `JSTKX`, `btn`, `clrF`/`clrB`/`clrU`/
  `clrD`, `clrbtn` — and `GENCTRL` reads them unchanged. **The demo needs no separate control path**,
  only a writer for the latches.

And **229 lines of `AUTO.S` are unreachable at level 0**: `MouseProg`, `ShadowProg`, `SkelProg` and
`VizierProg` are all level-4/5/6/12/13 specific. A port implementing only `KidProg`/`GuardProg`
reproduces the demo exactly and defers a third of the file.

#### 3D — Phase 2: the cel-bank path (AC3). **PROPOSAL ONLY — NO CODE WAS WRITTEN.**

**First, the P5.2 constraint set, re-verified rather than carried** (§7 asked):

| figure | status |
|---|---|
| one frame ≤ **3,700 B**, ≤ **4,999 B** across a room change | measured at P5.2 over 264 game frames; 0 of 264 exceeded either bound |
| pinned `$FFA6` = **8,192 B**, rotating `$FFA7` = **7,680 B** | `link/pop_cels_res.link`, `link/pop_cels_pg.link` — the 7,680 is `$E000-$FDFF`, because MC3=1 holds `$FE00-$FEFF` constant and `$FF00+` is I/O |
| `cel_bank_map` = **48 cy**, and it **must** run after every `HAL_gfx_swap` | decoded from `build/assets/scene_prog.raw` at `$2922`. **Re-checked here at the source:** `gfx_map_blocks` [`gfx.s`] is `ldx #$FFA4 / ldb #4 / loop: sta ,x+ / inca / decb / bne` — **four registers, unconditionally, masked.** Confirmed. |

##### The question: reuse, extend, or fresh?

**EXTEND. The beat schedule enters at exactly ONE place.**

Walking the machinery and asking of each part *"does this know about beats?"*:

| part | beat-shaped? |
|---|---|
| `cel_bank_map` [`cutscene_room.s:1246`] | **NO.** Reads `cel_res_block`/`cel_pg_block` and applies them. It re-applies a decision; it does not make one — its own comment says so. |
| `room_present` [`:1280`] | **NO.** Swap, then re-map. |
| the per-frame signature guard [`char_draw.s:443-465`] | **NO.** Compares `cel_pg_sig` against what is actually mapped. It checks that the window holds what was *asked for*, whatever asked. |
| `cel_load_startup` / `cel_service_read` | **NO.** Track reads into a page. |
| the page geometry + link scripts | **NO.** |
| **`vb_apply` [`char_draw.s:2196`]** | **YES.** `lda 1,u → cel_pg_block`, `ldd 2,u → cel_pg_sig`, where `U` is a **beat row**. |
| **`cel_pack.py`** | **YES.** Its whole algorithm takes a beat list and assigns pages so each beat's set is a subset of pinned ∪ its rotating page. |

> **So: `vb_apply`'s two stores and `cel_pack.py`'s input are the beat-shaped parts. Everything
> downstream of those two stores is schedule-agnostic and transfers unchanged.**

**Is the difference fatal? No — incidental, and P5.2 is why.** The draw set is fully determined by
the end of `NextFrame`, so *"which page does this frame need"* is answerable before any drawing.
The substitution is: **replace the table lookup in `vb_apply` with a per-frame computation over the
already-built image lists, writing the same two variables.** The 48-cycle re-map, the guard, the
refuse-to-draw behaviour and the page format all stay exactly as they are.

**Routines that would have to change, named:**

1. **`vb_apply`** — or rather, a gameplay peer of it. `vb_apply` also does beat plays, scenery
   selection and song cueing; the gameplay version needs only its two page stores.
2. **`cel_pack.py`** — a different assignment input (per-screen or per-move-group instead of
   per-beat). Its page-capacity checks, signature generation and track placement are reusable.
3. **Nothing else.**

##### ★ The worked co-location answer for screen 1 (the dispatch's real question)

*Fitting is a capacity fact; co-location is a packing decision.* Here is the packing, worked:

Screen 1's blueprint-determined set is **19 images, 3,424 B**, and here is every one of them:

```
$84 434  $0B 420  $07 420  $83 420  $45 354  $A2 343  $51 252  $04 105  $4B  91  $03  84
$05  84  $01  84  $06  72  $02  72  $1B  72  $85  54  $86  21  $15  21  $4C  21     = 3,424 B
```

**They can be co-located trivially, and not in the rotating page — in the PINNED one:**

| | bytes |
|---|---|
| page magic | 2 |
| tile pointer table (178 entries × 2, the whole dungeon set indexable) | 356 |
| screen 1's 19 cels | **3,424** |
| **total** | **3,782 of 8,192** — **4,410 B spare** |

**★★ So Phase 3 needs no rotating page at all: `cel_pg_sig = 0`, `$FFA7` unused.** That is not a new
state — it is the one the cutscene already uses for its song holds, and the guard already handles it:
*"0 = this beat draws only pinned cels, so no rotating page is owed"* [`char_draw.s:452-457`].
**The gated thing is therefore very small: one pinned page, one signature, zero rotations.**

**And it generalises further than screen 1.** P5.1 measured the **whole demo level's**
blueprint-determined tile set at **7,202 B across all 24 screens**; with the table and magic that is
**7,560 of 8,192 — it still fits the pinned page.** Tiles never rotate at level 0. Adding every
state-dependent image (gate bars, the 9 torch flames, slicer, loose floor, exit door, climb-up
masks, meters) takes it to **14,147 B**, which needs both pages — **14,505 of 15,872**, still no
rotation *within* a frame.

##### What I am deliberately NOT proposing

So the gate is on a bounded thing:

1. **No character paging scheme.** P5.1's W1 figure of 49,742 B for kid ∪ guard is untouched. This
   proposal covers **tiles only**, which is Phase 3's entire scope.
2. **No decision on recruiting blocks `$02`/`$03`/`$06`/`$07`.** Not needed for tiles.
3. **No change to `cel_pack.py`'s beat algorithm** — it is not used for this; a static page needs no
   scheduler.
4. **No claim that this scales past `LEVEL0`.** A palace-set level, or one whose tile set exceeds
   the pinned page, is a different problem.
5. **No page-ordered renderer**, and no mid-draw rotation of any kind.
6. **No HAL change.** `gfx_map_blocks` writing four registers when it owns two is what forces the
   48-cycle re-map; a two-register variant would remove it entirely, but that is a HAL change and a
   Karateka back-port under `§2G` — its own task, already filed at P5.2 §8.3.

### 4 — Verification (AC-by-AC)

- **AC1** — `docs/project/demo-behaviour.md` checked in: `DemoProg1` transcribed with all 25 entries
  and numeric command values; `AUTOPLAYBACK` described including the repeat and the saturation, with
  the "no interaction" answer; `AUTOCTRL` inventoried; fighter columns 10/11 extracted. §3B.
- **AC2** — §3C. 415 instructions, ~1,184 B estimated, **1,072 shared / 88 demo-only**, per routine.
- **AC3** — §3D. Reuse/extend/fresh answered **EXTEND** with the beat-shaped parts named
  (`vb_apply`, `cel_pack.py`) and the schedule-agnostic ones named; the P5.2 constraint set
  re-verified including a fresh source check of `gfx_map_blocks`; **screen 1's 3,424 B worked to a
  3,782-of-8,192 pinned-page answer with zero rotations**; six items left open.
- **AC4** — **THE STOP IS OBSERVED.** This report is filed; Phase 3 has not begun; no file under
  `src/` was created, modified or deleted.
- **AC5-AC7** — after the gate.
- **AC8** — §0. All three sha1s identical at receipt and at the stop.
- **AC9** — suites not run and **not required at the stop**: nothing was built and no build input
  changed, so the suites would re-report P5.2's result unchanged. **They will run at Phase 3, 128 KB
  first and 512 KB required**, as the dispatch specifies.
- **AC10** — §5.

### 5 — Reactive deviations and route accounting

**Deviations:**

1. **`main` resolved as `32b5fe2`**, per §0's instruction to resolve it rather than take it.
2. **Two of §1's figures corrected** (§3A) — 25 pairs not 29; 81 lines not ~30. The dispatch asked
   for §1 to be verified and this is what verification found.
3. **AC9 not exercised at the stop** — reasoned above rather than skipped silently.

**ROUTE ACCOUNTING.** No route was proposed in conversation before this task, and nothing was built,
so there is no plan-versus-artifact gap to account for. Within the task the only judgement worth
recording is the placement of `demo-behaviour.md` — see §6, flag 1: the dispatch directed
`docs/project/`, and I created it there and flagged the question rather than relocating it or
silently overriding the instruction.

**What this report contains:** AC1-AC4, AC8, AC10 in full.
**What it does not contain:** Phase 3, and any code whatsoever.

### 6 — Uncertainty flags

1. **★ `docs/project/` is where `CLAUDE.md §2D`'s Orchestrator-owned docs live, and §2D names
   "behavioral models" as one of the classes Clyde must not author.** `demo-behaviour.md` is a
   transcription of the oracle's data and an inventory of its routines — recon, the same class as
   `demo-memory-map.md` and `demo-move-graph.md`, both of which sit at the repo root. **The dispatch
   directed `docs/project/` and the file is there, labelled with its authorship class in its own
   header.** *Surfacing rather than deciding:* if the Orchestrator intends `docs/project/` to stay
   Orchestrator-owned, this file belongs at the root with its siblings, and moving it is one `git
   mv`. **Not a conflict I resolved silently, and not one that blocks the gate.**
2. **The byte estimates in §3C are estimates**, at 2.5 bytes per 6809 instruction. The instruction
   counts are measured; the byte column is an order of magnitude and should not be quoted as a
   measurement.
3. **The proposal is for TILES ONLY.** Characters — P5.1's 49,742 B at W1 — are untouched, and a
   pass on Phase 3 says nothing about them.
4. **`DemoProg1` covers phase 1 only**, by its own comment. Phases 2 and 3 are AI and a forced
   joystick; nothing in the recorded script describes them. A port that implemented only the script
   would produce a kid who walks to the guard and then stands still.
5. **`AUTOPLAYBACK` is shared, not demo-only** (level 5's thief), which slightly changes how §3C's
   split should be read: the 88 demo-only bytes are `DemoProg1` plus `DemoCtrl`'s branch, and
   nothing else.
6. **Carried, untouched:** the build's path contamination; the `.gitattributes` residual; the HAL
   audit items; the palette's two homes; the mislabelled 58,026 cy figure; `chtable7`/`chtable2`;
   the 4 unexplained w/h mismatches from P5.2 §7.1.

### 7 — Follow-up candidates

1. **The gate itself** — Jay on the §3D proposal. It is deliberately small: one pinned page, one
   signature, zero rotations.
2. **The placement question** for `demo-behaviour.md` (§6 flag 1).
3. **`gfx_map_blocks` writes four registers when it owns two** — a two-register variant removes
   `cel_bank_map` from the frame entirely. HAL change, Karateka back-port, its own task.
4. **The 229 unreachable lines of `AUTO.S`** are a real deferral, worth stating in whatever plan
   sizes the combat work: `MouseProg`/`ShadowProg`/`SkelProg`/`VizierProg` are levels 4/5/6/12/13.
5. **`impblockprob`, `specialcolor`, `extrastrength`** are undocumented in the fighter table's own
   comment block. Their consumers were not traced; if combat behaviour ever diverges, they are the
   first place to look.

### 8 — User interaction during task

None.

### 9 — Candidate(s) captured this task

`seeds/POP/live/2026-08-21-size-the-unique-surface-not-the-code-the-feature-touches.md` —
committed and pushed to the pool (fire-and-forget). *`KidProg` is `jmp GuardProg`: the demo's
unique surface is 88 bytes of 1,184, and 'build the demo' and 'build gameplay combat' are the
same task with 88 bytes of difference.*

### 10 — Commit

**`b420ceb`** — the artifact and this report, pushed to `origin/wip`; this hash stamp follows it on
the same branch. **`main` was NOT moved and stands at `32b5fe2`.** No `src/` file exists in either
commit.

---

## ★★ AWAITING JAY'S VERDICT ON §3D BEFORE PHASE 3 BEGINS.
