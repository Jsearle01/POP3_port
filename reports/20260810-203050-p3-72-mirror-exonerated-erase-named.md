## Form B Report — P3.72 — the split ran, the mirror is exonerated, and nothing accumulates
**Class:** build + recon. wip. Prod untouched. **Build left in the tree, condition stated** (§2).

### 0 — Receipt / status (C-35 stamp)
t0=2026-08-10T20:30:50-04:00 (HEAD `4c1f18c`, wip). Sync bridge green. Karateka and `main` untouched.

---

### 1 — Summary

**The x-129 split ran and found a real defect — but not this one.** The bake WAS baking the mirrored cel 11 at
`--start-col 124` while the machine draws it at **142**, because `aboutface,chx,9` moves her nine units after her
start x. Fixed. **The error did not move.**

**★ And the split could never have discriminated engine from checker, because both consume the same bake** —
changing it moves the two sides together. That is a property of the split as posed, not a result; I am flagging
it rather than reporting "the engine is at fault" as though the split had said so.

**What the measurements DO say — four exonerations and a characterisation:**

| | |
|---|---|
| **NOT the mirror** | the failure starts at **capture 03, cel 7, BEFORE she turns**, at her first column change; cels 2 and 4 are byte-exact |
| **NOT the peel slot** | her widest baked cel is **42×8 = 336 B** against a 344 B slot |
| **NOT the peel-skip gate** | `-DALWAYS_PEEL` is **bit-identical** (17/32), ablation verified by symbol |
| **NOTHING ACCUMULATES** | across 28 captures / 272 frames / both runs the count is **only ever 17 or 32** |

**The defect is the princess's ERASE**, and it is per-buffer: **buffer A carries residue at col 35; buffer B
carries her ENTIRE old footprint, cols 36-41, un-erased.** Her body draws correctly at cols 42-45 in both.

**Not patched, and the beats not started** — HARD-STOP #2.

---

### 2 — Files modified

**`1b7a58e`** — `harness/tools/bake_scene.py` (`needed()` returns the drawn x; `main()` uses it for
`--start-col`), `src/engine/char_draw.s` (the `-DALWAYS_PEEL` guarded ablation), regenerated
`content/cutscene/chars/{cel_image.s,walk_scripts.s,p11_m_src.s}`. Explicit-path staging.

**Tree condition: BUILDS, RUNS, KNOWN-BROKEN in one named place** — the princess's erase. Walk captures 01-02
byte-exact, 03 onward carry her residue; the vizier is byte-exact throughout; the bank assertion is green.

### 3 — Reasoning

**3A — AC1: the split, and what it actually settled.** Measured before rebuilding, from the trace itself:

```
cel 2..9  facing 0   BAKED at start-col == drawn start-col      (no discrepancy)
cel 11    facing 1   BAKED at start-col 124, DRAWN at 142        <-- the only one
```

Every unmirrored Palert cel already baked at the column it is drawn at; **only the cel that follows a `chx` did
not.** `--start-col` decides the cel's colour parity, so baking at a column the cel is never rendered at is
silently correct for a character who has not moved — which was every cel in this scene until Palert. **That is a
genuine latent defect and it is fixed** (the bake now prints `MIRRORED col 142`).

**It did not change the error: 17/32 before, 17/32 after.** So the bake's x is not the cause — and, as above,
this split *structurally* cannot separate engine from checker. **Authority tier: trace.**

**3B — AC2: the accumulation, and it is not one.** The dispatch asked what compounds between 17 and 32. **Nothing
does.** Across 28 captures spanning 272 frames, in two separated runs, the count takes **only two values, 17 and
32, and never anything else** — 05=32, 06=17, 07=17, 08=32, 09=32, 10=17 … 28=32. A compounding fault does not
sit bounded for 272 frames.

Measured per buffer against the room asset (rows 104-151):

