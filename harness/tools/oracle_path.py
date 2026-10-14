#!/usr/bin/env python3
r"""oracle_path.py — P5.36 AC1: which routines the ORACLE ENTERS in the AI's first window, per game frame.

Reads the instruction trace oracle_path.lua writes (`S=<sp 3 hex><PC 4 hex>: <instr>`) and the label table
oracle_symbols.py builds from the oracle's own listings. Boundaries are LISTING ADDRESSES, not guesses:
  game frame   MainLoop's `jsr rnd`            TOPCTRL.S:367  $218C   (one per game frame)
  NextFrame    `jsr DoKid` $225A -> $225D, `jsr DoShad` $225D -> $2260      TOPCTRL.S:512-514
  controllers  kid  `jsr ctrlplayer` $22FD -> $2300  (DoKid, TOPCTRL.S:644)
               guard `jsr ShadCtrl`  $235D -> $2360  (DoShad, TOPCTRL.S:711)
Game frame 180 = the frame of the first AUTOCTRL entry (P5.35 findings §3: the guard's first AutoCtrl).

For every game frame of the window it lists the labels entered (a PC equal to a label's address) inside
each extent, the RND calls, and -- the §1 stop condition -- any BLUEPRINT query: rdblock/RDBLOCK, get*infront,
getabove*, getbehind, getunderft, cmpspace, cmpbarr, cmpwall, checkledge, checkspikes. The $Dxxx vector table
is shared by address with the disk driver in another bank; inside a controller extent the game's bank is
the one mapped, so the AUTO/CTRLSUBS name is the right one there.

  python harness/tools/oracle_path.py [--tr build/p536/oracle_path.tr] [--from 180 --to 217]
"""
import argparse
import collections
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
LINE = re.compile(r"^\s*S=([0-9A-F]{3})([0-9A-F]{4}): (.*)$")
MAINLOOP_RND = 0x218C
EXTENTS = {"kid-ctrl": (0x22FD, 0x2300), "guard-ctrl": (0x235D, 0x2360),
           "DoKid": (0x225A, 0x225D), "DoShad": (0x225D, 0x2260)}
BLUEPRINT = {"rdblock", "rdblock1", "RDBLOCK", "RDBLOCK1", "getinfront", "get2infront", "getabove",
             "getaboveinf", "getabovebeh", "getbehind", "getunderft", "cmpspace", "cmpbarr", "cmpwall",
             "checkledge", "checkspikes", "getleft", "getright", "getup", "getdown"}
PREFER = ("AUTO.LST", "CTRLSUBS.LST", "CTRL.LST", "TOPCTRL.LST", "MISC.LST", "GRAFIX.LST")


def labels():
    s = json.load(open(ROOT / "build/p536/oracle_symbols.json"))
    by = collections.defaultdict(list)
    for name, (addr, f) in s.items():
        by[addr].append((name, f))
    out = {}
    for addr, names in by.items():
        names.sort(key=lambda nf: PREFER.index(nf[1]) if nf[1] in PREFER else 99)
        out[addr] = names[0][0]
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tr", default=str(ROOT / "build/p536/oracle_path.tr"))
    ap.add_argument("--from", dest="lo", type=int, default=180)
    ap.add_argument("--to", dest="hi", type=int, default=217)
    ap.add_argument("--json", default=str(ROOT / "build/p536/oracle_path.json"))
    a = ap.parse_args()
    lab = labels()
    autoctrl = next(k for k, v in lab.items() if v == "AUTOCTRL")
    rnd = next(k for k, v in lab.items() if v == "RND")
    frames = []                 # per game frame (relative): {extent: [labels entered in order]}
    cur = None
    open_ext = {}               # extent -> end PC while inside
    first_auto = None
    for raw in open(a.tr, errors="replace"):
        m = LINE.match(raw)
        if not m:
            continue
        pc = int(m.group(2), 16)
        if pc == MAINLOOP_RND:
            cur = dict(ents=collections.defaultdict(list), rnd=[])
            frames.append(cur)
            open_ext = {}
            continue
        if cur is None:
            continue
        for name, (start, end) in EXTENTS.items():
            if pc == start:
                open_ext[name] = end
            elif open_ext.get(name) == pc:
                del open_ext[name]
        if pc == autoctrl and first_auto is None:
            first_auto = len(frames) - 1
        if pc == rnd:
            cur["rnd"].append(sorted(open_ext) or ["(outside the controllers)"])
        name = lab.get(pc)
        if name:
            for e in open_ext:
                lst = cur["ents"][e]
                if not lst or lst[-1] != name:
                    lst.append(name)
    if first_auto is None:
        raise SystemExit("oracle_path: no AUTOCTRL entry in the trace")
    base = 180 - first_auto
    report, any_bp = {}, collections.Counter()
    print("oracle_path: %d game frames in the trace; game frame 180 = trace frame %d (first AUTOCTRL)"
          % (len(frames), first_auto))
    union = collections.defaultdict(set)
    for i, fr in enumerate(frames):
        g = base + i
        if not a.lo <= g <= a.hi:
            continue
        row = {e: fr["ents"].get(e, []) for e in EXTENTS}
        row["rnd"] = fr["rnd"]
        report[g] = row
        for e in EXTENTS:
            union[e].update(row[e])
            for n in row[e]:
                if n in BLUEPRINT:
                    any_bp[(e, n)] += 1
        ai = [n for n in row["guard-ctrl"] if n not in ("SHADCTRL",)]
        kid = row["kid-ctrl"]
        print("  gf %3d  guard-ctrl: %s" % (g, " > ".join(ai) or "-"))
        if "AUTOCTRL" in kid:
            print("          kid-ctrl:   %s" % " > ".join(kid))
        ai_rnd = [r for r in fr["rnd"] if any(x.endswith("-ctrl") for x in r)]
        if ai_rnd:
            print("          RND inside a controller: %d  %r" % (len(ai_rnd), ai_rnd))
    print()
    for e in ("guard-ctrl", "kid-ctrl", "DoShad", "DoKid"):
        print("UNION %-10s (%d labels): %s" % (e, len(union[e]), ", ".join(sorted(union[e]))))
    print()
    ctrl_bp = {k: v for k, v in any_bp.items() if k[0].endswith("-ctrl")}
    print("BLUEPRINT QUERIES inside a CONTROLLER (the §1 stop condition): %s"
          % (", ".join("%s %s x%d" % (k[0], k[1], v) for k, v in sorted(ctrl_bp.items())) or "NONE"))
    rest = {k: v for k, v in any_bp.items() if not k[0].endswith("-ctrl")}
    print("blueprint queries elsewhere in DoKid/DoShad (animation, physics): %s"
          % (", ".join("%s %s x%d" % (k[0], k[1], v) for k, v in sorted(rest.items())) or "none"))
    n_ai_rnd = sum(1 for g in report for r in report[g]["rnd"] if any(x.endswith("-ctrl") for x in r))
    print("RND calls inside a controller, game frames %d-%d: %d" % (a.lo, a.hi, n_ai_rnd))
    pathlib.Path(a.json).write_text(json.dumps({str(k): v for k, v in report.items()}, indent=0))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
