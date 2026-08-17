## Form B Report — P3.88 (RECON) — the oracle peels; P3.44 was wrong; and the suites could not see the hourglass or the late scene

**Class:** recon + checker fix. wip. Prod untouched; `src/` byte-identical to `50b337f`.

**★★★ §1 IS SETTLED AND IT GOES AGAINST THE RECENT READING. The oracle peels — per-sprite,
bounded, double-buffered, with its own dedicated buffers. P3.44's *"the oracle does not peel
at all"* is retracted in place. The port's peel is FAITHFUL, not a CoCo3-side invention, and
Jay's recollection was right.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-15T14:20:28-04:00 (HEAD `50b337f`, wip). Karateka untouched. `main` untouched.
Oracle source read-only throughout. `src/` restored after a seeded test — verified by diff and
rebuild. Working tree carries pre-existing dirt not mine: `dist/mame-cfg/rgb/coco3.cfg` (MAME
rewrites it on exit); `harness/smoke/walk_test.lua` showed modified with an **empty diff** at
session start — a line-ending artifact, not a change.

---

### 1 — Summary

| | |
|---|---|
| **§1** | **PA.2 was right, P3.44 was wrong.** `DRAWALL` peels; `FAST` does not draw — it *assembles* |
| | the two are **phases of one frame**, not strategies for two object classes |
| **consequence** | **the port's peel is faithful.** Do not remove it on fidelity grounds |
| **§2 peel** | 40,191 cy — **crosses only as a ≥19,299 cy package**; an unroll alone (~9,400) does not |
| **§2 scenery** | **crosses** (10.00 → 8.00 measured) — but **the defect question is NOT settled**, so removal is not costed |
| **§2 hourglass** | body **312/313 B** vs sand **37/42/42 B** — the body is **89%** and changes state **twice in the scene** |
| **★ §3** | **the exit's first boundary costs only ~9,900 cy** — half the entry's, and the body alone is twice what is needed |
| **§4** | **three** coverage holes closed, not one; **seeded and confirmed to fire** |
| **★ correction** | **the flash IS affirmed** — Jay, live-disk gate, 2026-08-15. The dispatch's open list is stale |

### 2 — Files modified

- `reports/20260809-033108-p3-44-audit-and-peel.md` — the losing claim **corrected in place**
- `harness/tools/verify_room_chars.py` — composites the glass body + sand; cel table widened
- `harness/smoke/walk_test.lua` — second capture window on the hourglass; 11-field position rows
- `harness/smoke/run_walk_test.sh` — exports `vm_scenery` / `sc_flow` / `P_SHOTS_GLASS`
- `harness/tools/verify_room_flame_pixels.py`, `verify_room_flicker.py` — accept both row widths
- `harness/tools/harness_offsets_check.py` — understands the two-width form; `_cmp` helper

No `src/` change. Explicit-path staging only.

### 3 — Reasoning

**3A — ★★★ §1 SETTLED FROM `GRAFIX.S`, AND THE ENCLOSING ROUTINE IS WHAT SETTLES IT.**

`DRAWALL` [GRAFIX.S:481] — *"This is the only routine that calls HIRES routines"* — runs, in
order: `DOGEN` → **`SNGPEEL`** *("'Peel off' characters (using the peel list we set up 2 frames
ago)")* → `ZEROPEEL` → `DRAWWIPE` → `DRAWBACK` → **`DRAWMID`** *("Draw middle list (floorpieces
& characters)... & save underlayers to now-clear peel list")* → `DRAWFORE` → `DRAWMSG`.

The storage is declared and bounded: `maxpeel = 46` [EQ.S:297]; `peelX`/`peelY`/`peelIMGL`/
`peelIMGH` each `ds maxpeel*2` [EQ.S:322-325]; `peelbuf1 = $d000`, `peelbuf2 = $d800`
[EQ.S:12-13]. `SNGPEEL` indexes `0` or `maxpeel` off `PAGE` — **one list per page.** `ADDPEEL`
[GRAFIX.S:436] writes the coordinates and the saved-image address per entry.

So *"there is no per-sprite save/restore anywhere in it"* is false in the strongest available
sense: the mechanism has a name, a bound, two page-indexed lists and dedicated buffers.

**★ WHERE THE READING WENT WRONG IS WORTH MORE THAN THE FACT IT GOT WRONG.** `FAST` and the
redraw buffers are real — but **`FAST` is not in `GRAFIX.S`**; it is FRAMEADV.S:189. Its own
header (*"Fast screen redraw... redraws only those blocks specified by redraw buffers"*)
describes the RESULT and reads exactly like a renderer. Its callers name the job:
`jsr fast ;get char/objs into mid table` [SUBS.S:996], `jsr fast ;Assemble image lists
(including objects` [TOPCTRL.S:977], and then `jsr drawall ;...then draw the rest`
[SUBS.S:1006]. Following the block path to the bottom removes the last doubt:
`RedBlockFast` → `wipesq` → **`jmp addwipe`**. It ENQUEUES.

