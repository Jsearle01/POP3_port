## Form B Report — P4.25b — *"still too late"* was right; the marker was **inside** the stall

**Class:** build.  wip.  Prod changed — `INTROSEQ.BIN` 2,362 → 2,381 B; scene program 1,196 → 1,251 B;
**`ROOM.BIN` removed from the disk image** (§3D). Karateka untouched; `main` untouched (`34e93e0`).

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-20 06:45 (HEAD `e70915a` at receipt, wip; `9fe4d75` + this report at report). Tree clean apart
from the pre-existing untracked `docs/ground-truth/*.pdf`, `nvram/`, `.vscode/`,
`POP-idioms-coco3-markers.md`, `content/intro/broderbund_splash_render.bin` and the modified
`dist/mame-cfg/rgb/coco3.cfg` carried since P4.19.

### 1 — Summary

| | |
|---|---|
| **Jay's verdict on P4.25** | ***"still too late"*** — **and correct against a number that said +2.4 s** |
| **★★★ why** | **the instrument's anchor was INSIDE the interval.** The real stall was **6.4 s**, not 2.4 |
| **the fix** | **all three pre-scene reads moved to the top of beat 4** (§3B) |
| **★★ measured now** | **`s_Princess` +0.9 s** (from +12.4, via +2.4). Vizier −1.0, Buildup −0.7, Magic +2.0 |
| **scene marker → cue** | **63 frames = 1.05 s, all CPU, zero disk** |
| **★★★ a silent disk fault** | **`ROOM.BIN` was being overwritten by a raw asset track and shipped corrupt** (§3D) |
| **suites** | **ALL PASS 128 KB and 512 KB**; framebuffer still **0 / 32,256** across the MMU borrow |
| **Jay's question** | *"can we delay the scene start for that second?"* — **measured, and it would not close it** (§3E) |

### 2 — Files modified

- `src/engine/intro_seq.s` — the scene-program read moves out of `run_scene` to the top of beat 4, with the
  `room_preload` call; `run_scene` now gates on `SCENE_SIG`.
- `src/engine/cutscene_room.s` — new `room_preload` entry (+E, offset asserted); `room_preloaded`;
  `rs_pre_ok` receipt; two guards in `room_start`.
- `build.bat` — `ROOM.BIN` no longer placed on the image; the read-back check runs on every build.
- `harness/tools/disk_file_readback_check.py` — **NEW.** Every DECB file vs. its artefact.
- `harness/tools/reveal_vs_cue.lua` — **NEW.** Picture against music, to answer §3E.
- `harness/smoke/run_introseq_live.sh` — its banner's disk figures re-measured (they were two dispatches stale).

### 3 — Reasoning

#### 3A — ★★★ THE INSTRUMENT WAS ANCHORED INSIDE THE THING IT WAS MEASURING

`cue_times.lua` reports each cue against the scene's start, and takes that start from the frame
`cel_scene_done` goes to zero. **The scene clears it in `cel_load_startup`** — which runs *after* the flame
bundle has been read and expanded. The disk trace, whose anchor is the controller rather than the scene:

```
frame 5120   -3.84s   track 24 -> $2500    the SCENE PROGRAM     1.9 s
frame 5237   -1.89s   track 30 -> $5800    the FLAME BUNDLE      1.9 s   <- the marker opens HERE
frame 5350   +0.00s   track 29 -> $5800    the ROOM BLOB         1.8 s
frame 5504   +2.57s   ★ CUE s_Princess           unpack+mirror  ~0.8 s
```

**Frames 5120..5504 = 6.4 s.** The tool reported the last 2.6 s of it.

**★★ WHAT MADE THIS SURVIVE TWO ROUNDS OF WORK IS THAT THE NUMBER MOVED CORRECTLY.** It was not noise: it
was an accurate measurement of a strictly smaller interval, it was reproducible, and it *improved when the
tail improved* — which is exactly the signal one would use to confirm an instrument works. Nothing in the
numbers ever contradicted it. **Jay's ear did.** ★ *The operator's complaint was data about the instrument,
not only about the system, and the cheap move at that moment — cheaper than another round of optimisation —
was to ask what the number could not see.*

