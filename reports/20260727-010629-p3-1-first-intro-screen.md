## Form B Report — P3.1 — the first intro screen: TRACED, and Phase 2 stopped on scope
**Class:** INVESTIGATE-THEN-BUILD. **Phase 1 COMPLETE and confirmed by Jay. Phase 2 STOPPED (hard-stop 10.2).**
POP `wip`. No engine code written. Karateka untouched; sync bridge green.
**The framing's resolution assumption was WRONG — the intro is DOUBLE hi-res, not 4-colour.**

### 0 — Receipt / status (C-35 stamp)
t0=2026-07-27T01:06:29Z (POP HEAD `db50d2f`, wip; tracked tree clean).
Karateka: `wip` `1c13ae8`, `main` `5eb92b1`. Sync bridge passing.

---

### 1 — Summary

**Following the code paid immediately: two of the three framing assumptions held, and the one that broke is
the one that would have wasted the whole build.**

| question | answer | source |
|---|---|---|
| Identity | **Brøderbund splash** (`PubCredit`) — as guessed | `MASTER.S:687` |
| Full-screen | **yes** — a full DHR page | `MASTER.S` `unpacksplash` |
| **Resolution** | **DOUBLE hi-res, 140×192×16 — NOT 4-colour** | `UNPACK.S:640`, `MASTER.S:96-104` |
| Composition | **base image + delta overlay, page-flipped** — not static | `MASTER.S:687-760` |
| Data location | **raw disk tracks via `rw18`** — NOT in the source tree | `MASTER.S:1168` |
| Behaviour | timed hold → text appears → music → text disappears | `MASTER.S` `PubCredit`/`CleanScreen` |

**The boot path, traced end to end:**
```
MASTER.S FIRSTBOOT → jsr initsystem (TOPCTRL) → jmp AttractLoop
AttractLoop:  jsr SetupDHires     ; blackout + LoadStage1A  (no content -- black)
              jsr PubCredit       ; <<< THE FIRST DISPLAYED SCREEN
              jsr AuthorCredit / TitleScreen / Prolog1 / PrincessScene / ...
```

**`PubCredit` is not a static image, and that changes what "render the first screen" means:**
```asm
PubCredit
 jsr unpacksplash        ; unpack splash into DHires page 1
 jsr setdhires           ; show page 1
 jsr copy1to2            ; copy to page 2
 lda #44 / jsr tpause    ; hold
 lda #delPresents        ; unpack "Broderbund Presents" ONTO page 1  <- a DELTA
 jsr DeltaExpPop
 ldx #80 / lda #s_Presents / jsr PlaySongI
 jmp CleanScreen         ; flip to page 2 -> the credit line disappears
```
Two layers — a base splash and a text delta — sequenced by **page flipping**. The credit text vanishing is
not a redraw; it is a flip to the page that never received the delta. That is the same double-buffer idea
P2.6 built, arriving from the oracle rather than from us.

**The resolution finding is the important one.** `MASTER.S` groups the intro assets under a literal
`* Double hi-res (stage 1)` header, with gameplay backgrounds separately under `* Single hires (stage 2)`:
```
* Double hi-res (stage 1)
pacSplash = $40    delPresents = $70    delByline = $72
delTitle  = $74    pacProlog   = $7c    pacSumup  = $60
* Single hires (stage 2)
pacProom  = $84
```
and `SETDHIRES` programs the hardware for it:
```asm
SETDHIRES
 sta RAMRDaux / sta RAMWRTaux / jsr vblank
 sta ADCOLon          ; annunciator 3 -- DHR colour
 bit HIRESon
 bit DHIRESon         ; (toggled for old Apple RGB cards)
 sta TEXToff
```
So the intro runs at **double hi-res: 560×192 mono, 140×192 in 16 colours** — not the 280×192×4 the framing
assumed. Had that assumption gone unchecked, the conversion path, the palette work and the CoCo3 mode choice
would all have been built wrong. It also means the 16-colour mode built in P2.5/P2.6 is the *right* target
for the intro, which was speculative when it was built and is now grounded.

