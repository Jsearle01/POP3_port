## Form B Report — P5.13 — one visible freeze, and 512 KB would pay for it at the boot screen

**Class:** recon. `wip`. Prod byte-identical at both ends. **Nothing built.**

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-22T19:59:20Z (HEAD `a80ca31`, wip; **`main` at `32b5fe2`, resolved here**).

`git status` at receipt — the standing untracked set: `.vscode/`, `nvram/`,
`POP-idioms-coco3-markers.md`, `content/intro/broderbund_splash_render.bin`, nineteen files under
`docs/ground-truth/`, `docs/project/pop-coco3-design-v0_7.pdf`. **No modified tracked files.**

**Prod sha1 — identical at both ends (AC12). Nothing rebuilt:**

```
d07f1f3295525783968dcce6409ee1b64942231c  build/intro_seq.bin
0b4968867bf5274d2942f3b5b90ea855ad6f2def  build/loader.bin
790836577e56b61b8f849cb309874e44304840a2  build/cutscene_room.bin
```

**AC11 — the stop observed:** `git status --porcelain src/` → **0 lines** at both ends.

---

### 1 — Summary

**Measured on the port's own driver, live-disk, headless: 18 drive-engaged spans, 126,720 bytes,
3,067 frames = 51.18 s of a 200.3 s window — the drive is running 25.6% of the attract cycle.**

★★ **But exactly ONE of those eighteen is visible.** Every other span happens with the screen already
static — under the loading screen, or between beats. **Span 15 alone has page flips on both sides and
none during it: 15 flips before, 0 during, 19 after. That is the cutscene freeze, and it is
3.20 seconds long.** `char_draw.s:2683`'s claim verifies exactly, and it is not two frames.

★★ **The music does NOT glitch, and the reason is design rather than luck.** During that span the DAC
takes 4 writes in 192 frames against 472 in the 60 frames after — silent. **But the read is scheduled
into a song hold**: `intro_seq.s:164` records *"beat 5 BEAT_SONG 0 (the PrincessScene gap)"*, and
`char_draw.s:2679` says *"During a song hold both characters are drawn from pinned cels, so `$FFA7`
is free and a track can land in it without taking anything off the screen."* **There is no song to
interrupt.** That is why the gate passed, and it is a deliberate placement, not an accident.

★★★ **§8's premise check comes back clean, and it was the most likely way this dispatch could have
been wrong. Decompression is 1.82 s across the entire cycle — five expansions of 0.38-0.48 s — against
51.18 s of disk. A 28:1 ratio.** The wait is disk. 512 KB is aimed at the right thing.

★ **And the trade is sharper than "remove disk loads" suggests.** The mid-run reads total **20.0 s**,
and most of that data has to be read at the front instead — **so the boot wait grows from 21.8 s to
about 35.8 s, to remove 3.2 s of visible freeze.** That is a judgement, not an improvement, and §4.2
said so before it was measured. **The smallest version of the change buys the whole visible benefit
for 9.2 s instead of 14** (§4.3).

★★ **AMENDED AFTER FILING, on Jay's account and confirmed by trace (§3H).** He said data is re-read
after the cutscene because it could not be held in memory during it. **It is: tracks 25
(`intro_bundle.raw`) and 27 (`intro_screen.lz`) are each read twice — once in the startup batch and
again after the scene, to rebuild the title.** That is **6.0 s of the 20.0**, and it does not move to
the front under 512 KB — **it stops happening.** §7.2 had flagged this as the softest figure in the
report and the one Jay's decision most turns on; it was right that it would move, and Jay supplied
the mechanism.

---

### 2 — Files modified

- `harness/tools/intro_load_trace.lua` — **new.** Three event-accurate taps (FDC data, DSKREG, DAC)
  plus `lz_end`/`lz_cnt`, giving every read with what was on screen and what the song was doing.
- `reports/20260822-203000-p5-13-…md` — this report.

Nothing under `src/`, `link/`, `content/`, `dist/`. `build.bat` untouched.

---

### 3 — Reasoning

#### 3A — §1's claims, verified

