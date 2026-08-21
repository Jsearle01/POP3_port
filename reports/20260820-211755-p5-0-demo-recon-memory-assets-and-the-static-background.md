## Form B Report — P5.0 (RECON) — the demo's memory map, its asset catalogue, and a tile renderer that matches the oracle byte for byte

**Class:** recon (+ one offline build tool). wip. Prod byte-identical — no file under `src/`, `content/`, `link/` or `build.bat` was touched.

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-20T22:25:48Z (HEAD `7809039`, wip). Tree at receipt was dirty only with the standing
untracked set (`docs/ground-truth/*.pdf` — local-reference-only by standing ruling —, `.vscode/`,
`nvram/`, `POP-idioms-coco3-markers.md`, `content/intro/broderbund_splash_render.bin`) plus a
modified `dist/mame-cfg/rgb/coco3.cfg`. None of those was touched by this task.

Prod `build/intro_seq.bin` sha1 `d07f1f3295525783968dcce6409ee1b64942231c`,
`build/loader.bin` `0b4968867bf5274d2942f3b5b90ea855ad6f2def`,
`build/cutscene_room.bin` `790836577e56b61b8f849cb309874e44304840a2` — rebuilt from unchanged
sources, so byte-identical by construction.

### 1 — Summary

The demo's memory map, asset catalogue and engine-reuse assessment are delivered as a checked-in
artifact (`demo-memory-map.md`), derived from the current link maps and the oracle source rather
than from prose. Three findings dominate. **(a) The dispatch's framebuffer premise is stale in a
useful direction**: the port has been 4-colour since P2.5, so there is no 15 KB per buffer to free
— but the 15,360-byte buffers sit inside a four-block reservation sized for 16-colour, and
**34,816 bytes of physical RAM on a stock 128 KB machine belong to nothing at all.** **(b) The cel
bank does not fit, and not marginally**: the kid alone is 50,890 B of 4-colour cels against a
32,768-byte bank, the two gameplay actors together are 60,240 B, and with the dungeon tiles the
figure is 81,690 B — 16,154 over even the maximum recruitable 65,536. That is a `§7.2` hard stop
and is reported, not solved. **(c) `demolevel 33,0` is a disk address, not a level number** —
track 33, region 0 — and the level it names was confirmed by rendering it: a new offline tile
compositor (`bg_compose.py`) reproduces the demo level's first screen and **matches the running
oracle's HGR page on 7,414 of 7,680 visible bytes, with every one of the 266 differences falling
inside four named omissions and zero unexplained.**

### 2 — Files modified

New, explicit-path staged:

- `demo-memory-map.md` — **the AC1 artifact.** CPU map at `Demo` entry, the GIME block map at
  128 KB, `LoadStage3` catalogued track by track with port-equivalent placement, the blueprint
  format, the tile and character catalogues, the fit arithmetic, and the engine-reuse table.
- `harness/tools/demo_asset_census.py` — every `IMG.*` table: cel count, extent, Apple bytes,
  CoCo3 4-colour bytes; plus `LEVEL0`'s piece histogram and per-screen occupancy.
- `harness/tools/demo_frame_census.py` — `FRAMEDEF.S` through `decodeim`: the cels each actor's
  frames actually name, per table, with the CoCo3 footprint.
- `harness/tools/oracle_demo_bg.lua` — boots the oracle to its own `Demo` and dumps both HGR
  pages plus a screenshot.
- `harness/tools/bg_compose.py` — POP's background renderer, offline, into an HGR page; diffs
  against the oracle dump and can scan all 24 screens to identify which one is showing.

Nothing under `src/`, `content/`, `link/` or `build.bat`. `main` untouched. Karateka untouched.
Oracle source read only.

### 3 — Reasoning

#### 3A — §1, the pre-demo map, and the premise that was already spent

**Authority: the tree (link maps + `gfx.s`/`sys.s`), which outranks the dispatch's summary.**

