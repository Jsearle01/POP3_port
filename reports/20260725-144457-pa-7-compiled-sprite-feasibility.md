## Form B Report — PA.7 — does the compiled-sprite blit make the port feasible?
**Class:** recon / measurement — CYCLE-COUNT + ESTIMATE ONLY. wip. **Prod byte-identity: N/A.**

> ## VERDICT: **FEASIBLE.** Compiled sprites close the gap with room to spare.
> **N2c, counted from Glen Hewlett's real sprite:** draw **4.09** cy/footprint-byte, erase **5.43**, **draw+erase 9.52** — against PA.6's ~52 cy/byte break-even, that is **5.5× better than required** and **16× cheaper** than the inherited masked loop.
> **The blit stops being the problem.** It falls from ~99% of the frame to **9.4%**. Typical frame: **0.65× budget at k=1.0, 0.88× at k=1.4.**
> **The bottleneck has moved to `k`** — the 6502→6809 logic scaling, still never measured. At k=1.8 typical fails (1.12×), and p90 fails at k≥1.4. Everything now turns on a number nobody has measured across four dispatches.
> **Memory (§5.23, now answerable):** byte-aligned working set **278 KB → a 512K CoCo3**. Sub-byte 4-phase **1.1 MB → 2M+**.

---

### 0 — Receipt / status (C-35 stamp)

```
t0=2026-07-25T18:39:17Z
```

**HEAD at t0:** `3e18f5d5a685a30879d6b8721910e34189012840` (branch `wip`, no tracked file modified).
**HEAD at report time:** same — this dispatch produced no commit other than the report.

**§10 hard-stop gate — PASS:**
```
vendored source last touched by : ba6154e "P1.1a: vendor oracle buildable-whole @ ec78dbf"
PROVENANCE pin                  : ec78dbfd51013ba349cda8c51c3ce0595fe75342
```
**No `.hdv` md5 gate** — no oracle run this dispatch (cycle-count only, per §0(a).2).
**§0(a).3 Glen's reference: REACHABLE.** `raw.githubusercontent.com/nowhereman999/CoCo-3-Scan-Line-Demo/master/000061.bmp.asm` → HTTP 200, 21,025 bytes. **The real file was counted; no fallback to the documented figure was needed.**

**`git status` at end:** no tracked file modified; 18 untracked (standing 16 + `POP-idioms-coco3-markers.md` + `.vscode/`).

Calibration-light per CLAUDE.md §1/§5. No elapsed, no band, no variance.

---

### 1 — Summary

**The technique works, and the margin is large.** Glen's `000061.bmp.asm` contains **both** halves — `_000061.bmp:` (draw) and `_Restore_000061.bmp:` (erase) — so §2(c)'s erase requirement is answered from the same artifact rather than modelled. Counted: draw **736 cycles**, erase **978 cycles**, **1,714 total** for a 20×18 sprite with a 180-byte footprint.

**Per byte: 4.09 (draw) / 5.43 (erase) / 9.52 (draw+erase).** PA.6 established that feasibility requires the blit at or below the Apple's ~52 cy/byte. Compiled sprites come in **5.5× under that**, and **16× cheaper** than the inherited masked loop's 176,948-cycle typical frame.

**The consequence is a category change, not an improvement.** The blit term drops from 176,948 to **10,860 cycles** — from ~99% of the frame to **9.4%**. PA.6's verdict inverts: typical goes from 1.58×–2.86× **over** to **0.65×–0.88× under** at k ≤ 1.4.

**But the constraint has moved, and the new one is unmeasured.** With the blit at 9.4%, the frame is now dominated by PA.5's 6502-measured non-blit remainder scaled by `k`. At k=1.8 the typical frame fails (1.12×) and p90 fails at k ≥ 1.4. **`k` has been flagged as unmeasured in PA.5, PA.6 and PA.6a and is now the single variable feasibility turns on.**

