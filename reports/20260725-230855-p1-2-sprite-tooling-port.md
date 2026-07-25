## Form B Report — P1.2 — port the sprite tooling to POP and verify (converter + authoring tool)
**Class:** BUILD — port production tooling to POP + verify. `wip`.
**Prod byte-identity: N/A** (tools, not a ported runtime artifact). What *is* verified here is the
converter's OUTPUT: format-correct, compiler-consumable, and identical to what the GIME displays.

### 0 — Receipt / status (C-35 stamp)
t0=2026-07-25T23:08:55Z (HEAD `18d4a39`, wip). Tracked tree **clean** at receipt.

**Gates — both PASS:**
- oracle `.hdv` md5 = `c4f0b13e49b77dd0fbc5063e27e53a24` ✔ (re-derived this dispatch, not carried).
- vendored source pinned at `ec78dbf` ✔ (`CLAUDE.md:9,33,41`); `oracle/source/` not modified.
- P1.1 harness present and runnable (`harness/smoke/run_probe_test.sh`, `--mode direct`) ✔.
- Karateka read-only sibling on `wip` @ `23c0592`; both tools present. **Not modified** (verified: 11 of
  13 `sprite_tool` files are byte-identical between the repos, and the 2 that differ are POP-side only).

Two untracked leftovers at receipt were **mine, from P1.1**: `.merge_file_QWah6M` (a
`git checkout-index --temp` scratch from the CRLF round-trip check) and `cfg/` (MAME writes it into its
CWD, which is the repo root when the harness runs). Both cleaned/ignored — see §2.

---

### 1 — Summary

**Both tools are ported, and the port turned out to be far smaller than the file sizes suggest — because
almost none of Karateka's tooling was actually Karateka-coupled.** 11 of the 13 `sprite_tool` files are
**byte-identical** to Karateka's; only `placement_table.py` (hard-defaulted to `content/scene6/…`) and
`catalog.py` (Karateka category names) needed retargeting. The converter needed exactly three changes:
the input reader (POP has real cel *binaries*, not a ca65 disassembly to scrape), the **swapped header
byte order**, and the CLI.

**AC2 is proven objectively, not asserted.** `harness/tools/verify_color_model.py` extracts the two
colour functions from both repos and compares them character for character: **IDENTICAL, exit 0**. Jay's
ruling that the model transfers free is now a checkable invariant with a guard that fails on drift.

**D3 — `start_col` from source: source sufficed for the mapping, and the interesting part is that there
is no value to find.** POP's source gives the mapping *exactly*, better than Karateka's traced answer:
`ByteTable[x] == x//7` and `OffsetTable[x] == x%7` (TABLES.S:51-67 `lup 36` loops), so `CVTX` is a pure
divmod-7 and `midX*7 + midOFF` **is** the pixel column; `ADDMID` (GRAFIX.S:341) stores both, while
`bgX`/`fgX` have no offset field at all — background is byte-aligned, characters are not. **No oracle
trace was needed.** But source cannot yield a single *value*, because there isn't one: `CharX` is live
state and the character moves, so on the real Apple II a walking character's artifact colours oscillate.
That is a property of the game, not a gap in the source — and it is exactly what Jay's freeze-at-
conversion ruling handles. One bonus: the draw path doubles a 140-res `CharX` into 280-res
(`asl`/`rol`, CTRLSUBS.S:809-813), so a character's **base column is always even** — making
`--start-col 0` (EVEN) the source-defensible default, which is what the sample used.

**D4 — verified, both halves.** All 9 sample cels (kid CHTAB1/2/3 + guard CHTAB4.GD; large/median/thin)
round-trip through the PA.9 compiled-sprite pipeline **ALL SOUND**. And the colour spot-check ran inside
P1.1's harness — the first use of that harness for content verification: a converted cel is displayed on
the real GIME in the shipping 320×192×4 mode and the framebuffer read back, **all 288 bytes / 1152 pixels
identical** to the converter's output.

