## Form B Report — P3.93 — five strobes, the sand flows, and the margin came back as predicted

**Class:** build. wip. Prod untouched.

**★★ THE GLASS AND ITS FLASH NOW ARRIVE ON THE SAME FRAME — they were 0.53 s apart, which is what
Jay reported. Five strobes where there was one; the sand advances once per play and no longer
freezes for the scene's last 27. ★ P3.92's margin came back within a few hundred cycles of the
prediction, exactly as stated at the time.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-15T16:26:42-04:00 (HEAD `9843810`, wip). Karateka untouched. `main` untouched. Oracle
source read-only (not read this dispatch — the trace it would settle does not exist; see 3C).
Pre-existing, not mine: `dist/mame-cfg/rgb/coco3.cfg`.

---

### 1 — Summary

| | |
|---|---|
| **§1** | `vb_tick`'s scenery block **moved above two branches that were never about it**. No new code |
| **rate** | **verified on the machine**: 5 strobes at steps 302-306; sand 16/16, 17/17, 12/12, 28/28 |
| **★** | glass at **f4186**, first strobe at **f4186** — was f4186 vs f4218 |
| **§1** | the **terminal beat now flows** — a decision, stated (3C) |
| **margins** | 4,246 / 1,365 / 6,988 cy — **back to P3.90, as predicted** |
| **★ cost** | beat 17 is **~311 cy worse than P3.90** — the sand cache's test with its benefit gone |
| **coverage** | the captures now composite **flow0, flow1 AND flow2**, all 0 bytes wrong |
| **25.3** | **PENDING JAY** — observed 179 s (the whole scene + ~100 s of the hold), no words |

### 2 — Files modified

- `src/engine/char_draw.s` — `vb_tick`: the scenery block hoisted above the beat bookkeeping
- `harness/smoke/run_room_live.sh` — banner: the strobe, the flow, and the restore's blast radius

### 3 — Reasoning

**★ §2H's THREE CHECKS** (third dispatch prompted by the restored §7 pointer):

1. **A second mechanism for a different object class?** **`vb_tick` itself was the instance** — two
   jobs on two clocks in one routine, and the fix is to stop them sharing a guard. The carried one
   is noted and **left**: `vm_frameadv`'s draw pass runs every iteration while a cel changes every
   second one. **Blocked by a stated reason** — P3.87 established the draw is unconditional because
   `flicker` repaints the torches underneath. It becomes live only if the torch repaint changes.
2. **The calling routine.** `vb_tick` ← `vm_beat_tick` ← `vm_nextframe` ← `chars_frame`, **once per
   step**. So the caller already establishes the play rate; the branch inside was overriding it.
   That is why the fix is a move and not new logic.
3. **Grep the reports for the subsystem.** P3.85's note asserts the sand steps *"once per play …
   which is the play rate in both cases"*; P3.91 traced that it did not. No further stale
   characterisation found — the P3.87 ones were corrected at P3.90/P3.91.

**3A — THE FIX IS A MOVE.** `vb_tick` does two jobs on two clocks. The **scenery events** belong to
the play — by their own comments and by the oracle — and **spending the beat** belongs to the beat.
They shared one control path, so the bookkeeping's guard (`bne`, taken on every play but the last)
silently became the scenery's guard too. The block moved above it. Nothing was rewritten.

**3B — ★★ VERIFIED AS A RATE, NOT READ FROM THE BRANCH** (§5.2, and §6.3 would have fired
otherwise). `port_vbtick_trace.lua`, write taps on `cad_idx` / `vm_beat` / `sc_lit` / `sc_flow`:

```
beat 15 begins at step 302, frame 4186      the glass appears
    lit =3 at step 302, frame 4186          ...and the first strobe with it
    lit =3 at step 303, frame 4196
    lit =3 at step 304, frame 4204
    lit =3 at step 305, frame 4210
    lit =3 at step 306, frame 4218
```

**Five arms, one per play of a five-play beat**, and the first on the beat's own first frame. Sand,
per beat: **16/16, 17/17, 12/12, 28/28 steps** — once per play throughout, and 28 in the terminal
beat's 27 steps.

