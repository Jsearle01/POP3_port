## Form B Report — P5.32 — the second character: a guard in the kid's path, three passes, and what the second actor costs
**Class:** build.  wip.  Prod byte-identical — `intro_seq.bin` `08BCAE4A…`, `loader.bin` `10BDDBD5…`,
`cutscene_room.bin` `D5B17B6D…`, `flame_cels.bin` `92DC6D96…`, sha1 identical at both ends. **Moved (the
subjects):** `kidrun_probe.bin` `D1B1B0D8…` → `B9EB8733…`, `kidrun_boot.bin` → `96100DB6…`,
`build/kidrun_gate.dmk`. `main` `32b5fe2` at both ends.

### 0 — Receipt / status (C-35 stamp)
t0=2026-10-10 11:59:09 (HEAD `ba97d84`, wip — as the dispatch drafted). git status clean of tracked changes
(the untracked set is not mine and untouched). Prod sha1s above, read at t0 and again at report.

### 1 — Summary
The guard of LEVEL0 stands on screen 1's top floor at CharX 160, facing the kid, driven by his own
`guardengarde` → `ready` sequence through `ALTSET1`; the kid runs `startrun` through him every lap.
`kidrun_probe.s` is rebuilt around **actor records and three passes — erase all, save all against the
clean room, draw all** — with four peel slots (actor × page). Thirteen steps predicted with no history are
byte-exact, including seven overlapped ones: **1,254 B of frame overlap and 357 both-opaque cells, 0
wrong**, the guard's frame exact at every step. A control build with the per-actor interleave P3.32 fixed
gets **59/73/53/37/7/73 bytes wrong at the overlapped steps, every one inside the stationary guard's
frame**, and none elsewhere — so the test discriminates. The second actor costs **+32,208 cy per step
(+76%)**: two actors take **74,757 cy**, **42.6% of the oracle's own one-actor time** for the frames run
(max 58.4%), and the cadence holds at **9.99 fps** against the oracle's 9.65.

### 2 — Files modified
- `src/engine/kidrun_probe.s` — rewritten: 38-byte actor records (`kid_rec`, `gd_rec`, initialised from
  `kid_tmpl`/`gd_tmpl`); `wk_seq_one`/`wk_erase_one`/`wk_save_one`/`wk_draw_one` per actor; the step is
  three passes plus a union-rectangle fore pass; facing-aware `chx` (ADDCHARX) and placement;
  `usealtsets`; `guardengarde` transcribed; `wk_nact` (2, or 1 for the one-actor control).
- `src/boot/kidrun_boot.s` — copies `kr_nact` → `wk_nact`; a third read (C, kd3) into `$3400` FIRST,
  copied up to `$6B00`, before reads A and B.
