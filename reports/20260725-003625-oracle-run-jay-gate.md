## Form B Report — Oracle run + Jay's visual gate — Phase 0 behavioral gate OBSERVED AND PASSED
**Class:** operator run + doc. wip. **Prod byte-identity: N/A** — no prod binary yet. The oracle `.hdv` is a gitignored build artifact, not a prod binary.

> **Headline: Jay ran the oracle and gated it "looks good" (2026-07-25).** That is the Phase 0 behavioral gate (backlog §7.1) — the first time POP's oracle has been observed running. The canonical `.hdv` mount is now **POP-verified** and recorded in the idioms file. Phase 0 *close* is the Orchestrator's to declare (§2D); this report supplies the evidence.

---

### 0 — Receipt / status (C-35 stamp)

**There is no dispatch receipt for this work, and I have not fabricated one** (§10: never fabricate a C-35 receipt). This was requested by Jay directly in conversation ("run the oracle" → "try again" → "looks good" → "update the report"), not by a dispatch, so no `t0` receipt stamp exists.

The nearest **evidenced** anchors:
```
t0=2026-07-25T04:07:26Z          <- verbatim, but that is the P1.2 RE-DISPATCH receipt (report 74ec1b4),
                                    NOT a receipt for this work. Quoted only to bound the interval.
report-composition stamp: 2026-07-25T04:36:24Z   <- captured live at report time; not a dispatch receipt.
```

**HEAD at report time:** `90cc27726476601759e9143981748a8ca6b78d18` (branch `wip`).
**HEAD at the start of this work:** `74ec1b43bd090dd4826b6f7bed2e2771e772e939` (the P1.2 hard-stop report).

