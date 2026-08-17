## Form B Report — P3.78b–d — CH_X widens, the reveal is fixed, the clip is built and fails

**Class:** build (continuation of P3.78, `reports/20260812-004500-p3-78-the-split-lands-the-exit-does-not.md`).
wip. Prod untouched. **The blitter clip is IN THE TREE AND BROKEN, deliberately committed
failing.** Everything else here is verified.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-11T21:51:59-04:00 (HEAD `1608cd1`, wip). Now at `20c6140`, pushed.
POP `main` untouched at `635f986`. **Karateka untouched** — `wip` still P3.76's `ac2b768`,
`main` `5eb92b1`. `hal_sync_check` OK (11 files).
Room suite: 8/8 in-emulator, **asset comparison FAILS** (§5). Walk suite: FAILS
(`beats_visited`). Build assembles and links clean.

---

### 1 — Summary

**Three live findings from Jay, all decisive, none of which any automated check had
caught:**

| what he saw | what it was |
|---|---|
| *"the cels are just black rectangles now"* | **mine** — a half-migrated field (§3B) |
| *"the initial disk load is occurring with the static screen shown"* | **mine** — a regression of the bug P3.72f fixed (§3C) |
| *"he is still not being clipped at the right edge"* | correct; the clip is §3D and it does not work |
| *"the vizier disappears briefly except his feet during his turn to exit"* | **undiagnosed** (§7) |

**Landed and verified:** `CH_X` is genuinely 16-bit, so the wrap-to-left-edge teleport is
gone; `co_clip` is 16-bit, signed and bounded to the row; every disk read once again
finishes before the picture is revealed.

**Landed and NOT working:** the per-row clip inside the blitter — the option Jay chose over
the cheaper skip. It is committed failing rather than discarded.

**★ I asserted a cause from the tracer instead of measuring it, and Jay caught that too.**
See §3A: it is the third time this dispatch that a model has been wrong where the machine
was available.

---

### 2 — Files modified

- **`fee3392`** — `src/engine/char_draw.s` (CH_X 16-bit end to end; `co_clip` rewritten),
  `harness/smoke/walk_test.lua`, `harness/tools/peel_census.lua` (record offsets).
- **`8a3387f`, `16f20b0`** — `harness/smoke/run_room_live.sh` (the banner described a build
  it no longer launches, then described two contradictory ones).
- **`0f2e92e`** — `src/engine/cutscene_room.s` (startup reordered; `ROOM_BLOB` moved),
  `harness/smoke/room_test.lua`, `run_room_test.sh` (`disk_reads_ok` derived, not literal).
- **`20c6140`** — `src/engine/blit_core.s` (the clip, failing), `src/engine/char_draw.s`
  (the window in `co_setup`), `src/engine/flame_cels.s` (unclipped entries for the torches).

### 3 — Reasoning

**3A — ★ THE RIGHT-EDGE CLAIM WAS MADE FROM THE TRACER AND WAS WRONG.** P3.78's report
said `Vexit` walked him off the right edge and named that as the stall's cause. That came
from the Python trace. Jay: *"i don't see the vizier walking to the right edge in the
visual. you need to verify positioning."*

He was right. The build at that moment stalled at beat 15, **before** he ever got there —
so the claim named a real defect for a reason that had not happened yet. Measured properly
afterwards, from the engine's own `CH_X`/`ch_col`/`ch_w`/`ch_dest`:

```
f4941  x=233  col=85   cols 85..92     past VIS_R (74) and past the 80-byte row
f5019  x=254  col=97   cols 97..102
f5025  x=0                              CH_X is one byte and WRAPPED
f5096  cel=29 x=191 face=79 awid=244    the slot record is now garbage
```

The edge overrun is real; it was simply not what was stalling the scene then. **The
correction matters more than the sentence** — the same tracer had already been proved
wrong about `:loop` earlier in the same dispatch, and I used it again anyway.

**3B — ★★ A HALF-MIGRATED FIELD, SHIPPED TO HIS SCREEN.** `ch_col` had to become a word:
a character leaving the screen has a real column past 79, and a byte is exactly what let
col 85 read as plausible and wrap the row. `co_clip` kept reading it with `lda` — on a
big-endian 6809 that is the **high** byte, zero for every on-screen column — so every
character tested as off the LEFT edge and every frame blanked five bytes down the left of
every cel. The peel then saved that black as background and restored it, and it
accumulated into solid rectangles.

**I left that reader on the old width deliberately**, intending to retire `co_clip` in the
next step along with the blitter clip. That is the mistake, and it is not the endianness:
**a half-migrated field is a bug with a plan attached, and the plan is not in the binary.**

Fixed, and `co_clip` now computes both spills as explicit clamped spans so neither can
leave the row:

```
left  = [ max(col,0)       , min(col+w, VIS_L) )
right = [ max(col,VIS_R+1) , min(col+w, 80)    )
```

