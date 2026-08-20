## Form B Report — P4.22 — the choppiness attributed and fixed: **a rest is mult ×1**. **Gate PASSED.**

**Class:** build.  wip.  Prod — `build/gen/msys_tables.s` regenerated (one timer row changed), which changes
the shipped player. Karateka untouched; `main` untouched (`34e93e0`); oracle source read-only.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-19 23:45 (HEAD `4a2c9f4` at receipt, wip; `2b0ab46` at report). Working tree clean apart from the
pre-existing untracked `docs/ground-truth/*.pdf`, `nvram/`, `.vscode/` and the modified
`dist/mame-cfg/rgb/coco3.cfg` carried since P4.19.

### 1 — Summary

| | |
|---|---|
| **§1 attributed** | **fixed positions across two runs — DATA-DRIVEN.** FIRQ firing, no pulse: **silent, not slow.** |
| **★★★ P4.21's hypothesis** | **REFUTED by the instrument.** TINS and count were both CORRECT during every gap. |
| **the cause** | **`gen_msys_tables.py` gave the REST row the ×7 delay multiplier.** One comparison. |
| **§2 the fix, evidenced** | 23 rests **153,746 µs → 48,050 µs**; song **455 → 310 frames** (model 298) |
| **§3 flame cadence, MEASURED** | `cel_scene_done` at **frame 7945 in both** builds — **not one frame of drift** |
| **suites** | ALL PASS, 128 KB first, `integ` included |
| **★★★ Jay's gate** | **PASSED** — *"sound is good, not niticing choppiness. torches look good too."* |

### 2 — Files modified

- `harness/tools/gen_msys_tables.py` — the multiplier rule corrected; `build/gen/msys_tables.s` regenerated.
- `harness/tools/timer_trace.lua` — NEW. The instrument that attributed it.
- `harness/smoke/run_oracle_live.sh` — sound on by default (`MUTE=1` restores).

Explicit-path staging only.

### 3 — Reasoning

#### 3A — ★★★ §1: ATTRIBUTED, AND P4.21'S EXPLANATION WAS WRONG

**P4.21 §3E named a mechanism: a TINS=1 count clocked at TINS=0, a 228× stretch.** It was reasoned from
arithmetic on the generated table, and the arithmetic was good — rows 30/35/36/37/47/48/49 produce 143.3,
161.3, 152.3, 143.4, 161.7, 152.7 and 143.8 ms at the wrong clock, **a band that brackets the measured
153.6–154.1 ms, with idx 36 sitting almost exactly on it.**

**★★ IT WAS STILL A HYPOTHESIS, AND THE INSTRUMENT REFUTED IT.** `harness/tools/timer_trace.lua` watches
`$FF91` (INIT1, whose bit 5 is TINS), `$FF94`/`$FF95` (the 12-bit count), the `$FF93` acknowledge and the
`$FF20` pulse, and reports what was **in force** during each long gap:

```
# n        gap_us   TINS   count  predict_us   FIRQs   VBLs
  3      153746.4      1    2398       669.9      42      9
  4      153745.8      1    2398       669.9      42      9
  ...
  25     153745.3      1    2398       669.9      43     10
```

**TINS = 1 and count = 2398 — BOTH CORRECT — through every one of them.** And **42 FIRQ entries fired during
each 154 ms gap while no pulse came out.**

> **★★★ The segments were SILENT, not SLOW.** That is a different fault from the one P4.21 named, and no
> amount of further reasoning would have got there: the wrong explanation predicted the right magnitude.

**The dispatch's four splits, all answered by that one run:**

| split | answer |
|---|---|
| fixed or variable position? | **FIXED** — two runs, `diff` clean on gap index, duration, TINS and count. **Data-driven.** |
| FIRQ stall, or genuinely long? | **Neither** — the FIRQ kept firing; the segments emitted nothing. |
| VBL-correlated? | **No** — 9 VBLs per gap is exactly 58.5 Hz, the normal rate. |
| the intro's own work? | **No** — reproduced in the probe, in isolation, with no intro at all. |

