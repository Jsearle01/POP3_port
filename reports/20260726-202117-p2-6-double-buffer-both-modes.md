## Form B Report — P2.6 — VBL study + double-buffering both modes + live animation proof
**Class:** BUILD — interrupt study, double-buffer completion, §2A.3 reconciliation, live-gated animation.
POP `wip` (service + probe + harness + idioms) and Karateka `wip` (shared source, service gated OFF).
**Karateka `main` UNTOUCHED at `5eb92b1`.**
**Karateka prod byte-identity: `88eba89b15cdf17c8d25e082d2d3e1f3cce57d38`, 17,978 bytes — HELD.**
**25.3 LIVE animation gate: PENDING JAY.** Presented live, all five stages ran; nothing self-certified.

### 0 — Receipt / status (C-35 stamp)
t0=2026-07-26T20:21:17Z (POP HEAD `96860f4`, wip; tracked tree clean).
Karateka at receipt: `wip` `d40c41a`, `main` `5eb92b1`, clean. Sync bridge live and passing.

---

### 1 — Summary

**All four phases delivered. The study paid for itself inside the same dispatch.**

| | |
|---|---|
| Phase 1 — VBL study | POP is **classification (b)**: HAL complete, caller must invoke in documented order |
| Phase 2 — double-buffer | **both modes**, one model, VBL-synced `HAL_gfx_swap`; the 60 KB worry was an error |
| Phase 3 — §2A.3 | **phantom** — no ruling was ever pending; the real debt was a filing lapse, now filed |
| Phase 4 — animation | **27/27** self-check; +150 swaps/stage, contrast stage exactly 0 |
| Karateka | **byte-identical**, 6/6 informative tests PASS |
| **25.3 live gate** | **PENDING JAY** |

**Phase 1 found a show-stopper and then I walked straight into it — which is the study working.**
POP's `irq_vbl.s` and `time.s` are byte-identical to Karateka's, so the mechanism is complete. What is
required is the **documented init order**, and skipping step 0 (`HAL_sys_init`) produces an interrupt
storm: the PIAs assert IRQ independently of the GIME's `IRQENR`, PIA0 on horizontal sync at ~15.7 kHz,
and a handler that ACKs only by reading `$FF92` never clears it.

**The expensive part is that the VBL path looks HEALTHY while this happens.** The frame counter advanced
1:1 with real frames. What failed was everything else — a clear loop that should take 6 frames never
finished. It reads as a hung graphics routine. PC-band sampling named it: **42% of samples inside the
ROM → `$010C` dispatch path**. `sys.s` already records the identical failure from Karateka's R-boot
investigation ("833,172 times per 30 seconds in MAME"); I reproduced it exactly by skipping the call.

**The second trap is quieter and would have survived to Jay's eye.** `HAL_time_vbl_wait` does **not**
wait when `CC.I` is set — it takes its documented Q001 N3=β fallback and returns immediately. A caller
that leaves interrupts masked gets a swap loop running flat out, flipping VOFFSET at arbitrary raster
positions. It compiles, it runs, the counters advance, and it tears. `HAL_time_init` deliberately will
not clear `CC.I` (the E1.c invariant), so `andcc #$EF` is the caller's job and nothing reminds them.

**The 60 KB constraint I recorded in P2.5 was wrong, and worth stating plainly.** It reasoned about the
CPU's view instead of the machine's. Framebuffers are addressed by the GIME's VOFFSET (`physical / 8`);
the CPU only ever sees an MMU-mapped window. There is no memory wall and there was never a forced
choice — 16-colour double-buffers exactly like 4-colour.

**§2A.3's "21 deferrals" was a phantom.** §2D reserves Orchestrator authorship for "decision records,
post-mortems, behavioral models"; an idioms file is none of those, and §2A.3 rule 3 explicitly instructs
Clyde to add to it — which happened for seven commits through P1.3-fix, then **lapsed** at P2.1. Nothing
was ever waiting on a ruling. The counter incremented on nothing while five dispatches' idioms
accumulated in source comments. Filed as §19 and §20; counter retired.

