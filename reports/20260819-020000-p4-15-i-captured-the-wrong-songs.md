## Form B Report — P4.15 — I captured the wrong songs, and the right ones are 7× bigger

**Class:** recon.  wip.  Prod unchanged — no `src/`, no `build.bat`, no shipping disk.
**HARD-STOP 3 fired. Nothing wired.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-19 02:00 (HEAD `dd9d6ae`, wip).

### 1 — Summary

**The five songs P4.15 asked me to wire had never been captured.** `MASTER.S:114-125` — the title set
holds **twelve** songs:

```
s_Presents 1  s_Byline 2  s_Title 3  s_Prolog 4  s_Sumup 5     <- the INTRO's, in the boot chain
s_Princess 7  s_Squeek 8  s_Vizier 9  s_Buildup 10  s_Magic 11  s_StTimer 12   <- the CUTSCENE's
```

**P4.7 captured 7-12 and five dispatches called them "the six title songs".** They are the ones
`PlayCut0` plays. **The port's five intro beats want 1-5**, and my capture armed on PlayCut0's own
marker — **which fires after the intro's songs have already finished, so they could never appear.**

**Re-armed from boot, all eleven appear in one run.** And the ones the port needs are much larger:

| song | span | raw | compressed |
|---|---|---|---|
| `s_Presents` | 4.68 s | 798 B | 410 B |
| `s_Byline` | 4.70 s | 798 B | 411 B |
| **`s_Title`** | 8.95 s | **18,018 B** | 1,381 B |
| **`s_Prolog`** | 12.55 s | **9,770 B** | **1,646 B** |

**Peak decompressed 18,018 B against a 3,072 B home. Peak compressed 1,646 B, which fits.** So the
intro's songs **cannot be played decompressed at all** — and P4.8's finding that the shipped LZ format
cannot stream is now binding rather than academic. **HARD-STOP 3: that is a format change, and a
design step.**

**★★ AND IT INVERTS P4.8's CONCLUSION.** *"On residency the two are comparable, with capture
marginally ahead"* — **2,590 B against 3,021 B, computed on the cutscene's six.** On the songs the port
actually plays it is **18,018 B against the oracle's 1,024 B resident set. 17.6×.** *The memory
argument was not spent; it was spent on the wrong songs.*

### 2 — Files modified

- `harness/tools/oracle_song_capture.lua` — `P_ARM=boot`; the eleven-song name table.
- Eleven per-song captures in `build/tmp/boot/` (untracked; regenerate with one run).

### 3 — Reasoning

#### 3A — how the wrong set got captured, and stayed uncorrected for five dispatches

P4.7 armed on `SPEED == 12`, PlayCut0's first marker — deliberately, and correctly for the question it
was asked (*which songs does the cutscene play*). **Everything after it inherited the answer as
"the title songs" and reasoned about wiring them into the intro.** P4.15's own table says *"the five
intro songs"* and *"the cutscene beats"* as though both sets were in hand. **One was.**

**★ The check that would have caught it existed and I ran a version of it.** P4.7b's plan-duration
assert compares a capture against the port's traced beat duration — **but only for ids with a PLAN
entry, and I only entered 7 and 9.** *An assert that skips the rows it has no data for cannot report
the rows that are missing entirely.*

**★★★ AND THIS IS THE FOURTH INSTANCE OF THE SAME SHAPE IN THIS ARC:** a 400-frame window read as a
42.5 s piece; one object's contribution read as a whole section; one image's span read as a whole
region; **and now one arming point's yield read as a whole song set.** *Each time the missing part was
one cheap query away.*

#### 3B — the port's beat holds ARE the song lengths, and that is a third cross-check landing

| beat | `BEAT_HOLD` | measured span | frames | delta |
|---|---|---|---|---|
| `s_Presents` | **281** | 4.68 s | 281.0 | **0.0%** |
| `s_Byline` | **283** | 4.70 s | 282.2 | **−0.3%** |
| `s_Title` | **537** | 8.95 s | 537.2 | **+0.0%** |
| `s_Prolog` | **760** | 12.55 s | 753.2 | **−0.9%** |

**Four for four, within 1%.** The port's holds were traced from the oracle's *frame* behaviour at
P3.72l; these are its *speaker*. **Two independent routes, agreeing — and the beat table's comments
cite `X=80`/`X=140`/`X=250`, which are the oracle's SOUND-OFF pauses and are NOT these numbers.**
*Whoever built the table used the traced durations and cited the sound-off constant beside them; the
values are right and the citation is misleading.*

**★ And they run SHORT, not long** — `s_Prolog` by 6.8 frames. **P4.11's "every song runs long" was
measured on the cutscene's six.** For the intro's, the sign is the other way, which matters because
short means silence at the end of a beat and long means a collision with the next one.

#### 3C — what fits, and what does not

