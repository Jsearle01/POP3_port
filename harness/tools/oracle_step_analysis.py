#!/usr/bin/env python3
r"""oracle_step_analysis.py — P5.21: what the oracle's game frames actually draw and hold.

Input: oracle_step_trace.lua's log. Uses frame_drawset.py's EXACT filter (a record survives only
if its address is in that table's own pointer list and the live w/h equals the file's) and its
table map, so the populations are P5.2's.

THE CONTROL COMES FIRST. P5.7 put the joint peak at frame 9328 with characters 1,828 B (distinct,
coco3 bytes). If this run's bin at 9328 does not reproduce that, the frame numbers here are not
P5.2/P5.7's and nothing below may be compared with them.

  AC4    distinct vs drawn: does 1,922 B understate the draw volume?
  §1     how long the ORACLE takes over each game frame -- the step is a MEAN
  AC17   per-step hold rate per character, as a distribution
  AC18   both / exactly one / neither hold
  AC19   combat vs locomotion
"""
import collections
import pathlib
import statistics
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import frame_drawset as FD                                    # noqa: E402

SPAN = (7930, 9584)          # P5.2 §3: "gameplay span frames 7930..9584 (266 frames)"
# ★ ONLY ONE CALLER OF setimage DRAWS. HIRES.S has two: GETWIDTH [:287-301], a width/height QUERY
# that draws nothing, and PREPREP [:311-329], which LAY, LAYRSAVE and every MLAY variant call.
# Their return addresses were measured at $EF06 and $EF26 -- 32 bytes apart, exactly the code
# between the two `jsr setimage` -- and GETWIDTH precedes PREPREP in the source. The first cut of
# this analysis counted both and "found" a cel drawn twice in 261 of 266 frames; it was GETWIDTH.
PREPREP_RET = 0xEF26
GETWIDTH_RET = 0xEF06
CHAR_TABLES = {k for k, v in FD.TABLES.items() if v[1] != "tile"}
OPP = {k for k, v in FD.TABLES.items() if v[1] == "opponent"}


def parse(path):
    valid = FD.load_valid()
    bins = []
    for ln in pathlib.Path(path).read_text().splitlines():
        if not ln.startswith("F "):
            continue
        p = ln.split()
        fn = int(p[1])
        kid = bytes.fromhex(p[2][2:])
        shad = bytes.fromhex(p[3][2:])
        draws = []
        for r in p[4:]:
            if r == "-":
                continue
            bank, tb, addr, w, h, x, y, off, op, ret = r.split("/")
            if int(ret, 16) != PREPREP_RET:
                continue
            key = (int(bank), int(tb, 16))
            addr = int(addr, 16)
            wh = valid.get(key, {}).get(addr)
            if wh is None or wh != (int(w), int(h)):
                continue
            draws.append((key, addr, int(w), int(h), int(x), int(y), int(off), int(op, 16)))
        bins.append(dict(fn=fn, kid=kid, shad=shad, draws=draws))
    return bins


def one_draw_per_lay(draws):
    """LAYRSAVE and LAY both call setimage for ONE character draw [GRAFIX.S:731-734], so the tap
    sees each character record twice in a row. Collapse an exact consecutive repeat; report how
    many collapsed so the rule is visible, not assumed."""
    out, collapsed = [], 0
    for d in draws:
        # ★ A MIRRORED pair differs in OPACITY bit 7: LAY clears it before `jmp MLAY`
        # [HIRES.S:658-664], so the LAY record repeats the LAYRSAVE one with bit 7 off. Compared
        # with that bit masked, and the KEPT record is the first (it carries the mirror flag).
        if out and out[-1][:7] == d[:7] and (out[-1][7] & 0x7F) == (d[7] & 0x7F):
            collapsed += 1
            continue
        out.append(d)
    return out, collapsed


def state(rec):
    # Posn, X, Y, Face, Scrn, Sword -- what selects the cel, places it, mirrors it, and adds a sword
    return (rec[0], rec[1], rec[2], rec[3], rec[11], rec[14])


def pct(n, d):
    return "%5.1f%%" % (100.0 * n / d) if d else "  -  "


