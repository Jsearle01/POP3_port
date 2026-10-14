#!/usr/bin/env python3
r"""oracle_blueprint.py — P5.37 §1, AC1: is the PORT'S map the ORACLE'S map?

Inputs: oracle_blueprint.lua's dumps of $B700-$BFFF from PHYSICAL main and aux RAM at three points, and its
register trace of display frames 8840-9260. The port's map is `bg_compose.Blueprint` -- the parser every
bake already uses (one home, §2F) -- of oracle/source/.../LEVELS/LEVEL0.

  BROAD   every byte of every section (BLUETYPE 720, BLUESPEC 720, LINKLOC, LINKMAP, MAP 96, INFO) of the
          port's parse against the oracle's loaded copy, at each dump point. ★ AUTHORITY: the oracle's memory
          outranks the parser (P5.37 §7). Any difference in a BAKED section stops the dispatch.
  NARROW  every RDBLOCK the oracle executed in the window ($D0D0 entry: A screen, X block x, Y block y,
          CTRLSUBS.S:136-138; result A at its final rts), attributed to the controller it ran in, against a
          reference RDBLOCK over the PORT'S table -- handler/offleft/offrt/offtop/offbot and GETLEFT..GETDOWN
          as CTRLSUBS.S:154-275 write them, screen 0 a solid block.
  EDGES   every traced query whose coordinates leave the screen, named with both sides.
  BLUESPEC  any instruction inside a controller extent that reads through the BlueSpec pointer ($26/$27).

  python harness/tools/oracle_blueprint.py
"""
import collections
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import bg_compose as BC                                     # noqa: E402

D = ROOT / "build/p537"
SECTIONS = [("BLUETYPE", 0, 720), ("BLUESPEC", 720, 1440), ("LINKLOC", 1440, 1696),
            ("LINKMAP", 1696, 1952), ("MAP", 1952, 2048), ("INFO", 2048, 2304)]
BAKED = ("BLUETYPE", "MAP")
IDMASK, BLOCK = 0x1F, 0x14                                  # EQ: idmask = %00011111; `block` objid
LINE = re.compile(r"^S=([0-9A-F]{3}) A=([0-9A-F]{2}) X=([0-9A-F]{2}) Y=([0-9A-F]{2})\|([0-9A-F]{4}): (.*)$")
RDBLOCK, AUTOCTRL, MAINLOOP = 0xD0D0, 0x5499, 0x218C
EXT = {"kid-ctrl": (0x22FD, 0x2300), "guard-ctrl": (0x235D, 0x2360)}


def blockid():
    """`block`'s objid from the oracle's own listing, not from memory."""
    for p in (ROOT / "oracle/source/obj").glob("*.LST"):
        for l in p.read_text(errors="replace").splitlines():
            m = re.search(r"=00([0-9A-F]{2})\s+\d+\s+block\s*=", l)
            if m:
                return int(m.group(1), 16)
    raise SystemExit("no `block =` in the listings")


def ref_rdblock(bp, scrn, x, y, block):
    """CTRLSUBS.S:149-173 + handler :178-198 + off* :200-234 + GET* :244-275, over the PORT's table."""
    x, y = x - 256 if x >= 128 else x, y - 256 if y >= 128 else y
    while True:
        if x < 0:
            x += 10; scrn = bp.adj(scrn, 0) if scrn else 0
        elif x >= 10:
            x -= 10; scrn = bp.adj(scrn, 1) if scrn else 0
        elif y < 0:
            y += 3; scrn = bp.adj(scrn, 2) if scrn else 0
        elif y >= 3:
            y -= 3; scrn = bp.adj(scrn, 3) if scrn else 0
        else:
            break
    if scrn == 0:
        return block, (0, x, y)
    return bp.type[(scrn - 1) * 30 + y * 10 + x] & IDMASK, (scrn, x, y)


def main():
    raw = (BC.LEVELS / "LEVEL0").read_bytes()
    bp = BC.Blueprint(raw)
    port = raw[:2304]
    block = blockid()
    print("oracle_blueprint: the port's map = bg_compose.Blueprint(LEVEL0), %d B; `block` objid = $%02X" % (len(raw), block))

    # ---------------------------------------------------------------- BROAD
    stop = False
    print("\nBROAD -- every section, port parse vs the oracle's loaded copy (physical RAM):")
    which = {}
    for fr in (7900, 8882, 9254):
        for bank in ("main", "aux"):
            o = (D / ("blueprint_%s_%d.bin" % (bank, fr))).read_bytes()
            diffs = {n: [i for i in range(a, b) if o[i] != port[i]] for n, a, b in SECTIONS}
            same = sum(1 for n in diffs if not diffs[n])
            which.setdefault(fr, {})[bank] = diffs
            print("  frame %d %-4s: %s" % (fr, bank, "  ".join(
                "%s %s" % (n, "==" if not diffs[n] else "%d diff" % len(diffs[n])) for n, _a, _b in SECTIONS)))
    # the bank that holds the level is the one whose BLUETYPE matches at load
    home = min(("main", "aux"), key=lambda b: len(which[7900][b]["BLUETYPE"]))
    print("  -> the level lives in the %s bank" % home.upper())
    for fr in (7900, 8882, 9254):
        for n in BAKED:
            if which[fr][home][n]:
                stop = stop or fr == 7900           # at load = the parser is wrong; later = the game mutated it
                o = (D / ("blueprint_%s_%d.bin" % (home, fr))).read_bytes()
                ex = [(i - dict((s[0], s[1]) for s in SECTIONS)[n], port[i], o[i]) for i in which[fr][home][n][:8]]
                print("  %s %s at frame %d: %d bytes, (offset, port, oracle) %r"
                      % ("★ BAKED SECTION DIFFERS AT LOAD:" if fr == 7900 else "(runtime: the game changed it since load)",
                         n, fr, len(which[fr][home][n]), ex))
    for n, a, b in SECTIONS:
        if n not in BAKED:
            dd = which[7900][home][n]
            print("  (not baked) %-8s at load: %s" % (n, "==" if not dd else "%d B differ" % len(dd)))

    # ---------------------------------------------------------------- NARROW + EDGES + BLUESPEC
    calls, base, bluespec = trace_calls()
    ctrl = [c for c in calls if c["ext"][0].endswith("-ctrl") and 180 <= c["gf"] <= 217]
    allw = [c for c in calls if 180 <= c["gf"] <= 217]
    bad, edges = [], []
    for c in allw:
        want, home_blk = ref_rdblock(bp, c["scrn"], c["x"], c["y"], block)
        if c.get("ret") != want:
            bad.append((c, want))
        xs = c["x"] - 256 if c["x"] >= 128 else c["x"]
        ys = c["y"] - 256 if c["y"] >= 128 else c["y"]
        if not (0 <= xs < 10 and 0 <= ys < 3):
            edges.append((c, home_blk))
    return report(bp, block, stop, ctrl, allw, bad, edges, bluespec)


