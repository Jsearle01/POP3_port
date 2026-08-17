## Form B Report — P3.100 — the exit column is the oracle's exactly, and the mirror anchor is exonerated

**Class:** recon (instrument + measurement). wip. Prod untouched; **no `src/` or `content/` change.**

**★★★ THE MEASUREMENT LANDED AND IT DID NOT ATTRIBUTE THE SKIP. The port draws all six of the
vizier's walk cels during the exit at EXACTLY the oracle's left-edge pixel — not similar, not
matching in deltas, identical: 168, 173, 176, 181, 182, 191, 188, 193 … on both machines, from
the same CharX, cycle after cycle. §5 HARD-STOP 2 therefore applies: both sequences are reported,
the next split is named, and NOTHING IS FIXED. The mirror anchor is exonerated by measurement, not
demoted by argument.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-16T13:08:53-04:00 (HEAD `c35622f`, wip). Karateka untouched. `main` untouched. Oracle
source read-only — `run_oracle_trace.sh` copies the `.hdv` to `build/` before the emulator opens it,
and `git status oracle/` is clean. No `src/` or `content/` change, so no prod `.bin` moved.
Pre-existing and not mine: `dist/mame-cfg/rgb/coco3.cfg`, the untracked `docs/ground-truth/*.pdf`.

---

### 1 — Summary

| | |
|---|---|
| **★★★ measured** | the port's exit column, **full 16-bit `ch_dest` at the write**, DRAW pass, vizier, cels 48..53 |
| **★★★ measured** | the oracle's, **on the running machine**, same six cels, at MLayGen's own store |
| **★★★ result** | **IDENTICAL, absolutely** — same left-edge pixel every step, every cycle |
| **★★ exonerated** | **the mirror anchor.** It was the leading suspect for four dispatches; it is not the cause |
| **★★ also excluded** | a stall or a dropped cel — the port draws all six, in order, once per step |
| **★ controls** | both taps **seeded and confirmed**; the oracle's first seed **silently no-op'd and the control caught it** |
| **★★★ NOT established** | **why the exit skips.** No attribution. Nothing fixed |
| **found en route** | two suites carried **no `-ramsize` at all** — every green they ever reported was 512 KB |
| **retracted** | nothing. P3.97's six numbers turn out to be right — **and they are evidence now for the first time** |

### 2 — Files modified

- `harness/tools/port_exit_column.lua` — NEW; 16-bit `ch_dest` at the write, DRAW pass, six cels, seeded
- `harness/tools/oracle_exit_column.lua` — NEW; the oracle's anchor at MLayGen's store, seeded
- `harness/smoke/run_exit_column.sh` — NEW; port runner, control first, 128 KB, live-disk
- `harness/smoke/run_exit_column_oracle.sh` — NEW; oracle runner, control first
- `harness/smoke/run_cel_test.sh` — sources `ramsize.sh`, passes `$RAMOPT` (it had none)
- `harness/smoke/run_compiled_test.sh` — same
- `reports/20260816-130853-…md` — this

(explicit-path staging only)

### 3 — Reasoning

**3A — THE TWO SEQUENCES, WHICH ARE THE DELIVERABLE.**

