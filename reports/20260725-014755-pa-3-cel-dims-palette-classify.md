## Form B Report — PA.3 — tighten the mode-gate inputs: real cel dimensions + palette deliberate-vs-fringe
**Class:** recon / measurement — INSPECTION + MEASUREMENT ONLY. wip. **Prod byte-identity: N/A.**

> **N1 — measured, and it moves the gate.** 602 cels decoded from the `IMG.CHTAB*` assets, validated at **100% structural contiguity**. The real character cel is **924 Apple px median** (→1,056 CoCo3 px), not PA.2's 1,536-px proxy — the proxy was **1.45× too large**.
> **M2 recomputed: typical load now FITS with 8% headroom** (164,580 vs 178,968 cyc) where PA.2 read 1.12× over. It flips to 1.15× over on 90th-percentile characters, so it remains alignment-contingent and close.
> **N2 — the question is NOT resolvable by the prescribed method, and that is the finding.** Spatial coherence and neighbour distribution both fail to separate the four sub-1% indices from **known-deliberate controls**: `dark-blue` carries 16.4% of the screen yet shows 53.4% singletons and 5.5% in large regions. The art is pervasively dithered, so every colour wears the fringe signature. **The effective palette cannot be shown to collapse below 16 — plain C is not revived; C-16 stands.**

---

### 0 — Receipt / status (C-35 stamp)

```
t0=2026-07-25T05:42:31Z
```

**HEAD at t0:** `f4c3f3fafea42c7b70e42d9b085b0566a0210708` (branch `wip`, no tracked file modified).
**HEAD at report time:** same — this dispatch produced no commit other than the report.

**§10 hard-stop gates — both PASS:**
```
vendored source last touched by : ba6154e "P1.1a: vendor oracle buildable-whole @ ec78dbf"
PROVENANCE pin                  : ec78dbfd51013ba349cda8c51c3ce0595fe75342
oracle .hdv md5                 : c4f0b13e49b77dd0fbc5063e27e53a24  -> PASS
```

**§0(a).3 — chtable assets:** all 12 present in `oracle/source/01 POP Source/Images/` — `IMG.CHTAB1`, `2`, `3`, `4.FAT`, `4.GD`, `4.SHAD`, `4.SKEL`, `4.VIZ`, `5`, `6.A`, `6.B`, `7`. Listing in Appendix A.1.

**`git status` at end:** no tracked file modified; 17 untracked (standing 16 + `POP-idioms-coco3-markers.md`).

Calibration-light per CLAUDE.md §1/§5. No elapsed, no band, no variance.

---

### 1 — Summary

**N1 replaced PA.2's weakest input with a measured one.** The cel format was recovered from the blitter's own documentation (`HIRES.S:180-186`, `:255-305`): each table is a count byte, a 2-byte little-endian **absolute** pointer array, then cels of `[width_bytes][height_lines][bitmap]`. All 602 cels across all 12 assets decode, and the decode is **validated structurally** — consecutive cels advance by exactly `2 + w×h` in **100% of cases** on every file (64/64, 69/69, 77/77, 31/31 ×5, 44/44, 102/102, 72/72, 7/7). That is not a plausibility check; it is proof the format and base are right.

Measured character cel (CHTAB1/2/3 + the five CHTAB4 variants, 373 cels): **median area 924 Apple px**, mean 894, 90th percentile 1,470, max 2,009; median 28×36 px. PA.2's proxy was 32×48 = 1,536 CoCo3 px — **1.45× larger** than the measured median once scaled.

**M2 recomputed with real inputs: the typical load now fits.** 5,064 CoCo3 px × 32.5 cy/px = **164,580 cyc against a 178,968 budget — 8% headroom**, where PA.2's proxy gave 199,680 (1.12× over). Substituting 90th-percentile characters gives 205,140 (1.15× over). So the answer moved to the right side of the line but did not move far from it.

