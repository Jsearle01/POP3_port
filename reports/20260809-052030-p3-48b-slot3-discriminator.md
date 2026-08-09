## Form B Report — P3.48b — the discriminator failed its own control, so slot 3 is still unresolved
**Class:** investigation. wip. `src/` unchanged (fix re-applied, measured, reverted again). Prod untouched.

### 0 — Receipt / status (C-35 stamp)
Follows P3.48 within the same session on Jay's *"run it"*, so the standing receipt is P3.48's:
t0=2026-08-09T04:54:25Z. HEAD at report = `e7cde1e`, wip, **tracked tree clean**; `src/` byte-identical to t0
and rebuilt to the t0 layout (`peel_base $22C9`, 36,253 B total). Sync bridge green. Karateka and `main`
untouched.

---

### 1 — Summary

**I ran the discriminator I proposed. It says there is no trail. That reading is worthless, because the
seeded control says the probe cannot see a trail even when I disable the erase entirely.**

| run | buffer B torch 1, non-zero bytes of 26 |
|---|---|
| real build, shot1 / shot2 | 15 / 14 |
| **erase DISABLED (seeded), shot1 / shot2** | **15 / 15** |

**Disabling the restore outright changed the magnitude not at all.** A probe that reads the same with the
mechanism removed cannot testify that the mechanism is working. **So the clean result from the real build
proves nothing, and slot 3 remains exactly as unresolved as it was at the end of P3.48.**

**The slot-3 measurement itself reproduced exactly** on a correctly built binary — parity 694/694 with slots
alternating 0/2, slots 0-2 written and read 9022 each, **slot 3 written 9022, read 0**.

**★ AND I CAUGHT A PROCESS ERROR OF MY OWN THAT INVALIDATED A RUN.** My first trail run measured a **stale
binary**. Re-applying the fix and rebuilding via `cmd /c ... build.bat` from Bash **silently does nothing** —
it prints a shell banner and returns 0. The build I believed I had made was the previous one. It surfaced only
because the symbol addresses in the log came back at the *unfixed* layout (`peel_base $22C9`, `fl_slot`
always 0). **A build that did not run looks exactly like a build that ran**, and its exit code is 0.

**The fix stays out of the tree**, for the same reason as P3.48 and now with less evidence than I had hoped to
add: the parity half is proven, the slot-3 half is not, and nothing I ran today discriminates it.

---

### 2 — Files modified

