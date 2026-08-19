## Form B Report — P4.21 — one song wired end to end; the probe fixed; **the gate FAILED on Jay's ear**

**Class:** build.  wip.  Prod — `src/engine/intro_seq.s` and `src/engine/msys_player.s` changed; the intro's
shipping binary now reads and plays a song. Karateka untouched; `main` untouched (`34e93e0`); oracle source
read-only.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-19 21:00 (HEAD `cdb9017` at receipt, wip; `604174b` at report). Working tree clean apart from the
pre-existing untracked `docs/ground-truth/*.pdf`, `nvram/`, `.vscode/` and the modified
`dist/mame-cfg/rgb/coco3.cfg` carried since P4.19.

### 1 — Summary

| | |
|---|---|
| **§3 the probe** | **FIXED, with a seeded failure it catches.** It always worked — the error handler was in the success path. |
| **§1 one song wired** | **`s_Presents`, beat 1, from the intro's real launch path.** Suites ALL PASS 128 KB with `integ`. |
| **the discovery** | **★★★ `$FF92` and `$FF93` SHARE ONE SET OF INTERRUPT LATCHES.** Adding the timer silently killed the VBL. |
| **cost in the hold** | **1,058 cycles/frame = 3.54%** of the VBL budget, control in the same beat |
| **§2 Jay's gate** | **★★★ FAILED.** *"so the song plays and seems at the right time, but it's very choppy."* |
| **the defect** | **localised and measured** — 23 segments of ~154 ms, 1.3% of the pairs and **47% of the elapsed time** |

**★★ THE DISPATCH'S OWN PREMISE PAID OFF EXACTLY AS INTENDED.** Jay: *"let's just wire in the first and
verify I hear and see it, and then we'll have the formula for the rest."* **One song exposed two defects that
all twelve would have inherited** — a hang that no amount of isolated testing had shown, and a playback fault
the `s_Princess` ear gate could not have caught because `s_Princess` does not trigger it.

### 2 — Files modified

- `src/harness/interp_probe.s` — the fall-through fixed; signature check; `dr_status` published.
- `harness/smoke/interp_live.lua` — reports the read; a disk failure names itself.
- `harness/smoke/run_interp_check.sh` — `P_SEED=nodisk` inverts the verdict.
- `src/engine/msys_player.s` — the FIRQ is now the single GIME dispatcher; end-of-song handback.
- `src/engine/intro_seq.s` — reads the player; `play_song`'s stub body replaced.
- `harness/smoke/introseq_test.lua` — `disk_reads_completed` 7 → 8, all eight named.
- `harness/tools/intro_song_cost.lua` — NEW. The cost measurement.
- `harness/smoke/run_introseq_live.sh` — sound on by default (`MUTE=1` restores the old behaviour).

Explicit-path staging only.

### 3 — Reasoning

#### 3A — §3: the probe always worked; the error handler was in the success path

P4.19 §7 carried *"the probe's disk read is not working"* and had spent a session on two hypotheses — a
missing `disk_read_init`, the track placement. **Both were wrong.**

```
                jsr     msys_init
                lda     #1
                sta     probe_status
                andcc   #$EF
ip_diskfail     lda     #$EE            <- the SUCCESS path falls straight into it
                sta     probe_status
ip_dead         jsr     HAL_time_vbl_wait
                bra     ip_dead
```

**A successful read set `probe_status = 1` and then walked into the error handler, which overwrote it with
`$EE` and spun.**

**★★ WHAT SETTLED IT IN ONE RUN WAS INSTRUMENTING, NOT REASONING.** Publishing the WD1773's own `dr_status`
and the first two bytes at `$0A00`:

```
# player disk read: WD1773 status $10   carry 0   first bytes at $0A00 $7E0A (want $7Exx — a JMP)
```

`$10` is the expected end-of-track RNF; `$7E0A` is the player's own `JMP`. **The read had been landing
correctly the whole time.** *Two plausible, internally consistent hypotheses, both wrong, neither surviving
thirty seconds of contact with a counter.*

**Three things added, because "the read returned no error" is a weak claim when a whole-track read ends on
RNF by design:**

1. **A signature check** on what landed (`$7E` at the base). Without it a track with no player means `jsr
   msys_init` jumps into whatever *is* there.
