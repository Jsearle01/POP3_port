## Form B Report — P4.41–P4.45 — *"why only there"*, and the answer that turned out not to be it

**Class:** recon (one change, made and reverted).  wip.  **Prod restored — `gen_msys_tables.py`'s
`ENV_OVERRIDE` is empty and `msys_mv5` is the oracle's bytes again.** Karateka untouched; `main` untouched
(`34e93e0`).

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-20 20:15 (HEAD `d283673`, wip). Tree clean apart from the modified
`dist/mame-cfg/rgb/coco3.cfg` carried since P4.19 and the pre-existing untracked files.

### 1 — Summary

**Jay:** *"here's what i don't understand. the sound seems corect everywhere except the princess song, why
only there"*

| | |
|---|---|
| **★★★ that question invalidated my method** | ten of eleven songs are right, so the PLAYER is right — and I had spent seven measurements testing the player (§3A) |
| **what is unique to `s_Princess`** | **envelope 5** — the only song using it, and the only envelope in use that holds a HIGH value (§3B) |
| **measured** | port **21.3 µs** mean pulse width vs oracle **15.7** on the same song; port **89%** at maximum |
| **the change** | envelope 5's sustain dropped one quantisation step — **21.3 → 16.4 µs**, within 4% of the oracle |
| **★★ Jay's verdict** | ***"doesnt sound any different"*** |
| **so** | **amplitude is not the defect.** Reverted (§3D) |
| **also found** | a real, documented-but-unimplemented divergence: **the port does not share `VTBL` between voices** (§3E) |
| **suites** | **ALL PASS, 128 KB**, before and after |
| **the fuzziness** | **still unexplained after ten measurements** |

### 2 — Files modified

- `harness/tools/gen_msys_tables.py` — `ENV_OVERRIDE` added, used, and emptied. **Net: an empty dict and
  the measurement that says the lever does not move.**
- `harness/tools/oracle_width_by_song.lua`, `amp_chain.lua` — NEW (P4.42/P4.43).

### 3 — Reasoning

#### 3A — ★★★ THE QUESTION WAS WORTH MORE THAN SEVEN MEASUREMENTS

**If ten of eleven songs are right, the player is right.** An engine defect hits all thirteen equally.
P4.36–P4.40 tested the blitter, interrupt masking, timer quantisation, pitch stability, duty, spectrum and
the silence ratio — **all properties of the renderer, which Jay's observation had already exonerated.** They
all came back clean, correctly.

★ *I had the elimination available in one sentence and spent an arc on instruments instead.*

#### 3B — what is actually unique to `s_Princess`

`msys_decode.py --all`, every song's envelope set:

```
s_Presents [3,4]  s_Byline [3,4]  s_Title [4]     s_Prolog [0,3,4]  s_Sumup [0,1,3,4]
s_Squeek [4]      s_Vizier [0,4]  s_Buildup [0,3] s_Magic [1,3]     s_StTimer [0]
s_Princess [3,5]   <-- the ONLY song that uses envelope 5
```

**And envelope 5 is structurally unlike every other one in use:**

| envelope | pattern | what `$FF` ("hold the last amplitude") holds |
|---|---|---|
| 0, 1, 3, 4 | `… 01 00 FF` | **silence** |
| **5** | **`01 0B 0D FF`** | **`$0D` — 13 of a maximum 14** |

So it sustains near maximum where every other song fades to nothing — **and a defect at the top of the
amplitude range is inaudible in ten songs and audible in one.** That was a complete, coherent theory.

#### 3C — the measurements it rested on, and the two errors in them

| `s_Princess` | oracle | port |
|---|---|---|
| mean pulse width | **15.7 µs** | **21.3 µs (+36%)** |
| the oracle's own songs | 11.2 … 23.6 | — |

**★★ ERROR ONE, CORRECTED IN FLIGHT (P4.42→P4.43).** I first reported the port as *"3.4× compressed"* against
an oracle max of 76.3 µs. **My split threshold was 100 µs when P4.4 had already established the pulse
population as 7.8–22.5.** At 30 µs, `s_Vizier` lost 438 of 601 samples and its mean fell 51.5 → 23.6. **The
fourth threshold in this arc written before the scale it thresholds was known** (§3F).

