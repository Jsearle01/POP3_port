## Form B Report — P3.4 — the oracle's intro load cadence, and the disk path
**Class:** INVESTIGATE-THEN-BUILD. **Phase 1 COMPLETE.** **Phase 2 PARTIAL — the disk
path works and is proven; the two-beat sequence does not complete reliably on it.**
POP `wip`. Karateka: `disk_read.s` guarded (mirrored), **prod binary byte-identical
`88eba89b15cdf17c8d25e082d2d3e1f3cce57d38`**, `main` untouched at `5eb92b1`.
**25.3: NOT REACHED — no visual gate is offered, because the sequence does not run
to completion.**

### 0 — Receipt / status (C-35 stamp)
t0=2026-07-27T23:30:17Z (POP HEAD `8ba6389`, wip; tracked tree clean at receipt).
Karateka: `wip` `c36e67e`, `main` `5eb92b1`.

---

### 1 — Summary

**The dispatch's premise is refuted by the trace, and so is the memory strategy
built on it.** The oracle does **not** stream during the intro, and it **does**
bank. A viable route fell out of the same trace and is half-built: the disk path
works, byte-exact, and `LOADM` is resolved — but the converted sequencer does not
finish, and I am reporting that rather than papering over it.

| | |
|---|---|
| Cadence | **batch-per-stage**, 39.8 s and 49.3 s of total silence between loads |
| "It streams during the intro" | **REFUTED** — zero device access across all four beats |
| "It doesn't bank" | **REFUTED** — its intro data lives in AUX while code runs in MAIN |
| `LOADM` ceiling | **RESOLVED** — program is 1,384 B, one granule, loads from disk |
| First real disk load | **PROVEN** — 30,720 B read into the back buffer, 0 bytes differ |
| Resident footprint | **0 B** for the screen (was 26,880) |
| Two-beat sequence | **BROKEN** — beat holds collapse to zero; not diagnosed |
| POP regressions | probe 6/6, mode 14/14, anim 27/27 — all PASS |

**Phase 1 is the deliverable that came out whole**, and it is worth more than the
cadence question it was asked to answer.

---

### 2 — Files modified

**POP `wip`:**
- `harness/tools/raw_tracks.py` — **NEW.** Writes a payload onto whole tracks and
  reserves the granules in the FAT (gate G1), so DECB never allocates over them.
- `harness/tools/make_intro_assets.py` — **NEW.** Emits the screen as a full
  160×192 framebuffer plus a fixed-slot bundle (palette + both caption patches).
- `src/hal/coco3-dsk/disk_read.s` — object-target guards + entry-point exports,
  **inert without `OBJTARGET`**; mirrored to Karateka, whose binary is unchanged.
- `src/harness/hal_build.s` — the primitive joins the kernel; first POP client.
- `src/engine/intro_seq.s` — screen and patches read from disk; `patch_blit` saves
  and restores rather than sourcing the repair from a resident base; drive release.
- `harness/smoke/introseq_test.lua` / `run_introseq_test.sh` — back to `LOADM`.
- `build.bat` — `DR_VARBASE`, the asset build, the raw-track write.
- `mame-idioms-coco3-port.md` — **§25** the `-D $hex` = 0 trap, **§26** release the
  drive.

**Not modified:** Karateka beyond the mirrored guard; `oracle/source/`.

---

### 3 — Reasoning

#### 3.1 — PHASE 1: the cadence (AC1) — determined, not assumed

Authority: **source** (`MASTER.S`), **confirmed on the running oracle**.

`ATTRACTMODE` calls `SetupDHires` → `LoadStage1A`, then `PubCredit`,
`AuthorCredit`, `TitleScreen`, `Prolog1`, `PrincessScene`. `LoadStage1A`
(`MASTER.S:1168`) is **seven whole-track reads in one burst**:

```
]lsub track 22:  rw18 -> AUX $4000,$5200,$6400,$7600,$8800   5 tracks, 23,040 B
setmain:         rw18 -> MAIN $6000,$7200                    2 tracks,  9,216 B
loadmusic1:      rw18 -> MAIN $4E00, moved to the aux language card
```

Every intro asset ID is an address inside that (`MASTER.S:101-104`): `pacSplash`
`$40`, `delPresents` `$70`, `delByline` `$72`, `delTitle` `$74`, `pacProlog` `$7c`
— all in AUX `$4000-$7FFF`. `unpacksplash` is `lda #pacSplash / sta RAMRDaux / jmp
DblExpand`: **it expands from resident memory, not from disk.**

