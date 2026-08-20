# Form B Report — P4.46 (loading screen + stage-1 loader) and P4.47 (BEAT_KEEP) — the intro's boot and its titles

**Class:** build. wip. Prod unchanged — this dispatch does not touch a `main` artefact.

## 0 — Receipt / status (C-35 stamp)

t0 = 2026-08-20 (dispatch P4.46 received in-session; exact receipt stamp not carried into this
context — recorded honestly rather than reconstructed). HEAD `4961e83`, wip, pushed.
`git status` clean for tracked paths in scope; the untracked `docs/ground-truth/*.pdf`,
`nvram/`, `.vscode/` and `POP-idioms-coco3-markers.md` are pre-existing and out of scope.

## 1 — Summary

P4.46 gives the port a **"loading" screen in the game's own byline font**, shown before any game
data is read. The word is not drawn — it is **lifted from the byline caption patch**, so the
letters are the game's letters by construction. A new stage-1 loader (`src/boot/loader.s`,
`$0E00`) owns the boot, puts the word up, reads the intro's program off **raw track 33**, and
enters it at a new second entry point. `INTROSEQ` stops being a DECB file.

P4.47 then answers two things Jay reported watching it: **the first title clears while the disk
loads**, and **the final title clears where the oracle's does not**. Both are one mechanism — a
new per-beat `BEAT_KEEP` flag — and they are settled differently (one by §2I, one by the oracle
source). Making room for it exposed and fixed a live memory-map collision.

## 2 — Files modified

- `src/boot/loader.s` — NEW. Stage-1 loader: boot prefix, mode, palette, `draw_loading`, swap,
  track-33 read, hand-off. Carries its own `load_tracks`.
- `link/pop_boot.link` — NEW. `prog @ $0E00`, `code @ $7900`, entry `boot_entry`.
- `harness/tools/byline_font.py` — NEW. Segments the byline patch into glyphs.
- `harness/tools/gen_loading.py` — NEW. Emits `build/gen/loading_data.s` (16 B palette + 263 B patch).
- `harness/tools/render_loading.py` — NEW. Writes `build/loading_preview.png` (§3: surfaced, never interpreted).
- `src/engine/intro_seq.s` — `intro_seq_boot` second entry (+B, after the probe block);
  `BEAT_KEEP` field, variable, descriptor copy and branch; `SCENE_BASE $2500 → $2600`;
  `seq_run` header invariant corrected.
- `build.bat` — loader generation/assembly/link/put; `INTRO_TRK=33`, `INTRO_BOOT_OFF=11`;
  `intro_prog.raw` on track 33; `SCENE_BASE=0x2600`; readback list gains `LOADER.BIN`.
- `link/pop_scene.link` — `section prog load 2600` (+ comments).
- `link/pop_engine.link`, `link/pop_msys.link` — map comments follow `SCENE_BASE`.
- `harness/smoke/introseq_test.lua` — `LOADER_SWAPS`; tags `7_title_held`, `11_title_held`;
  held-title gate moved to `st=5 ph=2`.
- `harness/tools/verify_introseq.py` — the two held-title comparisons and the mid-sweep `old_fb`
  now use `ttl_fb`; required-tag list updated.
- `harness/smoke/run_introseq_test.sh`, `run_introseq_live.sh`, and 20 harness `.lua` files —
  `LOADM"INTROSEQ"` → `LOADM"LOADER"`, `BIN` → `build/loader.bin`.

## 3 — Reasoning

### 3A The loader's disk read — the bug, and why it presented as something else

**Authority: trace (§2.2), then source.** The loader LOADMed correctly (1593 B, 2 segments),
reached its read (`trk=33` at frame 1283), and the WD1773 census showed **`op 4 … 4608 bytes`** —
18 sectors, exactly right. Nothing landed at `$2000`; the machine reset into BASIC (`PC` at
`$A064`, `$FA2D`, `$A840` — all Color BASIC ROM; the "writes spanning `$0000..$FFFF`" was the CPU
executing zero bytes as `NEG direct`).

Jay's hypothesis — the loader sitting in the DHR draw window and being overwritten by the draw —
was testable and was **refuted by a write-tap on the loader's own extent**: exactly eight writes,
all of them `draw_loading`'s own seven variables at `$0EA0..$0EA6`, with `dl_base = $B8E0` =
`$8000 + 91×160`, correct. The draw was never the problem.

