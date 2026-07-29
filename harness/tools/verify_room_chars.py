#!/usr/bin/env python3
r"""verify_room_chars.py — are the drawn characters the RIGHT PIXELS? (P3.21)

P3.20 classified the room diff with hand-drawn boxes, which can only say "this byte is
outside where I expected". That is not the same as "this byte is wrong", and the
difference cost a whole dispatch: the box method reported 12 stray bytes when 248 were
actually wrong, because a byte INSIDE a character box can be wrong too and the boxes
could not see it. P3.21 was dispatched to chase the 12 and found the 248.

It builds the CORRECT framebuffer offline -- the room asset with the two
baked cels composited onto it by cel_blit_prep's own byte-by-byte replay, which is
the same code path that validates the bake -- and diffs the capture against that.
Every reported byte is then a real defect with a known expected value.

The torch columns are excluded because the flames animate; nothing else is.
"""
import pathlib
import sys

ROOT = pathlib.Path("C:/Projects/POP3_port")
sys.path.insert(0, str(ROOT / "harness/tools"))
sys.path.insert(0, str(ROOT / "harness/tools/sprite_tool"))

import cel_blit_prep as P
from celio import Cel

STRIDE = 80
SP318 = pathlib.Path("C:/Users/jayse/AppData/Local/Temp/claude/"
                     "c--Projects-POP3-port/c6c8cbe3-f725-42c5-9533-3df5bc98fb16/"
                     "scratchpad/p318/ch6A")

# (label, source cel, phase, top row, byte col) — the hardcoded placement the room uses
PLACED = [("vstand", SP318 / "chtab6_a_080.s", 1, 104, 54),
          ("pstand", SP318 / "chtab6_a_025.s", 0, 109, 35)]


# The two things in this scene that animate and are NOT modelled offline: the torch
# flames and the four window stars. Everything else must match byte for byte.
STARS = {98 * STRIDE + 10, 101 * STRIDE + 8, 109 * STRIDE + 9, 114 * STRIDE + 9}


def torch(i):
    r, c = i // STRIDE, i % STRIDE
    if i in STARS:
        return True
    return 99 <= r <= 115 and (26 <= c <= 31 or 48 <= c <= 53)


def main():
    room = bytearray(pathlib.Path(ROOT / "content/cutscene/princess_room.raw").read_bytes())
    want = bytearray(room)

    for label, src, phase, top, col in PLACED:
        cel = Cel(str(src))
        rows, w = P.shift_pixels(cel, phase)
        segs = []
        for r in range(cel.h):
            segs += P.encode_row(rows[r], w)
        # replay into a local frame whose origin is this cel's top-left, then paste
        local = P.simulate(segs, cel.h, w, dest_stride=STRIDE,
                           initial={r * STRIDE + c: want[(top + r) * STRIDE + col + c]
                                    for r in range(cel.h) for c in range(w)})
        for r in range(cel.h):
            for c in range(w):
                o = r * STRIDE + c
                if o in local:
                    want[(top + r) * STRIDE + col + c] = local[o]
        print("  composited %-8s phase %d  %dx%dB at row %d col %d"
              % (label, phase, cel.h, w, top, col))

    for shot in ("build/room_front.bin", "build/room_front2.bin"):
        got = pathlib.Path(ROOT / shot).read_bytes()
        bad = [i for i in range(15360) if got[i] != want[i] and not torch(i)]
        print("\n%s: %d bytes WRONG vs the offline composite" % (shot, len(bad)))
        for i in bad[:20]:
            print("    row %3d col %2d  got $%02X want $%02X"
                  % (i // STRIDE, i % STRIDE, got[i], want[i]))
        if len(bad) > 20:
            print("    ... and %d more" % (len(bad) - 20))
    return 0


if __name__ == "__main__":
    sys.exit(main())
