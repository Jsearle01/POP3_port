## Form B Report — P4.28 — the blitter holds the music interrupt off for **2.5 note periods**

**Class:** recon.  wip.  **Prod unchanged — no `src/`, no asset, no build input touched.** Two new harness
tools (one of them a labelled failure). Karateka untouched; `main` untouched (`34e93e0`).

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-20 17:54 (HEAD `bfc7728` at receipt, wip; `fd32e76` at report). Tree clean apart from the modified
`dist/mame-cfg/rgb/coco3.cfg` carried since P4.19 and the pre-existing untracked files.

### 1 — Summary

**Jay:** *"terribly low quality, sounds muffled and indistinct not like the oracle … the first song played
after the scene displays is the worst sounding."*

| | |
|---|---|
| **the symptom, measured** | **81% of the cutscene's pulse periods deviate >5% from the previous one, against 11% in the intro** (§3B) |
| **★★★ the cause, confirmed** | **`blit_cel` masks IRQ+FIRQ for a median 15.1 ms — 2.5× the note period — across 82.5% of the scene's wall clock** (§3C) |
| **the control** | **the intro does ZERO cel blits.** That is why P4.19's gate was clean and told us nothing about the scene |
| **a lead raised and KILLED** | the wrong music set — `MASTER.S:112-126` puts `s_Princess`…`s_Magic` in **Set 1**, the same set as the intro's (§3A) |
| **★★ the fix is NOT a flag flip** | the blitter uses **S as the blast destination**; any interrupt pushes onto the framebuffer (§3E) |
| **★★★ a second consequence, UNVERIFIED** | the same `orcc` masks **IRQ**, and the frame counter is IRQ-driven — a candidate cause for P3.87's accepted 19% pace slip (§8) |

### 2 — Files modified

- `harness/tools/pulse_jitter.lua` — **NEW.** The DAC pulse train's period stability, intro vs scene.
- `harness/tools/blit_mask_window.lua` — **NEW.** The masked interval, bracketed on `bc_saved_s`.
- `harness/tools/firq_latency.lua` — **NEW, and it is a LABELLED FAILURE** kept on purpose (§3F).

### 3 — Reasoning

#### 3A — the lead I raised and killed before bringing it

P4.19's own 25.3 line records the song page as generated from **`MUSIC.SET1`**, and P4.23 records that *"the
ids OVERLAP between sets."* So the cutscene resolving id 7 against the intro's table was the obvious
candidate — and it would have retro-explained Jay's P4.23 note *"his entry music is wrong"* as literal
rather than as timing.

**`MASTER.S:112-126` disproves it:**
```
* Set 1 (title)
s_Presents = 1 … s_Sumup = 5
s_Princess = 7   s_Squeek = 8   s_Vizier = 9   s_Buildup = 10   s_Magic = 11
```
**The cutscene's songs ARE Set 1.** Set 2 is the epilog. The port plays the right data, so the defect is in
rendering. ★ *One command, and it saved a dispatch aimed at the wrong thing.*

#### 3B — the symptom, measured rather than characterised

`msys_player.s` states the unit: *"SEGMENT — one FIRQ. One full square-wave period of the note. The pulse
fires here."* So **the interval between DAC pulse-opens (`$FF20`, non-zero write) IS the note's period**, and
an interrupt that cannot be taken on time stretches exactly that interval. Two windows, **same run, same
player, same song page**:

| | INTRO `s_Presents` | SCENE `s_Princess` |
|---|---|---|
| pulses / 3.0 s | 1040 | 493 |
| mean period | 2881 µs (347 Hz) | 6051 µs (165 Hz) |
| **>5% off the previous** | **11.4%** | **81.1%** |
| **>25% off the previous** | **9.1%** | **76.4%** |

**★ TWO HONEST CAVEATS ON THESE NUMBERS.** The >5% metric counts genuine **note changes** too — that is most
of the intro's 11.4%, and it is why the intro's "worst single deviation" reads as an absurd 3730% (a short
note followed by a long one). **The distribution is the signal, not the worst case**, and 81% cannot be note
changes. Second, **the pulse-count difference is not lost interrupts**: 1040 × 2881 µs and 493 × 6051 µs both
fill the 3-second window exactly. It is pitch.

#### 3C — ★★★ THE CAUSE, BRACKETED ON ONE VARIABLE

`blit_cel` opens `pshs cc / orcc #$50 / sts bc_saved_s` and closes `lds bc_saved_s / puls cc`. **`$50` masks
IRQ *and* FIRQ**, and the music is FIRQ-driven [`char_draw.s:2220`]. So the write and the read of
`bc_saved_s` (`$3AD7`) bracket precisely the region where the interrupt cannot be taken — **both are DATA
accesses, so no opcode-fetch question arises at all.**

