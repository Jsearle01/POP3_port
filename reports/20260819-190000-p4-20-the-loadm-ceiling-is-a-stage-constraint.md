## Form B Report — P4.20 — `CLAUDE.md` §2L: the LOADM ceiling is a stage constraint

**Class:** doc.  wip.  Prod unchanged — **no source, no asset, no build input touched.** `build.bat` was run
only to satisfy AC4; it produced identical outputs. Karateka untouched; `main` untouched (`34e93e0`); oracle
source read-only.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-19 19:00 (HEAD `764c238`, wip). Working tree clean apart from the pre-existing untracked
`docs/ground-truth/*.pdf`, `nvram/`, `.vscode/` and the modified `dist/mame-cfg/rgb/coco3.cfg` that have been
dirty since P4.19's receipt.

### 1 — Summary

**§2L is in, verbatim, at the next free letter. The letter used is `2L`** — §2K (128 KB is the verification
target) was the last, and §2L now sits between it and §3.

**★★★ AND THE DISPATCH'S PREMISE IS CORROBORATED BY THIS SESSION'S OWN WORK, WHICH IS THE THIRD
MISAPPLICATION, NOT THE SECOND.** The dispatch names P4.11 and P4.12. **P4.19 — the dispatch immediately
before this one — made the same error a third time and paid the full price for it:** it searched the entire
intro memory map for somewhere to `LOADM` a music player, concluded *"the intro's memory is full"*, linked
the player into `INTROSEQ.BIN`, and got a truncated kernel segment out of the suite. Jay had to say it twice
(*"why are we still working against the loadm cieling…"*, then *"again we shouldnt need to orry about
loadm"*) before it was corrected.

**★★ That is exactly the failure this amendment exists to stop, and it happened while the amendment was being
written.**

### 2 — Files modified

- `CLAUDE.md` — §2L added. **16 insertions, 0 deletions.**

Explicit-path staging only.

### 3 — Reasoning

#### 3A — AC1: the letter, and the superset check

**Letter used: `2L`.** Enumerated rather than assumed:

```
## 2A ... ## 2B ... ## 2C ... ## 2D ... ## 2E ... ## 2F ... ## 2G
## 2H ... ## 2I ... ## 2J ... ## 2K      <- last
## 2L   <- added
## 3. PNG Handling Rules (absolute)
```

**★ §2D's SUPERSET DIFF-CHECK passes by construction rather than by inspection.** The change is an insertion
between two existing paragraphs, so no in-repo line can have been lost — and the diff confirms it:

```
CLAUDE.md | 16 ++++++++++++++++
1 file changed, 16 insertions(+)
lines removed: 0
```

Text rendered **verbatim** from the dispatch. **I authored none of it** (§2D: Orchestrator owns content,
Clyde owns commit).

#### 3B — AC2: no conflict, and why the two LOADM mentions in §4 are not a second convention

**`CLAUDE.md` mentions `LOADM` in exactly two places outside §2L, both inside §4 (MAME Visual Gate), and both
are about the LAUNCH PATH rather than about size:**

```
341:  - **`live-disk`** — real `LOADM`+`EXEC` off a mounted floppy (the delivery path…)
344:    load/launch bugs: the freeze P2.7, the LOADM ceiling P3.3, the EXEC-overwrite P3.5 all lived on the
      real path and were invisible to poke
```

**Line 344 is the only one that could be read as a scope claim, and it is not one.** It names *"the LOADM
ceiling P3.3"* as a member of a list of **bug classes the poke path hides** — the point being that `poke`
bypasses the loader and therefore cannot see loader faults. That is a statement about **where a bug is
observable**, not about **what the ceiling constrains.**

**★ So §4 and §2L are complementary and no second convention forms:**

| | |
|---|---|
| **§4** | the ceiling is a real fault that only the `live-disk` path can expose |
| **§2L** | the ceiling binds on the handover moment and not afterwards |

Both are true simultaneously. **P4.19 is the proof that they are:** the truncation was real, and it was
**only** visible on the live-disk suite (§3C), *and* it should never have been risked because the player did
not belong in the image at all.

**★★ ONE RECONCILIATION I HAVE NOT MADE, AND AM SURFACING INSTEAD OF DOING.** A reader arriving at §4:344
sees *"the LOADM ceiling"* with no pointer to its scope. A one-line cross-reference — `the LOADM ceiling P3.3
(scope: §2L)` — would close that. **I have not added it: §2D puts the content of this document with the
Orchestrator, and the dispatch supplied §2L's text only.** It is a one-token edit whenever the Orchestrator
wants it.

#### 3C — the evidence P4.19 contributes, which the Orchestrator may want to fold into §2L

**Not added to the text** — surfacing per §2D. Three measurements from P4.19 sharpen §2L's claim, and one of
them is a *new number*:

1. **★★★ THE CEILING IS ABOUT THE IMAGE, NOT THE `prog` SECTION'S END ADDRESS.** P3.22 measured it as
   *"prog ending `$2487` boots; `$2535` image corrupted"*, which reads as a limit on where `prog` ends.
   P4.19 hit truncation with **`prog` unchanged at `$2462`** and a second segment elsewhere: payload
   2,215 B → 5,317 B. The failure signature was `$7900..$7D43` reading `34..00` against `34..39` — the
   kernel segment begun and not finished. **So the binding quantity is the total LOADM image, and the
   `$2488..$2535` figure is one instance of it rather than the rule.**
2. **★★ THERE IS ALSO A FLOOR, AND ITS MIDDLE CASE IS THE DANGEROUS ONE.** DECB's file buffers reach above
   `$0A00`. Bisected on the target:

   | segment at | result |
   |---|---|
   | `$0A00`, `$0C00` | the probe never starts — loud |
   | **`$0D00`** | **it loads, RUNS, and emits nothing** — silently corrupted data |
   | `$0E00` | clean |

   **A `LOADM`-able segment's floor is `$0E00`.** Like the ceiling, it is a *handover-moment* constraint —
   read the same bytes off a track afterwards and the whole of `$0A00..$1FFF` is usable, which is where the
   player now lives.
3. **★ AND THE THIRD FAILURE AT `$1000` WAS NOT THE CEILING AT ALL** — 4,456 B there ran through the engine's
   own load address and lwlink placed it **silently**. It presented as *"the LOADM/EXEC did not take"*, the
   ceiling's signature, one region away from the real fault. `harness/tools/map_overlap_check.py` is now a
   build gate for both that and the floor. *Mentioned because it is the failure mode most likely to be
   mistaken for the one §2L is about.*

#### 3D — §2H's three checks, applied to this dispatch's claim

The claim being committed is *"the ceiling stops applying at handover."*

1. **Is there a SECOND mechanism?** **Yes, and §2L does not name it: the FLOOR** (§3C.2). Both are properties
   of DECB's workspace at handover; §2L's text speaks only of a "memory limit". The amendment is not wrong —
   the floor is likewise a stage constraint and is governed by the same sentence — but a reader looking for
   the floor will not find it here.
2. **Name the routine that CALLS it.** The handover is `LOADM"…"` + `EXEC` from Disk BASIC; what ends the
   constraint is the port taking the machine — `HAL_sys_init` onward — after which reads go through
   `disk_read_init` / `disk_read_range`, which is how the screens, cel pages, scene program and now the music
   player all arrive.
3. **Grep the prior reports for the same subsystem.** Done: P3.3 (first ceiling hit), P3.5 (EXEC overwrite —
   a different handover fault), P3.22 (the measurement), P3.105 (the standing invariant this amendment
   promotes), P4.11 and P4.12 (the two misapplications the dispatch names), P4.19 (the third). **No
   contradiction between them** — P3.22's number and P4.19's are the same phenomenon measured two ways
   (§3C.1).

### 4 — Verification (AC-by-AC)

- **AC1 amendment committed at the next free letter, letter reported** — **PASS.** `2L`, reported in §1 and
  §3A, enumerated in §3A.
- **AC2 no conflict; if any section implies the ceiling is global, say so and reconcile** — **PASS.** Both
  other `LOADM` mentions are §4 launch-path statements (§3B). **Nothing in `CLAUDE.md` implies a global
  ceiling.** Reconciliation is that the two sections answer different questions; a cross-reference is
  *proposed, not made* (§2D).
- **AC3 no behavioural change to the port** — **PASS.** One file changed and it is documentation. Build run
  for AC4 only; suites green; no source, asset, link script or build input touched.
- **AC4 route accounting present; suites green; sync bridge green; Karateka untouched; `main` untouched** —
  **PASS.** §6; evidence in §5; `main` at `34e93e0`, unmoved.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output, verbatim.**

`build.bat` — the HAL-sync bridge (AC4) and the terminator:
```
[hal-sync] OK -- HAL source aligned with karateka_coco3 (11 files compared, EOL/guard/export-placement normalised)
=== BUILD COMPLETE ===
```

`harness/smoke/run_suites.sh` — 128 KB first (§2K):
```
[suites] === introseq ===
[run_introseq_test] PASS
[suites] === integ ===
[integ] PASS

[suites] ALL PASS
```

The change, in full:
```
git diff --stat CLAUDE.md
 CLAUDE.md | 16 ++++++++++++++++
 1 file changed, 16 insertions(+)

lines removed (superset check): 0
```

**25.2 bundled-artifact grep:** N/A — documentation change, no artifact.

**25.3 operator-runtime-smoke:** **N/A — documentation only, nothing to observe.** Not "pending Jay": there
is no runtime behaviour in this change to gate. The suites' live-disk runs above are the evidence that
nothing regressed.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING. This report contains** §1's amendment, verbatim, at `2L`; the AC2 conflict analysis; and
the AC4 verification. **It does NOT contain** any edit to §4, any change to the port, or any change to §2L's
supplied wording.

**★ I proposed one thing I did not do, and am naming it rather than leaving it in a paragraph:** a one-line
`(scope: §2L)` cross-reference at §4:344. **Proposed in §3B; NOT implemented**, because §2D assigns this
document's content to the Orchestrator and the dispatch supplied §2L only.

**Reactive deviations (§22.5): none.** The text was rendered as given; no reshaping.

### 7 — Uncertainty flags

- **★★ §2L DOES NOT MENTION THE FLOOR** (§3C.2/§3D.1). Its sentence covers it — the floor is a
  handover-moment constraint like the ceiling — but a reader searching for *"how low can a `LOADM` segment
  go"* will not find `$0E00` here, and P4.19 measured it the hard way. **Whether to fold it in is the
  Orchestrator's call.**
- **★ §2L's `$2488..$2535` is P3.22's figure and P4.19 suggests it is one instance rather than the rule**
  (§3C.1). The amendment is not wrong — it is quoting the measurement that exists — but a reader may design
  against `$2488` as a `prog`-end limit when the binding quantity is the whole image.
- **The claim itself is not independently re-verified in this dispatch.** It rests on P3.22's measurement,
  P4.19's truncation, and the fact that the port demonstrably loads screens, cel pages and the scene program
  after handover. That is strong, and it is not a fresh experiment.

### 8 — Follow-up candidates

- **The `(scope: §2L)` cross-reference at §4:344** — one token, Orchestrator's call.
- **Whether §2L should carry the FLOOR (`$0E00`) and the image-vs-`prog` correction** (§3C) — Orchestrator's
  call; the measurements are in P4.19's §3J.
- **Unchanged and still the nearest engineering item:** P4.19's probe track-32 read does not work, so neither
  the ear gate nor the headless fidelity check can currently be re-run. Then the intro wiring.

### 9 — User interaction during task

None during execution. The dispatch itself carries Jay's words (*"remind Clyde that the LOADM memory
restrictions only apply to loading the disk loader — after that they are no longer in play"*), and §1 records
that he had already said the same thing twice during P4.19.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-19-a-stage-constraint-recorded-without-its-expiry-becomes-a-global-one.md` —
committed and pushed to the pool.

### 11 — Commit

`e229b5e` (pushed to origin/wip before this report)
