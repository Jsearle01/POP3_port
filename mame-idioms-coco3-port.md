# MAME idioms & quirks — CoCo3 target (the Karateka port)

**Purpose:** a standing, self-contained reference so instrumentation and boot quirks on the
`coco3` target (the `karateka-coco3` port) are **looked up, not rediscovered each dispatch.**
Every entry is traced to the pass that established it and, where one exists, to the **tool**
that exercises it and the **exact command/Lua syntax** that works. Read this before
instrumenting or booting the port under MAME.

**Target:** `mame coco3`, 6809 CPU, ~0.89 MHz slow / ~1.78 MHz double-speed, GIME video +
MMU, WD1773 FDC on a 5.25″ floppy. **Prod baseline (never mutate under a read pass):**
`karateka.bin` SHA-1 `88eba89b15cdf17c8d25e082d2d3e1f3cce57d38`, 17978 B. **Co-equal target:**
a MAME **failure** on coco3 is a **shipping bug** (C-11 / I-BOTH), not deferrable to hardware
— but a MAME **success** on a hardware-edge question is **not** a hardware guarantee (§7).

> This file **incorporates** the earlier `mame-idioms-addendum.md` item A (GIME register
> ordering) and D (pixel-colour provenance), plus the cross-cutting debugger/Lua mechanics,
> tap-GC gotcha, and live-gate flags shared with the apple2e oracle.

---

## 0. Measuring the port's per-frame COST: no Lua cycle counter — count **VBLs via frame_number**
**MAME 0.281's Lua device wrapper exposes neither `cpu.clock` nor `cpu:total_cycles()`** (both
`nil` — probed, `build/logs/b2_probe.txt`), and **`manager.machine.time` is quantised to the
scheduler timeslice**, so an intra-frame `machine.time` delta around a routine reads as ~4 cycles
and is **useless for cost** (it looks like the work is free). `scr:frame_number()` **is** exact.
So: **measure cost in VBL units** — read-tap each routine's entry address (6809 read-taps fire on
opcode fetch, §10) and diff `frame_number` between marks. 1 VBL = the entire per-frame budget, so
"this routine costs 5 frame-deltas" is already the verdict; convert with
**VBL = 29,859 cycles** (coco3 maincpu 894,886 Hz from `mame -listxml coco3`, **×2** because
`HAL_gfx_init` writes `$FFD9` SAM double-speed, `src/hal/coco3-dsk/gfx.s:198`; ÷59.94 Hz).
- **A whole-frame overrun is also directly visible**: tap the frame loop's `HAL_time_vbl_wait`
  entry and diff `frame_number` per iteration — 1 = fits, ≥2 = the frame missed its VBL. This is
  the cheapest go/no-go and needs no cycle counting at all.
- **⚠ ARM the taps after the `.bin` is loaded.** Driver routines living in low RAM (`$02xx-$04xx`)
  are addresses **DECB/BASIC itself executes** during boot (§5 overlap), so unarmed taps fire at
  ~f22 and a "first hit only" rule burns on BASIC, not the driver — it reads as the routine running
  impossibly early. Gate every tap on an `armed` flag set when PC is set to the driver's entry.
Tools: `harness/tools/stageb2_budget.lua` (frame-loop overrun), `stageb2_initcost.lua`
(per-routine VBL cost + blits/frame). *Established:* Stage-B2 §0 VBL-budget gate 2026-07-20.
*Candidate:* `measure-cost-in-vbls-when-the-emulator-exposes-no-cycle-counter`.

### 0a. The VBL spin-wait IS a cycle counter — how to verify the live CPU CLOCK by execution
MAME exposes **no clock accessor either** (`cpu.clock` / `configured_clock` / `unscaled_clock` /
`clock_scale` all nil — `build/logs/clk_probe.txt`), so "are we at 0.89 or 1.78 MHz?" must be
answered **behaviourally**. `HAL_time_vbl_wait` spins in a 2-instruction loop
(`cmpb <hal_frame_lo` = 4 cyc + `beq` taken = 3 cyc = **7 cycles/iteration**), burning every cycle
the engine is *not* working. Read-tap `hal_vbl_spin` and count hits per frame:
`spins*7 = idle cycles`, so **`spins*7` is a hard LOWER BOUND on the frame's cycle budget** — and a
bound is often all you need: measuring **29,736** cycles inside one frame *disproves* 0.89 MHz
outright, because that window only holds 14,929.
- **A/B/A control makes it conclusive and self-calibrating:** poke `$FFD8` (SAM speed LO) from Lua
  mid-run, then `$FFD9` (HI) to restore. Work per frame is unchanged, so with phase-matched samples
  `total_fast = 14*(spins_fast - spins_slow)` — no datasheet trust and no absolute-clock assumption.
  Measured: 1.76–1.79 MHz across 13 phases; forced-slow segment capped at 14,805 ≈ the 0.89 MHz
  window (0.8%), confirming MAME models the bit and the engine runs the doubled clock.
- **⚠ Phase-matching breaks where the work differs between segments** (a phase state-machine
  advances at different points when the clock changes) — those phases yield nonsense (0.007 MHz);
  use the assumption-free `max(spins)*7` bound as the primary, the differential as corroboration.
Tool: `harness/tools/verify_cpu_speed.lua`. *Established:* CPU-speed verification 2026-07-20 —
the engine's ONLY speed write is `HAL_gfx_init`'s `$FFD9` at `pc=$1E9B` (boot-time, not per-scene).
*Candidate:* `a-spin-wait-loop-is-a-free-cycle-counter-for-clock-verification`.

---

## 1. The load-bearing one: **the CoCo3 has NO autoboot**
Inserting a disk **runs nothing.** There is no autoboot. The entry point is **Disk BASIC
(DECB)** — you reach the game by having DECB `LOADM` + `EXEC` the binary (or an equivalent
boot front-end). **Do not expect `-flop1 <disk>` to boot the game** — it mounts the disk;
DECB is the ROM running, and it does nothing until told. The boot path is DECB, whose live
low-RAM and IRQ-vector usage **overlap the game's load region** (§5). *Candidate:*
`coco3-has-no-autoboot-entry-is-DECB`. *Established:* disk-boot / DECB-overlap arc.

---

## 2. **Autoboot script ↔ interactive input are mutually exclusive** — use `natkeyboard:post`
MAME's `-autoboot_script` and interactive input don't coexist cleanly here. To drive DECB
(type `LOADM"…"` / `EXEC`) under automation, **post keystrokes to the natural keyboard**:
```lua
manager.machine.natkeyboard:post('LOADM"PROG"\r')   -- note the trailing \r (ENTER)
manager.machine.natkeyboard:post('EXEC\r')
```
Drive it **after boot settles** (~frame 240). The documented method: `disk11.rom` (Disk BASIC
ROM) + `imgtool` (build the image) + `mame coco3` + `natkeyboard:post`, working around the
autoboot mutual-exclusion. *Candidate:*
`mame-autoboot-and-interactive-are-mutually-exclusive-use-natkeyboard-post`. *Established:*
disk-boot / DECB-overlap verdict (AC-4 reachability).

---

## 3. Disk images: **`imgtool`**, `.dsk` vs DMK, and **MAME can't write DMK/SDF back**
- **`imgtool`** builds coco3 disk images for MAME. **A `.dsk` is always 18 sectors/track** —
  no native short-track fixture; a short-count / worst-case track points at **DMK** (or JVC).
