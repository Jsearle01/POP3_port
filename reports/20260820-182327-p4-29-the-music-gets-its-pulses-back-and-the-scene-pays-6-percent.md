## Form B Report — P4.29 — the music gets **3.5× its pulses** back; the scene pays **6%**

**Class:** build.  wip.  Prod changed — `src/engine/blit_core.s` gains two instructions at `bc_row_done`;
`bc_saved_s` relocates `$3AD7 → $3ADB`. Karateka untouched; `main` untouched (`34e93e0`).

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-20 18:23 (HEAD `a88f7c5` at receipt, wip; `44af104` at report). Tree clean apart from the modified
`dist/mame-cfg/rgb/coco3.cfg` carried since P4.19 and the pre-existing untracked files.

### 1 — Summary

| | |
|---|---|
| **the change** | `andcc #$AF` / `orcc #$50` at `bc_row_done`. **Six cycles per row** |
| **★★★ the music** | **DAC pulses 493 → 1720 in 3 s (×3.5); >25% deviations 76.4% → 19.3%** |
| **what it really was** | **not jitter — TWO THIRDS OF THE PULSES WERE NEVER EMITTED** (§3B) |
| **★★ the cost** | **scene 46.6 → 49.4 s (+6.0%)**; blits/3 s 238 → 178; ms/blit 10.40 → 14.66 |
| **where the cost is** | **not the two instructions** — servicing ~6.9 FIRQs per blit the port was dropping (§3C) |
| **framebuffer** | **0 of 15,360 bytes differ**, captured at the same **blit count**, not the same frame (§3D) |
| **★ §1's code** | assumed S needed saving here. **It does not** — and its `sts` was a no-op (§3A) |
| **★★★ P4.28 §8** | **KILLED by the direction of this result** — mine to close (§3E) |
| **Jay's gate** | **OFFERED, run launched and completed. PENDING JAY.** |

### 2 — Files modified

- `src/engine/blit_core.s` — the unmask window at `bc_row_done`, with its precondition stated in place.
- `harness/tools/blit_fb_at_n.lua` — **NEW.** The drawn buffer after exactly N blits, for §3D.

### 3 — Reasoning

#### 3A — ★★ THE WINDOW NEEDS NO `lds`/`sts`, AND §1's CODE ASSUMED IT DID

The dispatch specified:
```
                lds     bc_saved_s              ; real stack — interrupts are safe
                andcc   #$AF
                orcc    #$50
                sts     bc_saved_s              ; in case FIRQ modified S
```
**S is already the real stack at `bc_row_done`.** Every S-modifying site in the file was enumerated before
writing a line:

| site | what it does |
|---|---|
| `:121 sts bc_saved_s` | park the real stack at entry |
| `:265 leas a,x` → `:290 lds bc_saved_s` | the unclipped blast, **restored immediately after** |
| `:306 lds #bc_scratch_end` → `:311 lds bc_saved_s` | the clipped blast, **same** |
| `:424 lds bc_saved_s` | the final exit |

**Those two blast regions are the only places S is a framebuffer pointer**, and both already end with
`lds bc_saved_s` — *"PUT THE REAL STACK BACK, IMMEDIATELY"*, the rule P3.78d was caught by. The row-end
bookkeeping walks **X**.

**★ So the `lds` is redundant and the `sts` is a NO-OP** — after `lds bc_saved_s`, S holds the saved value,
and storing it back writes the same bytes. The pair would have cost **12 more cycles per row** to accomplish
nothing. The window is **6 cycles**, not 18.

**★★ AND IT MUST PRECEDE `dec bc_rows`.** `andcc`/`orcc` write CC directly, so placing them between the
`dec` and its `lbne` would destroy the loop's own Z flag. The dispatch had the position right.

**★ TWO PRECONDITIONS CHECKED RATHER THAN ASSUMED**, both recorded in the source:
1. **The FIRQ handler is safe to take here.** A 6809 FIRQ stacks only PC and CC, so a handler that clobbered
   a register would corrupt this loop; msys's pushes `a,b,x,y,u` and restores them before `rti`
   [`msys_player.s:200,237`].
2. **`andcc` sets the mask absolutely** — it *enables* interrupts rather than restoring the caller's state.
   Every caller reaches here through `room_loop`, which runs with IRQs on. **There is no caller today that
   blits with interrupts deliberately masked**; if one appears this must become a restore of the caller's CC
   (on the stack at `,s`), at 13 cycles instead of 6. Stated in the code so it is checkable.

#### 3B — ★★★ THE MUSIC WAS NOT JITTERED. IT WAS MISSING.

Same 3.0 s window, same tool, same run structure:

