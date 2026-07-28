## Form B Report — P3.12 — the screens are compressed; 21 tracks become 6
**Class:** BUILD. POP `wip`. **Karateka UNTOUCHED** — `main` `5eb92b1`, `wip` `56a02e4`;
**0 files** under `src/hal/` touched; sync bridge green.
**25.3: pending Jay.**

### 0 — Receipt / status (C-35 stamp)
t0=2026-07-28T19:28:00Z (POP HEAD `8cf8aeb`, wip; tracked tree clean).
**No dispatch receipt exists for P3.12.** Jay asked which further disk-load
reductions were possible at 512 KB, then whether options 1 (prefetch) and 3
(compression) were possible at 128 KB, then said *"lets do 3 first"*. Recorded the
way P3.6 and P3.11 recorded the same situation.
Karateka: `main` `5eb92b1`, `wip` `56a02e4`.

---

### 1 — Summary

The three intro screens are LZ-compressed on disk and expanded **in place**, inside
the framebuffer they are displayed from, so this costs no RAM and works on a 128 KB
machine. Each screen went from 7 tracks to 2: **21 tracks to 6**, and the intro
reaches its last disk read **1,027 frames — 17.1 s — earlier** than at P3.11.

The format was chosen by measurement, not preference. Byte RLE is nearly useless on
these dithered images (6 tracks); row-XOR then RLE reaches 4; a simple LZ reaches 2;
zlib would reach 1 but wants a Huffman decoder in 6809 assembly. A one-track fit was
attempted and missed by 170 B, and chasing it was rejected — a 1.6% margin any asset
edit would break is a coincidence with a threshold.

The decoder was wrong on the first attempt in a way that cost most of the task, and
the way I misread the test output cost more than the bug did. Both are in §3.

---

### 2 — Files modified

- `harness/tools/lz_pack.py` — NEW. The compressor, a reference decoder, the in-place
  margin analysis, and a simulation of the real in-place expansion.
- `src/engine/intro_seq.s` — `lz_unpack` (the 6809 decoder), `LZ_LOAD_OFF`,
  `LZ_SRC_END`, `SCREEN_TRACKS`, `lz_tok`/`lz_end`/`lz_cnt`, and `load_screen` now
  reads a packed blob high in the window and expands it downward.
- `build.bat` — packs the screens, places 2-track blobs instead of 7-track ones.
- `mame-idioms-coco3-port.md` — idiom 38 (a 16-bit count cannot live in D across a
  copy loop).

Explicit-path staging only.

---

### 3 — Reasoning

**Why LZ and not RLE.** Measured on the three real screens, not assumed:

| encoding | avg bytes | tracks | |
|---|---|---|---|
| PackBits (byte RLE) | 25,934 | 6 | the images are dithered; byte runs are rare |
| RLE16 | 26,965 | 6 | longer counts make it worse |
| row-XOR + PackBits | 15,102 | 4 | vertical coherence is real |
| LZSS 12/4 | 6,462 | 2 | |
| **LZ4-style** | **5,994** | **2** | chosen |
| zlib -9 | 4,281 | 1 | needs a Huffman decoder |

Two findings worth keeping. **Row-XOR helps RLE and hurts LZ** (10,679 vs 8,445 on the
splash) — the delta destroys the long literal matches an LZ lives on, so they are
alternatives, not a stack. And zlib's extra track is 1.3 s per screen against an
entropy coder in assembly, which is not a trade worth making.

**Why in-place works, and the 1,536 bytes that make it fit.** The writer walks up from
the framebuffer base while the reader walks up from the blob, and the writer produces
faster than the reader consumes, so they converge. The stream must therefore start at
least `peak` bytes in, where peak is the high-water mark of (written − consumed).
Measured, peak sits 7–13 B *above* the final value, so placing the stream flush at the
end of a 30,720 B framebuffer misses on all three screens.

The draw window is 4 × 8 KB = 32,768 B while the framebuffer is 30,720, and
`$8000-$FDFF` is usable (`$FE00-$FEFF` is held constant by MC3=1, `$FF00` up is I/O).
That is 32,256 usable bytes. Placing the stream flush against *that* ceiling gives
1,535 B of slack on every screen. `lz_pack.py` does not merely compute this — it
**decodes each blob out of a single buffer exactly as the 6809 does** and compares,
so the claim is tested per screen rather than argued.

**The decoder bug, which could never have worked.** Both copy loops were written as:

```asm
lz_lit_loop     lda     ,u+
                sta     ,x+
                subd    #1          ; D is the count
                bne     lz_lit_loop
```

