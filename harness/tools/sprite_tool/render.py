#!/usr/bin/env python3
"""
render.py — aspect-correct, nearest-neighbor render of an assembled frame to a PIL image
(Milestone 3). Headlessly testable: returns a PIL.Image; the Tkinter app wraps it.

Each sprite pixel -> a NON-SQUARE integer cell (CELL_W*z x CELL_H*z), nearest-neighbor.
Palette = the RGB gate set (crawl driver palette_sets set 1: black/orange $26/blue $19/white $3F):
  0 -> TRANS (flat mid-gray, distinct from opaque black — the shadow-task view)
  1 -> orange (255,85,0)   2 -> blue (0,170,255)   3 -> white (255,255,255)
(Opaque-black `f` is the deferred paint-model decision — see the f-refactor plan.)
"""
from pixel_map import CELL_W, CELL_H
try:
    from PIL import Image, ImageDraw
except ImportError:
    Image = None

TRANS_GRAY = (128, 128, 128)
RGB = {0: TRANS_GRAY, 1: (255, 85, 0), 2: (0, 170, 255), 3: (255, 255, 255)}
BG = (40, 40, 40)                 # canvas outside any cel
BOUNDARY = (255, 0, 255)          # cel-boundary overlay

OPAQUE_BLACK = (0, 0, 0)          # index-0 marked opaque (shadow) — solid, distinct from trans gray
CHANGED = (255, 255, 0)           # changed-pixel (New vs Old) highlight

def render_frame(frame, zoom=3, boundaries=True, opacity_by_cel=None, changed_by_cel=None,
                 pixels_by_cel=None):
    """Render each placed cel, later on top. index 1/2/3 = colours; index 0 = TRANS gray,
    unless opacity_by_cel[cel_id][y][x] is True (opaque shadow) -> solid black.
    changed_by_cel[cel_id] = set of (x,y) local pixels to highlight (New vs Old).
    pixels_by_cel[cel_id] overrides the pixel source (used to render the Old/on-open view)."""
    if Image is None:
        raise RuntimeError("Pillow required: pip install pillow")
    # Render at 1:1 (one buffer entry per sprite pixel) then let PIL's C-level NEAREST resize do
    # the zoom expansion. The old code set every zoomed pixel in a Python quadruple loop
    # (cel x pixel x zoom_y x zoom_x) — millions of `px[]=` calls per frame, which was the lag.
    W, H = frame.W, frame.H
    buf = [BG] * (W * H)
    for p in frame.placed:                        # back to front
        opac = (opacity_by_cel or {}).get(p.cel_id)
        pixels = (pixels_by_cel or {}).get(p.cel_id, p.cel.pixels)
        bx, by = p.x - frame.x0, p.y - frame.y0
        for cy in range(p.h_px):
            row = pixels[cy]
            base = (by + cy) * W + bx
            if opac is None:
                for cx in range(p.w_px):
                    buf[base + cx] = RGB[row[cx]]
            else:
                orow = opac[cy]
                for cx in range(p.w_px):
                    val = row[cx]
                    buf[base + cx] = OPAQUE_BLACK if (val == 0 and orow[cx]) else RGB[val]
    img = Image.new("RGB", (W, H))
    img.putdata(buf)
    cw, ch = CELL_W * zoom, CELL_H * zoom
    img = img.resize((W * cw, H * ch), Image.NEAREST)   # C-level zoom, nearest-neighbor
    d = ImageDraw.Draw(img)
    if boundaries:
        for p in frame.placed:
            x0 = (p.x - frame.x0) * cw; y0 = (p.y - frame.y0) * ch
            d.rectangle([x0, y0, x0 + p.w_px * cw - 1, y0 + p.h_px * ch - 1], outline=BOUNDARY)
    # changed-pixel indicator = a yellow OUTLINE, drawn LAST so it's never hidden and never
    # replaces the pixel's real colour (trans stays gray, opaque-black stays solid, etc.)
    for p in frame.placed:
        for (cx, cy) in (changed_by_cel or {}).get(p.cel_id, set()):
            ox = (p.x - frame.x0 + cx) * cw; oy = (p.y - frame.y0 + cy) * ch
            d.rectangle([ox, oy, ox + cw - 1, oy + ch - 1], outline=CHANGED)
    return img
