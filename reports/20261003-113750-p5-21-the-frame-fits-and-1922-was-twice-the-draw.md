## Form B Report — P5.21 (+ Addendum: the stagger) — the gameplay frame fits; 1,922 B was about twice the draw, and the step was a mean

**Class:** measure. `wip`. **Prod byte-identical** (§0). No integration, no engine change, no gate reopened.

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-10-03T11:21:46-04:00 (HEAD **`0fb3a5e`**, wip — matches the dispatch; `main` **`32b5fe2`**;
`origin/wip` = `0fb3a5e`). Tracked tree clean; the standing untracked set unchanged.

**AC2 — prod sha1, `build/` as left at receipt vs a fresh end build:**
```
08bcae4a6249828a64554c61db9ed7ace72e4081  intro_seq.bin      IDENTICAL
10bddbd5413d14b1fbf26aeadb874515fc32b3e8  loader.bin         IDENTICAL
d5b17b6d468f1bcdd66163a60d9ffa1e36197e15  cutscene_room.bin  IDENTICAL
```
**AC15 — `main` = `32b5fe2` at both ends.**

---

### 1 — Summary

**The gameplay frame fits, comfortably, on both storage models.** I costed every game frame of the demo
from what the oracle **actually drew** in it, at each cel's real phase and facing, using the measured
per-pose draw and peel. **The port's draw + peel never exceeds 44% (baked) / 40% (transformed) of the time
the oracle itself spent on that frame — 0 of 264 frames over — and is 26.6% / 23.2% over the whole span.**
Even held to the **mean** step, the heaviest frame is 56.7% / 53.7%.

**§1's 122–156% comes from two inflations, both mechanical:**

1. **★★★ 1,922 B is not a draw volume.** P5.7's *"characters 1,828 B at frame 9328"* reproduces exactly on
   an unfiltered `setimage` tap. **But `setimage` has two callers, and one of them draws nothing:**
   `GETWIDTH`, a size query. At frame 9328 the oracle **draws 4 character cels, 736 B**. It **queries** 3
   more (1,092 B: the next poses, for geometry). **The drawn peak over the whole demo is 963 B.**
   P5.10, P5.11, P5.20 and the dispatch's 122–156% all multiplied by ~2× the real figure.