| | before | after |
|---|---|---|
| DAC pulses | 493 | **1720 (×3.5)** |
| mean period | 6051 µs (165 Hz) | **1743 µs (574 Hz)** |
| >25% off the previous | 76.4% | **19.3%** |
| >5% off the previous | 81.1% | 52.9% |

**★★ THE PULSE COUNT IS THE FINDING, NOT THE DEVIATION PERCENTAGE.** A ×3.5 rise in pulses at a *shorter*
mean period means the previous measurement was not observing a distorted note — it was observing **a note
with most of its edges absent**. The 6051 µs "period" was the gap between the pulses that survived.
★ *P4.28 read that number as a low-pitched note and said so; it was a decimated one.*

#### 3C — ★★ THE COST, AND WHERE IT ACTUALLY IS

| | before | after |
|---|---|---|
| scene length | 46.6 s | **49.4 s (+6.0%)** |
| blits / 3 s | 238 | **178 (−25%)** |
| ms per blit | 10.40 | **14.66 (+41%)** |
| `s_Vizier` / `s_Buildup` / `s_Magic` vs oracle | −1.0 / −0.7 / +2.0 s | **+1.8 / +2.0 / +4.7 s** |

**The +41% per blit is NOT the two instructions.** Six cycles per row against rows P3.19 measured at
4.5-5.8 cy/byte is small; the arithmetic that matters is **~6.9 additional FIRQs serviced per blit**
(1720 − 493 extra pulses ÷ 178 blits). **The port is now doing work it was previously dropping on the
floor**, and the scene runs slower because that work is real.

★ *This reframes the trade: it is not "audio quality costs frame budget", it is "the frame budget was
being balanced by silently discarding the music".*

**AC2 asked for per-row overhead as a percentage of average row time. I have the per-BLIT figure measured
and the per-row figure only as instruction timings (6 cycles), because nothing in this pass counts rows.**
Stated rather than estimated — §7.

#### 3D — ★★ THE FRAMEBUFFER CHECK, AND WHY IT COULD NOT BE FRAME-KEYED

**HARD-STOP 2.** The two builds run at **different speeds**, so "the same frame after the scene starts"
lands on a different animation step in each and would report **pace as corruption**. The capture is
therefore keyed on **work**: the drawn buffer after exactly N blits, counted on `bc_saved_s`'s write.

```
with    the window:  # drawn buffer $8000..$BBFF (15360 B) captured at blit #400   # frame 5828
without the window:  # drawn buffer $8000..$BBFF (15360 B) captured at blit #400   # frame 5734
differing bytes: 0 of 15360
```

★ **The 94-frame difference between the two captures is the pace divergence, visible in the same run that
shows the picture identical.** That is the design working: same work, same picture, different clock.

★★ *The corruption this looks for is specific — an interrupt taken while S is a framebuffer pointer pushes
PC and CC through it, three bytes, localised. P3.78d's instance was "two wrong bytes out of thirty-nine".
Only a byte-exact comparison would see it.*

#### 3E — ★★★ P4.28 §8's HYPOTHESIS IS KILLED, AND IT WAS MINE

I flagged that `orcc #$50` masks **IRQ** as well as FIRQ, that `time.s:135` makes the VBL IRQ handler the
frame counter's only writer, and that a ~15 ms masked stretch against a 16.7 ms frame sits where a second
VBL could be lost — **a candidate cause for P3.87's accepted 19% pace slip.**

**The direction of this result contradicts it.** If counts had been lost, restoring the interrupts would
make the scene run **faster**. It runs **6% slower**. A pending interrupt is taken on unmask rather than
dropped, so the counter was never under-counting; the slip is something else.

★ *Closed here rather than left standing, because I raised it and an unretracted hypothesis becomes a fact
by repetition — this project has six recorded instances of exactly that.*

#### 3F — ★★★ AN INSTRUMENT THAT SILENTLY CHANGED WHAT IT MEASURED

`blit_mask_window.lua` reported the masked interval getting **worse**: median 15.1 → 21.6 ms, 82.5% → 87.0%
of wall clock, "100.0%" of blits longer than a note period. **I nearly reported that as a regression.**

**It is not a regression and the tool is not broken.** It brackets `sts bc_saved_s` → last `lds bc_saved_s`.
Before the change, nothing ran inside that bracket but the blit, so the bracket **was** the masked interval.
After the change, interrupts are **serviced inside it** — so the same taps on the same code now measure the
blit's **elapsed** time, which includes the windows and the handlers. **Same instrument, same addresses,
different quantity**, and the change of meaning was caused by the very fix it was measuring.

