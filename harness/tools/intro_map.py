"""intro_map.py — P4.19: the intro's CPU memory map, and every gap in it.

★★★ WHY A TOOL AND NOT A TABLE IN A REPORT. The regions are declared in six places —
link/pop_engine.link, link/pop_flames.link, link/pop_scene.link, build.bat's
FLAME_BASE/SCENE_BASE/DR_VARBASE, intro_seq.s's BUNDLE/SAVE_BUF, and char_draw.s's peel
bases — and the sizes come from the link MAPS, which change with every build. A prose
table is out of date the moment an asset grows, and this project has been misled by a
stale map before: link/pop_engine.link's own header still says the disk parameter block
is at $1F00 when build.bat has passed $6A00 for many dispatches.

★★ AND THE QUESTION IT ANSWERS IS "WHAT IS LIVE WHEN", NOT "WHAT IS DECLARED". The
cutscene's peel buffers and the intro's caption save buffer never overlap in TIME, but a
resident player has to survive both, so for placement they both count as occupied. The
`live` column says which phase each region belongs to; the gap list assumes the strictest
case, which is the only safe one for something that must persist across the whole intro.

Run after build.bat. Reads the link maps for the true lengths.
"""
import argparse
import pathlib
import re
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

TRACE_RING = (0x7800, 0x78FF)
STACK_TOP = 0x7F00


def map_sections(path):
    out = []
    p = pathlib.Path(path)
    if not p.exists():
        return out
    for line in p.read_text(errors="replace").splitlines():
        m = re.match(r"Section: (\w+) \(([^)]+)\) load at ([0-9A-Fa-f]+), length ([0-9A-Fa-f]+)",
                     line.strip())
        if m:
            out.append((m.group(2).split("/")[-1], int(m.group(3), 16), int(m.group(4), 16)))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lo", default="0A00")
    ap.add_argument("--hi", default="7800")
    args = ap.parse_args()
    lo, hi = int(args.lo, 16), int(args.hi, 16)

    regions = []          # (start, end_inclusive, label, phase)

    for obj, a, ln in map_sections("build/obj/introseq.map"):
        if ln:
            regions.append((a, a + ln - 1, "engine: " + obj, "always"))
    for obj, a, ln in map_sections("build/obj/scene.map"):
        if ln and a < 0x7000:
            regions.append((a, a + ln - 1, "scene program: " + obj, "scene"))
    for obj, a, ln in map_sections("build/obj/flames.map"):
        if ln:
            regions.append((a, a + ln - 1, "scene bundle: " + obj, "scene"))

    # ★★★ DECB's own workspace, which is why nothing may LOAD below $0A00.
    # [intro_seq.s:145; karateka docs/project/decb-loadm-boot-gates.md; idioms §23]
    regions += [
        (0x02DC, 0x03D5, "DECB line-input buffer (typing EXEC lands here)", "always"),
        (0x0400, 0x05FF, "text screen (DECB prints OK)", "always"),
        (0x0600, 0x09FF, "DBUF0/DBUF1/FAT/FCBs -- LOADM itself uses these", "always"),
    ]
    # declared, not linked -- each with the file that owns it
    regions += [
        (0x3000, 0x52FF, "intro BUNDLE, 2 tracks [intro_seq.s:157]", "beats"),
        (0x5400, 0x68F1, "SAVE_BUF, TITLE save 5,361 B [intro_seq.s:160,181]", "beats"),
        (0x5800, 0x69FF, "scene packed-bundle landing [intro_seq.s:181]", "scene"),
        (0x6A00, 0x6A06, "DR_VARBASE, disk params [build.bat:117]", "always"),
        (0x6C00, 0x6FBF, "VIZ_PEEL 2x480 [char_draw.s:161]", "scene"),
        (0x6FC0, 0x727F, "PRI_PEEL 2x344 [char_draw.s:162]", "scene"),
        (TRACE_RING[0], TRACE_RING[1], "trace ring [pop_engine.link]", "always"),
    ]

    regions.sort()
    print("CPU $%04X..$%04X — the intro's map, from the link maps and the declaring files"
          % (lo, hi))
    print("%-9s %-9s %7s  %-9s %s" % ("start", "end", "bytes", "live", "what"))
    print("-" * 92)
    cur = lo
    gaps = []
    for a, b, label, phase in regions:
        if b < lo or a > hi:
            continue
        if a > cur:
            gaps.append((cur, a - 1))
            print("$%04X     $%04X     %7d  %-9s %s"
                  % (cur, a - 1, a - cur, "-", "FREE"))
        print("$%04X     $%04X     %7d  %-9s %s" % (a, b, b - a + 1, phase, label))
        cur = max(cur, b + 1)
    if cur <= hi:
        gaps.append((cur, hi))
        print("$%04X     $%04X     %7d  %-9s %s" % (cur, hi, hi - cur + 1, "-", "FREE"))

    print()
    print("GAPS a RESIDENT player could use (must survive every phase):")
    for a, b in sorted(gaps, key=lambda g: g[0] - g[1]):
        print("   $%04X..$%04X   %5d B" % (a, b, b - a + 1))
    print("   largest %d B; total %d B in %d pieces"
          % (max(b - a + 1 for a, b in gaps), sum(b - a + 1 for a, b in gaps), len(gaps)))
    print()
    print("★ The stack grows DOWN from $%04X and the kernel ends around $7D44, so the"
          % STACK_TOP)
    print("  443 bytes below the stack top are the stack's, not spare.")


if __name__ == "__main__":
    main()
