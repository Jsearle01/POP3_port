## Form B Report — P3.90 — §2J added, the hourglass split lands, and P3.87's revert was an instrument fault

**Class:** doc + build. wip.

**★★ THE PRIOR REVERT WAS WRONG. P3.87 reverted this change on a homemade build-to-build diff;
write taps show the two builds doing IDENTICAL work, and the walk suite — comparing against an
independently composited expected picture — passes both. The change is render-neutral and is
now in the tree. ★ AND THE NEW EXIT WINDOW FAILED ON ITS FIRST RUN, TWICE, AND NEITHER WAS THE
PORT.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-15T15:00:48-04:00 (HEAD `e19d2cf`, wip). Karateka untouched. `main` untouched. Oracle
source read-only. Pre-existing and not mine: `dist/mame-cfg/rgb/coco3.cfg`.

---

### 1 — Summary

| | |
|---|---|
| **§1** | **`2J`** added (no shell heredocs); **both P3.89 additions struck** |
| **★ §2 gate** | the "defect" blocking the split was **an instrument fault** — settled before re-landing |
| **§2** | the split lands: **glass = scenery, sand = animation** |
| **★ §3 margins** | exit crosses **for two of three beats**; the middle one is **1,676 cy — THIN** |
| **entry** | **untouched, 108,890 cy, 8.00 f/play** — the glass is not up then |
| **★ new coverage** | the exit window found **two checker faults** and **zero port faults** |
| **25.3** | **pending Jay** — live gate offered |

### 2 — Files modified

- `CLAUDE.md` — `## 2J`; the two P3.89 additions removed
- `src/engine/char_draw.s` — `sc_body`/`sc_fresh`; the body drawn on state change, not per frame
- `harness/smoke/walk_test.lua` — third capture window on `SC_GLASS1`; per-buffer sand frame
- `harness/tools/verify_room_chars.py` — **cel 18 → `p18_src.s`** (was `pslump_src.s`)
- `harness/tools/fb_region_diff.py` — the authoritative two-torch exclusion
- `harness/tools/port_residue_writers.lua` — NEW; who writes the disputed bytes

### 3 — Reasoning

**3A — §1, AND WHY THE LETTER MATTERED.** `2J` was used, not `2H` — `2H` now means *Look past the
first mechanism*, so reusing it for the file-creation rule would have turned a dangling citation
into a silently misdirecting one. Both P3.89 additions struck as instructed; the §7 Form B pointer
went with them, so **§2H's three checks are now asked for only by §2H itself.** Noted, not
re-argued.

**3B — ★★ THE GATE: `scenery_frame`'S REDRAW IS NOT LOAD-BEARING, AND THE EVIDENCE THAT SAID IT
WAS CAME FROM A BROKEN INSTRUMENT.** §4 forbade costing the removal until this was known. Three
independent measurements, none of them the diff that caused the revert:

1. **Write taps on the disputed bytes** (`port_residue_writers.lua`, PC resolved to the enclosing
   routine per §2H check 2). At two separate offsets inside the reported residue, the shipping and
   cached builds produce **identical multisets**: `be_pair+4 ×78 $00`, `bb_tail+11 ×20 $FF`,
   `bc_merge_loop+8 ×14`, same 39/39 buffer split — differing only in the frame numbers a faster
   build reaches them at. **Nothing is missing a write.**
2. **`fb_region_diff.py` excluded ONE torch.** The authoritative predicate is
   `verify_room_chars.torch()`: `99 <= r <= 115 and (26 <= c <= 31 or 48 <= c <= 53)` — **two**
   column ranges, wider rows. P3.87 took `rows 104-113, cols 27-29` from a `run_room_test` **log
   message**. The second torch at columns 48..53 sits inside the span reported as residue. Worth
   112 bytes of the 2,041 — not the whole story, but §2H's third check failing in the one file
   whose job is deciding what counts as a real difference.
3. **The walk suite passes both builds identically** across all 44 captures, comparing against an
   independently composited expected picture rather than against another build.

**A homemade diff was trusted over the checker. The checker was right.** The cited mechanism
(a stale erase punching the body) is real in principle — which is why the warm-up stays — but it
was never what the residue showed.

