## Form B Report — P4.26b (recon) — **the oracle plays it TWO plays in, not seven**

**Class:** recon.  wip.  **Prod unchanged — no `src/`, no asset, no build input touched.** One new harness
tool, one idioms entry. Karateka untouched; `main` untouched (`34e93e0`); oracle disk and source read-only.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-20 19:00 (HEAD `6a7b954`, wip). Tree clean apart from the modified `dist/mame-cfg/rgb/coco3.cfg`
carried since P4.19 and the pre-existing untracked files. Oracle `.hdv` mounted from a **scratch copy**;
the reference image untouched.

### 1 — Summary

**★★★ THE ANSWER IS NO, AND IT REVERSES MY OWN RECOMMENDATION.** P4.26 §8 offered "accept it — it is beat 0
playing" as the recommended route, on the reading that the port was probably faithful. **It is not.**

| | |
|---|---|
| **the question** | does the oracle also hold `Pstand` for **seven** plays before `s_Princess`? |
| **★★★ measured** | **NO — it holds TWO.** Oracle: **arm → cue = 10 frames (0.17 s)** |
| **the port** | **45 frames (0.75 s)** |
| **★★ the source agrees** | `PlayCut0`: `lda #2 / jsr play` → `PlaySongI` → `lda #5 / jsr play` (§3B) |
| **★★★ the cause** | the port's PLAN **merged the oracle's `play 2` and `play 5` into one 7-play beat** and put the cue after both (§3C) |
| **and the PLAN says so** | its own comment: *"play 2 + play 5, both standing … **with the cue between them**"* |
| **NOT the cause** | the loading (P4.25b closed that), beat 0's existence, or P3.87's pace |

**★ The port's step rate is very nearly right.** Oracle 2 plays in 10 frames = **5.0 f/play**; the port's
`cad_tab` is a flat **6**. The 35-frame error is **five plays of position**, not a rate error.

### 2 — Files modified

- `harness/tools/oracle_pstand_lead.lua` — **NEW.** The oracle's `PlayCut0`-relative lead-in.
- `mame-idioms-apple2e-oracle.md` — **§0a NEW:** `-state` and `-autoboot_script` do not compose (§3D).

**No engine source, no PLAN, no asset changed.** This was a recon dispatch and stayed one.

### 3 — Reasoning

#### 3A — ★★★ THE MEASUREMENT

Anchored on `PlayCut0`'s own marker — a **write** of 12 to `SPEED` (`$030C`), which is the same anchor
P4.23's oracle column used, so the numbers are directly comparable:

```
# --- hires page-select touches ($C054/$C055) ---------------------
  frame     5   page 1  (read)
  frame    10   page 2  (read)
#
# --- song cues ($031A read, id in Y) -----------------------------
  frame    10   s_Princess    (Y= 7, PC=$E479)
  frame    11   id 100        (Y=100, PC=$0CAE)
  ...
# --- PC histogram for the $031A tap (unfiltered) -----------------
#   $E479  x1
#   $0CAE  x292
#
  ORACLE  arm -> s_Princess = 10 frames = 0.17 s
  PORT    room revealed -> s_Princess = 45 frames = 0.75 s
```

**★★ THE HISTOGRAM IS THE CHECK, AND IT DID ITS JOB.** `$031A` has other readers, so the instrument reports
every PC rather than filtering silently. **`$E479` fired exactly once** — the real `PlaySongI`, with `Y=7`.
`$0CAE` fired **292 times** with `Y=100`/`255` every 2-3 frames: that is the play loop, not a song start. ★ *A
filter you cannot see is a filter you cannot check; here the two populations are unmistakable.*

**★ AND THE PAGE FLIP LANDS ON THE SAME FRAME AS THE CUE.** `$C055` (page 2) at frame 10, `s_Princess` at
frame 10. **In the oracle the picture and the music arrive together** — which is exactly the thing Jay has
been reporting as wrong in the port, stated as a positive measurement rather than as an impression.

#### 3B — ★★ THE SOURCE SAYS THE SAME THING, INDEPENDENTLY

`oracle/source/01 POP Source/Source/SUBS.S:658`:

```
PlayCut0
 jsr startV0
 jsr SaveKid
 jsr startP0 ;put chars in starting posn
 jsr SaveShad

 lda #2
 jsr play ;animate 2 frames        <- TWO plays
 lda #s_Princess
 ldx #8
 jsr PlaySongI                     <- the cue
 lda #5
 jsr play                          <- then FIVE more
```

**Two authorities, independently, agreeing:** the trace (tier 2) puts the cue at frame 10, and the source
(tier 3) puts it after `play 2`. At the measured 5 f/play, `play 2` **is** ~10 frames. ★ *Trace wins on fact
and source wins on intent; here they say the same thing, which is the strongest position §2 allows.*

#### 3C — ★★★ THE CAUSE, AND THE PLAN'S OWN COMMENT ALREADY KNEW

```python
PLAN = [("p", "Pstand", 7),       # play 2 + play 5, both standing [SUBS.S:665-672]
        ("song", "s_Princess", 761),   # ...with the cue between them; she waits
```
[`harness/tools/bake_scene.py:245`]

**The two runs were merged into one 7-play beat** — visually identical, since both are `Pstand` — and
`song_at()` reads the cue off the **next** PLAN row, so the cue landed after all seven plays instead of after
two. `cel_plan.s` emits exactly that: `beat 0 Pstand plays 7` with song byte `0`, `beat 1 s_Princess`.

**★★ THE MERGE IS HAND-AUTHORED, NOT AN AUTOMATIC COLLAPSE**, and the comment on the very next line says
where the cue belongs: ***"with the cue between them."*** The prose was right and the tuple was not. ★ *This
is the project's recurring shape once more — a description standing next to a fact that contradicts it, and
only the fact is executable.*

#### 3D — the instrument, and a MAME idiom that cost the first two runs

**`-state` and `-autoboot_script` do not compose.** With `-state princess` the script **does not run at all**
— no log, nothing on stderr, **exit 0**; the identical command without it runs fine and installs every tap.
Isolated with a three-line probe rather than by guessing. Filed as **§0a** in the oracle idioms file.

★ **The save state buys almost nothing anyway:** booting to `PlayCut0` is ~45 s emulated, which is **~4 s of
wall clock** at the 1437% this run measured. The tool boots and arms.

**★★ AND IT ARMS ON THE WRITE, NOT THE VALUE** — `oracle_scene.lua`'s own `demo` entry records why (a
value-wait once fired at frame 8 on uninitialised RAM and reported PASS from a machine that had not booted).
Its `princess` entry still waits on a value; this tool does not.

#### 3E — §2H's three checks

1. **A second mechanism?** ★ **Yes, and it is why the port looks nearly right.** Two things set the cue's
   position: **which PLAN row carries it** (the defect) and **`cad_tab`'s frames-per-play** (fine — 6 against
   the oracle's measured 5.0). Had I checked only the rate I would have concluded the port was faithful.
2. **The calling routine.** The cue is emitted by `song_at(bi)`, whose caller is the PLAN walk — **so the
   fact lives in the PLAN tuple, not in `song_at`.** Naming `song_at` would have pointed at correct code.
3. **Prior-report grep** (`PlayCut0|Pstand|s_Princess|PLAN`): P3.78, P4.7, P4.9, P4.23, P4.26. **One
   correction to my own P4.26:** its §8 called route 2 *"decouples the cue from the beat the oracle put it
   on, which is exactly the drift P4.23 built the plan-derived cue to prevent."* **Backwards.** Moving the
   cue earlier **restores** a boundary the PLAN collapsed; the current position **is** the drift.

### 4 — Verification (against the dispatch's ask)

- **"Re-measure the oracle's own `Pstand`"** — **★★★ DONE.** 10 frames to the cue, from two independent
  authorities (§3A trace, §3B source).
- **Which route the answer selects** — **route 1 (accept) is WITHDRAWN.** The port is not faithful here.
- **Suites** — **NOT RE-RUN, deliberately:** no build input touched. Last green at `c72bbf9`, `ALL PASS`
  with `integ`, 128 KB and 512 KB.
- **Oracle disk integrity** — mounted from `build/oracle_pstand.hdv`, a scratch copy; the reference
  `oracle/source/PrinceOfPersia_3.5.hdv` was not the mount target.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output, verbatim** — `harness/tools/oracle_pstand_lead.lua`, `apple2e`, headless:

```
  frame    10   page 2  (read)
  frame    10   s_Princess    (Y= 7, PC=$E479)
#   $E479  x1
#   $0CAE  x292
  ORACLE  arm -> s_Princess = 10 frames = 0.17 s
  PORT    room revealed -> s_Princess = 45 frames = 0.75 s  (reveal_vs_cue.lua)
  PORT    beat 0 = Pstand x7 plays at cad_tab 6 = 42 frames by construction
# READS AS: the oracle's lead is SHORTER than the port's.
```
```
Average speed: 1437.63% (56 seconds)
```

**25.2 bundled-artifact grep:** N/A — no sibling-import artifact.

**25.3 operator-runtime-smoke: N/A — nothing changed to observe.** The last recorded operator verdict
remains the **FAIL on `fe9b594`**, reverted at `c72bbf9`; the reverted build has still not been in front of
Jay.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING. This report contains** the measurement, its independent confirmation from the oracle
source, the located cause, and the idiom. **It contains no code, PLAN or asset change** — the dispatch asked
for recon and this stayed recon.

**★★ AND IT WITHDRAWS MY OWN RECOMMENDATION FROM ONE REPORT EARLIER.** P4.26 §8 recommended **accepting**
the 0.75 s as the scene's first beat playing, and reasoned that moving the cue would introduce drift. **Both
halves were wrong**, and one grep of `SUBS.S` — the same file P4.26 was already citing for `cel_plan`'s
provenance — would have shown it. ★ *P4.26's own captured lesson was "a flagged unknown one file away from
being known"; this is the second instance in two dispatches and it is the same file.*

### 7 — Uncertainty flags

- **★★ I HAVE NOT SPECIFIED THE PLAN EDIT, AND DELIBERATELY NOT.** The obvious form is to split
  `("p","Pstand",7)` into a 2-play row and a 5-play row with the `("song","s_Princess",761)` row between.
  **But the song row is itself a beat with a 761-frame hold** (`cel_plan.s` renders it `plays 109`), so
  whether the trailing `play 5` is already absorbed into that hold, or needs its own row, decides whether
  the edit is one line or three. **Getting that wrong shifts every later beat**, and the scenery-flag
  indices are asserted against PLAN positions. It needs the PLAN walk read properly, not a guess.
- **The oracle's 5.0 f/play is from ONE interval** (2 plays, 10 frames). It is enough to show the port's
  `cad_tab` 6 is not the cause of a 35-frame error; it is **not** a re-measurement of the pace, and P3.87
  stands untouched.
- **`vm_nextframe`'s comment still says "the 3,3,2,3,2 cycle"** against a flat-6 `cad_tab` (carried from
  P4.26 §7 — Orchestrator's text, §2D).

### 8 — Follow-up candidates

- **★★★ THE FIX, AND IT IS NOW A FIDELITY DEFECT WITH A NAMED CAUSE RATHER THAN A PREFERENCE:** split the
  merged `Pstand` beat in `bake_scene.py`'s PLAN so the cue falls where `PlayCut0` puts it — after two
  plays. **Expected result: the cue moves from ~45 frames to ~12-18**, against the oracle's 10. ★ *Needs
  §7's question answered first, and it regenerates `cel_plan.s`/`cel_pages.s`, so it is a content-pipeline
  task with a render-neutral gate, not a one-liner.*
- **Check the other cues for the same merge.** `s_Vizier` and `s_Buildup` sit on `("song", …)` rows the same
  way; `cue_times.lua` puts them at **−1.0 s** and **−0.7 s** — *early* — which is the opposite sign and may
  be the same class of boundary error in the other direction. **One grep of `SUBS.S` per cue.**
- **Re-offer 25.3 on `c72bbf9`** so the princess can be confirmed correct again.
- Carried: the 6-byte headroom; the full granule region; the `LOADM` ceiling; gameplay's colour mode; the
  per-cue control policy; the HAL audit; the stale `pop.link` stack comment; `Demo` unbuilt.

### 9 — User interaction during task

- Jay: ***"do the recon"*** — this dispatch.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-20-the-comment-said-between-them-and-the-tuple-said-after.md` — committed and pushed.

### 11 — Commit

This report + the tool and idioms entry. **No engine change — nothing in `src/` was touched.**
