## Form B Report — PA.8 — worst-scene peak 64KB-window footprint: does code + graphics + framebuffer fit?
**Class:** recon / analysis — SOURCE + ARITHMETIC ONLY. wip. **Prod byte-identity: N/A.**

> ## VERDICT: **4-colour FITS. 16-colour is forced out on memory geometry.**
> **The worst scene is smaller than feared:** POP has exactly **two** character slots (`Char*` / `Shad*`) — one-on-one by construction. Max simultaneous drawn cels, measured in PA.6: **9 median, 12 p90, 29 absolute max.**
> **4-colour, back buffer mapped:** engine 20,347 B leaves **28,293 B = 24 cels** resident. Median and p90 frames fit **fully resident**; only the 29-cel max frame needs a mid-frame bank, costing **0.16%** of the cycle budget.
> **16-colour: both buffers mapped consumes 8 of 8 MMU slots — arithmetically impossible.** Back-buffer-only leaves **11,909 B = 5.1 cels**, which cannot hold even a *median* frame's 20,916 B working set.
> **The engine is not the problem, and the raw scaling said it was.** POP's total object is 43,480 B (2.4× Karateka) — but 9,845 B is Apple-specific code the port *replaces* and 5,761 B is demo/title. **Resident core = 20,347 B = 1.13× Karateka's verified engine.**

---

### 0 — Receipt / status (C-35 stamp)

```
t0=2026-07-25T19:35:52Z
```

**HEAD at t0:** `16135e6a338ff10d14b5b65a9c8c4e0c1eab96eb` (branch `wip`, no tracked file modified).
**HEAD at report time:** same — this dispatch produced no commit other than the report.

**§10 hard-stop gate — PASS:** vendored source last touched by `ba6154e` (P1.1a, `ec78dbf`); `PROVENANCE.md` pin confirmed. No `.hdv` md5 gate — no oracle run (source + arithmetic only).

**§0(a).3 Karateka read access — PRESENT locally**, all three named docs: `asset-storage-bytes.md` (2,859 B), `hal.md` (26,089 B), `conventions.md` (44,092 B), plus `memory-map.md` which carries the actual map (§6.1).

**`git status` at end:** no tracked file modified; 18 untracked (standing 16 + `POP-idioms-coco3-markers.md` + `.vscode/`).

Calibration-light per CLAUDE.md §1/§5. No elapsed, no band, no variance.

---

### 1 — Summary

**The worst scene is bounded by design, not by capacity.** `GAMEEQ.S` declares exactly two mirrored character slots — `Char*` (15 variables) and `Shad*` (16) — with `ShadCtrl` documented as "Opponent control module". POP is one-on-one by construction; `maxobj=20`/`maxmid=46` are list capacities, not achievable actor counts. The operative numbers are PA.6's measured per-frame draws: **9 median, 12 p90, 29 max**.

**Karateka's envelope, verified not cited.** Per §10 I checked the engine figure against the artifact rather than the doc: `build/karateka.bin` is **17,978 bytes** — confirmed. The memory map came from `memory-map.md` §3.2 and `gfx.s` equates, not prose: **8 MMU slots × 8 KB**, DP `$0000-$00FF`, stack `$0100-$01FF`, framebuffers `$8000-$BBFF` and `$C000-$FBFF` (15,360 B each).

**One structural fact reframes the whole question.** `HAL_gfx_present` performs a real **VOFFSET swap** — the displayed buffer is chosen by a GIME *physical* video-address register, not by the CPU's MMU window. So **only the back buffer must be CPU-addressable**. Karateka maps both as a layout choice; POP need not. In 4-colour that converts 4 framebuffer slots into 2, freeing 16 KB.

**The engine estimate nearly produced a false negative.** Scaling POP's total object code (43,480 B, measured) against Karateka's 17,978 gives "2.4×", and at any plausible density (39–56 KB) the engine alone exceeds the non-framebuffer window — **infeasible before a single sprite**. Classifying by module corrects it: **9,845 B is Apple-specific code the port replaces** (HIRES blitter → compiled sprites, HRTABLES → CoCo3 geometry, UNPACK, RW18525 disk, GRAFIX draw-manager → HAL), **5,761 B is demo/title/copy-protection** not resident during play, and 5,744 B is bankable tables. **Resident core = 20,347 B = 1.13× Karateka's whole engine** (§6.2).

