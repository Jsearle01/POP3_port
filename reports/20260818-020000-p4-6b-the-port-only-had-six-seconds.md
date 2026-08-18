## Form B Report — P4.6b — "3 different pieces": the port only ever had 6.5 seconds

**Class:** build.  wip.  Prod unchanged — `build/probe.dmk` still 6 files / 36,673 B / 13,824 B free.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-18 02:00 (HEAD `3befcb5`, wip). Follow-through on Jay's timbre report, not a dispatch.

### 1 — Summary

Jay, on the port-vs-oracle comparison: **"the song played is not the same between the oracle and
the port. part of it is but not all of it. the port sounds like the same piece repeated 3 times.
the oracle sounds like 3 different pieces."**

**He is right, and the loop was not the bug — the port only HAD 6.5 seconds.** P4.4 captured a
400-frame window off the oracle's speaker; P4.5 built a slice on it; P4.6 measured and tuned that
slice to within half a percent; P4.6a retired a feature on it. **Four dispatches of increasingly
careful work on 15% of the piece**, and every automated check passed at every step, because none
of them knew how long the music was supposed to be.

The capture is now 5,400 frames. **42.5 seconds, cut where the music itself stops** — on a
six-second rest. Two things the short window had never exercised turned up immediately: **rests
longer than the timer can express**, and **silence at all**. The cost *fell* to **2.0%**.

### 2 — Files modified

- `content/sound/princess_cutscene_speaker_pairs.txt` — NEW, replaces the 6.5 s capture. 18,332
  segments over 90 s, whole and untrimmed.
- `harness/tools/pack_song.py` — long rests become TRAINS of silent rows; `--max-seconds`; reports
  the sounding span separately from the total.
- `src/harness/song_probe.s` — `width 0` is a rest and emits nothing.
- `build.bat` — `SONG_CUT=37.6`; the new capture.
- `harness/smoke/run_song_check.sh`, `run_song_wav.sh`, `run_song_slice.sh` — windows and text
  sized for a 42.5 s song rather than a 6.5 s one.

### 3 — Reasoning

#### 3A — what he heard, and why it took a human to see it

The oracle WAV he compared against ran from 39.7 s; the arm point is 44.7 s; he heard to 67.5 s.
In capture-relative terms that is 0 → 22.8 s, and **the measured gap structure in that range is at
12.7 s, 15.1 s and 22.3 s — three chunks. "3 different pieces" is exactly right, and it is in the
data.** The port had the first 6.5 s of the first chunk, looped.

★ **Nothing in the harness could have caught this, and it is worth being precise about why.** Every
check compares the port against **the captured stream**. The captured stream was the defect. *A
measurement can be internally perfect and still be of the wrong extent, and no amount of comparing
the artifact to it will say so.* The only signal available was someone who knew what the piece
sounds like. **That is the second time in three dispatches that the human found what the
instruments could not, and both times the instrument was measuring faithfully.**

#### 3B — two mechanisms the 6.5 s window had never exercised

**§2H, and this time the "second mechanism" was an absence.**

1. **Rests longer than 261 ms.** The GIME timer tops out at 4,095 ticks; the full cutscene contains
   rests of up to **6 seconds**. The packer's response to an over-ceiling value was to CLAMP — which
   on the old data fired zero times, and on the new data would have turned a six-second silence into
   a quarter of a second and sheared the piece apart. Long segments now become a **train**: one
   sounding row carrying the pulse, then silent maximum-length rows for the remainder. 7 rests were
   split; 61 silent rows.
2. **Silence itself.** `width 0` had no meaning — `ldb #0` falls into the delay loop and counts 256
   iterations, i.e. **the longest pulse in the table, exactly where the music wants none**. The
   handler now branches on it (3 cycles on every sounding segment).

Neither is an edge case in the real material; both were unreachable in the sample.

#### 3C — the envelope is much richer than the sample suggested, which revises P4.6 §3C

