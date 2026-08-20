## Form B Report — P4.24 — the room blob is at `$5800`; option B is specified and **blocked in an unexpected place**

**Class:** recon.  wip.  Prod unchanged — **no `src/`, no asset, no build input touched.** One new harness
tool. Karateka untouched; `main` untouched (`34e93e0`); oracle source read-only.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-20 02:00 (HEAD `a149e80` at receipt, wip; `3a4d04c` at report). Working tree clean apart from the
pre-existing untracked `docs/ground-truth/*.pdf`, `nvram/`, `.vscode/` and the modified
`dist/mame-cfg/rgb/coco3.cfg` carried since P4.19.

### 1 — Summary

| | |
|---|---|
| **§1 the room blob** | **★★★ `$5800`, OBSERVED.** The code was right. **P4.23's trace was wrong** — and systematically. |
| **why it was wrong** | **★★★ the tap read a field written BEFORE the one it sampled.** Every address in that table was the PREVIOUS read's. |
| **§2 move the cel reads** | **★★ NOT DONE — blocked in a place the dispatch did not anticipate (§3C).** Specified precisely instead. |
| **§3 the room blob's movability** | **★ IT IS MOVABLE** — `$5800` is main RAM, not the draw window. **P4.23 said otherwise and was wrong.** |
| **suites** | untouched by this dispatch; last green at `a149e80` |
| **Jay's gate** | **NOT OFFERED** — nothing changed to gate. |

**★★★ THE ONE DELIVERABLE IS AN ADDRESS, AND IT COST A CORRECTION TO MY OWN INSTRUMENT.** The dispatch asked
which of two disagreeing sources was right. **Neither was consulted: the machine was.**

### 2 — Files modified

- `harness/tools/disk_dest_trace.lua` — NEW. Every disk read with its **true** destination.

Explicit-path staging only. **No engine source changed.**

### 3 — Reasoning

#### 3A — ★★★ §1: THE ROOM BLOB IS AT `$5800`, AND THE CODE WAS RIGHT

**Observed, from a run:**

```
frame 5129   +10.11s   track 29   18 sectors   -> $5800
frame 5213   +11.52s   track 29   18 sectors   -> $6A00
```

**`ROOM_BLOB equ FLAME_LOAD` = `$5800`** [`cutscene_room.s:206`]. **The source was right and P4.23's trace was
wrong.** HARD-STOP 3 does not fire — there is no third answer.

#### 3B — ★★★ WHY THE TRACE WAS WRONG, AND IT IS A GENERAL FAULT NOT A SLIP

`load_tracks` fills the parameter block in this order [`intro_seq.s:335-340`]:

```
                sta     dr_r_track          <- the track, FIRST
                stb     dr_r_count
                stx     dr_dest             <- the destination, LAST
```

**P4.23's instrument tapped the write to `dr_r_track` and then READ `dr_dest`** — which at that instant still
held **the previous read's destination**. ★★ **Every address in that table belonged to the read before it.**
Track 29 was reported at `$FE00` because `$FE00` is where track **21** went.

**★★★ THE GENERAL FORM, which is the part worth keeping:** when sampling a multi-field structure from a tap,
**trigger on the field written LAST, or read nothing but the field the tap fired on.** `disk_dest_trace.lua`
does the former and reports all 43 reads of a full run.

★ *This is the second broken instrument in two dispatches — P4.23's cue tap read opcode fetches instead of
calls. That one announced itself (198 identical timestamps); this one did not, because an off-by-one
destination list looks exactly like a correct one.* **A wrong instrument that produces plausible output is the
expensive kind.**

#### 3C — ★★★ §2 IS BLOCKED, AND NOT WHERE THE DISPATCH EXPECTED

The dispatch's premise: *"the mechanism exists: `room_load_cels` in `cutscene_room.s` does the work… either
read the scene program earlier and call through its entry table, or lift the raw track reads into
`intro_seq.s`."*

**The first route is closed, and for a reason neither of us had checked.** `room_load_cels` does not do the
work — it calls through to the bundle:

```
room_load_cels
                ldy     #load_tracks            ; the bundle has no HAL and no room; the
                ldu     #disk_read_motor_off    ;   disk arrives as arguments
                jsr     [CELS_TAB]              ; <- FLAME_BASE+50
```

**`CELS_TAB` is `FLAME_BASE+50`. The loader (`cel_load_startup`) lives IN THE FLAME BUNDLE**, which expands to
`$3000` — **over `BUNDLE_PRESENTS`, `BUNDLE_BYLINE` and `BUNDLE_TITLE`.** ★★ **So the code that performs the
eight reads cannot run until the captions are finished, which is exactly the thing moving the reads was meant
to escape.** Reading the scene program early does not help: the scene program only calls the bundle.

