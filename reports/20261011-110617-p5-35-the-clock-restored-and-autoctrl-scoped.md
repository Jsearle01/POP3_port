## Form B Report — P5.35 — the clock restored, the arc re-baselined, AutoCtrl scoped to a stop
**Class:** build + measure. wip. Prod byte-identical — `intro_seq.bin` `08BCAE4A…`, `loader.bin` `10BDDBD5…`,
`cutscene_room.bin` `D5B17B6D…`, `flame_cels.bin` `92DC6D96…` (sha1 at t0 and at the end). `main` `32b5fe2`
at both ends. `content/chars` untouched (0 changes). **§1–§2 end at a gate; §4 ends at a stop — no AI code.**

### 0 — Receipt / status (C-35 stamp)
t0=2026-10-11 10:50:17 (HEAD `46c6f63`, wip — as drafted). git status clean of tracked changes. Moved:
`tile_probe.bin` `B7751D2F…` → `DCA4A42A…` (and every binary that links tile_probe: the char and kid-run probes).

### 1 — Summary
**The clock:** `tile_probe.s`'s `load_track` now restores `$FFD9` after its disk read on both paths. **Measured:
14,902 → 29,855 CPU cycles per real frame** (1.79 MHz = 29,859). The kid run now holds **exactly 6.00 display
frames per step, every step (min 6, max 6)** — no step needs a seventh. `kidrun_cost.py` reads the clock from the
log and refuses to quote a share without it. **Two corrections to the dispatch:** `HAL_sys_init` does NOT set
double speed in POP (its `$FFD9` is guarded off; `HAL_gfx_set_mode` sets it), and no register-owner row is needed
(`tile_probe.s` is allowlisted). **AutoCtrl (§4), scoped by an oracle trace:** (a) is half wrong — the demo's kid is
driven by the RECORDED SCRIPT (AutoPlayback) until he draws his sword, and only then by GuardProg; (b) the seed is
initialised (to 0, at boot) but never reset, so every attract cycle plays a different duel; (c) and (d) confirmed.
The trace can serve as the AI's oracle. **P5.31's attribution of the kid's `runstop` to AutoCtrl was wrong** — it is
the script. Full findings: `reports/20261011-110617-p5-35-autoctrl-findings.md`.

### 2 — Files modified
- `src/engine/tile_probe.s` — `SAM_FAST equ $FFD9`; `sta SAM_FAST` after `lt_ok` (both paths); header note.
- `harness/tools/kidrun_cycles.lua` — the end snapshot also records the step's absolute start cycles; the log
  ends with `# CLOCK <cycles per real frame>`.
- `harness/tools/kidrun_cost.py` — reads `# CLOCK`; **fails loudly** without it, and if it is within 2% of neither
  known SAM speed.
- `harness/smoke/run_xform_probe.sh`, `mame-idioms-coco3-port.md` — the concurrent-run hazard; measure the clock.
- `harness/tools/kidrun_plan.py` — comment: the runstop is the demo script, not AutoCtrl.
- `harness/tools/oracle_rnd_trace.lua` — NEW (promoted from build/p535): the oracle instrument behind §4.
- `reports/20261011-110617-p5-35-autoctrl-findings.md` — NEW: the §4 findings, every citation and number.

### 3 — Reasoning

