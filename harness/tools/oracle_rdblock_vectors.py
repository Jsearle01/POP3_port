#!/usr/bin/env python3
r"""oracle_rdblock_vectors.py — P5.37 AC1 NARROW: the ORACLE's RDBLOCK answers, as committed test vectors.

Reads oracle_blueprint.lua's register trace (build/p537/oracle_bp.tr -- one boot, display frames 8840-9260)
and writes harness/data/p537_rdblock_vectors.json:

  queries   every DISTINCT (screen, block x, block y) RDBLOCK was asked in game frames 180-217 (A, X, Y at
            $D0D0, CTRLSUBS.S:149-152), with each answer it returned (A at the matching rts), the game frames
            of each answer, and who asked (guard-ctrl / kid-ctrl / physics-other).
  cmpbarr   every CMPBARR in the kid's controller ($D69E, CTRLSUBS.S:1533): A in, A out, game frame.

The 6809's self-test answers every query on the game-frame-179 map (engarde_test.py compares); a query whose
oracle answer CHANGED in the window is the game mutating its map (physics, out of scope) and is compared
against its answer BEFORE the change.

  python harness/tools/oracle_rdblock_vectors.py
"""
import collections
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import oracle_blueprint as OB                               # noqa: E402

CMPBARR = 0xD69E
OUT = ROOT / "harness/data/p537_rdblock_vectors.json"


def main():
    calls, base, _ = OB.trace_calls()
    q = collections.OrderedDict()
    for c in calls:
        if not 180 <= c["gf"] <= 217:
            continue
        k = (c["scrn"], c["x"], c["y"])
        e = q.setdefault(k, dict(scrn=k[0], x=k[1], y=k[2], answers={}, who=set()))
        e["answers"].setdefault(c.get("ret"), []).append(c["gf"])
        e["who"].add(c["ext"][0])
    # CMPBARR in the kid's controller: A at entry, A at its rts
    bar, frame, pend, inkid = [], -1, None, False
    for l in open(OB.D / "oracle_bp.tr", errors="replace"):
        m = OB.LINE.match(l)
        if not m:
            continue
        s, a, pc, ins = int(m.group(1), 16), int(m.group(2), 16), int(m.group(5), 16), m.group(6)
        if pend and pend.get("ret") is None and pend.get("armed"):
            pend["ret"] = a
            bar.append(pend)
            pend = None
        if pc == OB.MAINLOOP:
            frame += 1
        if pc == 0x22FD:
            inkid = True
        elif pc == 0x2300:
            inkid = False
        if pc == CMPBARR and inkid:
            pend = dict(gf=frame + base, a_in=a, s=s)
        elif pend and ins.startswith("rts") and s == pend["s"]:
            pend["armed"] = True
    ctrl = [dict(gf=c["gf"], who=c["ext"][0], scrn=c["scrn"], x=c["x"], y=c["y"], ret=c.get("ret"))
            for c in calls if 180 <= c["gf"] <= 217 and c["ext"][0].endswith("-ctrl")]
    out = dict(source="build/p537/oracle_bp.tr (oracle_blueprint.lua, one boot, display frames 8840-9260)",
               game_frames=[180, 217],
               controller_calls=ctrl,
               queries=[dict(scrn=e["scrn"], x=e["x"], y=e["y"],
                             answers={"%d" % r: [min(g), max(g), len(g)] for r, g in e["answers"].items()},
                             who=sorted(e["who"])) for e in q.values()],
               cmpbarr=[dict(gf=b["gf"], a_in=b["a_in"], a_out=b["ret"]) for b in bar])
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(out, indent=1) + "\n", encoding="utf-8")
    print("oracle_rdblock_vectors: %d distinct queries (%d calls), %d cmpbarr -> %s"
          % (len(q), sum(len(g) for e in q.values() for g in e["answers"].values()), len(bar), OUT))
    for b in bar:
        print("  cmpbarr gf %d: objid $%02X -> %d" % (b["gf"], b["a_in"], b["ret"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
