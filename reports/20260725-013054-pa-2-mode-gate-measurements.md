## Form B Report — PA.2 — mode-gate measurements: DHGR title colour count + region-redraw budget estimate
**Class:** recon / measurement — INSPECTION + ESTIMATE ONLY. wip. **Prod byte-identity: N/A.**

> **M1 = 16.** All sixteen DHGR colours are used on every sampled title screen; the union is 16/16 with no index unused.
> **M2 = on the line, and the deciding variable is not the mode.** Against the **measured** budget of 178,968 cyc per animation step, a typical load costs ~199,680 cyc — **1.12× over** — under a mixed-alignment assumption, but **fits with 66% headroom** if blits are byte-aligned. Alignment moves the answer 5.5×; the 4-vs-16-colour mode moves it 2×.
> Both are stated as **gate input, not decisions** (§2(c)).

---

### 0 — Receipt / status (C-35 stamp)

```
t0=2026-07-25T05:23:38Z
```

**HEAD at t0:** `f98e18417ea75b5667f0851e7bc23f0181e49d09` (branch `wip`, no tracked file modified).
**HEAD at report time:** same — this dispatch produced no commit other than the report.

**§10 hard-stop gates — both PASS:**
```
vendored source last touched by : ba6154e "P1.1a: vendor oracle buildable-whole @ ec78dbf"
PROVENANCE pin                  : ec78dbfd51013ba349cda8c51c3ce0595fe75342
oracle .hdv md5                 : c4f0b13e49b77dd0fbc5063e27e53a24  -> PASS
```

**§0(a).3 — Karateka clone:** **PRESENT** at `/c/Projects/karateka_coco3`, with `src/hal/coco3-dsk/gfx.s` (47,949 B). M2 therefore uses the **measured Karateka basis**, not the first-principles fallback. Read-only throughout.

**`git status` at end:** no tracked file modified; 17 untracked (the standing 16 `docs/ground-truth/` + `POP-idioms-coco3-markers.md`).

Calibration-light per CLAUDE.md §1/§5. No elapsed, no band, no variance.

---

### 1 — Summary

**M1 — the title assets use the entire DHGR palette.** Six title screens were dumped from the running oracle as framebuffer *memory* and decoded offline to 140×192 16-colour. Every screen uses **all 16** indices; the union across all six is **16/16**, nothing unused. A single GIME palette would have to cover all sixteen. The distribution is strongly skewed, though — six colours carry 76% of pixels and four carry under 1% each — which raises a question this recon deliberately does **not** answer (§6.2).

**M2 — the estimate lands on the budget line, and the mode is not what decides it.** Two corrections to the naive framing dominate the result:

1. **The budget denominator was wrong by 6×.** The standing constant is 29,859 cyc per *hardware* frame, but PA.1's trace already recorded 738 page-flip events whose median interval is **6.0 frames** — POP animates at **10 fps**, not 60. The real budget is `6 × 29,859 − 186 = 178,968` cyc per animation step. At 29,859 the typical load reads 6.7× over; at the measured figure it reads 1.12× over. Same cost model, opposite indication.
2. **Karateka's measured blit cost is for a 4-colour mode, not 16.** `gfx.s` sets `$FF99=$15` = **320×192×4** (2bpp, 80-byte stride). Its documented `1880 cyc` for a 4-byte × 10-row sprite reconciles exactly as `40 bytes × 47 cy` — so the constant is sound, but it must be **doubled** for 4bpp before it means anything about a 16-colour mode.

With both corrected: a **typical** load (prince + 1 guard + 3 dynamic tiles) costs ~199,680 cyc against 178,968 — **1.12× over** at a 50/50 alignment mix, but **61,440 cyc (66% headroom)** if the blits are byte-aligned and **337,920 cyc (1.89× over)** if every blit is sub-byte shifted. **Alignment is a 5.5× lever; the colour mode is a 2× lever.** The dispatch anticipated exactly this case — §6 says rigour is warranted only if the number lands near the line, and it does.

