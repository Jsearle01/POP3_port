#!/usr/bin/env python3
"""xform_blast_perm.py — P5.20 phase 1: the `$80` pre-reversal, COMPUTED rather than argued.

Asks cel_blit_prep.encode_row for an n-byte blast of DISTINCT fully-opaque bytes and prints
which body byte each stream position holds. That is the permutation a runtime mirror or shift
has to read through. A mirror wants the body fully descending (for an ascending write), so:

    group ORDER  -- high-address first           -> already what the mirror wants (cancels)
    IN a group   -- forward                      -> the mirror wants it reversed (does not)
    3-byte tail  -- [1,2,0], pair then single    -> a third ordering

No 6809 stack op writes ascending, so a transformed blast cannot use blit_blast's
`pulu d,y`/`pshs d,y` mover; it is a per-byte loop, and that loop absorbs any fixed in-group
order with constant offsets (`ldb 3,u` ... `ldb 0,u`).
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import cel_blit_prep as P                                     # noqa: E402

OPAQUE = [b for b in range(256) if all((b >> s) & 3 for s in (0, 2, 4, 6))]   # 81 values


def stream_perm(n):
    """Body index held at each stream position of an n-byte blast, from encode_row itself."""
    px = []
    for i in range(n):
        v = OPAQUE[i]
        px += [(v >> 6) & 3, (v >> 4) & 3, (v >> 2) & 3, v & 3]
    body = P.pack_row(px, n)
    seg = P.encode_row(px, n)
    assert seg[0] == (P.SEG_BLAST << P.SEG_SHIFT) | n and seg[-1] == P.SEG_END
    return [body.index(b) for b in seg[1:-1]]


def main():
    print("n   stream order (body index per stream position)   relation to a mirror's descending read")
    for n in range(1, 13):
        s = stream_perm(n)
        rel = ("cancels" if s == list(range(n - 1, -1, -1))
               else "identity" if s == list(range(n)) else "neither")
        print("%-3d %-48s %s" % (n, s, rel))


if __name__ == "__main__":
    main()