Both verbatim. `char_draw.s:2683-2685`: *"THE TORCHES FREEZE FOR THE TRANSFER, and nothing here can
prevent it: `disk_read_range` polls the FDC with interrupts masked and there is no DMA on this
machine — the CPU is the transfer. That cost is measured at the gate, not quoted from the design."*
And `char_draw.s:186-200` carries the 39,682 B split bank.

★ **One §1 implication does not hold, and it matters for scope.** The intro's *own* file states
*"every asset is read before the first beat, and nothing touches the disk afterwards"*
[`intro_seq.s:32`]. **The mid-run reads are the CUTSCENE's, not the intro's** — the scene runs inside
the intro (P3.107), so they appear in the intro's timeline while belonging to `char_draw.s`'s cel
service. The distinction decides where a fix would go.

#### 3B — AC1/AC2: the schedule, measured

*Authority: execution trace, three write/read taps on the port's own run.*

**The instrument.** `$FF4B` FDC data register (read tap — every byte the WD1773 moves passes through
it, including DECB's boot `LOADM`, which the engine's own counter cannot see); `$FF40` DSKREG (write
tap — drive-engaged time, which is what the machine actually waits for, since the WD1773 paces the
6809 with HALT through seek, settle and latency as well as bytes); `$FF20` DAC (write tap — the song).
All three are event-accurate, because a load that starts and ends inside one frame is invisible to a
sampler [§5.239].

| # | frames | secs | bytes | what was on screen | verdict |
|---|---|---|---|---|---|
| 1 | 431–991 | 9.35 | 6,912 | BASIC prompt — DECB's `LOADM"LOADER"` | not the port's |
| 2–12 | 991–2298 | **21.8** | 55,296 | **the loading screen** — 0 flips throughout | invisible |
| 13–14 | 3759–4227 | 7.8 | 23,040 | static between beats | invisible |
| **15** | **6881–7073** | **3.20** | 9,216 | **the cutscene** — 15 flips before, **0 during**, 19 after | ★ **SCREEN FROZE** |
| 16–17 | 8636–8996 | 6.0 | 18,432 | static either side | invisible |
| 18 | 10583–10763 | 3.0 | 9,216 | static either side | invisible |

**Totals:** 18 spans, **3,067 frames = 51.18 s engaged of 200.3 s = 25.6%**; 126,720 bytes.

★ **The startup batch is 100% drive-engaged.** Spans 2–12 abut exactly — 991→1171→1279→1387… — so
across those 1,307 frames the drive never disengages. **There is no decompression time inside the
batch**; it all follows.

**Milestones (AC2):** EXEC at frame **801** (13.4 s, mostly DECB and my script's fixed typing delay,
not the port). **EXEC → end of startup batch = 1,497 frames = 25.0 s** before the first beat can run.
The intro then plays across a 2,654-frame gap (44.3 s, 223 flips) with the disk idle.

★ **I could not identify the attract loop's repeat from a marker**, only infer it from span 18
repeating spans 16/17's signature. **AC2's third total is therefore not established** — §7.

#### 3C — AC3: the freeze, and the music

**Duration 192 frames = 3.20 s. Count: one visible occurrence per observed cycle.**

The other seventeen spans all sit in periods with no flips on either side, so nothing stops that was
moving. **Only span 15 has motion on both sides and none during** — that is the definition this
report uses for "visible", and it is the only span that meets it.

**What stops:** page flips (0 during, 15/19 either side) and the DAC (4 writes in 192 frames against
472 in the following 60). So the torches freeze and the audio hardware goes quiet, exactly as the
source comment says.

> **★★ AC3's music question, answered plainly: the song does not glitch, because no song is playing.**
> The read is placed in the PrincessScene song gap [`intro_seq.s:164`, `BEAT_SONG 0`], and the design
> comment states the same thing from the other side [`char_draw.s:2679`]. **This is not a defect in a
> gated scene.** Had the read landed in a beat with a song, the same 3.2 s would have been 3.2 s of
> silence — the mechanism is there, the schedule keeps it away from it.

#### 3D — AC4: disk versus decompression

*Authority: trace. `lz_unpack` writes `lz_end` on entry and `lz_cnt` throughout its loop
[`lz_unpack.s`], so the first gives the start and the span of the second gives the duration.*

**Five expansions in the whole cycle**, each beginning on the exact frame a read ends:

| expansion at frame | seconds in | duration |
|---|---|---|
| 935 | 15.6 | <1 frame |
| 2298 | 38.4 | 29 frames = **0.48 s** |
| 4227 | 70.5 | 23 frames = **0.38 s** |
| 8996 | 150.1 | 23 frames = **0.38 s** |
| 10763 | 179.6 | 29 frames = **0.48 s** |

**Total frames in which `lz_cnt` was written at all: 109 = 1.82 s.**

> **★★★ 51.18 s of disk against 1.82 s of decompression — 28:1.** §8 warned that if the wait were
> mostly decode, most of this dispatch's premise would be wrong. **It is not. The premise holds**, and
> the 24.4-second idle gap after the startup batch is the intro *playing*, not overhead — 0.48 s of it
> is expansion and the rest is beat timing.

#### 3E — AC5: what 512 KB removes

The cutscene bank is **39,682 B across a pinned page and five rotating pages** [`char_draw.s:186-200`]
= **5 blocks**. Against P5.12's **56 free blocks on 512 KB**, the whole bank is resident before the
scene starts, and the mid-scene reads have nothing to fetch. **The arithmetic is not close: 5 of 56.**

★ **`vb_apply` becomes IDLE, not dead. `cel_service_read` becomes dead.** `vb_apply` does four things
per beat — publishes the block number to `cel_pg_block`, the signature to `cel_pg_sig`, the scenery
state to `vm_scenery`, and the song id — and **only the last of those is about disk**. Remove the
reads and it still has to publish the block and signature, because `room_present` re-maps after every
flip and the guard still compares. `cel_service_read` [`char_draw.s:2734`], called once per frame with
`Y = load_tracks`, is the part with nothing left to do.

#### 3H — ★★ ADDENDUM: the re-reads, found on Jay's account and confirmed by trace

**Jay, after the report was first filed:** *"so i know there is a re-read of data after the cutscene
because it couldn't be held in memory during the cutscene."*

**He is right, and §7.2 flagged exactly this figure as the one most likely to move. It moved.**

Tapping the disk driver's own request block — `DR_VARBASE+5`, the track byte staged before every
call [`tile_probe.s:93-95`] — names every read:

```
21 requests, 19 distinct tracks
  track 25   read at frames    991, 8636   <- RE-READ
  track 27   read at frames   2118, 10583  <- RE-READ
2 of 19 distinct tracks are read more than once; 2 of 21 requests are re-reads.
```

**And `build.bat`'s track map says what they are:**

| track | asset | first read | re-read |
|---|---|---|---|
| **25** | `intro_bundle.raw` | frame 991 (startup batch) | **frame 8636** |
| **27** | `intro_screen.lz` | frame 2118 (startup batch) | **frame 10583** |

> **★★ The intro's bundle and its title screen are evicted to make room for the cutscene and fetched
> again afterwards to rebuild the title.** That is precisely Jay's account, arrived at from knowing
> the design rather than from the trace, and the trace confirms it exactly.

**This splits the 20.0 s of mid-run disk into two kinds that behave differently under 512 KB:**

| | spans | frames | seconds | what 512 KB does |
|---|---|---|---|---|
| **first reads** | 13, 14, 15, 17 | 840 | **14.0** | move to the front — the boot wait pays for them |
| **re-reads** | **16, 18** | 360 | **6.0** | ★ **vanish outright** — the data is still resident |

**So §3F's arithmetic below is corrected: the boot wait grows by 14.0 s, not 20.0.** And the 6.0 s of
re-read is the concrete, named content of §3G's coexistence benefit — **it is what the attract loop
spends today, every cycle, to get back to the title.**

#### 3F — AC6: does the initial load get longer? **Yes — but by 14 s, not 20 (see §3H).**

512 KB does not make the machine boot with data in it. Everything read mid-run has to be read at the
front instead:

| | frames | seconds |
|---|---|---|
| startup batch today (spans 2–12) | 1,307 | **21.8** |
| mid-run reads that would move forward (spans 13,14,15,17 — first reads only) | 840 | **14.0** |
| ~~re-reads (spans 16, 18)~~ — these VANISH, they do not move | ~~360~~ | ~~6.0~~ |
| **boot wait after the change** | 2,147 | **≈35.8** |

