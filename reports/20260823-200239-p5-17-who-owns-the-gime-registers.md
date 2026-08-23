## Form B Report — who owns the GIME registers — audit and proposal, no code

**Class:** Phase 1 recon; Phase 2 proposal. `wip`. **Nothing built. Prod byte-identical.**

★ **NUMBERING FLAG.** The dispatch is labelled **P5.15**, and that number is taken: P5.15 was
the cutscene's disk read (`8cedebd`, gated 2026-08-23), and P5.16/b–g followed it. Filed as
**P5.17** so the report set stays ordered; the Orchestrator may renumber. Nothing else about
the dispatch is affected, and this is flagged rather than silently resolved (§8).

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-23T20:02:39Z (HEAD `d1ccc9a`, wip). `main` = `32b5fe23a49bf43e86c64f867ff59fb40c1ce0db`.

Prod at receipt **and at report, unchanged**:

```
intro_seq.bin        b995dd263a860d1e5b595456ebc97702cbd621c0
loader.bin           0b4968867bf5274d2942f3b5b90ea855ad6f2def
cutscene_room.bin    fe356a1242e2656b7f9ba1652e5227222c1dd9c0
```

`git status --porcelain src/` → **0 lines**, at receipt and at report. Whole tree → 0 tracked
changes. **The hard stop was observed.**

★ The dispatch's send-condition is met: **P5.14 gated** 2026-08-23 (*"whole thing ran"*), so
the block map this audits is the settled 512 KB one, not the one being rewritten.

---

### 1 — Summary

**§1's headline figure does not survive contact: it is 59, not 109 — and the shortfall is not
good news, it is a different problem.**

| | dispatch | **measured** | what the gap is |
|---|---|---|---|
| HAL | 148 | **47** | comments |
| outside HAL | **109** | **59** | comments, **minus** aliases the literal count misses |
| harness | 120 | **120** | (raw); **73** as code |

The 109 counts **comment text**. This codebase quotes register addresses constantly in prose —
correctly, and I have added dozens myself this session — so a `grep '$FF..'` over `src/engine`
returns 117 of which **85 are commentary**. But the same grep also **misses every access made
through an `equ` alias**, and those are the majority of the real ones: `CEL_MMU`, `BANK_MMU`,
`TC_MMU`, `SAM_SLOW/FAST`, `PALETTE`, and `msys_player`'s `FF90`–`FF95`. **Both errors are in
the method, and they point opposite ways.**

★★ **The finding that matters is not the count. It is that there are TEN two-owner registers,
not one.** §1 names `$FF92`/`$FF93`; the audit finds eight more, including **every framebuffer
MMU slot** and **the palette**.

★★★ **And §4.2's lead is INVERTED by the hot/cold split, which §7 says outranks it.** The
dispatch proposes converting `$FF92`/`$FF93` first because they caused a bug. They are written
**inside the FIRQ handler**, at audio rate — the hottest code in the port. Routing them through
a `jsr` is the single worst conversion available. **The register that already caused a bug and
the register that is safe to convert are not the same register**, and §4.4's honesty about cost
is what makes the difference visible.

**§4.1's ratchet survives intact and is the recommended deliverable.**

---

### 2 — Files modified

**None.** No file under `src/` was created, edited or staged. This report is the only artifact.

---

### 3 — Reasoning

#### 3A — AC1: the census, and why the method had to change twice

**Authority: execution / tool output** (§2 tier 2 — grep over the tree, not a description of it).

A reference counts as an **access** only if the line survives all four of: not a full-line
comment (`*`), not the inline half after `;`, not an `equ` definition, and carries a load/store
mnemonic. Aliases are resolved to their register, `+n` offsets included — so `sta CEL_MMU+1` is
counted as `$FFA7`, which is what it writes.

**59 accesses outside the HAL, in 6 files:**

