#!/usr/bin/env python3
r"""oracle_vs_port_bytes.py — what the ORACLE holds resident for this scene, against us.

P3.79 §1, second half, and it is Jay's question: the Apple mirrors at DRAW time and runs
this whole scene on a 128 KB machine with ONE load. Our port needs 39,680 B and three. So
either the oracle's cel data is far denser than ours, or our conversion is fat — and if it
is the latter, that is a much better place to spend effort than a packer.

This compares the SAME SET OF CELS on both sides and attributes the difference. It does
not estimate: the oracle side is read out of IMG.CHTAB6.A, the port side is the size of the
baked .s files the linker actually places, and the set is the one bake_scene's own trace
says the scene draws.

★ NAME THE LAYER (the standing invariant — disk sum / loaded total / live peak). Both
columns here are the SAME layer: bytes that must be RESIDENT to draw the scene, excluding
the lookup table. The oracle's is its chtab; ours is the sum of the baked cel variants.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "harness/tools"))
import sprite_convert as SC                                      # noqa: E402
import cel_parity_rule as R                                      # noqa: E402

TABLE = ROOT / "oracle/source/01 POP Source/Images/IMG.CHTAB6.A"
CHARS = ROOT / "content/cutscene/chars"
PACK = CHARS / "cel_pack.json"


def port_bytes(label):
    """Bytes the linker places for one baked variant — fcb/fdb counted, not file size."""
    p = CHARS / ("%s.s" % label)
    if not p.exists():
        return 0
    n = 0
    for line in p.read_text(errors="replace").splitlines():
        s = line.split(";")[0]
        m = re.match(r"\s*fcb\s+(.*)$", s)
        if m:
            n += len([x for x in m.group(1).split(",") if x.strip()])
        m = re.match(r"\s*fdb\s+(.*)$", s)
        if m:
            n += 2 * len([x for x in m.group(1).split(",") if x.strip()])
    return n


def main():
    cels = SC.load_chtable(str(TABLE))
    alt = R.altset2()
    pack = json.loads(PACK.read_text(encoding="utf-8"))

    # the scene's variants, from the pack the build actually placed
    variants = []
    for v, lab in pack["resident"]:
        variants.append((tuple(v), lab, "pinned"))
    for g in pack["pages"]:
        for v, lab in g["cels"]:
            variants.append((tuple(v), lab, "page %d" % g["index"]))

    # oracle cel index for a (who, cel) — ALTSET2's fimg, low 7 bits [cel_parity_rule]
    def oracle_cel(celno):
        fimg = alt[celno][0]
        return fimg & 0x7F

    print("=== the same scene, both sides, resident cel bytes (no lookup table) ===\n")
    print("  %-12s %-6s %-5s %8s   %8s  %s"
          % ("variant", "cel", "face", "ORACLE", "PORT", "port/oracle"))

    seen_oracle = {}
    tot_port = 0
    rows = []
    for (who, celno, facing, phase), lab, where in sorted(variants, key=lambda t: t[1]):
        oi = oracle_cel(celno)
        c = cels[oi - 1] if 1 <= oi <= len(cels) else None
        obytes = (c["w"] * c["h"]) if c else 0
        pbytes = port_bytes(lab)
        tot_port += pbytes
        # the oracle stores each cel ONCE regardless of facing or phase
        seen_oracle.setdefault(oi, obytes)
        rows.append((lab, celno, facing, obytes, pbytes, where))

    for lab, celno, facing, obytes, pbytes, where in rows:
        print("  %-12s %-6d %-5s %8s   %8s  %5.2fx   %s"
              % (lab, celno, "mirr" if facing else "norm",
                 format(obytes, ","), format(pbytes, ","),
                 (pbytes / obytes) if obytes else 0, where))

    tot_oracle = sum(seen_oracle.values())
    n_mirror = sum(1 for r in rows if r[2])
    mirror_bytes = sum(r[4] for r in rows if r[2])

    print("\n  ORACLE, distinct cels resident   %5d cels   %s B"
          % (len(seen_oracle), format(tot_oracle, ",")))
    print("  PORT,   baked variants           %5d       %s B"
          % (len(rows), format(tot_port, ",")))
    print("  ratio                                          %.2fx" % (tot_port / tot_oracle))

    print("\n=== ATTRIBUTION ===")
    print("  of the port's %s B:" % format(tot_port, ","))
    print("    %-42s %s B  (%d variants)"
          % ("mirrored copies the oracle does not store", format(mirror_bytes, ","),
             n_mirror))
    unmirrored = tot_port - mirror_bytes
    print("    %-42s %s B" % ("one facing only, like the oracle",
                              format(unmirrored, ",")))
    print("    %-42s %.2fx" % ("...still, against the oracle:",
                               unmirrored / tot_oracle))

    # the pixel-depth floor: Apple 7 px/byte vs CoCo3 4 px/byte
    print("\n  THE FLOOR, and it is not a choice: Apple hi-res packs 7 px into a byte,")
    print("  CoCo3 4-colour packs 4. Same picture, %.2fx the bytes, before any encoding."
          % (7 / 4))
    print("  So the port's unavoidable size for these cels is about %s B."
          % format(int(tot_oracle * 7 / 4), ","))
    print("  Measured unmirrored total is %s B -> encoding overhead %.2fx on top."
          % (format(unmirrored, ","), unmirrored / (tot_oracle * 7 / 4)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
