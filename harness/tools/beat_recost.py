#!/usr/bin/env python3
r"""beat_recost.py — what do the cutscene's REMAINING beats cost at the CORRECTED scale?

WHY A RECOST IS NEEDED AT ALL. Every occupancy figure from P3.32 onward was computed
against a doubling that did not exist. The port drew characters at `x + 20` — half scale,
no parity — where SETUPCHAR builds `2*(CharX + Fdx - 58) + parity` [CTRLSUBS.S:794-840].
That is not only a rendering bug: it changes the ARITHMETIC. At half scale a walk cycle
nets 10 px and 10 mod 4 = 2, so every cel is drawn at TWO sub-byte phases and needs two
baked variants. At true scale the same cycle advances 20 px = FIVE WHOLE BYTES, so the
phase is invariant and one variant serves.

Demonstrated already: Vstop, which P3.32 measured as 1,937 B beyond the window and
correctly refused, came out at 9 variants against the walk's own 12.

WHAT THIS DOES. Traces PlayCut0 the way the machine does — `play N` advances BOTH
characters, `vjumpseq`/`pjumpseq` retarget one of them — so the positions are the real
ones, because positions decide phases. Then converts and prepares every (cel, phase) it
finds INTO A SCRATCH DIRECTORY and measures the emitted bytes. Nothing is written to the
tree and no beat is built; the sizes are measured rather than estimated, because an
estimate is what this file exists to replace.

Read out of the oracle, not restated here: the script from SUBS.S, the sequences from
SEQTABLE.S, Fdx/Fcheck from ALTSET2 via cel_parity_rule.
"""
import argparse
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path("C:/Projects/POP3_port")
sys.path.insert(0, str(ROOT / "harness/tools"))
import cel_parity_rule as R                                    # noqa: E402

SRC = ROOT / "oracle/source/01 POP Source/Source"
SEQTABLE = SRC / "SEQTABLE.S"
SEQDATA = SRC / "SEQDATA.S"
SUBS = SRC / "SUBS.S"
TABLE = SRC.parent / "Images/IMG.CHTAB6.A"

BLOCKS = ["Vstand", "Vwalk", "Vstop", "Vraise", "Vexit",
          "Pstand", "Palert", "Pback", "Pslump"]

# startV0 / startP0 [SUBS.S:1131,1147]
START = {"viz": (197, R.FACE_LEFT, "Vstand"), "pri": (120, R.FACE_LEFT, "Pstand")}
CENTRING = 20


def sequences():
    """(labels, tokens) for every block, as ONE stream so a goto can cross blocks.

    ★★ `:loop` IS A LOCAL LABEL AND MUST BE SCOPED TO ITS BLOCK (P3.78). Mechner's
    assembler scopes a `:`-prefixed label to the enclosing routine, and SEQTABLE.S reuses
    `:loop` in almost every sequence. Read into one flat dict, the LAST definition wins
    and every earlier `goto :loop` silently retargets to it.

    What that cost: `Pback` ends `:loop db 17 / goto :loop` — she backs away and holds on
    cel 17 [SEQTABLE.S:1574, read, not inferred]. Parsed globally, its goto resolved to
    `Pslump`'s `:loop`, so the trace had her holding on cel 18 from the moment she
    finished backing away. The port's own hand-written sequence was right; the TRACE was
    wrong, and the trace is what the packer uses to decide which cels a beat needs.

    The consequence was not a wrong picture. The packer provisioned cel 18 for every beat
    after Pback and never provisioned 17, so the beat after Pback drew a cel that was in
    an unmapped page: a valid-looking pointer into the wrong block, which the blitter
    walked as a segment stream and never came out of. The room hung with interrupts
    masked, the frame counter stopped, and it presented as the scene stalling — five
    beats from the end, in the one dispatch that first made Pback run.

    Two lessons, and the second is the general one: a tracer that has never exercised a
    code path has not been tested on it, and the reused local label made every sequence
    with a `:loop` a latent instance of the same fault. Scoping is the fix, and it is
    applied to the TOKEN, so a `goto :loop` operand and its definition qualify alike.
    """
    lines = SEQTABLE.read_text(errors="replace").splitlines()
    toks, labels = [], {}
    for name in BLOCKS:
        i = next(k for k, l in enumerate(lines) if l.strip() == name)
        labels[name] = len(toks)

        def scope(t, _n=name):
            return (_n + t) if t.startswith(":") else t

        for l in lines[i + 1:]:
            s = l.split(";")[0].rstrip()
            if not s.strip():
                continue
            m = re.match(r"^(\S+)?\s*(db|dw)\s+(.*)$", s)
            if not m:
                break
            if m.group(1):
                lab = scope(m.group(1))
                if lab in labels:
                    raise SystemExit("  duplicate label %r — scoping did not work" % lab)
                labels[lab] = len(toks)
            toks += [scope(x.strip()) for x in m.group(3).split(",")]
    return labels, toks