**I did not take the headline figure on trust.** §5.22 records compiled sprites at "~1.8 cy/byte". Counted, the PSHU bursts really do run at 2.04–2.28 cy/byte — the headline is accurate *for the inner loop* — but a production sprite also pays transparent-edge read-modify-write, `LEAU` row-stepping, and the erase. The honest figure is **9.52, 5.2× the headline** (§6.2). The verdict is unaffected; a budget built on 1.8 would have been optimistic by 5×.

---

### 2 — Files modified

**None in `POP3_port` except this report.** No sprite compiler, no engine/HAL/content code, no source or idioms change. No code was copied from Glen's repo — cost model only, per §6. `/c/mame`, Karateka and the probe clone untouched.

**Pool:** one new `live/` row, `57d4d27` (§10).

---

### 3 — Reasoning

**Authority.** N2c is an instruction-level count of a real, published 6809 artifact — 6809 code on the target ISA, so **no `k` is applied to it** (§10). N1 and the non-blit remainder are reused measurements (PA.6, PA.5) and were not re-derived, per §6. The scaling to POP's cel size and the compiled-code-size expansion ratio are modelling, labelled as such in §4 AC7.

**Why the erase had to come from the artifact rather than a model.** §2(c) requires the erase because a frame is erase + draw, and PA.6 measured POP's peel count ≡ mid count — every drawn character is restored next frame. Glen's file happens to contain the matching `_Restore_` routine, so the erase cost is counted, not assumed. It is worth noting that **the erase is more expensive than the draw** (978 vs 736 cycles; 5.43 vs 4.09 cy/byte) — it reads saved background through `LDX`/`LDD` before blasting it back, where the draw pushes immediate data. Any cost model that counted only the draw would understate a POP frame by ~57%.

**How draw and erase were reconciled with PA.6's op counts** (§2(c)). PA.6 counted, per frame: `peel` 2.71, `bg` 2.86, `mid` 2.86, `fg` 0.54 (means). The peel **is** the erase, and PA.6 established `peel ≈ mid` because only moving characters are restored. So the frame's blit term is:
```
  mid (characters)  -> draw + erase
  bg + fg (scenery) -> draw only
```
Counting peels *and* charging draw+erase per character would double-count; that is why the character term uses the combined figure and the scenery term does not.

**Why a parse bug nearly corrupted the count, and how it surfaced.** My first pass stripped assembler comments by splitting on `*` — but `*` is also multiplication, and the row-step instructions look like `LEAU 128*17+6,U`. The operand was truncated to `LEAU 128`, so all 36 `LEAU` instructions were mis-costed as 4 cycles instead of 5–8. It surfaced because the instruction histogram classified `LEAU` as *no-operand* mode, which is impossible for `LEAU` — a structural impossibility rather than an implausible number. Corrected to strip only whitespace-preceded `*`; the draw total moved 715 → 736 cycles. Small in effect, but it would have been invisible had the classifier not carried a mode column.

**What the 5.2× headline gap is made of.** The PSHU burst is the technique's signature and its quoted cost; a real sprite pays three things it omits — transparent-edge RMW (`LDA`/`ORA`/`STA` = 12 cy for one byte), `LEAU` row-stepping once per row, and `LDD`/`STD` pairs for runs shorter than six bytes (4.5 cy/byte). Those scale with *perimeter and row count* while the burst scales with *area*, so the gap is widest on small or thin sprites. POP's cels are mostly-solid figures, close in character to Glen's (78% of footprint opaque), which is why his sprite is a defensible proxy.

---

### 4 — Verification (AC-by-AC)

