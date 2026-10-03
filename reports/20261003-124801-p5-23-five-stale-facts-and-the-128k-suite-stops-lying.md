## Form B Report — P5.23 — five stale facts corrected in place, and the 128 KB suite stops lying

**Class:** docs + harness config. `wip`. **Prod byte-identical; `probe.dmk` unchanged** (§0).
No engine change.

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-10-03T12:44:00-04:00 (HEAD **`62cec2e`**, wip — matches the dispatch; `main` **`32b5fe2`**).
Tracked tree clean.

**AC1 — sha1, receipt vs a full rebuild with every comment change in place:**
```
08bcae4a6249828a64554c61db9ed7ace72e4081  intro_seq.bin      IDENTICAL
10bddbd5413d14b1fbf26aeadb874515fc32b3e8  loader.bin         IDENTICAL
d5b17b6d468f1bcdd66163a60d9ffa1e36197e15  cutscene_room.bin  IDENTICAL
6c8d6e980c53eaa24d83eb383923f5a0568e4256  probe.dmk          IDENTICAL
92dc6d96778c71056ca37524779a5bcd1d61643c  flame_cels.bin     IDENTICAL  <- the bundle blit_core.s links into
```
**AC9 — `main` = `32b5fe2` at both ends.**

---

### 1 — Summary

