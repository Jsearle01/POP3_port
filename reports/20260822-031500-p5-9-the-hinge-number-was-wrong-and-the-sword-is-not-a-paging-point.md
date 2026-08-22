## Form B Report — P5.9 — the hinge number was wrong, and the sword is not a paging point

**Class:** recon (Phases 1-3) + proposal (Phase 4, no code). `wip`. Prod byte-identical at both ends.

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-22T02:44:39Z (HEAD `5f5b122`, wip; **`main` at `32b5fe2`, resolved here**).

`git status` at receipt — the standing untracked set: `.vscode/`, `nvram/`,
`POP-idioms-coco3-markers.md`, `content/intro/broderbund_splash_render.bin`, nineteen files under
`docs/ground-truth/`, `docs/project/pop-coco3-design-v0_7.pdf`. One modified tracked file,
`dist/mame-cfg/rgb/coco3.cfg` — **★ dirty, left dirty, not touched.**

**Prod sha1 — identical at both ends (AC11). Nothing rebuilt:**

```
d07f1f3295525783968dcce6409ee1b64942231c  build/intro_seq.bin
0b4968867bf5274d2942f3b5b90ea855ad6f2def  build/loader.bin
790836577e56b61b8f849cb309874e44304840a2  build/cutscene_room.bin
```

**AC10 — the stop observed:** `git status --porcelain src/` → **0 lines** at both ends.

---

### 1 — Summary

★★★ **THE HINGE NUMBER IS WRONG IN TWO SEPARATE WAYS, AND THE BUDGET IS WORSE THAN P5.7 SAID.**

**First, a transcription error I propagated.** P5.1's summary table says W1 (kid ∪ guard) = **49,924
B**; **P5.1's own tool output, in the same report, says 49,742.** P5.3 and P5.4 cited the tool.
**P5.6 and P5.7 — both mine — cited the table.** The 182 B does not move a block count, but the
figure was wrong in the two reports the whole budget now rests on.

**Second, and this one does move it: W1 was never the right question.** The residency requirement is
*what must be resident so a load cannot be forced*, and §3 shows **a load cannot complete inside any
interval the game offers**. So the figure is the FIXPOINT, and for the union that actually has to be
resident:

| | bytes | blocks |
|---|---|---|
| W1, kid ∪ guard (P5.6's basis, corrected) | 49,742 | 7 |
| **W∞, kid ∪ guard — the correct figure** | **61,195** | **8** |

**P5.6 and P5.7 both budgeted 7 blocks for characters. It is 8.** With animated scenery and
foreground (6,879 B) and the tile page, the total is **10 blocks against 8 free — over by TWO, not
one.** §5.235's A/B/C is needed more than it was, not less.

**★ AC3/AC5 — the mode split buys exactly one block, and it is unreachable.** On the union,
kid-armed ∪ guard is 60,898 B (8 blocks) and kid-unarmed ∪ guard is 56,816 B (7 blocks) — **a real
block.** But it can only be spent by paging at the sword, and **`startfall` writes `CharSword = 0` on
the frame the floor disappears** [`CTRL.S:359`, *"so you can grab on"*] with no animation at all,
while a whole-track read on the port's own driver measures **119 frames** [P5.5's live gate log].
**Zero frames to cover a two-second load.** The answer is no, and it is no for a reason that needs no
arithmetic.

★ **§1's own framing does not survive, in the direction it hoped.** It expected the closure to be
"barely above depth-1", making depth moot. For the *kid alone* that is nearly true (51,630 vs
40,141). For the **union** — which is what must be resident — the closure is **11,453 B above W1 and
crosses a block boundary.** The depth question was not moot; it was the block.

---

### 2 — Files modified

- `harness/tools/mode_closure.py` — **new.** Fixpoint of the move graph, per sword mode, with the
  mode-change sites as barriers taken from the `sta CharSword` writes themselves.
- `reports/20260822-031500-p5-9-...md` — this report.

Nothing under `src/`, `link/`, `content/`. `build.bat` untouched. No bake, no renderer.

---

### 3 — Reasoning

#### 3A — AC1: W∞, the fixpoint

*Authority: Mechner source via P5.1's own graph tooling, reused rather than reimplemented.*