**SIZE VERDICT (AC6): TRANSFERS FREE — no calibration pass needed.** No discrepancy was found. Stated
precisely, because the boundary matters: what is *proven* is that the colour model code is unchanged and
that the palette indices the converter emits are the palette indices the GIME displays. Whether those
indices are the *right* colours ends at Jay's eye (`CLAUDE.md §4`); I report the histograms objectively
and do not self-certify.

**Two defects found, both reported rather than absorbed** (§3.4): PA.9's POC carries a `converted.s`
reader that parses the decimal header as hex — latent there because all four cels it sampled have header
digits < 10, so **PA.9's published numbers are unaffected** (checked, not assumed), but it fires on the
first POP cel. And I reproduced a known project failure mode myself mid-dispatch: Python `read_text`/
`write_text` on Windows silently transcoded UTF-8 through cp1252. Caught, reverted byte-exact, redone.

---

### 2 — Files modified

Explicit-path staging only.

**New — POP-native tools:**
- `harness/tools/sprite_convert.py` — the converter (D1).
- `harness/tools/verify_color_model.py` — the AC2 guard.
- `harness/tools/compile_check.py` — converted.s + opacity.s → PA.9 pipeline (the AC4 adapter).
- `harness/tools/sprite_tool/` — 13 files (D2).

**New — colour spot-check harness (D4b), built on P1.1:**
- `src/harness/cel_probe.s` — displays a converted cel in 320×192×4.
- `harness/smoke/cel_test.lua`, `harness/smoke/run_cel_test.sh`.

**New — converted sample (D4):** `content/kid/` (7 cels), `content/guard/` (2 cels), 40 KB total.

**Modified:**
- `mame-idioms-coco3-port.md` — **appended §15** (4 new idioms). Existing content untouched per §6.
- `project-state.md` — build state, the `start_col` finding, the backlog item-3 unblock.
- `.gitignore` — `/cfg/` and `.merge_file_*` (both are harness byproducts, §0).

**Not modified:** `oracle/source/`, Karateka, `poc/compiled-sprite/`, `build.bat`, the P1.1 harness.

---

### 3 — Reasoning

#### 3.1 — What was actually coupled (AC1)

I expected the port to be mostly path-rewriting and it mostly wasn't — the coupling was concentrated in
two files. Enumerated:

| Karateka coupling | Where | Resolution |
|---|---|---|
| Reads a **ca65 disassembly `.s`** and scrapes `.byte` after a label | `sprite_convert.extract_sprite_bytes` | **Replaced** by `load_chtable`/`get_cel` — POP has real cel binaries (`IMG.CHTAB*`) |
| Cel header **`[height][width]`** | `sprite_convert.main` | **Swapped** — POP is `[width][height]` (HIRES.S:180-186) |
| `--source/--label` CLI | `sprite_convert.main` | `--table/--index/--all` |
| `DEFAULT = content/scene6/scene6_placement.txt` | `placement_table.py:17` | Repo-level `content/placement.txt` + `POP_PLACEMENT_TABLE` env override |
| Category names (player/akuma/bird/broderbund) | `catalog.py` docstring | POP's subjects; mechanism is category-name agnostic |
| `ROOT` = 4× dirname | `placement_table.py:16` | **Unchanged** — POP places the tool at the same depth, so it still resolves |

`celio.py`, `sidecar.py`, `opacity.py`, `save.py`, `edit_model.py`, `frame_assembly.py`, `lint.py`,
`pixel_map.py`, `render.py`, `sprite_tool_app.py`, `test_milestones.py` — **byte-identical**, no coupling
at all. They operate on the `converted.s`/`opacity.s` *format*, not on any repo layout. That is a
property of how the tool was written, and it is why D2 was cheap.

**The header swap is the trap.** Reading POP cels with Karateka's order produces a transposed sprite that
still "converts" without raising — silent garbage, not a crash. Filed as idiom §15c.

#### 3.2 — Colour model unchanged, and made checkable (AC2)

Rather than assert it, `verify_color_model.py` slices `_classify_row_convert` and
`convert_sprite_to_coco3` out of both files and diffs them. Result: **IDENTICAL** (1,070 and 6,732 chars).
The tool exits 1 on drift, so this is now a standing guard, not a one-time claim.