**Four of the five are corrected in the tree, additively and visibly (P3.88's pattern). The fifth,
CLAUDE.md §2K, is DRAFTED below and NOT applied.** §2D says the working agreement's body is the
Orchestrator's to write and mine to commit after a superset check, and the dispatch supplied no text.
§8 makes the agreement outrank a dispatch where they conflict. **That is a stop, reported.**

**The grep found more than the list, and one distinction the list did not draw.** 1,922 B (and its
1,828 B character part) is **right as a residency figure**: what must be mapped into the CPU window,
which includes cels `GETWIDTH` only reads. That is how P5.6 and P5.7 used it, so they get **scope
notes, not retractions**. It is **wrong as a draw volume**, which is how P5.10, P5.11, P5.20 and
`blit_core.s` used it, so they get **corrections**.

**The 128 KB suite run is green for the first time since P5.15, because it now runs only `tile`.**
That green was **earned by scoping, not by fixing**, and the runner says so on every run.

---

### 2 — Files modified

- `src/engine/blit_core.s` — two comment blocks added (AC2, AC3). **No code; `flame_cels.bin`
  identical.**
- `reports/…p5-10-…md`, `…p5-11-…md`, `…p5-20-…md` — correction banners where the figures are used (AC4).
- `reports/…p5-6-…md`, `…p5-7-…md` — scope notes: residency stands, draw volume does not (AC4).
- `harness/tools/xform_cost_summary.py`, `harness/tools/frame_fit_summary.py` — a comment on `PEAK`;
  **outputs unchanged**, so they still reproduce what P5.20/P5.21 reported (AC4).
- `harness/smoke/run_suites.sh` — 128 KB runs `tile` only, with the reason; its stale line-16 note
  corrected (AC5, plus a sixth stale fact found by reading the whole file).
- `harness/smoke/ramsize.sh` — the "suites pass on it" note corrected; P3.10 kept (AC6).
- This report. **Not modified: `CLAUDE.md`** (AC7, §3E). **Not touched: `run_block_budget.sh`.**

---

### 3 — Reasoning

#### 3A — AC2: `blit_core.s:37`, corrected with both facts

Original line 37 kept. Added beneath it, read back from the file:

```
* ★★★ CORRECTED AT P5.23 -- THE "~14%" ABOVE WAS AN ESTIMATE, AND IT WAS QUOTED ONWARD. It was
* P5.10's ~14 cy/byte (an unwritten routine, scaled from this file's 4.5 cy/byte) times P5.7's
* 1,922 B. Both inputs have since been measured, and both were wrong:
*   * THE RATE. P5.20 built the runtime transform and timed it on all 290 gameplay cels (the
*     debugger's totalcycles, byte-exact): SHIFT 60.3, joint shift+mirror 61.6 cy per phase-0
*     footprint byte -- and THIS blitter, drawing the pre-baked pose, 78.5. On 1,922 B that is
*     ~61.5% of the step for a shift, ~80% baked: the shift is CHEAPER than drawing the bake.
*   * THE VOLUME. 1,922 B is NOT a draw volume. P5.21 found it counts cels the oracle only
*     MEASURED -- `setimage` is also called by GETWIDTH [HIRES.S:287-301], a size query -- as
*     well as cels it drew: frame 9328 drew 736 B and merely queried 1,092. The drawn character
*     peak over the demo is 963 B, which at 61.6 is ~31% of a 188,509 cy step.
*   * THE BUDGET. Per oracle game frame, draw + peel is at most ~40-44% of the time the ORACLE
*     itself took over that same frame (P5.21 §3G) -- the step above is a MEAN, and heavy frames
*     take the original longer too. Logic, scenery and sound are not in that figure.
```
*(963 × 61.6 = 59,321 cy = 31.5% of 188,509.)*

#### 3B — AC3: `blit_core.s:52-54`, scoped, number unchanged

Line 69 (formerly 54) still reads `= 4.5 cy/byte, inside the 4.5-5.8 band P3.19 measured for real 4-9
byte rows.` Added beneath it:

```
* ★★ SCOPE (P5.23): 4.5 cy/byte IS THE MOVER'S RATE ON A FOUR-BYTE GROUP, NOT THIS ROUTINE'S.
* Measured on all 290 gameplay cels, blit_cel draws at 78.5 cy per footprint byte -- about
* 101 cy per SEGMENT + 2.6 per byte + 92 per row (P5.20 §3D, corroborated by a static decode of
* this file's listing) -- because most segments are one byte long [P3.79], so the per-segment
* walk, not the mover, is four-fifths of the cost. Every estimate from P5.10 to P5.11 scaled
* from the 4.5 and came out 3-7x low. The number above is right; it is a number about pulu/pshs.
```

#### 3C — AC4: the grep, and what each hit is a number of

`1,922 | 1922 | 1,828 | 1828 | "joint per-frame peak" | "joint peak" | ~14% | "14% of" | "~14 cy"` over
the whole tree (PDFs excluded). **Every hit, and what was done:**

| hit | use | action |
|---|---|---|
| `src/engine/blit_core.s:37` | "~14%" of a step: **draw** | **corrected** (§3A) |
| P5.10 §3G (`:187-195`), §4.1 (`:257`), AC6/flag 3 | 1,922 B × 14 cy/B: **draw** | **banner** at §3G + pointer at §4.1 |
| P5.11 §3F (`:270-271`) | 1,922 × 20.6: **draw** | **banner** at §3F (also corrects "upper bound") |
| P5.20 §1 table + `:57`, §3G (`:321-331`), flag 3 | 1,922 B → % of step: **draw** | **banner** in §1 + pointer at §3G |
| P5.21 (whole report) | the **correction itself** | none — already states it |
| P5.7 §3F (`:241-259`), AC6 | joint maximum vs the 15,872 B **window** | **scope note**: stands as residency |
| P5.6 §3 (`:32, 91, 106, 133, 413, 479`) | worst-frame **window** set, labelled "draws" | **scope note**: "draws" → "touches" |
| `harness/tools/xform_cost_summary.py:30-31` | `PEAK` × rate → % of step | **comment**; output unchanged |
| `harness/tools/frame_fit_summary.py:19,53,105` | same | **comment**; output unchanged |
| `harness/tools/xform_probe_check.py:12` | names P5.7's **unit** (`coco3_bytes`) | none — correct |
| `harness/tools/oracle_step_analysis.py:8,12,119-120` | the **control** that found it | none |
| `harness/tools/animated_blocks.py:208` | P5.7's tool, joint **residency** peak | none — correct as residency |
| `mame-idioms-apple2e-oracle.md:871-873` | the idiom recording the finding | none |
| `src/harness/xform_probe.s:10` | names P5.10's ~14 as **an estimate** | none — accurate |
| PA.8 `:279` "MASTER 1,922" | a module size | unrelated |
| P3.77 `:59`, `src/hal/coco3-dsk/time.s:166` "~14 cy" | other quantities | unrelated |
| oracle `HRTABLES.S` `SHIFT0 …1828…` | a hex table | unrelated |

**The Orchestrator's list (P5.7, P5.10, P5.11, P5.20, `blit_core.s`) missed P5.6 and the two tools, and
the grep shows P5.7 should not be corrected the same way as the others.**

#### 3D — AC5/AC6: the 128 KB pass

`run_suites.sh` now sources `ramsize.sh` first. When `MAME_RAM` is `128K` it sets `SUITES="tile"` and
prints `128 KB: aliasing detector -- running 'tile' only (introseq/integ red by design since P5.15)`. The
comment keeps P3.10 and the block map ($0C-$0F / $10-$17 / $38-$3F) as the reason the pass still exists.
**`run_block_budget.sh` untouched.**

`ramsize.sh`: the "suites pass on it" note keeps its original text, with a correction directly beneath.
The port still runs on 128 KB; `tile` passes; `introseq`/`integ` are red by design and no longer run
there. **The P3.10 block is unchanged.**

★ **A sixth stale line found by reading the whole file:** `run_suites.sh:16` said *"MAME_RAM=512K …
the confirmation machine; 128 KB is the target and the default."* Corrected beneath, since it is §2.6's
fact in another home.

★ **Also noticed, NOT changed (out of the five):** `run_suites.sh:55-58` says removing the harness probe
files from the image "moves the tracks". P5.22's gate image removed all four and **no raw track moved**;
they are placed at explicit track numbers. That comment is wrong in the same way, and is named here for a
later sweep.

#### 3E — ★ AC7: CLAUDE.md §2K — DRAFTED, NOT APPLIED, and why

**The conflict.** §2D: *"Clyde does NOT edit the body of authored authoritative docs directly… Jay
authors / Orchestrator drafts / Clyde renders"*, and CLAUDE.md's own changelog records v1.1 as
*"Orchestrator-authored per §2D"*. §8: *"Invariants here take precedence over task-contract instructions
where they conflict."* The dispatch asks me to amend §2K **without supplying the text**. **Stopped.** The
draft is below for the Orchestrator to adopt or rewrite; I'll commit whichever comes back (superset-
checked against the in-repo copy).