**Confirmed by a passive write tap on the CFFA2 card window** across the whole
intro (`build/oracle_snap/cadence.log`), correlated on ONE timeline with the
rendered-frame and RDPAGE2 beat trace:

```
f7    DISK burst 1: 1572 card writes, f7..f196
f401/f405   FLIP  "Broderbund Presents" in       <-.
f686/f698   FLIP  out                              |
f779/f782   FLIP  "A Game by Jordan Mechner" in    |  39.8 SECONDS
f1065/f1076 FLIP  out                              |  OF TOTAL SILENCE
f1149/f1183 FLIP  title in                         |
f1720/f1732 FLIP  title out                      <-'
f2581 DISK burst 2: 544 card writes   (39.8 s of quiet before it)  PrincessScene
f5600 DISK burst 3: 584 card writes   (49.3 s of quiet before it)  2nd SetupDHires
```

**The cadence: batch an entire stage, run many beats with no I/O at all, and
reload only when a scene needs data the display has destroyed.** Not
one-screen-at-a-time, not load-ahead. `ReloadStuff` (`MASTER.S:1211`, "Reload
2000-6000 auxmem — wiped out by dhires titles") exists because DHR page 2
(`$4000-$5FFF`) sits on top of the crunch store: displaying a double-hires screen
eats its own source data.

The 3.5" oracle uses `RW1835.S` rather than the 5.25" `rw18`, so the transport
differs and the cadence does not — same `MASTER.S`, same call sites.

#### 3.2 — PHASE 1: what that means for POP, and what it refutes (AC1, AC4)

**Two premises in the dispatch do not survive the trace.**

*"It disk-loads during the intro, so POP should too."* It does not. Across all four
beats the oracle touches the disk zero times. There is no streaming cadence to
match; matching what it actually does means "load once, keep everything resident",
which is precisely what P3.3 does and precisely what does not fit.

*"No banking till the game requires it."* The original required it from the first
intro screen. Its intro data lives in **AUX** `$4000-$99FF` while code runs in
MAIN — `sta RAMRDaux` / `sta RAMWRTaux` is a bank switch, the same idea as the
CoCo3 MMU. The oracle's memory strategy is **compression plus banking**, not
streaming.

The scale, which is the actual problem:

```
oracle's ENTIRE stage-1 payload, crunch-compressed, in a bank   32,256 B
POP's ONE splash, uncompressed, display-faithful                26,880 B
```

POP's single screen is most of the oracle's whole intro. RLE on it measures **86%**
(P3.3) — the display-faithful choice reproduces NTSC fringing everywhere, which
defeats compression by construction.

**But the same trace supplies the route.** The oracle expands its screen *straight
into the display pages* and never holds an uncompressed copy. POP's equivalent is
to read the screen from disk **directly into the back buffer** — the asset's
destination IS the framebuffer, which already lives outside the 64 KB map. Resident
cost: zero. That is closer to what the oracle does than keeping it resident is, and
it needs no decompressor and no banking of program memory. **Banking is avoided —
by structure, not by assumption.**

#### 3.3 — PHASE 2: the `LOADM` ceiling, resolved by removal (AC3)

With the screen on disk the program is **1,384 bytes, one granule, ending at
`$03A2` — below DECB's DBUF0 at `$0600`.** `LOADM"INTROSEQ"` then works, and the
program reads its own assets afterwards, long after DECB has finished with those
buffers. **A small resident program that loads its own data is the oracle's shape**;
the ceiling stops applying rather than being worked around, and Karateka's
bootloader is not needed for this case.

Verified: `loadm_from_disk PASS 1384 B, 2 segments, at frame 644 — the real path`.

#### 3.4 — PHASE 2: the disk read is exact (AC3)

```
base capture vs the on-disk screen asset: 30720 bytes, 0 differ -> DISK READ IS EXACT
```

The framebuffer the CoCo3 displayed was read off raw tracks 27–33 by
`disk_read_range`, into `HAL_gfx_draw_base`, and matches the built asset
byte-for-byte. **The first engine screen ever loaded from disk in this project.**
The bundle (palette + both patches, track 34) reads correctly too; two bytes differ
in its trailing pad, outside every payload slot, and are not explained.

`load_tracks` owns three things the primitive deliberately does not: the SAM speed
bracket (idiom §8 — POP is the first project to exercise the PROVISIONAL disk-speed
rule for real, and it holds), the interrupt mask, and the drive release.

#### 3.5 — PHASE 2: what does NOT work, stated plainly

The two-beat sequence does not complete. Current behaviour:

```
f3723  base up      (status=1)            <- correct, byte-exact
f3823  caption 1 in (status=2, +100 fr)   <- correct, matches the oracle's +99
       ... then the 281-frame hold collapses to ~0 and the run derails
```

Symptoms, all reproduced: beat holds returning immediately while the *pre* holds of
the same beats time correctly; `probe_phase` writes not landing while the adjacent
`probe_status` write does; **and behaviour that changes when four bytes of
diagnostic are added or removed.** That last one means a live memory-corruption or
aliasing defect I have not localised. Three hypotheses were tested and eliminated
(corrupt patch data — the bundle is intact; `patch_blit` geometry — a write tap
shows the first write at `$C0AC` = row 103 col 76, exactly right, and the walk
completing with `pb_row`=148, `pb_save`=`$1EEB`; the harness's MMU borrow — a
control run with it disabled fails identically).

**I am not offering a visual gate on this.** P3.3's sequencer at `8ba6389` remains
the last intro that runs correctly end to end.

---

### 4 — Verification (AC-by-AC)

- **AC1 cadence determined from the oracle, not assumed** — **MET.** Batch-per-stage,
  cited to `MASTER.S` and confirmed by a passive tap on the running oracle. The
  Orchestrator's "1 screen, replace prior" is **CORRECTED**, and so are the two
  premises under it (§3.2).
- **AC2 POP loading matches the cadence** — **PARTIAL.** The load schedule matches
  (one batch before the first beat, no I/O during the beats) and the credits are
  converted poked→disk-loaded. The sequence they drive does not complete.
- **AC3 real disk path exercised; `LOADM` resolved** — **MET.** `LOADM` from disk at
  frame 644; 30,720 B read byte-exact into the back buffer.
- **AC4 memory flat, banking avoided** — **MET for the screen.** 26,880 B → 0 B
  resident; program 419 B of code; assets 1,588 B read to `$0A00` at start-up.
  Banking avoided. The title beat now fits by a wide margin.
- **AC5 one kernel** — **MET.** Sync bridge green (11 files); Karateka's prod binary
  byte-identical; its bootloader still builds (403 B).
- **AC6 git status clean except the named work** — **MET.**

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim):**

