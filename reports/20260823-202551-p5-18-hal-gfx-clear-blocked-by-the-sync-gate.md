## Form B Report — P5.18 — `HAL_gfx_clear` clears half a 16-colour page, and cannot be fixed in POP alone

**Class:** build → **STOPPED AT A FINDING.** `wip`. **`main` untouched.** Prod byte-identical.

★★★ **THE FIX IS NOT APPLIED, AND THAT IS THE REPORT.** §2's premise — *"different file, and no
defect to fix"* — is **wrong on both halves**, and the second half is what blocks the work: the
same edit is required in **Karateka's** copy, which §2G forbids without Jay's authorisation.
Tested, not argued (§3C).

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-23T20:25:51Z (HEAD `bd12cc9`, wip). **AC7: `main` = `32b5fe23a49bf43e86c64f867ff59fb40c1ce0db`
at receipt and at report.**

Prod at receipt **and at report** (AC5 — **zero byte delta, all three**):

```
intro_seq.bin        b995dd263a860d1e5b595456ebc97702cbd621c0
loader.bin           0b4968867bf5274d2942f3b5b90ea855ad6f2def
cutscene_room.bin    fe356a1242e2656b7f9ba1652e5227222c1dd9c0
```

`git status --porcelain src/` → **0 lines.**

---

### 1 — Summary

**§1's defect is real and confirmed exactly as described.** `HAL_gfx_clear` takes its length from
the assembly-time `GFX_FB_WORDS equ $1E00` while `gfx_clear_window`, twenty lines away, takes it
from `HAL_gfx_cur_words` at runtime. Mode 1 is `320x192x16` at `$3C00` words, so the clear covers
**half the page**. That is what Jay saw at P5.16f.

**§2 is wrong, and this session's HAL record is now three-for-three:**

| §2 claims | measured |
|---|---|
| Karateka's `gfx.s` is **1,040 lines** | **1,658** (POP: 1,689 — a 31-line gap, all comment) |
| *"The HAL is NOT a shared file"* | `hal_sync_check.py:67` **compares it**, comments normalised away, and **fails both builds on drift** |
| *"Karateka … no defect to fix"* | **identical mode table** — same `mode 1: 320x192x16`, same `GFX_MODE_MAX equ 1`. **Same defect, latent** |
| *"this fix cannot break Karateka"* | it cannot break its **behaviour**; it **does** break its **build**, two different ways (§3B, §3C) |

★★ **AC2's answer inverts the dispatch's framing of the guard.** `HAL_GFX_MODE_SERVICE` is defined
in exactly one place — `build.bat:194` — and **Karateka never defines it at all.** So the fallback
is **not "the obvious shape, do not assume it is wanted"; it is mandatory**: without it the
reference does not resolve in Karateka, where `HAL_gfx_cur_words` is inside a guard that is off.

★★★ **And the guarded form still blocks** (§3C). Tested.

---

### 2 — Files modified

**None.** `src/hal/coco3-dsk/gfx.s` was edited twice as an experiment and reverted both times;
`git status --porcelain src/` is 0 and the three prod sha1s are unchanged. This report is the only
artifact.

---

### 3 — Reasoning

#### 3A — AC1: the defect and the diff that would fix it

Authority: **source, read directly** (§2 tier 3), and **execution** for §3C.

```
gfx_clear_window (correct)          HAL_gfx_clear (defective)
  ldy  HAL_gfx_cur_words              ldy  #GFX_FB_WORDS
```

`gfx_mode_table` row 1 — verified in **both** repos, byte-for-byte the same rows:

```
fcb $1E                 ; mode 1: 320x192x16
fcb 160                 ;   160 bytes/row
fdb $3C00               ;   30,720 B / 2
```

**The one-line form the dispatch asks for:**

```
-        ldy     #GFX_FB_WORDS           ; $1E00 word stores = 15,360 bytes
+        ldy     HAL_gfx_cur_words       ; the MODE's size
```

**The form that is actually required** (§3B), and which was the one tested:

```
                 ifdef   HAL_GFX_MODE_SERVICE
         ldy     HAL_gfx_cur_words       ; the MODE's size — 16-colour is $3C00, not $1E00
                 else
         ldy     #GFX_FB_WORDS           ; no mode service: one mode, and this is its size
                 endc
```

★ **`HAL_gfx_clear` also picks its BASE from `page_register`** (`$8000` / `$C000`) — the
4-colour side-by-side layout. In 16-colour there is one buffer and `$C000` is its bottom half,
which is why the visible symptom was the *bottom* half. **The length fix alone is not sufficient**;
the base needs `HAL_gfx_draw_base` under the same guard. §1 addresses only the length. Recorded
because a length-only fix would clear the right *number* of bytes from the wrong *address*.

#### 3B — ★★ AC2: the guard, and why the fallback is mandatory