Both sides reduce to a **left-edge pixel in the oracle's 280-res space**, because the two machines
quantise position differently and comparing them *as columns* compares two rulers. The oracle's
column is a **7-pixel** Apple byte plus a separate `OFFSET` 0..6; the port's is a **4-pixel** CoCo
byte with the remainder carried by the baked variant. So: oracle `= XCO_after*7 + OFFSET`, port
`= cs_px − 20` (dropping `co_setup`'s 320-screen centring). Neither number is computed offline.

| step | cel | awid | oracle CharX / port CharX | **oracle left-edge px** | **port left-edge px** | Δ |
|---|---|---|---|---|---|---|
| 1 | 49 | 4 | 156 / 156 | **168** | **168** | +0 |
| 2 | 50 | 5 | 162 / 162 | **173** | **173** | +0 |
| 3 | 51 | 5 | 163 / 163 | **176** | **176** | +0 |
| 4 | 52 | 4 | 162 / 162 | **181** | **181** | +0 |
| 5 | 53 | 4 | 163 / 163 | **182** | **182** | +0 |
| 6 | 48 | 3 | 164 / 164 | **191** | **191** | +0 |
| 7 | 49 | 4 | 166 / 166 | **188** | **188** | +0 |
| 8 | 50 | 5 | 172 / 172 | **193** | **193** | +0 |

and the per-cycle deltas, steady state, on **both**: `48→49 −3, 49→50 +5, 50→51 +3, 51→52 +5,
52→53 +1, 53→48 +9` — sum +20 px, six steps, repeating without variation for the whole walk-out on
each machine. **The divergence AC4 asks to be named as "a frame and a column" does not exist.**

★ **P3.97's withdrawn `+5,+3,+5,+1,+9,−3` is the same six numbers.** That figure was withdrawn at
P3.99 because it came from `cel_parity_rule.draw_x` run offline, and `draw_x` is a transcription of
MLayGen, so the comparison could not have failed. It happens to have been correct. **The correction
still stands and the withdrawal was still right**: the number was not evidence then and it is
evidence now, and the difference between those two states is the whole of this dispatch. A result
that could not have come out otherwise narrows nothing.

**3B — WHAT ELSE THE TRACE EXCLUDES, WHICH IS WORTH MORE THAN THE COLUMN.**

The port's exit rows show cels **49, 50, 51, 52, 53, 48, 49, 50 …** — each drawn exactly twice
(once per double-buffer page, at the same position), never three times, never skipped. So:

- **there is no stall.** `char_one`'s `cmpu #0 / beq cp_none` ("no cel: draw nothing") never fires
  here — P3.97's own hypothesis, written into the tool's header, is refuted by the tool.
- **there is no dropped cel.** All six mirrored variants exist and are drawn: the baked phases
  `v48_m_p3, v49_m_p0, v50_m_p1, v51_m_p0, v52_m_p1, v53_m_p2` are exactly the measured
  `cs_px mod 4` = 3,0,1,0,1,2, and all twelve walk bakes (six mirrored, six normal) are distinct
  by sha1 — no duplicated frame.
- **the cadence is not it either.** The port holds each cel a uniform **8 frames** on the exit —
  and a uniform 8 on the ENTRY too, which does not skip. Whatever differs, it is not the exit's
  own cadence against the entry's.

**So the skip is not a wrong position, not a missing draw, and not a different cadence from the
walk that does not skip.** That is a much narrower box than this arc has had.

**3C — WHAT IS LEFT, AND THE NEXT SPLIT.**

Ordered by what the measurement leaves standing, not by shape:

1. **★★ THE MIRRORED CELS' PIXELS.** The one input unique to the exit. Position is now excluded,
   the six bakes are distinct, and the phases are right — but *distinct* is not *correct*. A bake
   that is the right cel mirrored at the wrong row alignment, or the wrong source frame, reads as
   "a frame is missing" while the position sequence stays perfect. **The check is offline and
   cheap:** composite each `v4x_m` against the mirror of its own `v4x` source and diff. This is
   also the one thing `verify_room_chars` cannot catch if the checker reconstructs from the same
   mirrored asset the baker used.
2. **★ THE ERASE/DRAW ASYMMETRY, still unexamined** (P3.99 §3D.1, carried). `co_erase` rebuilds the
   anchor from a PAST save's stored `face`/`awid`, so within one step the same cel is set up twice
   with different inputs. This dispatch **filtered that out on purpose** (`ch_cp == CP_DRAW`) to
   answer the narrow question cleanly — which means it says nothing about it. The instrument
   already carries `ch_cp`; recording all three passes is a one-line change and one run.
3. The **absolute** frame timing against the oracle's (port 8 frames/step, oracle 6–7 and drifting
   down) — but this is the accepted P3.87 pace slip and it applies to the entry equally, so it is
   third, not first.

**3D — §2H's THREE CHECKS.**

1. **A second mechanism for a different object class?** Yes, and it bit the instrument twice. On
   the oracle, `LayGen` and `MLayGen` both open `JSR PREPREP`, and a **clipped** normal lay writes
   `XCO` from `CROP` — so "the first XCO write inside a lay" is MLayGen's anchor *for the mirrored
   character* and something else entirely for a clipped tile. The seeded control is scoped to the
   six images for exactly that reason. On the port, `co_setup`'s three callers are the same shape
   one level down.
