## Form B Report — P3.84 — the cutscene is gated end to end; where the port stands

**Class:** build (closing report for the swap arc). wip. Prod untouched.
**★ THE COMPLETE SCENE IS GATED.** Both suites green on both memory sizes, `src/` clean.
This is the milestone report: what is verified, what it cost, and what is left.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-13T20:03:57-04:00. Now at `a045661`, pushed.
POP `main` untouched at `635f986`. **Karateka untouched** — `wip` `ac2b768`, `main` `5eb92b1`.
`hal_sync_check` OK (11 files). Build green; `src/` clean.

```
room   8/8 in-emulator, room intact, flames flicker, 78 bytes byte-identical  128K + 512K
walk   guard clean, page sigs clean (1,147 frames), staged reads clean,
       beats_visited 18 of 18, stability all captures agree (0), STABLE, PASS 128K + 512K
intro  17/17 PASS
gates  build.bat runs hal_sync, verify_sequences, bundle_offsets, harness_offsets
```

---

### 1 — Summary

**25.3 GATE — `live-disk`, RGB, 512 KB, 78 s on the real `LOADM`+`EXEC` path.
Jay, verbatim: "looks fine."**

Under gate for the first time: **`Vraise` → `Pback` → `Vexit` → `Pslump`**, the right-edge
clip, and the two staged reads as they land in the scene. Motion-bearing throughout and
observed on a running machine, per CLAUDE.md §4. **Not self-certified, and not inflated:
"looks fine" is a pass.**

**The freeze is ACCEPTED, not liked** — Jay: *"imnot super happy with the time but it is
what it is."* **~2.7–2.9 s per staged read, ~5.6 s total.** This supersedes the 1.7 s
accepted at P3.75 §4A, which was costed when a page was thought to be one track.

### 2 — What the arc built, and what it cost

| | |
|---|---|
| cel image | split into a **pinned page + 5 rotating pages over 3 GIME blocks** |
| integrity | **a signature per page**, checked once per frame against the beat's own; refuse-to-draw |
| schedule | per-beat block mapping, in the **same PLAN that drives the beats** |
| loads | **3** (startup + 2 staged, hidden in the two song holds) |
| beats | `s_Buildup`, `Vraise`, `Pback`, `Vexit`, `Pslump` — all playing |
| freeze | **~5.6 s**, accepted |

**Faults found and fixed across the arc — thirteen, of which nine were mine:**

- a page read overrunning into the **GIME registers** (design error)
- `fcb 7  ,$0D` emitting one byte, silently, in **two** generated tables
- `:loop` mis-scoped in the tracer — wrong about `Pback` **and** `Vraise`
- the beat switch one step early (the guard structurally cannot see this)
- an uninitialised byte in the constant page
- a half-migrated `ch_col` — **the black rectangles**
- the load running with the picture up — a regression of the bug P3.72f fixed
- `leax a,x` signed, so `bc_keep = $FF` meant −1 and the torches stopped drawing
- **a `bsr` executed while S pointed into the framebuffer** — the two flame bytes
- **a trimmed blast taking the wrong source bytes** — the last clip fault
- three stale checkers (`room_test.lua`, `verify_room_flame_pixels.py`, the beat window)

**★ Four of those were found by Jay watching it run, not by any check.**

### 3 — Reasoning

**3A — The measurement that reframed the arc.** Jay: *"There are now 3 disk loads for this
one scene. That seems excessive."* The oracle holds **7,891 B** of cels for this scene on
128 KB with one load; the port holds **38,424 B — 4.87×**. The pixel-depth floor is 1.75×
and not a choice; **2.36× is ours, and it is punctuation**: 64.9% of the cel image is
per-segment and per-row headers, 23.1% is pixels. **6,330 of 11,111 segments are one byte
long.**

**And the other half of his question has the opposite answer:** mirroring at draw time
**does not pack at all** — it is a set change, not a size change, and it lengthens residency.

