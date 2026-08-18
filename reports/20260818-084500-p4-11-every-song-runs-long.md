## Form B Report — P4.11 — every song runs LONG, and the six of them have nowhere to live

**Class:** recon (measurements taken; §2 NOT executed).  wip.  Prod unchanged — no `src/`, no
`build.bat`, no shipping disk.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-18 08:45 (HEAD `b329feb`, wip).

### 1 — Summary

**§1's measurements were taken and they stopped §2.**

**Every one of the six songs runs LONGER than the oracle's rendition** — not one runs short. That is
**HARD-STOP 2 verbatim** (*"A rendition runs LONG past its beat → report the number and STOP"*), and
the three remedies the dispatch lists — cut mid-phrase, overrun the beat, or re-time — are named
there as Jay's.

**And there is a second blocker the dispatch did not anticipate: the songs have no home.** The
intro's `prog` section ends at **`$1D4F`** against a measured LOADM ceiling of **`$2488..$2535`** —
about **1,840 bytes free, against a largest song of 2,590 B decompressed.** §2 is not "replace a stub
body"; it needs a disk-residency decision first.

**§1.3 was not taken** — its own condition was *"only if it falls out of work already being done"*,
and it did not.

### 2 — Files modified

None.

### 3 — Reasoning

#### 3A — ★★★ DRIFT, PER SONG, ON THE FULL CAPTURES (AC1, AC2)

**The +0.36% on record is superseded.** It came from P4.6a, on the 6.5 s fragment, and the dispatch
is right that drift is exactly the quantity a short window cannot bound.

| song | intended | emitted | drift | | frames | plan |
|---|---|---|---|---|---|---|
| `s_Princess` | 12,724.4 ms | 12,748.5 | **+24.1 ms** | **+0.189%** | 764.9 | 761 |
| `s_Squeek` | 1,138.3 | 1,142.3 | **+3.9** | +0.346% | 68.5 | — |
| `s_Vizier` | 5,864.6 | 5,887.5 | **+22.9** | +0.391% | 353.3 | 358 |
| `s_Buildup` | 6,449.7 | 6,481.1 | **+31.3** | +0.486% | 388.9 | — |
| **`s_Magic`** | 1,859.2 | 1,893.8 | **+34.6** | **+1.864%** | 113.6 | — |
| `s_StTimer` | 4,837.3 | 4,842.7 | **+5.5** | +0.113% | 290.6 | — |
| | | | **+122.4 ms total** | | **≈ +7.3 frames** | |

**★★ THE SIGN IS THE FINDING, AND IT IS SYSTEMATIC.** Six songs, six positive drifts, spanning a
10× range in magnitude. This is not noise around zero — it is **the same rounding bias P4.6a found
and Jay ruled inaudible at 0.69%**, reappearing as a *duration* rather than a pitch. The periods
cluster; clustered values round the same way; the error accumulates instead of cancelling.

**★ `s_Magic` is the outlier at +1.86%** — five times the next worst. It is also the song P4.8 found
least compressible (1,030 B from 1,974 B, ratio 0.52) and densest per second (967 segments in 1.86 s).
**Whatever makes it dense makes it drift.**

#### 3B — what a long rendition does at the beat boundary (AC2)

**The port's `play_song(A=song, X=frames)` spends X frames.** With the music longer than X, there are
exactly the three outcomes the dispatch names, and **all of them are audible or visible**:

| | what happens | cost, worst song |
|---|---|---|
| **cut at X** | the FIRQ is torn down mid-phrase | a truncation ~2 frames from the end, plus whatever a mid-pulse DAC park sounds like |
| **overrun** | the beat waits for the song | **+2.1 frames on `s_Magic`, +7.3 across the intro** — every later beat shifts |
| **re-time** | X is set from the *measured* length, not the oracle's | the port's beats stop matching the traced durations that P4.7b just validated to within 2% |

★ **The third is the interesting one and it is not free:** re-timing makes the audio right and puts
the port's beat durations permanently out of agreement with the frame-counted traces — **the very
cross-check that caught P4.4's fragment.** Adopting it means giving up an independent check.

**+7.3 frames over a ~90 s intro is 0.13%.** *I am not going to call that negligible on Jay's behalf;
it is a twelfth of a second of accumulated slip and he has ruled on smaller things.*

#### 3C — ★★ THE SECOND BLOCKER: THE DATA HAS NOWHERE TO LIVE

| | |
|---|---|
| intro `prog` | loads at `$0200`, **length 6,991 → ends `$1D4F`** |
| LOADM ceiling | **`$2488..$2535`**, measured at P3.22; `$2480` is the practical limit |
| **free** | **≈ 1,840 B** |
| largest song | **2,590 B** decompressed / 1,030 B compressed |

**The largest single song does not fit, let alone six.** And `lz_unpack` expands **in place into a
destination the caller owns** — it has no small-window mode (P4.8 §3C), so "keep it compressed and
decode on demand" needs a 2,590 B destination anyway.

**The established route is in `link/pop_engine.link`'s own note:** *"put the code on a disk-resident
track and reach it through a fixed table, the way the cutscene bundle does"* — arrived at three times
the hard way. **So §2 requires a track allocation, a per-beat load, and a decision about when that
load happens relative to the beat.** That is an architecture step, not a wiring step, and pairing it
with §3B's choice is one decision, not two.