2. **The calling routine.** `co_setup` is called from `co_erase`, `co_save` and `co_draw`; the
   fact reported here is `co_draw`'s and is labelled as such. On the oracle the enclosing routine
   is `MLayGen`, reached from `LAY` via the OPACITY sign bit, reached from the mid-list draw loop —
   which is why the `IMAGE` pointer P3.99 logged could not name a cel and `IMSAVE` (the image
   NUMBER, saved before `setimage`) can.
3. **Grep the reports.** P3.97, P3.98 and P3.99 all discuss this stride. P3.98's report already
   carries P3.99's retraction banner; nothing further needed rewriting, because this dispatch
   confirms rather than contradicts the withdrawn figure — while replacing its provenance.

**3E — THE INSTRUMENT'S OWN ACCOUNT (§3 of the dispatch).**

Three faults in two dispatches were named; this dispatch closed all three and found two more of its
own, both caught by the controls rather than by review.

| fault | how it was closed |
|---|---|
| `ch_dest` sampled at the `cad_idx` tick — **stale** | tapped at the `std`, not at the step |
| the write tap caught **only the high byte** | **two taps**, `ch_dest` and `ch_dest+1`; a column error is invisible in the high byte, since 80 B per row means every column in a row shares it |
| `port_exit_walk.lua` read facing at slot **+5**, which is `CH_H` | `CH_FACE` is **+3** [`src/engine/char_draw.s:300`] |
| **NEW** — the oracle mirror read off `LAY`'s `and #$7f / sta OPACITY` | **misclassified half the data**, producing two tables holding the same steps. Replaced by an observation: inside a lay the first `XCO` write is the anchor and the second is `DONE`'s restore, so mirrored ⇔ `xco[1] ≠ XSAVE` |
| **NEW** — the oracle lay boundary taken from the `IMSAVE` write | `$F2` is written by more than `PREPREP`, giving ~700 phantom lays with a garbage `OFFSET` (values of 32 for a 0..6 field). Boundary moved to `XSAVE`, `PREPREP`'s only writer |

**★★★ AND THE SEED ITSELF FAILED SILENTLY, WHICH IS THE FINDING I DID NOT EXPECT.** The oracle's
first seed patched `MLayGen`'s `SBC WIDTH` → `SBC #$28`. It matched the routine's ten bytes against
`HIRES.LST` first and refused to write on a mismatch. **The bytes matched. The write was
discarded** — HIRES lives in language-card RAM, which the IIe *reads* as RAM and *write-protects*,
so the verification confirmed the address and never the writability. The control reported `0 lays
whose first XCO write is the seeded anchor` and I read it as a probe failure; it was a **seed**
failure, and a probe that had genuinely been blind would have produced identical output.

The seed now moves an **input** instead of the code: the `WIDTH` write inside `PREPREP` is
substituted to 40, **for images 74..79 only**, and the `XCO` tap **reads `WIDTH` back at the moment
of use** so "the seed never landed" is a third reported outcome, never a verdict on the tap. Both
controls then passed — see §4.

### 4 — Verification (AC-by-AC)

- **AC1 — the engine's full 16-bit drawn column, at the write, six walk cels, during the exit.**
  `build/tmp/port_exit_column_measure.log`: 82+ draws, `# all ch_dest writes by pass: cp 0 x357,
  cp 1 x360, cp 2 x1380 (CP_DRAW = 2, derived from the map)`, `orphan low-byte writes: 0`. Filtered
  to `ch_cp == CP_DRAW`, `ch_idx == 0`, cel ∈ 48..53; split ENTRY/EXIT by the engine's own
  `ch_face`. `CP_DRAW` is **derived** (`CP_DRAW − CP_ERASE`, and `CP_ERASE` is `equ 0` so its map
  value is the section base), never written as a literal.