```
[hal-sync] OK -- HAL source aligned with karateka_coco3 (11 files compared, ...)
--- Raw intro assets onto whole tracks ---
build/assets/intro_screen.raw: 30720 B framebuffer (7 tracks, 1536 B pad)
build/assets/intro_screen.raw: 30720 B -> build/probe.dsk tracks 27..33 (offset $01E600)
  FAT: granules 52..65 marked $C9 (used, no directory entry)
build/assets/intro_bundle.raw: 4608 B -> build/probe.dsk tracks 34..34
  FAT: granules 66..67 marked $C9
INTROSEQ.BIN                       1384             2 B
=== BUILD COMPLETE ===

loadm_from_disk              PASS 1384 B, 2 segments, at frame 644 — the real path
# frame   954  disk read 1 complete (+310 frames, 5.2 s)
# frame  2344  disk read 2 complete (+1390 frames, 23.2 s)
# frame  3723  disk read 3 complete (+1379 frames, 23.0 s)
capture_1_base               PASS

base capture vs the on-disk screen asset: 30720 bytes, 0 differ -> DISK READ IS EXACT
```

Oracle cadence (`build/oracle_snap/cadence.log`), verbatim in §3.1.

Regressions: `probe PASS`, `mode PASS`, `anim PASS`.
Karateka: `build/karateka.bin` sha1 `88eba89b15cdf17c8d25e082d2d3e1f3cce57d38` —
the standing baseline, **HELD**.

**25.2:** cadence finding §3.1 (`MASTER.S:1168/1211/724/862`,
`build/oracle_snap/cadence.log`); loader `src/hal/coco3-dsk/disk_read.s` +
`load_tracks` in `src/engine/intro_seq.s`; assets `harness/tools/raw_tracks.py`,
`harness/tools/make_intro_assets.py`.

