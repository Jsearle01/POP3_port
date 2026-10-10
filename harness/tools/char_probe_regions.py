#!/usr/bin/env python3
r"""char_probe_regions.py — the character probe's comparison, broken out PER DRAW (P5.28; P5.29).

A whole-screen EXACT says nothing about whether each draw did anything. Per draw this reports,
over the draw's own frame (the reference's columns and the routine's, rows top..yco):
  changed   bytes the PREDICTION changes against the bare tile reference (not vacuous)
  port      bytes the PORT's capture differs from the prediction (must be 0)
and two CONTROLS -- the prediction rebuilt with a plausible mistake, and how many bytes of the
capture each would have contradicted, so a pass is shown to have been able to fail:
  p528      P5.28's colour rule (every cel coloured at even, the mirror swapped iff 7*apple_w
            is even) -- the rule Jay rejected at P5.28's gate
  opposite  the oracle-rule reference with every orange/blue pixel swapped: the OTHER colour
            phase. For an odd-width mirror this is what the dispatch's formula
            `parity(X) XOR (mirrored AND 7*apple_w even)` would have drawn (P5.29 §3D)
A control at 0 means that mistake is invisible for that draw -- reported, not hidden.
"""
import argparse
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "sprite_tool"))
import char_probe_plan as CP                                # noqa: E402
import cel_blit_prep as P                                   # noqa: E402

STRIDE = 80
SWAP = (0, 2, 1, 3)


def draw_onto(fb, segs, h, w, top, col):
    base = top * STRIDE + col
    init = {o - base: v for o, v in enumerate(fb)}
    out = P.simulate(segs, h, w, STRIDE, initial=init)
    return bytearray(out[o - base] for o in range(len(fb)))


def swapped(segs, h, w):
    """The same stream with every pixel's 1<->2 exchanged (skip/merge structure unchanged:
    a swap maps 0->0 and 3->3, so masks are untouched)."""
    def sb(b):
        return sum(SWAP[(b >> (6 - 2 * j)) & 3] << (6 - 2 * j) for j in range(4))
    out, p = [], 0
    for _ in range(h):
        while True:
            s = segs[p]
            out.append(s)
            p += 1
            if s == P.SEG_END:
                break
            op, c = s >> P.SEG_SHIFT, s & P.SEG_MAX_RUN
            if op == P.SEG_BLAST:
                out += [sb(b) for b in segs[p:p + c]]
                p += c
            elif op == P.SEG_MERGE:
                for i in range(c):
                    out += [segs[p + 2 * i], sb(segs[p + 2 * i + 1])]
                p += 2 * c
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--got", default=str(ROOT / "build/char_front.bin"))
    a = ap.parse_args()
    tile = bytearray(CP.TILE_REF.read_bytes())
    pred = (ROOT / "build/assets/char_ref.bin").read_bytes()
    got = pathlib.Path(a.got).read_bytes()
    place = json.load(open(CP.PLACE))
    import bake_screen as BS
    _r, fvariants, _o, _c, fore = BS.bake(place["screen"]["level"], place["screen"]["screen"], "DUN")
    print("%-9s %-5s %-4s %-4s %-14s %6s %8s %5s | controls: %5s %8s %10s"
          % ("draw", "frame", "aw", "PL", "frame bytes", "bytes", "changed", "port", "p528", "opposite",
             "plane-swap"))
    allofs = set()
    for d in place["draws"]:
        aw, w0, h, stem, p0 = CP.registry_aw(d["table"], d["image"])
        yco = d["char_y"] + d["fdy"]
        top = yco - h + 1
        hh, w, segs = CP.ref_stream(d)
        if d["facing"] == 0:
            rcol, rk = d["col"], d["phase"]
        else:
            pp = 4 * d["col"] + d["phase"] - (4 * w0 - 7 * aw)
            rcol, rk = pp // 4, pp % 4
        c0 = min(d["col"], rcol)
        c1 = max(d["col"] + w - 1, rcol + w0 + (1 if rk else 0) - 1)
        offs = [r * STRIDE + c for r in range(top, yco + 1) for c in range(c0, c1 + 1)]
        allofs |= set(offs)
        ch = sum(1 for o in offs if pred[o] != tile[o])
        bad = sum(1 for o in offs if got[o] != pred[o])
        _, w5, s5 = CP.ref_stream(d, rule="p528")
        c528 = draw_onto(tile, s5, h, w5, top, d["col"])
        copp = draw_onto(tile, swapped(segs, h, w), h, w, top, d["col"])
        # P5.30 plane-swap control, for a draw that overlaps a foreground piece: the OTHER plane
        # order -- a MID draw redone on top of the finished picture (as if FLAT), a FLAT draw with
        # the foreground pass run over it (as if MID) -- and the bytes of the capture it contradicts
        swap = "-"
        if d.get("expect_fore"):
            if d.get("plane", "mid") == "mid":
                alt = draw_onto(bytearray(pred), segs, h, w, top, d["col"])
            else:
                alt = BS.replay_fore(pred, fvariants, fore)
            swap = str(sum(1 for o in offs if alt[o] != got[o]))
        print("%-9s %5d %4d %4d %3d..%-2d r%d..%-3d %6d %8d %5d | %14d %8d %10s"
              % (d["name"], d["frame"], aw, CP.oracle_pl(d), c0, c1, top, yco, len(offs), ch, bad,
                 sum(1 for o in offs if c528[o] != got[o]), sum(1 for o in offs if copp[o] != got[o]),
                 swap))
    outside = set(range(len(tile))) - allofs
    print("outside every frame: %d B; port vs bare tile reference differ: %d"
          % (len(outside), sum(1 for o in outside if got[o] != tile[o])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
