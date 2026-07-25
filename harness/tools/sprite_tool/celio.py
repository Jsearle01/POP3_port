#!/usr/bin/env python3
"""
celio.py — converted.s cel I/O for the hand-authoring sprite tool (Milestone 1).

WRAPS the existing converted.s format (NOT a new parser):
  - READ  reuses render_cel_sheet.parse_cel's fcb-parsing shape.
  - WRITE  reproduces sprite_convert.write_s_file's exact row format
           ('        fcb     $XX,...  ; row N', 8-space indent, UPPER hex).

Format (from a real cel):
  <comment preamble>            * ...   (verbatim)
  <label>:                      scene6_climb_A3C5:
          fcb     H,W  ; ...     header (H rows, W bytes/row; verbatim)
          fcb     $XX,...  ; row 0      H data rows: W bytes, 4px/byte 2bpp MSB-first
          ...
  <trailing>                    (usually just EOF newline; verbatim)

Model: preamble/header/trailing kept VERBATIM; the H data rows are the editable
pixel grid. write regenerates ONLY the data rows from pixels → a no-edit
load→save is byte-identical iff the pixel round-trip + row format are faithful.
"""
import os, re

# 2bpp, 4 px/byte, MSB-first — the GIME 320x192x4 packing.
def unpack_byte(b):
    return [(b >> 6) & 3, (b >> 4) & 3, (b >> 2) & 3, b & 3]

def pack_pixels(p0, p1, p2, p3):
    return ((p0 & 3) << 6) | ((p1 & 3) << 4) | ((p2 & 3) << 2) | (p3 & 3)

_FCB = re.compile(r'^\s*fcb\s', re.I)

class Cel:
    """One converted.s cel: verbatim preamble/trailing + an editable H x (4W) pixel grid."""
    def __init__(self, path):
        self.path = path
        with open(path, 'r', newline='') as f:
            self.raw = f.read()
        # preserve the file's newline style (converted.s is CRLF on Windows) so regenerated
        # data rows match byte-for-byte
        self._nl = '\r\n' if '\r\n' in self.raw else '\n'
        self._ends_nl = self.raw.endswith(self._nl)
        lines = self.raw.split(self._nl)
        if self._ends_nl:            # split leaves a trailing '' after the final newline
            lines = lines[:-1]
        self.lines = lines

        fcb_idx = [i for i, l in enumerate(lines) if _FCB.search(l)]
        if not fcb_idx:
            raise ValueError(f"{path}: no fcb directive")
        hdr_i = fcb_idx[0]
        hdr_nums = re.findall(r'\d+', lines[hdr_i].split(';')[0])
        self.h, self.w = int(hdr_nums[0]), int(hdr_nums[1])     # rows, bytes/row
        # the H data rows are the fcb lines immediately after the header
        self.data_idx = [i for i in fcb_idx if i > hdr_i][:self.h]
        if len(self.data_idx) != self.h:
            raise ValueError(f"{path}: expected {self.h} data rows, found {len(self.data_idx)}")

        self.preamble = lines[:hdr_i + 1]                       # through the header fcb (verbatim)
        self.trailing = lines[self.data_idx[-1] + 1:]           # after the last data row (verbatim)

        # pixels[r] = list of 4*W indices (0..3); original bytes kept for a fidelity check
        self.pixels = []
        self.orig_bytes = []
        for i in self.data_idx:
            payload = lines[i].split(';', 1)[0]
            # require the '$' prefix so 'fc' inside the 'fcb' directive isn't read as a byte
            vals = [int(v, 16) for v in re.findall(r'\$([0-9A-Fa-f]{2})', payload)]
            if len(vals) != self.w:
                raise ValueError(f"{path} row: expected {self.w} bytes, got {len(vals)}")
            self.orig_bytes.append(vals)
            px = []
            for b in vals:
                px.extend(unpack_byte(b))
            self.pixels.append(px)

    def row_bytes(self, r):
        """Repack pixel row r -> W bytes."""
        px = self.pixels[r]
        return [pack_pixels(px[c*4], px[c*4+1], px[c*4+2], px[c*4+3]) for c in range(self.w)]

    def _data_line(self, r):
        hex_vals = ','.join(f'${b:02X}' for b in self.row_bytes(r))
        return f"        fcb     {hex_vals}  ; row {r}"

    def to_text(self):
        out = list(self.preamble)
        out += [self._data_line(r) for r in range(self.h)]
        out += self.trailing
        text = self._nl.join(out)
        if self._ends_nl:
            text += self._nl
        return text

    def write(self, path=None):
        with open(path or self.path, 'w', newline='') as f:
            f.write(self.to_text())


def roundtrip_ok(path):
    """Load->regenerate->compare. Returns (ok, detail). ok == byte-identical no-edit round-trip."""
    with open(path, 'r', newline='') as f:
        orig = f.read()
    cel = Cel(path)
    regen = cel.to_text()
    if regen == orig:
        return True, f"{cel.h}x{cel.w*4}px byte-identical"
    # locate first divergence for the report
    for i, (a, b) in enumerate(zip(orig, regen)):
        if a != b:
            ctx = orig[max(0, i-20):i+20].replace('\n', '\\n')
            return False, f"diverge at byte {i}: ...{ctx}..."
    return False, f"length differs: orig={len(orig)} regen={len(regen)}"
