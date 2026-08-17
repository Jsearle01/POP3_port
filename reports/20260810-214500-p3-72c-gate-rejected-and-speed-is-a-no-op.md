## Form B Report — P3.72c — the gate was rejected on Palert's pace, and "true to oracle" turns out to be a no-op
**Class:** recon (gate + oracle authority). wip. No source change. Prod untouched.

### 0 — Receipt / status (C-35 stamp)
Continuation at Jay's "show me" then "1. lets make it true to oracle and then go from there".
HEAD `769eaf4`, wip. Suites green. Karateka and `main` untouched.

---

### 1 — Summary

**25.3 GATE: REJECTED.** Launch path **`live-disk`, RGB, `run_room_live.sh`**, real `LOADM"ROOM"`+`EXEC` off a
mounted floppy, throttled to 99.99% speed. **Jay's words, verbatim: "her ovement is way to fast".**

Jay then chose option 1 — make it true to the oracle first. **Investigating that instruction found the oracle
answer, and the answer is that the port is ALREADY true to it.** Implementing `SPEED` faithfully would change
nothing visible in the scene as it stands.

| | frames per step |
|---|---|
| **port, her turn** (measured this session, live path) | **3.86** |
| **oracle, characters animating** (P3.26, measured on the oracle) | **3.9** |

**Within 1%.** So "too fast" is not a fidelity defect — it is a judgement about the original's pace, and the
decision is Jay's to make as a deliberate deviation.

---

### 2 — Files modified

`harness/smoke/run_room_live.sh` — the gate text now names Palert and the three track reads (`769eaf4`). No
engine change.

### 3 — Reasoning

**3A — What the oracle actually specifies.** `play` pauses every animation step by `SPEED`
[SUBS.S:876-881], and `PlayCut0` — the scene the port is building — runs:

```
SPEED = 1            (inherited; the dispatcher restores #1 after every cutscene, "no delay")
  play 2 / play 5
  pjumpseq Palert
  play 9             <-- HER TURN
  lda #7 / sta SPEED
  play 5 / Vapproach / play 6 / Vstop / play 4 / play 4
  Vapproach / play 30 / Vstop / play 4
  Vraise / play 1 / Pback / play 13
  lda #12 / sta SPEED
  play 5 ...         <-- the hourglass onward
```

So the oracle's own values across this scene are **1 → 7 → 12**, and her turn is at the *fastest* setting.

**3B — And why that does not translate into a pace change. `pause` is a MINIMUM, and the oracle's draw
overruns it.** This project already measured that, on the oracle, at P3.26:

```
early  (f2700-4700): mean 2.6 frames between updates = 22.8 Hz
late   (f4700-6700): mean 3.9 frames between updates = 15.6 Hz
```

with the report's own conclusion: *"`SPEED 7` means 2.6 (intent, in the source); the oracle achieves 3.9 (fact,
on the trace)."* **The oracle is draw-bound whenever characters animate.**

Apply that to the three SPEED values, taking 2.6 frames as the SPEED-7 intent (so ≈0.37 frames per unit):

| SPEED | pause intent | oracle actual | port |
|---|---|---|---|
| **1** (her turn) | 0.4 frames | **draw-bound ≈3.9** | **3.86** |
| **7** (the approach) | 2.6 frames | **draw-bound ≈3.9** | 3.83 |
| **12** (hourglass on) | 4.5 frames | 4.5 — **pause finally exceeds the draw** | not built |

**SPEED only becomes visible at 12**, in beats that do not exist yet. For everything currently on screen, both
machines are draw-bound and land within 1% of each other.

**3C — So the port's `cad_tab` is not the wrong mechanism; it is the right value.** `char_draw.s` already cites
`SPEED 7` at SUBS.S:683 and calibrates 23/6 = 3.833 against *"the oracle's measured 3.9"*. Adding a SPEED
concept now would be correct groundwork for the later beats and a **no-op for what Jay just watched.**

**3D — What I am NOT claiming.** P3.26's 3.9 came from a window with **both characters animating plus the
hourglass** — a heavier workload than Palert, where she animates alone and the vizier holds. The oracle's Palert
could therefore be somewhat *faster* than 3.9, which would make the port's 3.86 already on the slow side. It
cannot plausibly be *slower*. Settling that exactly needs a direct oracle measurement of Palert (§8.2), which I
have not run.

### 4 — Verification

- **25.3:** **REJECTED by Jay**, `live-disk`, RGB, live (motion-bearing, watched running — not a still).
  Verbatim: *"her ovement is way to fast"*. Not self-certified.
- Port's Palert cadence, measured off the live path this session: cel changes at frames
  1762, 1766, 1770, 1774, 1777, 1781, 1785, 1789 → gaps 4,4,4,3,4,4,4 → **mean 3.86 f/cel; the 8-cel turn is 27
  frames = 0.45 s.**
- Oracle figures quoted from `reports/20260729-203504-p3-26-vm-pacing-gate.md`, measured there, not re-derived.
- Suites unchanged and green (P3.72b): room 8/8, walk 28/28 both sizes, intro 17/17, bank assertion green.

### 5 — Route accounting

Jay asked for the live gate ("show me") and then for oracle fidelity ("make it true to oracle"). **This contains
the gate, its rejection, and the oracle investigation. It contains NO engine change** — because the
investigation's result is that the faithful change is a no-op, and implementing a SPEED mechanism that moves
nothing while reporting it as a response to "too fast" would be the P3.30 failure exactly: a route described and
an artefact that does something else.

### 6 — Uncertainty flags

- **3D**: the oracle's Palert-specific rate is inferred from a heavier-workload window, not measured directly.
- The port's PLAN is a simplification of `PlayCut0`: it omits the leading `play 2`/`play 5`, the `play 5` after
  the SPEED change, and the **first** Vapproach/Vstop pair (6 and 4 plays) before the 30-play approach. That is
  pre-existing and separate from pacing, but it will matter when the remaining beats land.
- Carried: hourglass 856 B over; 513 B over the 32 KB bank; `$2310..$2329` read-tap blindness; `PlayCut0`'s four
  sound sites un-stubbed; `shift_row.s` unwired.

### 7 — Follow-up

1. **Jay's ruling** on pace: accept the original's rate, or deviate deliberately and record it as a deviation.
2. **Optional**: measure Palert directly on the oracle (`apple2e` + `cffa202` + `-hard1`, CLAUDE.md §2A) to
   replace the inference in 3D with a number.
3. `SPEED` as groundwork for the hourglass-onward beats, where it does bite.

### 8 — Commit

`769eaf4` (gate text) — pushed. This report to follow.
