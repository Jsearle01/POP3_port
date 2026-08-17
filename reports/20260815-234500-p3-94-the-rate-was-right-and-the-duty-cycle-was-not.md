## Form B Report — P3.94 — the rate was right and the duty cycle was not

**Class:** build. wip. Prod untouched.

**★★★ P3.93 VERIFIED THE ARMING RATE AND THE ARMING RATE WAS CORRECT. What reaches the eye is the
DUTY CYCLE, and it was one continuous white run of 41 video frames. Jay: *"i only see one long
strobe."* ★ The verification was sound and could not have caught this — it measured the wrong
quantity, and no suite in this project can see the defect at all.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-15T~22:50-04:00 (HEAD `4ec38c3`, wip). Karateka untouched. `main` untouched. Oracle
source read-only. Pre-existing, not mine: `dist/mame-cfg/rgb/coco3.cfg`.

---

### 1 — Summary

| | |
|---|---|
| **the report** | Jay, P3.93 gate: *"i only see one long strobe."* **Confirmed by measurement** |
| **measured** | one WHITE run, **f4186..f4227 = 41 video frames, 0.68 s**, no dark gap |
| **★ why P3.93 missed it** | it verified the **rate**; the eye receives the **duty cycle** |
| **root** | `SC_LIT_FRAMES = 3` **drawn frames**, and the next arm beat it to zero |
| **★ the oracle** | brackets **one frame's draw**, not a play — five **single-frame** flashes |
| **fix** | `SC_LIT_FRAMES` 3 → **1** |
| **now** | WHITE 5, dark 5, WHITE 4, dark 4, WHITE 3, dark 3, WHITE 4, dark 4, WHITE 3 |
| **25.3** | **PENDING JAY** — relaunched, observed 79 s, no words |

### 2 — Files modified

- `src/engine/char_draw.s` — `SC_LIT_FRAMES` 3 → 1; the comment that set it corrected
- `harness/tools/port_flash_duty.lua` — NEW; measures the palette, not the counter
- `harness/smoke/run_room_live.sh` — banner: count the strobes, check the blue in each gap

### 3 — Reasoning

**★ §2H's THREE CHECKS** (fourth dispatch prompted by the §7 pointer):

1. **A second mechanism for a different object class?** **Yes, and it is the whole finding.** The
   flash has two independent quantities — **when it fires** (`lightning` / `sc_lit` arming) and
   **how long it stays on** (the bracket / the countdown). P3.93 fixed and verified the first and
   left the second untouched, and the second is what the eye receives. They are not the same
   mechanism and one being right says nothing about the other.
2. **The calling routine.** `flashon` and `flashoff` are not a standalone effect — they are called
   **around `FrameAdv`** in the playback loop [SUBS.S:898-904]. **The enclosing routine is the
   fact**: read alone, `flashon` looks like "turn the flash on"; read in its caller it is
   *"turn it on for the duration of one frame's draw"*, and `flashoff` carries the `dec lightning`
   that makes five arms into five **frames**.
3. **Grep the reports for the subsystem.** The duty cycle has been flagged as *"derived, not
   traced"* since P3.85c and again at P3.93 §7 (*"a derived number … now multiplied by five"*).
   **The flag was correct and was carried four dispatches without being closed.** It is closed now,
   and not by a trace — by reading the enclosing routine.

**3A — WHAT WAS MEASURED, AND WHY THE INSTRUMENT CHANGED.** P3.93 traced `sc_lit` arming and
reported five arms at frames 4186 / 4196 / 4204 / 4210 / 4218. That is correct and it is still
correct. **It is not what Jay is looking at.** A write tap on `$FFB0` — the palette register the
screen actually obeys — gives the quantity his eye receives:

```
WHITE  f4186 .. f4227    41 video frames
```

**One run. No dark gap anywhere in it.** `sc_lit` was armed to 3 and decremented once per **drawn
frame**; the arms are ~8-10 video frames apart and three drawn frames is ~11, so every arm landed
before the countdown reached zero. The palette was never restored between plays. Five arms, one
strobe — exactly as reported.

**★ P3.93's verification was sound and structurally could not have caught this.** It asked "does it
fire once per play?" and the answer was yes. The defect lives in a different quantity entirely, and
§6.3 of that dispatch (*"a branch reading correctly is not a rate"*) has a sibling this one earns:
**a rate reading correctly is not a duty cycle.**

**3B — ★★ THE COMMENT THAT SET `3` WAS WRONG ABOUT THE ORACLE'S SHAPE.** It read:

> *WHITE FOR MOST OF THE PLAY, NOT ONE FRAME OF IT. The oracle brackets each play with
> flashon...flashoff, so the screen is white while the play draws…*

The bracket is not around a play. It is around **one frame's draw** [SUBS.S:898-904]:

```
jsr NextFrame      decide
jsr flashon        white ON
jsr FrameAdv       draw the hidden page
jsr flashoff       white OFF — and `dec lightning` [SUBS.S:863-867]
```

`lightning` is decremented **once per `flashoff`**, so `lda #5 / sta lightning` is **five
single-frame flashes**, each switched off at the end of the frame it was switched on for. **The
oracle never holds white across consecutive frames.** Three was not a magnitude error; it was the
wrong shape.

**★ And the arithmetic behind the 3 was out of scope twice over.** It assumed a ~2.3-frame iteration
— which is `flm_cad`'s **target**, never achieved; the loop runs ~3.6 — and a 10-frame step, now 8.
So it computed "about four drawn frames per play" where a play is **~2.2**. Three of them white was
longer than the whole play, and the strobes ran together: **the exact failure that comment said it
was avoiding.** A duration counted in drawn frames drifts whenever the loop does, which is P3.25's
bug one object along — *"The table was always in the right unit; the counter was not."*

