## Form B Report — PA.12 — sound feasibility budget + honest capability self-assessment
**Class:** recon.  wip.  Prod N/A — no prod binary exists yet (feasibility arc); no tracked file altered outside `poc/`.

### 0 — Receipt / status (C-35 stamp)
t0=2026-07-25T22:03:15Z (HEAD `5d68722`, wip). Working tree: no tracked file modified; untracked
`.vscode/`, `POP-idioms-coco3-markers.md`, `docs/ground-truth/*.pdf` (the latter local-reference-only per
Jay's standing ruling — never committed).

**Gates:** oracle `.hdv` md5 `c4f0b13e49b77dd0fbc5063e27e53a24` — **PASS, untouched**. Vendored source last
touched `ba6154e` (tree pinned at adamgreen `ec78dbf`) — **PASS**.

---

### 1 — Summary

**Q1 — sound is affordable, and by a wider margin than expected, because of an architectural discovery in
POP itself: on the Apple, music and gameplay never overlap.** `songcues` (TOPCTRL.S:1388) refuses to play a
song until the Kid *and* the Shadow are `static?`, `trobcount`/`nummob`/`lightning`/impact-stars are all
zero — the source comment says it outright: *"it wouldn't look good to freeze."* Music **freezes the game**.
So the original's music budget and its gameplay budget are **disjoint**, and the port inherits that for free.

What *does* run during action is 20 triggered effects, and they are tiny: a Footstep is **909 cy (0.51%)** of
a 178,968-cy game step, a Sword Clash **7,150 cy (4.00%)** — counted from `tone` (GRAFIX.S:1340).

Against that, I counted a **real** CoCo3 FIRQ DAC player — Run Dino Run's 3-voice mixer — at **85 cycles per
interrupt**, giving **36.96%** of a 1.79 MHz CPU at 7.8 kHz. That independently **corroborates** the
project's ~35% headline rather than contradicting it (the recurring project lesson cut the other way this
time — worth saying plainly). A minimum 1-voice PCM ISR is **51 cy → 22.17%**.

**Every model fits.** Against PA.11's p90 idiomatic frame (0.46×):

| model | ISR | load | p90 total | verdict |
|---|---|---|---|---|
| 3-voice music @7.8 kHz (exceeds the original) | 85 cy | 0.370× | **0.830×** | FITS (+17.0%) |
| 3-voice music @3.9 kHz | 85 cy | 0.185× | **0.645×** | FITS (+35.5%) |
| 1-voice PCM effects @7.8 kHz (matches the original) | 51 cy | 0.222× | **0.682×** | FITS (+31.8%) |
| 1-voice PCM @3.9 kHz | 51 cy | 0.111× | **0.571×** | FITS (+42.9%) |

Note the asymmetry the table hides: to *match* the original we need only the effects row, and music plays
into a **frozen** frame where the whole CPU is free — so the honest match-the-original figure is closer to
**0.46× + ~0.22× worst-case-effect-overlap**, and continuous-music-during-action is an *upgrade* we can
afford but the original never had. **On the literal-`k` path the p90 frame is already 1.21× (over) before a
single sample plays** — sound does not change PA.11's verdict, it inherits it.

**The one hard constraint found: audio must be silenced across disk I/O, on every live branch.** Not a
workaround — forced. See §3.4.

**Q2 — the honest self-assessment is in §3.5, per-capability.** Summary: **confident** on the FIRQ/DAC
plumbing and on porting POP's effects (I have read a complete working example and POP's `tone` is a clean
1:1 map). **Not confident, and this is the load-bearing gap: POP's music engine does not exist in the source
of record.** `minit`/`mplay` are `ds 3` JMP slots (EQ.S:193-194) patched at load time by a binary read off
**raw disk track 34** (`loadmusic1`, MASTER.S:254). No engine, no song data, no format — the port cannot
transliterate music; it must re-author it. And **I cannot certify that any of it sounds right** — audio
correctness is a perceptual gate that is Jay's alone, exactly like 25.3.

---

### 2 — Files modified
- `poc/sound-budget/isr_count.py` — **new**. The cycle-count instrument (commit `8bdb61d`, explicit-path staged).
- `reports/20260725-220315-pa-12-sound-feasibility.md` — this report.

No engine/HAL/content file touched. No authored authoritative doc edited (§2D respected — findings surface
here for the Orchestrator to fold).

---

### 3 — Reasoning

#### 3.1 — What POP actually needs (authority: **source**, tier 3)