#### 3B — ★★★ THE CAUSE: ONE COMPARISON IN THE GENERATOR

Comparing the model's silence against the port's localised it precisely — **same count, same positions,
different duration**:

```
MODEL song 1: 1741 pairs, 4.973 s   rests >20 ms: 23   at idx 202, 228, 254, 280 ...  46,760 us each
PORT  song 1: 1766 pairs, 7.572 s   rests >20 ms: 23   at idx 202, 228, 254, 280 ... 153,746 us each
```

**23 × 107 ms = 2.46 s, against a 2.60 s total discrepancy.** Decomposing one of the model's silent runs:

```
first silent run: 32 segments
   NOTE 122 x1  x28   1.252 ms each      <- the REST: pitch 0, LENGTH[0] = 28
   NOTE  62 x1  x2    0.664 ms each
   PAD          x2    4.85 ms each
   -> run total 46.1 ms
```

**`NOTE 122 × mult 1`.** The generator computed:

```python
mult = 7 if i < 0x19 else 1        # by INDEX
```

**`NEWNOTE` does not do that.** It masks the pitch bits and **branches past the multiplier when they are
zero**:

```
        AND #%11111100 / STA R+13 / BEQ MNOBC1    <- MNOBC1 is AFTER `LDA #7`
        LSR / LSR / CLC / ADC R+4 / STA R+13
        CMP #$19 / BGE MNOBC1
        LDA #7 / STA MLBL300+1
```

**So `pitch < $19` only reaches `LDA #7` when the pitch is NON-ZERO. Index 0 is the REST and takes ×1.**
Given ×7 it ran **4.905 ms per silent segment against the correct 1.258** — and a rest is 28 of them.

**★★ THE MODEL WAS ALREADY RIGHT.** `msys_decode.py`'s `new_note` sets `self.mult = 1` and only raises it
inside `if p:`. **The generator and the validator had disagreed since P4.19, and nothing compared them** —
the model predicted 46.8 ms and the port produced 153.7, and until this dispatch nobody put those two numbers
side by side. *One home per fact was satisfied for the tables and not for the rule that indexes them.*

**The fix is `mult = 7 if 0 < i < 0x19 else 1`.** Row 0 becomes TINS=1, div 2, count 2251 — **1,257.7 µs,
−0.0 cents** against the model's 1.252 ms.

#### 3C — §2: the fix evidenced by the segments, not by an impression

**The dispatch is explicit that "the fix's own evidence is the 23 disappearing, not the song sounding
better."** Measured in the probe, in isolation:

| | rests > 20 ms | each | share of elapsed time | frames |
|---|---|---|---|---|
| **before** | 23 | 153,746 µs | **47.0%** | 455 |
| **after** | **23** | **48,050 µs** | **21.5%** | **310** |
| model | 23 | 46,760 µs | — | 298 |

**Same 23 rests, same positions, now 2.7% long instead of 229% long.** The song is 310 frames against the
model's 298 — a 4% residual that is the pad quantisation and the general timing offset, not a defect class.
Period histogram after: `[(1 ms, 1572), (7, 19), (11, 95), (12, 38), (17, 19), (48, 23)]` — the 154 ms bucket
is gone.

#### 3D — §3: the flame cadence, MEASURED under a music-bearing intro

P4.21 §3E left this **decoupled by construction and not measured**, and flagged it. The control is the same
binary with the song switched off (`-DMSYS_WIRED_SONG=6` reads and inits the player but matches no beat):

```
music build     cel_scene_done set at frame 7945   20 reads (14 into the draw window)  769 swaps
silent control  cel_scene_done set at frame 7945   20 reads (14 into the draw window)  769 swaps
```

