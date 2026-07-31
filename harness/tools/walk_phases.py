#!/usr/bin/env python3
r"""walk_phases.py — which sub-byte PHASE is each Vwalk cel actually drawn at?

WHY THIS IS A TOOL AND NOT ARITHMETIC IN A REPORT. P3.30 answered this question by
hand twice and got two different answers, and the second one was baked into twelve
cels. The question has exactly one right answer and it is derivable, so it is derived
here -- from the oracle's own sequence table plus the two rules the port already
implements -- and printed as a trace anyone can read a line out of.

THE TWO RULES, both already in the port and neither invented here:

  1. OPCODES ARE CONSUMED UNTIL A CEL BYTE, then that cel is drawn at the resulting x.
     [COLL.S:996 ANIMCHAR -- ":next jsr getseq / cmp #chx / ... / jmp :next", so the
     chx BEFORE a cel has already moved CharX when that cel is drawn.  The port's
     vm_step is the same loop, char_draw.s:568.]  This is the step that P3.30's
     arithmetic dropped: `Vwalk db chx,1` moves x from 197 to 196 BEFORE cel 48 is
     ever drawn, and every phase downstream of that is shifted by one delta.

  2. chx IS MIRRORED BY FACING.  CharFace = -1 at startV0 [SUBS.S:1147], so a positive
     delta moves him LEFT.  [COLL.S:1002 addcharx; port: char_draw.s vs_chx.]

and the phase itself is the port's own co_setup expression, char_draw.s:406 --
`col = (x + Fdx + 20) / 4`, so the sub-byte phase is `(x + Fdx + 20) & 3`. The +20 is
the 280->320 centring; it is a multiple of 4 and so cannot change the phase, but it is
carried anyway because leaving it out of ONE of the two places is how the values drift.

Fdx comes from ALTSET2 via cel_parity_rule, not from a constant here.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path("C:/Projects/POP3_port")
sys.path.insert(0, str(ROOT / "harness/tools"))
import cel_parity_rule as R                                    # noqa: E402

SEQTABLE = ROOT / "oracle/source/01 POP Source/Source/SEQTABLE.S"
CHARX0, FACE = 197, -1            # startV0 [SUBS.S:1147]
CENTRING = 20                     # co_setup's 280->320 offset

OPS = {"chx", "chy", "aboutface", "goto"}


def vwalk():
    """(labels, tokens) for the Vwalk block, read out of the oracle's SEQTABLE.S."""
    lines = SEQTABLE.read_text(errors="replace").splitlines()
    i = next(k for k, l in enumerate(lines) if l.strip() == "Vwalk")
    toks, labels = [], {}
    for l in lines[i:]:
        s = l.split(";")[0].rstrip()
        if not s.strip():
            continue
        m = re.match(r"^(\S+)?\s*(db|dw)\s+(.*)$", s)
        if not m:
            if s.strip() == "Vwalk":
                labels["Vwalk"] = 0
                continue
            break
        lab, kind, rest = m.group(1), m.group(2), m.group(3)
        if lab:
            labels[lab] = len(toks)
        for item in [x.strip() for x in rest.split(",")]:
            toks.append(item)
    return labels, toks


def trace(steps=48):
    labels, toks = vwalk()
    alt = R.altset2()
    x, i = CHARX0, labels["Vwalk"]
    out = []
    for _ in range(steps):
        while True:
            t = toks[i]; i += 1
            if t == "chx":
                d = int(toks[i]); i += 1
                x += d if FACE >= 0 else -d     # addcharx mirrors by facing
            elif t == "chy":
                i += 1
            elif t == "aboutface":
                i += 1 if False else 0
            elif t == "goto":
                i = labels[toks[i]]
            else:
                cel = int(t)
                break
        fdx = alt[cel][1]
        out.append((cel, x, (x + fdx + CENTRING) & 3, fdx))
    return labels, out


def main():
    labels, tr = trace()
    print("=== Vwalk: the phase each cel is DRAWN at ===")
    print("  startV0 CharX=%d CharFace=%d [SUBS.S:1147]; goto -> %s"
          % (CHARX0, FACE, "Vwalk1" if labels.get("Vwalk1") else "?"))
    print("  phase = (x + Fdx + %d) & 3   [char_draw.s co_setup]\n" % CENTRING)
    print("  %-5s %-5s %-5s %-5s %s" % ("step", "cel", "x", "Fdx", "phase"))
    for n, (cel, x, ph, fdx) in enumerate(tr[:14], 1):
        print("  %-5d %-5d %-5d %-5d %d" % (n, cel, x, fdx, ph))
    print("  ...")

    occ = {}
    for cel, x, ph, _ in tr:
        occ.setdefault(cel, set()).add(ph)
    print("\n  OCCUPANCY over %d steps:" % len(tr))
    bad = 0
    for cel in sorted(occ):
        ph = sorted(occ[cel])
        print("    cel %d -> phases %s%s"
              % (cel, "{%s}" % ",".join(map(str, ph)),
                 "   <-- MORE THAN TWO" if len(ph) > 2 else ""))
        if len(ph) > 2:
            bad = 1
    net = tr[6][1] - tr[0][1]
    print("\n  net %d px per cycle of 6 cels; %d mod 4 = %d, which is why each cel has"
          % (net, abs(net), abs(net) % 4))
    print("  exactly two phases rather than one or four.")

    # how far the walk runs before he reaches the princess at 120 [SUBS.S:1131]
    reach = next((n for n, (_, x, _, _) in enumerate(tr, 1) if x <= 120), None)
    print("  reaches x<=120 (the princess's start) at step %s"
          % (reach if reach else "> %d" % len(tr)))
    return bad


if __name__ == "__main__":
    sys.exit(main())
