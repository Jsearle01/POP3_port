## Form B Report — P3.85b — the hourglass lands, and the screen was the wrong instrument

**Class:** build. wip. Prod untouched.
**★ The hourglass, the sand and `s_Magic` are in. The thing that had blocked the hourglass
for six dispatches was never its size — it was its RESIDENCY, and the fix was to stop
trying to page it.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-14T18:55:00-04:00 (HEAD `8bcc794`, wip). POP `main` untouched.
Karateka untouched. `hal-sync` OK.

---

### 1 — Summary

Three things landed, and one of them corrects a method rather than a defect.

| | before | **after** |
|---|---|---|
| beats in the scene | 18 | **19** — `s_Magic` traced at last |
| hourglass | deferred since P3.64 | **drawn, with its sand running** |
| pages / staged reads / loads | 4 / 1 / 2 | **4 / 1 / 2 — unchanged** |
| flame bundle | 4,608 B in 2 tracks | **4,608 B in 2 tracks, 4,608 B pad** |

The hourglass cost the pack **nothing**, because it does not go in the pack.

### 2 — Files modified

- `harness/tools/oracle_glass_beats.lua` — NEW; the beat tracer, on its third instrument
- `harness/tools/bake_scene.py` — `s_Magic` in `PLAN`; the scenery column; `check_scenery`
- `harness/tools/bundle_offsets_check.py` — plan stride 5 → 6
- `src/engine/char_draw.s` — `scenery_frame`, the sand's cadence, the flash, the imports
- `src/engine/flame_cels.s` — the five glass cels and their two tables
- `content/cutscene/glass/{glass0,glass1,flow0,flow1,flow2}/converted.s` — NEW
- `build.bat` — the glass bake, two phases

### 3 — Reasoning

**3A — ★★ THE SCREEN WAS THE WRONG INSTRUMENT, AND IT TOOK TWO WRONG ANSWERS TO SEE IT.**
`s_Magic`'s duration had to come off the oracle, and earlier cues had been timed by watching
a screen box and reading the quiet gaps between changes as the holds. That method was
reached for again and it failed twice:

| | method | what it said |
|---|---|---|
| v1 | per-object pixel boxes | glass and sand both "first change" at f3487 — **the princess turning.** She stands across the same columns until Pback backs her away |
| v2 | hashed boxes, but a **count** of lit pixels | a **26.6-second hold** across the exact stretch where the sand is supposed to be flowing |
| v3 | **write-taps on `SPEED`, `lightning`, `psandcount`** | one run, unambiguous |

v2's failure is the instructive one. A count cannot see one cel replace another of equal
ink, and the error it produces is **silent and one-directional** — a lossy summary always
reports a hold as LONGER than it is, never shorter, so the numbers stay plausible and only
get more wrong.

**★ And the deciding point is structural, not incidental.** `s_Magic` is the one cue during
which something animates — the sand runs through it. So the quiet-gap signal the screen
method depends on **cannot exist for it**. The method was not noisy for this case; it was
inapplicable, and nothing in its output said so.

`PlayCut0` brackets the cue exactly [SUBS.S:733-737] — `sta psandcount` immediately before,
`lda #7 / sta SPEED` immediately after — and the addresses were sitting in the assembler
listings beside the `ds` that reserves them (`SPEED $030C`, `lightning $0088`,
`psandcount $E14A`). Write taps, not read taps: a 6502 read tap false-0s through the
opcode-fetch bypass, but a store is not a fetch.

```
A  SPEED = 12, glass + flash   f4732
B  psandcount = 0, sand flows  f4773   A->B   41 frames  0.68 s
C  SPEED = 7, Vexit follows    f4886   B->C  113 frames  1.89 s   <- s_Magic
```

**It also corrected a detail nobody had questioned.** `lda #5 / sta lightning` reads like a
five-FRAME flash. The trace shows `lightning` stepping 5,4,3,2,1,0 at eight-frame spacing —
one per play. It is **five steps, one level each**, and the port renders five strobes rather
than one brief one.

