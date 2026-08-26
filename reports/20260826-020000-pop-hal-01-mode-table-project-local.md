## Form B Report — POP-HAL-01 — the mode descriptor table becomes project-local

**Class:** build (HAL refactor). `wip` in **both** repos. **`main` untouched.** Prod bytes **moved**;
behaviour did not. ★ **Sanctioned one-time re-baseline** — new hashes recorded in §5.

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-26. HEAD `282a65cf` → **`69bec9c4`**, `wip`.
`main` = `32b5fe23a49bf43e86c64f867ff59fb40c1ce0db`, untouched.
karateka `wip` `072ddcfc` → **`1b5ad76b`**; karateka `main` = `5eb92b14`, untouched.
`git status --porcelain src/` → **0**.

★ **Dispatch author's standing:** written by the `coco_agi` Orchestrator, not POP's, on Jay's ruling.
§2's grep below surfaced two things that dispatch could not have known — see §3.1 and §3.4.

---

### Pre-dispatch grep (§2) — verbatim

```
POP3_port        wip  282a65cf9c79739326e101b3d7cccffc8cff2daa   tracked dirty: 0
karateka_coco3   wip  072ddcfc27ccb2c0a9b820913cd57b341a6e6fbc

in-flight work on gfx.s / hal_globals.s / hal.inc:  NONE
  uncommitted: none.  last commits touching them:
    a7664bf P5.18: HAL_gfx_clear asks the mode for its geometry — landed in POP and karateka together
    ca5abcf P2.5: HAL_gfx_set_mode -- the first real kernel graphics service
    dd1cec4 P2.4: POP converts to the OBJECT/LINKED build model + HAL-sync bridge

build.bat CRLF state: CR=923 LF=923 CRLF=923 -> CRLF-clean, cmd.exe parses it.
  git ls-files --eol: i/lf w/crlf attr/text eol=crlf.  status: 0 dirty.
  ★ coco_agi's T-P0-010 repaired this working-tree defect at 282a65cf by re-checkout;
    the committed blob was already correct and nothing was committed in POP.

gfx.s:  ifdef HAL_GFX_MODE_SERVICE spans 76..842
        GFX_MODE_MAX   equ 1   line 347      GFX_MODE_ENTSZ equ 7   line 348
        gfx_mode_table         line 774      gfx_pal4 801, gfx_pal16 807
        HAL_gfx_cur_* 830-841
hal_globals.s: 84 lines, PURE EQUATES — emits nothing, opens NO section.
        PROJECT_LOCAL in hal_sync_check.py: yes.
karateka: builds clean, exit 0. Does NOT define HAL_GFX_MODE_SERVICE (no -D anywhere). ✓
```

★★ **The "27 artifacts" and "three prod artifacts" figures are both wrong, and §7 asked.**
Measured by mtime across a build: **`build.bat` writes 125 files** — 22 `.bin`, 1 `.dmk`, 21 `.map`,
24 `.o`, 19 `.raw`, 31 `.s`, 6 `.lz`, 1 `.inc`. POP ships **six DECB files plus one image**
(`PROBE/MODE/ANIM/INTRO/LOADER/TILE.BIN` + `probe.dmk`), not three. "27" was the count that
*changed* under `coco_agi`'s mode-2 experiment, not the count POP produces.

---

### 1 — Summary
`gfx_mode_table` and `GFX_MODE_MAX` move from `gfx.s` (SHARED) to `hal_globals.s`
(PROJECT_LOCAL); the mode service code stays in `gfx.s`. **Shared mechanism, project-local data.**
karateka is **byte-identical (104/104)** — the move is invisible where the service is undefined.
POP's artifacts change **exactly once**, and every `.bin`/`.dmk` keeps its **exact size**, which is
the signature of relocation rather than growth. A third mode can now be added to `hal_globals.s`
alone, with `hal-sync` still OK — demonstrated and reverted.

