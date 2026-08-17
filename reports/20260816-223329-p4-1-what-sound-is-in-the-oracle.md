## Form B Report — P4.1 — what sound IS in the oracle

**Class:** recon. wip. **Nothing designed, nothing built, nothing chosen. No `src/`, `content/`,
`link/` or `build.bat` change.**

**★★★ THE PLAYER IS IN THE VENDOR AFTER ALL — outside `01 POP Source`.
`04 Support/MakeDisk/S/MSYS.S`, 795 lines: *"Music System ][ by Kyle Freeman (c) 1986, Adapted by
Jordan Mechner July 1989"*, `org $D400`, opening `jmp _MINIT` / `jmp _MPLAY`. The data is
`Other/MUSIC.SET1/2/3`. So the music can be READ, not merely measured — which is the finding the
dispatch said would change the whole approach.**

**★★★ AND THE SINGLE MOST CONSEQUENTIAL FACT (AC5): in the oracle a beat's LENGTH IS AN OUTPUT OF
THE MUSIC, NOT AN INPUT. `PlaySongI` loops until `mplay` returns 0. The port has inverted that —
`play_song` spends a fixed frame count. The port's durations were traced with sound ON, so they
already equal the songs' lengths; honouring them means FITTING music to a fixed beat, which is a
different problem from playing a song and letting it end.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-16T22:33:29-04:00 (HEAD `34e93e0`, wip; `main` level at the same commit after P3.108).
`git status` clean but for this report. Karateka untouched. `main` untouched. **Oracle source
read-only — read only, never written.**

---

### 1 — Summary

| | |
|---|---|
| **★★★ player LOCATED** | `04 Support/MakeDisk/S/MSYS.S`, 795 lines, `org $D400` — Kyle Freeman's *Music System ][*, 1986 |
| **★★ data** | `Other/MUSIC.SET1` 4,608 B · `SET2` 1,024 B · `SET3` 4,608 B; `MusicTable = $D000` |
| **★★★ id spaces** | **THREE**, not two — and the discriminator is **not the id**, it is **which set is loaded from disk** |
| **★★ the port's four names** | all in the **title** set: `s_Princess 7`, `s_Vizier 9`, `s_Buildup 10`, `s_Magic 11` (+`s_StTimer 12`) |
| **★★ mechanism** | Apple one-bit speaker, `LDA $C030` between `DEY/BNE` delay loops — **CPU-timed bit-bang** |
| **★★★ durations** | **music-driven in the oracle, frame-driven in the port** — §3E |
| **★★ prior art** | Sock Master: **binary/shareware only, no source**. Fiscarelli's POP demo: **disk image only**. **The GIME reference IS readable and is directly on point** |
| **★★★ GIME** | *"The 279 ns clock is useful for **interrupt driven sound routines**"* — and `$FExx`/`$01xx` vectors are changeable |

### 2 — Files modified

**None.** This report is the only new file.

### 3 — Reasoning

**3A — ★★★ WHERE THE PLAYER IS, AND WHY THE GREP MISSED IT.**

`minit`, `mplay` and `musickeys` appear in `EQ.S` as **`ds 3`** — three-byte `JMP` slots in a
vector page at **`grafix = $400`** [`EQ.S:21`]. The same shape as `DrawGuard ds 3`. So a grep for
a *definition* in `01 POP Source/Source` correctly returns nothing: **those are call stubs, and
the dispatch's premise was right about the directory and wrong about the vendor.**

The chain, followed rather than inferred:

```
  minit/mplay        EQ.S      ds 3 @ grafix $0400   — vector slots
    -> CALLMINIT/CALLMPLAY   GRAFIX.S:1850-1878     — switchzp around the call
      -> _minit/_mplay       GAMEEQ.S  ds 3 @ msys $D400
        -> MSYS.S            04 Support/MakeDisk/S/  — `org $d400`, `jmp _MINIT`/`jmp _MPLAY`
```

**`msys = $D400`** and **`sound = $EA00`** [`GAMEEQ.S:31,36`], and `MSYS.S` opens at exactly
`$D400` with those two jumps. **It is the file.** `switchzp` around every call means the player
runs with **its own zero page** — 30 bytes of state at `R = $00`.

