## Form B Report — PA.4 — the two facts the mode gate turns on: `vibes` firing + horizontal motion granularity
**Class:** recon — SOURCE READING ONLY. wip. **Prod byte-identity: N/A.**

> **Q1 — the boundary IS clean, but not for the reason expected.** `vibes` *is* set nonzero during ordinary gameplay (weightlessness potion, ~200 frames of normal animation), so the naive reading — "DHGR can be on mid-gameplay" — looked confirmed. It is **wrong**: `$C05E` only produces DHGR when **80COL is on**, and the entire source has exactly **three** 80COL sites. Every animated phase is entered via `TEXT`, which turns 80COL **off**. The `vibes` write is therefore **inert as a mode change** — it sets only the AN3 annunciator. **B's mode boundaries are clean.**
> **Q2 — the alignment tax is REAL.** POP positions at **1-pixel** horizontal granularity (`CVTX`: X-coord 0–279 → byte + 0–6 bit offset; objects store `objX` *and* `objOFF`). Minimum nonzero step is **1 px**, and **72 of 129 moving frames (56%) use an odd `Fdx`** — positions 2-px quantization cannot represent. **All-aligned blitting is not available to POP.**
> **Net effect on the gate: PA.3's headline survives intact.** PA.3's "fits, 8% headroom" already assumed the 50/50 mixed-alignment case, which Q2 now *confirms* is the correct one. What Q2 removes is the optimistic 72%-headroom aligned branch, which was never the headline.

---

### 0 — Receipt / status (C-35 stamp)

```
t0=2026-07-25T06:10:12Z
```

**HEAD at t0:** `7ada912df0293f3daaf8901dd79fb01a1dcb4096` (branch `wip`, no tracked file modified).
**HEAD at report time:** same — this dispatch produced no commit other than the report.

**§10 hard-stop gate — PASS:**
```
vendored source last touched by : ba6154e "P1.1a: vendor oracle buildable-whole @ ec78dbf"
PROVENANCE pin                  : ec78dbfd51013ba349cda8c51c3ce0595fe75342
```
**No oracle run and no `.hdv` md5 gate:** this dispatch is source reading. The one trace consulted is PA.1's **existing** log, re-read rather than regenerated — no emulator was launched (§6.4).

**`git status` at end:** no tracked file modified; 17 untracked (standing 16 + `POP-idioms-coco3-markers.md`).

Calibration-light per CLAUDE.md §1/§5. No elapsed, no band, no variance.

---

### 1 — Summary

