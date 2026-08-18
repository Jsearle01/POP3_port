"""wav_trim.py — P4.6: cut a MAME session recording down to the part that makes noise.

★ MAME's -wavwrite records the WHOLE session from frame 0, so the oracle's rendition of
s_Princess sits 44 seconds inside a 25 MB file and the port's sits 21 seconds inside a
12 MB one. Handing someone that and saying "skip to 44 s" spends their attention on
transport controls; the ear gate is expensive enough already.

★★ THE THRESHOLD IS RELATIVE TO THE FILE'S OWN IDLE LEVEL, not to zero. Both machines sit
at a large non-zero DC level when silent (6144 on the Apple, 8192 on the CoCo3), so an
absolute threshold would either find everything or nothing. The baseline is taken as the
median of the first second, which on both machines is before anything is playing.

Prints where it cut and how loud the kept part is — a trim that silently produced silence
would look exactly like a trim that worked.
"""
import argparse
import array
import pathlib
import statistics
import sys
import wave

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--wav", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--after", type=float, default=0.0, help="ignore activity before this second")
    ap.add_argument("--pad", type=float, default=0.3, help="seconds of silence to keep either side")
    ap.add_argument("--thresh", type=float, default=0.08,
                    help="fraction of the loudest deviation that counts as activity")
    a = ap.parse_args()

    w = wave.open(a.wav, "rb")
    ch, sw, sr, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
    if sw != 2:
        sys.exit(f"[wav_trim] {a.wav}: sample width {sw}, expected 16-bit")
    raw = array.array("h")
    raw.frombytes(w.readframes(n))
    w.close()

    base = statistics.median(raw[i * ch] for i in range(0, min(n, sr), 7))
    blk = max(1, sr // 100)                       # 10 ms
    dev = []
    for b in range(0, n, blk):
        hi = 0
        for i in range(b, min(b + blk, n), 3):
            d = abs(raw[i * ch] - base)
            if d > hi:
                hi = d
        dev.append(hi)
    peak = max(dev) if dev else 0
    if peak == 0:
        sys.exit(f"[wav_trim] {a.wav} is flat — nothing to trim, and nothing to listen to")

    lim = peak * a.thresh
    skip = int(a.after * sr / blk)
    first = next((i for i in range(skip, len(dev)) if dev[i] > lim), None)
    if first is None:
        sys.exit(f"[wav_trim] {a.wav}: no activity above {lim:.0f} after {a.after}s")
    last = max(i for i in range(len(dev)) if dev[i] > lim)

    s0 = max(0, int((first * blk) - a.pad * sr))
    s1 = min(n, int((last + 1) * blk + a.pad * sr))
    kept = raw[s0 * ch:s1 * ch]

    o = wave.open(a.out, "wb")
    o.setnchannels(ch)
    o.setsampwidth(sw)
    o.setframerate(sr)
    o.writeframes(kept.tobytes())
    o.close()

    kpk = max(abs(kept[i * ch] - base) for i in range(0, (s1 - s0), 5)) if s1 > s0 else 0
    print(f"[wav_trim] {pathlib.Path(a.wav).name}: {n/sr:.1f}s -> {(s1-s0)/sr:.1f}s "
          f"({s0/sr:.1f}..{s1/sr:.1f}s), {ch}ch {sr} Hz")
    print(f"[wav_trim]   idle level {base:.0f}; kept peak deviation {kpk} of {peak} -> {a.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
