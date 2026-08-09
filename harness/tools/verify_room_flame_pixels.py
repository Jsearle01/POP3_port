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
    # THE CHECKER MUST READ THE CELS THAT WERE BUILT, not the pristine originals.
    # P3.52 shifts the torch cels 1 px right into a generated directory and compiles
    # THOSE; compositing the expectation from content/ would then report the engine as
    # wrong for drawing exactly what it was given. --cel-dir names the source of truth
    # for this run, and it defaults to content/ so nothing changes when no shift is in play.
    p = pathlib.Path(CEL_DIR) / f'flame{n}' / 'converted.s'
    rows = []
    for line in p.read_text().splitlines():
        if 'fcb' not in line or 'row' not in line:
            continue
        vals = [int(t, 16) for t in re.findall(r'\$([0-9A-Fa-f]{2})', line)]
        if vals:
            rows.append(vals)
    return rows


def composite(room, cel, col):
    """lay the cel over the room, OPAQUELY.

    The oracle's PSETUPFLAME sets OPACITY = sta -- a plain store -- so every pixel of
    the flame is written, black included. The cels are compiled with an all-opaque
    sidecar to match, so the expected image is a straight overwrite, not a key."""
    fb = bytearray(room)
    for r, row in enumerate(cel):
        for c, cb in enumerate(row):
            fb[(FLAME_TOP + r) * STRIDE + col + c] = cb
    return fb


CEL_DIR = 'content/cutscene/flames'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--room', required=True)
    ap.add_argument('--shot', required=True)
    ap.add_argument('--cel-dir', default='content/cutscene/flames',
                    help='directory holding flameN/converted.s as BUILT (default: the '
                         'pristine originals)')
    ap.add_argument('--cel0', type=int, required=True)
    ap.add_argument('--cel1', type=int, required=True)
    ap.add_argument('--pos', help='recorded character positions; their footprints are '
                                  'excluded, because a character standing in front of '
                                  'a torch is content, not damage')
    ap.add_argument('--tag', default='first', help='which capture row in --pos')
    a = ap.parse_args()
    globals()['CEL_DIR'] = a.cel_dir

    room = pathlib.Path(a.room).read_bytes()
    shot = pathlib.Path(a.shot).read_bytes()
    if len(shot) != len(room):
        print(f"  FAIL capture is {len(shot)} B, expected {len(room)}")
        return 1

    want = composite(room, load_cel(a.cel0), TORCH_COL[0])
    want = composite(want, load_cel(a.cel1), TORCH_COL[1])

    # A CHARACTER MAY STAND IN FRONT OF A TORCH. Until P3.32 the vizier stood at column
    # 54 forever and could not; now he walks the width of the room and passes both
    # torches, so this check has to know where he is or it reports the flames as broken
    # every time he crosses one. The footprints come from the machine's own record, not
    # from an assumption about where he might be.
    covered = set()
    if a.pos and pathlib.Path(a.pos).exists():
        W, H = 11, 48                   # widest cel + a byte for the sub-byte spill
        for line in pathlib.Path(a.pos).read_text().splitlines():
            f = line.split()
            # ONLY THIS CAPTURE'S ROW. The file holds every capture, and excluding all
            # of them would excuse bytes no character was standing on at this instant —
            # a check that widens itself is a check that stops failing.
            if len(f) != 7 or f[0] != a.tag:
                continue
            vx, vy, _vc, px, py, _pc = map(int, f[1:])
            for x, y in ((vx, vy), (px, py)):
                col = (x + 20) >> 2
                for r in range(y - H + 1, y + 1):
                    for c in range(col - 1, col + W + 1):
                        covered.add(r * STRIDE + c)

    bad, checked = [], 0
    for t, col in TORCH_COL.items():
        for r in range(FLAME_TOP, FLAME_TOP + CEL_H):
            for c in range(col, col + CEL_W):
                o = r * STRIDE + c
                if o in covered:
                    continue
                checked += 1
                if shot[o] != want[o]:
                    bad.append((t, r, c, shot[o], want[o]))
    if not bad:
        hidden = 2 * CEL_W * CEL_H - checked
        print(f"  PASS flame pixels are exactly cel {a.cel0}/{a.cel1} over the room: "
              f"{checked} bytes byte-identical"
              + (f" ({hidden} behind a character)" if hidden else ""))
        return 0 if checked else 1      # all of it hidden proves nothing

    print(f"  FAIL flame pixels wrong: {len(bad)} of {checked} bytes checked")
    names = {0: 'black', 1: 'orange', 2: 'BLUE', 3: 'white'}
    for t, r, c, got, exp in bad[:6]:
        gp = [names[(got >> (6 - 2 * k)) & 3] for k in range(4)]
        ep = [names[(exp >> (6 - 2 * k)) & 3] for k in range(4)]
        print(f"    torch {t} row {r} col {c}: got ${got:02X} {gp} want ${exp:02X} {ep}")
    return 1


if __name__ == '__main__':
    sys.exit(main())
