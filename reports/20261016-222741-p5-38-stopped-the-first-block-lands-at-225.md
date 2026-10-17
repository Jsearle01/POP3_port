## Form B Report — P5.38 — STOPPED at §1: the first exchange reaches sword contact 7 game frames in
**Class:** measure (the build did not start). wip. Prod byte-identical: nothing in `src/`, `link/`, `content/` or
`build.bat` was touched. `main` `32b5fe2` at both ends.

### 0 — Receipt / status (C-35 stamp)
t0=2026-10-16 22:21:36 −04:00 (HEAD `f1283d6`, wip, as drafted). git status was clean of tracked changes.

### 1 — Summary
**§1.1's stop condition fired.**
- The AI's first random draw is at **game frame 218**, as §5.446 says.
- The first **sword contact** is at **game frame 225**: the guard's strike (DoStrike, 221) meets the kid's block
  (DoBlock, 224). TestStrike [AUTO.S:953-979] then takes its **block-success branch**: `OpPosn := 161`,
  `justblocked := blocktime`, `jumpseq blockedstrike` + `animchar`.
- So the largest window that needs no contact path is **218–224: 7 game frames**, under the dispatch's 10. **I
  stopped.**
- **The next natural boundary is 218–231 (14 game frames).** It needs TestStrike's block outcome and nothing more;
  game frame 232 is the first **stab** (OpAction 99 → CHECKSTAB → StabChar → DECSTR, the first damage).

The rest of §1 is measured, as input to the ruling:
- **Tier 2 holds:** every frame has exactly 3 non-AI draws, in the oracle's order.
- **The kid's fight cels do not fit** the current map.
- **The sword is small:** 938 B.
- **One P5.37 claim changes:** the `AUTO.S:164` timer asymmetry **is exercised** in the 7-frame window
  (`gdtimer` from 221).

### 2 — Files modified
- `harness/tools/oracle_duel.lua` — NEW: one boot; the K/S records and globals at every game-frame boundary, plus a
  register trace (SP/A/X/Y), display frames 8840–10950. The game-frame-180 anchor is the first AUTOCTRL, as in P5.36.
- `harness/tools/oracle_duel.py` — NEW: per game frame, the labels entered in each extent:
  - kid-ctrl / guard-ctrl / checkstrike / checkstab [TOPCTRL.S:512-517];
  - every RND call with its site, the routine that asked, and its value;
  - the contact markers [AUTO.S:954-1002], StabChar, DECSTR, DEADENEMY and the meters.
- `harness/tools/p538_extent.py` — NEW: §1.1–§1.4 from those.

### 3 — Reasoning

**3A — §1.1, the extent.** The contact markers fire first at:

| marker | first game frame |
|---|---|
| TestStrike `:test` (striking; is the opponent blocking?) | 224 — no contact; it returns |
| **block success** `:1` / `:11` / `:12 blockedstrike` | **225** |
| **stab** `lda #99`, STABCHAR, DECSTR | **232** |
| DEADENEMY | 406 |

The exchange is short and dense:
- **221:** the guard strikes (DoStrike), and the kid's strike gives `gdtimer := gdpatience`.
- **224:** the kid blocks.
- **225:** the block lands; `justblocked` goes 4 → 0 over 225–229.
- **226–228:** the guard blocks the kid's riposte (the second block success is at 228).
- **232:** the kid stabs.

The meter routines (UPDATEMETERS / DRAW*METER) run every frame from 178. They draw the meters and decide nothing.

**3B — tier 2's premise (§0), measured over both extents.**
- Every game frame from 218 to 231 makes **exactly 3 non-AI draws**: MainLoop's, then GETFLAMEFRAME ×2, screen 4's
  two torches.
- **They always come before every AI draw, and kid-ctrl always comes before guard-ctrl.**
- AI draws:
  - 218–224: **13** (kid 7, guard 6);
  - 218–231: **33** (kid 17, guard 16).
- CHECKSTAB makes **none** before the stab at 232; its `rndp` [AUTO.S:1022] runs only after a stab.
- **So tier 2 is buildable as specified:** advance the port's own seed 3 times at the top of each game frame, then
  let the AI draw.

**3C — §1.2, the executed path (union over the extents).**
- **Guard (218–224):** AUTOCTRL > GuardProg > EnGarde > **InRange > GenFight > MaybeAdvance / MaybeBlock /
  MaybeStrike > rndp > RND**, **DoStrike**; then GENCTRL > FightCtrl. In 218–231 he also uses **DoBlock**.
- **Kid (218–224):** the same path, through DemoCtrl's guardprog 10 → 11. He uses **DoAdvance, DoBlock and
  DoStrike**; in 218–231 he also reaches GENCTRL's **clrall** (Action 5 / 4 — mid-bump).