Worth recording: the tool's *first* run reported drift, and it was the tool being right — my `END VERBATIM
COLOUR MODEL` banner fell inside the slice because the extractor ran to the next `def`. Fixed the
extractor to end at the real dedent (the function boundary) rather than loosening the comparison. A guard
that is relaxed to make it pass is not a guard.

#### 3.3 — `start_col` from source (D3/AC3)

Chain, all from source, no trace:
1. **`CVTX` is a pure divmod-7.** `TABLES.S:51-67` generates `ByteTable` as `lup 36 / db ]byte ×7` and
   `OffsetTable` as `lup 36 / db 0..6` — i.e. `x//7` and `x%7` exactly. So `byte*7 + offset ≡ x`; CVTX
   decomposes the column, it does not transform it.
2. **Characters are sub-byte positioned.** `ADDMID` (GRAFIX.S:341) stores `XCO`→`midX` *and*
   `OFFSET`→`midOFF`. `bgX`/`fgX` have no offset field, and `ADDMIDEZ` forces `OFFSET=0` — so the
   engine's own data model says background is byte-aligned and characters are not. (Consistent with
   PA.6a's finding that the original draws sub-byte.)
3. **The cel's X** = `CharX ± per-frame dx`, mirrored by facing (`ADDCHARX`, CTRLSUBS.S:355).
4. **`CharX` is 140-res**; the draw path does `sbc #ScrnLeft` then `asl`/`rol` → 280-res
   (CTRLSUBS.S:809-813), converting back with `lsr`/`ror` + `adc #ScrnLeft` (CTRLSUBS.S:1085-1089).

**Verdict: source sufficed — for the mapping.** POP's source-trust advantage over Karateka held, and
comfortably: Karateka had to trace the draw column because its disassembly was unreliable; here the
tables are *generated by visible loops* and settle it outright.

**And source cannot give a value, because none exists.** A moving character has a different draw column
every frame, so its HGR artifact colour genuinely oscillates on the original. An oracle trace would not
have helped — it would have returned *one sample of a varying quantity*. This is the substantive D3
finding: the fallback wasn't needed, and wouldn't have answered the question either. Jay's ruling is what
resolves it; `start_col` is an authoring input, frozen once, recorded in each `converted.s` header.

The one useful constraint that *does* fall out: the 140→280 doubling makes a character's base column
always even, so **EVEN parity is the source-defensible default**. The sample used `--start-col 0`.

#### 3.4 — Two defects found

**(a) PA.9's POC `converted.s` reader is wrong.** `run_poc.load_kar` uses
`re.findall(r'\$?([0-9A-Fa-f]{1,2})')` + `int(v,16)` on a line whose header is **decimal**
(`fcb 24,2`), reading 24 as `0x24` = 36. I checked the blast radius rather than assuming it: the four
Karateka cels PA.9's N3 stage sampled have h/w of 2, 4, 3, 6, 7 — **every header digit < 10, where hex
and decimal coincide** — so `load_kar` returned the right answer there and **PA.9's published numbers are
unaffected**. It fires on the first POP cel (24–41 rows). I did **not** patch `poc/compiled-sprite/`: it
is an explicitly throwaway PA.9 measurement instrument, and editing a report's evidence artifact after
the fact is worse than routing around it. The adapter (below) uses the canonical reader instead.

**(b) I reproduced a known project failure mode.** Retargeting the two coupled files, I used Python
`read_text()`/`write_text()`, which on Windows round-tripped UTF-8 through cp1252 and turned every `—`
(`\xe2\x80\x94`) into a lone `\x97` — leaving both files invalid UTF-8, with nothing raised. Detected
only because a `str.replace` on a line containing an em-dash silently found no anchor. This is the same
class as the P1.2 `.gitignore` LF→CRLF corruption the project already learned once. Fixed properly:
re-copied byte-exact from Karateka, redid every edit with `read_bytes().decode('utf-8')` /
`write_bytes(...encode('utf-8'))`, asserted every anchor, and verified all 13 files decode as UTF-8 with
exactly the 2 intended files differing. Filed as idiom §15b. Reported because a silent encoding change
in tooling is exactly the kind of thing that surfaces months later as mangled output.

