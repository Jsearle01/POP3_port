## Form B Report — P3.46b CORRECTION — the oracle DOES burn torches during `play`; §3D was my misreading, and it makes the plan simpler
**Class:** correction (recon). wip. No build, no `src/` change. Prod untouched.

### 0 — Receipt / status (C-35 stamp)
Follows P3.46 within the same session on Jay's live observation, so the standing receipt is P3.46's:
t0=2026-08-09T04:15:25Z. HEAD at this report = `7e73f18`, wip, tracked tree clean. Sync bridge green.
Oracle image verified byte-identical before and after the run: `c4f0b13e49b77dd0fbc5063e27e53a24`.

---

### 1 — Summary

**Jay ran the oracle and reports: "they look to flicker when he walks."**

**P3.46 §3D is WRONG and is withdrawn.** It claimed *"`pburn` is not called from `play`... the oracle never runs
both at once."* It does. The chain is:

```
play → playloop → FrameAdv → DoFast → jsr pburn / jsr pburn / jsr pstars / jsr drawall / jmp pflow
                            → vblank → PageFlip
```

`DoFast` is **SUBS.S:967**; the `pburn` pair is at **:1002-1003**, *inside* it. `FrameAdv` is
`jsr DoFast / jsr vblank / jmp PageFlip`. **The torches, stars, sand, hourglass and characters are all drawn in
one pass, into the hidden page, once per animation step, followed by one page flip.**

**And there was never a source/trace conflict — only my misreading**, which is worth stating precisely because
the failure is reusable (§3B): I grepped `pburn`'s call sites, saw `:1002-1003` with the comment
*"first put down 2 torch flames"*, read that as one-time scene setup, and **never checked which routine those
lines were inside.** A grep returns line numbers; **the enclosing routine is the fact, and I did not get it.**

**The comment does not even say what I took it to say.** `pburn` burns **one** torch per call, alternating via
`ptorchcount`. Two calls = two torches. *"first put down 2 torch flames"* is an **ordering** note — both flames
before `drawall` — inside a per-frame routine. Not setup.

**P3.26 was right all along.** Its *"the flames advance once per `play` iteration, so the gap between flame
updates IS the step interval"* is exactly what `DoFast` does. P3.46 §3D "corrected" a correct measurement
against a misread of the source. **That inversion is the part worth remembering.**

**★ THE CORRECTION MAKES THE PLAN SIMPLER, NOT HARDER.** The oracle's structure is now unambiguous and it is
precisely what A1 would give POP:

| | oracle | port today |
|---|---|---|
| what advances the torch | **one `pburn` per animation step** | `fl_div`, an independent divider, per **loop iteration** |
| where torches are drawn | **hidden page, with everything else** | back buffer, with everything else ✓ |
| flips per step | **one** | **one per video frame** |

- **A2 (direct-to-front) is UNNECESSARY.** The oracle does not draw torches to the displayed page during the
  cutscene — it draws them into the hidden page in `DoFast` and flips once. **The governance blocker in
  P3.46 §3C.2 no longer needs a ruling, because the mechanism it would have authorised is not wanted.**
  (`pburn`'s `jmp lay` *is* a direct call in the **`PlaySong`** music beats, which have no flip. Both are true,
  in different beats. The cutscene is the `play` path.)
- **A3 is now SPECIFIED, and its defect is bigger than a unit error.** The torch cadence should be **the
  animation step**, not an independent divider. `FLAME_DIV equ 3` is wrong on the **unit** (P3.45: it counts
  loop iterations, not VBLs) *and* on the **concept** (there should be no divider at all).
- **A1 alone now reaches the target**, because with the torches on the animation step there is exactly **one
  change source**. P3.45's *"the torches drag a full flip"* — the reason change-gating stalled at 157% —
  **disappears.**

**The arithmetic, on measured figures:** everything on one animation step = **57,074 cy** against
**2.60 × 29,673 = 77,150** → **74%. It fits**, with no MMU work, no HAL change, no tearing, and no
sync-bridge amendment.

---

### 2 — Files modified
- `reports/20260809-044512-p3-46b-correction-dofast.md` — this report.

**No `src/` change.** The oracle was run from a scratch copy (`build/oracle_run.hdv`); the vendored image is
untouched and re-verified.

---

### 3 — Reasoning

#### 3A — The chain, read completely this time

- **`FrameAdv`** (SUBS.S, immediately above `DoKid`): `jsr DoFast` / `jsr vblank` / `jmp PageFlip`.
- **`DoFast`** — label at **SUBS.S:967**. Sets up image lists, `zerolsts`, the hourglass (`drawglass`), loads
  and sets up both characters, `jsr fast`, `drawpost`, then at **:1002-1007**:

```
 jsr pburn
 jsr pburn      ;first put down 2 torch flames
 jsr pstars     ;& twinkle stars
 jsr drawall    ;...then draw the rest
 jmp pflow      ;& flow sand
```

