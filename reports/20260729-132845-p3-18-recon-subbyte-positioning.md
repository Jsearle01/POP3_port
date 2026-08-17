## Form B Report — P3.18 RECON — sub-byte positioning: how much does pixel precision grow the cutscene cel data, and does 128 KB hold it resident?
**Class:** recon. wip. No build — no `src/` change; measurement scratch lives outside the repo.

### 0 — Receipt / status (C-35 stamp)
t0=2026-07-29T16:12:58Z (HEAD `0e7bb23`, wip). `git status` clean of tracked modifications;
untracked = `.vscode/`, `nvram/`, `docs/ground-truth/*.pdf` (never committed, Jay's standing rule),
`POP-idioms-coco3-markers.md`, `content/intro/broderbund_splash_render.bin`.
No prod binary touched.

---

### 1 — Summary

**Jay's two questions, answered with measured numbers:**

**(1) How much does pixel precision grow the data? 1.20×, not 4×.** The naive worst case — every cel
compiled at all four sub-byte phases — is **3.98×** (100,770 B → 401,431 B), which confirms the recon's
"×4" estimate as an upper bound. But the vizier and princess never occupy all four sub-byte columns. Their
own `chx` deltas put each cel at **one or two** phases and no more: 41 of 49 cels need exactly **one**
phase, 8 need **two**, none need three or four. Mean **1.16 phases/cel**. Compiling only what the animation
actually reaches costs **120,498 B — 1.20× the byte-aligned baseline, +19,728 B.**

**(2) Does 128 KB hold it resident? No — and pixel precision is not why.** The **byte-aligned** set already
overflows: **100,770 B against a 32.0 KB free budget as the HAL stands, or 64.0 KB if 4-colour buffers are
packed.** Over by 66.4 KB / 34.4 KB respectively. Pixel precision adds 19.7 KB on top of a problem that is
already 100 KB. **On 512 KB all three models fit comfortably** (416 KB free as built; the all-4-phase worst
case fits with 24 KB to spare).

**The reframe: the 128 KB question is not about sub-byte positioning at all. It is about compiled sprites.**
The same 49 cels are **11.9 KB as raw packed bitmaps** and **100.8 KB as compiled code — 8.2×.** That trade
buys speed and costs an order of magnitude in RAM, and it is what puts the cutscene outside 128 KB.

> **CORRECTED after Jay's review — see §3G.** Every figure above counts the two CHARACTERS only. The
> scenery the scene also draws — torch flames, hourglass, post, stars — was left out of the budget
> entirely: **+19.1 KB compiled.** Jay was right that none of it needs phasing (it never moves
> horizontally, so the occupancy method already gives it one phase), but "needs no phases" is not "costs
> nothing to keep resident". The all-resident total is **120.4 KB, not 100.8 KB**, and the peak-beat figure
> I gave Jay in conversation was 4.4 KB short of fitting when it is really **23.6 KB** short. The same
> measurement opens a new option — §3G.

---

### 2 — Files modified
- `reports/20260729-132845-p3-18-recon-subbyte-positioning.md` — this report (only tracked change).

Measurement scratch (deliberately outside the repo, per AC5), retained for re-run:
`…/scratchpad/p318/{measure,verify,phases,fit}.py`, `ch6A/` (103 converted cels), `work/` (196 compiled
phase variants + assembled binaries).

---

### 3 — Reasoning

#### 3A — Cel identity: every link verified, because the first one I picked was wrong

The measurement is only as good as "which cels are the cutscene cels", so each link was checked against the
source rather than assumed:

| step | resolution | authority |
|---|---|---|
| sequence → cel numbers | `Vwalk` 48-53, `Vstand` 54, `Vraise` 67-76/83-85, `Vexit` 57-66/77-82, `Pstand` 11, `Palert` 2-9, `Pslump` 1/18 | `SEQTABLE.S:1496-1670` |
| `Vapproach` → ? | **= `Vwalk`** (`:96 dw Vwalk`) | `SEQDATA.S:94`, `SEQTABLE.S:128` |
| cel # → Fimage | `(n-1)*5` into `ALTSET2` | `CTRLSUBS.S:941` `getfindex` |
| which charset? | **`ALTSET2`, not `ALTSET1`** | `CTRLSUBS.S:927` — *"Princess & Vizier use alt set 2"* |
| Fimage → image | `Fimage & $7F` → 1-based index into `IMG.CHTAB6.A` | see below |

**I started on the wrong table.** `IMG.CHTAB4.VIZ` is the obvious file for "the vizier", and it is the
wrong one — that is the *sword-fighting* vizier, an enemy using `ALTSET1`/chtable4. `getaltframe2` names
the cutscene pair explicitly. The tell was arithmetic, not intuition: the VIZ table holds 32 cels and the
sequences reference frame numbers up to 85.

**The `& $7F` is evidence-backed, not a convenience.** Every cutscene Fimage resolves inside chtab6.A's 103
cels only when bit 7 is masked off. The anchor is in-repo: `GAMEBG.S:115` `stari hex 2a,2b` names chtable6
image 42, and `content/cutscene/flames/star42/converted.s` records its own origin as `IMG.CHTAB6.A` cel
`#42`. Bit 7 is a flag (facing, most likely); it is not part of the index.

#### 3B — Method: measure the pipeline that exists, by feeding it shifted input

A phase-*k* sprite is the same pixels shifted *k* pixels within the byte grid. So measuring the cost of
phase variants does **not** require building a phase-capable compiler — it requires phase-shifted *input*
fed to the untouched one. Each cel was unpacked to pixels, padded with *k* transparent pixels on the left,
repacked one byte wider, and compiled by `sprite_compiler.py` **unmodified**. That is what keeps this a
recon: nothing in the pipeline changed, and the number is what building it *would* cost.

Padding with index 0 is correct here because these cels carry no opacity sidecar, so index 0 **is** the
transparent token — the shifted cel draws the same picture, one to three pixels over.

**Code size was measured by assembling with `lwasm` and weighing the binary**, not by modelling 6809
instruction lengths in Python. A hand-rolled size model is exactly the kind of number that looks right and
is wrong. Cross-check: 926 instructions → 2,628 bytes = **2.84 B/instruction**, which is what a mix of
16-bit immediates, indexed stores and RMW sequences should weigh.

#### 3C — The growth measurement (§1 of the dispatch)

Per-cel, phase 0 vs phases 1-3, the growth is flat and near-exactly ×4 — 3.98× across the set, ranging
3.56×-4.80× per cel. **There is no free lunch inside a cel:** a shifted cel is one byte wider and its edge
bytes become partial, so mixed (read-modify-write) bytes go up and the code grows roughly in proportion.

| model | bytes | vs byte-aligned |
|---|---|---|
| **BYTE-ALIGNED** (today's pipeline, phase 0 only) | **100,770** | 1.00× |
| **OCCUPANCY** (only the phases actually reached) | **120,498** | **1.20×** |
| **ALL-4-PHASE** (the naive worst case) | **401,431** | 3.98× |

**Moving vs static, as the dispatch asked** — and the split is less meaningful than it looks. Classifying
by "does the cel appear in a sequence containing `chx`" gives moving 71,596 B / static 29,174 B, both
growing ~4×. But **phase is a property of the character's X, not of the cel.** Once the vizier has stepped
an odd number of pixels, *every* cel he draws is off-grid, including his standing cels — `Vexit` contains
`chx` and six frames of `54` (standing). The useful split is not moving-vs-static cels; it is **which
phases each cel actually reaches**, which is §3D.

#### 3D — The finding that changes the answer: occupancy, not ×4

Running the sequences as the engine does — from the positions the source sets (`startV0` CharX=197,
`startP0` CharX=120, both CharFace=-1 [`SUBS.S:1131,1147`]) and iterating until the state
(pc, phase, facing) repeats, so the phase set is **complete rather than sampled**:

```
  vizier  Vwalk   48:{0,2} 49:{0,2} 50:{0,2} 51:{1,3} 52:{0,2} 53:{1,3}
  vizier  Vstand  54:{1}
  vizier  Vexit   57..61:{0} 62:{2} 63:{3} 64:{2} 65:{2} 66:{3} 77..82:{1}
  vizier  Vraise  67..76,83..85:{1}
  princess Palert 2..9:{0} 11:{1}      Pslump 1:{0} 18:{0}
```

| phases needed | cels |
|---|---|
| 1 | 41 |
| 2 | 8 |
| 3 or 4 | **0** |

**Why the walk cycle needs only two.** From `Vwalk1` the cycle is `48, chx2, 49, chx6, 50, chx1, 51,
chx-1, 52, chx1, 53, chx1` — net **+10 px per cycle, and 10 ≡ 2 (mod 4)**. So the cycle alternates between
two sub-byte columns forever, and each walk cel is only ever drawn at two of them. The walk cels cost
**2.01×** (15,707 B → 31,510 B), not 4×.

This is a property of the *animation data*, and it is exact — not a sample. It is also fragile in a useful
way: a single `chx` delta changed by one pixel would change the modular arithmetic and could push cels to
3 or 4 phases. **The 1.20× is a measurement of POP's actual cutscene, not a general law.**

#### 3E — The fit (§2 of the dispatch), computed in 4-colour context

The dispatch is right that the 4-colour framebuffer is half the 16-colour one — **15,360 B, P3.17-measured,
not estimated.** But translating that into free RAM needs one correction:

**The ~30 KB is NOT currently freed.** `gfx.s` `GFX_DB_BLOCKS equ 4` maps a **four-block (32 KB) window per
buffer regardless of mode**. A 4-colour framebuffer needs two blocks. So the saving the dispatch expects is
real but **unclaimed** — releasing it is a small HAL change (allocate 2 blocks/buffer when the mode fits),
not an existing condition. Both cases are reported below, because computing only the optimistic one would
be the mirror of the pessimism the dispatch warned against.

Budget in MMU blocks (8,192 B), since that is the unit the GIME allocates. Program window
(`$0000-$7FFF`: engine, kernel, stack, assets) = 4 blocks.

| machine | buffer allocation | free | byte-aligned | occupancy | all-4-phase |
|---|---|---|---|---|---|
| **128 KB** | as built (4 blk/buf) | 32.0 KB | **OVER 66.4 KB** | **OVER 85.7 KB** | OVER 360.0 KB |
| **128 KB** | 4c packed (2 blk/buf) | 64.0 KB | **OVER 34.4 KB** | **OVER 53.7 KB** | OVER 328.0 KB |
| **512 KB** | as built | 416.0 KB | FITS | FITS | FITS |
| **512 KB** | 4c packed | 448.0 KB | FITS | FITS | FITS |

**The middle path does not rescue 128 KB.** Pixel-precise walk cels + byte-aligned everything else =
116,573 B — still 49.8 KB over the packed budget, because the walk cels are only 16% of the set. There is no
subset selection that fits, since the *baseline* is already 1.6× the budget.

#### 3F — The dormant capability, and why it is the real question

`sprite_compiler.py` has **no phase support of any kind** — one routine per cel, byte-aligned. Building
phase variants is itself unbuilt work (a scoped cost, not a flag flip).

But the HAL **already contains a complete 4-phase sub-byte shifter**: `HAL_gfx_blit_sprite`
[`gfx.s:966-990`], with `subbyte=0..3` at 2-bit units. It is **dormant, not missing** — behind
`ifdef POP_HAL_RUNTIME_BLIT`, disabled because **PA.6 measured the runtime blit at 54 cy/byte aligned and
88 shifted**, against a header comment claiming ~10/~55, and ruled it infeasible for gameplay's per-frame
budget. Re-enabling costs 1,231 bytes of HAL code.

**This matters because it inverts the memory picture.** The runtime-blit path stores *bitmaps*, not code:
**11.9 KB for the same 49 cels** (~23.9 KB with masks) plus 1.2 KB of HAL — roughly **13-25 KB, which fits
128 KB with room to spare**, and gets pixel precision for free because the shift happens at runtime.

**I am not recommending it, because I have not measured its per-frame cost for this scene and the honest
arithmetic is marginal.** Two characters ≈ 450 footprint bytes; at PA.6's shifted 88 cy/byte that is
~39,600 cycles against a 29,859 cy frame — over budget for a single frame, before erase/peel. Amortised
over a 3-video-frame animation step with two buffers it lands near ~26k/frame, which is under budget with
no margin. **PA.6's verdict was about gameplay's load, and the cutscene's load is different — but "different"
is not "measured".** That measurement is the natural P3.19.

#### 3G — What the budget left out, and the option it exposes (added after Jay's review)

Jay, reading the recon: *"did you remove the static graphics and the torch flames from the analysis?
anything that doesn't move or only moves vertically (not horizontally) shouldn't need phasing."*

**On phasing he is right, and it was already handled — but by accident of method rather than by design.**
The 49 cels came from the character sequence tables, so the scenery was never in the ×4. And the occupancy
method (§3D) makes his rule automatic: a cel that never moves horizontally is only ever drawn at one
sub-byte column, so it collapses to one phase by construction. That is precisely why 41 of 49 cels needed
one phase. `chy` does not touch X at all.

**On the budget he found a real omission.** The scenery is not in the ×4 — and it was not in the resident
total either, which was wrong. It has to be in RAM for the scene to draw:

| item | chtab6.A | compiled | raw bitmap |
|---|---|---|---|
| torch flames | #1-9 | 2,415 B | |
| post | #12 | 2,575 B | |
| **hourglass** | #13-21 | **14,571 B** | |
| stars | #42-43 | 42 B | |
| **total** | | **19,603 B (19.1 KB)** | **1,778 B (1.7 KB)** |

**The option this exposes.** Scenery is **11.0× worse compiled than stored as bitmaps** — a worse ratio
than the characters' 8.2×, because on small cels the fixed per-cel code overhead dominates. And these
objects sit at fixed positions, so they need **no shifter at all**: a plain byte-aligned blit is the cheap
54 cy/byte path, not the 88 cy/byte shifted one PA.6 ruled infeasible.

**Drawing scenery from data rather than compiling it saves 17.9 KB at almost no speed cost.** The hourglass
alone is 14.2 KB of straight-line code to animate falling sand.

That makes the sharper rule not "compile everything" but **compile only what moves horizontally, and blit
the rest from data** — a hybrid, rather than an all-or-nothing bet on the runtime blit:

| configuration | cost | vs 64 KB (packed 128 KB) |
|---|---|---|
| everything as data + runtime blit | ~15.2 KB | **fits, even unpacked** |
| peak beat compiled + **scenery as data** | 71.8 KB | over 7.7 KB |
| peak beat compiled + scenery compiled | 89.7 KB | over 23.6 KB |
| all cels compiled + scenery as data | 102.5 KB | over 38.4 KB |
| all compiled (§1 headline, corrected) | 120.4 KB | over 54.4 KB |

It moves the best compiled configuration from 23.6 KB short to **7.7 KB short** — within trimming distance,
where before it was not.

**Two supporting measurements, both from Jay's question rather than the dispatch:**

- **Per-beat working set.** The scene is sequential, so the union of 49 cels never has to be live at once.
  Peak beat is `Vexit` (23 cels) + the princess resident = 70,058 B byte-aligned. On 128 KB there is no
  spare bank to swap from, so per-beat residency means a disk load between beats — the thing Jay excluded.
  The beats do have natural cover (music stings, the princess turning), so whether it is truly excluded is
  his call, not an assumption I should make silently.
- **Merge overhead.** 29% of the compiled set — 28.3 KB — is read-modify-write merge code, needed only
  because a keyed pixel lands over unknown background. Compiled `--bg-zero` it is 1.40× smaller. That is
  **not a proposal** (the module docstring is explicit it is invalid under POP's peel model); it is a bound
  on what any compose-into-cleared-scratch design could recover — and the thing that composes into cleared
  scratch is the runtime blit again.

**A cel-identity thread left open.** Auditing the mapping against converted dimensions (prompted by Jay
asking whether flames were in the set) showed cels 1-77 resolve to indices 10-103, all character-sized
42-58 rows — but cels 78-85, labelled `vcast-*`, resolve to indices 1-8, which are 13×2 and **byte-identical
to the P3.17 flame cels**. Either the image numbering has a discontinuity `& $7F` does not capture, or those
are genuinely small spell-effect sprites (the vizier casts). **Bounded and non-load-bearing:** those 8 cels
are 2,102 B of 100,770 — 2.1% — and if they are really character-sized the total rises ~18 KB, making every
fit verdict worse, not better. No conclusion here depends on it.

---

### 4 — Verification (AC-by-AC)

- **AC1 — data growth MEASURED.** Met. 100,770 B → 401,431 B all-4-phase (3.98×); → 120,498 B at true
  occupancy (1.20×). Moving/static split reported (§3C) *and* its limitation stated. Pipeline emits no
  phases (§3F). Sizes are assembled-binary bytes, cross-checked at 2.84 B/instruction.
- **AC2 — fit computed IN 4-COLOUR CONTEXT.** Met. Framebuffer 15,360 B (P3.17-measured, half the 16c
  30,720 B) used throughout; the DHR figure is **not** carried. The ~30 KB saving is reported as real but
  **currently unclaimed** (`GFX_DB_BLOCKS=4`), and both allocations are computed. Middle path checked
  (§3E) — does not fit.
- **AC3 — tradeoff framed for Jay.** Met, §5. Recommendation left to Jay.
- **AC4 — full-game extrapolation flagged, not measured.** Met, §8.
- **AC5 — NO BUILD.** Met. `git status` shows only this report; all scratch is outside the repo.

---

### 5 — The tradeoff, for Jay's decision

| option | cost | 128 KB | 512 KB | fidelity |
|---|---|---|---|---|
| **Byte-aligned** (today) | 100,770 B | **no** (over 34-66 KB) | yes | characters snap to 4-px columns; PA.6a measured this as a real visible change |
| **Pixel-precise, occupancy** | 120,498 B (**+19.7 KB**) | **no** (over 54-86 KB) | yes | faithful sub-byte movement |
| **Pixel-precise, all 4 phases** | 401,431 B | no | yes (24 KB spare) | faithful; buys nothing over occupancy for *this* scene |
| **Middle path** (walk cels only) | 116,573 B | **no** (over 49.8 KB) | yes | partial |
| **Runtime blit** (dormant HAL) | ~15 KB | **yes** | yes | faithful — but per-frame cost unmeasured, PA.6 marginal |
| **Hybrid: compile what moves H, blit scenery** (§3G) | 71.8 KB peak-beat | **no** (over 7.7 KB) | yes | faithful; nearest miss on 128 KB |

**The decision this actually surfaces is not pixel-precision.** On 512 KB, pixel precision costs **+19.7 KB
on a 416 KB budget — 4.7% — and is essentially free.** On 128 KB nothing in the compiled-sprite path fits,
so the choice there is between the dormant runtime blit and not having the cutscene resident.

Three questions I would want Jay to rule on, in order:

1. **Is 128 KB still a target for the cutscene?** If 512 KB only, pixel precision is a cheap yes and this
   is settled.
2. **If 128 KB matters, should P3.19 measure the runtime blit for the cutscene's actual load?** It is the
   only path with the right memory shape, and PA.6's infeasibility verdict was measured against a different
   workload.
3. **Should the 4-colour block packing be claimed regardless?** It is ~32 KB on any machine, for a small
   HAL change, and it is free of the above.
4. **Should scenery stop being compiled at all?** (§3G, added after Jay's review.) 17.9 KB for objects that
   never move horizontally and so never needed the shifter. It is independent of every question above and
   the cheapest single saving found in this recon.

---

### 6 — Reactive deviations

- **Measured phase OCCUPANCY as well as the ×4 worst case.** The dispatch asked for the real delta versus
  the theoretical ×4 and for a moving/static split. The moving/static split turned out to be the wrong
  axis (§3C) — phase is a property of X, not of the cel — so I measured the axis that answers the question,
  and reported both. This changed the growth answer from 3.98× to 1.20×.
- **Reported the fit under two buffer allocations** rather than only the dispatch's "~30 KB freed", because
  that saving is not currently claimed by the HAL.

### 7 — Uncertainty flags

- **The runtime-blit per-frame cost for this scene is NOT measured** (§3F). The memory case is strong; the
  timing case is arithmetic from PA.6's cy/byte and is marginal. Do not treat §5's last row as feasible.
- **The occupancy result is specific to PlayCut0's `chx` deltas.** `10 ≡ 2 (mod 4)` is why walk cels need
  two phases; different deltas would give a different answer. It is exact for this scene, not a law.
- **Three cel numbers (186-188) were dropped** as a sequence-parser overrun past `Pslump` — outside
  ALTSET2's 90 frames [`FRAMEDEF.S:325`], so they cannot be cutscene cels. Dropped explicitly and counted,
  not silently. They do not affect the totals.
- **Eight `vcast-*` cels resolve onto flame-sized images** (§3G). Unexplained; bounded at 2.1% of the total
  and resolving it can only worsen the fit, so nothing depends on it — but the cel-identity chain is not
  fully closed.
- **Peel/save buffers are not in the budget.** Two characters at ~235/215 footprint bytes across two
  buffers ≈ 1 KB — immaterial against a 34-86 KB overshoot, but not zero.
- **The engine's own growth is not modelled.** The 4-block program window is assumed to still hold the
  engine, kernel, VM and scene assets; the sequence VM (P3.16 piece C) is unbuilt and will consume some.

### 8 — Follow-up candidates

- **P3.19 (the decision this report sets up): measure the dormant runtime blit against the cutscene's
  actual load** — 2 characters, ~450 footprint bytes, at the cutscene's animation rate, with peel. It is
  the only path that fits 128 KB.
- **Stop compiling the scenery** (§3G): 17.9 KB, no fidelity cost, no shifter needed. Cheapest saving here.
- **Close the `vcast-*` mapping** — 8 cels resolving to flame images; small, but the identity chain should
  not stay open.
- **Claim the 4-colour block packing** (~32 KB, small HAL change; would need the Karateka back-port route
  established in P3.17).
- **FULL-GAME EXTRAPOLATION — FLAG ONLY, not measured** (dispatch §4). 49 cutscene cels cost 100.8 KB
  byte-aligned. The game's library is ~600 cels; at this scene's mean (~2,057 B/cel) that is **~1.2 MB
  byte-aligned** — over twice a 512 KB machine, before any phase variants. Compiled sprites cannot be
  resident for the whole game on any CoCo3, so gameplay needs either streaming by level, or the runtime
  blit's ~8× smaller data. **This is a strategic flag for later, deliberately not measured here.**
- The `moving vs static` framing should not be carried into future dispatches; **phase occupancy** is the
  axis that predicts cost.

### 9 — User interaction during task
Jay reviewed the delivered recon and asked whether static graphics and the torch flames had been removed
from the analysis, noting that anything not moving horizontally should not need phasing. He was right on
the phasing (already handled, §3G) and the question exposed a genuine omission in the BUDGET: 19.1 KB of
scenery was uncounted, which made the peak-beat figure I had given him in conversation 19 KB optimistic.
Corrected in §1 and §3G, with the resulting hybrid option added to §5. Two further measurements (per-beat
working set, merge overhead) were made to answer his follow-up "what options do we have for 128 KB".

### 10 — Candidate(s) captured this task
`seeds/POP/live/2026-07-29-a-worst-case-multiplier-is-a-property-of-the-data-not-the-mechanism.md`
`seeds/POP/live/2026-07-29-a-budget-must-be-computed-in-the-unit-the-system-allocates.md`

### 11 — Commit
See below (pushed to origin/wip before this report was surfaced).