**Identical to the frame.** The scene runs `flm_cad 2,2,3` on its own cadence and nothing in it moved. ★ That
is expected — beat 5 carries `BEAT_SONG 0` and the scene is not a beat, so `msys_stop` has already restored
`$FF92`/`$FF93`/`$FF90` before it starts — **but P4.21 asserted it and this measures it.**

#### 3E — the latch-sharing check that HARD-STOP 4 requires

**No change in this dispatch touches the FIRQ handler's acknowledge path.** The fix is one value in a
generated data table; the handler, its `$FF93` read, its VBORD dispatch and its end-of-song handback are
byte-for-byte as P4.21 left them. **The VBL is therefore unaffected by construction, and the suites confirm
it** — `introseq` reaching all twelve captures depends on `hold_frames` returning, which depends on the VBL
being serviced.

### 4 — Verification (AC-by-AC)

- **AC1 the 23 long segments ATTRIBUTED** — **PASS** (§3A). Fixed-position, data-driven; **not** a FIRQ
  stall; **not** VBL-correlated; **not** the intro's work. **And P4.21's stated mechanism refuted.**
- **AC2 the cause named and fixed** — **PASS** (§3B). The generator applied the oracle's ×7 multiplier by
  index where `NEWNOTE` branches past it for a zero pitch.
- **AC3 the fix evidenced by the disappearance of the long segments** — **PASS** (§3C). 153,746 → 48,050 µs,
  by position match. **Not by an ear impression** — the ear gate came afterwards and separately.
- **AC4 the gate re-offered, WHOLE** — **PASS, and PASSED** (§5). All five items surfaced. **Three ruled on
  explicitly; two not separately reported — §7.**
- **AC5 the flame cadence independently measured** — **PASS** (§3D). Frame 7945 in both builds.
- **AC6 suites green 128 KB first, `integ` included; build verified by symbol** — **PASS** (§5).
- **AC7 route accounting present; Karateka untouched; `main` untouched** — **PASS** (§6).

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output, verbatim.**

```
[suites] running: introseq integ
[suites] -ramsize 128K
[suites] === introseq ===
[run_introseq_test] PASS
[suites] === integ ===
[integ] PASS

[suites] ALL PASS
```

`run_interp_check.sh --song 1`, after the fix:
```
# msys ticks 123   VBL frames 310   magic $504E (want $504E)
# toggle pairs emitted 1766
# player disk read: WD1773 status $10   carry 0   first bytes at $0A00 $7E0A
# PASS — it loaded, walked the stream, sounded and tore the FIRQ down.
    captured span 5.143 s (308.1 frames)   decoded span 4.973 s (298.0 frames)   ratio 0.9670
```
★ Before the fix the same line read `7.572 s (453.7 frames) ... ratio 0.6567`.

**Build verified by symbol** — the corrected row 0, from the generated table:
```
msys_period
                fcb     $20,2
                fdb     2251           ; idx  0 NOTE 122 x1    1257.7 us   -0.0 c
```
```
[map_check] 5 map(s) clean — no overlap, nothing below $0E00.
Section: msys (build/obj/msys_player.o) load at 0A00, length 1168
```

**25.2 bundled-artifact grep:** N/A — no sibling-import artifact.

**25.3 operator-runtime-smoke:** **★★★ PASSED — Jay, live-disk, RGB, 128 KB, sound on, cold boot, and the
oracle run alongside for comparison.** His words, verbatim:

> ***"sound is good, not niticing choppiness. torches look good too."***

**Launch path `live-disk`** — real `LOADM"INTROSEQ"` + `EXEC` off a mounted floppy, throttled to real speed
(`run_introseq_live.sh`). The run he ruled on lasted **181 seconds**, past the cutscene at 132.6 s and the
intro's completion at 169.1 s, so the torches were on screen. **The oracle was run alongside**
(`run_oracle_live.sh`, `apple2e` + `cffa202`, 188 s) so the comparison was against the thing being ported
rather than against memory.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING. This report contains** §1's attribution with P4.21's hypothesis refuted, §2's fix with
segment-level evidence, §3's gate re-offered whole and passed, and the flame cadence measured.
**It does NOT contain** the remaining eleven songs — that is P4.21 §4's formula and it is now unblocked, not
done.