2. **★★ 188,509 cy is the MEAN game frame.** The oracle's own frames run **3 to 13 display frames**. Light
   frames (< 600 B) average 5.27, heavy ones (≥ 1,200 B by P5.2's count) 9.38, and the peak frame takes
   it **8**. Holding the port's peak frame to the mean step demands more than the original does.

**On the dispatch's own arithmetic** (1,922 B × measured mean rates), draw + peel is **144.0% baked /
125.7% transformed**. That is reported plainly (§3B), **and it is a figure about a volume that does not
exist.**

**The other questions:**
- **The oracle's peel (AC5/AC6):** P3.88 had already settled it from source, on 2026-08-15 (§3C). Per
  footprint byte **in time**, the port's peel is **1.09×** the oracle's (a lower bound on the oracle). The
  gap is per-row overhead; the per-pixel mover is faster.
- **Compiled sprites (AC7–AC9):** on P5.20's own 290 cels, the compiled draw counts **6.05 cy/B against
  `blit_cel`'s measured 76.31: 12.6×.** **But at the phase × facing count they require they need 3.1×
  all 56 free blocks for the draw code alone.** The gate's RAM reason survives the move to 512 KB.
- **The stagger (AC17–AC22):** characters hold still rarely. In combat the kid holds 12.2% of steps, the
  guard 48.1%, and **neither holds in 50.6%**. The obvious cache (the shipped segment format) costs
  **more** to replay than to recompute (78.5 vs 61.6 cy/B). Small, and bounded.

---

### 2 — Files modified

- `harness/tools/oracle_step_trace.lua` — **new.** Every `setimage` with its **caller**, plus Kid/Shad state
  per game frame.
- `harness/tools/oracle_step_analysis.py` — **new.** Exact filter, PREPREP-only draws, layrsave/lay
  collapse, durations, hold rates. Control at frame 9328.
- `harness/tools/frame_fit_by_frame.py` — **new.** Per-frame port draw + peel against the oracle's own
  time for the frame.
- `harness/tools/frame_fit_summary.py` — **new.** Draw + peel per footprint byte, both models; the peel's
  decomposition; the oracle's peel counted.
- `harness/tools/compiled_census.py` — **new.** The production compiler over P5.20's 290 cels; sizes by
  assembly.
- `src/harness/xform_probe.s`, `harness/tools/xform_probe_gen.py`, `harness/tools/xform_probe.lua` —
  **the P5.20 probe extended.** 12-byte records with a per-case fill seed (so an erase lands on a different
  background from its save), a peel buffer in Y, and `--peel`. **Regression: 128/128 of P5.20's net
  draw cycle counts reproduce exactly** through the changed driver.
- `mame-idioms-apple2e-oracle.md` — **§13 added** (`setimage`'s non-drawing caller; the `SP`/`S` name;
  the mirrored-pair rule). Surfaced per §2A.3.
- This report.

Nothing under `src/engine/`, `src/hal/`, `link/`, `content/` or `build.bat`.

---

### 3 — Reasoning

#### 3A — The grep first (§8), and what it shrank

- **§3 was already done.** **P3.88** (2026-08-15) read `DRAWALL` → `SNGPEEL` → … → `DRAWMID`, `ADDPEEL`,
  `maxpeel`, `peelbuf1/2` from source. It found the oracle peels, per page, and **corrected P3.44's §3F in
  place** (`d69b391`). The dispatch's *"retracted at §5.313 this session"* is a seven-week-old correction
  rediscovered.
- **P3.88 also carries a later peel figure, 40,191 cy** (cutscene, per iteration), not P3.44's 25,402. Both
  are the cutscene's, and neither is used as a gameplay figure here.
- **P1.3 / PA.7 / P3.18** supplied the compiled-sprite numbers. Each was re-derived on P5.20's sample
  rather than carried (§3E).

#### 3B — AC1/AC3: draw and peel on gameplay, both models

*Authority: execution trace — the debugger's `totalcycles` on the built probe (idioms §41).*

**Draw:** P5.20's census, every gameplay pose, same instrument. It is not re-run: it is deterministic
(128/128 identical, P5.20) and was re-confirmed through this dispatch's driver (§2).

**Peel:** `blit_save_full` + `blit_erase_full` at every (rows, width) any of the 290 cels' eight poses
needs, under **both** models. The mirrored bake's trailing trim makes its width differ from `w0`, and the
transformed frame is `w0` (+1 at the phase actually drawn). **274 pairs, 548 cases, all byte-exact**: the
erase is checked on a different background from its save.

| model | draw | save | erase | **peel** | **total** | peel/draw |
|---|---|---|---|---|---|---|
| baked | 78.5 | 31.4 | 31.3 | **62.7** | **141.2** | 0.80 |
| transformed | 61.0 | 31.2 | 31.1 | **62.4** | **123.3** | 1.02 |

*(cy per phase-0 footprint byte, footprint-weighted over 290 cels × 8 poses)*

**× 1,922 B, against the 188,509 cy mean step, as §2.4 asks, unsoftened: 144.0% baked, 125.7%
transformed.** P3.44's cutscene ratio (peel = 0.95× draw) carried roughly: 0.80× / 1.02× here. **Then §3D
takes the volume apart.**

#### 3C — AC5/AC6: the oracle's peel, verified and costed

*Authority: Mechner source (`GRAFIX.S`, `HIRES.S`), read directly; consistent with P3.88.*

- `DRAWALL` [`GRAFIX.S:484-505`]: `DOGEN` → `SNGPEEL` (*"using the peel list we set up 2 frames ago"*) →
  `ZEROPEEL` → `DRAWWIPE` → `DRAWBACK` → `DRAWMID` (*"& save underlayers to now-clear peel list"*) →
  `DRAWFORE` → `DRAWMSG`. **Verified.**
- `DRAWMID` `:layrsave` [`:728-734`]: `layrsave` → `ADDPEEL` → `lay`. `ADDPEEL` [`:436-473`] stores
  `peelX/peelY/peelIMGL/peelIMGH`. `SNGPEEL` [`:641-670`] walks the list **in reverse**, `OPACITY = sta`,
  `jsr peel`. Both index `0`/`maxpeel` off `PAGE`: **per page.** **Verified.**
- **The movers** [`HIRES.S`]: `LAYRSAVE`'s `:inloop` (`lda abs,y` 4 / `sta (zp),y` 6 / `dey` 2 / `bpl` 3)
  = **15 cy per Apple byte**, ~42 per row. `fastlaySTA`'s (`lda (zp),y` 5 / `sta abs,y` 5 / `dey` / `bpl`)
  = **15 per Apple byte**, ~41 per row. Both cover `WIDTH+1` (*"inc WIDTH ;extra byte to cover shift
  right"*), **the same widening the port's peel has.**

**The port's peel, decomposed (least squares over 274 pairs):** `save = 13.04/byte + 118.1/row + 59.3/call`,
`erase = 13.07/byte + 116.9/row + 60.2/call`.

**AC6 — the gap, in components, on the same 290 cels and the same denominator:**

| | oracle (6502, 1.0218 MHz) | port (6809, 1.7898 MHz) | port / oracle, in time |
|---|---|---|---|
| per pixel moved, each way | 15 cy / 7 px = **2.10 µs** | 13.04 cy / 4 px = **1.82 µs** | **0.87× — the port's mover is faster** |
| per row, each way | ~41–42 cy = 40.6 µs | ~117–118 cy = 65.6 µs | **1.6× — the gap** |
| per call | prologue (`PREPREP`, `CROP`, `ADDPEEL`, list walk) **not counted** | ~60 cy = 33 µs | unknown |
| **whole peel, per footprint byte** | **≥ 32.0 µs** (lower bound) | **34.8 µs** | **≤ 1.09×** |

- **Structure:** identical (per-page lists, save during draw, restore before, `WIDTH+1`).
- **Byte mover:** the port's is faster per pixel despite moving 1.75× the bytes (2 bpp vs Apple's 1 bpp + 1
  palette bit per 7 px).
- **Per row:** the port pays ~1.6× in time. That matches P3.44's finding that its peel is dominated by
  per-row overhead.

The oracle's figure omits its prologue, so **the true gap is at most 9%.** **The port's peel is not
expensive relative to the original; on a 1,922 B frame the oracle's own peel alone would be 58.5% of its
mean step.** That is what first pointed at §3D.

#### 3D — ★★★ AC4: what 1,922 B is a number of — and the real draw volume

*Authority: execution trace (`oracle_step_trace.lua`); the caller identified from Mechner source.*

**The dispatch's §2.2 worry was the wrong way round.** A new trace logs **every** `setimage` (not
distinct-only), with `XCO`, `YCO`, `OFFSET`, `OPACITY` **and the caller**, read from the 6502 stack.