**★ THIRD INSTRUMENT FAULT IN THREE DISPATCHES ON THIS SUBSYSTEM, and they form a severity ladder:** P4.23's
read-tap **announced itself** (198 cues at one frame); P4.24's parameter-block tap was **plausible and
wrong** and survived a dispatch; this one was **plausible, correct and responsive**, which is the expensive
kind. Captured (§10).

#### 3B — THE FIX: all three reads to the top of beat 4

**The scene runs at the end of beat 4, so beat 4's top is the last point before it — and the first point at
which everything the reads need is free.** Three conditions become true together only there:

| | |
|---|---|
| **the captions are dead** | beat 3 was the last to patch one; beat 6's copy comes from `run_scene`'s post-scene reload, which the intro does anyway. So `bundle_expand` may write `$3000..$4883` here. |
| **`SAVE_BUF` is free** | the TITLE patch's 5,361 B (`$5400..$68F1`) are repaired at the end of beat 3. **This is what P4.25 §3D said blocked the room blob** — it does not block it *here*. |
| **`$5800` can serve twice** | packed bundle lands, expands to `$3000`, blob lands on what it vacated — the same two-step `room_start` always did, performed earlier. |

**And the stall it lands in already exists:** beat 4's own picture read runs at the same point, against beat
3's cleared title screen, before beat 4's music.

**`room_preload` (+E), the new scene entry.** Its offset is asserted against its own label at build time,
exactly as `room_call`'s is — the two units never link together, so the shared number is checked rather than
trusted. It takes no arguments and returns nothing: **a failure leaves the receipt clear and `room_start`
does the reads itself, which is precisely the pre-P4.25b behaviour**, so no caller needs an error path.

**★★ THE RECEIPT IS AN `fdb` INSIDE THE SCENE'S OWN DISK IMAGE, and that is the safety argument.**
`cel_load_startup`'s comment records what the constant page costs: `$FE02+` is ordinary power-on RAM that no
image initialises, which is why four bytes there have to be cleared by hand. `rs_pre_ok` is part of the
program that gets read from disk, so **the read that places it initialises it.** A 16-bit magic rather than
a flag, for the same reason the cel guard uses one.

#### 3C — the measurement after

| cue | P4.23 | P4.25 | **P4.25b** | oracle |
|---|---|---|---|---|
| `s_Princess` | +12.4 s | +2.4 s | **+0.9 s** | 0.2 s |
| `s_Vizier` | +10.5 s | +0.5 s | **−1.0 s** | 16.7 s |
| `s_Buildup` | +10.8 s | +0.8 s | **−0.7 s** | 26.3 s |
| `s_Magic` | +13.1 s | +3.1 s | **+2.0 s** | 34.9 s |

**★ The offsets are scattered about zero now instead of all late.** That is the signature of a systematic
fault removed: what remains is per-cue scheduling, which is the scene's own pacing and is the thing Jay
settled at P3.87.

**And the disk is gone from the interval entirely** — the trace shows the last read completing 14.9 s before
the scene marker (beat 4 plays its wipe and hold in between) and **no read at all** between there and the
cue.

#### 3D — ★★★ THE BUILD WAS SHIPPING A CORRUPT FILE, AND NOTHING SAID SO

`ROOM.BIN` grew past a granule boundary at this dispatch and landed on **granules 18,19 = track 9**, which is
`prolog1.lz`'s raw span. `raw_tracks.py` wrote the asset over it afterwards.

- **`imgtool put` returned 0.**
- **The directory listing showed a plausible size** (2,102 B).
- **`imgtool get` returned 2,102 bytes of packed screen beginning `78 00 13 48`** — not even a DECB header.

**★★ MOVING THE PUT AFTER THE RESERVATIONS DID NOT FIX IT, AND THAT IS A CORRECTION TO A TOOL'S OWN CLAIM.**
`raw_tracks.py`'s header says reserving granules means *"DECB never allocates over them"*. **imgtool's
allocator does not skip `$C9`** — the read-back check found the file on 18,19 again. The claim is about DECB,
not about imgtool, and it had never been exercised at the boundary because no file had ever reached it.