**Confirmed against the running oracle, not just the source.** The authoritative `.hdv` booted (CFFA2 in
slot 7) and five intro snapshots were captured. **Jay identified `f0600` as the Brøderbund screen**, which
confirms the traced control flow reaches `PubCredit` at ≈frame 600 and fixes the sampling point for the next
increment.

---

### 2 — Files modified

**None tracked.** Phase 1 is a finding; Phase 2 was stopped before any engine code. Artifacts live under
`build/` (gitignored, regenerable — idiom §3):
- `build/oracle_snap/f0600..f1800.png` — oracle intro snapshots (Jay reviewed; `f0600` is the target screen)
- `build/oracle.lua`, `build/dhr2.lua` — throwaway capture scripts

**Not modified:** `oracle/source/` (read-only); Karateka; any engine or HAL source.

---

### 3 — Reasoning

#### 3.1 — Why Phase 2 is stopped (hard-stop 10.2)

The dispatch's Phase 2 says "convert the real image data". That data is **not in the source tree**:
```asm
LoadStage1A
 jsr driveon
 lda #22 / jsr ]lsub
 jsr setmain
 jsr rw18                ; raw RW18 track reads
 db RdSeq.Inc,$60
 jsr rw18
 db RdSeq.Inc,$72
```
`Images/` contains only `IMG.BGTAB*` and `IMG.CHTAB*` — sprite/background tables for gameplay. The intro
assets are packed blobs read off raw tracks into aux memory and expanded by `DBLEXPAND` / `WipeRgtExp`
(`UNPACK.S`, 883 lines — a column-wise "wipe right" crunch format with its own delta variant).

Rendering it as specified therefore needs **three subsystems that do not exist**:
1. raw-track extraction from the disk image (RW18 layout, aux/main split),
2. a port of `DBLEXPAND` + `DeltaExp`,
3. an Apple **double** hi-res → CoCo3 16-colour converter (`sprite_convert.py` handles *single* hi-res →
   4-colour only; different bit layout, different palette model, different pixel width).

That is a large build, not "the first screen", so per hard-stop 10.2 the tractable core is reported and the
rest scoped rather than force-built.

#### 3.2 — The cheaper route the oracle boot opens, and its one blocker

Because the oracle runs, the unpacker does not have to be ported at all: **let the game unpack, then dump the
resulting framebuffer.** CLAUDE.md §2 puts the execution trace above source anyway, so the unpacked bytes are
the better authority.

Attempted this dispatch and **it did not work yet**, for a reason worth recording. Apple DHR page 1 occupies
`$2000-$3FFF` in **both** main and aux memory, interleaved per 14-pixel group; main alone is half the image.
Reading `$C003` (RAMRDaux) from Lua to bank aux in **did not take** — the aux read came back byte-identical
to main:
```
main  : 8192 bytes, 6904 non-zero
aux   : 8192 bytes, 6904 non-zero
restore matches main? true
aux differs from main? false
# banking did NOT take -- aux read is not distinct; do not trust these bytes
```
MAME's Lua memory accessor evidently does not fire the soft switch (or reads bypass banking). **No bytes were
written** — the script refused rather than emit a plausible-looking half-image. Main-bank content is
confirmed present (6,904 non-zero), so the data is there; only the aux path needs solving.

#### 3.3 — What the oracle boot cost, and a self-inflicted detour

`mame -verifyroms a2cffa02` reported *"romset not found"* and I briefly recorded the oracle as unbootable.
That was **my error: I ran it without `-rompath`.** With `-rompath C:/mame/roms` both `a2cffa02` and
`apple2e` verify good and the `.hdv` boots at ~1197% speed. Third instance this session of a broken
*instrument* reading as a broken *subject*; the standing guard (make the tool prove itself before trusting a
null) is exactly what I failed to apply and then did apply, correctly, in §3.2.