**AC1 — N2c method + count. — MET.** Counted from `000061.bmp.asm` (fetched, HTTP 200, 21,025 B). MC6809 timings used: indexed base LDA/LDB/STA/STB 4, LDD/STD/LDX/STX 5, LDY/STY 6 (page-2 prefix), LEA 4; indexed extra ,R 0 / 5-bit or 8-bit offset 1 / 16-bit 4 / A,R,B,R 1 / D,R 4 / ,R+ 2 / ,R++ 3; immediate LDA/LDB/ORA/ORB 2, LDD/LDX 3; PSHU/PULU 5+1 per byte; RTS 5.
```
=== DRAW  (_000061.bmp) ===
  instructions 164   CYCLES 736   screen bytes written 141  -> 5.22 cy per byte written
  PSHU bursts  : 67 bytes in 137 cy = 2.04 cy/byte
  mix: LEAU idx x18, STD idx x14, STA idx x14, LDD # x13, STB idx x12, LDB # x12, LDA idx x11, ORA # x11, STX idx x10

=== ERASE (_Restore_000061.bmp) ===
  instructions 153   CYCLES 978   screen bytes written 141  -> 6.94 cy per byte written
  PSHU bursts  : 125 bytes in 285 cy = 2.28 cy/byte
  mix: LDX idx x38, LDD idx x29, PSHU D,X x29, LEAU idx x18, LEAY idx x18, LDA idx x7, STX idx x6, STA idx x4

=== combined (20x18, 4bpp, 180-byte footprint) ===
  draw 736 + erase 978 = 1714 cy ; opaque bytes written 141/180 = 78%
  draw+erase per byte WRITTEN   : 12.16 cy/byte
  draw+erase per FOOTPRINT byte :  9.52 cy/byte
```
**cy/byte for a POP cel** (1,056 CoCo3 px @2bpp = **264 bytes** footprint, PA.3 median): opaque-floor is the PSHU rate **~2.0–2.3**; the **realistic mix is 4.09 draw / 9.52 draw+erase**. Per cel: **draw 1,079 cy; draw+erase 2,514 cy.**

**AC2 — both alignment variants. — MET, with the model stated.**
**Model assumed: pre-shifted phase variants.** Each phase is compiled separately with the pixel data already shifted, so the *draw cost is identical* for aligned and sub-byte — the shift is paid at compile time, in memory, not at runtime. This is how compiled sprites are normally used and is why the alignment question becomes a **memory** question rather than a cycles question (AC6).
- **Byte-aligned:** 1 phase per cel. Draw+erase **2,514 cy/cel**.
- **Sub-byte:** 4 phases per cel at 2bpp (4 px/byte). Draw+erase **2,514 cy/cel** — unchanged — at **4× the compiled memory**.
The alternative model (runtime shift inside the compiled code) was **not** costed: it would reintroduce per-byte shift work and forfeit the technique's entire advantage, which is precisely what PA.6 measured as unaffordable.

**AC3 — erase included and reconciled. — MET.** Counted from `_Restore_000061.bmp:` (978 cy, 5.43 cy/footprint-byte). Reconciled with PA.6's peel count per §3: characters (`mid`) charged draw+erase, scenery (`bg`+`fg`) draw only, so PA.6's separately-counted peel ops are not double-charged.

**AC4 — feasibility verdict. — MET.**
```
frame blit term:
  typical (mid 2.86 draw+erase, bg+fg 3.40 draw) =  10,860 cy
  p90     (mid 4    draw+erase, bg+fg 7    draw) =  17,612 cy
  PA.6 loop-blit typical was 176,948 cy  ->  compiled is 16x cheaper

case           blit  nonblit(k)    k      total   vs budget  verdict
typical      10,860     105,259  1.0    116,119       0.65x  FEASIBLE
typical      10,860     147,363  1.4    158,222       0.88x  FEASIBLE
typical      10,860     189,466  1.8    200,326       1.12x  INFEASIBLE
p90          17,612     153,270  1.0    170,882       0.95x  FEASIBLE
p90          17,612     214,578  1.4    232,190       1.30x  INFEASIBLE
p90          17,612     275,886  1.8    293,498       1.64x  INFEASIBLE
```
**Typical is FEASIBLE for k ≤ ~1.5** (35% headroom at k=1.0, 12% at k=1.4). **p90 is feasible only at k ≈ 1.0** (5% headroom). The failure mode is no longer the blit.