**Result.** 4-colour with the back buffer mapped: 49,152 B non-framebuffer, minus 512 B DP/stack, minus the engine → **28,293 B for sprites = 24 cels**, against a per-frame need of 9–12. **Fits resident.** 16-colour: both buffers is arithmetically impossible (8/8 slots); back-buffer-only leaves 11,909 B = **5.1 cels**, below even a median frame's 20,916 B. **The memory axis independently forces the same conclusion the cycle axis reached in PA.5.**

---

### 2 — Files modified

**None in `POP3_port` except this report.** No engine/HAL/MMU code, no sprite compiler, no source or idioms change. `/c/mame`, Karateka (read-only) and the probe clone untouched.

**Pool:** one new `live/` row, `571db7a` (§10).

---

### 3 — Reasoning

**Why the framebuffer question is the hinge, and how it was settled.** The naive decomposition charges the window for *both* framebuffers because that is what Karateka's map shows. But `gfx.s` documents `HAL_gfx_present` as "P2.3a.6-followup-1 implemented real VOFFSET swap", and `conventions.md` §139-140 describes the page register as selecting which buffer is *displayed*. VOFFSET is a GIME register addressing **physical** RAM; the CPU's view is the MMU's. Therefore the front buffer needs no CPU slot at all — it only needs to exist in physical memory for the video hardware to scan. This is not a proposal, it is what the existing verified code already does; Karateka maps both because its budget allows it.

The consequence is arithmetic: at 2bpp a framebuffer is 15,360 B → **2 slots**; mapping one instead of two frees **16,384 B**, which is the difference between 24 cels of sprite headroom and none.

**Why the module classification is the load-bearing step.** A port carries *logic* and re-implements the *platform contact surface*. In POP's 43,480 B those surfaces are large and unambiguous: `HIRES` (2,640) is the Apple blitter that compiled sprites replace outright; `HRTABLES` (2,492) is a table of Apple hi-res scanline addresses, meaningless on CoCo3 geometry; `RW18525` (1,272) is the Apple disk routine; `UNPACK` (933) is the Apple image unpacker; `GRAFIX` (2,508) is the draw-manager whose CoCo3 equivalent is the HAL. `AUTO` (2,509, attract demo), `MASTER` (1,922, title sequence) and `SPECIALK` (1,330, copy protection) are not resident during gameplay. That is **15,606 B — 36% of the total — that never occupies the play-time window.** Scaling the unclassified total is what produced the infeasible verdict; the classified core is 1.13× Karateka's engine, and Karateka is a *shipping* port on this exact substrate.

I have labelled the classification honestly: the clear cases (blitter, address tables, disk, demo, title) are most of it; the arguable middle (how much of the draw manager survives, whether a table banks) is small relative to the total.

**Why banking is free in time but the wrong question in space.** A CoCo3 MMU remap is a store to `$FFAx` — `STA extended` = 5 cycles. Even remapping once per cel drawn at the 29-cel maximum costs ~290 cycles, **0.16%** of the 178,968-cycle budget. Banking therefore never fails on time. What it can fail on is *granularity*: the MMU maps 8 KB blocks, so a bank swap brings in ~7 cels' worth of compiled sprite whether or not they are wanted, and mid-frame remapping requires the drawing code and the sprite data not to occupy the same slot. Those are design constraints to note, not costs to pay.

**Why the 16-colour result is a genuine forcing, not a preference.** At 4bpp a framebuffer is 30,720 B = **4 slots**. Two buffers = 8 slots = the entire 64 KB window, leaving nothing for code, stack or sprites — not tight, *impossible*. Mapping only the back buffer leaves 4 slots (32,768 B); after 512 B DP/stack and a 20,347 B engine that is 11,909 B, while a median frame's nine cels at 4bpp need 20,916 B. **16-colour cannot hold one median frame's working set even with a lean engine and one mapped buffer.** This is independent of PA.5's cycle-based elimination and reaches the same place.

---

### 4 — Verification (AC-by-AC)

