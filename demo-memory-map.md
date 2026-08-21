# demo-memory-map.md — the machine at `Demo` entry, and what the demo's assets cost

**Authorship:** Clyde-authored operational state, the same class as `project-state.md` and the
two `mame-idioms-*.md` files. **Not** an authored-authoritative doc under `CLAUDE.md §2D` — no
decision records, post-mortems or behavioural models here.

**Produced:** P5.0 (2026-08-20), against HEAD `7809039` on `wip`.
**Derived from:** the link maps of the current build (`build/obj/*.map`), `src/hal/coco3-dsk/gfx.s`,
`src/hal/coco3-dsk/sys.s`, `harness/tools/cel_pack.py`, and the oracle source at
`oracle/source/01 POP Source/` — every figure below is cited to one of them.

> **★ Sizes here are CURRENT, not aspirational.** `link/pop.link` says the same thing about its
> own map and it is the right warning: re-derive after any asset change.
> `python harness/tools/intro_map.py` regenerates the CPU-space half from the link maps;
> `python harness/tools/demo_asset_census.py` and `demo_frame_census.py` regenerate the asset half.

---

## 1. ★★★ THE FRAMEBUFFER CORRECTION, FIRST, BECAUSE IT CHANGES THE ARITHMETIC

**The port is already in 4-colour and has been since P2.5.** `HAL_gfx_set_mode` writes
`$FF98=$80 / $FF99=$15` — 320×192×4, 2 bpp, 80 B/row — and `GFX_FB_WORDS equ $1E00`
[`src/hal/coco3-dsk/gfx.s:105`] is **7,680 word stores = 15,360 bytes per buffer**.

So there is **no ~15 KB per buffer to free by "repurposing for 4-colour"**: that saving was
taken three years of dispatches ago. What is true, and is the useful form of the same fact, is
that **the 15,360-byte buffers do not fill the 32 KB the block allocation reserves for each of
them** — and the difference has never been claimed by anything. §4 counts it.

---

## 2. CPU space at `Demo` entry — what is alive

| range | bytes | what | authority |
|---|---|---|---|
| `$0000-$001F` | 32 | DP — HAL band | `src/hal.inc` |
| `$0020-$007F` | 96 | DP — engine band | `link/pop.link` |
| `$0A00-$1B97` | 4,504 | **MSYS player** (`section msys`) — *stays; only the song set changes* | `build/obj/msys.map` |
| `$6A00-$6A06` | 7 | disk-driver parameter block (`DR_VARBASE`) | `build.bat` |
| `$7800-$78FF` | 256 | trace ring buffer | `link/pop_engine.link` |
| `$7900-$7D43` | 1,092 | **the kernel** (`section code` = `hal_build.o`) | `build/obj/introseq.map` |
| `$7D44-$7EFF` | 444 | stack space; `$7F00` is the stack top | `link/pop_engine.link` |
| `$8000-$FFFF` | 32,768 | the MMU draw window, `$FFA4-$FFA7` | `gfx.s:402-404` |

**Live total below the window: 6,431 bytes.** Everything else in `$0200-$77FF` is dead at this
point — see §3.

**★ A LOAD EXTENT IS NOT AN OCCUPANCY, and the window is the standing example.** The window is
32 KB of *address space*; a 4-colour framebuffer is 15,360 B of it. What the other 17,408 bytes
are depends on which blocks are mapped, which is §4's subject and not this table's.

---

## 3. CPU space at `Demo` entry — what is dead, and the free runs

Dead, with extents, all from the current link maps:

| range | bytes | what | why it is dead |
|---|---|---|---|
| `$0200-$09FF` | 2,048 | DECB's DBUF0/DBUF1/FAT/FCBs | BASIC is gone after the handover [`CLAUDE.md §2L`] |
| `$0E00-$0FE5` | 486 | the stage-1 loader | jumped away and never re-entered [`link/pop_boot.link`] — *and the MSYS player already reads over it* |
| `$2000-$2514` | 1,301 | the intro program (`intro_seq.o` + `lz_unpack.o`) | all of it |
| `$2600-$2AE2` | 1,251 | the cutscene program (`cutscene_room.o` + `lz_unpack.o`) | all of it |
| `$3000-$3817` | 2,072 | `flame_cels.o` — the torch/hourglass cels | all of it |
| `$3818-$3B07` | 752 | `blit_core.o` | **NOT automatically dead** — see §7 |
| `$3B08-$48C9` | 3,522 | `char_draw.o` | **NOT automatically dead** — see §7 |
| `$3000-$52FF` | 8,960 | the intro caption bundle (shares the above; never live together) | all of it |
| `$5400-$68F1` | 5,362 | `SAVE_BUF`, the caption save buffer | all of it |
| `$5800-$69FF` | 4,608 | the scene's packed-bundle landing zone | all of it |
| `$6C00-$727F` | 1,664 | `VIZ_PEEL` / `PRI_PEEL`, the cutscene peel buffers | dead *unless the gameplay blitter reuses them* |