`mode_closure.py` imports `peak_residency.build()` and `ctrl_edges`, so the graph, the dispatch table
and the cel costing are the same code P5.1 was verified with. It reproduces P5.1's figures exactly —
W1's worst start is `runstop` at **40,141 B**, and the kid's fixpoint is **51,630 B**, both matching
[P5.1 §, and `Winf fixpoint (= the whole moveset) 51630`].

| set | cels | bytes | blocks | closure OF | interval |
|---|---|---|---|---|---|
| kid, W1 (peak over starts) | 185 | 40,141 | 5 | one control decision from the worst start | one decision |
| **kid, W∞** | 229 | **51,630** | 7 | every cel a reachable sequence can draw | unbounded |
| **guard, W∞** | 231 | **52,548** | 7 | as above, `usealtsets` mapping, sword unconditional | unbounded |
| **kid ∪ guard, W∞** | **271** | **61,195** | **8** | both actors resident together | unbounded |

**Sharing is large and already counted: 189 of the 271 cels are common, saving 42,983 B against the
naive sum.** The union is not kid+guard; it is 61,195 B.

★ **The kid's closure is only 28.6% above his one-decision peak, and that is what made "depth buys
nothing" look right.** It is wrong for the union, where the fixpoint crosses from 7 blocks to 8 —
and the union is the residency, because a guard is on screen during exactly the fight the kid's
armed set exists for.

#### 3B — AC2: the closures per mode

*Authority: source, from the writes rather than from a description of them.*

**Every `sta CharSword` in `CTRL.S`, with the sequence it reaches:**

| direction | site | sequence |
|---|---|---|
| → armed (2) | `CTRL.S:1613` `DoEngarde` | `engarde` 55 |
| → armed (2) | `CTRL.S:227` `:softland` | `landengarde` 63 — **but `cmp #2 / bne :1` means it only PRESERVES armed for the kid; a guard (`CharID ≥ 2`) always lands en garde** |
| → armed (2) | `CTRL.S:1578` | `turndraw` 89 |
| → unarmed (0) | `CTRL.S:800`, at `CharPosn` 171 | `resheathe` 92 |
| → unarmed (0) | **`CTRL.S:359` `startfall`** | `stepfall` 7 / `stepfall2` 19 / `jumpfall` 18 |
| → unarmed (0) | `CTRL.S:852`, `CharID == 0 → :drop` | the dropped sword |

Closures seeded from **`stand`**, with the opposite mode's transitions as **barriers** — the barrier
node is included (it draws during the change) but not expanded through:

| closure | cels | bytes | blocks |
|---|---|---|---|
| kid, armed (barriers = to-unarmed) | 228 | 51,333 | 7 |
| kid, unarmed (barriers = to-armed; FightCtrl denied) | 194 | 46,670 | 6 |
| **kid-armed ∪ guard** | 270 | **60,898** | **8** |
| **kid-unarmed ∪ guard** | 249 | **56,816** | **7** |

★ **The guard is armed unconditionally** — `SETUPSWORD`'s first test is *"live guard's sword is
ALWAYS visible"* [A.3, `CTRLSUBS.S:1590`] — so **the guard's armed set is in every union whatever the
kid's sword is doing.** That is why the split saves 4,082 B on the union rather than the ~5,000 the
kid-only figures suggest.

★ **A seeding error I made and corrected mid-task, because it decided the answer by construction.**
The first version seeded both modes from all 93 kid sequences, which puts the **fight** sequences in
the *unarmed* set by fiat — exactly what the mode split exists to exclude. It reported "the split
buys nothing." Seeded from `stand` and left to reachability, it buys a block. **The seed was doing
the work the closure was supposed to do.**

#### 3C — AC3: does the split buy anything? **Yes — one block, on the union.**

**8 blocks → 7.** Not on the kid alone (7 → 6 there, but the kid alone is not the residency).

#### 3D — AC4/AC5: is the sword a paging point? **No, and `startfall` settles it before the arithmetic**

*Authority: source for the transitions; the port's own measured gate log for the load.*

**The transitions, in frames, from the sequence table:**

| sequence | frames |
|---|---|
| `turndraw` | **2** |
| `engarde` | **7** |
| `resheathe` | **15** — the longest |
| `stepfall` / `jumpfall` | 4 |

