#!/usr/bin/env python3
r"""decb_to_raw.py — a DECB segmented binary -> a flat image for a raw track.

The engine reads its assets off raw whole tracks with the WD1773 primitive, which
knows nothing about DECB files: it drops bytes at an address. Code destined for a raw
track therefore has to be flattened out of lwlink's DECB output first — header,
per-segment length/address, and the $FF trailer all removed, and the segments placed
at their true offsets from a stated base.

Written for the torch-flame bundle (P3.17 phase B), which is linked at $0A00 and read
into $0A00 at run time. A gap between segments is filled rather than skipped, because
the track read is a flat copy and offsets have to be true.
"""
import argparse
import pathlib
import sys


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--bin', required=True, help='lwlink --decb output')
    ap.add_argument('--out', required=True)
    ap.add_argument('--base', required=True, type=lambda s: int(s, 0),
                    help='the address the raw image will be loaded at')
    ap.add_argument('--fill', type=lambda s: int(s, 0), default=0)
    ap.add_argument('--allow-gap', action='store_true',
                    help='permit a leading gap between --base and the first segment')
    # ★ P3.106 — DROP SEGMENTS AT OR ABOVE AN ADDRESS, and say which ones were dropped.
    #
    # The scene's disk-resident image (link/pop_scene.link) must be linked WITH
    # hal_build.o so its HAL calls resolve — lwasm's object mode makes an undefined symbol
    # an external automatically — but the kernel is already resident at $7900 from the
    # intro's LOADM, and this tool FILLS GAPS between segments, so without this the raw
    # image would span $2500..$7D43: 21 KB of mostly padding, and re-reading the kernel
    # from a track while the kernel is executing the read.
    #
    # The drop is printed rather than silent, because a segment vanishing from an image is
    # exactly the kind of thing that should never be inferred from a size.
    ap.add_argument('--span-end', type=lambda s: int(s, 0), default=None,
                    help='drop segments whose load address is >= this (they are reported)')
    a = ap.parse_args()

    d = pathlib.Path(a.bin).read_bytes()
    segs, i = [], 0
    while i < len(d):
        t = d[i]
        ln = (d[i + 1] << 8) | d[i + 2]
        ad = (d[i + 3] << 8) | d[i + 4]
        if t == 0xFF:
            print(f"  exec ${ad:04X}")
            break
        segs.append((ad, d[i + 5:i + 5 + ln]))
        i += 5 + ln

    if not segs:
        sys.exit("no segments found — is this a DECB binary?")

    if a.span_end is not None:
        keep = [(ad, b) for ad, b in segs if ad < a.span_end]
        for ad, b in segs:
            if ad >= a.span_end:
                print(f"  DROPPED seg ${ad:04X}..${ad + len(b) - 1:04X} "
                      f"({len(b)} B) — at or above --span-end ${a.span_end:04X}")
        if not keep:
            sys.exit(f"--span-end ${a.span_end:04X} dropped every segment")
        segs = keep

    lo = min(ad for ad, _ in segs)
    hi = max(ad + len(b) for ad, b in segs)
    if lo < a.base:
        sys.exit(f"segment at ${lo:04X} is below the stated base ${a.base:04X}")
    # AND IT MUST NOT BE ABOVE IT EITHER (P3.31). The load address lives in TWO places
    # that cannot see each other -- the linker script and this --base -- and a mismatch
    # in this direction is silent: the image just gains a run of fill at the front, so
    # every offset inside it is wrong by that much and the code jumps into padding. The
    # bundle is linked flush at its base, so lo != base means the two have drifted.
    if lo != a.base and not a.allow_gap:
        sys.exit(f"first segment is at ${lo:04X} but --base says ${a.base:04X} — the "
                 f"linker script and the build's base have drifted apart "
                 f"(pass --allow-gap if the leading gap is deliberate)")

    img = bytearray([a.fill]) * (hi - a.base)
    for ad, b in segs:
        o = ad - a.base
        img[o:o + len(b)] = b
        print(f"  seg ${ad:04X}..${ad + len(b) - 1:04X} -> offset {o} ({len(b)} B)")

    pathlib.Path(a.out).write_bytes(bytes(img))
    print(f"{a.out}: {len(img)} B flat image based at ${a.base:04X}")


if __name__ == '__main__':
    main()
