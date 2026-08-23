## Form B Report — P5.14 — the target moves to 512 KB, and 128 KB still runs

**Class:** Phase 1 recon; Phase 2 build. `wip`. **`main` untouched.**

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-22T21:07:01Z (HEAD `6caeedf`, wip).

★★ **AC1 — `main` AT RECEIPT: `32b5fe23a49bf43e86c64f867ff59fb40c1ce0db`.** Recorded here so the
end-of-report value can be compared to it byte for byte rather than to an abbreviation.

`git status` at receipt — the standing untracked set: `.vscode/`, `nvram/`,
`POP-idioms-coco3-markers.md`, `content/intro/broderbund_splash_render.bin`, nineteen files under
`docs/ground-truth/`, `docs/project/pop-coco3-design-v0_7.pdf`. One modified tracked file,
`harness/tools/intro_load_trace.lua` — P5.13's tracer, committed before the conversion began.

---

### 1 — Summary

★★★ **THE CONVERSION IS DONE AND IT COST ONE LINE. And the two things Jay authorised me to break
are both still intact, which is the finding rather than a boast.**

**The prod binaries are BYTE-IDENTICAL across the conversion:**

```
d07f1f3295525783968dcce6409ee1b64942231c  build/intro_seq.bin        UNCHANGED
0b4968867bf5274d2942f3b5b90ea855ad6f2def  build/loader.bin           UNCHANGED
790836577e56b61b8f849cb309874e44304840a2  build/cutscene_room.bin    UNCHANGED
```

★ **The byte-identity invariant was suspended for this dispatch by Jay's ruling. It was not spent.**
Recording that explicitly, because §0 is right that a suspended invariant which goes unrecorded
becomes a precedent — **and the precedent this sets is the opposite of the one feared: the conversion
did not need the permission.**

★★★ **AND 128 KB STILL RUNS. Both suites pass on BOTH machines, from one binary.**

```
-ramsize 512K   introseq PASS   integ PASS   tile PASS   ALL PASS
-ramsize 128K   introseq PASS   integ PASS   tile PASS   ALL PASS
```

**The reason is §3.2's own instruction.** Converting the target while deliberately not spending the
space leaves every block the port uses exactly where it was — `$0C-$0F` for the cel bank, `$10-$17`
for the framebuffers, `$38-$3F` for the program. **Those are real blocks on a 512 KB machine and they
alias correctly on a 128 KB one.** 128 KB support is therefore **not broken by this conversion**; it
breaks the first time anything claims a block above `$0F` (AC5).

**Two audit findings worth more than the conversion**, both in files the conversion had to read:

1. ★ **`gfx.s`'s own header contradicts its own constant.** Line 367 says *"buffer B physical $30000
   blocks `$18-$1B`"*; line 418 says `GFX_DB_B_BLOCK equ $14`. **`$18` is the exact value P3.10 found
   *fatal* on 128 KB** — the stale comment names the bug the code was fixed to avoid.
2. **`demo-memory-map.md` §4 is framed entirely at 128 KB** and its headline is *"the GIME block map
   at 128 KB — and 34,816 bytes nothing has claimed"*. Under the new target that number is wrong by
   an order of magnitude. **Not edited — it is an authored doc (§2D).**

---

### 2 — Files modified

- `harness/smoke/ramsize.sh` — **the conversion.** `MAME_RAM` default `128K` → `512K`, with Jay's
  ruling, P5.12's block table, and the "what this does NOT mean" clause recorded in it.

**That is the entire change.** No engine source, no link script, no bake input, no `build.bat`.

Also committed at the start, from P5.13: `harness/tools/intro_load_trace.lua` (the DSKREG edge-count
check).

**NOT edited, deliberately:** `CLAUDE.md` §2K (AC9 — drafted below, gated with the build);
`demo-memory-map.md` (§2D — authored doc, finding surfaced here instead);
`harness/tools/run_block_budget.sh` (hardcodes 128K **on purpose** — its whole subject is what the
GIME aliases away on a stock machine, so it is a 128 KB question by definition).

---

### 3 — Reasoning

#### 3A — AC3: the audit

*Authority: source, cited to file and line.*

**The block map.**