**`FAST` and `DRAWALL` are the ASSEMBLE and DRAW phases of one frame.** P3.44 read the
assemble phase as the renderer and concluded the draw phase's peel did not exist.

★ **The dispatch's offered reconciliation — "both true if POP has both mechanisms, each report
seeing one" — is also wrong**, and I am reporting that rather than taking the exit it offered.
They are not parallel mechanisms serving different object classes. They are sequential phases,
and only one of them draws.

**Consequence.** The port's peel mirrors the oracle structurally: restore-before-draw, save-
during-draw, one list per page. The oracle's own *"the peel list we set up 2 frames ago"* is
the same double-buffer round trip the port's per-buffer `ch_last` has. **The peel may still be
too expensive — P3.44 §3D's per-row-overhead measurements stand and are untouched by this — but
it is the right model and must not be removed on fidelity grounds.**

**3B — §2, COSTED AS BOUNDARY CROSSINGS.** The grid, from P3.87: an iteration is a whole number
of video frames, 3 frames = **89,577 cy**, and a step fires only on an iteration boundary.

| mechanism | cost | crosses a boundary? |
|---|---|---|
| **the peel** | 40,191 cy | **only as a ≥19,299 cy package.** Ablated entirely: walk beats 8.00 → 6.00, mean 6.99 → 6.36. An unroll of the 12.5 cy/byte copy loop recovers ~9,400 — **measurable and invisible.** A per-width straight-line copy lands ~19,000, i.e. *at* the edge, not clear of it. |
| **`scenery_frame`** | ~20,000 cy | **YES — 10.00 → 8.00 on the last three beats, measured by ablation.** But see 3C: removal is **not costed**, because the defect question is not settled. |
| **the hourglass body** | 312/313 B of 349/355 = **89%** | **YES** — the body cache achieved exactly the 10.00 → 8.00 crossing before failing render-neutrality. |

**★ AND THE DISPATCH'S BYTE FIGURES DO NOT RECONCILE WITH THE BUILD — but the argument survives.**
It quotes `glass0` 415 B / `glass1` 416 B against sand 49/57/57. Measured two independent ways
(map-symbol deltas, and counting the emitted `fcb`/`fdb` operands in `build/glass_seg/*.s`):
**312 / 313** and **37 / 42 / 42**. A constant ~1.33 apart, so the dispatch's figures are almost
certainly the same objects at a different scope — source cel rather than built segment stream.
**The ratio is identical to the decimal**: 312/349 = 89.4%, 415/464 = 89.4%. Jay's framing —
*only the sand is animation; the glass is scenery* — is unaffected and is the right
classification.

**3C — ★★ AC3: WHY THE EVERY-FRAME REDRAW IS LOAD-BEARING — PARTLY ESTABLISHED, AND I AM NOT
COSTING ITS REMOVAL ON A PARTIAL ANSWER.**

What §1 adds: in the port, `scenery_frame` runs **before** `vm_frameadv`, so a character's SAVE
always captures glass-over-room and its ERASE always restores the glass. That holds only once
the glass is in that buffer. The first pass after it appears has a **pre-glass save**; the erase
punches a hole, and — because the save runs *after* the erase — that same pass re-captures the
punched state. The redraw is what clears it next frame. Remove it and the damage is baked in and
accumulates, which fits P3.87's growth exactly (138 → 305 → 398 → 536 → 576 bytes).

**★ What it still does not explain: the residue sits at the vizier's exit columns 44..57, not at
the glass's 38..44.** Until that is accounted for, the mechanism is a fit, not an attribution.
**So per AC3's own ordering, removal is not costed.** The 10.00 → 8.00 crossing is a measured
fact about the *mechanism*; it is not yet a licence to ship one.

**3D — ★ §3, AND THE EXIT'S BOUNDARY IS MUCH CHEAPER THAN THE ENTRY'S.** This is the most
actionable number in the report and it is new:

```
exit beats 16/17/18   129,319 .. 131,957 cy
  -> 4 frames (119,436)   needs   ~9,900 cy      <- the entry needs 19,299
  -> 3 frames  (89,577)   needs  ~39,700 cy
```