### ★★ THE CONTIGUOUS FREE REGIONS, WHICH IS WHAT THE DEMO'S ASSETS HAVE TO FIT

Taking the §2 live list as the only thing that survives:

| run | bytes |
|---|---|
| `$0200-$09FF` | 2,048 |
| `$1B98-$69FF` | **20,072** ← the one that matters |
| `$6A07-$77FF` | 3,577 |
| **total** | **25,697** |

The largest single run is **20,072 bytes**, from just above the music player to just below the
disk driver's parameter block. If `DR_VARBASE` moved, `$1B98-$77FF` would be one run of 23,656.

**★ AND THE `LOADM` CEILING DOES NOT APPLY TO ANY OF IT** (`CLAUDE.md §2L`). Nothing here is
resident at the handover; the demo's program arrives the way the scene's does — read from a
track by the port's own driver [`link/pop_scene.link`].

---

## 4. The GIME block map at 128 KB — and 34,816 bytes nothing has claimed

`sys.s:227-241` sets `$FFA0-$FFA7 = $38..$3F`. `gfx.s:417-418` puts buffer A at block `$10` and
buffer B at `$14`, four blocks each. **On a 128 KB machine the GIME masks every block number
mod 16** [`gfx.s:405-417`], so:

| blocks (128 KB) | 8 KB each | occupant | actually used |
|---|---|---|---|
| `$00-$01` | 16,384 | framebuffer **A** | 15,360 |
| `$02-$03` | 16,384 | *A's block reservation* | **0 — FREE** |
| `$04-$05` | 16,384 | framebuffer **B** | 15,360 |
| `$06-$07` | 16,384 | *B's block reservation* | **0 — FREE** |
| `$08-$0B` | 32,768 | CPU `$0000-$7FFF` (program + kernel) | all |
| `$0C-$0F` | 32,768 | the **cel bank** [`cel_pack.py:61-63`] | all |

**★★★ UNALLOCATED PHYSICAL RAM ON A STOCK 128 KB MACHINE: 32,768 bytes (`$02`, `$03`, `$06`,
`$07`), plus the 1,024-byte tail of each buffer's second block — 34,816 in total.** It has never
been claimed because it sits *inside* the framebuffers' four-block reservation, which was sized
for 16-colour and never trimmed when the port settled on 4-colour.

**THE CONSTRAINT THAT SURVIVES RECRUITING IT IS ADDRESSABILITY, NOT CAPACITY.** Only two window
registers are free at a time — `$FFA4/$FFA5` must carry the back buffer's 15,360 B — so the
CPU can see at most **15,872 bytes** of bank at any instant: `$C000-$DFFF` (8,192) plus
`$E000-$FDFF` (7,680; `$FE00-$FEFF` is constant RAM under MC3=1 and `$FF00+` is I/O)
[`link/pop_cels_pg.link`]. Recruiting the free blocks raises the bank from **32,768 to 65,536
bytes of storage**; it does not widen the window.

*(A third window could exist: `$FFA3` covers CPU `$6000-$7FFF`, and §3 shows that region free.
Naming it here is not proposing it — it is an architecture decision, `CLAUDE.md §7.2`.)*

---

## 5. The oracle's `Demo`, and what `LoadStage3` loads

`MASTER.S:958-970` — `blackout` → `LoadStage3` → `setdemolevel` → `rdbluep` → `driveoff` →
`lda #0 / jmp start`.

### 5a. `LoadStage3` [`MASTER.S:1316-1367`], track by track

`rw18` reads **one whole track = 18 sectors × 256 B = 4,608 B**. `RdSeq` = sequential pages from
the given start; `RdGrp` = a page per sector, `00` meaning skip. `.Inc` is `$40`, *"to inc
track"* [`UNPACK.S:90`], so each call advances the track.

