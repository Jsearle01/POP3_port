## Form B Report — P3.38 RECON — does the heaviest frame need both characters shifted?
**Class:** recon. wip. No `src/` change, no lever pulled, no representation committed.

### 0 — Receipt / status (C-35 stamp)
t0=2026-08-08T17:36:53Z (HEAD `32f826d`, wip). `git status --porcelain` showed **0** tracked modifications at
t0. Untracked = `.vscode/`, `nvram/`, `docs/ground-truth/*.pdf` (never committed, Jay's standing rule),
`POP-idioms-coco3-markers.md`, `content/intro/broderbund_splash_render.bin`, `content/cutscene/*`.
No HAL change; no build.

---

### 1 — Summary

**The lead is half right, and the half that fails is the half that decides.**

**Confirmed from the script: the two characters NEVER both move.** Across all nineteen `play` calls, every
`chx` belongs to a stretch where the other character is at a fixed x.

**Refuted: "static" does not mean "no shift".** At `play 13` **both characters need shifting** — the princess
because her **x changes** (`Pback`: `chx,11/1/1/3/1`), the vizier because his **cel changes** (`Vraise`, which
contains **no `chx`** but steps through cels 85/67-76/83/84). **A fixed-x character with a changing cel still
pays the shifter**, because the new cel arrives at phase 0 and must be shifted to her column.

| stretch | shifting | frame at ~34 cy/B | verdict |
|---|---|---|---|
| six of seven stretches | **one character** | 25,704 | **87% — fits** |
| **`play 13` (Vraise + Pback)** | **both** | 31,756 | **107% — does not fit** |

**So the gap survives, but it is now confined to one stretch of the scene rather than being a property of the
whole cutscene.** That is a materially different problem from the one P3.36/P3.37 described, and a much
narrower one.

**Thresholds recomputed from P3.37's 19,652** (not inherited — four carried figures have now been corrected in
a row): **56.3 cy/byte** if one character shifts, **28.1** if two. The loop is 30.0 inner / ~34 all-in.

---

### 2 — Files modified
- `reports/20260808-133826-p3-38-recon-heaviest-frame.md` — this report (only change).

No `src/` change; nothing built.

---

### 3 — Reasoning

#### 3A — The timeline, read from `PlayCut0` and `SEQTABLE.S`

| `play` call | vizier | princess | who shifts |
|---|---|---|---|
| `play 2`, `play 5` | `Vstand` — 1 cel, fixed x | `Pstand` — 1 cel, fixed x | **neither** |
| `play 9` after `pjumpseq Palert` | `Vstand` static | `Palert` cels 2-9, then `chx,9` | princess |
| `play 6` after `vjumpseq Vapproach` | `Vwalk` `chx 2,6,1,-1,1,1` | `Pstand` static | vizier |
| `play 4`, `play 4` after `Vstop` | stopping | `Pstand` static | vizier |
| `play 30` after `Vapproach` | `Vwalk` `chx` | `Pstand` static | vizier |
| `play 1` after `vjumpseq Vraise` | `Vraise` cels, **no `chx`** | `Pstand` static | vizier (cel only) |
| **`play 13` after `pjumpseq Pback`** | **`Vraise` cels, no `chx`** | **`Pback` `chx 11,1,1,3,1`** | **both** |
| `play 17` after `vjumpseq Vexit` | `Vexit` `chx` | `Pslump`/static | vizier |

**The single-cel loops are real and they are long.** `Pstand` is `db 11,goto / dw Pstand` — one cel, forever —
and it covers `play 6 + 4 + 4 + 30 + 1` = **45 animation steps**, the bulk of the scene, while the vizier
walks. `Pslump` is the same shape. For those stretches the princess's bytes are **identical every frame**:
same cel, same x, same phase.

#### 3B — Where the lead breaks, and why the distinction matters

The dispatch's mechanism was *"a cel at a fixed x has a fixed sub-byte phase, so there is nothing to shift"*.
**True, and insufficient** — it requires the *cel* to be fixed as well as the x.

Two different things were being collapsed:

- **Fixed x AND fixed cel** (`Pstand`, `Pslump`): the shifted bytes are literally the same bytes every frame.
  Shift once, reuse.
- **Fixed x, CHANGING cel** (`Vraise`): each new cel arrives at phase 0 and must be shifted to the character's
  column. **The shifter runs on every cel change**, which under `Vraise` is every animation step.

`play 13` puts one of each on screen simultaneously, and the sum is two full shift costs. **`Vraise` is
precisely a sequence that changes cel without moving** — the case the lead's phrasing does not cover.

I am stating this as a refutation of the lead rather than working around it, per HARD-STOP #2: the script
decides, and it says both characters shift in that stretch.

#### 3C — What a truly static character costs, and what caching would need

For `Pstand`/`Pslump` the shifted form is invariant, so it could be produced once and held. **Cost: one
shifted cel buffer per static character.** A princess cel is 43 rows × ~6 bytes = ~258 B, plus the spill byte
per row → **~301 B**, against P3.33's **4,394 B spare** in the 14,848 B window. Comfortable.

**But caching does not help the frame that fails.** At `play 13` the princess is the one *moving*, so her
bytes change every step and there is nothing to cache; and the vizier's cel changes every step, so his cannot
be cached either. **The cache saves exactly the frames that already fit.**