**The load, measured on the port's own driver** — P5.5's live-disk gate, throttled, real FDC,
`build/tile_live.log`:

```
# frame  867  status=1 (mode set)
# frame  986  status=2 (page in)
```

**119 frames — about 2.0 s — for `disk_read_init` plus one whole-track read.** Cited, not estimated;
this is the run Jay watched.

**So the longest mode transition covers 15 frames of a 119-frame load — 13%.** Even `resheathe`, the
most generous case, is eight times too short.

★★ **And `startfall` is not a transition at all.** [`CTRL.S:355-361`]

```
*  No floor underfoot--commence falling
startfall
 lda #0
 sta rjumpflag
 sta CharSword ;so you can grab on
```

**The sword goes on the frame the floor disappears.** No animation gates it, no sequence precedes it,
and the player did not ask for it — walking off a ledge is enough. **A paging scheme keyed on
`CharSword` would be handed a mode change with zero frames of warning and a two-second load to
perform.**

> **AC5: the sword is not a paging point. The one block the split buys cannot be spent.**

★ And the reverse direction is no better: after `startfall` clears the sword, `:softland`'s
`cmp #2 / bne :1` means the kid **lands unarmed**, so re-arming needs `DoEngarde` — another
un-prefetchable transition, this one at the player's whim.

#### 3E — AC6/AC7: the block count and the budget

Under P5.6's rules — a cel cannot straddle a block boundary, so `ceil(bytes / 8192)`, and P5.6
measured real packing at 98–99% fill so the ceiling is achievable.

| claimant | bytes | blocks |
|---|---|---|
| characters, W1 kid ∪ guard (P5.6's basis, corrected from 49,924) | 49,742 | 7 |
| **characters, W∞ kid ∪ guard — the correct figure** | **61,195** | **8** |
| characters, kid-unarmed ∪ guard (only if pageable — it is not) | 56,816 | 7 |
| animated scenery + foreground [P5.7 6,105 + P5.8 774] | 6,879 | 1 |
| tile page (worst screen) | 7,582 | 1 |

**The budget, against 8 free blocks:**

| candidate | characters | + scenery/fore | + tile | total | verdict |
|---|---|---|---|---|---|
| W1 kid ∪ guard (what P5.6/P5.7 assumed) | 7 | 8 | 1 | **9** | over by 1 |
| **W∞ kid ∪ guard (correct)** | **8** | **9** | **1** | **10** | **★ over by 2** |
| kid-unarmed ∪ guard, if pageable | 7 | 8 | 1 | 9 | over by 1 — **and not reachable (§3D)** |

★ **These are LOWER BOUNDS on the block count, and I am saying so rather than presenting them as
exact.** P5.7 measured that animated cels must be **duplicated into** each character block that draws
them — 7,074 B of duplication for a 36,142 B character set across 5 blocks. At 61,195 B across 8
blocks the duplication will be larger, so the real total is ≥ 10 blocks.

> **AC7: A/B/C is still needed, for every candidate, and the overflow it has to close is two blocks
> rather than one.**

#### 3F — AC8: the character bake, confirmed and sized (NOT started)

*Authority: the tree.*

**Confirmed. `content/kid/` and `content/guard/` hold exactly nine cels**, and their names say what
they are:

```
content/kid/    kid_chtab1_040_large   kid_chtab1_047_median  kid_chtab1_064_thin
                kid_chtab2_002_median  kid_chtab2_003_large
                kid_chtab3_006_large   kid_chtab3_011_median
content/guard/  guard_gd_001_median    guard_gd_015_large
```

`large` / `median` / `thin` across three chtables — **a sizing exercise, not a bake.** The gameplay
character bake is **unstarted**.

**Sized:** the union closure needs **271 distinct cels**. Nine exist, and they are samples rather
than placements. **~262 cels to convert**, plus the guard's `usealtsets` mapping (231 of the 271 are
reachable as guard cels, with 189 shared).

