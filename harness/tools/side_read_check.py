#!/usr/bin/env python3
r"""side_read_check.py — P5.22: judge side_read.lua's dumps against an INDEPENDENT reading.

Expected bytes come from imgtool's own DMK parser (`readsector`, all 630 sectors), not from the
emulated FDC under test, so agreement means two different readers agree on the image. Every
single-track read is compared byte for byte; then the 1- and 3-track ranges give the per-track
MARGINAL time by subtraction, (t3 - t1) / 2, separated from each call's own Restore + Seek.
"""
import argparse
import pathlib
import shutil
import statistics
import subprocess
import sys
import tempfile

IMG = shutil.which("imgtool") or r"C:\mame\imgtool.exe"
TRACK = 4608


def read_image(dsk):
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="p522rd_")) / "s.bin"
    out = {}
    for t in range(35):
        buf = bytearray()
        for s in range(1, 19):
            subprocess.run([IMG, "readsector", "coco_dmk_rsdos", str(dsk), str(t), "0", str(s), str(tmp)],
                           check=True, capture_output=True)
            buf += tmp.read_bytes()
        out[t] = bytes(buf)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dsk", required=True)
    ap.add_argument("--log", required=True)
    a = ap.parse_args()
    want = read_image(a.dsk)
    reads, done = [], False
    for ln in open(a.log):
        if ln.startswith("R "):
            _, t, n, st, secs, frames, hx = ln.split()
            reads.append((int(t), int(n), int(st), float(secs), int(frames), bytes.fromhex(hx)))
        elif ln.startswith("DONE"):
            done = True
    if not done:
        print("  FAIL the probe did not finish (%d reads logged)" % len(reads))
        return 1
    bad = 0
    singles = {}
    for t, n, st, secs, frames, data in reads:
        exp = b"".join(want[t + k] for k in range(n))
        ok = st == 1 and data == exp
        if not ok:
            bad += 1
            diff = sum(1 for x, y in zip(data, exp) if x != y)
            print("  MISMATCH tracks %d..%d status %d: %d bytes differ" % (t, t + n - 1, st, diff))
        if n == 1 and t not in singles:
            singles[t] = secs
    print("  tracks read singly: %d of 35, byte-exact %d" % (len(singles), len(singles) - min(bad, len(singles))))
    print("  single-track call (Restore to 0 + Seek to t + one m=1 track):")
    print("     track 0: %.3f s   track 17: %.3f s   track 34: %.3f s   median %.3f s"
          % (singles.get(0, 0), singles.get(17, 0), singles.get(34, 0), statistics.median(singles.values())))
    rng = {}
    for t, n, st, secs, frames, data in reads[35:]:
        rng.setdefault(t, {})[n] = secs
    print("  per-track MARGINAL, (t3 - t1) / 2 at three positions:")
    m = []
    for t in sorted(rng):
        if 1 in rng[t] and 3 in rng[t]:
            v = (rng[t][3] - rng[t][1]) / 2
            m.append(v)
            print("     from track %2d: 1 track %.3f s, 3 tracks %.3f s -> %.3f s/track"
                  % (t, rng[t][1], rng[t][3], v))
    if m:
        print("  MEASURED marginal: %.3f s/track (karateka 1.19; POP P3.75b 1.20)" % statistics.mean(m))
    print("  %s" % ("PASS every read byte-exact against imgtool's independent reading" if not bad
                    else "FAIL %d read(s) differ" % bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
