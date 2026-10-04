## Form B Report — P5.28 — the first character on a gameplay screen: the kid ×3 on LEVEL0 screen 1, predicted offline and matched 15,360/15,360

**Class:** build. `wip`. **Prod byte-identical, and so are `probe.dmk` and `tile_probe.bin`** (§0, §6.1).
**Status: AT THE GATE.** 25.3 pending Jay.

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-10-04T15:32:30-04:00 (HEAD **`101a2b7`**, wip, as the dispatch was drafted; `main`
**`32b5fe2`**). Tracked tree clean.

**AC1 — receipt vs a full rebuild at the end:**
```
08bcae4a6249828a64554c61db9ed7ace72e4081  intro_seq.bin      IDENTICAL
10bddbd5413d14b1fbf26aeadb874515fc32b3e8  loader.bin         IDENTICAL
d5b17b6d468f1bcdd66163a60d9ffa1e36197e15  cutscene_room.bin  IDENTICAL
92dc6d96778c71056ca37524779a5bcd1d61643c  flame_cels.bin     IDENTICAL
6c8d6e980c53eaa24d83eb383923f5a0568e4256  probe.dmk          IDENTICAL   <- dispatch expected a change
b7751d2f1aabc9bbfb86b8ee29b9996174c89140  tile_probe.bin     IDENTICAL   <- dispatch expected a change
```
**AC11 — `main` = `32b5fe2` at both ends.**

---

### 1 — Summary

**A Prince of Persia character is on a Prince of Persia dungeon screen**, drawn from the P5.27 bake
through the P5.20 transform. The picture is LEVEL0 screen 1 with the kid's standing cel (CHTAB1 #15,
frame 15) drawn three times on the top floor:
- **identity:** phase 0, facing 0, through the shipped `blit_cel_full`;
- **shifted:** phase 1, the ascending table path;
- **mirrored:** the descending table path with the blue/orange swap. With d = −2 it draws at phase 2,
  which is the joint mirror+shift case.

**The framebuffer was predicted offline before the program ran, and the capture matches it 15,360 of
15,360**, at 512 KB and again at 128 KB. Off the real disk path: `LOADM"CHAR"` + `EXEC`. **Per draw**,
each frame changes 90–93 bytes of the picture and matches exactly. **A wrong draw would have been
caught:** the swap omitted (25 B), the pad omitted (103 B), phase 0 drawn in place of phase 1 (83 B).

**Plane ordering is still untested** (§3B). The three kids stand where LEVEL0 screen 1 has no
foreground rectangle and where the omitted gate bars cannot reach, so the picture does not depend on
plane ordering. That is all it shows about plane ordering.

---

### 2 — Files modified

**New:**
- `src/engine/xf_blit.s` — **the transform's new and only home** (§3D), moved out of the harness.
- `src/engine/char_probe.s` — the glue. It walks the draw list, reads `apple_w` from the registry,
  does the placement arithmetic, and calls `xf_blit`.
- `link/pop_charprobe.link` — the character probe's map (§3C).
- `content/chars/probe_place.json` — the **placement table**, §2F's one home for where the probe
  draws.
- `harness/tools/xf_tables.py` — the tables as a linkable section. It refuses to emit unless its bytes
  equal the probe's.
- `harness/tools/char_probe_plan.py` — reads the placement table, checks clearance, emits the 6809
  draw list and **the predicted framebuffer**.
- `harness/tools/fore_plane.py` — a screen's foreground plane as framebuffer rectangles.
- `harness/tools/char_probe_regions.py` — the per-draw breakdown and the controls.
- `harness/smoke/run_char_test.sh` (headless, byte verdict) and `harness/smoke/run_char_live.sh` (the
  gate).

**Modified:**
- `src/harness/xform_probe.s` — now `include`s `src/engine/xf_blit.s`; its binary is
  **byte-identical** (§3D).