### 2 — Files modified
- `src/hal/coco3-dsk/gfx.s` — **SHARED.** `GFX_MODE_MAX` and `gfx_mode_table` removed; the row-layout comment and the documented requirement remain. **Identical edit landed in karateka** (`1b5ad76b`), verified by diffing the two diffs.
- `src/hal/coco3-dsk/hal_globals.s` — **PROJECT_LOCAL, POP only.** Gains `GFX_MODE_MAX` and the table, guarded by `HAL_GFX_MODE_SERVICE` and wrapped in an `OBJTARGET` section.

karateka's `hal_globals.s` is **deliberately untouched**. Explicit-path staging.

### 3 — Reasoning

**3.1 ★★ POP's CLAUDE.md §2G is STALE, and this is the §2-grep contradiction.**
§2G says karateka is *"read-only"*, that POP should *"copy-and-adapt, don't depend"*, that
**"POP has no build-time dependency on it"**, and that back-ports are **"never an automatic sync."**
All four are false of the current tree: `hal_sync_check.py` runs inside `build.bat` and **fails the
build on drift against karateka**, which is both a build-time dependency and an automatic sync.

★ It is stale, not contradicted: the sync bridge arrived at **`dd1cec4` P2.4**, after v1.1 was
written, and **`a7664bf` P5.18 already landed a shared `gfx.s` change "in POP and karateka
together"** with Jay's approval. So POP's own history establishes the practice this task follows.
**I proceeded**, because §2G's prohibition is on modifying karateka's *content*; the HAL is
synchronised by tooling POP itself runs, and the precedent is POP's own. ★ **§2G needs updating —
that is an Orchestrator doc edit (§2D), not mine.** Flagged in §8.

**3.2 The change, and what it is.** `GFX_MODE_ENTSZ` **stays** in `gfx.s`: the row *layout* is what
the shared service indexes with, so a project that changed it would break shared code. **Layout is
mechanism; rows are data.** This is a **relocation, not a revision** — POP's own §2F.1.7 discipline
(*"a migration must not fix placement"*) applied to a HAL table rather than a placement table.

**3.3 ★★ The cost, accounted for in full (§5.2 requires it).** 30 produced artifacts change hash.

- **Every `.bin` and `.dmk` keeps its exact size** — `loader.bin` 1606→1606, `intro_splash.bin` 28145→28145, `probe.dmk` 224016→224016. Relocation, not growth.
- **Every `.map` keeps its exact size** after `GFX_MODE_MAX` was placed *inside* the section (see below).
- **`hal_build.o` is −5 bytes.** Accounted: the assembled section is **`$0450` long in both** with **635 emitting lines in both**, and the object carries **182 symbol names in both — none added, none removed**. Only symbol *values* differ, and lwasm encodes smaller addresses in fewer bytes. Nothing changed beyond the move.

★ An intermediate version of this change put `GFX_MODE_MAX` *outside* the section. It emitted no
byte differently, but lwasm then kept it out of the object's symbol table and **every `.map` lost
its `Symbol: GFX_MODE_MAX` line (−53 B each, −20 B in the object)**. Correct either way; I moved it
inside so the only delta is positional and AC-2's evidence has one story instead of two.

**3.4 ★★ A dependency the dispatch could not see (§5.4), and why the palettes did NOT move.**
`gfx_pal4` has a **checked consumer**: `src/engine/char_draw.s` carries a deliberate duplicate
(`sc_pal`), and **`harness/tools/palette_check.py` — run by `build.bat:283` — reads `gfx_pal4` out
of `gfx.s` by hardcoded path** and fails the build if the two drift. Its docstring anticipated
exactly this: *"gfx_pal4 moves and this fails the build instead of silently repainting the scene."*
The dispatch asked for the table and `GFX_MODE_MAX`, not the palettes, so the palettes stayed —
which keeps that check working and costs nothing: a project-local row may point at a shared palette
(same translation unit), or supply its own beside its table. `[palette] the flash's restore matches
gfx_pal4` still passes.

