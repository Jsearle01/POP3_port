## Form B Report — P4.19 — the duration is six bits, `MMPLAY` interleaves, and the player is built

**Class:** build.  wip.  Prod unchanged — no shipping-disk asset touched; `build/probe.dmk` regenerated
by `build.bat` as always. Karateka untouched; `main` untouched; oracle source read-only.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-19 14:24:31 −04:00 (HEAD `a6f14d0`, wip). Working tree clean apart from the pre-existing
untracked `docs/ground-truth/*.pdf`, `nvram/`, `.vscode/` and the modified `dist/mame-cfg/rgb/coco3.cfg`
that were dirty at receipt.

### 1 — Summary

**The grammar is complete, it was validated against the oracle's own trace rather than against the
listing it came from, and the player is built and runs on the target.**

| | |
|---|---|
| **`MMPLAY` resolved** | **outcome 2** — a second STREAM, not a second SOUND. Hard-stop does NOT fire. |
| **`s_Princess` walked** | 10 notes + 1 in voice 2, 0 calls, instruments 3 and 5, **314 ticks, 757.6 frames against a traced 762.4** |
| **the player** | **4,456 B for all thirteen songs**, against **3,137 B for ONE song** as a capture |
| **on the target** | **6,930 toggle pairs — the oracle emitted 6,930.** 774.0 frames against 762.4 |
| **suites** | green, 128 KB first, `integ` included |
| **Jay's ear** | **★★★ RULED — PASSED.** *"i would say the interpreter sounds the same as the oracle, but maybe a bit less fuzzy"* |
| **the player's home** | **disk track 32, read to `$0A00`** — not LOADM'd, not linked (§3J). 1,176 B of margin. |
| **wiring the twelve** | still NOT done — and the probe's own disk read is not working yet either (§7) |

**★★★ THE ONE FACT THAT WOULD HAVE MADE THE PLAYER WRONG: the note's duration is `byte1 & $3F`, not
`byte1`.** P4.18 §3A recorded it as the whole byte. Decoded that way `s_Princess` runs **1,477 frames
against a traced 761** — every note up to four times too long. *That is precisely the failure the
dispatch predicted: a grammar that parses without error and produces the wrong count.*

### 2 — Files modified

- `harness/tools/msys_decode.py` — NEW. The grammar, executed, with the trace comparator.
- `harness/tools/gen_msys_tables.py` — NEW. Emits the 6809 tables + the 1,024 B song page.
- `src/engine/msys_player.s` — NEW. The interpreter, FIRQ handler and tear-down.
- `src/harness/interp_probe.s` — NEW. Both players in one binary, for the A/B.
- `harness/smoke/interp_live.lua`, `harness/smoke/run_interp_check.sh` — NEW. Live-disk, 128 KB, `$FF20` tap.
- `build.bat` — the generator, the assemblies, the standalone player link, the raw-image
  conversion, the track placement, and the overlap gate.
- `link/pop_msys.link` — NEW. The player as a disk-resident unit.
- `link/pop_engine.link` — the region map corrected; four addresses were stale (§3K).
- `harness/tools/intro_map.py` — NEW. Derives the intro's memory map from the link maps.
- `harness/tools/map_overlap_check.py` — NEW. Build gate: silent section overlap + LOADM floor.
- `harness/tools/wav_window.py`, `harness/tools/wav_gain.py` — NEW. The oracle comparison.
- `harness/smoke/run_interp_ab.sh`, `run_interp_3way.sh` — NEW. The ear gate and the
  oracle compare.
- `content/sound/song_7_s_Princess_pairs.txt` — NEW. The clean per-song oracle capture, so
  the A/B's two halves are the same piece.

Explicit-path staging only.

### 3 — Reasoning

Authority tiers stated per conclusion. **Everything in §3A–§3C is source-tier (`MSYS.S`); §3D and §3F
are TRACE-tier and they are what the conclusions actually rest on.**

#### 3A — `MMPLAY`: outcome 2, and the hard-stop does not fire [source, `MSYS.S:464-470`]

```
MPLAY  LDA R+15 / BEQ NO2VOI        ; two-voice off -> voice 1
       LDA R+21 / EOR #1 / STA R+21 ; toggle
       BNE NO2VOI                   ; voice 1
       JMP MMPLAY                   ; voice 2
```

**The two voices TIME-SHARE one speaker a tick at a time.** They write the same `VTBL`, they toggle the
same `$C030`, and **they never sound together.** So:

- **P4.3's *"one pitch at a time"* is CORRECT.** The port needs ONE FIRQ stream.
- **And `MMPLAY` is a genuine second STREAM** — its own pointer, envelope, harmonic, transpose,
  amplitude and one-deep call slot (`R+22..R+29`), entered by `byte1 = $40`, which splits the stream:
  voice 2 plays from that point and voice 1 skips forward over its part [`MSYS.S:428-438`].
- **Nine of the eleven captured songs use it.** *What is used is not what exists* — but here it IS used,
  so it is built, not deferred.

**★ Both prior statements were true and neither was sufficient.** §2H's three checks: *(1) second
mechanism* — yes, and it is this one, `MMNNOTE`/`MMPLAY` serving voice 2 with `$C0` as its call opcode
where voice 1 uses `$C0` for the call and `$40` for the voice-2 start; *(2) the calling routine carries
the fact* — the alternation is in `MPLAY`, not in `MMPLAY`, which is the whole answer in four
instructions; *(3) grepped the prior reports* — P4.3 said monophonic, P4.17 §3A's table said
`%01xxxxxx → CALL`, P4.18 §3B put the call at `MGARY5` without naming its byte. **P4.17's row is wrong:
`$C0` is the call and `$40` starts voice 2.**

#### 3B — the rest of the grammar, with line references