- `src/engine/tile_probe.s` — two `ifdef CHAR_PROBE` blocks (an import, and one `jsr` after
  `tile_draw`). **Its own build is byte-identical** (`tile_probe.bin` sha1 above).
- `harness/smoke/tile_test.lua`, `harness/smoke/tile_live.lua` — `P_FILE` / `P_MARK` / `P_EXEC_WAIT`.
  Their defaults are the tile gate's previous literals, so the tile suite runs exactly as before (it
  PASSes, §5).
- `build.bat` — the P5.28 block, after the `probe.dmk` read-back. It builds the probe and
  `build/char_gate.dmk`, then checks the map and reads the disk back.
- This report.

---

### 3 — Reasoning

#### 3A — Phase 1, the prerequisites, in the dispatch's order (AC2, AC3)

1. **`apple_w` — read, not re-derived (AC2).** It is read at run time on the 6809:
   `lda [2,u]`, through the address of `chtab1_aw+14` in the **committed** `char_cels.s`, which the
   probe links. `char_probe_plan.py` reads the same file through the same parser that P5.27's `--baked`
   probe used, and takes `h` and `w0` from the committed stream's own header. `build/chars/bake.json`
   is not consulted.
2. **Tables: composed, 5,376 B.** The dispatch's default was the small form; my reason for not taking
   it: **the uncomposed routine does not exist.** P5.20's "2,304 B at about +5 cy/byte" is an estimate
   for code nobody has written. The composed routine is the one measured byte-exact on 6,688 cases, and
   building the other would make this the first draw of an unverified routine. **The bytes are
   affordable**, because the LOADM ceiling does not bind (Jay, §3C), and the tables occupy
   `$4200–$56FF` of a map that has nothing else there. If a later link is tight, the uncomposed routine
   is a separate dispatch with its own probe.
3. **Direct page: the routine owns page `$57`.** It uses fourteen bytes, `$5700–$570D`. The cost in
   this link is **a 256 B page reserved for 14 bytes of variables**, because `prog` starts at `$5800`.
   The other 242 bytes are idle, and nothing else is placed there. The alternative, extended
   addressing at about +1 cy and +1 B per access, would have changed the measured routine.
   (The dispatch said ten bytes; the routine's variables are 14.)
4. **No clip path, and none built.** All three frames are placed clear of the screen edges, and the
   plan tool checks that rather than asserting it: rows 15..55, bytes 34..47 of 0..79. The mirrored
   frame is checked at the routine's own columns, which are d px left of the reference's and one byte
   wider at a non-zero phase.
5. **Code in RAM: holds.** `xf_blit` patches its own `andb >XF_M` operands; it is linked at
   `$5C90–$6084`, in main RAM, loaded by LOADM. Nothing in this link is in ROM.

#### 3B — §2: the option taken, and the foreground of LEVEL0 screen 1 (AC4, AC7)

**I took option (1): place the character clear of the foreground and state that plane ordering is
untested.** The foreground comes from `bg_compose`'s own lists (`fore_plane.py`, using
`Renderer.sure` → `.fg`). Every entry is converted to framebuffer rows and bytes: Apple bytes + 20 px
margin, rows 1:1, the same mapping as `hgr_screen_convert`.

| foreground entry | rows | fb bytes | what it is |
|---|---|---|---|
| `$45` (STA) | 3..61 | 69..74 | the pillar front, block column 9 of the top row |
| `$83` ×8 | 66..125 | 5..18, 33..74 | block fronts, middle row (all but the shaft at block columns 2–3) |
| `$83` ×7 | 129..188 | 5..18, 40..74 | block fronts, bottom row (all but block columns 2–4) |
| **gate bars, OMITTED by `bg_compose`** | (0..62) | (5..11) | `drawfrnt` with `PRECED = gate` at block column 0 of the top row. The gate is on the screen to the left; its bars need the kid's position, so the tool cannot draw them. Claimed here as the whole block. |

