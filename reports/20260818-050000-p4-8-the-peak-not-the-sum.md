## Form B Report — P4.8 — the peak, not the sum, and against the right denominator

**Class:** recon.  wip.  Prod unchanged — `build/probe.dmk` still 6 files / 36,673 B / 13,824 B free.
**Nothing was built.** One measurement tool; no player, no decode, no change to `src/` or `build.bat`.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-18 05:00 (HEAD `efc1391`, wip).

### 1 — Summary

Jay: *"I still feel like he is comparing apples to oranges. The whole song bank doesn't have to be
resident, just the one about to be used. And once played, the next song could use the same memory."*

**Correct, and the sentence he is objecting to is mine.** P4.7 §1 said *"in RAM it is 8.4× the
oracle's resident 1,024 B, and that ratio is the whole decision."* **Both halves were the wrong
quantity** — a sum of six songs over a set holding sixteen.

**Measured:** the peak is **2,590 B** decompressed (`s_Buildup`) — **30% of the sum, 2.53× the
oracle's resident set** — and **1,030 B compressed**, which is **1.01×: parity**. Streaming would
not move the peak, and that is a fact about the format rather than a preference.

**And the denominator correction runs the other way too:** the interpret path needs `MSYS`'s
**1,997 B of tables** resident alongside its 1,024 B of data. **3,021 B against the capture path's
2,590 B peak.** On residency the two are comparable, with capture marginally ahead.

### 2 — Files added

- `harness/tools/song_residency.py` — NEW. Per-song raw/compressed sizes, the peak, and the maximum
  LZ back-reference per song. Asserts the compress/decompress round trip before printing anything.

No `src/`, no `build.bat`, no shipping disk. Suites green at 128 KB.

### 3 — Reasoning

#### 3A — ★★★ A SUM IS NOT A RESIDENCY REQUIREMENT, AND THIS IS THE THIRD TIME

| | the sum | the peak | peak/sum |
|---|---|---|---|
| P3.62 | 37,602 B — *"no representation fits"* | 5,631 B | 17% |
| P3.72m | 41,437 B — *"2.6× the bank"* | 6,769 B | 18% |
| **P4.7 (mine)** | **8,588 B — *"8.4×"*** | **2,590 B** | **30%** |

★★ **The first two were the cel subsystem. This one is audio.** Recurring in an unrelated subsystem
is what turns it from a property of the cel data into a property of the project, and the mechanism
is the same each time: **a total is the number the tool naturally prints, and residency is a
question about the worst single moment.**

**`play_song(id, frames)` is what guarantees it here** — the interface has been in the tree since
P3.52 and it plays exactly one song. The next beat's song is not wanted until the current one ends.

#### 3B — the peak, measured

| song | span | raw B | LZ B | ratio | max back-ref |
|---|---|---|---|---|---|
| `s_Princess` | 12.72 s | 2,510 | 542 | 0.22 | 2,112 |
| `s_Squeek` | 1.14 s | 222 | **223** | **1.00** | 60 |
| `s_Vizier` | 5.86 s | 1,014 | 639 | 0.63 | 344 |
| **`s_Buildup`** | 6.45 s | **2,590** | 644 | 0.25 | 848 |
| `s_Magic` | 1.86 s | 1,974 | **1,030** | 0.52 | 1,016 |
| `s_StTimer` | 4.84 s | 278 | 112 | 0.40 | 216 |

- **Peak decompressed: 2,590 B** (`s_Buildup`) — the number that binds if the player needs a whole
  song in memory.
- **Peak compressed: 1,030 B** (`s_Magic`) — **a different song**, which is worth noticing: the
  largest song and the least compressible one are not the same, so neither ranking predicts the other.
- **`s_Squeek` does not compress at all** — 223 B out of 222 B in. At 55 rows there is nothing for a
  match to find, and the token overhead exceeds the saving. *Reported because an average ratio of
  0.37 would have hidden it.*

**★ THE ORCHESTRATOR'S LEAD WAS HALF RIGHT AND IT MATTERS WHICH HALF.** §1 predicted *"800-1,200 B
resident"*. That is almost exactly the compressed peak (1,030 B) and **2.2-3.2× under the
decompressed one (2,590 B)** — and "resident" was the word used. **Measured, as the dispatch
instructed.**

