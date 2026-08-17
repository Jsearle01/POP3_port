## Form B Report — P3.5 — the beat-hold "collapse": Jay's eye was right, and so was the test
**Class:** DEBUG — reconcile, locate, fix. **Root cause FOUND and FIXED.**
POP `wip`. **Karateka UNTOUCHED** — no `src/hal/` change; `wip` `9f68eaa`, `main`
`5eb92b1`. Sync bridge green (11 files).
**Result: both credits run, timing matches the oracle, and the sequence ends
cleanly — on the REAL `LOADM`-from-disk path. 10/10 checks, 5/5 screens
byte-identical.**

### 0 — Receipt / status (C-35 stamp)
t0=2026-07-28T00:52:39Z (POP HEAD `c6734d7`, wip; tracked tree clean at receipt).

---

### 1 — Summary

**Typing `EXEC` overwrites the program you just `LOADM`ed.** Color BASIC's
line-input buffer is at `$02DC`; the engine loaded at `$0200`; so the four
characters of the command that starts the program landed on two of its
instructions. That is the entire bug.

| | |
|---|---|
| Jay's "I watched it run correctly" | **EXPLAINED — and correct** |
| The test's "it derails" | **also correct** |
| Why they disagreed | **different launch paths**: the viewer pokes + sets PC and never types `EXEC` |
| Run-off-the-end (lead hypothesis) | **DISPROVEN** — the loop terminates properly |
| Where the collapse was | **beat 1's own hold**, not past the credits |
| Cause | `$02DD`/`$02E0` overwritten with `'E','X','E','C'` |
| Fix | engine links at `$2000`, clear of DECB's buffer |
| Now | 10/10 checks, 5/5 byte-identical, timing +100/+282/+97/+285 |

**Both observations were data and neither was wrong.** The interactive viewer
writes the image into memory from Lua and sets PC directly — nothing is typed, so
nothing is corrupted, and Jay saw the credits run exactly as they should. The test
does the real thing: `LOADM"INTROSEQ"` then `EXEC`. The only difference between the
working case and the broken case was the launch path, and that is where the fault
was.

---

### 2 — Files modified

**POP `wip`:**
- `link/pop_engine.link` — **NEW.** The engine's own map, `prog` at `$2000`. The
  P1.x probes keep `link/pop.link` and `$0200`: they are pinned there by the
  harness contract and are small enough to stop below `$02DC`.
- `src/engine/intro_seq.s` — the beat descriptor is copied out ONCE at beat entry
  and the table is not indexed again; `probe_status` is set once from the loop
  counter instead of recomputed mid-beat.
- `build.bat` — the engine links with `pop_engine.link`.
- `harness/smoke/introseq_test.lua` — probe addresses follow the engine; the base
  capture waits for the screen to actually be read.
- `harness/smoke/introseq_live.lua` — uses the real `LOADM`+`EXEC` path now that it
  works; the poke is gone.
- `mame-idioms-coco3-port.md` — **§28**, the `$02DC` line-buffer trap.

**Not modified:** `src/hal/` (0 files); Karateka; `oracle/source/`.

---

### 3 — Reasoning

#### 3.1 — PHASE 1: run-off-the-end, checked first and DISPROVEN (AC2, AC3)

Jay's hypothesis was the cheap one, so it went first. `seq_run`'s termination:

```asm
                puls    b
                ldx     seq_beat
                leax    BEAT_SIZE,x
                incb
                cmpb    #BEAT_COUNT      ; 2
                blo     sq_beat
                rts
```

B goes 0→1 (loops), 1→2 (falls through). **It stops after exactly two beats and
never touches a third descriptor.** Independently corroborated by P3.4's own data:
`probe_status=4` was observed, and 4 is only written *after* `seq_run` returns — so
the loop had already been terminating correctly all along.

**The collapse was in beat 1's own hold**, which per the dispatch's discriminator
means the credits themselves were implicated — contradicting Jay's eye. Per the
standing invariant that was treated as a reason to distrust the measurement, not
the observation, and that is what led to the cause.

#### 3.2 — PHASE 1: locating it (AC2, AC5)

Measured, in order, each step chosen because the last one refused to fit:

1. **`hold_frames` is fine.** Sampling its counter: Y decrements by exactly 1 per
   frame. It was simply handed `$353F` = 13,654 frames — a 227-second hold, not a
   collapsed one.
2. **The VBL interrupt is fine.** 1,955 acks of `$FF92` and 1,956 increments of the
   frame counter over the stall. Not the P2.6 `CC.I` family.
3. **The data is fine.** At the hang, `seq_beat` = `$03A2` and `beat_table` =
   `1B 00 0A 40 00 63 01 19` — `HOLD` = `$0119` = 281, exactly right.
4. **The linked code is fine.** `$02E0: BE 03 94` (`ldx $0394`), `$02E3: EC 06`
   (`ldd 6,x`). Correct instructions over correct data.
