#!/usr/bin/env python3
"""make_intro_assets.py — the intro's raw-track payloads.

P3.4 moved the intro's screen out of the program image and onto the disk, so what
the build ships is no longer "a .bin the linker swallows" but two payloads the
running program reads for itself. This makes them.

WHY THE SCREEN IS STORED AS A FULL FRAMEBUFFER (30,720 B) AND NOT PACKED (26,880).
The packed form is 140 bytes per row and has to be expanded into 160-byte rows
with the +20 px margins — a blit. Stored as the framebuffer it already is, the
disk read lands 1:1 on the back buffer and there is no blit at all: the asset's
destination IS the framebuffer. Disk space is the one resource POP has spare
(89,856 bytes free on the .dsk), and 3,840 bytes of margin buys the removal of an
entire code path and, more importantly, of the resident copy.

    packed, resident, then blitted    26,880 B of program memory   (P3.3)
    framebuffer, on disk, read direct          0 B of program memory

This mirrors what the oracle does rather than what P3.3 did: the oracle expands
its compressed screen STRAIGHT INTO the display pages and never holds an
uncompressed copy anywhere. [P3.4 §1 — MASTER.S unpacksplash -> DblExpand]

THE BUNDLE (payload 2) carries the things that must stay resident because they are
consulted per-beat: the palette and the two caption patches. Fixed slots rather
than a header — the engine's equates and this layout are the same three numbers,
and an index would just be a third place to get them wrong.

    $000  palette          16 B
    $040  delta_presents  885 B
    $400  delta_byline    687 B
    $800  delta_title   5,909 B   (P3.7 -- the title is a THIRD caption over the
                                   same splash, not its own picture, so it lives
                                   here with the other two. It is 6.7x the size of
                                   the byline, which is why the bundle went from
                                   one track to two.)
"""
import argparse
import pathlib
import sys

FB_STRIDE = 160
SRC_STRIDE = 140
LEFT_MARGIN = 10
ROWS = 192
TRACK_BYTES = 4608

SLOT_PALETTE = 0x000
SLOT_PRESENTS = 0x040
SLOT_BYLINE = 0x400
SLOT_TITLE = 0x800
BUNDLE_TRACKS = 2


def framebuffer(packed, fill=0x00):
    """140 B/row packed -> 160 B/row framebuffer, content centred (the +20 px
    virtual-resolution contract, now baked into the asset instead of the blit)."""
    if len(packed) != SRC_STRIDE * ROWS:
        sys.exit(f"expected {SRC_STRIDE * ROWS} B of packed image, got {len(packed)}")
    fb = bytearray([fill]) * (FB_STRIDE * ROWS)
    for y in range(ROWS):
        o = y * FB_STRIDE + LEFT_MARGIN
        fb[o:o + SRC_STRIDE] = packed[y * SRC_STRIDE:(y + 1) * SRC_STRIDE]
    return bytes(fb)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--packed', default='content/intro/broderbund_splash.bin')
    ap.add_argument('--palette', default='content/intro/broderbund_splash.pal')
    ap.add_argument('--presents', default='content/intro/delta_presents.bin')
    ap.add_argument('--byline', default='content/intro/delta_byline.bin')
    ap.add_argument('--title', default='content/intro/delta_title.bin')
    ap.add_argument('--out-screen', required=True)
    ap.add_argument('--prolog', nargs=2, action='append', metavar=('PACKED', 'OUT'),
                    default=[], help='a further own-picture screen (P3.8)')
    ap.add_argument('--out-bundle', required=True)
    a = ap.parse_args()

    fb = framebuffer(pathlib.Path(a.packed).read_bytes())
    pathlib.Path(a.out_screen).write_bytes(fb)
    tracks = -(-len(fb) // TRACK_BYTES)
    print(f"{a.out_screen}: {len(fb)} B framebuffer "
          f"({tracks} tracks, {tracks * TRACK_BYTES - len(fb)} B pad)")

    for packed_path, out_path in a.prolog:
        fbp = framebuffer(pathlib.Path(packed_path).read_bytes())
        pathlib.Path(out_path).write_bytes(fbp)
        t = -(-len(fbp) // TRACK_BYTES)
        print(f"{out_path}: {len(fbp)} B framebuffer "
              f"({t} tracks, {t * TRACK_BYTES - len(fbp)} B pad)")

    bundle = bytearray(TRACK_BYTES * BUNDLE_TRACKS)
    for slot, path, limit in ((SLOT_PALETTE, a.palette, SLOT_PRESENTS - SLOT_PALETTE),
                              (SLOT_PRESENTS, a.presents, SLOT_BYLINE - SLOT_PRESENTS),
                              (SLOT_BYLINE, a.byline, SLOT_TITLE - SLOT_BYLINE),
                              (SLOT_TITLE, a.title,
                               TRACK_BYTES * BUNDLE_TRACKS - SLOT_TITLE)):
        d = pathlib.Path(path).read_bytes()
        if len(d) > limit:
            sys.exit(f"{path} is {len(d)} B, over its {limit} B slot at ${slot:03X}")
        bundle[slot:slot + len(d)] = d
        print(f"  ${slot:03X}  {pathlib.Path(path).name:22s} {len(d):5d} B "
              f"of {limit} B slot")
    pathlib.Path(a.out_bundle).write_bytes(bytes(bundle))
    print(f"{a.out_bundle}: {len(bundle)} B ({BUNDLE_TRACKS} tracks)")


if __name__ == '__main__':
    main()