The dispatch lists `$8000-$FDFF` as *"the framebuffers, repurposed for 4-colour — 2bpp instead of
4bpp, so each buffer is half as large, freeing ~15 KB per buffer inside the draw window."*
`gfx.s:105` reads `GFX_FB_WORDS equ $1E00` — 7,680 word stores, **15,360 bytes** — and
`HAL_gfx_set_mode` writes `$FF99=$15`. **The port has never run gameplay-adjacent code in
16-colour**; PA.8 excluded 16-colour on memory alone and P2.5 shipped the 4-colour mode. The
saving the dispatch expects to bank has been banked since.

What *is* true is the same fact one level down, and it is worth more. `gfx.s:417-418` puts buffer
A at block `$10` and B at `$14`, **four blocks each**, because the reservation was sized for
16-colour's 30,720 B. A 4-colour buffer uses 15,360. On 128 KB the GIME masks mod 16, so:

```
$00-$01  buffer A   15,360 of 16,384        $08-$0B  CPU $0000-$7FFF
$02-$03  FREE       16,384                  $0C-$0F  cel bank        [cel_pack.py:61]
$04-$05  buffer B   15,360 of 16,384
$06-$07  FREE       16,384
```

**32,768 bytes in `$02/$03/$06/$07`, plus the 1,024-byte tail of each buffer's second block:
34,816 unallocated.** Nothing has claimed it because it is *inside* the framebuffers' reservation,
which is exactly the shape of thing a map that lists CPU ranges cannot show.

CPU side at `Demo` entry: **6,431 bytes live** below the draw window (DP 128, MSYS player 4,504,
`DR_VARBASE` 7, trace ring 256, kernel 1,092, stack 444) and **25,697 free in three runs**, the
largest being **`$1B98-$69FF`, 20,072 bytes**. Full table in the artifact.

**★ A LOAD EXTENT IS NOT AN OCCUPANCY** — the standing caution, and the window is its live
example: 32 KB of address space, 15,360 B of pixels, and the remainder is whatever the MMU has
mapped there this instant.

#### 3B — §2, `LoadStage3` traced, and §2H's second check paying off

**Authority: source (`MASTER.S`, `UNPACK.S`, `MISC.S`, `TOPCTRL.S`), corroborated by a render.**

`rw18` moves one whole track (18 × 256 = 4,608 B) per call; `.Inc` is `$40`, *"to inc track"*
[`UNPACK.S:90`]. Twelve calls, tracks 4-18, **45,056 bytes**: 29,184 of image data (`bgtable1`
9,216 + `bgtable2` 4,608 + `chtable1` 9,216 + `chtable4` 6,144) and 15,872 of code and animation
tables. The per-track table with Apple destinations and port-equivalent placement is §5a of the
artifact.

**§2H check 1 — is there a SECOND mechanism serving a different object class? There are THREE
planes, not the two the dispatch's table names.** `DRAWALL` [`GRAFIX.S:484`] draws
`DRAWWIPE → DRAWBACK → DRAWMID → DRAWFORE → DRAWMSG`. The dispatch pairs "static (tiles)" with
`bgtable` and "dynamic (characters)" with `chtable4`; the **foreground** plane is neither. It is
fed by `drawfrnt` [`FRAMEADV.S:754`] from the *same* `bgtable` images, drawn *after* the
characters, and half of its entries go through `maddfore` — the same image queued **twice**, once
with `OPACITY=mask` and once with `ora`, so `FASTMASK` punches a hole with `MASKTAB[b & $7F]` and
`FASTLAY` fills it. **A tile renderer that draws only the background plane will put every post,
railing, arch and torch-bracket BEHIND the prince.** This is the single most load-bearing thing
the recon found about the tile path, and the two-column framing would have hidden it.

**§2H check 2 — name the routine that CALLS it.** `LoadStage3`'s callers are `Demo`
[`MASTER.S:960`] **and** `DOSTARTGAME` [`MASTER.S:1024`] — the identical load. The demo differs
from a real game start only in `setdemolevel` vs `set1stlevel` and in not setting `musicon`.
**There is no demo-specific load path and no demo engine**; `MainLoop` runs `demokeys` and any key
does `lda #1 / jmp START`. The scope fact is that building the demo IS building the game loop.

