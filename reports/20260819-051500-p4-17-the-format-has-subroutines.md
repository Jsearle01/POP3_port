## Form B Report — P4.17 (PARTIAL) — the note format has subroutines, which is why 92 bytes plays for nine seconds

**Class:** recon.  wip.  Prod unchanged — no `src/`, no `build.bat`, no shipping disk.
**§1's premise corrected; the player NOT built.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-19 05:15 (HEAD `dfca797`, wip).

### 1 — Summary

**§1 says *"everything needed to build it is now in hand"* and lists the data format as
`MusicTable` + `NOTE` + `LENGTH` + `HM1..HM29`. Those are the TABLES. A player needs the
GRAMMAR of the note stream — what a byte means — and that is undecoded.** P4.16 §7 said so
explicitly: *"This report establishes where each song's bytes are and how many. What a byte
MEANS — note, duration, envelope select, terminator — is unread. That is the interpret
player's actual work and none of it is done."*

**I read enough of `MINIT`/`NEWNOTE` to establish the shape, and it is not a flat note list.**
Songs are **two-byte events**, byte 1 discriminates, and the format includes **control codes,
voice selects, instrument/harmonic selects, song chaining and SUBROUTINE CALLS.**

**★★ The subroutines are the answer to P4.16's open question.** `s_Title` is 92 bytes and plays
for 8.95 s because a phrase can be **called** rather than repeated — a call saves the stream
pointer and jumps, and `$FE` returns. *That is the compression the capture path was recording
the expansion of, and it is why the ratio is 196× rather than 3×.*

**I stopped there rather than starting the player.** Decoding a grammar this shaped and then
building against it is not something to begin at the end of a very long session, and a
half-decoded format produces a player that is wrong in ways only Jay's ear would find.

### 2 — Files modified

None. Reading only.

### 3 — Reasoning

#### 3A — the event structure, from `MINIT`/`NEWNOTE`

```
MINIT     LDX INDEX / LDA MADRLO,X / STA R+0 / LDA MADRHI,X / STA R+1     ; song pointer
NEWNOTE   INC R+0 / INC R+0 / BNE .. / INC R+1                            ; ADVANCE BY TWO
          LDA (R+0),Y  Y=0   -> TAX          ; byte 0
          INY / LDA (R+0),Y  -> byte 1
          BEQ MSYSTM1                        ; byte 1 = 0 -> byte 0 is a COMMAND
          TXA / AND #%11111100 / LSR / LSR   ; else byte 0's top 6 bits are the PITCH
          CLC / ADC R+4                      ; + transpose
```

**So: two-byte events, and byte 1 is the discriminator.**

| byte 1 | byte 0 | meaning |
|---|---|---|
| ≠ 0 | top 6 bits + `R+4` | **a NOTE** — index into `NOTE`; byte 1 carries the duration |
| 0 | `$00` | restart the song (`BEQ MINIT`) |
| 0 | `$FE` | **return** — restores `R+25/R+26` into the stream pointer |
| 0 | `$FD` | sets bit 7 of `$1E80,X` — a flag, purpose unread |
| 0 | `$FF` | pause — loads `NOTE`/`LENGTH` defaults |
| 0 | `< 9` | **voice select** — `MVOLTBL-1,X`, `MVT2-1,X` |
| 0 | `≥ 9` | **instrument select** — `HTPTBL`/`HARMTBL`/`HARMTBH`, with an octave shift above 32 |

**And a second discrimination on byte 1's own bits** (`NMSYSM`): `AND #%00111111` = 0 selects
structural commands —

- **`%10xxxxxx` → song chaining**: `STX INDEX`, continue — one song runs into another.
- **`%01xxxxxx` → CALL**: saves `R+0/R+1` into `R+22/R+23`, adds an offset to the pointer, and
  `$FE` returns. **The format has subroutines.**

#### 3B — why that matters beyond curiosity

**A call/return pair means the byte count is not the note count.** `s_Title`'s 92 bytes can
invoke a repeated phrase many times, so **the stream length says nothing about the duration** —
and a player must implement the call stack or it will play a fraction of the piece and stop.

**★ It also retires an assumption I would have carried into the player**: that a song is a
linear list to walk to a terminator. **It is a small program.**

#### 3C — what is still unread, and it is the load-bearing half

- **Byte 1's duration encoding** — how the non-zero value maps to `LENGTH` and to the FIRQ period.
- **`R+4`'s transpose semantics** and the `CMP #$19` bound in `NEWNOTE`.
- **The envelope path** — `HM1..HM31` are selected via `MBASS1+1/+2` self-modification; how a
  pattern advances per segment is in `MPLAY` (line 464 onward), unread.
- **`$FD`'s flag at `$1E80`**, and `ALTSNG`'s conditional song switch that reads the same table.
- **`MVOLTBL`/`MVT2`/`HTPTBL`/`HARMTBL`** contents and how they combine.

**Roughly: the note-fetch is understood; the sound-production half is not.**

### 4 — Verification (AC-by-AC)

- **AC1 player built** — **NOT DONE.** Its stated prerequisite was not in hand (§1).
- **AC2-AC11** — not reached.
- **AC12 route accounting** — §6. Karateka, `main`, oracle source untouched.

### 5 — Verdict-time evidence (v0.7 §11)

Quoted in §3A from `04 Support/MakeDisk/S/MSYS.S:250-400`.

**25.1/25.2/25.3:** N/A — nothing built; no gate.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING. This report contains** a correction to §1's premise and a partial decode of
the note-stream grammar — the event size, byte 1's discrimination, the seven byte-0 cases, and
the call/return and chaining commands. **It does NOT contain** the player, the A/B, the wiring,
the retirement list (§4 of the dispatch), the hold cost, or the gate.

**No hard-stop fired.** The dispatch's premise was inaccurate and I stopped rather than build
on it — and I am naming session length as the second reason, because it is one: a grammar decode
plus a player plus an A/B plus twelve wirings is a fresh dispatch's work, and starting it here
would produce exactly the half-verified artifact this session has spent fifteen dispatches
correcting.

### 7 — Uncertainty flags

- **§3A's table is a reading of ~150 lines of 6502, not a validated decode.** Nothing was run.
  **Every row of it should be confirmed against the machine or against the data before a player
  depends on it** — the project's own authority stack puts the trace above the source, and this
  is source only.
- **`MPLAY` (line 464+) is entirely unread**, and it is where the per-segment sound production
  lives.
- **The `CMP #$19` bound and `R+4`'s role are guessed as transpose/range from context.** Not
  established.
- **P4.16's 770 B / 92 B figures are unaffected** — they are byte counts from the address table
  and do not depend on the grammar.

### 8 — Follow-up candidates

- **Decode `MPLAY`** — the sound-production half, and the larger one.
- **Validate the grammar against real data**: walk `s_Presents`' 54 bytes by hand against §3A's
  table and see whether it produces a sensible sequence. ★ *That is a strong cheap check and it
  needs no emulator.*
- Then the player, the A/B on `s_Princess`, and the wiring.
- Unchanged: the drift question, the timbre ruling, the retirement list, `Demo`.

### 9 — User interaction during task

None during execution.

### 10 — Candidate(s) captured this task

None. The "dispatch premise inherited an over-confident summary" lesson is
[[ask-the-tree-before-the-instrument]]'s shape and a second row would duplicate it.

### 11 — Commit

See below — pushed to origin/wip before this report.