**AC1 — worst scene identified from source, with actor count. — MET.**
Method: read the character-slot model from `GAMEEQ.S` rather than inferring from list caps. It declares exactly two mirrored slots:
```
GAMEEQ.S:567-581   CharPosn/CharX/CharY/CharFace/CharBlockX/CharBlockY/CharAction/
                   CharXVel/CharYVel/CharSeq/CharScrn/CharRepeat/CharID/CharSword/CharLife   (15)
GAMEEQ.S:618-631   ShadPosn/ShadX/ShadY/ShadFace/ShadBlockX/ShadBlockY/ShadAction/
                   ShadXVel/ShadYVel/ShadSeq/ShadScrn/ShadRepeat/ShadID/ShadSword           (16)
TOPCTRL.S:711      jsr ShadCtrl ;Opponent control module
```
**Max simultaneous actors = 2** (kid + one opponent). `maxobj=20`, `maxmid=46`, `maxpeel=46` (`EQ.S:294-299`) are list capacities, not reachable actor counts — PA.6 measured `mid` max 13 and total draws max 29 across 948 demo steps.
**The worst presentable scene is therefore a two-actor fight in a busy room.** Its operative size is PA.6's measured draw count: **9 median / 12 p90 / 29 max cels per frame.**

**AC2 — distinct simultaneous cel set, method + precision. — MET, labelled estimate.**
Parsed `SEQTABLE.S` for frame IDs (positive values; negatives are opcodes `goto`/`act`/`die`…): **222 distinct frame IDs referenced across all sequences** (range 1–240); combat-named sequences (`guy3`–`guy9`) reference **27 distinct frames**.
**Precision: the per-sequence parse is unreliable** — only 25 named sequences resolved and continuation lines merge into their predecessor (e.g. `sjland` absorbed 127 frames), so per-sequence counts are not trustworthy. The **aggregate** (222 distinct IDs) and the combat subset (27) are robust because they are set-unions, insensitive to boundary errors. Scenarios costed at PA.7's compiled size (1,162 B/cel at 2bpp; 2,324 B at 4bpp):
```
  one frame's draws, median (PA.6)      9 cels =  10,458 B (4-col) |  20,916 B (16-col)
  one frame's draws, p90               12 cels =  13,944 B         |  27,888 B
  one frame's draws, MAX               29 cels =  33,698 B         |  67,396 B
  combat working set ~27 x 2 actors    54 cels =  62,748 B         | 125,496 B
  kid full 213 + one opponent 32       245 cels = 284,690 B         | 569,380 B
```
**The binding figure is the per-frame draw count, not the library** — with per-cel banking costing 0.05–0.16% of budget (AC5), only what a frame draws must be addressable.

**AC3 — Karateka reals extracted and verified. — MET, verified not cited (§10).**
```
prod engine     : build/karateka.bin = 17,978 B      VERIFIED by wc -c against the artifact
                  (asset-storage-bytes.md:37 claims 17,978 "confirmed" — checked, matches)
MMU granularity : 8 slots x 8 KB                     memory-map.md §3.2
DP              : $0000-$00FF, 256 B                 memory-map.md §4.1 / :27
stack           : $0100-$01FF, 256 B                 memory-map.md §4.2 :121-123
framebuffer A   : $8000-$BBFF, 15,360 B (slots FFA4/FFA5 = $3C/$3D)   gfx.s:73,146; memory-map.md §3.2
framebuffer B   : $C000-$FBFF, 15,360 B (slots FFA6/FFA7 = $3E/$3F)   gfx.s:74,157
GIME mode       : $FF90=$4C — all-RAM, ROM unmapped $8000-$FEFF        hal.md:550-551
page-flip       : real VOFFSET swap (physical video address)           gfx.s:40
transparency    : 2bpp, 4 px/byte, index 0 = transparent               asset-storage-bytes.md:48-53 (HS-B3)
```
**Note:** the dispatch cites "`hal.md` §4.8-4.9" for the framebuffer/MMU map. `hal.md` §4 is *Data Formats* (4.1–4.3) and has no §4.8-4.9; that reference appears only inside a citation table at `hal.md:684` pointing to `memory-map.md §4.8-4.9`. The real map is in `memory-map.md` §3.2/§4.1/§4.2 and in `gfx.s`. Reported as a dispatch inaccuracy (§6.1), not treated as a blocker.