| | POP | Karateka |
|---|---|---|
| `-DHAL_GFX_MODE_SERVICE` | **`build.bat:194`** — the only HAL assembly | **never defined** |
| `HAL_gfx_cur_words` | exists (guard on) | **does not exist** (guard off) |
| `HAL_gfx_set_mode` | exists | absent from the build |
| `HAL_gfx_clear` | outside the guard | outside the guard |

`HAL_gfx_cur_words` is declared **inside** the guard (`gfx.s:833`, `endc` at `:842`) and
`HAL_gfx_clear` sits **after** it at `:867`. **In both repos.** So an unguarded
`ldy HAL_gfx_cur_words` assembles in POP and fails to resolve in Karateka.

★ **The fallback is also behaviourally exact, not a degradation.** With no mode service Karateka
has one mode, `$1E00` is its size, and the `else` branch emits the identical instruction it emits
today — so its five `HAL_gfx_clear` callers (`boot.s` ×4, `intro_scenes.s:131`) are byte-identical.
*Reasoned, not measured: Karateka was not built (§7.2).*

#### 3C — ★★★ the finding: BOTH forms are blocked, and it was tested twice

`hal_sync_check.py` compares `src/hal/coco3-dsk/gfx.s` across the repos (`:67`), dropping blank
lines, comments (`:90`) and the **dormancy guard's own** directives — and it keeps every other
`ifdef`/`endc` as a substantive line (`:93-107`). Two experiments, each reverted:

**Attempt 1 — the unguarded fix:**
```
[hal-sync]   src/hal/coco3-dsk/gfx.s: content differs at substantive line 282
        POP3_port: ldy HAL_gfx_cur_words ; the MODE's size, not a constant
        karateka_coco3: lda <page_register ; read page_register ($50)
```

**Attempt 2 — the guarded fix, the one §3 asks for:**
```
[hal-sync]   src/hal/coco3-dsk/gfx.s: content differs at substantive line 291
        POP3_port: ifdef HAL_GFX_MODE_SERVICE
        karateka_coco3: ldy #GFX_FB_WORDS ; $1E00 word stores = 15,360 bytes
[hal-sync] The HAL is ONE kernel in two copies. Reconcile the two files, then rebuild.
*** BUILD BLOCKED BY HAL DRIFT ***
```

★★ **The guard does not buy an exemption**, because only `POP_HAL_RUNTIME_BLIT`'s directives are
dropped — everything else is compared, by design, so that a per-project fork cannot hide inside a
conditional. **The check is behaving correctly. There is no POP-only expression of this fix.**

★ **Reverted to green after each:** `[hal-sync] OK -- HAL source aligned with karateka_coco3
(11 files compared…)`, `=== BUILD COMPLETE ===`.

#### 3D — AC3: `blackout_page` is KEPT, and here is the reason

**Kept.** With `HAL_gfx_clear` unfixed it is the only correct clear at POP's one 16-colour call
site. §3.3's collapse is conditional on the fix, and the fix is blocked.

★ **And even after the fix it would not be exactly equivalent, which §3.3 asked to be checked.**
`blackout_page` uses `HAL_gfx_draw_base`; `HAL_gfx_clear` uses `page_register`. In 16-colour the
back buffer is the window at `draw_base` and the flip is a **re-map**, not an address change — so
`page_register`'s A/B token selects between `$8000` and `$C000`, and `$C000` is *inside* the same
buffer. **They can disagree, and the disagreement is the original defect.** Collapsing
`blackout_page` requires §3A's base fix as well as the length fix.

#### 3E — AC4: Karateka verified, and a back-port **IS** warranted

- **Different file?** No — 1,658 vs 1,689 lines, differing only in commentary, and **gate-enforced
  identical** in substance.
- **Identical body?** Yes, `HAL_gfx_clear` included.
- **No defect?** **No — the same defect.** Identical mode table with a 16-colour row and
  `GFX_MODE_MAX equ 1`. It is **latent**, not absent: with the mode service compiled out, Karateka
  cannot reach mode 1 today.
- **Back-port warranted?** ★ **Yes — and not as a back-port.** This is one kernel with one bug; the
  edit is the same text in both copies and the gate requires them to land together. §2G still makes
  the Karateka side its own task and Jay's call, but it is **not optional** if the fix is wanted.

#### 3F — §2H's three checks

1. **A second mechanism for a different object class?** Yes — §3A: the routine gets **two** things
   from the 4-colour layout, the *length* and the *base*. §1 names the length. Fixing only that
   clears the right number of bytes at the wrong address in 16-colour.
2. **The routine that CALLS it.** Decisive for §4: `HAL_gfx_clear`'s only caller in POP is
   `src/harness/hal_link_proof.s:67` — a link proof, not prod. **Nothing in the engine calls it.**
