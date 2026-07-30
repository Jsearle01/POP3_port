## Form B Report — P3.28 — diagnose the per-step transition defect, densify, gate the pacing
**Class:** build (diagnosis + one fix). wip.
**PHASE 1 PARTIAL — two defects found where one was expected; one fixed, one open.**
**PHASES 2 AND 3 NOT REACHED** — HARD-STOP #5. Prod unchanged (`main` untouched; no HAL change).

### 0 — Receipt / status (C-35 stamp)
t0=2026-07-30T19:54:08Z (HEAD `27e96de` at receipt, wip). `git status --porcelain` showed **0** tracked
modifications at t0. Untracked at t0 = `.vscode/`, `nvram/`, `docs/ground-truth/*.pdf` (never committed, Jay's
standing rule), `POP-idioms-coco3-markers.md`, `content/intro/broderbund_splash_render.bin`.
HEAD at report = `3401184`.

---

### 1 — Summary

**The ablation attributed it, and it disproved this dispatch's own lead.** Overlap is not the variable and
peel ordering is not the cause. The dispatch marked that lead as a lead; it was wrong, and saying so is the
point of having marked it.

| variant | capture 1 | capture 2 | stability |
|---|---|---|---|
| A cel fixed, pos fixed | 0 | 0 | agree |
| **B cel fixed, pos every step** | 0 | 139 | DISAGREE |
| **C cel every step, pos fixed** | 65 | 72 | DISAGREE |
| D both every step (overlap) | 0 | 144 | DISAGREE |
| **E both every step, NO overlap** | 222 | 0 | DISAGREE |

**E is decisive:** disjoint old/new footprints (a 28 px move against a 24 px cel) and it still fails. And B
and C each fail *alone*, so it is not the combination either.

**There are TWO independent defects, not one** — which is why one dispatch did not close it.

**Defect 1, FIXED.** A cel change *without* movement skipped the peel entirely: the "has it moved?" test
compared x and y only, so the new cel was drawn straight over the old one's pixels with no background
restore. Variant C: **65/72 → 0/0, captures agreeing.**

**Defect 2, OPEN.** Movement every step still fails (B, D, E), independent of cel-change and of overlap.
Characterised precisely but **not diagnosed** — HARD-STOP #5, and the same judgement P3.27 made. §3D gives
the recommended next probe and the reasoning behind it.

**Phases 2 and 3 were not reached.** Densifying the demo is what defect 2 blocks, and the pacing gate needs
the dense demo. The shipped sparse demo is unaffected: 0 wrong at both captures, 8/8 at 512 KB and 128 KB,
intro PASS — so Jay's P3.27 mechanism gate still describes what is committed.

---

### 2 — Files modified
- `src/engine/char_draw.s` — the move test now also compares the cel, read from `ch_drawn` (what *this*
  buffer last drew); `ch_lastcel` added.

Commit `3401184`. Explicit-path staging. No HAL change, so the sync bridge is unaffected.
Ablation harness kept out of the repo: `…/scratchpad/p328/ablate.py`.

---

### 3 — Reasoning

#### 3A — The ablation, run before any theory

The dispatch's instruction was to run the 2×2 before forming a view, and it earned its keep: the theory I
would have reached for — the ordering/overlap lead — is refuted by the table in §1.

The harness rewrites `pri_demo` per variant, rebuilds, runs the room test, and reads
`verify_room_chars.py`'s two capture counts plus the stability verdict. **Stability is carried per variant,
not as an afterthought**, because it is what separates accumulating from systematic and has classified three
bugs correctly now.

One harness note worth recording: the script restores `char_draw.s` in a `finally`, so a fix applied *during*
a run is rolled back when it ends. The re-apply after the second run needed checking rather than assuming —
`grep -c` on the three markers, not a re-run.

#### 3B — What the table kills

- **Overlap is not the variable.** E moves 28 px against a 24 px cel, so the old and new footprints are
  disjoint, and it fails 222/0. The lead's mechanism — a save capturing cel pixels as background because the
  old cel is still on screen — requires overlap to be reachable. It is not the cause.
- **Peel ordering is not the cause**, for the same reason: ordering only becomes load-bearing under overlap.
- **It is not the combination of cel-change and movement.** B (movement alone) and C (cel-change alone) each
  fail independently.
- **It is not frequency-independent.** A passes; the shipped four-step demo passes. Both defects need the
  transition path running *every step* to appear.

