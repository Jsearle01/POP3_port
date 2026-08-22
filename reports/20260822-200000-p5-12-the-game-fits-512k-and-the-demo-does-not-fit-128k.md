## Form B Report — P5.12 — the whole game fits 512 KB, and the demo does not fit 128 KB

**Class:** recon. `wip`. Prod byte-identical at both ends. **Nothing built.**

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-22T19:17:56Z (HEAD `be62dae`, wip; **`main` at `32b5fe2`, resolved here**).

`git status` at receipt — the standing untracked set: `.vscode/`, `nvram/`,
`POP-idioms-coco3-markers.md`, `content/intro/broderbund_splash_render.bin`, nineteen files under
`docs/ground-truth/`, `docs/project/pop-coco3-design-v0_7.pdf`. **No modified tracked files** —
`dist/mame-cfg/rgb/coco3.cfg` stayed clean through this task, which is P5.11's fix working.

**Prod sha1 — identical at both ends (AC11). Nothing rebuilt:**

```
d07f1f3295525783968dcce6409ee1b64942231c  build/intro_seq.bin
0b4968867bf5274d2942f3b5b90ea855ad6f2def  build/loader.bin
790836577e56b61b8f849cb309874e44304840a2  build/cutscene_room.bin
```

**AC10 — the stop observed:** `git status --porcelain src/` → **0 lines** at both ends.

---

### 1 — Summary (AC9 up front, because it is the answer Jay asked for)

> **★★★ YES. The whole game fits 512 KB — comfortably, and not only per level.** Per-level loading
> needs **16 of 56 free blocks**; even holding **everything resident at once** needs **~44 of 56**.
> The margin is real but not enormous, and three of its inputs are lower bounds. **128 KB cannot do
> it at any granularity: per-level loading alone needs 16 blocks against 8.**

★★ **And the demo does not fit 128 KB either, which decouples nothing.** P5.7's "6 blocks, one
spare" used the demo's *observed run*. §2.2 was right that the run understates it: the demo's
fighters are **guardprog rows 10 and 11** — my own `demo-behaviour.md:269` records that *"columns
0-9 are the game's"*, and the fighter table has twelve — and a guardprog changes **probabilities,
not the alphabet** [`AUTO.S:99-124`: strikeprob, blockprob, advprob…]. **So the demo can demand the
whole fight closure: 61,195 B = 8 blocks, and 8 + tiles + scenery = 10 against 8.**

★ **Two of §1's corrections land, one in each direction.**
- **Variety confirmed as the driver**, measured rather than asserted: bytes vs distinct
  (obj,state) pairs **r = +0.836**; bytes vs non-empty blocks **r = +0.675**. P5.4 stands.
- **Cross-level dedup within a tileset is large and was uncounted**: **50.5%** on tileset 00 and
  **64.6%** on tileset 01. Fifteen levels really do not need fifteen independent variant sets.
- ★ **But the Orchestrator's withdrawn 90-120 blocks was not pessimistic — it was optimistic in the
  wrong place.** LEVEL0 is **the smallest level in the game** (20 pairs / 210 blocks against a
  median around 39/520), so every figure extrapolated from it understates.

★★★ **A hard scoping limit found and not worked around: one third of the game's tile art is not in
the tree.** `bgset1` names three tilesets [`MISC.S:772`] and `bg1trk hex 05,00,07` /
`bg2trk hex 12,02,09` [`MASTER.S:524-525`] confirm three on-disk sets. `Images/` holds **two** —
DUN and PAL. **Levels 7, 8, 9, 12 and 13 cannot be costed in bytes from this repository.** Their
blueprints are present, so their *variety* is measured and their bytes are **estimated at the
measured deduped rate and labelled as an estimate**, never as a measurement.

---

### 2 — Files modified

- `harness/tools/game_census.py` — **new.** Per-level and per-tileset tile census over all fifteen
  levels, the variety-vs-density check, and the bounded estimate for the absent tileset.
- `reports/20260822-200000-p5-12-…md` — this report.

Nothing under `src/`, `link/`, `content/`, `dist/`. `build.bat` untouched.

---

### 3 — Reasoning

#### 3A — AC1: the demo's own requirement, and a plain no on 128 KB

*Authority: source for the mechanism, P5.9's graph tooling for the closure.*

**§2.2's premise checked out, and my first reading of it was wrong.** Walking every blueprint's
`INFO` guard records (`GdStartProg` at +167) gives LEVEL0 **guardprogs 1 and 5** — no level in the
game uses 10 or 11. That looked like a refutation. It is not: the fighter parameter table
[`AUTO.S:99-124`] has **twelve columns**, and `docs/project/demo-behaviour.md:269` — written by this
project at P5.3 — records *"columns 0-9 are the game's"*. **Rows 10 and 11 are the demo's, assigned
at demo start rather than carried in the blueprint**, which is exactly why LEVEL0's own record says
1 and 5.

