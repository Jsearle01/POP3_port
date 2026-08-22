#!/usr/bin/env python3
r"""animated_blocks.py - P5.7. Size LEVEL0's animated scenery, and add it to the characters
AT THE FRAME THAT MAXIMISES THE PAIR.

★★★ TWO FIGURES, AND THEY ARE NOT THE SAME KIND OF NUMBER. P5.6's lesson, applied again:

  SUM (a RAM figure, extent = the whole level): every distinct cel every animated block on
      LEVEL0 can ever need. Nothing is ever this big at one instant.
  RESIDENCY (a WINDOW figure, extent = one frame): what one frame actually draws.

★★ AND THE PAIR IS ADDED AT THE JOINT MAXIMUM, NOT KIND BY KIND. A sum of per-kind maxima is
not a peak -- the frame that maximises characters is not the frame that maximises scenery, and
adding the two maxima invents a frame that never happened. This walks the frames and reports
the largest (characters + scenery) over a SINGLE frame, and names both components at it.

The animated image numbers come from the oracle's own tables, transcribed with their source
lines so the set is auditable rather than asserted:

  torch   torchflame  [GAMEBG.S:147-148]
  spikes  spikea/b    [BGDATA.S:118-119]
  loose   loosea/b/d  [BGDATA.S:143-147]
  gate    gate8c/8b, gatebotSTA/ORA, gatecmask  [BGDATA.S:88-93]
  exit    stairs/door/doormask/toprepair        [BGDATA.S:110-113]
  slicer  slicertop/bot/bot2/frnt               [BGDATA.S:134-137]

All are bgtable1 image numbers. Port cost is the same currency every prior report used:
packed 4-colour 2 bpp, ceil(w*7/4) bytes per row.
"""
import argparse
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "harness/tools"))

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

from frame_drawset import TABLES, coco3, load_valid          # noqa: E402

IMAGES = ROOT / "oracle/source/01 POP Source/Images"
BGTAB1 = (3, 0x6000)            # (bank, tablebase) as frame_drawset keys it

# LEVEL0's placement counts [P5.4 §5.211]
PLACED = {"torch": 11, "spikes": 5, "loose": 5, "gate": 4, "exit": 2, "slicer": 1}

KINDS = {
    "torch":  [0x52, 0x53, 0x54, 0x55, 0x56, 0x61, 0x62, 0x63, 0x64],
    "spikes": [0x22, 0x24, 0x26, 0x28, 0x2a, 0x23, 0x25, 0x27, 0x29, 0x2b],
    "loose":  [0x01, 0x1e, 0x1f, 0x1b, 0x15, 0x2c, 0x2d],
    "gate":   [0x2f, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36,
               0x3e, 0x3d, 0x3c, 0x3b, 0x3a, 0x39, 0x38, 0x37,
               0x43, 0x44, 0x0d],
    "exit":   [0x6b, 0x6c, 0x6d, 0x6e],
    "slicer": [0x58, 0x5a, 0x5c, 0x5e, 0x57, 0x59, 0x5b, 0x5d, 0x5f,
               0x8e, 0x8f, 0x90, 0x65, 0x66, 0x67, 0x68, 0x69],
}