#### 3C — Defect 1: the cel is part of "has it changed"

The move test compared **x and y only**. A character that changed cel while standing still therefore took the
static branch — no erase, no save, and the new cel drawn over the old one's pixels.

**Why that was ever safe:** P3.22 introduced the skip on the merge being idempotent —
`(((d&m)|s)&m)|s == (d&m)|s` — which holds for redrawing *the same* cel over itself. A **different** cel
breaks the premise: it leaves the previous cel showing wherever the new one is transparent, and it
accumulates frame over frame.

The test now also compares the cel, taken from `ch_drawn` — the draw-time shadow P3.27 added, which records
what **this buffer** actually drew. That is the correct source: the record's `CH_CEL` is what the VM wants
drawn *now*, not what this buffer holds.

**This is the third variant of one root assumption.** P3.22 skipped the peel when the position was unchanged;
P3.25 sized the peel buffer to the widest cel; P3.27 made the slot stride constant. Each time, the fix was
correct and the *premise* — that a character's footprint is characterised by its position, or by one cel's
dimensions — was still partly wrong. Defect 1 is the same premise once more: **"unchanged" has to mean
unchanged in everything the draw depends on**, and that is position *and* cel.

#### 3D — Defect 2: characterised, not diagnosed, and the probe I would run next

**What is known:** movement every step fails (B 0/139, D 0/144, E 222/0), independent of cel-change and of
overlap; movement every *four* steps does not (the shipped demo, 0/0). All three failing variants show the
accumulating signature.

**One observation worth carrying, marked as an observation:** E fails **222/0** — capture 1 wrong, capture 2
clean — the *reverse* of B and D (0/139, 0/144). Changing the step size moved *where in the cycle* the error
appears. That is more consistent with per-buffer state divergence than with a plain drawing error, but it is
a reading of three numbers, not a finding, and the probe should decide it rather than my inclination.

**Recommended next probe — one build, one run:** **disable the page flip and re-run variant B.** It splits
the remaining space cleanly:

- **Passes single-buffered** → the bug is in per-slot bookkeeping. Each buffer is redrawn roughly every 2
  frames while the VM steps every ~2.74, so the two buffers see *different subsets* of the state sequence;
  `ch_last`/`ch_seen`/`ch_drawn` per slot is exactly where that is tracked.
- **Still fails single-buffered** → the bug is inside one buffer's erase→save→draw for a moving character,
  independent of the flip.

This is the same shape as the two probes that worked: P3.27's freeze-the-VM (which localised the stride bug
in one run) and P3.21's peel-off. **Halve the space with a mechanical change before reading code.**

**Why I stopped rather than ran it.** HARD-STOP #5 names this explicitly, and P3.27 declined for the same
cause. This would be the **third accumulating bug in the peel subsystem**, and the pattern across P3.21,
P3.25 and P3.27 is that each was introduced or missed while writing new logic late in a long session. The
evidence is recorded so the next session starts from the table rather than from scratch.

#### 3E — What the pattern says about the subsystem

Three accumulating peel bugs (P3.21 rotation, P3.25 dimensions, this one), each found only when a *new usage
pattern* reached it, and each invisible to every test that existed at the time. The tests were not weak — they
were exercising a sparse path. **Every byte-exact result this engine has produced, including the one behind
Jay's mechanism gate, used a sequence that changes state once every four steps.**

That argues for a different kind of test rather than another fix: a matrix over the peel's actual state
space — move/no-move × cel-change/no-change × both buffers × dense/sparse — run as a suite rather than
reconstructed by hand each dispatch. The ablation harness written here is most of it (§8).

---

### 4 — Verification (AC-by-AC)

- **AC1 — ablation reported in full, before naming a cause.** **MET.** Five variants, both capture counts and
  the stability verdict each (§1), and the cause named only afterwards.
- **AC2 — cause attributed and fixed; lead corrected if wrong.** **PARTIAL.** Defect 1 attributed and fixed;
  defect 2 attributed to movement-every-step but **not root-caused**. The lead is stated plainly as wrong
  (§3B).
- **AC3 — dense sequence byte-exact AND stable.** **NOT MET** — defect 2. Not hidden: B/D/E in §1.
- **AC4 — demo densified.** **NOT MET** — blocked by AC3; densifying now would ship a known-broken picture.
- **AC5 — achieved cadence reported.** **NOT MET** — requires the dense demo.
- **AC6 — pacing gated by Jay.** **NOT MET** — requires AC4. Not withheld from Jay; there is nothing
  judgeable to show, which was P3.27's finding and remains true.
