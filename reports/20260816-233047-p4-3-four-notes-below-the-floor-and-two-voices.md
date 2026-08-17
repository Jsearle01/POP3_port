## Form B Report — P4.3 — four notes below the floor, and two voices

**Class:** recon (bounded). wip. **Nothing built, nothing designed, no instrument on any disk.**
No `src/`, `content/`, `link/` or `build.bat` change.

**★★★ SUB-FLOOR NOTES EXIST: 4 of the 76 `NOTE` entries fall below the GIME timer's floor, the
lowest by 10.1%. HARD-STOP 3 applies — reported, and no remedy proposed.**

**★★★ AND THE PLAYER IS TWO-VOICE, established from the code and not from vocabulary: `MPLAY`
opens `LDA R+15 / BEQ NO2VOI` — the label spells it — and when the flag is set it alternates
`R+21 EOR #1` and jumps to a second player. The one-bit speaker carries them by TIME-SLICING, one
voice per `mplay` call.**

**★★ THREE CORRECTIONS TO MY OWN RECORD, all found by doing the arithmetic rather than
re-reading: the table has 76 entries and I twice wrote 75; the floor is 437.1 Hz and I wrote
~468; and "the entire audio signal is frequency and duration" was too strong — there are
amplitude and envelope tables.** §3D.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-16T23:30:47-04:00 (HEAD `115044a`, wip). Karateka untouched. `main` untouched. Oracle
source read-only and not executed. Pre-existing and not mine: `dist/mame-cfg/rgb/coco3.cfg`.

---

### 1 — Summary

| | |
|---|---|
| **★★★ the mapping** | **`period = 56 + 10 × NOTE` cycles**, derived from the loop — **the volume term cancels** |
| **★★★ sub-floor** | **4 of 76** entries below **437.1 Hz**; lowest **393.1 Hz**, **10.1% below** |
| **★★ range** | 393.1 Hz … 6,989.6 Hz — **4.15 octaves** |
| **★★★ voices** | **TWO**, off by default, enabled by a `%01000000` byte in the song stream |
| **★★ how one bit carries two** | **time-slicing** — `MPLAY` alternates and hands every other call to `MMPLAY` |
| **★★★ NOT established** | **whether any SONG reaches the four** — needs the song table, which needs the open file mapping |
| **★★ correction** | the table has **76** entries; P4.1/P4.2 said 75 |
| **★★ correction** | the floor is **437.1 Hz**; P4.2 said ~468 — that was the tone I *tested*, not the ceiling |
| **★★ correction** | there ARE amplitude/envelope tables — P4.2's "frequency and duration" was too strong |

### 2 — Files modified

- `harness/tools/note_freq.py` — NEW; derives the mapping and checks it against the floor
- `reports/20260816-233047-…md` — this

### 3 — Reasoning

**3A — ★★★ THE PERIOD→FREQUENCY MAPPING, DERIVED (AC1).**

`MSYS.S`'s tone segment, with 6502 timings:

```
MSEG    LDY R+3        3     R+8 = NOTE[index]   the note period
MBASS1  LDA HM1,Y      4     R+6 = VTBL[...]     the VOLUME
        BMI MSEGL4     2
        INC R+3        5
        TAY            2
        LDA VTBL-1,Y   4
        STA R+6        3
        SEC            2
        SBC R+8        3     A = R+6 - R+8
        TAY            2
MADJLP  INY / BNE      5/it  -> (R8 - R6) mod 256 iterations
MLBL300 LDY #1         2
MLMDI   LDA R+8        3
        SEC            2
MDLOOP  SBC #1 / BNE   5/it  -> R8 iterations
        DEY / BNE      4
        LDY R+6        3
        BEQ MFIZZLE    2
M30A    LDA $C030      4     <-- TOGGLE
MVDIT   DEY / BNE      5/it  -> R6 iterations
M30B    LDA $C030      4     <-- TOGGLE
MFIZZY  DEX            2
        BNE MSEG       3
```

