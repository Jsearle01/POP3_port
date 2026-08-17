## Form B Report — PA.6 — the feasibility gate: does B actually fit? (real actor count + cycle-exact 4-colour blit)
**Class:** recon / measurement — MEASURE + CYCLE-COUNT ONLY. wip. **Prod byte-identity: N/A.**

> ## VERDICT: **INFEASIBLE** with the inherited blit as written — 1.58× to 2.86× over budget.
> **N1 (measured):** 9 blit ops/frame median, 12 p90 — close to the ~10 assumed, so the actor count was *not* the problem.
> **N2 (counted from the code):** the 4-colour blit is **54 cy/byte aligned, 88 shifted** — not the **~10 / ~55** that `gfx.s`'s header comment claims and that PA.2/PA.3/PA.5 all used. **The aligned figure was understated 5.4×.** Independently cross-checked: the Apple's own masked blit runs at ~52 cy/byte, so ~54 is right and ~10 was never plausible.
> **The typical frame's BLIT ALONE is 176,948 cyc = 0.99× of the entire 178,968 budget**, before any game logic.
> **But this is an implementation verdict, not a hardware one.** A blit matching the Apple's per-byte efficiency needs `k ≤ 1.28` — achievable. The current one needs `k ≤ 0.24` — impossible. **The whole gap is the blit's per-byte cost.**

---

### 0 — Receipt / status (C-35 stamp)

```
t0=2026-07-25T17:44:35Z
```

**HEAD at t0:** `2008221c511a5b3ae85469b283aca2630a90d782` (branch `wip`, no tracked file modified).
**HEAD at report time:** same — this dispatch produced no commit other than the report.

**§10 hard-stop gates — both PASS:**
```
vendored source last touched by : ba6154e "P1.1a: vendor oracle buildable-whole @ ec78dbf"
PROVENANCE pin                  : ec78dbfd51013ba349cda8c51c3ce0595fe75342
oracle .hdv md5                 : c4f0b13e49b77dd0fbc5063e27e53a24  -> PASS
```
**§0(a).3 CFFA2 ROM:** `1 romsets found, 1 were OK` — N1 **not blocked**.
**§0(a).4 Karateka clone:** present; `src/hal/coco3-dsk/gfx.s` (47,949 B) read — **N2 uses the primary source, not the fallback.**

**`git status` at end:** no tracked file modified. **18** untracked — the standing 16 `docs/ground-truth/` paths, `POP-idioms-coco3-markers.md`, and **`.vscode/` (new this session, 18th)**.

Calibration-light per CLAUDE.md §1/§5. No elapsed, no band, no variance.

---

### 1 — Summary

**N1 exonerates the actor count.** A write tap on `XCO` (`$01`) binned by PC counts cels *exactly* — each draw loop in `GRAFIX` writes `XCO` once per cel it draws, so this is a count, not a sample. Over 948 demo steps: normal-animation frames run **9 blit operations median** (peel 2 + bg 2 + mid 2 + fg 0, means summing to 8.97), **12 at p90**, max 29. PA.3/PA.5 assumed 5 images × 2 blits = 10 operations. **The assumed actor count was very nearly right** — this was not the soft input that mattered.

**N2 is where it breaks.** Cycle-counting Karateka's actual 6809 inner loops gives **54 cycles per byte aligned** (`blit_do_sb0`) and **88 shifted** (`blit_do_sb1`). `gfx.s`'s own header block states "~10 cy" aligned and "~47 cy" at subbyte=1, and PA.2 adopted those, PA.3 refined against them, PA.5 carried the result into the frame budget. **Three dispatches of budget arithmetic rested on a figure 5.4× too low.** The header describes an *opaque copy* (`lda ,x+` / `sta ,y+`); the code beneath it implements a **transparency-masked** blit — `pshs/tfr/lda b,u/coma/anda ,y/stb/ora/sta ,y+/puls` per output byte.

