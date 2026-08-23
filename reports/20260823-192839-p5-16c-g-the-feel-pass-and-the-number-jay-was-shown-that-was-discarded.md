## Form B Report — P5.16c–g — the feel pass, and a number Jay was asked to judge that the code was discarding

**Class:** build. `wip`. **`main` untouched** (`32b5fe23a49bf43e86c64f867ff59fb40c1ce0db`).

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-23T19:28:39Z (HEAD `4e06f43` at start → `17fde43` at report, wip).
Working tree clean apart from the standing untracked set.

Five commits, each one a Jay observation answered:

| | | |
|---|---|---|
| `64933e2` | **P5.16c** | the interval IS the song — prolog2 loses 7.4 s of silence |
| `48ada1f` | **P5.16d** | prolog1 holds a second longer before the cutscene |
| `82bfca8` | **P5.16e** | black out before the cutscene — the oracle's own first instruction |
| `c30969c` | **P5.16f** | the blackout clears the whole page — `HAL_gfx_clear` is 4-colour-only |
| `17fde43` | **P5.16g** | the beat table owns the durations again — prolog1 +3 s |

---

### 1 — Summary

**Every item here came from Jay watching the thing run.** None was found by a test, and two
were invisible to the whole suite. This is the arc where the intro stopped being *correct*
and started being *right*, and the report's own centre of gravity is §3E — **I twice asked
Jay to judge a change the code was throwing away.**

The five findings, in the order he reported them:

1. *"prolog2 seems to be displayed for a long time after the song ends"* → **7.98 s of
   silence**, measured. The hold was a fixed frame count taken from the oracle; the port's
   song is shorter than the oracle's was.
2. *"prolog1 transition to the cutscene is a bit to abrupt"* → +1 s. **Didn't help.**
3. *"still too abrupt"* → the useful half. It was never duration: **the oracle blacks the
   screen out** and the port hard-cut.
4. *"the bottom half of the screen … disappears"* → my blackout called `HAL_gfx_clear`,
   which is **4-colour-only** and wiped exactly half a 16-colour framebuffer.
5. *"it doesn't seem like prolog1 has extended in legth at all"* → correct, **and the reason
   was mine**: §3E.

**25.3: PASSED.** Jay, live-disk, RGB, 512 KB, 2026-08-23: *"looks good."*

---

### 2 — Files modified

- `src/engine/intro_seq.s` — `hold_song` added then removed (§3A, §3E); beat 4 and beat 5
  `BEAT_HOLD`; the blackout in `run_scene`; `blackout_page`.
- `harness/tools/beat_timeline.lua` — **new.** Beat boundaries and per-beat silence (§3F).

---

### 3 — Reasoning

#### 3A — prolog2's dead air, and the file that predicted its own fix

`BEAT_HOLD` for beat 5 is 1564 frames — **the oracle's** interval, `f5753..f7317`. The port's
rendition of `s_Sumup` stops sounding at 1113. **451 frames = 7.5 s of prolog2 in silence.**

`play_song`'s header had said what to do since P3.41:

> *"the duration is a CONSEQUENCE of the song, not a designed hold… **when sound arrives it
> replaces this BODY**"*

Sound arrived at P3.52 and the body went on spending a fixed count. P5.16c made the hold end
when the song fell silent. **It fixed the symptom and created §3E.**

#### 3B — ★★ the abruptness was not duration, and the oracle says so in one line

Two rounds went into making prolog1 *longer*. Jay's *"still too abrupt"* is what killed that
line of attack — **a hard cut does not get softer by lasting longer.** The oracle:

```
PrincessScene
 jsr blackout          ← MASTER.S:859-861, its FIRST instruction
 jsr ReloadStuff
```

The port went from prolog1's picture straight to the room's first frame. **§2's tier 3 read
directly rather than through the port's paraphrase** — and the port's own beat-6 comment,
which quotes `SilentTitle` accurately, shows why that matters: paraphrases in this codebase
are good, and this one line was not in any of them.

★ **The first diagnosis was wrong and was checked before shipping.** The obvious suspect was
`msys_stop` chopping `s_Prolog` mid-phrase. Lifting beat 4's ceiling from 820 to 3000 frames
grew the beat by **thirteen** — the song was already ending at ~833, so the cut was 0.22 s
early and inaudible. Guessing would have been the third wrong answer in a row.

#### 3C — ★★ `HAL_gfx_clear` is 4-colour-only, and Jay located it better than I predicted

I predicted the *top* half would clear. Jay saw the **bottom**, and the bottom is right:

```
HAL_gfx_clear:
        lda     <page_register          ; PAGE_A → $8000, PAGE_B → $C000
        ...
        ldy     #GFX_FB_WORDS           ; a FIXED $1E00 = 15,360 B
```

That is the **4-colour side-by-side layout**, two whole framebuffers in one window. The intro
runs 16-colour: one 30,720 B buffer across all four blocks, where `$C000` is not a second page
but **the bottom half of the only one**. The call wiped exactly that.

