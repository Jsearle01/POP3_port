#!/usr/bin/env python3
r"""walk_phases.py — which sub-byte PHASE is each of the vizier's cels drawn at?

WHY THIS IS A TOOL AND NOT ARITHMETIC IN A REPORT. P3.30 answered this question by
hand twice and got two different answers, and the second one — a CORRECTION of the
first, reported as a catch — was the exact complement of the truth. Twelve cels were
baked to it. The question has one right answer and it is derivable, so it is derived
here, from the oracle's own tables plus the two rules the port already implements, and
printed as a trace anyone can read a line out of.

THE RULES, all four already in the port and none invented here:

  1. OPCODES ARE CONSUMED UNTIL A CEL BYTE, then that cel is drawn at the resulting x.
     [COLL.S:996 ANIMCHAR; the port's vm_step is the same loop.]  This is the step
     P3.30's arithmetic dropped: `Vwalk db chx,1` moves x from 197 to 196 BEFORE cel 48
     is ever drawn, and every phase downstream of that shifts by one delta.

  2. chx IS MIRRORED BY FACING.  CharFace = -1 at startV0 [SUBS.S:1147], so a positive
     delta moves him LEFT.  [COLL.S:1002 addcharx; port: char_draw.s vs_chx.]

  3. THE SCENE SCRIPT SWITCHES SEQUENCES AFTER N ANIMATION STEPS. `play N` runs N
     frames [SUBS.S:876], and PlayCut0 calls vjumpseq/play in pairs. Which pairs and
     which counts is read out of SUBS.S below rather than copied: the P3.32 dispatch
     quoted "Vapproach 30 -> Vstop 4" and the source has TWO approach/stop pairs, an
     earlier `6 / 4` before it. Six steps of walking is 10 px of position, which is 2
     of phase — so taking the quoted script would have baked the stopping cels at the
     wrong phase for the same reason the walk cels were wrong.

  4. THE PHASE IS co_setup'S OWN EXPRESSION, term for term: `col = (x + Fdx + 20) / 4`
     [char_draw.s co_setup], so the phase is `(x + Fdx + 20) & 3`. The +20 centring is
     a multiple of 4 and cannot change the phase, but it is carried because leaving it
     out of ONE of the two places is how the values drifted in the first place.

Fdx comes from ALTSET2 via cel_parity_rule, not from a constant here.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path("C:/Projects/POP3_port")
sys.path.insert(0, str(ROOT / "harness/tools"))
import cel_parity_rule as R                                    # noqa: E402

SRC = ROOT / "oracle/source/01 POP Source/Source"
SEQTABLE = SRC / "SEQTABLE.S"
SEQDATA = SRC / "SEQDATA.S"
SUBS = SRC / "SUBS.S"

CHARX0, FACE = 197, -1            # startV0 [SUBS.S:1147]
CENTRING = 20                     # co_setup's 280->320 offset
BLOCKS = ["Vstand", "Vwalk", "Vstop"]   # the sequences this scene's vizier reaches

# How many steps to run the final, unbounded sequence for. He holds Vstand from the
# last Vstop onward, at one position, so a handful is enough to see the phase.
HOLD_STEPS = 4

# A sequence with a play count of 0 runs forever; a TRACE cannot. Six walk cycles is
# enough to visit every phase every cel reaches (the cycle nets 10 px, 10 mod 4 = 2, so
# the phase set repeats after two cycles).
TRACE_FOREVER = 36

# ---------------------------------------------------------------------------
# HOW MUCH OF THE SCRIPT THE PORT CAN RUN, AND IT IS A MEMORY LIMIT, NOT A SCOPE ONE.
#
# Vstop needs three more baked variants -- cels 55 and 56 at phase 2, and cel 54 at
# phase 2 for the Vstand he holds afterwards. They bake correctly (15 variants, 0
# failed) and they DO NOT FIT. Measured, P3.32:
#
#     bundle with the walk's 12 variants      14,525 B
#     bundle with Vstop's 15                  16,785 B   ($3000..$7190)
#     window $3000..$69FF (below DR_VARBASE)  14,848 B
#                                             ---------
#     over by                                  1,937 B
#
# and lz_pack refused it rather than letting it load through the disk driver's
# parameter block: "in-place UNSAFE: stream starts at 9809, needs >= 11747".
#
# Relocating everything above the bundle -- DR_VARBASE, and the peel buffers at $6C00 --
# raises the ceiling to the trace ring at $7800 = 18,432 B, against 16,785 + 1,648 of
# peel + 7 = 18,440. EIGHT BYTES SHORT. Moving the trace ring too would fit it with 248
# to spare, and would spend every remaining byte between the bundle and the kernel on
# three cels. That is the shape of the answer being wrong, not of the window being
# small: 49 cels at two phases each is not a thing this layout can hold, and the
# remedy is a representation that does not store every phase (a runtime shifter, or
# cels the blitter can walk packed) rather than another relocation.
#
# 1 = the approach only, which is what P3.31 shipped. Raise it when the window does.
PORT_ENTRIES = 1


def sequences():
    """(labels, tokens) for the vizier's sequence blocks, from the oracle's SEQTABLE.S.

    Parsed as ONE token stream so a `goto` can cross from one block to another, which
    is what Vstop does when it ends `goto Vstand`.
    """
    lines = SEQTABLE.read_text(errors="replace").splitlines()
    toks, labels = [], {}
    for name in BLOCKS:
        i = next(k for k, l in enumerate(lines) if l.strip() == name)
        labels[name] = len(toks)
        for l in lines[i + 1:]:
            s = l.split(";")[0].rstrip()
            if not s.strip():
                continue
            m = re.match(r"^(\S+)?\s*(db|dw)\s+(.*)$", s)
            if not m:
                break                       # the banner comment that ends the block
            if m.group(1):
                labels[m.group(1)] = len(toks)
            toks += [x.strip() for x in m.group(3).split(",")]
    return labels, toks


def script():
    """The vizier's [(sequence label, play count), ...] read out of PlayCut0.

    Matches `lda #<seq> / jsr vjumpseq / lda #<n> / jsr play`, resolving the sequence
    NAME through SEQDATA.S's id and SEQTABLE.S's id table -- Vapproach is 96 and 96 is
    Vwalk, which is why nothing in this file mentions Vapproach again.
    """
    ids = dict(re.findall(r"^(\w+)\s*=\s*(\d+)", SEQDATA.read_text(errors="replace"),
                          re.M))
    byid = dict(re.findall(r"^:(\d+)\s+dw\s+(\w+)", SEQTABLE.read_text(errors="replace"),
                           re.M))
    text = SUBS.read_text(errors="replace")
    body = text[text.index("\nPlayCut0"):]
    body = body[:body.index("Vraise")]          # Vraise onward is not this dispatch
    out = []
    for seq, n in re.findall(r"lda\s+#(\w+)\s*\n\s*jsr\s+vjumpseq\s*\n"
                             r"\s*lda\s+#(\d+)\s*\n\s*jsr\s+play", body):
        out.append((byid[ids[seq]], int(n)))
    return out


def port_plan():
    """What the PORT runs: the oracle's FINAL approach/stop pair, and only that.

    THE SOURCE HAS TWO PAIRS. `Vapproach 6 / Vstop 4 ;vizier enters` comes first, then
    four plays of Vstand, then `Vapproach 30 / Vstop 4 ;stops in front of princess`
    [SUBS.S:687-716]. Porting both is not a scope question, it is a MEMORY question:
    the entrance leaves him at a different x, the second approach therefore runs at the
    other phase parity, and every walk cel ends up drawn at THREE phases instead of two
    -- 24 baked variants where 12 already fill the window. Measured, not guessed: run
    this file with no arguments to see the full-script occupancy.

    So the port runs the final pair from startV0's own x. The COUNTS still come from the
    source (they are this list's last two entries, not numbers typed here); what is
    dropped is the entrance, and the visible consequence is where he comes to rest --
    reported by both traces below so the difference is a measurement and not a surprise.

    AND CURRENTLY IT RUNS ONLY THE FIRST ENTRY OF THAT, BECAUSE Vstop DOES NOT FIT --
    see PORT_ENTRIES.
    """
    s = script()
    plan = [s[-2], s[-1], ("Vstand", HOLD_STEPS)][:PORT_ENTRIES]
    return plan[:-1] + [(plan[-1][0], 0)]       # the last entry always holds


def trace(plan=None):
    """[(cel, x, phase, Fdx, seq), ...] — every cel the vizier draws, in order."""
    labels, toks = sequences()
    alt = R.altset2()
    plan = plan or (script() + [("Vstand", HOLD_STEPS)])
    x, out = CHARX0, []
    for seq, count in plan:
        i = labels[seq]                             # vjumpseq: back to the START
        for _ in range(count or TRACE_FOREVER):
            while True:
                t = toks[i]; i += 1
                if t == "chx":
                    d = int(toks[i]); i += 1
                    x += d if FACE >= 0 else -d     # addcharx mirrors by facing
                elif t in ("chy", "setfall"):
                    i += 1
                elif t == "aboutface":
                    pass
                elif t == "goto":
                    i = labels[toks[i]]
                else:
                    cel = int(t)
                    break
            fdx = alt[cel][1]
            out.append((cel, x, (x + fdx + CENTRING) & 3, fdx, seq))
    return labels, out


def occupancy(plan=None):
    """cel -> the sorted phases the script actually draws it at."""
    occ = {}
    for cel, _x, ph, _fdx, _seq in trace(plan)[1]:
        occ.setdefault(cel, set()).add(ph)
    return {c: tuple(sorted(p)) for c, p in occ.items()}


def summarise(name, plan):
    occ = occupancy(plan)
    tr = trace(plan)[1]
    # "rests at" only means anything if the script ENDS. A trailing count of 0 is a
    # sequence that runs forever, and the last x a finite trace happened to reach is
    # not a resting place -- saying so would be a measurement that is not one.
    where = ("rests at x=%d" % tr[-1][1] if plan[-1][1] else
             "never stops (trace ends x=%d)" % tr[-1][1])
    print("  %-12s %-36s %2d cels / %2d variants, %s"
          % (name, " -> ".join("%s x%s" % (s, n or "-") for s, n in plan),
             len(occ), sum(len(p) for p in occ.values()), where))
    return occ


def main():
    plan = port_plan()
    _labels, tr = trace(plan)
    print("=== the vizier's script, and the phase each cel is DRAWN at ===")
    print("  startV0 CharX=%d CharFace=%d [SUBS.S:1147]" % (CHARX0, FACE))
    print("  the SOURCE's script vs what the PORT runs:")
    full = summarise("source", script() + [("Vstand", HOLD_STEPS)])
    summarise("port", plan)
    over = sum(1 for p in full.values() if len(p) > 2)
    if over:
        print("  (%d of the source's cels are drawn at THREE phases — the entrance pair"
              " lands\n   the second approach on the other parity; see port_plan)" % over)
    print("\n  phase = (x + Fdx + %d) & 3   [char_draw.s co_setup]\n" % CENTRING)
    print("  %-5s %-8s %-5s %-5s %-5s %s" % ("step", "seq", "cel", "x", "Fdx", "phase"))
    shown = list(range(6)) + list(range(len(tr) - 10, len(tr)))
    last = -2
    for n in shown:
        if n < 0:
            continue
        if n != last + 1:
            print("  ...")
        cel, x, ph, fdx, seq = tr[n]
        print("  %-5d %-8s %-5d %-5d %-5d %d" % (n + 1, seq, cel, x, fdx, ph))
        last = n

    occ = occupancy(plan)
    print("\n  OCCUPANCY the port bakes to, over %d steps:" % len(tr))
    bad = 0
    for cel in sorted(occ):
        ph = occ[cel]
        print("    cel %d -> phases {%s}%s"
              % (cel, ",".join(map(str, ph)),
                 "   <-- MORE THAN TWO" if len(ph) > 2 else ""))
        if len(ph) > 2:
            bad = 1
    print("\n  %d cels to bake, %d in total"
          % (len(occ), sum(len(p) for p in occ.values())))
    if plan[-1][1]:
        print("  comes to REST at x=%d (cel %d), the princess starts at 120 [SUBS.S:1131]"
              % (tr[-1][1], tr[-1][0]))
    else:
        print("  the port's last script entry HOLDS — he does not stop (PORT_ENTRIES=%d)"
              % PORT_ENTRIES)
    return bad


if __name__ == "__main__":
    sys.exit(main())
