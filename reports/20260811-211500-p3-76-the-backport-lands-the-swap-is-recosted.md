## Form B Report — P3.76 — the back-port lands and pays; the swap's precondition was my own error
**Class:** build (§1, complete) + recon (§2, corrected and measured). wip.
Prod untouched. **§3–§6 not reached; nothing half-built.**

### 0 — Receipt / status (C-35 stamp)
t0=2026-08-11T20:23:47-04:00 (HEAD `6f28e2c`, wip). Now at `d19e105`.
**Karateka `wip` `ac2b768`; its `main` untouched at `5eb92b1`.** Sync bridge green. Tree green
and nothing left half-applied (§5).

---

### 1 — Summary

**§1 is done, measured, and pays: startup 9.27 s → 8.47 s.** The conditional spin-up is
back-ported to both repos byte-identical, the cold path is verified **as an artifact** rather
than asserted, and Karateka's own suites are green.

**§2 stopped at recon, and it should have: two claims in my own P3.75 design were wrong.** The
runtime mirror is **not** a precondition, and the argument I gave for pinning was about the
wrong quantity. Both were caught before a line of the packer was written. **The measurement the
build actually needed — where the scene can be CUT — is now taken and the schedule is clean.**

**§3–§6 not reached.** The remaining work is a packer, a link-script split, per-beat mapping, a
draw-time assertion, two staged reads and six beats; I stopped rather than start it at this
depth.

---

### 2 — Files modified

- **`c492257`** — `src/hal/coco3-dsk/disk_read.s` (the conditional spin-up, +38/−0),
  `src/engine/cutscene_room.s`, `src/engine/intro_seq.s` (release the drive through the HAL,
  and once instead of per read), `harness/tools/load_timing.lua` (relabelled, §3C).
- **`d19e105`** — `harness/tools/epoch_residency.py`, new: per-epoch resident sets.
- **Karateka `ac2b768`** (its `wip`) — the same HAL file, byte-identical.

### 3 — Reasoning

**3A — The back-port, and why it is safe.** Purely additive: **38 insertions, 0 deletions.**
`dr_motor_on` sits at `$FE01`, in the constant page beside `dr_nmi_done`, so MC3=1 keeps it
present through every MMU remap a caller performs — the flag has to outlive exactly the thing
the swap design will be doing to the window. New export `disk_read_motor_off` clears `DSKREG`
and the flag together, because a caller that pokes `DSKREG` itself would leave the flag
claiming a motor that had stopped.

**The invariant is enforceable because it was checked first**: Karateka has **no** direct
`DSKREG` writer, POP had two, and both moved in the same commit.

**3B — The cold path, verified as an artifact.** *"Purely additive"* is a claim about the
binary, so I measured the binary — Karateka's own `run_disk_sandbox.sh`, before and after:

```
spin-up    0.4394 -> 0.4395 s      Restore   0.0061 -> 0.0061 s
per-track  3.1943 -> 3.1943 s      FDC cmds  00 x1, 10 x8, 90 x8, D0 x9   identical
WORST-CASE LOAD: PASS both, 144/144 sectors byte-for-byte
```

The 0.1 ms is the four added instructions (~15 cy). In POP, load 1 still takes **exactly 174
frames**. *(Karateka's sandbox reads JVC fixtures at 3.19 s/track — the pre-DMK figure — which
independently confirms P3.6's interleave finding and why POP's DMK build reads at 1.20.)*

**3C — ★ THE HAL CHANGE ALONE SAVED NOTHING, AND THE MEASUREMENT CAUGHT IT.** First build came
back at **9.27 s, unchanged to the frame**. `load_tracks` released the drive after *every* read,
clearing the flag before the next could benefit. **Necessary and not sufficient** — and
indistinguishable from "the change doesn't work" without the timing probe.

The release moved out of `load_tracks` to a single call after the last read: the caller owns
the drive's lifetime because only the caller knows when it has finished reading.

