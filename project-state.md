# project-state.md — POP → CoCo3 build-phase state

**READ THIS FIRST at the start of every build session**, before CLAUDE.md's task-specific
context. Clyde is stateless across sessions; this file is what makes the build coherent
anyway. It records what is *built*, what is *verified*, what the standards are, and what
comes next.

**Authorship:** Clyde-authored operational state. This is **not** an authored-authoritative
doc under `CLAUDE.md §2D` (no decision records, post-mortems, or behavioural models here —
those stay Orchestrator-owned). Clyde updates this file directly as build state changes.

**Last updated:** 2026-08-20 (P5.1 — brought current after a 25-day gap; see §2)
**Phase:** BUILD. The intro and the princess cutscene are BUILT AND JAY-GATED and are on
`main`; the DEMO/gameplay arc opened at P5.0. The feasibility investigation is CLOSED (§1).

> **★ THIS FILE HAD GONE 25 DAYS AND ~130 REPORTS STALE.** It said *"Engine: nothing built
> yet"* through the whole of the P3 intro/cutscene arc and the P4 sound arc. It is the file
> the standing rules say to read first, so a stale one is worse than none. **It records
> ACTUAL EXECUTION STATUS, not specification status** — if something is written but not run
> and gated, it says so.

---

## 1. Where the project stands

The feasibility arc (PA.1–PA.12) is **closed**. The port is **FEASIBLE**, with these
findings now standing as build constraints rather than open questions:

| # | Finding | Consequence for the build |
|---|---|---|
| PA.2 | Budget denominator is **178,968 cyc/game-step** (POP animates at 10 fps), not 29,859 | Cost everything per *step*, not per VBL |
| PA.5 | POP is **compute-bound**; median idle is zero; blit is 55–63% | The blit is the thing to optimise; AI is not (COLL 1.23%, CTRL 0.21%) |
| PA.6 | Runtime masked-loop blitting is **INFEASIBLE** (`gfx.s`'s header estimate was 5.4× understated) | Do not build a runtime masked blitter |
| PA.7/PA.9 | **Compiled sprites** are ~16× cheaper; POP's real art is 68.9% mixed-class | ★ **SUPERSEDED at P3.54.** True on CYCLES and fatal on RAM: 8.2× the bytes of packed bitmaps, which is what put the cutscene outside 128 KB. The rendering strategy is **segment streams** |
| PA.8 | 16-colour mode is **excluded on memory alone** | **Mode = 320×192×4 (2bpp)**, `$FF98=$80`, `$FF99=$15` |
| PA.11 | `k` is **not a constant** — 1.23 transliterated vs 0.35 idiomatic; they straddle the p90 gate | **The idiomatic-6809 standard below is a hard requirement, not a preference** |
| PA.12 | Sound fits (0.57–0.83× at p90); effects map 1:1 from POP's `tone()` | ★ **CLOSED.** The music engine was absent from the source and was reverse-engineered off the oracle image (P4.16–P4.19); `msys_player.s` plays it |

**The single most important number:** at the p90 frame, a transliterated port lands at
**1.21× budget (INFEASIBLE)** and an idiomatic one at **0.46× (FEASIBLE, 54% headroom)**.
Feasibility is a translation choice. That is why §3 is a standard and not advice.

---

## 2. What is built and verified

| Artifact | Path | State |
|---|---|---|
| Build script | `build.bat` | **WORKING** — lwasm → DECB `.bin` → imgtool `.dsk` |
| Test harness | `harness/smoke/run_probe_test.sh` + `probe_test.lua` | **WORKING** — boots, verifies vs spec, PASS/FAIL, exit 0/1 |
| Harness-proof target | `src/harness/loop_probe.s` | **WORKING** — 149 B; GIME 4-colour + VOFFSET swap + VBL count |
| Line-ending policy | `.gitattributes` | `.bat` pinned CRLF (cmd.exe cannot parse LF-only batch) |
| **Sprite converter** | `harness/tools/sprite_convert.py` | **WORKING** — POP `chtable` cel → CoCo3 4-colour `converted.s`. Colour model carried VERBATIM from karateka |
| **Colour-model guard** | `harness/tools/verify_color_model.py` | **WORKING** — diffs the two colour fns vs karateka; exit 1 on drift |
| **Authoring tool** | `harness/tools/sprite_tool/` | **PORTED** — 11 of 13 files byte-identical to karateka; `placement_table.py`/`catalog.py` retargeted |
| **Compiler round-trip** | `harness/tools/compile_check.py` | **WORKING** — converted.s + opacity.s → PA.9 compiled-sprite pipeline, with soundness sim |
| **Cel colour spot-check** | `harness/smoke/run_cel_test.sh` + `cel_test.lua` + `src/harness/cel_probe.s` | **WORKING** — displays a converted cel on the GIME, reads the framebuffer back |
| **Orientation guard** | `harness/tools/verify_orientation.py` | **WORKING** — compares converted rows against the ORIGINAL POP cel binary; wired into the spot-check, exit 1 on a flip |
| **Sprite compiler** | `harness/tools/sprite_compiler.py` | ★ **RETIRED P3.54, not in `build.bat`** — was: draw+save+erase per cel, all 4 Glen optimizations, register-level sim |
| **Compiled-sprite proof** | `harness/smoke/run_compiled_test.sh` + `compiled_test.lua` + `src/harness/compiled_probe.s` | ★ **RETIRED P3.103** (`harness/smoke/retired.sh`) — the mechanism it proved is gone |
| **PSHU order probe** | `src/harness/pshu_probe.s` | one-shot: pinned `PSHU D,X,Y` = D,X,Y ascending (the POC had it inverted) |
| **HAL (P2.1)** | `src/hal.inc` + `src/hal/coco3-dsk/` | **ADOPTED** — 10 files byte-identical to karateka; runtime blit DORMANT via `-DPOP_HAL_RUNTIME_BLIT` (77% of HAL code; POP uses ★ segment streams, in `src/engine/blit_core.s`, not the HAL blit). 16 of 29 declared functions are implemented; `debug.s` absent; `mem.s` not built (`end boot`). 3 rule-4 flags raised, 0 applied. |
| Converted sample | `content/kid/`, `content/guard/` | 9 POP cels (kid CHTAB1/2/3 + guard CHTAB4.GD; large/median/thin) |

### 2.1 — THE ENGINE, WHICH IS BUILT AND RUNNING (current at P5.1)

The line above this section used to read *"Engine: nothing built yet."* It has been false
since P3.1. What the build emits today, all of it Jay-gated on a live disk boot:

| Unit | Path | State |
|---|---|---|
| **Stage-1 loader** | `src/boot/loader.s` → `LOADER.BIN` | **RUNNING** — `$0E00`, shows a "loading" screen in the game's own byline font, then hands to the intro with the kernel already resident (P4.46) |
| **HAL kernel** | `src/hal/coco3-dsk/*` → `code` @ `$7900`, 1,092 B | **RUNNING** — GIME init/mode/swap/mirror, VBL, WD1773 disk primitive, DAC. `kernel_identical_check.py` asserts the loader's and the intro's copies are byte-identical |
| **Intro sequencer** | `src/engine/intro_seq.s` → `INTRO.BIN` @ `$2000` | **RUNNING + GATED** — Broderbund splash, presents/byline/title captions, prologue, title reprise, picture wipe |
| **LZ unpacker** | `src/engine/lz_unpack.s` | **RUNNING** — screens and the scene bundle arrive packed |
| **Princess cutscene** | `src/engine/cutscene_room.s` @ `$2600`, disk-resident | **RUNNING + GATED** — the room, two characters, torch flames, the hourglass |
| **Blitter** | `src/engine/blit_core.s` | **RUNNING** — segment-stream cel draw, sub-byte phases, clipped and unclipped entries, rectangle peel/restore |
| **Character driver** | `src/engine/char_draw.s` | **RUNNING** — per-beat cel placement, the paged cel bank, the bank-signature guard |
| **Cel bank** | `content/cutscene/chars/` + `link/pop_cels_*.link` | **RUNNING** — 1 pinned page at `$C000` + 4 rotating at `$E000`, blocks `$0C-$0F`, two mid-scene disk reads hidden in the song holds |
| **Music player (MSYS)** | `src/engine/msys_player.s` → `section msys` @ `$0A00`, 4,504 B | **RUNNING + GATED** — FIRQ-driven, disk-resident; the format was reverse-engineered across P4.16-P4.19 |
| **Sound effects** | `src/hal/coco3-dsk/sound.s` | **RUNNING** — door squeak, timer, footsteps |

**★ COMPILED SPRITES ARE RETIRED.** `src/engine/flame_cels.s:47` records it: *"The flames
were the LAST COMPILED SPRITES in the tree… the same 49 cels are 11.9 KB as raw packed
bitmaps and 100.8 KB as compiled code, and it is what put the cutscene outside 128 KB. The
characters moved to segment streams; these never did."* Retired at P3.54.
**`harness/tools/sprite_compiler.py` is no longer in `build.bat`** and the §2 row above and
the cost model below are HISTORICAL. **Packed cel data is the unit for every memory figure.**

**Suites (P3.103, Jay):** `probe cel compiled mode anim room walk` are **RETIRED, not
skipped** — the refusal lives in `harness/smoke/retired.sh` with its reason attached, and
`POP_RUN_RETIRED=1` is the named override. The run is **`introseq` + `integ`, at 128 KB**.

**Where the code lives is a stage question, not a size question** (`CLAUDE.md §2L`): the
`LOADM` image stays one granule and everything else — the scene program, the bundles, the
music player, the cel pages, every screen — is read from raw tracks by the port's own driver
after DECB is gone.

### start_col — settled, and it is not what it looks like (P1.2)
The converter's colour depends on `screen_col = start_col + local_col` PARITY. POP's source
gives the mapping **exactly**: `ByteTable[x] == x//7` and `OffsetTable[x] == x%7`
(TABLES.S:51-67, `lup 36` loops), so CVTX is a pure divmod-7 and `midX*7 + midOFF` **is** the
pixel column; character cels carry sub-byte position via `ADDMID` (GRAFIX.S:341), unlike
`bgX`/`fgX`, which have no offset field at all. What source cannot give is a *value*: `CharX`
is live state and the character moves, so a cel has no single draw column — on the real
Apple II a walking character's artifact colours oscillate. **Per Jay's ruling this is fine:**
once converted, colour is frozen as CoCo3 palette indices, which carry no NTSC parity
dependence. `start_col` is a conversion-time authoring input, consumed once. The sample was
converted at `--start-col 0` (EVEN), which is also the source-defensible default: the draw
path doubles a 140-res `CharX` into 280-res (`asl`/`rol`, CTRLSUBS.S:809-813), so a
character's base column is always even.

### Cel ROW ORDER — POP is bottom-first (P1.2-fix). Trap for anyone porting art.
POP cel data is stored **BOTTOM-ROW-FIRST** — **SETTLED: Jay confirmed the corrected render
2026-07-26** ("yes the afters look correct"), so this is fact, not an inference from code.
Karateka's is top-first. Three code sites in `HIRES.S` establish it: PREPREP leaves `IMAGE` at
data row 0; CROP sets `TOPEDGE = YCO - HEIGHT` with `YCO` the *lowest* line; the draw loop
advances `IMAGE` FORWARD while `DEC YCO` walks UP.
**The `HIRES.S:187` comment says the opposite** (*"read left-right, top-bottom"*) — it describes
sequential storage, and taken as visual orientation it would make the original render upside
down. `CLAUDE.md §2` ranks comments lowest; the mechanism wins. The converter therefore reverses
rows at ingest. Without it every cel, and every compiled sprite built from one, is upside down.

**The verification lesson is the bigger one.** P1.2's spot-check passed **1152/1152 pixels** on
upside-down cels, because both sides of that comparison were downstream of the converter — a
uniform flip round-trips clean. Jay caught it by eye. `verify_orientation.py` now anchors to the
original cel binary instead. **For any property with a ground truth, at least one check must be
anchored OUTSIDE the pipeline under test.**

### Compiled-sprite cost model (P1.3) — ★ HISTORICAL. The mechanism was retired at P3.54.
Kept because it is the measurement that eventually retired itself: 8.2× the RAM of packed
bitmaps is what put the cutscene outside 128 KB. Do not plan against these numbers.
Per footprint byte, 9-cel sample: **draw 5.77**, erase 4.52 (byte-set) / 7.32 (rectangle),
**draw+erase 10.29** (byte-set) or 13.09 (rectangle). PA.9's POC was 5.94 on identical data,
so Glen's four optimizations bought **~3%** — `PSHU` fires in 0.4% of cycles because only 7%
of opaque bytes sit in runs of 4+; 60% of drawn bytes are *mixed* and fragment every run.
**Opaque-black is the real lever** (mixed 644→0, PSHU 7→348, draw −32%) but it is an
AUTHORING decision — and **PA.13 DECLINED it**: measured at the game's own character
placements the prince's body band is only **86.1% black (dungeon) / 84.3% (palace)**,
below the ~90% near-free bar, and the lit fraction is floor-hugging (**25.3% lit at
feet/shins** vs ~9% at head) — i.e. the departure would show exactly at the
character-floor contact line. p90 fits without it, so: **interior-black only, keyed
edge.** Tools: harness/tools/playfield_census.py, playfield_band.py. **Peel model is an open engine decision worth ~2.8 cy/byte**: POP's own
peel is a rectangle (`LAYRSAVE` `inc WIDTH`+`CROP`, constant cost), but a compiled sprite can
restore only the bytes it drew. p90 frame: PA.9's marginal 1.01× → **0.96–0.99× FEASIBLE**.

### The loop, concretely
```
build.bat                            # lwasm + imgtool  -> build/probe.dsk
harness/smoke/run_probe_test.sh      # boot + exercise + verify -> PASS (exit 0)
harness/smoke/run_probe_test.sh --expect-vbls 999    # wrong spec -> FAIL (exit 1)
harness/smoke/run_probe_test.sh --mode direct        # skip DECB; poke + set PC
```
Verified P1.1: 6/6 checks PASS on both load modes; two independent deliberate-FAIL modes
(timing spec, framebuffer spec) confirmed to fail. **A harness that cannot fail is not a
test** — keep a demonstrated FAIL in every future harness.

### What the harness can already do (that later work needs)
- Read arbitrary CPU-space memory, including both framebuffers (`$8000`/`$C000`, 15,360 B).
- Count time in **VBLs via `frame_number()`** (idiom §0 — there is no Lua cycle counter).
- Cross-validate guest timing against MAME's own frame clock (the check that makes a
  timing claim evidence rather than assertion).