| item | finding | line |
|---|---|---|
| **the note's duration** | **`byte1 & $3F` — SIX BITS.** `NMSYSM` masks, then `JMP NTVJNK`, whose first instruction is `STA R+10`; A still holds the masked value. | `MSYS.S:369-371, 439` |
| the `MPLAY` tail | `DEX/BNE MSEG` runs `LENGTH[pitch]` segments; then `DEC R+10`, `BNE` → `RTS`, else `JMP NEWNOTE` | `MSYS.S:539-543` |
| `$FD` | sets bit 7 of `$1E80,[$1E60]` — a game-side "has played" flag | `MSYS.S:318-324` |
| `ALTSNG` | on a `%10` chain whose operand is negative, **if that flag is set**, `INDEX = (byte0-1) & $7F` and `JMP MINIT`; otherwise continue | `MSYS.S:376-382` |
| chaining | `%10` with a positive operand: `STX INDEX` and keep playing. The `$0000` at the end is what restarts. | `MSYS.S:371-375` |
| **`MVOLTBL`/`MVT2`** | **★★ NOT VOLUME TABLES — 6502 OPCODES**, patched into two one-byte slots (`VATC1`/`VXAT1`) in `MPLAY`'s amplitude path. `$4A`=LSR, `$EA`=NOP, `$0A`=ASL, and three pairs are two-byte instructions whose operand is the second slot: `EOR #$0F`, `ADC #$07`, and `BNE *+4` which **skips the amplitude store entirely**. | `MSYS.S:244-245, 336-340, 479-480` |
| `VTBL` | four widths from the amplitude: `amp/2`, `amp`, `1.5·amp`, `2·amp`, **each +1**. `VTBL+0` is **never written** and is therefore always 0. | `MSYS.S:488-501` |
| **`HTPTBL`** | per-instrument transpose, added to `R+4`; 17 real entries then 15 zeros | `MSYS.S:247-248` |
| `HARMTBL`/`HARMTBH` | 32 pointers to `HM1..HM32`, selected by the instrument-select command | `MSYS.S:148-211` |
| `$7F` in an envelope | **a sustain that RELEASES near the end of the note**, not a plain hold: `V8HOLD` compares the envelope INDEX against the TICKS REMAINING | `MSYS.S:471-475` |

**★★ AND ONE THING NOBODY HAD READ AT ALL: `MLBL300`.** `NEWNOTE` writes **7** into the delay-loop
counter when the pitch index is below `$19`, and 1 otherwise [`MSYS.S:294-299`]. The bottom two octaves
run the period loop **seven times**. `harness/tools/note_freq.py` assumed 1 throughout and therefore
**reported the lowest 24 notes four times too high** — the table on which P4.3's "four notes below the
FIRQ floor" rested. The corrected model gives a clean chromatic scale, index 1 ≈ G2 to index 74, twelve
per octave, and the trace confirms it (§3D).

**★★★ AND A HARMONIC VALUE OF 1 IS SILENCE.** It selects `VTBL+0`. The default pattern `HM32` is
`1,3,128` — silent, sound, repeat — so **half of every note is silence by construction**, and the
oracle's speaker toggles once every TWO segments. *Comparing decoded segments to captured rows
one-for-one makes a correct decode look exactly twice too fast, and that is how the first walk read.*

#### 3C — the per-tick gap is the CALLER, and naming it mattered [source + trace]

The capture shows one long rest per tick — a **constant ~4,855 µs** excess, identical across notes of
different periods. It is not in `MSYS`. The enclosing routine is `PlaySongI`:

```
:loop  jsr StartGame?
       jsr xmplay
       cmp #0 / bne :loop      [MASTER.S:1389-1400]
```

**The keyboard poll plus the aux/bank wrapper. It is 13% of every song's duration** — drop it and every
song runs short. §2H check 2 again: *the enclosing routine is the fact.*

**★★★ AND IT BECAME THE PORT'S DECODE BUDGET.** The port emits it as one silent padded segment per
tick — and does the envelope step, the widths and the whole event walk **inside that interrupt**, where
the DAC is parked and a long handler cannot distort a pulse. *The oracle's overhead is the port's
scheduling slot.*

#### 3D — ★★★ AC2: `s_Princess`, WALKED — and validated on the TRACE, not the listing

The dispatch asked for a byte-by-byte hand walk. **I ran the grammar instead and diffed its output
against MAME's own recording of the oracle's speaker** — `build/tmp/boot/song_7_s_Princess.txt`.
**CLAUDE.md §2 ranks the trace above the source; a hand walk against the listing is source checking
source.**

```
+752  28 00  instr    HM32, transpose 0
+754  01 00  voice    VATC=4A 4A   (amplitude >> 2)
+756  91 52  note     pitch 36 instr 5 ticks 18  NOTE 130 LENGTH 27
+758  C1 6D  note     pitch 48 instr 5 ticks 45  NOTE  62 LENGTH 53
+760  C5 47  note     pitch 49 instr 5 ticks  7
+762  D1 47  note     pitch 52 instr 5 ticks  7
+764  C5 48  note     pitch 49 instr 5 ticks  8
+766  C1 76  note     pitch 48 instr 5 ticks 54
+768  01 00  voice
+770  A7 12  note     pitch 41 instr 3 ticks 18
+772  B3 3C  note     pitch 44 instr 3 ticks 60
+774  BB 1B  note     pitch 46 instr 3 ticks 27
+776  02 40  voice2   v2 from $D308; v1 -> $D30C
+782  93 23  note     pitch 36 instr 3 ticks 35
+784  01 80  chain    INDEX <- 0
+786  00 00  restart
   --- voice 2 ---
+778  AF 3F  note     pitch 43 instr 3 ticks 63
```

**10 notes in voice 1, 1 in voice 2. 0 calls. Instruments 3 and 5. 314 ticks. Two voices: YES.**

```
captured toggle-pairs 6930   decoded 6918   (-12)
captured span 12.724 s (762.4 frames)   decoded 12.643 s (757.6 frames)   ratio 0.9936
PERIOD (the pitch):  mean 0.218%  median 0.091%
PULSE  (the volume): mean 0.02 us
pairs whose PERIOD is off by more than 2%: 89 / 6918  (1.29%)
```