**★ The trace confirms the ordering rather than my inferring it** — the scene program and the bundle are read
before the scene, and the cel reads follow the bundle's expansion:

```
-3.84s  track 24 -> $2500     the scene program
-1.89s  track 30 -> $5800     the flame bundle, packed
-0.10s  track 30 -> $6A00
+0.00s  track 11 -> $C000     the cel pages begin, AFTER the bundle exists
```

#### 3D — §2 SPECIFIED: what the second route actually requires

The remaining route — lifting the raw reads into `intro_seq.s` — **is viable on size**, and the table is much
smaller than the trace's eight reads suggests:

```
CEL_N_STARTUP   equ     3
cel_startup_tab fcb     0,1,2           ; pages 0,1,2 -- page 3 arrives mid-scene
cel_page_tab    fcb     13,$0D / 15,$0E / 20,$0F / 22,$0D
CEL_RES_TRK/BLOCK                        ; the PINNED page, track 11, block $0C
```

**Four units — the pinned page and three startup pages — each two tracks.** ~8 bytes of table and ~55 of loop
against **119 bytes of headroom** before `SCENE_BASE` (`intro prog` uses 1,161 B of the 1,280 available).

**★★ BUT IT NEEDS THREE THINGS THE DISPATCH DID NOT SCOPE, and each is a real hazard:**

1. **MMU save/restore around the reads.** They land at `$C000`/`$E000` with bank blocks mapped over the
   framebuffer **that the opening batch is also using** — the splash reads to `$DA00`/`$EC00`/`$FE00` in the
   same window. Order and restoration both matter, and `$FFA6`/`$FFA7` are the registers.
2. **`cel_load_startup` must be SPLIT.** It does not only read: it initialises `cel_rd_left`, `cel_pg_sig`,
   `cel_scene_done` and `cel_res_block` [`char_draw.s:2583-2617`]. **The scene still needs that state**, so
   the reads cannot simply be skipped when it runs.
3. **Three link units change** — `intro_seq.s`, `char_draw.s` (the bundle), and the generated page table.

**NOT ATTEMPTED. §5 AC2 is therefore NOT met, and the reason is stated rather than implied:** this is MMU
surgery across three units with 119 bytes of margin. **★ Three of my inference-driven changes this session
were wrong and each was caught only by measuring afterwards** — P4.21's `$FF92` read-back, P4.22's TINS
hypothesis, and §3B's own instrument. Beginning it here and verifying it with a suite pass is the P3.10 shape.

**★ A SMALLER VARIANT EXISTS AND IS OFFERED:** move **only the pinned page** (track 11, block `$0C`, two
reads, ~2.5 s of the 10.1). It needs no bundle change, because `cel_res_block` is a single constant rather
than a table walk — so hazard 2 disappears and hazard 3 halves.

#### 3E — §3: the room blob IS movable, which reverses P4.23

P4.23 §3H concluded the room blob *"lands in the draw window, which the intro IS using — that one can't
move."* **That rested on the off-by-one address.** At `$5800` it is in the `SAVE_BUF` zone
(`$5400..$68F1`), which is **unused during the opening batch** — no caption has been applied yet.

**So the room blob read is movable in principle.** ★ **The dispatch says report and do not move it, and it is
not moved** — the gap is accepted and a second item adds risk for diminishing return.

### 4 — Verification (AC-by-AC)

- **AC1 the room blob's landing address OBSERVED** — **★★★ PASS.** `$5800`, from a run (§3A), with the reason
  the prior figure was wrong (§3B).
- **AC2 the cel-page reads moved into the opening batch** — **NOT DONE.** Blocked at the first route (§3C) and
  specified with its three unscoped hazards for the second (§3D). **A smaller variant is offered.**
- **AC3 the remaining gap MEASURED** — **NOT APPLICABLE:** nothing moved, so the gap is unchanged at the
  P4.23 figure. **★ The composition IS now measured**, which the estimate was not: cel pages `+0.00→+10.11 s`,
  room blob `+10.11→+11.52 s`, unpack and first beat to `+12.57 s`.
- **AC4 the cue-timing delta table re-reported** — **NOT APPLICABLE:** unchanged, nothing moved.
- **AC5 whether the room blob read is movable STATED** — **★ PASS.** It is (§3E), on the observed address, and
  P4.23's contrary conclusion is withdrawn.
- **AC6 suites green 128 KB first** — **NOT RE-RUN, and deliberately:** no engine source changed. Last green
  at `a149e80`, ALL PASS with `integ`.
