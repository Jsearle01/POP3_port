## Form B Report — P3.74 — the LOADED TOTAL crosses at `Pback`; a swap is required
**Class:** recon (the build the dispatch authorised was stopped by its own §2 gate). wip.
No source change. Prod untouched.

### 0 — Receipt / status (C-35 stamp)
t0=2026-08-11T10:44:47-04:00 (HEAD `5d0a03d`, wip). Tree green and unchanged but for four
generator label entries (§2). Karateka and `main` untouched.

---

### 1 — Summary

**The loaded total crosses at `Pback`: 23,002 B against a 15,872 B window, over by 7,130.**
Measured by baking and linking the real image after each beat, not by arithmetic.

```
current (Palert -> his stop)  19 bakes  12,922 B   fits, 2,950 spare
+ Vraise 1                    20        13,464     fits, 2,408 spare
+ Pback 13                    35        23,002     OVER by  7,130   <- crosses here
+ hold 5                      40        25,194     OVER by  9,322
+ Vexit 17                    52        30,556     OVER by 14,684
+ hold 12                     63        39,104     OVER by 23,232
+ Pslump 28                   64        39,680     OVER by 23,808
```

**So a swap mechanism is required — the scene cannot be completed with one loaded image.**
Per HARD-STOP #2 the crossing is reported and **the swap is not designed.**

**Nothing was landed, including `Vraise`** — §3B gives the reason, and it is not the budget.

**★ And the hourglass verdict was NOT the sum/peak error.** The dispatch invited me to
overturn it; the honest answer is that it stands (§3C).

---

### 2 — Files modified

`harness/tools/bake_scene.py` — four `LABEL` entries (`Vraise`→`viz_raise`, `Pback`→`pri_back`,
`Vexit`→`viz_exit`, `Pslump`→`pri_slump`) so the generator can name the remaining sequences.
**No engine, build, link or content change.** (`674ca56`)

The sequences themselves are deliberately not written. With the label present, adding a PLAN
entry for a sequence that has no body now fails at **link** with an undefined symbol instead
of at **bake** with a `KeyError` — both loud, neither silent.

### 3 — Reasoning

**3A — Three different quantities have now been called "the memory requirement", and only one
answers this question.** For the same content:

| | | decides |
|---|---|---|
| disk **sum** | 36,847 B | how many tracks the image needs |
| **loaded** total | 39,680 B | **whether a swap mechanism must exist** |
| live **peak** | 6,769 B | how big a swapped-in working set must be |

**The loaded total EXCEEDS the disk sum**, which looks wrong and is not: a mirrored variant is
a second copy in the bank but the same source cel on disk. That the three differ by 6× across
the same data is why P3.62 and P3.72m both manufactured a crisis — and why P3.73's peak, on
its own, would have manufactured the opposite one. **The peak fitting does not mean no swap is
needed; it means a swap can be small.**

**3B — Why `Vraise` was not landed, and it is not the budget.** It fits at the oracle's own
`play 1` with 2,408 B spare. But `Vraise` is `85, 67x6, 68..75, 83, 84, :loop 76`
[SEQTABLE.S:1503] — about 18 plays to reach the held pose — and only 8 of them fit:

```
play 1   13,464 B  fits, 2,408 spare        play 10  16,069 B  OVER by 197
play 8   14,798 B  fits, 1,074 spare        play 18  20,569 B  OVER by 4,697
```

The oracle gives `Vraise` one play and lets `Pback`'s thirteen carry the gesture on. With
`Pback` unable to land, `("v","Vraise",1)` followed by the trailing `Vstand` hold would flick
to cel 85 for a single step and snap back to standing. **That is a glitch, not a gesture** —
it would make the scene visibly worse than the one Jay gated, and it would spend 542 B of the
2,950 a swap design may want. A clean stop is the better artefact.

**3C — The hourglass: the dispatch's premise is wrong and the old verdict stands.** §1 says its
*"856 B objection was computed against the same mistaken framing (a sum, not a peak)"*. It was
not. P3.67 §3A costed **loaded totals against the window** — the very quantity this dispatch
calls deciding:

```
current scene cels              7,455 B   fits, 8,417 spare
current + Palert               12,747 B   fits, 3,125 spare
current + Palert + hourglass   16,728 B   over by 856
```

and P3.67 §3B explicitly subtracts the 512 B that MC3 and I/O take off the 16 KB. That is the
right arithmetic on the right number. Re-derived at today's figures — the loaded set has moved
from 12,747 to 12,922 B since, via the two-stage entrance and the phase alignment — the
hourglass is ~3,981 B and would land at **~16,903 B, over by ~1,031.** It still does not fit,
and it is moot regardless: `Pback` crosses first and the hourglass appears inside that beat.

