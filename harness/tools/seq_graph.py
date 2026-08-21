#!/usr/bin/env python3
r"""seq_graph.py - P5.1. The kid's sequence graph, and the PEAK reachable cel set.

★★★ WHY THIS EXISTS. P5.0 reported 211 cels / 50,890 B as the kid's residency requirement and
argued it from an assertion about the move graph -- "he can enter any move at any moment" --
without reading the move graph. That is a SUM being reported as a PEAK, which is this project's
signature error. This file reads the graph.

WHAT IT READS, all oracle source, all cited:
  SEQTABLE.S          org $3000: 114 `dw <label>` entries, then the byte streams. Positive bytes
                      are frame numbers ($01..$F0); negative bytes are opcodes ($F1..$FF).
  COLL.S:994 ANIMCHAR the interpreter, and therefore the OPERAND COUNTS -- taken from the
                      dispatch chain itself, not from the equate list:
                        chx/chy/act/tap/effect  1 operand
                        setfall                 2 operands
                        goto/ifwtless           2 operands (a `dw` address)
                        aboutface/up/down/die/jaru/jard/nextlevel   0
                      `die` is a NO-OP in ANIMCHAR (`:no9 cmp #die / bne :no10 / jmp :next`).
                      ANIMCHAR returns on the FIRST frame byte, so a `goto` costs no frame.
  SEQDATA.S           sequence NAME -> NUMBER (1..114). Note SEQTABLE.S does not `put` this;
                      its labels are stream labels and the equates live on the game's side.
  CTRLSUBS.S:693      JUMPSEQ -- `In: A = sequence # (1-127)`, indexes seqtab. The only routine
                      besides ANIMCHAR's `goto` that writes CharSeq, other than AUTO.S:1881
                      restoring a guard's raw pointer from the blueprint.
  CTRLSUBS.S:1680     usealtsets -- `ldx CharID / beq ]rts ;kid uses main set`. So for THE KID
                      every frame number resolves through Fdef, which is what makes a kid-only
                      census well defined.

  decodeim and the CoCo3 footprint are IMPORTED from P5.0's tools rather than re-derived
  (demo_frame_census.decodeim, demo_asset_census.read_table/coco3_bytes). One home each.

WHAT A "NODE" IS, AND WHY IT IS A LABEL RATHER THAN A SEQUENCE NUMBER.
  Streams jump into each other's middles -- `running` is `act,1 / goto runcyc1`, and runcyc1 sits
  inside startrun's body. So the graph is over LABELS: every seqtab entry plus every goto/ifwtless
  target. A node's BODY runs from its label to the first UNCONDITIONAL goto, falling through any
  intervening labels; its OWN CEL SET is the frames in that body; its OUT-EDGES are that goto's
  target plus any ifwtless targets passed on the way.

★★ WHAT THIS FILE CANNOT DO, STATED UP FRONT. The control-driven edges are guarded by game state
  (CharAction, CharPosn, joystick, collision) and CTRL.S dispatches on that state, not on the
  sequence id. The TARGETS are enumerable; the GUARDS are not, short of modelling 2,168 lines of
  CTRL.S. So every control-inclusive figure this file prints is an UPPER bound over an
  unguarded graph, and is labelled as one. The intra-table figures are exact.
"""
import argparse
import pathlib
import re
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "oracle/source/01 POP Source/Source"
IMAGES = ROOT / "oracle/source/01 POP Source/Images"
sys.path.insert(0, str(ROOT / "harness/tools"))

from demo_asset_census import read_table, coco3_bytes          # noqa: E402
from demo_frame_census import parse_framedef, decodeim         # noqa: E402

# COLL.S:994 ANIMCHAR — operand counts read off the dispatch chain.
OPS = {
    "goto": (-1, 2), "aboutface": (-2, 0), "up": (-3, 0), "down": (-4, 0),
    "chx": (-5, 1), "chy": (-6, 1), "act": (-7, 1), "setfall": (-8, 2),
    "ifwtless": (-9, 2), "die": (-10, 0), "jaru": (-11, 0), "jard": (-12, 0),
    "effect": (-13, 1), "tap": (-14, 1), "nextlevel": (-15, 0),
}

LABEL_RE = re.compile(r"^(:?[A-Za-z_][A-Za-z0-9_]*)\s+(db|dw)\s+(.*)$")
BARE_LABEL_RE = re.compile(r"^(:?[A-Za-z_][A-Za-z0-9_]*)\s*$")
DIR_RE = re.compile(r"^\s+(db|dw)\s+(.*)$")


