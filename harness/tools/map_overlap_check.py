"""map_overlap_check.py — P4.19: fail the build when linked sections collide.

★★★ WHY THIS IS A BUILD GATE AND NOT A README LINE. lwlink PLACES OVERLAPPING SECTIONS
SILENTLY. build.bat has said so since P3.2 — "check build/obj/introseq.map after ANY asset
change -- lwlink places overlapping sections silently, and did so three times in P3.2" —
and a check that asks a human to look is a check that eventually is not run.

★★ IT WAS NOT HYPOTHETICAL AT P4.19 EITHER. Placing the music player at $1000 put it at
$1000..$2167, straight through the engine's own load address at $2000. The link succeeded.
The binary loaded. The probe read back zeros and reported "the LOADM/EXEC did not take",
which is the signature of a completely different fault (the LOADM ceiling) and sent the
diagnosis one region the wrong way.

★ AND IT CHECKS THE LOADM FLOOR TOO, which is the other half of the same afternoon. DECB's
DBUF0/DBUF1/FAT/FCBs live at $0600-$09FF and its file control blocks reach ABOVE $0A00 —
measured by bisection, not read off a chart:

    msys at $0A00   the probe never started
    msys at $0C00   the probe never started
    msys at $0D00   it loaded and RAN, and emitted no sound at all   <- partial corruption
    msys at $0E00   PASS

$0D00 is the dangerous one: it produced a running program with silently damaged data. So
the floor a LOADM segment may use is $0E00, and it is asserted here rather than remembered.
"""
import argparse
import pathlib
import re
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

# ★ MEASURED (see the header), not read off DECB's documented workspace. The documented
#   top is $09FF; the observed one is $0DFF.
LOADM_FLOOR = 0x0E00


def sections(path):
    out = []
    for line in pathlib.Path(path).read_text(errors="replace").splitlines():
        m = re.match(r"Section: (\w+) \(([^)]+)\) load at ([0-9A-Fa-f]+), "
                     r"length ([0-9A-Fa-f]+)", line.strip())
        if m and int(m.group(4), 16):
            out.append((m.group(1), m.group(2).split("/")[-1],
                        int(m.group(3), 16), int(m.group(4), 16)))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("maps", nargs="+")
    ap.add_argument("--floor", default=None,
                    help="lowest address a LOADM segment may use (default $0E00)")
    args = ap.parse_args()
    floor = int(args.floor, 16) if args.floor else LOADM_FLOOR

    bad = 0
    for mp in args.maps:
        p = pathlib.Path(mp)
        if not p.exists():
            continue
        secs = sorted(sections(mp), key=lambda s: s[2])
        for i, (sn, obj, a, ln) in enumerate(secs):
            end = a + ln - 1
            if a < floor:
                print("[map_check] ★ %s: section `%s` (%s) at $%04X is BELOW the measured "
                      "LOADM floor $%04X — DECB's file buffers reach here and will corrupt "
                      "it as it loads." % (p.name, sn, obj, a, floor))
                bad += 1
            for sn2, obj2, a2, ln2 in secs[i + 1:]:
                if a2 <= end:
                    print("[map_check] ★ %s: `%s` (%s) $%04X..$%04X OVERLAPS `%s` (%s) "
                          "$%04X..$%04X — lwlink does this SILENTLY."
                          % (p.name, sn, obj, a, end, sn2, obj2, a2, a2 + ln2 - 1))
                    bad += 1
    if bad:
        print("[map_check] %d problem(s). This is a build failure, not a warning." % bad)
        return 1
    print("[map_check] %d map(s) clean — no overlap, nothing below $%04X."
          % (len(args.maps), floor))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