def script():
    """PlayCut0 as an ordered op list: ('vjump'|'pjump', seq) and ('play', n)."""
    ids = dict(re.findall(r"^(\w+)\s*=\s*(\d+)", SEQDATA.read_text(errors="replace"), re.M))
    byid = dict(re.findall(r"^:(\d+)\s+dw\s+(\w+)", SEQTABLE.read_text(errors="replace"), re.M))
    text = SUBS.read_text(errors="replace")
    body = text[text.index("\nPlayCut0"):]
    body = body[:body.index("addglass\n")] if "addglass\n" in body else body
    ops = []
    for m in re.finditer(r"lda\s+#(\w+)\s*\n\s*jsr\s+(vjumpseq|pjumpseq)|"
                         r"lda\s+#(\d+)\s*\n\s*jsr\s+play", body):
        if m.group(2):
            seq = byid.get(ids.get(m.group(1), ""), None)
            if seq:
                ops.append(("vjump" if m.group(2) == "vjumpseq" else "pjump", seq))
        else:
            ops.append(("play", int(m.group(3))))
    return ops


class Char:
    def __init__(self, x, face, seq, labels):
        self.x, self.face, self.i = x, face, labels[seq]
        self.drawn = []                       # (cel, phase, x, face)

    def jump(self, seq, labels):
        self.i = labels[seq]                  # vjumpseq restarts at the FIRST byte

    def step(self, toks, labels, alt):
        """Consume opcodes until a cel byte, exactly as ANIMCHAR does [COLL.S:994]."""
        for _ in range(200):
            t = toks[self.i]; self.i += 1
            if t == "chx":
                d = int(toks[self.i]); self.i += 1
                self.x += d if self.face == 0 else -d      # addcharx mirrors by facing
            elif t in ("chy", "setfall", "act", "tap"):
                self.i += 1
            elif t == "aboutface":
                self.face = 0 if self.face == R.FACE_LEFT else R.FACE_LEFT
            elif t == "goto":
                self.i = labels[toks[self.i]]
            elif re.fullmatch(r"-?\d+", t):
                cel = int(t)
                fdx, fchk = alt[cel][1], alt[cel][3]
                spx = R.draw_x(self.x, fdx, fchk, self.face, R.awid(cel)) + CENTRING
                self.drawn.append((cel, spx & 3, self.x, self.face))
                return
            else:
                return                        # an opcode this trace does not model
        raise SystemExit("  runaway sequence")


def trace():
    labels, toks = sequences()
    alt = R.altset2()
    who = {k: Char(x, f, s, labels) for k, (x, f, s) in START.items()}
    marks = []
    for op, arg in script():
        if op == "vjump":
            who["viz"].jump(arg, labels)
            marks.append(("viz", arg, len(who["viz"].drawn)))
        elif op == "pjump":
            who["pri"].jump(arg, labels)
            marks.append(("pri", arg, len(who["pri"].drawn)))
        else:
            for _ in range(arg):
                for c in who.values():
                    c.step(toks, labels, alt)
    return who, marks