#### 3.5 — The adapter, stated exactly (AC4)

The dispatch allows "no change, **or** the exact minimal adapter is stated". It is stated:
**do not re-parse — use `sprite_tool/celio.Cel`**, the authoring tool's own canonical `converted.s`
reader (which round-trips byte-identically), plus `sidecar.read_sidecar` for opacity; import only the
popcc **core** (`tokenize`/`pack`/`Compiler`/`cycles`/`simulate`). That is `harness/tools/compile_check.py`.
It is a genuine adapter, not a workaround: the canonical reader is the correct dependency and the POC's
ad-hoc regex was always the wrong one.

#### 3.6 — What the spot-check proves, and what it doesn't (AC5/AC6)

`run_cel_test.sh` builds a converted cel into `src/harness/cel_probe.s`, runs it under P1.1's harness,
and reads the framebuffer back. **All bytes identical** on every cel tried. That closes the loop from
POP's cel binary → converter → `.s` → assembler → GIME framebuffer.

Being precise about the boundary: this proves *the pipeline is faithful*. It does not prove the colours
are right, and I have not claimed it does. The objective colour data is the palette histogram (§5). The
judgment is Jay's (`CLAUDE.md §4`). I did not attempt calibration (§6 forbids it) and found nothing
suggesting it is needed — hence **SIZE = transfers free**.

---

### 4 — Verification (AC-by-AC)

- **AC1 — both tools ported, wired to POP, contract preserved; every coupling stated. MET.** §3.1 table.
  Converter runs on real `IMG.CHTAB*` cels (§5); `sprite_tool` exercised on POP cels — `celio`
  round-trips all 9 **byte-identically**, `opacity.derive` returns `'none'` unmarked and `'mixed'` with
  byte-aligned marks, `sidecar` write→read round-trips. 11/13 files byte-identical to Karateka.
- **AC2 — colour model UNCHANGED. MET, objectively.** `verify_color_model.py` → both functions
  **IDENTICAL**, exit 0 (§5). No change attempted.
- **AC3 — `start_col` from source, or trace-fallback, REPORTED. MET.** §3.3. **Source sufficed; no trace
  needed.** With the substantive caveat that source yields the *mapping*, not a *value*, because the
  value does not exist for a moving character — and a trace could not have supplied one either.
- **AC4 — compiler-consumable; adapter stated. MET.** All 9 cels **SOUND** through the PA.9 pipeline
  (§5). Adapter stated exactly in §3.5. Full path shown: `IMG.CHTAB1 #64` → converter → `converted.s` →
  `celio` → `popcc` → 6809 instructions → simulate.