- **The control:** unfiltered, frame 9328's character cels total **1,828 B, exactly P5.7's.** The frames
  are the same frames.
- **The caller splits it.** `HIRES.S` calls `setimage` from **`GETWIDTH`** [`:287-301`], which reads
  width/height and draws nothing, and from **`PREPREP`** [`:311-329`], which every drawing primitive calls.
  Measured returns: **`$EF06` and `$EF26`**, 32 bytes apart, exactly the code between the two `jsr`s.
- **Frame 9328 drew:** `chtab4gd_10` (guard, mirrored), `chtab3_46` (guard's sword, mirrored), `chtab5_2`
  (kid), `chtab3_40` (kid's sword) = **736 B**. **GETWIDTH-only:** `chtab4gd_11`, `chtab5_3`, `chtab5_17`
  = **1,092 B = 1,828 − 736 exactly.**
- **Does any frame draw a cel twice? No, 0 of 266.** The apparent duplicates were the `LAYRSAVE`/`LAY`
  pair: both call PREPREP for ONE draw, and for a mirrored draw `LAY` clears `OPACITY` bit 7 first
  [`HIRES.S:658-664`], so the pair differs only in that bit. 467 such pairs collapsed.

**So:** 1,922 B overstates the drawn volume; it does not understate it. **The drawn character peak over
the demo is 963 B** (frame 9561: 5 cels). It is a sum over **distinct cels that were drawn or merely
measured**, a residency-flavoured figure, as §5.304 suspected, and inflated by a second mechanism nobody
had looked for. (P5.7's 94 B of scenery was not re-measured; §7.)

#### 3E — AC7–AC9: compiled sprites, on P5.20's sample and unit

*Authority: the production compiler (`sprite_compiler.py`, unmodified, `bg_zero=False` — the only
setting valid under the peel), sizes by lwasm assembly; cycles are its static count.*

**AC7 — P3.18's 8.2×:** compiled code **100.8 KB vs 11.9 KB of raw packed 2 bpp bitmap**, on the
cutscene's **49 character cels**, byte-aligned (phase 0). On the 290 gameplay cels it comes out at:

| | bytes | × raw bitmap |
|---|---|---|
| raw packed bitmap | 59,080 | 1.00 |
| segment stream (what the port stores) | 91,906 | 1.56 |
| compiled DRAW | 231,055 | **3.91** |
| compiled draw + save + erase | 456,969 | **7.73** ← P3.18's 8.2× is this (all three routines) |

**AC8 — ★★ at the phase and facing count compiled sprites REQUIRE.** A compiled sprite bakes position and
byte order into its instruction stream, so it cannot be shifted or mirrored at run time. **Draw code
alone, 231,055 B per phase per facing:**

| | bytes | 8 KB blocks | against 56 free |
|---|---|---|---|
| one phase, one facing | 231,055 | 28.2 | fits, alone |
| × 3.09 phases (P5.10, a **lower bound**) × 2 facings | **1,427,920** | **174** | **3.1× over** |
| × 4 phases × 2 facings (the bound) | 1,848,440 | 226 | 4.0× over |

**The gate's RAM reason survives 512 KB by a factor of three**, before any compiled peel and before
scenery, tiles or code. (The 290 are every non-empty cel of the five gameplay tables, not P5.9's 271-cel
closure. Same order.)

**AC9 — the cycle gap on identical content:** same 290 cels, same pose (facing 0, phase 0), same
denominator (`ceil(7·apple_w/4)·h`):

| | cy / footprint B |
|---|---|
| compiled draw (static count) | **6.05** |
| compiled save + erase | 9.22 |
| `blit_cel` (measured, P5.20) | **76.31** |

**12.6×.** P1.3's 5.77 is the same kind of number (counted) on 9 cutscene cels. 5.77 → 6.05 is the
sample. **The remaining caveat is static vs executed:** compiled code is straight-line, so its static
count is its executed count apart from the call. **I did not execute it** (§7).

#### 3F — AC10/AC11: levers on the segment blitter without a representation change

- **AC10 — opaque black:** **applies in principle, and more strongly than to compiled sprites,** because
  the segment blitter's cost is per segment and opaque black merges runs. **But it is not available without
  a representation change:** transparency **is** index 0 (P3.18 3B, no sidecar), so an opaque black needs a
  mask the format does not carry.
- **AC11 — per-segment headroom, same stream format: measured, ≥ 40% on the unshifted path.** P5.20's
  **mirror-alone path walks the shipped segment structure unchanged** and draws it at **45.6 cy/B against
  `blit_cel`'s 78.6 on the same poses**, while doing **more** per byte (a table lookup and a one-byte write
  instead of the stack mover). **So a plain walker written the same way would cost ≤ 45.6 cy/B.** The
  identity case currently goes to `blit_cel` at 76.4. The saving comes from one header decode, no clip
  bookkeeping when unclipped, and no `jmp`/`jmp [bb_ret]` per blast. **Measured as an upper bound, not
  built.**

#### 3G — ★★ The fit, by frame (AC3 answered properly)

*Authority: execution trace for the oracle's frames and durations; the probe censuses for the costs.*

For each of the 264 timed game frames in P5.2's span: the cels the oracle **drew**, each at its phase
(`(XCO·7 + OFFSET + 20) mod 4`, P5.10) and facing (`OPACITY` bit 7). Each costs its own measured draw +
save + erase, against the **oracle's duration of that frame** (display frames at 60 Hz, at the port's
clock):

| | median | p90 | **max** | frames over the oracle's whole frame | whole span |
|---|---|---|---|---|---|
| baked | 0.28 | 0.39 | **0.44** | **0 / 264** | **26.6%** |
| transformed | 0.25 | 0.34 | **0.40** | **0 / 264** | **23.2%** |

**Heaviest drawn frame** (9561, 963 B, 5 cels): **106,829 cy baked / 101,301 transformed = 56.7% / 53.7%
of the MEAN step**, and 32.6% / 30.9% of the 11 display frames the oracle took over it.

**What the remaining ~56–60% of the oracle's time has to hold in the port:** scenery, game logic (POP's
control code, not yet ported), sound, the flip, and the clip. **None of those is measured here**, so "fits"
means **draw + peel leaves the majority of the oracle's own frame for everything else.** It does not mean
the frame is proven to fit. That needs the logic ported.

