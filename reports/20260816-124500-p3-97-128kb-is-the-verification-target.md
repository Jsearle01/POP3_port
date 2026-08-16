## Form B Report — P3.97 — `2K`: 128 KB is the verification target, and the runners default to the wrong one

**Class:** doc. wip. Prod untouched; no `src/` change.

**★ Jay is right and the HAL already documented the reason — including a case where a 512-KB-first
order WOULD have called a fatal build green. ★★ And the inversion is not only in the reports: the
RUNNERS DEFAULT TO 512 KB, so "run the suite" runs the wrong machine.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-16T12:29:16-04:00 (HEAD `8c289c9`, wip). Karateka untouched. `main` untouched. No `src/`
change. Pre-existing, not mine: `dist/mame-cfg/rgb/coco3.cfg`.

---

### 1 — Summary

| | |
|---|---|
| **letter** | **`2K`** — `2J` was the last; `2K` was free |
| **conflict** | **none.** `CLAUDE.md` had **no** mention of memory size anywhere before this |
| **★ verified** | the masking claim is in the HAL, with a **precedent**: `$18` was fatal at 128 KB |
| **★★ found** | the runners **default to 512 KB** — the inversion is in the tooling, not just the prose |
| **§2** | standing dispatch language reported, not edited |
| **suites** | green both sizes, **128 KB reported first** |

### 2 — Files modified

- `CLAUDE.md` — new `## 2K`

### 3 — Reasoning

**3A — HARD-STOP CHECK: DOES ANYTHING ALREADY FIX AN ORDER?** §4's gate rules and §7's Form B were
the two places that could have. **Neither does — and neither mentions memory size at all.** A grep
of the whole file for `128`, `512`, `ramsize` and `MAME_RAM` returned **nothing** before this
commit. So `2K` adds a convention rather than competing with one, and §3's requirement to reconcile
is satisfied by there being nothing to reconcile. Stated rather than assumed, because "I checked
and it's fine" is the shape of a check that was not run.

**3B — ★ THE MECHANISM VERIFIED FROM THE HAL, NOT INHERITED FROM THE DISPATCH.** The dispatch
asserts the GIME masks a block number to installed RAM. That is a claim I was about to write into
the standing rules, so I read it [`src/hal/coco3-dsk/gfx.s:405-417`]:

> *"THE TWO BUFFERS ARE ADJACENT, AND THAT IS A 128 KB REQUIREMENT (P3.10). The GIME masks a block
> number to the RAM actually installed, so on a 128 KB machine only `$00-$0F` exist and every number
> aliases mod 16 … B at `$18` is fine on 512 KB and **fatal** on 128 KB: the port loaded, started,
> and died at the first framebuffer access. `$14` aliases to `$04-$07` instead … On 128 KB that
> leaves `$0C-$0F` — 32 KB, exactly one screen — free."*

**It is confirmed, and it is stronger than the dispatch put it: there is a recorded instance.**
P3.10 shipped a block assignment that a 512 KB run would have passed and a 128 KB run killed
instantly. That precedent is what makes `2K` a rule rather than a preference, and it is why I put it
in the section text (§6 — it is an addition beyond the provided wording).

**3C — ★★ THE INVERSION IS IN THE TOOLING, WHICH MATTERS MORE THAN THE PROSE.** Jay's observation
was about how verification is *reported*. Checking, it is also how it is *run*: `run_walk_test.sh`
and `run_room_test.sh` add `-ramsize` **only when `MAME_RAM` is set**, and MAME's `coco3` default is
512 KB [`gfx.s:363`: `<ramoption name="512K" default="yes">`]. So the bare command — the one anyone
types, and the one every dispatch's "suites green" is satisfied by — **runs the non-target machine**,
and 128 KB happens only when someone remembers an environment variable.

**A rule that depends on remembering a variable is the kind this project keeps finding broken.**
`2K` says report 128 KB first; the runners still make 512 KB the path of least resistance.
**Flagged, not changed** — AC5 confines this dispatch to documentation, and flipping a runner default
is a tooling change that deserves its own line in a diff. It is follow-up 1.

**3D — §2: STANDING DISPATCH LANGUAGE.** The acceptance criteria have said **"suites green both
sizes"** since at least P3.85. That is not wrong and it is **unordered** — it does not say which is
the target, so it is satisfied identically by either order. The reports then resolved the ambiguity
the way the tooling did:

- `…-p3-87-…`: *"Room, default RAM and `MAME_RAM=128K`, both"* — 512 KB named first, 128 KB as the
  qualified case.