**3.5 The new coupling: DOCUMENTED, not guarded — and why.** `gfx.s`'s service now references a
symbol defined project-locally. A project defining `HAL_GFX_MODE_SERVICE` without a table fails
with **`Undefined symbol gfx_mode_table`**, which names the missing thing at assembly time. A guard
was considered and rejected: it would replace a loud, self-describing failure with either a **silent
compile-out** (the service present but inert — strictly worse) or **a second symbol every project
must keep in sync**, which is more coupling, not less. The requirement is stated at both the
reference site and the definition site, where the error sends the reader.

**3.6 Authority tiers.** Everything here rests on **fresh tool output** — builds, hashes, listings,
the assembler's own symbol table. No oracle mechanism is relied on, so §2H's three checks do not
apply to a conclusion in this report. **25.3 rests on Jay** and is not claimed (§4).

### 4 — Verification (AC-by-AC)

- **AC-1 ★★★ PASS.** karateka rebuilds **byte-identical: ALL 104 artifacts**, plus 30 files rewritten this run with **0 changed, 0 new** against the pre-change mark. Its `hal-sync` reports OK. The move is invisible where the service is undefined.
- **AC-2 ★★★ PASS.** POP's artifacts changed **exactly once**; the new hashes are in §5 and are the baseline. 30 of 125 produced files changed; **every `.bin`/`.dmk` and every `.map` identical in size**; the sole size delta is `hal_build.o` −5, fully accounted in §3.3.
- **AC-3 PASS (automated) / 25.3 pending Jay.** `[suites] ALL PASS` — `introseq`, `integ`, `tile`. Plus the build's own gates: disk readback `VERDICT: PASS`, `map_check` 6 maps clean, `reg-owner` OK, `palette` OK. ★ Per POP §4 I **cannot** self-certify the MAME visual gate and do not.
- **AC-4 PASS.** Mode 1's emitted row is **`1E A0 3C00 0000 10`** before and after — byte-for-byte identical; only its address moved (`$026C` → `$0007`). Bytes shown in §5.
- **AC-5 PASS.** `hal-sync` OK in **both** repos, after commit. `gfx.s` remains SHARED and matches — the two diffs were compared and are identical.
- **AC-6 ★★★ PASS — this is what the cost buys.** A throwaway `320×200×16` row was added to POP's `hal_globals.s` **alone**: `hal-sync` still **OK**, and the build completed **exit 0** with it present. No shared file was touched by that step. Row then removed; 0 demonstration rows remain.
- **AC-7 PASS.** `reg-discipline` **59**, matching the recorded figure. `reg-owner` OK — 25 owner rows over 14 registers, 10 files allowlisted. `palette` OK. `map_check` clean.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim):**

```
=== AC-1  karateka, after the move ===
  baseline artifacts: 104   current: 104
  ★ ALL 104 ARTIFACTS BYTE-IDENTICAL
[hal-sync] OK -- HAL source aligned with POP3_port (11 files compared, ...)
=== BUILD COMPLETE ===   (exit 0)
```

