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
    """(labels, tokens) for every block, as ONE stream so a goto can cross blocks."""
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
                break
            if m.group(1):
                labels[m.group(1)] = len(toks)
            toks += [x.strip() for x in m.group(3).split(",")]
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
                spx = R.draw_x(self.x, fdx, fchk, self.face) + CENTRING
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--scratch", required=True)
    ap.add_argument("--no-measure", action="store_true")
    a = ap.parse_args()

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