**3B — Checkers became a first-class hazard, and are now gated.** Five stale checkers, every
one found **by accident**. `harness_offsets_check.py` now runs on every build, is
**demonstrated to fire** (seeding `CH_CEL` back to 3 reproduces P3.80's bug and exits 1),
and reports **UNCHECKED** rather than passing when it cannot resolve something.

**3C — Two claims of mine retracted this dispatch**, both from proposing before checking: a
spin-up fix that cannot work (`dr_spinup` keys on the driver's flag, not `DSKREG`), and a
frame-cost attribution from two histograms that were not comparable. Both are recorded in
the P3.83b/c+P3.84 report §3C/§3D rather than quietly dropped.

### 4 — Verification

**25.1:** the four suite runs and four build gates in §0, all fresh at `a045661`.
**25.2:** N/A. **25.3: PASSED — Jay, live-disk, RGB** (§1), the full record in
`20260813-233000-p3-83bc-84-green-and-the-freeze-ruling.md` §12.

### 5 — What is left, in order

1. **The re-encode.** Pack opcode+count into one byte: **10,323 B, 27%**; predicted
   38,424 → 28,101 B, 5 pages → 4, **3 loads → 2 — which removes one freeze outright,
   ~5.6 s → ~2.8 s.** Authorised, and green now exists to measure it against. **Measure, do
   not quote** (P3.78 declared the scene unpackable over 78 bytes). Then **one look at the
   grouping** — the scene is one page from needing no staged read at all.
2. **The hourglass and its lightning flash**, the `s_Magic` hold between `Pback` and
   `Vexit`, `addglass1` state 1, `s_StTimer`. Jay found the omission by watching. `s_Magic`
   would also give the packer a **third read point** in the one region that has none.
3. **The turn-to-exit disappearance** — *"the vizier disappears briefly except his feet
   during his turn to exit"* — undiagnosed since P3.78b-d.
4. **The 16-colour swap and the `Prolog2` handoff.**
5. Optional: the HAL motor task (~0.4 s off the remaining freeze, needs a Karateka
   back-port under §2G).

### 6 — Reactive deviations and route accounting

**This report closes work Jay asked for in conversation rather than by dispatch:** the drive
question (P3.84, `22c9e31`), the live run, the gate, and the runner banner (`a045661`).

**Not present:** the re-encode, the grouping look, the hourglass, the flash, `s_Magic`, the
turn diagnosis, the 16-colour swap, the `Prolog2` handoff. **The swap was never unwound;
`shift_row.s` stays retired; draw-time mirroring stays ruled out on schedule grounds.**

### 7 — Uncertainty flags

- **ROOM.BIN has 6 bytes** under the LOADM ceiling. The next thing added to it will not fit;
  the memory map needs revisiting before another feature lands in the room.
- **The clip's per-segment trim cost is UNMEASURED** — the retraction in §3C. A like-for-like
  histogram over the same beats would settle it.
- **Freeze figures vary ±0.1 s** run to run (seek, rotational latency).
- **The re-encode's numbers are a model**, unbuilt.
- Carried: the turn-to-exit disappearance; 0.20 s per-call driver overhead; the
  `$2310..$2329` read-tap blindness; `PlayCut0`'s remaining sound sites.

### 8 — Follow-up candidates

As §5, in that order. The re-encode is both the largest saving and the only one that
changes the number Jay is unhappy with.

### 9 — User interaction during task

Four interventions, all load-bearing: *"are you leaving the motor running during the
scene"* (which found that the drive was released after startup); *"yes"* to a spin-up fix
that turned out not to exist; *"run it for me"*; and the gate, *"looks fine."* Plus the
ruling on the freeze.

### 10 — Candidate(s) captured this task

None new. Two candidates were captured earlier in the arc and both were exercised again
here: `a-failing-tree-is-not-a-baseline` (the re-encode waited three dispatches for green)
and `the-symptoms-shape-can-mislead-too` (§3C's two retractions are the same shape).

### 11 — Commits

`22c9e31`, `b091757`, `a045661` — pushed to origin/wip before this report. The arc's full
sequence is `88f9592` … `a045661` on `wip`.
