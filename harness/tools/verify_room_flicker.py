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

STRIDE = 80                     # 320 px at 4 px/byte
BOXES = [(26, 31, 99, 115),     # torch 0: true px 111 -> byte 27.75
         (48, 53, 99, 115)]     # torch 1: true px 201 -> byte 50.25


def inside(i):
    r, c = i // STRIDE, i % STRIDE
    return any(c0 <= c <= c1 and r0 <= r <= r1 for c0, c1, r0, r1 in BOXES)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--room', required=True, help='the converted room asset')
    ap.add_argument('--first', required=True)
    ap.add_argument('--second', required=True)
    a = ap.parse_args()

    want = pathlib.Path(a.room).read_bytes()
    one = pathlib.Path(a.first).read_bytes()
    two = pathlib.Path(a.second).read_bytes()

    if len(one) != len(want) or len(two) != len(want):
        print(f"  FAIL capture size {len(one)}/{len(two)}, expected {len(want)}")
        return 1

    ok = True

    stray = [i for i in range(len(want)) if one[i] != want[i] and not inside(i)]
    stray += [i for i in range(len(want)) if two[i] != want[i] and not inside(i)]
    if stray:
        i = stray[0]
        print(f"  FAIL room disturbed outside the torches: {len(stray)} bytes; "
              f"first at row {i // STRIDE} col {i % STRIDE}")
        ok = False
    else:
        print("  PASS room intact outside the torch boxes: every other byte "
              "matches the asset")

    moved = [i for i in range(len(one)) if one[i] != two[i]]
    outside = [i for i in moved if not inside(i)]
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
