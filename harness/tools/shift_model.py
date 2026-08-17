#!/usr/bin/env python3
"""p334 shifter.py — the runtime shifter, modelled exactly as the 6809 will do it,
verified against an INDEPENDENT truth source, and costed from a concrete instruction
sequence.

WHY A MODEL AT ALL. The 6809 routine is written out in the report and cycle-counted
from its instructions (P3.19's method, so the numbers compare). This model exists to
prove the ALGORITHM is right before anyone counts it -- a fast routine that produces
wrong pixels measures nothing.

THE TRUTH SOURCE, and its provenance. The baked phase-k cels in content/cutscene/chars
were produced by cel_blit_prep.py from the converted _src.s bitmaps, by shifting in
PIXEL space and re-packing. This model shifts in BYTE space with a table and a carry --
a different mechanism reaching the same result. Neither derives from the other, which is
what makes the comparison worth anything. (Instruments have failed silently six times in
this project; five of those shared an input with their subject.)

THE INNER LOOP THIS MODELS, one output byte per iteration:

    lda ,x+          6    the source byte
    ldb a,y          5    SHR[src]  -- table indexed by the byte itself
    orb <carry       4    the previous byte's spill, already shifted left
    stb ,u+          6    the shifted byte
    lda a,y2?             SHL[src] -> the next carry            <-- see report
                    21+   per byte, before carry maintenance

The carry problem is the design's crux and the report says how it is solved; this model
just does it correctly so the pixel comparison is meaningful.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path("C:/Projects/POP3_port")
CH = ROOT / "content/cutscene/chars"
sys.path.insert(0, str(ROOT / "harness/tools"))
sys.path.insert(0, str(ROOT / "harness/tools/sprite_tool"))
from celio import Cel                                              # noqa: E402
import cel_blit_prep as P                                          # noqa: E402


def shr_table(k):
    """SHR[b] = b >> 2k, the in-byte part of a k-pixel right shift."""
    return [(b >> (2 * k)) & 0xFF for b in range(256)]


def shl_table(k):
    """SHL[b] = (b << (8-2k)) & $FF, the part that spills into the next byte."""
    return [(b << (8 - 2 * k)) & 0xFF for b in range(256)]


def shift_row_bytes(src, k):
    """Shift one packed row right by k pixels, byte-wise with a carry. w -> w+1 bytes.

    This is what the 6809 loop does: table lookup for the in-byte part, OR the carry
    from the previous byte, and keep this byte's spill as the next carry.
    """
    if k == 0:
        return list(src)
    SHR, SHL = shr_table(k), shl_table(k)
    out, carry = [], 0
    for b in src:
        out.append(SHR[b] | carry)
        carry = SHL[b]
    out.append(carry)
    return out


def main():
    cels = sorted({re.match(r"(vwalk\d+)_", p.stem).group(1)
                   for p in CH.glob("vwalk*_src.s")})
    if not cels:
        print("  no walk cels found")
        return 1

    print("=== does a byte-wise table shift reproduce the baked pixel-space cels? ===")
    print("  %-10s %-6s %8s %8s %s" % ("cel", "phase", "rows", "bytes", "result"))
    bad_total = checked = 0
    for name in cels:
        src = CH / (name + "_src.s")
        cel = Cel(str(src))
        for k in (0, 1, 2, 3):
            # truth: cel_blit_prep's pixel-space shift, repacked
            rows_px, w = P.shift_pixels(cel, k)
            want = [P.pack_row(rows_px[r], w) for r in range(cel.h)]
            # model: byte-wise table shift with carry
            got = [shift_row_bytes(cel.orig_bytes[r], k)[:w] for r in range(cel.h)]
            bad = sum(1 for r in range(cel.h) for c in range(w)
                      if want[r][c] != got[r][c])
            checked += 1
            bad_total += bad
            if bad or k == 1:
                print("  %-10s p%-5d %8d %8d %s"
                      % (name, k, cel.h, cel.h * w,
                         "OK" if not bad else "MISMATCH %d bytes" % bad))
    print("\n  %d cel/phase combinations checked, %d mismatched" % (checked, bad_total))
    if bad_total:
        print("  the shift model is WRONG — do not cost it")
        return 1
    print("  the byte-wise table shift reproduces the pixel-space bake exactly")

    # --- how many bytes actually pass the shifter, per frame -----------------
    # The heaviest frame draws both characters. Count the bytes each cel occupies
    # and how they classify, because that is what the cycle math multiplies.
    print("\n=== bytes through the shifter, per drawn cel ===")
    print("  %-10s %6s %6s %8s %8s %8s" % ("cel", "rows", "w", "total", "opaque", "mixed"))
    tot = dict(total=0, opaque=0, mixed=0, skip=0)
    for name in cels:
        cel = Cel(str(CH / (name + "_src.s")))
        rows_px, w = P.shift_pixels(cel, 1)
        n = dict(total=0, opaque=0, mixed=0, skip=0)
        for r in range(cel.h):
            for c in range(w):
                kind = P.classify(rows_px[r], c)
                n['total'] += 1
                n['opaque' if kind == 'blast' else ('mixed' if kind == 'merge' else 'skip')] += 1
        print("  %-10s %6d %6d %8d %8d %8d"
              % (name, cel.h, w, n['total'], n['opaque'], n['mixed']))
        for key in tot:
            tot[key] += n[key]
    m = len(cels)
    print("  %-10s %6s %6s %8.0f %8.0f %8.0f   (mean per cel)"
          % ("MEAN", "", "", tot['total'] / m, tot['opaque'] / m, tot['mixed'] / m))
    print("\n  of %.0f footprint bytes, %.0f are transparent (%.0f%%) — these need NOT"
          % (tot['total'] / m, tot['skip'] / m, 100 * tot['skip'] / tot['total']))
    print("  pass the shifter if runs are skipped BEFORE shifting rather than after.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
