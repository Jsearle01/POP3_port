## Form B Report — P5.27 — the character bake (C): 290 gameplay cels and 128 guard-set cels promoted to content, and P5.20's probe re-run on them returns 4,640/4,640 with identical cycle counts

**Class:** build — content conversion. `wip`. **Prod byte-identical** (§0). `probe.dmk` unchanged. No
engine, no integration, no scheduling, no `blit_cel` change, no track constants.

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-10-04T15:04:24-04:00 (HEAD **`d23b244`**, wip, as the dispatch was drafted; `main`
**`32b5fe2`**). Tracked tree clean.

**AC1 — receipt vs a full rebuild at the end:**
```
08bcae4a6249828a64554c61db9ed7ace72e4081  intro_seq.bin      IDENTICAL
10bddbd5413d14b1fbf26aeadb874515fc32b3e8  loader.bin         IDENTICAL
d5b17b6d468f1bcdd66163a60d9ffa1e36197e15  cutscene_room.bin  IDENTICAL
6c8d6e980c53eaa24d83eb383923f5a0568e4256  probe.dmk          IDENTICAL
92dc6d96778c71056ca37524779a5bcd1d61643c  flame_cels.bin     IDENTICAL
```
**AC12 — `main` = `32b5fe2` at both ends.**

---

### 1 — Summary

**The shipping artifact now exists and it is P5.20's reference, byte for byte.** `content/chars/` holds
418 cels: P5.20's 290 (CHTAB1/2/3/4.GD/5) plus the four other guard sets (FAT, SHAD, SKEL, VIZ), which
are vendored, so §5.341's estimate for them is now a measurement. Each cel has a pixel file (`_src.s`,
§2F's home) and its facing-0 phase-0 segment stream (`_p0.s`, the shipping artifact). A registry
(`char_cels.s`) carries `apple_w` per cel in a side table.

**Correctness is inherited, not re-argued:**
- All 290 streams equal P5.20's `_src` and `_r00` streams, read from P5.20's own census batches.
- Their concatenation equals P5.22's `cast_seg.bin` byte for byte.
- **P5.20's probe, re-run on the baked files with `apple_w` read from the registry, returns 4,640/4,640.
  Every case has the same verdict and the same cycle count as P5.20's run.**

**Size: exactly as §5.338 priced it.** 91,906 B of stream → 41,426 B LZ → 9 tracks, a delta of zero.
**But 41,426 B is only 46 B under 9 tracks.** Of the nine P1.2 cels, 7 reproduce byte-identically. 2 differ
by exactly one leading blank byte column, which is P3.103's intended removal of leading trim.

---

### 2 — Files modified

- `harness/tools/bake_chars.py` — **new.** The bake: `sprite_convert` → `cel_blit_prep` phase 0, the
  same calls P5.20's generator made, plus the registry.
- `harness/tools/bake_chars_check.py` — **new.** The checks against P5.20's and P5.22's artifacts, AC7's
  control, and the sizes, through `disk_capacity.lz` (imported, not copied).
- `harness/tools/char_closure_set.py` — **new.** Exposes P5.9's 271-cel closure as a set by running
  `peak_residency.main()` unchanged.
- `harness/tools/xform_probe_gen.py` — `--baked` (draw the committed stream, `apple_w` from the
  registry) and `--all-guards`. The non-`--baked` path is unchanged in output (§3D).
- `content/chars/` — **new**:
  - `char_cels.s`;
  - per table, `<tab>/<tab>_<nnn>_src.s` and `_p0.s` for 418 cels, i.e. 836 files over nine tables.
  - All generated, LF, UTF-8.
- `mame-idioms-coco3-port.md` — **§44** (§6 of the dispatch).
- This report.

Nothing under `src/`, `link/`, `content/kid`, `content/guard`, `content/cutscene`, or `build.bat`.
Explicit-path staging.

---

### 3 — Reasoning

#### 3A — AC2: the set — 290, both priced

*Authority: source, via P5.9's own tool (`peak_residency.py`, run unchanged).*

`char_closure_set.py` captures the W∞ kid ∪ guard union that `peak_residency` prints as *"271 cels,
61195 B"*. **It is a strict subset of the 290: 19 extra, 0 missing.**

| set | cels | stream B | LZ B | tracks |
|---|---|---|---|---|
| **290** (baked) | 290 | **91,906** | **41,426** | **9** |
| 271 (closure) | 271 | 88,334 | 39,941 | 9 |
| the 19 | 19 | 3,572 | 1,485 | — |

**I baked the 290.** The 19 cost 1,485 B of LZ and **no track** (both sets are 9). And the closure does
not prove them dead. §2H's first check, a second mechanism, applies here:
- **5 of the 19 are named by frame definitions the closure never reached:** CHTAB2 #68–70 (Fdef
  f186–188), CHTAB5 #35 (Fdef f206) and CHTAB4.GD #25 (ALTSET1 f177).
