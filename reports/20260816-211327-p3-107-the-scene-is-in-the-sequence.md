## Form B Report — P3.107 — the scene is in the sequence

**Class:** build (integration). wip. **Prod CHANGED — deliberately:** the intro calls the scene,
the scene returns, and four restore items travel with it.

**★★★ GATED. Jay, live-disk, RGB, 128 KB, watching the whole sequence at real speed:
*"look good. mint it."* The intro runs splash → byline → title → prolog1 → THE VIZIER SCENE →
prolog2 → title reprise, and the scene is reached by a `jsr` between beats 4 and 5 exactly as
`MASTER.S` orders it.**

**★★ AND JAY CAUGHT TWO OF THE FOUR RESTORE ITEMS BY EYE, BOTH OF WHICH MY ENUMERATION HAD
EXPLICITLY DISMISSED — in writing, with a citation, wrongly both times.** §3C.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-16T21:13:27-04:00 (HEAD `b072265`, wip). Karateka untouched. `main` untouched. Oracle
read-only and not run. Pre-existing and not mine: `dist/mame-cfg/rgb/coco3.cfg`.

---

### 1 — Summary

| | |
|---|---|
| **★★★ 25.3 PASSED** | **Jay, live-disk, RGB, 128 KB: *"look good. mint it."*** |
| **★★ terminate** | `room_loop` exits on `cel_scene_done`, published by the terminal beat |
| **★★ return** | `room_call` at `$250B` keeps the caller's stack; both entries set S deliberately |
| **★★★ restore** | mode **and** palette **and** the splash cache — three of four found the hard way |
| **★ captions** | displaced and reloaded, the oracle's own `LoadStage2` model |
| **★★ asserts** | `beat_patch_check.py`, `kernel_identical_check.py`, and an `ifne`/`fail` on the call offset |
| **★★ measured** | read-before-reveal across the whole sequence — **no swap shares a frame with a draw-window read** |
| **★ new suite** | `integ` — the only one that boots what ships |
| **★★ found** | a **fifth stale checker**: `cel_rd_err` resolved against the wrong map for dispatches |
| **stated** | `SetupDHires`/`Prolog2` absent, not built |

### 2 — Files modified

- `src/engine/char_draw.s` — `cel_scene_done` published at `CEL_VARBASE+5`, cleared at init, set at the terminal beat
- `src/engine/cutscene_room.s` — `room_call`, `room_called`, `room_return`, the restore list, the offset assert
- `src/engine/intro_seq.s` — `run_scene`, `set_dhr_palette` extracted, `bank_valid` invalidation, the scene constants
- `harness/tools/beat_patch_check.py` — NEW; asserts the `$5400` condition
- `harness/smoke/integ_test.lua`, `run_integ_test.sh` — NEW; the integrated suite
- `harness/smoke/run_suites.sh` — `integ` added to the set
- `harness/smoke/introseq_test.lua` — the read count re-pointed and itemised (4 → 7)
- `harness/smoke/run_walk_test.sh` — `cel_rd_err` from `flames.map`, not `room.map`
- `build.bat` — `SCENE_BASE`/`SCENE_CALL_OFF`, the beat-patch assert
- `reports/20260816-211327-…md` — this

### 3 — Reasoning

**3A — TERMINATE, and the condition already existed as data.**

The last `cel_plan` row is `beat 18 Vstand, plays 0`, and `vb_bcnt` already recognised it —
`lda vm_bcnt / beq vb_done`, commented *"terminal beat: 0 plays, holds forever"*. **Nothing new
had to be detected; only published.** `cel_scene_done` at `CEL_VARBASE+5` is the channel, chosen
because `cel_res_block` at `+4` is the same pattern and because `$FE02-$FE1F` is constant RAM that
survives every MMU remap the schedule makes. `inca`/`sta` on a known zero rather than `inc`,
because the terminal beat runs forever and an `inc` wraps to 0 after 256 steps — a flag that
un-sets itself.

**The test sits at the TOP of `room_loop`, above the branch that separates its two arms.** Both
ended `bra room_loop`; a test on one would have returned only when the torch was due — a 1-in-3
chance per pass, presenting as an intermittent hang.