# ------------------------------------------------------------------ parsing
def parse_seqtable():
    """-> (items, labels, entries)

    items   a flat list of ('op',name) | ('num',int) | ('addr',label)
    labels  label -> index into items.  Local labels (`:loop`) are qualified with the
            most recent global label, because SEQTABLE.S reuses `:loop` in many streams.
    entries the 114 seqtab entries, entries[n] = label for sequence n (1-based)
    """
    text = (SRC / "SEQTABLE.S").read_text(errors="replace").splitlines()
    items, labels, entries = [], {}, {}
    scope = ""
    in_table = True

    def qual(name):
        return (scope + name) if name.startswith(":") else name

    def emit(kind, body):
        nonlocal in_table
        for tok in body.split(","):
            tok = tok.split(";")[0].strip()
            if not tok:
                continue
            if kind == "dw":
                items.append(("addr", qual(tok)))
            elif tok in OPS:
                items.append(("op", tok))
            else:
                items.append(("num", int(tok)))

    for raw in text:
        line = raw.rstrip()
        if not line or line.lstrip().startswith("*"):
            continue
        s = line.split(";")[0].rstrip()
        if not s:
            continue
        # The 114-entry table: ":N dw label", N running 1..114 IN ORDER.
        # ★ The order test is what keeps a later local label (`:1 dw stepfloat`)
        # out of the table. An `in_table` flag flipped by the first non-matching
        # line does NOT work -- ` org org` sits above the table and clears it.
        m = re.match(r"^:(\d+)\s+dw\s+(\S+)\s*$", s.strip())
        if m and in_table and int(m.group(1)) == len(entries) + 1:
            entries[int(m.group(1))] = m.group(2)
            if len(entries) == 114:
                in_table = False
            continue
        m = LABEL_RE.match(s)
        if m:
            name, kind, body = m.group(1), m.group(2), m.group(3)
            if not name.startswith(":"):
                scope = name
            labels.setdefault(qual(name), len(items))
            emit(kind, body)
            continue
        m = BARE_LABEL_RE.match(s)
        if m:
            name = m.group(1)
            if name in ("eof",):
                continue
            if not name.startswith(":"):
                scope = name
            labels.setdefault(qual(name), len(items))
            continue
        m = DIR_RE.match(s)
        if m:
            emit(m.group(1), m.group(2))
            continue
        # `org`, `lst`, `tr`, equates — not stream content
    return items, labels, entries


# ------------------------------------------------------------------ the walk
def walk(items, labels, start_label, limit=4000):
    """ANIMCHAR's semantics from `start_label` to the first UNCONDITIONAL goto.

    -> dict(frames=set, acts=set, out=[labels], cond=[labels], fell_off=bool, steps=int)
    """
    i = labels[start_label]
    frames, acts, cond = set(), set(), []
    steps = 0
    while i < len(items) and steps < limit:
        steps += 1
        kind, v = items[i]
        if kind == "op":
            n, nargs = OPS[v]
            if v == "goto":
                tgt = items[i + 1][1]
                return dict(frames=frames, acts=acts, out=[tgt], cond=cond,
                            fell_off=False, steps=steps)
            if v == "ifwtless":
                cond.append(items[i + 1][1])
                i += 2
                continue
            if v == "act":
                acts.add(items[i + 1][1] & 0xFF)
            i += 1 + nargs
            continue
        if kind == "num":
            b = v & 0xFF
            if 1 <= b <= 240:
                frames.add(b)
            i += 1
            continue
        # a bare ('addr', ...) with no preceding goto/ifwtless: the stream ran into
        # the next sequence's table entry. Should not happen; reported if it does.
        return dict(frames=frames, acts=acts, out=[], cond=cond, fell_off=True, steps=steps)
    return dict(frames=frames, acts=acts, out=[], cond=cond, fell_off=True, steps=steps)


# ------------------------------------------------------------------ cels
class Cels:
    """Frame number -> the kid's (table, index) -> CoCo3 bytes.  Fdef only: usealtsets
    returns immediately for CharID 0, so the kid never reads an alt set."""

    SLOT_FILE = {0: "IMG.CHTAB1", 1: "IMG.CHTAB2", 2: "IMG.CHTAB3", 3: "IMG.CHTAB4.GD",
                 4: "IMG.CHTAB5", 5: "IMG.CHTAB6.A", 6: "IMG.CHTAB7", 7: "IMG.CHTAB6.B"}

    def __init__(self, which="Fdef"):
        self.fd = parse_framedef()[which]
        self.tabs = {}
        for slot, name in self.SLOT_FILE.items():
            _, c, _ = read_table(IMAGES / name)
            self.tabs[slot] = c

    def cel_of(self, frame):
        """-> (table, image) or None for a blank frame slot."""
        e = self.fd.get(frame)
        if e is None:
            return None
        fi, fs = e
        if fi == 0 and fs == 0:
            return None
        return decodeim(fi, fs)

    def cels(self, frames):
        out = set()
        for f in frames:
            c = self.cel_of(f)
            if c:
                out.add(c)
        return out

    def bytes_of(self, cels):
        n = 0
        for t, im in cels:
            tab = self.tabs.get(t) or []
            if 1 <= im <= len(tab) and tab[im - 1]:
                cel = tab[im - 1]
                n += coco3_bytes(cel["w"], cel["h"])
        return n


