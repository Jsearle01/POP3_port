#!/usr/bin/env python3
"""
opacity.py — the opacity layer + descriptor derive/verify (Milestones 4b).

Opacity is meaningful ONLY for index-0 (black) pixels: is this black pixel OPAQUE
(shadow, stored solid) or KEYED (transparent)? Non-0 pixels (1/2/3) are always drawn.
No pixel-format change — opacity lives in a DERIVED descriptor matching the HAL:

  mixed  (HAL_gfx_blit_sprite_mixed): rectangles fcb start_col,width,start_row,num_rows,opaque
         — byte-column x row-band aligned. Represents ANY byte-uniform opacity.
  masked (HAL_gfx_blit_sprite_masked): one mask byte per column (width bytes), reused each
         row; bit-pair 11=opaque / 00=keyed. Sub-byte WITHIN a byte, but COLUMN-UNIFORM down rows.

Derive is by GEOMETRY, NO DEFAULT:
  - all opaque/trans boundaries on byte edges (every byte's index-0 marks uniform)  -> mixed
  - some byte has mixed marks AND the sub-byte pattern is uniform down all rows      -> masked
  - otherwise (row-varying sub-byte)                                                  -> CannotEncode (STOP)
A cel with no opaque marks -> ('none', None): keyed everywhere = current behavior, no sidecar.
"""

class CannotEncode(Exception):
    pass

def blank_opacity(cel):
    """Default: every index-0 pixel KEYED (False) — matches the current transparent blit."""
    return [[False] * (cel.w * 4) for _ in range(cel.h)]

def _byte_marks(cel, opacity, r, c):
    """The opacity marks of the index-0 pixels in byte (row r, byte-col c). Returns
    set of bools over index-0 pixels only (non-0 pixels don't constrain opacity)."""
    marks = set()
    for k in range(4):
        px = c * 4 + k
        if cel.pixels[r][px] == 0:
            marks.add(opacity[r][px])
    return marks

def has_opaque(cel, opacity):
    return any(cel.pixels[r][c] == 0 and opacity[r][c]
              for r in range(cel.h) for c in range(cel.w * 4))

def derive(cel, opacity):
    """Return ('none'|'mixed'|'masked', payload). Raise CannotEncode if unrepresentable."""
    if not has_opaque(cel, opacity):
        return 'none', None

    # per-byte opacity: True(opaque)/False(keyed)/None(no index-0 pixels)/'sub'(mixed within byte)
    byte_op = [[None] * cel.w for _ in range(cel.h)]
    any_sub = False
    for r in range(cel.h):
        for c in range(cel.w):
            m = _byte_marks(cel, opacity, r, c)
            if not m:
                byte_op[r][c] = None
            elif m == {True}:
                byte_op[r][c] = True
            elif m == {False}:
                byte_op[r][c] = False
            else:
                byte_op[r][c] = 'sub'; any_sub = True

    if not any_sub:
        return 'mixed', _mixed_rects(cel, byte_op)

    # sub-byte present -> try masked (per-column, uniform down rows); else the universal
    # per-pixel STENCIL (a full 2D mask). With stencil there is no unrepresentable marking,
    # so cheapest-that-fits is chosen: mixed > masked > stencil.
    try:
        return 'masked', _masked_mask(cel, opacity)   # raises CannotEncode if row-varying
    except CannotEncode:
        return 'stencil', _stencil_mask(cel, opacity)

def _mixed_rects(cel, byte_op):
    """Decompose byte-uniform opacity into rectangles that COVER THE WHOLE SPRITE — the mixed
    blit draws ONLY the regions it's given, so every byte must be in one or its colours are not
    drawn (the 'partially transparent in white/orange' bug). A byte is opaque(1) iff it has an
    OPAQUE index-0 mark; every other byte (keyed index-0, or colour-only/None) is transparent(0)
    — colours are drawn either way; the flag only decides whether index-0 is solid or keyed."""
    def op(c_v):
        return 1 if c_v is True else 0          # True->opaque; False/None->transparent
    rects = []   # (start_col, width, start_row, num_rows, opaque)
    for r in range(cel.h):
        c = 0
        while c < cel.w:
            o = op(byte_op[r][c])
            c0 = c
            while c < cel.w and op(byte_op[r][c]) == o:
                c += 1
            rects.append((c0, c - c0, r, 1, o))     # every byte covered
    return _merge_row_bands(rects)

def _merge_row_bands(rects):
    """Merge vertically-adjacent identical (col,width,opaque) 1-row rects into row-bands."""
    rects = sorted(rects, key=lambda t: (t[0], t[1], t[4], t[2]))
    out = []
    for sc, w, sr, nr, op in rects:
        if out and out[-1][0] == sc and out[-1][1] == w and out[-1][4] == op \
                and out[-1][2] + out[-1][3] == sr:
            p = out[-1]; out[-1] = (p[0], p[1], p[2], p[3] + nr, p[4])
        else:
            out.append((sc, w, sr, nr, op))
    return out

