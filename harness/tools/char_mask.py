#!/usr/bin/env python3
r"""char_mask.py — P5.33: the ORACLE's character transparency model, for the gameplay predictions.

★★★ WHY THIS EXISTS. P5.32's gate (Jay: "the guard is a bit too 'transparent' when the kid passes by
him") found a defect no automated check could see, because every prediction used the SAME model as
the bake: a pixel is transparent iff its 2-bit value is 0 (P3.18 §3B). The oracle does not draw
characters that way:

  DrawNormal [GAMEBG.S:432-437]   lda #mask / sta OPACITY    -- the kid; DRAWGUARD reaches it too
  LayMask    [HIRES.S:945-961]    mask = MASKTAB[image byte], shifted with the image through the
                                  same SHIFT/CARRY tables; screen := (screen AND mask) OR image
  MLayMask   [HIRES.S:1463-1489]  the same, on MIRROR[image byte], bytes read right to left
  MASKTAB    [HRTABLES.S:219-234] per 7-pixel byte: the lit bits AND one either side, CLEARED

So every character carries a one-pixel black border (within each of HIS 7-pixel source bytes -- the
mask is taken from the unshifted image byte, so it travels with the cel, not with the screen) and
gaps of one or two pixels inside him are filled black. He OCCLUDES what is behind him.

★★ THE MODEL COMES FROM THE ORACLE, NOT FROM THE ROUTE. MASKTAB and MIRROR are read LITERALLY out of
HRTABLES.S here and applied byte by byte the way LayMask/MLayMask index them. The bake
(bake_chars.py) computes its border by ARITHMETIC dilation instead; if the two ever disagree on a
byte, the byte-exact checks fail. Nothing here reads the bake, its streams, or cel_blit_prep: the
composite below is pixel by pixel, not a segment replay.

★ WHAT IS NOT MODELLED: the Apple's colour for the pixels the mask clears is black; the screen's
palette bit (MASKTAB returns bit 7 set, so the AND keeps the screen byte's hibit) changes how the
Apple renders the BACKGROUND beside him, which the port's background does not share. Every one of
the 53,577 gameplay + guard cel bytes has bit 7 set (checked at P5.33), so MASKTAB-$80,x and
MIRROR-$80,x never index outside their tables.

The port's pixel grid is the Apple's, 1:1: sprite_convert maps Apple column byte*7+bit to port
pixel column `col` [convert_sprite_to_coco3, width_pixels = 7*apple_w], and --mirror reverses that
7*apple_w-pixel list -- MLAY's c <-> 7*aw-1-c. So one Apple pixel of border is one port pixel.
"""
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "sprite_tool"))
import sprite_convert as SC                                 # noqa: E402

HRTABLES = ROOT / "oracle/source/01 POP Source/Source/HRTABLES.S"
STRIDE = 80
_TABS = {}


def _table(name):
    """The 128 bytes of `name` in HRTABLES.S, from its HEX lines -- the oracle's own data."""
    if name not in _TABS:
        out, on = [], False
        for line in HRTABLES.read_text(errors="replace").splitlines():
            s = line.split(";")[0].rstrip()
            m = re.match(r"^(\w+)\s+(hex|HEX)\s+(.*)$", s)
            if m:
                on = m.group(1) == name
                body = m.group(3)
            else:
                m2 = re.match(r"^\s+(hex|HEX)\s+(.*)$", s)
                if not (on and m2):
                    if s and not s[0].isspace() and not s.startswith("*"):
                        on = False
                    continue
                body = m2.group(2)
            if on:
                out += [int(t, 16) for t in re.findall(r"[0-9A-Fa-f]{2}", body.replace(",", ""))]
        if len(out) != 128:
            raise SystemExit("char_mask: %s has %d bytes in HRTABLES.S, not 128" % (name, len(out)))
        _TABS[name] = out
    return _TABS[name]


def masktab(b):
    return _table("MASKTAB")[b & 0x7F]


def mirror(b):
    return _table("MIRROR")[b & 0x7F]


def cleared(table, idx, mirrored):
    """Per VISUAL row (top first, sprite_convert's order), the set of Apple pixel columns
    0..7*aw-1 that MLayMask / LayMask clear for this cel -- the oracle's route, byte by byte."""
    cel = SC.get_cel(table, idx)
    aw, h, data = cel["w"], cel["h"], cel["data"]
    rows = []
    for vr in range(h):
        d = h - 1 - vr                                   # cel rows are stored bottom-up
        src = data[d * aw:(d + 1) * aw]
        cols = set()
        for p in range(aw):
            b = mirror(src[aw - 1 - p]) if mirrored else src[p]
            m = masktab(b)
            for i in range(7):
                if not (m >> i) & 1:
                    cols.add(7 * p + i)
        rows.append(cols)
    return rows


def compose(fb, pixels, clr, top, px0):
    """Lay one character into a 2-bpp framebuffer (bytearray, STRIDE bytes/row) the oracle's
    way: a pixel with a colour takes it; else a pixel the mask cleared becomes BLACK; else the
    screen shows through. `pixels` = visual rows of 2-bit values (sprite_convert's), `clr` =
    cleared() for the same cel and facing, registered at the same left pixel `px0`.
    Returns the set of framebuffer byte offsets this character made opaque."""
    opaque = set()
    for r, row in enumerate(pixels):
        y = top + r
        width = max(len(row), (max(clr[r]) + 1) if clr[r] else 0)
        for c in range(width):
            v = row[c] if c < len(row) else 0
            if v == 0 and c not in clr[r]:
                continue
            x = px0 + c
            o = y * STRIDE + x // 4
            sh = 6 - 2 * (x % 4)
            fb[o] = (fb[o] & ~(3 << sh) & 0xFF) | ((v & 3) << sh)
            opaque.add(o)
    return opaque


def dilation_agrees():
    """MASKTAB against the arithmetic the bake uses -- (b | b<<1 | b>>1) cleared, within 7 bits.
    Returns the list of bytes where they DISAGREE (empty = the bake's route is the oracle's table)."""
    bad = []
    for b in range(128):
        dil = (b | (b << 1) | (b >> 1)) & 0x7F
        if (masktab(b) & 0x7F) != (~dil & 0x7F):
            bad.append(b)
    return bad


if __name__ == "__main__":
    print("char_mask: MASKTAB[$01]=$%02X [$02]=$%02X (dispatch: $FC, $F8)" % (masktab(1), masktab(2)))
    bad = dilation_agrees()
    print("char_mask: MASKTAB vs arithmetic dilation, 128 bytes: %s" % ("IDENTICAL" if not bad else "DIFFER at %r" % bad))
    rev = [b for b in range(128) if (mirror(b) & 0x7F) != int("{:07b}".format(b)[::-1], 2)]
    print("char_mask: MIRROR vs a 7-bit reversal, 128 bytes: %s" % ("IDENTICAL" if not rev else "DIFFER at %r" % rev))
