## Form B Report — P5.2 (RECON) — one frame asks for 3,700 bytes of a 15,872-byte window, and it is knowable before the frame draws

**Class:** recon (Phases 1-2) + one measurement against built code (Phase 3). `wip`.
**Prod byte-identical** — no file under `src/`, `content/`, `link/` or `build.bat` was touched.

### 0 — Receipt / status (C-35 stamp)

t0 = **2026-08-21T03:05:13Z**, HEAD **`32b5fe2`**, branch **`wip`**.

`git status` at receipt: one modified tracked file, `dist/mame-cfg/rgb/coco3.cfg`, plus the
**standing untracked set**, named: `.vscode/`, `nvram/`, `POP-idioms-coco3-markers.md`,
`content/intro/broderbund_splash_render.bin`, `docs/project/pop-coco3-design-v0_7.pdf`, and
the nineteen files under `docs/ground-truth/` (local-reference-only by standing Jay ruling).
None was touched by this task.

Prod sha1, **at receipt and again at the end, identical**:

```
d07f1f3295525783968dcce6409ee1b64942231c  build/intro_seq.bin
0b4968867bf5274d2942f3b5b90ea855ad6f2def  build/loader.bin
790836577e56b61b8f849cb309874e44304840a2  build/cutscene_room.bin
```

★ **`main` is at `32b5fe2`, not `63326d4`.** The dispatch's figure is one commit behind: the
video work committed after P5.1's report (`4de681e`, `32b5fe2`) was fast-forwarded to `main`
the same way the report commits were. **`main` was not moved by this dispatch** — it is where
P5.1's last push left it.

### 1 — Summary

**One frame asks for at most 3,700 bytes of a 15,872-byte window, and 4,999 bytes if a room
change is bounded across the three bins it can straddle.** Median 1,005 B. **Zero of 264
measured game frames exceed even the 7,680-byte rotating half on its own.** The draw set is
**fully determined by the end of `NextFrame`** — every image selection is made there, nothing
inside `FrameAdv`/`DRAWALL` chooses one, and the two candidates that could have (`rnd` and the
torch phase counter) both live in `NextFrame`'s call chain. So a window arrangement can be
issued between the decision and the drawing, and §1's question dissolves as the dispatch
anticipated. The existing arrangement path costs **48 cycles** and its signature guard
**23-33**, together **0.27% of a 29,868-cycle video frame** — a budget confirmed by measuring
MAME's own refresh rather than carrying the project's figure. **§1's reasoning holds, with one
correction: what runs per frame is not a single `sta $FFA7` but `cel_bank_map`, which writes
BOTH window registers and masks interrupts to do it** — because `HAL_gfx_swap` destroys the
bank mapping on every flip. The conclusion is unaffected; the mechanism named in §1 is not the
one the built code runs.

### 2 — Files modified

New, explicit-path staged. Nothing under `src/`, `content/`, `link/` or `build.bat`.

- `harness/tools/oracle_frame_drawset.lua` — a write tap on `setimage`'s output, binned on
  the oracle's own frame boundary, logging every cel a frame is about to lay.
- `harness/tools/frame_drawset.py` — validates the log against the vendored tables and
  reports the distribution against the window.
- `harness/tools/cycle_count.py` — decodes a straight-line 6809 routine out of a **built**
  binary and sums documented cycle counts; refuses an opcode it does not know rather than
  skipping it.

### 3 — Reasoning

#### 3A — §1 checked, and the one thing in it that is wrong

**Authority: the tree. §5 says to treat §1 as a claim, so it was checked rather than assumed.**

**What holds.** `char_draw.s:2178` is verbatim as quoted, and its reasoning is sound: a
one-register store leaves a complete valid map at every instant. The window arithmetic holds
too — `gfx.s:403` puts the draw window at `$FFA4`, `char_draw.s:206` takes `$FFA6`/`$FFA7` for
the bank, and `link/pop_cels_pg.link` records why `$E000-$FDFF` is 7,680 and not 8,192
(MC3=1 holds `$FE00-$FEFF` constant, `$FF00+` is I/O). **15,872 B confirmed.** And the
recruited-configuration claim is arithmetically right: P5.1's W1 union is under 65,536, so
everything is resident and no disk read is involved.

