# project-state.md — POP → CoCo3 build-phase state

**READ THIS FIRST at the start of every build session**, before CLAUDE.md's task-specific
context. Clyde is stateless across sessions; this file is what makes the build coherent
anyway. It records what is *built*, what is *verified*, what the standards are, and what
comes next.

**Authorship:** Clyde-authored operational state. This is **not** an authored-authoritative
doc under `CLAUDE.md §2D` (no decision records, post-mortems, or behavioural models here —
those stay Orchestrator-owned). Clyde updates this file directly as build state changes.

**Last updated:** 2026-07-25 (P1.1 — build→test→verify loop stood up)
**Phase:** BUILD (the feasibility investigation is CLOSED — see §1)

---

## 1. Where the project stands

The feasibility arc (PA.1–PA.12) is **closed**. The port is **FEASIBLE**, with these
findings now standing as build constraints rather than open questions:

| # | Finding | Consequence for the build |
|---|---|---|
| PA.2 | Budget denominator is **178,968 cyc/game-step** (POP animates at 10 fps), not 29,859 | Cost everything per *step*, not per VBL |
| PA.5 | POP is **compute-bound**; median idle is zero; blit is 55–63% | The blit is the thing to optimise; AI is not (COLL 1.23%, CTRL 0.21%) |
| PA.6 | Runtime masked-loop blitting is **INFEASIBLE** (`gfx.s`'s header estimate was 5.4× understated) | Do not build a runtime masked blitter |
| PA.7/PA.9 | **Compiled sprites** are ~16× cheaper; POP's real art is 68.9% mixed-class | Compiled sprites are the rendering strategy |
| PA.8 | 16-colour mode is **excluded on memory alone** | **Mode = 320×192×4 (2bpp)**, `$FF98=$80`, `$FF99=$15` |
| PA.11 | `k` is **not a constant** — 1.23 transliterated vs 0.35 idiomatic; they straddle the p90 gate | **The idiomatic-6809 standard below is a hard requirement, not a preference** |
| PA.12 | Sound fits (0.57–0.83× at p90); effects map 1:1 from POP's `tone()` | Music engine is **absent from the source** — see §5 |

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
| Line-ending policy | `.gitattributes` | **NEW** — `.bat` pinned CRLF (cmd.exe cannot parse LF-only batch) |

**Engine: nothing built yet.** `src/{boot,engine,hal/coco3-dsk,opt/*}` are still empty
`.gitkeep` skeletons. The loop exists *before* the engine, deliberately: every piece of
engine code from here is built inside it.

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

## 5. Build-order backlog

Ordered. Each item is built inside the loop from §2 and gets its own spec-checked test.

1. **HAL video core** — `HAL_gfx_init` (the GIME sequence `loop_probe.s` already proves),
   `HAL_gfx_clear`, `HAL_gfx_present` (VOFFSET swap, ~186 cyc). Adapt from Karateka's
   `gfx.s` per `CLAUDE.md §2G`, but **do not carry its runtime masked blit** (PA.6).
2. **VBL/time HAL** — decide polled (`$FF92` VBORD latch, as the probe does) vs IRQ-driven.
   The probe's polled form needs no `$010C` install, which sidesteps the DECB overlap.
3. **The compiled-sprite compiler** — productionise `poc/compiled-sprite/popcc.py`
   (currently an explicitly throwaway measurement instrument, *not* engine tooling).
   Needs: real cel→token pipeline, the `opacity.s` sidecar contract, emitted-code
   correctness harness (the POC's `simulate()` is the right shape).
4. **Disk loader** — **BLOCKED on an undecided upstream question.** Karateka's
   `fdc-read-primitive.md` leaves two live branches: (b) DD+DRQ→HALT @0.89 MHz and
   (c) DD+polled @1.79 MHz (contested — fast-speed FDC access is unverified and
   Jay-doubted). Branch (a) single-density is ruled out by capacity. **Decide before
   building.** Karateka's `HAL_file_init` is a no-op stub; there is no code to reuse.
5. **Engine kernel** — per-frame dispatch, the actor/animation system (POP `ANIMCHAR`/
   `GETSEQ`/`ADDCHARX`), held to §3.
6. **Sound** — effects first (POP's `tone(pitch,dur)` maps ~1:1 to a DAC phase
   accumulator; confident). **Music is blocked**: `minit`/`mplay` are `ds 3` JMP slots
   patched at load time from raw disk **track 34** — the engine and all 22 songs are
   **absent from the vendored source**. Reverse-engineering them off the oracle image is
   its own recon arc, not a sub-task. Audio must be **masked across disk I/O** on both
   live FDC branches.

---

## 6. Open questions carried into the build

1. **The idioms-file authorship ruling** (`CLAUDE.md §2A.3`) — now deferred **ten** times.
   P1.1 filed 6 new idioms provisionally under the Orchestrator's standing recommendation
   and flagged them for Jay. A one-line ruling closes this.
2. **FDC branch (b) vs (c)** — blocks backlog item 4 (above).
3. **POP's music format** — blocks the music half of item 6.
4. **`$FF23` DAC/MUX enable** — small lookup in `docs/ground-truth/`, closes a PA.12 gap.
5. Housekeeping: `POP-idioms-coco3-markers.md` disposition; `.vscode/` disposition.
6. **Dispatch numbering:** two distinct dispatches have now been labelled **P1.1** (the
   oracle vendor, `reports/20260724-232429-p1-1-oracle-vendor.md`, and this build-loop
   dispatch). Report filenames differ so nothing collided, but the label is ambiguous.

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
