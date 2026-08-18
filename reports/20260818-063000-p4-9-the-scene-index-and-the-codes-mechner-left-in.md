## Form B Report — P4.9 — a scene index for the oracle, and the cheat codes that shipped

**Class:** build (harness only).  wip.  Prod unchanged — no `src/`, no `build.bat`, no shipping disk.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-18 06:30 (HEAD `22f9fdd`, wip).

### 1 — Summary

**Mechner's level-skip is in the shipped binary, and it works.** `MASTER.S:3` sets `FinalDisk = 1`,
which assembles the `kdemo`/`kprincess` keys **out** — Jay's expectation was right for those. But
**`SPECIALK.S:3` sets its own `FinalDisk = 0 ;removes all cheat keys`** — the comment describes what
setting it to *1* would do, and it is set to **0** — so that module's typed codes are assembled
**in**: `POP`, `SKIP`, `GO0`, `GO1`, `ZAP`, `BOOST`, `R`, `Z`, `TINA`. **Verified on the running
oracle against a control**, at tier 1: no rebuild, md5 intact.

The index ships with three entries, each with an arrival assert, tied to the oracle's md5.
**Two of my own bugs were caught during it and both are reported rather than quietly fixed** — one
of them produced a confident PASS from a machine that had not finished booting.

### 2 — Files added

- `harness/tools/oracle_scene.lua` — the index: named entries, each with tier / reach / cost /
  assumptions / arrival assert; save, and a control mode.
- `harness/smoke/run_oracle_scene.sh` — md5 gate, per-scene scratch image, state directory.

### 3 — Reasoning

#### 3A — ★★★ THE CODES, AND WHY THE SOURCE ALONE WOULD HAVE BEEN WRONG EITHER WAY

Two files set the same symbol to different values:

```
MASTER.S:3      FinalDisk = 1                          -> kdemo/kprincess assembled OUT
SPECIALK.S:3    FinalDisk = 0 ;removes all cheat keys  -> that module's codes assembled IN
```

**Reading either file alone gives the wrong answer**, and the comment actively misleads — it names
the effect of the value it does *not* have. So the question was settled on the **assembled
listing**, which is the artifact rather than the intent:

```
D97C: A9 FB   lda #C_devel      <- "POP"
D98D: A9 F6   lda #C_skip       <- "SKIP"
DAF6:         C_skip rev "SKIP"
DAFB:         C_devel rev "POP"
```

★ **`C_skip` sits OUTSIDE the conditional entirely** in the source, so SKIP would be present even
under `FinalDisk = 1`; the rest are inside it and present because this module's flag is 0.