- **checkstrike, every frame:** LoadShadwOp, TestStrike, SaveShadwOp, LoadKidwOp, TestStrike, SaveKidwOp. In 218–231
  it also reaches **ANIMCHAR / JUMPSEQ** (the block outcome).
- **checkstab:** entered every frame; its `cmp #99` test only, until 232.
- **★ What the TESTS and CONTROLS would need that the window does not enter** (§1.2's second list):
  1. FightCtrl's CTRL DoStrike / DoBlock and their sequences (the window enters these; listed so they are not
     missed).
  2. **The probability-table control** must perturb a row/column the window actually reads. Those are, with
     guardprog 11 for the guard and 10 for the kid: **advprob** (MaybeAdvance, 218–219), **strikeprob** (MaybeStrike,
     220–231) and **blockprob** (MaybeBlock, from 224). blockprob is 255 in both demo columns, so **only
     advprob/strikeprob perturbations can move a branch before the first block.**
  3. **The seed control** needs nothing new.
  4. **The map control's P5.37 block (3,0)** is behind the guard by 218. It would need re-choosing for this window.

**3D — §1.3, can the kid be drawn? Not in the current map.**
- **His full fight set**, Fdef frames 150–189 and 207–210: **38 distinct CHTAB5 images, 13,940 B** of baked streams,
  largest peel 434 B.
- **What he actually shows** in 218–231: **12 images, 5,497 B**, largest peel 408 B.
- **The guard also needs 9 new images** in 218–231 (strike, block, retreat, ~4.2 KB), beyond the 7 P5.37 linked
  (one of which is 13 of his 13 shown).
- **The engarde build leaves:**

  | span | free |
  |---|---|
  | kd1 | 110 B |
  | kd2 | 105 B |
  | kd3 | 1,951 B |
  | prog | 389 B |

  That is ~2.5 KB against ~9.7 KB needed.
- **The peel area** ($3000–$35FF) would need 2 × 468 (guard) + 2 × 408 (kid) = 1,752 B of its 1,536, so the logs
  at $3600 move too.
- **What would have to move:** the character streams have to leave the program's 64 KB map. Two options:
  - (a) a further raw-track read into a freed span, which does not exist at ~9.7 KB; or
  - (b) streams in a **mapped bank block**. That uses blocks beyond `$0C-$0F` and **ends the 128 KB aliasing
    detector for this probe** (CLAUDE.md §2K). **That is Jay's ruling, not mine.**

**3E — §1.4, the sword, SIZED, not built.**
- **SETUPSWORD** [CTRLSUBS.S:852]: Fsword & $3F → SWORDTAB [$2F3A, (image, dx, dy)] → a CHTAB3 cel drawn as its own
  object. A live guard's sword is always visible.
