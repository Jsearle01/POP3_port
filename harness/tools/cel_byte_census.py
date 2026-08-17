#!/usr/bin/env python3
"""harness/tools/cel_byte_census.py — count what a baked cel actually asks the blitter to do.

POP P3.44, Part A. P3.19 charged the draw at 4.5 cy/byte opaque and **22 cy/byte merge**,
the latter called "a 6809 floor". P3.44 measured the whole draw at 26,849 cy/iteration, so
the counted rate is now testable: parse the shipped cel streams, count the bytes in each
segment class, and divide.

Segment format (blit_core.s, from harness/tools/cel_blit_prep.py):
    $00            end of row
    $01 nn         skip nn transparent bytes
    $02 nn <data>  blast nn opaque bytes
    $03 nn <pairs> merge nn bytes as (mask, src)

This reads the ASSEMBLED DATA, not the generator's intent -- the point of the exercise is
to check a counted figure against the machine, so the input has to be the same bytes the
machine walks.
"""
import re
import sys


def load_fcb(path):
    """Every `fcb` byte in file order. The cel is one flat stream."""
    out = []
    for line in open(path, encoding="utf-8", errors="replace"):
        line = line.split(";")[0]
        m = re.search(r"\bfcb\s+(.*)", line, re.I)
        if not m:
            continue
        for tok in m.group(1).split(","):
            tok = tok.strip()
            if not tok:
                continue
            if tok.startswith("$"):
                out.append(int(tok[1:], 16))
            elif re.fullmatch(r"-?\d+", tok):
                out.append(int(tok) & 0xFF)
            else:
                return out, tok        # a symbol: stop, this is not cel data
    return out, None


def census(path):
    b, stop = load_fcb(path)
    if len(b) < 3:
        return None
    rows, width, i = b[0], b[1], 2
    skip = blast = merge = 0
    segs = 0
    for _ in range(rows):
        while i < len(b):
            op = b[i]; i += 1
            if op == 0x00:
                break
            segs += 1
            n = b[i]; i += 1
            if op == 0x01:
                skip += n
            elif op == 0x02:
                blast += n; i += n
            elif op == 0x03:
                merge += n; i += 2 * n
            else:
                return {"path": path, "error": f"bad opcode ${op:02X} at {i-2}"}
    return {"path": path, "rows": rows, "width": width, "skip": skip,
            "blast": blast, "merge": merge, "segs": segs, "drawn": blast + merge}


def main():
    paths = sys.argv[1:]
    if not paths:
        print("usage: cel_byte_census.py <cel.s> ...")
        return 1
    tot = {"rows": 0, "blast": 0, "merge": 0, "skip": 0, "segs": 0}
    print(f"  {'cel':<40} {'rows':>5} {'w':>3} {'blast':>6} {'merge':>6} {'skip':>6} {'segs':>5}")
    for p in paths:
        c = census(p)
        if not c:
            print(f"  {p:<40} (not cel data)")
            continue
        if "error" in c:
            print(f"  {p:<40} PARSE ERROR: {c['error']}")
            continue
        print(f"  {p.split('/')[-1]:<40} {c['rows']:>5} {c['width']:>3}"
              f" {c['blast']:>6} {c['merge']:>6} {c['skip']:>6} {c['segs']:>5}")
        for k in tot:
            tot[k] += c[k]
    print(f"\n  totals: rows={tot['rows']} blast={tot['blast']} merge={tot['merge']}"
          f" skip={tot['skip']} segments={tot['segs']}")
    # P3.19's counted model, for comparison against P3.44's measured draw.
    counted = tot["blast"] * 4.5 + tot["merge"] * 22
    print(f"  P3.19 counted draw = {tot['blast']}x4.5 + {tot['merge']}x22 = {counted:.0f} cy"
          f"   (segments and per-row overhead NOT included)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