5. **But the bus says otherwise.** A read tap: the program reads **`$FFAE`/`$FFAF`
   = `$35 $3F`** — the MMU registers — and **never touches `$03A8`**. `$FFA8` is
   where `gfx_map_blocks` leaves X after walking `$FFA4-$FFA7`, and `HAL_gfx_swap`
   does not preserve X.

So `ldx seq_beat` was fetched and did not take effect. **An instruction that
provably executed followed by one that provably did not, in straight-line code with
no branch between them, is not a logic bug** — it means the bytes are not what the
source says. That tell was visible early and was explained away; recognising it is
what ended the search.

6. **A write tap on `$0200-$03FF`, logging the writer**, gave the answer in four
   lines:

```
f708   $02DD <- $45  from DECB PC=$A3E7    'E'
f717   $02DE <- $58  from DECB PC=$A3E7    'X'
f726   $02DF <- $45  from DECB PC=$A3E7    'E'
f735   $02E0 <- $43  from DECB PC=$A3E7    'C'
```

`$02DD` was `sta probe_phase`. `$02E0` was `ldx seq_beat`. **Color BASIC's
line-input buffer is at `$02DC`, and the harness types `EXEC` after `LOADM` has
already put the program there.**

#### 3.3 — Why every earlier symptom followed from this (AC1)

- **Jay saw it work.** `introseq_live.lua` poked the image and set PC. Nothing was
  typed, so nothing was corrupted. His observation was of a genuinely correct run.
- **The test saw it derail.** It used `LOADM`+`EXEC`, the real path, which carries
  the fault.
- **It moved when instrumented.** Which instructions sit under `$02DC` is a
  build-layout accident, so four bytes of diagnostic changed the victim. Across
  P3.4/P3.5 the same program showed correct timing with nonsense status bytes, sane
  status bytes with collapsed timing, a hang, and a clean run — every measurement
  honest about the build it came from, and the set mutually contradictory.
- **P3.2/P3.3 never hit it.** Neither ever used `LOADM`; the ceiling (§23) meant
  they could not. Fixing the ceiling in P3.4 is what first exposed this.

#### 3.4 — PHASE 2: the fix (AC4)

**Primary — get out of DECB's buffer.** `link/pop_engine.link` puts `prog` at
`$2000`: above the line buffer (`$02DC-$03D5`), the text screen (`$0400-$05FF`) and
the DOS workspace (`$0600-$09FF`), and below the graphics pages' end at `$25FF`.
A separate script because the probes cannot move — they are pinned at `$0200` by
the P1.1 harness contract and are small enough to stop below `$02DC`.

**Secondary — remove the fragility the bug exploited.** The beat descriptor is now
copied out once at beat entry and the table is never indexed again; `probe_status`
is set once from the loop counter rather than recomputed by reading `probe_beat`
back. The old shape re-derived `ldx seq_beat / ldd FIELD,x` after every call, which
required the reload to be correct *and* to survive whatever ran in between. That is
a dependency worth deleting on its own merits — `HAL_gfx_swap` genuinely does not
preserve X — and it is what made a two-byte corruption fatal rather than cosmetic.

**Not fixed, because it was not broken:** hold timing. Jay's eye was right.

---

### 4 — Verification (AC-by-AC)

- **AC1 Jay's observation explained** — **MET.** §3.3: the viewer pokes and never
  types `EXEC`, so his run was genuinely correct. The credits were never broken.
- **AC2 collapse located** — **MET.** Beat 1's own hold, receiving `$353F` because
  `ldd BEAT_HOLD,x` read `$FFAE/$FFAF`; root cause the `$02DC` overwrite.
- **AC3 `seq_run` termination checked** — **MET.** Terminates correctly at
  `BEAT_COUNT=2`; run-off-the-end **disproven** (§3.1).
- **AC4 fixed; both credits run and it ends cleanly** — **MET**, verbatim in §5.
- **AC5 measure-skeptically** — **MET.** Four hypotheses eliminated by measurement
  (hold_frames, the VBL path, the data, the linked code); one measurement
  (registers sampled inside a tap) was identified as unreliable and discarded
  rather than built on.
- **AC6 one kernel** — **MET.** Sync bridge green; **0 files** changed under
  `src/hal/`; Karateka untouched.
- **AC7 git status clean except the fix + report** — **MET.**

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim):**

