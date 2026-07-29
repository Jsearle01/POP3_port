## Form B Report — P3.19 RECON — can a 100% runtime-blit draw path hit the frame budget on 128 KB?
**Class:** recon. wip. No build — no `src/` change; measurement scratch outside the repo.

### 0 — Receipt / status (C-35 stamp)
t0=2026-07-29T18:31:35Z (HEAD `5f539ab`, wip). `git status --porcelain` showed **0** tracked modifications
at t0. Untracked = `.vscode/`, `nvram/`, `docs/ground-truth/*.pdf` (never committed), `POP-idioms-coco3-markers.md`,
`content/intro/broderbund_splash_render.bin`. No prod binary touched.

---

### 1 — Summary

**YES — decisively, and with the conservative budget.** A 100% runtime-blit path drawing **pre-shifted
bitmaps** with a **stack-blast** inner loop draws the cutscene's heaviest frame in **19,579 cycles against
29,673 available — 66% of one hardware frame, 1.52× headroom.** The dispatch's borderline band was
25,000-32,000 cy; this lands below it, so **the reserve MAME prototype is not warranted** and is skipped.

**The "infeasible" ruling was about a different blitter.** PA.6 counted the repo's `HAL_gfx_blit_sprite` at
**54 cy/byte aligned, 88 shifted** — because it performs the sub-byte shift **at runtime, per byte**, and
pushes/pulls its loop counter per byte. Moving the shift into the data (P3.18: each cel occupies only 1-2
phases, so pre-shifting costs 1.20× RAM, not 4×) and blasting through the stack gives **3.67 cy/byte
asymptotic, 4.5-5.8 cy/byte on real 4-9 byte rows** for opaque runs. The merge case is **22 cy/byte** and
that is a 6809 floor, not an estimate. **An order of magnitude, from deleting the runtime shift.**

**The trade, stated plainly: the blit path costs 1.51× the compiled path in TIME and 8.2× less in RAM, and
both fit the frame.** Time is the thing 128 KB was supposed to cost us, and it does not.

| | compiled sprites | 100% runtime blit |
|---|---|---|
| heaviest frame | 12,947 cy (44%) | **19,579 cy (66%)** |
| cutscene cel RAM | ~120 KB | **~17-33 KB** |
| fits 128 KB | **no** | **yes** |

**So the platform question resolves in favour of holding the stock machine:** 128 KB does not force a slow
path, so it costs no fidelity. Jay's framing was that RAM is not fidelity but a missed frame rate is — on
this measurement the frugal path misses nothing.

---

### 2 — Files modified
- `reports/20260729-143012-p3-19-recon-blit-framerate.md` — this report (only tracked change).

Scratch (outside the repo, per AC6): `…/scratchpad/p319/{count,count2}.py`, reusing P3.18's
`work/` cel corpus.

---

### 3 — Reasoning

#### 3A — The honest blit path (dispatch §1)

**Pre-shifted bitmaps.** P3.18 measured that each cutscene cel is drawn at only 1-2 of the four sub-byte
columns (41 of 49 at one, 8 at two; mean 1.16), so baking the shift into the data costs **1.20×**, not 4×.
The blitter therefore never shifts — it draws a phase-correct bitmap straight. **This is the whole
difference between this count and PA.6's.**

**Opaque runs — stack-blast.** `S` and `U` are both auto-inc/dec pointers, so six bytes move per pair:

```
        pulu    d,x,y           5+6 = 11    six source bytes,  U ascends
        pshs    d,x,y           5+6 = 11    six dest bytes,    S descends
                                -------
                                22 cy / 6 bytes = 3.67 cy/byte
```

Costed from the same MC6809 timings `sprite_compiler.py` uses (`5 + bytes` for PSHU/PULU, hardware-verified
in P1.3). **The asymptote is not what a real cel gets** — rows are 80 B apart and cels are 4-9 B wide, so
every row pays a `leas` reposition and a partial push:

| row width | cycles | cy/byte |
|---|---|---|
| 4 B | 23 | 5.75 |
| 6 B | 27 | 4.50 |
| 9 B | 43 | 4.78 |

**Masked merge — 22 cy/byte, and this is a floor.** The cutscene cels carry no opacity sidecar, so index 0
is transparent (P3.18 §3B) and the vizier composites in front of the room:

```
        lda     ,s              4     read destination
        anda    ,u+             6     AND the mask
        ora     ,u+             6     OR the source
        sta     ,s+             6     write back
                                --
                                22 cy / byte
```

It cannot be done two bytes at a time: **the 6809 has no 16-bit AND/OR against memory and no
register-to-register logic op** (there is no `ora b`), so a merge is per-byte by construction. I looked for
a cheaper form and there isn't one.

**Why the strawman was 54.** PA.6's line 105 counts `stb <tmp | ora <tmp | sta ,y+ | puls b | decb | bne`
— a table lookup, a complement, and **a stack push/pull of the loop counter per byte**, even in the aligned
case. The improvement here is not cleverness; it is amortising loop control across a row and deleting the
runtime shift.

