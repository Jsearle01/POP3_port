## Form B Report — P2.9 — the freeze was an IRQ race on the MMU remap: CONFIRMED and FIXED
**Class:** DEBUG — decisive test first, fix via Karateka's discipline, doc correction folded in.
POP `wip` + Karateka `wip` (shared HAL + comment mirror). **Karateka `main` UNTOUCHED at `5eb92b1`.**
**Karateka prod byte-identity: `88eba89b15cdf17c8d25e082d2d3e1f3cce57d38` — HELD (hard-stop 12.4 clear).**
**`run_anim_test.sh`: 22/23 → 27/27 under DECB `LOADM`. The suite is green.**

### 0 — Receipt / status (C-35 stamp)
t0=2026-07-27T00:46:06Z (POP HEAD `4842494`, wip; tracked tree clean).
Karateka: `wip` `58cad3e`, `main` `5eb92b1`, clean. Sync bridge passing.

---

### 1 — Summary

**Third hypothesis, and this one survived the test. The freeze was the VBL interrupt landing inside the
non-atomic MMU remap.**

| | |
|---|---|
| Decisive mask test (§1) | **PASS 27/27** — IRQ race CONFIRMED |
| Narrowed to | **the 4-write MMU remap** — masking only those four writes also gives 27/27 |
| Fix | Karateka's discipline, applied in the shared HAL's `gfx_map_blocks` |
| Verified where the bug lives | **DECB `LOADM` 27/27**; direct load all five stages |
| POP regressions | mode PASS, P1.1 PASS, P1.3 PASS |
| Karateka | **byte-identical**, 6/6 informative tests PASS |
| `$FF90` doc (§4) | **corrected**, comment-only, binary byte-identical |

**Reading Karateka first is what made this fast.** `HAL_time_frame_count` masks IRQ around its two-byte
read of the interrupt-updated frame counter and is labelled a race fix. That is the rule, stated for a
different resource: **the 6809 gives no atomicity across multiple accesses, so anything the interrupt
context can observe part-way through must be made atomic by masking.** The counter needed it for a
16-bit READ; the MMU needs it for a four-register WRITE. The fix is that rule applied where it was
missing, not a new invention.

**The decisive test came first, and it was cheap.** Masking IRQ across the whole draw turned 22/23 into
27/27 in one run. A second, narrower test — masking *only* the four MMU register writes — did the same,
which localises the race exactly rather than leaving "somewhere in the draw".

**What the test also ruled out, and this matters.** The dispatch's prime suspect was the probe's raw
unmasked 16-bit read of the frame counter (`lda <frame_hi / ldb <frame_lo` in `rs_after`) — a real
deviation from `HAL_time_frame_count`. **It is not the mechanism:** that read was still unmasked in the
passing test. It remains a latent inconsistency worth fixing on its own merits, but it was not this bug,
and reporting it as the cause would have been wrong in a way the suite would never have caught.

**Why speed was the tell.** P2.8 established the variable was speed, not instruction form. Speed-
dependence means an asynchronous interaction, and the only asynchronous thing present is the VBL
interrupt. The faster loop simply hit the four-instruction window more often. That reasoning is what
selected this hypothesis over a fourth round of code inspection.

**The `$FF90` correction (§4) is in, comment-only.** The old postcondition claimed `$4C` left "ROM
unmapped from `$8000-$FEFF`". `$FF90`'s MC1:MC0 selects ROM *mapping* and has no all-RAM setting at all;
`$4C` is `MC1=0, MC0=0` = "16K internal, 16K external". The real RAM/ROM control is the SAM `$FFDE`/
`$FFDF` pair, which `HAL_sys_init` never writes.

---

### 2 — Files modified

**POP `wip`:**
- `src/hal/coco3-dsk/gfx.s` — **THE FIX**: `gfx_map_blocks` is now a masked critical section
  (`pshs cc` / `orcc #$50` / … / `puls cc`), with the mechanism and its measurement documented.
