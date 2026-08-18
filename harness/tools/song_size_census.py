"""song_size_census.py — P4.7/P4.7a: what does a CAPTURED score actually cost, per song?

★★★ THE QUESTION IS WHETHER CAPTURE-AND-REPLAY FITS, and it has to be answered on measured
per-song data rather than extrapolated from a fragment. P4.4 captured 400 frames; P4.6b
captured 5,400 and cut it "where the music stops"; both derived a boundary from the OUTPUT.
The boundary is the CALL — `PlaySongI` with a song id — and oracle_song_capture.lua now
records it. This tool takes those per-song streams and reports what each costs.

What it measures, in order of how much it could change the answer:

  1. THE ROW AS SHIPPED         5 bytes: ticks/frac/width/count. `frac` is dead in the
                               shipping build (the dither was retired on Jay's ear) and is
                               kept only so the packer and player cannot disagree about the
                               format. Reporting 4-byte rows separately makes that cost
                               visible rather than baked in.
  2. DICTIONARY CODING          how many DISTINCT (ticks,width) pairs a song actually uses.
                               Music reuses pitches; if the distinct count is small the row
                               can be an index plus a count.
  3. LZ                         the port ALREADY SHIPS an LZ4-style decoder for the intro
                               screens (harness/tools/lz_pack.py), so this costs no new
                               code — which is the only reason it belongs in the comparison.

★★ AND THE PRECEDENT SAYS TO ASK. The cel work found 64.9% of the image was punctuation and
packing the header saved 27% with no representation change. A segment stream may be
similarly redundant; the 6.5 s fragment was far too short to show it either way.

★ WHAT THIS TOOL DOES NOT DO: choose. The decision turns on whether the two representations
SOUND the same, which is Jay's and not a number.
"""
import argparse
import collections
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import lz_pack

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

# ★★★ THE PLAN ALREADY KNEW, AND NOBODY ASKED IT. Jay: "I thought capturing each song — or
# more importantly, playing each song at the appropriate time — would have been determined
# from the oracle doing exactly that." It was. P3.72l traced s_Princess by FRAME behaviour
# five dispatches before sound existed, and P4.4 then captured a 400-frame window without
# consulting it. Everything downstream refined a fragment whose extent no check questioned,
# because the check that would have caught it was never run.
#
# ★★ IT IS WORTH SOMETHING PRECISELY BECAUSE THE ROUTES ARE INDEPENDENT: these came from
# counting FRAMES of animation; the capture measures the SPEAKER. Two routes to one quantity
# is the standard that made P4.4's 866 credible against P4.2's +808.
#
# ★ AND THESE HAVE NO HOME IN THE TREE — they live in report prose. That is itself the
# finding: the port's play_song carries A=song, X=frames, but those X values are the
# oracle's SOUND-OFF pause (MASTER.S:1375 "X = length to pause if sound is turned off"),
# which is a different quantity from the song's length and must not be confused with it.
PLAN = {
    7: (761, "P3.72l: room f2688 -> her turn f3487 = 799 frames, less ~38 of plays"),
    9: (358, "P3.75: 761 frames (12.7 s) and 358 (6.0 s) of deliberate stillness"),
}

TICK_US = 63.695
TMAX = 4095
CPU_MHZ = 1.7897725
DLY_CYC = 5


def read_pairs(path):
    out = []
    for line in pathlib.Path(path).read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        a, b = line.split()
        out.append((float(a), float(b)))
    return out


def pack(pairs, lat=127.80, lat_adv=195.78, ovh=5.0):
    """Mirrors pack_song.py's quantisation closely enough to size it. Not the packer."""
    def width(p):
        return max(1, min(255, int(round((p * CPU_MHZ - ovh) / DLY_CYC))))
    rows, over, silent = [], 0, 0
    for p, r in pairs:
        t = max(1, int(round((p + r - lat) / TICK_US)))
        head = min(t, TMAX - 1)
        if head < t:
            over += 1
        rows.append((head, width(p)))
        rem = t - head
        lt = int(round(lat / TICK_US))
        while rem > 0:
            n = max(1, min(TMAX - 1, rem) - lt)
            rows.append((n, 0))
            silent += 1
            rem -= n + lt
    runs = []
    for x in rows:
        if runs and runs[-1][0] == x and runs[-1][1] < 255:
            runs[-1][1] += 1
        else:
            runs.append([x, 1])
    return runs, over, silent


