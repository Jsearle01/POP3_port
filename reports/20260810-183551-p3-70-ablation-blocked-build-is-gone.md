## Form B Report — P3.70 — the ablation cannot start: P3.69's build does not exist. Four ACs answered anyway, and the ruling-out method is defective.
**Class:** recon. wip. Prod untouched; no `src/`, `build.bat`, `link/` or `content/` change in this task.

### 0 — Receipt / status (C-35 stamp)
t0=2026-08-10T18:35:51-04:00 (HEAD `d562e15`, wip). Working tree carries only this report plus the
pre-existing untracked docs/content/`.vscode`/`nvram` set and the modified `dist/mame-cfg/rgb/coco3.cfg`
that t0 found. Karateka and `main` untouched.

---

### 1 — Summary

**§1's instruction — "re-apply P3.69's revert to reproduce" — rests on a false premise. There is nothing to
re-apply.** P3.69's banked build was not reverted by a `git revert`; it was discarded. It exists in no commit,
no stash, no dangling object, and no build artifact. **Not one ablation-table variant can be run without first
re-implementing all five pieces from the report's prose**, which is a build, not a diagnosis, and §5's HARD-STOP
#2/#3 forbid rebuilding on a guess.

So I ran everything that does not depend on the missing build, and it turned out to be most of the dispatch:
**AC2, AC3, AC4 and AC5 are answered, two hypotheses are killed by arithmetic, and P3.69's ruling-out of "the
mapping" is shown to be unsound as a method** — the capture path is itself an MMU writer.

**The tree is left exactly as t0 found it, and it is green by fresh measurement** (§5).

---

### 2 — Files modified

- `reports/20260810-183551-p3-70-ablation-blocked-build-is-gone.md` — this report.

No source, build, link, content or harness file was touched. (Explicit-path staging only.)

### 3 — Reasoning

**3A — The build is gone, verified four ways rather than assumed.**

| check | result |
|---|---|
| `grep -rn room_present src/` | no match — the wrapper does not exist |
| `build/assets/flames.raw` | **11,921 B** — the pre-bank size, not 4,280 |
| `room_test.log` | `disk_reads_ok PASS loads=2` — not the banked build's 3 |
| `git stash list` | empty |
| `git fsck --lost-found` | 8 dangling commits, **newest 2026-07-30**; P3.69 was 2026-08-10 |

The P3.69 report's closing line "`8d2dc57` remains the built state" is not accurate — `8d2dc57` is P3.65, and its
tree contains no bank. **Authority tier: measurement of the tree and of git, not the report's description.**

**3B — AC4, the damaged region's address range. It IS one contiguous run.**

The captures are 15,360 B and `walk_test.lua:39` reads `FB_BASE, FB_SIZE = 0x8000, 15360` — so the framebuffer is
4-colour, **80 B/row × 192 rows, CPU `$8000..$BBFF`**, and `$C000` is genuinely outside it (which is why a bank at
`$C000` could work at all).

Rows 106–191 × cols 0–79 = offsets 8,480..15,359 = **`$A120..$BBFF`, 6,880 bytes — one contiguous run, ending
exactly at the top of the framebuffer.**

It lies entirely inside **MMU register `$FFA5`'s window (`$A000-$BFFF`)**: rows 0..102.4 are under `$FFA4`, row
102.4 onward under `$FFA5`. That looked like the answer — a damage boundary falling on a block boundary rather
than a cel boundary. **Arithmetic kills it.** If `$FFA5` were mis-mapped the whole run would read `$FF`, and
measured against `princess_room.raw` (excluding `torch()`/`STARS` exactly as the checker does) that is **6,236
wrong bytes**. P3.69 measured **3,916**. A solid `$FF` fill of rows 106–191 is ruled out by the same number.
**The damage is genuinely scattered — 56.9 % of the run — which is what P3.69's word "scattered" already said and
what neither a block mis-map nor a runaway fill produces.**

**3C — AC5, the peel buffers. They did not move, and the P3.50 shape does not apply.**

`char_draw.s:144-145`: `VIZ_PEEL_BASE equ $6C00`, `PRI_PEEL_BASE equ $6C00+VIZ_PEEL*2` = `$6FC0`. Two vizier slots
× 480 B + two princess slots × 344 B = 1,648 B, **`$6C00..$727F`**.