#### 3C — ★★★ STREAMING: THE FORMAT ANSWERS IT, AND THE ANSWER IS NO

LZ4-style matches copy **from the decoded output**, so an incremental decoder must retain every
byte within its largest back-reference. That distance is measurable, and it is large:

| song | max back-ref | of raw | streaming verdict |
|---|---|---|---|
| `s_Princess` | 2,112 | **84%** | the history window IS the song |
| `s_Magic` | 1,016 | 51% | the window IS the song |
| `s_StTimer` | 216 | 78% | the window IS the song |
| `s_Buildup` | 848 | 33% | an 848 B window would serve |
| `s_Vizier` | 344 | 34% | a 344 B window would serve |
| `s_Squeek` | 60 | 27% | a 60 B window would serve |

**And it does not move the peak.** Streaming `s_Buildup` costs its 848 B window plus its 644 B
compressed source ≈ **1,492 B**, which is a real saving — but the peak then becomes `s_Princess`
at **2,510 B**, whose own window is 84% of itself. **2,590 → 2,510 B. Two percent.**

**★ AND THE SHIPPED DECODER IS NOT RESUMABLE ANYWAY.** `src/engine/lz_unpack.s` expands a whole
blob in one call, in place, with no saved state and no partial-output entry point. **That is a fact
about the code as it exists**, and it is the smaller of the two obstacles — the format's reach is
the binding one.

**★ ONE LEVER NAMED AND NOT MEASURED:** capping the compressor's match distance would bound the
window by construction, at some cost in ratio. `lz_pack.py` has a `--window-cap` for the in-place
safety argument, not for this. **Whether a 512 B cap would pay is unmeasured, and I am not going to
estimate it** — §1's lead is the reason.

#### 3D — the denominator, corrected in both directions

**The oracle's 1,024 B is a SET.** `loadmusic1`/`loadmusic2` each read four sectors into
`MusicTable = $d000`; `MSYS` indexes into whichever set is resident and **never reloads between
songs**. So it is not a per-song figure and the port's peak is not comparable to it directly.

**★★ AND THE INTERPRET PATH'S RESIDENCY IS NOT 1,024 B EITHER.** `MSYS`'s tables — `NOTE`, `LENGTH`,
`MV0..15`, `HM1..31`, `AMPTBL`, `HTPTBL` — are **1,997 B** (P4.7 §3E, counted from the source) and
must be resident for any note to be interpreted:

| | resident, worst moment | reloads |
|---|---|---|
| **capture** | **2,590 B** (one song, decompressed) + ~1.2 KB player | **one disk read per beat** |
| **interpret** | 1,024 B set + **1,997 B tables** = **3,021 B** + player | none within a set |

**So on residency the capture path is SMALLER, not 8.4× larger.** The honest difference is not
memory at all — it is **a disk read between beats** on one side, and **an unwritten player plus an
undecoded format** on the other.

★ *That inversion is what a sum over a set was hiding, and it took Jay's objection to find it.*

### 4 — Verification (AC-by-AC)

- **AC1 per-song compressed AND decompressed, all six** — PASS (§3B). Round trip asserted before
  any number is printed.
- **AC2 the peak stated, and what it is peak of** — PASS: **2,590 B, one song, decompressed,
  `s_Buildup`**; compressed peak is a *different* song at 1,030 B.
- **AC3 denominator corrected** — PASS (§3D), and corrected in the direction that hurts my own
  earlier framing.
- **AC4 incremental decode, as a fact about the format** — PASS (§3C): the format's back-references
  reach 84% across the largest song, so the history window is the song; and the shipped decoder has
  no resumption entry regardless. **HARD-STOP 3 applies and is reported, not argued around.**
- **AC5 the trade re-stated fairly** — §6.
- **AC6 nothing built beyond the measurements** — PASS. No `src/`, no `build.bat`.
- **AC7 suites green 128 KB; Karateka and `main` untouched** — PASS.

### 5 — Verdict-time evidence (v0.7 §11)

