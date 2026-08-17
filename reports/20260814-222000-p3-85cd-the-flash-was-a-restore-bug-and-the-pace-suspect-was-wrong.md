## Form B Report — P3.85c/d — the flash was a restore bug, and my pace suspect was wrong

**Class:** build. wip. Prod untouched.
**★ Two diagnoses I gave confidently were wrong, and in both cases the measurement — not the
argument — is what settled it. One correction is shipped; the other is a negative result.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-14T21:05:00-04:00 (start of this arc, HEAD `19771df`). Now at `009fb71`, pushed.
POP `main` untouched. Karateka untouched. `hal-sync` OK. Follows the P3.85b report
(`b6db158`), which covered the hourglass and `s_Magic`.

---

### 1 — Summary

| | |
|---|---|
| **P3.85c** | the flash's **restore** carried the wrong blue — shipped, gated by a new check |
| **P3.85d** | the clip trim is **NOT** what costs the pace — measured, 0.16 f/play |
| suites | room 8/8, 78 bytes byte-identical; walk 19/19, 0 bytes wrong, stable |
| **25.3** | **NOT PASSED.** Jay gated live four times; two defects reported, one fixed |

### 2 — Files modified

- `src/engine/char_draw.s` — `sc_pal` $1B→$19; the strobe held 3 drawn frames, not 1
- `harness/tools/palette_check.py` — NEW, wired into `build.bat`, demonstrated to fire
- `harness/tools/port_flash_trace.lua`, `port_beat_times.lua`, `port_step_rate.lua` — NEW
- `src/engine/blit_core.s` — `bc_noclip`, hoisted out of `bc_trim`
- `harness/smoke/run_room_live.sh` — the banner was telling the previous dispatch's story

### 3 — Reasoning

**3A — ★★ THE FLASH BUG WAS IN THE CLEANUP, NOT THE EFFECT.** Jay, on the P3.85b gate:
*"you got the flash wrong. it changes the blue color to a light greenish color but doesn't
'flash white at all."*

**My first answer was wrong and I gave it before measuring.** I said the duty cycle was too
short and a single white frame was being perceived as a tint. Plausible; false. Traced with
write taps on `$FFB0-$FFB3`, the port **never left the palette white at all** — zero white
frames — while the live palette after the mode set is:

```
f1268   $FFB0=$00  $FFB1=$26  $FFB2=$19  $FFB3=$3F
```

`sc_pal` — the table the flash **restores** — carried `$1B` for entry 2. `$1B` has more
green, so the first time the flash fired, the restore repainted the blue and **left it
repainted for the rest of the scene**. Both halves of Jay's sentence are that one bug: the
white was one frame and never seen; what *was* seen was the restore.

**Nothing upstream could have caught it.** Build green, both suites green, scene rendered —
because a restore writing a wrong value produces a scene that is internally consistent and
simply the wrong colour. It does not read as damage; it reads as a deliberate choice.

The `$1B` came from an inline `lda #$1B / sta $FFB2` in gfx.s's init path rather than from
`gfx_pal4`, the table `HAL_gfx_set_mode` actually loads — **and the two disagree inside the
HAL itself.** §8's "read constants back from the file" is exactly this rule, and this is
what skipping it costs.

`gfx_pal4` is not exported and the bundle links separately from the room, so the bytes must
be duplicated. `palette_check.py` now compares them and fails the build on divergence —
**demonstrated by re-seeding `$1B`: exit 1, naming entry 2.**

**3B — ★★ THE PACE SUSPECT WAS WRONG, AND THE NEGATIVE RESULT IS THE POINT.** Jay, with the
oracle running beside the port: *"the zizier pace is a bit slow and it looks like the
hourglass appears a bit too early."* He then chose *"fix the pace first and I'll look
again."*

Measured, the pace complaint is real and the cause is not where I said:

```
cad_tab = 6        6 frames  x237   honoured, 62% of steps
                   8 / 10    x133   slipped,  35% of steps
                   mean 7.15        19% slower than the table it is holding
```

I named the per-segment clip trim as the prime suspect and hoisted its unclipped test out
of `bc_trim` into a once-per-cel `bc_noclip`:

```
before   mean 7.15   6-frame x237   slipped x133
after    mean 6.99   6-frame x263   slipped x127
```

**0.16 frames/play. Not the cause.** The change is kept because it is structurally right —
`bc_lead`, `bc_keep` and `bc_width` cannot change within a cel, so a fast path reached
through `lbsr` was still paying the call and five stores on every segment of every cel — but
it does not fix what Jay reported.

**★ The 18,000 cy/frame figure I reasoned from was measured against a version that never
shipped.** `bc_trim`'s comment records it for the form with *no* fast path; I read it as
describing current cost. Same shape as P3.85b's deferral: a figure quoted without its scope.