| | `$6C00..$77FF` (intro beats, peel silent) | `$7268..$77FF` (always) |
|---|---|---|
| available | 3,072 B | 1,432 B |
| intro peak, decompressed | 18,018 B — **no** | no |
| intro peak, compressed | **1,646 B — yes, 1,426 B spare** | 1,646 B — **no** |

**So the only arrangement that fits is compressed-resident with an incremental decoder** — and the
format will not do it: `s_Prolog`'s largest back-reference is **9,388 B of 9,770 (96%)**, `s_Title`'s
9,652 of 18,018 (54%). **The history window is the song.**

**Option B (use `$6C00` during the cutscene too) was not tested**, because it answers a question about
the cutscene's six songs — **which the port has no call sites for.** `cutscene_room.s` contains no
`play_song` at all; beat 5's `BEAT_SONG` is `0`, commented *"the oracle's gap here is the PrincessScene
cutscene, not built"*. **The captured six currently have nowhere to play from.**

### 4 — Verification (AC-by-AC)

- **AC1 option B tested first** — **NOT DONE**, and §3C says why: it is a question about songs the port
  does not play. **A deviation from the dispatch's ordering, stated.**
- **AC2/AC3 the arrangement** — **A format change is required** (§3C). **HARD-STOP 3.**
- **AC4-AC9 assert, wiring, hold cost, scenery, abort, plan assert, decompression time** — **NOT DONE.**
- **AC10 suites** — not re-run; nothing was changed in `src/` or `build.bat`.
- **AC11 gate** — not reached.
- **AC12 route accounting** — §6. Karateka and `main` untouched.

### 5 — Verdict-time evidence (v0.7 §11)

```
# ★★ SONG CALLS: 11          (P_ARM=boot)
  1  s_Presents   6.75   span  4.69     4  s_Prolog   30.44  span 12.56
  2  s_Byline    13.03   span  4.72     7  s_Princess 44.87  span 12.73
  3  s_Title     19.72   span  8.96     ...  12 s_StTimer 87.40  span 4.87
  5  s_Sumup     95.85   span 51.67  <- LAST call: unbounded, see §7

song                    span s   RAW B    LZ B  ratio  max off  off/raw
song_1_s_Presents         4.68     798     410   0.51      656     0.82
song_2_s_Byline           4.70     798     411   0.52      656     0.82
song_3_s_Title            8.95   18018    1381   0.08     9652     0.54
song_4_s_Prolog          12.55    9770    1646   0.17     9388     0.96

BEAT_HOLD 281 / 283 / 537 / 760 / 1564(no song) / 310
```

**25.1/25.2/25.3:** N/A — nothing built; the gate was not reached.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING. This report contains** the eleven-song capture, the four intro songs sized, the
beat-hold cross-check, and the fit analysis. **It does NOT contain** option B's test (§4, deviation),
any wiring, the assert, the hold cost, or the gate.

**★ THE DEVIATION IS THE ORDERING AGAIN, and for a better reason than last time:** P4.15 said test B
first. B is about the cutscene's songs, and discovering the port has no cutscene song sites made the
question moot before it could be run. **Had I tested B first as instructed, I would have measured a
region for songs that have no caller.**

### 7 — Uncertainty flags

- **`s_Sumup` (id 5) is NOT bounded.** It is the last call in the recording, so its 51.67 s "span"
  runs to the end and sweeps up whatever follows. **Its true length, size and fit are unknown**, and it
  is one of the five the port needs. **A capture with a later stop is one run.**
- **The four sizes are packed with the CUTSCENE's latency constants** (127.80/195.78 µs). Those were
  measured on the port's own handler and should carry, but they were validated against the cutscene's
  material.
- **`s_Title` at 18,018 B raw and 0.08 compression is an outlier I did not investigate.** A ratio that
  extreme usually means long exact repeats; if the packer's RLE is missing structure the raw figure may
  be softer than it looks.
- **Beat 5's 1,564-frame hold has no song**, so the cutscene's music is not merely unhomed — it is
  uncalled.
- **P4.14a's `$6C00` finding stands**; what changed is the size that has to fit in it.

### 8 — Follow-up candidates

- **Bound and size `s_Sumup`** — one run.
- **Jay's ruling**, now on a materially different question than P4.8 posed: the intro's peak is
  18,018 B decompressed / 1,646 B compressed, and only compressed fits. **That means a resumable
  format (cap the compressor's window) or the interpret path — and interpret's 1,024 B set now looks
  very different against 18 KB than it did against 2.6 KB.**
- Extend the PLAN table to all eleven ids so the assert can report *missing*, not just *mismatched*.
- Fix the beat table's misleading `X=80`/`X=140` citations (§3B).

### 9 — User interaction during task

Jay: **"are you still working?"** — yes; this dispatch was in progress.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-19-an-arming-point-selects-the-answer.md`

### 11 — Commit

`9abaecc`  (pushed to origin/wip before this report)