Jay's scrolling insight is corroborated by the source: POP's `DRAWALL` (`GRAFIX.S:481-503`) is a peel-list restore-and-redraw over a static background, with a hard per-frame area cap from the peel buffer. There is no full-framebuffer translation anywhere in the per-frame path.

---

### 2 — Files modified

**None in `POP3_port` except this report.** No source, engine, HAL, content, coco3 or idioms change; no oracle rebuild; `/c/mame`, Karateka and the probe clone untouched (Karateka read-only for M2).

No oracle-instrumentation idiom was added: the framebuffer-dump method is a useful technique, but the banking save/restore it depends on is Apple-IIe-specific and was exercised once. Flagged in §8 for the Orchestrator to decide whether it earns a §2A.3 entry rather than asserting it does.

**Pool:** one new `live/` row, `22a43d9` (§10).

---

### 3 — Reasoning

**Authority and the visual boundary.** M1 is a **count over buffer contents read from emulated RAM** — not a rendered bitmap, not a PNG, and not an appearance claim. CLAUDE.md §3 forbids interpreting PNG pixel content, which rules out the snapshot route entirely; the dispatch's own §5.1 method (dump `$2000-$3FFF` from both banks) is memory data and is what was used. No statement in this report says what anything *looks like* — that remains Jay's (§4).

**Why the dumps are trustworthy: banking was observed, not assumed.** Reading aux RAM requires steering `RAMRD`, which perturbs the machine if restored wrongly. MAME exposes no RAM memory share for `apple2e` (`manager.machine.memory.shares` is empty; only ROM regions appear), so the read had to go through the CPU space. The dump therefore reads the IIe **read-only status switches** first — `$C013` RDRAMRD, `$C01C` RDPAGE2, `$C018` RD80STORE, `$C01D` RDHIRES, `$C01F` RD80COL — steers the bank, dumps, then restores to the observed prior state and **re-reads the status to confirm the restore**. All six dumps logged `restored RAMRD_aux=true (matches prior: true)`.

The status readback is also a cross-check on PA.1: every dump reports `80COL=true HIRES=true PAGE2=false 80STORE=false`, i.e. DHGR page 1 — independently consistent with PA.1's finding that the title screens run in DHGR. Note `RAMRD_aux=true` throughout: POP runs its title path with aux paged in for reads, which is precisely why a naive dump would have read the wrong bank.

**Why the M1 count is robust to the decode convention.** The decode splits each line's 560-bit stream into 140 **aligned** 4-bit groups (aux byte then main byte, 7 data bits each, LSB first). Some DHGR references apply a phase rotation by `x mod 4`. That uncertainty **cannot change the count**: a rotation is a bijection on the 16 values, so it permutes which indices appear but not how many. Since the answer is "all 16", the result is convention-independent. The per-index *labels* in §4 are the conventional Apple palette naming and are the one part that a different convention would relabel.

**Why the budget denominator is the crux of M2.** A cycles-per-frame constant invites comparison against one hardware frame of work, but POP does not advance one animation step per hardware frame. PA.1's trace answers this directly and at scale — 738 `$E1E4` page-flip events, median interval 6.0 frames, mean 6.43. That is measured on POP's own oracle, not assumed, and it multiplies the available budget by six. Both quantities are naturally spoken as "the per-frame budget", and no dimensional check distinguishes them, which is why the report states the denominator explicitly everywhere it appears.

**Why the Karateka constant needed scaling before reuse.** CLAUDE.md §2G says to reuse the *mechanism* but confirm the *constant* for POP. That rule earned its keep here: `gfx.s` header line 27 documents `320x192x4: $FF98=$80, $FF99=$15` and line 396 `Row stride is 80 bytes (320px / 4px per byte)` — 2bpp, four colours. Its cost table (`subbyte=0 ~10, 1 ~47, 2 ~55, 3 ~63` cy per source byte) and worked example (`4-byte × 10-row @ subbyte=1 ≈ 1880 cy`) reconcile exactly at `40 × 47 = 1880`, so the figures are internally consistent and usable — but only after doubling for 4bpp, where the same pixel area occupies twice the bytes.