**The count is independently confirmed.** PA.5 measured the Apple's blit at 61,734 6502 cycles for the same ~9 operations — ~52 cycles per byte for the same masked operation. Scaling by the 2.0× byte ratio (2bpp vs 1bpp) and the 1.37× per-byte ratio predicts **18,744** cycles per CoCo3 op; the instruction count gives **19,727**. Agreement within 5%, from a completely independent direction.

**Result: the typical frame's blit alone is 176,948 cycles — 0.99× of the whole 178,968 budget**, with zero cycles left for game logic. Adding PA.5's measured non-blit remainder puts the frame at **1.58×–2.86× over**.

**What this does and does not say.** It is a verdict on *the inherited blit implementation*, not on the hardware or the mode. The structural position is tighter than anyone assumed but not hopeless: the CoCo3's **1.70×** cycle advantage over the Apple is almost exactly cancelled by 2bpp's **1.75×** byte penalty, so POP-CoCo3 has **blit throughput parity with the original** — it must be about as efficient per byte as Mechner's blitter, and currently it is 1.37× worse. Close that gap and the frame fits at any plausible `k`; leave it and no `k` saves it. Per §6 I did not attempt to close it.

---

### 2 — Files modified

**None in `POP3_port` except this report.** No source, engine, HAL, content, coco3 or idioms change. No oracle rebuild. `/c/mame`, Karateka and the probe clone untouched (Karateka read-only for N2).

No §2A.3 idiom filed — the authorship ruling is still pending and this is the fourth dispatch to defer (§6.6).

**Pool:** one new `live/` row, `7b2665a` (§10).

---

### 3 — Reasoning

**Authority.** N1 is an exact machine count. N2 is an instruction-level cycle count of real 6809 source. The Apple cross-check is PA.5's measurement. The only modelled inputs are `k`, the cel-size mapping, and the alignment mix — all listed in the §4 ledger. No appearance claim anywhere.

**Why N1 is a count, not a sample.** Every draw loop in `GRAFIX` writes `XCO` exactly once per cel, at a distinct PC:
```
$06A4 DRAWWIPE   (rectangles — NOT cels, excluded)
$06D3 DRAWBACK   (background plane cel)
$0701 DRAWFORE   (foreground plane cel)
$0745 SNGPEEL    (background RESTORE — the peel)
$0770 DRAWMID    (middle plane cel = characters)
```
A **write** tap on `$01` binned by CURPC therefore counts cels with no sampling error at all. Self-test: every count landed inside its source-declared cap (`maxback=200`, `maxmid=46`, `maxfore=100`, `maxpeel=46`) and none was zero. A second internal check corroborates the model: `peel` and `mid` have identical medians (2) and near-identical means (2.71 / 2.86) — exactly as `DRAWALL` specifies, since `SNGPEEL` restores only what `DRAWMID` saved. A tap counting the wrong thing would not reproduce that relationship.

**Why the room-redraw frames were separated.** 99 of 948 demo steps show `bg > 10` (median 12, max 84) — full-room background redraws on room entry, not per-frame animation. Mixing them would inflate the typical figure with an event that happens on transitions. They are reported separately (§4 AC1) and the feasibility verdict uses the 849 normal-animation steps.

**Why the header estimate could survive three dispatches.** It is *internally consistent*: its worked example ("4-byte × 10-row sprite at subbyte=1: ~1880 cycles") reconciles exactly with its own per-byte figure (40 × 47 = 1880). Anyone checking the arithmetic finds it sound; only counting the instructions beneath it exposes the gap. The decay is the ordinary kind — the routine gained transparency masking and the header was not re-measured — and its direction is systematically optimistic, because a stale performance comment describes a simpler earlier version. Captured as a pool candidate.