```
=== AC-2  POP, baseline -> after.  produced 125 both; 30 changed ===
build/anim_probe.bin        1451 B 97085ee69757c587 ->  1451 B 2cfa655c5e819a2c
build/cutscene_room.bin     2389 B b675c85b08b6f06b ->  2389 B 2cd43cd1ed3d0627
build/hal_link_proof.bin    1164 B a9df3e03fad9a503 ->  1164 B e78ed12ecbd628be
build/interp_probe.bin      4743 B 854a0c62db52f8ed ->  4743 B 37a1da63b4e3d908
build/intro_seq.bin         2695 B f9e8f749d01f1818 ->  2695 B d66889dfa54c33ae
build/intro_splash.bin     28145 B 5eb1dd81c177759e -> 28145 B 8295c4139a2ee0a3
build/loader.bin            1606 B 72e2793c7c44d321 ->  1606 B 56bf6740440c4e0a
build/loop_probe.bin        1269 B 6cca53f1b1fe0002 ->  1269 B 1885b4d01f9166b9
build/mode_probe.bin        1332 B 8d848ac047bc4435 ->  1332 B 11134e4e24eee4e3
build/probe.dmk           224016 B aec2567dee2ee9e1 -> 224016 B ec6daccb0b78a9d5
build/scene_prog.bin        2389 B a53c7062e805ccf0 ->  2389 B 08c2a21d369f2a83
build/song_probe.bin       11913 B b6f55f4b5f105b03 -> 11913 B 3885e3eb60c53911
build/tile_probe.bin        1500 B 3484cb7e9cd83def ->  1500 B 69c48c62b528c029
build/tone_probe.bin        1367 B f8023b1d9f0a3a52 ->  1367 B ab2ad9eb558d99e9
build/assets/intro_prog.raw 1575 B 5eda8a8f40d1670e ->  1575 B 1858f872eb07a4d5
build/assets/scene_prog.raw 1269 B f9cb6e0f9ccdfde7 ->  1269 B c5c98080de0cb7d4
build/obj/hal_build.o       3976 B a11bef75f8c11317 ->  3971 B 04409252fbd608f4
  + 13 build/obj/*.map, all SIZE-IDENTICAL, hash changed
  artifacts whose SIZE changed: 1  ->  build/obj/hal_build.o  3976 -> 3971 (-5)
```

```
=== AC-4  the emitted mode table: pristine (gfx.s) vs after (hal_globals.s) ===
PRISTINE                                   AFTER THE MOVE
0265 15   fcb $15   ; mode 0 VRES          0000 15   fcb $15   ; mode 0 VRES
0266 50   fcb 80                           0001 50   fcb 80
0267 1E00 fdb $1E00                        0002 1E00 fdb $1E00
0269 0000 fdb gfx_pal4                     0004 0000 fdb gfx_pal4
026B 04   fcb 4                            0006 04   fcb 4
026C 1E   fcb $1E   ; mode 1 VRES          0007 1E   fcb $1E   ; mode 1 VRES
026D A0   fcb 160                          0008 A0   fcb 160
026E 3C00 fdb $3C00                        0009 3C00 fdb $3C00
0270 0000 fdb gfx_pal16                    000B 0000 fdb gfx_pal16
0272 10   fcb 16                           000D 10   fcb 16
  section size $0450 in BOTH; 635 emitting lines in BOTH; 182 symbol names in BOTH
```

```
=== AC-3 / 25.1 suites ===
[suites] running: introseq integ tile
[suites] retired at P3.103 (see harness/smoke/retired.sh): probe cel compiled mode anim room walk
[suites] -ramsize 512K
[suites] === introseq ===   [run_introseq_test] PASS
[suites] === integ ===      [integ] PASS
[suites] === tile ===       [run_tile_test] PASS
[suites] ALL PASS
```

```
=== AC-6  a third mode added to hal_globals.s ALONE ===
AC-6: throwaway mode 2 added to POP's PROJECT_LOCAL hal_globals.s only
[hal-sync] OK -- HAL source aligned with karateka_coco3 (11 files compared, ...)
AC-6 build with a 3rd LOCAL mode, exit: 0
=== BUILD COMPLETE ===
(row then removed; demo rows remaining: 0)
```

```
=== AC-5 / AC-7  standing checks ===
[hal-sync]  OK, POP3_port      [hal-sync] OK, karateka_coco3     (both after commit)
[reg-discipline] OK -- measured 59, matching the independent figure.
[reg-owner] OK — 25 owner row(s) over 14 register(s), 10 file(s) allowlisted.
  [palette] the flash's restore matches gfx_pal4 ($00 $26 $19 $3F)
[map_check] 6 map(s) clean — no overlap, nothing below $0E00, introseq.map all below
            $2700, scene.map linked at $2700.
# VERDICT: PASS - every file on the image matches its artefact.
```

**25.2** bundled-artifact grep: **N/A** — no sibling-import artifact is bundled by this change; the
HAL is assembled from source in-tree, and the one shared file edited is verified by `hal-sync`
rather than by a bundled copy.

