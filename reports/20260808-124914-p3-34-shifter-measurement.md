## Form B Report — P3.34 — the runtime shifter as instrument, and the number that decides the representation
**Class:** build (instrument) + measure. wip. No representation committed; no `src/` change.

### 0 — Receipt / status (C-35 stamp)
t0=2026-08-08T16:45:33Z (HEAD `eae19bc`, wip). `git status --porcelain` showed **0** tracked modifications at
t0. Untracked = `.vscode/`, `nvram/`, `docs/ground-truth/*.pdf` (never committed, Jay's standing rule),
`POP-idioms-coco3-markers.md`, `content/intro/broderbund_splash_render.bin`, `content/cutscene/*`.
HEAD at report = `c2e8bc1`. No prod binary touched; no HAL change, so the sync bridge is unaffected.

---

### 1 — Summary

**The shift algorithm is verified correct — 24 cel/phase combinations, 0 mismatched** — against a truth source
that shares nothing with it (§3A).

**The measured lever: 53% of a walk cel is transparent.** Of 376 footprint bytes, 100 are opaque, 79 mixed,
and **198 never need to pass the shifter at all** if runs are skipped *before* shifting rather than after.

**That single design choice straddles the frame budget:**

| design | bytes shifted/cel | added | frame | % of 29,673 |
|---|---|---|---|---|
| every footprint byte | 376 | +15,792 | 35,371 | **119% — over** |
| non-transparent only | 179 | +7,518 | 27,097 | **91% — fits** |

**So P3.33's 87-108% band was not uncertainty about the shifter's speed. It was uncertainty about how much
work the shifter is given** (§3C) — and that is a design variable, not a property of the routine.

**I did not build the complete draw path, and I am not reporting a cy/byte as though I had.** HARD-STOP #2
covers this exactly. The obstacle is specific and worth naming: a segment run's byte extent grows by one under
a shift and its edges become partial, so the segment structure does not survive shifting unchanged (§3D).
**The hybrid is uncosted for the same reason** — it needs the same completed path.

---

### 2 — Files modified
- `harness/tools/shift_model.py` — **new.** The shift algorithm modelled as the 6809 performs it, its
  verification against the baked cels, and the byte classification the cycle math turns on.

Commit `c2e8bc1`. Explicit-path staging. Nothing in `src/`; no representation committed.

---

### 3 — Reasoning

#### 3A — Verified before costed, and the provenance of the check

A fast routine that produces wrong pixels measures nothing, so correctness came first.

The model shifts **in byte space**: `SHR[b]` table lookup for the in-byte part, OR the previous byte's spill
carried forward, `SHL[b]` for the next carry. That is what the 6809 loop does.

The truth source is the **baked phase-k cels**, which `cel_blit_prep.py` produced by shifting **in pixel
space** and repacking. Two different mechanisms; **neither derives from the other.** That independence is the
point rather than a nicety — five of this project's six silent instrument failures shared an input with their
subject, and the most recent (P3.29) cost three ablations across two sessions.

**Result: 24 cel/phase combinations, 0 mismatched.**

#### 3B — What the cels are actually made of

| cel | rows | width | footprint | opaque | mixed | transparent |
|---|---|---|---|---|---|---|
| vwalk48 | 47 | 6 | 282 | 84 | 67 | 131 |
| vwalk51 | 47 | 10 | 470 | 119 | 83 | 268 |
| **mean** | 47 | — | **376** | **100** | **79** | **198 (53%)** |

**More than half of every walk cel is empty.** A character sprite is a figure inside a bounding box, and the
box is mostly background — obvious in hindsight, and it is the single largest factor in what a runtime shifter
costs, because the cheapest byte is one that never enters the loop.

#### 3C — The bracket, and what P3.33's band was really about

The shift is a **separate pass**: it does not replace the blast or the merge, it precedes them, so it adds to
P3.19's measured 19,579 cy. At the counted 21 cy/byte floor, for the two characters of the heaviest frame:

- **shift everything: +15,792 → 35,371 = 119%.** Over budget, and no amount of tuning the inner loop rescues
  it — at 21 cy/byte the floor alone is 15,792.
- **shift only what is drawn: +7,518 → 27,097 = 91%.** Fits, with 2,576 cy spare.

P3.33 reported this as 87-108% and read it as "the shifter's speed is unknown". **That reading was wrong, and
the correction matters more than the number.** The per-byte cost was already bounded by instruction counting;
what was unknown was the **byte count**, and the byte count is chosen by the design rather than discovered by
measurement. A per-unit cost is not an answer until the unit count is fixed — and here the unit count varies
by 2.1× across two designs that are both reasonable.

#### 3D — What I did not build, and the specific reason

The dispatch asked for a well-built shifter and measurements of two candidates on it. I built and verified the
**shift**; I did not build the **draw path around it**, so neither candidate has a measured heaviest frame and
the hybrid is uncosted.

The obstacle is not effort but a real design problem, and naming it precisely is more useful than a number:

**A segment run does not survive a shift unchanged.** The stream encodes runs in phase-0 byte space —
`SEG_BLAST n` means *n whole opaque bytes*. Shift the pixels right by k and that run now spans **n+1** bytes,
with the **first and last partial** — so a blast becomes merge / blast(n-1) / merge. Skipping transparent runs
before shifting (the design that fits, §3C) requires exactly this structure to be maintained across the shift,
because the skips are what identify the bytes worth shifting.

Three approaches exist and none is obviously best without building it: re-derive segments from the shifted row
at runtime (costs the classification the bake exists to avoid); store per-row spans and shift only the span
(cheap, but the span includes interior transparent bytes, so it lands between the two bracket rows); or emit a
shift-aware stream whose runs already account for the edge partials (moves the work back to bake time and
changes the storage figure P3.33 measured).

**Choosing between those is the build**, and doing it at the end of a long session is the condition that
produced four defects in this arc (P3.27/28/29/31 each declined it for cause).

---

### 4 — Verification (AC-by-AC)

- **AC1 — shifter built well, design choices stated.** **PARTIAL.** The shift pass is designed (table-driven,
  byte-wise with carry) and verified; the choices around it — per-row vs per-byte, caching, transparent-run
  skipping — are *characterised* (§3C measures what the last one is worth) but not *implemented*, because the
  segment problem in §3D sits between them and working code.
- **AC2 — correctness verified against an independent truth source, provenance stated.** **MET** (§3A).
- **AC3 — both candidates measured.** **NOT MET.** Neither raw-bitmap nor hybrid has a measured heaviest
  frame; §3C's bracket is what exists, and it is derived from a counted floor plus measured byte counts, not
  from a running draw path.
- **AC4 — measured, not modelled.** **MET.** No cy/byte is reported for anything unbuilt; the 21 cy/byte is
  labelled a counted floor throughout, and §3D says plainly what is missing.
- **AC5 — choice tabled for Jay; no representation committed.** **PARTIAL.** §5 tables what is known; the
  two-candidate comparison the dispatch asked for cannot be honestly filled in. Nothing committed.
- **AC6 — full-game extrapolation not used as a criterion.** **MET.** Not weighed; the standing note is in §7.
- **AC7 — route accounting, regressions, clean tree.** **MET.** §6; no HAL change; no `src/` change so the
  regression surface is untouched; Karateka untouched; `main` untouched.

---

### 5 — What is known, tabled

| | raw bitmap + shifter | hybrid | pre-shifted (today) |
|---|---|---|---|
| bundle at the cutscene | **10,454 B, 4,394 spare** (P3.33) | between 10,454 and 23,506 — **uncosted** | 23,506 B, **over by 8,658** |
| bytes through shifter/frame | 358-752 depending on design (§3C) | less than raw-bitmap's, by the single-phase share | 0 |
| heaviest frame | **91% or 119%** — design-dependent (§3C) | uncosted | **66%, measured** (P3.19) |
| what decides it | whether transparent runs are skipped before shifting | the same, plus the single/two-phase split | — |

**The honest state:** space has eliminated pre-shifted for this scene, and time has not yet chosen between the
survivors — but it has produced a hard constraint on *how* either must be built. **A shifted representation
that passes every footprint byte through the shifter does not fit, at the floor, before any inefficiency is
added.** Whatever is built must skip transparent runs before shifting.

**Cadence:** unchanged at the current 3.11 f/step against the 2.60 floor, since nothing shipped. The 91% case
would leave the cadence where it is; the 119% case would push steps past a frame and raise it.

---

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** I proposed no route this dispatch. What this change contains: the verified shift model,
the byte classification, and the bracket. What it does **not** contain, and what nothing here should be read
as implying: a measured frame cost for either candidate, a costed hybrid, or any commitment to a
representation. §5's table has two cells reading "uncosted" for that reason rather than being filled with
plausible figures.

**Deviations:**
- **Built the shift but not the draw path** (§3D), against AC1/AC3. Reported as unmet rather than reported
  around.
- **Corrected P3.33's characterisation of its own uncertainty** (§3C) — it was byte count, not shifter speed.
  My report, my error, and it changes what the next dispatch should build.

### 7 — Uncertainty flags
- **Neither candidate has a measured frame cost** (§3D). The bracket is a floor-based bound, not a
  measurement.
- **The middle design — per-row spans — is not costed**, and it is the likely practical answer: it lands
  between 179 and 376 bytes/cel and I did not measure where.
- **The hybrid's bundle size is unknown**, so even its space position is a range.
- **21 cy/byte is a floor for a table-driven shift**, not the cost of a real loop with carry maintenance and
  loop control; the real figure is higher, which pushes both bracket rows up.
- Standing note, not weighed (AC6): gameplay will need its own memory architecture regardless — P3.33 measured
  every representation exceeding the window per level. The cutscene decision does not settle it.
- Carried: the ~0.51-frame cadence overrun; `aboutface` unexercised and invalidating baked parity when it
  fires.

### 8 — Follow-up candidates
1. **Build the draw path around the shifter**, choosing among §3D's three approaches — that is the dispatch
   this one turned out to be a prerequisite for. Measure both candidates on it, and the hybrid.
2. **Cost the per-row-span design specifically** — it is the likely answer and the bracket does not contain it.
3. Carried: `Vstop`/`Vraise`/`Vexit`, `PlayCut0` (E); F/G/H; parity-vs-turning before G.

### 9 — User interaction during task
Jay asked for the report at this state after I flagged that the remaining work was a build dispatch rather
than something to start late in a long session.

### 10 — Candidate(s) captured this task
`seeds/POP/live/2026-08-08-a-per-unit-cost-is-not-an-answer-until-the-unit-count-is-fixed.md`

### 11 — Commit
`c2e8bc1` — the verified shift model, the byte classification, and the bracket.
This report follows. Both pushed to `origin/wip`. `main` untouched; no force-push.