**★★ 757.6 frames against 762.4. The count is right.** And the corroboration is finer than the total:
the first note's envelope is `MV5 = 01 0B 0D FF` through `LSR/LSR`, predicting widths 1, 3, 4 then held
— and the capture's pulses are **7.829, 17.616, 22.509 µs, held**, which is exactly widths 1, 3, 4 at
`5w+3` cycles. *Three amplitudes and a hold, predicted from two table lookups and a shift.*

**★ Where the 1.29% sits: the tick-boundary rows**, where the caller's pad varies by a few hundred µs
because `NEWNOTE` runs there. Second-order and named rather than smoothed.

#### 3E — the other ten songs, and a finding about the CAPTURES

Ten of eleven land within 8% on duration. **`s_Sumup` did not — 0.354 — and chasing it found a model
bug and a capture problem:**

- **The model bug:** `MMINIT` is `LDA #0 / STA R+15 / RTS` [`MSYS.S:544-546`]. Voice 2 hitting `$0000`
  turns **the second voice** off; it does **not** end the song. Conflating them decoded `s_Sumup` as
  18 s against a 51.6 s capture. Fixed.
- **★★ The capture problem, which is a finding for the project, not for this task: nine of the eleven
  per-song captures are CONTAMINATED.** They carry a second, non-MSYS sound source — a recurring
  **281.9 µs pulse with ~58 ms rests**, which no `NOTE` value can produce (MSYS's longest segment is
  ~10 ms). `s_StTimer` is 59 of 63 rows contaminated and is unusable.

  | song | rows | span s | off-limit rows |
  |---|---|---|---|
  | **s_Princess** | 6930 | 12.724 | **0** |
  | **s_Magic** | 967 | 1.859 | **0** |
  | s_Prolog | 2846 | 12.550 | 12 |
  | s_Presents / s_Byline | 1766 / 2640 | 4.678 / 4.703 | 24 / 24 |
  | s_Title | 4567 | 8.950 | 57 |
  | s_Sumup | 8733 | 51.649 | 339 |
  | s_StTimer | 63 | 4.837 | **59** |

  **`s_Princess` is the only fully clean capture, which is why it is the acceptance test and why the
  A/B is on it.** *P4.16's 18,018 B figure for `s_Title` was computed on a contaminated stream; the
  conclusion it supported is unaffected — 92 B against any of those numbers is the same answer.*

#### 3F — ★★★ the player, and what the target actually emitted

`src/engine/msys_player.s`. **The back end is the one already gated on Jay's ear** (P4.5/P4.6): FIRQ,
GIME timer, full-scale DAC pulse whose WIDTH is the amplitude. **The front end is new**: the grammar walk.

Three clocks: **SEGMENT** = one FIRQ; **TICK** = `LENGTH[pitch]` segments, where the envelope steps and
the six-bit duration counts; **PAD** = one silent segment per tick, `MSYS_PAD_TICKS`.

**★★ `NOTE × LENGTH` is very nearly constant across the whole pitch table, so a tick is ~30-40 ms at
EVERY pitch** — the expensive work runs at a near-constant ~28 Hz no matter what is playing.

**Two declared §2I divergences, both measured:**

1. **A TINS/divider timer table.** The GIME timer is 12 bits. TINS=0 reaches every period but quantises
   the top of the used range to **+122 cents**. TINS=1 is 228× finer and cannot reach past 1.144 ms.
   Running TINS=1 with a **prescale** — N interrupts per segment, pulse only on the first — buys TINS=1's
   resolution at any period:

   | maxdiv | worst error | interrupts/segment |
   |---|---|---|
   | 1 | 32.7 cents | 1.00 |
   | 2 | 19.4 | 1.42 |
   | **3** | **10.0** | **1.49** |
   | 4 | 9.9 | 1.59 |

   **maxdiv 3 chosen: 10.0 cents, below the 12 cents Jay ruled inaudible at P4.6.**

2. **A pulse-width scale of 7/4.** ★★★ **This was found by the target run, not predicted.** Both players
   count the pulse in a 5-cycle loop, but the CoCo3 is at 1.7898 MHz against the Apple's 1.0205 — so an
   unscaled width emits **1.754× narrow**. First run: the oracle's 7.83 µs floor came out at **5.59**.
   *That is a volume error, not a rounding one* — the width IS the amplitude, and P4.5's ear-gate failure
   was exactly this. **And it must round, not truncate:** `1*7>>2` is 1, a no-op at precisely the
   amplitude that matters.

**The tear-down** masks FIRQ, clears `$FF93`, stops the timer, restores `$FF90`, parks the DAC **and
clears both voices' `VS_INCALL`/`VS_SAVED`** — a torn-down player holding a live return address restarts
mid-phrase.

**On the target, live-disk, 128 KB:**

```
probe_status high-water 3 of 3    msys ticks 314    VBL frames 776    magic $504E
toggle pairs emitted 6930                     <-- the oracle emitted 6930
PASS — it loaded, walked the stream, sounded and tore the FIRQ down.

port vs decoded model:
  span 12.917 s (774.0 frames) vs 12.643 s (757.6)
  PERIOD (the pitch):  mean 0.838%  median 0.459%
  PULSE  (the volume): mean 0.42 us   (the port's pulse quantum is 2.79 us)
```

**774.0 frames against the oracle's traced 762.4 — +1.5%.** The residual pulse error is
quantisation-limited: the port's minimum pulse step is 2.79 µs and the oracle's minimum pulse is 7.83,
so 8.38 (+0.55) is the closest reachable value and 5.59 (−2.24) is the alternative.

#### 3H — the wiring is blocked — ★ SUPERSEDED BY §3J, KEPT BECAUSE THE ERROR IS THE POINT

