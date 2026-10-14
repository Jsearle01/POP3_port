## Form B Report — P5.37 — a block map in the port, proven against the oracle's own; the guard goes en garde
**Class:** build. wip. Prod byte-identical — `intro_seq.bin` `08BCAE4A`, `loader.bin` `10BDDBD5`, `cutscene_room.bin`
`D5B17B6D`, `flame_cels.bin` `92DC6D96`, unchanged at both ends. `main` `32b5fe2` at both ends.

### 0 — Receipt / status (C-35 stamp)
t0=2026-10-14 21:55:44Z (HEAD `5fa8280`, wip — as drafted). git status clean of tracked changes at receipt.
Jay, 5 minutes in: *"if you have a clear next step then continue"* — §1's stop report was interrupted and the
dispatch carried on from the ruling recorded in P5.37 §1's findings below.

### 1 — Summary
**§1 — the map is proven.**
- **BROAD:** at load, the port's parse of LEVEL0 matches the oracle's own blueprint in every section. That is
  2304/2304 bytes, dumped from the oracle's physical aux RAM.
- **NARROW:** every RDBLOCK either controller made in the window matches the oracle: the guard's 57, the kid's 9
  on his fight path, and the 3 from his DEMO walk at game frame 193. So do all 26 distinct queries behind all
  1978 RDBLOCK calls in game frames 180–217, including 10 that cross a screen edge.

**§2–§3 — the guard runs his own AI on the 6809.** The code is `src/engine/guard_ai.s`, transcribed from the
source, reading a writable block map baked from `bg_compose.Blueprint`.
- **His record:** all 16 bytes are **byte-identical to the oracle's after every one of the 38 game frames**
  (180–217).
- **RND calls:** zero.
- **guardprog:** goes 5 → 11 at game frame 215, written by the kid's controller as the oracle does it.
- **Second derivation:** a host transcription (`guard_model.py`) also reaches 38/38. Both derivations are compared
  against the oracle's trace, not against each other.
- **Negative controls:** both fail the check, as they must. Forcing EnemyAlert to 1 makes 10 of 38 game frames
  differ from 208, with at least 5 B differing in each. The map control (one block read as space) also makes 10 of
  38 differ from 208, with at least 3 B in each. In that run EnGarde takes `:gap` → **DoRetreat**: the map decides
  the advance.
- **Cost:** the logic costs **4,665 cycles per game frame** (worst 7,247) at a measured 29,852 cycles per frame.
  That is 15.6% of one display frame.
- **25.3:** **PASSED — Jay, live-disk, RGB, LEVEL0 screen 4.** This came after one fix: the first gate never drew
  the guard standing.

### 2 — Files modified
- `src/engine/guard_ai.s` — NEW: the window's AI.
  - The map, `rdblock`, `getunderft`, `getinfront`, `get2infront`, `cmpspace` and `cmpbarr`.
  - The 16-byte Char/Op/Kid/Shad records and Load/Save-with-Op.
  - DoKid before DoShad.
  - AUTOCTRL, GuardProg, Alert, EnGarde, the AUTO latches, GENCTRL, GuardCtrl, FightCtrl, the CTRL Do*, clrall,
    jumpseq, ANIMCHAR, REREADBLOCKS/GETFRAMEINFO and getopdist.
  - The LCG, as its own routine.
  - Traps for every branch that is not built.
- `src/engine/kidrun_probe.s` — `ifdef GA_WINDOW`:
  - One actor (the guard), driven by the AI and given his own 768 B peel per page.
  - The seed drawn first in every lap, and the loop/hold.
  - The run-mode byte, and the `ws_place` label.
  - The non-GA build is byte-identical: `kidrun_probe.bin` `58F37AC2`.
- `link/pop_engarde.link` — NEW.
- `build.bat` — the engarde block:
  - the plan, then assemble, link and the overlap check;
  - the same loader under new defines, and the kernel check;
  - screen 4's page, baked by tile_screen1's own path;
  - `build/engarde_gate.dmk`, carrying GUARD.BIN, plus a read-back check.
- `harness/tools/oracle_blueprint.{lua,py}` — NEW: the BROAD/NARROW/EDGES instrument. The verdict counts a
  difference AT LOAD, or inside a controller; it no longer counts the game's runtime mutations.
- `harness/tools/oracle_rdblock_vectors.py` + `harness/data/p537_rdblock_vectors.json` — NEW: the oracle's 26
  distinct queries with their answers, its 69 controller calls, and its 3 `cmpbarr`, as committed test vectors.
