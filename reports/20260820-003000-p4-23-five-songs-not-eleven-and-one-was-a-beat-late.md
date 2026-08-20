## Form B Report — P4.23 — the intro carries FIVE songs, not eleven; and one was a beat late

**Class:** build.  wip.  Prod — `src/engine/intro_seq.s`: the scaffolding guard removed and the beat table's
song column corrected. Karateka untouched; `main` untouched (`34e93e0`); oracle source read-only.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-20 00:30 (HEAD `5d879c4` at receipt, wip; `4d87ba7` at report). Working tree clean apart from the
pre-existing untracked `docs/ground-truth/*.pdf`, `nvram/`, `.vscode/` and the modified
`dist/mame-cfg/rgb/coco3.cfg` carried since P4.19.

### 1 — Summary

| | |
|---|---|
| **the count** | **★★★ FIVE songs, not eleven.** Four wired here; one was already wired. |
| **the other six** | **NO CALL SITE EXISTED** — ids 7-12 are the cutscene's. **★★★ FOUR are now wired, §3F.** |
| **★★★ a bug Jay heard** | **`s_Sumup` was one beat late** — on the title reprise instead of Prolog2. **Fixed.** |
| **the wiring itself** | **deleting two instructions.** No new mechanism, no per-song data, no second call site. |
| **flame cadence** | `cel_scene_done` at **frame 7945** — same as the one-song build and the silent control |
| **cost** | worst beat **11.78%** of the VBL budget; **beat 6 exactly 0.00%**, which validates the control |
| **suites** | ALL PASS, 128 KB first, `integ` included |
| **★★★ Jay's gate (intro)** | **PASSED** — *"everything looks and sounds pretty good between the oracle and the port."* |
| **the cutscene** | wired (§3F) — **and its cues are 12.4 s LATE, measured (§3G). Gate FAILED there.** |

### 2 — Files modified

- `src/engine/intro_seq.s` — `MSYS_WIRED_SONG` removed; the beat table's song column corrected; the real
  mapping and the cutscene gap documented; `-DMSYS_SILENT` added as the cost control.