> **★★ So the trade is: about 14 seconds added to the boot wait, to remove 3.2 seconds of visible
> freeze — plus 6.0 s per cycle that disappears entirely (§3H).** The rest of the removed disk time
> was never visible; it happened under a static screen. **That is still a judgement and it is Jay's**,
> but it is a better one than the first arithmetic suggested.

#### 3G — AC7: coexistence

Today *"nearly everything below `$7900` is free"* when gameplay starts, because the intro's program,
cutscene data, captions, flame bundle and cel pages all die. Costed against P5.12's figures:

| resident set | blocks |
|---|---|
| intro + cutscene assets (39,682 B bank + screens/captions) | ~7 |
| gameplay, per-level [P5.12] | 16 |
| **both resident together** | **~23 of 56** |
| gameplay, all-resident [P5.12] | 44 |
| **intro + all-resident gameplay** | **~51 of 56** |

**Both fit.** ★ **So the attract loop could return to the title without re-reading anything** — spans
16, 17 and 18 disappear entirely rather than moving to the front, because the intro's assets would
still be resident from the first pass. **That is the one benefit that does not have to be paid for at
boot**, and §4.3's smallest change does not capture it.

---

### 4 — Phase 4: the answer

**4.1 — AC8: does the intro get better, and by how much?**

**In visible frames: 192 frames — 3.20 seconds — once per attract cycle.** That is the entire
user-visible gain, and it is the cutscene's torches unfreezing. Everything else 512 KB removes is
disk time that already happens behind a static screen.

★ **But 6.0 s of that invisible time is a re-read the machine would stop doing altogether** (§3H) —
`intro_bundle` and `intro_screen`, fetched a second time to rebuild the title after the cutscene
evicted them. It is invisible, so it is not a *visual* gain; it is 6.0 s per cycle of drive wear and
of a static screen the viewer sits in front of.

**4.2 — What gets worse:** the boot wait, by **14 s** (§3F as corrected by §3H). The 6.0 s of
re-read does not move to the front — it stops happening — so coexistence (§3G) is not an extra
option here, it is what the re-reads becoming unnecessary *means*.

**4.3 — AC9: the smallest change that captures most of the benefit.**

**Preload only the rotating pages the cutscene reads mid-scene** — spans 15, 16 and 17, 27,648 bytes,
**3 blocks** — at startup, and leave everything else exactly as it is. **That removes the one visible
freeze for about 9.2 s of extra boot wait instead of 20**, needs no restructuring of the beat
schedule or the intro's asset flow, and leaves `vb_apply`'s publishing path untouched. Named, not
built.

**4.4 — AC10: what I am NOT proposing.**

1. Not proposing to **build** anything, or to rebuild the intro.
2. Not proposing **128 vs 512** — Jay's call, and this dispatch exists to inform it.
3. Not proposing to **adopt §4.3's preload** — it is the smallest option, not a recommendation.
4. Not proposing to **remove `vb_apply` or `cel_service_read`** (§3E distinguishes idle from dead).
5. Not proposing anything about the **beat schedule**, the song gap, or the cutscene's timing.
6. Not proposing to **re-gate the cutscene** — §3C finds no defect in it.
7. Not proposing anything on tileset 02, the character bake, the two-block gap, or A/B/C.

---

### 5 — Verification (AC-by-AC)

- **AC1** — §3B, all 18 spans with what was on screen; the §2 call-site list was a starting point and
  the trace found the reads without relying on it.
- **AC2** — §3B: EXEC→batch-end 25.0 s. ★ **The loop-repeat total is NOT established** (§7.1).
- **AC3** — §3C: **3.20 s, one visible occurrence**, screen frozen, **music explicitly not glitching
  and why**.
- **AC4** — §3D: **51.18 s disk vs 1.82 s decompression**.
- **AC5** — §3E: 5 blocks of 56; `vb_apply` **idle**, `cel_service_read` **dead**.
- **AC6** — §3F: **yes, +20 s**, roughly doubling the boot wait.
- **AC7** — §3G: ~23 of 56 with per-level gameplay, ~51 of 56 all-resident. Both fit.
- **AC8** — §4.1: **192 frames**. **AC9** — §4.3. **AC10** — §4.4.
- **AC11/AC12** — §0.
- **AC13** — **suites NOT run, and saying so.** Nothing was built: no source, link script, bake input
  or disk image changed, and `build.bat` was not invoked. The unchanged sha1 triple is the evidence.