- **AC7 — one kernel; regressions; clean tree.** **MET.** No HAL change; room suite PASS at 512 KB and
  128 KB; intro PASS; tree clean.

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim):**
```
=== per-step transition ablation ===
  variant                    capture 1  capture 2  stability
  A_cel-fixed_pos-fixed      0          0          agree
  B_cel-fixed_pos-every      0          139        DISAGREE
  C_cel-every_pos-fixed      65         72         DISAGREE
  D_both-every_overlap       0          144        DISAGREE
  E_both-every_no-overlap    222        0          DISAGREE

=== after the cel-change fix ===
  C_cel-every_pos-fixed      0          0          agree
  B / D / E                  unchanged             DISAGREE

[shipped sparse demo]
  second (cel54 top 104 col 54, cel1 top 109 col 33): 0 bytes WRONG
  stability: all captures agree (0); the character MOVED between captures
[run_room_test] PASS      128K: PASS      intro: PASS
```

**25.2 bundled-artifact grep:** N/A — no sibling import. The fix is in POP's own two-track bundle
(`char_draw.o`).

**25.3 operator-runtime-smoke: NOT RUN this dispatch.** No live gate was requested or offered: the pacing
gate needs the dense demo (AC4), which defect 2 blocks. **Jay's P3.27 mechanism gate** — *"the animation
looks good so far"*, `live-disk`, RGB — still describes what is committed, since the shipped sparse demo is
byte-identical in behaviour to what he saw. Nothing here is self-certified.

---

### 6 — Reactive deviations
- **Fixed defect 1 mid-diagnosis** rather than only reporting it. It was definite, isolated by a single
  variant, and re-running the ablation with it in place is what proved defects 1 and 2 are independent —
  which is the dispatch's actual question.
- **Did not densify or gate**, per HARD-STOP #5 and because AC4 would mean shipping a picture known to be
  wrong.

### 7 — Uncertainty flags
- **Defect 2 is open** and is the sole blocker for the pacing gate (§3D).
- **Defect 2's root cause is unknown.** The per-buffer-divergence reading of E's 222/0 is an observation, not
  a finding; the probe in §3D should decide it.
- **The dense path remains unexercised**, so the engine's byte-exactness is still only established at
  four-step density — including under Jay's gate.
- Carried: the 0.14-frame cadence residual; the signed 16-bit frame compare wrapping after ~9 minutes;
  `aboutface` unexercised and invalidating baked parity when it fires.

### 8 — Follow-up candidates (the recommended order)
1. **Run the single-buffer probe on variant B** (§3D) — one build, one run, halves the space. Do this before
   reading any code.
2. **Fix defect 2**, then re-run the full ablation — all five variants 0/0 and agreeing, not just the one
   that was fixed. Defect 1 hid behind defect 2 precisely because only one variant was ever run.
3. **Promote the ablation harness into the suite** (§3E). It currently lives in the scratchpad and was
   rebuilt from a description; as a checked-in test over move × cel-change × buffer × density it would have
   caught all three peel bugs at the dispatch that introduced them. **This is the highest-leverage item
   here** — the fixes are cheap and the blindness is what keeps costing dispatches.
4. **Then** densify the demo and take the pacing gate (P3.28 Phases 2-3, unchanged).
5. **Bake the vizier walk set** at per-cel parity (E) — a real walk cycle judges cadence better than a
   strobe and is the natural content for the pacing gate.

### 9 — User interaction during task
Jay asked what should come next; the single-buffer probe and the peel-matrix suite in §8 are that answer,
recorded here rather than only in conversation.

### 10 — Candidate(s) captured this task
None new. This dispatch's lesson — a sparse test can be byte-exact for the wrong reason — was already
captured at P3.27 as `making-a-property-visible-to-a-human-is-also-a-stronger-test`, and §3E is a second
instance of it rather than a new principle. Recorded as an instance in this report instead of duplicating
the row (pool rule: never edit existing entries).

### 11 — Commit
`3401184` — the ablation table, the cel-change fix, and defect 2 characterised.
This report follows. Both pushed to `origin/wip`. `main` untouched; no force-push.