| site | what it does | 128 KB dependence |
|---|---|---|
| `sys.s:226-241` | writes `$FFA0-$FFA7` = **`$38..$3F`** | ★ **none in the literals** — these are the top eight blocks of a 512 KB machine; 128 KB works because the GIME masks them to `$08..$0F` |
| `gfx.s:417-418` | `GFX_DB_A_BLOCK $10`, `GFX_DB_B_BLOCK $14` | same shape — real at 512 KB, aliases to `$00000`/`$08000` at 128 KB |
| `intro_seq.s:138-139` | `FB_A_BLOCK $10`, `FB_B_BLOCK $14` | **a second home**, and the file says so: *"MUST match gfx.s… lwasm's export does not carry equ symbols"* |
| `tile_probe.s:74` | `TILE_BLOCK equ $0C` | ★ **the real 128 KB assumption** — `$0C` is chosen because it is free *on a 128 KB machine* |
| `cel_pack.json` | rotating pages at blocks **13, 14, 15** (`$0D-$0F`) | same |

> **★ So §2.1's reading is confirmed: the aliasing at `sys.s` is what makes one binary work on both.**
> The literals are already 512-KB-native. **The only genuine 128 KB assumption is the choice of
> `$0C-$0F` for the cel bank** — and those blocks exist on both machines, which is why nothing had to
> change.

**The suites.** `harness/smoke/ramsize.sh:49` was `MAME_RAM="${MAME_RAM:-128K}"` — **the single home**,
per the three-pass sweep its own header records (P3.98/P3.100/P3.101). One line.

**The published figures.** `demo-memory-map.md` §4 (lines 92-107, 260) — the 128 KB block table, and
*"UNALLOCATED PHYSICAL RAM ON A STOCK 128 KB MACHINE: 32,768 bytes"*. Wrong target after this
dispatch. **Surfaced, not edited** (§2D).

**And the contradiction inside `gfx.s`** (§1 finding 1) — line 367 against line 418.

#### 3B — AC6: the 56 free blocks, confirmed against `gfx.s`

*Not carried from P5.12.* `gfx.s:361`: *"PHYSICAL RAM: 512 KB, `$00000-$7FFFF`, blocks `$00-$3F`
(8 KB each)"* — **64 blocks**, and the same note records it as *"CONFIRMED, not assumed: `mame coco3
-listxml` reports `<ramoption name="512K" default="yes">`"*.

| claimant | blocks | |
|---|---|---|
| program + kernel | 4 | `$38-$3B` [`sys.s:226-233`] |
| buffer A, **used** | 2 | `$10,$11` — 15,360 B of a 4-block span |
| buffer B, **used** | 2 | `$14,$15` — likewise |
| **free** | **56** | including the 4 unused buffer tails `$12,$13,$16,$17` |

**64 − 8 = 56. Confirmed.**

★ **With one precision P5.12 did not make: 56 is the FOUR-COLOUR figure.** The framebuffer is
15,360 B, so two blocks of each four-block span are reserved-but-unused. **In 16-colour mode the
framebuffer is 30,720 B and fills all four**, so the free count would be **52, not 56**. The port
uses 4-colour throughout, so 56 stands — but it is mode-dependent and the mode is not stated anywhere
the figure is quoted.

#### 3C — AC4/AC5: what a converted build does on 128 KB

**AC4 — it runs. Correctly. Unchanged.** Both suites pass at `-ramsize 128K` on the converted build,
from the same binary that passes at 512 KB.

**There is nothing to refuse, fall back from, or fail obscurely at**, because the conversion changed
the *target* and not the *map*. **No detection path is needed and none was built** — §2.4 asked for
one only if trivial, and the correct answer is that it is not yet needed at all.

**AC5 — 128 KB is broken INCIDENTALLY, not permanently, and not yet.**

> **It breaks the first time anything claims a block above `$0F`.** Until then the port is a 128 KB
> program that happens to be verified on a 512 KB machine first. **After the first use of the new
> space it becomes a 512 KB program**, and the failure mode will be P3.10's: *"fine on 512 KB and
> fatal on 128 KB — the port loaded, started, and died at the first framebuffer access."*

★ **So Jay has the fact §2.5 asked for: nothing has been retired.** Whether to keep 128 KB working —
by confining the new space to a build-time option, or by a size check and a refusal message — is a
decision, and it is his. **This dispatch neither made it nor foreclosed it.**

#### 3D — AC7: the conversion builds, and the intro is unchanged

`build.bat` exit 0, `VERDICT: PASS - every file on the image matches its artefact`,
`=== BUILD COMPLETE ===`.

