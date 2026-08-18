## Form B Report — P4.14a — both writers are the CHARACTER peel, and it is silent for the whole intro

**Class:** recon.  wip.  Prod unchanged — no `src/`, no `build.bat`, no shipping disk.
Completes P4.14's AC1/AC2, which P4.14 substituted away and its own §6 said cost a measurement.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-18 13:45 (HEAD `04bbc6b`, wip). Jay: **"do the 3a52/3a60 check"**.

### 1 — Summary

**Both writers are the character peel. The flames are not involved at all**, and it did not need a
run to establish — `blit_save` has exactly **two callers in the entire tree** and both are in
`char_draw.s`.

**And the "when" answer is stronger than the dispatch hoped: the peel region is written ZERO times
for the first 4,680 frames — the whole of the intro's beats.** All five intro `play_song` sites live
there. So during those beats **`$6C00..$77FF` — 3,072 B contiguous — is free, and 2,590 B fits with
482 B spare.**

**The cutscene is the exception**, and its song sites sit inside the busy stretch.

### 2 — Files modified

- `harness/tools/region_write_probe.lua` — `P_EVERY`: per-bucket deltas instead of a running total.

### 3 — Reasoning

#### 3A — the attribution, from the source (AC1)

```
src/engine/char_draw.s:729    jsr blit_save_full     ; capture body-over-room, not room
src/engine/char_draw.s:1051   jsr blit_save
```

**Those are the only two calls anywhere in `src/`.** `blit_save`'s entry takes `Y = peel buffer` from
the caller, and both callers pass `ch_peel`. **So `$3A52` (`bs_pair`'s `std ,y++`, 128,168 writes) and
`$3A60` (`bs_odd`'s trailing `sta ,y+`, 5,634) are both the character peel writing into the peel
buffers.** The flames never call it.

**★ AND THE ADDRESSES CONFIRM IT EXACTLY**, which is the part worth trusting:

```
VIZ_PEEL      equ 48*10      ; 480 B    VIZ_PEEL_BASE  equ $6C00
PRI_PEEL      equ 43*8       ; 344 B    PRI_PEEL_BASE  equ $6C00+VIZ_PEEL*2
  viz  2 slots x 480 = 960 B   $6C00..$6FBF
  pri  2 slots x 344 = 688 B   $6FC0..$726F
```

**P4.14's sweep found the untouched region starting at `$7268`.** The peel ends at `$726F`. *The
measurement and the source agree to within the eight bytes the last row's clipping never reached.*

★ **One stale comment found in passing:** `char_draw.s:159` says the princess peel runs
`$6FC0..$727F`. **It is `$726F` — off by 16.** Harmless, and it is the second map/comment-versus-reality
item this arc (`pop.link`'s stack range is still the first, still unreconciled).

#### 3B — WHEN it is written (AC2), in 2-second buckets

```
frame  120..4680   +0 every bucket        <- the ENTIRE intro. 39 consecutive quiet buckets.
frame  4800        +612                   <- the scene's first draw
frame  4920..5400  +0                     <- 10 s quiet
frame  5520..5640  +5810, +9802
frame  5760..5880  +0                     <- 4 s quiet
frame  6000..6240  +8054, +18832, +12692
frame  6360..6600  +0                     <- 6 s quiet
frame  6720..7440  busy
frame  7560..8280  +0                     <- the cutscene has ended
```

**★★★ THE INTRO'S BEATS ARE ENTIRELY IN THE QUIET.** Nothing writes the peel before frame 4,680,
because the intro's beats are captions and pictures — **there are no characters, so there is no peel.**
That is structural, not incidental.

**★★ THE CUTSCENE IS DIFFERENT AND I AM NOT CLAIMING ITS GAPS.** There are real quiet stretches inside
it — 10 s, 4 s, 6 s — and they are the right *shape* for holds. **But I did not establish the beat
boundaries, so attributing any specific gap to a specific song beat would be exactly the inference
this arc keeps getting caught on.** The cutscene's song sites are `s_Princess`, `s_Vizier`,
`s_Buildup`, `s_Magic`, `s_StTimer` — five of the six — and **whether the peel is quiet during each is
unmeasured.**

#### 3C — what this changes

| | free during | size | fits 2,590 B |
|---|---|---|---|
| `$7268..$77FF` | always | 1,432 B | no |
| **`$6C00..$77FF`** | **the intro's beats** | **3,072 B** | **yes, 482 B spare** |
| `$6C00..$77FF` | the cutscene's beats | 3,072 B | **unknown — §3B** |

**★ AND IT IS A CONDITION, NOT A PROPERTY.** If this route is taken, "no character peel is live" must
be **asserted**, not assumed — P3.105's `BEAT_PATCH = 0` is the precedent, safe only while a condition
holds and now enforced by a build-time check. **For the intro the condition is structural (the scene
is not loaded); for the cutscene it is not established at all.**

### 4 — Verification

- **AC1 (P4.14) writers attributed** — **PASS.** Both the character peel; two callers, both named;
  addresses confirmed against the sweep boundary to 8 bytes.
- **AC2 (P4.14) free when it matters** — **PASS for the intro's five beats** (39 consecutive quiet
  buckets), **NOT ESTABLISHED for the cutscene's.**
- **AC3 condition asserted** — **NOT DONE.** No wiring was attempted; the assert belongs with it.
- Nothing built. `main`, Karateka, oracle source untouched.

### 5 — Verdict-time evidence (v0.7 §11)

Verbatim in §3B. Callers from `src/engine/char_draw.s:729,1051`; extents from `char_draw.s:130-132,
161-162`; the `$7268` boundary from P4.14's sweep.

**25.1/25.2/25.3:** N/A — recon; nothing built, no gate.

### 6 — Reactive deviations and route accounting

**This report contains the check Jay asked for and the "when" measurement P4.14 owed.** It does not
contain any wiring, any assert, or any cutscene-beat attribution — **and the last of those is the one
that decides whether this route works for all six songs or only five.**

### 7 — Uncertainty flags

- **The cutscene's quiet stretches are unattributed** (§3B). Without the beat boundaries, "there are
  gaps" is not "the gaps are the song beats."
- **One run, 128 KB, one route.** An abort mid-intro would change what is drawn and when.
- **`blit_save_full` at `char_draw.s:729` was not separately traced** — it `lbra`s into `blit_save`,
  so its writes appear at the same PCs; both are still the character peel either way.
- **The 482 B spare is against today's `s_Buildup`** and moves with any packer change.

### 8 — Follow-up candidates

- **Measure the cutscene's song beats specifically** — the boundaries exist (P4.7's per-song capture
  armed on the oracle's calls; the port's beats are in the scene table).
- If the route is taken: assert "no peel live" at run time, and decide what happens if it ever is.
- Reconcile `char_draw.s:159`'s `$727F` and `pop.link`'s stack comment.

### 9 — User interaction during task

Jay: **"do the 3a52/3a60 check"** — done (§3A), and the "when" question it unlocks answered as far as
the intro (§3B).

### 10 — Candidate(s) captured this task

None. The lesson here is the one already captured as [[unwritten-is-not-unused]]'s sibling — a second
row would duplicate it.

### 11 — Commit

See below — pushed to origin/wip before this report.