**Screen 1's open space is the top row.** It is a corridor on floor y = 62, with three torches, a
raise plate and a pillar; the middle and bottom rows are solid wall apart from a shaft and spikes.
Therefore the kid stands on the top floor:
- **His height comes from the oracle's own rule.** FRAMEDEF.S:37 gives frame 15 = CHTAB1 #15, Fdx 0,
  Fdy 0. `CharY` = FloorY[block row 0] = 191 − 126 − 10 = **55** [TABLES.S:179-185], and the cel's
  bottom row is `CharY + Fdy` = 55 [CTRLSUBS.S:823-828].
- **His columns: block columns 4–5** (bytes 34..47), with floor underfoot. That is clear of the pillar
  (69..74), the gate claim (5..11) and the torches.

The plan tool **checks every frame against every rectangle and fails the build on any overlap**:
```
identity  IMG.CHTAB1 #15  rows 15..55  ref bytes 34..36  routine bytes 34..36 (phase drawn 0)  CLEAR
shifted   IMG.CHTAB1 #15  rows 15..55  ref bytes 39..42  routine bytes 39..42 (phase drawn 1)  CLEAR
mirrored  IMG.CHTAB1 #15  rows 15..55  ref bytes 44..46  routine bytes 44..47 (phase drawn 2)  CLEAR
```
**AC7: plane ordering remains UNTESTED.** The page is still one flattened opaque pass, and the
characters are drawn after the whole of it (the `jsr` follows `tile_draw`). That is exactly the
undifferentiated order `tile_probe.s`'s header warns about. The picture is correct only because no
foreground rectangle overlaps a kid. **A character walking under the pillar front or past the gate
would show it.**

**§2H's checks, on the foreground mechanism:**
- *Second mechanism:* yes. The gate bars are a foreground element that the bake cannot represent at
  all, because they are state-dependent and not in `.fg`. They were found only because `bg_compose`
  records its omissions, and they are in the clearance check.
- *Calling routine:* `DRAWALL` → the foreground list after the characters [GRAFIX.S:484]; `drawfrnt`
  is reached from `RedBlockSure` per block.
- *Prior reports:* P5.5 §3D/§3E (the warning, the omissions, the flame and meter regions) and P5.0 §3B.
  No contradiction.

#### 3C — The memory map, and Jay's ruling on LOADM (§9)

**The probe's `prog` is 3,075 B** (tile renderer 241, glue 927, `xf_blit` 1,013, `blit_core` 752,
`lz_unpack` 142). **That is past the LOADM ceiling** (`$2488..$2535`, `link/pop_engine.link`) at
`$2000`. I raised that, and Jay ruled: *"since we are using a loader to start the program, after that
loadm areas arent important since we only use loadm to boot."* **So it is placed above the staging
area instead:**
- `prog` at `$5800`, and the tables at `$4200`;
- a LOADM of 6,912 B at `$4000` was measured to load (idioms §23);
- `map_overlap_check` passes on the new map.

**It is not on `probe.dmk`.** That image has 0 bytes free, and the dispatch's class line keeps it
unchanged. `build.bat` copies the **finished** `probe.dmk` (track 34 holds the packed tile page as
always), deletes `INTRO.BIN` from the copy, and puts `CHAR.BIN` (9,576 B) on it as
`build/char_gate.dmk`. The read-back check confirms `CHAR.BIN` and `TILE.BIN` on that image byte for
byte.

#### 3D — AC6: the routine's new home — MOVED, with the harness including it

**`xf_blit` now lives in `src/engine/xf_blit.s`, and `src/harness/xform_probe.s` `include`s it.** The
probe has always included engine files this way (`blit_core.s`, `lz_unpack.s`). The argument:
- **A copy would be a second home for the one fact this project has proven most about.** The routine
  whose correctness rests on 6,688 measured cases would then exist in two texts, and only one of them
  would be measured.