- **AC2 — the oracle's, for the same six, from the running machine.**
  `build/tmp/oracle_exit_column.log`, armed on PlayCut0's ordered markers (SPEED 12 → psandcount 0
  → SPEED 7) at frame 4886, **not** on a frame number. The six are named in the **oracle's** numbering
  (images 74..79 from `content/cutscene/cel_table.s`) and the mapping is confirmed by the oracle's
  own image headers: `widths seen: 74:w3 75:w4 76:w5 77:w5 78:w4 79:w4 — MATCHES cel_table`.
- **AC3 — neither side from a formula.** Port: a write tap on `ch_dest`/`ch_dest+1` plus `cs_px`,
  `ch_col`, `ch_awid`, `ch_face`, `CH_X`, all read out of the machine. Oracle: write taps on
  `XSAVE`, `WIDTH`, `OFFSET`, `IMSAVE`, `XCO`. `cel_parity_rule.draw_x` is not invoked, imported or
  consulted anywhere in either tool.
- **AC4 — the two sequences side by side; any divergence named as a frame and a column.**
  §3A. **There is no divergence to name** — every step agrees to the pixel.
- **AC5 — the tap seeded and confirmed to report a known column.** Both, and the runners put the
  control FIRST and fail the run if it does not pass:
  - port: `# SEEDED at $3FDA: 'addd ch_base' -> 'ldd #$A10A'` … `# CONTROL PASSED: all 413
    post-seed taps reported $A10A, both bytes.` (a 3-byte-for-3-byte `$F3 ext` → `$CC imm` swap,
    the six-byte pattern including the following `std ch_dest` matched in full before writing)
  - oracle: `# MLayGen's ten bytes match the listing at $F35E (seen at frame 4888).` …
    `# images 74..79 after the seed: 64 anchored at XSAVE-40, 0 with the substitution not present
    in WIDTH, no mismatches` … `# CONTROL PASSED: all 64 seeded lays reported XSAVE-40 exactly`.
    XSAVE−40 wraps to `$E0..$FF`, a column no legitimate `XCO` (0..39) can take, so the control
    cannot be satisfied by a coincidence of the real geometry.
- **AC6 — fixed and carried through IF attributed; otherwise the sequences and the next split.**
  **Not attributed.** The sequences are §3A, the next split is §3C. **No `src/` or `content/`
  change; the mirror anchor was not touched.**
- **AC7 — suites green, 128 KB first; build verified by symbol from a freshly baked image.**
  §5. `build.bat` run fresh; both tools resolve every address out of `build/obj/flames.map`
  (`FAIL no symbol` and abort otherwise) and out of `oracle/source/obj/*.LST`.
- **AC8 — route accounting; sync bridge; Karateka; `main`.** §6. `[hal-sync] OK -- HAL source
  aligned with karateka_coco3 (11 files compared)`. Karateka untouched; `main` untouched.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim).**

`build.bat`:
```
--- cel image: 5 units placed, 10 tracks ---
       6 File(s)           36581 bytes                           18432 bytes free
=== BUILD COMPLETE ===
```

Suites, **all at 128 KB** (`ramsize.sh`, `-ramsize 128K`):
```
=== probe ===     [run_probe_test] PASS
=== mode ===      [run_mode_test] PASS
=== cel ===       [run_cel_test] PASS
=== anim ===      [run_anim_test] PASS
=== compiled ===  [run_compiled_test] PASS
=== introseq ===  [run_introseq_test] PASS
=== room ===      PASS flame pixels are exactly cel 3/8 over the room: 78 bytes byte-identical
                  [run_room_test] PASS
=== walk ===      STABLE: both runs walked the same positions and produced the same result
                  [run_walk_test] PASS
```

★ **`cel` and `compiled` are green at 128 KB for the first time.** They carried **no `-ramsize`
flag at all** — P3.98's sweep onto `ramsize.sh` missed them, so every "green" either has ever
reported was on the 512 KB machine. Both were re-run after the fix and both pass. Reported here
rather than filed quietly, because it is the same shape P3.98 named: **a policy and a default that
disagree.** It was found by grepping for the file that is supposed to be sourced — re-reading §2K
would not have found it.

`[hal-sync] OK -- HAL source aligned with karateka_coco3 (11 files compared, EOL/guard/export-placement normalised)`

**25.2 bundled-artifact grep:** N/A — harness-only change, no sibling-import artifact.

