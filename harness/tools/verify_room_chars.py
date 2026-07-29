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

# (label, source cel, phase) — the POSITION is read from the machine, not assumed.
# P3.22: the characters move, so compositing at a fixed x reported a correct move as
# 231 wrong bytes. room_test.lua records each capture's actual x/y out of the slot
# records and this reads them back. A pixel check that assumes a position cannot
# distinguish "drew in the wrong place" from "moved, as designed".
CELS = {"vstand": (SP318 / "chtab6_a_080.s", 1),
        "pstand": (SP318 / "chtab6_a_025.s", 0)}
POSFILE = ROOT / "build/room_chars_pos.txt"
FLOOR_H = {"vstand": 48, "pstand": 43}


def placements():
    """[(tag, [(label, src, phase, top, col), ...]), ...] from the recorded positions."""
    if not POSFILE.exists():
        raise SystemExit("  no build/room_chars_pos.txt — run the room test first")
    out = []
    for line in POSFILE.read_text().splitlines():
        f = line.split()
        if len(f) != 5:
            continue
        tag, vx, vy, px, py = f[0], *map(int, f[1:])
        rows = []
        for label, x, y in (("vstand", vx, vy), ("pstand", px, py)):
            src, phase = CELS[label]
            h = FLOOR_H[label]
            rows.append((label, src, phase, y - h + 1, (x + 20) >> 2))
        out.append((tag, rows))
    return out


# The two things in this scene that animate and are NOT modelled offline: the torch
# flames and the four window stars. Everything else must match byte for byte.
STARS = {98 * STRIDE + 10, 101 * STRIDE + 8, 109 * STRIDE + 9, 114 * STRIDE + 9}


def torch(i):
    r, c = i // STRIDE, i % STRIDE
    if i in STARS:
        return True
    return 99 <= r <= 115 and (26 <= c <= 31 or 48 <= c <= 53)


def main():
    room = pathlib.Path(ROOT / "content/cutscene/princess_room.raw").read_bytes()
    shots = {"first": "build/room_front.bin", "second": "build/room_front2.bin"}
    rc = 0
    seen = []
    for tag, rows in placements():
        want = bytearray(room)
        for label, src, phase, top, col in rows:
            cel = Cel(str(src))
            r_px, w = P.shift_pixels(cel, phase)
            segs = []
            for r in range(cel.h):
                segs += P.encode_row(r_px[r], w)
            local = P.simulate(segs, cel.h, w, dest_stride=STRIDE,
                               initial={r * STRIDE + c: want[(top + r) * STRIDE + col + c]
                                        for r in range(cel.h) for c in range(w)})
            for r in range(cel.h):
                for c in range(w):
                    o = r * STRIDE + c
                    if o in local:
                        want[(top + r) * STRIDE + col + c] = local[o]
        shot = pathlib.Path(ROOT / shots[tag]).read_bytes()
        bad = [i for i in range(15360) if shot[i] != want[i] and not torch(i)]
        pos = ", ".join("%s top %d col %d" % (l, tp, cl) for l, _, _, tp, cl in rows)
        print("  %-7s (%s): %d bytes WRONG" % (tag, pos, len(bad)))
        for i in bad[:8]:
            print("      row %3d col %2d  got $%02X want $%02X"
                  % (i // STRIDE, i % STRIDE, shot[i], want[i]))
        seen.append((tag, len(bad), pos))
        if bad:
            rc = 1
    # STABILITY: an accumulating state bug shows up as captures disagreeing, not as a
    # stable wrong number (P3.21 bug 2 presented exactly that way — 36 vs 33).
    counts = {n for _, n, _ in seen}
    moved = len({p for _, _, p in seen}) > 1
    print("  stability: %s%s"
          % ("all captures agree (%s)" % counts.pop() if len(counts) == 1
             else "CAPTURES DISAGREE %s — accumulating state bug" % sorted(counts),
             "; the character MOVED between captures" if moved else "; position static"))
    return rc


if __name__ == "__main__":
    sys.exit(main())
