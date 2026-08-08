#!/usr/bin/env python3
"""span_shift.py — approach (b): per-row spans, built, verified, and measured.

P3.35. The representation decision turns on ONE quantity — how many bytes pass the
shifter — because P3.34 established the per-byte cost is bounded and the workload is
not. Approach (b) is the cheapest of the three designs, and its measured position
brackets the other two: if it fits, the decision is made; if it does not, the gap it
leaves is exactly what (a) and (c) would buy.

THE DESIGN. For each row, store the span from the first to the last non-transparent
byte, and shift only that span. Interior transparent bytes INSIDE the span still pass
the shifter — that is (b)'s known inefficiency, and quantifying it is the point.

THE EDGE GROWTH IS HANDLED, NOT ASSUMED AWAY. A span of n bytes shifted right by k
pixels occupies n+1 bytes, and both ends become partial: pixels from the byte before
the span spill into its first byte, and the span's last byte spills into the one after.
So the shifted span is [start, start+n+1), and the two edge bytes must be MERGED with
the destination rather than stored, because each holds background in the pixels the
shift did not fill. Interior bytes are whole and may be stored.

VERIFIED AGAINST AN INDEPENDENT TRUTH SOURCE. The baked phase-k cels were produced by
cel_blit_prep.py shifting in PIXEL space and repacking; this shifts a byte span with a
table and a carry. Neither derives from the other. Five of this project's six silent
instrument failures shared an input with their subject, so the independence is the
check's whole value.
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

BUDGET = 29673          # usable cycles per frame (P3.19)
BASE = 19579            # heaviest frame today, pre-shifted (P3.19)
SHIFT_CY = 21           # counted floor for a table-driven shift (P3.34)


def row_span(px, w):
    """(first, last+1) non-transparent byte columns of a row, or None if empty."""
    cols = [c for c in range(w) if P.classify(px, c) != 'skip']
    return (cols[0], cols[-1] + 1) if cols else None


def shift_span(src, lo, hi, k):
    """Shift src[lo:hi] right by k pixels, returning hi-lo+1 bytes.

    The extra byte is the spill past the span's end. The byte BEFORE the span is
    all-transparent by construction (it is outside the span), so it contributes no
    carry in — which is why a span can be shifted independently of its row.
    """
    if k == 0:
        return list(src[lo:hi])
    out, carry = [], 0
    for b in src[lo:hi]:
        out.append(((b >> (2 * k)) & 0xFF) | carry)
        carry = (b << (8 - 2 * k)) & 0xFF
    out.append(carry)
    return out


def main():
    cels = sorted({re.match(r"(vwalk\d+)_", p.stem).group(1)
                   for p in CH.glob("vwalk*_src.s")})
    if not cels:
        print("  no walk cels found")
        return 1

    print("=== (b) correctness: does a shifted SPAN reproduce the baked cel? ===")
    bad_total = checked = 0
    for name in cels:
        cel = Cel(str(CH / (name + "_src.s")))
        for k in (1, 2, 3):
            rows_px, w = P.shift_pixels(cel, k)
            bad = 0
            for r in range(cel.h):
                sp = row_span(cel.pixels[r], cel.w)
                if sp is None:
                    continue
                lo, hi = sp
                got = shift_span(cel.orig_bytes[r], lo, hi, k)
                want = P.pack_row(rows_px[r], w)
                for i, b in enumerate(got):
                    c = lo + i
                    if c < w and want[c] != b:
                        bad += 1
            checked += 1
            bad_total += bad
    print("  %d cel/phase combinations, %d mismatched" % (checked, bad_total))
    if bad_total:
        print("  (b) IS WRONG — not costing it")
        return 1
    print("  a span shifted in byte space reproduces the pixel-space bake exactly")

    # --- the deciding quantity -------------------------------------------
    print("\n=== bytes through the shifter, per cel ===")
    print("  %-10s %7s %8s %8s %9s" % ("cel", "rows", "footprint", "span B", "drawn B"))
    tot_fp = tot_span = tot_drawn = 0
    for name in cels:
        cel = Cel(str(CH / (name + "_src.s")))
        rows_px, w = P.shift_pixels(cel, 1)
        fp = span = drawn = 0
        for r in range(cel.h):
            fp += w
            sp = row_span(cel.pixels[r], cel.w)
            if sp:
                span += (sp[1] - sp[0]) + 1        # +1 for the shift's spill byte
            drawn += sum(1 for c in range(w) if P.classify(rows_px[r], c) != 'skip')
        print("  %-10s %7d %8d %8d %9d" % (name, cel.h, fp, span, drawn))
        tot_fp += fp
        tot_span += span
        tot_drawn += drawn
    n = len(cels)
    fp, span, drawn = tot_fp / n, tot_span / n, tot_drawn / n
    print("  %-10s %7s %8.0f %8.0f %9.0f   (mean)" % ("MEAN", "", fp, span, drawn))

    waste = span - drawn
    print("\n  interior transparent waste: %.0f B/cel (%.0f%% of the span)"
          % (waste, 100 * waste / span))
    print("  -- these bytes pass the shifter and draw nothing; (a) and (c) buy exactly")
    print("     this back, and nothing else.")

    # --- the frame ---------------------------------------------------------
    print("\n=== heaviest frame, two characters, shift additive at %d cy/byte ===" % SHIFT_CY)
    print("  %-28s %8s %9s %9s %6s %s" % ("design", "B/cel", "added", "frame", "%", ""))
    for label, b in (("(bracket) every byte", fp),
                     ("(b) per-row spans", span),
                     ("(bracket) drawn bytes only", drawn)):
        add = int(2 * b * SHIFT_CY)
        tot = BASE + add
        print("  %-28s %8.0f %9d %9d %5.0f%% %s"
              % (label, b, add, tot, 100 * tot / BUDGET,
                 "FITS" if tot <= BUDGET else "OVER"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