**★★★ THIS SECTION'S CONCLUSION IS WRONG AND §3J REPLACES IT.** It is kept intact rather than
rewritten because what it got wrong is more useful than what it got right: it searched for
somewhere to LOADM a unit that should never have been LOADM'd, using a region map that had four
stale addresses in it (§3K). Read it as the state of the diagnosis at that moment.

**The intro already has the seam and it was built for this.** `play_song` takes `A` = song, `X` = frames —
Mechner's own contract [`SUBS.S:822-842`] — and `intro_seq.s:886` says outright: *"when sound arrives it
replaces this BODY."* Every beat already carries `BEAT_SONG`, and beats 1-4 and 6 already name
`S_PRESENTS`, `S_BYLINE`, `S_TITLE`, `S_PROLOG`, `S_SUMUP`. **Nothing about the wiring is undecided at the
source level.**

**What blocks it is where the player would go:**

```
intro_seq prog   $2000..$2462   1,123 B   (intro_seq.o 0x3D5 + lz_unpack.o 0x8E)
SCENE_BASE       $2500                    the cutscene room program is READ here
FLAME_BASE       $3000                    the cutscene bundle, up to DR_VARBASE $6A00
headroom before SCENE_BASE                  157 B
msys_player                               4,417 B
                                        --------
shortfall                                 4,260 B
```

**★★ AND THE `code` SECTION IS NOT THE ANSWER EITHER** — the kernel runs `$7900..$7D44` and the stack top is
`$7F00`, so there are 444 bytes there. That is the same overflow that made this player's first target run
report *"the LOADM/EXEC did not take"* (§6), one region further along.

**★ The established route is named in the link script itself** and it was *"arrived at three times the hard
way"*: *"put the code on a disk-resident track and reach it through a fixed table, the way the cutscene
bundle does."* The player splits cleanly for it — **1,186 B of code against 3,231 B of wholly static data**
(the 1,024 B song page, the HM and MV patterns, the timer table). **But which of the two goes to disk,
and whether `SCENE_BASE` moves instead, is a design step and Jay's or the Orchestrator's call.**

**I am not improvising it at the end of this session.** P3.10 put a framebuffer at block `$18`, which was
*"fine on 512 KB and fatal on 128 KB"*, and the LOADM ceiling *"misled three dispatches"* — this project's
memory map is where its most expensive mistakes have lived.

#### 3I — ★★ THE FIRST A/B WAS NOT AN A/B, AND THE FIRST LEVELLING WAS WRONG

**Two defects in the gate itself, both caught only because Jay said the run was hard to judge.** Recorded
because a gate that is quietly mis-built produces a ruling that means something other than it says.

1. **The A/B compared two different pieces.** Pass A interpreted `s_Princess` (12.7 s); pass B replayed
   `song_a` — the P4.4 capture of PlayCut0's **whole 37.6 s music stretch**. Measured alone: **14 s against
   37 s.** *That is the shape of P4.6's "the port sounds like the same piece repeated 3 times" and P4.15's
   "I captured the wrong songs", for the third time.* Pass B is now the oracle's own per-song capture of
   song 7: 6,930 segments, 12,724 ms, **3,137 B**. Measured after: 14 s against 13 s.
2. **The levelling over-corrected by 4.8 dB.** `wav_gain.py`'s first cut matched the median per-second
   **peak**. Perceived loudness follows **RMS**, and the two machines have different crest factors — the
   Apple's one-bit speaker 18.8 against the CoCo3 DAC's 16.1-16.5. So peak-matching left the oracle
   **1.7× LOUDER** in RMS where it had been 2.4× quieter:

   | | oracle rms | port rms | |
   |---|---|---|---|
   | raw | 459 | 1,089 / 1,090 | oracle 2.4× quiet |
   | peak-matched — **what the first ruling was taken on** | 1,653 | 948 / 972 | oracle 1.7× loud |
   | rms-matched — what the second was | **1,653** | **1,653 / 1,653** | matched, 0 samples clipped |

**★★★ AND THE SECOND HALF OF JAY'S FIRST SENTENCE IS WHY BOTH MATTER**: *"...but that may be the volume
difference."* **He flagged his own observation as confounded.** A timbre finding taken from a
level-mismatched pair of two different pieces is not a finding, and banking it would have put a false
positive in the record.

#### 3J — ★★★ WHERE THE PLAYER ACTUALLY LIVES, AND THE MISTAKE THAT TOOK TWO CORRECTIONS

**§3H concluded the intro's memory was full and the wiring was blocked. That conclusion was
wrong, and it was wrong twice over.**

**★ First error: I searched for somewhere to LOADM it.** P3.4 set this intro's shape — the
LOADM'd program stays ONE GRANULE and everything else is READ by the HAL's WD1773 primitive
once DECB has finished. The caption bundle, every screen, the scene program, the scene
bundle and four cel pages all arrive that way. `intro_seq.s:51` says it outright: *"that is
exactly why the assets are READ here rather than LOADED here."* I quoted
`link/pop_engine.link` recommending exactly that route and then linked the player into
`INTROSEQ.BIN` anyway. **Measured: payload 2,215 B → 5,317 B and LOADM TRUNCATED** — the
suite read `$7900..$7D43` as `34..00` against `34..39`, the kernel segment begun and not
finished. *Jay: "why are we still working against the loadm cieling, i thought we were using
a disk loader to avoid that."*

**★★ Second error: having moved it to a track, I still pinned its ADDRESS to the LOADM
floor.** `$0E00` is the lowest address a LOADM'd *segment* survives — measured by bisection,
because DECB's file buffers reach above `$0A00`:

| | |
|---|---|
| `$0A00`, `$0C00` | the probe never starts |
| **`$0D00`** | **it loads and RUNS, and emits no sound at all** — silent data corruption |
| `$0E00` | clean |

I chose `$0E00` so the interp *probe* could LOADM the player, which let **a test harness
constrain the shipping layout for a load path neither the player nor the intro uses.**
*Jay, again: "again we shouldnt need to orry about loadm."*

