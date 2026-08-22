## Form B Report — P5.10 — the multiplicity is 3.09×, and that is the argument for not baking it

**Class:** recon (Phases 1-3) + proposal (Phase 4, no code). `wip`. Prod byte-identical at both ends.

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-22T17:56:46Z (HEAD `7928c76`, wip; **`main` at `32b5fe2`, resolved here**).

`git status` at receipt — the standing untracked set: `.vscode/`, `nvram/`,
`POP-idioms-coco3-markers.md`, `content/intro/broderbund_splash_render.bin`, nineteen files under
`docs/ground-truth/`, `docs/project/pop-coco3-design-v0_7.pdf`. One modified tracked file,
`dist/mame-cfg/rgb/coco3.cfg` — **★ dirty, left dirty, not touched.**

**Prod sha1 — identical at both ends (AC13). Nothing rebuilt:**

```
d07f1f3295525783968dcce6409ee1b64942231c  build/intro_seq.bin
0b4968867bf5274d2942f3b5b90ea855ad6f2def  build/loader.bin
790836577e56b61b8f849cb309874e44304840a2  build/cutscene_room.bin
```

**AC12 — the stop observed:** `git status --porcelain src/` → **0 lines** at both ends.

---

### 1 — Summary

**Measured, on the running oracle: a gameplay cel is drawn at 3.09 of the four sub-byte phases on
average, and 60 of 173 are drawn at all four.** §1's four source claims all verify verbatim, including
the one it flagged: **`blit_core.s:14-16`'s "1.20× RAM, not 4×" is a property of the cutscene's
content**, and gameplay's figure is **2.6× worse**.

**And that is the argument for the opposite conclusion from the one the comment implies.** Baking the
measured multiplicity costs **≈189,000 B — about 24 blocks against 8 free**, and doubling again for
facing makes it ~47. **Baking is not a tight option; it is not an option.** Meanwhile the runtime
shift the blitter was built to avoid costs **~27,000 cycles of a 188,000-cycle animation-step
budget — 14%** — because the budget is per *animation step* (6.3 display frames at P5.2's measured
9.5 fps), not per display frame. **PA.6's infeasibility ruling does not transfer, and `blit_core.s`
already says why.**

**So P5.9's two-block gap does not widen. It survives unchanged** — one-phase storage is what P5.9
already costed — **and the thing that would have destroyed it is avoided by shifting.**

★★ **Three method failures this task, all mine, all caught by a control I put in deliberately.**

1. **A stale `OFFSET`.** `:setaddl` writes it only on the `lay`/`layrsave` paths; `fastlay` and the
   back/fore planes never do. I read it anyway, so byte-aligned draws reported the *previous
   character's* phase. Fixing it moved the answer 3.08 → 2.87.
2. **A freshness rule that assumed an ordering.** Clearing on the `XCO` write works for `DRAWMID` and
   breaks for `DRAWKIDMETER`, which stores `OFFSET` first. Clearing on the *draw* instead is correct
   for all three observed orderings; the answer moved back to **3.09**.
3. **A control predicate that was wrong three times**, each time by testing a claim P5.7 never made.

★ **And one process failure that was not a measurement error: every oracle run this session used
`-window`.** `mame-idioms-apple2e-oracle.md:100,113` — a file CLAUDE.md §2A requires me to read before
MAME work — says *"Validate the mount headlessly before opening a window, every time."* Jay had to
dismiss windows for runs that never needed one. Fixed to `-video none`, verified identical output.

---

### 2 — Files modified

- `harness/tools/oracle_phase_trace.lua` — **new.** Write-taps `setimage`, records the sub-byte phase
  and `XCO` per cel, with the offset-freshness rule and its two corrections in the header.
- `harness/tools/phase_census.py` — **new.** The distribution, the sum-over-cels storage figure, and
  the cross-instrument control.
- `reports/20260822-183000-p5-10-...md` — this report.