★ **And the closure over them is the full fight closure, for a reason that makes the question
easier than it looks.** A guardprog row is `strikeprob / restrikeprob / blockprob / advprob /
refractimer` — **probabilities and a timer. It changes how often a move is chosen, not which moves
exist.** So guardprogs 10/11 reach the same sequences as any other, and the demo's character
requirement is the kid ∪ guard closure:

| figure | bytes | blocks | what it is |
|---|---|---|---|
| the demo's *observed run* [P5.7] | 36,142 | 5 | one 50 s path — **understates** |
| **the guardprog closure** | **61,195** | **8** | what the demo CAN demand |

**AC1 — does the demo fit 128 KB? No.**

```
characters (closure, one facing + runtime mirror)   8 blocks
animated scenery + foreground [P5.7 + P5.8]         1
the screen's tile page                              1
                                                   --
                                                   10  against 8 free
```

**P5.7's "6 blocks, one spare" was correct for the run it measured and is not the requirement.**
§2.2 predicted exactly this and it is confirmed.

#### 3B — AC5: variety, all fifteen levels, and §8's check

*Authority: the blueprints, all of which are present.*

| level | tileset | non-empty blocks | distinct (obj,state) | art |
|---|---|---|---|---|
| 0 | 00 | **210** | **20** | DUN |
| 1 | 00 | **616** | 32 | DUN |
| 5 | 01 | 520 | **51** | PAL |
| 11 | 01 | 461 | 31 | PAL |
| 7,8,9,12,13 | 02 | 328–580 | 21–40 | ★ **ABSENT** |

**Most varied: LEVEL5, 51 pairs. Most dense: LEVEL1, 616 blocks. LEVEL0 is the smallest on both
axes.**

> **★ §8's check, measured not assumed: bytes vs VARIETY r = +0.836, bytes vs DENSITY r = +0.675.
> Variety dominates, as P5.4 found.** Density is not irrelevant — LEVEL1 at 616 blocks / 32 pairs
> costs 39,783 B against LEVEL11 at 461/31 costing 28,281 — but it is the weaker term.

#### 3C — AC2/AC3: tiles, per level and per tileset

*Authority: `bake_screen.bake`, the opaque-rectangle model P5.5 proved buildable [§5.216].*

| level | set | variants | entries | bytes | blocks |
|---|---|---|---|---|---|
| 0 | DUN | 104 | 761 | 20,293 | 3 |
| 1 | DUN | 203 | 1,970 | 39,783 | 5 |
| 2 | DUN | 178 | 1,971 | 35,670 | 5 |
| 3 | DUN | 202 | 1,820 | 40,342 | 5 |
| 4 | PAL | 196 | 1,983 | 42,338 | 6 |
| **5** | PAL | **245** | 1,973 | **55,183** | **7** |
| 6 | PAL | 215 | 1,761 | 46,918 | 6 |
| 10 | PAL | 199 | 1,826 | 45,056 | 6 |
| 11 | PAL | 135 | 1,461 | 28,281 | 4 |
| 14 | PAL | 205 | 1,936 | 45,626 | 6 |

**Per-tileset dedup, within a tileset only [§5.236]:**

| set | levels | naive | deduped | saved |
|---|---|---|---|---|
| 00 | 0,1,2,3 | 136,088 | **67,345** | 68,743 (**50.5%**) |
| 01 | 4,5,6,10,11,14 | 263,402 | **93,333** | 170,069 (**64.6%**) |
| | **measured total** | 399,490 | **160,678 = 20 blocks** | |

★ **The saving grows with the number of levels sharing the set** — four levels save half, six save
nearly two thirds. That is the shape you would expect if contexts repeat, and it is the lever §1
said was uncounted.

**The absent third, bounded not measured.** Deduped rates are **648 B/pair** (set 00) and
**372 B/pair** (set 01), mean **510**. Tileset 02 carries **157 pairs** across five levels →
**≈80,022 B ≈ 10 blocks. An estimate.** ★ An earlier version of this scaled the *naive* rate onto a
*deduped* total — two quantities in one sum, the error §8 names — and it is corrected in the tool
with the reason recorded.

#### 3D — AC4: the two tile figures, which must not merge

| | bytes | blocks | |
|---|---|---|---|
| **largest single level (LEVEL5)** | **55,183** | **7** | **RESIDENCY**, extent = one level |
| **whole game (10 measured + 5 estimated)** | **240,700** | **30** | **a SUM**, extent = fifteen levels |

#### 3E — AC6/AC7: the cast

*Authority: P5.9's closure tooling, re-costed per character file.*

