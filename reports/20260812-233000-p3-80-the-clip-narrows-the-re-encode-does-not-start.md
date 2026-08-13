## Form B Report — P3.80 — the clip narrows to two bytes; the re-encode does not start

**Class:** build (partial). wip. Prod untouched.
**★ THE DISPATCH'S PRIMARY DELIVERABLE — §1, the segment-header re-encode — IS NOT BUILT.**
The dispatch is spent on §3's clip, and the reason is stated in §6 rather than implied.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-12T20:30:13-04:00 (HEAD `3ceaa49`, wip). Now at `81bffc1`, pushed.
POP `main` untouched at `635f986`. **Karateka untouched** — `wip` `ac2b768`, `main` `5eb92b1`.
Build green. **Room suite: 8/8 in-emulator, room intact, flames flicker, 2 of 78 flame
bytes wrong. Walk suite: guard/signatures/reads/pixels all clean and STABLE, `beats_visited`
16 of 18.** Neither suite fully green; both far better than P3.78d.

---

### 1 — Summary

**The re-encode needs a green baseline to be measured against, and the tree did not have
one** — `co_clip` was committed failing at P3.78d. Diagnosing it was supposed to be a
prelude and became the dispatch.

**Two real bugs found, both mine, neither in the clip's arithmetic:**

| | |
|---|---|
| `leax a,x` takes A as a **signed** byte | `bc_keep = $FF` meant −1, so the window collapsed and **the torches stopped drawing** |
| `room_test.lua` still read `ch_last` at the **pre-16-bit offsets** | recorded character boxes at columns **−31..−19**; the princess's own pixels counted as "room disturbed" — **the 296 bytes were never the clip** |

**What remains: 2 of 78 flame bytes**, bounded by experiment to my `blit_save`/`blit_erase`
rewrite, **not attributed**. And `beats_visited` 16 of 18 — the scene still does not finish.

### 2 — Files modified

- **`b044a22`** — `src/engine/blit_core.s` (the signed-offset fix),
  `harness/smoke/room_test.lua` (re-pointed at the 9-byte `ch_last` entry).
- **`81bffc1`** — `src/engine/blit_core.s` (the unclipped fast path).
- **`c3c947c`** (P3.79, carried in this branch) — the three measuring tools.

### 3 — Reasoning

**3A — The bisect P3.78d planned and never ran, and it was worth one build.** Force the
peel primitives full-width, leave the draw clipped: **it failed identically** — 296 bytes,
same byte. That acquitted the peel rewrite of the 296 outright and sent me to look at the
right thing.

**3B — ★ THE SIGNED OFFSET.** `blit_cel_full` passes `bc_keep = $FF` to mean *"wider than
any cel"*, and `leax a,x` treats A as **signed** — so `clip_hi` landed one byte *below*
`clip_lo`, every segment trimmed to nothing, and the torches drew nothing at all. The suite
called it *"flames did not move between the captures — a still picture"*, which is exactly
what a window of negative width looks like from outside. Computed 16-bit now.

**3C — ★★ AND THE 296 BYTES WERE A STALE CHECKER, NOT A RENDERING FAULT.** The strays were
at **cols 35–40, rows 109–151** — the princess's own footprint — and her *recorded* box read
**columns −31..−19**. `room_test.lua` still read `ch_last` with the pre-P3.78b offsets:
`CH_X` became 16-bit, the entry grew 8 bytes to 9, `walk_test.lua` and `peel_census.lua`
were re-pointed and **this one was not**.

A nonsense box excludes nothing, so her pixels counted as *"room disturbed outside the
torches"* — 148 per capture, 296 across two — **and it pointed squarely at the clip that had
just landed.** This dispatch's own §4 warned about it: *"a format change is exactly what
strands a checker on the old tree (P3.65)."* I re-pointed three readers and missed the
fourth, and the failure it produced accused the wrong code for two dispatches.

**3D — The two flame bytes: bounded by experiment, NOT attributed.** Torch 1, rows 106–107,
col 50 — the right edge of the right torch, showing background where flame should be.

- **It is mine, not pre-existing.** Checking out the pre-clip engine (`0f2e92e`) and
  rebuilding gives *"flame pixels are exactly cel 3/8 over the room: 78 bytes
  byte-identical."*
- **It is not `blit_cel`'s trim.** A fast path that takes the whole segment when
  `bc_keep = $FF` — so the torches skip the trim arithmetic entirely — leaves the two bytes
  exactly as they were.
- **So the suspect is my `blit_save`/`blit_erase` restructuring**, which the flames reach
  through the `_full` doors. The concrete recommendation is in §8.

**3E — ★ AND I NEARLY COMMITTED A FALSE DIAGNOSIS FOR IT.**
`sed -n '/^blit_save/,/^blit_erase/p'` prints from `blit_save_FULL` to `blit_erase_FULL` —
which made `blit_erase_full` look like a label with **no body**, sitting directly on top of
`blit_save`. That is a perfect, plausible explanation for a small edge artifact: every torch
erase running the save instead, the flame never cleared, the next ORed on top.

**It has a body. The range was mine.** The Edit tool's exact-match refusing to find the text
is the only thing that caught it. **A misread range produces a misdiagnosis that reads
exactly like a finding** — and this is the fourth time in three dispatches that a tool
between me and the machine has been the thing that was wrong.

### 4 — Verification

