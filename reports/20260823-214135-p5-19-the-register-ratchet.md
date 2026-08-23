## Form B Report — P5.19 — the register ratchet

**Class:** build (tooling). `wip`. **`main` untouched.** **Zero source bytes; prod unchanged.**

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-23T21:41:35Z. HEAD `b9ffd22` → **`9589c2c`**, pushed.
`main` = `32b5fe23a49bf43e86c64f867ff59fb40c1ce0db`. **`git status --porcelain src/` → 0** —
no assembly file was touched, at any point.

Prod, identical to P5.18c's gated build: `intro_seq.bin` 2,695 B · `loader.bin` 1,606 B ·
`cutscene_room.bin` 2,389 B. **No re-gate.**

---

### 1 — Summary

P5.17 §4.1's tier 0, built as proposed: **a new owner of a GIME/MMU/SAM register now fails the
build.** Zero bytes, no artifact moved, separable from every conversion tier — which is why it
was the recommended deliverable rather than the tiering.

**25 owner rows over 14 registers, 6 files, 10 allowlisted probes.** The tree passes today; the
26th row fails until someone writes it down.

★ **The worked example is in the baseline, marked.** `$FFA4`/`$FFA5` gained a second owner at
P5.16 when `tc_map` borrowed the framebuffer's own MMU slots. It is correct code — it saves and
restores them — and **nothing in the diff said a HAL-owned register pair had acquired an engine
owner.** P5.17 found it six commits later by enumerating. That is the event this converts into a
build failure.

---

### 2 — Files modified

- `harness/tools/register_owner_check.py` — **new**, the checker.
- `docs/project/register-owners.tsv` — **new**, the baseline, generated then hand-annotated.
- `build.bat` — the call, ahead of `map_overlap_check`.

**No `src/` file.** Explicit-path staging.

---

### 3 — Reasoning

#### 3A — what it compares, and the two shapes that were rejected

**Rows are `(register, file)` — ownership, not traffic.**

| change | result |
|---|---|
| a new file touches a register | new row → **FAILS** |
| a new register in an existing file | new row → **FAILS** |
| another write in a file that already owns it | no new row → passes |

★ **The third case is deliberate and is the design's whole content.** P5.17 §7: *"Do not
conflate 'engine touches no registers' with 'one owner.'"* 71 of the MMU accesses are the cel
bank — engine-owned by design, running every frame. A fifth `sta CEL_MMU` in the file that is
already the sanctioned owner of `$FFA6` tells a reviewer nothing; **a seventh file writing
`$FFA6` tells them everything.**