★ **A measurement error I made and corrected, because it produced a suspiciously perfect answer.**
My first pass reported *every* guard type at exactly 61,195 B. The guard types are alternative
**files** loaded into one table slot [`ch4trk hex 0d,03,04,05,0a,0b` — six sets, one slot], so they
share `(table, image)` keys; a set of those pairs cannot distinguish them, and costing every union
through CHTAB4.GD's table returns GD's answer five times. Re-costed through each type's own table:

| guard type | kid ∪ that guard | its CHTAB4-only part |
|---|---|---|
| GD | **61,195** (8 blocks) | 30 cels, 9,053 B |
| FAT | 61,146 | 9,004 B |
| SHAD | 60,439 | 8,297 B |
| SKEL | 59,781 | 7,639 B |
| VIZ | 61,093 | 8,951 B |

| | bytes | blocks | |
|---|---|---|---|
| **largest per-level cast** (kid ∪ one guard type) | **61,195** | **8** | **RESIDENCY**, one level |
| **whole-game cast** (shared 52,142 + all five CHTAB4 sets) | **95,086** | **12** | **a SUM** — ★ lower bound, a sixth set exists on disk and is not vendored |

> **★ AC7 — the shared part is 52,142 B, 85% of every level's cast.** The kid and the frames the
> guard reuses from him are the same cels on every level; only ~9 KB changes. **Per-level character
> loading would reload 85% of what it already has**, which is an argument against doing it at all —
> and it is why the whole-game cast (12 blocks) is barely above one level's (8).

#### 3F — AC8: the matrix

**Blocks, not bytes** [§5.225]. One facing and one phase throughout — the settled storage model
[§5.261], i.e. runtime mirror and runtime shift assumed.

| | **128 KB — 8 free** | **512 KB — 56 free** |
|---|---|---|
| **per-level loading**<br>(largest level resident) | chars 8 + tiles 7 + scenery 1 = **16** †<br>**OVER by 8** | **16 of 56** †<br>**FITS, 40 spare** |
| **all resident**<br>(whole-game totals) | chars 12 + tiles 30 + scenery ~2 = **44** †‡<br>**OVER by 36** | **44 of 56** †‡<br>**FITS, ~12 spare** |

† **Lower bound.** P5.7 measured that animated cels must be *duplicated into* each character block
that draws them — 7,074 B for a 36,142 B set across 5 blocks. That duplication is **not** included
in any cell, and it grows with the character figure.

‡ **Also a lower bound**, twice over: tileset 02's five levels are estimated (§3C), and the sixth
character set named by `ch4trk` is not vendored (§3E).

**The 56 free blocks, derived rather than taken:** 512 KB is 64 blocks. The HAL's map
[`gfx.s:405-417`] puts program and kernel at four (`$38-$3B`) and each framebuffer's span at four
(`$10-$13`, `$14-$17`), of which only two per buffer carry the 15,360 B picture. **64 − 12 mapped +
4 unused buffer tails = 56**, and the dispatch's figure agrees.

---

### 4 — AC9: the answer, in one paragraph

**The whole game fits 512 KB, and it fits at both granularities.** Per-level loading — the
conservative design — needs **16 of 56 free blocks**, leaving 40 spare, so it is not close. Holding
**everything resident at once** needs about **44 of 56**, which fits with roughly a dozen blocks of
margin; that margin is where the unmeasured duplication and the two absent asset sets have to come
from, so it should be treated as "fits, with work to do" rather than "fits comfortably". **128 KB
does not fit at any granularity: the largest single level alone needs 16 blocks against 8, and even
the demo needs 10.** ★ **So Jay's condition is satisfied — there is a way the gameplay levels fit,
and it is 512 KB.** The design does not have to be per-level loading to make the game work, though
per-level loading is what makes the margin comfortable rather than tight; and 128 KB is not back in
play, because the demo itself exceeds it once the fight closure rather than one observed run is the
requirement.

---

### 5 — Verification (AC-by-AC)

- **AC1** — §3A. The guardprog closure is 61,195 B = 8 blocks; **the demo does not fit 128 KB (10
  against 8)**. §2.2's warning that the run understates is confirmed.
- **AC2** — §3C, ten levels. **AC3** — §3C, within tilesets only, 50.5% and 64.6%.
- **AC4** — §3D: **largest level 7 blocks (residency)**, **whole game 30 blocks (sum)**, each
  labelled.
- **AC5** — §3B, all fifteen; LEVEL5 most varied, LEVEL1 most dense; **variety r=+0.836 vs density
  r=+0.675**.