# ------------------------------------------------------------------ control edges
SEQ_NAMES = None


def parse_seqdata():
    names = {}
    for line in (SRC / "SEQDATA.S").read_text(errors="replace").splitlines():
        m = re.match(r"^(\w+)\s*=\s*(\d+)\s*$", line.strip())
        if m and 1 <= int(m.group(2)) <= 114:
            names[m.group(1)] = int(m.group(2))
    return names


def control_targets(names, window=10):
    """Every sequence id a `jumpseq`/`opjumpseq` call site can be reached with.

    ★ THE HEURISTIC IS STATED BECAUSE IT IS THE WEAK LINK: the nearest preceding
    `lda #<seqname>` within `window` lines. Sites with no such load are UNRESOLVED and
    are returned separately rather than dropped -- 'I could not enumerate these' is a
    result; silently omitting them would make the peak a fiction.
    """
    hits, unresolved = {}, []
    for path in sorted(SRC.glob("*.S")):
        lines = path.read_text(errors="replace").splitlines()
        for i, line in enumerate(lines):
            s = line.split(";")[0]
            if not re.search(r"\b(jsr|jmp)\s+(jumpseq|opjumpseq)\b", s, re.I):
                continue
            found = None
            for j in range(i, max(-1, i - window), -1):
                m = re.search(r"\blda\s+#(\w+)\b", lines[j].split(";")[0])
                if m and m.group(1) in names:
                    found = m.group(1)
                    break
            if found:
                hits.setdefault(found, []).append("%s:%d" % (path.name, i + 1))
            else:
                unresolved.append("%s:%d  %s" % (path.name, i + 1, s.strip()))
    return hits, unresolved


