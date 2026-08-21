#!/usr/bin/env python3
r"""variant_census.py - P5.4 AC2/AC3/AC4. How many CONTEXT VARIANTS does a whole level need?

★★★ THE FIGURE THIS EXISTS TO KEEP APART. A per-SCREEN variant set is a RESIDENCY requirement —
only one screen is composited at a time, and a room change rebuilds. A LEVEL total is a SUM: what
the disk must carry, or what a design that never reloads would have to hold. **They are different
numbers over different extents and this project has merged that pair five times.** Both are
printed, each labelled with which it is.

THE BAKE MODEL BEING COUNTED, stated because counting requires one and designing one is out of
scope: a variant is the CONVERTED COMPOSITED PAGE's pixels over the cel's bounding box, with the
pixels the cel's own isolated conversion makes index 0 left transparent. Shape from the cel,
colour from the page. That is the minimal reading of P5.3's finding and it is what makes the
port's composite reproduce bg_compose by construction.

TWO SIZE FIGURES:
  raw packed      ceil(w*7/4) * h bytes, the flat 2 bpp form
  segment stream  cel_blit_prep.encode_row, the form the blitter actually consumes
                  [blit_core.s:41-48] -- skip runs cost one header byte and no payload, so a
                  mostly-black screen is far cheaper than its raw figure suggests.

Entries the census does NOT count, and says so rather than absorbing them:
  * AND / mask entries -- no bitwise AND exists on palette indices; the blitter's $C0 merge
    segment is where they would go, and designing that is out of scope here.
"""
import argparse
import pathlib
import statistics
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "harness/tools"))

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

import bg_compose as B                                                  # noqa: E402
from hgr_screen_convert import deinterleave                             # noqa: E402
from sprite_convert import convert_sprite_to_coco3                      # noqa: E402
from cel_blit_prep import encode_row                                    # noqa: E402

PIECE = B.PIECE_NAMES


def page_pixels(page_bytes):
    """The composited HGR page -> 192 rows of 280 four-colour indices."""
    rows = deinterleave(page_bytes)
    flat = b"".join(rows)
    packed, wb = convert_sprite_to_coco3(list(flat), 192, 40, start_col=0)
    out = []
    for y in range(192):
        px = []
        for b in packed[y * wb:(y + 1) * wb]:
            px += [(b >> 6) & 3, (b >> 4) & 3, (b >> 2) & 3, b & 3]
        out.append(px[:280])
    return out


def cel_shape(cel, start_col):
    """The cel converted ALONE -> rows of indices, TOP FIRST. Used only for transparency."""
    w, h, data = cel
    packed, wb = convert_sprite_to_coco3(list(data), h, w, start_col=start_col)
    rows = []
    for r in range(h):
        px = []
        for b in packed[r * wb:(r + 1) * wb]:
            px += [(b >> 6) & 3, (b >> 4) & 3, (b >> 2) & 3, b & 3]
        rows.append(px[:w * 7])
    return rows[::-1]


def variant_of(cel, xco, yco, pagepx, opaque):
    """-> (key, raw_bytes, seg_bytes).

    ★ `opaque` is the oracle's OPACITY, and it changes the segment cost by more than
    anything else here. An `sta` entry paints its whole bounding box INCLUDING its black,
    so every byte is a BLAST (1 header + n data). An `ora` entry leaves index-0 pixels
    alone, so bytes that mix lit and unlit pixels become MERGE segments at TWO bytes per
    byte. Treating every entry as transparent -- the first cut of this census did -- turns
    51 of screen 1's 76 entries into merges that the oracle never performs.
    """
    w, h, _ = cel
    px0 = xco * 7
    phase = px0 % 4
    shape = cel_shape(cel, start_col=px0)
    top = yco - h + 1
    wid = (w * 7 + phase + 3) // 4          # bytes once left-padded to a byte boundary
    rows = []
    for r in range(h):
        y = top + r
        row = [0] * (wid * 4)
        if 0 <= y < 192:
            for c in range(w * 7):
                if not opaque and shape[r][c] == 0:
                    continue                 # `ora`: the cel does not paint here
                p = px0 + c
                if 0 <= p < 280:
                    row[phase + c] = pagepx[y][p]
        rows.append(row)
    key = bytes(v for row in rows for v in row)
    seg = 0
    for row in rows:
        seg += len(encode_row(row, wid))
    return key, wid * h, seg