**And then it was run** (§2's authority stack: the trace outranks the source):

| run | typed | result |
|---|---|---|
| skip | `POP`, then `SKIP` | **level 255 → 1**, one write |
| **control** | **nothing** | **level never moved** over the same 900-frame window |

**The control is what makes this a finding rather than a coincidence.** Without it, "the level
changed after I typed" is indistinguishable from "the attract loop restarted", and this instrument
had already produced one false positive (§3C).

*One thing I cannot explain and will not paper over:* the write landed **one frame** after
`nk:post("skip")`, which is faster than four keystrokes should be consumed. The control says the
change does not happen without typing; it does not explain the latency.

#### 3B — `setdemolevel`, read rather than inferred (AC3)

```
setdemolevel   lda demolevel / ldx demolevel+1 / jmp SetLevel
SetLevel       sta params / stx params+1              ; params = $3f0
demolevel      db 33,0
firstlevel     db 33,1
```

**Both start with 33**, and only the second byte differs — 0 for the demo, 1 for a new game. So
**33 is not a level number**; the level is the *second* byte and 33 is a starting position. ★ **That
is a reading of two initialisers and one routine, not a trace** — I did not follow `params` to its
consumer, and **AC3's "whether the SHIPPED binary honours a runtime write to it" is NOT answered.**
The SKIP path made it unnecessary for now and I did not spend a run on it.

#### 3C — ★★★ TWO BUGS OF MINE, BOTH IN THE INSTRUMENT, BOTH REPORTED

1. **A confident PASS from a machine that had not booted.** The gameplay predicate was
   `level ~= 0`. At **frame 8** the uninitialised RAM at `$03F4` held 69, so it fired; the same noise
   became 255 a frame after a keystroke, and the run reported *"the shipped binary honours the typed
   code."* **It reached the strongest conclusion available from nothing at all.** Fixed by arming on
   a **write tap** — the oracle's own code setting the level — plus a boot-time floor.
2. **An empty string is truthy in Lua.** The runner exports `P_STATE` unconditionally; the script
   tested `if LOADED then`, so **every run took the state-restore branch**, including the control,
   which then "failed" for a reason unrelated to what it was controlling for. Fixed explicitly.

*Both are the same family as the five stale checkers: a check that passes, or fails, for a reason
that has nothing to do with its subject.*

#### 3D — the md5 tie (AC6), and a correction

**The dispatch says the oracle's md5 is "already verified at run time". It was not.** No runner,
tool or script in this repo hashed it — `mame-idioms-apple2e-oracle.md` records reference md5s in
prose and nothing consulted them. `run_oracle_scene.sh` now gates on
`c4f0b13e49b77dd0fbc5063e27e53a24` and **refuses to run on a mismatch**, because an index derived
against one image is invalidated, not merely shifted, by another.

#### 3E — what is in the index

| entry | tier | reach | cost | arrival assert | status |
|---|---|---|---|---|---|
| `princess` | 1 — no touch | boot and wait | ~45 s | `SPEED == 12` at `$030C` | **PASS**, frame 2682 |
| `demo` | 1 — no touch | boot and wait | ~131 s | the game **writes** `level` | **PASS**, frame 7891 |
| `skip` | 1 — no touch | play, type `POP` then `SKIP` | +~2 s each | level changes, control-checked | **PASS** |

**P4.7's six songs fold in here rather than staying a separate mechanism** — they are reachable from
`princess`, which is the same entry armed on the same marker.

**★ No entry uses `PC = label`.** `Demo` opens `jsr blackout / jsr LoadStage3 / jsr setdemolevel` —
it loads before it does anything, which is exactly the initialisation a PC write would skip.

### 4 — Verification (AC-by-AC)

- **AC1 checked-in index with reach, assumptions, cost** — PASS (§3E).
- **AC2 save states with provenance** — **PARTIAL.** `princess.sta` (66 KB) and `demo.sta` (69 KB)
  are produced and the route is logged. **★ RESTORING THEM IS UNVERIFIED** — see AC5.
- **AC3 `demolevel` from `setdemolevel`** — **PARTIAL** (§3B): the two bytes are read from the
  routine, but **whether the shipped binary honours a runtime write is NOT established.**
- **AC3a tiers tagged; no rebuild-tier basis** — PASS. Tier 3 read for evidence, never used.
- **AC4 songs folded in** — PASS (§3E).
- **AC5 arrival assert per entry** — PASS **for the boot-and-wait and cheat entries**;
  **★★★ HARD-STOP 3 APPLIES TO THE STATE-LOAD PATH.** With `-state`, MAME starts and the autoboot
  script produces **no log at all** — so the restore cannot currently be asserted. Cause not found.
  **The states are therefore checked in as artifacts with no verified way to confirm where they land,
  and that entry must not be treated as working.**
- **AC6 tied to the md5** — PASS, and the dispatch's premise corrected (§3D).
- **AC7 oracle source untouched** — PASS; read-only, copied per scene.
- **AC8 suites green 128 KB; Karateka and `main` untouched** — PASS (below).

### 5 — Verdict-time evidence (v0.7 §11)

```
[scene] oracle md5 c4f0b13e49b77dd0fbc5063e27e53a24 — matches the anchor

# ★ ARRIVED at frame 2682   level=0  params=0,0  SPEED=12      (princess)
# PASS — the machine is where the index says it is.

# ★ ARRIVED at frame 7891   level=255  params=89,250  SPEED=0  (demo, via the write tap)
# PASS — the machine is where the index says it is.

# typed POP at frame 7952 (sets the development flag)
# typed SKIP #1 at frame 8073
# ★★★ LEVEL CHANGED 255 -> 1, 1 frames after SKIP (1 writes)
# PASS — the shipped binary honours the typed code. Tier 1, md5 intact.

# CONTROL: typing nothing. Any level change from here is NOT the code.
# ★★★ FAIL — SKIP typed 3 times and level never moved.        <- the control, as wanted

build/oracle_states/apple2e/princess.sta  66218 B
build/oracle_states/apple2e/demo.sta      69042 B

[suites] -ramsize 128K / [run_introseq_test] PASS / [integ] PASS / [suites] ALL PASS
```

**25.2:** N/A — harness only. **25.3:** N/A for this dispatch.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** I proposed nothing in advance. **This commit contains:** the index with three
verified entries, the md5 gate, save-state *creation*, the control mode, and the source findings.
**What it does NOT contain, and I am naming rather than leaving to inference:** a verified
state-**restore** path (AC5, HARD-STOP 3); an answer to whether a runtime `demolevel` write is
honoured (AC3); any per-level enumeration beyond what SKIP reaches; any `PC = label` entry.

**Deviations:** the runner used one scratch image for all scenes, so two concurrent runs collided
("Device or resource busy") — fixed to per-scene copies, because a harness defect that reads as an
oracle failure is worse than a slow harness.

### 7 — Uncertainty flags

- **★★★ THE SAVE STATES ARE CHECKED IN WITHOUT A WORKING RESTORE ASSERT.** They may restore
  perfectly; nothing here demonstrates it. **Treat `princess.sta`/`demo.sta` as unproven until the
  `-state` + autoboot-script interaction is understood.**
- **`level=255` at the demo entry** is what the write tap caught; whether 255 is the demo level's
  real number or a transient was not chased. The *entry* is asserted on the write, not on the value.
- **The one-frame SKIP latency** (§3A) is unexplained.
- **SKIP is capped at level 4 without the devel flag** per the source; `POP` is typed first here and
  the cap was not tested.
- **`demolevel`'s two bytes** are read from two initialisers and one routine, not traced (§3B).
- **The other codes** — `GO0`, `GO1`, `ZAP`, `BOOST`, `R`, `Z`, `TINA` — are assembled in but
  **untested**; only `POP`+`SKIP` were run.

### 8 — Follow-up candidates

- **Make the state-restore assert work**, or drop the states from the index. An entry that cannot be
  checked will eventually be wrong silently.
- Test SKIP's level-4 cap and the remaining codes; add per-level entries once the cap is understood.
- Answer AC3's runtime-write question if a level beyond SKIP's reach is ever needed.
- Unchanged: the timbre ruling; capture-vs-interpret; `MUSIC.SET*`; `Demo` unbuilt.

### 9 — User interaction during task

None during execution. The dispatch quotes Jay's question and his expectation that the debug
facilities may have been removed — **half right, and the half that survived is the useful half.**

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-18-the-scaffolding-is-usually-still-there.md`

### 11 — Commit

`f4f10b8`  (pushed to origin/wip before this report)
