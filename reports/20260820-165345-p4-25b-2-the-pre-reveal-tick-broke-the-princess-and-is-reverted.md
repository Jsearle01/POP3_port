## Form B Report — P4.25b-2 — the pre-reveal tick broke the princess's animation; **reverted**

**Class:** build (net: a no-op).  wip.  **Prod restored** — `src/engine/cutscene_room.s` is **byte-identical**
to its state at `f37f709`; `introseq` prog 1,274 B and `scene` prog 1,251 B, unchanged from that commit.
Karateka untouched; `main` untouched (`34e93e0`).

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-20 16:53 (HEAD `c72bbf9`, wip). Working tree clean apart from the modified
`dist/mame-cfg/rgb/coco3.cfg` carried since P4.19 and the pre-existing untracked
`docs/ground-truth/*.pdf`, `nvram/`, `.vscode/`, `POP-idioms-coco3-markers.md`,
`content/intro/broderbund_splash_render.bin`.

### 1 — Summary

| | |
|---|---|
| **what was asked** | Jay chose **"delay the reveal past the cue"** to close the last 0.75 s |
| **what was built** | one `chars_frame` tick before `HAL_gfx_mirror`, so beat 0's song would fire while the room was still hidden |
| **★★ what it measured** | **45 → 38 frames. It did not collapse** — reported as not-done at the time |
| **★★★ what it actually did** | **advanced the animation cadence one step before the scene began.** Jay: ***"undo what you did it messed up the princesses animation"*** |
| **the mechanism** | `vm_due` is `fdb 0`; zero is not neutral to a `now >= due` test, it is **maximally overdue** (§3B) |
| **disposition** | **REVERTED** (`c72bbf9`). `cutscene_room.s` byte-identical to `f37f709`; timings measure back to **45 frames / +0.75 s exactly** |
| **suites** | **ALL PASS, 128 KB** |
| **Jay's gate** | **NOT OFFERED on the reverted build yet** — 25.3 still unrecorded (§5) |

**★★★ THE ONE FINDING WORTH KEEPING IS NOT THE BUG, IT IS THAT THE MEASUREMENT CONTAINED IT AND I READ IT AS
A DISAPPOINTING RESULT.** 45 → 38 frames is precisely the shape of *"consumed one animation step and shifted
the reveal."* The suites passed too. Jay's eye was the only instrument that saw it.

### 2 — Files modified

- `src/engine/cutscene_room.s` — **net zero.** `fe9b594` added 33 lines; `c72bbf9` removed the same 33.
  `git diff f37f709 HEAD -- src/engine/cutscene_room.s` is **empty**.

No other source, asset, tool or build input touched in this sub-arc.

### 3 — Reasoning

#### 3A — what was attempted, and why it looked right

P4.25b measured the cutscene's room appearing **45 frames (0.75 s) before its music**, and established that a
plain hold cannot close that: `unpack → savebg → mirror → present → loop → beat 0 → cue` is sequential, so a
delay anywhere before the cue moves the cue with it. Jay ruled for **moving the reveal past the cue**.

The implementation ran the scene loop's own per-frame call once, ahead of the mirror — verbatim from
`rl_draw` (frame count in `U`, buffer parity in `A`, draw base in `X`), with `cel_bank_map` ahead of it
because the characters draw from the cel bank and a 4-colour framebuffer ends at `$BBFF`, clear of the bank at
`$C000`.

**The premise was that `vm_due fdb 0` makes beat 0 due on the first ask, so one tick would fire the song.**

#### 3B — ★★★ WHY IT BROKE THE PRINCESS, AND THE COMMENT NEVER BECAME FALSE

`chars_frame` is **two phases** — the file says so itself: *"chars_frame is ALREADY the two phases the oracle
keeps distinct: `vm_nextframe` DECIDES and `vm_frameadv` DRAWS."*

The same paragraph carries the sentence I leaned on:

> *"That comparison is idempotent under being asked more often — calling it every 2-3 frames instead of every
> 6 steps the characters on exactly the same frames and simply draws them more often."*

