#!/usr/bin/env python3
r"""xform_probe_check.py — P5.20: judge the probe's dumps against the generated reference.

CORRECTNESS FIRST (the dispatch's AC4 outranks AC5): every case's dump is compared byte for
byte with the reference framebuffer xform_probe_gen.py produced, and every differing PIXEL is
enumerated -- row, column, got, want -- rather than counted. A fast wrong blit is worth
nothing, and "close" is a known-occupied position (P5.11 measured the shipped mirror at three
silhouette pixels), so a near miss is reported as a miss.

COST SECOND: each case's cycles are the debugger's totalcycles bracket minus case 0's (the
same bracket around a bare `rts`). Per-byte figures divide by the cel's PHASE-0 FOOTPRINT,
ceil(7*apple_w/4) * h -- the unit P5.7's 1,922 B is stated in (coco3_bytes,
demo_asset_census.py:60) -- so a rate here multiplies against that figure without a units
change.

Writes <log>.json with every case's verdict and cycles, for xform_cost_summary.py.
"""
import argparse
import json
import sys

STRIDE = 80


def px(b, j):
    return (b >> (6 - 2 * j)) & 3


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cases", required=True)
    ap.add_argument("--log", required=True)
    ap.add_argument("--max-pixels", type=int, default=40, help="per case, before eliding")
    a = ap.parse_args()

    spec = json.load(open(a.cases))
    cases = spec["cases"]
    got = {}
    done = None
    for line in open(a.log):
        if line.startswith("C "):
            _, i, cyc, hx = line.split()
            got[int(i)] = (int(cyc), bytes.fromhex(hx))
        elif line.startswith("DONE"):
            done = int(line.split()[1])
    if done != len(cases):
        print("  FAIL the probe finished %s of %d cases" % (done, len(cases)))
        return 1
    calib = got[0][0]
    print("  calibration (bracket around a bare rts): %d cy" % calib)

    out, nbad = [], 0
    for i, c in enumerate(cases):
        if i == 0:
            continue
        cyc, dump = got[i]
        want = bytes(c["want"])
        diffs = []
        if len(dump) != len(want):
            diffs.append(("length", len(dump), len(want)))
        else:
            for o, (g, w) in enumerate(zip(dump, want)):
                if g != w:
                    for j in range(4):
                        if px(g, j) != px(w, j):
                            diffs.append((o // STRIDE - 1, (o % STRIDE) * 4 + j, px(g, j), px(w, j)))
        ok = not diffs
        nbad += 0 if ok else 1
        rec = dict(tag=c["tag"], f=c["f"], k=c["k"], mode=c["mode"], cyc=cyc - calib, ok=ok,
                   ndiff=len(diffs), a=c["a"], b=c["b"], nseg=c.get("nseg"), h=c["h"],
                   sbytes=c.get("sbytes"))
        out.append(rec)
        if not ok:
            print("  MISMATCH %s facing %d phase %d %s: %d pixel(s)" % (c["tag"], c["f"], c["k"], c["mode"], len(diffs)))
            for d in diffs[:a.max_pixels]:
                if d[0] == "length":
                    print("      dump length %d, want %d" % (d[1], d[2]))
                else:
                    print("      cel row %3d  screen px %3d  got %d  want %d" % d)
            if len(diffs) > a.max_pixels:
                print("      ... %d more" % (len(diffs) - a.max_pixels))

    metas = {m["tag"]: m for m in spec["cels"]}
    print()
    print("  %-22s %-2s %-2s  %8s %8s  %6s  %7s %7s" % ("cel", "f", "k", "base cy", "xform cy", "ratio",
                                                         "base/B", "xf/B"))
    by = {}
    for r in out:
        by.setdefault((r["tag"], r["f"], r["k"]), {})[r["mode"]] = r
    for (tag, f, k), m in sorted(by.items()):
        fp = metas[tag]["footprint"]
        b = m.get("base")
        x = m.get("xform")
        bc = b["cyc"] if b else None
        xc = x["cyc"] if x else None
        print("  %-22s %-2d %-2d  %8s %8s  %6s  %7s %7s%s" % (
            tag, f, k, bc if bc is not None else "-", xc if xc is not None else "-",
            ("%.2f" % (xc / bc)) if (bc and xc) else "-",
            ("%.1f" % (bc / fp)) if bc else "-", ("%.1f" % (xc / fp)) if xc else "-",
            "" if all(v["ok"] for v in m.values()) else "   <-- MISMATCH"))

    json.dump(dict(calib=calib, cels=spec["cels"], results=out), open(a.log + ".json", "w"))
    total = len(out)
    print()
    if nbad:
        print("  FAIL %d of %d cases differ from the reference" % (nbad, total))
        return 1
    print("  PASS all %d cases byte-exact against the generated reference" % total)
    return 0


if __name__ == "__main__":
    sys.exit(main())
