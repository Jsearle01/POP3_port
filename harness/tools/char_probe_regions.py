#!/usr/bin/env python3
r"""char_probe_regions.py — P5.28: the character probe's comparison, broken out PER DRAW.

A whole-screen EXACT says nothing about whether each draw did anything. Per draw this reports,
over the draw's own frame (the reference's columns and the routine's, rows top..yco):
  changed   bytes the PREDICTION changes against the bare tile reference (the draw is not
            invisible -- a draw that changed nothing would pass vacuously)
  port      bytes the PORT's capture differs from the prediction (must be 0)
and then the CONTROLS: the prediction rebuilt with each plausible mistake, and how many bytes
of the capture each would have contradicted -- so a pass is shown to have been able to fail:
  no-swap   the mirror drawn without the blue<->orange swap (t=1 instead of 2)
  no-pad    the mirror registered without d (the routine's frame at `col`, not d px left)
  phase-0   the shifted draw at phase 0
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
import sprite_convert as SC                                 # noqa: E402
import bake_chars as B                                      # noqa: E402
from celio import Cel                                       # noqa: E402

STRIDE = 80


def draw_onto(fb, segs, h, w, top, col):
    base = top * STRIDE + col
    init = {o - base: v for o, v in enumerate(fb)}
    out = P.simulate(segs, h, w, STRIDE, initial=init)
    return bytearray(out[o - base] for o in range(len(fb)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--got", default=str(ROOT / "build/char_front.bin"))
    a = ap.parse_args()
    tile = bytearray(CP.TILE_REF.read_bytes())
    pred = (ROOT / "build/assets/char_ref.bin").read_bytes()
    got = pathlib.Path(a.got).read_bytes()
    place = json.load(open(CP.PLACE))
    print("per draw: bytes over the draw's frame | prediction changes vs bare tile | port vs prediction")
    regions = []
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
        regions.append((d, offs, top))
        ch = sum(1 for o in offs if pred[o] != tile[o])
        bad = sum(1 for o in offs if got[o] != pred[o])
        print("  %-9s rows %d..%d bytes %d..%d  %4d B  changed %3d  port-vs-predicted %d"
              % (d["name"], top, yco, c0, c1, len(offs), ch, bad))
    outside = set(range(len(tile))) - {o for _, offs, _ in regions for o in offs}
    print("  outside every frame: %d B, port vs bare tile reference differ: %d"
          % (len(outside), sum(1 for o in outside if got[o] != tile[o])))

    print()
    print("controls (a WRONG prediction, compared with the same capture -- each must disagree):")
    for d, offs, top in regions:
        aw, w0, h, stem, p0 = CP.registry_aw(d["table"], d["image"])
        if d["facing"] == 1:
            raw = SC.get_cel(B.IMG / d["table"], d["image"])
            path = CP.WORK / ("%s_mirror_noswap.s" % stem)
            SC.convert_one(B.IMG / d["table"], d["image"], path, "x", 0,
                           (7 * raw["w"]) % 2 != 0, True, trim=True, quiet=True)
            cel = Cel(str(path))
            rows, w = P.shift_pixels(cel, d["phase"])
            segs = sum((P.encode_row(rows[r], w) for r in range(cel.h)), [])
            wrong = draw_onto(tile, segs, h, w, top, d["col"])
            print("  %-9s no-swap: %d of its bytes would differ" % (d["name"], sum(1 for o in offs if wrong[o] != got[o])))
            hh, w, segs = CP.ref_stream(d)
            pad = 4 * w0 - 7 * aw
            # unregistered: the routine's frame placed at col instead of d px left
            shift = -pad // 4 if pad % 4 == 0 else None
            src = Cel(str(ROOT / "content/chars" / B.short(d["table"]) / ("%s_src.s" % stem)))
            mir = [[0] * (4 * src.w) for _ in range(src.h)]
            for r in range(src.h):
                px = list(src.pixels[r])
                mir[r] = [(0, 2, 1, 3)[v] if (7 * aw) % 2 == 0 else v for v in px[::-1]]
            rows = [row + [0] * 0 for row in mir]
            segs2 = sum((P.encode_row(rows[r], src.w) for r in range(src.h)), [])
            wrong = draw_onto(tile, segs2, h, src.w, top, d["col"])
            print("  %-9s no-pad:  %d of its bytes would differ" % (d["name"], sum(1 for o in offs if wrong[o] != got[o])))
        elif d["phase"]:
            src = Cel(str(ROOT / "content/chars" / B.short(d["table"]) / ("%s_src.s" % stem)))
            rows, w = P.shift_pixels(src, 0)
            segs = sum((P.encode_row(rows[r], w) for r in range(src.h)), [])
            wrong = draw_onto(tile, segs, h, w, top, d["col"])
            print("  %-9s phase-0: %d of its bytes would differ" % (d["name"], sum(1 for o in offs if wrong[o] != got[o])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