#### 3H — ADDENDUM: the stagger (AC17–AC22)

*Authority: execution trace — Kid ($50) and Shad ($60) state records [`GAMEEQ.S:389-393, 600-632`]
sampled at every game-frame boundary; plausibility checked (Face ∈ {00, FF}, X moves smoothly).*

**Hit condition:** `Posn, X, Y, Face, Scrn, Sword` unchanged from the previous step.

**AC20 — facing belongs in it, from source:** the sequence interpreter's `aboutface` is
`lda CharFace / eor #$ff / sta CharFace` and **nothing else** [`COLL.S:1022-1027`]. It does not change
`Posn` or `X`. A character can turn with an unchanged cel index and x, so facing must be in the condition;
in the port it selects the mirrored draw. *(Observed in this demo: 0 such steps, but the source permits
it.)*

**AC17/AC18/AC19:**

| | steps | kid holds | guard holds | **both** | **exactly one** | **neither** |
|---|---|---|---|---|---|---|
| **combat** (guard drawn) | 82 | 12.2% | 48.1% | 11.1% | 38.3% | **50.6%** |
| **locomotion** (no guard) | 183 | 21.9% | — | — | — | — |

**Hold-run lengths, the distribution:** kid `{1:4, 2:2, 4:1, 6:1, 7:1, 8:1, 17:1}`; guard `{14:1, 25:1}`.
The guard's holds are two long waits, not a steady rate. **On a non-hold, what changed:** kid
`posn+x` 103, `posn` 93, `posn+x+y` 14, …; guard `posn` 33, `posn+x` 7. **Posn changes in every
non-hold.**