#### 3B — The count (dispatch §2), and it is deliberately unflattering

Two models were run. The first charged only the work I had thought of and returned 13,398 cy. **That is
exactly the kind of number this project has been burned by** (P3.4, and Jay catching the P3.18 scenery
omission), so a second model charges everything a real blitter also pays: a counted row loop (5 cy/row),
mode transitions where a row switches between descending stack-blast and ascending merge (10 cy × 3/row),
skip-run pointer advances (5 cy × 2/row), and per-call setup — save `S`, mask interrupts, load pointers,
dispatch on width, restore (40 cy × 3 calls/character).

**The loaded model is the one reported.** POP peels, so each character costs erase + save + draw per frame:

| component | blit cy | compiled cy |
|---|---|---|
| vizier 48×9B (largest cutscene cel) | 9,423 | 5,698 |
| princess 43×5B | 6,572 | 3,741 |
| torch flames 13×2B ×2 | 1,408 | ~1,000 |
| hourglass 25×6B | 1,680 | 2,364 |
| stars 1×1B ×4 | 496 | 144 |
| **heaviest frame** | **19,579** | **12,947** |

#### 3C — The budget, and a conflict I did not resolve silently

The dispatch's standing invariant says *"29,859 cy/frame MINUS the VBL/IRQ overhead"*. But
`project-state.md:24` records PA.2's finding: *"Budget denominator is **178,968 cyc/game-step** (POP
animates at 10 fps), not 29,859 — cost everything per step, not per VBL."* They differ by 6×. Both are
quoted rather than reconciled by me:

| budget | cycles | blit frame as % |
|---|---|---|
| **per hardware frame** (dispatch; 29,859 − 186 page-flip) | **29,673** | **66%** |
| per cutscene step (P3.17 measured 2.6 frames at SPEED 7) | 77,447 | 25% |
| per PA.2 game-step (6 frames, 10 fps) | 178,968 | 11% |

