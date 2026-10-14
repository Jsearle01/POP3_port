#!/usr/bin/env python3
r"""engarde_test.py — P5.37 §3: what the 6809 COMPUTED in the en-garde window, against the ORACLE.

run_engarde_test.sh runs build/engarde_gate.dmk (the gate's own disk) for the window's 38 game frames and
dumps the AI's logs (src/engine/guard_ai.s: GA_LOG, GA_GPLOG, GA_RLOG, GA_TQOUT) and its state. This compares:

  AC8   the guard's 16-byte record after every game frame 180-217 vs the oracle's S= (engarde_expect.json);
        Seq through the sq_XXXX labels (port address -> the oracle's SEQTABLE address)
  AC9   RND calls: 0 (ga_rnd_calls)
  AC12  guardprog per game frame vs the oracle's (5 -> 11 written by the KID's controller at 215)
  AC1   NARROW: every map read the 6809's controllers made, in order, vs the oracle's (harness/data/
        p537_rdblock_vectors.json: the trace's guard-ctrl and kid-ctrl RDBLOCK calls with their answers);
        the self-test: the 26 distinct queries + cmpbarr on this map; EDGES named
  --mode ea|map   the NEGATIVE CONTROLS: the record must DIFFER; the margin is reported as numbers

  python harness/tools/engarde_test.py --mode gate|ea|map
  python harness/tools/engarde_test.py --dumpspec        # the runner's P_DUMPMEM
"""
import argparse
import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SRC = ROOT / "src/engine/guard_ai.s"
MAP = ROOT / "build/obj/engarde.map"
EXP = ROOT / "build/gen/engarde_expect.json"
VEC = ROOT / "harness/data/p537_rdblock_vectors.json"
FIELDS = "Posn X Y Face BlockX BlockY Action XVel YVel SeqL SeqH Scrn Repeat ID Sword Life".split()
NFR = 38
WHO = {0x00: "guard-ctrl", 0x80: "kid-ctrl"}


def equ(name):
    m = re.search(r"^%s\s+equ\s+\$([0-9A-Fa-f]+)" % name, SRC.read_text(encoding="utf-8"), re.M)
    return int(m.group(1), 16)


def syms():
    out = {}
    for l in MAP.read_text().splitlines():
        m = re.match(r"^Symbol: (\S+) \(.*\) = ([0-9A-F]+)$", l)
        if m:
            out[m.group(1)] = int(m.group(2), 16)
    return out


def dumpspec():
    s = syms()
    v0, v1 = s["ga_char"], s["ga_mode"] + 1
    return ";".join([
        "%04X:%d:build/engarde_log.bin" % (equ("GA_LOG"), 16 * NFR),
        "%04X:%d:build/engarde_gp.bin" % (equ("GA_GPLOG"), NFR),
        "%04X:%d:build/engarde_rlog.bin" % (equ("GA_RLOG"), 6 * 80),
        "%04X:%d:build/engarde_tq.bin" % (equ("GA_TQOUT"), 2 * 26),
        "%04X:%d:build/engarde_vars.bin" % (v0, v1 - v0)])


