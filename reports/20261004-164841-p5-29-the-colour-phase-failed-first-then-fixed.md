## Form B Report — P5.29 — the colour phase: the corrected instrument FAILED the old draw (944 + 396 cases), then the fixed draw passed (4,720 + 2,048)

**Class:** build. `wip`. **Prod byte-identical** (§0); `probe.dmk` and `tile_probe.bin` are also
unchanged. Only `char_probe.bin` moved. **Status: AT THE RE-GATE.** 25.3 pending Jay.

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-10-04T16:16:07-04:00 (HEAD **`20f72e1`**, wip, as the dispatch was drafted; `main`
**`32b5fe2`**). Tracked tree clean.

**AC3 — receipt vs a full rebuild at the end:**
```
08bcae4a6249828a64554c61db9ed7ace72e4081  intro_seq.bin      IDENTICAL
10bddbd5413d14b1fbf26aeadb874515fc32b3e8  loader.bin         IDENTICAL
d5b17b6d468f1bcdd66163a60d9ffa1e36197e15  cutscene_room.bin  IDENTICAL
92dc6d96778c71056ca37524779a5bcd1d61643c  flame_cels.bin     IDENTICAL
6c8d6e980c53eaa24d83eb383923f5a0568e4256  probe.dmk          IDENTICAL   (dispatch expected a change; §6.1)
b7751d2f1aabc9bbfb86b8ee29b9996174c89140  tile_probe.bin     IDENTICAL   (likewise)
c480978275707a102e3b29f791fdf2fcda8169d6 -> 2cdb3efd51aef60d48720f5abe654a7db42b4bfa  char_probe.bin  CHANGED (the subject)
```
**AC13 — `main` = `32b5fe2` at both ends.**

---

### 1 — Summary

**The sequence was kept.** The reference was corrected to colour by the oracle's rule, and **the probe,
run against the UNCHANGED draw, failed.** Gameplay failed **944 of 4,720** cases and the guard sets
**396 of 2,048**. Every failure lies in a class the diagnosis predicts, no class predicted to pass has a
single failure, and every predicted-fail case that passed is a chroma-free sword cel. That run was
committed on its own (`adbcc3b`) **before** any draw change.

Then a swap-without-mirror path was built (t = 3, four table pairs), and the same probe passes
**4,720 / 4,720 and 2,048 / 2,048.** The character probe now draws five kids, adding an unmirrored
PL = 1 frame and an odd-width mirror. The capture matches the offline prediction **15,360 / 15,360**, at
512 KB and 128 KB.

**Three of the dispatch's inputs did not hold, and each is reported rather than absorbed:**
1. **§5.385's counts (94 of 220 frames; 28 dual-parity cels) were my P5.28 instrument errors.** The
   correct figures are 98 of 227 frames and **5** dual-parity cels (§3B). The failure SHAPE still
   matched, so the diagnosis stands; the numbers did not.
2. **The dispatch's swap formula disagrees with the Jay-gated cutscene model for odd `apple_w`** (§3D).
   I followed the model, and the re-gate includes the frame that decides between them.
3. **The tables cost +2,048 B, not +1,792** (§3E): 256 B were spent to avoid writing a new, unmeasured
   loop.

---

### 2 — Files modified

- `harness/tools/cel_parity_rule.py`:
  - **extended, not forked**: `frame_table()` (every field evaluated), `swordtab()`,
    `decode_table()`, `gameplay_uses()`;
  - **`ROOT` derived from the file**, replacing `C:/Projects`;
  - `altset2()` untouched, so the cutscene cannot move.