- **A harness file in a shipping link is backwards.** The engine depends on the engine; the harness
  measures the engine.
- **So the measured text and the linked text are the same file.** I proved the move changed nothing:
  probe batches `k000`, `k050`, `k105` (gameplay), `g000` (guard sets) and `s000` (the shipped cutscene
  cross-check) assemble **byte-identical** before and after.

The file takes its layout from equates (`XF_DPPAGE`, `XF_M`, `XF_T1`, `XF_T2`, `XF_TABS`) and has no
defaults, so a wrong table address fails to assemble rather than drawing plausible garbage. Under
`OBJTARGET` it is section `prog`, `export xf_blit`, `import blit_cel_full`. `SETDP` is kept only for the
absolute build, because lwasm refuses it in an object target and every direct-page operand is already
forced with `<`.

#### 3E — AC5: predicted, then captured, then compared

**The prediction** (`char_probe_plan.py`, written before the first run):
- The starting point is the tile bake's own reference framebuffer, the one the tile suite holds the
  port to.
- Each draw's **reference** stream is replayed on top of it by `cel_blit_prep.simulate`, in P5.20's
  sense of reference: the baked pixel file at phase k for facing 0; `sprite_convert --mirror`
  (`--flip-parity` because `7·apple_w` = 14 is even) at phase k for facing 1, at byte column `col`.

So the port is asked the same question the probe answered 6,688 times, now over a real background at a
real position. **The 6809 does the registration itself** (`p = 4·col + k + 7·apple_w − 4·w0`), so the
prediction checks that arithmetic too.

```
FB COMPARE — port vs PREDICTED (tile reference + three reference draws)
  15360/15360 identical, 0 differ  (100.00%)  -> EXACT          [512 KB, and again at 128 KB]

per draw: bytes over the draw's frame | prediction changes vs bare tile | port vs prediction
  identity  rows 15..55 bytes 34..36   123 B  changed  93  port-vs-predicted 0
  shifted   rows 15..55 bytes 39..42   164 B  changed  90  port-vs-predicted 0
  mirrored  rows 15..55 bytes 44..47   164 B  changed  92  port-vs-predicted 0
  outside every frame: 14909 B, port vs bare tile reference differ: 0

controls (a WRONG prediction, compared with the same capture -- each must disagree):
  shifted   phase-0: 83 of its bytes would differ
  mirrored  no-swap: 25 of its bytes would differ
  mirrored  no-pad:  103 of its bytes would differ
```

**On the three-silhouette-pixel mirror error (§5.259):** it does not appear here, and it could not. That
error is a difference between **two bake paths** (colour model before vs after mirroring), which P5.11
measured against the oracle. The prediction here is the bake's own mirror path, which the runtime
mirror reproduces exactly (P5.20 §3C). **So a byte-exact mirrored draw says the runtime mirror equals
the bake's mirror. It says nothing about whether either matches the oracle's mirrored kid.** No oracle
capture of a mirrored gameplay kid was compared. If Jay sees a silhouette difference at gameplay
scale, that is the known one, and this comparison could not catch it.

---

### 4 — Verification (AC-by-AC)

- **AC1** — §0: prod identical. `tile_probe.bin` and `probe.dmk` are **also** identical, because the
  probe is a second build of the same source and goes on its own disk (§6.1).
- **AC2** — §3A.1: read at run time from `char_cels.s`.
- **AC3** — §3A.2–3: composed tables, 5,376 B, with the reason; DP page `$57`, 14 B used, 242 B idle.
- **AC4** — §3B: the foreground named and located, the omitted gate bars included; the clearance
  checked by tool, edges included.
- **AC5** — §3E: **predicted, captured, 15,360/15,360**; per draw 0 differing bytes; three controls.
- **AC6** — §3D: moved; the probe includes it; the probe binary is byte-identical.
- **AC7** — §3B: untested, with the reason.
- **AC8** — `run_char_live.sh`: live-disk, RGB, `SRC_DSK` override, `$MAME_RAM` (512 KB by default).
  The headless runner proved the same disk path at 512 KB and 128 KB.
