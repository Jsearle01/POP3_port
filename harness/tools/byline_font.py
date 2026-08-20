#!/usr/bin/env python3
"""byline_font.py - lift the alphabet out of the byline caption bitmap.

★★★ WHY THE PATCH IS THE RIGHT SOURCE, AND NOT A RENDER OF THE SCREEN. The byline is a
SPARSE PATCH over the Broderbund splash [intro_seq.s patch_blit]:

    fdb first_row / fcb n_rows / per row: fcb n_runs, per run: fcb col, len, data*

so its runs are exactly the bytes the caption overwrites -- the glyph pixels and nothing
else. Compositing it onto the splash first would mean segmenting letters out of a full
picture; reading the patch gives them already isolated, by construction.

★★ AND IT IS READ FROM THE BUILT ARTEFACT, `build/assets/intro_bundle.raw`, which is what
reaches the disk. The generator is a second home for the same fact and could drift from it
-- intro_patch_extent.py makes the same choice for the same reason.

★ MODE: 320x192, 16 colours, 4 bits per pixel, 2 pixels per byte, 160 bytes per row
[intro_seq.s FB_STRIDE / GFX_MODE_320x192x16]. A run's `col` is a BYTE column, so pixel
x = col*2 and a run of `len` bytes covers 2*len pixels.

★★★ THIS EMITS TEXT, NOT AN IMAGE. CLAUDE.md §3 forbids reading pixel content out of a PNG
and requires any PNG to go to Jay before it is interpreted. A colour-index grid is exactly
the "structured text" §3 names as the permitted form, and it is also the only form in which
stroke widths and baselines can be counted rather than eyeballed.
"""
import argparse
import pathlib
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

STRIDE = 160
PATCHES = {"presents": 0x040, "byline": 0x400, "title": 0x800}


def parse_patch(buf, off):
    """-> (first_row, n_rows, {(row, xpx): index}) with x in PIXELS."""
    first_row = (buf[off] << 8) | buf[off + 1]
    n_rows = buf[off + 2]
    p = off + 3
    px = {}
    for r in range(n_rows):
        n_runs = buf[p]; p += 1
        for _ in range(n_runs):
            col, ln = buf[p], buf[p + 1]; p += 2
            for i in range(ln):
                b = buf[p + i]
                px[(first_row + r, (col + i) * 2)] = b >> 4
                px[(first_row + r, (col + i) * 2 + 1)] = b & 0x0F
            p += ln
    return first_row, n_rows, px


def ink_of(px):
    """The glyph colour: the least common index that is not the modal one.

    ★ The modal index is the caption's BACKGROUND -- the patch paints a solid field behind
    the text so the splash underneath cannot show through. Whatever else is present in
    quantity is the ink. Counting beats assuming: the palette is the artwork's, not a
    fixed one, and P2.5's diagnostic palette has burned this project before.
    """
    hist = {}
    for v in px.values():
        hist[v] = hist.get(v, 0) + 1
    ranked = sorted(hist.items(), key=lambda kv: -kv[1])
    return ranked[0][0], ranked[1][0] if len(ranked) > 1 else None, hist


def columns_with_ink(px, ink, rows):
    cols = {}
    for (r, x), v in px.items():
        if v == ink:
            cols.setdefault(x, 0)
            cols[x] += 1
    return cols


def text_lines(px, bg, blank=2):
    """Split the patch into LINES of text on runs of entirely-background rows.

    ★ The byline is TWO lines, which the first cut of this tool did not expect -- it
    segmented the whole box by column and produced four nonsense groups spanning both
    lines at once. Rows first, then columns.
    """
    rows = sorted({r for (r, x) in px})
    inked = [r for r in rows if any(px.get((r, x), bg) != bg
                                    for (rr, x) in px if rr == r)]
    inked = sorted({r for (r, x), v in px.items() if v != bg})
    if not inked:
        return []
    out, cur = [], [inked[0]]
    for r in inked[1:]:
        if r - cur[-1] > blank:
            out.append((cur[0], cur[-1])); cur = [r]
        else:
            cur.append(r)
    out.append((cur[0], cur[-1]))
    return out


def segment_line(px, bg, y0, y1, gap):
    """Glyphs within one text line, split on background-only pixel columns.

    ★ INK IS 'NOT THE BACKGROUND', not 'the modal ink index'. The caption is ANTI-ALIASED
    -- index 15 is the core but seven other indices shade its edges -- so segmenting on the
    core alone cuts a glyph wherever its stroke thins to a shade.
    """
    xs = sorted({x for (r, x), v in px.items()
                 if v != bg and y0 <= r <= y1})
    if not xs:
        return []
    groups, cur = [], [xs[0]]
    for x in xs[1:]:
        if x - cur[-1] > gap:
            groups.append(cur); cur = [x]
        else:
            cur.append(x)
    groups.append(cur)
    out = []
    for g in groups:
        gx0, gx1 = g[0], g[-1]
        ys = [r for (r, x), v in px.items()
              if v != bg and gx0 <= x <= gx1 and y0 <= r <= y1]
        out.append((gx0, gx1, min(ys), max(ys)))
    return out