- `harness/tools/guard_model.py` — NEW: the host transcription, `--xref` and `--control ea|map`.
- `harness/tools/engarde_plan.py` — NEW: the window's data.
  - The map.
  - The oracle's assembled sequences: those reachable from the four `jumpseq` targets and the seed.
  - The replays and the seed.
  - The equates and the 96-byte probability table, taken from the listings.
  - The peel-size check.
  - The expectation file.
- `harness/tools/engarde_test.py`, `harness/smoke/run_engarde_test.sh` — NEW: the gate run and the two controls.
- `harness/tools/engarde_cost.py`, `harness/smoke/run_engarde_cycles.sh` — NEW: AC14.
- `harness/smoke/run_engarde_live.sh` — NEW: the gate.
- `harness/tools/kidrun_cycles.lua` — the phase list (`P_PH`) and the file name (`P_FILE`) are now parameters. With
  neither set, the log is the same format as before; kid-run re-measured 78,285 mean / 90,478 worst against P5.35's
  78,299 / 90,478.
- `harness/smoke/tile_test.lua` — `P_POKE8` and `P_DUMPMEM`, both env-gated; unset changes nothing.
- `harness/smoke/run_suites.sh` — adds `engarde`.

### 3 — Reasoning

**3A — §1, what was baked, decided by measurement (AC2, AC3).**
- **BlueSpec is omitted:** across the whole trace, no instruction inside either controller reads through the
  BlueSpec pointer (`($26),y`).
- **Window consumers use only the objid:**
  - FightCtrl: `getunderft / cmp #loose`;
  - EnGarde: `getinfront / cmpspace / get2infront / cmpspace`;
  - the kid's DEMO: `cmpbarr`.
- **What is baked:** **BLUETYPE 720 B** (24 screens × 30) **+ MAP 96 B** (24 × 4: left, right, up, down). P5.36's
  "~720 + ~96" was exact.
- **LINKLOC / LINKMAP / INFO are not baked:** they serve gates and triggers, i.e. physics.
- **One reader:** the table is emitted from `bg_compose.Blueprint`, the bakes' own parser. The HAL is untouched:
  `[hal-sync] OK`, and no file under `src/hal` changed.
- **★ The oracle MUTATES BLUETYPE at runtime.**
  - Loose floors that fall become space: screen 2 (7,0)/(8,0) before the window, and screen 4 (8,0)/(7,0) at game
    frames 206 and 210.
  - Floor becomes rubble at screen 5 (7,2)/(8,2).
  - So the port's map is writable RAM.
  - The test bed seeds the oracle's game-frame-179 state, which is 4 B away from the file (`ga_mapseed`).
  - The collapses at 206/210 are physics and are not reproduced. None of the 66 controller reads in the window
    touches them; the 28 RDBLOCK calls that see them are all physics.

**3B — AC1, all from the oracle (tier 2), not from the parser.**
- **BROAD:** see §5.
- **NARROW:** the 6809 logs every map read with its arguments. The guard's 57 and the kid's 9 (fight path) match
  the trace in game frame, arguments, answer and order.
- **Self-test:** every distinct query the oracle made in the window is answered on the 6809's map at seed time.
  - That is 26 queries covering all 1978 calls.
  - The two that change answer mid-window are compared with their answer before the change.
- **EDGES:** all 10 match. Named, both sides:
  - screen 4 (−1,0) → screen 24 (9,0) = $03;
  - screen 4 (10,0) → screen 2 (0,0) = $13;
  - (4..10,−1) → the screen above, which is 0, read as a solid block = $14.
- **`cmpbarr` ×3:** gate $04 → 1, gate $04 → 1, loose $0B → 0. All match the oracle's return values.

**3C — §2's boundary, built and not built (AC4, AC5, AC6).**
- **Built:** the dispatch's list.
- **★ Three findings that the list did not name, each reported rather than transcribed quietly:**
  1. **ANIMCHAR and REREADBLOCKS (GetFrameInfo + GetBaseBlock).** jumpseq without the sequencer moves nothing, and
     **BlockX in the compared record is made by REREADBLOCKS**: it changes 2→1→2→3 across the window. It needs the
     frame table's Fdx/Fcheck, the altset rule, and BlockTable. BlockTable is computed exactly as TABLES.S
     generates it, `(x+68)/14 − 9`, rather than stored (§2I).
  2. **DoRetreat (AUTO and CTRL).** The window never enters it; **the map control does.** A control that trapped
     instead of retreating would not show the map deciding anything.
  3. **`cmpbarr` is NOT in frames 215–217.** The trace puts all three calls at **game frame 193**, in the kid's
     DEMO → AUTOPLAYBACK → `DoStartrun` path, which is his replayed walk and out of scope. His 215–217 path makes
     9 RDBLOCK calls and no `cmpbarr`. It is built and verified against those three traced calls.
