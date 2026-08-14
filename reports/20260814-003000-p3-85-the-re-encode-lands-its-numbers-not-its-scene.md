## Form B Report — P3.85 — the re-encode lands its numbers but not its scene; the hourglass is a quarter of its estimate

**Class:** build (partial, **failing and committed failing**). wip. Prod untouched.
**★ The re-encode achieves every figure P3.79 predicted and the scene resets at beat 12.**
The hourglass is measured and **not built** — the packer refuses it under the old encoding,
which inverts this dispatch's build order.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-13T21:44:11-04:00 (HEAD `c0922b2`, wip). Now at `ca3939d`, pushed.
POP `main` untouched at `635f986`. Karateka untouched (`wip` `ac2b768`, `main` `5eb92b1`).
`hal_sync_check` OK.

```
BUILD   green; five new/updated gates all pass
room    8/8, room intact, flames flicker, 78 bytes byte-identical      <- GREEN
walk    resets the machine during Pback (beat 12)                      <- FAILING
```

**The tree is left failing deliberately.** The last fully green commit is `22c9e31`.

---

### 1 — Summary

**The re-encode works as designed and as predicted:**

| | predicted | **achieved** |
|---|---|---|
| pages | 4 | **4** |
| staged reads | 1 | **1** |
| **disk loads** | **2** | **2** |
| pinned page (cels) | — | **5,942 → 3,468 B** |

**★ And the scene resets partway through `Pback`.** Room suite is fully green including
`78 bytes byte-identical`, so the packed decode is correct for everything that suite
reaches. **The cause is not attributed** and is not being closed as bounded.

**★★ THE HOURGLASS IS 994 B, NOT 3,981.** It needs **five** cels, not twelve — and that
changed the build order this dispatch was given.

### 2 — Files modified

`ca3939d` — `harness/tools/cel_blit_prep.py` (packed encoder + a replay that now *parses*
the packed header rather than being told it), `src/engine/blit_core.s` (the decode),
`harness/tools/verify_cel_streams.py` (new, wired into `build.bat`),
`harness/tools/glass_fit.py` (new), `content/cutscene/chars/` (re-baked).

### 3 — Reasoning

**3A — ★★ THE HOURGLASS, AND THE ESTIMATE THAT BLOCKED IT FOR SIX DISPATCHES.** P3.64 costed
it at **3,981 B for twelve cels** and it has been deferred ever since, each dispatch citing
that figure. **The number was right about the wrong scope.** `PlayCut0` calls `addglass1`
with X=0 and then X=1 [SUBS.S:722,745], so this scene reaches **two glass states plus the
three sand frames — five cels.** Converted and measured:

```
glass0 415   glass1 416   flow0 49   flow1 57   flow2 57      = 994 B      (all replay OK)
```

Position and opacity read from the oracle rather than assumed: `glassx = 19, glassy = 151`
[GAMEBG.S:120], `flowx = glassx+1, flowy = glassy-2`, and **`OPACITY = sta`** — the
hourglass is an **opaque** blit at a fixed byte column, no mask, exactly the torches' shape.
Apple byte 19 → CoCo px 153 → col 38 phase 1; the flow at byte 20 → px 160 → col 40 phase 0.
**One phase each**, as P3.64 said.

**3B — ★ AND IT INVERTED THIS DISPATCH'S ORDER, which §1 invited by saying "land it first
and let §2 see the real numbers".** The numbers say otherwise:

```
today's encoding, with hourglass     DOES NOT PACK
with the re-encode, with hourglass   pinned 2,850/6,828 (3,978 spare) | 4 pages | 1 read | 2 LOADS
```

The pinned page has **886 B spare** and the hourglass needs **994**. It has to be pinned —
it appears after `Pback` and is drawn every frame to the end, spanning beats that map two
different rotating blocks, and a cel straddling a mapping change is the one thing the packer
refuses. **So the re-encode had to go first.** Reported rather than worked around.

**3C — The re-encode, and why the format is what it is.** One header byte: opcode in the top
two bits, count in the low six, `$00` = end of row. P3.79 measured 64.9% of the cel image as
punctuation against 23.1% pixels, with **6,330 of 11,111 segments one byte long**. The
longest run anywhere is 10, so four bits would do and six is ample; the generator **refuses**
a run that will not fit, so the bound is checked at bake time rather than trusted in the
blitter. It is also marginally faster — one fetch and two masks instead of two fetches.

**3D — ★★ THE FAILURE, AND WHAT IS RULED OUT BY DIRECT CHECK.** The walk suite resets the
machine during `Pback` (beat 12), looping in `blit_erase`'s row loop **with a normal stack**
(`S=$7EF3`), so it is being handed a bad row count rather than corrupting itself. State was
sane 60 frames earlier (`ch_cel=$E9DC ch_h=48 ch_w=6 ch_col=45`, viz cel 67, pri cel 16).