**AC21 — what a cache would hold and what replaying it costs:**
- **The obvious cached form, the transformed cel re-emitted in the shipped segment format, costs MORE to
  replay than to recompute:** `blit_cel` measures **78.5 cy/B** on baked streams; the fused transform is
  **61.6 cy/B**. **A cache in that format is a net loss.** (P3.40's cache cached `shift_row`'s output for
  a different blitter.)
- **Only a raw masked form could save:** shifted bytes + mask, replayed by a masked copy. Its floor is the
  6809 merge, **22 cy per byte** (P3.19, counted), plus per-row overhead. **Bound: saving ≤ ~40 cy/B per
  held character-step** (61.6 − 22 × (w0+1)/w0), and **less in practice**, since per-row overhead is
  real (the peel pays ~117 cy/row).
- **Expected value:** at the measured hold rates, ~12% of kid steps and ~48% of guard steps in combat.
  **And the cache must be WRITTEN on every non-held step,** costing a store per output byte on top of the
  draw. **Not measured; bounded as small.**

**AC22 — RAM:** `(w0+1) × h × 2` per character (bytes + mask): ≤ ~1.6 KB for the largest cel, against 56
free blocks. **Not per page:** a held character's transformed bytes are the same on both pages (same cel,
same x). Only the peel is per page, because the backgrounds differ.

**★ P3.40's 93% and P3.44's 6.8% appear nowhere above as gameplay figures**, per §B6.

---

### 4 — Phase 3: what it means (NO integration, NO architecture)

**4.1 — AC3: does the gameplay frame fit?** **On the demo's own frames, draw + peel takes at most 40–44% of
the time the oracle spent on the same frame, and never exceeds it.** On the dispatch's arithmetic
(1,922 B × mean rates ÷ mean step) it is 126–144%. **That arithmetic is wrong twice over (§3D, §1.2),
and the by-frame figure is the one to plan on.** It is a **draw + peel** figure; logic and scenery are
not in it.

**4.2 — AC12: the menu. Costed where measured, named where not. NOT CHOSEN.** With the frame fitting, these
are headroom levers, not rescues:

| lever | what it buys | status |
|---|---|---|
| **per-segment overhead out of the unshifted path** | identity case 76.4 → ≤ 45.6 cy/B | **measured as a bound** (§3F) |
| peel per-row overhead | the ~1.6× row gap vs the oracle | measured gap (§3C); fix not costed |
| storage model (baked → transformed) | 141.2 → 123.3 cy/B draw+peel | measured (§3B) |
| the stagger / cache | ≤ ~40 cy/B on held steps, minus cache writes | bounded, small (§3H) |
| compiled sprites | draw 76 → ~6 cy/B | **closed: 3.1× over 56 blocks** (§3E) |
| lower draw volume / frame rate | — | not needed on this evidence |

**4.3 — AC13: what I am NOT proposing.**
1. Not integrating anything; not changing `blit_cel`, the peel, the bake or the cutscene.
2. **Not reopening the compiled-sprite gate.** §3E says what reopening would cost, and the answer closes it
   again.
3. Not building the stagger or a cache. §3H measures what it would be worth.
4. **Not correcting P5.7, P5.10, P5.11 or P5.20 in place.** Their volume figure is ~2× high, and the
   correction is a doc job for the Orchestrator (§2D).
5. Not claiming the frame fits with logic in it.
6. Not the `blit_core.s:37` doc fix, the disk arc, the tile renderer, or bisecting 128 KB.

---

### 5 — Verification (AC-by-AC)

- **AC1** — §3B. Save, erase **measured** (548 cases, byte-exact); draw from P5.20's census. Same instrument.
- **AC2** — §0, identical. **AC15** — §0.
- **AC3** — §3B (dispatch arithmetic: 144.0% / 125.7%) and **§3G (by frame: ≤ 44% / ≤ 40%, 0 of 264
  over).**
- **AC4** — §3D. **Distinct cels drawn OR measured; overstates the draw ~2×; no frame draws a cel twice.**
- **AC5** — §3C, verified from source (and already done by P3.88); oracle peel 15 cy/Apple-byte + ~41–42/row.
- **AC6** — §3C: structure same, mover faster, **per-row 1.6×**, per-call unknown; **≤ 1.09× overall**.
- **AC7** — §3E: 8.2× = compiled draw+save+erase vs raw bitmap, 49 cutscene cels; 7.73× on gameplay.
- **AC8** — §3E: **174–226 blocks vs 56 free.**
- **AC9** — §3E: 6.05 vs 76.31 on identical content; static vs executed noted.
- **AC10** — §3F, one line. **AC11** — §3F, ≤ 45.6 cy/B measured bound.
- **AC12** — §4.2. **AC13** — §4.3. **AC16** — §6.
- **AC14** — **512 KB: ALL PASS** (`introseq`, `integ`, `tile`). **128 KB: `introseq` FAIL (capture stage),
  `integ` FAIL, `tile` PASS** — red as the dispatch says, reported, not bisected.
- **AC17–AC19** — §3H table and run distributions. **AC20** — §3H, `COLL.S:1022-1027`. **AC21/AC22** — §3H.

### 5b — Verdict-time evidence

**25.1** (verbatim):
```
build.bat: [hal-sync] OK ... [reg-owner] OK — 25 owner row(s) over 14 register(s) ... === BUILD COMPLETE ===
run_suites.sh 512K: [run_introseq_test] PASS / [integ] PASS / [run_tile_test] PASS / [suites] ALL PASS
run_suites.sh 128K: [run_introseq_test] FAIL (capture stage) / [integ] FAIL / [run_tile_test] PASS / [suites] FAIL
XF_PREFIX=d run_xform_probe.sh (sample, through the changed driver): PASS 128 cases; 128/128 net cycles = P5.20
XF_PREFIX=p run_xform_probe.sh --all-gameplay --peel: PASS all 548 cases byte-exact
oracle_step_analysis.py: CONTROL (unfiltered) frame 9328 1,828 B = P5.7; drawn 736 B; dup-drawn bins 0 of 266
frame_fit_by_frame.py:  baked max 0.44, 0/264 over, span 26.6% | xform max 0.40, 0/264 over, span 23.2%
compiled_census.py:     draw 231,055 B = 3.91x raw; draw+save+erase 7.73x; 6.05 vs blit_cel 76.31 cy/B (12.6x)
```
**25.2:** N/A. **25.3:** N/A. Nothing on screen changed.