**3A — The clock (AC1–AC3), source and measurement.** `load_track` [tile_probe.s:201-219]: `sta SAM_SLOW` →
`disk_read_range` → `bcc lt_ok / com probe_dskerr` → **`lt_ok sta SAM_FAST`**, so both paths restore; CC comes
back from the stack, so the caller's flags are unchanged. **Correction 1 — where double speed comes from:**
`HAL_sys_init`'s `sta $FFD9` [sys.s:264-267] is inside `ifdef HAL_SYS_FAST_CLOCK`, which POP's `hal_build.o` does not
define [build.bat:194]; the unconditional write is `HAL_gfx_set_mode` step 6 [gfx.s:500-503]. So `tile_entry` ran
sys_init (slow) → set_mode (fast) → the page read (slow, never restored). **The dispatch's conclusion stands for
the right reason:** every prod program sets a mode and every prod reader restores. **Correction 2:** no register
row — `tile_probe.s` is on the ratchet's probe allowlist by name [register-owners.tsv:23-27]; the ratchet passed
(`27 owner row(s) … 10 file(s) allowlisted`). **AC3, other readers:** loader.s:241/247, kidrun_boot.s:159/165,
cutscene_room.s:1315/1331, intro_seq.s:568/580, interp_probe.s:149/171 all bracket. `side_read_probe.s:80` and
`side_check_probe.s:142` read at 0.894 MHz BY DESIGN (no mode set; `side_read_probe.s:16-18` says so) — not the
same gap: they never claim a double-speed budget. **`tile_probe.s` was the only one.**

**3B — AC6, the framing, confirmed with one refinement.** The cycle COUNTS were always facts; the DIVISOR was
wrong; and the shipping engine runs at 1.79 MHz. Measured at the restored clock: one actor **26.7%** of the
oracle's time (26.0% of the paced budget), two actors **44.3%** mean / 59.4% max of the oracle's time and
**43.7% mean / 50.5% worst of the paced budget**. (The dispatch's 26.1 / 43.8 / 50.6 are BUDGET shares, not
oracle shares; both are given below.) **The refinement:** "the demo did the work on half a clock and still met
the cadence" holds through P5.32 (worst step 95% of the half-clock pace) and **fails at P5.34/P5.34b** — the mask's
draw cost took the worst step to 101-103% and the cadence to 9.85 fps. The fix ends that overrun; it does not buy
speed (the pace is fixed at 6 frames, 9.99 fps), which is exactly what the measurement shows.

**3C — AC5, P5.31–P5.35 in one table.** Cycle counts are what each dispatch measured (unchanged); "as reported"
divided by an assumed 29,859; "true" divides by the clock each run actually had (0.894 MHz through P5.34b — measured
14,902 at P5.35's before-run — and 29,855 after the fix). Shares are of the oracle's own durations for the frames
run; budget is the worst step against 6 × the clock.

| run | actors | cy/step mean (worst) | share as reported | **share, true** | budget worst as reported | **budget worst, true** | cadence |
|---|---|---|---|---|---|---|---|
| P5.31 | 1 | 42,420 (52,111) | 24.6% (max 35.3) | **49.3% (70.7)** | 29.1% | **58.3%** | 9.96 |
| P5.32 | 1 | 42,549 (52,358) | 24.7 (35.5) | **49.5 (71.1)** | — | **58.6%** | 10.01 |
| P5.32 | 2 | 74,757 (84,808) | 42.6 (58.4) | **85.4 (117.0)** | — | **94.9%** | 9.99 |
| P5.34 | 1 | 46,807 (58,555) | 26.8 (37.0) | **53.7 (74.1)** | 32.7% | **65.5%** | 9.99 |
| P5.34 | 2 | 79,880 (91,912) | 45.1 (60.1) | **90.4 (120.4)** | 51.3% | **102.8%** | 9.85 |
| P5.34b | 1 | 46,753 (58,675) | — | **53.6 (74.5)** | — | **65.6%** | 9.99 |
| P5.34b | 2 | 78,471 (90,664) | — | **88.9 (119.2)** | — | **101.4%** | 9.85 |
| **P5.35, 1.79 MHz** | 1 | 46,655 (58,551) | — | **26.7 (37.1)** | — | **32.7%** | **9.99** |
| **P5.35, 1.79 MHz** | 2 | 78,299 (90,478) | — | **44.3 (59.4)** | — | **50.5%** | **9.99** |

**What moved and what did not:** every cycle count is unchanged in meaning; P5.35's are 0.2% lower than P5.34b's
for the same code because fewer VBL interrupts land inside a phase when the phases take half the time (IRQ time is
inside the counts — idiom §41). Every share and every budget moved by the clock ratio, 29,859/14,902 = 2.004.

**3D — AC7, AC8.** After the fix: **6.00 frames per step, min 6, max 6, over 71 periods** — not one seventh frame,
and the 5/7 jitter of the end-of-step sampling is gone too (each step now finishes inside its first frames). **The
control (standing from here on, §3A): minimum margin 5 B** — the per-actor interleave is wrong by 48/52/43/34/5/52 B
at steps 15/16/17/19/21/40, every byte inside the guard's frame, 12/22/46 exact; unchanged from P5.34b (the clock
changes timing, not pixels). **The minimum's history: 7 (P5.32) → 5 (P5.34) → 5 (P5.34b) → 5 (P5.35), at step 21.**
Flat for three runs; the trend has stopped, not turned.

