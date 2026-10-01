#!/usr/bin/env python3
r"""xform_cost_summary.py — P5.20: the three figures, measured, and what they cost a step.

Reads every build/xform/b*.log.json (xform_probe_check.py's verdicts) and classifies each
TRANSFORMED case by what the 6809 actually did, which is not always the label the case was
generated under: a mirrored draw lands at runtime phase (k - pad) mod 4, so a "facing 1,
phase 0" reference can be a JOINT draw and a "facing 1, phase 1" one a pure mirror.

    shift alone   facing 0, runtime phase 1-3        (xf_blit ascending)
    mirror alone  facing 1, runtime phase 0          (xf_blit's xm0 path)
    joint         facing 1, runtime phase 1-3        (xf_blit descending)

Each class is measured DIRECTLY -- the joint figure is the joint cases' own cycles, never
shift + mirror (§5.260: that sum agreed with a joint figure by arithmetic luck).

Rates divide by the phase-0 footprint, ceil(7*apple_w/4)*h -- P5.7's unit -- and are
footprint-WEIGHTED (sum of cycles over sum of bytes), so a large cel counts for its size.
The baseline is the shipped blit_cel_full drawing the BAKED stream of the same pose: what
drawing that frame costs today.
"""
import argparse
import glob
import json

CLOCK_HZ = 894886 * 2        # mame -listxml coco3 maincpu clock, x2 for $FFD9 (idioms §0)
# P5.2, measured on the running oracle: 266 game frames over 1,681 apple2e display frames,
# and apple2e refreshes at 60.000000 Hz (idioms §10). Wall time per game frame, at the port's
# clock, is the step -- the feel the port has to match.
FPS = 266 / (1681 / 60.0)
PEAK = 1922                  # P5.7 frame 9328: characters 1,828 + scenery 94
PEAK_CHARS = 1828


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--glob", default="build/xform/b*.log.json")
    a = ap.parse_args()

    res, metas, bad, n = [], {}, 0, 0
    for path in sorted(glob.glob(a.glob)):
        d = json.load(open(path))
        for m in d["cels"]:
            metas[m["tag"]] = m
        for r in d["results"]:
            res.append(r)
            n += 1
            bad += 0 if r["ok"] else 1
    base = {(r["tag"], r["f"], r["k"]): r for r in res if r["mode"] == "base"}

    cls = {"shift alone": [], "mirror alone": [], "joint": [], "identity": []}
    for r in res:
        if r["mode"] != "xform":
            continue
        mir = bool(r["b"] & 1)
        key = ("joint" if r["a"] else "mirror alone") if mir else ("shift alone" if r["a"] else "identity")
        cls[key].append(r)

    print("cases %d, mismatches %d, cels %d" % (n, bad, len(metas)))
    step = CLOCK_HZ / FPS
    print("animation step = %d Hz / %.3f fps = %.0f cy" % (CLOCK_HZ, FPS, step))
    print()
    print("%-13s %6s %10s %10s %9s %9s %7s   %s" % ("class", "cases", "xform cy", "base cy",
                                                    "xf cy/B", "base cy/B", "ratio", "1,922 B -> % of step"))
    rows = {}
    for name in ("shift alone", "mirror alone", "joint", "identity"):
        rs = cls[name]
        if not rs:
            continue
        fp = sum(metas[r["tag"]]["footprint"] for r in rs)
        xc = sum(r["cyc"] for r in rs)
        bc = sum(base[(r["tag"], r["f"], r["k"])]["cyc"] for r in rs if (r["tag"], r["f"], r["k"]) in base)
        xr, br = xc / fp, (bc / fp if bc else float("nan"))
        rows[name] = (xr, br)
        print("%-13s %6d %10d %10d %9.1f %9.1f %7.2f   %6.0f cy = %5.1f%%   (base %5.1f%%)" % (
            name, len(rs), xc, bc, xr, br, xc / bc if bc else float("nan"),
            xr * PEAK, 100 * xr * PEAK / step, 100 * br * PEAK / step))

    # the baked baseline over EVERY pose, both facings, all phases -- today's rate
    fp = sum(metas[r["tag"]]["footprint"] for r in base.values())
    bc = sum(r["cyc"] for r in base.values())
    if fp:
        print("%-13s %6d %10s %10d %9s %9.1f %7s   %6.0f cy = %5.1f%%" % (
            "baked (all)", len(base), "-", bc, "-", bc / fp, "-", bc / fp * PEAK, 100 * bc / fp * PEAK / step))

    # WHERE THE CYCLES GO: least squares over poses, cyc ~ a*segments + b*footprint + c*rows.
    # Plain normal equations -- no numpy on this toolchain, and a silent ImportError is how
    # this first ran and printed nothing.
    def fit(rs, nseg_of):
        X = [[nseg_of(r), metas[r["tag"]]["footprint"], r["h"]] for r in rs]
        y = [r["cyc"] for r in rs]
        A = [[sum(X[i][p] * X[i][q] for i in range(len(X))) for q in range(3)] for p in range(3)]
        v = [sum(X[i][p] * y[i] for i in range(len(X))) for p in range(3)]
        for c in range(3):                                   # Gauss-Jordan, 3x3
            piv = max(range(c, 3), key=lambda r: abs(A[r][c]))
            A[c], A[piv], v[c], v[piv] = A[piv], A[c], v[piv], v[c]
            for r in range(3):
                if r != c:
                    m = A[r][c] / A[c][c]
                    A[r] = [A[r][j] - m * A[c][j] for j in range(3)]
                    v[r] -= m * v[c]
        coef = [v[c] / A[c][c] for c in range(3)]
        pred = [sum(coef[j] * X[i][j] for j in range(3)) for i in range(len(X))]
        worst = max(abs(p - t) / t for p, t in zip(pred, y))
        return coef, worst
    print()
    coef, worst = fit(list(base.values()), lambda r: r["nseg"])
    print("baked fit   cyc ~ %6.1f/segment + %5.2f/footprint B + %5.1f/row   (worst pose off by %.1f%%)"
          % (coef[0], coef[1], coef[2], 100 * worst))
    xs = [r for r in res if r["mode"] == "xform" and (r["a"] or r["b"])]
    coef, worst = fit(xs, lambda r: r["nseg"])
    print("xform fit   cyc ~ %6.1f/segment + %5.2f/footprint B + %5.1f/row   (worst pose off by %.1f%%)"
          % (coef[0], coef[1], coef[2], 100 * worst))
    segs = sum(r["nseg"] for r in base.values())
    print("baked streams: %d segments over %d footprint B = %.2f segments/B"
          % (segs, sum(metas[r["tag"]]["footprint"] for r in base.values()), segs / fp))


if __name__ == "__main__":
    main()
