## Form B Report — P3.98 — the exit stride is the oracle's own; the runners now default to 128 KB

**Class:** build (tooling) + recon. wip. Prod untouched; **no `src/` change**.

**★★★ HARD-STOP §5.2 FIRES: THE ORACLE HAS THE SAME LURCH, SO THE STRIDE IS FAITHFUL AND I HAVE NOT
TOUCHED IT. ★★ And the dispatch's premise for expecting otherwise is wrong — the mirror anchor is not
a port construct; the port TRANSCRIBED it from `MLayGen`, with the citation already in the code.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-16T12:29:16-04:00 (HEAD `8c289c9` at dispatch; `04daaa0` at start of work, wip). Karateka
untouched. `main` untouched. Oracle source read-only. **No `src/` change.** Pre-existing, not mine:
`dist/mame-cfg/rgb/coco3.cfg`.

---

### 1 — Summary

| | |
|---|---|
| **★ §1** | **the stride is FAITHFUL — hard-stop, not fixed.** `MLayGen` does `SBC WIDTH`; the port copied it |
| **★ premise** | the dispatch's *"nothing in the oracle for it to vary in"* is **false** — corrected below |
| **§2** | all **ten** runners now default to **128 KB**, via one shared home |
| | both suites green at **128 KB first**, then 512 KB |
| **§2H ch.1** | swept the other per-cel anchors — **all already per-cel**; one flagged |
| **25.3** | **re-offered on the target machine**, three changes surfaced; pending Jay |

### 2 — Files modified

- `harness/smoke/ramsize.sh` — NEW; one home for the machine size
- `harness/smoke/run_*.sh` (ten) — source it instead of each carrying the 512-KB-default pattern
- `harness/smoke/run_room_live.sh` — banner: the faithful-stride finding, and that the gate is 128 KB

### 3 — Reasoning

**★ §2H's THREE CHECKS:**

1. **A second mechanism / another per-cel quantity treated as constant?** Swept the anchors the draw
   path uses: `ch_w`/`ch_h` come from `co_dims` per resolved variant; `bc_lead`/`bc_keep`/`bc_width`
   are per-cel and were hoisted to once-per-cel at P3.85d; the peel's row advance uses the cel's own
   width; `ch_awid` is per-cel from `cel_table+4`; `start_col` is a per-cel registry field.
   **All already per-cel.** The one constant is the sand's `FLOW_ROWS`/`FLOW_WIDE`, which is a
   genuinely fixed-size object, not an assumption. ★ **So the dispatch's expectation of a fourth
   instance is not borne out — reported as a negative rather than left as an open worry.**
2. **The calling routine.** `MLayGen` is reached only through the dispatcher at `HIRES.S:654`
   — *"Transfers control to MLAY if image is to be mirrored"* — so the `SBC WIDTH` applies to
   **mirrored draws only**. `LayGen`, the normal path, has no such arithmetic. That asymmetry is the
   whole finding, and reading the routine without its caller would have hidden which draws it governs.
3. **Grep the reports.** P3.97's recon named the mechanism; there was no report, which is why §1
   asked for one before a fix. This is it.

**3A — ★★★ §1: THE ORACLE HAS THE SAME LURCH.** The dispatch's precondition, and it settles the
matter against fixing anything.

The oracle branches on the mirror bit and the mirrored routine subtracts the image's own width from
its x coordinate:

```
MLayGen                    LayGen  (the normal path)
 JSR PREPREP                 ...no XCO / WIDTH arithmetic at all
 LDA XCO
 SEC
 SBC WIDTH
 STA XCO
```

The walk cels are **3, 4, 5, 5, 4, 4** Apple bytes wide, so the anchor moves **14 px across one
cycle** — comparable to the stride itself — and redistributes the apparent motion. That is what
produces `+5, +3, +5, +1, +9, −3` where the entry walk (not mirrored, no anchor term) gives
`−4, −12, −3, +2, −1, −2`.