These are **absolute literals**. They are not derived from the bundle size, from `FLAME_BASE`, or from any symbol
that moved when 7,641 B left the bundle — and they sit **below `$8000`, outside the `$8000-$FFFF` draw window
entirely**, clear of the disk parameter block at `$6A00` and the trace ring at `$7800`. The bundle shrinking
11,921 → 4,280 B moves only its *end*, downward, which can only increase the clearance. **P3.50's shape is a
guard keyed to an address that legitimately moved; nothing about the peel is keyed to the bundle extent, so the
analogy does not hold and the peel is not the second writer.**

**3D — AC3, frame vs step. The dispatch's premise is inverted.**

`walk_test.lua:192` — `next_shot = fn + GAP`, with `P_GAP=10` and `P_SHOTS=28` (`run_walk_test.sh:60-61`).
**Captures are every 10 video FRAMES, not per step.** Capture 05 is at `first_fn + 40` frames. Measured cadence on
this run: **mean 3.78 frames per step over 32 steps**, so capture 05 is ~10.6 steps in. **Captures and the remap
are both per-frame — this harness offers no frame-vs-step discriminator at all**, and the distinction the dispatch
expected to narrow things sharply does not exist here.

**3E — AC2, what changes at capture 05. Answered from the running machine.**

Fresh run a:

```
01  cel48 top 105 col 74      05  cel52 top 105 col 65   <-- first draw of cel 52
02  cel50 top 105 col 70      06  cel49 top 105 col 63
03  cel53 top 105 col 69      07  cel51 top 105 col 59
04  cel49 top 105 col 68
```

- **Capture 05 is the first frame on which cel 52 is drawn.** Captures 01–04 draw {48, 50, 53, 49}. That is the
  concrete discriminator.
- **It is NOT the first phase-0 draw.** Measured occupancy on the running machine: cel 48 → {0,2}, 49 → {0,2},
  50 → {0,2}, 51 → {1,3}, 52 → {0,2}, 53 → {1,3}. Phase 0 is already exercised at capture 01. *(I had this as a
  lead off the `content/cutscene/chars/v52_p0.s` filename — cel 52 being the only `p0` baked variant. The machine
  killed it. Recorded because it is exactly the plausible story §5 warns about.)*
- **It is not a facing change or a first mirrored draw** — the vizier walks left throughout, and the princess
  (cel 11, top 109 col 36) is static across all 28 captures.
- **It is not a foreground-plane event.** The pillar fill is rows 104–151, cols 60–62 (`verify_room_chars.py:30`).
  At capture 05 the vizier is at col 65 spanning 65–71, right of the pillar; he first overlaps at capture 07
  (col 59, spanning 59–65). **P3.69's ruling-out of `co_fore` on its gate is sound for capture 05** and I did not
  re-examine it further.

**3F — ★ The one thing I found that is a defect rather than an observation, and it is systemic.**

`dump_front()` in `walk_test.lua:53-64`:

```lua
local function map_blocks(first)
    for i = 0, 3 do mem:write_u8(0xFFA4 + i, first + i) end
end
... map_blocks(front_blk) ... read $8000..$BBFF ... map_blocks(back_blk)
```

It writes **all four** MMU registers and restores them to the **back buffer's** four blocks — a restore scheme
that predates the bank and does not know it exists. **In the banked build every capture silently un-maps the bank
from `$FFA6`/`$FFA7`**, and the only thing that puts it back is `room_present` on the next swap. The same
`map_blocks` pattern is in `room_test.lua:104`, `introseq_test.lua:167` and `torch_trail_probe.lua:45`. **This is
what AC7's "checkers re-pointed at the bake's scheme" concretely means, and it will be present in any rebuild.**

**It also makes P3.69's ruling-out of "the mapping" unsound as a method.** The tree's own `bank_watch.log` reads:

```
f1700  $C000=11 $C001=46   f1750  $C000=0 $C001=0
f1755  $C000=255 $C001=255 f1760  $C000=11 $C001=46
```

— the window reads **`$FF` at f1755**, and the report's claim was scoped "from f1760 to the end," sampled on a
schedule unrelated to the capture frames. **A probe that cannot land on the perturbed window, measuring a
register the capture path writes, cannot rule that register out.** I am flagging the *method*, not re-opening the
cause — the conclusion may well still be right, but it is not yet evidence.

**3G — The next cheapest mechanical split, and why it beats the ablation table.**

With the rebuild in hand: a **passive write-tap on `$FFA0-$FFA7`** plus a **write-watch on `$A120..$BBFF`**, run to
capture 05. `harness/tools/block_budget.lua:36` already installs exactly that tap
(`mem:install_write_tap(0xFFA0, 0xFFA7, ...)`), so it is one existing instrument, it touches nothing, and **it
records who wrote rather than what broke** — which distinguishes every row of the dispatch's four-variant table
at once and costs one run instead of four rebuilds.

