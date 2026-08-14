#!/usr/bin/env python3
r"""verify_room_flame_pixels.py — is the drawn flame the RIGHT PIXELS, not just moving?

The existing flicker check asserts that bytes change and that the changes stay inside
the torch boxes. It cannot see a wrong COLOUR, a wrong cel, or a corrupted merge —
which is exactly how blue pixels reached Jay's eye instead of the suite's. A test that
cannot detect a wrong pixel is not testing the draw.

This composites the expected framebuffer offline — the room asset with cel N laid over
it at the torch position, opaque where the cel is non-zero and transparent where it is
index 0 (the flames convert with opacity=none, so every black pixel is keyed) — and
compares it against the captured screen byte for byte inside the torch boxes.

The engine reports which cel each torch is showing, so there is no guessing about
which of the nine to composite: probe_cel0/probe_cel1 are read at capture time and
passed in here.
"""
import argparse
import pathlib
import re
import sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import cel_blit_prep as cbp
import cel_parity_rule as R

STRIDE = 80
CEL_W, CEL_H = 2, 13
FLAME_TOP = 101


def torch_cols(src='src/engine/cutscene_room.s'):
    """the torch byte columns, READ FROM THE ENGINE rather than duplicated here.

    This held its own `{0: 28, 1: 50}` and that is the trap the pool row
    a-constant-duplicated-across-files-survives-the-link-and-the-boot describes: two files
    independently asserting the same fact, with nothing that can ever compare them. Moving
    torch 0 to byte 27 (P3.56) would have left this checker compositing at 28 and calling
    the CORRECTED render broken -- a check that fails on a good build teaches you to
    distrust the check. One home, so the two cannot drift.
    """
    txt = pathlib.Path(src).read_text()
    cols = {}
    for t in (0, 1):
        m = re.search(rf'^TORCH{t}_COL\s+equ\s+(\d+)', txt, re.M)
        if not m:
            raise SystemExit(f'  FAIL cannot find TORCH{t}_COL in {src}')
        cols[t] = int(m.group(1))
    return cols


TORCH_COL = torch_cols()


def load_segments(seg_dir, torch, n):
    """the EMITTED segment stream for this torch's cel: (rows, width, segment bytes).

    THE CHECKER READS WHAT THE BUILD SHIPPED, and replays it with the blitter's own
    consumer. It used to lay converted.s over the room OPAQUELY at a byte column, which
    is a faithful model of a PHASE-0 torch and nothing else. P3.54 put torch 1 on phase
    1: three bytes wide, with the partial edge bytes emitted as SEG_MERGE so the
    background shows through. The opaque model called that 21 wrong bytes when the render
    was right -- Jay cleared it by eye ("the right flame looks good") and the check could
    not.

    Replaying is NOT circular. cel_blit_prep.simulate walks the emitted stream the way
    the 6809 does and is "independent of encode_row on purpose" (its own docstring): the
    encoder turns pixels into segments, this turns segments back into pixels, so an
    encoder bug shows up as a wrong reconstruction rather than cancelling out.
    """
    p = pathlib.Path(seg_dir) / f't{torch}_{n}.s'
    vals = []
    for line in p.read_text().splitlines():
        if 'fcb' not in line:
            continue
        vals += [int(t, 16) for t in re.findall(r'\$([0-9A-Fa-f]{2})', line)]
    # the header is `fcb 13,2` in DECIMAL and the segments are $hh — read the header
    # separately rather than letting a hex scan miss it.
    hdr = None
    for line in p.read_text().splitlines():
        m = re.search(r'fcb\s+(\d+)\s*,\s*(\d+)', line)
        if m:
            hdr = (int(m.group(1)), int(m.group(2)))
            break
    if hdr is None:
        raise SystemExit(f'  FAIL {p}: no `fcb rows,width` header')
    return hdr[0], hdr[1], vals


