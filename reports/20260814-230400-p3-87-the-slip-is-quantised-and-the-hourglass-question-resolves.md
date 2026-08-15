## Form B Report — P3.87 — the slip is attributed to a grid, not to a cost; and the hourglass disagreement resolves

**Class:** recon + one reverted build change. wip. Prod untouched; `src/` is byte-identical to `9d048f3`.

**★ The pace slip is ATTRIBUTED and the attribution changes what a fix has to be. It is not a
draw that gradually overruns — it is a step that can only fire on a 3-frame grid. That makes
every partial saving worth exactly nothing, which is why this dispatch ships no pace change:
the one I built crossed the boundary on three beats and FAILED a render-neutrality diff that
both existing suites had passed.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-14T22:11:26-04:00 (HEAD `9d048f3`, wip). Karateka untouched. `main` untouched.
`src/` restored to HEAD after the reverted attempt — verified by symbol: `sc_body` absent from
`build/obj/flames.map` in the final build. Working tree carries the pre-existing dirt from the
session start (`dist/mame-cfg/rgb/coco3.cfg`, `harness/smoke/walk_test.lua`, untracked PDFs)
— none of it mine, none of it staged.

---

### 1 — Summary

| | |
|---|---|
| **the mechanism** | the step fires only on a room-loop iteration boundary, and an iteration is a **whole number of video frames** |
| **the split** | peel **40,191 cy**; scenery **~20,000 cy**; a walking iteration is **19,299 cy** over its 3-frame budget |
| **the consequence** | a saving below 19,299 cy is **measurable and invisible** — 6/8/10 has nothing in between |
| **the fix attempt** | hourglass body cached per buffer: **10.00 → 8.00 f/play on the last three beats, then REVERTED** — not render-neutral |
| **★ coverage** | **both suites passed the broken change.** The hourglass is not in `verify_room_chars`'s expected picture at all |
| **hourglass timing** | **resolved** — instrument and eye measure different quantities, both right, and the pace fix repairs both |
| **25.3** | **pending Jay** — three items re-offered, the flash explicitly unaffirmed |

### 2 — Files modified

- `harness/tools/port_pace_split.lua` — NEW; slices the step stream into loop iterations
- `harness/tools/port_phase_cost.lua` — NEW; per-beat cost of the four phases of an iteration
- `harness/tools/port_exit_cost.lua` — NEW; CH_X, `ch_anymove` and beat frame boundaries
- `harness/tools/port_blit_work.lua` — NEW; blits and cel area per iteration, per beat
- `harness/tools/port_pace_ablate.lua` — NEW; run-time ablation + the VBL-spin cycle clock
- `harness/tools/port_scene_frames.lua` — NEW; displayed-framebuffer captures **by step index**
- `harness/tools/fb_region_diff.py` — NEW; diffs two capture sets and attributes by region
- `harness/smoke/run_pace_split.sh` — NEW; headless live-disk runner for the above

No `src/` change survives. Explicit-path staging only.

### 3 — Reasoning

**3A — ★★ THE HISTOGRAM WAS ALREADY TELLING ME IT WAS A GRID, AND I HAD READ IT AS A COST.**

P3.85d's own numbers carried the answer: `6 x263, 7 x1, 8 x61, 10 x66`. **One odd interval in 391
steps.** A draw that gradually overruns a budget lands on 7 and 9 as often as on 8 and 10; a
distribution that is *even* is a distribution quantised by something. That reading is P3.85d's
"SPREAD and lumpy => the draw does not fit" being wrong about its own data — the tool printed
both hypotheses and the shape had already chosen.

The grid is the room loop, and the raw event stream shows it with nothing inferred in between
(`port_pace_split.lua`, taps on `rl_now`, `flm_idx`, `cad_idx`):

```
f2097   top drw          f2103   top drw
f2098   stp              f2104   stp
f2100   top drw          f2106   top drw
```

Iterations start every **3 frames**; the step fires on every second one. Three facts make that
the whole mechanism, each measured rather than argued:

1. **`vm_nextframe` is reachable only from a drawing iteration** — the room calls `chars_frame`
   under `rl_draw` [cutscene_room.s].
2. **`room_present` ends every iteration on a VBL wait**, so an iteration is a whole number of
   frames whatever the work inside it costs.
