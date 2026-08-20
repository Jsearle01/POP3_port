## Form B Report — P4.31 — the squeak moves before her turn; the residual dirt is **two causes, not one**

**Class:** build + recon.  wip.  Prod changed — one PLAN row reordered; content regenerated. **No `src/`
change.** Karateka untouched; `main` untouched (`34e93e0`).

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-20 19:02 (HEAD `9c7e4e0` at receipt, wip; `bfb72bd` at report). Tree clean apart from the modified
`dist/mame-cfg/rgb/coco3.cfg` carried since P4.19 and the pre-existing untracked files.

### 1 — Summary

**Jay, two asks in one message:**
> *"so the princess song still sounds dirty. can we clean that up or are we at a wall? also, even though the
> squeak sound matches the tiing of the oracle, can it be moved to before the princess turn , i feel like it
> would fit better."*

| | |
|---|---|
| **the squeak** | **MOVED. 16.4 s → 15.2 s**, before `Palert`. Scene length **identical**; no other cue moved |
| **its authority** | **a deliberate divergence, and §2I governs it** — no further defence needed (§3A) |
| **★★★ "are we at a wall?"** | **NO — and the residual is TWO causes, which a percentage was hiding** (§3B) |
| **cause 1** | **67.1% of deviations are ≤200 µs** — the blitter's one-row mask. The narrower window addresses it |
| **★★ cause 2** | **8.4% are OVER 1 ms, up to 6.7 ms.** No row-level mask can produce those |
| **what I did NOT do** | **name cause 2.** 144 events in 3 s ≈ 48/s is a lead, not a diagnosis (§3C) |
| **suites** | **ALL PASS, 128 KB, `integ` included** |
| **Jay's gate** | **OFFERED, run completed at 100.00% speed, 155 s. PENDING JAY.** |

### 2 — Files modified

- `harness/tools/bake_scene.py` — the `s_Squeek` row moved ahead of `("p","Palert",9)`.
- `harness/tools/pulse_jitter.lua` — reports deviations in **absolute microseconds** as well as percent.
- `content/cutscene/chars/` — regenerated.

### 3 — Reasoning

#### 3A — the squeak, and why this needs no fidelity argument

The oracle turns her **first** and squeaks the door **second** [`SUBS.S:673-681`]. Jay, having heard the
faithful order, asked for the reverse. **CLAUDE.md §2I settles the authority without further debate:**

> *"The mandate is that the port LOOKS right and FEELS right to play. It is not that the port works the way
> the oracle works… A divergence that preserves visual output and play feel is legitimate and needs no
> justification beyond measurement."*

★ *So this is recorded as a decision, not defended as a deviation, and §2.1 makes his ear the authority on
whether it worked.*

**It costs nothing structurally.** A `("song", …)` row is a **hold** — no `jumpseq` — so she goes on standing
through the 69 frames and `Palert` then turns her. **The row COUNT is unchanged**, so `SCENERY`'s keys do not
move and the scene's length is identical. Verified by loading the module and re-checking every key against
its beat name (True), not by eye.

| | before | after |
|---|---|---|
| `s_Squeek` | 16.4 s | **15.2 s** |
| scene length | 58.3 s | **58.3 s** |
| `s_Vizier` / `s_StTimer` | 19.5 / 50.5 s | **19.5 / 50.4 s** |

#### 3B — ★★★ THE PERCENTAGE WAS HIDING TWO CAUSES

**The tempting answer was "yes — narrow the blit window", and it is two thirds right.** What made me check
first: after P4.29 the blitter masks for **one row**, which at P3.19's measured 4.5-5.8 cy/byte is roughly
90-290 cycles = **50-160 µs** at 1.78 MHz. Against a 1743 µs note period that is 3-9%. **It cannot produce
19.3% of periods deviating by more than 25%.** So either my model of the masking was wrong, or something
else was in play.

`pulse_jitter.lua` reported only percentages, and **a percentage cannot tell a 100 µs delay from a 6 ms one**
— both read as ">25% off" at these periods. Re-expressed in absolute units:

```
   |delta| median      91.1 us
            90th      593.9 us
            99th     6048.8 us
            max      6715.4 us
   within 200 us (one masked row)   1153  (67.1%)
   over 1000 us (NOT the blitter)    144  (8.4%)
```

**★★ THE MEDIAN LANDS AT 91 µs — squarely inside the predicted one-row band.** That is the blitter, and it
is 67% of the events. **The 99th percentile is 6 ms**, which is 40× a masked row and cannot be one.

★ *Two failure modes had been summing into a single percentage for two dispatches. Splitting them changes
the plan: narrowing the blit window is worth doing and would leave the millisecond tail untouched.*

#### 3C — ★★ WHAT I DID NOT DO