**And "static" does not mean "not drawn."** P3.32 made the peel-skip frame-wide — if anything moved, everybody
peels — so a static character is still erased, saved and drawn every frame. What caching removes is only the
*shift*, not the draw. That is what the dispatch asked me to check and it is the answer: the draw cost stays,
the shift cost is avoidable only when both x and cel hold still.

#### 3D — Recomputed, and the one number I could not measure

Thresholds from **19,652** (P3.37), at 178 B/cel drawn:

| case | threshold | loop 30.0 | loop 34.0 |
|---|---|---|---|
| one character shifting | **56.3 cy/B** | 24,992 = 84% | 25,704 = **87% fits** |
| two characters shifting | **28.1 cy/B** | 30,332 = 102% | 31,756 = **107% does not fit** |

**A caveat that makes the verdict worse rather than better, so the conclusion is robust to it:** 178 B/cel is
the **walk cels'** measured drawn-byte mean (P3.35). `Vraise`'s cels resolve to chtab6.A **93-103**, which
P3.18 recorded at **48-58 rows** against the walk cels' 47 — so the `play 13` frame is likely **heavier** than
2 × 178, not lighter. **I did not convert and measure those cels**; doing so is a bake, which this recon is
not authorised to do. The gap at `play 13` is therefore **at least** 2,083 cy and plausibly more.

---

### 4 — Verification (AC-by-AC)

- **AC1 — heaviest frame named concretely.** **MET** (§3A): `play 13`, following `pjumpseq Pback`, with
  `Vraise` live on the vizier — identified from `PlayCut0`'s call order and the sequences, not assumed.
- **AC2 — per-character state with `chx` evidence.** **MET** (§3A, §3B). `Vraise` contains no `chx` (verified
  by grep); `Pback` carries `chx 11,1,1,3,1`.
- **AC3 — static-character cost determined, cache storage costed.** **MET** (§3C): ~301 B per static
  character against 4,394 spare — and the finding that it saves only frames that already fit.
- **AC4 — recomputed at both rates against a fresh threshold.** **MET** (§3D). 56.3 / 28.1 from 19,652.
- **AC5 — plain verdict.** **MET**: the gap survives, confined to `play 13`; shortfall ≥2,083 cy; implied
  147 B/cel *for that stretch only*.
- **AC6 — no build, no lever, no representation.** **MET.**
- **AC7 — route accounting; clean tree.** **MET.** Karateka untouched; `main` untouched; only this report.

---

### 5 — What this changes about the decision

**The problem is no longer "the shifted representation does not fit the cutscene."** It is **"the shifted
representation does not fit one 13-step stretch where a cel-changing character and a moving character are on
screen together."** Six of seven stretches fit at 87%.

That is a different question, and it is Jay's to take. I am not pulling a lever, but the narrowing is the
deliverable and worth stating precisely: **the failure is localised, and it is localised to a stretch whose
composition is a property of the script rather than of the engine.**

**What I have deliberately not done:** measured `Vraise`/`Pback` cel sizes (needs a bake), costed any
mitigation, or touched the representation.

---

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** I proposed no route. What this change contains: one report — a timeline, a refutation of
the dispatch's lead, a static-character cost, and recomputed thresholds. It contains **no** code, no lever, no
representation, no bake, and no recommendation about which lever to pull. §5's narrowing is a finding.

**Deviations:**
- **Reported the lead as refuted rather than confirmed** (§3B) — the script shows both characters shifting at
  `play 13`, for two different reasons. Per HARD-STOP #2 I did not go looking for a different frame to make
  the lead work.
- **Left `Vraise`/`Pback` cel sizes unmeasured** (§3D) and said which direction that biases the answer.

### 7 — Uncertainty flags
- **`Vraise`/`Pback` drawn-byte counts are unmeasured** (§3D). 178 B/cel is the walk mean; `Vraise`'s cels are
  taller, so `play 13` is probably worse than costed. **This is the largest open number in the report.**
- **The `play 13` stretch is 13 steps at SPEED 7** — I did not check whether every one of those steps has both
  characters simultaneously active, only that the stretch does. A finer walk might find the overlap shorter.
- **`Pback`'s tail (`:loop db 17`) may leave her static for part of the stretch**, which would shorten the
  overlap further; not traced.
- Carried: `shift_row.s` counted not assembled; the ~0.51-frame cadence overrun; `aboutface` unexercised and
  invalidating baked parity when it fires.

### 8 — Follow-up candidates
1. **Measure `Vraise`/`Pback` drawn bytes** — the one number that sizes the remaining gap properly.
2. **Trace `play 13` step by step** to see how many frames actually have both characters shifting (§7); the
   overlap may be shorter than 13 steps.
3. **Then Jay's lever decision**, now against a localised failure rather than a global one.
4. Carried: `Vstop`/`Vraise`/`Vexit`, `PlayCut0` (E); F/G/H; parity-vs-turning before G.

### 9 — User interaction during task
None — dispatch executed as written.

### 10 — Candidate(s) captured this task
`seeds/POP/live/2026-08-08-a-worst-case-assembled-from-each-parts-maximum-may-never-occur.md`

### 11 — Commit
This report only; no `src/` change. Pushed to `origin/wip`. `main` untouched; no force-push.