**★★ AND THE DISPATCH'S PREMISE IS BACKWARDS.** It says: *"the mirror anchor is a PORT construct —
the Apple mirrors at draw time and never bakes a second copy, so there is nothing in the oracle for
it to vary in."* The first clause is true and the conclusion does not follow. **Baking a second copy
is a STORAGE difference; the ANCHOR is the oracle's own arithmetic**, and the port's is a
transcription — `cel_parity_rule.draw_x`'s docstring has carried the citation all along:

> *"a mirrored image is laid down one sprite-width to the LEFT of the same coordinate
> (MLayGen: LDA XCO / SEC / SBC WIDTH [HIRES.S:1202-1208])"*

So the question *"does the oracle do this too"* was answered inside the port's own source before I
started. **The lurch is Mechner's.**

**This is P3.51's back-step exactly** — `db 51,chx,-1`, one positive delta among five negatives,
which looked like a defect and was the oracle's data. *"This looks wrong" and "this is ours" are
different claims*, and here they separate the same way. **Not fixed.**

**★ SCOPE OF THE EVIDENCE, stated because §2 ranks the trace above the source:** this is a
**source-derived** conclusion, not a traced one. It is unusually strong for a source read — the
branch, the routine, the instruction, and the port's own transcription note — but the oracle was
**not run**. The dispatch anticipated this (`addcharx` is a bodiless stub, so P3.51 could confirm
data but not appearance). **If Jay wants it settled on the machine, that trace is the next step**;
it would change the confidence, not the answer, unless the oracle's `WIDTH` at `MLayGen` time
differs from the image's byte width, which nothing suggests.

**3B — §2: THE POLICY AND THE DEFAULT WERE TWO HOMES FOR ONE FACT.** P3.97 committed `2K` — *128 KB
is the verification target* — and left ten runners each carrying:

```
RAMOPT=""
[ -n "${MAME_RAM:-}" ] && RAMOPT="-ramsize $MAME_RAM"
```

so `-ramsize` was passed **only** when someone remembered a variable, and the bare command ran
512 KB. **`CLAUDE.md` said one thing and the tooling did the other.**

Now: `harness/smoke/ramsize.sh` is the single home (`MAME_RAM="${MAME_RAM:-128K}"`), sourced by all
ten. `MAME_RAM=512K` is the explicit opt-in. **The file carries the reason** — the GIME's mod-16
aliasing, and P3.10's `$18` that was *"fine on 512 KB and fatal on 128 KB"* — so the next person to
consider flipping it back reads the precedent first.

**★ AND WHAT IT MEANS FOR THE RECORD**, per the dispatch: every report before now that says "green"
**without naming a size was 512 KB**. Not a reason to re-run history; a reason not to cite an old
bare "green" as evidence about the target machine. That is written into `ramsize.sh` rather than
only here.

Hard-stop §5.4 did not fire: nothing broke. Both suites pass at 128 KB **and** at 512 KB.

### 4 — Verification (AC-by-AC)

- **AC1 the oracle checked FIRST; if it has the same skip the stride is faithful** — **MET, and it
  does** (3A). **Nothing was changed.**
- **AC2 mechanism stated, then fixed in one home** — **first half MET, second half CORRECTLY NOT
  DONE.** AC2 presupposes a defect; hard-stop §5.2 overrides it.
- **AC3 the stride verified as a rate on the machine** — **N/A**: there is nothing to verify, because
  nothing changed. The rate work that would have followed a fix is not owed. *(P3.97's recon already
  measured the stride on the machine — `ch_drawn` == `CH_CEL` at every step, deltas exactly the
  oracle's.)*
- **AC4 runners default to 128 KB; §2K and the tooling agree** — **MET** (3B).
- **AC5 anything else anchoring on an assumed-constant per-cel quantity** — **MET, as a negative**
  (§3 check 1).
- **AC6 suites green, 128 KB first; build by symbol** — **MET** (§5).
- **AC7 25.3 re-offered with the three changes surfaced** — **MET; pending Jay.**
- **AC8 route accounting; sync; Karateka; `main`** — **MET.**

### 5 — Verdict-time evidence (v0.7 §11)

**25.1**, in `2K`'s order:

**128 KB (target, now the default):** walk `PASS`, `STABLE`; room `PASS`.
**512 KB (confirmation, explicit):** walk `PASS`, `STABLE`; room `PASS`.
`. ramsize.sh` → `MAME_RAM=128K  RAMOPT=-ramsize 128K`.
Build: `[hal-sync] OK`; `=== BUILD COMPLETE ===`; `ok every ALTSET2 frame's table resolves to the
file decodeim names`. Symbols unchanged from P3.96's freshly baked image (no `src/` or content
change this dispatch).

