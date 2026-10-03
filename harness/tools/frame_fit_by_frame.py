#!/usr/bin/env python3
r"""frame_fit_by_frame.py — P5.21: the port's draw + peel of EACH oracle game frame, against the
time the ORACLE itself spent on that frame.

WHY NOT THE MEAN STEP. 188,509 cy is the MEAN game frame (P5.2: 266 frames over 1,681 display
frames). The oracle's own game frames range from 3 to 13 display frames, and the heavy ones are
the long ones (oracle_step_analysis.py). A port that takes as long as the oracle on the frames
where the oracle is slow plays at the oracle's own pace there; comparing a PEAK frame against the
MEAN step demands more than the original does.

For every game frame in P5.2's span, from oracle_step_trace.lua:
  * the character cels the oracle DREW (PREPREP's caller only -- GETWIDTH's size queries are not
    draws; see oracle_step_analysis.py), each with its phase and facing;
  * the port's measured cost of drawing that cel at that pose, baked or transformed (P5.20
    census) plus saving and erasing its footprint (P5.21 peel census) -- same instrument;
  * the oracle's duration of that frame, in display frames at 60.0 Hz, converted to the port's
    cycles (1,789,772 Hz).

NOT IN THE PORT FIGURE: scenery, game logic, sound, the page flip, the clip. So this is a lower
bound on the port's frame, and the oracle's figure is everything the oracle did in that frame.

PHASE: P5.10's mapping, (XCO*7 + OFFSET + 20) mod 4 -- the 280-px Apple field centred in 320.
For a MIRRORED draw the recorded XCO is the pre-mirror anchor (LAYRSAVE subtracts WIDTH after
PREPREP), so the phase there is approximate; the per-phase cost spread is ~3% (P5.20 §1).
"""
import collections
import glob
import json
import pathlib
import statistics
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import frame_drawset as FD                                    # noqa: E402
import oracle_step_analysis as A                              # noqa: E402

PORT_HZ = 894886 * 2
STEP = PORT_HZ * (1681 / 60.0) / 266
TAG = {"IMG.CHTAB1": "chtab1", "IMG.CHTAB2": "chtab2", "IMG.CHTAB3": "chtab3",
       "IMG.CHTAB4.GD": "chtab4gd", "IMG.CHTAB5": "chtab5"}


def addr_to_index():
    out = {}
    for (bank, base), (_, _, fname) in FD.TABLES.items():
        if fname not in TAG:
            continue
        b = (FD.IMAGES / fname).read_bytes()
        for i in range(b[0]):
            ptr = b[1 + 2 * i] | (b[2 + 2 * i] << 8)
            if ptr:
                out[((bank, base), base + ptr - 0x6000)] = "c_%s_%d" % (TAG[fname], i + 1)
    return out


def main():
    draw = {}
    for p in glob.glob("build/xform/b[0-9][0-9][0-9].log.json"):
        for r in json.load(open(p))["results"]:
            draw[(r["tag"], r["f"], r["k"], r["mode"])] = r["cyc"]
    peel = {}
    for p in glob.glob("build/xform/p[0-9][0-9][0-9].log.json"):
        for r in json.load(open(p))["results"]:
            peel.setdefault(r["tag"], {})[r["mode"]] = r["cyc"]
    poses = {c["tag"]: c for c in json.load(open("build/xform/p_peel_poses.json"))}
    idx = addr_to_index()

    bins = A.parse(sys.argv[1] if len(sys.argv) > 1 else "build/tmp/oracle_step_trace.txt")
    prev = None
    for b in bins:
        b["dur"] = b["fn"] - prev if prev is not None else None
        prev = b["fn"]
    span = [b for b in bins if A.SPAN[0] <= b["fn"] <= A.SPAN[1] and b["dur"]]

    rows, unknown = [], collections.Counter()
    for b in span:
        ch, _ = A.one_draw_per_lay([d for d in b["draws"] if d[0] in A.CHAR_TABLES])
        cost = {"baked": 0, "xform": 0}
        nbytes = 0
        for key, addr, w, h, x, y, off, op in ch:
            tag = idx.get((key, addr))
            if tag is None or tag not in poses:
                unknown[tag] += 1
                continue
            f = 1 if op & 0x80 else 0
            k = (x * 7 + off + 20) % 4
            i = f * 4 + k
            c = poses[tag]
            nbytes += c["footprint"]
            for model, mode, widths in (("baked", "base", c["peel_baked"]), ("xform", "xform", c["peel_xf"])):
                pk = peel["peel_h%d_w%d" % (c["h"], widths[i])]
                cost[model] += draw[(tag, f, k, mode)] + pk["save"] + pk["erase"]
        oracle_cy = b["dur"] / 60.0 * PORT_HZ
        rows.append(dict(fn=b["fn"], dur=b["dur"], B=nbytes, n=len(ch), oracle=oracle_cy,
                         baked=cost["baked"], xform=cost["xform"]))

    print("frames %d (span %d..%d); cels not in the census: %s" % (len(rows), A.SPAN[0], A.SPAN[1],
                                                                   dict(unknown) or "none"))
    print()
    for model in ("baked", "xform"):
        r_ = [r[model] / r["oracle"] for r in rows]
        over = [r for r in rows if r[model] > r["oracle"]]
        worst = max(rows, key=lambda r: r[model] / r["oracle"])
        heavy = max(rows, key=lambda r: r[model])
        print("%-6s port draw+peel / the oracle's own time for that frame:" % model)
        print("       median %.2f   p90 %.2f   max %.2f (frame %d: %d cy vs the oracle's %d frames = %d cy)"
              % (statistics.median(r_), sorted(r_)[int(0.9 * len(r_))], max(r_), worst["fn"],
                 worst[model], worst["dur"], worst["oracle"]))
        print("       frames where draw+peel alone exceeds the oracle's whole frame: %d of %d" % (len(over), len(rows)))
        print("       heaviest frame %d: %d B, %d cy = %.1f%% of the MEAN step, %.1f%% of its own oracle time"
              % (heavy["fn"], heavy["B"], heavy[model], 100 * heavy[model] / STEP,
                 100 * heavy[model] / heavy["oracle"]))
        tot_p, tot_o = sum(r[model] for r in rows), sum(r["oracle"] for r in rows)
        print("       whole span: draw+peel %d cy over the oracle's %d cy = %.1f%%"
              % (tot_p, tot_o, 100 * tot_p / tot_o))
        print()
    by = collections.defaultdict(list)
    for r in rows:
        by[r["dur"]].append(r)
    print("by the oracle's duration (display frames): n, mean drawn B, mean xform draw+peel as % of that time")
    for d in sorted(by):
        rs = by[d]
        print("   %2d  n=%3d  %5.0f B   baked %5.1f%%   xform %5.1f%%" % (
            d, len(rs), statistics.mean(r["B"] for r in rs),
            100 * statistics.mean(r["baked"] / r["oracle"] for r in rs),
            100 * statistics.mean(r["xform"] / r["oracle"] for r in rs)))


if __name__ == "__main__":
    main()