```
loadm_from_disk              PASS 1396 B, 2 segments, at frame 644 — the real path
capture_1_base               PASS
capture_2_presents_up        PASS
capture_3_presents_clear     PASS
capture_4_byline_up          PASS
capture_5_done               PASS
seq_magic                    PASS $5E92 (want $5E92)
beats_completed              PASS last beat index 1
disk_reads_completed         PASS probe_loads = 3 (want 3: bundle + screen x2)
image_cannot_contain_screen  PASS INTROSEQ.BIN is 1396 B; the framebuffer is 30,720 B
# --- transitions ---
#   1_base           frame  3723
#   2_presents_up    frame  3823   (+100)
#   3_presents_clear frame  4105   (+282)
#   4_byline_up      frame  4202   (+97)
#   5_done           frame  4487   (+285)
# both credits ran
# checks=10 passed=10 failed=0
# VERDICT: PASS

  PASS base screen == converted splash, centred: 30720 bytes byte-identical
  PASS caption 1 == base + presents patch: 30720 bytes byte-identical
  PASS caption 1 removal is exact: 30720 bytes byte-identical
  PASS caption 2 == base + byline patch ONLY: 30720 bytes byte-identical
  PASS final screen == base: 30720 bytes byte-identical
VERDICT: PASS
```

Against the oracle: **+99/+281/+96/+283** measured on the Apple II (P3.3) versus
**+100/+282/+97/+285** here — one to two frames, the swap's own VBL wait.

Regressions: `probe PASS`, `mode PASS`, `anim PASS`.
The corruption itself, verbatim, in §3.2.

**25.2:** `link/pop_engine.link`; `seq_run`/`sq_beat` in `src/engine/intro_seq.s`;
idiom §28.

**25.3:** the full sequence on the real disk path, ending cleanly, recorded to
`C:\Users\jayse\OneDrive\Pictures\pop-coco3-intro-P3.5.mp4` (613 KB, 1280×944 DAR
4:3, 16.0 s). Jay already passed the credits' appearance in P3.3; the new thing to
confirm is the clean end. **Not self-certified.**

---

### 6 — Reactive deviations (§22.5)

1. **The engine got its own link script** (`$2000`). The probes could not move
   (harness contract) and the engine could not stay.
2. **The beat descriptor is cached at entry** and `probe_status` set once — removing
   the re-index pattern rather than only relocating away from the corruption.
3. **`introseq_live.lua` now uses `LOADM`+`EXEC`.** It had been the poked path, and
   keeping it that way would preserve the exact blind spot that caused this.
4. **The base capture waits for the disk reads.** Setting `probe_status` at beat
   entry moved it before `load_screen`, so the harness briefly captured an empty
   framebuffer — a test artifact I introduced and fixed.
5. **One measurement was discarded as unreliable:** registers sampled inside a bus
   tap are mid-instruction, and reported X as `$FFA8` where the source said
   otherwise. It happened to be right, and was still not evidence.

---

### 7 — Uncertainty flags

1. **The load is slow — ~47 s** before the first picture (three whole-track reads at
   ~23 s each, against the oracle's ~3 s for its entire stage). Unchanged from P3.4
   and now the most visible defect in the intro.
2. **`$02DC-$03D5` is asserted from the measurement**, not read out of Color BASIC
   Unravelled. The start (`$02DC`) is directly observed; the 250-byte length is the
   documented buffer size and was not verified here. The engine sits far above
   either way.
3. **Nothing else in `$0200-$03FF` was audited** for other DECB owners. The engine
   no longer lives there, so it is moot for the engine, but the probes still do.
4. Carried: the pipeline needs the oracle for display-faithful conversion;
   `HAL_gfx_set_palette` is still a P3 stub.

---

### 8 — Follow-up candidates

1. **Load speed** (§7.1) — ~3.3 s per track against a 0.2 s revolution. The intro is
   correct and slow; this is what a viewer would notice first.
2. **Halve the base load** with a chunked front-to-back MMU copy instead of reading
   the screen twice.
3. **The title beat** — the mechanism, the memory and now the loader all support it.
4. **`HAL_gfx_swap` clobbers X** and hal.inc does not say so. Worth stating in the
   ABI comment; the caching fix means POP no longer depends on it, but the next
   caller will not know.
5. Carried: the unmasked counter read (P2.9); the edge-blink raster measurement; the
   two buffer models; the 16-colour frame budget; `POP-idioms-coco3-markers.md`'s
   fate; the CLAUDE.md boot-contract statement drafted in P2.8 §8.1.

---

### 9 — User interaction during task

None during execution. The dispatch carried Jay's two observations — that he had
watched the sequence run correctly, and that nothing exists after the Mechner
credit — and both were load-bearing: the first was the fact the diagnosis had to
explain and ultimately the thing that identified the launch path as the variable;
the second scoped the fix to terminating at the real end rather than building a
third beat.

---

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-07-28-when-human-and-test-disagree-ask-what-each-one-launched.md`
- `seeds/POP/live/2026-07-28-a-layout-sensitive-fault-makes-the-diagnostic-part-of-the-experiment.md`

Pool commit `fad8e99`, pushed.

---

### 11 — Commit

**POP:** `94885d1` — the engine link script, the sequencer fix, the harnesses, idiom
§28, this report. Pushed to `origin/wip`.
**Karateka:** untouched — `wip` `9f68eaa`, `main` `5eb92b1`.