3. **Prior-report grep.** P5.16f (the discovery), P5.17 §4.3 (the same gate, the same wall,
   predicted there), §5.283-287. **No contradiction — P5.17 §4.3 already recorded that "additive
   behind a feature guard would NOT pass the sync check", and §3C is that prediction confirmed by
   experiment.**

---

### 4 — AC5: the gate question, answered BEFORE any gate is requested

**No gate is requested. Nothing changed.**

★ Had the fix landed, **§4's option A applies**: `HAL_gfx_clear` is linked into prod but **has no
engine caller** (§3F.2), so its bytes move and its behaviour does not. A byte diff with that
explanation would be sufficient and **no re-gate would be needed** — *provided* §3.3 is NOT taken.

★★ **If `blackout_page` is collapsed (§3.3), it IS a re-gate** — the cutscene entrance changes
path. §3D says that collapse also needs the base fix. **So the three items are one decision, not
three:** length + base + collapse, and taking the third makes it a gate. **Recommend: length +
base, leave `blackout_page`, no gate.**

**Byte delta as measured: 0 for all three artifacts** — nothing was applied.

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim), AC6 — 512 KB first:**

```
[hal-sync] OK -- HAL source aligned with karateka_coco3 (11 files compared, EOL/guard/export-placement normalised)
=== BUILD COMPLETE ===
[suites] -ramsize 512K
[suites] === introseq ===   [run_introseq_test] PASS
[suites] === integ ===      [integ] PASS
[suites] === tile ===       [run_tile_test] PASS
[suites] ALL PASS
```

★ **Green on the REVERTED tree**, which is the honest claim: this proves the experiments left
nothing behind, not that a fix works. 128 KB not run — nothing changed, and it has been failing
since P5.15 §3E for unrelated reasons.

**25.2:** N/A — no artifact produced. **25.3: N/A** — nothing runs differently; **no gate claimed.**

---

### 6 — AC8: route accounting

**No route proposed** before the dispatch.

**Executed:** §3.1 attempted (twice), §3.2 answered, §3.3 decided (keep, with reason), §3.4
answered (0 bytes — nothing applied), §2 verified and **falsified**.

**NOT executed, and named rather than left to a diff:** the fix itself. Two edits were made to
`src/hal/coco3-dsk/gfx.s` as experiments and both were reverted; **neither is in the tree and
neither is committed.** §2G forbids the Karateka edit that would be required, and §7's *"stop and
report rather than resolving ambiguity silently"* governs.

**Deviations, all §7-sanctioned:** §2 wrong on four counts (§1 table); §1's fix incomplete (§3A —
the base); AC2's fallback mandatory rather than optional (§3B).

---

### 7 — Uncertainty flags

1. **The base fix (§3A) is reasoned from the source, not observed.** The *length* half was
   confirmed live by Jay at P5.16f; the claim that `page_register` also mis-selects in 16-colour
   follows from the layout and has not been run — the routine has no engine caller to run it.
2. **Karateka was not built.** §3B's byte-identical claim for its five callers is reasoning from
   `else`-branch equivalence, not measurement. **Building Karateka is a Karateka-side act** and was
   not performed.
3. **Karateka's file was read, never written.** Confirmed by its own `git status` being untouched
   by this task — no edit was attempted there at any point.
4. **`GFX_FB_WORDS` remains correct for mode 0** and is not proposed for removal; a later reader
   may reasonably ask why both exist.

---

### 8 — Follow-up candidates

1. ★ **Jay's ruling on the Karateka edit.** The fix is two identical hunks in two repos, landing
   together. Without that authorisation this item cannot move at all.
2. **The base fix** (§3A) belongs in the same hunk as the length fix.
3. **`blackout_page`'s collapse** (§3D) — only after 1 and 2, and it is a re-gate.
4. **P5.17 §4.1's ratchet** — unaffected, still the cheapest open item.
5. **The other sixteen uncalled HAL exports** — out of scope here; `HAL_gfx_clear` being uncalled
   is what made this defect survive.

---

### 9 — User interaction during task

None during the task. ★ The dispatch cites Jay's ruling *"fix the hal_gfx_clear call and verify
against Karateka."* **The verification is what stopped the fix** — it says the Karateka copy must
change too, which is the one thing §2 assumed would not be needed.

---

### 10 — Candidate(s) captured this task

**None.** The nearest general lesson — an isolation claim ("different file, cannot affect the
sibling") that a build gate falsifies in one command — is a second instance of
`2026-08-23-verify-the-change-reaches-the-person-judging-it` rather than a new row: in both cases
a plausible model of the system was believed instead of exercised, and one command settled it.
Held for the reconciler as a second instance.

---

### 11 — Commit

Report only; **no `src/` change to commit.** Pushed to `origin/wip`.