**Q1 turned on a fact neither the dispatch nor PA.1 had considered.** The dispatch framed the question as "can `vibes` fire during ordinary animation?", with the expectation that a bounded special effect means a clean boundary. The answer to *that* question is **yes** — `vibes` is set by drinking a weightlessness potion (`MISC.S:321`) and then held nonzero by a per-frame countdown for up to 200 frames (~20 s at POP's measured 10 fps) while the kid moves and animates normally. On the dispatch's own decision rule that indicates a **non-clean** boundary.

It is nonetheless clean, because the question was one level too shallow. `PAGEFLIP`'s `lda $c05e` is a DHIRES *request*, and on the Apple IIe DHIRES only takes effect when **80COL is on**. The entire source contains exactly **three** 80COL sites: `BOOT.S:33` (off), `UNPACK.S:633` inside `TEXT` (off), `UNPACK.S:644` inside `SETDHIRES` (on). Every animated phase is entered through `TEXT`, so 80COL is off for the whole of gameplay and the `$C05E` write **cannot change the graphics mode**. PA.1's trace corroborates precisely: `80COL_off` at f=2580 and f=7809, immediately before each animated phase; `80COL_on` only at the three `SETDHIRES` moments.

So `vibes` fires during gameplay and is harmless. **B carries no mid-animation mode-flip complexity.**

**Q2 answered cleanly and against the optimistic case.** POP does not move on a coarse grid. `CVTX` (`GRAFIX.S:888-940`) is documented *"Hires scrn: X-coord range 0-279, byte range 0-39"* and converts a full-resolution X into `ByteTable[x]` (x/7) plus `OffsetTable[x]` (x mod 7); `loadobj` stores `objX` and `objOFF` separately per object; the blitter takes `OFFSET` = 0–6 bit shift (`HIRES.S:158-160`). Parsing all 359 frame records in `FRAMEDEF.S` (`Fimage, Fsword, Fdx, Fdy, Fcheck`): the minimum nonzero `|Fdx|` is **1 px**, 33 frames use it, and **72 of the 129 moving frames carry an odd `Fdx`** — including the core run cycle (`run-4`, `run-5` at `Fdx=1`; `run-6` at 3).

**Gate consequence, stated precisely.** Q2 does *not* move PA.3's headline. PA.3's "typical fits with 8% headroom" was computed at the **mixed 32.5 cy/px** assumption — 50/50 aligned/shifted — which is exactly what 1-px motion at 4bpp (2 px per byte) produces. Q2 converts that assumption from a guess into a measured consequence. What it removes is the all-aligned 10 cy/px branch (72% headroom), which was never the headline figure.

---

### 2 — Files modified

**None in `POP3_port` except this report.** No source, engine, HAL, content, coco3 or idioms change. No oracle run; `/c/mame`, Karateka and the probe clone untouched.

**Pool:** one new `live/` row, `a4c01e6` (§10).

---

### 3 — Reasoning

**Authority.** Everything below is a source citation (file:line, quoted) except one corroboration from PA.1's existing trace, which is labelled as such. No appearance claim is made anywhere: Q2 reports position units and integer step counts, never how motion looks. Whether 1-px versus 2-px motion is *visibly* different is Jay's call (§4), and §8 routes it there rather than asserting it.

**Why Q1's obvious answer was wrong, and what caught it.** Tracing "where is `vibes` written" is the correct first move and the dispatch specified it. It yields a complete and accurate picture of the write side — the trigger is real, the countdown is real, it runs in the per-frame loop, and the `PAGEFLIP` branch genuinely executes. Every element checks out at the write site, which is why the wrong conclusion is so plausible. The falsifier is not at the write site at all: it is the *enable*. `$C05E`/AN3 is only a DHGR control while 80COL is on; otherwise it is an annunciator with no effect on the video mode.

That made the decisive evidence an **exhaustive enumeration of a small set** rather than a trace: `grep` for every 80COL access in the whole program returns exactly three sites, all in `BOOT.S`/`UNPACK.S`, none in any gameplay path. Three-of-three is a complete enumeration, not a sample, which is why the source read stands on its own and the trace is corroboration (§6.4). Captured as a pool candidate.

**Why `vibes` is genuinely a gameplay-duration flag, not a one-shot.** `MISC.S:321` sets `vibes = vibetimer = 3` (`MISC.S:255`) in the potion dispatch's weightlessness case, alongside `weightless = wtlesstimer = 200` (`MISC.S:254`). Thereafter `TOPCTRL.S:1685 wtlessflash` — called from the per-frame path at `TOPCTRL.S:656` — decrements `weightless` and rewrites `vibes` each frame:
```
wtlessflash
 lda weightless / beq ]rts       ; inactive -> leave vibes alone
 ldx #0 / sec / sbc #1 / sta weightless
 beq :3                          ; expired -> X=0
 ldx #$ff
 cmp #wtlflash / bcs :3          ; weightless >= 15 -> X=$ff  (steady ON)
 lda vibes / eor #$ff / tax      ; weightless < 15  -> X = ~vibes (alternates)
:3 stx vibes                     ; "Screen flashes as weightlessness ends"
```
So `vibes` is `$ff` for the bulk of the 200-frame window and then **alternates $00/$ff every frame** for the final `wtlflash = 15` frames (`TOPCTRL.S:68`) — the flashing tail. Under the naive reading that would be a mode flip *every frame* during a fall. It is not, because of the enable.

**Two of the five write sites are clears, not triggers.** The dispatch listed four sites; there are five, and only one sets a nonzero start value. `SUBS.S:1247` (`initit`, princess-cut init), `TOPCTRL.S:235` (`initgame`) and `TOPCTRL.S:282` (`RESTART`) all write **A = 0** — they are zeroing sweeps, not triggers. Distinguishing them matters because "four write sites" invites the reading that four game conditions can raise `vibes`; exactly one can.

**Why Q2's granularity is proven rather than inferred.** Three independent source facts agree:
1. `HIRES.S:158-160` — the blitter's documented inputs are `XCO` (byte column 0–39) **and** `OFFSET` (*"# of bits to shift image right (0-6)"*). Sub-byte placement is a first-class blitter feature.
2. `GRAFIX.S:888-940 CVTX` — *"Convert X-coord to byte & offset… Hires scrn: X-coord range 0-279, byte range 0-39"*, via `ByteTable`/`OffsetTable` lookups. The position input is full-resolution pixels.
3. `FRAMEADV.S:718-726 loadobj` — objects carry `objX` **and** `objOFF` as separate stored fields, so sub-byte position is *persisted per object*, not merely computed at draw time.

Then the step size is read directly off the data: `FRAMEDEF.S` frame records are `Fimage, Fsword, Fdx, Fdy, Fcheck`, and `CTRLSUBS.S:807-808` (`lda Fdx / jsr addcharx ;A := CharX + Fdx`) applies it. No unit is inferred.

**What Q2 does and does not imply for the gate.** At 4bpp a CoCo3 byte holds 2 pixels, so odd destination x requires a 4-bit shift. With 56% of moving frames at odd `Fdx` the aligned/shifted split lands near 50/50 — precisely PA.3's mixed assumption. The correct reading is therefore *"Q2 confirms the assumption PA.3 already used"*, not *"Q2 breaks PA.3"*. Byte-aligned blitting remains available as a deliberate **fidelity trade** (snap actors to even pixels), but it is a choice with a motion cost, not a free optimisation — and choosing it is the gate's business, not mine.

---

### 4 — Verification (AC-by-AC)

**AC1 — every `vibes` nonzero-write site enumerated, with value, routine and reaching condition. — MET (five sites, not four).**

| # | site | writes | routine | condition reaching it |
|---|---|---|---|---|
| 1 | `MISC.S:321` | `#vibetimer` = **3** | potion dispatch, case 3 "Weightless" | kid **drinks a weightlessness potion**; also sets `weightless = wtlesstimer = 200` |
| 2 | `TOPCTRL.S:1699` | `X` ∈ {0, `$ff`, `~vibes`} | `wtlessflash` (per-frame, called `TOPCTRL.S:656`) | while `weightless != 0`; `$ff` steady while `weightless ≥ 15`, alternating below |
| 3 | `SUBS.S:1247` | **0** | `initit` (princess-cut init) | **clear**, not a trigger |
| 4 | `TOPCTRL.S:235` | **0** | `initgame` | **clear** |
| 5 | `TOPCTRL.S:282` | **0** | `RESTART` (level restart) | **clear** |

Reads: `SUBS.S:408` (`PAGEFLIP`) and `TOPCTRL.S:1696` (the countdown's own read). Declaration `GAMEEQ.S:534 vibes ds 1`. Constants: `vibetimer = 3` (`MISC.S:255`), `wtlesstimer = 200` (`MISC.S:254`), `wtlflash = 15` (`TOPCTRL.S:68`).

**What `vibes` represents:** a **screen-shake/flash effect flag for the weightlessness potion**, held for the potion's duration and pulsed at its expiry. The `TOPCTRL.S:1699` comment ("Screen flashes as weightlessness ends") describes only the final 15-frame tail; the flag is set for the whole ~200-frame window.

**AC2 — the decisive yes/no. — MET, and it splits.**
- **Can `vibes` be nonzero during ordinary actor animation?** **YES.** Duration ~200 frames (≈20 s at POP's measured 10 fps), during which the kid moves and animates normally; `$ff` steady for the first ~185, alternating every frame for the last 15.
- **Does that make the HGR/DHGR boundary non-clean?** **NO — the write is inert.** DHIRES requires 80COL on. Exhaustive enumeration of every 80COL access in the source:
```
BOOT.S:33     sta $c00c ;80col off      (boot)
UNPACK.S:633  sta ADCOLoff              (inside TEXT     -> OFF)
UNPACK.S:644  sta ADCOLon               (inside SETDHIRES -> ON)
```
Three sites, total. Every animated phase is entered via `TEXT` (PA.1's mode map), so 80COL is **off** throughout gameplay and `$C05E` sets only the AN3 annunciator. Corroborated by PA.1's trace:
```
f=2580  80COL_off pc=$ECBC     <- immediately before the princess animation (f=2686+)
f=7809  80COL_off pc=$ECBC     <- immediately before the Demo (f=7935+)
f=304 / 5750 / 11062  80COL_on pc=$ECCC   <- only at SETDHIRES
```
**Verdict: the boundary is clean. B carries no mid-animation mode-flip cost.**

**AC3 — `CharX` units and update path. — MET.**
`CharX ds 1` (`GAMEEQ.S:568`), `CharXVel ds 1` (`:574`), `FCharX ds 2` (`:636`), `CharPosn ds 1` (`:567`). `addcharx` is a jump-table slot (`GAMEEQ.S:226 ds 3`); it is invoked as `lda Fdx / jsr addcharx ;A := CharX + Fdx` (`CTRLSUBS.S:807-808`), with the direction-aware form at `CTRLSUBS.S:338 adc Fdx ;Fdx (+ = fwd, - = bkwd)` and a 2-byte variant `ADDFCHARX` (`CTRLSUBS.S:887-888`).

**Horizontal position is whole-pixel, with sub-byte placement preserved through to the blitter** — not a position index, and not sub-pixel fixed-point. Evidence: `CVTX` takes an X-coord in **0–279** and emits byte + offset (`GRAFIX.S:888-940`); `loadobj` stores `objX` and `objOFF` as separate per-object fields (`FRAMEADV.S:718-726`); the blitter accepts `OFFSET` = 0–6 (`HIRES.S:158-160`).

**AC4 — the step distribution, and the quantization verdict. — MET.** All 359 `FRAMEDEF.S` frame records parsed:

| `Fdx` (px) | frames | share | examples |
|---:|---:|---:|---|
| −5 | 2 | 0.6% | drink17, drink18 |
| −4 | 6 | 1.7% | drink11–13 |
| −2 | 11 | 3.1% | jumphang-2, -3, -5 |
| −1 | 15 | 4.2% | jumphang-4, -9, -10 |
| **0** | **230** | **64.1%** | run-8, run-9, run-10 |
| **1** | **18** | **5.0%** | **run-4, run-5**, turn-10 |
| 2 | 24 | 6.7% | jumphang-11–13 |
| 3 | 21 | 5.8% | **run-6**, turn-8, hangdrop-4 |
| 4 | 14 | 3.9% | run-7, turn-7, hangdrop-8 |
| 5 | 7 | 1.9% | climbup-34–36 |
| 7 | 9 | 2.5% | jumphang-22, -23, guy-7 |
| 10 | 2 | 0.6% | full ext., guy-6 |

- **Minimum nonzero |`Fdx`| = 1 px**; 33 frames use it.
- 129 of 359 frames move; **72 of those 129 (55.8%) have an odd |`Fdx`|**.
- `CharX` → pixel column at draw time via `CVTX` → (byte, 0–6 offset); no snapping anywhere in the path.

**Would 2-pixel quantization visibly alter POP's motion?** **It would alter the motion data**, which is the measurable half of the question. Over half of all moving frames land on positions a 2-px grid cannot represent, and the core run cycle opens `1, 1, 3, 4` — under even-only placement those become `0/2, 0/2, 2/4, 4`, changing both per-frame displacement and cycle phase. Whether the resulting difference is *perceptible* is a visual judgement and is Jay's (§7.3, §8). **The engine is emphatically not already quantized**: sub-byte placement is a designed, persisted, first-class feature of POP's renderer.

**AC5 — gate-input update. — MET, in §8, indication only.**

**AC6 — no source/engine/HAL/content/coco3 change; status clean except standing untracked. — MET.**

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output — APPLIES in the limited form §7 allows.** No emulator was run. The evidence is source citations (quoted throughout §4) plus one fresh analysis run: the `FRAMEDEF.S` parse of all 359 frame records, output verbatim in AC4/Appendix B. PA.1's trace lines in AC2 are a re-read of an existing log, labelled as such.

**25.2 — N/A.** Nothing built or imaged.

**25.3 — N/A as a gate.** No visual output; no appearance claim. Q2 reports position units and integer step counts only. The perceptibility of 1-px versus 2-px motion is explicitly left to Jay (§8 follow-up 2).

**C-35 presence check — SATISFIED.** §0 quotes verbatim `t0=2026-07-25T06:10:12Z` and HEAD. No elapsed, no band, no variance.

**Capture presence check — SATISFIED.** §10 carries one slug.

---

### 6 — Reactive deviations

**6.1 — Q1's answer inverts the dispatch's own decision rule, and the rule's premise was too shallow. (Most important finding.)**
§5.3 sets: "`vibes` fires only in a bounded effect / never during ordinary animation ⇒ clean boundary" versus "can fire during normal animation ⇒ B must handle mid-animation mode flips". Measured against that rule the answer is the *second* — `vibes` is nonzero for ~200 frames of ordinary gameplay. But the rule assumes a nonzero `vibes` produces a mode flip, and it does not: DHIRES is gated by 80COL, which is off throughout gameplay. Both halves must be reported or the conclusion inverts. **The boundary is clean despite `vibes` firing during animation.** Captured as a pool candidate.

**6.2 — Five `vibes` write sites, not four; three of them write zero.**
The dispatch named `MISC.S:321`, `SUBS.S:1247`, `TOPCTRL.S:235`, `TOPCTRL.S:282`. There is a fifth, `TOPCTRL.S:1699` (`stx vibes` in `wtlessflash`) — and it is the *only* one besides `MISC.S:321` that can write nonzero. Of the dispatch's four, three (`SUBS.S:1247`, `TOPCTRL.S:235`, `TOPCTRL.S:282`) write **A = 0** and are zeroing sweeps in init/restart paths. Exactly **one** game condition raises `vibes`: drinking a weightlessness potion.

**6.3 — Q2 removes an optimistic branch but does not move PA.3's headline; stated explicitly to prevent a misread.**
It would be easy to read "1-px motion ⇒ byte alignment unavailable ⇒ PA.3's fit collapses". It does not. PA.3's headline (164,580 cyc, 8% headroom) used the **mixed 32.5 cy/px** assumption, and 1-px motion at 4bpp is exactly what produces a ~50/50 aligned/shifted split — Q2 *validates* that assumption. Only the all-aligned 10 cy/px case (72% headroom) is ruled out, and it was never the headline. Recorded because the opposite reading would wrongly swing the gate toward B.

**6.4 — I consulted PA.1's trace rather than running the oracle, and the source read stands alone.**
§6 permits a headless confirmation if a point genuinely needs it. It did not: three 80COL sites in the entire program is a complete enumeration, not a sample. PA.1's existing log was re-read as corroboration at zero cost. No emulator was launched and no `.hdv` md5 gate was therefore required (§0).

**6.5 — `addcharx`'s implementation body was not located; the behaviour is read from its call sites.**
`addcharx` is a jump-table slot (`GAMEEQ.S:226 ds 3`) and its implementing label is not present under `01 POP Source/Source/` by that name. Its semantics are taken from the call sites, which are explicit: `CTRLSUBS.S:807-808` (`lda Fdx / jsr addcharx ;A := CharX + Fdx`) and `CTRLSUBS.S:338` (`adc Fdx ;Fdx (+ = fwd, - = bkwd)`). **This is an inference from callers, flagged per §10.** It does not affect the Q2 verdict, which rests on `CVTX`, `loadobj`, `HIRES.S`'s documented `OFFSET`, and the `Fdx` data — none of which depend on `addcharx`'s body.

**6.6 — `CharX` is one byte but `CVTX` takes a two-byte X-coord; the relationship was not fully traced.**
`CharX ds 1` (0–255) cannot by itself span the 0–279 range `CVTX` accepts, and `FCharX ds 2` exists alongside it. The likely reading is that `CharX` is room-relative and expanded to a screen coordinate downstream, with `objX`/`objOFF` carrying the byte/offset pair. **Not proven**, and reported as a gap. It does not change the granularity finding — `objOFF` and the 0–6 blitter shift establish sub-byte placement regardless of how `CharX` is scaled.

**6.7 — `Fdx` values are signed and were decoded as such.** Values > 127 are treated as negative (`−1`, `−2`, `−4`, `−5` appear, consistent with `CTRLSUBS.S:338`'s "+ = fwd, − = bkwd"). The parser skips any record whose `Fdx` field is a symbol rather than a literal; all 359 parsed records had literal fields, and 359 is consistent with the file's frame count.

---

### 7 — Uncertainty flags

1. **`addcharx`'s body is inferred from callers** (§6.5) — the strongest-labelled inference in this report, though not load-bearing for either verdict.
2. **The `CharX` (1 byte) ↔ `CVTX` (2 byte) relationship is untraced** (§6.6).
3. **Perceptibility is not established.** Q2 proves the motion *data* changes under 2-px quantization; whether that is *visible* is Jay's, and this report deliberately does not assert it.
4. **`vibes`'s AN3 write is inert on a stock IIe; on an RGB card it is not.** AN3 toggling is how an Apple RGB card switches its display mode (`UNPACK.S:651`'s own comment, ";for old Apple RGB card"). On such hardware the weightlessness effect presumably *does* something visible. Out of scope for a CoCo3 port, but it means "inert" is hardware-conditional, not absolute.
5. **`Fdx` is the kid's/actors' frame delta; guards may use other tables.** The 359 records are `FRAMEDEF.S`'s full set, which the naming suggests spans all characters, but per-character attribution was not established.
6. **Vertical granularity was not examined** — only horizontal was asked. If `Fdy` has an analogous constraint it is unmeasured here (the data is in the same records).

---

### 8 — Follow-up candidates

**Gate-input update (§5.3 — INDICATION ONLY; Jay decides at §9.10):**

- **Q1 lowers B's cost.** B's mode boundaries are **clean**: no mid-animation mode flip exists, because 80COL is off for the whole of gameplay. B's transition handling is limited to the phase boundaries PA.1 already mapped (blackout → `TEXT` → mode set), which are few and already quiescent. The `vibes` complication is **not real**.
- **Q2 does not weaken C-16.** The alignment tax is real in the sense that all-aligned blitting is unavailable — POP genuinely moves at 1 px and 56% of moving frames are odd — but PA.3's fit already assumed the mixed case that 1-px motion produces. **C-16 still fits typical at 8% headroom; the 72%-headroom optimistic case is withdrawn.**
- **What Q2 *does* do is remove a free lunch.** Byte-aligned blitting remains available as a deliberate **fidelity trade** — snap actors to even pixels, gain ~3× on blit cost, coarsen motion on over half the moving frames. That is now a stated, priced option rather than an assumed optimisation.
- **Net: unchanged in shape, firmer in both directions.** C-16 fits at mixed alignment with a thin margin; B is cheaper than feared because its boundaries are clean. The decision still turns on how much the 8% margin is trusted (PA.3 §6.6: it is inside the model's own error) and on whether 2-px motion quantization is acceptable — **the latter being a visual judgement only Jay can make.**

**Ordered follow-ups:**
1. **Jay's ruling on 2-px motion quantization** — the one input neither measurement nor source reading can supply, and it now sits directly on the gate's critical path.
2. **Measure POP's actual simultaneous-actor count** — still M2's dominant remaining uncertainty (PA.3 §6.7), unchanged by this dispatch.
3. **Cycle-exact validation of the blit cost** (PA.2 §6.6) — the largest systematic uncertainty in the 8% margin.
4. **Trace the `CharX` ↔ `CVTX` scaling** (§6.6) and locate `addcharx`'s body (§6.5) if the gate needs the position model in more detail.
5. **`Fdy` / vertical granularity** (§7.6), if vertical alignment ever matters.
6. Standing: `POP-idioms-coco3-markers.md` disposal; the POP-level `.gitattributes` task.

---

### 9 — User interaction during task

**None.** No question asked; bridge-safe-equiv. Every judgment call — reporting Q1's inversion of the dispatch's own rule (§6.1), the fifth write site (§6.2), the explicit anti-misread on PA.3's headline (§6.3), declining an oracle run (§6.4), and flagging the two inferences (§6.5/§6.6) — is surfaced in §6 for post-hoc ruling.

---

### 10 — Candidate(s) captured this task

One new `live/` row, pushed in pool commit `a4c01e6`:

- `seeds/POP/live/2026-07-25-a-register-write-is-inert-without-its-enabling-precondition.md` — a hardware register write means nothing until its **enabling precondition** is traced; a live-looking conditional branch can be entirely inert because a separate enable is off, and nothing at the write site says so (from §6.1). `initiator: executor`.

`seeds/POP/live/` now holds **nineteen** POP rows.

---

### 11 — Commit

- **This report's commit** — on `wip`, pushed to `origin/wip` before reporting back. Hash in the accompanying reply.
- **No other `POP3_port` commit** — source reading only, per §9 of the dispatch.
- **Pool:** `a4c01e6`.

---
---

## Appendix A — Q1 source evidence, verbatim

### A.1 — the trigger (`MISC.S:313-323`), potion case 3
```
* Weightless (3)

:3 cpx #3
 bne :4
 lda #s_ShortPot
 ldx #25
 jsr cuesong
 lda #wtlesstimer
 sta weightless
 lda #vibetimer
 sta vibes
 rts
```
`wtlesstimer = 200` (`MISC.S:254`), `vibetimer = 3` (`MISC.S:255`).

### A.2 — the per-frame countdown (`TOPCTRL.S:1685-1700`), called from `TOPCTRL.S:656`
```
wtlessflash
 lda weightless
 beq ]rts
 ldx #0
 sec
 sbc #1
 sta weightless
 beq :3
 ldx #$ff
 cmp #wtlflash
 bcs :3
 lda vibes
 eor #$ff
 tax
:3 stx vibes ;Screen flashes as weightlessness ends
]rts rts
```
`wtlflash = 15` (`TOPCTRL.S:68`).

### A.3 — the consumer (`SUBS.S:403-418`, `PAGEFLIP`)
```
E1DB: AD 18 03   408  lda vibes
E1DE: F0 04      409  beq :rts
E1E0: AD 5E C0   410  lda $c05e      ; vibes != 0 -> DHIRES ON  (inert while 80COL off)
E1E3: 60         411 ]rts rts
E1E4: AD 5F C0   412 :rts lda $c05f  ; vibes == 0 -> DHIRES OFF
```

### A.4 — the enable: every 80COL site in the program
```
BOOT.S:33     sta $c00c ;80col off
UNPACK.S:633  sta ADCOLoff       (TEXT)
UNPACK.S:644  sta ADCOLon        (SETDHIRES)
```
Three sites, exhaustive. Corroboration from PA.1's trace:
```
f=45    80COL_off pc=$203D
f=141   80COL_off pc=$ECBC
f=304   80COL_on  pc=$ECCC        <- SETDHIRES (titles)
f=2580  80COL_off pc=$ECBC        <- before princess animation (f=2686+)
f=5599  80COL_off pc=$ECBC
f=5750  80COL_on  pc=$ECCC        <- SETDHIRES (Prolog2)
f=7809  80COL_off pc=$ECBC        <- before Demo (f=7935+)
f=10899 80COL_off pc=$ECBC
f=11062 80COL_on  pc=$ECCC        <- SETDHIRES (attract loop 2)
```

---

## Appendix B — Q2 source evidence, verbatim

### B.1 — the blitter's documented placement inputs (`HIRES.S:158-160`)
```
*  XCO         Screen X-coord (0=left, 39=right)
*  YCO         Screen Y-coord (0=top, 191=bottom)
*  OFFSET      # of bits to shift image right (0-6)
```

### B.2 — full-resolution X → byte + offset (`GRAFIX.S:888-940`, `CVTX`)
```
*  Convert X-coord to byte & offset
*  Works for both single & double hires
*  In: XCO/OFFSET = X-coord (2 bytes)
*  Out: XCO/OFFSET = byte/offset
*  Hires scrn: X-coord range 0-279, byte range 0-39
*  Dbl hires scrn: X-coord range 0-559, byte range 0-79
...
:ok ldy ]XL
 lda ByteTable,y
 clc
 adc ]temp
 sta XCO
 lda OffsetTable,y
 sta OFFSET
```

### B.3 — sub-byte position persisted per object (`FRAMEADV.S:718-726`, `loadobj`)
```
loadobj
 lda objX,x
 sta FCharX
 sta XCO
 lda objOFF,x
 sta OFFSET
```

### B.4 — the frame record and its application
```
FRAMEDEF.S:21  *  Fimage, Fsword, Fdx, Fdy, Fcheck
FRAMEDEF.S:23  :1 db $01,0,1,0,$c0+4 ;run-4      <- Fdx = 1
FRAMEDEF.S:24  :2 db $02,0,1,0,$40+4 ;run-5      <- Fdx = 1
FRAMEDEF.S:25  :3 db $03,0,3,0,$40+7 ;run-6      <- Fdx = 3
FRAMEDEF.S:26  :4 db $04,0,4,0,$40+8 ;run-7      <- Fdx = 4

CTRLSUBS.S:338   adc Fdx ;Fdx (+ = fwd, - = bkwd)
CTRLSUBS.S:807   lda Fdx
CTRLSUBS.S:808   jsr addcharx ;A := CharX + Fdx
CTRLSUBS.S:887   lda Fdx
CTRLSUBS.S:888   jsr ADDFCHARX ;A := FCharX + Fdx
```

### B.5 — the parsed distribution (all 359 records)
```
frame records parsed: 359

Fdx (px)  frames   share   examples
      -5       2    0.6%   drink17, drink18
      -4       6    1.7%   drink11, drink12, drink13
      -2      11    3.1%   jumphang-2, jumphang-3, jumphang-5
      -1      15    4.2%   jumphang-4, jumphang-9, jumphang-10
       0     230   64.1%   run-8, run-9, run-10
       1      18    5.0%   run-4, run-5, turn-10
       2      24    6.7%   jumphang-11, jumphang-12, jumphang-13
       3      21    5.8%   run-6, turn-8, hangdrop-4
       4      14    3.9%   run-7, turn-7, hangdrop-8
       5       7    1.9%   climbup-34, climbup-35, climbup-36
       7       9    2.5%   jumphang-22, jumphang-23, guy-7
      10       2    0.6%   full ext., guy-6 (full ext)

nonzero-dx frames: 129 of 359
minimum nonzero |Fdx| = 1 px
frames with |Fdx| == 1 : 33
frames with |Fdx| odd  : 72
frames with |Fdx| even : 57
```

---

*End of report.*
