## Form B Report — PA.9 — compiled-sprite proof-of-concept: does the pipeline work on real POP cels, and does it hit PA.7's cost?
**Class:** PROTOTYPE + MEASURE. wip. **Prod byte-identity: N/A** — POC measurement instrument, not a prod artifact.

> ## N1 SOUNDNESS: **ALL PASS.** The pipeline produces correct sprites.
> 12 real POP cels + 8 real Karateka variants compiled; every emitted routine's writes reproduce the expected render **exactly**, with transparent positions preserving a canary background. Verified by executing the instruction list against a virtual framebuffer and diffing — a data check, not a look.
> ## N2: **PA.7's number does NOT hold on POP's own art — and this is the risk the dispatch existed to catch.**
> Glen's proxy is ~22% mixed bytes. **POP's real cels are 68.9% mixed** — thin limbs and outlines, not a solid blob. Real draw cost is **6.44 cy/footprint-byte vs PA.7's 4.09 — 1.57× worse.**
> **Feasibility survives:** typical frame **0.68×–0.92×** of budget at k ≤ 1.4. But blit share rises 9.4% → **14.0%**, and the p90 frame moves from comfortable to **MARGINAL (1.01×)** at k=1.0.
> ## N3: opaque-black resolves at compile time — and marking it **makes sprites FASTER**, not slower.
> On real authored sidecars: `scene6_bg_A6A6` goes 249 → **202 cycles** with opacity applied, because opaque black converts read-modify-write bytes into plain stores.

---

### 0 — Receipt / status (C-35 stamp)

```
t0=2026-07-25T20:56:58Z
```
**HEAD at t0:** `09776c759117f6c7a9c643ba08a0f0fe542c8aff` (branch `wip`). **§10 gates:** vendored source at `ec78dbf` (`ba6154e`); oracle `.hdv` md5 `c4f0b13e49b77dd0fbc5063e27e53a24` — **PASS**.
**`git status` at end:** the POC path `poc/compiled-sprite/` plus the standing 18 untracked. Calibration-light; no band, no variance.

---

### 1 — Summary

**The pipeline works.** A throwaway compiler (`poc/compiled-sprite/`) reads a cel's pixels plus an opacity plane, resolves transparency **at compile time**, and emits 6809 instructions — PSHU bursts for opaque runs, skip for transparent bytes, read-modify-write for mixed. Every one of the 20 compiled routines passes an exact-match soundness diff. Jay's standing worry — "don't get excited about stack-blasting you can't actually draw" — is answered: the code draws, and correctly.

**PA.7's cost does not transfer.** PA.7 counted Glen's real sprite rigorously, and flagged the proxy assumption honestly, but did not test whether POP's art has the same *internal structure*. It does not. The cost driver is the **mixed byte** — one containing both opaque and transparent pixels, forcing a 4-instruction RMW instead of a shared store. Glen's sprite is ~22% mixed (a solid blob); **POP's cels average 68.9% mixed** across 12 samples spanning large/median/thin in three kid tables and one guard table. Real draw cost: **6.44 cy per footprint byte against PA.7's 4.09.**

**Feasibility holds, with less margin.** Scaling the erase by the same structural factor gives 14.99 cy/byte draw+erase. The typical frame's blit rises 10,860 → **17,099 cycles**; the frame totals **0.68×** budget at k=1.0 and **0.92×** at k=1.4. The p90 frame is now **1.01× — marginal — even at k=1.0.** Against PA.6's ~52 cy/byte break-even, compiled sprites remain **3.5× better than required** (was 5.5×).

**On the sprite tool I was wrong, and Jay corrected me.** I characterised stage 1 by reading `sprite_convert.py`'s docstring — a *different* tool (the one-time Apple→CoCo3 converter) — and concluded the pipeline could not distinguish opaque black from transparent. It can. `harness/tools/sprite_tool/` writes a per-cel **`opacity.s` sidecar**, created only when a cel has opaque work and deleted when none remains, with `converted.s` byte-identical for opacity-only edits. `opacity.py` states the model exactly: *"Opacity is meaningful ONLY for index-0 (black) pixels: is this black pixel OPAQUE (shadow, stored solid) or KEYED (transparent)? Non-0 pixels (1/2/3) are always drawn."* **That is precisely the three-way token model a compiler needs, already authored** (§6.1).

---

### 2 — Files modified

**`poc/compiled-sprite/`** (new, POC path per §9 — *not* under `src/`):
- `popcc.py` — throwaway compiler: cel decode, tokenizer, 6809 emitter with register tracking, MC6809 cycle counter, store-level simulator.
- `run_poc.py` — driver: POP cel sample + real Karateka sidecar cases.

