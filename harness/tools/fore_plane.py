#!/usr/bin/env python3
r"""fore_plane.py — P5.28: where a screen's FOREGROUND plane is, in port framebuffer bytes.

DRAWALL draws the foreground list AFTER the characters [GRAFIX.S:484; P5.0 §3B], so anything a
character overlaps there should occlude him. The tile bake flattens back and fore into one
opaque page (tile_probe.s's header), so the port cannot honour that yet. A character placed
clear of every rectangle this prints is therefore drawn the same either way -- and that is the
only claim such a placement supports. Plane ordering itself stays UNTESTED.

The lists are bg_compose's own (Renderer.sure -> .fg / .bg), not a re-derivation. Each entry
is laid by Page.lay: rows yco-h+1 .. yco, Apple bytes xco .. xco+w-1. The port framebuffer is
hgr_screen_convert's: rows 1:1, Apple pixel x -> port pixel x+20 (LEFT_MARGIN 5 bytes).

  python harness/tools/fore_plane.py [--level LEVEL0] [--screen 1] [--json OUT]
"""
import argparse
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import bg_compose as BC                                     # noqa: E402

MARGIN_PX = 20


def rects(r, lst):
    out = []
    for image, xco, yco, op in lst:
        tab = r.tabs[1] if image & 0x80 else r.tabs[0]
        idx = (image & 0x7F) - 1
        if not (0 <= idx < len(tab)) or tab[idx] is None:
            continue
        w, h, _ = tab[idx]
        top = max(0, yco - h + 1)
        bot = min(191, yco)
        px0 = MARGIN_PX + 7 * xco
        px1 = MARGIN_PX + 7 * (xco + w) - 1
        out.append(dict(image=image, op=op, xco=xco, yco=yco, w=w, h=h,
                        rows=[top, bot], bytes=[px0 // 4, px1 // 4], px=[px0, px1]))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--level", default="LEVEL0")
    ap.add_argument("--screen", type=int, default=1)
    ap.add_argument("--json", default=None)
    a = ap.parse_args()
    bp = BC.Blueprint((BC.LEVELS / a.level).read_bytes())
    bg1 = BC.read_table(BC.IMAGES / "IMG.BGTAB1.DUN")
    bg2 = BC.read_table(BC.IMAGES / "IMG.BGTAB2.DUN")
    r = BC.Renderer(bp, bg1, bg2, level=int(a.level.replace("LEVEL", "")), bgset1=0)
    r.sure(a.screen)
    fg = rects(r, r.fg)
    print("%s screen %d: %d background entries, %d FOREGROUND entries"
          % (a.level, a.screen, len(r.bg), len(fg)))
    print("  %-6s %-4s %5s %5s  %-11s %-11s %s" % ("image", "op", "xco", "yco", "rows", "fb bytes", "port px"))
    for e in sorted(fg, key=lambda e: (e["rows"][0], e["bytes"][0])):
        print("  $%02X    %-4s %5d %5d  %3d..%-3d    %2d..%-2d       %3d..%d"
              % (e["image"], e["op"], e["xco"], e["yco"], e["rows"][0], e["rows"][1],
                 e["bytes"][0], e["bytes"][1], e["px"][0], e["px"][1]))
    if r.omitted:
        print("  omitted by bg_compose (state-dependent): %s" % dict(r.omitted))
    if a.json:
        pathlib.Path(a.json).write_text(json.dumps(dict(fg=fg, omitted=r.omitted)), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