- Load a build **two ways**: DECB `LOADM`+`EXEC` (the real boot path) and direct poke
  (fast, deterministic — this is the mode the oracle framebuffer-diff will use).

---

## 3. STANDARD — idiomatic 6809 (PA.11). Non-negotiable.

`k=0.35` is a **target to be hit**, not a property to be discovered. Code that misses it
pushes p90 frames over budget. Concretely, when porting 6502 logic:

- **Hot-loop pointers live in index registers** (`X`/`U`/`Y`), not in zero-page reloaded
  per access. `lda (ptr),y` → `ldb ,x+`, not `ldu <ptr` + `ldb ,u`.
- **Use auto-increment/decrement indexed modes.** They are the whole point of the 6809.
- **Do not transliterate.** The idiomatic form is allowed to change program *structure* —
  PA.11's measured win came partly from eliminating a subroutine the 6502 source needed.
- **`D` is a 16-bit register.** Pair 8-bit work; use `STD`/`LDD`/`ADDD` where the 6502 did
  two 8-bit ops.
- **Direct Page is a resource.** `setdp 0` and DP-relative access for hot variables.
- 6809 only. 6309-equivalent code is acceptable; 6309-*only* instructions are not.

**Review rule:** any hot-path routine that reads as a 1:1 opcode mapping of the 6502 source
is a defect, even if correct.