★★★ **THE VOLUME TERM CANCELS, AND THAT IS THE WHOLE MECHANISM.** The three loops cost
`5(R8−R6) + 5·R8 + 5·R6 = 10·R8` — independent of `R6`. So the **period** is set by the note and
the **pulse width** by the volume: constant-period, variable-duty, which is how a one-bit speaker
produces amplitude at all. Two toggles per pass = one full cycle.

```
    period = 56 + 10 × NOTE cycles          f = 1,020,484 / period
```

★ **The 56 is hand-counted and is the only soft number, so the tool reports the verdict's
sensitivity to it rather than quoting one figure:**

```
   overhead   sub-floor entries   lowest Hz
   0          4                   401.8
   28         4                   397.4
   56         4                   393.1
   84         5                   388.9
   120        6                   383.6
```

**At the low notes `10×NOTE` is ~45× the overhead, so the verdict is the same across every
plausible count.** The exact frequency is not; the verdict is.

**3B — ★★★ THE ANSWER: FOUR ENTRIES ARE BELOW THE FLOOR (AC3).**

The floor is `1 / (2 × 4095 × 279.365 ns)` = **437.1 Hz**.

```
  idx  NOTE  freq Hz   vs floor
  1    254   393.1     ★ BELOW by 44 Hz (10.1%)
  2    238   418.9     ★ BELOW by 18 Hz (4.2%)
  3    226   440.6       above by 4 Hz
  25   250   399.3     ★ BELOW by 38 Hz (8.7%)
  26   234   425.9     ★ BELOW by 11 Hz (2.6%)
  27   222   448.4       above by 11 Hz
```

★★ **The four are indices 1, 2, 25 and 26 — the TOP of each of the two descending runs**, i.e.
**the lowest notes of two ranges.** Index 3 clears the floor by 4 Hz and index 27 by 11: the
boundary cuts through the table rather than sitting outside it.

★ **The table's two-run shape was a lead in the dispatch and it survives as a description, not a
finding:** entries 0-24 and 25-48 are two descending runs, 49-75 a third finer one. **What those
runs mean — octaves, instruments, or voice ranges — is not established**, and the sub-floor
entries being the head of the first two is consistent with several readings.

**3C — ★★★ WHAT IS NOT ESTABLISHED, AND WHY I STOPPED (AC2).**

**Whether any SONG uses those four indices is NOT established.** AC2 asks for the lowest note the
songs actually use, distinguished from the lowest the table can express — ★ **and I have the
first and not the second.**

I did decode the note format, which is a step toward it [`MSYS.S:275-300`]:

```
NEWNOTE  INC R+0 / INC R+0        the song pointer advances TWO BYTES per note
         LDA (R+0),Y   ; Y=0      byte 0
         INY / LDA (R+0),Y        byte 1 — ZERO terminates the song
         TXA / AND #%11111100     the top 6 bits of byte 0...
         LSR / LSR                ...>>2 = the NOTE index, 0..63
         CLC / ADC R+4            ...plus a per-song TRANSPOSE
```

★★ **And the transpose is why a scan would be inference rather than measurement.** The index a
byte produces depends on `R+4`, which is per-song state; and finding where each song starts needs
the `MADRLO`/`MADRHI` table at `$D000`, which needs the `MUSIC.SET*` → `loadmusic1/2/3` mapping —
**explicitly left open at P4.1 because the file sizes do not agree with the sector lists**, and
§3 of this dispatch forbids resolving it by inference.

★★★ **So a histogram over the vendored bytes would have produced a number that looked like an
answer and was not one.** Reported as open, with exactly what it needs: the set mapping, then the
address table, then the per-song transpose.

**HARD-STOP 3 fires here regardless** — sub-floor notes exist in the table, and the remedies
(TINS=0 at 63.695 µs and far too coarse; transposing the songs up; accepting four notes wrong;
a software divider on top of the timer) all have audible consequences. **None is proposed.**

**3D — ★★ THREE CORRECTIONS TO MY OWN RECORD.**