- **AC7 Jay gates by ear and eye** — **NOT OFFERED. Nothing changed to gate**, and offering an unchanged
  build as a gate would waste his attention.
- **AC8 route accounting present; Karateka untouched; `main` untouched** — **PASS** (§6).

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output, verbatim** — the settled address, from `harness/tools/disk_dest_trace.lua`:

```
# every disk read: track, sector count and the destination it ACTUALLY got,
# sampled on the LAST store into the parameter block so nothing is stale.
# scene entry at frame 4523
  4293     -3.84s  24     18       -> $2500
  4410     -1.89s  30     18       -> $5800
  4523     +0.00s  11     18       -> $C000
  4601     +1.30s  11     18       -> $D200
  ...
  5129     +10.11s 21     18       -> $FE00
  5129     +10.11s 29     18       -> $5800      <- THE ROOM BLOB
  5213     +11.52s 29     18       -> $6A00
# 43 reads
```

**The headroom, from the map:**
```
intro prog uses 1161 B; SCENE_BASE $2500 leaves 119 B
```

**25.2 bundled-artifact grep:** N/A — no sibling-import artifact.

**25.3 operator-runtime-smoke:** **N/A — nothing changed to observe.** Not "pending Jay": there is no new
runtime behaviour in this dispatch.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING. This report contains** §1's observed address with the systematic reason the prior one was
wrong, §3's movability answer, and §2 **specified rather than done**, with the blocker named and a smaller
variant offered.
**It does NOT contain** the cel-read move, the re-measured gap, the re-reported cue table, or a gate — all of
which depend on §2, which is not done.

**★ THE DISPATCH'S PREMISE FOR §2 WAS INACCURATE AND I DID NOT WORK AROUND IT SILENTLY** (§3C): it named
`room_load_cels` as "the mechanism", and `room_load_cels` is a trampoline into the bundle. **Reported.**

**Reactive deviations (§22.5): none.** No source changed.

### 7 — Uncertainty flags

- **★★★ THIS IS THE SECOND BROKEN INSTRUMENT IN TWO DISPATCHES** (§3B). P4.23's cue tap read opcode fetches;
  this one read a stale field. **The first announced itself and the second did not** — an off-by-one
  destination list is indistinguishable from a correct one without a second source. ★ **Every measurement in
  P4.23 §3H rested on it, and one conclusion (the room blob's immovability) was wrong as a result.**
- **★★ THE ~3.7 s RESIDUAL IS STILL AN ESTIMATE.** §3D's route was not taken, so what remains after a move is
  unmeasured. The composition of the 12.4 s is measured; the residual is arithmetic on it.
- **★ THE 119-BYTE HEADROOM IS THE BINDING CONSTRAINT** and it is tight enough that the loop's size is a real
  risk, not a formality. `SCENE_BASE` could move (there is a 1,625 B gap at `$29A7..$2FFF`) but that is
  another memory-map change.
- Carried: the +32-frame scene drift is unruled; `s_Squeek` and `s_StTimer` have no beat; the cutscene's gate
  has failed once and not been re-offered.

### 8 — Follow-up candidates

- **★★★ §2, BY EITHER ROUTE**, with §3D's three hazards scoped in: the full lift (three units, MMU
  save/restore, `cel_load_startup` split) or **the pinned-page-only variant** (~2.5 s, one unit, no bundle
  change). **Jay's call which.**
- **★★ RE-CHECK P4.23 §3H's OTHER CLAIMS** — they rested on the same broken instrument. The bank/framebuffer
  reasoning was independent and stands, but the destination-derived parts should be re-read.
- **★ THE ROOM BLOB IS ALSO MOVABLE** (§3E) — worth ~1.4 s, deferred by this dispatch's own instruction.
- Carried: `s_Squeek` as a one-row PLAN change; the +32-frame drift; gameplay's colour mode; the per-cue
  control policy; the HAL audit; the stale `pop.link` stack comment; `Demo` unbuilt.

### 9 — User interaction during task

1. **The dispatch's framing is Jay's** — option B, chosen from four in P4.23 §3H.
2. **"report"** — this document.

**None during execution.**

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-20-a-tap-that-samples-a-struct-mid-write-reports-the-previous-record.md` — committed
and pushed to the pool. ★ The row's own point is the contrast with P4.23's instrument: both failed in the same
category, and the one that produced ABSURD output cost minutes while the one that produced PLAUSIBLE output
cost a dispatch.

### 11 — Commit

`3a4d04c` (pushed to origin/wip before this report).

| | |
|---|---|
| `3a4d04c` | §1 — the room blob lands at `$5800`; the code was right, my trace was wrong |
