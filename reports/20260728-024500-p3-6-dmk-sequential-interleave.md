## Form B Report — P3.6 — DMK with sequential interleave: the intro load drops 2.5×
**Class:** BUILD — disk container + interleave. POP `wip`. **Karateka UNTOUCHED**
(read-only reference only): `wip` `9f68eaa`, `main` `5eb92b1`, prod binary
`88eba89b15cdf17c8d25e082d2d3e1f3cce57d38` — held. Sync bridge green; **0 files**
changed under `src/`.
**Result: 51.4 s → 21.3 s to first frame (2.41×), byte-for-byte identical, whole
suite green.**

### 0 — Receipt / status (C-35 stamp)
**No dispatch receipt exists for this task** — it began from Jay's instruction to
check what Karateka does about read times, then "yeah lets do it". Recording the
provenance I actually have rather than a stamp I did not take:
start HEAD `a17b2c4` (wip, tracked tree clean), 2026-07-28 ~02:00Z.
Karateka at start: `wip` `9f68eaa`, `main` `5eb92b1`.

---

### 1 — Summary

**The 3.31 s/track was the container, not the loader.** MAME's `coco_jvc` carries
no physical sector order, so MAME synthesises one, and it is near-pessimal for a
whole-track read. DMK preserves the order imgtool authors, and **sequential
(interleave 0) is the fastest** — which inverts the RS-DOS convention.

| | |
|---|---|
| Cause | JVC has no physical order; MAME's synthesised one ≈ 0.89 rev/**sector** |
| Fix | `coco_dmk_rsdos --interleave=0`, payload via `writesector` |
| Counter-intuitive | interleave *monotonically worsens* it; sequential wins |
| To first frame | **51.4 s → 21.3 s (2.41×)**; per-track 3.31 → 1.31 s |
| Correctness | introseq 10/10 checks, **5/5 screens byte-identical** |
| Suite | probe, mode, anim, introseq — all PASS |
| Free win | DMK is read-only in MAME → idiom §24's write-back hazard gone |
| Exposed | a latent harness race the slow load had been hiding |

**Karateka had already answered this, and its own first answer was wrong** — worth
recording because the correction is the useful part. Probe 1 decomposed the time
(95.7% rotational), projected ~5–10× from a matched interleave, and reported the
sweep *blocked* because "imgtool exposes no interleave option". Probe 2 found that
was a `createopts` mis-invocation, ran the sweep, and measured the opposite: **2.5×,
from making the layout sequential rather than spread.**

---

### 2 — Files modified

**POP `wip`:**
- `build.bat` — the image is now `coco_dmk_rsdos … --interleave=0`; `.dsk` → `.dmk`.
- `harness/tools/raw_tracks.py` — places payload with `imgtool writesector` by
  logical id instead of computing JVC byte offsets, and read-modify-writes the FAT
  sector the same way. DMK is raw tracks (IDAM/DAM/gap/CRC); the linear offset
  formula does not exist there.
- `harness/smoke/run_{probe,mode,anim,introseq}_test.sh` — mount the `.dmk`.
- `harness/smoke/anim_test.lua` — settle 90 frames and require `nk.empty` before
  posting `EXEC`; report *what* the LOADM gate saw on failure; dump the text screen
  on a LOADM failure.
- `harness/smoke/mode_test.lua` — 2 lines, incidental to the same diagnosis.
- `mame-idioms-coco3-port.md` — **§29**.

**Not modified:** `src/` (engine, HAL, kernel — 0 files); Karateka; `oracle/source/`.

---

### 3 — Reasoning

#### 3.1 — The cause, and why the number was already known

POP measured **3.31 s/track**; Karateka independently **3.33 s/track**. Both ≈
**0.89 revolutions per SECTOR**, where a whole-track `m=1` Read-Multiple should cost
about one revolution *per track*. Karateka's decomposition attributes 95.7% to the
read, 0.2% to seek and 0.44 s one-time to spin-up — so it is rotational, and
rotational cost is a function of where the sectors physically sit.

**JVC has no "where".** It is a logical container — `off(T,S) = (T*18 + S-1)*256` —
so MAME must invent a physical order, and the one it invents is close to the
pessimal case for sequential-id reading.

#### 3.2 — The fix, and the part that inverts the convention

```
imgtool create coco_dmk_rsdos <img> --tracks=35 --sectors=18 \
        --sectorlength=256 --interleave=0
imgtool writesector coco_dmk_rsdos <img> <track> 0 <sector> <file>
```