**3E — §4, AutoCtrl, scoped (AC10–AC16).** Measured by a fresh oracle trace (`oracle_rnd_trace.lua`: write taps
on RNDseed, on clrF as an AutoCtrl detector, and on the frame boundary; it reproduced P5.21's trace 320/320 K/S
records, so its frame numbers are P5.21/P5.31's), plus source reading. I re-checked the load-bearing claims
myself: DemoCtrl [CTRL.S:587-600], the tables [AUTO.S:109-124], INITSYSTEM's zero-page clear [TOPCTRL.S:120-139],
DemoProg1 [SUBS.S:1194-1197].
- **(a) Half wrong.** `KidProg jmp GuardProg` [AUTO.S:449-450] and the CharID dispatch [:163-164, :192] are right —
  but **the demo's kid is driven by the recorded script until he draws his sword**: `DemoCtrl` does `lda CharSword
  / beq :preprog` → `:preprog jmp demo` (AutoPlayback on DemoProg1); only with a sword does it run `guardprog=10 /
  jsr AutoCtrl / guardprog=11` [CTRL.S:590-597]. Trace: 461 AutoCtrl calls in cycle 1 — 269 guard, 192 kid; the
  kid's first at display frame 9211, after he draws at 9201.
- **(b) The seed is initialised, not garbage — and that is not the good news it looks like.** INITSYSTEM zeroes the
  whole auxiliary zero page at boot, RNDseed ($9E) included (caught at frame 141). It is **never reset after
  that**: 2,341 calls before the demo (cutscene torches, stars, play loop) leave it at **CB** for attract cycle 1
  and **D6** for cycle 2; the two cycles diverge at the kid's first random decision, and **every attract cycle
  plays a different duel** (cycle 1: 292 AI draws; cycle 2: 128). The LCG is exactly 5x+23 mod 256, period 256.
- **(c) Confirmed** [AUTO.S:109-124]. Columns 10 (kid) / 11 (enemy): strike 40/60, restrike 255/150, **block
  255/255**, impblock 255/175, adv 100/100, refract 0/0. Act iff rnd < p, so 255 still fails 1 in 256. **One call
  site missed:** CHECKSTAB [AUTO.S:1022] calls `rndp` only to load X, and still consumes a number. **guardprog is
  one global:** the screen-4 guard starts on program 5 (ADDGUARD, AUTO.S:1923-1928) and becomes 11 only because
  DemoCtrl writes 11 after the kid's call.
- **(d) Confirmed, comment and code agree.** NextFrame runs DoKid then DoShad [TOPCTRL.S:512-514]; the kid's
  controller runs before either fighter is animated (both PRECEDING — the exception), the guard's after the kid is
  saved (kid UPCOMING); CTRL.S:923 says `;enemy sees kid 1 frame ahead`. Trace: the kid's call at 9242 sees
  himself at posn 210 and the guard at 164 (both preceding); the guard's call at 9243 already sees the kid at 158
  (his upcoming frame).
- **AC12 — when AutoCtrl first matters:** the first call is the screen-4 guard's at display frame 8890 (game frame
  180, after the cut at 179); **the first random number the AI uses is at game frame 218** (display 9242). **179
  game frames are reachable with no AutoCtrl, 217 with no randomness.** P5.31's kid run (screen 1, game frames
  4-15) is entirely script-driven.
- **AC13 — every RND call:** cycle 1, display frames 7890-10898: **1,714** = 448 main loop (one per game frame) + 950
  torch flames (one per torch per game frame) + 7 torch set-ups + **292 AI** (strikeprob 207, advprob 25, blockprob
  24, impblockprob 21, restrikeprob 11, CHECKSTAB 4). Order per game frame is fixed: main loop → torches → kid AI →
  guard AI → CHECKSTAB. **Verdict: the trace CAN be the AI's oracle** — the order is a pure function of state the
  port would have — **provided the port starts from a measured seed at a defined checkpoint** (CB at the demo's
  start, or 66 before game frame 180). Matching cycle 1 exactly is a test choice, not a fidelity requirement: the
  oracle itself never plays the same duel twice.
- **AC14:** RNDseed's initial value: **0, from INITSYSTEM's block clear** — a grep for stores to RNDseed misses it
  because the store names `$0,x`, not the variable.
- **AC11, AC15, AC16:** GuardProg's extent [AUTO.S:455-899, plus AUTOCTRL :160-193], its full read/write surface,
  what the port lacks (screens 2 and 4, the 179-frame scripted walk and its physics, the 16-byte character record,
  ~12 globals, fight control, contact/damage, the sword sprite, the oracle's RNG in the torches), and the one-page
  proposal are in the findings file. **The proposal in one line:** first build = *"the guard goes en garde"* —
  AutoCtrl for the screen-4 guard against a REPLAYED kid over game frames 180-217, where no random number is drawn;
  test = the guard's record byte-identical to the oracle's for all 38 frames, plus zero RND calls, plus a negative
  control; seeded from oracle state at game frame 179 (a §2I test-bed shortcut, stated as one).

**§2H.** (1) Second mechanisms: two, both found — the scripted walk and the ordinary sword draw are not AutoCtrl.
(2) Calling routines: kid DoKid → PLAYERCTRL → DemoCtrl; guard DoShad → SHADCTRL; both under NextFrame.
(3) Reports grepped: P5.3 agrees (three phases); **P5.31 §3A's "runstop (AutoCtrl)" is contradicted** (corrected in
kidrun_plan.py's comment); P5.3's "~23 s demo" is contradicted (AutoCtrl alone runs 8890-10898).

### 4 — Verification (AC-by-AC)
- **AC1** — MET, with the correction that no register row is needed (allowlisted). **AC2** — MET: 14,902 → 29,855.
- **AC3** — MET: the only unbracketed reader was tile_probe.s; the two side probes run slow by design.
- **AC4** — MET: `kidrun_cost.py` reads `# CLOCK`, exits with a message without it or off both known speeds.
- **AC5** — MET (§3C). **AC6** — CONFIRMED with the P5.34 refinement (§3B). **AC7** — MET: 6.00, no seventh.
- **AC8** — MET: minimum margin **5 B** (step 21), history 7/5/5/5. **AC9** — MET (both homes).
- **AC10** — (a) half refuted, (b) refined (initialised to 0; never reset), (c) and (d) confirmed — §3E.
- **AC11–AC16** — MET (§3E and the findings file). **AC17** — MET. **AC18** — MET: 512 KB introseq, integ, tile,
  char, kidrun ALL PASS; 128 KB tile PASS; 13 kid-run steps 15360/15360; `content/chars` 0 changes.
- **AC19** — MET: PASSED live-disk (Jay: "looks correct"). **AC20** — MET. **AC21/AC22** — §6.

### 5 — Verdict-time evidence
```
BEFORE (pre-fix binary):  # CLOCK 14902.0 cycles per real frame (6348267 cycles over 426 frames, step starts)
AFTER:  kidrun_cost: CLOCK MEASURED 29855 cycles per real frame -- 1.79 MHz (double speed, $FFD9) (29859)
  ONE ACTOR   phase means: seq 413 erase 8689 save 9037 draw 22279 fore 6236 = 46655   worst 58551
              share 26.7% (max 37.1%)   CADENCE 6.00 display frames (min 6, max 6) = 9.99 fps   budget 32.7%
  TWO ACTORS  phase means: seq 821 erase 16693 save 17459 draw 36967 fore 6357 = 78299   worst 90478
              share 44.3% (max 59.4%)   CADENCE 6.00 display frames (min 6, max 6) = 9.99 fps   budget 50.5%
[reg-owner] OK — 27 owner row(s) over 14 register(s), 10 file(s) allowlisted.
=== BUILD COMPLETE ===   (prod sha1s unchanged)
kid run steps 6..46: 15360/15360 EXACT x13
CONTROL: guard frame 48/52/43/34/5/52 wrong at 15/16/17/19/21/40; 12/22/46 EXACT  -> minimum margin 5 B
[suites] running: introseq integ tile char kidrun ... [suites] ALL PASS      128 KB tile ... ALL PASS
oracle_rnd_trace self-check: F-record check: old frames 320, new frames 320 common, identical K/S 320
```
25.2: N/A. **25.3: PASSED — Jay, live-disk, 512 KB, RGB, live motion:** *"looks correct"* — the kid-and-guard run
at the restored clock (6.00 display frames every step).

### 6 — Reactive deviations and route accounting
- **Register-owner row not added** — the dispatch asked for it; the file is allowlisted, so a row would be redundant.
- **§2's sys.s:266 citation corrected** to gfx.s:502 (the guarded line is not POP's).
- **§4 was done by a delegated research agent** (read-and-measure, no tracked edits, one MAME at a time on a scratch
  copy of the oracle image, unchanged afterwards); I re-verified its four load-bearing source claims myself. Side
  effect it reported: MAME updated two files in the untracked `nvram/apple2e/` folder.
