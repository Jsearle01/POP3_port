## Form B Report — P3.99 — the oracle does not skip, and two of my conclusions are withdrawn

**Class:** recon + retraction. wip. Prod untouched; **no `src/` or content change**.

**★★★ JAY, HAVING WATCHED THE ORACLE: *"the vizier exit skip does not exist visually in the
oracle."* THAT CONTRADICTS P3.98 AND P3.99, AND THEY ARE WITHDRAWN. The exit skip is REAL and it is
OURS. ★★ Both of my attributions outran their evidence, in the same way, and I had written down the
gap in one of them before relying on it anyway.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-16T13:03:26-04:00 (HEAD `805f8eb`, wip). Karateka untouched. `main` untouched. Oracle
source read-only — the `.hdv` is copied to `build/` before any run, and `git status oracle/` is
clean. No `src/` or `content/` change. Pre-existing, not mine: `dist/mame-cfg/rgb/coco3.cfg`.

---

### 1 — Summary

| | |
|---|---|
| **★ gate** | **the feet fix PASSES** — Jay, live-disk, RGB, **128 KB**, 2026-08-16 |
| **★★ gate** | **the oracle does NOT skip** — Jay, watching the reference at real speed |
| **★★★ retracted** | P3.98/P3.99's *"the stride is faithful"* — **withdrawn** |
| **★★★ retracted** | P3.97's *"+5,+3,+5,+1,+9,−3"* as the port's rendering — **it was my offline formula** |
| **established** | the port skips, the oracle does not, **the difference is ours** |
| **NOT established** | **why.** No attribution stands |
| **built** | the oracle trace harness (`run_oracle_trace.sh`, `oracle_exit_stride.lua`) |

### 2 — Files modified

- `harness/tools/oracle_exit_stride.lua` — NEW; XCO trace on the running oracle
- `harness/smoke/run_oracle_trace.sh` — NEW; headless oracle runner, image copied first
- `harness/smoke/run_oracle_live.sh` — measured cutscene timings for watching
- `harness/tools/port_exit_walk.lua` — `ch_dest` sampled at the write, not the step tick

### 3 — Reasoning

**3A — ★★★ THE RETRACTION, FIRST, BECAUSE EVERYTHING ELSE DEPENDS ON IT.**

P3.98 concluded from source that the exit stride's lurch is the oracle's own: it branches to MLAY
for a mirrored image [`HIRES.S:654`] and `MLayGen` does `LDA XCO / SEC / SBC WIDTH / STA XCO`
[`HIRES.S:1202-1208`], while `LayGen` has no such arithmetic. P3.99 then traced the running oracle
and reported that confirmed.

**What the trace actually showed is narrower than what I reported.** Armed on PlayCut0's own markers
(SPEED 12 → psandcount 0 → SPEED 7) at frame 4886, 5,178 XCO writes over 900 frames, 150 mirrored
draws — and the widths subtracted were **2, 5, 7, 11, 12**, with the same IMAGE pointer taking
different widths on different draws. That establishes **that mirrored draws in this scene subtract a
varying width**. It does **not** establish anything about the vizier's six walk cels, which is the
only thing the question was about.

**★ I wrote that limitation into the P3.99 commit message — *"it does not isolate the vizier's six
walk cels specifically"* — and then let the conclusion stand on it.** Flagging a gap is not the same
as not relying on it. A caveat that does not change the verdict is decoration.

**And the port half was no better.** P3.97 reported the drawn column moving `+5,+3,+5,+1,+9,−3`
against the entry walk's `−4,−12,−3,+2,−1,−2`. **Those came from `cel_parity_rule.draw_x` — my
offline formula — run over traced CharX values.** I presented them as what the engine draws. They
are what my arithmetic says it should draw, and since `draw_x` is itself the transcription of the
oracle's formula, comparing the two was always going to agree. **A formula agreeing with itself is
not evidence.**

Attempting to ground it during this dispatch: I sampled `ch_dest` at the `cad_idx` tick and got a
constant `$A230` with `awid` 0 — **stale**, because `ch_dest` is written inside `co_setup` during the
draw pass. Moved the sample to a write tap, which is correct, but it still catches only the high
byte, so **the engine's actual column is still not measured.**

**3B — WHAT IS ESTABLISHED, AND IT IS ALL JAY'S.**

1. **The port's exit walk skips** — reported at the P3.96 gate: *"his walk out still looks like he's
   skipping not walking. almost like a frame is missing."*
2. **The oracle's does not** — reported having watched the reference at real speed, 95 s, which
   covers the exit at ~85 s with ten seconds to spare.

**Therefore the difference is real and it is the port's.** That is the whole of the current finding,
and it is worth more than either of my retracted mechanisms, because it is the thing neither of them
was entitled to conclude.

