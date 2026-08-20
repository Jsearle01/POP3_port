#!/usr/bin/env python3
"""gen_loading.py - emit the stage-1 loader's "loading" screen as 6809 source.

★★★ ONE HOME FOR THE LETTERFORMS. The glyphs are not drawn here and not stored anywhere
else: they are lifted from the byline caption in the intro's own asset bundle by
byline_font.py, every build. Change the artwork and this follows it; there is no second
copy of a letter to drift [CLAUDE.md §2F].

WHAT IS EMITTED
  msys-style, two things from one pass over one source:
    * the 16-byte palette, copied from BUNDLE_PAL at bundle offset $000 -- the artwork's
      own colours, so the anti-aliasing renders as the caption does. set_mode installs a
      DIAGNOSTIC palette (P2.5) and drawing against that would show colours the text never
      has.
    * the word as a SPARSE PATCH in patch_blit's own format:
          fdb first_row / fcb n_rows / per row: fcb n_runs, per run: fcb col, len, data*
      which the loader walks with a dozen instructions. ★ The format is reused rather than
      invented because the intro already speaks it -- a second bitmap format would be a
      second thing to get wrong, and P3.85's packed-header note is what that costs.

★★ `l` AND `i` ARE THE FONT'S OWN STROKE, NOT DRAWINGS. `j` is a plain vertical stem whose
rows 1..8 are identical; `l` is that stem at ascender height and `i` at x-height. Jay ruled
on both details after seeing them rendered: DOTLESS, because this font's `j` has no dot and
a dotted `i` would be an invention; and NO TERMINAL, because `j`'s `###` top row reads as a
bar sitting above an isolated stem even though it belongs on `j`.

★ THE SIZE IS WHY THIS IS A SEPARATE BINARY. The patch measures ~263 B and the loader's
code and palette bring it to ~430 B. link/pop_engine.link's ceiling note is explicit --
"prog ending $2487 boots; $2535 image corrupted... treat $2480 as the practical limit" --
and the intro's prog already ends $24FA. There is no room for this in that image, which is
what put the loader in its own.
"""
import argparse
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from byline_font import (parse_patch, ink_of, text_lines,       # noqa: E402
                         unsplit_letters)

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

WORD = "loading"
GAP = 2                     # px between letters; the byline measures 1-2
SCREEN_W, SCREEN_H = 320, 192
ASC_ROWS = 9                # ascender top .. baseline, from the byline's own metrics


def letters(bundle):
    buf = pathlib.Path(bundle).read_bytes()
    _, _, px = parse_patch(buf, 0x400)
    bg, ink, _ = ink_of(px)
    got, _ = unsplit_letters(px, bg, ink, text_lines(px, bg))

    def lift(ch):
        x0, x1, y0, y1 = got[ch]
        base = 124 if y0 < 130 else 138          # the two lines' baselines
        asc = base - (ASC_ROWS - 1)
        return ({(r - asc, x - x0): px.get((r, x), bg)
                 for r in range(y0, y1 + 1) for x in range(x0, x1 + 1)}, x1 - x0 + 1)

    L = {c: lift(c) for c in "adgno"}
    jg, jw = lift("j")
    stem = {c: jg[(4, c)] for c in range(jw)}    # a mid-stem row, free of j's terminal
    L["l"] = ({(r, c): v for r in range(0, 9) for c, v in stem.items()}, jw)
    L["i"] = ({(r, c): v for r in range(3, 9) for c, v in stem.items()}, jw)
    return L, bg, buf[0x000:0x010]


def compose(L, bg):
    w = sum(L[c][1] for c in WORD) + GAP * (len(WORD) - 1)
    grid, x = {}, 0
    for c in WORD:
        g, gw = L[c]
        for (r, cc), v in g.items():
            grid[(r, x + cc)] = v
        x += gw + GAP
    return grid, w


def to_patch(grid, w, bg):
    """-> (bytes, first_row, n_rows, x0) in patch_blit's format, centred on screen.

    ★ A run's `col` is a BYTE column and a byte is two pixels, so the word is placed on an
    EVEN pixel boundary. Centring to an odd x would need every glyph shifted a nibble --
    the sub-byte shifter exists for the cutscene's cels and is not worth waking for a word
    that appears once.
    """
    rows = {}
    x0 = ((SCREEN_W - w) // 2) & ~1
    y0 = (SCREEN_H - ASC_ROWS) // 2
    for (r, c), v in grid.items():
        if v != bg:
            rows.setdefault(r, {})[x0 + c] = v
    first, last = min(rows), max(rows)
    out = bytearray([(y0 + first) >> 8, (y0 + first) & 0xFF, last - first + 1])
    for r in range(first, last + 1):
        cells = rows.get(r, {})
        bcols = sorted({px // 2 for px in cells})
        runs = []
        if bcols:
            s = p = bcols[0]
            for b in bcols[1:]:
                if b != p + 1:
                    runs.append((s, p)); s = b
                p = b
            runs.append((s, p))
        out.append(len(runs))
        for (b0, b1) in runs:
            out += bytes([b0, b1 - b0 + 1])
            for b in range(b0, b1 + 1):
                out.append((cells.get(b * 2, bg) << 4) | cells.get(b * 2 + 1, bg))
    return bytes(out), y0 + first, last - first + 1, x0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bundle", default="build/assets/intro_bundle.raw")
    ap.add_argument("--out", default="build/gen/loading_data.s")
    args = ap.parse_args()

    L, bg, pal = letters(args.bundle)
    grid, w = compose(L, bg)
    patch, row, nrows, x0 = to_patch(grid, w, bg)

    W = []
    W.append("* loading_data.s - the stage-1 loader's screen.")
    W.append("* GENERATED by harness/tools/gen_loading.py - do not hand-edit.")
    W.append("*")
    W.append("* The letters are LIFTED from the byline caption in the intro's own bundle,")
    W.append("* every build, so the artwork is the single home for them. `l` and `i` are the")
    W.append("* font's own `j` stem at ascender and x height -- dotless and without j's top")
    W.append("* terminal, both on Jay's ruling after seeing them rendered.")
    W.append("*")
    W.append("* Format is patch_blit's [intro_seq.s]:")
    W.append("*   fdb first_row / fcb n_rows / per row: fcb n_runs, per run: fcb col, len, data*")
    W.append("*")
    W.append("* word %d px wide, placed at x=%d row=%d, %d rows, %d bytes"
             % (w, x0, row, nrows, len(patch)))
    W.append("")
    W.append("* the artwork's own sixteen colours - BUNDLE_PAL, bundle offset $000")
    W.append("loading_pal")
    W.append("                fcb     " + ",".join("$%02X" % b for b in pal))
    W.append("")
    W.append("loading_patch")
    for i in range(0, len(patch), 16):
        W.append("                fcb     " + ",".join("$%02X" % b for b in patch[i:i + 16]))
    W.append("loading_patch_end")

    out = pathlib.Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(W) + "\n", encoding="utf-8")
    print("gen_loading: %s" % out)
    print("  word '%s' %d px wide at x=%d, rows %d..%d" % (WORD, w, x0, row, row + nrows - 1))
    print("  patch %d B + palette 16 B" % len(patch))
    return 0


if __name__ == "__main__":
    sys.exit(main())
