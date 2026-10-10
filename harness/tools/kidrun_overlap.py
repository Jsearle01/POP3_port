#!/usr/bin/env python3
r"""kidrun_overlap.py — P5.32: P3.32's discriminating test, on a captured step of the kid-run probe.

P3.32: "1,333 overlapped cells across the run and the princess byte-exact at every one, which is
the discriminating test." A whole-framebuffer EXACT already implies it; this says WHERE the bytes
were that could have gone wrong, so a pass is shown to have exercised them:

  guard frame    every byte of the STATIONARY character's frame -- the one a mover's save straddles
                 (P3.32 §3A: "the STATIONARY character is the one vandalised")
  frames overlap the bytes inside BOTH actors' frames
  both opaque    the bytes where BOTH draws put a non-transparent pixel -- the overlapped cells

Reads kidrun_plan.py's kidrun_ref_N.json (rectangles and the both-opaque offsets, from the
no-history prediction), the prediction and the capture. Exit 1 on any wrong byte in any of them.
"""
import argparse
import json
import pathlib
import sys

STRIDE = 80


def cells(r):
    return {row * STRIDE + c for row in range(r[0], r[1] + 1) for c in range(r[2], r[3] + 1)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--want", required=True)
    ap.add_argument("--got", required=True)
    ap.add_argument("--meta", required=True)
    a = ap.parse_args()
    want = pathlib.Path(a.want).read_bytes()
    got = pathlib.Path(a.got).read_bytes()
    m = json.loads(pathlib.Path(a.meta).read_text())
    kid, gd = cells(m["kid_rect"]), cells(m["guard_rect"])
    regions = [("guard frame", gd), ("kid frame", kid), ("frames overlap", kid & gd),
               ("both opaque", set(m["both_opaque"]))]
    bad = 0
    for name, cs in regions:
        wrong = sum(1 for o in cs if want[o] != got[o])
        bad += wrong
        print("  step %-3d %-15s %5d B, %d wrong" % (m["step"], name, len(cs), wrong))
    print("  OVERLAP %s  step %d: %d both-opaque cells, %d B of frame overlap"
          % ("EXACT" if not bad else "WRONG", m["step"], len(m["both_opaque"]), len(kid & gd)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
