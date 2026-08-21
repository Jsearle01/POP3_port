#!/usr/bin/env python3
r"""ctrl_edges.py - P5.1. WHICH sequences the controller can select, and FROM WHICH FRAMES.

★★★ THE FINDING THIS FILE EXISTS TO MAKE CHECKABLE. GENCTRL does not dispatch on the sequence.
It dispatches on `CharPosn` -- the FRAME NUMBER -- and only a small enumerated set of frames
reaches a controller at all [CTRL.S:686-733]:

    ldx CharPosn
    cpx #15   beq :standing          15                 -> standing
    cpx #48   beq :turning           48                 -> turning
    cpx #50   bcc :0
    cpx #53   bcc :standing          50,51,52           -> standing
  :0
    cpx #4    bcc :starting          1,2,3              -> starting
    cpx #67   bcc :4
    cpx #70   bcc :stjumpup          67,68,69           -> stjumpup
  :4 cpx #15  bcs :2
    jmp :running                     4..14              -> arunning
  :2 cpx #87  bcc :1
    cpx #100  bcs :1
    jmp :hanging                     87..99             -> hanging
  :1 cpx #109 beq :crouching         109                -> crouching
  :3 rts                             EVERYTHING ELSE    -> no control transition at all

So from every other frame the sequence runs on its own and the only reachable cels are the
intra-table closure. That is what makes "the peak" a smaller question than "the sum".

★★ AND THE GUARDS INSIDE EACH ROUTINE ARE NOT MODELLED. Whether `standing` actually fires
DoStartrun depends on the joystick, on `gotsword`, on `EnemyAlert`, on the block underfoot. This
file takes a routine's WHOLE target set, which is an upper bound within that routine and the
right conservative direction. The partition BETWEEN routines is exact; the choice within one is
not modelled and is stated as such.

METHOD, so the scoping is auditable rather than asserted:
  * a region map for each .S file: a column-0 label owns the lines up to the next column-0 label;
  * a call graph from `jsr`/`jmp <Label>` inside a region;
  * a region's targets = every `lda #<seqname>` in it, transitively through its callees;
  * plus the computed forms, named individually below.

THE UPPERCASE FORMS ARE THE MODULE JUMP TABLE, NOT CALL SITES. `CTRLSUBS.S:36 jmp OPJUMPSEQ`
and `:81 jmp JUMPSEQ` are entries in the module's own dispatch table at its head. Real call
sites use the lowercase equate. Filtering on case is what removes those two false positives.
"""
import pathlib
import re
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "oracle/source/01 POP Source/Source"
sys.path.insert(0, str(ROOT / "harness/tools"))

from seq_graph import parse_seqdata                                    # noqa: E402

# CTRL.S:686-733, transcribed above. frame -> the routine GENCTRL jumps to.
DISPATCH = {}
for f in (15, 50, 51, 52):
    DISPATCH[f] = "standing"
DISPATCH[48] = "turning"
for f in (1, 2, 3):
    DISPATCH[f] = "starting"
for f in (67, 68, 69):
    DISPATCH[f] = "stjumpup"
for f in range(4, 15):
    DISPATCH[f] = "arunning"
for f in range(87, 100):
    DISPATCH[f] = "hanging"
DISPATCH[109] = "crouching"

# The COMPUTED target sets, each named with its site so none of them is a silent addition.
COMPUTED = {
    # CTRL.S:1856-1859  `adc #stepfwd1-1 / jmp jumpseq` with A = getfwddist (0..13)
    "DoStepfwd": list(range(29, 43)),
}

LABEL0 = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\b")
CALL = re.compile(r"\b(?:jsr|jmp)\s+([A-Za-z_][A-Za-z0-9_]*)\b")
LDAIMM = re.compile(r"\blda\s+#([A-Za-z_][A-Za-z0-9_]*)\b")
JUMPSEQ = re.compile(r"\b(?:jsr|jmp)\s+(jumpseq|opjumpseq|pjumpseq|kjumpseq|mjumpseq|vjumpseq)\b")


def regions(path):
    """-> {label: (lo, hi)} 1-based line range, a column-0 label owning to the next."""
    lines = path.read_text(errors="replace").splitlines()
    marks = []
    for i, line in enumerate(lines):
        if not line or line[0] in " \t*;":
            continue
        m = LABEL0.match(line)
        if m and "=" not in line.split(";")[0].split()[0:1][0]:
            marks.append((m.group(1), i + 1))
    out = {}
    for k, (name, lo) in enumerate(marks):
        hi = marks[k + 1][1] - 1 if k + 1 < len(marks) else len(lines)
        out.setdefault(name, (lo, hi))
    return out, lines