- **JVC createopts came back empty; DMK is the format for track-geometry control** (DMK
  createopts unchecked at last note — verify before relying). Boot images are
  **whole-track-aligned** in our `.dsk` layout (keeps raw game tracks contiguous).
- **`.dsk` fixtures are gitignored / throwaway** — a shared fixture once broke an AC (3b-1);
  **generate per-task, don't share.**
- **MAME write-back is format-limited (a real gotcha).** **DMK and SDF are READ-ONLY** in
  MAME's floppy layer (`floptool` shows `dmk r-`, `sdf r-`) — a guest that formats a mounted
  `.dmk` runs fine but the file is **byte-unchanged on exit**. Only `jvc` and `coco_rawdsk`
  save back, and JVC is a **logical** image (discards physical sector order). So you **cannot
  image a guest-formatted disk to inspect its interleave**, and MAME Lua exposes no floppy
  track-data accessor.
  - **Workaround — in-session CPU hijack (§10 proxy pattern):** boot the guest, let it format
    in the in-memory floppy, then from Lua load a standalone read harness and time a read of
    the just-formatted disk (no write-back needed). **Validate the hijack with a control**
    (read a known-good pristine disk the same way; it must reproduce the normal time). Detect
    guest-op completion by watching FDC command writes (`$FF48`) for an idle gap.

*Candidates:* `dsk-is-always-18-sectors-use-DMK-for-short-tracks`,
`mame-dmk-writeback-hijack-proxy`. *Established:* BUILD #3b passes + the DECB-BACKUP refutation.

---

## 4. **Track-17 is the DECB directory** — mid-disk, do not overwrite
The DECB directory lives on **track 17, mid-disk.** A raw game-track span crossing track 17 is
**silent corruption** (bootloader reads directory as game data, or the raw layer overwrites
the directory). **Keep the raw game track range clear of track 17** (or account for it
explicitly); reserved raw tracks must stay **contiguous and clear of 17**, and DECB must
**tolerate the reservation** (it can flag reserved tracks as an inconsistency if done wrong).
*Candidate:* `decb-directory-is-track-17-keep-raw-tracks-clear`. *Established:* BUILD #3b-3.

---

## 5. The disk-boot overlap: **DECB `LOADM` overwrites `$010C`** (M1) — confirmed mechanism
When DECB `LOADM`s the binary, segment-1 lands on DECB's regions — specifically **M1: the
`$010C` IRQ-vector overwrite** (hang at `$C60F` in the trace). `$0100-$01FF` is **contested
during LOADM** — the M1 watchpoint on it pinpointed the overlap. The fix (a separate gated
task, M4): a bootable `.dsk` + a loader that avoids the overlap; the raw-underlayer approach
chains through this. **M2** (a second overlap hypothesis) was **unreachable/unproven** in the
trace — flagged, not smoothed over. *Candidate:* `decb-loadm-overwrites-010C-irq-vector`.
*Established:* disk-boot / DECB-overlap verdict (M1 confirmed by trace).

---

## 6. **The WD1773 FDC** — the CoCo3 disk-controller programming model
- **Four memory-mapped registers** in the `$FF4x` area (command/status, track, sector, data;
  command/status at **`$FF48`**) — confirm base/order against **DECB Unravelled** (register
  base/order is the F1 risk if assumed).
- **DECB assumes slow; it does not FORCE slow**, and **does not use HALT for double-density.**
  The absence of a `$FFD8` (slow-speed poke) in the disk path is the evidence — "assumes
  slow" ≠ "forces slow."
- **Capture the density / motor / settle sequence** (addresses, latch bits, DECB's
  motor/settle/density order) when tracing disk I/O.

*Candidate:* `decb-assumes-slow-does-not-force-slow`. *Established:* FDC read-primitive recon +
DECB speed passes.

---

## 7. What MAME **cannot** answer here — do not over-trust the emulator
MAME shows *behaviour*; only real hardware / a faithful timing model settles some questions.
Flag these **MAME-can't-confirm**; don't launder a clean run into "verified":
- **Fast-speed FDC survival** at ~1.78 MHz — doc-supported-**unsafe** (Lomont fast-speed ROM
  failure; MFM DD polling fails at 0.89 MHz empirically) but the **edge is not
  MAME-authoritative** → real silicon.
- **HALT + NMI-completion timing** — if the fix depends on HALT-enable / NMI-completion and
  there's no INTRQ path, it may be **UN-TESTABLE in MAME**; report as such (may still be
  correct, just not MAME-provable).
- **Seek-Error reliance / FDC edge fidelity** → real silicon.
- **GIME MMU 128K range conflict** — MAME does **not** resolve the doc-vs-hardware MMU-range
  question; tracked as a 25.3-H(divergence) item, not closed by a clean run.

**Rule:** a MAME **failure** on a co-equal target is a real bug (C-11); a MAME **success** on
a hardware-edge question (fast-speed FDC / HALT timing / MMU range) is **not** a hardware
guarantee — hold it as `inferred`, gate to silicon. *Candidate:*
`mame-success-on-a-hardware-edge-question-is-not-a-hardware-guarantee`. *Established:*
DD-slow-speed feasibility, DECB fast-speed viability, GIME-MMU recheck.

---

## 8. Speed control: **force-slow → do-I/O → restore-speed** wrapper
Where slow speed is needed for disk I/O, poke the speed down, do the transfer, restore.
`$FFD8`/`$FFD9` are the speed pokes (slow/fast). The **boot primitive itself doesn't need it**;
the wrapper is owned at the I/O-caller layer. DECB assumes slow but won't protect you at fast
speed (§6) — a missing `$FFD8` in a disk path means "assumes slow," not "forces slow."
*Established:* DD-at-slow-speed feasibility + FDC viability follow-up.

---

## 9. **GIME register write ORDER: palette must be written AFTER video mode** (addendum A)
A real hardware/emulator behaviour, not a style preference: **palette register writes
(`$FFB0-$FFB3`) do not latch correctly until the GIME's video mode is already set.** Writing
palette **before** `$FF98`/`$FF99` leaves the mid-range indices **not rendering** — only the
extremes ($00 black / $3F white) survive; indices 1/2 (orange, blue/cyan) come out wrong or
absent. **Symptom:** a four-band palette test shows only 2 bands; Brøderbund logos render
without orange/blue.

**The required order** (addresses confirmed present in `src/`):
1. **`$FF90`** (CoCo3 mode) **first** — the `$8000+` framebuffer needs CoCo3 mode for CPU
   access.
2. clear buffers.
3. GIME mode/offset/SAM setup: **`$FF98`/`$FF99`** (video mode + resolution), **`$FF9D`/
   `$FF9E`** (offset), **`$FF9C`**, **`$FF9F`**, **`$FFD9`**, **`$FFDF`**.
4. **palette `$FFB0-$FFB3` LAST.**