★★ *The tell was the accompanying number: "blits longer than ONE NOTE PERIOD: 178 (100.0%)" is trivially
true once the note period drops to 1743 µs, and a metric that reads 100% is usually measuring the wrong
thing.* Captured (§10).

#### 3G — §2H's three checks

1. **A second mechanism?** ★ **Yes — the mask covers IRQ *and* FIRQ**, so this window serves the frame
   counter as well as the music. §3E measures which of the two mattered: the FIRQ.
2. **The calling routine.** `bc_row_done`'s caller is the row loop, entered from `bc_seg`'s `SEG_END`;
   the blast's *own* masked regions are `bc_blast_back`/`bb_clip_back`, and **naming `blit_cel` alone would
   have hidden that S is already restored between them** — which is the whole of §3A.
3. **Prior-report grep** (`blit_core|orcc|bc_saved_s|blast`): P3.19, P3.20, P3.78d, P4.28. **No
   contradiction.** P3.78d's "restore S immediately" note is the load-bearing prior fact and it held.

### 4 — Verification (AC-by-AC)

- **AC1 the window inserted between rows at `bc_row_done`** — **PASS** (§3A), as two instructions, with §1's
  redundant pair omitted and the reason given.
- **AC2 per-row overhead measured** — **PARTIAL.** The window's own cost is **6 cycles/row** (instruction
  timings). The **per-blit** cost is measured at **+41%**, and §3C attributes it to FIRQ servicing rather
  than to the window. **Rows were not counted** — §7.
- **AC3 FIRQ service count per blit** — **PASS, derived from measurement: ~6.9 additional per blit.**
- **AC4 jitter re-measured** — **PASS.** 81.1% → 52.9% at >5%; **76.4% → 19.3% at >25%**; pulses ×3.5.
- **AC5 cutscene pace re-measured** — **PASS. 46.6 → 49.4 s (+6.0%)**, and §3E closes the P3.87 hypothesis
  it was meant to test.
- **AC6 framebuffer verified clean, byte-diff with and without** — **PASS. 0 of 15,360** (§3D).
- **AC7 suites green 128 KB first** — **PASS**, `integ` included. ★ *512 KB not run: this touches neither
  MMU, bank, framebuffers nor loader.*
- **AC8 Jay gates by ear** — **PENDING JAY** (§5).
- **AC9 route accounting; Karateka untouched; `main` untouched** — **PASS** (§6).

### 5 — Verdict-time evidence (v0.7 §11)

```
[suites] -ramsize 128K
[run_introseq_test] PASS
[integ] PASS
[suites] ALL PASS
```
```
## SCENE  s_Princess          (after)
   pulses            1720
   mean period       1742.8 us  (574 Hz)
   periods > 5% off the previous    909 of 1718  (52.9%)
   periods > 25% off the previous   332  (19.3%)
```
```
# scene frames 5418..8379 = 49.4 s        (P4.27 baseline: 5418..8209 = 46.6 s)
  s_Princess      5451       0.6s       0.2s      +0.4s
  s_Vizier        6524      18.5s      16.7s      +1.8s
  s_Buildup       7116      28.3s      26.3s      +2.0s
  s_Magic         7792      39.6s      34.9s      +4.7s
```
```
differing bytes: 0 of 15360        (blit #400, with vs without the window)
```

**25.3 operator-runtime-smoke: OBSERVED — Jay, live-disk, RGB, 128 KB, sound on, BY EAR.** Verbatim:

> ***"the music upon entry to the scene is still a bit crappy, but at least it is playing in the appropriate
> amount of time. also, i don't hear the door squeak and there sound be a sound after the vizier exit whith
> the princess hani her head. that is missing"***

**★★ THE TIMING IS ACCEPTED** — *"at least it is playing in the appropriate amount of time"* — which settles
P4.27's provisional AC2/AC6 as well as this dispatch's pace question. **The 6% cost is not objected to.**

**★★ THE AUDIO QUALITY IS IMPROVED BUT NOT PASSED** — *"still a bit crappy"*. So the residual **52.9%** of
§7's uncertainty flag is real and audible, and this dispatch is a **partial** fix rather than a closed one.

**★★★ AND TWO CUES ARE MISSING, WHICH IS A DIFFERENT DEFECT AND NOT AUDIO QUALITY AT ALL:** the door squeak
(`s_Squeek`) and a sound after the vizier's exit over the princess slumping (`s_StTimer`). **Both were
already in P4.23's table as "never fires"** and both are absent from the PLAN. Opened as §8's first item.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING. This commit contains** the two-instruction window, the audio measurement, the pace and
per-blit cost, the framebuffer byte-diff and its work-keyed capture tool.