- **AC6** — §3E: five guard types costed through their own tables; per-level 8 blocks, whole-game 12.
- **AC7** — §3E: **85% shared**.
- **AC8** — §3F, four cells, lower bounds marked †‡.
- **AC9** — §4.
- **AC10** — §0, 0 lines. **AC11** — §0, identical.
- **AC12** — **suites NOT run, and saying so.** Nothing was built: no source, link script, bake input
  or disk image changed, and `build.bat` was not invoked. The unchanged sha1 triple is the evidence.
- **AC13** — §6.

---

### 6 — Reactive deviations and route accounting

1. **★ One third of the tile art is absent and I did not work around it.** §3's census asks for all
   fifteen levels; ten are measurable. I measured variety for all fifteen, bytes for ten, and
   **estimated** the rest at the measured deduped rate with the label attached. The alternative —
   extracting tileset 02 from the oracle `.hdv` or dumping it from a running level — is a real route
   and out of scope here (§8).
2. **A measurement error caught by an implausible result** (§3E): five guard types costing
   identically. Corrected by costing each through its own table.
3. **An estimate error caught before it shipped** (§3C): a naive rate added to a deduped total.
   Corrected in the tool, with the reason in its header.
4. **★ I destroyed and rewrote `game_census.py` mid-task.** A patch script computed
   `s[a:b]` where `b < a`, producing an empty `old`, and `s.replace("", new)` inserted the
   replacement between every character — a 192,430-line file. **This is my second self-inflicted
   patch failure in two dispatches** (P5.11's was a backslash in a triple-quoted string). Both came
   from doing string surgery in throwaway Python instead of using the editing tools §2H points at.
   I have stopped; the file was rewritten with `create_file`.

**ROUTE ACCOUNTING.** No route proposed beforehand. Within the task the plan changed once: §2's
guardprog closure was to be computed from the blueprints, which turned out to record the *level's*
guardprogs rather than the *demo's*. Rather than report "programs 10 and 11 do not exist", I found
what they are (§3A) and established that the closure is insensitive to the row anyway — **so the
figure is exact rather than approximated, and the dispatch's premise is confirmed rather than
refuted.**

**Contains:** AC1-AC13, one new census tool, no build.
**Does not contain:** any decision. 512 KB is Jay's call and §4 exists to inform it.

---

### 7 — Uncertainty flags

1. **★ Five of fifteen levels are estimated, not measured** (§3C). If tileset 02 is richer than the
   mean rate, the whole-game tile figure rises; at set 00's rate rather than the mean it would be
   ~102,000 B instead of ~80,000, taking the all-resident cell from 44 to ~47 of 56. **Still fits.**
2. **★ Every matrix cell is a lower bound** (§3F †). P5.7's duplication-into-character-blocks is not
   included and is the single largest omission.
3. **The scenery figure is LEVEL0's** — 6,879 B, one block. LEVEL0 is the smallest level in the game
   (§3B), so richer levels carry more animated blocks and the true figure is higher. **Not measured
   for any other level.**
4. **A sixth character set exists on disk and is not vendored** (§3E), so the whole-game cast is a
   lower bound.
5. **The 85% sharing figure is over the five vendored guard types only.** The shadow, Jaffar and the
   cutscene cast (princess, vizier, mouse) are not in the closure — `chset` names six sets and
   `AUTO.S` carries 229 lines unreachable at level 0 [§5.196], neither of which this enumerates.
   **§4's "full cast" is therefore partly answered: the guard types are enumerated, the specials are
   not.**
6. **The demo's guardprog closure assumes probabilities do not gate reachability.** A `strikeprob`
   of 0 would make a move unreachable in practice; column 8 has `strikeprob 000`. **Rows 10 and 11
   are 040 and 060, both non-zero**, so the assumption holds for the demo — but it is an assumption.

---

### 8 — Follow-up candidates

1. **★ Get tileset 02's art** — dump it from a running oracle at level 7, the same technique
   `oracle_demo_bg.lua` uses. It closes flag 1 and completes the census.
2. **Measure the scenery figure per level** (flag 3), not just LEVEL0's.
3. **Fold P5.7's duplication into the matrix** (flag 2), so the cells stop being lower bounds.
4. **Enumerate the specials** — shadow, Jaffar, and the cutscene cast (flag 5).
5. **The 128 KB question is now closed by measurement**, so §5.235's A/B/C and the nine-block gap are
   both artefacts of a 128 KB target. **If Jay takes 512 KB they retire together.**

---

### 9 — User interaction during task

None.

---

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-22-identical-results-across-variants-mean-a-collapsed-key.md` — §3E: five
guard types costing byte-identically was a collapsed `(table, image)` key, not equality, and the
companion figures that *did* vary are what localised it. Pushed as `97ff84a`.

---

### 11 — Commit

Recorded in the push that carries this report to `origin/wip`. **`main` is untouched at `32b5fe2`.**
