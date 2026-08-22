#!/usr/bin/env python3
r"""game_census.py - P5.12. The whole-game tile census, per level and per tileset.

★★★ TWO QUANTITIES, NEVER MERGED [§5.222 and seven prior instances]:

  LARGEST LEVEL   a RESIDENCY requirement, extent = one level, IF levels load one at a time.
  WHOLE-GAME SUM  a SUM, extent = all fifteen levels; a residency only if all are resident.

Every table below says which it is.

★★ AND THE ART FOR ONE THIRD OF THE GAME IS NOT IN THE TREE. `bgset1` maps levels to three
tilesets [MISC.S:772] and `bg1trk hex 05,00,07` / `bg2trk hex 12,02,09` [MASTER.S:524-525]
confirm three distinct on-disk sets. The vendored Images/ directory holds TWO --
IMG.BGTAB{1,2}.DUN and IMG.BGTAB{1,2}.PAL. So:

    tileset 00  levels 0,1,2,3          DUN   measurable
    tileset 01  levels 4,5,6,10,11,14   PAL   measurable
    tileset 02  levels 7,8,9,12,13      ---   ART ABSENT FROM THE TREE

Ten of fifteen levels can be costed in BYTES. All fifteen can be costed in VARIETY, because
the blueprints are all present. The five unmeasured levels are BOUNDED from the measured ones
and the bound is labelled as such -- it is not presented as a measurement.

★ THE RATE THAT TRANSFERS IS THE DEDUPED ONE. Dividing the NAIVE total by the measured pair
count and adding the result to a DEDUPED total mixes two quantities in one sum -- the error
§8 names, and one this file made in its first version. Tileset 02's five levels would dedup
among themselves as 00 (four levels) and 01 (six) do, so the rate is bytes-per-pair AFTER
dedup, taken per tileset and averaged.

★ DEDUP IS WITHIN A TILESET ONLY [§5.236]. Levels sharing a tileset share art; levels in
different tilesets draw different pictures from different files, and merging them would
invent a saving that does not exist.

MODEL: the OPAQUE-RECTANGLE bake P5.5 proved buildable [§5.216], via bake_screen.bake --
NOT P5.4's transparent-shape model, whose totals are a different quantity.
"""
import argparse
import statistics
import sys
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "harness/tools"))

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

import bake_screen as BS                                         # noqa: E402
import bg_compose as B                                           # noqa: E402

BLOCK = 8192

# [MISC.S:772] bgset1 db 00,00,00,00,01,01,01,02,02,02,01,01,02,02,01
BGSET = [0, 0, 0, 0, 1, 1, 1, 2, 2, 2, 1, 1, 2, 2, 1]
SETNAME = {0: "DUN", 1: "PAL", 2: None}


def variety(level):
    """Distinct (objid, state) pairs a level's blueprint names, and its non-empty blocks."""
    bp = B.Blueprint((B.LEVELS / level).read_bytes())
    pairs, blocks = set(), 0
    for i in range(720):
        t = bp.type[i] & 0x1F
        if t != 0:
            blocks += 1
        pairs.add((t, bp.spec[i]))
    return len(pairs), blocks


def level_bake(level, bgset):
    uni, ents = {}, 0
    for s in range(1, 25):
        try:
            _, variants, order, _ = BS.bake(level, s, bgset)
        except SystemExit:
            continue
        if not order:
            continue
        ents += len(order)
        for key in variants:
            uni[key] = len(key[0])
    return uni, ents