- **AC21 — not proposed:** no AI code, sword, screen 2/4, room boundary, cutscene change, `lz_unpack` fix, disk map.
- **AC22 — route accounting:** P5.34 §8.1 proposed "`sta $FFD9` after `disk_read_range` in `load_track`; a
  register-owner row; re-baseline P5.31-P5.34 at the true clock" — **done, except the row** (not needed). P5.34 §8.2
  ("the cost tool should read the clock") — done.

### 7 — Uncertainty flags
- The §4 numbers are one boot's (cycle 1 and cycle 2 of the same boot); a different boot path (a key pressed, a
  different attract entry) would leave a different seed.
- The oracle trace logs `id=` from the wrong byte ($4C); kid/guard were told apart by return address (stated in
  the instrument's header).
- Not traced: how the demo ends; EnemyAlert and the fight timers per frame (the proposal's prerequisite).

### 8 — Follow-up candidates
1. The first AutoCtrl build: "the guard goes en garde" (findings §6), with its prerequisite oracle dump at game frame 179.
2. The apple2e idioms the research found (aux-ZP write taps also fire for the other bank — filter by PC; a `jsr`→`jmp`
   tail call leaves the real caller on the stack; AutoCtrl detectable as DoRelease's clrF write) — into
   `mame-idioms-apple2e-oracle.md`.
3. Candidates for the pool (not captured here): "a block-cleared variable looks uninitialised to a grep"; "a global
   the AI reads can be owned by the other character".

### 9 — User interaction during task
None before the gate. At the gate: "yes" (launch it); "looks correct".

### 10 — Candidate(s) captured this task
None.

### 11 — Commit
`ba0fe43` (the clock, §1-§3) and `b7cf376` (this report, the findings, the instrument); pushed to origin/wip
before the gate. `main` untouched.
