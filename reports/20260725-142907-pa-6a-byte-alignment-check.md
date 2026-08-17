## Form B Report — PA.6a — does the oracle already draw byte-aligned?
**Class:** recon — INSTRUMENT + MEASURE ONLY. wip. **Prod byte-identity: N/A.**

> ## ANSWER: **NO — the original draws the prince SUB-BYTE.**
> Across 681 captured kid draws, **all seven offsets 0–6 are used**, and **36.4% land on odd offsets**. The prince is not drawn on byte boundaries.
> **Byte-alignment on CoCo3 is therefore a real visual change, not free fidelity.** §5.23's tradeoff stays live and the judgment is Jay's.
> **And it is larger than previously stated.** PA.4's "2-px quantization" was derived when C-16 (4bpp, 2 px/byte) was the live mode. B is the **4-colour** mode — 2bpp, **4 px/byte** — so byte-aligning quantizes to **4 pixels**, double the figure that has been in circulation (§6.2).

---

### 0 — Receipt / status (C-35 stamp)

```
t0=2026-07-25T18:24:06Z
```

**HEAD at t0:** `7d15937e06c91c25bf3d7255f0fec87e5c0cdf33` (branch `wip`, no tracked file modified).
**HEAD at report time:** same — this dispatch produced no commit other than the report.

**§10 hard-stop gates — all three PASS:**
```
vendored source last touched by : ba6154e "P1.1a: vendor oracle buildable-whole @ ec78dbf"
PROVENANCE pin                  : ec78dbfd51013ba349cda8c51c3ce0595fe75342
oracle .hdv md5                 : c4f0b13e49b77dd0fbc5063e27e53a24        -> PASS
CFFA2 ROM (hard-stop #3)        : 1 romsets found, 1 were OK              -> PASS, not blocked
```
**§0(a).4 read points:** idioms §0 (mount), §1/§1a (read-tap semantics — load-bearing: the step marker is a **read** tap, the three capture taps are **write** taps).

**`git status` at end:** no tracked file modified; 18 untracked (standing 16 + `POP-idioms-coco3-markers.md` + `.vscode/`).

Calibration-light per CLAUDE.md §1/§5. No elapsed, no band, no variance.

---

### 1 — Summary

The dispatch was right that this cannot be answered from source: `ByteTable`/`OffsetTable` are generated, so the offsets POP actually uses only exist at runtime.

**Capture.** `ADDMID` (`GRAFIX $059C`) writes, in fixed order per call with X = mid-list index: `midTYP` (`$05A4`), `midOFF` (`$05AE` — the CVTX sub-byte offset), and `midTAB` (`$05BD` — the image table). Three write taps keyed on those exact PCs reconstruct every mid-plane draw as a `(type, offset, table)` triple, with no sampling. 1,938 entries captured across 300 emulated seconds.

**Self-test passed:** every captured offset fell in **0–6**, exactly the range `CVTX` documents as its output (`GRAFIX.S:895`, *"Hires scrn: X-coord range 0-279, byte range 0-39"*). A tap reading the wrong location would not land inside that range.

**Identification.** `midTYP` bit 7 = char tables, low bits 2 = `lay+layrsave` — characters. 1,778 of 1,938 entries are `midTYP=$82`. `midTAB` is a **0-based index** into `chtablist` (`setcharimg`: `ldy TABLE / lda chtablist,y`), so **indices 0/1/2 = CHTAB1/2/3 = the kid**, index 3 = CHTAB4.* = guards/shadow/skeleton. That yields **681 kid draws**.

**Result.** The kid uses **every offset from 0 to 6**: `0:110 1:87 2:98 3:111 4:136 5:50 6:89`. **248 of 681 (36.4%) are odd.** Guards are similar at 50.6% odd. Every character table in the capture uses all seven offsets. The original is emphatically not byte-quantized on screen.

