## Form B Report — P3.105 — Suspect 3 confirmed, there is no fourth block, and the merge is not done

**Class:** recon (measurement + design). wip. **Prod untouched — no `src/`, `content/`, `link/` or
`build.bat` change. The merge was NOT attempted.**

**★★★ §3's TWO MEASUREMENTS BOTH LANDED AND BOTH CHANGE THE DESIGN'S INPUTS.**
**Suspect 3 is CONFIRMED and it is 5× worse than the gap it was suspected against: the TITLE
caption patch saves 5,361 B into 1,024 B of clearance.** **And there is NO fourth bank block —
the scene already uses all four ($0C pinned, $0D/$0E/$0F rotating), so §1's displace-and-reload
is mandatory rather than one of two options.**

**★★ I DID NOT DO THE MERGE, AND THE REASON IS BUDGET, NOT A HARD-STOP.** §1's reload, §2's
re-staging, §4's re-pointed suites and §8's live gate are a large connected change, and this
session does not have the room left to do them to the standard the last four dispatches were held
to. **A half-merged tree is the outcome P3.104 existed to prevent.** What is delivered is the
measurement AC3 asked for and the §2 design with its numbers, so the merge is a build step rather
than a design one when it is taken.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-16T20:42:03-04:00 (HEAD `1bf8191`, wip). Karateka untouched. `main` untouched. Oracle
read-only and not run. Pre-existing and not mine: `dist/mame-cfg/rgb/coco3.cfg`.

---

### 1 — Summary

| | |
|---|---|
| **★★★ SUSPECT 3 → CONFIRMED** | TITLE patch saves **5,361 B**; clearance is **1,024 B**. `$5400..$68F1` against the scene's `$5800..$69FF` |
| **★★★ …but SAFE AT THE INSERTION POINT** | **beats 4 and 5 both carry `BEAT_PATCH = 0`**, so no save is live across the scene call. **A condition, not a property** |
| **★★★ NO FOURTH BLOCK** | `$0C` pinned + `$0D/$0E/$0F` rotating = **all four** free blocks at 128 KB. §1's reload is **mandatory** |
| **★★ §2 design, with numbers** | move the **scene's** program off the LOADM image to a driver read at **`$2500`**; intro-only image is **`$2000..$2432`**, under the ceiling |
| **not done** | **the merge** — AC1, AC2 (built), AC4, AC5, AC7, AC8 |
| **stated** | `SetupDHires`/`Prolog2` absent, not built |

### 2 — Files modified

- `harness/tools/intro_patch_extent.py` — NEW; measures the caption patches' save extent
- `reports/20260816-204203-…md` — this

(explicit-path staging only)

### 3 — Reasoning

**3A — ★★★ SUSPECT 3, MEASURED, AND IT IS NOT MARGINAL.**

`patch_blit` saves every framebuffer byte it overwrites into `SAVE_BUF` so the caption can be
lifted again [`intro_seq.s:793-858`]. The extent is the sum of every run's `len`, read from
`build/assets/intro_bundle.raw` — **the artefact that reaches the disk, not the generator**:

```
  patch      first_row  rows  runs   SAVED B   SAVE_BUF end   verdict
  PRESENTS   103        45    45     747       $56EB          clear
  BYLINE     116        25    36     587       $564B          clear
  TITLE      102        87    229    5361      $68F1          ★ OVERRUNS $5800
```

**5,361 B of 1,024 available — 524% used.** P3.104 reported this as a suspect with the number
that would settle it; the number settles it against, and by a factor of five.

★★★ **AND YET IT IS SAFE AT THE POINT THE SCENE IS INSERTED — for a reason that has to be
written down rather than noticed.** The scene is called between beats 4 and 5 [P3.104 §3E], and:

```
  beat 4  prolog1 (track 9)    BEAT_PATCH  0   ; none: the picture IS the beat
  beat 5  prolog2 (track 18)   BEAT_PATCH  0   ; none
```

**Neither beat has a patch, so nothing is live in `SAVE_BUF` across the scene call.** Beat 6's
TITLE patch runs after the scene is completely finished, by which time the scene's packed bundle
at `$5800` has long been consumed by `bundle_expand`, and `$5400..$68F1` is clear again (it stops
below `DR_VARBASE $6A00` and well below the peel buffers at `$6C00`).

★★ **THAT IS EXACTLY THE SHAPE OF THE ASSUMPTION THAT FAILED AT P3.104** — *"the two programs
never run at once"*, true when written, enforced by nothing. **So it must not be left as an
observation.** A beat gaining a patch at that boundary, or the scene call moving, breaks it
silently and the symptom would be corrupted caption restore three beats later. **The enforcement
is named in §8 and it is cheap**; I have not built it because it needs the call site, which does
not exist yet.

**3B — ★★★ THERE IS NO FOURTH BANK BLOCK.**

§3 asked whether a fourth free block exists, so the intro's captions could live there instead of
being reloaded. **It does not.** At 128 KB the GIME masks a block number to installed RAM
[`gfx.s:406`], so:

```
  $00-$03  buffer A   (GFX_DB_A_BLOCK $10 aliases to $00)
  $04-$07  buffer B   (GFX_DB_B_BLOCK $14 aliases to $04)
  $08-$0B  the low 32 KB logical — program, kernel, DP, stack
  $0C      CEL_RES_BLOCK — the PINNED cel page      [content/cutscene/chars/cel_pages.s:22]
  $0D/$0E/$0F  the three rotating pages             [cel_pack.json schedule]
```

**All four of the free blocks are the scene's.** So the captions cannot be parked in a spare
block, and **§1's displace-and-reload is the only shape available** — which also means it is not
a choice Jay has to make between two options, and §3's *"if it is free and cheap, it may retire
§1's read"* does not arise.

★ **Reported rather than built, as §3 required.** And it is worth noting the answer is a
128 KB answer: at 512 KB there are blocks to spare, but **128 KB is the verification target
(§2K)** and a design that only fits on the confirmation machine is not a design.

**3C — ★★ §2's DESIGN, WITH THE NUMBERS, AND WHY THE CEILING IS NOT THE PROBLEM IT LOOKS LIKE.**

★★★ **Jay's correction is the whole of it:** *"D won't work since LOADM isn't available after
initial load."* `LOADM` is a BASIC command and BASIC is gone once the port has control — **so the
ceiling binds only on what must be resident at the instant BASIC hands over.** The ~$820 is not
too much data; it is too much data in the wrong stage.

```
  merged prog    intro_seq $03A5 + cutscene_room $03ED + lz_unpack $008E = $0820
                 -> $2000..$281F     against the MEASURED ceiling $2488..$2535
                 -> over by $02EA..$0397

  intro alone    $03A5 + $008E = $0433  -> $2000..$2432   ✓ under, with $56..$103 to spare
  scene alone    $03ED + $008E = $047B  -> $2000..$247A   ✓ under, barely
```

**So the LOADM image keeps the intro, and the SCENE's program moves past the handover.** It is
the route `link/pop_engine.link` already names — *"put the code on a disk-resident track and
reach it through a fixed table, the way the cutscene bundle does"* — and **the mechanism exists
on both sides**: the intro has its own `load_tracks` wrapper [`intro_seq.s:310`] over the
kernel's `disk_read_range`, and the kernel is resident at `$7900` throughout.

**Where it lands, and why that address:**

```
  $2000..$2432   the intro's program (LOADM'd, resident)
  $2440..$2FFF   FREE during the whole scene — 3,008 B
  $3000..$4883   the scene's flames bundle (unpacked)
  $5400..$68F1   the intro's SAVE_BUF worst case  }  never live at the same
  $5800..$69FF   the scene's packed bundle        }  instant — see §3A
```

**`$2500` gives the scene's `$03ED` program room to `$28ED`**, above the intro's code and clear
of `$3000`. ★ **It is above the LOADM ceiling and that is the point**: nothing `LOADM`s it. **A
free track exists — 17 or 24, both mapped free at P3.104.**

★ **I have NOT built this.** The numbers are from this build's maps; the design is stated so the
merge is arithmetic rather than discovery.

**3D — §2H's THREE CHECKS.**

1. **A second mechanism for a different object class?** Yes, and it is why §3B matters: the cel
   bank has **two** kinds of page — one pinned and three rotating — and asking "how many blocks
   does the scene use" of the schedule alone returns three. The pinned one is in a different
   file (`cel_pages.s`) and would have been missed by the obvious grep.
2. **The calling routine.** `SAVE_BUF`'s extent is not a property of `SAVE_BUF` or of
   `patch_blit` — it is a property of **the largest caption the bundle carries**, which is
   generated content. That is why the measurement reads the built asset.
3. **Grep the reports.** P3.104 called `$5400` a suspect and gave the number that would settle
   it. It is settled here, against — **and the earlier report's caution was the right call**, not
   an over-caution.

### 4 — Verification (AC-by-AC)

- **AC1 — `$3000` resolved by displace-and-reload; return read verified unseen.** ★ **NOT DONE.**
  §3B establishes it is the **only** available shape (no fourth block), which is progress on its
  inputs, not on the criterion.
- **AC2 — the image under the MEASURED ceiling, before/after reported.** **Design and numbers
  §3C; NOT BUILT.** Before: `$2000..$281F` merged. After (designed): `$2000..$2432`.
- **AC3 — `$5400` measured; the fourth-block question answered.** ★ **DONE, both.** §3A, §3B.
  Reported, not built, as §3 required.
- **AC4 — merge done; scene's suites against the integrated build.** ★ **NOT DONE.**
- **AC5 — entry state confirmed post-merge.** ★ **NOT DONE** — P3.104's pre-merge answer stands
  (the scene re-inits sys/MMU/mode/time and paints both buffers before its first peel save) and
  **"largely self-established" is still not "unchanged"**, exactly as §4 says.
