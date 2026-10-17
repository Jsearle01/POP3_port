#!/usr/bin/env python3
r"""p538_extent.py — P5.38 §1.1-§1.4, measured: the extent, the RND stream's shape (tier 2's premise), the
executed path, and the sizes of the kid's fight cels and the sword -- from oracle_duel.py's build/p538/duel.json
and the oracle's records (build/p538/oracle_duel.txt), the frame table and the baked streams.

  python harness/tools/p538_extent.py
"""
import collections
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "harness/tools"))
import bake_chars as B                                      # noqa: E402

D = json.loads((ROOT / "build/p538/duel.json").read_text())
AI = ("kid-ctrl", "guard-ctrl", "checkstab")
CONTACT = ("TestStrike:block(:1)", "TestStrike:block(:11)", "TestStrike:blockedstrike(:12)", "TestStrike:STAB(#99)",
           "STABCHAR", "DECSTR", "DEADENEMY")
TABS = {0: "chtab1", 1: "chtab2", 2: "chtab3", 3: "chtab4gd", 4: "chtab5"}


def records():
    out = {}
    for l in (ROOT / "build/p538/oracle_duel.txt").read_text().splitlines():
        m = re.match(r"^F (\d+) gf=(\d+) K=([0-9A-F]{32}) S=([0-9A-F]{32})", l)
        if m:
            out[int(m.group(2)) - 7] = (bytes.fromhex(m.group(3)), bytes.fromhex(m.group(4)), int(m.group(1)))
    return out


def frame_rows():
    rows = {"fdef": {}, "alt1": {}}
    tab = None
    for l in (ROOT / "content/chars/frame_table.s").read_text(encoding="utf-8").splitlines():
        if l.startswith("fdef_tab"):
            tab = "fdef"
        elif l.startswith("alt1_tab"):
            tab = "alt1"
        m = re.match(r"^\s+fcb\s+(\d+),(\d+),(\d+),\$([0-9A-F]{2}),(\d+)\s+;\s+(\d+)\s", l)
        if m and tab:
            rows[tab][int(m.group(6))] = (int(m.group(1)), int(m.group(5)))
    return rows


def stream(slot, img):
    p = ROOT / "content/chars" / TABS[slot] / ("%s_%03d_p0.s" % (TABS[slot], img))
    if not p.exists():
        return None
    v = B.fcb_values(p)
    return dict(path=str(p.relative_to(ROOT)), size=len(v), rows=v[0], w0=v[1], peel=v[0] * (v[1] + 1))