---

### 2 — Files modified

**POP `wip` (commit `4b8ea94`):**
- `src/hal/coco3-dsk/gfx.s` — double-buffer geometry, `HAL_gfx_swap`, `gfx_map_blocks`,
  `gfx_clear_window`, published draw base / back index / swap counters. All inside `HAL_GFX_MODE_SERVICE`.
- `src/hal.inc` — the double-buffer contract, `HAL_gfx_swap`, the CC.I trap, and the new **caller stack
  requirement** (§3.5).
- `src/harness/anim_probe.s` — **NEW**. 5-stage animated probe including the no-swap contrast.
- `src/harness/mode_probe.s` — repointed at `HAL_gfx_draw_base`, stack moved, draws into both halves.
- `harness/smoke/anim_test.lua`, `run_anim_test.sh`, `anim_live.lua` — **NEW**.
- `harness/smoke/mode_test.lua` — framebuffer reads follow the draw base.
- `mame-idioms-coco3-port.md` — **§19 (object/linked build) and §20 (interrupt discipline)**, the
  Phase-3 filing.
- `build.bat` — assemble/link the animation probe, `ANIM.BIN` on the disk.

**Karateka `wip` (commit `58cad3e`) — shared source only, gated OFF:** `src/hal.inc`,
`src/hal/coco3-dsk/gfx.s`.

**Not modified:** Karateka `main`; Karateka's `build.bat`; `HAL_gfx_init` (§3.4); engine code;
`oracle/source/`.

---

### 3 — Reasoning

#### 3.1 — Phase 1: the study (AC1)

**Karateka's approach**, read from the adopted source: `HAL_time_init` zeroes the counter, patches
`$010C` with `JMP hal_vbl_handler`, writes `$FF93=0` and `$FF92=$08` (VBORD **only**) *before* raising
`IEN` in `$FF90` (so no IRQ asserts from stale boot state mid-sequence), and leaves `CC.I` alone. The
handler reads `$FF92` (ACK — clears **all** GIME flags, which is why only one source may be enabled),
tests bit 3, increments the counter, `rti`. `HAL_time_vbl_wait` spins on the counter changing.

**POP's status: (b) — the HAL provides the mechanism; the caller must invoke it correctly.**
`irq_vbl.s` and `time.s` are byte-identical to Karateka's (verified by `diff` after EOL normalisation).
No gap to fill. The failure modes are all caller-side, and both bit me (§1).

**The sequence the animation uses:**
```asm
        jsr   HAL_sys_init      ; step 0 — silence the PIAs, or nothing else runs
        jsr   HAL_time_init     ; install $010C, VBORD only, IEN=1
        andcc #$EF              ; CLEAR CC.I — HAL_time_init deliberately will not
        lda   #<mode>
        jsr   HAL_gfx_set_mode
  loop: ... draw at HAL_gfx_draw_base ...
        jsr   HAL_gfx_swap      ; wait VBL, show it, remap the other half
```

*(A self-inflicted detour worth recording: my first cross-repo comparison of these files used Python's
`hash()` in two separate processes and reported DIFFERS. String hashing is salted per process, so that
comparison can never match. `diff` showed the files identical. The tool was broken, not the files.)*

#### 3.2 — Phase 2: the double-buffer (AC2)

**Placement, verified rather than guessed** (hard-stop 12.4):

| | physical | blocks | VOFFSET (`phys/8`) |
|---|---|---|---|
| buffer A | `$20000` | `$10-$13` | `$4000` |
| buffer B | `$30000` | `$18-$1B` | `$6000` |