**Interleave 0 = sequential = fastest.** The usual reason to spread sectors is to
give a sector-at-a-time reader time to breathe between requests. A HALT-paced `m=1`
Read-Multiple reads the whole track under ONE command and keeps pace inside it, so
it wants the next sector to be the *next* sector; any spread costs a revolution.
Karateka's sweep rises monotonically — il=0: 10.66 s, il=1: 12.27, il=9: 25.07,
il=13: 31.46 (worse than JVC).

The read side is unchanged: the primitive still asks for ids 1..18. Only the
physical placement moved, which is why correctness is unaffected by construction.

#### 3.3 — Measured (AC: the deliverable)

| read | JVC | DMK il=0 | |
|---|---:|---:|---:|
| bundle (1 track) | 5.2 s | 3.1 s | 1.68× |
| screen (7 tracks) | 23.2 s | 9.2 s | 2.52× |
| screen (7 tracks) | 23.0 s | 9.0 s | 2.56× |
| **to first frame** | **51.4 s** | **21.3 s** | **2.41×** |

Per-track **3.31 → 1.31 s**, against Karateka's 3.33 → 1.33 — agreement to 0.02 s
between two projects that measured it independently. The 1-track bundle gains less
because it carries the whole 0.44 s spin-up.

**A ~6 rev/track `wd_fdc` floor remains** that interleave cannot reach (Karateka's
Phase C). The load is now transfer-bound rather than container-bound; going below
21 s wants load-masking behind a transition, not more disk tuning.

#### 3.4 — Two free consequences

- **DMK is read-only in MAME's floppy layer** (idiom §3), so idiom §24's write-back
  hazard — MAME rewriting `probe.dsk` and corrupting it mid-task — cannot happen.
  Verified: the built image's md5 is unchanged across a full suite run, and MAME
  does not rewrite the scratch copy either. The scratch-copy rule stays as
  belt-and-braces.
- **The FAT reservation still works**, now via read-modify-write of track 17 sector
  2 through imgtool. Granules 52–67 reserved, `$C9`, no directory entry — DECB's
  allocator skips them and FREE reports correctly (gate G1).

#### 3.5 — The speedup exposed a latent harness race

`anim` failed after the change, in code, data and a harness the change never
touched. **Jay identified it by watching the screen: the first `E` of `EXEC` was
being eaten.**

The harness posted `EXEC` the instant the image verified. That check says only that
the BYTES are in memory; DECB may still be finishing the LOADM and getting back to
its prompt, and a keystroke posted into that window is dropped. **The slow JVC load
had been hiding the race for the entire life of the harness** — the OS was always
idle by the time the check passed. Making the load 2.5× faster moved the check into
the busy window.

Fixed at the wait, not at the speedup: settle 90 frames after the image lands, and
require `nk.empty`, before posting.

---

### 4 — Verification

- **Load time reduced** — §3.3, measured from `build/introseq_test.log` per-read
  timestamps, same harness before and after.
- **Correctness preserved** — introseq **10/10 checks**; **5/5 screens
  byte-identical** to an offline replay of the assets; all four DECB files
  round-trip byte-exact out of the DMK image.
- **Suite green** — `probe PASS`, `mode PASS`, `anim PASS`, `introseq PASS`.
- **One kernel** — sync bridge green pre-build; **0 files** changed under `src/`;
  Karateka's prod binary `88eba89b…` held.
- **Image integrity** — `build/probe.dmk` md5 `1c22e30177eccb9e3a45b06f289b55cc`
  unchanged across the whole suite.

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim):**

```
build/assets/intro_screen.raw: 30720 B -> build/probe.dmk tracks 27..33
  (126 sectors via writesector, 1536 B pad)
  FAT: granules 52..65 marked $C9 (used, no directory entry)
build/assets/intro_bundle.raw: 4608 B -> build/probe.dmk tracks 34..34
  (18 sectors via writesector, 0 B pad)
  FAT: granules 66..67 marked $C9
=== BUILD COMPLETE ===

# frame   858  disk read 1 complete (+187 frames, 3.1 s)
# frame  1409  disk read 2 complete (+551 frames, 9.2 s)
# frame  1949  disk read 3 complete (+540 frames, 9.0 s)
# checks=10 passed=10 failed=0
# VERDICT: PASS
  PASS base screen == converted splash, centred: 30720 bytes byte-identical
  PASS caption 1 == base + presents patch: 30720 bytes byte-identical
  PASS caption 1 removal is exact: 30720 bytes byte-identical
  PASS caption 2 == base + byline patch ONLY: 30720 bytes byte-identical
  PASS final screen == base: 30720 bytes byte-identical
VERDICT: PASS

probe     [run_probe_test] PASS
mode      [run_mode_test] PASS
anim      [run_anim_test] PASS
introseq  [run_introseq_test] PASS
```