**3C — THE FIX AND THE RESULT.** `SC_LIT_FRAMES` 3 → 1: one drawn frame of white per arm, matching
`lightning`'s one decrement per `flashoff`. Re-measured on the palette:

```
WHITE 5   normal 5   WHITE 4   normal 4   WHITE 3   normal 3   WHITE 4   normal 4   WHITE 3
```

**Five strobes with dark between them**, ~50% duty, 3-5 video frames each.

**3D — ★ NO SUITE IN THIS PROJECT CAN SEE THIS DEFECT.** The flash is four palette registers and no
pixels, so the framebuffer is byte-identical whether the screen is white or blue. The suites passed
before the fix, passed after it, and would pass with the flash removed entirely. **That is not a
coverage hole to close by adding captures** — the checkers compare framebuffer bytes by
construction, and the palette is not in them. `port_flash_duty.lua` is the instrument for this
class, and it is in the tree.

### 4 — Verification

- **The defect reproduced from Jay's report**, on the machine, as a palette timeline (3A).
- **The fix's target derived from the oracle's own structure**, not tuned to the symptom (3B).
- **The result re-measured with the same instrument** (3C) — not inferred from the constant.
- **Suites green both sizes**: room `checks=8 passed=8 failed=0`, `78 bytes byte-identical`; walk
  **44 captures, 0 bytes wrong**, `19 of 19` beats, `STABLE`. **Expected, and not evidence here**
  (3D).
- **Build verified by symbol from a freshly baked image.**

### 5 — Verdict-time evidence (v0.7 §11)

**25.1** `=== BUILD COMPLETE ===`; `[hal-sync] OK`; `[harness-offsets] all checked offsets agree`.
Suites as above, both memory sizes.

**25.2** N/A — ROM build.

**25.3 — ★ PASSED for the flash and the slump. Jay, live-disk, RGB, 2026-08-15:**

> *"so the flash looks good. her slumb looks good. but he still has a frame of two where he
> dissapears except for his feet. there are eithr at the end of thr raise phase or very beginning
> of the his turn"*

- **★ THE FLASH IS AFFIRMED AGAINST THE FIVE-STROBE BEHAVIOUR.** This is the affirmation the
  2026-08-15 single-strobe pass could not carry forward, and it also clears the **restore's blast
  radius**: `sc_pal` now runs five times per beat where it had only ever been exercised once, and
  the blue comes back correctly each time.
- **★ HER SLUMP IS AFFIRMED, which closes a qualification rather than a defect.** It had been
  *observed-unknown* since P3.90 — my coverage caveat, never a fault he reported. The 79-second run
  reached it and he looked. **Recording what a qualification was ABOUT is what made this closeable
  in one line.**
- **THE TURN DISAPPEARANCE PERSISTS, and he has narrowed it sharply**: *"a frame or two"*, *"except
  for his feet"*, and now a location — *"the end of the raise phase or very beginning of his
  turn."* Carried to P3.95; see §8.

The terminal beat's flowing sand begins ≈ 80 s and the run ended at 79; **still unobserved.**

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** No dispatch was open; this is work taken directly from Jay's gate report,
which §6.5's earned-stop list names as a reason to continue. **What I did NOT do is tune the
constant to the symptom**: 1 is derived from `flashoff`'s `dec lightning` inside its caller, and
had the oracle's bracket turned out to span a play, the fix would have been elsewhere.

**★ I corrected a source comment I had relied on.** The "white for most of the play" note was
evidence I accepted at P3.85c and re-cited at P3.93 §7 while flagging the number as derived. The
flag was right; I never followed it to the caller. That is §2H check 2 catching my own prior work.

Not present: the terminal beat's sand (unobserved, not unchanged); the turn disappearance; the peel.

`hal-sync` OK. Karateka untouched. `main` untouched.

### 7 — Uncertainty flags

- **★ The strobe durations are uneven — 5, 4, 3, 4, 3 video frames** — because one *drawn* frame is
  a variable number of *video* frames (the loop runs 3-5). Faithful to the oracle's structure (it
  also flashes for one drawn frame), but it is a variable-length flash and Jay may read it as
  uneven. **Named so it is not discovered as a surprise.**
- **The dark gaps are equally variable** and roughly equal to the white runs; the oracle's true
  on/off ratio inside a play is still not traced, only its *shape*.
- **The 2026-08-15 affirmation covered the single-strobe behaviour** and does not carry to this.
- **The terminal beat's flowing sand remains unobserved** — decided on §2I grounds at P3.93, still
  never seen; the 79 s run stops ~1 s short of it.
- Carried: the turn-to-exit disappearance; the exit pace; the characters' per-iteration draw;
  0.20 s driver overhead; `$2310..$2329` blindness; sound sites stubbed as holds.

### 8 — Follow-up candidates

1. **The turn-to-exit disappearance** — now the largest open defect Jay has reported.
2. **Watch the terminal beat once** — it needs ~85 s and has never been on screen.
3. Trace the oracle's flash on/off ratio if the uneven strobe reads wrong.

### 9 — User interaction during task

Jay, on the P3.93 gate: **"i only see one long strobe."** That is the whole of this dispatch's
input and it is quoted verbatim in 3A. He then asked for the gate to be run again, which was done
before the fix; this report covers the run after it.

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-15-verifying-the-rate-is-not-verifying-the-effect.md`

### 11 — Commit

`e319d10` (the fix + the instrument), the banner, and this report. Pushed to origin/wip.
