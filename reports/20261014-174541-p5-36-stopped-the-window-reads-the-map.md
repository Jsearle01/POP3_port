## Form B Report — P5.36 — STOPPED at §1: the guard's AI reads the level map in every frame of the window
**Class:** measure (the build did not start). wip. Prod byte-identical — the four sha1s (`08BCAE4A`, `10BDDBD5`,
`D5B17B6D`, `92DC6D96`) unchanged; nothing in `src/`, `link/`, `content/` or `build.bat` touched. `main` `32b5fe2`.

### 0 — Receipt / status
t0=2026-10-11 11:30:48 (HEAD `a424bb7`, wip — as drafted). git status clean of tracked changes.

### 1 — Summary
**§1's stop condition fired.** Instrumented on the oracle (a full instruction trace of display frames 8840-9260,
attributed by listing addresses), the guard's controller **queries the blueprint in every game frame of the
window**: `FightCtrl → getunderft → RDBLOCK` (the block under his feet) in all 37 frames 181-217, and
`EnGarde → getinfront/get2infront → RDBLOCK → cmpspace` (the blocks in front of him, before he advances) in
all 10 frames 208-217. The dispatch says a blueprint query in the window is architecture and stops it; I
stopped. **Zero RND calls inside either controller across 180-217** — the window IS RNG-free, as P5.35 said.
§2's dump is done and confirms the starting state. The map question, sized, is §3C.

### 2 — Files modified
- `harness/tools/oracle_symbols.py` — NEW: every global code label in the oracle's 25 `.LST` listings with its
  address (2,043), cross-checked against the `jsr`/`jmp` operands that call them.
- `harness/tools/oracle_path.lua` — NEW: the instruction trace (idioms §4e) over a frame window, each line with SP,
  plus the Kid/Shad records and every §2 variable at each game-frame boundary.
- `harness/tools/oracle_path.py` — NEW: attributes the trace to game frames and to the controller extents.

### 3 — Reasoning

**3A — The instrument, and where its boundaries come from (listing addresses, not guesses).** Game frame =
MainLoop's `jsr rnd` [TOPCTRL.S:367, $218C]; kid controller = `jsr ctrlplayer` $22FD→$2300 inside DoKid
[TOPCTRL.S:644]; guard controller = `jsr ShadCtrl` $235D→$2360 inside DoShad [:711]; game frame 180 = the frame of
the first-ever AUTOCTRL entry. A first version of the label table put `rndp` at $5864 against the `20 62 58` its
own callers encode — instruction lines without labels were not consumed; fixed, and every routine below now
agrees with its callers' operands (`DoRelease` $580E, `EnGarde` $5668, `FollowKid` $5718, `InRange` $576A,
`GenFight` $5785, `GENCTRL` $3D49, `rndp` $5862, `RND` $0A52). **The $D000-$D0FF "labels" in AUTO.LST are a
jump-vector table** (`rdblock` $D021 → `RDBLOCK` $D0D0 in CTRLSUBS); the disk driver in another language-card bank
shares those addresses, so a few driver names (`handler`, `SPcmdlist`, `wrByte_`, `wrTrack`) appear inside
`RDBLOCK`'s extent in the listing below — they are address collisions, not calls.

**3B — AC1, the executed path, game frames 180-217 (the guard's controller; the kid's only from 215).**

| game frames | guard controller (ShadCtrl → AutoCtrl → AUTOCTRL → DoRelease → GuardProg → …) |
|---|---|
| 180 | `Alert → getopdist → DoEngarde → DoAdvance`, then `GenCtrl → GuardCtrl → clrall → jumpseq` |
| 181-205, 207 | `EnGarde`, then `GenCtrl → FightCtrl → getunderft → RDBLOCK` |
| 206 | as 181, plus `getopdist` ×3 inside EnGarde |
| 208-217 | `EnGarde → getopdist ×2 → getinfront → RDBLOCK → cmpspace → get2infront → RDBLOCK → cmpspace → DoAdvance`, then `GenCtrl → FightCtrl → getunderft → RDBLOCK → getopdist` (`jumpseq` at 208, 212, 216) |
| 215-217, the kid | `ctrlplayer → PlayerCtrl → DemoCtrl → AutoCtrl → AUTOCTRL → DoRelease → KidProg → GuardProg → EnGarde → …` — the same path as the guard's, including the blueprint queries |