**AC4 — peak-window decomposition, both modes, with margin. — MET.**
```
framebuffer: 4-colour 15,360 B = 2 slots | 16-colour 30,720 B = 4 slots

layout                                            fb slots   free for code+data+sprites
4-colour, BOTH buffers mapped (Karateka layout)       4        4 slots = 32,768 B
4-colour, back buffer only mapped                     2        6 slots = 49,152 B
16-colour, BOTH buffers mapped                        8        0 slots = 0 B  *** IMPOSSIBLE ***
16-colour, back buffer only mapped                    4        4 slots = 32,768 B
```
With DP+stack 512 B and the **resident core 20,347 B** (§6.2):
```
=== 4-colour, back buffer only (49,152 B free) ===
  engine  20,347 (core x1.0)          -> sprite space 28,293 B = 24.3 cels
  engine  24,416 (core x1.2)          -> sprite space 24,224 B = 20.8 cels
  engine  30,520 (core+HAL+slack x1.5)-> sprite space 18,120 B = 15.6 cels

=== 16-colour, back buffer only (32,768 B free) ===
  engine  20,347 (core x1.0)          -> sprite space 11,909 B =  5.1 cels
  engine  24,416 (core x1.2)          -> sprite space  7,840 B =  3.4 cels
  engine  30,520 (core+HAL+slack x1.5)-> sprite space  1,736 B =  0.7 cels
```
**4-colour: FITS.** Median (9 cels, 10,458 B) and p90 (12 cels, 13,944 B) frames are fully resident even at the ×1.5 engine. **Margin at core×1.2: 24,224 B against a 13,944 B p90 need = 10,280 B spare (74% headroom).**
**16-colour: DOES NOT FIT.** Both-mapped is impossible; back-buffer-only cannot hold a median frame (needs 20,916 B, has 11,909 B) and has effectively nothing at a realistic engine size.

**AC5 — swap boundary and its cycle cost. — MET.**
Needed only for the **29-cel maximum frame** in 4-colour (33,698 B against 24,224 B resident) and for **every frame** in 16-colour.
**Boundary:** the natural split is compiled-sprite banks in one or two 8 KB slots (≈7 cels per slot at 1,162 B), remapped between draws; engine, DP/stack and the back buffer stay fixed. **Cost:** a remap is `STA extended` to `$FFAx` = **5 cycles**.
```
   9 cels/frame x ~10 cy (remap + bookkeeping) =  90 cy = 0.05% of 178,968
  29 cels/frame x ~10 cy                       = 290 cy = 0.16% of 178,968
```
**Banking never fails on time.** Its real constraints are granularity (an 8 KB swap brings ~7 cels whether wanted or not) and the requirement that drawing code and sprite data not share a slot — design constraints, noted not solved (§6).

**AC6 — half-for-code check. — MET.**
```
                        non-fb window   engine        engine share
Karateka (verified)     32,768 B        17,978 B      55%
POP 4-col back-fb-only  49,152 B        20,347 B      41%   (24,416 -> 50%)
```
**POP's engine is 1.13× Karateka's** and lands at 41–50% of its non-framebuffer window — i.e. **the ~half-for-code target holds**, and holds more comfortably than Karateka's own split because mapping one buffer instead of two widens the window. This is the finding the raw 2.4× scaling would have hidden (§6.2).

**AC7 — transparency note. — MET.**
Karateka's HS-B3 (`asset-storage-bytes.md:48-53) confirms 2bpp / 4 px per byte with **index 0 designated transparent**, "a stored 2-bit value like any other" — so PA.7's ~9.52 cy/byte compiled cost holds in 4-colour, and a clean cel costs the same bytes as a fringed one.
**Can POP's cels live with 3 opaque + 1 transparent? Yes, comfortably.** POP's gameplay cels are Apple **HGR 1bpp** — `HIRES.S:184-186` defines the format as `width (bytes) / height (lines) / image bytes`, with `OFFSET` documented as "# of bits to shift image right (**0-6**)", i.e. **7 pixels per byte, one bit each**. A POP sprite is a 1-bit mask; it needs at most **two** opaque values plus transparency. Three opaque indices is more than the source format can express. (The 16-colour finding of PA.2 concerned DHGR *title screens*, not gameplay cels.)

