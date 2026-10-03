## Form B Report — P5.22 — the disk arc: side B fits compressed, both sides author and read back, and drive 1 can be detected without hanging

**Class:** measure + author (tooling only). `wip`. **Prod byte-identical; `probe.dmk` unchanged** (§0).
No change to `build.bat`'s shipped image; no gate spent.

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-10-03T11:56:34-04:00 (HEAD **`58cff35`**, wip — matches the dispatch; `main` **`32b5fe2`**).
Tracked tree clean.

**AC1 — sha1, receipt `build/` vs a fresh end build:**
```
08bcae4a6249828a64554c61db9ed7ace72e4081  intro_seq.bin      IDENTICAL
10bddbd5413d14b1fbf26aeadb874515fc32b3e8  loader.bin         IDENTICAL
d5b17b6d468f1bcdd66163a60d9ffa1e36197e15  cutscene_room.bin  IDENTICAL
6c8d6e980c53eaa24d83eb383923f5a0568e4256  probe.dmk          IDENTICAL
```
**AC16 — `main` = `32b5fe2` at both ends.**

---

### 1 — Summary

**Side B fits, compressed, with ~2 tracks to spare. "Over by more than 2×" compares expanded CoCo bytes
against a disk.** P5.12's 240,700 + 95,086 B are the port's **in-memory** form. Run through the shipped
`lz_pack` codec: **tile variants compress 5.8–7.8×**, the cast 2.2×, blueprints 2.8×. Side B's measured
content (tilesets 00/01, the gameplay cast, all 15 blueprints) takes **20 tracks**. Named estimates for
what isn't in the tree (tileset 02, four guard sets, scenery, music) take 13 more. **33 of 35.**

