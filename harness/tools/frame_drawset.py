#!/usr/bin/env python3
r"""frame_drawset.py - P5.2. What ONE FRAME demands of the 15,872-byte CPU window.

★★★ THIS IS NOT P5.1's RESIDENCY NUMBER AND MUST NOT BE ADDED TO IT. W0 (8,219 B) is what
must be in physical RAM because the controller cannot intervene. This is the set that must be
MAPPED THROUGH THE WINDOW because a draw is about to read it. Different set, different
interval, and the project has merged that pair twice.

INPUT: oracle_frame_drawset.lua's log — one line per emulated frame, each record
`bank/tablebase/celaddr/w/h`, distinct cels only, captured by a WRITE tap on `setimage`'s
output [HIRES.S:270].

THE TABLE MAP is the oracle's own equates [GAMEEQ.S:9-18, EQ.S], keyed on (BANK, TABLE):
BANK 2 = main, 3 = aux [HIRES.S header]. The pair is needed because bgtable1 and chtable1
are BOTH $6000 — one in each bank — and so are bgtable2 and chtable2 at $8400.

PORT COST is the same currency P5.1 used and P5.2's dispatch re-confirmed: packed 4-colour
2 bpp, ceil(w*7/4) bytes per row.
"""
import pathlib
import statistics
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

TABLES = {
    (2, 0x6000): ("chtable1", "kid", "IMG.CHTAB1"),
    (2, 0x8400): ("chtable2", "kid", "IMG.CHTAB2"),
    (2, 0x0800): ("chtable3", "kid/sword", "IMG.CHTAB3"),
    (2, 0xA800): ("chtable5", "kid", "IMG.CHTAB5"),
    (3, 0x6000): ("bgtable1", "tile", "IMG.BGTAB1.DUN"),
    (3, 0x8400): ("bgtable2", "tile", "IMG.BGTAB2.DUN"),
    (3, 0x9600): ("chtable4", "opponent", "IMG.CHTAB4.GD"),
}

# ★★★ THE TAP CATCHES THREE THINGS AND ONLY ONE OF THEM IS A CEL.
#
#   EQ.S:384-385   height = IMAGE
#                  width  = IMAGE+1
#
# IMAGE IS ALIASED. `DRAWWIPE` [GRAFIX.S:545-547] writes a wipe's height and width through
# the same two bytes, and `LAYERSAVE`/`PEEL` write PEEL BUFFER addresses ($D000/$D800)
# there too. Read as a cel pointer, a wipe's (height=39, width=196) becomes address $C427
# and whatever two bytes live there become a plausible w/h -- which is how one frame
# "drew" 18,975 B out of chtable1 at $D800, i.e. out of peelbuf2.
#
# THE FILTER IS EXACT, NOT HEURISTIC: a genuine setimage result is one of the addresses in
# that table's own pointer list. The vendored Images are assembled at $6000, so cel i of a
# table loaded at B lives at B + (file_ptr_i - $6000). A record is kept only if its address
# is in that set AND the (w,h) READ OUT OF LIVE MEMORY equals the (w,h) in the file -- an
# agreement between the running machine and the vendored artefact, which is the check that
# makes the survivors evidence rather than assumption.
ROOT = pathlib.Path(__file__).resolve().parents[2]
IMAGES = ROOT / "oracle/source/01 POP Source/Images"


def load_valid():
    """-> {(bank, tablebase): {addr: (w, h)}}"""
    out = {}
    for (bank, base), (_, _, fname) in TABLES.items():
        b = (IMAGES / fname).read_bytes()
        n = b[0]
        d = {}
        for i in range(n):
            ptr = b[1 + 2 * i] | (b[2 + 2 * i] << 8)
            if not ptr:
                continue
            off = ptr - 0x6000
            if 0 <= off < len(b) - 1:
                d[base + off] = (b[off], b[off + 1])
        out[(bank, base)] = d
    return out