**3B — THE DATA, AND HOW A SONG ID RESOLVES.**

`MusicTable = $D000`; `MADRLO = MusicTable`, `MADRHI = MusicTable+$68`. **So the id is an index
into a split lo/hi address table** — `$68` = 104 entries, which bounds the set at ≤104 songs.
`MSYS.S` also carries a `NOTE` table of **75 period values** (122, 254, 238 … 9) and a `LENGTH`
table of note durations.

**On disk** [`MASTER.S:252-280`]:

```
  loadmusic1   (title)   track 34, RdSeq $4e   ";we only want $50-53"
  loadmusic2   (game)    track 20, RdGrp.Inc   50,51,52,53
  loadmusic3   (epilog)  jmp loadmusic1
```

★ Vendored: `MUSIC.SET1` 4,608 B, `SET2` 1,024 B, `SET3` 4,608 B. `SET2`'s 1,024 B is exactly the
four 256-byte sectors `$50-53`; the other two are 4,608 B = one whole Apple track. **I have NOT
established that the three vendored files map one-to-one onto loadmusic1/2/3** — the sizes do not
obviously agree with the sector lists, and asserting the mapping is precisely the kind of
inference this project keeps paying for. **Named as open.**

**3C — ★★★ THREE ID SPACES, AND THE DISCRIMINATOR IS NOT THE ID.**

`SOUNDNAMES.S` carries three blocks, and its own comments label them:

```
  (unlabelled)   PlateDown 0 … JawsClash 19      20 sound EFFECTS
  * game music   s_Accid 1 … s_Heartbeat 16
  * title music  s_Princess 7 … s_StTimer 12
```

`s_Vict = 7` and `s_Princess = 7` collide — **and the resolution is that they are the same index
into two different blobs that occupy the same memory at different times.** `loadmusic1`/
`loadmusic2` read different disk tracks into `$D000`. ★★ **The id space is not what
disambiguates; the loaded SET is.** A song id is meaningless without knowing which set is
resident, and nothing in the id carries that.

**The port's four cited names are all title-set** (`s_Princess`, `s_Vizier`, `s_Buildup`,
`s_Magic`), as is the stubbed `s_StTimer`. ★ **They sit in the space the port thinks they do**
— AC3 answered — **but the port has no concept of a loaded set**, and the cutscene is entirely
title-set, so nothing has yet required one.

**3D — HOW A SOUND IS ACTUALLY MADE, AND WHAT THAT IMPLIES FOR A DAC.**

Both systems bit-bang the Apple's one-bit speaker at `$C030`.

**Effects** are a lookup table of 20 routines [`SOUND.S`], almost all of which reduce to one
primitive:

```
  DoFootstep      ldy #35 / ldx #0 / lda #3 / jmp tone
  DoRaisingExit   ldy #40 / ldx #0 / lda #6 / jmp tone
  DoRaisingGate   ldy #20 / ldx #0 / lda #2 / jmp tone

  tone   sty :pitch / stx :pitch+1
  :outloop  bit spkr          <- ONE toggle per outer pass
            ...nested Y then X delay loops...
            sbc #1 / bne :outloop
```

★ So an effect is **(period, repeat-count) → a square wave**. `Y`=inner period, `X`=outer
multiplier, `A`=number of half-cycles. **That is three numbers per effect, and they transcribe
directly to any tone generator.** The 20 effects are a small, readable, fully-specified set.

**Music** is the same idea with a note table: `M30A LDA $C030` … `MVDIT DEY/BNE MVDIT` …
`M30B LDA $C030` — two toggles bracketing a delay = one square-wave cycle at the period in `R+6`.
There are two such blocks (`M30x` and `M20x`), which is **not** established to be two voices and
should not be read as such.

★★★ **THE IMPLICATION FOR THE CoCo3'S 6-BIT DAC.** The Apple's mechanism is *one bit toggled by
CPU timing*; the CoCo3 has a **6-bit DAC** (`$FF20`), which is strictly more capable. So the
oracle's sound is **fully described by frequency and duration** — there is no timbre, no envelope,
no sample content to recover. **Reproducing it does not require emulating the speaker; it requires
producing the same frequencies for the same durations.** ★ Under §2I the mandate is that it
*sounds* right, and re-synthesising a square wave through a DAC is the same waveform by a cheaper
route — **but that is an observation about the source material, not a design, and I am not
choosing it.**