**★ ERROR TWO, WITHDRAWN (P4.38).** *"The duty matches — 21.3 vs 21.2"* compared the port's `s_Princess`
against an oracle figure drawn from a window spanning **several songs**. Per song the oracle is **15.7**. A
coincidence read as confirmation, and it sent the search past the answer.

**★★★ AND THE CHAIN ITSELF IS FAITHFUL.** `VS_AMP` is 3 for 384 of 439 ticks; envelope 5 holds `$0D` = 13;
`s_Princess` issues voice command `01` = `4A 4A` = LSR/LSR = ÷4; 13 ÷ 4 = 3. The decoder agrees and
`s_Magic` issues the same command. `scale_widths` clamps at 255 and never approaches it. **Nothing is
miscomputed** — the port simply spends more *time* at the held value.

#### 3D — ★★ THE CHANGE, AND THE VERDICT THAT MATTERS MORE THAN IT

The transform is `>> 2`, so it quantises hard — 12–15 → 3, 8–11 → 2. **Exactly one step was available below
the present value, and it is a 33% reduction against a 36% excess.**

```
oracle   msys_mv5  $01,$0B,$0D,$FF   -> amp 0, 2, 3, hold 3
tried    msys_mv5  $01,$0B,$FF       -> amp 0, 2,    hold 2
```

**Measured: 21.3 → 16.4 µs mean, within 4% of the oracle's 15.7; pulses at maximum 3231 → 18.**

**Jay: *"doesnt sound any different."***

**★★★ THAT IS THE MOST VALUABLE RESULT IN THE ARC.** The change was real on the bus and null in the ear, so
**amplitude is not the defect** — the one elimination here made by the authority (§2.1) rather than by an
instrument of mine, and it settles what ten measurements could not.

**Reverted**, because a §2I divergence has to buy something and this bought nothing. `ENV_OVERRIDE` stays as
an **empty dict with the measurement above it**: the mechanism is two lines, and the fact that this lever was
pulled and did not move should not have to be re-derived. Restoration verified — the width census returns
`8.4/14.0/16.8/22.3` at `154/54/196/3231`, identical to the pre-change run.

#### 3E — ★★ A REAL DIVERGENCE, FOUND WHILE READING FOR SOMETHING ELSE

`msys_player.s`'s own header, on the two voices:

> *"`MPLAY` toggles `R+21` and jumps to `MMPLAY` on alternate calls — the two voices TIME-SHARE one speaker a
> tick at a time. **They share `VTBL`.** They never sound together."*

**The port does not share `VTBL`.** `VS_VTBL` is an offset *inside each voice's struct*; `msys_v1` and
`msys_v2` each carry their own five widths. On the oracle, voice 2 writing the shared table leaves voice 1's
following segments using voice 2's widths until voice 1 rewrites them.

**★ And the difference is maximised by exactly the song under complaint.** Of the four two-voice songs,
`s_Title` has 21 second-voice notes, `s_Prolog` 13, `s_Vizier` 8 — **and `s_Princess` has ONE.** With many
notes both voices constantly rewrite the shared table and sharing converges with not-sharing; with one note
held against a ten-note melody they diverge for as long as it lasts.

**★★ STATED WITH ITS OWN COUNTER-EVIDENCE: the predicted direction is WRONG.** Sharing would make the
*oracle's* voices contaminate each other and the port's cleaner — the opposite of what Jay hears. So it may
be a dead end. It is recorded because it is a genuine, documented-but-unimplemented behaviour specific to
this song, not because it is likely.

★ *The voice-end path was checked and is correct: `clr msys_two` stops the alternation when voice 2's stream
ends, so voice 1 gets every tick thereafter [msys_player.s].*

#### 3F — §2H's three checks

1. **A second mechanism?** ★ The arc's whole content. Envelope 5 was real, unique, and **not the cause** —
   the third mechanism this session that was true and not governing.
2. **The calling routine.** `VS_AMP`'s value comes from `voice_apply`, whose selector comes from the song's
   own voice command — so the "instrument" is a property of the DATA, not of the code, which is what made
   the per-song enumeration the right instrument.
3. **Prior-report grep** (`envelope|VTBL|voice|amplitude`): P4.3, P4.5, P4.17–P4.19, P4.38, P4.42.
   **Two of my own conclusions withdrawn here** (§3C).

