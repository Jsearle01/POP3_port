## Form B Report — P1.3 — production sprite compiler (all of Glen's optimizations included)
**Class:** BUILD — production tooling. `wip`.
**Prod byte-identity:** N/A — correctness here is that the compiled draw reproduces the source cel exactly,
verified by a register-level simulator on all 9 cels AND on the real GIME for one.

### 0 — Receipt / status (C-35 stamp)
t0=2026-07-26T00:22:27Z (HEAD `7991e7d`, wip). Tracked tree **clean** at receipt.
**Gates PASS:** oracle `.hdv` md5 `c4f0b13e49b77dd0fbc5063e27e53a24` ✔; vendored source `ec78dbf` ✔;
P1.2 tooling output present (9 cels) and the P1.2-fix orientation guard **green, 9/9** ✔.

---

### 1 — Summary

**The compiler is built, all four optimizations are in and demonstrable, every cel is sound, and one runs on
real hardware. But the headline number is not the one the dispatch expected, and the reason is the finding.**

**Glen's four optimizations bought ~3% on POP's art.** Production draw = **5.77 cy/footprint-byte** against
the PA.9 POC's **5.94 on identical cels** (the 6.44 in PA.9 was its own, different sample). The
implementations are correct and each is visible in the emitted code. They simply have almost nothing to work
on: profiling the emitted instruction mix, **`PSHU` fires 7 times in 2,990 instructions — 0.4% of cycles**,
while single-byte `LDA/STA` RMW is **60%**. The run-length histogram is decisive: **only 7% of opaque bytes
sit in runs of 4+, and 177 of 287 runs are a single byte.** The bursts are not underused, they are
**starved** — 60% of drawn bytes are *mixed* (opaque and transparent pixels in one 2bpp byte) and every mixed
byte fragments an opaque run. Glen's sprite is a compact solid blob with long flat runs; POP's cels are thin
limbed figures with maximal perimeter-per-area. PA.9 said its 6.44 "can only improve"; it did, by 3%.

**The lever that actually moves is opaque-black, and it is an authoring decision, not a compiler one.**
Measured on the same 9 cels: marking black opaque takes mixed **644 → 0**, `PSHU` firings **7 → 348**, opaque
runs of 4+ from **7% → 98%**, and draw from **5.77 → 3.93 cy/byte (−32%)**. That confirms PA.9 §6.4
quantitatively — and it only works *because* the four optimizations are present to exploit the changed byte
mix. They are not wasted; they are conditional.

**A correction to PA.9 §6.4, and it depends on the peel model.** Under a byte-set peel, opaque-black draws
more bytes so the erase grows and draw+erase gets *worse* (10.29 → 11.67). **POP's actual peel is a
rectangle** — `LAYRSAVE` does `inc WIDTH` then `CROP` and saves the bounding box; `PEEL` restores it via
`fastlaySTA` — so the erase is **constant with respect to coverage** and the draw saving is kept
(13.09 → 11.25). Both models are implemented and measured. Best combination measured:
**keyed black + byte-set peel at 10.29 cy/byte** — cheaper than POP's own rectangle peel, because the
compiler knows the exact byte set the draw touched.

**A real defect found in the PA.9 POC, and it had been passing for two dispatches.** The POC mapped a 6-byte
run onto `PSHU D,X,Y` as `run[0:2]→Y … run[4:6]→D`. That is **backwards**. Verified on the real 6809
(`src/harness/pshu_probe.s`): ascending from the final U the bytes are **A, B, Xhi, Xlo, Yhi, Ylo**. The POC
never caught it because its `simulate()` replayed the `chunk` list it had been handed and **never modelled
registers at all** — so the only decision the emitter actually made was outside the checker's model. The
production simulator executes A/B/X/Y/U, so an inverted mapping now fails the diff.