- `link/pop_kidrun.link` — `kd2` `$2000` → `$2200` (prog passed `$2000`); `kd3` at `$6B00`.
- `harness/tools/kidrun_plan.py` — both actors: both transcriptions checked against `seq_graph`; the
  guard placed, peel-bounded and predicted (mirrored reference, char_probe_plan's oracle rule); fails if
  the two never overlap; writes `kidrun_ref_N.json` (rectangles, both-opaque offsets); kd3 span.
- `harness/tools/kidrun_overlap.py` — NEW. P3.32's test on a capture: the guard's frame, the frames'
  overlap, the both-opaque cells.
- `harness/smoke/run_kidrun_test.sh` — runs `kidrun_overlap.py`; default step 14 → 16 (inside the overlap).
- `harness/smoke/run_suites.sh` — `kidrun` joins the 512 KB suite set (AC14).
- `harness/tools/kidrun_cycles.lua` — snapshot-at-end timing (§3G); slots `$3400` → `$4100` (`$3400` is
  now inside the peel); `P_NACT` one-actor control. `harness/smoke/run_kidrun_cycles.sh` — `kr_nact`,
  `P_OUT`. `harness/tools/kidrun_cost.py` — takes a log path.
- `build.bat` — `--predict` list; image C on track 7; `KR_TRK_C`, `KR_WKNACT` into the loader.
- `mame-idioms-coco3-port.md` — §41: multi-phase timing must snapshot in one bp action (§3G).

### 3 — Reasoning

**3A — Three passes, not a per-actor loop** (source: P3.32 §3A, read first as §1 required). P5.31's loop
was erase→save→draw for one character; extending it per actor is P3.32's bug exactly. `wk_loop` is now:
SEQ (kid, guard) → ERASE ALL (guard, kid) → SAVE ALL (kid, guard) → DRAW ALL (kid, guard) → FORE once over
the union of both new rectangles. There is no per-actor path through a step. Erase order does not matter
(both buffers were saved against the clean room); draw order does — next.

**3B — Who is in front** (source, FRAMEADV.S:2191-2193, `compare`): `cmp #TypeShad / beq :xinfront
;enemy is always in front`. The guard is drawn after the kid.

**3C — The guard's sequence and frames (AC3)** (source). `guardengarde` [SEQTABLE.S:214] is `goto ready`;
`ready` [:228] is `act 1, tap 0, 158, 170`, then `:loop 171 / goto :loop`. Frames 158/170/171 are all in
150..189, so `usealtsets` [CTRLSUBS.S:1685-1711] reads them from `ALTSET1` (`sbc #149`; `alt1_tab` row
n−150): CHTAB4.GD #8, #19, #20 — 39 rows × 7 bytes, Fdx 0, Fdy 1, Fcheck `$CD`, so PL 0 facing right.
**Why this one:** it is the guard's combat stance — the hold §5.327 measured at 48.1% of his steps — and a
stationary character crossed by a mover is P3.32's discriminating configuration ("the STATIONARY
character is the one vandalised") and the case §3.3's peel-skip question is about. Every opcode it uses
(`goto`, `act`, `tap`) is already implemented. A walking guard (`advance`) would add frames, not a
different test. **Not drawn: his sword.** Fsword `$C8` names SWORDTAB entry 8, a separate CHTAB3 sprite
[SETUPSWORD, CTRLSUBS.S:1590]; §8 puts the sword out of scope.

**3D — Facing right** (source). FCharX = 2·(ADDCHARX(Fdx) − 58) + PL with ADDCHARX = CharX + Fdx facing
right [CTRLSUBS.S:353-363, 805-839]. `MLayGen` [HIRES.S:1178-1208] takes (XCO, OFFSET) as the image's
**bottom-RIGHT** corner (`XCO := XCO − WIDTH`), so the mirrored image ends at FCharX. `xf_blit` mirrors its
own 4·w0-px frame, so the frame starts at port px 20 + FCharX − 4·w0; the reference (7·apple_w px) ends at
the same pixel and sits 4·w0 − 7·apple_w to its right — the relation `char_probe.s` already uses for a
mirrored draw (P5.28/29, Jay-gated). Colour: swap = PL in both facings (P5.29). Byte-exactness at every
captured step is the check that this is right.

**3E — Placement and the overlap (AC4)**. Guard CharX 160, CharY 55, his frame port bytes 49..55, rows
18..56. The kid's frame crosses his at steps **13-21 of every 24-step lap** (`kidrun_plan.py` lists the
lap and fails if none overlap). Captured: 6, 12 (before), 13, 15, 16, 17, 19, 21 (through), 22 (just after
— residue), 24, 26 (the wrap), 40 (the second pass), 46 (after it).

**3F — Peel slots (AC5)**. Each record carries its own per-page valid/offset/rows/width/buffer; nothing
indexes another actor's. Kid `$3000`/`$3190` (400 B each), guard `$3320`/`$3460` (320 B; needs 273),
`$3000-$359F` in the staging area, runtime only. The page index is `HAL_gfx_cur_back`, as P5.31's.