**3C — ★ AND I NEARLY OVERWROTE A GOOD MEASUREMENT WITH A WORSE ONE.** I was about to lower
`cad_tab` from 6, having measured the oracle's Vraise+Pback at 5.43 f/play. Reading the
comment stopped me: **6 IS the oracle's number** — P3.72k measured `Vapproach` at `SPEED 7`
as a steady 6.0 f/step, which is precisely the vizier walk under complaint. My 5.43 came
from a different beat whose start edge was a **screen-derived** hold boundary — the same
weak instrument that gave two wrong answers in P3.85b. Lowering the table would have
displaced a deliberate measurement and made the honoured steps too fast.

**3D — A landmark bug of my own, caught by disagreement.** `port_beat_times.lua` reported
"room up at f1202"; that is the BASIC text screen at `EXEC` tripping a not-blank test. The
room is up at f2089 (the room suite measures it independently). Corrected, the hourglass
lands at room+2121 (35.4 s) against the oracle's room+2044 (34.1 s) — **1.3 s LATE**, which
is the opposite of what Jay saw, and why that question was put back to him rather than
answered.

### 4 — Verification

**25.1:** `=== BUILD COMPLETE ===` with `[palette] the flash's restore matches gfx_pal4
($00 $26 $19 $3F)`, `[hal-sync] OK`, `[sequences] … 9 sequences`, `[harness-offsets] all
checked offsets agree`, `[cel-streams] 82 cels walk exactly to their own end`.

Room: `checks=8 passed=8 failed=0`, `PASS flame pixels … 78 bytes byte-identical`.
Walk: `19 beats, 1 staged reads`, `beats_visited PASS (19 of 19)`, `engine_bank_guard PASS`,
`0 bytes WRONG` at all 28 captures, `STABLE` across two runs.

**The blitter change is pixel-neutral**, which is the only thing a speed change may be.

**25.2:** N/A — ROM build.

**25.3: NOT PASSED — and it has now failed twice with two different defects.**
Jay observed live-disk/RGB four times plus the oracle for comparison. Reported: (1) the
flash — **fixed**, and he did not re-report it after the fix, but he did not affirm it
either, so it is **not** recorded as passed; (2) the pace and the hourglass timing — **open**.

### 5 — Acceptance criteria

1. **Flash correct** — the restore bug is fixed and gated. **Not affirmed by Jay.**
2. **Strobe duration** — changed 1→3 drawn frames per play, derived from the port's own
   cadence. **The oracle's on/off ratio inside a play is still NOT traced.**
3. **Pace fixed** — **NO.** Cause unattributed; the suspect was eliminated, not confirmed.
4. **Hourglass timing** — **open**, and my measurement disagrees with the observation.
5. **Suites green** — yes, both, on the final build. **128 KB not run.**
6. **§2 grouping push** — **NOT DONE** (unchanged from P3.85b).

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** I proposed two mechanisms out loud and **both were wrong**: the
flash's duty cycle (§3A) and the clip trim (§3B). The commits contain the *corrections*, not
the proposals. I also proposed lowering `cad_tab` and **did not do it** (§3C) — that reversal
is deliberate and is the one place where not shipping a proposal was the right outcome.

Not present: the pace fix, the hourglass-timing decision, §2's grouping push, the
turn-to-exit disappearance, the 16-colour swap, the `Prolog2` handoff, `s_StTimer`.

### 7 — Uncertainty flags

- **★ The pace overrun is UNATTRIBUTED.** The 6/8/10 clustering is discrete rather than
  spread, which does not look like general draw overrun. Next split: correlate the slips
  against which beat is running — one instrumented run, no code change.
- **★ The hourglass timing is contested.** Jay sees it early; I measure it 1.3 s late. One
  of us is measuring a different thing and it is not yet established which.
- The strobe's duty cycle is derived from the port's cadence, not traced from the oracle.
- **The HAL has two disagreeing palette sources.** `gfx_pal4` is live; the inline stores at
  `gfx.s:255-262` are dead weight that reads like documentation. They misled me, and they
  will mislead the 16-colour swap the same way.
- 128 KB not run. Carried: ROOM.BIN's 6-byte headroom; 0.20 s per-call driver overhead;
  `$2310..$2329` read-tap blindness; `PlayCut0`'s remaining sound sites.

### 8 — Follow-up candidates

1. **Attribute the pace overrun by beat** — the cheapest next measurement.
2. Decide the hourglass timing question once Jay answers what "early" is relative to.
3. **Delete or reconcile the HAL's inline palette stores** — one home for those four bytes.
4. §2's grouping push for a single load.

### 9 — User interaction during task

Jay reported the flash defect; ran the gate four times plus the oracle; reported the pace
and hourglass timing; chose "fix the pace first" from four options; authorised the bisect.

### 10 — Candidate(s) captured this task

- `2026-08-14-measure-the-mechanism-not-the-rendering.md` (P3.85b, pushed)
- `2026-08-14-the-bug-was-in-the-cleanup-not-the-effect.md` — a feature is judged by what it
  does, so its teardown gets a fraction of the scrutiny; a wrong value in a restore is
  indistinguishable from the effect having changed something deliberately, and the symptom
  OUTLASTS the feature that caused it.

### 11 — Commit

`26e31db` (the palette fix + gate), `135887b` (the live banner), `009fb71` (the hoist).
All pushed to origin/wip before this report. P3.85b: `19771df`, report `b6db158`.
