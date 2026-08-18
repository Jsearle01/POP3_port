## Form B Report — P4.13 — the region is NOT free: 133,802 writes, from the blitter's save routine

**Class:** recon.  wip.  Prod unchanged — no `src/`, no `build.bat`, no shipping disk.
**HARD-STOP 2 fired at §1. §2 not started.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-18 11:30 (HEAD `9009d26`, wip).

### 1 — Summary

**`$6B91..$77FF` is not free.** A write tap over it across a full intro recorded **133,802 writes**,
touching **1,632 distinct addresses**, from **two writers — `$3A52` and `$3A60`, both inside
`blit_save` in `blit_core.o`.**

**★★★ MY ARITHMETIC SAID 3,183 BYTES FREE. THE MACHINE SAYS THE BLITTER OWNS IT.** P4.12 derived the
region from `intro_splash.bin`'s span and did not account for `flame_cels.bin`, which loads at
**`$3000..$488C`** and whose blitter saves background **above** it, into `$6C00` upward.

**The dispatch was right to demand this run, and right about why:** I had just been caught misreading
a map, and this was the same bet twice. It lost.

### 2 — Files added

- `harness/tools/region_write_probe.lua` — NEW. A write tap over an arbitrary range that **drives its
  own intro launch**, because MAME takes one autoboot script and a tap on a machine sitting at a BASIC
  prompt reports zero and proves nothing.

### 3 — Reasoning

#### 3A — what the run found (AC1)

```
# REGION WRITE PROBE — $6B91..$77FF (3183 bytes)
# posted LOADM at frame 300
# posted EXEC at frame 801 -- the intro runs from here
# frame 1200   writes so far: 0        <- clean through the early beats
# frame 4200   writes so far: 0
# frame 4800   writes so far: 612      <- first writes at frame 4724
# frame 6000   writes so far: 24278
# frame 7800   writes so far: 133802

# first: frame 4724  $6DE0 <- $00  from PC $3A60
# 1632 distinct addresses touched, 2 distinct writers
#   PC $3A52  x128168
#   PC $3A60  x5634
# ★★★ NOT CLEAN.
```

**★ THE REGION IS CLEAN FOR THE FIRST 4,700 FRAMES AND THEN IS NOT.** Had this been run over the
early beats only, it would have reported zero and I would have built on it. **The occupancy starts
when the cutscene starts.**

#### 3B — who owns it, from the symbol table (AC1)

| | |
|---|---|
| `$3A19` | `blit_save` |
| `$3A4E` | `bs_pair` — **`$3A52` is inside it: 128,168 writes** |
| `$3A60` | `bs_next` — 5,634 writes |

All in `build/obj/blit_core.o`, reached through `flame_cels.bin`:

```
flame_cels.bin (6295 B)   $3000..$488C   6285 B
```

**So the writes are the blitter SAVING BACKGROUND under sprites**, into a buffer that lives above the
flames bundle. `$6B91..$77FF` is that buffer's territory during the cutscene.

**★★ AND THIS IS EXACTLY THE MAP-TRUST PROBLEM THE DISPATCH NAMED.** `flame_cels.bin` occupies
`$3000..$488C`; nothing in the images says where its *runtime* buffers go. **A linked span is where
the code and its initialised data land, not where the program writes.**

#### 3C — why I am not relocating the buffer (HARD-STOP 2)

The dispatch is explicit: *"Relocating the buffer is a placement decision with the same map-trust
problem; do not solve it by picking another region off the same map."*

**That is right, and the run just demonstrated why.** Any candidate region I could name would be
named from the same images that just proved insufficient — and the failure mode is not "the region is
small", it is **"the map does not describe runtime writes at all"**. Finding the next home means
either instrumenting candidates the same way, or getting the answer from the code that allocates
those buffers rather than from a linker output.

**★ The instrument now exists and is cheap** — `P_LO`/`P_HI` and one run per candidate.

### 4 — Verification (AC-by-AC)

- **AC1 `$6B91..$77FF` observed across a full intro; findings reported** — **PASS as an observation,
  FAIL as a placement.** 133,802 writes, two named writers (§3A/§3B).
- **AC2-AC9** — **NOT DONE. HARD-STOP 2 fired**, which is the dispatch's instruction.
- **AC10 route accounting** — §6. Karateka and `main` untouched.

### 5 — Verdict-time evidence (v0.7 §11)

Verbatim in §3A. `flame_cels.bin $3000..$488C`; `blit_save $3A19`, `bs_pair $3A4E`, `bs_next $3A60`
in `build/obj/flames.map`.

**25.1:** N/A — nothing built. **25.2/25.3:** N/A — the gate was not reached.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING. This report contains §1 only** — the observation, the writers, and the conclusion
that the region cannot hold a song buffer. **It does NOT contain §2 in any part**, and the reason is
HARD-STOP 2 rather than anything else.

**Three defects of my own during the run, all in the instrument, none in the finding:**
1. I first launched `introseq_live.lua` with `P_OUT` set to my probe's log, so **the probe never ran
   and the old file looked like a result.** MAME takes one autoboot script.
2. The probe then needed its own launch, and I broke a Lua string literal across two lines twice
   while adding it — a syntax error that produced no log, which reads exactly like "no writes".
3. Both were caught only because **the log's first line is the probe's own banner**; a script that
   cannot start cannot lie about a zero.

### 7 — Uncertainty flags

- **This was one run, at 128 KB, over one intro.** The occupancy begins at frame 4724 and I did not
  establish whether it is the same on every pass, or whether a different route through the intro
  moves it.
- **I did not read `blit_save` to find where its buffer is DECLARED.** Knowing the writers is enough
  to stop; knowing the allocation is what would let someone choose the next home properly.
- **The 593 B "spare" from P4.12 is void**, not merely reduced.
- **P4.12's other claims stand unretracted but should be re-read in this light** — the `$0200..$6B90`
  span is measured and correct; the inference that what follows it is *free* was not.

### 8 — Follow-up candidates

- **Find where a song buffer can actually live** — from the code that allocates the blitter's buffers,
  not from a linker map, then confirm with `region_write_probe.lua`.
- Then §2 as written: wire six, cost in a hold, scenery decoupled, abort teardown asserted, PLAN
  assert permanent.
- Reconcile `pop.link`'s stale stack comment (P4.12 §7), still outstanding.
- Unchanged: the timbre ruling; capture-vs-interpret; `MUSIC.SET*`; `Demo` unbuilt.

### 9 — User interaction during task

None during execution.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-18-a-map-describes-placement-not-writes.md`

### 11 — Commit

`590a72a`  (pushed to origin/wip before this report)