def occupancy(char, lo=0, hi=None):
    occ = {}
    for cel, ph, _x, _f in char.drawn[lo:hi]:
        occ.setdefault(cel, set()).add(ph)
    return {c: tuple(sorted(p)) for c, p in occ.items()}


def measure(occ, scratch, stem_of):
    """Convert + prepare each (cel, phase) into scratch; return {(cel,ph): bytes}."""
    alt = R.altset2()
    scratch = pathlib.Path(scratch)
    scratch.mkdir(parents=True, exist_ok=True)
    out = {}
    for cel in sorted(occ):
        fimg, fdx, _fdy, fchk, _lab = alt[cel]
        idx = fimg & 0x7F
        for ph in occ[cel]:
            stem = stem_of(cel)
            src = scratch / ("c%d_src.s" % cel)
            if not src.exists():
                sc = R.draw_x(197 if stem.startswith("v") else 120, fdx, fchk)
                r = subprocess.run(
                    [sys.executable, str(ROOT / "harness/tools/sprite_convert.py"),
                     "--table", str(TABLE), "--index", str(idx), "--out", str(src),
                     "--label", "c%d_src" % cel, "--start-col", str(sc), "--quiet"],
                    capture_output=True, text=True)
                if r.returncode != 0 or not src.exists():
                    out[(cel, ph)] = None
                    continue
            dst = scratch / ("c%d_p%d.s" % (cel, ph))
            b = subprocess.run(
                [sys.executable, str(ROOT / "harness/tools/cel_blit_prep.py"), str(src),
                 "--phase", str(ph), "--label", "c%d_p%d" % (cel, ph), "--out", str(dst)],
                capture_output=True, text=True)
            m = re.search(r"(\d+) segment bytes", b.stdout or "")
            out[(cel, ph)] = (int(m.group(1)) + 2) if m else None   # +2 rows/width header
    return out


# ---------------------------------------------------------------------------
# THE PEAK WORKING SET (P3.63) — and why it is NOT the sum.
#
# P3.62 costed the whole scene's cels and got 37,602 B against a 14,848 B window, which
# reads as a representation crisis. But the beats PLAY IN SEQUENCE: Vwalk, Vstop, Vraise,
# Pback, Vexit and Pslump are consecutive, not simultaneous. Summing them charges the
# window for every cel at once when the machine only ever draws two per step.
#
# The binding figure is what must be RESIDENT AT ONCE. Modelled here the way an interval
# does: a cel is live from the first step that draws it to the last, because anything
# narrower means loading it twice. Peak = the largest total over any single step.
#
# THAT MODEL IS DELIBERATELY PESSIMISTIC IN ONE PLACE AND HONEST ABOUT IT: Vexit ends
# `goto Vwalk2` [SEQTABLE.S:1553], so the vizier walks OUT on the walk cels. Their span
# therefore stretches from step 1 to nearly the last, and they are resident across every
# beat in between even though nothing draws them in the middle. A scheme that unloads and
# reloads them would pay twice; the span model charges once and holds. Both are worth
# knowing, so `spans` reports the gap as well as the extent.
def spans(char, key):
    """{key: (first_step, last_step, n_draws)} over this character's drawn list."""
    out = {}
    for i, (cel, ph, _x, _f) in enumerate(char.drawn):
        k = key(cel, ph)
        if k in out:
            f, _l, n = out[k]
            out[k] = (f, i, n + 1)
        else:
            out[k] = (i, i, 1)
    return out


def peak(all_spans, sizes, n_steps):
    """(peak_bytes, step, live_keys) under the interval model."""
    best = (0, -1, ())
    for s in range(n_steps):
        live = [k for k, (f, l, _n) in all_spans.items() if f <= s <= l]
        tot = sum(sizes.get(k, 0) for k in live)
        if tot > best[0]:
            best = (tot, s, tuple(live))
    return best


