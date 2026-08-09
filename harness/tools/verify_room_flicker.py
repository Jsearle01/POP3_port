#!/usr/bin/env python3
r"""verify_room_flicker.py — did the torches actually flicker, and nothing else move?

Phase B's claim is motion, so a single captured frame cannot test it: a still picture
passes every other check in the room suite. This takes TWO captures a few frames apart
and asserts the pair.

Two assertions, and they fail in opposite directions:

  1. OUTSIDE the torch boxes, both captures must equal the room asset byte for byte.
     This is what catches a sprite drawn at the wrong address, a peel buffer that
     restores the wrong bytes, or a draw that scribbles past its footprint.
  2. INSIDE the torch boxes, the two captures must DIFFER. This is what catches the
     flicker not running at all -- which is exactly the failure a single-frame check
     would have called a pass.

The boxes are the flames' measured extent on the running oracle (columns 27-29 and
50-51, rows 104-113) with a margin, not a guess: harness/tools/oracle_ram_dump.lua
captures, differenced across frames, put them there.
"""
import argparse
import pathlib
import sys
import cel_parity_rule as R

STRIDE = 80                     # 320 px at 4 px/byte
BOXES = [(26, 31, 99, 115),     # torch 0: true px 111 -> byte 27.75
         (48, 53, 99, 115),     # torch 1: true px 201 -> byte 50.25
         # ...and the four stars. They are OUTSIDE the torches, so without these a lit
         # star reads as damage to the room — the check would fail for the scene
         # working correctly.
         (10, 10, 98, 98), (8, 8, 101, 101),
         (9, 9, 109, 109), (9, 9, 114, 114),
         # ...and the two characters (P3.21). They are drawn by the real blit path
         # now, so their footprints are legitimate content rather than damage. The
         # BYTE-EXACTNESS of what lands there is not checked here -- this file only
         # knows where things may change. verify_room_chars.py compares the pixels
         # against an offline replay of the same baked cels, which is the check that
         # can actually see a wrong one.
         # The vizier MOVES (P3.22), so his box is the range of the motion, not one
         # position. The demo oscillates x over 189..205 in 8 px steps — 8 px keeps
         # him on phase 1, which one baked cel can serve — so with +20 centring and
         # width 5 he occupies byte columns 52..60.
         # ...AND SINCE P3.31 HE WALKS THE WHOLE ROOM, so a fixed box is no longer a
         # box at all. --pos replaces both character boxes with the footprints the
         # machine actually recorded for each capture; this pair is the fallback for
         # a run with no positions file, which is now only the static demos.
         (52, 60, 104, 151),          # vizier   x 189..205, phase 1
         # The princess MOVES and CHANGES CEL under the VM (P3.25): the demo sequence
         # steps her x between 112 and 120 and alternates Pstand (5 B wide) with
         # Pslump (6 B), so she occupies byte columns 33..40 over rows 109..151.
         (33, 40, 109, 151)]          # princess x 112..120, cels 11/1, phase 0


def inside(i, boxes=None):
    r, c = i // STRIDE, i % STRIDE
    return any(c0 <= c <= c1 and r0 <= r <= r1 for c0, c1, r0, r1 in (boxes or BOXES))


def recorded_boxes(posfile):
    """Character boxes from where the machine says the characters WERE.

    A walking character cannot have a written-down box: the whole point of the walk is
    that he is somewhere different every step. Reading the position back and boxing THAT
    keeps the assertion tight -- everything outside the footprints the machine reports
    must still equal the room -- instead of widening the box until it stops meaning
    anything. Widths and heights are the widest either character has, which is the one
    approximation here and it errs on the side of excusing bytes, not accusing them.
    """
    W, H = 11, 48                    # widest cel + a byte for the sub-byte spill
    boxes = list(BOXES[:6])          # the torches and the stars, unchanged
    for line in pathlib.Path(posfile).read_text().splitlines():
        f = line.split()
        if len(f) != 7:
            continue
        vx, vy, vc, px, py, pc = map(int, f[1:])
        for x, y, cel in ((vx, vy, vc), (px, py, pc)):
            # SETUPCHAR's expression, not `x + 20` (P3.58): CharX is in two-pixel units
            # and the parity bit is the odd pixel. The half-scale form put the vizier's
            # footprint 20 byte-columns left of where he is now drawn, so his real
            # position read as damage to the room.
            _i, fdx, _fy, fchk, _l = R.altset2()[cel]
            col = (R.draw_x(x, fdx, fchk) + 20) >> 2
            boxes.append((col - 1, col + W, y - H + 1, y))
    return boxes


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--room', required=True, help='the converted room asset')
    ap.add_argument('--first', required=True)
    ap.add_argument('--second', required=True)
    ap.add_argument('--pos', help='positions recorded by the run; replaces the two '
                                  'static character boxes with the real footprints')
    a = ap.parse_args()
    boxes = recorded_boxes(a.pos) if a.pos and pathlib.Path(a.pos).exists() else None
    inside_ = lambda i: inside(i, boxes)                              # noqa: E731

    want = pathlib.Path(a.room).read_bytes()
    one = pathlib.Path(a.first).read_bytes()
    two = pathlib.Path(a.second).read_bytes()

    if len(one) != len(want) or len(two) != len(want):
        print(f"  FAIL capture size {len(one)}/{len(two)}, expected {len(want)}")
        return 1

    ok = True

    stray = [i for i in range(len(want)) if one[i] != want[i] and not inside_(i)]
    stray += [i for i in range(len(want)) if two[i] != want[i] and not inside_(i)]
    if stray:
        i = stray[0]
        print(f"  FAIL room disturbed outside the torches: {len(stray)} bytes; "
              f"first at row {i // STRIDE} col {i % STRIDE}")
        ok = False
    else:
        print("  PASS room intact outside the torch boxes: every other byte "
              "matches the asset")

    moved = [i for i in range(len(one)) if one[i] != two[i]]
    outside = [i for i in moved if not inside_(i)]
    if not moved:
        print("  FAIL flames did not move between the captures — a still picture")
        ok = False
    elif outside:
        i = outside[0]
        print(f"  FAIL something moved outside the torches: {len(outside)} bytes; "
              f"first at row {i // STRIDE} col {i % STRIDE}")
        ok = False
    else:
        rows = sorted({i // STRIDE for i in moved})
        cols = sorted({i % STRIDE for i in moved})
        print(f"  PASS flames flicker: {len(moved)} bytes changed between captures, "
              f"all inside the torch boxes (rows {rows[0]}-{rows[-1]}, "
              f"cols {cols[0]}-{cols[-1]})")
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
