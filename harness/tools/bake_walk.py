#!/usr/bin/env python3
"""bake_walk.py — bake the vizier's Vwalk cels for the runtime blitter (P3.30, piece E).

TWELVE cels, not six: each of Vwalk's frames is drawn at exactly TWO sub-byte phases.
That is a property of the animation data -- the sequence's chx deltas net 10 px per
cycle and 10 mod 4 = 2, so the cycle alternates between two phase sets forever.

WHICH TWO PHASES IS NOT WRITTEN HERE, AND THAT IS THE POINT (P3.31). P3.30 hand-computed
them, baked twelve cels to the answer, and the answer was one delta out: `Vwalk db chx,1`
moves x from 197 to 196 BEFORE cel 48 is ever drawn, so every phase downstream shifted by
one and the set came out as the exact complement of the truth. Twelve cels at the wrong
phase build, link, load and draw -- they are simply the wrong pixels. So the phases now
come from walk_phases.py, which derives them from the oracle's sequence table and the
port's own co_setup expression; nothing in this file may disagree with the walk.

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
import walk_phases as W                                        # noqa: E402

TABLE = ROOT / "oracle/source/01 POP Source/Images/IMG.CHTAB6.A"
OUT = ROOT / "content/cutscene/chars"
CHARX = 197                       # startV0 [SUBS.S:1147]


PHASES = W.occupancy(W.port_plan())

# cel -> (source stem, convert it?). The walk's six each get their own conversion; the
# vizier's standing cel already has one from P3.22 and is reused rather than re-derived,
# because a second conversion of the same image at the same start_col is a second chance
# to differ from the file everything else already checks against.
STEMS = {48: ("vwalk48", True), 49: ("vwalk49", True), 50: ("vwalk50", True),
         51: ("vwalk51", True), 52: ("vwalk52", True), 53: ("vwalk53", True),
         54: ("vstand", False), 55: ("vstop55", True), 56: ("vstop56", True)}


def main():
    alt = R.altset2()
    ok = fail = 0
    print("=== baking Vwalk: 6 cels x 2 phases ===")
    for cel in sorted(PHASES):
        fimg, fdx, fdy, fchk, lab = alt[cel]
        idx = fimg & 0x7F
        sc = R.draw_x(CHARX, fdx, fchk)          # a column of the correct PARITY
        stem, convert = STEMS[cel]
        src = OUT / ("%s_src.s" % stem)
        if convert:
            r = subprocess.run([sys.executable, str(ROOT / "harness/tools/sprite_convert.py"),
                                "--table", str(TABLE), "--index", str(idx),
                                "--out", str(src), "--label", "%s_src" % stem,
                                "--start-col", str(sc), "--quiet"],
                               capture_output=True, text=True)
            if r.returncode != 0:
                print("  cel %d: CONVERT FAILED %s" % (cel, (r.stderr or "")[:60]))
                fail += 1
                continue
        elif not src.exists():
            print("  cel %d: %s is missing and this cel is not re-converted" % (cel, src))
            fail += 1
            continue
        par = "ODD" if R.parity(fchk, R.FACE_LEFT) else "EVEN"
        for ph in PHASES[cel]:
            dst = OUT / ("%s_p%d.s" % (stem, ph))
            b = subprocess.run([sys.executable, str(ROOT / "harness/tools/cel_blit_prep.py"),
                                str(src), "--phase", str(ph),
                                "--label", "%s_p%d" % (stem, ph), "--out", str(dst)],
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
    if not fail:
        emit_table()
    return 1 if fail else 0


def emit_table():
    """The engine's side of the same fact: WHICH baked cel serves WHICH phase.

    Generated rather than hand-written because a lookup table and a bake that disagree
    is a silent wrong-pixel bug -- the table would point at a cel that exists and is
    the wrong shift. Four slots per cel so the lookup is an index rather than a search;
    the two phases the walk never visits hold 0, which co_variant treats as "fall back
    to the record's own pointer" rather than blitting from address 0.
    """
    out = OUT / "walk_baked.s"
    lo, hi = min(PHASES), max(PHASES)
    L = ["* walk_baked.s " + chr(0x2014) + " the Vwalk bake, and the phase lookup over it.",
         "* GENERATED by harness/tools/bake_walk.py " + chr(0x2014) + " do not hand-edit.",
         "*",
         "* Phases are derived by walk_phases.py from the oracle's sequence table and the",
         "* port's own co_setup expression; see that file for why they are not written by hand.",
         "*"]
    for cel in sorted(PHASES):
        L.append("*   cel %d -> phases {%s}"
                 % (cel, ",".join(str(p) for p in PHASES[cel])))
    L.append("")
    for cel in sorted(PHASES):
        for ph in PHASES[cel]:
            L.append('                include "content/cutscene/chars/%s_p%d.s"'
                     % (STEMS[cel][0], ph))
    L += ["",
          "WALK_LO         equ     %d" % lo,
          "WALK_N          equ     %d" % (hi - lo + 1),
          "walk_tab"]
    for cel in range(lo, hi + 1):
        row = ["%s_p%d" % (STEMS[cel][0], p) if p in PHASES.get(cel, ()) else "0"
               for p in range(4)]
        L.append("                fdb     " + ",".join(row))

    # THE SCENE SCRIPT COMES FROM THE SAME DERIVATION AS THE PHASES, because it IS the
    # same fact: which sequence runs for how many steps is what decides the positions,
    # and the positions are what decide the phases. Written by hand in one place and
    # derived in the other, they would drift, and the symptom would be a cel drawn at a
    # phase nobody baked.
    seqlab = {"Vwalk": "viz_walk", "Vstop": "viz_stop", "Vstand": "viz_stand"}
    L += ["",
          "* the vizier's scene script: (sequence, plays), from PlayCut0 [SUBS.S].",
          "* A count of 0 means the sequence holds and the script is finished.",
          "viz_script"]
    for seq, n in W.port_plan()[:-1]:
        L.append("                fdb     %s" % seqlab[seq])
        L.append("                fcb     %d" % n)
    L += ["                fdb     %s" % seqlab[W.port_plan()[-1][0]],
          "                fcb     0"]
    out.write_text("\n".join(L) + "\n", encoding="utf-8")
    print("  %s: %d cels, WALK_LO %d WALK_N %d"
          % (out.name, sum(len(p) for p in PHASES.values()), lo, hi - lo + 1))


if __name__ == "__main__":
    sys.exit(main())
