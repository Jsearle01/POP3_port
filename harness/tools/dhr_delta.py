#!/usr/bin/env python3
"""dhr_delta.py — a SPARSE screen patch: the credit line, and nothing else.

WHAT THIS IS FOR. The oracle's intro is built out of one base image plus small
patches drawn over it (`DeltaExpPop`, MASTER.S:750/792/816). P3.3 traced the
mechanism and found the two credits share a single base picture: "Broderbund
Software Presents" and "A Game by Jordan Mechner" are patches over the SAME splash,
never separate screens. So the port stores one base and two patches, which is both
the faithful structure and the only one that fits.

WHY SPARSE AND NOT A RECTANGLE. A rectangle was the first design and it does not
fit in memory, which is worth stating with the numbers rather than asserting:

    base image (display-faithful, 280x192 at 4bpp)   26,880 B
    presents patch as a rectangle 108 x 45            2,430 B
    byline   patch as a rectangle 112 x 25            1,400 B
                                                    ----------
                                                     30,710 B

against $0200..$77FF = 30,208 bytes of program space. Over budget before a single
instruction of engine code. But only 1,172 of the presents rectangle's 4,860 pixels
actually differ from the base (24%), and 803 of the byline's 2,800 (29%) -- the
bounding box is mostly unchanged picture. Encoding only the differing runs takes
both patches to about a tenth of that, and the saving is not a trick: a patch that
stores unchanged pixels is not really a delta.

THE FORMAT, and the one thing it is designed around: the SAME run list drives the
patch AND its removal. A run is (row, col, len), and the engine can fill it from
either the patch data or the base image, because the base's byte for framebuffer
column C at row R sits at a fixed offset. So "undo the credit line" needs no second
asset and no full-screen copy -- it is the same geometry read from the other source.
That is the port's equivalent of the oracle's `copy2to1`, and it touches ~1 KB
instead of 16.

    fdb  first_row          ; first scanline described
    fcb  n_rows             ; consecutive rows described
    per row:
      fcb  n_runs           ; 0 = this row is unchanged
      per run:
        fcb  col            ; byte column in the 160-byte framebuffer row
        fcb  len            ; bytes, 1..255
        fcb  data * len     ; packed 4bpp, 2 px/byte -- framebuffer format

Coordinates are FRAMEBUFFER coordinates, already carrying the +20 px centring of
the virtual-resolution contract, because a screen patch has no placement freedom:
it registers against the base picture and nowhere else. (Contrast a sprite cel,
whose placement is a table decision -- CLAUDE.md §2F.)

MERGING. Two runs separated by a short unchanged gap cost 3 bytes of header each;
bridging the gap costs one byte per pixel-pair. Below the break-even the encoder
merges, which makes the output smaller AND the blit inner loop longer -- both good.
"""
import argparse
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import dhr_convert as D                                          # noqa: E402

LEFT_MARGIN_BYTES = D.LEFT_MARGIN_BYTES     # 10 — the 280->320 centring
RUN_HEADER = 3                              # col + len + the row's share
MERGE_GAP = RUN_HEADER                      # bridge a gap cheaper than a new run


def rows_from_render(path):
    return D.from_render(pathlib.Path(path).read_bytes(), D.DHR_RGB)


def pack_row(px):
    """280 indices -> 140 bytes, 2 px/byte, high nibble = even (left) pixel."""
    return bytes((px[i] << 4) | px[i + 1] for i in range(0, len(px), 2))


def encode(base_rows, over_rows):
    """-> (blob, stats). Byte-level diff in FRAMEBUFFER packing."""
    diff_rows = []
    for y in range(D.ROWS):
        b, o = pack_row(base_rows[y]), pack_row(over_rows[y])
        cols = [i for i in range(len(b)) if b[i] != o[i]]
        diff_rows.append((cols, o))

    live = [y for y, (c, _) in enumerate(diff_rows) if c]
    if not live:
        return None, None
    y0, y1 = live[0], live[-1]

    blob = bytearray()
    blob += bytes([y0 >> 8, y0 & 0xFF, y1 - y0 + 1])
    n_runs = n_bytes = 0
    for y in range(y0, y1 + 1):
        cols, packed = diff_rows[y]
        runs = []
        for c in cols:
            if runs and c - (runs[-1][0] + runs[-1][1]) <= MERGE_GAP:
                s, ln = runs[-1]
                runs[-1] = (s, c - s + 1)
            else:
                runs.append((c, 1))
        blob.append(len(runs))
        for s, ln in runs:
            # framebuffer column = source byte + the left margin
            blob += bytes([s + LEFT_MARGIN_BYTES, ln]) + packed[s:s + ln]
            n_runs += 1
            n_bytes += ln
    return bytes(blob), dict(y0=y0, rows=y1 - y0 + 1, runs=n_runs,
                             px_bytes=n_bytes, total=len(blob))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--base', required=True, help='560x192 ARGB32 dump: the base screen')
    ap.add_argument('--over', required=True, help='560x192 ARGB32 dump: base + the patch')
    ap.add_argument('--out', required=True)
    a = ap.parse_args()

    base = rows_from_render(a.base)
    over = rows_from_render(a.over)
    blob, st = encode(base, over)
    if blob is None:
        sys.exit('the two frames are IDENTICAL — refusing to emit an empty patch')
    pathlib.Path(a.out).write_bytes(blob)
    rect = 0
    cols = [x for y in range(D.ROWS) for x in range(140)
            if pack_row(base[y])[x] != pack_row(over[y])[x]]
    if cols:
        rect = (max(cols) - min(cols) + 1) * st['rows']
    print(f"{a.out}: {st['total']} bytes  "
          f"(rows {st['y0']}..{st['y0'] + st['rows'] - 1}, {st['runs']} runs, "
          f"{st['px_bytes']} pixel bytes)")
    if rect:
        print(f"  same patch as a bounding rectangle: {rect} bytes "
              f"-> sparse is {100 * st['total'] / rect:.0f}% of it")


if __name__ == '__main__':
    main()