```
## INTRO  s_Presents
   NO DATA (0 brackets, 1040 pulses)
## SCENE  s_Princess
   blits (masked brackets)   238
   mean note period          6050.7 us   (from the pulse train)
   masked  median            15144.9 us
           90th              19199.7 us
   TOTAL masked in window    2476.0 ms of 3000 ms  (82.5%)
   blits longer than ONE NOTE PERIOD:  120  (50.4%)
```

**★★ THE INTRO'S ZERO IS THE CONTROL, NOT A FAILURE.** The intro does no cel blitting — its songs play over
static screens and whole-screen unpacks. **That is precisely why P4.19's gate was clean, and precisely why it
could not have caught this:** the player was validated on a machine that was not drawing.

★ **Three `lds bc_saved_s` sites exist** [`blit_core.s:290,311,424`]; the two inner ones restore the real
stack mid-routine without ending the mask. The tool takes the **last** read before the next write as the
close and reports its own event counts, so that assumption is visible rather than buried.

#### 3D — the hole in my own lead, and why it dissolved

I flagged one before measuring: *`s_Princess`'s beat is a pinned-only hold where `ch_anymove` skips the peel,
so it should be the cheapest drawing in the scene — if masking were the whole story the worst audio would
land on the busiest beat.*

**The peel is not the drawing.** `room_loop` runs `flicker`, `chars_frame` and `room_present` **every pass at
the flame rate, in every beat**; skipping the peel does not stop the per-frame character blit or the torches.
So the objection was about the wrong thing and does not argue against `blit_core`. ★ *Recorded because I
raised it, and an objection quietly dropped is worse than one that was never made.*

#### 3E — ★★ WHY THIS IS NOT A ONE-LINE FIX

`blit_core.s:277` states the constraint: *"(jsr, rts, pshs of the return, an interrupt) is unsafe inside a
blast."* **S is the blast destination** — that is what makes the `pshs` blast fast — so **any** interrupt
taken mid-blast pushes onto the framebuffer. On the 6809 even FIRQ pushes PC and CC. **Unmasking without
changing the blast corrupts the picture.**

So the routes are design changes with costs to measure, and both are Jay's:
1. **Chunk the blast** — brief unmask windows between rows. Costs cycles per row **in the port's hottest
   code**.
2. **Move the destination off S** — loses the `pshs` primitive the blitter was built around.

**Not attempted.** ★ *Touching the blitter off a confirmed diagnosis and an unmeasured cost is the exact
sequence that produced this week's two reverts.*

#### 3F — the broken instrument, kept and labelled

**`firq_latency.lua` was the first attempt and it is wrong.** It paired each pulse with the timer reload that
followed it, assuming the handler reloads every time; `msys_player.s:347` says otherwise — *"emit the pulse,
return. The tick work is in the PAD and never runs here."*

**It announced itself**, which is the only reason it cost minutes rather than a dispatch: the fitted tick came
out **162 µs/count** (no GIME tick is that), the "expected period" was **4× what P4.28 had measured
directly**, only **59 of ~1040** pulses paired, and the scene window was **empty**. ★ *Its numbers were
discarded, not reported.* It is committed with the failure in its own header so the next reader does not
re-derive it, and `blit_mask_window.lua` reports its own event counts for the same reason.

#### 3G — §2H's three checks

1. **A second mechanism?** ★ **Yes, and §8 carries it.** `orcc #$50` masks **IRQ as well as FIRQ**, and
   `time.s:135` records that *"hal_vbl_handler increments hal_frame_lo on each VBL IRQ."* So the same mask
   that breaks the music also gates the **frame counter the animation paces off**.
2. **The calling routine.** `blit_cel` is called from `chars_frame` and `flicker` via the bundle's
   `BLIT_TAB`, from `room_loop`, **every pass** — the caller is what makes 238 brackets in 3 seconds, and the
   line number alone would not have shown that.
3. **Prior-report grep** (`blit_core|FIRQ|orcc|msys`): P3.21, P3.72k, P4.5, P4.19, P4.21, P4.23. **No
   contradiction**, but one gap worth naming: **P4.19's gate is the only operator ruling the player has, and
   it was taken in the intro.** Its own §25.3 says so. Nothing since has re-gated it against drawing.

### 4 — Verification

- **The symptom** — `pulse_jitter.lua`, two windows in one run (§3B).
- **The cause** — `blit_mask_window.lua`, bracketed on `bc_saved_s`, with the intro as a zero-blit control
  (§3C).