**Does the existing tooling cover it?** Structurally yes, and the pipeline is the cutscene's:
`sprite_convert.py` → `cel_blit_prep.py` (segment format, sub-byte phase baked) → `cel_pack.py` /
`cel_table.py` (page packing and the registry). ★ **But there is a gap, and it is the one this arc
keeps rediscovering:** the cutscene's cels are converted at *known, fixed* `start_col` values because
the vizier and princess stand still. **A gameplay character moves, so his phase changes every frame**
— and §5.208's radius-1 context means a cel converted at one phase is not the cel at another. The
port already solves this for cels it owns (`blit_core.s` bakes the phase and the 4-phase shifter
handles placement), so the question is whether **four phase variants per cel** are needed in storage:
**271 cels × 4 = up to 1,084 variants**, which would be catastrophic, or whether the runtime shifter
covers it, which is what the HAL was built for. **Not resolved here, and it is the single largest
open question in the character bake.**

---

### 4 — Phase 4: the proposal (AC9)

**4.1 — Which residency figure the port should be built to: W∞ for the union, 61,195 B, 8 blocks.**

Not W1, and not per-mode. The reasoning is §3D's and it is short: **a residency requirement is
bounded by what a load can rescue, and here a load rescues nothing.** 119 frames against a 15-frame
best case and a 0-frame worst case means every reachable cel must be resident before play starts.
The interval is unbounded, so the figure is the closure.

**4.2 — Does the one-block overflow dissolve? No. It doubles.**

I hoped to retire A/B/C by dissolving the overflow. **The opposite happened**: the overflow is two
blocks, because the character figure was 7 blocks on a mis-transcribed W1 and is 8 blocks on the
correct closure. **A/B/C is not only still needed — none of the three, as costed in P5.7 §4, buys
two blocks.** Option A (stop holding the tile page) buys one.

★ **So this dispatch ends with a gap that no option on the table closes, and that is the finding to
carry forward rather than a proposal to adopt.**

**4.3 — What is NOT being proposed:**

1. Not proposing to **build** anything. No code, no bake change, no renderer change.
2. Not proposing to **start the character bake** — §7 excludes it and §3F only sizes it.
3. Not proposing a **way to close the two-block gap.** I did not find one, and inventing one at the
   stop would be worse than reporting the gap.
