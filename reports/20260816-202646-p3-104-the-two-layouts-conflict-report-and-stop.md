## Form B Report — P3.104 — the two layouts conflict: report and STOP

**Class:** recon (memory audit). wip. **Prod untouched — nothing merged, nothing moved, no `src/`,
`content/`, `link/` or `build.bat` change.**

**★★★ HARD-STOP 2 FIRED. §1 said to report conflicts BEFORE changing either program, and §7's
HARD-STOP 2 says a layout clash is a design step, not a merge step. There are THREE, and one of
them is arithmetic and certain: the merged program does not fit under the measured LOADM ceiling.
I have not started the merge.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-16T20:26:46-04:00 (HEAD `b1638c3`, wip). Karateka untouched. `main` untouched. Oracle
source read-only and not run. **No file in `src/`, `content/`, `link/` or `build.bat` was modified
by this dispatch.** Pre-existing and not mine: `dist/mame-cfg/rgb/coco3.cfg`.

---

### 1 — Summary

| | |
|---|---|
| **★★★ BLOCKING 1** | **`$3000` — the intro's caption bundle and the scene's flames bundle occupy the same region, and the intro needs its bundle AFTER the scene** |
| **★★★ BLOCKING 2** | **the merged `prog` is ~$820 B against a measured LOADM ceiling of `$2488..$2535`** |
| **★★ SUSPECT 3** | **`$5400` — the intro's `SAVE_BUF` is 1,024 B below the scene's packed-bundle landing zone; the gap's sufficiency is unmeasured** |
| **★ NOT a conflict** | **`DR_VARBASE` already has ONE home** — `build.bat` `0x6A00`, passed to all three assemblies |
| **★ NOT a conflict** | **disk tracks do not overlap** — full map below; tracks 17 and 24 are free |
| **★★ answered** | **how the scene must be reached: a CALL BETWEEN BEATS 4 and 5**, not a seventh beat — with the reason |
| **★★ answered** | **the scene's entry state is largely self-established** — it re-inits sys/MMU/mode/time and paints both buffers before its first peel save |
| **stated** | **`SetupDHires` and `Prolog2` are absent and were not built** |
| **not done** | the merge, and therefore AC3, AC5, AC6, AC8, AC9 |

### 2 — Files modified

**None.** The audit reads; it does not write. This report is the only new file.

### 3 — Reasoning

**3A — ★★★ BLOCKING 1: `$3000`, AND IT IS THE ONE THE REPO ALREADY PREDICTED.**

`link/pop_flames.link` closes with:

> *"Nothing else may live at `$3000` while the room is running. The intro's bundle uses the same
> region, **but the two programs never run at once**."*

**That premise is exactly what this dispatch was asked to break.** The measurements:

| | region | contents |
|---|---|---|
| **intro** | **`$3000..$52FF`** (2 tracks, 9,216 B) | `BUNDLE_PAL $3000`, `BUNDLE_PRESENTS $3040`, `BUNDLE_BYLINE $3400`, `BUNDLE_TITLE $3800` |
| **scene** | **`$3000..$4883`** (unpacked; `flames.raw` 6,276 B → 3,940 packed) | flame cels, blit core, `char_draw`, the VM's cel table |

**The overlap is `$3000..$4883` — and it lands on all three caption patches.**

★★★ **AND IT CANNOT BE SOLVED BY ORDERING, WHICH IS THE PART THAT MAKES IT BLOCKING.** The
oracle's own sequence puts the scene between Prolog1 and Prolog2 [`MASTER.S:695-709`], and the
port's beat table is:

```
  beat 1  splash  (track 27)  + BUNDLE_PRESENTS
  beat 2  inherit             + BUNDLE_BYLINE
  beat 3  inherit             + BUNDLE_TITLE
  beat 4  prolog1 (track 9)                       <-- the scene goes AFTER this
  beat 5  prolog2 (track 18)                      <-- and these two still need the bundle
  beat 6  splash  (track 27)  + BUNDLE_TITLE      <-- patches $3800, which the scene overwrote
```