**The exit's first boundary costs about half what the entry's does, and the hourglass body alone
is twice what is needed to clear it.** That is why the body cache moved those beats 10.00 → 8.00
and why nothing similar was available for the entry. Jay's scope correction is therefore not a
formality: **the entry's closures were all argued against a 19,299 cy gap and none of them
transfers to a 9,900 cy one.**

**3E — §4: THREE HOLES, NOT ONE, AND THE SECOND WAS THE ONE THAT MATTERED.**

1. **The compositor omitted the glass** — the dispatch's premise, and true.
2. **★ The captures never reached it.** The 28 shots arm on the first cel change and end at
   f3059; the glass appears at f4186. **No expected picture could have caught it.** Fixing only
   (1) would have shipped an inert change that still passed everything.
3. **★ The cel table stopped at Palert.** Widening the window immediately produced *"cel 74 is
   on screen but has no baked source"* — **Vraise, Vexit, Pback and his exit walk have been
   unchecked for their entire existence**, while the bake has been writing `v57..v85` and
   `p12..p17` all along. It **refused rather than skipping**, which is the only reason this was
   findable; that behaviour is preserved deliberately.

**★ SEEDED, because a new check that has never failed is not evidence.** `GLASS_COL` 38 → 39,
rebuilt: **126 bytes wrong at every one of the eight glass captures, 0 at all 28 before them.**
Reverted; `src/` byte-identical.

**And the build's own guard caught me breaking two other readers** — `verify_room_flame_pixels`
and `verify_room_flicker` both required exactly 9 fields and would have silently skipped every
row. **The guard then needed teaching too:** rewriting a reader as `len(f) not in (9, 11)` made
it invisible to the `len(f) != N` regex, so it would have gone on printing `ok` for the two files
it could still see while the one actually changed went unchecked — the same defect it exists to
catch, one level up. Both widened; the guard now reports each reader against **both** writers.

**3F — ★★ FINDINGS FROM JAY'S GATE THAT POSTDATE THE DISPATCH.** Reported, not acted on:

- **The flash is AFFIRMED** — *"so the flash looks fin[e]"*, live-disk, RGB, 2026-08-15. **The
  dispatch's carried-open list saying it is unaffirmed is stale.** Recorded in §5.
- **★ Jay: *"the hourglass still appears before the flash to my eye."*** In `vm_beat_tick`, the
  flash and sand blocks sit **below** `bne vb_done`, which is taken on every play except the one
  where `vm_bcnt` reaches zero. **So the flash fires only on the LAST play of the beat** — the
  glass appears on play 1, the flash on play 5. Both blocks carry comments reading *"once per
  PLAY"*; the branch above them prevents it. The same branch gates `sc_flow`, so **the sand
  advances once per beat, not once per play.** Source-derived — needs a trace before it is called
  confirmed, per §2's hierarchy. It also makes the "animation" half of the hourglass smaller than
  Jay's framing assumes.
- **★ Jay: all of the vizier but his feet vanishes for a frame at the turn.** Cels are stored
  bottom-up, so the feet are the **first** rows blitted — the shape of a blit that stopped early,
  i.e. a wrong row count for one frame. The turn is also where `cel_plan` switches block `$0E` →
  `$0F`. A wrong header read at a page boundary is the P3.78 failure exactly.
- **★ Jay: the exit walk "looks like a limp".** Measured: entry `8 × 29` (uniform), exit beat 15
  `6 × 9, 8 × 2, 10 × 6` (mixed). His turn cels vary 2–8 bytes wide, so the iteration cost
  straddles a frame boundary and lands differently step to step. **This independently confirms
  P3.87's prediction that drift-free `vm_due` would read as a limp** — he identified a mixed-
  interval stretch as one without knowing which beats were mixed.

### 4 — Verification (AC-by-AC)

- **AC1 §1 settled; losing claim corrected in place** — **MET.** PA.2 right, P3.44 wrong;
  retraction block added to `20260809-033108-p3-44-audit-and-peel.md` (`d69b391`), original text
  preserved because it was quoted onward.
- **AC2 three mechanisms costed as crossings** — **MET** (3B). Two cross; the peel crosses only
  as a package, and the unroll is named as measurable-and-invisible.
- **AC3 `scenery_frame` explained before removal costed** — **PARTIALLY MET, and the shortfall is
  reported rather than papered over** (3C). Mechanism fits; the residue's location is unexplained;
  removal therefore **not** costed.
- **AC4 hourglass split into scenery/animation, costed; 10.00 → 8.00 reconciled** — **MET** (3B).
  The mechanism reached the boundary; the implementation failed render-neutrality for the reason
  in 3C.
- **AC5 hourglass added to the expected picture** — **MET, and exceeded of necessity**: the
  compositor alone would have been inert (3E).