**So the file SET is the problem and it is arithmetic:** `PROBE 1 + MODE 1 + ANIM 1 + INTRO 13 + INTROSEQ 2 =
18 granules = tracks 0..8`, and the first raw asset track is 9 = granules 18,19. The set needs 20 where 18
exist; **which file overflows is arbitrary.**

**`ROOM.BIN` is the one dropped**, on Jay's own prior ruling: it boots the standalone room whose suites were
retired at P3.103 (*"walk and room should be deprecated anyway. they have been gated in the intro sequence"*),
`integ_test.lua`'s own header records that the integrated scene is reached by a `jsr` and not by
`LOADM"ROOM"`, and it was the **last** put — so P3.103's caution that removing a file "moves the tracks" does
not apply. `build/cutscene_room.bin` is still built and still map-checked.

**`harness/tools/disk_file_readback_check.py` now runs on every build and BLOCKS it.** It compares bytes,
not exit codes, because the exit code was 0 for the corrupt file. **`INTROSEQ.BIN` verified byte-identical on
the image.**

#### 3E — ★★ JAY'S QUESTION: *"can we delay the scene start for that second?"* — MEASURED, AND NO

**First, the premise is right: the picture and the music ARE apart.** `harness/tools/reveal_vs_cue.lua`:

```
  reveal   frame 5436      (the scene's own probe_status := 2, just after room_present)
  cue      frame 5481      (song id 7)
  delta    45 frames = +0.75 s
```

**But a delay cannot close it, because the chain is sequential:**

```
unpack -> savebg -> HAL_gfx_mirror (THE PICTURE APPEARS) -> present -> room_ready -> room_loop -> beat 0 -> CUE
```

**Every one of those is downstream of the last, so a hold inserted anywhere before the cue delays the cue by
the same amount.** The picture and the music move together and the 0.75 s survives intact — the viewer just
waits longer for both. ★ *To close the gap the two ends have to move toward each other, not the whole chain
backward.*

**§2H checks on this conclusion.** (1) *A second mechanism?* Yes — the reveal is `HAL_gfx_mirror`, not
`room_present`; the file's own comment says the mirror *"writes the finished room into the FRONT buffer,
which is the DISPLAYED one — so the picture appears at the mirror, not at the swap."* The instrument
therefore anchors on `probe_status:=2`, which is **later** than the true reveal, so the measured 0.75 s is
the **conservative end** and the real gap is larger. (2) *The calling routine:* the cue is fired by
`vb_apply` in the flame bundle when a beat is applied, not by the room — so the 45 frames are the scene's
first character-due tick, not room set-up. (3) *Prior-report grep:* P3.87 settled the scene's pacing by Jay's
decision, and `vm_due` was explicitly offered and refused — **which is why §8 does not propose touching it.**

### 4 — Verification

- **The stall is measured from outside the system under test** — `disk_dest_trace.lua`, whose anchor is the
  disk controller. 6.4 s before, and the three reads named.