def _masked_mask(cel, opacity):
    """width mask bytes (bit-pair 11=opaque, 00=keyed per pixel), uniform down rows.
    Non-index-0 pixels are 'don't care' -> forced to 11 (opaque) so source (the colour)
    passes through unchanged (the OR contributes the colour; dest cleared where 11)."""
    W = cel.w
    mask = [None] * W
    for c in range(W):
        col_mask = None
        for r in range(cel.h):
            byte_bits = 0
            for k in range(4):
                px = c * 4 + k
                if cel.pixels[r][px] != 0:
                    bits = 0b11                       # colour pixel: always take source
                else:
                    bits = 0b11 if opacity[r][px] else 0b00
                byte_bits |= bits << (2 * (3 - k))    # pixel 0 = MSB pair
            if col_mask is None:
                col_mask = byte_bits
            elif col_mask != byte_bits:
                raise CannotEncode(
                    f"col {c}: sub-byte opacity varies by row (row {r}) — not encodable "
                    f"as mixed (sub-byte) or masked (column-uniform); STOP")
        mask[c] = col_mask if col_mask is not None else 0
    return mask


def _stencil_mask(cel, opacity):
    """Full 2D mask (h rows x w bytes) for HAL_gfx_blit_stencil_punch: bit-pair 11 where a pixel
    is index-0 AND opaque (force black), 00 elsewhere (colour pixels + keyed index-0 untouched).
    Cel-local (sprite-aligned). NOTE: stencil_punch is BYTE-ALIGNED — a cel PLACED at a sub-byte
    X needs build-side mask shifting; the tool authors/verifies the mask cel-locally (placement-
    independent), and the build applies it — gen_climb_opacity.py pre-shifts by the placement sub
    and the climb draw path punches it (implemented for the climb path; other paths as authored)."""
    mask = []
    for r in range(cel.h):
        row = []
        for c in range(cel.w):
            b = 0
            for k in range(4):
                px = c * 4 + k
                if cel.pixels[r][px] == 0 and opacity[r][px]:
                    b |= 0b11 << (2 * (3 - k))
            row.append(b)
        mask.append(row)
    return mask

# ---- VERIFY: re-render the cel THROUGH the derived descriptor, compare to the marks ----

def _truth(cel, opacity):
    """Ground truth: for every index-0 pixel, True=opaque(black solid) False=keyed."""
    return {(r, c): opacity[r][c]
            for r in range(cel.h) for c in range(cel.w * 4) if cel.pixels[r][c] == 0}

def _apply_mixed(cel, rects):
    """Simulate the mixed blit's opacity: each rect sets its index-0 pixels opaque/keyed."""
    res = {(r, c): False for r in range(cel.h) for c in range(cel.w * 4) if cel.pixels[r][c] == 0}
    for sc, w, sr, nr, op in rects:
        for r in range(sr, sr + nr):
            for c in range(sc * 4, (sc + w) * 4):
                if (r, c) in res:
                    res[(r, c)] = bool(op)
    return res

def _apply_masked(cel, mask):
    res = {}
    for r in range(cel.h):
        for c in range(cel.w * 4):
            if cel.pixels[r][c] == 0:
                byte = mask[c // 4]
                bits = (byte >> (2 * (3 - (c % 4)))) & 0b11
                res[(r, c)] = (bits == 0b11)
    return res

def _apply_stencil(cel, mask):
    res = {}
    for r in range(cel.h):
        for c in range(cel.w * 4):
            if cel.pixels[r][c] == 0:
                byte = mask[r][c // 4]
                bits = (byte >> (2 * (3 - (c % 4)))) & 0b11
                res[(r, c)] = (bits == 0b11)
    return res

def decode_to_opacity(cel, kind, payload):
    """Inverse of derive: a saved descriptor -> the per-pixel opacity EDIT LAYER (index-0 pixels
    marked opaque/keyed). Used to reload an authored cel's shadow on open so it can be refined."""
    op = blank_opacity(cel)
    if kind in (None, 'none'):
        return op
    marks = {'mixed': _apply_mixed, 'masked': _apply_masked, 'stencil': _apply_stencil}[kind](cel, payload)
    for (r, c), opaque in marks.items():
        op[r][c] = opaque
    return op

def reload_is_lossless(cel, kind, payload):
    """Gate: decode the descriptor -> marks, re-derive -> must reproduce the SAME descriptor
    byte-for-byte (no lossy reload). Returns (ok, decoded_opacity, detail)."""
    op = decode_to_opacity(cel, kind, payload)
    rk, rp = derive(cel, op)
    if (rk, rp) == (kind, payload):
        return True, op, f"{kind} reload lossless"
    return False, op, f"reload NOT lossless: sidecar {kind} -> re-derives {rk} (differs)"

def verify(cel, opacity, kind, payload):
    """Re-render through the descriptor; return (ok, detail). ok == reproduces marks exactly."""
    truth = _truth(cel, opacity)
    if kind == 'none':
        got = {k: False for k in truth}
    elif kind == 'mixed':
        got = _apply_mixed(cel, payload)
    elif kind == 'masked':
        got = _apply_masked(cel, payload)
    elif kind == 'stencil':
        got = _apply_stencil(cel, payload)
    else:
        return False, f"unknown kind {kind}"
    if got == truth:
        return True, f"{kind}: {len(truth)} index-0 pixels reproduced exactly"
    diff = [k for k in truth if truth[k] != got.get(k)]
    return False, f"{kind}: {len(diff)} pixel(s) differ e.g. {diff[:3]}"