**3B — RETURN, and the stack was the trap §1.3 said it would be.**

`room_start` opens `lds #STACK_TOP`, and `STACK_TOP` is `$7F00` — **which is exactly where
`intro_seq.s` puts its own stack**. A `jsr` into `room_start` would reset S on top of the
caller's frames and push over them; the return address would be gone before the first subroutine
call. So `room_call` is a **separate entry** that keeps the caller's stack and records it
(`sts` runs after the `jsr` has pushed, so the saved S has the return address on top). It sits
**after** the probe block because every harness reads those bytes as offsets from `room_entry`.

The offset is asserted, not documented: `intro_seq.s` calls `SCENE_BASE+SCENE_CALL_OFF` and
cannot see the label, so `cutscene_room.s` carries `ifne room_call-room_entry-SCENE_CALL_OFF /
fail`. Verified by symbol from the freshly baked map: `room_call = 250B`.

**3C — ★★★ RESTORE, WHICH I ENUMERATED AND STILL GOT WRONG TWICE. THIS IS THE FINDING.**

§1.2 asked for the restore to be enumerated rather than discovered. I enumerated it. **Two of the
four items I listed as "does not need restoring", with a citation each, were wrong — and Jay
found both by eye before any check did.**

| item | what I wrote | what was true |
|---|---|---|
| **video mode** | *"the port has ONE mode … that is the HAL's OTHER mode, which the intro does not use"* | **The intro runs `GFX_MODE_320x192x16`.** Forty lines above my note, the same file says *"the intro's 16-colour is the newer one"* — **I read that sentence and wrote down its opposite.** 160 B/row against 80: different stride, so every row lands wrong. Jay: *"it looks like you are not properly switching back to DHRes after the vizier scene completes."* |
| **palette** | *"self-correcting WITH EVIDENCE: the intro re-installs the artwork's palette every time it loads a screen"* | **It installs it ONCE, at startup, inline.** `load_screen` never touches it. I cited the startup comment as though it described the per-screen path. Jay: *"you need to restore the DHRes palette."* Fixed by extracting `set_dhr_palette` to one home and calling it after the caption reload. |
| **the window** | *"NOT self-correcting … PUT BACK HERE"* | **Wrong in the other direction, and my fix was the defect.** I wrote `$3E/$3F` into `$FFA6/$FFA7` *after* `set_mode`, reasoning that *"set_mode owns `$FFA4/$FFA5`"*. It owns **all four** — the 16-colour buffer is 30,720 B, four blocks. `introseq` caught it exactly: *"12260 bytes differ; first at row 102 col 64"*, which is the top 40% of the screen. **The correct action was none.** |
| **the splash cache** | not listed at all | `BANK_BLOCK` is `$3C`, four blocks `$3C-$3F` — and the GIME masks to installed RAM, so at **128 KB those are `$0C-$0F`: exactly the scene's cel bank.** The scene overwrites the cached splash. `run_scene` clears `bank_valid`, so beat 6 re-reads it. ★ **512 KB would not have caught this** — there they are different physical blocks. §2K, working. |

★★★ **The pattern across all four is one thing: I reasoned from comments about the code instead of
from the registers and the constants.** Three of the four were decided by reading a sentence; the
fourth was not asked at all. CLAUDE.md §2 ranks comments **lowest**, and this is what that rank is
for. **The one item I got right — the stack — is the one I checked by grepping for `lds`.**

**3D — READ-BEFORE-REVEAL, MEASURED (AC6).**

`integ_test.lua` logs every `disk_read_range` and every `HAL_gfx_swap` in order with destinations,
and asserts the property rather than eyeballing it:

```
     4186     READ    $2500   trk 24  the scene's program
     4303     READ    $5800   trk 30  program space
     4416..4938  READ  $C000/$E000  trks 11-16, 20-21   the cel pages
     5022     READ    $5800   trk 29  the room blob
     ...the scene runs...
     7838     cel_scene_done set
     7841     READ    $3000   trk 25  captions
     8021     READ    $DA00   trk 18  DRAW WINDOW — back buffer
     8224     swap    $8000                     <- prolog2 revealed, 203 frames later
#      PASS — no swap shares a frame with a draw-window read anywhere in the run.
```

