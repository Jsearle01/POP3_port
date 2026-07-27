## Form B Report — P2.8 — boot-contract confirmation, freeze diagnosis, contract codified
**Class:** DEBUG-CONFIRM + PROCESS. **HYPOTHESIS DISPROVEN → hard-stop 11.2 → no boot-order fix forced.**
POP `wip`. Karateka untouched; sync bridge green.
**The freeze is NOT a ROM-residency / boot-order bug. It is a SPEED-dependent race — newly bisected.**
**The boot contract is codified anyway (§21), on its own merits.**

### 0 — Receipt / status (C-35 stamp)
t0=2026-07-27T00:29:34Z (POP HEAD `f8b6321`, wip; tracked tree clean).
Karateka: `wip` `58cad3e`, `main` `5eb92b1`, clean. Sync bridge passing.

---

### 1 — Summary

**Jay's hypothesis is disproven by direct measurement, and the source comment that motivated it is
itself wrong.** That is a real result, not a null one: it closes a plausible lead permanently and
corrects a factual error sitting in the shared kernel.

| | |
|---|---|
| ROM-resident-read hypothesis | **DISPROVEN** — every address writable RAM at every point |
| `sys.s:112` "`$FF90=$4C` unmaps ROM" | **UNSUPPORTED** by both references — flagged, not edited |
| Freeze mechanism | **advanced, not solved** — bisected to **SPEED**, not the instruction form |
| Boot-order fix | **NOT forced** (hard-stop 11.2); conformance added and measured — no effect |
| Boot contract | **CODIFIED** as idioms §21a-§21e; governance statement DRAFTED for Jay |
| Karateka | untouched, sync bridge green |

**The disproof, measured rather than argued.** A write/read-back survey at three points on the DECB
path — at the prompt, after `LOADM` but before `EXEC`, and with the probe running — found `$0200`,
`$3000`, `$6000`, `$7F00`, `$8000`, `$9000`, `$A000`, `$C000`, `$D000`, `$D7FF` **all writable RAM,
every time**, including *before `HAL_sys_init` had ever run*. There is no ROM-resident window to read
from. After `set_mode` the whole `$6000-$D7FF` draw window reads `$00` (cleared) with `$6000` holding
the bar — the clear reaches every byte it should.

**The documentation error, which is the durable finding here.** `sys.s` states as a postcondition that
`$FF90=$4C` leaves *"ROM unmapped from `$8000-$FEFF`"*. Both ground-truth references give the same
MC1:MC0 table and neither contains an all-RAM setting:

| MC1 | MC0 | ROM mapping |
|-----|-----|-------------|
| 0 | x | 16K internal, 16K external |
| 1 | 0 | 32K internal |
| 1 | 1 | 32K external (except vectors) |

`$4C` = `0100_1100` → MC1=0, MC0=0 → *"16K internal, 16K external"*. The CoCo3's upper-memory RAM/ROM
choice is the SAM's `$FFDE`/`$FFDF` pair, and **`HAL_sys_init` never writes it** — `HAL_gfx_init` and
`HAL_gfx_set_mode` write `$FFDF`, as their *last* step. So the comment attributes an effect to the
wrong register. I did **not** correct it (§3.4).

**The freeze diagnosis did advance, materially.** P2.7 bisected it to "the unrolled loop". P2.8 bisected
*inside* that:

| variant | speed | result |
|---|---|---|
| rolled byte loop | slow | **PASS 27/27** |
| unrolled `sta ,x+` ×16 | fast | **FAIL 22/23** |
| unrolled `std ,x++` ×8 | fast | **FAIL 22/23** |

Unrolled **byte** stores fail too. So it is neither `std` nor `,x++` nor 16-bit addressing — **the
variable is SPEED**. The unroll introduced no coding error; it made the loop fast enough to reach a
latent race. That reframes the bug from "find my mistake in the unroll" to "find what races when the
draw completes sooner", which is a different and more tractable question. I did not answer it.

**Contract conformance was added and measured, and it changed nothing** — which is itself evidence.
The probe now runs the full canonical prefix (`HAL_sys_init` → `HAL_mem_size_detect` → `HAL_time_init`)
and still fails 22/23. A boot-order fix was therefore not merely unjustified by Phase 1; it is
independently shown not to help.

