"""cel_mirror_paths.py — P3.103a: test the mirroring WITHOUT crossing formats.

★★★ WHY THE METHOD HAD TO CHANGE. Jay: *"even doing that he still has to do math to
compare them, introducing the same potential error."*

P3.100 reported the port and the oracle agreeing at `168, 173, 176, 181, 182, 191, 188,
193` — but the port's `ch_dest` is a CoCo3 framebuffer address and the oracle's store is an
Apple screen position, so SOMETHING mapped between them to call those the same pixel. ★★ If
that mapping is the same 7→4 reasoning the bake uses, a rounding error in it is invisible to
the comparison: it agrees by construction. **That is P3.99's trap moved into the COMPARISON
rather than into an operand.**

★★★ SO THIS TEST NEVER LEAVES COCO SPACE. Two paths, one source cel, both ending in a CoCo
pixel array, compared as CoCo pixels. No Apple↔CoCo coordinate arithmetic anywhere.

    Path A — MIRROR IN APPLE SPACE, THEN CONVERT.
             The oracle's own operation [HIRES.S MLayGen + the MIRROR table]: reverse the
             byte order and mirror the seven pixel bits inside each byte, each byte keeping
             its own palette bit. Then run the colour model on the mirrored bitmap — so the
             model sees the geometry it will actually be displayed at.

    Path B — CONVERT, THEN MIRROR IN COCO SPACE.
             What the bake does today (`--mirror`): run the colour model on the UNMIRRORED
             bitmap, then reverse the resulting per-pixel index list.

★★ THE TWO ARE NOT THE SAME OPERATION AND THE DIFFERENCE IS DIRECTIONAL. The colour model
has a rule that points one way [sprite_convert.py, the `gap == 1` arm]:

    # NTSC chroma: attributed to this ON pixel, painted at col-1
    row_indices[col - 1] = chroma_idx
    row_indices[col]     = 3

A chroma pixel painted one column LEFT of its ON pixel. Path B reverses that afterwards, so
in the shipped mirrored cel the smear sits one column RIGHT of its ON pixel. Path A computes
it on the mirrored geometry, so it stays where the display would put it.

★ WHAT EACH OUTCOME MEANS, decided before running:
  - **They differ** → the mirrored conversion is wrong, expressed purely in CoCo pixels, and
    it is fixable at the converter. It also means every cross-format position comparison in
    this arc inherits the doubt, P3.100's included.
  - **They agree** → the mirroring is sound and Jay's rounding lead closes cleanly, without
    the ambiguity now attached to the `ch_dest` comparison.

★ A LEAD IS NOT A FINDING, INCLUDING JAY'S. This can refute it.
"""
import argparse
import pathlib
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import cel_parity_rule as R                      # noqa: E402
import sprite_convert as SC                      # noqa: E402

WALK = [48, 49, 50, 51, 52, 53]


def mirror_apple_row(row_bytes, apple_width):
    """Reverse a row of Apple hi-res bytes the way the oracle does.

    Apple hi-res packs seven pixels per byte, LSB = leftmost [sprite_convert's own
    classifier: `bit_pos = col % 7`, `p = byte >> bit_pos`], with bit 7 the palette bit. The
    oracle mirrors with a $80-entry MIRROR table [HIRES.S HRPARAMS] and lays the bytes
    right-to-left, so each byte's seven pixels reverse INSIDE the byte and the palette bit
    stays with the byte it belongs to. Reproduced exactly here — and note this is a pure
    Apple-space operation: no CoCo coordinate is computed, so nothing under suspicion is
    used to build the input.
    """
    out = []
    for b in reversed(row_bytes[:apple_width]):
        pal = b & 0x80
        pix = b & 0x7F
        rev = 0
        for i in range(7):
            if (pix >> i) & 1:
                rev |= 1 << (6 - i)
        out.append(pal | rev)
    return out


def unpack(bitmap, width, height):
    """packed CoCo bytes -> list of rows of 2-bit palette indices."""
    rows = []
    for r in range(height):
        row = []
        for c in range(width):
            b = bitmap[r * width + c]
            for p in range(4):
                row.append((b >> (6 - 2 * p)) & 3)
        rows.append(row)
    return rows


def load(cel):
    tab = R.table_path(cel)
    idx = R.chartable(cel)[1]
    c = SC.get_cel(str(tab), idx)
    h, w = c["h"], c["w"]
    # the ingest row flip convert_one does; identical on both paths, so it cannot bias them
    bm = [b for r in range(h - 1, -1, -1) for b in c["data"][r * w:(r + 1) * w]]
    return bm, h, w