**25.2:** `build.bat` (create + writesector), `harness/tools/raw_tracks.py`,
idiom §29. Reference: `karateka_coco3 docs/project/interleave-realization-mame.md`
and `load-time-decomposition-interleave-probe.md` (read-only).

**25.3:** **Not required and not offered.** Nothing about the rendered output
changed — the five screens are byte-identical to before. The deliverable is a time,
and it is measured, not judged. The P3.5 video already shows the sequence.

---

### 6 — Reactive deviations (§22.5)

1. **`raw_tracks.py` was rewritten**, not adjusted: JVC byte offsets have no DMK
   equivalent, so placement moved to `imgtool writesector` and the FAT edit to
   read-modify-write.
2. **`anim_test.lua` gained an EXEC settle** (§3.5) — required by the speedup, not
   optional.
3. **I relinked `anim_probe` and `mode_probe` to `$2000` and then REVERTED it.**
   See §7.1. This was my own addition, outside what the work required, and it cost
   most of the task's time.
4. **`mame-idioms-coco3-port.md` §29** added.

---

### 7 — Uncertainty flags

1. **`anim_probe` is knowingly exposed to the `$02DC` overwrite, unfixed.** Its
   prog spans `$0200-$034A`, so Color BASIC's line-input buffer at `$02DC` sits
   inside it, and the typed `EXEC` overwrites live code — **measured**, not
   inferred: `C6 04 A7 80 4C` → `00 00 00 43 00` after the keystrokes land. It
   passes anyway. I relocated it to `$2000` to fix that, which produced a *different*
   failure (a stage-5 hang, the P2.7/P2.8/P2.9 family) that I could not diagnose in
   the time, so I reverted rather than ship a half-diagnosed regression. **The
   defect is real and open.** `mode_probe` (212 B) and `loop_probe` (149 B) both
   stop below `$02DC` and are genuinely safe — the P3.5 report's blanket claim that
   "the probes are small enough" was **wrong for anim** and is corrected here.
2. **I attributed the `anim` failure to that overwrite without checking**, and acted
   on it. Jay found the real cause by looking at the screen. §3.5 — and it is the
   second consecutive task in which the decisive information came from watching the
   machine rather than instrumenting it.
3. **The ~6 rev/track floor is Karateka's measurement, not re-derived here.** POP's
   numbers agree with theirs to 0.02 s/track, so the floor is very likely the same,
   but POP measured the total, not the decomposition.
4. **DMK's read-only property is asserted from idiom §3 plus one md5 check.** Two
   runs, not a systematic test.

---

### 8 — Follow-up candidates

1. **`anim_probe` and the `$02DC` overwrite** (§7.1) — needs its own dispatch:
   relocate, then diagnose the stage-5 hang that relocation exposes. Do not bundle
   it into unrelated work again.
2. **Load-masking** — 21 s is now transfer-bound. Hiding it behind a transition is
   the only remaining lever short of a different read mechanism.
3. **The wd_fdc floor** — Karateka's own follow-up: why Read-Multiple costs ~0.3
   rev/sector even sequential, and whether per-sector `m=0` beats it.
4. **Audit the other harnesses for the same EXEC race** — `mode` and `introseq` post
   on the same gate and pass, which is luck of the same kind that was hiding `anim`.
5. Carried: `HAL_gfx_swap` clobbers X and `hal.inc` does not say so; the two buffer
   models; the 16-colour frame budget; `POP-idioms-coco3-markers.md`'s fate; the
   CLAUDE.md boot-contract statement drafted in P2.8 §8.1.

---

### 9 — User interaction during task

1. Jay: *"check what karateka does. i believe we use or at least documented a disk
   writing/reading mechanism that would reduce read times."* — correct, and it
   short-circuited the whole investigation: the measurement, the tooling and the
   sweep already existed.
2. Jay: *"yeah lets do it."*
3. Jay, mid-debug: *"when you run anim, the first e in exec is getting eaten."* —
   the actual cause of the `anim` failure, which I had misattributed. §3.5.
4. Jay: *"visually it looks like anim is loadming fine. there is just no exec to run
   it."* — confirmed the gate never passed, and caught that I had left the tree
   inconsistent (binaries relinked to `$2000`, harnesses reverted to `$0200`).

---

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-07-28-a-real-defect-next-to-a-failure-is-worse-than-no-explanation.md`
- `seeds/POP/live/2026-07-28-a-speedup-is-a-timing-change-and-will-expose-latent-races.md`

Pool commit `44e5b65`, pushed.

---

### 11 — Commit

**POP:** `deaa6a1` — DMK build, `raw_tracks.py`, the harnesses, idiom §29. Pushed
to `origin/wip`. This report: `11af68d`.
**Karateka:** untouched — `wip` `9f68eaa`, `main` `5eb92b1`, prod `88eba89b…` held.