**§2H check 3 — grep the reports before citing a characterisation.** Ran it over `DRAWALL`/peel:
`PA.2` (peel list = 2 blits per image), `P3.44` (*"no per-sprite save/restore anywhere in it"*),
`P3.46b`, and **`P3.88`, which settled it — the oracle peels.** Read directly here for the third
time and independently: `DRAWMID` saves underlayers into the just-cleared peel list and `SNGPEEL`
restores them at the head of the next frame. P3.88's verdict stands; nothing new to reopen.

#### 3C — §2b, what `db 33,0` means, answered rather than assumed

**Authority: source, then confirmed by rendering the level it names.**

`demolevel db 33,0` → `SetLevel` stores A and X at `params` = `$3F0` [`MASTER.S:350-360`], and
`EQ.S`'s `dum $3f0` names `$3F0` `bluepTRK` and `$3F1` `bluepREG`. **So `33,0` is a disk address —
track 33, first region — not a level number and not a coordinate.** `firstlevel db 33,1` is the
other half of the same track.

Corroborated from the enclosing routine rather than the initialiser, per §2H: `LOADLEVELX`
[`MISC.S:795`] indexes `bluepTRKlst`/`bluepREGlst` by level number, and entry **0** is `33,0`
[`MISC.S:778-786`]. `START`'s own header says *"A = level # (0 for demo, 1 for game)"*
[`TOPCTRL.S:88`]. Level 0's sets are `bgset1=0, bgset2=0, chset=0` — dungeon tiles, guard — which
is why `LoadStage3`'s single load already covers it and `LOADLEVEL`'s set comparison skips the
reloads.

**And it was checked, not left at that:** §3E's compositor renders `LEVEL0` and matches the
running oracle. `demolevel 33,0` produces the level the tables say it does.

#### 3D — §2b/§2c, the blueprint and `start`

Blueprint = **exactly 2,304 bytes**, nine sectors to pages `$B7-$BF` [`MASTER.S:598`], and
`EQ.S`'s `dum blueprnt` accounts for every byte: `BLUETYPE` 720 (24 screens × 30 blocks, piece id
in bits 0-4), `BLUESPEC` 720 (per-block state), `LINKLOC` 256, `LINKMAP` 256, `MAP` 96
(24 × left/right/up/down), `INFO` 256 (kid start, sword start, 24 guard starts). Every file in
`Levels/` is 2,304 bytes, which is the artefact agreeing with the equate.

`LEVEL0`: ten screens carry blocks (1-9 and 24); fourteen piece ids in use; the kid starts on
screen 1 block 9; **one** guard, on screen 4.

`start` with A=0 → `StartGame` (sets `level`/`NextLevel` = 0, `origstrength`, `initgame`'s
thirteen zeroed vars, `SPEED`=1) → `RESTART`, which is the list the port has to provide:
`LoadLevelX`, `setinitials`, `initialguards`, ~24 zeroed state variables, `zerosound`,
`zeropeels`, `initCDbuf`, `initinput`, `startkid`, `entrance`, `FirstFrame`, `MainLoop`. Level 0
is also what suppresses the level banner (`lda level / beq :nomsg`).

#### 3E — §4, the static background: composed, and checked against the running oracle

**Authority: the trace. The reference is the oracle's own framebuffer, dumped from MAME.**

The port has no tile renderer, and the route P3.2/P3.17 used for the cutscene room — acquire the
room as a picture — does not scale here: 24 screens × 15,360 B is 368 KB. So `bg_compose.py`
implements the renderer offline: `SURE`'s 10 × 3 sweep with its three-rows-then-the-D-row-above
shape, `RedBlockSure`'s nine sections, `getprev`/`getbelow`'s left-and-below context (including
the `:belowblack` path that leaves `SBELOW` deliberately stale), `getobjid`'s two pressplate
rewrites, `ADDBACK`'s `YCO >= 192` drop, and `FASTLAY`/`FASTMASK`'s bottom-up byte-column blit.