**★★ WHAT IS WRONG, AND IT IS THE MECHANISM RATHER THAN THE CONCLUSION.** §1 says *"what
remains is a `sta $FFA7`"*. The built code re-maps **both** registers **every frame**:

```
room_present    jsr HAL_gfx_swap        cutscene_room.s:1280
                jsr cel_bank_map
cel_bank_map    pshs cc / orcc #$50     ...:1246 — INTERRUPTS MASKED
                lda cel_res_block / sta $FFA6
                lda cel_pg_block  / sta $FFA7
                puls cc / rts
```

and the file states why it cannot be otherwise: *"HAL_gfx_swap ends by calling
gfx_map_blocks, which writes ALL FOUR window registers unconditionally… every flip destroys
the bank mapping. There is no 'map it at startup' version of this design."* **The mask is
there for exactly the hazard `char_draw.s:2178` names as its own counterexample** — two
registers, an invalid state between them. §1 quoted the routine that has no hazard and
described the one that does.

It costs 48 cycles (§3D), so nothing downstream changes. Reporting it because the dispatch
asked for §1 to be checked and this is what checking it found.

#### 3B — Phase 1: the per-frame draw set (AC1)

**Authority: the running oracle.**

**The instrument.** Every draw goes through `setimage` [`HIRES.S:270`], which resolves an
image index to a cel address and stores it in `IMAGE`/`IMAGE+1` (`$04`/`$05`). A **write** tap
on `$05` therefore fires once per cel about to be laid and carries the address — and the
cel's own first two bytes are its width and height [`HIRES.S:180-186`], so the size is read at
the tap and no table has to be identified. Write taps, because on the 6502 a read tap
silently false-0s [`mame-idioms-apple2e-oracle.md §1`]; PA.6 counted cels the same way.

**★★★ THREE THINGS WENT WRONG BEFORE THE NUMBER WAS RIGHT, AND EACH IS WORTH THE RECORD.**

1. **`IMAGE` IS ALIASED.** `EQ.S:384-385`: `height = IMAGE` / `width = IMAGE+1`. `DRAWWIPE`
   [`GRAFIX.S:545`] writes a wipe's height and width through the same two bytes, and
   `LAYERSAVE`/`PEEL` write **peel-buffer** addresses (`$D000`/`$D800`) there. Read as cel
   pointers those produce plausible-looking cels: one frame "drew" **18,975 B out of
   chtable1 at `$D800`**, which is `peelbuf2`. **The filter is exact, not heuristic** — a
   record survives only if its address is one of that table's own pointer-list entries **and**
   the (w,h) read out of **live memory** equals the (w,h) in the **vendored file**. 2,443
   kept, 604 dropped, and **4 w/h mismatches on otherwise-valid pointers** (§7 flag 1).
2. **THE BIN WAS THE WRONG WIDTH — a 6× error.** Binning per 59.92 Hz display frame gave a
   maximum of **1,118 B** that excluded every room change, because POP animates at ~10 fps
   [PA.2] and one game frame spans about six display frames. *Measure the primitive at its
   real width.*
3. **TWO BOUNDARY CANDIDATES FAILED FIRST.** `PAGE` (`$00`), which `PAGEFLIP` [`SUBS.S:397`]
   writes once per game frame — but nine other sites write it too, and the run produced 5,973
   bins over 1,700 display frames. Then `FrameCount` (`$0306`) — and **`KEEPTIME`
   [`SPECIALK.S:1261`] opens `lda level / beq ]rts ;not in demo or during playback`. The demo
   is level 0, so the game's own frame counter never ticks in the mode being measured.**

