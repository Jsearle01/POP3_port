## Form B Report — P5.20 — the shifted and mirrored blit: byte-exact on all 290 gameplay cels, and cheaper than the baked blit it would replace

**Class:** build — harness probe, NOT integrated. `wip`. **Prod byte-identical** (`intro_seq.bin`,
`loader.bin`, `cutscene_room.bin`, built at receipt and at end — §0).

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-10-01T18:28:09-04:00 (HEAD **`104b197`**, wip; `main` at **`32b5fe2`**).

★ **The dispatch's correction holds:** HEAD is `104b197`, not `282a65c`. Nothing between them touches
`blit_core.s` or the bake. Three other parts of the dispatch did not hold: §3E, §3F and §3J.

`git status` at receipt: the standing untracked set (`.vscode/`, `nvram/`, `POP-idioms-coco3-markers.md`,
`content/intro/broderbund_splash_render.bin`, nineteen `docs/ground-truth/` files,
`docs/project/pop-coco3-design-v0_7.pdf`). No tracked file dirty.

**AC2 — prod sha1, at both ends, each from a fresh build:**

```
receipt (104b197, clean worktree, 2-pass)   end (this tree)                             
08bcae4a6249828a64554c61db9ed7ace72e4081    08bcae4a6249828a64554c61db9ed7ace72e4081   intro_seq.bin      IDENTICAL
10bddbd5413d14b1fbf26aeadb874515fc32b3e8    10bddbd5413d14b1fbf26aeadb874515fc32b3e8   loader.bin         IDENTICAL
d5b17b6d468f1bcdd66163a60d9ffa1e36197e15    d5b17b6d468f1bcdd66163a60d9ffa1e36197e15   cutscene_room.bin  IDENTICAL
```
`probe.dmk`, `scene_prog.bin`, `flame_cels.bin`, `msys_player.bin`, `cel_res.bin` also identical.

**AC12 — `main` is `32b5fe2` at both ends.**

---

### 1 — Summary

**The storage model survives, and by more than the estimates said. The reason is not the one anyone
expected.** I built one routine that draws a phase-0, facing-0 cel at any phase and either facing. It
draws **byte-exact on all 290 gameplay cels × 4 phases × 2 facings: 4,640 cases, 0 differing pixels.** It
also reproduces the five shipped cutscene bakes it can be compared with, including two shipped mirrors.

**Measured against the shipped `blit_cel` drawing the pre-baked stream of the same pose, it is
CHEAPER:**

| class (what the 6809 drew) | cases | runtime cy/B | baked cy/B | ratio | 1,922 B → % of step |
|---|---|---|---|---|---|
| shift alone | 870 | **60.3** | 79.0 | **0.76** | 61.5% (baked 80.6%) |
| mirror alone | 290 | **45.6** | 78.6 | **0.58** | 46.5% (baked 80.1%) |
| **joint, measured** | 870 | **61.6** | 78.8 | **0.78** | **62.8%** (baked 80.3%) |