| trk | form | Apple destination | bytes | what lands there | port equivalent |
|---|---|---|---|---|---|
| 4 | `RdGrpErr.Inc` sectors 10-17 | **aux** `$2000-$27FF` | 2,048 | `topctrl` — the game loop's entry [`GAMEEQ.S:19`] | code, read to a free CPU run (§3) |
| 5 | `RdSeq.Inc,$60` | aux `$6000-$71FF` | 4,608 | `bgtable1` — background tiles | **cel bank**, §6 |
| 6 | `RdSeq.Inc,$72` | aux `$7200-$83FF` | 4,608 | `bgtable1` cont. | " |
| 7 | `RdSeq.Inc,$60` | **main** `$6000-$71FF` | 4,608 | `chtable1` — the kid | **cel bank** |
| 8 | `RdSeq.Inc,$72` | main `$7200-$83FF` | 4,608 | `chtable1` cont. | " |
| 13 | `RdGrp.Inc` sectors 12-17 | aux `$9600-$9BFF` | 1,536 | `chtable4` — the opponent | **cel bank** |
| 14 | `RdSeq.Inc,$9c` | aux `$9C00-$ADFF` | 4,608 | `chtable4` cont. | " |
| 15 | `RdSeq.Inc,$28` | aux `$2800-$39FF` | 4,608 | `seqtable`/`framedef` `$2800` + `seqtab` `$3000` | animation tables — CPU RAM |
| 16 | `RdSeq.Inc,$3a` | aux `$3A00-$4BFF` | 4,608 | `ctrl` `$3A00` + `coll` `$4500` | code |
| 17 | `RdSeq.Inc,$4c` | aux `$4C00-$5DFF` | 4,608 | `gamebg` `$4C00` + `auto` `$5400` | code |
| 18 | `RdSeq.Inc,$84` | aux `$8400-$95FF` | 4,608 | `bgtable2` — the rest of the tiles | **cel bank** |
| — | `loadmusic2` | — | — | the 16 gameplay songs | **MSYS data only** — §7 |

**Total transferred: 45,056 bytes**, of which **29,184 is image data** (`bgtable1` 9,216 +
`bgtable2` 4,608 + `chtable1` 9,216 + `chtable4` 6,144) and **15,872 is code and animation
tables** (`topctrl` 2,048 + three full tracks).

**★ WHAT `LoadStage3` DOES *NOT* RELOAD, AND WHY THAT IS THE INFORMATIVE HALF.** `chtable2`
(main `$8400`), `chtable3` (`$0800`) and `chtable5` (`$A800`) are absent from the list — yet the
frame table needs all three (§6). They are loaded by an earlier stage and **survive the
cutscene**, which is precisely why they are not here: the cutscene's `chtable6` occupies main
`$6000`, displacing `chtable1` only, so `LoadStage3` restores exactly what was displaced. The
one loose end is `chtable7` at main `$9F00`, which overlaps `chtable2`'s measured extent
(`$8400`+8,893 = `$A73D`); that reload path was not traced and is an open item — it does not
change what the port must hold.

### 5b. `setdemolevel` — what `db 33,0` means

`demolevel db 33,0` [`MASTER.S:93`] → `SetLevel` stores them at `params` = `$3F0`
[`MASTER.S:350-360`], and `$3F0` is `bluepTRK` / `$3F1` is `bluepREG` [`EQ.S`, `dum $3f0`].

> **So `33,0` is a DISK ADDRESS: track 33, region 0** — the first nine sectors of that track.
> It is not a level number and not a coordinate. `firstlevel db 33,1` is the *other* half of the
> same track, which is level 1.

Corroborated independently: `bluepTRKlst[0] = 33`, `bluepREGlst[0] = 0` [`MISC.S:778-786`], the
tables `LOADLEVELX` indexes by level number — and level **0** is the demo. `START` documents it:
*"In: A = level # (0 for demo, 1 for game)"* [`TOPCTRL.S:88`].

Level 0's image sets, from the same file: `bgset1 = 0`, `bgset2 = 0`, `chset = 0`
[`MISC.S:770-772`] — **the dungeon tiles and the guard**, the same sets levels 1-2 use, which is
why `LoadStage3`'s single load already covers the demo.

### 5c. `rdbluep` — the blueprint, exactly 2,304 bytes

`rdbluep` reads nine sectors to pages `$B7-$BF` [`MASTER.S:598-620`] = `$B700-$BFFF` = **2,304 B**,
and the `dum blueprnt` at `EQ.S:139-146` accounts for every byte:

| offset | bytes | field | meaning |
|---|---|---|---|
| 0 | 720 | `BLUETYPE` | 24 screens × 30 blocks, piece id in bits 0-4 (`idmask`) |
| 720 | 720 | `BLUESPEC` | the per-block state byte (gate position, panel variant, spike phase…) |
| 1,440 | 256 | `LINKLOC` | pressplate → target links |
| 1,696 | 256 | `LINKMAP` | the link state the two pressplate rewrites read [`FRAMEADV.S:2065`] |
| 1,952 | 96 | `MAP` | 24 × (left, right, up, down) screen numbers [`CTRLSUBS.S:243-270`] |
| 2,048 | 256 | `INFO` | start positions: kid, sword, and 24 guards |