- **AC14** — §6.

---

### 6 — Reactive deviations and route accounting

1. **★ My first trace reported ZERO disk activity over 200 emulated seconds** — which reads as "the
   intro does no I/O" and was actually "the intro never ran". The delivery path is `LOADM` + `EXEC`
   off the floppy and nothing types them unless the script does. Caught because zero was implausible,
   not because anything failed. The tool now posts them and says why in its header.
2. **★ My first `dac` and `flips` columns were uninterpretable and nearly produced the wrong finding.**
   `dac = 0` during a read is "the song stopped" only if the song was playing either side; otherwise
   it is "no song was playing". Seventeen of eighteen spans read `dac = 0`, which invites "the music
   breaks constantly". With the 60-frame neighbourhood added, **one span meets the definition and it
   is in a deliberate song gap.** The verdict is derived from the comparison, never from the zero.
3. **Headless throughout** [§5.255] — `-video none`, no window opened at any point.

**ROUTE ACCOUNTING.** No route proposed beforehand. Within the task the instrument was extended three
times, each time because a measurement could not answer the question asked of it: adding the program
start (deviation 1), adding neighbourhood context (deviation 2), and adding `lz_cnt` after `lz_end`
alone gave an expansion's *start* but not its *duration* — one timestamp cannot bound an interval.
**Each extension is in the tool's header with the reason.**

**Contains:** AC1-AC14, one new trace tool, no build.
**Does not contain:** any decision, any code, and none of §4.4's seven non-proposals.

---

### 7 — Uncertainty flags

1. **★ AC2's loop-repeat total is not established.** I inferred the cycle from span 18 repeating
   spans 16/17's byte signature, but found no marker that says "the attract loop restarted". The
   200 s window may contain slightly more or less than one full cycle, which would move the 25.6%
   figure.
2. **★ RESOLVED, and it did move.** This flag read: *"§3F's +20 s assumes every mid-run read moves to
   the front unchanged… I did not check track numbers for duplication… That is the single figure most
   likely to move."* **Jay supplied the hypothesis from knowing the design and the track tap confirmed
   it** — tracks 25 and 27 are re-reads, 6.0 s of the 20.0, and they vanish rather than move. The
   corrected figure is **+14.0 s** (§3H). ★ **The flag was right about which number was soft and right
   about the direction; it took Jay to say what the mechanism was.**
3. **§3G's "~7 blocks" for the intro is an estimate.** The 39,682 B bank is measured
   [`char_draw.s:186-200`]; the screens and captions are not re-measured here and are carried from
   the intro's own accounting.
4. **One observed cycle, one machine, 128 KB.** The freeze duration could differ on a machine whose
   drive seeks differently; the span is drive-engaged time, which includes latency.
5. **"Visible" is defined as page flips on both sides and none during.** A screen that is genuinely
   static by design and a screen that has frozen are indistinguishable to that test — it is why
   span 15 is identified and why the other seventeen are called invisible rather than proven so.
6. **The DAC tap sees writes, not audibility.** Four writes in 192 frames is silence for practical
   purposes, but the tap cannot distinguish a held sample from no sample.

---

### 8 — Follow-up candidates

1. ~~Check the mid-run reads for duplicate tracks~~ — **done in §3H**; two re-reads found, +20 s
   corrected to +14 s.
2. **Find an attract-loop restart marker** (flag 1) so the cycle can be bounded exactly.
3. **Cost §4.3's 3-block preload against the boot wait precisely**, rather than by subtraction.
4. **Measure the intro's own asset residency** (flag 3) so §3G stops being an estimate.

---

### 9 — User interaction during task

None.

---

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-22-measure-the-observable-subset-not-the-total.md` — §3B/§6.2: the total said
25.6% of the cycle is disk; the answer was 3.20 s, because seventeen of eighteen loads happen where
nothing was moving. Pushed as `4b75c33`.

---

### 11 — Commit

`c532db9` (pushed to origin/wip). **`main` is untouched at `32b5fe2`.**
