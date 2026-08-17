## Form B Report — P3.89 — two `CLAUDE.md` amendments: look past the first mechanism, and what fidelity mandates

**Class:** doc. wip. Prod untouched; `src/` byte-identical to `3725c62`.

**★ Both amendments committed at `2H` and `2I` — both letters were free. But "§2H" has been cited
across dispatches for a heredoc rule that IS NOT IN `CLAUDE.md` AND NEVER WAS, so that citation
now resolves to a real but unrelated section. Reported, not fixed.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-15T~16:50-04:00 (HEAD `3725c62`, wip). Karateka untouched. `main` untouched. Oracle
source not read this dispatch. `src/engine/char_draw.s` shows modified in `git status` with an
**empty `--numstat`** — a line-ending artifact from reverting P3.88's seeded test, not a change.
Also pre-existing and not mine: `dist/mame-cfg/rgb/coco3.cfg` (MAME rewrites it on exit).

---

### 1 — Summary

| | |
|---|---|
| **§2H** | *Look past the first mechanism* — three bounded checks, stated as producing §3 output |
| **§2I** | *The mandate is visual fidelity and play feel* — oracle mechanisms are evidence, not requirements |
| **letters** | **`2H` and `2I`, both free.** Sections now run 2, 2A–2I, 3 |
| **★ hazard** | the heredoc rule cited as "§2H" **does not exist in `CLAUDE.md`** — the citation now misresolves |
| **additions** | **two**, beyond the provided text, flagged for strike (§6) |
| **conflicts** | **none found** with §2, §2G or §4 — reconciliation stated rather than assumed |

### 2 — Files modified

- `CLAUDE.md` — new `## 2H` and `## 2I`; one pointer added to §7's Form B `### 3` template line

No `src/` change, no harness change.

### 3 — Reasoning

**3A — PLACEMENT, AND WHY THE LETTER MATTERS MORE THAN IT LOOKS.** `CLAUDE.md`'s sections ran
`2, 2A…2G, 3`, so `2H` and `2I` were the next free letters and are what I used.

**★ But the dispatch's own standing-invariants block cites *"file via `create_file`/`str_replace`,
NOT heredocs (§2H)"* — and there is no such rule anywhere in `CLAUDE.md`.** I grepped for
`heredoc`, `create_file` and `str_replace`: zero hits before this dispatch. So "§2H" has been a
**citation to a section that did not exist**, carried across dispatches, and as of this commit it
resolves to *"Look past the first mechanism"* — a real section that says nothing about file
writing.

That is the same family as the six instances §2H itself is about: a reference in the record
standing in for something that was never checked. It is now worse than a dangling citation,
because a dangling one fails loudly and a misresolving one does not. **The Orchestrator owns the
fix** (§2D) and the options are to give the heredoc rule a real section — `2J` is free — or to
stop citing §2H for it. **I did not place it myself; authoring `CLAUDE.md` content is not mine.**

**3B — HARD-STOP CHECK: DOES EITHER AMENDMENT CONTRADICT §2, §2G OR §4?** Checked against the
file, not against my memory of it. **No contradiction found.** Stating the reasoning rather than
just the verdict, because "I checked and it's fine" is the shape of a check that was not run:

- **§2** ranks Jay → trace → source → disassembly → comments as authorities on **what the oracle
  does**. §2I is about **what the port must reproduce**. Different questions; §2I re-ranks
  nothing and explicitly says so. §2's *"Trace wins on fact; source wins on intent"* is untouched.
- **§2G** is about reusing Karateka's *substrate* and is orthogonal — it never claimed oracle-
  mechanism-matching as a goal.
- **§4** makes Jay's eye on a running machine the gate. §2I strengthens it: if the mandate is that
  it looks and feels right, the visual gate is the mandate's own test, not a formality after it.

**★ The one place a careless reading COULD do damage** is §2F.1(6): *"Migration gate =
RENDER-NEutral (framebuffer-diff byte-identical). Any pixel change → STOP."* §2I says an
output-preserving divergence *"needs no justification beyond measurement"*, and a reader in a
hurry could take that as licence to ship a pixel change that "still looks right". It is not a
contradiction — *preserving visual output* means exactly no pixel change — but the two sit close
enough that I added a closing paragraph making it explicit. **That paragraph is an addition
beyond the provided text; see §6.**

