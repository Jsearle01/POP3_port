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
import cel_parity_rule as R
from celio import Cel

CENTRING = 20                     # the 280->320 offset; a multiple of 4, so phase-neutral
VIS_L, VIS_R = 5, 74              # the Apple's 280 px, centred: cols 5..74
FORE_L, FORE_R, FORE_T, FORE_B = 60, 62, 104, 151   # the rightmost pillar, Jay-confirmed

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
#   vizier   start_col 279 (ODD)   princess start_col 124/125   both Fdx=0
# CEL NUMBER -> (converted source, phase, rows). Keyed by the number the VM writes into
# the slot record, because with an interpreter running there is no fixed answer to
# "which cel is on screen" — it must be read from the machine, like the position.
# CEL NUMBER -> its converted source. The PHASE and COLUMN are no longer tabulated for
# anything: both are derived below from the oracle's own SETUPCHAR expression, so the
# engine picking a variant out of walk_tab and this compositing a shift from the source
# cel agree only if the table, the bake and the draw all line up.
# THE STEMS bake_scene.py ACTUALLY WRITES (P3.65). These were vwalk48_src.s .. and the
# bake renamed to v48_src.s when it grew to cover both characters. The old files are still
# on disk and byte-identical, so this kept passing while checking sources the build no
# longer produces — a checker quietly reading a different tree than the one under test.
# Named from the bake's own scheme so a rename breaks this loudly instead of silently.
def _src(who, cel):
    return ROOT / ("content/cutscene/chars/%s%d_src.s" % (who, cel))


SRC = {c: _src("v", c) for c in range(48, 57)}          # Vwalk / Vstop / Vstand
SRC.update({c: _src("p", c) for c in range(2, 10)})     # Palert, her eight turn cels
SRC.update({11: _src("p", 11),                          # Pstand
            1:  ROOT / "content/cutscene/chars/pslump_src.s",     # Pslump
            18: ROOT / "content/cutscene/chars/pslump_src.s"})


def mirrored(src):
    """The `_m` bake beside a source, when the machine says the cel was drawn facing right.

    A FACING DIMENSION, because Palert ends `aboutface` [SEQTABLE.S:1565] and from the
    scene's opening onward the princess's standing cel is the MIRRORED bake. This checker
    predated piece G and reconstructed every character from the unmirrored source, which
    was correct only while nobody turned -- and the whole point of the beat that was just
    restored is that she does. Falls back to the plain source when no mirrored bake
    exists, which is the honest behaviour for a character that never turns.
    """
    m = src.with_name(src.name.replace("_src.s", "_m_src.s"))
    return m if m.exists() else src

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
        if len(f) != 9:                  # tag + x,y,cel and facing, per character
            continue
        tag = f[0]
        vx, vy, vc, px, py, pc, vf, pfc = map(int, f[1:])
        rows = []
        for cel, x, y, face in ((vc, vx, vy, vf), (pc, px, py, pfc)):
            if cel not in SRC:
                raise SystemExit("  cel %d is on screen but has no baked source" % cel)
            # FACING FROM THE MACHINE, recorded at draw time (P3.71). -1/$FF is left and
            # NORMAL, anything else is right and MIRRORED [FRAMEADV.S:1970].
            right = (face != 0xFF)
            src = mirrored(SRC[cel]) if right else SRC[cel]
            h = cel_rows(src)
            # SETUPCHAR's own expression, from the ORACLE's tables — not from the port.
            # CharX is in two-pixel units and the parity bit is the odd pixel (P3.58).
            _img, fdx, _fdy, fcheck, _lab = R.altset2()[cel]
            spx = R.draw_x(x, fdx, fcheck, 0 if right else R.FACE_LEFT) + CENTRING
            rows.append(("cel%d" % cel, src, spx & 3, y - h + 1, spx >> 2))
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
            # CLIPPED TO THE VIRTUAL SCREEN, as the oracle clips every image to
            # LEFTCUT..RIGHTCUT in whole bytes [HIRES.S CROP] — RIGHTCUT 40, i.e. Apple
            # byte 39 / CoCo col 74. The vizier ENTERS through the right-hand door, so
            # for the first few steps most of him is off the edge; compositing him whole
            # called the correct clip 149 wrong bytes. The margins are $00 in the asset,
            # which is what makes blanking and clipping the same operation.
            for r in range(cel.h):
                for c in range(w):
                    o = r * STRIDE + c
                    if o not in local:
                        continue
                    dst = (top + r) * STRIDE + col + c
                    want[dst] = 0 if not (VIS_L <= col + c <= VIS_R) else local[o]
        # THE FOREGROUND PLANE GOES DOWN LAST, over every character (P3.60) — the
        # oracle's addfore ordering, which is what puts the vizier BEHIND the rightmost
        # pillar as he walks past it. Restored here from the ROOM ASSET, while the engine
        # fills $FF, so this stays an independent check of the fill rather than a copy of
        # its assumption: if that region were ever not solid white the two would disagree.
        for rr in range(FORE_T, FORE_B + 1):
            for cc in range(FORE_L, FORE_R + 1):
                want[rr * STRIDE + cc] = room[rr * STRIDE + cc]
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
