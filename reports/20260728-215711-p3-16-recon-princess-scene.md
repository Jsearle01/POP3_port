## Form B Report — P3.16 (RECON) — the princess cutscene, and the engine behind it
**Class:** RECON ONLY. **No build.** POP `wip`. **Karateka UNTOUCHED** (read-only).
**25.3: N/A — nothing built.**

### 0 — Receipt / status (C-35 stamp)
t0=2026-07-28T21:57:11Z (POP HEAD `782d6c7`, wip; tracked tree clean bar the standing
untracked PNGs/PDFs). Karateka: `main` `5eb92b1`, `wip` `56a02e4`, read only.

**Dispatch discrepancy, not a hard-stop.** The dispatch cites "§2H" of CLAUDE.md for
the no-heredoc rule. **There is no §2H in the in-repo CLAUDE.md** (§2 runs 2, 2A–2G).
It is a forward reference to something not yet folded in — presumably from P3.15. I
followed the instruction regardless: every file here was written with the Write tool.
Flagged for the Orchestrator rather than stopped on, because nothing in-repo
contradicts it.

---

### 1 — Summary

**The dispatch's central premise about the scene's driver is wrong, and the truth is
better.** `VizierProg` is not the cutscene script — it is a `brk` stub under
`do DemoDisk`, and in the full build it is the vizier's *gameplay* AI hook, sibling to
`ShadowProg`. The cutscene is `PlayCut0`, reached via `PrincessScene → cutprincess1 →
xplaycut`, and it is **a straight-line script over the game's own animation engine**.

That matters enormously for scoping: **the cutscene is not a special subsystem.** It
is nine calls to `play` interleaved with sequence changes. Build the animation engine
and the cutscene is a data file. Which also means: **reconning this scene is reconning
the engine**, exactly as the dispatch supposed — just through a different door.

The engine's design is small, clean and CPU-independent: a **bytecode VM** where
positive bytes are cel numbers and negative bytes are opcodes (`chx`, `chy`,
`aboutface`, `goto`, `act`, `setfall`), driving a two-phase frame loop
(`NextFrame` decides, `FrameAdv` draws). It ports directly.

**The compiled-sprite pipeline is in better shape than "dormant" implies.** Both
regression tests pass, and on the fitness question it is not merely adequate — it was
**built for exactly this engine's draw model**: it emits `_draw_`/`_save_`/`_erase_`
per cel because *POP peels*, and it is already **4-colour**, which is the mode the
cutscene switches to. The real gap is sub-byte horizontal positioning (§2A).

---

### 2 — Files modified

None. Recon only. This report.

---

### 3 — Reasoning

#### 3A — DELIVERABLE 1: the assets, and residency

**Karateka's model — RESIDENT, confirmed.** Jay's hypothesis is right and the evidence
is unambiguous: cels are `include`d as assembly source into the binary
(`intro_scenes.s: include "../../content/font/glyph_a/converted.s"`, ×281 cel files),
and **there is no disk read anywhere under `src/engine/`** — `grep -rln "disk_read"`
returns nothing. Nothing streams. The whole of Karateka is 17,978 bytes of binary with
its art inside it.

That is the model the animation has to run at speed, and it is affordable here for a
reason worth noting: Karateka's 281 cels are 367,613 bytes of *source* but a very
small binary, because the cels are small and heavily keyed.

**POP's scene needs (from `SEQTABLE.S`, the sequences `PlayCut0` actually uses):**

| character | sequences | cel numbers seen |
|---|---|---|
| vizier | `Vapproach`, `Vwalk`, `Vstop`, `Vraise`, `Vexit` | 48–85 |
| princess | `Pstand`, `Palert`, `Pback`, `Pslump` | 2–17 |
| torch flame | `ptorchflame` table | 18 entries, 9 distinct |
| hourglass | `GlassState` 0/1 + `psandcount` | not a cel sequence — see §3D |

Roughly **38 vizier cels + ~16 princess cels + 9 flame frames**, plus throne and
static scenery. The exact per-cel byte cost is not knowable until they are converted
(it depends on keying), so **the residency budget is a real open number**, not one I
can quote — flagged in §7. What is knowable: the model is resident, the engine must
therefore read cels from memory, and this lands directly on the 128 KB budget and the
banking work.

