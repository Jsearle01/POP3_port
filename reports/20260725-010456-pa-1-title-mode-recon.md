## Form B Report — PA.1 — title-sequence graphics-mode recon (HGR-only vs HGR/DHGR mode-switching)
**Class:** recon — INSPECTION ONLY. wip. **Prod byte-identity: N/A.**

> **ANSWER TO §1: POP genuinely switches between HGR and DHGR.** The extra colour on the title/text screens is **real double hi-res**, not HGR artifacting. The switch is not subtle or occasional — it happens *inside* the title sequence, and the animated engine turns DHGR **off on every single page flip**. Source and oracle agree instruction-for-instruction.

---

### 0 — Receipt / status (C-35 stamp)

```
t0=2026-07-25T04:53:53Z
```

**HEAD at t0:** `6d4f92c42ad02d022b0bd5943dcc9604b791d5c7` (branch `wip`, no tracked file modified).
**HEAD at report time:** `63b9d2d…` (the idioms addition; the report commit follows).

**§10 hard-stop gates — both PASS:**
```
vendored source last touched by : ba6154e "P1.1a: vendor oracle buildable-whole @ ec78dbf"
PROVENANCE pin                  : ec78dbfd51013ba349cda8c51c3ce0595fe75342
oracle .hdv md5                 : c4f0b13e49b77dd0fbc5063e27e53a24  (required c4f0b13e…)  -> PASS
```

**§0(a).3 — CFFA2 ROM:** present and good (`romset a2cffa02 is good`). **The oracle half was NOT blocked.** My first check reported `romset "a2cffa02" not found!` — that was **my own cwd error**, not a missing ROM; see §6.1. Both halves of the recon ran.

**`git status` at end:** no tracked file modified beyond the two commits below. 17 untracked — the standing 16 `docs/ground-truth/` paths plus `POP-idioms-coco3-markers.md`.

Calibration-light per CLAUDE.md §1/§5. No elapsed, no band, no variance.

---

### 1 — Summary

Two independent evidence lines were run and they agree completely.

**Source (authoritative for intent).** `GRAFIX.S:137-140` names the switches (`DHIRESon = $c05e`, `DHIRESoff = $c05f`). The only routine that *sets* DHGR is `UNPACK.S SETDHIRES`, reached via the `setdhires` jump-table entry from `MASTER.S` at three sites. The attract/title driver `MASTER.S:686-707` runs `PubCredit → AuthorCredit → TitleScreen → Prolog1 → PrincessScene → SetupDHires → Prolog2 → SilentTitle → Demo`, and `PubCredit`'s own comments read *"Unpack splash screen into **DHires** page 1"*. Meanwhile `PrincessScene` → `CUTPRINCESS` uses **`SngExpand`** (single hi-res) where every title card uses **`DblExpand`** — which is precisely why `setdhires` has to be called *again* before `Prolog2`.

**Oracle (authoritative for fact).** A read+write tap over `$C000-$C0FF` produced 247,989 hits across a 120 s run (self-test passed, so a null would have been meaningful). DHGR is enabled at frame 304 by an eight-access sequence at `$ECCC-$ECE1` that maps **instruction-for-instruction** onto `UNPACK.S:644-653`. From frame 2686 onward, `SUBS.S PAGEFLIP` at `$E1E4` issues `DHIRES_OFF` on **every page flip** — 150 times in the run against only 6 `DHIRES_ON`.

**The mechanism, stated plainly:** DHGR is turned on once per static-screen phase and is torn down implicitly by the animation engine, because `PAGEFLIP` unconditionally takes a `DHIRES` branch every flip — `off` when `vibes == 0`, which is the normal case. Static title/story screens therefore sit in DHGR; anything animated runs in HGR.

**This matches Jay's observation exactly** and explains it: the title/text screens *are* 16-colour DHGR, and the animated scenes *are* 4-colour HGR — not two renderings of one mode.

One correction to the dispatch's own method is reported in §6.2: §5.2's instruction to *"watch writes to the soft-switch addresses, not reads"* would have produced a **zero-hit null and the opposite conclusion**, because POP sets mode exclusively with reads (`bit`/`lda`).

---

