## Form B Report — P3.72n recon — what a RUNTIME mirror would cost, and what it would buy
**Class:** recon. wip. No source change. Prod untouched.

### 0 — Receipt / status
Jay's question, after spotting that the vizier's exit reuses the walk frames: cost a runtime
mirror properly, against the 6809 floor. HEAD `814cd30`, wip, tree green.

---

### 1 — Summary

**Affordable — about 3-4% of an iteration per mirrored cel — and worth taking. But it is
16% of the shortfall, not a substitute for the loader.**

| | |
|---|---|
| cost per mirrored cel draw | **~+3,080 cy** |
| iteration budget (loop runs every ~2.8 frames) | **~83,600 cy** |
| measured headroom over a full two-character peel+draw | **~24,000 cy** |
| **so a mirrored cel costs** | **3.7% of the iteration, 13% of the headroom** |
| RAM it returns | **~4,175 B net** |
| the remaining beats' shortfall | **25,565 B** |

---

### 2 — Reasoning

**2A — Why the question is a good one.** `Vexit` ends

```
db aboutface,chx,16
db chx,3
db goto
dw Vwalk2          <- the WALK loop
```

so he turns and **walks out on cels 48-53 again, mirrored**. Only the turn (57-66) and the
arm-lowering (77-82) are new art. **`Pback` is not the same story** — measured across every
cel in these beats, **no image index is shared by any two cels**; her step-back cels 12-17
are images 35-40, her own art, and she has no walk sequence in this scene at all.

**The real inefficiency the question exposes: the port pays for mirrors twice and the
oracle does not.** In the oracle a mirror is free — `OPACITY` bit 7 routes `LAY` to `MLAY`
[HIRES.S:655], same art. In the port every mirrored variant is a second full-size baked
cel.

**2B — The cost, from the actual inner loop.** `blit_cel`'s merge path is annotated as a
floor, not an estimate — *"22 cy/byte, and that is a 6809 FLOOR ... there is no 16-bit
AND/OR against memory and no register-to-register logic op"* [blit_core.s:98-102]:

```
lda ,x      ; 4   read destination
anda ,u+    ; 6   keep where the cel is clear
ora ,u+     ; 6   take the cel elsewhere
sta ,x+     ; 6   write back
```

A mirrored draw needs two things per byte: the destination walked **descending** (free —
`sta ,-x` costs the same as `sta ,x+`), and each source byte **pair-reversed**, because a
byte holds four 2-bit pixels and mirroring reverses their order within it. Reversal is a
256-byte lookup (`ldb ,u+ / ldb b,y`), not arithmetic — but it needs B and a spill, since A
is holding the destination byte:

```
ldb ,u+ / ldb b,y / stb tmp / lda ,x / anda tmp
ldb ,u+ / ldb b,y / stb tmp / ora tmp / sta ,-x
```

**≈63 cy against ≈31 including loop overhead — about +32 cy/byte on merges.** The blast
path is cheaper to convert: a stack blast already writes descending, so only the lookup is
added, ~+10 cy/byte.

**2C — Against the measured segment mix.** Parsed from the scene's own baked cels: **~74
merge bytes and ~71 blast bytes per cel.**

```
merge  74 x +32  = +2,368 cy
blast  71 x +10  =   +710 cy
                 = +3,078 cy per mirrored cel draw
```

The loop now runs every ~2.8 frames (P3.72k), so an iteration has ~2.8 x 29,859 = **83,600
cy**. P3.21 measured a full two-character peel+draw at ~2 frames ≈ 59,700, leaving ~24,000
spare. **One mirrored cel is 13% of that headroom; both characters mirrored at once is 26%.**
In this scene at most one is mirrored at a time.

**2D — What it returns.** Her mirrored standing cel (1 bake) plus `Vexit`'s walk-out (cels
48-53 mirrored, 6 bakes) = 7 x 633 B = **4,431 B**, less a 256-byte table = **~4,175 B**.

**And it compounds:** it removes the mirror from the bake permanently, so every future beat
that turns a character costs nothing extra in RAM. `Vexit` is one; the game beyond this
cutscene is full of them.

### 3 — The verdict, and the part that does not change

**Take it — but it does not unblock the beats.** 4,175 B against a **25,565 B** shortfall is
16%. The staging loader is still the thing that closes the gap, and P3.63's measured peak
residency of 5,631 B against a 15,872 B bank is still the reason it can.

What the mirror does change is the loader's job: every beat's working set shrinks, and the
one structural cost that was going to grow with every future turn stops growing.

**Sequencing, if both are wanted:** the loader first, because it is what makes the beats
possible at all and its design is unaffected by the mirror; the mirror second, as a
reduction that makes each staged load smaller. Doing the mirror first would be optimising a
scene that still cannot play to its end.

### 4 — Uncertainty flags

- **The +32 cy/byte is an instruction-count sketch, not a measured run.** The sequence is
  written out above and can be counted, but it has not been assembled and timed. The
  conclusion is not sensitive to it: at double my figure a mirrored cel is still only 26%
  of the headroom.
- **`blit_blast` needs its own pass.** It writes through S with `pshs` in reversed groups
  already; whether the lookup fits its register discipline as cheaply as +10 cy/byte is
  assumed, not shown.
- The 24,000 cy headroom is derived from P3.21's two-frame figure at the OLD loop rate,
  re-scaled to the current 2.8-frame iteration. It should be re-measured with `phasecost`
  before anything is built on it.

### 5 — Commit

This report. No source change.