#### 3B — DELIVERABLE 2: the animation engine (POP is the authority)

**The frame loop** (`SUBS.S play`), which is the whole engine in fourteen lines:

```asm
play    sta SceneCount          ; run N frames
playloop
        jsr rnd                 ; RNG advance (the flicker draws on this)
        lda SPEED
        jsr pause               ; pacing — NOT VBL-locked, a delay
        jsr strobe              ; input; a keypress ends the scene
        jsr NextFrame           ; decide what the next frame looks like
        jsr flashon             ;   \
        jsr FrameAdv            ;    > draw to the hidden page and show it
        jsr flashoff            ;   /
        ... sound ...
        dec SceneCount
        bne playloop
```

Two things to port carefully:

1. **Decide/draw separation.** `NextFrame` advances every character's state;
   `FrameAdv` renders. They are distinct passes, and the flash brackets only the
   draw. This is a better structure than a fused update-and-draw and should survive
   the port unchanged.
2. **Pacing is a delay, not a VBL wait.** `SPEED` is 7 or 12 within this one scene
   (`sta SPEED` four times in `PlayCut0`). Our CoCo3 substrate is VBL-synced
   (`HAL_time_vbl_wait`), so **SPEED must be re-expressed as a frame count**, and the
   conversion needs the wall-clock value of `pause` — see §7.

**The sequence VM** (`SEQTABLE.S`) — the design to port, and it is tiny. A sequence is
a byte stream; **positive bytes are cel numbers, negative bytes are opcodes**:

```
goto = -1   aboutface = -2   chx = -5   chy = -6   act = -7   setfall = -8
```

```asm
Vwalk   db chx,1
Vwalk1  db 48,chx,2
Vwalk2  db 49,chx,6
        db 50,chx,1
        db 51,chx,-1
        db 52,chx,1
        db 53,chx,1
        db goto
        dw Vwalk1
```

**Animation and movement are the same stream.** Six cels and their per-frame X deltas
(+2, +6, +1, −1, +1, +1 — net +10 px per cycle) interleaved, looping via `goto`. The
walk's speed is not a parameter anywhere; it is emergent from the data. `Vexit` shows
the rest of the vocabulary — `77..82` (lower arms), `54` ×6 (standing), `57..66` with
deltas, then `aboutface`, `chx,16`, and `goto Vwalk2` to walk off.

**This is a ~100-byte interpreter on the 6809** and it is the single highest-value
thing to port faithfully. It is also completely CPU-independent, which is why the
6502 origin costs us nothing here.

**Karateka, reconciled (a glance, per §2G).** Its per-frame loop is
`timer_framesync.s` → `HAL_time_vbl_wait` + `HAL_gfx_present` page flip — that is the
CoCo3 machine-mechanics half and it transfers. Its *architecture* has no sequence VM:
`princess_controller.s` is hand-written per-character control flow. **POP's structure
is better and should win**, exactly as the dispatch says. Karateka's contribution here
is the VBL/page-flip plumbing we already reuse, and nothing above it.

#### 3C — DELIVERABLE 2A: the draw architecture, and the pipeline verified

**(a) Regression — does it still work? YES.**

```
compiled   [run_compiled_test] PASS
cel        [run_cel_test] PASS
```

(`sprite_tool/test_milestones.py` from the dispatch does not exist in POP — no
`sprite_tool/` directory here. Noted, not chased.)

**(b) Fitness — does it work the way the engine needs?** Better than expected, because
the compiler was written against POP's oracle draw model rather than invented:

| requirement | status | evidence |
|---|---|---|
| stack-blasting | **yes** | `PSHU D,X,Y` 6-byte bursts, 11 cy/6 B, byte order verified on hardware by `pshu_probe.s` |
| masking / compositing over live scenery | **yes** | keyed pixels + 16-bit RMW coalescing; `--bg-zero` (the fast overwrite path) is **off by default** precisely because *POP peels* |
| peel / erase model | **yes** | emits `_draw_`, `_save_`, `_erase_` per cel, over exactly the byte set the draw touches |
| **4-colour** | **yes** | `cel.w * 4` px per byte, `(b >> (6-2*k)) & 3` — 2 bpp. The cutscene's mode is already the compiler's mode |
| positioning | **byte granularity** | `U` is the framebuffer cursor in all three routines; the caller sets it |
| movement | **yes** | per-frame repositioning is just a different `U`, with save/erase around it |
| frame-data integration | **NO** | one routine per cel, no cel-id → routine-address table. Scoped work |
| **sub-byte horizontal** | **NO — the real gap** | see below |

**The gap that matters: sub-byte positioning.** `U` positions at byte granularity,
which in 4-colour is **4 pixels**. The sequence data moves characters by `chx,1` and
`chx,-1` — one pixel. PA.6a already established that the original draws sub-byte and
that byte-alignment is a visible change. The intro's HAL solves this with a 4-phase
shifter, but a *compiled* sprite cannot shift at run time without giving up the reason
it is fast. The options are pre-compiling 4 phase variants per cel (4× the code, and
38 vizier cels makes that a real number), or shifting the source data at conversion
time into 4 variants. **This is the largest single unknown in the build and it wants
its own measurement before anyone commits to compiled sprites for characters.**

#### 3D — DELIVERABLE 3: the timing, exactly

`PlayCut0` is deterministic — a fixed frame count between fixed sequence changes. From
`SUBS.S:658`, in order:

| step | frames | SPEED | note |
|---|---|---|---|
| `startV0` + `startP0` | — | — | starting positions |
| `play` | 2 | | |
| song `s_Princess` | | | |
| `play` | 5 | | |
| `Palert` → `play` | 9 | | princess hears something |
| song `s_Squeek` | | | door squeaks |
| | | **7** | |
| `play` | 5 | 7 | |
| `Vapproach` → `play` | 6 | 7 | |
| `Vstop` → `play` | 4 | 7 | **vizier enters** |
| song `s_Vizier`, `play` | 4 | 7 | |
| `Vapproach` → `play` | **30** | 7 | the long walk in |
| `Vstop` → `play` | 4 | 7 | **stops in front of the princess** |
| song `s_Buildup` | | | |
| `Vraise` → `play` | 1 | 7 | **raises arms** |
| `Pback` → `play` | 13 | 7 | princess steps back |
| `addglass1(0)` | — | | **hourglass appears** |
| `lightning=5`, `lightcolor=$FF` | — | | **THE FLASH — 5 frames, white** |
| | | **12** | |
| `play` | 5 | 12 | |
| `psandcount=0`, song `s_Magic` | — | | sand starts flowing |
| | | **7** | |
| `Vexit` → `play` | 17 | 7 | lower arms, **turn**, walk off |
| `addglass1(1)`, `play` | 12 | 7 | glass starts to fill |
| `Pslump` → `play` | 28 | 7 | |
| | | **12** | |
| song `s_StTimer` | | | ends |

**145 engine frames total.** Jay's white flash is **source-confirmed and named**:
`lightning` is a 5-frame countdown and `lightcolor` is `$FF`; `flashon`/`flashoff`
bracket `FrameAdv`, so it is a whole-screen colour override around the draw,
decremented once per frame.

**One correction to the scene description:** the vizier does not *drop* the hourglass.
`addglass1` makes it **appear**, with the lightning flash — it materialises. There is
no falling animation, and `GlassState` 0→1 later means "starts to fill", not a
physical event.

**What I could not derive: wall-clock.** `pause SPEED` is a delay whose real duration I
have not measured, so SPEED 7 vs 12 is a ratio, not milliseconds. Converting 145 engine
frames into CoCo3 VBL frames needs that number. §7.

#### 3E — DELIVERABLE 4: the torches (and the stars)

`FRAMEADV.S drawtorchb` → `setupflame` → the background draw list (`addback`), per
torch, every frame. The princess's room has **its own flame table** (`GAMEBG.S:150`):