def path_a(cel, start_col):
    """Mirror in APPLE space, then convert."""
    bm, h, w = load(cel)
    mirrored = []
    for r in range(h):
        mirrored.extend(mirror_apple_row(bm[r * w:(r + 1) * w], w))
    return SC.convert_sprite_to_coco3(mirrored, h, w, start_col, False, False), h


def path_b(cel, start_col):
    """Convert, then mirror in COCO space — what the bake ships."""
    bm, h, w = load(cel)
    return SC.convert_sprite_to_coco3(bm, h, w, start_col, False, True), h


def compare(cel, start_col):
    (a_bm, a_w), h = path_a(cel, start_col)
    (b_bm, b_w), _ = path_b(cel, start_col)
    ra, rb = unpack(a_bm, a_w, h), unpack(b_bm, b_w, h)
    npix = min(len(ra[0]), len(rb[0]))
    diff = sum(1 for r in range(h) for x in range(npix) if ra[r][x] != rb[r][x])
    # a SHAPE difference (ink where the other has none, or vice versa) is a position defect;
    # a pure INDEX difference at the same pixels is a colour one. Separating them matters:
    # only the first can move a character.
    shape = sum(1 for r in range(h) for x in range(npix)
                if (ra[r][x] != 0) != (rb[r][x] != 0))
    # the ink's own span on each path, in CoCo pixels
    def span(rows):
        lo = hi = None
        for row in rows:
            for x, v in enumerate(row):
                if v:
                    lo = x if lo is None else min(lo, x)
                    hi = x if hi is None else max(hi, x)
        return lo, hi
    alo, ahi = span(ra)
    blo, bhi = span(rb)
    return dict(cel=cel, h=h, wa=a_w, wb=b_w, npix=npix, diff=diff, shape=shape,
                a_span=(alo, ahi), b_span=(blo, bhi),
                shift=(blo - alo) if (alo is not None and blo is not None) else None)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--cels", default=",".join(str(c) for c in WALK))
    ap.add_argument("--start-col", type=int, default=0,
                    help="chroma parity only; it cannot move ink, and 0 keeps this "
                         "independent of the scene trace")
    args = ap.parse_args()
    cels = [int(x) for x in args.cels.split(",")]

    print("# TWO PATHS TO A MIRRORED CEL, COMPARED IN COCO PIXELS ONLY")
    print("#   A = mirror in Apple space (the oracle's own byte/bit reversal), then convert")
    print("#   B = convert, then reverse the CoCo pixel list  <-- what the bake ships")
    print("# No Apple<->CoCo coordinate arithmetic is performed anywhere in this comparison.")
    print()
    print("  cel  rows  Aw  Bw  ink span A     ink span B     shift  SHAPE diffs  total diffs")
    out = []
    for cel in cels:
        d = compare(cel, args.start_col)
        out.append(d)
        print("  %-4d %-5d %-3d %-3d %-14s %-14s %-6s %-12d %d"
              % (d["cel"], d["h"], d["wa"], d["wb"],
                 "%d..%d" % d["a_span"], "%d..%d" % d["b_span"],
                 ("%+d" % d["shift"]) if d["shift"] is not None else "?",
                 d["shape"], d["diff"]))
    print()

    shifts = [d["shift"] for d in out]
    shapes = [d["shape"] for d in out]
    if all(s == 0 for s in shapes):
        print("# ★ NO SHAPE DIFFERENCE ON ANY CEL: the two paths put the same pixels in the")
        print("#   same places. The mirrored conversion does not move anything, and Jay's")
        print("#   rounding lead CLOSES for position.")
    else:
        print("# ★★★ THE PATHS DISAGREE IN SHAPE — the mirrored conversion moves ink.")
    print()
    print("# ★ DOES THE OFFSET ALTERNATE? A constant offset is a displaced but smooth walk;")
    print("#   an offset that changes cel to cel is a gait that slips, which is what")
    print("#   'almost like a frame is missing' describes.")
    print("    shift per cel: %s" % " ".join("%d:%+d" % (d["cel"], d["shift"]) for d in out))
    span = max(shifts) - min(shifts)
    print("    spread %d px  =>  %s" % (
        span, "CONSTANT" if span == 0 else "★ VARIES ACROSS THE CYCLE"))
    print()
    if any(d["diff"] and not d["shape"] for d in out):
        print("# NOTE: cels differ in palette INDEX at pixels where both have ink. That is a")
        print("#   colour difference, not a position one — it cannot move a character, and it")
        print("#   is the directional NTSC chroma rule reversing with the pixel list.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
