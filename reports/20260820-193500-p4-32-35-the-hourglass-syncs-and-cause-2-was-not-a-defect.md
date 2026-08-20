## Form B Report — P4.32–P4.35 — the hourglass syncs, and **"cause 2" was never a defect**

**Class:** build + recon.  wip.  Prod changed — one PLAN row's song column moved (P4.34); content
regenerated. **No `src/` change in this arc.** Karateka untouched; `main` untouched (`34e93e0`).

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-20 19:35 (HEAD `b4d8160`, wip). Tree clean apart from the modified
`dist/mame-cfg/rgb/coco3.cfg` carried since P4.19 and the pre-existing untracked files.

### 1 — Summary

| | |
|---|---|
| **P4.32 the hourglass, measured** | the sound landed **with the SAND**, 0.73 s after the glass — **which is the oracle's own order** (§3A) |
| **P4.34 the hourglass, synced** | **glass and sound now on the SAME FRAME**, at Jay's request, **with every play count preserved** (§3B) |
| **★★★ P4.35 "cause 2"** | **NOT A DEFECT. It is the music's own long notes and rests** (§3C) |
| **the correction** | **P4.31 said two causes. There is ONE** — the blitter's per-row mask (§3C) |
| **two instrument errors** | both caught before they reached a conclusion, both recorded (§3D) |
| **suites** | **ALL PASS, 128 KB, `integ` included** |
| **Jay's gate** | **NOT YET OFFERED on P4.34** — the hourglass change has not been in front of him |

### 2 — Files modified

- `harness/tools/glass_vs_cue.lua` — **NEW.** The hourglass animation against its cue.
- `harness/tools/pulse_gap_census.lua` — **NEW.** What is inside the music's gaps, hypothesis-free.
- `harness/tools/bake_scene.py` — `s_Magic`'s song column moved one row earlier.
- `content/cutscene/chars/` — regenerated.

### 3 — Reasoning

#### 3A — P4.32: where the sound actually sat

Jay: *"where is the hourglass drop sound in reference to the actual hourglass animation"*. Measured from
`vm_scenery` (`$4054`), the per-beat flag the room draws the glass and sand from:

```
+39.90 s   SCENERY  GLASS0+FLASH     the glass appears, with its flash
+40.64 s   SCENERY  GLASS0+FLOW      the sand starts
+40.64 s   CUE      song id 11       s_Magic — THE SAME FRAME as the sand
+42.49 s   SCENERY  FLOW+GLASS1      the body switches to state 1
```

**The sound belonged to the sand, not to the arrival — and that is faithful.** The oracle's
`sta psandcount` and its `jsr PlaySongI` are **adjacent instructions** [`SUBS.S:715-745`], with `addglass1`
a whole `play` earlier. ★ *So "it sounds late" was a true observation about the oracle, which is what Jay
independently concluded: "yes it sounds late in the orcle too, i think that beacuse if the limtation of the
apple ii."*

#### 3B — P4.34: the sync, and why it was free

Jay: *"I'd like to try and sync the landing of the hourglass with tis sound."* **§2I governs** — the oracle's
mechanism is evidence about how to achieve the effect, not a requirement; **§2.1 makes his ear the
authority.** Recorded as a decision, not argued as a deviation.

**★★ THE UNITS ARE THE WHOLE OF THE CARE HERE.** `expand()` converts a `("song", …, N)` row's **N frames** to
`round(N/SONG_FPS)` **plays**; a `("-", "", N)` row's N is **already plays**. So the two rows could swap which
one carries the song **without moving a single play**:

| beat | before | after | plays |
|---|---|---|---|
| 15 (glass + flash) | `("-","",5)` | `("song","s_Magic",35)` | **5 both ways** |
| 16 (sand) | `("song","s_Magic",113)` | `("-","",16)` | **16 both ways** |

Verified through `expand()`: beats 15/16 are 5 and 16 plays before and after, **total 438 unchanged**.
`SCENERY`'s **flags stayed on their own beats**; only its **name assertions** swapped, because the row types
did — and every key was re-checked against its beat name.