**The fault was in `loader.s`'s hand-typed parameter-block offsets:** `dr_status=+0, dr_dest=+3`
against the driver's `dr_dest=+2, dr_status=+4` [`src/hal/coco3-dsk/disk_read.s:77-82`]. `stx
dr_dest` landed the destination one byte high, so the driver read perfectly and wrote to `$??20`.
`disk_read.s:106-108` warns about precisely this drift. The fix copies `intro_seq.s`'s six equates
verbatim and lists **all six** though the loader writes four — a partial list is what went wrong.

**★ The diagnostic probe inherited the bug**: it read `dr_dest` at `+3` because it was written from
the loader's own equates, and so reported the parameter block as zeroed — corruption that never
happened. An instrument built from the artefact under test cannot see a fault in the assumptions
they share.

### 3B The titles — and the two are settled differently

**Authority: source (§2.3), confirmed against Jay's observation (§2.1).**

- `SilentTitle` [MASTER.S:808-822] = `unpacksplash / copy1to2 / tpause 20 / DeltaExpPop delTitle /
  jmp tpause 160`, then RETURNS into `jmp Demo` [MASTER.S:709]. **No `CleanScreen`**, where both
  `PubCredit` and `TitleScreen` end with one. The port's clear was its own invention. Jay was right.
- `TitleScreen` [MASTER.S:823-838] **does** end `jmp CleanScreen` ("Credit line disappears"). So
  beat 2's clear was faithful to the instruction and wrong about the result: the oracle
  batch-loads, the port pays beat 3's scene preload *and* prolog1's read there. **§2I governs** —
  reproducing the oracle's action reproduced the opposite of its appearance.

### 3C §2H's three checks

1. **A second mechanism for a different object class?** Yes, and it matters. The take-down is
   *two* things — the swap (the visible disappearance) and `patch_blit`'s repair (which makes the
   hidden page clean). Skipping only the swap would leave the caption up and silently erase it
   from the page behind, so any later swap-in would show it vanishing for no reason. `BEAT_KEEP`
   skips **both**. Picture beats (`sq_nopatch`) have no caption and are untouched.
2. **The calling routine, not the implementation.** The tail is reached by *every* beat with a
   non-zero `BEAT_PATCH` — beats 0, 1, 2 and 5. A blanket change would have altered beats 0 and 1,
   which `PubCredit` and `AuthorCredit` both end with `jmp CleanScreen` and which Jay did not
   report. That is why this is a **per-beat table field**, not a rule.
3. **Prior-report grep.** `seq_run`'s header states "a caption beat leaves both buffers holding its
   clean base". `BEAT_KEEP` **breaks that invariant**, so the header was corrected rather than left
   to mislead: a keep beat satisfies neither "both clean" nor "both hold the picture". It is safe
   only because beat 2 is followed by a **wiping** beat (`wipe_in` leaves both buffers holding
   prolog1) and beat 5 is **last**. That is a condition, and it is now written down.

### 3D The memory-map collision

`BEAT_KEEP` grew the intro prog past `$2500`. The scene program is read as a **whole track** (4608 B
for a 1,191-byte program) starting at `SCENE_BASE`, so it was clipping the last 14 bytes of
`lz_unpack.o` (`$2480..$250D`) — which `load_screen` still needs for beats 3, 4 and 5. A real,
fatal collision, not tidying.

**`intro_map.py` listed both regions overlapping and did not flag it.** What caught the incomplete
move was `build.bat`'s `decb_to_raw` base assertion. Four homes had to agree: `build.bat`,
`intro_seq.s`'s `ifndef`, `link/pop_scene.link`'s load address, and three link-script comments.

## 4 — Verification (AC-by-AC)

- **The loading word is the game's own font** — lifted from the byline patch by `byline_font.py`
  using the gaps already present (1–2 px letters, 5–7 px words). Jay's steer that the wide gaps are
  real spaces removed the need for any hand-tuning. Corrections applied: dotless `i`, `i` height
  4→6 rows, and the `j` cap dropped from `l`/`i`.
- **Shown before the game data loads** — the loader draws and swaps before `disk_read_init`.
- **The intro still runs** — `introseq` 18/18 live + 12/12 offline PASS; `integ` PASS.
- **The first title holds through the disk reads** — `title HOLDS through beat 3's reads: 30720
  bytes byte-identical` to `ttl_fb`.
- **The final title is never cleared** — `reprise HOLDS -- SilentTitle never clears it: 30720 bytes
  byte-identical` to `ttl_fb`.
- **prolog1 wipes over the held title** — the mid-sweep composite check passes with `old_fb =
  ttl_fb`: swept through content col 39, unswept from 41, 1 column caught mid-copy.
- **No map overlap** — `intro_map.py` shows `$250E..$25FF FREE`, scene at `$2600..$2A54`.

## 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output:**
```
VERDICT: PASS - every file on the image matches its artefact.
=== BUILD COMPLETE ===