**No POP source, engine, HAL, content or idioms change.** Karateka, Glen's repo and the probe clone read-only.
**Pool:** one new `live/` row, `db9c5dc` (§10).

---

### 3 — Reasoning

**Why soundness is a data diff, not a render.** The simulator prefills a virtual framebuffer with a canary (`$A5`), executes the emitted instruction list (LEAU/LDD/LDX/LDY/PSHU/LDA/ANDA/ORA/STA against a modelled U register), then checks every byte: `store` bytes must equal the sprite value, `skip` bytes must still hold the canary (**background preserved — this is what proves transparency works**), `mixed` bytes must equal `(canary & keepmask) | value`. A single mismatch is a FAIL. This is §7's data-diff requirement; nothing here is an appearance claim.

**Why the compiler tracks registers.** PA.7 observed Glen's file has 46 `PSHU` but only 13 `LDD #` — register values are reused across rows. The prototype models D/X/Y contents and emits an immediate load only when the needed value is not already live. Without that, PSHU bursts would cost more in loads than they save.

**Why mixed-byte fraction is the whole story.** At 2bpp a byte spans 4 pixels. A byte entirely inside the figure is a plain store (shared across a PSHU burst, ~2 cy/byte amortised); a byte entirely outside is free (skipped); a byte straddling the edge needs `LDA/ANDA/ORA/STA` ≈ 14 cycles for one byte. So cost is dominated by **perimeter per unit area**. Glen's sprite is compact and solid; POP's cels are thin figures with limbs and a sword, which have far more edge per pixel. That is a structural property, invisible in "a 20×18 mostly-solid sprite", and it is what PA.7's proxy assumption missed. **It was also cheaply checkable in advance** — mixed-byte fraction needs only the pixel grid, not a compiler (§10 candidate).

**Why POP's cels skip 59% of their footprint.** POP cels are Apple HGR 1bpp masks drawn in OR/mask mode, so OFF is transparent by construction. That is why footprint cy/byte (6.44) is far below drawn-only cy/byte (15.52) — most of a cel's bounding box costs nothing. It also means POP's cels currently carry **no authored opaque black at all**; every index-0 pixel is keyed. Opaque black becomes relevant only when the ported art authors it (§6.3).

---

### 4 — Verification (AC-by-AC)

**AC1 — prototype built and described. — MET.** Python 3, `poc/compiled-sprite/`, throwaway. Input: pixel grid (0–3) + opacity plane (bool per index-0 pixel). Output: 6809 instruction list (`LEAU`/`LDD`/`LDX`/`LDY`/`PSHU`/`LDA`/`ANDA`/`ORA`/`STA`), cycle-counted with the MC6809 timings used in PA.6/PA.7. Rows walked bottom-up, each row right-to-left, matching PSHU's pre-decrement.

**AC2 — sample selected and justified. — MET.** 12 cels: **large / median / thin** from each of `CHTAB1`, `CHTAB2`, `CHTAB3` (kid) and `CHTAB4.GD` (guard), sized 14×3 up to 49×41 — spanning PA.3's dimension range and both actor types. Thin cels are included deliberately because they are the mixed-byte worst case.

**AC3 — N1 soundness. — MET: ALL PASS.**
```
CHTAB1 #40 49x41 large   bytes 533 (skip 393 store  54 mixed  86) instr 431 cyc 2026  OK
CHTAB1 #47 21x40 median  bytes 240 (skip 111 store  48 mixed  81) instr 404 cyc 1780  OK
CHTAB1 #54 14x39 thin    bytes 156 (skip  54 store  38 mixed  64) instr 330 cyc 1614  OK
CHTAB2 #3  42x39 large   bytes 429 (skip 304 store  40 mixed  85) instr 413 cyc 1962  OK
CHTAB2 #2  21x39 median  bytes 234 (skip 114 store  32 mixed  88) instr 412 cyc 1982  OK
CHTAB2 #34 14x38 thin    bytes 152 (skip  53 store  34 mixed  65) instr 321 cyc 1561  OK
CHTAB3 #6  35x38 large   bytes 342 (skip 228 store  33 mixed  81) instr 386 cyc 1840  OK
CHTAB3 #11 14x40 median  bytes 160 (skip  65 store  24 mixed  71) instr 330 cyc 1628  OK
CHTAB3 #43 28x3  thin    bytes  21 (skip  13 store   5 mixed   3) instr  19 cyc   74  OK
CHTAB4.GD #15 42x39 lg   bytes 429 (skip 273 store  44 mixed 112) instr 524 cyc 2365  OK
CHTAB4.GD #1  35x36 med  bytes 324 (skip 175 store  41 mixed 108) instr 505 cyc 2354  OK
CHTAB4.GD #31 35x19 thin bytes 171 (skip  85 store  19 mixed  67) instr 303 cyc 1353  OK
SOUNDNESS: ALL PASS  (0 mismatches across 3,191 footprint bytes)
```

