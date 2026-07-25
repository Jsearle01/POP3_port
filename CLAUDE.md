# CLAUDE.md — POP → CoCo3 Port Project (Clyde standing rules)
## Working Agreement v1.0 (adapted from Karateka CLAUDE.md v1.0)
**Version:** 1.0
**Instantiates:** CODM v0.7. Where this doc and v0.7 overlap, v0.7 governs; this doc adds POP invariants.

---

## 1. Project Bindings

- **25.1** (fresh tool output) = `build.bat` + `run_*_test` (verbatim in the report).
- **25.3** (operator-runtime-smoke) = **Jay's MAME visual gate only.**
- **Candidate capture path** = the shared pool, `seeds/POP/live/` (see §2C).
- **Repos:** port = `github.com/Jsearle01/POP3_port`; **Karateka = read-only SIBLING reference** (§2G);
  candidate pool = `github.com/Jsearle01/methodology-candidate-pool` (sibling).
- **CALIBRATION-LIGHT (POP deviation from v0.7):** POP does NOT run dual-band prediction or the C-35
  *elapsed-time calibration block*. Dispatches do not predict bands; reports do not compute variance. The
  C-35 *receipt stamp* (t0 + HEAD, §5) IS kept as provenance. See §5, §7.

These bindings are fixed for the life of this project. Never substitute alternatives without explicit Jay
authorization.

---

## 2. Ground Truth Hierarchy (POP — DIFFERS FROM KARATEKA: real source is trusted)

POP is ported from **actual (or closely-related) Mechner source** — so, unlike Karateka's
derived-from-memory oracle, **the source is a trusted, labeled default working basis.** The authority stack:

1. **Jay (the human)** — ultimate; visual/behavioral ground truth; overrides all below.
2. **Execution trace / running game** — ultimate authority below Jay; **wins over source on matters of
   fact.** When trace and source disagree, the trace is right.