4. Not proposing to **choose among A/B/C**, nor to add a fourth option.
5. Not proposing **block recruitment**, the phase-variant question (§3F), the two-format ruling, or
   anything about the 14.3% [§5.241 — Jay's alone].
6. Not proposing to **re-run P5.1** — its tooling is reused unchanged here and reproduces its
   figures; only the summary table's transcription is corrected.
7. Not proposing anything past `LEVEL0`, or about `AUTOCTRL`, the `:game` branch, or sound.

---

### 5 — Verification (AC-by-AC)

- **AC1** — §3A. W∞ kid 51,630, guard 52,548, **union 61,195**, against W1's 40,141 (kid) and 49,742
  (union). P5.1's tooling reused and its figures reproduced.
- **AC2** — §3B. Per-mode closures with barriers from the `sta CharSword` sites, transitions included
  in both, each labelled with what it is a closure of and over what interval.
- **AC3** — §3C. **Yes: one block on the union, 8 → 7.**
- **AC4** — §3D. `turndraw` 2, `engarde` 7, `resheathe` 15, `stepfall` 4 frames; **track read 119
  frames, measured on the port's driver** and cited to `build/tile_live.log`.
- **AC5** — §3D. **`startfall` answered specifically: zero frames, no animation, player did not ask.
  The sword is not a paging point.**
- **AC6** — §3E. Block counts per candidate under the straddling rule, stated as lower bounds.
- **AC7** — §3E. **Over by two. A/B/C still needed, and no option costed so far buys two blocks.**
- **AC8** — §3F. Nine sample cels confirmed; **~262 to convert**; tooling covers the pipeline but the
  phase-variant question is open. **Not started.**
- **AC9** — §4.3, seven non-proposals.
- **AC10** — §0. `git status --porcelain src/` → 0 lines at both ends.
- **AC11** — §0. Prod sha1 triple identical at both ends.
- **AC12** — **suites NOT run, and saying so.** Nothing was built — no source, link script, bake input
  or disk image changed, and `build.bat` was not invoked. The suites would have re-tested the exact
  artifacts P5.5 gated; the unchanged sha1 triple is the evidence.
- **AC13** — §6.

---

### 6 — Reactive deviations and route accounting

**Deviations:**

1. **★ I corrected two of my own prior figures, not the Orchestrator's.** The 49,924 in §1 came from
   P5.1's summary table, and **P5.6 and P5.7 — my reports — carried it into the budget.** P5.1's own
   tool output in the same report says 49,742. The dispatch was faithfully quoting my error.
2. **A seeding error found and corrected mid-task** (§3B). The first per-mode closure seeded from all
   93 kid sequences and reported "the split buys nothing"; that answer was produced by the seed, not
   by the graph. Recorded rather than silently fixed, and the tool carries the note.
3. **I extended the question from the kid to the union without being asked.** §2 asks for kid, guard
   and union at W∞ (AC1) but frames the per-mode work around the kid. **The union is what changed the
   answer**, so §3B and §3C are computed on it as well.

**ROUTE ACCOUNTING.** No route was proposed in conversation before this task. Within it, one
expectation was overturned rather than a plan changed: §1 predicted the closure would be barely above
depth-1, making the depth question moot and possibly retiring A/B/C. **It is barely above depth-1 for
the kid and 11,453 B above for the union, which is a block.** I report the overturn rather than the
prediction. **No proposal is made to close the resulting two-block gap** — §4.2 states plainly that I
did not find one.

**This report contains:** AC1-AC13, one new analysis tool, no engine change.
**It does not contain:** any build, any code, any adoption, and none of §4.3's seven non-proposals.

---

### 7 — Uncertainty flags

1. **★ The block counts in §3E are LOWER BOUNDS.** They divide bytes by 8,192. P5.7 measured that
   animated cels must be duplicated into each character block that draws them (7,074 B for a 36,142 B
   set across 5 blocks); the same duplication applies at 61,195 B across 8 and is **not** included.
   **The real overflow is ≥ 2 blocks and could be 3.**
2. **The union assumes one guard.** `LEVEL0` places guards per screen and I did not check whether two
   can be live at once. If they can, the union does not grow (they share a cel set) but the
   *per-frame* figure does, which is P5.6's window number rather than this one.
3. **`landengarde` resolves to a sequence with zero frames in its body**, so as a barrier it is inert.
   That is consistent with `:softland` being a *preserving* rather than *creating* transition for the
   kid, but it means the to-armed barrier set is effectively `engarde` + `turndraw`.
4. **The 119-frame load is one measurement of one track on one machine**, from P5.5's throttled gate.
   It includes `disk_read_init` and spin-up, so a steady-state second read would be faster — but not
   by the factor that would matter, and the `startfall` argument does not depend on the figure at all.
5. **§3F's phase-variant question is stated, not answered.** Whether the port needs up to four
   converted variants per character cel or whether the runtime 4-phase shifter covers it decides
   whether the character bake is 271 cels or four times that. **It is the largest unresolved number
   in the arc and it is bigger than the two-block gap.**
6. **The mode barriers are taken from `CTRL.S` only.** `AUTO.S:435/1872/1876`, `MISC.S:674` and
   `SUBS.S:1582` also write `CharSword`; `AUTO.S` is the demo's autoplayer and `SUBS.S:1582` is
   cutscene setup, so I judged them out of the gameplay graph — **judged, not verified.**

---

### 8 — Follow-up candidates

1. **★ Resolve the phase-variant question** (flag 5) before any character bake begins. It is worth
   more than the two-block gap.
2. **Measure the duplication at 8 blocks** (flag 1), so the overflow is exact rather than bounded.
3. **Find a two-block option**, since none of A/B/C reaches it. The tile page (1 block) and the
   scenery block are the only non-character claimants.
4. **Check whether two guards can be live** (flag 2).
5. **Correct P5.1's summary table** — it is an authored doc, so under §2D the body is the
   Orchestrator's to edit; this report supplies the delta (49,924 → 49,742).

---

### 9 — User interaction during task

None.

---

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-22-check-the-seed-does-not-already-contain-the-answer.md` — §3B: seeding the
per-mode closure from all 93 sequences put the fight moves in the unarmed set by construction, so
the closure reported its own seed back and said the split bought nothing. Pushed as `f6a497e`.

---

### 11 — Commit

Recorded in the push that carries this report to `origin/wip`. **`main` is untouched at `32b5fe2`.**