**Entered:** AUTOCTRL, DoRelease, GuardProg, Alert, EnGarde, DoEngarde, DoAdvance, getopdist, GENCTRL, GuardCtrl,
FightCtrl, clrall, jumpseq, and the blueprint queries. **NOT entered in the window — out of scope by
measurement:** `FollowKid`, `InRange`, `GenFight`, `MaybeAdvance`, `MaybeBlock`, `MaybeStrike`, `rndp`, `RND`
(inside a controller), every `Do*` except DoEngarde/DoAdvance, and all of `CHECKSTRIKE`/`CHECKSTAB`'s contact path.
The dispatch's ~450 lines collapse to roughly AUTOCTRL + GuardProg + Alert + EnGarde's opening + two Do* + the
FightCtrl/GuardCtrl entries — **but every frame of it reads the map.**

**3C — The stop, sized for the decision.**
- **What is read:** `getunderft` (the block type under the guard's feet — FightCtrl's ground check),
  `getinfront`/`get2infront` + `cmpspace` (the next two blocks ahead, compared for open space before an advance).
  All are `RDBLOCK` lookups of the level blueprint by (screen, block X, block Y), including across screen edges.
  Counts in the window: guard controller `RDBLOCK` ×57 (getunderft 37, getinfront 10, get2infront 10), `cmpspace`
  ×20; the kid's controller in 215-217 adds `cmpbarr`. Outside the controllers, the fighters' animation and
  physics (`checkfloor`, `gravity`, `checkspikes`, `enemycoll`, …) read it hundreds of times per window — the
  next thing to need it after this.
- **What the port has:** the blueprint is parsed host-side (`bg_compose.Blueprint`, used by the bakes); the 6809
  has only a baked PAGE. **Nothing in the port can answer "what block is at (screen, x, y)".**