**AC8 — no source/engine/HAL/content/coco3 change; status clean except standing untracked. — MET.**

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output — APPLIES, satisfied.** Verified `wc -c build/karateka.bin` = 17,978; POP module object sizes from the P1.1 build; the `GAMEEQ.S`/`EQ.S`/`HIRES.S` greps; the `SEQTABLE.S` parse; and all decomposition arithmetic — quoted in §4 and the appendices.

**25.2 — N/A.** Nothing built or imaged. **25.3 — N/A as a gate.** Byte counts and source analysis; no appearance claim.

**C-35 presence check — SATISFIED.** §0 quotes verbatim `t0=2026-07-25T19:35:52Z` and HEAD.

**Capture presence check — SATISFIED.** §10 carries one slug.

---

### 6 — Reactive deviations

**6.1 — The dispatch's `hal.md` §4.8-4.9 reference does not resolve.** `hal.md` §4 is *Data Formats* (4.1 Sprite, 4.2 Palette, 4.3 Sound); there is no §4.8 or §4.9. The string appears only at `hal.md:684`, inside a citation table pointing at **`memory-map.md` §4.8-4.9**. The actual map I used is `memory-map.md` §3.2 (MMU slot table), §4.1 (DP), §4.2 (stack), plus the `gfx.s` equates. Reported rather than silently substituted, since the dispatch presented it as ground truth.

**6.2 — Raw scaling gave INFEASIBLE; module classification gave FEASIBLE. (The methodological finding.)**
POP's total object is 43,480 B = 2.4× Karateka's verified 17,978. At 0.9–1.3× code density that is 39–56 KB — exceeding the non-framebuffer window in every layout, before any sprite. **That verdict is wrong**, because 36% of the total never occupies the play-time window: 9,845 B is Apple-specific code the port *replaces* (`HIRES`, `HRTABLES`, `UNPACK`, `RW18525`, `GRAFIX`), 5,761 B is demo/title/copy-protection (`AUTO`, `MASTER`, `SPECIALK`), 5,744 B is bankable tables. **Resident core = 20,347 B = 1.13× Karateka.** Captured as a pool candidate — and noted there that a *pessimistic* estimate is the more dangerous kind in a feasibility gate, because "infeasible" ends the investigation and nobody re-checks a number that told them to stop.

**6.3 — Only the BACK buffer needs a CPU slot; this is decisive and was not in the dispatch's decomposition.**
§1's template charges the window for "framebuffer (visible)". Since `HAL_gfx_present` swaps by **VOFFSET** (a GIME physical video-address register), the displayed buffer needs no MMU slot. Mapping one buffer instead of two frees **16,384 B in 4-colour** — the difference between 24 cels of headroom and 8. Karateka maps both; POP need not. Reported as an arithmetic consequence of existing verified code, **not** proposed as a design (§6 forbids that).

**6.4 — 16-colour with both buffers mapped is arithmetically impossible**, not merely tight: 4 slots per 4bpp buffer × 2 = 8 of 8. Worth stating flatly because prior dispatches discussed 16-colour as a cost tradeoff; on this axis it is a hard geometric exclusion.

**6.5 — The `SEQTABLE.S` per-sequence parse is unreliable** (§4 AC2): continuation lines merge into the preceding label, so `sjland`'s "127 distinct frames" is an artifact. Only the set-union figures (222 total, 27 combat) are used, because unions are insensitive to boundary errors. Flagged rather than presented as clean.

**6.6 — The worst scene came out *smaller* than the dispatch anticipated.** §2(a) asked me to "confirm the true max (some rooms/fights may have more)". The source answer is that POP structurally cannot exceed two characters — there is no third slot to spawn into. That makes `maxobj=20` a list capacity for *objects* (tiles, debris), not actors, and it removes the "crowded fight" scenario from consideration entirely.

**6.7 — No idiom filed; seventh consecutive deferral.** Nothing here is oracle instrumentation (no emulator ran). The five techniques queued from prior dispatches remain behind the outstanding authorship ruling.

---

### 7 — Uncertainty flags

