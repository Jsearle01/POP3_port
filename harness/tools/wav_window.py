"""wav_window.py — P4.19: cut an EXACT window out of a MAME session recording.

★★★ WHY NOT wav_trim.py. That tool finds activity against the file's own idle level, which
is right when you want "the part that makes noise" out of one recording. It is WRONG for a
three-way comparison, because each file would be cut at a different place by a different
amount and the listener could not tell a timing difference from a trimming difference.

★★ THE WINDOWS HERE ARE KNOWN, NOT DISCOVERED. `oracle_song_capture.lua` recorded when each
song is CALLED — s_Princess at t=44.867 s after boot — and the decode says it runs 12.724 s.
The port's own passes are located the same way, from the frame the probe was EXEC'd. So each
clip is cut to the same 12.7 s of the same piece and any difference you hear is the machine.

★ It still reports peak and RMS per clip, because a window that produced silence and a
window that worked look identical from the filename — which is the failure this project
keeps meeting.
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--wav", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--start", type=float, required=True, help="seconds")
    ap.add_argument("--dur", type=float, required=True, help="seconds")
    ap.add_argument("--label", default="")
    args = ap.parse_args()

    src = pathlib.Path(args.wav)
    if not src.exists() or src.stat().st_size == 0:
        print("[wav_window] ★ %s is missing or empty — that is a failure, not a quiet "
              "recording." % args.wav)
        raise SystemExit(1)

    w = wave.open(str(src), "rb")
    n, ch, sw, fr = w.getnframes(), w.getnchannels(), w.getsampwidth(), w.getframerate()
    raw = w.readframes(n)
    w.close()
    if sw != 2:
        raise SystemExit("[wav_window] only 16-bit input is handled (got %d bytes)" % sw)

    s = struct.unpack("<%dh" % (n * ch), raw)
    a = int(args.start * fr)
    b = min(n, a + int(args.dur * fr))
    if a >= n:
        print("[wav_window] ★ window starts at %.2f s but the file is only %.2f s"
              % (args.start, n / fr))
        raise SystemExit(1)

    clip = s[a * ch:b * ch]
    mono = [clip[i * ch] for i in range((b - a))]
    base = statistics.median([s[i * ch] for i in range(min(fr, n))])
    peak = max(abs(v - base) for v in mono) if mono else 0
    rms = (sum((v - base) ** 2 for v in mono) / len(mono)) ** 0.5 if mono else 0

    out = wave.open(args.out, "wb")
    out.setnchannels(ch)
    out.setsampwidth(sw)
    out.setframerate(fr)
    out.writeframes(struct.pack("<%dh" % len(clip), *clip))
    out.close()

    tag = args.label or pathlib.Path(args.out).stem
    print("[wav_window] %-22s %5.2f..%5.2f s -> %s"
          % (tag, args.start, args.start + args.dur, args.out))
    print("[wav_window]   idle %d   peak deviation %d   rms %.0f%s"
          % (base, peak, rms, "   ★ SILENT" if peak < 200 else ""))


if __name__ == "__main__":
    main()
