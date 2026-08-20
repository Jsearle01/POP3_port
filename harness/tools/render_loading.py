#!/usr/bin/env python3
"""render_loading.py - render the composed "loading" and the byline it came from, to PNG.

★★★ CLAUDE.md §3 GOVERNS THIS FILE. The PNG it writes is a DIAGNOSTIC ARTEFACT FOR JAY. It
is surfaced for his inspection on generation and is NOT read, analysed or interpreted here
or anywhere else -- every measurement in this task (bounding boxes, stroke widths,
baselines, letter gaps) is taken from the PATCH BYTES, which are structured data, and none
of it comes from looking at a picture.

WHAT IT DRAWS, and why both halves are on one image: the composed word above the byline
line it was lifted from, at the same scale and in the same palette, so the question "do `l`
and `i` belong with the rest" can be answered by comparison rather than from memory.

THE PALETTE IS THE ARTWORK'S OWN. BUNDLE_PAL is the 16 bytes at offset $000 of the caption
bundle [intro_seq.s:156], written to $FFB0-$FFBF by set_dhr_palette. A CoCo3 palette byte is
six bits, RRGGBB interleaved as R1G1B1R0G0B0 [GIME_Reference_Manual], so each channel is two
bits and scales to 8 bits by *85. ★ Using the real palette matters: P2.5's DIAGNOSTIC
palette is what set_mode installs, and rendering against that would show colours the caption
never has.
"""
import argparse
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from byline_font import (parse_patch, ink_of, text_lines,      # noqa: E402
                         unsplit_letters)

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass


def coco3_rgb(b):
    """One GIME palette byte -> (r, g, b) 8-bit. Bits are R1 G1 B1 R0 G0 B0."""
    r = ((b >> 5) & 1) * 2 + ((b >> 2) & 1)
    g = ((b >> 4) & 1) * 2 + ((b >> 1) & 1)
    bl = ((b >> 3) & 1) * 2 + (b & 1)
    return (r * 85, g * 85, bl * 85)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bundle", default="build/assets/intro_bundle.raw")
    ap.add_argument("--out", default="build/loading_preview.png")
    ap.add_argument("--scale", type=int, default=6)
    ap.add_argument("--gap", type=int, default=2)
    args = ap.parse_args()

    from PIL import Image

    buf = pathlib.Path(args.bundle).read_bytes()
    pal = [coco3_rgb(b) for b in buf[0x000:0x010]]
    _, _, px = parse_patch(buf, 0x400)
    bg, ink, _ = ink_of(px)
    lines = text_lines(px, bg)
    got, _ = unsplit_letters(px, bg, ink, lines)

    def lift(ch):
        x0, x1, y0, y1 = got[ch]
        base = 124 if y0 < 130 else 138
        asc = base - 8
        return ({(r - asc, x - x0): px.get((r, x), bg)
                 for r in range(y0, y1 + 1) for x in range(x0, x1 + 1)}, x1 - x0 + 1)

    L = {c: lift(c) for c in "adgno"}
    jg, jw = lift("j")

    # ★★★ THE STEM IS `j`'s, WITH ITS CAP REMOVED — TWO CORRECTIONS FROM JAY.
    #
    # "the i is too short and i don't like the vertical bar above i and l"
    #
    # ★ THE HEIGHT WAS A PLAIN BUG. x-height in this font is rows 3..8 -- six rows, as
    #   `o`, `a` and `n` all measure. I built `i` from rows 5..8, which is four. Two short.
    #
    # ★★ AND THE "BAR" IS `j`'s TOP ROW. Row 0 of `j` is `###` -- three pixels of core ink
    #   -- where every row below it is `+#+`, one core pixel between two shades. On `j` that
    #   cap is part of a letterform the eye reads as a whole; isolated on a bare stem it
    #   reads as a separate blob sitting above the stroke. I carried it onto `l` and then
    #   invented a second one for `i`, which made it worse.
    #
    # So both letters are now the UNIFORM part of j's stroke, rows 1..8, repeated to the
    # height each letter needs. Same weight, same shading, no terminal.
    stem_row = {c: jg[(4, c)] for c in range(jw)}          # a mid-stem row: `+#+`
    L["l"] = ({(r, c): v for r in range(0, 9)
               for c, v in stem_row.items()}, jw)          # ascender: rows 0..8
    # ★ DOTLESS, on Jay's ruling: this font's `j` has no dot (rows 0..8 are continuous),
    #   so a dotted `i` would be an invention rather than a match.
    L["i"] = ({(r, c): v for r in range(3, 9)
               for c, v in stem_row.items()}, jw)          # x-height: rows 3..8

    word = "loading"
    W = sum(L[c][1] for c in word) + args.gap * (len(word) - 1)
    grid, x = {}, 0
    for c in word:
        g, w = L[c]
        for (r, cc), v in g.items():
            grid[(r, x + cc)] = v
        x += w + args.gap

    # the byline's own second line, for the side-by-side
    by0, by1 = lines[1]
    bx0 = min(x for (r, x) in px if by0 <= r <= by1)
    bx1 = max(x for (r, x) in px if by0 <= r <= by1)
    BW = bx1 - bx0 + 1

    pad, sc = 6, args.scale
    iw = max(W, BW) + pad * 2
    ih = 11 + pad + (by1 - by0 + 1) + pad * 2
    img = Image.new("RGB", (iw, ih), pal[bg])
    p = img.load()
    for (r, c), v in grid.items():
        if 0 <= r < 11:
            p[pad + c, pad + r] = pal[v]
    top = pad + 11 + pad
    for r in range(by0, by1 + 1):
        for xx in range(bx0, bx1 + 1):
            p[pad + xx - bx0, top + r - by0] = pal[px.get((r, xx), bg)]

    img = img.resize((iw * sc, ih * sc), Image.NEAREST)
    out = pathlib.Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out)
    print("# wrote %s  (%dx%d at %dx)" % (out, iw, ih, sc))
    print("# TOP: the composed word 'loading'.  BOTTOM: the byline line it was lifted from.")
    print("# palette: the artwork's own BUNDLE_PAL, not set_mode's diagnostic one.")
    print("# ★ CLAUDE.md §3 — this image is for Jay. It is not read or interpreted here.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