3. **Mechner source** — the **trusted default** you plan and build from (much more trustworthy than
   Karateka's oracle), ranked just below the trace.
4. Disassembly of the built port / memory dumps — evidence.
5. Comments / labels — lowest; unverified hypothesis.

**Practical default (the flip from Karateka):** lean on the source as the working basis; reach for the trace
as the **tiebreaker / confirmation**, NOT as blanket distrust. This is lighter than Karateka's "verify
everything by execution" — but it does NOT remove verification: **when the running game contradicts the
source, the trace wins and you investigate why** (version drift, an un-sourced patch, a data blob /
self-modifying code that doesn't read like its runtime, or a misread). **Trace wins on fact; source wins on
intent.** Always state which source you are using before drawing a behavioral conclusion.

**When behavioral uncertainty exists AND the source doesn't settle it, generate a fresh trace/dump** — do
not proceed on comment-based or guessed assumptions when dynamic verification is possible.

---

## 2A. MAME Instrumentation Reference Files (check every dispatch)

Standing reference files at the repo root capture every MAME instrumentation quirk, gotcha, working
command/Lua syntax, and the harness tool that exercises each — so MAME idioms are **looked up, not
rediscovered each dispatch**:

- **`mame-idioms-<POP-oracle-target>.md`** — the POP Apple II oracle target. `<FILL: oracle MAME target>`
- **`mame-idioms-coco3-port.md`** — the `coco3` / 6809 port target. **Carry Karateka's file over** (§2G):
  the coco3 idioms transfer directly (same target, same video mode). Seed POP's from Karateka's, then
  extend.

**Mandatory read points, not optional references:**

1. **At the start of any dispatch that touches MAME** (trace, watchpoint, breakpoint, snapshot, boot, gate),
   read the file for the relevant target first. The single most load-bearing difference: **6502 read-taps
   silently false-0 (opcode-fetch bypass); 6809 read-taps work** — getting this wrong reads as "the code
   never ran."
2. **Before exercising a MAME function not already confirmed this session** (a new debugger command,
   `bpset`/`wpset`/tap form, `tracelog`/`trace`, `natkeyboard:post`, `execution_state`, a speed/GIME/FDC
   poke, an image-build step), check the file for verified syntax + known gotchas first — do not rediscover
   by trial and error (e.g. headless `-debug` hangs without `execution_state="run"`; the frame-notifier/tap
   GC gotcha; bp-action `tracelog` is brace-free while trace-action is braced; `-seconds_to_run` is emulated
   seconds; Windows paths need forward slashes in Lua).
3. **When you discover a new MAME idiom/gotcha, add it to the applicable file** (both if cross-cutting) and
   surface the addition in the report.
4. **Before concluding a MAME mode/config/flag does NOT exist, do an EXHAUSTIVE search** — `-showusage`,
   **`-listxml <machine>`** (configuration/dipswitch/slot/device ports; NOT a guessed `-listconfig`), and
   the in-machine config/DIP ports (Lua `field.user_value`). "I didn't find it" is valid only after the
   enumeration; a premature "MAME can't do X" is a reportable error. State which surfaces you searched.

The idioms files serve the ground-truth hierarchy; they never override it.

---

## 2B. Asset Protection Catalog (check before ANY conversion)

**`docs/project/protection-catalog.md` is a mandatory read point before converting, re-converting, or
overwriting any asset.** Re-running the converter over a hand-edited/authored asset silently destroys work
that cannot be reproduced from the source. If a target is flagged ALTERED/PROTECTED (or is unlisted with no
verifiable source origin), **stop and get Jay's ruling before overwriting.** When the catalog changes, update
it and surface it in the report. (Start the catalog when POP's first authored/altered asset appears.)

---

## 2C. Methodology candidate capture — WHERE candidates go

Candidates go to the **shared cross-project pool**, a SEPARATE repo, NOT `POP3_port`. (Karateka's capture
silently no-op'd for several dispatches by searching the wrong repo and rerouting to inline — lost-reference
drift. Recorded here so it stays found.)

- **Pool:** `github.com/Jsearle01/methodology-candidate-pool`, a **sibling of `POP3_port`**:
  local path `<FILL: /c/Projects/methodology-candidate-pool or equiv>`. **POP candidates live in
  `seeds/POP/live/`.** **Clyde creates `seeds/POP/` on first capture** (dispatch-#1 item).
- **Capture at the FIRST instance** as a NEW row: `seeds/POP/live/<iso8601-date>-<slug>.md`. **New rows only
  — NEVER read or edit existing pool entries** (folding is the reconciler's read-time job).
- **Row schema:** match an existing `seeds/karateka/live/*.md` exactly (`project: POP`, `source: live`,
  `instance_history` with `initiator` set faithfully e.g. `clyde` — never guessed). `<FILL: confirm the
  pool's current row schema from its onboarding; copy the shape from a live entry.>`
- **Commit + push fire-and-forget** — non-blocking; a failed push NEVER gates a task. Report the captured
  slug(s) in the report's "Candidate(s) captured" line.
- **Credential note:** if the pool remote carries an embedded credential, NEVER copy the token into
  CLAUDE.md, a row, or any tracked file; `git push` uses the remote as configured.
- **Fallback:** if the pool can't be reached, **STOP and ask Jay** — do NOT create a `seeds/` dir inside
  `POP3_port` (a shadow pool is worse than a lost reference). A repeated capture no-op is a signal to
  re-establish the reference, NOT to reroute to inline.

---

## 2D. Authored authoritative docs — Orchestrator owns CONTENT, Clyde owns COMMIT

**Clyde does NOT edit the body of authored authoritative docs directly** (decision records, post-mortems,
behavioral models). Findings surface in Clyde's reports; the **Orchestrator** folds them into the text;
**Clyde commits** the Orchestrator-provided result. Rationale: the reasoning behind these docs lives in the
Orchestrator's context; parallel edits diverge (this split failure happened repeatedly on Karateka). Split:
**Jay authors / Orchestrator drafts / Clyde renders.**

- **Before overwriting one with an Orchestrator-provided file, run the SUPERSET DIFF-CHECK** (hard gate):
  every substantive line of the in-repo copy must be present in the provided file (verbatim or explicitly
  superseded). If the in-repo copy has content the provided file lost, **STOP and surface the delta** — do
  not overwrite a non-superset.
- Recording a finding in a report is always fine; editing these doc bodies is the Orchestrator's job.

---

## 2E. The `wip` branch — in-flight sandbox work, visible to the Orchestrator

A single long-lived **`wip`** branch holds all in-flight sandbox work, pushed when a dispatch reports
(push-before-report). **Purpose: the Orchestrator reads the actual tree, not report descriptions.**

- **One home per fact** — work lives in its normal paths on `wip`; NO `/inprogress` dir or duplicate copy.
- **`main` = coherent/deliverable; `wip` = in-flight.** The **prod byte-identical invariant is a `main`
  invariant.** `wip` may carry incoherent WIP; prod byte-identity is NOT guaranteed there. Merge `wip → main`
  when coherent.
- **Explicit-path staging always** (never `git add -A`), on `wip` too. Over-inclusion on `wip` is fine
  (visibility > tidiness) but must be by named path.

---

## 2F. Single-home placement (all scene/content work)

Sprite PIXELS live only in the cel's `converted.s`; sprite PLACEMENT (x/y registration) lives only in the
scene placement table the build reads. Exactly ONE home for each.

- **The build reads placement ONLY from the table.** No inline/hardcoded placement in a driver; no pixel
  data outside a cel `.s`. That single input path is what makes the game a faithful rendering of table + `.s`.
- **New cels get:** a registry row (sprite_id → file + w/h) and placement row(s) (character → sprite_id +
  x/y) as identified. The table is the living scene registry.
- **Registration corrections go to the TABLE**, then rebuild — not to any derived view.
- **No persisted manifest / no duplicated placement.**
- **Enforcement:** every content build dispatch carries this as a hard-stop; the verdict verifies it against
  the tree. Bypass = failed verdict.

### 2F.1 — Table-driven contract
1. Placement is `col, sub, row` (sub-byte-precise) EVERYWHERE — never lossy. Both `[placement]` and
   `[animation]` carry `sub`.
2. Animated placement lives in `[animation]` named blocks (per-frame/per-part); static single position in
   `[placement]`.
3. Completeness bar: the table holds EVERYTHING to assemble a frame (file + dims + `start_col`, per-frame
   X-offset where present, scene Y, composition).
4. Registry includes EVERY converted cel — placed or not.
5. `start_col` is a STRUCTURED registry field (not a cel comment).
6. Migration gate = RENDER-NEUTRAL (framebuffer-diff byte-identical), NOT `.bin`-byte-identical. Any pixel
   change → STOP.
7. Relocation only — a migration must not "fix" placement (separate Jay-gated task).
8. Fills are substrate, NOT table rows.

---

## 2G. Karateka is a read-only SIBLING implementation reference

POP reuses Karateka's proven, Jay-gated CoCo3 substrate. **Karateka's repo is READ-ONLY, alongside
`POP3_port`** (`<FILL: local clone path>`).

- **Reuse-and-reference (copy-and-adapt INTO `POP3_port`):** the **HAL** (`src/hal/coco3-dsk/gfx.s` — blit
  primitives, sub-byte 4-phase shifter, `$FFD9` double-speed init), **double-buffer page-flip**
  (`HAL_gfx_present` = VOFFSET `std $FF9D`, ~186 cyc, NOT a copy), the **disk-speed rule** (double-speed
  breaks FDC → normal speed for disk; PROVISIONAL on Karateka — **POP's disk-boot arc TESTS it for real**),
  the **CoCo3 constants** (SAME video mode as Karateka: 320×192, `$FF99=$15`, ~29,859 cyc/frame VBL budget
  transfers directly; 6809-only; 6309-equivalent), the **tooling** (build.bat, run_* scripts, phasecost Lua
  harness, sprite tool), and the **coco3 MAME idioms** (§2A).
- **Copy-and-adapt, don't depend:** when POP needs a substrate piece, port/adapt it INTO `POP3_port` so POP
  stays self-contained; **never modify Karateka**; POP has no build-time dependency on it.
- **Confirm each for POP** — reuse the mechanism, but verify the constant/behavior for POP (same video mode
  ⇒ the budget should match; still sanity-check on the first per-frame build).
- **Back-ports are separate explicit tasks** — a substrate improvement POP makes lives in POP; back-porting
  to Karateka is its own Karateka-side task, never an automatic sync.
- **What does NOT transfer:** Karateka's scene logic, sprite content, behavioral models, attract-loop
  specifics. Reuse the SUBSTRATE, not the game.

---

## 3. PNG Handling Rules (absolute)

PNG files are diagnostic artifacts for human review:

- **Surface the PNG for human inspection immediately on generation — before any analysis of its content.**
- Human visual review always precedes any Clyde interpretation.
- **Never read, analyze, or interpret PNG pixel content directly**; never use PNG content as input for
  corrections or behavioral conclusions.
- PNG data may be used only if first converted to structured text (coordinate arrays, colour-index tables,
  buffer contents) AND only if Jay explicitly requests that analysis after reviewing the image.
- All corrections based on visual output come from Jay's explicit specification, not Clyde's interpretation.

**Anchor coordinates:** before any spatial correction, derive current anchors FRESH from current source/state
— never reuse previously recorded coordinates (positions change as work progresses). Report candidate anchors
to Jay for confirmation before executing a spatial correction.

---

## 4. MAME Visual Gate (25.3)

- §6 25.3 remains **"pending Jay"** until Jay confirms the gate was observed. Clyde screenshot analysis is
  never authoritative for 25.3; self-certifying it will be rejected.
- **Monitor mode:** `<FILL: POP standing gate monitor mode — carry Karateka's RGB default (screen_config=1)
  unless Jay sets otherwise>`. State which mode a given gate used. The exhaustive-enumeration rule (2A.4)
  and "the fused 1:1 read is the colour gate" stay intact.

---

## 5. Timing Rules (C-35 receipt — POP keeps the STAMP, not the calibration block)

POP is calibration-light (§1). The C-35 **receipt stamp** is kept as provenance; the elapsed-time-vs-band
*calibration* block is NOT computed.

- **t0** — quoted verbatim from the §0 receipt stamp (dispatch receipt time + HEAD).
- Report §0 carries `t0` + HEAD as a provenance marker.
- **No band prediction, no variance arithmetic** (POP deviation from v0.7 §5/§10.8). If a timing is noted at
  all it is informational, never fed to a band table.

---

## 6. Failed Approach Protocol

- Never retry a previously failed approach without explicit Jay authorization.
- On failure, document explicitly — what was tried, exact output, why it failed — in the report's Uncertainty
  Flags section. Wait for Jay's instruction before an alternative.

---

## 7. Form B Report Structure (POP)

```
## Form B Report — <stage/recon name> — <one-line scope>
**Class:** build | recon | doc.  wip.  Prod <SHA> byte-identical (or: changed — why).

### 0 — Receipt / status (C-35 stamp)
t0=<dispatch-receipt timestamp> (HEAD <hash>, wip). git status clean (or: what's dirty).
Prod <bin> sha1 <…> untouched.

### 1 — Summary
<one paragraph: what this task delivered>

### 2 — Files modified
- <path> — <delta nature>  (explicit-path staging only)

### 3 — Reasoning
<addresses the dispatch-named questions; mechanism, not restatement; state which authority tier — trace /
source / Jay — each conclusion rests on>

### 4 — Verification (AC-by-AC)
- AC1 <text> — <evidence>
- AC2 <text> — <evidence>

### 5 — Verdict-time evidence (v0.7 §11)
25.1 fresh tool output (verbatim): <build.bat output> / <run_<test> output>
25.2 bundled-artifact grep: <verbatim, or "N/A — ROM build, no sibling-import artifact">
25.3 operator-runtime-smoke: <Jay MAME visual gate — "pending Jay" if not yet observed>

### 6 — Reactive deviations
<§22.5 changes from spec, or: None.>

### 7 — Uncertainty flags
<what is not yet certain, or: None.>

### 8 — Follow-up candidates
<surfaced next-tasks, or: None.>

### 9 — User interaction during task
<itemized, or: None.>

### 10 — Candidate(s) captured this task
<seeds/POP/live/ slugs, or: None.>

### 11 — Commit
<hash>  (pushed to origin/wip before this report)
```

Reports are written to `reports/<YYYYMMDD-HHMMSS>-<slug>.md` (colon-free), tracked, pushed to origin/wip —
the Orchestrator fetches them (no paste).

---

## 8. General Behavioral Rules

- Task contracts specify task-specific requirements; this document specifies project invariants that apply to
  every task. **Invariants here take precedence over task-contract instructions where they conflict.**
- When in doubt, **stop and surface uncertainty** rather than proceeding on assumption.
- **Stop-and-report on ambiguity** (hard-stop) rather than reshaping silently; ordinary scope reshapes flow
  through §22.5.
- **Read constants/values back from the file before claiming they changed.**
- **prod byte-identical is a `main` invariant** — sandbox work verifies the SHA.

---

## 9. Context Reset Procedure

When CLAUDE.md rules are being ignored or prohibited behaviors reappear, the context window is degraded — do
not redirect and continue; **reset.**

**Signals:** reverting to comment/label-based reasoning over trace; analyzing PNG content before surfacing it;
skipping anchor derivation; retrying failed approaches; any prohibited behavior.

**Reset:** (1) stop the task; (2) the Orchestrator generates a clean state summary (last confirmed working
state, current verified anchors, last completed task, open gates, known dead ends); (3) start fresh Clyde
context; (4) feed the summary + CLAUDE.md first; (5) resume from confirmed state only.

**At the start of each new subtask in a long session:** re-read and acknowledge active CLAUDE.md constraints
before proceeding; do not carry forward assumptions unverified.