**Why no 6502→6809 `k` is applied to the blit.** Per §10, `k` scales only the 6502-*measured* non-blit remainder. N2 counts real 6809 instructions on the target ISA, so the blit term needs no cross-ISA scaling and applying one would double-count. That separation is preserved in every total in §4.

**What the structural arithmetic shows.** Apple HGR is 7 px/byte (280 px = 40 bytes/row); CoCo3 320×192×4 is 4 px/byte (320 px = 80 bytes/row) — **1.75× the bytes per pixel**. The CoCo3 has **1.70×** the Apple's cycles per animation step (178,968 vs 105,259). Those cancel. So the port's blit budget is, to within 3%, *the same as the Apple's*, and the Apple already spends 59% of its frame there. There is no mode-choice or actor-count lever large enough to change that; only per-byte blit efficiency is.

---

### 4 — Verification (AC-by-AC)

**AC1 — N1 method + worst-case count. — MET.**
Method above. Sampled 400 emulated seconds, 1,096 real steps, 948 in the demo window.

| | peel | bg | mid | fg | cels (bg+mid+fg) | **total (cels+peel)** |
|---|---:|---:|---:|---:|---:|---:|
| **DEMO normal-animation** (n=849, `bg≤10`) median | 2 | 2 | 2 | 0 | 6 | **9** |
| p90 | 4 | 6 | 4 | 1 | 9 | **12** |
| max | 9 | 10 | 13 | 6 | 24 | **29** |
| mean | 2.71 | 2.86 | 2.86 | 0.54 | 6.26 | **8.96** |
| **DEMO room-redraw** (n=99, `bg>10`) median | 1 | 12 | 1 | 1 | 16 | **17** |
| max | 4 | 84 | 10 | 25 | 106 | **106** |

**How the busy frames were reached:** by sampling the attract demo across 400 s rather than driving input; the heaviest frames encountered bound the worst case. **The count fed to N2 is 8.97 ops (typical) and 12 (p90).** Caps confirmed never exceeded. Note the peel/mid correspondence above as an internal validity check.

**AC2 — N2 cycle-exact blit. — MET.** Source: `/c/Projects/karateka_coco3/src/hal/coco3-dsk/gfx.s`, `blit_do_sb0` and `blit_do_sb1` (the primary source, not the fallback). MC6809 timings: indexed base 4; `,R+` +2; `B,R` +1; direct load/store 4; direct read-modify-write 6; `PSHS`/`PULS` 5+1/byte; `TFR` 6; inherent 2; branch 3.

*Aligned (`blit_do_sb0`), per source byte:*
```
lda ,x+ 6 | pshs b 6 | tfr a,b 6 | lda b,u 5 | coma 2 | anda ,y 4
stb <tmp 4 | ora <tmp 4 | sta ,y+ 6 | puls b 6 | decb 2 | bne 3   = 54 cy/byte
row overhead (ldb width / ldb #80 / subb / leay b,y / dec height / bne) = 24 cy/row
```
*Shifted (`blit_do_sb1`), per source byte:*
```
clr <ovf_new 6 | lda ,x+ 6 | lsra 2 | ror <ovf_new 6 | lsra 2 | ror <ovf_new 6
ora <ovf_prev 4 | pshs b 6 | tfr a,b 6 | lda b,u 5 | coma 2 | anda ,y 4
stb <tmp 4 | ora <tmp 4 | sta ,y+ 6 | puls b 6 | lda <ovf_new 4 | sta <ovf_prev 4
decb 2 | bne 3                                                    = 88 cy/byte
row overhead (incl. the trailing overflow-byte write) = 63 cy/row
```
**Per POP-sized cel** (PA.3 median character 1,056 CoCo3 px over 36 rows; 2bpp = 4 px/byte):
```
character   aligned 15,120   shifted 25,500   50/50 avg 20,310 cyc
environment aligned 14,004   shifted 23,538   50/50 avg 18,771 cyc
```