**The two reads integration added go to `$2500` and `$3000` — neither is a framebuffer**, and what
is on screen across them is the scene's own finished last frame. The one read that does build a
picture (prolog2 at `$DA00`) is revealed 203 frames later. **It has regressed twice; it did not
regress here, and that is a measurement.**

**3E — §2H's THREE CHECKS.**

1. **A second mechanism for a different object class?** Yes, three times: `room_loop`'s two arms
   (§3A); the palette's **two** call sites once extracted, where only one had existed; and the
   bank, which is a *fourth* consumer of GIME blocks alongside the two framebuffers and the cel
   bank — the one nobody had counted.
2. **The calling routine.** `bank_valid` is cleared in `run_scene`, not in `room_return`: the
   scene cannot invalidate a cache it does not own, and the palette's source (`BUNDLE_PAL`) is
   data the scene has just overwritten. **Both restores had to move to the caller.**
3. **Grep the reports.** P3.104 §3F reported the scene's entry state as *"largely self-
   established … palette, mode, MMU"*. That was pre-merge and it was optimistic in exactly the
   places §3C lists. Corrected here rather than left for citation.

**3F — ★★ A FIFTH STALE CHECKER, found by its own noise.**

`run_walk_test.sh` resolved `cel_rd_err` against `room.map`. **It is defined in `char_draw.s`,
which links into the disk-resident bundle — it has never been in `room.map`.** `sym` returned
empty, `P_RDERR` was the string `"0x"`, and the Lua's guard is `if RDERR ~= 0` — nil ≠ 0, so the
check **ran** and read whatever that resolved to. It printed 0 for dispatches, not because no
staged read failed but because the wrong byte happened to be zero, and printed **224** the moment
the bundle grew by a few bytes. Every other bundle symbol in that file already used `$FMAP`.

### 4 — Verification (AC-by-AC)

- **AC1 — `room_loop` terminates on a stated condition, on the existing decision path.** §3A.
- **AC2 — the restore enumerated and performed, each item established or self-correcting with
  evidence.** §3C. **Three of four were wrong on the first enumeration and are corrected in the
  file, with what was wrong left visible.**
- **AC3 — the return happens where S is a real stack, confirmed.** §3B. Top of `room_loop`, above
  every draw call; `blit_core` uses S as the blast destination, so an exit from inside the
  blitter could not `rts` at all.
- **AC4 — captions displaced and reloaded via the existing loader.** `run_scene`, tracks 25-26.
- **AC5 — `BEAT_PATCH = 0` asserted at build time.** `[beat-patch] OK — beat 4, beat 5 carry
  BEAT_PATCH 0 … (6 beats parsed)`. It reads the assembled source, not a copy of the table.
- **AC6 — read-before-reveal verified across the whole sequence, as a measurement.** §3D.
- **AC7 — the merge done; the scene's suites against the integrated build.** `integ` is new and
  green. ★ **Gap stated: `room` and `walk` still boot the standalone `ROOM.BIN`.** Their pixel
  checks are byte-exact and their launch is `LOADM"ROOM"`; re-pointing them at the integrated
  launch means waiting four beats into the intro, which is a suite rewrite rather than a
  re-point. **They are evidence about the standalone scene; `integ` is the evidence about the
  integrated one.** `introseq`'s read count was re-pointed (4 → 7) and itemised so it still says
  what each read is for.
- **AC8 — entry state confirmed post-merge.** The scene re-inits sys/MMU/mode/time itself; the
  room blob plus `HAL_gfx_mirror` paint **both** buffers before any character draw, so the first
  peel save cannot see the intro's leavings. Confirmed unchanged by `room`/`walk` passing against
  the rebuilt scene.
- **AC9 — suites green, 128 KB first; build verified by symbol.** §5.
- **AC10 — Jay gates LIVE, words verbatim, not self-certified.** §5.
- **AC11 — route accounting; sync bridge; Karateka; `main`.** §6.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim).**

