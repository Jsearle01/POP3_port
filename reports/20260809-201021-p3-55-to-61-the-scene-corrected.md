## Form B Report — P3.55–P3.61b — the scene, corrected by eye: torch, gait, scale, clip, occlusion, princess
**Class:** build. wip. **Seven builds landed, all suites green at report.** Gates observed live by Jay; his
verdict on the last is recorded below and is not self-certified. Prod untouched.

### 0 — Receipt / status (C-35 stamp)
t0=2026-08-09T20:10:21Z (HEAD `7829bdb`, wip). `git status --porcelain` showed **0** tracked modifications at
report. Sync bridge green. Untracked = `.vscode/`, `nvram/`, `docs/ground-truth/*.pdf`,
`POP-idioms-coco3-markers.md`, `content/intro/broderbund_splash_render.bin`, `docs/project/*.pdf`.
Karateka and `main` untouched. Oracle source read-only throughout.

Covers everything after the P3.54 report (`8543512`): commits `f438644 19f2bfa 422f0fb 6b02f61 bccbb5f
331b0f4 e9d7b9e b8db171 5eff543 2618438 7829bdb`.

---

### 1 — Summary

**Jay's eye found a bug that six independent source verifications could not.** He reported a hitch in the
vizier's walk. The walk data proved faithful in every respect I could check — and it was. The defect was that
**`CharX` is in TWO-pixel units** and the port had been drawing at half scale since P3.17, which does not
present as a position error: it presents as bad animation, because the same leg artwork carried him half as
far and his planted foot slid backwards.

That one correction cascaded. At true scale a walk cycle advances 20 px = **5 whole bytes**, so every cel's
sub-byte phase becomes invariant — one baked variant per cel instead of two. **Vstop, which P3.32 measured as
1,937 B beyond the window and correctly refused, now costs three FEWER variants than the walk alone did.** He
walks in from the door and stops in front of her, which the port has never done.

Around it: the left torch moved to its true pixel; a limp of our own making was removed; characters are now
clipped to the Apple's 280 px; the vizier passes behind the right pillar; and the princess stopped flailing —
she had been running a P3.25 placeholder that was never her behaviour.

**★ The port's own converter had the correct formula the whole time.** `cel_parity_rule.draw_x` is
`2*(CharX + Fdx - 58) + parity`, written "for the record" and wired to nothing. It is what stamped
`start_col 279` into the walk cels and `124/125` into the princess's. Comparing the tree against itself
settled this faster than reading the oracle did.

---

### 2 — Files modified

- `src/engine/char_draw.s` — the coordinate formula (`co_setup`), parity carried through the record
  (`CH_PAR`) and `ch_last`, phase derivation (`co_variant`), virtual-edge clip (`co_clip`), foreground plane
  (`co_fore`), cadence table 5→6 entries, princess sequence.
- `harness/tools/walk_phases.py` — phase derived via `draw_x`; `PORT_ENTRIES` 1 → 3.
- `harness/tools/bake_walk.py` — all nine cels convert; `vstand` re-derived at its true column.
- `harness/tools/verify_room_chars.py` — placement, clip and foreground plane all derived from the oracle
  tables rather than tabulated.
- `harness/tools/verify_room_flicker.py`, `verify_room_flame_pixels.py` — footprints via `draw_x`; torch
  columns read from the engine source instead of duplicated.
- `harness/smoke/room_test.lua`, `walk_test.lua`, `run_room_test.sh`, `run_walk_test.sh` — `ch_last` stride
  derived from the link map.
- `content/cutscene/chars/` — nine baked variants regenerated at true scale, `pstand_p1` added.
- `build.bat`, `src/engine/cutscene_room.s` — torch 0 to phase 3 / byte 27.

Explicit-path staging throughout; no `git add -A`.

---

### 3 — Reasoning

**3A — The scale (P3.58). Authority: source, confirmed by Jay's eye.** `SETUPCHAR` [CTRLSUBS.S:794-840] builds
`FCharX = 2*(CharX + Fdx - ScrnLeft) + parity`, `ScrnLeft = 58` [EQ.S:479], parity set when
`bit7(Fcheck) == bit7(CharFace)`. `co_setup` had `x + 20`. `2*(197-58) = 278` is the right-hand door, where
the oracle brings the vizier in; the port drew him at 217.