**3E — ★★★ THE DURATION QUESTION (AC5), WHICH IS THE ONE THAT DECIDES THE SHAPE.**

`PlaySongI` [`SUBS.S:818-845`], in full structure:

```
PlaySongI
 tay
 lda soundon / and musicon / bne :1
 txa / beq ]rts / jmp play        <- SOUND OFF: X = # plays. THE FALLBACK, not a length.
:1 tya
 jsr minit
 jsr swpage
:loop jsr musickeys
      cmp #$80 / bcs :interrupt
      jsr pburn                   <- torches
      jsr pstars                  <- stars
      jsr pflow                   <- the hourglass sand
      jsr mplay                   <- ONE SLICE of music
      cmp #0
      bne :loop                   <- until the song reports itself finished
```

**Three facts follow, and they are the whole of the design's ground:**

1. **The beat ends when the SONG ends.** `mplay` returns the song number and **0 when done**;
   nothing counts frames. ★ **In the oracle, duration is an output.**
2. **The scenery is clocked BY the music.** `pburn`/`pstars`/`pflow` run **once per `mplay`
   call** — the torch flicker rate, the star twinkle and the sand flow are all downstream of the
   music player's slice rate. **They are not independent clocks.**
3. **`X` is the sound-OFF fallback**, exactly as P3.52 established and the dispatch restates.
   ★ **Not a duration.** Confirmed by reading: it is only reached when `soundon AND musicon` is
   false.

**The port is the mirror image.** `play_song` [`intro_seq.s:897`]:

```
play_song   tfr x,d          ; "the frame count; the song id is not used yet"
            (falls through into hold_frames — a VBL-counting loop)
```

★★★ **So the port spends a FIXED, TRACE-MEASURED number of frames** — `s_Princess` 761,
`s_Vizier` 358, the intro's 281/283/537/760/1564/310 — **and those numbers were measured on the
oracle with sound ON, which means they already ARE the songs' lengths.**

**Therefore, stated plainly as AC5 requires:** *the durations can be honoured, and honouring them
is a constraint on the music rather than a consequence of it.* The port must **fit** a rendition
into a known frame count. That is strictly easier than matching a free-running player — nothing
can drift — **but it inverts the oracle's causality, and two things follow that a designer must
not discover later:**

- **the port's torches are already independent of any music** (`flm_cad 2,2,3`, its own cadence),
  so the oracle's coupling in fact (2) is **already not reproduced**, and adding music must not
  re-introduce it by accident;
- **if a rendition is shorter than its beat, the beat still ends on time** — silence at the tail,
  not a short beat. **That is a visible/audible design decision and it belongs to Jay.**

**3F — CPU COST, WHICH IS A FIRST-CLASS QUESTION AND IS NOT ANSWERED HERE.**

In the oracle the CPU **is** the sound: `tone`'s delay loops and `MSYS`'s `MVDIT DEY/BNE` burn
every cycle a note lasts. The oracle affords it because `pburn`/`pstars`/`pflow` are the only
other work in that loop.

★★ **The port's worst beat already spends 92.6% of its frame budget** (carried figure), and
P3.102 measured the exit's iteration at **63.2 ms of work against a 66.75 ms four-frame budget —
5.6% of headroom.** ★★★ **A blocking bit-bang cannot fit there.** That is not a design choice; it
is arithmetic against a measurement this project already has.

**3G — §2H's THREE CHECKS.**

1. **A second mechanism for a different object class?** ★ **Yes, and there are FOUR systems, not
   the two the dispatch named:** the effects (`$EA00`), the music player (`$D400`), the music
   *data* (`$D000`, disk-swapped in sets), and `musickeys` — a separate input path polled inside
   the play loop. The dispatch found two; the tree has four, and the fourth is why the loop can be
   interrupted at all.
2. **The calling routine.** `mplay` is not the unit of a song — it is a **slice**, called in a
   loop that also drives the scenery. Reading `MSYS.S` alone would make it look like a
   fire-and-forget player.