---

### 2 — Files modified

- `src/harness/anim_probe.s` — added `jsr HAL_mem_size_detect` (step 1). **Contract conformance, NOT a
  fix**; measured to have no effect on the failure.
- `mame-idioms-coco3-port.md` — **§21** (`21a` canonical boot; `21b` the layering; `21c` the
  proto-kernel-boot framing; `21d` the `sys.s` flag with evidence; `21e` speed-is-schedule).
- `reports/20260727-002934-p2-8-boot-contract-freeze-fix.md` — this report.

**Not modified:** `src/hal/coco3-dsk/sys.s` (§3.4 — flagged for Jay, deliberately not edited); the
unrolled loop; `CLAUDE.md` (governance draft is in §8, per §2D); Karateka; `oracle/source/`.

---

### 3 — Reasoning

#### 3.1 — Phase 1: the confirmation attempt (AC1) — DISPROVEN

The dispatch asked for `$FF90`'s state at the failing read and whether the read targets `$8000-$FEFF`.
Both questions dissolve once the region is measured directly:

```
--- DECB prompt, BEFORE LOADM ---            --- probe RUNNING, after sys_init + set_mode ---
  $0200 reads $00  RAM (writable)              $0200 reads $7E  RAM (writable)
  $8000 reads $45  RAM (writable)              $8000 reads $00  RAM (writable)
  $C000 reads $44  RAM (writable)              $C000 reads $00  RAM (writable)
  $D7FF reads $8E  RAM (writable)              $D7FF reads $00  RAM (writable)
```
`$8000-$D7FF` is writable RAM *before the probe has executed a single instruction*. Nothing the probe
does can be a read of ROM-resident space, because there is none. And P2.7's corrupted addresses were
`$0203-$0341` — **low RAM, nowhere near `$8000-$FEFF`** — which the hypothesis never accounted for.

Hard-stop 11.2 fires: report the real mechanism, do not force a boot-order fix.

#### 3.2 — What the freeze actually is, as far as it is now known

Bisecting inside the unroll (§1) isolates **speed** as the only variable. The three variants write
identical bytes to identical addresses in identical order; only the cycle count differs.

This is worth stating precisely because it inverts the search: an optimisation that is provably
output-equivalent can still change *when* memory is touched relative to the VBL interrupt, the raster,
and the MMU remap that stage 5 performs every iteration. Something in that interaction is racy. The
candidates I did not get to test are the MMU remap racing the IRQ, and the draw racing the raster in
the one stage that deliberately writes the *displayed* buffer — stage 5 is the only stage that does
both, which is consistent with it being the only stage that fails.

#### 3.3 — Why the load-path asymmetry still stands unexplained

DECB `LOADM` fails; direct load passes; same binary, same probe, same contract prefix. Since memory is
RAM either way and boot order is now identical either way, the asymmetry must come from machine state
the two paths leave behind — most plausibly disk-controller or timing state. **This is the strongest
unexplored thread and I did not run it down.**

#### 3.4 — Why I did not correct `sys.s`

It is a factual claim about machine behaviour in the *shared kernel*, and three things argue for
flagging over editing: the references contradict it but the measured behaviour doesn't *depend* on it
(the region is RAM regardless, so nothing observable is wrong today); I have been wrong about this
machine twice in two dispatches and only measurement settled it; and it is Karateka's inherited text,
where a silent correction would propagate a second unreviewed claim. Recorded with evidence in §21d for
Jay's disposition.

#### 3.5 — Phase 3: codifying (AC4), and its honest justification

The contract is codified **on the strength of P2.5 and P2.6, not P2.7**. P2.6's interrupt storm *was* a
genuine boot-order violation (skipping `HAL_sys_init`), and P2.5's hang was hand-rolled VBL setup. Those
two justify the rule. P2.7/P2.8's freeze turns out **not** to be a member of that family — so the
contract is worth having, and it would not have prevented this particular bug. Saying otherwise would
be tidier and false.

§21b records the layering that resolves "boot differs per resolution": steps 0-2 are
resolution-independent and mandatory-first; step 3 is the single parameterised, resolution-dependent
call. §21c records Jay's OS-boundary reading — the kernel guarantees machine configuration before any
program runs, and programs then *request* modes.

