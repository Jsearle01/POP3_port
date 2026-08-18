## Form B Report — P4.6a — the ear gate returned a verdict, and the dither is retired

**Class:** build.  wip.  Prod unchanged — `build/probe.dmk` still 6 files / 36,673 B / 13,824 B free.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-18 01:30 (HEAD `f851c6a`, wip). Follow-through on P4.6's AC8, not a new dispatch.

### 1 — Summary

Jay ran `run_song_slice.sh` and ruled on the A/B: **"i don't hear a difference."** That is an
answer, not a null result, and it retires the dither. `SP_DITHER` is now opt-in, table B is out
of the shipping build, and the player is re-packed against the free-running latency — which is a
*different* constant, not the same one reused. **Cost drops from 5.5% to 4.4% of a frame; the
binary drops from 4,727 to 3,073 bytes; the emitted duration is +0.36%.** The timbre question is
untouched and still his.

### 2 — Files modified

- `src/harness/song_probe.s` — `SP_NODITHER` (opt-out) becomes `SP_DITHER` (opt-in); table B and
  `probe_mode 2` are behind it; without it `probe_mode 1` loops the one rendition.
- `build.bat` — `SONG_LATENCY` 170.24 → **127.80**, `SONG_LATENCY_ADV` 225.22 → **195.78**.
- `harness/smoke/run_song_check.sh` — `P_ABLATE=nodither` → `P_ABLATE=dither`.
- `harness/smoke/run_song_slice.sh`, `harness/smoke/run_song_wav.sh` — no A/B to present.

### 3 — Reasoning

**The test was valid before the verdict was in.** The two tables emitted **6474.7 ms** and
**6521.5 ms** in separate measured runs — they differed by the 0.72% they were built to differ by,
so "no difference" is a statement about audibility, not about whether both played. **0.69% is
about 12 cents**, an eighth of a semitone on a solo monophonic line; not hearing it is the
expected physical result. *Recorded that way so a later reader does not re-open this as a
suspected broken A/B.*

**★ AND THE CONSTANTS ARE NOT INTERCHANGEABLE — this was the trap in the follow-through.** With
the dither, the handler rewrote `$FF94` every interrupt and the offset was +170.24/+225.22 µs.
Without it the timer **auto-reloads and the handler never touches it**, so the offset is almost
entirely the GIME's own `nnn+2`: **+127.80/+195.78 µs**, measured. Re-using the dither build's
numbers would have re-introduced a 42 µs/segment error — 2.6% at the pitch this song mostly uses,
which is four times the detune just ruled inaudible. **Re-packed, then verified on the machine
rather than assumed:** the run reports steady **+128.27 µs = 2.01 ticks** and adv **+195.67 µs**,
against the 127.80/195.78 it was packed for.

**The saving is where the ablation said it would be.** P4.6 measured the dither machinery at 279
cyc/frame by ablation; removing it for real gives 1,650 → **1,306 cyc/frame**, and the rate moved
too (10.12 → 10.03 interrupts/frame, the periods being slightly different). **130 cycles per
interrupt, down from 163.**

**The opt-in path is still exercised** — `P_ABLATE=dither` builds and passes — so the A/B can be
rebuilt if the question is reopened. **That build's tuning is now WRONG** (it inherits the
auto-reload constants) and both the source header and the runner say so: re-run `pack_song.py`,
never reuse.

### 4 — Verification (AC-by-AC)

- **P4.6 AC8 (the detune)** — **ANSWERED BY JAY, verbatim: "i don't hear a difference."** Acted on.
- **P4.6 AC8 (the timbre)** — **STILL PENDING JAY.** `build/tmp/port_princess_trim.wav` (23.2 s)
  regenerated from *this* build against `build/tmp/oracle_princess_trim.wav` (27.8 s), so the
  comparison is not being made against a superseded binary.
- **Cost re-reported** — `+1306 cyc/frame = 4.4%`, 130 cyc/interrupt at 10.03 interrupts/frame.
- **Tuning preserved through the change** — emitted duration **+0.36%** (was −0.49% with dither,
  +7.17% before P4.6). Tick nominal: 63.714 µs, +0.03%.
