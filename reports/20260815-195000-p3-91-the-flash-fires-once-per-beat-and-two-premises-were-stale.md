## Form B Report — P3.91 — the flash fires once per BEAT, not once per play; and two of this dispatch's premises were stale

**Class:** recon + doc. wip. **No `src/` change.** Prod untouched.

**★★★ TRACED ON THE MACHINE: the glass appears at frame 4186 and its flash fires at frame 4218 —
32 frames, 0.53 s later — and it fires ONCE where the oracle has FIVE. Jay's "the hourglass still
appears before the flash" is exactly right, and the mechanism is a branch. ★★ AND TWO PREMISES IN
THE DISPATCH DO NOT MATCH THE RECORD — reported rather than built on.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-15T15:54:17-04:00 (HEAD `f1fe0a8`, wip). Karateka untouched. `main` untouched. Oracle
source read-only. No `src/` change this dispatch. Pre-existing, not mine: `dist/mame-cfg/rgb/coco3.cfg`.

---

### 1 — Summary

| | |
|---|---|
| **§1** | §7's pointer to §2H's three checks **restored** |
| **★ §2 premise** | **Jay reported no defect in the slump.** *"the three look good."* The qualification is **mine**, about coverage, not his, about a fault |
| **§2** | Pslump renders **byte-correct**; the stale-cel fault was **P3.90's checker**, found and fixed there |
| **★★ §3** | **the flash arms once per BEAT, on the beat's LAST play** — traced. So does the sand |
| **§3 premise** | the every-frame redraw is **not** load-bearing — P3.90 settled that; what remains per-frame is the **sand** |
| **verdict** | the per-frame sand cycle redraws an **unchanged** image ~56 times a beat |
| **25.3** | **no visual change made** — nothing new to gate |

### 2 — Files modified

- `CLAUDE.md` — §7's Form B `### 3` pointer restored
- `harness/tools/port_vbtick_trace.lua` — NEW; the trace that settles the flash and the sand

### 3 — Reasoning

**★ §2H's THREE CHECKS**, as §7 now asks (this is the first dispatch prompted by the template):

1. **A second mechanism for a different object class?** **Yes, and it is the finding.** `vb_tick`
   serves two classes through one branch: the BEAT bookkeeping (`vm_bcnt`, `vm_pend`) and the
   SCENERY events (the flash, the sand). They have different natural rates — per beat and per play
   — and share one control-flow path, which is how the second acquired the first's rate.
2. **The routine that CALLS it.** `vm_beat_tick` ← `vm_nextframe` ← `chars_frame`, on **every
   step**. So the flash and sand blocks are *reached* once per play; it is the `bne` above them
   that spends them once per beat. The caller is not the constraint — the branch is.
3. **Grep the reports for `scenery_frame`.** Done. P3.87 §7 says *"load-bearing and I do not know
   why"* and P3.87 §8 says *"a live defect being masked"*. **Both are superseded by P3.90**, which
   showed the evidence behind them came from a broken diff. This dispatch's §3 inherits the P3.87
   phrasing; the check is what caught it (3C).

**3A — ★★ §3 SETTLED: THE FLASH AND THE SAND FIRE ONCE PER BEAT.** In `vm_beat_tick`:

```
vb_tick   lda vm_bcnt
          beq vb_done          ; terminal beat: skips them entirely
          deca
          sta vm_bcnt
          bne vb_done          ; <-- taken on every play but the LAST
          inc vm_pend
          ...flash block...    ; lda #SC_LIT_FRAMES / sta sc_lit
          ...sand block...     ; sc_flow = (sc_flow + 1) mod 3
```

**Traced** (`port_vbtick_trace.lua`, write taps on `cad_idx`, `vm_beat`, `sc_lit`, `sc_flow` — no
inference between):

```
--- beat 15 begins at step 301 (frame 4186) ---      the glass appears
      lit =3   at step 305 (4 into the beat), frame 4218      the flash ARMS
      lit =2   at step 305, frame 4218                        ...and burns down
      lit =1   at step 305, frame 4221
--- beat 16 begins at step 306 (frame 4224) ---
```

and per beat, over the whole scene:

| beat | plays | flash armed | sand advanced |
|---|---|---|---|
| 15 (the glass) | 5 | **1** | 0 |
| 16 | 16 | 0 | **1** |
| 17 | 17 | 0 | **1** |
| 18 | 12 | 0 | **1** |
| 19 | 28 | 0 | **1** |
| 20 (terminal) | 27 | 0 | **0** |

**Both blocks carry comments saying "once per PLAY".** The branch above them prevents it. Under §2
the source is the trusted default and **the trace wins on fact** — this is that case.

**Three consequences, in the order they matter:**

- **★ Jay's report is confirmed to the frame.** Glass at 4186, flash at 4218 — **0.53 s apart**,
  because the glass goes up when the beat is *applied* and the flash fires when the beat is
  *spent*. He saw the glass appear before the flash because it does.
- **★ There is ONE strobe where the oracle has FIVE.** P3.85 traced the oracle: `lightning` steps
  5→0 once per play at 8-frame spacing. The port's banner has been promising *"five white strobes,
  one per play"* through several gates. It has been delivering one — which is very likely why the
  flash now "looks fine": a single clean strobe reads as deliberate.
- **★★ AND THE SAND IS NEARLY STATIC, WHICH ANSWERS §3.** It advances **once per beat** — once
  across beat 19's 28 plays. Meanwhile `scenery_frame` erases, saves and redraws it on **every
  iteration**: at ~2 iterations per step that is ~56 redraws of an image that changed once.
  **The per-frame sand cycle is not load-bearing for animation; it is redrawing an unchanged
  9×2 image.** Its cost is not costed here, per AC3's ordering — but the defect it was suspected
  of masking is now named, and it is not a masking defect at all.

**The terminal beat gets neither** (`beq vb_done`), so the sand stops flowing for the last 27
plays while `cel_plan` marks that beat `SC_FLOW`.

**3B — §2: THE SLUMP. THE PREMISE IS WRONG AND I AM NOT BUILDING ON IT.**

The dispatch says *"Jay gated the glass and the sand and QUALIFIED the slump"* and asks me to
*"establish what is wrong with `Pslump` … something specific is off and it is visible."*

**Jay's words were: *"the three look good."*** He reported **no** defect. **The qualification is
mine, and it is about observation coverage, not about a fault**: I measured that the run I observed
closed at ~75 emulated seconds and that the slump begins at f4538 ≈ 75.6 s, so on that run it was
not reachable. I recorded it as *observed-unknown* rather than passed. That is the opposite of a
reported defect, and treating it as one would manufacture a fault out of my own caution.

**What I can establish without him:**
- **Pslump renders byte-correct.** Walk captures 43 and 44 land on it and report **0 bytes wrong**
  against an independently composited expected picture, both memory sizes, stable across two runs.
- **The stale-cel fault was the checker and it is already fixed** — P3.90 found `verify_room_chars`
  reading `pslump_src.s` for cel 18 where the bake emits `p18_src.s` (2,699 B against 2,755), which
  produced 27 phantom wrong bytes **in the shipping build too**. Fixed there; 0 wrong since.

**★ So the checker fault and the "qualification" are NOT the same finding.** The checker fault was
real, was in the checking, and is closed. The qualification is a gap in what Jay had on screen. The
only thing that can close it is Jay, and the question is one line: **did you run it past ~76
seconds?** Per §6.2 it goes back to him rather than being closed by argument.

**3C — ★★ THE OTHER STALE PREMISE, AND WHY IT IS WORTH A PARAGRAPH.** §3 asks me to *"establish
WHY the every-frame redraw is load-bearing"*, quoting P3.87. **P3.90 established it is not** — write
taps showed both builds doing identical work, the walk suite passed both, and the split shipped and
was gated. The phrase is a P3.87 characterisation that outlived its evidence by two dispatches.

I answered the question the tree actually poses — *what does the remaining per-frame scenery work
accomplish?* — and it turned out to be the more useful question (3A). **This is §2H's third check
doing its job on the dispatch rather than on the source**, which is a use I did not expect it to
have.

### 4 — Verification (AC-by-AC)

- **AC1 §7's pointer restored** — **MET**, commit `e33e5bd`. Sections unchanged otherwise.
- **AC2 the slump's qualification resolved** — **PUT BACK TO JAY** (3B), with what was and was not
  reproducible, and the checker fault reconciled with it: separate findings, one closed, one his.
