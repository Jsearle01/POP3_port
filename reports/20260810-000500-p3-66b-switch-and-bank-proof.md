## Form B Report — P3.66b — §2 cannot be measured as posed; §3's mechanism proved instead, and it needs no copy
**Class:** recon (continuation of P3.66 §1). wip. **§2 HARD-STOP #3 — reported, not estimated. §3 de-risked
end-to-end without a `src` change; the banking itself is not built.** Prod untouched.

### 0 — Receipt / status (C-35 stamp)
Continues P3.66 (t0=2026-08-09T22:05:55Z). HEAD at start `3751150`, wip. Sync bridge green. No `src/`,
`content/` or `build.bat` change; the tree's built state is still `8d2dc57`. Karateka and `main` untouched.

---

### 1 — Summary

**§2 as posed cannot be answered, and the reason is structural rather than a shortfall of effort.**
`gfx_map_blocks` — the HAL's remap path — is **not exported**. Its only exported caller, `HAL_gfx_swap`, opens
with `jsr HAL_time_vbl_wait`, which dominates anything the remap costs. Exporting it means editing `gfx.s`, and
that fails the sync bridge (verified P3.46, and a standing hard-stop). **HARD-STOP #3: said, not estimated.**

**But §2's question was shaped by an assumption that turned out to be false — that banking means copying.** It
does not:

> In 4-colour the framebuffer is 15,360 B and occupies CPU **`$8000..$BBFF`**. The draw window is 32 KB. So
> window blocks 2 and 3 — `$FFA6`/`$FFA7`, CPU **`$C000-$FFFF`, 16 KB** — map memory the framebuffer never
> reaches.

A bank block mapped at `$C000` is therefore addressable **at the same time as** the framebuffer at `$8000`. The
blitter reads cels from `$C000+` and writes pixels to `$8000+` in one pass. **No copy, no staging buffer, and the
"switch" is a single masked write to one MMU register rather than a transfer.**

**★ AND THAT IS NOW PROVED ON THE RUNNING MACHINE, not argued.** With the room up, the probe pointed `$FFA6` at
bank block `$0E`, wrote 2 KB through it, and let the scene run on:

- **every byte intact** at the end of the scene — the bank is *usable*, not merely unmapped;
- **the room suite passed 8/8 in the same run**, with `$FFA6` borrowed and written through mid-scene.

So the three things banking needs — free blocks, contents that survive, and a window half that can be borrowed
without disturbing the picture — are all established by measurement.

---

### 2 — Files modified

- `harness/tools/bank_proof.lua` — **new**; stamps a bank block through `$FFA6` and verifies it after the scene.
- `harness/tools/run_block_budget.sh` — runs both probes in one grafted session.

No `src/` change. **Nothing built; no banking implemented.**

### 3 — Reasoning

**3A — Why `$FFA6` can be borrowed at all.** `GFX_DB_BLOCKS` is 4 because the *16-colour* buffer is 30,720 B.
The cutscene is 4-colour, 15,360 B, ending at `$BBFF`. Blocks 2 and 3 of the window are reserved and unused —
`gfx.s:368` says as much ("32 KB reserved per buffer … 4-colour uses 15,360 B of the same reservation"), and this
is the first use anyone has made of the slack. The port's own next `HAL_gfx_swap` calls `gfx_map_blocks` and
rewrites all four registers, so a borrowed register does not even need restoring by hand.

**3B — The evidence, verbatim:**

```
# gfx init mapped the window at frame 1251
# RESULT: $0C-$0F are never mapped: 32 KB free on 128 KB, MEASURED.

# 2048 B stamped into physical block $0E through $FFA6, room running
# RESULT: every byte intact after the scene ran on — the bank is USABLE,
#         not merely unmapped, and borrowing $FFA6 did not disturb the room.

# checks=8 passed=8 failed=0        <- the room suite, in that same run
```

**3C — A FIFTH instrument fault, and this one passed.** The first version of `bank_proof.lua` wrote its pattern
at frame 20, when the firmware's boot map still has blocks `$0C-$0F` at CPU `$8000-$FFFF`. It clobbered DECB's
workspace, the port never loaded — and the probe reported **"every byte intact after the whole scene"** about a
machine that had never run the scene. It was caught only because the *other* probe in the same run said
`gfx init … NEVER — the port never ran`.