**The boundary that works** is `ZEROLSTS`'s write to `genCLS` (`imlists` = `$AC00`): `DoFast`
and `DoSure` both open with `jsr zerolsts`, so one write = one frame's lists reset, and the
bin that follows holds that frame's list building *and* its `DRAWALL`. **It yields 266 bins
over 1,681 display frames — 9.5 game fps, which is PA.2's "POP animates at 10 fps" arrived at
independently.** That agreement is what makes the binning evidence rather than a choice.

**The result, over the demo's 266 game frames on `LEVEL0`** — distinct cels per frame, in
port-side packed 4-colour bytes (a cel drawn twice costs the window nothing extra):

| | bytes | cels |
|---|---|---|
| min (of drawing frames) | 268 | 3 |
| **median** | **1,005** | 8 |
| p90 | 2,002 | 18 |
| p99 | 3,439 | 24 |
| **MAX — frame 7930** | **3,700** | **25** |
| mean | 1,162 | |

**The worst frame is 25 tile cels and nothing else** — `FirstFrame`'s full composite of screen
1. `tile_working_set.py` independently put screen 1's blueprint-determined set at **3,424 B**;
the measured composite is 3,700 including the meters and the state-dependent pieces. Two
methods, one number.

**And the room-change bound.** `SURE` writes `genCLS` a second time, so a composite can
straddle bins; the maximum over **any three consecutive bins** bounds it without tuning a
threshold: **4,999 B at frame 8882** — 22 tile cels, both actors and a sword. **15 full-screen
composites are in the sample**, so room changes are represented rather than assumed.

By kind, per frame: tile median 254 B / max 3,700; kid 474 / 1,101; kid's sword 54 / 543;
opponent 546 / 847.

#### 3C — Phase 1 against the window (AC2)

| | bytes | vs the whole window 15,872 | vs the rotating half 7,680 alone |
|---|---|---|---|
| median | 1,005 | FITS, 14,867 spare | FITS, 6,675 spare |
| p99 | 3,439 | FITS, 12,433 spare | FITS, 4,241 spare |
| **max single bin** | **3,700** | **FITS, 12,172 spare** | **FITS, 3,980 spare** |
| **max over 3 bins (room change)** | **4,999** | **FITS, 10,873 spare** | **FITS, 2,681 spare** |

**Frames exceeding the whole window: 0 of 264. Frames exceeding the rotating half on its own:
0 of 264.**

★ **This is the negative result §5 asked for plainly, so plainly: one frame fits, with room to
spare, and it fits in HALF the window.** The demand does not force a page-ordered renderer.

**What this does NOT settle, and must not be read as settling:** that a frame's demand fits
7,680 B says nothing about whether a *packer* can put that particular frame's cels — tiles
from two tables plus both actors — into one page. **Fitting is a capacity fact; co-location is
a packing decision**, and packing is architecture, which §4 puts out of scope.

#### 3D — Phase 2: the draw set is complete at the end of `NextFrame` (AC3)

**Authority: source, and the answer is yes.**

`MainLoop` [`TOPCTRL.S:366`] is `rnd → strobe → demokeys → misctimers → NextFrame → flashon →
FrameAdv`. `NextFrame` [`TOPCTRL.S:503`] settles every input to the draw:

| call | what it decides |
|---|---|
| `animmobs`, `animtrans` | every mobile object's phase — **including the torch flame**, via `animtorch` [`MOVER.S:714,1063`] → `GETFLAMEFRAME`, which writes the blueprint `state` byte |
| `bonesrise`, `checkalert` | skeleton, `EnemyAlert` |
| **`DoKid`**, **`DoShad`** | each character's `CharPosn` — the frame number, through `ANIMCHAR` |
| `checkstrike`, `checkstab` | sword outcomes |
| `chgmeters` | the strength meters |
| `cutcheck` → **`PrepCut`** | whether this frame is a **room change** (`cutplan`) |

**No site inside the draw path selects an image.** Checked individually:

- **`rnd`** — every `jsr rnd` is in `MOVER.S` (inside `animmobs`/`animtrans`) or is `rndp` in
  `AUTO.S` (the guard AI, under control). **None in `FrameAdv`, `DoFast`, `fast` or `DRAWALL`.**