**Consequence for the port.** Byte-alignment is a genuine fidelity change, so PA.6's "close the 1.37× per-byte blit gap" cannot be achieved for free by simply dropping the shifter. And the change is **4 pixels** in B's 2bpp mode, not the 2 px figure inherited from the C-16-era analysis — a distinction I flag rather than resolve, because it makes Jay's visual judgment a coarser one than previously framed.

---

### 2 — Files modified

**None in `POP3_port` except this report.** No source, engine, HAL, content, coco3 or idioms change. No oracle rebuild. `/c/mame`, Karateka and the probe clone untouched.

No §2A.3 idiom filed — fifth consecutive deferral pending the authorship ruling (§6.5).

**Pool:** one new `live/` row, `d1991a2` (§10).

---

### 3 — Reasoning

**Authority.** Every number here is a captured memory write or a source citation. No appearance claim: the report states offset values, and explicitly does **not** say whether the resulting motion looks smooth or stepped — that is the judgment this measurement exists to inform, and it is Jay's (§7, CLAUDE.md §4).

**Why the capture is exact rather than sampled.** `ADDMID` is the single funnel through which every mid-plane image enters the draw list, and it writes the three fields I need at three fixed PCs in a fixed order within one call. Keying the taps on `CURPC` rather than on the address range alone excludes any other writer of those tables, and assembling the triple on the third write guarantees the fields belong to the same call. There is no decimation and no inference.

**Why `midTAB` is the right discriminator, and how I avoided getting it wrong.** My first analysis assumed `midTAB` held the table's high byte (`$60`, `$84`, `$96` …) and produced **zero** kid draws — an obviously broken result rather than a plausible wrong one, which is what made it safe. Reading `setcharimg` (`GRAFIX.S:853-866`) settled it: `ldy TABLE / lda chtablist,y` means `TABLE` is a 0-based *index*, and the observed values 0–6 map onto `chtable1`–`chtable7`. Combined with PA.3's asset inventory (CHTAB1/2/3 = kid animation; CHTAB4.* = FAT/GD/SHAD/SKEL/VIZ = guards and other antagonists), the kid is indices 0/1/2. Had the mis-mapping produced a *plausible* count instead of zero, it would have been much harder to catch.

**What the offset actually means.** `CVTX` splits a 0–279 Apple X-coordinate into `ByteTable[x]` (byte column, 0–39) and `OffsetTable[x]` (0–6, the sub-byte pixel shift within a 7-pixel HGR byte). An offset of 0 means the sprite starts exactly on a byte boundary; any other value means it starts mid-byte and the blitter must shift. So the offset distribution *is* the answer to "does the game draw byte-aligned" — and a distribution spanning all seven values with no clustering at 0 is as clear a negative as the measurement can give.

**Why the guard figure is worth reporting alongside.** Guards are 50.6% odd against the kid's 36.4%. Both use all seven offsets, so nothing about the conclusion depends on which character is examined — the result is robust to any residual error in my kid/guard identification.

---

### 4 — Verification (AC-by-AC)

**AC1 — method + self-test. — MET.** Three **write** taps keyed on PC, plus a **read** tap on `$C05F` for the step boundary (idioms §1a):
```
$05A4  sta midTYP,x  ($B36B+x)   type: bit7 = char tables; low bits 2 = lay+layrsave
$05AE  sta midOFF,x  ($B2B3+x)   THE SUB-BYTE OFFSET (CVTX output)
$05BD  sta midTAB,x  ($B451+x)   image-table index -> which character
```
**Self-test, verbatim:**
```
rows=1938  min=0  max=6  (CVTX documents 0-6)
  OFFSET=0 : 371    OFFSET=1 : 270    OFFSET=2 : 284    OFFSET=3 : 376
  OFFSET=4 : 278    OFFSET=5 : 117    OFFSET=6 : 242
```
Every value inside `CVTX`'s documented output range; no value out of band; the tap demonstrably fires.