| | what I wrote | what it is |
|---|---|---|
| **table size** | *"a `NOTE` table of 75 period values"* — P4.1 §3B, repeated in P4.2 §3C | **76.** 13+12+12+12+12+12+3. I carried a number from the dispatch's restatement instead of counting the rows. |
| **the floor** | *"~468 Hz floor at TINS=1"* — P4.2 §3C and its summary table | **437.1 Hz.** 468 was the frequency my probe's `TMR_LO = 3822` produced — **a tone I chose to test**, not the value at the timer's 4095 ceiling. I derived a constraint from an experimental parameter. |
| **what the signal is** | *"the entire audio signal is described by frequency and duration"* — P4.2 §3C | **Too strong.** `AMPTBL`, `ENVTBL`, `ENVTBH` and the `VTBL` pulse-width mechanism mean **amplitude and envelope** are in there too. Still no samples — that part stands — but a rendition that ignores the envelope will not sound like the oracle. |

★★ **All three came from doing the arithmetic, not from re-reading.** The floor one is the worst:
it made a *softer* constraint look *harder* by 7%, and it is the constraint this whole dispatch
was called to check.

**3E — ★★★ TWO VOICES, ESTABLISHED FROM THE PLAYER (AC4).**

```
MPLAY   LDA R+15         the two-voice flag
        BEQ NO2VOI       <- the label spells it out
        LDA R+21
        EOR #1           alternate...
        STA R+21
        BNE NO2VOI
        JMP MMPLAY       ...and every other call goes to the SECOND player
```

- `MINIT` clears `R+15` [`:272`] — **songs start monophonic.**
- A song **turns it on from the stream**: a byte `%01000000` sets `R+15 = 1`, `R+21 = 1`, and
  saves the current pointer into `R+22` as the second voice's cursor [`:383-390`].
- `MMPLAY`/`MMNNOTE`/`MMSEG` are a full second copy of the note machinery, ending in the
  `M20A`/`M20B` toggle pair against `M30A`/`M30B` for voice one.

★★★ **HOW ONE BIT CARRIES TWO: TIME-SLICING, not mixing and not duty-cycling.** `mplay` services
voice 1 on one call and voice 2 on the next. The two are never sounding simultaneously in any
electrical sense — the ear integrates the alternation.

★★ **Two consequences worth stating, neither of them a design:**

1. **The FIRQ budget does not double.** Only one voice is toggling at any moment, so the interrupt
   rate is that of the *currently active* voice — P4.2's `rate × ~55 cycles` still prices it.
2. ★ **The CoCo3's DAC could mix them properly, and that would NOT be faithful.** A real two-voice
   mix sounds different from — arguably better than — an alternating one. §2I says it must sound
   *right*, and right is the oracle's sound. **Interleaving is the faithful choice and the cheaper
   one, which is a rare alignment; it is still Jay's call, and it is not made here.**

**3F — §2H's THREE CHECKS.**

1. **A second mechanism for a different object class?** ★ **Yes, and it is §3E:** there is an
   entire second copy of the player. A reading of the one-voice path alone — which is what P4.1
   and P4.2 both did — makes the player look monophonic, and `MMPLAY` sits 250 lines away.
2. **The calling routine.** The note index is not a song byte: it is `(byte0 >> 2) + R+4`, and
   **the transpose is what makes a scan of the data meaningless without per-song state** (§3C).
3. **Grep the reports.** P4.1 §3D wrote *"two such blocks (`M30x` and `M20x`), which is **not**
   established to be two voices and should not be read as such."* ★ **That caution was correct to
   write and the inference it declined to make turns out to be true** — the flag and the
   alternation are what establish it, not the block names.

### 4 — Verification (AC-by-AC)

- **AC1 — the mapping derived from the delay loop; all entries compared.** §3A, §3B.
  `harness/tools/note_freq.py`, with a sensitivity table so the hand-counted overhead is visible
  rather than load-bearing.
- **AC2 — the lowest note the songs USE, distinguished from the table.** ★ **NOT ESTABLISHED**, and
  §3C says exactly why and what it needs. **The table's lowest is 393.1 Hz.**
- **AC3 — sub-floor notes quantified; no design proposed.** **4 of 76**; indices 1, 2, 25, 26; the
  worst 10.1% below. No remedy proposed.
