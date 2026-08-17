#!/usr/bin/env python3
r"""verify_sequences.py — the port's hand-written sequence streams against the tracer's.

WHY THIS EXISTS, AND WHY EVERY OTHER CHECK IN THE CHAIN WAS BLIND TO WHAT IT CATCHES.

The cel packer asserts that every beat's draw set is reachable from what is mapped while
that beat runs. That assertion is real and it fires. It could not catch P3.78's hang,
because BOTH SIDES OF IT CAME FROM THE SAME DERIVATION: beat_recost walks the oracle's
SEQTABLE to decide what a beat draws, and the packer then checks that answer against
pages built from the same walk. When the walk is wrong, the packer is wrong in exactly
the same way and agrees with itself.

`mame-idioms-coco3-port.md` §11 names this shape: "N/N pixels match the rule is
tautological if the rule generated the predictions — validate against independently
grounded pixels." The independently grounded thing here was sitting in the tree the whole
time: char_draw.s's `fcb` streams, transcribed from the oracle by hand in an earlier
dispatch. They disagreed with the tracer and nothing compared them.

WHAT WENT WRONG, CONCRETELY. Mechner's assembler scopes a `:`-prefixed label to the
enclosing routine and SEQTABLE.S reuses `:loop` in nearly every sequence. beat_recost read
them into one flat dict, so every `goto :loop` resolved to the LAST one parsed. `Pback`
ends `:loop db 17 / goto :loop` — the princess holds on cel 17 — and the tracer had her
holding on cel 18, `Pslump`'s loop. The packer therefore provisioned 18 for four beats
that draw 17, and never provisioned 17. The beat after Pback drew a cel sitting in an
unmapped page: a valid-looking pointer into the wrong block, which blit_cel walked as a
segment stream and never returned from. The room hung with interrupts masked.

So this compares the two transcriptions ON THE CELS THEY EMIT, which is the only thing
that matters downstream, and fails the build on any divergence.

Exit 1 on a divergence, a missing sequence, or an unparseable stream — a check that
cannot find its inputs must fail, not pass quietly.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "harness/tools"))
import beat_recost as B                                          # noqa: E402
import cel_parity_rule as R                                      # noqa: E402

SRC = ROOT / "src/engine/char_draw.s"
STEPS = 80          # well past every sequence's loop point

# port label -> the oracle sequence it transcribes (bake_scene.LABEL, inverted)
PAIRS = {"viz_stand": "Vstand", "viz_walk": "Vwalk", "viz_stop": "Vstop",
         "viz_raise": "Vraise", "viz_exit": "Vexit",
         "pri_stand": "Pstand", "pri_alert": "Palert",
         "pri_back": "Pback", "pri_slump": "Pslump"}

OPS = {0xFF: "goto", 0xFE: "aboutface", 0xFB: "chx", 0xFA: "chy", 0xF8: "setfall"}


def port_streams():
    """{label: [tokens]} from char_draw.s's fcb/fdb sequence data.

    Tokens are ints for cel numbers and ('op', name) / ('addr', label) otherwise, so the
    walker below can be the same shape as beat_recost's.
    """
    names = dict(re.findall(r"^(SEQ_\w+)\s+equ\s+\$([0-9A-Fa-f]+)", SRC.read_text(
        errors="replace"), re.M))
    code = {int(v, 16): k for k, v in names.items()}
    if not code:
        raise SystemExit("  FAIL no SEQ_* opcode definitions in %s" % SRC)

    out, order, cur = {}, [], None
    for line in SRC.read_text(errors="replace").splitlines():
        s = line.split(";")[0].rstrip()
        m = re.match(r"^(\w+)?\s+(fcb|fdb)\s+(.*)$", s)
        if not m:
            # a label alone on its line continues the current stream
            m2 = re.match(r"^(\w+)\s*$", s)
            if m2 and (m2.group(1).startswith("viz_") or m2.group(1).startswith("pri_")):
                cur = m2.group(1)
                out.setdefault(cur, [])
                order.append(cur)
            continue
        lab, kind, rest = m.group(1), m.group(2), m.group(3)
        if lab and (lab.startswith("viz_") or lab.startswith("pri_")):
            cur = lab
            out.setdefault(cur, [])
            order.append(cur)
        elif lab:
            cur = None
        if cur is None:
            continue
        for t in [x.strip() for x in rest.split(",")]:
            if not t:
                continue
            if kind == "fdb":
                out[cur].append(("addr", t))
            elif t.startswith("SEQ_"):
                out[cur].append(("op", t))
            else:
                try:
                    out[cur].append(int(t, 0) & 0xFF)
                except ValueError:
                    raise SystemExit("  FAIL cannot parse %r in %s" % (t, cur))
    return out, order


def flatten(streams, order):
    """One flat token list plus {label: index}, so a goto can cross labels as it does
    in the assembled image — the streams are laid out consecutively in the source."""
    toks, at = [], {}
    seen = set()
    for lab in order:
        if lab in seen:
            continue
        seen.add(lab)
        at[lab] = len(toks)
        toks += streams[lab]
    return toks, at


def walk_port(toks, at, start, alt, x0, face0):
    """Emit (cel, phase, x, face) per step, exactly as the 6809 vm_step does."""
    i, x, face = at[start], x0, face0
    drawn = []
    for _ in range(STEPS):
        for _guard in range(400):
            t = toks[i]; i += 1
            if isinstance(t, int):
                fdx, fchk = alt[t][1], alt[t][3]
                spx = R.draw_x(x, fdx, fchk, face, R.awid(t)) + B.CENTRING
                drawn.append((t, spx & 3, x, face))
                break
            kind, name = t
            if kind == "addr":
                i = at[name]
                continue
            op = {"SEQ_GOTO": "goto", "SEQ_ABOUTFACE": "aboutface", "SEQ_CHX": "chx",
                  "SEQ_CHY": "chy", "SEQ_SETFALL": "setfall"}[name]
            if op == "goto":
                continue                        # the fdb that follows does the jump
            if op == "aboutface":
                face = 0 if face == R.FACE_LEFT else R.FACE_LEFT
            elif op == "chx":
                d = toks[i]; i += 1
                d = d - 256 if d > 127 else d
                x += d if face == 0 else -d
            else:
                i += 1                          # chy / setfall: operand consumed unused
        else:
            raise SystemExit("  FAIL %s: runaway stream in the port's own data" % start)
    return drawn


def main():
    alt = R.altset2()
    labels, otoks = B.sequences()
    streams, order = port_streams()
    toks, at = flatten(streams, order)

    bad = 0
    for plabel, oname in sorted(PAIRS.items()):
        if plabel not in at:
            print("  FAIL %s is not in %s" % (plabel, SRC.name))
            bad = 1
            continue
        who = "viz" if plabel.startswith("viz") else "pri"
        x0, face0 = (197, R.FACE_LEFT) if who == "viz" else (120, R.FACE_LEFT)

        port = walk_port(toks, at, plabel, alt, x0, face0)
        ch = B.Char(x0, face0, oname, labels)
        for _ in range(STEPS):
            ch.step(otoks, labels, alt)
        oracle = ch.drawn

        if port == oracle:
            print("  ok   %-10s == %-8s  %d steps, cels %s..."
                  % (plabel, oname, STEPS,
                     ",".join(str(c) for c, _p, _x, _f in port[:6])))
            continue
        bad = 1
        n = next((k for k in range(min(len(port), len(oracle)))
                  if port[k] != oracle[k]), min(len(port), len(oracle)))
        print("  FAIL %s and %s diverge at step %d" % (plabel, oname, n))
        print("         port   (cel,phase,x,face) = %s" % (port[n:n + 4],))
        print("         tracer                    = %s" % (oracle[n:n + 4],))
        print("         the port's stream is a HAND transcription of the oracle and the")
        print("         tracer is a MACHINE one. Read SEQTABLE.S and fix whichever is")
        print("         wrong — do not reconcile them against each other.")

    if bad:
        print("  [sequences] the two transcriptions of the oracle DISAGREE.")
        return 1
    print("  [sequences] port streams agree with the traced oracle over %d steps, "
          "%d sequences" % (STEPS, len(PAIRS)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