```asm
torchflame   hex 52,53,54,55,56,61,62,63,64,52,54,56     ; 12 — dungeon
ptorchflame  db  1,2,3,4,5,6,7,8,9,3,5,7,1,4,9,2,8,6     ; 18 — PRINCESS'S ROOM
```

18 entries over 9 distinct frames — 1–9 in order, then a scrambled tail. **A designed
flicker pattern, not randomness**, indexed by the block's own state (`spreced`), drawn
opaque (`OPACITY = sta`) via `PSETUPFLAME` using `chtable6`.

So the ambient animation is **not a second mechanism**: torches are background blocks
whose state advances and which are redrawn from the block list each frame, entirely
independent of the character VM. That is a clean separation to keep.

**Also in this room, unmentioned in the dispatch:** `TWINKLE` — stars outside the
princess's window, 4 of them, updated *directly on both screens*. A third animation
category (neither character VM nor block list). Whether the scene needs it is Jay's
call; it is cheap and it is part of the room.

---

### 4 — Verification (AC-by-AC)

- **AC1 — assets enumerated + residency.** §3A. Karateka resident, confirmed by
  `include` of 281 `converted.s` files and the absence of any `disk_read` in
  `src/engine/`. POP's scene sequences and cel ranges enumerated. **Byte cost not
  quoted** — it is not knowable pre-conversion (§7).
- **AC2 — engine characterized from POP.** §3B: the `play` loop, the decide/draw
  split, and the sequence VM with its opcode set. Karateka consulted only for VBL/page
  flip and explicitly not adopted architecturally.
- **AC2A — draw architecture + pipeline verified.** §3C: both regressions PASS;
  fitness assessed against seven engine requirements with evidence per row; two gaps
  scoped (no cel-id table; **sub-byte positioning**).
- **AC3 — timing captured.** §3D, from the deterministic script: 145 frames, every
  beat, the 5-frame white flash, both SPEED changes. **Derived from source, not from a
  frame-by-frame capture** — see §6.
- **AC4 — torches characterized.** §3E: 18-entry designed pattern, block-state driven,
  independent of the character VM.
- **AC5 — scoping synthesis.** §5 below.
- **AC6 — NO BUILD.** No `src/` change; `git status` clean bar this report and the
  standing untracked files.
- **AC7 — both sources cited**, Karateka read-only and unmodified.

---

### 5 — SCOPING SYNTHESIS

**Buildable pieces, in dependency order** (Jay's static-first instinct, which the
evidence supports):

| # | piece | depends on | source of truth | risk |
|---|---|---|---|---|
| A | 4-colour mode + palette + static room (throne, princess, torches placed) | — | Karateka palette to start; POP for layout | low |
| B | torch flicker loop | A | `ptorchflame` + block state | low — 18 bytes of data and a per-frame redraw |
| C | **the sequence VM** + cel table | A | `SEQTABLE.S` — port the interpreter | **medium; this is the engine** |
| D | compiled-sprite draw path for characters | C | POP pipeline + **sub-byte decision** | **HIGH — §3C's gap** |
| E | vizier walk-in / stop / raise (the scripted action) | C, D | `PlayCut0` + sequences | low once C+D land |
| F | hourglass appear + white flash | E | `lightning`/`lightcolor`, `GlassState` | low |
| G | `Vexit` turn + walk-off, `Pslump` | E | sequences | low |
| H | mode swap back to 16c + handoff to Prolog2 | all | existing beat machinery | low |

**Karateka provides:** the VBL-synced per-frame loop and page flip (already reused),
the 4-colour palette as a starting point, and the residency pattern. **Nothing
architectural.**

**POP-new:** the sequence VM, the cel-id table, the compiled-sprite character draw
path, the block-state ambient loop, the flash.

**Recommended order: A → B → C → D → E → F → G → H**, with A and B gated by Jay's eye
before C starts. A and B together produce a *static room with flickering torches*,
which is a real visual milestone and exercises the mode swap, the palette and the
block redraw without touching the engine.

**The decisions I would put to Jay before any build dispatch:**

