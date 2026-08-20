## Form B Report — P4.30 — the door squeaks and the timer sounds; **all six cues now fire**

**Class:** build.  wip.  Prod changed — the PLAN gains two rows; `cel_plan.s`, `cel_pack.json`,
`walk_scripts.s`, `cel_res.s` and `cel_pg0-3.s` regenerated. **No `src/` change.** Karateka untouched;
`main` untouched (`34e93e0`).

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-20 18:44 (HEAD `091bf30` at receipt, wip; `0488bae` at report). Tree clean apart from the modified
`dist/mame-cfg/rgb/coco3.cfg` carried since P4.19 and the pre-existing untracked files.

### 1 — Summary

**Jay:** *"i don't hear the door squeak and there sound be a sound after the vizier exit whith the princess
hani her head. that is missing"*

| | |
|---|---|
| **the defect** | **`PlayCut0` makes SIX `PlaySongI` calls; the PLAN carried FOUR** (§3A) |
| **★★★ `s_StTimer` is a TAIL CALL** | `jmp PlaySongI`, the routine's last act — invisible to "read the body and list the calls" (§3B) |
| **durations** | **MEASURED, not derived** — `sta SPEED` bounds each block exactly (§3C) |
| **★★ the scenery trap** | a 356-frame cue without `SC_GLASS1\|SC_FLOW` stops the sand for six seconds, **and nothing automated would say a word** (§3D) |
| **result** | **all six cues fire**, verified on the running port (§5) |
| **★ the cue deltas grew** | and they are **PROPORTIONAL (~1.17×), not offsets** — P3.87's pace over a longer scene (§3E) |
| **suites** | **ALL PASS, 128 KB, `integ` included** |
| **Jay's gate** | **OFFERED, run launched and completed. PENDING JAY.** |

### 2 — Files modified

- `harness/tools/bake_scene.py` — two PLAN rows; `SONG_ID` gains `s_StTimer: 12`; `SCENERY` re-keyed **and
  gains a row**.
- `harness/tools/oracle_pstand_lead.lua` — filtered to the real `PlaySongI` (`PC=$E479`) and now logs
  `SPEED` writes, which is what made §3C's measurement possible.
- `content/cutscene/chars/` — regenerated: `cel_plan.s`, `cel_pack.json`, `walk_scripts.s`, `cel_res.s`,
  `cel_pg0-3.s`, `v54_m_src.s`.

### 3 — Reasoning

#### 3A — six calls, four rows

```
PlayCut0 [SUBS.S:658-755]                                     in the PLAN?
  lda #2 / jsr play ; lda #s_Princess / jsr PlaySongI              ✓ (P4.27)
  lda #Palert / pjumpseq / play 9
  lda #s_Squeek / ldx #0 / jsr PlaySongI ;door squeaks...          ✗ MISSING
  lda #7 / sta SPEED ; play 5 ; Vapproach ; Vstop
  lda #s_Vizier / jsr PlaySongI                                    ✓
  ... Vapproach ; Vstop ; lda #s_Buildup / jsr PlaySongI           ✓
  ... addglass1 ; sta psandcount ; lda #s_Magic / jsr PlaySongI    ✓
  ... Vexit ; addglass1 ; Pslump ; play
  sta SPEED / lda #s_StTimer / jmp PlaySongI                       ✗ MISSING
```

**`s_Squeek` goes between `Palert` and the `("-","",5)` row** — whose own comment already read *"play 5 —
both hold after the SPEED change"*, referring to the `lda #7 / sta SPEED` that **this very call returns
into**. ★ *The table described the cue's neighbourhood without containing the cue, which is the second time
in four dispatches a PLAN comment has been more complete than the data beside it.*

#### 3B — ★★★ THE TAIL CALL IS WHY ONE OF THEM STAYED HIDDEN

`s_StTimer` is not a `jsr`. It is **`jmp PlaySongI`** — `PlayCut0`'s final act, a tail call. **I enumerated
this routine's calls earlier in the session and reported "five `PlaySongI` calls" from reading the body**;
the sixth is past the last `jsr play`, in the two lines that end the routine.

★★ **A tail call is exactly the call a reader stops before**, because the natural reading strategy is "walk
the body until it returns" — and a tail call *is* the return. It is also, structurally, the routine's **last
and often most significant action**. `s_StTimer = 12` [`SOUNDNAMES.S:54`]; `MASTER.S`'s Set-1 list stops at
`s_Magic = 11` and never names it, which is why `SONG_ID` had no entry either. **Two records, both
incomplete in the same direction.** Captured (§10).

#### 3C — ★★ THE DURATIONS ARE MEASURED, AND THAT IS NEW FOR THIS TABLE

`PlaySongI` **blocks** while the music plays, and `PlayCut0` punctuates itself with `sta SPEED`. So the
first `SPEED` write after a cue **is the frame that cue's block ended** — an exact boundary, not an estimate:

```
# --- song cues ($031A read, id in Y) ---        # --- SPEED writes ---
  frame   847   s_Squeek   (Y= 8)                  frame   916   SPEED = 7
  frame  2562   s_StTimer  (Y=12)                  frame  2918   SPEED = 1
```

| row | derivation |
|---|---|
| `s_Squeek` | 916 − 847 = **69 frames** |
| `s_StTimer` | 2918 − 2562 = **356 frames** |

**★ The three existing song rows could not do this.** `bake_scene.py`'s own notes derive 761, 358 and 394 as
*"measured interval minus N plays at ~6 f/play"* — an estimate with the plays-per-frame rate inside it.
These two are boundary-to-boundary.

★ *`s_StTimer`'s 356 frames are real hold: the oracle's cutscene does not end until the song does, because
the tail call blocks. The port's scene must not terminate under it, so the row sits before the terminal
`("v","Vstand",0)`.*

#### 3D — ★★★ THE SCENERY ROW, WHICH NOTHING AUTOMATED WOULD HAVE CAUGHT

`SCENERY` is keyed by PLAN index. Inserting `s_Squeek` at 4 shifts everything after by one; inserting
`s_StTimer` at 20 shifts `Vstand` again. **The name assertion catches a missed shift** — that is what it is
for, and it passed.

**What the assertion CANNOT catch is a beat that needs a flag and has no entry at all.** The flags are
**per-beat and do not persist**: a beat without `SC_GLASS1|SC_FLOW` stops the sand and reverts the glass
body. `s_StTimer` holds for **356 frames — nearly six seconds** — so omitting its row would have hidden the
hourglass through the whole of the scene's last sound.

**★★ No cue table, no suite, no framebuffer byte-diff would have reported it.** The cues would all have
fired; `integ` checks that the scene is reached and returns; the pixel comparison was retired at P4.2. **It
would have reached Jay's eye and nothing else.** A row was added at index 20 and the reasoning written
beside it.

#### 3E — ★ THE DELTAS GREW, AND THE SHAPE SAYS WHY

| cue | oracle | port | ratio |
|---|---|---|---|
| `s_Squeek` | 14.1 s | 16.4 s | **1.16** |
| `s_Vizier` | 16.7 s | 19.5 s | **1.17** |
| `s_Buildup` | 26.3 s | 29.4 s | **1.12** |
| `s_Magic` | 34.9 s | 40.7 s | **1.17** |
| `s_StTimer` | 42.7 s | 50.5 s | **1.18** |

**A constant ratio, not a constant offset.** The oracle's `PlayCut0` ends at frame 2918 = **48.6 s** against
the port's **58.3 s** scene = **1.20×** — which is **P3.87's ~19% pace slip**, closed by Jay's decision,
now visible across a longer scene with the full cue list in it. ★ *Not a new defect, not addressed here, and
explicitly not re-opened without his say-so.*

#### 3F — §2B, checked before accepting the regenerated assets

**There is still no protection catalog** (no POP asset is authored/altered yet). Every regenerated file
declares itself `GENERATED by bake_scene.py` **except `v54_m_src.s`**, which is a converted cel
(`ORIGIN: IMG.CHTAB6.A`). Its diff is **1 line changed, 0 non-comment lines**: a derived `start_col`
comment moved `289 → 467` with the parity still `ODD`, so **the cel's pixels are untouched**. `cel_res.s`
and `walk_scripts.s` are 2-line comment deltas.

★ *Worth surfacing rather than passing over: `start_col` lives here as a CEL COMMENT and moves when the beat
schedule changes, while CLAUDE.md §2F.1(5) says it is "a STRUCTURED registry field (not a cel comment)".
That inconsistency is pre-existing and not introduced here — §8.*

#### 3G — §2H's three checks

1. **A second mechanism?** ★ **Yes, and it is §3D.** A cue row is not only a cue: it is a **beat**, and beats
   carry block, signature, read and scenery columns. Adding one for its sound alone would have silently
   dropped the scenery.
2. **The calling routine.** The cue is emitted by `song_at(bi)` off the PLAN tuple; the **read points** are
   derived from `PLAN[bi][0] == "song"`, so a new song row is also a new **read candidate** — the packer
   re-ran its search and still schedules the single read at beat 12 in a long hold. *Checked, not assumed.*
3. **Prior-report grep** (`PlaySongI|s_Squeek|s_StTimer|PLAN`): P4.7, P4.23, P4.26b, P4.27, P4.29. **No
   contradiction.** P4.23 recorded both cues as "never fires" and that is now explained rather than
   restated.

### 4 — Verification (against the ask)

- **Both cues fire** — **PASS**, on the running port (§5).
- **Durations measured** — **PASS** (§3C), boundary-to-boundary.
- **Index shift safe** — **PASS**: `SCENERY`'s name assertion aligns on every key (checked by loading the
  module and comparing keys to beat names, not by eye).