- **AC9** — §5, 25.3.
- **AC10** — **512 KB first: `introseq` PASS, `integ` PASS, `tile` PASS, ALL PASS; then 128 KB:
  `tile` PASS, ALL PASS.** Plus `run_char_test.sh` EXACT at both sizes.
- **AC11** — §0.
- **AC12** — §6.
- **AC13** — §6.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim):**
```
build.bat:
xf_tables: 5376 B, identical to the probe's tables_asm() -> build/gen/xf_tables.s
char_probe_plan: 3 draws on LEVEL0 screen 1   (three CLEAR lines, §3B)
  predicted framebuffer -> build/assets/char_ref.bin (275 B differ from the bare tile reference)
  build/char_probe.bin (9576 bytes)
[map_check] 1 map(s) clean — no overlap, nothing below $0E00.
  CHAR.BIN             9576      9576  ok
  TILE.BIN             1500      1500  ok
# VERDICT: PASS - every file on the image matches its artefact.
=== BUILD COMPLETE ===

run_char_test.sh (512K):
  # LOADM first byte landed at frame 842 / # posted EXEC at frame 1201
  # terminal: status=4 dskerr=00 magic=7B1E ents=80 at frame 1418
  status reached 4 / disk read clean / page magic / 80 of 80 entries / mode 320x192x4 / captured: all PASS
  15360/15360 identical, 0 differ  (100.00%)  -> EXACT
[run_char_test] PASS
run_char_test.sh (128K): 15360/15360 identical -> EXACT, [run_char_test] PASS

run_suites.sh 512K: [run_introseq_test] PASS / [integ] PASS / [run_tile_test] PASS / [suites] ALL PASS
run_suites.sh 128K: [run_tile_test] PASS / [suites] ALL PASS
```
**25.2:** N/A — no sibling-import artifact. `xf_blit.s` is POP's own, and the HAL is untouched.

**25.3 operator-runtime-smoke: FAILED ON ONE POINT — Jay, live-disk, RGB, 512 KB (static picture;
a live observation is complete for it).** Jay: *"they look to be standing properly in the top level.
the sprites look right. the mirrored kid looks coreect except he has bule color instead of orange."*

| judged | verdict |
|---|---|
| placement (standing on the top floor) | **PASS** |
| proportion / the sprites | **PASS** |
| colour, the two left-facing kids (identity, shifted) | **PASS** (no objection) |
| **colour, the mirrored kid** | **FAIL — blue where the oracle has orange** |

#### ★ 25.3's finding, and why the byte-exact prediction could not catch it

*Authority: Jay (the colour) and source (the mechanism), CTRLSUBS.S:805-839; the port's own rule is
`harness/tools/cel_parity_rule.py`, P3.22/P3.65/P3.72h.*

**The oracle picks a character's colour phase per FRAME and per FACING, not per cel.** The draw X is
`2*(CharX + Fdx - ScrnLeft)`, which is always even, **plus 1 iff bit7(Fcheck) == bit7(CharFace)**.
Apple artifact colour is decided by column parity, so this decides orange against blue.

- **Frame 15** has Fcheck = `$43` (bit 7 = 0).
- **Facing left** (`CharFace` bit 7 = 1): no match, so **even** X. That is what the bake assumes
  (`start_col` 0), and it is why the two left-facing kids are right.
- **Facing right** (bit 7 = 0): match, so **odd** X. Mirroring a 14-px (even-width) image flips every
  pixel's parity, and the odd X flips it back, so **the correct mirrored draw needs NO swap**. I drew
  it with the swap, following P5.20's rule (*"swap iff 7·apple_w is even"*, from `bake_scene.py:626`).
  Hence blue.