**AC4 — N2 cost + byte classes. — MET, and it corrects PA.7.**
```
footprint bytes 3,191 | drawn 1,323 (41%) | skipped 1,868 (59%)
mixed / drawn   911 / 1,323 = 68.9%          <- Glen's proxy: ~22%
cycles          20,539
cy/byte (footprint) 6.44                      <- PA.7 (Glen, draw only): 4.09  => 1.57x worse
cy/byte (drawn)    15.52
```
**POP's mixed fraction is 3.1× Glen's**, and that is the entire delta.

**AC5 — feasibility re-check. — MET.** Erase scaled by the same 1.57× structural factor (8.55), giving **14.99 cy/footprint-byte draw+erase**; POP cel (264 B) = 1,700 cy draw / 3,957 cy draw+erase.
```
case          blit  nonblit(k)    k     total  vs budget  verdict
typical     17,099     105,259  1.0   122,358      0.68x  FEASIBLE
typical     17,099     147,363  1.4   164,461      0.92x  FEASIBLE
typical     17,099     189,466  1.8   206,565      1.15x  INFEASIBLE
p90         27,730     153,270  1.0   181,000      1.01x  MARGINAL
p90         27,730     214,578  1.4   242,308      1.35x  INFEASIBLE
p90         27,730     275,886  1.8   303,616      1.70x  INFEASIBLE
```
**Typical stays feasible to k ≈ 1.5** (PA.7 said ~1.5 too, with more slack). **p90 is now marginal at k=1.0** where PA.7 had it at 0.95×. Blit share 9.4% → **14.0%**. Against PA.6's ~52 cy/byte break-even: **3.5× better** (was 5.5×).

**AC6 — N3 opaque-black at compile time. — MET, on real authored data.** Rather than a synthetic case I ran four real Karateka cels that carry authored `opacity.s` sidecars, each **twice** — once honouring the sidecar, once ignoring it (control):
```
scene6_bg_A684 [mixed]   opaqueblk 12/12  8 bytes (skip  0 store  8 mixed  0)  40 cy  OK
scene6_bg_A684 [IGNORED]                  8 bytes (skip  2 store  4 mixed  2)  62 cy  OK
scene6_bg_A6A6 [stencil] opaqueblk 99/102 42 bytes (skip  0 store 39 mixed  3) 202 cy  OK
scene6_bg_A6A6 [IGNORED]                  42 bytes (skip 21 store 11 mixed 10) 249 cy  OK
scene6_bg_A6C0 [mixed]   opaqueblk 39/42  24 bytes (skip  0 store 21 mixed  3) 162 cy  OK
scene6_bg_A6C0 [IGNORED]                  24 bytes (skip  9 store  9 mixed  6) 170 cy  OK
```
The distinction is resolved **entirely in the tokenizer**; the emitted code contains **no mask table and no runtime transparency test**. Both variants are sound, and they differ — proving the sidecar actually drives instruction selection.
**Unexpected and worth acting on: marking black opaque makes sprites CHEAPER** (249 → 202 cy), because it converts RMW bytes into plain stores. Opaque black is a performance *win*, not a cost.

**AC7 — tool boundary. — MET (corrected, §6.1).** Stage 1 is **`harness/tools/sprite_tool/`**, not `sprite_convert.py`. It emits:
- `converted.s` — `fcb H,W` + 2bpp packed pixels; **byte-identical for opacity-only edits**
- `opacity.s` — sidecar, written only where opaque work exists, deleted when none remains; kinds `mixed` (rects `fcb start_col,width,start_row,num_rows,opaque`), `masked` (one mask byte per column), `stencil` (2D mask)
- registry state as a *consequence* of saving: `authored` / `none` / `converted`

**Can it drive the compiler as-is? Yes — with a read-side transform, no tool change.** The prototype consumes exactly this pair and expands the sidecar into a per-pixel opacity plane. Two notes for the production compiler: (a) `opacity.py` raises **`CannotEncode`** for row-varying sub-byte opacity because the *runtime* descriptors cannot express it — **a compiled sprite has no such limit**, since it bakes per-byte decisions into instructions, so the compiler could accept opacity the current HAL must reject; (b) compiled sprites also eliminate the `_mixed`/`_masked`/`stencil_punch` blit variants and their extra passes entirely.