**AC2 — the offset sequence, verbatim. — MET.** By image table (character entries, `midTYP=$82`):
```
CHTAB1 (KID)                  n= 180  [0:31 1:21 2:13 3:31 4:38 5:18 6:28]  odd=38.9%  distinct=[0,1,2,3,4,5,6]
CHTAB2 (KID)                  n=  54  [0:18 1:6  2:10 3:10 4:4  5:4  6:2 ]  odd=37.0%  distinct=[0,1,2,3,4,5,6]
CHTAB3 (KID)                  n= 447  [0:61 1:60 2:75 3:70 4:94 5:28 6:59]  odd=35.3%  distinct=[0,1,2,3,4,5,6]
CHTAB4.* (GUARD/shadow/skel)  n= 269  [0:58 1:90 2:19 3:24 4:39 5:22 6:17]  odd=50.6%  distinct=[0,1,2,3,4,5,6]
CHTAB5                        n= 192  [0:17 1:41 2:25 3:17 4:65 5:3  6:24]  odd=31.8%  distinct=[0,1,2,3,4,5,6]
CHTAB6                        n= 620  [0:26 1:46 2:142 3:222 4:34 5:38 6:112] odd=49.4% distinct=[0,1,2,3,4,5,6]
CHTAB7                        n=  16  [0:0  1:6  2:0  3:2  4:4  5:4  6:0 ]  odd=75.0%  distinct=[1,3,4,5]

*** THE KID (CHTAB1/2/3) ***  n= 681  [0:110 1:87 2:98 3:111 4:136 5:50 6:89]  odd=36.4%  distinct=[0,1,2,3,4,5,6]
```
A consecutive stretch, showing the offset changing frame to frame:
```
  step   450  frame   9874  OFFSET=6      step   455  frame   9911  OFFSET=3
  step   450  frame   9874  OFFSET=1      step   455  frame   9911  OFFSET=0
  step   451  frame   9881  OFFSET=4      step   456  frame   9919  OFFSET=4
  step   451  frame   9881  OFFSET=2      step   456  frame   9919  OFFSET=6
  step   452  frame   9889  OFFSET=4      step   457  frame   9927  OFFSET=5
  step   452  frame   9889  OFFSET=6      step   457  frame   9927  OFFSET=6
  step   453  frame   9896  OFFSET=4      step   458  frame   9934  OFFSET=0
  step   453  frame   9896  OFFSET=6      step   458  frame   9934  OFFSET=5
  step   454  frame   9903  OFFSET=5      step   459  frame   9942  OFFSET=4
  step   454  frame   9903  OFFSET=6      step   459  frame   9942  OFFSET=6
```

**AC3 — correlation with `Fdx`. — PARTIALLY MET (§6.3).** The direct pairing the AC asks for — this frame's `Fdx` beside this frame's `OFFSET` — was **not** captured: `Fdx` is consumed inside `addcharx` to update `CharX`, and I did not tap the animation-frame index that would identify which `FRAMEDEF` record was active. What the data does establish is the substantive point the correlation was meant to test:

- PA.4 measured the logical motion: minimum nonzero `|Fdx|` = **1 px**, with the run cycle opening `1,1,3` and 56% of moving frames on odd deltas.
- PA.6a measures the drawn result: the kid's `OFFSET` takes **all seven values including odd ones**, changing frame to frame (stretch above).

So 1-px logical motion produces **changing sub-byte draw offsets** — it is *not* absorbed into byte-column steps with `OFFSET` pinned at 0 or even. That is the disjunction §5.2 posed, resolved. The per-frame pairing would sharpen it but cannot change it: a byte-quantized renderer cannot produce odd offsets at all, let alone 36.4% of the time.

**AC4 — the plain answer. — MET.**
```
kid draws captured : 681
EVEN offsets       :  433 (63.6%)
ODD  offsets       :  248 (36.4%)
distinct offsets   : [0, 1, 2, 3, 4, 5, 6]
-> SUB-BYTE: the original draws the prince at odd sub-byte offsets
```
**The original is NOT byte-aligned.** Byte-alignment on CoCo3 is a real visual change requiring Jay's judgment; it is not fidelity-free, and §5.23 option 1 does not collapse into "simply correct".