★ **"The intro runs unchanged in behaviour" is provable here rather than assertable**: the three prod
binaries are **byte-identical** to their receipt values (§1), so the intro is not merely behaving the
same, it *is* the same program. The conversion touched no input to it.

#### 3E — AC8: both suites, 512 KB first

```
[suites] -ramsize 512K          <- the new default, reported first
  introseq PASS   integ PASS   tile PASS   ALL PASS

[suites] -ramsize 128K          <- the legacy machine, run to establish AC5
  introseq PASS   integ PASS   tile PASS   ALL PASS
```

#### 3F — AC9: the §2K amendment, DRAFTED NOT APPLIED

**§2K as it stands today** [`CLAUDE.md`], quoted so the delta is visible:

> **## 2K. 128 KB is the verification target**
> **Verify on stock 128 KB first. It is the target machine and it is strictly the harder case…**
> **512 KB is confirmation, not the primary run, and most dispatches do not need it.** … Report
> 128 KB first in every case.

**The drafted replacement.** Not applied — a standing rule's wording is gated with the build:

> **## 2K. 512 KB is the target; 128 KB is the harder case and still runs**
>
> **Verify on 512 KB first — it is the target machine as of Jay's ruling, 2026-08-22.** P5.12 measured
> why: the largest single level needs 16 blocks against 8 free on a 128 KB machine, and the demo alone
> needs 10. The intro is the only part that ever fit 128 KB.
>
> **★ But 128 KB is still the harder case, and that asymmetry has not changed direction.** The GIME
> masks a block number to the RAM installed, so 512 KB can pass while a masking assumption is wrong
> and the reverse does not happen [P3.10: buffer B at `$18` was *"fine on 512 KB and fatal on 128 KB"*].
> **Run 128 KB when a change touches the MMU, the bank, the framebuffers or the loader** — a
> DIVERGENCE between the two is still informative, and after P5.14 it also means something has begun
> using the new space.
>
> **★★ 128 KB IS NOT RETIRED AND P5.14 DID NOT BREAK IT.** The conversion moved the target without
> spending the space: the port still uses `$0C-$0F`, `$10-$17` and `$38-$3F`, which are real at
> 512 KB and alias correctly at 128 KB, and both suites pass on both machines from one binary.
> **It stops working the first time anything claims a block above `$0F`** — and whether to prevent
> that, or to accept it with a size check and a refusal message, is Jay's decision and is open.
>
> **Report 512 KB first in every case; report 128 KB whenever it was run, and say so when it was not.**

---

### 4 — Verification (AC-by-AC)

- **AC1** — §0 and §6. `main` at receipt `32b5fe23a49bf43e86c64f867ff59fb40c1ce0db`; **unchanged at
  the end**; no promotion, no push to `main`, no cherry-pick.
- **AC2** — §1. All three sha1s **identical**; the suspension of the byte-identity invariant recorded
  explicitly, and recorded as **unspent**.
- **AC3** — §3A, every site cited to file and line, plus two findings the audit turned up.
- **AC4** — §3C. It runs correctly; nothing to detect yet; no detection path built, and why.
- **AC5** — §3C. **Incidental, not permanent, and not yet.** Reported, not decided.
- **AC6** — §3B. 64 − 4 − 2 − 2 = **56**, confirmed from `gfx.s:361` and `sys.s:226-233`, with the
  four-colour caveat P5.12 omitted.
- **AC7** — §3D. Builds; the intro is byte-identical, not merely equivalent.
- **AC8** — §3E. Both suites green, **512 KB first**, and 128 KB also green.
- **AC9** — §3F. Drafted and quoted; **not applied.**
- **AC10** — ★ **PASSED — Jay, live-disk, RGB, 512 KB (2026-08-23).** Jay, on the live run: *"whole thing ran."* The target machine is 512 KB and the port runs on it, observed on the delivery path rather than the poke path. Gated on build `b019264` (P5.16), the first build whose 128 KB fallback is genuinely gone — so this confirms the target move itself, which P5.14 made without spending any of its permission.
- **AC10 (original note)** — `harness/smoke/run_introseq_live.sh` now defaults to `-ramsize 512K`
  through `ramsize.sh`, forces RGB through `cfgdir.sh`'s scratch copy, and mounts a real floppy
  (`-ext fdc -flop1`). It keeps its window deliberately — it is a gate meant to be watched, which is
  the one exception to the headless default [§5.255]. **Run: `bash harness/smoke/run_introseq_live.sh`**
