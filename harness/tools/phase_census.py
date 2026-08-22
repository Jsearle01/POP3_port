#!/usr/bin/env python3
r"""phase_census.py - P5.10. How many sub-byte phases each cel is ACTUALLY drawn at.

★★★ A DISTRIBUTION, NOT A MULTIPLIER [§5.222, §5.233]. The storage requirement is the SUM OVER
CELS of the phases each one needs. 271 x 4 is a BOUND; the mean is a different lie. Both are
printed next to the sum so neither can stand in for it.

INPUT: oracle_phase_trace.lua's log -- one line per distinct cel, with the number of times it was
drawn at each of the four CoCo3 sub-byte phases. The phase is computed in the tap as
(XCO*7 + OFFSET + 20) mod 4 from the oracle's own staged draw position [HIRES.S:158-160], where
+20 is the 280->320 centring the port applies.

★ THE TILE CONTROL. P5.7 derived that every block-aligned background piece sits at phase 0 and
every torch flame at phase 3, because 28c mod 4 = 0 and the flame's `inc XCO` adds 7. If the
measurement reproduces that, the instrument is reading the phase correctly. If tiles come back
spread over four phases, the instrument is wrong and the character figure means nothing. So the
control is run first and its result gates the rest.

WHAT THE TRACE CAN AND CANNOT SAY. It is a LOWER BOUND: the demo plays one path, so a cel it
never drew at phase 3 might still be drawable there. A lower bound is the useful direction --
if the measured multiplicity is already high, the derivation cannot lower it.
"""
import argparse
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "harness/tools"))

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

from frame_drawset import TABLES, coco3, load_valid              # noqa: E402