2. **`P_SEED=nodisk`** — runs against a disk with no track 32 and **inverts the verdict**, so the instrument
   is shown catching its own planted fault (P3.48b/P3.49). Confirmed both ways:

   ```
   normal: PASS   $0A00 = $7E0A  carry 0   314 ticks  6,930 toggle pairs
   seeded: FAIL   $0A00 = $FFFF  carry 1   "seed caught — the probe reported the failure"
   ```
3. **A disk failure now NAMES ITSELF** instead of falling through to *"the LOADM/EXEC did not take."*
   **★ Reporting the wrong subsystem is worse than reporting nothing**, and that exact misdirection is what
   the previous session was lost inside.

#### 3B — ★★★ `$FF92` AND `$FF93` SHARE ONE SET OF LATCHES, AND THAT IS WHY THE INTRO HUNG

**The intro hung in beat 1 the moment the song played, and nowhere near the cause.**

`$FF92` (IRQENR) and `$FF93` (FIRQENR) look like two independent enable registers. They are not:
**reading EITHER *"tells you which interrupts came in and acknowledges and resets the interrupt source"***
[`SockmasterGime.md:67`]. The player's FIRQ acknowledges by reading `$FF93` — **which destroys a VBORD
pending in the same window.**

**★★ AND `$FF93` REPORTS ONLY THE SOURCES ENABLED IN FIRQENR.** With TMR alone it destroys the frame and
**does not even say it did** — so the first fix, which dispatched on the returned bit, changed nothing.

**Measured on the target rather than argued** (`vbl_probe.lua`, every 300 frames):

```
f2100   HALframe=190  DAC+1535  FF92reads+105  FF93reads+1895
f2400   HALframe=190  DAC+2001  FF92reads+0    FF93reads+2470   <- the VBL is dead
f2700   HALframe=190  DAC+0     FF92reads+0    FF93reads+0      <- song ends; nothing left
```

`hold_frames` spins in `HAL_time_vbl_wait`, which waits on `hal_frame_lo` [`time.s:136-139`]. **The counter
froze at 190 and nothing would ever touch it again.**

**★★★ AND THE PORT'S OWN CODE PREDICTED IT, VERBATIM** [`irq_vbl.s:67-71`]:

> *"Multi-source constraint: `lda $FF92` clears ALL pending GIME IRQ flags simultaneously. With only VBORD
> enabled this is correct. **If future work enables additional GIME sources (timer, HBORD, keyboard, serial,
> cartridge), save A and dispatch on each bit before any are lost.**"*

**The timer is that future work.** ★ The comment lives in the file that owns the *incumbent* source; the work
was in the file that owns the *newcomer*. *A constraint recorded next to the incumbent is not read by whoever
adds the newcomer — and the newcomer is exactly who needs it.*

**THE FIX, IN THREE PARTS, EACH FOUND BY MEASURING:**

1. **The FIRQ becomes the single GIME dispatcher while a song plays** — `$FF93 = $28` (TMR + VBORD),
   `$FF92 = 0`, and the handler does the VBL's job on bit 3 before gating the segment work on bit 5. It
   cannot double-count: whichever consumer wins the race, the other sees the bit clear.
2. **★★ THE END-OF-SONG PATH HANDS THE MACHINE BACK.** The song ends *inside* the interrupt. With only the
   timer stopped, the machine was left with **no interrupt source at all**, and `msys_stop` — which the
   caller runs *after* the hold returns — could never rescue it. The counter froze at 471 instead of 190.
3. **★★★ AND A MISTAKE OF MY OWN, CORRECTED.** I first made the player "restore what it found" by reading
   `$FF90`/`$FF92` at arm time — normally the right instinct. **The GIME's registers are WRITE-ONLY:
   `lda $FF92` returns the pending bitmap and clears it, not the enable mask.** So it saved a pending bitmap
   and put that back. The values are now the constants the HAL establishes, **quoted from where `time.s`
   sets them** (`$FF92 = $08`, `$FF90 = $6C`). *Defensive generality applied to a register whose semantics
   were assumed produced a second silent failure on top of the first.*

#### 3C — §1: what was wired, and why beat 1

**`s_Presents`, beat 1** — the dispatch asked for the first intro beat with a stub `play_song`, and beat 1 is
the first beat of the intro. It is also the simplest: a caption beat with a 281-frame hold.