*(`sc_lit` is armed and counted down through one byte, so a naive tap reads three events per strobe.
Flagged at P3.91 §7 and applied here: the arming value is `3`, and there are five of them.)*

**3C — ★ THE TERMINAL BEAT: A DECISION, NOT A SIDE EFFECT.** It is reached by the `beq` the block
now sits above, so before this the sand froze for the scene's last 27 plays while `cel_plan` marked
that very beat `SC_FLOW`. P3.91 flagged that a fix must **decide** this rather than assume it.

**There is no oracle fact to trace, and that is the finding rather than a gap.** The terminal beat
is a **port artifact** — a row with `plays = 0` that holds forever because the `Prolog2` handoff is
not built [`bake_scene.PLAN`: `("v", "Vstand", 0)`; `cel_plan.s`: *"holds forever … not the end of
the scene"*]. `PlayCut0` has no counterpart: the oracle's cutscene ends and control passes on. So
"what does the oracle do here" has no answer, and waiting for one would be waiting forever.

Under **§2I** the mandate is the picture. An hourglass whose sand stops while the scene sits parked
on it is the wrong picture. **It flows.**

**3D — MARGINS, ENTRY AND EXIT SEPARATELY, AND THE PREDICTION HELD.** 4-frame boundary = 119,436 cy.

| scene beat | P3.90 | P3.92 | **now** | f/play now |
|---|---|---|---|---|
| 16 | 4,320 | 8,933 | **4,246** | 8.25 |
| 17 | **1,676** | 6,288 | **1,365** | 8.68 |
| 18 | 7,033 | 12,031 | **6,988** | 8.00 |

**Entry: 108,890 → 108,903 → 108,914 cy — unchanged throughout**, as it must be; the glass is not up
during the entry. Scene mean 6.77 → 6.75 → **6.78 f/play**.

**This is the expected cost and it is not a regression.** A correctly flowing sand cannot be
skipped: it changes once per step, each buffer is drawn once per step, so every buffer's record is
stale at every visit and P3.92's skip never fires during a `SC_FLOW` beat. P3.92 predicted beat 17
would return to *"roughly its 1,676 cy"*; it returned to 1,365.

**★ AND THE 311 cy IT DID NOT PREDICT IS WORTH NAMING.** Beat 17 is now *worse* than P3.90, not
equal to it, because P3.92's sand test still runs every frame and now always answers "redraw" — the
cache's cost with its benefit gone. **Kept**, per §1: it is keyed on the **value** so it stays
correct at either rate, and its **body** half still fires everywhere (the body changes twice in the
whole scene). But the sand half is currently net-negative and should be recorded as such rather
than left inside a favourable-looking total.

**3E — COVERAGE TRACKS THE CORRECTED RATE, which is a stronger claim than "the suite passed".** A
suite green on a static sand is not evidence about a flowing one. The 16 hourglass and exit captures
now composite **`flow0`, `flow1` and `flow2`** across them — where each window previously saw a
single frame — and every one is 0 bytes wrong. The per-buffer sand record added at P3.90 is what
makes that work: the checker composites the frame the **displayed** buffer holds, not the engine's
current one.

### 4 — Verification (AC-by-AC)

- **AC1 branch fixed, once per play** — **MET** (3A).
- **AC2 verified as a RATE on the machine** — **MET** (3B).
- **AC3 margins re-reported, entry and exit separately, loss stated not treated as regression** —
  **MET** (3D), including the 311 cy the prediction missed.
- **AC4 the cache retained** — **MET**, with its current net cost stated.
- **AC5 coverage tracks the corrected rate; suites green both sizes; build by symbol** — **MET**
  (3E). `sc_sdrw = 4060`, `sc_sneed = 4062` from the freshly baked image.
- **AC6 §2H's checks in §3; character-draw noted and left** — **MET** (head of §3).
- **AC7 Jay gates live** — **OFFERED AND OBSERVED; NOT AFFIRMED.** See §5.
- **AC8 route accounting; sync; Karateka; `main`** — **MET.**

### 5 — Verdict-time evidence (v0.7 §11)

**25.1** `=== BUILD COMPLETE ===`; `[hal-sync] OK`; `[harness-offsets] all checked offsets agree`.
Room, both sizes: `checks=8 passed=8 failed=0`, `78 bytes byte-identical`.
Walk, both sizes: **44 captures, `0 bytes WRONG` at every one**, `beats_visited PASS (19 of 19)`,
`stability: all captures agree (0)`, `STABLE`.

**25.2** N/A — ROM build.

**25.3 PENDING JAY. Offered and observed; no words received, so nothing is recorded as passed.**
Launch path `live-disk`, RGB, `run_room_live.sh`. The run lasted **179 emulated seconds at 100%
speed** — the scene's terminal beat begins at ~f4781 ≈ 80 s, so this covered the whole scene and
roughly 100 s of the hold, which is where the newly-flowing sand is most visible. **That the window
was open long enough is not the same as an observation**, and a closed window is not a gate result.

Three things were surfaced for his eye: **five strobes rather than one, the first arriving with the
glass**; **the sand flowing, including through the parked hold**; and **the blue returning after
every one of the five** — the P3.85c restore has only ever been exercised against a single strobe,
so its blast radius is untested.

Standing: the flash, the glass and the sand **PASSED** (2026-08-15, against the *old* single-strobe
behaviour — that affirmation does not carry to the new one); **the slump is observed-unknown**; the
turn disappearance and the exit pace remain **open**.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** The change is the dispatch's and is implemented as specified: the branch fixed
by moving the block, the cache retained, margins re-reported. **Two things I added:**

- **The terminal-beat decision** (3C). The dispatch did not mention it; P3.91 flagged it as
  requiring a decision, and the move forces one. Decided on §2I grounds with the reasoning stated,
  because there is no oracle counterpart to defer to.
- **The 311 cy net cost of the sand cache** (3D). Not asked for, and it is the one number in this
  report that makes the result look slightly worse than the prediction.

★ **An earlier attempt failed to build** — the `vb_tick` label was left behind when the block moved.
Caught by the assembler, fixed, rebuilt. Recorded because "it built" is load-bearing evidence here.

Not present: the characters' per-iteration draw (blocked, §3 check 1); the turn disappearance; the
peel; the grouping push.

`hal-sync` OK. Karateka untouched. `main` untouched.

### 7 — Uncertainty flags

- **★★ The palette restore has never been exercised against five strobes.** P3.85c fixed `sc_pal`
  where it disagreed with `gfx_pal4`, and `palette_check.py` guards the values — but the *sequence*
  arm→restore→arm→restore, five times inside one beat, is new. If the restore is wrong in a way the
  value check cannot see, this is where it shows. **Surfaced at the gate.**
- **The affirmation of 2026-08-15 was against the single-strobe behaviour** and does not carry
  forward to this change.
- **The slump remains observed-unknown** and needs one answer from Jay.
- **Beat 17's peak is 131,347 cy**, above the 4-frame boundary; 9 of its 28 steps land on 10.
- **`SC_LIT_FRAMES` is still a derived number**, not traced from the oracle's own on/off ratio
  inside a play — unchanged since P3.85c and now multiplied by five.
- Carried: the characters' per-iteration draw; the turn-to-exit disappearance; 0.20 s driver
  overhead; `$2310..$2329` blindness; sound sites stubbed as holds.

### 8 — Follow-up candidates

1. **The turn-to-exit disappearance** — `ch_h`/`ch_w` and the page signature across `$0E → $0F`.
   Now the largest open defect Jay has reported.
2. **Trace the oracle's flash duty cycle** inside a play, so `SC_LIT_FRAMES` stops being derived.
3. The characters' per-iteration draw, if the torch repaint is ever revisited.

### 9 — User interaction during task

Jay ran the live gate (179 s). **No words received during the task**; nothing recorded as passed.

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-15-a-guard-for-one-job-becomes-a-guard-for-both.md`

### 11 — Commit

`845a7c1` (the fix), the banner, and this report. Pushed to origin/wip.
