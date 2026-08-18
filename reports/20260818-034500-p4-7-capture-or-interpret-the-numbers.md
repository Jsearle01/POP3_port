## Form B Report — P4.7 + P4.7a + P4.7b — capture or interpret: the numbers, per song

**Class:** recon.  wip.  Prod unchanged — `build/probe.dmk` still 6 files / 36,673 B / 13,824 B free.
**Nothing was built.** Three measurement tools; no player, no decode, no change to `src/` or `build.bat`.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-18 03:45 (HEAD `e40b318`, wip). P4.7a and P4.7b arrived mid-task and are folded in;
both changed what was measured before the measuring was done.

### 1 — Summary

**The capture list was already written and nobody asked it** (P4.7b). Once asked, the boundaries
came from the oracle's own calls: **six title songs, by id, in order** — and every song with a
traced duration in the tree agrees with its capture to within 2%.

**Per song, measured:** the cutscene's six songs are **8,588 B** as 4-byte rows, **6,061 B**
dictionary-coded, and **3,190 B** through the LZ decoder the port already ships. **The oracle's
loaded music set is 1,024 B.**

★★★ **So the answer to "does a captured score fit" is: on disk, comfortably — 3,190 B is 0.69× the
4,608 B file the oracle's title set comes out of. In RAM it is 8.4× the oracle's resident 1,024 B,
and that ratio is the whole decision.** It is Jay's, and it turns on sound, not on these numbers.

### 2 — Files added

- `harness/tools/oracle_song_capture.lua` — NEW. Speaker + song calls on one clock, one run;
  writes one pairs file per song id.
- `harness/tools/oracle_song_ids.lua` — NEW. The narrower first instrument; kept because its PC
  histogram is what made the trigger identifiable.
- `harness/tools/song_size_census.py` — NEW. Per-song sizes, three encodings, and the
  **plan-duration assert** (P4.7b AC2).

No `src/`, no `build.bat`, no shipping disk.

### 3 — Reasoning

#### 3A — ★★★ P4.7b IS RIGHT, AND IT IS WORSE THAN IT LOOKS

Jay: *"I thought capturing each song — or more importantly, playing each song at the appropriate
time — would have been determined from the oracle doing exactly that."*

It was. `intro_seq.s:492` calls `play_song` with *"the caption stays up for its song's length"*, the
beat table carries `BEAT_SONG` per beat with `MASTER.S` line citations, and **P3.72l traced
`s_Princess` at 761 frames from the oracle's FRAME behaviour — five dispatches before sound
existed.** P4.4 then captured 400 frames and consulted none of it.

**The check is free and it passes:**

| song | captured | traced | delta | source of the trace |
|---|---|---|---|---|
| `s_Princess` | **763 f** | **761 f** | **+0.3%** | P3.72l — `room f2688 → her turn f3487 = 799, less ~38 of plays` |
| `s_Vizier` | **352 f** | **358 f** | **−1.7%** | P3.75 |

★★ **Two genuinely independent routes** — counting frames of *animation*, and tapping the
*speaker* — **to the same quantity, within 2%.** That is the standard that made P4.4's 866
credible against P4.2's +808, and **it would have failed a 400-frame window instantly.**

**★ AND ONE CORRECTION TO P4.7b's PREMISE, because it matters for anyone who ships the assert.**
The port's `play_song(A=song, X=frames)` carries X values of 80/80/140/250/250 — **those are the
oracle's SOUND-OFF pause** (`MASTER.S:1375`: *"X = length to pause if sound is turned off"*), which
`intro_seq.s` documents correctly and which is **a different quantity from a song's length.** The
761 and 358 live **only in report prose**; they have no home in the tree. The assert therefore
carries them with citations, and **that absence is itself a finding**, not a detail.

#### 3B — the boundaries, measured from the calls (P4.7a)

`PlaySongI` is at `$FFB5` and **cannot be read-tapped — it is code, and 6502 code taps silently
false-0.** But it reads `musicon` at `$031A` four instructions in, as DATA, with the song number in
Y from the `tay` two instructions earlier. So the tap is on the data and the id comes from the
register.

**★ That cost one run to get right.** `$031A` has other readers; a flat 500-event cap let a
per-frame caller at `$0CAE` produce 1,514 of 1,521 reads and **crowd out every trigger after ~30 s**
— the same shape of failure as the capture window itself. The cap is now per-PC and the histogram
is printed, so the filter is auditable rather than trusted.