That is the same family as P3.66 §3C's four, with one difference worth recording: **the previous four produced
answers that were wrong; this one produced a PASS.** `_bank_verify` now requires the caller to pass evidence the
room came up and reports INCONCLUSIVE without it. A probe that cannot fail is not a probe, and one that cannot
tell "intact" from "never ran" is worse than none.

**3D — What §3 still needs, unbuilt.** The mechanism is proved; the plumbing is not. Cel addressing must become
(bank block, offset) rather than a flat pointer; `bake_scene` must group cels by block and emit that; `co_variant`
must return both; the bank must be loaded once at scene start; and the map must not change between the three
passes — `vm_frameadv` runs erase-all / save-all / draw-all inside one frame, and P3.32's invariant is not
negotiable. **None of that is written.**

### 4 — Verification (AC-by-AC)

- **AC2 switch cost** — **HARD-STOP #3.** Not measurable from the existing path (§1); **not estimated.** The
  operation the design actually needs is a one-register masked write that does not exist yet, and becomes
  measurable when §3 writes it.
- **AC3 banking built** — **no.** Mechanism proved, plumbing not written (§3D).
- **AC4 `Palert` restored** — no; it depends on AC3.
- **AC5** — suites: the room suite passed 8/8 *inside the probe run*, with the window borrowed. No `src` change,
  so the full suite state is P3.65's, unchanged.
- **AC6 `shift_row.s` not wired** — correct, untouched.
- **AC7 Jay gates live** — **not offered.** Nothing in `src/` changed.
- **AC8** — §6 below; sync bridge green; Karateka and `main` untouched.

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output:** `run_block_budget.sh` → the block quoted in §3B, exit 0; `build/block_budget_room.log`
→ `checks=8 passed=8 failed=0`. **No `build.bat` run and none claimed.**

**25.2:** N/A. **25.3:** not offered — the tree's behaviour is byte-identical to `8d2dc57`.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** The dispatch's route was §1 budget → §2 switch cost → §3 build → §5 live gate. **§1 landed
(P3.66). This report contains NO part of §3's build** — it contains a proof that §3's mechanism works and a
finding that §3's design is cheaper than the dispatch assumed. `Palert` is still not restored and no gate is
claimed.

**Deviation from the dispatch's framing, stated because it changes the design and not just the estimate:** §2
asked for the cost of a switch on the assumption that cels must be paged into a working area. The 4-colour
framebuffer leaves half the window unused, so cels can be blitted straight out of a mapped bank block. The
dispatch's question is not unanswerable — it is the wrong question for the design the measurement points at.

### 7 — Uncertainty flags

- **8 KB of the 32 KB was pattern-verified**, not all four blocks. `$0C` is DECB's workspace at boot and `$0D`
  was not exercised; both are *unmapped* by the port (§1) but only `$0E` is *proved to survive*.
- **The borrow was one register for one scene.** A design switching `$FFA6` every beat, mid-frame, is not what
  was tested; the three-pass invariant (§3D) is the specific risk.
- **`$FFA7` (`$E000-$FDFF`) was not exercised.** `$FF00-$FFFF` is always I/O and MC3 pins `$FE00-$FEFF`, so it
  should behave like `$FFA6` — untested.
- The complete scene is still 513 B over the bank as segment streams (P3.66 §1).
- Carried: `$2310..$2329` read-tap blindness; `PlayCut0`'s sound sites; `addcharx` bodiless; `shift_row.s`
  unwired.

### 8 — Follow-up candidates

1. **§3's plumbing** (§3D) — the one substantial piece left, and now de-risked: mechanism proved, no copy needed.
2. Measure the one-register switch once §3 writes it; that closes §2 on the operation that matters.
3. `Palert` — one line in `bake_scene.PLAN` after §3.

### 9 — User interaction during task

Jay: "continue" (twice), directing the dispatch past P3.66 §1's stop.

### 10 — Candidate(s) captured this task

None new — this dispatch's fifth instrument fault is a further instance of
`the-instrument-measured-a-machine-that-was-not-running-the-thing-under-test`, captured at P3.66. Per §2C, live
rows are single-instance and folding is the reconciler's job; the sharper detail (this one reported a PASS rather
than a wrong answer) is recorded in §3C for that fold.

### 11 — Commit

This report and `bank_proof.lua` / `run_block_budget.sh`. `8d2dc57` remains the built state.