Empirical (GFXMODE3.ASM + Jay: "the GIME needs to be completely initialized before palette
values are written"), **not** Sockmaster-documented. Cost of not knowing it: the P2.3a
display-init arc burned multiple followups (followup-2 NOT CONFIRMED, chasing palette
*values* when the cause was *ordering*) before the reorder fixed it. *Candidate:*
`gime-palette-writes-must-follow-video-mode-set`. *Established:* P2.3a.6 followup-3 (the
reorder). Tool: `harness/tools/palette_derive.py` (index derivation),
`harness/tools/decode_framebuffer.py` (framebuffer verify).

---

## 9a. **OPAQUE blit + a sub-byte shift writes the shifted-in edge zeros as BLACK bars**
`HAL_gfx_blit_sprite_opaque` stores **every** pixel of the sprite's byte span. When the sprite is
placed with `blit_subbyte > 0`, the sub-byte shift brings **zeros (index-0 black) into the leading/
trailing edge pixels** of the partial edge bytes — and opaque mode writes them, so each shifted
sprite shows a **thin black vertical bar at its left and right edge** (a transparent blit keys these
out, so the bug only appears with opaque). **Symptom:** a stack of opaque backdrop sprites shows
1-2px black bars at every sub-byte-shifted sprite's edges (scene-6 Fuji: A9B8 sub1 + A948 sub2 →
4 bars at X144-145 / X174-175). **Fix (backdrop):** **byte-align** the sprites (`blit_subbyte = 0`);
the ≤3px position loss is negligible for a static backdrop and the shifted-in zeros disappear. (For
sub-pixel-critical actors, pad the cel's edge with the sky index or use a masked/transparent blit
instead.) *Established:* scene-6 Stage-1 Fuji backdrop gate. Tool: `harness/tools/scene6_stage1_confirm.lua`
+ a per-column black-count framebuffer scan.

## 9b. **Index-0 is overloaded (transparent-pad vs meaningful-black) — flood-fill to separate them**
The Apple→CoCo3 converter emits index-0 (black) for BOTH the sprite's meaningful black AND the
transparent bounding-box padding/edges, so a single opaque/transparent blit flag can't render both
right (opaque → padding shows as black boxes/bars; transparent → the real black shows sky). Separate
them by **flood-fill from the cel border through {index-0, index-2(sky-blue)}**: black *reached* from
the border is edge/outline (choose per the art); black *walled off by index-3 white* is interior. On
scene-6's Fuji, Jay's ruling was **edge-connected black = OPAQUE** (mountain outline), **white-
surrounded interior black = TRANSPARENT** (sky-holes → convert to blue), plus **fully-black columns =
trim-boundary artifact → blue**. Tool: `harness/tools/floodfill_bg_sky.py`. *Established:* scene-6
Stage-1 Fuji cel-data fix.

## 10. Instrumentation — **6809 read-taps WORK** (the key cross-target asymmetry) + shared Lua
- **On 6809, program-space read-taps DO fire** — unlike the 6502 oracle side, where opcode
  fetches bypass them. So the single most important cross-target difference: **on coco3 you
  can read-tap an execution address directly; on apple2e you can't** (use a bp / write-tap /
  watch-the-result there). *Candidate:* `6809-read-taps-work-6502-read-taps-dont`.
- **Tap-GC gotcha (cross-cutting, applies here too):** `install_read_tap`/`install_write_tap`
  and `emu.add_machine_frame_notifier` return an object you **must keep referenced** (`_G._tap
  = …`, `_G._n = …`) or it is garbage-collected and **silently stops firing** (empty log =
  false "never happens"). Taps work **headless** (no `-debug`).
- **The debugger/Lua toolkit is MAME-general** (same as apple2e §4) and useful on coco3 for
  boot-time watchpoints and forcing:
  ```lua
  pcall(function() manager.machine.debugger.execution_state="run" end)  -- unpause headless -debug (else HANGS)
  local cpu = manager.machine.devices[":maincpu"]
  cpu.debug:wpset(cpu.spaces["program"], "w", 0x010C, 2, nil, 'tracelog "M1 pc=%04X",pc; go')  -- catch the $010C overwrite
  cpu.debug:bpset(0xADDR, nil, 'pb@0xZP=0xNN; go')     -- force a value at a read
  manager.machine.debugger:command("trace C:/…/out.tr,0")   -- run any debugger cmd from Lua
  ```
  **Syntax:** registers `a b d x y u s pc cc dp` (6809 set); byte read `b@0xADDR`; poke
  `pb@0xADDR=v`; **bp-action `tracelog` is brace-FREE** (`tracelog "…",pc; go`), **trace-command
  action is BRACED** (`{tracelog "…",pc}`) — mixing fails silently. Debugger `printf` is **NOT
  captured headless** — use `tracelog` into an open trace. Write Lua output via `io.open`, not
  `print()` (console not captured).

*Established:* cross-target instrumentation note + the M1 `$010C` watchpoint + the shared
debugger toolkit from the `$6540` pass (commit `634e0c3`).

---

## 11. Visual authority is **Jay's live MAME**, never a Clyde snapshot
Every colour / position / on-screen claim is **Jay's** to gate off a live coco3 MAME run. The
CoCo3 side is **palette-based** (GIME explicit palette) — once colour is fixed on the Apple
read side, the CoCo3 index is baked correctly and there is nothing to re-check at render time;
but **whether it reads right on-screen is still Jay's eye**, and 25.3 is his MAME observation.
A `wpset` PC-confirm shows *code ran*, not *what it looks like*.

**Pixel-colour provenance (addendum D — applies to any capture file):** filename labels
("TRUE"/"reference"/"ground truth") establish nothing; **content + creation method +
timestamp** do. MAME's rendered palette ≠ the conversion tool's constants (MAME blue ≈
`(25,144,255)` vs tool `(0,0,255)`, the latter confirmed in `harness/tools/palette_derive.py`)
— a "ground truth" file with `(0,0,255)` is a tool render. **Automated-check tautology:**
"N/N pixels match the rule" is tautological if the rule generated the predictions — validate
against independently-grounded pixels. *Candidates:*
`tool-render-is-not-a-mame-capture-verify-by-pixel-colour`,
`automated-check-tautology-validate-against-ground-truth-not-rule-predictions`. *Established:*
standing; Content Wave 1 (commit `0b5825b`).

**`-nothrottle` snapshots lie for motion (cross-cutting, mirrored from the apple2e file §6).**
`-nothrottle` is fine for **traces** (full trace fast), but a `-nothrottle` **still-frame
snapshot manufactures phantom motion artifacts** — a mid-frame no-throttle grab ≠ the live
rendered frame. So a coco3 snapshot tool (`gate1_snap.lua` / `comp_snap.lua`, §13) is **not a
live gate**, and colour/position from a snapshot is not authoritative regardless — the on-screen
truth is Jay's live MAME (above). *Established:* the nothrottle/motion caveat +
`nothrottle-snapshots-unreliable-trust-live-gate`.

