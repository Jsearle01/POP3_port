#!/usr/bin/env python3
r"""tile_working_set.py - P5.1. How many TILES a level actually needs, per screen and in total.

★★★ P5.0 REPORTED 178 CELS / 21,450 B AS "THE DUNGEON TILES". That is the whole content of
IMG.BGTAB1.DUN + IMG.BGTAB2.DUN -- the tile set for ALL FIFTEEN dungeon levels. It is a sum,
and this dispatch's subject is that a sum is not a residency requirement.

TWO BOUNDS, both stated, because one of them is achievable and the other is safe:

  LOWER  the images bg_compose.py's display lists actually reference for each screen. Exact for
         every blueprint-determined piece; misses the state-dependent ones bg_compose omits by
         design (gate bars, flames, slicer blade, loose-floor motion, exit door).

  UPPER  the lower bound plus every image any code path can reach for the PIECE IDS THE LEVEL
         CONTAINS -- the gate's 16 bar frames, the 9 torch flames, the slicer's blade and gap
         sets, the loose floor's animation, the exit's stairs/door, and the climb-up masks.
         Enumerated from BGDATA.S and GAMEBG.S by name, so the list is auditable.

WHY THE ANSWER MATTERS. FRAMEADV's `FAST` runs EVERY frame and redraws marked blocks straight
out of the tile tables [TOPCTRL.S:961 DoFast -> `jsr fast`; FRAMEADV.S:189 FAST -> RedBlockFast
-> fastlay]. So the tiles are resident WHILE characters draw -- they are not a load-time-only
cost, which is what P5.0 §3F assumed. The size of that resident set is therefore load-bearing.
"""
import pathlib
import statistics
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "harness/tools"))

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

import bg_compose as B                                              # noqa: E402
from demo_asset_census import coco3_bytes                           # noqa: E402

# Images no blueprint names but some code path can draw, keyed by the piece id that
# unlocks them. All from BGDATA.S unless marked.
STATE_IMAGES = {
    B.gate:   list(B.gate8c) + list(B.gate8b) +
              [B.gatebotSTA, B.gatebotORA, B.gateB1, B.gatecmask],
    B.torch:  [0x52, 0x53, 0x54, 0x55, 0x56, 0x61, 0x62, 0x63, 0x64],   # GAMEBG.S:147 torchflame
    B.slicer: list(B.slicertop) + list(B.slicerbot) + list(B.slicerfrnt) +
              [0x8e, 0x8f, 0x90, 0x5d, 0x5f] + [0x38, 0x46, 0x53, 0x55],  # slicerbot2, slicergap
    B.loose:  list(B.loosea) + list(B.loosed) + [B.looseb],
    B.spikes: list(B.spikea) + list(B.spikeb),
    B.exitp:  [B.stairs, B.door, B.doormask, B.toprepair],
    B.exit2:  [B.stairs, B.door, B.doormask, B.toprepair],
    B.floor:  [B.CUmask, B.CUpiece, B.CUpost],      # climb-up masking, any floor edge
    B.posts:  [B.CUpost],
}

# ★★★ ADDENDUM A.3 STEP 6 — IMAGES NO BLUEPRINT AND NO PIECE ID NAMES, drawn straight by
# GAMEBG.S. They were missed for exactly the reason SWORDTAB was: the walk followed the
# tables the blueprint indexes and these are not among them.
#   GAMEBG.S:99-101   bullet $88 / bline 89,8a,8b / blank $8c  ";in bgtable2"
#                     -> bit 7 set -> bgtable2 indices 8..12. The strength meters, redrawn
#                     every frame by `updatemeters` at the tail of FAST.
#   GAMEBG.S:1134     pretext sets TABLE = bgtable2 and prchar does `sbc #"/"`, so a glyph is
#                     bgtable2[ascii - '/']: "0"->1 .. "9"->10, "A"->$12 .. "Z"->$2B.
# ★ The DEMO draws no text: RESTART suppresses the banner at level 0 (`lda level / beq
# :nomsg`) and timerequest is never set, so the glyphs are a REAL-GAME cost, not a demo one.
METERS = [0x88, 0x89, 0x8A, 0x8B, 0x8C]
GLYPH_DIGITS = [0x80 | i for i in range(1, 11)]
GLYPH_LETTERS = [0x80 | i for i in range(0x12, 0x2C)]