- **AC6 nothing built beyond the checker fix** — **MET.** No `src/` change. The seeded
  `GLASS_COL` edit was a test of the checker and is reverted.
- **AC7 route accounting; suites; sync; Karateka; `main`** — **MET** (§6).

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output.** `=== BUILD COMPLETE ===` with `[harness-offsets] all checked offsets
agree with the build`, and the widened guard reporting all three readers against both writers:
`verify_room_chars.py accepts [9, 11] <- walk_test.lua writes 11` (and the same for
`verify_room_flame_pixels.py`, `verify_room_flicker.py`, against both writers).

Room, default and `MAME_RAM=128K`: `checks=8 passed=8 failed=0`, `PASS flame pixels are exactly
cel 3/8 over the room: 78 bytes byte-identical`.

Walk, default and 128K: **36 captures** (28 + 8 on the hourglass), `0 bytes WRONG` at every one,
including `(glass0 top 127 col 38, flow0 top 141 col 40, cel76 ..., cel17 ...)`;
`beats_visited PASS (19 of 19)`; `engine_bank_guard PASS`; `stability: all captures agree (0)`;
`STABLE` across two runs.

**25.2:** N/A — ROM build.

**25.3: ★ THE FLASH IS PASSED — Jay, live-disk, RGB, 2026-08-15.** His words: *"so the flash
looks fin[e]"*. This is the first affirmation it has had and it closes an item open since P3.85c.
**The rest of the gate is not passed**: he reported three defects in the same breath (3F), none
of which is fixed. The exit pace is **open**, per his scope correction.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** I proposed nothing this dispatch that is not in the tree, and one thing in
the tree exceeds what was asked:

- **AC5 as written** was "add the hourglass to the expected picture". I did that **and** widened
  the capture window **and** widened the cel table, because the first alone is inert (3E). Stated
  because it is scope I added, not scope I was given.
- **Declined an exit the dispatch offered:** its suggested reconciliation for §1 ("both right
  about different objects") is wrong, and I report that instead of taking it (3A).
- **AC3 not fully met** and reported as such rather than approximated (3C).
- The seeded `GLASS_COL` change was a **test**, reverted, `src/` byte-identical.

Not present: any pace fix; the `vb_tick` flash/sand branch fix; the turn disappearance; the peel
rewrite; §2's grouping push.

`hal-sync` OK. Karateka untouched. `main` untouched. Oracle source read-only.

### 7 — Uncertainty flags

- **★ `scenery_frame`'s residue location is unexplained** (3C) — the mechanism fits the growth
  but not the columns. This gates any removal.
- **★ The `vb_tick` flash/sand finding is source-derived, not traced.** Under §2's hierarchy the
  trace wins on fact; it has not been run.
- **The dispatch's 415/416 B figures do not reconcile with the build's 312/313** (3B). Ratio
  identical, so the argument holds, but the absolute numbers should not be quoted onward until
  their scope is identified.
- **The 8 glass captures cover f4196..f4266 only** — the hourglass beat's start. They do **not**
  reach the exit beats where P3.87's residue actually appeared, so the new coverage would probably
  **not** have caught that specific change. It catches a wrong glass; it does not yet cover the
  whole of the object's life.
- **`verify_room_chars`'s SRC is keyed by cel number alone**, which assumes the two characters
  never share one. `v18_src.s` exists and key 18 resolves to her slump; dormant, not wrong.
  Deliberately not fixed here.
- Carried: the turn-to-exit disappearance; 0.20 s per-call driver overhead; `$2310..$2329`
  read-tap blindness; the scene is one page from a single load; the strobe's duty cycle derived
  rather than traced.

### 8 — Follow-up candidates

1. **Trace the `vb_tick` branch** — if it holds, the flash is one strobe not five and the sand
   is nearly static, and both are cheap fixes with a visible result Jay has already reported.
2. **The turn disappearance** — a per-frame trace of `ch_h`/`ch_w` and the page signature across
   the `$0E → $0F` boundary. "But his feet" narrows it a long way.
3. **Attribute `scenery_frame`'s residue columns**, which unblocks the exit's ~9,900 cy crossing.
4. **Extend the glass capture window to the exit beats**, so the coverage covers the object's life
   and not just its arrival.

### 9 — User interaction during task

None during the task. Jay's gate observations (3F) arrived before this dispatch and are reported
here because the dispatch predates them.

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-15-the-later-reading-wins-by-recency-not-evidence.md`

### 11 — Commit

`d69b391` (the P3.44 correction), `1d8c821` (the checker fix), and this report. Pushed to
origin/wip.