def s8(v):
    return v - 256 if v >= 128 else v


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", default="gate", choices=("gate", "ea", "map"))
    ap.add_argument("--dumpspec", action="store_true")
    a = ap.parse_args()
    if a.dumpspec:
        print(dumpspec())
        return 0
    s = syms()
    exp = json.loads(EXP.read_text())
    vec = json.loads(VEC.read_text())
    sq = {v: int(k[3:], 16) for k, v in s.items() if re.match(r"^sq_[0-9A-F]{4}$", k)}
    rd = lambda n: (ROOT / ("build/engarde_%s.bin" % n)).read_bytes()
    log, gp, rlog, tq, var = rd("log"), rd("gp"), rd("rlog"), rd("tq"), rd("vars")
    V = lambda name, n=1: var[s[name] - s["ga_char"]:s[name] - s["ga_char"] + n]
    err, gf, nrl = V("ga_err")[0], V("ga_gf")[0], V("ga_nrl")[0]
    rnd = int.from_bytes(V("ga_rnd_calls", 2), "big")
    print("engarde_test [%s]: ga_err %d, game frames run %d of %d, RND calls %d, map reads logged %d, mode $%02X"
          % (a.mode, err, gf, NFR, rnd, nrl, V("ga_mode")[0]))
    ok = True

    # ---------------- the records, oracle form (Seq through the labels)
    got = []
    for i in range(NFR):
        r = bytearray(log[16 * i:16 * i + 16])
        p = r[9] << 8 | r[10]
        o = sq.get(p)
        if o is None:
            r[9], r[10] = 0xEE, 0xEE                # a Seq outside the emitted sequences: never equal
        else:
            r[9], r[10] = o & 0xFF, o >> 8
        got.append(bytes(r))
    want = [bytes.fromhex(h) for h in exp["guard"]]
    per = [[FIELDS[k] for k in range(16) if g[k] != w[k]] for g, w in zip(got, want)]
    ndiff = sum(1 for d in per if d)

    if a.mode != "gate":
        nb = [sum(1 for x, y in zip(g, w) if x != y) for g, w in zip(got, want)]
        dd = [n for n in nb if n]
        first = next((exp["gf0"] + i for i, n in enumerate(nb) if n), None)
        print("engarde_test: CONTROL %s -> %d of %d game frames differ (first gf %s); fewest differing bytes in a "
              "differing frame %d" % (a.mode, ndiff, NFR, first, min(dd) if dd else 0))
        if first is not None:
            i = first - exp["gf0"]
            print("  gf %d: 6809 %s  oracle %s  (%s)" % (first, got[i].hex().upper(), want[i].hex().upper(),
                                                        ",".join(per[i])))
            if a.mode == "map":
                p = log[16 * i + 9] << 8 | log[16 * i + 10]
                print("  -> the guard's Seq at gf %d is oracle $%04X, Posn %d: %s" % (
                    first, sq.get(p, 0), got[i][0],
                    "the RETREAT sequence ($31A4-$31B1) -- EnGarde took :gap -> DoRetreat"
                    if 0x31A4 <= sq.get(p, 0) <= 0x31B1 else "NOT the retreat sequence"))
        good = ndiff > 0 and err == 0 and gf == NFR
        print("engarde_test: CONTROL %s %s" % (a.mode, "DISCRIMINATES (the check FAILS, as it must)" if good
                                               else "★ DOES NOT DISCRIMINATE / did not run"))
        return 0 if good else 1

    ok &= err == 0 and gf == NFR
    print("AC8  the guard's record, %d game frames: %s" % (NFR, "ALL IDENTICAL to the oracle's S=" if not ndiff
                                                         else "%d DIFFER" % ndiff))
    for i, d in enumerate(per):
        if d:
            print("     gf %d: 6809 %s  oracle %s  (%s)" % (exp["gf0"] + i, got[i].hex().upper(),
                                                         want[i].hex().upper(), ",".join(d)))
    ok &= not ndiff
    print("AC9  RND calls: %d %s" % (rnd, "-- zero, as the window is" if rnd == 0 else "★ NOT ZERO"))
    ok &= rnd == 0
    gpd = [(exp["gf0"] + i, g, w) for i, (g, w) in enumerate(zip(gp, exp["guardprog"])) if g != w]
    print("AC12 guardprog per game frame: %s; 5 -> 11 at gf %s (the KID's controller, DemoCtrl)"
          % ("IDENTICAL" if not gpd else "DIFFER %r" % gpd[:3],
             next((exp["gf0"] + i for i, g in enumerate(gp) if g == 11), None)))
    ok &= not gpd

    # ---------------- AC1 NARROW: the controllers' map reads, in order
    mine = []
    for i in range(min(nrl, 80)):
        e = rlog[6 * i:6 * i + 6]
        mine.append((exp["gf0"] + e[0], WHO.get(e[1], "?%02X" % e[1]), e[2], s8(e[3]), s8(e[4]), e[5]))
    fights = {m[0] for m in mine if m[1] == "kid-ctrl"}
    orc = [(c["gf"], c["who"], c["scrn"], s8(c["x"]), s8(c["y"]), c["ret"]) for c in vec["controller_calls"]
           if c["who"] == "guard-ctrl" or c["gf"] in fights]
    demo = [c for c in vec["controller_calls"] if c["who"] == "kid-ctrl" and c["gf"] not in fights]
    for who in ("guard-ctrl", "kid-ctrl"):
        o = [c for c in orc if c[1] == who]
        m = [c for c in mine if c[1] == who]
        same = o == m
        print("AC1  NARROW %s: the 6809's %d map reads vs the oracle's %d -- %s" % (
            who, len(m), len(o), "IDENTICAL (game frame, arguments, answer, order)" if same else "DIFFER"))
        if not same:
            k = next((j for j, (x, y) in enumerate(zip(o, m)) if x != y), min(len(o), len(m)))
            print("     first difference #%d: oracle %r  6809 %r" % (k, o[k] if k < len(o) else None,
                                                                    m[k] if k < len(m) else None))
        ok &= same
    print("     (the kid's other %d oracle reads, gf %s, are his DEMO walk -- AUTOPLAYBACK, replayed, not built)"
          % (len(demo), sorted({c["gf"] for c in demo})))

    # ---------------- AC1 self-test: every distinct query + cmpbarr, on the 6809's map
    bad, edges = [], []
    for j, q in enumerate(vec["queries"]):
        ans = {int(k): v for k, v in q["answers"].items()}
        first = min(ans, key=lambda r: ans[r][0])       # the answer before any mutation in the window
        g = tq[2 * j]
        if g != first:
            bad.append((q["scrn"], s8(q["x"]), s8(q["y"]), g, first))
        x, y = s8(q["x"]), s8(q["y"])
        if not (0 <= x < 10 and 0 <= y < 3):
            edges.append((q["scrn"], x, y, g, first, len(ans) > 1))
    print("AC1  SELF-TEST: %d distinct queries (all %d the oracle made in the window) on the 6809's map: %s"
          % (len(vec["queries"]), sum(n for q in vec["queries"] for _a, _b, n in q["answers"].values()),
             "ALL MATCH the oracle's answer" if not bad else "%d DIFFER %r" % (len(bad), bad)))
    ok &= not bad
    mut = [q for q in vec["queries"] if len(q["answers"]) > 1]
    print("     (%d of them changed answer in the oracle's window -- %s -- the game mutating its map: compared"
          " with the answer before the change)" % (len(mut), ["scrn %d (%d,%d) %s" % (
              q["scrn"], q["x"], q["y"], {k: v[0] for k, v in q["answers"].items()}) for q in mut]))
    print("AC1  EDGES -- %d distinct cross-screen queries, each with the 6809's and the oracle's answer:" % len(edges))
    for sc, x, y, g, w, _m in edges:
        print("     screen %d block (%d,%d): 6809 $%02X, oracle $%02X %s" % (sc, x, y, g, w, "==" if g == w else "≠"))
    cb = []
    for c in vec["cmpbarr"]:
        j = next((j for j, q in enumerate(vec["queries"]) if tq[2 * j] == c["a_in"]), None)
        mine_out = tq[2 * j + 1] if j is not None else None
        cb.append((c["gf"], c["a_in"], c["a_out"], mine_out))
    cbok = all(m == o for _g, _i, o, m in cb)
    print("AC1  CMPBARR x%d (the oracle's, gf %s, DEMO -> DoStartrun): %s" % (
        len(cb), sorted({c[0] for c in cb}), ", ".join("$%02X -> oracle %d, 6809 %s" % (i, o, m)
                                                      for _g, i, o, m in cb)) + ("  IDENTICAL" if cbok else "  DIFFER"))
    ok &= cbok
    print("engarde_test: %s" % ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