**OLD (CLAUDE.md:292-309, verbatim headings and first paragraphs):**
> ## 2K. 128 KB is the verification target
>
> **Verify on stock 128 KB first. It is the target machine and it is strictly the harder case:** the GIME
> masks a block number to the RAM actually installed … **512 KB can pass while a masking assumption is
> wrong; the reverse does not happen.**
>
> **512 KB is confirmation, not the primary run, and most dispatches do not need it.** Run it when a
> change touches the MMU, the bank, the framebuffers or the loader … **Report 128 KB first in every
> case.**
>
> *(then the HAL mechanism paragraph and the P3.10 precedent, unchanged in the draft)*

**DRAFT NEW:**
> ## 2K. 512 KB is the verification target; 128 KB is the aliasing detector
>
> **Verify on 512 KB first. It is the target machine** (Jay, 2026-08-22: *"lets move to the 512kb as the
> standard"*; P5.12: the game needs 16–44 blocks, 128 KB has 8). **Report 512 KB first in every case.**
>
> **128 KB is still run, for one reason: it is strictly the harder case for block MASKING.** The GIME
> masks a block number to the RAM actually installed, so on 128 KB the framebuffers alias and the bank
> occupies the top of real RAM. **512 KB can pass while a masking assumption is wrong; the reverse does
> not happen.** The port still uses only $0C-$0F / $10-$17 / $38-$3F, real on 512 KB and correctly
> aliased on 128 KB, so a 128 KB run is a detector that fires the moment anything claims a block above
> $0F. **At 128 KB only `tile` runs** (`run_suites.sh`); `introseq` and `integ` are red there by design
> since P5.15, and a suite that is always red reports nothing. **A divergence between the two sizes is
> itself informative: it means something depends on aliasing.**
>
> *(the HAL mechanism paragraph and the P3.10 precedent, kept verbatim)*

---

### 4 — AC10: what is not being proposed

1. **Not applying the §2K amendment** (§3E): drafted for the Orchestrator per §2D.
2. **Not changing any number** in `blit_core.s` or any report; every correction is additive.
3. **Not fixing `blit_core.s`'s per-segment overhead** (§4 of the dispatch: documenting a cost is not
   permission to change it).