---

### 6 — Reactive deviations and route accounting

1. **★ §2's draw volume replaced.** The dispatch asked for draw + peel on "P5.7's 1,922 B". I reported that
   (144% / 126%) **and** found it is not a draw volume. The by-frame measure is the answer I stand on.
   **A contradicting finding outranks the dispatch,** per §8.
2. **The comparison basis changed from the mean step to the oracle's own frame time.** That is the
   feel-preserving budget (CLAUDE.md §2I). The mean-step figure for the heaviest frame (53.7–56.7%) is
   given beside it so nothing is hidden.
3. **§3 not re-derived from scratch**: P3.88 had it. I re-verified the source lines and added the per-byte
   costing.
4. **Compiled sizes from assembly, on gameplay content**, rather than scaling P3.18's 8.2×.
5. **The P5.20 probe was extended** (records 12 B, fill seed, peel buffer). It was re-verified against
   P5.20's own numbers before use.
6. **A new oracle instrument** with a built-in control, which caught its own first two mistakes (an
   `S`/`SP` misread, then the `GETWIDTH` caller).

**ROUTE ACCOUNTING.** No route was proposed before this task. Within it: §4.2's menu names levers **and
builds none**. AC11's ≤ 45.6 is a **measured bound from an existing routine, not a built identity path**.
AC21's raw-cache saving is a **bound, not a measurement.**

---

### 7 — Uncertainty flags

1. **★ "Fits" is draw + peel only.** Scenery, game logic, sound, flip and clip are not in the port figure.
   They have to fit in the remaining ~56–60% of the oracle's frame time; logic is not ported, so this is
   unmeasurable today.
2. **★ One demo run, 264 frames** (a seed-determined fight, apple2e idioms §3). A heavier fight, or more
   characters on screen, is not sampled.
3. **P5.7's scenery figure (94 B at 9328) was not re-measured** against the `GETWIDTH` finding. Its tool
   (`oracle_fore_trace.lua`) may or may not share the defect.
4. **Phase of a mirrored oracle draw is approximate** (`LAYRSAVE` adjusts `XCO` after PREPREP). The
   per-phase cost spread is ~3%.
5. **The oracle's peel is a lower bound** (prologue and page-crossing not counted), so "≤ 1.09×" is an
   upper bound on the gap.
6. **Compiled-sprite cycles are static counts**, not executed (straight-line code, so expected equal
   apart from the call).
7. **The per-character state is read from zero page by sampling.** It is plausible on inspection (Face ∈
   {00, FF}, X smooth, guard present only in combat), but an ALTZP misread was not formally excluded.
8. **The raw-cache bound uses the counted 22 cy/B merge floor**, not a measured masked replay.

### 8 — Follow-up candidates

1. **★ Correct the carried 1,922 B** (P5.7/P5.10/P5.11/P5.20) — **Orchestrator doc work.** The drawn peak
   is 963 B.
2. **Re-check P5.7's scenery tap for the same `GETWIDTH`-style inflation** (flag 3).
3. **Re-run the by-frame fit on more seeds / a longer demo** (flag 2), and with scenery once it's re-measured.
4. **The identity-case walker** (AC11), if headroom is wanted: ≤ 45.6 vs 76.4 cy/B, no format change.
5. **P3.88's carried items still open** (turn disappearance, `vb_tick` branch). Unrelated, noted from the
   grep.

### 9 — User interaction during task

**One mid-task message: the Addendum (the stagger).** It was folded in as §3H (AC17–AC22) without
restarting; nothing in it changed §2–§4's method. It arrived after the peel census and before the oracle
trace, which then served both.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-10-03-a-funnel-tap-counts-every-caller.md`: a tap on a shared funnel
(`setimage`) counted a size query as a draw. The figure was quoted for four dispatches until the caller
was read from the stack, and an exact control (reproducing the old number unfiltered) is what made the
correction trustworthy.

### 11 — Commit

See the commit following this report's first save; hash recorded in the follow-up commit.
`main` untouched at `32b5fe2`.