**I did not name cause 2.** 144 events in 3.0 s is **~48/s**, which is near the frame rate and therefore
suggestive of something per-frame — the player's own per-tick decode in the pad path, or a masked region
outside the blitter. **Those are candidates I can list, not a diagnosis I can defend**, and this session has
already cost Jay two reverts from exactly this shape of confident inference (P4.25b-2's animation step,
P4.26's `vm_due`). The measurement to make it a finding is bounded and stated in §8.

★ *Stating the lead without asserting it is the whole of the difference between §7 and §3 here.*

#### 3D — §2H's three checks

1. **A second mechanism?** ★ **That is literally the finding** (§3B): there are two, and the reporting units
   were concealing one of them.
2. **The calling routine.** The 91 µs bulk belongs to `blit_cel`'s row loop; the millisecond tail belongs to
   *something that runs about once per frame*, which is a caller I have **not** yet identified — named as
   unknown rather than guessed.
3. **Prior-report grep** (`pulse_jitter|masked|blit_core|FIRQ`): P4.28, P4.29. **One correction to my own
   P4.29 §8**, which offered the narrower window as *"the most likely lever on 'still a bit crappy'"* — it is
   **a** lever, worth 67%, not the whole of it. Corrected here rather than left to be discovered later.

### 4 — Verification

- **The squeak moved and nothing else did** — cue table (§5); `SCENERY` keys re-verified against beat names.
- **The residual decomposed** — `pulse_jitter.lua` in absolute units (§3B).
- **Suites** — `ALL PASS` at 128 KB with `integ`. ★ *512 KB not run: no MMU, bank, framebuffer or loader
  change.*
- **Disk** — every file byte-identical to its artefact; the image was confirmed newer than every source
  before the gate was offered.

### 5 — Verdict-time evidence (v0.7 §11)

```
[suites] -ramsize 128K
[run_introseq_test] PASS
[integ] PASS
[suites] ALL PASS
```
```
# scene frames 5418..8913 = 58.3 s
  s_Princess      5451       0.6s       0.2s      +0.4s
  s_Squeek        6328      15.2s      14.1s      +1.1s
  s_Vizier        6585      19.5s      16.7s      +2.8s
  s_StTimer       8440      50.4s      42.7s      +7.7s
```
```
   within 200 us (one masked row)   1153  (67.1%)
   over 1000 us (NOT the blitter)    144  (8.4%)
```
```
# VERDICT: PASS - every file on the image matches its artefact.
```

**25.3 operator-runtime-smoke: PENDING JAY — live-disk, RGB, 128 KB, sound on, BY EAR AND EYE.** The run
completed at **100.00% speed, 155 s**. **A completed run is not a verdict and is not recorded as one.** Not
self-certified.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING. This commit contains** the squeak reorder and the absolute-units decomposition.

**It does NOT contain** either audio fix: not the narrower blit window (cause 1) and not any change aimed at
the millisecond tail (cause 2). ★ *Both were offered to Jay with the recommendation to diagnose cause 2
first, and neither was started under cover of the squeak change.*

**★★ AND IT CORRECTS A RECOMMENDATION I MADE ONE REPORT EARLIER** (§3D.3): P4.29 §8 called the narrower
window *"the most likely lever"* on the audio. It is worth **67%**, not all of it, and I would have found
that out by doing it rather than by measuring first.

### 7 — Uncertainty flags

- **★★ CAUSE 2 IS UNIDENTIFIED.** ~48 events/s, up to 6.7 ms each. Near the frame rate. **Not diagnosed.**
- **The two causes may not be independent** — a FIRQ delayed by a millisecond arrives to find its timer
  reload late, which could inflate the following intervals too. The 67/8 split is a split of *events*, not
  necessarily of *blame*.
- **The squeak's 69-frame hold is unchanged.** If the reorder reads as her being slow to react rather than
  reacting *to* the sound, the lever is the hold's LENGTH, not its position.
- **The audio quality is still Jay's *"dirty"***; this dispatch changed nothing about it.

### 8 — Follow-up candidates

- **★★★ DIAGNOSE CAUSE 2 FIRST — recommended.** Bounded and non-destructive: tap the DAC and record what
  else is executing across each >1 ms gap (the room loop's phase, whether a VBL IRQ was taken, whether the
  player was in its pad path). ★ *Doing this before the blitter change matters: if the millisecond tail is
  the player itself, the narrower window buys less than P4.29 §8 implied, and it would be learned by
  restructuring the port's hottest code rather than by a measurement.*
- **★★ THE NARROWER BLIT WINDOW (cause 1, 67%)** — mask only the two blast regions instead of at
  `blit_cel`'s entry. Evidenced at P4.29 §8 and re-sized here. Needs its own framebuffer byte-diff
  (`blit_fb_at_n.lua` exists and is work-keyed for exactly this).
- **P3.87's pace, still open** — the port's cutscene is 1.20× the oracle's (P4.30 §3E).
- Carried: the 6-byte headroom; the disk's 18-of-18 granules; the `LOADM` ceiling; `start_col` as a cel
  comment vs §2F.1(5); gameplay's colour mode; the per-cue control policy; the HAL audit; the stale
  `pop.link` stack comment; `Demo` unbuilt.

### 9 — User interaction during task

- Jay: ***"so the princess song still sounds dirty. can we clean that up or are we at a wall? also … can it
  be moved to before the princess turn"*** — both addressed: the move done, the wall question answered with
  a decomposition rather than a yes/no.
- Jay: ***"show me the port with the squeak change"*** — launched; disk verified current first.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-20-a-normalised-metric-can-hide-two-causes.md` — committed and pushed.

### 11 — Commit

`bfb72bd` (pushed to origin/wip before this report) + this report.