def segment(px, ink, gap):
    """Split into glyphs on runs of ink-free pixel columns of at least `gap`."""
    xs = sorted({x for (r, x), v in px.items() if v == ink})
    if not xs:
        return []
    groups, cur = [], [xs[0]]
    for x in xs[1:]:
        if x - cur[-1] > gap:
            groups.append(cur); cur = [x]
        else:
            cur.append(x)
    groups.append(cur)
    out = []
    for g in groups:
        x0, x1 = g[0], g[-1]
        ys = [r for (r, x), v in px.items() if v == ink and x0 <= x <= x1]
        out.append((x0, x1, min(ys), max(ys)))
    return out


def render(px, ink, x0, x1, y0, y1):
    lines = []
    for r in range(y0, y1 + 1):
        lines.append("".join("#" if px.get((r, x)) == ink else "."
                             for x in range(x0, x1 + 1)))
    return lines


# ---------------------------------------------------------------------------
# ★★★ THE GLYPHS ARE LABELLED FROM THE KNOWN TEXT, NOT RECOGNISED FROM THEIR SHAPES.
#
# intro_seq.s's beat table names this caption "A Game by Jordan Mechner", so the letters
# are known and only their ORDER has to be matched to the segmentation. Reading letterforms
# out of an ASCII grid by eye is exactly the kind of judgement CLAUDE.md §3 keeps away from
# pixel data, and it would be silently wrong for the pair that matters -- an `o` mistaken
# for a `c` reaches Jay's eye as a typo, not as an error message.
#
# ★★ TWO GLYPHS SPLIT AT THE SEGMENTER'S GAP, AND BOTH ARE `m` -- its two arches are joined
# only by a shade, so a core-ink split cuts between them. The split is declared here per
# line rather than patched into the segmenter, because it is a property of THIS caption and
# a segmenter tuned until it produced 20 groups would be tuned to the answer.
LINE_TEXT = {
    0: ("a", "g", "a", ("m", 2), "e", "b", "y", None),   # None = a 1px stray, see §
    1: ("j", "o", "r", "d", "a", "n", ("m", 2), "e", "c", "h", "n", "e", "r"),
}


def label(px, bg, ink, lines, gap):
    """-> {letter: [(x0, x1, y0, y1), ...]} using LINE_TEXT to name the groups."""
    out = {}
    for li, (ly0, ly1) in enumerate(lines):
        gs = segment_line_core(px, ink, ly0, ly1, gap)
        spec, gi = LINE_TEXT[li], 0
        for item in spec:
            if item is None:
                gi += 1
                continue
            name, n = (item, 1) if isinstance(item, str) else item
            if gi + n > len(gs):
                break
            parts = gs[gi:gi + n]
            gi += n
            x0 = min(p[0] for p in parts); x1 = max(p[1] for p in parts)
            ys = [r for (r, x), v in px.items()
                  if v != bg and x0 <= x <= x1 and ly0 <= r <= ly1]
            out.setdefault(name, []).append((x0, x1, min(ys), max(ys)))
    return out


def segment_line_core(px, ink, y0, y1, gap):
    """Glyph groups split on the CORE ink only.

    ★ Segmenting on 'not background' merges every letter in the line: the anti-alias
    shades bridge the gaps. Segmenting on the core ink at gap>1 separates them. Both were
    measured before choosing -- 'not background' gave 2 groups for 13 letters.
    """
    xs = sorted({x for (r, x), v in px.items() if v == ink and y0 <= r <= y1})
    if not xs:
        return []
    groups, cur = [], [xs[0]]
    for x in xs[1:]:
        if x - cur[-1] > gap:
            groups.append(cur); cur = [x]
        else:
            cur.append(x)
    groups.append(cur)
    return [(g[0], g[-1], y0, y1) for g in groups]


