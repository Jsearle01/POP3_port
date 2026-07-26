## Form B Report — P2.7 — stage-5 freeze + edge-blink diagnosis
**Class:** DEBUG — diagnose before fix. **STOPPED AT THE §2 CHECKPOINT (hard-stop 11.2).**
POP `wip`. No fix applied. Karateka untouched; sync bridge green.
**Freeze: reproduced and BISECTED to the exact change — mechanism NOT proven.**
**Edge-blink: partially characterized — the raster-position measurement FAILED and is unmeasured.**

### 0 — Receipt / status (C-35 stamp)
t0=2026-07-26T21:27:28Z (POP HEAD `af8ccea`, wip; tracked tree clean).
Karateka: `wip` `58cad3e`, `main` `5eb92b1`, clean. Sync bridge passing.

---

### 1 — Summary

**I did not solve this, and I am reporting rather than guessing.** The dispatch's checkpoint says stop
if the root cause is not established as small. It is not established at all.

| | |
|---|---|
| Freeze reproduced | **YES** — DECB `LOADM` fails, direct load passes, same binary |
| Freeze bisected | **YES, precisely** — the unrolled `std` loop. `BAR_STEP` ruled out; baseline 27/27 |
| Freeze mechanism | **NOT PROVEN** — see §3.3 for what the evidence rules out |
| Edge-blink | **partially characterized** — frame-rate correlation strong; raster position UNMEASURED |
| One bug or two | **TWO, on evidence** (§3.5) — the same change moved them in OPPOSITE directions |
| Fix applied | **NONE** — §2 checkpoint honoured |

**What the bisection establishes, cleanly.** The pre-regression probe passes **27/27**. Adding only the
unrolled loop makes it fail **22/23**. Reverting `BAR_STEP` 2→4 while keeping the unroll still fails. So
the fault is in the unroll and nothing else in that commit.

**What the evidence RULES OUT, which is the useful part.** I chased the obvious leads and each is dead:

- **Not the `$FFA3-$FFA6` stack lead the dispatch offered.** `anim_probe.s` already does `lds #$1F00`
  before any MMU work, and the stack reads correctly at the moment of failure (`S=$1EFA`, holding a valid
  `run_stage → draw_frame → paint_bar` return chain: `$0255`, `$0281`, `$0308`).
- **Not a bad `rts` or a corrupted call chain** — that chain is intact at the crash.
- **Not miscompiled code.** I disassembled the generated `paint_bar`: `BE 31 FE` (`ldx $31FE`),
  `10 8E 00 C0` (`ldy #192`), `34 10` (`pshs x`), eight × `ED 81` (`std ,x++`), `35 10` (`puls x`) —
  exactly as intended, and byte-equivalent in effect to the loop it replaced.
- **Not `HAL_sys_init` being the cause.** It *does* run (PC `$3029-$3051`, rewriting `$FF90=$4C` and the
  whole MMU back to `$FFA0=$38 … $FFA7=$3F`), but the probe's data already reads `$FF` **before** it, so
  it is a consequence of the CPU going astray, not the trigger.

**The signature, stated exactly, because it is contradictory and that matters.** At failure the probe's
data region reads all `$FF` (`stage=255 bar_x=255 paint_x=255 tear=255 prev=[255,255] ctr=65535`) while
the HAL's data one block away is pristine (`draw_base=$6000 stride=160 words=$3C00 back=0`). A write tap
on `$0203-$0206` armed from stage 1 through the crash caught **only** the legitimate `run_stage` writes —
no corrupting write was ever observed. But the stack, in the **same MMU block** as the corrupted data,
still reads correct values. So it is neither a clean mapping change (the stack would have gone too) nor an
observed write. I cannot reconcile those two facts, and rather than invent a story that fits, I am
reporting the contradiction.

---

### 2 — Files modified
**None.** No fix was applied — the checkpoint sent this to Jay. Diagnostic scripts live in `build/`
(gitignored, throwaway). The only tracked change is this report.

`dist/mame-cfg/rgb/coco3.cfg` was rewritten by MAME during the runs and restored, as in every dispatch.

---