def trace_calls():
    """Every RDBLOCK in oracle_bp.tr: dict(gf, scrn, x, y, ret, ext); game frame 180 = the first AUTOCTRL."""
    calls, frame, first_auto, open_ext = [], -1, None, {}
    pending = []                         # RDBLOCK entries awaiting their rts
    prev = None
    bluespec = collections.Counter()
    for raw_line in open(D / "oracle_bp.tr", errors="replace"):
        m = LINE.match(raw_line)
        if not m:
            continue
        s, a, x, y, pc, ins = (int(m.group(1), 16), int(m.group(2), 16), int(m.group(3), 16),
                               int(m.group(4), 16), int(m.group(5), 16), m.group(6))
        if prev is not None and prev[0] == "ret":
            c = prev[1]
            c["ret"] = a
            prev = None
        if pc == MAINLOOP:
            frame += 1
            open_ext = {}
        for name, (st, en) in EXT.items():
            if pc == st:
                open_ext[name] = en
            elif open_ext.get(name) == pc:
                del open_ext[name]
        if pc == AUTOCTRL and first_auto is None:
            first_auto = frame
        if pc == RDBLOCK:
            c = dict(frame=frame, scrn=a, x=x, y=y, s=s, ext=sorted(open_ext) or ["(physics/other)"])
            calls.append(c)
            pending.append(c)
        if pending and ins.startswith("rts") and s == pending[-1]["s"]:
            prev = ("ret", pending.pop())
        if open_ext and re.search(r"\(\$26\),y", ins):
            bluespec[tuple(sorted(open_ext))] += 1
    base = 180 - first_auto
    for c in calls:
        c["gf"] = c["frame"] + base
    return calls, base, bluespec


def report(bp, block, stop, ctrl, allw, bad, edges, bluespec):
    byc = collections.Counter(c["ext"][0] for c in ctrl)
    print("\nNARROW -- RDBLOCK in game frames 180-217: %d in all (%d inside a controller: %s)"
          % (len(allw), len(ctrl), dict(byc)))
    print("  each against a reference RDBLOCK over the PORT'S table: %s"
          % ("ALL %d IDENTICAL" % len(allw) if not bad else "%d DIFFER, e.g. %r" % (len(bad), bad[:3])))
    kinds = collections.Counter((c["scrn"], c["x"], c["y"], c.get("ret")) for c in ctrl)
    for (sc, x, y, r), n in sorted(kinds.items()):
        print("    controller query: screen %d, block (%d,%d) -> objid $%02X  x%d" % (sc, x, y, r, n))
    print("\nEDGES -- queries that leave the screen: %d" % len(edges))
    for c, (sc, x, y) in edges[:6]:
        print("    gf %d %s: screen %d block (%d,%d) -> home screen %d block (%d,%d) -> objid $%02X (oracle $%02X)"
              % (c["gf"], c["ext"][0], c["scrn"], c["x"] - 256 if c["x"] >= 128 else c["x"],
                 c["y"] - 256 if c["y"] >= 128 else c["y"], sc, x, y, ref_rdblock(bp, c["scrn"], c["x"], c["y"], block)[0],
                 c.get("ret", -1)))
    cbad = [(c, w) for c, w in bad if c["ext"][0].endswith("-ctrl")]
    print("  ...of which inside a CONTROLLER: %d; the rest are physics/objects (out of scope): %d"
          % (len(cbad), len(bad) - len(cbad)))
    for c, w in bad[:1] + bad[-1:]:
        print("    e.g. gf %d %s: screen %d block (%d,%d): static table $%02X, oracle returned $%02X"
              % (c["gf"], c["ext"][0], c["scrn"], c["x"], c["y"], w, c["ret"]))
    print("\nBLUESPEC reads through ($26),y inside a controller extent, frames 8840-9260: %s"
          % (dict(bluespec) or "NONE"))
    # when does the oracle's map change? first/last game frame each mutated block was read either way
    mut = collections.defaultdict(list)
    for c, w in bad:
        mut[(c["scrn"], c["x"], c["y"])].append(c["gf"])
    for k, v in sorted(mut.items()):
        print("  runtime map change seen by RDBLOCK: screen %d block (%d,%d) -- from game frame %d (%d reads)"
              % (k[0], k[1], k[2], min(v), len(v)))
    if stop or cbad:
        print("\noracle_blueprint: FAIL -- %s" % ("a baked section differs from the oracle AT LOAD" if stop
                                                 else "a CONTROLLER's RDBLOCK differs from the static table"))
        return 1
    print("\noracle_blueprint: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