**Why the load model is the peel list.** `DRAWALL` (`GRAFIX.S:481-503`) is, in order: `SNGPEEL` (restore the background saved two frames ago) → `ZEROPEEL` → `DRAWWIPE` → `DRAWBACK` → `DRAWMID` (which saves underlayers into the now-clear peel list) → `DRAWFORE` → `DRAWMSG`. So each visible image costs **two** blits per step — one restore, one draw — which is the `BLITS_PER_IMG = 2` in the model. `maxpeel = 46` (`EQ.S:297`) caps the list, and the peel buffer (`peelbuf1 = $d000`, `peelbuf2 = $d800`, `EQ.S:12-13`) caps the *area*: 2,048 bytes of Apple 1bpp ≈ 14,336 px. That is a hard architectural ceiling on per-frame redraw, taken from the source rather than guessed — scenario D.

---

### 4 — Verification (AC-by-AC)

**AC1 — M1 method stated and defensible. — MET.**
*Assets:* the DHGR screens PA.1 identified, sampled from the running oracle at frames chosen from PA.1's transition timeline — 380 (`PubCredit` splash, after `setdhires` at 304 and before the first `DeltaExpPop` at 401), 600 ("Brøderbund Presents"), 900 (`AuthorCredit`/byline), 1300 (`TitleScreen`), 2000 (`Prolog1`), 6500 (`Prolog2`/`SilentTitle` after the second `setdhires` at 5750). All are `DblExpand`-sourced screens per PA.1.
*Decode:* line base `(y&7)*0x400 + ((y>>3)&7)*0x80 + (y>>6)*0x28`; per line 40 column positions, each contributing **aux byte then main byte**, 7 data bits each, LSB first → 560 bits → **140 aligned 4-bit groups** = 140×192 16-colour. Full decoder in Appendix B; raw dumps are 32,781-byte hex files per frame.
*Banking:* observed and restored per §3, verified each time.

**AC2 — is the union ≤8, ≤16, or the full palette? — MET: the FULL palette, 16/16.**
Every one of the six screens independently uses all 16 indices. Union across all six:

| idx | conventional name | union px | share |
|---:|---|---:|---:|
| 0 | black | 43,568 | 27.01% |
| 8 | dark-blue | 26,453 | 16.40% |
| 1 | magenta | 21,390 | 13.26% |
| 4 | dark-green | 13,034 | 8.08% |
| 14 | aqua | 10,202 | 6.33% |
| 6 | green | 8,113 | 5.03% |
| 15 | white | 7,807 | 4.84% |
| 12 | medium-blue | 6,749 | 4.18% |
| 2 | brown | 4,913 | 3.05% |
| 9 | violet | 3,898 | 2.42% |
| 3 | orange | 3,421 | 2.12% |
| 7 | yellow | 7,293 | 4.52% |
| 13 | light-blue | 1,581 | 0.98% |
| 10 | grey2 | 1,173 | 0.73% |
| 11 | pink | 918 | 0.57% |
| 5 | grey1 | 767 | 0.48% |

**Unused indices: none.** Per-screen breakdowns in Appendix A. Two structural observations, reported as measurements only: the top six indices carry **76.1%** of all pixels, while the bottom four (`light-blue`, `grey2`, `pink`, `grey1`) carry **2.76%** combined; and the two story-text screens (2000, 6500) are dominated by black + magenta + dark-blue at ~72%, a visibly different distribution from the splash screens.