**Beat 6 patches `BUNDLE_TITLE` at `$3800`, and the scene's bundle unpacks over it.** So the
intro's bundle must survive the scene or be re-read after it. **Neither is true today**, and
choosing between them (move one bundle / re-read tracks 25-26 on return / page one through the
MMU) is a design decision, not a merge.

**3B — ★★★ BLOCKING 2: THE MERGED PROGRAM DOES NOT FIT.**

From the maps of the current build:

```
  introseq   prog  intro_seq.o   $2000 +$03A5      lz_unpack.o +$008E   -> $2000..$2432
  room       prog  cutscene_room.o $2000 +$03ED    lz_unpack.o +$008E   -> $2000..$247A
```

`lz_unpack` is shared, so a merged program is about **`$03A5 + $03ED + $008E = $0820`** →
**`$2000..$2820`**, before a single byte of glue.

**The measured LOADM ceiling is `$2488..$2535`** [`link/pop_engine.link`, measured at P3.22 by
adding dead `rmb` filler to a known-good build: `prog` ending `$2487` boots 8/8; ending `$2535`
corrupts]. **A merged program overshoots it by roughly `$2E0..$390` bytes.**

★★ **AND THE FAILURE MODE IS THE ONE THAT COST THREE DISPATCHES**, so it is worth naming here
rather than discovering it: the probe byte reads garbage and the disk-read count is **zero** —
DECB wrote over the image as it loaded. It is **not** a logic bug, and `link/pop_engine.link`
records that P3.20 (twice) and P3.22 each spent rounds hunting one.

★ **The established route is already written down** in the same file: *"put the code on a
disk-resident track and reach it through a fixed table, the way the cutscene bundle does."*
**That is a design step and I have not taken it.**

**3C — ★★ SUSPECT 3: `$5400`, AND I AM NOT ASSERTING IT.**

The intro's caption save buffer is `SAVE_BUF equ $5400` — `patch_blit` saves the framebuffer rows
it is about to overwrite there. The scene reads its **packed** bundle to `FLAME_LOAD`, which the
builder places at **`$5800..$69FF`**. That is **1,024 B of clearance**, and *"in-place slack 8571
B"* refers to the unpack, not to this gap.

★ **I have not measured a caption patch's saved extent**, so I cannot say whether a patch ever
reaches `$5800`. **Reported as a suspect with the number that would settle it**, not as a finding
— and it only matters at all once the two programs share an address space.

**3D — ★ WHAT IS *NOT* IN CONFLICT, stated because I nearly reported two of these.**

1. **`DR_VARBASE` already has one home.** `build.bat:117` sets `0x6A00` and passes it to
   `hal_build.o`, `intro_seq.o` **and** `cutscene_room.o`. The `equ $1F00` in both sources is an
   `ifndef` fallback that the `-D` overrides. ★ Reading either source alone shows `$1F00` and
   suggests a clash; the build is already correct.
2. **The disk tracks do not overlap.** Full map from this build:

```
   9..10  prolog1.lz      (intro)        18..19  prolog2.lz      (intro)
  11..12  cel_res                        20..21  cel_pg2
  13..14  cel_pg0                        22..23  cel_pg3
  15..16  cel_pg1                        25..26  intro_bundle    (intro)
      17  free                           27..28  intro_screen.lz (intro)
      24  free                               29  princess_room.lz
                                         30..31  flames.lz
```

`DISK_ROOM_TRK equ 29 ; clear of the intro's spans and the directory` — the comment is accurate
and the allocation is already integration-safe.

**3E — ★★ AC2: HOW THE SCENE IS REACHED, AND WHY IT IS NOT A SEVENTH BEAT.**

**A call between beats 4 and 5.** The reason is structural rather than stylistic: a beat's fields
are `BEAT_TRACK / BEAT_WIPE / BEAT_PATCH / BEAT_PRE / BEAT_HOLD / BEAT_SONG` — **a picture, a
transition, a caption, two timings and a song.** The scene is none of those. Expressing it as a
beat would mean either a sentinel track value that the beat loop special-cases (a second home for
"what beat 5 is"), or six fields carrying values that mean nothing for this one entry.