**25.3** operator-runtime-smoke: **pending Jay.** ★ Prod bytes moved, so a gate is warranted before
this is treated as delivered. Suggested: the standard `live-disk` runner, RGB. Per §4 I have not
observed it and do not certify it.

### 6 — Reactive deviations and route accounting

- **Deviation (scope):** the **palettes were not moved**, though they are table-adjacent. Reason in §3.4 — a hardcoded consumer would break. The dispatch asked for the table and `GFX_MODE_MAX`; that is what moved.
- **Deviation (placement):** `GFX_MODE_MAX` was first placed outside the emitted section, changing every `.map`. Corrected before commit; both states are reported in §3.3 rather than only the final one.
- **§5.4 triggered and handled inline** (the `palette_check.py` dependency) rather than escalated, because it did not block the requested change — it bounded it. Reported here.
- **§5.5 examined and NOT triggered** — see §3.1. POP's §2G is stale rather than in conflict, and POP's own `a7664bf` is the precedent. Had I read it as live, the dispatch would be withdrawn.
- **ROUTE ACCOUNTING.** I proposed no route. The dispatch's §3 named three things — move the table, move `GFX_MODE_MAX`, keep the mode-number equates in `hal.inc` as a shared registry. The first two are done. **The third I did NOT implement:** `hal.inc` is unchanged, because POP has no mode 2 and adding a `GFX_MODE_320x200x16 equ 2` to a SHARED file for a mode POP does not ship is `coco_agi`'s change to make when it lands its mode, not POP's to make speculatively. `GFX_MODE_320x192x4/16` already exist there and remain the shared registry.

### 7 — Uncertainty flags

- **25.3 is not observed.** Prod bytes moved; behaviour should be unchanged, and the suites agree, but a visual gate has not been run.
- **The suites ran at `-ramsize 512K`** (the runner's own setting, unchanged by me). POP's §2K makes **128 KB** the verification target; this change is address-neutral in character, but it has **not** been exercised at 128 KB.
- **`hal_globals.s` now emits bytes**, where it was pure equates. It opens an `OBJTARGET` section for them. karateka's copy never reaches that code, so its build is unaffected — but the file's character changed and its header comment (*"Values are byte-for-byte the same as karateka's globals.s"*) is now only true of the DP band above the new block.
- **The `-5` object delta is explained but not byte-decoded.** I established that no symbol was added or removed and that only values differ; I did not parse lwasm's object format field by field.
- **`build.bat` writes 125 files, but I did not verify each is a build product** rather than an incidental touch; the classification is by mtime.

### 8 — Follow-up candidates

1. ★★ **POP's CLAUDE.md §2G needs updating.** It states karateka is read-only with *no build-time dependency* and *never an automatic sync*; the tree has enforced the opposite since P2.4. A stale rule that is routinely and correctly violated teaches that the document is optional. **Orchestrator doc edit (§2D).**
2. ★ **`hal_globals.s`'s header comment** should stop claiming byte-identity with karateka's `globals.s` now that a POP-only block lives below it.
3. **Re-run the suites at 128 KB** (§2K) if any doubt attaches to the re-baseline.
4. **§7's figure question, answered:** POP produces **125 files**; the shipped set is **six DECB files + one image**. If any POP document still says "three prod artifacts", it understates the rule's scope and should be corrected.
5. `coco_agi` can now land its mode 2 in its own `hal_globals.s`, touching no shared file — the property AC-6 demonstrated.

### 9 — User interaction during task
None.

### 10 — Candidate(s) captured this task
None — the governing observation (*a shared table is a shared binary*) was captured from the
`coco_agi` side at P3.1 as `2026-08-26-a-shared-table-is-a-shared-binary.md`, and §2C says new rows
only, never a duplicate for the same principle.

### 11 — Commit
`69bec9c` — POP-HAL-01: the mode descriptor table becomes project-local
karateka `1b5ad76` — POP-HAL-01: … (shared half)
(both pushed to origin/wip before this report)