**3G — An instrument tore, and was fixed before any two-actor number was used.** The first two-actor
timing log had erase values of ~4,294,893,000 on 25 of 72 rows. The rows also showed the NEXT step's frame
number: `kidrun_cycles.lua` wrote each phase boundary to its own slot and read the slots once per video
frame, and with a 2.4-frame step a read could land after the next step's seq and erase had run. Fixed in
the instrument, not the probe: boundaries set debugger temps, and the end breakpoint writes all the deltas
plus frame/X/phase/step number in one action; a snapshot is accepted only when its step agrees with
`wk_steps`. The one-actor figures were unaffected by the fix (identical before and after). Idiom §41.

**3H — Memory.** The three guard streams (1,379 B) did not fit kd1+kd2 (≈ 700 B free). The span P5.31b
vacated at `$6B00-$77FF` is free, but no whole-track read can land there without covering `$6A00` or the
kernel. So the loader reads one more track (7, the last free one) into `$3400` FIRST, copies it up, then
does A and B (B overwrites the temporary bytes; the loader at `$3200` is never covered). Boot, LOADM typed
→ kid running: **17.8 s** (P5.31b 16.1 s; the extra track +1.7 s). Also: the three-pass code ran prog past
`$2000` — `map_overlap_check` blocked the first link (`prog $1D6F..$205E OVERLAPS kd2`); kd2 moved to
`$2200`.

**§2H checks.** (1) Second mechanism: the guard reads `ALTSET1`, the kid `Fdef` — `usealtsets` is the
second frame-table path, implemented with its range test; its falling substitution (102..106) is the third
and is unreachable here (stated in the source header). (2) Calling routine: `ANIMCHAR`'s frame byte →
`GETFRAMEINFO` → `usealtsets` [CTRLSUBS.S:1652]; draw order from `sortlist`'s `compare` [FRAMEADV.S:532,
2182]. (3) Prior reports grepped: P3.32 (three passes, the discriminating test, the skip's false premise),
P3.21 §3D (the second character's peel crossed the cutscene's budget — "the place to look", §4), P5.27
(CHTAB4.GD baked and probed), P5.31/31b (the loop, the loader). No contradiction found.

### 4 — Verification (AC-by-AC)
- **AC1** prod byte-identity — the four sha1s identical at t0 and at report (header). Moved: the probe,
  its loader, its gate disk.
- **AC2** three passes — `wk_loop`, §3A. The control (AC6) is the evidence it matters.
- **AC3** `guardengarde` → `ready`, ALTSET1 frames 158/170/171 → CHTAB4.GD #8/#19/#20 — §3C, with why.
- **AC4** overlap — steps 13-21 of each lap, §3E.
- **AC5** four slots, per actor per page — §3F.
- **AC6** overlapped cells counted, exact at every one — **357 both-opaque cells and 1,254 B of frame
  overlap across steps 13/15/16/17/19/21/40, 0 wrong; the guard's 273-B frame 0 wrong at all 13 steps.**
  The control (per-actor interleave, built, run, and reverted — source sha1 `AC77A36A…` restored and
  verified): steps 15/16/17/19/21/40 wrong by 59/73/53/37/7/73 B, all inside the guard's frame; 12/22/46
  exact. P3.32's asymmetry, reproduced.
- **AC7** no-history prediction, 13 steps — 15360/15360 EXACT each, twice (before the control and on the
  final binary).
- **AC8** positions — kid: transcription = `seq_graph` over 80 steps, and frames 1..11 = the oracle trace
  and `oracle_step_trace.txt`. Guard: transcription = `seq_graph` over 80 steps; **the trace cannot check
  him** — its opponent record is constant over the run (1 distinct value): the demo's guard is not on
  screen 1.
- **AC9/AC10/AC11** — §5's table.
- **AC12** — §5's peel-skip figures, computed, not built.
- **AC13** — **pending Jay**, live-disk (§5).
- **AC14** — suites 512 KB: introseq, integ, tile, char, **kidrun** PASS; 128 KB: tile PASS.
- **AC15** — `main` `32b5fe2` at both ends; `origin/main` the same.
- **AC16/AC17** — §6.

### 5 — Verdict-time evidence

**Cost (AC9-AC11).** 72 steps each, the same three-pass binary; the one-actor control is `kr_nact=1`.
Cycles per step, means (debugger `totalcycles`; IRQs inside a phase are in it):

| phase | one actor | two actors | second actor adds |
|---|---:|---:|---:|
| seq | 413 | 821 | +408 |
| erase | 8,676 | 16,740 | +8,064 |
| save | 9,082 | 17,445 | +8,363 |
| draw | 18,113 | 33,372 | +15,259 |
| fore | 6,264 | 6,376 | +112 |
| **total** | **42,549** | **74,757** | **+32,208 (+76%)** |
| worst step | 52,358 | 84,808 | |
| share of the oracle's time, mean (max) | 24.7% (35.5%) | **42.6% (58.4%)** | |
| cadence | 10.01 fps | **9.99 fps** | oracle 9.65 |
| worst step / the paced budget (6 × 29,859) | 29.2% | **47.3%** | |

- **The peel and the draw double; the fore pass and the sequencer do not.** The guard's erase+save
  (+16,427) is the kid's (17,758) less his smaller frame (273 B against the kid's up to 400); his draw
  (+15,259) is under the kid's (18,113) for the same reason. The fore pass is ONE pass over the union
  rectangle: +112 cy (+1.8%). Its bimodal cost (~14,000 cy at steps 1-9 of a lap, ~1,700 after) is the
  kid near the post, in both runs. The sequencer does double (+408), at 1% of the step.