def main():
    bins = parse(sys.argv[1] if len(sys.argv) > 1 else "build/tmp/oracle_step_trace.txt")
    span = [b for b in bins if SPAN[0] <= b["fn"] <= SPAN[1]]
    # duration of each game frame = display frames since the previous boundary
    prev = None
    for b in bins:
        b["dur"] = b["fn"] - prev if prev is not None else None
        prev = b["fn"]

    print("bins logged %d; in P5.2's gameplay span %d..%d: %d" % (len(bins), SPAN[0], SPAN[1], len(span)))

    # ---------------- per-bin character volume ----------------
    tot_coll = 0
    for b in span:
        ch = [d for d in b["draws"] if d[0] in CHAR_TABLES]
        ch1, coll = one_draw_per_lay(ch)
        tot_coll += coll
        distinct = {(d[0], d[1]): d for d in ch1}
        b["distinct_B"] = sum(FD.coco3(d[2], d[3]) for d in distinct.values())
        b["drawn_B"] = sum(FD.coco3(d[2], d[3]) for d in ch1)
        b["n_distinct"], b["n_drawn"] = len(distinct), len(ch1)
        b["opp"] = any(d[0] in OPP for d in ch1)

    print("character records collapsed as layrsave+lay pairs: %d" % tot_coll)

    # ---------------- THE CONTROL ----------------
    c = [b for b in span if b["fn"] == 9328]
    print()
    if c:
        print("CONTROL frame 9328: characters distinct %d B (P5.7: 1,828)  drawn %d B  [%s]"
              % (c[0]["distinct_B"], c[0]["drawn_B"], "AGREES" if c[0]["distinct_B"] == 1828 else "DISAGREES"))
    else:
        print("CONTROL: no bin ends at 9328 -- bins near it: %s"
              % [b["fn"] for b in span if 9310 < b["fn"] < 9345])

    # ---------------- AC4 ----------------
    dup = [b for b in span if b["drawn_B"] != b["distinct_B"]]
    print()
    print("AC4  bins where a character cel is drawn more than once: %d of %d" % (len(dup), len(span)))
    print("     max distinct %d B   max drawn %d B   (frame of max drawn: %d)"
          % (max(b["distinct_B"] for b in span), max(b["drawn_B"] for b in span),
             max(span, key=lambda b: b["drawn_B"])["fn"]))
    for b in sorted(dup, key=lambda b: -(b["drawn_B"] - b["distinct_B"]))[:5]:
        print("     frame %d: distinct %d B, drawn %d B (+%d)" % (b["fn"], b["distinct_B"], b["drawn_B"],
                                                               b["drawn_B"] - b["distinct_B"]))

    # ---------------- the oracle's own step, per frame ----------------
    durs = [b["dur"] for b in span]
    print()
    print("ORACLE GAME-FRAME DURATION (display frames at 60 Hz), over the span:")
    print("     mean %.3f  (%d bins / %d frames)" % (statistics.mean(durs), len(durs), sum(durs)))
    print("     distribution %s" % dict(sorted(collections.Counter(durs).items())))
    heavy = sorted(span, key=lambda b: -b["distinct_B"])[:8]
    print("     the heaviest bins (distinct character B -> oracle duration):")
    for b in heavy:
        print("        frame %5d  %5d B  %d display frames" % (b["fn"], b["distinct_B"], b["dur"]))
    lo = [b["dur"] for b in span if b["distinct_B"] < 600]
    hi = [b["dur"] for b in span if b["distinct_B"] >= 1200]
    if lo and hi:
        print("     mean duration: < 600 B -> %.2f (%d bins);  >= 1,200 B -> %.2f (%d bins)"
              % (statistics.mean(lo), len(lo), statistics.mean(hi), len(hi)))

    # ---------------- AC17-19: holds ----------------
    def holds(seq, who, gate):
        """per step: does `who` hold (state unchanged AND drawn both steps)?"""
        res = []
        for a, b in zip(seq, seq[1:]):
            if not (gate(a) and gate(b)):
                res.append(None)
                continue
            res.append(state(a[who]) == state(b[who]))
        return res

    kid_vis = lambda b: True
    opp_vis = lambda b: b["opp"]
    k = holds(span, "kid", kid_vis)
    o = holds(span, "shad", opp_vis)
    print()
    for label, sel in (("ALL", lambda b: True), ("COMBAT (guard drawn)", lambda b: b["opp"]),
                       ("LOCOMOTION (no guard)", lambda b: not b["opp"])):
        idx = [i for i in range(len(k)) if sel(span[i + 1])]
        kk = [k[i] for i in idx if k[i] is not None]
        oo = [o[i] for i in idx if o[i] is not None]
        both = sum(1 for i in idx if k[i] and o[i])
        one = sum(1 for i in idx if (k[i] is not None and o[i] is not None) and (k[i] != o[i]))
        neither = sum(1 for i in idx if k[i] is False and o[i] is False)
        pairs = sum(1 for i in idx if k[i] is not None and o[i] is not None)
        print("%-24s steps %3d | kid holds %s of %d | guard holds %s of %d | "
              "both %s  exactly one %s  neither %s  (of %d steps with both on screen)"
              % (label, len(idx), pct(sum(kk), len(kk)), len(kk), pct(sum(oo), len(oo)), len(oo),
                 pct(both, pairs), pct(one, pairs), pct(neither, pairs), pairs))

    # runs: the DISTRIBUTION of hold lengths, not a mean (§5.233)
    def runs(v):
        out, n = [], 0
        for x in v:
            if x:
                n += 1
            elif n:
                out.append(n)
                n = 0
        if n:
            out.append(n)
        return dict(sorted(collections.Counter(out).items()))
    print()
    print("hold-run lengths (consecutive held steps -> count):")
    print("     kid   %s" % runs([x for x in k if x is not None]))
    print("     guard %s" % runs([x for x in o if x is not None]))

    # what changes when a character does NOT hold
    def why(who, gate):
        c = collections.Counter()
        for a, b in zip(span, span[1:]):
            if gate(a) and gate(b) and state(a[who]) != state(b[who]):
                names = [n for n, i in (("posn", 0), ("x", 1), ("y", 2), ("face", 3), ("scrn", 11), ("sword", 14))
                         if a[who][i] != b[who][i]]
                c["+".join(names)] += 1
        return dict(c.most_common(8))
    print()
    print("what changed on a non-hold:  kid %s" % why("kid", kid_vis))
    print("                             guard %s" % why("shad", opp_vis))
    faceonly = sum(1 for a, b in zip(span, span[1:])
                   for who in ("kid", "shad")
                   if a[who][3] != b[who][3] and a[who][0] == b[who][0] and a[who][1] == b[who][1])
    print("steps where a character TURNED with Posn and X unchanged: %d" % faceonly)


if __name__ == "__main__":
    main()