**Both sides were authored by an explicit track map with a new tool modelled on karateka's**, and **read
back byte-exact through the shipped `disk_read_range` under MAME**: all 35 tracks of each, track 17
included on the raw side. **Measured: 1.166 s per track marginal** (karateka 1.19, POP's P3.75b 1.20).

**★ Jay's mid-task ruling — two drives, or one drive and a flip — is measured, not just noted.** Drive 1
can be identified **safely** with a two-stage check. First, index pulses are read with HALT off and a
timeout. Only then is the signature sector read HALT-paced. **That ordering matters:** an empty or
absent drive 1 **never finishes a read**, so the shipped HALT-armed read would hang the game in exactly
the cases the ruling must survive (§3H).

**Two of the dispatch's premises were already true, in more of the tree than §1 credited:**
- **POP already authors bulk by `writesector` on explicit tracks.** `raw_tracks.py` does it, with
  `$C9` FAT reservation, the track-17 guard and karateka citations. Only the DECB *files* go through the
  allocator, and 8 of the shipped image's 9 file tracks are **harness probes**, not game content (§3A).
- **The "~4.6 KB directory tax" is exactly one track** (4,608 B): 161,280 raw vs 156,672 DECB.

---

### 2 — Files modified

- `harness/tools/make_side_dmk.py` — **new.** The authoring tool (AC11): explicit track map, `writesector`
  at (track, sector), DECB-boot or raw side, LZ in shipped blob format, read-back check. **Tooling only.**
- `harness/tools/side_maps.py` — **new.** The proposed maps (AC10), generated from measured sizes.
- `harness/tools/disk_capacity.py` — **new.** The shipped image's FAT/directory read back, per-side budgets,
  per-class LZ (AC2, AC4, AC5).
- `src/harness/side_read_probe.s`, `harness/tools/side_read.lua`, `harness/tools/side_read_check.py`,
  `harness/smoke/run_side_read.sh` — **new.** Read a side back through `disk_read_range`, timed (AC12).
- `src/harness/drive_probe.s`, `harness/tools/drive_probe.lua`, `harness/smoke/run_drive_probe.sh` —
  **new.** Drive-1 detection in four configurations (Jay's ruling, §3H).
- `src/harness/xform_probe.s`, `harness/tools/xform_probe_gen.py` — `lz_unpack` included and an `--lz`
  case type, to time the shipped decoder on real class data.
- `harness/tools/raw_tracks.py` — **header comment only:** the two hazards (AC13). No logic changed; the
  shipped image is byte-identical.
- `mame-idioms-coco3-port.md` — **§42**: authoring, measured read times, capacity, and the two hazards.
- This report.

Nothing in `build.bat`, `src/engine/`, `src/hal/`, `link/`, `content/`.

---

### 3 — Reasoning

#### 3A — The grep (§10), and what was already true

- **`raw_tracks.py`** places every bulk asset with `imgtool writesector` by logical sector at an explicit
  track, marks the granules `$C9`, refuses track 17, and cites karateka's `interleave-realization-mame.md`
  and `decb-loadm-boot-gates.md`. **That is karateka's `make_decb_boot_disk.sh` pattern, shipping.**
  §2's *"POP places everything with `imgtool put` as named DECB files"* applies to six files only.
- **The shipped image, read back** (`disk_capacity.py` reads the FAT and directory off `probe.dmk`):
  **18 DECB-file granules, 50 raw-reserved, 0 free of 68.** The file granules are `INTRO.BIN` 13 (the
  P3.2 splash probe), `PROBE`/`MODE`/`ANIM` 1 each (harness probes), and `LOADER`/`TILE` 1 each. **8 of the
  9 file tracks are not game content.**
- **P5.12 read whole** (§10). Its 240,700 B is `bake_screen`'s opaque-rectangle tiles, deduplicated within
  a tileset, with **5 of 15 levels estimated** (tileset 02 is not vendored). Its 95,086 B is `coco3_bytes`
  over kid + five guard sets: **a lower bound**, one facing, one phase. **Both are expanded, in-memory
  CoCo figures**, and nowhere called disk figures.
- **POP's own read timing** was in `build.bat:621-625` (P3.75b: 1.20 s/track, 0.60 s spin-up). It is now
  re-measured on authored images (§3F).

#### 3B — AC2/AC3: per-side budget

| | bytes | whole tracks |
|---|---|---|
| raw, 35 × 18 × 256 | **161,280** (157.5 KiB) | **35** |
| DECB-formatted (track 17 = directory + FAT) | **156,672** (153.0 KiB) | **34** |
| **the directory tax** | **4,608** | **exactly 1 track** |

**The Orchestrator's reading verifies:** POP has budgeted 161,280 (raw) while shipping a DECB side. Under
the authored-track-map model:
- **Side A** must keep DECB as its boot surface (`LOADM` → loader): **34 tracks**, minus `LOADER.BIN`'s
  granule (half of track 0).
- **Side B** needs no DECB surface if it is identified by a signature: **35 tracks.**

**AC3 — what a DECB-less side B is worth: exactly one track, 4,608 B, ~1.2 s of read.** With today's
estimates side B claims 33 tracks, so the difference is **2 tracks spare vs 1**. ★ It interacts with
Jay's ruling ("a disk with the appropriate **file**"): a file-based check needs the DECB surface (§3H).
**Not chosen.**

#### 3C — AC4: `lz_pack` per asset class (the shipped codec; every blob round-trip-verified)

*Inputs are CoCo form. Classes over 8 KB are compressed in 8,192 B chunks, the GIME block the port maps.
`lz_pack`'s 16-bit offsets forbid one stream over 64 KB, and an in-place decode needs block-sized units.*

| class | what it is a number of | expanded B | LZ B | ratio | tracks |
|---|---|---|---|---|---|
| **tile variants, tileset 00** | P5.12's deduplicated variants, 4 levels | 67,345 | **8,600** | **7.83×** | 15 → 2 |
| **tile variants, tileset 01** | same, 6 levels | 93,333 | **15,988** | **5.84×** | 21 → 4 |
| tile variants, per-level packs | 10 levels **not** deduped | 399,490 | 66,740 | 5.99× | 87 → 15 |
| tile page (shipped) | LEVEL0 screen 1, baked page | 7,280 | 1,390 | 5.24× | 2 → 1 |
| **cast, segment streams** | 290 gameplay cels, phase 0, facing 0 | 91,906 | 41,426 | 2.22× | 20 → 9 |
| **cast, raw 2bpp bitmaps** | same 290 cels | 59,080 | **27,431** | 2.15× | 13 → 6 |
| cutscene cel pages (**shipped uncompressed**) | 4 pages + pinned page | 3,267–7,647 | 1,472–2,917 | 2.2–3.8× | **2 → 1 each** |
| level blueprints | 15 × 2,304 B, Apple form, used as-is | 34,560 | 12,484 | 2.77× | 8 → 3 |
| scenery (cutscene sample) | torch ×2 + hourglass segment streams | 2,008 | 678 | 2.96× | — |
| sound | one msys song page | 1,024 | 858 | 1.19× | — |
| code | intro / scene programs | 1,575 / 1,269 | 1,425 / 968 | 1.1 / 1.3× | — |
| screens (shipped, one stream) | intro / prolog1 / room | 30,720 / 30,720 / 15,360 | 8,298 / 4,936 / 4,132 | 3.7 / 6.2 / 3.7× | as shipped |

**P3.12's ratios were for dithered screens. Gameplay tiles compress better (5.8–7.8×), the cast worse
(2.2×), and code and sound barely.**

#### 3D — AC5/AC6: representation, and expansion vs compression

**AC5 — LZ on raw bitmap beats LZ on segment stream, by 34% in bytes:** 27,431 vs 41,426 for the same
290 cels. The ratios are similar (2.15× vs 2.22×); the raw form simply starts 1.56× smaller. **But the
blitter consumes segment streams**, so storing raw bitmaps is a derive-at-load (§3E, row 4).

**AC6 — karateka's 1.62×/1.68× is an EXPANSION ratio:** CoCo bytes over Apple bytes for the same sprites,
the 7 → 4 px/byte repack [`karateka content-expansion-capacity-projection.md:22,56-62`]. **It is not a
compression ratio.** On POP's 290 gameplay cels it measures **1.86×** (63,550 / 34,117); narrow cels pay
more byte-width rounding. **The backlog's "Apple form is ~60% of CoCo size" is the same claim
inverted:** 1/1.68 = 0.595 (karateka), 1/1.86 = **0.537** (POP). Neither says anything about LZ.

#### 3E — AC7/AC8: derive-at-load, in disk bytes and seconds

*Read cost at the **measured** 1.166 s/track (§3F; the dispatch's 1.19 gives ~2% more). Decode cost is
the **measured** `lz_unpack` rate: 21.5–33.7 cy per output byte on real tile, cast, blueprint and screen
data (7 cases, byte-exact) = **12–19 ms per KB at 1.79 MHz**, twice that if decoding stays at disk
speed.*

| candidate | disk bytes saved | load-time cost | status |
|---|---|---|---|
| **mirrored facing at draw time** (P5.20) | the second facing: ~62 KB packed, ~14 tracks ≈ **16 s** | **zero at load** (draw-time cost measured, P5.20) | **adopted model** |
| **phases at draw time** (P5.20) | ×(3.09−1) of the cast: ~130 KB packed, ~28 tracks ≈ **33 s** | zero at load | **adopted model** |
| **LZ, everything on side B** | ~445 KB expanded → ~128 KB (§3G's entries, estimates included): **~69 tracks ≈ 80 s** of read avoided | ~12.4 M cy decode at ~28 cy/B ≈ **6.9 s** at 1.79 MHz | measured both ways |
| cast as raw bitmaps + segment-encode at load | ~18 KB ≈ 4 tracks ≈ **4.7 s** | encoder **unbuilt**; bounded ~1.6–3.2 s at 1.79 MHz (~30–60 cy/B) | **named; the cost is an estimate** |
| cast in Apple form + colour model at load | 3,628 B on 290 cels (23,803 vs 27,431 LZ) ≈ **<1 track** | port `sprite_convert`'s colour model **and** the segment encoder to 6809 | named; not worth it on these numbers |
| tile variants from base tiles | variants 24,588 B packed vs Apple BGTAB sources 5,740 + 6,390 B packed: **~12 KB ≈ 3 tracks** | port `bake_screen` (compositing + colour model) to 6809 | named; large unbuilt cost |
| scenery phases | none to save: one phase per kind (P5.7) | — | — |

**AC8 — confirmed absent from the disk requirement:** side B's map stores the cast at **one phase, one
facing** (§3G). Every phase and the mirrored facing are produced at draw time by P5.20's measured
routine. Neither appears in any track count here.

#### 3F — AC11/AC12: the tool, and the read-back

**`make_side_dmk.py`**, modelled on `make_game_dmk.sh` (`create coco_dmk_rsdos --interleave=0`, payload by
`writesector` at logical IDs) and `make_decb_boot_disk.sh` (one `put` to granule 0, raw spans `$C9`). It
**refuses** a span crossing track 17 on a DECB side, any overlap, and any span running off the disk.
**Every written sector is read back with `imgtool` before exit 0.**

**Read-back through the shipped primitive** (`run_side_read.sh`). The port's own `hal_build.o`, linked to a
probe, calls `disk_read_range` on each of the 35 tracks singly, then 1- and 3-track ranges at three
positions. The expected bytes come from **imgtool's independent DMK parse**, not the FDC under test:

```
side B (raw):   35 of 35 tracks byte-exact, track 17 = payload     side A (DECB): 35 of 35 byte-exact
single-track call (Restore + Seek + one m=1 track): median 1.384 s (1.601 first, with spin-up)
per-track MARGINAL, (t3 − t1)/2:  from 2: 1.099   from 15: 1.199   from 28: 1.199   MEAN 1.166 s/track
```
*(The two sides time identically to the millisecond. That's geometry, not content, and MAME is
deterministic, so it is one measurement, not two.)*

#### 3G — AC10: the proposed track map (`side_maps.py`; both images authored and read back)

| side | tracks | content | |
|---|---|---|---|
| **A** (DECB boot) | 0 | `LOADER.BIN` (granule 0) | authored |
| | 1 | intro program | authored |
| | 2–3 | intro caption bundle | authored |
| | 4–9 | intro screen, prolog 1, prolog 2 (LZ, as shipped) | authored |
| | 10–13 | princess room, flame bundle, music player, scene program | authored |
| | 14–16, 18–19 | cutscene cel pages + pinned page, **now LZ: 1 track each instead of 2** | authored |
| | **17** | **DECB directory + FAT** | format |
| | 20 | tile page (LEVEL0 test page) | authored |
| | **21–34** | **14 tracks free**: engine/game code, phase-1 content | — |
| **↕ FLIP POINT** | | **when side B is first needed**: first level after the intro; drive 1 if present (§3H) | |
| **B** (raw) | 0 | **side directory + `POPB` signature** | authored |
| | 1–2 | tileset 00 variants (67,345 → 8,654 B) | authored |
| | 3–6 | tileset 01 variants (93,333 → 16,060 B) | authored |
| | 7–9 | tileset 02 variants | **reserved, EST** (not vendored) |
| | 10–12 | 15 blueprints (34,560 → 12,514 B) | authored |
| | 13–22 | gameplay cast, kid + GD, segment streams (91,906 → 41,498 B) — **across track 17** | authored |
| | 23–27 | guard sets FAT/SHAD/SKEL/VIZ | **reserved, EST** |
| | 28–29 | animated scenery, 3 tilesets | **reserved, EST** |
| | 30–32 | music, 11 songs | **reserved, EST** |
| | **33–34** | **2 free** | — |

Side A's 14 free tracks come from re-laying the shipped content: dropping the four harness probes and
compressing the cel pages. ★ **This map describes no image the port reads today.** The loader's track
constants (`INTRO_TRK=33`, `DISK_FLAME_TRK=30`, …) point at the shipped layout.

#### 3H — ★★ Jay's ruling, mid-task: two drives, or one drive and a flip

> *"we should be designing for two situations. two drives two disks and a single drive with a flippy
> disk. the game should check for a second drive and if a disk with the appropriate file exists. if no
> second drive, no disk, or wrong disk, then prompt for user flip on the single drive."*

**One pair of images serves both:** side B is the second image whether it sits in drive 1 or is the
flip side of a flippy in drive 0. The check is the same in both places.

**The hazard, measured before anything was designed around it** (`run_drive_probe.sh`, four MAME
configurations, drive 0 as control in each):

| drive 1 | Restore | index-pulse edges | **polled** read | **HALT-paced read, gated on index** | verdict |
|---|---|---|---|---|---|
| side B | ok | **8** | Lost Data after 1 B | **`POPB` + directory, exact** | **use drive 1** |
| wrong disk | ok | **8** | Lost Data | `00 FF FF…` — no signature | flip |
| **empty** | ok | **0** | **never finishes** | skipped | flip |
| **no drive** | **Busy stuck** | **0** | **never finishes** | skipped | flip |

1. **★★ An empty or absent drive never finishes a read.** `disk_read.s` arms HALT for every transfer and
   only INTRQ or DRQ releases it, so **the shipped read path, pointed at drive 1, would hang the game
   in two of the four cases Jay names.** A halted CPU cannot time itself out.
2. **Index pulses are the safe presence test:** Type I status with HALT off, polled with a bound. 8 edges
   with a disk, 0 without.
3. **A polled read cannot keep up at 0.894 MHz** (Lost Data after one byte), so the identifying read must
   be HALT-paced, which is safe only after stage 1 has proved a disk is turning.
4. **Cost:** the negative cases take ~0.8 s longer to decide than the positive one. It can sit behind the
   moment side B is first needed.

**What this requires that is not built, named for whoever builds it:**
- **`disk_read.s` hard-codes drive 0** (`DSK_DRV0 = $01` in every DSKREG write). It is shared with
  karateka and coco_agi under `hal_sync_check.py`, so **drive selection and the index-pulse gate are a
  cross-repo HAL task**, not a POP-local edit.
- **The identity check, two options, not chosen:**
  (a) **raw side B + signature** on track 0 (what is authored here): 35 tracks;
  (b) **DECB side B + a named file**, read from the directory (track 17, sectors 3+) after the index gate:
  costs **one track**, but a user's `DIR 1` shows what the disk is. **"Appropriate file" may mean (b)**;
  that's Jay's ruling to make, and §3B prices it.
- **Side A needs a signature too** (`POPA`), so a single-drive player is verified after flipping back.
  The oracle flips back itself: `GOATTRACT` checks `BBundID` and calls `flipdisk` [`TOPCTRL.S:1241-1264`].
- **The flip prompt re-runs the same check on drive 0** until `POPB` appears, so a wrong flip is caught
  by the mechanism that caught the wrong disk.

#### 3I — AC9: where side B's loads can hide (named, not designed)

**The oracle's own load points are the template.** It is a two-sided original too (`POPside1`/`POPside2`,
"FLIP DISK", `TOPCTRL.S:1241-1264`). It reads at **every level start and restart**: `RESTART` →
`LoadLevelX` *"load blueprint & image sets from disk"* behind a cleared text screen [`TOPCTRL.S:256-271`].
And `LOADLEVEL` fetches the bg sets and char set **only when they changed** (`cpx BGset1 / beq ;already
in memory?`, `MASTER.S:467-557`), which is exactly P5.12's per-tileset unit.

| load | size (measured / est.) | read at 1.166 s/track + call | decode | hides behind |
|---|---|---|---|---|
| **first side-B load** (cast kid+GD 10 + first tileset 2 + blueprints 3) | ~15 tracks | ~18 s | ~4 s | **the flip prompt / drive-1 check, and a loading screen** (P4.46's pattern) |
| tileset change (levels 4, 7, 10, 12, 14…) | 2–4 tracks | 2.5–4.9 s | ≤ 1.4 s | **the level-start screen**, as the oracle does |
| guard-set change | 1–2 tracks | 1.4–2.6 s | < 0.5 s | the level-start screen |
| blueprint, every level | resident after the first load (12.5 KB packed) | none | ~0.06 s | — |

**Two drives remove the flip, not the loads.** Drive 1 reads at the same measured speed.

---

### 4 — AC14: what is NOT being proposed

1. **Not changing `build.bat`, `probe.dmk`, or any track constant.** The maps are proposals; the shipped
   image is byte-identical.
2. **Not moving gameplay content onto a real image**: the bake (C) does not exist.
3. **Not editing `disk_read.s`.** Drive selection and the index gate are a cross-repo HAL task (§3H).
4. **Not choosing** raw-signature vs DECB-file identification, raw vs DECB side B, or raw-bitmap vs
   segment cast on disk. Each is priced.
5. **Not designing the load masking** (§3I names where; it does not design it).
6. **Not removing the harness probes from the shipped image**, though they hold 8 of its 9 file tracks.
7. **Not building the load-time segment encoder, colour model or tile baker** (§3E, rows 4–6).

---

### 5 — Verification (AC-by-AC)

- **AC1** — §0, four sha1s identical, `probe.dmk` included. **AC16** — §0.
- **AC2** — §3B: 161,280 B / 35 tracks raw; 156,672 B / 34 tracks DECB; tax = 1 track. Per side: A = 34
  (DECB boot), B = 35 (raw) or 34.
- **AC3** — §3B: one track, 4,608 B, ~1.2 s; 2 spare vs 1. Not chosen.
- **AC4** — §3C, ten classes, ratios and absolute bytes, each named. **AC5** — §3D: raw 27,431 vs
  segment 41,426.
- **AC6** — §3D: 1.62/1.68/1.86 are expansion (CoCo/Apple); the "~60%" is the same claim inverted.
- **AC7** — §3E, seven candidates in bytes and seconds; decode rate measured. **AC8** — §3E.
- **AC9** — §3I, from the oracle's own load points. **AC10** — §3G, both sides, flip point marked.
- **AC11** — `make_side_dmk.py`, tooling only. **AC12** — §3F: 35/35 byte-exact, both sides, 1.166 s/track.
- **AC13** — `raw_tracks.py` header + coco3 idioms §42 + `make_side_dmk.py` header: never `DSKINI`; no
  stock fast-copy. **For the release notes: ship as an image copy or a flux write.**
- **AC15** — **512 KB: ALL PASS. 128 KB: `introseq` FAIL (capture stage), `integ` FAIL, `tile` PASS** —
  red as expected, not bisected.
- **AC17** — §6.

### 5b — Verdict-time evidence

**25.1** (verbatim):
```
build.bat: [hal-sync] OK ... [reg-owner] OK — 25 owner row(s) ... === BUILD COMPLETE ===
run_suites.sh 512K: [run_introseq_test] PASS / [integ] PASS / [run_tile_test] PASS / [suites] ALL PASS
run_suites.sh 128K: [run_introseq_test] FAIL (capture stage) / [integ] FAIL / [run_tile_test] PASS
make_side_dmk.py side B: tracks used 20 of 35 (no DECB surface) — readback: every written sector matches
make_side_dmk.py side A: tracks used 19 of 34 (track 17 = directory) — readback: every written sector matches
run_side_read.sh side_b.dmk: 35 of 35 byte-exact; MEASURED marginal 1.166 s/track; PASS
run_side_read.sh side_a.dmk: 35 of 35 byte-exact; PASS
run_xform_probe.sh --lz ×7: PASS all byte-exact; lz_unpack 21.5–33.7 cy per output byte
run_drive_probe.sh: right POPB | wrong no-sig | empty idx=0 skipped | nodrive restore TIMEOUT idx=0 skipped
```
**25.2:** N/A. **25.3:** N/A. Nothing on screen changed; no gate spent.

---

### 6 — Reactive deviations and route accounting

1. **★ Jay's ruling arrived mid-task** (two drives / flip) and was **measured**, not just recorded (§3H).
   It added a probe and four MAME configurations. It did not change the capacity work.
2. **§2's premise corrected** (§3A): the `writesector` authoring already ships in `raw_tracks.py`.
3. **Decode cost measured** rather than estimated: the P5.20 probe gained an `--lz` case. It was needed
   because "seconds" in AC7 has to include decoding, not just reading.
4. **Two of my own errors, both caught by the tools before reporting:** the scenery estimate first scaled
   by 15 levels instead of 3 tilesets (P5.7 measured it per kind), which over-claimed side B by 6 tracks;
   and the first `--lz` cases passed the bare stream instead of the shipped 6-byte-header blob, which
   `lz_unpack` rejected by decoding garbage. Both are fixed and noted in the code.

**ROUTE ACCOUNTING.** I proposed nothing before the task. Within it, the track map (§3G) is a proposal
**and both images exist and read back**. The drive-1 check (§3H) is **measured as a mechanism in a harness
probe and NOT built into the HAL or the game**. The identity-check choice, raw vs DECB side B, and the
load masking are **named and priced, not built.**

---

### 7 — Uncertainty flags

1. **★ 13 of side B's 33 tracks are estimates**: tileset 02 is not vendored, nor are the other guard sets'
   segment forms, per-level scenery, or the songs. Side B's 2 spare tracks are a margin on estimates.
2. **★ Everything is MAME.** §3's gap-margin hazard and the drive-1 behaviours (index pulses, Busy stuck on
   a missing drive) need **real-hardware confirmation**. A real WD1773 with no drive may behave
   differently from MAME's model. The safe design does not depend on how a missing drive fails, only on
   seeing index pulses before arming HALT.
3. **The post-read status after a correct HALT-paced read was `$07`**, not clean. The data was exact, so
   status is not the identity signal; the cause is not run down.
4. **The cast on side B is kid + GD only**; the whole-game cast is a lower bound (P5.12 flag 4).
5. **Engine/game code size is unknown.** Side A's 14 free tracks are for it, and it is not estimated here.
6. **The derive-at-load encoder costs are estimates** (§3E rows 4–6). Only `lz_unpack` was measured.

### 8 — Follow-up candidates

1. **★ The cross-repo HAL task:** a drive parameter in `disk_read.s`, plus an index-pulse presence gate that
   never arms HALT on an unverified drive (§3H). It touches karateka and coco_agi through the sync check.
2. **★ Jay's ruling on identification:** raw signature vs DECB file on side B (one track, §3B).
3. **Reclaim the harness probes from the shipped image** (8 file tracks) and LZ the cutscene cel pages
   (5 tracks): side A goes from full to 14 free.
4. **Real-hardware check** of the drive-1 cases and the `DSKINI` gap hazard.
5. **Vendor tileset 02** (P5.12 follow-up) to turn side B's largest estimate into a measurement.

### 9 — User interaction during task

**One, mid-task — Jay:** *"we should be designing for two situations. two drives two disks and a single
drive with a flippy disk. the game should check for a second drive and if a disk with the appropriate file
exists. if no second drive, no disk, or wrong disk, then prompt for user flip on the single drive."*
Folded in as §3H: measured in four configurations, the hazard found, the safe two-stage check
demonstrated, the HAL work and the file-vs-signature question named for him.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-10-03-a-capacity-figure-names-its-form.md`: a capacity requirement stated in
in-memory bytes was compared against a disk for a month; the form (expanded vs stored) has to travel with
the number.

### 11 — Commit

See the follow-up commit for the hash. Pushed to `origin/wip`. `main` untouched at `32b5fe2`.