Verified: **28 captures, 0 bytes WRONG** against `verify_room_chars`' independent
prediction; guard clean; page signatures clean over 787 checked frames.

**3C — THE REVEAL, REGRESSED AND RESTORED.** P3.78 moved the cel-page loader into the
bundle (the room could not carry it and stay under the LOADM ceiling). That made the cel
read depend on `bundle_expand`, which lands on the room blob's ground and so must follow
`HAL_gfx_mirror` — **and the mirror IS the reveal**, because it writes the finished room
into the FRONT buffer. Eight tracks of disk moved to after the picture appeared.

This is precisely the bug P3.72f removed, and the file carries its warning. I then wrote
*"the load still happens BEFORE room_present, so it is still a black screen"* three
paragraphs below the text explaining that the reveal is at the mirror and **not** at
`room_present`. A comment can restate a claim the paragraph above it has already refuted,
and nothing in the toolchain reads either.

The order needs no new code, only the blob to move house:

```
bundle -> expand      the loader exists, and nothing is on screen
cel pages             eight tracks, still against black
room blob -> unpack   the picture is BUILT but not shown
mirror                ...revealed, every read already finished
```

`ROOM_BLOB` moves `$3000` → `FLAME_LOAD`, free the instant `bundle_expand` has run.
Measured: **room visible f2113 → flames moving f2115, 2 frames.** Room suite 8/8.