*(cy/B = cycles per phase-0 footprint byte, P5.7's unit; step = 188,509 cy, re-derived in §3G)*

★★ **And that is because the estimates' "today" rate was never the draw's rate.** P5.10 and P5.11
scaled everything from `blit_core`'s **4.5 cy/byte**. That figure is the `pulu d,y`/`pshs d,y` pair on
a long blast. **The shipped blit actually draws gameplay cels at 78.5 cy per footprint byte**, about
**101 cy per segment**, with 0.62 segments per byte. The estimates (14 / 6.8 / 20.6) are therefore
**3–7× low in absolute terms**. **20.6 was not an upper bound: the joint measures 61.6, 3.0× above it.**
The *ratios* say the opposite of what the estimates implied: the runtime transform costs **less** than
today's baked draw.

★★★ **The finding that outranks the storage question: drawing 1,922 B costs 63–80% of an animation
step on either storage model**, before peel, game logic or sound. Baked or transformed, the draw path
is the budget's largest consumer. The storage model is not what threatens it.

> **★★★ CORRECTED AT P5.23 (from P5.21) — the paragraph above and the table's last column use 1,922 B as
> a DRAW volume, and it is not one.** It counts cels the oracle only **measured** (`setimage` is also
> called by `GETWIDTH`, a size query, `HIRES.S:287-301`) as well as those it drew: frame 9328 drew
> **736 B**, and **the drawn character peak over the demo is 963 B** (P5.21 §3D). At the measured rates
> that is ~31% of the step transformed and ~40% baked, not 63–80%. Per oracle frame, draw + peel stays
> ≤ ~40–44% of the oracle's own time for that frame (P5.21 §3G). **The per-byte rates and ratios in
> this report are unaffected**; only the volume they were multiplied by was wrong. Left as written
> because it was quoted onward (P3.88's precedent).

---

### 2 — Files modified

- `src/harness/xform_probe.s` — **new.** The routine (`xf_blit`) and its harness driver. Not in
  `build.bat`, not linked into anything shipped.
- `harness/tools/xform_probe_gen.py` — **new.** Tables, case records, and the **generated reference**
  (sprite_convert → cel_blit_prep → simulate), plus `--shipped` for the manifest's own bakes.
- `harness/tools/xform_probe.lua` — **new.** Pokes the probe and brackets each call with the
  debugger's `totalcycles`.
- `harness/tools/xform_probe_check.py` — **new.** Byte-exact verdict per case; enumerates every
  differing pixel; nets out the bracket.
- `harness/tools/xform_cost_summary.py` — **new.** Classifies by what was drawn; footprint-weighted
  rates; least-squares cost decomposition.
- `harness/tools/xform_blast_perm.py` — **new** (phase 1, committed alone in `e6b83d8`). Computes the
  `$80` permutation.
- `harness/smoke/run_xform_probe.sh` — **new.** The runner (sources `ramsize.sh` / `cfgdir.sh`).
- `mame-idioms-coco3-port.md` — **§41 added**, plus a pointer in §0: **the debugger's `totalcycles` is an
  exact, headless cycle counter** (§2A.3, surfaced in §8).
- `reports/20261001-183442-p5-20-…md` — this report.

Nothing under `src/engine/`, `src/hal/`, `link/`, `content/` or `build.bat`. Explicit-path staging.

---

### 3 — Reasoning

#### 3A — AC1: the `$80` pre-reversal, answered from source before the routine

> *This section is reproduced verbatim from commit `e6b83d8`, made before any line of the routine
> existed (the routine's first appearance in history is the commit that follows it).*

*Authority: source (`cel_blit_prep.py:131-139` encode, `:182-196` replay; `blit_core.s:505-532`), and
the permutation COMPUTED from `encode_row` itself rather than argued — `p520_phase1.py`.*

**It neither cancels nor compounds. It half-cancels, and the half that remains is what matters.**

An n-byte blast is stored as: the 4-byte groups **highest-address first**, **bytes forward inside
each group**, then the 1-3 byte tail (a 3-byte tail as `[1,2,0]` — the pair, then the single).
Computed from `encode_row`, body index per stream position:

```
n=5   [1,2,3,4, 0]            n=8   [4,5,6,7, 0,1,2,3]
n=6   [2,3,4,5, 0,1]          n=11  [7,8,9,10, 3,4,5,6, 1,2,0]
n=7   [3,4,5,6, 1,2,0]        n=12  [8,9,10,11, 4,5,6,7, 0,1,2,3]
```

A mirror needs the body in **fully descending** order (`n-1 … 0`) for an ascending write, or fully
ascending for a descending write. Against that:

- **the group ORDER cancels** — groups already arrive high-first, which is what an ascending mirrored
  write wants;
- **the order INSIDE a group does not** — it is forward, and the mirror needs it reversed; the
  3-byte tail's `[1,2,0]` is a third ordering again.

**★ The consequence is larger than the permutation, and it is what "a different routine" means
here.** `blit_blast` gets 4.5 cy/byte from `pulu d,y` / `pshs d,y`, and **PSHS and PSHU both write
descending — no 6809 stack op writes ascending.** A mirrored blast needs its bytes reversed inside
each group AND translated through the table, so it **cannot use the stack mover at all**: every
byte goes through a register, one at a time. The same is true of the shift, whose output byte is
the OR of two source bytes' halves.

**So the mirror is not the routine §5.260 costed, though not for the reason §2 feared.** §5.260
scaled its snippet's ratio (mirror 18 / plain 12 = 1.50×) onto `blit_core`'s **4.5 cy/byte stack-
blast** figure, which assumes the mirror keeps the stack mover's per-byte advantage. It cannot.
**6.8 and 20.6 cy/byte are therefore not established as upper bounds; they rest on a rate the
transformed path cannot reach.** The measurement in this dispatch decides it.

**What the permutation itself costs: nothing material.** A per-byte loop reads a group with
constant offsets (`ldb 3,u` … `ldb 0,u`, 5 cy each, then one `leau 4,u`) instead of `ldb ,u+`
(6 cy) — 25 cy per four bytes against 24. Any fixed in-group order is absorbed that way, so the
pre-reversal is a READ PATTERN, not a cost.

*(Post-script, not part of the committed answer: `p520_phase1.py` lives in the tree as
`harness/tools/xform_blast_perm.py`. The build confirmed the prediction. Both transforms read the body
ASCENDING through one shared read pattern, and the mirror comes from the WRITE direction.)*

#### 3B — The routine (AC3)

*Authority: source of this dispatch, verified by execution (§3C).*

**One idea:** a shifted output byte is `SHL_k[src[q-1]] | SHR_k[src[q]]`. Read ascending and
written ascending, that is a carry loop (`out = carry | F[b]; carry = C[b]`). **A mirror is the same
loop written DESCENDING with the pixel-reversal composed into the tables:** `F = SHL_k∘T`,
`C = SHR_k∘T`. So shift and shift+mirror are **one loop at one per-byte cost**, differing only in two
table pointers and the sign of the write. Mirror alone (k=0) keeps the segment structure and uses
`T` directly. Facing 0, phase 0 delegates to the shipped `blit_cel_full`.

**★ The carry stays in A.** `shift_row.s` (P3.36–P3.41) says the spill "must travel through memory"
because the 6809 has no register-to-register OR, which costs it 8 cy/byte. It need not: `ora b,y` ORs
the *table entry* into A. Per interior blast byte, decoded from the built listing (`opt c`):

```
ldb n,u [5]   ora b,y [5]   sta ,x+ [6]   lda b,s [5]      = 21 cy/byte    (shift_row: 30)
group of 4: leau -4,u [5] + 4×21 + dec <xf_g [6] + bne [3] = 98 cy = 24.5 cy/byte
```

**Partial bytes** (every merge byte, the first byte of a blast, a skip's flushed carry, the row's
last carry) are read-modify-written through `M[out]` ("11 per zero pixel"). This is valid because
transparency is index 0 with no sidecar (P3.18 3B), so a merge's mask carries nothing its src does not.
M is reached through a **self-modified extended operand**, because X/U/Y/S are all taken.

**AC3's per-cel parity compensation** is the `flags` bit1 swap, chosen **per cel** by the caller
exactly as `bake_scene.py:626-631` does: swap iff `7*apple_w` is even. The swap is folded into a
second table set (`t=2`). It was exercised on the 151 even-width cels of the 290.

**Two things a caller owns, and both are placement arithmetic:**
1. **the phase**, as today;
2. **the mirror's pad, `d = 4*w0 − 7*apple_w`.** The runtime reverses all `4w0` pixels of the stored
   frame, while `sprite_convert --mirror` reverses the `7*apple_w` it converted. So the runtime draw
   sits `d` px left of the bake's. `d` runs −3…+1 over the sample, and is negative when the trailing
   trim cut the frame below `7*apple_w`. **An integrated mirror needs `apple_w` (or `d`) per cel in
   the registry; today's stream header carries only rows and width.**

**Size:** routine 1,013 B (`$2083–$2478`, including its pointer table). **Tables 5,376 B**: M 256,
T×2 512, nine (k,t) pairs × 512. Uncomposed (T then shift) would be 2,304 B at about +5 cy/byte.

#### 3C — AC4: correctness, against a generated reference — and a shipped one

*Authority: execution trace (the probe's own framebuffer), compared with the bake's own tools.*

**The reference is generated by the bake's own tools, through the same files.** Facing 0 is
`sprite_convert` → `cel_blit_prep --phase k`. Facing 1 is the same with `--mirror` (+`--flip-parity`
iff `7*apple_w` is even). Each is drawn by `cel_blit_prep.simulate` over the probe's background, which
is `$5B + $9D·o` and so cycles all 256 byte values. Every byte of the cel's rows plus a guard row above
and below is compared.

**Sample (dispatch §4.1): 8 cels, 128 cases, all byte-exact.**

| cel | apple_w | W | h | w0 | pad d | swap | shift cy/B | mirror cy/B | joint cy/B | baked cy/B |
|---|---|---|---|---|---|---|---|---|---|---|
| CHTAB1 #64 | **1** | 7 | 24 | 2 | +1 | no | 114.0 | 87.7 | 114.8 | 153.4 |
| CHTAB3 #64 | **1** | 7 | 18 | 2 | +1 | no | 96.9 | 72.5 | 100.2 | 131.5 |
| CHTAB3 #32 | 3 | **21** | 4 | 5 | −1 | no | 62.6 | 48.4 | 64.3 | 87.3 |
| CHTAB2 #16 | 5 | **35** | 16 | 9 | +1 | no | 58.1 | 44.2 | 59.5 | 69.0 |
| CHTAB4.GD #31 | 5 | **35** | 19 | 8 | **−3** | no | 50.9 | 38.9 | 51.9 | 65.0 |
| CHTAB1 #65 | 4 | **28** | 26 | 7 | 0 | **yes** | 57.4 | 42.8 | 59.0 | 69.0 |
| CHTAB3 #23 | 4 | **28** | 22 | 7 | 0 | **yes** | 73.1 | 54.6 | 74.5 | 87.7 |
| CHTAB4.GD #7 | 4 | **28** | 40 | 7 | 0 | **yes** | 66.4 | 49.5 | 67.9 | 82.2 |

- **"1-byte-wide":** no gameplay cel is 1 CoCo byte wide. All nine Apple-1-byte cels (7 px) convert
  to 2 CoCo bytes and none trims to 1, so the sample's 1-byte cels are **Apple** 1-byte.
- **Non-trivial `$80` groups (dispatch §4.4):** GD #31 carries a **7-byte blast (tail 3)**, CHTAB2 #16
  and CHTAB3 #23 **6-byte blasts (tails 0, 1, 2)**. **Every tail length 0–3 is exercised**, so §3A's
  three orderings were all tested by execution.

**The census: all 290 non-empty cels of CHTAB1/2/3/4.GD/5, 4,640 cases, 0 mismatches.**

**★ The shipped cross-check, which the dispatch did not know was available (§3E):** `--shipped p11
--shipped v54`. The runtime transform of the shipped facing-0 source reproduces **every manifest-listed
shipped bake of those cels byte-exact**: `p11_p1`, **`p11_m_p1`**, `v54_p1`, `v54_p3`, **`v54_m_p3`**.
The two shipped mirrors were coloured at their **own** render columns (start_col 121 and 467). Both are
odd, like the facing-0 sources, so the same no-swap rule applies. That is a stronger reference than the
generated one, and it agrees.

**"Close" did not arise.** P5.11's 3 silhouette pixels were a comparison between two *bake paths*
(colour model before vs after mirroring). This compares the runtime against the bake's own mirror path,
which is a pure pixel reversal of the coloured list. A table can do that exactly, and it does.

**The swap table matches `--flip-parity` exactly on this content, but only on this content.**
`--flip-parity` swaps only `pal_bit=1` chroma; a `pal_bit=0` pixel is index 2 regardless of parity
[`sprite_convert.py:191,197`]. A uniform 1↔2 table would differ on such pixels. **Measured over all
290 gameplay cels: 0 such pixels.** The table is exact for gameplay; a table that ever carried
`pal_bit=0` chroma would need its own check.

#### 3D — AC5/AC7: the three figures, measured, and what 20.6 was

*Authority: execution trace — the debugger's `totalcycles` on the built binary, plus a static decode
of the built listing.*

**Instrument.** `mame-idioms-coco3-port.md §0` says Lua has no cycle counter. **The debugger's
`totalcycles` is one**, headless under `-debug -debugger none`. Breakpoints before and after the
driver's `jsr` write the difference to RAM. I calibrated it before use: a hand-counted 24-cycle
sequence read 24 on 8 of 8 iterations, and the bracket around a bare `rts` reads 15 cy (subtracted).
**It is deterministic: 128 of 128 sample cycle counts were identical across separate runs, batch
layouts and RAM sizes** (512 KB sample vs 128 KB census). So no interrupt leaks in: the probe clears
the PIA's IRQ/FIRQ enables, because `blit_cel` unmasks every row.

**The three figures (§1's table), each measured directly. The joint was measured on its own 870
cases, never summed from the other two.** Cases are classified by the **phase actually drawn**, not by
the reference's label: a mirrored draw lands at `(k − d) mod 4`, so "facing 1, phase 0" is a joint draw
whenever `d ≢ 0`.

**AC7 — was 20.6 an upper bound? No, and not by a little.**

| | estimate (P5.10/P5.11) | measured | measured / estimate |
|---|---|---|---|
| shift alone | ~14 | 60.3 | 4.3× |
| mirror alone | 6.8 | 45.6 | 6.7× |
| **joint** | **20.6 "upper bound"** | **61.6** | **3.0×** |
| "today" (baked) | **4.5** | **78.5** | **17.4×** |

**Why:** the last row explains the others. **4.5 cy/byte is `pulu d,y`/`pshs d,y` on a long blast**.
`blit_core.s:52-54` says exactly that. It is not what the routine costs. Decoded statically from the
built listing (`opt c`), one unclipped `blit_cel` segment is **46 cy** for a skip, **~135 cy** for a
1-byte merge, **164 cy** for a 1-byte blast and **175 cy** for a 4-byte blast, plus ~82 cy per row. A
least-squares fit over the 2,320 baked poses agrees from the other side:

```
baked    cyc ≈ 101.4/segment + 2.56/footprint B + 91.5/row     (0.62 segments per footprint B)
runtime  cyc ≈  72.0/segment + 2.50/footprint B + 101.8/row
```

**About four-fifths of today's draw is per-segment overhead**, and P3.79 measured why: most segments
are one byte. Every estimate that scaled from 4.5 inherited a blind spot of ~17×. §5.260's 4.58×
"joint vs plain" ratio was applied to the wrong plain. **The ratio that holds is runtime/baked =
0.78×.** The routine wins on segment overhead (one header decode, no clip bookkeeping when unclipped,
no `jmp`/`jmp [bb_ret]` per blast), not on per-byte work. Per byte it is slower: 24.5 against the
stack mover's ~8.

**§2H, check 3, and it hit.** The dispatch called both figures *"estimates for routines nobody has
written."* **A runtime shift loop was written and EXECUTED at P3.41: 32.9 cy/byte + 56.2 cy/row**
(`shift_row.s`, `shift_bench.s`). That loop shifts into a buffer and still needs a masked blit after it.
P5.10's ~14 does not cite it. **Two figures for one mechanism survived side by side for twenty-five
dispatches, each cited alone.** That is §2H's table exactly.

#### 3E — The Orchestrator's oracle finding, checked (dispatch §4, §9)

*Authority: the manifest, read whole.*

**It does not hold, and the reason is mechanical.** `cel_pack.json` holds **64** cel entries:
**51 in `pages` + 13 in `resident`**. 51 is the `pages` count alone. Of the 64:

- **8 cels are baked in BOTH facings** (pri 11; viz 48–54), not "all facing 0";
- **viz 54 facing 0 is baked at two phases** (p1, p3), not "zero at more than one phase";
- **two pairs share a phase across facings** (`p11_p1`/`p11_m_p1`, `v54_p3`/`v54_m_p3`). That is a
  shipped mirror oracle, used in §3C.

**Separately:** `content/cutscene/chars/p11_m_p2.s` is a **stale bake in the pre-P3.85 two-byte
format**. It was last committed at P3.78 (`88f9592`), the manifest does not reference it, and it does
not parse as a current stream. Recorded in §8, not touched.

#### 3F — §2H's three checks, for the mechanisms this relies on

1. **A second mechanism?** The draw has two classes of byte cost, per-byte and per-segment, and the
   estimates saw only the first (§3D). For the *transform*, the second object class is the **flames and
   glass**. They also go through `blit_cel` at baked phases, and **P5.7 showed scenery is
   phase-invariant (block-aligned, one phase per kind)**, so they need no runtime shift. The routine is
   for characters only.
2. **The calling routine.** `blit_cel` is called from `char_draw.s` (characters, through `co_setup`'s
   clip window) and from the room's torch path (`blit_cel_full`). The probe measures `blit_cel_full`,
   which is unclipped. **A clipped character at a screen edge pays `bc_trim` per segment** (~40–65 cy
   more, `blit_core.s:170-175`). The baseline here is therefore the *cheap* case. An integrated
   transform would need its own clip, not yet built (§6, route accounting).
3. **Prior reports.** Grep for the shift, the mirror and the 4.5 figure found P3.36–P3.42 (the executed
   shift, §3D), P3.65 (facing baked, "a runtime mirror would need reverse traversal AND bit-reversal",
   `char_draw.s:1171`; both turn out free: the write direction and the table), P5.10 and P5.11.
   **The contradiction is P3.41's measured 32.9 against P5.10's estimated ~14**, reported in §3D.

#### 3G — AC6: the step, re-derived, and the percentage

*Authority: P5.2's trace and `mame -listxml coco3`, not P5.10's carried figure.*

- **Game rate:** P5.2 counted **266 game frames over 1,681 apple2e display frames**, and apple2e
  refreshes at **60.000000 Hz** (idioms §10). That is 0.105326 s per game frame, **9.494 fps**.
- **Clock:** `mame -listxml coco3` → maincpu **894,886 Hz**, ×2 for `$FFD9` = **1,789,772 Hz**.
- **Step = 1,789,772 × 0.105326 = 188,509 cy.** P5.10's ~188,400 holds to 0.06%. (It took 6.31
  display frames × 29,859, which agrees, but the step is a wall-clock quantity and needs no coco3 frame
  rate at all.)

> **★ P5.23: the volume in this table is ~2× the real draw — see the banner in §1.** Drawn character
> peak 963 B: **31.5%** transformed (joint 61.6), **40.1%** baked (78.5). The step re-derivation above
> stands.

**Against P5.7's 1,922 B** (frame 9328: characters 1,828 + scenery 94):

| | cy/B | cycles | **% of 188,509** |
|---|---|---|---|
| joint (the worst transform class) | 61.6 | 118,438 | **62.8%** |
| shift alone | 60.3 | 115,853 | 61.5% |
| mirror alone | 45.6 | 87,735 | 46.5% |
| **baked, today's blit** | **78.5** | **150,971** | **80.1%** |
| P5.11's estimate (joint) | 20.6 | 39,593 | 21.0% |

**★ 1,922 B is a RESIDENCY figure**: P5.2/P5.7 count *distinct* cels per frame ("a cel drawn twice
costs the window nothing extra"). P5.10, P5.11 and this dispatch use it as a draw volume. A frame that
draws a cel twice draws more than this. The scenery's 94 B is block-aligned and would not be
transformed. Both refinements are second-order next to the 4.5→78.5 correction, and both are flagged
in §7.

---

### 4 — Phase 3: what it means (NO integration)

**4.1 — AC8: does the storage model survive? Yes, and it is the cheaper of the two on cycles as
well as blocks.** One phase and one facing, shifted and mirrored at run time, measures **0.58–0.78×**
the cycles of drawing the pre-baked pose with today's blitter. It is byte-exact, and the alternative
costs **24–47 blocks against 8** (P5.10/P5.11). §1's fear was that the real figure would be "materially
worse" than estimated. **In absolute terms it is 3–4× worse than estimated. Relative to the thing it
replaces, it is better.** The estimates were wrong in a way that hid this, not in a way that threatens it.

**4.2 — If it had not survived (§6.2): what the cost would have to be.** No storage-model alternative
is feasible on blocks, so the storage model cannot lose to baking on cycles alone. **Baking is slower
per byte (78.5 vs 61.6), not faster.** It "fails" only if the frame does not fit, and **then the baked
model fails first**. So the threshold is not a cy/byte figure; it is **whatever the step leaves after
peel, logic and sound**. That is unmeasured (§7). The fallbacks are named, **not chosen**:
(a) take `blit_cel`'s per-segment overhead out of the unshifted path too, since the identity case
currently delegates to it at 76.4 cy/B; (b) P3.40's **stagger** (re-transform only the character that
advanced); (c) a lower draw volume per step (peel-skip, P3.32's caveat applies); (d) frame rate.

**4.3 — AC9: what integration would cost. Named, not taken.**
- **Artifacts that move:** `char_draw.s` (call `xf_blit` with phase/facing instead of selecting a baked
  label), `blit_core.s` or a sibling module, the flame bundle it links into (`flame_cels.bin` →
  `flames.raw`/`.lz`), the cel image (`cel_pg*.bin`, `cel_res.bin`; the `_m_` facings and extra phases
  go away), `cel_pack.json`, `bake_scene.py`, `probe.dmk`. **`intro_seq.bin` and `cutscene_room.bin` would
  move only if the cutscene is migrated, and it need not be.** The cutscene's baked 1.20× fits, and the
  routine is for gameplay, which has no renderer yet.
- **New requirements:** 5,376 B of tables resident with the draw (or 2,304 B uncomposed at about
  +5 cy/byte); **per-cel `apple_w` in the registry** for the mirror's pad (§3B); a **direct page** the
  routine owns (or extended addressing at about +1 cy per access); **a clip path**, since the probe is
  unclipped (§3F.2); and code in RAM (self-modifying operand: true of the whole port, but now
  load-bearing).
- **Jay gate: yes, if anything shipped is touched.** Moving the cutscene onto it changes gated pixels'
  provenance and needs a live-disk re-gate. Building it into the first gameplay renderer gets gated
  with that renderer.

**4.4 — AC10: what I am NOT proposing.**
1. Not proposing to **integrate** the routine anywhere, or to migrate the cutscene onto it.
2. Not proposing to **change `blit_cel`**, though §3D shows its per-segment overhead is most of its cost.
3. Not proposing a **frame-budget verdict for gameplay**: 63–80% of the step is the draw alone, and the
   rest of the step is unmeasured.
4. Not proposing to **revise `blit_core.s`'s comments** (its 4.5 cy/byte and P5.10's "~14% of that"
   at line 37 are now known to be wrong) — that is a doc edit for a separate dispatch.
5. Not proposing to **resolve P3.41 vs P5.10** beyond reporting it.
6. Not proposing the **disk arc, the tile renderer, AutoCtrl**, or anything in §8 of the dispatch.
7. Not proposing to **delete the stale `p11_m_p2.s`**.

---

### 5 — Verification (AC-by-AC)

- **AC1** — §3A, committed alone as `e6b83d8` **before** the routine. The routine's first appearance
  is the commit after it.
- **AC2** — §0. Three sha1s identical, receipt build (clean worktree at `104b197`) vs end build.
- **AC3** — §3B. Builds as a probe (`lwasm -9 --decb`). Per-cel parity is the bit1 swap, chosen per cel
  by `7*apple_w` parity, exercised on 151 even-width cels.
- **AC4** — §3C. **Byte-exact at all four phases and both facings**: sample 128/128 (Apple-1-byte,
  odd-width and even-width, every blast tail 0–3), census **4,640/4,640**, shipped cross-check 10/10.
  **0 differing pixels.**
- **AC5** — §3D. Shift 60.3, mirror 45.6, **joint 61.6 measured on its own 870 cases** cy/footprint B,
  from `totalcycles` on the built binary, with the inner loop also decoded from the built listing.
- **AC6** — §3G. Step **188,509 cy**, re-derived. Joint **62.8%**; baked **80.1%**.
- **AC7** — §3D. **Not an upper bound: measured 61.6, 3.0× above 20.6.**
- **AC8** — §4.1. **Survives**, at 0.58–0.78× today's baked cost.
- **AC9** — §4.3. Named, not taken. Jay gate if anything shipped moves.
- **AC10** — §4.4, seven non-proposals.
- **AC11** — **512 KB: ALL PASS. 128 KB: `introseq` and `integ` FAIL, and they FAIL IDENTICALLY on a
  clean worktree of the receipt commit `104b197`** (same "swap shares the frame of a read to `$A400`"
  frames, f12927…f12997). They are pre-existing, and no shipped byte changed (§0). `tile` passes at both
  sizes. **AC11 is not green at 128 KB, and this dispatch did not make it red.**
- **AC12** — §0. `main` = `32b5fe2` at both ends.
- **AC13** — §6.

---

### 5b — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim):**
```
build.bat (end tree):
[hal-sync] OK -- HAL source aligned with karateka_coco3, coco_agi (11 files compared, EOL/guard/export-placement normalised)
[reg-owner] OK — 25 owner row(s) over 14 register(s), 10 file(s) allowlisted.
# VERDICT: PASS - every file on the image matches its artefact.
=== BUILD COMPLETE ===

run_suites.sh, MAME_RAM=512K:
[run_introseq_test] PASS
[integ] PASS
[run_tile_test] PASS
[suites] ALL PASS

run_suites.sh, MAME_RAM=128K (end tree AND clean 104b197 worktree, identical):
[run_introseq_test] FAIL (capture stage)
      #      FAIL — f12997: a swap shares the frame of a read to $A400
    [integ] the scene did not reach-and-return
[run_tile_test] PASS
[suites] FAIL

run_xform_probe.sh --all-gameplay (128K):     PASS — 4,640 cases byte-exact, 104 batches
run_xform_probe.sh (sample, 512K):           PASS — 128 cases; 128/128 cycle counts = census
XF_PREFIX=s run_xform_probe.sh --shipped p11 --shipped v54:   PASS all 10 cases byte-exact
xform_cost_summary.py:
shift alone      870   11491862   15069261      60.3      79.0    0.76
mirror alone     290    2900908    4995341      45.6      78.6    0.58
joint            870   11748238   15020501      61.6      78.8    0.78
baked (all)     2320          -   39934348         -      78.5
```
**25.2 bundled-artifact grep:** N/A — ROM build, no sibling-import artifact.
**25.3 operator-runtime-smoke:** N/A. Not integrated; nothing on screen changed, and the probe has no
visual output. No Jay gate is owed by this dispatch.

---

### 6 — Reactive deviations and route accounting

**Deviations:**
1. **The census.** The dispatch asked for a sample. I ran the sample *and* all 290 gameplay cels,
   because the sample's cost spread (39–115 cy/B per cel) made one cel's rate a poor estimator. The
   census is what §1's figures rest on.
2. **The shipped cross-check**, which the dispatch's premise ruled out (§3E).
3. **Baselines measured alongside.** The dispatch asked for the routine's cost. I also measured today's
   blit on identical content, because without it the routine's absolute figure (61.6) would have read
   as "3× over estimate". The ratio (0.78×) is the decision-relevant number.
4. **A new instrument** (`totalcycles`). It was calibrated before use (§3D) and added to the idioms file
   (§2A.3).
5. **AC11 order.** The dispatch said "512 KB first", and CLAUDE.md §2K says 128 KB is the target and is
   reported first (§8: invariants outrank dispatches). Both were run. 128 KB is red at HEAD (§5), so the
   order changes nothing here, but the two documents disagree and §7 flags it.

**ROUTE ACCOUNTING.** No route was proposed before this task. Within it I described a routine (composed
tables, write-direction mirror, carry in A, M via self-modified operand, k=0 mirror path, blit_cel for
identity) and **built all of it**. **What is NOT in it, stated so the probe is not mistaken for an
integrable blitter:** **no clip window** (it is the `blit_cel_full` analogue, not `blit_cel`), **no peel**
(save/erase), and **no lean identity path** (facing 0 phase 0 still goes through `blit_cel`). §4.2(a)
names that last one as a fallback; it is not built. The per-row IRQ/FIRQ window **is** in, because a
routine without it could not ship (P4.29).

---

### 7 — Uncertainty flags

1. **★ The 128 KB suites are red at `104b197`**, pre-existing and unexplained here. CLAUDE.md §2K calls
   128 KB the verification target, and the dispatch says 512 KB first. One of them is stale. I did not
   bisect (out of scope).
2. **★ The absolute budget, 62.8% / 80.1% of a step for drawing alone, is a draw-only figure.** Peel,
   logic and sound are not in it, and the probe is unclipped (the cheap case). **Whether the gameplay
   frame fits is open on EITHER storage model.**
3. **1,922 B is a residency figure (distinct cels) used as a draw volume** (§3G), and its 94 B of
   scenery would not be transformed.
4. **The `pal_bit=0` exactness is content-dependent** (§3C): 0 such pixels in 290 gameplay cels, so it
   is untested by execution, not proven impossible.
5. **The census is the oracle's tables, not the demo's draws.** Rates are footprint-weighted over
   every cel at every phase and facing equally. A real frame's mix of cels, phases and facings would
   weight differently. The class rates are close (60–62) except mirror alone.
6. **The routine is a first build.** Left on the table: lwasm encoded `ldb 0,u` with a zero 5-bit
   offset (5 cy, not 4); DP variables could take more of the per-segment work. The measured figure is
   this routine's, an upper bound on what the approach can reach.
7. **Push failed** (§11): the repo needs an SSH key this machine lacks. The Orchestrator cannot see
   `wip` until it is pushed from a credentialed environment.

---

### 8 — Follow-up candidates

1. **★ Bisect the 128 KB `introseq`/`integ` failure.** It is red at HEAD, on the CLAUDE.md §2K target.
2. **★ Measure a whole gameplay step's budget**: peel, logic, sound, clip. §4.2 cannot be closed
   without it, and the draw alone is 63–80%.
3. **Correct the carried 4.5 cy/byte wherever it is used as a draw rate.** `blit_core.s:37`'s "a
   runtime shift costs ~14% of that" is the live instance (doc edit, separate dispatch).
4. **A clean clone cannot build in one pass:** `intro_seq.s:202` includes `build/obj/flame_load.inc`,
   assembled at `build.bat:219` and generated at `build.bat:377`. It works only where a previous build
   left the file. Found building the receipt worktree; worked around by seeding it, and the regenerated
   file was byte-identical to the seed.
5. **`run_suites.sh` assumes `build/tmp` exists**, and a fresh build does not create it.
6. **`content/cutscene/chars/p11_m_p2.s`** is a stale pre-P3.85 bake that nothing references.
7. **`render_fb.py` needs PIL**, which this toolchain lacks: `run_tile_test.sh` passes but produces no
   PNG.
8. **Idioms §41 (`totalcycles`) is new.** It should be re-confirmed on the next MAME version bump, like
   the rest of the file.

### 9 — User interaction during task

None. (Four "say what you're doing" prompts from the harness were answered with status lines; no ruling
was sought or given.)

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-10-01-an-inner-loop-rate-is-not-the-routines-rate.md`: the estimates were
scaled from an inner loop's rate, and measuring the baseline with the same instrument exposed a ~17×
blind spot. Pushed to the pool as `0fdcc65`.

### 11 — Commit

Phase 1: `e6b83d8` (the `$80` answer, alone, before the routine). Phase 2–3: **`d9cf353`** (the probe,
tools, idioms §41, this report); this hash line follows in its own commit. **NOT pushed to `origin/wip`:** `git push` fails with `Permission denied (publickey)`, and
this environment has no key for `git@github.com` (`C:\Users\jayse\.ssh` holds only `known_hosts`).
**`main` untouched at `32b5fe2`.**
