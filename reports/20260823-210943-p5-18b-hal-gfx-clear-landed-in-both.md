## Form B Report — P5.18b — `HAL_gfx_clear` asks the mode for its geometry, landed in both repos

**Class:** build. `wip` in **both** repos. **`main` untouched.** Prod bytes **moved**; behaviour did not.

★ **Supersedes P5.18's stop.** That report established the fix could not land in POP alone and
stopped for a ruling. Jay: *"perform the fix. land it in both."*

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-23T21:09:43Z. POP `bd12cc9` → **`a7664bf`**. Karateka `ac2b768` → **`072ddcf`**, pushed
to `origin/wip`.

**AC7 — `main` = `32b5fe23a49bf43e86c64f867ff59fb40c1ce0db`** at both ends. POP
`git status --porcelain src/` → 0. Karateka `src/` → 0.

---

### 1 — Summary

**The defect was TWO facts, not one, and the dispatch's fix addresses one of them.**
`HAL_gfx_clear` took its **base** from `page_register` (`$8000` or `$C000`) *and* its **length**
from a fixed `GFX_FB_WORDS`. Both describe the 4-colour layout. In 16-colour there is one
30,720 B buffer across all four blocks and **`$C000` is the bottom half of the only page** — which
is why Jay saw the bottom half go. ★ **§1's one-line `ldy` swap would have cleared the right
number of bytes at the wrong address.** Both are fixed.

**It landed as one change in two repos**, because `hal_sync_check.py` compares
`src/hal/coco3-dsk/gfx.s` across them and fails **both** builds on substantive drift — P5.18 §3C
proved that by experiment, twice.

★★ **Karateka's emitted bytes did not change, and that is MEASURED, not argued:** `karateka.bin`
rebuilds to **`36ce471c5605`**, byte-identical to the pre-fix artifact of 08-11. P5.18 §7.2 flagged
that claim as reasoning-not-measurement; it is now measurement.

---

### 2 — Files modified

- `src/hal/coco3-dsk/gfx.s` — **+37 lines, 0 deletions**, one routine. **POP** (`a7664bf`).
- `src/hal/coco3-dsk/gfx.s` — **the identical block**, +37/0. **Karateka** (`072ddcf`).

Explicit-path staging in both. No other file touched in either repo.

---

### 3 — Reasoning

#### 3A — AC1: the fix

```
HAL_gfx_clear:
                ifdef   HAL_GFX_MODE_SERVICE
        ldy     HAL_gfx_cur_words       ; the MODE's size, not a constant
        beq     gfx_clear_done          ; zero-size mode: 0 would wrap to 65,536 stores
        cmpy    #GFX_MIRROR_MAX
        bls     gfx_clear_two_buf       ; fits half a window => 4-colour, two side by side
        ldx     HAL_gfx_draw_base       ; 16-colour: ONE buffer, at the window
        bra     gfx_clear_common
gfx_clear_two_buf:
                endc
        lda     <page_register          ; ... unchanged 4-colour path ...
gfx_clear_common:
        ldd     #$0000
                ifndef  HAL_GFX_MODE_SERVICE
        ldy     #GFX_FB_WORDS
                endc
gfx_clear_loop:
        ...
gfx_clear_done:
        andcc   #$FE
        rts
```

★ **The discriminator is `HAL_gfx_mirror`'s**, deliberately — that routine already decides this
same question the same way (*"16-colour: no room for two at once"*), and two different tests for
one fact is how they drift apart.

★ **The 4-colour path keeps its fall-through.** `gfx_clear_b_buf` still falls into
`gfx_clear_common` rather than branching, which is what makes §3C's byte-identity possible.

#### 3B — AC2: the guard, and why the fallback is mandatory

`HAL_gfx_cur_words` and `HAL_gfx_draw_base` are declared **inside** `ifdef HAL_GFX_MODE_SERVICE`
(`:833`, `endc :842`); `HAL_gfx_clear` sits **after** it. **POP defines the guard
(`build.bat:194`); Karateka never defines it at all.** So an unguarded reference does not resolve
there — the fallback is **not "the obvious shape, do not assume it is wanted"**, it is the only
form that assembles in both.

★ **And it is correct, not a degradation:** with no mode service there is one mode and `$1E00`
*is* its size.

#### 3C — ★★ AC4: Karateka verified by measurement

| | |
|---|---|
| same file? | **substantively yes** — 1,658 vs 1,689 lines, the gap all comment, and gate-enforced |
| identical body? | yes, `HAL_gfx_clear` included |
| same defect? | **yes, latent** — identical `gfx_mode_table` with the `320x192x16` row, `GFX_MODE_MAX equ 1` |
| bytes changed? | ★ **NO — `karateka.bin` = `36ce471c5605`, identical to 08-11's pre-fix build** |
| build? | **green** |

**Back-port warranted — and not as a back-port.** One kernel, one bug, two copies the gate
requires to land together. Karateka's own history shows this is its normal shape for HAL work
(`HAL: add HAL_gfx_mirror`, `HAL: dr_spinup becomes conditional`), and the commit lands on its
`wip`, not `main`.

#### 3D — AC3: `blackout_page` is KEPT, and the reason has changed

P5.16f's `blackout_page` stays. ★ **But the reason is now different from P5.18's:** with the base
fix in, `HAL_gfx_clear` and `blackout_page` **are** equivalent in 16-colour — both resolve to
`draw_base` + `cur_words`. **The collapse §3.3 asks for is finally possible.**

**It is not taken here because it is a re-gate** (§4), and §4 says say so *before*, not after.

