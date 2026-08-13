## Form B Report — P3.82 — the addressing lead is refuted by measurement; the fault is in `blit_cel`

**Class:** recon (measurement + splits; no net source change). wip. Prod untouched.
**★ HARD-STOP #2 fired again: the two bytes are still not attributed** — but the candidate set
is now down to one, by measurement rather than by reasoning.
**§2 (beats, harness sweep) and §3 (re-encode) not reached.**

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-12T22:25:05-04:00 (HEAD `db07d12`, wip). **Still at `db07d12` — `src/` is clean;**
every edit this dispatch was a probe and every probe was reverted.
POP `main` untouched at `635f986`. Karateka untouched (`wip` `ac2b768`, `main` `5eb92b1`).
Build green; room suite unchanged (8/8, room intact, flames flicker, 2 of 78 flame bytes).

---

### 1 — Summary

**The Orchestrator's lead was well-reasoned and is WRONG, and the machine says so.** Torch 1
draws at exactly the right address, from exactly the right table:

```
draw 1   X=$9FC2  U=$365A (torch1 cel 8)  rows=13 width=3
         $9FC2 - $8000 = 8130 = row 101, col 50   <- FLAME_TOP 101, TORCH1_COL 50, phase 1
draw 4   X=$9FAB  U=$3141 (torch0 cel 4)  rows=13 width=3
         $9FAB - $8000 = 8107 = row 101, col 27   <- TORCH0_COL 27
```

**And the paired fact has not drifted:** `torch0_cels` links at `$3000` (= `FLAME_BASE+0`)
and `torch1_cels` at `$3012` (= `FLAME_BASE+18`), matching the room's two `equ`s exactly.

**★ AND THE SYMPTOM'S OWN ARITHMETIC REFUTES THE PHASE STORY TOO.** Only **2 bytes of 39**
differ for torch 1. A sub-byte phase error displaces *every* byte of the cel, not two — so
"one-pixel shift" was the right observation about those two bytes and the wrong inference
about the cause.

**By elimination, on measurement alone, the fault is in `blit_cel`'s segment restructuring.**
That is the last candidate standing and it is not yet proven.

### 2 — Files modified

**None.** `src/` is clean at `db07d12`.

### 3 — Reasoning

**3A — What was measured (§1.1–1.3 of the dispatch).** A read-tap on `blit_cel`'s entry,
gated on the opcode fetch (`PC == addr+1`, idioms §10a), logging X, U, and resolving U
against both torch tables. Twenty-five draws captured:

- **Addresses correct** for both torches, every frame (§1 above).
- **`t_tab` reaches the right table** — every torch-1 stream resolves inside `torch1_cels`,
  every torch-0 stream inside `torch0_cels`. The `_full` repoint did not disturb it.
- **Both torches are 3 bytes wide**, which incidentally corrects two stale comments that
  disagree with each other: `flame_cels.s:69` says torch 0 is "phase 0, 13x2B, px 112",
  `cutscene_room.s:1105` says "phase 3, 13x3B — px 111". `build.bat` builds it `--phase 3`,
  and the machine says width 3. **Neither comment is right; the build is.**

**3B — ★ Only torch 1 is wrong, and only two of its bytes.** That was already the
discriminator §1.3 asked for, and it points *away* from the shared path — but the
two-of-thirty-nine ratio also points away from a phase or address fault, because those are
wholesale. The symptom is a *localised* wrong value at the cel's first column on two adjacent
rows, which is arithmetic, not addressing.

**3C — The candidate set, and how each was closed.**

| candidate | closed by | verdict |
|---|---|---|
| the peel (`blit_save`/`blit_erase`) | P3.81: both reverted, bytes persist | **not it** |
| `bc_trim`'s arithmetic | P3.80: fast path bypasses it, bytes persist | **not it** |
| the flame content pipeline | `git diff 0f2e92e..HEAD` — identical | **not it** |
| the draw address / `t_off` | **this dispatch: measured correct** | **not it** |
| `t_tab` / the torch table pair | **this dispatch: measured correct** | **not it** |
| **`blit_cel`'s merge/blast restructuring** | — | **the last one standing** |

The fast path bypasses `bc_trim`'s *arithmetic* but **not the restructuring around it** —
`bc_blast` still reaches `blit_blast` with the count in `bc_run` rather than in A from
`lda ,u+`, and both paths still carry the `bc_pre`/`bc_seglen` bookkeeping. That is the
untested delta.

**3D — I did not complete the split that would prove it, and the reason is a process
failure worth recording.** The probe required replacing the merge and blast bodies with their
originals. **I damaged `blit_core.s` a fourth time doing it** — a regex spanning
`bc_blast_back` to the wrong `lbra bc_seg` removed the label the blast path returns through.
Restored from git; `src/` is clean.

