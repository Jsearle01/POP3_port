#!/usr/bin/env python3
r"""mode_closure.py - P5.9. The FIXPOINT of the move graph, and the same fixpoint per sword mode.

★★★ WHAT THIS ADDS TO peak_residency.py, AND WHY IT IS A DIFFERENT QUESTION.
P5.1 computed W0/W1/W2 -- peaks over a stated number of control DECISIONS. P5.6 killed W0 as a
window requirement and kept W1 as a RAM one. But "one decision" is an assumption about the
INTERVAL, not a derivation of it, and the interval that actually matters for RAM residency is
"how far can the machine get before a load could complete". If a load cannot complete inside any
plausible interval, the honest residency figure is the FIXPOINT -- everything reachable at all.

So this computes:

  W-inf        the transitive closure of `step` until it stops growing. SET OF: every cel any
               reachable sequence can draw. INTERVAL: unbounded. This is a CLOSURE, not a peak.
  W-inf armed  the same, seeded from armed states, with the to-UNARMED transitions as BARRIERS:
               the barrier node is INCLUDED (its frames draw during the transition) but is not
               expanded through, because past it the mode -- and therefore the resident set --
               has changed.
  W-inf unarmed  the mirror, with the to-ARMED transitions as barriers and armed=False, which
               also denies FightCtrl [CTRL.S:678].

★★ THE BARRIERS ARE THE MODE-CHANGE SITES, TAKEN FROM THE WRITES THEMSELVES rather than from a
description of them. Every `sta CharSword` in CTRL.S, with the sequence it jumps to:

  -> armed (2)    engarde 55   [CTRL.S:1613 DoEngarde]
                  landengarde 63 [CTRL.S:227 :softland -- and note it only PRESERVES armed for
                                  the kid; `cmp #2 / bne :1` means an unarmed kid lands unarmed.
                                  It is a barrier for the guard, who is armed unconditionally.]
                  turndraw 89  [CTRL.S:1578]
  -> unarmed (0)  resheathe 92 [CTRL.S:800, at CharPosn 171]
                  stepfall 7 and its siblings [CTRL.S:359 startfall, "so you can grab on"]
                  the drop    [CTRL.S:852, CharID==0 -> :drop]

★ CTRL.S:359 IS THE ONE THAT MATTERS AND IT IS NOT AN ANIMATION. `startfall` writes
CharSword = 0 on the frame the floor disappears. There is no draw-sword-down sequence gating it.
Phase 2 of the dispatch turns on that fact, so it is recorded here next to the barrier list
rather than only in the report.
"""
import argparse
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "harness/tools"))

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

import ctrl_edges as CE                                                 # noqa: E402
from peak_residency import build, CUTSCENE_SEQS                         # noqa: E402

BLOCK = 8192