- **The player is read in the SAME opening burst as the captions**, before the first beat, and the read
  **cannot land visibly** — `$0A00` is not in the draw window (`GFX_DB_WINDOW = $8000`), so it touches no
  framebuffer byte. **Structural, not lucky.** The entry table's `JMP` signature is checked before the
  player is called.
- **`play_song`'s stub body is replaced, as its own comment promised it would be** (*"when sound arrives it
  replaces this BODY"*). The beat's traced frame count still owns the interval — the song plays inside it
  and does not extend it. **`msys_stop` runs on every path**, including the silent one.
- **`MSYS_WIRED_SONG` is deliberate scaffolding.** One song, so a fault shows in one place rather than five.
  Widening it is deleting one comparison. **It also served as the bisect switch** — `-DMSYS_WIRED_SONG=6`
  reads and inits the player but matches no beat, which separated *"the read broke it"* from *"playback
  broke it"* in one run and gave §3D its control.

#### 3D — §1: the cost in the hold, with the control in the SAME beat

**★ THE FIRST ATTEMPT WAS INVALID AND IS RECORDED AS SUCH.** Comparing beat 1 (song) against beat 5 (silent)
gave "30% of the budget" — meaningless, because different beats do different work and beat 5 is the prologue
with 4,916 frames of its own. **The control has to be the same beat.**

| beat 1, 616 frames | spins/frame | FIRQ/frame |
|---|---|---|
| silent (`-DMSYS_WIRED_SONG=6`) | 2,634.7 | 0.00 |
| `s_Presents` | 2,483.6 | 4.98 |

**151.1 spins × 7 cycles = 1,058 cycles/frame = 3.54% of the 29,859-cycle VBL budget.**

For scale: P4.6 measured the capture player at 2.0%. The interpreter costs ~1.8× that, which is the decode
plus the VBL dispatch it now carries.

#### 3E — ★★★ §2: THE GATE FAILED, AND THE DEFECT IS MEASURED

**Jay, from a cold boot on the target, live-disk, sound on, RGB, 128 KB — verbatim:**

> ***"so the song plays and seems at the right time, but it's very choppy."***

**Both halves are load-bearing.** *"Plays and seems at the right time"* is the wiring working — the song
starts at the beat's entry. *"Very choppy"* is a real defect, and it is not subtle.

**Bisected first: the fault is in the PLAYER, not the intro.** Running `s_Presents` through the probe in
isolation emits all 1,766 toggle pairs but takes **455 frames against the model's 298** — median period error
0.54%, **worst 1,409%**.

**Then characterised:**

| period | pairs | share of pairs | **share of elapsed time** |
|---|---|---|---|
| ~1 ms | 1,572 | 89% | 27% |
| ~7-17 ms | 171 | 10% | 26% |
| **~154 ms** | **23** | **1.3%** | **★ 47%** |

**Twenty-three segments of ~154 ms, in a song whose notes are all 0.6-1.9 ms.** Those are the gaps.

**★★ THE MECHANISM, IDENTIFIED BY ARITHMETIC ON THE GENERATED TABLE.** 154 ms is what a **TINS=1 count
clocked at TINS=0** produces — a 228× stretch:

```
idx 30  FF91=$20 div=3 count=2249  -> TINS=1: 1.88 ms   TINS=0: 143.3 ms
idx 35  FF91=$20 div=2 count=2532  -> TINS=1: 1.41 ms   TINS=0: 161.3 ms
idx 36  FF91=$20 div=2 count=2391  -> TINS=1: 1.34 ms   TINS=0: 152.3 ms
idx 47  FF91=$20 div=1 count=2538  -> TINS=1: 0.71 ms   TINS=0: 161.7 ms
```

**The 143-162 ms band is exactly the range measured.** So on some path the timer is loaded with a fine-clock
count while `$FF91` still says slow clock.

**★★★ AND THIS IS WHY THE `s_Princess` EAR GATE COULD NOT HAVE CAUGHT IT.** `s_Princess` measured 774 frames
against 762 — 1.5% long, **no outliers at all**. It has ONE voice-2 note; `s_Presents` has fifteen. The 23
outliers are close to the number of note changes, which points at the note-change or voice-switch path rather
than at steady playback. *A gate on one song is a gate on one song.*

