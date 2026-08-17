## Form B Report — P3.81 — the two flame bytes refuse attribution, and my P3.80 bounding was wrong

**Class:** recon (four experiments, no net source change). wip. Prod untouched.
**★ HARD-STOP #3 FIRED: the two flame bytes cannot be attributed. Reported with the splits
tried and the next one, NOT closed as bounded.** §2 (the two missing beats), §3 (the harness
sweep) and §4 (the re-encode) are **not reached.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-12T21:41:34-04:00 (HEAD `84a27e0`, wip). **Still at `84a27e0` — no source change
survives this dispatch;** every edit was a probe and every probe was removed.
POP `main` untouched at `635f986`. Karateka untouched (`wip` `ac2b768`, `main` `5eb92b1`).
Build green. Room suite: 8/8 in-emulator, room intact, flames flicker, **2 of 78 flame bytes
wrong**. Walk suite unchanged from P3.80.

---

### 1 — Summary

**★★ I REPORTED THE TWO BYTES AS "BOUNDED TO MY `blit_save`/`blit_erase` REWRITE". THAT IS
WRONG, AND THIS DISPATCH DISPROVED IT.** Both routines have now been reverted to their
pre-clip bodies, independently and then together, and **the two bytes persist unchanged.**

P3.80 was right to call them *bounded, not attributed* — and the bound itself was wrong.
The distinction saved nothing here: a wrong bound sent this dispatch at the wrong file.

**Four experiments, each ruling something out:**

| split | result |
|---|---|
| peel forced full-width, draw clipped (P3.80) | 296 bytes identical → **peel not the 296** |
| `bc_trim` fast path for `bc_keep = $FF` | two bytes persist → **not the trim** |
| **`blit_erase` reverted to pre-clip body** | two bytes persist → **not the erase** |
| **`blit_save` reverted as well — both original** | two bytes persist → **not the save** |
| flame content pipeline diffed `0f2e92e..HEAD` | **identical** → not the baked flame data |

**And it is still mine:** building the pre-clip engine gives *"flame pixels are exactly cel
3/8 over the room: 78 bytes byte-identical."*

### 2 — Files modified

**None.** `src/engine/blit_core.s` was probed four times and restored to `84a27e0` each
time; `git status` is clean on `src/`. The only lasting artefacts are the measurements below.

### 3 — Reasoning

**3A — The splits, and why each was the right next one.** The dispatch named the method:
*"a mechanical split that changes one thing."*

- **`blit_erase` first**, because the rewrite changed its pointer discipline most — U went
  from peel-source to framebuffer-destination and the peel row moved into `bc_peelrow`.
  Reverted to the original `tfr y,u` form with the `FB_STRIDE − width` advance: **two bytes
  unchanged.**
- **`blit_save` as well**, leaving `blit_core` entirely pre-clip except the window setup at
  `blit_cel`'s head (which the fast path makes dead for the torches): **two bytes unchanged.**

**3B — What that leaves, stated precisely.** With the peel pair original, the trim bypassed
and the flame data byte-identical, the only differences the torches can still see are:

1. `blit_cel`'s **merge/blast restructuring** — `bsr bc_trim` plus the `bc_pre`/`bc_run`
   handling. The fast path makes it *arithmetically* equivalent, but it is not the *same
   instructions*, and `bc_blast` in particular now reaches `blit_blast` through a different
   register path (`lda bc_run` where the original held the count in A from `lda ,u+`).
2. **`flame_cels.s`'s `blit_tab`**, repointed to the `_full` doors.
3. **`char_draw.s`** — everything the clip added there.

**★ (2) is the one I would split next**, and it is cheap: the `_full` wrappers are supposed
to be transparent, and `blit_cel_full` **clobbers A** (`lda #$FF`) on the way in. `blit_cel`
does not take A as an argument, so that *should* be harmless — but "should be harmless" is
what I said about the peel rewrite two dispatches running.

**3C — And the shape of the corruption argues against every candidate I have.** The two bytes
are a **one-pixel shift**, not garbage:

```
torch 1 row 106 col 50: got $C4 [white, black, orange, black]  want $C1 [white, black, black, orange]
torch 1 row 107 col 50: got $82 [BLUE,  black, black,  BLUE ]  want $D5 [white, orange, orange, orange]
```

The orange has moved one pixel LEFT in the first, and the second is showing background where
flame should be. A one-pixel displacement in a 4 px/byte mode is a **sub-byte phase**
difference — and the torches' phases are baked (`--phase 3` and `--phase 1`), unchanged, at
addresses the room computes and I did not touch. **I cannot reconcile that with any of the
three candidates above, and I am recording the discrepancy rather than picking the least
uncomfortable story.**