**Why the prediction agreed with the wrong picture.** The prediction is P5.20's reference: the bake's
mirror at the SAME `start_col` as facing 0, swapped iff the width is even. The cutscene bake gets this
right because it ALSO applies the Fcheck rule. It colours each (cel, facing) at its own `start_col`, and
the two shipped mirrors in P5.20's cross-check (`p11`, `v54`) happened to sit at matching parities. **So
the 4,640 + 2,048 cases and this 15,360/15,360 prove the runtime equals the BAKE. They say nothing about
the bake's colour phase against the ORACLE's, and that is exactly where this fails.** §3E's caveat
anticipated a silhouette difference. The real difference is chroma, and larger.

**★ IT IS NOT ONLY THE MIRROR.** Over FRAMEDEF.S's kid table (`Fdef`), counting the 220 frames with an
image:
- **94 have Fcheck bit 7 = 1**: drawn at ODD X when facing LEFT, i.e. UNMIRRORED. P5.27 coloured every
  cel at even, so those draws would show the same swap.
- **28 of the 147 cels Fdef names are used at BOTH parities** by different frames, so no single baked
  colouring is right for them.

**So the runtime needs a colour swap that is independent of the mirror**, decided per draw from
(Fcheck, CharFace, apple_w). `xf_blit` has no such swap today: the swap is offered only together with
the mirror (`t = 2`). An unmirrored swapped draw would need a swap-only T table and three swap-only shift
pairs (+1,792 B of tables), plus the selection.

**This dispatch stops at the gate and I have not changed anything** (CLAUDE.md §6: no fix attempted
without a ruling). §8.0 names the route.

> **Gate run 1 (2026-10-04), live-disk, RGB, 512 KB, `run_char_live.sh`.** Jay: *"i typed exec and
> closed it. i did see 3 kids two facing left and one facing right."* That is the drawn arrangement
> (two in the stored facing, the mirror opposite). It is recorded as an OBSERVATION, not a pass:
> colour, proportion, placement and the mirrored kid's look have not been ruled on.
>
> The run's log read `status=4` one frame after the script's EXEC, because Jay's own EXEC had already
> run the program during the script's 1,500-frame wait. A headless re-run of the same script on the same
> image walks every stage (boot → mode 1867 → page 1986 → drawn 2008 → shown 2017), so the program
> is unaffected. The wait is now 900 frames (`run_char_live.sh`). Runner: `harness/smoke/run_char_live.sh`, which is
**`live-disk`** (`LOADM"CHAR"` + `EXEC` off `build/char_gate.dmk`), RGB (`dist/mame-cfg/rgb`), 512 KB,
throttled and windowed. **The picture is static, so a live observation is complete for it.**

**What Jay is asked:** on LEVEL0 screen 1, **does the kid look right**? Specifically:
1. **Colour.**
2. **Proportion.**
3. **Placement:** standing on the top floor.
4. **The mirrored kid**, the right-most of the three, facing the other way. It is the first runtime
   mirror of a gameplay cel at gameplay scale.

(The left kid is the stored bake drawn as-is; the middle one is shifted by one pixel. They should look
identical except for position.)

**What Jay is NOT asked:**
- motion or timing (nothing moves);
- **plane ordering** (§3B: deliberately avoided, still untested);
- clipping (none exists; every frame is placed on screen);
- the torch flames and the strength meter (omitted by the tile bake since P5.5);
- the gate (it is on the next screen);
- whether three kids belong there (they are a test pattern, not a scene);
- anything else about the engine.

No PNG was produced: `render_fb.py` needs PIL, which this toolchain lacks (P5.20 §8.7). The capture is
`build/char_front.bin`, and the gate is the live run.

---

### 6 — Reactive deviations, non-proposals, and route accounting