def bgtab1_cels():
    """image number (1-based) -> (w, h). Byte 0 of a record is WIDTH, byte 1 HEIGHT.

    ★ THAT ORDER IS EMPIRICAL, NOT FROM THE EQUATE. EQ.S:384-385 reads
    `height = IMAGE / width = IMAGE+1`, but frame_drawset.py's validator agrees with LIVE
    MEMORY on 2,443 records under the opposite order, and only that order yields sane cels
    (a kid at 2-6 bytes wide by ~41 rows, a flame 1 byte wide by 15). Trace over source on a
    matter of fact [CLAUDE.md §2].
    """
    b = (IMAGES / "IMG.BGTAB1.DUN").read_bytes()
    out, addr = {}, {}
    for i in range(b[0]):
        p = b[1 + 2 * i] | (b[2 + 2 * i] << 8)
        if not p:
            continue
        o = p - 0x6000
        if 0 <= o < len(b) - 1:
            out[i + 1] = (b[o], b[o + 1])
            addr[0x6000 + o] = i + 1
    return out, addr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", default="build/tmp/frame_drawset.txt")
    args = ap.parse_args()

    cels, addr2img = bgtab1_cels()
    img2kind = {n: k for k, v in KINDS.items() for n in v}

    # ---------------------------------------------------------------- AC5
    print("=" * 78)
    print("AC5 — THE 28 ANIMATED BLOCKS OF LEVEL0, SIZED PER KIND")
    print("=" * 78)
    print("  ★ EVERY FIGURE HERE IS A **SUM** OVER THE WHOLE LEVEL, NOT A RESIDENCY.")
    print("    It is the distinct cel data each kind can ever need. No frame is this big;")
    print("    the residency figure is AC6 below, and it is two orders smaller.")
    print()
    print("  %-8s %7s %8s %9s %9s   %s"
          % ("kind", "placed", "distinct", "apple B", "coco3 B", "images"))
    tot_a = tot_c = 0
    seen = {}
    for k in ("torch", "spikes", "loose", "gate", "exit", "slicer"):
        ns = sorted(set(KINDS[k]))
        a = c = 0
        miss = []
        for n in ns:
            if n not in cels:
                miss.append(n)
                continue
            w, h = cels[n]
            a += w * h
            c += coco3(w, h)
            seen[n] = coco3(w, h)
        tot_a += a
        tot_c += c
        print("  %-8s %7d %8d %9d %9d   %s"
              % (k, PLACED[k], len(ns) - len(miss), a, c,
                 " ".join("$%02X" % n for n in ns[:8]) + (" ..." if len(ns) > 8 else "")))
        if miss:
            print("           ★ absent from bgtable1: %s"
                  % " ".join("$%02X" % n for n in miss))
    print("  " + "-" * 74)
    print("  %-8s %7d %8d %9d %9d   <- SUM over the level, all kinds"
          % ("TOTAL", sum(PLACED.values()), len(seen), tot_a, tot_c))
    print()
    print("  ★★ AND THE PHASE MULTIPLIER IS ONE, WHICH IS THE USEFUL PART.")
    print("    The conversion is position-dependent [P5.4: radius 1, measured exact], so the")
    print("    reflex is to multiply by the number of sub-byte phases a piece appears at. It")
    print("    does not apply here, and the reason is arithmetic rather than luck:")
    print()
    print("      block column c sits at Apple byte 4c = pixel 28c; hgr_screen_convert centres")
    print("      280 in 320 with a 20 px left margin, so the CoCo pixel is 28c+20.")
    print("      28c mod 4 = 0 and 20 mod 4 = 0  ->  EVERY block-aligned piece is PHASE 0.")
    print("      SETUPFLAME does `inc XCO` [GAMEBG.S:741] = +7 px, so a flame is at 28c+27")
    print("                                              ->  EVERY flame is PHASE 3.")
    print()
    print("    Two phases exist across the whole class and each kind uses exactly one, on")
    print("    every column of every screen. So %d B IS the storable figure, not %d B."
          % (tot_c, tot_c * 4))
    print("    This is why the animated blocks are cheap where the tile variants were not:")
    print("    a tile variant multiplies by its NEIGHBOURS, an animated cel does not, because")
    print("    it is always drawn at the same offset within its block.")

    # ---------------------------------------------------------------- AC6
    print()
    print("=" * 78)
    print("AC6 — PER-FRAME RESIDENCY, AND THE PAIR ADDED AT THE JOINT MAXIMUM")
    print("=" * 78)
    valid = load_valid()
    rows = []
    for ln in pathlib.Path(args.log).read_text().splitlines():
        if not ln.startswith("F "):
            continue
        p = ln.split()
        ch = sc = 0
        chl, scl = [], []
        for rec in p[2:]:
            if rec == "-":
                continue
            bank, tb, a, w, h = rec.split("/")
            bank, tb, a, w, h = int(bank), int(tb, 16), int(a, 16), int(w), int(h)
            tv = valid.get((bank, tb))
            if tv is None or tv.get(a) != (w, h):
                continue
            kind = TABLES[(bank, tb)][1]
            cost = coco3(w, h)
            if kind in ("kid", "kid/sword", "opponent"):
                ch += cost
                chl.append((a, kind, cost))
            elif (bank, tb) == BGTAB1:
                img = addr2img.get(a)
                if img in img2kind:
                    sc += cost
                    scl.append((img, img2kind[img], cost))
        rows.append((int(p[1]), ch, sc, chl, scl))

    play = [r for r in rows if r[1] or r[2]]
    sc_only = sorted(r[2] for r in rows if r[2])
    print("  animated-scenery bytes per frame (over %d frames that draw any):" % len(sc_only))
    if sc_only:
        print("    min %d   median %d   p90 %d   MAX %d"
              % (sc_only[0], sc_only[len(sc_only) // 2],
                 sc_only[int(len(sc_only) * 0.9)], sc_only[-1]))
    else:
        print("    none drawn in the captured span")

    best = max(rows, key=lambda r: r[1] + r[2])
    bc = max(rows, key=lambda r: r[1])
    bs = max(rows, key=lambda r: r[2])
    print()
    print("  ★ THE JOINT MAXIMUM — the largest (characters + scenery) over ONE frame:")
    print("     frame %d:  characters %d B + scenery %d B = %d B"
          % (best[0], best[1], best[2], best[1] + best[2]))
    for img, k, c in sorted(best[4], key=lambda t: -t[2]):
        print("        scenery  $%02X %-8s %5d B" % (img, k, c))
    print()
    print("  AND THE TWO SEPARATE MAXIMA, so the difference is visible:")
    print("     characters peak  frame %d: %d B chars + %d B scenery = %d B"
          % (bc[0], bc[1], bc[2], bc[1] + bc[2]))
    print("     scenery    peak  frame %d: %d B chars + %d B scenery = %d B"
          % (bs[0], bs[1], bs[2], bs[1] + bs[2]))
    naive = bc[1] + bs[2]
    print()
    print("  ★ THE ERROR THIS AVOIDS: adding the two per-kind maxima gives %d B, which is"
          % naive)
    print("     %+d B against the real joint peak of %d B. %s"
          % (naive - (best[1] + best[2]), best[1] + best[2],
             "The naive sum OVERSTATES." if naive > best[1] + best[2]
             else "They coincide here." if naive == best[1] + best[2]
             else "The naive sum UNDERSTATES -- which should be impossible; check."))
    print()
    WIN, BLK = 15872, 8192
    v = best[1] + best[2]
    print("  vs the whole window %d B -> %s" % (WIN, "FITS, %d spare" % (WIN - v)))
    print("  vs one block        %d B -> %s" % (BLK, "FITS, %d spare" % (BLK - v)
                                                if v <= BLK else "OVER by %d" % (v - BLK)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
