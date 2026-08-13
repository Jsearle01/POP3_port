## Form B Report — P3.79 §1 — the loads are the encoding's fault, not the mirror's

**Class:** recon (measurement only — **nothing built, nothing unwound**). wip. Prod untouched.
**HARD-STOP: §1's answer is an architecture recommendation and it is Jay's to take.** §2 (the
clip) and §3 (the two live defects) are NOT reached — deliberately, because §1's answer
changes what is worth building.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-12T20:30:13-04:00 (HEAD `3ceaa49`, wip). Now at `c3c947c`, pushed.
POP `main` untouched at `635f986`. **Karateka untouched** — `wip` `ac2b768`, `main` `5eb92b1`.
Tree otherwise unchanged from P3.78d: the failing `co_clip` is still in place, as intended.
No source touched; three read-only tools added.

---

### 1 — Summary

**Jay: *"There are now 3 disk loads for this one scene. That seems excessive. Did we miss
something or are we overcomplicating this?"* … *"Why don't we mirror at draw time?"***

**He is right that something is wrong. The mirror is not it.**

| | |
|---|---|
| **the oracle holds** | **7,891 B** of cels for this scene, 128 KB, one load |
| **the port holds** | **38,424 B** — **4.87×** |
| less every mirrored variant | 32,613 B — still **4.13×** |
| the pixel-depth floor (7 px/byte → 4 px/byte) | **1.75×** — not a choice |
| **left to explain** | **2.36×, and it is ours** |

**Where it goes, measured cel by cel:**

```
per-SEGMENT and per-ROW punctuation   24,938 B   64.9%
the mask column                        4,468 B   11.6%
actual pixels                          8,890 B   23.1%
```

**Run through the real packer** — because a total that fits on paper can still fail to pack,
as P3.78 found when the whole scene was declared unpackable over 78 bytes:

```
today (baked mirrors)     38,424 B   5 pages   2 staged reads   3 DISK LOADS   <- ships
mirror at draw time                  DOES NOT PACK
packed segment header     28,101 B   4 pages   1 staged read    2 DISK LOADS
both                      26,985 B   4 pages   1 staged read    2 DISK LOADS
```

**★ Mirroring at draw time makes it WORSE. ★ The encoding removes a load and extends
nothing.** **Nothing was built.**

### 2 — Files modified

`c3c947c` — three read-only measuring tools, no engine or content change:
- `harness/tools/oracle_vs_port_bytes.py` — the same cel set, both sides, attributed.
- `harness/tools/cel_encoding_census.py` — where the port's bytes go, segment by segment.
- `harness/tools/mirror_economics.py` — each scenario through the real `cel_pack`.

### 3 — Reasoning

**3A — The comparison, and the fairness check it needed first.** The oracle's cutscene cel
table `IMG.CHTAB6.A` is **9,201 B** whole; the 55 distinct cels this scene draws are
**7,891 B** of it, each stored ONCE — one facing, one phase.

**Before comparing I checked whether the oracle pays a cost we do not.** It does not: POP
draws characters with `lda #ora` [FRAMEADV.S], and hi-res is **one bit per pixel**, so `ORA`
leaves the destination wherever the sprite bit is 0 [HIRES.S:776]. **Transparency is free
and no mask image is stored.** Only certain background pieces carry a `maska`; characters
do not. Its sub-byte shift is likewise free at draw time — `lda (IMAGE),y / TAX / LDA
SHIFTn,X` is a 256-byte lookup [HIRES.S:695-710], which is why it stores no phase variants
either.

CoCo3 4-colour is **two bits per pixel and OR does not compose**: a destination pixel of
`01` under a source of `10` ORs to `11`, a third colour. So a partially-transparent byte
genuinely needs `(dest AND mask) OR src` and a stored mask. **That part is real and is not
recoverable** — but it is only 11.6% of the image.

**3B — ★★ THE FAT IS THE PUNCTUATION, AND THE HISTOGRAM IS THE PROOF.** Every run costs
**two bytes**, an opcode and a count:

```
run length   1: 6,330 segments     4:   355
             2: 3,087              5:   128
             3: 1,162             6+:    49
```

**6,330 of 11,111 segments are ONE BYTE LONG**, 3,087 are two. The encoding routinely
spends a two-byte header to describe a single byte of picture, on cels averaging **6.4
bytes wide** — a row is a handful of very short runs, and the punctuation costs nearly
three times the pixels.

**The longest run anywhere is 10**, which needs four bits. **Opcode plus count fits in one
byte with two bits to spare**, saving exactly one byte per segment: **10,323 B**, 27% of
the image. This is not a compression scheme or a new representation — it is the same
segments with the header packed, and the blitter reads a nibble instead of a byte.

**3C — ★★ AND MIRRORING AT DRAW TIME MAKES IT WORSE, WHICH IS NOT WHAT I EXPECTED.**
Dropping the mirror is **a set change, not a size change**, and that is the whole subtlety.
P3.76 §3E observed it and this quantifies it: with baked mirrors `Vexit → Vwalk2` reuses
the walk's cel NUMBERS and none of its baked BYTES, so `v48..v53` **retire at beat 9**.
Mirror at run time and the exit reuses the *normal* walk cels, which must then stay live
**from beat 4 to beat 16**.

The bytes go away and the **residency gets longer** — and residency is what a block schedule
is made of. The packer cannot find any grouping: *"no grouping of the beats into ≤3 blocks
refilled at [1, 6, 10] produces a page schedule."*

So the answer to *"why don't we mirror at draw time?"* is: **it would not have helped, and
it is the second time this arc that the mirror has been costed wrong** (P3.75 §3D called it
a precondition; P3.76 §3D withdrew that). Its ~3,080 cy/cel (P3.72n) was never assembled
and timed, and on this evidence it should not be — the RAM case for it has collapsed twice.

**3D — What it does to the freeze.** Today: **3.19 s + 2.89 s = 6.08 s** of frozen torches
(measured P3.78). With the encoding packed: **one staged read, ~3.19 s**, and the second
freeze disappears. **★ And at 4 pages against 3 blocks the scene is ONE PAGE from needing
no staged read at all** — a little more saving, or a better grouping, reaches a single load
and no freeze whatsoever.

### 4 — Verification

**25.1 fresh tool output (at `c3c947c`):** the three tools' output is quoted in §1 and §3
verbatim. Two independent cross-checks, both of which had to agree or one tool was wrong:
- `cel_encoding_census` totals **38,424 B**, exactly `oracle_vs_port_bytes`' PORT column and
  exactly the sum the linker places. *(A first draft read 46,488 — it multiplied a
  per-cel accumulator by the cel count. It was caught by that column disagreeing.)*
- Every scenario is run through the **real `cel_pack`**, not arithmetic.

**No build was run and no suite was run**, because no source changed. The tree is exactly
P3.78d's, whose condition is stated there: build green, room suite 8/8 in-emulator with the
asset comparison FAILING, walk suite failing at `beats_visited`.

**25.2:** N/A. **25.3: not offered** — nothing visual changed.

### 5 — Acceptance criteria

1. **Load count with runtime mirroring answered** — **yes.** It does not reduce loads; it
   **does not pack at all**. Frame cost at the mirroring beats: **not measured, and
   deliberately** — the RAM case collapsed, so timing it would be spending a measurement on
   a settled question (§7 flags this as the one AC item consciously left open).
   Freeze effect: **6.08 s → ~3.19 s** under the encoding change (§3D).
2. **Oracle-vs-port resident bytes compared and attributed** — **yes** (§3A/3B).
3. **A recommendation with numbers** — **yes** (§8), **and it is Jay's to take.**
4. **`co_clip` diagnosed** — **NO, not reached.**
5. **The turn-to-exit disappearance diagnosed** — **NO, not reached.**
6. **Suites green both sizes** — not run; no source changed. Unchanged from P3.78d.
7. **Build left in the tree, condition stated** — yes (§4).
8. **Route accounting; sync bridge; Karateka and `main` untouched** — yes.

### 6 — Reactive deviations and route accounting

