## Form B Report — P5.34 — xf_blit carries the stream's mask: premise proven, draw finished, suites green — and the kid has been running at HALF SPEED since P5.31
**Class:** build. wip. Prod byte-identical — `intro_seq.bin` `08BCAE4A…`, `loader.bin` `10BDDBD5…`,
`cutscene_room.bin` `D5B17B6D…`, `flame_cels.bin` `92DC6D96…`, sha1 at t0 and at the end. The cutscene has not
moved. `content/chars/` untouched (0 changes). `main` `32b5fe2` at both ends.

### ★★★ THE CADENCE RESULT, FIRST (§5.4)
**The two-actor cadence slipped from 9.99 to 9.85 fps (6.00 → 6.08 display frames per step)**, still faster
than the oracle's 9.65 over the same frames. **No VBL tick is lost** (1,200 real frames = 1,200 HAL ticks, one
and two actors — `vbl_tick_check.lua`). **The cause is the clock: the kid-run probe executes at 0.89 MHz, not
1.79.** `tile_probe.s`'s `load_track` [:201-213] writes `SAM_SLOW` (`$FFD8`) for the tile-page read and never
writes `$FFD9` back; `tile_entry` reads that page after `HAL_sys_init` set double speed. **Measured: 14,834 CPU
cycles per real frame during the run** (0.89 MHz = 14,930; 1.79 MHz = 29,859). So:
- **Every budget and share figure from P5.31 to P5.33 used 29,859 cy/frame and is 2× optimistic.** At the
  true clock the six-frame pace is **89,580 cy**, not 179,156. P5.32's two actors averaged 74,757 (83%) with a
  worst step of 84,808 (95%) — they fit. **This dispatch's two actors average 79,880 (89%) and the worst step
  is 91,912 (103%)**: some steps run into a seventh frame.
- **One line fixes it** — restore `$FFD9` after the read in `tile_probe.s`'s `load_track` (plus a register-owner
  row; `$FFD9` is a new owner for that file). It halves every step's wall-clock time. **Not done here**: it is
  outside this dispatch, it changes what every earlier cost figure means, and P5.5's tile probe is a gated
  artifact (§8.1).

### 0 — Receipt / status (C-35 stamp)
t0=2026-10-10 13:58:01 (HEAD `682dc03`, wip — as drafted). `wip` red on `char`/`kidrun` at t0 (P5.33's honest
state). git status clean of tracked changes.

### 1 — Summary
**AC1, the premise, proven exhaustively over the tables AS LINKED** (the `xftab` segment of the built binary):
every table — `XF_T1`, `XF_T2`, F and C of all 13 pairs — keeps a byte of 00/11 pixels in that set (448/448),
and `XF_M[v] == ~v` on those bytes (16/16). **The defect model was confirmed before building** (AC3): all
64,584 residual pixels from P5.33 sit on the four `M` sites, none elsewhere. `xf_blit` now carries an
**opacity byte** beside the colour byte through every segment type and writes `dest = (dest AND M[out_op]) OR
out` — the "pixel is 0" heuristic is gone from the routine, not patched around. Result: **the transform probe
passes 4,720/4,720** (the baseline cases restored under the oracle model), the 464 cases that already passed
are **unchanged to the cycle**, the kid run is exact at all 13 steps with **459 both-opaque cells, 0 wrong**,
`char` and `kidrun` are **green**, and P5.32's broken control **still fails** inside the guard.

