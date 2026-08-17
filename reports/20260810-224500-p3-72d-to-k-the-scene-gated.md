## Form B Report — P3.72d–k — the scene passes Jay's live gate
**Class:** build. wip. Prod untouched. **25.3 GATED — Jay, verbatim: "look great".**

### 0 — Receipt / status (C-35 stamp)
Interactive continuation of P3.72 under Jay's direction. HEAD `0204823`, wip, ten commits since
`d609b18`. Sync bridge OK. Karateka and `main` untouched.

---

### 1 — Summary

**The gate passed.** Live-disk, RGB, 99.99% speed, motion watched running. **Jay's words: "look great"** —
and earlier in the same pass, on the princess specifically: **"she looks good now"**. Not self-certified.

Seven defects fixed, every one found by measurement or by Jay's eye, **and four of the seven were mine from
earlier in this same session.**

| | was | now |
|---|---|---|
| step cadence (anchor was an instrument artefact) | 3.83 f/step | **6.00** = the oracle |
| her turn | 39% fast | 11% slow |
| she drifted through the turn | col 36 → **40** | col 36 → **35** (oracle: −3 px) |
| her mirrored colours | orange/blue **transposed** | matches her unmirrored cel |
| dead room before the flames | **~10 s** | none |
| flame rate | 10.0 Hz | **21.7 Hz** (oracle 26.2) |
| the scene's opening | started mid-turn | **7-play lead-in**, as the oracle |
| his entrance | one unbroken stride | **two stages with a stop** |
| cel image | 13,639 B | **12,922 B** — smaller, with more scene in it |

---

### 2 — Files modified

Ten commits, all pushed. `a6c7d45` oracle Palert rate · `41d804f` cadence re-anchor · `9076903` oracle live
runner · `5a6e6d4` lead-in + anchor measured · `dfde131` cel read moved before the mirror · `f0ffdc0` the
mirror anchor · `1c6309a` the parity flip · `ac83fe5` flame rate verified + bank wall · `14c453f` two-stage
entrance fits · `0204823` flames decoupled.

Touching `src/engine/{char_draw,cutscene_room}.s`, `harness/tools/{bake_scene,gen_cel_table,cel_parity_rule,
beat_recost,verify_room_chars,verify_room_flicker}.py`, `harness/smoke/{walk_test,room_test,run_walk_test,
run_room_live}.*`, new `harness/tools/{oracle_palert_rate,oracle_palert_shift,port_flame_rate,peel_trace,
erase_trace}.lua` + runners, and the regenerated `content/cutscene/{cel_table.s,chars/*}`.

### 3 — Reasoning

**3A — The cadence anchor was an instrument artefact, and finding that unlocked the rest.** `char_draw.s`
tuned `cad_tab` to *"the oracle's measured 3.9"*, which came from `oracle_flame_rate.lua` on the premise
*"the flames advance once per play iteration."* **Measured false:** over f2688–f5560 the flame box changes on
a 2–3 frame cycle continuously, straight through stretches where the play period is plainly 6–7. It was
measuring flame flicker.

So I measured the thing itself. Her turn is **self-identifying** — she is static for the whole scene except
that one beat, so it shows as an isolated burst of exactly nine changes (cel 11 → 2..9 → 11):

```
oracle  f3487-f3530  gaps 5 5 5 6 6 5 5 6   mean 5.38 f/cel
port                 gaps 4 4 4 3 4 4 4     mean 3.86 f/cel
```

**Jay was right by 39%.** Re-anchored to a flat 6 — flat because the oracle's approach is a steady 6 with no
spread, so P3.57's spread was compensating for the wrong target, and with every entry equal its
rotating-limp failure mode becomes structurally impossible rather than merely avoided.

**3B — The mirror anchor: `aboutface,chx,N` is registration, not movement.** `MLayGen` does
`LDA XCO / SEC / SBC WIDTH` [HIRES.S:1202-1208] — a mirrored image is laid one sprite-width LEFT — so the
`chx` cancels the flip. Cel 11 is 3 Apple bytes = 21 px against `chx,9` = 18 px, net **−3 px**. Confirmed on
the oracle *before building*: across her turn only 21 px of columns differ, where a real 18 px shift would
have spanned ~58.