[run_introseq_test]  checks=18 passed=18 failed=0   VERDICT: PASS
  PASS base screen == converted splash, centred: 30720 bytes byte-identical
  PASS title == base + title patch ONLY: 30720 bytes byte-identical
  PASS title HOLDS through beat 3's reads: 30720 bytes byte-identical
  PASS reprise == the SAME screen as beat 3's title: 30720 bytes byte-identical
  PASS reprise HOLDS -- SilentTitle never clears it: 30720 bytes byte-identical
  VERDICT: PASS
[run_introseq_test] PASS

[integ]  21 reads (14 into the draw window), 890 swaps
         PASS — no swap shares a frame with a draw-window read anywhere in the run.
[integ] PASS
```

**25.2 bundled-artifact grep:** N/A — disk-image build, no sibling-import artefact. The
byte-wise disk readback stands in its place and passes for all 5 files.

**25.3 operator-runtime-smoke: PASSED — Jay, live-disk, RGB, 128 KB.** Two separate gates, both
observed live on a running machine rather than on a still, because both are motion-bearing (§4):

- **the loading screen** (P4.46) — Jay: *"looks good."*
- **the two title changes** (P4.47) — Jay: *"looks good."*

The launch path was `live-disk` in both cases: real `LOADM"LOADER"` + `EXEC` off the mounted
floppy via `harness/smoke/run_introseq_live.sh` — the delivery path, not the poke path.

## 6 — Reactive deviations and route accounting

- **`SCENE_BASE $2500 → $2600` was not in either dispatch.** It is a forced consequence of
  `BEAT_KEEP`, and it is a genuine collision rather than a tidy-up (§3D). Flagged rather than
  folded in silently.
- **ROUTE ACCOUNTING.** For P4.46 I proposed: *"a second entry point into the intro, past its mode
  set, exactly like the scene's `room_call` at +B. That's 3 bytes."* **This commit contains that in
  full** — `intro_seq_boot` at `+B` with a build-time offset assertion. Nothing from that proposal
  was dropped. No route was proposed for P4.47 beyond what is implemented.

## 7 — Uncertainty flags

- **`intro_map.py` does not flag overlaps** — it printed a fatal collision as two ordinary rows.
  A checker, not a listing, would have caught this at the moment it was created. Not fixed here
  (out of scope); surfaced as a follow-up.
- **The `BEAT_KEEP` safety condition is a comment, not an assertion.** A keep beat must be followed
  by a beat that rebuilds both pages, or by nothing. `beat_patch_check.py` already asserts an
  adjacent condition at build time, so there is precedent for making this one mechanical too.
- **512 KB not run.** §2K makes 128 KB primary and this touches the memory map, so a 512 KB
  confirmation is worth doing; a divergence would itself be informative.
- The audio "fuzziness" on `s_Princess` remains **unexplained** (P4.36–P4.45); untouched here.

## 8 — Follow-up candidates

1. Make `intro_map.py` **fail** on overlapping live regions rather than listing them.
2. Give the disk driver's parameter block **one home** — a shared `.inc` included by driver and
   clients — so the offsets cannot be re-typed at all (§3A).
3. Assert the `BEAT_KEEP` adjacency condition at build time, next to `beat_patch_check.py`.
4. 512 KB confirmation run for the `SCENE_BASE` move.

## 9 — User interaction during task

- Jay: *"i think the extra space youre seeing is actual spaces seperating the words"* — removed the
  need to hard-code which glyphs split.
- Jay: *"dotless"*; *"the i is too short and i don't like the vertical bar above i and l"* — both applied.
- Jay: *"the intros headroom shouldnt matter. this is prior to all that"* — corrected my misdiagnosis.
- Jay: *"if your putting the loader in the DHRes window then it will be overwritten by the draw."* —
  tested directly and refuted; the tap that refuted it is what localised the real fault.
- Jay: *"looks good."* — the 25.3 gate on the loading screen.
- Jay: *"the fisrt title screen clears the tiltle while the disk loads, i'd rather keep the title up
  until the disk reads are done. also, the final tiltle screen clears the title, the oracle doesn't"*
  — P4.47 in full.

## 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-20-a-partial-copy-of-a-shared-layout-is-more-dangerous-than-no-copy.md`
  (pool `b21bafc`, pushed)

## 11 — Commit

`964a51c` (P4.46) and `4961e83` (P4.47) — both pushed to `origin/wip` before this report.