| file | count | registers | hot? |
|---|---|---|---|
| `msys_player.s` | **23** | `$FF90`–`$FF95` | ★ **HOT — FIRQ** |
| `intro_seq.s` | **19** | `$FFA2`, `$FFA4`–`$FFA7`, `$FFD8/9`, `$FFB0` | mixed |
| `char_draw.s` | 4 | `$FFA6`, `$FFA7` | ★ hot (per beat) |
| `cutscene_room.s` | 4 | `$FFA6`, `$FFA7`, `$FFD8/9` | ★ **HOT — per frame** |
| `loader.s` | 2 | `$FFD8`, `$FFD9` | cold |
| `tile_probe.s` | 2 | `$FFA6`, `$FFD8` | cold (probe) |
| `intro_splash.s` | 5 | `$FFB0` | cold |

#### 3B — ★★ AC2: TEN registers with two owners

Written both inside and outside the HAL:

| reg | HAL | outside | outside owners |
|---|---|---|---|
| `$FF90` | 8 | 3 | `msys_player.s` |
| `$FF92` | 4 | 3 | `msys_player.s` — **the known one** |
| `$FF93` | 2 | 4 | `msys_player.s` — **the known one** |
| `$FFA2` | 1 | 5 | `intro_seq.s` |
| `$FFA4` | 3 | 3 | `intro_seq.s` |
| `$FFA5` | 2 | 3 | `intro_seq.s` |
| `$FFA6` | 2 | 6 | `char_draw.s`, `cutscene_room.s`, `intro_seq.s`, `tile_probe.s` |
| `$FFA7` | 2 | 7 | `char_draw.s`, `cutscene_room.s`, `intro_seq.s` |
| `$FFB0` | 2 | 5 | `char_draw.s`, `intro_seq.s`, `intro_splash.s`, `loader.s` |
| `$FFD9` | 2 | 3 | `cutscene_room.s`, `intro_seq.s`, `loader.s` |

★ **`$FFA4`/`$FFA5` became two-owner THIS SESSION, by my hand.** P5.16's `tc_map` borrows the
framebuffer's own MMU slots to reveal a cached track. It saves and restores them, and it is
correct — **and it is exactly the pattern the ratchet exists to make visible.** A reviewer
reading only the diff would not have seen a new owner appear on a HAL-owned register pair.
**The 110th reference the ratchet is meant to catch was added six commits ago.**

★★ **`$FFD8` is the mirror-image finding: 0 HAL, 4 outside.** The speed-*down* for the FDC is
entirely engine-owned while the speed-*up* `$FFD9` is shared. A single owner, on the wrong side
of the boundary — invisible to a two-owner test, and worth naming because the disk-speed rule
is a §2G invariant carried from Karateka.

#### 3C — ★★★ hot/cold, and the finding that outranks §4.2

**Hot = executes per frame or faster. §7 asked for this to be checked against the lead.**

**HOT, and they are not where the dispatch expected:**

1. **`msys_player.s` `$FF91`/`$FF94`/`$FF95` — inside the FIRQ handler.** `fh_quiet` and
   `fh_pad1` write the GIME timer registers per *segment*, and a segment is one square-wave
   period. **This is audio-rate — orders hotter than per-frame.** `$FF92`/`$FF93`/`$FF90` are
   written on the song-end path, also inside the FIRQ.
2. **`cutscene_room.s:1273,1280` — `cel_bank_map`, called from `room_present`**, which is
   `jsr HAL_gfx_swap / jsr cel_bank_map`. **Per frame.**
3. **`intro_seq.s:1433` — `wc_loop`, inside `wipe_col`.** `WIPE_COLS = 140` columns per wipe.
   **Per column.** The dispatch did not anticipate a hot `$FFA2`.
4. **`char_draw.s:2203` — the beat's page map**, 1.58×/s per §5.227. Warm, not hot.