**AC5 — prince identified, and how. — MET.** Two-stage, both from source:
1. **Character vs scenery:** `midTYP` bit 7 = char tables, low bits = 2 = `lay+layrsave` (`GRAFIX.S:719-722`, *"2 = use lay with layrsave (normal for characters)"*). 1,778 of 1,938 entries are `$82`. Corroborated structurally — PA.6 measured `peel` count ≡ `mid` count, and `layrsave` is exactly what creates a peel entry.
2. **Kid vs guard:** `midTAB` is a 0-based index into `chtablist` (`setcharimg`, `GRAFIX.S:853-866`). Indices 0/1/2 = CHTAB1/2/3 = kid animation; 3 = CHTAB4.* = guards/shadow/skeleton (PA.3's asset inventory). Kid = 681 draws; guards = 269.
**The conclusion does not depend on this split** — every character table uses all seven offsets (AC2), so any residual mis-identification leaves the answer unchanged.

**AC6 — no source/engine/HAL/content/coco3 change; status clean except standing untracked. — MET.**

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output — APPLIES, satisfied.** `Average speed: 1526.17% (299 seconds)`, 1,939 rows; self-test and full distributions quoted verbatim in AC1/AC2 and Appendix A.

**25.2 — N/A.** Nothing built or imaged.

**25.3 — N/A as a gate.** `OFFSET` is a captured memory value. **No appearance claim is made** — this report deliberately does not say whether the motion looks smooth or stepped. That judgment is Jay's, and it is precisely what this measurement is meant to inform.

**C-35 presence check — SATISFIED.** §0 quotes verbatim `t0=2026-07-25T18:24:06Z` and HEAD.

**Capture presence check — SATISFIED.** §10 carries one slug.

---

### 6 — Reactive deviations

**6.1 — The answer is the one that keeps the decision open, and it is unambiguous.** All seven offsets, 36.4% odd for the kid, all seven tables using all seven values. There is no reading of this data under which the original is byte-quantized. The hoped-for collapse of §5.23 into "byte-alignment is free fidelity" does not happen.

**6.2 — The alignment tax is 4 px in mode B, not the 2 px in circulation. (Flagged, not resolved.)**
PA.4 established byte-alignment's cost as "2-pixel horizontal quantization" — correctly, **under C-16**: 16 colours = 4bpp = 2 px/byte. PA.5 then eliminated C-16 and B became the mode. **B is 4 colours = 2bpp = 4 px/byte** (Karateka's `gfx.s`: *"CoCo3 2bpp, 4 pixels per byte"*, *"Row stride is 80 bytes (320px / 4px per byte)"*). So under B, byte-aligning quantizes horizontal position to **4 pixels**. The figure was right when derived and became stale when the branch it assumed was withdrawn. **This doubles the visual magnitude of the judgment Jay is being asked to make**, and I surface it rather than fold it into the answer because it changes the question's stakes, not its answer. Captured as a pool candidate.

For completeness: Karateka's blit already implements four sub-byte phases at 2bpp (`subbyte=0..3`, 2-bit units), so 1-px placement is *available* in B — byte-alignment would be a deliberate choice to use only phase 0, not a limitation.

**6.3 — The per-frame `Fdx`↔`OFFSET` pairing (AC3) was not captured.** `Fdx` is consumed inside `addcharx`, whose body PA.4 §6.5 already recorded as not locatable under `01 POP Source/Source/` by that name; pairing would have required also tapping the active animation-frame index. I captured the drawn offsets only. The substantive disjunction §5.2 posed is nonetheless resolved (AC3 reasoning), and the missing pairing cannot overturn it. Reported as a genuine partial rather than dressed as complete.

**6.4 — My first `midTAB` mapping was wrong, and the failure was loud rather than quiet.** I assumed `midTAB` stored the table's high byte (`$60`/`$84`/`$96`, from `chtablist db #>chtable1,…`); that yielded **zero** kid draws — an obviously broken result. `setcharimg` showed `TABLE` is a 0-based index. Recorded because the near-miss is instructive: had the wrong mapping produced a plausible non-zero count, the report would have been confidently wrong about which character it measured. The conclusion happened not to depend on it (§AC5), but that was luck, not design.