**AC3 — blit mix applied. — MET.** PA.4 established 1-px horizontal motion with 56% of moving frames on odd `Fdx`; at 4bpp (2 px/byte) that gives ~50/50 aligned/shifted, applied above.

**AC4 — feasibility verdict. — MET.** Average op = 19,727 cyc (weighted: peel+mid at character size, bg+fg at environment size).

```
case             blit  nonblit(k)    k      total   vs budget  verdict
typical       176,948     105,259  1.0    282,207       1.58x  INFEASIBLE
typical       176,948     147,363  1.4    324,311       1.81x  INFEASIBLE
typical       176,948     189,466  1.8    366,414       2.05x  INFEASIBLE
p90           236,720     153,270  1.0    389,990       2.18x  INFEASIBLE
p90           236,720     214,578  1.4    451,298       2.52x  INFEASIBLE
p90           236,720     275,886  1.8    512,606       2.86x  INFEASIBLE
```
**Typical BLIT ALONE = 176,948 = 0.99× of budget. p90 blit alone = 236,720 = 1.32×.** Both labels are **INFEASIBLE** by §4's own thresholds; neither typical nor p90 reaches even "marginal".

**Independent cross-check of N2** (the reason to trust the flip):
```
Apple blit (PA.5 measured)   : 61,734 cyc / 8.97 ops = 6,882 cyc per op
bytes per character cel      : Apple 132   CoCo3 264   -> 2.00x
Apple per-byte               : 52 cy/byte  |  CoCo3 counted 54 aligned / 88 shifted (71 avg)
predicted CoCo3 per op       : 6,882 x 2.00 x (71/52) = 18,744
N2 counted per op            : 19,727                        -> agreement within 5%
```

**AC5 — measured-vs-modelled ledger. — MET.**

| term | status | source |
|---|---|---|
| N1 cel/peel counts per frame | **MEASURED (exact count)** | oracle, XCO write tap binned by PC |
| N2 blit cycles per byte/row | **MEASURED (instruction count)** | Karateka `gfx.s` `blit_do_sb0`/`sb1`, MC6809 timings |
| non-blit remainder (6502) | **MEASURED** | PA.5 oracle, 105,259 median / 153,270 p90 |
| Apple blit share (cross-check) | **MEASURED** | PA.5 PC attribution |
| `k` (6502→6809 non-blit) | **ASSUMPTION**, 1.0–1.8 band | no in-repo convention exists (PA.5 §6.2) |
| cel pixel area | measured (PA.3) → **mapped** ×320/280 | PA.3 medians; the scaling is a modelling choice |
| environment cel row count (30) | **ASSUMED** | PA.3 gave area, not height, for env cels |
| 50/50 alignment mix | **DERIVED** from PA.4 | 56% odd-`Fdx` moving frames |
| present overhead (186 cyc) | **ASSUMED** | backlog §3; negligible at 0.1% |

**AC6 — the double-speed check. — MET.** The 178,968 budget = 6 × 29,859 − 186, and 29,859 × 60 Hz = **1.79 MHz**, i.e. it **does** assume CoCo3 double-speed (`$FFD9`). The budget is therefore already the optimistic case; at normal speed (0.89 MHz) it halves to ~89,500 and the verdict worsens correspondingly. Per the disk-speed rule (backlog §3; CLAUDE.md §2G, PROVISIONAL from Karateka) double-speed breaks the FDC, so disk I/O must drop to normal speed — animation is not disk-bound per frame, so the per-frame budget stands, but **any frame that touches disk cannot assume 29,859 cycles.** PA.5's outlier steps (max 40.5M 6502 cycles) are exactly such disk events.

**AC7 — no source/engine/HAL/content/coco3 change; status clean except standing untracked. — MET** (18 untracked, `.vscode/` new — §0).

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output — APPLIES, satisfied.** N1 oracle run quoted verbatim in AC1 and Appendix A (`Average speed: 1471.22%`, 1,102 rows, self-test against source caps). N2 derivation quoted instruction-by-instruction in AC2 and Appendix B. Verdict arithmetic in Appendix C.

