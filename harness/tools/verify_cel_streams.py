#!/usr/bin/env python3
r"""verify_cel_streams.py — every baked cel walked the way the 6809 walks it.

P3.85. cel_blit_prep replays each cel as it emits it, but that replay is a check on the
PIXELS. This is a check on the STREAM's shape: walked with the assembly's own decode, does
every cel consume exactly the bytes it occupies, no more and no less?

That is the failure a format change produces. A stream that ends one byte early leaves the
walker reading the NEXT cel's header as a segment, and the damage appears somewhere else
entirely — a wild blast count, a crash several beats later, nothing that points back here.

The packed header (P3.85) is one byte: opcode in the top two bits, count in the low six,
$00 = end of row. Decoded here exactly as bc_seg does it, so a disagreement between the
generator and the blitter shows up as a length mismatch rather than as a reset.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
CHARS = ROOT / "content/cutscene/chars"
SEG_MASK, SEG_OP = 0x3F, 0xC0
SEGP_SKIP, SEGP_BLAST, SEGP_MERGE = 0x40, 0x80, 0xC0


def stream(path):
    out = []
    for line in pathlib.Path(path).read_text(errors="replace").splitlines():
        s = line.split(";")[0]
        m = re.match(r"\s*fcb\s+(.*)$", s)
        if m:
            for x in m.group(1).split(","):
                x = x.strip()
                if x:
                    out.append((int(x[1:], 16) if x.startswith("$") else int(x, 0)) & 0xFF)
    return out


def walk(st):
    """-> (bytes_consumed, rows_seen, error) walking exactly as bc_seg does."""
    if len(st) < 2:
        return 0, 0, "shorter than a header"
    rows, width = st[0], st[1]
    i = 2
    for r in range(rows):
        cols = 0
        while True:
            if i >= len(st):
                return i, r, "ran off the end inside row %d" % r
            hdr = st[i]
            i += 1
            if hdr == 0:
                break
            op, n = hdr & SEG_OP, hdr & SEG_MASK
            if n == 0:
                return i, r, "row %d: header $%02X has a ZERO count" % (r, hdr)
            cols += n
            if op == SEGP_SKIP:
                pass
            elif op == SEGP_BLAST:
                i += n
            elif op == SEGP_MERGE:
                i += 2 * n
            else:
                return i, r, "row %d: opcode field $%02X is not a segment" % (r, op)
        if cols != width:
            return i, r, "row %d covers %d columns, width is %d" % (r, cols, width)
    return i, rows, None


def main():
    pack = CHARS / "cel_pack.json"
    labels = []
    if pack.exists():
        m = json.loads(pack.read_text(encoding="utf-8"))
        labels = [l for _v, l in m["resident"]]
        for g in m["pages"]:
            labels += [l for _v, l in g["cels"]]
    labels = sorted(set(labels))
    extra = sorted(p.stem for p in (ROOT / "build/flames_seg").glob("*.s"))

    bad = 0
    checked = 0
    for lab, base in ([(l, CHARS) for l in labels]
                      + [(l, ROOT / "build/flames_seg") for l in extra]):
        p = base / ("%s.s" % lab)
        if not p.exists():
            continue
        st = stream(p)
        used, rows, err = walk(st)
        checked += 1
        if err:
            bad += 1
            print("  FAIL %-12s %s" % (lab, err))
        elif used != len(st):
            bad += 1
            print("  FAIL %-12s walks %d bytes but the cel occupies %d — the blitter would "
                  "read the NEXT cel as a segment" % (lab, used, len(st)))
    if not checked:
        print("  FAIL no cels found to check")
        return 1
    if bad:
        print("  [cel-streams] %d of %d cels are malformed" % (bad, checked))
        return 1
    print("  [cel-streams] %d cels walk exactly to their own end" % checked)
    return 0


if __name__ == "__main__":
    sys.exit(main())