**AC5 — gap check. — MET.** **Compiled draw+erase = 9.52 cy/byte vs the ~52 cy/byte break-even → 5.5× better than required.** The inherited masked loop was 54 aligned / 88 shifted. PA.6's 1.37× per-byte gap is not merely closed, it is inverted with a large margin. Blit share of the typical frame: **9.4%**, down from ~99%.

**AC6 — memory ledger. — MET.** Expansion ratio from the counted artifact: 317 instructions × ~2.5 B ≈ **792 B of code for a 180-byte sprite = 4.4×**.
```
POP cel (264 B footprint) compiled draw+erase ~ 1,162 B

BYTE-ALIGNED (1 phase)
   full library (602 cels)                    :   683 KB
   working set (kid 213 + one guard set 32)   :   278 KB   -> 512K CoCo3
SUB-BYTE (4 phases @2bpp)
   full library (602 cels)                    : 2,733 KB
   working set (kid 213 + one guard set 32)   : 1,112 KB   -> 2M+
```
**Neither variant's full library fits in RAM**, so a compiled build implies per-level/per-actor banking or streaming in both cases — the working set is the operative figure. **Byte-aligned fits a 512K machine; sub-byte needs 2M+.** That is the §5.23 tradeoff made concrete: sub-byte costs **4× memory and a RAM-tier jump**, and (per PA.6a) buys back the original's genuine sub-byte motion.

**AC7 — measured-vs-modelled ledger. — MET.**

| term | status | source |
|---|---|---|
| N1 blit ops/frame (9 median, 12 p90; mix) | **MEASURED (exact count)** | PA.6, reused unmodified per §6 |
| non-blit remainder (105,259 / 153,270) | **MEASURED** | PA.5 oracle |
| compiled draw / erase cycles per byte | **COUNTED** from real 6809 code | Glen `000061.bmp.asm` |
| POP cel size (1,056 px → 264 B) | measured (PA.3) → **mapped** ×320/280 | PA.3 medians; scaling is a modelling choice |
| transparent fraction (78% opaque) | **MEASURED in Glen's sprite**, assumed representative of POP cels | proxy assumption |
| compiled-code expansion (4.4×) | **DERIVED** from the counted artifact, ×2.5 B/instr assumed | instruction count is exact; byte/instr is an estimate |
| `k` (6502→6809 non-blit) | **ASSUMPTION**, 1.0–1.8 | no convention exists (PA.5 §6.2) |
| pre-shifted-phase sub-byte model | **STATED ASSUMPTION** | AC2 |

**AC8 — no source/engine/HAL/content/coco3 change; status clean except standing untracked. — MET.**

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output — APPLIES, satisfied.** The fetch (`http=200 bytes=21025`), the full instruction-level cycle derivation, the verdict table and the memory ledger are quoted verbatim in AC1/AC4/AC6 and the appendices. No oracle run was made.

**25.2 — N/A.** Nothing built or imaged.

**25.3 — N/A as a gate.** Cycle counts and byte sizes only; no appearance claim.

**C-35 presence check — SATISFIED.** §0 quotes verbatim `t0=2026-07-25T18:39:17Z` and HEAD.

**Capture presence check — SATISFIED.** §10 carries one slug.

---

### 6 — Reactive deviations

**6.1 — The verdict inverts PA.6, and the binding constraint moves. (The finding.)**
PA.6: infeasible, 1.58×–2.86× over, blit ≈99% of frame. PA.7: feasible at k ≤ ~1.5, blit **9.4%** of frame. The same op counts and the same non-blit remainder produce opposite verdicts purely because the blit implementation changed. **The consequence worth acting on is that the analysis focus must move**: five dispatches treated the blit as the question, and it is now the smallest term. The frame is now dominated by the 6502-measured game logic scaled by `k`, and **`k` has never been measured** — flagged unmeasured in PA.5 §6.2, PA.6 §7.1 and PA.6a. At k=1.8 the typical frame fails. **Feasibility now rests on the one number nobody has measured.**