### 3 — Reasoning

#### 3.1 — The reproduction (AC1), captured before theorizing

Same binary, both load paths, back to back:
```
############ DECB LOADM path ############
  completed_before_timeout  FAIL stage=5 swaps=600 frames=1132
  # checks=23 passed=22 failed=1     VERDICT: FAIL

############ DIRECT LOAD path (same binary) ############
# stage 4  4-colour  ANIMATED (switched back)   swaps=450  (frame 1086)
# stage 5  16-colour NO-SWAP CONTRAST           swaps=600  (frame 1402)
# all five stages done.
```
`stage/vres/stride` **were** published while `swaps/frames` were not, which localises the failure to the
**first stage-5 iteration**, before `rs_after`.

#### 3.2 — The bisection (the dispatch's own handle, and it worked)

| build | result |
|---|---|
| current (unroll + `BAR_STEP` 2) | **22/23 FAIL** |
| unroll + `BAR_STEP` **4** | **22/23 FAIL** → `BAR_STEP` is NOT the cause |
| pre-regression `b6bba7e` (byte loop) | **27/27 PASS** → baseline confirmed |

The regression commit changed exactly three things; two are now excluded. **The unrolled `std` loop is
the cause.** That is a solid, reproducible narrowing — it is the mechanism I lack, not the culprit.

#### 3.3 — Why I stopped instead of fixing

The obvious fix is "revert the unroll," and it would restore 27/27. I did not apply it because:

1. **It is a fix by reversion, not by understanding.** The unroll is byte-equivalent in what it writes.
   A change that *should* be inert is not, which means something about my model of this probe or of the
   load path is wrong. Reverting hides that rather than resolving it, and the same wrongness will surface
   again the moment engine code does something similar.
2. **It would undo the smoothness Jay gated.** He observed the ~29 Hz version and accepted it; reverting
   returns to the ~20 Hz version he called "still a bit blinky", invalidating that observation.
3. **Hard-stop 11.2 applies.** The root cause is not established as a small stack/memory-map adjustment —
   it is not established at all. The dispatch says stop and let Jay decide, and that is the higher-value
   outcome here.

#### 3.4 — §1b, the edge-blink: partially characterized, and honestly short

**What is established:** the blink is strongly frame-rate-correlated. Jay's own before/after is the
evidence — *"still a bit blinky"* at ~20 Hz (1 swap per 3.07 VBLs), then *"look better"* at ~29 Hz
(1 per 2.05) with no change whatsoever to the swap logic. That is a real A/B on the same code path.

**What is NOT established, and this was the point of §1b:** WHERE in the raster the VOFFSET write lands.
I attempted to measure it with a write tap on `$FF9D` sampling the beam position, and the MAME Lua screen
API calls I used (`screen.visible_area`, `screen:vpos()`) are not available/correct on this build — the
first attempt produced an empty log, the second incremented the hit counter while the log line errored,
which is exactly the silent-failure shape idiom §10 warns about. **So the central question of §1b is
unanswered.** The `CC.I` hypothesis specifically is *not* supported — `anim_probe.s` does `andcc #$EF`
and the swaps demonstrably wait (150 swaps take ~308 VBL-paced frames, not zero) — but "the wait happens"
and "the write lands inside the blank" are different claims and only the first is evidenced.

#### 3.5 — §1c: one bug or two? **TWO, and the evidence is direct**

The dispatch's shared-cause hypothesis is that the 20→29 Hz change both exposed a fragility (freeze) and
pushed swaps near the raster edge (blink). The measurements point the other way:

- **The blink existed BEFORE the change** (Jay saw it at ~20 Hz) and got **better** after it.
- **The freeze did not exist before the change** and appeared **only** after it.

One change, two symptoms moving in **opposite directions**. A shared root cause would be expected to move
them together. They are almost certainly two independent issues that happen to share an introduction
point. Not proof — but it is the conclusion the evidence supports, and it argues against spending effort
looking for a unifying explanation.

---

### 4 — Verification (AC-by-AC)