**Result, measured:**
```
+39.90 s   SCENERY  GLASS0+FLASH  ─┐  same frame
+39.90 s   CUE      song id 11    ─┘
+40.67 s   SCENERY  GLASS0+FLOW      the sand, unchanged
```

#### 3C — ★★★ P4.35: "CAUSE 2" IS THE COMPOSITION, NOT A DELAY

**P4.31 reported two causes.** The census — which counts what is inside each gap rather than testing a
hypothesis — says there is one.

```
  gaps over 3000 us    78              ordinary gaps  1641
    blits inside       0.49 avg          blits inside  0.09 avg
    VBL ticks inside   0.46 avg
    player in PAD      0 of 78
  worst gap  8731 us  (blits 0, swaps 0, vbl 0)
```

**★★ BLIT DENSITY IS THE SAME INSIDE AND OUT.** 0.49 blits per ~8 ms gap is ~0.06/ms; 0.09 per ~1.7 ms gap
is ~0.05/ms. A big gap holds more blits **only because it is longer**. The blitter is eliminated.

**★★★ AND THE VBL INTERRUPT FIRES AT ITS NORMAL RATE THROUGHOUT THEM** — 0.46 per gap where ~0.27 would be
expected. **If interrupts were masked, the VBL count would be SUPPRESSED inside the gaps.** It is not.
**Nothing is holding interrupts off; the player scheduled these periods itself.**

**So they are the music's own long notes and rests.** `pulse_jitter.lua` compares **consecutive periods**, so
a rest followed by a note yields a huge `|Δ|` that is **composition, not jitter**. P4.31's *"8.4% over 1 ms =
cause 2"* is largely that artifact.

**★ THE CONSEQUENCE FOR THE PLAN:** there is **one** cause — the blitter's per-row mask, median **91 µs**,
67% of the deviations — and **the narrower window is the whole of the remaining lever**, not two thirds of
it. ★ *Jay's instruction was "cause 2 first, then the narrower window". Cause 2 is now closed by measurement
rather than by a fix, which is the cheapest possible outcome and is why it was worth doing first.*

#### 3D — ★★ TWO INSTRUMENT ERRORS, BOTH CAUGHT BEFORE A CONCLUSION

1. **`glass_vs_cue.lua` reported "sand starts → s_Magic: +131.02 s".** `vm_scenery` lives in the flame
   bundle, which is **ordinary RAM until the bundle is read and expanded**, so pre-scene garbage logged
   FLOW/FLASH events at −90 s, −19 s and −13 s and the unwindowed "first FLOW" search took one. **It
   announced itself by being absurd.** The search is now restricted to the scene window; the **timeline was
   right throughout**, only the derived line was wrong. ★ *`cel_load_startup`'s comment warns about this class
   for the constant page — it applies to the bundle's variables too.*
2. **`pulse_gap_census.lua` defaulted to a 1000 µs threshold, which is BELOW the 1743 µs mean note period**,
   so it censused ordinary notes as "gaps" and its averages were meaningless. **Caught by the contrast line**
   — 200 "big" gaps against 42 ordinary ones is not a plausible pulse train. Re-run at 3000 µs. ★ *A
   threshold expressed in absolute units has to be checked against the scale of the thing it thresholds; this
   one was written before that scale was known.*

#### 3E — §2H's three checks

1. **A second mechanism?** ★ **The finding is that there ISN'T one** (§3C) — and the check was the reason to
   census rather than to assume the millisecond tail was a second masker.
2. **The calling routine.** The 91 µs bulk is `blit_cel`'s row loop; the big gaps have **no** caller holding
   interrupts off, which the VBL rate establishes positively rather than by absence of evidence.
3. **Prior-report grep** (`pulse_jitter|cause 2|masked|rests`): P4.28, P4.29, P4.31. **One correction to my
   own P4.31**, made here rather than left to be discovered.

### 4 — Verification