```
load 1   174 frames   (cold — unchanged)
load 2   108 -> 84    (-0.40 s)
load 3   252 -> 228   (-0.40 s)
EXEC -> room   556 -> 508 frames,   9.27 -> 8.47 s
```

**0.40 s per warm read against `dr_spinup`'s 393,216 cy at 0.894 MHz = 0.44 s theoretical.**
That agreement is the best evidence the mechanism does what it claims rather than something
else that happens to be faster.

**And it exposed the second symptom with a number:** 0.20 s of per-call overhead REMAINS on the
warm reads — the unconditional `FDC_RESTORE` to track 0 plus the seek back out. The driver
still does not remember where its head is. Not fixed; flagged, measured. `load_timing.lua`'s
second term was relabelled accordingly: it is per-call overhead, and only spin-up when cold.

**3D — ★★ THE MIRROR IS NOT A PRECONDITION. My P3.75 §3D was wrong.** It claimed *"without it
`Pback`'s set does not fit a rotating block."* Measured:

```
Vraise  1,979 B   p12 v50 v67          Vexit   2,019 B   p18 v50 v62
Pback   2,028 B   p18 v50 v75          Pslump  1,334 B   p18 v53
```

Two or three variants at a time against a **7,680 B** rotating block. **I had conflated
`Pback`'s LIVE SET (2,028 B) with the loaded-total INCREMENT from P3.74 (9,538 B)** — the
latter being Vraise+Pback's cels plus their phase variants. **Same wrong-layer error this
session already filed a candidate about, and the third instance of it today.** At some point
that stops being a lesson and becomes a property of this content: three quantities, same units,
all comparable to the same window, and nothing in the number says which one it is.

What the mirror actually buys is capacity — 5,155 B, turning the mid-scene read from two tracks
into one, ~1.2 s less freeze. Optional, and the most delicate change available: `blit_cel`'s
blast half cannot use the stack trick (`pshs`/`pulu` preserve within-group order) and needs a
byte-at-a-time loop against a 256-byte reverse table.

**3E — And "live at both ends" was true of the wrong thing.** The per-variant spans show only
`v50` live at `Pback`, not all six walk cels — because **with baked mirrors the exit's walk-out
is different data entirely.** `Vexit → Vwalk2` reuses the cel NUMBERS and none of the baked
BYTES. That is an argument *for* the mirror; it is not the argument I made for pinning.

**3F — The measurement the build needed, and it is clean.** Per-step live sets say a swapped set
can be small; they do not say where the scene can be **cut**. `epoch_residency.py` answers that:

```
cut at                      RETIRED    CARRIED   ARRIVING
step 192  end of s_Vizier    4,681      6,769     25,397
step 229  his second stop   10,152      1,376     25,319
step 248  before Vexit      21,998      1,940     12,909
```

**At the end of the `s_Vizier` hold, 4,681 B is retirable and it is EXACTLY her eight turn cels
`p2-p9`** — last drawn at step 125, never again. By his second stop, 10,152 B. So the 7,936 B
that cannot fit the bank arrives as **two reads, one in each of `s_Vizier` and `s_Buildup`**,
landing over content provably finished. Both are song holds. **`s_Buildup` is a beat the oracle
has and the port has not built** — so the schedule and the beat list are the same task.

### 4 — Verification

**25.1 fresh tool output (verbatim, at `d19e105`):**
- `build.bat` → `cel_image.raw: 12922 B flat image based at $C000` → `tracks 11..13 (902 B pad)`
  / `=== BUILD COMPLETE ===`
- `run_room_test.sh` → `checks=8 passed=8 failed=0` / `PASS`
- `run_walk_test.sh` → `first movement at frame 2522 (+811 held frames)`;
  `bank_mapped_at_every_capture PASS (0 of 28 captures unmapped)`; `modal gap 6 frames`;
  `STABLE`; `PASS`