- **AC1 — freeze reproduced, asymmetry captured. MET.** §3.1, verbatim.
- **AC2 — root cause proven with mechanism. NOT MET.** Bisected precisely to the unrolled loop; the
  mechanism is unproven and the `$FFA3-$FFA6` lead is **ruled out** with evidence (§1). Reported as a
  failure to establish, not dressed up.
- **AC3 — edge-blink characterized. PARTIALLY MET.** Frame-rate correlation established from Jay's A/B;
  the raster-position measurement failed and is unmeasured (§3.4).
- **AC4 — related-or-not concluded. MET.** TWO, with reasoning (§3.5).
- **AC5 — checkpoint honoured. MET.** Freeze: not-small → **STOPPED, no fix** (hard-stop 11.2).
  Edge-blink: no clean fix identified because the mechanism is unmeasured → **not fixed**, documented.
- **AC6 — n/a**, no fix applied.
- **AC7 — n/a**, no temporal change, so no new Jay gate needed.
- **AC8 — one kernel. MET.** Sync bridge green; Karateka untouched (`58cad3e`, `main` `5eb92b1`).
- **AC9 — clean status. MET.**

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 — the bisection (verbatim):**
```
BISECT A: BAR_STEP 2 -> 4 (unroll KEPT)      # checks=23 passed=22 failed=1   VERDICT: FAIL
BISECT B: pre-regression probe (b6bba7e)     # checks=27 passed=27 failed=0   VERDICT: PASS
current  (unroll + BAR_STEP 2)               # checks=23 passed=22 failed=1   VERDICT: FAIL
```

**25.1 — the crash signature (verbatim):**
```
entry  fn=1937 PC=$0327 S=$1EF6 | stage=5 bar_x=0  paint_x=34 col=$00 tear=1 prev=[0,0] ctr=150
       HAL: draw_base=$6000 stride=160 words=$3C00 back=0 cur_mode=1
ok     fn=1980 PC=$032E S=$1EF6 | stage=5 bar_x=44 paint_x=42 col=$00 tear=1 prev=[0,0] ctr=128
# ---- $0203 STOPPED BEING 5 ----
BROKE  fn=1993 PC=$2593 S=$1EFA | stage=255 bar_x=255 paint_x=255 col=$FF tear=255 prev=[255,255] ctr=65535
       HAL: draw_base=$6000 stride=160 words=$3C00 back=0 cur_mode=1   <- HAL data PRISTINE
```

**25.1 — the intact call chain at the crash (verbatim):**
```
EXEC $3000 fn=1994 PC=$3001 S=$1EFA CC=$C0
   stack@S: 03 08 02 81 02 55 FF FF FF FF FF FF     <- $0308/$0281/$0255 = paint_bar/draw_frame/run_stage
```

**25.1 — no corrupting write was ever observed (verbatim):**
```
# tap armed at fn=689 (stage=1)          [write tap on $0203-$0206, live through the crash]
WRITE $0203 <- $02 PC=$0263 ... WRITE $0205 <- $A0 PC=$026F  stage=5 fn=1937
# end          <- ONLY legitimate run_stage writes. Nothing wrote $FF.
```

**25.1 — `HAL_sys_init` runs AFTER the corruption, not before (verbatim):**
```
INIT $FF90 <- $4C  PC=$3029  stage=255 fn=1994      <- stage ALREADY 255
MMU  $FFA0 <- $38  PC=$302E  stage=255 fn=1994
MMU  $FFA1 <- $39  PC=$3033  stage=255 fn=1994
MMU  $FFA7 <- $3F  PC=$3051  stage=255 fn=1994
```

**25.1 — generated code is correct (verbatim):**
```
paint_bar $0309:
BE 31 FE 4F F6 03 3E 30 8B 10 8E 00 C0 34 10 B6 03 3F 1F 89
ED 81 ED 81 ED 81 ED 81 ED 81 ED 81 ED 81 ED 81 35 10 4F F6
  ldx $31FE / clra / ldb $033E / leax d,x / ldy #192 / pshs x / lda $033F / tfr a,b
  std ,x++ x8 / puls x / clra / ldb <stride>
```