**AC3 — M2 basis stated. — MET: the measured Karateka basis.**
From `/c/Projects/karateka_coco3/src/hal/coco3-dsk/gfx.s` (read-only), header lines 386-391, quoted verbatim:
```
* Cycle estimate per source byte (static analysis):
*   subbyte=0: ~10 cy (lda ,x+ + sta ,y+ + loop overhead)
*   subbyte=1: ~47 cy (2×LSR + 2×ROR + OR-blend + overflow handling)
*   subbyte=2: ~55 cy (4×LSR + 4×ROR + OR-blend + overflow)
*   subbyte=3: ~63 cy (6×LSR + 6×ROR + OR-blend + overflow)
* For a 4-byte × 10-row sprite at subbyte=1: ~1880 cycles.
```
**These are Karateka's own static analysis, not an independent measurement**, and they are for **320×192×4** (`$FF99=$15`, line 27; 80-byte stride, line 396) — a **4-colour, 2bpp** mode. Internally consistent: `4 bytes × 10 rows × 47 = 1,880`. Scaled to 320×192×16 (4bpp, 2 px/byte): the same pixel area is twice the bytes, and the sub-byte shift becomes a 4-bit shift, nearest to Karateka's `subbyte=2 ≈ 55 cy/byte`; aligned stays ≈10 cy/byte.

**AC4 — M2 load model stated. — MET, and it is an estimate.**
Per-frame path `DRAWALL` (`GRAFIX.S:481-503`) → **2 blits per image** (peel restore + draw). Caps from source: `maxpeel = 46` (`EQ.S:297`), peel buffer 2,048 B (`EQ.S:12-13`) ≈ 14,336 Apple px.
*Proxy sizes (ESTIMATE):* character cel 32×48 px, dynamic tile 32×32 px on a 320×192 CoCo3 screen. These are the **weakest input in M2** — they are proportionate proxies, not measured POP cel dimensions (§7.2).
Scenarios: A quiet (prince + 1 tile); B typical (prince + 1 guard + 3 tiles); C busy (prince + 2 guards + 6 tiles); D the peel-buffer cap, scaled 320/280 = 1.14 to CoCo3 width.

**AC5 — M2 result vs budget, with headroom. — MET.**

**Budget = 6 × 29,859 − 186 = 178,968 cyc per animation step** (6 frames measured; 186 cyc `HAL_gfx_present` per flip — 0.1% of the budget, negligible but included).

| scenario | px redrawn | aligned (10 cy/px) | mixed (32.5) | shifted (55) | verdict at *mixed* |
|---|---:|---:|---:|---:|---|
| A quiet | 2,560 | 25,600 | 83,200 | 140,800 | **FITS**, 54% headroom |
| B typical | 6,144 | 61,440 | 199,680 | 337,920 | **OVER 1.12×** |
| C busy | 10,752 | 107,520 | 349,440 | 591,360 | OVER 1.95× |
| D peel cap | 16,384 | 163,840 | 532,480 | 901,120 | OVER 2.98× |

Break-even redrawn area: **17,897 px aligned** (29% of the screen), **5,507 px mixed** (9%), **3,254 px shifted** (5%).
Same loads in Karateka's existing **4-colour** mode (half the bytes): A 41,600; B 99,840; C 174,720 — all **fit**; only D overruns.

**AC6 — gate-input summary mapped onto the §9.10 tree, indication only. — MET, in §8.**

**AC7 — no source/engine/HAL/content/coco3 change; status clean except standing untracked. — MET.** Only this report; 17 untracked as at §0.

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output — APPLIES, satisfied.** Verbatim in the appendices: the framebuffer-dump run (`Average speed: 1441.43% (129 seconds)`, EXIT=0) with its banking/restore log; the decoder output; the cadence measurement (738 events, median 6.0); the budget computation.

**25.2 bundled-artifact grep — N/A.** Nothing built or imaged; no artifact produced.

**25.3 — N/A as a gate.** All runs headless (`-video none`). M1 is a **count over RAM buffer contents**, not an appearance claim and not derived from any PNG — the snapshot route was ruled out by CLAUDE.md §3. Appearance remains Jay's (§4).

**C-35 presence check — SATISFIED.** §0 quotes verbatim `t0=2026-07-25T05:23:38Z` and HEAD. No elapsed, no band, no variance.

**Capture presence check — SATISFIED.** §10 carries one slug.

---

### 6 — Reactive deviations

