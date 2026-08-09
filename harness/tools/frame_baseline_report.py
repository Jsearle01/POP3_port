#!/usr/bin/env python3
"""harness/tools/frame_baseline_report.py — difference the ablation runs into a
decomposed, MEASURED frame baseline.

POP P3.43. The arc's verdicts all divide by P3.19's 19,652 cy model of the frame. This
turns five ablation runs (harness/tools/frame_baseline.lua) into the measured figure
that replaces it, and into per-component costs.

WHAT IT REFUSES TO DO. Each component's cost is a DIFFERENCE of two runs, and a
difference is only meaningful if the ablation actually happened. So every component is
gated on its own confirming evidence -- the ENTRY COUNT of the routine that was ablated,
recorded by a tap that knows nothing about the timing -- and one whose ablation did not take is reported
as UNCONFIRMED rather than as a number. A subtraction between two runs that did the same
work is noise with a plausible magnitude, which is the worst kind.
"""
import re
import sys

MODEL = 19652          # P3.19 / P3.37, never executed
BUDGET = 29673         # 29,859 less the 186 cy page flip — the tightest of P3.19's three
FRAME = 29859


def parse(path):
    runs, cur = {}, None
    for line in open(path, encoding="utf-8", errors="replace"):
        m = re.search(r"# FRAME BASELINE — mode=(\w+)", line)
        if m:
            cur = {"mode": m.group(1)}
            runs[cur["mode"]] = cur
            continue
        if cur is None:
            continue
        if "ABORTED" in line:
            cur["aborted"] = line.split("ABORTED:", 1)[1].strip()
        m = re.search(r"# RESULT mode=(\w+) work=(-?[\d.]+) cy/iter \(([\d.]+) frame budgets\)", line)
        if m:
            cur["work"] = float(m.group(2))
            cur["budgets"] = float(m.group(3))
        m = re.search(r"# (\d+) iterations\s+([\d.]+) frames/iter", line)
        if m:
            cur["iters"] = int(m.group(1))
            cur["frames"] = float(m.group(2))
        m = re.search(r"per iter: ([\d.]+)/([\d.]+)/([\d.]+)", line)
        if m:
            cur["save"] = float(m.group(1))
            cur["erase"] = float(m.group(2))
            cur["cel"] = float(m.group(3))
        m = re.search(r"# ENTRIES per iter: chars_frame=([\d.]+) flicker=([\d.]+)", line)
        if m:
            cur["e_chars"] = float(m.group(1))
            cur["e_flicker"] = float(m.group(2))
    return runs


def main():
    runs = parse(sys.argv[1] if len(sys.argv) > 1 else "build/frame_baseline.txt")
    if not runs:
        print("  no runs parsed — nothing to report")
        return 1

    print(f"  {'mode':<10} {'iters':>6} {'frames/iter':>12} {'work cy':>10} {'budgets':>8}"
          f" {'save':>6} {'erase':>6} {'cel':>6} {'chars':>7} {'flicker':>8}")
    for mode in ("full", "nopeel", "nochars", "noflicker", "neither"):
        r = runs.get(mode)
        if not r:
            print(f"  {mode:<10} MISSING")
            continue
        if r.get("aborted"):
            print(f"  {mode:<10} ABORTED — {r['aborted']}")
            continue
        print(f"  {mode:<10} {r.get('iters',0):>6} {r.get('frames',0):>12.3f}"
              f" {r.get('work',0):>10.0f} {r.get('budgets',0):>8.3f}"
              f" {r.get('save',0):>6.2f} {r.get('erase',0):>6.2f} {r.get('cel',0):>6.2f}"
              f" {r.get('e_chars',0):>7.2f} {r.get('e_flicker',0):>8.2f}")

    full = runs.get("full")
    if not full or "work" not in full:
        print("\n  the `full` run is missing or aborted — no decomposition is possible")
        return 1

    print()
    print(f"  MEASURED frame cost, nothing ablated : {full['work']:>9.0f} cy"
          f"  ({full['work']/BUDGET*100:.0f}% of the {BUDGET} budget)")
    print(f"  P3.19/P3.37 MODEL, never executed    : {MODEL:>9d} cy"
          f"  ({MODEL/BUDGET*100:.0f}%)")
    print(f"  ratio measured/model                 : {full['work']/MODEL:>9.2f}x")
    print(f"  assumption-free form                 : {full.get('frames',0):.3f} video frames per"
          f" iteration (a {MODEL/FRAME:.2f}-budget frame cannot take {full.get('frames',0):.2f})")

    # Each component is a difference, and each difference is gated on the evidence that
    # the ablation actually took -- recorded by a tap that knows nothing about the timing.
    print("\n  component costs, by difference (each gated on its own ablation evidence):")
    # Each gate is keyed on the ROUTINE THAT WAS ABLATED — its entry count must go to
    # zero — and on the one that was NOT, which must keep running. Keying on a downstream
    # primitive instead would require an argument about which caller reaches it, and the
    # first version of this gate got exactly that wrong: it demanded blit_cel fall to zero
    # under `nochars`, which the flicker path keeps non-zero for reasons of its own.
    comps = [
        ("peel (erase+save)", "nopeel",
         lambda r: r.get("save", 1) == 0 and r.get("erase", 1) == 0 and r.get("e_chars", 0) > 0,
         "save and erase blits must fall to 0 while chars_frame keeps running"),
        ("character path",   "nochars",
         lambda r: r.get("e_chars", 1) == 0 and r.get("e_flicker", 0) > 0,
         "chars_frame entries must fall to 0 while flicker keeps running"),
        ("flicker (torches)", "noflicker",
         lambda r: r.get("e_flicker", 1) == 0 and r.get("e_chars", 0) > 0,
         "flicker entries must fall to 0 while chars_frame keeps running"),
        ("chars + flicker",  "neither",
         lambda r: r.get("e_chars", 1) == 0 and r.get("e_flicker", 1) == 0,
         "both entry counts must fall to 0"),
    ]
    for label, mode, ok, why in comps:
        r = runs.get(mode)
        if not r or "work" not in r:
            print(f"    {label:<20} UNAVAILABLE ({mode} run missing or aborted)")
            continue
        delta = full["work"] - r["work"]
        if ok(r):
            print(f"    {label:<20} {delta:>9.0f} cy  ({delta/full['work']*100:5.1f}% of the frame)")
        else:
            print(f"    {label:<20} UNCONFIRMED — {why}; measured "
                  f"chars_frame={r.get('e_chars',0):.2f} flicker={r.get('e_flicker',0):.2f} "
                  f"save={r.get('save',0):.2f} erase={r.get('erase',0):.2f}")
            print(f"    {'':<20} (the {delta:.0f} cy difference is NOT reported as a cost)")

    rest = runs.get("neither")
    if rest and "work" in rest:
        print(f"\n    {'loop + swap + IRQ':<20} {rest['work']:>9.0f} cy  — what is left with both removed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