**3C — ★★ THE EXIT WINDOW FOUND TWO CHECKER FAULTS AND NO PORT FAULTS.** P3.88 flagged that its
glass captures covered the object's arrival and stopped ~600 frames short of the exit. Armed on
`SC_GLASS1` with a 40-frame gap, the new window failed immediately:

- **`cel 18` resolved to `pslump_src.s`; it is `p18_src.s`.** Different files — 2,699 B against
  2,755 — so every capture of her on cel 18 was compared against the wrong artwork: **27 wrong
  bytes, stable, in the shipping build and the experimental one alike.** ★ **A WRONG table entry
  and a MISSING one fail differently**: a missing cel raises *"cel N is on screen but has no baked
  source"* and stops the run, which is how P3.88 found `v57..v85` in a minute. A wrong one checks
  real bytes against the wrong expectation and **reports a defect in the port**.
- **Five bytes in the sand rect were a checker race.** `sc_flow` is the frame the NEXT draw uses;
  the displayed buffer was drawn an iteration earlier. The sand frame is now recorded **per buffer
  at the buffer swap** — not at the top of the iteration, because `sc_flow` still changes inside
  `chars_frame` after `flm_idx` has ticked.

Both fixed; all 44 captures 0 bytes wrong. **New coverage found three faults this arc and every
one was in the checking, not the port** — which is the argument for building it.

**3D — ★★ §3: MARGINS, AND THE DISTINCTION EARNS ITS KEEP.** 4-frame boundary = 119,436 cy.

| scene beat | before | after | **margin** | f/play |
|---|---|---|---|---|
| 16 | 129,319 | 115,116 | **4,320** | 10.00 → 8.17 |
| 17 | 131,957 | 117,760 | **★ 1,676 — THIN** | 10.00 → 8.68 |
| 18 | 126,820 | 112,403 | **7,033** | 10.00 → 8.00 |

Scene mean **6.99 → 6.77 f/play**.

**★ HARD-STOP §6.3 FIRES ON BEAT 17.** 1,676 cy is **1.4%** of the budget it just got under, and
its **peak iteration is still 130,920 — above the boundary** — which is why 9 of its 28 steps land
on 10 rather than 8. So this **crosses for two of three beats and only partly for the middle one.**
*"Crosses the boundary"* would have been a misleading one-line summary; that is the point.

**★ THE GAMEPLAY IMPLICATION, since the margin is thin.** A cutscene drawing **two** characters at
98.6% of a 4-frame budget is a bad starting position for a demo drawing a prince, guards and
dynamic tiles. **Beat 17 is not safe to build on**, and anything added there goes straight back to
5 frames with no gradual warning — the grid is a floor, not a discount.

**ENTRY: untouched and unchanged**, 108,890 cy and 8.00 f/play, 19,313 cy from the 3-frame
boundary — exactly where it was, as it must be: the hourglass is not on screen during the entry.
**The entry's arithmetic said nothing about the exit's, and the exit's says nothing back.**

**3E — §2H's THREE CHECKS**, as §2H requires (the §7 pointer having been struck, stated here
because the rule asks for it):
1. **Second mechanism for another object class?** Yes, and it is the whole design: the glass body
   and the sand are two object classes in one routine, and separating them is the change.
2. **The calling routine.** `scenery_frame` is called from `chars_frame` **before** `vm_frameadv` —
   which is what makes a character's save capture body-over-room, and what the warm-up protects.
3. **Prior-report grep.** Done, and it is what caught P3.87's residue conclusion (3B).

### 4 — Verification (AC-by-AC)

- **AC1 §2J added; the two additions struck; letters reported** — **MET.** `2J`; sections run
  2, 2A…2J, 3.
- **AC2 split landed, prior failure reconciled not re-encountered** — **MET** (3B).
- **AC3 margins reported, entry and exit separately, gameplay noted** — **MET** (3D), including
  the thin one.
- **AC4 suites green both sizes, hourglass in the expected picture** — **MET.** 44 captures.
- **AC5 build verified by symbol from a freshly baked image** — **MET**: `sc_body = 4011`,
  `sc_fresh = 4013` in `build/obj/flames.map`.