**Live-gate viewing flags (Jay's preference — viewing-only, no cadence change):**
```
mame coco3 -rompath C:\mame\roms -window -prescale 3 -resolution 1920x1152 -speed 8 \
     -autoboot_script tools\<gate>_live.lua
```
`-speed 8` (fast-watch; `-speed 16`/`-nothrottle` for max), `-prescale 3 -resolution
1920x1152` (3× window, size only). The `*_live.lua` loads the boot-excluded `.bin` and sets
PC. *Established:* `mame-live-gate-viewing-flags`.

### 11a. Prove a behavior-preserving RENDER refactor with a FRAMEBUFFER DIFF (not a re-gate)
For a "changed the code, not the output" refactor (extract a shared draw module, de-dup, reorganize
includes), the objective proof is a **framebuffer byte-diff**, not Jay's eye: dump **Frame A
`$8000-$BBFF`** (15360 B) at the driver's **hold PC** BEFORE the change, refactor, rebuild, dump
AFTER, `cmp` — require **byte-identical** for every affected driver. The pixel diff catches a
sub-visual one-pixel/one-colour drift the eye misses, is instant/repeatable, and doesn't spend a
human gate cycle (the live gate is for NEW visual behaviour). Pair with a single-source `grep` to
prove the structural goal (no duplicated routines remain). Dump via the same DECB-load Lua as the
`*_live`/`*_confirm` scripts, then `for a=0x8000,0xBBFF do o:write(string.char(mem:read_u8(a))) end`.
*Candidate:* `prove-a-render-refactor-with-a-framebuffer-diff-not-a-visual-re-gate`. *Established:*
scene-6 backdrop shared-include refactor (commit `7bfb24c`; both drivers pixel-identical pre/post).
Tool: `harness/tools/*` DECB-load pattern + a Frame-A dump.

### 11b. Render PNGs at NATIVE 1:1 square pixels — MAME `screen:snapshot()` STRETCHES
For oracle-vs-port **by-eye** matching, a MAME `screen:snapshot()` is NOT square-pixel: **apple2e
snaps are 560×192** — each logical HGR dot is rendered as **2 horizontal pixels** (280 logical → 560;
~97% of even-column pairs are identical, differing only at NTSC colour fringes), so at 1:1 the image
is ~2.9:1, badly horizontally stretched vs the real ~4:3 display. Precise visual matching is
impossible against a stretched render. **Fix (standing):** emit native-resolution 1:1 square-pixel
PNGs — **apple2e: halve the 560 width → 280×192** (NEAREST, keep the left of each pair; box-resize
blends the fringe); **coco3: decode the raw `$8000-$BBFF` framebuffer (2bpp MSB-first, 80 B/row) →
320×192** directly (already square, no MAME snapshot involved). Optionally **uniform integer upscale**
(×N NEAREST) for visibility — never fractional. Pixel-aspect is 1:1 **logical** (not 4:3 hardware-
corrected); use the SAME convention for both targets so an apple2e px X lines up with coco3 px X+20
(the port's +20 centering of 280-in-320). *Candidate:*
`render-native-square-pixel-pngs-mame-snapshot-stretches-apple2e-560-is-280-doubled`. *Established:*
wall-top reference capture 2026-07-14 (commit TBD). Tool: `harness/tools/render_square.py`
(`--apple2e <560png>` / `--coco3 <15360 dump>` / `--scale N`); pairs with `fbdump_stage.lua`.

### 11c. Render a cel PREVIEW in the REAL palette + a NON-palette transparency mark (decode the mask)
A sprite preview must use the **actual 4-index scene palette** the cel will ship in (0 blk / 1 orange
/ 2 blue / 3 white — MAME-authoritative RGB), and show **transparency in a colour that CANNOT occur
in that palette** (a **gray checkerboard**), with the convention **stated** in the image/report. Two
traps this avoids, both real defects on this project: (1) a **debug placeholder colour** (magenta)
reads as "the art is wrong" when it's a render artifact — Jay's gate flagged a magenta sheet whose
composite (same bytes) looked correct; the tell that it's the render not the art is *same source,
different output*. (2) The **index-0 collision**: opaque-black (`b`) and transparent (`t`) BOTH pack
to colour index 0 — distinguished ONLY by the mask plane. So a preview must **decode the MASK** (mask
00 → transparent-checker, 11 → `PALETTE[colour]`), not the colour index — ignore the mask and `t`
looks like whatever bg (blue), or a wrong flag paints it magenta. **Render FROM the packed
color+mask bytes** (and assert the decode matches the authored grid) so the preview is faithful to
what ships AND validates the packing. Emit **1:1 AND integer-NEAREST magnified** (factor stated).
*Candidate:* `render-cel-preview-in-real-palette-decode-the-mask-checkerboard-transparency-not-a-debug-colour`.
*Established:* wall post/rail preview fix 2026-07-15 (2nd preview defect after the 560-stretch).
Tool: `harness/tools/gen_wall_post_rail.py` (`render_from_planes`).
**Refinement (2026-07-16, HS-10):** DEFAULT the transparent background to the **real sky (index 2)** —
it shows the cel as it will actually appear (why the composite read right). Use the checkerboard
**only** when the cel's own palette **includes** the bg index (then sky is ambiguous). Post/rail
palette is {w=3,b=0} with no blue → sky default is unambiguous. `--bg sky|checker` (default sky).

### 11d. A cross-platform side-by-side MUST be reconciled onto ONE stated coordinate system
Comparing oracle (apple2e) vs port (coco3) pixel positions is worse than useless unless both are on
**one coordinate system with the mapping STATED** — else it invents a phantom offset. Apple HGR = 280
logical px (7 px/byte); CoCo3 = 320 px (4 px/byte); the bridge is the port's **+20 centering**:
`CoCo3_px = Apple_px + 20` ((320−280)/2), and the native oracle render is 280 wide (the 560 MAME snap
halved, §11b) → **pad it +20 left** into 320-space. Then integer-NEAREST only (no interpolation — it
blurs the boundaries being read), **stack vertically (oracle top / port bottom) with columns aligned**
(X-checking is the point, not literal left-right), overlay a **byte ruler** (4-px CoCo3 boundaries +
mark the target bytes), crop to the band, emit **1:1 + magnified**, and **print the mapping on the
image**. Sanity check the reconcile: oracle post (Apple col 23 sh5 = px166) +20 = **px186** must equal
the port target byte 46 sub 2 = 46*4+2 = **px186** — they land together only because sub 2 is the fix.
*Candidate:* `cross-platform-side-by-side-needs-one-stated-coordinate-system-plus20-integer-nearest`.
*Established:* wall-top placement side-by-side 2026-07-16. Tool: `harness/tools/walltop_side_by_side.py`.

### 11e. Decompose authored art into an OPAQUE block + uniform FILLS to avoid a masked-blit primitive
When authored art seems to need a per-pixel masked composite blit (opaque-black `b`=0 vs transparent
`t`=0, both index 0), **check whether the transparency is separable by geometry** before building the
primitive. The scene-6 wall post (9×7) put **every** `t` in **one column** (col 6) that is itself a
**uniform repeating rail** → the art decomposed into (a) **cols 0–5 = a fully-opaque block** (no `t`
anywhere → no mask; the plain opaque blit suffices — and `HAL_gfx_blit_sprite_opaque` DOES sub-byte
shift 0–3, sharing `blit_dispatch`), and (b) **col 6 = the rail = direct horizontal ROW-FILLS** (every
tiled column identical → white/black row-runs, no cel/mask/tiling). This **designed out** the
substantial Stage-4 masked-composite primitive entirely. **Assert the decomposition** (no `t` in the
opaque region; the transparent column == the fill pattern) — don't assume it. Watch the **§9a edge**:
an opaque *shifted* blit stamps the shifted-in leading pixels black (pre-shift with a sky-filled edge,
or flag for the gate). *Candidate:*
`decompose-authored-art-into-opaque-block-plus-uniform-fills-to-avoid-a-masked-blit-primitive`.
*Established:* wall-top 9×7 placement 2026-07-16 (`scene6_cliff_walltop.s`; framebuffer-diff-verified,
zero leak outside the band). The combatants may still need the primitive (non-decomposable art).
*Gotcha caught by the framebuffer-diff:* `ldd #colour` **clobbers B** — if a fill routine takes the
row in B, load the colour into **U** (survives `MUL`) instead; the diff flagged a stray row-0 fill.

---

## 12. Quick command idioms (coco3)
```bash
# Boot to DECB + drive it (needs disk11.rom present):
mame coco3 -flop1 <image.dsk>        # then natkeyboard:post 'LOADM"PROG"\r' / 'EXEC\r' (§2)
# Build an image:  imgtool ...        # .dsk = 18 sec/track fixed; DMK for track geometry (§3)
# Operator live-watch (§11):  -speed 8 -prescale 3 -resolution 1920x1152 -window -nomax
# Fast headless trace:  -nothrottle -video none -sound none -seconds_to_run <N> -script tools/<lua>.lua
# Headless DEBUGGER run:  add -debug AND unpause in Lua (execution_state="run", §10)
```
- **Windows-path-in-Lua gotcha (shared):** `"C:\k…"` is an invalid Lua escape → the script
  **silently fails** and MAME runs the full duration with **no tap, no error.** Use forward
  slashes (`C:/…`) or `\\`.
- **Script must be at MAME's cwd** (`-script tools/foo.lua` resolves from the run repo) —
  copy from `harness/tools/` if needed.
- **`-seconds_to_run` is EMULATED seconds**, not wall-clock; if a `-nothrottle` run drags for
  minutes real-time, throttle isn't in effect — fix the invocation.
- **Never mutate prod under a read pass:** `karateka.bin` `88eba89…` must stay byte-identical.

---

## 13. Tool index — which tool exercises each idiom
| Idiom | Tool |
|---|---|
| live visual gate (boot-excluded `.bin` + set PC) | `harness/tools/gate1_live.lua`, `gate2_live.lua`, `comp_live.lua` |
| gate trace / framebuffer verify | `harness/tools/gate1_trace.lua`, `gate2_trace.lua`, `decode_framebuffer.py` |
| GIME palette index derivation | `harness/tools/palette_derive.py` |
| sprite convert / parity / render | `harness/tools/sprite_convert.py`, `flip_parity_inplace.py`, `sprite_visualize.py` |
| snapshot capture (⚠ not a live gate) | `harness/tools/gate1_snap.lua`, `comp_snap.lua` |

---

## Appendix — candidate names (MAME cluster, coco3)
Sourced to specific disk-boot / FDC / GIME / display-init passes:
- `coco3-has-no-autoboot-entry-is-DECB`
- `mame-autoboot-and-interactive-are-mutually-exclusive-use-natkeyboard-post`
- `dsk-is-always-18-sectors-use-DMK-for-short-tracks` · `mame-dmk-writeback-hijack-proxy`
- `decb-directory-is-track-17-keep-raw-tracks-clear`
- `decb-loadm-overwrites-010C-irq-vector` · `decb-assumes-slow-does-not-force-slow`
- `mame-success-on-a-hardware-edge-question-is-not-a-hardware-guarantee`
- `gime-palette-writes-must-follow-video-mode-set`
- `6809-read-taps-work-6502-read-taps-dont`
- `tool-render-is-not-a-mame-capture-verify-by-pixel-colour`
  · `automated-check-tautology-validate-against-ground-truth-not-rule-predictions`
- **cross-cutting (shared, in the apple2e file's appendix):**
  `mame-frame-notifier-return-must-be-referenced-or-gcd`,
  `mame-debugger-printf-not-captured-headless-use-tracelog`,
  `mame-bp-action-tracelog-is-brace-free-trace-action-is-braced`.

---

## Cross-reference
The **Apple IIe / oracle** quirks (6502 read-tap bypass, watch-the-seed, seed-determinism of
the attract loop, `FD_STATEFORCE`, tap-every-draw-entry, trace-through-a-boundary,
`-nothrottle` motion-snapshot lie, boot-time-static bytes, the full debugger/Lua toolkit) are
in the companion **`mame-idioms-apple2e-oracle.md`**. The two targets differ most at §1/§10:
**6809 read-taps work; 6502 read-taps don't** — the single most important cross-target
difference. The debugger/Lua mechanics (`execution_state="run"` headless-unpause, `bpset`/
`wpset`, `b@`/`pb@`, `debugger:command`, trace+`tracelog`, the brace rule) and the
tap-GC/visual-provenance/`-seconds_to_run` gotchas are **shared** and appear in both files.

---

## Verify a VBL animation runs headless — sample the frame-index ZP + check for dwell-drift
To confirm a port ANIMATION actually runs (not just assembles), load the driver `.bin` into
coco3 (fbdump DECB-inject + set PC=exec, `harness/tools/fbdump_stage.lua` pattern) and sample
the controller's **frame-index ZP** (e.g. `cl_idx $40`, `cl_dwctr $41`) + `page_register $50`
every N frames. Two things fall out at once:
- **It runs** iff the index cycles through its range (crawl: `cl_idx` 0→6→0) and `page_register`
  toggles ($20↔$40 = double-buffer flipping).
- **Each render fits ONE VBL** iff the measured per-frame **dwell does not DRIFT** — if a heavy
  render (clean-restore + composite blit) overran its VBL, `HAL_time_vbl_wait` would miss the
  next VBL and the dwell would stretch run-to-run. Exact, stable dwells (21 / 7×5 / 60 VBL as
  authored) ⇒ the render completes within budget. This is a cheaper one-VBL-budget check than
  cycle-counting the render path. *Established:* climb-crawl first-animation build 2026-07-13
  (`scene6_climb_crawl_driver`, `climb_controller.s`).

### 11f. Verdict a placement on the OBSERVED framebuffer, never on the intended value
A placement report claimed "posts sub 2 → sub 1 → px 185" and was verdicted CONFIRMED on the *claim* —
the value that shipped was never measured. (It later turned out the sub-1 HAD landed, but that was luck,
not evidence.) **Fix the class like the art-bytes check does — with evidence:** (1) quote the placement
lines from the BUILT source (`grep`/`sed` of the real file post-edit, not a restatement of intent), and
(2) DUMP the framebuffer and report the OBSERVED pixel columns / band rows (`fbdump_stage.lua` +
per-pixel decode). If observed ≠ expected, STOP — do not reconcile in prose. Corollary: also measure the
CURRENT state before applying a "correction" — the delta may already be there (here the post was already
at px185, so "1px left" meant px184, not the dispatch's stated px185). *Candidate:*
`verdict-placement-on-the-observed-framebuffer-not-the-intended-value`. *Established:* wall-top placement
correction 2026-07-16 (`scene6_cliff_walltop.s`; posts measured at px184/268 post-edit).

### 11d. A "don't commit until X" hold needs an explicit RELEASE TRIGGER + SCOPE, or it strands work
The 07-12 Stage-3 WIP was held under *"don't commit Stage-3 until the static image is correct."* The
hold had **no release trigger and no scope**: when the static image *was* gated (the wall-top, months
later), nobody re-derived the hold, so the WIP sat in the working tree — and it had become
**load-bearing** (`scene6_backdrop.s`'s `draw_fuji_cels`/`fill_walltop` are called by the shipped
fallback). Consequences: (1) **the gated render was not reproducible from HEAD** — it lived only on
disk; (2) every subsequent *"file X unchanged"* byte-identity claim was **quietly ambiguous**
(unchanged vs HEAD, or vs the churned disk?). Confirm load-bearing cheaply before assuming: `git stash
<file>` → build → observe the failure (here: `Undefined symbol fill_walltop`/`draw_fuji_cels`) → pop.
**Rule:** a commit-hold must name (a) the exact **release trigger** and (b) its **scope** (which files
/ which change), or unrelated work accreting in the same working tree gets stranded and byte-identity
claims made afterwards are unsound. *Candidate:*
`a-dont-commit-until-X-hold-needs-an-explicit-release-trigger-and-scope`. *Established:* churn commit
2026-07-18 (`891dc63`).

### 11e. A transition/carryover artifact is ONLY visible in the LIVE sequence — per-item renders LIE
A **carryover** artifact (previous-pose pixels surviving into the next frame because the restore bbox
doesn't cover the previous pose's extent) exists **only in the running animation** — the state is
`restore-previous → draw-current`. **Rendering each pose standing alone on a clean substrate CANNOT
reproduce it** (there is no "previous" to leak), so every frame comes back innocent and the case is
**falsely closed**. This is exactly how the prior orange diagnosis answered the wrong question (it
tested the *substrate alone* at rows 152–168 — faithful, true — but the artifact is *carryover at the
player's lower body*). **Rule:** to capture carryover, run the gated build live and dump the DISPLAYED
framebuffer **once per pose, in sequence**, detected from the controller's frame index — never
independent per-pose renders. *Candidate:*
`carryover-artifact-only-in-live-sequence-per-item-renders-falsely-exonerate`. *Established:* per-pose
climb capture 2026-07-18 (`climb_pose_capture.lua`).

### 11f. Live per-pose capture: gate on the DWELL counter, not just the frame index (`cl_idx` reads 0 pre-init)
Capturing pose 0 of the crawl by "first frame where `cl_idx`($0040)==0, a couple frames after PC=exec"
grabbed a **half-drawn substrate**: the substrate blitting takes several frames after `PC=exec`, and
`cl_idx` reads 0 the whole time (ZP is 0 before `cl_init` writes it), and `page_register`($0050) still
read `$00` (uninitialized). The dump had only 123 rows of content vs 175–188 for real frames — an
invalid "anim_00." **Fix:** gate the capture on `cl_dwctr`($0041) `!= 0` — it is 0 until `cl_init` runs
`cl_load_dwell` (loads dwell 21) and is *never* left at 0 mid-crawl (`cl_tick` reloads it the same tick
it hits 0). So `cl_dwctr != 0` is the objective "init complete, pose 0 rendered on the fully-drawn clean
substrate" signal — the sanity anchor for HS-2 (anim_00 clean = clean **by construction**, first render
with no predecessor). Also: the DISPLAYED buffer = **opposite** of `page_register` (it holds the *back*
buffer; `cl_render` presents then toggles), so dump `(pr==$20)?$C000:$8000`. And per §11b, dump the
framebuffer **memory** and decode square-pixel — `scr:snapshot()` stretches and cannot show a 1px line.
*Candidate:* `gate-live-pose-capture-on-dwell-counter-not-frame-index-cl-idx-reads-0-preinit`.
*Established:* per-pose climb capture 2026-07-18.

### 11g. A mechanism that explains the artifact but NOT its exclusivity is incomplete — the negatives are the test
The anim_02 orange was diagnosed as double-buffer carryover: `cl_render` draws into the *back* buffer,
so a pose's carryover source is **two poses back** ⇒ anim_02 inherits anim_00 (the Y158 outlier, "must
draw below the box"). The story fit anim_02 perfectly — **and was wrong.** Computing every pose's drawn
extent from the pose table (`fcb col,sub,row` + cel `fcb height,width`) showed **all 7 poses are fully
contained in the restore bbox** (cols 20–32, rows 112–167); anim_00's bottom row is 165, *inside* 167.
So `cl_restore` repaints every pose's whole footprint — **zero carryover for ANY pose.** Empirical diff
of each captured displayed frame vs the clean substrate (buffer B at pose0): **orange outside a pose's
own body extent = 0, all 7 poses.** The real cause: anim_02's *own* cels introduce ~3–4× the orange of
the other poses (72 vs 18–39 introduced px) — pose-specific **cel content**, not a restore leak.
**Rules:** (1) a carryover claim must explain the **negative cases** (why NOT the other buffer-A poses)
— if it can't, it's incomplete → STOP, don't fix on a one-frame-fit story; (2) **compute the drawn
extent from cel dims before invoking an out-of-bbox mechanism** — "the low pose must overflow" is an
assumption, the `fcb height` is the fact; (3) diff against a **clean-substrate reference** (an untouched
double-buffer half is a free one) to separate cel content from carryover. This is the second time this
arc a plausible orange mechanism answered the wrong question (cf. the substrate-rows-152-168 finding).
*Candidate:* `carryover-claim-must-explain-the-exclusivity-compute-extent-from-cel-dims-not-assume`.
*Established:* anim_02 orange diagnosis 2026-07-18 (`anim02-orange-finding.md`).

### 11h. When the operator doubts an analysis, render the underlying DATA — and let it falsify the claim
The anim_02 "orange is in the cel data (72 px vs 18–39)" finding was argued from **framebuffer pixel
counts**. Jay doubted it (his eye has overruled analysis every time in this arc). The right response is
not more counts defending the finding — it is to **render the underlying data and let it falsify the
claim.** Decoding all 7 climb poses' cels straight from `converted.s` (per-pixel, mask/index-0 handled,
real palette, square-pixel) gave raw index-1 counts of **anim_02=126, but anim_04=88 / anim_05=92 /
anim_03=86** — i.e. **every pose's cels carry substantial orange; anim_02 is highest but ~1.4×, NOT the
3–4× outlier the earlier framebuffer numbers implied.** The two measurements differ because the prior
"introduced-vs-substrate within the bbox" count suppresses cel orange that lands on already-orange
substrate — a *different basis*, so the raw sheet **does not reproduce** the 72/18–39 ratio. **Rules:**
(1) an analysis-vs-eye dispute is settled by rendering the **data under test**, not by recounting;
(2) **state the measurement basis** — "orange introduced in the composited frame within the bbox" and
"raw index-1 px in the cel" are different numbers and conflating them manufactures a false
outlier/agreement; (3) present the falsifier **neutrally** — a result that undercuts your prior finding
is the method working, not a failure. *Candidate:*
`when-operator-doubts-analysis-render-the-data-to-falsify-state-the-measurement-basis`.
*Established:* climb-cel sprite sheet 2026-07-18 (`render_cel_sheet.py`).

### 11i. Entangled causes (what an index LOOKS like vs WHICH index a pixel is) — test ONE per render
The anim_02 orange had two live candidate causes: a **palette** change (alters what index 1 looks like)
and a **blue↔orange swap** (alters which index a pixel is). Rendered together, a "fixed" frame can't
attribute the fix — and a *wrong pair can cancel out and look right* (a swap that's wrong plus a palette
that's wrong can land on a plausible frame). **Rule: one variable per comparison render.** Judge the
palette at the current cel data (no swap); run the swap at the palette under which the mismatch was
observed (here CURRENT `$1B`/`$26`). Only combine after each is settled independently. Corollary for the
swap test specifically: **report the NEGATIVE band too** — a blanket index swap is all-or-nothing, so it
must be checked against the rows that CURRENTLY match (here base rows 166/167), not only the mismatch
rows; if it fixes the mismatch band but breaks the matching band, it is **not a clean swap** — and that
is the finding, not a failure. *Candidate:*
`test-one-variable-per-render-a-wrong-pair-can-cancel-and-look-right-check-the-negative-band`.
*Established:* anim_02 palette/swap renders 2026-07-18.

### 11j. Scope a colour/swap test to the ARTEFACT under test — and read the FUSED view, not just per-pixel
Two follow-ons from the anim_02 arc. (1) **A global re-colour conflates sprite and substrate and voids
the result.** The first blue↔orange swap flipped *every* index-1 pixel and "broke base rows 166/167" —
but those are substrate, never part of the hypothesis; the test never tested the sprite-scoped claim.
To scope a swap to one cel, **replay its blit** (placement byte-col/sub/row + cel data, in draw order)
to build a per-pixel source mask, and **validate the replay against the real captured frame** (here the
sim matched pose_2 1404/1404 px) before trusting the mask. Mind draw order: the over-cel overdraws the
back-cel in the overlap, so the swapped region can be far smaller than the cel's extent — state the
visible rows so a scoping success isn't misread as partial failure. (2) **On striped/alternating content
the FUSED (1:1) read is the gate, not the per-pixel map.** Apple HGR artifact colour physically blends on
a composite display; discrete GIME indices don't — so a frame can be per-pixel correct yet read wrong, or
per-pixel wrong yet read right. Ship 1:1 (fused) AND the ×8 countable crop; the operator rules from the
fused view. And when a palette must change for the sandbox but prod builds from the same `src/`, apply it
in the **sandbox/fallback** (override after `HAL_gfx_init`), not shared `gfx.s`, or prod moves on rebuild;
prove palette-only with an **identical index-frame diff** (the RGB framebuffer diff is global and proves
nothing). *Candidate:*
`scope-swap-to-the-cel-via-validated-blit-replay-and-gate-on-the-fused-read-not-per-pixel`.
*Established:* anim_02 hybrid-apply + $A4A4 swap 2026-07-18.

### 11k. Asset-pipeline safety: catalog before converting; one pass / two outputs; derive geometry once
Two pipeline idioms (asset-side, recorded here per the pre-conversion-safety dispatch).
**(1) Before any bulk re-conversion, prove which assets are pure converter output — re-convert + diff.**
Hand-edited/authored work is **not reproducible from the oracle**; a bulk re-run **silently destroys** it.
The behavioural test beats a git-history read (it catches *converted-then-edited* that rode in on a bulk
commit): re-convert each cel fresh from the oracle to a **scratch dir** (never over `content/`) and byte-diff
the CEL DATA (H,W header + H*W bitmap; ignore comment/ORIGIN lines). Identical ⇒ pure ⇒ safe; ANY diff ⇒
protected. **Report the diff SHAPE, don't adjudicate:** LOCALISED (few bytes, an edge) = hand-edit;
SYSTEMATIC across the *whole* set = converter drift — opposite treatments. A localised edit that *recurs
across a themed subset but not the whole tree* (the Mt-Fuji edge-fill-to-`$AA`: 4 of 188) is an authored
edit, not drift. Over-inclusion is free; a wrong "safe" is not. Protection must be **structural** (a
checked-in protected manifest + a converter hard-stop that refuses to overwrite), never "remember not to run
it on those". Determinism is a precondition — verify same-input→same-output before trusting any diff.
**(2) When one artefact must be DERIVABLE from another, produce BOTH in ONE pass from a single
classification.** A second pass recomputes extents/trims independently and **shifts the result inside an
identically-sized box** — the converter already does this (`sprite_convert.py` trims leading/trailing
all-zero columns per-cel; a separate "clean" pass would trim a different count than "fringed" and mis-register
the sprite). Derive geometry once in the superset frame; the subset **inherits** the trim, never computes its
own. And the discriminating classification often lives in the decode's **branch structure**, not its output —
so filtering the output (e.g. "drop the chroma index") conflates categories that need opposite treatment
(edge fringe vs a solid coloured body). *Candidates:*
`catalog-by-reconvert-diff-before-bulk-convert-report-shape-protect-structurally`,
`one-pass-two-outputs-derive-geometry-once-or-a-second-pass-shifts-inside-the-same-box`.
*Established:* pre-conversion-safety dispatch 2026-07-18.

### 11l. MAME coco3 HAS a Monitor Type config (Composite default / RGB) — set it via the screen_config ioport
**CORRECTION (supersedes the earlier "no toggle" claim — that was wrong; Jay was right there is an RGB
switch).** MAME `coco3` has a **"Monitor Type" machine configuration**: ioport tag **`:screen_config`**,
mask 1, **`Composite`=0 (default)** / **`RGB`=1** (visible in `-listxml coco3`; there is also a separate
`gime:artifacting` config). The earlier search failed because **`-listconfig` is not a MAME command** (it
errors "unknown option") — the configs are enumerated by **`-listxml`**, not a `-listconfig` flag, and I
stopped too early. **It is a MACHINE CONFIG, not a CLI flag** — there is no `-monitor`/`-rgb` command-line
switch; set it either in the MAME UI (TAB → Machine Configuration → Monitor Type) which persists to
`cfg/coco3.cfg`, or **headless from Lua**: find the field named `"Monitor Type"` on port `:screen_config`
and set `field.user_value = 1` (RGB) / `0` (Composite) **before the palette registers are written**, then
snapshot (`monitor_mode_snapshot.lua`). **Measured, same climb frame, same GIME regs $00/$26/$2D/$3F:**
| reg | Composite (default) | RGB (Monitor Type=1) |
|---|---|---|
| `$26` orange | (245,115,58) | (255,85,0) |
| `$2D` blue | (54,179,247) | **(255,0,255) magenta** |
| `$1B` blue | (94,44,255) | (0,255,255) cyan |

RGB mode = the digital bitpack (R1 G1 B1 R0 G0 B0, 2b/channel); Composite = the intensity/hue artifact
decode. **The palette study + everything gated so far was judged through the DEFAULT = Composite.**
Consequence for the RGB clean-vs-fringed gate: **MAME CAN show the RGB-monitor look** — set Monitor
Type=RGB; no real hardware or external decode tool required for that gate (hardware is still needed only
for true-silicon fidelity, per 25.3-H). **Gotcha:** set the config **once, early** (before the fallback's
`HAL_gfx_init` palette write) and let the mode settle before snapshotting — re-asserting it on the grab
frame catches a mid-transition geometry change and yields a truncated PNG. *Candidate:*
`mame-coco3-monitor-type-is-a-screen_config-ioport-composite-default-rgb-set-via-lua-not-a-cli-flag`.
*Established:* MAME mode-check + correction 2026-07-18 (`monitor_mode_snapshot.lua`).

### 11m. Fix a per-cel systematic bug by DERIVING the parameter from ground truth, not a hand-override list; verify the RULE against a control
The climb chroma-parity was set by a `pick_parity('orange')` heuristic + a hand-maintained `FLIP_OVERRIDE`
list — which silently inverted `$A4A4` (it passed its hue gate while blue↔orange swapped). The right fix
for a **systematic per-cel bug** is to **derive the parameter from ground truth** — here each cel's
**traced render column** (`start_col = byte_col*7 + sub`), the same model the cliff cels already used — so
parity is correct by construction, no heuristic and no exception list. **Verify the RULE, not every
asset:** (1) it must **reproduce every existing hand-override automatically** (they become derivations —
if any isn't reproduced, the rule is incomplete → STOP); (2) it must flip a **known control** (`$A4A4`
MUST flip, Jay-ruled — if it doesn't, the rule is wrong → STOP). Prove both in a **scratch** re-convert +
byte-diff before touching `content/`; adopt only the cel(s) whose DATA changed; **framebuffer-diff** the
one render that moves and surface it — don't self-certify. **Parity fixes which index a pixel gets, not
its look ⇒ no hue-gate re-run.** *Candidate:*
`derive-the-systematic-parameter-from-ground-truth-not-an-override-list-verify-the-rule-against-a-control`.
*Established:* column-parity fix 2026-07-18 (`stage3_convert_climb.py`; A4A4 the missed cel).

### 11n. coco3 `gime:artifacting` = the composite NTSC artifact-colour model (Off/Standard/Reverse) — a NO-OP for palette-mode content
`-listxml coco3` config `Artifacting` (tag `gime:artifacting`, Off=0/Standard=1/Reverse=2) on the coco3
GIME (`gime_ntsc`) device — distinct from the CoCo1/2 VDG `:artifacting`. **It is classification A (an
emulator composite-render model), not a monitor-independent GIME register:** "artifacting" with a
Standard/Reverse *phase* is the composite NTSC artifact-colour model (the GIME has no such register; the
phenomenon lives only on the composite signal), and measured behaviour is **RGB-invariant** to it.
**Load-bearing:** it is a **NO-OP for Karateka** — measured, the same frame renders **pixel-identical**
across Off/Standard/Reverse under BOTH Monitor Types — because Karateka uses the GIME **4-colour palette
mode**; artifacting only applies to the **1-bit/2-colour high-res modes** where alternating pixels artifact
into colour. **Rule:** classify an emulator "artifacting" option by what it DRIVES (composite artifact
phase ⇒ A) not its name, enumerate exhaustively (§2A.4) before concluding scope, and **exercise it on
representative content** — a knob that does nothing on palette-mode frames is irrelevant regardless of its
A/B label. Set it (like Monitor Type) via the `Artifacting` field `user_value` on port `:gime:artifacting`
(`gime_artifact_snapshot.lua`); there is no CLI flag. *Candidate:*
`coco3-gime-artifacting-is-the-composite-artifact-model-a-no-op-for-palette-mode-content`.
*Established:* GIME-artifacting recon 2026-07-18.

### 11o. A two-record post-mortem is corroborated by INDEPENDENT reconstruction, then reconciliation
When two parties each hold half of a history (here: the executor's trace/build/commit record and the
Orchestrator's planning/verdict record), the value is the **cross-check**, and it only works if each half
is reconstructed **independently first** — read the other record before drafting yours and you anchor to
it, turning corroboration into transcription. Draft from your OWN artifacts (commit spine, reports, diffs,
hashes), THEN diff against the other and build an agree/disagree/coverage-gap table; **flag discrepancies,
don't smooth them; surface conflicts for the ground-truth owner, don't resolve them unilaterally.** And
**no invented precision** — if a SHA/measurement isn't in your record, "not in my record" is a valid,
useful entry (it shows which claims only one half supports); echoing the other record's number as if
independently confirmed defeats the exercise. If the other record is **inaccessible**, say so and provide
your side's discrepancy-candidates as inputs to the table rather than faking the diff. *Candidate:*
`two-record-postmortem-independent-reconstruction-then-reconcile-never-read-the-other-first`.
*Established:* post-mortem Vol II 2026-07-18.

### 11p. Preview coco3 RGB-monitor palette candidates by the BITPACK decode (= MAME Monitor Type=RGB), not per-candidate snapshots
To build an RGB palette-selection panel square-pixel, render the index frame with each candidate's **bitpack
RGB** (6-bit value → R1G1B1R0G0B0, 2 bits/channel scaled 0/85/170/255) — this is **exactly what MAME renders
under Monitor Type=RGB** (verified: `$19`→(0,170,255), `$26`→(255,85,0), `$34`→(255,170,0), `$2D`→(255,0,255),
`$1B`→(0,255,255)). It avoids MAME's stretched 640-wide snapshots and lets one image sweep many candidates.
**Verify the mode took** by measuring one candidate in real MAME RGB (`rgb_palette_snapshot.lua`: set the
Monitor Type field + poke `$FFB1`/`$FFB2`) — the framebuffer must show the RGB triple, not the composite one.
And **value-verify the composite anchor** before building the panel (poke nothing, Monitor=Composite → assert
the recorded hybrid `$2D`→(54,179,247)/`$26`→(245,115,58); mismatch = drift, STOP). Finding worth surfacing:
in RGB mode the digital bitpack can land **closer to the oracle** than the composite decode (C1 blue `$19`
d36 / orange `$26` d36 vs composite `$2D` d46 / `$26` d60) — native-strong RGB may beat the composite look;
the fused 1:1 read decides, not the metric. *Candidate:*
`preview-rgb-palette-candidates-by-bitpack-decode-equals-mame-monitor-type-rgb-verify-the-anchor`.
*Established:* RGB palette selection study 2026-07-18.

### 11q. Two palettes for one build = a two-row table + a boot-time selection byte (NEVER monitor-detect)
The CoCo3 GIME emits composite AND RGB simultaneously and the **6809 cannot read which monitor is
attached** — so "which palette" is a **boot-time CHOICE per monitor, not an auto-detect**. Land it as a
named `palette_sets` table (4 bytes/row = `$FFB0..$FFB3`) with one row per look, and a `pal_select` byte
(a runtime byte a future boot menu can write) read at boot; `apply_palette` does `pal_select*4` (MUL) →
`leax d,#palette_sets` → copy 4. Keep the two sets a **one-entry difference** where possible (here composite
`$00,$26,$2D,$3F` vs RGB `$00,$26,$19,$3F` — only index 2/blue differs) so the two looks are provably the
same art under a different decode. Build the variant with `lwasm -DPAL_SEL_DEFAULT=1` (guard the default
with `ifndef`), not an edit/revert. Verify BOTH variants against their monitor: composite+Composite →
(54,179,247)/(245,115,58) unchanged (regression), RGB+RGB → (0,170,255)/(255,85,0). Identical pixel COUNTS
across variants prove the index frame is untouched (palette is a pure index→RGB remap; the parity fix and
the palette compose orthogonally). *Candidate:*
`two-palette-sets-one-build-selection-byte-at-boot-never-monitor-detect-one-entry-diff`.
*Established:* RGB palette landing 2026-07-18 (`scene6_climb_crawl_driver.s`).
