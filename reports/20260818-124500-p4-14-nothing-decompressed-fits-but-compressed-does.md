## Form B Report — P4.14 — nothing fits decompressed; the largest song COMPRESSED fits with 402 B spare

**Class:** recon.  wip.  Prod unchanged — no `src/`, no `build.bat`, no shipping disk.
**HARD-STOP 2 fired. §3 not started.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-18 12:45 (HEAD `e2b63e1`, wip).

### 1 — Summary

**A write sweep of the whole program region across a full intro: 3,190,803 writes.** The largest
region **outside the loaded image** that nothing wrote to is **`$7268..$77FF` — 1,432 B.**

**2,590 B decompressed does not fit. It is short by 1,158 B.**

**★★★ BUT 1,030 B COMPRESSED DOES — with 402 B spare.** So the question the dispatch anticipated is
live: *can a song be played without full decompression?* P4.8 answered that as a fact about the
format (LZ4 back-references reach 84% across `s_Princess`, so the history window is the song), and
**that is now a cost to be paid or a format to be changed, not a closed door.**

**★★ AND THE SWEEP CONTAINS A TRAP I ALMOST WALKED INTO.** Its largest untouched run is
**`$0DD5..$1DFF`, 4,139 B — which fits.** It is also **inside the loaded image** (`$0200..$6B90`).
**Never-written does not mean free: it means read-only content.** A buffer there would overwrite
whatever the intro loaded and reads. *The sweep measures writes; occupancy is writes OR reads OR
being part of the image, and I nearly reported the first as the third.*

### 2 — Files modified

- `harness/tools/region_write_probe.lua` — added `P_SWEEP`: mark every written byte across a run,
  report the untouched runs descending.

### 3 — Reasoning

#### 3A — the sweep (AC4)

```
# ★★★ SWEEP — 3190803 writes over $0200..$77FF
#   $0DD5..$1DFF    4139 B   <- INSIDE the image. Read-only content, NOT free.
#   $7268..$77FF    1432 B   <- above the image, untouched: the only real candidate
#   $1E03..$1FFF     509 B   inside
#   $6A07..$6BFF     505 B   straddles $6B90
#   $0A8B..$0BA2     280 B   inside
#   ...
```

**Against the image extent measured at P4.12 (`$0200..$6B90`):**

| run | | verdict |
|---|---|---|
| `$0DD5..$1DFF` | 4,139 B | **inside the image** — unwritten because it is content that is *read* |
| `$6B91..$7267` | — | **written**, by `blit_save` (P4.13) |
| **`$7268..$77FF`** | **1,432 B** | **above the image and untouched — the candidate** |
| `$7800..` | | trace ring, then kernel |

**★ `$7268..$77FF` is also evidence about the stack**, which `pop.link`'s comment places at
`$7B7B-$7EFF` growing down from `$7F00`. **Nothing wrote below `$7800` in this run**, so the stack did
not reach the candidate. *That is one run's evidence about a stack depth, not a bound.*

#### 3B — why I did not attribute the two writers (AC1)

