"""cel_content_offset.py — P3.103 §1: where do the PIXELS sit inside the footprint?

★★★ WHY THIS EXISTS. P3.100 measured `ch_dest` and found the port's exit column identical
to the oracle's, to the pixel, for all six walk cels. That measured the DESTINATION ADDRESS
— the left edge of the FOOTPRINT. It said nothing about where the ink sits INSIDE that
footprint, and Jay's lead is precisely there: "if the cells are the same mirrored, then the
x offsets have to be wrong."

★★ AND THERE IS A MECHANISM IN THE CONVERTER THAT WOULD DO IT, ALREADY DOCUMENTED AS A
HAZARD BY THE CONVERTER'S OWN CLI HELP AND NEVER CHECKED FOR THESE CELS:

    sprite_convert.py --no-trim:
      'Keep all-zero leading/trailing byte columns. NOTE: trimming shifts the cel origin
       left by `lead` bytes - the placement table must compensate'

Trimming is ON by default. It strips blank byte columns from BOTH ends and records
`lead`/`trail` in a dict that is printed and then dropped. **Nothing in bake_scene, the cel
table or the engine adds `lead` back** — grep for it: the only other `lead` in the tree is
`bc_lead`, which is the clip window and a different thing entirely.

So a cel trimmed with lead=L has its byte 0 holding what was byte L of the sprite, and the
engine places byte 0 at the sprite's true left edge. **The ink therefore lands 4*L pixels
too far LEFT.**

★★★ AND THE MIRROR IS EXACTLY WHERE THAT STOPS BEING HARMLESS. A constant displacement is
invisible — the character is a few pixels off and walks smoothly. What is visible is a
displacement that CHANGES from cel to cel, because then the character's ink jitters against
its own motion. And mirroring SWAPS the blank columns: the left margin of the mirrored cel
is the right margin of the unmirrored one. There is no reason for those to be equal, and
every reason for the difference to vary per cel, because each pose has a different
silhouette.

★ THE PRECEDENT IS P3.52's TORCHES — left +1, right -1 — the same shape one level down.

WHAT THIS MEASURES, all offline, no machine:
  1. For each of the six walk cels, both facings: convert with trim OFF, so the container is
     the full ceil(awid*7/4) bytes and byte 0 IS the sprite's left edge.
  2. Find the ink extent (first and last non-black BYTE column) — which is exactly the
     lead/trail the shipped, trimmed conversion applies.
  3. Report the resulting displacement, per cel, per facing, and WHETHER IT ALTERNATES
     across the walk cycle — alternation is what produces a slip; a constant offset
     produces a displaced but smooth walk.
  4. Cross-check the mirror itself: the mirrored ink extent should be the exact reflection
     of the unmirrored one inside width_pixels. If it is not, the reversal is not clean and
     that is a second, separate defect.

★ A LEAD IS NOT A FINDING, INCLUDING JAY'S. This tool can refute it: if every lead is 0, or
if they are all equal within a facing, the content is not displaced and both leads close.
"""
import argparse
import pathlib
import sys

# Windows' default console encoding is cp1252 and this file's output carries the project's
# star markers; without this the tool dies mid-report with UnicodeEncodeError on ★
# AFTER printing the table, which reads as a crash rather than as an encoding default.
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import cel_parity_rule as R                      # noqa: E402
import sprite_convert as SC                      # noqa: E402

WALK = [48, 49, 50, 51, 52, 53]


def ink_extent(bitmap, width, height):
    """(first, last) non-black BYTE column, or (None, None) for an empty cel."""
    has = [any(bitmap[r * width + c] != 0 for r in range(height)) for c in range(width)]
    if not any(has):
        return None, None
    return (next(i for i in range(width) if has[i]),
            next(i for i in range(width - 1, -1, -1) if has[i]))


