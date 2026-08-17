## Form B Report — P3.103 + P3.103a — the trim moved one mirrored cel in six

**Class:** build (converter fix + re-bake) + recon + harness retirement. wip.
**Prod CHANGED — deliberately:** four cels re-baked, so `ROOM.BIN`/the cel pages differ. §5.

**★★★ ATTRIBUTED AND FIXED. `sprite_convert` trimmed all-blank byte columns from BOTH ends
of every cel. Trimming the TRAILING end is free; trimming the LEADING end moves the sprite,
because the engine places byte 0 at the left edge it computes from the UNTRIMMED Apple
width. The tool's own `--no-trim` help said so — *"trimming shifts the cel origin left by
`lead` bytes - the placement table must compensate"* — and nothing ever compensated.**

**★★★ MEASURED ACROSS THE SIX WALK CELS: normal leads `0,0,0,0,0,0`; mirrored
`0,1,0,0,0,0`. One cel in six, 4 px back and forward again, once per cycle, in the walk OUT
only.** That is Jay's *"his walk out still looks like he's skipping not walking. almost like
a frame is missing"*, and it is why the entry looks right and the exit does not.

**★★ AND P3.103a's TWO-PATH TEST CLEARS THE MIRRORING ITSELF, in CoCo pixels only:** ink
extents identical on all six, shift +0 everywhere. **Jay's 7→4 rounding lead closes for
position** — and the same test found a real **colour** defect it could not have been asked
about. **25.3 is pending Jay: the walk changed and I cannot gate it.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-16T19:49:41-04:00 (HEAD `989a2b8`, wip). Karateka untouched. `main` untouched.
Oracle source read-only and **not run — this dispatch never touched the oracle**, by design
(§P3.103a §1). Pre-existing and not mine: `dist/mame-cfg/rgb/coco3.cfg`.

**§2B ASSET PROTECTION, checked before re-converting anything:**
`docs/project/protection-catalog.md` **does not exist** — CLAUDE.md §2B says to start it
"when POP's first authored/altered asset appears", and none has. No cel carries an
ALTERED/PROTECTED marker (grepped). Every `*_src.s` header names its origin
(`ORIGIN: IMG.CHTAB6.A`, `POP cel: #75`), so none is "unlisted with no verifiable source
origin". **Re-conversion is in-contract.** Flagged rather than assumed.

---

### 1 — Summary

| | |
|---|---|
| **★★★ attributed** | the converter's **leading blank-column trim**; nothing added `lead` back |
| **★★★ the signature** | mirrored leads `0,1,0,0,0,0` vs normal `0,0,0,0,0,0` — **varies, so it jitters** |
| **★★★ fixed** | trailing-only trim, with an assert; **4 cels re-baked** (`v49_m`, `v54_m`, `v63`, `v66`) |
| **★★ P3.103a** | two-path test, CoCo pixels only: **ink identical on all six, shift +0** |
| **★★ closed** | Jay's mirrored-rounding lead, **for position** |
| **★ found, not fixed** | the mirrored cels' **chroma** differs (137–165 px on 3 of 6) — the colour model is DO-NOT-EDIT |
| **★★ consequence stated** | P3.100's exoneration **crossed the suspect format**; what it is evidence for changes |
| **★★ retired** | five P1/P2 suites, with replacement coverage named and **one real gap flagged** |
| **★★★ pending Jay** | **the walk changed — 25.3 is not self-certifiable** |

### 2 — Files modified

- `harness/tools/sprite_convert.py` — trailing-only trim + assert; `--no-trim` help corrected
- `harness/tools/cel_content_offset.py` — NEW; where the ink sits inside the footprint
- `harness/tools/cel_mirror_paths.py` — NEW; P3.103a's two-path test
- `content/cutscene/chars/v49_m_src.s`, `v49_m_p0.s`, `v54_m_src.s`, `v54_m_p1.s`,
  `v63_src.s`, `v63_p2.s`, `v66_src.s`, `v66_p2.s` — re-baked
- `content/cutscene/chars/cel_res.s`, `cel_pg3.s`, `cel_pages.s`, `cel_pack.json` — re-packed
- `harness/smoke/retired.sh` — NEW; one home for what "retired" means
- `harness/smoke/run_suites.sh` — NEW; one home for what "the suites" are
- `harness/smoke/run_probe_test.sh`, `run_cel_test.sh`, `run_compiled_test.sh`,
  `run_mode_test.sh`, `run_anim_test.sh` — retired
- `reports/20260816-194941-…md` — this

(explicit-path staging only)

