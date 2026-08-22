#!/usr/bin/env python3
r"""bake_screen.py - P5.5. Bake one blueprint screen into a PINNED PAGE the port can blit.

★★★ THE MODEL, AND IT DEPARTS FROM THE ONE THE CENSUS COUNTED. P5.4 counted a variant as the
composited page's pixels over the cel's bounding box with the cel's own transparent pixels left
at index 0 -- shape from the cel, colour from the page. That model is not BLITTABLE without a
transparency mechanism (a mask byte per data byte, or the segment format, which is a two-format
ruling nobody has made), and adding one costs more than it saves.

THE IMPLEMENTABLE MODEL IS SIMPLER AND IS PROVEN EXACT HERE:

  EVERY ENTRY IS AN OPAQUE RECTANGLE OF THE FINAL PAGE'S PIXELS.

and the reason it works is worth stating, because it looks too good: every variant's colours are
taken from the FINISHED composite, so a pixel's value already accounts for everything any entry
draws there, in any order. Writing that value is therefore correct whoever writes it and whenever.
Three consequences fall out at once:

  * TRANSPARENCY DISAPPEARS. An `ora` entry's "transparent" pixels hold the finished value, which
    is exactly what a transparent write would have left behind.
  * ORDER DISAPPEARS. Overlapping rectangles write identical bytes.
  * ★ THE AND/MASK ENTRIES ARE HANDLED BY CONSTRUCTION, not omitted. A mask CLEARS pixels an
    earlier entry set; the finished page already reflects that, so every rectangle covering a
    masked pixel carries the cleared value. Screen 1's four masks need no code at all.

`--verify` replays the emitted page in Python and compares it byte-for-byte against
hgr_screen_convert's output for the same screen. It is EXACT or the bake fails.

PAGE FORMAT (at $C000, one 8,192 B GIME block; $C000-$DFFF is all reachable):
    +0   fdb  magic
    +2   fcb  n_variants
    +3   fcb  n_entries
    +4   variant table, 4 B each:  fdb data_addr / fcb width_bytes / fcb height_rows
    ...  display list, 3 B each:   fcb variant_id / fcb x_byte / fcb y_top
    ...  variant data, width*height raw 2 bpp bytes, top row first
"""
import argparse
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "harness/tools"))

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

import bg_compose as B                                                  # noqa: E402
import variant_census as V                                              # noqa: E402
from hgr_screen_convert import deinterleave                             # noqa: E402
from sprite_convert import convert_sprite_to_coco3                      # noqa: E402

MAGIC = 0x7B1E              # "tile" page; distinct from the cutscene's $C35A
FB_STRIDE, FB_ROWS = 80, 192
LEFT_MARGIN = 5             # bytes; the 280->320 centring hgr_screen_convert applies
PAGE_CAP = 8192


def reference_fb(page_bytes):
    """The screen composited in HGR and converted once — what the port must reproduce."""
    rows = deinterleave(page_bytes)
    flat = b"".join(rows)
    bm, wb = convert_sprite_to_coco3(list(flat), FB_ROWS, 40, start_col=0)
    fb = bytearray(FB_STRIDE * FB_ROWS)
    for y in range(FB_ROWS):
        fb[y * FB_STRIDE + LEFT_MARGIN:y * FB_STRIDE + LEFT_MARGIN + wb] = bm[y * wb:(y + 1) * wb]
    return bytes(fb)


def bake(level, screen, bgset):
    bp = B.Blueprint((B.LEVELS / level).read_bytes())
    bg1 = B.read_table(B.IMAGES / ("IMG.BGTAB1.%s" % bgset))
    bg2 = B.read_table(B.IMAGES / ("IMG.BGTAB2.%s" % bgset))
    tabs = (bg1, bg2)
    r = B.Renderer(bp, bg1, bg2, level=int(level.replace("LEVEL", "")),
                   bgset1=0 if bgset == "DUN" else 1)
    r.sure(screen)
    hgr = bytes(r.paint().b)
    pagepx = V.page_pixels(hgr)
    ref = reference_fb(hgr)

    variants, order = {}, []
    clipped = 0
    for image, xco, yco, op in r.bg + r.fg:
        t = tabs[1] if image & 0x80 else tabs[0]
        i = (image & 0x7F) - 1
        if not (0 <= i < len(t)) or t[i] is None:
            continue
        w, h, _ = t[i]
        px0 = xco * 7
        phase = px0 % 4
        wid = (w * 7 + phase + 3) // 4
        top = yco - h + 1
        y0, y1 = max(0, top), min(FB_ROWS, top + h)
        if y1 <= y0:
            clipped += 1
            continue
        if y0 != top or y1 != top + h:
            clipped += 1
        xb = LEFT_MARGIN + (px0 - phase) // 4
        if xb < 0 or xb + wid > FB_STRIDE:
            raise SystemExit("entry image $%02X at xco %d runs off the framebuffer "
                             "(x %d + %d > %d)" % (image, xco, xb, wid, FB_STRIDE))
        base = px0 - phase
        rows = []
        for y in range(y0, y1):
            px = [pagepx[y][base + k] if 0 <= base + k < 280 else 0 for k in range(wid * 4)]
            rows.append(bytes(((px[c * 4] & 3) << 6) | ((px[c * 4 + 1] & 3) << 4)
                              | ((px[c * 4 + 2] & 3) << 2) | (px[c * 4 + 3] & 3)
                              for c in range(wid)))
        blob = b"".join(rows)
        key = (blob, wid)
        if key not in variants:
            variants[key] = len(variants)
        order.append((variants[key], xb, y0, wid, y1 - y0))
    return ref, variants, order, clipped