- **`pburn`** advances one torch's flame state per call — `lda ptorchstate,x / jsr getflameframe /
  sta ptorchstate,x` — selecting the torch by `ptorchcount`, incremented and wrapped on entry. **Two calls,
  two torches, one flame-frame each, every animation step.**

**So the oracle's cutscene frame is a single composite pass over every animated element, flipped once.** That
is the model, and the port already has its shape — `flicker` then `chars_frame` then one `HAL_gfx_swap`. What
the port gets wrong is the **rate**: it runs that composite pass every video frame instead of every animation
step, and it drives the torches from a separate divider.

#### 3B — How I got it wrong, stated so it is reusable

Three compounding errors, none of them exotic:

1. **I trusted a grep's line numbers as scope.** `grep -n pburn` gave `:803, :837, :1002, :1003`. Line numbers
   locate text; they say nothing about the enclosing routine. **The enclosing routine was the entire question**
   and one `awk` for the preceding label would have answered it. I ran that awk only after Jay contradicted me.
2. **I read a comment as a claim about lifecycle when it was a claim about order.** *"first put down 2 torch
   flames"* — I took "first" as "at scene start"; it means "before `drawall`". The project's standing invariant
   is *a check must distinguish code from commentary about code*; this is the subtler cousin — **distinguishing
   what a comment is about.**
3. **I stopped at a hypothesis that explained the evidence I had.** "`pburn` lives in `PlaySong`, so the beats
   alternate" accounted for `:803` and `:837` neatly, and I let it absorb `:1002-1003` as setup rather than
   treating them as the anomaly they were. **A hypothesis that explains most call sites and quietly
   re-labels the rest is not confirmed, it is unfalsified.**

**And it was reported with confidence and a table.** P3.46 §1 stated *"The oracle never runs both at once"* in
bold. The presentation carried more certainty than the evidence did — the same shape as P3.45's confident
absence, one dispatch later.

#### 3C — What survives from P3.46, and what does not

**Withdrawn:** §3D in full, and every consequence drawn from it — that A2's premise is not the oracle's, that
A3's target is unsettled, and the §7 flag suggesting P3.26's measurement conflicted with the source.

**Survives, unaffected:**
- **Part B** (§3A of P3.46) — Karateka's 11-phase VBL scheduler, found in `tests/scripted/scene6_b2prime_driver.s`,
  with the present scheduled into the last phase. Jay's recollection confirmed; my P3.45 absence claim
  corrected. Untouched by this.
- **§3C.1** — the `$8000+` window is clear (nothing linked above `$7D2F`; `STACK_TOP $7F00`). Still true, now
  moot for A2.
- **§3C.2** — a one-instruction `gfx.s` addition fails the sync bridge, verified by injection and reverted.
  Still true, and **no longer blocking**, because A2 is not wanted.
- **§3B** — POP's per-step work (1.92 VBLs) fits inside its step (2.60 VBLs), so POP needs the cadence gate and
  not slicing. **Strengthened**: with the torches on the step, there is one change source rather than two.

---

### 4 — Verification

- **Jay's live observation** (tier 1): *"they look to flicker when he walks."* Launch path: **live oracle**,
  `mame apple2e -sl7 cffa202 -hard1 <scratch copy> -window -nomaximize -prescale 3`, operator-driven.
- **Preconditions honoured** (idioms §2A): `romset a2cffa02 is good` verified from `/c/mame`; mount validated
  headlessly (5 s, exit 0) before the window; scratch copy mounted, never the vendored image.
- **Oracle integrity**: `c4f0b13e49b77dd0fbc5063e27e53a24` before **and** after — byte-identical to the
  reference hash recorded in the idioms file. The scratch copy was also unwritten.
- **The source now agrees with the observation** (§3A), so there is no outstanding trace-vs-source conflict to
  carry.
- No `src/` change; Karateka untouched; `main` untouched.

---

### 5 — What this changes for the next build

**A1 becomes sufficient**, and A2/A3 collapse into it:

1. **Gate the composite pass on the animation step** — draw once per step, flip once, exactly as `DoFast` +
   `FrameAdv` do.
2. **Put the torches on that same step** and delete `FLAME_DIV` — the oracle has no torch divider. This is A3,
   and it is now a deletion rather than a retune.
3. **No A2.** No MMU work, no HAL change, no tearing question, no sync-bridge amendment.

**Still to be settled before building** (unchanged from P3.46 §3E): the gate needs `flicker` and `chars_frame`
split into decide/draw halves so "did anything change" is known before drawing — a restructure of the render
path. That is the build, and it is a fresh-session task.

---

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** I proposed no route. This change contains **one report and no code** — no cadence gate,
no torch change, no `src/` modification, no build. §5 states what the next build would contain; nothing in the
tree implements it.

**Deviations:**
- **Withdrew P3.46 §3D** on Jay's observation, then found the source had said so all along (§3A). Recording the
  misreading rather than only its conclusion (§3B), because the conclusion was reported in bold and the record
  needs the correction to be at least as loud.

### 7 — Uncertainty flags

- **Jay's observation is qualitative** (*"look to flicker"*) and is not needed to be more than that — the source
  now independently gives the mechanism, and the two agree.
- **`PlaySong` beats still draw torches direct to the displayed page** (`pburn`'s `jmp lay`, no flip in that
  loop). The port has no equivalent of those music beats, so nothing acts on it here — noted so it is not
  mistaken later for a contradiction of §3A.
- **The 57,074 / 74% figure is the CURRENT scene's work** at the oracle's cadence; `play 13`'s cels are still
  not in the tree (P3.42 §3C).
- Carried: the merge-rate comment still says 22; the scene's cels are unenumerated.

### 8 — Follow-up candidates

1. **Build A1 in a fresh session**, with the torches folded onto the animation step and `FLAME_DIV` deleted
   (§5). The specification is now complete and matches the oracle.
2. Carried: the 22 cy/byte comment in `blit_core.s`; enumerate the scene's cels; the representation ruling.

### 9 — User interaction during task

Jay asked me to run the oracle, watched it, and said the torches flicker while the vizier walks. That is the
opposite of what I had reported one turn earlier, and it was right. The source agreed with him; I had read it
badly and stated the result with more confidence than I had earned.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-09-a-grep-gives-line-numbers-not-scope.md` — pushed fire-and-forget.

### 11 — Commit

This report only; **no `src/` change**. Explicit-path staging on `wip`, pushed to `origin/wip`. `main`
untouched; Karateka read-only and unmodified; the vendored oracle image untouched and hash-verified; no
force-push.
