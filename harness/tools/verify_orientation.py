#!/usr/bin/env python3
"""
verify_orientation.py — assert a converted cel's VERTICAL ORIENTATION against the
POP source cel, not against itself.

WHY THIS EXISTS (the blind spot it closes)
------------------------------------------
P1.2's colour spot-check compared the CoCo3 framebuffer to the converter's output
and passed, 1152/1152 pixels — while every cel was upside down. It could not have
caught it: both sides of that comparison are downstream of the same converter, so a
consistent flip round-trips perfectly. **Self-consistency is necessary and not
sufficient.** Jay's eye caught what the byte-check structurally could not.

This guard compares against an INDEPENDENT quantity: the original POP cel binary in
oracle/source/.../IMG.CHTAB*, plus the row-order semantics the Apple blitter itself
defines.

THE GROUND TRUTH — POP cel rows are stored BOTTOM-ROW-FIRST
-----------------------------------------------------------
Three independent code sites in HIRES.S (not comments — code):
  1. PREPREP  : IMAGE += 2 past the [width][height] header, so IMAGE points at
                DATA ROW 0 when drawing begins.
  2. CROP     : TOPEDGE = YCO - HEIGHT, with YCO the "Y-coord of lowest visible
                line of image" — i.e. YCO is the BOTTOM scanline.
  3. draw loop: "Next line up" — IMAGE += WIDTH advances the source FORWARD while
                DEC YCO walks the destination UP, terminating at TOPEDGE.
  => data row 0   is drawn at the BOTTOM scanline.
  => data row h-1 is drawn at the TOP scanline.
(The HIRES.S:187 comment "read left-right, top-bottom" describes sequential storage;
read as visual orientation it contradicts all three sites. CLAUDE.md §2 ranks
comments lowest — the code wins.)

converted.s is a TOP-FIRST format (row 0 renders at the top: both POP render paths —
sprite_tool/render.py and src/harness/cel_probe.s — map row 0 to the top, verified).
So the correct converted.s is the ROW-REVERSE of a straight POP-order conversion.

WHAT THIS CHECKS
----------------
Re-derives the conversion from the ORIGINAL cel binary using the colour model as a
black box, WITHOUT the converter's row loop, and asserts:
      converted.s row r  ==  straight_conversion row (h-1-r)     for every r
It therefore fails if the flip is dropped, doubled, or partially applied.

WHAT IT DOES NOT CHECK: that the ground truth above is itself right. That rests on
the three code sites and, finally, on Jay's eye (CLAUDE.md §4) — orientation is a
visual property and this project does not self-certify those.

Usage:  python harness/tools/verify_orientation.py <cel_dir> [<cel_dir> ...]
        python harness/tools/verify_orientation.py --all content
Exit:   0 = all correctly oriented, 1 = a flip/regression detected
"""
import sys
import re
import pathlib
import argparse

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "sprite_tool"))

from sprite_convert import load_chtable, convert_sprite_to_coco3
from celio import Cel

IMAGES = ROOT / "oracle" / "source" / "01 POP Source" / "Images"


def origin_of(cel_dir):
    """Parse `* ORIGIN: <table>` and `* POP cel: #<n>` from the converted.s header."""
    txt = (pathlib.Path(cel_dir) / "converted.s").read_text(encoding="utf-8", errors="replace")
    tab = re.search(r'^\*\s*ORIGIN:\s*(\S+)', txt, re.M)
    idx = re.search(r'^\*\s*POP cel:\s*#(\d+)', txt, re.M)
    if not (tab and idx):
        return None, None
    return tab.group(1), int(idx.group(1))


def straight_rows(table, index, start_col=0):
    """Convert the POP cel in ITS OWN data order (no flip), returning packed rows.

    Deliberately does NOT call sprite_convert.convert_one — reusing the converter's
    row loop would make this circular. The colour model is used as a black box.
    """
    cels = load_chtable(IMAGES / table)
    cel = cels[index - 1]
    h, w = cel["h"], cel["w"]
    bmp, cw = convert_sprite_to_coco3(cel["data"], h, w, start_col)
    return [list(bmp[r * cw : (r + 1) * cw]) for r in range(h)], cw


def trim_cols(rows):
    """Apply the converter's leading/trailing all-zero byte-column trim.
    Column-only: it cannot affect row ORDER, so it is safe to mirror here."""
    if not rows or not rows[0]:
        return rows
    w = len(rows[0])
    has = [any(r[c] for r in rows) for c in range(w)]
    if not any(has):
        return rows
    L = next(i for i in range(w) if has[i])
    R = next(i for i in range(w - 1, -1, -1) if has[i])
    return [r[L:R + 1] for r in rows]


def check(cel_dir, verbose=True):
    d = pathlib.Path(cel_dir)
    table, index = origin_of(d)
    if not table:
        if verbose:
            print(f"  {d.name:<30} SKIP  (no ORIGIN header — not a converted POP cel)")
        return None

    cel = Cel(str(d / "converted.s"))
    on_disk = [cel.row_bytes(r) for r in range(cel.h)]

    straight, _ = straight_rows(table, index)
    straight = trim_cols(straight)

    if len(straight) != len(on_disk):
        if verbose:
            print(f"  {d.name:<30} FAIL  height {len(on_disk)} vs source {len(straight)}")
        return False

    want_flipped = straight[::-1]                    # the CORRECT orientation
    ok_flipped = (on_disk == want_flipped)
    ok_straight = (on_disk == straight)               # the WRONG (unflipped) orientation

    if verbose:
        if ok_flipped and not ok_straight:
            print(f"  {d.name:<30} PASS  {cel.h}x{cel.w}B  row 0 == source row {cel.h-1} (top-first) ")
        elif ok_straight and not ok_flipped:
            print(f"  {d.name:<30} FAIL  UPSIDE DOWN — row 0 == source row 0 (POP's BOTTOM row)")
        elif ok_flipped and ok_straight:
            print(f"  {d.name:<30} PASS* {cel.h}x{cel.w}B  vertically symmetric — flip undetectable")
        else:
            bad = next((r for r in range(cel.h) if on_disk[r] != want_flipped[r]), None)
            print(f"  {d.name:<30} FAIL  matches neither orientation; first bad row {bad}")
    return ok_flipped


def main():
    ap = argparse.ArgumentParser(description="Assert converted-cel vertical orientation vs POP source")
    ap.add_argument("paths", nargs="+", help="cel dir(s), or a content root with --all")
    ap.add_argument("--all", action="store_true", help="walk <path>/*/*/converted.s")
    args = ap.parse_args()

    dirs = []
    for p in args.paths:
        if args.all:
            dirs += sorted(q.parent for q in pathlib.Path(p).glob("*/*/converted.s"))
        else:
            dirs.append(pathlib.Path(p))

    print(f"=== verify_orientation: {len(dirs)} cel(s) vs POP source row order ===")
    results = [check(d) for d in dirs]
    checked = [r for r in results if r is not None]
    bad = [r for r in checked if not r]
    print(f"\n  checked {len(checked)}, correctly oriented {len(checked)-len(bad)}, FLIPPED {len(bad)}")
    if bad:
        print("  VERDICT: ORIENTATION FAIL — converted cels are upside down vs the POP source.")
        return 1
    print("  VERDICT: ORIENTATION OK — every cel's row 0 is the POP cel's TOP row.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