**6.5 — No idiom filed; fifth consecutive deferral.** The ADDMID triple-tap (PC-keyed write taps reconstructing a structured draw-list record with no sampling) is reusable oracle instrumentation qualifying under §2A.3. Not filed — the authorship ruling requested in the oracle-run report §6.3 and deferred in PA.3 §6.8, PA.5 §6.7 and PA.6 §6.6 remains outstanding. **Five techniques are now queued behind one ruling.**

**6.6 — Two kid draws per animation step are common** (visible in AC2's stretch: step 451 shows `OFFSET=4` and `OFFSET=2` for the same table). The kid is composed of more than one mid-plane image per frame. Not investigated — it does not affect the offset distribution — but it is consistent with PA.6's measured mid-plane count of ~2 per frame and worth knowing before anyone models "one cel per character".

---

### 7 — Uncertainty flags

1. **The `Fdx`↔`OFFSET` per-frame pairing is absent** (§6.3). The disjunction is resolved; the frame-by-frame demonstration is not.
2. **Motion type not isolated.** §2(a) asked for a run cycle and ideally a jump and a turn. I sampled 300 s of attract demo and captured 681 kid draws across whatever it exercised; I did not identify which draws belong to running vs jumping vs turning. The offset distribution is aggregate.
3. **Kid/guard identification rests on the CHTAB1/2/3-vs-4 convention** (PA.3's inventory + `chtablist` ordering), not on a runtime character ID. §AC5 shows the conclusion is insensitive to it.
4. **Attract demo, one seed** (idioms §3). 681 kid draws over ~5 minutes of emulated play is a good sample of this run.
5. **`OFFSET` is the *sub-byte* component only.** I did not capture the byte column (`midX`), so this report says nothing about absolute screen position or its evolution — only about sub-byte alignment, which is the question asked.
6. **CHTAB5/6/7 are labelled by index, not identified.** CHTAB6 carries 620 character-typed draws — more than the kid — but what it depicts was not established (PA.3 classified 5/6/7 as "environment/other"). Immaterial here; flagged as a loose end.

---

### 8 — Follow-up candidates

**The fact, for the decision (statement only — §5.23 is Jay's):**

- **The original draws the prince sub-byte.** All seven offsets, 36.4% odd. Byte-alignment on CoCo3 changes what is drawn.
- **Under mode B the change is 4-pixel quantization**, not 2-px (§6.2). Jay's "looks and feels right" judgment is over a coarser step than the earlier framing implied.
- **This closes off the free-lunch reading of PA.6.** PA.6 found the port infeasible unless the blit's 1.37× per-byte gap closes; dropping the sub-byte shifter was the obvious lever, and this measurement prices it in fidelity rather than removing the cost.
- **1-px placement remains available in B** — `gfx.s` implements four 2bpp sub-byte phases. Byte-alignment would be a choice, not a constraint.

**Ordered follow-ups:**
1. **Jay's judgment on 4-px horizontal quantization** — now the live question, and the input PA.6's feasibility path depends on.
2. **Measure `k`** — still the threshold variable in PA.6's break-even; unmeasured across three dispatches.
3. **Pair `Fdx` with `OFFSET` per frame** if the decision needs the frame-by-frame demonstration (§6.3).
4. **Rule once on idioms-file authorship** (§6.5) — five techniques queued.
5. Standing: `POP-idioms-coco3-markers.md` disposal; POP-level `.gitattributes`; `.vscode/` disposition.

---

### 9 — User interaction during task

**None during execution.** The dispatch's framing is Jay's (he could not tell from watching whether the prince moved smooth or stepped). Every judgment call — the `midTAB` correction (§6.4), reporting AC3 as partial (§6.3), flagging the 2-px→4-px staleness (§6.2), not filing an idiom (§6.5) — is surfaced in §6 for post-hoc ruling.

---

### 10 — Candidate(s) captured this task

One new `live/` row, pushed in pool commit `d1991a2`:

- `seeds/POP/live/2026-07-25-a-derived-constant-is-scoped-to-the-branch-it-was-derived-under.md` — a constant derived under one branch of an open decision is scoped to that branch; when the decision resolves differently the figure must be re-derived, because the number stays quotable while its premise quietly disappears (from §6.2). `initiator: executor`.

`seeds/POP/live/` now holds **twenty-two** POP rows.

---

### 11 — Commit

- **This report's commit** — on `wip`, pushed to `origin/wip` before reporting back. Hash in the accompanying reply.
- **No other `POP3_port` commit** — measurement only, per §9 of the dispatch.
- **Pool:** `d1991a2`.

---
---

## Appendix A — capture, verbatim

```
mame apple2e -sl7 cffa202 -hard1 PrinceOfPersia_3.5.hdv -video none -sound none \
     -nothrottle -seconds_to_run 300 -autoboot_script offsetcap.lua
Average speed: 1526.17% (299 seconds)      rows: 1939

SELF-TEST (values vs CVTX's documented 0-6 output range):
rows=1938  min=0  max=6
  OFFSET=0 : 371    OFFSET=1 : 270    OFFSET=2 : 284    OFFSET=3 : 376
  OFFSET=4 : 278    OFFSET=5 : 117    OFFSET=6 : 242

breakdown by midTYP:
  midTYP=$01 :    40   bg tables, lay
  midTYP=$02 :   120   bg tables, lay+layrsave
  midTYP=$82 :  1778   CHAR tables, lay+layrsave

*** THE KID (CHTAB1/2/3) ***  n=681  [0:110 1:87 2:98 3:111 4:136 5:50 6:89]
  EVEN offsets :  433 (63.6%)
  ODD  offsets :  248 (36.4%)
  distinct     : [0, 1, 2, 3, 4, 5, 6]
  -> SUB-BYTE: the original draws the prince at odd sub-byte offsets
```

## Appendix B — the instrument

`ADDMID` (`GRAFIX $059C`), from `obj/GRAFIX.LST`, writing three fields per call with X = mid-list index:
```
059C: AE 85 B2   341 ADDMID ldx midX
05A4: 9D 6B B3   346  sta midTYP,x     <- tap 1  (type)
05A7: A5 01      348  lda XCO
05A9: 9D 85 B2   349  sta midX,x
05AC: A5 03      350  lda OFFSET
05AE: 9D B3 B2   351  sta midOFF,x     <- tap 2  (THE SUB-BYTE OFFSET)
05B6: A5 04      356  lda IMAGE
05B8: 9D 0F B3   357  sta midIMG,x
05BB: A5 07      359  lda TABLE
05BD: 9D 51 B4   360  sta midTAB,x     <- tap 3  (image table index; emits the record)
```
Taps are keyed on `CURPC` so no other writer of those tables can contaminate the record, and the triple is emitted on the third write so all three fields provably belong to one call.

**Semantics, from source:**
```
GRAFIX.S:331  *  midTYP bit 7: 1 = char tables, 0 = bg tables
GRAFIX.S:719  * midTYP values:  0 = fastlay (floorpieces)  1 = lay
GRAFIX.S:722  *                 2 = lay with layrsave (normal for characters)

GRAFIX.S:853  setcharimg
GRAFIX.S:856   ldy TABLE            <- TABLE is a 0-based INDEX
GRAFIX.S:862   lda chtablist,y      <- into chtable1..chtable7
GRAFIX.S:186  chtablist db #>chtable1,#>chtable2,#>chtable3,#>chtable4
GRAFIX.S:187            db #>chtable5,#>chtable6,#>chtable7

GRAFIX.S:895  *  Hires scrn: X-coord range 0-279, byte range 0-39   (CVTX: offset = 0-6)
```

---

*End of report.*