**NOT FIXED IN THIS DISPATCH, DELIBERATELY.** The next step is a targeted trace of `$FF91`/`$FF94`/`$FF95`
writes across a note change, which shows the ordering directly instead of inferring it. **Every defect in
this dispatch was found by measuring and every hypothesis reasoned from first principles was wrong** (§3A's
two, §3B's first fix, §3B.3's own-goal). Editing the FIRQ's timer path on inference at the end of a long
session is the one move the evidence argues against.

### 4 — Verification (AC-by-AC)

- **AC1 one intro song wired and playing from the real launch path; song named, load timed, read landing
  unseen** — **PASS** (§3C). `s_Presents`, beat 1; read in the opening burst before the first beat; `$0A00`
  is outside the draw window so the read cannot land visibly.
- **AC2 cost measured IN THE HOLD, against budget** — **PASS** (§3D). **1,058 cycles/frame = 3.54%**, control
  in the same beat. The first, invalid measurement is recorded rather than discarded.
- **AC3 scenery confirmed still decoupled** — **PARTIAL, and stated as such.** `flm_cad 2,2,3` is the
  *scene's* cadence (`cutscene_room.s:1216`), and no song plays during the scene — beat 5 carries
  `BEAT_SONG 0` and the scene is not a beat. The player has fully restored `$FF92`/`$FF93`/`$FF90` before it
  runs. **Mechanical evidence: `integ` PASSES**, including scene reach-and-return and read-before-reveal over
  20 reads and 769 swaps. **★ What is NOT independently measured is the flame cadence itself under a
  music-bearing intro** — it is decoupled by construction here rather than by measurement.
- **AC4 the probe fixed, with a seeded-failure confirmation** — **PASS** (§3A). Both directions shown.
- **AC5 Jay gates BY EAR AND EYE from a cold boot; words verbatim** — **★★★ GATED AND FAILED.** §3E.
  *"so the song plays and seems at the right time, but it's very choppy."* Start timing PASSED by his eye
  and ear; playback quality FAILED. **Stop timing, transition quality, torches and abort were not separately
  reported** — the chop dominates and the remaining questions are not answerable under it.
- **AC6 suites green 128 KB first, `integ` included; build verified by symbol** — **PASS** (§5).
- **AC7 route accounting present; Karateka untouched; `main` untouched** — **PASS** (§6).

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output, verbatim.**

`harness/smoke/run_suites.sh` (128 KB, §2K):
```
[suites] === introseq ===
[suites] === integ ===
[integ] PASS

[suites] ALL PASS
```

`run_introseq_test.sh`, the assertion list in full — every capture, after the interrupt fix:
```
loadm_from_disk PASS   capture_1_base PASS   capture_2_presents_up PASS
capture_3_presents_clear PASS   capture_4_byline_up PASS   capture_5_byline_clear PASS
capture_6_title_up PASS   capture_7_title_clear PASS   capture_1a_wipe_mid PASS
capture_8_prolog1 PASS   capture_9_prolog2 PASS   capture_10_title_reprise PASS
capture_11_done PASS     seq_magic PASS $5E92     beats_completed PASS (5 = six beats)
disk_reads_completed PASS 8       image_cannot_contain_screen PASS
```

`harness/smoke/run_interp_check.sh`, both directions:
```
normal  # PASS — it loaded, walked the stream, sounded and tore the FIRQ down.
        # player disk read: WD1773 status $10  carry 0  first bytes at $0A00 $7E0A
seeded  # FAIL — THE PLAYER'S DISK READ. Nothing that looks like the entry table landed.
        [interp_check] ★ seed caught — the probe reported the failure.
```

**Build verified by symbol** (`build/obj/introseq.map`, `build/obj/msys.map`):
```
Section: prog (build/obj/intro_seq.o)  load at 2000, length 03FF
Section: prog (build/obj/lz_unpack.o)  load at 23FF, length 008E
Section: code (build/obj/hal_build.o)  load at 7900, length 0444
Section: msys (build/obj/msys_player.o) load at 0A00, length 1168
[map_check] 5 map(s) clean — no overlap, nothing below $0E00.
```
★ The intro grew 42 bytes (`$3D5` → `$3FF`) and stays clear of `SCENE_BASE` at `$2500`.

**25.2 bundled-artifact grep:** N/A — no sibling-import artifact.