- **Scenery preserved across the new cue** — **PASS by construction** (§3D); ★ *and by Jay's eye at the
  gate, because nothing automated can see it.*
- **Assets** — §3F.
- **Suites** — `ALL PASS` at 128 KB with `integ`. ★ *512 KB not run: no MMU, bank, framebuffer or loader
  change.*

### 5 — Verdict-time evidence (v0.7 §11)

```
[suites] -ramsize 128K
[run_introseq_test] PASS
[integ] PASS
[suites] ALL PASS
```
```
# scene frames 5418..8914 = 58.3 s
  s_Princess      5451       0.6s       0.2s      +0.4s
  s_Squeek        6400      16.4s      14.1s      +2.3s
  s_Vizier        6586      19.5s      16.7s      +2.8s
  s_Buildup       7178      29.4s      26.3s      +3.1s
  s_Magic         7854      40.7s      34.9s      +5.8s
  s_StTimer       8441      50.5s      42.7s      +7.8s
```
```
NEW PLAN (22 rows) — every SCENERY key aligned with its beat name: True
song rows -> [(1,'s_Princess',7), (4,'s_Squeek',8), (8,'s_Vizier',9),
              (12,'s_Buildup',10), (16,'s_Magic',11), (20,'s_StTimer',12)]
```
```
# VERDICT: PASS - every file on the image matches its artefact.
=== BUILD COMPLETE ===
```

**25.3 operator-runtime-smoke: PENDING JAY — live-disk, RGB, 128 KB, sound on, BY EAR.** The run was
launched and completed at real speed; **a completed run is not a verdict and is not recorded as one.** Not
self-certified. ★ *The last recorded operator ruling is P4.29's: timing accepted, quality "still a bit
crappy", these two cues missing.*

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** This was not a dispatch — it is the §8 item Jay said *"doit"* to. **This commit
contains** both cue rows with measured durations, the `SONG_ID` entry, the `SCENERY` re-key **and its new
row**, and the regenerated content.

**It does NOT contain** any change to the pace (§3E), to the audio quality residual P4.29 left open, or to
the narrower blit window P4.29 §8 evidenced. ★ *All three are open and none was touched under cover of this
one.*

**★ AND I CORRECTED MY OWN ENUMERATION MID-TASK (§3B):** I told Jay there were "five `PlaySongI` calls in
`PlayCut0`; the PLAN carries four" after reading 120 lines of the routine. **There are six.** The sixth was
the tail call, past where I stopped reading. The correction is the finding.

### 7 — Uncertainty flags

- **★★ `s_StTimer`'s 356 frames end at the NEXT SCENE's `SPEED` write, not at `PlaySongI`'s return.** That
  boundary includes whatever `SetupDHires` and `Prolog2`'s entry cost before their first `sta SPEED`, so the
  true block is **356 frames or slightly less**. It is an upper bound, and the error is at most the few
  frames of that setup.
- **The scene is now 58.3 s against the oracle's 48.6.** Whether that is acceptable **with the full cue list
  in place** is a fresh question for Jay's ear — P3.87 was settled on a shorter, quieter scene.
- **The audio QUALITY residual is untouched** — P4.29's 52.9% and Jay's *"still a bit crappy"* stand.
- **`s_Squeek`'s 69-frame hold is short** (~10 plays at `SONG_FPS` 7). If the port's rendering of that song
  runs longer than its hold, the following beat will cut it off. **Not measured** — the ear will say.

### 8 — Follow-up candidates

- **★★ THE AUDIO QUALITY RESIDUAL** — P4.29 §8's narrower window: mask only the two blast regions instead of
  at entry, giving the interrupt a gap between every *segment* rather than every *row*. **Evidenced, not
  speculative**, and the most likely lever on *"still a bit crappy"*.
- **★ P3.87's PACE, NOW WITH A REASON TO REVISIT IT** — the port's cutscene is 1.20× the oracle's, and every
  cue is proportionally late (§3E). It was accepted on a scene without `s_Squeek` or `s_StTimer` in it.
  **Jay's ruling; the measurement is now in hand either way.**
- **`start_col` as a cel comment vs §2F.1(5)'s "structured registry field"** (§3F) — a pre-existing
  inconsistency, surfaced not fixed.
- Carried: the 6-byte headroom; the disk's 18-of-18 granules; the `LOADM` ceiling; gameplay's colour mode;
  the per-cue control policy; the HAL audit; the stale `pop.link` stack comment; `Demo` unbuilt.

### 9 — User interaction during task

- Jay: ***"doit"*** — this task, on P4.29 §8's first item.
- Jay: ***"run the oracle for me"*** — launched with sound, for the A/B.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-20-a-tail-call-is-the-call-the-reader-stops-before.md` — committed and pushed.

### 11 — Commit

`0488bae` (pushed to origin/wip before this report) + this report.