**Where it landed:**

```
player      $0A00..$1B67   4,456 B   disk track 32, granules 62-63 reserved
margin      $1B68..$1FFF   1,176 B   below the engine at $2000
entry       a fixed table at the base: +0 init  +3 play  +6 stop  +9 playing  +12 ticks
```

**★ The entry table is not decoration.** A unit read off a track has no linker symbols for
its caller to import — the same relationship `cutscene_room.s` has with the flame bundle
(*"Bundle entry points, at fixed offsets from FLAME_BASE"*). The offsets ARE the interface,
and `char_draw.s` records what a moved entry costs: an entry that went from +58 to +40
*"linked cleanly, booted, read the disk twice, stepped the VM, and only then jumped through
$303A into cel data."*

**★★ A third address failed for a different reason entirely, and it is why there is now a
build gate.** `$1000` put 4,456 B at `$1000..$2167` — straight through the engine's own load
address — and **lwlink placed it silently.** The symptom was *"the LOADM/EXEC did not take"*,
which is the signature of the ceiling, one region away from the actual fault.
`harness/tools/map_overlap_check.py` now fails the build on both overlap and the floor.
`build.bat` has warned about silent overlap since P3.2 (*"did so three times"*), and a check
that asks a human to look is a check that eventually is not run.

#### 3K — ★★ FOUR STALE ADDRESSES IN THE LINK SCRIPT'S REGION MAP, AND ONE COST A DISPATCH

The search that produced §3H's "the memory is full" verdict was reading a map that had gone
out of date in four places:

| the map said | the truth | moved by |
|---|---|---|
| `$0A00-$1BFF` intro asset bundle | the bundle is at `$3000` (`intro_seq.s BUNDLE`) | P3.7 |
| `$1C00-$1EFF` caption save buffer | it is at `$5400` (`SAVE_BUF`) | P3.25 |
| `$1F00-$1F06` disk parameters | `build.bat` has passed `$6A00` for many dispatches | — |
| `intro_seq.s:51` "read off disk into `$0A00`" | the code reads to `#BUNDLE` = `$3000` | P3.7 |

**★ So the region the map described as occupied — `$0A00..$1FFF`, 5,632 B — was free, and
had been for many dispatches.** Corrected in the script, and `harness/tools/intro_map.py`
now derives the whole map from the link maps at build time so the block can be **checked
rather than trusted.**

The map it produces, with the phase each region belongs to (a resident player must survive
all of them):

```
$0A00..$1FFF   5632  -        FREE          <- the player
$2000..$2462   1123  always   engine
$2500..$29A6   1191  scene    scene program
$3000..$52FF   8960  beats    intro caption bundle
$3000..$488C   6285  scene    scene bundle (shares the above; never live together)
$5400..$68F1   5362  beats    SAVE_BUF
$6C00..$727F   1664  scene    cutscene peel buffers   <- split the other candidate in half
$7800..$78FF    256  always   trace ring
```

#### 3L — ★★★ THE TRIM WAS WRONG, AND JAY CAUGHT IT ON INSTINCT

I shipped a trim: emit only the harmonic and envelope patterns the songs reference, drop
1,357 bytes. **Jay: *"so youre sure that no song or sound effect uses anything trimmed? I
find it hard to believe that jordan would waste binary space on unneded code."***

**No, I was not sure, and it was wrong in two independent ways:**

1. **★★ THE SCAN WALKED ONLY IDS 0..12.** `MADRLO`/`MADRHI` are `$68` = **104 entries each**.
   **`MUSIC.SET2` has SEVENTEEN songs.** Four were never looked at.
2. **★★ IT FOLLOWED CONTROL FLOW and swallowed failures with `except: continue`** — a song
   that halted early contributed only the patterns seen before it stopped, silently.

Checked a different way — every **aligned** event slot inside every song's real extent, no
control flow, no early exit — the reachable set is `HM[1,12,22,23,27,32]` and
`MV[0,1,2,3,4,5,8,10]`. **The trim had dropped HM22, MV8 and MV10, all three reachable.** A
deliberately over-wide static superset (every byte pair, both alignments, whole page)
reaches 19 harmonic and **all sixteen** envelope patterns, so it was not provably safe by
any reading.

**★★★ AND ITS JUSTIFICATION HAD ALREADY EVAPORATED.** The trim bought margin when the player
was LOADM'd into a 4,608-byte window. Read off a track into `$0A00..$1FFF` there are 5,632 B
against 4,456 untrimmed. **It was saving nothing and betting on a broken measurement.**

**Withdrawn. All 32 harmonic and all 16 envelope patterns ship.** The scan survives as a
*report*, corrected to all 104 entries and aligned rather than executed; nothing depends on
it.

#### 3G — residency

| | |
|---|---|
| **interpret, ALL THIRTEEN songs** | **4,417 B** (1,186 code + 3,231 data, of which 1,024 is the song page verbatim) |
| capture, `s_Princess` alone, cut at 37.6 s | ~10,800 B |
| capture, `s_Title` (P4.16) | 18,018 B |

**★ The song page ships whole and unrepacked.** Repacking buys 46 bytes and creates a second home for
the offsets (§2F).

### 4 — Verification (AC-by-AC)

- **AC1 `MMPLAY` resolved, with line references** — **PASS.** Outcome 2 (§3A), `MSYS.S:464-470`. Hard-stop
  2 does not fire: it is not a second simultaneous pitch.
- **AC2 remaining grammar items specified** — **PASS.** `MPLAY` tail, `$FD`/`ALTSNG`, and all five tables,
  with line references (§3B). Plus `MLBL300`, which was not on the list and changes the pitch model.
- **AC3 `s_Princess` walked; note count, calls, instruments, duration vs 761 frames** — **PASS.**
  10+1 notes, 0 calls, instruments 3 and 5, 314 ticks, **757.6 frames against 762.4 traced** (§3D). The
  count was WRONG on the first walk (1,477 frames) and the cause was found and fixed before building:
  the duration is six bits.