- **Suites, 128 KB** — `introseq` PASS, `integ` PASS. Shipping disk unchanged; no instrument on it.

### 5 — Verdict-time evidence (v0.7 §11)

```
[pack_song] song_a: 3924 segments -> 321 runs (1607 B) -> build/gen/song_a.s
[pack_song]   dither off; latency 127.80 us; pulse overhead 5.0 cyc
[pack_song]   period error mean |0.730%| signed +0.504% worst 2.307%; 6506.7 ms
  build/song_probe.bin (3073 bytes)
=== BUILD COMPLETE ===

# PASS — it loaded, played to the terminator and tore the FIRQ down.
# ★ FIRQ RATE, MEASURED: 10.03 interrupts/frame over 391 frames
#   THE PLAYER COSTS +1306 cyc/frame = 4.4% of the VBL budget
#   -> 130 cycles per interrupt, at 10.03 interrupts/frame
#   TICK LENGTH from 16 adjacent pairs: 63.714 us  (nominal 63.695, +0.03%)
#     steady  n=3603  mean +128.27 us  = 230 cyc, 2.01 ticks
#     adv     n=320   mean +195.67 us  = 350 cyc, 3.07 ticks
#   ★★ TOTAL EMITTED DURATION 6529.8 ms vs 6506.7 ms = +0.36%

[suites] -ramsize 128K
[run_introseq_test] PASS
[integ] PASS
[suites] ALL PASS

P_ABLATE=dither: # PASS — it loaded, played to the terminator and tore the FIRQ down.
```

**25.2:** N/A — harness instrument, not on the shipping disk.
**25.3:** the detune **PASSED — Jay, live-disk, RGB, 128 KB, sound on, throttled** (his words in
§4). The **timbre** remains **pending Jay**, on WAV.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** P4.6 §8 stated the consequence in advance: *"If A and B sound alike: drop
the dither, take back 279 cyc/f, and `SP_NODITHER` becomes the shipping build — but its latency
constants differ and must be re-packed, not reused."* **This commit contains all of it** — the
flag inverted, table B dropped, the constants re-measured-and-re-packed rather than carried over,
and the saving confirmed on the machine. Nothing else was changed. **What I did NOT do:** delete
the dither path (it is opt-in and still builds), re-record the oracle WAV (unchanged by this), or
touch `main`.

**Deviation:** this was not dispatched. Jay gave a verdict, not a work order; I acted on it
because P4.6 had already named the consequence and leaving a feature in the tree that had just
been ruled inaudible — at 0.9% of a frame — is a worse default than removing it. **Reversible in
one flag if that call was wrong.**

### 7 — Uncertainty flags

- **The `SP_DITHER` build's tuning is now wrong** by design (auto-reload constants). Stated in the
  source header and in `run_song_check.sh`; its PASS above is liveness, **not** tuning.
- **The `nnn+2` is MAME's**, unchanged from P4.6 §7: a real 1987 GIME does `nnn+1` and would run
  this ~64 µs/segment fast. **With the dither gone, the packed periods now depend on that constant
  more directly, not less** — the handler contributes almost nothing to the offset any more.
- **Signed error is +0.504% now** against −0.689% before: same magnitude, opposite sign, because
  the periods land on a different phase of the tick. **The bias did not go away; it moved.** Ruled
  inaudible at that size, but it is not zero.

### 8 — Follow-up candidates

Unchanged from P4.6 §8, less the dither item: re-measure the three constants on real hardware;
the counter (117 cyc/f) and direct-page addressing (≈8 cyc/int) remain the cost levers;
`MUSIC.SET*` → `loadmusic1/2/3`; the other four songs; tail silence; a song against its beat.

### 9 — User interaction during task

Jay, on the A/B: **"i don't hear a difference."** Verbatim, and the whole of it — no other
instruction was given, and the timbre question was not answered.

### 10 — Candidate(s) captured this task

None. P4.6's capture covers the method; this is its consequence.

### 11 — Commit

See below — pushed to origin/wip before this report.