def corr(xs, ys):
    mx, my = statistics.mean(xs), statistics.mean(ys)
    num = sum((a - mx) * (b - my) for a, b in zip(xs, ys))
    den = (sum((a - mx) ** 2 for a in xs) * sum((b - my) ** 2 for b in ys)) ** 0.5
    return num / den if den else 0.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--block", type=int, default=BLOCK)
    args = ap.parse_args()

    def blk(b):
        return -(-int(b) // args.block)

    print("=" * 78)
    print("AC5 — VARIETY, ALL FIFTEEN LEVELS (blueprint only; art not required)")
    print("=" * 78)
    print("  %-8s %7s %10s %11s   %s" % ("level", "tileset", "blocks", "distinct", "art"))
    var = {}
    for n in range(15):
        p, b = variety("LEVEL%d" % n)
        var[n] = (p, b)
        print("  LEVEL%-3d %7d %10d %11d   %s"
              % (n, BGSET[n], b, p, SETNAME[BGSET[n]] or "★ ABSENT"))
    wv = max(var, key=lambda k: var[k][0])
    wb = max(var, key=lambda k: var[k][1])
    print()
    print("  ★ most VARIED  LEVEL%d — %d distinct (obj,state) pairs, %d blocks"
          % (wv, var[wv][0], var[wv][1]))
    print("  ★ most DENSE   LEVEL%d — %d blocks, %d distinct pairs"
          % (wb, var[wb][1], var[wb][0]))
    print("  LEVEL0 sits at %d pairs / %d blocks — the smallest level in the game."
          % (var[0][0], var[0][1]))

    print()
    print("=" * 78)
    print("AC2/AC3 — TILE VARIANTS AND BYTES, the ten levels whose art is vendored")
    print("=" * 78)
    print("  Opaque-rectangle model [§5.216]. Per level: a RESIDENCY figure (one level).")
    print()
    print("  %-8s %5s %9s %9s %10s %7s" % ("level", "set", "variants", "entries",
                                           "bytes", "blocks"))
    per, bysets = {}, {0: {}, 1: {}}
    for n in range(15):
        name = SETNAME[BGSET[n]]
        if name is None:
            continue
        uni, ents = level_bake("LEVEL%d" % n, name)
        b = sum(uni.values())
        per[n] = (len(uni), ents, b)
        bysets[BGSET[n]].update(uni)
        print("  LEVEL%-3d %5s %9d %9d %10d %7d"
              % (n, name, len(uni), ents, b, blk(b)))
    meas = sorted(per)
    big = max(per, key=lambda k: per[k][2])
    print()
    print("  ★ LARGEST MEASURED LEVEL: LEVEL%d at %d B = %d blocks."
          % (big, per[big][2], blk(per[big][2])))
    print("    ★★ A RESIDENCY FIGURE, extent = ONE LEVEL. It binds if levels load one at a")
    print("       time. It is NOT the whole-game figure and must not be quoted as one.")

    print()
    print("  ★ §8's CHECK — what drives a level's bytes, variety or density?")
    pv = [var[n][0] for n in meas]
    pb = [var[n][1] for n in meas]
    by = [per[n][2] for n in meas]
    cv, cd = corr(pv, by), corr(pb, by)
    print("     bytes vs VARIETY (distinct obj/state pairs) : r = %+.3f" % cv)
    print("     bytes vs DENSITY (non-empty blocks)         : r = %+.3f" % cd)
    print("     -> %s" % ("variety dominates, as P5.4 found." if cv > cd else
                          "★★ DENSITY dominates — this CONTRADICTS P5.4 and outranks "
                          "the census."))

    print()
    print("  PER-TILESET DEDUP — within a tileset only [§5.236]:")
    tot_naive = tot_dedup = 0
    rates = []
    for ts in (0, 1):
        lv = [n for n in meas if BGSET[n] == ts]
        naive = sum(per[n][2] for n in lv)
        ded = sum(bysets[ts].values())
        pairs = sum(var[n][0] for n in lv)
        tot_naive += naive
        tot_dedup += ded
        rates.append(ded / pairs)
        print("    set %02d  %d levels %-20s naive %7d -> deduped %7d  (saves %6d, %.1f%%)"
              % (ts, len(lv), ",".join(str(x) for x in lv), naive, ded,
                 naive - ded, 100.0 * (naive - ded) / naive if naive else 0))
        print("            %d distinct pairs -> %.0f B/pair deduped" % (pairs, ded / pairs))
    print("    " + "-" * 72)
    print("    measured (sets 00+01, 10 levels): naive %d B -> %d B = %d blocks"
          % (tot_naive, tot_dedup, blk(tot_dedup)))

    print()
    print("=" * 78)
    print("AC4 — THE WHOLE-GAME FIGURE, the missing third BOUNDED not measured")
    print("=" * 78)
    miss = [n for n in range(15) if n not in per]
    rate = sum(rates) / len(rates)
    mp = sum(var[n][0] for n in miss)
    est = mp * rate
    print("  mean DEDUPED rate %.0f B/pair; tileset 02 carries %d pairs over %d levels"
          % (rate, mp, len(miss)))
    print("  -> ESTIMATED %.0f B = %d blocks" % (est, blk(est)))
    print("     ★ AN ESTIMATE. Tileset 02's art is not in the tree; this scales the measured")
    print("       deduped bytes-per-variety rate onto the blueprints that are.")
    print()
    print("  WHOLE-GAME SUM (a SUM, extent = all fifteen levels):")
    print("    measured 10 levels, deduped within tileset : %8d B  %3d blocks"
          % (tot_dedup, blk(tot_dedup)))
    print("    estimated 5 levels (tileset 02)            : %8.0f B  %3d blocks"
          % (est, blk(est)))
    print("    " + "-" * 62)
    print("    whole-game estimate                        : %8.0f B  %3d blocks"
          % (tot_dedup + est, blk(tot_dedup + est)))
    print()
    print("  ★★ THE TWO FIGURES THIS DISPATCH MUST NOT MERGE:")
    print("     LARGEST LEVEL  %7d B = %2d blocks   RESIDENCY, one level at a time"
          % (per[big][2], blk(per[big][2])))
    print("     WHOLE GAME     %7.0f B = %2d blocks   a SUM; residency only if all resident"
          % (tot_dedup + est, blk(tot_dedup + est)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
