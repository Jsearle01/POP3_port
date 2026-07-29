#!/usr/bin/env python3
r"""verify_room_flame_pixels.py — is the drawn flame the RIGHT PIXELS, not just moving?

The existing flicker check asserts that bytes change and that the changes stay inside
the torch boxes. It cannot see a wrong COLOUR, a wrong cel, or a corrupted merge —
which is exactly how blue pixels reached Jay's eye instead of the suite's. A test that
cannot detect a wrong pixel is not testing the draw.

This composites the expected framebuffer offline — the room asset with cel N laid over
it at the torch position, opaque where the cel is non-zero and transparent where it is
index 0 (the flames convert with opacity=none, so every black pixel is keyed) — and
compares it against the captured screen byte for byte inside the torch boxes.

The engine reports which cel each torch is showing, so there is no guessing about
which of the nine to composite: probe_cel0/probe_cel1 are read at capture time and
passed in here.
"""
import argparse
import pathlib
import re
import sys

STRIDE = 80
CEL_W, CEL_H = 2, 13
FLAME_TOP = 101
TORCH_COL = {0: 28, 1: 50}


def load_cel(n):
    """the converted cel's packed CoCo bytes, one row per line"""
    p = pathlib.Path(f'content/cutscene/flames/flame{n}/converted.s')
    rows = []
    for line in p.read_text().splitlines():
        if 'fcb' not in line or 'row' not in line:
            continue
        vals = [int(t, 16) for t in re.findall(r'\$([0-9A-Fa-f]{2})', line)]
        if vals:
            rows.append(vals)
    return rows


def composite(room, cel, col):
    """lay the cel over the room, keying index-0 pixels"""
    fb = bytearray(room)
    for r, row in enumerate(cel):
        for c, cb in enumerate(row):
            o = (FLAME_TOP + r) * STRIDE + col + c
            keep = fb[o]
            out = 0
            for k in range(4):
                sh = 6 - 2 * k
                v = (cb >> sh) & 3
                out |= ((v if v else (keep >> sh) & 3) << sh)
            fb[o] = out
    return fb


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--room', required=True)
    ap.add_argument('--shot', required=True)
    ap.add_argument('--cel0', type=int, required=True)
    ap.add_argument('--cel1', type=int, required=True)
    a = ap.parse_args()

    room = pathlib.Path(a.room).read_bytes()
    shot = pathlib.Path(a.shot).read_bytes()
    if len(shot) != len(room):
        print(f"  FAIL capture is {len(shot)} B, expected {len(room)}")
        return 1

    want = composite(room, load_cel(a.cel0), TORCH_COL[0])
    want = composite(want, load_cel(a.cel1), TORCH_COL[1])

    bad = []
    for t, col in TORCH_COL.items():
        for r in range(FLAME_TOP, FLAME_TOP + CEL_H):
            for c in range(col, col + CEL_W):
                o = r * STRIDE + c
                if shot[o] != want[o]:
                    bad.append((t, r, c, shot[o], want[o]))
    if not bad:
        print(f"  PASS flame pixels are exactly cel {a.cel0}/{a.cel1} over the room: "
              f"{2 * CEL_W * CEL_H} bytes byte-identical")
        return 0

    print(f"  FAIL flame pixels wrong: {len(bad)} of {2 * CEL_W * CEL_H} bytes")
    names = {0: 'black', 1: 'orange', 2: 'BLUE', 3: 'white'}
    for t, r, c, got, exp in bad[:6]:
        gp = [names[(got >> (6 - 2 * k)) & 3] for k in range(4)]
        ep = [names[(exp >> (6 - 2 * k)) & 3] for k in range(4)]
        print(f"    torch {t} row {r} col {c}: got ${got:02X} {gp} want ${exp:02X} {ep}")
    return 1


if __name__ == '__main__':
    sys.exit(main())
