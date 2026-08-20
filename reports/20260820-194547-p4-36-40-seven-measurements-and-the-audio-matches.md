## Form B Report — P4.36–P4.40 — seven measurements, six hypotheses refuted, **the audio matches**

**Class:** recon.  wip.  **Prod unchanged across this whole arc — no `src/`, no asset, no build input
touched.** Five new harness tools. Karateka untouched; `main` untouched (`34e93e0`).

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-20 19:45 (HEAD `a47d09b`, wip). Tree clean apart from the modified
`dist/mame-cfg/rgb/coco3.cfg` carried since P4.19 and the pre-existing untracked files.

### 1 — Summary

**Jay:** *"continue working on the fuzziness of the princess song."*

| # | hypothesis | verdict | number |
|---|---|---|---|
| P4.36 | the blitter's per-row mask | **12.3%, not 67%** | median 158 µs with a blit vs 76 µs without, **10% of periods** |
| P4.35 | interrupts masked in the big gaps | **refuted** | VBL fires at its normal rate throughout |
| P4.37 | timer quantisation | **refuted** | no comb; **44% of periods identical within 8 µs** |
| P4.37 | pitch instability | **refuted** | held notes exact (~8 cents) |
| P4.38 | duty / amplitude wrong | **refuted** | port **21.3 µs** mean vs oracle **21.2** |
| P4.39 | the output path (DAC vs speaker cone) | **refuted** | above 2 kHz: port **83.2%**, oracle **85.2%** |
| P4.40 | the port sounds where the oracle rests | **refuted, and the comparison was unsound** | port **51% silent** |

**★★★ BY EVERY PROPERTY MEASURABLE ON THE BUS OR IN THE WAVEFORM, THE PORT MATCHES THE ORACLE.** ★ *And Jay
still hears it as fuzzy, which is real information rather than a contradiction — it says the difference is
not any of the seven things above.*

**★★ THE MOST LOAD-BEARING RESULT IS P4.36's**, because it stopped a change: I was one step from
restructuring `blit_core` — the port's hottest code — for a gain that turned out to be 12%.

### 2 — Files modified

`harness/tools/`: `jitter_by_blit.lua`, `jitter_quantum.lua`, `pulse_width_census.lua`,
`spectrum_compare.py`, `silence_ratio.lua` — all NEW. **Nothing else.**

### 3 — Reasoning

#### 3A — ★★★ P4.36: THE CHANGE I WAS ABOUT TO MAKE WOULD HAVE BOUGHT 12%

P4.31 attributed 67% of the residual jitter to `blit_cel`'s per-row mask, and P4.35 called the narrower
window *"the whole of the remaining lever"*. **Neither checked the periods that contain no blit.**

```
  periods WITH a blit    n=171    median 158.1 us   mean 1253.8 us
  periods with NO blit   n=1547   median  76.0 us   mean  520.7 us
  periods with a blit      10.0% of all periods
  ★ BLITTER'S SHARE of total deviation  12.3%
```

A blit **doubles** the deviation in the periods it touches — and touches **one in ten**. Ninety percent have
no blit and still deviate by 76 µs.

**★★ THE ARITHMETIC WAS ALREADY IN MY HANDS.** P4.35's own census reported 0.09 blits per ordinary period —
so ~9% of periods have one. *If the blitter caused the bulk, ~91% of periods would be clean and the median
would be near zero. It was 91 µs.* That contradiction sat inside a report I wrote and I did not do the
division.

**★ AND THE TOOL'S FIRST VERDICT WAS WRONG IN THE SAME DIRECTION:** it printed *"THE BLITTER IS THE CAUSE"*
from a median ratio over 2.0 — true, and meaningless alone, because **a ratio is not a share**. Corrected to
compute excess × population before the number was quoted anywhere.

#### 3B — P4.37: the pitch is not the problem, and the zero spike is why

If the player programmed whole GIME ticks, deviations would sit in **spikes** at 0/64/127/191 µs.
Latency smears; quantisation combs. **No comb** — excluding the zero bin, 44% land near a whole tick,
*below* the ~50% a smooth distribution gives.