| id | song | called at | span | frames |
|---|---|---|---|---|
| 7 | `s_Princess` | 0.17 s | 12.72 s | 763 |
| 8 | `s_Squeek` | 14.12 s | 1.14 s | 68 |
| 9 | `s_Vizier` | 16.65 s | 5.86 s | 352 |
| 10 | `s_Buildup` | 26.32 s | 6.45 s | 387 |
| 11 | `s_Magic` | 34.87 s | 1.86 s | 112 |
| 12 | `s_StTimer` | 42.70 s | 4.84 s | 290 |

**All six title-set ids, in `SOUNDNAMES.S` order.** A seventh call at 51.15 s carries id 5 from a
*different* call site (`$FFBB`, `MASTER.S`'s own `PlaySongI` rather than the cutscene's `$E479`) and
is **out of the title id-space** — recorded and excluded rather than silently swept in.

**P4.6b's "42.5 s song" was four of these plus the silence between them.** The inter-song silence is
**not** in the per-song files: those durations are the beat structure, which the port already owns.

#### 3C — the sizes (P4.7 §1), and the extrapolation they supersede

**The dispatch's ≈8.4 KB *for one song* is superseded, not refined. 8,588 B is ALL SIX.**

| encoding | bytes | vs `MUSIC.SET1` (4,608 B) |
|---|---|---|
| as shipped, 5-byte rows | 10,732 | 2.33× |
| 4-byte rows (the `frac` byte is dead) | **8,588** | 1.86× |
| dictionary-coded (95–157 distinct pairs/song) | 6,061 | 1.32× |
| **LZ — the decoder already ships** | **3,190** | **0.69×** |

★★ **The redundancy the cel work predicted is there: 70% of the captured stream is compressible,
and it costs no new code** — `lz_pack.py`'s LZ4-style decoder is already in the port for the intro
screens. *The 6.5 s fragment was far too short to have shown this either way.*

#### 3D — ★★★ WHAT THE ORACLE ACTUALLY SPENDS, WHICH IS NOT 4,608 B

