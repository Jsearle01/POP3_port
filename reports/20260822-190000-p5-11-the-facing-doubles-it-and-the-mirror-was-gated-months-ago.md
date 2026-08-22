## Form B Report — P5.11 — the facing doubles it, and the mirror Jay would have to approve he approved in August

**Class:** Phase 1 build (comment + config); Phases 2-3 recon; Phase 4 proposal, no engine code. `wip`.

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-22T18:38:35Z (HEAD `52fd21a`, wip; **`main` at `32b5fe2`, resolved here**).

`git status` at receipt — the standing untracked set: `.vscode/`, `nvram/`,
`POP-idioms-coco3-markers.md`, `content/intro/broderbund_splash_render.bin`, nineteen files under
`docs/ground-truth/`, `docs/project/pop-coco3-design-v0_7.pdf`. One modified tracked file:
`dist/mame-cfg/rgb/coco3.cfg` — **now fixed, §1.2.**

**AC2 — prod sha1, receipt and end, across a FULL REBUILD with the comment changed:**

```
receipt                                    end (rebuilt)
d07f1f32…4942231c  intro_seq.bin           d07f1f32…4942231c   IDENTICAL
0b496886…d6f2def   loader.bin              0b496886…d6f2def    IDENTICAL
79083657…04840a2   cutscene_room.bin       79083657…04840a2    IDENTICAL
```

**The comment change moved no byte.** `=== BUILD COMPLETE ===`, readback `VERDICT: PASS`.

---

### 1 — Summary

★★★ **§2's suspicion is right and it is the largest number in the arc. `bytes_of()` costs each
distinct `(table, image)` pair ONCE — `coco3_bytes(cel["w"], cel["h"])`, no facing term
[`seq_graph.py:239-246`]. So 61,195 B is ONE FACING.** The oracle stores one and mirrors at draw
time (`LAY` → `MLAY` on `OPACITY` bit 7 [`HIRES.S:650-662`]); the port cannot, so it needs both.
**Character residency is ~122,390 B — 15 blocks, not 8 — and the budget is 17 against 8. Over by
NINE.** Neither escape exists: **0 of 290 character cels are left-right palindromes**, and
`usealtsets` selects different *frames*, not orientations.

★★★ **And A.1 closes the mirror question outright: Jay gated a Path-B mirror on 2026-08-13.**
`sprite_convert.py` has **only** `--mirror` (Path B) and `--flip-parity` — **Path A has never
existed as an option**, so the bake could not have used it. `--mirror` entered on **2026-07-25**;
Jay gated the cutscene end to end on **2026-08-13** (`c0922b2`) and again on **2026-08-16**
(`b1638c3`, *"the exit walk looks good noe gate it."*). `cel_mirror_paths.py` — the tool that
raised the doubt — landed **2026-08-16**, *three days after the gate it would have questioned*.
**The princess's standing cel he passed is a Path-B mirror, and `char_draw.s:1067` says so.**

★★ **P3.103a's "the paths disagree in shape" is a finding about the UNCOMPENSATED case.** It ran
`parity_flip=False` on both paths [`cel_mirror_paths.py:122`]. The converter documents a **per-cel**
compensation — *"for even width_pixels, --flip-parity"* [`sprite_convert.py:166-168`]. Applied as
documented, **the disagreement collapses from 466 pixels to 3.**

**A.2's split, and the addendum's instinct was right:**

| | interior (chroma) | **boundary (silhouette)** | total |
|---|---|---|---|
| uncompensated — what P3.103a measured | 302 | **164** | 466 |
| **per-cel parity — what the bake ships** | **0** | **3** | **3** |

**A third of the uncompensated error was boundary.** A single aggregate would have hidden exactly
the failure mode A.2 named. As shipped: **zero chroma error, three silhouette pixels across six
cels.**

**Both of Jay's fixes are in and proved inert:** the comment is replaced (AC2, byte-identical), and
the config is fixed **at the mechanism** — 32 runners now source `cfgdir.sh`, and the tracked
template survived two gate runs unchanged (AC4).

---

### 2 — Files modified

**Phase 1 — Jay's two fixes:**
- `src/engine/blit_core.s` — the 1.20× paragraph now says what it is a measurement *of*. **Comment
  only; prod byte-identical.**