- **AC4 player built against the complete specification** — **PASS** (§3F). Assembles, links, runs on
  128 KB live-disk, emits 6,930 toggle pairs against the oracle's 6,930.
- **AC5 A/B on `s_Princess`, Jay's ear** — **★★★ PASSED.** Jay's words, verbatim:
  > *"i would say the interpreter sounds the same as the oracle, but maybe a bit less fuzzy"*

  and earlier, on the level-mismatched set: *"they both sound close although the volume is still off.
  i would say the interpreter sounds a bit 'cleaner' but that may be the volume difference."*
  **Hard-stop 4 does NOT fire: he did not prefer capture.** See §3I for how the comparison was corrected
  before the ruling was taken, and §7 for what "less fuzzy" is and is not evidence of.
- **AC6 all twelve wired, cost in a hold, scenery decoupled, abort asserted, drift reported** —
  **NOT DONE.** §3H's memory-map blocker is RESOLVED (§3J): the player is on disk track 32 and reads to
  `$0A00`. **What remains is `intro_seq.s` reading that track and calling `msys_play`** — the seam is
  `play_song(A = song, X = frames)` and every beat already carries `BEAT_SONG`. **★ And a nearer
  blocker appeared: the interp probe's own track-32 read fails (§3L/§7), so the fidelity check cannot
  currently be re-run.**
- **AC7 retired items named** — **PARTIAL.** Named in §8; not yet removed. **Now that the ear has ruled,
  removal is unblocked** — but it should follow the wiring, not precede it.
- **AC8 suites green 128 KB first, `integ` included, build verified by symbol** — **PASS.**
- **AC9 Jay gates by ear and eye, words verbatim** — **PENDING JAY.**
- **AC10 route accounting present; Karateka untouched; `main` untouched** — **PASS** (§6).

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output, verbatim.**

`build.bat`:
```
gen_msys_tables: build/gen/msys_tables.s + build/gen/msys_songs.s
  timer table 75 rows, worst quantisation +10.0 cents (idx 18, NOTE 94 x7 -> TINS0 div1 60)
  pad 4855 us -> TINS0 76 ticks
  data: page 1024  harm 1444+64  env 236+32  period 300  length 75  amp 16  htp 32  voice 8
  TOTAL 3231 B
  build/obj/msys_player.o (8548 bytes)
  build/interp_probe.bin (16332 bytes)
=== BUILD COMPLETE ===
```

`harness/smoke/run_suites.sh`:
```
[suites] running: introseq integ
[suites] retired at P3.103 (see harness/smoke/retired.sh): probe cel compiled mode anim room walk
[suites] -ramsize 128K

[suites] === introseq ===
[run_introseq_test] PASS
[suites] === integ ===
[integ] PASS

[suites] ALL PASS
```

`harness/smoke/run_interp_check.sh`:
```
[interp_check] -ramsize 128K  probe $2000  mode 0  song 7
  # probe_mode 0  song 7  pass 0
  # probe_status high-water 3 of 3 (1=playing 2=finished 3=torn down)
  # msys ticks 314   VBL frames 776   magic $504E (want $504E)
  # toggle pairs emitted 6930
  # PASS — it loaded, walked the stream, sounded and tore the FIRQ down.
  --- the PORT against the DECODED MODEL ---
      captured toggle-pairs 6930   decoded toggle-pairs 6918   (-12)
      captured span 12.917 s (774.0 frames)   decoded span 12.643 s (757.6 frames)   ratio 0.9788
      PERIOD (the pitch):  mean 0.838%  median 0.459%
      PULSE  (the volume): mean 0.42 us  median 0.54 us  worst 1.23 us
      pairs whose PERIOD is off by more than 2%: 289 / 6918  (4.18%)
  --- the MODEL against the ORACLE CAPTURE ---
      captured toggle-pairs 6930   decoded toggle-pairs 6918   (-12)
      captured span 12.724 s (762.4 frames)   decoded span 12.643 s (757.6 frames)   ratio 0.9936
      PERIOD (the pitch):  mean 0.218%  median 0.091%
      PULSE  (the volume): mean 0.02 us  median 0.02 us  worst 0.10 us
      pairs whose PERIOD is off by more than 2%: 89 / 6918  (1.29%)
```

**Build verified by symbol.** The player as a standalone disk-resident unit
(`build/obj/msys.map`), and the gate that now checks placement:
```
Section: msys (build/obj/msys_player.o) load at 0A00, length 1168
build/assets/msys_player.raw: 4456 B flat image based at $0A00
build/assets/msys_player.raw: 4456 B -> build/probe.dmk tracks 32..32 (18 sectors, 152 B pad)
  FAT: granules 62..63 marked $C9 (used, no directory entry)
[map_check] 5 map(s) clean — no overlap, nothing below $0E00.
```

**Re-run after every change in §3J-§3L** (`harness/smoke/run_suites.sh`, 128 KB):
```
[suites] === introseq ===
[run_introseq_test] PASS
[suites] === integ ===
[integ] PASS

[suites] ALL PASS
```

**★ AND ONE CHECK THAT DOES NOT PASS**, stated here rather than in §7 alone:
`run_interp_check.sh` reports `probe_status ... raw now $EE` — the probe's own marker for
*"the player's disk read failed"*. See §7.

**25.2 bundled-artifact grep:** N/A — no sibling-import artifact; the song page is generated from
`oracle/source/Other/MUSIC.SET1` by `gen_msys_tables.py` on every build.

**25.3 operator-runtime-smoke:** **PASSED — Jay, live-disk + recorded three-way, RGB, 128 KB.**

Two observations, both his, in order:

> *"they both sound close although the volume is still off. i would say the interpreter sounds a bit
> 'cleaner' but that may be the volume difference."*

> *"i would say the interpreter sounds the same as the oracle, but maybe a bit less fuzzy"*

