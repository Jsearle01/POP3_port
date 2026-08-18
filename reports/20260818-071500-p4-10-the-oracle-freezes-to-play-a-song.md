## Form B Report — P4.10 (RECON) — the oracle FREEZES the game to play a song, and thirteen gates exist to hide it

**Class:** recon.  wip.  **Nothing built.** No `src/`, no `build.bat`, no harness, no shipping disk.
Oracle source read-only throughout.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-18 07:15 (HEAD `1db8da3`, wip). Source-only; no runs needed, so P4.9's scene index was
not required (HARD-STOP 3 did not arise).

### 1 — Summary

**Jay: *"I would suspect that there are only sound effects during gameplay, because a song of any
length would make gameplay stall or choppy at best."***

**Right about the stall, and it is worse than "choppy": `songcues` stops the game dead and runs the
song to completion in a spin loop.** Wrong about the consequence — **gameplay uses both.** Effects
run every frame through a non-blocking table; songs freeze everything.

**★★★ AND THE INTERESTING PART IS THE THIRTEEN GATES, WHICH ARE NOT ABOUT THE MUSIC AT ALL.** Every
one asks *is anything moving that would look bad frozen?* — the kid mid-move, the shadow, slicers,
MOBs, lightning, impact stars. **`SongCue`/`SongCount`/`songcues` is machinery for hiding a stall,
and the port's FIRQ player has no stall to hide.**

**But four things it encodes are real intent, not workaround** — and two of them are other code
**waiting on `SongCue`**, which a non-blocking player would silently turn into no-ops.

### 2 — Files modified

None.

### 3 — Reasoning

#### 3A — `songcues` in full (AC1) — `TOPCTRL.S:1388`