### 4 — Verification (AC-by-AC)

- **AC1 four ruled-out causes not re-examined; ablation run** — **half.** Not re-examined (the `co_fore` gate is
  independently reconfirmed in 3E, not re-litigated). **No variant could be run** — §1's premise is false (3A).
- **AC2 capture 05 enumerated concretely** — **done, 3E.** First draw of cel 52 at col 65; phase-0, facing and
  foreground all excluded by measurement.
- **AC3 frame-vs-step established** — **done, 3D.** Captures are per-frame (GAP=10), not per-step.
- **AC4 damaged region's address range, contiguous?** — **done, 3B.** `$A120..$BBFF`, 6,880 B, one contiguous run.
- **AC5 peel buffers checked against post-bank layout** — **done, 3C.** `$6C00..$727F`, absolute, unmoved, outside
  the draw window.
- **AC6 writer named and fixed** — **NOT named.** Reporting the state and the next split, per HARD-STOP #2/#3.
- **AC7 build lands, suites green, Jay gates live** — **N/A**, no build attempted.
- **AC8 route accounting; tree stated; Karateka and `main` untouched** — §6; tree stated in §1 and §5.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim, this task, at the unchanged t0 tree):**
- `build.bat` → `6 File(s)  36376 bytes  64512 bytes free` / `=== BUILD COMPLETE ===`
- `build/assets/flames.raw` → `11921 B` (the pre-bank bundle)
- `run_walk_test.sh` → all 28 captures `0 bytes WRONG`; `stability: all captures agree (0)`;
  `STABLE: both runs walked the same positions and produced the same result`; `[run_walk_test] PASS`
- `room_test.log` → `# checks=8 passed=8 failed=0` / `VERDICT: PASS`, `disk_reads_ok PASS loads=2`

**25.2:** N/A — no sibling-import artifact.

**25.3 operator-runtime-smoke:** **not offered** — nothing visual changed this task.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING. I proposed no route.** The dispatch's route was: reproduce → ablate four variants → name the
writer → fix → re-apply P3.69's five pieces → `Palert` → beats → live gate. **This commit contains none of the
build steps and none of the ablation.** It contains the four analytic ACs, two hypotheses killed, one defect
found, and the blocker. **Nothing was rebuilt, nothing was patched, and no cause is claimed.**

**Deviation (§22.5):** §1 directs "re-apply P3.69's revert to reproduce"; I could not, and did not substitute a
from-prose rebuild for it, because that is a build under a dispatch whose own HARD-STOP #3 says not to rebuild on
a guess and #5 says this dispatch is diagnosis. **Per HARD-STOP #4 I left the tree in place** — there was nothing
of mine to unwind, and I am asking rather than acting.

### 7 — Uncertainty flags

- **The cause is not attributed.** What is now known and was not: the damaged run is `$A120..$BBFF` contiguous;
  it is neither a solid `$FF` fill (6,236 ≠ 3,916) nor a wholesale `$FFA5` mis-map (same arithmetic); the peel is
  not the writer; capture 05 is cel 52's first draw and is not a phase, facing or foreground event.
- **P3.69's "the mapping is not the cause" should be treated as unproven, not as wrong** (3F).
- I could not reconstruct 3,916 from any generator I tried. Without the failing capture that is modelling, and I
  stopped rather than fit a story to a number quoted in prose.
- Carried, untouched: hourglass 856 B over; 513 B over the 32 KB bank for the complete scene; `$2310..$2329`
  read-tap blindness; `PlayCut0`'s four sound sites un-stubbed; `shift_row.s` assembled and unwired.

### 8 — Follow-up candidates

1. **The question for Jay (§9).** Rebuilding P3.69's five pieces from prose is a build-sized task. Is it
   authorised as P3.71, or does the build survive somewhere I cannot see?
2. **Fix `map_blocks` in all four harnesses before any rebuild** (3F) — bank-aware restore, or better, stop
   writing `$FFA6`/`$FFA7` at all in the capture path, which the 15,360-byte read at `$8000..$BBFF` never needs.
3. **Instrument first, ablate second** (3G) — the `$FFA0-$FFA7` write-tap already exists.

### 9 — User interaction during task

None during the task. **One question outstanding, asked in place per HARD-STOP #4** — see §8.1.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-10-instrument-that-writes-the-register-it-measures-cannot-rule-out.md` — committed and
pushed to the pool (fire-and-forget, exit 0).

### 11 — Commit

See below. Pushed to origin/wip before this report.