### 2 — Files modified
- `src/engine/xf_blit.s` — the opacity byte: DP +4 (`xf_oc`, `xf_cc`, `xf_fff`, `xf_cff`; 14 → 18 bytes);
  `XA_R`/`XD_R` replaced by `XA_B`/`XD_B` (a blast's first byte) and `XA_M`/`XD_M` (a merge byte);
  `xf_consts` (per call: F[$FF], C[$FF]); skip-flush and row-end gated on the OPACITY carry; blast end sets the
  carry to C[$FF]; `xa_r0`/`xd_r0` branches long. Header: the failed premise named and replaced. `XA_D`/`XD_D`,
  `xm0` and the `blit_cel_full` path untouched.
- `link/pop_charprobe.link`, `link/pop_kidrun.link` — the DP map comment, 18 bytes.
- `harness/tools/xf_opacity_premise.py` — NEW: AC1, over a built binary's xftab.
- `harness/tools/xform_probe_gen.py` — `stream_oracle()`: baseline cases restored under `--mask oracle`.
- `harness/tools/vbl_tick_check.lua` — NEW: HAL ticks vs real frames while the kid runs.

### 3 — Reasoning

**3A — AC1, the premise** (`xf_opacity_premise.py`, verbatim in §5). Base: **16** of the 256 bytes have all four
pixels in {0, 3}; 28 tables × 16 = 448 checks, 0 fail; `XF_M[v] == ~v` 16/16. And §3B's constants exist: per
pair F[$FF] and C[$FF] are complementary halves (pair 0 `$3F`/`$C0` … swap-only k=0 `$FF`/`$00`).

**3B — AC2, the four sites, and §2's reading confirmed — with one addition.** Ascending (descending mirrors each):

| site | before | now |
|---|---|---|
| `xa_mpk` skip, flushing a carry | `M[out]`, and only if **A ≠ 0** | `M[op_carry]`, if the **opacity** carry ≠ 0; then op_carry = 0 |
| `xa_mp0..3` a blast's first output byte | `M[out]` | `M[op_carry | F[$FF]]`; after the blast op_carry = C[$FF] |
| `xa_mpm` every merge byte | `M[out]` (mask byte never read) | `M[op_carry | F[~mask]]`; op_carry = C[~mask] |
| `xa_mpe` the row's final carry | `M[out]`, if **A ≠ 0** | `M[op_carry]`, if op_carry ≠ 0 |

**The addition to §2's reading:** the skip flush and the row end were gated on the COLOUR carry, so a carried
half-byte of pure border (colour 0) was not written at all — lost before `M` was even reached. Both now test
the opacity carry.

**3C — AC3, the residue was where §2 said.** P5.33's post-bake probe log, walked against each stream the way
the loops walk it: 64,584 mismatched pixels — merge 30,478, blast-first 21,101, skip-flush 11,349, row-end
1,656, **elsewhere 0**.

**3D — §3A/§3B confirmed.** `op` (11 = opaque) carries with identity 0: `clra`/`clr <xf_oc` at row start and after
a skip. Interior blast bytes pay nothing: their opacity is $FF on both halves (F[$FF] | C[$FF] = $FF in every
pair), so `XA_D` is unchanged and the blast's carry out is the per-pair constant, set once at its end (AC4).

**3E — AC11, the direct page.** `XF_DPPAGE*256 + 0..13` as before; **+14 `xf_oc`, +15 `xf_cc`, +16 `xf_fff`,
+17 `xf_cff`**. Header and both link maps say 18. **None is touched inside `XF_WINDOW`** — the window is `clra /
tfr a,dp / andcc / orcc / lda #XF_DPPAGE / tfr a,dp`, unchanged. Room: `$5F00-$5F11` in the gameplay builds
(`$5F0E-$5FFF` was free), `$2C00-$2C11` in the probe (its DP page holds nothing else).

**3F — AC12, the masked window.** Per row = call cycles / rows (the row body is the masked span; the window
itself ~16 cy). Widest gameplay stream w0 = 14 B (CHTAB1 #24, #25; CHTAB4.GD #26); worst case CHTAB4.GD #26,
mirrored, A=1: **679 → 829 cy per row**. At the measured 0.89 MHz that is 5.6% of a frame. **The VBL handler's
tolerance is not a documented number**: the GIME's IRQ is latched and served at the next row window, so a tick
is lost only if a masked span outlasts a frame. **The evidence is empirical: 0 ticks lost in 1,200 frames, one
and two actors** — measured, not argued.

**§2H.** (1) Second mechanism: two blitters on the gameplay path, `blit_cel_full` and `xf_blit` (P5.33); and
within `xf_blit` four `M` sites, not one, plus the A≠0 gate. (2) Calling routine: `kidrun_probe.s`/`char_probe.s`
→ `xf_blit` (A = phase, B = mirror|swap) → `blit_cel_full` for A=0 plain. (3) Prior reports grepped: P5.20 (the
derivation — "M is a self-modified operand because the loop already holds four pointers", why the new state is
DP bytes, not registers), P5.31 (DP=0 in the window), P5.33 (the residue). The clock finding contradicts the
cycle budgets of P5.31 (§3E there), P5.32 (§5) and P5.33 — all used 29,859.

### 4 — Verification (AC-by-AC)
- **AC1** — MET. 448/448; `XF_M` 16/16 (§3A).
- **AC2** — MET (§3B); §2's reading confirmed, plus the A≠0 gate.
- **AC3** — MET: 64,584/64,584 residual pixels at the four sites (§3C).
- **AC4** — MET: interior blast bytes pay 0; per blast +8 cy, first byte +16 cy (§5).
- **AC5** — MET: `blit_cel_full` 0/169 and `xm0` 0/295 still pass — **and their mean cycles are identical to the
  cycle** (17,032 and 10,998, before and after).
- **AC6** — MET: swap-only 0/126, shift 0/885, shift+mirror 0/885; 418/418 cels exact offline.
- **AC7** — MET: `--mask oracle` had dropped the 2,360 BASELINE cases (blit_cel_full drawing the reference
  re-encoded at each phase — a check of the reference generator and blit_cel, not of xf_blit); restored under
  the oracle model (`stream_oracle`). **4,720/4,720**: every (cel, PL) unit (295) × 2 facings × 4 phases, for
  both blitters — P5.29's coverage. (P5.20's 4,640 was 290 cels before P5.29 split dual-PL cels into units.)
- **AC8** — MET: `char` and `kidrun` GREEN, 512 KB; suites ALL PASS; 128 KB tile PASS. No allow-list, no
  re-baseline, no tolerance — the instrument is P5.33's, unchanged.
- **AC9** — MET: 13 steps EXACT; both-opaque cells 73 + 116 + 108 + 39 + 7 + 116 = **459, 0 wrong**; the guard's
  273-B frame 0 wrong at all 13.
- **AC10** — MET: the per-actor interleave control, rebuilt on this xf_blit: steps 15/16/17/19/21/40 wrong by
  **53/62/50/34/5/62 B, every one inside the guard's frame**; 12/22/46 exact. (P5.32: 59/73/53/37/7/73 — the
  counts moved because the guard now occludes the kid's border.) Reverted; source sha1 `AC77A36A…` restored.
- **AC11** — MET (§3E). **AC12** — MET (§3F). **AC13** — §5.
- **AC14** — MET: no re-bake; `git status content/chars` = 0 changes; offline 418/418 against the model.
- **AC15** — MET. **AC16** — pending Jay (§5). **AC17** — MET (`32b5fe2`). **AC18/AC19** — §6.

### 5 — Verdict-time evidence
**Cost (AC13).** Per byte, from the built listing (`opt c`): merge byte 57 → **89 cy** (+32); a blast's first
byte 43 → **59** (+16); interior blast byte **unchanged**; +8 per blast, +6 per skip and per row. Per draw,
measured over the probe's 2,360 xf_blit cases (P5.33's run vs this one, same cases):