def pixel_ink_extent(bitmap, width, height):
    """(first, last) non-black PIXEL column — finer than the byte extent, and it is the
    pixel one the mirror check needs: a byte-level reflection can look clean while the
    pixels inside it are off by up to three."""
    lo, hi = None, None
    for r in range(height):
        for c in range(width):
            b = bitmap[r * width + c]
            if b == 0:
                continue
            for p in range(4):
                if (b >> (6 - 2 * p)) & 3:
                    x = c * 4 + p
                    if lo is None or x < lo:
                        lo = x
                    if hi is None or x > hi:
                        hi = x
    return lo, hi


def analyse(cel, mirror):
    """Convert one cel with trim OFF and report where its ink actually sits."""
    tab = R.table_path(cel)
    idx = R.chartable(cel)[1]
    c = SC.get_cel(str(tab), idx)
    height, apple_width = c["h"], c["w"]
    bitmap = c["data"]
    # the same bottom-row-first flip convert_one does at ingest; without it the row order
    # differs from the shipped cel and the ink extent is still right, but the artefact
    # would not be byte-comparable to what ships.
    bitmap = [b for r in range(height - 1, -1, -1)
              for b in bitmap[r * apple_width:(r + 1) * apple_width]]
    # start_col only picks chroma; it cannot move ink, so 0 is fine for a POSITION question
    # and using the real render column would make this depend on the trace.
    bm, w = SC.convert_sprite_to_coco3(bitmap, height, apple_width, 0, False, mirror)
    L, Rr = ink_extent(bm, w, height)
    plo, phi = pixel_ink_extent(bm, w, height)
    return dict(cel=cel, mirror=mirror, h=height, awid=apple_width,
                width_px=apple_width * 7, full_w=w,
                lead=L, trail=(w - 1 - Rr) if Rr is not None else None,
                px_lo=plo, px_hi=phi)