**Checked against the artefact:** every file in `oracle/source/01 POP Source/Levels/` is exactly
2,304 bytes, `LEVEL0` included.

**LEVEL0's own contents** (`harness/tools/demo_asset_census.py`): 24 screens, of which **10 carry
blocks** (1-9 and 24; 10-23 are empty). Fourteen distinct piece ids are used —
`space floor spikes posts gate pillarbottom pillartop loose upressplate exit exit2 slicer torch
block`. The kid starts on **screen 1**, block 9, facing 255; exactly one guard, on screen 4.

### 5d. `start` with A = 0

`START` [`TOPCTRL.S:88`] → `sta ALTZPon` → `StartGame` → `RESTART`.
`StartGame` [`TOPCTRL.S:149`] sets `level` and `NextLevel` to 0, sets `origstrength`, and calls
`initgame`, which zeroes `blackflag redrawflg inmenu inbuilder recheck0 SINGSTEP ManCtrl vibes
invert milestone timerequest FrameCount NextTimeMsg`, sets `MinLeft`/`SecLeft` to `$FF` and
`SPEED` to 1. **Level 0 is also what suppresses the level banner** — `lda level / beq :nomsg`.

`RESTART` [`TOPCTRL.S:258`] then does the work the port has to provide: `LoadLevelX` (blueprint +
image sets — a *second* load, indexed by level, which for level 0 resolves to the same track 33
region 0), `setinitials`, `initialguards`, twenty-odd zeroed state variables, `zerosound`,
`zeropeels`, `initCDbuf`, `initinput`, `startkid`, `entrance`, **`FirstFrame`**, then `MainLoop`.

`MainLoop` calls `demokeys` and *"During demo, press any key to play"* → `lda #1 / jmp START`.
So the demo is the ordinary game loop with `level = 0` and a prerecorded input source; there is
no separate demo engine in the oracle.

---

## 6. The asset catalogue, and whether it fits

Measured by `harness/tools/demo_asset_census.py` (files) and `demo_frame_census.py` (frames).
"CoCo3" = the port's raw 4-colour 2 bpp footprint, `ceil(w×7 / 4) × h` per cel — **1.85× the
Apple bitmap**, and *not* the compiled-sprite figure, which is larger.

### 6a. Tiles — the static half

| file | cels | Apple B | CoCo3 B |
|---|---|---|---|
| `IMG.BGTAB1.DUN` | 127 | 8,360 | 15,495 |
| `IMG.BGTAB2.DUN` | 51 | 3,373 | 5,955 |
| **dungeon total** | **178** | **11,733** | **21,450** |

Tiles are **not fixed-size, and the distribution is extreme**: `BGTAB1.DUN`'s largest cel is
16 × 63 Apple bytes × rows (675 CoCo3 B) against a **median of 64 CoCo3 bytes** and a minimum of
2 — because a "tile" here is one *section* of a piece, not a square. A block composites up to five of
them — A, B, C, D and a front piece — chosen from `BGDATA.S`'s tables by the piece id, the piece
to its **left**, and the piece **below-and-left**. Thirty piece ids index images up to `$AE`.

### 6b. Characters — the dynamic half

Counted from `FRAMEDEF.S` through `decodeim` [`CTRLSUBS.S:1017`], i.e. **the cels some frame
actually names**, not the file contents:

