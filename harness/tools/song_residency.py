"""song_residency.py — P4.8: the PEAK, not the sum, and against the right denominator.

★★★ P4.7 REPORTED A RATIO WITH BOTH HALVES WRONG, and Jay caught it: "I still feel like he
is comparing apples to oranges. The whole song bank doesn't have to be resident, just the
one about to be used. And once played, the next song could use the same memory."

    numerator    8,588 B — the SUM of six songs. They play ONE AT A TIME, and
                 play_song(id, frames) guarantees it: the next beat's song is not wanted
                 until the current one ends.
    denominator  1,024 B — the oracle's resident SET, holding sixteen-plus songs, because
                 MSYS indexes into a whole set.

So a sum was divided by a set and read as one song against another. ★★ THIS IS THE THIRD
TIME A SUM HAS STOOD IN FOR A RESIDENCY REQUIREMENT HERE — P3.62 (peak was 17% of the sum)
and P3.72m (18%) were the other two, both in the cel subsystem. Recurring in a different
subsystem makes it a property of the project rather than of the cel data.

---------------------------------------------------------------------------
WHAT THIS MEASURES
---------------------------------------------------------------------------
  * per song, DECOMPRESSED — what the player walks, and what must be resident if the
    player needs the whole song in memory
  * per song, COMPRESSED — what it costs on disk, through the LZ decoder the port
    ALREADY SHIPS (src/engine/lz_unpack.s)
  * the MAXIMUM MATCH OFFSET in each compressed song

★★★ THE LAST ONE IS THE INTERESTING NUMBER AND IT IS A FACT ABOUT THE FORMAT, NOT A
PREFERENCE. LZ4-style matches copy from the DECODED OUTPUT, so a decoder that expanded
incrementally as the FIRQ consumed segments would still have to keep every byte within the
largest back-reference. If the largest offset in a song is close to the song's own size,
streaming buys nothing: the history window IS the song. If it is small, the resident cost
is a window plus the compressed source, which would be SMALLER than the oracle's set.

Nothing here chooses a representation. The choice turns on whether the two SOUND the same,
which is Jay's.
"""
import argparse
import pathlib
import struct
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import lz_pack
from song_size_census import read_pairs, pack, to_bytes

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

ORACLE_SET = 1024        # what loadmusic1/2 actually read: 4 sectors into $d000 (P4.7 §3D)


def match_offsets(src, outlen):
    """Walk the compressed block and return every back-reference distance.

    ★ Mirrors lz_pack.decompress's parse exactly; if the two ever disagree this tool is
    wrong and the number it prints is fiction, so it is written against that decoder rather
    than against the format description.
    """
    offs, produced, i = [], 0, 0
    while produced < outlen:
        tok = src[i]; i += 1
        litlen = tok >> 4
        if litlen == 15:
            while True:
                b = src[i]; i += 1; litlen += b
                if b != 255:
                    break
        i += litlen
        produced += litlen
        if produced >= outlen:
            break
        off = struct.unpack('>H', src[i:i + 2])[0]; i += 2
        mlen = (tok & 15) + lz_pack.MIN_MATCH
        if (tok & 15) == 15:
            while True:
                b = src[i]; i += 1; mlen += b
                if b != 255:
                    break
        offs.append(off)
        produced += mlen
    return offs


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("songs", nargs="+")
    a = ap.parse_args()

    rows = []
    for path in a.songs:
        pairs = read_pairs(path)
        if not pairs:
            continue
        runs, over, silent = pack(pairs)
        raw = to_bytes(runs, 4)
        comp = lz_pack.compress(raw)
        chk = lz_pack.decompress(comp, len(raw))
        assert chk == raw, f"{path}: the round trip does not agree — the sizes below are fiction"
        offs = match_offsets(comp, len(raw))
        rows.append((pathlib.Path(path).stem, len(raw), len(comp),
                     max(offs) if offs else 0, sum(p + r for p, r in pairs) / 1e6))

    print(f"{'song':22s} {'span s':>7s} {'RAW B':>7s} {'LZ B':>7s} {'ratio':>6s} "
          f"{'max off':>8s} {'off/raw':>8s}")
    for n, raw, comp, mo, span in rows:
        print(f"{n:22s} {span:7.2f} {raw:7d} {comp:7d} {comp/raw:6.2f} {mo:8d} "
              f"{mo/raw:8.2f}")
    print("-" * 78)

    peak_raw = max(r[1] for r in rows)
    peak_raw_n = [r[0] for r in rows if r[1] == peak_raw][0]
    peak_lz = max(r[2] for r in rows)
    peak_lz_n = [r[0] for r in rows if r[2] == peak_lz][0]
    tot_raw = sum(r[1] for r in rows)
    tot_lz = sum(r[2] for r in rows)

    print()
    print("★★★ THE PEAK — one song at a time, because play_song(id, frames) plays one.")
    print(f"  largest DECOMPRESSED song : {peak_raw:6d} B  ({peak_raw_n})")
    print(f"  largest COMPRESSED song   : {peak_lz:6d} B  ({peak_lz_n})")
    print(f"  the SUM of all six        : {tot_raw:6d} B raw / {tot_lz:6d} B compressed")
    print(f"  peak is {100.0*peak_raw/tot_raw:.0f}% of the raw sum — a sum was never the requirement")
    print()
    print(f"★ AGAINST THE ORACLE'S RESIDENT SET ({ORACLE_SET} B, holding ALL of them):")
    print(f"  port peak resident, decompressed : {peak_raw:6d} B  = {peak_raw/ORACLE_SET:.2f}x")
    print(f"  port peak resident, compressed   : {peak_lz:6d} B  = {peak_lz/ORACLE_SET:.2f}x")
    print("  ★★ AND THE TWO SIDES ARE STILL DIFFERENT QUANTITIES: the oracle's 1,024 B holds")
    print("     EVERY song and never reloads; the port's peak is ONE song and the next beat")
    print("     needs a load. That is a disk-access question, not a memory one, and this")
    print("     tool does not answer it.")
    print()
    print("★★★ CAN IT BE STREAMED? The largest back-reference bounds the history a decoder")
    print("    must keep, because LZ4 matches copy from the DECODED OUTPUT.")
    for n, raw, comp, mo, span in rows:
        verdict = ("window IS the song — streaming saves nothing"
                   if mo > raw * 0.5 else
                   f"a {mo} B history window would do")
        print(f"    {n:22s} max offset {mo:5d} of {raw:5d} B  -> {verdict}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