- **The two ways forward — Jay's/the Orchestrator's, not mine:**
  - **(A) A block map in the port:** the level's BlueType (and BlueSpec where read) per screen, 10 × 3 blocks, plus
    the screen links — LEVEL0 is 24 screens, so ~720 B of types (+ ~96 B of links), and a `rdblock` that reads it.
    Small in memory; it is the representation every later piece needs (physics, the kid's AI, collisions, gates).
  - **(B) Replay the window's map answers from the trace** — a THIRD §2I test-bed divergence alongside the
    replayed kid and the seeded scene. Gets this window's 38 frames without the map; buys nothing after it.
  - My recommendation, for what it is worth: **(A)** — it is the smallest real piece and the window's own
    discriminating test would then exercise it.

**3D — AC2, the game-frame-179 dump (F8882, the last record before the first AutoCtrl):** guard `S=A6 64 37 00 02 00
01 00 00 1F31 04 00 02 00 FF` = Posn 166, X 100, Y 55, Face right, BlockX 2, BlockY 0, Action 1, Scrn 4, ID 2,
Sword 0, Life $FF; kid `K=6C C2 37 FF FF 00 01 02 00 9C32 04 00 00 00 FF` = Posn 108, X 194, Y 55, Face left,
BlockX $FF, BlockY 0, Action 1, Scrn 4, Sword 0, Life $FF — **both exactly as P5.35 recorded.** Globals: refract
0, justblocked 0, gdtimer 0, alertguard 0, droppedout 0, offguard 0, EnemyAlert 0, KidStrength 4, OppStrength 4,
MaxOppStr 4, guardprog 5, **RNDseed A1**, milestone 0, heroic 0, gotsword 1. ★ **Correction to P5.35:** its "66
before game frame 180" is the seed AFTER frame 180's main-loop and torch draws; at the 179 boundary it is A1.
**Per frame across the window:** the three timers stay 0 throughout; **guardprog 5 → 11 between F9201 and F9213**
(game frame 215, as P5.35 found); **EnemyAlert 2 at 180, 1 for 181-~205 (one 2 at F9103), 2 from F9128 on.**
(CHECKALERT, which computes EnemyAlert, also reads the map — replaying it was already the plan.)

**§2H.** (1) Second mechanism: yes — the AI's decisions are not only `guardprog`/tables/timers; the MAP is an input
to EnGarde and to FightCtrl. (2) Callers named throughout (DoShad → ShadCtrl …; DoKid → ctrlplayer …).
(3) P5.35's findings §2 listed `rdblock` among GuardProg's reads; §6's proposal assumed the window could avoid it.
The trace says it cannot.

### 4 — Verification
- **AC1** — MET, and it STOPS the dispatch (§3B-C). **AC2** — MET (§3D). **AC3-AC14, AC16, AC17** — not reached
  (stopped at §1, as the dispatch directs). **AC15** — MET. **AC18** — MET (`32b5fe2`).

### 5 — Verdict-time evidence (verbatim excerpts)
```
oracle_path: 42 game frames in the trace; game frame 180 = trace frame 2 (first AUTOCTRL)
  gf 180  guard-ctrl: ShadCtrl > AutoCtrl > AUTOCTRL > DoRelease > GuardProg > Alert > getopdist > GETOPDIST > DoEngarde > DoAdvance > GenCtrl > GENCTRL > GuardCtrl > clrall > jumpseq > JUMPSEQ
  gf 181  guard-ctrl: ShadCtrl > AutoCtrl > AUTOCTRL > DoRelease > GuardProg > EnGarde > GenCtrl > GENCTRL > FightCtrl > getunderft > GETUNDERFT > rdData > RDBLOCK > RDBLOCK1 > …
  gf 208  guard-ctrl: … EnGarde > getopdist > GETOPDIST > getopdist > GETOPDIST > getinfront > GETINFRONT > RDBLOCK > … > cmpspace > CMPSPACE > get2infront > GET2INFRONT > RDBLOCK > … > cmpspace > CMPSPACE > DoAdvance > GenCtrl > GENCTRL > FightCtrl > getunderft > …
BLUEPRINT QUERIES inside a CONTROLLER (the §1 stop condition): guard-ctrl RDBLOCK x57, guard-ctrl cmpspace x20, guard-ctrl get2infront x10, guard-ctrl getinfront x10, guard-ctrl getunderft x37, kid-ctrl RDBLOCK x12, kid-ctrl cmpbarr x3, …
RND calls inside a controller, game frames 180-217: 0
scratch hdv md5 before/after: C4F0B13E49B77DD0FBC5063E27E53A24 (unchanged)
```
25.1/25.3: none — no build.

### 6 — Deviations and route accounting
Stopped at §1 as the dispatch directs. Not built: everything in §3 of the dispatch. Not proposed for shipping:
anything. The map options (§3C) are a question, not a proposal I have acted on. The duel-vs-mechanism ruling (§8) is
untouched — nothing here bears on it beyond confirming the window is RNG-free.

### 7 — Uncertainty flags
- One boot's trace; the guard's path in 180-217 is RNG-free and so should not vary by boot, but only this boot was traced.
- `milestone`/`gotsword` were read through whatever bank was mapped for reads at the record point.

### 8 — Follow-up candidates
1. **The map ruling: (A) a block map in the port, or (B) replayed answers** (§3C). The window's build follows it.
2. Then P5.36's build as written, with the map in its scope.

### 9 — User interaction during task
"continue" (mid-task).

### 10 — Candidate(s) captured
None.

### 11 — Commit
`4a0e030` (pushed to origin/wip; this line in the follow-up commit). `main` untouched.