**25.2 — N/A.** Nothing built or imaged.

**25.3 — N/A as a gate.** Counts and cycle derivations only; no appearance claim.

**C-35 presence check — SATISFIED.** §0 quotes verbatim `t0=2026-07-25T17:44:35Z` and HEAD.

**Capture presence check — SATISFIED.** §10 carries one slug.

---

### 6 — Reactive deviations

**6.1 — The soft input that decided feasibility was N2, not N1 — the opposite of the dispatch's expectation.**
§1 framed both inputs as jointly deciding. N1 came in at 9 ops median against ~10 assumed — **the actor count was already essentially right** and changes nothing. The entire flip comes from N2: the blit is 5.4× more expensive per aligned byte than the figure in use since PA.2. Worth stating because it redirects where future estimate error should be expected: not in the counts, in the per-unit costs.

**6.2 — `gfx.s`'s header cost estimate does not describe the code beneath it. (The finding.)**
Header: "subbyte=0: ~10 cy … subbyte=1: ~47 cy … 4-byte × 10-row sprite at subbyte=1: ~1880 cycles". Counted: **54** and **88** cy/byte. The header describes an opaque `lda ,x+`/`sta ,y+` copy; the implementation is transparency-masked (a per-byte table lookup, complement, mask, merge, plus stack save/restore of the loop counter). PA.2 adopted the header figures, PA.3 and PA.5 built on them. **The aligned case — the one that produced every "fits comfortably" statement in this arc — was understated 5.4×.** Captured as a pool candidate. Note this also retroactively explains PA.3's suspiciously generous "72% headroom if fully aligned" branch: at 54 cy/byte that branch never existed.

**6.3 — The verdict is INFEASIBLE, and §5.4's "fits neither" branch says flag it loudly. Flagging it — with its precise boundary.**
Both modes now fail: C-16 at 1.14×–1.45× (PA.5) and B at 1.58×–2.86× (here). Per §6 I did **not** attempt to solve it. But "infeasible" alone is not actionable, so I computed what would have to be true — arithmetic on measured numbers, not a design proposal:

```
current 6809 blit (71 cy/byte avg)
  blit = 61,734 x 2.00 x 1.37 = 168,581 cyc (0.94x of budget)
  leaves 10,387 for non-blit -> requires k <= 0.24   IMPOSSIBLE

PERFECT blit (matching the Apple's measured 52 cy/byte)
  blit = 61,734 x 2.00 x 1.00 = 123,468 cyc (0.69x of budget)
  leaves 55,500 for non-blit  -> requires k <= 1.28   ACHIEVABLE
```
**The whole feasibility question reduces to the blit's per-byte cost.** The 2.00× byte factor is inherent to 2bpp and not addressable; the 1.37× per-byte factor is entirely implementation. This is a finding, not a plan — what to do about it is Jay's and the Orchestrator's.

**6.4 — A structural fact worth recording independently of the verdict.** CoCo3 320×192×4 costs **1.75× the bytes per pixel** of Apple HGR, and the CoCo3 has **1.70×** the cycles per animation step. These cancel: **POP-CoCo3 has blit throughput parity with the 1983 original.** The port has no inherent headroom to spend on a less efficient blitter, in any mode. This is mode-independent and survives every assumption in this report.

**6.5 — Room-redraw frames excluded from the typical figure.** 99 of 948 demo steps redraw the full background (`bg` up to 84, total up to 106 ops). Those are room transitions; at 19,727 cyc/op a 106-op frame is ~2.1M cycles, ~12× the budget — but it is a transition, not sustained animation, and POP itself takes multiple frames over them. Excluded from the verdict and reported separately so the exclusion is visible rather than silent.