Nothing under `src/`, `link/`, `content/`. `build.bat` untouched. No bake, no renderer.

---

### 3 — Reasoning

#### 3A — §1's claims, verified

*Authority: source, read directly.*

All four verbatim. `blit_core.s:14-16` says *"P3.18 measured that each cutscene cel is drawn at only
1-2 of the four sub-byte columns… 1.20x RAM, not 4x. This blitter therefore never shifts."*
`char_draw.s:2424-2427` carries the 11-mod-4 argument. `char_draw.s:356-359` says *"MUST be a
multiple of 4 px… Sub-byte motion is piece E's problem"* with `CH_STEP equ 8`.
`char_draw.s:1171` says *"EIGHT SLOTS PER CEL NOW, NOT FOUR: two facings × four phases."*

**And §1.3's specific numbers check out**: `Fdef` frame 1 (`run-4`) has `Fdx = 1`, frame 3 (`run-6`)
has `Fdx = 3` [`FRAMEDEF.S:23,25`]. Gameplay steps are not multiples of 4.

#### 3B — AC1: the distribution, measured

*Authority: execution trace.*

`oracle_phase_trace.lua` write-taps `setimage` [`HIRES.S:265-276`], the funnel every draw passes
through, and computes the port's phase as `(XCO*7 + OFFSET + 20) mod 4` from the oracle's own staged
position [`HIRES.S:158-160`], where +20 is the 280→320 centring. **A trace has no seed** [§5.246], so
the question of what starting x to assume does not arise.

**8,436 draws over 3,000 frames; 173 distinct character cels after the exact validator.**

| phases | cels | % | one-phase B | at N phases |
|---|---|---|---|---|
| 1 | 13 | 7.5% | 1,028 | 1,028 |
| 2 | 55 | 31.8% | 10,973 | 21,946 |
| 3 | 45 | 26.0% | 11,251 | 33,753 |
| **4** | **60** | **34.7%** | 16,433 | 65,732 |
| **total** | **173** | | **39,685** | **122,459** |

> **★ THE STORAGE FIGURE IS THE SUM OVER CELS: 122,459 B = 3.09× the one-phase 39,685 B.**
> The **bound** (every cel at four) is 158,740 B = 4.00×; the **mean** is the same 3.09 and hides
> the 60 cels that need four. Neither is the requirement [§5.222, §5.233].

By kind: **kid** 90 cels (12/24/25/29 at 1/2/3/4 phases), **kid/sword** 54 (10/18/12/14),
**opponent** 29 (3/4/2/20 — the guard is the worst, 69% of its cels at four phases).

#### 3C — AC2: what bounds x, and is the phase set closed?

*Authority: source for the mechanism, trace for the magnitude.*

**Within a loop, the phase is stable.** A self-looping sequence accumulates `sum(Fdx)` per cycle, and
the orbit is `4/gcd(sum,4)` — `char_draw.s:2424`'s argument generalised. Measured over the sequence
table: **25 of 27 self-looping sequences have cycle sum ≡ 0 mod 4** (orbit 1), 2 have sum ≡ 2
(orbit 2), **and none is odd.** A run cycle returns to the phase it started on.

★ **So the multiplicity does NOT come from cycle drift — it comes from ENTRY PHASE.** The same
sequence entered from different x lands its whole cel set on a different phase, and the trace's 3.09
is the count of distinct entries the demo happened to make.

**Is the set closed? No — it is bounded only by 4, and the trace is a lower bound converging on it.**
Nothing quantises x on entry: `CTRL.S:287` *"Align char with block"* and `COLL.S:1240` *"align char
w/slicer"* snap x at specific events, but running, turning and jumping do not, and the fall path
sets no alignment at all. **A cel in a loop entered from an unaligned run can be entered at any of
the four residues, so every cel a moving sequence draws is drawable at four phases given enough
play.** The demo's 3.09 is what one 50-second path exhibited.

