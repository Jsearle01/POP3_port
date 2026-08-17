## Form B Report — P3.78 — the split lands and the schedule drives it; the exit does not clip

**Class:** build (substantial, and **NOT complete — the scene does not finish**). wip.
Prod untouched. The build is green and in the tree; the runtime failure is stated, located
and machine-verified rather than smoothed.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-11T21:51:59-04:00 (HEAD `1608cd1`, wip). Now at `88f9592`, pushed.
**Karateka untouched** — its `wip` is still P3.76's `ac2b768`, its `main` `5eb92b1`.
POP `main` untouched at `635f986`. `hal_sync_check` OK (11 files).
Build green; suites **not** all green — §4.

---

### 1 — Summary

**The packing, the split, the per-block signatures, the per-beat mapping and both staged
reads are built and working.** The scene plays **17 of its 18 beats**, both mid-scene
reads land in their song holds and complete, and the guard is clean for every beat up to
the exit.

**It does not finish.** `Vexit` walks the vizier off the right edge of the screen and this
port has no clipping for that case — the first time in its life a character has left the
screen. Located on the machine, not inferred.

**Five faults were found and fixed on the way, three of them silent**, and one of those
was a design error of mine that wrote through the GIME registers.

**Measured, not quoted:** the two staged reads freeze the torches **3.19 s and 2.89 s** —
against the 1.7 s Jay accepted at P3.75, because a page is two tracks and not one. That is
his call, and §7 states it as one.

**Jay caught a §3 omission by watching it run:** the hourglass and its flash are not built.

---

### 2 — Files modified

`88f9592` —
- `harness/tools/cel_pack.py` (new) — the packer: resident/rotating split, per-page
  signatures, the beat→block schedule, and the read points.
- `harness/tools/cel_link.py`, `cel_table.py` (new) — per-page link, the skewed disk
  layout, the `[cel][facing][phase]` table built from the pages' link maps.
- `harness/tools/verify_sequences.py` (new) — the independent cross-transcription check.
- `harness/tools/bake_scene.py` — per-beat draw sets, the five beats in `PLAN`, the plan
  and page-table emitters.
- `harness/tools/beat_recost.py` — `:loop` scoped to its block (§3C).
- `harness/tools/bundle_offsets_check.py` — linked byte-count checks for both generated
  tables; `CELS_TAB`.
- `src/engine/char_draw.s` — the per-block guard, `vm_beat_tick`/`vb_apply`, the page
  loader, the skewed two-call read.
- `src/engine/cutscene_room.s` — `cel_bank_map` reads the schedule's block; the loader
  moved into the bundle; the two mirror paths merged.
- `src/engine/flame_cels.s` — `cels_tab`.
- `harness/smoke/walk_test.lua`, `run_walk_test.sh` — the new assertions.
- `content/cutscene/chars/` — `cel_res.s`, `cel_pg0..4.s`, `cel_plan.s`, `cel_pages.s`,
  `cel_pack.json`, the new beats' cels; `cel_image.s` retired.
- `link/pop_cel_res.link`, `pop_cel_pg*.link`; `link/pop_cels.link` retired.
- `build.bat` — per-page link/place, and `verify_sequences` as a pre-build gate.

Explicit-path staging throughout.

### 3 — Reasoning

**3A — The split, and the shape the content chose.** One pinned page at `$C000` (8,192 B
addressable, holding the 4-byte header, the 1,360 B table and 5,942 B of carried cels) and
**five rotating pages of 7,680 B over three blocks** at `$E000`. The packer asserts, on the
real sets, that every beat's cels are reachable from `resident ∪ mapped page`, that a read
is only issued at a beat needing no rotating page, and that the read's target block is the
one that beat maps. **No beat straddles a changing block** (AC1).

**★ One phase was added after measurement, and it is a slot argument rather than a byte
one.** `Vraise` draws exactly one cel the pinned page lacks (`v85`, **78 B**), and beat 12
is 7,678 B against a 7,680 B page — so the union misses by 76 bytes and Vraise took a whole
block for 78 bytes. That pushed the last page onto a block whose refill point would have had
to be beat 12 or 13, neither of which is a hold, and **the packer reported the entire scene
as unpackable over 78 bytes.** Pinning such a beat buys a *slot*, not bytes, and it is worth
far more than it costs.

**3B — ★ THE READ GEOMETRY, WHICH IS THE ONE I GOT WRONG AND THE MACHINE CAUGHT.**
`disk_read_range` reads whole tracks only. A page holds 7,680 B and therefore needs two
tracks — **9,216 B of transfer into a window that reaches 7,680**. The straightforward read
overran **1,536 bytes** through `$FE00-$FEFF` (the constant page, where the disk driver keeps
its own NMI and motor flags) and then through **`$FF00-$FFFF`, which is the GIME and the MMU**.