- **The hourglass sync** — `glass_vs_cue.lua`, same frame (§3B).
- **Play counts preserved** — through `expand()`, not by eye: 5/16, total 438.
- **`SCENERY` keys** — every one re-checked against its beat name (True).
- **Cause 2** — `pulse_gap_census.lua` at a threshold above the note period (§3C).
- **Suites** — `ALL PASS` at 128 KB with `integ`. ★ *512 KB not run: no MMU, bank, framebuffer or loader
  change.*

### 5 — Verdict-time evidence (v0.7 §11)

```
[suites] -ramsize 128K   [run_introseq_test] PASS   [integ] PASS   ALL PASS
```
```
+39.90 s   SCENERY  GLASS0+FLASH
+39.90 s   CUE      song id 11
+40.67 s   SCENERY  GLASS0+FLOW
  glass appears -> s_Magic :  +0.00 s
```
```
  gaps over 3000 us      78
    blits inside      0.49        (ordinary gaps, n=1641: 0.09)
    VBL ticks inside  0.46
  worst gap  8731 us  (blits 0, swaps 0, vbl 0, state 0)
```

**25.3 operator-runtime-smoke: NOT YET OFFERED for P4.34.** The hourglass sync has **not** been in front of
Jay. The last operator ruling is P4.31's on the squeak reorder, itself unrecorded.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** Jay's instruction was **"yes do them in that order"** — cause 2's diagnosis, then the
narrower blit window — with the hourglass question arriving ahead of both.

**This arc contains** the hourglass measurement, the hourglass sync, and **cause 2 closed by measurement**.
**It does NOT contain the narrower blit window**, which is next and untouched.

**★★ AND IT WITHDRAWS HALF OF MY OWN P4.31 FINDING** (§3C). I reported two causes and sized them 67/8. There
is one. ★ *The 8.4% was real as a measurement and wrong as a diagnosis — the number was never in doubt, only
what it meant.*

### 7 — Uncertainty flags

- **The rests conclusion rests on the VBL rate inside the gaps.** It is positive evidence (interrupts are
  being taken) rather than an absence, but **I have not confirmed against the player's own programmed timer
  period** that each big gap was intended. The stronger check exists and is in §8.
- **The 78 big gaps are one window of one run.**
- **The audio is still Jay's *"dirty"*** — nothing in this arc addressed it.

### 8 — Follow-up candidates

- **★★★ THE NARROWER BLIT WINDOW — NEXT, and now the whole lever rather than two thirds.** Mask only the two
  blast regions instead of at `blit_cel`'s entry, giving a window between every *segment* rather than every
  *row*. `blit_fb_at_n.lua` exists and is work-keyed for its framebuffer check.
- **Confirm the rests directly** if ever needed: record the timer value the player programs for each segment
  and compare the actual gap against it. ★ *Not needed to proceed — the VBL rate already eliminates masking.*
- **Offer 25.3 on the hourglass sync.**
- Carried: P3.87's pace (the port's cutscene is 1.20× the oracle's); the 6-byte headroom; the disk's
  18-of-18 granules; the `LOADM` ceiling; `start_col` vs §2F.1(5); gameplay's colour mode; the per-cue
  control policy; the HAL audit; the stale `pop.link` stack comment; `Demo` unbuilt.

### 9 — User interaction during task

- Jay: ***"where is the hourglass drop sound in reference to the actual hourglass animation"*** — §3A.
- Jay: ***"yes do them in that order"*** — cause 2, then the narrower window.
- Jay: ***"yes it sounds late in the orcle too… I'd like to try and sync the landing of the hourglass with
  tis sound"*** — §3B.

### 10 — Candidate(s) captured this task

None new — §3D's two instrument errors are instances of
[[an-instrument-anchored-inside-the-interval-it-measures]] and
[[a-metric-whose-meaning-the-fix-changed]], both already captured this session. ★ *A third row restating them
would dilute the pool rather than add to it.*

### 11 — Commit

`088f7f7` (P4.32) and `b4d8160` (P4.34) — both pushed to origin/wip before this report.