1. **Sub-byte positioning (§3C).** The single biggest unknown. Pre-compiled phase
   variants multiply cel code by 4; byte-alignment is a visible infidelity PA.6a
   already measured. **This deserves its own measurement task before D is scoped.**
2. **How many dispatches.** A+B is one. C is one. D is one *and may need the
   measurement above first*. E–H is one. So **four or five**, not one.
3. **Whether `TWINKLE` (the stars) is in scope** (§3E).
4. **The wall-clock conversion for `SPEED`** (§7) — needed before timing can be called
   faithful.

---

### 6 — Reactive deviations

- **The dispatch's premise about `VizierProg` is wrong** (§1). I followed the evidence
  to `PlayCut0` rather than reporting the named symbol as the answer. This *helps* the
  scope: the cutscene is data over the engine, not a bespoke subsystem.
- **Timing was derived from source rather than a frame-by-frame capture.** The script
  is deterministic — exact frame counts between exact sequence changes — so source is
  *more* precise than a capture, not less. What a capture would add is the wall-clock
  value of `pause SPEED`, which source cannot give and which I have not measured. Given
  this is recon and the number is a single scalar, I have flagged it rather than spent
  a capture on it. If the Orchestrator wants it now, it is one instrumented run.
- **`sprite_tool/` does not exist in POP**; the dispatch's `test_milestones.py` could
  not be run. The two pipeline tests that do exist were run and pass.

---

### 7 — Uncertainty flags

- **The residency budget is an open number.** I can enumerate the cels but not their
  bytes until they are converted — keying dominates the cost and varies per cel. The
  128 KB question therefore stays open, and it is the one that could force banking.
- **Sub-byte positioning is unresolved and is the project's next real risk** (§3C).
- **`pause SPEED` has no measured wall-clock value**, so SPEED 7 vs 12 is a ratio only
  (§3D). Everything downstream that claims "faithful timing" depends on it.
- **`Vapproach` was not read** — I read `Vwalk`, `Vstop`, `Vraise`, `Vexit` and inferred
  `Vapproach` is the walk entry. It is 30 frames of the scene and should be read before
  building E.
- **The princess's `Pslump` frames were not enumerated** (I read `Pstand`, `Palert`,
  `Pback`).
- **Cel numbers are per alt-set.** `CTRLSUBS.S getaltframe2` — "Princess & Vizier use
  alt set 2" — was noted by the dispatch and I did **not** verify how alt sets index
  into the cel tables. That is a prerequisite for the cel-id table in piece C.
- **The 6502 `pause`/`rnd`/`strobe` calls have no CoCo3 equivalents yet**; the port's
  loop will be VBL-driven, which changes the shape of `play` even though the VM above
  it is unchanged.

---

### 8 — Follow-up candidates

1. **Measure `pause SPEED`** in wall-clock — one instrumented oracle run, unblocks all
   timing fidelity.
2. **Sub-byte positioning decision task** (§3C) — measure the cost of 4 phase variants
   against the visible cost of byte alignment, before scoping piece D.
3. **Read `Vapproach` and `Pslump`; verify alt-set-2 indexing** (§7).
4. **Build dispatch A+B** — 4c mode, palette, static room, torch flicker. The natural
   first milestone and the one that needs no engine.
5. Carried: prefetch (~6 s, unblocked); the constant-rate sweep vs the oracle's
   variable rate; mid-sweep guards for beat 5; the `FB_*_BLOCK` coupling; the 1.00 s
   inter-track disk gap; `anim_probe` spanning `$02DC`; keypress-to-start;
   `HAL_mem_size_detect`; `HAL_gfx_swap` clobbering X; `HAL_gfx_set_palette`; the
   banked-RAM block map; `build.bat` line endings; re-labelling P3.7–P3.9 gates as
   `static-png`; folding §2H into CLAUDE.md (§0).

---

### 9 — User interaction during task

The dispatch only. No interaction during execution.

---

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-07-28-a-named-symbol-in-a-plan-is-a-hypothesis-about-where-behaviour-lives.md`

---

### 11 — Commit

See below — pushed to `origin/wip` before this report was surfaced.
