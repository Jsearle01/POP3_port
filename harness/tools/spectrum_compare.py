#!/usr/bin/env python3
"""spectrum_compare.py - the port's audio against the oracle's, as NUMBERS.

★★★ WHY THIS EXISTS. P4.36-P4.38 eliminated every suspect that lives on the bus: the
blitter is 12% of the jitter, interrupts are not masked, the timer is not quantising, held
notes are exact within 8 us, and the rendered pulse duty matches the oracle's to 0.1 us
(21.3 vs 21.2). By every measurable property the port is doing what the oracle does -- and
Jay still hears it as "dirty" and "fuzzy".

That leaves the OUTPUT PATH, which is not on the bus and cannot be settled by a tap:

  * the oracle drives a 1-BIT SPEAKER. A cone is a mechanical low-pass filter, and it
    integrates a ~1.3%-duty pulse train into a tone.
  * the port writes $FC/$00 to a 6-BIT DAC feeding the CoCo's sound mux at line level,
    with far less filtering.

The same pulse train through a less forgiving destination keeps its high harmonics.
msys_player.s:11-13 says the port's train "is what the Apple's speaker actually emits" --
true about the SOURCE and silent about where it lands.

★★ SO THIS COMPARES SPECTRA, and does it as octave-band ENERGY RATIOS rather than as a
picture. CLAUDE.md §3 governs diagnostic images: a plot would have to go to Jay before any
reading of it, and a plot is not what the question needs. Numbers are.

★ WHAT WOULD CONFIRM THE HYPOTHESIS: the port carrying materially more of its energy in the
high bands than the oracle, with comparable energy in the fundamental bands. What would
REFUTE it: similar distributions, in which case the difference is not the output path
either and the next suspect is somewhere this arc has not looked.

Usage:
  spectrum_compare.py --a port.wav --a-start 91 --b oracle.wav --b-start 45 --secs 5
"""
import argparse
import struct
import sys
import wave

import numpy as np

# ★ stdout is cp1252 on this host and a star character crashes the print. Force UTF-8 on
# the stream rather than stripping the marks: a tool that dies AFTER printing its data
# looks like a tool whose data you cannot trust.
sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def read_slice(path, start_s, secs):
    with wave.open(path, "rb") as w:
        ch, width, rate, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        start = int(start_s * rate)
        want = int(secs * rate)
        if start >= n:
            raise SystemExit("%s: start %.1fs is past the end (%.1fs)" % (path, start_s, n / rate))
        want = min(want, n - start)
        w.setpos(start)
        raw = w.readframes(want)
    if width != 2:
        raise SystemExit("%s: expected 16-bit, got %d-bit" % (path, width * 8))
    a = np.frombuffer(raw, dtype="<i2").astype(np.float64)
    if ch > 1:
        a = a.reshape(-1, ch).mean(axis=1)
    return a, rate


def bands(a, rate):
    """Octave-band energy, as a fraction of total. Hann-windowed, DC removed."""
    a = a - a.mean()
    if np.allclose(a, 0):
        return None, 0.0
    win = np.hanning(len(a))
    spec = np.abs(np.fft.rfft(a * win)) ** 2
    freq = np.fft.rfftfreq(len(a), 1.0 / rate)
    edges = [0, 125, 250, 500, 1000, 2000, 4000, 8000, 16000, rate / 2]
    out, tot = [], spec.sum()
    for i in range(len(edges) - 1):
        m = (freq >= edges[i]) & (freq < edges[i + 1])
        out.append((edges[i], edges[i + 1], spec[m].sum() / tot * 100.0))
    return out, float(np.sqrt((a ** 2).mean()))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--a", required=True); ap.add_argument("--a-start", type=float, required=True)
    ap.add_argument("--b", required=True); ap.add_argument("--b-start", type=float, required=True)
    ap.add_argument("--secs", type=float, default=5.0)
    ap.add_argument("--a-name", default="PORT"); ap.add_argument("--b-name", default="ORACLE")
    args = ap.parse_args()

    res = {}
    for tag, path, start in ((args.a_name, args.a, args.a_start),
                             (args.b_name, args.b, args.b_start)):
        a, rate = read_slice(path, start, args.secs)
        b, rms = bands(a, rate)
        if b is None:
            raise SystemExit("%s: the slice is silent -- wrong offset?" % tag)
        res[tag] = (b, rms, rate, len(a))

    print("# octave-band energy, as a percentage of each signal's own total.")
    print("# %.1f s slices. Levels are normalised away on purpose: the question is the"
          % args.secs)
    print("# SHAPE of the spectrum, not how loud each machine was recorded.")
    print("#")
    for tag in (args.a_name, args.b_name):
        b, rms, rate, n = res[tag]
        print("#   %-7s %s  %d Hz, %d samples, rms %.0f" % (tag, "", rate, n, rms))
    print("#")
    print("  %-14s %10s %10s %10s" % ("band", args.a_name, args.b_name, "diff"))
    ha, hb = 0.0, 0.0
    for i, (lo, hi, _pa) in enumerate(res[args.a_name][0]):
        pa = res[args.a_name][0][i][2]
        pb = res[args.b_name][0][i][2]
        star = "  <<<" if abs(pa - pb) >= 5.0 else ""
        print("  %5d..%-7d %9.1f%% %9.1f%% %+9.1f%s" % (lo, hi, pa, pb, pa - pb, star))
        if lo >= 2000:
            ha += pa; hb += pb
    print("#")
    print("  above 2 kHz    %9.1f%% %9.1f%% %+9.1f" % (ha, hb, ha - hb))
    print("#")
    if ha - hb >= 10.0:
        print("# ★ THE PORT CARRIES MATERIALLY MORE HIGH-FREQUENCY ENERGY. That is the")
        print("# signature of the same pulse train landing somewhere less filtered, and it")
        print("# is what 'fuzzy' sounds like. The output path is the lead.")
    elif hb - ha >= 10.0:
        print("# ★ THE ORACLE carries more high-frequency energy than the port, which is the")
        print("# OPPOSITE of the hypothesis. The port is not brighter; look elsewhere.")
    else:
        print("# ★ THE DISTRIBUTIONS ARE COMPARABLE. The output-path hypothesis is NOT")
        print("# supported: the port is not measurably brighter than the oracle, and the")
        print("# difference Jay hears is not gross spectral shape.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