# ---------------------------------------------------------------------------
# ★★★ WORDS FIRST, THEN LETTERS — AND THE WORD BREAKS ARE MEASURED, NOT ASSUMED.
#
# Jay, on the first cut of this: "i think the extra space youre seeing is actual spaces
# seperating the words". He was right, and it replaced a worse method. I had been about to
# declare WHICH glyphs split (`m` splits at the gap between its arches) and hard-code that
# per line -- which is tuning the segmenter until it emits the number of groups the answer
# needs, and it would have been unfalsifiable.
#
# The gaps say it without any help:
#     line 0   1 2 1 1 5 2 1      <- letter gaps are 1-2 px
#     line 1   1 2 1 2 2 7 2 2 1 2 2 1 2      <- word gaps are 5 and 7
# so a threshold of 4 separates them with no overlap, and the caption's own text
# ["A Game by Jordan Mechner", intro_seq.s's beat table] supplies the words.
#
# ★★ AND THE PAYOFF IS THAT THE LETTERS I NEED NEED NO GUESSING AT ALL. Word group counts
# come out [1, 5, 3] and [6, 8] against "a game by" [1, 4, 2] and "jordan mechner" [6, 7]:
#
#     "jordan"    6 groups for 6 letters   <- NOTHING SPLITS. j o r d a n label directly.
#     "game"      5 for 4                  <- `g` is still the FIRST group either way
#     "by"        3 for 2
#     "mechner"   8 for 7
#
# Every letter this task needs -- o, a, d, n from "jordan" and g from the head of "game" --
# is in a position no split can move. The words that DO split are not used.
WORD_TEXT = {0: ("a", "game", "by"), 1: ("jordan", "mechner")}
WORD_GAP = 4                     # px; letter gaps measured 1-2, word gaps 5 and 7


def words_of(px, ink, y0, y1, gap=1):
    """-> [[(x0,x1), ...], ...] : glyph groups, split into words on the wide gaps."""
    gs = segment_line_core(px, ink, y0, y1, gap)
    if not gs:
        return []
    out = [[gs[0]]]
    for prev, g in zip(gs, gs[1:]):
        (out.append([g]) if g[0] - prev[1] - 1 >= WORD_GAP else out[-1].append(g))
    return out


def segment_line_core(px, ink, y0, y1, gap):
    """Glyph groups split on the CORE ink only.

    ★ Segmenting on 'not background' merges the whole line: the anti-alias shades bridge
    every gap. Measured before choosing -- it gave 2 groups for 13 letters.
    """
    xs = sorted({x for (r, x), v in px.items() if v == ink and y0 <= r <= y1})
    if not xs:
        return []
    groups, cur = [], [xs[0]]
    for x in xs[1:]:
        if x - cur[-1] > gap:
            groups.append(cur); cur = [x]
        else:
            cur.append(x)
    groups.append(cur)
    return [(g[0], g[-1]) for g in groups]


def unsplit_letters(px, bg, ink, lines):
    """-> {letter: (x0, x1, y0, y1)} for words whose group count equals their length.

    ★★ ONLY those words. A word with more groups than letters contains a split, and which
    glyph split is exactly the thing not to guess -- so those words are reported and not
    labelled. `g` is the one exception and it is safe for a stated reason: it is the FIRST
    group of its word, a position no later split can move.
    """
    out, notes = {}, []
    for li, (ly0, ly1) in enumerate(lines):
        ws = words_of(px, ink, ly0, ly1)
        for w, text in zip(ws, WORD_TEXT[li]):
            def box(g):
                ys = [r for (r, x), v in px.items()
                      if v != bg and g[0] <= x <= g[1] and ly0 <= r <= ly1]
                return (g[0], g[1], min(ys), max(ys))
            if len(w) == len(text):
                for g, ch in zip(w, text):
                    out.setdefault(ch, box(g))
            else:
                notes.append("%-8s %d groups for %d letters -- SPLIT, not labelled"
                             % ('"%s"' % text, len(w), len(text)))
                # ★★★ THE HEAD IS **NOT** ALWAYS SAFE, AND THE DATA CAUGHT ME. I first
                # took every split word's first group on the argument that a later split
                # cannot move it. True -- unless the HEAD ITSELF is the glyph that splits,
                # which is exactly the case in "mechner": its `m` is the splitter, so the
                # first group is half an m. It was labelled `m` and came out h9 when `m`
                # is an x-height letter.
                #
                # ★★ SO THE HEAD IS ACCEPTED ONLY IF ITS HEIGHT CLASS MATCHES. That is a
                # positive check the shapes cannot fake: an ascender occupies 9 rows, an
                # x-height letter 6, and a descender crosses the baseline. `g` passes
                # because it descends -- which no fragment of a preceding letter would.
                b = box(w[0])
                ok = height_class(b, base_row(px, bg, ly0, ly1)) == CLASS.get(text[0])
                if ok:
                    out.setdefault(text[0], b)
                    notes[-1] += "; head '%s' accepted (height class matches)" % text[0]
                else:
                    notes[-1] += ("; head '%s' REJECTED -- %s, expected %s"
                                  % (text[0],
                                     height_class(b, base_row(px, bg, ly0, ly1)),
                                     CLASS.get(text[0])))
    return out, notes


# the three height classes this font uses, from the letters that cannot be ambiguous
CLASS = {"a": "x", "c": "x", "e": "x", "m": "x", "n": "x", "o": "x", "r": "x",
         "b": "asc", "d": "asc", "h": "asc", "l": "asc", "t": "asc",
         "g": "desc", "j": "desc", "p": "desc", "q": "desc", "y": "desc"}


