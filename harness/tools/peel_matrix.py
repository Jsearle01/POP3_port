#!/usr/bin/env python3
"""peel_matrix.py — the peel's regression matrix (P3.30, promoted from P3.28's ablation).

Rationale, axes and the historical-coverage claim live in
harness/smoke/run_peel_matrix.sh — read that first; this file is the mechanism.

Each case rewrites the VM's demo sequence, rebuilds, runs the room test and asserts BOTH
zero wrong bytes AND capture-to-capture stability. Exit 1 if any case fails either.

It builds and runs the emulator per case, so it is slower than the other smoke tests and
is invoked explicitly rather than on every build. Run it whenever the draw, the peel, or
the VM's state handling changes -- which is exactly when the three historical bugs were
introduced.

BUILD FAILURES ARE FAILURES, NOT SILENCE. An earlier one-off version of this script did
not check build.bat's output, so a failed build left the previous binary in place and it
reported the PREVIOUS demo's result -- a green that meant "never built". A measurement
tool that cannot tell "no effect" from "not applied" reports them identically.
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path("C:/Projects/POP3_port")
CD = ROOT / "src/engine/char_draw.s"

# name -> the pri_demo body (cel bytes and SEQ_CHX pairs), all looping via goto
VARIANTS = {
    "A_cel-fixed_pos-fixed": ["11"],
    "B_cel-fixed_pos-every": ["11", "SEQ_CHX,4", "11", "SEQ_CHX,4",
                              "11", "SEQ_CHX,-4", "11", "SEQ_CHX,-4"],
    "C_cel-every_pos-fixed": ["11", "1", "11", "1"],
    "D_both-every_overlap": ["11", "SEQ_CHX,4", "1", "SEQ_CHX,4",
                             "11", "SEQ_CHX,-4", "1", "SEQ_CHX,-4"],
    # 28 px > the 24 px cel width, so old and new footprints are DISJOINT.
    # Negative delta with CharFace=-1 moves her RIGHT, away from the torch columns.
    "E_both-every_no-overlap": ["11", "SEQ_CHX,-28", "1", "SEQ_CHX,28"],
}


def pin_vizier(t):
    """Hold the vizier on Vstand for the duration of the matrix.

    THE MATRIX VARIES ONE THING (P3.31). Since the walk landed, the shipped demo has the
    vizier crossing the room and eventually standing on top of the princess -- and two
    characters whose footprints overlap break the peel in a way that has nothing to do
    with these axes (it is its own defect, reported separately). Leaving him walking
    would make every case report that instead of what it is testing, which is the
    difference between a matrix and a scene.
    """
    lo = t.index("viz_demo        fcb")
    hi = t.index("* --- the VM's cel-id table")
    return t[:lo] + "viz_demo        fcb     54\n                fcb     SEQ_GOTO\n" \
                    "                fdb     viz_demo\n\n" + t[hi:]


def set_demo(body):
    t = pin_vizier(CD.read_text(encoding='utf-8'))
    start = t.index("\npri_demo") + 1   # label alone; the harness rewrites the body
    # The marker is a comment line in char_draw.s; it is named there too. If it moves,
    # this raises rather than silently rewriting the wrong span.
    end = t.index("* --- the vizier's sequence")
    new = "pri_demo\n"
    for item in body:
        new += "                fcb     %s\n" % item
    new += "                fcb     SEQ_GOTO\n                fdb     pri_demo\n\n"
    CD.write_text(t[:start] + new + t[end:], encoding='utf-8')


def build():
    r = subprocess.run(["cmd.exe", "/c", "cd /d C:\\Projects\\POP3_port && "
                        "C:\\Projects\\POP3_port\\build.bat"],
                       capture_output=True, text=True)
    if re.search(r"ERROR", r.stdout or "", re.I):
        return [l for l in (r.stdout or "").splitlines() if "ERROR" in l.upper()][:1]
    return None


def run():
    err = build()
    if err:
        return None, err
    pos = ROOT / "build/room_chars_pos.txt"
    if pos.exists():
        pos.unlink()
    subprocess.run(["bash", "harness/smoke/run_room_test.sh"], cwd=str(ROOT),
                   capture_output=True, text=True)
    v = subprocess.run([sys.executable, "harness/tools/verify_room_chars.py"],
                       cwd=str(ROOT), capture_output=True, text=True)
    return v.stdout, None


def main():
    orig = CD.read_text(encoding='utf-8')
    bad = []
    print("=== peel regression matrix ===")
    print("  %-26s %-10s %-10s %s" % ("variant", "capture 1", "capture 2", "stability"))
    try:
        for name, body in VARIANTS.items():
            set_demo(body)
            out, err = run()
            if err:
                print("  %-26s BUILD ERROR: %s" % (name, err[0][:50]))
                continue
            counts = re.findall(r"(\d+) bytes WRONG", out or "")
            stable = "agree" if "all captures agree" in (out or "") else "DISAGREE"
            c1 = counts[0] if len(counts) > 0 else "?"
            c2 = counts[1] if len(counts) > 1 else "?"
            ok = (c1 == "0" and c2 == "0" and stable == "agree")
            if not ok:
                bad.append(name)
            print("  %-26s %-10s %-10s %-9s %s"
                  % (name, c1, c2, stable, "" if ok else "<-- FAIL"))
    finally:
        CD.write_text(orig, encoding='utf-8')
        # AND REBUILT. Restoring the source leaves build/ holding the LAST CASE's binary
        # -- a demo nobody asked for -- and the next thing to run a smoke test measures
        # that instead of the tree. It cost a set of memory-size runs in P3.31: the room
        # came up with the vizier pinned and case E's princess, and passed, which is the
        # same "reports the previous build" hazard this file's header warns about, seen
        # from the other end.
        print("\n  (char_draw.s restored; rebuilding so build/ matches the tree)")
        run()
    if bad:
        print("  FAILED: %s" % ", ".join(bad))
        print("  A case that is 0 at one capture and non-zero at the other is the")
        print("  ACCUMULATING signature -- diagnose, do not re-run hoping.")
        return 1
    print("  all cases 0 wrong and stable across separated captures")
    return 0


if __name__ == "__main__":
    sys.exit(main())
