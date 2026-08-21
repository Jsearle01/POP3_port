#!/usr/bin/env python3
r"""peak_residency.py - P5.1. The PEAK, over a stated window. Not the sum.

Composes seq_graph.py (the intra-table graph, exact) with ctrl_edges.py (which frames reach a
controller, and what each controller can select) into the figure the cel-bank decision needs.

★★★ EVERY NUMBER HERE STATES WHAT IT IS A PEAK OF AND OVER WHAT WINDOW. That is the whole point
of the dispatch: P5.0 reported a SUM as a residency requirement, which is this project's
signature error at its sixth instance.

THE WINDOWS, and what each one assumes:

  W0  "mid-move"     The kid is inside a sequence and the controller cannot intervene, because
                     his current frame is not one of the 36 the GENCTRL dispatch answers
                     [CTRL.S:686-733]. Reachable = the intra-table closure over goto/ifwtless.
                     EXACT — no guard is unmodelled, because there is no guard.

  W1  "one decision" The controller fires once. Reachable = W0, plus for every control-active
                     frame in W0 the whole target set of the routine that frame dispatches to,
                     plus each of those targets' W0. UPPER BOUND within a routine: whether
                     `standing` actually picks DoStartrun depends on the joystick and on
                     `gotsword`/`EnemyAlert`, and those guards are not modelled.

  W2  "two decisions"  W1 iterated once more.

  Winv "involuntary"  The transitions the kid does not choose: a bump, a crush, a slice, a stab,
                     a fall. These fire from collision code, not from CharPosn, so they are
                     added at every window rather than gated on a frame.

WHAT IS EXCLUDED, AND ON WHAT AUTHORITY. Sequences 94-114 are the princess, the vizier and the
mouse [SEQDATA.S: Pstand=94 .. Mraise=114]. They are selected only by SUBS.S's `startP*`/
`startV*`/`startM*` and `PlayCut0`, i.e. by the CUTSCENE, and their frame numbers index altset2
for those characters [CTRLSUBS.S:1680 usealtsets, `cpx #5 / bcs :usealt2`]. Counting them into a
gameplay figure would charge the kid for cels he never draws. Both figures are printed so the
exclusion is visible rather than assumed.
"""
import pathlib
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "harness/tools"))

import seq_graph as SG                                                  # noqa: E402
import ctrl_edges as CE                                                 # noqa: E402

CUTSCENE_SEQS = set(range(94, 115))


def build():
    items, labels, entries = SG.parse_seqtable()
    names = SG.parse_seqdata()
    cels = SG.Cels("Fdef")

    # nodes + bodies
    bodies, frontier = {}, list(entries.values())
    node_set = set(frontier)
    while frontier:
        lab = frontier.pop()
        if lab in bodies:
            continue
        if lab not in labels:
            bodies[lab] = dict(frames=set(), acts=set(), out=[], cond=[], fell_off=True)
            continue
        b = SG.walk(items, labels, lab)
        bodies[lab] = b
        for t in b["out"] + b["cond"]:
            node_set.add(t)
            if t not in bodies:
                frontier.append(t)
    return items, labels, entries, names, cels, bodies


