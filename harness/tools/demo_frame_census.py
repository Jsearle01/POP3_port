#!/usr/bin/env python3
r"""demo_frame_census.py - P5.0. How many CELS does gameplay actually name, per actor?

★ THE QUESTION THE DISPATCH ASKS IS NOT "how many cels are in the files". It is
"how many does the PEAK RESIDENT SUBSET need", and the frame table is what says so:
a cel nobody's frame names is never drawn.

WHERE THE FACTS COME FROM
  FRAMEDEF.S       three frame tables, 5 bytes each: Fimage, Fsword, Fdx, Fdy, Fcheck
                     Fdef      frames   1..240   the KID
                     ALTSET1   frames 150..189   the OPPONENT (chtable4)
                     ALTSET2   frames   1..90    the cutscene characters (chtable6/7)
  CTRLSUBS.S:1017  decodeim, implemented here in arithmetic rather than paraphrased:
                     FCharTable = (Fsword>>6) + (4 if Fimage&$80 else 0)      0..7
                     FCharImage = Fimage & $7F                                0..127
  GAMEBG.S:140 / CTRLSUBS.S:1053 / GAMEBG.S:887
                   file number = slot + 1, stated by the oracle three times.

WHAT IT DOES NOT DO
  It does not resolve a SEQUENCE into the frames a given level actually reaches. Every
  frame in Fdef is the kid's and the kid is always resident, so the kid's figure is a
  residency requirement as it stands. The opponent's is per-chset.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path("C:/Projects/POP3_port")
sys.path.insert(0, str(ROOT / "harness/tools"))
SRC = ROOT / "oracle/source/01 POP Source/Source"
IMAGES = ROOT / "oracle/source/01 POP Source/Images"

from demo_asset_census import read_table, coco3_bytes            # noqa: E402

# slot -> the file the loader puts in that slot. Slot 3 is the SWAPPABLE one
# (chtable4: GD / SHAD / SKEL / FAT / VIZ, chosen by `chset`); level 0 uses GD.
SLOT_FILE = {0: "IMG.CHTAB1", 1: "IMG.CHTAB2", 2: "IMG.CHTAB3", 3: "IMG.CHTAB4.GD",
             4: "IMG.CHTAB5", 5: "IMG.CHTAB6.A", 6: "IMG.CHTAB7", 7: "IMG.CHTAB6.B"}

ENTRY = re.compile(r"^:(\d+)\s+db\s+"
                   r"\$?([0-9a-fA-F]{1,2}),"
                   r"\$?([0-9a-fA-F]{1,2})(?:\+(\d+))?,"
                   r"(-?\d+),(-?\d+)")


def hx(tok):
    return int(tok, 16)


def parse_framedef():
    """-> {'Fdef': {n:(fimage,fsword)}, 'ALTSET1': {...}, 'ALTSET2': {...}}"""
    text = (SRC / "FRAMEDEF.S").read_text(errors="replace").splitlines()
    tables, cur = {}, None
    for line in text:
        s = line.rstrip()
        lab = s.strip()
        if lab in ("Fdef", "ALTSET1", "ALTSET2", "SWORDTAB"):
            cur = lab
            tables[cur] = {}
            continue
        if cur is None or cur == "SWORDTAB":
            continue
        m = ENTRY.match(s.strip())
        if not m:
            continue
        n = int(m.group(1))
        fimage = hx(m.group(2))
        # Fsword is written either as `$c0+13` or as a bare decimal like `9`.
        raw = m.group(2 + 1)
        plus = m.group(4)
        fsword = hx(raw) if s.strip().split(",")[1].startswith("$") else int(raw)
        if plus:
            fsword += int(plus)
        tables[cur][n] = (fimage, fsword)
    return tables


def decodeim(fimage, fsword):
    """CTRLSUBS.S:1017-1037, in arithmetic."""
    table = (fsword >> 6) + (4 if (fimage & 0x80) else 0)
    return table, fimage & 0x7F


def main():
    tabs = parse_framedef()
    cels = {}
    for slot, name in SLOT_FILE.items():
        _, c, _ = read_table(IMAGES / name)
        cels[slot] = c

    def report(title, frames, note=""):
        used = {}
        blank = 0
        for n, (fi, fs) in sorted(frames.items()):
            if fi == 0 and fs == 0:
                blank += 1
                continue
            t, im = decodeim(fi, fs)
            used.setdefault(t, set()).add(im)
        print()
        print("%s  (%d frame slots, %d blank)%s" % (title, len(frames), blank, note))
        tot_a = tot_c = 0
        for t in sorted(used):
            fname = SLOT_FILE.get(t, "?")
            tab = cels.get(t) or []
            a = c = miss = 0
            for im in sorted(used[t]):
                if 1 <= im <= len(tab) and tab[im - 1]:
                    cel = tab[im - 1]
                    a += cel["nbytes"]
                    c += coco3_bytes(cel["w"], cel["h"])
                else:
                    miss += 1
            print("   table %d -> %-16s %3d distinct cels   apple=%5d  coco3=%5d%s"
                  % (t, fname, len(used[t]), a, c,
                     ("   (%d index out of range)" % miss) if miss else ""))
            tot_a += a
            tot_c += c
        print("   %-31s %3d           apple=%5d  coco3=%5d"
              % ("TOTAL", sum(len(v) for v in used.values()), tot_a, tot_c))
        return used

    print("FRAME-TABLE CEL CENSUS  [FRAMEDEF.S + decodeim CTRLSUBS.S:1017]")
    kid = report("THE KID          Fdef", tabs["Fdef"])
    opp = report("THE OPPONENT     ALTSET1", tabs["ALTSET1"],
                 "   [chtable4 = chset; level 0 -> IMG.CHTAB4.GD]")
    cut = report("CUTSCENE CHARS   ALTSET2", tabs["ALTSET2"],
                 "   [not loaded during gameplay]")

    # --- the residency question ------------------------------------------
    print()
    print("PEAK GAMEPLAY RESIDENT SET (kid + opponent, the demo's two actors):")
    merged = {}
    for src in (kid, opp):
        for t, s in src.items():
            merged.setdefault(t, set()).update(s)
    ta = tc = 0
    for t in sorted(merged):
        tab = cels.get(t) or []
        a = c = 0
        for im in sorted(merged[t]):
            if 1 <= im <= len(tab) and tab[im - 1]:
                cel = tab[im - 1]
                a += cel["nbytes"]
                c += coco3_bytes(cel["w"], cel["h"])
        print("   table %d -> %-16s %3d cels  apple=%5d  coco3=%5d"
              % (t, SLOT_FILE[t], len(merged[t]), a, c))
        ta += a
        tc += c
    print("   %-31s %3d       apple=%5d  coco3=%5d"
          % ("TOTAL", sum(len(v) for v in merged.values()), ta, tc))

    # --- the background, for the same page ---------------------------------
    print()
    print("BACKGROUND (level 0 -> bgset 0 = DUN):")
    bt = 0
    for name in ("IMG.BGTAB1.DUN", "IMG.BGTAB2.DUN"):
        _, c, flen = read_table(IMAGES / name)
        live = [x for x in c if x]
        cc = sum(coco3_bytes(x["w"], x["h"]) for x in live)
        print("   %-16s %3d cels  apple=%5d  coco3=%5d"
              % (name, len(live), sum(x["nbytes"] for x in live), cc))
        bt += cc
    print("   %-16s               coco3=%5d" % ("TOTAL", bt))
    print()
    print("GRAND TOTAL (chars + background), CoCo3 4-colour raw: %d B" % (tc + bt))


if __name__ == "__main__":
    sys.exit(main())
