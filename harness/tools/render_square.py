#!/usr/bin/env python3
"""render_square.py — normalise captures to NATIVE 1:1 square pixels.

WHY THIS EXISTS (idiom §11b, standing rule — POP had no implementation until P3.2).
A MAME `screen:snapshot()` of apple2e is **560x192**. Each logical Apple dot is
emitted as TWO horizontal pixels, so at 1:1 the image is ~2.9:1 — badly stretched
horizontally, which reads to the eye as "squished vertically". Comparing a port's
render against a stretched reference is comparing two different geometries and will
mislead about position, proportion and shape.

THE RULE: halve the 560 width to 280 by NEAREST sampling, keeping the LEFT pixel of
each pair. A box/average resize blends the NTSC colour fringes and invents colours
that were never in the frame.

  apple2e snapshot  560x192  --halve-->  280x192   (1:1 logical)
  coco3 framebuffer          decoded     320x192   (already 1:1)

Both then share the SAME convention — 1:1 LOGICAL pixels, not 4:3 hardware-corrected
— so an apple2e pixel X lines up with a coco3 pixel X+20 under POP's
virtual-resolution contract (280 content centred in 320).

Integer upscaling for visibility is NEAREST and never fractional.
"""
import argparse
import pathlib
import sys

from PIL import Image


def halve_apple2e(img):
    """560-wide -> 280-wide, keeping the LEFT pixel of each doubled pair."""
    if img.width != 560:
        sys.exit(f"expected a 560-wide apple2e snapshot, got {img.width}")
    out = Image.new('RGB', (280, img.height))
    src, dst = img.convert('RGB').load(), out.load()
    for y in range(img.height):
        for x in range(280):
            dst[x, y] = src[x * 2, y]       # NEAREST: left of each pair
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('src')
    ap.add_argument('-o', '--out', required=True)
    ap.add_argument('--apple2e', action='store_true',
                    help='halve a 560-wide MAME apple2e snapshot to native 280')
    ap.add_argument('--scale', type=int, default=1, help='integer NEAREST upscale')
    a = ap.parse_args()

    img = Image.open(a.src).convert('RGB')
    before = img.size
    if a.apple2e:
        img = halve_apple2e(img)
    if a.scale > 1:
        img = img.resize((img.width * a.scale, img.height * a.scale), Image.NEAREST)
    img.save(a.out)
    print(f"{a.src} {before} -> {a.out} {img.size}"
          + ("  (apple2e 560->280 native)" if a.apple2e else ""))


if __name__ == '__main__':
    main()