**Both loaders read four sectors.** `loadmusic1` takes track 34 `$50-$53` (*"we only want
$50-53"*); `loadmusic2` takes track 20 `$50,$51,$52,$53`. **Four sectors = 1,024 bytes**, into
`MusicTable = $d000`, with `MSYS` itself at `$d400` — i.e. the music data is exactly `$d000-$d3ff`.

**And `MUSIC.SET2` is exactly 1,024 B and its bytes confirm the layout:**

```
offset 104 (= MusicTable+$68 = MADRHI):
  d0 d1 d1 d1 d1 d1 d1 d2 d2 d2 d2 d3 d3 d3 d3 d3 d3
```

**Seventeen high bytes, strictly non-decreasing, all inside `$d0-$d3`** — paired with offsets 0-16
they give song addresses `$d0fe, $d102, $d120, $d148 … $d3cc`, strictly increasing, for ids 0-16.
**That is the game set's sixteen songs plus entry 0.** Measured from the bytes, at the offset the
source predicts.

**★ `MUSIC.SET1`'s 4,608 B is therefore NOT the loaded image** — its head is a named directory
(`DEMO`, `CELL`, `UNUSED`, `Guards`, high-bit ASCII, with track/sector-shaped fields). It is a
container of which the loader takes four sectors. **This is exactly the "sizes do not agree with
the sector lists" that HARD-STOP 3 warned against resolving by inference — and it is now resolved
by measurement instead, for `SET2`. `SET1`'s container is not decoded and the note-stream FORMAT
inside either is not decoded at all.**

**So the honest comparison is 1,024 B against 8,588 B resident**, not 4,608 against 8,588.

#### 3E — what an interpreting player would cost (P4.7 §2)

- **Tables, counted exactly from `MSYS.S`: 1,997 B** — `HM*` 471, `MV*` 200, `HTPTBL` 17, `AMPTBL`
  16, `NOTE` 13, `LENGTH` 13, plus 1,242 in unlabelled continuation lines. These port as data
  unchanged; they are paid **once**, not per set.
- **Player code: ~522 instruction lines of 6502.** Not assembled, not converted — **counted, and
  labelled as counted.** *Counted ≠ assembled ≠ executed, and this project has been wrong on that
  axis four times.*
- **Per interrupt:** the replay handler measures **94 cycles**. An interpreting one adds envelope
  stepping on top of the same timer write and pulse. ★ **P4.4's "amplitude is free on the DAC" does
  NOT transfer**: P4.6 already found that free applies to a LEVEL, and the slice spends 28 cyc/int
  rendering amplitude as WIDTH for the timbre. An interpreter pays that too, plus the envelope walk.
  **Not measured. Not built.**
- **The decode:** `SET2`'s address table is structurally confirmed (§3D). **The note-stream format
  is not read at all**, and `SET1` — which holds the six songs this comparison is about — is a
  container whose relationship to the loaded page is unmeasured. **HARD-STOP 3 applies: this path
  needs that work, and the capture path has never needed it.**

**Scaling, which is the part the totals hide:** interpret is **~1,024 B per SET** (six songs, or
sixteen); capture is **~1.4 KB per SONG**. The gap widens with every song added.

#### 3F — rests and silence: handled, and INSIDE songs (P4.7 §4, P4.7a §3)

**Both, and the distinction is now measured rather than argued.**

- **HANDLED, not merely found.** Long rests become trains of silent rows; `width 0` emits nothing.
  P4.6b built both and the full-length run passed with `runs consumed 2086` and magic `$504E`.
- **5 long rests fall INSIDE songs** — 2 in `s_Buildup`, 3 in `s_StTimer`. `s_StTimer` is 63
  segments across 4.84 s: a *ticking* sound with genuine multi-second gaps. **So the handling is
  necessary, not an artefact of a mis-delimited window.**
- **And the 5.99 s rest P4.6b cut on was BETWEEN songs** — `s_Magic` ends at 36.75 s, `s_StTimer`
  is called at 42.70 s. **P4.7a's suspicion is correct for that one and wrong as a general claim,
  and only the per-song capture could tell them apart.**

### 4 — Verification (AC-by-AC, all three dispatches)

- **P4.7 AC1 / P4.7a AC3 — per-song sizes measured, cutscene total** — PASS (§3C). Extrapolation
  superseded: 8,588 B is six songs, not one.
- **P4.7 AC2 — compressibility** — PASS. 70% via a decoder already in the port (§3C).
- **P4.7 AC3 — interpreting player costed** — PARTIAL AND SAID SO (§3E): tables exact, code
  counted-not-assembled, per-interrupt work **not measured**, decode **not done**.
- **P4.7 AC4 — sound equivalence surfaced, not decided** — PASS (§6, below).
- **P4.7 AC5 — rests/silence handled or found** — PASS: **handled**, and classified (§3F).
- **P4.7 AC6 — nothing built beyond the measurements** — PASS. No `src/`, no `build.bat`.
- **P4.7a AC1/AC2 — per song id, id-space recorded** — PASS (§3B).
- **P4.7a AC5 — no inter-song timing in the data** — PASS: the per-song files end at the song's
  last speaker event.
- **P4.7b AC1/AC2/AC3 — list from the plan, assert shipped, both numbers reported** — PASS (§3A).
- **AC7 — suites green 128 KB, no instrument on the shipping disk, proven Lua launch** — PASS.
- **AC8 — route accounting** — §6. Karateka untouched; `main` untouched.

### 5 — Verdict-time evidence (v0.7 §11)

```
song                    span s  cap f plan f   delta   runs      4B    dict      LZ  rests
song_7_s_Princess        12.72    763    761   +0.3%    627    2510    1541     542      0
song_8_s_Squeek           1.14     68      -       -     55     222     265     223      0
song_9_s_Vizier           5.86    352    358   -1.7%    253    1014     940     639      0
song_10_s_Buildup         6.45    387      -       -    647    2590    1644     644      2
song_11_s_Magic           1.86    112      -       -    493    1974    1459    1030      0
song_12_s_StTimer         4.84    290      -       -     69     278     212     112      3
------------------------------------------------------------------------------------------
TOTAL                    32.87   1972                  2144    8588    6061    3190      5

★ Every song with a traced duration agrees with it within 5%.
  captured, as shipped (5-byte rows) :  10732 B   2.33x       (vs MUSIC.SET1 4,608 B)
  captured, 4-byte rows              :   8588 B   1.86x
  captured, dictionary-coded         :   6061 B   1.32x
  captured, LZ (decoder already ships):   3190 B   0.69x
  long rests INSIDE songs: 5   silent filler rows: 14

# PC HISTOGRAM for $031A
#   $0CAE    1514 seen, 40 kept        <- per-frame caller; drowned the first run
#   $E479       6 seen, 6 kept         <- the cutscene's PlaySongI: the six title songs
#   $FFBB       1 seen, 1 kept         <- MASTER.S's, later, id 5, different id-space

MSYS.S tables: HM 471, MV 200, HTPTBL 17, AMPTBL 16, NOTE 13, LENGTH 13, (cont) 1242
               TOTAL 1997 bytes; ~522 instruction lines

MUSIC.SET2 offset 104: d0 d1 d1 d1 d1 d1 d1 d2 d2 d2 d2 d3 d3 d3 d3 d3 d3   <- MADRHI

[suites] -ramsize 128K
[run_introseq_test] PASS
[integ] PASS
[suites] ALL PASS
```

**25.2:** N/A — recon; no artifact shipped. **25.3:** N/A for this dispatch; the **timbre ruling
remains PENDING JAY** and is now worth taking (§6).

### 6 — ★★★ THE QUESTION THAT DECIDES IT, WHICH IS JAY'S (P4.7 AC4)

**The numbers do not choose, and I am not going to pretend they lean harder than they do.**

| | capture-and-replay | interpret `MSYS` data |
|---|---|---|
| data, six cutscene songs | 8,588 B resident / 3,190 B on disk | **1,024 B** per set |
| player | **built, measured at 2.0% of a frame** | ~2 KB tables + a player, unwritten |
| scaling | ~1.4 KB per song | ~1,024 B per set |
| sound effects | ★★ **cannot represent them at all** | the oracle's are **code** — `DoPlateDown` is `ldy #70 / ldx #0 / lda #4 / jmp tone` |
| `MUSIC.SET*` decode | never needed | **required, and not done** |
| what it sounds like | **exactly what the Apple emitted** | what the port thinks the notes mean |

**★★ THE ROW THAT IS NOT ABOUT SIZE:** the port's interface is `play_song(id, frames)` and a
captured stream serves it fine — one file per id, already produced. **But the twenty sound EFFECTS
are not data anywhere; they are three parameters and a `jmp tone`.** A capture cannot hold them,
because they fire on demand and layer over whatever is playing. **That is a gameplay problem, not a
cutscene one, and it does not bear on this decision — but it means the interpret path arrives
eventually regardless.**

**What I would ask you to listen for before deciding:** the captured rendition is *exactly* what the
Apple's speaker did, quantisation aside. An interpreted one is the port's reading of the same notes,
and **they are not obliged to agree.** If the capture already sounds right to you, the interpret
path's only argument is size and reach — and 3,190 B on disk is not a size problem today.

### 7 — Uncertainty flags

- **The interpreting player's per-interrupt cost is not measured** and its code size is *counted*,
  not assembled. **Any comparison that treats those as equal-confidence with the 94-cycle replay
  figure is wrong.**
- **The note-stream FORMAT is not decoded.** `SET2`'s address table is confirmed; what the bytes at
  `$d0fe` onward *mean* is unread. **`SET1` — which holds these six songs — is a container, and its
  relationship to the loaded 1,024 B page is unmeasured.**
- **LZ's 3,190 B is a DISK figure.** It must decompress to 8,588 B to play. Whether that trade is
  right depends on where the music lives at run time, which is not decided.
- **The captured spans include the oracle's own tail behaviour.** `PlaySongI` blocks until the song
  ends, so the span is bounded by the *next call*, not by the song's own terminator — a song
  followed by a long animation beat would read longer than it is. The two songs with traced
  durations agree within 2%, which is evidence for four others, not proof about them.
- **`s_Magic` is 967 segments in 1.86 s** and packs to 1,974 B — **the densest song per second by
  far**, and the one most likely to move if the cut point or the capture is off.

### 8 — Follow-up candidates

- **Jay's ruling** on capture-vs-interpret, and on timbre — both now answerable on whole songs.
- Give the traced song durations **a home in the tree**; they exist only in report prose (§3A).
- If capture wins: drop the dead `frac` byte (−20%) and wire the existing LZ decoder (−70%).
- If interpret wins: the `MUSIC.SET1` container and the note-stream format are the first task, and
  neither is a formality.
- Unchanged: the TINS hybrid re-opened for the high band (P4.6b §7); real-hardware constants; the
  other five songs of the *game* set; `Demo` unbuilt.

### 9 — User interaction during task

Jay, mid-task, twice — both changed what was measured before it was measured:
- *"that entire track won't be played continuously during the intro. There are sections played at
  specific times during each intro scene."* (via P4.7a)
- *"I thought capturing each song — or more importantly, playing each song at the appropriate time —
  would have been determined from the oracle doing exactly that."* (via P4.7b)

Both were correct, and the second names a check that had been available in the tree since P3.72l.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-18-ask-the-tree-before-the-instrument.md`

### 11 — Commit

`a78b3cf`  (pushed to origin/wip before this report)