**AC8 — no POP source/engine/HAL/content change. — MET.** Only `poc/compiled-sprite/` + this report.

---

### 5 — Verdict-time evidence

**25.1 — APPLIES, satisfied.** Compiler runs, cycle counts and soundness diffs quoted verbatim in AC3/AC4/AC6.
**25.2 — POC artifact** at `poc/compiled-sprite/`; a measurement instrument, **no byte-identity gate** (stated per §7).
**25.3 — N/A as a gate.** Soundness is a data diff (compiled writes vs expected bytes), never "looks right". Final art look is Jay's, later.
**C-35 — SATISFIED.** §0 quotes `t0` and HEAD. **Capture — SATISFIED**, §10.

---

### 6 — Reactive deviations

**6.1 — I mischaracterised the stage-1 tool; Jay corrected me mid-task.** I read `sprite_convert.py`'s docstring ("pixel OFF → palette 0 (Black)") and reported that the pipeline collapses black and transparent and cannot express opaque black. **Wrong on two counts:** that file is the one-time Apple→CoCo3 *converter*, not the sprite *tool*; and the tool does express opaque black, via the `opacity.s` sidecar. The correct model is in `sprite_tool/opacity.py` and `sidecar.py`. I rebuilt the POC's input model around the real contract, which is why AC6 could be exercised on **authored** data instead of a synthetic hack. Root cause: I characterised a capability from a doc header rather than the tool's actual outputs — the PA.6 stale-comment failure in a new costume.

**6.2 — PA.7's cost does not transfer to POP's art. (The finding this dispatch existed to catch.)**
PA.7's 4.09 cy/byte was counted correctly, on an artifact whose *structure* is unrepresentative: ~22% mixed bytes vs POP's **68.9%**. Real POP draw cost is **1.57× higher**. Feasibility survives but the p90 frame slips to marginal. Captured as a pool candidate, with the observation that mixed-byte fraction was computable in advance from the pixel grid alone — no compiler needed.

**6.3 — POP's cels currently contain NO opaque black.** They are HGR 1bpp masks: every OFF pixel is transparent by construction, so the opacity plane is empty for all 12 POP samples. Opaque black is a property the **ported art** may author later (as Karateka's scene-6 backgrounds do), not something POP's source expresses. AC6 was therefore exercised on real Karateka authored cels — which is stronger evidence than a synthetic POP case would have been, but means **the opaque-black path is proven on Karateka data, not POP data**.

**6.4 — Opaque black is cheaper, not dearer.** Unexpected: applying the sidecar *reduced* cycles in every case (249→202, 170→162, 68→58, 62→40). Marking a black pixel opaque removes it from the transparency mask, which collapses mixed bytes into stores. Flagged because it inverts the intuition that opacity work costs performance — for compiled sprites it buys performance.

**6.5 — The erase cost is scaled, not measured.** I compiled and measured only the **draw**. The erase figure (8.55 cy/byte) is PA.7's counted erase scaled by the same 1.57× structural factor. Defensible — the erase writes the same footprint with the same byte classes — but it is **modelled, not measured**, and is ~57% of the blit term.

**6.6 — The HGR→4-colour rendering is a structural stand-in**, per §5.1: ON pixels get an opaque index by a simple run rule (interior→white, edge→chroma by parity), OFF→transparent. It echoes `sprite_convert.py`'s shape without claiming its validated colour model. **This affects colour values but not byte classes** — which token an opaque pixel gets does not change whether its byte is store/skip/mixed — so the cost finding is insensitive to it. Final art is a later Jay decision.

**6.7 — The compiler is a prototype, and a better one would be cheaper.** It emits PSHU bursts of 6/4/2 with register reuse, but does not: reuse register values *across rows* as aggressively as Glen's, coalesce adjacent mixed bytes into 16-bit RMW, or exploit `ORA`-only merges where the background under mixed bytes is known-zero (Glen's file does this). **The measured 6.44 is therefore an upper bound on what a production compiler would achieve** — the real number can only improve.

**6.8 — No idiom filed; eighth deferral.** No emulator ran. The queue behind the authorship ruling is unchanged.

---

### 7 — Uncertainty flags

