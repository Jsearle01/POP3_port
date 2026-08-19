"""wav_gain.py — P4.19: bring a set of clips to a common listening level, without clipping.

★★★ THE PROBLEM THIS SOLVES IS AUDIBILITY, NOT FIDELITY. Jay, comparing the three-way:
"anyway to raise the volume of the oracle, its hard to hear cleanly." The Apple's one-bit
speaker peaks at 3,901 through most of s_Princess where the CoCo3's 6-bit DAC peaks at
16,125 — 4x, about 12 dB — so an A/B means riding the volume control between clips, which
is exactly the kind of friction that makes an ear gate not get answered.

★★ A SINGLE SCALAR GAIN CHANGES NOTHING THIS GATE IS ABOUT. Pitch, tempo, timbre and the
envelope WITHIN a clip are all preserved; only the absolute level moves. And the
between-machine level was never comparable anyway — a one-bit speaker against a 6-bit DAC
has no common electrical scale. What must NOT happen is CLIPPING, because clipping a pulse
train changes its harmonic content, which IS what is being judged.

★★★ SO THE LEVEL IS SET BY THE QUIETEST-HEADROOM CLIP, NOT BY A FIXED TARGET. Each clip's
"typical" level is the median of its per-second peaks; its ceiling is the loudest single
sample. The common typical level is the highest one that leaves EVERY clip inside the
headroom. The oracle has one loud second (8,647 against a 3,901 typical) and that second is
what caps the set.

★ DC IS REMOVED FIRST. The CoCo3 clips idle at -8192 out of +/-32768 — a quarter of the
headroom spent on an offset, and an audible thump at the cut. The Apple idles at ~0.

Prints the gain applied to each file. A tool that silently changed a level would make two
clips incomparable in a way no one could see.
"""
import argparse
import pathlib
import statistics
import struct
import sys
import wave

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

FULL = 32767


def load(path):
    w = wave.open(str(path), "rb")
    n, ch, sw, fr = w.getnframes(), w.getnchannels(), w.getsampwidth(), w.getframerate()
    raw = w.readframes(n)
    w.close()
    if sw != 2:
        raise SystemExit("[wav_gain] only 16-bit input is handled")
    s = struct.unpack("<%dh" % (n * ch), raw)
    return s, n, ch, sw, fr


def measure(s, n, ch, fr):
    mono = [s[i * ch] for i in range(n)]
    dc = statistics.median(mono)
    peaks = []
    for sec in range(max(1, n // fr)):
        seg = mono[sec * fr:(sec + 1) * fr]
        if seg:
            peaks.append(max(abs(v - dc) for v in seg))
    typical = statistics.median(peaks) if peaks else 0
    ceiling = max((abs(v - dc) for v in mono), default=0)
    return dc, typical, ceiling


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--wav", action="append", required=True,
                    help="repeatable; all files are brought to ONE level")
    ap.add_argument("--suffix", default="_lvl")
    ap.add_argument("--headroom", type=float, default=0.95,
                    help="the loudest sample any clip may reach, as a fraction of full "
                         "scale. Below 1.0 because clipping a pulse train changes its "
                         "timbre, which is the thing under gate.")
    ap.add_argument("--max-gain", type=float, default=12.0)
    args = ap.parse_args()

    clips = []
    for p in args.wav:
        path = pathlib.Path(p)
        if not path.exists() or path.stat().st_size == 0:
            print("[wav_gain] ★ %s is missing or empty" % p)
            raise SystemExit(1)
        s, n, ch, sw, fr = load(path)
        dc, typ, ceil = measure(s, n, ch, fr)
        if typ <= 0 or ceil <= 0:
            print("[wav_gain] ★ %s is silent — refusing to amplify nothing" % p)
            raise SystemExit(1)
        clips.append((path, s, n, ch, sw, fr, dc, typ, ceil))

    # ★ the common level: the highest typical every clip can reach inside the headroom
    limit = FULL * args.headroom
    target = min(min(t * (limit / c), t * args.max_gain)
                 for _, _, _, _, _, _, _, t, c in clips)

    print("[wav_gain] common typical level %.0f  (headroom %.0f%% of full scale)"
          % (target, args.headroom * 100))
    for path, s, n, ch, sw, fr, dc, typ, ceil in clips:
        g = target / typ
        out = path.with_name(path.stem + args.suffix + path.suffix)
        scaled = []
        clipped = 0
        for v in s:
            x = int(round((v - dc) * g))
            if x > FULL:
                x, clipped = FULL, clipped + 1
            elif x < -FULL - 1:
                x, clipped = -FULL - 1, clipped + 1
            scaled.append(x)
        w = wave.open(str(out), "wb")
        w.setnchannels(ch)
        w.setsampwidth(sw)
        w.setframerate(fr)
        w.writeframes(struct.pack("<%dh" % len(scaled), *scaled))
        w.close()
        print("[wav_gain]   %-16s gain x%5.2f  (%+5.1f dB)  dc %+6d removed  "
              "typical %5.0f -> %5.0f  peak %5.0f -> %5.0f%s"
              % (path.name, g, 20 * __import__("math").log10(g), -dc,
                 typ, typ * g, ceil, ceil * g,
                 "   ★ %d SAMPLES CLIPPED" % clipped if clipped else ""))


if __name__ == "__main__":
    main()