★ **The HAL states the correct rule in three places and this routine follows none of them** —
*"CALLERS DRAW AT HAL_gfx_draw_base AND NEVER AT A BUFFER ADDRESS"*, `HAL_gfx_cur_words` is
*"the same value callers read"*, and `HAL_gfx_mirror` **refuses** in 16-colour rather than
assuming the geometry. `blackout_page` is those two exported values used literally.

★★ **`HAL_gfx_clear` is deliberately NOT patched.** It is shared, Jay-gated substrate; every
other caller runs 4-colour, where it is correct; and this blackout is **the first 16-colour
caller the port has ever had**, which is why the bug was latent rather than old. Fixing my own
call site cannot regress anything. §8.1.

#### 3D — §2H's three checks

1. **A second mechanism for a different object class?** Yes, and it is §3C exactly: the HAL has
   *two* framebuffer geometries and one routine that only knows the other one. Asking "what
   does the 16-colour case do?" is what turned Jay's report into a diagnosis in one read.
2. **The routine that CALLS it.** The caller carried the scope twice — `run_scene` owns the
   beat boundary, so the blackout and the drive release both belong there rather than in the
   scene; and `play_song`'s *caller* (the beat table) is where §3E's control had to go back to.
3. **Prior-report grep.** P3.41 (the `play_song` stub and its own prediction), P3.52 (sound
   arriving), P4.23/P4.25b (the song-to-beat assignment), P4.47 (`BEAT_KEEP`), P3.87 (the pace
   ruling — relevant, and §8.3). No contradiction found.

#### 3E — ★★★ THE ONE THAT MATTERS: I asked Jay to judge a number the code was discarding

P5.16d raised beat 4's `BEAT_HOLD` 760 → 820 and reported *"+60 frames, exactly the 1.00 s
asked for"*, with a measurement (4342 → 4402) that was **true**. Jay looked and said it hadn't
changed. I offered to make it two seconds.

**It could not have been two seconds.** P5.16c — my own commit, three earlier — had made the
song a **ceiling** on every beat, and `s_Prolog` ends at ~833 frames. `BEAT_HOLD` above 833
was silently ignored. The +60 was the last increment that number could ever deliver, and I did
not know it while proposing more of them.

★ **Two gates were spent on this**, each ending with Jay reporting no change and me proposing
a larger version of a value that was being capped away.

★★ **And the measurement did not catch it, which is the part worth keeping.** 4342 → 4402 is
a real, correct, reproducible +60 frames. A number can be *measured accurately* and still not
be *the number that reaches the screen*. The check that would have caught it is one I had
already run for a different reason at §3B — lifting the ceiling to 3000 and seeing the beat
grow by thirteen. **I had the evidence that the song governed this beat and used it only to
exonerate the music.**

★★★ **THE FIX WAS TO GIVE THE NUMBER BACK, NOT TO MAKE THE MECHANISM SMARTER.** `hold_song`
is removed. Beat 5's `BEAT_HOLD` becomes **1150 — its song's measured length** — which
reproduces on screen exactly what the mechanism produced, while leaving the duration a value
Jay can move. *A rule that computes the right answer is worth less here than a value the
person judging it can change.* That is the whole lesson and it cost two gates to learn.

#### 3F — the instrument, and its own first wrong answer

`beat_timeline.lua` taps `probe_status`/`probe_phase` to reconstruct every beat boundary, and
`$FF20` for the music.

★ **Its first version said the music played to the last frame of every beat.** It does not:
`msys_player`'s FIRQ keeps running once the song's data is exhausted and keeps storing **the
same level**, and a steady DC level is silence. **A tap that counts writes cannot tell a note
from nothing; one that counts value CHANGES can.** Both the wrong reading and the reason are
written into the tool, because the wrong version was completely plausible.

---

### 4 — Verification (AC-by-AC)

Jay's reports are the acceptance criteria.

- **AC1 — prolog2 not held past its song.** 7.98 s of silence → **1.07 s**. Beat 5 26.55 s →
  19.64 s.
- **AC2 — the cutscene entrance not abrupt.** The oracle's `blackout` added; prolog1 → black →
  room. Jay: *"looks good."*
- **AC3 — the blackout clears the whole picture.** `blackout_page` uses `draw_base` +
  `cur_words`; Jay confirmed *"the bottom scene dissapear is fixed."*
- **AC4 — prolog1 perceptibly longer.** 4402 → **4629 frames, +3.79 s**, and the ceiling that
  made the previous attempt inert is gone.
- **AC5 — nothing else moved.** Beats 1, 2, 3, 6 frame-identical across every commit here
  (428 / 381 / 655 / 527).
- **AC6 — `main` untouched.** `32b5fe23a49bf43e86c64f867ff59fb40c1ce0db`.

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim):**

```
[map_check] 6 map(s) clean — no overlap, nothing below $0E00, introseq.map all below $2700,
            scene.map linked at $2700.
=== BUILD COMPLETE ===
[suites] -ramsize 512K
[suites] === introseq ===   [run_introseq_test] PASS
[suites] === integ ===      [integ] PASS
[suites] === tile ===       [run_tile_test] PASS
[suites] ALL PASS
```