- `harness/tools/torch_trail_probe.lua` — **new.** Tap-free two-buffer torch-box sampler **with a
  seeded-failure control** (`P_SEED=1` turns `torch_step`'s `beq ts_nosave` into `bra`, disabling the erase),
  and a gate located by instruction pattern rather than by byte offset.

**`src/engine/cutscene_room.s` — re-applied, measured, reverted again.** No `src/` delta.

---

### 3 — Reasoning

#### 3A — What was run, and in what order

1. Re-applied the parity fix (slots 2-3 are unreachable without it, so the question does not exist on the
   reverted tree).
2. **A stale-build run** whose result I discarded (§3C).
3. Rebuilt properly; **the slot proof reproduced**: `fl_slot 0:347 2:347`, parity **agree 694 / disagree 0**,
   slots 0-2 `w9022 r9022`, **slot 3 `w9022 r0`**, `t_prev` never 0 at the gate.
4. **The trail probe** on that binary: buffer B torch 1 at 15 then 14 non-zero bytes of 26 — no growth, no
   saturation.
5. **The seeded control** — and this is the run that matters.

#### 3B — The control, and why it voids the result

The trail probe had produced **byte-identical output for two different binaries**, which demonstrates
determinism and says nothing about sensitivity. This project's peel suite earns its verdicts by being
*proven to fail when seeded*; this probe had never been shown to fail at all.

So: patch `torch_step`'s `beq ts_nosave` to `bra` — **the erase never runs, for any slot, on any frame.**

```
# SEEDED: $2154 $27 -> $20 (BEQ->BRA); the erase is disabled
shot2 bufB torch1 0000000000000004000400544040404005400540055400540040   (15 of 26 non-zero)
```

**Against the unseeded 14-15. The probe cannot tell the erase from its absence.** My reasoning — *"an
unrestored box accumulates the union of every cel drawn there"* — is therefore false about this code, and the
whole discriminator rests on it.

**The probe did respond to the seed, just not the way I predicted:** with the erase disabled, all four boxes
became identical at shot1, where unseeded they differed. So it is not blind; it is measuring something other
than what I claimed.

**The hypothesis that would explain everything, offered as a hypothesis and nothing more:** if the compiled
flame draw writes **every byte** of its 13×2 box rather than only the lit pixels, then the erase is largely
redundant, an unrestored box looks identical to a restored one, and the peel is closer to vestigial than to
load-bearing. That would account for the 30 green dispatches with a cross-buffer restore, for the seeded
control, and possibly for slot 3. **I have not read the compiled cel routines to check, and I am not
concluding it.**

#### 3C — The stale build, recorded because it nearly produced a false result

Re-applying the fix and rebuilding with

```
cmd /c "cd /d c:\Projects\POP3_port && call .\build.bat" >/dev/null 2>&1
```

from the Bash tool **does not run the batch file** — the same invocation earlier in this session printed only
`Microsoft Windows [Version …]` and returned. Exit code 0 either way. The rebuild that works here is the
PowerShell path.

So the first trail run measured the **previous** binary. It was caught by the addresses in the log: `fl_slot`
values `0:694` (the pre-fix constant) and `peel_base $22C9` rather than `$22C2` — an 8-byte shift, exactly the
size difference between the fixed and unfixed ROOM.BIN.

**What saved it was the tool printing the addresses it was using.** Had it printed only its verdict, a stale
binary's clean result would have read as the fix's clean result. **Instruments should print their inputs, not
just their conclusions** — the same property that let P3.44's abort and today's seed guard fire.

#### 3D — The seed guard fired too, and was right

The first seeded attempt aborted:

```
# SEED ABORTED: $2147 holds $8E, expected $27 (BEQ) — NOT PATCHING
```

I had computed the gate as `torch_step + 3` by counting instruction lengths and got it wrong — `$8E` is the
second byte of `ldy #ptorchflame`. Patching there would have corrupted an operand and produced a plausible
number from a broken program. The tool now **locates the gate by pattern** (`lda t_prev` = `B6 <t_prev>`, take
the branch that follows) rather than by offset, which is the P3.43 lesson applied.

---

### 4 — Verification

- **Slot-3 finding reproduced** on a correctly built binary (§3A.3), identical to P3.48's.
- **Parity fix reproduced**: 694 agreements, 0 disagreements.
- **The discriminator was controlled and failed its control** (§3B) — the result is reported as void rather
  than as evidence.
- **`src/` restored and rebuilt**: `peel_base $22C9`, 36,253 B — the t0 layout. Tree clean.
- No `src/` change committed; Karateka untouched; `main` untouched; sync bridge green.

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 fresh tool output (verbatim):** the tables in §1 and §3B; the abort in §3D; and

```
# fl_slot values written: 0:347 2:347      # PARITY vs HAL: agree 694, DISAGREE 0
#   slot 3  $2310..$2329  writes   9022  reads      0  *** NOT LIVE ***
```

**25.2 bundled-artifact grep:** `harness/tools/torch_trail_probe.lua` — `seed_break` / `find_gate` /
`grab_box` / `map_blocks` (the `room_test.lua` dump idiom reused).

**25.3 operator-runtime-smoke:** **N/A — nothing shipped.** `src/` is byte-identical to t0.

**C-35 presence check:** §0. **Capture presence check:** one slug, §10.

---

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING.** I proposed no route. This commit contains **one probe and this report**. It contains
**no `src/` change** — the parity fix was re-applied, measured and reverted, and is in no commit. No cadence
gate.

**Deviations:**
- **Added a seeded control** the dispatch did not ask for, after noticing the probe had never been shown to
  fail. **It is the only reason this report says "unresolved" instead of "resolved".**
- **Discarded a completed run** as invalid on discovering the stale build (§3C).

### 7 — Uncertainty flags

- **★ Slot 3 is unresolved.** Reproducible, unexplained, and today's discriminator is void.
- **The "no accumulation" model of a missing erase is disproven for this code** (§3B). Any future
  discriminator must not rest on it.
- **The opaque-draw hypothesis (§3B) is unread and unverified** — the compiled cel routines have not been
  inspected.
- **The trail probe's remaining signal** (all four boxes converging under the seed) is unexplained and I have
  not built anything on it.
- **The `t_prev` base-0 / base-2 asymmetry** (1041 vs 694 gate reads) noted in P3.48 is still unexplained.
- Carried: the pre-existing cross-buffer restore remains in the tree, latent; the cadence gate unbuilt.

### 8 — Follow-up candidates

1. **Read the compiled flame cel routines first** (`build/flames/flame*.s`, from `sprite_compiler.py`) and
   establish whether the draw is fully opaque over its box. That one read decides whether the torch peel is
   load-bearing at all — and if it is not, **both the slot-3 puzzle and the P3.47 blocker dissolve**, and the
   cadence gate needs neither.
2. **Only then** re-open slot 3, with a discriminator that survives a seeded control.
3. Reapply the parity fix (proven) once 1-2 settle.
4. Carried: the cadence gate; the 22 cy/byte comment; audit for other orphans.

### 9 — User interaction during task

Jay said *"run it"*. I ran it, and it produced the answer I expected — no trail, fix looks safe. The control I
added afterwards showed the probe could not have detected a trail either way, so the expected answer was not
evidence. Reporting that is the whole of this dispatch.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-09-a-probe-that-agrees-with-you-still-needs-its-control.md` — pushed fire-and-forget.

### 11 — Commit

One probe and this report; **no `src/` change**. Explicit-path staging on `wip`, pushed to `origin/wip`.
`main` untouched; Karateka read-only and unmodified; no force-push.