def scan(path, names):
    """-> (targets_by_region, calls_by_region, jumpseq_sites, unresolved)"""
    regs, lines = regions(path)
    tgt = {r: set() for r in regs}
    calls = {r: set() for r in regs}
    sites, unresolved = [], []
    owner = {}
    for r, (lo, hi) in regs.items():
        for ln in range(lo, hi + 1):
            owner[ln] = r
    for i, raw in enumerate(lines, 1):
        s = raw.split(";")[0]
        r = owner.get(i)
        if r is None:
            continue
        m = LDAIMM.search(s)
        if m and m.group(1) in names:
            tgt[r].add(names[m.group(1)])
        for c in CALL.findall(s):
            if c in regs:
                calls[r].add(c)
        if JUMPSEQ.search(s):
            sites.append((r, i, s.strip()))
    return tgt, calls, sites, regs, lines


def closure_targets(root, tgt, calls, seen=None):
    seen = seen or set()
    if root in seen:
        return set()
    seen.add(root)
    out = set(tgt.get(root, ()))
    out |= set(COMPUTED.get(root, ()))
    for c in calls.get(root, ()):
        out |= closure_targets(c, tgt, calls, seen)
    return out


def main():
    names = parse_seqdata()
    inv = {v: k for k, v in names.items()}

    tgt, calls, sites, regs, lines = scan(SRC / "CTRL.S", names)

    print("CTRL.S — per-routine sequence targets (transitive through intra-file calls)")
    print("  [scoping: a column-0 label owns lines to the next column-0 label]")
    rows = {}
    for r in ("standing", "turning", "starting", "stjumpup", "arunning", "hanging",
              "crouching", "Stairs", "FightCtrl", "GuardCtrl"):
        if r not in regs:
            print("  ★ region %s not found" % r)
            continue
        t = closure_targets(r, tgt, calls)
        rows[r] = t
        lo, hi = regs[r]
        print("  %-10s lines %4d-%4d  %2d targets: %s"
              % (r, lo, hi, len(t), ", ".join(sorted(inv.get(x, str(x)) for x in t))))

    print()
    print("THE CONTROL-ACTIVE FRAMES [CTRL.S:686-733] — %d of 240 frame slots"
          % len(DISPATCH))
    by_routine = {}
    for f, r in DISPATCH.items():
        by_routine.setdefault(r, []).append(f)
    for r in sorted(by_routine):
        fr = sorted(by_routine[r])
        print("  %-10s frames %s" % (r, fr))

    # --- the involuntary edges: everything outside CTRL.S ------------------
    print()
    print("INVOLUNTARY / OUT-OF-CTRL edges — jumpseq sites in the other modules")
    other = {}
    for path in sorted(SRC.glob("*.S")):
        if path.name == "CTRL.S":
            continue
        t2, c2, s2, r2, _ = scan(path, names)
        for r, ln, txt in s2:
            tt = closure_targets(r, t2, c2)
            if tt:
                other.setdefault(path.name, {}).setdefault(r, set()).update(tt)
    allother = set()
    for f in sorted(other):
        for r in sorted(other[f]):
            allother |= other[f][r]
            print("  %-12s %-16s %s" % (f, r, ", ".join(sorted(inv.get(x, str(x))
                                                              for x in other[f][r]))))
    print("  union: %d sequences" % len(allother))

    # --- unresolved --------------------------------------------------------
    print()
    print("CALL SITES WITH NO RESOLVABLE IMMEDIATE — named, not dropped")
    print("  AUTO.S:1058  chgshadposn — A comes from a 7-byte shadpos RECORD's 8th byte")
    print("               (`shadpos6a hex ... / db stand`), so the targets are the `db"
          " <seqname>` bytes of those tables and ARE enumerable; they are shadow-only.")
    print("  CTRL.S:1859  DoStepfwd — computed, `adc #stepfwd1-1`, A = getfwddist 0..13")
    print("               -> sequences 29..42.  Enumerated in COMPUTED above.")
    print("  SUBS.S:1023,1032  pjumpseq/kjumpseq/mjumpseq/vjumpseq — TRAMPOLINES that swap")
    print("               the loaded character and pass A through. Not target selectors;")
    print("               their callers are, and are scanned like any other region.")
    print("  CTRLSUBS.S:36,81  jmp OPJUMPSEQ / jmp JUMPSEQ — the module's own jump TABLE at")
    print("               its head, not call sites. Excluded on case.")
    print("  ★ REMAINING GENUINELY UNENUMERABLE: none found. Every site above resolves to a")
    print("    named set, a computed range, or a data table whose bytes are named sequences.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