1. **The resident-core figure is a classification, not a measurement.** 20,347 B is the sum of POP's *6502* modules judged to carry across; the actual 6809 resident core could differ by the code-density factor (unmeasured — the same `k`-adjacent gap) and by how much of the draw manager survives.
2. **No CoCo3 HAL is included in the 20,347.** Karateka's HAL is *inside* its 17,978, so POP's total resident code is core + HAL. The ×1.2/×1.5 rows are intended to cover this but are not derived.
3. **PA.7's compiled-cel size (1,162 B) carries its own estimate** — an exact instruction count times an assumed 2.5 bytes/instruction (PA.7 §7.3). A ±25% error moves the 24-cel headroom to 19–32 cels.
4. **Cel sizes are the PA.3 median.** The 90th-percentile cel is ~59% larger, so a frame of large cels needs proportionally more resident space; the 74% margin at p90 absorbs this but was not modelled explicitly.
5. **8 KB MMU granularity is coarse relative to a 1,162 B cel** — a bank holds ~7 cels, so real packing efficiency depends on which cels co-locate. Not modelled.
6. **Working RAM is not separately budgeted.** Karateka reserves `$6000-$7FFF` for working RAM + trace buffer; POP needs peel/save buffers (the Apple used 2 KB `peelbuf`). This comes out of the sprite space and is not deducted above — it would reduce 24 cels to roughly 22.
7. **`.vscode/` remains an unruled 18th untracked path.**

---

### 8 — Follow-up candidates

**Fit verdict, three ways (§1 / §3 deliverable — statement only):**

1. **Whole engine resident + worst-scene graphics — YES in 4-colour, NO in 16-colour.** 4-colour with the back buffer mapped holds the engine plus a **24-cel** sprite working set against a 9–12 cel per-frame need — median and p90 frames fully resident, 74% headroom at p90. 16-colour cannot hold a median frame even with a lean engine, and both-buffers-mapped is arithmetically impossible.
2. **Swap fallback — needed only for the 29-cel max frame in 4-colour, and it is essentially free:** ~290 cycles = **0.16%** of budget. Its real constraints are 8 KB granularity and slot co-residency, not time.
3. **Half-for-code — holds.** POP's engine is 41–50% of its non-framebuffer window vs Karateka's proven 55%.

**The memory axis independently confirms the cycles axis.** PA.5 eliminated 16-colour on cycles; PA.8 eliminates it on address-space geometry. Two unrelated constraints, same answer — **4-colour is the mode**, and it is no longer a close call on either axis.

**Ordered follow-ups:**
1. **Measure `k`** — still the single unmeasured determinant (PA.7), and it now also governs the resident-core size estimate (§7.1).
2. **Jay's alignment decision** (PA.6a/PA.7) — unaffected by this report; sub-byte's 4× memory cost lands in *banked* storage, not the 64 KB window, so it does not change this fit.
3. **Budget working RAM explicitly** (§7.6) — peel/save buffers come out of the same 49,152 B.
4. **Confirm the module classification** (§6.2/§7.1) with a port-plan pass over the carried/replaced boundary.
5. **Rule once on idioms-file authorship** (§6.7) — five techniques queued.
6. Standing: `POP-idioms-coco3-markers.md` disposal; POP-level `.gitattributes`; `.vscode/` disposition.

---

### 9 — User interaction during task

**None during execution.** Jay's framing (peak simultaneous 64 KB commitment, not disk/library size) set the analysis. Every judgment call — verifying the engine figure against the binary rather than the doc, the back-buffer-only observation, the module classification, and the unreliable sequence parse — is surfaced in §6 for post-hoc ruling.

---

### 10 — Candidate(s) captured this task

One new `live/` row, pushed in pool commit `571db7a`:

- `seeds/POP/live/2026-07-25-a-port-size-estimate-must-exclude-what-the-port-replaces.md` — a port's size estimate scaled from the original's total must first subtract what the port *replaces*; platform-specific code is not part of the payload, and including it flipped this feasibility verdict from infeasible to feasible. `initiator: executor`.

`seeds/POP/live/` now holds **twenty-four** POP rows.

---

### 11 — Commit

- **This report's commit** — on `wip`, pushed to `origin/wip` before reporting back. Hash in the accompanying reply.
- **No other `POP3_port` commit** — analysis only, per §9.
- **Pool:** `571db7a`.

---
---

