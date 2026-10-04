#!/usr/bin/env python3
r"""char_closure_set.py — P5.27: the 271-cel closure as a SET, and how it differs from the 290.

peak_residency.py prints the W-inf kid UNION guard closure as a count and a byte figure
("Winf ... union 61195 B (271 cels)") and never exposes the set itself. P5.27 has to choose
between baking that set and P5.20's 290 (every non-empty cel of CHTAB1/2/3/4.GD/5), so it needs
the members, not the count.

★ THIS DOES NOT REIMPLEMENT THE CLOSURE. It runs peak_residency.main() unchanged and records
every set handed to Cels.bytes_of; the union line is the one set of 271 cels whose bytes are
61,195. Reimplementing the fixpoint here would be a second copy of the mechanism that could
drift from the one P5.9 reported -- the thing CLAUDE.md §2H's third check exists to catch.
If the closure ever changes size, the assertion below fails rather than returning a near miss.

Cels are (slot, image): slot 0..4 = IMG.CHTAB1/2/3/4.GD/5, image 1-based [seq_graph.Cels].

  python harness/tools/char_closure_set.py [--json OUT]
"""
import argparse
import contextlib
import io
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "sprite_tool"))

SLOT_FILE = {0: "IMG.CHTAB1", 1: "IMG.CHTAB2", 2: "IMG.CHTAB3", 3: "IMG.CHTAB4.GD", 4: "IMG.CHTAB5"}
WANT_N, WANT_B = 271, 61195      # P5.9 §3A, and peak_residency.py's own "Winf ... union" line


def closure():
    import seq_graph as SG
    import peak_residency as PR
    seen = []
    orig = SG.Cels.bytes_of

    def spy(self, cels):
        b = orig(self, cels)
        seen.append((len(cels), b, frozenset(cels)))
        return b

    SG.Cels.bytes_of = spy
    try:
        with contextlib.redirect_stdout(io.StringIO()):
            PR.main()
    finally:
        SG.Cels.bytes_of = orig
    hits = {s for n, b, s in seen if n == WANT_N and b == WANT_B}
    if len(hits) != 1:
        raise SystemExit("the W-inf union is not a unique %d-cel / %d B set (%d candidates)"
                         % (WANT_N, WANT_B, len(hits)))
    return next(iter(hits))


def all290():
    import sprite_convert as SC
    img = HERE.parents[1] / "oracle/source/01 POP Source/Images"
    out = set()
    for slot, name in SLOT_FILE.items():
        for c in SC.load_chtable(img / name):
            if c is not None and c["w"] and c["h"]:
                out.add((slot, c["idx"]))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", default=None)
    a = ap.parse_args()
    clo = closure()
    every = all290()
    only290 = sorted(every - clo)
    only271 = sorted(clo - every)
    print("closure (W-inf kid U guard): %d cels    all non-empty: %d cels" % (len(clo), len(every)))
    print("in the 290 and NOT the closure: %d" % len(only290))
    for s, i in only290:
        print("   %-14s #%d" % (SLOT_FILE[s], i))
    print("in the closure and NOT the 290: %d%s" % (len(only271), "" if not only271 else " %r" % only271))
    if a.json:
        pathlib.Path(a.json).write_text(json.dumps(dict(
            closure=sorted([SLOT_FILE[s], i] for s, i in clo),
            only_290=[[SLOT_FILE[s], i] for s, i in only290])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
