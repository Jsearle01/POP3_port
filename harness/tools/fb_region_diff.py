#!/usr/bin/env python3
r"""fb_region_diff.py — P3.87: diff two sets of displayed-framebuffer captures and say
WHERE they differ, by named region.

A count of differing bytes cannot distinguish "the flames are at a different phase" from
"a hole was punched through the hourglass", and those need opposite responses. So the
diff is attributed to the regions the engine itself defines:

    torches   rows 104..113  cols 27..29   [cutscene_room.s TORCH0_COL, room suite box]
    stars     rows  98..115  cols  8..10   [room_test.lua star_off]
    glass     rows 127..151  cols 38..44   [char_draw.s GLASS_TOP/GLASS_COL, 25 rows,
                                            7 bytes wide — the --phase 1 bake]
    sand      rows 141..149  cols 40..41   [FLOW_TOP/FLOW_COL/FLOW_ROWS/FLOW_WIDE]
    chars     everything else

The torches and the stars run on their own cadence and were decoupled from the animation
step at P3.72k, so at a matched STEP index their phase is a function of the pace and is
EXPECTED to differ when the pace changes. Nothing else is.
"""
import pathlib
import sys

STRIDE, ROWS = 80, 192

REGIONS = [
    ("sand", 141, 149, 40, 41),
    ("glass", 127, 151, 38, 44),
]

# ★★ THE TORCH/STAR EXCLUSION IS COPIED FROM verify_room_chars.torch(), VERBATIM, AND THE
# FIRST VERSION OF THIS FILE GOT IT WRONG IN THE MOST INSTRUCTIVE WAY.
#
# P3.87 wrote `("torches", 104, 113, 27, 29)` — ONE torch, taken from run_room_test.sh's
# log line "all inside the torch boxes (rows 104-113, cols 27-29)". That line is a message
# about the bytes that happened to change in two captures twelve frames apart. It is not
# the exclusion. The real predicate has TWO column ranges and wider rows:
#
#     99 <= r <= 115 and (26 <= c <= 31 or 48 <= c <= 53)
#
# The second torch at columns 48..53 sits directly inside the span P3.87 reported as
# character residue (rows 105..149, columns 44..57), so an unknown share of that "residue"
# was the OTHER TORCH AT A DIFFERENT FLICKER PHASE — which is expected between two builds
# running at different speeds and is exactly what the exclusion exists to remove.
#
# ★ This is §2H's third check failing in miniature: a description in the record (a log
# message) was cited instead of the fact (the predicate), in a file whose whole job is to
# decide what counts as a real difference. The stars come along for the same reason.
STARS = {98 * STRIDE + 10, 101 * STRIDE + 8, 109 * STRIDE + 9, 114 * STRIDE + 9}


def region_of(off):
    row, col = divmod(off, STRIDE)
    if off in STARS:
        return "stars"
    if 99 <= row <= 115 and (26 <= col <= 31 or 48 <= col <= 53):
        return "torches"
    for name, r0, r1, c0, c1 in REGIONS:
        if r0 <= row <= r1 and c0 <= col <= c1:
            return name
    return "chars/room"


def main(a_dir, a_pre, b_dir, b_pre):
    a_dir, b_dir = pathlib.Path(a_dir), pathlib.Path(b_dir)
    names = sorted(p.name[len(a_pre):] for p in a_dir.glob(a_pre + "*.bin"))
    if not names:
        sys.exit("no captures matching %s%s*.bin" % (a_dir, a_pre))
    total = {}
    worst = []
    for suffix in names:
        pa = a_dir / (a_pre + suffix)
        pb = b_dir / (b_pre + suffix)
        if not pb.exists():
            print("  MISSING %s" % pb)
            continue
        da, db = pa.read_bytes(), pb.read_bytes()
        if len(da) != len(db):
            sys.exit("size mismatch %s %d vs %d" % (suffix, len(da), len(db)))
        per = {}
        for i, (x, y) in enumerate(zip(da, db)):
            if x != y:
                r = region_of(i)
                per[r] = per.get(r, 0) + 1
                total[r] = total.get(r, 0) + 1
        tag = "  ".join("%s %d" % (k, v) for k, v in sorted(per.items())) or "IDENTICAL"
        print("  %-12s %s" % (suffix.replace(".bin", ""), tag))
        worst.append((sum(per.values()), suffix))

    print()
    print("  TOTAL by region over %d captures:" % len(names))
    for k, v in sorted(total.items()):
        print("    %-12s %d bytes" % (k, v))
    hard = total.get("chars/room", 0) + total.get("glass", 0) + total.get("sand", 0)
    print()
    if hard == 0:
        print("  VERDICT: RENDER-NEUTRAL outside the torch/star cadence "
              "(0 bytes differ in the room, the characters, the glass or the sand)")
    else:
        print("  VERDICT: NOT render-neutral — %d bytes differ outside the "
              "torch/star cadence" % hard)
    return 0 if hard == 0 else 1


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:5]))