## Appendix A — Karateka's proven 64 KB map (verified)

```
$0000-$00FF  Direct page (DP)                256 B     memory-map.md §4.1
$0100-$01FF  Stack                           256 B     memory-map.md §4.2
$0200-$1FFF  Engine code start   FFA0=$38  ]
$2000-$3FFF  Engine continued    FFA1=$39   |  32,768 B low window
$4000-$5FFF  HAL code + data     FFA2=$3A   |  (4 MMU slots)
$6000-$7FFF  Working RAM + trace FFA3=$3B  ]
$8000-$9FFF  Frame buffer A 1st  FFA4=$3C  ]  Frame A $8000-$BBFF = 15,360 B
$A000-$BFFF  Frame buffer A 2nd  FFA5=$3D  ]
$C000-$DFFF  Frame buffer B 1st  FFA6=$3E  ]  Frame B $C000-$FBFF = 15,360 B
$E000-$FFFF  Frame buffer B 2nd  FFA7=$3F  ]
$FF90=$4C : GIME all-RAM, ROM unmapped $8000-$FEFF, $FExx locked   hal.md:550-551

$ wc -c build/karateka.bin
17978   <- VERIFIED against the artifact, not cited from the doc
```

## Appendix B — POP module classification (measured object bytes)

```
POP total 6502 object (P1.1 build): 43,480 B

RESIDENT CORE (game logic, every frame)        20,347 B
  TOPCTRL 2,053 | CTRL 2,827 | CTRLSUBS 2,315 | COLL 1,790 | MOVER 2,672
  FRAMEADV 3,366 | SUBS 2,418 | GAMEBG 1,570 | MISC 1,336
BANKABLE DATA (tables)                          5,744 B   SEQTABLE 2,558 | FRAMEDEF 2,013 | TABLES 1,173
REPLACED by CoCo3 HAL / compiled sprites        9,845 B   HIRES 2,640 | HRTABLES 2,492 | GRAFIX 2,508
                                                          UNPACK 933 | RW18525 1,272
NOT RESIDENT during play                        5,761 B   AUTO 2,509 | MASTER 1,922 | SPECIALK 1,330

resident core 20,347 vs Karateka's whole verified engine 17,978  ->  1.13x
raw total     43,480 vs 17,978                                   ->  2.4x   (the misleading figure)
```

## Appendix C — the decomposition, verbatim

```
framebuffer: 4-colour 15,360 B = 2 slots | 16-colour 30,720 B = 4 slots   (MMU = 8 slots x 8 KB)

layout                                            fb slots   free
4-colour, BOTH buffers mapped (Karateka's layout)     4      4 slots = 32,768 B
4-colour, back buffer only mapped                     2      6 slots = 49,152 B
16-colour, BOTH buffers mapped                        8      0 slots = 0 B  *** IMPOSSIBLE ***
16-colour, back buffer only mapped                    4      4 slots = 32,768 B

=== 4-colour, back buffer only (49,152 B free, minus 512 B DP/stack) ===
  engine  20,347 (core x1.0)           -> sprite space 28,293 B = 24.3 cels
  engine  24,416 (core x1.2)           -> sprite space 24,224 B = 20.8 cels
  engine  30,520 (core+HAL+slack x1.5) -> sprite space 18,120 B = 15.6 cels

=== 16-colour, back buffer only (32,768 B free) ===
  engine  20,347 (core x1.0)           -> sprite space 11,909 B =  5.1 cels
  engine  24,416 (core x1.2)           -> sprite space  7,840 B =  3.4 cels
  engine  30,520 (core+HAL+slack x1.5) -> sprite space  1,736 B =  0.7 cels

=== per-frame need (PA.6 measured draws x PA.7 compiled size) ===
  median frame   9 cels =  10,458 B (4-col) |  20,916 B (16-col)
  p90 frame     12 cels =  13,944 B         |  27,888 B
  max frame     29 cels =  33,698 B         |  67,396 B

=== MMU remap cost (banking in time) ===
  STA extended to $FFAx = 5 cy
   9 cels/frame x ~10 cy =  90 cy = 0.05% of 178,968
  29 cels/frame x ~10 cy = 290 cy = 0.16% of 178,968
```

---

*End of report.*