### 3 — Reasoning

**3A — WHERE THE INK SITS INSIDE THE FOOTPRINT (P3.103 §1).**

P3.100 measured `ch_dest`: the **destination address**, i.e. the left edge of the
**footprint**. Jay's lead is about what is inside it. `sprite_convert.convert_one` trimmed
both edges and recorded `lead`/`trail` in a dict that is printed and dropped:

```
  cel  facing    awid  px wide  container  ink bytes  lead  trail  ink px
  49   normal    4     28       7          [0..5]     0     1      0..21
  49   MIRRORED  4     28       7          [1..6]     1     0      6..27
```

`cel_table` +4 carries the **Apple** width (4 bytes = 28 px) and `co_setup` computes
`cs_px = px − awid*7` from it, so the footprint's left edge is right. The cel data had one
byte removed from its left. **The two disagreed by exactly 4 px, and only for the mirrored
bake.**

```
  normal    lead 48:0 49:0 50:0 51:0 52:0 53:0   spread 0 px  — CONSTANT, invisible
  MIRRORED  lead 48:0 49:1 50:0 51:0 52:0 53:0   spread 4 px  — ★ VARIES ACROSS THE CYCLE
```

★★ **AND THE ALTERNATION IS THE WHOLE POINT (AC1).** A constant offset is a character a few
pixels off, walking smoothly. One frame in six displaced is a gait that slips. **The normal
cycle's spread is zero, which is why the walk in has never looked wrong.**

**Blast radius**, every cel both facings: **8 of 170 pairs** carried a non-zero lead; **4 are
actually baked** — `v49_m` (the walk cel — the skip), `v54_m` (a held pose, so a static 4 px
offset), and `v63`/`v66` **normal** (inside Vexit's turn, so the turn had a 4 px hitch too).

**3B — THE FIX, AT THE CONVERTER (AC2).**

`L = 0` always; trailing columns still trimmed; `assert lead == 0` so it cannot silently
return. ★ **Trailing is safe and leading is not, and the asymmetry is the fix**: dropping
columns off the right makes the container narrower without moving anything inside it.

**3C — ★★★ P3.103a: THE TWO-PATH TEST, AND WHY THE OLD METHOD WAS UNSOUND.**

Jay: *"even doing that he still has to do math to compare them, introducing the same
potential error."* **P3.100's `168, 173, 176, 181, 182, 191, 188, 193` compared a CoCo
framebuffer address against an Apple screen position — something mapped between them.** If
that mapping shares the converter's reasoning, it **agrees by construction**. That is
P3.99's trap moved from an operand into the **comparison**, where it is harder to see
because both operands were honestly measured on hardware.

So: two paths, one source, both ending in a CoCo pixel array, **compared as CoCo pixels,
with no Apple↔CoCo arithmetic anywhere.**

- **Path A** — mirror in Apple space (the oracle's own operation: reverse the byte order and
  mirror the seven pixel bits inside each byte, each byte keeping its palette bit
  [HIRES.S MLayGen + the `MIRROR` table]), then convert.
- **Path B** — convert, then reverse the CoCo pixel list. **What the bake ships.**

```
  cel  ink span A   ink span B   shift  SHAPE diffs  total diffs
  48   2..18        2..18        +0     0            0
  49   6..27        6..27        +0     0            164
  50   3..32        3..32        +0     0            0
  51   2..31        2..31        +0     0            0
  52   0..27        0..27        +0     2            165
  53   3..26        3..27        +0     1            137
```

**★★ POSITION: the ink span is identical on all six and the shift is +0 everywhere. Jay's
7→4 rounding lead CLOSES for position** (AC2/AC3 of the addendum), and it closes without
the ambiguity now attached to the `ch_dest` comparison.

**★ COLOUR: it does not close there.** Three of six differ in 137–165 pixels, and two carry
1–2 edge pixels of shape. The cause is in the colour model and is **directional**:

```
    # NTSC chroma: attributed to this ON pixel, painted at col-1
    row_indices[col - 1] = chroma_idx
```

a chroma smear painted one column **left** of its ON pixel. Path B reverses it afterwards,
so in every shipped mirrored cel the smear sits one column **right**. ★ **I did not touch
it:** that block is banner-marked *"COLOUR MODEL - CARRIED VERBATIM FROM KARATEKA. DO NOT
EDIT. Any change here is out of scope per the P1.2 dispatch (6) and Jay's ruling."*
CLAUDE.md §8 puts invariants above task instructions. **Surfaced, not changed** — §8.

**3D — THE STANDING CONSEQUENCE (addendum AC4).**

**P3.100's exoneration of the mirror anchor crossed the format under suspicion.** It does
**not** un-exonerate the anchor — the anchor is arithmetic on `CharX`, and P3.103a's
mirror test independently found no positional difference. **What changes is what P3.100 is
evidence FOR:** it establishes that the port puts the cel where our conversion says the
oracle put it. It cannot establish that the conversion is right. **Every cross-format
position comparison in this arc inherits that limit**, and the differential test is the
form that does not.

**3E — §2H's THREE CHECKS.**

1. **A second mechanism for a different object class?** Yes, and it is the reason the
   blast-radius scan ran over all 170 pairs rather than the six: the same trim silently
   displaced `v63`/`v66` in the **normal** facing, inside the turn. Had I checked only the
   mirrored walk cels I would have fixed the skip and left the turn wrong.
2. **The calling routine.** Not `convert_sprite_to_coco3` (whose mirror is exact) but
   `convert_one`, which trims **after** it. The mirror got four dispatches of suspicion for
   something its caller did.
3. **Grep the reports.** `probe_cel_parity.py:6` records *"both cels trim with lead=0"* —
   P3.22 checked this exact hazard for two cels, found zero, and moved on. **The check was
   right and its scope was two cels.**

### 4 — Verification (AC-by-AC)

- **P3.103 AC1 / 103a AC1–AC2 — content position, all six, alternation stated.** §3A, §3C.
  Both tools are offline and neither performs Apple↔CoCo coordinate arithmetic.
- **AC2/AC3 — attributed to the converter, fixed there, the six re-baked.** §3B. `bake_scene`
  re-ran; 4 cels changed. **Verified by symbol from a freshly baked image:** `v49_m_p0`'s
  header is now `fcb 47,7` (was `47,6`) while `cel_table` cel 49 still carries Apple width 4
  — which is the fix in one line: the container is the full `ceil(28/4)` and byte 0 is the
  sprite's left edge again.
- **AC3 (P3.103 §2) — old suites retired, listed, replacement coverage named.** §5.
- **AC4 — nothing tuned, nothing fixed on shape.** `cad_tab` untouched; the colour model
  untouched; no engine change at all. The one change is the converter's trim, attributed by
  measurement before it was made.
- **AC5 — suites green, 128 KB first; build verified by symbol from a freshly baked image.** §5.
- **AC6 — Jay gates LIVE if the walk changes.** **The walk changed. 25.3 is `pending Jay`
  and is not self-certified.** §5.
- **AC7 — route accounting; sync bridge; Karateka; `main`.** §6.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim).** `build.bat` after the re-bake: `=== BUILD COMPLETE ===`.