Corroborated four ways before I touched anything: the sequence transcription against SEQTABLE.S:1513-1522;
`Fdx = 0` for all six walk frames [FRAMEDEF.S:378-383]; `ADDCHARX` [CTRLSUBS.S:353] and `ANIMCHAR`
[COLL.S:994-1095] for the facing-negate and the opcode/frame pairing; and the port's own converted cels,
whose recorded `start_col` values are exactly `2*(CharX-58)+parity` for every character image.

**3B — Why it survived every gate.** The two formulas agree at `CharX 116`. The princess sits at 120 and
rendered 4 px off — invisible — and she is what placement had been validated against. The vizier was 82 px
off. **A scaling error is zero at the fixed point of the transform, and the stationary thing near the centre
is exactly what one picks to validate against.**

**3C — The hitch was authentic; the bug magnified it.** `Vwalk` genuinely carries `db 51,chx,-1`
[SEQTABLE.S:1518] and nothing compensates it. At true scale that is +1 px against a 20 px stride, 5%. At half
scale it is +2 against 10, a fifth. Same data, four times the prominence — the difference between
unnoticeable and a stumble. **This is why auditing the walk kept confirming the walk was right.**

**3D — A limp that was ours (P3.57).** `cad_tab` was 5 entries against a 6-step gait, so its one short hold
rotated: cycle 0 clipped pose 4, cycle 1 pose 3, cycle 2 pose 2 — a different pose clipped every cycle, period
30 steps, over a walk of ~45. The oracle sets a flat `SPEED 7` [SUBS.S:683]. Six entries pin each pose to its
own hold; 23/6 = 3.833 f/step against the old 3.800 and the oracle's measured 3.9, so this is nearer in rate
too. **Real, but not what Jay was reporting** — stated plainly at the time rather than claimed as the fix.

**3E — The stop paid for itself (P3.58).** Measured, not estimated:

| | cels | variants |
|---|---|---|
| half scale, approach only | 6 | 12 *(what shipped)* |
| true scale, approach only | 6 | 6 |
| true scale, approach + stop + stand | 9 | **9** |

P3.32's refusal was correct arithmetic on a broken premise. Bundle **14,158 → 11,219 B** of 14,848.
`viz_script` is emitted from `walk_phases.port_plan`, so the script follows the derivation and cannot drift
from it.

**3F — The clip (P3.59).** The oracle clips every image to `LEFTCUT..RIGHTCUT` in whole bytes,
`RIGHTCUT` 40 [HIRES.S `CROP`]; entering at `FCharX 277` that is `XCO 39 / VISWIDTH 1`. Apple byte 0 → CoCo
col 5, byte 39 → col 74. Both margins are `$00` for all 192 rows of the asset — **verified, not assumed** —
which is what makes blanking identical to clipping. Clipping inside the blitter was rejected: segments encode
runs, not columns, so a width clamp needs a per-byte bounds test and the merge path is already a 6809 floor
at 22 cy/byte.

**3G — The foreground plane (P3.60).** The oracle lays the foreground down after the characters [`addfore`,
EQ.S:182]. Anchors derived from the asset and **confirmed by Jay before placing** (§3): cols 60–62, solid
`$FF` from row 104 to 191. Solid is why it is cheap — the restore is a fill, so no saved copy of the room and
no second home for the pillar's pixels. Runs once after the whole draw pass, not per character, which is what
makes it a plane.

**3H — The princess (P3.61).** `pri_demo` was a P3.25 placeholder for exercising the interpreter's opcodes.
`Pstand` is `db 11,goto` — one cel, held — and `Palert` ends in `Pstand`, well before the approach the port
renders. P3.58 doubled her placeholder's 8 px to 16, which is why a long-standing wrong surfaced now.

---

### 4 — Verification (AC-by-AC)

- **The gait reads correctly** — Jay, live: *"the vizer looks correct now."*
- **Scale is the oracle's** — walk 28/28 byte-exact, checker compositing from `draw_x` against the ORACLE's
  tables, independent of the engine.
- **He stops** — recorded trajectory: 196 → 148, cel 56 (Vstop) at 146, then cel 54 held. Column 49 against
  her 36.
- **Clip** — captures 1–2 previously showed 149/106 bytes in cols 75+; now 0, with the checker modelling
  `CROP` itself.
- **Occlusion** — captures 07–10 have his footprint genuinely spanning cols 60–62; pillar `$FF` across all 48
  rows in every one. Control: before the change the suite passed with the checker compositing him *over* the
  room with no plane, and both composites cannot match the same capture.