**3C — §3 OF THE DISPATCH: STANDING LANGUAGE THAT CONFLATES THE TWO.** Swept `CLAUDE.md`, `src/`
and `reports/`. The conflation is **normative** language ("the oracle does X, *therefore* the port
should"), not **descriptive** language ("this mirrors the oracle's structure"), and the descriptive
uses in `char_draw.s` and `cutscene_room.s` are legitimate — they cite the oracle as evidence for a
design, which is exactly what §2I says it is. Reported, not edited:

1. **`reports/…p3-44-audit-and-peel.md:53`** — *"The port's peel is a CoCo3-side invention, not a
   ported model — **so** the largest component of the port's frame is paying for a mechanism the
   original never had."* The `so` is the conflation in one word: it treats *"the original never had
   it"* as a reason to remove it. Under §2I that inference is void independently of whether the
   premise was true. (It was also false — P3.88.)
2. **P3.88's own dispatch §2 table** — *"the peel | 40,191 cy | **faithful, or a port invention —
   §1 decides**"*. This makes a cost verdict contingent on provenance. Under §2I, §1 decides nothing
   about whether the peel should be made cheaper; measurement and output do.
3. **★ AND MY OWN P3.88 CORRECTION IS NOT CLEAN OF IT.** I wrote *"it is the right model and must
   not be removed on fidelity grounds."* The second clause is §2I-compatible; **the first is not.**
   "The right model" is a fidelity verdict standing in for a cost-and-output one. What it should
   say is that the peel produces the required output at a measured 40,191 cy, and that its
   provenance is irrelevant to whether that is worth paying. Flagged rather than re-edited — the
   retraction block is load-bearing as written and re-editing a correction twice in two dispatches
   is its own hazard.

**3D — WHAT I DID NOT FIND.** No standing language in `CLAUDE.md` itself treats oracle-mechanism-
matching as the goal. §2's title (*"real source is trusted"*) and §2G's reuse rules are about
authority and substrate, not about mandating the oracle's implementation. So the conflation lives
in **dispatch prose and report prose**, not in the standing rules — which is consistent with it
having gone unnoticed: nobody was reading a rule that said it.

### 4 — Verification (AC-by-AC)

- **AC1 both amendments committed, letters reported** — **MET.** `## 2H`, `## 2I`, commit
  `644717e`. Sections now run 2, 2A…2I, 3. Superset check run: all sixteen pre-existing headings
  still present, nothing dropped.
- **AC2 §2H's three checks stated as producing §3 output** — **MET** by the provided text
  (*"state their results in §3"*), and reinforced by a pointer added to §7's Form B `### 3`
  template so the report structure actually asks for them. **That pointer is an addition; see §6.**
- **AC3 §2I explicitly reconciled with §2's stack** — **MET** (3B), in §2I's own body: it clarifies
  what the stack is for and does not re-rank it.
- **AC4 conflating dispatch language reported, not edited** — **MET** (3C), three instances, one of
  them mine.
- **AC5 no behavioural change** — **MET.** No `src/` change; `char_draw.s`'s status flag is an
  empty-numstat line-ending artifact.
- **AC6 route accounting; suites; sync bridge; Karateka; `main`** — **MET** (§5, §6).

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output.** `[hal-sync] OK -- HAL source aligned with karateka_coco3 (11 files
compared, EOL/guard/export-placement normalised)`; `=== BUILD COMPLETE ===`.

Room: `PASS flame pixels are exactly cel 3/8 over the room: 78 bytes byte-identical`,
`[run_room_test] PASS`.

Walk: `STABLE: both runs walked the same positions and produced the same result`,
`[run_walk_test] PASS` — 36 captures including the eight on the hourglass added at P3.88, 0 bytes
wrong.

**25.2:** N/A — documentation change, no build artifact affected.

**25.3:** **N/A for this dispatch** — nothing reached the screen. The standing gate state is
unchanged from P3.88: **the flash is PASSED** (Jay, live-disk, RGB, 2026-08-15); the hourglass-
before-flash, the turn disappearance and the exit pace remain **open**.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING. Two additions beyond the Orchestrator-provided text, both flagged here for
strike or rewording rather than presented as rendering:**

1. **§2I's closing paragraph** — *"AND IT DOES NOT LOOSEN §2F.1 OR §4"*. My words, not the
   dispatch's. Reason in 3B: §2I's "needs no justification beyond measurement" sits close enough to
   §2F.1(6)'s "any pixel change → STOP" to be misread, and P3.87 shipped a change that failed
   exactly that gate. **Strike it if the Orchestrator prefers the text as drafted.**
2. **The §7 Form B pointer** — §2H's checks are only reached if the report template asks for them,
   and this project's history is largely checks that existed and were not reached. One clause added
   to the `### 3` template line.

§2I's *"THIS DOES NOT RE-RANK §2"* paragraph is **not** an addition — it is the dispatch's own §2
prose folded into the section, as AC3 requires.

**Not present:** any port behaviour change; the heredoc rule (not mine to author); any edit to
dispatch text; any re-edit of P3.44 or P3.88.

`hal-sync` OK. Karateka untouched. `main` untouched.

### 7 — Uncertainty flags

- **★ "§2H" now misresolves.** Dispatches cite it for a heredoc rule that is not in `CLAUDE.md`;
  it now names *Look past the first mechanism*. `2J` is free. **Orchestrator's to fix.**
- **§2I is a rule about judgement and cannot be mechanically checked**, unlike §2H's third check.
  Its first real test will be the first time a cheaper non-oracle mechanism is proposed — and the
  failure mode to watch is the opposite of the old one: reaching for a divergence *before*
  establishing what the oracle does, which §2's stack still forbids.
- **My P3.88 correction's "it is the right model"** is a fidelity verdict where §2I wants a
  cost-and-output one (3C.3). Not re-edited.
- Carried from P3.88: `scenery_frame`'s residue columns unexplained; the `vb_tick` flash/sand
  branch is source-derived and untraced; the glass capture window covers the beat's start but not
  the exit beats; `verify_room_chars`'s SRC keyed by cel number alone.
- Carried: the turn-to-exit disappearance; the exit pace (open, per Jay's scope correction);
  0.20 s per-call driver overhead; `$2310..$2329` read-tap blindness.

### 8 — Follow-up candidates

1. **Give the heredoc rule a real section, or stop citing §2H for it.**
2. **Trace the `vb_tick` branch** — still the cheapest open item with a result Jay has reported.
3. Re-state P3.88's peel conclusion in §2I's terms (output + cost, not provenance), if the
   Orchestrator wants the record clean rather than merely correct.

### 9 — User interaction during task

None. Jay's two quotes are carried in the dispatch and are folded into the amendments verbatim.

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-15-the-original-does-it-this-way-is-evidence-not-a-requirement.md`

### 11 — Commit

`644717e` (the amendments) and this report. Pushed to origin/wip.
