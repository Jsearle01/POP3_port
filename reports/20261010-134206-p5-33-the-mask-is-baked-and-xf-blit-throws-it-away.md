## Form B Report — P5.33 — the character mask: the prediction moved and failed, the bake is right, and xf_blit discards it — STOPPED (§9)
**Class:** build. wip. **STOPPED at §9's tripwire, before the re-gate.** Prod byte-identical — `intro_seq.bin`
`08BCAE4A…`, `loader.bin` `10BDDBD5…`, `cutscene_room.bin` `D5B17B6D…`, `flame_cels.bin` `92DC6D96…`, sha1 at
t0 and on a fresh build at the stop. **The cutscene has not moved.** `main` `32b5fe2` at both ends.

### 0 — Receipt / status (C-35 stamp)
t0=2026-10-10 13:26:17 (HEAD `0ea4e78`, wip — as drafted). git status clean of tracked changes; prod sha1s above.

### 1 — Summary
Done in the dispatch's order. **(1) The predictions moved to the oracle's model** — a new `char_mask.py` reads
`MASKTAB` and `MIRROR` literally out of HRTABLES.S and composites each character pixel by pixel the way
`LayMask`/`MLayMask` do; the kid-run, character-probe and transform-probe references all use it. **(2) Against
the UNCHANGED bake they fail (AC1):** the kid-run's 13 steps by 11-50 bytes each, the `char` suite by 63, the
transform probe 2,315 of 2,360 cases. **(3) The border is baked** — arithmetic dilation per 7-px source byte,
emitted as merge pairs (mask 00, src 00), `encode_row` and `blit_cel` unchanged. **The bake is exact against
the oracle model for all 418 cels**, and every probe case drawn by a path that honours the stream's mask is
exact (464/464: `blit_cel_full` and `xf_blit`'s mirror-alone path). **(4) It does not reach the screen whole,
because `xf_blit`'s shift and swap paths rebuild the merge mask from the source byte** — index-0 transparency,
by construction [xf_blit.s:73-76] — so they drop the border: 1,863 of 1,896 such cases still fail, the kid
run by 1-8 bytes a step, `char` by 24. **§9: "If that distinction stops holding, stop and say so."** It stopped
holding — for gameplay, `xf_blit` IS the blitter, and to it index 0 means transparent. Stopped; not gated.

### 2 — Files modified
- `harness/tools/char_mask.py` — NEW. The oracle model: MASKTAB/MIRROR parsed from HRTABLES.S; `cleared()`
  (the oracle's route, byte by byte, mirrored via MIRROR); `compose()` (pixel-level composite); a self-check
  of MASKTAB against arithmetic dilation and MIRROR against a 7-bit reversal (both IDENTICAL, 128/128).
- `harness/tools/kidrun_plan.py` — the kid's and the guard's references composited through `char_mask`; no
  segment stream in the prediction; the both-opaque set from the composite.
- `harness/tools/char_probe_plan.py` — the reference through `char_mask`; the draw-vs-draw clearance test on
  OPAQUE BYTES instead of frames (§3E).
- `harness/tools/xform_probe_gen.py` — `--mask oracle`: the expected framebuffer composited by `char_mask`
  (`expect_oracle`); baseline cases dropped under it.
- `harness/tools/bake_chars.py` — `border_rows()` (the border, by arithmetic), `stream_bytes()` with its own
  replay gate over the border; header: the two-models warning (AC10).
- `content/chars/**/<tab>_<nnn>_p0.s` (418) and `content/chars/char_cels.s` — re-baked. **No `_src.s`
  changed** (0 of 418): the pixel home is untouched; the border is a draw rule computed from the Apple bytes.
- `harness/tools/cel_blit_prep.py`, `harness/tools/bake_scene.py` — docstrings only: the two-models warning
  where a reader of the shared encoder or the cutscene bake will hit it (AC10). No code change.

### 3 — Reasoning

**3A — The mechanism, from the source (AC3 and the model)**. `DrawNormal` [GAMEBG.S:432-437] `lda #mask / sta
OPACITY`; `DRAWGUARD` → `DrawNormal`/`DrawShifted`, both `#mask`. `LayMask` [HIRES.S:945-961] takes `MASKTAB` of
the **unshifted image byte** (`lda MASKTAB-$80,x`) and shifts it through the SAME SHIFT/CARRY tables as the
image, so the border is a property of the cel's own 7-px source bytes, independent of screen position — one
baked stream per cel CAN carry it exactly. `MLayMask` [HIRES.S:1463-1489] does the same on `MIRROR[byte]`.
MASKTAB [HRTABLES.S:219-234]: `$01 → $FC`, `$02 → $F8`; **all 128 entries equal ~(b | b<<1 | b>>1) within 7
bits**, and MIRROR equals a 7-bit reversal — so the border is symmetric and mirrors with the cel. **Every one
of the 53,577 gameplay + guard cel bytes has bit 7 set**, so `MASKTAB-$80,x` / `MIRROR-$80,x` never index
outside their tables (the oracle's byte < $80 path would read the previous table). **AC3, 1:1 pixels:**
`convert_sprite_to_coco3` maps Apple column `byte·7+bit` to port pixel column `col`, `width_pixels =
7·apple_w`, and `--mirror` reverses that list — MLAY's `c ↔ 7aw−1−c`. One Apple pixel of border is one port
pixel. Authority: source, and the converter's code (not its comments).

**3B — The model, not the route (§9)**. The prediction takes MASKTAB **literally from HRTABLES.S** and walks the
oracle's byte route (MIRROR first when mirrored); it composites pixels and never touches a segment stream. The
bake computes the border by **arithmetic** and encodes it. The two agree on all 128 bytes by the self-check —
so they are two derivations of one oracle fact, and a disagreement would show as a byte error.

**3C — AC1, the failing run (against the bake as it stood at t0):**

| instrument | result |
|---|---|
| kid run, 13 steps | **all 13 FAIL**: 11, 16, 16, 42, 50, 35, 30, 16, 12, 14, 11, 50, 12 B (steps 6..46). The guard's frame is 11 B wrong at every step (his border against the dungeon); at step 16, 43 of 116 both-opaque cells wrong |
| `char` suite | **FAIL, 63 B** |
| transform probe, 290 cels / 295 uses, `--baked --mask oracle` | **FAIL, 2,315 of 2,360 cases**; sample `got 2 want 0` — background where the oracle draws black |

**3D — The bake, and where it holds.** `border_rows()` marks a pixel 4 (OPAQUE BLACK) where the cel is 0 and the
dilation of its source byte is set; `encode_row` needs no change (non-zero = opaque; `&3` packs 4 as 0; the merge
mask keeps dest only at 0) — so a border pixel is a merge pair with mask bits CLEARED and src bits ZERO, §3's
expression. Index 0 still means transparent to `blit_cel`. Streams widen past the trailing trim where the border
reaches (cel #15: w0 3 → 4); the registry's `d = 4·w0 − 7·aw` follows. **Offline, every one of the 418 baked
streams replays (cel_blit_prep.simulate, hostile background) byte-exact against `char_mask.compose`.** On the
6809, by the path `xf_blit` actually takes (classified by the A and B it is CALLED with — a mirrored case's
phase is `(4·C_REF + k − d) mod 4`, not the reference's k):

| xf_blit path | before the bake | after the bake |
|---|---|---|
| A=0 plain → `blit_cel_full` (the stream's mask) | 164 / 169 fail | **0 / 169** |
| A=0 mirror, `xm0` (`T[mask]`: the stream's mask) | 288 / 295 fail | **0 / 295** |
| A=0 swap-only — ascending loop, `M[out]` | 126 / 126 | **126 / 126 fail** |
| A>0 shift — ascending loop, `M[out]` | 867 / 885 | **867 / 885 fail** |
| A>0 shift+mirror — descending loop, `M[out]` | 870 / 885 | **870 / 885 fail** |

**3E — WHY IT STOPS: xf_blit rebuilds the mask from the source.** Its own header [xf_blit.s:73-76]: *"Transparency
is index 0 with no sidecar (P3.18 3B), so a merge's (mask,src) pair carries nothing the src byte does not … An
output byte is therefore written as dest = (dest AND M[out]) OR out, M = '11 where the pixel is 0'."* The
`XA_R`/`XD_R` bodies read **only the src byte** (`ldb 1,u`) of a merge pair and mask with `M[out]`; the mask byte
the bake carefully cleared is never read. Only `xm0_merge` reads it. Interior BLAST bytes are stored directly,
which is why most of the border survives and the screen residue is 1-8 bytes per step, not the whole border.
That premise was true when written — and is now false for gameplay streams. **This is a blitter change, and
§3/§9 say a blitter change is a different dispatch: stopped.**

Also in this step — not a deviation in substance: the character probe's clearance test refused its own placement
table after the bake (`mirrored` frame 41..45 touching `shifted`'s 37..41: cel #15's new byte is transparent
padding; `shifted`'s last opaque byte is 40, `mirrored`'s first is 42). The test exists to keep the picture
independent of draw order, so it now compares the draws' **opaque bytes** (from the oracle composite), not their
frames. The gated placement table was not touched.

**§2H.** (1) Second mechanism: there are TWO blitters on the gameplay path — `blit_cel_full` (honours masks) and
`xf_blit` (rebuilds them) — and the first-found one (the format, §3) was not the governing one; the bake was right
and the transform was not. (2) Calling routine: `kidrun_probe.s`/`char_probe.s` call `xf_blit` with A = phase,
B = mirror|swap; `xf_blit` delegates A=0 plain to `blit_cel_full`. (3) Prior reports: P3.18 §3B (the index-0
choice), P5.20 (xf_blit's derivation — its "nothing the src byte does not" is the premise that broke), P5.27
(the bake, the 46-B margin), P5.32 (the gate).

### 4 — Verification (AC-by-AC)
- **AC1** — **MET.** The corrected prediction against the unchanged bake: kid run 13/13 FAIL (11-50 B), `char` 63 B,
  probe 2,315/2,360 (§3C).
- **AC2** — **MET.** The four prod sha1s identical at t0 and on a fresh build at the stop; the cutscene's bake and
  bundles untouched.
- **AC3** — **MET** (§3A), from the converter's code.
- **AC4** — **MET.** Border = merge pairs, mask 00 / src 00; `blit_cel` and `cel_blit_prep`'s encoder unchanged
  (docstring only). **But xf_blit discards it on four of its five paths (§3E) — the reason for the stop.**
- **AC5** — **PARTIAL.** 418/418 baked cels byte-exact against the corrected reference offline; on the 6809,
  464/464 cases on the mask-honouring paths; 1,863/1,896 FAIL on xf_blit's `M[out]` paths.
- **AC6** — **NOT MET** (residue). Kid run after the bake: steps 6, 12, 26 EXACT; 13/15/16/17/19/21/22/24/40/46
  differ by 5/5/5/8/7/2/1/3/5/1 B; at the overlap: step 16 116 both-opaque cells, 1 wrong; step 17 108, 3 wrong.
- **AC7** — **NOT RUN.** The control's question (does the overlap test still discriminate) is about a finished fix.
- **AC8** — **MET** (§5).
- **AC9** — **NOT MEASURED.** A cost of a draw that is not yet correct would be the wrong number; the merge cost
  is in §5 as bytes.
- **AC10** — **MET.** The two-models warning in `bake_chars.py` (the gameplay bake), `bake_scene.py` (the
  cutscene bake), `cel_blit_prep.py` (the encoder both use), and `char_mask.py`.
- **AC11** — **NOT RUN.** Stopped before the re-gate.
- **AC12** — 512 KB: introseq, integ, tile PASS; **char FAIL (24 B), kidrun FAIL (5 B)** — the residue, now
  visible because the instrument is honest. 128 KB: tile PASS.
- **AC13** — **MET.** `main` `32b5fe2` at both ends.
- **AC14/AC15** — §6.

### 5 — Verdict-time evidence
**Size (AC8)** — §5.338's unit: segment-stream bytes ([h,w]+segments), lz_pack in 8,192 B chunks, 4,608-B tracks
(`bake_chars_check.py`'s size section; its P5.20-comparison sections now report DIFFER by design — they compare
against P5.20's index-0 streams):

| | P5.27 | P5.33 | Δ |
|---|---:|---:|---:|
| gameplay 290, stream | 91,906 | **97,696** | +5,790 (+6.3%) |
| gameplay 290, LZ | 41,426 | **43,723** | +2,297 |
| **gameplay tracks (one span)** | 9 (46 B spare) | **10** | **+1 — the margin is crossed** |
| guard sets FAT/SHAD/SKEL/VIZ, one run, LZ | 22,449 (5 tracks) | **23,780 (6 tracks)** | +1 |
| per-table spans: gameplay 5 tables / guard sets 4 | 12 / 8 tracks | **12 / 8 tracks** | **0** |

**Against §5.341's map:** as ONE span each, the cast and the guard sets need 10 + 6 instead of 9 + 5 — **both of
side B's two spare tracks** [§5.337], on a side where 13 of 33 tracks are still estimates. **As per-table spans
(P5.27 §3F.3), nothing moves**: every table's growth fits inside its own track padding. The disk-map choice is
not this dispatch's.

**25.1 (verbatim excerpts):**
```
char_mask: MASKTAB[$01]=$FC [$02]=$F8 (dispatch: $FC, $F8)
char_mask: MASKTAB vs arithmetic dilation, 128 bytes: IDENTICAL
char_mask: MIRROR vs a 7-bit reversal, 128 bytes: IDENTICAL

[AC1 -- bake unchanged]
  step 16  15310/15360 identical, 50 differ  -> DIFFERS   guard frame 49 wrong   both opaque 43 of 116 wrong
  char     15297/15360 identical, 63 differ  -> DIFFERS
  xform    m000..m014: FAIL 2,315 of 2,360 cases differ from the reference

bake_chars: 418 cels -> content\chars          (_src.s changed: 0)
offline: cels 418, differing 0                 (baked stream replay vs char_mask.compose)
   gameplay 290 (CHTAB1/2/3/4.GD/5), tag order     290 cels    97696 B  -> lz  43723 B   2.23x   22 -> 10 tracks

[after the bake]
  steps 6, 12, 26   15360/15360 EXACT
  step 16  15355/15360 identical, 5 differ   guard frame 4 wrong   both opaque 1 of 116 wrong
  char     15336/15360 identical, 24 differ
  xform    A=0 plain 0/169 fail, A=0 mirror 0/295 fail; swap-only 126/126, A>0 shift 867/885,
           A>0 shift+mirror 870/885 fail  (all three: xf_blit's M[out])
[suites] 512K: introseq PASS  integ PASS  tile PASS  char FAIL  kidrun FAIL;  128K: tile PASS
```
25.2: N/A. **25.3: NOT RUN — stopped before the re-gate (§9).** PNGs from the post-bake captures exist at
`build/kidrun_step*.png` (surfaced, not read); they show a partial fix and are not a gate.

### 6 — Reactive deviations and route accounting
- **STOPPED at §9** (§3E). Not done: AC6/AC7/AC9/AC11 to completion.
- **The character probe's clearance test moved from frames to opaque bytes** (§3E) — to keep a gated placement
  table untouched.
- **The transform probe gained `--mask oracle`** — the dispatch's AC5 named "every baked cel"; P5.20's probe is
  the instrument that exercises every cel through every phase and facing.

**AC14 — not proposed:** no cutscene change; no `lz_unpack` fix; no `blit_cel` change; **no `xf_blit` change in
this dispatch**; no peel-skip, no stagger; nothing on the disk map.

**AC15 — route accounting.** The dispatch's route: move the prediction → fail → bake → re-run → re-gate. **This
commit contains the first three in full and the fourth as a measurement of a partial result; the re-gate is not
done.** A route for the remainder, PROPOSED, NOT IMPLEMENTED: **carry the stream's mask through xf_blit's shift**
— for a merge byte read the mask too, take `op = ~mask` (11 where opaque), push `op` through the SAME F/C tables
as the src (its pixel pairs are 00/11, which every table — shift, mirror, swap — maps to themselves), keep an
opacity carry beside A, and write `dest = (dest AND M[out_op]) OR out` — `M[out_op]` is exactly `~out_op`, so the
existing `XF_M` table serves. Blasts are op = $FF, skips op = 0. A second carry needs a direct-page byte (the four
pointers and A are taken); cost to be measured, per `R` byte. That is a P5.20-scale change to a measured routine
and wants its own dispatch and its own probe run.

### 7 — Uncertainty flags
- **The residue's size on screen**: 1-8 bytes per step on the kid run. Whether that is visible in motion is
  Jay's to say; the border mostly survives through blast bytes.
- **The palette bit**: MASKTAB returns bit 7 set, so the AND keeps the screen byte's hibit — on the Apple that
  changes how the background beside the character renders; the port's background does not share that and it is
  not modelled (char_mask.py header).
- **The P5.20/P5.27 probe logs (`b###`, `k###`) and `bake_chars_check.py`'s comparisons** are now against the
  old model by design; nothing was deleted.

### 8 — Follow-up candidates
1. **xf_blit carries the stream's mask** (§6's route) — the remainder of this fix; then this dispatch's AC6/AC7/
   AC9/AC11 on it.
2. The disk map: one span (+2 tracks, side B's whole margin) vs per-table spans (+0) — §5.
3. Carried, unchanged: the cutscene's model and the `lz_unpack` 256-count fix move together (§2; `bake_scene.py`).

### 9 — User interaction during task
None.

### 10 — Candidate(s) captured this task
None.

### 11 — Commit
(the follow-up commit carries this line)