**6.2 — The technique's headline figure (~1.8 cy/byte) is its inner loop, not its production cost.**
§5.22 and §1 of this dispatch both quote ~1.8 cy/byte. Counted: the PSHU bursts do run at **2.04–2.28** cy/byte, so the headline is accurate *about the burst*. But a production sprite also pays transparent-edge RMW, `LEAU` row-stepping, and the erase — giving **4.09 draw / 9.52 draw+erase**, i.e. **5.2× the headline**. The verdict is unaffected (still 5.5× better than break-even), but a budget built on 1.8 would have been optimistic by 5×. **This is the PA.6 lesson applied prospectively rather than learned retrospectively** — §10 explicitly warned against citing the figure, and counting was what surfaced the gap. Captured as a confirming pool instance.

**6.3 — A parse bug briefly corrupted the count; caught by a structural impossibility.**
Stripping assembler comments by splitting on `*` truncated operands containing multiplication (`LEAU 128*17+6,U` → `LEAU 128`), mis-costing all 36 `LEAU` instructions. It surfaced because the instruction histogram reported `LEAU` in *no-operand* mode, which `LEAU` cannot have — a structural impossibility, not a merely surprising number. Fixed to strip only whitespace-preceded `*`; draw total 715 → 736 cycles. Reported because the same collision will affect any future parse of this assembler dialect, and because the *detector* (carrying an addressing-mode column that can be checked for impossibility) is the reusable part.

**6.4 — The erase costs more than the draw**, 978 vs 736 cycles (5.43 vs 4.09 cy/footprint-byte). A cost model counting only the draw would understate a POP character frame by ~57%. Recorded because the erase is the half a headline figure never mentions.

**6.5 — Neither compiled library fits in RAM; the working set is the operative figure.**
Full library is 683 KB aligned / 2.7 MB sub-byte against a 512K–2M machine, so **any** compiled build requires per-level or per-actor banking/streaming. That is a design consequence I am *reporting*, not solving (§6). The working-set figures (278 KB / 1.1 MB) are what the RAM-tier question actually turns on.

**6.6 — Glen's sprite is 4bpp; POP mode B is 2bpp.** The cost model is *per byte*, so it transfers directly — but the same pixel area is half the bytes at 2bpp, which is already reflected (POP cel = 1,056 px ÷ 4 px/byte = 264 B). Flagged because a reader could mistakenly halve or double it a second time.

**6.7 — No idiom filed; sixth consecutive deferral.** Nothing here is oracle instrumentation (this dispatch ran no emulator), so §2A.3 arguably does not apply at all — but the five techniques queued from prior dispatches remain queued behind the outstanding authorship ruling.

---

### 7 — Uncertainty flags

1. **`k` is the whole ballgame now** and remains unmeasured. Typical is feasible to ~1.5 and fails at 1.8; p90 is feasible only near 1.0. Every other input could be perfect and the verdict would still hinge on this.
2. **Glen's sprite as a proxy for POP cels.** 78% opaque, 20×18, mostly-solid figure. POP character cels are similar in kind (PA.3: median 28×36), but a thinner or more ragged cel pays proportionally more perimeter RMW. Not sensitivity-tested.
3. **The 2.5 bytes/instruction estimate** in the memory ledger is not counted — the instruction count (317) is exact, the byte size is an estimate. A ±25% error moves the working set by ±70 KB (aligned), which does not change the RAM tier.
4. **Pre-shifted-phase model assumed** (AC2). If sub-byte were implemented as runtime shifting inside compiled code instead, the cycle advantage largely evaporates and PA.6's verdict would substantially return.
5. **PA.5's non-blit remainder is a 6502 measurement of POP's actual logic.** A CoCo3 port would not run identical logic — different memory layout, different I/O — so `k` is standing in for both ISA efficiency *and* implementation divergence.
6. **Compiled sprites impose a build-time toolchain** (a sprite compiler over 602 cels × phases) that does not exist. Out of scope here, but it is real work between this verdict and a running port.
7. **The 264-byte POP cel is the median.** PA.3's 90th percentile is 1,470 Apple px (~1,680 CoCo3 px, 420 B) — ~59% larger, which would raise the blit term to ~17 K typical. Still under 10% of the frame, so the verdict is insensitive.