---

## 4. STANDARD — verification

- **Behaviour identity vs the oracle is the bar**, checked by framebuffer diff, not by
  reading code. `oracle/source/` is the trusted default working basis (`CLAUDE.md §2`),
  but **when the trace and the source disagree, the trace wins.**
- **Prod byte-identity is a `main` invariant** (`CLAUDE.md §2E`); `wip` may carry
  incoherent WIP. Verify the SHA before claiming it.
- **`25.3` is Jay's gate.** Never self-certify a visual result. PA.12 added a second gate
  of the same kind: **audio correctness is also Jay's alone** — no numeric check answers
  "does it sound right."
- Oracle hard-stop: `.hdv` md5 must be `c4f0b13e49b77dd0fbc5063e27e53a24`.

---

## 5. Build-order backlog — DONE, and what is next

**Items 1-6 of the original backlog are all DONE.** Recorded here rather than deleted,
because the shape of how each was closed is the useful part:

| orig. | item | how it closed |
|---|---|---|
| 1 | HAL video core | **DONE** P2.5/P2.6 — `HAL_gfx_init`, `set_mode`, `swap` (VOFFSET, ~186 cyc), `mirror` |
| 2 | VBL/time HAL | **DONE** — IRQ-driven, `HAL_time_vbl_wait`. ★ Its documented fallback does NOT wait when `CC.I` is set, which is the trap `gfx.s` warns about at length |
| 3 | the compiled-sprite compiler | **SUPERSEDED, not built.** Compiled sprites measured 8.2× the RAM of packed bitmaps and were retired at P3.54. Characters are **segment streams** |
| 4 | disk loader (FDC branch b vs c) | **DONE** — `src/hal/coco3-dsk/disk_read.s`; whole-track reads, an NMI handler in the `$FE00` constant-RAM page so it survives an MMU remap |
| 5 | engine kernel | **DONE for the intro and the cutscene**; the GAMEPLAY loop is the open arc |
| 6 | sound | **DONE.** Effects on the DAC; the music format was reverse-engineered off the oracle image (P4.16-P4.19) and `msys_player.s` plays it under FIRQ |