**3C — WHAT IS NOT ESTABLISHED.** Nothing about the cause. The mirror anchor remains the leading
suspect on shape — the exit is mirrored and the entry is not, which matches "unlike his walk coming
in" — but *leading suspect* is where P3.85d, P3.87 and P3.95 all went wrong, and "last candidate
standing is not proof" is a standing invariant here.

**3D — §2H's THREE CHECKS.**

1. **A second mechanism for a different object class?** Unresolved and now important: the ERASE pass
   reconstructs a PAST save's anchor from stored face/awid [P3.72b], so within one step the same cel
   is set up **twice with different `awid` and different `face`** — visible in the new trace
   (cel 49 with `awid 5 / face $FF` and `awid 4 / face $01` in adjacent frames). That is by design,
   but it means **"the anchor for cel N" is not one number**, and any attribution has to say which
   pass it is talking about. **Neither of my retracted ones did.**
2. **The calling routine.** `co_setup`'s callers are `co_erase`, `co_save` and `co_draw` — three
   passes, three different input sets. Reading `co_setup` alone hides that.
3. **Grep the reports.** P3.97's recon, P3.98 and P3.99 all assert the withdrawn claim; P3.98's
   report is corrected in place this dispatch so the next reader does not inherit it.

### 4 — Verification

- **The oracle harness works and is repeatable**: armed deterministically off PlayCut0's markers,
  not off a frame number; **write taps only**, because a 6502 read-tap on a code address silently
  false-0s through the opcode-fetch bypass [idioms §1].
- **The oracle reference is never written**: the `.hdv` is copied to `build/oracle_trace.hdv`;
  `git status oracle/` clean.
- **Suites** unchanged and green — no `src/` or content change this dispatch.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1** No build change; the tree is as P3.98 left it (`=== BUILD COMPLETE ===`, `[hal-sync] OK`).

**25.2** N/A.

**25.3 — ★ TWO RESULTS, BOTH JAY'S, BOTH RECORDED VERBATIM.**

- **"the feet fix looks good."** — live-disk, RGB, **128 KB**, 2026-08-16. Closes the defect he
  reported across three gates (P3.87, P3.94, P3.96), shipped at P3.96 and unaffirmed until now.
  **The first gate result ever recorded on the target machine.**
- **"the vizier exit skip does not exist visually in the oracle."** — watching the reference. This
  is not a gate on the port; it is the comparison the port is measured against, and it is what
  forces §3A.

Standing: flash, glass, sand, slump and **the feet** all **PASSED**. **The exit walk skip is OPEN
and unattributed.**

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** No dispatch was open; this is work taken from Jay's two instructions
(*"run the oracle"*, then his observation). What was built is instrument only.

**★ The substantive item is a retraction of my own work, twice over**, and both are corrected in the
record rather than left to be cited: this report withdraws them, and P3.98's report carries a
retraction banner at its head. **P3.97's `+9/−3` figure should not be quoted again** — not because
it is necessarily wrong, but because it has never been measured.

Not present: any fix to the stride; the port-side `ch_dest` measurement (started, incomplete); the
oracle-side cel isolation.

`hal-sync` OK. Karateka untouched. `main` untouched.

### 7 — Uncertainty flags

- **★★ The exit skip is unattributed.** Two mechanisms proposed, both withdrawn.
- **★ `ch_dest` is 16-bit and the tap catches the high byte only** — the port-side measurement is
  begun, not done.
- **The oracle trace cannot yet name the vizier's own draws**; `IMAGE` pointers are not mapped to
  cel numbers.
- **The erase/draw asymmetry (3D.1) may be the answer or a red herring** — it is a real property of
  the code and it is unexamined.
- Carried: `Fdy` dropped at `cel_table+2` (dormant, live for the demo); the terminal beat's flowing
  sand never commented on; the characters' per-iteration draw; 0.20 s driver overhead;
  `$2310..$2329` blindness; sound stubbed as holds.

### 8 — Follow-up candidates

1. **The engine's real column**: full 16-bit `ch_dest`, filtered to the **draw** pass
   (`ch_cp == CP_DRAW`) and `ch_idx 0`, across the walk-out.
2. **The oracle's own six walk cels**: map `IMAGE` pointers back to cel numbers and compare their
   width subtraction against the port's `awid` 3,4,5,5,4,4.
3. Only then, an attribution — and only if those two disagree.

### 9 — User interaction during task

Jay: *"run the oracle"*; then **"the feet fix looks good"**; then **"the vizier exit skip does not
exist visually in the oracle."** All three quoted verbatim above.

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-16-a-caveat-that-does-not-change-the-verdict.md`

### 11 — Commit

`a2a2ceb` (the oracle trace), `b38b6ff` (the live runner's timings), `b97342c` (the feet gate),
`805f8eb` (the `ch_dest` sampling fix), and this report. Pushed to origin/wip.