**COLD** — `intro_seq.s`'s `TC_MMU` pair (~11 fetches per run), `cel_preload` (once), every
`$FFB0` site, `loader.s` (once), `tile_probe.s`, and the `SAM` writes (once per disk read, 19
per run).

★★★ **THE INVERSION.** §4.2 leads with *"`$FF92`/`$FF93` (14 refs) — convert. Worth a
re-gate."* **Those registers are written from an interrupt handler that fires per audio
segment.** A `jsr`+`rts` is ~12–14 cycles; the FIRQ's whole budget is a fraction of a segment,
and §5.224 already records that a single-register write is 7 cycles — **the call overhead would
exceed the work.** Converting them is not a re-gate cost, it is a **correctness risk to the
sound arc**, which is the one subsystem whose failure mode is already documented as silent.

**The register that caused the bug and the register that is safe to convert are different
registers.** The bug was *shared latches without a protocol*; the fix for that is a protocol,
not an indirection — and **the code already has one**: `firq_arm` takes IRQENR down, and the
song-end path hands the VBL back explicitly (`sta FF92 ; ★ the VBL, back to the IRQ path`).
What is missing is not a HAL call. It is **a written contract and a check that no third owner
appears.**

#### 3D — §2H's three checks

1. **A second mechanism for a different object class?** Yes, and it is §3C.3: the audit set out
   to find *MMU* contention and found the **timer/interrupt** registers to be the hot ones, with
   a third class (`wipe_col`'s `$FFA2`) hot for a reason — the wipe — that has nothing to do
   with either. **Three object classes, three different reasons to touch a register.**
2. **The routine that CALLS it.** Decisive here and it is why §3C exists: `cel_bank_map` reads
   cold at its own line and is per-frame at its caller; `fh_quiet` is a label until you know
   `fh_` is the FIRQ. **Every hot/cold verdict in this report is the caller's, not the line's.**
3. **Prior-report grep.** §5.224 (7-cycle write), §5.227 (1.58×/s), P3.10 (block numbers),
   P5.14 (the block map), P5.16 (`tc_map`). No contradiction; §5.224's cycle figure is what
   makes §3C's argument quantitative rather than an opinion.

#### 3E — AC3: the harness allowlist, by explicit filename

**By filename, never by pattern** — as the dispatch requires, so adding one is a visible act:

```
src/harness/anim_probe.s          src/harness/mode_probe.s
src/harness/cel_probe.s           src/harness/shift_bench.s
src/harness/compiled_probe.s      src/harness/song_probe.s
src/harness/interp_probe.s        src/harness/tone_probe.s
src/harness/loop_probe.s
```

Nine files, 73 code accesses. ★ **And one file that is NOT in `src/harness` belongs on the same
list: `src/engine/tile_probe.s`.** It is a probe by name, behaviour and its own header, and it
sits in the engine tree — so a directory-scoped rule would either miss it or force it to move.
**Listing files rather than directories is what makes that a one-line decision instead of a
refactor.**

---

### 4 — Phase 2: the proposal

#### 4.1 — AC4: the ratchet ★ RECOMMENDED, and separable

**Mechanism.** A build step that enumerates register accesses exactly as §3A does — comments
stripped, `equ` definitions excluded, **aliases resolved** — and compares the result to a
checked-in baseline.

**Why alias resolution is load-bearing rather than a refinement:** a literal-only ratchet would
have baselined 32 accesses and been blind to `CEL_MMU`, which is the single most-contended
symbol in the port. It would also have failed the build on a *comment*, which §4.1's own grep
would do today — and a check that fires on prose is a check that gets bypassed, exactly as
`hal_sync_check.py` reasons about line endings.

**Baseline storage:** `docs/project/register-owners.tsv`, one line per site —
`register<TAB>file<TAB>symbol-or-literal<TAB>hot|cold<TAB>owner-note`. Sorted, so a diff is
readable and a merge conflict is local. **Not** a bare count: a count regresses silently when
one site is deleted and another added.

**Approval path:** adding a line to the baseline **is** the approval, in the same commit as the
code, so the reviewer sees the new owner as a diff line with a note beside it rather than as an
absence. **`$FFA4`/`$FFA5` in §3B is the worked example** — that addition would have been one
visible line instead of an invisible one.

**Cost: zero bytes.** No prod artifact moves. No re-gate. **Separable from everything below and
should be done first regardless of what is decided about §4.2.**

#### 4.2 — AC5: tiering, revised by the measurement

| tier | what | cost | prod artifacts moved | verdict |
|---|---|---|---|---|
| **0** | the ratchet (§4.1) | none | **none** | ★ **do it** |
| **1** | `$FFB0` palette — 5 cold sites | small | `intro_seq.bin`, `loader.bin` | do it, cheap |
| **2** | `$FFD8`/`$FFD9` SAM — 7 cold sites | small | all three | do it; **and fix the `$FFD8` asymmetry** |
| **3** | `$FFA6`/`$FFA7` cel window — 13 sites, **hot** | a `jsr` per frame | `cutscene_room.bin` | **primitive, not conversion** — §4.2's lead is right |
| **4** | `$FF90`–`$FF95` — 23 sites, **FIRQ** | ★ **cycles inside an audio interrupt** | `intro_seq.bin` | ★ **DO NOT CONVERT** — §3C |

★ **Tier 3 largely exists already.** `cel_bank_map` *is* the single sanctioned entry point the
dispatch asks for; what is missing is that `HAL_gfx_swap` clobbers `$FFA6`/`$FFA7`, so the
engine must re-map after every flip (`char_draw.s:2203`'s own comment says so). **The honest
tier-3 item is not "export a primitive" — it is "decide whether the HAL's swap should preserve
the window it does not own."** That is a HAL behaviour question and is out of scope here.

★★ **Tier 4's replacement deliverable:** a written ownership contract for `$FF90`–`$FF95` —
who takes IRQENR, who hands it back, and when — placed in `msys_player.s`'s header where the
FIRQ author will read it, and enforced by tier 0. **No bytes move.**

#### 4.3 — AC6: Karateka impact — **ZERO**

**No HAL change is proposed**, so there is nothing for the sibling to absorb. Tiers 1–2 touch
engine call sites only; tier 0 is a build step; tiers 3–4 are explicitly not conversions.

★ **This is load-bearing today rather than theoretical.** Earlier in this same session a
one-routine HAL fix (`HAL_gfx_clear`) was blocked by `hal_sync_check.py` — *"The HAL is ONE
kernel in two copies"* — whose sanctioned divergences are line endings, the dormancy guard,
export placement and comments, and **explicitly still compares code inside the guard**. So
§4.3's "additive behind a feature guard" **would not pass the sync check**: guarded code is
compared, and a symbol appearing in one copy's ABI is named as drift. **Any HAL addition needs
Jay's authorisation to touch Karateka, and a Karateka-side re-gate.** That is the strongest
argument for keeping this dispatch's deliverable at tier 0.

#### 4.4 — the re-gate, costed honestly

- **Tier 0:** no bytes, **no re-gate**.
- **Tier 1:** `intro_seq.bin`, `loader.bin` move. **Jay must re-gate the intro on hardware.**
- **Tier 2:** all three move, and it touches the **disk-speed rule** (§2G, PROVISIONAL). **Jay
  must re-gate the intro AND the cutscene**, and the disk path is what P5.16 just spent seven
  live runs settling.
- **Tiers 3–4:** not proposed.

★ **Timing note:** the intro and cutscene were gated **today**, at `17fde43`. Tiers 1–2 would
spend that gate. **Recommend banking it and doing tier 0 alone.**

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output:** the census in §3A/§3B is the tool output, run over the tree at
`d1ccc9a`. **No build was run and none was required — nothing was built** (AC10).

**25.2 bundled-artifact grep:** N/A — no artifact produced.

**25.3 operator-runtime-smoke: N/A — nothing runs.** Recon and proposal only; there is no
behaviour to observe and **no gate is claimed**.

**AC8 — stop observed:** `git status --porcelain src/` → **0 lines**.
**AC9 — prod byte-identity:** three sha1s identical at receipt and report (§0).

---

### 6 — Reactive deviations and route accounting

**No route was proposed** before this dispatch; it arrived complete.

**Deviations from the dispatch's expectations, all §7-sanctioned:**

1. **§1's counts are wrong in both directions** (§1, §3A) — the dispatch invited the check.
2. **§4.2's first tier is inverted** (§3C). The dispatch says *"if the hot/cold split
   contradicts the expectation, that finding outranks the dispatch"* — it does, and it does.
3. **Nine two-owner registers beyond the one named** (§3B).
4. **§4.3's "additive behind a feature guard" would not pass `hal_sync_check.py`** (§4.3).
   Reported rather than worked around.

**Not done, and not attempted:** any conversion, any HAL edit, any re-gate. `git status` proves
it rather than asserting it.

---

### 7 — Uncertainty flags

1. **The dispatch number collides.** Filed as P5.17; the Orchestrator may renumber.
2. **"Hot" is derived from callers and comments, not from a profile.** The FIRQ classification
   is certain (`fh_*` is the handler); `cel_bank_map` is certain (`room_present`); `wipe_col`'s
   per-column rate is read from `WIPE_COLS = 140` and its two `bsr` sites. **A write-tap census
   would settle the marginal cases** and was not run — §7's *"only a write tap finds events"*
   applies, and this audit is static.
3. **`$FFB0` is counted as one register.** The palette is `$FFB0`–`$FFBF`; the HAL writes
   `$FFB0`–`$FFB3` and the outside writers index from a base. Site counts are right; a
   per-entry breakdown was not done.
4. **`src/engine/tile_probe.s` is classified as a probe on its header and behaviour**, not by a
   rule. If the allowlist is filename-based this is a one-line decision; under any directory
   rule it is a judgement someone must make.
5. **The 120 vs 73 harness figure** is raw-vs-code; §3E's allowlist uses code counts. Either is
   defensible for a baseline as long as the ratchet and the baseline agree.

---

### 8 — Follow-up candidates

1. **Tier 0, the ratchet** — the recommended next dispatch, and the only one that costs nothing.
2. **`HAL_gfx_swap` and the cel window** (§4.2 tier 3) — should the swap preserve a window it
   does not own? Answering that would remove 13 hot writes rather than route them.
3. **`$FFD8`'s missing HAL owner** (§3B) — a single owner on the wrong side of the boundary.
4. **`HAL_gfx_clear`** — still 4-colour-only, still blocked on the Karateka question from
   earlier today. Unchanged by this dispatch.
5. **A write-tap register census** to replace §7.2's static classification.

---

### 9 — User interaction during task

None. The dispatch arrived complete and ends at a hard stop.

★ One item from **earlier the same day** is load-bearing here and is cited rather than
re-litigated: Jay's ruling to fix `HAL_gfx_clear`, and the `hal_sync_check.py` block that
followed it, which is what makes §4.3's guard proposal untenable. **That question is still
open and this report does not resolve it.**

---

### 10 — Candidate(s) captured this task

**None.** §3A's lesson — that a count over a commented codebase measures prose, and that the
same grep misses aliases — is close to
`2026-08-23-verify-the-change-reaches-the-person-judging-it` (measuring the wrong link in the
chain) and to P5.15's `more-resource-worse-result-means-a-greedy-stop`. **Held rather than
captured**: a third row restating a neighbour is what the pool's reconciler has to unpick, and
this instance is better recorded as a second instance of an existing row than as a new one.

---

### 11 — Commit

Report only; **no `src/` change to commit.** Pushed to `origin/wip`.