`lda` loads into **A, which is D's high half** — the first byte copied overwrites the
counter, so `subd` decrements the data. It cannot terminate correctly for any input.
Counting in B with the page byte in memory fixes it (idiom 38). [Authority: source +
trace.]

**How I misread the evidence, which cost more than the bug.** The first run printed
seven consecutive `capture_<screen> PASS` lines and failed on the eighth, and I
reported that the splash decoded byte-perfect and the prologue did not. Those checks
assert **that a dump file was written** — nothing about its contents. The byte
comparisons live in a later stage that never ran, because the run died first.

So the premise "screen one is right, screen two is wrong" was never checked, and two
experiments were then designed against it: capping match length to force single-byte
255-chains (eliminated the extension path), and simulating the assembly as written
(which passed, because the *algorithm* was right — my transcription of the assembly
into the simulator did not reproduce the register clobber, since Python has no A).
Both experiments were sound and both were meaningless: they searched for a difference
between two cases that were the same case. **Two eliminations in a row should have
sent me back to the premise.**

**The guard is worth keeping on its own merits.** The failure presented as a machine
that scribbled through `$FF00` I/O — remapping memory underneath the routine doing the
remapping — so it looked data-dependent and address-dependent, anything but "the loop
is impossible". `cmpu #LZ_SRC_END / bhs lz_done` stops the reader leaving the window,
converting a self-destroying machine into a merely wrong picture. A wrong picture can
be looked at.

---

### 4 — Verification (AC-by-AC)

- **AC1 — screens are compressed on disk.** 30,720 B → 8,298 / 4,936 / 4,731 B
  (27.0% / 16.1% / 15.4%), 7 tracks → 2 each, 21 → 6.
- **AC2 — the picture is unchanged.** All eleven offline byte comparisons pass,
  **30,720 bytes byte-identical each** — including both prologue screens, which are
  now produced entirely by the decoder, and the reprise, which must equal beat 3's
  title having arrived by a different route.
- **AC3 — it is faster.** The splash read went 539 → 180 frames (9.0 s → 3.0 s), and
  cumulatively the intro reaches its last read at frame 3845 against 4872 —
  **1,027 frames = 17.1 s earlier.** Decode costs ~41 frames (~680 ms) per screen,
  measured as the read-to-swap gap, against the ~6 s each read saves.
- **AC4 — 128 KB.** `MAME_RAM=128K`: `checks=16 passed=16 failed=0`, `VERDICT: PASS`,
  asset comparison `VERDICT: PASS`. No banked RAM is used by this feature at all.
- **AC5 — no regressions.** `run_probe_test` PASS, `run_mode_test` PASS,
  `run_anim_test` PASS.
- **AC6 — Karateka untouched.** No file under `src/hal/`; sync bridge green.

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim):**

`build.bat` (asset stage):
```
intro_screen.raw      30720 ->   8298 B (27.0%), 7 -> 2 tracks, load at +23040, in-place slack 1535 B
prolog1.raw           30720 ->   4936 B (16.1%), 7 -> 2 tracks, load at +23040, in-place slack 1535 B
prolog2.raw           30720 ->   4731 B (15.4%), 7 -> 2 tracks, load at +23040, in-place slack 1535 B
                     21 tracks -> 6 tracks (19.7 s of disk saved)
                     every screen loads to framebuffer +23040 -- one constant for the engine
build/intro_seq.bin (1763 bytes)
=== BUILD COMPLETE ===
```

`run_introseq_test.sh` (512 KB):
```
# frame   942  disk read 1 complete (+257 frames, 4.3 s)
# frame  1122  disk read 2 complete (+180 frames, 3.0 s)
# frame  2780  disk read 3 complete (+1658 frames, 27.6 s)
# frame  3845  disk read 4 complete (+1065 frames, 17.8 s)
# checks=16 passed=16 failed=0
# VERDICT: PASS
  PASS base screen == converted splash, centred: 30720 bytes byte-identical
  PASS caption 1 == base + presents patch: 30720 bytes byte-identical
  PASS caption 1 removal is exact: 30720 bytes byte-identical
  PASS caption 2 == base + byline patch ONLY: 30720 bytes byte-identical
  PASS caption 2 removal is exact: 30720 bytes byte-identical
  PASS title == base + title patch ONLY: 30720 bytes byte-identical
  PASS title removal is exact: 30720 bytes byte-identical
  PASS 8_prolog1 == its own converted picture: 30720 bytes byte-identical
  PASS 9_prolog2 == its own converted picture: 30720 bytes byte-identical
  PASS reprise == the SAME screen as beat 3's title: 30720 bytes byte-identical
  PASS reprise removal is exact: 30720 bytes byte-identical
VERDICT: PASS
[run_introseq_test] PASS
```