`SOUNDNAMES.S` is an exact inventory: **20 sound effects** (0–19: PlateDown/Up, GateDown, SpecialKey1/2,
Splat, MirrorCrack, LooseCrash, GotKey, Footstep, RaisingExit, Raising/LoweringGate, SmackWall, Impaled,
GateSlam, FlashMsg, SwordClash1/2, JawsClash), **16 game music cues**, **6 title cues**.

The effect path (SOUND.S): `ADDSOUND` appends a sound # to `soundtable` during the frame (~30 call sites
across MOVER/COLL/CTRL/MISC/AUTO); `PLAYBACK` runs once per frame and plays the queue **synchronously**,
dispatching through a `lookup` table via self-modifying `jmp $ffff`. Each effect is a **blocking** delay
loop toggling `$C030`. That is the only thing a 1-bit Apple speaker permits.

**This is the finding that sets the budget.** Because effects block, POP's own sound cost is already inside
PA.5's measured frame — and it is small (§1 table). Because *music* blocks for seconds, POP hides it behind
a freeze rather than paying for it. Verified in `songcues`:

```
 lda KidPosn / jsr static?  / bne ]rts      ; Kid must be static
 lda ShadPosn / jsr static? / bne ]rts      ; Shadow must be static
 lda trobcount / bne ]rts   ;(slicers or other fast-moving objects
                            ; that it wouldn't look good to freeze)
 lda nummob    / bne ]rts
 lda lightning / bne ]rts
* Prepare for minimal animation
:loop jsr burn / jsr musickeys / jsr mplay / cmp #0 / bne :loop
```

`MUSICKEYS` is documented *"Call while music is playing"* — a keypoll living **inside** the blocking song
loop so ESC still pauses. Unambiguous: the song loop owns the CPU until the song ends.

#### 3.2 — The reference player, counted (authority: **source**, corroborated against **ground truth**)

Per the dispatch's standing rule, this section exists because real code was read. Source of record:
`pfiscarelli/Run-Dino-Run` @ master, `src/dinorun.asm`, label `note` — *"Multi-voice Note Mixer (located in
DP for speed)"*. Three phase accumulators (16-bit accumulate-and-wrap), mixed by `ADDA`/`RORA`, out to the
6-bit DAC at `$FF20`. Full per-instruction table in `poc/sound-budget/isr_count.py`; the total:

```
FIRQ entry 10 (stacks CC+PC only, E=0) + JMP <note 3 ($FEF4 secondary vector = $0E,<lo)
+ body 66 + RTI 6 (E=0 -> 6 cyc, not 15)                                    = 85 cycles
```

The three cycle counts most likely to be got wrong, stated explicitly: **FIRQ entry is 10** (not 19 — FIRQ
stacks only CC and PC); **RTI is 6** (not 15, because E=0); **`LDA ,X+` is 6** (4 base + 2 for the
postincrement postbyte) in the PCM variant.

I verified every GIME register against ground truth (`docs/ground-truth/SockmasterGime.md`) rather than
trusting the reference's comments — `$FF91` bit 5 TINS=1 → 279.365 ns tick, and Sockmaster notes that clock
is *"useful for interrupt driven sound routines"*, exactly this use; bit 0 TR=0 → `$FFA0-$FFA7`, which is
the MMU bank POP uses (PA.8), so **no conflict**; `$FF93` bit 5 TMR enables the timer FIRQ; `$FF94/95` is
the 12-bit reload.

**One correction the ground truth forced on the reference's own arithmetic:** Sockmaster records that
neither GIME revision honours the written value exactly — *"nnn+2 for 1986 GIME and nnn+1 for 1987 GIME."*
So `ldd #460` yields **3,579,545/462 = 7,748 Hz** (1986) rather than the 7,782 Hz the divisor implies, and
the source comment's "8Khz" is a round number. Effect on the budget: 36.96% → **36.80%**. Immaterial to the
verdict; recorded because I am claiming a counted figure, not an approximate one.

#### 3.3 — Why the headline held

The dispatch anticipated the README's 35% being a claim to be checked against code, and it was right to —
but this time the claim survives. My independent count lands at 36.8–37.0%. Reporting that it *matched* is
as much the job as catching a miss would have been; the PA.6 lesson (a header estimate 5.4× understated) is
a reason to measure, not a reason to expect a discrepancy.

#### 3.4 — Disk I/O: the one hard constraint (authority: **Karateka `fdc-read-primitive.md`** + datasheet)