#### 3.4 — What Karateka contributes, and what it cannot

`broderbund_scene.s` / `intro_scenes.s` give the CoCo3 intro *structure* — load → mode → render → hold →
transition — and that transfers. What does not transfer is the content pipeline: Karateka's intro art was
converted through the single-hires 4-colour path. POP's intro is double hi-res, so the converter is new work
regardless of structure.

---

### 4 — Verification (AC-by-AC)

- **AC1 — Phase 1 finding reported, cited to the ORACLE. MET.** §1/§3.1, every claim cited to file and
  routine. The framing's "4-colour" is **corrected**, not confirmed.
- **AC2 — resolution determined from display code. MET.** `SETDHIRES` + the `Double hi-res` asset header.
  Mapped to the CoCo3 16-colour mode.
- **AC3 — first screen rendered faithfully. NOT DONE.** Stopped per hard-stop 10.2 (§3.1). The oracle's own
  first screen was captured and confirmed by Jay instead, which is the reference the render will be graded
  against.
- **AC4 — engine→kernel path exercised. NOT DONE.** No engine code; Phase 1 gated Phase 2 and Phase 2 did
  not open.
- **AC5 — scope honesty. MET.** Three missing subsystems named; a cheaper route identified and its blocker
  measured rather than assumed.
- **AC6 — one kernel. MET.** Sync bridge green; nothing touched.
- **AC7 — clean status. MET.**

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 — the traced boot path (verbatim from `MASTER.S`):**
```
FIRSTBOOT ... jsr initsystem ;in topctrl ... jmp AttractLoop

AttractLoop
 lda #1 / sta musicon
 jsr SetupDHires
 jsr PubCredit          <- first displayed screen
 jsr AuthorCredit
 jsr TitleScreen
 jsr Prolog1
```

**25.1 — the resolution, from the asset table and the display code (verbatim):**
```
* Hi bytes of crunch data
* Double hi-res (stage 1)
pacSplash = $40      delPresents = $70    delByline = $72
delTitle  = $74      pacProlog   = $7c    pacSumup  = $60
* Single hires (stage 2)
pacProom  = $84

SETDHIRES
 sta ADCOLon
 bit HIRESon
 bit DHIRESon
 sta TEXToff
```

**25.1 — the load path is raw disk, not the source tree (verbatim):**
```
LoadStage1A
 jsr driveon
 lda #22 / jsr ]lsub
 jsr setmain
 jsr rw18
 db RdSeq.Inc,$60
```
`Images/` listing: `IMG.BGTAB1.DUN … IMG.CHTAB7` — sprite/background tables only, no intro art.

**25.1 — oracle boot, with the correct rompath (verbatim):**
```
romset a2cffa02 is good        romset apple2e is good
Average speed: 1197.22% (31 seconds)
# snapshot at frame 600 / 900 / 1200 / 1500 / 1800
```

**25.1 — the aux-bank dump attempt, refusing to emit untrusted data (verbatim):**
```
main  : 8192 bytes, 6904 non-zero
aux   : 8192 bytes, 6904 non-zero
restore matches main? true
aux differs from main? false
# banking did NOT take -- aux read is not distinct; do not trust these bytes
```

**25.2 —** traced sources: `oracle/source/01 POP Source/Source/MASTER.S` (`FIRSTBOOT`, `AttractLoop`,
`PubCredit`, `LoadStage1A`, the crunch-data table), `TOPCTRL.S` (`START`, `INITSYSTEM`), `UNPACK.S`
(`SETDHIRES`, `DBLEXPAND`, `DeltaExp`). Snapshots in `build/oracle_snap/`.

**25.3 — Jay's gate, PARTIALLY EXERCISED and it did its job.** Five oracle snapshots were surfaced per
CLAUDE.md §3 before any interpretation. **Jay identified `f0600` as the Brøderbund screen**, confirming the
traced flow reaches `PubCredit` there. No POP render exists to compare against yet — that is AC3, deferred.