**25.2 —** no fix artifacts. Diagnostics: `build/d7.lua`–`build/d12.lua` (throwaway, gitignored).

**25.3 — N/A.** No rendering change, no temporal change, no fix. Nothing new for Jay's eye.

---

### 6 — Reactive deviations

1. **My own first diagnostic gated `LOADM` on `$0200` alone** — the exact P2.4 race (idiom §19d) — so
   `EXEC` was typed into a running `LOADM` and the probe never started. I nearly drew a conclusion from a
   broken harness. Fixed to the full segment gate and re-run. Recording it because it is the second time
   this dispatch that a *tool* defect masqueraded as a *subject* defect (the first was Python's salted
   `hash()` in P2.6 §3.1).
2. **A write tap silently swallowed its own error** — the raster probe incremented its hit counter and
   then failed inside the log call, producing an empty result that reads as "never happened". Idiom §10
   warns about tap-GC producing exactly that shape; this is a second route to the same false negative.
3. **The dispatch's `$FFA3-$FFA6` stack lead was ruled out**, not confirmed. The probe already relocates
   its stack. Stated because a lead that survives into a report as "probably" is worse than one closed.

---

### 7 — Uncertainty flags

1. **The freeze mechanism is unknown.** I can reproduce it and name the change that introduces it; I
   cannot say why an effect-equivalent code change causes it. Anything further would be invention.
2. **The corruption signature is internally contradictory** (§1) — no observed write, yet the stack in the
   same MMU block survives while the data does not. One of my assumptions is wrong and I have not found
   which. Candidates I could not close: whether MAME's write tap covers every path that can modify that
   memory; whether the Lua `read_u8` view matches the CPU's view under a mid-instruction MMU state.
3. **The load-path asymmetry itself is unexplained.** DECB `LOADM` vs direct poke should differ only in
   how bytes arrive, and both run `HAL_sys_init` afterwards. That it matters at all is the strongest
   remaining clue and I did not run it down.
4. **The edge-blink's actual mechanism is unmeasured** (§3.4). Frame rate correlates; that is not the same
   as knowing the swap lands in the blank.
5. **"Two bugs, not one" is an inference from directionality**, not a proof. If the freeze mechanism turns
   out to be timing-related it would be worth re-examining.

---

### 8 — Follow-up candidates

1. **[JAY'S CALL] Which way on the freeze/smoothness trade:**
   - **(a) Revert the unroll** — restores 27/27, returns to ~20 Hz, and invalidates the smooth version Jay
     accepted. Safe, immediate, understands nothing.
   - **(b) Keep as-is** — 22/23, the smoother animation Jay gated, one known-failing contrast-stage check.
   - **(c) A third path: cut the draw cost WITHOUT unrolling** — e.g. erase only the columns the bar has
     vacated rather than its full width. Plausibly recovers most of the speed on the known-good code
     shape, and would also test whether "the unroll" or "the speed" is what matters. My recommendation if
     the mechanism is to stay unknown.
2. **Run down the load-path asymmetry** (§7.3) — the most informative unexplored thread.
3. **Get a working raster-position measurement** — find the correct MAME Lua screen API, then answer §1b
   properly. Needed before any edge-blink fix can be called clean.
4. Carried from P2.6: unify the two buffer models; 16-colour frame budget; mode-table bounds check; the
   composite-vs-RGB palette comment; `POP-idioms-coco3-markers.md`'s fate.

---

### 9 — User interaction during task
**None during execution.** The dispatch carried the diagnose-before-fix discipline and the checkpoint
policy, both of which decided the outcome here.

---

### 10 — Candidate(s) captured this task
`seeds/POP/live/2026-07-26-when-the-tool-is-broken-the-subject-looks-broken.md` — twice in two dispatches a
defect in the *instrument* (a salted hash; a harness gate racing the loader; a tap swallowing its own
error) presented as a defect in the *subject*, and each time the misleading result was quiet rather than
loud. Committed and pushed.

---

### 11 — Commit
**POP:** `<hash>` (this report only — no fix). Pushed to POP `origin/wip`.
**Karateka:** untouched at `58cad3e`; `main` `5eb92b1`.