`beat_timeline.lua`, before → after the whole arc:

```
                          BEFORE (b019264)              AFTER (17fde43)
  beat 4 prolog1(+scene)  4342 fr  72.46 s               4629 fr  77.25 s
  beat 5 prolog2          1591 fr  26.55 s               1177 fr  19.64 s
                          music ..18.57 s, 7.98 s SILENT       ..18.57 s, 1.07 s SILENT
  beats 1,2,3,6           428 / 381 / 655 / 527          UNCHANGED
```

**25.2 bundled-artifact grep:** N/A — no sibling-import artefact.

**★ 25.3 operator-runtime-smoke: PASSED — Jay, live-disk, RGB, 512 KB, 2026-08-23.**
*"looks good. now gate it and report."* Motion-bearing throughout and observed live on the
delivery path across seven successive runs, each one closing a specific report of his.

**This closes every gate open on this branch:** P5.14 (the 512 KB target), P5.15 (the cutscene
freeze), P5.16/b (the cache), and P5.16c–g (this arc).

---

### 6 — Reactive deviations and route accounting

**No route was proposed for this arc** — each commit answered one observation of Jay's, and
none of them was planned before he made it.

**Two things here diverge from the oracle deliberately**, and both are recorded *in the beat
table* rather than only here, so a future reader meets the reasoning at the value:

- **beat 4 `BEAT_HOLD` 760 → 1000.** +4.00 s over the oracle's measured `f1822..f2582`.
- **beat 5 `BEAT_HOLD` 1564 → 1150.** The port's song, not the oracle's interval.

§2I is the standing authority for both: the mandate is that the port looks and feels right,
and the oracle's timing is evidence toward that rather than the thing itself. **These are the
first two numbers in that table that are not the oracle's.**

★ **P5.16g reverses P5.16c's mechanism**, four commits after shipping it. Named here because a
revert is exactly the kind of thing a diff shows without explaining.

---

### 7 — Uncertainty flags

1. **`BLACKOUT_FRAMES` = 30 (0.50 s) is invented.** The oracle spends that interval on real
   work (`ReloadStuff`, `cutprincess1`); the port has nothing to do there *because* P5.16 made
   the scene's assets resident. Flagged in place as Jay's to rule on. He has now gated it, so
   it stands — but it was never measured.
2. **`HAL_gfx_clear` is still wrong in 16-colour** (§3C). Latent for every current caller;
   fatal for the next 16-colour one. §8.1.
3. **Dropping `hold_song` costs a property.** A song whose length changes no longer drags its
   beat with it — beat 5's 1150 would need re-measuring. The note lives in the beat table.
4. **The last 1.80 s of post-boot disk remains** — the scene program, still uncached, still
   without a root cause (P5.16 §3F).
5. **128 KB is unchanged and still broken**, since P5.15 §3E.
6. **One machine, one run each.** Frame counts are that machine's.

---

### 8 — Follow-up candidates

1. **`HAL_gfx_clear`** — take `draw_base`/`cur_words`, or refuse in 16-colour the way
   `HAL_gfx_mirror` does. Not done here because it is gated substrate and this was not its
   dispatch.
2. **The scene program's 1.80 s** — needs P5.16 §3F's unfound root cause.
3. **The RAM-size guard** — carried since P5.15 §8.1, and more urgent now: the cache needs
   eleven blocks a 128 KB machine does not have.
4. **`run_introseq_live.sh`'s banner** — stale in three ways, now four (its timings predate
   this whole arc).
5. **`main` is now unblocked.** Jay's P5.14 condition was *"until the 512kb version is gated,
   MAIN binaries need to remain untouched"* — it is gated. Merging `wip → main` is his call
   and is not done here.

---

### 9 — User interaction during task

Seven exchanges, each one a live observation, and **five of them corrections**:

1. *"there is still a long delay between the first title and prolog 1. the sequence from
   princess trough to silent title looks good."* — P5.16's gate, in part.
2. *"also it does not loop back to the beginning as you inplied"* — **my error**, and P5.13
   had it in writing.
3. *"so iwant to keep the sweep… the delay is during prolog2 not actually the transisiton."*
   — I had proposed changing beat 6's wipe. He declined it and redirected me to the real
   thing, which was §3A.
4. *"prolog1 transition to the cutscene is a bit to abrupt, may extend prologs for a sec?"*
5. *"still too abrupt."* — the report that killed the duration theory (§3B).
6. *"the bottom half of the screen … disappears right before the transition to the cutscene."*
   — §3C, located more precisely than my own prediction.
7. *"it doesn't seem like prolog1 has extended in legth at all. over both changes you made."*
   — §3E.
8. *"looks good. now gate it and report."*

---

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-23-verify-the-change-reaches-the-person-judging-it.md` — *before asking
someone to evaluate a change, confirm the change reaches the output they will look at; a value
can be correctly measured at its source and still be discarded downstream, and the reviewer's
"I see no difference" is then read as a taste judgement instead of the bug report it is.*

---

### 11 — Commit

`17fde43` — pushed to `origin/wip` before this report.