- **AC3 `scenery_frame`'s defect established; removal not costed** — **MET** (3A). The every-frame
  redraw is **not** masking a defect; the defect is in `vb_tick`'s branch. **No cost figure given.**
- **AC4 §2H's three checks stated in §3** — **MET** (head of §3), first dispatch prompted by the
  template.
- **AC5 suites green both sizes; build verified by symbol** — **MET.**
- **AC6 Jay gates live if anything visual changed** — **N/A: nothing visual changed.**
- **AC7 route accounting; sync; Karateka; `main`** — **MET.**

### 5 — Verdict-time evidence (v0.7 §11)

**25.1** `=== BUILD COMPLETE ===`; `[hal-sync] OK`; `[harness-offsets] all checked offsets agree`.
Symbols from the freshly baked image: `sc_body = 4011`, `sc_flow = 4008`.
Room, both sizes: `checks=8 passed=8 failed=0`, `78 bytes byte-identical`.
Walk, both sizes: **44 captures, `0 bytes WRONG` at every one**, `beats_visited PASS (19 of 19)`,
`STABLE`.

**25.2** N/A — ROM build.

**25.3 NOT RE-OFFERED. Nothing visual changed this dispatch**, so there is nothing new to gate and
gating unchanged pixels would be spending Jay's attention for nothing. Standing: the flash, the
glass and the sand **PASSED** (2026-08-15); **the slump is observed-unknown** and needs one answer
from him; the hourglass-before-flash, the turn disappearance and the exit pace remain **open**.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** I proposed nothing and shipped nothing beyond the pointer and the trace tool.
**Two dispatch premises were declined rather than executed**, both reported with evidence:

- **§2's "something specific is off and it is visible" in Pslump** — no defect was reported by Jay
  and none is visible to the suite. **I did not go looking for a fault to match the premise.**
- **§3's "establish why the every-frame redraw is load-bearing"** — it is not, per P3.90. I answered
  what the remaining per-frame work does instead.

**A fix is NOT included and that is deliberate.** Moving the flash and sand blocks above the `bne`
would give five strobes and a flowing sand — a **visual change to a gated scene**, which this
dispatch did not authorise (§3 asked to *establish*). It is a one-block move and it is follow-up 1.

Not present: any `src/` change; the sand's per-frame cost; the peel; the turn disappearance.

`hal-sync` OK. Karateka untouched. `main` untouched.

### 7 — Uncertainty flags

- **★ Whether five strobes is right for the PORT is established for the oracle, not re-derived
  here.** P3.85 traced `lightning` 5→0 at 8-frame spacing; I am relying on that trace, not a fresh
  one. Its scope: the oracle's hourglass beat.
- **★ The terminal beat's sand** — `cel_plan` marks it `SC_FLOW` and `vb_tick` never reaches the
  block for it (`beq vb_done`). Whether the oracle's sand runs through its final hold is **not
  traced**; a fix must decide it rather than assume.
- **The slump is observed-unknown**, not passed, and only Jay closes it.
- **`sc_lit` counts down through the same byte it is armed with**, so a naive tap counts the
  countdown as arming — noted because the first cut of the trace did exactly that and read 3 arms
  where there was 1.
- Carried: the turn-to-exit disappearance; the exit pace (8.17/8.68/8.00); the thin margin
  **accepted by Jay**; 0.20 s driver overhead; `$2310..$2329` blindness; sound sites stubbed as
  holds.

### 8 — Follow-up candidates

1. **Move the flash and sand blocks above the `bne`** — five strobes, a flowing sand, and the glass
   and its flash arriving together. Fixes a defect Jay reported. Needs a decision on the terminal
   beat and a live gate.
2. **Then** cost the sand's per-frame cycle, which only makes sense once its real change rate is
   the intended one.
3. The turn-to-exit disappearance — `ch_h`/`ch_w` and the page signature across `$0E → $0F`.

### 9 — User interaction during task

None during the task. Jay's *"the three look good"* preceded it and is quoted in 3B.

### 10 — Candidate(s) captured this task

- `seeds/POP/live/2026-08-15-two-rates-through-one-branch.md`

### 11 — Commit

`e33e5bd` (the §7 pointer), `cc97ff2` (the trace tool + this report). Pushed to origin/wip.