Ruled out, each by measurement:

| | |
|---|---|
| the streams | `verify_cel_streams.py` walks all **82** cels the way `bc_seg` does; every one consumes **exactly** the bytes it occupies |
| the pack | every beat's set is inside resident ∪ its mapped page, checked against `cel_pack.json` |
| the lookup table | all **64** live entries point into the right region — pinned at `$C000-$DFFF`, paged at `$E000+` |
| the decode model | the generator's replay was rewritten to **parse** the packed header and still reconstructs every cel over a hostile background |

**A stream ending one byte early is the failure a format change produces, and it is not
this.** That check is new and now gates the build, so the class cannot recur silently.

### 4 — Verification

**25.1 (at `ca3939d`):** `=== BUILD COMPLETE ===` with `[hal-sync] OK`, `[sequences] … 9
sequences`, `[harness-offsets] all checked offsets agree`, `ok cel_plan 19 rows x 5 B`,
`ok cel_page_tab 4 rows x 2 B`, `[cel-streams] 82 cels walk exactly to their own end`.
Room: `checks=8 passed=8 failed=0`, `PASS room intact`, `PASS flames flicker`,
`PASS flame pixels … 78 bytes byte-identical`. Walk: resets (§3D).

**25.2:** N/A. **25.3: not offered** — the scene does not complete.

### 5 — Acceptance criteria

1. **Hourglass built** — **NO.** Measured (§3A) and blocked by the order inversion (§3B);
   the flash, the sand wiring, the `SPEED` 7→12→7 change and `s_Magic`'s trace are **not**
   done. **Not dropped** — HARD-STOP #2 is about it not fitting *after* the re-encode, and
   after the re-encode it fits with 3,978 B to spare.
2. **Bank occupancy reported** — **yes** (§3A/3B).
3. **Re-encode landed with achieved figures** — **numbers yes, scene no** (§1, §3D).
4. **Grouping pushed for one load** — **NO, not reached.** It is 4 pages against 3 blocks,
   still one page short, and there is now **3,978 B of pinned slack** to spend on it.
5. **Suites green both sizes** — **NO.** Room green; walk failing; 128 KB not run.
6. **Jay gates live** — **not offered.**
7. **Route accounting; sync bridge; Karateka and `main` untouched** — yes.

### 6 — Reactive deviations and route accounting

**The dispatch ordered §1 (hourglass) → §2 (re-encode) → §3 (verify) → §4 (gate). This
reversed §1 and §2**, on the packer's evidence (§3B), and then §2 failed at runtime.

Not present: the hourglass build, the flash, the sand, `s_Magic`'s trace, the `SPEED`
change, the grouping push, the gate, the turn-to-exit disappearance, the 16-colour swap,
the `Prolog2` handoff. **The swap was not unwound; draw-time mirroring not revisited.**

### 7 — Uncertainty flags

- **★ The beat-12 reset is UNATTRIBUTED.** Four static checks pass. The next split is a
  runtime one: log `blit_erase`'s A and B at entry for every call in `Pback` and find the
  bad row count's source — `co_erase` reads its dimensions from `ch_last`, so that record is
  the first place to look, and it is **not** part of the re-encode.
- **★ Whether the failure is even the re-encode is not established.** The re-pack changed
  every page's contents at the same time; those are two changes in one commit and they have
  not been separated. **That separation is the first thing to do, not the last** — it is the
  same mistake shape as P3.80's wrong bound.
- The hourglass's 994 B is measured for **states 0 and 1 only**; the full game needs twelve.
- ROOM.BIN headroom unchanged at 6 bytes.
- Carried: the turn-to-exit disappearance; 0.20 s per-call overhead; `$2310..$2329` read-tap
  blindness; `PlayCut0`'s remaining sound sites.

### 8 — Follow-up candidates

1. **Separate the two changes** — re-bake with the OLD encoder against the NEW pack, or the
   reverse. One build each, and it says whether the reset is the format or the packing.
2. Then attribute the reset **by split**, not by exhaustion.
3. Then the hourglass (994 B, fits with 3,978 B spare), the flash, the sand, `s_Magic`.
4. Then the grouping push for a single load — **zero staged reads means zero freeze**, and
   there is now real slack to spend on it.

### 9 — User interaction during task

None during execution.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-13-a-deferral-outlives-its-reason.md` — pushed (`4e54b7f`). The
hourglass was blocked for six dispatches by a figure that was correct for the whole game's
twelve states and never for this scene's five. A deferral gets cheaper to repeat each time
it is repeated, and nothing about a deferred item changes to trigger a re-check.

### 11 — Commit

`ca3939d` — pushed to origin/wip before this report. Last fully green commit: `22c9e31`.