- **the torch phase** — advanced by `animtorch` under `ANIMTRANS`. `SETUPFLAME`
  [`GAMEBG.S:735`] is called from the draw (`drawtorchb`, `FRAMEADV.S:1505`) but only
  **reads** `spreced`, the state byte written earlier.
- **the meters** — `DRAWKIDMETER` reads `KidStrength`, settled by `chgmeters`.
- **`develpatch`** → `sure` on `redrawflg`: changes the **scope** of the redraw, not the
  choice of any image, and `redrawflg` is set outside the draw.

**★ THE ONE QUALIFICATION, AND IT IS A REAL ONE.** The image **lists** are *built* inside
`FrameAdv` — `DoFast` [`TOPCTRL.S:961`] runs `zerolsts / addmobs / addchars / fast / dispmsg`
before `drawall`. So the set is not sitting in a variable at the end of `NextFrame`; it is
**derivable** from state that is. The correct statement is: **every input to the selection is
settled before `FrameAdv` is entered, and the list building is pure computation over that
state, so it can be hoisted ahead of any drawing.** A port that builds its lists, arranges the
window, and only then draws is doing what the oracle does with the arrangement inserted at a
boundary that already exists.

**So §1's question dissolves, and for the reason §1 predicted:** the arrangement is a store
issued after the decision and before any drawing, not a swap that has to complete inside a
control decision.

#### 3E — Phase 3: what the arrangement actually costs (AC4, AC5)

**Measured by decoding the BUILT binary**, not counted off the source — `harness/tools/
cycle_count.py` walks the emitted bytes and sums documented 6809 counts, and refuses an
opcode it does not know rather than skipping it. On a 6809 every instruction here has one
data-independent cycle count; there is no cache, no pipeline, no variable-latency memory.

**`cel_bank_map`, from `build/assets/scene_prog.raw` at `$2922`:**

```
$2922  34 01           pshs cc       6
$2924  1A 50           orcc #$50     3
$2926  B6 FE 06        lda ext       5      cel_res_block
$2929  B7 FF A6        sta ext       5      -> $FFA6
$292C  B6 FE 02        lda ext       5      cel_pg_block
$292F  B7 FF A7        sta ext       5      -> $FFA7
$2932  35 01           puls cc       6
$2934  39              rts           5
                       body         40   +8 for the jsr = 48 cycles, ONCE PER FRAME
```

**The signature guard, from `build/assets/flames.raw` at `$3B43`** (`chars_frame`, after
`vm_nextframe`):

```
ldd $C000 (6) / cmpd #$C35A (5) / bne (3) / ldd $FE03 (6) / beq (3)     = 23 cy
   ... and when a rotating page is owed:  cmpd $E000 (7) / beq (3)      = 33 cy
```

matching the source's own *"~24 cy"* estimate. **Total per frame: 81 cycles worst case.**

**The budget, confirmed rather than carried.** MAME reports the coco3 screen refresh as
**59.9227 Hz** (measured, not assumed), and the port writes `$FFD9` for the 1.78 MHz clock
[`gfx.s:232,488`]. 14.31818 MHz ÷ 8 ÷ 59.9227 = **29,868 cycles per video frame** — the
project's 29,859 is the same figure at a 59.94 Hz refresh, 0.03% apart. **Confirmed.**

> **81 cy against 29,868 = 0.27% of a video frame.** Against the cutscene's animation step of
> 2.60 frames (77,150 cy, `cutscene_room.s:550`) it is **0.105%**.

★ **A documentation inconsistency found on the way, reported not fixed:** `char_draw.s:471`
measures the guard *"against a 58,026 cy budget"*, but `cutscene_room.s:550` gives the step
budget as **77,150** cy and the video frame as 29,673 net of the flip. 58,026 is ≈1.94 video
frames, which is the *measured work* figure at `char_draw.s:369` (1.92 VBLs), not a budget.
It changes nothing — 24 cy is negligible against any of the three — but the number is
mislabelled where it stands.