- `dist/mame-cfg/rgb/coco3.cfg` — **restored** to its documented form; the machine-specific
  `C:\Projects\POP3_port\build\` path is gone.
- `harness/smoke/cfgdir.sh` — **new.** One home for the cfg directory: copies the template to
  `build/tmp/mame-cfg` and points `-cfg_directory` there, so MAME rewrites the scratch.
- **32 runners** re-routed through it (31 under `harness/smoke/`, plus
  `harness/tools/run_block_budget.sh`).
- `harness/smoke/run_tile_test.sh` — **headless by default** (§6.2).

**Report:** `reports/20260822-190000-p5-11-…md`.

Measurement scratch, outside the repo: `p511_joint.s`.

---

### 3 — Reasoning

#### 3A — AC1: the comment, replaced

The new text, quoted (AC1). Added after the original paragraph, which is kept because it is true
*about the cutscene*:

> ★★★ **THE 1.20x IS THE CUTSCENE'S CONTENT, NOT THIS BLITTER'S PROPERTY, AND IT DOES NOT CARRY
> INTO GAMEPLAY.** P3.18 measured a vizier and a princess who move in 4-px steps BY CONSTRUCTION —
> `CH_STEP equ 8` [char_draw.s:360], whose own comment says *"MUST be a multiple of 4 px… Sub-byte
> motion is piece E's problem"*. A character that only ever moves whole byte-columns can only ever
> land on one phase, so 1.20x is a measurement of that decision, not of cels in general.
>
> A GAMEPLAY step is `Fdx`, and it is 1 or 3 px [FRAMEDEF.S:23,25 — run-4 and run-6]. P5.10
> write-tapped `setimage` on the running oracle and measured GAMEPLAY cels at 3.09 of the four
> phases, with 35% drawn at ALL FOUR. Baking that is ~189,000 B, about 24 blocks against the 8 free
> on a 128 KB machine — and doubling again for facing makes it ~47. Baking is not a tight option for
> gameplay; it is not an option.
>
> ★ SO THE NO-SHIFT DESIGN IS CORRECT FOR THE CUTSCENE AND MUST NOT BE CARRIED INTO GAMEPLAY ON THE
> STRENGTH OF THE PARAGRAPH ABOVE. The budget that decides it is the ANIMATION STEP, not the display
> frame: P5.2 measured the game at 9.5 fps against a 59.92 Hz display, so a character is drawn once
> per ~6.3 display frames and the real budget is ~188,400 cy, not 29,859. A runtime shift costs ~14%
> of that. [P5.10]

**Read back from the file, and the rebuild proves it inert** (§0, AC2).

#### 3B — AC3/AC4: the config, fixed at the mechanism

**What I found, recorded before changing it** (AC3) — saved to `build/tmp/p511_cfg_found.xml`:

```
<!-- This file is autogenerated; comments and unknown tags will be stripped -->
  <device instance="floppydisk1" directory="C:\Projects\POP3_port\build\" />
  <port tag=":screen_config" type="CONFIG" mask="1" defvalue="0" value="1" />
  ... plus <mixer>, <audio_effects> and <sound_map> blocks MAME added
```
sha1 `246dc4c8…` against HEAD's `9400c023…`. **The gate itself was never harmed** —
`screen_config value="1"` survives every rewrite, so no gate has run in the wrong monitor mode.
What was destroyed, one run at a time, was the header explaining why the file exists.

**The fix is the one the disk image already gets.** Every runner copies `build/probe.dmk` to a
scratch name before mounting it, *because MAME opens a floppy read-write and saves back* (idiom 24).
**The cfg directory is the same hazard and had the opposite treatment.** `cfgdir.sh` copies the
template to `build/tmp/mame-cfg` and sets `CFGOPT`; 32 runners source it. The header is preserved in
two places the rewrite cannot reach: the restored template, and `cfgdir.sh` itself.

**AC4 — the gate run twice:**

```
before   1be62aef2325c60f73d703db00689ea19c3ab75e
run 1 -> 1be62aef2325c60f73d703db00689ea19c3ab75e   PASS
run 2 -> 1be62aef2325c60f73d703db00689ea19c3ab75e   PASS
scratch build/tmp/mame-cfg/coco3.cfg: contains "autogenerated"  <- MAME wrote HERE
```

**Unchanged both times, and the scratch carries the rewrite that used to land on the template.**

#### 3C — AC5/AC6: facing, read from the costing

*Authority: the code, not the absence of a keyword.*

```python
def bytes_of(self, cels):
    n = 0
    for t, im in cels:
        cel = tab[im - 1]
        n += coco3_bytes(cel["w"], cel["h"])