- **Princess still** — one distinct `(x, cel)` across all 28 captures, where she had six.
- **Torch 0 at its true pixel** — replayed both streams into a pixel grid: lit px `112..118 → 111..117`,
  exactly −1.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output:** `build.bat` → `=== BUILD COMPLETE ===`. `run_walk_test.sh` → `28/28 … stability:
all captures agree (0) … STABLE … PASS`. `run_room_test.sh` → `checks=8 passed=8 failed=0 … PASS`, and PASS
at `MAME_RAM=128K`. `run_introseq_test.sh` → `PASS`. `hal_sync_check.py` → `OK — 11 files compared`.

**25.2 bundled-artifact grep:** N/A — no sibling-import artifact.

**25.3 operator-runtime-smoke:** **Jay, live-disk, RGB.** Verdicts as given: *"the vizer looks correct now,
but the princess is still flailing around"* (before P3.61), then P3.61 run and no defect reported against the
gait, clip, pillar or stillness. **No further gate claimed** — the last run was observed and Jay's only
subsequent report was the facing correction in §7.

---

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** Two routes proposed and one *not* delivered as described:

- P3.58 recon told Jay the correction "likely unblocks him actually stopping" on a **2× margin** estimate
  (4,150 B freed vs 1,937 B needed). That arithmetic was **wrong** — it compared a saving at true scale
  against a shortfall measured at half scale. Corrected before building by measuring the real figure: 9
  variants vs 12. **The conclusion held; the reasoning I gave for it did not, and the measurement replaced
  it.**
- P3.58 proposed the scale fix alone; the commit also contains the **full approach/stop/stand script**. Stated
  in the commit and here: at true scale he crosses the room twice as fast, so without the stop he leaves the
  screen — the stop became required for a coherent result, not an extra.

Deviation: P3.61a asserted the princess faces him and that piece G was not needed. **Wrong on both counts**,
reverted at P3.61b. See §7.

### 7 — Uncertainty flags

- **The princess is turned in the oracle and is not here.** `Palert` ends `aboutface,chx,9`, so she should
  stand at CharX 129 / CharFace 0 — parity flips to 0, phase 2, col 40 — needing a **mirrored** image 25.
  Piece G is on this scene's path. Open for Jay: it is an 18 px spatial move (§3).
- **`cel_table`'s parity column is generated for CharFace=left** and is invalid for any character that turns.
  The durable fix is for `vm_resolve` to carry `Fcheck` and derive parity against `CH_FACE` at runtime.
- **I reversed a correct finding on a mistaken correction** (§6). All three readings are left in the source
  comment rather than tidied, because which one was believed is what a diff cannot show.
- The port runs only the oracle's **final** approach/stop pair. The entrance pair lands the second approach on
  the other parity — 18 variants — which still does not fit.
- Carried: the `22 cy/byte` comment in `blit_core.s` (measured 32); `PlayCut0`'s four sound sites un-stubbed;
  the four-slot peel instrumentation still obsolete since `PEEL_BYTES` moved 26→39.

### 8 — Follow-up candidates

1. **The turn (piece G)** — mirrored cels + runtime parity from `Fcheck ^ CH_FACE`. Retires a documented
   landmine for every future turn rather than special-casing the princess.
2. **Extend the EXEC verify-then-commit pattern** to the other ~20 scripts, starting with `introseq_live.lua`,
   which Jay also drives by hand.
3. Re-instrument the four-slot peel discipline.

### 9 — User interaction during task

Jay drove every finding in this report by eye: the left torch a pixel right; the walk hitch, twice, the second
time insisting it was not in the oracle when the source said it was — which is what forced the trace-over-source
call (§2) and found the scale; the clip; the pillar, plus its confirmation as the rightmost; the princess
flailing; and the facing, corrected twice.

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-09-a-periodic-schedule-whose-length-does-not-divide-the-cycle-it-drives.md`
- `seeds/POP/live/2026-08-09-a-scaling-error-is-invisible-at-the-fixed-point-of-the-transform.md`

(Both pushed. `a-constant-duplicated-across-files-survives-the-link-and-the-boot`, captured at P3.54, recurred
twice this session — the checker's torch columns and the Lua's `ch_last` stride — and both are now derived
rather than duplicated.)

### 11 — Commit

`7829bdb` (pushed to origin/wip before this report), atop `2618438 5eff543 b8db171 e9d7b9e 331b0f4 bccbb5f
6b02f61 422f0fb 19f2bfa f438644`.
