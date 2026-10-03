## Form B Report — P5.26 — CLAUDE.md §2G rendered: Karateka and coco_agi are synchronized siblings (v1.3)

**Class:** docs. `wip`. **Prod byte-identical** (§0). One file changed: `CLAUDE.md`.

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-10-03T13:15:01-04:00 (HEAD **`3b7ca6d`**, wip; the dispatch was drafted at `fa18fb6`, and
dispatch 173 / P5.25 landed since as `e8c6e80` + `b6a7be2` + `3b7ca6d`; `main` **`32b5fe2`**). Tracked
tree clean.

**AC1 — receipt vs a full rebuild after the edit:**
```
08bcae4a6249828a64554c61db9ed7ace72e4081  intro_seq.bin      IDENTICAL
10bddbd5413d14b1fbf26aeadb874515fc32b3e8  loader.bin         IDENTICAL
d5b17b6d468f1bcdd66163a60d9ffa1e36197e15  cutscene_room.bin  IDENTICAL
6c8d6e980c53eaa24d83eb383923f5a0568e4256  probe.dmk          IDENTICAL
92dc6d96778c71056ca37524779a5bcd1d61643c  flame_cels.bin     IDENTICAL
```
**AC9 — POP `main` = `32b5fe2` at both ends.** No sibling repo touched.

---

### 1 — Summary

§2G is replaced with the Orchestrator's text, rendered per §2D, **after the superset gate passed**. The
section now describes the HAL as eleven files synchronized across three repos with a build-blocking gate,
not a read-only reference. **173 had landed, so this is v1.2 → v1.3**, with its own changelog entry
after v1.1 → v1.2. **Three changes to the supplied text, each because the file or the AC outranks the
dispatch** (§3C): the blocked-build message is quoted in full from `build.bat`; "byte-identical" is
qualified to what the script actually compares (it normalises line endings, guards and export placement);
and the bold added around "Reuse the SUBSTRATE, not the game." is dropped so AC5's verbatim comparison holds.
Suites: 512 KB ALL PASS, then 128 KB (`tile`) ALL PASS.

---

### 2 — Files modified

- `CLAUDE.md` — lines 2–3 (version → 1.3), a new changelog entry at 17–21, and §2G between the `## 2G.`
  and `## 2H.` headings. **Nothing else** (`git diff -U0`: four hunks, all within these places; 43
  insertions, 21 deletions).
- This report.

---

### 3 — Reasoning

#### 3A — AC3: the superset diff-check (§2D's hard gate), run on the whole old section

Anchored on the headings (`## 2G.` at 203, `## 2H.` at 227 at receipt), not the dispatch's line numbers,
which had moved by 6 since `fa18fb6`. Every substantive claim of the old §2G:

| old content | disposition |
|---|---|
| heading *"Karateka is a read-only SIBLING implementation reference"* | **superseded** (row 1 of the dispatch's table) |
| *"POP reuses Karateka's proven, Jay-gated CoCo3 substrate."* | **kept verbatim** |
| *"Karateka's repo is READ-ONLY, alongside `POP3_port`"* | **superseded** (row 1) |
| local clone `/c/Projects/karateka_coco3` | **superseded** — now `C:\Users\jayse\DEV\<name>`, derived from the script |
| underscore/hyphen note | **kept** (reworded by the Orchestrator, same facts: `karateka_coco3` vs `Jsearle01/karateka-coco3`, not interchangeable) |
| reuse-and-reference list | **superseded** (row 6). Per-item check below |
| *"Copy-and-adapt, don't depend"* / *"never modify Karateka"* / *"no build-time dependency"* | **superseded** (rows 2, 3, 4) |
| *"Confirm each for POP — reuse the mechanism, verify the constant/behavior … sanity-check on the first per-frame build"* | **kept in substance** |
| *"Back-ports are separate explicit tasks … never an automatic sync"* | **superseded** (row 5) |
| *"What does NOT transfer"* | **kept verbatim** (§3B) |

**Row 6, item by item. The dispatch flagged this one as the row most likely to lose something.** Each
fact from the dropped reuse list, and where it is still recorded:

| dropped fact | still recorded at |
|---|---|
| `gfx.s`: blit primitives, 4-phase shifter, `$FFD9` double-speed init | the file itself (`gfx.s:226-232`), now named in the shared list |
| page-flip = VOFFSET `std $FF9D`, NOT a copy | `gfx.s:932-1002` (`HAL_gfx_present`'s header and code) |
| disk-speed rule: double speed breaks the FDC, so disk runs at normal speed | `mame-idioms-coco3-port.md:143, 175-178`; P5.22 measured disk at normal speed (`:2207`), which settles "PROVISIONAL" |
| 320×192, `$FF99=$15` | `gfx.s:27, 202-204`; idioms §19e |
| ~29,859 cyc/frame VBL budget | `mame-idioms-coco3-port.md:31-32` |
| 6809-only; 6309-equivalent | `project-state.md:181` (*"6309-equivalent code is acceptable; 6309-only instructions are not"*) |
| tooling (build.bat, run_* scripts, phasecost, sprite tool) | in-tree; a description of where it came from, not a rule |
| coco3 MAME idioms | §2A, which owns them |

**Result: superset holds. All six superseded items are accounted for, and no seventh was found.** The one
fact I checked hardest was **6809-only**, because it is a hard ISA constraint rather than a description.
It survives at `project-state.md:181`, but that file is not a governing document. **If the Orchestrator
wants that constraint in CLAUDE.md, it now lives nowhere in CLAUDE.md** (§8.1). I judged this as covered,
not a stop, because the dispatch's own reading assigns the constants to "elsewhere".

#### 3B — AC5: the "What does NOT transfer" bullet, shown identical

Extracted between the `## 2G.`/`## 2H.` anchors from `git show HEAD:CLAUDE.md` and from the edited file,
whitespace-normalised, compared as strings:
```
OLD: Karateka's scene logic, sprite content, behavioral models, attract-loop specifics. Reuse the SUBSTRATE, not the game.
NEW: Karateka's scene logic, sprite content, behavioral models, attract-loop specifics. **Reuse the SUBSTRATE, not the game.**
identical: False | identical ignoring ** emphasis: True
```
The dispatch's §2 text adds bold to the last sentence, and AC5 asks for the bullet verbatim, so the two
conflict. **I applied AC5 and removed the added `**`.** The bullet in the file is now the old text exactly
(`CLAUDE.md:242-243`). If the Orchestrator meant the emphasis, re-adding it is a two-character edit.

#### 3C — AC6/AC7: the text checked against the files it describes; two corrections

- **AC6. The SHARED list matches.** `hal_sync_check.py:69-75` has eleven entries: `src/hal.inc`; `sys`,
  `time`, `irq_vbl`, `gfx`, `input`, `sound`, `file`, `mem`, `disk_read` `.s` under
  `src/hal/coco3-dsk/`; and `harness/tools/hal_sync_check.py` (*"checks itself"*). This is the same set
  and order as the dispatch's text. `PARTICIPANTS` (`:65`) =
  `['POP3_port', 'karateka_coco3', 'coco_agi']`. The sibling path is `here = …parents[2]` (`:192`) plus
  `here.parent / other` (`:204`), i.e. `parents[2].parent / <name>`, as written. The `hal_globals.s`
  escape is `PROJECT_LOCAL` (`:87-91`): every participant, with the reasons given at `:84-86`.
- **AC6, correction 1: "byte-identical".** The script does not compare bytes. Its own OK line reads
  *"11 files compared, EOL/guard/export-placement normalised"*, and `normalise()` (`:96-`) strips exactly
  those differences. karateka's copies are CRLF, while POP's and coco_agi's are LF, so the files are
  **not** byte-identical, and the check passes anyway. Applying "the script wins", the paragraph now reads
  *"requires them identical (after normalising line endings, `ifdef` guards and export placement)"*, and
  the changelog says *"eleven identical files"*. "Byte-identity" in the cross-repo bullets is unchanged,
  because it is about the siblings' **emitted artifacts**, and for those it is correct.
- **AC7, correction 2: the message.** `build.bat:63-67` is as the dispatch says (`python
  harness\tools\hal_sync_check.py` / `if errorlevel 1` / echo / `exit /b 1`). But the message at `:65` is
  `*** BUILD BLOCKED BY HAL DRIFT — see [hal-sync] above ***`, not `*** BUILD BLOCKED BY HAL DRIFT ***`.
  It is now quoted in full. The script's own line (`:231`) is a different string,
  `[hal-sync] *** HAL DRIFT -- BUILD BLOCKED ***`.

#### 3D — One line of pushback, as §7 invited (not acted on)

**"Fails all three builds" is true only for the siblings that are present and only when python is.** If a
sibling is missing, the check warns and skips that pair (`hal_sync_check.py:205-219`). If no participant is
present, or python is not on PATH (`build.bat:59-61`), the build **proceeds** with a WARNING. This is
deliberate: *"a check that blocks legitimate builds gets deleted"* (`build.bat:53-54`). It interacts with
the new path sentence, though. **A clone in the wrong place is not compared, and it is not flagged as an
error either: it is skipped with a warning and the build goes green.** That is exactly how the
`C:\Projects` copies could fall behind unnoticed. If the Orchestrator wants it, one sentence would cover
it, e.g. *"An absent sibling is skipped with a WARNING, not a failure: read the `[hal-sync]` line, not the
exit code."* Not added; that is new content. Also, `build.bat:56-57` calls the block *"TEMPORARY BY DESIGN
— … delete cleanly when the kernel becomes a single shared source"*. That is consistent with §2G's title,
but it is a stated future that §2G does not mention.

#### 3E — AC2/AC4: the new text, read back from the file

**§2G (`CLAUDE.md:209-245`):**
```
## 2G. Karateka and coco_agi are SYNCHRONIZED SIBLINGS — the HAL is one source in three repos

POP reuses Karateka's proven, Jay-gated CoCo3 substrate. **The HAL is no longer copied: it is
SYNCHRONIZED.** `harness/tools/hal_sync_check.py` compares eleven files across **POP3_port**,
**karateka_coco3** and **coco_agi** and requires them identical (after normalising line endings, `ifdef`
guards and export placement):

    src/hal.inc
    src/hal/coco3-dsk/{sys,time,irq_vbl,gfx,input,sound,file,mem,disk_read}.s
    harness/tools/hal_sync_check.py          <- it compares itself

**This IS a build-time dependency.** `build.bat` runs the check before anything else and, on drift,
prints `*** BUILD BLOCKED BY HAL DRIFT — see [hal-sync] above ***` and exits 1 — **in every participant**.
A shared file that differs between repos fails all three builds, not just the one that changed.

**Siblings' local clones are `C:\Users\jayse\DEV\<name>`** — the check derives them as
`parents[2].parent / <name>`, so a clone anywhere else is not what it compares. **NOTE: the local dir
uses an underscore (`karateka_coco3`); the GitHub remote is `Jsearle01/karateka-coco3` with a hyphen.
Not interchangeable.**

- **A change to a shared HAL file is a CROSS-REPO TASK, not a POP edit.** Land the same text in all three,
  run the check from each, and **prove the siblings' emitted bytes** — rebuild each sibling, **name which
  of its artifacts embed the changed file, and show those were regenerated by the after-build.** An
  artifact that was not rebuilt compares identical for free. *Standard set by P5.18b; met by P5.24.*
- **If a sibling's bytes cannot stay identical, STOP and surface it.** The gate will force the change into
  them; that is a mechanism, not permission. **Moving a sibling's shipped bytes is Jay's decision.**
- **A guard is the cheapest shape.** New HAL capability behind `ifdef` that no shipped build defines costs
  the siblings nothing and needs no ruling (P5.24: `HAL_DISK_DRIVE_SELECT`).
- **Project-local data has one sanctioned escape:** `src/hal/coco3-dsk/hal_globals.s` is per-repo by
  design — DP allocations everywhere, plus POP's own `gfx_mode_table` (POP-HAL-01) and coco_agi's. **Shared
  mechanism, project-local data.** Nothing else may diverge.
- **Confirm each behaviour for POP** — reuse the mechanism, verify the constant. Same video mode should
  mean the same budget; sanity-check it on the first per-frame build anyway.
- **What does NOT transfer:** Karateka's scene logic, sprite content, behavioral models, attract-loop
  specifics. Reuse the SUBSTRATE, not the game.
- **A sibling you cannot build, you cannot clear.** The byte-identity standard above requires rebuilding
  each participant; if one will not build, say so in the report rather than clearing it by inspection.
```

**Version and changelog (`CLAUDE.md:2-3, 17-21`). Numbering: v1.2 → v1.3, because 173 had landed:**
```
## Working Agreement v1.3 (adapted from Karateka CLAUDE.md v1.0)
**Version:** 1.3
…
**Changelog v1.2 → v1.3 (2026-10-03, Orchestrator-authored per §2D):** §2G rewritten — Karateka and
coco_agi are synchronized siblings, not read-only references. The HAL is eleven identical files
across three repos, enforced by hal_sync_check.py, which blocks every participant's build on drift; a
shared-HAL change is a cross-repo task with a byte-identity proof (P5.18b, P5.24). Corrects the sibling
clone path, which named C:\Projects rather than the C:\Users\jayse\DEV clones the check compares.
```
The only change from the dispatch's §4 is "eleven byte-identical files" → "eleven identical files" (§3C).
No BOM; the file still begins `# CL`.

---

### 4 — AC10: what is not being proposed

1. **No other CLAUDE.md section touched**, §2K included.
2. **No sibling touched.** karateka's and coco_agi's own CLAUDE.md files presumably still describe this
   relationship the old way. **Named, not done**: that is a back-port for their maintainers (§8.2).
3. **No code, harness or content change.** `build.bat` and `hal_sync_check.py` were read, not edited.
4. **§3D's sentence and §3A's 6809-only placement are not added.** Both are the Orchestrator's call.
5. Out of scope and untouched: coco_agi's baseline assembly break (§5.360), and `run_suites.sh:55-58`
   (§5.353).

---

### 5 — Verification (AC-by-AC)

- **AC1** — §0, five sha1s identical after a full rebuild.
- **AC2** — §3E, quoted from the file.
- **AC3** — §3A: superset holds; six superseded items accounted for, row 6 item by item; no seventh.
- **AC4** — §3E: version and changelog quoted; the numbering is v1.2 → v1.3.
- **AC5** — §3B, shown by comparison. Identical after the added bold was removed.
- **AC6** — §3C: matches the script's `SHARED`. The "byte-identical" wording was corrected to the
  script's normalised comparison.
- **AC7** — §3C: `build.bat:63-67` verified; the message is corrected to the file's full string.
- **AC8** — **512 KB first: `introseq` PASS, `integ` PASS, `tile` PASS, ALL PASS; then 128 KB: `tile`
  PASS, ALL PASS.**
- **AC9** — §0.
- **AC10** — §4.
- **AC11** — §6.

### 5b — Verdict-time evidence
```
build.bat: [hal-sync] OK -- HAL source aligned with karateka_coco3, coco_agi (11 files compared, EOL/guard/export-placement normalised)
           === BUILD COMPLETE === ; five sha1s identical (§0)
run_suites.sh (MAME_RAM default 512K): [run_introseq_test] PASS / [integ] PASS / [run_tile_test] PASS / [suites] ALL PASS
run_suites.sh (MAME_RAM=128K): [suites] 128 KB: aliasing detector -- running 'tile' only ... / [run_tile_test] PASS / [suites] ALL PASS
```
25.2: N/A. 25.3: N/A (docs; nothing on screen changed).

### 6 — Reactive deviations and route accounting

1. **Three edits to the supplied text** (§3B, §3C): the full message, the normalised-not-byte-identical
   wording in the paragraph and the changelog, and the bold dropped for AC5. Each is backed by an AC that
   says the file wins over the dispatch.
2. **The numbering is v1.2 → v1.3**, as the dispatch anticipated if 173 had landed.

**ROUTE ACCOUNTING.** I proposed no route. In P5.24 §8.2 and P5.25 §8.2 I proposed only the path fix;
this change contains that and the Orchestrator's wider rewrite. Nothing I proposed is left undone.

### 7 — Uncertainty flags

1. One harness slip on my side: my first 128 KB run passed a positional `128K`, which `run_suites.sh`
   ignores, so it ran 512 KB a second time. The 128 KB line in §5b is from the rerun with `MAME_RAM=128K`.
   No effect on the result; recorded so the duplicate 512 KB run is not mistaken for 128 KB.

### 8 — Follow-up candidates

1. **6809-only / 6309-equivalent** is no longer stated in CLAUDE.md. It lives only in `project-state.md:181`
   (§3A). Restore it if the Orchestrator wants it governing.
2. **The siblings' own working agreements** probably describe the relationship the old way. That would be
   a back-port in each repo, if wanted.
3. **§3D's sentence** about a skipped sibling producing a green build.
4. Unchanged: §3E of P5.25 (the P3.10 sentence re-point).

### 9 — User interaction during task

None.

### 10 — Candidate(s) captured this task

None.

### 11 — Commit

**`1a84948`**; this hash line follows in its own commit. Pushed to `origin/wip`. `main` untouched at
`32b5fe2`.