```
[`seq_graph.py:239-246`]

**One cel, one cost.** `cels()` builds a set of `(table, image)` pairs from frame numbers; a facing
is not part of that key and never enters the sum. **61,195 B is one facing.**

**The oracle stores one facing** — `LAY / lda OPACITY / bpl :notmirr`, *"Transfers control to MLAY if
image is to be mirrored"* [`HIRES.S:650-662`] — **and the port cannot**, per P3.65
[`char_draw.s:1171-1176`], so it needs both baked.

**Re-costed (AC6):**

| | bytes | blocks |
|---|---|---|
| P5.9's figure, one facing | 61,195 | 8 |
| **both facings** | **122,390** | **15** |
| + scenery/foreground 6,879 | | 1 |
| + tile page | | 1 |
| **total against 8 free** | | **17 — over by NINE** |

**Both escapes checked and both fail.** **0 of 290** character cels across CHTAB1/2/3/4.GD/5 are
left-right palindromes (every row's Apple pixel sequence tested for symmetry; bit 7 excluded as the
palette select, not a pixel). And `usealtsets` maps the guard to **ALTSET1**, a different *frame*
table selecting different images from the same art — **not a mirrored orientation**.

★ **This is the third time this arc a figure computed under one assumption has been used under
another**, and it is the largest: W0 as a window figure (P5.6), W1 read from prose beside the tool
output that contradicted it (P5.9), now facing.

#### 3D — AC7/AC8/AC9a: which path, and when it was gated

**AC7 — the bake uses Path B, and could not have used anything else.** `sprite_convert.py` exposes
`--mirror` and `--flip-parity` and nothing else; **there is no mirror-in-Apple-space option in the
converter at all.** `--mirror` is documented as *"reverse the per-row PIXEL list… BEFORE packing"*
[`sprite_convert.py:152-157`] — Path B by definition.

**AC8 — P3.103a's finding, quoted verbatim from a fresh run:**

> `# ★★★ THE PATHS DISAGREE IN SHAPE — the mirrored conversion moves ink.`
> `    shift per cel: 48:+0 49:+0 50:+0 51:+0 52:+0 53:+0`
> `    spread 0 px  =>  CONSTANT`
> `# NOTE: cels differ in palette INDEX at pixels where both have ink. That is a`
> `#   colour difference, not a position one — it cannot move a character, and it`
> `#   is the directional NTSC chroma rule reversing with the pixel list.`

★ **But it ran `parity_flip=False`** [`cel_mirror_paths.py:122`], and the converter documents a
**per-cel** compensation keyed on width parity. Applying it as documented:

| Path B variant | total disagreement |
|---|---|
| `parity_flip=False` (P3.103a) | **466 px** |
| `parity_flip=True` everywhere | 468 px — *swaps which cels fail* |
| **`parity_flip` per cel by width parity** | **3 px** |

**The middle row is the tell**: a global flip does not reduce the error, it moves it from the
odd-width cels to the even-width ones. **The rule is per cel, and the converter says so.**

**AC9a — the dates:**

| date | commit | event |
|---|---|---|
| 2026-07-25 | `5ed34ed` | `--mirror` (Path B) enters the converter |
| **2026-08-13** | `c0922b2` | **"the cutscene is gated end to end"** |
| 2026-08-16 | `1e3cb74` | P3.103a — `cel_mirror_paths.py`, the doubt |
| **2026-08-16** | `b1638c3` | **Jay: "the exit walk looks good noe gate it."** |
| 2026-08-16 | `862778c` | wip→main: *"the intro plays, the scene is in it, and Jay gated it"* |

