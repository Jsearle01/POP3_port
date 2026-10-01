## Form B Report — P5.20 — the shifted and mirrored blit, built and measured (IN PROGRESS)

**Class:** build (harness probe, not integrated). `wip`.

> ★ This file is committed in two steps on purpose. **This first commit holds ONLY §3A — the `$80`
> answer — and is made BEFORE any line of the routine exists**, so AC1's "before the routine was
> written" is a fact about the history rather than a claim in the report. The rest is filled in at
> the end.

### 0 — Receipt / status (C-35 stamp)

t0 = 2026-10-01T18:28:09-04:00 (HEAD `104b197`, wip; `main` at `32b5fe2`).

### 3A — AC1: the `$80` pre-reversal, answered from source before the routine

*Authority: source (`cel_blit_prep.py:131-139` encode, `:182-196` replay; `blit_core.s:505-532`), and
the permutation COMPUTED from `encode_row` itself rather than argued — `p520_phase1.py`.*

**It neither cancels nor compounds. It half-cancels, and the half that remains is what matters.**

An n-byte blast is stored as: the 4-byte groups **highest-address first**, **bytes forward inside
each group**, then the 1-3 byte tail (a 3-byte tail as `[1,2,0]` — the pair, then the single).
Computed from `encode_row`, body index per stream position:

```
n=5   [1,2,3,4, 0]            n=8   [4,5,6,7, 0,1,2,3]
n=6   [2,3,4,5, 0,1]          n=11  [7,8,9,10, 3,4,5,6, 1,2,0]
n=7   [3,4,5,6, 1,2,0]        n=12  [8,9,10,11, 4,5,6,7, 0,1,2,3]
```

A mirror needs the body in **fully descending** order (`n-1 … 0`) for an ascending write, or fully
ascending for a descending write. Against that:

- **the group ORDER cancels** — groups already arrive high-first, which is what an ascending mirrored
  write wants;
- **the order INSIDE a group does not** — it is forward, and the mirror needs it reversed; the
  3-byte tail's `[1,2,0]` is a third ordering again.

**★ The consequence is larger than the permutation, and it is what "a different routine" means
here.** `blit_blast` gets 4.5 cy/byte from `pulu d,y` / `pshs d,y`, and **PSHS and PSHU both write
descending — no 6809 stack op writes ascending.** A mirrored blast needs its bytes reversed inside
each group AND translated through the table, so it **cannot use the stack mover at all**: every
byte goes through a register, one at a time. The same is true of the shift, whose output byte is
the OR of two source bytes' halves.

**So the mirror is not the routine §5.260 costed, though not for the reason §2 feared.** §5.260
scaled its snippet's ratio (mirror 18 / plain 12 = 1.50×) onto `blit_core`'s **4.5 cy/byte stack-
blast** figure, which assumes the mirror keeps the stack mover's per-byte advantage. It cannot.
**6.8 and 20.6 cy/byte are therefore not established as upper bounds; they rest on a rate the
transformed path cannot reach.** The measurement in this dispatch decides it.

**What the permutation itself costs: nothing material.** A per-byte loop reads a group with
constant offsets (`ldb 3,u` … `ldb 0,u`, 5 cy each, then one `leau 4,u`) instead of `ldb ,u+`
(6 cy) — 25 cy per four bytes against 24. Any fixed in-group order is absorbed that way, so the
pre-reversal is a READ PATTERN, not a cost.