CHAR_KINDS = ("kid", "kid/sword", "opponent")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", default="build/tmp/p510_phase.txt")
    ap.add_argument("--block", type=int, default=8192)
    args = ap.parse_args()

    valid = load_valid()
    rows = []
    dropped = 0
    for ln in pathlib.Path(args.log).read_text().splitlines():
        if not ln.startswith("C "):
            continue
        p = ln.split()
        bank, tb, addr = p[1].split(":")
        bank, tb, addr = int(bank), int(tb, 16), int(addr, 16)
        w, h = (int(x) for x in p[2].split("x"))
        counts = [int(x) for x in p[3:7]]
        nsub, nalign = (int(p[7]), int(p[8])) if len(p) > 8 else (0, 0)
        xs = [int(v) for v in p[9][1:].split(',')] if len(p) > 9 and p[9].startswith('X') and len(p[9]) > 1 else []
        tv = valid.get((bank, tb))
        if tv is None or tv.get(addr) != (w, h):
            dropped += 1
            continue
        rows.append((TABLES[(bank, tb)][1], addr, w, h, counts, nsub, nalign, xs))

    print("VALIDATION — the same exact filter frame_drawset.py applies")
    print("  kept %d cel records, dropped %d (not a cel pointer in its table, or w/h mismatch)"
          % (len(rows), dropped))
    print()

    # ---------------------------------------------------------------- control
    print("=" * 78)
    print("THE CONTROL — cross-instrument agreement, not a self-check")
    print("=" * 78)
    print("  ★ THE FIRST TWO CONTROLS I WROTE WERE BOTH WRONG, AND IN THE SAME WAY: they")
    print("    predicted phases from P5.7's derivation, whose scope is block-aligned scenery")
    print("    and torch flames. It does not cover `drawfrnt`, which places a piece at")
    print("    blockxco + frontx[objid] with frontx values of 0..3 BYTES [BGDATA.S:77], nor")
    print("    the strength meters, which draw at KidStrX columns that are not multiples of 4")
    print("    with real KidStrOFF sub-byte offsets [GAMEBG.S:93-97]. Both legitimately")
    print("    occupy phases P5.7 never claimed they could not. Testing against a claim that")
    print("    was never made is not a control; it is a way to fail forever.")
    print()
    print("  What IS a control: P5.8 recorded the foreground list's XCO values through a")
    print("  DIFFERENT tap (fgX/fgY/fgIMG, the queue) on a different run. This tap reads XCO")
    print("  at setimage. Two instruments, one truth — they must agree.")
    print()
    # ★ AND THE PREDICATE WAS WRONG A THIRD TIME, so it is stated as a RULE now rather than
    # as a set. P5.8's XCO list came from screens 1 and 2 at one instant; this trace runs
    # 3,000 frames across more screens, so neither set contains the other and set-equality
    # can only fail. What both instruments must agree on is the MECHANISM: `drawfrnt` places
    # a piece at blockxco + frontx[objid] [FRAMEADV.S:775-780, BGDATA.S:77], blockxco is
    # colno*4, so every observation of a given image must fall in ONE residue class mod 4,
    # and that class must equal its own frontx entry. That is a claim about the code, checked
    # against two independent taps, and neither tap can satisfy it by accident.
    #   fronti[3]=$45 frontx[3]=1 | fronti[4]=$46 frontx[4]=3 | fronti[20]=$83 frontx[20]=0
    EXPECT = {0x83: 0, 0x45: 1, 0x46: 3}
    P58 = {0x83: {0, 4, 8, 16, 20, 24, 28, 32, 36}, 0x46: {39}, 0x45: {37}}
    IMDIR = ROOT / "oracle/source/01 POP Source/Images"

    def imgmap(fname, base):
        b = (IMDIR / fname).read_bytes()
        m = {}
        for i in range(b[0]):
            ptr = b[1 + 2 * i] | (b[2 + 2 * i] << 8)
            if ptr:
                m[base + (ptr - 0x6000)] = i + 1
        return m

    maps = {(3, 0x6000): imgmap("IMG.BGTAB1.DUN", 0x6000),
            (3, 0x8400): imgmap("IMG.BGTAB2.DUN", 0x8400)}
    agree = disagree = 0
    for kind, addr, w, h, c, ns, na, xs in rows:
        for (bk, tb), mm in maps.items():
            n = mm.get(addr)
            if n is None:
                continue
            img = n if tb == 0x6000 else (n | 0x80)
            if img not in EXPECT:
                continue
            got = set(xs)
            want = EXPECT[img]
            mine = {x % 4 for x in got}
            theirs = {x % 4 for x in P58[img]}
            ok = mine == {want} and theirs == {want}
            print("    image $%02X  frontx=%d | this tap XCO%s -> mod4 %s | P5.8 XCO%s -> mod4 %s  %s"
                  % (img, want, sorted(got), sorted(mine), sorted(P58[img]), sorted(theirs),
                     "AGREE" if ok else "★ DISAGREE"))
            if ok:
                agree += 1
            else:
                disagree += 1
    print()
    if disagree == 0 and agree:
        print("  ★ CONTROL PASSES: %d image(s), both taps, every observation in the single" % agree)
        print("    residue class `drawfrnt` predicts. The position half of the phase is sound.")
    elif not agree:
        print("  ★ CONTROL INCONCLUSIVE: none of P5.8's images appear in this trace.")
    else:
        print("  ★ CONTROL FAILS on %d image(s). Read no further without resolving it." % disagree)

    # And the one shape the freshness rule cannot distinguish.
    both = [r for r in rows if r[5] and r[6]]
    print()
    print("  cels reporting BOTH sub-byte and byte-aligned draws: %d %s"
          % (len(both),
             "— none, so the freshness rule was unambiguous on every draw." if not both
             else "★ — the freshness rule cannot separate these; see the tool header."))
    print()

    # ---------------------------------------------------------------- AC1
    print("=" * 78)
    print("AC1 — THE PER-CEL PHASE DISTRIBUTION, character cels")
    print("=" * 78)
    chars = [r for r in rows if r[0] in CHAR_KINDS]
    dist = {1: [], 2: [], 3: [], 4: []}
    for kind, addr, w, h, c, ns, na, xs in chars:
        n = sum(1 for x in c if x)
        if n:
            dist[n].append((kind, addr, w, h, c))
    tot_cels = sum(len(v) for v in dist.values())
    print("  %d distinct character cels drawn in the traced span" % tot_cels)
    print()
    print("  %-10s %6s %8s %10s %12s" % ("phases", "cels", "%", "1-phase B", "at N phases"))
    base = store = 0
    for n in (1, 2, 3, 4):
        b = sum(coco3(w, h) for _, _, w, h, _ in dist[n])
        base += b
        store += b * n
        print("  %-10d %6d %7.1f%% %10d %12d"
              % (n, len(dist[n]), 100.0 * len(dist[n]) / tot_cels if tot_cels else 0,
                 b, b * n))
    print("  " + "-" * 50)
    print("  %-10s %6d %8s %10d %12d" % ("TOTAL", tot_cels, "", base, store))
    print()
    print("  ★ THE STORAGE FIGURE IS THE SUM OVER CELS: %d B, which is %.2fx the one-phase"
          % (store, store / base if base else 0))
    print("    total of %d B." % base)
    print("    For contrast, and NEITHER of these is the requirement:")
    print("      the BOUND  (every cel at 4 phases) : %6d B  = %.2fx" % (base * 4, 4.0))
    print("      the MEAN   (%.2f phases x total)    : %6d B  -- hides the 4-phase cels"
          % (store / base if base else 0, store))
    print()
    print("  ★ AND THE SUM AND THE BOUND ARE THE SAME NUMBER IF EVERY CEL NEEDS FOUR."
          if store == base * 4 else
          "  ★ The sum is %d B below the bound (%.1f%% saved by cels that need fewer)."
          % (base * 4 - store, 100.0 * (base * 4 - store) / (base * 4) if base else 0))

    # per kind
    print()
    print("  by kind:")
    for k in CHAR_KINDS:
        sub = [r for r in chars if r[0] == k]
        if not sub:
            continue
        hs = {}
        for kind, addr, w, h, c, ns, na, xs in sub:
            n = sum(1 for x in c if x)
            hs[n] = hs.get(n, 0) + 1
        print("    %-10s %3d cels   phases: %s" % (k, len(sub),
              ", ".join("%d->%d cels" % (n, hs[n]) for n in sorted(hs))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
