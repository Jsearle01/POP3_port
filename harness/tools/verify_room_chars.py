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
# The converted sources IN THE REPO, not the P3.18 scratch dump. The scratch copies
# were converted at start_col=0, which is the wrong Apple screen-column PARITY for
# where these characters actually stand — Jay saw it as orange and blue swapped.
# Verifying against them would have confirmed the bug instead of catching it, which is
# the whole hazard of a checker sharing its input with the thing it checks.
#   vizier   start_col 197 (ODD)   princess start_col 120 (EVEN)   both Fdx=0
# CEL NUMBER -> (converted source, phase, rows). Keyed by the number the VM writes into
# the slot record, because with an interpreter running there is no fixed answer to
# "which cel is on screen" — it must be read from the machine, like the position.
CELS = {54: (ROOT / "content/cutscene/chars/vstand_src.s", 1, 48),   # Vstand
        11: (ROOT / "content/cutscene/chars/pstand_src.s", 0, 43),   # Pstand
        1:  (ROOT / "content/cutscene/chars/pslump_src.s", 0, 43),   # Pslump
        18: (ROOT / "content/cutscene/chars/pslump_src.s", 0, 43)}   # Pslump, same image

# THE WALK'S CELS CARRY NO FIXED PHASE, and that is the whole difference (P3.31). Every
# cel above is drawn at one sub-byte phase for the life of the scene, so the phase could
# be written next to it. Cels 48-53 are drawn at TWO, alternating as x moves 10 px per
# cycle, so the phase is a function of the position -- and the position is read off the
# machine. Deriving it here with co_setup's own expression is what keeps this a CHECK:
# the engine picks a variant out of walk_tab, this composites the shift from the source
# cel, and the two agree only if the table, the bake and the draw all line up.
#
# Fdx is 0 for every walk cel [ALTSET2 via cel_parity_rule], so it is not carried here;
# a walk cel with a non-zero Fdx would need it, and cel_table.s is where it lives.
WALK = {c: ROOT / ("content/cutscene/chars/vwalk%d_src.s" % c) for c in range(48, 54)}
POSFILE = ROOT / "build/room_chars_pos.txt"


def cel_rows(src):
    """The cel's own row count, read from the converted source rather than tabulated."""
    return Cel(str(src)).h


def placements(posfile=None):
    """[(tag, [(label, src, phase, top, col), ...]), ...] from the recorded state."""
    pf = pathlib.Path(posfile) if posfile else POSFILE
    if not pf.exists():
        raise SystemExit("  no %s — run the room test first" % pf)
    out = []
    for line in pf.read_text().splitlines():
        f = line.split()
        if len(f) != 7:
            continue
        tag = f[0]
        vx, vy, vc, px, py, pc = map(int, f[1:])
        rows = []
        for cel, x, y in ((vc, vx, vy), (pc, px, py)):
            if cel in WALK:
                src, phase = WALK[cel], (x + 20) & 3
                h = cel_rows(src)
            elif cel in CELS:
                src, phase, h = CELS[cel]
            else:
                raise SystemExit("  cel %d is on screen but has no baked source" % cel)
            rows.append(("cel%d" % cel, src, phase, y - h + 1, (x + 20) >> 2))
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
    # --pos/--shots let the WALK run reuse this unchanged: same check, more captures.
    # Two captures 12 frames apart can only see the walk's start, and "byte-exact at the
    # start" is precisely what an accumulating bug looks like.
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('--pos', help='positions file (default build/room_chars_pos.txt)')
    ap.add_argument('--shots', help='printf pattern for capture files, %%s = tag')
    a = ap.parse_args()

    room = pathlib.Path(ROOT / "content/cutscene/princess_room.raw").read_bytes()
    shots = {"first": "build/room_front.bin", "second": "build/room_front2.bin"}
    rc = 0
    seen = []
    for tag, rows in placements(a.pos):
        if a.shots:
            shots[tag] = a.shots % tag
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
    #
    # BUT DISAGREEING COUNTS ONLY MEAN THAT WHEN THE CAPTURES SHOW THE SAME SCENE. The
    # walk never repeats a position, so "the counts differ" is what a moving character
    # looks like whether or not anything is wrong, and reading it as an accumulating bug
    # would be the fifth variant of a checker assuming the state it checks. Captures at
    # the SAME position must agree; captures at different ones are compared ACROSS RUNS
    # instead (run_walk_test.sh runs the machine twice and diffs).
    counts = {n for _, n, _ in seen}
    by_pos = {}
    for _, n, p in seen:
        by_pos.setdefault(p, set()).add(n)
    unstable = {p: sorted(v) for p, v in by_pos.items() if len(v) > 1}
    if unstable:
        print("  stability: SAME POSITION, DIFFERENT RESULT %s — accumulating state bug"
              % list(unstable.values())[:3])
        rc = 1
    elif len(by_pos) == len(seen) and len(seen) > 2:
        print("  stability: %d captures, every one a different position — no repeat to "
              "compare within this run; %s"
              % (len(seen), "all clean" if counts == {0}
                 else "worst %d wrong" % max(counts)))
    else:
        print("  stability: %s"
              % ("all captures agree (%s)" % sorted(counts)[0] if len(counts) == 1
                 else "CAPTURES DISAGREE %s — accumulating state bug" % sorted(counts)))
        if len(counts) > 1:
            rc = 1
    return rc


if __name__ == "__main__":
    sys.exit(main())