def to_bytes(runs, row=4):
    b = bytearray()
    for (t, w), n in runs:
        b += bytes([(t >> 8) & 0xFF, t & 0xFF])
        if row == 5:
            b.append(0)                     # the dead frac byte
        b += bytes([w & 0xFF, n & 0xFF])
    b += b"\x00\x00"
    return bytes(b)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("songs", nargs="+", help="per-song pairs files")
    a = ap.parse_args()

    print(f"{'song':22s} {'span s':>7s} {'cap f':>6s} {'plan f':>6s} {'delta':>7s} "
          f"{'runs':>6s} {'4B':>7s} {'dict':>7s} {'LZ':>7s} {'rests':>6s}")
    tot, bad = collections.Counter(), []
    for path in a.songs:
        pairs = read_pairs(path)
        if not pairs:
            print(f"{pathlib.Path(path).stem:22s}  (empty)")
            continue
        span = sum(p + r for p, r in pairs) / 1e6
        runs, over, silent = pack(pairs)
        b5, b4 = to_bytes(runs, 5), to_bytes(runs, 4)
        # dictionary: distinct (ticks,width) pairs -> index + count per row
        distinct = len(set(k for k, _ in runs))
        idx_bytes = (1 if distinct <= 256 else 2)
        dict_total = len(runs) * (idx_bytes + 1) + distinct * 3 + 2
        lz = len(lz_pack.compress(b4))
        sid = int(pathlib.Path(path).stem.split("_")[1])
        capf = span * 60.0
        pl = PLAN.get(sid)
        if pl:
            d = 100.0 * (capf - pl[0]) / pl[0]
            plan_s, delta_s = f"{pl[0]:6d}", f"{d:+6.1f}%"
            if abs(d) > 5.0:
                bad.append((sid, capf, pl))
        else:
            plan_s, delta_s = "     -", "      -"
        print(f"{pathlib.Path(path).stem:22s} {span:7.2f} {capf:6.0f} {plan_s} {delta_s} "
              f"{len(runs):6d} {len(b4):7d} {dict_total:7d} {lz:7d} {over:6d}")
        tot["span"] += span
        tot["segs"] += len(pairs)
        tot["runs"] += len(runs)
        tot["b5"] += len(b5)
        tot["b4"] += len(b4)
        tot["dict"] += dict_total
        tot["lz"] += lz
        tot["over"] += over
        tot["silent"] += silent
    print("-" * 96)
    print(f"{'TOTAL':22s} {tot['span']:7.2f} {tot['span']*60:6.0f} {'':6s} {'':7s} "
          f"{tot['runs']:6d} {tot['b4']:7d} {tot['dict']:7d} {tot['lz']:7d} {tot['over']:6d}")
    print()
    if bad:
        print("★★★ A CAPTURE DISAGREES WITH THE PLAN BY MORE THAN 5% — STOP AND REPORT.")
        for sid, capf, pl in bad:
            print(f"    id {sid}: captured {capf:.0f} f vs plan {pl[0]} f  [{pl[1]}]")
    else:
        print("★ Every song with a traced duration agrees with it within 5%. Two independent")
        print("  routes — frame counting and a speaker tap — to the same quantity.")
    print()
    print("★ THE ORACLE'S OWN SCORE, for the same six songs: MUSIC.SET1 = 4,608 B.")
    print(f"  captured, as shipped (5-byte rows) : {tot['b5']:6d} B   {tot['b5']/4608:.2f}x")
    print(f"  captured, 4-byte rows              : {tot['b4']:6d} B   {tot['b4']/4608:.2f}x")
    print(f"  captured, dictionary-coded         : {tot['dict']:6d} B   {tot['dict']/4608:.2f}x")
    print(f"  captured, LZ (decoder already ships): {tot['lz']:6d} B   {tot['lz']/4608:.2f}x")
    print(f"  long rests INSIDE songs: {tot['over']}   silent filler rows: {tot['silent']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