**6.6 — No idiom filed; fourth consecutive deferral.** The XCO-write-tap-binned-by-PC technique for exact per-frame draw counting is genuinely reusable oracle instrumentation and would qualify under §2A.3. Not filed: the idioms-authorship ruling requested in the oracle-run report §6.3, and deferred again in PA.3 §6.8 and PA.5 §6.7, remains outstanding. Four techniques are now queued behind one ruling.

**6.7 — `.vscode/` appeared as an 18th untracked path** this session (not created by me). Noted so the untracked count reconciles against prior reports' 17.

---

### 7 — Uncertainty flags

1. **`k` remains an assumption** (no in-repo convention, PA.5 §6.2). The verdict is invariant across 1.0–1.8, but the *break-even* analysis in §6.3 turns on it directly — `k ≤ 1.28` is the threshold a corrected blit would have to meet, and nothing has measured `k`.
2. **Environment-cel row count (30) is assumed**; PA.3 measured area, not height, for `CHTAB5/6/7`. Character rows (36) are measured. Env cels are ~38% of ops, so a ±25% row error moves the blit total ~3%.
3. **Cel sizes are mapped, not measured, on CoCo3** — PA.3's Apple medians × 320/280. A 1:1-pixel port would reduce the blit ~12%; a redraw at native CoCo3 resolution invalidates the mapping.
4. **No genuine scripted combat frame was isolated** (carried from PA.5 §6.3). The p90 (12 ops) is the proxy for a heavy frame; a real fight could exceed it.
5. **N2 counts the inherited implementation as it stands today.** It is a snapshot of Karateka's `gfx.s`, which POP has not yet adopted or adapted.
6. **The `mul`-based row-address computation and per-call setup** (~40 cycles) are excluded from the per-cel figures; at ~0.2% of a cel's cost this is immaterial but is an omission.
7. **MC6809 timings are the standard published counts**; I did not cross-check them against the vendored Motorola manual instruction-by-instruction. The Apple cross-check (§4) is the practical validation and agrees within 5%.

---

### 8 — Follow-up candidates

**Feasibility verdict for the gate (§3 deliverable — statement only; the rethink is Jay's):**

- **B is INFEASIBLE with the inherited blit**, at 1.58×–2.86× over budget. The typical frame's blit alone consumes 99% of the budget.
- **The mode question is settled and was never the lever.** C-16 fails (PA.5), B fails (here), and the actor count was accurate all along. **Per-byte blit efficiency is the only term large enough to matter.**
- **The gap is precisely bounded:** a blit at the Apple's measured 52 cy/byte makes the frame fit for any `k ≤ 1.28`. The current one requires `k ≤ 0.24`, which is impossible. **1.37× on per-byte blit cost is the whole feasibility question.**
- **Parity, not hopelessness.** POP-CoCo3 has the same effective blit budget as the 1983 original (§6.4). That is a demanding target, not an impossible one — the original hit it on a 1 MHz 6502.

**Ordered follow-ups:**
1. **Jay/Orchestrator: rethink scope in light of the verdict** — this is the "changes the whole plan" branch and the decision is not mine.
2. **Measure `k`** — it is now the threshold variable in the break-even, not just a scaling caveat. Two dispatches have flagged it.
3. **Re-audit any other cost figure taken from a comment** rather than counted — the same failure mode may sit elsewhere in the inherited substrate (§6.2).
4. **Correct or annotate `gfx.s`'s header estimate** — it is Karateka's file and read-only to POP, so this is a Karateka-side task, but POP should not re-adopt the stale figure.
5. **Rule once on idioms-file authorship** (§6.6) — four techniques now queued.
6. Standing: `POP-idioms-coco3-markers.md` disposal; the POP-level `.gitattributes` task; `.vscode/` disposition.

---

### 9 — User interaction during task

**None during execution.** The dispatch's framing (Jay's: C-16 eliminated, so this is feasibility not preference) shaped the report's emphasis. Every judgment call — separating room-redraw frames, computing the break-even boundary rather than stopping at "infeasible", not filing an idiom, not attempting a fix — is surfaced in §6 for post-hoc ruling.

