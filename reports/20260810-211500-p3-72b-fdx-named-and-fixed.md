## Form B Report — P3.72b — the erase cleared Fdx on an assumption three lines of code disprove
**Class:** build. wip. Prod untouched. **Green at both memory sizes.**

### 0 — Receipt / status (C-35 stamp)
Continuation of P3.72 at Jay's "run the split" / "continue measuring". HEAD `8b0481e`, wip.
Sync bridge OK. Karateka and `main` untouched.

---

### 1 — Summary

**Named and fixed.** `co_here` writes `ch_tx` from `CH_X` and `ch_fdx` from `CH_FDX` **separately**, so the x that
reaches `ch_last` is the **raw CharX**. `co_erase` then did `clr ch_fdx`, on the stated grounds that *"the old
position already included it."* **It does not.** The save's column was `co_setup`'s `f(ch_tx + ch_fdx)`; the erase
reconstructed `f(ch_tx + 0)`. **The erase restored a column the save never wrote**, the peel came back holding the
room shifted, and the residue compounded into every later save.

**Why it hid:** every cel this scene has ever drawn had **Fdx 0** — `char_draw`'s own cadence note records Vwalk's
six frames as all Fdx 0 [FRAMEDEF.S:378-383]. **Palert is the first sequence in the port with a non-zero one**:
cels 5, 6, 7, 9 carry **−1, 2, 2, 1**. CharX is in **two-pixel units** at 4 px/byte, so **Fdx 2 is exactly one
byte column** — the measured signature.

**Room 8/8 + all three asset comparisons; walk 28/28 byte-exact both runs; `all captures agree`; both at 512 KB
and 128 KB; intro 17/17; bank assertion `0 of 28 captures unmapped`; sync bridge OK.**

---

### 2 — Files modified

**`38c22a8`** — `harness/tools/erase_trace.lua`, `harness/smoke/run_erase_trace.sh` (the record split).
**`8b0481e`** — `src/engine/char_draw.s` (the fix), `harness/tools/peel_trace.lua`,
`harness/smoke/run_peel_trace.sh` (the peel-content split). Explicit-path staging.

### 3 — Reasoning

**3A — How it was found: two splits, after five exonerations.**

The first split (`erase_trace.lua`) traced the princess's per-buffer records across her move and **exonerated
everything around the peel**: both buffers converge (`ch_drawn` 11/11, both `ch_last` = `129 151 6 43 0 1`),
`co_variant` never returns 0 (so P3.71's null-cel guard is clear — it was the only gate ahead of the
unconditional `co_draw`), `ch_move` fires throughout, and neither peel slot is overrun (vizier widest 470 B in
480; princess widest 336 B in 344). **The records were right and the pixels were still wrong**, which put the
fault inside the save/restore pair rather than around it.

The second split (`peel_trace.lua`) **dumped the peel contents** and compared them to the room:

```
1786 slot0  cols 36-41 :   0/258 bytes differ    <-- before any non-zero-Fdx cel
1786 slot1  cols 36-41 :  26/258
1795 slot0  cols 40-45 :   9/258
1795 slot1  cols 40-45 :  22/258
```

**A clean peel before her move and a polluted one after** splits save from erase and points inside the pair. The
first byte off reads `got $00 want $08` against the room's repeating `08 00 80` — **the room shifted one column**,
the same signature as the screen residue.

From there the source read is short: `co_here` is three lines of proof that `ch_last`'s x is raw.

**3B — The fix, and why Fdx is stored rather than folded in.** Fdx now goes into `ch_last`'s second spare byte
(+6; +5 is the facing added at P3.71) and the erase restores it. **Stored separately rather than pre-summed into
x**, because the harness and `verify_room_chars` both read this x and apply the cel's own Fdx themselves —
folding it in would make them double-count. Every term of `co_setup`'s expression is now in the record, which is
the actual invariant: *the erase reconstructs the save's column, so it needs the save's inputs.*

**3C — What this says about the earlier readings.** P3.71 called it "the first mirrored cel this port has ever
drawn" and the dispatch inherited that. **The mirror was never involved.** The discriminator was Fdx, and the
reason the mirror looked implicated is that Palert introduced both at once. Three further leads died on the way
(peel sizing, the peel-skip gate, my own null-cel guard) — each by measurement, none by argument.

### 4 — Verification

- **25.1 fresh tool output (verbatim):**
  - `run_room_test.sh` → `checks=8 passed=8 failed=0`; `PASS room intact outside the torch boxes`;
    `PASS flames flicker`; `PASS flame pixels are exactly cel 4/7`; `[run_room_test] PASS`
  - `verify_room_chars.py` → `first … 0 bytes WRONG` / `second … 0 bytes WRONG` / `stability: all captures agree (0)`
  - `run_walk_test.sh` → `bank_mapped_at_every_capture PASS (0 of 28 captures unmapped)`; **all 28 captures
    `0 bytes WRONG`**, including capture 03 (cel 7, Fdx 2) which was the first to fail; `STABLE`; `PASS`
  - **128 KB:** `run_room_test.sh` → `checks=8 passed=8 failed=0` / `PASS`; `run_walk_test.sh` → `STABLE` / `PASS`
  - `run_introseq_test.sh` → `checks=17 passed=17 failed=0` / `PASS`
  - `hal_sync_check.py` → `OK`
- **Bank occupancy:** 13,049 B of 16,384 (**79.6%**), tracks 11-13. Unchanged — this was an engine fix.
- **25.3:** **now worth offering** — see §5.

### 5 — What is NOT done

**The five remaining beats are not started**: `Vraise`, `Pback`, `Vexit`, `Pslump`, the 16-colour swap, the
`Prolog2` handoff. The hourglass stays out (856 B over, untouched).

**A gate is now warranted and I am offering it, scoped honestly:** what runs today is **`Palert` → `Vwalk` →
`Vstop`** — she hears the door and turns, he walks in and stops. **Not** the raise, the step back, the mirrored
exit, the slump, or the handoff. Her turn is motion-bearing and new, so per CLAUDE.md §4 it needs a **live** run,
not a still.

### 6 — Route accounting

The dispatch's route: split → name → fix → land six beats → gate. **This contains the split, the naming and the
fix.** It does **not** contain any of the six beats, and the gate is offered rather than taken. **Deviation:** the
§1 split as posed ("bake at x=129") could not discriminate, and I said so in P3.72 rather than forcing a verdict;
the two splits that did work were the ones named in that report's §7, run here at Jay's instruction.

### 7 — Uncertainty flags

- **`ch_last` now has one spare byte left** (+7). The next thing needing per-buffer draw-time state will have to
  widen the entry rather than borrow.
- The peel matrix is still unrun on the banked build.
- Carried: hourglass 856 B over; 513 B over the 32 KB bank for the complete scene; `$2310..$2329` read-tap
  blindness; `PlayCut0`'s sound sites; `shift_row.s` unwired.

### 8 — Follow-up

1. **Jay's live gate on Palert → Vwalk → Vstop** (§5).
2. The five remaining beats.
3. Re-run the peel matrix.

### 9 — Candidate captured

None new this turn — the operative lesson (a comment asserting an invariant the adjacent routine disproves) is
close enough to the existing `instrument-that-writes-the-register-it-measures` and P3.50 rows that filing a third
near-duplicate would be worse than folding at reconcile time.

### 10 — Commit

`38c22a8`, `8b0481e` — pushed to origin/wip.