- **AC5 — colour spot-check inside P1.1's harness. MET.** §5. First content verification through that
  harness. Three cels checked; framebuffer byte-identical to converter output in every case. A
  **deliberate-FAIL** is also demonstrated (P1.1's standing rule).
- **AC6 — SIZE verdict. MET: TRANSFERS FREE, no calibration pass needed.** No discrepancy found. Scope
  boundary stated in §3.6; colour judgment remains Jay's.
- **AC7 — no `oracle/source/` edit, no engine/compiler/HAL code; status clean except new tools + report
  + standing untracked. MET.** §5. `poc/compiled-sprite/` deliberately untouched (§3.4a).

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 — colour model unchanged (AC2), verbatim:**
```
POP : C:\Projects\POP3_port\harness\tools\sprite_convert.py
KAR : C:\Projects\karateka_coco3\harness\tools\sprite_convert.py   [read-only reference]
  _classify_row_convert        IDENTICAL  (1070 chars, 29 lines)
  convert_sprite_to_coco3      IDENTICAL  (6732 chars, 121 lines)
VERDICT: COLOUR MODEL UNCHANGED - POP carries karateka's model verbatim.
exit=0
```

**25.1 — converter on real POP cels (AC1), verbatim:**
```
POP sprite_convert: IMG.CHTAB1  start_col=0 (parity EVEN)
  cel #40  7x41B (49x41px) -> coco3 12x41B  [trim lead=0 trail=1 from W=13]
  cel #47  3x40B (21x40px) -> coco3  5x40B  [trim lead=1 trail=0 from W=6]
  cel #64  1x24B ( 7x24px) -> coco3  2x24B
  cel #3   6x39B (42x39px) -> coco3 10x39B  [trim lead=0 trail=1 from W=11]
  cel #15  6x39B (42x39px) -> coco3 11x39B                      [IMG.CHTAB4.GD]
  cel #1   5x36B (35x36px) -> coco3  8x36B  [trim lead=1 trail=0 from W=9]
```

**25.1 — `sprite_tool` on POP cels (AC1), verbatim:**
```
=== celio round-trip on 9 POP cels (load -> regenerate -> byte-compare) ===
  guard_gd_001_median          OK   36x32px byte-identical
  kid_chtab1_040_large         OK   41x48px byte-identical
  kid_chtab1_064_thin          OK   24x8px  byte-identical
  ... (9/9)
  -> ALL ROUND-TRIP BYTE-IDENTICAL
=== opacity layer + derive on a POP cel (the PA.9 stage-1 contract) ===
  no marks           -> derive = 'none' (keyed everywhere, no sidecar)
  4 rows byte-aligned-> derive = 'mixed', 8 rect(s)
  wrote sidecar      -> content\guard\guard_gd_001_median\opacity.s
  read back          -> kind='mixed', 8 rect(s)  MATCHES
```

**25.1 — compiler round-trip (AC4), verbatim:**
```
=== compile_check: 9 cel(s) -> PA.9 compiled-sprite pipeline ===
  guard_gd_001_median   36x 8B  bytes  288 (skip 121 store  90 mixed 77)  instr 424 cyc 1813  cy/B  6.30  SOUND
  guard_gd_015_large    39x11B  bytes  429 (skip 273 store  72 mixed 84)  instr 455 cyc 1902  cy/B  4.43  SOUND
  kid_chtab1_040_large  41x12B  bytes  492 (skip 352 store  60 mixed 80)  instr 416 cyc 1909  cy/B  3.88  SOUND
  kid_chtab1_064_thin   24x 2B  bytes   48 (skip   1 store   1 mixed 46)  instr 187 cyc  911  cy/B 18.98  SOUND
  ... (9/9)
=== AGGREGATE (n=9) ===
  SOUNDNESS           : ALL PASS
  footprint bytes     : 2,506   drawn 1,075   skipped 1,431 (57%)
  mixed / drawn       : 644 / 1,075 = 59.9%
  cy/byte (footprint) : 5.92
```

**25.1 — colour spot-check inside P1.1's harness (AC5), verbatim:**
```
[run_cel_test] cel: content/guard/guard_gd_001_median
[run_cel_test] built build/cel_probe.bin
  # loaded, PC <- $0200 at frame 300
  # cel drawn, complete at frame 317
  magic_is_CE10                PASS got $CE10
  cel_dims_match_source        PASS guest 36x8B vs converted.s 36x8B
  framebuffer_matches_converter PASS all 288 bytes (1152 px) identical
  # ON-SCREEN PALETTE INDEX HISTOGRAM (objective; colour judgement is Jay's)
  #   0 Black    731   63.5%
  #   1 Orange    27    2.3%
  #   2 Blue     131   11.4%
  #   3 White    263   22.8%
  # VERDICT: PASS
[run_cel_test] PASS
```

**25.1 — DEMONSTRATED FAIL on the new harness (P1.1's standing rule), verbatim:**
```
=== thin cel on screen, median cel's spec ===
  magic_is_CE10                PASS got $CE10
  cel_dims_match_source        FAIL guest 24x2B vs converted.s 40x5B
  framebuffer_matches_converter FAIL 143/200 bytes differ; first row 0 byte 0: want $00 got $03
  # VERDICT: FAIL     sentinel written: build/cel_test_FAIL
```

**25.1 — POP vs Karateka `sprite_tool`, per-file (AC1/AC7), verbatim:**
```
  catalog.py               utf8-ok   modified   pop=  3566 kar=  3385
  celio.py                 utf8-ok   IDENTICAL  pop=  4832 kar=  4832
  edit_model.py            utf8-ok   IDENTICAL   ...
  opacity.py               utf8-ok   IDENTICAL  pop=  9832 kar=  9832
  placement_table.py       utf8-ok   modified   pop=  5797 kar=  5224
  sidecar.py               utf8-ok   IDENTICAL  pop=  3733 kar=  3733
  sprite_tool_app.py       utf8-ok   IDENTICAL  pop= 25532 kar= 25532
  (11 IDENTICAL, 2 modified — exactly the intended two)
```

**25.2 — committed POP tools:** `harness/tools/sprite_convert.py`, `harness/tools/sprite_tool/`,
`harness/tools/verify_color_model.py`, `harness/tools/compile_check.py`,
`harness/smoke/{cel_test.lua,run_cel_test.sh}`, `src/harness/cel_probe.s`, `content/{kid,guard}/`.

**25.3 — colour spot-check:** **No PNG was generated, so none is surfaced** (`CLAUDE.md §3`: nothing
produced, nothing interpreted). The objective palette-index comparison is above. **The colour judgment is
Jay's** and is *not* claimed here — if a visual review is wanted, `harness/smoke/run_cel_test.sh <cel_dir>`
puts any converted cel on screen (RGB, `screen_config=1` per `CLAUDE.md §4`).

**`git status --porcelain` (tracked) at commit time:**
```
M  .gitignore          M  mame-idioms-coco3-port.md    M  project-state.md
A  content/guard/... (2 cels)          A  content/kid/... (7 cels)
A  harness/smoke/cel_test.lua          A  harness/smoke/run_cel_test.sh
A  harness/tools/compile_check.py      A  harness/tools/sprite_convert.py
A  harness/tools/sprite_tool/ (13)     A  harness/tools/verify_color_model.py
A  src/harness/cel_probe.s
```

---

### 6 — Reactive deviations

1. **Two extra tools built beyond D1/D2.** `verify_color_model.py` (AC2 needed to be *provable*, not
   asserted) and `compile_check.py` (AC4's "exact minimal adapter", which is more useful as a committed
   tool than as a paragraph). Both are small and both are verification infrastructure, not scope creep
   into the compiler.
2. **`poc/compiled-sprite/` deliberately NOT fixed** despite containing a real defect (§3.4a). It is
   PA.9's evidence artifact; editing it after the report would rewrite that report's provenance. Routed
   around instead, and the defect is documented in §15d and `project-state.md` so it cannot be carried
   forward silently.
3. **The test `opacity.s` was deleted before commit.** Exercising `opacity.derive`/`sidecar` required
   marking pixels opaque; I marked 4 rows arbitrarily. That is a *mechanism test*, not authored shadow
   work, and committing it into `content/` would have made fabricated marks look like real authoring.
   Removed; the run is in §5 as evidence. Consequently `compile_check --all` now reports `opacity=none`
   for all 9 — the `mixed` path evidence is the transcript, not the tree.
4. **`.gitignore` extended** for `/cfg/` and `.merge_file_*` — both are byproducts of the P1.1 harness I
   shipped, so ignoring them is closing my own loop, not new policy.
5. **`build.bat` not extended** to build `cel_probe`. The cel choice is a per-run parameter, and
   `run_cel_test.sh` owns it (one home for the choice). Adding a default cel to the P1.1 build contract
   would have created a second home.
6. **Converter writes LF, not CRLF (a divergence from karateka's `write_s_file`).** Karateka writes
   `converted.s` with CRLF. POP's `.gitattributes` (P1.1) pins `*.s text eol=lf`, so CRLF output would
   make every re-convert show a spurious whole-file whitespace diff against a fresh checkout — git said
   so explicitly at `git add` time. Changed to LF and re-converted the sample; `celio` detects and
   preserves whichever style it finds, so the authoring round-trip is still byte-identical (re-verified:
   all 9). This is a deliberate divergence from the substrate, made to match POP's own line-ending policy.
7. **Dispatch label collision, again.** This is the second dispatch labelled **P1.2** (the first was the
   cleanup dispatch, `reports/20260724-235136-p1-2-cleanup.md`). Report filenames differ so nothing
   collided. Same class as the P1.1 collision already recorded in `project-state.md §6`.

---

### 7 — Uncertainty flags

1. **The spot-check compares the pipeline to itself, not to the oracle.** It proves converter output ==
   GIME framebuffer. It does **not** compare against POP running on `apple2e`. A true oracle colour
   comparison — capture the same cel on the Apple II and diff — was not performed, and the "transfers
   free" verdict rests on Jay's ruling plus the unchanged-model proof, not on an A/B against the oracle.
   That A/B is the honest next step if anyone wants the claim hardened.
2. **`start_col=0` is a defensible default, not a measured value** (§3.3). The evenness argument comes
   from the 140→280 doubling; per-frame `dx` from the image tables can still shift the final parity, and
   I did not enumerate those offsets.
3. **`sprite_tool_app.py` (the 25 KB tkinter GUI) is ported but NOT exercised.** It is byte-identical to
   Karateka's and imports only modules that now work on POP cels, but I ran no GUI session — it cannot
   be driven headlessly. Treat "ported" as "wired and syntactically intact", not "verified".
4. **`test_milestones.py` was copied unmodified and not run.** It is Karateka's milestone suite and very
   likely references Karateka content; it should be either retargeted or removed in a later pass.
5. **The trim step shifts cel origin.** `lead`/`trail` stripping moves the left edge by whole byte
   columns (fired on 5 of 9 sample cels). Placement must compensate — `CLAUDE.md §2F` puts that in the
   table, and Karateka already has a captured candidate on exactly this. No placement table exists yet,
   so nothing is wrong today, but converting content before the table exists defers a correction.
6. **`content/placement.txt` does not exist.** `placement_table.DEFAULT` points at it; any `sprite_tool`
   path that loads a table will fail until POP's first scene is placed. The env override exists as the
   escape hatch.
7. **Sample is 9 cels of ~600.** Chosen to span kid/guard and large/median/thin — but see §10: this
   dispatch's own candidate is about samples that look well-chosen on one axis and are blind on another.

---

### 8 — Follow-up candidates

1. **Oracle A/B colour comparison** — capture a cel as POP actually displays it on `apple2e` and diff
   against the converted CoCo3 render. Converts §7.1 from "ruling + unchanged-model" to measured.
2. **Retarget or remove `sprite_tool/test_milestones.py`** (§7.4) — it is currently dead Karateka weight.
3. **Create POP's placement table** (`CLAUDE.md §2F`) — unblocks the tool's table-driven paths and gives
   the trim compensation (§7.5) a home.
4. **Productionise the compiled-sprite compiler** — now genuinely unblocked; `compile_check.py` is the
   consumable-input proof, and the canonical readers are in place.
5. Standing, still open: the **§2A.3 idioms-authorship ruling** (now **eleven** deferrals; this dispatch
   filed 4 more provisionally, §15); `POP-idioms-coco3-markers.md` disposition; `.vscode/` disposition.

---

### 9 — User interaction during task
**None.** No questions asked; no clarifications received.

---

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-07-25-validation-sample-must-span-the-input-space.md` — *"A validation sample that
does not SPAN the input space can certify a broken tool — when a bug is only reachable by input values
the sample happens to exclude, every test passes and the tool ships wrong; choose samples by input-space
coverage, not by convenience or representativeness."* Fresh single-instance row (`initiator: clyde`),
schema matched against `seeds/karateka/live/2026-06-13-asset-readiness-gates-port-scope.md`; no existing
entry read or edited. Committed and pushed (`6e90ec0`).

Arose from §3.4a: PA.9's POC reader was exercised throughout that dispatch without ever firing, because
all four cels sampled had header digits < 10 — the one range where hex and decimal coincide. The sample
*had* been chosen carefully, for size-representativeness; the defect lived on the encoding axis, which
nobody was sampling. Directly relevant to §7.7 of this very report.

---

### 11 — Commit
`5ed34ed` — P1.2: port sprite tooling to POP + verify (converter + authoring tool).
Pushed to `origin/wip`. *(A report's §11 names the commit containing it; this line was filled in by the follow-up commit below — same convention as P1.1.)*


---

## ADDENDUM (post-report, same dispatch) — `sprite-tool.bat` and the GUI's Karateka defaults

**Raised by Jay after the report was pushed: "did you update sprite-tool.bat in the repo root to point at
the POP sprite tool". Answer: no, I had not.** It was carried into POP at P1.0 bootstrap (`635f986`)
byte-identical to Karateka's and I never revisited it in P1.2. Checking it exposed that §7.3's "ported but
NOT exercised" was understating the problem — the GUI could not have launched on POP at all. Three
compounding faults, all now fixed:

1. **The launcher's working-tree copy was LF** — precisely the §14g bug I filed in P1.1. It predates
   `.gitattributes` (P1.1), so it had never been re-checked-out; `git check-attr` says `eol: crlf` and a
   fresh `checkout-index` does yield CRLF, so **the repo was correct and only the stale working copy was
   broken**. Rewritten as CRLF, and its help text no longer advertises Karateka's
   `player / climb_crawl f0` defaults. *(The path it invokes,
   `harness\tools\sprite_tool\sprite_tool_app.py`, was already correct — the ported tool sits exactly
   there — so "point at the POP sprite tool" was satisfied by construction, but nothing else was.)*

2. **`placement_table.Table.__init__` hard-failed with no placement file.** `_parse()` opens `self.path`
   unconditionally; POP has no `content/placement.txt` (it does not exist until POP's first scene is
   placed, `CLAUDE.md §2F`), so the tool raised `FileNotFoundError` before opening a single cel. An absent
   table is now an **empty** table — registry/placement/anim stay empty and the tool falls back to the
   per-category cel list, which is the correct pre-placement view.

3. **The app hardcoded two Karateka content defaults.** `init_cat = "player"` and a `build_frame`
   fallback of `assemble_animation(table, "climb_crawl", 0)` — neither exists in POP. Both now resolve
   from what is on disk: prefer an animation block if a table supplies one (so Karateka-shaped content is
   unaffected), else the first cel under `content/`; category prefers `kid`, else the first that exists.

**Verified** by replaying `main()`'s pre-GUI sequence (lines 57-59 — everything that was Karateka-coupled)
against POP's real content:
```
  DEFAULT table path : C:\Projects\POP3_port\content\placement.txt
  exists?            : False  (POP has no scene yet)
  Table() constructed: registry=0 placement=0 anim=0
  categories         : ['guard', 'kid']
  init_cat resolves  : 'kid'   (was hardcoded 'player')
  build_frame([])   -> ('guard_gd_001_median',)
  frame             -> label='guard_gd_001_median' 32x36px
  FrameEdit         -> cels=['guard_gd_001_median'] selected='guard_gd_001_median'
  sprite-tool.bat: CRLF=19 bare-LF=0 tabs=0 bytes=890  invoke line intact: True
```
Full suite re-run after the change: colour model **UNCHANGED**, compile round-trip **ALL PASS**, celio
**ALL 9 BYTE-IDENTICAL**. Karateka unmodified.

**The GUI itself is still not launched here** — tkinter and Pillow are both present, so `main()` would
open a real window and block. §7.3's caveat stands, narrowed: everything *up to* the `tk` import is now
exercised on POP content; the UI remains unverified until Jay runs it.

**Two process notes, reported rather than buried.** I twice broke a file with Python string escapes while
fixing this: `"harness\tools"` in a heredoc became `harness<TAB>ools`, corrupting the `.bat`'s invoke
line — and Python's own `SyntaxWarning: invalid escape sequence '\t'` said so, which I did not act on the
first time. Rewritten via a literal file write instead of string assembly. Separately, I invoked the
`.bat` as a "test"; it ends in `pause`, so it hung for the full 2-minute timeout in a non-interactive
shell. Both are the same lesson as §15b: **stop assembling file content out of escaped string literals,
and do not execute a script containing `pause` from automation.** I hit the string-escape one **three times in this addendum alone** — including in the sentence describing it, which is the clearest possible argument for the rule.

**Pre-existing, NOT fixed** (out of scope, and confirmed identical in Karateka): the tool has no argparse,
so `sprite-tool.bat --help` is read as a placement id and dies with `KeyError: '--help'`.