P4.6 reported **four** distinct pulse widths and concluded the `HM1..HM29` envelope was "already in
the data". The conclusion holds — but the evidence was thin, and it was thin in a way I called
sufficient. The full piece uses **24 distinct widths**, 8.4 µs to 282 µs:

```
2=8.4  4=14.0  5=16.8  7=22.3  9=27.9  11=33.5  12=36.3  14=41.9  16=47.5  18=53.1
19=55.9  23=67.0  26=75.4  28=81.0  30=86.6  33=95.0  37=106.2  44=125.7  51=145.3
54=153.7  58=164.8  72=203.9  75=212.3  100=282.2      (microseconds emitted)
```

**"Four widths and none varies within a held note" was a fact about 6.5 seconds that I reported as
a fact about the song.** The amplitude does vary, considerably, and the port reproduces all of it —
but P4.6's confidence in that section was borrowed from a sample that could not support it.

#### 3D — the cost FELL, and the reason is the sample again

**+598 cyc/frame = 2.0%**, at **6.39 interrupts/frame** and **94 cycles per interrupt** — against
4.4% and 10.03 interrupts/frame on the 6.5 s window. **The opening is the fastest part of the
piece.** Every cost figure in P4.1–P4.6a was taken on it, so every one of them was an upper bound
presented as an average.

*One flag rather than a reassurance:* the widest pulse is **500 cycles inside a single FIRQ**
(1.7% of a frame, in one interrupt). Here the foreground is a VBL wait and it does not matter.
**Against a renderer it is a latency spike, not a throughput cost, and throughput is all that has
been measured so far.**

#### 3E — the metric that read −14% on a correct song

The first full-length run reported **−14.07%** duration. It was the metric: the cut lands on a
6 s rest, and the `$FF20` tap measures **first pulse to last pulse**, which cannot span a silence
that emits nothing. `pack_song.py` now reports the **sounding span** separately from the total —
36,566.8 ms predicted against **36,566.1 ms measured, −0.002%.**

*Recorded because a −14% that turns out to be the ruler is exactly the shape that gets "fixed" in
the wrong place.*

### 4 — Verification

- **The full song plays** — `runs consumed 2086`, `FIRQ entries 9869`, `magic $504E`, PASS.
- **Tuning holds over the whole range** — sounding span −0.002%; the latency constants measured on
  the 6.5 s window still hold across 24 widths and 134 tick values (steady +128.10 µs = 2.01 ticks,
  adv +197.58 µs).
- **Cost** — +598 cyc/frame = 2.0%, 94 cyc/interrupt at 6.39 interrupts/frame.
- **Suites, 128 KB** — `introseq` PASS, `integ` PASS. Shipping disk unchanged; `SONG.BIN` (11,900 B)
  goes on a run-time copy — **which has 13,824 B free, so this fits with 1,924 B to spare.**
- **WAVs regenerated at comparable length** — port 37.2 s (one pass, no loop), oracle 52.9 s.

### 5 — Verdict-time evidence (v0.7 §11)

```
[pack_song] song_a: 9809 segments -> 2086 runs (10432 B) -> build/gen/song_a.s
[pack_song]   period error mean |0.919%| signed +0.045% worst 7.711%; 42553.1 ms total, 36566.8 ms sounding
[pack_song]   9809 of 18332 captured segments; 61 silent rows; 7 long rest(s) split into trains
  build/song_probe.bin (11900 bytes)
=== BUILD COMPLETE ===

# runs consumed 2086   FIRQ entries 9869   magic $504E (want $504E)
# PASS — it loaded, played to the terminator and tore the FIRQ down.
# ★ FIRQ RATE, MEASURED: 6.39 interrupts/frame over 1545 frames
#   THE PLAYER COSTS +598 cyc/frame = 2.0% of the VBL budget
#   -> 94 cycles per interrupt, at 6.39 interrupts/frame
#     steady  n=7736  mean +128.10 us  = 229 cyc, 2.01 ticks
#     adv     n=2036  mean +197.58 us  = 354 cyc, 3.10 ticks
#   ★★ TOTAL EMITTED DURATION 36566.1 ms vs 36566.8 ms = -0.00%

[suites] -ramsize 128K
[run_introseq_test] PASS
[integ] PASS
[suites] ALL PASS

[wav_trim] port_princess.wav:   95.0s -> 37.2s (20.9..58.0s)
[wav_trim] oracle_princess.wav: 95.0s -> 52.9s (39.7..92.6s)
```

