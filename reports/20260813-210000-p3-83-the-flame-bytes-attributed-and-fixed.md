## Form B Report — P3.83 — the flame bytes attributed and fixed; one clip bug left, diagnosed

**Class:** build. wip. Prod untouched.
**Room suite FULLY GREEN.** Walk suite green except one case, **diagnosed from first
principles and confirmed by measurement**, with the fix specified and **not attempted** (§7).
§4's re-encode not started — HARD-STOP #3, green is not reached.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-13T20:03:57-04:00 (HEAD `620feff`, wip). Now at `cbff02b`, pushed.
POP `main` untouched at `635f986`. Karateka untouched (`wip` `ac2b768`, `main` `5eb92b1`).
Build green. **Room: 8/8, room intact, flames flicker, `78 bytes byte-identical`.**
**Walk: bank guard, page signatures (1,155 frames), staged reads, `beats_visited 18 of 18`,
run-a-vs-b STABLE — all PASS. One failure: captures 14–17.**

---

### 1 — Summary

**★★ THE TWO FLAME BYTES ARE ATTRIBUTED BY SPLIT AND FIXED.** Three dispatches failed at
this; the cause was in `blit_blast`'s own header all along:

> *"S IS THE DESTINATION POINTER while this runs… Anything that touches S implicitly (jsr,
> rts, pshs of the return, an interrupt) is unsafe inside a blast."*

The pre-clip walker obeyed that **by accident** — it contained no call of any kind. P3.78d
added `bsr bc_trim` to the segment walk, and a `bsr` after a blast pushes its return address
**into the framebuffer**. Fix: `lds bc_saved_s` in `bc_blast_back`. **78/78 byte-identical.**

**★ `beats_visited` was never a scene fault.** The schedule reaches beat 17 at f5011; the
counter sampled only after first movement and missed the two beats before anything moves.
Fixed — and fixing it exposed the same class one level down (it then read `19 of 18`,
counting pre-init garbage), now bounded to the plan table. **18 of 18.**

**One failure remains and it is a real clip bug**, newly reachable now that everything else
is green: **a trimmed BLAST segment draws the wrong pixels** (§3C).

### 2 — Files modified

- **`d59b8fe`** — `src/engine/blit_core.s`: `lds bc_saved_s` in `bc_blast_back`.
- **`cbff02b`** — `harness/smoke/walk_test.lua`, `run_walk_test.sh`: beat sampler hoisted
  above the early return and bounded to `cel_plan..cel_plan_end`.

### 3 — Reasoning

**3A — ★★ THE ATTRIBUTION, AND THE DATA IS WHAT PROVED IT.** The dispatch demanded a split,
not elimination. Split A (blast path restored to its pre-clip register discipline) **changed
the symptom** — row 106 went from partial flame to pure background — which implicated the
blast path. Then decoding the cel settled it:

```
t1_8: rows=13 width=3
  row 4  screen 105: SKIP1@0 MERGE1@1 SKIP1@2
  row 5  screen 106: MERGE1@0 BLAST1@1 SKIP1@2   <<<
  row 6  screen 107: MERGE1@0 BLAST1@1 SKIP1@2   <<<
  row 7  screen 108: MERGE2@0 SKIP1@2
```

**Rows 5 and 6 are the ONLY two rows of thirteen that contain a BLAST — and screen rows 106
and 107 were exactly the two wrong bytes.** After a blast, S stays a framebuffer pointer
until the end of the cel; the *next* row's merge `bsr` pushes two bytes at S−2, S−1, landing
on the previous row's col 50. **The extent (2 of 39), the position (first column) and which
rows were hit all follow from one mechanism.**

**3B — What this retires.** Three confident wrong answers, all mine or accepted by me:
P3.80 bounded it to `blit_save`/`blit_erase` (disproved by reverting both); P3.82 narrowed
it to the merge/blast restructuring **by elimination** and said plainly that was not proof;
the Orchestrator's addressing lead was refuted by measuring the draw address. **The cause was
a calling-convention violation that no amount of auditing the clip arithmetic would find.**

**3C — ★★ THE REMAINING FAILURE, DIAGNOSED: A TRIMMED BLAST CANNOT TAKE FEWER SOURCE
BYTES.** Captures 14–17 fail, deterministically in both runs, all at **col 74 — the last
visible column** — with `got $FF` (the room showing through) where the cel's pixel belongs.

**The window is not the problem.** Measured live at the moment of the draw:

```
ch_col=70 ch_w=9  -> bc_lead=0 bc_keep=5   draws cols 70..74
ch_col=69 ch_w=10 -> bc_lead=0 bc_keep=6   draws cols 69..74
ch_col=74 ch_w=6  -> bc_lead=0 bc_keep=1   draws cols 74..74
```

Every case is correct and includes col 74. **The fault is the blitter's execution of it.**

`cel_blit_prep` bakes each blast segment's groups **in the order `blit_blast` consumes
them — high destination address first** — so which source byte belongs to which column
depends on the segment's **FULL length**. Trimming the destination and taking the first
`run` source bytes therefore draws the wrong pixels. **I identified this at P3.78d and lost
it**; it is written in that commit's own message.

**3D — The fix, specified and NOT attempted.** A trimmed blast should be blasted **in full
into a scratch row** and the kept part copied out — correct regardless of group order, and
paid only at a screen edge, since every unclipped blast keeps the stack path untouched:

```
bb_run   run == seglen ?  -> the existing fast path, unchanged
         otherwise        -> lds #bc_scratch_end ; blast the FULL segment
                             lds bc_saved_s      ; real stack back at once
                             copy bc_run bytes from scratch[pre] to X+pre
```

**Why I stopped rather than write it:** it is ~30 lines of 6809 that manipulate S — the
exact operation whose misuse caused §3A — and **I have damaged this file four times in four
dispatches with mechanical edits**, once producing a false diagnosis. That is a specific,
evidenced judgement about this edit in this file at this depth, not a blanket late-session
stop.

### 4 — Verification

**25.1 fresh tool output (at `cbff02b`):**
- `build.bat` → `=== BUILD COMPLETE ===`
- `run_room_test.sh` → `checks=8 passed=8 failed=0`; `PASS room intact outside the torch
  boxes`; `PASS flames flicker`; **`PASS flame pixels are exactly cel 3/8 over the room: 78
  bytes byte-identical`**
- `run_walk_test.sh` → `bank_mapped_at_every_capture PASS`; `engine_bank_guard PASS`;
  `page_sig_matched_every_frame PASS (1,155 checked, 0 mismatches)`; **`beats_visited PASS
  (18 of 18)`**; `staged_reads PASS (2 of 2 pages, cel_rd_err = 0)`; `STABLE`;
  **`stability: CAPTURES DISAGREE [0,2,4,17,28]`** ← §3C
- Beat trace: `vm_beat` rows 0..17, terminal at f5011
- Window trace: 11 distinct right-edge placements, all correct

**Both assertions still fire**: the zero-capture check and the bank-guard check are present
and their PASS lines are required by the runner. **Not run:** 128 KB, the intro suite.

**25.2:** N/A. **25.3: not offered** — one visual fault remains.

### 5 — Acceptance criteria

1. **Two bytes attributed by a split and fixed; 78/78** — **YES** (§3A).
2. **Two stale flame comments corrected** — **NO, not done.** They are recorded in §7 with
   the measured truth; the edit was not made.
3. **Two missing beats found on the machine; 18 of 18** — **YES**, and the fault was the
   checker, not the scene.
4. **Harness offsets swept** — **NO, not done as a sweep**, though two more stale checkers
   were found and fixed in passing (the beat window, the garbage-value count) and one more
   recorded unfixed (§7).
5. **Both suites fully green both sizes** — **NO.** Room green; walk has §3C.
6–8. **Re-encode, grouping, symbol verification, gate** — **NO.** HARD-STOP #3.
9. **Route accounting; sync bridge; Karateka and `main` untouched** — yes.

### 6 — Reactive deviations and route accounting

**The dispatch ordered §1 → §2 → §3 → §4. This contains §1 complete, §3's first half
(beats), and stops in §3's second half.** §2 (the comments) and the sweep were not reached;
§4 was correctly gated off by HARD-STOP #3.

**One deviation, stated:** §5.2's comment correction is trivial and I did not do it, because
I would rather hand over a tree whose last touch was verified than add an unverified edit to
close an AC. It is a two-line change and it is specified in §7.

Not present: the re-encode, the grouping, the sweep, the comment fix, the clipped-blast fix,
the turn, the hourglass, any gate. Swap not unwound; `shift_row.s` not reopened; draw-time
mirroring still ruled out on schedule grounds.

### 7 — Uncertainty flags

- **★ §3C is diagnosed, not fixed.** The diagnosis rests on the bake's group ordering
  (documented in `cel_blit_prep.py` and this file's header) plus the measurement that the
  window is correct. **It has not been proven by a split** — the honest status is
  *diagnosed with a mechanism and a measurement*, which is stronger than P3.82's "last
  candidate standing" but is not the same as demonstrated.
- **★ A fifth stale checker, found and NOT fixed:** `verify_room_flame_pixels.py:139` skips
  every position line with `if len(f) != 7`; `room_test.lua` has written **9** fields since
  P3.71. The character-footprint exclusion has been dead for eleven dispatches. It does not
  affect any current failure, but a character standing in front of a torch would be reported
  as broken flames.
- **Two stale comments** (§5.2), measured truth: torch 0 is **phase 3, width 3**
  (`build.bat` builds `--phase 3`; the machine reports width 3). `flame_cels.s:69` says
  "phase 0, 13x2B, px 112" and `cutscene_room.s:1105` says "phase 3, 13x3B — px 111".
  **Neither is right; the build is.**
- 128 KB and the intro suite not re-run this dispatch.
- Carried: the turn-to-exit disappearance; hourglass and flash unbuilt; ROOM.BIN 7 bytes of
  headroom; 0.20 s per-call overhead; `$2310..$2329` read-tap blindness.

### 8 — Follow-up candidates

1. **§3D's clipped-blast fix**, then green, then §4's re-encode.
2. **The harness sweep**, which has now surfaced its fifth stale checker by accident. Two of
   the five were found *today*, both while chasing something else.
3. The two comments; the turn; the hourglass and flash.

### 9 — User interaction during task

None.

### 10 — Candidate(s) captured this task

None new. §3A is a strong instance of an existing shape — the rule was written in the file
being edited, in a header the editor had not read — and §3C is a second instance of *a fact
I recorded and then lost* (P3.78d's own commit message names the blast-ordering problem).
Both are better folded into existing rows at reconcile time than filed as near-duplicates,
on the P3.76 §9 precedent.

### 11 — Commits

`d59b8fe`, `cbff02b` — pushed to origin/wip before this report.