4. **Not correcting P5.6/P5.7's figures**: they stand as residency; only their scope is annotated.
5. **Not sweeping `run_block_budget.sh`** or the `run_suites.sh:55-58` comment (§3D, named for later).
6. **Not seeding a block-above-$0F fault** to prove the 128 KB detector still fires. That would be an
   engine change. It is untested in this dispatch; P3.10 is the existing evidence that it fires.

---

### 5 — Verification (AC-by-AC)

- **AC1** — §0, five sha1s identical after a full rebuild, `probe.dmk` and `flame_cels.bin` included.
- **AC2** — §3A, quoted from the file. **AC3** — §3B, quoted; the 4.5 is unchanged.
- **AC4** — §3C: every hit listed with its use and action; 7 locations changed, the rest justified.
- **AC5** — §3D, `tile` only at 128 KB; `run_block_budget.sh` untouched.
- **AC6** — §3D, corrected with P3.10 kept.
- **AC7** — **NOT MET by design, stopped on §2D/§8** (§3E): old quoted, new drafted.
- **AC8** — **512 KB: ALL PASS** (`introseq`, `integ`, `tile`). **128 KB: ALL PASS — `tile` only.**
  ★ **The first all-green 128 KB run since P5.15, earned by scoping the run, not by fixing anything.**
- **AC9** — §0. **AC10** — §4. **AC11** — §6.

### 5b — Verdict-time evidence

```
build.bat: === BUILD COMPLETE === ; five sha1s identical (§0)
run_suites.sh 512K: [run_introseq_test] PASS / [integ] PASS / [run_tile_test] PASS / [suites] ALL PASS
run_suites.sh 128K: [suites] 128 KB: aliasing detector -- running 'tile' only (introseq/integ red by design since P5.15)
                    [run_tile_test] PASS / [suites] ALL PASS
```
**25.2:** N/A. **25.3:** N/A — nothing on screen can change; no byte moved.

---

### 6 — Reactive deviations and route accounting

1. **★ AC7 stopped** on CLAUDE.md §2D/§8 (§3E). The dispatch's instruction conflicts with the working
   agreement, and the agreement wins until the Orchestrator supplies text or Jay rules otherwise.
2. **P5.6/P5.7 annotated, not corrected**, because the grep showed their use is right (§3C).
3. **A sixth stale line corrected** (`run_suites.sh:16`), and one more named but not changed (`:55-58`).

**ROUTE ACCOUNTING.** No route proposed. The change contains comments, report banners and one runner
condition. It contains **no** CLAUDE.md edit and **no** code.

### 7 — Uncertainty flags

1. **The 128 KB detector's ability to fire is asserted from P3.10 and the block map**, not re-proven
   here (§4.6).
2. **The P5.21-derived figures in the banners (963 B, ~31%, ≤ 40–44%) rest on one demo run**, P5.21's
   own flag.

### 8 — Follow-up candidates

1. **The §2K amendment**: Orchestrator text, then my commit.
2. **`run_suites.sh:55-58`'s "moves the tracks"** is contradicted by P5.22's gate image.
3. **`blit_core.s:29`'s "8 free on a 128 KB machine"** is true but frames a target that has moved. Left
   alone (not one of the five).

### 9 — User interaction during task

None.

### 10 — Candidate(s) captured this task

None. The pattern (a residency figure quoted as a draw volume) was captured at P5.21
(`a-funnel-tap-counts-every-caller`); this dispatch is its clean-up, not a new instance.

### 11 — Commit

**`8c21b7b`**; this hash line follows in its own commit. Pushed to `origin/wip`. `main` untouched at
`32b5fe2`.