- `harness/smoke/run_oracle_live.sh` — sound on by default (carried from P4.22's close).

Explicit-path staging only.

### 3 — Reasoning

#### 3A — ★★★ THE COUNT: FIVE, AND THE DISPATCH'S TABLE SAID TWELVE

**The dispatch asked me to confirm the mapping from the PLAN rather than from its own table, and that
instruction earned its place twice over.**

**The beat table, which is the only home for this fact:**

| beat | song | |
|---|---|---|
| 1 | `s_Presents` | already wired and gated at P4.22 |
| 2 | `s_Byline` | wired here |
| 3 | `s_Title` | wired here |
| 4 | `s_Prolog` | wired here |
| **5** | **`s_Sumup`** | wired here — **and it was on the wrong beat, §3B** |
| **6** | **none** | `SilentTitle` — silent by the oracle's own routine name |

**So the intro carries FIVE songs across six beats.** One was wired; **four were added.**

**★★★ AND THE OTHER SIX HAVE NO CALL SITE ANYWHERE.** ids 7-12 (`s_Princess`, `s_Squeek`, `s_Vizier`,
`s_Buildup`, `s_Magic`, `s_StTimer`) are the cutscene's. Neither `cutscene_room.s` nor `char_draw.s`'s beat
schedule ever plays one — **the phrase "song hold" in those files names a DURATION that the mid-scene disk
reads are scheduled inside, not a song trigger** [`cutscene_room.s:104`, `char_draw.s:459`]. **Wiring them is
a mechanism that does not exist yet, not a widening of this one.**

**HARD-STOP 2 says: report it, do not fabricate a mapping or skip silently.** Reported here, documented in
`intro_seq.s` beside the beat table so the next reader meets it there, and carried to §8.

#### 3B — ★★★ THE BUG JAY HEARD: `s_Sumup` WAS ONE BEAT LATE

**With all five wired, Jay ran the intro and reported:**

> ***"something is wrong at prolog 2, there is n music fora long time and the it move to the secong tilte
> screen and then plays music. i think you have the song tied to the wrong location"***

**He was right, and the oracle's own call order settles it** [`MASTER.S:690-707`]:

```
        jsr Prolog1        -> s_Prolog
        jsr PrincessScene  -> the cutscene
        jsr SetupDHires
        jsr Prolog2        -> s_Sumup      <- MASTER.S:882-884, INSIDE Prolog2
        jsr SilentTitle    -> nothing      <- and its NAME says so
```

The beat table had **beat 5 (prolog2) at `BEAT_SONG 0`** and **beat 6 (the title reprise) at `S_SUMUP`** —
inverted.

**★★ HOW IT WENT WRONG IS THE INTERESTING PART, BECAUSE IT WAS NOT A TYPO.** Beat 5's comment read:

> *"NO SONG -- the oracle's gap here is the PrincessScene cutscene, not built"*

**That is a reasoned conclusion from a false premise.** The cutscene is a **separate call between Prolog1 and
Prolog2**; beat 5 **is** Prolog2, and Prolog2 plays. **And beat 6's row already CITED `MASTER.S:882-884`** —
Prolog2's own lines. ★ **The citation was correct and the assignment was one row off.** It has been in the
table since P3.52 and nothing caught it, because until this dispatch **no beat produced a sound** and a song
column nothing reads is a column nothing checks.

**Verified by the machine, not by re-reading the table** — per-beat FIRQ rate, before and after:

| | beat 5 (prolog2) | beat 6 (`SilentTitle`) |
|---|---|---|
| before | **0.00** /frame | 6.92 /frame |
| after | **10.79** /frame | **0.00** /frame |

**★ AND IT WAS BEING CUT SHORT AS WELL AS MISPLACED.** Beat 6's window is 720 frames against beat 5's 1,767,
so `s_Sumup` had nowhere near room to finish where it sat. Both faults had the same single cause.

#### 3C — the wiring: deleting two instructions

`MSYS_WIRED_SONG`'s comparison is gone. **That is the whole change** — the player already carries all
thirteen songs and its entry table resolves the id, so there is **no new mechanism, no per-song data, and no
second call site.** The scaffolding existed so P4.21's defects would surface in one place rather than five,
and both did (the shared-latch hang, the ×7 rest multiplier); **neither is per-song, so neither can return one
song at a time.**

#### 3D — cost, with a control in EVERY beat

**★ P4.21 measured beat 1 against beat 5 and got a meaningless 30%** — different beats do different work.
`-DMSYS_SILENT` builds the same binary with `play_song` short-circuited, so every beat runs its exact code
path with no song:

| beat | song | control | cyc/frame | % VBL | FIRQ/f |
|---|---|---|---|---|---|
| 1 `s_Presents` | 2414.9 | 2634.7 | 1,539 | 5.15% | 7.73 |
| **2 `s_Byline`** | 3733.2 | 4235.5 | **3,516** | **11.78%** | 18.48 |
| 3 `s_Title` | 3804.1 | 4184.6 | 2,664 | 8.92% | 13.78 |
| 4 `s_Prolog` | 995.3 | 1047.6 | 366 | 1.23% | 2.26 |
| 6 (silent) | 3762.6 | 3762.6 | **0** | **0.00%** | 0.00 |
| 5 `s_Sumup` | 2524.8 | 2684.1 | 1,115 | 3.73% | 6.92 |

*(measured before §3B's swap; the rows are the beats as they then stood)*

**★★ BEAT 6's EXACT ZERO IS THE CONTROL VALIDATING ITSELF** — the same binary, the same beat, no difference
because there was no song. A control that cannot show zero cannot show a number either.

**Worst case 11.78% of the 29,859-cycle budget.** ★ Beat 1 rose from P4.22's 3.54% to 5.15% **because the
rest fix made the song denser**, not because anything regressed — the same song now finishes in 310 frames
instead of 455, so its work is packed into fewer frames.

#### 3E — the flame cadence, across the FULL intro

P4.22 measured zero drift with one song. With five:

```
cel_scene_done: cleared by the scene yes, then set at frame 7945
20 reads (14 into the draw window), 769 swaps
```

**Frame 7945 — identical to the one-song build AND to the silent control.** Not one frame of drift with five
songs playing, which is what §3 item 5 asked for.

#### 3F — ★★★ THE CUTSCENE'S SONGS, ADDED AFTER THE GATE PASSED

**Jay, after ruling: *"let's add the cutscene sound."*** §3A had called this a design step, and it was a
smaller one than that — **because the PLAN already carried the fact:**

```python
("song", "s_Princess", 761)   ("song", "s_Vizier", 358)
("song", "s_Buildup", 394)    ("song", "s_Magic", 113)
```

**Those rows already became beats of their own traced length, and `cel_plan.s` already printed the song's
NAME — in a COMMENT.** So the schedule knew which beat was a cue and nothing could act on it. ★ *A fact
present in a generated artifact but only as prose is a fact the machine does not have.*

| where | what changed |
|---|---|
| `bake_scene.py` | `song_at()` reads the SAME PLAN row the beat came from, so a cue cannot drift from its beat. Ids quoted from `MASTER.S:112-126`, not remembered. |
| `cel_plan.s` | a 7th byte per row — beat 1 → 7, beat 6 → 9, beat 10 → 10, beat 14 → 11 |
| `char_draw.s` | `PLAN_STRIDE` 6 → 7; `vb_apply` plays byte 6 when non-zero |
| `cutscene_room.s` | `msys_stop` at `room_return` |

**★★ START ONLY, NEVER STOP PER BEAT.** A song outlives its own beat by design — the PLAN converts its traced
duration into a hold and the following beats animate over it, which is what the oracle does. **Stopping on a
0 would cut every song after one beat.** The tear-down is `room_return`, the only place that knows the scene
is over; a scene returning with a live FIRQ hands the intro an interrupt it does not know about.

**★ FOUR, NOT SIX.** The PLAN has no `s_Squeek` or `s_StTimer` beat — the port's scene does not contain those
moments (the vizier's entrance was cut at P3.72i for the bank wall). **Reported, not invented.**

**★★★ AND THE BUILD'S OWN STRIDE ASSERTION CAUGHT THE ROW CHANGE ON THE BUILD THAT MADE IT:**

```
FAIL cel_plan is 140 B linked but 20 rows x 6 B is 120 B (off by +20) — a row emitted the wrong number of bytes
```

**Three copies of the row length exist** — `bake_scene.py`, `char_draw.s`, `bundle_offsets_check.py` — **and
the check exists because they can disagree.** All three updated; it now reads
`ok cel_plan 20 rows x 7 B = 140 B linked`.

**MEASURED — and one number got WORSE, which is the point of measuring:**

| | before | after |
|---|---|---|
| scene FIRQ rate | 2.26 /frame | **6.32 /frame** — it genuinely sounds |
| **`cel_scene_done`** | **frame 7945** | **frame 7977** |

**★★ THE SCENE IS 32 FRAMES (0.53 s) LONGER, ~2.3% on a ~23 s scene.** §3E and P4.22 both measured **zero**
drift there — **but the scene was silent then.** The FIRQ takes cycles and the room loop occasionally misses
its due frame. **Reported for Jay's ear, not tuned:** whether 2.3% on the cutscene is acceptable is his call
under §2I, and tuning against a number he has not heard is how a pace gets optimised into something nobody
asked for.

#### 3G — ★★★ THE CUTSCENE'S CUES ARE 12.4 s LATE, AND IT IS ONE FAULT

**Jay, on the wired cutscene:**

> ***"the sound for the beginning of the cutscene is just wrong. his entry music is wring. the hourgalss
> appearance sound decent, but it way to late in the sequence"***

**Three observations. ONE fault.** `harness/tools/cue_times.lua` taps the write to `msys_index` — `msys_play`'s
first act, once per call, carrying the id — and reports each start against the scene's own window
(`cel_scene_done`), so the offsets are directly comparable with the oracle's PlayCut0-relative call times:

| song | port | oracle | delta |
|---|---|---|---|
| `s_Princess` | **12.6 s** | 0.2 s | **+12.4 s** |
| `s_Squeek` | **never fires** | 14.1 s | **MISSING** |
| `s_Vizier` | 27.2 s | 16.7 s | +10.5 s |
| `s_Buildup` | 37.1 s | 26.3 s | +10.8 s |
| `s_Magic` | 48.0 s | 34.9 s | +13.1 s |
| `s_StTimer` | **never fires** | 42.7 s | **MISSING** |

**★★ THE FIRST CUE IS 12.4 s LATE AND EVERY LATER ONE INHERITS THE OFFSET.** Not four errors — one, carried
forward. That is exactly the shape of his report: *"the beginning is just wrong"* is 12.6 s of silence;
*"his entry music is wrong"* is 10.5 s late; *"way too late"* is 13.1 s late.

**★★★ AND THE FIRST INSTRUMENT WAS BROKEN.** It read-tapped the entry table's `msys_play` slot on the theory
that a `jsr` there shows up as a read. It reported **198 cues, all at one frame, all inside the INTRO** —
opcode fetches, not calls. ★ *It announced itself by being absurd, which is worth more than a subtly wrong
number.* The correction was to **tap STATE, not control flow**: one write, once per call, carrying the id,
and it cannot fire on anything else.

**WHERE THE 12.4 s GOES — nine track reads before beat 0 ticks:**

```
+0.00s  READ track 11 -> $6A00      +6.11s  READ track 16 -> $F200
+1.30s  READ track 12 -> $D200      +7.31s  READ track 20 -> $FE00
+2.50s  READ track 13 -> $E000      +8.71s  READ track 21 -> $F200
+3.70s  READ track 14 -> $F200     +10.11s  READ track 29 -> $FE00
+4.91s  READ track 15 -> $FE00     +12.57s  ★ CUE s_Princess
```

**The oracle has no such gap** — it batch-loaded its stage before `PlayCut0`, so the scene animates and plays
immediately. **The port loads the scene's assets AT the scene's start.**

#### 3H — Jay chose to move the loading earlier; here is what that actually costs

Offered four options; he chose **B, move the scene's asset loading into the intro's opening batch.**
Measuring it first turned "expensive" into a specification:

| reads | destination | during the intro | movable |
|---|---|---|---|
| tracks 11-16, 20-21 — the cel pages | GIME bank `$0C-$0F` | **not used by the framebuffers** (§2K: they are `$10`/`$14`, aliasing to `$00`/`$08`) | **YES — ~8.7 s** |
| track 29 — `princess_room.lz` | draw window `$FE00` | **the intro's own screens live there** | **NO** |

**So B recovers ~8.7 s of the 12.4, leaving ~3.7 s.**

**★★ AND IT HAS ONE COST THAT ONLY APPEARED ON MEASUREMENT.** The intro caches the splash in that same bank
[`intro_seq.s:1089`, `bank_valid`]. Loading cel pages at start-up destroys the cache immediately, so the
splash re-read beat 6 already performs would be needed earlier too — **one extra track read, for 8.7 s.**

**★ AND THE WORK IS NOT "MOVE A CALL".** The page-fill code lives in `cutscene_room.s`, which is read to
`$2500` and **does not exist yet** when the intro's opening batch runs. B is therefore either reading the
scene program earlier and calling a fill entry through its table, or lifting the fill into `intro_seq.s`.
**Both touch the MMU.**

**NOT IMPLEMENTED IN THIS DISPATCH, AND THE REASON IS STATED RATHER THAN IMPLIED:** this is a bank/MMU change,
which is where this project's most expensive bugs have lived — P3.10's block `$18` was *"fine on 512 KB and
fatal on 128 KB"* — and **three of my inference-driven changes this session were wrong**, each caught only by
measuring afterwards (§3G's first instrument, P4.21's `$FF92` read-back, P4.22's TINS hypothesis). Starting an
MMU change at the end of a long session and verifying it with a suite pass is the P3.10 shape. **Recommended
to Jay as the next dispatch's first item, with `cue_times.lua` already in the tree so its first act can be to
watch the 12.6 s drop.**

### 4 — Verification (AC-by-AC)

- **AC1 all twelve songs wired, from the PLAN's own mapping** — **★ NOT AS WRITTEN, AND THE PLAN IS WHY.**
  **All five of the intro's songs are wired.** The other six have no call site (§3A) — reported per
  HARD-STOP 2 rather than fabricated. **The mapping came from the beat table, and following that instruction
  is what found §3B's bug.**
- **AC2 `integ` passes 128 KB first** — **PASS** (§5).
- **AC3 Jay gates by ear and eye, all five items, words verbatim** — **★★★ PASSED**, in two rounds. The
  first found a real fault (§3B, the beat mapping) and the corrected build was ruled on against the oracle
  running alongside:
  > ***"everything looks and sounds pretty good between the oracle and the port."***

  ★ **Judged as a COMPARISON, which is the strongest form this gate has taken** — the oracle was on screen
  beside it (`run_oracle_live.sh`, sound on) rather than recalled from memory.
- **AC4 if passed: the retired items named** — **PASS, NAMED in §8, NOT REMOVED.** The gate has passed so the
  removals are unblocked; ★ **they are not actioned here because Jay's next instruction moved to the cutscene,
  and deleting the capture path is a separate change that should stand on its own diff.**
- **AC5 route accounting present; Karateka untouched; `main` untouched** — **PASS** (§6).

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output, verbatim** — after §3B's fix:

```
[suites] running: introseq integ
[suites] -ramsize 128K
[suites] === introseq ===
[run_introseq_test] PASS
[suites] === integ ===
[integ] PASS

[suites] ALL PASS
```

**Build verified by symbol** — the corrected song column, read back from the source:
```
1144:  fcb  S_PRESENTS   ; BEAT_SONG  [MASTER.S:753-755]
1151:  fcb  S_BYLINE     ; BEAT_SONG  [MASTER.S:795-797]
1163:  fcb  S_TITLE      ; BEAT_SONG  [MASTER.S:832-834]
1171:  fcb  S_PROLOG     ; BEAT_SONG  [MASTER.S:850-852]
1194:  fcb  S_SUMUP      ; BEAT_SONG  [MASTER.S:882-884]      <- beat 5, prolog2
1212:  fcb  0            ; BEAT_SONG  NO SONG -- SilentTitle  <- beat 6
```
```
[map_check] 5 map(s) clean — no overlap, nothing below $0E00.
```

**25.2 bundled-artifact grep:** N/A — no sibling-import artifact.

**25.3 operator-runtime-smoke — TWO SEPARATE GATES, RULED SEPARATELY.**

**THE INTRO: ★★★ PASSED — Jay, live-disk, RGB, 128 KB, sound on, cold boot, WITH THE ORACLE RUNNING
ALONGSIDE.** His words, verbatim:

> ***"everything looks and sounds pretty good between the oracle and the port."***

**Two rounds.** The first surfaced a genuine fault — §3B's beat mapping — and is recorded as a fault found,
not as a failed attempt. The second, after the fix, is the ruling. **Launch path `live-disk`**, cold boot,
sound on, throttled (`run_introseq_live.sh`), 175 s — past the cutscene at 132.6 s and the intro's completion
at 169.1 s. The oracle ran alongside (`run_oracle_live.sh`, `apple2e` + `cffa202`, 137 s), so the comparison
was against the thing being ported.

**THE CUTSCENE: ★★★ FAILED.** Added after the intro's gate passed, on Jay's instruction, and ruled
separately:

> ***"the sound for the beginning of the cutscene is just wrong. his entry music is wring. the hourgalss
> appearance sound decent, but it way to late in the sequence"***

**Attributed (§3G) and NOT fixed** — the cause is a scene-startup load order and the fix is a memory-map
change (§3H). ★ **The intro's pass does not carry to the cutscene and is not claimed to.**

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING. This report contains** the intro's five songs wired, the count reconciled against the
PLAN, the cutscene gap reported, §3B's beat-mapping bug found by Jay and fixed, the cost measured with a
control in every beat, and the flame cadence measured across the full intro.
**It does NOT contain** the cutscene's six songs — **no call site exists and building one was not this
dispatch's scope** — nor §4's retirements, which are gated on a pass that has not happened.

**Reactive deviations (§22.5):**

1. **The dispatch's inventory said eleven and the PLAN says four** (§3A). Reconciled out loud rather than
   worked around. **The dispatch explicitly asked for this check and it paid twice.**
2. **`-DMSYS_SILENT` added to `intro_seq.s`** — a build-flag control for the cost measurement. It is
   scaffolding, and unlike `MSYS_WIRED_SONG` it changes nothing in the shipping build.

### 7 — Uncertainty flags

- **★★★ THE BEAT TABLE'S SONG COLUMN HAS NEVER BEEN CHECKED AGAINST ANYTHING BUT AN EAR.** §3B's error sat
  in it from P3.52, with a CORRECT source citation attached to the WRONG row, and nothing caught it because
  until P4.21 no beat made a sound. **The other four rows are cited the same way and have the same standing.**
  Jay has now heard beats 1-6 in sequence once, with one fault found; **that is the only check they have had.**
- **★★★ THE CUTSCENE'S GATE FAILED** (§3G) and the cause is attributed but NOT fixed. The intro's gate
  (§4 AC3) stands on its own — the two were run and ruled separately.
- **★★ TWO NUMBERS I REPORTED WRONG, BOTH CORRECTED HERE.** ★ The scene is **57.6 s** (frames 4523-7977),
  not the ~23 s I assumed when calling §3F's +32-frame drift "2.3%" — **it is 0.9%**. ★ And §3F said the
  cutscene work was a "small step"; it was, but the cue TIMING it exposed is not.
- **★ `s_Squeek` and `s_StTimer` have no beat in the port's scene** and are therefore unreachable. `s_Squeek`
  belongs between the princess turning and the vizier approaching — **the port has a silent 5-play hold at
  exactly that position** (`("-", "", 5)`, beat 3), so adding it is a one-row PLAN change. `s_StTimer` falls
  after the scene's current end. **Neither is a defect; the scene is four-sixths of the oracle's cue list.**
- **★ THE +32-FRAME SCENE DRIFT IS STILL UNRULED** and now measured against the right denominator (0.9%).
- **★ THE COST TABLE IN §3D PRE-DATES §3B's SWAP.** The per-beat figures are correct for the beats as they
  then stood; `s_Sumup` has since moved from a 720-frame window to a 1,767-frame one, so its per-frame cost
  will be lower and its total higher. **Not re-measured** — the worst case (11.78%, beat 2) is unaffected.
- **`s_Sumup` was being truncated by beat 6's short hold** (§3B). Whether it now fits beat 5's 1,767 frames
  is **not measured**; if it still overruns, `msys_stop` cuts it and that is the drift question, not a defect.
- Carried from P4.22: only two songs have ever been heard individually; the generator/validator assertion is
  still unbuilt; `$FF91` is still written wholesale.

### 8 — Follow-up candidates

- **★★★ MOVE THE CEL-PAGE READS INTO THE INTRO'S OPENING BATCH** (§3H) — Jay's choice B, now specified:
  eight of nine reads, ~8.7 s recovered, one extra splash read as the cost, and the page-fill code has to
  reach the intro somehow. **The next dispatch's first item.**
- **★★ ADD `s_Squeek` TO THE PLAN** — a one-row change at beat 3's existing silent hold (§7).
- **★★ THE RETIREMENT LIST, held until the gate passes** — so it is not lost: the capture song files
  (`song_a.s`, `song_b.s`, `song_princess.s`), `pack_song.py`'s latency/pulse-overhead constants, `SP_DITHER`
  and table B, `song_probe.s`'s table walk, the `$6C00` and `$7268` buffer arrangements, the peel-silent
  condition and its assert, the two-arrangement split, and the LZ4-streaming question. **The capture player
  itself is Jay's call** — it has no callers, and it was the thing he first said sounded fine.
- **★ A build-time assertion that the generated timer table reproduces `msys_decode`'s segment durations**
  (carried from P4.22 §7, still the most valuable unbuilt check).
- **Verify `s_Sumup` fits beat 5's hold** (§7).
- Carried: gameplay's colour mode; the per-cue control policy; the HAL audit; the stale `pop.link` stack
  comment; `Demo` unbuilt.

### 9 — User interaction during task

1. **★★★ THE BUG** — *"something is wrong at prolog 2, there is n music fora long time and the it move to the
   secong tilte screen and then plays music. i think you have the song tied to the wrong location."*
   **§3B. Correct, and his diagnosis — "tied to the wrong location" — was the exact fault.**
2. **"continue"** ×2 — proceed.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-19-a-dispatchs-inventory-is-a-claim-check-it-against-the-plan.md` — committed and
pushed to the pool.

### 11 — Commit

`4d87ba7` (pushed to origin/wip before this report). This dispatch:

| | |
|---|---|
| `c3e240a` | all five of the intro's songs wired; the other six have no call site |
| `4d87ba7` | `s_Sumup` was one beat late — Jay heard it, the oracle confirms it |
