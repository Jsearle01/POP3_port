#!/usr/bin/env python3
r"""parity_fail_shape.py — P5.29: does a probe run's failure set have the shape the diagnosis says?

Reads a prefix's case files and logs (build/xform/<pre>###_cases.json / .log.json) and sorts
every xform case into the class the colour-phase diagnosis predicts:

  facing 0 (unmirrored): the stored cel is coloured at EVEN; the oracle wants PL. With P5.20's
                         draw (no swap) a case FAILS iff PL = 1.
  facing 1 (mirrored):   P5.20's draw swaps iff 7*apple_w is even; the oracle wants a swap iff
                         PL (xform_probe_gen.cel_cases). A case FAILS iff (apple_w even) != PL.

A cel with no orange/blue pixel at all is unchanged by a swap and cannot fail either way, so a
class predicted to fail may hold some passes; a class predicted to PASS must hold NO failures --
one there means the diagnosis is wrong, and that is the line this tool exists to print.
"""
import argparse
import collections
import glob
import json
import sys


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pre", required=True)
    ap.add_argument("--draw", choices=("p520", "oracle"), default="p520")
    a = ap.parse_args()
    metas, res = {}, {}
    for p in sorted(glob.glob("build/xform/%s[0-9][0-9][0-9]_cases.json" % a.pre)):
        for m in json.load(open(p))["cels"]:
            metas[m["tag"]] = m
    for p in sorted(glob.glob("build/xform/%s[0-9][0-9][0-9].log.json" % a.pre)):
        for r in json.load(open(p))["results"]:
            res[(r["tag"], r["f"], r["k"], r["mode"])] = r
    tally = collections.Counter()
    bad_pass_class = []
    for (tag, f, k, mode), r in res.items():
        m = metas[tag]
        pl, aw = m.get("pl"), m["apple_w"]
        if mode != "xform":
            tally[("base", "-", r["ok"])] += 1
            continue
        if a.draw == "p520":
            predict_fail = (pl == 1) if f == 0 else ((aw % 2 == 0) != (pl == 1))
        else:
            predict_fail = False
        cls = "f%d PL%s aw%s -> %s" % (f, pl, "even" if aw % 2 == 0 else "odd",
                                      "FAIL predicted" if predict_fail else "pass predicted")
        tally[(cls, predict_fail, r["ok"])] += 1
        if not predict_fail and not r["ok"]:
            bad_pass_class.append((tag, f, k))
    total = len(res)
    fails = sum(1 for r in res.values() if not r["ok"])
    print("prefix %s (draw=%s): %d cases, %d FAIL, %d pass" % (a.pre, a.draw, total, fails, total - fails))
    print("  %-40s %8s %8s" % ("class", "fail", "pass"))
    classes = sorted({c for c, _, _ in tally})
    for c in classes:
        nf = sum(v for (cc, _, ok), v in tally.items() if cc == c and not ok)
        np = sum(v for (cc, _, ok), v in tally.items() if cc == c and ok)
        print("  %-40s %8d %8d" % (c, nf, np))
    units = collections.Counter((m.get("pl"), m["apple_w"] % 2) for m in metas.values())
    print("  units by (PL, apple_w odd): %s" % dict(units))
    if bad_pass_class:
        print("  ★ %d FAILURE(S) WHERE THE DIAGNOSIS PREDICTS A PASS -- first: %r" % (len(bad_pass_class), bad_pass_class[:5]))
        return 2
    print("  every failure lies in a class the diagnosis predicts to fail")
    return 0


if __name__ == "__main__":
    sys.exit(main())
