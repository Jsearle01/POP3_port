#!/usr/bin/env python3
r"""cel_blit_prep.py — bake a converted.s cel into the runtime blitter's segment format.

P3.20 piece D. The blitter never shifts at runtime (P3.19): the sub-byte phase is
baked here, and each row is pre-segmented into the three cases the blitter has
instructions for.

--------------------------------------------------------------------------------
WHY THE DATA IS LAID OUT BACKWARDS IN PLACES — read this before editing
--------------------------------------------------------------------------------
The opaque core is `pulu d,x,y` / `pshs d,x,y`: 22 cycles for 6 bytes, the fastest
byte-mover the 6809 has. PULU ASCENDS and PSHS DESCENDS, and that asymmetry is not
cosmetic:

    pulu d,x,y   reads src[0:2]->D, src[2:4]->X, src[4:6]->Y   (U += 6)
    pshs d,x,y   writes so that ASCENDING from the new S: D, X, Y   (S -= 6)

So each 6-byte GROUP lands in the right order, but successive groups land at
DESCENDING addresses. Feeding a segment forward would write its groups back to
front. Since this tool generates the data, the fix is free: **each BLAST segment's
6-byte groups are emitted in reverse group order, bytes within a group forward.**

This is exactly the class of bug PA.9 shipped (it had the PSHU register->byte
mapping inverted and its checker could not see it), so nothing here is trusted to
reasoning: simulate() below REPLAYS the 6809 semantics byte by byte and reconstructs
the framebuffer, and the CLI refuses to emit a cel whose replay does not match the
source bitmap exactly.

--------------------------------------------------------------------------------
SEGMENT FORMAT (per row, terminated by SEG_END)
--------------------------------------------------------------------------------
    $00            SEG_END      end of row
    $01 nn         SEG_SKIP     advance nn transparent bytes, draw nothing
    $02 nn <data>  SEG_BLAST    nn opaque bytes, groups reversed (see above)
    $03 nn <pairs> SEG_MERGE    nn bytes as (mask,src) pairs, applied low->high

Transparency is index 0 with NO opacity sidecar (P3.18 3B), so a pixel is
transparent iff its 2-bit value is 0. MERGE mask bytes keep the destination where
the cel is transparent: mask bit-pair = 11 to keep dest, 00 to take src.
"""
import argparse
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "sprite_tool"))
from celio import Cel                                    # noqa: E402

SEG_END, SEG_SKIP, SEG_BLAST, SEG_MERGE = 0, 1, 2, 3


def shift_pixels(cel, phase):
    """The cel's pixel grid shifted right `phase` pixels; width grows by one byte."""
    w = cel.w + (1 if phase else 0)
    rows = []
    for r in range(cel.h):
        px = [0] * phase + list(cel.pixels[r])
        px += [0] * (w * 4 - len(px))
        rows.append(px)
    return rows, w


def pack_row(px, w):
    return [((px[c * 4] & 3) << 6) | ((px[c * 4 + 1] & 3) << 4)
            | ((px[c * 4 + 2] & 3) << 2) | (px[c * 4 + 3] & 3) for c in range(w)]


def classify(px, c):
    """'skip' | 'blast' | 'merge' for the byte at column c (4 pixels)."""
    q = px[c * 4:c * 4 + 4]
    if all(v == 0 for v in q):
        return 'skip'
    if all(v != 0 for v in q):
        return 'blast'
    return 'merge'


def encode_row(px, w):
    """One row -> segment bytes."""
    out = []
    c = 0
    while c < w:
        kind = classify(px, c)
        run = c
        while run < w and classify(px, run) == kind:
            run += 1
        n = run - c
        data = pack_row(px, w)
        if kind == 'skip':
            out += [SEG_SKIP, n]
        elif kind == 'blast':
            out += [SEG_BLAST, n]
            # GROUPS ARE FOUR BYTES, NOT SIX, and the reason is register pressure
            # rather than the stack: `pulu d,x,y` would move six, but X is the
            # blitter's destination pointer and PULU would clobber it. `pulu d,y`
            # moves four for 18 cy = 4.5 cy/byte, inside the 4.5-5.8 band P3.19
            # measured for real 4-9 byte rows, so the budget is unaffected.
            #
            # Emitted in CONSUMPTION order, which is high address to low because S
            # descends: the top 4-byte groups first, then the 1-3 byte tail that
            # occupies the lowest addresses. Within a 3-byte tail the pair comes
            # before the single, for the same reason.
            body = data[c:run]
            rem = n % 4
            groups = [body[rem + i:rem + i + 4] for i in range(0, n - rem, 4)]
            for g in reversed(groups):
                out += g
            if rem == 3:
                out += body[1:3] + body[0:1]
            elif rem:
                out += body[:rem]
        else:
            out += [SEG_MERGE, n]
            for i in range(c, run):
                mask = 0
                for k in range(4):
                    if px[i * 4 + k] == 0:
                        mask |= 3 << (6 - 2 * k)      # keep destination here
                out += [mask, data[i]]
        c = run
    out.append(SEG_END)
    return out


