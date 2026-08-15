## Form B Report — P3.92 — the sand armed on the beat, and a margin that is provisional on a bug

**Class:** build. wip. Prod untouched.

**★★ THE THIN BEAT IS NO LONGER THIN — 1,676 → 6,288 cy. ★★★ AND THE SAVING IS MEASURED AGAINST A
RATE THAT IS ITSELF A DEFECT: fixing the `vb_tick` branch will give most of this margin back, and
saying so is the difference between a measurement and a figure without its scope.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-15T16:09:34-04:00 (HEAD `ac18405`, wip). Karateka untouched. `main` untouched. Oracle
source not read this dispatch. Pre-existing, not mine: `dist/mame-cfg/rgb/coco3.cfg`.

---

### 1 — Summary

| | |
|---|---|
| **§1** | the sand armed on the beat, via **the body's mechanism**, not a second one |
| **★ margins** | exit **4,320 / 1,676 / 7,033 → 8,933 / 6,288 / 12,031 cy** |
| **entry** | **108,890 → 108,903 cy — unchanged**, as it must be: the glass is not up then |
| **speed** | scene mean 6.77 → **6.75 f/play**; scene beat 16 **8.17 → 8.00**, 17 **8.68 → 8.43** |
| **★★ scope** | the saving exists **because of a defect**; fixing it returns beat 17 to ~1,676 cy |
| **§4 gate** | **no visual change** — byte-exact at 44 captures, both sizes. Nothing owed |

### 2 — Files modified

- `src/engine/char_draw.s` — `sc_sdrw`/`sc_sneed`; the body's decision hoisted above the erase

### 3 — Reasoning

**★ §2H's THREE CHECKS** (second dispatch prompted by the restored §7 pointer):

1. **A second mechanism for a different object class?** The dispatch asks the general form — *what
   else in the per-frame path is armed on the frame when its content changes on the beat?* —
   and there is a clear answer: **the characters.** `vm_frameadv`'s draw pass runs on **every**
   iteration while a character's cel changes **once per step**, i.e. every second iteration. It is
   the same shape as the sand, one object class up and far larger. It is **not** removable by the
   same trick — P3.87 established the draw is unconditional because `flicker` repaints the torches
   underneath and the peel is per-buffer — but it is the next place this question points, and it
   should be asked deliberately rather than assumed answered.
2. **The calling routine.** `scenery_frame` ← `chars_frame` ← `room_loop`'s `rl_draw`, once per
   **drawing iteration** — which is the rate that made this waste, and which is why the fix is at
   the content's rate rather than the caller's.
3. **Grep the reports for the subsystem.** Done at P3.91 and it is why this dispatch exists: two
   prior characterisations of `scenery_frame` (*"load-bearing"*, *"a live defect being masked"*)
   had been answered by P3.90 and re-cited twice afterwards. Nothing further stale found.

**3A — THE CHANGE, AND WHY IT IS THE BODY'S MECHANISM AND NOT A NEW ONE.** `sc_sdrw` is to the sand
what `sc_body` is to the body: one byte per buffer naming what that buffer holds. `$FF` for "none"
rather than `0`, because `0` is a real flow frame and a zero-initialised record would claim the
buffer already holds it.

**The body's DECISION moved above the erase; its blit did not.** The sand's decision has to read
`sc_need`, and reading it where it used to sit would have read the *previous frame's* value. The
coupling runs one way only: **a body redraw forces a sand redraw** (the body's stream carries SKIP
runs, so it does not reliably cover the sand's rectangle and assuming either way is how a smear
ships), while **a sand change alone does not need the body**, because the erase restores `flow_peel`
— which is body-over-room.

**3B — ★★ MARGINS, ENTRY AND EXIT SEPARATELY.** 4-frame boundary = 119,436 cy.

| scene beat | before | after | **margin** | f/play |
|---|---|---|---|---|
| 16 | 115,116 | 110,503 | 4,320 → **8,933** | 8.17 → **8.00** |
| 17 | 117,760 | 113,148 | **1,676 → 6,288** | 8.68 → **8.43** |
| 18 | 112,403 | 107,405 | 7,033 → **12,031** | 8.00 → 8.00 |

**Entry: 108,890 → 108,903 cy — unchanged**, and it must be: the hourglass is not on screen during
the entry, so a change to the hourglass cannot touch it. The 13 cy is measurement noise.

**★ The mean barely moves (6.77 → 6.75) and the margins roughly triple.** That is the case for
reporting margins rather than crossings: this change buys almost no visible speed and a great deal
of headroom. The beat Jay accepted at 1.4% clearance now has 5.3%.

**Beat 17's peak is still 126,083 cy**, above the boundary, which is why 5 of its 28 steps still
land on 10 rather than 8. It is better, not clean.

**3C — ★★★ THE SCOPE OF THAT SAVING, WHICH IS THE MOST IMPORTANT LINE IN THIS REPORT.**

The waste being removed — *~56 redraws of an unchanged image per beat* — exists **because the sand
advances once per beat, and that rate is a defect.** P3.91 traced it: `vb_tick`'s flash and sand
blocks sit below a `bne` taken on every play but the last, so both fire once per beat where their
own comments and the oracle say once per play.

