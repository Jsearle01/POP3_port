#!/usr/bin/env python3
"""
frame_assembly.py — assemble ONE scene-6 frame from the placement table (Milestone 2).

Handles both schemas:
  - animated frame  : an [animation] block's frame -> its parts {cel; col,sub,row}
  - static cel      : a [placement] row -> one part

Sub-byte X is load-bearing: each part's pixel origin = col*4 + sub (4 px/byte), y = row.
Parts are placed on a shared canvas at converted dims (FIXED — the tool never resizes).
Pixel values are the 2bpp read (0=black/trans, 1=orange, 2=blue, 3=white); the trans-vs-
opaque-black (`f`) distinction is the deferred paint-model decision (see the f-refactor plan).
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from celio import Cel
from placement_table import Table

class PlacedCel:
    def __init__(self, cel_id, cel, x, y, cel_dir):
        self.cel_id, self.cel, self.x, self.y, self.cel_dir = cel_id, cel, x, y, cel_dir
        self.w_px, self.h_px = cel.w * 4, cel.h
    def covers(self, px, py):
        return self.x <= px < self.x + self.w_px and self.y <= py < self.y + self.h_px
    def pixel(self, px, py):
        return self.cel.pixels[py - self.y][px - self.x]

class AssembledFrame:
    def __init__(self, placed, label):
        self.placed = placed          # draw order (later = on top)
        self.label = label
        xs0 = min(p.x for p in placed);  ys0 = min(p.y for p in placed)
        xs1 = max(p.x + p.w_px for p in placed);  ys1 = max(p.y + p.h_px for p in placed)
        self.x0, self.y0, self.W, self.H = xs0, ys0, xs1 - xs0, ys1 - ys0

    def owners(self, px, py):
        """Cels whose bbox covers canvas pixel (px,py), in draw order. Edit routes to the
        selected one when >1 (overlap); the tool surfaces the overlap, never guesses."""
        return [p for p in self.placed if p.covers(px, py)]

    def composite(self):
        """Display grid[H][W]: topmost non-transparent (index!=0) pixel, else -1 (background)."""
        grid = [[-1] * self.W for _ in range(self.H)]
        for p in self.placed:                        # back to front
            for cy in range(p.h_px):
                for cx in range(p.w_px):
                    v = p.cel.pixels[cy][cx]
                    if v != 0:                       # index 0 = transparent key (current 2bpp)
                        grid[p.y - self.y0 + cy][p.x - self.x0 + cx] = v
        return grid

def _cel_dir(table, cel_id):
    return os.path.dirname(table.cel_path(cel_id))

def assemble_animation(table, block, frame_index):
    frame = table.anim[block][frame_index]
    placed = []
    for part in frame.parts:
        cel = Cel(table.cel_path(part.cel_id))
        cel_dir = _cel_dir(table, part.cel_id)
        for row in part.rows():                    # one PlacedCel per row (tiled parts draw many)
            placed.append(PlacedCel(part.cel_id, cel, part.x_px, row, cel_dir))
    return AssembledFrame(placed, f"{block}[{frame.fid}]")

def assemble_static(table, placement_id):
    sid, col, sub, row = table.placement[placement_id]
    cel = Cel(table.cel_path(sid))
    return AssembledFrame([PlacedCel(sid, cel, col * 4 + sub, row, _cel_dir(table, sid))], placement_id)

def assemble_cel(cel_dir, cel_id=None):
    """Standalone single cel at origin — author ANY content cel individually (Part A),
    placed or not, at its own converted dims. cel_dir is an absolute content dir."""
    cel = Cel(os.path.join(cel_dir, "converted.s"))
    cid = cel_id or os.path.basename(cel_dir)
    return AssembledFrame([PlacedCel(cid, cel, 0, 0, cel_dir)], cid)