```
front(A)   {35:14,          41:7, 42:32, 43:38, 44:36, 45:2}
front2(B)  {36:8, 37:6, 38:3, 39:3, 40:3, 41:10, 42:32, 43:38, 44:36, 45:2}
```

**Buffer B holds her entire old footprint (cols 36-41, w=6 at col 36) un-erased; buffer A holds a 14-byte
residue at col 35.** Her body is at 42-45 in both, and the checker's predicted position (col 40) is right.

**So 17 and 32 are two different buffers' fixed residues, and which one a capture sees is buffer parity.**
`verify_room_chars`'s `stability: CAPTURES DISAGREE — accumulating state bug` is a **misreading**: its stability
rule assumes two captures of the same scene, and two captures one buffer apart are not that. P3.71's report
carried the same misreading, and so did this dispatch's §1. **Correcting it is the finding.**

**3C — Three exonerations, each by measurement rather than argument.**
- **The mirror.** The walk suite with Palert shows `01 cel2 → 0 wrong`, `02 cel4 → 0 wrong`, **`03 cel7 → 38
  wrong`** — cel 7 is drawn at col 37 where cels 2 and 4 were at col 36. **The failure begins at her first
  column change, four captures before she turns.** The dispatch's framing ("the mirrored column") and P3.71's
  ("the first mirrored cel this port has ever drawn") are both wrong about the trigger.
- **The peel slot.** Her baked cels measure 43×6, 43×6, 42×6, 42×7, 42×8, 43×7, 43×6, 43×6, 43×6 — widest
  **336 B** against `PRI_PEEL` 344 B. No overrun.
- **The peel-skip gate.** `ch_scan`'s `ch_anymove` is decided once per frame while a footprint belongs to one
  buffer, so a stale footprint surviving a no-motion frame was the obvious candidate. `-DALWAYS_PEEL` forces it
  on: **the result is bit-identical, 17/32.** **Verified present by symbol** — `ch_scan_one` `$38D2` → `$38D7`
  and `flames.raw` 4,312 → 4,317 B, the exact 5 bytes of the ablation. A build that did not run returns 0; this
  one ran.

**3D — What is left, and why I did not patch it.** The erase writes at `ch_last`'s recorded x/y/w/h/parity. In
buffer B her old footprint is not erased *at all*, which is a different failure from buffer A's one-column
shortfall — two symptoms from one routine. Naming the line needs the record's contents at the frames around her
move, not another reading of the source. **HARD-STOP #2: report both readings and the next split; do not patch
toward a guess.** Three leads have been killed in this arc by exactly this discipline, and two more died today.

### 4 — Verification (AC-by-AC)

- **AC1 x-129 split run and reported; engine or checker named** — **split run and reported (3A). NEITHER named**,
  and the reason is structural: both sides consume the bake. What the split did name is a separate latent bake
  defect, now fixed.
- **AC2 the accumulation explained** — **done, and it is a misreading (3B).** Nothing accumulates; two buffers
  hold two fixed residues.
- **AC3 fixed, captures AGREE both sizes** — **NOT met.** The defect is not fixed.
- **AC4 five beats landed; hourglass boundary; occupancy** — **NOT started** (HARD-STOP #2). Occupancy stands at
  **13,049 B of 16,384 (79.6%)**; the hourglass remains 856 B over and was not approached.
- **AC5 suites green; bank assertion green; verified by symbol; checkers re-pointed** — **bank assertion GREEN
  (`0 of 28 captures unmapped`)**; symbol verification done (3C); **suites NOT green** — the princess's residue.
- **AC6 build left in tree, condition stated** — **done** (§2).
- **AC7 Jay gates LIVE** — **not offered.** The scene has a named, reproducible visual defect; gating it would
  spend Jay's time on something I can already describe.
- **AC8 route accounting; sync bridge; Karateka; `main`** — §6; bridge OK; both untouched.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim):**
- `bake_scene.py` → `pri cel 11 MIRRORED col 142 phase 2 OK` (was `col 124`); `19 baked, 0 failed`
- `build.bat` → `cel_image.raw: 13049 B flat image based at $C000` → `tracks 11..13`; `=== BUILD COMPLETE ===`
- `run_walk_test.sh` → `bank_mapped_at_every_capture PASS (0 of 28 captures unmapped)`; `01 … 0 bytes WRONG`,
  `02 … 0 bytes WRONG`, `03 (cel7 top 109 col 37) … 38 bytes WRONG`, thereafter 17/32 alternating; **both runs
  identical**