def simulate(segments, h, w, dest_stride=80, initial=None):
    """Replay the blitter's 6809 semantics and rebuild what the screen would hold.

    Independent of encode_row on purpose: it walks the emitted stream the way the
    assembly will, including PSHS descending, rather than re-deriving from pixels.
    Returns a dict mapping framebuffer offset -> byte.

    `initial` is the DESTINATION the blit lands on, and it is load-bearing: MERGE
    reads the destination back. Replaying onto an empty framebuffer reads zero
    there, which makes a correct mask indistinguishable from a mask of $00 — the
    first run of this verifier reported 44 mismatches for exactly that reason, and
    the data was fine. A checker that cannot see the background cannot test a merge.
    """
    fb = dict(initial) if initial else {}
    p = 0
    for r in range(h):
        col = 0
        while True:
            op = segments[p]
            p += 1
            if op == SEG_END:
                break
            n = segments[p]
            p += 1
            if op == SEG_SKIP:
                col += n
            elif op == SEG_BLAST:
                # S starts one past the segment end and descends; groups arrive
                # high-to-low, so replay consumes them the same way. Sizes mirror
                # the assembly exactly: 4s, then a 2, then a 1.
                s = r * dest_stride + col + n
                rem = n % 4
                sizes = [4] * ((n - rem) // 4)
                sizes += {0: [], 1: [1], 2: [2], 3: [2, 1]}[rem]
                for sz in sizes:
                    grp = segments[p:p + sz]
                    p += sz
                    s -= sz
                    for i, b in enumerate(grp):
                        fb[s + i] = b
                col += n
            elif op == SEG_MERGE:
                for i in range(n):
                    mask, src = segments[p], segments[p + 1]
                    p += 2
                    o = r * dest_stride + col + i
                    fb[o] = ((fb.get(o, 0) & mask) | src) & 0xFF
                col += n
            else:
                raise ValueError("bad opcode %d" % op)
    return fb


def verify(cel, phase, segments):
    """Replay must reproduce the shifted bitmap exactly, over a hostile background."""
    rows, w = shift_pixels(cel, phase)
    # a non-zero background proves the mask keeps what it should; a zero one cannot
    bg = {}
    for r in range(cel.h):
        for c in range(w):
            bg[r * 80 + c] = 0xB4
    fb = simulate(segments, cel.h, w, initial=bg)
    # rebuild expected: transparent pixels keep background, others take the cel
    bad = []
    for r in range(cel.h):
        want_row = pack_row(rows[r], w)
        for c in range(w):
            o = r * 80 + c
            exp = 0
            for k in range(4):
                px = rows[r][c * 4 + k]
                sh = 6 - 2 * k
                exp |= (px if px else ((0xB4 >> sh) & 3)) << sh
            if fb.get(o, 0xB4) != exp:
                bad.append((r, c, fb.get(o, 0xB4), exp))
    return bad


def emit_asm(label, cel, phase, segments, w):
    L = ["* %s — runtime-blit segment data, phase %d" % (label, phase),
         "* GENERATED by harness/tools/cel_blit_prep.py — do not hand-edit.",
         "* %d rows x %d bytes, %d segment bytes" % (cel.h, w, len(segments)),
         "*",
         "%s:" % label,
         "        fcb     %d,%d  ; height, width in bytes" % (cel.h, w)]
    for i in range(0, len(segments), 12):
        L.append("        fcb     " + ",".join("$%02X" % b for b in segments[i:i + 12]))
    return "\n".join(L) + "\n"


def main():
    ap = argparse.ArgumentParser(description="bake a cel for the runtime blitter")
    ap.add_argument("cel", help="path to a converted.s")
    ap.add_argument("--phase", type=int, default=0, choices=(0, 1, 2, 3))
    ap.add_argument("--label", default=None)
    ap.add_argument("--out", default=None)
    a = ap.parse_args()

    cel = Cel(a.cel)
    rows, w = shift_pixels(cel, a.phase)
    segments = []
    for r in range(cel.h):
        segments += encode_row(rows[r], w)

    bad = verify(cel, a.phase, segments)
    label = a.label or (pathlib.Path(a.cel).parent.name + "_p%d" % a.phase)
    print("%-22s phase %d  %dx%dB  %d segment bytes  (%.2f B/footprint byte)"
          % (label, a.phase, cel.h, w, len(segments), len(segments) / (cel.h * w)))
    if bad:
        print("  REPLAY MISMATCH at %d bytes; first: row %d col %d got $%02X want $%02X"
              % (len(bad), bad[0][0], bad[0][1], bad[0][2], bad[0][3]))
        return 1
    print("  replay OK — reconstructs the shifted bitmap over a $B4 background")
    if a.out:
        p = pathlib.Path(a.out)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(emit_asm(label, cel, a.phase, segments, w), newline="\n")
        print("  -> %s" % p)
    return 0


if __name__ == "__main__":
    sys.exit(main())