```
[suites] running: introseq room walk
[suites] retired at P3.103 (see harness/smoke/retired.sh): probe cel compiled mode anim
[suites] -ramsize 128K
[suites] === introseq ===   [run_introseq_test] PASS
[suites] === room ===       [run_room_test] PASS
[suites] === walk ===       [run_walk_test] PASS
[suites] ALL PASS
```
`[hal-sync] OK -- HAL source aligned with karateka_coco3 (11 files compared…)`

**★★ THE RETIREMENT, AND IT IS A RETIREMENT RATHER THAN A SKIP.** The suites came back
because there was no such thing as "the suite set" — there was a directory of
`run_*_test.sh` and every fresh session rebuilt the list by globbing it, **and a list
rebuilt from a glob cannot remember a decision.** So the list lives once in
`run_suites.sh`, and each retired runner refuses to run on its own via `retired.sh`
(override `POP_RUN_RETIRED=1`, a named override rather than a default):

| retired | covered | covered now |
|---|---|---|
| `probe` P1.1 | the loop probe / HAL harness boots | room+walk boot live-disk through the same HAL |
| `cel` P1.2 | converter output vs on-screen indices | room's flame check (78 B byte-identical) + walk's composite diff over 28 captures |
| `compiled` P1.3 | `sprite_compiler.py`'s emitted 6809 | **nothing, and nothing need:** the engine replaced compiled sprites with segment streams [`flame_cels.s:56`] |
| `mode` P2.5 | mode **cycling** 16→4→16→4 | ★ **PARTIAL — A REAL GAP.** Setup is covered by room/introseq/walk; **cycling is not covered anywhere.** The port sets the mode once, so the gap is over a capability it does not use — flagged per HARD-STOP 3 rather than glossed |
| `anim` P2.6 | the double-buffer page flip | walk's per-page signature guard + bank-mapped-at-capture assertion, and room's displayed-buffer diff |