#### 3E — §2H's three checks

1. **A second mechanism for a different object class?** ★ **Yes, and it is the whole point of this
   report:** the routine consumed *two* facts from the 4-colour layout. The dispatch named the
   length. The base is the one that produced the symptom Jay actually saw.
2. **The routine that CALLS it.** Decisive for §4 — `HAL_gfx_clear`'s only caller in POP is
   `src/harness/hal_link_proof.s:67`, a link proof. **No engine caller**, which is what makes this
   a byte diff rather than a gate.
3. **Prior-report grep.** P5.16f (discovery), P5.17 §4.3 (predicted the gate), P5.18 (the stop).
   No contradiction; each is the previous one's consequence.

---

### 4 — AC5: byte delta, and the gate question answered

| artifact | before | after | Δ |
|---|---|---|---|
| `intro_seq.bin` | `b995dd26…` | `7cf156ff…` | changed, 2,714 B |
| `loader.bin` | `0b496886…` | `dea9ec18…` | changed, **1,593 → 1,606 B** |
| `cutscene_room.bin` | `fe356a12…` | `57e51b30…` | changed, 2,389 B |

★ **The dispatch expected "one opcode byte and no length" and the length DID move — §3.4 says
that is a finding, so here it is:** ~13 bytes per artifact, because the **base** fix adds
instructions the one-line form does not. The prediction holds for the fix §1 proposed; it does not
hold for the fix the defect actually needs.

★★ **NO RE-GATE, and this is §4's option A.** The changed bytes are inside a routine with **no
engine caller** (§3E.2). All three artifacts embed the HAL, so all three moved; none of them can
execute the changed instructions. **A byte diff with this explanation is sufficient.**

**A re-gate WOULD be required if §3.3 is taken** — collapsing `blackout_page` makes the routine
reachable and changes the intro's cutscene entrance. **Not done. Jay's call.**

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim). AC6 — 512 KB first:**

```
[hal-sync] OK -- HAL source aligned with karateka_coco3 (11 files compared, EOL/guard/export-placement normalised)
[map_check] 6 map(s) clean — no overlap, nothing below $0E00, introseq.map all below $2700, scene.map linked at $2700.
=== BUILD COMPLETE ===
[suites] -ramsize 512K
[suites] === introseq ===   [run_introseq_test] PASS
[suites] === integ ===      [integ] PASS
[suites] === tile ===       [run_tile_test] PASS
[suites] ALL PASS
```

Karateka: `=== BUILD COMPLETE ===`, `karateka.bin` md5 `36ce471c5605` (unchanged).

128 KB not run — unchanged by this, and failing since P5.15 §3E for unrelated reasons.

**25.2:** N/A. **25.3: no gate requested** (§4) — behaviour is unchanged and the routine is
unreachable from the engine.

---

### 6 — AC8: route accounting

**Executed:** §3.1 (length), **plus the base fix §1 did not ask for** (§3A), §3.2 (guard, fallback
mandatory), §3.3 (kept — reason updated, §3D), §3.4 (delta reported, and it moved).

**Beyond the dispatch:** the base fix, and **building Karateka to prove byte-identity** rather than
asserting it — P5.18 §7.2 had flagged that as unmeasured.

**Deviations:** the dispatch's §3.4 prediction does not hold for the delivered fix (§4), stated
rather than left in the diff.

★ **A process note that belongs in the record.** While patching, an index-based text splice matched
`HAL_gfx_clear:` in a **comment at line 7** instead of the label, and wrote a 45,103-character
block into Karateka's file. Caught immediately by an assertion on the block size, reverted with
`git checkout`, and confirmed back at md5 `6c997b0b…` before any build. **The second attempt
anchored on `"\nHAL_gfx_clear:\n"` and asserted the slice length.** This is the same trap that hit
earlier the same day on the same file; the lesson is that a unique-looking anchor in a heavily
commented file is usually not unique.

---

### 7 — Uncertainty flags

1. ★ **The 16-colour path is still not exercised by anything that runs.** `HAL_gfx_clear` has no
   engine caller, so the suites prove it *assembles and links*, not that it *clears correctly*.
   The equivalent code **is** proven live — `blackout_page` has been gated by Jay — but the HAL
   routine itself is unreached. **§3.3's collapse is what would exercise it.**
2. **Karateka's suites were not run**, only its build. Its bytes are identical, so its behaviour
   cannot have changed; a suite run would add nothing and is its own repo's business.
3. **`GFX_FB_WORDS` still exists** and is still correct for mode 0. A later reader may reasonably
   ask why both it and `cur_words` are referenced in one routine; the `ifndef` is the answer.

---

### 8 — Follow-up candidates

1. **§3.3's collapse** — now possible (§3D), and a re-gate. The only remaining piece of this arc.
2. **P5.17 §4.1's ratchet** — still the cheapest open item.
3. **The other sixteen uncalled HAL exports** — `HAL_gfx_clear` being uncalled is precisely what
   let this defect live; the same argument applies to each of them.

---

### 9 — User interaction during task

Jay, twice: *"fix the hal_gfx_clear"* (P5.18, which stopped at the sync gate), then
**"perform the fix. land it in both"** — the authorisation for the Karateka edit that §2G
otherwise forbids, and the reason this report exists.

---

### 10 — Candidate(s) captured this task

**None.** §6's splice error is a second instance of a trap already recorded this session; capturing
it as a fresh row would give the reconciler two rows for one lesson.

---

### 11 — Commit

POP `a7664bf` · Karateka `072ddcf` — both pushed to their `origin/wip` before this report.