---

### 10 — Candidate(s) captured this task

One new `live/` row, pushed in pool commit `7b2665a`:

- `seeds/POP/live/2026-07-25-a-cost-estimate-in-a-comment-is-not-a-measurement-of-the-code.md` — a performance figure in a comment header is a claim about code that may have changed underneath it; count the instructions before it becomes the basis of a decision, because a stale estimate is internally consistent, systematically optimistic, and never re-derived (from §6.2). `initiator: executor`.

`seeds/POP/live/` now holds **twenty-one** POP rows.

---

### 11 — Commit

- **This report's commit** — on `wip`, pushed to `origin/wip` before reporting back. Hash in the accompanying reply.
- **No other `POP3_port` commit** — measurement only, per §9 of the dispatch.
- **Pool:** `7b2665a`.

---
---

## Appendix A — N1: per-frame cel count, verbatim

```
mame apple2e -sl7 cffa202 -hard1 PrinceOfPersia_3.5.hdv -video none -sound none \
     -nothrottle -seconds_to_run 400 -autoboot_script actorcount.lua
Average speed: 1471.22% (399 seconds)      rows: 1102

SELF-TEST (counts vs source-declared caps):
  steps=1096  max peel=9 (cap 46)  max bg=84 (cap 200)  max mid=13 (cap 46)
              max fg=25 (cap 100)  max cels=106
```
Tap: **write** tap on `$01` (XCO) binned by CURPC; step boundary from a **read** tap on `$C05F`. PCs from `obj/GRAFIX.LST`: `$06A4` DRAWWIPE, `$06D3` DRAWBACK, `$0701` DRAWFORE, `$0745` SNGPEEL, `$0770` DRAWMID.

```
--- DEMO normal-animation steps (n=849, bg<=10) ---
  peel   median   2.0  mean   2.71  p90   4.0  max    9
  bg     median   2.0  mean   2.86  p90   6.0  max   10
  mid    median   2.0  mean   2.86  p90   4.0  max   13
  fg     median   0.0  mean   0.54  p90   1.0  max    6
  cels   median   6.0  mean   6.26  p90   9.0  max   24
  total  median   9.0  mean   8.96  p90  12.0  max   29

--- DEMO room-redraw steps (n=99, bg>10) ---
  bg     median  12.0  mean  16.51  p90  19.0  max   84
  cels   median  16.0  mean  21.01  p90  25.0  max  106
  total  median  17.0  mean  22.38  p90  28.0  max  106

histogram, cels per normal-animation step:
   3:115  4:133  5:89  6:307  7:34  8:62  9:24  10:16  11:6  12:10
  14:12  15:14  16:2  17:2  18:4  20:8  21:2  22:4  24:2
```

---

## Appendix B — N2: the cycle count, verbatim

Source: `/c/Projects/karateka_coco3/src/hal/coco3-dsk/gfx.s`.

```
=== per-byte inner loop, ALIGNED (blit_do_sb0) ===
    lda ,x+            6      stb <tmp           4
    pshs b             6      ora <tmp           4
    tfr a,b            6      sta ,y+            6
    lda b,u            5      puls b             6
    coma               2      decb               2
    anda ,y            4      bne                3
    TOTAL/byte        54      row overhead      24

=== per-byte inner loop, SHIFTED (blit_do_sb1) ===
    clr <ovf_new       6      stb <tmp           4
    lda ,x+            6      ora <tmp           4
    lsra               2      sta ,y+            6
    ror <ovf_new       6      puls b             6
    lsra               2      lda <ovf_new       4
    ror <ovf_new       6      sta <ovf_prev      4
    ora <ovf_prev      4      decb               2
    pshs b             6      bne                3
    tfr a,b            6
    lda b,u            5      TOTAL/byte        88
    coma               2      row overhead      63
    anda ,y            4

POP-sized cel, 4-colour 2bpp:
  character (1056 px, 36 rows): aligned   15,120   shifted   25,500   50/50 avg   20,310
  environment (984 px, 30 rows): aligned   14,004   shifted   23,538   50/50 avg   18,771

PA.2/PA.3/PA.5 used the gfx.s HEADER estimate: aligned ~10 cy/byte, shifted ~55 cy/byte.
COUNTED FROM THE CODE:                        aligned 54 cy/byte, shifted 88 cy/byte.
  -> aligned understated by 5.4x ; shifted understated by 1.6x
```