- `run_room_test.sh` → `checks=8 passed=8 failed=0`; asset comparison `FAIL … first at row 112 col 35`
- ablation → `-DALWAYS_PEEL`: `17 bytes WRONG` / `32 bytes WRONG` — unchanged; `ch_scan_one $38D2 → $38D7`
- `hal_sync_check.py` → `OK`

**Not run:** the peel matrix; the 128 KB pass (the 512 KB result is already red, so a second size would add no
information about this defect).

**25.2:** N/A. **25.3:** **not offered** (AC7).

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** The dispatch's route: run the x-129 split → name engine or checker → fix → land `Vraise`,
`Pback`, `Vexit`, `Pslump`, the 16c swap, the `Prolog2` handoff → live gate.

**This work contains:** the split, its result, a latent bake defect found and fixed, three exonerations, and a
corrected reading of the 17→32 figure. **It does NOT contain:** a named cause, a fix, any of the six beats, or
the gate.

**Deviation:** none from the specified method — §1's split was run as written. **The dispatch's premise that the
split would discriminate engine from checker did not hold**, and I have said why rather than forcing a verdict
out of it (3A). **I also contradicted two things the dispatch stated as established** — that the defect is the
mirrored column, and that 17→32 accumulates (3B, 3C). Both were inherited in good faith from P3.71, which I
wrote; both are wrong, and the measurements are above.

### 7 — Uncertainty flags

- **The erase fault is not named.** Known: begins at her first column change (capture 03, cel 7); buffer B leaves
  her whole old footprint un-erased, buffer A leaves 14 bytes at col 35; bounded, deterministic, two-valued;
  the vizier — who moves every step — is unaffected.
- **Next split (cheapest):** log `ch_last[pri][slot]` (x, y, w, h, par) and `ch_move` per frame across frames
  1755-1790, i.e. her move. Buffer B not erasing *at all* means either `ch_moved` returned 0 for that slot or
  the erase ran at the wrong offset, and the record distinguishes those in one run without a rebuild.
- **A second reading worth keeping open:** she is the only character whose *cel dimensions change between
  consecutive draws* (43×6 → 42×7 → 42×8 → 43×7). If `ch_last`'s w/h are written after the new cel is resolved
  rather than from the drawn one, the erase would restore the wrong extent — which fits buffer A's one-column
  shortfall.
- Carried: hourglass 856 B over; 513 B over the 32 KB bank for the complete scene; `$2310..$2329` read-tap
  blindness; `PlayCut0`'s sound sites; `shift_row.s` unwired.

### 8 — Follow-up candidates

1. **The erase record trace** (§7) — one run, no rebuild.
2. **`verify_room_chars`'s stability rule** should compare captures of the same BUFFER, or say "two buffers"
   instead of "accumulating". It mislabelled this defect and the label was believed twice.
3. The six beats, once the erase is settled.

### 9 — User interaction during task

None.

### 10 — Candidate(s) captured this task

None — the strongest candidate here (a checker's stability rule inventing an "accumulating bug" from a
two-buffer oscillation) is a near-duplicate of the P3.70 row on instruments distorting what they measure, and the
pool schema forbids editing an existing row. Worth folding at reconcile time rather than filed twice.

### 11 — Commit

`1b7a58e` — pushed to origin/wip before this report.
