#!/usr/bin/env python3
r"""tile_composite_check.py - P5.3 Phase 3, the question that has to be answered BEFORE any
engine code: can the port composite a screen from PER-CEL 4-colour conversions and land on the
same bytes `bg_compose.py` produces?

★★★ WHY THIS IS NOT OBVIOUS, AND WHY IT IS THE FIRST THING BUILT.
`bg_compose.py` composites in APPLE HGR SPACE -- 1 bit per pixel plus the palette bit -- and
converts the finished page to 4 colours ONCE, at the end. The port has no HGR framebuffer. It
must convert each cel ONCE at bake time and composite the 4-colour results.

Those are not the same operation. The HGR->4-colour model is NEIGHBOUR-DEPENDENT: a pixel's
colour depends on the run it belongs to, the gap before that run, and the parity of its screen
column [sprite_convert.convert_sprite_to_coco3]. Two cels that abut in HGR have pixels that are
adjacent, and converting them separately cannot see across the seam.

So the port and the compositor may DISAGREE AT EVERY CEL BOUNDARY, and the gate release predicts
they will be byte-identical. This measures it instead of assuming either way.

WHAT IT BUILDS
  A: bg_compose.py's HGR page -> hgr_screen_convert -> 15,360 B framebuffer   (the reference)
  B: each cel converted alone at its own start_col, composited in 4-colour     (what a port can do)

THE GEOMETRY, which is the part that must not be hand-waved:
  An HGR byte column `xco` is Apple pixel column xco*7. hgr_screen_convert maps 280 content
  pixels to 70 bytes at 4 px/byte with a 5-byte left margin, so Apple pixel p lands at
  framebuffer byte 5 + p//4, sub-byte phase p%4. For a BLOCK section xco is a multiple of 4
  (blockxco = colno*4), so xco*7 is a multiple of 28 and the phase is 0. FRONT pieces add
  frontx[objid] (0..3), so they land on phases 21%4=1, 14%4=2, 7%4=3 -- the phase machinery the
  blitter already has.

OPACITY, mapped from HGR to 4 colours:
  sta  -> write every pixel                        (opaque)
  ora  -> write non-black pixels only              (index 0 is transparency)
  and  -> the HGR mask. There is no 4-colour equivalent of a bitwise AND on palette indices,
          so this is reported separately rather than modelled: see the output.
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
from sprite_convert import convert_sprite_to_coco3                      # noqa: E402

FB_STRIDE, FB_ROWS = 80, 192
LEFT_MARGIN = 5


def cel_pixels(cel, start_col):
    """A cel -> list of rows, each a list of 2-bit palette indices, TOP ROW FIRST.

    POP cels are stored BOTTOM-ROW-FIRST [project-state.md, P1.2-fix, Jay-confirmed], and
    bg_compose's Page.lay walks them bottom-up. convert_sprite_to_coco3 takes them in storage
    order and returns packed bytes in the same order, so the rows are reversed here to give
    display order.
    """
    w, h, data = cel
    packed, wbytes = convert_sprite_to_coco3(list(data), h, w, start_col=start_col)
    rows = []
    for r in range(h):
        by = packed[r * wbytes:(r + 1) * wbytes]
        px = []
        for b in by:
            px += [(b >> 6) & 3, (b >> 4) & 3, (b >> 2) & 3, b & 3]
        rows.append(px)
    return rows[::-1]          # storage order is bottom-first; return top-first


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--level", default="LEVEL0")
    ap.add_argument("--screen", type=int, default=1)
    ap.add_argument("--bgset", default="DUN")
    ap.add_argument("--out", default=None)
    ap.add_argument("--ref", default=None, help="the HGR-composited framebuffer to diff against")
    args = ap.parse_args()

    bp = B.Blueprint((B.LEVELS / args.level).read_bytes())
    bg1 = B.read_table(B.IMAGES / ("IMG.BGTAB1.%s" % args.bgset))
    bg2 = B.read_table(B.IMAGES / ("IMG.BGTAB2.%s" % args.bgset))
    tabs = (bg1, bg2)

    r = B.Renderer(bp, bg1, bg2, level=int(args.level.replace("LEVEL", "")),
                   bgset1=0 if args.bgset == "DUN" else 1)
    r.sure(args.screen)

    # ---- B: composite in 4 colours from per-cel conversions ------------------
    fb = bytearray(FB_STRIDE * FB_ROWS)
    ops = {"sta": 0, "ora": 0, "and": 0, "mask": 0, "eor": 0}
    nonzero_phase = 0
    for image, xco, yco, op in r.bg + r.fg:
        tab = tabs[1] if image & 0x80 else tabs[0]
        i = (image & 0x7F) - 1
        if not (0 <= i < len(tab)) or tab[i] is None:
            continue
        cel = tab[i]
        w, h, _ = cel
        name = {B.OP_STA: "sta", B.OP_ORA: "ora", B.OP_AND: "and",
                B.OP_MASK: "mask", B.OP_EOR: "eor"}[op]
        ops[name] += 1
        px_col = xco * 7
        if px_col % 4:
            nonzero_phase += 1
        rows = cel_pixels(cel, start_col=px_col)
        top = yco - h + 1
        for ri, row in enumerate(rows):
            y = top + ri
            if not (0 <= y < FB_ROWS):
                continue
            for ci, v in enumerate(row):
                p = px_col + ci
                fbx = LEFT_MARGIN * 4 + p          # framebuffer PIXEL column
                if not (0 <= fbx < FB_STRIDE * 4):
                    continue
                if op == B.OP_ORA and v == 0:
                    continue                        # index 0 is transparency
                if op in (B.OP_AND, B.OP_MASK):
                    continue                        # see the header; counted, not modelled
                byi = y * FB_STRIDE + (fbx >> 2)
                sh = 6 - 2 * (fbx & 3)
                fb[byi] = (fb[byi] & ~(3 << sh)) | (v << sh)

    print("screen %d: %d display-list entries" % (args.screen, len(r.bg) + len(r.fg)))
    print("  opacity mix: %s" % {k: v for k, v in ops.items() if v})
    print("  entries at a non-zero sub-byte phase: %d" % nonzero_phase)
    if args.out:
        pathlib.Path(args.out).write_bytes(bytes(fb))
        print("  -> %s (%d B)" % (args.out, len(fb)))

    if args.ref:
        ref = pathlib.Path(args.ref).read_bytes()
        same = sum(1 for a, b in zip(fb, ref) if a == b)
        diff = len(ref) - same
        print("  vs %s: %d/%d bytes identical (%.2f%%), %d differ"
              % (args.ref, same, len(ref), 100.0 * same / len(ref), diff))
        rowdiff = {}
        for y in range(FB_ROWS):
            n = sum(1 for x in range(FB_STRIDE)
                    if fb[y * FB_STRIDE + x] != ref[y * FB_STRIDE + x])
            if n:
                rowdiff[y] = n
        print("  differing rows: %d of 192" % len(rowdiff))
    return 0


if __name__ == "__main__":
    sys.exit(main())