**25.2** N/A — ROM build.

**25.3 RE-OFFERED, PENDING JAY.** `live-disk`, RGB, **and 128 KB — the first gate ever run on the
target machine.** Surfaced: **the feet** (eight `vcast` cels now full height — his defect across
three gates, shipped at P3.96 and never affirmed); **the five strobes and the flowing sand**; **the
glass/sand split**. And the stride finding, with the choice put to him explicitly: it is faithful,
so smoothing it would be a deliberate divergence and **his call, not mine**.

**★ RESULT — Jay, live-disk, RGB, 128 KB, 2026-08-16: *"the feet fix looks good."*** That closes the
defect he reported across **three** gates (P3.87 *"all of him but his feet"*, P3.94 *"except for his
feet … at the end of the raise or very beginning of his turn"*), shipped at P3.96 and unaffirmed
until now. **It is also the first gate result ever recorded on the target machine.**

Standing: flash, glass, sand, slump **and the feet** all **PASSED**; the exit stride is **faithful**
(P3.99 traced it on the oracle) and open only as a preference.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** §1's fix was **not performed**, and that is the dispatch's own hard-stop rather
than a deviation — but it means AC2 and AC3 are partly unmet by design, which I have said in §4
rather than reporting them as satisfied.

**One correction to the dispatch, made rather than absorbed:** its structural argument for expecting
the oracle to be smooth is wrong (3A). Had I taken it, I would have "fixed" a faithful stride into a
divergence — which is precisely what §5.2 exists to prevent.

**Beyond the dispatch:** `ramsize.sh` is a new shared file rather than ten edits, and it carries the
reasoning and the P3.10 precedent. §2 asked for the default to change; making it one home was mine.

Not present: any stride change; the oracle runtime trace; the characters' per-iteration draw.

`hal-sync` OK. Karateka untouched. `main` untouched.

### 7 — Uncertainty flags

- **★ The faithful-stride conclusion is source-derived, not traced** (3A). Strong — branch, routine,
  instruction, and the port's own transcription note — but the oracle was not run, and §2 ranks the
  trace higher. The open risk is narrow: that `WIDTH` at `MLayGen` time is not the image's byte width.
- **★ Whether Jay WANTS the faithful stride is a separate question from whether it is faithful**, and
  §2I makes it his: the mandate is the picture. If he wants it smoothed, that is a deliberate
  divergence and should be recorded as one.
- **The 128 KB default is new and has been exercised on two suites.** The other eight runners now
  default to 128 KB too and have not all been run since.
- Carried: the feet fix unaffirmed; `Fdy` dropped at `cel_table+2` (dormant, live for the demo); the
  characters' per-iteration draw; 0.20 s driver overhead; `$2310..$2329` blindness; sound stubbed.

### 8 — Follow-up candidates

1. **Jay's call on the stride** — faithful as it stands; smoothing it is a divergence he would have
   to want.
2. **An oracle runtime trace of `Vexit`'s walk-out**, if the source read is not enough confidence.
3. Run the remaining eight runners once at 128 KB to confirm the new default across the harness.

### 9 — User interaction during task

Jay, at the P3.96 gate: *"his walk out still looks like he's skipping not walking. almost like a
frame is missing."* — the observation this dispatch answers.

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-16-a-policy-and-a-default-that-disagree.md`

### 11 — Commit

`ea10eca` (the runners' default), the banner, and this report. Pushed to origin/wip.