3. **The loop never idles.** 787 iterations, 787 draws — `flm_due` is always already past, so
   the flame cadence table `2,2,3` is not being honoured either; the loop runs flat out.

`cad_tab`'s 6 is then *exactly two 3-frame iterations* and lands perfectly. A 4-frame iteration
pushes the boundary out and the step becomes 8; two of them, 10. **That is the entire 19%.**

**3B — ★ AND THE SLIP IS CONTENT, NOT LOAD.** Per beat it is not jitter at all:

```
scene beat  1 / 6 / 10   song holds, nothing moves      6.02  6.00  6.00
scene beat  4 / 8        Vwalk — Jay's complaint        9.14  8.00
scene beat 16 / 17 / 18  after the hourglass            10.00 10.00 10.00
```

Fifty-four consecutive steps at exactly 10.00 is not a load average, and **scene beat 16 is a
hold** — the same kind of beat as 1/6/10, costing double.

**3C — THE PHASE SPLIT, AND WHAT IT ELIMINATED.** Read-taps on the four phase entries
(`port_phase_cost.lua`, §10a's PC discriminator at every hit):

```
              total    pre   flicker   chars  present
hold           3.00   0.00     1.00     1.96    0.04
Vwalk          4.00   0.00     1.00     3.00    0.00
after Vexit    5.00   0.00     1.00     3.96    0.04
```

**`flicker` is a flat 1.00 at every beat in the scene** — so the hourglass, the sand and the
torches are not where the time goes, and `pre`/`present` are ~0. It is all `chars_frame`. And
`blit_cel` entries per iteration go **4.00 → 6.00** exactly where the glass appears, which is
`scenery_frame` — called from `chars_frame`, not from `flicker`, which is why the phase table
and the blit count point at the same thing from two directions.

**★ AND THE CLIPPING EXPLANATION IS REFUTED BY ARITHMETIC, not by a guess.** CharX 132..166
across scene beat 16 maps through `co_setup`'s `px = 2*(x-58)+20, col = px/4` to columns 43..59
of 80. He is **fully on screen** for a beat that already costs the full 5 frames flat. He also
exits **right**, not left — CH_X runs 135 → 242.

**3D — ★★★ THE NUMBER THAT CHANGED THE PLAN, AND I NEARLY OPTIMISED WITHOUT IT.** An
iteration's *length* says only which side of a boundary the work fell on, never how far over —
so the phase table cannot cost a component, and scene beat 14 reading 3.06 against beat 10's
3.00 is not "the hourglass costs 0.06 frames", it is the hourglass fitting inside a 3-frame
iteration that had room. The idioms file's VBL-spin clock (`work = frames*29,859 − spins*7`)
gives the real figure:

```
song hold        65,751 cy      -27%
Vwalk           108,876 cy      +22%     budget = 3 frames = 89,577
after Vexit    129,319 cy      +44%
```

and run-time ablation sizes the two components:

```
                    mean f/play    scene beats 16/17/18
shipping               6.99             10.00
scenery ablated        6.73              8.00
peel ablated           6.36              6.00
```

The peel is `108,876 − 68,685 =` **40,191 cy** on a walking iteration; its inner loop is
`ldd ,u++ / std ,y++ / dec / bne` = 25 cy per 2 bytes = **12.5 cy/byte**, where ~8 is reachable
by an unroll and ~6 by a per-width straight-line copy selected once per cel.

**★★ AND THAT IS EXACTLY THE OPTIMISATION THAT WOULD HAVE BEEN WORTH NOTHING.** The gap is
19,299 cy. An unroll recovers ~9,400. 99,476 and 108,876 are on the same side of 89,577 and
both round to four frames, so the pace would not have moved by one frame — a true profile
number, a real saving, and zero user-visible effect. **On a quantised path the measurement that
matters is the distance to the boundary, not the size of the waste.** That is this task's
candidate.

**3E — THE ONE CHANGE THAT DID CROSS A BOUNDARY, AND WHY IT IS NOT IN THE TREE.**

The glass body is a 312-byte segment stream for a static opaque object, redrawn ~20 times a
second. Ablating `scenery_frame` outright took the last three beats from 10.00 to 8.00 — a
whole boundary. So I cached it per buffer (`sc_body`, one byte per buffer, exactly as `sc_prev`
names whether that buffer has sand down), with a warm-up after a state change because a
character's pre-glass save would otherwise punch a hole through it.

**Both suites passed it. Room 8/8 with flame pixels 78 bytes byte-identical; walk 19/19 with
0 bytes wrong at all 28 captures. The change was broken.**

`verify_room_chars` builds its expected framebuffer as "the room asset with the two baked cels
composited on", and its own docstring says what is excluded: *"The torch columns are excluded
because the flames animate; nothing else is."* **The hourglass is not in that picture**, and the
walk captures are all pre-glass. This is the stale-checker failure with the roles swapped: the
checker is current, the **coverage** is not, and a green suite that does not cover the change
reads exactly like a green suite that does.

So I built the gate the change actually needed — CLAUDE.md §2F.1(6)'s render-neutral test:
dump the displayed framebuffer at matched **step indices** (not frame numbers — the change
alters the pace, so at frame 4000 the two builds are at different points in the scene and a
correct change would report as a total mismatch), and attribute the diff by region.

```
step 0180..0300   IDENTICAL
step 0340         chars/room 138   glass 9   sand 6
step 0380         chars/room 576   glass 11  sand 7
```

**Residue, growing, appearing exactly when the glass appears, at the vizier's exit columns
44..57.** Reverted.

**★ AND THE CONTROL IS WHAT MAKES THAT A FINDING RATHER THAN A SUSPICION.** Seven bytes of
`rmb` in the same place, no logic change, rebuilt and re-diffed: **IDENTICAL at all 21
captures.** So it is not the bundle growing, and it also proves the new diff can return clean.
The `scenery_frame` redraw is doing something besides drawing — **the every-frame redraw is
load-bearing and the mechanism is not yet established.** Leading hypothesis, unconfirmed: the
scenery goes down before the character SAVE, so any damage a character's erase does is
re-captured by that same frame's save and only the next frame's redraw clears it — remove the
redraw and the damage accumulates, which fits the growth (138 → 305 → 398 → 536 → 576). It does
**not** yet explain why the residue is at the character's own columns rather than the glass's.

**3F — ★★ THE HOURGLASS: BOTH OBSERVATIONS ARE CORRECT, ABOUT DIFFERENT QUANTITIES.**

Jay saw it appear too early; the instrument said late. Suspecting the instrument first, I
re-derived its anchor independently — the room is up at f2089/f2090 from the step stream and
f2093 from the room suite, agreeing with P3.85d's correction — so the instrument is sound. The
hourglass beat begins at **f4186 = room+2096 frames = 34.9 s**.

The reconciliation is in the *decomposition*, and it closes to the frame:

```
                             actual   at cad_tab's 6      slip
scene 1  s_Princess  hold      654          654            0
scene 6  s_Vizier    hold      306          306            0
scene 7              hold       24           24            0
scene 10 s_Buildup   hold      507      336 + 171 read     0
scene 4  Vwalk                  64           42          +22
scene 8  Vwalk                 232          174          +58
scene 2/5/9/12/0  (motion)     ---          ---          +57
                                                        ----
room -> hourglass             2096         1959         +137
```

**Every hold is exact to the frame. Every frame of the slip is on a beat where a character is
moving.** The vizier's two walks alone run 296 frames against 216 — **37% longer than they
should** — while the waits between them take precisely as long as they should.

So: the instrument measures the hourglass against the **clock** and finds it 2.3 s late on the
port's own table. Jay measures it against the **action beside it**, and there the ratio really
is wrong — the walking swells by 37% and the waiting does not, so the glass arrives before the
gait it is being judged against has earned it. Neither observation needs correcting.

**★ And the consequence is the useful part: fixing the pace fixes both, so the hourglass's
timing must NOT be adjusted.** Moving it later to satisfy the eye would have baked the pace
defect into the scene's content, where no future pace fix could reach it. Jay's ordering — "fix
the pace first and I'll look again" — was right, and this is why.

### 4 — Verification (AC-by-AC)

- **AC1 the slip attributed by a split, and fixed; the mean returns toward 6** — **ATTRIBUTED,
  NOT FIXED, and I am not reporting the attribution as though it were the fix.** The mechanism
  is the 3-frame iteration grid (§3A), the components are sized by ablation (§3D), and the gap
  is 19,299 cy. The one change that crossed a boundary failed its render-neutrality gate and was
  reverted (§3E). **The mean is unchanged at 6.99.**
- **AC2 `cad_tab` NOT lowered** — **MET.** Untouched, and now with a positive reason rather than
  a prohibition: the table is not what sets the pace, the iteration grid is, and 6 is exactly two
  iterations when they cost 3 frames.
- **AC3 the hourglass disagreement resolved** — **MET.** Both quantities named, the difference
  explained, and the arithmetic closes to the frame (§3F).
- **AC4 all three re-offered, the flash explicitly unaffirmed** — **MET** (§5, 25.3).
- **AC5 suites green both sizes; room 78 bytes byte-identical; walk 19/19 stable; build verified
  by symbol** — **MET.**
- **AC6 build left in the tree, condition stated** — **MET.** The tree is the shipping build,
  `src/` byte-identical to `9d048f3`, rebuilt and re-verified after the revert.
- **AC7 route accounting; sync bridge; Karateka; `main`** — **MET** (§6).

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output.** `=== BUILD COMPLETE ===`, with `[palette] the flash's restore
matches gfx_pal4 ($00 $26 $19 $3F)`, `[hal-sync] OK`, `[harness-offsets] all checked offsets
agree`, `[cel-streams] 82 cels walk exactly to their own end`. Final build has **no** `sc_body`
symbol in `build/obj/flames.map` — the revert is verified by symbol from a freshly baked image,
not by a diff.

Room, default RAM and `MAME_RAM=128K`, both: `checks=8 passed=8 failed=0`;
`PASS flame pixels are exactly cel 3/8 over the room: 78 bytes byte-identical`.

Walk, default RAM and 128K, both: `19 beats, 1 staged reads`, `beats_visited PASS (19 of 19)`,
`engine_bank_guard PASS (ch_bankerr = 0)`, `page_sig_matched_every_frame PASS (1194 checked)`,
`0 bytes WRONG` at all 28 captures, `STABLE`.

**★ And the standing caveat those two now carry:** neither of them looks at the hourglass. They
passed a change that put growing residue on screen. `fb_region_diff.py` is the instrument that
caught it and it is in the tree.

**25.2 bundled-artifact grep:** N/A — ROM build, no sibling-import artifact.

**25.3 operator-runtime-smoke: PENDING JAY. NOT self-certified, and nothing here upgrades it.**
Three items are open and two of them Jay has already reported:

1. **The flash** — fixed at P3.85c and gated by `palette_check.py`, but **never affirmed by
   Jay**. Not re-reported is not passed; it is recorded as **unaffirmed**.
2. **The pace** — **unchanged this dispatch.** Attributed, not fixed. It will look exactly as it
   did when he reported it.
3. **The hourglass timing** — **deliberately unchanged**, for the reason in §3F.

Launch path for any gate: `live-disk` via `harness/smoke/run_room_live.sh`, RGB. Motion-bearing,
so it needs a live run, not a still.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** I proposed, in this dispatch's own working, three things and shipped none
of them, which is the whole of what changed relative to the plan:

- **Proposed:** cache the hourglass body per buffer. **Built, measured (10.00 → 8.00 on three
  beats), and REVERTED** when the render-neutrality diff failed. Not in the tree.
- **Proposed:** unroll / rewrite the peel's inner copy loop (12.5 → ~6-8 cy/byte). **NOT
  built**, and the reason is a measurement rather than a schedule: it does not reach the
  boundary and would have changed the observed pace by nothing (§3D).
- **Considered and NOT done:** drift-free `vm_due` (`vm_due + count` instead of `vm_now +
  count`), which returns the mean to 6 by construction with no pixel change. Not shipped
  because it converts a uniform 8 into an alternating 8,4,8,4 — a limp instead of a lag — and
  because after the staged read it would sprint to catch up unless clamped. **That is a
  question about how the walk should LOOK, so it is Jay's, not mine** (§8).

Deviation from the dispatch spec: §4's AC1 asks for a fix and there is none. Reported as absent
rather than approximated. `cad_tab` untouched; nothing tuned to mask anything.

`hal-sync` OK. Karateka untouched. `main` untouched.

### 7 — Uncertainty flags

- **★★ `scenery_frame`'s every-frame redraw is load-bearing and I do not know why.** The
  7-byte control eliminates size; the residue is real, growing, and at the character's exit
  columns rather than the glass's. My leading hypothesis (§3E) fits the growth but not the
  location. **This is the next thing to attribute, and it may be the same defect as the carried
  "turn-to-exit disappearance" — the residue sits exactly where that was reported.**
- **The 19,299 cy gap is a bound on a fix, not a target that is known to be reachable.** The
  peel is 40,191 cy and ~half of it looks recoverable on paper; that estimate is arithmetic
  from an instruction count, not a measurement, and this arc has three instances of a figure
  quoted without its scope.
- **The oracle's room+2044 is quoted from P3.85b/c**, measured by `oracle_glass_beats.lua` off
  `psandcount`/`SPEED` write taps. **I did not re-measure it**, and §3F's conclusion does not
  rest on it — the decomposition is entirely within the port.
- **The beat index differs by one between my own tools.** `port_pace_split` reads the `vm_beat`
  pointer and reports true scene beats; `port_pace_ablate`/`phase_cost`/`exit_cost`/`blit_work`
  count `vm_beat` writes and are **one high** (there is an extra write at init). Everything in
  this report is normalised to scene beats; the raw logs in `build/tmp/` are not.
- The flame cadence table `2,2,3` is not being honoured at all — the loop never idles, so the
  torches run at ~17 Hz against the oracle's 26.2. P3.72k's decoupling bought less than it
  looks like it bought.
- Carried: 0.20 s per-call driver overhead; the `$2310..$2329` read-tap blindness; the scene is
  one page from a single load; §2's grouping push; the HAL's two disagreeing palette sources;
  `s_StTimer` untraced; the strobe's duty cycle derived rather than traced.

### 8 — Follow-up candidates

1. **Attribute what `scenery_frame`'s redraw is repairing** — it is a live defect being masked,
   and it is probably the turn-to-exit disappearance.
2. **Jay's call on the walk: uniform-but-slow, or on-average-right-with-a-limp?** Drift-free
   `vm_due` is ~6 bytes and no pixel change; it buys the correct mean and costs gait evenness.
   The alternative is to find 19,299 cy.
3. **Give `verify_room_chars` the hourglass**, or make `fb_region_diff` a standing gate. A suite
   that cannot see a third of the late scene is going to pass the next change too.
4. The peel's copy loop, **if and only if** it is part of a package that reaches the boundary.

### 9 — User interaction during task

None. No questions were put to Jay during this task; the three items in §5 are for the gate.

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-14-a-cost-quantised-to-a-boundary-pays-nothing-until-it-crosses.md`
  — committed and pushed. A cost quantised to a boundary pays nothing until it crosses, so the
  gap decides whether an optimisation is worth doing; and the corollary that lets you decline
  a real profile number.

### 11 — Commit

`d143bf6` (the instruments), `f8e2f4e` (this report), `a4d1c1e` (§12). Pushed to origin/wip.

### 12 — ★ JAY'S RULING, AFTER THE REPORT WAS FILED

**"leave the pace as is."**

So the pace question is **CLOSED BY DECISION, not by a fix**, and the distinction matters for
whoever picks this up next. Nothing was reverted to comply — this dispatch shipped no pace
change, so the tree already was the ruling. What the ruling settles:

- **The walk stays at 8.00 f/play against a table asking 6**, and scene beats 16/17/18 stay at
  10.00. The 19% is measured, attributed and **accepted**.
- **The drift-free `vm_due` question is answered NO** — the limp is not wanted. Do not re-raise
  it as a fix; it was offered as a trade and declined.
- **The peel's 12.5 cy/byte copy loop is not to be rewritten for the pace.** It may still be
  worth doing for a different reason, but it no longer has this one, and on its own it does not
  reach the boundary anyway (§3D).
- **`cad_tab` stays at 6.** It was never the problem and it is not now a knob.

**★ WHAT THE RULING DOES NOT COVER, stated so it is not silently absorbed into it.** Jay
reported the pace having watched the vizier's walk. The scene's worst beats are the last three
— **10.00 f/play, 67% slow, over 54 consecutive steps** — and those come after the hourglass,
in the part of the scene he has gated once and never re-reported. If "as is" was meant to cover
the whole scene it covers them too; if he was ruling on what he saw, they are still open. Not
assumed either way, and not re-litigated — flagged.

**Still open and untouched by this ruling:** the flash is **unaffirmed** (§5); `scenery_frame`'s
every-frame redraw is load-bearing for a reason not yet established, and that is a live defect
being masked rather than a performance question (§7).