- **Not built** (each ends at `ga_trap` with a code): FollowKid, InRange, GenFight, the Maybe*, DoTurn, DoStrike,
  DoBlock, `demo`, the kid's non-fight GENCTRL, CHECKSTRIKE/STAB, and all physics after ANIMCHAR.
  - The host model transcribed `enemycoll` and `checkfloor` once (`5746a96`). Both were inert across 38/38 frames
    and were then removed.
- **Records and order:** DoKid then DoShad, with `LoadKidwOp` / `LoadShadwOp` / `SaveShad`. The kid's controller
  runs only on DemoCtrl's en-garde branch (guardprog 10, AutoCtrl, guardprog 11, GenCtrl). Otherwise his record is
  the replay.
- **`AUTO.S:164`:** the kid skips the three decrements. This is implemented and **unexercised**, because all three
  timers are 0 throughout.

**3D — AC7.**
- **`ga_rnd`:** `(5·RNDseed + 23) mod 256` [GRAFIX.S:1386], seeded **A1** from the game-frame-179 record, counting
  its calls.
- **The probability table:** 96 B (8 rows × guardprog 0..11), read from AUTO.LST, documented as `rnd < p` (even 255
  fails 1 in 256). **Nothing in this window uses either.**
- **Scope of the zero:** the port's main loop does not call `rnd` per frame as the oracle's does, so "0" means zero
  in the controllers.
- The flames' RNG is untouched.

**3E — AC10, two derivations.**
- `guard_model.py` (Python) and `guard_ai.s` (6809) each transcribe the source.
- They share only DATA readers: the LST tables and the oracle records.
- Each is compared with the oracle's trace and never with the other.
- They agree on everything, including the controls' margins.
- **Writing the 6809 side surfaced two latent bugs in the Python side:** CTRL DoAdvance's `fastadvance` for the
  kid, and `tap 2` also setting `alertguard`. Neither is reached in the window; both were fixed before the 6809 was
  written.

**3F — The peel overrun (a defect found and fixed in this build).**
- P5.32 sized the guard's peel at 320 B per page, checked over the `ready` frames.
- The advance's frames need up to 468 B (image 15).
- The first 6809 run overran page B's buffer into $3600.
- **It was found because** the self-test's first answer came back $08 with a `cmpbarr` byte of $08, which
  `cmpbarr` cannot return.
- **The fix:** the guard, as the only actor, gets $3000–$35FF (768 B per page), and `engarde_plan.py` now fails the
  build if any frame he can show needs more.
- The kid-run build is unaffected: its guard shows only `ready`, which fits 320 B.

**3G — §2H.**
1. **Second mechanism:** yes, twice. The map has a second writer (the game mutates it), and the compared record
   has a second maker (REREADBLOCKS).
2. **Callers, named:**
   - DoShad → ShadCtrl → SHADCTRL → AutoCtrl / GenCtrl.
   - DoKid → ctrlplayer → PLAYERCTRL → DemoCtrl → AutoCtrl / GenCtrl.
   - RDBLOCK ← getunderft (FightCtrl), getinfront / get2infront (EnGarde).
   - `cmpbarr` ← DoStartrun (DEMO).
3. **Reports cited:** P5.36 §3B, §3C and §3D; P5.35 §3C (the baseline); P5.32's GD_PEEL sizing.

### 4 — Verification (AC-by-AC)
- **AC1** — MET: §3B and §5. BROAD is exhaustively clean at load.
- **AC2** — MET: BLUETYPE 720 B + MAP 96 B. BlueSpec is omitted on measurement (0 reads in either controller).
- **AC3** — MET: from `bg_compose.Blueprint`; HAL untouched.
- **AC4** — MET, with the three findings in §3C reported.
- **AC5** — MET.
- **AC6** — MET; unexercised.
- **AC7** — MET; unused in this window.
- **AC8** — MET: 38/38 byte-identical. Seq is compared through `sq_XXXX` = the oracle's SEQTABLE address.
- **AC9** — MET: 0.
- **AC10** — MET.
- **AC11** — MET.
  - EnemyAlert forced to 1: 10/38 frames differ from 208; **minimum margin 5 B**.
  - Map control (screen 4 (3,0) read as space): 10/38 differ from 208; **minimum margin 3 B**; the guard is in
    `retreat` at 208.
  - ★ **The dispatch's alternative, "guardprog forced to 0", would NOT discriminate**, because nothing in the window
    reads guardprog.