**I report against the tightest of the three.** Which is correct depends on the draw model — flipping every
frame (P3.17's room) requires a redraw every hardware frame; drawing directly to the displayed page (the
oracle's model) only requires one per animation step. **The verdict is the same under all three, so the
conflict does not need resolving to answer Jay's question** — but it would matter for a tighter workload,
and it should be settled before it is load-bearing.

#### 3D — The check that would have caught a broken model

A cost model can be wrong in the flattering direction and still look plausible. The strongest available
falsifier: **a runtime blit must come out slower than a compiled sprite for the same cel** — compiled code
is straight-line with no loop, no pointer arithmetic and no mode switching, so if my blit came out faster,
the model is broken regardless of how reasonable the cycle counts look.

| cel | compiled draw | blit draw | ratio |
|---|---|---|---|
| 48×9B | 1,784 | 4,735 | 2.65× |
| 48×9B | 2,474 | 5,242 | 2.12× |
| 43×5B | 1,454 | 3,912 | 2.69× |

**2.1-2.7× slower — right direction, plausible magnitude.** And the *erase* paths, which are pure copies in
both designs and so should nearly agree, land within 10-20% (1,940 vs 2,344; 1,221 vs 1,330). Two
independent ways for the model to have been wrong, neither of which fired.

#### 3E — What the blit path actually costs in RAM

P3.18 measured the raw bitmaps at 13,998 B (characters 12,220 + scenery 1,778). The blit path needs two
things on top, and the second is easy to forget:

- **pre-shifted phases: ×1.20** → 16,798 B
- **mask bytes**, because the merge reads a mask per byte. A naive "mask byte for every data byte" doubles
  it → **33,596 B (32.8 KB)**. Storing masks only for the 37% of bytes that are actually mixed → **~23,013 B
  (22.5 KB)**.

| variant | RAM | vs 32 KB free (128 KB as built) | vs 64 KB (4c packed) |
|---|---|---|---|
| masks for mixed bytes only | 22.5 KB | fits | fits |
| mask byte for every byte | 32.8 KB | **over by 0.8 KB** | fits |

So the naive mask layout lands *just* outside the unpacked budget — and P3.18's 4-colour block packing
(~32 KB, small HAL change) covers it twice over. **Worth stating because "13.7 KB of bitmaps" understates
the real requirement by 1.6-2.4×**, which is the same shape of omission as P3.18's scenery.

---

### 4 — Verification (AC-by-AC)

- **AC1 — honest blit path designed.** Met, §3A. Pre-shifted bitmaps (no runtime shift), stack-blast
  `pulu/pshs` inner loop, real masked merge. **3.67 cy/byte asymptotic / 4.5-5.8 real** opaque, **22
  cy/byte** merge, contrasted with the strawman's 54/88 and the reason for the gap identified.
- **AC2 — heaviest frame cycle-counted.** Met, §3B. Bytes × rate split opaque/masked, plus overheads, plus
  peel (erase + save + draw per character), plus animated scenery. **19,579 cy vs 29,673 available.** Both
  sides stated; the clean model (13,398) is reported alongside so the loading is visible.
- **AC3 — verdict.** Met. **YES**, decisively — 66% of the tightest budget.
- **AC4 — prototype only if borderline.** Honored: 19,579 is below the 25,000-32,000 band, so **no MAME
  prototype was run.** Cheap-first respected.
- **AC5 — decision framed for Jay.** §5, with the full-game note. Platform choice left to Jay.
- **AC6 — NO build.** Met. Only this report is tracked; all scratch is outside the repo.

---

### 5 — The decision, for Jay

**Does a 100% runtime-blit path hit the frame rate on 128 KB? Yes — at 66% of one hardware frame, with
1.52× headroom, on the most conservative of three defensible budgets.**

The consequence, in your framing: **holding the standard 128 KB CoCo3 costs no fidelity.** The frugal path
is not the slow path. It costs 1.51× the compiled path in cycles, and that 1.51× is spent out of headroom
that exists, not out of frame rate.

What this does and does not settle:

- **Settled:** the memory objection to 128 KB. ~17-33 KB of bitmaps against ~120 KB of compiled code.
- **Settled:** the speed objection to the blit path, at cutscene load. PA.6's ruling stands for the blitter
  it measured and does not transfer to this one.
- **Not settled:** gameplay. This counts two characters and scenery. Gameplay runs more actors (PA.5's
  actor-count work), and 3.1 characters/frame at this cel size is the ceiling this design gives.
- **Full-game implication (flag, not measured):** at the cutscene's ~249 B/cel raw, a ~600-cel library is
  **~150 KB of bitmaps pre-shift, ~180 KB with phases** — still over 128 KB resident, but against compiled
  sprites' ~1.2 MB it is the difference between "stream per level, as the oracle does" and "impossible on
  any CoCo3".

**My read, with the decision yours:** the evidence supports holding stock 128 KB. The one thing I would not
do is treat 66% as comfortable for *gameplay* — it is comfortable for this scene, and the actor-count
question is a separate measurement.

---

### 6 — Reactive deviations

- **Ran two cost models rather than one** (§3B). The clean model returned 13,398 cy and I did not trust a
  number that agreeable; the loaded model (19,579) is what the verdict rests on. Reporting both makes the
  loading auditable rather than a claim.
- **Reported three budgets** (§3C) because the dispatch's per-frame figure conflicts with PA.2's per-step
  denominator recorded in `project-state.md`. Used the tightest as primary. Did not resolve the conflict —
  that is not this recon's call.
- **Added the mask-byte RAM cost** (§3E), which neither the dispatch nor P3.18 accounted for. It changes
  the blit path's requirement by 1.6-2.4× and moves the naive layout just outside the unpacked budget.

### 7 — Uncertainty flags

- **The 22 cy/byte merge assumes mask bytes are stored in the source stream**, read via `,u+`. A different
  mask representation (run-length, or a stencil bitmap) trades RAM against cycles and was not costed.
- **Mode-transition overhead is estimated, not counted from an implementation** — 10 cy × 3 per row is my
  charge for switching between descending stack-blast and ascending merge inside a row. It is the softest
  number here. It is also 21% of the loaded total, so a 2× error on it moves the frame to ~23,600 cy — still
  inside budget, still below the borderline band.
- **Interrupts must be masked for the whole blit** (S is the stack pointer). ~19,600 cy ≈ 11 ms of masked
  time per frame. That is survivable within a 16.7 ms frame but interacts with the VBL IRQ and the frame
  counter, and was not modelled.
- **No prototype was run**, by design (AC4). The verdict rests on a static count cross-checked two ways
  (§3D), not on execution.
- **PA.2 vs the dispatch's budget denominator is unresolved** (§3C).

### 8 — Follow-up candidates

- **Settle the budget denominator** — per hardware frame or per animation step. It depends on whether the
  engine page-flips every frame (P3.17) or draws direct like the oracle, and it will be load-bearing for
  gameplay even though it was not here.
- **Cycle-count the blit path at GAMEPLAY actor counts** — this recon answers the cutscene only; 3.1
  characters/frame is the ceiling this design implies.
- **Decide the mask representation** (§3E, §7) — it is the difference between 22.5 KB and 32.8 KB.
- **Claim the 4-colour block packing** (carried from P3.18) — ~32 KB, and it covers the naive mask layout's
  overshoot outright.
- The `POP_HAL_RUNTIME_BLIT` dormancy comment should be annotated: its "infeasible" note is correct for the
  runtime shifter and is now demonstrably not a verdict on runtime blitting as such.

### 9 — User interaction during task
None — dispatch executed as written.

### 10 — Candidate(s) captured this task
`seeds/POP/live/2026-07-29-an-infeasibility-verdict-inherits-the-implementation-it-was-measured-on.md`

### 11 — Commit
See below (pushed to origin/wip before this report was surfaced).