- **The other 14 are named by NO frame definition at all:** CHTAB1 #65; CHTAB2 #36; CHTAB3 #13–18, #28,
  #37, #73; CHTAB4.GD #24; CHTAB5 #16, #45.
- A cel that no frame names is either unused or drawn by code outside the sequence/frame mechanism. P5.9's
  closure models only that mechanism. I have not searched the source for direct draws (§7.1).

**The 19, if they are dead, are 1,485 B. That is not worth deciding before the loader exists.**

#### 3B — AC3: the guard sets — vendored, baked, measured

`IMG.CHTAB4.FAT/SHAD/SKEL/VIZ` are all in `oracle/source/01 POP Source/Images`. **All four were baked: 32
cels each, 128 in total.** The figures are in §3F. The bake passed the same probe (§3E).

#### 3C — AC4: `apple_w`, in a side table

- **The choice: `apple_w`, the source fact, not `d`.** Three reasons:
  1. **It is the precedent.** `content/cutscene/cel_table.s` +4 already carries *"Apple sprite WIDTH in
     bytes … the mirror anchor"* (P3.72g), for the same reason. §2H's third check found it. The
     dispatch's "no view worth imposing" was in fact settled at P3.72g.
  2. **It carries more than `d`.** It gives `d = 4·w0 − 7·apple_w`, with `w0` already in the stream
     header, AND the parity-swap rule (swap iff `7·apple_w` is even).
  3. **Deriving `d` costs one ×7 per draw.** That is against a draw of thousands of cycles.
- **Location: a side table, `content/chars/char_cels.s`.** Per table, `<tab>_n equ` plus `<tab>_aw`, one
  byte per image slot. **Cost: 418 B for all nine tables (290 B for the gameplay five).** No table has
  an empty slot, so there are no padding bytes. **No stream header changed, and `blit_cel` was not
  touched.**
- **The dispatch's reading of the header holds, with one correction.**
  `content/kid/kid_chtab1_064_thin/converted.s:14` is a **pixel** file's header (`sprite_convert`
  output), not a segment stream's. The stream header (`cel_blit_prep`'s `fcb h,w`) is also two bytes
  with no `apple_w`, so the conclusion is the same.
- **★ `d` runs −6…+3 over the 290, not −3…+1.** P5.20 §3B gave −3…+1 *"over the sample"* (8 cels). The
  census, among the 290:

  | d | −6 | −5 | −4 | −3 | −2 | −1 | 0 | +1 | +2 | +3 |
  |---|---|---|---|---|---|---|---|---|---|---|
  | cels | 2 | 10 | 14 | 15 | 25 | 57 | 61 | 30 | 49 | 27 |

  Every value passed the probe. An integrated mirror's clip must allow −6…+3 (§7.2). The 151 cels needing
  the swap match P5.20's 151 exactly.

#### 3D — AC5 + AC7: correctness against artifacts already on disk

*Authority: P5.20's census batches (`build/xform/b000–b103_gen.s`, 104 files, written 2026-10-01
18:52), P5.20's logs, and P5.22's `build/p522/cast_seg.bin`. These are not this dispatch's own
regeneration of them.*

```
AC5 — 104 batches; 290 `_src` streams, 290 `_r00` references found
   ★ 290 / 290 gameplay cels byte-exact against BOTH P5.20 streams
AC5 — bake 91906 B, blob 91906 B: BYTE-IDENTICAL          (P5.22's cast_seg.bin)
```

**AC7, the control:** the nine P1.2 cels, re-converted today by the identical call:

| cel | file | pixels, P1.2 vs today | today vs bake |
|---|---|---|---|
| 7 of 9 | **IDENTICAL** | IDENTICAL | IDENTICAL |
| `kid_chtab1_047_median` | DIFFER | 40×5 → **40×6** | IDENTICAL |
| `guard_gd_001_median` | DIFFER | 36×8 → **36×9** | IDENTICAL |

**The two differences are explained, mechanically checked, and intended.** In each, today's pixels are
P1.2's with **one all-zero leading byte column restored**, and the check verified exactly that. P1.2's log
shows both trimmed `lead=1`, and the P3.103 fix stopped trimming leading columns:
`sprite_convert.py:386` asserts `lead == 0`, because a leading trim *"displaces the cel by 4·L px"* and
nothing compensated. **So the pipeline did move, deliberately, at P3.103, and those two committed P1.2
samples predate it.** The bake has the corrected form. **The P1.2 files were not overwritten.**
`run_cel_test.sh` and `run_compiled_test.sh` point at them, and they are not mine to rule on (§2B; §8.3).