- **AC12** — MET: written by DemoCtrl's 10/11 and checked per frame against the oracle (5 → 11 at 215). ★ This is
  **untested by the gate in the sense the dispatch means**: nothing in the window reads guardprog, so a hardcoded 11
  at 215 would pass.
- **AC13** — MET. The three divergences are labelled where a reader of the harness meets them: the `guard_ai.s` and
  `engarde_plan.py` headers, each emitted table, `guard_model.py`, and `run_engarde_live.sh`. The 179 state comes
  from this project's own instruments: `oracle_path` for the records and globals, and the `oracle_blueprint` F8882
  aux dump for the map.
- **AC14** — MET.
  - Logic: 4,665 cy per game frame mean, 7,247 worst (game frame 216, Posn 163).
  - Everything per game frame: 39,717 mean / 55,666 worst = 14.8% / 20.7% of the 9-frame pace.
  - Against the oracle's own time per game frame (6–13 display frames): 14.9% / 21.1%.
  - Against P5.35's baseline (one actor, 46,655 / 58,551): the logic is 10.0% of it.
  - Cadence: 9.03.
- **AC15** — screen 4. `bake_screen.py --screen 4` bakes it **EXACT (15360/15360)** by the existing path, with no
  new code; only build plumbing was added. Tileset 02 was not needed.
- **AC16** — MET: the four sha1s are identical before and after.
- **AC17** — MET.
  - 512 KB: introseq, integ, tile, char, kidrun, engarde **ALL PASS**.
  - 128 KB: `tile` PASS.
  - `git status content/chars` = 0.
- **AC18** — MET: live-disk.
- **AC19** — MET: `32b5fe2` at both ends.
- **AC20** — §6. **AC21** — §6.

### 5 — Verdict-time evidence
```
oracle_blueprint (BROAD, at load): frame 7900 aux : BLUETYPE ==  BLUESPEC ==  LINKLOC ==  LINKMAP ==  MAP ==  INFO ==
  -> the level lives in the AUX bank      ...  oracle_blueprint: PASS
guard_model: 38 of 38 game frames byte-identical to the oracle's S= record
xref: guard-ctrl map reads, game frames 180-217 -- oracle 57, model 57: IDENTICAL (coordinates, answers, order)
xref: kid-ctrl map reads, game frames 180-217 -- oracle 9, model 9: IDENTICAL (coordinates, answers, order)
guard_model: CONTROL enemyalert -> 10 of 38 game frames differ (first at gf 208); fewest differing bytes in a differing frame 5
guard_model: CONTROL map -> 10 of 38 game frames differ (first at gf 208); fewest differing bytes in a differing frame 3
```
25.1 fresh tool output (verbatim):
```
[hal-sync] OK -- HAL source aligned with karateka_coco3, coco_agi (11 files compared, EOL/guard/export-placement normalised)
engarde_plan: map 720+96 B (the oracle's 179 state differs in 4 B: ['scrn 2 (7,0)', 'scrn 2 (8,0)', 'scrn 5 (7,2)', 'scrn 5 (8,2)']); 58 sequence bytes from 5 roots (guardengarde,advance,fastadvance,retreat,seed); kid replay 39 records; EnemyAlert 38; vectors 26
  GUARD.BIN            1257      1257  ok
=== BUILD COMPLETE ===
engarde_test [gate]: ga_err 0, game frames run 38 of 38, RND calls 0, map reads logged 66, mode $02
AC8  the guard's record, 38 game frames: ALL IDENTICAL to the oracle's S=
AC9  RND calls: 0 -- zero, as the window is
AC12 guardprog per game frame: IDENTICAL; 5 -> 11 at gf 215 (the KID's controller, DemoCtrl)
AC1  NARROW guard-ctrl: the 6809's 57 map reads vs the oracle's 57 -- IDENTICAL (game frame, arguments, answer, order)
AC1  NARROW kid-ctrl: the 6809's 9 map reads vs the oracle's 9 -- IDENTICAL (game frame, arguments, answer, order)
AC1  SELF-TEST: 26 distinct queries (all 1978 the oracle made in the window) on the 6809's map: ALL MATCH the oracle's answer
AC1  EDGES -- screen 4 block (-1,0): 6809 $03, oracle $03 ==   screen 4 block (10,0): 6809 $13, oracle $13 ==  (+8 more, all ==)
AC1  CMPBARR x3 (the oracle's, gf [193], DEMO -> DoStartrun): $04 -> oracle 1, 6809 1, $04 -> oracle 1, 6809 1, $0B -> oracle 0, 6809 0  IDENTICAL
[run_engarde_test] PASS (gate)
engarde_test: CONTROL ea -> 10 of 38 game frames differ (first gf 208); fewest differing bytes in a differing frame 5
engarde_test: CONTROL map -> 10 of 38 game frames differ (first gf 208); fewest differing bytes in a differing frame 3
  -> the guard's Seq at gf 208 is oracle $31AC, Posn 160: the RETREAT sequence ($31A4-$31B1) -- EnGarde took :gap -> DoRetreat
engarde_cost: CLOCK MEASURED 29852 cycles per real frame -- 1.79 MHz (double speed, $FFD9)
  ★ THE LOGIC (ga_frame): mean 4665, min 4151, max 7247 cycles per game frame = 15.6% of one display frame
[suites] 512K: introseq PASS, integ PASS, tile PASS, char PASS, kidrun PASS, engarde PASS (gate) -- ALL PASS
[suites] 128K: tile PASS -- ALL PASS
```
25.2: N/A — ROM build, no sibling-import artifact.
**25.3: PASSED — Jay, live-disk, RGB, LEVEL0 screen 4** (motion: the en garde and three advances, live). *"it looks
right."* The first gate run (`c7458d8`) drew no standing frame. Jay: *"he doesn't look to start standing ... he does
advance 3 times. never draws his sword."* Fixed in `04cb189`: every lap now draws the game-frame-179 seed (frame
166) and holds it 45 display frames. The sword is a separate sprite and out of scope, as stated before the gate.

