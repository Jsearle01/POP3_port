#!/usr/bin/env python3
r"""demo_asset_census.py - P5.0. What the DEMO's assets are, and what they cost the port.

Answers the dispatch's AC5 (tile catalogue) and AC6 (character-sprite catalogue) from the
oracle's OWN data structures rather than from a count of source labels, because the count
that matters is the one on disk.

WHAT IT READS
  oracle/source/01 POP Source/Images/IMG.*      the cel tables, in POP's chtable format
  oracle/source/01 POP Source/Levels/LEVEL0     the demo blueprint, 2,304 B

WHY THE BASE ADDRESS IS DERIVED AND NOT PASSED
  A chtable's pointer list holds ABSOLUTE Apple addresses. sprite_convert.load_chtable
  takes `base` as an argument and defaults to $6000, which is right for chtable1 and wrong
  for five of the other files. Here the base is RECOVERED from the file itself: the record
  area starts immediately after the pointer list, so
        base = min(pointer) - (1 + 2*count)
  and the recovered value is reported, so a mismatch against GAMEEQ.S's equate is visible
  rather than absorbed.

PORT-SIDE COST
  The port stores a cel as 4-colour 2bpp: ceil(apple_w*7 / 4) bytes per row against the
  Apple's apple_w. That is the RAW bitmap figure -- the number the cel bank has to hold.
  It is NOT the compiled-sprite figure (PA.9), which is code and larger; the cutscene's
  bank holds raw cels and this census is about the bank.
"""
import pathlib
import sys

ROOT = pathlib.Path("C:/Projects/POP3_port")
IMAGES = ROOT / "oracle/source/01 POP Source/Images"
LEVELS = ROOT / "oracle/source/01 POP Source/Levels"


def read_table(path):
    """-> (base, [cel|None ...]).  Base recovered from the pointer list."""
    b = path.read_bytes()
    n = b[0]
    ptrs = [b[1 + 2 * i] | (b[2 + 2 * i] << 8) for i in range(n)]
    live = [p for p in ptrs if p]
    # Records begin 2 bytes past the pointer list in every one of these files
    # (checked: IMG.CHTAB1 hdr $83, first record $85). All 16 are assembled at
    # $6000 regardless of the runtime address the loader gives the table.
    hdr = 1 + 2 * n + 2
    base = min(live) - hdr if live else 0
    cels = []
    for p in ptrs:
        if not p:
            cels.append(None)
            continue
        off = p - base
        if not (0 <= off < len(b) - 1):
            cels.append(None)
            continue
        w, h = b[off], b[off + 1]
        cels.append(dict(w=w, h=h, off=off, nbytes=w * h))
    return base, cels, len(b)


def coco3_bytes(w, h):
    """Port-side raw 2bpp footprint of one cel."""
    return ((w * 7 + 3) // 4) * h


def main():
    rows = []
    for path in sorted(IMAGES.glob("IMG.*")):
        base, cels, flen = read_table(path)
        live = [c for c in cels if c]
        apple = sum(c["nbytes"] for c in live)
        coco = sum(coco3_bytes(c["w"], c["h"]) for c in live)
        hi = max((c["off"] + 2 + c["nbytes"]) for c in live) if live else 0
        rows.append(dict(name=path.name, flen=flen, base=base, slots=len(cels),
                         live=len(live), apple=apple, coco=coco, extent=hi,
                         maxw=max((c["w"] for c in live), default=0),
                         maxh=max((c["h"] for c in live), default=0)))

    print("%-18s %6s %6s %5s %5s %8s %8s %8s %s" %
          ("file", "bytes", "base", "slots", "live", "appleB", "coco3B", "extent", "max w x h"))
    for r in rows:
        print("%-18s %6d  $%04X %5d %5d %8d %8d %8d   %dx%d" %
              (r["name"], r["flen"], r["base"], r["slots"], r["live"],
               r["apple"], r["coco"], r["extent"], r["maxw"], r["maxh"]))

    print()
    print("TOTALS  apple=%d  coco3=%d  ratio=%.2f" %
          (sum(r["apple"] for r in rows), sum(r["coco"] for r in rows),
           sum(r["coco"] for r in rows) / max(1, sum(r["apple"] for r in rows))))

    # --- what the DEMO specifically needs -----------------------------------
    # level 0: bgset1=0 bgset2=0 chset=0  [MISC.S:770-772]
    demo = ["IMG.BGTAB1.DUN", "IMG.BGTAB2.DUN",       # bg set 0 = dungeon
            "IMG.CHTAB1", "IMG.CHTAB2", "IMG.CHTAB3",  # the kid, always resident
            "IMG.CHTAB4.GD",                           # char set 0 = guard
            "IMG.CHTAB5", "IMG.CHTAB6.A", "IMG.CHTAB6.B", "IMG.CHTAB7"]
    print()
    print("DEMO-RESIDENT SET (level 0: bgset 0 / chset 0):")
    ta = tc = 0
    for r in rows:
        if r["name"] in demo:
            print("  %-18s apple=%6d  coco3=%6d  cels=%d" %
                  (r["name"], r["apple"], r["coco"], r["live"]))
            ta += r["apple"]
            tc += r["coco"]
    print("  %-18s apple=%6d  coco3=%6d" % ("TOTAL", ta, tc))

    # --- the blueprint ------------------------------------------------------
    bp = (LEVELS / "LEVEL0").read_bytes()
    print()
    print("BLUEPRINT LEVEL0: %d bytes" % len(bp))
    bt = bp[0:720]
    types = [b & 0x1F for b in bt]
    used = sorted(set(types))
    print("  distinct piece IDs used: %d -> %s" % (len(used), used))
    hist = {}
    for t in types:
        hist[t] = hist.get(t, 0) + 1
    print("  piece histogram: %s" % sorted(hist.items(), key=lambda kv: -kv[1]))
    # non-blank screens: a screen is 30 blocks
    print("  screens (24), non-space block counts:")
    line = []
    for s in range(24):
        blocks = types[s * 30:(s + 1) * 30]
        line.append("%d:%d" % (s + 1, sum(1 for x in blocks if x != 0)))
    print("   ", " ".join(line))


if __name__ == "__main__":
    sys.exit(main())