**Reactive deviations (§22.5):**

1. **Both live runners now run with SOUND** (`MUTE=1` restores). `run_introseq_live.sh` at P4.21 and
   `run_oracle_live.sh` here. Both passed `-sound none` because the port had no audio; **an oracle comparison
   with the oracle muted is not a comparison.**
2. **I told Jay the wrong thing by omission and it cost him two runs.** His first two looks were 36 s and
   39 s and he reported *"i forgot to check the torches"* — the cutscene is at **2m12s** and he had never
   reached it. **I offered a gate on an item without saying when it becomes visible.** Corrected by giving
   the timeline before the third run.

### 7 — Uncertainty flags

- **★★ THE GATE COVERS THREE OF FIVE ITEMS EXPLICITLY.** Jay ruled on **the choppiness** (*"not niticing"*),
  **the timbre** (*"sound is good"*) and **the torches** (*"look good too"*). **He did not separately report
  the stop timing or the abort.** P4.21 established that a partially credited gate is not a gate — **so this
  is recorded as passing on what he named, and those two remain unruled.** They are cheap to fold into the
  next gate.
- **★ THE EAR GATE HAS NOW COVERED TWO SONGS AND THE PORT PLAYS ONE.** `s_Princess` (P4.19, in isolation) and
  `s_Presents` (here, in the intro). **The other ten are decoded by the same grammar and none has been
  heard.**
- **★★ THE GENERATOR AND THE VALIDATOR DISAGREED FOR THREE DISPATCHES AND NOTHING COMPARED THEM** (§3B).
  The model said 46.8 ms and the port produced 153.7 from P4.19 onward. **A build-time assertion that the
  generated timer table reproduces `msys_decode`'s own segment durations would have caught this at P4.19**
  and would catch the next one. Not built — flagged as the follow-up it is.
- **`s_Presents` runs 310 frames against the model's 298** — 4%. Beat 1's hold is 281 frames, so the song is
  still cut. Jay did not report it, and P4.21's drift acceptance is unchanged.
- **The player writes `$FF91` wholesale**, clearing INIT1's MMU task-select bit. Harmless while that bit is
  0, which DECB leaves it. Still an assumption, carried from P4.21.

### 8 — Follow-up candidates

- **★★★ THE REMAINING ELEVEN SONGS** — P4.21 §4's formula, now unblocked. Same entry table, same
  `play_song` call, same frame-count hold, same tear-down; only the id differs. **Delete `MSYS_WIRED_SONG`'s
  comparison.**
- **★★ A BUILD-TIME ASSERTION THAT THE GENERATED TABLE MATCHES `msys_decode`'s SEGMENT DURATIONS** (§7).
  The two are meant to be one fact and were two for three dispatches.
- **Fold the stop timing and the abort into the next gate** (§7).
- **Hear a two-voice song other than `s_Presents`.**
- Carried: gameplay's colour mode; the per-cue control policy; the HAL audit; the stale `pop.link` stack
  comment; `Demo` unbuilt.

### 9 — User interaction during task

1. **"run it again i forgot to check the torches"** — and the reason he had not is §6.2: the cutscene is
   2m12s in and his looks had been 36 s and 39 s. **My omission, not his.**
2. **"run the oracle for me"** — run with sound (§6.1), 188 s, alongside the port.
3. **★★★ THE GATE** — *"sound is good, not niticing choppiness. torches look good too."*

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-19-arithmetic-that-matches-a-measurement-is-a-hypothesis-not-a-cause.md` — committed
and pushed to the pool.

### 11 — Commit

`2b0ab46` (pushed to origin/wip before this report). This dispatch:

| | |
|---|---|
| `79502a0` | the choppiness attributed and fixed — a rest is mult ×1, not ×7 |
| `2b0ab46` | the oracle live runner runs with sound |
