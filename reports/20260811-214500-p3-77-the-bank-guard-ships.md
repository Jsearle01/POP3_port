## Form B Report — P3.77 — the bank guard ships and is seeded-tested; the packer does not
**Class:** build (partial, complete and green as far as it goes). wip. Prod untouched.
**The swap's packing, staged reads and beats are NOT built — stated, not half-done.**

### 0 — Receipt / status (C-35 stamp)
t0=2026-08-11T21:20-04:00 (HEAD `e22d978`, wip). Now at `b784ec2`. Karateka untouched this
dispatch (`wip` `ac2b768`, `main` `5eb92b1`) — the P3.76 exception is closed. Sync bridge green.
Tree green, nothing half-built.

---

### 1 — Summary

**Three things landed, all measured, all green.**

| | |
|---|---|
| **`s_Buildup` traced** | **394 frames (6.6 s)** — the second read's hiding place, never measured before |
| **The draw-time bank guard** | shipped, **seeded and confirmed to fire** |
| **Two vacuous passes closed** | the walk suite passed while the engine drew *nothing* |

**The packer, the link split, the per-beat mapping, the two staged reads and the six beats are
not built.** I stopped rather than write the packer at this depth: it is precisely where a
mistake becomes the silent-garbage failure the guard now exists to catch.

---

### 2 — Files modified

`4ff0332` — `bake_scene.py`: `s_Buildup`'s traced duration recorded.
`b784ec2` — `bake_scene.py` (image signature), `src/engine/char_draw.s` (the guard,
`ch_bankerr`), `harness/smoke/walk_test.lua` + `run_walk_test.sh` (re-pointed, and two new
assertions), regenerated `content/cutscene/chars/cel_image.s`.

### 3 — Reasoning

**3A — `s_Buildup`, measured.** The schedule's second read has to hide in it, and its length
had never been traced. A **400-frame hold** ending at f4656, less the one held play of
`Vstop`'s `play 4` → **394 frames**.

The measurement needed a narrower box than the obvious one: **the torches sit at screen x ~182
and ~362**, and a box spanning them counts their flicker as scene motion — 384 changes against
the true 281. Narrowed to 200-350 the holds resolve cleanly.

**It is recorded but NOT in the PLAN.** `s_Buildup` belongs with `Vraise`/`Pback`, which do not
fit until the swap lands; alone it would add 6.6 s of dead pause to an ending that has nothing
after it. Landing it now would make the gated scene worse.

**3B — The guard, and why it refuses rather than repairs.** `walk_tab` holds **absolute**
pointers. A wrong GIME block under `$C000` leaves every pointer valid-*looking* and `blit_cel`
draws whatever bytes are present — no crash, no bad address, garbage that reads as a rendering
bug. That is capture-05 exactly, and it took three dispatches to attribute because nothing in
the machine complained.

So the image now says who it is: **two bytes of signature at its head**, checked once per
frame. Three choices worth stating:

- **Once per frame, not per cel.** The mapping can only change at a beat boundary, so a frame
  is the finest granularity at which the answer can differ. ~14 cy against 58,026.
- **It refuses to draw.** A skipped frame is instantly visible and harms nothing; drawing from
  an unmapped window corrupts the peel's saved background and **accumulates**, which is the
  shape that took three dispatches last time.
- **A magic, not a range check.** Two duplicated bytes, and that duplication is the entire
  point — a plausibility test on `WALK_LO` would pass on a wrong block that happened to look
  sane.

**Seeded and confirmed** (P3.48b/P3.49). With `CEL_MAGIC_VAL` set to `$DEAD`:
`# engine_bank_guard FIRED — the engine refused to draw (ch_bankerr = 1)`; reverted, `0`.

**3C — ★★ AND THE SEEDED RUN CAUGHT THE SUITE PASSING ON NOTHING.** With the guard firing the
engine drew nothing at all, so the walk suite armed on no movement, took **zero captures**,
compared nothing, found both runs identical — and reported **PASS**.

**That is the second time.** The `s_Princess` hold did the same at P3.72l, when all 28 captures
landed inside the song. Both times the suite was byte-exact green over an empty observation.
Two assertions added, both shown to fire:

```
FAIL run a: ZERO captures — the scene never moved, so nothing was tested
FAIL run a: the engine's own bank guard fired — it refused to draw
```

**★ And the zero-capture check did not fire on its first attempt — on the very run that proved
it was needed.** `grep -c` PRINTS `0` and EXITS `1`, so `|| echo 0` appended a second line and
the numeric test broke silently. Fixed with `|| true`. **Third instance in this arc of an
assertion that could not fire**, after P3.72h's vacuously-true parity test and P3.71's
expected-good-value guard. The pattern is not carelessness about logic; it is that a broken
assertion and a satisfied one are indistinguishable from the outside, so nothing forces the
check to be checked.