---

### 8 — Follow-up candidates

**Feasibility statement for the gate (§3 deliverable — statement only):**

- **The port is FEASIBLE with compiled sprites**, at k ≤ ~1.5 for a typical frame. The blit term falls 16× and stops being the constraint.
- **The gap check passes decisively:** 9.52 cy/byte against a ~52 cy/byte break-even — **5.5× better than required**.
- **The constraint has moved to `k`.** This is the headline for planning: the next measurement that matters is not graphical.
- **Memory makes the alignment tradeoff concrete** (§5.23): byte-aligned = 278 KB working set on a **512K** machine; sub-byte = 1.1 MB needing **2M+**, and buys back the original's genuine sub-byte motion (PA.6a). Both need banking/streaming for the full library. **The tradeoff is now RAM tier vs motion fidelity** — Jay's call, and it is a cleaner question than it was two dispatches ago.

**Ordered follow-ups:**
1. **Measure `k`.** Now the sole determinant of feasibility and unmeasured across four dispatches. A representative POP logic routine hand-ported and cycle-counted both ways would settle it.
2. **Jay's alignment decision** — now precisely framed: 512K + 4-px quantized motion, vs 2M+ + faithful sub-byte motion.
3. **Sensitivity-test the cel proxy** (§7.2) — count a second, thinner sprite to bound the perimeter-RMW effect.
4. **Scope the sprite compiler** (§7.6) — real work implied by this verdict.
5. **Rule once on idioms-file authorship** (§6.7) — five techniques still queued.
6. Standing: `POP-idioms-coco3-markers.md` disposal; POP-level `.gitattributes`; `.vscode/` disposition.

---

### 9 — User interaction during task

**None during execution.** Every judgment call — reconciling erase against PA.6's peel count (§3), stating the pre-shifted-phase model (AC2), reporting the headline-vs-counted gap (§6.2), and disclosing the parse bug (§6.3) — is surfaced in §6 for post-hoc ruling.

---

### 10 — Candidate(s) captured this task

One new `live/` row, pushed in pool commit `57d4d27`:

- `seeds/POP/live/2026-07-25-a-techniques-headline-figure-is-its-best-case-not-its-production-cost.md` — a technique's headline figure describes its inner-loop best case, not a production instance; count a real artifact, including whatever must run to undo it, before budgeting. Filed deliberately as a **confirming second instance** of PA.6's count-it-don't-cite-it principle, this time with the guard applied and paying off. `initiator: executor`.

`seeds/POP/live/` now holds **twenty-three** POP rows.

---

### 11 — Commit

- **This report's commit** — on `wip`, pushed to `origin/wip` before reporting back. Hash in the accompanying reply.
- **No other `POP3_port` commit** — measurement only, per §9 of the dispatch.
- **Pool:** `57d4d27`.

---
---

## Appendix A — the counted artifact

```
$ curl -sS -L https://raw.githubusercontent.com/nowhereman999/CoCo-3-Scan-Line-Demo/master/000061.bmp.asm
http=200 bytes=21025
```
A 20×18 4bpp sprite (10 bytes/row × 18 rows = 180-byte footprint), containing two routines:
`_000061.bmp:` (draw) and `_Restore_000061.bmp:` (erase).

Sample of the real code — note the mixed idiom, not pure PSHU:
```
_000061.bmp:
        LEAU    128*17+6,U
* Row 18: 00 00 00 0F FF FF 00 00 00 00
        LDB     -3,U            \
        ORB     #$0F             |  transparent-edge read-modify-write (12 cy for 1 byte)
        STB     -3,U            /
        LDD     #$FFFF          \  short run (9 cy for 2 bytes)
        STD     -2,U            /
* Row 17: 00 00 FF FE EE EF FF F0 00 00
        LEAU    -128*1+1,U         row step
        LDA     ,U              \
        ORA     #$F0             |  edge RMW again
        STA     ,U              /
        LDD     #$FFFE
        STD     -5,U
```