def main():
    gfs = sorted(int(g) for g in D)
    # ---- §1.1 the extent
    first = {}
    for g in gfs:
        for k in D[str(g)]["contact"]:
            first.setdefault(k, g)
    stop = min(first[k] for k in CONTACT if k in first)
    why = [k for k in CONTACT if first.get(k) == stop]
    print("§1.1 first AI draw: gf %d" % next(g for g in gfs if any(r["site"] in AI for r in D[str(g)]["rnd"])))
    print("§1.1 contact markers, first game frame: %s" % {k: first[k] for k in CONTACT if k in first})
    print("§1.1 EXTENT without the contact path: gf 218-%d = %d game frames (ends because gf %d needs %s)"
          % (stop - 1, stop - 218, stop, why))
    stab = first.get("TestStrike:STAB(#99)")
    print("     next boundary: gf 218-%d = %d game frames, if TestStrike's BLOCK outcome is built (the first stab -- "
          "StabChar/DECSTR, damage -- is gf %d)" % (stab - 1, stab - 218, stab))
    # ---- tier 2's premise: the non-AI draws per frame, and the order
    for lo, hi in ((218, stop - 1), (218, stab - 1)):
        bad_order, counts = [], collections.Counter()
        for g in range(lo, hi + 1):
            sites = [r["site"] for r in D[str(g)]["rnd"]]
            non = [s for s in sites if s not in AI]
            counts[(len(non), tuple(non))] += 1
            # order: every non-AI draw before every AI draw; kid-ctrl before guard-ctrl before checkstab
            rank = {"kid-ctrl": 1, "guard-ctrl": 2, "checkstab": 3}
            r = [rank.get(s, 0) for s in sites]
            if r != sorted(r):
                bad_order.append((g, sites))
        print("tier 2, gf %d-%d: non-AI draws per game frame %s; order main->torches->kid->guard->checkstab broken "
              "in %d frames %s" % (lo, hi, dict(counts), len(bad_order), bad_order[:3]))
        ai = [(g, r["site"], r["asker"], r["value"]) for g in range(lo, hi + 1) for r in D[str(g)]["rnd"]
              if r["site"] in AI]
        print("     AI draws: %d (kid %d, guard %d, checkstab %d)" % (
            len(ai), sum(1 for a in ai if a[1] == "kid-ctrl"), sum(1 for a in ai if a[1] == "guard-ctrl"),
            sum(1 for a in ai if a[1] == "checkstab")))
    # ---- §1.2 the executed path, union, over both extents
    for lo, hi in ((218, stop - 1), (218, stab - 1)):
        u = collections.defaultdict(set)
        for g in range(lo, hi + 1):
            r = D[str(g)]
            for k in ("guard", "kid", "strike", "stab"):
                u[k].update(r[k])
        for k in ("guard", "kid", "strike", "stab"):
            print("§1.2 gf %d-%d %-6s entered: %s" % (lo, hi, k, ", ".join(sorted(u[k]))))
    # ---- what the fighters SHOW over each extent, and the cels it needs
    R = records()
    rows = frame_rows()
    for lo, hi in ((218, stop - 1), (218, stab - 1)):
        gp = sorted({R[g][1][0] for g in range(lo - 1, hi + 1)})
        kp = sorted({R[g][0][0] for g in range(lo - 1, hi + 1)})
        print("frames shown, gf %d-%d: guard %s; kid %s" % (lo, hi, gp, kp))
    # §1.3 the kid's fight cels: frames 150-189 and 207-210, his set (Fdef)
    kid = {}
    for f in list(range(150, 190)) + list(range(207, 211)):
        img, slot = rows["fdef"].get(f, (0, 0))
        if img:
            kid.setdefault((slot, img), []).append(f)
    tot, peel, missing = 0, 0, []
    for (slot, img), fs in sorted(kid.items()):
        s = stream(slot, img)
        if s is None:
            missing.append((TABS[slot], img))
            continue
        tot += s["size"]
        peel = max(peel, s["peel"])
    print("§1.3 the kid's FIGHT cels (Fdef frames 150-189, 207-210): %d distinct images, %d B of baked streams, "
          "largest peel %d B; not baked: %s" % (len(kid), tot, peel, missing or "none"))
    shown = sorted({R[g][0][0] for g in range(217, stab)})
    need = {}
    for f in shown:
        img, slot = rows["fdef"].get(f, (0, 0))
        need[(slot, img)] = stream(slot, img) if img else None
    print("     ... of which the kid SHOWS in gf 218-%d: frames %s -> %d images, %d B, largest peel %d B"
          % (stab - 1, shown, len(need), sum(s["size"] for s in need.values() if s),
             max(s["peel"] for s in need.values() if s)))
    # the guard's new frames over the 14-frame extent
    gshown = sorted({R[g][1][0] for g in range(217, stab)})
    gneed = {}
    for f in gshown:
        img, slot = rows["alt1"].get(f, rows["fdef"].get(f, (0, 0)))
        gneed[(slot, img)] = stream(slot, img) if img else None
    print("     the guard SHOWS frames %s -> images %s, %d B (7 linked at P5.37: 8,13,14,15,16,19,20), largest peel %d B"
          % (gshown, sorted(i for _s, i in gneed), sum(s["size"] for s in gneed.values() if s),
             max(s["peel"] for s in gneed.values() if s)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