**25.3:** **NOT OFFERED.** The sequence does not run to completion, so there is
nothing honest to put in front of Jay. P3.3 (`8ba6389`) is the last passing gate.

---

### 6 — Reactive deviations (§22.5)

1. **The dispatch's premises were refuted** (§3.2). Reported rather than built to,
   per Jay's governing instruction. The hard-stop in §10.2 is adjacent but not
   triggered: banking is **avoided**, not required.
2. **`disk_read.s` gained object-target guards** and joined POP's kernel. §6 permits
   loader adaptation; Karateka's binary is byte-identical.
3. **The screen is stored as a full framebuffer (30,720 B) rather than packed
   (26,880 B).** Disk space is what POP has spare; it removes the blit entirely and
   makes the disk read land 1:1.
4. **`load_tracks` releases the drive after every transfer.** The primitive leaves
   it selected and spinning — harmless for Karateka's loader, which jumps into the
   game and never runs another frame, and fatal here. The oracle brackets every
   load `driveon`..`driveoff`. Idiom §26.
5. **`-DDR_VARBASE=$1F00` silently defined the symbol as ZERO.** lwasm's `-D` takes
   a C-style literal; `$1F00` is accepted without warning and evaluates to 0, which
   put the disk parameter block at `$0000` on top of the HAL's DP scratch. `0x1F00`
   is correct. Idiom §25.
6. **`inc probe_loads` clobbered the Z flag `load_tracks` returns its verdict in**,
   so every successful read reported failure — complete with a plausible WD1773
   status byte that was the expected end-of-track RNF terminator all along.
7. **Two diagnostics perturbed their own measurement**, again (P3.3's lesson, third
   and fourth instances): a per-frame soft-switch write corrupted the oracle run
   in the first cadence attempt, and the `sts` probes changed the very behaviour
   they were measuring.

---

### 7 — Uncertainty flags

1. **THE SEQUENCE DOES NOT COMPLETE.** §3.5. Not diagnosed. Layout-sensitive, which
   points at memory corruption or aliasing rather than logic.
2. **Two bytes of the bundle read differ** from the asset (`$1B0B-$1B0C`, value
   `$1B`), in the trailing pad, outside every payload. Not explained. It may be the
   same defect as (1).
3. **The load is slow: 23 s per 7-track read**, ~3.3 s per track against a 0.2 s
   revolution. The oracle's entire stage-1 load is ~3 s. Nothing here required load
   speed, but ~50 s of drive noise before the first frame would fail a visual gate.
4. **The screen is read twice** to fill both buffers, because only one is
   CPU-addressable at a time. A chunked front-to-back copy through the spare MMU
   slots would halve the load; it was not attempted.
5. Carried: the pipeline still needs the oracle for display-faithful conversion.

---

### 8 — Follow-up candidates

1. **Diagnose the sequence failure** (§3.5). Everything else in P3.4 is blocked
   behind it, and the alignment-sensitivity suggests a stray write into `$0200-$03FF`.
2. **Load speed** (§7.3) — measure where the 3.3 s per track goes before adding
   screens.
3. **Halve the base load** with a chunked front-to-back buffer copy (§7.4).
4. **The title beat** — now fits; blocked on (1).
5. Carried from P3.3: `HAL_gfx_set_palette` is still a P3 stub; the unmasked
   counter read (P2.9); the edge-blink raster measurement; the two buffer models;
   the 16-colour frame budget; `POP-idioms-coco3-markers.md`'s fate; the CLAUDE.md
   boot-contract statement drafted in P2.8 §8.1.

---

### 9 — User interaction during task

None. (P3.3's closing exchange — Jay's "it looked good" — is recorded in that
report.)

---

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-07-27-a-primitive-proven-where-nothing-returns-leaks-state.md`
- `seeds/POP/live/2026-07-27-the-plans-premise-about-the-original-was-itself-untraced.md`

Pool commit `ea6fe39`.

---

### 11 — Commit

**POP:** `<hash>` — cadence trace, raw-track tooling, disk-loading sequencer,
idioms §25/§26, this report. Pushed to `origin/wip`.
**Karateka:** `<kar>` on `wip` — `disk_read.s` guard mirror; prod binary
byte-identical `88eba89b…`. `main` untouched at `5eb92b1`.
