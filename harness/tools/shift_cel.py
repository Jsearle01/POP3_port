#!/usr/bin/env python3
"""harness/tools/shift_cel.py — shift a converted cel right by N pixels, in 4-colour.

POP P3.52. Jay, on the live gate: the right-hand torch flame needs to move 1 px right.

WHY A TOOL RATHER THAN AN EDIT. `content/cutscene/flames/*/converted.s` are CONVERTED
ASSETS with a verifiable source origin (IMG.CHTAB6.A via the converter). Hand-shifting
them in place would make them ALTERED -- the state CLAUDE.md §2B exists to protect against,
and the one that cannot be reproduced from the source. This reads them, writes shifted
copies somewhere else, and never touches the originals. The shift therefore stays
reproducible from a command rather than living as an untracked edit in a data file.

THE ARITHMETIC. The mode is 320x192x4: 2 bits per pixel, 4 px per byte. Shifting one pixel
right is `>> 2` bits across the row treated as one big-endian value.

THE SPILL IS CHECKED, NOT ASSUMED. A right shift pushes the row's low bits out of its last
byte. If any row has those bits set, the cel would need an extra byte column -- which would
change the peel footprint, `PEEL_BYTES`, and the slot arithmetic with it. Measured across
the nine torch cels: every row's last byte has its low 2 bits clear, so the shift fits in
the existing width. This tool REFUSES rather than silently widening or truncating, because
a dropped pixel column is exactly the kind of loss that shows up three dispatches later as
"the flame looks wrong on one side".
"""
import argparse
import pathlib
import re
import shutil
import sys

ROW_RE = re.compile(r"^(\s*fcb\s+)(\$[0-9A-Fa-f]{2}(?:\s*,\s*\$[0-9A-Fa-f]{2})*)(\s*;.*)?$")


def shift_row(vals, px):
    """Shift a big-endian row right by px pixels (2 bits each). Returns (bytes, spilled)."""
    n = len(vals)
    acc = 0
    for v in vals:
        acc = (acc << 8) | v
    bits = 2 * px
    spilled = acc & ((1 << bits) - 1)
    acc >>= bits
    out = [(acc >> (8 * (n - 1 - i))) & 0xFF for i in range(n)]
    return out, spilled


def process(src_dir, dst_dir, px):
    src_dir, dst_dir = pathlib.Path(src_dir), pathlib.Path(dst_dir)
    conv = src_dir / "converted.s"
    if not conv.exists():
        return f"{src_dir}: no converted.s"
    dst_dir.mkdir(parents=True, exist_ok=True)

    lines = conv.read_text(encoding="utf-8", errors="replace").splitlines()
    out, rows, bad = [], 0, []
    for ln in lines:
        m = ROW_RE.match(ln)
        if not m:
            # Includes the `fcb 13,2` header, which is DECIMAL and so never matches
            # ROW_RE. An earlier version skipped "the first matching fcb" as the header
            # and silently dropped row 0 from the shift -- 12 rows of 13. The header is
            # excluded by the pattern, not by a counter.
            out.append(ln)
            continue
        vals = [int(x, 16) for x in re.findall(r"\$([0-9A-Fa-f]{2})", m.group(2))]
        rows += 1
        sh, spill = shift_row(vals, px)
        if spill:
            bad.append((rows, [f"${v:02X}" for v in vals], spill))
        body = ",".join(f"${v:02X}" for v in sh)
        out.append(f"{m.group(1)}{body}{m.group(3) or ''}")

    if bad:
        return (f"{src_dir.name}: REFUSED — {len(bad)} row(s) would lose pixels off the "
                f"right edge (first: row {bad[0][0]} {bad[0][1]})")

    (dst_dir / "converted.s").write_text("\n".join(out) + "\n", encoding="utf-8")
    op = src_dir / "opacity.s"
    if op.exists():
        shutil.copyfile(op, dst_dir / "opacity.s")   # opacity is unchanged by a shift
    return f"{src_dir.name}: {rows} rows shifted +{px}px"


def main():
    ap = argparse.ArgumentParser(description="shift a converted cel right by N px (4-colour)")
    ap.add_argument("dirs", nargs="+", help="cel directories containing converted.s")
    ap.add_argument("--px", type=int, default=1, help="pixels to shift right (default 1)")
    ap.add_argument("--out", required=True, help="destination root; <out>/<celname>/ is written")
    args = ap.parse_args()

    print(f"=== shift_cel: +{args.px}px right, {len(args.dirs)} cel(s) ===")
    rc = 0
    for d in args.dirs:
        d = pathlib.Path(d)
        msg = process(d, pathlib.Path(args.out) / d.name, args.px)
        print("  " + msg)
        if "REFUSED" in msg:
            rc = 1
    return rc


if __name__ == "__main__":
    sys.exit(main())