It did not present as corruption. The machine reset the instant the first page landed,
`$FFA6/$FFA7` came back as the boot default `$3E/$3F` and `probe_status` read 0 — which
looks exactly like *"the program never started"*, the one thing it had not done.

The fix costs nothing: no HAL change, no staging RAM, no extra block. Each unit is padded to
the window it is read into and its **second track is laid out skewed** so the read *ends* at
the window's top — `$EC00`→`$FE00` for a page, `$CE00`→`$E000` for the pinned one. The two
reads overlap and carry identical bytes there; `cel_link.py` asserts the rebuild.

**3C — ★★ THE TRACER AND THE PORT DISAGREED ABOUT THE ORACLE, AND NOTHING COMPARED THEM.**
Mechner's assembler scopes a `:`-prefixed label to the enclosing routine; `SEQTABLE.S`
reuses `:loop` in nearly every sequence; `beat_recost` read them into one flat dict, so
**every `goto :loop` resolved to the last one parsed**. `Pback` ends `:loop db 17 / goto
:loop` — read from the oracle source, not from a comment — and the trace had the princess
holding **cel 18**, `Pslump`'s loop.

The packer therefore provisioned 18 for four beats that draw 17 and never provisioned 17. The
beat after Pback drew a cel sitting in an unmapped page: a valid-looking pointer into real
data belonging to someone else, which `blit_cel` walked as a segment stream and never came
out of. The room hung with interrupts masked, five beats from the end.

**The packer's own assertion could not catch it, and the reason is the finding.** Both sides
of that check come from the same tracer, so it agreed with itself. The independently grounded
second opinion was in the tree the whole time — `char_draw.s`'s hand-written `fcb` streams.
`verify_sequences.py` compares the two transcriptions on the cels they emit, is wired into
`build.bat`, and **is demonstrated to fire** (§4). It caught `Vraise` as well.

**3D — ★ AND THE BEAT BOUNDARY WAS ONE STEP EARLY, WHICH THE GUARD STRUCTURALLY CANNOT SEE.**
Decrementing the play count and taking the next beat in the same call maps the *next* beat's
page for the step that is still the *current* beat's last. Measured at the last step of Vexit:

```
f4625  cel=60  col=43  w=8  h=48   dest=$A0AB     the last correct frame
f4631  cel=61  col=43  w=1  h=192  dest=$C3AB     a header read out of the wrong page
```

`h=192, w=1` are not a cel; they are two bytes of another page's pixels read as a header, and
the blit then walked 192 rows **into the cel bank itself**, over the pinned page, until the
stack ran from `$7EFE` down to `$00FA`.

**The per-block guard asks "is the page this BEAT needs mapped?" and the answer was YES.**
Beat 15's page was correctly mapped for beat 15; the fault was that the cel came from beat 14.
A signature proves which page is in the window; it cannot prove the cel about to be drawn
belongs to the beat the window is set for. The beat is now marked *spent* and the switch
happens at the top of the following step.

**3E — the two staged reads, measured.** Beat 6 (`s_Vizier`) fetches page 3; beat 10
(`s_Buildup`) fetches page 4. Both land over content the residency table proves finished, and
both pages are first drawn several beats later.

```
staged read 1   entered f3058, room drew again f3249   191 frames = 3.19 s frozen
staged read 2   entered f3831, room drew again f4004   173 frames = 2.89 s frozen
```

Corroborated independently by the flip cadence: 476 gaps of 2 frames and 350 of 3, with
exactly **two outliers of 176 and 194 frames**. The torches freeze for the transfer — polled,
interrupts masked, no DMA — and that is surfaced here rather than at the gate, because the
gate did not happen.

**`s_Buildup`'s 394 frames was NOT relied on for sizing.** The read is 3.19 s inside a 6.6 s
hold; it would fit with a wide margin at any plausible correction to that number, so the
P3.77 inference is not load-bearing here and I did not re-trace it.

### 4 — Verification (AC-by-AC)

**25.1 fresh tool output (verbatim, at `88f9592`):**
```
[sequences] port streams agree with the traced oracle over 80 steps, 9 sequences
ok   CELS_TAB   FLAME_BASE+50  = $3032 == cels_tab
ok   cel_plan     19 rows x 5 B =  95 B linked
ok   cel_page_tab  5 rows x 2 B =  10 B linked
res    7306 B -> padded 8192, tracks at +0 and +3584 (read to $C000/$CE00)
pg0..pg4  4683/5600/7680/7006/7523 B -> padded 7680, tracks at +0 and +3072 ($E000/$EC00)
=== BUILD COMPLETE ===
hal_sync_check.py -> OK (11 files compared)
```

