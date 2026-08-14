#!/usr/bin/env python3
r"""glass_fit.py — does the hourglass fit, and does it need the re-encode first?

P3.85 §1. The hourglass has been deferred since P3.64 on a costing of 3,981 B for TWELVE
cels. PlayCut0 uses TWO glass states (addglass1 with X=0 then X=1) and the three flow
frames, so THIS SCENE needs FIVE, measured at 994 B:

    glass0 415   glass1 416   flow0 49   flow1 57   flow2 57

It has to be PINNED rather than paged: it appears after Pback and is drawn every frame to
the end of the scene, spanning beats that map two different rotating blocks. A cel that
straddles a mapping change is the one thing the packer refuses.

So the question is whether the pinned page has 994 B spare — today, and under the re-encode
(one byte saved per segment, P3.79) — and the answer decides the build ORDER. The dispatch
says land the hourglass first; if it does not fit until the re-encode has run, that order is
wrong and it is better to know from the packer than from a failed link.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "harness/tools"))
import bake_scene as S                                           # noqa: E402
import cel_pack as K                                             # noqa: E402
import cel_encoding_census as C                                  # noqa: E402

GLASS = ROOT / "build/tmp/glass"
# the five, and the beat from which each is live to the end of the scene
GLASS_CELS = [("glass0", 13), ("glass1", 13), ("flow0", 14), ("flow1", 14), ("flow2", 14)]


def emitted(path):
    """(bytes, segments) for a baked cel outside the chars directory."""
    out = []
    for line in pathlib.Path(path).read_text(errors="replace").splitlines():
        s = line.split(";")[0]
        m = re.match(r"\s*fcb\s+(.*)$", s)
        if m:
            for x in m.group(1).split(","):
                x = x.strip()
                if x:
                    out.append((int(x[1:], 16) if x.startswith("$") else int(x, 0)) & 0xFF)
    c = C.census(out)
    if c is None:
        return None, None
    n_seg = (c["skip_hdr"] + c["blast_hdr"] + c["merge_hdr"]) // 2
    total = (c["header"] + c["rowend"] + c["skip_hdr"] + c["blast_hdr"] + c["blast_data"]
             + c["merge_hdr"] + c["merge_mask"] + c["merge_src"])
    return total, n_seg


def lab_of(v):
    who, cel, face, ph = v
    return "%s%d%s_p%d" % ("v" if who == "viz" else "p", cel, "_m" if face else "", ph)


def main():
    viz, pri, beats = S.trace_scene(with_beats=True)

    meas = {}
    for p in (ROOT / "content/cutscene/chars").glob("*_p[0-9].s"):
        b, n = emitted(p)
        if b:
            meas[p.stem] = (b, n)

    glass = {}
    for name, _first in GLASS_CELS:
        b, n = emitted(GLASS / ("%s.s" % name))
        if b is None:
            print("  FAIL %s is not baked — run the conversion first" % name)
            return 1
        glass[name] = (b, n)

    def build(pack_hdr, with_glass):
        sz, bs = {}, []
        for bi, nm, pl, vs in beats:
            vs2 = set(vs)
            if with_glass:
                for name, first in GLASS_CELS:
                    if bi >= first:
                        vs2.add(("glass", name))
            bs.append((bi, nm, pl, vs2))
        for bi, nm, pl, vs in bs:
            for v in vs:
                if v[0] == "glass":
                    b, n = glass[v[1]]
                else:
                    lab = lab_of(v)
                    if lab not in meas:
                        continue
                    b, n = meas[lab]
                sz[v] = b - (n if pack_hdr else 0)
        return bs, sz

    print("=== the hourglass: five cels, %s B measured ===\n"
          % format(sum(b for b, _n in glass.values()), ","))
    for tag, pack_hdr in (("today's encoding", False), ("with the re-encode", True)):
        for with_glass in (False, True):
            bs, sz = build(pack_hdr, with_glass)
            label = "%s, %s" % (tag, "with hourglass" if with_glass else "as it ships")
            try:
                p = K.pack(bs, sz, 1360, [1, 6, 10])
            except K.PackError as e:
                print("  %-38s DOES NOT PACK — %s" % (label, str(e)[:70]))
                continue
            res = p["resident_bytes"]
            budget = K.RES_CAP - 4 - 1360
            print("  %-38s pinned %s/%s B (%s spare) | %d pages | %d read(s) | %d LOAD(S)"
                  % (label, format(res, ","), format(budget, ","),
                     format(budget - res, ","), len(p["pages"]), len(p["reads"]),
                     1 + len(p["reads"])))
    print("\n  (a LOAD is the startup read plus each staged one; zero staged reads = no freeze)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
