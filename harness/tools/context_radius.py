#!/usr/bin/env python3
r"""context_radius.py - P5.4 AC1. HOW FAR does the HGR->4-colour conversion actually reach?

★★★ THE DISPATCH'S HYPOTHESIS IS THAT THE DEPENDENCE IS LEFTWARD ONLY. It is not, and the
contract says so before any measurement does:

  _classify_row_convert [sprite_convert.py:103] gives each ON pixel
      (pos_in_run, run_len, gap_before_run, pal_bit)
  and convert_sprite_to_coco3 uses them as:
      run_len == 1                      -> chroma at the pixel's own screen-column parity
      pos_in_run == 0 and gap == 1      -> chroma at col-1, WHITE at col
      otherwise                         -> WHITE

  RIGHTWARD: `run_len == 1` asks whether the run ends immediately, which is ONE pixel to the
      right. The COLOUR-CELL FILL pass then reads src_indices[c+1] -- an already-classified
      index, which itself needed one pixel to ITS right -- so the reach is TWO.
  LEFTWARD: `pos_in_run == 0` is one pixel; `gap == 1` needs prev_run_end == run_start-2, so
      TWO; and the fill's src_indices[c-1] makes it two again.
  NOT A NEIGHBOUR AT ALL: the screen-column parity comes from `start_col`, i.e. from the
      PLACEMENT, not from surrounding pixels.
  ★ `pal_bit` looks unbounded -- it is bit 7 of the byte containing the RUN START, which may be
      far to the left -- but it is only ever read in the two branches that require the pixel to
      BE the run start (`run_len == 1`, `pos_in_run == 0`), so in practice it comes from the
      pixel's own byte.

So the reasoned bound is TWO PIXELS EACH SIDE. This file MEASURES it rather than trusting that,
by converting a real composited screen two ways:

  (a) the whole 280-pixel row at once            -- the reference the port must reproduce
  (b) in 28-pixel chunks (one tile block) with N pixels of true context on each side

and reporting the smallest N at which (b) reproduces (a) for every row of every screen.

Padding is by WHOLE APPLE BYTES so that `col//7`, `col%7` and the palette bit keep their
meaning; a pixel radius N is then obtained by zeroing the padding pixels beyond N. `start_col`
is offset by the padding so the parity term stays correct.
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

import bg_compose as B                                                  # noqa: E402
from hgr_screen_convert import deinterleave                             # noqa: E402
from sprite_convert import convert_sprite_to_coco3                      # noqa: E402

BLOCK_BYTES = 4          # one tile block is 4 Apple bytes = 28 pixels
PAD_BYTES = 2            # window padding; a pixel radius is masked out of this


def row_to_pixels(row_bytes):
    """40 Apple bytes -> (280 bit values, 40 palette bits)."""
    bits = []
    pal = []
    for b in row_bytes:
        pal.append((b >> 7) & 1)
        for k in range(7):
            bits.append((b >> k) & 1)
    return bits, pal


def pixels_to_bytes(bits, pal):
    out = bytearray()
    for i in range(len(pal)):
        v = pal[i] << 7
        for k in range(7):
            if bits[i * 7 + k]:
                v |= 1 << k
        out.append(v)
    return bytes(out)


def convert_row(row_bytes, start_col):
    """One row of Apple bytes -> a list of 4-colour palette indices, one per pixel."""
    packed, wb = convert_sprite_to_coco3(list(row_bytes), 1, len(row_bytes), start_col=start_col)
    px = []
    for b in packed[:wb]:
        px += [(b >> 6) & 3, (b >> 4) & 3, (b >> 2) & 3, b & 3]
    return px[:len(row_bytes) * 7]


def chunked(row_bytes, radius):
    """Convert in 4-byte chunks with `radius` pixels of true context each side."""
    nb = len(row_bytes)
    out = [0] * (nb * 7)
    bits, pal = row_to_pixels(row_bytes)
    for c0 in range(0, nb, BLOCK_BYTES):
        lo = max(0, c0 - PAD_BYTES)
        hi = min(nb, c0 + BLOCK_BYTES + PAD_BYTES)
        wb = list(row_bytes[lo:hi])
        wbits, wpal = row_to_pixels(wb)
        # keep only `radius` pixels of context on each side of the chunk
        chunk_lo_px = (c0 - lo) * 7
        chunk_hi_px = chunk_lo_px + BLOCK_BYTES * 7
        for i in range(len(wbits)):
            if i < chunk_lo_px - radius or i >= chunk_hi_px + radius:
                wbits[i] = 0
        win = pixels_to_bytes(wbits, wpal)
        got = convert_row(win, start_col=lo * 7)
        n = min(BLOCK_BYTES * 7, nb * 7 - c0 * 7)
        out[c0 * 7:c0 * 7 + n] = got[chunk_lo_px:chunk_lo_px + n]
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--level", default="LEVEL0")
    ap.add_argument("--bgset", default="DUN")
    ap.add_argument("--screens", default="1-24")
    ap.add_argument("--radii", default="0,1,2,3,4")
    args = ap.parse_args()

    lo, _, hi = args.screens.partition("-")
    screens = range(int(lo), int(hi or lo) + 1)
    radii = [int(x) for x in args.radii.split(",")]

    bp = B.Blueprint((B.LEVELS / args.level).read_bytes())
    bg1 = B.read_table(B.IMAGES / ("IMG.BGTAB1.%s" % args.bgset))
    bg2 = B.read_table(B.IMAGES / ("IMG.BGTAB2.%s" % args.bgset))

    print("CONTEXT RADIUS — %s, bgset %s, screens %s" % (args.level, args.bgset, args.screens))
    print("  reference = the whole 280-px row converted at once")
    print("  candidate = 28-px tile blocks converted with N pixels of true context each side")
    print()
    print("  %-8s %12s %12s %10s" % ("radius N", "px differing", "rows differing", "verdict"))

    pages = []
    for s in screens:
        r = B.Renderer(bp, bg1, bg2, level=int(args.level.replace("LEVEL", "")),
                       bgset1=0 if args.bgset == "DUN" else 1)
        r.sure(s)
        pages.append(deinterleave(bytes(r.paint().b)))

    for N in radii:
        bad_px = 0
        bad_rows = 0
        for rows in pages:
            for row in rows:
                ref = convert_row(row, start_col=0)
                got = chunked(row, N)
                d = sum(1 for a, b in zip(ref, got) if a != b)
                if d:
                    bad_px += d
                    bad_rows += 1
        print("  %-8d %12d %12d %10s"
              % (N, bad_px, bad_rows, "EXACT" if bad_px == 0 else ""))
        if bad_px == 0:
            print()
            print("  ★ SMALLEST EXACT RADIUS: %d pixels each side." % N)
            print("    A tile's conversion is therefore determined by its own pixels plus %d" % N)
            print("    pixel(s) of neighbour on each edge — a CLASSIFIABLE context, not a")
            print("    per-placement one.")
            return 0
    print()
    print("  ★ NO RADIUS IN %s WAS EXACT — the dependence reaches further than tested." % radii)
    return 1


if __name__ == "__main__":
    sys.exit(main())