| actor | frames | table → file | cels | CoCo3 B |
|---|---|---|---|---|
| **the kid** | 240 (234 defined) | 1 `CHTAB1` / 2 `CHTAB2` / 3 `CHTAB3` / 5 `CHTAB5` | **211** | **50,890** |
| **the opponent** | 40 (35 defined) | 4 `CHTAB4.GD` (level 0's `chset`) | **31** | **9,350** |
| *(cutscene chars, for scale)* | 85 | 6 `CHTAB6.A` / 7 `CHTAB7` | 84 | 16,990 |
| **gameplay peak** | | | **242** | **60,240** |

### 6c. ★★★ THE CEL BANK DOES NOT FIT, AND THE SHORTFALL IS NOT MARGINAL

| | bytes |
|---|---|
| characters (kid + one opponent) | 60,240 |
| dungeon tiles | 21,450 |
| **both** | **81,690** |
| the bank as it stands (`$0C-$0F`) | 32,768 |
| the bank with §4's free blocks recruited | 65,536 |

- **The kid ALONE is 50,890 B — 1.55× today's whole bank.**
- Characters alone are **1.84×** today's bank, and fit the recruited 65,536 with 8% spare.
- Characters **and** tiles are **16,154 B over** even the recruited maximum.
- At most **15,872 B is CPU-addressable at any instant** (§4) regardless of which of these holds.

**★★ A SUM IS NOT A RESIDENCY REQUIREMENT — and for the kid it very nearly is one.** The kid can
enter any move at any moment; the oracle keeps `chtable1/2/3/5` resident for the whole game and
never pages them. The tiles are the half with real slack: a screen is composited once and
redrawn only on a room change, so the tile set is a *load-time* requirement, not a per-frame one.

**This is a `CLAUDE.md §7.2` hard stop and is NOT solved here.** The options, named only:
recruit `$02/$03/$06/$07` (§4); page character families from disk per move-group the way the
cutscene pages cels; a denser encoding paid for in decode time; a third window at `$FFA3`.

---

## 7. Engine reuse — what fits and what does not

| subsystem | verdict |
|---|---|
| **MSYS player** | **fits unchanged.** Gameplay differs only in the data: `loadmusic2` in place of `loadmusic1`. The player is 4,504 B at `$0A00` and is already the one thing the map keeps alive across the transition. |
| **disk reader** | **fits.** `disk_read_range` reads whole tracks, which is exactly `rw18`'s granularity; `LoadStage3` is 12 track reads. |
| **VBL handler / `HAL_gfx_swap`** | **fits.** Unchanged requirement. |
| **HAL / GIME setup** | **fits.** Same mode, same palette registers. |
| **blitter (`blit_core.o`) + `char_draw.o`** | **fits in kind, not in place.** Characters over an opaque background with a peel/restore is the same problem the cutscene solved. Two things change: the cel bank they index is §6c's problem, and the peel buffers (`$6C00-$727F`, sized for two cutscene characters) are sized for the wrong actors. |
| **peel/restore** | **fits, and the oracle agrees.** `DRAWALL` [`GRAFIX.S:484`] is `DOGEN → SNGPEEL → ZEROPEEL → DRAWWIPE → DRAWBACK → DRAWMID → DRAWFORE → DRAWMSG`: `DRAWMID` saves underlayers into the cleared peel list and `SNGPEEL` restores them next frame. *Read directly, and it settles P3.44's "no per-sprite save/restore anywhere" the same way P3.88 did.* |
| **the tile renderer** | **DOES NOT EXIST.** This is the one genuinely new subsystem. `harness/tools/bg_compose.py` implements it offline and is validated byte-exact (§8). |
| **the 4-colour palette** | **two homes for one fact.** `HAL_gfx_init` writes `$00/$26/$1B/$3F` directly [`gfx.s:256-262`]; `HAL_gfx_set_mode`'s descriptor points at `gfx_pal4 = $00/$26/$19/$3F` [`gfx.s:801-805`], whose own comment calls it *"DIAGNOSTIC … Not POP's art palette"*. Index 2 differs. `set_mode` runs last, so `$19` is what the machine shows and what Jay has been gating. Worth one line of resolution before the dungeon's colours are judged. |

---

## 8. The tile renderer, offline and checked

`harness/tools/bg_compose.py` implements `SURE` [`FRAMEADV.S:44`] — the 10 × 3 block sweep,
`RedBlockSure`'s nine sections, `getprev`/`getbelow`'s left-and-below context, `ADDBACK`'s
display list, and `FASTLAY`/`FASTMASK`'s bottom-up byte-column blit — and renders a blueprint
screen into an Apple HGR page.

**Checked against the running oracle, not against itself.** `harness/tools/oracle_demo_bg.lua`
boots the oracle to its own `Demo` and dumps both HGR pages out of MAME.

```
LEVEL0 screen 1 vs the oracle's HGR page 2:  7,414 / 7,680 visible bytes identical (96.54%)
  all 266 differing bytes fall in four regions, and all four are named omissions:
     45  cols 0-3    the gate bars of screen 2's block 9, whose position is live state
     14  cols 4-7    the torch flame at block col 0   (drawtorchb -> setupflame, animated)
     24  cols 28-35  the torch flames at block cols 6 and 7
    183  rows >= 160 the kid and the strength meter — not background at all
      0  UNEXPLAINED
```

Rows 24-159 are **byte-identical**. A 24-screen scan picks screen 1 as the best match at 95.5%
against page 1 and no other screen above 66%, so the screen identification is measured too.

**★ The reference is outside the pipeline under test**, which is the lesson `project-state.md`
records from P1.2: 1,152/1,152 pixels once passed on upside-down cels because both sides were
downstream of the same converter.