---

### 4 — Verification (AC-by-AC)

- **AC1 — mechanism proven or disproven. MET (disproven).** §3.1, with the measurement verbatim in §5.
  The real mechanism is advanced (speed, not form) but **not** proven — stated as such.
- **AC2 — freeze fixed via canonical sequence. NOT APPLICABLE / NOT DONE.** Hypothesis disproven →
  hard-stop 11.2 → no fix forced. Conformance added and shown ineffective.
- **AC3 — verified where the bug lives. N/A** (no fix). Current state measured on both paths: DECB
  22/23, direct load all five stages.
- **AC4 — boot contract codified. MET.** Idioms §21a-§21e; governance statement drafted in §8 for Jay
  rather than self-authored (§2D).
- **AC5 — one kernel. MET.** Sync bridge green; Karateka `58cad3e` untouched, `main` `5eb92b1`.
- **AC6 — stop if disproven. MET.** That is the outcome.
- **AC7 — no engine code; clean status. MET.**

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 — THE DISPROOF (verbatim):**
```
--- DECB prompt, BEFORE LOADM (fn=300) ---
  $0200  reads $00  RAM (writable)      $8000  reads $45  RAM (writable)
  $3000  reads $FF  RAM (writable)      $9000  reads $84  RAM (writable)
  $6000  reads $FF  RAM (writable)      $A000  reads $A1  RAM (writable)
  $7F00  reads $FF  RAM (writable)      $C000  reads $44  RAM (writable)
                                        $D000  reads $03  RAM (writable)
                                        $D7FF  reads $8E  RAM (writable)
--- probe RUNNING, after HAL_sys_init + set_mode (fn=689) ---
  $0200  reads $7E  RAM (writable)      $8000  reads $00  RAM (writable)
  $6000  reads $FF  RAM (writable)      $C000  reads $00  RAM (writable)
  $7F00  reads $00  RAM (writable)      $D7FF  reads $00  RAM (writable)
```
Writable RAM everywhere, at every stage, including before `HAL_sys_init` ran.

**25.1 — the reference tables that contradict `sys.s` (verbatim):**
```
GIME_Reference_Manual.pdf §3 INIT0:        SockmasterGime.md:33-37:
 ROM mapping (MC1:MC0):                     Bits 1-0  MC1 MC0  ROM map control
 0 x  16K Internal, 16K External             0x = 16K internal, 16K external
 1 0  32K Internal                           10 = 32K internal
 1 1  32K External (except vectors)          11 = 32K external (except interrupt vectors)
Standard CoCo3 operating value: `$4C`
0100_1100 -> COCO=0, MMUEN=1, IEN=0, FEN=0, MC3=1, MC2=1, MC1=0, MC0=0
```

**25.1 — THE NEW BISECTION, speed vs form (verbatim):**
```
BISECT C: unrolled sta ,x+ x16 (unroll kept, std/,x++ removed)
  # checks=23 passed=22 failed=1     VERDICT: FAIL
  -> byte stores fail too; std / ,x++ are NOT the cause. SPEED is the variable.
```
With the prior results: rolled byte loop **27/27 PASS**; unrolled bytes **22/23 FAIL**; unrolled words
**22/23 FAIL**.

**25.1 — contract conformance changes nothing (verbatim):**
```
probe now runs the full canonical prefix 0 -> 1 -> 2
[hal-sync] OK -- HAL source aligned with karateka_coco3
=== BUILD COMPLETE ===
  # checks=23 passed=22 failed=1     VERDICT: FAIL
```

**25.1 — current state, both paths (verbatim):**
```
DECB LOADM : 22/23 (stage-5 contrast check failing)
direct load: # stage 5 ... swaps=600 (frame 1402) / # all five stages done.
```

**25.2 —** `src/harness/anim_probe.s` (step-1 conformance); `mame-idioms-coco3-port.md` §21.
POP `wip` `15324fe`; Karateka `wip` `58cad3e`; `main` `5eb92b1`.

**25.3 — N/A.** No rendering or temporal change; the probe's output is unchanged and no fix was applied.