★ **THE GENERATION STAYS, deliberately.** `build.bat` still assembles PROBE/MODE/ANIM into
`build/probe.dmk`. The live suites boot from that same disk and **the cel pages are placed
at explicit tracks after those files**, so removing them moves the tracks. What cost time
was *running* them — five MAME boots a round — and that is what stopped.

**25.2 bundled-artifact grep:** the cel pages re-packed;
`cel_res.s 5,891 B / cel_pg0 7,292 / cel_pg1 6,451 / cel_pg2 5,674 / cel_pg3 6,526`, all
placed, `18432 bytes free` on the disk.

**25.3 operator-runtime-smoke: ★★★ PENDING JAY — live-disk, RGB, 128 KB.**
**The walk-out changed: mirrored cel 49 moves 4 px right, once per cycle, and the turn's
cels 63/66 move 4 px right.** This is the thing under gate and **a suite cannot see it** —
`verify_room_chars` composites from the same source cel the machine drew, so it agrees
whichever position that cel is at. **I am not certifying this.** Standing gates unchanged:
flash, glass, sand, slump and the feet all PASSED.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** No route proposed in advance. Against both dispatches: **P3.103
AC1–AC5, AC7 and 103a AC1–AC7 are contained in full**; **AC6 (Jay's gate) is open by
construction** — it is his to give.

**Named as not-done rather than left absent:**
1. **The chroma defect §3C found is NOT fixed** — the colour model is banner-marked
   DO-NOT-EDIT with a Jay ruling behind it, and CLAUDE.md §8 ranks that above a task
   instruction. It is a follow-up (§8), not a silent omission.
2. `v54_m` and `v63`/`v66` were re-baked as part of the same converter fix. They were not
   named in either dispatch; leaving them displaced while fixing `v49_m` would have been
   fixing the symptom rather than the cause.
3. The block's +13% cost (P3.102) is untouched and still open.

**Reactive deviations (§22.5):** the addendum replaced §1's method mid-dispatch. My original
§1 test had already been built and run and **also stays in the report** — it is CoCo-space
only and it is what found the trim. The addendum's test is a different question (the
mirroring itself) and answers it independently. Both are reported; neither is presented as
the other.

Oracle read-only and not run. Karateka untouched. `main` untouched. `hal-sync` OK.

### 7 — Uncertainty flags

- **★★★ Whether this closes the skip is JAY'S to say.** The mechanism is attributed and the
  arithmetic is clean, but the last four dispatches each had a mechanism that measured well
  and did not close it. **I have not claimed it does.**
- **★★ The mirrored cels' chroma is wrong** (§3C) — 137–165 px on three of six, plus 1–2
  edge pixels of shape on two. Real, measured, unfixed.
- **★ P3.100's exoneration crossed the suspect format** (§3D). The anchor stays exonerated
  on P3.103a's independent evidence, not on P3.100's.
- **★ `mode`'s cycling coverage is genuinely lost** — flagged per HARD-STOP 3 rather than
  quietly dropped. The port does not cycle the mode.
- The four re-baked cels grow `v49_m` from 6 to 7 bytes wide, so the exit's peel/blit does
  marginally more work — which nudges the P3.102 block's margin the wrong way. Not measured.
- Carried: what costs the exit's +13%; the characters' per-iteration draw; 0.20 s driver
  overhead; the `$2310..$2329` blindness; the scene is one page from a single load.

### 8 — Follow-up candidates

1. **The chroma smear's direction under mirroring** (§3C) — needs a Jay ruling first,
   because the colour model is DO-NOT-EDIT. The measurement is already in
   `cel_mirror_paths.py` and would be the fix's own check.
2. **Re-run P3.101's timing measurement after the re-bake** — `v49_m` is a byte wider now,
   and P3.102 showed the exit sits 5.6% under a whole-frame boundary.
3. Start `docs/project/protection-catalog.md` — §2B wants it "when the first authored/altered
   asset appears"; four cels are now regenerated-with-intent and the catalog would record why.
4. The block's +13% (P3.102 §8.1): rebuild with a different `VIS_R` and see whether it moves.

### 9 — User interaction during task

**P3.103a arrived mid-dispatch**, after §1's original test had run and the converter fix was
in. It replaced §1's method; §1's hypothesis and §2 stood. Both tests are reported (§6).

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-16-a-test-that-crosses-the-suspect-format-cannot-clear-it.md`
- `seeds/POP/live/2026-08-16-an-offset-is-invisible-until-it-varies.md`

### 11 — Commit

See below — pushed to origin/wip before this report.