**Separately, the generator's non-baked path still matches P5.20.** The case records (§3E) and the
`_r00` references are unchanged.

#### 3E — AC6: P5.20's probe, re-run on the BAKED cels

**Harness change (in scope per §4.3):** `xform_probe_gen.py --baked` draws
`content/chars/<tab>/<tab>_<nnn>_p0.s` as committed, parsed from the file. It reads `apple_w` from
`char_cels.s`, so **`d` and the swap now come from the registry**, while `w0` comes from the baked header.
The reference is still generated exactly as at P5.20.

```
AC6 (static) — 4640 cases before, 4640 after; same case set: True;
               differing in want/col/A/B/h/stream/fn: 0
run_xform_probe.sh --all-gameplay --baked (XF_PREFIX=k, 512K): 106 batches, each "PASS all N cases";
               [run_xform_probe] PASS
AC6 — P5.20: 4640 cases, 4640 ok    baked: 4640 cases, 4640 ok
      verdict identical per case: 4640 / 4640    cycle count identical per case: 4640 / 4640
```

**The result is unchanged: 4,640/4,640, and down to the cycle.** That is the strongest form of
"unchanged" available. The batch count is 106, not 104, because P5.21 widened the case record from 10
to 12 bytes. Packing is not a result.

**Guard sets, same instrument:** `run_xform_probe.sh --all-guards --baked` (XF_PREFIX=g):
**128 cels, 2,048 cases (8 base + 8 transformed each), 50 batches, all byte-exact, 0 mismatches.**
P5.20 has no run of these to compare cycles against, so this is a first measurement rather than an
unchanged one.

#### 3F — AC8/AC9: size, in §5.338's unit

*Stream B = `[h,w]` + segments per cel; LZ = `lz_pack` in 8,192 B chunks (`disk_capacity.lz`); a track
is 4,608 B. ★ These are DISK figures. They are not residency and not draw volume.*

| | cels | stream B | LZ B | ratio | tracks |
|---|---|---|---|---|---|
| **gameplay 290, one run** | 290 | **91,906** | **41,426** | 2.22 | **9** |
| ★ delta vs §5.338 | | **+0** | **+0** | | **+0** |
| CHTAB1 | 65 | 22,525 | 10,320 | 2.18 | 3 |
| CHTAB2 | 70 | 23,753 | 9,962 | 2.38 | 3 |
| CHTAB3 | 78 | 16,898 | 7,302 | 2.31 | 2 |
| CHTAB4.GD | 32 | 12,612 | 6,458 | 1.95 | 2 |
| CHTAB5 | 45 | 16,118 | 7,331 | 2.20 | 2 |
| *five tables, LZ'd separately, summed* | 290 | 91,906 | 41,373 | | *9 if packed; **12** if each starts on a track* |
| CHTAB4.FAT | 32 | 12,853 | 6,292 | 2.04 | 2 |
| CHTAB4.SHAD | 32 | 11,643 | 5,473 | 2.13 | 2 |
| CHTAB4.SKEL | 32 | 8,959 | 4,863 | 1.84 | 2 |
| CHTAB4.VIZ | 32 | 12,621 | 6,324 | 2.00 | 2 |
| **guard sets, one run** | 128 | 46,076 | **22,449** | 2.05 | **5** |

What this means for the disk map; **these numbers are Jay's to know, not mine to solve:**
1. **The cast is 9 tracks with 46 B to spare** (9 × 4,608 = 41,472). §5.341's tracks 13–22 hold it.
   **Any growth at all, a tenth track's worth or one byte over, takes side B's two-track margin**
   [§5.337].
2. **§5.341 reserved 5 tracks (23–27) for the guard sets, and one run of all four measures 5 tracks with
   591 B spare.** The estimate holds.
3. **The per-level shape costs tracks.** A level needs CHTAB1/2/3/5 plus ONE CHTAB4 variant. **Laid out
   one table per track-aligned span, the five gameplay tables take 12 tracks, not 9, and the guard sets 8,
   not 5.** §5.341 assumes the cast is one span. **If the loader wants per-table spans, side B's
   arithmetic changes by +3 (+6 with the guard sets).**

---

### 4 — Verification (AC-by-AC)

- **AC1** — §0, five sha1s identical after a full rebuild.
- **AC2** — §3A: 290, with the reason; 271 priced (39,941 B LZ, also 9 tracks); the 19 listed.
- **AC3** — §3B: all four guard sets baked and measured.
- **AC4** — §3C: `apple_w`, in a side table, 418 B (290 B for the gameplay five); no header change.
- **AC5** — §3D: 290/290 against P5.20's `_src` and `_r00`; the concatenation is byte-identical to
  P5.22's blob.
