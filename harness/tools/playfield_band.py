#!/usr/bin/env python3
r"""
playfield_band.py — PA.13: rasterize the PRINCE'S BODY BAND over the real world.

Supersedes the coverage column in playfield_census.py, which summed raw ink over the
band area and could exceed 100% (pieces are taller than the band and B/front spill
into neighbours). This one RASTERIZES: it places each contributing piece at its real
offset into a 28 x 41 band bitmap, clips, and counts covered pixels. No fraction can
exceed 100% and overlap is not double-counted.

GEOMETRY (all from source; see playfield_census.py's header for the citations)
  block = 28 px wide (4 bytes) x 63 lines.  DHeight = 3 -> the floor slab occupies
  block-local y 0..2 measured UP from the block bottom. The prince's feet rest at
  y = 3 and his tallest cel is 41 lines (measured, P1.2), so the BAND is y 3..43.

  Anchors (BGDATA.S): "A & B sections have l.l. of (X = BlockLeft, Y = BlockBot-3)"
  -> A at y = 3 + pieceay, B at y = 3 + pieceby, front at A's anchor + fronty and
  x + frontx. "l.l." = lower-left, and POP images are stored bottom-row-first
  (P1.2-fix), so an image extends UPWARD from its anchor.

WHAT CONTRIBUTES TO A BLOCK'S BAND (RedBlockSure, FRAMEADV.S)
  own A + own front + the LEFT neighbour's B.  (C is the below-left's and lands in
  the floor slab, not the band; D is the slab itself.)  `drawb` begins
  `lda objid / cmp #block / beq ]rts` — the B-section is SUPPRESSED when the block
  being drawn is a solid `block`. That condition is honoured here.

  NOT modelled: `drawa`'s conditional mask (it masks A against the left neighbour for
  panelwif/panelwof/pillartop/block/archtop1) and the various special-case front
  pieces (gate, slicer). Masking can only REMOVE ink, so excluding it makes this an
  UPPER BOUND on inked area — i.e. a LOWER bound on blackness. Stated, not hidden.

Usage:  python harness/tools/playfield_band.py
"""
import pathlib
import collections
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from playfield_census import (load_table, bgdata_tables, level_blocks, resolve,
                              BGTABLE1_BASE, BGTABLE2_BASE, PIECE_NAMES, IMAGES)

BLOCK_W_PX, DHEIGHT, PRINCE_H = 28, 3, 41
BAND_LO, BAND_HI = DHEIGHT, DHEIGHT + PRINCE_H - 1          # block-local y, inclusive
BLOCK_ID = 20


def img_pixels(img):
    """[(dx, dy)] of ON pixels, dy measured UP from the image's lower-left."""
    out = []
    w, h = img["w"], img["h"]
    for r in range(h):                     # row 0 = BOTTOM (P1.2-fix: bottom-first)
        for c in range(w):
            b = img["data"][r * w + c]
            for k in range(7):
                if (b >> k) & 1:
                    out.append((c * 7 + k, r))
    return out


def stamp(band, px, x0, y0):
    """Mark pixels into the 28-wide band raster. band is a set of (x,y)."""
    for dx, dy in px:
        x, y = x0 + dx, y0 + dy
        if 0 <= x < BLOCK_W_PX and BAND_LO <= y <= BAND_HI:
            band.add((x, y))


def main():
    bg = bgdata_tables()
    counts, grids = level_blocks()
    band_area = BLOCK_W_PX * PRINCE_H

    for theme, suffix in (("DUNGEON", "DUN"), ("PALACE", "PAL")):
        t1 = load_table(IMAGES / f"IMG.BGTAB1.{suffix}", BGTABLE1_BASE)
        t2 = load_table(IMAGES / f"IMG.BGTAB2.{suffix}", BGTABLE2_BASE)
        cache = {}

        def px_of(imgid):
            if imgid not in cache:
                im = resolve(imgid, t1, t2)
                cache[imgid] = img_pixels(im) if im else []
            return cache[imgid]

        # standable = the piece draws a D floor slab, so the prince can rest on it
        standable = {p for p in range(30) if bg["pieced"][p] != 0}

        tot_all = cov_all = 0
        tot_std = cov_std = 0
        per_type = collections.defaultdict(lambda: [0, 0])
        for lvl, screens in grids.items():
            for scr in screens:
                for row in range(len(scr)):
                    for col in range(len(scr[row])):
                        pid = scr[row][col]
                        band = set()
                        stamp(band, px_of(bg["piecea"][pid]), 0, DHEIGHT + bg["pieceay"][pid])
                        fi = bg["fronti"][pid]
                        if fi:
                            stamp(band, px_of(fi), bg["frontx"][pid] * 7,
                                  DHEIGHT + bg["pieceay"][pid] + bg["fronty"][pid])
                        # LEFT neighbour's B — suppressed when THIS block is solid
                        if col > 0 and pid != BLOCK_ID:
                            lp = scr[row][col - 1]
                            stamp(band, px_of(bg["pieceb"][lp]), 0, DHEIGHT + bg["pieceby"][lp])
                        c = len(band)
                        tot_all += band_area; cov_all += c
                        per_type[pid][0] += band_area; per_type[pid][1] += c
                        if pid in standable:
                            tot_std += band_area; cov_std += c

        print(f"\n=== {theme}: prince body band ({BLOCK_W_PX}x{PRINCE_H} px, y {BAND_LO}..{BAND_HI}) ===")
        print(f"    rasterized over {sum(counts.values()):,} real blocks "
              f"({len(grids)} levels x 24 screens x 30)")
        print(f"\n    {'piece':<14}{'blocks':>8}{'% world':>9}{'band INKED%':>13}{'band BLACK%':>13}")
        for pid, n in counts.most_common(10):
            a, c = per_type[pid]
            inked = 100 * c / a if a else 0.0
            print(f"    {PIECE_NAMES[pid]:<14}{n:>8,}{100*n/sum(counts.values()):>8.1f}%"
                  f"{inked:>12.2f}%{100-inked:>12.2f}%")
        print(f"\n    ALL blocks       : band {100*cov_all/tot_all:5.2f}% inked "
              f"=> {100-100*cov_all/tot_all:5.2f}% BLACK")
        print(f"    STANDABLE blocks : band {100*cov_std/tot_std:5.2f}% inked "
              f"=> {100-100*cov_std/tot_std:5.2f}% BLACK   "
              f"({tot_std//band_area:,} blocks, {100*(tot_std//band_area)/sum(counts.values()):.1f}% of world)")


if __name__ == "__main__":
    main()