**★★ ONE DEVIATION FROM §1, STATED (§3A):** the specified `lds`/`sts` pair is omitted. It is redundant here
and its `sts` was a no-op; including it would have tripled the window's cost for nothing. **The dispatch's
position for the window was right and is used unchanged.**

**★ AND ONE THING I ALMOST REPORTED AND DID NOT (§3F):** an apparent regression in the masked interval,
which was my own instrument's meaning changing under the fix. The numbers were discarded, not published.

**Not attempted:** the narrower alternative — masking only around the two blast regions instead of at entry
— which §3A's enumeration shows is possible and would give a window between **every segment** rather than
every row. **Jay ruled for chunking between rows and that is what was built**; the alternative is §8's, with
the evidence for it already in hand.

### 7 — Uncertainty flags

- **★★ AC2 IS PARTIAL.** Rows were not counted, so "6 cycles as a percentage of average row time" is not
  measured — only the instruction cost and the per-blit total. **HARD-STOP 4 asks whether the per-row cost
  exceeds 15% of row time, and I cannot answer that from this pass.** What I can say is that the observed
  +41% per blit is dominated by FIRQ servicing, not by the window.
- **The pace cost is one measurement of one run.** 46.6 → 49.4 s.
- **The >5% deviation figure remains 52.9%**, which is high. Part is genuine note changes (§3B's caveat from
  P4.28 still applies) and part may be residual delay. **I have not decomposed it**, and it is the number to
  watch if Jay says the audio is still not right.
- **`s_Squeek` and `s_StTimer` still never fire** — pre-existing since P4.23, untouched.

### 8 — Follow-up candidates

- **★★★ THE TWO MISSING CUES JAY NAMED — LOCATED IN THE ORACLE'S SOURCE, SAME CLASS AS P4.27.**
  `PlayCut0` makes **SIX** `PlaySongI` calls; the PLAN carries **four**:

  | oracle [`SUBS.S`] | PLAN |
  |---|---|
  | `s_Princess`, after `play 2` | ✓ (P4.27) |
  | **`s_Squeek`** — `lda #s_Squeek / ldx #0 / jsr PlaySongI ;door squeaks...`, after `Palert` | **✗** |
  | `s_Vizier`, after the first `Vstop` | ✓ |
  | `s_Buildup`, after the second `Vstop` | ✓ |
  | `s_Magic`, after `sta psandcount` | ✓ |
  | **`s_StTimer`** — `SUBS.S:755`, **`jmp PlaySongI`**, after `Pslump` | **✗** |

  ★ *The last is a **tail call** and is the routine's final act — it would be missed by anyone reading only
  the body.* Both match P4.23's oracle column (14.1 s and 42.7 s) and its "never fires" note exactly.
  **★★ WHAT IMPLEMENTING NEEDS, so it is not mistaken for a two-line edit:** (a) `SONG_ID` gains
  `s_StTimer: 12` [`SOUNDNAMES.S:54`] — `s_Squeek: 8` is already there, so only its PLAN row is absent;
  (b) each new `("song", …)` row carries a **traced duration**, and P4.23's oracle cue times give the
  intervals but not the play-counts to subtract — the same derivation P3.72l did for 761 and 358;
  (c) `s_StTimer` is a tail call, so it likely attaches to the **terminal** beat with no hold, which is a
  different shape from the other four; (d) the index shift moves `SCENERY`'s keys again.
- **★★★ THE NARROWER WINDOW, NOW EVIDENCED (§3A).** S is a framebuffer pointer **only** between
  `leas a,x`/`lds #bc_scratch_end` and their immediate `lds bc_saved_s`. So the entry mask could be removed
  and replaced by a mask around **just those two regions** — giving the interrupt a window between every
  *segment* rather than every *row*. ★ *That would cut the remaining latency further and might reduce the
  6% pace cost, since fewer FIRQs would arrive late and need catching up. It is a bigger change to the
  masking structure and needs its own framebuffer check.*
- **Decompose the residual 52.9%** (§7) if the gate does not pass.
- **The 6% pace cost is a trade only Jay can price** — cleaner audio against later cues and a slower scene.
- Carried: the other cues' PLAN boundaries (P4.27 §8); the 6-byte headroom; the disk's 18-of-18 granules;
  the `LOADM` ceiling; gameplay's colour mode; the per-cue control policy; the HAL audit; the stale
  `pop.link` stack comment; `Demo` unbuilt.

### 9 — User interaction during task

None during this task. The dispatch carries Jay's ruling (*"keep the stack blast, chunk it between rows"*)
and his P4.27/P4.28 observations.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-20-a-metric-whose-meaning-the-fix-changed.md` — committed and pushed.

### 11 — Commit

`44af104` (pushed to origin/wip before this report) + this report.