The width now comes down in `cel_table` (+4, from the image table itself), the record's **dead** `CH_W`
becomes `CH_AWID`, and `co_setup` subtracts 7×AWID **in pixels** — before the /4, because 7 px per Apple byte
is not a multiple of the 4 px CoCo byte.

**Two things this broke, both caught by measurement:** the phase (`co_variant` derives it from the same
position; anchoring only `co_setup` made it look up a phase the bake had not written, hit the table's 0, and
**the null-cel guard silently stalled her** — the record showed the turn completing while `ch_drawn` froze at
cel 9), and the erase (`co_setup`'s inputs now include facing and width, so `co_erase` was applying today's
anchor to yesterday's footprint — the P3.72b defect one field along).

**3C — The parity flip, which no suite could ever have caught.** The rule is `--flip-parity` iff
`width_pixels = apple_width_bytes * 7` is even. The bake tested `(coco3_width * 4) % 2` — **even for every cel
that can exist** — so it flipped unconditionally, under a comment claiming it was measured. Proven by
histogram: flipped `orange=126 blue=34`, correct `orange=34 blue=126`, identical to her unmirrored cel.

★ `verify_room_chars` composites its prediction from the same source the engine blits, so a wrongly-flipped
bake makes **both sides wrong together** and the check passes byte-exact — as it did, 28 captures, before and
after. **Two independent-looking checks sharing one input are one check.** Only an eye on the running machine
could see this, which is exactly the case CLAUDE.md §4 reserves for Jay.

**3D — Ten seconds of dead room, and it was mine.** `HAL_gfx_mirror` writes the finished room into the FRONT
buffer, so the picture appears at the *mirror*, not the swap. I put the three-track cel read after it at
P3.71 — the exact bug this file warns about two paragraphs above the site. My stated reason was also wrong:
the mirror maps the *front buffer's* blocks at `$FFA6`/`$FFA7` while the bank's `$0E`/`$0F` stay unmapped and
untouched. Same CPU addresses, different physical memory.

**And `startup_gap_small` reported `0.03 s` before and after** — it times from the swap, so ten seconds of
dead room in front of Jay passed it.

**3E — The bank wall that wasn't (Jay's question did this one).** The faithful two-stage entrance bakes to
19,288 B against 15,872 B usable — over by 3,416. Not the two extra plays: the stop shifts his x by an **odd**
number of CharX units, so every walk cel lands on the opposite phase and needs a second bake. I reported the
boundary and pointed at `shift_row.s`.

Jay: *"would it be possible to stop him at a slightly different x so we could reuse cels?"* The phase is
`(2*(x+Fdx)+par) mod 4`, so an **even** shift preserves it:

```
app1=6 app2=30   pauses CharX 186   ends CharX 135   18 viz bakes   <- the oracle
app1=7 app2=29   pauses CharX 185   ends CharX 135    9 viz bakes   <- shipped
```

**One CharX unit is two Apple pixels.** Total travel and final position identical; only the pause moves, by
half a byte-column. 19,288 → **12,922 B**, which is 717 B *smaller* than the single-approach version it
replaces. **The wall was a one-unit alignment problem and I had framed it as structural.** `shift_row.s`
stays parked.

**3F — The flames, decoupled.** `room_loop` gated on `chars_due`, so the torches ran at the *character* step
rate — which my own re-anchor had dragged from 15.7 Hz to 10.0. No change to `char_draw` was needed:
`chars_frame` is already `vm_nextframe` (decides) + `vm_frameadv` (draws), and the decide gate gets asked more
often without stepping more often. The room paces on the torch instead. The whole loop moves because a 26 Hz
flicker needs a 26 Hz swap.

**Draw-bound at ~2.7, measured not assumed:** a `2,2,2` table achieves 2.7 and `2,2,3` achieves 2.8. `2,2,3`
ships because it is the oracle's measured distribution rather than a value chosen to cancel today's overrun —
a minimum tuned to an overrun goes wrong when the overrun changes, which is how `cad_tab` reached 3.83.