- `src/hal/coco3-dsk/sys.s` — **§4**: the `$FF90=$4C` postcondition corrected, with both reference
  tables cited. Comment-only.
- `src/harness/anim_probe.s` — the probe's own inline tear-mode remap gets the same discipline.
- `mame-idioms-coco3-port.md` — **§22** (multi-register update = critical section); §21e updated from
  "unresolved" to resolved.
- `reports/20260727-004606-p2-9-irq-race-diagnosis.md` — this report.

**Karateka `wip`:** `src/hal/coco3-dsk/gfx.s` and `src/hal/coco3-dsk/sys.s` — the same shared-kernel
text, mirrored. Binary byte-identical (the gfx change is inside `HAL_GFX_MODE_SERVICE`, gated off there;
the sys change is a comment).

**Not modified:** Karateka `main`; any `$FF90` register WRITE (§8 — comment-only); the unrolled loop
(never the bug); engine code; `oracle/source/`.

---

### 3 — Reasoning

#### 3.1 — Karateka's proven pattern, read first (AC1)

```asm
HAL_time_frame_count:
        pshs    cc                      ; save caller's CC (preserves mask state)
        orcc    #$10                    ; mask IRQ (CC.I=1) — no handler mid-read
        lda     <hal_frame_hi           ; \ atomic pair
        ldb     <hal_frame_lo           ; /
        puls    cc                      ; restore caller's CC exactly
        rts
```
Three things carry over and all three are in the fix: **mask around the multi-access sequence**;
**`pshs cc`/`puls cc` rather than `orcc`/`andcc`**, so a caller that had interrupts masked stays masked
(the E1.c invariant); and **the reason** — no atomicity across multiple accesses on this CPU.

`HAL_time_vbl_wait`'s opt-in contract (`andcc #$EF`, as `boot.s:150` does) was also checked: the probe
already does it, so that P2.6 trap was not in play here.

#### 3.2 — Phase 1: the decisive test (AC2), run before any theorising

Wrapped `jsr draw_frame` in `orcc #$50` … `andcc #$AF` and re-ran under DECB `LOADM`:
```
# checks=27 passed=27 failed=0     VERDICT: PASS
```
From 22/23 to 27/27 by masking interrupts alone. Nothing else changed. **IRQ race confirmed.**

#### 3.3 — Phase 2: narrowing to the exact code (AC3)

Stage 5 is the only failing stage and the only one whose `draw_frame` performs an MMU remap (it maps the
*displayed* buffer, deliberately, for the contrast). Masking **only** those four writes:
```
TEST A: IRQ masked around the MMU remap ONLY
# checks=27 passed=27 failed=0     VERDICT: PASS
```

**The mechanism.** Writing four MMU registers is a multi-step change to the CPU's memory map. Between
the first write and the last, the window at CPU `$6000-$DFFF` is half one buffer and half the other — a
configuration that never legitimately exists. An interrupt taken in that gap executes against it. The
handler is not wrong; the machine underneath it is inconsistent.

This also retires P2.7's contradiction — data reading `$FF` with no observed write, while the stack in
the same block read fine. A half-updated map explains reads that come from the wrong physical memory
without any write having occurred, and explains why different addresses disagree about reality.

#### 3.4 — Phase 3: the fix, at the right layer (AC4)

Applied in **`gfx_map_blocks` in the shared HAL**, not in the probe, because every caller of the
double-buffer path (`HAL_gfx_swap`, `HAL_gfx_set_mode`, and any future engine code) performs the same
remap and has the same exposure. Fixing only the probe would have left the kernel defective.

The probe's own inline tear-mode remap — a deliberate duplicate, since that stage defeats the buffering
on purpose — gets the same treatment. Defeating the *buffering* is the point of that stage; defeating
the *machine* is not.

#### 3.5 — What was NOT the cause, recorded so it is not re-found later