1. **The erase is modelled, not measured** (§6.5) — the single largest unmeasured term in the re-check.
2. **6.44 is an upper bound** (§6.7); a production compiler with cross-row register reuse and 16-bit RMW would land lower, possibly materially.
3. **Opaque-black proven on Karateka cels, not POP cels** (§6.3) — POP has none authored yet.
4. **12-cel sample.** Spans large/median/thin across four tables, but 12 of ~600. The mixed fraction ranged 43%–79% across samples; a different sample could shift the aggregate several points.
5. **`k` remains unmeasured** and now matters more: at 6.44 the p90 frame is marginal at k=1.0 and fails above it.
6. **The simulator models the instructions I emit**, not a real 6809 — it is a soundness check on the compiler's *logic*, not a hardware verification. A MAME render would be strictly stronger.
7. **Cel-local addressing only.** The prototype computes offsets from a cel-local origin; a real blit needs screen-address setup and clipping, neither costed.

---

### 8 — Follow-up candidates

**Statement for the gate (§3 deliverable — no decision):**
- **The pipeline is sound.** Tool → compiler → correct 6809 code is demonstrated on real cels from both projects. Jay's "can you actually draw it" question is answered yes.
- **The cost is 1.57× PA.7's**, because POP's art is 3.1× more mixed-byte than the proxy. **Feasibility survives at typical (0.68×–0.92× to k≈1.5) but p90 is marginal at 1.01×.**
- **Opaque black is a performance win**, and the authoring mechanism already exists.
- **Compiled sprites strictly dominate the descriptor approach** — they remove `CannotEncode`, the `_mixed`/`_masked`/`stencil_punch` variants, and their extra passes.

**Ordered follow-ups:**
1. **Measure `k`** — now decisive: it is the difference between a comfortable and a marginal p90 frame.
2. **Compile and measure the ERASE** (§6.5) — 57% of the blit term is currently scaled, not counted.
3. **Improve the prototype's codegen** (§6.7) to bound how much of the 1.57× is POP's art vs my emitter — cross-row register reuse and 16-bit RMW are the two obvious wins.
4. **Widen the cel sample** (§7.4) and report the mixed-fraction distribution across all ~600 cels — cheap, no compiler needed.
5. **Decide whether the production compiler should accept `CannotEncode` opacity** (AC7) — compiled sprites can express what the runtime descriptors cannot.
6. Standing: idioms-authorship ruling; `POP-idioms-coco3-markers.md`; `.gitattributes`; `.vscode/`.

---

### 9 — User interaction during task

**Two corrections from Jay, both mid-task and both material.**
1. *"check the tool again… it only creates an opaque 'sidecar' if there are opaque pixels — i think you missed the sidecar."* Correct — I had. I found `sprite_tool/sidecar.py` + `opacity.py`, rebuilt the POC's input model, and AC6 is exercised on authored data as a result.
2. *"you should be looking at the 'sprite tool' not the 'sprite converter' — different tools, different function."* Correct — I had conflated `sprite_convert.py` (one-time Apple→CoCo3 conversion) with `harness/tools/sprite_tool/` (the authoring tool, stage-1 producer). AC7 is answered against the right tool.

Both are recorded in §6.1 rather than silently absorbed.

---

### 10 — Candidate(s) captured this task

One new `live/` row, pool commit `db9c5dc`:
- `seeds/POP/live/2026-07-25-a-proxy-artifacts-structure-not-just-its-size-drives-the-cost.md` — when a cost is measured on a proxy, validate the proxy's **structure**, not just its dimensions; a perfectly-counted cost model can rest on an unrepresentative artifact, and the error survives *because* the counting was correct. `initiator: orchestrator` (the dispatch was framed to catch exactly this).

---

### 11 — Commit

- **This report + `poc/compiled-sprite/`** — on `wip`, pushed to `origin/wip` before reporting back. Hash in the accompanying reply.
- **No prod/engine/HAL/content commit.** **Pool:** `db9c5dc`.

---

## Appendix — aggregate, verbatim

```
=== AGGREGATE (POP cels, n=12) ===
  SOUNDNESS            : ALL PASS
  footprint bytes      : 3,191   drawn 1,323   skipped 1,868 (59%)
  mixed / drawn        : 911 / 1,323 = 68.9%
  cycles               : 20,539
  cy/byte (footprint)  : 6.44     <- vs PA.7 Glen proxy 4.09 (draw only)
  cy/byte (drawn only) : 15.52

PA.7 (Glen proxy) draw 4.09 + erase 5.43 = 9.52 cy/footprint-byte
PA.9 (real POP)   draw 6.44 -> 1.57x worse; erase scaled 8.55 -> draw+erase 14.99
POP cel (264 B): draw 1,700 cy | draw+erase 3,957 cy
frame blit: typical 17,099 cy (PA.7 said 10,860) | p90 27,730 cy (PA.7 said 17,612)
blit share of typical frame: 14.0%  (PA.7 said 9.4%)
vs PA.6's ~52 cy/byte break-even: 14.99 -> still 3.5x better
```

*End of report.*