**3B — ★★ THE HOURGLASS'S REAL OBSTACLE WAS RESIDENCY, NOT SIZE.** P3.85's first half found
the size figure had been wrong for six dispatches (994 B for this scene's five cels, not
3,981 for the game's twelve) and then costed the 994 against the pinned page — where it
now has 4,330 B spare and fits easily. But that was still the wrong question.

The hourglass is live **from the beat it appears to the end of the scene**, spanning beats
that map two different rotating blocks. A cel that straddles a mapping change is the one
thing `cel_pack` refuses, so it has to be pinned — and pinning it spends pinned budget on
an object that is not a character cel at all.

**It belongs in the flame bundle, which is already resident for exactly this class of
object.** The torches, the stars and the sand are one class in the oracle too
[SUBS.S:360 `pstars`, GAMEBG.S `DRAWGLASS`]. Put there, it costs the pack **nothing** —
the pages, the staged read and the two loads are all unchanged — and the bundle still fits
its two tracks with 4,608 B of pad. The 4,330 B of pinned slack stays available for §2.

**3C — Placement is derived, not guessed.** The port centres the Apple's 280 px in 320, so
CoCo px = Apple px + 20 — which is what puts the torches at px 111 and 201, and it is the
torches that prove the mapping rather than any assumption about scaling:

```
glassx 19 -> Apple px 133 -> CoCo px 153 = byte 38 phase 1   glassy 151 baseline, 25 rows -> top 127
flowx  20 -> Apple px 140 -> CoCo px 160 = byte 40 phase 0   flowy  149 baseline,  9 rows -> top 141
```

**Two phases, two bakes**, for the reason P3.56 spent a dispatch on: one phase for both
would put the glass a pixel off, which is the exact defect that sat on the left torch for
the life of the port.

**3D — Which beats show it is a PLAN column, not a test in the draw code.** The plays, the
block and the signature already come from one walk, precisely because a second derivation
of "which beat is it" drifts from the first — P3.78's beat-switch was that failure exactly.
So the hourglass is byte 5 of the beat row, generated by the same walk.

**★ And the indices are ASSERTED against the beat names, because this dispatch performed
the very edit that would have broken them.** Inserting `s_Magic` shifted every beat above
13; a scenery table keyed by index would have moved the hourglass one beat early with no
row malformed, no pack failure and no complaint. `check_scenery` compares each index's
expected name against `PLAN` before anything is written.

**3E — The sand has a peel; the body does not, and the difference is measured.** The body
never moves and is opaque [`DRAWGLASS` sets `OPACITY = sta`], so redrawing it each frame
restores nothing and accumulates nothing. The sand cycles, and the body's stream **does**
carry SKIP runs — checked, 80 skip headers in `glass0` — so redrawing the body does not
reliably cover last frame's sand. Assuming it would is how a smear ships.

**3F — The flash is a palette write, not a fill.** `lightcolor = $FF` is Apple hi-res white,
so it is a full-screen white strobe. The Apple must paint a screen to change its colour; the
GIME has four palette registers, so the flash costs **four stores and no pixels** — and
unlike a fill it cannot damage what is under it, so nothing needs saving.

### 4 — Verification

**25.1 (build):** `=== BUILD COMPLETE ===`, `[hal-sync] OK`, `[sequences] … 9 sequences`,
`[harness-offsets] all checked offsets agree`, `[cel-streams] 82 cels walk exactly to their
own end`.

**Two build failures on the way, both caught by gates rather than by me** — and the second
is the one worth recording. The `cel_plan` stride guard fired: `cel_plan is 100 B linked but
20 rows x 6 B is 120 B (off by -20)`. build.bat does not re-bake, so the plan was still the
5-byte one. That check exists because of `fcb 7  ,$0D` emitting one byte, and it caught a
completely different way of getting the same class wrong.

**Room suite (with the hourglass in):**
```
# checks=8 passed=8 failed=0     PASS room intact     PASS flames flicker
PASS flame pixels are exactly cel 3/8 over the room: 78 bytes byte-identical
```

**Walk suite (with the hourglass in):**
```
19 beats, 1 staged reads, live-disk, 28 captures
bank_mapped_at_every_capture PASS   engine_bank_guard PASS (ch_bankerr = 0)
page_sig_matched_every_frame PASS (1283 checked)
beats_visited PASS (19 of 19)       staged_reads PASS (1 of 1 pages, cel_rd_err = 0)
every capture 0 bytes WRONG; stability: all captures agree
STABLE: both runs walked the same positions and produced the same result
```

**Both suites were re-run after the flash went in, and both are green on that build.**
One re-run was needed for a reason worth recording: invoking the runners through
PowerShell resolves `bash` to **WSL's**, not Git Bash's, and WSL's rejected the scripts
outright (`line 16: set: -`, then `$'\r'`). The room suite had silently not run at all.
The suites above were run under Git Bash against the final build.

**25.2:** N/A — ROM build, no sibling-import artifact.
**25.3: PENDING JAY.**

### 5 — Acceptance criteria

1. **`s_Magic` traced as the other cues were** — **yes**, 113 frames, §3A.
2. **The `SPEED` 7→12→7 change** — **measured, not applied.** §3A gives its size at this
   beat (oracle 41 frames for five plays, port 35); the flat cadence table stands, now with
   the cost of the flag known where it is largest.
3. **Hourglass built** — **yes**, §3B, and without spending pack budget.
4. **The sand flowing** — **yes**, `psandcount`'s three-frame cycle, one per play.
5. **The flash** — **built** (§3F); **not yet seen by Jay.**
6. **Bank occupancy reported** — yes: resident 3,862 B of 8,192, 4,330 B spare, untouched
   by the hourglass.
7. **Suites green both sizes** — green as reported; **128 KB not run.**
8. **§2 grouping push for ONE load** — **NOT DONE.**
9. **Jay gates live** — **pending.**

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** I proposed, mid-task, putting the hourglass in the **pinned page** on
the strength of its 4,330 B of slack. **This commit does not do that** — it puts the five
cels in the **flame bundle** instead, for the residency reason in §3B. The pinned page is
untouched and its slack is still there. I also said I would defer the flash and report its
mechanism only; **the flash is in fact built**, so that deferral did not happen either.

Not present: §2's grouping push; the turn-to-exit disappearance; the 16-colour swap; the
`Prolog2` handoff; `s_StTimer` (still untraced, still absent, on the same rule that kept
`s_Magic` out until it was measured).

### 7 — Uncertainty flags

- **★ The hourglass has not been seen.** Everything above is a build gate and two automated
  suites; neither renders a judgement about whether it is in the right place. The placement
  arithmetic in §3C is derived from the torches and is exactly the kind of thing that has
  been a pixel out before.
- **The flash's cadence is a port decision, not a measurement.** The oracle strobes within
  each play; the port gives one white drawn frame per play. Five strobes either way, but the
  duty cycle is not matched and was not measured.
- **The 128 KB configuration was not run.**
- Carried: the turn-to-exit disappearance; ROOM.BIN's 6-byte LOADM headroom; the 0.20 s
  per-call driver overhead; `$2310..$2329` read-tap blindness; `PlayCut0`'s remaining sound
  sites.

### 8 — Follow-up candidates

1. **§2, and it is now better placed than it was** — 4 pages against 3 blocks, with 4,330 B
   of pinned slack that the hourglass did NOT consume. Zero staged reads means zero freeze.
2. Trace `s_StTimer` the way `s_Magic` was traced — the instrument is written now.
3. The 128 KB run.

### 9 — User interaction during task

None during execution.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-14-measure-the-mechanism-not-the-rendering.md` — when a program's
own variables bracket the thing being measured, read them; measuring the rendered output
adds an inference whose preconditions the measurement itself cannot report, and it fails
hardest on exactly the cases where the output is busy.

### 11 — Commit

`19771df` — pushed to origin/wip before this report.
Candidate pushed to the pool separately.