**Fix that, and this optimisation largely stops paying.** The sand would change once per step; each
buffer is drawn once per step; so each buffer's record is stale at every visit and the skip never
fires during a `SC_FLOW` beat. **Beat 17's margin would return to roughly its 1,676 cy.**

The cache is keyed on the **value**, not on a rate, so it stays *correct* either way and does not
bake the wrong rate in. But its **worth is provisional on a bug**, and a margin quoted without that
is exactly the "figure without its scope" this project has recorded three times.

**★ The sequencing consequence is Jay's, not mine:** the `vb_tick` fix restores five strobes and a
flowing sand — a defect he reported — and costs back most of what this dispatch just gained. Both
are true at once and neither cancels the other.

### 4 — Verification (AC-by-AC)

- **AC1 sand armed on the beat, using the body's mechanism** — **MET** (3A).
- **AC2 cost as a margin, entry and exit separately** — **MET** (3B), with its scope (3C).
- **AC3 §2H's three checks in §3** — **MET** (head of §3).
- **AC4 suites green both sizes, four coverage windows, stable across separated captures** —
  **MET.** 44 captures: 28 walk, 8 hourglass, 8 exit; `stability: all captures agree (0)`;
  `STABLE` across two runs, both sizes.
- **AC5 build verified by symbol from a freshly baked image** — **MET**: `sc_sdrw = 4060`,
  `sc_sneed = 4062`, `sc_body = 405B`.
- **AC6 no visual change, or reconciled** — **MET: none.** Byte-exact at every capture.
- **AC7 route accounting; sync; Karateka; `main`** — **MET.**

### 5 — Verdict-time evidence (v0.7 §11)

**25.1** `=== BUILD COMPLETE ===`; `[hal-sync] OK`; `[harness-offsets] all checked offsets agree`.
Room, both sizes: `checks=8 passed=8 failed=0`, `78 bytes byte-identical`.
Walk, both sizes: **44 captures, `0 bytes WRONG` at every one**, `beats_visited PASS (19 of 19)`,
`engine_bank_guard PASS`, `page_sig_matched_every_frame PASS`, `stability: all captures agree (0)`,
`STABLE`.

**25.2** N/A — ROM build.

**25.3 NOT OFFERED — nothing visual changed.** The change is output-preserving by construction and
verified byte-exact at 44 captures spanning the hourglass's arrival and its life. Gating unchanged
pixels would spend Jay's attention for nothing. Standing: the flash, the glass and the sand
**PASSED** (2026-08-15); **the slump is observed-unknown** and needs one answer from him (did he run
past ~76 s?); the hourglass-before-flash, the turn disappearance and the exit pace remain **open**.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** The change is the dispatch's and is implemented as specified — the body's
mechanism reused, not a second one. **One thing I added that was not asked for: the scope statement
in 3C.** The dispatch presents the ~56-redraw figure as the waste; it is, today, and it will not be
after a fix that is already follow-up 1. Reporting the margin without that would have handed forward
a number whose basis is a defect — so it is stated as prominently as the number itself.

I also **hoisted the body's decision above the erase**, which the dispatch did not mention. It is
required: the sand's test reads `sc_need`, and in its old position that read the previous frame's
value. The body's **blit** stayed where it was.

Not present: the `vb_tick` fix; the characters' per-iteration draw (3, check 1); the peel; the turn
disappearance.

`hal-sync` OK. Karateka untouched. `main` untouched.

### 7 — Uncertainty flags

- **★★ The margins in 3B are provisional on the `vb_tick` defect** (3C). Fixing it returns beat 17
  to ~1,676 cy. This is the flag to carry forward, not the margin.
- **Beat 17's peak remains 126,083 cy**, above the 4-frame boundary; 5 of 28 steps still land on 10.
- **The warm-up (`SC_WARM`) is shared with the body and was not re-derived for the sand.** A sand
  change forces a redraw anyway on the frame it happens, so the exposure is narrower than the body's;
  it has not been separately tested.
- **The terminal beat still gets no sand advance** (`beq vb_done`), and `cel_plan` marks it
  `SC_FLOW`. Untouched here; it is part of the `vb_tick` fix and needs an oracle trace to settle.
- Carried: the turn-to-exit disappearance; the exit pace; 0.20 s driver overhead; `$2310..$2329`
  blindness; sound sites stubbed as holds — **real audio would consume CPU inside those beats**,
  which is the other reason margin matters more than mean.

### 8 — Follow-up candidates

1. **The `vb_tick` fix** — five strobes, a flowing sand, the glass and its flash together. Fixes a
   reported defect and **consumes most of this dispatch's margin**; those two facts belong in the
   same decision.
2. **The characters' per-iteration draw** (§3 check 1) — the same shape, much larger, and not
   removable the same way.
3. The turn-to-exit disappearance — `ch_h`/`ch_w` and the page signature across `$0E → $0F`.

### 9 — User interaction during task

None.

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-15-an-optimisation-whose-value-depends-on-a-bug.md`

### 11 — Commit

`92a2987` (the change) and this report. Pushed to origin/wip.
