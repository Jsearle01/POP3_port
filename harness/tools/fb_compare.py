#!/usr/bin/env python3
r"""fb_compare.py — P5.5. Compare two 320x192x4 framebuffers and say WHERE they differ.

A differing-byte COUNT is not a finding. P5.5's AC5 asks for every differing region
enumerated with none unexplained, and a count cannot tell "the four omission classes are
absent, as predicted" from "the renderer dropped a row" — those need opposite responses.
So the differing bytes are clustered into connected boxes and each box is reported with
its rows, its columns and its byte count, largest first.

Two modes, and the difference is the exit code, not the output:

  * DEFAULT (the smoke test's): any difference at all is a failure. This is the port
    against bake_screen.py's reference, where byte-identity is guaranteed BY CONSTRUCTION
    -- the bake replays its own page before it emits -- so a difference means the RUNNING
    machine departed from the model, which is the only thing this comparison can discover.

  * --report-only (AC3's port-vs-oracle): differences are EXPECTED and are the finding.
    The oracle's page carries characters, meters, torch flames and gate bars that the
    static bake does not draw at all.

Geometry is 80 bytes/row x 192 rows = 15,360 B. Both inputs must be exactly that.
"""
import argparse
import pathlib
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

STRIDE, ROWS = 80, 192
SIZE = STRIDE * ROWS


def load(path):
    b = pathlib.Path(path).read_bytes()
    if len(b) != SIZE:
        raise SystemExit("%s is %d B, not the %d B of a 320x192x4 framebuffer"
                         % (path, len(b), SIZE))
    return b


def boxes(diff):
    """Cluster differing cells into connected boxes (8-neighbour, iterative flood).

    Recursion is not used on purpose: a differing region can be thousands of cells and
    Python's default recursion limit is 1,000, so a deep flood would raise inside what is
    meant to be a diagnostic.
    """
    seen = set()
    out = []
    for start in diff:
        if start in seen:
            continue
        seen.add(start)
        stack = [start]
        cells = []
        while stack:
            r, c = stack.pop()
            cells.append((r, c))
            for dr in (-1, 0, 1):
                for dc in (-1, 0, 1):
                    n = (r + dr, c + dc)
                    if n in diff and n not in seen:
                        seen.add(n)
                        stack.append(n)
        rs = [r for r, _ in cells]
        cs = [c for _, c in cells]
        out.append((len(cells), min(rs), max(rs), min(cs), max(cs)))
    out.sort(reverse=True)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--want", required=True)
    ap.add_argument("--got", required=True)
    ap.add_argument("--label", default="framebuffer comparison")
    ap.add_argument("--report-only", action="store_true",
                    help="differences are the finding, not a failure (exit 0 regardless)")
    ap.add_argument("--max-boxes", type=int, default=24)
    args = ap.parse_args()

    want, got = load(args.want), load(args.got)
    diff = {(i // STRIDE, i % STRIDE) for i in range(SIZE) if want[i] != got[i]}
    same = SIZE - len(diff)

    print("FB COMPARE — %s" % args.label)
    print("  want %s" % args.want)
    print("  got  %s" % args.got)
    print("  %d/%d identical, %d differ  (%.2f%%)  -> %s"
          % (same, SIZE, len(diff), 100.0 * same / SIZE,
             "EXACT" if not diff else "DIFFERS"))

    if diff:
        bs = boxes(diff)
        print("  %d connected region(s), largest first:" % len(bs))
        print("    %-8s %-12s %-12s" % ("bytes", "rows", "cols"))
        for n, r0, r1, c0, c1 in bs[:args.max_boxes]:
            print("    %-8d %-12s %-12s" % (n, "%d..%d" % (r0, r1), "%d..%d" % (c0, c1)))
        if len(bs) > args.max_boxes:
            rest = sum(n for n, _, _, _, _ in bs[args.max_boxes:])
            print("    ... and %d more region(s), %d bytes"
                  % (len(bs) - args.max_boxes, rest))

    if args.report_only:
        return 0
    return 0 if not diff else 1


if __name__ == "__main__":
    sys.exit(main())