**3D — THE CLIP: WHAT IS RIGHT, AND WHY IT STILL FAILS.** Jay chose the faithful option
(clip inside the blitter, as the oracle's `CROP` does) over skipping a character whose span
would wrap.

Right, and worth keeping:
- `co_setup` computes the window **once per placement** as `bc_lead`/`bc_keep`, derived
  purely from `(col, width)`. That purity is load-bearing: `co_erase` recomputes the
  identical window from the **stored** x, so the restore covers exactly the span the save
  took. A window derived from anything the frame knows but the save did not would restore
  the wrong bytes.
- `bc_trim` pre-trims each **segment**, not each byte, so the merge path keeps its measured
  22 cy/byte floor (P3.19) and a fully-on-screen character adds nothing to the inner loop.
- `blit_cel_full` / `blit_save_full` / `blit_erase_full`. The window is a global and the
  torches are drawn straight through `blit_tab` without ever calling `co_setup`; on the
  first build they inherited the last character's window and the flames came back 30 bytes
  wrong. **A global that some callers must remember to set is a trap**, so the callers who
  do not clip get their own doors.

**Wrong, and the shape of the finding is the useful part:** the room asset comparison fails
with **296 bytes disturbed, first at row 109 col 37** — the princess's own columns, where
`lead=0` and `keep=`her full width, so the window should be a **no-op**. Failing *there*
says the fault is not in the trimming arithmetic but in something the rewrite changed for
**every** placement, clipped or not. `blit_erase` now walks the framebuffer through `U`
instead of `X` and takes its peel row from `bc_peelrow`; that is the most-changed code and
the first place to look.

**A bisect would settle it in one run** — force the peel primitives full-width, leave the
draw clipped — and it is **deliberately not committed**: a probe left in the tree is the
same half-migrated trap as §3B.

### 4 — Verification

**25.1 fresh tool output (at `20c6140`):**
- `build.bat` → `[sequences] port streams agree with the traced oracle over 80 steps, 9
  sequences`; `ok cel_plan 19 rows x 5 B = 95 B linked`; `ok cel_page_tab 5 rows x 2 B =
  10 B`; `=== BUILD COMPLETE ===`
- `run_room_test.sh` → `disk_reads_ok PASS loads=10 (want 10)`; `startup_gap_small PASS
  room visible f2113 -> flames moving f2116 = 3 frames`; `checks=8 passed=8 failed=0` —
  **then** `FAIL room disturbed outside the torches: 296 bytes; first at row 109 col 37`
- `hal_sync_check.py` → `OK`
- At `fee3392` (before the clip): walk suite `28 captures, 0 bytes WRONG`, `engine_bank_guard
  PASS`, `page_sig_matched_every_frame PASS (787 checked, 0 mismatches)`, `staged_reads PASS
  (2 of 2 pages, 4 disk calls, cel_rd_err = 0)`, `STABLE`

**25.2:** N/A. **25.3: NOT OFFERED.** The scene does not finish and the room asset check
fails. Jay ran `run_room_live.sh` at his own request (77 s, 100% speed, live-disk, RGB) —
that was **showing him the build, not a gate**, and nothing here is claimed from it.

### 5 — Acceptance criteria (against P3.78's dispatch)

Unchanged from the first report except where noted:

1. **Packed and split, per-beat mapping, no straddling** — yes.
2. **A signature per block; refuse-to-draw; a magic** — yes.
3. **Guard exercised by a REAL wrong mapping** — built (`-DSEED_WRONGBLOCK`), **not run.**
4. **Two staged reads, cost measured** — yes: **3.19 s and 2.89 s**.
5. **Beats landed** — the five character beats, yes. **The hourglass, its flash, `s_Magic`,
   the 16-colour swap and the `Prolog2` handoff are NOT built** (§6).
6. **The suite cannot pass on nothing** — yes; sample counts are inside the assertions and
   the checks were checked (`verify_sequences` demonstrated to fire).
7. **All suites green both sizes** — **NO.** Room asset comparison fails; walk stalls at
   `beats_visited`; 128 KB and intro not re-run.
8. **Jay gates live** — **not offered.**
9. **Route accounting; sync bridge; Karateka and both `main`s untouched** — yes.

### 6 — Reactive deviations and route accounting

**This continuation contains:** `CH_X` 16-bit, `co_clip` corrected, the startup reorder, the
live runner's banner, and a failing blitter clip. **It does not contain:** the hourglass,
the lightning flash, the `s_Magic` hold, `addglass1` state 1, `s_StTimer`, the 16-colour
swap, the `Prolog2` handoff, the seeded real-wrong-mapping run, or a working clip.

**Deviations:**
- **Jay chose the clip design** (per-row in `blit_core`) and **`CH_X` widened to 16-bit**
  over the cheaper alternatives I recommended. Both were built as chosen; only the second
  works.
- **The room's `disk_reads_ok` was a literal `3`** and had become a check that fails as a
  disk fault whenever the pack changes shape. Now derived from `cel_pack.json`.
- **The failing clip is committed rather than reverted**, per the standing invariant and
  HARD-STOP #5 (ask in place; state what is in the tree).

### 7 — Uncertainty flags

- **★ THE CLIP DOES NOT WORK** (§3D). The room is wrong at columns the window should not
  touch. Next step is the one-run bisect.
- **★ "Disappears except his feet during the turn" is UNDIAGNOSED.** I have deliberately not
  guessed. One lead, held as a lead and not a diagnosis: the mapping changes mid-gesture —
  cels 57–61 are in page 3 and 62–66 in page 4 — but the guard reported clean and the page
  signatures matched on all 787 checked frames, which argues against it. The instrument that
  would settle it is `CH_CEL` against `ch_drawn` per step through beats 14–15, which
  distinguishes "the draw was skipped" from "the draw used wrong data."
- **★ THE FREEZES ARE 3.19 s AND 2.89 s** against the 1.7 s Jay accepted at P3.75, because a
  page is two tracks and not one. The lever is the runtime mirror (~5,155 B; P3.76 §3D
  costed it as turning one read from two tracks into one). **Still his call.**
- **ROOM.BIN has 7 bytes** under the practical `$2480` ceiling.
- The 128 KB runs and the intro suite have not been re-run since `88f9592`.
- Carried: `build.bat` does not run `bake_scene`; the 0.20 s per-call driver overhead; the
  `$2310..$2329` read-tap blindness; `PlayCut0`'s remaining sound sites.

### 8 — Follow-up candidates

1. **Bisect the clip** (peel full-width, draw clipped) — one run, and it halves the search.
   Suspect `blit_erase`'s U/X swap and `bc_peelrow`.
2. **Diagnose the turn** with a `CH_CEL` vs `ch_drawn` trace over beats 14–15.
3. **The hourglass beat** — `addglass1` states 0 and 1, the 5-frame `lightning`/`lightcolor`
   flash, `s_Magic` as a measured hold. **`s_Magic` would also give the packer a third read
   point in the one region where it currently has none.**
4. **Retire `co_clip`** once the blitter clips — two mechanisms for one job is how this
   class recurs.
5. Run the seeded real wrong mapping (AC3); re-run both sizes and the intro suite.
6. **Re-measure the p90 frame** after the clip lands: it adds a bounds test per segment.

### 9 — User interaction during task

Six interventions from Jay, all live observation, all load-bearing: the teleporting vizier
(P3.78 §9, ×1), the missing hourglass and flash, the right-edge positioning challenge that
overturned my tracer-derived claim, the black rectangles, *"show me"* → *"show me the
build"* (the live run), and the load-before-reveal. **Four of the six found defects; none
of them were found by a check.**

### 10 — Candidate(s) captured this task

None new in this continuation. The first report captured
`seeds/POP/live/2026-08-12-both-sides-of-a-check-from-one-derivation.md` (`9b53dae`).

§3B is a second instance of a shape worth watching — *a field widened but not fully
migrated, with the remaining reader left for a later step* — but it is close enough to the
existing `name-which-layer-a-number-belongs-to` row that the right move is to strengthen
that at reconcile time rather than file a near-duplicate, exactly as P3.76 §9 decided.

### 11 — Commits

`fee3392`, `8a3387f`, `16f20b0`, `0f2e92e`, `20c6140` — pushed to origin/wip before this
report. (P3.78's own: `88f9592`, report `d863eee`.)
