#!/usr/bin/env python3
"""render_fb.py — decode a raw CoCo3 framebuffer dump to a native 1:1 PNG.

WHY NOT A MAME SNAPSHOT (idiom §11b): `screen:snapshot()` is not square-pixel and,
under -nothrottle, manufactures motion artifacts. Decoding the raw framebuffer is
the honest image: 320x192 at 1:1, no emulator rendering in the path.

Supports the two modes HAL_gfx_set_mode serves (P2.5):
  4-colour  CRES=01, 2 bpp, 4 px/byte,  80 B/row, 15,360 B
  16-colour CRES=10, 4 bpp, 2 px/byte, 160 B/row, 30,720 B
[ref: docs/ground-truth/GIME_Reference_Manual.pdf §11 Pixel Data Format]
  16-colour byte = [PA3..PA0 | PA3..PA0], high nibble = LEFT pixel
   4-colour byte = [PA1 PA0 | PA1 PA0 | PA1 PA0 | PA1 PA0], MSB pair = leftmost

PALETTE FORMAT: RGB monitor, bits 5:0 = R1 G1 B1 R0 G0 B0, each channel 2 bits
(0-3). CLAUDE.md §4 makes RGB the project gate and POP ships
dist/mame-cfg/rgb/coco3.cfg to force it; the SAME byte is a different colour under
composite, which is what made orange read as yellow in P1.3.
[ref: docs/ground-truth/SockmasterGime.md:218-225]

This renders what the FRAMEBUFFER BYTES plus the PALETTE mean. It is a decode, not
a photograph of the screen — the on-screen truth is Jay's live MAME (idiom §11).
"""
import argparse
import pathlib
import sys

from PIL import Image

# The default test palettes HAL_gfx_set_mode loads (gfx.s gfx_pal4 / gfx_pal16).
PAL4 = [0x00, 0x26, 0x19, 0x3F]
PAL16 = [0x00, 0x07, 0x38, 0x3F, 0x24, 0x26, 0x36, 0x12,
         0x1B, 0x09, 0x2D, 0x04, 0x02, 0x01, 0x1D, 0x33]

WIDTH, ROWS = 320, 192
LEVEL = (0, 85, 170, 255)          # 2-bit channel -> 8-bit


def gime_rgb(byte):
    """GIME RGB palette byte -> (r, g, b). bits 5:0 = R1 G1 B1 R0 G0 B0."""
    r = ((byte >> 5) & 1) * 2 + ((byte >> 2) & 1)
    g = ((byte >> 4) & 1) * 2 + ((byte >> 1) & 1)
    b = ((byte >> 3) & 1) * 2 + (byte & 1)
    return LEVEL[r], LEVEL[g], LEVEL[b]


def decode(data, bpp):
    stride = WIDTH * bpp // 8
    pal = PAL16 if bpp == 4 else PAL4
    want = stride * ROWS
    if len(data) < want:
        sys.exit(f"dump is {len(data)} B, need {want} B for {bpp} bpp "
                 f"({stride} B/row x {ROWS} rows)")
    rgb = [gime_rgb(p) for p in pal]
    img = Image.new('RGB', (WIDTH, ROWS))
    px = img.load()
    for y in range(ROWS):
        base = y * stride
        x = 0
        for i in range(stride):
            byte = data[base + i]
            if bpp == 4:
                px[x, y] = rgb[byte >> 4]          # high nibble = left pixel
                px[x + 1, y] = rgb[byte & 0x0F]
                x += 2
            else:
                for sh in (6, 4, 2, 0):            # MSB pair = leftmost
                    px[x, y] = rgb[(byte >> sh) & 3]
                    x += 1
    return img


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('dump', help='raw framebuffer dump')
    ap.add_argument('-o', '--out', help='output PNG (default: dump name + .png)')
    ap.add_argument('--bpp', type=int, choices=(2, 4),
                    help='bits per pixel; inferred from file size if omitted')
    ap.add_argument('--scale', type=int, default=1,
                    help='integer NEAREST upscale for visibility (never fractional)')
    a = ap.parse_args()

    data = pathlib.Path(a.dump).read_bytes()
    bpp = a.bpp
    if bpp is None:
        bpp = {15360: 2, 30720: 4}.get(len(data))
        if bpp is None:
            sys.exit(f"cannot infer bpp from {len(data)} B; pass --bpp")

    img = decode(data, bpp)
    if a.scale > 1:
        img = img.resize((WIDTH * a.scale, ROWS * a.scale), Image.NEAREST)

    out = a.out or (str(pathlib.Path(a.dump).with_suffix('')) + '.png')
    img.save(out)
    colours = 16 if bpp == 4 else 4
    print(f"{a.dump}: {len(data)} B, {bpp} bpp, {colours} colours, "
          f"{WIDTH * bpp // 8} B/row -> {out} ({img.width}x{img.height})")


if __name__ == '__main__':
    main()