def replay(variants, order):
    data = {v: k[0] for k, v in variants.items()}
    fb = bytearray(FB_STRIDE * FB_ROWS)
    for vid, xb, y0, wid, hh in order:
        d = data[vid]
        for rr in range(hh):
            o = (y0 + rr) * FB_STRIDE + xb
            fb[o:o + wid] = d[rr * wid:(rr + 1) * wid]
    return bytes(fb)


def emit(path, variants, order, level, screen):
    inv = {v: k for k, v in variants.items()}
    L = ["* %s - GENERATED by harness/tools/bake_screen.py. Do not edit." % path,
         "* %s screen %d: %d variants, %d display-list entries." % (level, screen,
                                                                    len(variants), len(order)),
         "* Page format is documented in the tool; magic $%04X." % MAGIC,
         "                ifdef   OBJTARGET",
         "                section prog",
         "                export  tile_page",
         "                endc",
         "tile_page",
         "                fdb     $%04X" % MAGIC,
         "                fcb     %d                      ; variants" % len(variants),
         "                fcb     %d                      ; display-list entries" % len(order),
         "* --- variant table: data address, width in bytes, height in rows ---"]
    for v in range(len(variants)):
        blob, wid = inv[v]
        L.append("                fdb     tv_%02d" % v)
        L.append("                fcb     %d,%d" % (wid, len(blob) // wid))
    L.append("* --- display list: variant id, x byte, y top ---")
    for vid, xb, y0, wid, hh in order:
        L.append("                fcb     %d,%d,%d" % (vid, xb, y0))
    L.append("* --- variant data, raw 2 bpp, top row first ---")
    for v in range(len(variants)):
        blob, wid = inv[v]
        L.append("tv_%02d           equ     *                       ; %dx%d = %d B"
                 % (v, wid, len(blob) // wid, len(blob)))
        for i in range(0, len(blob), 12):
            L.append("                fcb     " + ",".join("$%02X" % b for b in blob[i:i + 12]))
    L.append("                end")
    pathlib.Path(path).write_text("\n".join(L) + "\n", encoding="ascii")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--level", default="LEVEL0")
    ap.add_argument("--screen", type=int, default=1)
    ap.add_argument("--bgset", default="DUN")
    ap.add_argument("--out", default=None)
    ap.add_argument("--out-ref", default=None, help="write the reference framebuffer here")
    ap.add_argument("--census", action="store_true", help="all 24 screens, sizes only")
    args = ap.parse_args()

    if args.census:
        print("BAKE CENSUS (implementable model) — %s, bgset %s" % (args.level, args.bgset))
        print("  %-4s %8s %9s %9s %9s %8s" %
              ("scr", "entries", "variants", "data B", "page B", "of 8192"))
        worst = (0, 0)
        for s in range(1, 25):
            ref, variants, order, _ = bake(args.level, s, args.bgset)
            if not order:
                continue
            data = sum(len(k[0]) for k in variants)
            page = 4 + 4 * len(variants) + 3 * len(order) + data
            if page > worst[0]:
                worst = (page, s)
            print("  %-4d %8d %9d %9d %9d %8s" %
                  (s, len(order), len(variants), data, page,
                   "FITS" if page <= PAGE_CAP else "OVER"))
        print("  ★ worst screen %d at %d B of %d — %s"
              % (worst[1], worst[0], PAGE_CAP,
                 "FITS with %d spare" % (PAGE_CAP - worst[0]) if worst[0] <= PAGE_CAP
                 else "OVER by %d" % (worst[0] - PAGE_CAP)))
        return 0

    ref, variants, order, clipped = bake(args.level, args.screen, args.bgset)
    data = sum(len(k[0]) for k in variants)
    page = 4 + 4 * len(variants) + 3 * len(order) + data
    print("BAKE — %s screen %d, bgset %s" % (args.level, args.screen, args.bgset))
    print("  header (magic + two counts)   %6d B" % 4)
    print("  variant table  %3d x 4        %6d B" % (len(variants), 4 * len(variants)))
    print("  display list   %3d x 3        %6d B" % (len(order), 3 * len(order)))
    print("  variant data                  %6d B" % data)
    print("  ------------------------------------")
    print("  page total                    %6d B of %d   %s"
          % (page, PAGE_CAP,
             "FITS, %d spare" % (PAGE_CAP - page) if page <= PAGE_CAP
             else "OVER by %d" % (page - PAGE_CAP)))
    if page > PAGE_CAP:
        return 1
    print("  entries clipped at a screen edge: %d" % clipped)

    got = replay(variants, order)
    same = sum(1 for a, b in zip(got, ref) if a == b)
    print()
    print("  VERIFY — replay vs hgr_screen_convert's framebuffer for the same screen:")
    print("    %d/%d identical, %d differ  -> %s"
          % (same, len(ref), len(ref) - same, "EXACT" if same == len(ref) else "MISMATCH"))
    if same != len(ref):
        return 1
    if args.out:
        emit(args.out, variants, order, args.level, args.screen)
        print("  -> %s" % args.out)
    if args.out_ref:
        pathlib.Path(args.out_ref).write_bytes(ref)
        print("  -> %s (the reference framebuffer)" % args.out_ref)
    return 0


if __name__ == "__main__":
    sys.exit(main())