- **AC6 Jay gates live** — **OFFERED, not met.** Not self-certified.
- **AC7 route accounting; sync; Karateka; `main`** — **MET.**

### 5 — Verdict-time evidence (v0.7 §11)

**25.1** `=== BUILD COMPLETE ===`; `[hal-sync] OK`; `[harness-offsets] all checked offsets agree`.
Room, both sizes: `checks=8 passed=8 failed=0`, `78 bytes byte-identical`. Walk, both sizes:
**44 captures, `0 bytes WRONG` at every one**, `beats_visited PASS (19 of 19)`,
`stability: all captures agree (0)`, `STABLE`.

**25.2** N/A — ROM build.

**25.3 — ★ PASSED (with one item qualified). Jay, live-disk, RGB, 2026-08-15: *"the three look
good."*** The three offered were the glass (no flicker, tear, or hole punched where the vizier
walks past it), the sand (still running), and her slump.

**The glass and the sand are affirmed without qualification** — both were on screen throughout the
observed run, and the glass is the object this dispatch changed: it now goes down twice per buffer
instead of ~20 times a second, so a stale-buffer fault would have shown exactly there. Jay's eye is
the only instrument that can judge it, because a suite cannot judge motion.

**★ HER SLUMP IS RECORDED AS QUALIFIED, NOT CLEAN.** The run this report observed closed at ~75
emulated seconds; the slump begins at **f4538 ≈ 75.6 s** (measured post-split, §3D's beat table).
So on that run it was not reachable. Jay may have re-run it longer — that is not visible from here,
and asking is cheaper than assuming. Until answered, the beat with the 1,676 cy margin is
**observed-unknown**, and *"not re-reported" is not "passed"* cuts the same way when the words are
positive: an affirmation cannot cover what was not on screen.

Standing: the flash **PASSED** (2026-08-15); the hourglass-before-flash, the turn disappearance and
the exit pace remain **open** — none of them touched this dispatch.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** Scope I added beyond the dispatch, all reported rather than folded in:

- **The exit capture window** — not asked for. Without it the split would have been shipped with
  its disputed region still unchecked, and §2's reconciliation could not have been done at all.
- **Two checker fixes** (cel 18, the sand race) — found by that window, fixed because they were
  reporting phantom port defects.
- **`fb_region_diff.py`'s torch exclusion** — corrected because it was evidence in P3.87's revert.
- **`port_residue_writers.lua`** — new; the instrument that settled §4's gate.

**The split is the dispatch's; the reasoning that let it land is not.** Not present: any peel work;
`scenery_frame`'s further removal; the `vb_tick` flash/sand branch fix; the turn disappearance.

### 7 — Uncertainty flags

- **★ Beat 17's 1,676 cy margin is thin and its peak still exceeds the boundary.** It crosses on
  the mean and not on every iteration.
- **The warm-up (`SC_WARM = 2`) is retained on principle, not on evidence** — the hazard it guards
  is real in the source order, but the residue that seemed to demonstrate it was an artifact. It is
  cheap; it has not been shown necessary.
- **P3.87's report stands uncorrected on this point.** Its §3E concluded the change was not
  render-neutral. That conclusion is wrong and this report supersedes it; the earlier text has not
  been edited.
- **Only 8 exit captures at a 40-frame gap** — the exit is spanned, not densely sampled.
- Carried: `scenery_frame`'s remaining per-frame work; the peel package; the turn-to-exit
  disappearance; the `vb_tick` branch (untraced); 0.20 s driver overhead; `$2310..$2329` blindness.

### 8 — Follow-up candidates

1. **Beat 17's remaining ~11,500 cy of peak** — the only thing between the exit and a clean 8.00.
2. **Trace the `vb_tick` branch** — still the cheapest open item with a Jay-reported symptom.
3. **The turn disappearance** — `ch_h`/`ch_w` and the page signature across `$0E → $0F`.
4. Sample the exit more densely if anything else changes there.

### 9 — User interaction during task

None during the task.

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-15-a-cross-reference-to-nothing-fails-silently-forever.md`

### 11 — Commit

`26df937` (§2J + strikes), `d3a3615` (the exit window + checker fixes), `fb2eb23` (the split),
and this report. Pushed to origin/wip.