★ **And the oracle agrees, in the only place that matters:** `MASTER.S:695-709` calls
`PrincessScene` as a peer of `Prolog1`/`Prolog2`, not as a variant of them.

**3F — ★★ AC7, ANSWERED AS FAR AS IT CAN BE WITHOUT MERGING — AND IT IS MOSTLY GOOD NEWS.**

§4a's four risks, against what `room_start` actually does:

| risk | finding |
|---|---|
| palette / video mode | **self-established.** `room_start` calls `HAL_sys_init` (PIAs, MMU, MC3=1), `HAL_mem_size_detect`, `HAL_time_init`, then `GFX_MODE_320x192x4` via `HAL_gfx_set_mode`, then `disk_read_init`. It inherits none of these. |
| MMU mapping | **self-established**, same call. |
| **★ the framebuffer under the first peel save** | **covered.** The room blob is unpacked into the back buffer and `HAL_gfx_mirror` fills the other, so **both buffers hold the room before any character is drawn** — the peel's first save cannot see the intro's leavings. This is what the oracle's `blackout` in `CUTPRINCESS` is for, and the port gets it from painting rather than clearing. |
| DP and stack | **NOT established by the scene** — they come from whoever calls it. The only two facts still open here, and both are cheap to fix at the call site. |
| moved addresses | **moot until §3A/§3B are resolved**, since resolving them is what would move things. |

**3G — §2H's THREE CHECKS.**

1. **A second mechanism for a different object class?** Yes, and it is why §3A is blocking rather
   than awkward: the intro's bundle is not one object but **three caption patches at three
   addresses**, and beat 6 reaches back for one of them *after* the scene would have run. A check
   that only asked "does the scene fit at `$3000`" would have answered yes-if-we-move-it and
   missed that the intro needs the region **later**.
2. **The calling routine.** `$3000` is not owned by `flame_cels.s` or by `intro_seq.s` — it is
   owned by `link/pop_flames.link` and by `intro_seq.s:155` **separately**, which is precisely how
   two programs came to claim it without anything noticing.
3. **Grep the reports.** `link/pop_flames.link` already states the conflict and the assumption
   that made it safe. **The assumption was true when written and this dispatch is the event that
   ends it** — so it is quoted rather than re-derived.

### 4 — Verification (AC-by-AC)

- **AC1 — memory conflicts reported before any merge.** §3A–§3D. **Done, and it is the
  deliverable.**
- **AC2 — how the scene is reached from the beat table, with the reason.** §3E.
- **AC3 — the scene integrated; the intro returns and finishes.** ★ **NOT DONE — HARD-STOP 2.**
- **AC4 — `SetupDHires` and `Prolog2` stated as absent.** **Both are absent from the port. Neither
  was built.** The oracle runs `PrincessScene → SetupDHires → Prolog2 → SilentTitle`; the port has
  no 16-colour swap and no `Prolog2` beyond beat 5's picture. **A future gate on this integration
  must not be read as a gate on a complete intro.**
- **AC5 — read-before-reveal across the whole sequence, as a measurement.** ★ **NOT DONE** — it
  cannot be measured across a sequence that does not exist yet. **What is confirmed for the scene
  alone** is that its own three reads finish before `HAL_gfx_mirror` reveals anything
  [`cutscene_room.s:270-296`: *"the picture is BUILT but not shown … and only now is it revealed,
  with every read finished"*]. **That is the standalone ordering, and §3 of the dispatch is right
  that integration is where it regresses a third time.**
- **AC6 — the scene's suites against the INTEGRATED build.** ★ **NOT DONE**, and §4a is correct
  that the standalone results do not carry. **Recorded as the gap it is**: today's green
  `introseq`/`room`/`walk` are evidence about the standalone builds only.
- **AC7 — the scene's inherited entry state.** §3F. **Answered for palette, mode, MMU and the
  framebuffer; DP and stack remain open.**
- **AC8 — suites green, 128 KB first; build verified by symbol.** §5.
- **AC9 — Jay gates LIVE.** ★ **Nothing to gate. No behaviour changed.**
- **AC10 — route accounting; sync bridge; Karateka; `main`.** §6.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim).** `build.bat` re-run this dispatch to take the audit's numbers
off a freshly baked image rather than off the tree: `=== BUILD COMPLETE ===`. Every figure in §3
comes from that run's maps (`build/obj/introseq.map`, `room.map`, `flames.map`, `cel_res.map`) and
its packer/track output. **The two blocking numbers — `$3000..$4883` and `$2000..$2820` against
`$2488..$2535` — are section loads and lengths, not estimates.**