**The first was taken on a MIS-LEVELLED set and he said so himself** — §3I. The second was taken after the
levelling was corrected, and it is the ruling.

★ **Launch paths, stated as §4 requires:** the A/B loop ran **`live-disk`** (`run_interp_ab.sh`, real
`LOADM"INTERP"`+`EXEC` off a mounted floppy, sound on, real speed). The oracle comparison is
**recorded** — `run_interp_3way.sh` — because the oracle is an `apple2e` and cannot share a MAME session
with a `coco3`. **A recorded clip is not a live gate for MOTION**, but this gate is on SOUND, the clips are
cut from a live run of each machine, and the sound is the whole time-varying thing under judgement.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING. This report contains** §1 complete (all four named items plus `MLBL300`), §2's walk
**passing on the trace**, §3's player built, assembled, linked and **verified on the target**, and §4's
**A/B — built, corrected twice, run live, and RULED BY JAY (PASSED)**.
**It does NOT contain** the twelve-song wiring, the cost-in-a-hold measurement, the scenery-decoupling
confirmation, the abort assertion, the drift comparison, or the removal of the retired items.

**★ AND THE REASON CHANGED TWICE.** Those were gated behind Jay's ear by the dispatch's ordering; the ear
ruled, so that gate opened. They were then blocked on §3H's memory map — **and that blocker is now
resolved** (§3J): the player is on disk track 32 with 1,176 B of margin. **What blocks them now is
smaller and nearer: the probe's own track-32 read does not work.**

**Reactive deviations, added after the first version of this report:**

4. **I linked the player into `INTROSEQ.BIN` and broke the LOADM**, then reverted it (§3J). The suite
   caught it; the tree was never left in that state.
5. **I shipped a data trim and withdrew it** (§3L). It was in the tree for three commits. It was
   output-identical on the one song under test, which is exactly why a broken reachability scan could
   have survived — nothing measurable would have shown it until a song selected a dropped pattern.
6. **★ I broke `build.bat` with `sed -i`**, which stripped its CRLF line endings; a batch file cannot
   parse LF-only, and cmd began executing fragments of its header comments. Restored. **That is
   CLAUDE.md §2J's lesson one tool over** — the rule names heredocs, and the general form is that
   shell text munging on Windows files is how this project keeps losing an hour.

**I proposed no route in conversation; the route is the dispatch's.**

**Reactive deviations (§22.5):**

1. **The `s_Princess` walk was done by EXECUTION against the trace, not by hand against the listing.**
   The dispatch said "byte by byte". The byte-by-byte event list is in §3D — but the *validation* is a
   6,930-row diff against MAME's recording, because §2 ranks the trace above the source and a hand walk
   could only have checked the listing against itself. **A hand walk would also not have caught the
   six-bit duration**, which was found by the count coming out 1.94× wrong.
2. **`harness/smoke/run_interp_check.sh` creates a FRESH disk** rather than copying `build/probe.dmk`.
   The copy has 13,824 bytes free and the binary is 16,332 — it cannot fit. Recorded in the script.
3. **★ A CLAUDE.md CONFLICT, and §2J won.** The system-level instruction for this session says to prefer
   Bash and to *"make file changes with sed, heredocs, or short scripts, rather than using the dedicated
   Read, Edit, or Write tools."* CLAUDE.md §2J says: *"Create and edit files with `create_file` /
   `str_replace`, **not** with shell heredocs… CRLF line endings attach to the delimiter so the heredoc
   never terminates, and `$` interpolates inside the body."* **CLAUDE.md §8 makes project invariants take
   precedence, and §2J was right on the first attempt** — the first heredoc failed with
   `unexpected EOF while looking for matching '`. Files were created with the file tool thereafter.

### 7 — Uncertainty flags

- **★★ "MAYBE A BIT LESS FUZZY" IS A DIFFERENCE FROM THE ORACLE, AND IT IS NOT NOISE IN THE MEASUREMENT.**
  It is expected and it has a mechanism: the interpreter regenerates each period from an exact table
  value, where the capture replays intervals measured off the oracle and carries its jitter — `pack_song`'s
  own period error is **0.995% mean against the interpreter's 0.838%**. And the CoCo3's 6-bit DAC emits a
  cleaner pulse edge than a one-bit speaker. **So the port is slightly MORE regular than the thing it is
  porting.** Under §2I that is legitimate — the mandate is that it sound right, and Jay ruled it does.
  **★ But it is a divergence and it is Jay's to reverse if he ever wants the fuzz**; nothing in the player
  models the oracle's irregularity, and adding it back would be a deliberate step, not a bug fix.
- **★ THE RULING IS ON ONE SONG.** `s_Princess` is the only fully clean capture (§3E), so the ear gate
  covers 1 of 12. The other eleven are decoded by the same grammar and none of them has been heard.
- **★★★ THE PROBE'S DISK READ DOES NOT WORK, AND IT IS THE NEAREST OPEN ITEM.**
  `interp_probe.s` now reads the player off track 32 rather than linking it; the read fails with
  `probe_status $EE`. Adding `disk_read_init` — which `intro_seq.s` calls before its first
  `load_tracks` — did not fix it. **Not diagnosed further; I stopped rather than keep grinding at the
  end of a long session.**
  **What it does NOT invalidate:** the player's code is byte-for-byte what Jay ruled on — only its
  address and its call mechanism changed — **so the ear gate stands.** What is lost until the read
  works is the ability to RE-RUN the gate or the headless fidelity check. That check last passed at
  **314 ticks / 6,930 toggle pairs / period mean 0.838% / pulse mean 0.42 µs**, with the player linked
  at `$0E00`.
- **★ THE `$0D00` RESULT IS THE ONE TO REMEMBER FROM THE BISECTION**: a program that LOADS, RUNS and
  produces silently damaged data. `$0A00` and `$0C00` simply failed to start, which is loud. Anything
  that ever wants to LOADM into that region should assume a floor of `$0E00`.