def main():
    level = sys.argv[1] if len(sys.argv) > 1 else "LEVEL0"
    bgset = sys.argv[2] if len(sys.argv) > 2 else "DUN"
    bp = B.Blueprint((B.LEVELS / level).read_bytes())
    bg1 = B.read_table(B.IMAGES / ("IMG.BGTAB1.%s" % bgset))
    bg2 = B.read_table(B.IMAGES / ("IMG.BGTAB2.%s" % bgset))
    tabs = (bg1, bg2)

    def cost(imgs):
        n = 0
        for im in imgs:
            if not im:
                continue
            t = tabs[1] if im & 0x80 else tabs[0]
            i = (im & 0x7F) - 1
            if 0 <= i < len(t) and t[i]:
                w, h, _ = t[i]
                n += coco3_bytes(w, h)
        return n

    pieces = set(b & 0x1F for b in bp.type)
    extra = set()
    for p in pieces:
        extra |= set(STATE_IMAGES.get(p, ()))
    extra.discard(0)

    rows, union = [], set()
    for s in range(1, 25):
        r = B.Renderer(bp, bg1, bg2, level=int(level.replace("LEVEL", "")),
                       bgset1=0 if bgset == "DUN" else 1)
        r.sure(s)
        imgs = {e[0] for e in r.bg + r.fg}
        union |= imgs
        rows.append((s, imgs))

    print("%s / bgset %s — TILE WORKING SET" % (level, bgset))
    print("  pieces present: %s" % sorted(PIECE(p) for p in pieces))
    print()
    print("  screen   images  lower B   +state  upper B")
    for s, imgs in rows:
        up = imgs | extra
        print("    %2d      %5d  %7d  %7d  %7d"
              % (s, len(imgs), cost(imgs), len(up) - len(imgs), cost(up)))
    pop = [(s, i) for s, i in rows if len(i) > 4]
    lows = [cost(i) for _, i in pop]
    ups = [cost(i | extra) for _, i in pop]
    print()
    print("  populated screens (%d): lower max %d / median %d, upper max %d / median %d"
          % (len(pop), max(lows), int(statistics.median(lows)),
             max(ups), int(statistics.median(ups))))
    print("  WHOLE LEVEL, union over 24 screens : %d images, lower %d B, upper %d B"
          % (len(union), cost(union), cost(union | extra)))
    print()
    print("  NOT NAMED BY ANY BLUEPRINT OR PIECE ID — drawn directly by GAMEBG.S:")
    print("    strength meters (bgtable2 8-12)     %5d B   every frame, inside FAST" % cost(METERS))
    print("    text digits 0-9                     %5d B   ★ 0 B in the DEMO: level 0" % cost(GLYPH_DIGITS))
    print("    text letters A-Z                    %5d B     suppresses the banner" % cost(GLYPH_LETTERS))
    print("  DEMO-CORRECT tile total (upper + meters): %d B" % cost(union | extra | set(METERS)))
    print("  REAL-GAME tile total (+ the full glyph set): %d B"
          % cost(union | extra | set(METERS) | set(GLYPH_DIGITS) | set(GLYPH_LETTERS)))
    whole = [c for c in bg1 if c] + [c for c in bg2 if c]
    print("  the two FILES (all 15 dungeon levels): %d images, %d B"
          % (len(whole), sum(coco3_bytes(c[0], c[1]) for c in whole)))
    print("  -> the level needs %.0f%% of the file set (upper bound)"
          % (100.0 * cost(union | extra) / sum(coco3_bytes(c[0], c[1]) for c in whole)))
    return 0


def PIECE(p):
    return B.PIECE_NAMES[p] if p < len(B.PIECE_NAMES) else str(p)


if __name__ == "__main__":
    sys.exit(main())
