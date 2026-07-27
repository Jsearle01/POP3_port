#!/usr/bin/env python3
"""dhr_convert.py — Apple II DOUBLE hi-res -> CoCo3 320x192x16 framebuffer.

This is a NEW path, not an extension of sprite_convert.py. That tool handles SINGLE
hi-res (280x192, 4 colours, 7 pixels/byte, one bank). Double hi-res is a different
machine format in every respect: two memory banks, 4 bits per colour pixel, 140
colour pixels per row, and a 16-entry palette.
[ref: reports/*-p3-1-first-intro-screen.md — the intro is DOUBLE hi-res, traced]

INPUT: the two 8 KB banks of DHR page 1 ($2000-$3FFF in MAIN and AUX), dumped from
the running oracle rather than unpacked from POP's crunch format. CLAUDE.md §2 ranks
the execution trace above source, and it also means the 883-line UNPACK.S decompressor
never has to be ported.

--------------------------------------------------------------------------------
THE VIRTUAL-RESOLUTION CONTRACT (Jay, governing — applies to EVERY screen)
--------------------------------------------------------------------------------
  * the game is DESIGNED in a 280x192 logical space (Apple single-hires width)
  * double-hires content is 140 colour pixels wide and maps 140 -> 280 at its
    natural 2x relationship, so it lands in the SAME 280 virtual space
  * 280 -> 320 hardware is CENTERED: +20 px on the left, 20 px margin each side
  * purely HORIZONTAL — 192 rows map 1:1, only width is virtualised

The arithmetic lands exactly, which is worth stating because it is why this is
faithful by construction rather than by approximation:

    DHR colour pixel i (0..139)
      -> virtual x = 2i, 2i+1                  (the natural 2x)
      -> physical x = 20+2i, 21+2i             (the +20 centring)
      -> framebuffer byte (20+2i)/2 = 10+i     (16-colour mode packs 2 px/byte)

So ONE DHR colour pixel is exactly ONE framebuffer byte, both nibbles set to the
same index. No scaling artefacts, no rounding, no dropped columns. Row layout:
    bytes   0.. 9   left border   (10 bytes = 20 px)
    bytes  10..149  the 140 DHR pixels, one byte each
    bytes 150..159  right border  (10 bytes = 20 px)

--------------------------------------------------------------------------------
DHR MEMORY LAYOUT (the part that is easy to get wrong)
--------------------------------------------------------------------------------
Row base address uses the standard Apple hi-res interleave, NOT a linear stride:
    base = (y & 7) * 0x400  +  ((y >> 3) & 7) * 0x80  +  (y >> 6) * 0x28
Each row is 40 bytes from AUX and 40 from MAIN, interleaved **AUX FIRST**:
    aux[0], main[0], aux[1], main[1], ...
Each byte contributes its low 7 bits (bit 7 is the unused/palette-select bit),
emitted LSB-first — bit 0 is the LEFTMOST pixel on screen. 80 bytes x 7 bits = 560
mono dots; consecutive groups of 4 dots form one of 16 colours = 140 colour pixels.

ASSUMPTIONS THAT JAY'S EYE ADJUDICATES, stated so they are checkable:
  * the aux-before-main interleave order
  * the LSB-first bit order within each byte
  * the aux-before-main interleave order and the LSB-first bit order are CONFIRMED
    by Jay's "content is good" verdict on the first render -- geometry was correct
    on the first attempt
  * the nibble->colour table was WRONG on the first attempt and is now MEASURED from
    the oracle rather than assumed (see the table's own note)
"""
import argparse
import pathlib
import sys

WIDTH_DHR = 140          # colour pixels per row
ROWS = 192
FB_STRIDE = 160          # CoCo3 320x192x16: 2 px/byte
LEFT_MARGIN_BYTES = 10   # 20 px / 2 px-per-byte  -> the 280->320 centring