**AC5 — implied rotations per frame: NONE.** The worst frame demands 3,700 B and the worst
room change 4,999 B, both under the 7,680-byte rotating half by itself. **Nothing in the
measured distribution forces a mid-draw rotation**, so one arrangement per frame — the 48
cycles already being spent — is sufficient on capacity grounds. Whether a packing exists that
realises it is the architecture question, and this dispatch does not answer it.

**Hard stop observed.** No renderer, no architecture choice, no cel-bank change, no ranking of
P5.0's four options.

### 4 — Verification (AC-by-AC)

- **AC1** — §3B. Distribution min 268 / median 1,005 / p90 2,002 / p99 3,439 / **max 3,700 B
  at frame 7930**, worst frame named by content (25 tile cels, `FirstFrame`'s composite of
  screen 1), plus the 3-bin room-change bound of 4,999 B at frame 8882. Every figure states
  it is the set of **distinct cels a single GAME frame lays**, over the interval between two
  `zerolsts` calls.
- **AC2** — §3C. 0 of 264 frames exceed 15,872 B; 0 of 264 exceed the 7,680 rotating half.
- **AC3** — §3D. Complete at the end of `NextFrame`; `rnd`, the torch counter, the meters and
  `develpatch` each checked and named; the list-building qualification stated.
- **AC4** — §3E. `cel_bank_map` 48 cy, guard 23-33 cy, decoded from the built binaries,
  against a budget of **29,868 cy** confirmed from MAME's measured refresh.
- **AC5** — §3E. **None implied.**
- **AC6** — §5. 128 KB, both suites PASS. 512 KB not run: nothing here touches the MMU, the
  bank, the framebuffers or the loader — this dispatch wrote no engine code at all.
- **AC7** — §6.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim):**

```
$ bash harness/smoke/run_suites.sh
[suites] running: introseq integ
[suites] retired at P3.103 (see harness/smoke/retired.sh): probe cel compiled mode anim room walk
[suites] -ramsize 128K
[suites] === introseq ===   [run_introseq_test] PASS
[suites] === integ ===      [integ] PASS
[suites] ALL PASS

$ python harness/tools/frame_drawset.py
RECORD VALIDATION (see the header — IMAGE is aliased as height/width)
  kept      2443   address is in the table's pointer list AND live w/h == file w/h
  dropped    604   {'not a cel pointer in that table': 550, 'unknown table 2/$6001': 47, ...}
  w/h MISMATCH on a valid pointer: 4
  gameplay span            frames 7930..9584  (266 frames)
  min 268 / median 1005 / p90 2002 / p99 3439 / MAX 3700 B (25 cels) frame 7930
  MAX over any THREE consecutive bins (bounds a room change): 4999 B at frame 8882
    full-screen composites in the sample (>=15 tile cels): 15
  frames exceeding the whole window 15,872  0 of 264 (0.00%)
  frames exceeding the rotating half 7,680  0 of 264 (0.00%)

$ python harness/tools/cycle_count.py build/assets/scene_prog.raw 2600 2922
  TOTAL (body, excluding the JSR to it)      40 cycles
  with `jsr` extended (8 cy)                 48 cycles

$ (MAME, coco3)  screen refresh (Hz) = 59.922747589565
   14.31818 MHz / 8 / 59.9227 = 29,868.0 cy per video frame
```

**25.2 bundled-artifact grep:** N/A — no bundled artifact and no sibling import; nothing under
`src/` or `content/` changed.

**25.3 operator-runtime-smoke:** **N/A for this dispatch.** No engine code, no visual change,
no new artifact for Jay to look at. P5.0's static-background gate remains open and this
dispatch does not advance it.

### 6 — Reactive deviations and route accounting

**Deviations:**

1. **`main` is `32b5fe2`, not `63326d4`** (§0). Reported; not moved.
2. **The binning boundary was chosen after two failed candidates**, and the first cut of the
   instrument produced a 6×-low maximum (§3B). Both failures are recorded in the tool's header
   so the next reader does not re-try them.