### THE OPEN ARC — the DEMO (gameplay), opened P5.0

1. **The tile renderer.** The one genuinely new subsystem. `harness/tools/bg_compose.py`
   implements POP's background compositor OFFLINE and is validated **byte-exact against the
   running oracle** (96.54% of visible bytes, all 266 differences inside four named
   omissions, zero unexplained). That tool is the specification and its diff is the
   acceptance test the 6809 version can reuse unchanged. ★ **It must draw the FOREGROUND
   plane too** — `drawfrnt` queues to a separate list from the SAME `bgtable` images, drawn
   AFTER the characters, half of it through `maddfore`'s mask-then-or pair. A background-only
   renderer puts every post, railing and arch behind the prince (P5.0 §3B).
2. **★★★ THE CEL-BANK ARCHITECTURE DECISION — Jay's, and open.** Measured at P5.1:

   | window | chars (kid ∪ guard) | tiles (demo level) | total | vs bank 32,768 | vs recruited 65,536 | vs the 15,872 B visible at once |
   |---|---|---|---|---|---|---|
   | mid-move | 12,061 | 14,063 | **26,124** | FITS | FITS | over by 10,252 |
   | one control decision | 48,576 | 14,063 | **62,639** | over by 29,871 | FITS (4.4% spare) | over by 46,767 |

   **The binding constraint has moved from CAPACITY to ADDRESSABILITY.** Options named and
   unranked: recruit blocks `$02/$03/$06/$07`; page character families per move-group; a
   denser encoding; a third window at `$FFA3`. See `demo-move-graph.md` and
   `demo-memory-map.md` — both checked in, both regenerable from their tools.