- `harness/tools/xform_probe_gen.py`:
  - **`--parity oracle|even`** (the reference) and **`--draw oracle|p520`** (the caller's swap flag);
  - the unit becomes the (cel, PL) use;
  - the four swap-only table pairs; `XP_CASES` moved to `$4A00`.
- `src/harness/xform_probe.s` — `XP_CASES $4A00`, and the comments.
- `src/engine/xf_blit.s` — **t = 3, swap alone**: flag decode, `xf_swap`, four more `xf_ptab` entries.
- `harness/tools/xf_tables.py` — the four pairs; 7,424 B.
- `harness/tools/parity_fail_shape.py` — **new**; classifies a run against the diagnosis.
- `harness/tools/gen_frame_table.py` — **new**; `content/chars/frame_table.s` — **new**, Fcheck per
  frame (AC7).
- `src/engine/char_probe.s` — the colour phase applied on the 6809, the oracle's four steps literally;
  10-byte draw entries.
- `harness/tools/char_probe_plan.py` — the reference coloured by the oracle (FRAMEDEF through
  `cel_parity_rule`), frame cross-checked, draws checked against each other.
- `harness/tools/char_probe_regions.py` — five draws, two controls.
- `content/chars/probe_place.json` — five draws.
- `link/pop_charprobe.link` — re-laid: `prog` `$0E00`, tables `$4200–$5EFF`, DP `$5F`, `chdata`
  `$6B00`.
- `build.bat` — `-DXF_DPPAGE=0x5F`; the frame table regenerated and compared with the committed one
  on every build.
- `harness/smoke/tile_test.lua` — `P_SETTLE` (default 900, unchanged).
- `harness/smoke/run_char_test.sh`, `run_char_live.sh` — LOADM settle 1,800 (§3F).
- This report.

---

### 3 — Reasoning

#### 3A — Phase 1: the reference, corrected (AC4, AC5)

*Authority: source, CTRLSUBS.S:805-839 (the rule), 867-895 and 374-404 (the sword), HIRES.S:1202-1208
(MLayGen); and the shipped cutscene bake's model, Jay-gated at P3.72h.*

**The rule is `cel_parity_rule.parity()`**, which has existed since P3.22: odd X iff bit7(Fcheck) ==
bit7(CharFace). **Its header predicted P5.27's defect**, and it is the only home of the rule. I extended
it for gameplay rather than forking it:
- **`frame_table()` evaluates every FRAMEDEF field the way the assembler does.**
- **`gameplay_uses()` gives each use of a cel its PL**, the X parity facing left:
  - for a character cel, from its frame's Fcheck (Fdef, and ALTSET1 for the guard);
  - for a **sword** cel, its parent frame's parity XOR (SWORDTAB dx odd). SETUPSWORD adds dx to the
    character's FCharX **without** doubling it (`jsr ADDFCHARX`). I found this mechanism by reading the
    caller (§2H check 2).
- **Facing right, the X is always the other parity.**

**The corrected reference uses the cutscene's model**, the model `bake_scene.convert_src` ships and Jay
gated at P3.72h on an odd-width mirror (cel 11, 21 px):
- facing 0: `sprite_convert` at a column of parity PL;
- facing 1: `--mirror` at the oracle's LEFT column, X − 7·apple_w (`cel_parity_rule.draw_x`), so of
  parity (1 − PL) XOR (apple_w odd), flipped iff 7·apple_w is even.

**Its only parity input is the oracle's Fcheck.** The stream the probe DRAWS stays the bake's even
colouring, and I separated the two explicitly: an earlier cut of the change would have fed the
reference's colouring to the draw.

**The reference's unit is now the (cel, PL) USE, so the case count changed.**
- gameplay: **295 units → 4,720 cases** (was 290 cels → 4,640). The new number is not comparable with
  the old one under the same name.
- 5 cels are drawn at both parities (two units each).
- **8 cels no gameplay frame table names** (CHTAB1 #65, CHTAB2 #36, CHTAB3 #28/#37/#73, CHTAB4.GD #24,
  CHTAB5 #16/#45) keep one unit at PL 0, which is P5.20's reference, and the run's own output lists
  them.
- guard sets: **128 units → 2,048 cases** (4 unnamed, the #24 of each).

**AC4 — the cutscene does not move:**
```
--shipped p11 --shipped v54 (new code)  vs  P5.20's s000:   10 vs 10 cases, same set, differing 0
--parity even --draw p520 --baked       vs  P5.27's k###:   4640 vs 4640 cases, same set, differing 0
```
The prod files (§0) are identical after a full rebuild with the `ROOT` change, so `bake_scene` and
`gen_cel_table` read the same frame data as before.

#### 3B — Phase 2: the failing run (AC1, AC2) — ★ the dispatch's most important result

**The reference corrected, the draw UNCHANGED** (`--draw p520`: no swap at facing 0; at facing 1 a
swap iff 7·apple_w is even):

```
prefix f (draw=p520): 4720 cases, 944 FAIL, 3776 pass           [gameplay, 107 batches]
  class                                        fail     pass
  base                                            0     2360
  f0 PL0 aweven -> pass predicted                 0      296
  f0 PL0 awodd -> pass predicted                  0      380
  f0 PL1 aweven -> FAIL predicted               300       16
  f0 PL1 awodd -> FAIL predicted                180        8
  f1 PL0 aweven -> FAIL predicted               284       12
  f1 PL0 awodd -> pass predicted                  0      380
  f1 PL1 aweven -> pass predicted                 0      316
  f1 PL1 awodd -> FAIL predicted                180        8
  every failure lies in a class the diagnosis predicts to fail

prefix h (draw=p520): 2048 cases, 396 FAIL, 1652 pass           [guard sets, 50 batches]
  f0 PL1 aweven 192/0   f0 PL1 awodd 60/4   f1 PL0 aweven 84/0   f1 PL1 awodd 60/4   (fail/pass)
  every predicted-pass class: 0 failures
```

- **The shape is the diagnosis.** Unmirrored draws fail exactly when PL = 1, which is the half Jay
  could not see at P5.28. Mirrored draws fail exactly when (apple_w even) ≠ PL; P5.28's mirrored kid is
  `f1 PL0 aweven`. **No class predicted to pass fails, and no base case fails.**
- **The 44 + 8 predicted-fail cases that PASSED are 11 + 2 units, every one chroma-free.** They are
  CHTAB3 sword cels with pixel indices {0, 3} only; checked from the bake. A swap cannot change them.
- **The failing run is preserved** at `build/charp/failing_run/` (case files and logs, 314 files), and
  `parity_fail_shape.py` re-derives the tables above from it.

**AC2, against §5.385's prediction: the shape matches and the numbers do not, because §5.385's numbers
were wrong, and they were mine.** P5.28's counting script sliced FRAMEDEF with a regex that:
- (a) **skips every entry whose fields are expressions or bare decimals**: frames 135–140
  (`-5+5,51-63`), frame 206 (Fcheck `0`), and more;
- (b) **read `$40` in Fsword as decimal 40**, mis-decoding the table for **109** frames.

Evaluated properly, using the same counts as the probe:

| | P5.28 / §5.385 | evaluated |
|---|---|---|
| Fdef frames with an image | 220 | **227** |
| …with Fcheck bit 7 = 1 (unmirrored at odd X) | 94 | **98** |
| cels drawn at BOTH parities | 28 | **5** (Fdef alone: **0**; ALTSET1 and the swords add 5) |
| of the 290, cels with any PL = 1 use | — | **126** (121 PL = 1 only) |

**The defect is the same and its size is different.** It is not "28 cels force a runtime swap". It is
**126 cels the bake colours at the wrong phase for their own unmirrored draws**, plus the mirror rule.
The runtime swap still covers all of it with one stored colouring (§3E).

**The same regex error reaches P5.27.** Its *"14 of the 19 extra cels are named by NO frame
definition"* was produced through it. Evaluated, frames 135–140 name CHTAB3 #13–18 and frame 206 names
CHTAB5 #35, so **8**, not 14, of the 290 are unnamed (§8.3).

#### 3C — Phase 3: swap-without-mirror (AC6, AC7, AC8)

**`xf_blit` flags:** bit 0 = mirror, bit 1 = swap. **Swap alone is t = 3**, and draws from pair
**9 + k**, k = 0..3, through **the existing ascending carry loop.**
- **For k ≥ 1** the pair is F = SHR_k∘S, C = SHL_k∘S, where S is the 1↔2 exchange with no reversal.
- **For k = 0** the pair is F = S, C = SHL_0 = 0. The loop's carry is then always zero, the frame is w
  bytes, and every possibly-partial byte still goes through M.

So an unshifted swapped draw needs **no loop of its own**. The alternative was a dedicated k = 0 path,
which would be new code with no measurement behind it.

**AC6 — the cost, built against priced:**

| | priced (P5.28) | built |
|---|---|---|
| tables | **+1,792 B** (an S table + 3 pairs) | **+2,048 B** (4 pairs; S lives inside pair k = 0's F half) |
| total tables | 7,168 | **7,424 B** (`xftab` length `$1D00`) |
| code | — | `xf_blit` 1,013 → **1,059 B** (+46: the flag decode, `xf_swap`, 4 pointers) |

The +256 B is the price of reusing the measured loop. `xf_tables.py` refuses to emit unless its 7,424
bytes equal the probe generator's `tables_asm()`, and they do.

**AC7 — Fcheck carried in `cel_table.s`'s shape.** `content/chars/frame_table.s` (generated by
`gen_frame_table.py`, committed like `char_cels.s`) has one 5-byte row per frame for **Fdef (1..240)**
and **ALTSET1 (150..189)**:
- **+0 image, +1 Fdx, +2 Fdy, +3 Fcheck RAW** are `cel_table.s`'s fields, in its order. As there, *"the
  table carries the FACT and the engine the RULE"*.
- **+4 is the table slot**, where `cel_table.s` has the width. A gameplay frame's table varies (Fsword's
  top bits) and the cutscene's never did, and `apple_w` is per cel in `char_cels.s` (P5.27), so it is
  not repeated.
- **1,400 B.** `build.bat` regenerates it on every build and blocks if the committed copy differs.

**AC8 — the cast blob is untouched, measured:**
```
bake 91906 B, blob 91906 B: BYTE-IDENTICAL
gameplay 290 (CHTAB1/2/3/4.GD/5), tag order   290 cels  91906 B -> lz 41426 B  2.22x  20 -> 9 tracks
★ delta vs §5.338 (91,906 B / 41,426 B / 9 tracks): stream +0 B, lz +0 B, tracks +0
```
No stream changed (no re-bake), and the tables and the frame table are separate artifacts, so the 46 B
of track margin stands.

#### 3D — ★ The swap formula: the dispatch's and the model's disagree for odd apple_w

**The dispatch's formula:** `parity(oracle X) XOR (mirrored AND 7·apple_w even)`.

**What the cutscene's Jay-gated model gives,** relative to the bake's even colouring:
- **Facing 0:** the image's left column is X, so swap = parity(X) = **PL**.
- **Facing 1:** MLayGen lays the mirror 7·apple_w px left of X, so the left column's parity is
  parity(X) XOR (apple_w odd). The even-width flip then adds (apple_w even). Since
  (apple_w odd) XOR (apple_w even) = 1, swap = NOT parity(X) = **PL** again.

The two agree when apple_w is even, which includes P5.28's kid (frame 15). **They disagree when apple_w
is odd.** The dispatch's formula leaves out MLayGen's −7·apple_w column shift, which `cel_parity_rule.
draw_x` carries (P3.72g) and which the cutscene's odd-width mirror, cel 11, depends on.

I followed the model. **The source alone cannot settle a pixel-level question like this, so the re-gate
asks it directly.** `oddmirror` is frame 3 (`run-6`, CHTAB1 #3, apple_w = 3), drawn mirrored. The
dispatch's formula would draw it in the **opposite** colour phase, which differs from the capture in
**41 bytes** (§3G).

The 6809 glue does not use the PL shortcut. It composes the four steps literally (Fcheck vs face →
parity of X → left column via MLayGen → even-width flip), so the probe and the prediction check its
arithmetic rather than share it.

#### 3E — Phase 4: the passing run (AC9)

```
prefix p (draw=oracle): 4720 cases, 0 FAIL, 4720 pass     [gameplay, 129 batches; [run_xform_probe] PASS]
prefix u (draw=oracle): 2048 cases, 0 FAIL, 2048 pass     [guard sets, 71 batches; [run_xform_probe] PASS]
```
(There are more batches than before because the case area moved from `$4200` to `$4A00` to make room
for the new pairs.)

**What this pass is worth, said plainly.** It proves the RUNTIME equals the CORRECTED REFERENCE on
every use of every cel. **Whether the corrected reference equals the oracle's colour is Jay's
judgement.** That limit is what P5.28 lacked and the failing run now has.

#### 3F — The re-gate draws, predicted and compared (AC10)

**Five draws on LEVEL0 screen 1's top floor**, the same screen and the same rule as P5.28:

| draw | frame | cel | apple_w | PL | facing | what it tests |
|---|---|---|---|---|---|---|
| identity | 15 `stand` | CHTAB1 #15 | 2 | 0 | left | unchanged from P5.28 (Jay passed it) |
| shifted | 15 | CHTAB1 #15 | 2 | 0 | left, phase 1 | unchanged from P5.28 |
| **mirrored** | 15 | CHTAB1 #15 | 2 | 0 | **right** | **P5.28's failure, recoloured** |
| **pl1** | 1 `run-4` | CHTAB1 #1 | 2 | **1** | left | **an UNMIRRORED PL = 1 frame**, the half Jay has not seen |
| **oddmirror** | 3 `run-6` | CHTAB1 #3 | **3** | 0 | **right** | the odd-width case that decides §3D |

```
FB COMPARE — port vs PREDICTED: 15360/15360 identical, 0 differ  -> EXACT       [512 KB; 128 KB likewise]

draw      frame aw   PL   frame bytes     bytes  changed  port | controls:  p528 opposite
identity     15    2    0  33..35 r15..55     123       93     0 |              0       28
shifted      15    2    0  37..40 r15..55     164       90     0 |              0       26
mirrored     15    2    0  42..45 r15..55     164       93     0 |             25       25
pl1           1    2    1  47..50 r15..55     164      103     0 |             34       34
oddmirror     3    3    0  53..58 r16..55     240      123     0 |              0       41
outside every frame: 14505 B; port vs bare tile reference differ: 0
```
- **`p528`** is P5.28's rule. Identity and shifted are coloured exactly as before (0 bytes differ).
  Mirrored and pl1 are recoloured (25 and 34 bytes). The rejected rule would also have drawn oddmirror
  the same way (0).
- **`opposite`** is the other colour phase. For oddmirror it is the dispatch's formula, 41 bytes away.

**LOADM timing.** `CHAR.BIN` is now **13,885 B** (seven granules). At `tile_test.lua`'s 900-frame
settle, LOADM was still running when EXEC was typed: the keystroke was lost and the program stayed at
status 0 with BASIC's palette. The settle is now a parameter (`P_SETTLE`, default 900, so the tile suite
is unchanged); the character runners use **1,800**. Measured: 900 fails, 1,800 and 2,000 pass.

**The map** (`link/pop_charprobe.link`): `prog` at `$0E00–$179C` (the LOADM floor the map check
enforces), tables at `$4200–$5EFF`, DP `$5F`, and `chdata` (streams, registry, frame table) at
`$6B00–$7635`.

---

### 4 — Verification (AC-by-AC)

- **AC1** — §3B: **944 / 4,720 and 396 / 2,048 FAIL** on the unchanged draw, committed alone as `adbcc3b`.
- **AC2** — §3B: the shape matches, with no failure in a predicted-pass class. §5.385's counts were wrong
  (mine) and are corrected.
- **AC3** — §0.
- **AC4** — §3A: the cutscene cases are unchanged (10 / 10) and the old reference reproduces P5.27
  (4,640 / 4,640).
- **AC5** — §3A: `cel_parity_rule.py` extended. Its `ROOT` is fixed; **17 other tools** carry the stale
  literal (§7.2).
- **AC6** — §3C: built; **+2,048 B against +1,792 priced**, with the reason.
- **AC7** — §3C: `frame_table.s`, `cel_table.s`'s +0..+3.
- **AC8** — §3C: the cast blob is byte-identical, 41,426 B, 9 tracks, 46 B margin.
- **AC9** — §3E: **4,720 / 4,720 and 2,048 / 2,048.**
- **AC10** — §3F: five draws, including the unmirrored PL = 1 frame; **15,360 / 15,360** at 512 KB and
  128 KB.
- **AC11** — §5.
- **AC12** — **512 KB first: `introseq` PASS, `integ` PASS, `tile` PASS, ALL PASS; 128 KB: `tile`
  PASS, ALL PASS.** `run_char_test.sh` is EXACT at both sizes.
- **AC13** — §0.
- **AC14** — §6.
- **AC15** — §6.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1:**
```
build.bat: xf_tables: 7424 B, identical to the probe's tables_asm()
           gen_frame_table: Fdef + ALTSET1, 1400 B (and fc /b against content/chars/frame_table.s: same)
           char_probe_plan: 5 draws ... all CLEAR; predicted framebuffer (502 B differ from the bare tile)
           build/char_probe.bin (13885 bytes); [map_check] 1 map(s) clean
           CHAR.BIN 13885 ok / TILE.BIN 1500 ok; VERDICT: PASS; === BUILD COMPLETE ===
run_xform_probe.sh f (p520 draw): [run_xform_probe] FAIL  -- 944 of 4720
run_xform_probe.sh h (p520 draw): [run_xform_probe] FAIL  -- 396 of 2048
run_xform_probe.sh p (oracle draw): [run_xform_probe] PASS -- 4720 of 4720
run_xform_probe.sh u (oracle draw): [run_xform_probe] PASS -- 2048 of 2048
run_char_test.sh 512K: status=4 ... 15360/15360 identical -> EXACT, [run_char_test] PASS
run_char_test.sh 128K: 15360/15360 identical -> EXACT, [run_char_test] PASS
run_suites.sh 512K: introseq PASS / integ PASS / tile PASS / ALL PASS;  128K: tile PASS / ALL PASS
```
**25.2:** N/A.

**25.3 operator-runtime-smoke: PENDING JAY — the re-gate.** Runner `harness/smoke/run_char_live.sh`:
**live-disk** (`LOADM"CHAR"` + `EXEC` off `build/char_gate.dmk`), RGB, 512 KB, throttled. The picture is
static, so a live observation is complete for it. ★ **The script waits ~30 s at the BASIC prompt
before it types EXEC itself**, because LOADM takes that long.

**What Jay is asked**, about the five kids, left to right:
1. **Is the third kid (mirrored, facing right) orange now, like the first two?** That is P5.28's
   failure.
2. **The fourth kid (a running frame, facing LEFT, not mirrored):** are his colours right? It is a frame
   the old rule would have coloured wrong without anyone mirroring it.
3. **The fifth kid (another running frame, mirrored, facing right):** are his colours right? **This one
   decides between two readings of the rule** (§3D). The other reading would draw him in the opposite
   colour phase.
4. **Are the first two unchanged** from what he passed at P5.28?

**What Jay is NOT asked:**
- motion or timing;
- **plane ordering** (still avoided, still untested);
- clipping;
- the omitted torch flames, meter and gate;
- whether a running frame belongs on a floor next to standing ones (they are test patterns);
- anything about the guard sets (probe-verified only).

### 6 — Reactive deviations, non-proposals, route accounting

**Deviations:**
1. **`probe.dmk` and `tile_probe.bin` did not change**, though the dispatch expected both to. The
   character probe is a second build on its own gate disk (P5.28 §6.1), so the fix moves only
   `char_probe.bin`.
2. **I did not use the dispatch's swap formula** (§3D). The re-gate tests both readings.
3. **The table cost is 2,048 B, not 1,792** (§3C).
4. **I reported §5.385's counts as wrong and corrected them** (§3B) instead of matching against them.
5. **Five draws, not four:** the odd-width mirror was added to settle §3D.
6. **The LOADM settle** became a parameter, and the character runners use 1,800 frames (§3F).

**AC14 — not proposed:**
- no re-bake. A re-bake at each cel's oracle phase would make the unmirrored swap unnecessary for 121
  cels, but not for the 5 dual-parity ones; priced in §8.4, not taken;
- no plane ordering, motion, loader or clip path;
- the cutscene is untouched;
- the 17 stale-`ROOT` tools are not swept;
- `run_char_test.sh` is not added to `run_suites.sh`: it is not free, because it needs its own 1,800-
  frame settle and a second MAME boot;
- no PIL / PNG path (still failing at `render_fb.py`, carried).

**AC15 — ROUTE ACCOUNTING.** P5.28 §8.0 proposed three things:
- a swap-without-mirror path (+1,792 B);
- Fcheck in the registry or per frame;
- P5.20's reference corrected, then a re-gate.

**This change contains all three**, in the dispatch's order (reference, fail, fix, pass, re-gate). The
departures from what P5.28 described are stated above: 2,048 B not 1,792, and the swap rule stated
differently from P5.28's formula.

### 7 — Uncertainty flags

1. **§3D is unsettled until Jay sees `oddmirror`.** If the dispatch's formula is right, the model in
   `cel_parity_rule.draw_x` is wrong for gameplay, and so are the reference, the glue and
   `--draw oracle`. They all follow the cutscene model and would all agree with each other wrongly
   again, which is exactly the class P5.28 exposed. Only the gate can tell.
2. **★ The shipping build runs a tool from the stale `C:\Projects` clone.** `build.bat` runs
   `cel_link.py`, whose `ROOT = "C:/Projects/POP3_port"`. It executes **that clone's
   `harness/tools/cel_table.py`** to build the cutscene's walk table, and creates `build/obj` there.
   Prod is byte-identical today, so the two copies currently agree, but **the cutscene build depends on
   a second checkout**. 17 tools carry the literal: `bake_scene`, `demo_frame_census`,
   `demo_asset_census`, `bake_walk`, `beat_recost`, `cel_link`, `cel_table`, `chartable_audit`,
   `epoch_residency`, `gen_cel_table`, `pack_probe`, `peel_matrix`, `probe_cel_parity`, `shift_model`,
   `span_shift`, `verify_room_chars`, `walk_phases`.
3. **8 cels have no gameplay use** that I could find through the frame tables. Their reference stays at
   PL 0, which is a default, not a measurement.
4. **The guard sets' PLs come from slot 3's uses (GD's frames).** That assumes every CHTAB4 variant is
   drawn through the same frame tables, which is the oracle's structure (one CHTAB4 slot per level). It
   is not separately traced.

### 8 — Follow-up candidates

1. **★ Fix `cel_link.py`'s `ROOT`** (§7.2), and sweep the other 16. That is a prod-path change, so it
   needs its own dispatch.
2. **A second home for the FRAMEDEF parse remains**: `demo_frame_census.parse_framedef`,
   `chartable_audit`, `seq_graph`. Their regexes almost certainly share P5.28's blind spot. Fold them
   onto `cel_parity_rule.frame_table()`.
3. **Correct P5.27's "named by no frame def" claim** (14 → 8) in the record.
4. **Re-bake at oracle phase** (priced, not proposed): 121 cels would need no unmirrored swap; 5 still
   would.
5. Carried: plane ordering (P5.28 §8.1), the char test in the suites, the PNG path.

### 9 — User interaction during task

None.

### 10 — Candidate(s) captured this task

None.

### 11 — Commit

Phases 1–2 alone: **`adbcc3b`** (the corrected reference, before any draw change). Phases 3–4 and this
report: **`347b386`**. This hash line follows in its own commit. Pushed to `origin/wip`. `main`
untouched at `32b5fe2`. 25.3 will be recorded in a further commit.
