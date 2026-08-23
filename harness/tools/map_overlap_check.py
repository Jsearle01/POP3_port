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

★★★ AND SINCE P5.16 IT CHECKS A CEILING TOO, FOR THE SAME REASON IN THE OTHER DIRECTION.
The intro's prog must end BELOW SCENE_BASE, because the scene's program is read to there as
a WHOLE TRACK -- 4,608 bytes for a program of about 1,200 -- so everything from SCENE_BASE
to SCENE_BASE+$1200 is overwritten at run time. Nothing in the link can see that: the two
regions never coexist in one map, so the overlap check above is structurally blind to it.

It has now happened TWICE, both times to lz_unpack.o, both times found by watching the
intro die rather than by reading a map:

    P4.47   SCENE_BASE $2500 clipped lz_unpack's last 14 bytes ($2480..$250D)
    P5.16   SCENE_BASE $2600 clipped its last 6      ($2578..$2606)

P4.47's own note says what went wrong with the response: "the map tool LISTED the two
regions overlapping and did not flag it." It then raised the constant and left the tool
alone, so the second occurrence was guaranteed. The symptom is expensive out of all
proportion to the cause -- the intro runs three beats, then beat 4 dies inside a routine
whose tail is gone, with the drive still engaged, 1,650 frames after the byte that did it.
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

# The scene program is read as a WHOLE TRACK, so SCENE_BASE..SCENE_BASE+this is clobbered
# at run time whatever the program's actual length. 18 sectors x 256 B.
SCENE_READ_LEN = 18 * 256


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
    ap.add_argument("--ceiling", action="append", default=[], metavar="MAP=ADDR",
                    help="a map whose sections must all END BELOW ADDR, e.g. "
                         "introseq.map=0x2700. Repeatable.")
    ap.add_argument("--loadat", action="append", default=[], metavar="MAP=ADDR",
                    help="a map whose `prog` section must load EXACTLY at ADDR — for an "
                         "image read to a fixed address by someone else. Repeatable.")
    args = ap.parse_args()
    floor = int(args.floor, 16) if args.floor else LOADM_FLOOR
    ceilings = {}
    for spec in args.ceiling:
        name, _, addr = spec.partition("=")
        ceilings[name.strip()] = int(addr, 16)
    loadats = {}
    for spec in args.loadat:
        name, _, addr = spec.partition("=")
        loadats[name.strip()] = int(addr, 16)

    bad = 0
    for mp in args.maps:
        p = pathlib.Path(mp)
        if not p.exists():
            continue
        secs = sorted(sections(mp), key=lambda s: s[2])
        # ★★ AN IMAGE READ TO A FIXED ADDRESS BY SOMEONE ELSE MUST BE LINKED AT THAT
        # ADDRESS, and nothing in the link can check it: the reader and the linked image
        # are different builds that never see each other. The address therefore has two
        # homes -- a variable in build.bat and a literal in the link script -- and P5.16
        # moved one without the other. The image linked $100 low, was read to the right
        # place, ran two disk reads off correctly-relative code and then died on the first
        # absolute jump. This makes that a build failure instead of a three-beat fuse.
        want = loadats.get(p.name)
        if want is not None:
            prog = [x for x in secs if x[0] == "prog"]
            if not prog:
                print("[map_check] ★ %s: no `prog` section to check against $%04X."
                      % (p.name, want))
                bad += 1
            elif prog[0][2] != want:
                print("[map_check] ★ %s: `prog` (%s) is LINKED at $%04X but is read "
                      "to $%04X — every absolute address inside it is off by %d. Set the "
                      "link script's `section prog load` to match SCENE_BASE."
                      % (p.name, prog[0][1], prog[0][2], want, want - prog[0][2]))
                bad += 1
        for i, (sn, obj, a, ln) in enumerate(secs):
            end = a + ln - 1
            if a < floor:
                print("[map_check] ★ %s: section `%s` (%s) at $%04X is BELOW the measured "
                      "LOADM floor $%04X — DECB's file buffers reach here and will corrupt "
                      "it as it loads." % (p.name, sn, obj, a, floor))
                bad += 1
            # ★ THE HAZARD IS OVERLAP WITH THE SCENE'S READ WINDOW, NOT "above an
            # address". A section living entirely ABOVE that window is untouched by it —
            # hal_build.o sits at $7900 and is perfectly safe — so a bare `end >= cap`
            # test reports it as a problem and teaches the reader to ignore the check.
            cap = ceilings.get(p.name)
            if cap is not None and a <= cap + SCENE_READ_LEN - 1 and end >= cap:
                print("[map_check] ★ %s: section `%s` (%s) $%04X..$%04X runs into "
                      "$%04X..$%04X, which is OVERWRITTEN AT RUN TIME — the scene program "
                      "is read there as a whole track (%d B for a program of ~1,200). "
                      "Raise SCENE_BASE in build.bat or shrink the image."
                      % (p.name, sn, obj, a, end, cap, cap + SCENE_READ_LEN - 1,
                         SCENE_READ_LEN))
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
    print("[map_check] %d map(s) clean — no overlap, nothing below $%04X%s%s."
          % (len(args.maps), floor,
             "".join(", %s all below $%04X" % (k, v) for k, v in sorted(ceilings.items())),
             "".join(", %s linked at $%04X" % (k, v) for k, v in sorted(loadats.items()))))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
