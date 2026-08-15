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
    ("torches", 104, 113, 27, 29),
    ("stars", 98, 115, 8, 10),
    ("sand", 141, 149, 40, 41),
    ("glass", 127, 151, 38, 44),
]


def region_of(off):
    row, col = divmod(off, STRIDE)
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