- **AC6 — `SetupDHires`/`Prolog2` stated as absent.** **Both absent from the port; neither built.**
- **AC7 — suites green, 128 KB first; build verified by symbol.** §5.
- **AC8 — Jay gates LIVE.** ★ **Nothing to gate. No behaviour changed.**
- **AC9 — route accounting; sync bridge; Karateka; `main`.** §6.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim).**

```
# CAPTION PATCH SAVE EXTENT — measured from build\assets\intro_bundle.raw (9216 B)
# SAVE_BUF $5400; the scene's packed bundle lands at $5800; clearance 1024 B.
  patch      first_row  rows  runs   SAVED B   SAVE_BUF end   verdict
  PRESENTS   103        45    45     747       $56EB          clear
  BYLINE     116        25    36     587       $564B          clear
  TITLE      102        87    229    5361      $68F1          ★ OVERRUNS $5800
# worst case 5361 B of 1024 available — -4337 B of headroom (524% used).
# ★★★ SUSPECT 3 CONFIRMED
```

`CEL_RES_BLOCK equ $0C` [`content/cutscene/chars/cel_pages.s:22`]; schedule blocks
`['0xd','0xe','0xf']` [`cel_pack.json`]. Section sizes in §3C are from
`build/obj/introseq.map` and `build/obj/room.map` of the P3.103 build, which is the current tree.

★ **I did not re-run `build.bat` or the suites.** No source changed, so a suite result would be
evidence about a build this dispatch did not produce — **a green tick that means nothing is worse
than no tick**, and the last four dispatches have each turned up one stale checker.
`introseq`/`room`/`walk` were green at 128 KB at P3.103 and the tree is unchanged since.

**25.2 bundled-artifact grep:** N/A — nothing built or bundled.

**25.3 operator-runtime-smoke: N/A — no behaviour changed.** Standing gates unchanged: flash,
glass, sand, slump, the feet, and the exit walk (P3.103, Jay) all PASSED.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** No route proposed in advance. Against §6's nine criteria this change
contains **AC3 and AC6 in full, AC2's design and numbers without the build, and AC9**; **AC1,
AC4, AC5, AC7, AC8 are NOT DONE.**

★★ **Stated plainly because it is the load-bearing sentence in this report: the merge was not
attempted for want of session budget, not because a hard-stop fired.** §7's HARD-STOP 2 covers
"cannot be brought under the ceiling by re-staging" and that is **not** my case — §3C shows it
can. I am not dressing a budget limit as a rule. The judgement is that §1+§2+§4+§8 form one
connected change whose failure mode is a corrupted image with a silent signature, and starting it
without room to verify it is how P3.68 reached a running VM before jumping through cel data.

**Reactive deviations (§22.5):** one. `harness/tools/intro_patch_extent.py` is new tooling not
named in the dispatch; §3 asked for the measurement and the artefact is how it is repeatable
rather than a number in a report.

Oracle read-only and not run. Karateka untouched. `main` untouched. No `hal-sync` run — no HAL
change since P3.103's green check.

### 7 — Uncertainty flags

- **★★ The `$5400` safety is a CONDITION and nothing enforces it.** Beats 4 and 5 carry
  `BEAT_PATCH = 0` today. A beat gaining a patch there, or the call site moving, breaks it
  silently — corrupted caption restore three beats later. §8.1.
- **★ `$2500` is proposed, not proven.** The region is free by inspection of the current maps; it
  has not been exercised, and DECB's post-handover workspace has not been re-checked at that
  address (the ceiling work at P3.20/P3.22 measured the LOADM path, not what is safe afterwards).
- **★ The scene-alone image is `$2000..$247A` against a ceiling of `$2488..$2535`** — 14 bytes of
  clearance at the low end of the bracket. It ships today, so it works; it is worth knowing how
  little room it has if anything is ever added to the scene's program.
- The fourth-block answer is a **128 KB** answer (§3B).
- Carried: the mirrored cels' chroma; the exit's +13% cause; P3.103's `mode`-cycling gap;
  `SetupDHires`/`Prolog2`.

### 8 — Follow-up candidates

1. **★ Enforce the `$5400` condition at build time** — assert that no beat straddling the scene
   call carries a non-zero `BEAT_PATCH`, or that the worst caption save fits below whatever the
   merged layout puts above `SAVE_BUF`. `intro_patch_extent.py` already computes the number; it
   needs a target to compare against, which the merge supplies.
2. **The merge itself**, per §3C: relink `cutscene_room.o` at `$2500` as its own disk-resident
   image on track 17 or 24, read by the intro's `load_tracks`, entered through a fixed address;
   the caption reload before beat 5; then AC4/AC5/AC7/AC8.
3. **Re-point the scene's suites at the integrated build** before quoting any of them as evidence
   about the integrated scene (§4 / P3.104 §4a).
4. Verify read-before-reveal across the whole sequence as a measurement — the return read adds one
   to a boundary that did not have one, and it has regressed twice.

### 9 — User interaction during task

None.

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-16-a-ceiling-that-binds-on-a-stage-not-a-total.md`

### 11 — Commit

See below — pushed to origin/wip before this report.