# The PORT's plan, not PlayCut0's absolute timeline. BROUGHT CURRENT AT P3.73: the port no
# longer drops the entrance pair (P3.72i/j) and now carries the lead-in and both song cues
# (P3.72e/l), so its positions — and therefore its phases — are the ones bake_scene.PLAN
# produces. Beats after the second Vstop follow SUBS.S:713-750 in order.
#
# THE SONG HOLDS ARE INCLUDED because they are steps the port really plays, and because
# they are where a loader would have its time. They add no cels, so they cannot move the
# PEAK — but they do stretch every span that brackets them, which is why a span below is
# read in steps and not in seconds.
#
# The remaining beats' own cues (s_Buildup, s_Magic, s_StTimer) are NOT here: their
# durations have not been trace-measured, and a hold changes no residency. Their absence
# shortens the step axis and changes nothing else.
PORT_PLAN = [("p", "Pstand", 7),          # the lead-in [SUBS.S:665-672]
             (None, None, 109),           # s_Princess, 761 frames / 7
             ("p", "Palert", 9),          # she turns
             (None, None, 5),
             ("v", "Vwalk", 7),           # he enters
             ("v", "Vstop", 4),           # ...and stops
             (None, None, 51),            # s_Vizier, 358 frames / 7
             (None, None, 4),
             ("v", "Vwalk", 29),          # he crosses
             ("v", "Vstop", 4),           # stops in front of her  <- WHERE THE PORT ENDS
             ("v", "Vraise", 1),          # ---- the remaining beats, from here down ----
             ("p", "Pback", 13),
             (None, None, 5),
             ("v", "Vexit", 17),
             (None, None, 12),
             ("p", "Pslump", 28)]


def port_trace():
    labels, toks = sequences()
    alt = R.altset2()
    viz = Char(197, R.FACE_LEFT, "Vstand", labels)
    pri = Char(120, R.FACE_LEFT, "Pstand", labels)
    bounds = []
    for w, seq, n in PORT_PLAN:
        if w == "v":
            viz.jump(seq, labels)
        if w == "p":
            pri.jump(seq, labels)
        for _ in range(n):
            viz.step(toks, labels, alt)
            pri.step(toks, labels, alt)
        bounds.append((seq or "(continue)", n, len(viz.drawn)))
    return viz, pri, bounds


