#!/usr/bin/env python3
"""p323 parity.py — find the artifact-parity RULE from the ORACLE, not from reasoning.

THE OPEN QUESTION (P3.22). Hue follows the parity of start_col + local_col. The vizier
derives correctly from CharX (197, odd). The princess needs ODD but CharX=120 is EVEN,
and P3.22 ruled out the geometric explanations: both cels trim with lead=0, both have
Fdx=0, both are 21 Apple px wide, so nothing width- or facing-based can move them
differently while the vizier still derives.

So this asks the machine instead. An oracle capture that contains the characters is the
ground truth (CLAUDE.md §2: trace over source). Each cel is converted at BOTH parities
and slid over the capture; the variant that matches, and where, gives the real
start_col — and the difference between the two characters' answers is the rule.

WHY THIS IS NOT THE TAUTOLOGY P3.22 SHIPPED. verify_room_chars.py compared the engine
against cels converted by the same command the engine's cels came from, so it could only
prove they agreed. Here the reference is an ORACLE CAPTURE — produced by the Apple II,
not by our converter — so a wrong conversion cannot match it.
"""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path("C:/Projects/POP3_port")
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "harness/tools"))
sys.path.insert(0, str(ROOT / "harness/tools/sprite_tool"))
from celio import Cel                                            # noqa: E402

STRIDE = 80
TABLE = ROOT / "oracle/source/01 POP Source/Images/IMG.CHTAB6.A"
CAP = ROOT / "build/assets/room_page1.raw"          # f4750: princess + vizier on screen

# (label, chtab6.A index, the CharX the source sets)
SUBJECTS = [("princess cel 11 -> A#25", 25, 120),
            ("vizier   cel 54 -> A#80", 80, 197)]


def convert(idx, start_col, flip, out):
    cmd = [sys.executable, str(ROOT / "harness/tools/sprite_convert.py"),
           "--table", str(TABLE), "--index", str(idx), "--out", str(out),
           "--label", "probe", "--start-col", str(start_col), "--quiet"]
    if flip:
        cmd.append("--flip-parity")
    subprocess.run(cmd, capture_output=True, check=True)
    return Cel(str(out))


def best_match(cel, cap):
    """Slide the cel over the capture; return (mismatches, row, col) for the best fit.

    Only OPAQUE cel pixels are compared — index 0 is transparent and the background
    shows through, so counting those would penalise every position equally.
    """
    best = None
    for top in range(88, 156 - cel.h):
        for col in range(0, 76 - cel.w):
            bad = 0
            for r in range(cel.h):
                px = cel.pixels[r]
                base = (top + r) * STRIDE + col
                for c in range(cel.w):
                    got = cap[base + c]
                    for k in range(4):
                        want = px[c * 4 + k]
                        if want == 0:
                            continue
                        sh = 6 - 2 * k
                        if ((got >> sh) & 3) != want:
                            bad += 1
                if best and bad > best[0]:
                    break
            if best is None or bad < best[0]:
                best = (bad, top, col)
    return best


def main():
    cap = CAP.read_bytes()
    HERE.mkdir(parents=True, exist_ok=True)
    print("=== matching each cel against the ORACLE capture %s ===" % CAP.name)
    print("  (opaque pixels only; lower = better; 0 = exact)")
    for label, idx, charx in SUBJECTS:
        print("\n  %s   (source CharX=%d, parity %s)"
              % (label, charx, "ODD" if charx & 1 else "EVEN"))
        for flip in (False, True):
            cel = convert(idx, charx, flip, HERE / ("probe_%d_%d.s" % (idx, flip)))
            bad, top, col = best_match(cel, cap)
            opaque = sum(1 for r in range(cel.h) for v in cel.pixels[r] if v)
            eff = "as CharX" if not flip else "CharX + flip"
            print("    %-14s %dx%dB  best fit at row %3d col %2d : %4d of %4d opaque px wrong (%.1f%%)"
                  % (eff, cel.h, cel.w, top, col, bad, opaque, 100.0 * bad / max(opaque, 1)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