**P3.81 §6 said this technique was "now banned for me on this file" and I used a regex form
of it in the very next dispatch.** Four instances across four dispatches, one of which
produced a false diagnosis (P3.80 §3E). **That is not a technique problem any more; it is a
reliability signal about doing delicate mechanical edits this deep into a session**, and it
is the honest reason this dispatch stops here rather than pressing on.

### 4 — Verification

**25.1 fresh tool output (at `db07d12`, tree restored):**
- `lwasm` on the restored `blit_core.s` → clean, `src/` shows 0 modified files
- Torch trace (verbatim excerpts in §1) — `build/tmp/trace_torch.log`, 25 draws
- Link map: `torch0_cels = 3000`, `torch1_cels = 3012`, `blit_tab = 3028`
- Room suite unchanged: `checks=8 passed=8 failed=0`; `PASS room intact`; `PASS flames
  flicker`; `FAIL flame pixels wrong: 2 of 78`

**The instrument was checked for what it writes** (P3.71): the tap is read-only and gated on
the PC; it writes only its log.

**25.2:** N/A. **25.3: not offered.**

### 5 — Acceptance criteria

1. **Torch 1's draw address measured live; `t_tab` confirmed; torch 0 compared** — **YES**
   (§3A). All three came back correct, which is a negative result and a real one.
2. **The two bytes attributed and fixed** — **NO.** Narrowed to one candidate by measurement;
   **no new bound is proposed, because the dispatch is explicit that an untested bound is
   what cost P3.81.**
3. **Two missing beats** — **NO, not reached.**
4. **Harness offsets swept** — **NO, not reached** — though one was found in passing (§7).
5–8. **Green, re-encode, grouping, symbol verification, gate** — **NO.** HARD-STOP #3: green
   is not reached, so the re-encode did not start.
9. **Route accounting; sync bridge; Karateka and `main` untouched** — yes.

### 6 — Reactive deviations and route accounting

**The dispatch ordered §1 → §2 → §3. This contains §1's measurements and one failed split,
and nothing else.** No deviation from the order; the yield was one exclusion pair and one
aborted probe.

Not present: the attribution, the fix, the beats, the sweep, the re-encode, the grouping, the
gate, the turn, the hourglass. Swap not unwound; `shift_row.s` not reopened; draw-time
mirroring still ruled out on schedule grounds.

### 7 — Uncertainty flags

- **★ The two bytes remain unattributed.** One candidate stands (§3C) and it is untested.
  **No bound is claimed.**
- **★ A stale checker found in passing, unfixed:** `verify_room_flame_pixels.py:139` skips
  every position line with `if len(f) != 7`, but `room_test.lua` has written **9** fields
  since P3.71 added the two facings. So the character-footprint exclusion has been dead for
  eleven dispatches — it does not affect this failure (no character is near col 50) but it
  means **a character standing in front of a torch would be reported as broken flames.**
  Fourth instance of the stale-checker class, and again found by accident rather than by the
  sweep §2 keeps deferring.
- **Two stale comments contradict each other** about torch 0's phase and width (§3A).
- `beats_visited` 16 of 18, untouched.
- Carried: the turn-to-exit disappearance; hourglass and flash unbuilt; ROOM.BIN 7 bytes of
  headroom; 0.20 s per-call overhead; `$2310..$2329` read-tap blindness.

### 8 — Follow-up candidates

1. **The remaining split, done safely:** replace `blit_cel`'s merge and blast bodies with the
   pre-clip originals **by hand-editing with exact-match replacements only**, never a regex or
   an index range. If the two bytes vanish, that is the attribution.
2. **★ Then reconsider the clip's shape.** If the restructuring is the fault, the fix is
   probably not to repair it but to apply the window the way `co_clip` already does — as a
   post-pass — rather than threading a trim through the segment walker. That was the cheaper
   option Jay declined *for the draw*, and it may be the right one *inside* the blitter.
3. **§2's harness sweep**, which has now surfaced its fourth stale checker by accident.
4. `beats_visited`; then the re-encode against green.

### 9 — User interaction during task

None.

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-08-13-the-symptoms-shape-can-mislead-too.md` — pushed. The Orchestrator
reasoned that a one-pixel displacement must be an addressing fault and that candidates
producing wrong *values* were "the wrong shape". The reasoning was sound and the conclusion
was wrong: two bytes out of thirty-nine is not a displacement of the cel at all, and the
shape argument had been applied to the wrong scale. **Constraining a search by the symptom's
shape is powerful and still has to be checked against the symptom's EXTENT.**

### 11 — Commit

**No source commit.** Tree at `db07d12`, `src/` clean; this report follows.