OPAQUE_OPS = (B.OP_STA,)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--level", default="LEVEL0")
    ap.add_argument("--bgset", default="DUN")
    args = ap.parse_args()

    bp = B.Blueprint((B.LEVELS / args.level).read_bytes())
    bg1 = B.read_table(B.IMAGES / ("IMG.BGTAB1.%s" % args.bgset))
    bg2 = B.read_table(B.IMAGES / ("IMG.BGTAB2.%s" % args.bgset))
    tabs = (bg1, bg2)
    lvl = int(args.level.replace("LEVEL", ""))

    level_variants = {}          # (image, key) -> (raw, seg)
    per_screen = []
    skipped = {"and/mask": 0, "off page": 0}

    for s in range(1, 25):
        r = B.Renderer(bp, bg1, bg2, level=lvl, bgset1=0 if args.bgset == "DUN" else 1)
        r.sure(s)
        pagepx = page_pixels(bytes(r.paint().b))
        entries = 0
        sv = {}
        ops = {}
        for image, xco, yco, op in r.bg + r.fg:
            if op in (B.OP_AND, B.OP_MASK):
                skipped["and/mask"] += 1
                continue
            t = tabs[1] if image & 0x80 else tabs[0]
            i = (image & 0x7F) - 1
            if not (0 <= i < len(t)) or t[i] is None:
                skipped["off page"] += 1
                continue
            entries += 1
            ops[op] = ops.get(op, 0) + 1
            key, raw, seg = variant_of(t[i], xco, yco, pagepx, op in OPAQUE_OPS)
            sv[(image, key)] = (raw, seg)
            level_variants[(image, key)] = (raw, seg)
        blocks = sum(1 for k in range(30)
                     if (bp.type[(s - 1) * 30 + k] & 0x1F) != 0)
        per_screen.append((s, entries, len(sv),
                           sum(v[0] for v in sv.values()),
                           sum(v[1] for v in sv.values()), blocks))

    PIN, BOTH = 8192, 15872
    print("VARIANT CENSUS — %s, bgset %s" % (args.level, args.bgset))
    print("  a variant = one (image x context) cel, colours taken from the composited page")
    print("  entries skipped: %s" % skipped)
    print()
    print("  %-3s %8s %9s %10s %10s %8s" %
          ("scr", "entries", "variants", "raw B", "segment B", "blocks"))
    for s, e, v, raw, seg, blocks in per_screen:
        print("  %-3d %8d %9d %10d %10d %8d" % (s, e, v, raw, seg, blocks))

    pop = [p for p in per_screen if p[1] > 0]
    ent = sum(p[1] for p in pop)
    vsum = sum(p[2] for p in pop)
    raws = [p[3] for p in pop]
    segs = [p[4] for p in pop]
    worst = max(pop, key=lambda p: p[4])

    print()
    print("AC2 — DEDUP")
    print("  display-list entries, all screens : %d" % ent)
    print("  variants summed per screen        : %d   (dedup %.2fx within screens)"
          % (vsum, ent / vsum if vsum else 0))
    print("  DISTINCT variants across the LEVEL: %d   (a further %.2fx across screens)"
          % (len(level_variants), vsum / len(level_variants) if level_variants else 0))
    print("  overall %d entries -> %d variants  (%.2fx)"
          % (ent, len(level_variants), ent / len(level_variants)))

    print()
    print("AC3 — THE TWO FIGURES, AND WHICH IS WHICH")
    print("  ★ PER-SCREEN MAXIMUM  = a RESIDENCY requirement (one screen composites at a time)")
    print("      raw     max %6d B   median %6d B   min %6d B" %
          (max(raws), int(statistics.median(raws)), min(raws)))
    print("      segment max %6d B   median %6d B   min %6d B" %
          (max(segs), int(statistics.median(segs)), min(segs)))
    print("      worst screen: %d — %d entries, %d variants, %d blocks placed"
          % (worst[0], worst[1], worst[2], worst[5]))
    lr = sum(v[0] for v in level_variants.values())
    ls = sum(v[1] for v in level_variants.values())
    print("  ★ LEVEL TOTAL         = a SUM (what a never-reload design would hold, or the disk)")
    print("      raw     %6d B     segment %6d B" % (lr, ls))

    print()
    print("AC4 — AGAINST THE PAGES")
    for nm, val, kind in (("per-screen max, segment", max(segs), "residency"),
                          ("per-screen max, raw", max(raws), "residency"),
                          ("level total, segment", ls, "sum"),
                          ("level total, raw", lr, "sum")):
        print("  %-26s %6d B  (%-9s)  vs pinned 8,192: %-16s vs both 15,872: %s"
              % (nm, val, kind,
                 "FITS %d spare" % (PIN - val) if val <= PIN else "OVER by %d" % (val - PIN),
                 "FITS %d spare" % (BOTH - val) if val <= BOTH else "OVER by %d" % (val - BOTH)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