## Appendix B — the cycle count, verbatim

```
=== DRAW  (_000061.bmp) ===
  instructions         : 164
  CYCLES               : 736
  screen bytes written : 141
  -> 5.22 cy per byte written
  PSHU bursts          : 67 bytes in 137 cy = 2.04 cy/byte
  mix: LEAU idxx18, STD idxx14, STA idxx14, LDD #x13, STB idxx12, LDB #x12,
       LDA idxx11, ORA #x11, STX idxx10

=== ERASE (_Restore_000061.bmp) ===
  instructions         : 153
  CYCLES               : 978
  screen bytes written : 141
  -> 6.94 cy per byte written
  PSHU bursts          : 125 bytes in 285 cy = 2.28 cy/byte
  mix: LDX idxx38, LDD idxx29, PSHU D,Xx29, LEAU idxx18, LEAY idxx18,
       LDA idxx7, STX idxx6, STA idxx4, PSHU A,Xx3

=== combined, 20x18 sprite (4bpp, 10 bytes/row x 18 rows) ===
  draw 736 cy + erase 978 cy = TOTAL 1714 cy
  footprint 180 bytes; opaque bytes written 141 (78% of footprint)
  draw+erase per byte WRITTEN   : 12.16 cy/byte
  draw+erase per FOOTPRINT byte :  9.52 cy/byte
```
MC6809 timings used: indexed base LDA/LDB/STA/STB 4, LDD/STD/LDX/STX 5, LDY/STY 6 (page-2 prefix), LEA 4; indexed extra ,R 0 / 5- or 8-bit offset 1 / 16-bit 4 / A,R,B,R 1 / D,R 4 / ,R+ 2 / ,R++ 3; immediate LDA/LDB/ORA/ORB 2, LDD/LDX 3, LDY 4; PSHU/PULU 5 + 1 per byte; RTS 5.

## Appendix C — verdict and memory ledger, verbatim

```
=== POP cel: 1056 CoCo3 px @2bpp = 264 bytes footprint ===
  draw only       1,079 cy
  draw+erase      2,514 cy

=== frame blit term ===
  typical (mid 2.86 draw+erase, bg+fg 3.40 draw) =   10,860 cy
  p90     (mid 4 draw+erase, bg+fg 7 draw)       =   17,612 cy
  PA.6 loop-blit typical was 176,948 cy -> compiled is 16x cheaper

case           blit  nonblit(k)    k      total   vs budget  verdict
typical      10,860     105,259  1.0    116,119       0.65x  FEASIBLE
typical      10,860     147,363  1.4    158,222       0.88x  FEASIBLE
typical      10,860     189,466  1.8    200,326       1.12x  INFEASIBLE
p90          17,612     153,270  1.0    170,882       0.95x  FEASIBLE
p90          17,612     214,578  1.4    232,190       1.30x  INFEASIBLE
p90          17,612     275,886  1.8    293,498       1.64x  INFEASIBLE

=== GAP CHECK vs PA.6's ~52 cy/byte break-even ===
  compiled draw+erase = 9.52 cy/byte  -> 5.5x BETTER than break-even
  inherited masked loop was 54 (aligned) / 88 (shifted) cy/byte
  blit share of the typical frame: 9.4% (was ~99% with the loop blit)

=== MEMORY LEDGER (compiled code size) ===
  Glen: 317 instrs x ~2.5 B = 792 B for a 180-byte sprite -> 4.4x expansion
  POP cel (264 B footprint) compiled draw+erase ~ 1,162 B
  BYTE-ALIGNED (1 phase)
     full library (602 cels)                  :   683 KB
     working set (kid 213 + 1 guard set 32)   :   278 KB  -> needs 512K
  SUB-BYTE (4 phases @2bpp)
     full library (602 cels)                  : 2,733 KB
     working set (kid 213 + 1 guard set 32)   : 1,112 KB  -> needs 2M+
```

---

*End of report.*