- **AC6** — §3E: **4,640/4,640, with identical verdicts and identical cycle counts per case.**
- **AC7** — §3D: 7/9 file-identical; 2 differ by P3.103's restored leading column, verified mechanically.
- **AC8** — §3F: **91,906 / 41,426 / 9, a delta of zero**, with 46 B of track spare.
- **AC9** — §3F: per table.
- **AC10** — §44 added (§2 above).
- **AC11** — **512 KB first: `introseq` PASS, `integ` PASS, `tile` PASS, ALL PASS; then 128 KB: `tile`
  PASS, ALL PASS.**
- **AC12** — §0.
- **AC13** — §6.
- **AC14** — §6.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim):**
```
build.bat:
[hal-sync] OK -- HAL source aligned with karateka_coco3, coco_agi (11 files compared, EOL/guard/export-placement normalised)
# VERDICT: PASS - every file on the image matches its artefact.
=== BUILD COMPLETE ===

run_suites.sh (MAME_RAM default 512K): [run_introseq_test] PASS / [integ] PASS / [run_tile_test] PASS / [suites] ALL PASS
run_suites.sh (MAME_RAM=128K):         [run_tile_test] PASS / [suites] ALL PASS

bake_chars.py:  IMG.CHTAB1 65 cels 22525 / CHTAB2 70 23753 / CHTAB3 78 16898 / CHTAB4.GD 32 12612 /
                CHTAB5 45 16118 / FAT 32 12853 / SHAD 32 11643 / SKEL 32 8959 / VIZ 32 12621 -> 418 cels
bake_chars_check.py: PASS        (full output quoted in §3D-§3F)
run_xform_probe.sh --all-gameplay --baked: [run_xform_probe] PASS (106 batches)
run_xform_probe.sh --all-guards --baked:   50 x "PASS all N cases" (2,048 total); [run_xform_probe] PASS
```
**25.2:** N/A — ROM build, no sibling-import artifact.
**25.3:** N/A. Nothing on screen changed, and no content is integrated.

### 6 — Reactive deviations, non-proposals, and route accounting

**Deviations:**
1. **The guard sets were probed as well as baked** (128 cels, 2,048 cases). The dispatch asked only to
   bake them, but they are new content with no prior check.
2. **§44 says four lines, not three.** The third hazard (Python's cp1252 default) was found during this
   bake, in already-committed cutscene streams, so it belonged in the same entry.
3. **A tracked helper, `char_closure_set.py`,** because the 271 set existed only as a printed count.

**AC13 — not proposed:**
1. **No integration, scheduling or paging.** `cel_pack.py` was not used (§10).
2. No `blit_cel` change, no stream-header change, no track constants, nothing on a two-sided image.
3. **Not re-converting the two stale P1.2 samples** (§3D, §8.3).
4. **Not dropping the 19 cels** (§3A).
5. Not normalising the cutscene streams' cp1252 `0x97` bytes (§44); they are comments, and the files ship.

**ROUTE ACCOUNTING.** I proposed no route before this task. Within it I named four things and did all four:
- the bake;
- the registry in a side table;
- the probe re-run through `--baked`;
- the size measurement in §5.338's unit.

### 7 — Uncertainty flags

1. **The 19 cels' liveness** (§3A). 14 are named by no frame definition. Whether something draws them
   directly is unsearched.
2. **`d` spans −6…+3.** An integrated mirror's clip window and placement arithmetic must cover the full
   range. P5.20's −3…+1 was a sample range and should not be carried as the census one.
3. **The 46 B of track spare** (§3F.1) is a coincidence of the current content, not a margin anyone
   designed.

### 8 — Follow-up candidates

1. **The 19:** a source search for direct draws of CHTAB1–5 images outside the frame tables.
2. **The side-B map:** one span or per-table spans (+3 / +6 tracks, §3F.3). That decides whether §5.341
   holds.
3. **`content/kid`, `content/guard`:** two of the nine P1.2 samples predate P3.103. Re-convert or retire
   them, at Jay's ruling. Two smoke tests use them as fixtures.
4. **`docs/project/protection-catalog.md` does not exist** (CLAUDE.md §2B: *"start the catalog when POP's
   first authored/altered asset appears"*). The bake is fully generated, so nothing here needs a catalog
   entry, but the read point names a missing file.
5. `xform_probe_gen.py`'s docstring still says *"10-byte record"*; it has been 12 since P5.21.

### 9 — User interaction during task

None.

### 10 — Candidate(s) captured this task

None.

### 11 — Commit

**`2da164b`** (843 files: 837 under `content/chars/`, four tools, the idioms file, this report). This
hash line follows in its own commit. Pushed to `origin/wip`. `main` untouched at `32b5fe2`.