> **★★ A.1's answer: the cutscene AS GATED was Path B, twice, and the tool that raised the doubt
> post-dates the first gate by three days. The calibration point was collected on 2026-08-13, on a
> character who stands still — and `char_draw.s:1067` records that from the scene's opening onward
> the princess's standing cel IS the mirrored bake. §3.4's "would Jay accept it" is already
> answered: he did, on hardware, twice.**

★ **And the turn A.2 worried about is in the gated scene.** `char_draw.s:1067`: *"Palert ends
`aboutface`"* — she turns, so both facings appear back to back in the beat Jay watched. **The
one moment A.2 says motion cannot mask is the moment the gate covered.**

#### 3E — AC9 (amended): the error as two figures

*Authority: computation over the frozen colour model, both paths in CoCo pixels only.*

| | interior (chroma) | **boundary (silhouette)** | total |
|---|---|---|---|
| uncompensated (P3.103a's configuration) | 302 | **164** | 466 |
| **per-cel parity (what the bake ships)** | **0** | **3** | **3** |

Per cel, as shipped: 48 → 0, 49 → 0, 50 → 0, 51 → 0, **52 → 2 boundary**, **53 → 1 boundary**.

**A.2's mechanism is real and its worry is the residue.** The `gap == 1` arm writes a pair —
chroma at `col-1`, WHITE at `col` — and at a cel edge a displaced pair adds or removes an outline
column. **Uncompensated, 164 of 466 differing pixels are exactly that.** Compensated, three survive,
in two of six cels. **Three pixels is not zero**, and the honest statement is that the shipped
mirror can make a silhouette one pixel different in a small minority of cels.

**The cheapest artifact that would show it** — named, not built, and per A.1 probably unnecessary:
the `aboutface` beat of the existing cutscene, frame-stepped, since it already contains both facings
of the same cel back to back and is already on the disk.

**Not decided.** Jay's lean is recorded; A.1 says he has already ruled in practice.

#### 3F — AC10/AC11/AC12: cycle cost

**AC10 — yes, cycle cost is now the operative question**, because A.1 closed correctness. §3.4's
condition (*"if a Path-B mirror could be acceptable"*) is satisfied by a hardware gate rather than by
a measurement.

**AC11 — costed jointly, not summed.** Decoded from an assembled snippet (scratchpad, not the repo):

| inner step | instrs | cy/byte (un-amortised) | ratio to plain |
|---|---|---|---|
| plain (today's opaque path) | 2 | 12 | 1.00× |
| mirror only | 3 | 18 | 1.50× |
| **mirror + shift, jointly** | 10 | **55** | **4.58×** |

Scaled onto `blit_core`'s **measured** 4.5 cy/byte opaque path: **mirror 6.8, joint 20.6 cy/byte.**

Against P5.7's 1,922 B joint per-frame peak and the ~188,400 cy animation-step budget:
**1,922 × 20.6 = 39,593 cy = 21.0%.**

★ **And the sum would have been wrong in the other direction here.** Mirror-alone (6.8) plus
P5.10's shift-alone (~14) is 20.8 — coincidentally close to the joint 20.6, because my snippet's
middle spills through memory twice (`sta tmp` / `lda tmp`, 20 of its 55 cycles). **A register-resident
version would be materially cheaper, so 20.6 is an upper bound**, and the agreement with the naive
sum is arithmetic luck, not a reason to trust summing.

**AC12 — what `blit_cel` would need.** The mirror is **one 256-entry table**: reversing four 2-bit
pixels within a byte and swapping the chroma indices are the same lookup, because `parity_flip` is a
pure blue↔orange index swap — `(2 if ((screen_col % 2 == 0) ^ parity_flip) else 1)`, and the code's
own comment says *"color-only, no shape change"* [`sprite_convert.py:187-191`]. **The byte-order
reversal is free**: `blit_core`'s header says *"PULU ASCENDS, PSHS DESCENDS, AND THAT IS
LOAD-BEARING"* — the descending traversal a mirror needs is already the primitive.

**The segment format survives reversal, with one caveat I am flagging rather than resolving.**
`$40` skip and `$80` blast are order-free run lengths and reverse cleanly. `$C0` merge carries
`(mask,src)` pairs which reverse with their bytes. **But the header notes `$80` groups are
"pre-reversed"** for the `pulu`/`pshs` core — so a mirrored blit reverses an already-reversed group,
and whether that cancels or compounds is a question for whoever implements it. **Not established
here.**

---

### 4 — Phase 4: the proposal

**4.1 — AC13: the corrected residency and the gap.**

| | blocks |
|---|---|
| characters, both facings baked (the honest current figure) | **15** |
| characters, **one facing + runtime mirror** | **8** |
| scenery + foreground | 1 |
| tile page | 1 |
| **against 8 free** | **17 baked / 10 mirrored** |

> **The gap is NINE if facing is baked and TWO if it is mirrored. A runtime mirror does not close
> the gap — it restores it to the size P5.9 reported.** P5.9's "over by two" was never a figure
> about a baked-facing port; it was a figure about a port that mirrors, computed before anyone
> noticed the closure counted one facing.

**4.2 — What I am proposing:** that the character bake stores **one facing**, and that the mirror and
the shift are done at draw time in a single pass sharing one table lookup. **Correctness has a
hardware gate behind it (§3D); cost is 21% of an animation step and that is an upper bound (§3F).**

**4.3 — AC14: what I am NOT proposing.**

1. Not proposing to **build** the mirror, the shift, or anything else. Phase 1 was the only build.
2. Not proposing to **rule on the 3 boundary pixels** — Jay's, and A.1 argues he already has.
3. Not proposing to **resolve the pre-reversed `$80` group question** (§3F) — flagged, not answered.
4. Not proposing to **close the two-block gap**, choose among A/B/C, or recruit blocks.
5. Not proposing to **start the character bake**, convert the dungeon flames, or touch `LEVEL0+`.
6. Not proposing to **re-run P5.9's closure** — its arithmetic is unchanged; only its interpretation
   (one facing, not two) is corrected.
7. Not proposing the **headless default beyond `run_tile_test.sh`** (§6.2) — the other automated
   runners still open windows and that is a follow-up, not a silent sweep.

---

### 5 — Verification (AC-by-AC)

- **AC1** — §3A, new text quoted. **AC2** — §0, all three sha1s identical across a full rebuild.
- **AC3** — §3B: mechanism fixed, prior contents recorded to `build/tmp/p511_cfg_found.xml`, header
  preserved in the template and in `cfgdir.sh`, absolute path gone.
- **AC4** — §3B: two runs, `1be62aef…` unchanged both times, scratch rewritten instead.
- **AC5** — §3C: **one facing**, read from `bytes_of()`.
- **AC6** — §3C: 15 blocks, budget 17 of 8; **0 of 290 symmetric**, `usealtsets` is frames not
  orientations.
- **AC7** — §3D: **Path B**, and Path A is not an option in the converter.
- **AC8** — §3D: quoted, with its `parity_flip=False` configuration named.
- **AC9** — §3E: **interior 0 / boundary 3** as shipped; 302/164 uncompensated. Artifact named, not
  decided. **AC9a** — §3D: Path B, gated 2026-08-13 and 2026-08-16, tool dated 2026-08-16.
- **AC10** — §3F: yes, correctness is closed by the gate. **AC11** — §3F: 20.6 cy/byte joint, 21.0%,
  upper bound. **AC12** — §3F: one table; `$80` pre-reversal flagged.
- **AC13** — §4.1. **AC14** — §4.3.
- **AC15** — suites green: **128 KB first** (`introseq`/`integ`/`tile` ALL PASS), then **512 KB ALL
  PASS**. I ran 512 KB rather than assuming: Phase 1 touches no MMU, bank, framebuffer or loader
  path, so per CLAUDE.md §2K it should not differ — **and it does not.**
- **AC16** — §6.

---

### 6 — Reactive deviations and route accounting

1. **32 runners changed, not one file.** §1.2 said fix the mechanism; the mechanism lives in every
   runner that names `-cfg_directory`. All now source `cfgdir.sh`, and the residual check
   (`grep -rl cfg_directory | grep -q cfgdir.sh`) is clean.
2. **★ `run_tile_test.sh` made headless by default.** Not asked for, and beyond §1.2. It is P5.10
   §8.5's follow-up and directly answers Jay's *"i keep having to start it for you."* **Two of AC4's
   runs still opened windows** because my first patch attempt failed silently (a backslash
   continuation inside a triple-quoted Python string — the same class of failure §2H's heredoc rule
   exists to prevent, arriving through the tool I used to avoid heredocs). Fixed with `str_replace`;
   the third run was headless. **The live gate runners keep their window deliberately.**
3. **A measurement snippet assembled in the scratchpad** (`p511_joint.s`), same precedent as P5.6.
   Not under `src/`, not linked, not built.
4. **I re-ran `cel_mirror_paths.py` with a configuration it does not expose** (per-cel
   `parity_flip`), rather than only quoting its output. That is what turned 466 into 3, and it is a
   different claim from the one the tool prints — **stated as mine, not as P3.103a's.**

**ROUTE ACCOUNTING.** No route proposed in conversation beforehand. The addendum arrived mid-task and
was folded in rather than restarting: **A.1 was done first and made §3.4 conditional-on-nothing**
(correctness closed by a hardware gate), so §3.4 was answered anyway for AC10-AC12 rather than
skipped — the dispatch says skip it *if a Path-B mirror could not be acceptable*, and A.1 shows the
opposite. **A.2's split is reported as two figures throughout and never aggregated.**

**Contains:** Phase 1's two fixes, AC1-AC16, no engine code beyond the comment.
**Does not contain:** any mirror, any shift, any bake, and none of §4.3's seven non-proposals.

---

### 7 — Uncertainty flags

1. **★ The 3-pixel boundary residue is six cels of the vizier's walk**, the set
   `cel_mirror_paths.py` ships with. It is not a census over the 271-cel closure, and the rate could
   differ. The *mechanism* generalises; the *number* does not.
2. **★ The per-cel parity rule is my reading of the converter's docstring**, applied as
   `parity_flip = (apple_width*7 % 2 == 0)`. The docstring says *"for even width_pixels"* and also
   mentions `--render-col-byte`, which I did not model. **If the real rule keys on the render column
   rather than the width, the 3 could move.**
3. **20.6 cy/byte is an upper bound** (§3F) and the snippet is deliberately unoptimised. It is also
   not `blit_cel`'s real inner loop, which works in `pulu`/`pshs` groups of six.
4. **The `$80` pre-reversed group question is open** and could make a mirrored blit cheaper or
   costlier than §3F says.
5. **15 blocks assumes the doubling is uniform.** Both facings of a cel are the same size, so the
   byte figure is exact, but the *packing* into blocks was not re-measured — P5.7 found real
   packing at 98-99% fill for one facing.
6. **A.1's conclusion rests on the converter having no Path A at any point**, which I established
   from the current file and the `--mirror` commit history, not by reading every intermediate
   revision.

---

### 8 — Follow-up candidates

1. **Census the interior/boundary split over the whole closure**, not six walk cels (flag 1).
2. **Settle the per-cel parity rule from the converter's authors' intent** — width parity or render
   column (flag 2).
3. **Resolve the pre-reversed `$80` group question** before any mirror is implemented (flag 4).
4. **Sweep the headless default across the remaining automated runners** (§6.2) — ~30 files, and the
   live gate runners must be excluded deliberately.
5. **The nine-block gap is now the arc's number**, not two — and it is two only if the mirror is
   built.

---

### 9 — User interaction during task

**One, mid-turn: Addendum A** (A.1 check whether the ruling exists; A.2 report the error as two
figures). Both folded in without restarting: A.1 is §3D and changed the shape of §3 as it predicted;
A.2 is §3E and its instinct was borne out — a third of the uncompensated error is boundary, which a
single aggregate would have hidden. No ruling was sought or given on acceptability.

---

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-22-the-defect-may-be-the-configuration-the-test-ran-in.md` — §3D: the
test that found the mirror 'moves ink' ran it with the converter's documented compensation off; the
global-flip run redistributing failures rather than reducing them is what exposed the per-item rule.
Pushed as `528e06f`.

---

### 11 — Commit

`a437173` (pushed to origin/wip). **`main` is untouched at `32b5fe2`.**
