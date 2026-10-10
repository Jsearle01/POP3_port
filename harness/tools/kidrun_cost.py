#!/usr/bin/env python3
r"""kidrun_cost.py — P5.31: the running kid's cost per animation step, against the ORACLE's time.

Reads build/kidrun_cycles.log (kidrun_cycles.lua: per step, cycles in each phase -- sequencer,
peel restore, save, draw, foreground -- off the built binary through the debugger's totalcycles).

THREE DENOMINATORS, kept apart (§5.324 is the entry for confusing them):
  * cycles per animation STEP -- what the port spent on one step;
  * the ORACLE's duration for the FRAME that step drew, in display frames, from P5.21's trace
    (build/tmp/oracle_step_trace.txt): frames 1..11 from the demo's own start of this run
    (display frames 7949..8008), frames 12..14 from every run cycle elsewhere in the trace --
    converted to port cycles at 1,789,772 Hz / 59.94 Hz = 29,859 per display frame;
  * the CADENCE, in fps: the port's fixed WK_SPEED against the oracle's per-frame durations.
"""
import collections
import pathlib
import re
import statistics
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
CY_PER_DISPLAY_FRAME = 1789772 / 59.94      # the port's clock over one NTSC field
SPEED = 6                                   # kidrun_plan.SPEED


def oracle_durations():
    """posn -> [display frames held], every run step (posn 1..14) in P5.21's trace."""
    tr = ROOT / "build/tmp/oracle_step_trace.txt"
    recs = []
    for line in tr.read_text().splitlines():
        m = re.match(r"^F (\d+) K=([0-9A-F]{2})", line)
        if m:
            recs.append((int(m.group(1)), int(m.group(2), 16)))
    out = collections.defaultdict(list)
    for (f0, p0), (f1, p1) in zip(recs, recs[1:]):
        if 1 <= p0 <= 14 and p1 != p0 and f1 > f0:
            out[p0].append(f1 - f0)
    return out


def main():
    log = ROOT / "build/kidrun_cycles.log"
    rows = []
    for line in log.read_text().splitlines():
        if line.startswith("S "):
            v = [int(x) for x in line.split()[1:]]
            rows.append(dict(step=v[0], frame=v[1], x=v[2], k=v[3], seq=v[4], erase=v[5],
                             save=v[6], draw=v[7], fore=v[8], total=v[9],
                             seen=v[10] if len(v) > 10 else None))
    if not rows:
        print("no steps in %s" % log)
        return 1
    od = oracle_durations()
    print("kidrun_cost: %d steps measured (debugger totalcycles; VBL IRQs inside a phase are in it)"
          % len(rows))
    print("  phase means, cycles per step:  seq %d  erase %d  save %d  draw %d  fore %d  = %d"
          % tuple(int(statistics.mean(r[p] for r in rows)) for p in ("seq", "erase", "save", "draw", "fore", "total")))
    print("  worst step: %d cy (step %d, frame %d)" % max((r["total"], r["step"], r["frame"]) for r in rows))
    print()
    print("  frame | port cy/step (mean) | oracle held (display frames, n) | oracle time in port cy | share")
    shares = []
    for f in range(1, 15):
        rs = [r["total"] for r in rows if r["frame"] == f]
        if not rs:
            continue
        held = od.get(f, [])
        m = statistics.mean(held) if held else None
        cy = m * CY_PER_DISPLAY_FRAME if m else None
        sh = statistics.mean(rs) / cy if cy else None
        if sh:
            shares.append(sh)
        print("   %2d   | %8d            | %s | %s | %s"
              % (f, statistics.mean(rs), ("%.2f (n=%d)" % (m, len(held))).ljust(31) if m else "-".ljust(31),
                 ("%9d" % cy).ljust(22) if cy else "-".ljust(22), "%.1f%%" % (100 * sh) if sh else "-"))
    print("  ★ mean share of the oracle's own time for the frames walked: %.1f%%  (max %.1f%%)"
          % (100 * statistics.mean(shares), 100 * max(shares)))
    allheld = [d for f in range(1, 15) for d in od.get(f, [])]
    o_fps = 60.0 / statistics.mean(allheld)
    first = [od[f][0] for f in range(1, 12) if od.get(f)]
    seen = [r["seen"] for r in rows if r["seen"] is not None]
    gaps = [b - a for a, b in zip(seen, seen[1:])]
    if gaps:
        mg = statistics.mean(gaps)
        print("  CADENCE, MEASURED: step-to-step %.2f display frames (min %d, max %d) = %.2f fps"
              % (mg, min(gaps), max(gaps), 59.94 / mg))
    print("  CADENCE: oracle, run frames 1..14 over the trace: mean %.2f display frames = %.2f fps "
          "(this run's frames 1..11: %s)" % (statistics.mean(allheld), o_fps, first))
    print("  budget at the port's own pace: %d display frames x %d cy = %d cy per step; worst step uses %.1f%%"
          % (SPEED, CY_PER_DISPLAY_FRAME, SPEED * CY_PER_DISPLAY_FRAME,
             100 * max(r["total"] for r in rows) / (SPEED * CY_PER_DISPLAY_FRAME)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