**Two of this arc's four killed leads were the Orchestrator's; this is a fifth.** Worth stating
plainly because the pattern is instructive: the sum/peak error was real twice, which made it
look like the explanation for every earlier budget verdict. It was not the explanation for this
one.

**3D — What the numbers say about the two shapes in §3, without designing either.** Recorded as
measurement, not recommendation:

- *Pin one slot, rotate the other* — the walk cels are live steps ~130..~300 (`Vexit → Vwalk2`),
  so they must stay resident across every beat between. They are **6,769 B at their peak**
  including her standing cel, which is under one 8 KB block only if the pinned slot carries
  the walk set alone. It does not fit with `Pback`'s 9,538 B increment beside it in the same
  8 KB.
- *Rotate both* — the largest single beat increment measured above is `Pback`'s **9,538 B**
  (12,922 → 23,002 including its share), which exceeds one 8 KB block. So a per-beat set does
  not automatically fit a single block either.

**Both shapes therefore need the numbers per block, not per beat**, and that is a measurement
the swap dispatch should take before choosing.

### 4 — Verification

- **25.1:** every byte figure above is produced by `lwasm` + `lwlink` + `decb_to_raw` on the
  real `cel_image.s`, the same three steps `build.bat` runs — not by a per-bake average. (My
  P3.72m estimates were 12% high for exactly that reason.)
- **The instrument was checked for the fault it might cause** (P3.71): the sweep writes into
  `content/cutscene/chars/` and `build/`, so the tree was restored afterwards by re-running
  `bake_scene.py` and `build.bat`, and verified back at **12,922 B / 19 includes** — its
  committed state.
- **Tree green after restoration:** `run_room_test.sh` → `checks=8 passed=8 failed=0` / `PASS`;
  `run_walk_test.sh` → `first movement at frame 2570 (+811 held frames)`,
  `bank_mapped_at_every_capture PASS (0 of 28)`, `STABLE`, `PASS`.

**25.2:** N/A. **25.3:** **not offered.** The scene is unchanged from the one Jay already gated
("that looks awesome"), and the complete arc §5 asks for cannot be built until the swap exists.
Offering the same scene again would spend his time on nothing new.

### 5 — Acceptance criteria

1. **Beats landed** — **no.** Stopped by §2's own gate at `Pback`; `Vraise` withheld for §3B.
2. **Hourglass re-checked** — **yes**, and the old verdict stands on its own arithmetic (§3C).
3. **★ Loaded total reported per beat** — **yes** (§1). It **crosses**, at `Pback`, with the
   number. **The swap is not designed.**
4. Suites green (§4). 5. Tree stated (§4). 6. Gate not offered, with reason (§4).
7. §6 below; Karateka and `main` untouched.

### 6 — Route accounting

The dispatch authorised landing six beats and gated that on §2's number. **§2's number stops
it at the first one**, so this contains the measurement and nothing else: no beat data, no
swap mechanism, no `walk_tab` change, no loader. The only edit is four generator labels.

I proposed nothing beyond the dispatch and implemented none of §3's two shapes; §3D reports
what the measurements say about them and stops there.

### 7 — Uncertainty flags

- **The hourglass's ~3,981 B is derived by subtraction** from P3.67's table, not measured
  directly — its asset was never built. The conclusion is insensitive (it would have to be
  under 2,950 B to fit, a 26% error) but the figure itself is second-hand.
- **The per-beat increments are cumulative differences**, so they include each beat's mirrored
  variants and any phase the trace newly reaches. They are not the beat's cels in isolation.
- The loaded totals assume the current one-image-at-$C000 layout; a swap changes what "loaded"
  means and every figure above would need re-taking against the new scheme.
- Carried: the runtime mirror (~4,175 B for ~3,080 cy/cel, still sequenced after); the
  `$2310..$2329` read-tap blindness; `PlayCut0`'s remaining sound sites.

### 8 — Follow-up

1. **The swap dispatch.** §3D's finding is its first task: neither shape obviously fits, because
   `Pback`'s 9,538 B increment exceeds an 8 KB block. **Measure per block before choosing.**
2. §3's addressing hazard is the real one — `walk_tab` holds absolute pointers, and a wrong
   block underneath a valid-looking pointer draws garbage rather than crashing. That is the
   capture-05 presentation exactly, and the draw-time assertion the dispatch describes should
   be built with the swap, not after it.

### 9 — Candidate captured

`seeds/POP/live/2026-08-11-name-which-layer-a-number-belongs-to.md` — pushed. Three quantities
on the same content differing by 6×, each answering a different question; comparing the wrong
one against a capacity manufactured a crisis twice and would have dismissed a real constraint
once.

### 10 — Commit

`674ca56`. This report follows.