```
[kernel-identical] OK — $7900 is byte-identical in both images (1092 B).
[beat-patch] OK — beat 4, beat 5 carry BEAT_PATCH 0, so no caption save is live across the scene call
build/assets/scene_prog.raw: 1191 B flat image based at $2500
build/assets/scene_prog.raw: 1191 B -> build/probe.dmk tracks 24..24
=== BUILD COMPLETE ===

[suites] -ramsize 128K
[suites] === introseq ===   [run_introseq_test] PASS
[suites] === room ===       [run_room_test] PASS
[suites] === walk ===       [run_walk_test] PASS
[suites] === integ ===      [integ] PASS
[suites] ALL PASS
```
`[hal-sync] OK -- HAL source aligned with karateka_coco3 (11 files compared…)`

Build verified by symbol from the freshly baked map: `room_entry = 2500`, `room_call = 250B`,
`room_called = 250E`, `room_return` present.

**25.2 bundled-artifact grep:** `scene_prog.raw` 1,191 B on track 24; all other placements
unchanged.

**25.3 operator-runtime-smoke: ★★★ PASSED — Jay, live-disk, RGB, 128 KB, the whole sequence
observed live at real speed (198 s at 100%).** Verbatim:

> **"look good. mint it."**

**What the gate covered:** the sequence AND the scene — the intro reaching it, the transition in,
the loads landing unseen, the return, the mode, the palette, and the two beats after it.
★ **`SetupDHires` and `Prolog2` proper remain ABSENT and were not built**, so this is not a gate
on a complete intro.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** Against §4's eleven criteria: **AC1–AC6 and AC8–AC11 in full; AC7 partial**
— `integ` covers the integrated build, `room`/`walk` still boot standalone and that is stated as
a gap rather than worked around.

**Reactive deviations (§22.5):**
1. **Three restore items were added after the enumeration**, not from it — §3C. Named as the
   dispatch's central failure rather than folded in silently.
2. `run_walk_test.sh`'s `cel_rd_err` map fix (§3F) — outside the dispatch, found because it
   started failing.
3. `introseq_test.lua`'s read count 4 → 7. **Itemised, not bumped**: a number raised until a
   suite goes green is not a check, and this one is the only thing standing between "the scene
   was called" and "the scene was silently skipped".

Oracle read-only and not run. Karateka untouched. `main` untouched. `hal-sync` OK.

### 7 — Uncertainty flags

- **★★ `room` and `walk` are standalone-only** (AC7). The integrated scene's PIXELS are gated by
  Jay's eye and by `integ`'s reach/return/read checks, **not** by a byte-exact comparison.
- **★ The `bne rs_out` before `set_dhr_palette`** skips the palette if the caption read reports
  failure. A read that fails but still lands would leave the wrong palette; on that path the
  captions are also garbage, so it is not the worst outcome — but it is a path with no test.
- **★ `$2500` is exercised now but its DECB-workspace safety is still not independently checked**
  (carried from P3.105). It works; nothing proves it is clear of anything DECB might do later.
- **★ The scene returns immediately on the terminal beat** — no hold. The hold comes for free from
  the caption + prolog2 reads that follow, which is why it does not read as a cut. If those reads
  ever get faster, the ending gets abrupt.
- Carried: the mirrored cels' chroma; the exit's +13% cause; P3.103's `mode`-cycling gap;
  `SetupDHires`/`Prolog2`; the scene is one page from a single load and no freeze.

### 8 — Follow-up candidates

1. **Re-point `room`/`walk` at the integrated launch**, or accept them as standalone-only and say
   so in `run_suites.sh` where the list lives.
2. `SetupDHires` and `Prolog2` — the next piece of the sequence.
3. Retire `ROOM.BIN` once nothing needs the standalone launch, so nothing tests a build that does
   not ship.

### 9 — User interaction during task

Three interventions, all Jay, all corrections that landed:

1. *"it looks like you are not properly switching back to DHRes after the vizier scene completes."*
2. *"the palette is still wrong."*
3. *"you control rebiulding not me so if its stal it needs to be rebuilt"* — I had asked him
   whether the disk he was testing included a fix I had not built. **The build is mine to run.**
   Saved to memory.

Then the gate: **"look good. mint it."**

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-16-what-a-component-borrows-is-not-what-its-comments-list.md`

### 11 — Commit

See below — pushed to origin/wip before this report.
