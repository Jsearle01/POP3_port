#!/usr/bin/env python3
r"""engarde_cost.py — P5.37 AC14: the en-garde window's cost per GAME FRAME, against the MEASURED clock.

Reads build/engarde_cycles.log (kidrun_cycles.lua with run_engarde_cycles.sh's seven boundaries): per game
frame, cycles in  ai (guard_ai.s ga_frame: DoKid + DoShad, the logic) | place (the frame's row, position,
stream) | erase | save | draw | fore. The `# CLOCK` line is REQUIRED (P5.35: never assume the clock).

Denominators, kept apart:
  * the CLOCK, measured: cycles per real (display) frame;
  * the PACE: engarde_plan.SPEED display frames per game frame -- the budget a game frame has here;
  * the ORACLE: the display frames the oracle itself took for each of these game frames (engarde_expect.json,
    the F numbers of its records) -- the port's time as a share of the oracle's;
  * P5.35's baseline at the same clock: the kid run, one actor, 46,655 cy/step mean (58,551 worst).
"""
import json
import pathlib
import re
import statistics
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "harness/tools"))
import engarde_plan as EP                                   # noqa: E402

BASE_MEAN, BASE_WORST = 46655, 58551                        # P5.35 §3C, one actor, 1.79 MHz
CLOCKS = {"1.79 MHz (double speed, $FFD9)": 1789772 / 59.94, "0.89 MHz (normal speed)": 894886 / 59.94}
PH = ("ai", "place", "erase", "save", "draw", "fore")


def main():
    log = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "build/engarde_cycles.log"
    text = log.read_text()
    m = re.search(r"^# CLOCK ([\d.]+) cycles per real frame", text, re.M)
    if not m:
        raise SystemExit("engarde_cost: NO `# CLOCK` LINE in %s -- not measured, and not assumed (P5.35)" % log)
    clk = float(m.group(1))
    near = min(CLOCKS, key=lambda k: abs(CLOCKS[k] - clk))
    if abs(CLOCKS[near] - clk) / CLOCKS[near] > 0.02:
        raise SystemExit("engarde_cost: clock %.0f is within 2%% of neither SAM speed -- stop" % clk)
    rows = []
    for l in text.splitlines():
        if l.startswith("S "):
            v = [int(x) for x in l.split()[1:]]
            rows.append(dict(step=v[0], frame=v[1], x=v[2], k=v[3], **dict(zip(PH, v[4:10])), total=v[10],
                             seen=v[11]))
    rows = [r for r in rows if 1 <= r["step"] <= EP.GF1 - EP.GF0 + 1]
    if not rows:
        print("engarde_cost: no game frames in %s" % log)
        return 1
    exp = json.loads((ROOT / "build/gen/engarde_expect.json").read_text())
    df = exp["display_frame"]
    odur = [b - a for a, b in zip(df, df[1:])]              # oracle display frames per game frame (37 gaps)
    print("engarde_cost: CLOCK MEASURED %.0f cycles per real frame -- %s" % (clk, near))
    print("engarde_cost: %d game frames (%d..%d) measured; per-phase means, cycles:" % (
        len(rows), EP.GF0, EP.GF0 + len(rows) - 1))
    print("  " + "  ".join("%s %d" % (p, statistics.mean(r[p] for r in rows)) for p in PH)
          + "  = total %d" % statistics.mean(r["total"] for r in rows))
    ai = [r["ai"] for r in rows]
    print("  ★ THE LOGIC (ga_frame): mean %d, min %d, max %d cycles per game frame = %.1f%% of one display "
          "frame at the measured clock (max %.1f%%)" % (statistics.mean(ai), min(ai), max(ai),
                                                         100 * statistics.mean(ai) / clk, 100 * max(ai) / clk))
    hi = max(rows, key=lambda r: r["ai"])
    print("    heaviest: game frame %d (Posn %d) -- %d cycles" % (EP.GF0 + hi["step"] - 1, hi["frame"], hi["ai"]))
    tot = [r["total"] for r in rows]
    budget = EP.SPEED * clk
    print("  per game frame, everything: mean %d (worst %d) cycles = %.1f%% (worst %.1f%%) of the pace's budget "
          "(%d display frames x the clock)" % (statistics.mean(tot), max(tot), 100 * statistics.mean(tot) / budget,
                                               100 * max(tot) / budget, EP.SPEED))
    sh = [100 * r["total"] / (d * clk) for r, d in zip(rows, odur)]
    print("  as a share of the ORACLE's own time for each game frame (%s display frames): mean %.1f%%, max %.1f%%"
          % ("%d-%d" % (min(odur), max(odur)), statistics.mean(sh), max(sh)))
    print("  against P5.35's baseline (the kid run, one actor, same clock): %d mean / %d worst cy per step -- this "
          "window %d mean / %d worst; the logic is %.1f%% of the baseline's mean"
          % (BASE_MEAN, BASE_WORST, statistics.mean(tot), max(tot), 100 * statistics.mean(ai) / BASE_MEAN))
    seen = [r["seen"] for r in rows]
    gaps = [b - a for a, b in zip(seen, seen[1:])]
    if gaps:
        print("  CADENCE: %.2f display frames per game frame (min %d, max %d) -- the pace is %d"
              % (statistics.mean(gaps), min(gaps), max(gaps), EP.SPEED))
    return 0


if __name__ == "__main__":
    sys.exit(main())