### 4 — Verification

- **Restored** — `msys_mv5` is the oracle's bytes; the width census matches the pre-change run bucket for
  bucket.
- **Suites** — `ALL PASS` at 128 KB with `integ`, before and after.
- **The disk** — every file byte-identical to its artefact.

### 5 — Verdict-time evidence (v0.7 §11)

```
s_Princess mean pulse width:   oracle 15.7 us    port 21.3 us
  the oracle's own songs:  s_Buildup 11.2  s_StTimer 13.2  s_Magic 15.0
                           s_Princess 15.7 s_Squeek 22.5   s_Vizier 23.6
with the change:  port mean 16.4 us, pulses at max 3231 -> 18
after revert:     8.4/14.0/16.8/22.3 at 154/54/196/3231  (identical to baseline)
```
```
[suites] -ramsize 128K   [run_introseq_test] PASS   [integ] PASS   ALL PASS
```

**25.3 operator-runtime-smoke: the change was gated and REJECTED.** Jay, live-disk, RGB, 128 KB, sound on,
by ear: ***"doesnt sound any different."*** Recorded as a **null result**, which is what it was — not a
failure of the build and not a pass.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** Jay: *"lets try the envelope change for 5"*, then *"yes revert and report"*. **Both
done.** The tree is byte-identical to its pre-change state apart from an empty `ENV_OVERRIDE` and its
comment.

**★★ I PROPOSED THE ENVELOPE THEORY AND IT WAS WRONG.** It was coherent, it explained "why only there", it
was supported by a 36% measured excess, and the fix worked exactly as predicted on the bus. **None of that
made it the defect.** ★ *A theory that predicts a measurement correctly has still not been tested against
the thing the measurement is a proxy for.*

**Not attempted:** the `VTBL` sharing (§3E), whose predicted direction is wrong; and nothing further on the
blitter, which P4.36 sized at 12%.

### 7 — Uncertainty flags

- **★★★ THE FUZZINESS IS UNEXPLAINED AFTER TEN MEASUREMENTS.** Established: it is not the blitter, not
  masking, not quantisation, not pitch, not duty, not spectrum, not the silence ratio, and **not amplitude**.
- **★★ MY ERROR RATE IN THIS ARC IS THE THING TO WEIGH.** Four thresholds written before their scale; three
  conclusions withdrawn; one fix built on a theory that measured right and sounded like nothing. **The
  pattern is that I build comparisons faster than I verify their scales**, and Jay's ear has been more
  decisive than any of my instruments.
- The `VTBL` divergence is real and its direction is against it (§3E).

### 8 — Follow-up candidates

- **★★ STOPPING IS A LEGITIMATE OUTCOME AND I AM RECOMMENDING IT BE CONSIDERED.** The timing, the cues, the
  animation and the hourglass are all gated and accepted. What remains is one song's timbre, resistant to ten
  measurements, in a subsystem where every faithful-reproduction question has come back "the port matches".
- **If it is pursued:** the `VTBL` sharing (§3E) is the only concrete implementation divergence found that is
  specific to this song. **Its predicted direction is wrong**, which is worth knowing before spending on it.
- **A different kind of evidence:** an A/B of a single sustained note, sample by sample, rather than any
  further whole-song statistic. Ten of the eleven measurements here average over the song.
- Carried: P3.87's pace (1.20×); the 6-byte headroom; the disk's 18-of-18 granules; the `LOADM` ceiling;
  `start_col` vs §2F.1(5); gameplay's colour mode; the per-cue control policy; the HAL audit; the stale
  `pop.link` stack comment; `Demo` unbuilt.

### 9 — User interaction during task

- Jay: ***"here's what i don't understand… why only there"*** — the observation that redirected the arc.
- Jay: ***"check it"***, ***"yes"*** — each next measurement.
- Jay: ***"lets try the envelope change for 5."*** — built.
- Jay: ***"doesnt sound any different"*** — the verdict.
- Jay: ***"yes revert and report"*** — this.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-20-a-defect-in-one-instance-exonerates-everything-shared.md` — committed and pushed.

### 11 — Commit

`589e8d9`, `15a2694`, `6101313`, `cb49c45`, `d283673` — all pushed to origin/wip before this report.