**6.1 — The budget denominator in AC5 is wrong by 6× if taken literally; I used the measured cadence and said so. (Most important deviation.)**
AC5 asks for the cost "compared to 29,859 cyc". That constant is per *hardware* frame; POP advances one animation step every **6** hardware frames (median of 738 page-flip intervals from PA.1's trace — mean 6.43). Comparing a per-animation-step cost against a per-hardware-frame budget overstates cost 6×: scenario B reads **6.7× over** at 29,859 versus **1.12× over** at 178,968. That is the difference between "the rich mode is hopeless" and "it depends on how you write the blitter". I report against the measured denominator, state it explicitly everywhere, and give the raw per-hardware-frame figures in Appendix C so the Orchestrator can check the substitution. Captured as a pool candidate.

**6.2 — M1's answer is "16", but the distribution invites a question I deliberately did not answer.**
Four indices carry under 1% of pixels each (2.76% combined) and could be dither/fringe artifacts of the DHGR encoding rather than deliberate palette entries — which would matter a great deal to a "≤8 easy" assessment. Determining that requires perceptual quantization or spatial analysis of the pixel distribution, and **proposing a reduced palette is palette design**, which §1/§6 forbid this dispatch. I therefore report the exact count and the full distribution and stop. Flagged in §8 as a distinct follow-up measurement, not as a finding.

**6.3 — Karateka's inherited blit constant is for a 4-colour mode; reusing it unscaled would have halved the estimate.**
`gfx.s` is `320×192×4` (2bpp), not 16-colour. The mechanism transfers, the constant does not — exactly the case CLAUDE.md §2G's "confirm each for POP" clause exists for. Recorded because the 1880-cyc figure is quotable out of context and would understate a 16-colour estimate by 2×.

**6.4 — MAME exposes no RAM memory share for `apple2e`, so the dump goes through the CPU space with explicit bank steering.**
`manager.machine.memory.shares` is **empty**; only ROM regions appear (`:maincpu`, `:gfx1`, `:sl7:cffa202:cffa2_rom`, …). Aux RAM is therefore not directly addressable from Lua. The dump reads the IIe status switches, steers `RAMRD`, dumps, restores, and re-reads the status to confirm — verified on all six dumps. Recorded because "there is no share, therefore you cannot read aux" is the wrong conclusion and would have blocked M1.

**6.5 — Source inconsistency: the peel buffer has two different sizes in two files.**
`EQ.S:12-13` gives `peelbuf1 = $d000`, `peelbuf2 = $d800` (2,048 B apart); `HIRES.S:40-41` gives `peelbuf1 = $d000`, `peelbuf2 = $d600` (1,536 B). M2 scenario D uses the **larger** (2,048 B), which is the conservative choice for a worst-case cap. Not investigated further — plausibly a game-vs-editor memory-map difference, but unresolved and reported as-is.

**6.6 — The Karateka cost figures are that project's *static analysis*, not a measured timing.**
`gfx.s` line 386 says "Cycle estimate per source byte (static analysis)". They are internally consistent and were accepted as the basis per AC3, but M2 inherits whatever error they carry. A cycle-exact measurement on real hardware or an accurate emulator would tighten M2 more than any refinement of my load model.

**6.7 — No §2A.3 idiom was added.** The framebuffer-dump-with-banking-restore technique is reusable, but it is Apple-IIe-specific and has been exercised exactly once. Rather than assert it into the idioms file on a single use — the file is a standing reference, and this dispatch's §3 permits but does not require the addition — it is surfaced in §8 for the Orchestrator to rule on. Noted explicitly because "discovered an idiom and did not record it" would otherwise look like an omission against §2A.3.

---

### 7 — Uncertainty flags

1. **M2 is an estimate and the report should not be read as a feasibility verdict.** It lands near enough to the line (1.12×) that the estimate's own error bars straddle it.
2. **The weakest input is the sprite proxy size.** Character 32×48 and tile 32×32 are proportionate guesses, not measured POP cel dimensions. Scenario cost scales linearly with them, so a 30% error in cel area moves scenario B from 1.12× over to roughly break-even or to 1.45× over. Measuring real cel dimensions from `chtable*` is the single highest-value refinement.
3. **Alignment mix is assumed 50/50 and is the dominant lever** — 5.5× between all-aligned and all-shifted, versus 2× for the colour mode. Whether a CoCo3 port can keep actor blits byte-aligned (2-pixel granularity at 4bpp) is an implementation choice this recon does not make and cannot predict.
4. **Blits-per-image is taken as 2** from `DRAWALL`'s restore-then-draw structure. If a CoCo3 implementation redrew dirty rectangles rather than per-image peel/restore, the constant changes.
5. **M1 sampled six frames**, chosen from PA.1's transition timeline. They cover every `DblExpand` title screen PA.1 identified, but a screen between samples could differ — though since every sample already uses all 16, more samples cannot lower the union.
6. **The palette index *names* are conventional**, and a different DHGR phase convention would relabel them. The **count** is convention-independent (§3).
7. **Nothing here has been visually confirmed.** That the 16 indices correspond to 16 perceptually distinct colours on screen is not established by this recon.
8. **`vibes`-driven DHGR-on during gameplay** (PA.1 §6.5) is not modelled; M2 assumes the animated path runs in one mode throughout.

---

### 8 — Follow-up candidates

**Gate-input summary (§4 AC6 / §5.3 — INDICATION ONLY, the decision is Jay's at the §9.10 gate):**

- **M1 forecloses the ≤8 branch as measured.** The union is 16/16, so a single ≤8-colour GIME palette cannot reproduce the title screens without a reduction step that this dispatch was forbidden to design. Between the surviving branches, M1 points at **C-16** rather than plain **C**.
- **M2 does not cleanly select a branch.** At the measured budget the typical load is 1.12× over under a mixed-alignment assumption and comfortably inside it if blits are aligned. So **C-16 is not excluded by cost**, and **B is not compelled** — the deciding variable is the blitter's alignment strategy, not the colour depth. Karateka's existing 4-colour mode fits every realistic scenario, which is what makes **B** a genuine fallback rather than a formality.
- **Net:** the numbers indicate **C-16, contingent on blit alignment**, with **B** as the fallback if alignment cannot be controlled. Stated as indication; not a decision, and not a recommendation.

**Ordered follow-ups:**
1. **Measure real POP cel dimensions** from `chtable1-7` — collapses M2's dominant uncertainty (§7.2) and is cheap.
2. **Decide whether M2 needs rigour.** It landed near the line, which is the condition §6 set for escalating from estimate to a real animation-engine recon.
3. **A perceptual/quantization analysis of the title palette** (§6.2) — whether the four sub-1% indices are deliberate or fringe artifacts. A measurement, distinct from palette design.
4. **Cycle-exact validation of the blit cost** (§6.6) — would tighten M2 more than any model refinement.
5. **Rule on the framebuffer-dump idiom** (§6.7) — worth a §2A.3 entry or not.
6. **Resolve the `peelbuf2` discrepancy** (§6.5).
7. Standing: dispose of `POP-idioms-coco3-markers.md`; the POP-level `.gitattributes` task.

---

### 9 — User interaction during task

**None.** No question asked; bridge-safe-equiv. Every judgment call — the budget denominator (§6.1), declining the palette-reduction question (§6.2), scaling the Karateka constant (§6.3), the banking method (§6.4), not adding an idiom (§6.7) — is surfaced in §6 for post-hoc ruling.

---

### 10 — Candidate(s) captured this task

One new `live/` row, pushed in pool commit `22a43d9`:

- `seeds/POP/live/2026-07-25-per-frame-budget-needs-the-subjects-cadence-not-the-refresh-rate.md` — a per-frame cycle-budget comparison needs the subject's **measured animation cadence** as the denominator, not the display refresh rate; the units hide the error and it always biases toward abandoning the richer option (from §6.1). `initiator: executor`.

`seeds/POP/live/` now holds **seventeen** POP rows.

---

### 11 — Commit

- **This report's commit** — on `wip`, pushed to `origin/wip` before reporting back. Hash in the accompanying reply.
- **No other `POP3_port` commit** — measurement only, per §9 of the dispatch.
- **Pool:** `22a43d9`.

---
---

## Appendix A — M1: framebuffer dumps and colour counts, verbatim

### A.1 — dump run and banking verification
```
mame apple2e -sl7 cffa202 -hard1 PrinceOfPersia_3.5.hdv -video none -sound none \
     -nothrottle -seconds_to_run 130 -autoboot_script fbdump.lua
Average speed: 1441.43% (129 seconds)   EXIT=0

frame=380  RAMRD_aux=true PAGE2=false 80STORE=false HIRES=true 80COL=true base=$2000
   restored RAMRD_aux=true (matches prior: true)
frame=600  RAMRD_aux=true PAGE2=false 80STORE=false HIRES=true 80COL=true base=$2000
   restored RAMRD_aux=true (matches prior: true)
frame=900  RAMRD_aux=true PAGE2=false 80STORE=false HIRES=true 80COL=true base=$2000
   restored RAMRD_aux=true (matches prior: true)
frame=1300 RAMRD_aux=true PAGE2=false 80STORE=false HIRES=true 80COL=true base=$2000
   restored RAMRD_aux=true (matches prior: true)
frame=2000 RAMRD_aux=true PAGE2=false 80STORE=false HIRES=true 80COL=true base=$2000
   restored RAMRD_aux=true (matches prior: true)
frame=6500 RAMRD_aux=true PAGE2=false 80STORE=false HIRES=true 80COL=true base=$2000
   restored RAMRD_aux=true (matches prior: true)
```
Six dumps, 32,781 bytes each (MAIN + AUX, `$2000-$3FFF` per bank). Status readback independently confirms PA.1: 80COL on, HIRES on, PAGE2 off → DHGR page 1 on every sample.

### A.2 — per-screen distinct colour counts
```
frame   380  PubCredit splash (pre-delta)      distinct=16  px=26880
frame   600  'Broderbund Presents'             distinct=16  px=26880
frame   900  AuthorCredit / byline             distinct=16  px=26880
frame  1300  TitleScreen 'Prince of Persia'    distinct=16  px=26880
frame  2000  Prolog1 (story text)              distinct=16  px=26880
frame  6500  Prolog2 / SilentTitle             distinct=16  px=26880

=== UNION across all sampled title screens ===
distinct colours in union = 16  (of 16 possible)
unused indices: none — all 16 used
```

### A.3 — two representative per-screen breakdowns
```
frame 1300  TitleScreen 'Prince of Persia'          frame 2000  Prolog1 (story text)
  idx  0 black        6097 px (22.68%)                idx  0 black        7873 px (29.29%)
  idx  1 magenta      2296 px ( 8.54%)                idx  1 magenta      5442 px (20.25%)
  idx  2 brown         983 px ( 3.66%)                idx  2 brown         396 px ( 1.47%)
  idx  3 orange        756 px ( 2.81%)                idx  3 orange        380 px ( 1.41%)
  idx  4 dark-green   2555 px ( 9.51%)                idx  4 dark-green   1278 px ( 4.75%)
  idx  5 grey1         167 px ( 0.62%)                idx  5 grey1          58 px ( 0.22%)
  idx  6 green        1679 px ( 6.25%)                idx  6 green         656 px ( 2.44%)
  idx  7 yellow       1459 px ( 5.43%)                idx  7 yellow        920 px ( 3.42%)
  idx  8 dark-blue    3290 px (12.24%)                idx  8 dark-blue    6046 px (22.49%)
  idx  9 violet        646 px ( 2.40%)                idx  9 violet        344 px ( 1.28%)
  idx 10 grey2         255 px ( 0.95%)                idx 10 grey2          70 px ( 0.26%)
  idx 11 pink          138 px ( 0.51%)                idx 11 pink           89 px ( 0.33%)
  idx 12 medium-blue  1419 px ( 5.28%)                idx 12 medium-blue   814 px ( 3.03%)
  idx 13 light-blue    337 px ( 1.25%)                idx 13 light-blue    191 px ( 0.71%)
  idx 14 aqua         2060 px ( 7.66%)                idx 14 aqua         1276 px ( 4.75%)
  idx 15 white        2743 px (10.20%)                idx 15 white        1047 px ( 3.90%)
```

---

## Appendix B — M1 decode model

```
line base(y) = (y&7)*0x400 + ((y>>3)&7)*0x80 + (y>>6)*0x28        [+ $2000 page base]
per line: 40 column positions; each contributes AUX byte then MAIN byte
per byte: 7 data bits (bit7 is not a data bit in DHGR), shifted out LSB-first
       -> 560-bit stream -> 140 ALIGNED 4-bit groups -> colour index 0..15
no phase rotation: groups are aligned to the 4-pixel NTSC period.
```
The count is invariant under the rotation convention (a rotation is a bijection on 16 values); only the index *labels* would change. Palette names are the conventional Apple IIe DHGR ordering.

---

## Appendix C — M2 computation, verbatim

### C.1 — the measured cadence (from PA.1's trace, re-analysed)
```
page-flip events: 738
intervals sampled: 725
median interval : 6.0 frames
mean interval   : 6.43 frames
=> POP animation rate = 60 / 6 = 10 fps
=> CoCo3 cycles per POP animation step = 6 x 29859 = 179,154 cyc  (less 186 present = 178,968)
```

### C.2 — the model output
```
Budget per POP animation step = 29859 x 6 - 186 present = 178,968 cyc

scenario                                    px    aligned      mixed    shifted   verdict(mixed)
A  quiet: prince only + 1 tile            2560     25,600     83,200    140,800   FITS, 54% headroom
B  typical: prince + 1 guard + 3 tiles    6144     61,440    199,680    337,920   OVER by 1.12x
C  busy: prince + 2 guards + 6 tiles     10752    107,520    349,440    591,360   OVER by 1.95x
D  peel-buffer CAP (absolute worst)      16384    163,840    532,480    901,120   OVER by 2.98x

Per-pixel cost, 4bpp, restore+draw:   aligned 10.0 cy/px   mixed 32.5   shifted 55.0
Break-even redrawn area:  aligned 17,897 px (29% of screen)
                          mixed    5,507 px ( 9%)
                          shifted  3,254 px ( 5%)

Same loads in Karateka's 4-colour 320x192x4 mode (half the bytes):
   A  41,600 cy FITS     B  99,840 cy FITS     C 174,720 cy FITS     D 266,240 cy OVER
```

### C.3 — the same figures against the RAW per-hardware-frame constant (for cross-check, §6.1)
Dividing by 6: against 29,859 cyc, scenario B (mixed) is 199,680/29,859 = **6.69× over** — the figure the naive denominator would have produced, and the reason §6.1 exists.

### C.4 — inputs and provenance
```
VBL           29,859 cyc/frame        CLAUDE.md §3 / backlog §3
PRESENT          186 cyc              HAL_gfx_present page flip, backlog §3
FLIP_FRAMES        6 (median)         MEASURED, PA.1 trace, 738 events
CY_ALIGNED        10 cy/src byte      karateka gfx.s:387 (static analysis, 2bpp)
CY_SHIFTED        55 cy/src byte      karateka gfx.s:389 (subbyte=2; nearest 4-bit-shift case)
BYTES_PER_PX     0.5                  320x192x16 = 4bpp = 2 px/byte
BLITS_PER_IMG      2                  GRAFIX.S:481-503 DRAWALL: SNGPEEL restore + DRAWxxx draw
maxpeel           46                  EQ.S:297
peelbuf        2,048 B                EQ.S:12-13  ($d000/$d800)   [cf. §6.5 discrepancy]
cel proxy      32x48 char, 32x32 tile ESTIMATE — not measured (§7.2)
```

---

*End of report.*