---

### 6 — Reactive deviations

1. **The dispatch's premise was wrong, and the source it cited is wrong.** The dispatch quoted
   `sys.s:112` as CONFIRMED and built the hypothesis on it. It is not confirmed by either reference.
   Reported rather than worked around, because a wrong claim in the shared kernel is worth more than
   this dispatch's fix.
2. **Step 1 conformance was added even though Phase 1 disproved the hypothesis** — as codification
   follow-through, explicitly measured to show it is not a fix. Flagged so "the probe changed" is not
   mistaken for "the probe was fixed".
3. **`sys.s` deliberately NOT corrected** (§3.4) — flagged for Jay.
4. **The contract is codified on P2.5/P2.6's evidence, not P2.7/P2.8's** (§3.5). The freeze is not a
   member of the family the contract addresses.

---

### 7 — Uncertainty flags

1. **The freeze is still unsolved.** Narrowed from "the unroll" to "the speed", which is progress, but
   the racing mechanism is unidentified.
2. **The load-path asymmetry remains unexplained** (§3.3) and is now the strongest lead: with memory and
   boot order both equalised, whatever differs must be residual machine state from the disk load.
3. **`sys.s`'s comment may still be right for a reason I have not found** — MC3/MC2 semantics, or CoCo3
   RAM-shadowing behaviour that makes the distinction moot. The measurement shows the region is RAM
   either way, so I cannot distinguish "the comment is wrong" from "the comment is irrelevant here".
4. **§21 asserts a contract the codebase does not yet enforce.** Nothing checks that a program runs the
   canonical prefix; it is documentation, like `hal.inc` was before P2.4 made it linkable.
5. **The edge-blink was untouched** (out of scope per §7) and remains as P2.7 left it: frame-rate
   correlated, raster position unmeasured.

---

### 8 — Follow-up candidates

1. **[DRAFTED FOR JAY / ORCHESTRATOR — §2D governance-class, not self-authored]** proposed CLAUDE.md
   addition:
   > **Boot contract.** Every probe and program MUST execute the HAL's canonical machine-config boot —
   > `HAL_sys_init`, `HAL_mem_size_detect`, `HAL_time_init`, in that order, verbatim — as its FIRST
   > action, before any memory, graphics or data access. That prefix is resolution-INDEPENDENT and
   > mandatory. Graphics mode (`HAL_gfx_set_mode`) is the only resolution-dependent step and is called
   > AFTER it. Do NOT hand-roll machine bring-up. [ref: karateka `src/engine/boot.s`; `hal.inc` INIT
   > ORDER; idioms §21]
2. **[JAY'S CALL] `sys.s:112`'s `$FF90=$4C` "unmaps ROM" comment** (§3.4, §21d) — correct it, qualify
   it, or confirm it is right for a reason I missed. It is shared-kernel text.
3. **Run down the load-path asymmetry** (§7.2) — the most informative remaining thread on the freeze.
4. **The freeze/smoothness trade from P2.7 §8.1 is still open** — (a) revert the unroll, (b) keep 22/23,
   (c) cut draw cost another way. **Now better informed:** since SPEED is the variable, option (c) would
   likely reproduce the failure too, and option (a) works only by being slow. That makes the real
   question "what races", not "which loop shape".
5. Carried: edge-blink raster measurement; unify the two buffer models; 16-colour frame budget;
   mode-table bounds check; the composite-vs-RGB palette comment; `POP-idioms-coco3-markers.md`.

---

### 9 — User interaction during task
**None during execution.** The dispatch carried Jay's hypothesis and the disprove-and-stop discipline;
the latter determined the outcome.

---

### 10 — Candidate(s) captured this task
`seeds/POP/live/2026-07-27-an-output-equivalent-speedup-is-still-a-schedule-change.md` — an optimisation
that provably changes no output can still change *when* things happen, and so can surface a latent race;
when a verified-equivalent speedup breaks something, the bug is not in the optimisation. Committed and
pushed.

---

### 11 — Commit
**POP:** `15324fe` — step-1 conformance, idioms §21, this report. Pushed to POP `origin/wip`.
**Karateka:** untouched at `58cad3e`; `main` `5eb92b1`.