- **AC11** — §5.

---

### 5 — Reactive deviations and route accounting

**Deviations: none of substance.** The conversion is one line in the file the project had already
made the single home for it, which is what three passes of sweeping (P3.98/P3.100/P3.101) bought.

**What I did NOT do, each for a stated reason:**
1. **Did not edit `CLAUDE.md` §2K** — AC9 says draft, not apply.
2. **Did not edit `demo-memory-map.md`** — §2D makes authored docs the Orchestrator's; the finding is
   in §3A instead.
3. **Did not change `run_block_budget.sh`'s hardcoded 128K** — it is deliberate and correct there.
4. **Did not fix `gfx.s`'s stale header** (§1 finding 1) — it is engine source and this dispatch's
   Phase 2 is a target conversion, not a comment sweep. **Flagged for a follow-up rather than folded
   in**, because a conversion that also edits engine comments is harder to gate as a conversion.
5. **Did not build a 128 KB detection path** — §2.4 conditioned it on triviality, and §3C shows it is
   not yet needed.

**ROUTE ACCOUNTING.** No route was proposed beforehand. **§6's "convert the target; do not spend the
space" was followed literally, and that single constraint is what produced the two headline results** —
byte-identical binaries and a still-working 128 KB. Had I taken any of the 48 new blocks, neither
would be true and the gate would have two variables in it.

**Contains:** AC1-AC11, one line of conversion, the §2K draft.
**Does not contain:** any intro rework, any batching, any asset move, any promotion, and no use
whatsoever of the new space.

---

### 6 — AC1 re-check

★★ **`main` at the end of this dispatch: `32b5fe23a49bf43e86c64f867ff59fb40c1ce0db`** — character for
character the receipt value in §0. **`main` did not move.**

---

### 7 — Uncertainty flags

1. **★ The conversion is verified in emulation only.** Both suites pass on both machines under MAME.
   **AC10's hardware gate is what makes it real**, and P3.10's precedent is precisely a case where a
   block-number assumption behaved differently than expected — on the machine, not in the abstract.
2. **★ 56 free blocks is the FOUR-COLOUR figure** (§3B). Nothing in the tree states the mode alongside
   it, and in 16-colour it would be 52. If a future mode change is ever made, every block budget in
   this arc moves by 4.
3. **`intro_seq.s:138-139` is a second home for the framebuffer block numbers**, kept in sync by a
   comment rather than by the toolchain, because `lwasm`'s export does not carry `equ` symbols. It is
   correct today. It is the shape of thing that goes stale when a target moves, and this target just
   moved.
4. **The 128 KB pass proves the suites work there, not that everything does.** The suites are
   `introseq`, `integ` and `tile`; the retired `room`/`walk`/`cel` coverage is not exercised on either
   machine.
5. **Nothing has been declared about the two-block gap**, per §5 — it is moot under this ruling and
   its figures remain lower bounds. **Moot is not closed.**

---

### 8 — Follow-up candidates

1. ★ **Jay's hardware gate** (AC10) — the one thing that turns this from an emulator result into a
   converted project.
2. **Fix `gfx.s:367`'s stale header** — it names `$18`, the value P3.10 proved fatal, in a file whose
   correct constant is `$14` fourteen lines away.
3. **Fold the §2K amendment in** once the gate passes (§3F has the text).
4. **Re-issue `demo-memory-map.md` §4** at the new target — 34,816 unallocated bytes becomes ~458,752.
5. **Decide 128 KB's future** (§3C/AC5) — keep it working, or accept the break with a refusal message.
   **The fact is now on the record; the decision is Jay's.**

---

### 9 — User interaction during task

None during the task. The dispatch itself carries Jay's ruling, quoted in §0 and in `ramsize.sh`.

---

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-22-permission-to-break-something-is-not-a-reason-to.md` — §1/§5: Jay
authorised breaking prod byte-identity and the 128 KB mapping; following §6's "do not spend the
space" literally meant neither permission was needed, and the unspent permission is what makes the
gate a one-variable question. Pushed as `c80ae4e`.

---

### 11 — Commit

`4868db0` (pushed to origin/wip). ★ **`main` is untouched at
`32b5fe23a49bf43e86c64f867ff59fb40c1ce0db`.**
