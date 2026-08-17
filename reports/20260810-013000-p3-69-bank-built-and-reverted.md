## Form B Report — P3.69 — the bank was built and it RUNS, then corrupts from capture 05. Reverted.
**Class:** build, completed and then reverted on an undiagnosed regression. wip. **Tree back at `8d2dc57`'s
state, suites green.** Prod untouched.

### 0 — Receipt / status (C-35 stamp)
HEAD at start `dd3597c`, wip. Sync bridge green at t0 and at report. Working tree carries only this report;
every `src/`, `build.bat`, `link/`, `content/` and harness change was reverted after the regression. Karateka and
`main` untouched.

---

### 1 — Summary

**All five pieces were built, the port loaded the banked cels, and the room came up drawing from `$C000`.**
Then the walk suite failed: **captures 01–04 byte-exact, 05 onward ~3,800 wrong bytes each**, deterministic and
identical across two separated runs. I could not diagnose it inside this session, so I reverted rather than leave
a broken tree or guess at a fix.

**What demonstrably worked:**

| | |
|---|---|
| bundle after the cels left it | **11,921 → 4,280 B** |
| cel image | **7,633 B, linked `$C000..$DDD0`** |
| disk | tracks 11–13, unpacked, 3 whole tracks |
| room suite | **8/8**, room displayed, cels on screen, `loads=3` |
| walk captures 01–04 | **0 bytes wrong** — cels genuinely drawn out of the bank |

**What I verified is NOT the cause**, each by direct measurement rather than reasoning:
- **the mapping** — `$C000`/`$C001` read `11`/`46` (`WALK_LO`/`WALK_N`) continuously from f1760 to the end;
- **the table** — every entry checked against `cels.map`; cel 50 ph1 → `$CA95`, cel 11 ph1 → `$C2E2`, all inside
  the image;
- **the swap** — exactly one `jsr HAL_gfx_swap` in the file, inside `room_present`;
- **the pillar fill** — `co_fore` is bounded to 3 × 48 bytes and its gate is not even satisfied at capture 05.

**The damage does not have a cel's shape:** `$FF` scattered over **rows 106–191, cols 0–79** — most of the lower
screen. That is a runaway blit or a second writer, and it starts at one point and never recovers.

---

### 2 — Files modified

- `reports/20260810-013000-p3-69-bank-built-and-reverted.md` — this report.

**Reverted:** `bake_scene`'s split into `cel_image.s` + `walk_scripts.s`; `link/pop_cels.link`; `build.bat`'s
assembly, link, `decb_to_raw` and track allocation; `char_draw.s` reading `WALK_LO`/`WALK_N` from the image and
indexing `CEL_WALK_TAB`; `img_map`'s reduction and the slot seeds; `cutscene_room.s`'s `cel_bank_map`,
`room_present` and the cel load; `room_test.lua`'s load-count guard.

### 3 — Reasoning

**3A — The five pieces, as built.** Bank blocks **`$0E`/`$0F`, not `$3E`/`$3F`** — on 128 KB the GIME masks to
installed RAM so `$0E` aliases to itself, and on 512 KB `$00-$0F` sit below both framebuffers (`$10-$1B`) and
below the default CPU map (`$38-$3F`), so the same numbers are free in both sizes. `$3E`/`$3F` would have been
the CPU's own map at 512 KB.

`cel_bank_map` writes `$FFA6`/`$FFA7` under `pshs cc / orcc #$50`. `room_present` wraps `HAL_gfx_swap` and
re-applies it, so "a flip must be followed by a re-map" is a property of one routine rather than a rule every
call site remembers.

The image describes itself — `WALK_LO`/`WALK_N` as its first two bytes — so the engine reads its bounds instead
of keeping a second copy across a link boundary it cannot resolve. That was deliberate: a duplicated layout
constant is what `CHAR_TAB` was.

**3B — Three build faults, all mine, all fixed.** `link/pop_cels.link` used `*` comments (lwlink wants `;`);
`load $C000` parses as zero and linked the image at `$0000`, caught by `decb_to_raw`'s base check — **the same
`$`-versus-bare-hex trap `build.bat` documents for `lwasm -D`, one tool along**; and the inserted load pushed
three `bne room_failed` past an 8-bit displacement, needing `lbne`.