I checked this against Karateka's existing FDC design reference rather than my own arithmetic, and the
reference is more restrictive than my first pass. Its branch (a) — single-density, comfortable margin — is
**already ruled out** there by capacity (~87.5 KB SD < ~128 KB content) and the DD-only DECB bootstrap. The
live branches are (b) DD+DRQ→HALT @0.89 MHz and (c) DD+polled @1.79 MHz (itself *contested*). Both are
fatal to concurrent audio:

| branch | polled slack | ISR A (85) | ISR B (51) |
|---|---|---|---|
| (b) DD+HALT @0.89 MHz | (32 − 27.0) µs = **4.5 cy** | LOST DATA | LOST DATA |
| (c) DD polled @1.79 MHz | (32 − 13.5) µs = **33.1 cy** | LOST DATA | LOST DATA |

Branch (b) is worse than the table shows, and this is the part worth flagging: DRQ is wired to the **6809
HALT line**. A halted 6809 executes no instructions **and takes no interrupts** — so the audio FIRQ is
*suspended*, not merely late. A 256-byte sector = 8.2 ms = **64 missed samples** at 7.8 kHz: an audible
dropout, per sector, unavoidably.

**Conclusion: mask the audio FIRQ (or stop the timer) across the sector transfer.** This is forced on both
branches — and it costs nothing behaviourally, because it is what the original does anyway: POP *loads*
music from disk (`loadmusic1` → track 34) and *then* plays it. Sound and disk were never concurrent.

#### 3.5 — Q2: per-capability honest self-assessment

Rated against what I actually read this dispatch. Calibrated candor, not a blanket yes.

**CONFIDENT (3)**

1. **GIME timer FIRQ + DAC plumbing.** I have read a complete, working init and ISR and verified every
   register against Sockmaster independently: `$FF90=$D8`, `$FF91` TINS/TR, `$FF93` TMR, `$FF94/95` reload,
   the `$FEF4` secondary vector patched as `$0E,<lo` (JMP direct), `andcc #$BF` to unmask. ~10 instructions.
   I can write this and defend each value. *Residual:* the 1986/1987 timer-value offset means the exact
   sample rate is silicon-dependent — a tuning detail, not a risk.
2. **Porting POP's 20 effects.** POP's effects are not samples; they are `tone(pitch_lo, pitch_hi, duration)`
   calls (plus `WHOOP`). That is a **parameterised square-wave generator**, which maps to a DAC phase
   accumulator essentially 1:1 — the same accumulator the reference already uses, one voice, driven by the
   same three parameters. This is the single most reassuring thing I found: the effects are not a
   reverse-engineering problem, they are a translation with all inputs present in the source.
3. **The `ADDSOUND`/`PLAYBACK` queue integration.** Trivial (`soundtable`, `maxsfx`, a lookup dispatch), and
   the port makes it *simpler*: `PLAYBACK` stops being "play, blocking" and becomes "hand to the ISR and
   return." Asynchronous audio is strictly easier here than what the original had to do.

**PARTIAL (3)**

4. **DAC output-enable path.** I know `$FF20` bits 7-2 are the DAC. I do **not** know from the code I read
   how the audio MUX is enabled — the reference does `lda $FF23` at both its "turn off music" and
   "re-enable sound" sites, which is a *read* of PIA1 CRB, not a write. That is either a bug it gets away
   with because the ROM left the MUX enabled, or something I am misreading. Either way I would be guessing.
   **Resolvable from the CoCo Tech Ref / Service Manual (both in `docs/ground-truth/`) — a 30-minute
   lookup, not a research project.**
5. **Writing a multi-voice mixer.** I understand the design (phase accumulator + frequency step, take the
   high byte, sum with `RORA` halving to avoid overflow) and can reproduce and re-cost it. What I have not
   done is build the **note→frequency table** and pattern format for a *specific* score. Mechanically
   straightforward; unproven by me.
6. **Silencing audio across disk I/O.** The mechanism is clear (§3.4) and I am confident in the *rule*. But
   it integrates with a disk primitive that **does not exist yet** — Karateka's `HAL_file_init` is a no-op
   stub, and branch (b)-vs-(c) is undecided. I cannot integrate against unbuilt, undecided code.

**NOT CONFIDENT (2) — these are the real gaps**

7. **POP's music.** This is the headline gap and it is structural, not a skill issue. `minit`/`mplay` are
   **`ds 3`** — three reserved bytes each (EQ.S:193-194), patched at load time with a JMP into a music
   binary read from **raw disk track 34** (`loadmusic1`: `lda #34 / sta track / jsr rw18 / db RdSeq,$4e`).
   **The engine and all 22 songs are absent from the vendored source of record.** Consequences I want stated
   before anyone plans against this: there is nothing to transliterate; the format is undocumented and would
   have to be reverse-engineered off the oracle image (a real recon arc of its own, not a sub-task); and
   until that is done I cannot estimate the music work honestly. **The CPU budget in §1 says music is
   *affordable*. It does not say I know how to reproduce POP's music, and I do not.**