# Apple II double hi-res 16-colour palette — DETERMINED BY CONTROLLED EXPERIMENT
# on the real hardware model, not assumed and not correlated.
#
# THE EXPERIMENT (P3.2). For each 4-bit value 0..15, a full 560-dot row was
# synthesised whose every 4-dot group carries that value, packed 7 bits per byte and
# split across the banks, then written into the running oracle's DHR page and the
# RENDERED frame sampled. Every band came back perfectly uniform at all sample
# points, which proves three things at once:
#   * the bit order within a byte is LSB-FIRST (bit 0 = leftmost dot)
#   * the group order is LSB-FIRST (first dot = bit 0 of the colour index)
#   * the interleave is AUX on even columns, MAIN on odd
# A wrong assumption in any of those would have produced mixed or wrong bands.
# The interleave independently matches the game's own PutScrByte:
#     txa / lsr / tay / bcs NoAuxSet / sta RAMWRTaux    (even column -> AUX)
#
# WHY THIS REPLACED A MEASURED TABLE. An earlier pass correlated decoded indices
# against the rendered splash and got 11 of 16 at 100%, filling the rest from the
# complement rule (i + (15-i) = white). That was very nearly right -- but grey 1 came
# out as (127,127,127) where the truth is (128,128,128), and those straddle a CoCo3
# quantisation boundary: 127 -> level 1 ($07, dark grey), 128 -> level 2 ($38, mid
# grey). Close enough to look plausible in a table and clearly wrong on screen.
# Correlation gets you near; a controlled experiment gets you exact.
DHR_RGB = [
    (0,   0,   0),      #  0 black
    (64,  28,  247),    #  1 dark blue
    (0,   116, 64),     #  2 dark green
    (25,  144, 255),    #  3 medium blue
    (64,  99,  0),      #  4 brown
    (128, 128, 128),    #  5 grey 1
    (25,  215, 0),      #  6 green
    (88,  244, 191),    #  7 aqua
    (167, 11,  64),     #  8 red
    (230, 40,  255),    #  9 purple
    (128, 128, 128),    # 10 grey 2
    (191, 156, 255),    # 11 light blue
    (230, 111, 0),      # 12 orange
    (255, 139, 191),    # 13 pink
    (191, 227, 8),      # 14 yellow
    (255, 255, 255),    # 15 white
]


# HAND-TUNED CoCo3 PALETTE OVERRIDES — Jay's eye over the arithmetic.
#
# The CoCo3 has 2 bits per channel: 4 levels, 64 colours. Nearest-neighbour
# quantisation of a 24-bit Apple colour is mathematically correct and can still be
# perceptually wrong, because "nearest in RGB" is not "looks like the same colour".
#
# index 14, Apple yellow (191, 227, 8) -> $30, chosen by Jay's eye against the oracle:
#   nearest-neighbour picks R=2 (191 sits 21 from level 2's 170, 64 from level 3's
#   255) giving $32 = (170,255,0). With green already at maximum, red one step short
#   reads as LIME, not yellow -- "the lime-green color should be more yellowish".
#   Forcing R to level 3 gives $36 = (255,255,0), a true yellow, which read as TOO
#   yellow. There is nothing between them: $32 is R=2 and $36 is R=3, adjacent levels.
#
#   So the in-between had to come off the red axis. $30 = (170,170,0) holds yellow's
#   HUE exactly (R and G equal, as in pure yellow) but one level darker, giving a
#   duller yellow rather than a greener one. Four candidates were rendered against
#   the oracle side by side ($32 lime, $30 dark, $37 pale, $36 pure) and Jay chose
#   $30.
#
# This is a deliberate PERCEPTUAL override of a correct measurement. Nearest-in-RGB
# is not nearest-in-perception, and with 2 bits per channel the gap between them is
# wide enough to see. Recorded so nobody "fixes" it back to the arithmetic. The
# measured Apple values are untouched; only this entry's CoCo3 quantisation is
# overridden. Expect more of these as art lands -- the measurement gets the colour,
# the eye gets the hue, and this table is where they are reconciled.
#
# indices 5 and 10, Apple grey (128, 128, 128) -> $07, Jay's call after three tries:
#   the grey axis has only four levels (0, 85, 170, 255) and 128 sits almost exactly
#   between 85 and 170 -- 43 from each, a tie that nearest-neighbour broke upward.
#     $38 (170,170,170)  "too light"
#     $07 (85,85,85)     "too dark"
#     dither $07/$38     rejected -- averages to (127,127,127), within one unit of
#                        the Apple's grey, but a checkerboard is a TEXTURE, not a
#                        colour, and it read as noise rather than as mid grey
#   $07 is therefore the least-wrong SOLID colour, chosen deliberately over an
#   arithmetically closer dither. Recorded because the dither looks like the obvious
#   clever answer and was tried and rejected on the screen -- do not re-derive it.
#
#   Both greys measured as the identical Apple colour, so both take $07; splitting
#   them would invent a distinction the source does not make. (The dither experiment
#   did split them, which is why that redundancy is now free again.)
COCO3_OVERRIDE = {
    5:  0x07,       # grey 1: $38 too light, dither rejected -> $07, Jay's call
    10: 0x07,       # grey 2: same source colour, kept consistent
    14: 0x30,       # yellow: $32 (lime) / $36 (too yellow) -> $30, Jay's choice
}