Suites are as P3.103 left them and **nothing in this dispatch could have changed them** (no source
change): `introseq`, `room`, `walk` green at 128 KB; the five P1/P2 suites stay retired.
★ **I did not re-run them** — a suite result is evidence about a build, and this dispatch produced
no new build behaviour. Re-running to decorate the report would be a green tick that means nothing.

**25.2 bundled-artifact grep:** N/A — nothing built or bundled.

**25.3 operator-runtime-smoke: N/A — no behaviour changed, nothing to put on a screen.** Standing
gates unchanged: flash, glass, sand, slump, the feet, and **the exit walk (P3.103, Jay)** all
PASSED.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** No route proposed in advance. Against §6's ten criteria this change contains
**AC1, AC2, AC4, AC7 (partial) and AC10 in full**, and **AC3, AC5, AC6, AC8 (partial), AC9 NOT
DONE** — stopped by the dispatch's own HARD-STOP 2 on finding the conflicts §1 asked for.

★ **Stating the shape plainly, because a stopped dispatch is easy to read as a failed one:** §1 and
§7.2 together define this outcome as the correct one. The audit was the gate on the merge, the gate
did not pass, and **the value delivered is that the merge was not attempted** — §3B's ceiling
overshoot would have produced a corrupted image whose signature (`probe` garbage, **zero** disk
reads) has already cost this project three dispatches of logic-hunting.

**Reactive deviations (§22.5):** none. Nothing was changed to make the audit possible.

Oracle read-only and not run. Karateka untouched. `main` untouched. No `hal-sync` run — no HAL
change (it is unchanged since P3.103's green check).

### 7 — Uncertainty flags

- **★★ `SAVE_BUF`'s used extent is unmeasured** (§3C). 1,024 B of clearance; a caption patch's
  saved rows could in principle exceed it. It is a suspect, not a finding.
- **★ DP and stack on entry to the scene are not established by the scene** (§3F). Cheap to fix at
  a call site that does not exist yet.
- **★ The `$3000` resolution is unchosen.** Three shapes exist — move the scene's bundle, re-read
  the intro's tracks 25-26 on return, or map one through the MMU — and each has a different cost.
  **I have deliberately not picked one**; that is the design step §7.2 reserves.
- **The LOADM ceiling is a RANGE (`$2488..$2535`), not a point.** The overshoot is large enough
  that the imprecision does not matter here, but a resolution that lands near it would need the
  ceiling measured properly rather than bracketed.
- Carried: the mirrored cels' chroma; the exit's +13% block cause; P3.103's `mode`-cycling
  coverage gap; `SetupDHires` and `Prolog2`.

### 8 — Follow-up candidates

1. **Resolve `$3000`** — the three shapes above, costed. This is the next dispatch and it is a
   design one.
2. **Resolve the program size** — the established route is a disk-resident track reached through a
   fixed table [`link/pop_engine.link`], which is what the cutscene bundle already does. Whether
   the intro or the scene moves is the open question.
3. **Measure `SAVE_BUF`'s worst-case extent** — one offline read of the three caption patches.
4. Only then the integration, and with it AC5's whole-sequence read-before-reveal measurement and
   AC6's suites re-pointed at the integrated build.

### 9 — User interaction during task

None.

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-16-two-programs-verified-alone-share-an-address-space.md`

### 11 — Commit

`96873ec`  (pushed to origin/wip before this report)