**3C — One guard fired correctly and was updated, not relaxed.** `room_test.lua` asserted `loads == 2`; there are
now three reads. That is the P3.50 shape — a guard keyed to the expected-GOOD value failing open when the good
value legitimately moves — and the count is a real assertion (a missing read is a silent black scene), so it was
re-keyed to 3 rather than removed.

**3D — Why I reverted rather than pressed on.** The regression is real, reproducible and not explained by
anything I could check statically. Every fast hypothesis was eliminated by measurement (§1). What remains needs
either a write-watch on the bank across the failing frames or a bisect of the draw path, and I am far enough into
this session that a fix arrived at now would be a guess. **A broken tree or a guessed fix is worse than a clean
revert and an accurate account of where it broke.**

### 4 — Verification (AC-by-AC)

- **AC1 five pieces built** — **yes, and then reverted.** All five existed and the port ran on them.
- **AC2 map once** — **not applicable**: P3.68 established it cannot be once; `room_present` re-applies per swap,
  as Jay authorised.
- **AC3 `Palert` restored** — **no.** The bank had to work first.
- **AC4 remaining beats** — no.
- **AC5 bank occupancy measured** — cel image 7,633 B against 15,872 B usable; it fits entirely in block `$0E`,
  so `$FFA7` is not yet exercised by real data.
- **AC6 suites green** — **at the reverted state**: build COMPLETE, room 8/8, walk 28/28 stable. **Not green on
  the banked build** — that is the finding.
- **AC7 no `gfx.s` edit, no duplicated HAL constants** — honoured. `$FFA4-$FFA7` are GIME registers, not the
  HAL-private buffer addresses `gfx.s` protects; the distinction is argued in the reverted source.
- **AC8 Jay gates live** — **not offered.**
- **AC9** — §6; sync bridge green; Karateka and `main` untouched.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output, at the reverted state:** `build.bat` → `flames.raw: 11921 B` / `=== BUILD COMPLETE ===`;
`run_room_test.sh` → `PASS`; `run_walk_test.sh` → `PASS`; `hal_sync_check.py` → `OK`.

**On the banked build, before revert:** room `checks=8 passed=8 failed=0`; walk captures 01–04 `0 bytes WRONG`,
05 `3916 bytes WRONG`, and every capture after it.

**25.2:** N/A. **25.3:** **not offered.**

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** The route was five pieces → `Palert` → the beats → a live gate. **The five pieces were
built and are not in this commit; nothing else was started.** `Palert` was never restored — it was gated behind
the bank working, and the bank does not yet. No gate is claimed. **This is the second dispatch running where work
was written and then backed out**, and the reason differs: P3.68 stopped at a verified hard-stop before
finishing, this one finished and failed its own suite.

**Deviation:** the per-swap re-map was implemented as authorised. No other deviation.

### 7 — Uncertainty flags

- **The regression is undiagnosed.** Known: starts at capture 05 and never recovers; `$FF` over rows 106–191,
  cols 0–79; deterministic across two runs; mapping and table verified correct throughout.
- Untested in the banked build: 128 KB (the failing run was at default 512 KB), and `$FFA7`, which no real cel
  data reached.
- The cel image at 7,633 B fits one block, so the two-block arithmetic that motivated `$FFA7` is not yet
  exercised — `Palert` is what would push past 8 KB.
- Carried: hourglass 856 B over; 513 B over the 32 KB bank for the complete scene; `$2310..$2329` read-tap
  blindness; `PlayCut0`'s sound sites; `shift_row.s` unwired.

### 8 — Follow-up candidates

1. **Diagnose the corruption first, with an instrument rather than a hypothesis** — a write-watch on `$C000-$DDD0`
   across frames 1750–1850 would say directly whether the bank is being written or the blit is running away.
   Everything cheap has already been eliminated (§1).
2. The five pieces are described here precisely enough to rebuild in one pass once the cause is known.
3. `Palert` after that.

### 9 — User interaction during task

Jay re-worded HARD-STOP #5 to authorise implementing a settled design, and authorised the per-swap re-map with
"do it". Both were acted on.

### 10 — Candidate(s) captured this task

None new. The build faults (§3B) are further instances of already-captured rows; the regression is undiagnosed
and a candidate written now would be a guess about its cause.

### 11 — Commit

This report. `8d2dc57` remains the built state.