- `…-p3-88-…`: *"Room, default and `MAME_RAM=128K`"* — same.
- `…-p3-85-…` and `…-p3-85b-…`: *"128 KB not run"*, as a footnote to an otherwise green verdict.

★ **That last form is the sharpest illustration**: a dispatch could be reported green with the
target machine never exercised, and the AC as written permitted it. Reported, not edited.

### 4 — Verification (AC-by-AC)

- **AC1 amendment committed, letter reported** — **MET.** `## 2K`, commit `1ddf395`; sections now run
  2, 2A…2K, 3. Superset check: all nineteen pre-existing headings still present.
- **AC2 reconciled with §4 and §7** — **MET** (3A): neither implies an order, and neither mentions
  memory size, so there is no second convention.
- **AC3 the divergence case preserved** — **MET.** `2K` re-scopes 512 KB to confirmation and names
  when to run it (MMU, bank, framebuffers, loader), explicitly because a divergence is informative.
- **AC4 standing dispatch language reported, not edited** — **MET** (3D).
- **AC5 no behavioural change** — **MET.** `CLAUDE.md` only.
- **AC6 route accounting; suites; sync; Karateka; `main`** — **MET** (§5, §6).

### 5 — Verdict-time evidence (v0.7 §11)

**25.1** — reported in `2K`'s order, which is the first time:

**128 KB (target):** walk `PASS`, `STABLE`; room `PASS`.
**512 KB (confirmation):** walk `PASS`, `STABLE`; room `PASS`.
Build: `[hal-sync] OK — HAL source aligned with karateka_coco3 (11 files compared)`;
`=== BUILD COMPLETE ===`.

**25.2** N/A — documentation change.

**25.3 N/A for this dispatch** — nothing reached the screen. Standing: the flash, glass, sand and
slump **PASSED**; **the feet fix is shipped and unaffirmed**; the exit walk's skip is **open and
attributed** (P3.97 recon, commit `8c289c9`).

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING. One addition beyond the provided text**, flagged as P3.89's two were:

- **`2K`'s last paragraph** — the `gfx.s` citation and the P3.10 precedent. My words. The provided
  text asserted the masking mechanism without a source, and I was about to commit it to the standing
  rules; verifying it turned up a recorded instance of exactly the failure the rule prevents, which
  seemed worth more than the assertion. **Strike it if the Orchestrator prefers the wording as
  drafted** — the rule stands without it.

Nothing else added. No `src/` change. No dispatch text edited.

**★ Two things about this dispatch itself, reported rather than worked around:**

1. **Its number collides.** The exit-walk recon committed earlier today is also `P3.97`
   (`8c289c9`); this is the second. Harmless, but the report filenames and commit prefixes now
   disagree about what P3.97 was.
2. **Its carried-open list is stale.** It lists *"P3.96's two numbers (does the scene still pack,
   and the margins against the corrected cels)"* as open. **Both were answered in P3.96** — it packs
   at 4 pages / 1 read / 3 blocks, and the margins are 4,309 / 1,361 / 6,862 with the entry
   unchanged. Same family as the two stale premises P3.91 reported.

`hal-sync` OK. Karateka untouched. `main` untouched.

### 7 — Uncertainty flags

- **★ `2K` is a rule the tooling does not enforce** (3C). Until a runner default changes, the
  cheapest path still runs 512 KB.
- **`2K` says "most dispatches do not need" 512 KB**, which is a judgement call it does not
  operationalise. The four named triggers (MMU, bank, framebuffers, loader) are the dispatch's; I
  have not tested whether they are exhaustive.
- Carried: the exit walk's skip (attributed, needs an oracle trace to decide faithful vs defect);
  `Fdy` dropped at cel_table +2 (dormant, live for the demo); the characters' per-iteration draw;
  0.20 s driver overhead; `$2310..$2329` blindness.

### 8 — Follow-up candidates

1. **Make 128 KB the runners' default** and have `MAME_RAM=512K` be the opt-in. That is what would
   make `2K` hold without anyone remembering it.
2. The oracle trace for the exit walk's mirror anchor.
3. Whether `Fdy` should be applied before the demo's cels are drawn.

### 9 — User interaction during task

Jay: *"when Clyde runs his verification, it seems he runs it against the 512 KB MAME and then later
checks it against the 128 KB. This seems backwards and wasteful…"* — carried in the dispatch and the
basis for `2K`.

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-16-verify-where-the-constraints-bind.md`

### 11 — Commit

`1ddf395` (the amendment) and this report. Pushed to origin/wip.