**25.2:** N/A — harness instrument, not on the shipping disk.
**25.3:** **PENDING JAY.** `bash harness/smoke/run_song_slice.sh`, or the two trimmed WAVs.
**The clips do not start at the same instant:** the oracle's begins ~5 s before the arm point and
runs ~10 s past where the port stops, because the port's cut is deliberate. Aligning them is the
listener's job and it should be said rather than implied.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** I proposed nothing in advance here — the report Jay was responding to had
listed *"a song against its beat rather than a 6.5 s capture window"* as an open item, and his
finding is that item arriving as a defect. **This commit contains:** the longer capture, the cut as
a build constant, long-rest trains, `width 0` as a rest, the sounding-span metric, and every runner
resized. **What it does NOT contain:** any change to the tuning constants (they held, and were
re-verified rather than re-fitted); any re-opening of the dither; a decode of `MUSIC.SET*`; the
music past 42.5 s; any change to `main`.

**Deviation:** not dispatched. Jay reported a defect in something he was asked to judge; fixing it
before asking again is the point of asking. **And the raw capture is kept whole** — the cut is
`SONG_CUT` in `build.bat`, so the measurement is not edited to fit the build.

### 7 — Uncertainty flags

- **The cut at 42.5 s is a judgement, not a measurement.** It lands on the longest rest in the
  capture (5.99 s at 36.6 s), which is where the music sounds finished — but the oracle plays on,
  and whether PlayCut0's music *is* those 42.5 s is Jay's call, not mine. **Nothing structural
  marks it; I chose it from the gap histogram.**
- **The worst per-segment period error is now 7.7%**, not 1.2%. It lands on the FAST segments —
  466 of 9,809 (4.8%) exceed 2%, concentrated above 1 kHz where a 63.7 µs tick is a coarse ruler.
  **★ AND THIS RE-OPENS THE TINS HYBRID, for the opposite reason to the one P4.3 assumed:** the
  second clock cannot reach the low band, but it would quantise the *top* of the range to 0.08%.
  Whether 4.8% of segments justify it is an ear question, and it is now a real one.
- **Cost is measured on one pass with an idle foreground.** 2.0% is throughput. The 500-cycle
  worst-case interrupt is not, and nothing has measured what that does to a renderer.
- **`content/sound/princess_speaker_pairs.txt` was deleted**, superseded by the cutscene capture.
  It was one commit old and nothing else referenced it.

### 8 — Follow-up candidates

- **Jay's call on the cut point** — 42.5 s, or further, or shorter.
- The TINS hybrid, re-opened for the high band (§7).
- Re-measure the three constants on real hardware (`nnn+2` is MAME's).
- The 5-byte row still carries a `frac` byte the shipping build ignores: 2,086 bytes and ~10
  cyc/interrupt, kept so the packer and player cannot disagree about the format.
- Unchanged: `MUSIC.SET*` → `loadmusic1/2/3`; the other songs; a song against its beat.

### 9 — User interaction during task

Jay, on the timbre comparison, verbatim and in full: **"for the timbre the song played is not the
same between the oracle and the port. part of it is but not all of it. the port sounds like the
same piece repeated 3 times. the oracle sounds like 3 different pieces."**
**No verdict on timbre was given, and none should be read into this** — he could not reach that
question past the wrong material.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-18-the-sample-was-the-specification.md`

### 11 — Commit

`1bbf069`  (pushed to origin/wip before this report)