- **AC4 — voice count from the player; how one bit carries them.** §3E. **Two, time-sliced.**
- **AC5 — nothing built; no instrument on any disk.** Only `note_freq.py`, an offline reader.
- **AC6 — suites green, 128 KB first.** §5.
- **AC7 — route accounting; Karateka; `main`.** §6.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim).**

```
# GIME floor: 1/(2 * 4095 * 279.365 ns) = 437.1 Hz
  entries          76
  period range     254 .. 9  ->  393.1 Hz .. 6989.6 Hz
  span             4.15 octaves
# ★★★ 4 of 76 TABLE ENTRIES FALL BELOW THE FLOOR.
#   lowest: NOTE[1] = 254 = 393.1 Hz, which is 10.1% below 437.1 Hz.

[suites] retired at P3.103: probe cel compiled mode anim room walk
[suites] -ramsize 128K
[suites] === introseq ===   [run_introseq_test] PASS
[suites] === integ ===      [integ] PASS
[suites] ALL PASS
```
`[hal-sync] OK`. ★ `room` and `walk` are retired per Jay's P4.2 ruling, **with what went with them
already named in `retired.sh` and `run_suites.sh`** — the byte-exact pixel comparison, the
per-page signature guard, the bank-mapped-at-capture assertion, the phase-occupancy census and the
two-run stability check.

**25.2 bundled-artifact grep:** N/A — nothing built or bundled. **No disk was touched.**

**25.3 operator-runtime-smoke: N/A — no port behaviour changed.** No emulator was run this
dispatch.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** Against §4's seven criteria: **AC1, AC3, AC4, AC5, AC6, AC7 in full; AC2
NOT ESTABLISHED and reported as such** (§3C) rather than answered by a scan that would have looked
like an answer.

**Reactive deviations (§22.5):** none. Nothing was modified; the oracle was read only.

★ **The three corrections in §3D are to my own prior reports, not deviations from this dispatch** —
but they change what P4.2's summary table says, and P4.2 is already on `wip`, so they are stated
here where the next reader meets them.

Karateka untouched. `main` untouched. Oracle read-only, never executed.

### 7 — Uncertainty flags

- **★★★ Whether any song reaches the four sub-floor notes is unknown** (§3C). **The whole
  practical weight of this finding depends on it** — four unreachable table entries would be a
  non-issue, and four notes in the princess's theme would not.
- **★★ The 56-cycle overhead is hand-counted from a listing**, not assembled or executed. The
  sensitivity table shows the verdict survives 0-120; **the frequencies themselves are ±3%.**
- **★ The Apple's 1.020484 MHz is the nominal NTSC figure** and ignores the "long cycle" every 65;
  that is a sub-0.1% effect and does not move the verdict.
- **★ What the table's three runs MEAN is not established** (§3B) — only that the sub-floor
  entries head the first two.
- **★ The envelope tables are found, not read.** `AMPTBL`/`ENVTBL`/`ENVTBH` exist and shape the
  pulse width; **what they do to a note is unexamined.**
- Carried: the `MUSIC.SET*` mapping; no song decoded; tail silence (Jay's); the FIRQ tear-down on
  abort; `Demo` unbuilt; the cel bank does not survive the 16-colour mode.

### 8 — Follow-up candidates

1. **★ Resolve the `MUSIC.SET*` mapping and decode the address table** — it is now the gate on
   AC2, on the reached-note set, and on any rendition. **Everything downstream waits on it.**
2. **Read the envelope tables** (§3D, third correction) — a rendition that ignores them will not
   sound like the oracle even at the right pitches.
3. Read Hewlett's `MIDI-2-CoCo-Converter` players for per-interrupt cost and voice handling
   (carried from P4.2).
4. Measure the port's headroom during a song HOLD (carried from P4.2) — still the number that
   prices the design.

### 9 — User interaction during task

None.

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-16-a-constraint-derived-from-an-experimental-parameter.md`

### 11 — Commit

See below — pushed to origin/wip before this report.