---

### 6 — Reactive deviations

1. **Phase 2 not attempted.** Hard-stop 10.2: the data is on raw disk in a proprietary crunch format at a
   resolution with no existing converter. Reported rather than force-built.
2. **The oracle was booted, which the dispatch did not ask for.** It was the cheapest way to confirm the
   trace against the running game (CLAUDE.md §2 ranks trace above source) and it turned the increment from
   "port an 883-line unpacker" into "dump a framebuffer".
3. **A `-rompath` omission briefly produced a false "oracle unbootable" reading** (§3.3), self-corrected.
4. **The aux dump wrote nothing** rather than emit a half-image that would have looked plausible and
   converted into a wrong picture.

---

### 7 — Uncertainty flags

1. **Aux-bank access from MAME Lua is unsolved** (§3.2). Without it there is no full DHR page. Options not
   yet tried: the `-debug` console's bank commands, a `ram` device handle, or having the *guest* copy aux to
   main before the dump.
2. **The `.nib` 5.25" pair is NOT the graded oracle** (idioms: its md5s mismatch the Phase 0 reference; the
   `.hdv` matches). Only the `.hdv` was used here — worth stating because the fallback is tempting.
3. **140×192 → 320×192 is not a clean mapping.** Apple DHR colour is 140 px wide; the CoCo3 16-colour mode is
   320. Neither 2× nor any integer scale lands on 320, so the intro conversion needs a stated policy
   (letterbox, stretch, or a different CoCo3 mode). **Not decided, and it is a visual-fidelity decision.**
4. **The delta format is unexamined.** `DeltaExp`/`DELTAEXPPOP` were located but not read; whether the
   "Presents" overlay can be treated as a second full image or must be applied as a delta is unknown.
5. **Timing units are unconverted.** `tpause #44` and `PlaySongI ldx #80` are in oracle units; no mapping to
   CoCo3 frames has been established.
6. **Whether `f0600` is the splash *before* or *after* the delta** is not established — the trace says the
   text appears 44 units after the splash, and a single snapshot cannot distinguish the two layers.

---

### 8 — Follow-up candidates

1. **Solve the aux-bank dump** (§7.1) — the single blocker between here and real pixels. Highest value.
2. **Decide the 140→320 width policy** (§7.3) before any conversion is written; it is a Jay-visible choice.
3. **Capture both layers separately** — dump before and after the `delPresents` delta (§7.6), which also
   answers what `f0600` shows.
4. **Then** build the DHR→CoCo3-16-colour converter and render via the kernel ABI using Karateka's intro
   structure. That is the original Phase 2, correctly scoped.
5. Carried: the unmasked counter read (P2.9 §8.1); the edge-blink raster measurement; unify the two buffer
   models; 16-colour frame budget; the composite-vs-RGB palette comment; `POP-idioms-coco3-markers.md`; the
   CLAUDE.md boot-contract statement drafted in P2.8 §8.1.

---

### 9 — User interaction during task

1. Five oracle snapshots surfaced for identification (CLAUDE.md §3, before any interpretation).
2. **Jay: "f0600"** — identifying which frame holds the Brøderbund screen. That confirmed the traced control
   flow reaches `PubCredit` at ≈frame 600 and fixes the sampling point for the next increment.

---

### 10 — Candidate(s) captured this task
`seeds/POP/live/2026-07-27-trace-the-spec-before-building-to-it.md` — when a faithful port has an executable
original, the spec is a set of checkable facts rather than a design question; and the assumption most worth
checking is the one that silently determines the whole pipeline. Committed and pushed.

---

### 11 — Commit
**POP:** `<hash>` — this report only (no code; Phase 2 stopped). Pushed to POP `origin/wip`.
**Karateka:** untouched at `1c13ae8`; `main` `5eb92b1`.