def coco3_rgb_byte(r, g, b):
    """24-bit RGB -> CoCo3 GIME palette byte, RGB monitor format.

    bits 5:0 = R1 G1 B1 R0 G0 B0, i.e. two bits per channel.
    [ref: docs/ground-truth/SockmasterGime.md:218-225]
    CLAUDE.md §4 makes RGB the project's monitor gate; the same byte means a
    different colour under composite, which is what made orange read yellow in P1.3.
    """
    def q(v):                       # 0..255 -> 0..3
        return min(3, (v * 4) // 256)
    R, G, B = q(r), q(g), q(b)
    return (((R >> 1) & 1) << 5 | ((G >> 1) & 1) << 4 | ((B >> 1) & 1) << 3
            | (R & 1) << 2 | (G & 1) << 1 | (B & 1))


def row_base(y):
    """Apple hi-res row interleave. Rows are NOT linearly addressed."""
    return (y & 7) * 0x400 + ((y >> 3) & 7) * 0x80 + (y >> 6) * 0x28


def decode(main, aux):
    """-> list of 192 rows, each a list of 140 colour indices (0-15)."""
    rows = []
    for y in range(ROWS):
        base = row_base(y)
        bits = []
        for col in range(40):
            # AUX byte first, then MAIN, 7 bits each, LSB-first (bit 0 = leftmost)
            for byte in (aux[base + col], main[base + col]):
                for b in range(7):
                    bits.append((byte >> b) & 1)
        # 560 dots -> 140 colour pixels, 4 dots each, first dot = LSB
        px = []
        for i in range(0, 560, 4):
            px.append(bits[i] | bits[i + 1] << 1 | bits[i + 2] << 2 | bits[i + 3] << 3)
        rows.append(px)
    return rows


def from_render(raw, pal):
    """DISPLAY-faithful path: convert the oracle's RENDERED frame, not its data.

    WHY THIS EXISTS, and why it is not cheating. The 16-band probe proved the DATA
    model exactly: 140 colour values per row, LSB-first groups, aux on even columns.
    Converting that data matches the oracle 100% in colour interiors -- and produces
    no fringing at all, because THE FRINGING IS NOT IN THE DATA. The same probe
    showed a single dot at phase 3 renders across screen dots 2, 3 AND 4, bleeding
    into the next group: that colour is generated by the display, at display time,
    and the game's bytes contain no trace of it.

    Reproducing it therefore means INVENTING pixels -- exactly what karateka's
    4-colour converter does for single hi-res, where it paints chroma at col-1, a
    pixel that was OFF. This is the double-hi-res equivalent, and it is a deliberate
    fidelity policy: match what the machine LOOKS like rather than what its memory
    holds. Jay chose it after comparing both against the oracle.

    280 distinct virtual pixels are required. At 140 (one CoCo3 byte each) there is
    no sub-pixel room for a fringe to live in; at 280 each virtual pixel is one CoCo3
    pixel, and a packed row maps 1:1 onto framebuffer bytes.
    """
    import struct
    W, H = 560, ROWS
    px = struct.unpack('<%dI' % (W * H), raw)

    def nearest(rgb):
        return min(range(16), key=lambda i: (rgb[0] - pal[i][0]) ** 2
                                          + (rgb[1] - pal[i][1]) ** 2
                                          + (rgb[2] - pal[i][2]) ** 2)
    cache, rows = {}, []
    for y in range(H):
        base = y * W
        r = []
        for v in range(280):                 # each virtual pixel = 2 screen dots
            a, b = px[base + 2 * v], px[base + 2 * v + 1]
            i = cache.get((a, b))
            if i is None:
                rgb = (((a >> 16 & 0xFF) + (b >> 16 & 0xFF)) // 2,
                       ((a >> 8 & 0xFF) + (b >> 8 & 0xFF)) // 2,
                       ((a & 0xFF) + (b & 0xFF)) // 2)
                i = cache[(a, b)] = nearest(rgb)
            r.append(i)
        rows.append(r)
    return rows


def to_packed(rows):
    """140 indices/row -> 70 bytes/row, 4 bits per pixel, high nibble = even pixel.

    WHY PACKED RATHER THAN A READY-MADE FRAMEBUFFER. The obvious asset is a full
    160x192 framebuffer with the margins baked in (30,720 B), and that is what this
    tool emitted first. It does not fit: loaded at $0200 it runs to $7CE1, straight
    through the kernel at $3000 and into the MMU draw window at $6000 that
    HAL_gfx_set_mode remaps away -- and lwlink places overlapping sections without
    a word of complaint. At 4 bits per pixel the same image is 13,440 B and clears
    the kernel comfortably.

    The cost is that the engine expands nibbles at blit time and applies the +20 px
    centring itself, so the virtual-resolution contract now lives in the blit rather
    than in the asset. Still exactly one place.
    """
    out = bytearray()
    for px in rows:
        for i in range(0, len(px), 2):
            out.append((px[i] << 4) | px[i + 1])
    return bytes(out)


def to_framebuffer(rows):
    """140-wide indices -> CoCo3 320x192x16 bytes, CENTERED (the +20 px contract).

    One DHR colour pixel == one framebuffer byte (2 px/byte, 2x horizontal), so the
    mapping is exact.
    """
    fb = bytearray(FB_STRIDE * ROWS)
    for y, px in enumerate(rows):
        o = y * FB_STRIDE + LEFT_MARGIN_BYTES
        for i, c in enumerate(px):
            fb[o + i] = (c << 4) | c        # both pixels of the byte
    return bytes(fb)


def preview(rows, path, scale=2, centered=False):
    """Decode preview at native 1:1 (idiom §11b — never a stretched MAME snapshot)."""
    from PIL import Image
    w = 320 if centered else WIDTH_DHR * 2
    img = Image.new('RGB', (w, ROWS))
    p = img.load()
    for y, px in enumerate(rows):
        for i, c in enumerate(px):
            x0 = (20 + 2 * i) if centered else (2 * i)
            p[x0, y] = DHR_RGB[c]
            p[x0 + 1, y] = DHR_RGB[c]
    if scale > 1:
        img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    img.save(path)
    return img.size


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--main', required=True, help='8 KB MAIN-bank dump of $2000-$3FFF')
    ap.add_argument('--aux', required=True, help='8 KB AUX-bank dump of $2000-$3FFF')
    ap.add_argument('--out', required=True, help='output packed 4bpp asset (.bin)')
    ap.add_argument('--full-fb', help='also emit the un-packed 160x192 framebuffer')
    ap.add_argument('--preview', help='decode preview PNG (280-wide content)')
    ap.add_argument('--preview-centered', help='preview as it lands in the 320 framebuffer')
    ap.add_argument('--palette', help='write the 16 CoCo3 palette bytes here')
    ap.add_argument('--from-render', metavar='RAW',
                    help='DISPLAY-faithful: convert this 560x192 ARGB32 oracle '
                         'frame dump (280 virtual px/row) instead of the banks')
    ap.add_argument('--scale', type=int, default=2)
    a = ap.parse_args()

    m = pathlib.Path(a.main).read_bytes()
    x = pathlib.Path(a.aux).read_bytes()
    if len(m) != 8192 or len(x) != 8192:
        sys.exit(f"expected two 8192-byte banks, got main={len(m)} aux={len(x)}")
    if m == x:
        sys.exit("main and aux are IDENTICAL — the bank switch did not take; refusing "
                 "to emit a half-image (see P3.1/P3.2)")

    if a.from_render:
        rows = from_render(pathlib.Path(a.from_render).read_bytes(), DHR_RGB)
        print('DISPLAY-faithful: 280 virtual px/row from the rendered frame')
    else:
        rows = decode(m, x)
        print('DATA-faithful: %d colour px/row from the memory banks' % WIDTH_DHR)
    used = sorted({c for r in rows for c in r})
    packed = to_packed(rows)
    pathlib.Path(a.out).write_bytes(packed)
    if a.full_fb:
        pathlib.Path(a.full_fb).write_bytes(to_framebuffer(rows))

    pal = bytes(COCO3_OVERRIDE.get(i, coco3_rgb_byte(*DHR_RGB[i]))
                for i in range(16))
    if a.palette:
        pathlib.Path(a.palette).write_bytes(pal)

    print(f"palette indices present: {used}")
    print(f"packed asset: {len(packed)} bytes ({len(packed)//ROWS} B/row x {ROWS}) -> {a.out}")
    print(f"  engine expands to {FB_STRIDE} B/row, content at bytes "
          f"{LEFT_MARGIN_BYTES}..{LEFT_MARGIN_BYTES + WIDTH_DHR - 1} "
          f"({LEFT_MARGIN_BYTES} B margin each side = the 280->320 centring)")
    print("CoCo3 palette (RGB monitor): " + ' '.join(f'{b:02X}' for b in pal))
    if a.preview:
        print(f"preview {preview(rows, a.preview, a.scale)} -> {a.preview}")
    if a.preview_centered:
        print(f"preview centered {preview(rows, a.preview_centered, a.scale, True)}"
              f" -> {a.preview_centered}")


if __name__ == '__main__':
    main()