**Rejected: a bare count** (what §4.1's sketch implied). It regresses silently when one site is
deleted and another added — it would have passed the exact change it exists to catch if
`tc_map` had replaced an access rather than adding one.

**Rejected: line numbers in the baseline.** They churn on every edit above them, and a baseline
that must be regenerated after unrelated work is one people regenerate without reading.

#### 3B — ★★ the method, which had to be wrong twice first

Both errors are in the tool's header, so the next person meets them before repeating them.

1. **A naive `grep '$FF..'` over `src/engine` returns 117 hits of which 85 are COMMENT TEXT.**
   This codebase quotes register addresses in prose constantly — correctly, and I have added
   dozens myself. §4.1's sketched grep would fail the build on a comment, and **a check that
   fires on prose is a check that gets switched off**, exactly as `hal_sync_check.py` reasons
   about line endings.
2. **The same grep misses every access through an `equ` alias** — `CEL_MMU`, `BANK_MMU`,
   `TC_MMU`, `SAM_SLOW/FAST`, `PALETTE`, `msys_player`'s `FF90`–`FF95` — **which are the
   majority of the real ones.**

**Both errors are in the method and they point opposite ways**, which is why the count in §1 of
the P5.17 dispatch was 109 and the truth was 59. A line counts only if it survives all four of:
not a full-line comment; not the inline half after `;`; not an `equ` **definition**; carries a
load/store/modify mnemonic. Aliases resolve to the register they name, `+n` included.

#### 3C — verified in both directions BEFORE wiring

★ **A check nobody has seen fail is not a check.** Three experiments, tree restored after each,
`git status --porcelain src/` → 0 at the end of every one:

```
clean tree      [reg-owner] OK — 25 owner row(s) over 14 register(s), 10 file(s) allowlisted.   rc=0

literal         [reg-owner] ★ NEW OWNER: $FFA6 is now touched by src/engine/blit_core.s
                            (src/engine/blit_core.s:734, `$FFA6`)
                [reg-owner] 1 new, 0 stale. This is a build failure, not a warning.             rc=1

alias+offset    [reg-owner] ★ NEW OWNER: $FFA8 is now touched by src/engine/char_draw.s
                            (src/engine/char_draw.s:2876, `CEL_MMU+2`)                          rc=1
```

★★ **The third is the one that matters.** `CEL_MMU+2` contains no `$FF` at all and resolves to
`$FFA8` — the exact class of access a literal grep cannot see, and the class that made up most
of the real references.

#### 3D — the approval path, and why there is no override

**Adding the row to `docs/project/register-owners.tsv` in the same commit as the code IS the
approval.** No flag, no bypass, deliberately.

★ The failure this addresses is not that a second owner is wrong — ten registers have two owners
today and they are load-bearing. **It is that one arrived without anyone deciding.** So the
remedy is a diff line with a note beside it, in front of the reviewer, where an absence used to
be. `--write` regenerates the baseline and is a deliberate human act; it is never in CI.

#### 3E — the baseline is annotated, not just generated

Generated, then hand-annotated from P5.17 §3B/§3C: **which ten registers have two owners**, and
**hot|cold derived from the CALLING routine rather than the line** — `cel_bank_map` is per frame
via `room_present`; `wipe_col`'s `$FFA2` is per column, 140 per wipe; `msys_player`'s
`$FF91`/`$FF94`/`$FF95` are **inside the FIRQ handler**, per audio segment.

★ That last one is why the file says so at the row: P5.17 §3C found that the dispatch's proposed
first conversion target was the hottest code in the port, and **the annotation is where that
finding will actually be read** — next to the register, by whoever next proposes to touch it.

#### 3F — §2H's three checks

1. **A second mechanism for a different object class?** Yes — literals and aliases are two ways
   to name one register, and §3B's whole point is that a check seeing only one is worse than
   useless. A third exists and is **explicitly out of scope**: the PIA at `$FF00`–`$FF7F`
   (`DAC`, `DSKREG`), named in the tool's header so a later reader knows it was decided.
2. **The routine that CALLS it.** §3E — every hot/cold verdict in the baseline is the caller's.
3. **Prior-report grep.** P5.17 (the audit and the proposal), P5.16 (`tc_map`, the worked
   example), and `hal_sync_check.py`'s header for the "don't fire on prose" precedent. No
   contradiction; §3A's count-vs-rows choice is P5.17 §4.1's own recommendation, kept.

---

### 4 — Verification (AC-by-AC, against P5.17 §4.1)

- **AC1 — mechanism.** `register_owner_check.py`, wired at `build.bat:884`, ahead of
  `map_overlap_check`.
- **AC2 — baseline storage.** `docs/project/register-owners.tsv`, sorted, one row per
  `(register, file)`, TSV so a diff is readable and a conflict is local.
- **AC3 — approval path.** §3D: the row, same commit, no override.
- **AC4 — allowlist by explicit filename.** Ten files, including `src/engine/tile_probe.s`,
  which lives in the engine tree and which no directory rule would classify correctly.
- **AC5 — separable.** Touches no `src/` file and no conversion tier. §4.2's tiers 1–4 are
  untouched and unproposed here.
- **AC6 — zero bytes.** Prod sizes identical to the gated P5.18c build.

---

### 5 — Verdict-time evidence (v0.7 §11)

```
[hal-sync] OK -- HAL source aligned with karateka_coco3 (11 files compared, ...)
[reg-owner] OK — 25 owner row(s) over 14 register(s), 10 file(s) allowlisted.
[map_check] 6 map(s) clean — no overlap, nothing below $0E00, introseq.map all below $2700, scene.map linked at $2700.
=== BUILD COMPLETE ===
[suites] -ramsize 512K
[suites] === introseq ===   [run_introseq_test] PASS
[suites] === integ ===      [integ] PASS
[suites] === tile ===       [run_tile_test] PASS
[suites] ALL PASS
```

**25.2:** N/A. **25.3: N/A — no gate required and none requested.** No source file changed and
prod is byte-for-byte the build Jay gated at P5.18c; there is nothing new to observe.

---

### 6 — Route accounting

**Delivered exactly P5.17 §4.1** — mechanism, baseline storage, approval path, allowlist,
separability — and nothing from §4.2. **Tiers 1–4 are not started and not proposed here.**

**Beyond the proposal:** the alias resolution (§3B.2) and the three-way verification (§3C).
§4.1's sketch was a grep against a count; both would have failed on prose and been blind to the
majority of real accesses. **The proposal's shape is kept; its implementation is not what it
sketched, and that is said here rather than left in the diff.**

---

### 7 — Uncertainty flags

1. **`hot|cold` and the notes are documentation, not compared.** Only `(register, file)` is
   checked, so an annotation can rot while the row stays valid. Deliberate — comparing prose
   would fail builds over wording — but it means the notes are only as good as the last person
   to touch them.
2. **The PIA (`$FF00`–`$FF7F`) is out of scope**, so `DAC` and `DSKREG` ownership is unguarded.
   `msys_player` and the disk driver both write `DAC`. Named in the tool's header.
3. **A file could rename and lose its row silently** — the check reports it as *stale*, which
   fails the build, so the failure is visible; but the reviewer must recognise a rename rather
   than delete the row.
4. **`src/hal` is excluded** as the sanctioned owner. `hal_sync_check.py` guards that side; the
   ratchet is deliberately blind to it.

---

### 8 — Follow-up candidates

1. **P5.17 §4.2 tiers 1–2** (palette, SAM) — cold, cheap, **and they move prod bytes, so they
   spend a gate.** The ratchet does not; that was the argument for doing this first.
2. **A written ownership contract for `$FF90`–`$FF95`** — P5.17 §4.2's replacement for tier 4,
   which is *not* a conversion. The baseline now names the four rows it would cover.
3. **The PIA**, if `DAC`/`DSKREG` ownership is ever worth the same treatment (§7.2).
4. **`main` is unblocked** — everything on `wip` is gated. Jay's call, still not taken.

---

### 9 — User interaction during task

Jay: *"do the register racket."* No other interaction.

---

### 10 — Candidate(s) captured this task

**None.** §3C's *"a check nobody has seen fail is not a check"* is close to the standing
`verify-the-change-reaches-the-person-judging-it` row (both are "exercise the mechanism, don't
model it") and is better recorded as a second instance than as a new row.

---

### 11 — Commit

`9589c2c` — pushed to `origin/wip` before this report.