**25.1 fresh tool output (at `81bffc1`):**
- `build.bat` → `[sequences] port streams agree ... 9 sequences`; `ok cel_plan 19 rows x 5 B`;
  `ok cel_page_tab 5 rows x 2 B`; `=== BUILD COMPLETE ===`
- `run_room_test.sh` → `checks=8 passed=8 failed=0`; **`PASS room intact outside the torch
  boxes`**; **`PASS flames flicker: 14 bytes changed, all inside the torch boxes`**;
  `FAIL flame pixels wrong: 2 of 78`
- `run_walk_test.sh` → `bank_mapped_at_every_capture PASS`; `engine_bank_guard PASS`;
  `page_sig_matched_every_frame PASS (1,148 checked, 0 mismatches)`; `staged_reads PASS
  (2 of 2 pages, cel_rd_err = 0)`; pixel check clean; `STABLE`; `beats_visited FAIL (16/18)`
- **Control run** at `0f2e92e`: `flame pixels ... 78 bytes byte-identical` — the evidence in
  §3D that the two bytes are mine.

**Not run:** 128 KB, the intro suite, `hal_sync_check` since `0f2e92e` (no HAL file touched).
**The re-encode's numbers are not measured because it is not built.**

**25.2:** N/A. **25.3: not offered** — the scene does not finish and two flame bytes are
wrong. Offering it would spend Jay's time on a known-incomplete build.

### 5 — Acceptance criteria

1. **Segment header packed** — **NO. Not started.**
2. **Achieved size / pages / loads measured** — **NO.** P3.79's predictions (28,101 B,
   4 pages, 2 loads) stand as predictions and are explicitly not quoted as achieved.
3. **Grouping looked at once** — **NO.**
4. **`co_clip` diagnosed on the machine** — **YES, and largely fixed** (§3B/3C). Two bytes
   remain, bounded but unattributed (§3D). **Diagnosed on the machine throughout: three
   experiments, no claim from reading.**
5. **The turn-to-exit disappearance diagnosed** — **NO.**
6. **Hourglass + flash** — **NO.**
7. **Suites green both sizes** — **NO** (§4). Checkers re-pointed: **one of them by this
   dispatch, having been missed by the last** (§3C).
8. **Jay gates live** — **not offered.**
9. **Route accounting; sync bridge; Karateka and `main` untouched** — yes.

### 6 — Reactive deviations and route accounting

**The dispatch ordered §1 (re-encode) → §2 (grouping) → §3 (clip, turn, hourglass). This
contains §3's clip work only, and nothing else.**

**The deviation is real and I am not dressing it as a judgement call.** My stated reason for
taking the clip first was that the re-encode has to be measured against a green baseline and
the tree did not have one. That reason is sound. **What I did not predict is that it would
consume the entire dispatch**, and at the point where the 296 bytes turned out to be a stale
checker rather than a rendering fault — a fifteen-minute fix — I should have stopped
diagnosing and started the re-encode. Instead I chased the last two bytes through two more
builds and a false diagnosis.

**HARD-STOP #3 was not reached** — the per-row clip is *nearly* working, not unworkable, so
the cheaper skip is not being offered.

Not present: the re-encode, the grouping look, the turn diagnosis, the hourglass, the flash,
`s_Magic`, the 16-colour swap, the `Prolog2` handoff, any gate. **The swap was not unwound;
`shift_row.s` not reopened; draw-time mirroring not revisited** (ruled out on schedule
grounds at P3.79 and left ruled out).

### 7 — Uncertainty flags

- **★ Two flame bytes, bounded to `blit_save`/`blit_erase`, NOT attributed** (§3D).
- **★ `beats_visited` 16 of 18 — the scene still does not finish**, and with the clip now
  largely working I do **not** know why. No corruption is reported and the pixel check is
  clean, so this may be the harness's run window rather than a fault; **that is a guess and
  is flagged as one.**
- **The re-encode's predicted numbers are P3.79's model**, unbuilt and unmeasured.
- 128 KB and the intro suite not re-run.
- Carried: the turn-to-exit disappearance; the hourglass and flash unbuilt; ROOM.BIN has
  7 bytes of headroom; 0.20 s per-call driver overhead; the `$2310..$2329` read-tap blindness.

### 8 — Follow-up candidates

1. **The two flame bytes.** Concrete route, and it is a *smaller delta from known-good code*
   than what is there now: restore `blit_save`/`blit_erase` to the original's
   **continuous-Y** structure and add the clip as a minimal addition — step `U`/`Y` over
   `bc_lead` at row start, copy `bc_keep`, then step both over the tail so `Y` lands on the
   next peel row exactly as it used to. My rewrite replaced a working loop shape when it only
   needed two `leay`s.
2. **Then §1, the re-encode** — unchanged in value by anything here.
3. `beats_visited`; the turn; the hourglass and flash.

### 9 — User interaction during task

None during execution. The dispatch itself carries Jay's authorisation for the re-encode,
which this report does not deliver.

### 10 — Candidate(s) captured this task

None new. §3C is a third instance of the stranded-checker shape (P3.65, P3.78b-d's
`disk_reads_ok`, this) and §3E is a second instance of
`both-sides-of-a-check-from-one-derivation` seen from the tooling side — a *tool* between me
and the machine being the thing that was wrong. Both are better folded into the existing rows
at reconcile time than filed as near-duplicates, on the P3.76 §9 precedent.

### 11 — Commits

`b044a22`, `81bffc1` — pushed to origin/wip before this report. (P3.79's `c3c947c`,
`066787f` precede them on the same branch.)
