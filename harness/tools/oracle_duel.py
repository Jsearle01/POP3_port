#!/usr/bin/env python3
r"""oracle_duel.py — P5.38 §1: the oracle's first exchange, measured from oracle_duel.lua's one-boot trace.

Per game frame (180 = the first AUTOCTRL, P5.36's numbering):
  * the labels ENTERED inside each extent -- kid-ctrl ($22FD->$2300), guard-ctrl ($235D->$2360), checkstrike
    ($2260->$2263), checkstab ($2263->$2266) [TOPCTRL.S:512-517] -- and inside DoKid/DoShad outside them;
  * every RND call ($0A52, GRAFIX.S:1386) with its SITE (main loop $218C / the extent it ran in / outside) and
    the routine that asked (the last label entered before it), and its VALUE (A at RND's rts);
  * the CONTACT markers: TestStrike's `:test` $589D, block-success `:1` $58B3 / `:11` $58B8 / `:12` $58C0, the stab
    `lda #99` $58E5 [AUTO.S:954-1002]; StabChar, DECSTR, DEADENEMY, the meters.
Writes build/p538/duel.json.

  python harness/tools/oracle_duel.py [--from 218 --to 400]
"""
import argparse
import collections
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "harness/tools"))
import oracle_path as OP                                    # noqa: E402  (labels())

TR = ROOT / "build/p538/oracle_duel.tr"
LINE = re.compile(r"^S=([0-9A-F]{3}) A=([0-9A-F]{2}) X=([0-9A-F]{2}) Y=([0-9A-F]{2})\|([0-9A-F]{4}): (.*)$")
MAINLOOP, AUTOCTRL, RND = 0x218C, 0x5499, 0x0A52
EXT = {"kid-ctrl": (0x22FD, 0x2300), "guard-ctrl": (0x235D, 0x2360), "checkstrike": (0x2260, 0x2263),
       "checkstab": (0x2263, 0x2266), "DoKid": (0x225A, 0x225D), "DoShad": (0x225D, 0x2260)}
CONTACT = {0x589D: "TestStrike:test", 0x58B3: "TestStrike:block(:1)", 0x58B8: "TestStrike:block(:11)",
           0x58C0: "TestStrike:blockedstrike(:12)", 0x58E5: "TestStrike:STAB(#99)", 0xFABD: "STABCHAR",
           0xFC61: "DECSTR", 0xE908: "DEADENEMY", 0x4E97: "UPDATEMETERS", 0x4EA8: "DRAWKIDMETER",
           0x4F22: "DRAWOPPMETER"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="lo", type=int, default=218)
    ap.add_argument("--to", dest="hi", type=int, default=420)
    a = ap.parse_args()
    lab = OP.labels()
    frames, cur, open_ext, first_auto = [], None, {}, None
    pend = []                                   # RND calls awaiting their rts: (sp, entry)
    last_label = {}
    for raw in open(TR, errors="replace"):
        m = LINE.match(raw)
        if not m:
            continue
        s, acc, pc, ins = int(m.group(1), 16), int(m.group(2), 16), int(m.group(5), 16), m.group(6)
        if pend and ins.startswith("rts") and s == pend[-1][0]:
            pend[-1][1]["value"] = None          # filled on the NEXT line (A after rts == A at rts)
            pend[-1][1]["value"] = acc
            pend.pop()
        if pc == MAINLOOP:
            cur = dict(ents=collections.defaultdict(list), rnd=[], contact=collections.Counter())
            frames.append(cur)
            open_ext, last_label = {}, {}
        if cur is None:
            continue
        for name, (st, en) in EXT.items():
            if pc == st:
                open_ext[name] = en
            elif open_ext.get(name) == pc:
                del open_ext[name]
        if pc == AUTOCTRL and first_auto is None:
            first_auto = len(frames) - 1
        if pc in CONTACT:
            cur["contact"][CONTACT[pc]] += 1
        if pc == RND:
            inner = [e for e in ("kid-ctrl", "guard-ctrl", "checkstrike", "checkstab") if e in open_ext]
            site = inner[0] if inner else ("main-loop" if not cur["rnd"] and not open_ext else
                                           ("DoKid" if "DoKid" in open_ext else "DoShad" if "DoShad" in open_ext
                                            else "other"))
            e = dict(site=site, asker=last_label.get(site), seed_in=None)
            cur["rnd"].append(e)
            pend.append((s, e))
        name = lab.get(pc)
        if name:
            for e in open_ext:
                lst = cur["ents"][e]
                if not lst or lst[-1] != name:
                    lst.append(name)
                if name not in ("RND", "rnd"):
                    last_label[e] = name
            if not open_ext and name not in ("RND", "rnd"):
                last_label["main-loop"] = name
                last_label["other"] = name
    base = 180 - first_auto
    out = {}
    firsts = {}
    for i, fr in enumerate(frames):
        g = base + i
        for k in fr["contact"]:
            firsts.setdefault(k, g)
        if a.lo <= g <= a.hi:
            out[g] = dict(guard=fr["ents"].get("guard-ctrl", []), kid=fr["ents"].get("kid-ctrl", []),
                          strike=fr["ents"].get("checkstrike", []), stab=fr["ents"].get("checkstab", []),
                          rnd=fr["rnd"], contact=dict(fr["contact"]))
    print("oracle_duel: %d game frames traced (180 = trace frame %d); last = gf %d" % (len(frames), first_auto,
                                                                                    base + len(frames) - 1))
    print("first game frame of each CONTACT marker: %s" % {k: v for k, v in sorted(firsts.items(), key=lambda x: x[1])})
    for g in sorted(out):
        r = out[g]
        ai = [x for x in r["rnd"] if x["site"] in ("kid-ctrl", "guard-ctrl", "checkstab")]
        print("gf %d  guard: %s" % (g, " > ".join(n for n in r["guard"] if n not in ("SHADCTRL",)) or "-"))
        if "AUTOCTRL" in r["kid"]:
            print("        kid:   %s" % " > ".join(r["kid"]))
        print("        rnd: %s" % ", ".join("%s/%s=%02X" % (x["site"], x["asker"], x.get("value") or 0)
                                            for x in r["rnd"]))
        if r["contact"]:
            print("        CONTACT: %r" % r["contact"])
    (ROOT / "build/p538/duel.json").write_text(json.dumps({str(k): v for k, v in out.items()}, indent=0))
    return 0


if __name__ == "__main__":
    sys.exit(main())