`MAME_RAM=128K bash harness/smoke/run_introseq_test.sh`:
```
# checks=16 passed=16 failed=0
# VERDICT: PASS
VERDICT: PASS
[run_introseq_test] PASS
```

Regressions:
```
probe   [run_probe_test] PASS
mode    [run_mode_test] PASS
anim    [run_anim_test] PASS
```

**25.2 bundled-artifact grep:** N/A — ROM/disk build, no sibling-import artifact.

**25.3 operator-runtime-smoke:** **pending Jay.** What to check: the intro should look
exactly as it did at P3.9/P3.11 — every screen is byte-identical to before — while
running about 17 s shorter, with the waits before each prologue picture noticeably
briefer. Nothing about any picture should have changed.

---

### 6 — Reactive deviations

- **A permanent reader guard was added (§22.5).** Not in the plan; added first as a
  diagnostic and kept because it is right on its own terms. Past `$FDFF` lies constant
  RAM and then I/O, so a desynced stream reads the GIME and then writes it. The guard
  is two instructions.
- **A one-track fit was attempted and abandoned.** A lazy parse got prolog1/2 to 4,983
  and 4,778 against a 4,608 B track. Rejected rather than tuned further: a 1.6% margin
  that any asset edit would silently break is not a design.
- **`build.bat` line endings, again.** Same working-copy drift as P3.11 §6 — the file
  is canonically LF in the repo with `.gitattributes` carrying `*.bat text eol=crlf`,
  and a tool had rewritten it in place with LF, so `cmd.exe` could not parse it. Fixed
  in the working copy again. It will keep recurring until the tools that rewrite it
  respect the attribute; worth a real fix as a follow-up rather than a repair per task.

---

### 7 — Uncertainty flags

- **Decode cost is measured indirectly.** ~680 ms per screen comes from the gap between
  the read completing and the page flip, which also contains the bank save, the swap
  and the sampler's granularity. It is an upper bound, not the decoder's own time. If
  that number ever matters, it wants measuring directly.
- **`lz_pack.py`'s in-place proof is per screen, not general.** It verifies the blobs
  it just produced. A new screen whose peak exceeded the ceiling would be caught at
  build time by the `in-place UNSAFE` check — but only at build time, and only if the
  packer is the thing that produced it.
- **The guard hides desync rather than reporting it.** If a stream ever desynced in the
  field, the reader would stop and leave a partial picture with no diagnostic. Nothing
  detects "the decode ended early"; a length check at the end would.
- **The `image_cannot_contain_screen` check is now weaker than it reads.** It asserts
  `INTROSEQ.BIN` (1,763 B) is smaller than a 30,720 B framebuffer. That was a strong
  claim when the screen was raw; now that a screen is 4,936 B on disk it is still true
  but proves less. Flagged rather than changed — the same class of decay as idiom 34,
  and I am not editing a check's meaning inside the task that weakened it.

---

### 8 — Follow-up candidates

- **Option 1, prefetch.** Jay's stated next step. Prolog2 can be prefetched into the
  back buffer during prolog1's hold with no restructuring; prolog1 needs the
  double-buffer contract to stop reserving the back buffer as a clean base, which the
  splash bank has already made affordable.
- **A real fix for `build.bat`'s line endings** rather than a repair per task.
- **A decode-length check** so a desynced stream reports rather than stopping quietly.
- Carried, unchanged: `anim_probe` still spans `$02DC`; the `Demo`/`PrincessScene`
  engine arc; keypress-to-start in `hold_frames`; `HAL_mem_size_detect` a P2.x stub;
  `HAL_gfx_swap` clobbers X and `hal.inc` does not say so; `HAL_gfx_set_palette` a
  P3 stub; the banked-RAM block map.

---

### 9 — User interaction during task

Jay's three messages: *"can we further reduce disk loads with 512KB? do do it jusy
tell me the possibilities"* (answered, no work done), *"can 1 and 3 be done in
128KB"* (answered — and it corrected my previous turn, where I had treated the
absence of free 8 KB blocks as the absence of free memory), and *"lets do 3 first"*.

---

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-07-28-a-green-line-whose-predicate-you-have-not-read-is-not-evidence.md`
(pool commit `98591dc`, pushed).

---

### 11 — Commit

See below — pushed to `origin/wip` before this report was surfaced.