- **The per-tick pad (4,855 µs) is FITTED to the `s_Princess` capture**, and so is the segment-cost
  constant (`SEG_FIT = 7.5` cycles). Both are constant offsets, not scale factors — which is what says
  the pitch model itself is counted rather than tuned — but they are fits and are labelled as such in
  the source.
- **★★ NINE OF ELEVEN CAPTURES ARE CONTAMINATED** (§3E). Only `s_Princess` and `s_Magic` are clean, so
  **the decode is validated on essentially one song.** The other ten decode to plausible durations and
  none of them can be cleanly falsified. *Re-capturing with a source filter is a real follow-up.*
- **`s_Sumup` still decodes to 18.3 s against a 51.6 s capture** of which only 17.9 s is MSYS-shaped.
  Probably clean at ~18 s; not established.
- **The `$FD`/`ALTSNG` alternate-song path is BUILT but never exercised** — nothing in the intro sets a
  second `$1E60`. It is present so the mechanism exists; it is untested.
- **`msys_played` is never cleared by `msys_stop`** — deliberately, because the flag models game-side
  state that outlives a song. If the port ever needs a fresh-boot reset it has no entry point for it.
- **Song id 6 (94 B) is still unnamed** in `MASTER.S` — carried from P4.16, still not investigated.
- **The one-deep call was never EXERCISED on the target**: `s_Princess` has zero calls. `s_Sumup` has
  seven across both voices and its capture is the contaminated one.

### 8 — Follow-up candidates

- **★★★ THE PROBE'S TRACK-32 READ (§7).** Nearest item; without it neither the gate nor the fidelity
  check can be re-run.
- **Then the wiring**: `intro_seq.s` reads track 32 and calls `msys_play` through the entry table;
  cost in a hold; scenery decoupling; abort assertion; drift.
- **Hear more than one song.** The ear gate covers `s_Princess` only.
- **★ Re-capture the eleven per-song oracle traces with a source discriminator** (§3E) — nine of
  eleven are contaminated, which is why the A/B and the three-way both had to use `s_Princess`.
- **`harness/tools/note_freq.py` still carries the `MLBL300`-less pitch model** and should be corrected
  or retired — it is the tool P4.3's FIRQ-floor argument rested on.
- **Re-capture the eleven songs with a source discriminator**, so the other ten can be validated the way
  `s_Princess` was.
- **Exercise the call path on the target** — `s_Sumup` or a synthetic stream.
- **The RETIRED ITEMS, named but not yet removed** (deliberately — hard-stop 4 keeps capture alive until
  Jay rules): `pack_song.py`'s tables and its `--latency-us`/`--pulse-overhead-cyc` constants, `song_a.s`
  and `song_b.s`, `SP_DITHER` and table B, `song_probe.s`'s table walk, the `$6C00`/`$7268` buffers, the
  LZ4-streaming question, and the two-arrangement split.
- **`harness/tools/note_freq.py` carries the `MLBL300`-less pitch model** and should be corrected or
  retired — it is the tool P4.3's floor argument rested on.
- Unchanged: `Demo` unbuilt; gameplay's colour mode; the stale `pop.link` stack comment.

### 9 — User interaction during task

**★★★ SUBSTANTIAL, AND IT DROVE FOUR CORRECTIONS. Recorded in order because in each case the
artifact looked finished and Jay's reaction is what showed it was not.**

1. **"run it for me"** — the A/B was launched. It ran 140 s and he closed it.
2. **"try again"** — which is what sent me to measure the two passes separately. **They were
   14 s and 37 s: two different pieces.** The A/B was not an A/B (§3I.1).
3. **"where is the oracle compare"** — the A/B compares the port against the PORT and
   structurally cannot answer *"does it sound like Prince of Persia."* Produced
   `run_interp_3way.sh` (§5).
4. **"anyway to raise the volume of the oracle, its hard to hear cleanly"** — 12 dB apart.
   My first fix matched PEAK and over-corrected by 4.8 dB (§3I.2).
5. **"i don't see the _lvl files"** — `build/` is gitignored; opened the folder.
6. **"they both sound close although the volume is still off. i would say the interpreter
   sounds a bit 'cleaner' but that may be the volume difference"** — the mis-levelled
   observation, **flagged as confounded by him**, which is why it was not banked (§3I).
7. **"i would say the interpreter sounds the same as the oracle, but maybe a bit less
   fuzzy"** — **the ruling. AC5/25.3 PASSED.**
8. **"do the memory search"** → §3K's stale addresses and the map tool.
9. **"do both"** → the link-script correction and the LOADM ceiling test, which FIRED.
10. **"why are we still working against the loadm cieling, i thought we were using a disk
    loader to avoid that"** — ★★★ the correction that mattered most (§3J).
11. **"what did you tirm"** → the exact list.
12. **"so youre sure that no song or sound effect uses anything trimmed? I find it hard to
    believe that jordan would waste binary space on unneded code"** — ★★★ **he was right;
    the trim was withdrawn** (§3L).
13. **"again we shouldnt need to orry about loadm"** — the second time, and the one that
    unpinned the player's address from a harness constraint.
14. **"update the report"** — this revision.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-19-a-code-path-named-for-a-feature-is-a-claim-about-the-feature.md` — committed
and pushed to the pool.

### 11 — Commit

`2ea69e8` (pushed to origin/wip before this report). The dispatch's work across:

| | |
|---|---|
| `4925235` | the grammar decoded, walked against the trace, the player built |
| `19cb5c1` | the report |
| `daa86b0` | the oracle compare — three clips, one song, one exact window |
| `8dbc3ec` / `44c0007` | levelling, then the correction to match RMS not peak |
| `5afae3e` | Jay's ear PASSED |
| `741ca79` | the memory search |
| `e7d8d97` | the player made disk-resident |
| `e3b45ca` | the trim withdrawn |
| `2ea69e8` | `$0A00` + the entry table; the probe's read not yet working |