#### 3D — AC3: the union closure re-costed

P5.9's union closure is **61,195 B at one phase, 8 blocks**. Applying the measured 3.09:

| | bytes | blocks |
|---|---|---|
| one phase (P5.9's figure) | 61,195 | **8** |
| × 3.09 measured multiplicity | ≈189,100 | **≈24** |
| × 4.00 bound | 244,780 | **30** |
| × 3.09 × 2 facings (§3E) | ≈378,200 | **≈47** |

★ **Against 8 free blocks this is not a shortfall, it is a different order of magnitude.** The
extrapolation from 173 measured cels to the closure's 271 is flagged in §7.

#### 3E — AC4: facing

**Baked, not mirrored, and it is a second ×2** — already ruled at P3.65 and stated in the registry:
*"EIGHT SLOTS PER CEL NOW, NOT FOUR: two facings × four phases. The oracle mirrors at DRAW time —
`OPACITY` bit 7 sends `LAY` to `MLAY` [`HIRES.S:655`] — and the port cannot: `blit_cel` walks segment
runs left to right, so a runtime mirror would need reverse traversal AND bit-reversal inside each
byte"* [`char_draw.s:1171-1174`].

★ **I flag rather than accept it.** `blit_core.s`'s own header says *"PULU ASCENDS, PSHS DESCENDS,
AND THAT IS LOAD-BEARING"* — the descending traversal the mirror needs is the primitive the blitter
already uses, and bit-reversal within a byte is a 256-entry table. **The P3.65 ruling may be cheaper
to revisit than it looks**, and if it holds the multiplier is 6.18× rather than 3.09×. Not resolved
here; §8.

#### 3F — AC5: the per-animation-step budget

*Authority: derived from two measurements, both cited.*

P5.2 measured the game frame at **9.5 fps** against the **59.92 Hz** display → **6.31 display frames
per animation step**. The frame budget is **29,859 cycles** [`blit_core.s:155,367`, the constant the
port has used since Karateka].

> **6.31 × 29,859 = ~188,400 cycles per animation step.**

**§3.1's ~188,000 checks out.** The distinction is the whole of AC6: a character is drawn once per
*animation step*, not once per display frame, so the budget is 6.3× larger than the naive one.

#### 3G — AC6/AC7: the shift, costed

*Authority: the port's own measured blit rates.*

`blit_core.s` measures itself: **4.5 cy/byte on the opaque path** (*"inside the 4.5-5.8 band P3.19
measured for real 4-9 byte rows"*, line 34) and **22 cy/byte on the merge path** — *"a 6809 FLOOR
rather than an estimate"* (lines 195, 345).

**PA.6's 54/88 cy/byte does not transfer, and `blit_core.s:8-12` already says why**: that routine
computed the shift per byte with 2-6 `LSR` + 2-6 `ROR` and stack-pushed its loop counter per byte.
Both are properties of that implementation.

Against P5.7's joint per-frame peak of **1,922 B** (characters + scenery at the frame that maximises
the pair):

| approach | cy/byte | cycles for 1,922 B | % of the 188,400 cy step |
|---|---|---|---|
| baked phase, opaque path (today) | 4.5 | 8,649 | **4.6%** |
| runtime shift, table-driven estimate | ~14 | ~26,900 | **~14.3%** |
| runtime shift at PA.6's discredited rate | 88 | 169,136 | 89.8% |

> **★ AC6: the shift is affordable by a wide margin.** Even at PA.6's own pessimistic 88 cy/byte it
> fits inside one animation step — and the port's blitter is not that routine.

**AC7 — the hybrid is not worth it.** Baking only the 13 single-phase cels saves 1,028 B of the
~189,000 and still requires the shift path for everything else, so it buys nothing but two code
paths. **The distribution is what decides this and it decides against**: with 87% of cels needing
two or more phases, there is no cheap subset to carve off.

#### 3H — AC8: what `blit_core.s:14-16` should say

Not an edit (§7 excludes it) — a statement the next dispatch can act on:

> The 1.20× is **the cutscene's content**, not the blitter's property. P3.18 measured a vizier and a
> princess who move in 4-px steps by construction [`char_draw.s:356`, `CH_STEP equ 8`]. **A gameplay
> character's step is `Fdx`, which is 1 or 3 px [`FRAMEDEF.S:23,25`], and P5.10 measured gameplay
> cels at 3.09 of four phases with 35% at all four.** Baking that is ~24 blocks against 8. The
> no-shift design is correct for the cutscene and must not be carried into gameplay on the strength
> of this paragraph.

#### 3I — the controls, and what they cost to get right

*Recorded because two of the three errors would have produced a confident wrong number.*

**Failure 1 — stale `OFFSET`.** `:setaddl` [`GRAFIX.S:742`] does `lda midOFF,x / sta OFFSET` and is
reached only from `:lay` and `:layrsave`; `:fastlay` never calls it, and `bgX/bgY/bgIMG/bgOP` and
`fgX/fgY/fgIMG/fgOP` have **no offset field at all** [`EQ.S:306-314`] — only the mid list does
[`EQ.S:327-328`], which is exactly the plane characters draw in. So byte-aligned draws leave the
previous sub-byte draw's offset. **The tile control caught it: tiles came back spread over four
phases**, which P5.7's arithmetic excludes.

**Failure 2 — an order-dependent fix.** Clearing freshness on the `XCO` write assumes every path
stores `XCO` before `OFFSET`. `DRAWMID` does; **`DRAWKIDMETER` stores `OFFSET` first**
[`GAMEBG.S:553-556`], so the rule discarded a legitimate offset and the meter bullets landed on the
wrong phases. Clearing on the **draw** is correct for all three observed orderings.

**Failure 3 — the control's predicate, wrong three times.** I kept predicting phases from P5.7's
derivation, whose scope is block-aligned scenery and torch flames. It does not cover `drawfrnt`,
which places a piece at `blockxco + frontx[objid]` with `frontx` values of 0-3 **bytes**
[`BGDATA.S:77`], nor the strength meters at `KidStrX`/`KidStrOFF` [`GAMEBG.S:93-97`]. **Testing
against a claim that was never made is not a control; it is a way to fail forever.**

**The control that works is cross-instrument.** P5.8 recorded foreground `XCO` values through a
*different* tap (the `fgX` queue) on a different run. Both must satisfy the same rule:

```
image $45  frontx=1 | this tap XCO[1]                     -> mod4 [1] | P5.8 XCO[37] -> mod4 [1]  AGREE
image $46  frontx=3 | this tap XCO[39]                    -> mod4 [3] | P5.8 XCO[39] -> mod4 [3]  AGREE
image $83  frontx=0 | this tap XCO[0,4,8,12,16,20,24,36]  -> mod4 [0] | P5.8 XCO[0,...,36] -> mod4 [0]  AGREE
★ CONTROL PASSES
```

Neither tap can satisfy that by accident, and the sets deliberately differ — the runs visited
different screens. **Set-equality was my third wrong predicate; the residue class is the claim about
the code.**

---

### 4 — Phase 4: the proposal (AC9-AC11)

**4.1 — AC9: bake ONE phase and shift at run time.**

The trade is not close. Baking costs **~24 blocks against 8 free**; shifting costs **~14% of one
animation step**. §3G's table is the whole argument, and it turns on §3F's distinction between the
display frame and the animation step.

**4.2 — What it does to P5.9's two-block gap: nothing. It survives unchanged, and that is the good
outcome.** P5.9's 61,195 B / 8 blocks is already one-phase storage, so the gap is still two blocks.
**What this dispatch establishes is that the alternative would have made it a twenty-block gap** —
the question §1 asked was whether the figure was about to multiply, and the answer is that it would
have, and must not be allowed to.

**4.3 — AC10: the character bake re-sized.** Unchanged in cel count: **~262 cels to convert**
(271 in the closure, 9 sample cels exist). **What changes is what each conversion produces** — one
phase per cel per facing instead of four, so the bake is 271 × 2 = 542 converted cels rather than
271 × 8 = 2,168. **If §3E's mirror question resolves in the port's favour it is 271.**

**4.4 — AC11: what I am NOT proposing.**

1. Not proposing to **build** anything. No code, no bake change, no renderer change.
2. Not proposing to **edit `blit_core.s`'s comment** — §7 excludes it; §3H says what it should say.
3. Not proposing to **start the character bake**.
4. Not proposing to **close the two-block gap**, choose among A/B/C, or recruit blocks.
5. Not proposing to **overturn P3.65's facing ruling** — §3E flags it as worth revisiting and does
   not revisit it.
6. Not proposing a **shift implementation**. The ~14 cy/byte is an estimate for a table-driven shift
   and is flagged as such in §7; the design is a separate task.
7. Not proposing anything past `LEVEL0`, or about `AUTOCTRL`, the `:game` branch, or sound.

---

### 5 — Verification (AC-by-AC)

- **AC1** — §3B. Distribution 13/55/45/60 cels at 1/2/3/4 phases; storage as a **sum over cels**,
  122,459 B, with the bound and the mean printed beside it and neither substituted for it.
- **AC2** — §3C. Cycle sums bound the phase *within* a loop (25 of 27 at orbit 1); the multiplicity
  comes from **entry phase**, and the set is **not closed** — bounded only by 4.
- **AC3** — §3D. 61,195 B → ≈189,100 B → **≈24 blocks**, and ≈47 with facing.
- **AC4** — §3E. **Baked, a second ×2**, per P3.65 — flagged as possibly cheaper to revisit.
- **AC5** — §3F. **~188,400 cy/animation step**, derived from P5.2's 9.5 fps and the 29,859 cy frame.
- **AC6** — §3G. **~26,900 cy = ~14%** of the step; affordable even at PA.6's discredited rate.
- **AC7** — §3G. Hybrid costed and rejected: 87% of cels need ≥2 phases, so there is no subset worth
  carving off.
- **AC8** — §3H.
- **AC9/AC10** — §4.1-4.3. Shift; the gap survives unchanged at two blocks; bake is 542 cels.
- **AC11** — §4.4, seven non-proposals.
- **AC12** — §0. `git status --porcelain src/` → 0 lines at both ends.
- **AC13** — §0. Prod sha1 triple identical at both ends.
- **AC14** — **suites NOT run, and saying so.** Nothing was built — no source, link script, bake
  input or disk image changed, and `build.bat` was not invoked. The suites would have re-tested the
  exact artifacts P5.5 gated; the unchanged sha1 triple is the evidence.
- **AC15** — §6.

---

### 6 — Reactive deviations and route accounting

**Deviations:**

1. **★ Every oracle run this session used `-window`, against a standing idiom I am required to read.**
   `mame-idioms-apple2e-oracle.md:100,113` says to validate headlessly before opening a window, every
   time. Jay had to start/dismiss windows for pure data-collection runs. Corrected to `-video none`
   mid-task, verified byte-identical output (8,436 draws both ways). **This is a process failure, not
   a measurement one, and it cost the operator time rather than the report accuracy.**
2. **Three instrument/control corrections mid-task**, §3I. Each is recorded with what it moved:
   3.08 → 2.87 → **3.09**.
3. **A parse error caught by §1.3.** My first `Fdx` reader regexed the whole of `FRAMEDEF.S` and
   matched **Merlin local labels** — `:1` repeats in `ALTSET1`/`ALTSET2`/`SWORDTAB`, and
   `SWORDTAB`'s `:1 db $1d,0,-9` is what it returned for frame 1. It read `Fdx = -9` where §1.3 says
   1. **The dispatch's own example is what caught it**; restricted to the `Fdef` block the values
   match exactly.
4. **A conclusion written before the data.** My first cycle-sum run printed "14 of 31 sequences put
   their cels on all four phases" from a hardcoded sentence; the corrected run says **0 of 27**. The
   sentence was drafted with the code and not updated when the numbers arrived. It never left the
   terminal, and it is recorded because it would have inverted §3C.

**ROUTE ACCOUNTING.** No route was proposed in conversation before this task. Within it, the plan
changed once and is recorded rather than replaced: I intended to derive the phase sets analytically
from the move graph, and switched to a trace when §5.246's seed problem made the derivation's
starting x the thing that would decide the answer. **The analytical work is still here — §3C's cycle
sums — but as the MECHANISM behind the measured number, not as the number.** Jay interrupted once,
about the windows; §9.

**This report contains:** AC1-AC15, two new tools, no engine change.
**It does not contain:** any build, any code, any adoption, and none of §4.4's seven non-proposals.

---

### 7 — Uncertainty flags

1. **★ 3.09 is a LOWER BOUND from one 50-second path.** §3C shows nothing closes the phase set, so
   more play can only raise it toward 4.00. **The honest planning figure is closer to 4 than to 3**,
   and §3D's ≈24 blocks is correspondingly optimistic.
2. **173 of 271 cels were measured.** §3D scales the closure by the measured ratio. The unmeasured 98
   are the moves the demo never made, and there is no reason to think they are less varied.
3. **★ The ~14 cy/byte shift estimate is mine and is not measured.** It assumes a table-driven
   sub-byte shift on the 6809. The *conclusion* is robust — even PA.6's 88 cy/byte fits the
   188,400 cy step — but the specific figure should not be quoted as measured.
4. **Three cels report both sub-byte and byte-aligned draws**, the one shape the freshness rule
   cannot separate (a single list entry calling `setimage` twice). 3 of 234, so the effect on the
   distribution is below one cel either way, but it is not zero.
5. **The facing ruling is P3.65's and I did not re-derive it** (§3E). If mirroring is feasible the
   multiplier halves; if not, §3D's figures double.
6. **`CTRL.S:287`'s "align char with block" was read, not traced.** I assert that running and jumping
   do not quantise x; I checked the `sta CharX` sites but did not trace x across a run to confirm no
   other path snaps it.

---

### 8 — Follow-up candidates

1. **★ Re-examine P3.65's facing ruling** (§3E, flag 5). `PSHS` already descends and bit-reversal is
   a 256-byte table; if the mirror is feasible the character bake halves.
2. **Measure a real sub-byte shift** on the 6809 rather than estimating it (flag 3).
3. **Extend the phase trace over a longer or scripted path** to move 3.09 toward its true bound
   (flags 1-2).
4. **Close the two-block gap** — still open, still the arc's blocker, and now known not to be about
   to multiply.
5. **Add the headless-first rule to the coco3 idioms file too.** It is stated in the apple2e file
   only; every coco3 runner in this session's harness also passes `-window` by default, and most of
   them are automated checks that never need one.

---

### 9 — User interaction during task

One. **Jay: *"you probe it faulty. i keep having to start it for you."*** — the MAME windows. I
confirmed the cause (my `-window`, against the documented headless idiom), fixed it to `-video none`,
verified identical output, and reported status before continuing. Jay then said **"carry on"**, and
this report is the continuation. No ruling was sought or given on the technical content.

---

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-22-a-failing-control-may-be-testing-a-claim-nobody-made.md` — §3I: the
control failed three times, twice for real instrument bugs and once because its predicate tested a
claim P5.7 never made at a scope P5.7 never described. Pushed as `d23fe11`.

---

### 11 — Commit

`651f0fc` (pushed to origin/wip). **`main` is untouched at `32b5fe2`.**