`oracle_demo_bg.lua` boots the oracle to its own `Demo` — arming on a **write** tap to `level`
after frame 600, the same guard `oracle_scene.lua` uses because P4.9 once reported a PASS off
uninitialised RAM by *reading* one — and dumps both HGR pages.

```
LEVEL0 screen 1  vs  the oracle's HGR page 2
  7,414 / 7,680 visible bytes identical  (96.54%)
  266 differ, and every one of them is inside a named omission:
     45  cols 0-3     gate bars — screen 2's block 9 IS a gate (verified in the blueprint),
                      and its bar position is live state no blueprint holds
     14  cols 4-7     the torch flame at block col 0        [drawtorchb -> setupflame]
     24  cols 28-35   the torch flames at block cols 6 and 7
    183  rows >= 160  the kid and the strength meter — not background at all
      0  UNEXPLAINED
  rows 24-159 are BYTE-IDENTICAL
```

A 24-screen scan against page 1 picks **screen 1 at 95.5%** with no other screen above 66%, so
which screen the oracle was showing is measured rather than assumed.

**★ The reference sits outside the pipeline under test**, which is `project-state.md`'s own P1.2
lesson: 1,152/1,152 pixels once passed on upside-down cels because both sides of the comparison
were downstream of the same converter.

The composed page was then converted with the existing `hgr_screen_convert.py` (the frozen colour
model, unmodified) and rendered 1:1 with `render_fb.py` — **framebuffer dumps rendered offline,
not MAME snapshots**, per the idiom `mode_test.lua` records. **PNGs surfaced for Jay, unread:**

- `build/demo_bg/port_composed_s1.png` — the composed background in the port's 4-colour palette
- `build/demo_bg/oracle_frame_s1.png` — the oracle's own frame through the same conversion
- `build/demo_bg/oracle_mame_screenshot.png` — MAME's snapshot of the oracle at that frame

**What this is NOT:** it has not been drawn by port code on the GIME. The composition and the
colour conversion are both checked; putting it on the machine needs either the runtime tile
renderer or a room-image loader, and both are the next task rather than this one. §6's route
accounting says so again.

#### 3F — §3/§5, the catalogues and the fit

Characters are counted from the **frame tables**, not the files — a cel no frame names is never
drawn. `FRAMEDEF.S` through `decodeim` [`CTRLSUBS.S:1017`, implemented in arithmetic, not
paraphrased]:

| | frames | tables | distinct cels | CoCo3 4-colour B |
|---|---|---|---|---|
| the kid (`Fdef`) | 234 defined | `CHTAB1/2/3/5` | **211** | **50,890** |
| the opponent (`ALTSET1`) | 35 defined | `CHTAB4.GD` | **31** | **9,350** |
| gameplay peak | | | **242** | **60,240** |
| dungeon tiles | | `BGTAB1/2.DUN` | 178 | 21,450 |
| **both** | | | | **81,690** |

**The cel bank is 32,768 B; recruiting §3A's free blocks makes it 65,536.**

- **The kid alone is 1.55× today's whole bank.**
- Characters alone are 1.84× today's bank and fit the recruited maximum with 8% spare.
- Characters *and* tiles are **16,154 B over** even that maximum.
- At most **15,872 B is CPU-addressable at any instant** regardless — `$FFA4/$FFA5` must carry the
  back buffer, leaving `$C000-$DFFF` (8,192) + `$E000-$FDFF` (7,680).

**★★ A SUM IS NOT A RESIDENCY REQUIREMENT — and for the kid it very nearly is one.** He can enter
any move at any moment and the oracle never pages `chtable1/2/3/5`. The tiles are the half with
slack: a screen is composited once and redrawn on room change, so they are a load-time
requirement, not a per-frame one. **Hard stop `§7.2` — not solved here.** Options named only:
recruit `$02/$03/$06/$07`; page character families per move-group the way the cutscene pages cels;
a denser encoding paid for in decode time; a third window at `$FFA3` (CPU `$6000-$7FFF`, which
§3A shows free).

#### 3G — §5, engine reuse: five of six fit, one does not exist