**That claim is TRUE, and it is about a VM whose due-time a running loop has already established.** At scene
entry `vm_due` is `fdb 0` out of the bundle's image. **Zero is not a neutral starting value for a
`now >= due` comparison — it is the maximally-overdue one.** So the extra call found a step unconditionally
due, took it, advanced `cad_idx`, and stepped the princess's sequence once before the scene's loop ever ran.

**★★ THE COMMENT DID NOT GO STALE. ITS SCOPE WAS THE LOOP AND MY CALL SITE WAS OUTSIDE THE LOOP**, and
nothing in the sentence said so because its author had no reason to imagine a caller there. ★ *Re-reading it
after the failure confirms the wrong conclusion, which is what makes this worth a rule rather than a shrug.*

**Two checks would have caught it, both cheap, neither run:**
1. **Name the variable the claim rests on** — `vm_due` — and ask what it holds at the new call site.
2. **Ask what is different about my call site from the one I copied.** Every existing caller runs after at
   least one loop pass has set the due-time.

#### 3C — ★★ THE MEASUREMENT CONTAINED THE DEFECT

| | |
|---|---|
| before | reveal 5436, cue 5481, **delta 45** |
| after the tick | reveal 5439, cue 5477, **delta 38** |

**The reveal moved 3 frames LATER and the cue 4 frames EARLIER.** I reported that as "it did not collapse,
my premise was wrong" — which was true and incomplete. **A cue arriving earlier in absolute frames is exactly
what a consumed animation step produces**, and I had no reading of *why* the cue moved at all. ★ *I treated an
unexplained component of a measurement as noise around a disappointing headline.*

**The suites did not see it either, and that is expected rather than a gap to fix here:** `introseq` and
`integ` gate the scene's endpoints — that it is reached, returns, and reveals nothing half-built. **The
scene's PIXELS and its cadence are gated by Jay's eye alone**, which `run_suites.sh` states as the standing
consequence of the P4.2/P3.103 retirements.

#### 3D — §2H's three checks, applied to the revert rather than to a new mechanism

1. **A second mechanism?** ★ **Yes, and it is the one that bit.** `chars_frame` serves two object classes in
   one call — the VM's *decision* and the characters' *draw*. I reasoned about the decision half only.
2. **The calling routine.** `rl_draw` is the only caller, and its context — a loop that has already run — is
   the fact the copied lines depended on. **The enclosing routine was the fact, not the call.**
3. **Prior-report grep.** `P3.87` records the animation pace as **closed by Jay's decision, not by a fix**,
   with drift-free `vm_due` explicitly offered and refused. ★ *That report is about the same variable this
   change disturbed.* It is why §8 does not propose touching beat 0's application without a ruling.

### 4 — Verification (of the revert)

- **Source restored** — `git diff f37f709 HEAD -- src/engine/cutscene_room.s` is **empty**.
- **Build restored** — `introseq` prog 1,274 B (`$2000..$24F9`), `scene` prog 1,251 B (`$2500..$29E2`),
  `intro_seq.bin` 2,381 B: the `f37f709` figures.
- **Timing restored, measured** — reveal 5436, cue 5481, **delta 45 frames = +0.75 s**, identical to the
  pre-tick run.
- **Suites** — `ALL PASS` at 128 KB.
- **Disk** — every file byte-identical to its artefact.

### 5 — Verdict-time evidence (v0.7 §11)

```
c72bbf9 Revert "P4.25b-2: one beat tick before the reveal - measured 45 -> 38 frames, NOT the collapse expected"
 1 file changed, 33 deletions(-)
--- cutscene_room.s vs pre-tick state (empty = identical): ---
(empty above = identical)
```
```
#   file            on disk  artefact  verdict
# VERDICT: PASS - every file on the image matches its artefact.
=== BUILD COMPLETE ===
```
```
[suites] -ramsize 128K
[run_introseq_test] PASS
[integ] PASS
[suites] ALL PASS
```
```
  reveal   frame 5436
  cue      frame 5481   (song id 7)
  delta    45 frames = +0.75 s
```