def working_set(scratch):
    viz, pri, bounds = port_trace()
    n_steps = len(viz.drawn)
    print("=== the PORT's plan, and where each beat ends ===")
    for seq, n, at in bounds:
        print("    %-11s x%-3d -> step %d" % (seq, n, at))
    print("    %d animation steps in all\n" % n_steps)

    # measure every variant and every distinct cel, once, into scratch
    occ_v, occ_p = occupancy(viz), occupancy(pri)
    sz_var, sz_cel = {}, {}
    for who, occ, base in (("viz", occ_v, 197), ("pri", occ_p, 120)):
        sizes = measure(occ, pathlib.Path(scratch) / who,
                        lambda c, w=who: ("v" if w == "viz" else "p") + str(c))
        for (cel, ph), b in sizes.items():
            if b:
                sz_var[(who, cel, ph)] = b
        for cel in occ:
            src = pathlib.Path(scratch) / who / ("c%d_src.s" % cel)
            if src.exists():
                m = re.search(r"fcb\s+(\d+)\s*,\s*(\d+)", src.read_text(errors="replace"))
                if m:
                    sz_cel[(who, cel)] = int(m.group(1)) * int(m.group(2)) + 2

    sp_var, sp_cel = {}, {}
    for who, ch in (("viz", viz), ("pri", pri)):
        for k, v in spans(ch, lambda c, p, w=who: (w, c, p)).items():
            sp_var[k] = v
        for k, v in spans(ch, lambda c, p, w=who: (w, c)).items():
            sp_cel[k] = v

    print("=== residency SPANS (first step drawn -> last), longest first ===")
    rows = sorted(sp_cel.items(), key=lambda kv: -(kv[1][1] - kv[1][0]))
    for (who, cel), (f, l, n) in rows[:10]:
        gap = (l - f + 1) - n
        print("    %-4s cel %-3d live steps %3d..%-3d  span %3d  drawn %2d  idle-inside %3d%s"
              % (who, cel, f, l, l - f + 1, n, gap,
                 "   <-- Vexit -> Vwalk2" if 48 <= cel <= 53 and who == "viz" else ""))
    print("    (%d cels in all)\n" % len(sp_cel))

    # P3.73: the targets are the BANK's, not the bundle's. The cels left the flame bundle
    # at P3.71, so 14,848/3,632 describe a window this data no longer answers to.
    #   WIN  = $C000..$FDFF, what two mapped blocks reach AT ONCE
    #          ($FE00-$FEFF is constant RAM under MC3, $FF00+ is always I/O)
    #   BANK = the 32 KB P3.66 measured free at physical blocks $0C-$0F — twice the window,
    #          reachable only by remapping $FFA6/$FFA7, which room_present already does
    #          after every swap.
    WIN, FREE = 0xFE00 - 0xC000, 32768
    for label, sp, sz in (("segment streams (today)", sp_var, sz_var),
                          ("raw bitmaps + shifter  ", sp_cel, sz_cel)):
        total = sum(sz.values())
        pk, step, live = peak(sp, sz, n_steps)
        print("=== %s ===" % label.strip())
        print("    whole-scene SUM      %6d B   (what P3.62 costed)" % total)
        print("    PEAK simultaneous    %6d B   at step %d, %d items live"
              % (pk, step, len(live)))
        print("    peak is %.0f%% of the sum" % (100.0 * pk / total if total else 0))
        print("    vs window %d B: %s" % (WIN, "FITS, %d B spare" % (WIN - pk) if pk <= WIN
                                          else "OVER by %d B" % (pk - WIN)))
        print("    vs 32K bank %d B: %s\n" % (FREE, "FITS" if pk <= FREE
                                              else "over by %d B" % (pk - FREE)))
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--scratch", required=True)
    ap.add_argument("--no-measure", action="store_true")
    ap.add_argument("--working-set", action="store_true",
                    help="P3.63: peak SIMULTANEOUS residency, not the sum")
    a = ap.parse_args()

    if a.working_set:
        return working_set(a.scratch)

    who, marks = trace()
    print("=== PlayCut0 traced: `play N` advances BOTH characters ===")
    for c, seq, at in marks:
        print("    %-4s -> %-8s at its step %d" % (c, seq, at))

    print("\n=== what the PORT already ships (the final approach onward) ===")
    print("    viz cels 48-56, 9 variants — measured in the tree")

    for name, ch in who.items():
        occ = occupancy(ch)
        print("\n=== %s: every cel PlayCut0 draws, and at how many phases ===" % name)
        multi = 0
        for cel in sorted(occ):
            ph = occ[cel]
            if len(ph) > 1:
                multi += 1
            print("    cel %-3d phases {%s}%s"
                  % (cel, ",".join(map(str, ph)), "   <-- MORE THAN ONE" if len(ph) > 1 else ""))
        print("    %d cels, %d variants, %d cel(s) needing more than one phase"
              % (len(occ), sum(len(p) for p in occ.values()), multi))
        print("    ends at CharX %d, face %s" % (ch.x, "left" if ch.face == R.FACE_LEFT else "RIGHT"))

    if a.no_measure:
        return 0

    print("\n=== measured bytes (converted + prepared into scratch; tree untouched) ===")
    total = 0
    for name, ch in who.items():
        occ = occupancy(ch)
        sizes = measure(occ, pathlib.Path(a.scratch) / name,
                        lambda c, n=name: ("v" if n == "viz" else "p") + str(c))
        got = {k: v for k, v in sizes.items() if v}
        miss = [k for k, v in sizes.items() if not v]
        n = sum(got.values())
        total += n
        print("    %-4s %2d variants measured, %6d B%s"
              % (name, len(got), n, "   (%d unmeasurable: %s)" % (len(miss), miss[:4]) if miss else ""))
    print("    ALL OF PlayCut0's characters: %d B" % total)
    return 0


if __name__ == "__main__":
    sys.exit(main())