- **The reads moved** — trace: all three at −22.7 s to −17.5 s (beat 4's top), **no read between −14.9 s and
  the scene**.
- **The cue** — `+0.9 s` (§3C, verbatim below).
- **The framebuffer** — still **0 of 32,256 bytes** differ across the MMU borrow.
- **Suites** — `ALL PASS` at 128 KB, and at 512 KB.
- **The disk** — every file byte-identical to its artefact (§5).

### 5 — Verdict-time evidence (v0.7 §11)

```
#   file            on disk  artefact  verdict
  PROBE.BIN            1256      1256  ok
  MODE.BIN             1319      1319  ok
  ANIM.BIN             1438      1438  ok
  INTRO.BIN           28132     28132  ok
  INTROSEQ.BIN         2381      2381  ok
# VERDICT: PASS - every file on the image matches its artefact.
[map_check] 5 map(s) clean — no overlap, nothing below $0E00.
=== BUILD COMPLETE ===
```
```
[suites] -ramsize 128K      [run_introseq_test] PASS   [integ] PASS   ALL PASS
[suites] -ramsize 512K      [run_introseq_test] PASS   [integ] PASS   ALL PASS
```
```
# song           frame       port     oracle      delta
  s_Princess      5481       1.1s       0.2s      +0.9s
  s_Vizier        6358      15.7s      16.7s      -1.0s
  s_Buildup       6951      25.6s      26.3s      -0.7s
  s_Magic         7627      36.9s      34.9s      +2.0s
```
```
# VERDICT: PASS -- the framebuffer is byte-identical across the borrow.
  bytes differing            0
```

**25.3 operator-runtime-smoke: PENDING JAY — live-disk, RGB, 128 KB, by EAR and EYE.** The runner was
launched twice at Jay's request and ran at 100.00% speed (135 s, then 180 s). **A window closing is not a
verdict and is not recorded as one.** Not self-certified.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING. This commit contains** the three-read move to beat 4 with the `room_preload` entry and
its receipt, the re-measurement from an external anchor, the disk read-back check, the `ROOM.BIN` removal,
and the reveal-vs-cue measurement that answers Jay's question.

**It does NOT contain** any change to the scene's beat pacing or to `vm_due` (P3.87 — settled by Jay), and it
does **not** contain the delay Jay asked about, because the measurement says it would not close the gap
(§3E). ★ *That is a proposal declined on evidence, not a scope reduction — the alternatives are in §8 and the
choice is his.*

**★★ TWO THINGS HERE WERE NOT ASKED FOR AND BOTH ARE STATED RATHER THAN SLIPPED IN:** the `ROOM.BIN` removal
(§3D — a corrupt artefact was shipping, and the alternative was a blocked build) and the read-back check that
found it.

### 7 — Uncertainty flags

- **★★★ HEADROOM TO `SCENE_BASE` IS 6 BYTES.** `intro_seq.s`'s prog ends `$24F9`; the scene program is read
  to `$2500`. **The intro sequencer is full.** The next addition needs the scene's load address revisited
  first — that is `link/pop_scene.link`, and it is a task, not a tweak.
- **★★ THE DISK'S FILE REGION IS ALSO FULL** — 18 of 18 granules before track 9, zero margin. `INTROSEQ.BIN`
  has 2,227 B before it takes a third granule and busts it. The read-back check now catches this rather than
  shipping it, but it will present as a **blocked build**.
- **The `LOADM` ceiling is still unpinned** in the band this image occupies (`link/pop_engine.link` brackets
  it as *"prog ending `$2487` boots; `$2535` image corrupted"*; this build ends `$24F9`). It boots and both
  suites pass at both RAM sizes.
- **The remaining 1.05 s is CPU**, and `reveal_vs_cue.lua` measures its picture/music split from a
  conservative anchor (§3E) — the true reveal is earlier, so the 0.75 s is a floor.

### 8 — Follow-up candidates

- **★★ CLOSING THE LAST 0.75 s — Jay's call, two routes, and the second is the one I would take.**
  (a) *Delay the reveal past the cue* — hold the finished room hidden until beat 0 fires. Adds 0.75 s of
  stale prolog1 and keeps the silence. (b) **Fire beat 0's cue at the reveal instead**, so the music starts
  with the picture — this removes the silence rather than hiding it. The 45 frames are the scene's first
  character-due tick (§3E check 2), so (b) means touching when the first beat applies. ★ *P3.87 settled the
  scene's PACE by your decision, and I have not touched it; the initial tick is arguably a different
  question, but it is adjacent enough that it is yours to rule on.*
- **The 6-byte headroom and the full granule region.** Both are now hard walls with checks in front of them.
- **Pin the `LOADM` ceiling.** It has bounded three dispatches from a two-sample bracket.

### 9 — User interaction during task

- Jay: ***"run it for me"*** — the live gate was launched (twice, once per build).
- Jay: ***"still too late"*** — the finding in §3A, and this dispatch.
- Jay: ***"can we dely the scene start for that second?"*** — measured and answered in §3E; not implemented,
  with the reason and the alternatives.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-20-an-instrument-anchored-inside-the-interval-it-measures.md` — committed and pushed.

### 11 — Commit

`9fe4d75` (code, pushed to origin/wip before this report) + this report.