**3D — build.bat does NOT run bake_scene, and that bit me inside this dispatch.** The cel image
is a manually generated source. The guard's first run failed because the image still carried
the old header — the build had produced a correct binary from a **stale generated source**, and
`=== BUILD COMPLETE ===` said nothing about it. Flagged, not fixed: making the build regenerate
content has a protection-catalog dimension (§2B) that is not mine to decide.

### 4 — Verification

**25.1 fresh tool output (verbatim, at `b784ec2`):**
- `build.bat` → `cel_image.raw: 12924 B flat image based at $C000` → `tracks 11..13 (900 B pad)`
  / `=== BUILD COMPLETE ===`
- image head reads `195 90 2 55` — signature then bounds
- `run_room_test.sh` → `checks=8 passed=8 failed=0`; `PASS room intact`; `PASS flames flicker`;
  `PASS flame pixels`; `PASS`
- `run_walk_test.sh` → `bank_mapped_at_every_capture PASS (0 of 28)`;
  **`engine_bank_guard PASS (ch_bankerr = 0)`**; `STABLE`; `PASS`
- 128 KB: room `PASS`, walk `PASS`. `run_introseq_test.sh` → `17/17` / `PASS`
- `hal_sync_check.py` → `OK`
- **Verified by symbol:** `Symbol: ch_bankerr (build/obj/char_draw.o) = 415C`

**What the instruments write** (P3.71): the guard is engine code and writes one latch byte;
`walk_test.lua` gained only reads. The oracle trace is read-only.

**25.2:** N/A. **25.3:** **not offered.** The scene is unchanged from the one Jay gated; the
complete arc §5 wants does not exist.

### 5 — Acceptance criteria

1. **Swap built** — **no.** Packing, split and per-beat mapping not started.
2. **Draw-time assertion shipped AND seeded-tested** — **yes** (§3B).
3. **Two staged reads** — no. Their schedule is measured (P3.76 §3F) and `s_Buildup`'s duration,
   the missing prerequisite, is now measured too (§3A).
4. **Beats landed** — no.
5. **Suites green both sizes** — yes (§4); build verified by symbol; checkers re-pointed for the
   moved header (offsets 2/3, and `$C002/$C003` in the Lua).
6. **Build left in the tree, condition stated** — green, nothing half-built.
7. **Gate** — not offered, with reason.

### 6 — Route accounting

The dispatch asked for the swap, the two reads, the beats and a live gate. **This contains the
guard (AC2), `s_Buildup`'s trace, and the suite fixes the seeded test exposed — and nothing
else.**

**One deviation, deliberate:** the dispatch's order implies the packing first, with the
assertion alongside. I built **the assertion first**, because it is the check that makes a
wrong packing loud instead of silent, and building it after the thing it guards would mean
debugging the packer without it — which is the position P3.69 was in for three dispatches.

Not present: packer, link split, per-beat mapping, staged reads, `Vraise`, `Pback`, `Vexit`,
`Pslump`, `s_Buildup` in the PLAN, hourglass, 16c swap, `Prolog2`. No gate claimed. Karateka
untouched; `main` untouched in both repos.

### 7 — Uncertainty flags

- **The guard has never been exercised by a REAL wrong mapping**, only by a seeded expected-value
  mismatch. Those exercise the same comparison, but the real failure also has to be *reachable*
  — that is the packer's problem and it is unwritten.
- **The signature costs two bytes at the head of every future image split.** If the packer puts
  cels in more than one block, each block needs its own signature or the guard only proves one
  of them is mapped.
- **`s_Buildup`'s 394 frames subtracts one held play by the same reasoning used for `s_Vizier`**
  (six frames at SPEED 7). The subtraction is inferred from the script's shape, not observed.
- `build.bat` can build from a stale generated cel image (§3D).
- Carried: 0.20 s per-call driver overhead; the `$2310..$2329` read-tap blindness;
  `PlayCut0`'s remaining sound sites.

### 8 — Follow-up

1. **The packer, in a fresh context** — with P3.76 §3F's cut points and §3A's hold length, its
   inputs are complete. It is the piece where a mistake is silent, which is why the guard went
   first.
2. **Per-block signatures** if the split exceeds one block (§7).
3. Make `build.bat` regenerate or at least verify the cel image (§3D) — a `--check` mode that
   fails when the generated source is older than its generator would be enough.

### 9 — Candidate captured

`seeds/POP/live/2026-08-11-an-assertion-that-cannot-fire.md` — pushed. Three instances in one
arc: a vacuously-true condition, a guard keyed to the expected-good value, and a shell test
broken by `grep -c`'s exit status. A satisfied assertion and a broken one look identical from
outside, so the only defence is to break it on purpose once.

### 10 — Commit

`4ff0332`, `b784ec2` — pushed to origin/wip. This report follows.