8. **Certifying that it sounds correct.** I can verify cycle counts, register writes, interrupt rate, and I
   could dump the DAC write stream from a MAME trace and check a waveform's period matches the intended
   frequency numerically. I **cannot** hear it, and no numeric check answers "does this sound like Prince of
   Persia." This is a perceptual gate and it is **Jay's alone** — the exact analogue of the 25.3 visual
   gate, and I will not self-certify it. Any plan should budget Jay-in-the-loop audio review as a standing
   gate, not a one-off sign-off.

**One-line answer to the dispatch's Q2 as posed** — *can Clyde implement POP's sound as POP needs it?*
**Effects: yes, with justified confidence.** **Music: not yet — the engine isn't in the source, and I'd be
bluffing to say otherwise.** **Verification that it sounds right: never mine to certify.**

---

### 4 — Verification (AC-by-AC)

- **AC1 — real reference code read, ISR counted from instructions not the headline.** MET. `dinorun.asm`
  fetched (HTTP 200, 133,261 B); ISR transcribed instruction-by-instruction into
  `poc/sound-budget/isr_count.py` with per-instruction addressing mode and cycle count; total **85 cy**.
  §10 hard-stop #3 (no readable source → do not fabricate) did **not** fire — source was reachable and read.
- **AC2 — both budget models computed.** MET. §1 table: continuous 3-voice worst case **36.96%**; light
  triggered effects **22.17%** (1-voice) — plus the 3.9 kHz variants of each.
- **AC3 — p90 frame re-checked against PA.11.** MET. p90 idiomatic 0.46× (confirmed verbatim from
  `reports/20260725-173302-pa-11-k-measurement.md:9,45`) + sound = **0.571× – 0.830×, all FIT**. Literal
  p90 was already 1.21× (over) pre-sound — stated so the fit is not misread as rescuing that path.
- **AC4 — FDC / double-speed interaction addressed.** MET. §3.4, checked against Karateka's
  `fdc-read-primitive.md` rather than my own arithmetic alone. Both live branches require the audio FIRQ to
  be masked across the transfer; branch (b)'s DRQ→HALT *suspends* the CPU (64 missed samples/sector).
- **AC5 — per-capability honest self-assessment, rated with reasoning.** MET. §3.5 — 8 capabilities rated
  3 confident / 3 partial / 2 not-confident, each with the evidence it rests on and the specific gap.
  The pass condition (no blanket "yes I can do it all") is met by items 7 and 8, which are refusals to
  claim capability I have not demonstrated.

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim, `python poc/sound-budget/isr_count.py`, abridged to totals):**
```
  TOTAL per interrupt                       85     [A. Run Dino Run 3-voice mixer]
  TOTAL per interrupt                       51     [B. 1-voice PCM sample player]
  rate = 3,579,545 / 460 = 7,781.6 Hz   (source comment says '8Khz')
  A. 3-voice music @ 7.8 kHz   7781.6 Hz x  85 cy =  661,438 cy/s =  36.96% of 1.79 MHz
  B. 1-voice PCM  @ 7.8 kHz    7781.6 Hz x  51 cy =  396,863 cy/s =  22.17% of 1.79 MHz
  p90 idiomatic 0.46x + A 3-voice @7.8k  0.370x = 0.830x  -> FITS  (margin +17.0%)
  p90 idiomatic 0.46x + B 1-voice @7.8k  0.222x = 0.682x  -> FITS  (margin +31.8%)
  Footstep    (35,0,3)     =     909 cy blocking =  0.51% of a 178,968-cy game step ( 0.89 ms)
  SwordClash  (15,0,50)    =   7,150 cy blocking =  4.00% of a 178,968-cy game step ( 6.99 ms)
  (b) DD + DRQ->HALT @ 0.89 MHz
    Blackout = 256 bytes x 32 us = 8.2 ms per sector = 64 missed samples -> audible dropout
      ISR A 3-voice       85 cy vs   4.5 cy slack -> LOST DATA
  (c) DD + polled     @ 1.79 MHz
      ISR B 1-voice PCM   51 cy vs  33.1 cy slack -> LOST DATA
```

**25.2 bundled-artifact grep:** N/A — recon dispatch, no build, no sibling-import artifact.

**25.3 operator-runtime-smoke:** **N/A for this dispatch** (no runtime change to observe). Flagged forward:
**audio will need its own standing Jay gate**, per §3.5 item 8 — it cannot ride on the visual gate.