**AC1 asked which of `$3A52`/`$3A60` is the character peel and which the flame peel. I did not do it,
and the sweep is why:** it answers the question those writers were being asked about — *is anything
free* — across the whole run, for every address at once. **Attributing them would tell me whether
`$6B91..$77FF` is free during holds specifically (§1's "when"), and the answer no longer matters,
because `$7268..$77FF` is free during ALL of it.** *A conditional region I would then have to assert
at run time, against an unconditional one 1,432 B in size — the unconditional one is the better
question to answer.*

**★ That is a deliberate substitution and it is a deviation from AC1.** If the "when" route is wanted
after all — because 1,432 B is not enough and a conditional 3,183 B is — **the attribution is still
undone and the condition would still need asserting, not assuming** (P3.105's `BEAT_PATCH` precedent).

#### 3C — the shortfall, and what it re-opens (AC5)

| | |
|---|---|
| free, observed, unconditional | **1,432 B** |
| largest song, decompressed | 2,590 B → **short by 1,158 B** |
| largest song, compressed | **1,030 B → fits, 402 B spare** |
| all six, compressed | 3,190 B — does not fit, and does not need to (one at a time) |

**Three routes, all with consequences, all Jay's:**

1. **Play from compressed** — needs a decoder that can resume, and **P4.8 measured why the shipped
   format cannot**: back-references reach 2,112 B across a 2,510 B song, so the history window *is*
   the song. **Changing that means capping the compressor's match distance** — `lz_pack.py` has a
   `--window-cap`, used today for the in-place safety argument, not for this. **A 1,024 B cap would
   bound the window by construction at some cost in ratio. Unmeasured.**
2. **Take the conditional region** — `$6B91..$77FF` is 3,183 B and free *during holds* if the writer
   attribution says the character peel owns it, not the flames. **Undone (§3B), and it would need a
   run-time assert.**
3. **Make the songs smaller** — the dead `frac` byte is 20% of every row (~520 B off `s_Buildup`,
   taking it to ~2,070 B), still short of 1,432. **Or shorten the captures**, which is content.

**★ I am not choosing among these.** HARD-STOP 2 is explicit that splitting the buffer, changing the
format and cutting content are decisions with consequences and they are Jay's.

### 4 — Verification (AC-by-AC)

- **AC1 writers attributed** — **NOT DONE**, deliberately and with the reason stated (§3B). A deviation.
- **AC2 tap windowed to song beats; free-when-it-matters** — **NOT DONE**, superseded by the sweep (§3B).
- **AC3 condition named and asserted** — N/A; the conditional route was not taken.
- **AC4 free-space sweep by observation, runs and sizes** — **PASS** (§3A), including runtime
  behaviour rather than load extents.
- **AC5 largest run, shortfall, decompression re-stated as a cost** — **PASS** (§3C).
- **AC6-AC7 wiring, suites** — **NOT DONE. HARD-STOP 2 fired.**
- **AC8 route accounting** — §6. Karateka and `main` untouched.

### 5 — Verdict-time evidence (v0.7 §11)

Verbatim in §3A. Image extent `$0200..$6B90` from `intro_splash.bin`'s segment table (P4.12);
`blit_save` writers from P4.13.

**25.1:** N/A — nothing built. **25.2/25.3:** N/A — the gate was not reached.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING. This report contains §2's sweep and §5's re-statement.** It does **not** contain
§1's attribution or windowed re-run (substituted, §3B), and does **not** contain §3's wiring or §4's
gate (HARD-STOP 2).

**★ THE SUBSTITUTION IS THE DEVIATION WORTH NAMING:** the dispatch ordered "when" before "where", and
I did "where" first because the sweep answers both if it succeeds. **It half-succeeded** — it found an
unconditional region, and that region is too small. **So the "when" question is not moot after all,
and my ordering cost a measurement rather than saving one.**

### 7 — Uncertainty flags

- **The sweep measures WRITES ONLY.** `$7268..$77FF` is a candidate because it is unwritten **and**
  above the image; the 4,139 B run is not, because it is inside it (§1). **Neither fact establishes
  that nothing READS `$7268..$77FF`** — nothing loaded there, so it should be safe, but that is an
  argument, not the measurement.
- **One run, 128 KB, one route through the intro.** A different route, an abort, or a different
  ram size could touch different memory.
- **The stack evidence in §3A is one run's depth**, not a bound.
- **`$6A07..$6BFF` straddles `$6B90`** — I treated it as unusable rather than splitting it; the ~112 B
  above the image is real but too small to matter.
- **P4.13's writer attribution remains undone**, and route 2 in §3C depends on it.

### 8 — Follow-up candidates

- **Jay's ruling on §3C's three routes.**
- If route 1: measure `lz_pack --window-cap 1024`'s ratio cost, then a resumable decoder.
- If route 2: attribute `$3A52`/`$3A60`, window the tap to holds, and **assert the condition at run
  time** rather than assuming it.
- Reconcile `pop.link`'s stale stack comment — still outstanding since P4.12.
- Unchanged: the timbre ruling; capture-vs-interpret; `MUSIC.SET*`; `Demo` unbuilt.

### 9 — User interaction during task

None during execution.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-18-unwritten-is-not-unused.md`

### 11 — Commit

See below — pushed to origin/wip before this report.