**AC1 — packed and split, per-beat mapping, schedule in the PLAN, no straddling** — **yes.**
Asserted in the packer on the real sets (§3A). 18 beats, 5 pages, 3 blocks.

**AC2 — a signature per block, guard checks the one the pointer needs, refuse-to-draw kept,
still a magic** — **yes.** Two comparisons: the pinned page's `$C35A` and the rotating page's
per-page magic against `cel_pg_sig`, which the schedule publishes; `0` means "this beat draws
only pinned cels" and is itself asserted by the packer. Verified by symbol:
`ch_bankerr (build/obj/char_draw.o) = 4312`.

**AC3 — guard exercised by a REAL wrong mapping** — **built, not yet run.**
`-DSEED_WRONGBLOCK` makes `vb_apply` map the block *next to* the one the schedule chose:
the signature expected is unchanged, the pointers stay valid-looking, and the window holds a
real page belonging to another beat. It is in the tree and has **not** been exercised,
because the unseeded build does not yet finish the scene. **Not claimed.**

**AC4 — two staged reads, cost measured** — **yes** (§3E). 3.19 s / 2.89 s.

**AC5 — beats landed, `Vraise` not without `Pback`, totals reported** — **partly.**
`s_Buildup`, `Vraise`, `Pback`, `Vexit`, `Pslump` are in `PLAN`, in `PlayCut0`'s order, and
Vraise+Pback landed as one edit. Loaded total **43,158 B** on disk (7,306 pinned + 32,492 in
five pages + padding), bank occupancy **7,306 of 8,192** pinned and **4,683–7,680 of 7,680**
per page. **The hourglass, its flash, the `s_Magic` hold, the 16-colour swap and the
`Prolog2` handoff are NOT built** (§6).

**AC6 — the suite cannot pass on nothing** — **yes, and it is doing its job.**
`page_sig_matched_every_frame` now carries its **sample count inside the assertion**
(`PASS (2749 checked, 0 sustained mismatches)`) — it previously reported PASS having compared
nothing on a run where the scene never started. The zero-capture check and the bank-guard
check both still fire, and the shell requires each assertion's **PASS line to be present**, so
a check that does not run at all is a failure. **The staged-read counter was itself wrong and
was fixed** — it counted disk calls against pages and reported `4 of 2 completed` for a run in
which both reads were perfect.

**★ And the checks were checked.** `verify_sequences.py` was run against a restored copy of
the old unscoped parser and **failed as it should**, naming `Pback` at step 6 and `Vraise` at
step 18. Both stride checks were confirmed against the real linked byte counts.

**AC7 — all suites green both sizes** — **NO.** `run_room_test.sh` and `run_walk_test.sh`
reach the room and the walk correctly, but the walk suite ends **FAIL**: `beats_visited
17 of 18`, and the guard and read counters read garbage because the runaway overwrites the
bundle bytes they live in. Intro and 128 KB runs were **not re-run** after the last fix —
not claimed. Build verified by symbol from a **freshly baked** image (`bake_scene.py` run
deliberately before each build; `build.bat` still does not do it — carried).

**AC8 — Jay gates live** — **NOT OFFERED.** The scene does not finish.

**AC9 — route accounting present; sync bridge green; Karateka and both `main`s untouched** —
yes (§0, §6).

**25.2:** N/A — no sibling-import artifact. **25.3: not offered**, with reason.

### 5 — What is still broken, precisely

`Vexit` ends `goto Vwalk2`, so the vizier keeps walking out — as he does in the oracle, for
the 40 plays the scene has left. **The port has no clipping for a character leaving the
screen**, and has never needed one. Measured on the machine:

```
f4941  x=233  col=85   cols 85..92     past VIS_R (74) and past the 80-byte row
f5019  x=254  col=97   cols 97..102
f5025  x=0                              CH_X is one byte and WRAPPED
f5096  cel=29 x=191 face=79 awid=244    the slot record is now garbage
```

Three separate things: `co_setup` computes `col = px/4` unbounded; `co_clip` blanks the spill
**after** the blit rather than bounding it; and `CH_X` is a byte that wraps at 255. The oracle
clips every image to `LEFTCUT..RIGHTCUT` in bytes [HIRES.S CROP].

