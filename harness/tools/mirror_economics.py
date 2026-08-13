#!/usr/bin/env python3
r"""mirror_economics.py — P3.79 §1: how many LOADS does this scene need?

Jay: *"There are now 3 disk loads for this one scene. That seems excessive. Did we miss
something or are we overcomplicating this?"* and *"Why don't we mirror at draw time?"*

This answers it with the REAL PACKER, not arithmetic. Each scenario re-sizes the scene's
variants and re-runs cel_pack, which is the thing that decides whether a schedule exists —
a total that fits on paper can still fail to pack, and P3.78 saw exactly that (the whole
scene declared unpackable over 78 bytes).

THE THREE LEVERS, each measured elsewhere and applied here:

  MIRROR AT DRAW TIME   drops the mirrored variants entirely (oracle_vs_port_bytes).
                        The oracle does this: OPACITY bit 7 routes LAY to MLAY
                        [HIRES.S:655], so it stores ONE facing.

  PACK THE SEGMENT HEADER  every run costs an opcode byte AND a count byte; the count
                        never exceeds the cel width. 2-bit opcode + 6-bit count fits one
                        byte and saves exactly one byte per segment (cel_encoding_census).

  BOTH.

★ THE ROW TERMINATOR IS ALREADY ONE BYTE and is NOT halved — an earlier draft of the
census did halve it and overstated the saving by 1,358 B. Segments are what cost two.
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

CHARS = ROOT / "content/cutscene/chars"
TABLE_BYTES = 1360          # walk_tab, unchanged by any of this


def lab_of(v):
    who, cel, face, ph = v
    return "%s%d%s_p%d" % ("v" if who == "viz" else "p", cel, "_m" if face else "", ph)


def measured():
    """{variant: (bytes_today, n_segments)} from the baked files."""
    out = {}
    for p in CHARS.glob("*_p[0-9].s"):
        lab = p.stem
        st = C.cel_bytes(lab)
        c = C.census(st)
        if c is None:
            continue
        n_seg = (c["skip_hdr"] + c["blast_hdr"] + c["merge_hdr"]) // 2
        total = (c["header"] + c["rowend"] + c["skip_hdr"] + c["blast_hdr"]
                 + c["blast_data"] + c["merge_hdr"] + c["merge_mask"] + c["merge_src"])
        out[lab] = (total, n_seg)
    return out


def run(name, beats, sizes, note):
    try:
        p = K.pack(beats, sizes, TABLE_BYTES, [1, 6, 10])
    except K.PackError as e:
        print("  %-26s DOES NOT PACK - %s" % (name, e))
        return
    tot = p["resident_bytes"] + sum(g["bytes"] for g in p["pages"])
    n_reads = len(p["reads"])
    print("  %-26s %6s B cels | %d pages | %d staged read(s) | %d DISK LOAD(S) %s"
          % (name, format(tot, ","), len(p["pages"]), n_reads, 1 + n_reads, note))
    for r in p["reads"]:
        print("      read at beat %-2d -> page %d" % (r["at_beat"], r["page"]))


def main():
    viz, pri, beats = S.trace_scene(with_beats=True)
    meas = measured()

    # ★★ DROPPING THE MIRROR IS A SET CHANGE, NOT A SIZE CHANGE, and that is the whole
    # subtlety. With baked mirrors, `Vexit -> Vwalk2` reuses the walk's cel NUMBERS and
    # none of its baked BYTES (P3.76 §3E) — v48_m..v53_m are separate data used only at
    # the exit. Mirror at draw time and the exit reuses the NORMAL walk cels instead, so
    # v48..v53 become live from beat 4 all the way to beat 16 rather than retiring at 9.
    # The bytes go away; the RESIDENCY gets longer. Only the packer can say which wins.
    normal_of = {}
    for _bi, _n, _p, vs in beats:
        for (who, cel, face, ph) in vs:
            if not face:
                normal_of.setdefault((who, cel), (who, cel, 0, ph))

    def remap(v, drop_mirrors):
        if not drop_mirrors or not v[2]:
            return v
        # a mirrored draw becomes the normal cel of the same number, mirrored at run time
        return normal_of.get((v[0], v[1]), (v[0], v[1], 0, v[3]))

    def beats_for(drop_mirrors):
        return [(bi, nm, pl, {remap(v, drop_mirrors) for v in vs})
                for bi, nm, pl, vs in beats]

    def sizes_for(drop_mirrors, pack_hdr):
        sz = {}
        for _bi, _n, _p, vs in beats_for(drop_mirrors):
            for v in vs:
                lab = lab_of(v)
                if lab not in meas:
                    continue
                total, n_seg = meas[lab]
                if pack_hdr:
                    total -= n_seg          # one byte saved per segment, exactly
                sz[v] = total
        return sz

    print("=== how many disk loads does the scene need? (the packer decides) ===\n")

    base = sizes_for(False, False)
    n_mirror = sum(v for k, v in base.items() if k[2])
    print("  scene cel bytes today            %s B" % format(sum(base.values()), ","))
    print("  of which mirrored variants       %s B" % format(n_mirror, ","))
    seg_saving = sum(meas[lab_of(k)][1] for k in base if lab_of(k) in meas)
    print("  segments across the scene        %s  (1 B saved each if packed)\n"
          % format(seg_saving, ","))

    run("today (baked mirrors)", beats_for(False), base, "<- what ships")
    run("mirror at draw time", beats_for(True), sizes_for(True, False), "")
    run("packed segment header", beats_for(False), sizes_for(False, True), "")
    run("both", beats_for(True), sizes_for(True, True), "")

    print("\n  (a 'staged read' is 2 tracks and froze the torches 3.19 s / 2.89 s")
    print("   measured on the machine at P3.78; one DISK LOAD is the startup read.)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