The probe reads the interrupt-updated frame counter unmasked in `rs_after`:
```asm
                lda     <frame_hi       ; $10   no mask, unlike HAL_time_frame_count
                ldb     <frame_lo       ; $11
```
That is a genuine deviation from Karateka's discipline and the dispatch's prime suspect. **It is not
this bug** — that read stayed unmasked through every passing test. A torn counter would corrupt an
*observable*, not hang the probe. Left as-is and flagged (§8.1) rather than "fixed" opportunistically,
because bundling an unverified change into a confirmed fix makes the next regression harder to bisect.

---

### 4 — Verification (AC-by-AC)

- **AC1 — Karateka read first, pattern documented. MET.** §3.1; recorded as idiom §22.
- **AC2 — decisive mask test run FIRST, verbatim. MET.** §3.2 — PASS ⇒ IRQ race.
- **AC3 — exact mechanism proven, gap vs Karateka named. MET.** §3.3 — the four-write MMU remap; the gap
  is the missing mask that `HAL_time_frame_count` already applies elsewhere.
- **AC4 — fixed via Karateka's discipline, verified where the bug lives. MET.** `gfx_map_blocks`;
  **DECB `LOADM` 27/27**, direct load all five stages.
- **AC5 — `$FF90` doc corrected, byte-identical, mirrored. MET.** §5.
- **AC6 — one kernel. MET.** Sync bridge green both directions; Karateka byte-identical + 6/6.
- **AC7 — n/a**, the test confirmed rather than disproved.
- **AC8 — no engine code; clean status. MET.**

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 — THE DECISIVE TEST (verbatim):**
```
PHASE 1 test applied: IRQ masked across draw_frame
=== DECISIVE TEST: DECB LOADM with IRQ masked across the draw ===
  stage5_16-colour NO-SWAP_no_swaps        PASS +0 swaps (want 0), over +299 MAME frames
  stage5_16-colour NO-SWAP_still_vbl_paced PASS stage lasted +299 MAME frames
  # checks=27 passed=27 failed=0     VERDICT: PASS
```

**25.1 — NARROWED TO THE MMU REMAP (verbatim):**
```
TEST A: IRQ masked around the MMU remap ONLY
  # checks=27 passed=27 failed=0     VERDICT: PASS
```

**25.1 — THE FIX, verified on the DECB load path (verbatim):**
```
[hal-sync] OK -- HAL source aligned with karateka_coco3
=== BUILD COMPLETE ===
  stage5_16-colour NO-SWAP_vres            PASS $FF99 $1E (want $1E)
  stage5_16-colour NO-SWAP_stride          PASS stride 160 (want 160)
  stage5_16-colour NO-SWAP_no_swaps        PASS +0 swaps (want 0), over +299 MAME frames
  stage5_16-colour NO-SWAP_still_vbl_paced PASS stage lasted +299 MAME frames
  all_five_stages_ran                      PASS last stage 5
  vbl_irq_live                             PASS HAL frame counter reached 1581
  # checks=27 passed=27 failed=0     VERDICT: PASS
[run_anim_test] PASS
```

**25.1 — direct load + POP regressions (verbatim):**
```
# stage 5  16-colour NO-SWAP CONTRAST ... swaps=600 (frame 1402)
# all five stages done.
[run_mode_test] PASS      [run_probe_test] PASS      [run_compiled_test] PASS
```

**25.1 — HARD-STOP 12.4, comment-only doc fix (verbatim):**
```
pre : 88eba89b15cdf17c8d25e082d2d3e1f3cce57d38
post: 88eba89b15cdf17c8d25e082d2d3e1f3cce57d38
*** BYTE-IDENTICAL — comment-only, hard-stop 12.4 clear ***

run_gfx_init_precheck PASS   run_sys_init_test PASS
run_gfx_init_test PASS       run_timer_framesync_test PASS
run_kernel_dispatch_test PASS run_vbl_irq_test PASS
```

**25.2 —** `src/hal/coco3-dsk/gfx.s` (`gfx_map_blocks`); `src/hal/coco3-dsk/sys.s` (§4 comment);
`src/harness/anim_probe.s`; `mame-idioms-coco3-port.md` §22.
POP `wip` `<hash>`; Karateka `wip` `<kar>`; `main` `5eb92b1`.