```
song                    span s   RAW B    LZ B  ratio  max off  off/raw
song_7_s_Princess        12.72    2510     542   0.22     2112     0.84
song_8_s_Squeek           1.14     222     223   1.00       60     0.27
song_9_s_Vizier           5.86    1014     639   0.63      344     0.34
song_10_s_Buildup         6.45    2590     644   0.25      848     0.33
song_11_s_Magic           1.86    1974    1030   0.52     1016     0.51
song_12_s_StTimer         4.84     278     112   0.40      216     0.78

★★★ THE PEAK — one song at a time, because play_song(id, frames) plays one.
  largest DECOMPRESSED song :   2590 B  (song_10_s_Buildup)
  largest COMPRESSED song   :   1030 B  (song_11_s_Magic)
  the SUM of all six        :   8588 B raw /   3190 B compressed
  peak is 30% of the raw sum — a sum was never the requirement

★ AGAINST THE ORACLE'S RESIDENT SET (1024 B, holding ALL of them):
  port peak resident, decompressed :   2590 B  = 2.53x
  port peak resident, compressed   :   1030 B  = 1.01x

[suites] -ramsize 128K
[run_introseq_test] PASS
[integ] PASS
[suites] ALL PASS
```

**25.2:** N/A — recon. **25.3:** N/A for this dispatch; the **timbre ruling remains PENDING JAY**.

### 6 — ★★★ THE TRADE, RE-STATED WITH FAIR NUMBERS (AC5)

| | **capture-and-replay** | **interpret `MSYS` data** |
|---|---|---|
| resident, worst beat | **2,590 B** (one song) | **3,021 B** (1,024 set + 1,997 tables) |
| disk, all six | 3,190 B | 1,024 B |
| between beats | **a disk read** | nothing |
| player | **built, measured at 2.0% of a frame** | unwritten; per-interrupt cost unmeasured |
| `MUSIC.SET*` decode | never needed | **required, and not done** |
| sound effects (20) | cannot represent — they are `jmp tone` with 3 parameters | native |
| what it sounds like | **exactly what the Apple emitted** | what the port thinks the notes mean |

**Both are affordable.** The residency question that prompted three dispatches is **settled and it
does not discriminate** — 2,590 against 3,021 is not a difference worth choosing on.

**★★ SO IT IS ENTIRELY YOURS, ON SOUND.** The numbers now say only that either can be built. What
they cannot say is whether an interpreted rendition sounds like the one you have, and **they are not
obliged to agree** — the capture is what the Apple's speaker did; an interpretation is the port's
reading of the same notes through a different amplifier.

**The one thing that is not symmetric:** the interpret path arrives eventually regardless, because
**the twenty sound effects have no data representation to capture.** That is a gameplay problem, and
it does not bear on the cutscene.

### 7 — Uncertainty flags

- **`s_Squeek` compresses to larger than raw.** A 1.00 ratio on one song is a reminder that the
  3,190 B total is an aggregate over very different material.
- **The disk-read-between-beats cost is unmeasured.** §6 lists it as a difference without a number;
  the beats are 1.1-12.7 s long, so there is time, but *"there is time"* is not a measurement and
  the loader's behaviour under a beat boundary has not been tested.
- **The window-cap lever is unmeasured** (§3C) and would change the streaming answer if it paid.
- **The interpret side's 3,021 B counts tables and data only.** Its player code is *counted*, not
  assembled — the same caveat P4.7 §7 carried, and it is why the two columns in §6 are not equally
  firm.
- **The peak assumes one song resident at a time with nothing pre-loaded.** If a beat ever needs the
  next song staged while the current one plays, the peak becomes a sum of two — **and the two
  largest are 2,590 and 2,510.**

### 8 — Follow-up candidates

- **Jay's ruling** on capture-vs-interpret and on timbre — both now answerable, and the size
  question no longer weighs on either.
- Measure the disk read at a beat boundary if capture wins.
- The `frac` byte (−20%) is still dead weight in the shipping row format.
- Unchanged: the TINS hybrid re-opened for the high band; real-hardware constants; the traced song
  durations still have no home in the tree; `MUSIC.SET*`; `Demo` unbuilt.

### 9 — User interaction during task

Jay, verbatim and in full: **"I still feel like he is comparing apples to oranges. The whole song
bank doesn't have to be resident, just the one about to be used. And once played, the next song
could use the same memory."** He was right, the sentence he objected to was mine, and checking it
inverted the comparison rather than merely narrowing it.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-18-a-ratio-can-be-wrong-on-both-sides.md`

### 11 — Commit

See below — pushed to origin/wip before this report.