- **What the 42.6% is a number of:** both actors' seq + peel + draw + fore, per step, against the ORACLE's
  durations for the KID's run frames 1-14 from P5.21's trace — a one-actor scene, the only durations the
  trace has for these frames. The oracle with a guard on screen would itself spend more per step, so this
  share overstates the port's relative cost if anything. It is not a frame budget and not a share of a
  mean step.
- **P3.21's question, answered for gameplay:** the second character does not cross the budget here. The
  worst step uses 47.3% of the six display frames the run is paced to; the cadence is still pinned by
  `WK_SPEED` (9.99 against one actor's 10.01).

**The peel-skip, computed from the table (AC12) — not implemented:**
- **P3.32's frame-level skip** (skip only when NOTHING moved): **worth 0 cy here** — the kid moves every step.
- **A per-actor skip for the static guard** (P3.21's premise, which P3.32 calls false with two characters):
  his erase+save is **16,427 cy/step (22% of the step)**; with his draw as well, 31,686 (42%) — but the draw
  cannot be skipped while the kid overlaps him (9 of 24 steps), so ~25,900 cy/step averaged over a lap.
  It would need a rectangle-intersection test and its own failure mode (P3.32 §6 declined that trade).
- **Worth in what Jay sees: nothing at present.** Cadence is pinned by `WK_SPEED` with 52.7% of the paced
  budget unused at the worst step; a skip would matter only once a step's work approaches six frames.

**25.1 fresh tool output (verbatim excerpts):**
```
kidrun_plan: kid    `startrun` -- hand transcription vs seq_graph's parse of SEQTABLE.S, 80 steps: IDENTICAL
kidrun_plan: guard  `guardengarde` -- hand transcription vs seq_graph's parse of SEQTABLE.S, 80 steps: IDENTICAL
kidrun_plan: kid positions vs the ORACLE's trace (frames 1..11, display frames 7949..8002): IDENTICAL
kidrun_plan: ... and against build/tmp/oracle_step_trace.txt itself: IDENTICAL
kidrun_plan: the trace's opponent record over the same frames: 1 distinct value(s) -- constant: no guard on screen 1 in the demo, so the guard is checked against seq_graph only
kidrun_plan: 24 steps per lap (wrap after step 24, CharX 120 < 122); peel needs <= 400 B of 400 (kid), 273 B of 320 (guard) per page; frames on screen: ALL
kidrun_plan: the frames OVERLAP at steps [13, 14, 15, 16, 17, 18, 19, 20, 21, 37, 38, 39, 40, 41, 42, 43, 44, 45] (laps 1-2)
kidrun_plan: the guard's frames carry Fsword index [8] -- SWORDTAB, a separate CHTAB3 sprite, NOT drawn (P5.32 §8: the sword is out of scope)
kidrun_plan: -> build/gen/kidrun_gen.s (streams: kd1 2239 B of 2560, kd2 3254 B of 3584, kd3 1379 B of 3328; guard images [8, 19, 20] in ['kd3'])
[kernel-identical] OK — $7900 is byte-identical in both images (1105 B).
build/assets/kidrun_c.raw: 1379 B -> build/kidrun_gate.dmk tracks 7..7 (18 sectors via writesector, 3229 B pad)
=== BUILD COMPLETE ===

run_kidrun_test.sh 16 (final binary B9EB8733):
  15360/15360 identical, 0 differ  (100.00%)  -> EXACT
  step 16  guard frame       273 B, 0 wrong
  step 16  frames overlap    266 B, 0 wrong
  step 16  both opaque        92 B, 0 wrong
  OVERLAP EXACT  step 16: 92 both-opaque cells, 266 B of frame overlap
[the same EXACT for steps 6, 12, 13, 15, 17, 19, 21, 22, 24, 26, 40, 46]

CONTROL (per-actor interleave, reverted):
  step 15  15301/15360  guard frame 59 wrong   both opaque 23 of 54 wrong
  step 16  15287/15360  guard frame 73 wrong   both opaque 43 of 92 wrong
  step 17  15307/15360  guard frame 53 wrong   both opaque 17 of 87 wrong
  step 19  15323/15360  guard frame 37 wrong   both opaque 14 of 29 wrong
  step 21  15353/15360  guard frame  7 wrong   both opaque  3 of 3 wrong
  step 40  15287/15360  guard frame 73 wrong   both opaque 43 of 92 wrong
  steps 12, 22, 46  EXACT

[suites] running: introseq integ tile char kidrun   (-ramsize 512K)  ... [suites] ALL PASS
[suites] 128 KB: running: tile ... [suites] ALL PASS
```
25.2: N/A — ROM build, no sibling-import artifact.
**25.3: OBSERVED BY JAY — A DEFECT FOUND; NOT PASSED.** live-disk, 512 KB, RGB, motion
(`run_kidrun_live.sh`). Jay, verbatim: *"the guard doesn't animate is he supposed to? also it appears the
guard is a bit too 'transparent' when the kid passes by him"*.
- **"doesn't animate" — by design here.** `ready` plays 158, 170, then holds 171 (`:loop db 171 / goto
  :loop`); the oracle's guard leaves that stance only when AutoCtrl drives him (out of scope, §8).
- **"too transparent" — a real fidelity gap, found in the source after the gate.** The oracle draws the
  kid and the guard with **`OPACITY = mask`**: `DrawNormal` [GAMEBG.S:432-437] (DRAWGUARD → DrawNormal or
  DrawShifted, both `lda #mask`). `MLayMask` ANDs the screen with `MASKTAB` [HRTABLES.S:219-234] before
  ORing the image: MASKTAB[b] clears the bits of `b` AND one pixel either side of each (e.g. `$01 → $FC`,
  `$02 → $F8`), so every character carries a one-pixel black border horizontally and gaps of 1-2 px inside
  him are filled black — he OCCLUDES what is behind him. The port treats every index-0 pixel as
  transparent (P3.18 §3B: "Transparency is index 0 with no sidecar"), so the kid shows through the
  guard's border and small dark gaps. **The suite could not see it: the prediction uses the same
  index-0-transparent model** (it is exact against the port's model, not the oracle's). The same gap is
  present for every character against the background, and in the shipped cutscene (P3.18's choice) —
  any fix there moves prod bytes and is Jay's. Not fixed in this dispatch (hard stop at the gate); §8.5.
- **Residue — none (Jay, asked directly): *"nothing left behind"*.** The three-pass peel holds on the live
  machine through the overlap: the gate's peel question PASSES; the character-mask finding stands open.
Original question put to Jay:
does the pair look right in motion, and does either leave anything behind — especially where they overlap
(steps 13-21 of each lap: from about 1.2 s into every 2.4 s pass, for about 0.9 s). Not asked: combat, collision, the guard's AI,
the room boundary, single-frame pixels, the sword.
PNGs (surfaced, not read): `build/kidrun_step{6,12,13,15,16,17,19,21,22,24,26,40,46}.png`.

### 6 — Reactive deviations and route accounting
- **A third disk read (kd3)** — not in the dispatch; forced by memory (§3H). +1.7 s of boot.
- **kd2 moved `$2000` → `$2200`** — the three-pass prog passed `$2000`; caught by the map check.
- **The cycle instrument was rebuilt** (§3G) — the dispatch's numbers could not be taken from the old one.
- **`kidrun` added to the suites, default step 14 → 16** — AC14 names it; 14 is no longer predicted.
- **A control build was run and reverted** — not asked for; it is what makes AC6's zero a discriminating zero.

**AC16 — what is NOT being proposed:** no peel-skip (computed only); no `AutoCtrl`, combat, collision,
input, room change; no sword; no guard movement; no change to `xf_blit`, the HAL, `fore_draw`, or any prod
binary; no stagger/transform cache; no `lz_unpack` fix.

**AC17 — route accounting.** Proposed in this dispatch's own work: none beyond the deviations above. Carried
from P5.31b: the drive-hold between the loader's reads (§8.1 there) — **not done**; with three reads it is
now worth ~2 spin-ups.

### 7 — Uncertainty flags
- The oracle's durations are one-actor (§5). No trace here has the oracle's per-step time with two actors
  on a screen; combat would be the place to measure it.
- The guard's facing-right placement is derived from MLayGen and checked by byte-exactness against a
  reference built from the same derivation, not against an oracle frame of a right-facing guard. Jay's eye
  is the independent check.
- Timings are MAME's wd_fdc (idiom 29), not a real CoCo.

### 8 — Follow-up candidates
1. The drive-hold across the loader's three reads (P5.31b §8.1) — now three spin-ups.
2. The guard's sword (SWORDTAB 8, CHTAB3) — the next thing the oracle draws that this does not.
3. An oracle trace with kid + guard on one screen, for a two-actor denominator.
4. **§2G's sibling-path line (carried, §8 of the dispatch): `C:\Projects\karateka_coco3` IS a junction**
   to `C:\Users\jayse\DEV\karateka_coco3` — and so is every entry under `C:\Projects` (8 of 8: karateka_coco3,
   coco_agi, methodology-candidate-pool, POP3_port, pop-oracle-build, agi-games,
   karateka_dissasembly_claude, scummvm; all created 2026-09-05; `dir /AL C:\Projects`). The two paths
   name one tree on this machine. The edit is the Orchestrator's (§2D).

5. **★ The character mask (Jay, 25.3).** Draw characters the oracle's way — MLayMask: the screen ANDed with
   MASKTAB (a one-pixel horizontal border around every lit pixel cleared to black), then the image ORed.
   Bake the border into the streams as OPAQUE black: the stream format already carries (mask, src) merge
   bytes, so this is a bake change, not a blitter change, and costs bytes and cycles to be measured. The
   prediction must move to the oracle's model in the same change, or the suite stays blind to it. Gameplay
   first; the cutscene shares the model and moving it is a prod change for Jay.

### 9 — User interaction during task
None before the gate. At the gate: "yes" (launch it); then *"the guard doesn't animate is he supposed to?
also it appears the guard is a bit too 'transparent' when the kid passes by him"* (§5 25.3); asked whether
anything was left behind: *"nothing left behind"*.

### 10 — Candidate(s) captured this task
None.

### 11 — Commit
`0eebcbe`  (pushed to origin/wip before the gate; this line in the follow-up commit). `main` untouched.