- **In 218–231:** 24 of the 26 frames the two fighters show carry a sword. They use **16 distinct cels, 938 B** of
  baked streams. The largest is 18 rows × 6 bytes (cel 39, the guard's frame 159); most are 2–12 rows × 2–7 bytes.
- **Per-frame draw cost — ESTIMATE, not measured:**
  - P5.37 measured the guard's erase + save + draw at 32,844 cy over a ~400 B footprint, about **80 cy per footprint
    byte**.
  - A sword cel's footprint is 16–126 B, so **about 1.3K–10K cy per sword per game frame**, two swords in a
    duel.
  - The current total is 39,717 cy against a 268,668 cy budget (9 frames × 29,852).
- **The absence is known and sized,** for when Jay rules.

**3F — AC11 (and a correction to P5.37's report).**
- **`gdtimer` becomes non-zero at 221**: $0E, `gdpatience`, written by FightCtrl `:bts` for CharID 0 when the kid
  strikes [CTRL.S:822-826].
- It then **falls by exactly one per game frame** (0E 0D 0C 0B 0A, reset at 226 and 229). **Only the guard's
  AutoCtrl decrements it**, which is the `AUTO.S:164` asymmetry, exercised for the first time. MaybeAdvance reads it
  [AUTO.S:756].
- **`justblocked`** is 4 at 225, falling to 0 by 229.
- **`refract`** stays 0 through 231.
- P5.37's "all three timers 0 throughout" was true of 180–217 only.

**3G — §2H.**
1. **Second mechanism:** yes. **CHECKSTRIKE runs every game frame after DoShad** [TOPCTRL.S:516]. It is a third
   writer of both records, after the two controllers: it can rewrite the opponent's Posn and restart the striker's
   sequence. A port that only ran DoKid / DoShad would diverge at 225 without any AI error.
2. **Callers:**
   - NextFrame → checkstrike → CHECKSTRIKE → TestStrike ×2;
   - NextFrame → checkstab → CHECKSTAB → StabChar (232);
   - MaybeAdvance / MaybeBlock / MaybeStrike → rndp → RND;
   - FightCtrl `:bts` → gdtimer.
3. **Reports grepped:** P5.35's findings (the order, the 292 draws, the probability columns); P5.36 §3B; P5.37
   §3C / §4 AC6 (the timers, now superseded for frames from 221).

### 4 — Verification
- **AC1** — MET, and it **STOPS** the dispatch: 7 game frames (218–224). The reason is the block at 225. Next
  boundary 231 (14), then 232 (the stab).
- **AC2** — MET (§3C), with the separate tests/controls list.
- **AC3** — MET as measurement (§3D): it does not fit; what would have to move is stated.
- **AC4** — MET (§3E).
- **AC11** — MET (§3F).
- **AC5–AC10, AC12–AC16** — not reached (stopped at §1, as the dispatch directs).
- **AC17** — `main` `32b5fe2` at both ends.
- **AC18 / AC19** — §6.

### 5 — Verdict-time evidence (verbatim)
```
oracle_duel: 271 game frames traced (180 = trace frame 2); last = gf 448
§1.1 first AI draw: gf 218
§1.1 contact markers, first game frame: {'TestStrike:block(:1)': 225, 'TestStrike:block(:11)': 225, 'TestStrike:blockedstrike(:12)': 225, 'TestStrike:STAB(#99)': 232, 'STABCHAR': 232, 'DECSTR': 232, 'DEADENEMY': 406}
§1.1 EXTENT without the contact path: gf 218-224 = 7 game frames (ends because gf 225 needs ['TestStrike:block(:1)', 'TestStrike:block(:11)', 'TestStrike:blockedstrike(:12)'])
     next boundary: gf 218-231 = 14 game frames, if TestStrike's BLOCK outcome is built (the first stab -- StabChar/DECSTR, damage -- is gf 232)
tier 2, gf 218-224: non-AI draws per game frame {(3, ('main-loop', 'other', 'other')): 7}; order main->torches->kid->guard->checkstab broken in 0 frames []
     AI draws: 13 (kid 7, guard 6, checkstab 0)
tier 2, gf 218-231: non-AI draws per game frame {(3, ('main-loop', 'other', 'other')): 14}; order main->torches->kid->guard->checkstab broken in 0 frames []
     AI draws: 33 (kid 17, guard 16, checkstab 0)
§1.3 the kid's FIGHT cels (Fdef frames 150-189, 207-210): 38 distinct images, 13940 B of baked streams, largest peel 434 B; not baked: none
     ... of which the kid SHOWS in gf 218-231: frames [152, 155, 156, 157, 158, 161, 162, 164, 165, 167, 169, 170, 210] -> 12 images, 5497 B, largest peel 408 B
sword: distinct sword cels 16, 938 B of streams
scratch hdv md5 before/after: C4F0B13E49B77DD0FBC5063E27E53A24 (unchanged)
```
25.1 / 25.3: none (no build, no gate).

### 6 — Deviations and route accounting
- Stopped at §1, as directed. §1.2–§1.4 were completed as **measurement only**, because the ruling below needs
  them.
- Nothing was built and nothing is proposed for shipping.
- No route was proposed before this report.

### 7 — Uncertainty flags
- One boot. From 218 the duel depends on the seed, so another boot plays a different exchange (§0). Where contact
  first lands is this boot's fact, not the game's.
- The sword cost is an estimate scaled from the guard's measured rate, not a measurement.
- The kid's and guard's image counts come from the records' Posn values. Cels not yet baked would show up as
  missing; none were.

### 8 — Follow-up candidates — the ruling this stop needs
1. **Extend to 218–231 (14 game frames), adding TestStrike's BLOCK outcome only** (not the stab). The cost:
   - ~25 lines of 6809: CHECKSTRIKE's two TestStrike calls with Load/Save-with-Op, the block branch, and
     `blockedstrike`'s sequence;
   - the window's AI as §3C lists it;
   - tier 2;
   - 9 guard cels (~4.2 KB), which also do not fit as the map stands (§3D).
   - **The decision the block exposes** — the guard's riposte decision at 226–228, guarded by justblocked's
     impaired-block path — **is the most decision-dense stretch of the exchange.**
2. **Or the 7-frame window as is.** It shows the approach (MaybeAdvance), the guard's first strike decision
   (MaybeStrike), and the kid's block decision. It would end on the strike in the air, before it lands.
3. **Either way, the memory question (§3D) comes first.** Neither extent's cels fit beside the AI in the probe's
   64 KB, the guard's own new frames included. The options are streams in a bank block (giving up the 128 KB
   detector for this probe) or a different probe layout.

### 9 — User interaction during task
None (the dispatch).

### 10 — Candidate(s) captured
None.

### 11 — Commit
(this line in the follow-up commit)