**Deviations:**
1. **`tile_probe.bin` and `probe.dmk` did NOT change, though the dispatch expected both to.** The
   dispatch is self-contradictory on this: its class line says *"`probe.dmk` unchanged"* and AC1 says
   it will change. Changing `tile_probe.bin` would also break the tile suite's byte comparison with the
   bare page, which is P5.5's gated result. So the character probe is a second build of `tile_probe.s`
   (`-DCHAR_PROBE`) on its own gate disk. `tile_probe.s` is still the subject; its shipped binary is
   unchanged.
2. **Composed tables, not the small form** (§3A.2), because the small form is unbuilt.
3. **Three draws on ONE screen, not three programs**, so that Jay compares the mirror with the
   identity side by side. Each draw is still judged separately in bytes (§3E).
4. **The prediction checks the 6809's placement arithmetic too**, not only the blits.
5. **The Lua verifier and live runner are reused with environment overrides** rather than copied. The
   defaults are the previous literals.

**AC12 — not proposed:**
- no motion, sequencer, input or loader;
- no clip path;
- **no plane split** (§2 option 2);
- the cutscene is not migrated;
- no track constants;
- the character probe is not added to `run_suites.sh` (§8.2);
- the uncomposed routine is not built.

**AC13 — ROUTE ACCOUNTING.** I proposed one route in conversation: LOADM-aware placement, with the
overlay above `$4000`. Jay's ruling simplified it, and **this commit contains all of it**: one link,
`prog` at `$5800`, tables at `$4200`, its own gate disk. Nothing I described is unbuilt.

### 7 — Uncertainty flags

1. **Plane ordering is untested** (§3B). This was the first chance to test it and it was deliberately
   avoided.
2. **The gate bars' extent is a claim, not a measurement.** I claimed the whole block (bytes 5..11).
   The kids are at 34+, so the claim does not bear on this picture.
3. **Mirror vs the ORACLE's mirror is unmeasured** (§3E): exact against the bake's mirror only.
4. **The `$83` front pieces** are 4×60 "block front" images by geometry and by the blueprint's
   `block` objids. I did not look at their pixels (CLAUDE.md §3).

### 8 — Follow-up candidates

0. **★ The colour phase (25.3's failure), NOT built.** The per-draw swap should be
   `parity(oracle X) XOR (mirrored AND 7·apple_w even)`, where `parity(oracle X)` = bit7(Fcheck) ==
   bit7(CharFace). Making that possible needs:
   - a **swap-without-mirror** path in `xf_blit`: a T table that only swaps, plus three shift pairs
     built on it, +1,792 B;
   - **Fcheck in the registry**, or per frame where the draw is selected (the cutscene's
     `cel_table.s` +3 carries exactly this, P3.65);
   - **P5.20's reference corrected** to colour by the oracle's rule, so the probe can catch this class
     of error, followed by a re-gate.

   P5.27's bake is unaffected: one stored colouring plus a runtime swap covers all 220 frames, so this
   needs no re-bake.
1. **Plane ordering:** the plane split (§2 option 2), or a placement that deliberately overlaps the
   pillar front, as the test it needs.
2. **Add `run_char_test.sh` to `run_suites.sh`**, so the composition check does not rot (P5.5's own
   argument for adding `tile`).
3. **A PNG path without PIL**, e.g. `zlib` from the standard library, since every runner's PNG
   currently fails here.
4. **An oracle capture of a mirrored gameplay kid**, to measure §5.259's error at gameplay scale.

### 9 — User interaction during task

1. I raised the LOADM ceiling as a constraint on where the routine could go. **Jay:** *"loadm shouldnt
   matter at this point"*.
2. I asked which reading was meant. **Jay:** *"i mean that since we are using a loader to start the
   program, after that loadm areas arent important since we only use loadm to boot."* Applied in §3C.

### 10 — Candidate(s) captured this task

None.

### 11 — Commit

**`b2f67aa`** (16 files). This hash line follows in its own commit. Pushed to `origin/wip`. `main`
untouched at `32b5fe2`. 25.3 will be recorded in a further commit when Jay has looked.