- `hal_sync_check.py` → `OK -- HAL source aligned with karateka_coco3 (11 files compared)`
- At `c492257`, both sizes: room 8/8 and walk PASS at 128 KB; intro `checks=17 passed=17`
- **Karateka:** `build.bat` → `=== BUILD COMPLETE ===`; `run_smoke.bat` → `PASS`;
  `run_disk_sandbox.sh` → `WORST-CASE LOAD: PASS`

**The instrument was checked for what it writes** (P3.71): `load_timing.lua`,
`midscene_read.lua` and `epoch_residency.py` are read-only against the machine;
`epoch_residency` bakes into a scratch directory outside the repo. The tree was re-verified at
**12,922 B / 19 includes** after every sweep.

**25.2:** N/A. **25.3:** **not offered.** The scene is unchanged from the one Jay gated
("that looks awesome"); §1 changes only load timing, and the complete arc §6 wants does not
exist yet. Offering the same scene again would spend his time on nothing new.

### 5 — Acceptance criteria

1. **Back-port applied to both repos byte-identical; Karateka green; cold path verified as an
   artifact; `hal_sync_check` green; Karateka `main` untouched** — **yes**, §3A/3B/4.
2. **Runtime mirror built, then pin-and-rotate** — **no.** The premise was wrong (§3D) and the
   order it implies is not the right one; recon done instead.
3. **Draw-time assertion** — no. 4. **Mid-scene read** — no, but its schedule is measured (§3F).
5. **Beats landed** — no. 6. Suites green (§4). 7. **Tree stated** — green, nothing half-built.
8. **Gate** — not offered, with reason (§4).

### 6 — Route accounting

The dispatch authorised §1 then §2–§6. **This contains §1 complete and §2's recon, and stops
there.**

**Two reactive deviations, both reported rather than taken silently:**
- **The build order was not followed.** §2 says *"the runtime mirror is a PRECONDITION… Build it
  first."* That instruction rests on my own P3.75 §3D, which §3D above disproves. I did not
  build the mirror first, and I did not build pin-and-rotate in its place either — I stopped and
  said so.
- **§1 needed a POP-side change the dispatch did not name** — moving the drive release out of
  `load_tracks`. Without it the back-port measurably does nothing (§3C).

Not present: mirror, packer, link split, per-beat mapping, assertion, staged reads, beats,
hourglass, 16c swap, `Prolog2`. No gate claimed.

### 7 — Uncertainty flags

- **The 0.20 s residual per-call overhead is attributed to Restore+seek by elimination**, not by
  isolating it. It should be measured directly before anyone sizes the head-tracking work.
- **`epoch_residency` uses the interval model**, which is pessimistic: a cel is charged from
  first draw to last even when idle between. Real retirement could free more, not less.
- **Its byte totals come from `beat_recost`'s per-cel bake (36,847 B), not the linked image
  (39,680 B).** The linked figure is authoritative for what must sit in the bank — table and
  per-cel overhead included — so the shortfall is **7,936 B**, not the 5,103 the tool prints.
  The tool should be re-pointed at the linked artifact.
- The two staged reads assume `s_Buildup` is implemented as a hold of measurable length; its
  duration has never been traced off the oracle.
- Carried: the `$2310..$2329` read-tap blindness; `PlayCut0`'s remaining sound sites.

### 8 — Follow-up

1. **The build, in the corrected order:** link-split → per-beat mapping + assertion → the two
   staged reads → the beats. §3F is its schedule.
2. **Trace `s_Buildup`'s duration** off the oracle — the second read has nowhere to hide without it.
3. The mirror, after the beats, as a freeze reduction rather than a precondition.
4. Re-point `epoch_residency` at the linked image (§7).

### 9 — Candidate captured

None new. §3D is a third instance of
`seeds/POP/live/2026-08-11-name-which-layer-a-number-belongs-to.md`, already filed today; the
right move is to strengthen that row at reconcile time, not to file a near-duplicate. Its own
proposed fix — make the tool print all three layers — is what would actually have stopped this.

### 10 — Commit

`c492257`, `d19e105` (POP, pushed to origin/wip); `ac2b768` (Karateka `wip`, pushed). This
report follows.
