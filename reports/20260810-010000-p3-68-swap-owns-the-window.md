## Form B Report — P3.68 — HARD-STOP #2: the map cannot happen once. `HAL_gfx_swap` owns all four window registers.
**Class:** build, halted at a verified hard-stop. wip. **Both bank halves proven; the five pieces started and
backed out.** Tree at `8d2dc57`'s built state, suites green. Prod untouched.

### 0 — Receipt / status (C-35 stamp)
HEAD at start `a88e7f4`, wip. Sync bridge green at t0 and at report. Working tree carries only
`harness/tools/bank_proof.lua` (extended) plus this report; every `src/`, `build.bat`, `link/` and `content/`
change made during the attempt was reverted. Karateka and `main` untouched.

---

### 1 — Summary

**HARD-STOP #2, and it is the dispatch's own: *"Anything requires a per-frame or per-beat remap → stop and
report; this milestone maps once."* It does.**

`HAL_gfx_swap` ends by calling `gfx_map_blocks` [gfx.s:568], and `gfx_map_blocks` writes **`GFX_DB_BLOCKS = 4`**
registers from `$FFA4` — **all four**, unconditionally. This scene swaps **once per animation step**. So every
page flip rewrites `$FFA6`/`$FFA7` back to framebuffer blocks and **a bank mapping cannot survive a single
frame.**