TO_ARMED = ("engarde", "landengarde", "turndraw")
TO_UNARMED = ("resheathe", "stepfall", "stepfall2", "jumpfall")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--block", type=int, default=BLOCK)
    args = ap.parse_args()

    items, labels, entries, names, cels, bodies = build()

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
    involuntary |= CE.closure_targets("GENCTRL", tgt, calls) & {names["dropdead"]}

    def seq_label(n):
        return entries.get(n)

    def w0(nodes, barrier=frozenset()):
        seen, cur = set(nodes), set(nodes)
        while cur:
            nxt = set()
            for n in cur:
                if n in barrier:
                    continue                # included, not expanded through
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

    def cost(nodes, armed=True):
        c = cels.cels(frames_of(nodes), armed=armed)
        return len(c), cels.bytes_of(c)

    def step(nodes, armed=True, barrier=frozenset()):
        out = set(nodes)
        for n in nodes:
            if n in barrier:
                continue
            for f in bodies[n]["frames"]:
                r = CE.DISPATCH.get(f)
                if not r:
                    continue
                for s in routine_targets.get(r, ()):
                    if s in CUTSCENE_SEQS:
                        continue
                    lab = seq_label(s)
                    if lab:
                        out.add(lab)
        if armed and any(150 <= f <= 189 for f in frames_of(nodes - set(barrier))):
            for s in routine_targets["FightCtrl"]:
                lab = seq_label(s)
                if lab:
                    out.add(lab)
        for s in involuntary:
            if s in CUTSCENE_SEQS:
                continue
            lab = seq_label(s)
            if lab:
                out.add(lab)
        return w0(out, barrier)

    def fixpoint(seed, armed=True, barrier=frozenset(), cap=40):
        cur, n = w0(seed, barrier), 0
        while n < cap:
            nxt = step(cur, armed=armed, barrier=barrier)
            n += 1
            if nxt == cur:
                return cur, n
            cur = nxt
        return cur, n

    def labels_for(seqnames):
        out = set()
        for nm in seqnames:
            s = names.get(nm)
            if s is None:
                continue
            lab = seq_label(s)
            if lab:
                out.add(lab)
        return out

    kid_seed = {entries[n] for n in range(1, 94) if n in entries}
    print("BARRIERS, resolved from the sequence table (a name that does not resolve is listed")
    print("as absent rather than silently dropped):")
    for tag, nms in (("-> armed", TO_ARMED), ("-> unarmed", TO_UNARMED)):
        for nm in nms:
            s = names.get(nm)
            print("   %-11s %-14s seq %s  label %s"
                  % (tag, nm, s if s is not None else "ABSENT",
                     seq_label(s) if s is not None else "-"))
    print()

    # ------------------------------------------------------------------ AC1
    print("=" * 78)
    print("AC1 — W-inf, THE FIXPOINT.  CLOSURE OF: every cel a reachable sequence can draw.")
    print("      INTERVAL: unbounded — no bound on how many decisions the player makes.")
    print("=" * 78)
    inf, iters = fixpoint(kid_seed, armed=True)
    n_inf, b_inf = cost(inf, armed=True)
    print("  kid, armed-capable (FightCtrl reachable):")
    print("     %3d nodes, %3d cels, %6d B   (fixpoint after %d iterations)"
          % (len(inf), n_inf, b_inf, iters))
    infu, itu = fixpoint(kid_seed, armed=False)
    n_u, b_u = cost(infu, armed=False)
    print("  kid, unarmed cel costing (no sword cel per frame):")
    print("     %3d nodes, %3d cels, %6d B   (fixpoint after %d iterations)"
          % (len(infu), n_u, b_u, itu))

    # ★ W1 IS A PEAK OVER START NODES, NOT A UNION, and conflating the two is how this tool
    # first reported W1 = 51,630. peak_residency.py computes step() from EACH start
    # separately and takes the max; the union of all starts is by definition already the
    # fixpoint. Both are printed so the difference is visible rather than assumed.
    per_start = []
    for n in sorted(w0(kid_seed)):
        s1 = step(w0({n}), armed=True)
        per_start.append((cost(s1, armed=True)[1], n))
    per_start.sort()
    b1, worst = per_start[-1]
    print()
    print("  W1 as a PEAK over start nodes (peak_residency.py's definition):")
    print("     worst start `%s` -> %d B; median start %d B" % (worst, b1,
                                                                per_start[len(per_start) // 2][0]))
    print("  ★ W-inf / W1 = %.3f   -> the closure is %d B above the one-decision peak (%.1f%%)"
          % (b_inf / b1 if b1 else 0, b_inf - b1,
             100.0 * (b_inf - b1) / b1 if b1 else 0))

    # ------------------------------------------------------------------ AC2
    print()
    print("=" * 78)
    print("AC2 — THE PER-MODE CLOSURES.  CLOSURE OF: the cels reachable WHILE THE MODE HOLDS.")
    print("      INTERVAL: unbounded within the mode; the barrier sequences end it.")
    print("      Transition sequences are INCLUDED IN BOTH — they draw during the change.")
    print("=" * 78)
    # ★ THE SEED IS ONE STATE, NOT ALL 93, AND THE FIRST VERSION OF THIS TOOL GOT IT WRONG.
    # Seeding from every kid sequence puts the FIGHT sequences in the unarmed set by
    # construction -- which is precisely what the mode split is supposed to exclude, so the
    # answer was decided by the seed instead of by reachability. The question asked is
    # "everything reachable FROM an unarmed state WITHOUT passing through CharSword == 2",
    # so the seed is the kid's canonical rest state and the closure does the work.
    bar_a = labels_for(TO_ARMED)
    bar_u = labels_for(TO_UNARMED)
    stand = labels_for(("stand",))
    if not stand:
        print("  ★ `stand` did not resolve; falling back to the full seed and SAYING SO.")
        stand = kid_seed
    print("  seed for both modes: %s" % sorted(stand))
    armed_set, ia = fixpoint(stand, armed=True, barrier=frozenset(bar_u))
    unarm_set, iu = fixpoint(stand, armed=False, barrier=frozenset(bar_a))
    n_a, b_a = cost(armed_set, armed=True)
    n_un, b_un = cost(unarm_set, armed=False)
    print("  ARMED closure   (barriers: the to-unarmed sequences)")
    print("     %3d nodes, %3d cels, %6d B  (%d iterations)" % (len(armed_set), n_a, b_a, ia))
    print("  UNARMED closure (barriers: the to-armed sequences; FightCtrl denied)")
    print("     %3d nodes, %3d cels, %6d B  (%d iterations)" % (len(unarm_set), n_un, b_un, iu))
    larger = max(b_a, b_un)
    print()
    print("  the modes cannot coexist [CTRL.S:678], so the requirement is the LARGER: %d B"
          % larger)
    print("  ★ against the unsplit closure %d B, the split saves %d B (%.1f%%)"
          % (b_inf, b_inf - larger, 100.0 * (b_inf - larger) / b_inf if b_inf else 0))

    # ------------------------------------------------------------------ AC3
    print()
    print("=" * 78)
    print("AC3 — DOES THE SPLIT BUY A BLOCK?")
    print("=" * 78)
    print("  ★ BLOCKS, NOT BYTES [§5.225]. A cel cannot straddle a block boundary, so the")
    print("    figure that binds is ceil(bytes / %d) -- and P5.6 measured real packing at" % args.block)
    print("    98-99%% fill, so the ceiling is achievable rather than optimistic.")
    print()
    print("  %-28s %9s %8s" % ("candidate", "bytes", "blocks"))
    rows = [("W1 (one decision)", b1),
            ("W-inf, unsplit", b_inf),
            ("W-inf, armed", b_a),
            ("W-inf, unarmed", b_un),
            ("W-inf, larger mode", larger)]
    for tag, b in rows:
        print("  %-28s %9d %8d" % (tag, b, -(-b // args.block)))
    blk_unsplit = -(-b_inf // args.block)
    blk_split = -(-larger // args.block)
    print()
    if blk_split < blk_unsplit:
        print("  ★ THE SPLIT BUYS %d BLOCK(S): %d -> %d." % (blk_unsplit - blk_split,
                                                             blk_unsplit, blk_split))
    else:
        print("  ★ THE SPLIT BUYS NOTHING IN BLOCKS: both land at %d." % blk_unsplit)
        print("    The %d B it saves does not cross a block boundary, and blocks are the unit"
              % (b_inf - larger))
        print("    that binds. Phase 2's paging question is therefore moot on the arithmetic")
        print("    alone, before the startfall argument is even reached.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