**3D — Where the characters were, checked so it could be excluded.** At capture the vizier is
at cols 74–79 and the princess at 36–41 — **neither near col 50** — so a character over-draw
is ruled out. His span does cross `VIS_R`, so `co_clip` blanks cols 75–79; the pre-clip
`co_clip` blanked the same five columns, so that is not new either.

### 4 — Verification

**25.1 fresh tool output (at `84a27e0`, tree restored):**
- `build.bat` → `=== BUILD COMPLETE ===`
- `run_room_test.sh` → `checks=8 passed=8 failed=0`; `PASS room intact outside the torch
  boxes`; `PASS flames flicker`; `FAIL flame pixels wrong: 2 of 78`
- Control at `0f2e92e` → `PASS flame pixels are exactly cel 3/8 over the room: 78 bytes
  byte-identical`
- `git diff --stat 0f2e92e..HEAD -- harness/tools/cel_blit_prep.py content/cutscene/flames`
  → **empty**

**25.2:** N/A. **25.3: not offered.**

### 5 — Acceptance criteria

1. **The two flame bytes attributed** — **NO. HARD-STOP #3.** Splits tried and the next one
   named (§3A/3B). **The prior bound is retracted.**
2. **Two missing beats found; `beats_visited` 18 of 18** — **NO, not reached.**
3. **Harness offsets swept** — **NO, not reached.**
4. **Both suites green both sizes** — **NO.**
5–8. **Re-encode, grouping, symbol verification, gate** — **NO.** §7 HARD-STOP #2 is explicit:
   green is not reached, so the re-encode does not start. It did not.
9. **Route accounting; sync bridge; Karateka and `main` untouched** — yes.

### 6 — Reactive deviations and route accounting

**The dispatch ordered §1 → §2 → §3 → §4. This contains §1's investigation and nothing
else, and §1 did not succeed.**

No deviation from the order. The failure is of *yield*, not of sequencing: four experiments
bought four exclusions and no attribution.

**★ AND I DAMAGED `blit_core.s` A THIRD TIME BY INDEX-BASED SPLICING** while setting up the
first probe — appending the whole original file and multiply-defining every `equ`. Restored
from git and redone with exact-match edits. **That technique is now banned for me on this
file**; it has cost time in three consecutive dispatches and produced one false diagnosis
(P3.80 §3E's phantom bodyless label).

Not present: the re-encode, the grouping look, the beats, the sweep, the turn, the hourglass,
the flash, any gate. Swap not unwound; `shift_row.s` not reopened; draw-time mirroring still
ruled out on schedule grounds.

### 7 — Uncertainty flags

- **★ The two bytes are unattributed and my prior bound was wrong.** Anything built on the
  clip should treat the blitter as not-yet-proven.
- **★ The one-pixel-shift shape does not fit the remaining candidates** (§3C). That mismatch
  is the most useful thing here and I have not explained it.
- `beats_visited` 16 of 18 — untouched this dispatch, still unexplained.
- The harness sweep (§3 of the dispatch) is **not done**, so there may be another stale
  checker; the fourth would then again be found by accident, which is exactly what that
  section exists to prevent.
- Carried: the turn-to-exit disappearance; hourglass and flash unbuilt; ROOM.BIN 7 bytes of
  headroom; 0.20 s per-call overhead; `$2310..$2329` read-tap blindness.

### 8 — Follow-up candidates

1. **Split (2): point `blit_tab` back at the plain entries** and set the window from the room
   instead, so the `_full` wrappers are out of the path. Cheapest remaining exclusion.
2. **Then split (1): remove `bsr bc_trim` and the `pre`/`run` handling** from `blit_cel`, so
   `blit_core` is instruction-identical to `0f2e92e` bar the dead window setup. If the two
   bytes survive **that**, the cause is in `char_draw.s` and the next split is `co_clip`.
3. **★ Consider inverting the search**: dump the torch-1 framebuffer bytes at a fixed frame
   under both builds and diff the *draw addresses* rather than the results — a one-pixel
   shift is a placement fact, and placement is computed outside `blit_core`.
4. §2's beats, §3's sweep, then §4's re-encode — all unchanged in value.

### 9 — User interaction during task

None.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-12-a-failing-tree-is-not-a-baseline.md` — pushed. Leaving a failing
build in the tree preserves evidence and is right; sequencing measured work on top of it
measures against nothing, and the prelude becomes the dispatch. Two dispatches in a row have
now been spent on a prelude to the same unstarted re-encode.

### 11 — Commit

**No source commit.** The tree is at `84a27e0` with `src/` clean; this report follows.