3. **Grep the reports.** P3.52 established `X` as the sound-off fallback and the Orchestrator read
   it as a duration once. **Re-checked against the source this dispatch: P3.52 is right.**

### 4 — Verification (AC-by-AC)

- **AC1 — the music player located.** §3A. `04 Support/MakeDisk/S/MSYS.S`. **Present in the
  vendor, outside `01 POP Source`. It can be READ.**
- **AC2 — the music data characterised.** §3B. Format (lo/hi address table at `$D000`, ≤104
  entries, note-period and length tables in the player), sizes, and the disk tracks. ★ The
  mapping from the three vendored `MUSIC.SET*` files to `loadmusic1/2/3` is **not** established.
- **AC3 — the id spaces disambiguated; the port's names placed.** §3C. **Three spaces; the
  discriminator is the loaded set, not the id.** The port's four are title-set, correctly.
- **AC4 — how an effect makes a sound, and what it implies for a DAC.** §3D. `(period, repeat)` →
  square wave; the oracle's audio is fully described by frequency and duration, with no timbre to
  recover.
- **AC4a — prior art surveyed, availability reported rather than summarised.**
  - **Sock Master (John Kowalski)** — [his page](https://www.6809.org.uk/twilight/sock/) lists
    Donkey Kong, Donkey Kong Remixed, the CoCo Demos, **CoCoTracker** (a MOD player) and
    **Digi-512** (an audio digitiser). ★ **All binary/shareware; no source code is offered for
    any of them.** So the Donkey Kong hardware-emulation approach is an **existence proof, not a
    readable design.** ★★ CoCoTracker and Digi-512 are the more directly relevant artifacts —
    multi-channel sample playback and 6-bit sampling, both shipped on this machine.
  - **The GIME reference IS readable and is already vendored** at
    `docs/ground-truth/SockmasterGime.md`. ★★★ **Directly on point:** *"The 279 ns clock is useful
    for **interrupt driven sound routines**"* — the 12-bit countdown timer, `TINS` at `$FF91`,
    `TMR` enable at `$FF92` bit 5 — and *"you can change the `$FExx` and `$01xx` vectors"*. **So
    interrupt-driven audio is documented hardware, and the port already installs a VBL handler.**
  - **Simon Jonassen** — 2-voice CoCo3 music demonstrably exists; **no published source surfaced.**
    Not built on.
  - **Paul Fiscarelli's Prince of Persia Demo (CoCo 3)** — real, added to the
    [Color Computer Archive](https://colorcomputerarchive.com/updates/2021) 2021-11-17,
    **available as a disk image only.** ★ **What it does with sound is NOT established** — I did
    not download or run it, and no description of its audio surfaced.
- **AC5 — whether the trace-measured durations can be honoured.** §3E. **Yes, and the reason
  matters: they are already the songs' lengths, so the constraint is to FIT music to a fixed beat
  rather than to let a song set the beat.**
- **AC6 — options reported with costs; nothing chosen, nothing built.** §5.
- **AC7 — route accounting; clean tree; Karateka; `main`.** §6.

### 5 — The options, with costs. **Nothing chosen.**

Stated as a menu because §3 of the dispatch says to report and not decide. Each carries the CPU
question of §3F, which is the constraint every one of them meets first.

| | what it is | cost / risk |
|---|---|---|
| **A. Transcribe the note data** | read `MUSIC.SET*` through `MSYS.S`'s format, emit note/duration pairs, write a CoCo3 player | Needs the data format decoded and the set→file mapping settled (§3B open). Gives exact melodies. Player cost is ours to choose — **an interrupt-driven DAC player is the documented shape** (§4/AC4a). |
| **B. Emulate the speaker** | Sock Master's Donkey Kong shape: run the oracle's timing and render its toggles | ★ **Existence proof only — his source is not available.** Requires the 6502 player's cycle timing to be reproduced on a 6809 at a different clock. **Most faithful, most expensive, and the least readable prior art.** |
| **C. Effects only, first** | the 20 `SOUND.S` routines are `(period, repeat)` triples | **Smallest, best-specified, and independently useful.** Does not touch the cutscene's beats at all — effects belong to gameplay, which is unbuilt. |
| **D. Sample playback** | pre-render on the host, play PCM through the DAC | Digi-512/CoCoTracker prove the hardware does it. **Disk and CPU cost unmeasured**; the scene is already one page from a single load. |

★★ **What is common to all four and is the real gate:** the port's exit iteration has **5.6%
headroom** against a whole-frame boundary (P3.102). **Any per-frame audio cost that exceeds it
moves the iteration from 4 frames to 5 and the step from 8 to 10** — a 25% pace change, visible,
on a scene Jay has already gated. **That is the number the next dispatch should measure against
before anything is chosen.**

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** Against §4's seven criteria: **AC1–AC7 in full, all recon.** No route
proposed. **Nothing designed, nothing chosen, nothing built** — §5 is a menu with costs, as
instructed.

**Reactive deviations (§22.5):** none. No file was modified; the oracle was read only.

**★ One correction to the dispatch's premise, which is why it mattered:** *"the music player is
not in the vendored source … a grep across the tree returns nothing."* **The grep was run against
`01 POP Source/Source`**, where the names appear only as `ds 3` vector slots. The player is in
`04 Support/MakeDisk/S/` and the data in `Other/`. ★★ **This flips the approach from *measure* to
*transcribe*** — HARD-STOP 2's branch does not fire.

Karateka untouched. `main` untouched. Oracle read-only and **not executed** — this dispatch ran no
emulator at all.

### 7 — Uncertainty flags

- **★★ The `MUSIC.SET*` → `loadmusic1/2/3` mapping is NOT established** (§3B). Sizes do not
  obviously match the sector lists. **Nothing should assume `SET1` is the title set** until it is
  read.
- **★★ The music data FORMAT is not decoded.** I located the table (`$D000`, lo/hi, ≤104 entries)
  and the player's note/length tables; **I did not decode a single song.** "It can be read" is a
  claim about availability, not about having read it.
- **★ `M30x`/`M20x` are two tone blocks in `MSYS.S` and I do not know what distinguishes them.**
  **Not** established to be two voices; the dispatch's mention of Jonassen's 2-voice work makes
  that an inviting inference and it is unsupported.
- **★ Fiscarelli's demo is unexamined** — disk image only, not downloaded, not run.
- **★ CoCoTracker/Digi-512 are named from a download page**, not from having run them.
- **★ The 92.6% figure is carried, not re-measured this dispatch.** P3.102's 5.6% headroom IS
  this project's own measurement and is the sounder of the two.
- Carried from the port track: `Demo` unbuilt; **the cel bank does not survive the 16-colour
  mode**; the two freezes; the mirrored chroma; the exit's +13%; one page from a single load.

### 8 — Follow-up candidates

1. **Decode one song**, end to end, from `MUSIC.SET*` through `MSYS.S`'s table into note/duration
   pairs — and settle the set→file mapping while doing it. **That is the fact everything in §5
   option A rests on.**
2. **Measure the audio budget** against P3.102's 5.6% headroom, before choosing anything. A
   timer-interrupt player's cost per interrupt is measurable on the port as it stands.
3. **The 20 effects** are the cheapest real deliverable and are independent of the cutscene's
   timing — but they belong to gameplay, which is unbuilt.
4. Ask Jay whether Simon Jonassen can be approached directly (§2a suggests he may be reachable);
   his 2-voice work is the closest live expertise and none of it is published.

### 9 — User interaction during task

None.

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-16-a-duration-can-be-an-output-on-one-side-and-an-input-on-the-other.md`

### 11 — Commit

See below — pushed to origin/wip before this report.

**Sources** (AC4a):
- [Sock Master's Tandy Color Computer 3 Page](https://www.6809.org.uk/twilight/sock/)
- [awesome-coco (dougmasten)](https://github.com/dougmasten/awesome-coco/blob/main/README.md)
- [Sock Master updates Donkey Kong for the CoCo 3 — AtariAge](https://atariage.com/forums/topic/240607-sock-master-updates-donkey-kong-for-the-coco-3/)
- [TRS-80 Color Computer Archive — 2021 updates](https://colorcomputerarchive.com/updates/2021)