def composite_replay(room, seg_dir, torch, n, col):
    """lay the cel over the room by REPLAYING the emitted stream onto it."""
    h, w, segs = load_segments(seg_dir, torch, n)
    origin = FLAME_TOP * STRIDE + col
    initial = {r * STRIDE + c: room[origin + r * STRIDE + c]
               for r in range(h) for c in range(w + 1)}
    out = cbp.simulate(segs, h, w, dest_stride=STRIDE, initial=initial)
    fb = bytearray(room)
    for off, b in out.items():
        fb[origin + off] = b
    return bytes(fb)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--room', required=True)
    ap.add_argument('--shot', required=True)
    ap.add_argument('--seg-dir', default='build/flames_seg',
                    help='the EMITTED segment streams the build shipped (tN_M.s)')
    ap.add_argument('--cel0', type=int, required=True)
    ap.add_argument('--cel1', type=int, required=True)
    ap.add_argument('--pos', help='recorded character positions; their footprints are '
                                  'excluded, because a character standing in front of '
                                  'a torch is content, not damage')
    ap.add_argument('--tag', default='first', help='which capture row in --pos')
    a = ap.parse_args()

    room = pathlib.Path(a.room).read_bytes()
    shot = pathlib.Path(a.shot).read_bytes()
    if len(shot) != len(room):
        print(f"  FAIL capture is {len(shot)} B, expected {len(room)}")
        return 1

    want = composite_replay(room, a.seg_dir, 0, a.cel0, TORCH_COL[0])
    want = composite_replay(want, a.seg_dir, 1, a.cel1, TORCH_COL[1])

    # A CHARACTER MAY STAND IN FRONT OF A TORCH. Until P3.32 the vizier stood at column
    # 54 forever and could not; now he walks the width of the room and passes both
    # torches, so this check has to know where he is or it reports the flames as broken
    # every time he crosses one. The footprints come from the machine's own record, not
    # from an assumption about where he might be.
    covered = set()
    if a.pos and pathlib.Path(a.pos).exists():
        W, H = 11, 48                   # widest cel + a byte for the sub-byte spill
        for line in pathlib.Path(a.pos).read_text().splitlines():
            f = line.split()
            # ONLY THIS CAPTURE'S ROW. The file holds every capture, and excluding all
            # of them would excuse bytes no character was standing on at this instant —
            # a check that widens itself is a check that stops failing.
            # ★ NINE FIELDS, NOT SEVEN (P3.83). P3.71 added both characters' FACING to the
            # position line and this reader was not updated, so `len(f) != 7` skipped every
            # line for eleven dispatches and `covered` stayed empty — the exclusion this
            # whole block exists for was DEAD, and a character standing in front of a torch
            # would have been reported as broken flames. It never fired because nobody
            # stood there; that is luck, not a passing test.
            #
            # The count is checked on every build now by harness_offsets_check.py, which
            # compares what the writers emit against what the readers require.
            if len(f) != 9 or f[0] != a.tag:
                continue
            vx, vy, vc, px, py, pc = map(int, f[1:7])
            for x, y, cel in ((vx, vy, vc), (px, py, pc)):
                # SETUPCHAR's expression (P3.58) — see verify_room_flicker.py
                _i, fdx, _fy, fchk, _l = R.altset2()[cel]
                col = (R.draw_x(x, fdx, fchk) + 20) >> 2
                for r in range(y - H + 1, y + 1):
                    for c in range(col - 1, col + W + 1):
                        covered.add(r * STRIDE + c)

    # WIDTH PER TORCH, FROM THE EMITTED HEADER. CEL_W was 2 because every torch was
    # byte-aligned; torch 1 is three bytes wide at phase 1, and checking only two of them
    # would leave its spill column untested — the exact column the phase change creates.
    widths = {t: load_segments(a.seg_dir, t, n)[1]
              for t, n in ((0, a.cel0), (1, a.cel1))}
    total = sum(w * CEL_H for w in widths.values())

    bad, checked = [], 0
    for t, col in TORCH_COL.items():
        for r in range(FLAME_TOP, FLAME_TOP + CEL_H):
            for c in range(col, col + widths[t]):
                o = r * STRIDE + c
                if o in covered:
                    continue
                checked += 1
                if shot[o] != want[o]:
                    bad.append((t, r, c, shot[o], want[o]))
    if not bad:
        hidden = total - checked
        print(f"  PASS flame pixels are exactly cel {a.cel0}/{a.cel1} over the room: "
              f"{checked} bytes byte-identical"
              + (f" ({hidden} behind a character)" if hidden else ""))
        return 0 if checked else 1      # all of it hidden proves nothing

    print(f"  FAIL flame pixels wrong: {len(bad)} of {checked} bytes checked")
    names = {0: 'black', 1: 'orange', 2: 'BLUE', 3: 'white'}
    for t, r, c, got, exp in bad[:6]:
        gp = [names[(got >> (6 - 2 * k)) & 3] for k in range(4)]
        ep = [names[(exp >> (6 - 2 * k)) & 3] for k in range(4)]
        print(f"    torch {t} row {r} col {c}: got ${got:02X} {gp} want ${exp:02X} {ep}")
    return 1


if __name__ == '__main__':
    sys.exit(main())