**N2 did not resolve, and the honest report of that is the result.** The dispatch's criterion — deliberate colours form sizable contiguous regions, fringe artifacts appear as isolated boundary pixels — looked emphatic on the suspects alone: `grey1`, `grey2` and `pink` have **0.0%** of their pixels in any component ≥20 px, max components of 6–12 px, ~45% outright singletons. Adding **known-deliberate controls** destroyed that verdict: `dark-blue` (16.4% of all pixels) shows **53.4% singletons and only 5.5% in ≥20 px regions**; `magenta` (13.3%) shows **65.3% and 0.4%**. A second, independent metric (neighbour-colour distribution) failed the same way — all four suspects read "mixed/boundary" at 18–25% top-1 share, and so did controls `white` 19.0%, `dark-green` 18.7%, `aqua` 18.8%.

The reason is structural and is itself a finding: **the title art is pervasively dithered.** Every one of the 16 indices neighbours 14–15 other indices. In dithered art a deliberate colour used as a dither partner is spatially indistinguishable from a boundary artifact, so no purely spatial statistic can separate them.

One positive discrimination did survive: **`light-blue` (idx 13) is the only suspect with real solid regions** — largest component 44 px, **43.0%** of its pixels in ≥20 px regions, which exceeds control `white` (36.9%) and far exceeds control `dark-blue` (5.5%).

---

### 2 — Files modified

**None in `POP3_port` except this report.** No source, engine, HAL, content, coco3 or idioms change; no oracle rebuild; `/c/mame`, Karateka and the probe clone untouched. N2 reused PA.2's six retained framebuffer dumps — no new emulator run was required.

No §2A.3 idiom added: the cel-table decode is an *asset-format* technique, not an oracle-instrumentation idiom, so it does not belong in `mame-idioms-apple2e-oracle.md`. Flagged in §8 rather than asserted.

**Pool:** one new `live/` row, `d23aa13` (§10).

---

### 3 — Reasoning