def scan_all(cels):
    """Every cel, both facings — which ones ship with their ink displaced."""
    bad = []
    for cel in cels:
        for mirror in (False, True):
            try:
                d = analyse(cel, mirror)
            except Exception as e:                     # a cel the table cannot resolve
                print("  cel %-3d %-9s SKIPPED (%s)" % (cel, "MIRRORED" if mirror else "normal",
                                                        str(e)[:50]))
                continue
            if d["lead"]:
                bad.append(d)
    print("# EVERY CEL WITH A NON-ZERO LEAD — these ship with their ink 4*lead px LEFT of")
    print("# where the engine places their footprint, because nothing adds the lead back.")
    print()
    print("  cel  facing    awid  container  lead  displacement")
    for d in bad:
        print("  %-4d %-9s %-5d %-10d %-5d %+d px"
              % (d["cel"], "MIRRORED" if d["mirror"] else "normal", d["awid"],
                 d["full_w"], d["lead"], -4 * d["lead"]))
    if not bad:
        print("  (none)")
    print()
    print("# %d of %d (cel, facing) pairs are displaced." % (len(bad), 2 * len(cels)))
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--cels", default=",".join(str(c) for c in WALK))
    ap.add_argument("--all", action="store_true",
                    help="every cel the scene bakes, both facings — the blast radius")
    args = ap.parse_args()
    if args.all:
        # ★ THE BLAST RADIUS, and it is a property of the CONVERTER rather than of this
        # scene: every cel with a real image is scanned in both facings, so the answer does
        # not depend on which beats happen to be baked today.
        alt = R.altset2()
        cels = sorted(c for c, v in alt.items() if v[0])
        return scan_all(cels)
    cels = [int(x) for x in args.cels.split(",")]

    rows = {}
    print("# THE INK'S POSITION INSIDE THE FOOTPRINT — converted with trim OFF, so byte 0")
    print("# IS the sprite's left edge and `lead` is exactly what the shipped (trimmed)")
    print("# conversion removes from that end.")
    print()
    print("  cel  facing    awid  px wide  container  ink bytes   lead  trail  ink px")
    for mirror in (False, True):
        for cel in cels:
            d = analyse(cel, mirror)
            rows[(cel, mirror)] = d
            print("  %-4d %-9s %-5d %-8d %-10d [%d..%d]     %-5s %-6s %d..%d"
                  % (d["cel"], "MIRRORED" if mirror else "normal", d["awid"],
                     d["width_px"], d["full_w"], d["lead"], d["full_w"] - 1 - d["trail"],
                     d["lead"], d["trail"], d["px_lo"], d["px_hi"]))
        print()

    # ---- 1. is the mirror itself clean? -------------------------------------------
    print("# ★ IS THE MIRROR A CLEAN REFLECTION? Reversing a list of width_px pixels maps")
    print("#   pixel x -> width_px-1-x, so the mirrored ink must span")
    print("#   [width_px-1-hi, width_px-1-lo] exactly. Anything else is a second defect.")
    clean = True
    for cel in cels:
        a, b = rows[(cel, False)], rows[(cel, True)]
        want_lo = a["width_px"] - 1 - a["px_hi"]
        want_hi = a["width_px"] - 1 - a["px_lo"]
        ok = (b["px_lo"] == want_lo and b["px_hi"] == want_hi)
        clean = clean and ok
        print("    cel %-3d normal px %3d..%-3d -> mirrored expected %3d..%-3d, got %3d..%-3d  %s"
              % (cel, a["px_lo"], a["px_hi"], want_lo, want_hi, b["px_lo"], b["px_hi"],
                 "OK" if ok else "★ MISMATCH"))
    print("  %s" % ("  => the reversal is exact." if clean
                    else "  => THE REVERSAL IS NOT EXACT — a defect in its own right."))
    print()

    # ---- 2. the displacement the trim causes, and whether it VARIES ----------------
    print("# ★★ THE DISPLACEMENT. Nothing adds `lead` back (grep: the only other `lead` in")
    print("#   the tree is bc_lead, the clip window), so the ink is drawn 4*lead pixels")
    print("#   LEFT of where it belongs. A CONSTANT offset within a facing is a displaced")
    print("#   but smooth walk; a VARYING one is a walk whose ink jitters against its own")
    print("#   motion — which is what a skip looks like.")
    print()
    for mirror in (False, True):
        leads = [rows[(c, mirror)]["lead"] for c in cels]
        disp = [-4 * l for l in leads]
        print("  %-8s  lead per cel %s" % ("MIRRORED" if mirror else "normal",
                                           " ".join("%d:%d" % (c, l) for c, l in zip(cels, leads))))
        print("            displacement px %s"
              % " ".join("%d:%+d" % (c, d) for c, d in zip(cels, disp)))
        span = max(disp) - min(disp)
        print("            spread %d px  =>  %s" % (
            span,
            "CONSTANT — invisible as a jitter" if span == 0
            else "★ VARIES BY %d px ACROSS THE CYCLE" % span))
        print()

    ne = [rows[(c, False)]["lead"] for c in cels]
    mi = [rows[(c, True)]["lead"] for c in cels]
    print("# ★★★ ENTRY vs EXIT, which is the comparison Jay's report is about:")
    print("#   normal   spread %d px" % (4 * (max(ne) - min(ne))))
    print("#   mirrored spread %d px" % (4 * (max(mi) - min(mi))))
    if 4 * (max(mi) - min(mi)) > 4 * (max(ne) - min(ne)):
        print("#   => the MIRRORED cycle jitters more than the normal one. Consistent with")
        print("#      'the exit skips and the entry does not'.")
    elif max(mi) == min(mi) and max(ne) == min(ne):
        print("#   => neither cycle jitters. BOTH LEADS CLOSE: the content is not displaced")
        print("#      relative to itself, and the skip is elsewhere.")
    else:
        print("#   => the normal cycle jitters at least as much. That does NOT match the")
        print("#      report, so the trim is not the explanation on its own.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