Full table in the artifact. In short: **MSYS player fits unchanged** (only `loadmusic2` instead of
`loadmusic1` — data, not code, and it is already the one thing the map keeps alive across the
transition); **disk reader fits** (`disk_read_range` is whole-track, which is exactly `rw18`'s
granularity); **VBL handler, `HAL_gfx_swap` and the GIME setup fit unchanged**; **blitter and
`char_draw` fit in kind but not in place** — same problem shape, but the bank they index is §3F's
problem and the peel buffers at `$6C00-$727F` are sized for two cutscene characters, not a prince
and a guard; **peel/restore fits and the oracle agrees**; **the tile renderer does not exist** and
is the one genuinely new subsystem. **No conflict was found that argues for a second engine.**

One loose thread surfaced: **the 4-colour palette has two homes.** `HAL_gfx_init` writes
`$00/$26/$1B/$3F` inline [`gfx.s:256-262`]; `HAL_gfx_set_mode`'s descriptor points at `gfx_pal4 =
$00/$26/$19/$3F` [`gfx.s:801-805`], whose own comment calls it *"DIAGNOSTIC … Not POP's art
palette."* Index 2 differs. `set_mode` runs last, so `$19` is what the machine shows and what Jay
has been gating all along — it is a duplicated fact, not a visible defect, and worth one line of
resolution before the dungeon's colours are judged.

### 4 — Verification (AC-by-AC)

- **AC1 pre-demo memory map as a checked-in artifact** — `demo-memory-map.md`: live items with
  extents, dead items with extents, three free runs totalling 25,697 B, the 128 KB block map with
  34,816 B unallocated, and the framebuffer premise corrected. Regenerable:
  `python harness/tools/intro_map.py`.
- **AC2 `LoadStage3` traced and catalogued** — §5a of the artifact: 12 track reads, contents,
  sizes, Apple addresses, port-equivalent placement; totals 45,056 B (29,184 image / 15,872 code).
  `.Inc = $40` confirmed at `UNPACK.S:90`.
- **AC3 `demolevel 33,0` understood from `setdemolevel`** — track 33 / region 0, a disk address,
  three independent citations (`MASTER.S:350-360` + `EQ.S dum $3f0`; `MISC.S:778-786`;
  `TOPCTRL.S:88`) and confirmed by rendering the level it names (AC7).
- **AC4 blueprint format and size** — 2,304 B, six fields accounted byte for byte, and every
  `Levels/*` file is exactly 2,304 B.
- **AC5 tile catalogue** — 178 dungeon cels, 11,733 Apple B, **21,450 CoCo3 B**; variable-size,
  median 64 CoCo3 B, max 675; five sections per block. `demo_asset_census.py`.
- **AC6 character catalogue and the bank** — 242 cels / **60,240 B** peak, kid 211 / 50,890,
  guard 31 / 9,350. **DOES NOT FIT**: 1.84× the bank, 81,690 with tiles vs 65,536 recruited
  maximum. Hard stop reported, not solved. `demo_frame_census.py`.
- **AC7 static background rendered in 4-colour and presented alongside the oracle** — composed
  from the oracle's tile data, **96.54% byte-identical to the running oracle's HGR page with zero
  unexplained differences**; converted to 4-colour and rendered 1:1. Three PNGs listed in §3E.
  **Qualified: this is an offline 1:1 render, not yet drawn by port code on the GIME.**
- **AC8 engine reuse assessment** — §3G and the artifact's §7: five subsystems fit, one is absent,
  two mis-sizings named, no conflict arguing for a second engine.
- **AC9 Jay gates the static background by eye** — **pending Jay.**
- **AC10 suites green 128 KB first** — see §5. `main` untouched, Karateka untouched.
- **AC11 route accounting** — §6.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim):**

```
$ cmd /c C:\Projects\POP3_port\build.bat
...
--- cel image: 5 units placed, 10 tracks ---

Contents of build\probe.dmk:
------------------------------ -------- --------------- ------------------
PROBE.BIN                          1256             2 B
MODE.BIN                           1319             2 B
ANIM.BIN                           1438             2 B
INTRO.BIN                         28132             2 B
LOADER.BIN                         1593             2 B
------------------------------ -------- --------------- ------------------
       5 File(s)           33738 bytes                            6912 bytes free
[map_check] 5 map(s) clean — no overlap, nothing below $0E00.
  PROBE.BIN            1256      1256  ok
  MODE.BIN             1319      1319  ok
  ANIM.BIN             1438      1438  ok
  INTRO.BIN           28132     28132  ok
  LOADER.BIN           1593      1593  ok
# VERDICT: PASS - every file on the image matches its artefact.
=== BUILD COMPLETE ===

$ bash harness/smoke/run_suites.sh
[suites] running: introseq integ
[suites] retired at P3.103 (see harness/smoke/retired.sh): probe cel compiled mode anim room walk
[suites] -ramsize 128K

[suites] === introseq ===
[run_introseq_test] PASS
[suites] === integ ===
[integ] PASS

[suites] ALL PASS
```

512 KB not run: no change touches the MMU, the bank, the framebuffers or the loader (§2K — 128 KB
first, 512 KB is confirmation and most dispatches do not need it).

Recon tool output:

```
$ python harness/tools/demo_frame_census.py
PEAK GAMEPLAY RESIDENT SET (kid + opponent, the demo's two actors):
   table 0 -> IMG.CHTAB1        64 cels  apple= 8632  coco3=16114
   table 1 -> IMG.CHTAB2        69 cels  apple= 8609  coco3=16146
   table 2 -> IMG.CHTAB3        35 cels  apple= 4152  coco3= 7768
   table 3 -> IMG.CHTAB4.GD     31 cels  apple= 5149  coco3= 9350
   table 4 -> IMG.CHTAB5        43 cels  apple= 5854  coco3=10862
   TOTAL                           242       apple=32396  coco3=60240
GRAND TOTAL (chars + background), CoCo3 4-colour raw: 81690 B

$ python harness/tools/bg_compose.py --screen 1 --compare build/oracle_demo_hgr2.bin
level LEVEL0 screen 1, bgset DUN
  background list 64 entries, foreground list 16
  OMITTED (state-dependent, not in the blueprint):
    x1   gate B-section (drawgateb: live gate position)
    x1   gate bars over character (DrawGateBF?: needs kid position)
    x3   torch FLAME (drawtorchb -> setupflame: per-frame animation)
  vs build/oracle_demo_hgr2.bin: 7414/7680 visible bytes match (96.54%), 266 differ
```

**25.2 bundled-artifact grep:** N/A — no bundled artifact and no sibling import; nothing under
`src/` or `content/` changed.

**25.3 operator-runtime-smoke:** **pending Jay.** The background PNGs in §3E are `static-png` and
are *not* a live gate: they are an **offline 1:1 render of a framebuffer the port has not yet
produced on the machine**, which is weaker still than the `static-png` class `CLAUDE.md §4`
defines. Nothing here should be recorded as a passed visual gate. The background is static, so
motion is not at issue; the open question is colour, and that is Jay's eye on RGB.

### 6 — Reactive deviations and route accounting

**Deviations from the dispatch spec:**

1. **§1's framebuffer premise was not adopted.** The dispatch asks the map to *"note what CHANGES
   about the framebuffer — 4-colour (2bpp) uses 15,360 bytes per buffer against the intro's
   16-colour at 30,720, freeing ~15 KB per buffer."* The port is already 4-colour; nothing
   changes. The artifact states the correction first, because the arithmetic downstream of it
   would otherwise be 30 KB optimistic, and supplies the fact that replaces it (34,816 B of
   unallocated physical RAM).
2. **`§4`'s render is offline, not on the GIME.** Reasoning and its limits are in §3E; the
   consequence for the gate is in §5's 25.3 line.

**ROUTE ACCOUNTING.** No route was proposed in conversation before this task; there was no prior
message describing a plan that this commit could diverge from. Within the task, the one place a
plan was formed and then changed is worth stating: the oracle capture was first attempted via the
`demo_arrive` save state, which restores and then makes MAME exit before the autoboot script loads
— exit 0, no log, no error. That failure is recorded in `oracle_demo_bg.lua`'s header and the
full 110-second boot is used instead. The `demo_arrive.sta` written along the way is a by-product
and nothing depends on it.

**What this commit contains that the dispatch asked for:** AC1-AC8 and AC10-AC11 in full.
**What it does not contain:** AC7's render has not been drawn by port code on the CoCo3 — it is
composed offline and colour-converted offline — and AC9 is Jay's.

### 7 — Uncertainty flags

1. **`chtable2` / `chtable3` / `chtable5` are not in `LoadStage3`'s list**, yet the kid's frames
   need all three. They must be loaded by an earlier stage and survive the cutscene, which is
   consistent with the cutscene's `chtable6` displacing only main `$6000`. The loose end:
   `chtable7` at main `$9F00` overlaps `chtable2`'s measured extent (`$8400` + 8,893 = `$A73D`),
   and no reload of `chtable2` was found. **Not traced; it does not change what the port must
   hold**, but it is an unresolved contradiction in the oracle's own load map and is flagged
   rather than smoothed over.
2. **The AUX dump failed and was not needed.** `oracle_demo_bg.lua` could not find MAME's
   `auxram` share and the enumeration printed nothing, so the blueprint and tile tables were not
   read out of the running machine. The compositor uses `Levels/LEVEL0` and `Images/IMG.BGTAB*.DUN`
   from the vendored tree instead — and the 96.54% match against the machine's own framebuffer is
   the check that makes that substitution safe. If a future task needs live AUX, the share lookup
   needs solving first.
3. **`level` and `params` read through the MAIN program space came back as 255 and 89,250**, not
   0 and 33,0. POP runs with `ALTZPon` and toggles `setaux`/`setmain` constantly, so a debugger
   read of page 3 lands in whichever bank is switched in at that instant. **The arming write tap
   is unaffected** (it fires on the write, wherever it lands) and the render confirms the level
   independently — but any future read of a POP game variable from Lua must resolve the bank
   first, and this report's numbers do not depend on those reads.
4. **The compositor is validated on one screen of one level.** The unimplemented movable pieces
   (gate bars, slicer blade, loose-floor motion, flask bubbles, exit door, torch flame) are
   enumerated by the tool at run time rather than silently skipped, but they are unimplemented.
5. **The palette has two homes** (§3G). Not a defect today; a duplicated fact.
6. **`bg_compose.py` reads the `IMG.*` tables at base `$6000`** for every file, recovered from
   each file's own pointer list. Correct for all sixteen, but it means the vendored images are
   the *unrelocated* masters — the disk imager places them. Not investigated further.

### 8 — Follow-up candidates

1. **The cel-bank architecture decision** (`§7.2`, hard stop): recruit `$02/$03/$06/$07`, page per
   move-group, denser encoding, or a third window at `$FFA3`. Jay's to authorise.
2. **The foreground plane.** §3B's finding: a tile renderer must draw back **and** fore, with
   `maddfore`'s mask-then-or pair, or every railing and post lands behind the prince.
3. **Port the tile compositor to 6809** — `bg_compose.py` is the specification, and its diff
   against the oracle is the acceptance test the port version can reuse unchanged.
4. **Peel-buffer sizing** for a prince and a guard rather than the vizier and the princess.
5. **Resolve the 4-colour palette's two homes**, and decide whether the dungeon needs an art
   palette distinct from the cutscene's.
6. **The MAME `auxram` share** (flag 2), if live AUX reads are ever needed.
7. **`project-state.md` is stale** — last updated 2026-07-26, "Engine: nothing built yet", and the
   whole P3/P4 arc has happened since. It is the file the standing rules say to read first.

### 9 — User interaction during task

None.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-20-a-phase-boundary-frees-content-not-machinery.md` — committed and pushed
to the pool (fire-and-forget).

### 11 — Commit

See the commit that carries this report; pushed to `origin/wip` before reporting.