**25.3 — N/A.** The fix is interrupt-masking discipline; no rendering or timing-visible change. The
probe's output is identical and DECB 27/27 is the observable. Nothing new for Jay's eye.

---

### 6 — Reactive deviations

1. **The dispatch's prime suspect was wrong, and I did not fix it anyway** (§3.5). The unmasked counter
   read is a real deviation from Karateka but was not this bug — it stayed unmasked through every
   passing run. Flagged as follow-up rather than bundled in, so the confirmed fix stays isolated.
2. **The fix went into the shared HAL, not the probe.** Every double-buffer caller performs the same
   remap; fixing only the probe would have left the kernel defective for the engine.
3. **The probe's inline tear remap was fixed too** — it duplicates the remap deliberately, and defeating
   the buffering is the point of that stage while defeating the machine is not.
4. **§21e updated** from "still unresolved" to resolved, so the idioms file does not carry a stale
   open question.

---

### 7 — Uncertainty flags

1. **Why DECB `LOADM` and not direct load** is still not fully explained. The fix removes the failure on
   both paths, but the asymmetry itself — why the same race only manifested under one loader — remains
   open. Most likely the two paths leave different interrupt timing/phase, so the direct path simply hit
   the window less often. That is a plausible account, **not a measured one**.
2. **The unmasked counter read remains** (§3.5). Latent, not currently harmful, and a real inconsistency
   with `HAL_time_frame_count`.
3. **Other multi-register writes are unaudited.** The same shape exists wherever several hardware
   registers are written as a set — VOFFSET pairs, palette runs, the MMU task switch. `HAL_gfx_swap`'s
   `std $FF9D` is a single 16-bit store and is fine; the palette loop in `set_mode` writes 4–16
   registers unmasked and has never been examined for this.
4. **The masking cost is unmeasured.** Interrupts are now disabled for the duration of four stores in
   `gfx_map_blocks`, called twice per `set_mode` and once per swap. Trivially small, but not measured,
   and VBL latency is what animation depends on.
5. **The edge-blink is untouched** (out of scope) and stands as P2.7 left it.

---

### 8 — Follow-up candidates

1. **Use `HAL_time_frame_count` in the probe** instead of the raw unmasked counter read (§3.5) — small,
   and it removes a known deviation from the discipline this dispatch just codified.
2. **Audit the other multi-register writes** (§7.3), particularly the palette loop, against §22.
3. **Explain the load-path asymmetry** (§7.1) — now much lower value since the bug is fixed, but it is
   the one fact still unaccounted for.
4. **Measure the masking cost** (§7.4) before animation timing gets tight.
5. Carried: the edge-blink raster measurement; unify the two buffer models; 16-colour frame budget;
   mode-table bounds check; the composite-vs-RGB palette comment; `POP-idioms-coco3-markers.md`; the
   CLAUDE.md boot-contract statement drafted in P2.8 §8.1, still awaiting Jay/Orchestrator.

---

### 9 — User interaction during task
**None during execution.** The dispatch supplied Karateka's labelled race fix as the pattern and the
measure-before-believing discipline; both determined the outcome, and the first test settled in one run
what two dispatches of inspection had not.

---

### 10 — Candidate(s) captured this task
`seeds/POP/live/2026-07-27-read-the-working-sibling-before-theorising-about-your-own-code.md` — three
theories, three dispatches, and the answer was a discipline the working sibling already had and had
labelled; the cheap move is to diff your code against the thing that works before reasoning about why
yours doesn't. Committed and pushed.

---

### 11 — Commit
**POP:** `<hash>` — the fix, the doc correction, idioms §22, this report. Pushed to POP `origin/wip`.
**Karateka:** `<kar>` on `wip` — mirrored shared kernel; binary byte-identical. Pushed.
**Karateka `main` @ `5eb92b1` — untouched.**
