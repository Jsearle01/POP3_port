## Form B Report — P3.72l–n — the songs land and gate; the remaining beats do not fit
**Class:** build + recon. wip. Prod untouched. **25.3 GATED — Jay, verbatim: "that looks awesome".**

### 0 — Receipt / status (C-35 stamp)
Continues `20260810-224500-p3-72d-to-k-the-scene-gated.md`. HEAD `9a9724f`, wip, three commits
since `f3cc73d`. Sync bridge OK. Karateka and `main` untouched. Tree green and stable (§4).

---

### 1 — Summary

**The two song stubs are in and the scene gated.** Jay, live-disk, RGB, 100% speed:
**"that looks awesome"**. Not self-certified.

**Then the recon stopped the next beat before it was built.** Jay asked for the remaining
beats one at a time — recon, build, verify, visual. The recon says the first of them is
**7,188 B over the bank**, and the full arc is **2.6× it**. Nothing was built on that.

**And it retired advice I had given twice** (§3D): `shift_row.s` is no longer the answer,
because the fix Jay suggested at P3.72j removed the phase duplication it would have
collapsed.

| | |
|---|---|
| her opening hold | **811 frames** vs the oracle's 799 (1.5%) |
| his entrance stop | measured off the same trace, 358-frame cue |
| remaining beats | **~41,437 B** against a 15,872 B bank — **over by 25,565** |
| a runtime mirror | **~3,080 cy/cel**, returns **~4,175 B** — 16% of the shortfall |

---

### 2 — Files modified

- **`1182b36`** — the two song stubs: `harness/tools/bake_scene.py` (a `("song", id, frames)`
  PLAN entry and `expand()`), `harness/smoke/walk_test.lua` (arm on first movement),
  regenerated `content/cutscene/chars/{cel_image,walk_scripts}.s`.
- **`814cd30`** — `bake_scene.py`: the remaining-beats cost recorded where the scene's budget
  facts live. No functional change.
- **`9a9724f`** — `reports/20260810-233000-p3-72n-runtime-mirror-cost.md`, the mirror recon.

### 3 — Reasoning

**3A — The songs are beats, not silence.** `PlaySongI` BLOCKS while the music plays
[SUBS.S:822-842] and contains no wait instruction, so stubbing the two cues to silence did
not remove sound — it removed two beats. Durations are **trace-measured**, because P3.52
established the oracle's `X` operand is only the sound-OFF fallback:

```
s_Princess  room f2688 -> her turn f3487 = 799 frames, less ~38 of plays  -> 761
s_Vizier    his last cel change f3676 -> first on resuming f4064 = 388,
            less 30 of held plays                                        -> 358
```

The oracle's own `X` values here are 8 and 12 — neither is either number.