**Feasibility: PA.9's marginal p90 frame is recovered.** At k=1.0 PA.9 left it at **1.01× (MARGINAL)**; the
production compiler puts it under budget at **every** model, worst case **0.99×**, best **0.96×**. At
PA.11's idiomatic k=0.35 it is **0.41×**.

---

### 2 — Files modified
- `harness/tools/sprite_compiler.py` — **new.** The production compiler (D1). Supersedes `poc/compiled-sprite/`.
- `src/harness/pshu_probe.s` — **new.** The hardware probe that pinned the `PSHU` byte order.
- `src/harness/compiled_probe.s` — **new.** Runs a compiled cel on the GIME (D4).
- `harness/smoke/run_compiled_test.sh`, `harness/smoke/compiled_test.lua` — **new.** The D4 harness.
- `project-state.md` — compiler state, the cost model, the peel finding.
- `mame-idioms-coco3-port.md` — appended §17 (the `PSHU` order + the simulator-fidelity trap)
  and **§18/§18a** (MAME's Monitor Type default + the two palette decode tables).

**Added by the post-report fix (`6f07c8a`), after Jay reported orange rendering yellow:**
- `dist/mame-cfg/rgb/coco3.cfg`, `dist/mame-cfg/composite/coco3.cfg` — **new.** Monitor-Type presets.
  MAME's default is Composite; `CLAUDE.md §4` makes RGB the gate, so it must be set explicitly.
- `harness/smoke/run_probe_test.sh`, `run_cel_test.sh`, `run_compiled_test.sh` — `-cfg_directory
  dist/mame-cfg/rgb` added to all three.
- `src/harness/loop_probe.s`, `cel_probe.s`, `compiled_probe.s` — palette corrected to karateka's
  MAME-verified RGB set `$00/$26/$19/$3F` (was `$24`/`$12`, wrong for **both** modes).
- `.gitignore` — `/snap/` and `dist/mame-cfg/*/default.cfg` (MAME byproducts).

**Not modified:** `poc/compiled-sprite/` (PA.9's evidence artifact — superseded, not edited), the P1.2
tooling, `oracle/source/`, Karateka, Glen's repo (read-only; technique modelled, **no code copied**).

---

### 3 — Reasoning

#### 3.1 — The `PSHU` byte order, pinned on hardware (the thing everything rests on)

The whole emitter is a mapping from cel bytes onto D/X/Y before a burst. Rather than reason from the manual,
I asked the CPU: load `D=$A1A2, X=$B1B2, Y=$C1C2`, one `PSHU D,X,Y`, dump memory with canaries either side.
Result, ascending: **`A1 A2 B1 B2 C1 C2`** ⇒ `run[0:2]→D`, `run[2:4]→X`, `run[4:6]→Y`.

**The POC had it inverted.** Its soundness check reported ALL PASS across PA.9 and P1.2 regardless, because
`simulate()` did `for v in reversed(chunk): mem[u]=v` — it replayed the emitter's *intent* rather than
executing the machine's *semantics*, so register assignment was structurally outside its reach. This is the
P1.2-fix lesson in a new place, and it is why the production simulator executes registers.

#### 3.2 — The four optimizations, and why they under-delivered here

All four implemented; each demonstrated in emitted code in §5.

| # | Optimization | Status | Effect on POP's art |
|---|---|---|---|
| 1 | `PSHU D,X,Y` 6-byte bursts | in, **cost-driven** | fires 7× (0.4% of cycles) — starved by run fragmentation |
| 2 | Cross-push register reuse (whole routine) | in | elides loads when a burst repeats; few bursts to elide across |
| 3 | 16-bit RMW coalescing | in | 107 pairs coalesced (20 cy vs 28) — the one that pays here |
| 4 | Known-zero-bg `ORA`-only | in, **OFF by default** | −39% draw when enabled, but see below |

**On (1) being cost-driven rather than greedy.** A 2-byte run is *cheaper* as `STD d,U` (6 cy, U does not
move) than as `PSHU D` (7 cy plus a `LEAU` to reposition U). Glen's own file mixes `PSHU`/`STD`/`STX`/`STA`
for exactly this reason (46 `PSHU`, but also 14 `STD`, 16 `STX`, 18 `STA`). The emitter costs both forms per
run and picks.

**On (4) being off by default — the correctness call the dispatch explicitly allowed.** If the destination
is known zero, a mixed byte needs no read and collapses to a store. Measured: draw **3.78 → 2.30** cy/byte,
`ANDA` 52 → 0. But it is only valid if the back buffer is cleared before drawing, and **POP peels** —
`LAYRSAVE`/`PEEL` exist precisely so the engine never clears and redraws. Under a peel model the background
is live scenery and an `ORA`-only merge would smear the sprite over it. So `--bg-zero` is implemented,
measured, and **off**: correctness beats a lower cy/byte.

#### 3.3 — Why the gain is small, established by measurement not assertion

Instruction mix (draw, all 9 cels): `STA` 33.7% + `LDA` 25.9% = **59.6% of cycles in single-byte RMW**;
`PSHU` **0.4%**. Opaque-run lengths: 177 runs of 1, 85 of 2, 18 of 3, **7 runs of ≥4 (7% of store bytes)**.
`PSHU` needs ≥4 to pay. The cause is the mixed-byte fraction (59.9% of drawn bytes), which fragments runs —
the same structural property PA.9 identified as the cost driver, now shown to also disable the optimizations
meant to fix it.

#### 3.4 — Opaque-black, and the peel-model correction

Measured on the 9 cels, three opacity levels × two erase models (cy per footprint byte):

| black | mixed | PSHU | draw | erase (byte-set) | erase (**RECT = POP**) | d+e byte-set | d+e RECT |
|---|---|---|---|---|---|---|---|
| none (as authored) | 644 | 7 | 5.77 | 4.52 | 7.32 | **10.29** | 13.09 |
| shadow (lower ⅓) | 404 | 139 | 5.16 | 5.62 | 7.32 | 10.78 | 12.48 |
| all | 0 | 348 | **3.93** | 7.74 | 7.32 | 11.67 | **11.25** |

Two things fall out. **(a)** PA.9 §6.4 called opaque-black a win; it is — on *draw*. Under a byte-set peel
it is paid back by a larger erase. Under POP's rectangle peel it is not, because the erase is constant. The
model determines the answer, so I implemented and measured both rather than picking one. **(b)** The
cheapest column is `none + byte-set = 10.29` — i.e. **the compiled sprite enables a peel POP itself could
not do**, restoring exactly the bytes drawn rather than the bounding box, because the compiler knows the
byte set statically.

#### 3.5 — Erase is real, not scaled (closes PA.9 §6.5)

Three routines per cel, all compiled and counted from emitted instructions: `_draw_`, `_save_`
(framebuffer→peel buffer) and `_erase_` (peel buffer→framebuffer, `PSHU D,X` bursts of 4 — 4 not 6 because
Y is occupied as the source pointer, which is exactly the shape Glen's `_Restore_` uses). PA.9 scaled its
erase by a structural factor; this is measured.

---

### 4 — Verification (AC-by-AC)

- **AC1 — all four optimizations implemented and each demonstrated in emitted code. MET.** §5 shows a
  `PSHU D,X,Y` burst, a burst with `ldy` **elided** because Y was still live, a 16-bit coalesced RMW beside
  the 8-bit form it replaces, and the `--bg-zero` `ORA`-only collapse. Opt 4 is off by default **with
  reasoning** (§3.2), as §4.1 of the dispatch permits.
- **AC2 — opaque-black exploited, with the cy delta. MET.** §3.4 table: mixed 644→0, PSHU 7→348, draw
  5.77→3.93 (−32%). Demonstrated on a real POP cel with a real `opacity.s` sidecar (a **fixture in `build/`,
  not `content/`** — it is a compiler demonstration, not authored art).
- **AC3 — erase is REAL. MET.** §3.5. Compiled and counted: 4.52 cy/byte (byte-set) / 7.32 (rectangle).
- **AC4 — soundness on every sampled cel + orientation. MET.** 9/9 `OK` from the register-level simulator;
  9/9 orientation-guard PASS. Zero failures.
- **AC5 — measured improvement vs PA.9 + p90 re-check. MET, and honestly.** Draw **5.77** vs the POC's
  **5.94 on identical data** (**+2.9%**); vs PA.9's published 6.44 (different sample) it is 1.12×. The p90
  frame moves from **1.01× MARGINAL** to **0.96×–0.99× FEASIBLE** across all models (§5).
- **AC6 — one real assembled run. MET.** LWTools → 1,263-byte binary → real GIME → **all 492 bytes /
  1968 px identical**, orientation guard clean. The histogram shows **0% black**: transparent bytes still
  hold the `$A5` canary (which decodes to orange/blue), proving transparency was preserved rather than
  painted.
- **AC7 — idiomatic standard held. MET.** Straight-line bursts, index-register addressing off U with
  cel-local offsets, `,--Y`/`,Y++` auto-decrement/increment in save/erase, no per-byte scaffolding or
  transliterated loops.
- **AC8 — no engine/HAL/game code, no bulk conversion; status clean. MET.** §5.

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 — `PSHU` byte order, on the real 6809 (verbatim):**
```
loaded: D=$A1A2  X=$B1B2  Y=$C1C2 ; then PSHU D,X,Y
  buf+2    $A1   A   (D high)      buf+5    $B2   X low
  buf+3    $A2   B   (D low)       buf+6    $C1   Y high
  buf+4    $B1   X high            buf+7    $C2   Y low
ASCENDING ORDER: A (D high), B (D low), X high, X low, Y high, Y low
```

**25.1 — the compiler on all 9 cels (verbatim):**
```
=== sprite_compiler: 9 cel(s) ===
  guard_gd_001_median           36x8   none  288  149  89  1957 1491 1400   6.80  11.97  OK
  kid_chtab1_040_large          41x12  none  492  140  80  1892 1543 1351   3.85   6.98  OK
  kid_chtab1_064_thin           24x2   none   48   47  46   613  476  403  12.77  22.69  OK
  ... (9/9)
=== AGGREGATE (n=9) ===
  SOUNDNESS            : ALL PASS
  footprint bytes      : 2,506   drawn 1,075   mixed 644 (59.9% of drawn)
  draw cycles          : 14,453      -> 5.77 cy/footprint-byte
  erase cycles         : 11,330      -> 4.52 cy/footprint-byte
  draw+erase           : 25,783      -> 10.29 cy/footprint-byte
```

**25.1 — why the optimizations under-deliver (verbatim):**
```
=== DRAW instruction mix, all 9 cels ===
  STA  627  4869  33.7%      PSHU    7    63   0.4%
  LDA  627  3738  25.9%      LEAU    7    44   0.3%
=== opaque-run lengths ===
  run length 1: 177 runs;  2: 85;  3: 18;  4: 5;  5: 2
  runs of length >=4 : 7  (30 bytes = 7% of store bytes)
```

**25.1 — OPT 1 + OPT 2 (burst; `ldy` ELIDED across pushes) (verbatim):**
```
        ldd     #$000F         *  3
        ldx     #$FF00         *  3
        ldy     #$0000         *  4
        pshu    D,X,Y          * 11
        ldd     #$0FFF         *  3
        ldx     #$C000         *  3     <-- no LDY: Y=$0000 still live (OPT 2)
        pshu    D,X,Y          * 11
```

**25.1 — OPT 3 (16-bit coalesce, 20 cy) beside the 8-bit form it replaces (verbatim):**
```
        ldd     84,U    * 6        |        lda     2,U     * 5
        anda    #$C0    * 2        |        anda    #$CF    * 2
        andb    #$0F    * 2        |        ora     #$10    * 2
        ora     #$3F    * 2        |        sta     2,U     * 5
        orb     #$F0    * 2        |   (14 cy for ONE byte; 28 for two)
        std     84,U    * 6        |
```

**25.1 — OPT 4 (`--bg-zero`), measured then left OFF (verbatim):**
```
  default : kid_shadow 41x12 mixed 492 272 56  1862 ...  3.78 cy/B      ANDA count 52
  --bg-zero: kid_shadow 41x12 mixed 492 272 56 1133 ...  2.30 cy/B      ANDA count  0
```

**25.1 — AC2 opaque-black, both erase models (verbatim):**
```
  black     mixed  PSHU    draw  erase(byteset)  erase(RECT=POP)  d+e byteset  d+e RECT
  none        644     7    5.77            4.52             7.32        10.29     13.09
  shadow      404   139    5.16            5.62             7.32        10.78     12.48
  all           0   348    3.93            7.74             7.32        11.67     11.25
```

**25.1 — D4, the compiled sprite on the real GIME (verbatim):**
```
  kid_chtab1_040_large  PASS  41x12B  row 0 == source row 40 (top-first)
[run_compiled_test] assembled build/compiled_probe.bin (1263 bytes)
  magic_is_C0DE                PASS got $C0DE
  framebuffer_matches_cel      PASS all 492 bytes (1968 px) identical
  #   0 Black      0    0.0%   <- transparent bytes still hold the $A5 canary
  #   1 Orange   820   41.7%      (canary decodes to orange/blue) => transparency PRESERVED
  # VERDICT: PASS
```

**25.1 — p90 feasibility re-check (verbatim):**
```
  PA.9 p90 blit = 27,730 cy at 14.99 cy/byte  =>  1,850 footprint bytes
  --- non-blit k=1.0 (PA.9's marginal case): 153,270 cy ---
    PA.9 POC (scaled erase)                    total 181,000  1.011x  MARGINAL
    P1.3 production, byte-set peel             total 172,305  0.963x  FEASIBLE
    P1.3 production, RECT peel (POP-faithful)  total 177,485  0.992x  FEASIBLE
  --- non-blit k=0.35 idiomatic (PA.11) ---
    P1.3 production, byte-set peel             total  73,061  0.408x  FEASIBLE
```

**25.2 — the compiler + output:** `harness/tools/sprite_compiler.py`; compiled `.s` in `build/compiled/`
(gitignored build artifacts); the emitted routines are quoted above.

**25.3 — the real GIME render → JAY'S GATE: ✅ CONFIRMED 2026-07-26T00:45:32Z ("the png looks good").**

Surfaced uninspected per `CLAUDE.md §3`. The background is the `$A5` canary by design, so the frame is
deliberately noisy — that noise *is* the transparency evidence.

**Gated on the SECOND snapshot, not the first — and the reason matters.** The original
`…__real-GIME.png` was rendered in **Composite**, because MAME's `Monitor Type` defaults to Composite
(`value=0, default="yes"`) and this harness never set it, while `CLAUDE.md §4` makes **RGB** the project
gate. On top of that the probe palette (`$24`/`$12`) had been hand-computed as an RGB bit-pack and was wrong
for both modes; under composite decoding `$24` is intensity 2 / hue 4 — **yellow**. Jay reported the orange
reading yellow-ish, which is what exposed the monitor-mode error underneath it. Both fixed (commit
`6f07c8a`): RGB forced via `-cfg_directory dist/mame-cfg/rgb`, palette set to karateka's MAME-verified RGB
values `$00/$26/$19/$3F`. The confirmed artifact is
`build/compiled-review/compiled_kid_chtab1_040_large__RGB-corrected.png`.

**None of it moved a single measurement in this report.** The framebuffer holds palette INDICES; monitor
type and palette registers only change how those indices are DECODED for display. Every cycle count,
soundness diff and the 492-byte framebuffer match are unaffected, and were re-run green after the fix
(compiled proof PASS, P1.1 loop probe 6/6, P1.2 cel spot-check PASS).

**And no automated check could have caught it** — the byte-diff was green at 1968/1968 px throughout,
because palette semantics live entirely outside the bytes being diffed. Structurally the same blind spot as
the P1.2-fix orientation flip: different property, identical shape. Filed as idiom §18/§18a.

**`git status --porcelain` (tracked):**
```
A  harness/smoke/compiled_test.lua      A  harness/smoke/run_compiled_test.sh
A  harness/tools/sprite_compiler.py     A  src/harness/compiled_probe.s
A  src/harness/pshu_probe.s             M  mame-idioms-coco3-port.md
M  project-state.md
```

---

### 6 — Reactive deviations

1. **Optimization 4 is implemented but OFF by default** (§3.2). POP peels, so a known-zero background is not
   available. §10 of the dispatch explicitly prefers omission with reasoning over incorrect code.
2. **Two erase models emitted, not one.** The dispatch said "match the engine's intended peel/restore model
   (POP peels; state which)". POP's peel is a **rectangle** (`LAYRSAVE` `inc WIDTH` + `CROP`), but a compiled
   sprite can do better — a byte-set peel restoring only what it drew. Both are implemented and measured
   because the choice changes the opaque-black verdict (§3.4) and is an engine decision not yet made.
3. **The measured gain is small and is reported as such.** The dispatch framed PA.9's 6.44 as an upper bound
   that this work would improve on. It does, by ~3% on identical data. I have not presented the 6.44→5.77
   comparison as the headline because 6.44 was a different sample; the like-for-like number is 5.94→5.77.
4. **A defect was found in PA.9's POC** (§3.1). `poc/compiled-sprite/` was **not edited** — it is PA.9's
   evidence artifact, now superseded. The defect is recorded here and in idiom §17.
5. **The opaque-black demonstration fixture lives in `build/`, not `content/`** — same call as P1.2: an
   arbitrary opacity mark is a compiler demonstration, not authored shadow art, and must not sit in
   `content/` looking authored.
6. **A `snap/` directory was created in the repo root by MAME** and moved into `build/`. Now gitignored
   alongside `cfg/`, together with the `default.cfg` MAME drops into any `-cfg_directory`.
7. **POST-REPORT FIX (`6f07c8a`) — the harness had been rendering in the wrong monitor mode since
   P1.1.** Jay reported the orange reading yellow-ish. Root cause was two-deep: MAME's `Monitor Type`
   defaults to **Composite** and this harness never set it, while `CLAUDE.md §4` makes **RGB** the
   project gate; and the probe palette had been hand-computed as an RGB bit-pack (`$24`/`$12`) that
   was wrong for both modes — under composite decoding `$24` is intensity 2 / hue 4, i.e. yellow.
   Fixed and re-verified (§25.3). **No measurement in this report moved**: the framebuffer holds
   palette INDICES and only their DECODE was wrong. Surfaced here rather than folded silently in,
   because a monitor-mode error invalidates every prior visual gate's *mode* claim even when it
   invalidates none of the numbers.

---

### 7 — Uncertainty flags

*(25.3 is CLOSED — Jay confirmed the corrected render 2026-07-26. The monitor-mode/palette defect
found in the process changed no measurement in this report; see 25.3.)*


1. **The cy/byte figures are counted from emitted instructions, not executed cycle counts.** MAME exposes no
   cycle counter (idiom §0), so per-instruction counts are the method — the same one PA.7/PA.9/PA.11 used.
   The real GIME run proves *correctness*, not *timing*. A VBL-delta measurement of a compiled cel is the
   follow-up that would close it.
2. **`_save_` is emitted and counted but never executed** — neither in simulation nor on hardware. Only
   `_draw_` is proven end-to-end. `_erase_` is counted but likewise unexecuted; its correctness depends on
   the peel buffer being filled by the matching `_save_`, which no engine yet does.
3. **The 9-cel sample is small and all from the same two characters.** The mixed-byte fraction (59.9%) and
   run-length distribution drive every conclusion here; a wider sample could shift them. PA.9 used 12 cels
   and got 68.9% mixed on a different (structural stand-in) pipeline.
4. **The p90 re-check reuses PA.9's frame decomposition** (1,850 footprint bytes, non-blit 153,270 at
   k=1.0). It inherits whatever error is in that decomposition; only the blit term is re-derived.
5. **Opt 2's benefit is under-measured, not absent.** Cross-push reuse can only elide loads when bursts
   recur, and with 7 bursts there is nothing to recur. Under opaque-black (348 bursts) it is doing real work,
   but I did not isolate its individual contribution from opts 1/3.
6. **Glen's `LEAU` row-stepping idiom was not adopted.** He folds the row advance and column adjust into one
   `LEAU -128*1+1,U`; my emitter emits `LEAU` lazily from a tracked U. On this art `LEAU` is 0.3% of cycles,
   so it was not worth the complexity — but on burst-heavy art it would matter.

---

### 8 — Follow-up candidates

1. **Decide the peel model** (byte-set vs rectangle) — it changes the opaque-black verdict and is worth
   ~2.8 cy/byte. This is now an engine decision with measured numbers behind it.
2. **Measure a compiled cel's real cycle cost by VBL delta** (idiom §0) to close §7.1 — converts the whole
   cost model from counted to executed.
3. **Execute `_save_`/`_erase_` on hardware** (§7.2) — the draw is proven, the other two are not.
4. **Widen the cel sample** and re-derive the mixed-byte fraction (§7.3) before the bulk conversion.
5. **Bulk-convert + compile the library** once 1–4 settle — explicitly out of scope here.
6. Standing: the **§2A.3 authorship ruling** (now **thirteen** deferrals; §17 filed provisionally).

---

### 9 — User interaction during task
**One, post-report, and it caught a real defect.** Jay reviewed the surfaced snapshot and reported
*"the orange color shows as yellow-ish but i guess thats because you didn't set the proper palette
colros?"* — correct, and the cause ran deeper than the palette: the harness had never set MAME's
Monitor Type, so it had been rendering in Composite (MAME's default) since P1.1 while `CLAUDE.md §4`
specifies RGB. Both fixed in `6f07c8a`; see 25.3. Jay then confirmed the corrected render
(*"the png looks good"*, 2026-07-26T00:45:32Z), closing the gate.

---

### 10 — Candidate(s) captured this task

Two, both pushed (`20f97cc`), fresh single-instance rows, no existing entry read or edited:

1. `seeds/POP/live/2026-07-26-an-optimizations-payoff-is-a-property-of-the-data.md` — *"An optimization's
   published payoff is a property of the DATA it was measured on, not of the technique."* Four correctly
   implemented optimizations bought 3% because `PSHU` had nothing to burst; the structural property that
   predicts it (run length) was checkable from the input alone, before building anything.
2. `seeds/POP/live/2026-07-26-a-simulator-that-replays-intent-cannot-validate-encoding.md` — *"A
   code-generator's simulator must execute the TARGET MACHINE's semantics, not replay the generator's own
   intent."* The POC's inverted `PSHU` mapping passed every check across two dispatches because its
   simulator never modelled registers.

---

### 11 — Commit
`ca1224c` — P1.3: production sprite compiler (the dispatch's deliverable).
`93739d8` — report §11 hash fill-in.
`6f07c8a` — P1.3-fix: monitor mode + palette (post-report, Jay-reported; §6.7, 25.3).
`9be334a` — 25.3 gate confirmation recorded.
All pushed to `origin/wip`.