- **The song data exonerated** — `MASTER.S:112-126` (§3A).
- **Suites** — **NOT RE-RUN, deliberately:** no build input touched. Last green at `2c8c101`, `ALL PASS` with
  `integ` at 128 KB.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output, verbatim** — §3B's and §3C's blocks, and:
```
# ★ THE VERDICT LINE
# The INTRO window produced no brackets, which is EXPECTED — the intro does no
# cel blitting at all. That absence is the control, not a failure.
# The scene masks 82.5% of its wall clock, and 120 blits run longer than a
# whole note period. A FIRQ that cannot be taken until after the next one was
# due cannot produce the note it was for.
```

**25.2 bundled-artifact grep:** N/A — no sibling-import artifact.

**25.3 operator-runtime-smoke: N/A — nothing changed to observe.** ★ *The finding this dispatch investigates
IS an operator observation, recorded verbatim in P4.27's §5 and carried here in §1.*

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING. This report contains** the symptom measurement, the confirmed cause, the killed
set-hypothesis, the dissolved hole in my own lead, and the labelled broken instrument. **It contains no code
change** — the dispatch was *"do 1"*, a measurement, and it stayed one.

**★ I PROPOSED TWO ROUTES AND RAN ONLY THE ONE JAY PICKED.** I offered (1) measure the masked interval and
(2) A/B with the character draw suppressed, and recommended (1). **(2) was not run** and is not needed now
that (1) came back positive — but it remains the way to apportion blame between the character blits and the
torches, which this dispatch does **not** separate.

### 7 — Uncertainty flags

- **★★ THIS DOES NOT APPORTION THE MASKING between the character blits and the torch flicker.** Both go
  through `blit_cel`; 238 brackets in 3 s is all of them together. If the fix is to be scoped to one, that
  split has to be measured first.
- **The median masked interval (15.1 ms) exceeds the mean (10.4 ms)**, which means a long tail of SHORT
  brackets — many small blits plus a few large ones. **I have not characterised the distribution's shape**
  beyond the quantiles reported, and the 90th and the worst are identical (19,199.7 µs), which may be a real
  repeated cel or may be an artefact of the bracket-closing rule (§3C's "last read" assumption).
- **The 82.5% is of WALL CLOCK inside the 3 s window**, not of frames, and it is one window in one run.
- **§8's IRQ/pace hypothesis is UNVERIFIED** and is stated as a hypothesis.

### 8 — Follow-up candidates

- **★★★ THE MASK ALSO GATES THE FRAME COUNTER, AND THAT MAY BE P3.87's PACE SLIP.** `orcc #$50` masks **IRQ**
  as well as FIRQ; `time.s:135` says the VBL IRQ handler is what increments `hal_frame_lo`; the animation VM
  paces off `HAL_time_frame_count`. **A masked stretch of ~15 ms against a 16.7 ms frame sits right at the
  boundary where a second VBL inside one mask is lost.** A frame counter that under-counts makes everything
  paced on it run **slow** — and **P3.87 measured the port's animation ~19% slow and Jay closed it by
  decision rather than by a fix.** ★ *STATED AS A HYPOTHESIS, NOT A FINDING. It is cheap to test: count VBL
  IRQs taken against frames elapsed, in the same two windows.* If it holds, one defect explains both the
  music and the pace.
- **Apportion the masking** between character blits and torches (§7) before scoping any fix.
- **The two fix routes** (§3E) — chunk the blast, or move the destination off S. **Jay's ruling**, and each
  needs its cost measured in the port's hottest code before it is chosen.
- Carried: the other cues' PLAN boundaries (P4.27 §8); the 6-byte headroom; the disk's 18-of-18 granules;
  the `LOADM` ceiling; gameplay's colour mode; the per-cue control policy; the HAL audit; the stale
  `pop.link` stack comment; `Demo` unbuilt.

### 9 — User interaction during task

- Jay: ***"the sound before the hourglass drop is terribly low quality, sounds muffled and indistinct not
  like the oracle"*** — the opening report.
- Jay: ***"you need to go back further. the first song played after the scene displays is the worst
  sounding"*** — a correction to my scoping; I had anchored on `s_Buildup`, and the target is `s_Princess`.
- Jay: ***"do 1"*** — this measurement, chosen from the two I offered.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-20-a-component-gated-in-a-quiet-environment-is-untested.md` — committed and pushed.

### 11 — Commit

`8a84932` (the symptom) and `fd32e76` (the cause), both pushed to origin/wip before this report.