**"Map once at scene start" is not achievable.** Keeping the bank reachable requires re-mapping two registers
after every swap — a per-frame remap — and the only alternative is making the window two blocks instead of four,
which is a `gfx.s` edit and fails the sync bridge (HARD-STOP #3).

**★ FIRST, THOUGH: P3.67's one untested dependency is now measured and it holds.** Both bank halves, stamped
through their own registers with the room live:

```
  $FFA6 -> block $0E, 2048 B at $C000: all intact
  $FFA7 -> block $0F, 2048 B at $E000: all intact
# RESULT: both bank halves survive the scene, and borrowing them did not
#         disturb the room. 16 KB of the 32 KB free verified.
# checks=8 passed=8 failed=0        <- the room suite, same run
```

So the *bank* is sound. What is not sound is the claim that one mapping suffices.

---

### 2 — Files modified

- `harness/tools/bank_proof.lua` — extended to stamp **both** halves (P3.67 flagged `$FFA7` as untested and the
  design rested on it).
- `reports/20260810-010000-p3-68-swap-owns-the-window.md` — this report.

**Reverted, deliberately:** the `$C000` link script, `bake_scene`'s split into `cel_image.s` + `walk_scripts.s`,
`char_draw.s`'s re-pointing at `CEL_IMAGE`, `img_map`'s reduction, and `build.bat`'s cel-image assembly and track
allocation. **They were written and then backed out** — see §6.

### 3 — Reasoning

**3A — How far the build got before the stop.** Four of the five pieces were written: the link script at `$C000`;
`bake_scene` emitting a self-describing cel image (`WALK_LO`/`WALK_N` as its first two bytes, so the engine reads
its bounds rather than declaring a second copy — the `CHAR_TAB` lesson) plus a separate `walk_scripts.s`, because
the scripts name sequence labels that live in `char_draw.s` and cannot cross a link boundary; `build.bat`
assembling, linking and allocating tracks 11–13 unpacked (3 tracks = 13,824 B, and `load_tracks` reads whole
tracks straight into the mapped bank, so the packing the `$3000` bundle needs has no equivalent here); and the
engine reading `walk_tab` at `CEL_IMAGE+2`.

**The fifth piece — the room's one-time map and load — is where it stopped**, because writing it required knowing
whether the mapping survives, and it does not.

**3B — The check that ended it.** Reading `HAL_gfx_swap` to place the map:

```
gfx_sw_map:
        jsr     gfx_map_blocks          [gfx.s:568]

gfx_map_blocks:
        ldx     #GFX_DB_MMU             ; $FFA4
        ldb     #GFX_DB_BLOCKS          ; 4
gfx_map_lp:
        sta     ,x+                     ; four registers, unconditionally
```

`GFX_DB_BLOCKS` is 4 because the **16-colour** buffer needs 32 KB. The cutscene is 4-colour and uses 15,360 B, so
two of those four writes are placing blocks the framebuffer never reads — and overwriting whatever the bank had
put there.

**3C — Why this was not visible earlier, and it should have been.** P3.66b measured that borrowing `$FFA6` did
not disturb the room, and read that as "the borrow is safe". It is — but *safe* and *durable* are different
claims, and the probe stamped once and read back once. **It never checked whether the mapping was still in place
between those two moments**, and it was not: the port reclaimed it on the very next swap and the pattern survived
only because nothing else uses that physical block. **The measurement was correct and the inference from it was
not.** P3.67 then built a design on the inference.

**3D — What the fix costs, characterised but NOT taken.** Re-mapping after each swap is two masked writes,
outside the three passes, on the order of 20 cycles against a 29,859-cycle frame. It is small and it is safe.
**It is also exactly what the dispatch said to stop on**, and taking it would be reshaping a stated constraint
rather than reporting it — so it is recorded here for Jay to rule on, not implemented.

### 4 — Verification (AC-by-AC)

- **AC1 five pieces built** — **no.** Four written, one blocked, all reverted (§2, §6).
- **AC2 map ONCE at scene start** — **impossible**, and that is the finding.
- **AC3 `Palert` restored** — no; it depends on AC1/AC2.
- **AC4 remaining beats** — no.
- **AC5 bank occupancy** — unchanged from P3.67's arithmetic; nothing new landed to measure.
- **AC6 suites green** — yes, at the reverted state: build COMPLETE, bundle-offset assertion passing, walk 28/28
  stable across two runs, room 8/8. **Bank contents proven to survive a full scene for both halves** (§1).
- **AC7 no `gfx.s` edit, no duplicated HAL constants** — honoured; the second is *why* AC2 is impossible.
- **AC8 Jay gates live** — **not offered.** Nothing in `src/` changed.
- **AC9** — §6 below; sync bridge green; Karateka and `main` untouched.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output:** `build.bat` → `[bundle-offsets] room offsets agree …` / `=== BUILD COMPLETE ===`.
`run_walk_test.sh` → `STABLE … PASS`. `run_room_test.sh` → `PASS`. `run_block_budget.sh` → the block in §1,
exit 0. `hal_sync_check.py` → `OK`.

**25.2:** N/A. **25.3:** **not offered** — the tree's behaviour is byte-identical to `8d2dc57`.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** The route was five pieces → `Palert` → the beats → a live gate. **This commit contains none
of them.** Four pieces were written and **reverted rather than committed**, because leaving them in would have
left either a broken tree (the engine reading `$C000` with nothing mapped there) or dead unreferenced code — the
`CHAR_TAB` hazard this project has already been bitten by. The only surviving change is the bank proof.

**Deviation:** none taken. The per-swap remap (§3D) is characterised and left unimplemented under HARD-STOP #2.

**And a correction to my own P3.66b, which is the substance of this report:** that dispatch concluded borrowing
`$FFA6` was safe, and P3.67 built "map once at scene start" on it. The borrow *is* safe; it is not *durable*, and
nothing measured the difference. **The design premise was mine and it was wrong.**

### 7 — Uncertainty flags

- **The per-swap remap is characterised by instruction count, not measured** (§3D). If it is taken, it should be
  measured, not estimated — and it is now measurable, being POP-side code rather than HAL-private.
- The bank proof stamps 2 KB per half, not the full 16 KB, and does not exercise the mode swap to 16-colour.
- Whether re-mapping after `HAL_gfx_swap` interacts with `HAL_gfx_mirror` (which also touches buffers) is
  unexamined.
- Carried: hourglass 856 B over; complete scene 513 B over the 32 KB bank in segment encoding; `$2310..$2329`
  read-tap blindness; `PlayCut0`'s sound sites; `shift_row.s` unwired.

### 8 — Follow-up candidates

1. **Rule on the per-swap remap.** Two masked writes after each swap, outside the three passes. If authorised,
   the other four pieces are written and can be restored from this report's description in one pass.
2. Alternatively: a POP-side wrapper that swaps *and* re-maps, so the fact lives in one place rather than at every
   call site.
3. Measure it once taken.

### 9 — User interaction during task

Jay re-worded HARD-STOP #5 in this dispatch to authorise implementing a settled design, and directed "continue"
twice before it. That authorisation was acted on: the build was attempted, and stopped at a different hard-stop
than the one he relaxed.

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-10-safe-and-durable-are-different-claims.md`

### 11 — Commit

This report and the extended `bank_proof.lua`. `8d2dc57` remains the built state.