def main():
    items, labels, entries, names, cels, bodies = build()
    inv = {v: k for k, v in names.items()}

    # --- control machinery from ctrl_edges --------------------------------
    tgt, calls, sites, regs, _ = CE.scan(CE.SRC / "CTRL.S", names)
    routine_targets = {r: CE.closure_targets(r, tgt, calls)
                       for r in ("standing", "turning", "starting", "stjumpup",
                                 "arunning", "hanging", "crouching", "Stairs",
                                 "FightCtrl", "GuardCtrl")}

    involuntary = set()
    for path in sorted(CE.SRC.glob("*.S")):
        if path.name == "CTRL.S":
            continue
        t2, c2, s2, r2, _ = CE.scan(path, names)
        for r, ln, txt in s2:
            involuntary |= CE.closure_targets(r, t2, c2)
    # GENCTRL's dead-character path is in CTRL.S but is not frame-dispatched.
    involuntary |= CE.closure_targets("GENCTRL", tgt, calls) & {names["dropdead"]}

    def seq_label(n):
        return entries.get(n)

    def w0(nodes):
        """intra-table closure over a set of labels"""
        seen, cur = set(nodes), set(nodes)
        while cur:
            nxt = set()
            for n in cur:
                for t in bodies[n]["out"] + bodies[n]["cond"]:
                    if t not in seen:
                        nxt.add(t)
            seen |= nxt
            cur = nxt
        return seen

    def frames_of(nodes):
        f = set()
        for n in nodes:
            f |= bodies[n]["frames"]
        return f

    def cost(nodes):
        c = cels.cels(frames_of(nodes))
        return len(c), cels.bytes_of(c)

    def step(nodes, exclude_cutscene=True):
        """one control decision: add every routine reachable from a control-active frame."""
        out = set(nodes)
        for f in frames_of(nodes):
            r = CE.DISPATCH.get(f)
            if r:
                for s in routine_targets.get(r, ()):
                    if exclude_cutscene and s in CUTSCENE_SEQS:
                        continue
                    lab = seq_label(s)
                    if lab:
                        out.add(lab)
        # FightCtrl is entered on CharSword==2, not on a frame; treat it as available
        # whenever a fighting frame (150-189) is live.
        if any(150 <= f <= 189 for f in frames_of(nodes)):
            for s in routine_targets["FightCtrl"]:
                lab = seq_label(s)
                if lab:
                    out.add(lab)
        for s in involuntary:
            if exclude_cutscene and s in CUTSCENE_SEQS:
                continue
            lab = seq_label(s)
            if lab:
                out.add(lab)
        return w0(out)

    # ★ START NODES ARE THE KID'S OWN STATES. Sequences 94-114 are the princess, the
    # vizier and the mouse; a peak "at Pback" is not a fact about the kid. The set is the
    # intra-table closure of sequences 1..93, which is derived, not hand-picked.
    kid_seed = {entries[n] for n in range(1, 94) if n in entries}
    starts = sorted(w0(kid_seed))
    print("PEAK RESIDENCY — the kid, Fdef, CoCo3 4-colour packed bytes")
    print("  nodes in the graph: %d   (114 seqtab entries + goto/ifwtless targets)" % len(bodies))
    print()
    print("  %-34s %9s %9s %9s %s" % ("window", "max B", "median B", "min B", "worst-case node"))
    sets = {n: w0({n}) for n in starts}
    for tag, sets_now in (
            ("W0  mid-move (EXACT)", sets),
            ("W1  + one control decision", {n: step(v) for n, v in sets.items()}),
    ):
        vals = sorted((cost(v)[1], cost(v)[0], n) for n, v in sets_now.items())
        med = vals[len(vals) // 2]
        print("  %-34s %9d %9d %9d %s (%d cels)"
              % (tag, vals[-1][0], med[0], vals[0][0], vals[-1][2], vals[-1][1]))
        sets = sets_now
    sets2 = {n: step(v) for n, v in sets.items()}
    vals = sorted((cost(v)[1], cost(v)[0], n) for n, v in sets2.items())
    med = vals[len(vals) // 2]
    print("  %-34s %9d %9d %9d %s (%d cels)"
          % ("W2  + two control decisions", vals[-1][0], med[0], vals[0][0],
             vals[-1][2], vals[-1][1]))

    # fixpoint
    cur = {n: sets2[n] for n in starts}
    for _ in range(12):
        nxt = {n: step(v) for n, v in cur.items()}
        if all(nxt[n] == cur[n] for n in starts):
            break
        cur = nxt
    vals = sorted((cost(v)[1], cost(v)[0], n) for n, v in cur.items())
    print("  %-34s %9d %9d %9d %s (%d cels)"
          % ("Winf fixpoint (= the whole moveset)", vals[-1][0],
             vals[len(vals) // 2][0], vals[0][0], vals[-1][2], vals[-1][1]))

    # --- per-routine cost --------------------------------------------------
    print()
    print("THE COST OF BEING AT A CONTROL-ACTIVE FRAME — per dispatch routine")
    print("  (the routine's whole target set, each target's W0 closure, unioned)")
    for r in sorted(routine_targets):
        labs = set()
        for sq in routine_targets[r]:
            if sq in CUTSCENE_SEQS:
                continue
            lab = seq_label(sq)
            if lab:
                labs.add(lab)
        if not labs:
            continue
        n, b = cost(w0(labs))
        frames = sorted(f for f, rr in CE.DISPATCH.items() if rr == r)
        print("  %-10s %2d targets -> %3d cels %6d B   entered from frames %s"
              % (r, len(routine_targets[r]), n, b,
                 frames if frames else "(CharSword==2)" if r == "FightCtrl" else "(guard)"))

    # --- the hub -----------------------------------------------------------
    print()
    print("THE HUB. `standing` has %d targets; every other routine has 1 to 5."
          % len(routine_targets["standing"]))
    st = entries[names["stand"]]
    for tag, s in (("stand W0", w0({st})), ("stand W1", step(w0({st}))),
                   ("stand W2", step(step(w0({st}))))):
        n, b = cost(s)
        print("  %-10s %3d cels  %6d B" % (tag, n, b))

    peak_w1 = max(cost(v)[1] for v in sets.values())
    peak_w2 = max(cost(v)[1] for v in sets2.values())
    kid_sets = {"W0": {n: w0({n}) for n in starts}, "W1": sets, "W2": sets2, "Winf": cur}

    # --- THE GUARD, with its OWN frame->table mapping ----------------------
    # * P5.0's 9,350 B is a SUM over the 31 cels ALTSET1 names, and this dispatch's whole
    # subject is that a sum is not a peak. usealtsets [CTRLSUBS.S:1685-1707] gives the
    # enemy's mapping exactly: frames 150-189 -> ALTSET1 (index = frame-149); frames
    # 102-106 -> +70 -> 172-176 -> ALTSET1; EVERYTHING ELSE STILL COMES FROM Fdef, which
    # is the half P5.0's guard figure left out.
    alt = SG.Cels("ALTSET1")

    def guard_cost(nodes):
        c = set()
        for f in frames_of(nodes):
            g = f + 70 if 102 <= f <= 106 else f
            e = alt.cel_of(g) if 150 <= g <= 189 else cels.cel_of(g)
            if e:
                c.add(e)
        return len(c), cels.bytes_of(c)

    gd_seed = set()
    for r in ("GuardCtrl", "FightCtrl"):
        for sq in routine_targets[r]:
            lab = seq_label(sq)
            if lab:
                gd_seed.add(lab)
    for sq in involuntary:
        if sq in CUTSCENE_SEQS:
            continue
        lab = seq_label(sq)
        if lab:
            gd_seed.add(lab)
    gd_nodes = w0(gd_seed)
    gn, gb = guard_cost(gd_nodes)
    print()
    print("THE GUARD, recomputed with usealtsets' actual mapping")
    print("  every sequence GuardCtrl/FightCtrl/involuntary can select, W0-closed:")
    print("    %d cels, %d B     [P5.0 reported 31 cels / 9,350 B, ALTSET1 only]" % (gn, gb))
    gw0 = sorted(guard_cost(w0({n}))[1] for n in gd_nodes)
    print("  per-start W0: max %d B, median %d B, min %d B" % (gw0[-1], gw0[len(gw0)//2], gw0[0]))

    # --- CO-RESIDENCY, AS A UNION AND NOT AS A SUM -------------------------
    # * The kid and the guard SHARE Fdef cels for every frame outside 150-189, so adding
    # their two figures double-counts. The bank holds a SET of cels, so the figure the
    # bank cares about is the union.
    def kid_cels(nodes):
        return cels.cels(frames_of(nodes))

    def gd_cels(nodes):
        c = set()
        for f in frames_of(nodes):
            g = f + 70 if 102 <= f <= 106 else f
            e = alt.cel_of(g) if 150 <= g <= 189 else cels.cel_of(g)
            if e:
                c.add(e)
        return c

    print()
    BANK, BANK_MAX, WINDOW = 32768, 65536, 15872
    gd_all = gd_cels(gd_nodes)
    gd_w0max = max((gd_cels(w0({n})) for n in gd_nodes), key=lambda c: cels.bytes_of(c))
    print("CO-RESIDENT PEAK — kid UNION guard, both at the same window")
    for tag in ("W0", "W1", "W2", "Winf"):
        kmax = max(kid_sets[tag].values(), key=lambda v: cels.bytes_of(kid_cels(v)))
        k = kid_cels(kmax)
        g = gd_w0max if tag == "W0" else gd_all
        u = k | g
        kb, gb2, ub = cels.bytes_of(k), cels.bytes_of(g), cels.bytes_of(u)
        print("  %-5s kid %6d B + guard %6d B, union %6d B (%d cels; %d B saved to sharing)"
              % (tag, kb, gb2, ub, len(u), kb + gb2 - ub))
        print("        vs bank 32,768 -> %-14s vs recruited 65,536 -> %-14s vs window 15,872 -> %s"
              % ("FITS" if ub <= BANK else "over by %d" % (ub - BANK),
                 "FITS" if ub <= BANK_MAX else "over by %d" % (ub - BANK_MAX),
                 "FITS" if ub <= WINDOW else "over by %d" % (ub - WINDOW)))

    # --- cutscene inclusion delta ------------------------------------------
    inc = {n: step(w0({n}), exclude_cutscene=False) for n in starts}
    print()
    print("  cutscene sequences 94-114 INCLUDED, W1 peak: %d B (vs %d excluded, delta %d)"
          % (max(cost(v)[1] for v in inc.values()), peak_w1,
             max(cost(v)[1] for v in inc.values()) - peak_w1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
