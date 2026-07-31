#!/usr/bin/env python3
"""bake_walk.py — bake the vizier's Vwalk cels for the runtime blitter (P3.30, piece E).

TWELVE cels, not six: each of Vwalk's frames is drawn at exactly TWO sub-byte phases.
That is a property of the animation data, derived here from the source rather than
assumed -- the sequence's chx deltas (2,6,1,-1,1,1) net +10 px per cycle, and
10 mod 4 = 2, so the cycle alternates between two phase sets forever.

    cels 48,49,50,52 -> phases {1,3}
    cels 51,53       -> phases {0,2}

PARITY IS PER CEL AND VARIES WITHIN THE WALK. 48/49/50/53 are ODD, 51/52 are EVEN
(ODD iff bit7(Fcheck) == bit7(CharFace); CharFace = -1 throughout the cutscene). A bulk
conversion at one parity per character would be wrong for a third of this cycle -- which
is exactly what P3.24 predicted and why the cel table carries parity per cel.

Every baked cel goes through cel_blit_prep's self-verifying replay, which reconstructs
the shifted bitmap over a hostile $B4 background and refuses to emit on a mismatch.
"""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path("C:/Projects/POP3_port")
sys.path.insert(0, str(ROOT / "harness/tools"))
import cel_parity_rule as R                                    # noqa: E402

TABLE = ROOT / "oracle/source/01 POP Source/Images/IMG.CHTAB6.A"
OUT = ROOT / "content/cutscene/chars"
CHARX = 197                       # startV0 [SUBS.S:1147]

# cel -> the two phases it is drawn at, derived from the walk's own deltas
PHASES = {48: (1, 3), 49: (1, 3), 50: (1, 3), 51: (0, 2), 52: (1, 3), 53: (0, 2)}


def main():
    alt = R.altset2()
    ok = fail = 0
    print("=== baking Vwalk: 6 cels x 2 phases ===")
    for cel in sorted(PHASES):
        fimg, fdx, fdy, fchk, lab = alt[cel]
        idx = fimg & 0x7F
        sc = R.draw_x(CHARX, fdx, fchk)          # a column of the correct PARITY
        src = OUT / ("vwalk%d_src.s" % cel)
        r = subprocess.run([sys.executable, str(ROOT / "harness/tools/sprite_convert.py"),
                            "--table", str(TABLE), "--index", str(idx),
                            "--out", str(src), "--label", "vwalk%d_src" % cel,
                            "--start-col", str(sc), "--quiet"],
                           capture_output=True, text=True)
        if r.returncode != 0:
            print("  cel %d: CONVERT FAILED %s" % (cel, (r.stderr or "")[:60]))
            fail += 1
            continue
        par = "ODD" if R.parity(fchk, R.FACE_LEFT) else "EVEN"
        for ph in PHASES[cel]:
            dst = OUT / ("vwalk%d_p%d.s" % (cel, ph))
            b = subprocess.run([sys.executable, str(ROOT / "harness/tools/cel_blit_prep.py"),
                                str(src), "--phase", str(ph),
                                "--label", "vwalk%d_p%d" % (cel, ph), "--out", str(dst)],
                               capture_output=True, text=True)
            good = "replay OK" in (b.stdout or "")
            print("  cel %-3d img %-4d %-5s start_col %-4d phase %d  %s"
                  % (cel, idx, par, sc, ph, "OK" if good else "REPLAY FAILED"))
            if good:
                ok += 1
            else:
                fail += 1
                print("      %s" % (b.stdout or b.stderr or "").strip()[:120])
    print("\n  %d baked, %d failed" % (ok, fail))
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