| path | before | after |
|---|---:|---:|
| A=0 plain → blit_cel_full | 17,032 | 17,032 (+0.0%) |
| A=0 mirror, xm0 | 10,998 | 10,998 (+0.0%) |
| A=0 swap-only | 14,216 | 17,752 (+24.9%) |
| A>0 shift | 14,037 | 17,752 (+26.5%) |
| A>0 shift+mirror | 14,285 | 18,026 (+26.2%) |

Per step, 72 steps, `kr_nact` 1 and 2 (P5.32's figures, pre-border, in brackets):

| phase | one actor | two actors |
|---|---:|---:|
| seq / erase / save | 413 / 8,689 / 9,098 | 821 / 16,753 / 17,461 |
| **draw** | **22,342** [18,113] | **38,450** [33,372] |
| fore | 6,264 | 6,392 |
| **total** | **46,807** [42,549] | **79,880** [74,757] |
| worst step | 58,555 | 91,912 |
| cadence (oracle 9.65 fps) | 6.00 frames = 9.99 fps | **6.08 frames = 9.85 fps** |
| **share of the paced budget at the TRUE clock (6 × 14,930)** | 52% (worst 65%) | **89% (worst 103%)** |
| share as kidrun_cost.py prints it (29,859 — wrong clock) | 26.8% (max 37.0%) | 45.1% (max 60.1%) |

★ **What the "share of the oracle's own time" numbers are**: kidrun_cost.py divides by the oracle's one-actor
durations converted at 29,859 cy/frame. With the port at 0.89 MHz, the like-for-like share is DOUBLE the printed
figure: two actors ≈ 90% mean, 120% max of the oracle's time for the same frames.

**25.1 (verbatim excerpts):**
```
xf_opacity_premise: 28 tables (XF_T1, XF_T2, F and C of 13 pairs) x 16 opacity bytes = 448 checks: 0 fail
xf_opacity_premise: XF_M[v] == ~v over the 16 opacity bytes: 0 fail
mismatched pixels listed in the log: 64584   merge 30478  blast-first 21101  skip-flush 11349  row-end 1656  NOT at an M site: 0
=== BUILD COMPLETE ===    (prod sha1s unchanged)
[run_xform_probe] PASS   after: 4720 cases logged, 4720 ok  (xform 2360, base 2360)
kid run steps 6,12,13,15,16,17,19,21,22,24,26,40,46: 15360/15360 EXACT each; step 16: both opaque 116 B, 0 wrong
[run_char_test] PASS   15360/15360 EXACT
CONTROL (per-actor interleave): steps 15/16/17/19/21/40 guard frame 53/62/50/34/5/62 wrong; 12/22/46 EXACT
VBL actors=1  real frames 1200  HAL ticks 1200  LOST 0
VBL actors=2  real frames 1200  HAL ticks 1200  LOST 0
frames 600  cycles ... -> 14834 cycles per real frame   (1.79 MHz = 29,859; 0.89 MHz = 14,930)
[suites] running: introseq integ tile char kidrun ... [suites] ALL PASS     128 KB: tile ... ALL PASS
offline: cels 418, differing 0
```
25.2: N/A. **25.3: pending Jay** — live-disk, 512 KB, RGB, motion (`run_kidrun_live.sh`): does the guard
occlude the kid now (the border and the interior gaps), and does the cadence still feel right (9.85 fps, an
occasional seven-frame step — §top). PNGs from this build (surfaced, not read):
`build/kidrun_step{6,12,13,15,16,17,19,21,22,24,26,40,46}.png`.

### 6 — Reactive deviations and route accounting
- **The clock finding** — not asked for; found by refusing to attribute the cadence slip without measuring.
  Reported first; not fixed (§8.1).
- **Baseline cases restored** (AC7's "restore if possible").
- **The skip/row-end gate moved from colour to opacity** — beyond §2's four sites, the same defect class.

**AC18 — not proposed:** no cutscene change; no `lz_unpack` fix; no re-bake; no disk-map change; no
`blit_cel` change; **no fix to the clock in this dispatch**; no AutoCtrl.

**AC19 — route accounting.** P5.33 §6 proposed: *"read the mask too, op = ~mask, push op through the SAME F/C
tables, keep an opacity carry beside A, write dest = (dest AND M[out_op]) OR out; blasts op = $FF, skips op = 0;
a second carry needs a direct-page byte."* **This commit contains all of it**, plus: the blast's carry out as a
constant (the dispatch's §3B), the opacity-gated flush/row-end (§3B here), and a parked colour carry (`xf_cc`) —
four DP bytes, not one. The dispatch's killed routes (§10) were not revisited; nothing measured here reopens them.

### 7 — Uncertainty flags
- **The VBL tolerance** is empirical (0 lost in 1,200 frames), not a stated number (§3F).
- **The cadence at the true clock is marginal** (worst step 103% of the pace) — a third actor, or a busier
  screen, will slip further until the clock is fixed.
- MAME's wd_fdc and CPU timing, not a real CoCo.

### 8 — Follow-up candidates
1. **★ Restore double speed after `tile_probe`'s disk read** (`sta $FFD9` after `disk_read_range` in
   `load_track`; a register-owner row). Halves every step; re-baseline P5.31-P5.34's cost figures at the true clock.
2. The cost tool (`kidrun_cost.py`) should read the clock rather than assume 29,859.
3. Carried: the cutscene's model + `lz_unpack` together (§5.426); the disk map (§5.432).

### 9 — User interaction during task
None before the gate.

### 10 — Candidate(s) captured this task
None.

### 11 — Commit
`7cbe4a0` (pushed to origin/wip before the gate; this line in the follow-up commit). `main` untouched.