def coco3(w, h):
    return ((w * 7 + 3) // 4) * h


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "build/tmp/frame_drawset.txt"
    valid = load_valid()
    rows = []
    kept = dropped = mismatch = 0
    drop_reason = {}
    for ln in pathlib.Path(path).read_text().splitlines():
        if not ln.startswith("F "):
            continue
        p = ln.split()
        fn = int(p[1])
        cels = []
        for rec in p[2:]:
            if rec == "-":
                continue
            bank, tb, addr, w, h = rec.split("/")
            bank, tb, addr, w, h = int(bank), int(tb, 16), int(addr, 16), int(w), int(h)
            tv = valid.get((bank, tb))
            if tv is None:
                dropped += 1
                drop_reason["unknown table %d/$%04X" % (bank, tb)] =                     drop_reason.get("unknown table %d/$%04X" % (bank, tb), 0) + 1
                continue
            wh = tv.get(addr)
            if wh is None:
                dropped += 1
                drop_reason["not a cel pointer in that table"] =                     drop_reason.get("not a cel pointer in that table", 0) + 1
                continue
            if wh != (w, h):
                mismatch += 1
                continue
            kept += 1
            cels.append((bank, tb, addr, w, h))
        rows.append((fn, cels))
    print("RECORD VALIDATION (see the header — IMAGE is aliased as height/width)")
    print("  kept    %6d   address is in the table's pointer list AND live w/h == file w/h"
          % kept)
    print("  dropped %6d   %s" % (dropped, drop_reason))
    print("  w/h MISMATCH on a valid pointer: %d   (must be 0; any other value means the"
          % mismatch)
    print("                                       live table is not the vendored one)")
    print()

    # --- which frames are GAMEPLAY -----------------------------------------
    # ★ Identify by what is being DRAWN, not by reading a variable: P5.1's gotcha is that
    # mem:read_u8 is bank-dependent and MAIN/AUX validity is anti-correlated. A frame that
    # draws from bgtable1/2 AND a character table is a gameplay frame; the attract loop
    # after the demo ends draws whole-screen artwork through neither.
    def is_play(cels):
        kinds = {TABLES[(b, t)][1] for b, t, a, w, h in cels}
        return "tile" in kinds

    play = [(fn, c) for fn, c in rows if is_play(c)]
    first, last = (play[0][0], play[-1][0]) if play else (0, 0)
    span = [(fn, c) for fn, c in rows if first <= fn <= last]

    print("PER-FRAME DRAW SET — the demo, LEVEL0, measured on the running oracle")
    print("  frames logged            %d" % len(rows))
    print("  gameplay span            frames %d..%d  (%d frames, %.1f s at 59.92 Hz)"
          % (first, last, len(span), len(span) / 59.92))
    print("  frames drawing nothing   %d of the span" % sum(1 for _, c in span if not c))

    # --- the distribution ---------------------------------------------------
    def cost(cels):
        return sum(coco3(w, h) for _, _, _, w, h in cels)

    vals = [(cost(c), len(c), fn, c) for fn, c in span]
    nz = [v for v in vals if v[0] > 0]
    nz.sort()
    print()
    print("AC1 — DISTINCT CELS DRAWN PER FRAME, in port-side packed 4-colour bytes")
    print("  (a cel drawn twice costs the window nothing extra, so the set is deduplicated)")
    print("  %-26s %8s %8s" % ("", "bytes", "cels"))
    print("  %-26s %8d %8d" % ("min (of drawing frames)", nz[0][0], nz[0][1]))
    print("  %-26s %8d %8d" % ("median", nz[len(nz) // 2][0], nz[len(nz) // 2][1]))
    print("  %-26s %8d %8d" % ("p90", nz[int(len(nz) * 0.90)][0], nz[int(len(nz) * 0.90)][1]))
    print("  %-26s %8d %8d" % ("p99", nz[int(len(nz) * 0.99)][0], nz[int(len(nz) * 0.99)][1]))
    print("  %-26s %8d %8d   frame %d" % ("MAX", nz[-1][0], nz[-1][1], nz[-1][2]))
    print("  mean %d B over %d drawing frames" % (statistics.mean(v[0] for v in nz), len(nz)))

    # --- the worst frame, named by what was in it ---------------------------
    print()
    print("  THE WORST FRAME (%d), by what it drew:" % nz[-1][2])
    byk = {}
    for b, t, a, w, h in nz[-1][3]:
        nm, kind = TABLES[(b, t)][0], TABLES[(b, t)][1]
        byk.setdefault((nm, kind), []).append(coco3(w, h))
    for (nm, kind), v in sorted(byk.items(), key=lambda kv: -sum(kv[1])):
        print("    %-10s %-9s %2d cels  %6d B" % (nm, kind, len(v), sum(v)))

    # --- split by kind, across the span -------------------------------------
    print()
    print("  Split by kind, per frame (over drawing frames):")
    for kind in ("tile", "kid", "kid/sword", "opponent"):
        per = []
        for fn, c in span:
            s = sum(coco3(w, h) for b, t, a, w, h in c
                    if TABLES[(b, t)][1] == kind)
            if s:
                per.append(s)
        if per:
            per.sort()
            print("    %-10s frames %4d   median %5d B   max %5d B"
                  % (kind, len(per), per[len(per) // 2], per[-1]))

    # --- AC2: against the window --------------------------------------------
    WIN, PIN, ROT = 15872, 8192, 7680
    print()
    print("AC2 — AGAINST THE WINDOW")
    print("  the whole window        %6d B" % WIN)
    print("  pinned half  ($FFA6)    %6d B      rotating half ($FFA7)  %6d B" % (PIN, ROT))
    for tag, v in (("max", nz[-1][0]), ("p99", nz[int(len(nz) * 0.99)][0]),
                   ("median", nz[len(nz) // 2][0])):
        print("  %-6s %6d B  ->  window %-22s rotating half %s"
              % (tag, v,
                 "FITS, %d spare" % (WIN - v) if v <= WIN else "OVER by %d" % (v - WIN),
                 "FITS, %d spare" % (ROT - v) if v <= ROT else "OVER by %d" % (v - ROT)))

    # --- the ROOM-CHANGE bound ----------------------------------------------
    # SURE writes genCLS a second time, so a full composite can straddle bins. The maximum
    # over any THREE consecutive bins bounds it without tuning a threshold to the answer.
    best = (0, 0)
    for i in range(len(span) - 2):
        u = set()
        for j in (i, i + 1, i + 2):
            u.update(span[j][1])
        v = sum(coco3(w, h) for _, _, _, w, h in u)
        if v > best[0]:
            best = (v, i)
    u = set()
    for j in range(best[1], best[1] + 3):
        u.update(span[j][1])
    print()
    print("  MAX over any THREE consecutive bins (bounds a room change): %d B at frame %d"
          % (best[0], span[best[1]][0]))
    byk = {}
    for b, t, a, w, h in u:
        byk.setdefault(TABLES[(b, t)][1], []).append(coco3(w, h))
    for k, v in sorted(byk.items(), key=lambda kv: -sum(kv[1])):
        print("    %-10s %2d cels %6d B" % (k, len(v), sum(v)))
    print("    vs window 15,872 -> %s ; vs rotating half 7,680 -> %s"
          % ("FITS, %d spare" % (WIN - best[0]) if best[0] <= WIN else "OVER by %d" % (best[0] - WIN),
             "FITS, %d spare" % (ROT - best[0]) if best[0] <= ROT else "OVER by %d" % (best[0] - ROT)))
    ncomp = sum(1 for _, c in span
                if sum(1 for b, t, a, w, h in c if TABLES[(b, t)][1] == "tile") >= 15)
    print("    full-screen composites in the sample (>=15 tile cels): %d" % ncomp)

    # --- how many frames exceed each bound ----------------------------------
    print()
    for bound, nm in ((WIN, "the whole window 15,872"), (ROT, "the rotating half 7,680")):
        over = [v for v in nz if v[0] > bound]
        print("  frames exceeding %-24s %d of %d (%.2f%%)%s"
              % (nm, len(over), len(nz), 100.0 * len(over) / len(nz),
                 ("   worst %d B at frame %d" % (over[-1][0], over[-1][2])) if over else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