# ------------------------------------------------------------------ report
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=None, help="write the graph artifact here (markdown)")
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()

    items, labels, entries = parse_seqtable()
    names = parse_seqdata()
    cels = Cels("Fdef")

    print("SEQTABLE.S: %d stream items, %d labels, %d seqtab entries"
          % (len(items), len(labels), len(entries)))
    missing = [n for n in range(1, 115) if n not in entries]
    if missing:
        print("  ★ seqtab entries missing: %s" % missing)

    # --- nodes -----------------------------------------------------------
    node_labels = set(entries.values())
    frontier = list(node_labels)
    bodies = {}
    fell_off, unknown = [], []
    while frontier:
        lab = frontier.pop()
        if lab in bodies:
            continue
        if lab not in labels:
            unknown.append(lab)
            bodies[lab] = dict(frames=set(), acts=set(), out=[], cond=[], fell_off=True, steps=0)
            continue
        b = walk(items, labels, lab)
        bodies[lab] = b
        if b["fell_off"]:
            fell_off.append(lab)
        for t in b["out"] + b["cond"]:
            node_labels.add(t)
            if t not in bodies:
                frontier.append(t)

    print("  nodes (seqtab entries + goto/ifwtless targets): %d" % len(bodies))
    if unknown:
        print("  ★ goto targets with no label in SEQTABLE.S: %s" % sorted(set(unknown)))
    print("  bodies that ran off the end without an unconditional goto: %s"
          % (sorted(fell_off) if fell_off else "none"))

    # --- AC3: the union check -------------------------------------------
    all_frames = set()
    for b in bodies.values():
        all_frames |= b["frames"]
    graph_cels = cels.cels(all_frames)
    graph_bytes = cels.bytes_of(graph_cels)

    fd_frames = set(cels.fd)
    fd_cels = cels.cels(fd_frames)
    fd_bytes = cels.bytes_of(fd_cels)

    print()
    print("AC3 — UNION CHECK")
    print("  every frame named by any sequence stream : %d frames -> %d cels, %d B"
          % (len(all_frames), len(graph_cels), graph_bytes))
    print("  every frame slot defined in Fdef         : %d frames -> %d cels, %d B"
          % (len(fd_frames), len(fd_cels), fd_bytes))
    print("  P5.0's figure                            : 211 cels, 50,890 B")
    verdict = "PASS" if (len(fd_cels), fd_bytes) == (211, 50890) else "DISCREPANCY"
    print("  Fdef-total vs P5.0: %s" % verdict)
    orphan = sorted(f for f in fd_frames
                    if f not in all_frames and cels.cel_of(f) is not None)
    print("  frames DEFINED in Fdef but named by NO sequence stream: %d %s"
          % (len(orphan), orphan))

    # --- per-node table --------------------------------------------------
    rows = []
    for lab in sorted(bodies):
        b = bodies[lab]
        c = cels.cels(b["frames"])
        rows.append((lab, len(b["frames"]), len(c), cels.bytes_of(c),
                     sorted(b["acts"]), b["out"] + ["?%s" % x for x in b["cond"]]))

    # --- reachability ----------------------------------------------------
    def closure(start, depth):
        seen, cur = {start}, {start}
        for _ in range(depth):
            nxt = set()
            for n in cur:
                for t in bodies[n]["out"] + bodies[n]["cond"]:
                    if t not in seen:
                        nxt.add(t)
            seen |= nxt
            cur = nxt
            if not cur:
                break
        return seen

    def cost(nodes):
        fr = set()
        for n in nodes:
            fr |= bodies[n]["frames"]
        c = cels.cels(fr)
        return len(c), cels.bytes_of(c)

    print()
    print("AC4 — PEAKS OVER THE INTRA-TABLE GRAPH ONLY (goto + ifwtless edges; EXACT)")
    for depth in (0, 1, 2, 99):
        vals = []
        for lab in bodies:
            n, b = cost(closure(lab, depth))
            vals.append((b, n, lab))
        vals.sort()
        med = vals[len(vals) // 2]
        lo, hi = vals[0], vals[-1]
        tag = "transitive closure" if depth == 99 else "depth %d" % depth
        print("  %-20s max %5d B (%3d cels) at %-16s   median %5d B   min %5d B"
              % (tag, hi[0], hi[1], hi[2], med[0], lo[0]))

    # --- control edges ---------------------------------------------------
    hits, unresolved = control_targets(names)
    print()
    print("AC1 — CONTROL-DRIVEN EDGE TARGETS (jumpseq / opjumpseq)")
    print("  distinct sequence ids the control code loads: %d of 114" % len(hits))
    print("  UNRESOLVED call sites (no `lda #<seqname>` within 10 lines): %d" % len(unresolved))
    for u in unresolved:
        print("      %s" % u)
    ctl_labels = set()
    for nm in hits:
        lab = entries.get(names[nm])
        if lab:
            ctl_labels.add(lab)
    n, b = cost(ctl_labels)
    print("  union of every control-selectable sequence's OWN body: %d cels, %d B" % (n, b))
    tn, tb = cost(set().union(*[closure(l, 99) for l in ctl_labels])) if ctl_labels else (0, 0)
    print("  ...and their transitive closure: %d cels, %d B" % (tn, tb))

    # --- the CharSword partition ----------------------------------------
    print()
    print("THE PARTITION THE CODE ITSELF DRAWS — GENCTRL branches on CharSword")
    print("  [CTRL.S:648 GENCTRL: `lda CharSword / cmp #2 / beq FightCtrl`]")
    fight_frames = set(f for f in all_frames if 150 <= f <= 189)
    norm_frames = set(f for f in all_frames if f < 150 or f > 189)
    for tag, fr in (("frames 150-189 (the fighting band)", fight_frames),
                    ("everything else", norm_frames)):
        c = cels.cels(fr)
        print("  %-36s %3d frames -> %3d cels, %6d B" % (tag, len(fr), len(c), cels.bytes_of(c)))

    if args.verbose:
        print()
        print("PER-NODE TABLE")
        print("  %-20s %5s %5s %8s  %-10s %s" % ("label", "frms", "cels", "coco3B", "act", "out"))
        for lab, nf, nc, nb, acts, out in rows:
            print("  %-20s %5d %5d %8d  %-10s %s" % (lab, nf, nc, nb, acts, ",".join(out)))

    if args.out:
        write_artifact(args.out, bodies, entries, names, rows, cels, hits, unresolved,
                       closure, cost, all_frames, fd_cels, fd_bytes)
        print("\n  -> %s" % args.out)
    return 0


def write_artifact(path, bodies, entries, names, rows, cels, hits, unresolved,
                   closure, cost, all_frames, fd_cels, fd_bytes):
    inv = {v: k for k, v in names.items()}
    lab2num = {}
    for n, lab in entries.items():
        lab2num.setdefault(lab, n)
    out = []
    out.append("| # | sequence | label | frames | cels | CoCo3 B | act | out-edges |")
    out.append("|---|---|---|---|---|---|---|---|")
    for n in sorted(entries):
        lab = entries[n]
        b = bodies.get(lab)
        if b is None:
            continue
        c = cels.cels(b["frames"])
        out.append("| %d | `%s` | `%s` | %d | %d | %d | %s | %s |"
                   % (n, inv.get(n, "?"), lab, len(b["frames"]), len(c),
                      cels.bytes_of(c), ",".join(str(a) for a in sorted(b["acts"])) or "—",
                      ", ".join("`%s`" % x for x in b["out"] + b["cond"]) or "—"))
    pathlib.Path(path).write_text("\n".join(out) + "\n", encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