**25.3 operator-runtime-smoke:** **★★★ FAILED — Jay, live-disk, RGB, 128 KB, sound on, cold boot.**
> ***"so the song plays and seems at the right time, but it's very choppy."***

Not self-certified, and not partially credited: the start timing passing does not make this a pass.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING. This report contains** §3's probe fix with its seeded confirmation, §1's one wired song
with its load, its cost and its scaffolding switch, and §2's gate — **run, and failed.**
**It does NOT contain** §4's formula applied to the remaining eleven songs, and it must not until the chop is
fixed: **multiplying a defect by twelve is the specific thing this dispatch's one-song design exists to
prevent.**

**Reactive deviations (§22.5):**

1. **§3 was done FIRST**, before §1. The dispatch orders it last. Without a working probe there was no
   instrument to verify §1 with, and its silence would not have been evidence.
2. **`harness/smoke/run_introseq_live.sh` now runs with SOUND** (`MUTE=1` restores the old behaviour). It
   passed `-sound none` from P3.3 onward, correctly — the intro had no audio. A silent run can no longer
   answer the question asked of it. *Also corrected `-sound sdl` → `-sound auto`: MAME refused the value on
   every launch, and a runner that prints a rejection each time trains its reader to ignore its output.*
3. **`introseq_test.lua`'s `disk_reads_completed` raised 7 → 8.** The eighth read is the player and is
   intended. **All eight are named in the failure string** so the number cannot become one nobody can
   account for.
4. **The first cost measurement was invalid** (§3D) — a different beat is not a control. Recorded rather
   than quietly replaced.

### 7 — Uncertainty flags

- **★★★ THE CHOP IS DIAGNOSED BUT NOT FIXED** (§3E). The mechanism — a TINS=1 count clocked at TINS=0 — is
  established by arithmetic on the generated table matching the measured 143-162 ms band. **The exact code
  path is NOT established**; it is inferred from the outlier count tracking the note changes. A
  `$FF91`/`$FF94`/`$FF95` write trace across a note change would settle it.
- **★★ THE EAR GATE HAS NOW COVERED TWO SONGS AND THEY DISAGREE.** `s_Princess` passed at 1.5% long with no
  outliers; `s_Presents` is 53% long with 23 of them. **Nothing says the other ten behave like either one.**
- **★ AC5's other questions are unanswered, not passed** — stop timing, transition quality, torch flicker
  and abort. The chop dominates and they cannot be judged under it.
- **AC3's flame cadence is decoupled by construction, not by measurement** (§4).
- **The player writes `$FF91` wholesale** (`$00`/`$20`), which also clears INIT1's MMU task-select bit.
  Harmless while the task bit is 0, which DECB leaves it — but it is an assumption, not a check.
- **The FIRQ now services the VBL**, so the player is load-bearing for the intro's frame timing whenever a
  song plays. A defect in the player is now also a defect in the intro's clock.

### 8 — Follow-up candidates

- **★★★ THE CHOP** — trace `$FF91`/`$FF94`/`$FF95` across a note change and a voice switch. Nearest item;
  everything else waits behind it.
- **Then §4's formula**: the remaining eleven songs, same entry table, same call, same tear-down.
- **Re-run the gate on `s_Presents`** and, when it passes, on at least one two-voice song other than it.
- **`$FF91` written wholesale** — read-modify-write the TINS bit instead, or document the assumption.
- Carried: the drift acceptance; gameplay's colour mode; the per-cue control policy; the stale `pop.link`
  stack comment; `Demo` unbuilt.

### 9 — User interaction during task

1. **The dispatch's framing is Jay's** — *"let's just wire in the first and verify I hear and see it, and
   then we'll have the formula for the rest. And fix the probe."*
2. **The gate, from a cold boot on the target** — *"so the song plays and seems at the right time, but it's
   very choppy."* **§3E and AC5.**
3. **"update report"** — this document.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-19-two-registers-one-latch-the-cost-of-a-second-interrupt-source.md` — committed and
pushed to the pool.

### 11 — Commit

`604174b` (pushed to origin/wip before this report). This dispatch:

| | |
|---|---|
| `95018de` | §3 — the probe fixed; the error handler was in the success path |
| `5aede70` | §1 — `s_Presents` plays in the intro; the GIME's shared interrupt latches |
| `89b5165` / `604174b` | the live gate runs with sound, with a value MAME accepts |