def base_row(px, bg, y0, y1):
    """The baseline: the lowest row that most of the line's glyphs reach."""
    counts = {}
    for (r, x), v in px.items():
        if v != bg and y0 <= r <= y1:
            counts[r] = counts.get(r, 0) + 1
    rows = sorted(counts)
    # the baseline is the last row whose ink is within half the line's peak
    peak = max(counts.values())
    deep = [r for r in rows if counts[r] >= peak * 0.4]
    return max(deep) if deep else y1


def height_class(box, baseline):
    _, _, y0, y1 = box
    if y1 > baseline:
        return "desc"
    return "asc" if (y1 - y0 + 1) > 7 else "x"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bundle", default="build/assets/intro_bundle.raw")
    ap.add_argument("--patch", default="byline", choices=sorted(PATCHES))
    ap.add_argument("--gap", type=int, default=2,
                    help="ink-free pixel columns that separate two glyphs")
    ap.add_argument("--grid", action="store_true", help="print each glyph as a grid")
    args = ap.parse_args()

    buf = pathlib.Path(args.bundle).read_bytes()
    first_row, n_rows, px = parse_patch(buf, PATCHES[args.patch])
    bg, ink, hist = ink_of(px)

    print("# %s patch: rows %d..%d (%d), %d pixels painted"
          % (args.patch, first_row, first_row + n_rows - 1, n_rows, len(px)))
    print("# colour histogram (index: count) -- background is the mode, ink the runner-up")
    for v, c in sorted(hist.items(), key=lambda kv: -kv[1]):
        tag = "  <- background" if v == bg else ("  <- INK" if v == ink else "")
        print("#   %2d  %6d%s" % (v, c, tag))
    print("#")

    lines = text_lines(px, bg)
    print("# %d line(s) of text: %s" % (len(lines), lines))
    print("#")

    got, notes = unsplit_letters(px, bg, ink, lines)
    for s in notes:
        print("# " + s)
    print("#\n# LETTERS LIFTED (%d): %s" % (len(got), " ".join(sorted(got))))
    print("#  %-3s %-10s %-10s %-3s %-3s %-9s" % ("ch", "x", "y", "w", "h", "kind"))
    base = max(b[3] for b in got.values())
    for ch in sorted(got):
        x0, x1, y0, y1 = got[ch]
        h = y1 - y0 + 1
        kind = "x-height" if h <= 6 else ("descender" if y1 > 138 else "ascender")
        print("   %-3s %-10s %-10s %-3d %-3d %-9s"
              % (ch, "%d..%d" % (x0, x1), "%d..%d" % (y0, y1), x1 - x0 + 1, h, kind))
    print("#")
    if args.grid:
        for ch in sorted(got):
            x0, x1, y0, y1 = got[ch]
            print("## '%s'  x %d..%d  y %d..%d" % (ch, x0, x1, y0, y1))
            for r in range(y0, y1 + 1):
                print("   %3d %s" % (r, "".join(
                    "#" if px.get((r, x), bg) == ink
                    else ("+" if px.get((r, x), bg) != bg else ".")
                    for x in range(x0, x1 + 1))))
            print()
        return 0
    print("#")
    n = 0
    for li, (ly0, ly1) in enumerate(lines):
        glyphs = segment_line(px, bg, ly0, ly1, args.gap)
        print("# line %d  rows %d..%d  -> %d glyphs at gap>%d"
              % (li, ly0, ly1, len(glyphs), args.gap))
        print("#  %-4s %-9s %-9s %-4s %-4s %-8s %-7s" %
              ("n", "x", "y", "w", "h", "advance", "gap"))
        prev_x1 = None
        for (x0, x1, y0, y1) in glyphs:
            adv = "" if prev_x1 is None else str(x0 - prev_x1 - 1)
            print("   %-4d %-9s %-9s %-4d %-4d %-8s %-7s"
                  % (n, "%d..%d" % (x0, x1), "%d..%d" % (y0, y1),
                     x1 - x0 + 1, y1 - y0 + 1, "", adv))
            prev_x1 = x1
            n += 1
        print("#")
    if args.grid:
        n = 0
        for (ly0, ly1) in lines:
            for (x0, x1, y0, y1) in segment_line(px, bg, ly0, ly1, args.gap):
                print("## glyph %d  x %d..%d  y %d..%d  (w %d h %d)"
                      % (n, x0, x1, y0, y1, x1 - x0 + 1, y1 - y0 + 1))
                for r in range(y0, y1 + 1):
                    print("   %3d %s" % (r, "".join(
                        "#" if px.get((r, x), bg) == ink
                        else ("+" if px.get((r, x), bg) != bg else ".")
                        for x in range(x0, x1 + 1))))
                n += 1
                print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