**25.3 operator-runtime-smoke: PENDING JAY — and NOT offered on this build.** Jay observed the *defective*
build live (`run_introseq_live.sh`, live-disk, RGB, 128 KB, 100.00% speed, 128 s) and **rejected it by ear
and eye**: *"undo what you did it messed up the princesses animation."* **That is a recorded FAIL on
`fe9b594`, not a pass on `c72bbf9`.** The reverted build has not been in front of him. Nothing self-certified;
no window-closing has been treated as a verdict at any point in this session.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING. This sub-arc contains** the attempt, its measurement, Jay's rejection, and the revert.
**It contains no net source change.**

**★★ I PROPOSED THE ROUTE AND IT WAS WRONG, AND THE PROPOSAL IS WHERE THE ERROR ENTERED.** The option Jay
chose was presented by me as *"hold the finished room hidden until beat 0 fires"* with the note that it costs
*"same total wait; nothing touched in the scene's pacing."* **The second half of that was false** — running
the VM once IS touching the pacing, and I did not see it because I had reasoned about `vm_nextframe`'s gate
and not about `vm_frameadv` behind it. **Jay chose between two options one of which I had mis-costed.**

**★ ALSO CORRECTED HERE:** in offering the options I wrote that *"the first beat tick fires the cue."* That
was stated before measurement and is not true — `vb_apply` is not reached on the first `chars_frame` call.

**One process fault, recorded rather than tidied:** `fe9b594`'s commit message is garbled — a backtick inside
a double-quoted `git commit -m` ran as shell substitution and ate the phrase `vm_due fdb 0`. It is on `wip`
only. **Not fixed, because fixing it means a force-push**, which is destructive and was not authorised. This
is the same family as CLAUDE.md §2J's heredoc warning (`$` interpolation, CRLF delimiters) with a third
character; the safe form is a single-quoted heredoc, which §2J already prescribes for files.

### 7 — Uncertainty flags

- **★★ THE 0.75 s HAS NO ROUTE LEFT THAT I CAN TAKE UNILATERALLY.** The reveal end broke the animation. The
  cue end means changing when beat 0 applies, which is the scene's beat schedule — **P3.87, closed by Jay's
  decision.** Both ends now need his ruling.
- **What the 45 frames ARE is still not established.** They are ~13-19 loop passes at the torch cadence
  before `vb_apply` reaches beat 0; I have not traced *why* the VM needs that many. **Stating this rather
  than assuming it, because two premises about this VM have now been wrong in one session.**
- **Headroom to `SCENE_BASE` is 6 bytes**; the disk's file region is **18 of 18 granules**. Both are hard
  walls with checks in front of them, and both will present as blocked builds rather than silent corruption.
- **The `LOADM` ceiling remains unpinned** in the band this image occupies.

### 8 — Follow-up candidates

- **★★ THE LAST 0.75 s — Jay's ruling needed, and the honest framing has changed.** Of the two options I
  offered, one is now **disproven** (holding/ticking the reveal disturbs the animation) and the other
  (**fire beat 0's cue at the reveal**) touches the pace P3.87 settled. ★ *A third option exists and is the
  cheapest: accept it. `s_Princess` is +0.9 s against the oracle's 0.2 s and the other cues sit within
  ±1-2 s.*
- **Trace why beat 0 takes ~13-19 loop passes to apply.** That is the prerequisite for any route to the
  0.75 s, and it is recon, not a change.
- **Re-offer 25.3 on `c72bbf9`** so the princess can be confirmed correct again.
- Carried: the 6-byte headroom; the full granule region; pinning the `LOADM` ceiling; gameplay's colour mode;
  the per-cue control policy; the HAL audit; the stale `pop.link` stack comment; `Demo` unbuilt.

### 9 — User interaction during task

- Jay chose **"delay the reveal past the cue"** from the options offered — an option I had mis-costed (§6).
- Jay: ***"show me what it is currently"*** — the live gate was launched on the defective build.
- Jay: ***"undo what you did it messed up the princesses animation"*** — a recorded FAIL on `fe9b594`, and
  this revert.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-20-an-idempotence-claim-is-scoped-to-the-state-the-code-normally-runs-in.md`
— committed and pushed.

### 11 — Commit

`c72bbf9` (the revert; pushed to origin/wip before this report) + this report.
Sub-arc range: `fe9b594` (the attempt) → `c72bbf9` (the revert), net zero source change.