**Inputs:** `SongCue` (0 = none, else song #), `SongCount`.

**The gate chain — it returns without playing unless ALL of these hold:**

| # | condition | the comment, where there is one |
|---|---|---|
| 1 | `EditorDisk` false | (assembles an early `rts` when building the editor) |
| 2 | `SongCue ≠ 0` | |
| 3 | **`level ≠ 0`** | **`;no music in demo`** |
| 4 | **`SongCount ≠ 0`** | **`;when SongCount reaches 0, forget it`** — else clears the cue |
| 5 | not (`KidPosn=0` and `NextLevel=level`) | **`;Play only one song once kid has reached stairs`** |
| 6 | `KidPosn` is `static?` | |
| 7 | shadow absent or static | `ShadFace=86`, or `ShadScrn≠VisScrn`, or `ShadPosn` static |
| 8 | **`trobcount = 0`** | **`;slicers or other fast-moving objects / that it wouldn't look good to freeze`** |
| 9 | `nummob = 0` | `;wait for no MOBs and no lightning` |
| 10 | `lightning = 0` | |
| 11 | `mergetimer` clear | |
| 12 | **`ChgKidStr | ChgOppStr = 0`** | **`;& no impact stars`** |

Then, under the comment **`* Prepare for minimal animation`**:

```
 lda PAGE / eor #$20 / sta PAGE      flip to the other page
 jsr listtorches
 lda SongCue / jsr minit
 sta $c010                           clear the keyboard
:loop jsr burn                       torches only
 jsr musickeys
 jsr mplay
 cmp #0 / bne :loop                  ★ spins until the song ENDS
:done lda #0 / sta SongCue
 lda PAGE / eor #$20 / sta PAGE
 jmp clearjoy
```

**What continues: the torches (`burn`) and the keyboard (`musickeys`). What blocks: everything
else** — the kid, opponents, collision, the timer, input. **`* Prepare for minimal animation` is the
author naming the workaround in his own comment.**

★ **§2H, second check — the enclosing routine is the fact.** The dispatch flagged that the
Orchestrator called line 300 "the game loop" from a grep. Line 300 is **level init** (`sta heroic /
sta ChgKidStr / …`). The main-loop call is **`TOPCTRL.S:393`**, and it is real:

```
 jsr FrameAdv     ;Draw next frame & show it
 jsr playback     ;Play sounds
 jsr zerosound    ;& zero sound table
 jsr flashoff
 jsr songcues     ;Play music        <- every frame
```

#### 3B — cued and deferred (AC2)

**The cue is set from all over, and never played by the setter:** `TOPCTRL.S:155` (`s_Danger`),
`TOPCTRL.S:1206/1210` (`s_Accid` "accidental death" / `s_Heroic`), `AUTO.S:1653/1796` (`s_Danger`),
`SUBS.S:490/607/633` (`s_Heartbeat`), `SUBS.S:616` (`s_Danger`), `SUBS.S:652` (`s_Timer`).

**So: any code may raise a cue; the main loop plays it at the first moment the screen can be frozen
without it showing.** That is emphatically *cued-and-deferred*, and it is the answer to the question
the dispatch said would decide whether Jay's hypothesis holds.

#### 3C — `SongCount` is a deadline in frames (AC3)

Set beside the cue (`sta SongCue / stx SongCount`, `SPECIALK.S:1333-1334`), **decremented once per
frame that the cue is pending**, and at zero the cue is **discarded unplayed**.

**★★ That is a strong statement about cost.** The game would rather drop a musical cue entirely than
play it late — because "late" means "at a moment when freezing the screen would be visible", and
there may never be a quiet moment before the cue stops being relevant.

#### 3D — effects DO run in gameplay, and they are the non-blocking half (AC4)

- **`TOPCTRL.S:388  jsr playback ;Play sounds`** — every frame, in the main loop, immediately before
  `zerosound` clears the table for the next one.
- **`TOPCTRL.S:519  jsr addsfx`**, and `addsound` at `TOPCTRL.S:1226/1522`.
- `ADDSOUND` appends to `soundtable`; `PLAYBACK` walks it and calls `makesound`, which is a
  self-modifying dispatch into the twenty `Do*` routines — **each of which is three parameters and a
  `jmp tone`** (P4.1's reading, confirmed: `DoPlateDown` is `ldy #70 / ldx #0 / lda #4 / jmp tone`).

**So the oracle runs two sound systems side by side in gameplay** — a per-frame effect queue that
does not block, and a song mechanism that stops the world. *§2H's first check: yes, there is a second
mechanism, and it serves a different object class.*

#### 3E — the id space (AC5)

**Gameplay uses the 16-name GAME set**, confirmed by use rather than by the table: `s_Danger`(3),
`s_Heroic`(2), `s_Accid`(1), `s_Timer`(13), `s_Heartbeat`(16) all appear in gameplay code.
`loadmusic2` is called at `MASTER.S:1365`. **The discriminator is which set is resident, not the id**
— P4.1's finding holds, and the overlap is real (`s_Vict`=7 in the game set, `s_Princess`=7 in the
title set).

#### 3F — ★★★ WHAT THE PORT WOULD KEEP IF ITS PLAYER DOES NOT BLOCK (AC6)

**Droppable — these exist ONLY to hide the stall.** Gates 6-12: kid static, shadow static, no
slicers, no MOBs, no lightning, no merge, no impact stars. **A FIRQ player freezes nothing, so there
is nothing to wait for.** Porting them would reproduce a workaround without the problem — inheritance,
not fidelity (§2I).

**★★ REAL INTENT, WHICH MUST SURVIVE SOMEWHERE:**

1. **`level = 0` → no music in the demo.** A design rule, unrelated to the stall.
2. **"Play only one song once kid has reached stairs."** Also a design rule.
3. **Cue priority.** `TOPCTRL.S:300-303`, at level init: `ldx SongCue / cpx #s_Danger / beq :1st /
   sta SongCue` — **everything else is cleared; `s_Danger` survives.** One slot, and one cue that
   outranks a reset.
4. **★★★ AND THE SHARP ONE: OTHER CODE WAITS ON `SongCue`.**
   - `TOPCTRL.S:1124` — `lda SongCue / bne ]rts ;wait for song to finish before putting up msg`
   - `AUTO.S:498-502` — on **level 13**, `;Vizier only: wait for music to finish` before `DoEngarde`

   **These are sequencing, not stalling.** In the oracle `SongCue` is non-zero from cue to
   completion, so "wait for the song" is expressible. **A non-blocking player that started the song
   and cleared the cue immediately would turn both waits into no-ops** — the death message would
   appear over the music and **the Vizier fight would start early.** So the port must keep
   `SongCue` as a *song-is-playing* flag even after deleting the mechanism that made it one.

**★ AND IT IS A §2I DECISION, WHICH IS JAY'S.** Removing the stall is **better play feel and a timing
divergence at once**: the oracle's gameplay genuinely pauses for the length of a song, and the port's
would not. **Reported, not chosen.**

### 4 — Verification (AC-by-AC)

- **AC1 `songcues` from the routine** — PASS (§3A), full gate chain and loop body quoted.
- **AC2 call sites, cued vs on-the-spot** — PASS (§3B): **cued and deferred**, six setters found.
- **AC3 `SongCount` and expiry** — PASS (§3C): a per-frame deadline; the cue is dropped unplayed.
- **AC4 gameplay effects** — PASS (§3D): `playback` every frame, plus `addsfx`/`addsound`.
- **AC5 gameplay id space** — PASS (§3E): the game set, discriminated by which set is loaded.
- **AC6 mechanism vs intent** — PASS (§3F): seven gates droppable, four intents named, one of them
  (the `SongCue` waits) a live hazard for a non-blocking player.
- **AC7 nothing built; `main`, Karateka, oracle source untouched** — PASS.
- **AC8 route accounting** — §6.

### 5 — Verdict-time evidence (v0.7 §11)

```
TOPCTRL.S:393   jsr songcues ;Play music        <- the main loop, after FrameAdv/playback
TOPCTRL.S:1388  songcues
  lda level / beq ]rts          ;no music in demo
  lda SongCount / bne :cont / lda #0 / sta SongCue   ;when SongCount reaches 0, forget it
  ...KidPosn static? / shadow / trobcount / nummob / lightning / mergetimer / impact stars...
  * Prepare for minimal animation
  lda SongCue / jsr minit
:loop jsr burn / jsr musickeys / jsr mplay / cmp #0 / bne :loop

TOPCTRL.S:388   jsr playback ;Play sounds       <- effects, every frame, non-blocking
TOPCTRL.S:519   jsr addsfx
TOPCTRL.S:301   cpx #s_Danger                   <- s_Danger survives a level init
TOPCTRL.S:1124  lda SongCue / bne ]rts ;wait for song to finish before putting up msg
AUTO.S:501      lda SongCue / bne ]rts          ;Vizier only: wait for music to finish (level 13)
```

**25.1:** N/A — no build; nothing was changed to build. **25.2/25.3:** N/A — recon.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** I proposed nothing in advance. **This report contains** the five answers and
the mechanism-vs-intent split. **What it does NOT contain, named rather than left to inference:** any
observation of `songcues` on a running machine (this is source-tier only); any measurement of how
long a gameplay song actually stalls; any change to the port; any decision about whether to keep the
stall. **No deviations** — the dispatch was recon and stayed recon.

### 7 — Uncertainty flags

- **★ THIS IS SOURCE-TIER, NOT TRACE-TIER.** §2 ranks the running machine above the source, and
  **nothing here was observed on the oracle.** The gate chain and the spin loop are read, not seen.
  **The single most valuable follow-up is to watch a gameplay song on the machine and measure how
  long the freeze lasts** — P4.9's `demo` entry reaches gameplay in ~131 s and `SongCue` at a known
  address would arm it.
- **`EditorDisk = 0`** in the three files that define it (`FRAMEADV.S`, `GAMEBG.S`, `GRAFIX.S`);
  `TOPCTRL.S` does not define it. **I did not confirm from a listing that `songcues`'s early `rts`
  is absent from the shipped binary** — and P4.9 just showed that a same-named flag can differ per
  file. *Assume nothing about that guard until it is read off `TOPCTRL.LST`.*
- **`SongCount`'s magnitude is unknown.** Only one setter was found (`SPECIALK.S:1333-1334`), and the
  other five setters may leave it stale. **How many frames a cue survives is not established.**
- **`musickeys` inside the spin loop is unread** — it may allow aborting the song, which would change
  the stall's worst case.
- **The port's non-blocking player is measured for the CUTSCENE songs.** Gameplay songs come from a
  different set and have not been captured, sized, or costed.

### 8 — Follow-up candidates

- **Observe it running** — the freeze's real duration, and whether `musickeys` can cut it short.
- Read `TOPCTRL.LST` for the `EditorDisk` guard.
- Establish `SongCount`'s values at the five unexamined setters.
- If the port drops the stall: `SongCue` must still mean *a song is playing*, or the death message
  and the level-13 Vizier fight change timing (§3F.4).
- Unchanged: the timbre ruling and capture-vs-interpret (Jay's); the drift figure re-measured on full
  songs; `MUSIC.SET*`; P4.9's unverified state-restore; gameplay's colour mode.

### 9 — User interaction during task

None during execution. The dispatch carries Jay's hypothesis, which §1 answers directly: **right that
a song stalls gameplay, wrong that gameplay therefore uses only effects.**

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-18-a-subsystem-that-exists-to-hide-a-limitation.md`

### 11 — Commit

`e9b52c0`  (pushed to origin/wip before this report)