The header block, quoted from `gfx.s` for the record:
```
* Cycle estimate per source byte (static analysis):
*   subbyte=0: ~10 cy (lda ,x+ + sta ,y+ + loop overhead)
*   subbyte=1: ~47 cy (2xLSR + 2xROR + OR-blend + overflow handling)
*   subbyte=2: ~55 cy (4xLSR + 4xROR + OR-blend + overflow)
*   subbyte=3: ~63 cy (6xLSR + 6xROR + OR-blend + overflow)
* For a 4-byte x 10-row sprite at subbyte=1: ~1880 cycles.
```

---

## Appendix C — verdict and break-even, verbatim

```
N1 measured: 8.97 blit ops/frame typical (median total 9, p90 12, max 29)
N2 counted : char 50/50 20,310 cyc, env 18,771 cyc  ->  19,727 cyc per average op

TYPICAL frame BLIT ALONE = 176,948 cyc  = 0.99x of the 178,968 budget
P90     frame BLIT ALONE = 236,720 cyc  = 1.32x

case             blit  nonblit(k)    k      total   vs budget  verdict
typical       176,948     105,259  1.0    282,207       1.58x  INFEASIBLE
typical       176,948     147,363  1.4    324,311       1.81x  INFEASIBLE
typical       176,948     189,466  1.8    366,414       2.05x  INFEASIBLE
p90           236,720     153,270  1.0    389,990       2.18x  INFEASIBLE
p90           236,720     214,578  1.4    451,298       2.52x  INFEASIBLE
p90           236,720     275,886  1.8    512,606       2.86x  INFEASIBLE

=== CROSS-CHECK against the Apple's MEASURED blit cost (PA.5) ===
  Apple blit  : 61,734 cyc / 8.97 ops = 6,882 cyc per op
  bytes per char cel: Apple 132  CoCo3 264  ratio 2.00x
  Apple per-byte    : 52 cy/byte     CoCo3 counted: 54 (aligned) / 88 (shifted)
  predicted CoCo3 per op = 6,882 x 2.00 x (71/52) = 18,744
  N2 counted per op      = 19,727   -> consistent with the measured Apple cost

=== structural, implementation-independent ===
  Apple 1bpp : 7 px/byte -> 280px row = 40 bytes
  CoCo3 2bpp : 4 px/byte -> 320px row = 80 bytes   (1.75x bytes per pixel)
  CoCo3 cycles per animation step / Apple's:        1.70x
  -> the 1.70x cycle advantage is cancelled by the 1.75x byte penalty.
     Effective blit throughput is ~PARITY with the Apple.

=== what would have to be true for B to fit? ===
  current 6809 blit (71 cy/byte avg)
    blit = 61,734 x 2.0 x 1.37 = 168,581 cyc  (0.94x of budget)
    leaves 10,387 for non-blit -> requires k <= 0.24   IMPOSSIBLE
  PERFECT blit (matches Apple's 52 cy/byte)
    blit = 61,734 x 2.0 x 1.00 = 123,468 cyc  (0.69x of budget)
    leaves 55,500 for non-blit -> requires k <= 1.28   ACHIEVABLE
```

---

*End of report.*
