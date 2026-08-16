## Form B Report — P3.96 — the scene DOES pack, and P3.95's "it does not" was my error

**Class:** build. wip. Prod untouched.

**★★★ I TOLD JAY THE CORRECTED CELS DID NOT FIT AND HANDED HIM THREE EXPENSIVE OPTIONS. They fit,
at today's 4 pages and ONE read, with the read in the same hold it already occupies. `cel_pack`'s
search is NOT MONOTONIC in its read-point argument, so a failure from one candidate set was never
evidence that no schedule exists — and I reported the tool's answer as a property of the scene.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-16T11:45:27-04:00 (HEAD `70c013c`, wip). Karateka untouched. `main` untouched. Oracle
source read-only. Pre-existing, not mine: `dist/mame-cfg/rgb/coco3.cfg`.

---

### 1 — Summary

| | |
|---|---|
| **★ the correction** | **P3.95's "does not pack" was wrong.** 4 pages, 1 read, 3 blocks — unchanged |
| **why** | `cel_pack`'s search is **non-monotonic**: `[1,6,10]` fails, `[1,6,10,13]` packs, all-beats fails |
| **the fix** | `bake_scene` searches candidate read-point sets; the safety property becomes an **assertion on the result** |
| **the cels** | eight `vcast-*` frames now from `IMG.CHTAB7` — 48-to-50 rows, not 13-row stubs |
| **margins** | exit **4,309 / 1,361 / 6,862** — essentially unmoved; entry **108,914**, unchanged |
| **cost** | scene mean **6.78 → 6.82 f/play**, landing on Vraise (improves), the glass hold and Vexit |
| **§3** | `chartable_audit.py` is now a **build guard**; nothing else in the project can see this class |
| **25.3** | **PENDING JAY** — offered, observed 82 s (the whole scene), no words |

### 2 — Files modified

- `harness/tools/bake_scene.py` — the read-point search + the scheduled-read assertion
- `harness/tools/chartable_audit.py` — from one-off diagnosis to build guard
- `harness/tools/gen_cel_table.py` — the +0 field's stale "into IMG.CHTAB6.A" corrected
- `harness/tools/pack_probe.py` — NEW; the numbers behind the decision
- `build.bat` — the guard wired in
- `content/cutscene/chars/**` — the eight corrected cels and the regenerated schedule
- `harness/smoke/run_room_live.sh` — banner

### 3 — Reasoning

**★ §2H's THREE CHECKS** (fifth dispatch prompted by the §7 pointer):

1. **A second mechanism serving a different object class?** The dispatch names the exact analogue:
   *is there a second FIELD the source pairs with the one being read?* **Yes, and I looked.**
   `ALTSET2` carries `Fdy` beside `Fdx`; the bake parses it, `gen_cel_table` emits it into the
   engine's table at **+2** — and **`vm_resolve` reads +0, +1, +3 and +4 and never +2.** So `Fdy`
   is carried the whole way and dropped at the last step, the same shape as `Fsword` one level
   along. **It is DORMANT, not live: all 55 cels this scene draws have `Fdy = 0`** — measured, not
   assumed. It becomes live the moment a scene uses a cel with a non-zero one, which the demo will.
   **Flagged, not acted on** (§7).
2. **The calling routine.** `read_beats` is consumed by `cel_pack.pack`, which uses it for **two
   different things** — where a page BOUNDARY may fall and where a READ may be issued. Reading the
   parameter name alone hides that; reading its uses is what showed the search could be widened
   without buying a second freeze.
3. **Grep the reports for the subsystem.** Done, and it is what caught me: P3.95's *"the scene
   needs another block or another read point"* is a **quotation of the packer's error string**, and
   I had promoted it to a finding. It is now corrected in this report rather than left to be cited.

**3A — ★★★ THE CORRECTION, FIRST.** P3.95 reported that the eight corrected cels do not pack and
offered Jay a second freeze, a fourth GIME block, or a re-encode. Measured this dispatch:

```
reads at [1, 6, 10]      (today's default)  ->  does not pack
reads at [1, 6, 10, 13]                     ->  PACKS: 4 pages, 1 read
every beat offered                          ->  does not pack
```

**Non-monotonic.** Offering *more* candidates makes it fail; offering exactly one more makes it
succeed. So "does not pack" from the default set says nothing about whether a schedule exists, and
the three options I put to Jay were unnecessary. **Nothing about the geometry had to change.**

**3B — THE FIX, AND WHY IT IS A SEARCH.** `read_beats` conflates a free property (a page boundary)
with an expensive one (a ~2.8 s transfer that can only hide in a long hold). `bake_scene` now
enumerates candidate sets smallest-first — the song holds, then those plus each single, pair and
triple of the non-song beats — and takes the first that packs. **The safety property moved from the
input to the result:** every read actually *scheduled* must land in a hold of ≥ 40 plays, and a
schedule that violates it is rejected and the search continues. A pack call is ~5 ms, so the search
costs seconds, and it is deterministic.

The schedule found is today's: **4 pages, one read, three blocks, the read still at beat 10
(`s_Buildup`, 56 plays)**.

```
cel_res 5,871 B   pg0 7,292   pg1 6,451   pg2 5,674   pg3 6,508
```

**3C — MARGINS, entry and exit separately, against the post-P3.93 baseline** (P3.92's were
provisional on `vb_tick` *and* measured with stubs — doubly out of scope):

| scene beat | cycles | **margin** | was |
|---|---|---|---|
| 16 | 115,127 | **4,309** | 4,246 |
| 17 | 118,075 | **1,361** | 1,365 |
| 18 | 112,574 | **6,862** | 6,988 |
| entry | 108,914 | unchanged | 108,914 |

Scene mean **6.78 → 6.82 f/play**. **The exit is untouched** — the corrected cels are not drawn
there. The cost lands where they are: **Vraise improves 7.00 → 6.00**, the glass hold goes 6.80 →
8.00 and Vexit 6.94 → 7.65. Net +0.04 f/play for cels roughly three times the footprint of the
stubs they replace.

**3D — §3: WHAT NOW VERIFIES THE TABLE CHOICE.** `chartable_audit.py` was the script that found the
bug; it is now a **build guard**. It computes `decodeim` from `CTRLSUBS.S` independently and
requires that the file `cel_parity_rule.table_path` would open agrees, for all 85 `ALTSET2` frames.

**Nothing else in the project could see this class, and that is worth stating rather than assuming
the new check was always needed.** A wrong-table bake produces a *well-formed file of a plausible
size holding real cel data* — so the assembler accepts it, the packer costs it, the link map
places it, and the pixel checkers compare the engine's output against the same wrong artifact and
agree. Every automated gate was green for the project's whole life. **Three live gates and Jay's
eye is what found it**, and his third description — *"except for his feet"* — is what made it
findable, because cels are stored bottom-up.

Also corrected: `gen_cel_table` emitted a header calling +0 *"image index into IMG.CHTAB6.A"*,
which has been false for eight cels since they were first baked.

### 4 — Verification (AC-by-AC)

- **AC1 pack reported** — **MET** (3A/3B): 30,424 B of segment stream, 4 pages, 1 read, 3 blocks;
  heaviest beat 6,502 B against a 7,680 B block, so no beat alone was ever the problem.
- **AC2 margins re-reported against the post-P3.93 baseline** — **MET** (3C).
- **AC3 nothing chosen if nothing is required** — **MET, and this is the substance**: no option was
  needed, and P3.95's three are withdrawn.
- **AC4 the runtime mirror re-measured if bytes are needed** — **N/A: bytes are not needed.** Not
  re-cited either; simply not reached.
- **AC5 coverage windows regenerated for the full cels** — **MET.** `verify_room_chars` recomputes
  its expected picture from the sources every run, so it is compositing 48-to-50-row cels; three
  captures (`cel80`, `cel83`, `cel84` at `top 94`) land on the corrected eight at 0 bytes wrong.