3. **The gameplay loop** — `RESTART`'s init list, `MainLoop`, the frame dispatcher, the
   actor/animation system (`ANIMCHAR`/`GETSEQ`/`ADDCHARX`), held to §3.
4. **Peel-buffer resizing** — `VIZ_PEEL`/`PRI_PEEL` at `$6C00-$727F` are sized for the
   vizier and the princess, not for a prince and a guard.
5. **Music set 2** — the 16 gameplay songs. The player needs no change; only the data load.

---

## 6. Open questions carried into the build

1. **The idioms-file authorship ruling** (`CLAUDE.md §2A.3`) — deferred since P1.1.
   A one-line ruling from Jay closes it.
2. **The 4-colour palette has two homes.** `HAL_gfx_init` writes `$00/$26/$1B/$3F` inline
   [`gfx.s:256`]; `HAL_gfx_set_mode`'s descriptor points at `gfx_pal4 = $00/$26/$19/$3F`
   [`gfx.s:801`], whose own comment calls it *"DIAGNOSTIC … Not POP's art palette."* Index 2
   differs. `set_mode` runs last, so `$19` is what the machine shows and what Jay has been
   gating — a duplicated fact, not a visible defect.
3. **`.gitattributes` residual gap (P5.1).** Both halves the backlog required are present and
   have been since `fe333ff` (2026-07-25), three weeks before P3.108's byte-identity claim.
   But `*.md`, `*.txt` and `*.py` are covered only by `* text=auto` (normalised in the repo,
   NATIVE in the working tree) rather than pinned `eol=lf`; and `content/cutscene/*.lz` and
   `*.raw` — production content — are not in the `binary` list, relying on git's NUL-byte
   heuristic. **Deliberately not changed at P5.1**: altering line-ending policy immediately
   before a byte-identity promotion is the wrong ordering.
4. **The oracle's `chtable2`/`chtable7` extent contradiction** (P5.0 §7 flag 1). `chtable7`
   at main `$9F00` overlaps `chtable2`'s measured extent (`$8400`+8,893 = `$A73D`), and
   `LoadStage3` does not reload `chtable2`. Flagged, not chased; it does not change what the
   port must hold.
5. **The MAME `auxram` share** — `oracle_demo_bg.lua` could not find it, so live AUX reads
   from the oracle are unavailable. Not needed so far.
6. **`s_Princess` fuzziness** — an open audio item from the P4 arc; may reappear in gameplay.
7. **The stale `pop.link` stack comment** and the `POP-idioms-coco3-markers.md` / `.vscode/`
   dispositions — housekeeping.
8. **Dispatch numbering:** two distinct dispatches were labelled **P1.1**. Report filenames
   differ so nothing collided, but the label is ambiguous.

---

## 7. Environment (verified P1.1)

| Tool | Version | Location |
|---|---|---|
| LWTools | 4.24 | `C:\WIN_LWTools\` (`lwasm`, `lwlink`, `lwar`) |
| MAME | 0.281 | `C:\mame\mame.exe`, roms `C:\mame\roms` |
| imgtool | (MAME 0.281) | `C:\mame\imgtool.exe` |
| Python | 3.13.7 | on PATH |

- `mame coco3 -verifyroms` reports "bad" — **this is benign**: the only missing files are
  three *alternate* DOS ROMs for the `coco_fdc` cartridge (`rgbdos_mess.rom`,
  `hdbdw3bck.rom`, `hdbdw3bc3.rom`). The CoCo3 BIOS and `disk11.rom` ship inside
  `coco3.zip` and disk boot works.
- **`-ext fdc` is mandatory** for any disk boot. A bare `coco3` has no disk controller.
- `docs/ground-truth/` is **local reference only — never committed** (standing Jay ruling).