**Authority and the visual boundary.** N1 is a dimension count read from asset bytes. N2 is a spatial statistic over RAM-dumped buffers (PA.2's dumps, banking observed/restored). Neither is an appearance claim, and no PNG was read — CLAUDE.md §3 respected. **Nothing in this report says what anything looks like.** N2's unresolved question is precisely one that *would* need a visual judgement, which is Jay's (§4), and §8 hands it back on that basis rather than my substituting a statistic for his eye.

**Why N1's decode is trustworthy — and the near-miss that proves it.** The auto-detection selected `base=$6000` for **every** table, including the five that `GAMEEQ.S:9-15` declares at `$8400`, `$0800`, `$9600`, `$A800`, `$9F00`. That looked wrong and could easily have been a spurious fit satisfying loose sanity checks — plausible-looking dimensions from a wrong base is exactly the "confidently wrong" outcome to guard against. Rather than reason about it I tested it structurally: if the decode is correct, cels stored sequentially must advance by exactly `2 + w×h`. **They do, in 100% of adjacent pairs on all 12 files.** The declared `GAMEEQ.S` addresses are the tables' **runtime** load addresses in different memory banks; the on-disk files are all *authored* against `$6000`, so `offset = ptr − $6000` is the correct file mapping. Corroborated independently: the first cel offset is `hdr_end + 2` on every single file (133 vs 131, 143 vs 141, 209 vs 207 …) — a consistent 2-byte gap, which a wrong base could not produce twelve times.

*(My first validation script reported 0/N contiguity and was itself buggy — it double-counted the header, adding `hdr_end` to an offset already absolute. The corrected script gives 100%. Recorded because the intermediate result briefly looked like the decode had failed.)*

**Why N2's controls were decisive.** The dispatch's criterion is reasonable on its face and would have produced a clean, confident "these four are fringe" from the suspects alone — `0.0%` in large regions is about as emphatic as a statistic gets. The criterion silently assumes the metric discriminates *on this data*, which measuring only the suspects can never test. The suspects were selected for an unusual property (low pixel mass), so a metric correlating with that property rather than with deliberateness will separate them from nothing at all. Four extra indices over dumps already in hand converted an untested criterion into a calibrated one, and the calibration says: **it does not discriminate here.**

**What the negative result establishes positively.** All 16 indices neighbour 14–15 others; the high-mass pairs cluster (black↔dark-blue 33.2%/36.0%, magenta→dark-blue 40.5%) exactly as dither partners would. So the "16 colours" are not 12 real ones plus 4 accidents — they are structurally entangled in a dither. That matters directly to the gate it feeds: reducing the palette would alter the dither structure and therefore the perceived image, not merely the index count. A forced fringe verdict would have suppressed the one conclusion the data actually supports.

**Why M2's recompute is arithmetic, not a new estimate.** Per §2(c) I substituted the measured cel area into PA.2's unchanged model — same 2 blits/image from `DRAWALL`, same per-byte costs (aligned ≈10, 4bpp-shift ≈55 cy/byte), same measured 178,968-cyc budget, same 320/280 width scaling. Only the sprite-area input changed.

---

### 4 — Verification (AC-by-AC)

**AC1 — N1 method + result. — MET.**
*Format* (`HIRES.S:180-186`, `:255-305`, verbatim in Appendix A.2):
```
table[0]            = image count
table[1 + 2*(n-1)]  = 2-byte little-endian ABSOLUTE address of image n   (setimage: y = IMAGE*2-1)
image[0]            = width in BYTES  (Apple HGR: 7 px/byte)
image[1]            = height in LINES
image[2..]          = bitmap, left-right top-bottom
```
*Base:* `$6000` for all files, structurally validated (§3). *Per-asset breakdown:*

| asset | cels | w px min/med/max | h min/med/max | median area px |
|---|---:|---|---|---:|
| IMG.CHTAB1 | 65 | 7/21/56 | 24/38/43 | 840 |
| IMG.CHTAB2 | 70 | 7/21/49 | 1/38/57 | 815 |
| IMG.CHTAB3 | 78 | 7/21/35 | 1/23/53 | 560 |
| IMG.CHTAB4.FAT | 32 | 7/35/49 | 1/37/42 | 1218 |
| IMG.CHTAB4.GD | 32 | 7/35/56 | 1/37/42 | 1218 |
| IMG.CHTAB4.SHAD | 32 | 7/35/56 | 1/35/38 | 1162 |
| IMG.CHTAB4.SKEL | 32 | 7/35/49 | 1/34/37 | 1113 |
| IMG.CHTAB4.VIZ | 32 | 7/35/56 | 1/36/46 | 1162 |
| IMG.CHTAB5 | 45 | 7/28/49 | 1/36/45 | 903 |
| IMG.CHTAB6.A | 103 | 7/21/35 | 1/25/58 | 525 |
| IMG.CHTAB6.B | 73 | 7/21/56 | 1/36/49 | 861 |
| IMG.CHTAB7 | 8 | 14/21/21 | 48/48/58 | 1008 |

**Typical animated actor (the figure replacing the proxy): 924 Apple px median** (median 28 px wide × 36 lines), from the 373 character cels in CHTAB1/2/3 + CHTAB4.*. Mean 894, 90th pct 1,470, max 2,009.
**CoCo3 equivalent:** ×320/280 on width only → **1,056 CoCo3 px** median, 1,680 at the 90th percentile.
Environment/other (CHTAB5/6/7, 229 cels): median 861 Apple px → **984 CoCo3 px**.

**AC2 — N1 vs the proxy, and direction. — MET.**
PA.2 proxy character 32×48 = **1,536** CoCo3 px vs measured **1,056** → the proxy was **1.45× too large**.
PA.2 proxy tile 32×32 = **1,024** vs measured **984** → **1.04× too large** (essentially right).
**Direction: the correction reduces cost**, because the character cels — the dominant term — are substantially smaller than assumed. Real POP actors are ~28×36, not ~32×48.

**AC3 — N2 method + result, per index. — MET (with the discriminating power reported, not assumed).**
Method: connected components (4-connectivity) over the 140×192 index map of all six PA.2 dumps, plus neighbour-colour distribution; **known-deliberate controls analysed identically**.

| idx | name | px | comps | median comp | largest | % px in 1-px comps | % px in ≥20-px comps | |
|---:|---|---:|---:|---:|---:|---:|---:|---|
| 5 | grey1 | 767 | 512 | 1 | 12 | 44.7% | **0.0%** | suspect |
| 10 | grey2 | 1173 | 800 | 1 | 6 | 46.4% | **0.0%** | suspect |
| 11 | pink | 918 | 552 | 1 | 7 | 47.2% | **0.0%** | suspect |
| 13 | light-blue | 1581 | 579 | 1 | **44** | 23.7% | **43.0%** | suspect |
| 0 | black | 43568 | 8082 | 2 | 4304 | 6.8% | 60.6% | **control** |
| 8 | dark-blue | 26453 | 16789 | 1 | 154 | **53.4%** | **5.5%** | **control** |
| 15 | white | 7807 | 2477 | 1 | 570 | 20.3% | 36.9% | **control** |
| 1 | magenta | 21390 | 15785 | 1 | 31 | **65.3%** | **0.4%** | **control** |

Neighbour distribution (top-1 neighbour share): suspects `grey1` 25.0%, `grey2` 22.6%, `pink` 17.9%, `light-blue` 19.6% — all "mixed/boundary". Controls: `white` 19.0%, `dark-green` 18.7%, `aqua` 18.8% — **indistinguishable**; only the high-mass cluster separates (`magenta`→dark-blue 40.5%, `dark-blue`→black 36.0%, `black`→dark-blue 33.2%). All 16 indices neighbour 14–15 distinct colours.

**Per-index verdict:**
- **idx 13 light-blue — DELIBERATE.** The one clear call: 43.0% of its pixels sit in regions ≥20 px, exceeding control `white` (36.9%) and far exceeding control `dark-blue` (5.5%); largest region 44 px.
- **idx 5 grey1, idx 10 grey2, idx 11 pink — UNRESOLVED, not "fringe".** They form no region ≥20 px, but control `magenta` — 13.3% of the entire screen — also forms essentially none (0.4%, max component 31). On this art the criterion does not distinguish "never forms a region" from "not deliberate", so the fringe verdict is **not supported**.

**AC4 — is the effective deliberate palette ~16 or does it collapse toward ≤8? — MET: it does NOT collapse on this evidence; the effective count remains 16.**
One suspect (light-blue) is positively deliberate. The other three are unresolved rather than excluded, and the measurements give no basis for removing them. **No index can be shown to be a mere artifact**, so the deliberate count stands at 16 with three entries carrying an explicit "unresolved by spatial statistics" caveat. Per §1/§6 this is a **count**, not a proposed reduced palette, and no merge or remap is offered.

**AC5 — M2 recomputed with N1's real cel size. — MET.** Budget **178,968 cyc/step** (§5.16).

| scenario | CoCo3 px | aligned (10 cy/px) | mixed (32.5) | shifted (55) | verdict at *mixed* |
|---|---:|---:|---:|---:|---|
| **typical: prince + 1 guard + 3 tiles (median cels)** | **5,064** | **50,640** | **164,580** | 278,520 | **FITS, 8% headroom** |
| typical, 90th-pct characters | 6,312 | 63,120 | 205,140 | 347,160 | OVER 1.15× |
| busy: prince + 2 guards + 6 tiles (median) | 9,072 | 90,720 | 294,840 | 498,960 | OVER 1.65× |
| busy, 90th-pct characters | 10,944 | 109,440 | 355,680 | 601,920 | OVER 1.99× |
| *PA.2 proxy typical (comparison)* | *6,144* | *61,440* | *199,680* | *337,920* | *OVER 1.12×* |

**The headline movement: typical goes from 1.12× over to 8% under.** It fits at *any* alignment better than ~37 cy/px, and fits with 72% headroom if fully aligned.

**AC6 — gate-input update. — MET, in §8, as indication only.**

**AC7 — no source/engine/HAL/content/coco3 change; status clean except standing untracked. — MET.**

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output — APPLIES, satisfied.** Verbatim in the appendices: the cel decode (12 assets, 602 cels), the structural validation (100% contiguity), the two N2 analyses with controls, and the M2 recompute.

**25.2 — N/A.** Nothing built or imaged.

**25.3 — N/A as a gate.** N1 is a dimension count from asset bytes; N2 is a spatial statistic over RAM buffers. Neither is an appearance claim; no PNG was read (CLAUDE.md §3). Appearance remains Jay's (§4) — and §8 explicitly routes N2's residue back to him for that reason.

**C-35 presence check — SATISFIED.** §0 quotes verbatim `t0=2026-07-25T05:42:31Z` and HEAD. No elapsed, no band, no variance.

**Capture presence check — SATISFIED.** §10 carries one slug.

---

### 6 — Reactive deviations

**6.1 — N2's prescribed criterion does not discriminate on this data; I report that instead of a verdict. (Most important deviation.)**
§5.2 specified "deliberate ⇒ a few sizable contiguous regions; fringe ⇒ many isolated pixels at colour boundaries," and AC3/AC4 expect a per-index verdict and a possible collapse toward ≤8. Measured on the suspects alone the criterion returns an emphatic fringe verdict (0.0% in ≥20 px regions for three of four). **Known-deliberate controls falsify it**: `dark-blue` at 16.4% of the screen scores 5.5%, `magenta` at 13.3% scores 0.4%. A second independent metric fails identically. I therefore report **one resolved index (light-blue, deliberate) and three unresolved**, and explicitly decline the "collapse to ≤8" conclusion the criterion would have produced. Adding controls was not requested; it is what prevented a confident wrong answer feeding the gate. Captured as a pool candidate.

**6.2 — Every table decodes against `$6000`, contradicting the `GAMEEQ.S` addresses; validated rather than assumed.**
`GAMEEQ.S:9-15` declares `chtable2=$8400`, `chtable3=$0800`, `chtable4=$9600`, `chtable5=$A800`, `chtable7=$9F00`, yet all 12 files decode against `$6000`. Those are **runtime** load addresses for different banks; the on-disk files are authored against `$6000`. Established by 100% structural contiguity plus the invariant `first_cel_offset = hdr_end + 2` across all 12 files (§3), not by argument. Recorded because taking `GAMEEQ.S` at face value would have produced garbage dimensions or a false "cannot decode".

**6.3 — My first validation script was wrong and briefly indicated the decode had failed.** It computed `offset = ptr − min(ptr) + hdr_end`, double-counting the header, and reported `0/N` contiguity with last-cel-end values far beyond file size. The corrected mapping `offset = ptr − $6000` gives 100%. Reported because the intermediate output looked like a decode failure and would have been a plausible place to abandon N1.

**6.4 — Five of twelve assets carry trailing slack beyond the last decoded cel.** `CHTAB3`, `4.SHAD`, `5`, `6.A`, `7` end exactly at file size; the rest have unused tails, `IMG.CHTAB4.GD` most notably (last cel ends at 5,281 in an 8,999-byte file — 3.7 KB). Contiguity is 100% within the decoded range, so this is not a decode error; plausibly a second appended table or padding. Not investigated (out of scope) and it does not affect the dimension statistics.

**6.5 — Cel heights of 1 line appear in most tables** (min h = 1 for CHTAB2/3/4.*/5/6). These are real entries in the tables, not decode noise — the contiguity test passes through them. They drag the *mean* below the median and are included in all statistics as found. If some are placeholders rather than drawable cels, the character median would rise slightly and the M2 headroom shrink.

**6.6 — M2's 8% headroom is inside the model's own error.** The recompute changed one input. Everything PA.2 §7 flagged still holds — the alignment mix is assumed 50/50 (a 5.5× lever), the blit costs are Karateka's static analysis for a 4-colour mode doubled for 4bpp, and blits-per-image is 2. An 8% margin does not survive an adverse move in any of those. Stated plainly so the fit is not over-read.

**6.7 — Actor-count assumptions are unchanged and unmeasured.** N1 measured cel *sizes*; the scenario compositions (1 guard typical, 2 busy, 3/6 tiles) are still PA.2's assumptions. POP's actual simultaneous-actor limit was not determined this dispatch — `maxpeel = 46` is a list capacity, not a typical count. This is now the dominant open input in M2, having displaced cel size.

**6.8 — No idiom was added.** The cel-table decode is an asset-format technique, not an oracle-instrumentation idiom, so `mame-idioms-apple2e-oracle.md` is the wrong home under §2A.3. Surfaced in §8 for the Orchestrator rather than filed unilaterally.

---

### 7 — Uncertainty flags

1. **Three of four suspect indices remain unclassified** (§6.1). Resolving deliberate-vs-fringe needs either perceptual analysis at display resolution or Jay's eye — the latter being the authority the question actually belongs to.
2. **M2's 8% headroom is marginal** (§6.6) and rests on an assumed 50/50 alignment mix, which remains the single largest lever at 5.5×.
3. **Actor counts are unmeasured** (§6.7) — now M2's weakest input.
4. **The 320/280 width scaling** treats a CoCo3 port as rendering the same cels 1.14× wider. A port choosing 1:1 pixels would reduce cost ~12%; one redrawing art at native CoCo3 resolution invalidates the mapping entirely.
5. **Character/environment table attribution** follows the naming convention (CHTAB1/2/3 + CHTAB4.* = characters; 5/6/7 = environment/other) and the `CHTAB4.*` variant names (GD guard, SHAD shadow, SKEL skeleton, FAT, VIZ vizier). Which table holds the kid specifically was **not** confirmed from `SEQTABLE.S`/`SEQDATA.S`; if CHTAB1-3 are not all kid cels the character median shifts.
6. **N2 sampled title screens only.** Gameplay cels may dither differently, and the gate concerns both.
7. **Palette index names are conventional** (PA.2 §3); the counts are convention-independent, the labels are not.

---

### 8 — Follow-up candidates

**Gate-input update (§4 AC6 / §5.4 — INDICATION ONLY; Jay decides at §9.10):**

- **N1 strengthens C-16.** The typical load moved from 1.12× over to **8% under budget** at 50/50 alignment, and fits comfortably (72% headroom) if aligned. C-16 is no longer excluded on cost for a typical frame.
- **But it remains alignment-contingent and close.** 90th-percentile characters put it 1.15× over, and the busy scenario is 1.65–1.99× over at 50/50. The 5.5× alignment lever still dominates the 2× mode lever, so the gate's shape is unchanged: **the blitter's alignment strategy decides this, not the colour depth.**
- **N2 does not revive plain C.** The palette does not collapse: one suspect is positively deliberate, three are unresolved, none is shown to be an artifact. The effective deliberate count stands at **16**. Moreover the pervasive dither means a reduction would alter the perceived image rather than merely the index count — which argues the 16 are load-bearing, though that judgement is Jay's.
- **Net: C-16, contingent on blit alignment, with B as fallback** — the same shape as PA.2 but with the cost input now measured and landing on the favourable side. Indication, not decision.

**Ordered follow-ups:**
1. **Measure POP's actual simultaneous-actor count** — now M2's dominant uncertainty (§6.7), having displaced cel size.
2. **Settle the three unresolved indices** (§6.1/§7.1) — needs perceptual analysis or Jay's eye; a spatial statistic will not do it.
3. **Establish whether the CoCo3 blitter can guarantee byte-aligned actor blits** — the 5.5× lever, and now the single largest determinant of the gate.
4. **Confirm which chtable holds the kid** from `SEQTABLE.S`/`SEQDATA.S` (§7.5).
5. **Cycle-exact validation of the blit cost** (PA.2 §6.6) — still the largest systematic uncertainty in the cost basis.
6. **Rule on where the cel-decode technique belongs**, if anywhere (§6.8).
7. Standing: `POP-idioms-coco3-markers.md` disposal; the POP-level `.gitattributes` task.

---

### 9 — User interaction during task

**None.** No question asked; bridge-safe-equiv. Every judgment call — adding controls to N2 (§6.1), validating the `$6000` base (§6.2), my own buggy validator (§6.3), declining the "collapse to ≤8" verdict (§6.1/AC4), not filing an idiom (§6.8) — is surfaced in §6 for post-hoc ruling.

---

### 10 — Candidate(s) captured this task

One new `live/` row, pushed in pool commit `d23aa13`:

- `seeds/POP/live/2026-07-25-classification-metrics-need-known-positive-controls.md` — a classification metric must be run on known-**positive** controls alongside the suspects; without them a metric that discriminates nothing returns a confident clean verdict, and the failure is invisible and directional because the suspects were selected for being unusual (from §6.1). `initiator: executor`.

`seeds/POP/live/` now holds **eighteen** POP rows.

---

### 11 — Commit

- **This report's commit** — on `wip`, pushed to `origin/wip` before reporting back. Hash in the accompanying reply.
- **No other `POP3_port` commit** — measurement only, per §9 of the dispatch.
- **Pool:** `d23aa13`.

---
---

## Appendix A — N1: cel dimensions

### A.1 — assets (§0(a).3)
```
IMG.BGTAB1.DUN 9056   IMG.BGTAB1.PAL 9185   IMG.BGTAB2.DUN 4299   IMG.BGTAB2.PAL 4593
IMG.CHTAB1     9165   IMG.CHTAB2     9189   IMG.CHTAB3     5985
IMG.CHTAB4.FAT 5469   IMG.CHTAB4.GD  8999   IMG.CHTAB4.SHAD 5011
IMG.CHTAB4.SKEL 4749  IMG.CHTAB4.VIZ 5445   IMG.CHTAB5     6134
IMG.CHTAB6.A   9201   IMG.CHTAB6.B   8092   IMG.CHTAB7     1155
```

### A.2 — the format, from the blitter's own documentation (`HIRES.S`)
```
*  Image table format:
*  Byte 0:    width (# of bytes)
*  Byte 1:    height (# of lines)
*  Byte 2-n:  image bytes (read left-right, top-bottom)          [HIRES.S:180-186]

setimage lda IMAGE / asl / sec / sbc #1 / tay                     [HIRES.S:264-268]
 lda (TABLE),y / sta IMAGE / iny / lda (TABLE),y / sta IMAGE+1
GETWIDTH ... ldy #1 / lda (IMAGE),y ;height / tax
             dey     / lda (IMAGE),y ;width                        [HIRES.S:287-302]
```

### A.3 — structural validation (the decisive check)
```
file                     n  first hdrend    contig  lastend   size  verdict
IMG.CHTAB1              65    133    131   64/64       8999   9165  CHECK(tail)
IMG.CHTAB2              70    143    141   69/69       8893   9189  CHECK(tail)
IMG.CHTAB3              78    159    157   77/77       5985   5985  OK
IMG.CHTAB4.FAT          32     67     65   31/31       5262   5469  CHECK(tail)
IMG.CHTAB4.GD           32     67     65   31/31       5281   8999  CHECK(tail)
IMG.CHTAB4.SHAD         32     67     65   31/31       5011   5011  OK
IMG.CHTAB4.SKEL         32     67     65   31/31       4493   4749  CHECK(tail)
IMG.CHTAB4.VIZ          32     67     65   31/31       5218   5445  CHECK(tail)
IMG.CHTAB5              45     93     91   44/44       6134   6134  OK
IMG.CHTAB6.A           103    209    207  102/102      9201   9201  OK
IMG.CHTAB6.B            73    149    147   72/72       8052   8092  CHECK(tail)
IMG.CHTAB7               8     19     17    7/7        1155   1155  OK
```
**Contiguity is 100% on every file** (each consecutive cel advances by exactly `2 + w×h`). `first = hdrend + 2` on all twelve. "CHECK(tail)" flags unused trailing bytes only (§6.4), not a decode failure.

### A.4 — aggregate dimensions
```
total cels decoded: 602
width  px : min 7  median 21  mean 24.9  max 56
height px : min 1  median 36  mean 30.9  max 58
area   px : min 7  median 882  mean 828.4  max 2009

CHARACTER cels (CHTAB1/2/3 + CHTAB4.*): 373 cels
  width  px : median 28  mean 27.5  max 56
  height px : median 36  mean 31.7  max 57
  area   px : median 924  mean 893.8  max 2009   90th pct 1470

ENVIRONMENT/other (CHTAB5/6/7): 229 cels
  area px: median 861  mean 721.8  max 1960
```

---

## Appendix B — N2: palette classification, with controls

### B.1 — spatial coherence (6 dumps pooled)
```
idx name              px  comps  median  largest   %px in   %px in
                                   comp     comp      1px   >=20px
--- SUSPECT (sub-1% indices from PA.2) ---
  5 grey1            767    512       1       12    44.7%     0.0%
 10 grey2           1173    800       1        6    46.4%     0.0%
 11 pink             918    552       1        7    47.2%     0.0%
 13 light-blue      1581    579       1       44    23.7%    43.0%
--- CONTROL (known-deliberate, high-mass) ---
  0 black          43568   8082       2     4304     6.8%    60.6%
  8 dark-blue      26453  16789       1      154    53.4%     5.5%
 15 white           7807   2477       1      570    20.3%    36.9%
  1 magenta        21390  15785       1       31    65.3%     0.4%
```
Controls `dark-blue` and `magenta` — 16.4% and 13.3% of all screen pixels — score *worse* than the suspects on the "forms regions" criterion. The metric separates solid-fill from dithered colours, not deliberate from artifact.

### B.2 — neighbour-colour distribution
```
idx name                top-1 neighbour   top1%   top2%  distinct   reading
  5 grey1                    dark-green   25.0%   15.8%        14   [suspect] mixed/boundary
 10 grey2                    dark-green   22.6%   15.6%        15   [suspect] mixed/boundary
 11 pink                         orange   17.9%   17.3%        14   [suspect] mixed/boundary
 13 light-blue                     aqua   19.6%   16.8%        15   [suspect] mixed/boundary
  0 black                     dark-blue   33.2%   30.7%        15   [control] leaning dark-blue
  8 dark-blue                     black   36.0%   35.7%        15   [control] leaning black
 15 white                         black   19.0%   14.7%        15   [control] mixed/boundary
  1 magenta                   dark-blue   40.5%   37.7%        15   [control] leaning dark-blue
  4 dark-green                    black   18.7%   17.1%        15   [control] mixed/boundary
 14 aqua                          black   18.8%   15.4%        15   [control] mixed/boundary
```
Suspects (17.9–25.0%) are indistinguishable from controls `white` 19.0%, `dark-green` 18.7%, `aqua` 18.8%. Every index neighbours 14–15 distinct colours — pervasive dithering.

---

## Appendix C — M2 recompute

```
budget = 29859 x 6 - 186 = 178,968 cyc per animation step

N1 measured character cel: median 924 Apple px -> 1056 CoCo3 px  (PA.2 proxy 1536 -> 1.45x over)
N1 measured environment cel: median 861 Apple px -> 984 CoCo3 px (PA.2 proxy 1024 -> 1.04x over)

scenario                                            px   aligned     mixed   shifted   verdict(mixed)
typical  prince+1 guard+3 tiles (median cels)     5064    50,640   164,580   278,520   FITS, 8% headroom
typical  same, 90th-pct characters                6312    63,120   205,140   347,160   OVER 1.15x
busy     prince+2 guards+6 tiles (median)         9072    90,720   294,840   498,960   OVER 1.65x
busy     prince+2 guards+6 tiles (90th-pct)      10944   109,440   355,680   601,920   OVER 1.99x
PA.2 proxy typical (for comparison)               6144    61,440   199,680   337,920   OVER 1.12x
```
Unchanged from PA.2: 2 blits/image (`GRAFIX.S:481-503` DRAWALL restore+draw), aligned ≈10 / 4bpp-shift ≈55 cy per source byte (Karateka `gfx.s` static analysis, doubled for 4bpp), 0.5 bytes/px at 4bpp, 320/280 width scaling. Only the sprite-area input changed.

---

*End of report.*
