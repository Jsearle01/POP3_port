#!/usr/bin/env python3
"""p321 peelcost.py — cost the peel movers, per ROW rather than per byte.

Jay: "measure it" -- the backward-reading stack-blast I floated at ~6.5 cy/byte
against the forward copy's ~10.5.

Per-BYTE rates are the wrong unit here and that is the finding. A cel row is FIVE
bytes; the per-row prologue and epilogue are not amortised over anything. So this
counts complete rows, including the invariant reloads the shipped code performs
every row.

MC6809 timings, same source as P3.19 (sprite_compiler's IMM/LD_IDX/ST_IDX plus
`5 + bytes` for the stack ops):
    ldd ,u++ / std ,y++     8 each      ldd ,--u   8     ldy ,--u   9
    pulu/pshs d,y           9 each      lda ,u     4     sta ,y     4
    lda ,-u                 6           pshs a     6
    pshs/puls x,y           9 each      leax n,x   5     leay a,y   5
    lda/sta direct          4           dec direct 6     bne        3
    lsra / anda #imm        2           tfr        6     beq        3
"""

W = 5                      # both cutscene cels are 5 bytes wide
VIZ_ROWS, PRI_ROWS = 48, 43


def shipped_forward(w):
    """What P3.21 actually shipped: forward copy, invariants reloaded per row."""
    cy = 9                                  # pshs x,y
    cy += 6                                 # tfr x,u
    cy += 4 + 2 + 3 + 4                     # lda width / lsra / beq / sta count
    pairs = w // 2
    cy += pairs * (8 + 8 + 6 + 3)           # ldd/std/dec/bne
    cy += 4 + 2 + 3                         # lda width / anda #1 / beq
    if w & 1:
        cy += 4 + 4                         # lda ,u / sta ,y
    cy += 9                                 # puls x,y
    cy += 5 + 4 + 5                         # leax stride / lda width / leay
    cy += 6 + 3                             # dec rows / bne
    return cy


def tight_forward(w):
    """Same mover, invariants hoisted and the row unrolled."""
    cy = 6                                  # tfr x,u
    cy += (w // 2) * (8 + 8)                # unrolled ldd/std, no loop control
    if w & 1:
        cy += 4 + 4
    cy += 5 + 5 + 6 + 3                     # leax / leay / dec / bne
    return cy


def backward_blast(w):
    """The variant Jay asked about: read descending, pshs writes a true copy."""
    cy = 6 + 5                              # tfr x,u ; leau w,u  (U at row end)
    cy += 5                                 # leas w,y            (S at peel end)
    cy += (w // 4) * (9 + 8 + 9)            # ldy ,--u / ldd ,--u / pshs d,y
    rem = w % 4
    if rem >= 2:
        cy += 8 + 7                         # ldd ,--u / pshs d
    if rem & 1:
        cy += 6 + 6                         # lda ,-u / pshs a
    cy += 5 + 5 + 6 + 3                     # leax / leay / dec / bne
    return cy


def padded_blast(w):
    """Pad the peel row to a multiple of 4 so pulu/pshs IS an involution."""
    wp = (w + 3) & ~3
    cy = 6                                  # tfr x,u
    cy += 5                                 # leas wp,y
    cy += (wp // 4) * (9 + 9)               # pulu d,y / pshs d,y
    cy += 5 + 5 + 6 + 3
    return cy, wp


print("=== per-ROW cost of one peel pass, width %d ===" % W)
sf = shipped_forward(W)
tf = tight_forward(W)
bb = backward_blast(W)
pb, wp = padded_blast(W)
for name, cy in (("shipped forward copy", sf), ("tight forward (hoisted)", tf),
                 ("backward stack-blast", bb), ("padded fwd blast (w=%d)" % wp, pb)):
    print("  %-26s %4d cy/row  = %5.1f cy/byte" % (name, cy, cy / W))

print("\n=== both characters, erase + save, per frame ===")
rows = VIZ_ROWS + PRI_ROWS
for name, cy in (("shipped forward copy", sf), ("tight forward (hoisted)", tf),
                 ("backward stack-blast", bb), ("padded fwd blast", pb)):
    tot = rows * cy * 2
    print("  %-26s %6d cy" % (name, tot))

print("\n=== against the frame budget (29,673 cy usable) ===")
DRAW = 4735 + 3912          # measured blit_cel draw cost, P3.19 model
FLAME = 1408
for name, cy in (("shipped forward copy", sf), ("tight forward (hoisted)", tf),
                 ("backward stack-blast", bb), ("padded fwd blast", pb)):
    peel = rows * cy * 2
    total = peel + DRAW + FLAME
    print("  %-26s peel %6d + draw %5d + flames %4d = %6d  -> %s"
          % (name, peel, DRAW, FLAME, total,
             "FITS (%.0f%%)" % (100 * total / 29673) if total <= 29673
             else "OVER %.2fx" % (total / 29673)))

print("\n=== the structural option: don't peel a character that has not moved ===")
print("  A static character's background never changes, so save is needed ONCE per")
print("  buffer and erase not at all. Per frame that leaves the DRAW alone:")
print("    draw only               %6d cy  -> FITS (%.0f%%)"
      % (DRAW + FLAME, 100 * (DRAW + FLAME) / 29673))