### 4 — Verification

**25.1 fresh tool output (verbatim, at `0204823`):**
- `build.bat` → `flames.raw: 4500 B` / `cel_image.raw: 12922 B flat image based at $C000` → `tracks 11..13
  (902 B pad)` / `=== BUILD COMPLETE ===`
- `run_room_test.sh` → `checks=8 passed=8 failed=0`; `PASS room intact outside the torch boxes`;
  `PASS flames flicker`; `PASS flame pixels are exactly cel 3/4`; `PASS`
- `run_walk_test.sh` → `bank_mapped_at_every_capture PASS (0 of 28 captures unmapped)`;
  `modal gap 6 frames` (the character rate, unchanged by the flame decoupling); all 28 `0 bytes WRONG`;
  `STABLE`; `PASS`
- **128 KB:** room `checks=8 passed=8 failed=0` / `PASS`; walk `PASS`
- `run_introseq_test.sh` → `checks=17 passed=17 failed=0` / `PASS`
- `hal_sync_check.py` → `OK`
- `port_flame_rate.lua` → `mean 2.8 frames = 21.7 Hz` against the oracle's `2.3 = 26.2 Hz`

**Bank occupancy: 12,922 of 15,872 usable = 81.4%.**

**25.2:** N/A. **25.3:** **PASSED — Jay, live-disk, RGB, LIVE (motion, 99.99% speed). Verbatim: "look
great"**, and on the princess mid-pass, *"she looks good now"*. Not self-certified.

### 5 — Route accounting

Jay drove this interactively; there was no dispatch spec. Each ask and what it produced: measure the oracle →
done, and it invalidated the existing anchor; re-anchor the cadence → done; add the pre-turn portion → done;
fix her forward drift → done; her colours → done; verify the flame rate → done, then fixed on a second ask;
the vizier's stop → done, via his own suggestion after I reported it as over budget.

**What this does NOT contain:** the four un-stubbed `PlaySongI` sites, and `Vraise` / `Pback` / `Vexit` /
`Pslump` / the 16-colour swap / the `Prolog2` handoff. Nothing was claimed for them.

### 6 — Uncertainty flags

- **Two known timing gaps, both the same cause.** The oracle's `PlaySongI` **blocks**, so her opening pause is
  ~13.3 s (measured f2688→f3487) and the port's is 0.7 s, and his entrance pause should carry the `s_Vizier`
  cue. The four un-stubbed sound sites are **timing, not just audio** — stubbing them to silence deleted beats
  the scene is built around.
- **Flames sit at 86% of the oracle's rate.** The remaining 14% is per-iteration work, not a table value.
- **`ch_last` has no spare bytes left** (+5 facing, +6 Fdx, +7 sprite width). The next per-buffer draw-time
  fact needs a wider entry.
- **`startup_gap_small` measures the swap, not the reveal** (3D). It should be re-pointed.
- The peel matrix is still unrun on the banked build.
- Carried: hourglass 856 B over; 513 B over the 32 KB bank for the complete scene; `$2310..$2329` read-tap
  blindness; `shift_row.s` assembled and unwired — **not** forced by this work.

### 7 — Follow-up

1. **The song stubs as timed waits** — measure all four `PlaySongI` durations off the oracle. This is the
   biggest remaining gap between the port and what Jay watched.
2. `Vraise`, `Pback`, `Vexit`, `Pslump`, 16c swap, `Prolog2`. `Vexit` ends `aboutface,chx,16` — the mirror
   anchor is already in place for it, and the phase-alignment lever from 3E applies to its `chx` too.
3. Re-point `startup_gap_small`; re-run the peel matrix.

### 8 — Candidate captured

`seeds/POP/live/2026-08-10-a-vacuously-true-guard-reads-as-a-careful-measurement.md` — pushed. A conditional
that cannot be false is worse than none, because it wears the appearance of a check; and two
independent-looking checks sharing one input are one check.

### 9 — Commit

`a6c7d45` … `0204823` (ten), all pushed to origin/wip. This report follows.