### 2 — Files modified

**`63b9d2d`** — `mame-idioms-apple2e-oracle.md`: added **§1a** (soft switches toggle on reads; §1's false-0 is scoped to code addresses; tap design, noise filters, self-test, `.LST` PC→source mapping) and **§1b** (`rompath` is cwd-relative). Both VERIFIED FOR POP. Permitted by this dispatch's §3 under CLAUDE.md §2A.3. Superset-checked against a **byte copy of the working file** (not `git show` — per the P1.2 correction): 1 hunk, 0 lines removed, LF preserved.

**This report.**

**Not modified:** no source, engine, HAL, content, or coco3 change; no edit to `mame-idioms-coco3-port.md` or `mame-idioms-addendum.md`; no oracle rebuild; `/c/mame`, Karateka and the probe clone untouched.

**Pool:** one new `live/` row, `512a59e` (§10).

---

### 3 — Reasoning

**Authority handling.** Source is authoritative for intent, trace for fact, and where they agree the finding is solid (§2(c)). Here they agree at the instruction level, so no tie-break was needed. **No visual claim is made anywhere in this report** — every statement is a soft-switch access, a PC, or a source line. Which mode produces which *appearance* on screen is Jay's (CLAUDE.md §4), and the recon deliberately does not assert it.

**Resolving names before addresses.** Per §5.1 I resolved the equates first rather than grepping raw addresses. `GRAFIX.S:132-160` defines the full soft-switch block by name; that immediately separated genuine mode-sets from incidental `$C0xx` traffic (keyboard `$C000`, RAMRD/RAMWRT paging), which is the bulk of `$C0xx` references in the tree and would otherwise have swamped the read.

**Why `SngExpand` vs `DblExpand` is the cleanest source-side tell.** Rather than reasoning only from soft-switch sites, the unpacker choice is decisive and unambiguous:
```
MASTER.S:651  jsr SngExpand   <- CUTPRINCESS  (the ONLY SngExpand site in the tree)
MASTER.S:848  jsr DblExpand   <- Prolog1
MASTER.S:878  jsr DblExpand   <- Prolog2
MASTER.S:897  jsr DblExpand   <- Epilog
MASTER.S:919  jmp DblExpand   <- unpacksplash (PubCredit / SilentTitle)
```
Every title/story asset is unpacked by the **double** hi-res expander; the princess cutscene by the **single** one. The engine carries two separate unpackers, which is only worth doing if both modes are genuinely used. `GRAFIX.S:890-896` corroborates in comments: *"Works for both single & double hires… Hires scrn: X-coord range 0-279… Dbl hires scrn: X-coord range 0-559"*.

**Why the mode teardown is implicit rather than an explicit "switch to HGR".** There is no `SETHIRES` counterpart to `SETDHIRES`. Instead `SUBS.S PAGEFLIP` (`$E1D0-$E1EF`) ends every flip with a DHIRES access:
```
E1DB: AD 18 03   408  lda vibes
E1DE: F0 04      409  beq :rts
E1E0: AD 5E C0   410  lda $c05e      ; vibes != 0  -> DHIRES ON
E1E3: 60         411 ]rts rts
E1E4: AD 5F C0   412 :rts lda $c05f  ; vibes == 0  -> DHIRES OFF
```
`vibes` (`$0318`, `GAMEEQ.S:534`) is a gameplay flash effect — `TOPCTRL.S:1699` comments *"Screen flashes as weightlessness ends"*. In the normal case it is zero, so **every page flip turns DHGR off**. The trace bears this out: 150 `DHIRES_OFF` events, all at `$E1E4`, against 6 `DHIRES_ON`.

That asymmetry is the whole answer to §1. DHGR is a *static-screen* mode here, re-established per phase and dismantled by the first animated flip.

**Byte-exact reconciliation via the build's listings.** The P1.1 build left `oracle/source/obj/*.LST`, which carry `ADDR: bytes  line  source`. Every traced PC was resolved through them, so the source↔trace mapping is *demonstrated*, not inferred — see §4's mode map and Appendix B.

---

### 4 — Verification (AC-by-AC) — including the MODE MAP

**AC1 — every graphics-mode soft-switch site enumerated with file:line and context. — MET.**

*Definitions* (`GRAFIX.S:132-160`, duplicated verbatim in `MASTER.S:132-160` and `UNPACK.S:38-47`; `TOPCTRL.S:57-58` defines a two-entry subset):
```
GRAFIX.S:137  DHIRESoff = $c05f      GRAFIX.S:141  PAGE2on  = $c055
GRAFIX.S:138  DHIRESon  = $c05e      GRAFIX.S:142  PAGE2off = $c054
GRAFIX.S:139  HIRESon   = $c057      GRAFIX.S:143  MIXEDon  = $c053
GRAFIX.S:140  HIRESoff  = $c056      GRAFIX.S:144  MIXEDoff = $c052
GRAFIX.S:149  ADCOLon   = $c00d      GRAFIX.S:145  TEXTon   = $c051
GRAFIX.S:150  ADCOLoff  = $c00c      GRAFIX.S:146  TEXToff  = $c050
GRAFIX.S:153-156 RAMWRTaux/main = $c005/$c004, RAMRDaux/main = $c003/$c002
GRAFIX.S:157-158 ADSTOREon/off (80STORE) = $c001/$c000
```

*Actual mode-setting sites* (as distinct from incidental `$C0xx`):

| Site | file:line | What it does |
|---|---|---|
| `SETDHIRES` | `UNPACK.S:640-654` | **The only DHGR enable.** `RAMRDaux`/`RAMWRTaux`, `vblank`, `ADCOLon` (80COL), `bit HIRESon`, the 5-access AN3 toggle, `TEXToff` |
| `TEXT` | `UNPACK.S:630-635` | `TEXTon`, `ADCOLoff`, `PAGE2off` — text/blackout |
| `PAGEFLIP` | `SUBS.S:403-418` | Page flip + `HIRESon` + `TEXToff` + **conditional `$c05e`/`$c05f`** |
| `DOFLASHON/OFF` | `SUBS.S:215-227` | `$c056`/`$c057` lo-res flash effect (gameplay) |
| — | `MISC.S:1000-1013` | `PAGE2off`/`TEXTon` … `HIRESon`/`TEXToff`/`PAGE2on` around a keypress wait |
| boot init | `BOOT.S:30-33` | `80store off`, `RAMRD main`, `RAMWRT main`, `80col off` |
| `DeltaExpPop` | `UNPACK.S:524-526` | `PAGE2on` / `jsr DeltaExp` / `PAGE2off` — **does not touch DHIRES** |
| `CleanScreen` | `MASTER.S:769-777` | `PAGE2on` / `copy2to1` / `PAGE2off` — **does not touch DHIRES** |

**Incidental / non-mode `$C0xx` excluded:** `$C000` *reads* (keyboard, e.g. `MISC.S:1006`), `$C010` (keyboard strobe), `$C002-$C005` (aux-memory paging by the blitter — 222k accesses in a 120 s run), `$C083/$C08B/$C082` (language-card banking, `GRAFIX.S:161-163`).

**AC2 — the binary question answered from source. — MET: YES, the title path enables DHGR.**
`MASTER.S:739 PubCredit` calls `setdhires` with the source comments *"Unpack splash screen into DHires page 1" / "Show DHires page 1"*. `MASTER.S:880 Prolog2` and `MASTER.S:899 Epilog` likewise. `MASTER.S:862` and `:1213` both carry the aside *"wiped out by dhires titles"*. The extra colour is therefore **genuine DHGR, not HGR artifacting**.

**AC3 — oracle soft-switch timeline. — MET.** Read+write tap on `$C000-$C0FF`; **self-test passed** (247,989 hits — the method demonstrably fires, so a null would have been informative). Full log in Appendix A. Access totals over 120 s:
```
$C003/$C002 RAMRD   83865 / 83109     $C057 HIRES_on     152
$C004/$C005 RAMWRT  28065 / 27575     $C05F DHIRES_OFF   150
                                      $C050 TEXT_off     147
$C054/$C055 PAGE2    95 / 87          $C05E DHIRES_ON      6
```

**AC4 — source and oracle reconciled. — MET, at instruction level. No disagreement found.**

`SETDHIRES`, trace vs listing:

| Trace (f=304) | Listing (`obj/UNPACK.LST`) | Source line |
|---|---|---|
| `$C00D 80COL_on pc=$ECCC` | `ECCC: 8D 0D C0` | `644  sta ADCOLon` |
| `$C057 HIRES_on pc=$ECCF` | `ECCF: 2C 57 C0` | `645  bit HIRESon` |
| `$C05E DHIRES_ON pc=$ECD2` | `ECD2: 2C 5E C0` | `647  bit DHIRESon` |
| `$C05F DHIRES_OFF pc=$ECD5` | `ECD5: 2C 5F C0` | `648  bit DHIRESoff` |
| `$C05E DHIRES_ON pc=$ECD8` | `ECD8: 2C 5E C0` | `649  bit DHIRESon` |
| `$C05F DHIRES_OFF pc=$ECDB` | `ECDB: 2C 5F C0` | `650  bit DHIRESoff` |
| `$C05E DHIRES_ON pc=$ECDE` | `ECDE: 2C 5E C0` | `651  bit DHIRESon ;for old Apple RGB card` |
| `$C050 TEXT_off pc=$ECE1` | `ECE1: 8D 50 C0` | `653  sta TEXToff` |

Eight accesses, eight source lines, exact. `PAGEFLIP` (`$E1D2/$E1D5/$E1D8/$E1E4` ↔ `SUBS.S:404/406/407/412`) and `TEXT` (`$ECB9/$ECBC/$ECBF` ↔ `UNPACK.S:632/633/634`) reconcile identically.

**AC5 — THE MODE MAP, complete for the title sequence, stopping where it ends. — MET.**

| Frames | Phase | Mode | Source path | Oracle evidence |
|---|---|---|---|---|
| 0–140 | Boot / firmware | TEXT | ROM `$FB33`, CFFA2 firmware `$CB2D-$CB4A`, `BOOT.S:30-33` | `HIRES_off`, `PAGE2_off`, `TEXT_on` @ `$FB33-$FB39`; `80COL_off` @ `$203D` |
| 141–303 | Blackout before titles | TEXT, 80COL off | `UNPACK.S TEXT` (630-635) | `TEXT_on/80COL_off/PAGE2_off` @ `$ECB9-$ECBF` |
| **304** | **DHGR enabled** | **→ DHGR** | `MASTER.S:739 PubCredit` → `setdhires` → `UNPACK.S:640` | the 8-access block above @ `$ECCC-$ECE1` |
| 304–2580 | Brøderbund / Author / Title / Prolog1 | **DHGR** | `PubCredit`, `AuthorCredit`, `TitleScreen`, `Prolog1`; `DblExpand` | page flips @ `$EC08/$EC0E` (`DeltaExpPop`) and `$FC0E/$FC14` (`CleanScreen`) — **neither touches DHIRES**; no `$C05x` mode change in the window |
| 2580 | Blackout | TEXT | `UNPACK.S TEXT` | `TEXT_on` @ `$ECB9` |
| 2686–~5700 | **PrincessScene** (animated cutscene) | **HGR** | `MASTER.S:859 PrincessScene` → `CUTPRINCESS` → **`SngExpand`** | `PAGEFLIP` @ `$E1D2-$E1E4` every 3–6 frames: `HIRES_on` + **`DHIRES_OFF`** |
| **5750** | **DHGR re-enabled** | **→ DHGR** | `MASTER.S:703 SetupDHires` + `:880 Prolog2` → `setdhires` | second 8-access block @ `$ECCC-$ECE1` |
| 5750–7500 | Prolog2 / SilentTitle | **DHGR** | `Prolog2` (`DblExpand`), `SilentTitle` (`unpacksplash`→`DblExpand`) | quiescent; page flips @ `$EC08/$EC0E` only |
| 7809–7900 | Blackout + stage load | TEXT | `UNPACK.S TEXT`; `TOPCTRL` `$20F0`/`$2463` | `TEXT_on` @ `$ECB9`, then `$20F3`/`$2466` |
| **7935 →** | **Demo (gameplay attract)** | **HGR** | `MASTER.S:707 jmp Demo` | sustained `PAGEFLIP` @ `$E1D2-$E1E4`, `DHIRES_OFF` every flip |

**The title sequence ends at frame ≈7935**, where `jmp Demo` hands over and sustained `PAGEFLIP`-driven HGR animation begins. Per §2(a) the recon stops there. Confirmed as a loop, not a one-off: a 300 s run shows `SETDHIRES` at f=304, 5750, **11062, 16523** — the attract loop repeating with period ≈10,758 frames (~179 s).

**AC6 — no source/engine/HAL/content/coco3 change; `git status` clean except standing untracked. — MET.** Only `mame-idioms-apple2e-oracle.md` (§3-permitted) and this report. Untracked: the standing 16 plus `POP-idioms-coco3-markers.md`.

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output — APPLIES, satisfied.** Verbatim MAME instrumentation output in Appendix A (tap totals, DHIRES event list, condensed timeline) and Appendix B (listing lines). Both runs: `-seconds_to_run 120` → `Average speed: 976.53%`, EXIT=0; `-seconds_to_run 300` → `830.05%`, EXIT=0.

**25.2 bundled-artifact grep — N/A.** No artifact produced; nothing built or imaged.

**25.3 operator-runtime-smoke — N/A as a gate.** Both runs were headless (`-video none`); no windowed run was used and **no on-screen characterization is made anywhere in this report**. Every finding is a soft-switch access, a PC, or a source line. Appearance remains Jay's (CLAUDE.md §4).

**C-35 presence check — SATISFIED.** §0 quotes verbatim `t0=2026-07-25T04:53:53Z` and HEAD. No elapsed, no band, no variance.

**Capture presence check — SATISFIED.** §10 carries one slug.

---

### 6 — Reactive deviations

**6.1 — `-verifyroms` reported the CFFA2 ROM missing; that was my cwd error, not a missing ROM.**
§0(a).3's check run as `/c/mame/mame -verifyroms a2cffa02` from the repo directory returned `romset "a2cffa02" not found!`. Taken at face value that would have declared the oracle half **blocked** and reduced this recon to its source half. `rompath` defaults to the relative `roms`, resolved from **MAME's cwd**; re-run from `/c/mame` it returns `romset a2cffa02 is good`. The ROM was present throughout. Captured as idioms §1b so it does not recur.

**6.2 — §5.2's instrumentation instruction would have inverted the finding. (Most important deviation.)**
The dispatch says, in bold: *"**watch writes to the soft-switch addresses, not reads**"*, justified by idioms §1 (6502 read-taps false-0). **Followed literally this yields zero hits on `$C05E`/`$C05F` and supports the conclusion "POP never switches graphics mode" — the exact opposite of the truth.** Two reasons:

1. **§1's hazard does not extend here.** Its mechanism is that *opcode fetches* bypass the program-space read-tap — it is about detecting execution by tapping **code** addresses. A soft-switch access is a **data** access; the read-tap fired 247,989 times.
2. **POP sets graphics mode exclusively with reads.** `bit DHIRESon` (`UNPACK.S:647-651`, `2C` = BIT) and `lda $c05e`/`lda $c05f` (`SUBS.S:410/412`, `AD` = LDA). Apple II soft switches toggle on *any* access, so writes are simply not how this program does it. A write-only tap on the decisive registers logs **nothing**.

I therefore tapped **read and write**, and carried a hit-counter self-test so a null would be interpretable. **What saved this was the dispatch's own ordering** — §5.1's source read ran first and exposed the `bit`/`lda` access mode *before* the instrument was designed. Had instrumentation gone first, the null would have arrived pre-justified by §1 and been very easy to believe. Captured as a pool candidate, and corrected in idioms §1a.

**6.3 — Extended `mame-idioms-apple2e-oracle.md` (explicitly permitted here).** §3 of this dispatch permits it for a genuinely new oracle-instrumentation idiom under §2A.3, so unlike the previous session there is no ambiguity. Added §1a and §1b (`63b9d2d`). Note this also **corrects an over-generalization of the existing §1**, which is a change to how a standing idiom should be read — flagged for the Orchestrator in case that warrants review rather than acceptance.

**6.4 — The 120 s run ended mid-Prolog2 and did not reach the `Demo` boundary.** Hit count froze at 247,989 from f=5750 to the f=7200 end marker — DHGR held, no further switching. Since AC5 requires identifying where the title sequence *ends*, I re-ran at 300 s, which captured the blackout (f=7809), the stage load (f=7891-7900) and the Demo handover (f=7935). Reported because the first run's quiescent tail could be misread as "nothing further happens".

**6.5 — A source-half finding beyond the title sequence, reported not pursued.** `SUBS.S PAGEFLIP` sets DHIRES **on** when `vibes != 0` (`GAMEEQ.S:534`; `TOPCTRL.S:1699` *"Screen flashes as weightlessness ends"*). That is an in-game effect and §2(a) puts gameplay out of scope, so it was not instrumented. Recorded because it means the HGR/DHGR boundary is not simply "titles vs game" — a gameplay effect can flip DHGR on mid-animation.

**6.6 — Noise filtering was necessary and is worth stating.** `$C002-$C005` produced ~222,000 of the 248,000 hits (aux-memory paging by the blitter) and `$C000` reads are the keyboard. Both were filtered from the timeline. Unfiltered, the mode signal is invisible. Recorded in idioms §1a.

**6.7 — The AN3 five-toggle is an RGB-card idiom, not a DHGR requirement.** `UNPACK.S:651`'s own comment reads *";for old Apple RGB card"*. The toggle sequence sets an external RGB card's mode; plain DHGR needs only `80COL on` + `HIRES on` + AN3 low. Flagged so the 5 accesses are not misread as five mode changes — they are one mode set.

---

### 7 — Uncertainty flags

1. **Scope is the title sequence only** (§2(a)). Gameplay and cutscenes past `jmp Demo` were not analysed. The Demo *entry* was observed (HGR) but the demo itself was not characterized.
2. **No visual confirmation is claimed.** The recon proves which soft switches are set when; it does **not** assert what the screen looks like. That `DHGR ⇒ what Jay saw as "more than 4 colours"` is a highly plausible correlation, not something this recon establishes — the correlation is Jay's to confirm.
3. **`vibes != 0` was never observed** in these runs (all 150 PAGEFLIP DHIRES accesses took the `off` branch). The `on` branch (§6.5) is read from source only.
4. **`Epilog` also calls `setdhires`** (`MASTER.S:899`) but is end-of-game, outside both the title sequence and this recon's runs.
5. **Two runs, one boot seed.** The attract loop is seed-non-deterministic run-to-run (idioms §3); the *mode* structure is code-driven and so should be stable, but only two runs were observed.
6. **`$C23C`/`$CB2D-$CB4A` at f=0** are boot firmware (CFFA2 expansion ROM / IIe internal ROM), not POP code. Not attributed further.

---

### 8 — Follow-up candidates

1. **The coco3 graphics-mode gate — this recon's consumer.** The fact is now established: POP needs **two** distinct graphics modes, switched at phase boundaries, plus the tear-down-on-pageflip behaviour. **Per §2(b) I state no recommendation** — the choice between a single GIME mode approximating both versus mirroring the oracle's switching is the gate's, not mine. Flagged as the open question the gate must answer.
2. **Determine the DHGR colour count actually used** by the title assets — informs any palette-mapping work. Not attempted (§2(b)).
3. **Characterize gameplay/cutscene modes** past `jmp Demo`, including the `vibes` DHGR-on effect (§6.5/§7.3).
4. **Orchestrator review of idioms §1a** — it corrects how standing §1 should be read (§6.3).
5. **Dispose of `POP-idioms-coco3-markers.md`** — still untracked, still unruled.
6. **POP-level `.gitattributes`/`core.autocrlf`** — still deferred.

---

### 9 — User interaction during task

**None.** No question asked; the dispatch is bridge-safe-equiv. Every judgment call — the cwd diagnosis (§6.1), the read-vs-write tap decision (§6.2), the longer second run (§6.4) — is surfaced in §6 for post-hoc ruling.

---

### 10 — Candidate(s) captured this task

One new `live/` row, pushed in pool commit `512a59e`:

- `seeds/POP/live/2026-07-25-a-hazard-note-over-generalized-into-a-method-inverts-the-finding.md` — a documented hazard can be over-generalized into a prescribed method that yields the opposite of the truth; check the hazard's *mechanism and scope* against the specific measurement before adopting it, and read the source before designing the instrument because it tells you which instrument can work (from §6.2). `initiator: executor`.

`seeds/POP/live/` now holds **sixteen** POP rows.

---

### 11 — Commit

- **`63b9d2d`** — `idioms(apple2e): add §1a soft-switches-toggle-on-READS, §1b rompath is cwd-relative`.
- **This report's commit** — on `wip`, pushed to `origin/wip` before reporting back. Hash in the accompanying reply.
- **No source/engine/content commit** (§9 of the dispatch).
- **Pool:** `512a59e`.

---
---

## Appendix A — oracle instrumentation, verbatim

### A.1 — method and self-test
```
mame apple2e -sl7 cffa202 -hard1 PrinceOfPersia_3.5.hdv -video none -sound none \
     -nothrottle -seconds_to_run 120 -autoboot_script softswitch_trace.lua
Average speed: 976.53% (119 seconds)     EXIT=0

SELF-TEST: log lines 223511; "--- frame 7200 marker, hits so far = 247989 ---"
=> the tap demonstrably fires; a null would have been a finding, not a failure.
```
Tap: `install_read_tap` **and** `install_write_tap` over `$C000-$C0FF`, both held in `_G` (idioms §2 GC gotcha). `$C000/$C001` reads (keyboard) dropped; `$C002-$C005` filtered from the timeline only.

### A.2 — access totals, 120 s
```
  83865 $C003 RAMRD_aux        152 $C057 HIRES_on          7 $C000 80STORE_off
  83109 $C002 RAMRD_main       150 $C05F DHIRES_OFF        6 $C05E DHIRES_ON
  28065 $C004 RAMWRT_main      147 $C050 TEXT_off          6 $C001 80STORE_on
  27575 $C005 RAMWRT_aux        95 $C054 PAGE2_off         5 $C051 TEXT_on
                                87 $C055 PAGE2_on          4 $C00C 80COL_off
                                 7 $C056 HIRES_off         2 $C00D 80COL_on
                                                           1 $C052 MIXED_off
                                                           1 $C00E ALTCHAR_off
```

### A.3 — every DHIRES_ON event (120 s run) — one 3-access set per DHGR enable
```
f=304     R $C05E DHIRES_ON      pc=$ECD2
f=304     R $C05E DHIRES_ON      pc=$ECD8
f=304     R $C05E DHIRES_ON      pc=$ECDE
f=5750    R $C05E DHIRES_ON      pc=$ECD2
f=5750    R $C05E DHIRES_ON      pc=$ECD8
f=5750    R $C05E DHIRES_ON      pc=$ECDE
```
300 s run adds `f=11062` and `f=16523` — the attract loop repeating (~10,758 frames ≈ 179 s).

### A.4 — the DHGR enable at f=304 (maps 1:1 to UNPACK.S:644-653)
```
f=304 $C00D 80COL_on   pc=$ECCC
f=304 $C057 HIRES_on   pc=$ECCF
f=304 $C05E DHIRES_ON  pc=$ECD2
f=304 $C05F DHIRES_OFF pc=$ECD5
f=304 $C05E DHIRES_ON  pc=$ECD8
f=304 $C05F DHIRES_OFF pc=$ECDB
f=304 $C05E DHIRES_ON  pc=$ECDE
f=304 $C050 TEXT_off   pc=$ECE1
```

### A.5 — PAGEFLIP tearing DHGR down every flip (animated phases)
```
f=2686 $C054 PAGE2_off  pc=$E1D2
f=2686 $C057 HIRES_on   pc=$E1D5
f=2686 $C050 TEXT_off   pc=$E1D8
f=2686 $C05F DHIRES_OFF pc=$E1E4     <- every flip, vibes==0 branch
f=2691 $C055 PAGE2_on   pc=$E1EC
f=2691 $C057 HIRES_on   pc=$E1D5
f=2691 $C050 TEXT_off   pc=$E1D8
f=2691 $C05F DHIRES_OFF pc=$E1E4
   … 150 such events, all at $E1E4 …
```

### A.6 — the Demo boundary (300 s run) — where the title sequence ENDS
```
f=7467 $C055 PAGE2_on   pc=$EC08     SilentTitle (DeltaExpPop), still DHGR
f=7500 $C054 PAGE2_off  pc=$EC0E
f=7809 $C051 TEXT_on    pc=$ECB9     blackout (UNPACK.S TEXT)
f=7891 $C054 PAGE2_off  pc=$20F0     stage load (TOPCTRL)
f=7900 $C051 TEXT_on    pc=$2466
f=7935 $C057 HIRES_on   pc=$E1D5     >>> DEMO: sustained PAGEFLIP, HGR <<<
f=7935 $C05F DHIRES_OFF pc=$E1E4
```

---

## Appendix B — source listings, verbatim (`oracle/source/obj/*.LST`, P1.1 build)

### B.1 — `UNPACK.LST`: TEXT and SETDHIRES
```
ECB3: 8D 03 C0   630 TEXT sta RAMRDaux
ECB6: 20 ED 04   631  jsr vblank
ECB9: 8D 51 C0   632  sta TEXTon
ECBC: 8D 0C C0   633  sta ADCOLoff
ECBF: 8D 54 C0   634  sta PAGE2off
ECC2: 60         635 ]rts rts
ECC3: 8D 03 C0   641  sta RAMRDaux
ECC6: 8D 05 C0   642  sta RAMWRTaux
ECC9: 20 ED 04   643  jsr vblank
ECCC: 8D 0D C0   644  sta ADCOLon
ECCF: 2C 57 C0   645  bit HIRESon
ECD2: 2C 5E C0   647  bit DHIRESon
ECD5: 2C 5F C0   648  bit DHIRESoff
ECD8: 2C 5E C0   649  bit DHIRESon
ECDB: 2C 5F C0   650  bit DHIRESoff
ECDE: 2C 5E C0   651  bit DHIRESon ;for old Apple RGB card
ECE1: 8D 50 C0   653  sta TEXToff
ECE4: 60         654  rts
```

### B.2 — `SUBS.LST`: PAGEFLIP (the conditional DHIRES)
```
E1D0: 85 00      403  sta PAGE
E1D2: AD 54 C0   404  lda $C054 ;show page 1
E1D5: AD 57 C0   406 :3 lda $C057 ;hires on
E1D8: AD 50 C0   407  lda $C050 ;text off
E1DB: AD 18 03   408  lda vibes
E1DE: F0 04      409  beq :rts
E1E0: AD 5E C0   410  lda $c05e
E1E3: 60         411 ]rts rts
E1E4: AD 5F C0   412 :rts lda $c05f
E1E7: 60         413  rts
E1E8: A9 00      415 :1 lda #0
E1EA: 85 00      416  sta PAGE
E1EC: AD 55 C0   417  lda $C055 ;show page 2
E1EF: 4C D5 E1   418  jmp :3
```

### B.3 — the title driver, `MASTER.S:686-707` (verbatim source)
```
ATTRACTMODE
AttractLoop
 lda #1
 sta musicon
 jsr SetupDHires
 jsr PubCredit
 jsr AuthorCredit
 jsr TitleScreen
 jsr Prolog1
]princess
 jsr PrincessScene
 jsr SetupDHires
 jsr Prolog2
 jsr SilentTitle
 jmp Demo
```

### B.4 — `PubCredit`, the DHGR intent in the author's own comments (`MASTER.S:731-745`)
```
PubCredit
* Unpack splash screen into DHires page 1
 jsr unpacksplash
* Show DHires page 1
 jsr setdhires
* Copy to DHires page 2
 jsr copy1to2
```

### B.5 — the single/double split (`MASTER.S:644-655`, CUTPRINCESS)
```
CUTPRINCESS
 jsr blackout
 lda #1 ;seek track 0
cutprincess1
 jsr LoadStage2 ;displaces bgtab1-2, chtab4
 lda #pacProom
 jsr SngExpand          <- the ONLY SngExpand call site in the tree
```

---

*End of report.*