512 KB confirmed from `mame coco3 -listxml`: `<ramoption name="512K" default="yes">524288</ramoption>`.
32 KB reserved per buffer (16-colour's 30,720 B rounded to the 8 KB block granularity); 4-colour uses
15,360 B of the same reservation, so **only the size differs per mode** — the addresses are
mode-independent, which is what makes it one model rather than two.

**Why not the top 64 KB.** The CoCo3 boots with CPU `$0000-$FFFF` mapped to physical `$70000-$7FFFF`, so
a buffer placed there overlaps the running program — this program is at CPU `$0200` = physical `$70200`
with its kernel at `$73000`. Drawing into such a buffer overwrites the code doing the drawing.

**Why the draw window is `$6000` and not `$8000`.** A 32 KB window at `$8000` needs `$FFA7`, which maps
CPU `$E000-$FFFF` — the stack and vector area. Basing at `$6000` (`$FFA3-$FFA6`) leaves `$E000-$FFFF`
permanently untouched. It costs nothing and removes a whole class of failure.

**`HAL_gfx_swap` order is load-bearing:** wait for VBL → write VOFFSET to the just-drawn buffer → toggle
and remap. Writing VOFFSET mid-scanline switches the GIME's source address while it is drawing, which is
a visible tear.

#### 3.3 — Phase 2: clear-on-switch, extended

The contract now clears **both** halves, because the first swap reveals the other one. Each is mapped in
turn; the clear length comes from the same published `HAL_gfx_cur_words` the caller reads, so "how big is
the screen" has one source and cannot disagree with itself.

#### 3.4 — §7.4 reconciled — one model, and why `HAL_gfx_init` was left alone

`HAL_gfx_set_mode` is the model going forward: double-buffered, physical buffers, MMU-mapped drawing,
VBL-synced swap. `HAL_gfx_init` remains Karateka's shipping 4-colour path with its CPU-window buffers at
`$8000`/`$C000`.

**I did not refactor it into a special case of `set_mode`**, and the dispatch explicitly allowed that
judgment ("don't force a refactor if risky"). It has 25 live call sites in Karateka and its buffer
addresses are baked into `HAL_gfx_present`, `HAL_gfx_clear` and the scene drivers; changing them would
move Karateka's binary and its tests. The models agree in the sense that matters — there is one model
POP uses and one legacy path clearly marked as such — but they are not unified, and that is a stated
deferral rather than a claim of completion.

#### 3.5 — A contract addition the build surfaced

`set_mode` remaps `$FFA3-$FFA6`, so **the caller's stack must not live in CPU `$6000-$DFFF`**. DECB
leaves `S` at about `$7F2B`, inside it. `mode_probe` had worked for two dispatches and hung the moment
`set_mode` gained its MMU mapping — no warning, the call simply never returns. Documented in `hal.inc`;
`mode_probe` now moves its stack to `$1F00` (MMU block 0, never remapped).

#### 3.6 — Phase 3: the §2A.3 reconciliation (AC3)

**True state.** `mame-idioms-coco3-port.md` is the home, is tracked, and was actively maintained: seven
commits (P1.0, P1.1, P1.2, P1.2b, P1.2-fix, P1.3, P1.3-fix). The practice then **lapsed** from P2.1
onward — P2.1 through P2.5 recorded idioms in source comments and reports while the report counter
climbed to twenty-one.

**The ruling was never pending.** §2A.3 rule 3 is unambiguous, and §2D's scope is "decision records,
post-mortems, behavioral models" — an idioms file is a §2A *reference* file that §2A.3 tells Clyde to add
to. P1.1 filed "provisionally" against a question that did not need answering.

**Action:** filed the lapsed P2.1–P2.6 idioms as **§19** (four object-only directive classes;
`--section-base` silently ignored; `lwlink` only errors on *referenced* undefined symbols; multi-segment
DECB gating; the confirmed `$FF99` values; the deliberate GIME-RM §14 ordering divergence; physical-RAM
double-buffering; and §19h recording this reconciliation) and **§20** (the PIA storm, the `CC.I` trap,
VBORD arming, the `natkeyboard` quote failure, signed accumulator offsets). **Counter retired.**

*Also noted:* `POP-idioms-coco3-markers.md` sits untracked at the repo root. It is an Orchestrator-authored
work order whose edits were already applied and committed in P1.2b (`4a7232e`) — leftover scaffolding, not
pending work. Flagged rather than deleted; removing an Orchestrator-authored file is not mine to decide.

#### 3.7 — Phase 4: the animation, and my own two bugs (AC4)

Five stages: 16 → 4 → 16 → 4 animated, then a **NO-SWAP contrast** stage that defeats the buffering
deliberately by drawing into the displayed buffer. Static content cannot prove double-buffering; only
motion reveals a tear. The contrast stage is what makes "smooth" mean the swap is *doing* something.

**Bug 1 — 6809 accumulator-offset indexing is SIGNED.** In `leax a,x` the offset is −128..+127, so a
16-colour stride of 160 is **−96**: the draw pointer walked backward out of the framebuffer and through
the kernel until the probe executed itself at `$6001`. Offsets now go through `D`.

**Bug 2 — the full-buffer clear per frame ran it at ~6 fps.** Erasing only the bar's own 16 columns fixed
it. That is a double-buffer problem in miniature: the stale bar in *this* buffer is from **two** frames
ago, so the old position is tracked per buffer.

**One harness over-specification, corrected.** I first asserted swaps ≈ frames 1:1. That is wrong — a
frame taking longer than one VBL legitimately yields fewer swaps than frames. The honest invariant is
`swaps <= VBL frames` (every swap waited for at least one blank). I also measured stage duration with the
probe's own published counter, which is only written *after* a stage's first swap, so the boundary
snapshot belonged to the previous stage and produced nonsense deltas (`+57312`). Switched to MAME's
`frame_number` — an independent clock with no such coupling.

---

### 4 — Verification (AC-by-AC)

- **AC1 — study done FIRST, POP classified, sequence stated. MET.** §3.1. Classification **(b)**; no deep
  gap, so hard-stop 12.2 did not trigger — but two caller-side traps were found and both were hit.
- **AC2 — double-buffered both modes, VOFFSET math verified, §7.4 reconciled. MET.** §3.2/§3.4. 512 KB and
  the `phys/8` values confirmed from `-listxml` and GIME-RM §13 respectively.
- **AC3 — §2A.3 resolved. MET.** §3.6. Phantom identified, lapse filed as §19/§20, counter retired.
- **AC4 — animation proves it in both modes; mechanism self-verified. MET.** 27/27; +150 swaps per
  animated stage; back-buffer alternates; contrast stage exactly 0 swaps.
- **AC5 — Jay's LIVE gate. PENDING JAY.** Presented live (throttled, RGB, 3×, direct-load); all five
  stages ran to completion. The bonus contrast stage is included. **Not self-certified.**
- **AC6 — one kernel; Karateka unaffected. MET.** Sync bridge green both directions; binary byte-identical;
  6/6 informative tests PASS.
- **AC7 — no engine code; clean status. MET.**

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 — the interrupt storm, measured before the fix (verbatim):**
```
n=1    PC=$31D3 ... words=$3C00 drawbase=$6000 back=0 swaps=$0000 | probe: stage=0
n=240  PC=$010E ... words=$3C00 drawbase=$6000 back=0 swaps=$0000 | probe: stage=0
# --- where the CPU actually spends its time (600 samples) ---
  clear_window   203      vbl_handler    113      other($30B6)  136
  $FED3 12  $FEFA 20  $010C 12  $010D 12  $010E 13  $010F 25  $FEF7 23  $FEF8 10  $FEF9 10
  -> 42% of samples in the ROM -> $010C interrupt-dispatch path
```
Published geometry was CORRECT throughout (`mode=1 vres=$1E stride=160 words=$3C00 palcnt=16`) — the
graphics code was fine; it was being starved.

**25.1 — after adding `HAL_sys_init` (step 0), and after the signed-offset fix (verbatim):**
```
n=40   PC=$02E4 S=$1EFC ... back=0 swaps=$0000 | probe: stage=1
n=80   PC=$02E4 S=$1EFC ... back=0 swaps=$0004 | probe: stage=1
n=240  PC=$02E4 S=$1EFC ... back=0 swaps=$0014 | probe: stage=1
```

**25.1 — 512 KB confirmed, not assumed (verbatim):**
```
<ramoption name="128K">131072</ramoption>
<ramoption name="512K" default="yes">524288</ramoption>
```

**25.1 — the P2.6 ABI resolved at link (verbatim):**
```
Symbol: HAL_gfx_swap      (hal_build.o) = 3184
Symbol: HAL_gfx_draw_base (hal_build.o) = 31FE
Symbol: HAL_gfx_cur_back  (hal_build.o) = 3200
Symbol: HAL_gfx_swaps     (hal_build.o) = 3202
Symbol: HAL_time_init     (hal_build.o) = 3058
Symbol: HAL_time_vbl_wait (hal_build.o) = 3078
```

**25.1 — THE ANIMATION SELF-CHECK (verbatim, abridged to the shape):**
```
stage1_16-colour_swaps_advanced      PASS +150 swaps over +459 MAME frames
stage1_16-colour_vbl_paced           PASS 150 swaps <= 459 MAME frames
stage1_16-colour_back_alternates     PASS back-buffer indices seen: 2
stage2_4-colour_swaps_advanced       PASS +150 swaps over +467 MAME frames
stage3_16-colour back_swaps_advanced PASS +150 swaps over +459 MAME frames
stage4_4-colour back_swaps_advanced  PASS +150 swaps over +467 MAME frames
stage5_16-colour NO-SWAP_no_swaps    PASS +0 swaps (want 0), over +450 MAME frames
all_five_stages_ran                  PASS last stage 5
vbl_irq_live                         PASS HAL frame counter reached 15525
# checks=27 passed=27 failed=0
# VERDICT: PASS
```
The asymmetry is the point: 150 swaps in each animated stage and **exactly 0** in the contrast stage is
what makes the swap counter evidence rather than decoration.

**25.1 — regressions + Karateka (verbatim):**
```
[run_mode_test] PASS      (14/14, under the new double-buffer model)
[run_probe_test] PASS
[run_compiled_test] PASS
P2.4 baseline : 88eba89b15cdf17c8d25e082d2d3e1f3cce57d38
P2.6 (now)    : 88eba89b15cdf17c8d25e082d2d3e1f3cce57d38
*** BYTE-IDENTICAL ***
run_gfx_init_precheck PASS   run_sys_init_test PASS
run_gfx_init_test PASS       run_timer_framesync_test PASS
run_kernel_dispatch_test PASS run_vbl_irq_test PASS
```

**25.2 — artifacts:** `src/hal/coco3-dsk/gfx.s`; `src/hal.inc`; `src/harness/anim_probe.s`;
`harness/smoke/anim_test.lua` + `run_anim_test.sh` + `anim_live.lua`;
`mame-idioms-coco3-port.md` §19–§20. POP `wip` `4b8ea94`; Karateka `wip` `58cad3e`; `main` `5eb92b1`.

**25.3 — OPERATOR RUNTIME SMOKE — PENDING JAY. This is THE validation.**
Double-buffering correctness is TEMPORAL — a tear is about *when* a VOFFSET write lands relative to the
raster. No byte check sees it, which is why 27/27 is corroboration and not a verdict. Presented live,
throttled (not `-nothrottle`, which manufactures motion artifacts — idiom §11), RGB, 3× window:
```
# poked   311 bytes -> $0200
# poked   628 bytes -> $3000
# PC <- $0200 at frame 120 -- running
# stage 1  16-colour ANIMATED                        $FF99=$1E stride=160 swaps=0    (frame 154)
# stage 2  4-colour  ANIMATED                        $FF99=$15 stride= 80 swaps=150  (frame 613)
# stage 3  16-colour ANIMATED (switched back)        $FF99=$1E stride=160 swaps=300  (frame 1080)
# stage 4  4-colour  ANIMATED (switched back)        $FF99=$15 stride= 80 swaps=450  (frame 1539)
# stage 5  16-colour NO-SWAP CONTRAST                $FF99=$1E stride=160 swaps=600  (frame 2006)
# all five stages done.
```
**Jay's call: smooth motion and no tearing in 4-colour AND 16-colour, and whether stage 5 visibly breaks
up where 1–4 do not.** Not self-certified.

---

### 6 — Reactive deviations

1. **Two dead live runs before the working one.** `LOADM"ANIM"` reached DECB as `LOADMBANIMB` / `?SN ERROR`
   — MAME's `natkeyboard` delivered each `"` as the letter **B**. Confirmed by dumping the text screen at
   `$0400`. Intermittent: the identical string succeeded in the automated run in the same session. **Jay
   reported it**; I had relaunched once without checking that the first run got past loading. The live
   view now direct-loads and never touches the keyboard; `LOADM` stays in the automated test. Filed as
   idiom §20d.
2. **A new probe file rather than editing `mode_probe.s`** — P2.5's probe is a Jay-gated artifact and
   rewriting it would destroy what was gated. `anim_probe.s` extends the same cycle with motion.
3. **`mode_probe.s` and `mode_test.lua` did need updating** — `set_mode` now maps the back buffer at
   `$6000`, so the P2.5 probe would have drawn into unmapped memory and shown black. It now reads
   `HAL_gfx_draw_base`, moves its stack (§3.5) and draws into both halves. 14/14 again.
4. **`HAL_gfx_init` deliberately NOT refactored** (§3.4) — permitted by the dispatch, and stated as a
   deferral rather than dressed up as completion.
5. **The harness's swaps-vs-frames check was over-specified and its duration metric was wrong** (§3.7).
   Both corrected; the surviving invariant is weaker and true.
6. **A broken comparison tool briefly reported false drift** (§3.1) — Python `hash()` is salted per
   process. `diff` is the authority.

---

### 7 — Uncertainty flags

1. **Nothing here proves the absence of tearing.** 27/27 says swaps happen, are VBL-paced and alternate
   buffers. Whether a flip ever lands mid-raster is Jay's eye. That gap is the whole reason for 25.3.
2. **The two buffer models are reconciled in policy, not in code** (§3.4). `HAL_gfx_init` still uses
   `$8000`/`$C000` with no MMU involvement. A caller that mixes `HAL_gfx_init` and `HAL_gfx_set_mode` in
   one program would get incoherent state, and nothing prevents that.
3. **`HAL_gfx_swap` does not gate on the raster position, only on the VBL wait.** If a draw overruns a
   frame the swap happens at the next blank; if `HAL_time_vbl_wait` returns early for any reason the flip
   is unprotected. The `CC.I` trap is the known instance; there may be others.
4. **The 16-colour animation runs at roughly 1 swap per 3 frames** with a trivial 16-column bar. Real
   content at 4 bpp will be heavier. Nothing here establishes a frame budget for 16-colour animation.
5. **`HAL_gfx_cur_words` and the buffer reservation assume 32 KB per buffer.** A future mode needing more
   would overlap buffer B silently — the table has no bounds check.
6. **The PIA disable in `HAL_sys_init` is total** (all four control registers, bits 0-1). Any future work
   wanting keyboard or joystick interrupts must re-enable deliberately and will then need a handler that
   dispatches on source before reading `$FF92`.

---

### 8 — Follow-up candidates

1. **Unify the two buffer models** (§7.2) — make `HAL_gfx_init` a `HAL_gfx_set_mode(4-colour)` wrapper.
   Needs a Karateka-side decision because its binary and 25 call sites move.
2. **Establish a 16-colour frame budget** (§7.4) before animated content is designed.
3. **Bounds-check the mode table against the buffer reservation** (§7.5).
4. **Resolve the composite-vs-RGB palette comment in `HAL_gfx_init`** — still open from P2.5 §7.2.
5. **Enable `HAL_GFX_MODE_SERVICE` in Karateka** if it wants the service — still a one-flag change.
6. **Decide the fate of `POP-idioms-coco3-markers.md`** (§3.6) — applied in P1.2b, still untracked at the
   repo root.

---

### 9 — User interaction during task

1. The dispatch carried the design (study-first, uniform double model, the 4-stage cycle plus contrast).
2. **Jay reported `LOADM"ANIM"` producing a syntax error** during the live presentation. That was a real
   failure I had relaunched past without verifying — it led directly to root-causing the `natkeyboard`
   quote defect (§6.1) and to the direct-load live path. Two of Jay's viewings were spent on dead runs.
3. **25.3 is outstanding** — the live animation gate is presented and awaiting Jay's verdict.

---

### 10 — Candidate(s) captured this task
`seeds/POP/live/2026-07-26-a-healthy-looking-subsystem-can-be-the-alibi-for-the-broken-one.md` — a
partially-working system emits genuine healthy signals from the parts that still work, and those signals
point away from the fault when the failure is starvation rather than breakage; the unsticking question is
"where is the CPU actually spending its time?", answered with a distribution rather than a snapshot.
Committed and pushed.

---

### 11 — Commit
**POP:** `4b8ea94` (study + double-buffer + idioms + probe) + `52260c6` (this report) — pushed to `origin/wip`.
**Karateka:** `58cad3e` on `wip` — shared source, service gated OFF, binary byte-identical. Pushed.
**Karateka `main` @ `5eb92b1` — untouched.**

---

## ADDENDUM (post-report, same dispatch) — smoothness change, and a REGRESSION I introduced

Jay viewed the live animation and reported: **"looks ok, still a bit blinky."** That is a
partial pass with a real observation, so it is recorded as such — 25.3 is NOT discharged by
it.

**Diagnosis of the blinkiness: frame RATE, not tearing.** The inner paint loop was 16
single-byte stores per row plus loop overhead (~180 cycles/row). Two paints per frame (erase
+ draw) over 192 rows consumed the whole frame budget, so a swap only landed every third
VBL — a ~20 Hz update, which on a high-contrast bar reads as strobing. Replaced with eight
unrolled 16-bit stores (~64 cycles/row) and halved the bar step:

| | before | after |
|---|---|---|
| stage duration | ~460 MAME frames | **~308** |
| swaps per frame | 1 per 3.07 | **1 per 2.05** |
| effective update | ~20 Hz | **~29 Hz** |

**THE REGRESSION: `run_anim_test.sh` now FAILS at stage 5 (22/23), and I have not
root-caused it.** The probe FREEZES in the no-swap contrast stage when loaded via DECB
`LOADM` — `swaps` and the frame counter stop at identical values (600 / 1132) across runs
with different timeouts, so it is a freeze and not slowness. It does NOT reproduce under
direct load: a PC-band sample of stage 5 there shows 400/400 samples inside the probe with
the frame counter advancing 1:1, and all five stages complete. Stages 1–4 pass on both paths.

What I know, stated plainly because the shape matters:
- Before the smoothness change the same test passed 27/27 including stage 5, so **I
  introduced this**.
- The DECB path is *independently* flaky — a follow-up diagnostic run never reached stage 5
  at all, which is consistent with the intermittent `natkeyboard` quote defect (§20d) making
  that path unreliable run-to-run.
- Those two facts are easy to confuse, and I have not separated them. "It's just the keyboard
  bug" is a hypothesis, not a finding.

**Status: the suite is NOT green.** The live path Jay gates on is unaffected and verified
end-to-end, but the automated DECB-path test has a real, reproducible failure that is mine
and is outstanding. It is recorded here rather than re-scoped around.

**Superseding §5's 27/27:** that figure was accurate for the binary at the time it was
measured. The current binary measures **22/23 with stage 5 failing on the DECB path**.