- **AC6 §2H's three checks; whether anything verifies the table choice** — **MET** (head of §3, 3D).
- **AC7 Jay gates live** — **OFFERED AND OBSERVED; NOT AFFIRMED.** §5.
- **AC8 route accounting; sync; Karateka; `main`** — **MET.**

### 5 — Verdict-time evidence (v0.7 §11)

**25.1** `=== BUILD COMPLETE ===`; `[hal-sync] OK`; `[harness-offsets] all checked offsets agree`;
`ok every ALTSET2 frame's table resolves to the file decodeim names`.
Room, both sizes: `checks=8 passed=8 failed=0`, `78 bytes byte-identical`.
Walk, both sizes: **44 captures, `0 bytes WRONG` at every one**, `beats_visited PASS (19 of 19)`,
`stability: all captures agree (0)`, `STABLE`.
Corrected cels confirmed in the image: `v78_src.s` 50 rows, `v85_src.s` 48 rows, header
`POP cel: #8 (3x48 bytes)`.

**25.2** N/A — ROM build.

**25.3 PENDING JAY.** Offered after the fix; `live-disk`, RGB; the run lasted **82 emulated seconds
at 100%** — long enough to cover the raise (~68 s), the turn (~72 s), her slump (~75.6 s) and the
terminal beat (~80 s), the fullest coverage of any run except the 179 s one. **No words received;
nothing recorded as passed.** Surfaced at the gate: the vizier whole through the end of the raise
and the start of the turn, and that **the load count and freeze are unchanged** — nothing was
traded for the fix.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING. The largest item is a retraction of my own.** P3.95 concluded the scene does not
pack and put three costly options to Jay. **That conclusion is withdrawn**; it was the packer's
error string promoted to a finding, and this dispatch's §1 — *"this may simply still fit — check it
first"* — is what made me check it rather than build on it.

Beyond the dispatch: I wired `chartable_audit.py` into `build.bat` (§3 asked whether anything
verifies the table choice; making the answer "yes" seemed better than reporting "no"), and I
corrected `gen_cel_table`'s stale header. Both are small and both are stated.

Not present: the runtime mirror (not reached — no bytes were needed); the `Fdy` drop (dormant,
flagged); the characters' per-iteration draw.

`hal-sync` OK. Karateka untouched. `main` untouched.

### 7 — Uncertainty flags

- **★★ `Fdy` is emitted into the engine's cel_table at +2 and `vm_resolve` never reads it.**
  Dormant here — all 55 cels this scene draws have `Fdy = 0`, measured — and **live for any future
  scene that uses a cel with a non-zero one.** Same shape as the bug just fixed, one level along.
- **★ The read-point search is a search over a heuristic, not a proof.** It finds *a* schedule; it
  does not establish that the packer's answer is optimal, and a future content change could make it
  fail again where a schedule still exists. The assertion on scheduled reads is what keeps a
  success safe; nothing keeps a failure honest.
- **The corrected cels have never been seen by Jay.** Everything about them is byte-comparison and
  arithmetic until he looks.
- **Beat 17's margin is 1,365 cy** and its peak still exceeds the boundary — unchanged by this work
  and accepted by Jay.
- Carried: the characters' per-iteration draw; 0.20 s driver overhead; `$2310..$2329` blindness;
  the scene is one page from a single load; sound sites stubbed as holds.

### 8 — Follow-up candidates

1. **Whether `Fdy` should be applied** — it costs a byte in the slot record and a `leay` in
   `co_setup`, and it is a live defect the moment the demo's cels are drawn.
2. **The characters' per-iteration draw**, if the torch repaint is ever revisited.
3. Sample the exit more densely if anything else changes there.

### 9 — User interaction during task

Jay: *"1. you'll have to find it. 2. no assets have been hand editied yet."* — authorising the
search and clearing §2B's re-conversion gate. Then *"do it"*, authorising the fix.

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-16-a-tools-failure-is-not-the-systems-property.md`

### 11 — Commit

`29be31c` (the cels + the search), the banner, and this report. Pushed to origin/wip.