3. **§1's mechanism was corrected** (§3A) — the dispatch asked for §1 to be checked, and
   checking it found the per-frame path writes two registers under an interrupt mask, not one
   register bare. The conclusion is unaffected.

**ROUTE ACCOUNTING.** No route was proposed in conversation before this task. Within it, one
plan changed and is recorded rather than quietly replaced: the draw set was first binned per
**display** frame, which under-reported the maximum by 6× and excluded every room change; the
bin was re-derived from the oracle's own `zerolsts` boundary and the run repeated. An
intermediate ad-hoc check also briefly reported 30,918-byte frames — that was my own analysis
skipping the address-validity half of the filter, caught by disagreement with the tool that
applies it, and it is the reason the strict filter is described at length in §3B rather than
assumed.

**What this commit contains:** AC1-AC7 in full.
**What it does not contain:** no renderer, no architecture choice, no cel-bank change, no
ranking of P5.0's four options, no engine code — all out of scope by §4, and the Phase 3 hard
stop was observed.

### 7 — Uncertainty flags

1. **4 records had a valid cel pointer but a live (w,h) disagreeing with the vendored file.**
   0.16% of 2,447. They are dropped, so they cannot inflate anything, but they are unexplained
   — most likely the tap catching `setimage`'s two stores mid-update on a frame boundary. If
   the figure ever grows, it would mean the live tables are not the vendored ones, which would
   invalidate more than this dispatch.
2. **604 records dropped**, including 54 whose `TABLE` read off a page boundary
   (`2/$6001`, `2/$6003`). Checked: **none** becomes valid when `TABLE` is snapped to its
   page, so they are artefacts and not lost cels.
3. **The sample is one demo run of one level.** 266 game frames, 15 full-screen composites,
   screens 1/2/4. A different level with denser rooms would move the tile figure; the
   character figures are bounded by P5.1's per-actor sets and cannot.
4. **"Fits in 7,680 B" is a capacity fact, not a packing one** (§3C). The architecture
   question is whether a packer can co-locate a frame's cels, and it is untouched here.
5. **`char_draw.s:471`'s "58,026 cy budget"** is mislabelled (§3E). Reported, not edited.
6. **The list-building qualification** (§3D): the set is derivable at the end of `NextFrame`,
   not materialised there.
7. **Carried, untouched:** the build's path contamination; the `.gitattributes` residual;
   `DemoProg1`'s format; `AutoCtrl`'s combat logic; the HAL audit items; the palette's two
   homes; the `chtable7`/`chtable2` extent contradiction; `s_Princess`; the stale `pop.link`
   stack comment.

### 8 — Follow-up candidates

1. **The architecture ruling is now unblocked on this axis** — Jay's, with the fact it was
   waiting on: a frame asks for ≤4,999 B of a 15,872-byte window, the set is knowable before
   drawing, and the arrangement costs 0.27% of a frame.
2. **The packing question** is what remains: can a page assignment keep each frame's cels
   within the two mapped pages? The per-frame logs (`build/tmp/frame_drawset.txt`) are the
   input a packer would be evaluated against.
3. **`HAL_gfx_swap` writes all four window registers unconditionally**, which is what forces
   the per-frame re-map. A swap that wrote only the two it owns would remove `cel_bank_map`
   from the frame entirely — a HAL change and a Karateka back-port under §2G, so its own task.
4. **Correct `char_draw.s:471`'s budget figure** when that file is next touched.
5. **The `IMAGE` aliasing** (`height`/`width`/peel-buffer addresses through `$04`/`$05`) is
   worth carrying into the apple2e idioms file if another dispatch taps zero page.

### 9 — User interaction during task

None.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-20-the-bin-width-is-part-of-the-measurement-and-must-come-from-the-system.md`
— committed and pushed to the pool (fire-and-forget). *The bin boundary is part of the
measurement: a clock-derived bin split one game frame across six display frames and
under-reported the peak by 6×, and the boundary that worked was the one the system draws for
its own reasons.*

### 11 — Commit

See the commit that carries this report, pushed to `origin/wip` before reporting. **`main` was
not moved.**
