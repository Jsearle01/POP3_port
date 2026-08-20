## Form B Report — P4.25 — the cel pages moved into the opening batch; the cue is **+2.4 s**, not +12.4

**Class:** build.  wip.  Prod changed — `INTROSEQ.BIN` 2,268 → 2,362 B; `ROOM.BIN` unchanged at 2,301 B
(the bundle's guard is four instructions inside an existing routine). Karateka untouched; `main` untouched
(`34e93e0`); oracle source read-only.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-20 05:16 (HEAD `875870d` at receipt, wip; `f59e2b5` at report). Working tree clean apart from the
pre-existing untracked `docs/ground-truth/*.pdf`, `nvram/`, `.vscode/`, `POP-idioms-coco3-markers.md`,
`content/intro/broderbund_splash_render.bin` and the modified `dist/mame-cfg/rgb/coco3.cfg` carried since
P4.19. Explicit-path staging only.

### 1 — Summary

| | |
|---|---|
| **§1 the three hazards** | **all three resolved** — MMU save/restore verified by byte-diff, `cel_load_startup` split, link units stated (§3A-§3C) |
| **§1 the cel reads** | **★★★ MOVED.** Eight tracks now read in the opening batch, before the first beat, against black |
| **§2 the room blob** | **★★★ NOT MOVED — and the dispatch's premise for it is wrong. `$5800` is inside `SAVE_BUF`, and beat 3's TITLE patch save runs through it** (§3D). There is no other home. |
| **§3 the remaining gap** | **★★ +2.4 s, MEASURED** (was +12.4). Hard-stop 3's threshold is ~2 s, so: **the real number, for Jay's eye.** |
| **§4 the splash-cache cost** | **★★★ NOT ONE EXTRA READ — ZERO.** The bank had to go, and what replaced it costs no disk at all (§3E) |
| **§5 framebuffer intact** | **PASS — 0 of 32,256 bytes differ** across the borrow, new instrument |
| **suites** | **ALL PASS, 128 KB first; 512 KB confirms, no divergence** |
| **Jay's gate** | **OFFERED — by ear and eye, cutscene end to end.** Pending Jay. |

**★★★ THE ONE NUMBER: the cutscene's first cue was 12.4 s late and is now 2.4 s late.** Every later cue
inherited the offset and every later cue improved with it.

### 2 — Files modified

- `src/engine/intro_seq.s` — gains `cel_preload` (the eight raw reads + MMU save/restore) and
  `fb_copy_front`/`front_block`; **loses the splash bank** (`bank_copy`, `bank_valid`, `BANK_BLOCK` and
  `load_screen`'s two bank paths); includes `content/cutscene/chars/cel_pages.s`.
- `src/engine/char_draw.s` — `cel_load_startup` guards its reads on the pinned page's magic. State init
  unchanged.
- `harness/smoke/introseq_test.lua` — `disk_reads_completed` 8 → 16, itemised.
- `harness/tools/preload_fb_diff.lua` — **NEW.** The framebuffer across the MMU borrow, byte for byte.
- `mame-idioms-coco3-port.md` — **§22a NEW**: the MMU registers `$FFA0-$FFA7` are readable (§2A.3).

### 3 — Reasoning

#### 3A — §1a: the MMU borrow, and it is two bytes each way

**`cel_preload` saves `$FFA6`/`$FFA7`, maps the cel bank, reads, and puts them back.** Authority: **ground
truth for the readability, and the running machine for the result.**

> *"These registers can also be read to determine what palettes are set but **like the MMU registers, the
> upper 2 bits must be masked out**"* — [`docs/ground-truth/SockmasterGime.md:243`], with `$FFA0-$FFA7`
> listed as the Task-0 bank registers at line 188.

So the save is `lda $FFA6 / anda #$3F / sta cp_sav6`. **The mask is not needed for the write-back** — the
GIME ignores bits 6-7 — **but an unmasked byte is not a block number**, and it is stored in a variable
another reader could believe. Filed as idiom **§22a**, together with the asymmetry that matters: `$FF92`
needs VBORD armed (§20c) and the timer registers are write-only outright. *"GIME register" is not one
readability class.*

**★★ THE ORDER QUESTION THE DISPATCH RAISED DOES NOT ARISE, and the reason is worth stating rather than
assuming.** The dispatch expected the splash's `$DA00`/`$EC00`/`$FE00` reads to be interleaved with the cel
reads. **They are not in the opening batch at all** — the batch reads the caption bundle to `$3000` and the
music player to `$0A00`, both main RAM, and the splash is beat 1's, well after the borrow has been returned.
The preload therefore goes **last in the batch** for a different reason: a failure there should not have
wasted the two reads before it.

**HARD-STOP 2 — checked by byte-diff, not by looking.** `harness/tools/preload_fb_diff.lua` samples the whole
draw window `$8000..$FDFF` on two **write taps**, because a once-per-frame poll cannot sample "after the
preload returned and before beat 1 reads its picture" — those are microseconds apart inside one frame:

| sample | trigger | why it is exact |
|---|---|---|
| BEFORE | the write of **2 to `probe_loads`** | bundle and player are in; the preload has not issued a read |
| AFTER | the write of **2 to `probe_status`** | beat 1 starting; the preload has returned and restored, and `load_screen` has not written a byte |

**Between those two points the only thing that has run is `cel_preload`.** Result: **0 differing bytes of
32,256.** ★ *A wrong restore cannot produce zero — the cel pages are 30 KB of non-zero image data sitting
under exactly the half of the window that was borrowed.* (1,536 non-zero bytes appear in **both** samples:
that is `$F800..$FDFF`, the window above the 30,720-byte framebuffer, which `set_mode` does not clear.)

#### 3B — §1b: the split, and the guard is the payload rather than a flag

`cel_load_startup` did two things. **The reads moved; the state stayed.** `cel_rd_left`, `cel_rd_req`,
`cel_pg_sig`, `cel_scene_done` and `cel_res_block` live at `CEL_VARBASE $FE02` as **ordinary power-on RAM** —
the routine's own comment records that a garbage `cel_rd_req` once mapped a wild block and reset the machine —
and the scene needs them set when the scene starts, not ninety seconds earlier.

**The guard is `ldd CEL_MAGIC / cmpd #CEL_MAGIC_VAL / beq cs_first`** — four instructions, and **no new fact
enters the file**: `cel_walk_addr` already makes the same test with the same two constants.

**★ Why not a flag.** A flag is a second fact that two link units which deliberately cannot see each other's
symbols would both have to keep true — the shape this file already names as its `CHAR_TAB` mistake. The magic
is the fact, it cannot go stale, and it answers the question actually being asked: not *"did someone
preload?"* but *"are the pages here?"*

**★★ AND IT KEEPS `cel_load_startup` STANDING ALONE, which is dispatch §1b's guard requirement.** The reads
are not deleted. Remove the preload, or reach the scene without running the intro, and the magic is absent
and the eight reads happen exactly as they always did.

**★ ONE TEST COVERS ALL EIGHT TRACKS because `cel_preload` is all-or-nothing:** any failure returns Z clear,
`seq_start` stops on it, and the intro never leaves the batch. A half-loaded bank cannot reach the scene.

#### 3C — §1c: the three link units, and what actually changed in each

| unit | change | note |
|---|---|---|
| `intro_seq.s` (INTROSEQ.BIN, `$2000`) | `cel_preload` + the table include; bank removed | +94 B net |
| `char_draw.s` (the flame bundle, `$3000`) | 4 instructions of guard | ROOM.BIN unchanged; `flames` bundle grew 7 B |
| **the page table** | **NOT duplicated — INCLUDED** | see below |

**★★ THE TABLE IS THE ONE THING I WAS DETERMINED NOT TO COPY.** `content/cutscene/chars/cel_pages.s` is
generated by `bake_scene.py` from `cel_pack.json`, and `build.bat` places those very tracks. Both objects now
`include` it. **They never link together**, so the labels cannot collide, and **they cannot disagree about the
disk without the build being re-run.** What is duplicated is a loop; the fact has one home. (Precedent:
`CEL_VARBASE`, which build.bat's own note describes as exactly this arrangement.)

#### 3D — ★★★ §2: THE ROOM BLOB DOES NOT MOVE, AND THE DISPATCH'S PREMISE IS WRONG

**The dispatch:** *"`$5800` is free during the opening batch — the save buffer is not used until the first
character is drawn."*

**`SAVE_BUF` is the INTRO's caption save buffer, not the scene's character save.** `SAVE_BUF equ $5400`
[`intro_seq.s:187`], and `patch_blit` saves what each caption overwrites into it. **Beat 3 is the TITLE
caption, and it runs before the scene** (`SCENE_AFTER_BEAT equ 3`, i.e. after beat index 3 = beat 4).

**Measured by the project's own existing tool, not by me:**

```
  patch      first_row  rows  runs   SAVED B   SAVE_BUF end   verdict
  PRESENTS   103        45    45     747       $56EB          clear
  BYLINE     116        25    36     587       $564B          clear
  TITLE      102        87    229    5361      $68F1          ★ OVERRUNS $5800
```
[`harness/tools/intro_patch_extent.py`]

**A room blob preloaded to `$5800..$69FF` would be destroyed by beat 3.** ★ *P4.23 said the blob could not
move because it landed in the draw window and was wrong; P4.24 said it could move because `$5800` is main RAM
and was right about the address. Both stopped at the address. `$5800` is main RAM* **and** *it is spoken for.*

**AND THERE IS NO OTHER HOME.** The blob is one whole track, 4,608 B (`ROOM_TRACKS equ 1`). Main RAM during
the intro:

| region | size | state |
|---|---|---|
| `$0200..$09FF` | 2,048 B | DECB's dead buffers — free, **too small** |
| `$0A00..$1B97` | 4,504 B | the music player, live |
| `$1B98..$1FFF` | 1,128 B | free, too small |
| `$2000..$24E7` | | the intro program |
| `$2500..$2FFF` | | the scene's own program is read here |
| `$3000..$52FF` | 9,216 B | the caption bundle, live to beat 6 |
| `$5400..$68F1` | 5,361 B | **`SAVE_BUF`, worst case — the collision** |
| `$6A00..$6A06` | 7 B | `DR_VARBASE`, the disk parameter block |
| **`$6A07..$77FF`** | **3,577 B** | **free — the largest region, and 1,031 B short** |

**§6 AC3 is therefore NOT met, and the reason is measured rather than asserted.** ★ *Per §7.5 I am asking in
place rather than reverting anything: the cel move stands on its own and the blob is 1.4 s of the remaining
2.4.* **A variant exists and I did not implement it unasked** — see §8.

#### 3E — ★★★ §4: THE SPLASH-CACHE COST WAS INVERTED, AND THE REAL ONE IS ZERO

**The dispatch:** *"loading cel pages at start-up destroys the intro's splash cache in the same GIME blocks,
so beat 6's splash re-read is needed earlier. One extra track read. Already measured — accept it."*

**The dependency runs the other way, and it is fatal rather than costly.** The bank is filled at **beat 1**,
from `load_screen`, ~2 s into the intro — long before the scene. Preload the cel pages in the opening batch
and **beat 1's bank fill lands on top of them**: `BANK_BLOCK $3C` is four blocks `$3C-$3F`, the GIME masks a
block number to installed RAM [`gfx.s:406`], and at 128 KB those **are** `$0C-$0F`, the cel bank. `run_scene`'s
own comment already recorded the aliasing — in the other direction. P3.105 measured all four free blocks at
128 KB as the scene's, so **there is no second home: the bank and an early cel load are mutually exclusive on
the target machine.**

**So the bank had to go — and the question was what beat 1's second base then costs.**

| candidate | cost | verdict |
|---|---|---|
| re-read the splash from disk | **+2.6 s AFTER the reveal**, and every cue shifts | rejected — a new visible defect |
| `HAL_gfx_mirror` | — | **refuses**: it needs both buffers mapped at once and a 16-colour framebuffer takes the whole window [`gfx.s:595-604`] |
| **`fb_copy_front`** | **95 ms, no disk, no storage** | **taken** |

**`fb_copy_front` copies the FRONT buffer into the hidden one, one block at a time through the same `$FFA2`
window the bank used.** The swap has just put this beat's picture in the front buffer; the copy brings it
back. **The bank existed to avoid re-reading a picture the machine already had — in a buffer.**

**★★ IT IS ALSO MORE GENERAL THAN THE BANK WAS.** The bank only ever held `DISK_SCREEN_TRK`, so beat 4's and
beat 5's second base would have been re-read had they carried captions. This works for any beat. And
`run_scene`'s `clr bank_valid` is gone: nothing is stale, so nothing is cleared.

**★★★ AND THE SUITE PROVES THE REMOVAL WAS PAID FOR.** `probe_loads` is **16**, not 17: 8 before + the 8 cel
tracks. *If the bank's removal had cost a disk read, the count would say so.* The check now carries that
argument in its own text.

#### 3F — §2H's three checks (the conclusion rests on an oracle-side mechanism: the split cel image)

1. **A second mechanism for a different object class?** ★ **Yes, and it is already in the design.** The cel
   image is split into a **pinned** page (`$FFA6`, block `$0C`, the walk table + standing cels) and **rotating**
   pages (`$FFA7`). `cel_preload` had to serve both: one fixed block/track pair, and a table walk. It also
   does **not** touch the **fourth** page (`CEL_N_STARTUP 3` of `CEL_N_PAGES 4`) — page 3 arrives mid-scene
   inside a song hold, which is a *third* path and is deliberately untouched.
2. **The routine that CALLS it.** `cel_load_startup`'s caller is `room_load_cels`, which is a trampoline:
   `ldy #load_tracks / ldu #disk_read_motor_off / jsr [CELS_TAB]`. **That indirection is the whole blocker** —
   it is what put the loader inside the payload. Naming the implementation would have hidden it; P4.24 found
   it by reading the caller.
3. **Prior-report grep for this subsystem.** `grep -l "cel_load_startup\|CELS_TAB\|splash bank\|bank_valid"
   reports/*.md` → P3.78, P3.84, P3.105, P4.23, P4.24. **One contradiction found and resolved in this
   report:** P4.23 §3H tabulated the room blob as *"draw window `$FE00` — NO"* and P4.24 §3E as *"`$5800`,
   main RAM — YES, movable."* **Both were incomplete**; §3D settles it on a third fact neither consulted.

### 4 — Verification (AC-by-AC)

- **AC1 the three hazards resolved** — **PASS.** MMU save/restore verified by byte-diff, 0 of 32,256 (§3A);
  `cel_load_startup` split with a payload guard (§3B); link units stated (§3C).
- **AC2 the cel reads moved into the opening batch, before the first beat** — **★★★ PASS.** Eight reads,
  `probe_loads` 2 → 10 before `probe_status` is first written (§3A's tap frames), against a cleared screen.
- **AC3 the room blob read moved to `$5800`** — **★★★ NOT DONE, and the premise is refuted (§3D).** `$5800`
  is inside `SAVE_BUF` and beat 3's TITLE save runs `$5400..$68F1` through it; no 4,608 B main-RAM home
  survives beats 1-4 (largest free region 3,577 B). **Measured, with the project's own tool.**
- **AC4 the remaining gap MEASURED, not estimated** — **★★ PASS. +2.4 s** (§5). ★ *Hard-stop 3's threshold is
  ~2 s and this is 2.4, so the real number is reported and not smoothed.*
- **AC5 the cue-timing delta table re-reported** — **PASS** (§5, verbatim).
- **AC6 the splash-cache cost accepted, one extra track read** — **★★★ INVERTED, AND THE REAL COST IS ZERO
  READS** (§3E). The bank had to be removed outright, not re-ordered; `fb_copy_front` replaced it for 95 ms
  and no disk. `probe_loads` = 16 is the proof.
- **AC7 suites green 128 KB first, `integ` included** — **PASS.** `ALL PASS` at 128 KB; 512 KB confirms with
  **no divergence** — expected, since the design no longer depends on aliasing.
- **AC8 Jay gates by ear and eye, words verbatim** — **PENDING JAY.** Not self-certified (§5, 25.3).
- **AC9 route accounting present; Karateka untouched; `main` untouched** — **PASS** (§6). `main` at `34e93e0`.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output, verbatim.**

`build.bat`:
```
INTROSEQ.BIN                       2362             2 B
ROOM.BIN                           2301             2 B
[map_check] 5 map(s) clean — no overlap, nothing below $0E00.
=== BUILD COMPLETE ===
```

`harness/smoke/run_suites.sh` (**128 KB first, CLAUDE.md §2K**):
```
[suites] running: introseq integ
[suites] -ramsize 128K
[suites] === introseq ===
[run_introseq_test] PASS
[suites] === integ ===
[integ] PASS
[suites] ALL PASS
```
and the 512 KB confirmation, **no divergence**:
```
[suites] -ramsize 512K
[run_introseq_test] PASS
[integ] PASS
[suites] ALL PASS
```

**★★★ THE CUE-TIMING DELTA TABLE, re-reported — `harness/tools/cue_times.lua`, 128 KB, live-disk:**
```
# scene frames 5350..8204 = 47.6 s
# song           frame       port     oracle      delta
  s_Princess      5504       2.6s       0.2s      +2.4s
  s_Vizier        6381      17.2s      16.7s      +0.5s
  s_Buildup       6974      27.1s      26.3s      +0.8s
  s_Magic         7624      38.0s      34.9s      +3.1s
```

| song | P4.23 | **P4.25** | recovered |
|---|---|---|---|
| `s_Princess` | +12.4 s | **+2.4 s** | **10.0 s** |
| `s_Vizier` | +10.5 s | **+0.5 s** | 10.0 s |
| `s_Buildup` | +10.8 s | **+0.8 s** | 10.0 s |
| `s_Magic` | +13.1 s | **+3.1 s** | 10.0 s |
| `s_Squeek` / `s_StTimer` | never fires | **still never fires** | — |

★ *The two missing cues are unchanged and unrelated — P4.23 recorded the scene as four-sixths of the oracle's
cue list. The recovery is 10.0 s at every cue, which is the signature of one fault removed rather than four.*

**THE FRAMEBUFFER, ACROSS THE BORROW — `harness/tools/preload_fb_diff.lua`, 128 KB, live-disk:**
```
# the draw window across cel_preload's MMU borrow, byte for byte.
# window $8000..$FDFF (32256 B); the borrowed half is $C000 up.
# BEFORE  frame 1572  (write of 2 to probe_loads)
# AFTER   frame 2411  (write of 2 to probe_status)
  non-zero bytes BEFORE      1536
  non-zero bytes AFTER       1536
  bytes differing            0
    below $C000 (untouched)  0
    at/above $C000 (borrowed) 0
# VERDICT: PASS -- the framebuffer is byte-identical across the borrow.
```

**THE HEADROOM, from the map — ★ and it is the tight number now:**
```
prog 1255 B, ends $24E7, headroom to SCENE_BASE $2500: 25 B
```

**25.2 bundled-artifact grep:** N/A — no sibling-import artifact.

**25.3 operator-runtime-smoke: PENDING JAY — live-disk, RGB, `harness/smoke/run_introseq_live.sh`, by EAR
and EYE, cutscene end to end.** ★ *The question is now "is ~2.4 s tolerable" rather than "is 12.4 s
tolerable."* **The gate is motion- and audio-bearing and must be observed on a running machine** (CLAUDE.md
§4); a still cannot show it. **Not self-certified.**

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING. This commit contains:** the cel-page move into the opening batch with MMU save/restore
(§1a), the `cel_load_startup` split with an idempotent payload guard (§1b), the link-unit accounting (§1c),
the measured remaining gap and re-reported cue table (§3, §5), the byte-diff instrument, and the idioms-file
addition.

**It does NOT contain:** the room-blob move (**§2 / AC3**), for the measured reason in §3D. **Nothing was
substituted for it silently** and no alternative placement was implemented unasked — §8 offers one.

**★★ IT ALSO CONTAINS ONE THING THE DISPATCH DID NOT ASK FOR, AND THE CHANGE IS LOAD-BEARING: THE SPLASH BANK
IS DELETED.** §4 framed the bank as a cost to accept; it is a **blocker**, and the cel move does not work
with the bank present at 128 KB (§3E). I did not treat that as licence to redesign the intro: the replacement
is the smallest thing that keeps beat 1's second base free, it is measured, and `probe_loads` = 16 is the
check that it cost nothing. **Stated here because a diff shows what was done, never what was described.**

**★ AND TWO PREMISES IN THE DISPATCH WERE INACCURATE AND ARE NOT WORKED AROUND SILENTLY:** §2's *"`$5800` is
free during the opening batch"* (§3D) and §4's *"one extra track read — already measured, accept it"* (§3E).
Both are reported rather than quietly reinterpreted.

### 7 — Uncertainty flags

- **★★★ HEADROOM TO `SCENE_BASE` IS 25 BYTES** (was 119). `intro_seq.s`'s prog ends `$24E7` and the scene's
  program is read to `$2500`. **The next addition to the intro sequencer will not fit**, and `map_overlap_check`
  is what would catch it — it passes now. This is a real constraint on the next dispatch, not a note.
- **★★ THE `LOADM` CEILING IS UNMEASURED IN THE BAND THIS IMAGE NOW OCCUPIES.** `link/pop_engine.link`
  records *"prog ending `$2487` boots; `$2535` image corrupted"*. This build ends `$24E7` — **between the two
  samples.** It boots, LOADMs (`loadm_from_disk PASS 2362 B, 2 segments`) and both suites pass at both RAM
  sizes, so the empirical answer is fine; the **ceiling itself is still not pinned**, and it is what turns a
  25-byte headroom into a hard stop earlier than `$2500` would suggest.
- **The 2.4 s is composition, not one item.** It is the flame bundle read + expand and the room blob read +
  unpack. Only the blob half (~1.4 s) is movable in principle, and §3D says not to `$5800`.
- `s_Squeek` and `s_StTimer` still never fire — **pre-existing and out of scope**, carried from P4.23.

### 8 — Follow-up candidates

- **★★ THE ROOM BLOB, WITH A PLACEMENT THAT ACTUALLY EXISTS — Jay's call, because the cost is visible.**
  `SAVE_BUF` is dead the instant beat 3's caption repair finishes, and beats 4 and 5 carry no patch
  (`beat_patch_check.py` asserts it). So the blob **can** be read to `$5800` at the top of beat 4, where
  beat 4's own 2.6 s picture read already stalls against the title screen. That trades **1.4 s off the
  cutscene** for **1.4 s onto an existing pause**, moving the cost rather than removing it. ★ *I did not
  implement it: which of those two seconds matters is an eye-and-ear judgment, not a measurement.*
- **The 25-byte headroom.** The intro sequencer is out of room at `$2000..$24FF`. Options exist (the scene's
  program does not have to be read to `$2500`; `link/pop_scene.link` is where that lives) and none of them is
  this dispatch.
- **Pin the `LOADM` ceiling.** It has bounded two dispatches now from a two-sample bracket.

### 9 — User interaction during task

None. The dispatch was executed as written except where §6 records otherwise.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-20-the-loader-inside-the-payload-is-a-circular-dependency-not-an-ordering.md`
— committed and pushed to the pool (fire-and-forget, succeeded).

### 11 — Commit

`f59e2b5` (pushed to origin/wip before this report).