---

### 6 — Reactive deviations

1. **Reference project substituted.** The dispatch named Simon Jonassen's FIRQ DAC player. The reachable,
   readable CoCo3 FIRQ-DAC source I found and counted is **Run Dino Run** (`pfiscarelli/Run-Dino-Run`,
   `src/dinorun.asm`) — a GIME-timer FIRQ 3-voice DAC mixer, i.e. the same technique and the same ~35%
   headline. I counted what I could read rather than fabricating from a project I could not open. Surfaced
   rather than absorbed, in case the Orchestrator intended a specific different file.
2. **Scope widened by one finding.** §3.1 (music freezes the game) was not asked for; it emerged from
   reading `songcues` to answer "is music concurrent with gameplay," and it materially changes the budget
   framing, so it is reported rather than dropped.
3. **Ground-truth cross-check added.** I verified the GIME registers and the timer offset against
   `SockmasterGime.md` beyond what the dispatch required, because §3.2's numbers otherwise rested on a
   third-party project's comments — tier 5 in the hierarchy.

---

### 7 — Uncertainty flags

1. **The `k=0.35` precondition carries through.** Every "FITS" here sits on PA.11's idiomatic p90 (0.46×).
   On the literal path p90 is 1.21× **before** sound. Sound does not rescue that path and this report should
   never be quoted as if it does.
2. **DAC output-enable (`$FF23`) unresolved** — §3.5 item 4. I did not chase it into the Tech Ref this
   dispatch; it is a lookup, but it is currently a guess and I have not treated it as anything else.
3. **POP's music format is entirely unknown** — §3.5 item 7. Track 34, raw `rw18` read, no engine in-source.
   Any music schedule is currently unestimable, not merely uncertain.
4. **No execution trace taken.** Every figure here is *counted* from source (tier 3), not observed running
   (tier 2). The effect costs, the ISR cost, and the interrupt rate are all static counts. Consistent with
   §2's "source is the trusted default," but a trace would be the tiebreaker if any of it is contested —
   and the 1986/1987 timer offset in particular is exactly the kind of thing only a trace settles.
5. **The FDC branch is undecided upstream** (b vs c, and (c) is contested), so the disk/audio interaction is
   a rule I am confident in attached to a mechanism nobody has built yet.
6. **`WHOOP` not costed.** I costed `tone`, which covers the effects I sampled; `WHOOP` (a separate
   descending-pitch loop) was read but not counted. Cheap by inspection, unmeasured in fact.

---

### 8 — Follow-up candidates

1. **Recon POP's music binary on the oracle image (track 34).** Prerequisite to any music estimate; likely a
   full arc, not a sub-task. This is the single highest-value unblock for sound.
2. **Resolve the `$FF23` DAC/MUX enable** from the CoCo Tech Ref + Service Manual already in
   `docs/ground-truth/`. Small, closes §3.5 item 4.
3. **Establish an audio verification gate with Jay** — the analogue of 25.3. Should be agreed *before* audio
   work starts, not after (§3.5 item 8).
4. **Prototype one POP effect end-to-end** (Footstep: `tone(35,0,3)` → DAC square wave) to convert §3.5
   item 2's confidence from reasoned to demonstrated.
5. Standing, still unresolved: the **idioms-file authorship ruling** (now ten deferrals; this dispatch adds
   GIME-timer-FIRQ + DAC idioms to the queue — six techniques waiting), disposition of
   `POP-idioms-coco3-markers.md`, POP-level `.gitattributes`, `.vscode/`.

---

### 9 — User interaction during task
**None.** No questions asked; no clarifications received.

---

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-07-25-corroboration-is-a-reportable-result.md` — *"When independent measurement
**confirms** a third-party headline claim, report the corroboration as explicitly as a discrepancy would be
reported — otherwise a standing 'verify claims against code' lesson silently degrades into an expectation
that claims are wrong."* Captured as a fresh single-instance row (`initiator: clyde`), schema matched
against `seeds/karateka/live/2026-06-13-asset-readiness-gates-port-scope.md`; no existing pool entry read or
edited. Arose from §3.3: PA.6 found `gfx.s`'s header estimate 5.4× understated and flipped a verdict, so the
prior entering PA.12 was that the 35% headline would also fail — it didn't, and only the catches were
getting written down.

---

### 11 — Commit
`8bdb61d` — `PA.12: FIRQ DAC ISR cycle count + POP sound budget instrument`
(this report committed and pushed to `origin/wip` before reporting)