### 6 — Reactive deviations and route accounting
- **Deviations:** the three in §3C. The room is screen 4 (§4 AC15), not the screen 1 the dispatch anticipated. The
  gate fix (the seed frame).
- **★ The kid is replayed and NOT DRAWN in the gate build.** His run streams would not fit beside the guard's and
  the AI, and §4 does not ask about him. Stated in the build, the runner and here.
- **Route accounting.** I proposed four things after §1:
  1. a writable map of BLUETYPE + MAP initialised from the bake;
  2. the 179 map state seeded from the oracle's dump;
  3. the window's floor collapses not reproduced;
  4. screen 1 with a "wrong room" label.

  This build does (1), (2) and (3) as proposed. It does **not** do (4): screen 4 baked exactly, so it replaced the
  label.
- **Not proposed for shipping:** anything here. It is a test bed; the run-mode byte and the logs exist for its
  harness.

### 7 — Uncertainty flags
- The window is one boot's trace. It is RNG-free, so it should not vary.
- **When EnemyAlert is read:** the replay uses each game frame's recorded value as the value GuardProg reads in that
  frame. 38/38 supports this but does not prove the timing inside the frame.
- **Pace:** 9 display frames per game frame is the oracle's mean here; it varied from 6 to 13. A pace, not a model.
- **The map control** is one byte, chosen so it bites at 208, because the guard's BlockX is 1 there. (4,0) first
  bites at 212.

### 8 — Follow-up candidates
1. The duel-vs-mechanism ruling (§5.448.9.3) gates the next window, where `rndp` and the probability table start
   being consulted.
2. Drawing the kid in this window means finding a home for his non-run streams.
3. The map's runtime mutation (loose floors) belongs with the physics.

### 9 — User interaction during task
- "if you have a clear next step then continue"
- "what do you need for my verdict"
- "he doesn't looj to start stadning ... he does advance 3 times. neer draws his sword."
- "fix it"
- "it looks right"

### 10 — Candidate(s) captured this task
`seeds/POP/live/2026-10-14-a-capacity-check-covers-only-the-inputs-it-was-run-over.md` (pushed).

### 11 — Commit
`933f1a0` (report); build `c7458d8`, gate fix `04cb189`, instruments `b937338` `5746a96` `ce7cd95` -- pushed to origin/wip. `main` untouched.
