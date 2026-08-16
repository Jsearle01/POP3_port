#!/usr/bin/env python3
r"""pack_probe.py — P3.96: what does the scene cost now, and what is the SMALLEST change
that makes it pack?

bake_scene prints "THE SCENE DOES NOT PACK" and stops, which is the right thing for a
build and the wrong thing for a decision. The decision Jay has in front of him — accept a
second freeze, take a fourth block, or find bytes — needs three numbers the failure
message does not carry:

    * the loaded total, and how many pages it wants
    * WHICH beat is the one that will not fit, and by how much
    * what the minimum relaxation is: one more read point, or one more block

★ AND EVERY EXISTING FIGURE IS SCOPED TO THE STUBS. The eight `vcast-*` cels were baked
from the wrong table for the project's whole life [P3.95], so every pack and margin number
on the record was measured with 13-row 2-byte stubs standing in for 48-to-50-row cels.
This re-measures against the corrected artifact.

It reuses bake_scene's OWN inputs — the same trace, the same per-file segment-stream sizes
— so this cannot disagree with the build about what it is costing. Nothing here writes.
"""
import pathlib
import sys

ROOT = pathlib.Path("C:/Projects/POP3_port")
sys.path.insert(0, str(ROOT / "harness/tools"))
sys.path.insert(0, str(ROOT / "harness/tools/sprite_tool"))

import bake_scene as S                                          # noqa: E402
import cel_pack as K                                            # noqa: E402


SEG = __import__("re").compile(r"(\d+) segment bytes")


def inputs():
    """bake_scene's own packer inputs, rebuilt from the files it just wrote.

    The sizes are read from each emitted `<label>.s` header — the same "N segment bytes"
    cel_blit_prep prints and bake_scene adds 2 to for the rows/width pair — so this is
    costed against the ARTIFACT, exactly as the build is, and cannot drift from it.
    """
    _viz, _pri, beats = S.trace_scene(with_beats=True)
    want = S.needed()
    label_of, size_of = {}, {}
    for (who, cel, facing), (phases, _x) in sorted(want.items()):
        stem = S.stem_for(who, cel) + ("_m" if facing else "")
        for ph in phases:
            label = "%s_p%d" % (stem, ph)
            f = S.OUT / ("%s.s" % label)
            if not f.exists():
                raise SystemExit("  missing %s — run bake_scene.py first" % f)
            m = SEG.search(f.read_text(errors="replace"))
            if not m:
                raise SystemExit("  %s has no segment-byte count in its header" % f)
            label_of[(who, cel, facing, ph)] = label
            size_of[(who, cel, facing, ph)] = int(m.group(1)) + 2
    lo = min(c for _w, c, _f, _p in label_of)
    hi = max(c for _w, c, _f, _p in label_of)
    table_bytes = (hi - lo + 1) * 8 * 2
    reads_at = [bi for bi, _nm, n, _vs in beats
                if S.PLAN[bi][0] == "song" and n >= 40]
    return beats, size_of, table_bytes, reads_at


def main():
    beats, size_of, table_bytes, reads_at = inputs()

    total = sum(size_of.values())
    print("  === THE SCENE'S CEL BYTES, corrected cels in ===")
    print("    %d variants, %d bytes of segment stream" % (len(size_of), total))
    print("    walk table %d B; resident cap %d B; rotating page cap %d B"
          % (table_bytes, K.RES_CAP, K.ROT_CAP))
    print("    read points offered: %s" % (reads_at,))

    # ── per beat, what has to be resident at once ────────────────────────────────────
    print()
    print("  === PER-BEAT DEMAND (the rotating page must hold this beat's non-resident set) ===")
    print("    beat  name              plays   variants   bytes")
    worst = []
    for bi, nm, n, vs in beats:
        b = sum(size_of.get(v, 0) for v in vs)
        worst.append((b, bi, nm, len(vs)))
        print("    %-5d %-17s %-7d %-10d %d" % (bi, nm, n, len(vs), b))
    worst.sort(reverse=True)
    print()
    print("    heaviest beat: %d (%s) at %d B against a %d B rotating block"
          % (worst[0][1], worst[0][2], worst[0][0], K.ROT_CAP))
    if worst[0][0] > K.ROT_CAP:
        print("    ★ THAT BEAT ALONE EXCEEDS ONE BLOCK BY %d B — no grouping or read"
              % (worst[0][0] - K.ROT_CAP))
        print("      schedule can fix it; the only remedies are fewer bytes in that beat")
        print("      or a bigger window.")

    # ── the minimum relaxation ───────────────────────────────────────────────────────
    print()
    print("  === WHAT WOULD MAKE IT PACK ===")
    # ROT_BLOCKS is a 3-tuple, and pack() indexes it by page number — so probing a 4th
    # rotating block means widening it. $0C is the PINNED block, so a 4th rotating one
    # does not exist on this machine; the probe is here to say what it WOULD buy, which
    # is the number Jay needs to weigh "take a block from somewhere else" against.
    real = K.ROT_BLOCKS
    tried = []
    for n_rot in (3, 4):
        K.ROT_BLOCKS = real if n_rot == 3 else real + (0x0B,)
        # ★ THE LAST CASE OFFERS EVERY BEAT. read_beats is what the packer may use as a
        # page BOUNDARY as well as where it may issue a read, and those are different
        # properties: a boundary is free, a read costs ~2.8 s of frozen torches and can
        # only hide in a long hold. Offering everything and then CHECKING where the reads
        # actually landed separates the two — see the assertion this probe motivates.
        allb = [b for b, _n, _p, _v in beats]
        for extra in ([], [3], [7], [3, 7], [3, 7, 13], allb):
            pts = sorted(set(reads_at) | set(extra))
            key = (n_rot, tuple(pts))
            if key in tried:
                continue
            tried.append(key)
            try:
                p = K.pack(beats, size_of, table_bytes, pts, n_rot=n_rot)
            except (K.PackError, IndexError) as e:
                print("    %d blocks, reads at %-18s -> no%s"
                      % (n_rot, pts, "" if isinstance(e, K.PackError) else " (index)"))
                continue
            print("    %d blocks, reads at %-18s -> ** PACKS: %d pages, %d reads"
                  % (n_rot, pts, len(p["pages"]), len(p["reads"])))
            print()
            print("  === THE SCHEDULE IT FOUND ===")
            print("    resident %d B" % sum(size_of.get(v, 0) for v in p["resident"]))
            for k, pg in enumerate(p["pages"]):
                print("    page %d: %d B, %d variants"
                      % (k, sum(size_of.get(v, 0) for v in pg), len(pg)))
            # ★ WHICH BEAT THE READ LANDS IN IS THE WHOLE QUESTION. A page is two tracks
            # and the CPU IS the transfer, so the freeze has to hide inside a hold long
            # enough to cover it — which is why the offered set was song beats of >= 40
            # plays. A read scheduled into a 5-play beat would freeze longer than the beat.
            for r in p["reads"]:
                bi = r["at_beat"]
                nm, plays = next((n, pl) for b, n, pl, _v in beats if b == bi)
                print("    read: page %d into block $%02X at beat %d (%s, %d plays)"
                      % (r["page"], r["block"], bi, nm, plays))
                if plays < 40:
                    print("      ★ %d PLAYS IS TOO SHORT TO HIDE A ~2.8 s TRANSFER" % plays)
            K.ROT_BLOCKS = real
            return 0
    K.ROT_BLOCKS = real
    print()
    print("    nothing probed packs — including a hypothetical 4th rotating block.")
    print("    That points at BYTES rather than at the schedule.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
