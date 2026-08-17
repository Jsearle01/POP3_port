#!/usr/bin/env python3
"""
pixel_map.py — CoCo3 pixel aspect + exact screen<->sprite pixel mapping (Milestone 3).

Aspect derivation (GIME 320x192 graphics mode on a 4:3 display):
  display width:height = 4:3; the 320x192 pixel grid fills it.
  pixel_w = display_w/320, pixel_h = display_h/192
  pixel_aspect = pixel_w/pixel_h = (4/3)*(192/320) = 768/960 = 0.8  -> pixels NARROWER than tall
  0.8 = 4/5, so the integer non-square base cell is 4 (wide) x 5 (tall).

Rendering: each sprite pixel is a NON-SQUARE INTEGER cell (4z x 5z at integer zoom z),
nearest-neighbor, never fractional. Mapping is exact:
  screen (sx,sy) -> sprite (floor(sx/(CELL_W*z)), floor(sy/(CELL_H*z)))
  sprite (px,py) -> screen rect [px*CELL_W*z, (px+1)*CELL_W*z) x [py*CELL_H*z, (py+1)*CELL_H*z)
"""
from math import gcd

# derived, not assumed:
PIXEL_ASPECT_NUM = 4 * 192   # 768
PIXEL_ASPECT_DEN = 3 * 320   # 960
_g = gcd(PIXEL_ASPECT_NUM, PIXEL_ASPECT_DEN)
ASPECT_W, ASPECT_H = PIXEL_ASPECT_NUM // _g, PIXEL_ASPECT_DEN // _g   # 4, 5
PIXEL_ASPECT = ASPECT_W / ASPECT_H                                   # 0.8
CELL_W, CELL_H = ASPECT_W, ASPECT_H                                  # base non-square cell 4x5

def screen_to_sprite(screen_x, screen_y, zoom):
    return screen_x // (CELL_W * zoom), screen_y // (CELL_H * zoom)

def sprite_to_screen_rect(px, py, zoom):
    x0 = px * CELL_W * zoom; y0 = py * CELL_H * zoom
    return x0, y0, CELL_W * zoom, CELL_H * zoom