#### 3D — the model behind §3A, stated as what it is

**★ These are ASSEMBLED figures, not EXECUTED ones.** Each song's emitted duration is computed as
`Σ rows (n × ticks × 63.695 + latency_adv + (n−1) × latency_steady)` from the packed table, using the
two latencies measured on the bus at P4.6.

**The model has been validated once against the machine** — P4.6b's full-length build predicted a
36,566.8 ms sounding span and the `$FF20` tap measured **36,566.1 ms, −0.002%**. That is strong, and
it is still one validation of a model rather than six measurements of six songs. *Counted ≠ assembled
≠ executed, and these are the middle one.* **Confirming `s_Magic` on the machine is one build and one
run, and it is the first thing I would do if §2 resumes.**

### 4 — Verification (AC-by-AC)

- **AC1 drift re-measured per song, +0.36% superseded** — PASS (§3A), with the tier stated (§3D).
- **AC2 long-rendition case, per-song sign and magnitude** — PASS (§3A/§3B). **All six long.**
- **AC3-AC6 wiring, hold cost, scenery, abort** — **NOT DONE. HARD-STOP 2 fired** (§1), and §3C is a
  second, independent blocker.
- **AC7 PLAN-duration assert permanent** — **NOT DONE.** It exists in `song_size_census.py` from
  P4.7; making it a build-time gate belongs with the wiring it would gate.
- **AC8 suites** — not re-run: nothing was changed. Last green at 128 KB this session (P4.9).
- **AC9 Jay's ear gate** — **not reached**; §4's three items cannot be surfaced on an unbuilt thing.
- **AC10 route accounting** — §6. Karateka and `main` untouched.

### 5 — Verdict-time evidence (v0.7 §11)

```
song         intended ms  emitted ms  drift ms  drift %  frames  plan f
s_Princess       12724.4     12748.5    24.101    0.189   764.9     761
s_Squeek          1138.3      1142.3     3.934    0.346    68.5       -
s_Vizier          5864.6      5887.5    22.904    0.391   353.3     358
s_Buildup         6449.7      6481.1    31.335    0.486   388.9       -
s_Magic           1859.2      1893.8    34.647    1.864   113.6       -
s_StTimer         4837.3      4842.7     5.476    0.113   290.6       -
                                       +122.4 total  = +7.3 frames, all POSITIVE

Section: prog (build/obj/intro_splash.o) load at 0200, length 6991   -> ends $1D4F
LOADM ceiling measured $2488..$2535 (P3.22)                          -> ~1,840 B free
largest song 2,590 B decompressed / 1,030 B compressed               -> does not fit
```

**25.1:** N/A — nothing built. **25.2/25.3:** N/A — §2 not executed; **the ear gate was not reached.**

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** I proposed nothing in advance. **This report contains §1.1 and §1.2 only.**
**What it does NOT contain, and why, named rather than left to inference:**
- **§2's wiring, §3's verification, §4's gate** — HARD-STOP 2 fired on the first measurement, and its
  three remedies are named in the dispatch as Jay's.
- **§1.3, the `HM` split** — its own condition was "only if it falls out of work already being done".
  It did not, and I did not spend a pass on it.
- **The PLAN-duration build gate (AC7)** — deferred deliberately to sit with the wiring it gates,
  rather than landing a gate on a path that does not exist yet.

**No deviations otherwise.** Nothing in `src/`, `build.bat`, the shipping disk, Karateka or `main`.

### 7 — Uncertainty flags

- **§3A is model-computed** (§3D). One validation on the bus, not six.
- **The drift model assumes the packed table as `pack_song.py` would emit it today**, including the
  count-weighted latency. A change to the packer changes these numbers.
- **`s_Magic`'s +1.86% is unexplained.** It correlates with density and poor compressibility; I did
  not establish the mechanism.
- **The 1,840 B figure is `prog`'s headroom in the INTRO build.** The cutscene links separately
  (`pop_scene.link`, `$2500`) and its headroom was not measured — a song loaded for a cutscene beat
  may have different room available.
- **Nothing here says the drift is audible.** +2 frames at the end of a song may be inaudible, or may
  click on tear-down. **That is exactly what an ear gate would settle, and this dispatch could not
  reach one.**

### 8 — Follow-up candidates

- **Jay's ruling on §3B** — cut, overrun, or re-time. **It gates the wiring.**
- Confirm `s_Magic`'s drift on the machine before acting on it (one build, one run).
- Decide where the songs live (§3C) — disk track + per-beat load, as the cutscene bundle does.
- Then §2 as written: wire six, measure the cost **in a hold**, confirm the scenery stays decoupled,
  wire `song_stop` into the abort and assert no live FIRQ survives.
- Unchanged: the timbre ruling; capture-vs-interpret; `MUSIC.SET*`; P4.9's unverified state-restore;
  the gameplay freeze question.

### 9 — User interaction during task

None during execution.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-18-error-that-cancels-or-accumulates.md`

### 11 — Commit

`08fcd95`  (pushed to origin/wip before this report)