**★ I asserted this cause once from the tracer before measuring it, and was wrong** — I said
he left the edge during `Vexit` when the build at that moment was stalling before he ever got
there. Jay's *"i don't see the vizier walking to the right edge"* is what sent me to the
machine. The numbers above are the engine's own `CH_X`/`ch_col`/`ch_w`/`ch_h`/`ch_dest`.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** The dispatch asked for §1 (pack, split, per-block signatures, per-beat
mapping), §2 (two staged reads, measured), §3 (the beats **including the hourglass, the
16-colour swap and the `Prolog2` handoff**), §4 (verification) and §5 (Jay's live gate).

**This contains §1 complete, §2 complete and measured, §3's five CHARACTER beats, and §4 in
part.** It does **not** contain:

- **the hourglass (`addglass1`), its lightning flash, and the `s_Magic` hold** — `PlayCut0`
  places all three between Pback and Vexit; my beat 13 is a bare 5-play hold sitting exactly
  where they belong. **Jay found this by watching it run, not I.** The hourglass is not a
  character sequence — it is `GlassState`/`psandcount` on the background plane with a
  whole-screen colour override — so nothing in this dispatch's machinery would have produced
  it. Also missing: `addglass1` state 1 after Vexit, and `s_StTimer`.
- **the 16-colour swap and the `Prolog2` handoff** — not started.
- **the live gate** — not offered.
- **AC3's seeded real wrong mapping** — built, not run.

**Deviations taken:**
- **The packer gained a phase the dispatch did not name** (§3A, pin a beat that would spend a
  whole block on 78 bytes). Without it the scene did not pack at all once the sequences were
  corrected — and reporting "the scene cannot be packed" would have been a false finding.
- **`verify_sequences.py` is new and gates the build.** Not asked for; it is the check that
  would have caught §3C, and §3C cost most of this dispatch.
- **The room's two mirror paths were merged** to recover LOADM headroom — ROOM.BIN sits at
  `$2479`, **7 bytes** under the practical `$2480` ceiling. That is not a margin; the next
  thing added to ROOM.BIN will not fit.

### 7 — Uncertainty flags

- **★ THE FREEZE IS 3.19 s AND 2.89 s, NOT THE 1.7 s JAY ACCEPTED.** P3.75 §4A costed one
  track plus a spin-up; a page is **two** tracks. The known lever is the runtime mirror
  (P3.76 §3D: ~5,155 B, "two tracks into one"), which the dispatch calls optional. **Jay's
  call, and it should be made before the gate.**
- **The scene does not finish** (§5). Everything after the vizier reaches the right edge is
  unverified — including whether `Pslump` and the terminal beat render correctly.
- **The 128 KB runs and the intro suite were not re-run** after the final fix.
- **`ch_bankerr` and `cel_rd_err` are read out of the bundle**, which the runaway overwrites,
  so their values in a failing run are meaningless. They were trustworthy in the runs where
  the scene did not run away, and that is the only reason §3D could be attributed.
- **ROOM.BIN has 7 bytes of headroom.**
- Carried: `build.bat` does not run `bake_scene`; 0.20 s per-call driver overhead; the
  `$2310..$2329` read-tap blindness; `PlayCut0`'s remaining sound sites.

### 8 — Follow-up candidates

1. **Clip the character draw at the screen edge, and widen `CH_X`** — this is what stops the
   scene finishing, and the oracle's own `CROP` is the model.
2. **The hourglass beat**: `addglass1` states 0 and 1, the 5-frame `lightning`/`lightcolor`
   flash, and `s_Magic` as a measured hold. **`s_Magic` would also give the packer a third
   read point in the one region where it currently has none.**
3. **Run the seeded real wrong mapping** (AC3) once the scene completes.
4. Re-run both sizes and the intro suite.
5. `build.bat` should regenerate or verify the baked image (carried from P3.77).

### 9 — User interaction during task

Three interventions from Jay, all live-observation, all decisive:
1. *"the vizier walk is not animating. he teleports from the right side of the screen to in
   front of the princess"* — the guard refusing to draw, from the page-table stride bug.
2. *"there is no flash and no hourglass before the vizier turns to walk out"* — §6; verified
   against `PlayCut0` and correct.
3. *"i don't see the vizier walking to the right edge in the visual. you need to verify
   positioning"* — which overturned a claim I had made from the tracer and sent me to the
   machine (§5).

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-12-both-sides-of-a-check-from-one-derivation.md` — pushed
(`9b53dae`). An invariant check proves nothing when both sides of it come from the same
derivation; the packer's assertion agreed with itself because the tracer fed both halves.

### 11 — Commit

`88f9592` — pushed to origin/wip before this report.