**★★ THE ZERO SPIKE IS THE FINDING: 1233 of 2803 blit-free periods (44%) are IDENTICAL to their
predecessor within 8 µs** — 0.5% of a 1743 µs period, ~8 cents, under the 12 cents Jay ruled inaudible at
P4.6. **Held notes render essentially perfectly**, and the smear sits at period *changes* — which is what a
**note change** looks like from outside. ★ *The same trap as P4.35's rests: `pulse_jitter` compares
consecutive periods, so the composition scores as jitter.*

#### 3C — P4.38–P4.39: the duty and the spectrum match

`msys_player.s:59-64` records three oracle mechanisms as deliberately unported under §2I, with the claim
*"they are not missed: the output is the same pitch and the same duty."* **Both halves are now tested.**

| | port | oracle |
|---|---|---|
| pulse width range | 8.4 … 22.3 µs | 7.8 … 22.5 µs |
| **pulse width mean** | **21.3 µs** | **21.2 µs** |
| energy above 2 kHz | **83.2%** | **85.2%** |

The port's 4-value alphabet with 89% at maximum **looked** like collapsed dynamics; the oracle's own trace
shows the same shape (long runs at one width, mean 21.2 against max 22.5). **It is faithful.**

**★ AND MY OUTPUT-PATH HYPOTHESIS IS REFUTED BY ITS OWN TEST.** I argued the port should be harsher because
a 6-bit DAC at line level does not integrate a 1.3%-duty pulse the way a speaker cone does. **The port is
marginally DARKER in every audible band.** The only large gap is 16–24 kHz (10.3% vs 0.0%), beyond hearing
and almost certainly MAME's Apple speaker model low-passing.

#### 3D — ★★ P4.40: refuted, and built on a number the instrument could not see

The port rests **more** than the oracle figure — 51% against ~22% — so *"it sounds where the oracle rests"*
is refuted in its direction.

**★★★ BUT THE COMPARISON WAS NEVER SOUND AND I SHOULD HAVE SAID SO BEFORE RUNNING IT.** The oracle's 22% was
**derived** from its speaker capture's pulse/segment pairing — and **a silent segment emits no speaker toggle
at all**, so the oracle's segment count is *precisely the quantity that capture cannot see*. I built a
measurement against a number produced by an instrument blind to it.

