#!/usr/bin/env python3
r"""frame_fit_summary.py — P5.21: draw + peel per footprint byte, both storage models, and the step.

Joins two censuses taken with the same instrument (the debugger's totalcycles, idioms §41):
  build/xform/b*.log.json   P5.20: the DRAW of every gameplay pose, baked and transformed
  build/xform/p*.log.json   P5.21: blit_save + blit_erase at every (rows, width) a pose needs
  build/xform/p_peel_poses.json  which (rows, width) each of a cel's eight poses peels, per model

Per cel, each model's cost is the mean over its eight poses (two facings x four phases, the
weighting P5.20 used), and the rate is footprint-WEIGHTED across cels (sum of cycles over sum of
phase-0 footprint bytes, P5.7's unit). The transformed model's facing-0 phase-0 pose is drawn by
blit_cel -- as built -- so its draw is the baked one.
"""
import glob
import json

CLOCK_HZ = 894886 * 2
STEP = CLOCK_HZ * (1681 / 60.0) / 266          # P5.2 -> 188,509 cy (P5.20 §3G)
PEAK = 1922


def main():
    draw = {}
    for p in glob.glob("build/xform/b[0-9][0-9][0-9].log.json"):
        for r in json.load(open(p))["results"]:
            draw[(r["tag"], r["f"], r["k"], r["mode"])] = r["cyc"]
    peel = {}
    for p in glob.glob("build/xform/p[0-9][0-9][0-9].log.json"):
        for r in json.load(open(p))["results"]:
            peel.setdefault(r["tag"], {})[r["mode"]] = r["cyc"]
    poses = json.load(open("build/xform/p_peel_poses.json"))

    tot = {m: dict(draw=0, save=0, erase=0) for m in ("baked", "xform")}
    fp_sum, rows_sum = 0, 0
    for c in poses:
        tag, h = c["tag"], c["h"]
        fp_sum += c["footprint"]
        rows_sum += h
        for model, widths in (("baked", c["peel_baked"]), ("xform", c["peel_xf"])):
            i = 0
            for f in (0, 1):
                for k in range(4):
                    pk = peel["peel_h%d_w%d" % (h, widths[i])]
                    tot[model]["save"] += pk["save"] / 8
                    tot[model]["erase"] += pk["erase"] / 8
                    mode = "base" if model == "baked" else "xform"
                    tot[model]["draw"] += draw[(tag, f, k, mode)] / 8
                    i += 1

    print("cels %d, footprint %d B, step %.0f cy, P5.7 peak %d B" % (len(poses), fp_sum, STEP, PEAK))
    print()
    print("%-7s %8s %8s %8s %8s %8s   %s" % ("model", "draw/B", "save/B", "erase/B", "peel/B",
                                             "total/B", "x1,922 B -> cycles = % of step"))
    for model in ("baked", "xform"):
        t = tot[model]
        d, s, e = t["draw"] / fp_sum, t["save"] / fp_sum, t["erase"] / fp_sum
        tt = d + s + e
        print("%-7s %8.1f %8.1f %8.1f %8.1f %8.1f   draw %6.0f (%5.1f%%)  peel %6.0f (%5.1f%%)  "
              "TOTAL %6.0f = %5.1f%%   peel/draw %.2f" % (
                  model, d, s, e, s + e, tt, d * PEAK, 100 * d * PEAK / STEP, (s + e) * PEAK,
                  100 * (s + e) * PEAK / STEP, tt * PEAK, 100 * tt * PEAK / STEP, (s + e) / d))

    # ---- WHERE THE PORT'S PEEL GOES: cyc ~ a*bytes + b*rows + c, least squares over pairs ----
    def fit(mode):
        pts = []
        for tag, m in peel.items():
            h, w = (int(v[1:]) for v in tag.split("_")[1:])
            pts.append((h * w, h, m[mode]))
        X = [[b, r, 1.0] for b, r, _ in pts]
        y = [c for _, _, c in pts]
        A = [[sum(x[p] * x[q] for x in X) for q in range(3)] for p in range(3)]
        v = [sum(X[i][p] * y[i] for i in range(len(X))) for p in range(3)]
        for c in range(3):
            piv = max(range(c, 3), key=lambda r: abs(A[r][c]))
            A[c], A[piv], v[c], v[piv] = A[piv], A[c], v[piv], v[c]
            for r in range(3):
                if r != c:
                    m_ = A[r][c] / A[c][c]
                    A[r] = [A[r][j] - m_ * A[c][j] for j in range(3)]
                    v[r] -= m_ * v[c]
        coef = [v[c] / A[c][c] for c in range(3)]
        worst = max(abs(coef[0] * b + coef[1] * r + coef[2] - cy) for b, r, cy in pts)
        return coef, worst
    print()
    for mode in ("save", "erase"):
        (a, b, c), worst = fit(mode)
        print("port %-5s cyc = %5.2f/byte + %6.1f/row + %5.1f/call   (worst pair off by %d cy, %d pairs)"
              % (mode, a, b, c, worst, len(peel)))

    # ---- THE ORACLE'S PEEL ON THE SAME CELS, counted off HIRES.S (6502 cycles) ----
    # LAYRSAVE :inloop  lda abs,y 4 / sta (zp),y 6 / dey 2 / bpl 3        = 15 per Apple byte
    #          per row  ~42  (YLO/YHI base, ldy, width add, dex/cpx/bne)
    # fastlaySTA :inloop lda (zp),y 5 / sta abs,y 5 / dey 2 / bpl 3       = 15 per Apple byte
    #          per row  ~41
    # Both cover WIDTH+1 Apple bytes (LAYRSAVE: "inc WIDTH ;extra byte to cover shift right").
    # Page-crossing (+1) and the per-call prologue (PREPREP, CROP, ADDPEEL, the SNGPEEL list walk)
    # are NOT counted, so this is a LOWER bound on the oracle's peel.
    ORACLE_HZ = 1021800                          # apple2e maincpu, mame -listxml apple2e (measured
    #                                              P5.21; 1,022,727 is the textbook figure, not MAME's)
    o_step = ORACLE_HZ * (1681 / 60.0) / 266
    o_cyc = sum((15 * (c["apple_w"] + 1) + 42) * c["h"] + (15 * (c["apple_w"] + 1) + 41) * c["h"]
                for c in poses)
    o_rate = o_cyc / fp_sum
    print()
    print("oracle peel (lower bound): %.1f 6502-cy per footprint B  x1,922 B = %.0f cy = %.1f%% of its "
          "%.0f cy step" % (o_rate, o_rate * PEAK, 100 * o_rate * PEAK / o_step, o_step))
    xp = (tot["xform"]["save"] + tot["xform"]["erase"]) / fp_sum
    print("port peel: %.1f 6809-cy per footprint B = %.1f%% of its step.  In TIME per footprint B: "
          "oracle %.1f us, port %.1f us  (port/oracle %.2f)"
          % (xp, 100 * xp * PEAK / STEP, 1e6 * o_rate / ORACLE_HZ, 1e6 * xp / CLOCK_HZ,
             (xp / CLOCK_HZ) / (o_rate / ORACLE_HZ)))


if __name__ == "__main__":
    main()