**`git status`:** no tracked file modified, nothing staged. 17 untracked — the standing 16 under `docs/ground-truth/` (Jay's P1.0 ruling) plus `POP-idioms-coco3-markers.md` (spent P1.2 companion spec, still unruled).

Calibration-light per CLAUDE.md §1/§5. No elapsed computed, no band, no variance.

---

### 1 — Summary

Jay asked for the oracle to be run. It took two attempts, and the first one could not run the oracle at all.

**Attempt 1 — the `.hdv` was unmountable.** CLAUDE.md v1.1 §2A's predicted invocation is exactly right in shape: `-sl7 cffa202` genuinely does create a `harddisk1 (hard1)` instance that accepts `.hdv` natively. But the CFFA2 card carries its own device firmware (`cffa20ee02.bin`, romset `a2cffa02`) which was **absent from the MAME install**, so the machine died before boot. An exhaustive enumeration (§2A.4) established that **every** hard-disk card on `apple2e` was ROM-blocked in this install, so this was not a "pick a different card" problem. Rather than hand Jay a dead window I ran the 5.25" `.nib` pair on the built-in Disk II — which needs no extra ROM — and said plainly that it was **not** the oracle.

**Attempt 2 — the real oracle.** Jay supplied `a2cffa02.zip` (verified `romset a2cffa02 is good`). The canonical mount then worked first time, and Jay observed it and gated it **"looks good"**.

Two things were then recorded. Per §2A.3 (discovered idioms go into the applicable file) I added a **§0 "POP ORACLE MOUNT — VERIFIED FOR POP"** section to `mame-idioms-apple2e-oracle.md` — the first POP-verified content in a file that otherwise carries the inherited-unverified banner, which **stays**, with §0 stating explicitly that it covers only itself. And a line-ending error I made while writing that section is reported in full in §6.2, because the fix I applied was itself the remedy from a pool candidate written one task earlier — the remedy turned out to be unsafe in this case.

---

### 2 — Files modified

**`90cc277`** — `mame-idioms-apple2e-oracle.md`: new §0 inserted before §1. **Pure insertion: 48 lines added, 0 removed** (`git diff --cached --numstat` → `48  0`). Banner intact. Working-tree sha1 `6d462772…` → `fd107800…`; 715 → 763 lines. See §6.2 for the line-ending caveat attached to that working-tree hash.

**Not modified:** nothing else. No engine, HAL, content, or oracle-source change. No rebuild — the `.hdv` on disk is the P1.1 artifact, unchanged, still hashing `c4f0b13e49b77dd0fbc5063e27e53a24`. `/c/mame` was not modified by me; Jay added `a2cffa02.zip` himself.

**Pool repo:** two new `live/` rows — `56fbf7f` (from the P1.2 re-dispatch halt) and `824fc77` (§6.2's correction). §10.

---

### 3 — Reasoning

**Authority tiers, explicitly.** The mount findings rest on **direct tool output** (MAME's own `-listslots`/`-listmedia`/`-verifyroms` and its fatal-error text). The verdict that the oracle *runs correctly* rests on **Jay** — tier 1, above everything (CLAUDE.md §2, §4; 25.3 is Jay's MAME observation only). **No visual claim in this report is mine.** I never characterized what was on screen, before or after his verdict; the machine-level facts I do assert (exit code, speed, duration) are not visual claims and are not offered as a substitute for one.

**Why the enumeration mattered rather than being ceremony.** §2A.4 forbids concluding "MAME can't do X" before an exhaustive search. Had I stopped at the first failure the conclusion would have been "the CFFA2 path is broken", which is wrong in a way that would have cost real time later. What the enumeration actually established is narrower and far more useful: the *invocation is correct and the capability exists*; only a data file was missing. That converts an apparent dead end into a one-file fix — which is exactly what Jay then did.

The surfaces searched, per §2A.4's requirement to state them: `-listslots apple2e` (slot names `sl1`–`sl7` and their options), `-listmedia apple2e` (base machine), `-listmedia` **again with a card inserted** (the decisive one), `-verifyroms` on each candidate romset, and an actual short run per storage card to capture its real failure text.

**The trap that would otherwise bite every future dispatch.** `mame -listmedia apple2e` on the bare machine reports only `flop1`, `flop2`, `cass` — **no `hard1` at all**. Read naively that says the target cannot take a hard-disk image, which is false. The instance only materializes once a CFFA2 card occupies a slot:
```
$ mame apple2e -sl7 cffa202 -listmedia
apple2e   harddisk1  (hard1)   .chd  .hd  .hdv  .2mg  .hdi
```
So on this target the enumeration must be run **with the card inserted** or it returns a confidently wrong answer. That is now §0's second bullet.

**Why the 5.25" fallback was offered but explicitly not called the oracle.** Both `.nib` images and the `.hdv` are built from the same `obj/`, so it is the same assembled game — but per `PROVENANCE.md` the oracle (tier 1a) is specifically the 3.5" `.hdv`, and the two `.nib` images are precisely the artifacts that **mismatch** the Phase 0 reference md5s (P1.1 §6.1, divergence localized to `crackle`'s `nib_5.25` encoder). Presenting them as "the oracle" would have quietly substituted a known-divergent artifact for the graded one. They were run and labelled as a stopgap, with that caveat stated before Jay looked at it.

**Why a headless validation preceded each windowed launch.** A missing device ROM is a **fatal-before-boot** error — invisible to any check that only inspects the media path, and indistinguishable from "the game is broken" if the operator meets it as a dead window. A 5-emulated-second `-video none` run costs seconds and returns a precise diagnosis instead. This is now recorded in §0 as a reusable idiom, and it is what turned attempt 1 from a mystery into a named missing file.

---

### 4 — Verification

No dispatch, so no AC list. Verified against what was actually done:

**V1 — the oracle image is the byte-exact P1.1 artifact.** `md5sum oracle/source/PrinceOfPersia_3.5.hdv` = `c4f0b13e49b77dd0fbc5063e27e53a24`, matching the Phase 0 Linux reference in `PROVENANCE.md`. Checked immediately before the run, so what Jay observed was the reference-identical oracle.

**V2 — the CFFA2 firmware is present and good.** `mame -verifyroms a2cffa02` → `romset a2cffa02 is good. 1 romsets found, 1 were OK.`

**V3 — the mount is valid (headless pre-check).**
```
$ mame apple2e -sl7 cffa202 -hard1 <hdv> -video none -sound none -nothrottle -seconds_to_run 5
Average speed: 1269.67% (4 seconds)
EXIT=0
```

**V4 — the operator run completed cleanly.**
```
launching THE ORACLE: mame apple2e -sl7 cffa202 -hard1 PrinceOfPersia_3.5.hdv -window -nomax -prescale 3
Average speed: 99.89% (190 seconds)
EXIT=0
```
190 s at ~100% speed, exit 0 — no crash, no fatal error, no emulation fault. **This is a machine-level statement only.**

**V5 — Jay's visual gate.** Jay observed the run and stated **"looks good."** Recorded verbatim. This is the 25.3 gate and the Phase 0 behavioral gate; it is his call and is reported, not interpreted.

**V6 — the idioms edit is a pure insertion.** Content diff (line endings normalized) against `HEAD`: **1 hunk, 0 removed lines**. Committed diff `48 insertions, 0 deletions`. Banner verified still present at the head of the file. `grep -c 'INHERITED FROM'` unchanged.

**V7 — nothing else moved.** No rebuild, no oracle-source change, no engine/content work, no edit to `mame-idioms-coco3-port.md` or `mame-idioms-addendum.md`, and the probe clone and Karateka untouched.

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output — APPLIES (tool runs, not a build).** No `make` was run and no artifact was produced, but this task's substance *is* fresh tool output. Verbatim MAME output quoted in V2/V3/V4 and Appendix A. There is still no `build.bat`/`run_*_test` in the repo (CLAUDE.md §1 binds 25.1 to those).

**25.2 bundled-artifact grep — N/A.** Nothing compiled, assembled, or imaged; no sibling source imported. Nothing to grep.

**25.3 operator-runtime-smoke — SATISFIED, by Jay.** Jay ran the oracle live under MAME and gated it **"looks good."** Per CLAUDE.md §1 and §4 this is the only form 25.3 can take, and it is not self-certifiable by me. **Monitor mode:** CLAUDE.md §4's standing RGB / `screen_config=1` binding is a **coco3** setting; the `apple2e` target has no such control, so it does not apply to this gate — stated because §4 requires saying which mode a gate used.

**C-35 presence check (calibration-light) — SATISFIED WITH A CAVEAT.** §0 carries HEAD at start (`74ec1b4`) and at report time (`90cc277`). It does **not** carry a dispatch `t0`, because none exists — this work was requested conversationally. §0 says so explicitly rather than substituting a fabricated or borrowed stamp. No elapsed, no band, no variance.

**Capture presence check (habit, not a gate) — SATISFIED.** §10 carries two slugs.

---

### 6 — Reactive deviations

**6.1 — The oracle could not be run on first request; a labelled substitute was run instead.**
The `.hdv` mount died with `cffa20ee02.bin NOT FOUND (tried in a2cffa02 apple2e)` / `Fatal error: Required files are missing`. The full enumeration found every `apple2e` storage card ROM-blocked in this install:

| card | missing ROM |
|---|---|
| `cffa202` | `cffa20ee02.bin` (set `a2cffa02`) |
| `cffa2` | `cffa20eec02.bin` (set `a2cffa2`) |
| `a2sd` | `appleiisd.bin` |
| `corvus` | `a4.7.u10` |
| `focusdrive` | `focusrom.bin` |
| `zipdrive` | `zip drive - rom.bin` |
| `booti` | exposes no `hard1` at all |

`/c/mame/roms` held only `apple2e.zip`, `coco3.zip`, `coco3h.zip`, so no other system was available either. I ran the 5.25" `.nib` pair on the built-in Disk II as a stopgap and stated **before** Jay looked at it that it was not the oracle and that those two images are the md5-divergent ones. Jay then supplied `a2cffa02.zip` and attempt 2 ran the real thing. Recorded because the failure is environmental and will recur on any fresh MAME install.

**6.2 — I flattened `mame-idioms-apple2e-oracle.md` from CRLF to LF while inserting §0 — using the remedy from my own prior pool candidate.**
Writing §0, I took the baseline from `git show HEAD:<path>` — precisely the fix prescribed in the P1.2 candidate `read-back-the-bytes-not-the-text-after-a-programmatic-edit`, written one task earlier. It hashed `56cef5eb…` against the `6d462772…` that **both** P1.0 and P1.2 had recorded for that file. Investigating rather than assuming a stale record found the cause:

```
working file : 52,099 bytes, CRLF
git blob     : 51,392 bytes, LF
delta        :    707 bytes across 715 lines = one CR per original line
```

The file was in fact **mixed** — 707 CRLF lines from Jay's original plus 8 LF lines from the P1.0 banner — a state git cannot reproduce from either side. Rebuilding it as `blob + section` flattened all 715 lines to LF.

**Damage assessment, and it inverts the obvious reading.** The working tree really was rewritten, but the **committed** diff is `48 insertions, 0 deletions` — git normalizes both sides to LF on add, so history received exactly the intended change and nothing else. The only casualty was working-tree byte-identity with a recorded sha1sum of a mixed-ending artifact git never preserved. Ending up LF-consistent is arguably better than the mixed state it replaced. I did not attempt to reconstruct the mixed endings: they are not reproducible from git, and doing so would trade a tidy state for a fragile one.

**The generalizable point** is that the earlier candidate's advice is unsafe as stated: `git show HEAD:<path>` is the wrong baseline whenever working tree and blob differ by normalization. Per the never-edit-existing-entries rule I filed a **new** row correcting it rather than amending the old one (§10). The safe baseline for a working-tree edit is a byte copy of the working file, with git as cross-check — and `git diff --cached --numstat` is the right place to ask "what actually lands".

**6.3 — I edited an idioms file without a dispatch authorising it.** CLAUDE.md §2A.3 is a standing instruction ("when you discover a new MAME idiom/gotcha, add it to the applicable file and surface the addition in the report"), and §2D's Orchestrator-owns-content rule names *decision records, post-mortems, behavioral models* — not the idioms reference files, which §2A explicitly assigns to Clyde to extend. I judged §0 to fall under §2A.3 and am surfacing it here as that clause requires. **If the Orchestrator reads the idioms files as §2D-owned, this edit should be reverted and re-authored** — it is one commit (`90cc277`) and a clean revert.

**6.4 — The banner was deliberately NOT lifted.** §0 is POP-verified; nothing else in `mame-idioms-apple2e-oracle.md` has been re-tested against POP's oracle. The whole-file inherited-unverified banner therefore stays, and §0's opening sentence says it covers only itself. Lifting it would have been the tempting and wrong move — one verified section is not a verified file.

**6.5 — `-speed 8` from the §11 operator idiom was deliberately not copied.** That idiom is Karateka's fast-forward for reaching a known scene. For a first-boot observation, normal speed is correct; the runs used `-window -nomax -prescale 3` only. Noted because copying the idiom verbatim would have had Jay watching an 8× boot.

**6.6 — A focused MAME window leaks host keys into the emulation** (§10a ZERO-KEYBOARD note). Harmless here — a live operator run is exactly where keyboard input is wanted — but it means these runs are **not** valid as attract-mode reference captures. Flagged so a later capture task does not reuse this invocation.

---

### 7 — Uncertainty flags

1. **"Looks good" is the gate as given.** Jay observed the run and passed it. I did not ask, and am not assuming, how far into the game he went or which beats he saw. If the gate was meant to cover a specific arc (title, attract, first level), that scope is not recorded and only he can state it.
2. **Phase 0 close is not declared here.** The gate is observed and passed; declaring Phase 0 closed is a decision-record act, which is the Orchestrator's under §2D.
3. **`a2cffa02.zip` is an environmental dependency now, and it is untracked.** It lives in `/c/mame/roms`, outside the repo, and is not reproducible from it. Any fresh machine or MAME reinstall re-blocks the oracle. §0 records the requirement, but nothing enforces it.
4. **Only the mount is POP-verified** (§6.4). Every other claim in the oracle idioms file remains inherited-unverified.
5. **The 5.25" `.nib` divergence remains open** (P1.1 §6.1). Attempt 1's run is weak evidence the divergence may be benign — the images booted and Jay did not report the substitute as broken — but he gated the `.hdv`, not the `.nib`, so **this does not resolve it** and should not be recorded as having done so.
6. **POP still has no line-ending policy** (§6.2, and the deferred `.gitattributes` task). This has now bitten twice in two sessions, in two different ways.

---

### 8 — Follow-up candidates

1. **Orchestrator: declare Phase 0 closed** (or state what else the gate needs) — the behavioral gate is passed and evidenced (§4 V5).
2. **Rule on §6.3** — whether idioms-file edits are Clyde's under §2A.3 or Orchestrator-authored under §2D. Cheap to reverse now (`90cc277`).
3. **The POP-level `.gitattributes` / `core.autocrlf` task** — priority raised again by §6.2; twice bitten.
4. **Record `a2cffa02.zip` as an environment prerequisite** somewhere enforceable (§7.3) — a setup note, or a harness pre-flight check.
5. **Dispose of `POP-idioms-coco3-markers.md`** — still untracked at the repo root, still unruled (P1.2 §6.3).
6. **Optionally root-cause the 5.25" `.nib` divergence** (P1.1 §6.1) — still low priority; the `.hdv` is the graded artifact and now has a passed gate.
7. **Substrate-adoption dispatch** (§2G) — the natural next step now that the oracle is observable.
8. **`build.bat` / `run_*_test`** — CLAUDE.md §1 binds 25.1 to them; neither exists yet.

---

### 9 — User interaction during task

Four exchanges, all Jay-initiated; this work exists because of them and was not dispatched.

1. **"run the oracle"** — I read `mame-idioms-apple2e-oracle.md` first (§2A mandatory read point), enumerated the mount, hit the missing CFFA2 firmware, ran the labelled 5.25" substitute, and reported the exact blocker.
2. **"try again"** — ambiguous between *relaunch* and *retry the `.hdv`*. Rather than guess I checked whether the ROM had appeared; it had (`a2cffa02.zip`, verified good), which resolved the ambiguity on evidence. Ran the real oracle.
3. **"looks good"** — the visual gate. Recorded verbatim as Jay's verdict; not interpreted, not expanded.
4. **"update the report"** — ambiguous as to *which* report. I judged that the unreported work since `74ec1b4` was what needed to reach the pipe, wrote this new report rather than editing a pushed historical one, and said so explicitly so Jay could redirect.

---

### 10 — Candidate(s) captured this task

Two new `live/` rows. Never inside `POP3_port`; no existing entry read for content or edited.

- `seeds/POP/live/2026-07-25-content-addressed-preconditions-make-a-redispatch-safe.md` (pool `56fbf7f`) — a baseline-hash precondition doubles as idempotency protection, so a re-sent dispatch cannot corrupt anything; and a report must distinguish halt-because-broken from halt-because-already-done. From the P1.2 re-dispatch halt. `initiator: executor`.
- `seeds/POP/live/2026-07-25-git-show-is-the-wrong-baseline-when-worktree-and-blob-differ.md` (pool `824fc77`) — `git show HEAD:<path>` is the wrong baseline when working tree and blob differ by normalization; **explicitly corrects** the P1.2 row `read-back-the-bytes-not-the-text-after-a-programmatic-edit`, filed as a new row per the never-edit rule. From §6.2. `initiator: executor`.

`seeds/POP/live/` now holds **fifteen** POP rows.

---

### 11 — Commit

- **`90cc27726476601759e9143981748a8ca6b78d18`** — `mame-idioms-apple2e-oracle.md: add §0 — POP oracle mount, VERIFIED FOR POP`. Pushed to `origin/wip` (`74ec1b4..90cc277`).
- **This report's commit** — on `wip`, pushed to `origin/wip` before reporting back. Hash in the accompanying reply.
- **No other `POP3_port` change.** No rebuild; the oracle `.hdv` is the unchanged P1.1 artifact.
- **Pool:** `56fbf7f` and `824fc77`, both pushed to `origin/main` of `Jsearle01/methodology-candidate-pool`.

---
---

## Appendix A — MAME evidence, verbatim

### A.1 — enumeration (§2A.4 surfaces searched)
```
$ mame -listmedia apple2e                      # BARE MACHINE — note: no hard1
apple2e   floppydisk1  (flop1)   .mfi .dfi .d13 .dsk .do .po .rti .edd .woz .nib
apple2e   floppydisk2  (flop2)   .mfi .dfi .d13 .dsk .do .po .rti .edd .woz .nib
apple2e   cassette     (cass)    .wav .flac

$ mame apple2e -sl7 cffa202 -listmedia          # WITH THE CARD IN — hard1 appears
apple2e   floppydisk1  (flop1)   .mfi .dfi .d13 .dsk .do .po .rti .edd .woz .nib
apple2e   floppydisk2  (flop2)   .mfi .dfi .d13 .dsk .do .po .rti .edd .woz .nib
apple2e   harddisk1    (hard1)   .chd .hd .hdv .2mg .hdi
apple2e   harddisk2    (hard2)   .chd .hd .hdv .2mg .hdi
apple2e   cassette     (cass)    .wav .flac

$ mame -listslots apple2e                       # slot names sl1..sl7; sl6 holds diskiing
apple2e   sl1 / sl2 / sl3 / sl4 / sl5 / sl6 / sl7
          sl6:diskiing:0  525  5.25" single density floppy drive
          sl6:diskiing:1  525  5.25" single density floppy drive
          ... cffa2   CFFA 2.0 Compact Flash (65C02 firmware, www.dreher.net)
          ... cffa202 CFFA 2.0 Compact Flash (6502 firmware, www.dreher.net)
```

### A.2 — attempt 1: the blocker
```
$ mame apple2e -sl7 cffa202 -hard1 <hdv> -video none -sound none -nothrottle -seconds_to_run 3
cffa20ee02.bin NOT FOUND (tried in a2cffa02 apple2e)
Fatal error: Required files are missing, the machine cannot be run.
EXIT=2

$ ls roms/
341-0027-a.p5  341-0028-a.rom  342-0132-c.e12  342-0133-a.chr  342-0134-a.64
342-0135-b.64  Karateka.dsk  apple2e.zip  coco3.zip  coco3h.zip  testdisk.dsk

$ mame -verifyroms a2cffa02
romset "a2cffa02" not found!
```
Per-card run-test (each fatal before boot): `cffa2`→`cffa20eec02.bin`, `a2sd`→`appleiisd.bin`, `corvus`→`a4.7.u10`, `focusdrive`→`focusrom.bin`, `zipdrive`→`zip drive - rom.bin`. `booti`→`Error: unknown option: -hard1`.

### A.3 — the labelled 5.25" substitute (attempt 1 fallback — NOT the oracle)
```
$ mame apple2e -flop1 <SideA.nib> -flop2 <SideB.nib> -video none -sound none -nothrottle -seconds_to_run 5
Average speed: 803.57% (4 seconds)      EXIT=0

$ mame apple2e -flop1 <SideA.nib> -flop2 <SideB.nib> -window -nomax -prescale 3
Average speed: 100.00% (216 seconds)    EXIT=0
```

### A.4 — attempt 2: the oracle (after Jay supplied the ROM)
```
$ mame -verifyroms a2cffa02
romset a2cffa02 is good
1 romsets found, 1 were OK.

$ md5sum PrinceOfPersia_3.5.hdv
c4f0b13e49b77dd0fbc5063e27e53a24        <- matches the Phase 0 Linux reference

$ mame apple2e -sl7 cffa202 -hard1 <hdv> -video none -sound none -nothrottle -seconds_to_run 5
Average speed: 1269.67% (4 seconds)     EXIT=0

$ mame apple2e -sl7 cffa202 -hard1 <hdv> -window -nomax -prescale 3
Average speed: 99.89% (190 seconds)     EXIT=0
```
**Jay's gate on this run: "looks good."**

---

## Appendix B — the §0 section added to `mame-idioms-apple2e-oracle.md`

Committed in `90cc277` as a pure 48-line insertion before §1; banner unchanged. Reproduced here so the Orchestrator can review the wording without fetching the file (§2D — if idioms files are deemed Orchestrator-owned, this is the text to re-author; see §6.3).

``````markdown
## 0. POP ORACLE MOUNT — **VERIFIED FOR POP, 2026-07-25** (the one section the banner does NOT cover)

Everything else in this file remains inherited-unverified for POP (see the banner). **This section is
POP-verified against POP's own oracle**, on a live run Jay gated "looks good" (2026-07-25).

**The working command** (operator live-watch; Jay's 25.3 gate):
```bash
mame apple2e -sl7 cffa202 -hard1 <abs-path>/PrinceOfPersia_3.5.hdv -window -nomax -prescale 3
```
Confirmed clean: exit 0, 99.89% speed over a 190 s operator run. The image hashed
`c4f0b13e49b77dd0fbc5063e27e53a24` (the Phase 0 Linux reference) at run time.

- **`a2cffa02.zip` in the rompath is a HARD PREREQUISITE.** The CFFA2 card carries its own device
  firmware (`cffa20ee02.bin`). Without it MAME dies before boot with
  `cffa20ee02.bin NOT FOUND (tried in a2cffa02 apple2e)` / `Fatal error: Required files are missing`.
  Verify with `mame -verifyroms a2cffa02` → `romset a2cffa02 is good`. A stock MAME install does **not**
  ship it.
- **⚠ `hard1` does NOT exist on a bare `apple2e`.** `mame -listmedia apple2e` alone reports only
  `flop1`/`flop2`/`cass` — the hard-disk instance materializes **only once a CFFA2 card occupies a slot**.
  Enumerate with the card inserted or the conclusion is wrong:
  `mame apple2e -sl7 cffa202 -listmedia` → `harddisk1 (hard1) .chd .hd .hdv .2mg .hdi`.
- **Slot choice:** `sl7` (the conventional Apple II hard-disk slot) leaves `sl6`'s `diskiing` Disk II
  intact. `sl2` also yields `hard1`; slots are `sl1`–`sl7`.
- **`cffa202` (6502 firmware), not `cffa2`** (65C02, needs an enhanced //e or better) — confirmed by
  the slot-option descriptions.
- **NOT `-flop1`.** Karateka's `-flop1 <dsk>` mount is the wrong media class for POP; the oracle is an
  800K 3.5" ProDOS volume on `hard1`. `.hdv` is natively accepted — no conversion, no CHD.
- **Every other `apple2e` storage card was ROM-blocked in this install** (checked exhaustively per §2A.4,
  via `-listslots` + a run-test on each): `cffa2`→`cffa20eec02.bin`, `a2sd`→`appleiisd.bin`,
  `corvus`→`a4.7.u10`, `focusdrive`→`focusrom.bin`, `zipdrive`→`zip drive - rom.bin`; `booti` exposes no
  `hard1` at all. So `cffa202` + `a2cffa02.zip` is not merely the preferred path, it was the only one.
- **Fallback that needs no extra ROM:** the same build's 5.25" pair boots on the built-in Disk II —
  `mame apple2e -flop1 PrinceOfPersia_5.25_SideA.nib -flop2 PrinceOfPersia_5.25_SideB.nib`. Useful when
  the CFFA2 firmware is unavailable, but note those two `.nib` images are the artifacts that **mismatch**
  the Phase 0 reference md5s (the `.hdv` matches) — so they are not the graded oracle.

**Idiom worth reusing beyond this target: validate a mount headlessly before handing an operator a window.**
```bash
mame apple2e -sl7 cffa202 -hard1 <hdv> -video none -sound none -nothrottle -seconds_to_run 5
```
Exit 0 ⇒ the mount is good. This costs seconds and is what turned "a dead window Jay stares at" into a
precise missing-ROM diagnosis. A missing device ROM is a *fatal-before-boot* error, so it is invisible to
any check that only inspects the media path.

*Established:* POP P1.1 oracle build + the 2026-07-25 operator run (Jay gate: "looks good").

---
``````

---

*End of report.*