**25.3 operator-runtime-smoke: N/A this dispatch — no `src/`/`content/` change, so there is nothing
new to put on a screen.** Standing gates unchanged: flash, glass, sand, slump and the feet all
**PASSED** (Jay, live-disk, RGB, 128 KB). **The exit walk skip remains OPEN and unattributed**, and
this dispatch narrows it without closing it.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** I proposed no route in advance; the plan was the dispatch's. What this change
contains against §4's list: **AC1–AC5, AC7, AC8 in full.** **AC6 deliberately not exercised** — the
cause is not attributed, so under §5 HARD-STOP 2 nothing was fixed, and in particular **the mirror
anchor was not touched despite being the last suspect standing.** Named as not-done rather than
silently absent: the erase/save passes were **filtered out** of this measurement on purpose, so
§3C.2 is open work I did not start; and §3C.1's bake-content diff is named, not run.

**Reactive deviations (§22.5), both small and both stated:**
1. `run_cel_test.sh` and `run_compiled_test.sh` now source `ramsize.sh`. Outside the dispatch's
   letter; inside AC7, which asks for suites green **at 128 KB** — and two of them were not being
   run there at all. One line each, and the value goes through the existing one home.
2. The oracle seed changed mechanism mid-dispatch (code patch → input substitution) after the code
   patch was shown not to take. §3E.

Oracle source read-only. Karateka untouched. `main` untouched. `hal-sync` OK.

### 7 — Uncertainty flags

- **★★ The exit skip is still unattributed.** Three suspects are now excluded by measurement
  (column, stall/dropped cel, exit-vs-entry cadence). **"Last candidate standing" was wrong about
  the mirror anchor and it would be wrong again about §3C.1** — that one is next because it is
  cheap and unexcluded, not because it is what remains.
- **★ The oracle's step cadence drifts** across the walk-out (7,7,7,7,7,6 … then 6,6,6,5,5,5)
  while the port's is a flat 8. I have not established whether that is the oracle's `SPEED`
  changing, a second draw path, or an artefact of my lay boundary. **It is not offered as a lead;
  it is offered as something I saw and did not explain.**
- **★ The oracle's `NORMAL lays` table is empty**, as expected (the window arms at Vexit, so the
  entry walk is outside it) — which means **the oracle side has no within-run control column.** The
  port's entry walk serves that role and the oracle's does not.
- The mirror classification `xco[1] ≠ XSAVE` is sound **for these six cels** (every row shows the
  `[anchor][XSAVE]` pair, and the anchor is `XSAVE − WIDTH` in all 70 rows). It is **not** sound
  for clipped tiles, and the seeded control is scoped accordingly.
- Carried, unchanged: the characters' per-iteration draw (blocked by the torch repaint); 0.20 s
  per-call driver overhead; the `$2310..$2329` read-tap blindness; `Fdy` dropped at `cel_table+2`;
  the terminal beat's flowing sand never commented on; `PlayCut0`'s sound sites stubbed as holds.

### 8 — Follow-up candidates

1. **The six mirrored bakes' pixels** — composite each `v4x_m` against the mirror of its own
   `v4x_src` and diff. Offline, no machine. §3C.1.
2. **All three passes, one run** — drop the `CP_DRAW` filter in `port_exit_column.lua` and report
   erase/save/draw columns per step, to close P3.99 §3D.1. §3C.2.
3. **An oracle control column** — arm a second window on the ENTRY walk so the oracle has the same
   entry/exit split the port's table already has.
4. Audit the remaining runners for other §2K gaps the same way this one was found (grep for the
   sourced file, not for the policy).

### 9 — User interaction during task

One message: **"continue"**, mid-dispatch, while I was tracing the oracle's `OFFSET`. No
instruction, no scope change.

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-16-a-formula-agreeing-with-itself-is-not-evidence.md` (the dispatch's own)
- `seeds/POP/live/2026-08-16-a-seed-that-silently-no-ops-publishes-a-pass.md` (new, from §3E)

Committed and pushed to the pool (fire-and-forget, non-blocking).

### 11 — Commit

`69d5461`  (pushed to origin/wip before this report)