**What is solid is better than what I was looking for:** 3635 sounding segments against **3635 silent runs of
mean length 1.0** is a strict **alternation** — sound, silent, sound, silent. Not articulation between notes:
**the harmonic pattern shaping the waveform**, which `gen_msys_tables.py` names outright (*"The default
pattern is `1,3,128`: silent, sound"*).

#### 3E — ★★★ THREE THRESHOLDS WRITTEN BEFORE THE SCALE THEY THRESHOLD

Recorded together because three instances in one arc is a pattern, not luck:

| tool | threshold | why it was wrong |
|---|---|---|
| `pulse_gap_census` | "gap > **1000 µs**" | the mean note period is **1743 µs** — it censused ordinary notes as gaps |
| `jitter_by_blit` | "median ratio > **2.0** ⇒ the cause" | a ratio ignores that only 10% of periods qualify |
| `silence_ratio` | "silent > **16%** ⇒ about the same" | **51% against 22%** is not "about the same" |

★ *Each was written before its quantity had been measured, and each produced a confident wrong sentence in a
log. Two were caught by absurdity (200 "big" gaps against 42 ordinary ones is not a plausible pulse train);
one was caught only by doing the arithmetic by hand afterwards.* **The rule is small: a threshold in absolute
units cannot be written before the scale it thresholds is known** — derive it from the data or state it as
provisional in the output. Captured (§10).

#### 3F — §2H's three checks

1. **A second mechanism?** ★ **The arc is nothing but this check applied seven times.** Each refutation was a
   candidate that was real (the blitter *does* delay interrupts; the timer *does* quantise) and not
   governing.
2. **The calling routine.** The 91 µs bulk is not attributable to any caller — it is present in periods where
   nothing but the player ran, which is what eliminates contention as a class.
3. **Prior-report grep** (`pulse_jitter|blit_core|msys|duty`): P4.4, P4.5, P4.19, P4.28–P4.31, P4.35.
   **Two corrections to my own reports**, both made here: P4.31's two-cause split (§3A) and P4.39's
   output-path hypothesis (§3C).

### 4 — Verification

Every number above is from a fresh run on the current build, at 128 KB, live-disk. **No suite was re-run and
none needed to be: no build input changed in this arc.** Last green at `b4d8160`, `ALL PASS` with `integ`.

### 5 — Verdict-time evidence (v0.7 §11)

```
  periods with a blit  10.0% of all   |   BLITTER'S SHARE of total deviation  12.3%
```
```
     0 us ########################################  1233     <- 44% identical within 8 us
    56 us #                                           35     <= 1 x tick   (no comb)
```
```
  PORT   n=3635  range 8.4 .. 22.3 us  mean 21.3      ORACLE  n=2841  7.8 .. 22.5  mean 21.2
```
```
  above 2 kHz    83.2%      85.2%      -2.0
```
```
  segments 7420   sounding 3635 (49.0%)   SILENT 3785 (51.0%)   runs 3635, mean 1.0
```

**25.3 operator-runtime-smoke: N/A for this arc — nothing changed to observe.** The port and the oracle were
each played for Jay at his request (200 s at 99.93%, and the oracle after it); **no verdict has been given
and none is recorded.**

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING. I proposed the narrower blit window in P4.29 §8 and again in P4.35 §8, and this arc
CANCELS it** — §3A sizes it at 12%. **It is not built, and the reason it is not built is the measurement, not
a change of mind.**

**This arc contains** seven measurements and five tools. **It contains no code change of any kind.**

**★★ TWO OF MY OWN PRIOR CONCLUSIONS ARE WITHDRAWN HERE:** P4.31's "two causes, 67/8" (§3A) and P4.39's
output-path hypothesis (§3C) — the latter refuted by the very test I designed for it.

### 7 — Uncertainty flags

- **★★ THE FUZZINESS IS UNEXPLAINED.** Seven suspects eliminated is not a diagnosis. What it establishes is
  that the difference is **not** any of them — which is worth having, and is not an answer.
- **Every measurement in this arc averages over a whole song.** A systematic *per-note* difference would
  survive all seven. That is the strongest remaining structural gap and it drives §8's first item.
- **The oracle-side silence figure is unusable** (§3D) and should not be quoted.
- **`s_Squeek` / `s_StTimer` hold lengths** and the 1.20× pace remain open from earlier dispatches.

### 8 — Follow-up candidates

- **★★★ ISOLATE ONE NOTE — recommended, and cheap.** Play a single sustained note on both machines and
  compare the waveforms **sample by sample** rather than statistically. ★ *Six of the seven measurements
  above are whole-song statistics, and a per-note difference is exactly what they cannot see. If one note is
  clean, the problem is between notes and the search changes completely.*
- **★★ CHANGE THE MECHANISM (§2I) — Jay's ruling, not mine to take.** The CoCo3 has a **6-bit DAC** where the
  Apple has one bit. The port faithfully reproduces **a workaround for hardware it does not have**: PWM
  exists because a 1-bit speaker is all the Apple had. Emitting the amplitude as a *level* is a different
  mechanism for the same intended output. ★ *This is the largest available change and the only one not yet
  ruled out by measurement.*
- **Accept it.** The port measures equivalent on every axis; "a bit crappy" may be the honest cost of the
  design as ported.
- Carried: P3.87's pace (1.20×); the 6-byte headroom; the disk's 18-of-18 granules; the `LOADM` ceiling;
  `start_col` vs §2F.1(5); gameplay's colour mode; the per-cue control policy; the HAL audit; the stale
  `pop.link` stack comment; `Demo` unbuilt.

### 9 — User interaction during task

- Jay: ***"continue working on the fuzziness of the princess song"*** — this arc.
- Jay: ***"yes"*** ×4 — to each proposed next measurement in turn.
- Jay: ***"play the port for me"*** / ***"play the oracle"*** — both launched; no verdict given.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-20-a-threshold-written-before-the-scale-it-thresholds.md` — committed and pushed.

### 11 — Commit

`d7b9817`, `f24e54f`, `9ab60a0`, `a535afb`, `3f0841f`, `a47d09b` — all pushed to origin/wip before this
report.