**The dispatch asked for §1 (the economics), then §2 (the clip), then §3 (the two defects).
This contains §1 complete and stops there.**

**That is a deliberate stop, and the dispatch's own §4 is the reason:** *"Do not build more
beats on the current arrangement until §1 is answered — that is the point of asking now."*
§1's answer is that **the arrangement itself is built on a number three times larger than it
needs to be.** Diagnosing `co_clip` and the turn is still worth doing and neither is
invalidated — but re-encoding the cel format changes every cel's bytes, every page boundary
and the whole schedule, so doing it before Jay rules would risk debugging the clip twice.

**HARD-STOP #2 did not fire in the form it was written** — it fires if runtime mirroring
*removes* a load, and it does not. I am treating the encoding finding as the same class of
event (an architecture change, Jay's to authorise) and stopping on it.

Not present: any change to the swap, the packer, the encoding, the clip, the turn
diagnosis, the hourglass, the flash, `s_Magic`, the 16-colour swap, the `Prolog2` handoff.
**The swap was not unwound** (§4 of the dispatch); `shift_row.s` not reopened; the hourglass
verdict not reopened.

### 7 — Uncertainty flags

- **The packed-header saving is modelled, not built.** 10,323 B is exact arithmetic over
  the measured segment count, but the re-encoder has to be written, the blitter has to read
  the new form, and `cel_blit_prep`'s replay check must be re-pointed. **The pack results
  above assume the saving lands exactly.**
- **The runtime mirror's cycle cost is still P3.72n's instruction-count sketch**, never
  assembled and timed. §5.1 states why I did not spend the measurement.
- **The oracle figure is its CEL TABLE only.** It excludes the oracle's own shift tables
  (four 256-byte tables ≈ 1 KB, shared by every sprite in the game) and its scene scripts.
  Adding those would raise the oracle side by roughly a kilobyte and the ratio would fall
  from 4.87× to ~4.3× — **it does not change the conclusion, and I have not counted them
  because they are shared across the whole game rather than this scene's cost.**
- **Name the layer:** every figure in §1 and §3 is **resident cel bytes**, one layer. The
  39,682 B quoted in earlier reports is the LINKED IMAGE (cels + the 1,360 B table +
  padding); the 38,424 B here is the cels alone. Same scene, different layer.
- Carried from P3.78d: the clip fails; the turn-to-exit disappearance is undiagnosed; the
  hourglass and flash unbuilt; ROOM.BIN has 7 bytes of headroom; 0.20 s per-call driver
  overhead; the `$2310..$2329` read-tap blindness.

### 8 — Recommendation, and it is Jay's call

**Re-encode the cel format: pack the segment opcode and count into one byte.**

- **10,323 B**, 27% of the cel image, for a change that extends no residency and touches
  no scene logic.
- **3 disk loads → 2**, and the second freeze (**2.89 s**) disappears.
- It leaves the scene **one page short** of needing no staged read at all — worth a look at
  the grouping afterwards, because zero freezes is reachable.
- **Do NOT mirror at draw time.** It saves 5,811 B and costs the schedule outright.

**Sequencing, if taken:** re-encode → re-bake → re-pack → *then* the clip and the turn, so
neither is debugged against bytes that are about to change.

**If Jay would rather ship what works:** the current arrangement is correct and measured;
three loads and 6.08 s of freeze is the price, and the clip and the turn can be taken next
with no re-encode at all.

### 9 — User interaction during task

Jay's two questions ARE this dispatch, and both were right: the loads are excessive, and the
port had never compared itself to the machine it is a port of. His second question — *"why
don't we mirror at draw time?"* — turns out to have the opposite answer from the one it
implies, and finding that out is what located the real cost.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-12-compare-the-result-against-what-the-original-did.md` — pushed
(`0d72d72`). Six dispatches of paging machinery were built on a figure nobody had sanity-
checked against the original, and every individual step was correctly measured. The tell is
not a bad measurement; it is a **quantity that keeps needing more machinery to accommodate
it**.

### 11 — Commit

`c3c947c` — pushed to origin/wip before this report.
