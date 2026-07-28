#!/usr/bin/env python3
r"""hgr_screen_convert.py — an Apple II HGR *screen* -> a CoCo3 320x192x4 framebuffer.

WHY THIS EXISTS. sprite_convert.py converts CELS: a rectangular bitmap out of a
chtable. The princess's room is not a cel and is not a picture anywhere in the
oracle -- it is a tiled block layout the background renderer assembles at run time.
Porting that renderer is the animation-engine work (piece C), so for the static room
(piece A) the room is acquired the way P3.2 acquired its reference: dumped from the
running oracle and converted.

TWO THINGS THIS ADDS, AND NOTHING ELSE:

 1. THE HGR MEMORY LAYOUT. The Apple II hires page is famously not row-major. Row y
    lives at
        base = page + (y & 7) * 0x400 + ((y >> 3) & 7) * 0x80 + (y >> 6) * 0x28
    for 40 bytes. De-interleaving that is the whole difference between a screen and
    a cel.

 2. THE VIRTUAL-RESOLUTION CONTRACT. 280 content pixels -> 70 CoCo3 bytes at 4 px
    per byte, centred in an 80-byte row: 5 bytes of margin each side, which is the
    +20 px of the 280->320 centring. Rows are 1:1. Same contract the intro screens
    are built to, applied at conversion time so the destination IS the framebuffer.

THE COLOUR MODEL IS NOT REDERIVED. convert_sprite_to_coco3 from sprite_convert.py is
called directly, with start_col=0 because a screen starts at screen column 0 by
definition (the one POP-specific variable that file documents). Reimplementing the
parity/gap rules here would be a second, divergent copy of a model that is deliberately
frozen and provable byte-identical to Karateka's.
"""
import argparse
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from sprite_convert import convert_sprite_to_coco3      # noqa: E402

HGR_ROWS = 192
HGR_ROW_BYTES = 40
FB_STRIDE = 80          # 320 px at 4 px/byte
CONTENT_BYTES = 70      # 280 px at 4 px/byte
LEFT_MARGIN = (FB_STRIDE - CONTENT_BYTES) // 2      # 5 bytes = 20 px


def deinterleave(page):
    """HGR page bytes -> 192 rows of 40, in display order."""
    rows = []
    for y in range(HGR_ROWS):
        base = (y & 7) * 0x400 + ((y >> 3) & 7) * 0x80 + (y >> 6) * 0x28
        rows.append(page[base:base + HGR_ROW_BYTES])
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--page', required=True, help='an 8192-byte HGR page dump')
    ap.add_argument('--out', required=True, help='320x192x4 framebuffer (15,360 B)')
    ap.add_argument('--fill', type=lambda s: int(s, 0), default=0,
                    help='margin fill index (default 0 = black)')
    a = ap.parse_args()

    page = pathlib.Path(a.page).read_bytes()
    if len(page) != 8192:
        sys.exit(f"expected an 8192-byte page, got {len(page)}")

    rows = deinterleave(page)
    flat = b''.join(rows)
    bitmap, width = convert_sprite_to_coco3(flat, HGR_ROWS, HGR_ROW_BYTES, start_col=0)
    if width != CONTENT_BYTES:
        sys.exit(f"converter returned {width} bytes/row, expected {CONTENT_BYTES}")

    fb = bytearray([a.fill]) * (FB_STRIDE * HGR_ROWS)
    for y in range(HGR_ROWS):
        src = bitmap[y * width:(y + 1) * width]
        o = y * FB_STRIDE + LEFT_MARGIN
        fb[o:o + width] = src
    pathlib.Path(a.out).write_bytes(bytes(fb))

    hist = {}
    for b in fb:
        for k in range(4):
            hist[(b >> (6 - 2 * k)) & 3] = hist.get((b >> (6 - 2 * k)) & 3, 0) + 1
    tot = sum(hist.values())
    print(f"{a.out}: {len(fb)} B framebuffer, {HGR_ROWS} rows x {FB_STRIDE} B, "
          f"content at bytes {LEFT_MARGIN}..{LEFT_MARGIN + width - 1}")
    print("  palette index use: " + ", ".join(
        f"{i}={100 * hist.get(i, 0) // tot}%" for i in range(4)))


if __name__ == '__main__':
    main()
