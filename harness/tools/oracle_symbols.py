#!/usr/bin/env python3
r"""oracle_symbols.py — P5.36: every GLOBAL code label in the oracle's listings, with its address.

The oracle build leaves `oracle/source/obj/*.LST` (apple2e idioms §1a): `ADDR: bytes  line  source`.
A label is the token right after the source line number when exactly ONE space separates them (an
instruction line has two); a label on its own line has no address (`    :`), so it takes the address of
the next addressed line. Local labels (`:loop`) are skipped -- they repeat across routines.

  python harness/tools/oracle_symbols.py [--json build/p536/oracle_symbols.json]

Used by oracle_path.py to name the routine a traced PC entered.
"""
import argparse
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
LST = ROOT / "oracle/source/obj"
LINE = re.compile(r"^\s*([0-9A-F]{4})?\s*:\s*(?:[0-9A-F]{2}\s)*\s*(\d+)(.*)$")


def symbols():
    out = {}
    for p in sorted(LST.glob("*.LST")):
        pending = []
        for raw in p.read_text(errors="replace").splitlines():
            m = LINE.match(raw)
            if not m:
                continue
            addr, tail = m.group(1), m.group(3) or ""
            # exactly ONE space after the line number = a label in column 0 of the source
            rest = tail[1:] if tail.startswith(" ") else ""
            if rest and not rest.startswith((" ", ";", "*", ":")):
                tok = rest.split()[0]
                if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", tok) and tok.lower() not in ("do", "fin", "else", "lst", "org", "dum", "dend", "tr", "put", "use", "ds", "db", "dw", "hex", "asc"):
                    pending.append(tok)
            if addr and pending:
                a = int(addr, 16)
                for lab in pending:
                    out.setdefault(lab, (a, p.name))
                pending = []
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", default=str(ROOT / "build/p536/oracle_symbols.json"))
    a = ap.parse_args()
    s = symbols()
    pathlib.Path(a.json).parent.mkdir(parents=True, exist_ok=True)
    pathlib.Path(a.json).write_text(json.dumps({k: [v[0], v[1]] for k, v in s.items()}, indent=0))
    for k in ("AUTOCTRL", "GuardProg", "Alert", "EnGarde", "FollowKid", "InRange", "GenFight", "MaybeAdvance",
              "MaybeBlock", "MaybeStrike", "DoRelease", "rndp", "RND", "SHADCTRL", "GuardCtrl", "FightCtrl",
              "GENCTRL", "rdblock", "getinfront", "get2infront", "cmpspace", "cmpbarr", "DemoCtrl", "CHECKALERT"):
        v = s.get(k)
        print("%-14s %s" % (k, ("$%04X  %s" % v) if v else "NOT FOUND"))
    print("oracle_symbols: %d labels -> %s" % (len(s), a.json))


if __name__ == "__main__":
    main()