**3B — The intro's `play_song` could not be reused, exactly as its own comment predicted.**
*"IT WAITS RATHER THAN ANIMATING ... the things the oracle's song loop drives — pburn,
pstars, pflow — are the PRINCESS ROOM's torches ... If a beat ever gains a live element, it
is driven from here."* This is that beat: the torches must keep flickering through both
cues. A no-jump hold does that already — characters frozen, `room_loop` still flickering and
swapping — so the song's **body is the hold**, and the duration lives in the PLAN once with
the holds derived by `expand()`. Nothing hand-written beside a call for anyone to remember
to delete when sound lands (P3.52's property).

**3C — Two things measurement caught, both mine.**

**The divisor.** Converting frames→plays at `cad_tab`'s 6 made the opening 17% long. Since
P3.72k the loop samples `vm_nextframe` at the *flame* rate, and it re-bases as `now + count`,
so `now` is systematically late and a play costs ~7 frames. Measured on the machine: **937
frames over 134 plays = 6.99.** At 7 the opening is 811 against the oracle's 799.

**★ The walk suite went vacuous.** It armed on the room coming up — which *used* to be the
instant the scene began moving. With a 761-frame opening hold, all 28 captures at a 10-frame
gap landed **inside the song**: every capture identical, both characters standing,
**byte-exact green, observing nothing.** Not a check that misses a rare failure — one that
could no longer fail on anything it was written to test. It now arms on the first cel change
and reports the held frames, so the window follows the action wherever the scene's holds
move it.

**3D — The recon, and the advice it retires.** Costed beat by beat against 15,872 B usable,
at the 633 B/bake this image averages. Vraise+Pback was additionally **built and linked** to
check the model — 23,002 B measured against 23,060 estimated:

```
current      19 bakes  12,922 B   2,950 free
+ Vraise 1   20        ~13,555    fits
+ Pback 13   35        ~23,060    OVER by  7,188
+ hold 5     40        ~26,229    OVER by 10,357
+ Vexit 17   52        ~33,833    OVER by 17,961
+ hold 12    63        ~40,804    OVER by 24,932
+ Pslump 28  64        ~41,437    OVER by 25,565
```

Only `Vraise`'s first play fits, and alone it freezes him mid-gesture; the oracle pairs
Vraise and Pback into one beat.

**★ P3.72i called `shift_row.s` the structural fix, worth "up to 4×". That is now wrong, and
it is wrong because of the P3.72j fix.** Aligning the pause by one CharX unit removed the
phase duplication a runtime shifter would have collapsed. The image is now **9 viz bakes for
9 distinct cels and 10 pri for 9** — zero phase duplication left. The recommendation was
correct when made and obsolete when I repeated it; acting on it would have cost a dispatch.

**3E — Jay's question about reuse, and what it actually found.** He asked whether `Pback` and
the vizier's exit are just walk frames mirrored.

**Right about the exit:** `Vexit` ends `aboutface,chx,16 / chx,3 / goto Vwalk2` — he walks out
on cels 48-53 again, mirrored. Only the turn (57-66) and the arm-lowering (77-82) are new.

**Not `Pback`:** measured across every cel in these beats, **no image index is shared by any
two cels**. Her step-back cels 12-17 are images 35-40, her own art, and she has no walk
sequence in this scene.

**But the question exposed a real inefficiency: the port pays for mirrors twice and the
oracle does not.** In the oracle a mirror is free at draw time (`OPACITY` bit 7 → `MLAY`); in
the port every mirrored variant is a second full-size baked cel. Costed in full at
`20260810-233000-p3-72n-runtime-mirror-cost.md`: **~+3,080 cy per mirrored cel draw** against
~24,000 cy of headroom, returning **~4,175 B**. Worth taking, and it compounds — but 16% of
the shortfall, not a substitute for the loader.

### 4 — Verification

**25.1 fresh tool output (verbatim, at `9a9724f`):**
- `build.bat` → `flames.raw: 4500 B` / `cel_image.raw: 12922 B flat image based at $C000` →
  `tracks 11..13 (902 B pad)` / `=== BUILD COMPLETE ===`
- `run_room_test.sh` → `checks=8 passed=8 failed=0` / `VERDICT: PASS` / `PASS` — **run twice,
  identical**
- `run_walk_test.sh` → `room up at frame 1759, loads=3`; `first movement at frame 2570 (+811
  held frames)`; `bank_mapped_at_every_capture PASS (0 of 28 captures unmapped)`; `modal gap
  6 frames`; `STABLE`; `PASS`
- Earlier at P3.72l, both memory sizes: room 8/8 and walk PASS at 128 KB; intro 17/17;
  `hal_sync_check.py` → `OK`

**★ ONE RUN FAILED AND IT WAS NOT THE PORT.** A room-test invocation reported
`FAIL (in-emulator checks)` having produced **no log file at all** — the Lua never ticked, so
MAME did not start. Two clean runs after it are 8/8 identical. Recorded rather than quietly
re-run to green: the discriminator is the *absent* log, not the second green.

**Bank occupancy: 12,922 of 15,872 usable = 81.4%; 902 B of track slack.**

**25.2:** N/A. **25.3:** **PASSED — Jay, live-disk, RGB, LIVE (motion, 100% speed).
Verbatim: "that looks awesome".** Not self-certified.

### 5 — Route accounting

Jay drove this interactively. Asked and delivered: add the two sound stubs like the intro's →
done, gated. Then "do the remaining beats — recon, build, verify, visual, one at a time" →
**the recon ran and stopped there**, because the first beat does not fit; no build was
attempted and none is claimed. Then "cost a runtime mirror" → done, reported, not built.

**Not present:** `Vraise`, `Pback`, `Vexit`, `Pslump`, the 16-colour swap, the `Prolog2`
handoff, the staging loader, the runtime mirror. The hourglass stays out (856 B over).

### 6 — Uncertainty flags

- **`vm_nextframe` re-bases as `now + count`, so its period drifts with the sampling rate.**
  `due = due + count` would not. It is why `SONG_FPS` is 7 rather than `cad_tab`'s 6 — a
  derived constant compensating for a source-level drift, which is the shape this project
  distrusts. Worth fixing properly.
- The mirror's `+32 cy/byte` is an instruction-count sketch, not a timed run; and the
  ~24,000 cy headroom is P3.21's figure re-scaled to the new 2.8-frame iteration. Both should
  be re-measured with `phasecost` before anything is built on them.
- Flames sit at 21.7 Hz against the oracle's 26.2; the gap is per-iteration work.
- `ch_last` has no spare bytes left (+5 facing, +6 Fdx, +7 sprite width).
- `startup_gap_small` measures the swap, not the reveal, and passed a ten-second dead room.
- Carried: hourglass 856 B over; `$2310..$2329` read-tap blindness; the peel matrix unrun on
  the banked build.

### 7 — Follow-up

1. **The staging loader** — Jay's P3.45 question, now binding. P3.63's peak residency of
   5,631 B against a 15,872 B bank is why it works; both song cues are 6-13 s of stillness,
   which is a lot of disk time to hide a read behind.
2. The runtime mirror, after the loader (§3E).
3. `vm_nextframe`'s re-base; re-point `startup_gap_small`; re-run the peel matrix.

### 8 — Candidate captured

`seeds/POP/live/2026-08-10-a-vacuously-true-guard-reads-as-a-careful-measurement.md`, pushed
at P3.72h. This segment's own candidate — a suite that goes vacuous when the thing it samples
moves out from under its trigger (§3C) — is the same family and is better folded into that
row at reconcile time than filed twice.

### 9 — Commit

`1182b36`, `814cd30`, `9a9724f`, all pushed to origin/wip. This report follows.
