#!/usr/bin/env python3
r"""gate_image.py — the shipped track map, re-authored by make_side_dmk.py (P5.22 follow-up).

Jay asked for the visual gate "with the new disk formatting". The PROPOSED P5.22 layout cannot boot
yet -- the loader's track constants (INTRO_TRK, DISK_FLAME_TRK, ...) point at the shipped map and the
cel pages there are uncompressed -- so this gates the new AUTHORING METHOD on the CURRENT map:

  * every raw-reserved track of build/probe.dmk is read (imgtool readsector) and laid back at the
    SAME track by make_side_dmk.py: fresh `create --interleave=0`, `writesector` only, no allocator;
  * the DECB surface is LOADER.BIN alone -- the four harness probes (PROBE, MODE, ANIM, INTRO) and
    TILE.BIN that share the shipped image are not on it;
  * every raw track is compared byte-for-byte against the shipped image before the tool exits 0.

No port byte changes; build/probe.dmk is read, never written.
"""
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import disk_capacity as D                                     # noqa: E402

IMG = shutil.which("imgtool") or r"C:\mame\imgtool.exe"
OUT = ROOT / "build/p522/gate"


def read_track(dsk, t, tmp):
    buf = bytearray()
    for s in range(1, 19):
        subprocess.run([IMG, "readsector", "coco_dmk_rsdos", str(dsk), str(t), "0", str(s), str(tmp)],
                       check=True, capture_output=True)
        buf += tmp.read_bytes()
    return bytes(buf)


def main():
    src = ROOT / "build/probe.dmk"
    OUT.mkdir(parents=True, exist_ok=True)
    cls, _ = D.read_image(src)
    raw_tracks = sorted({D.granule_track(g) for g, c in cls.items() if c == "raw"})
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="p522gate_")) / "s.bin"
    entries = []
    for t in raw_tracks:
        p = OUT / ("t%02d.bin" % t)
        p.write_bytes(read_track(src, t, tmp))
        entries.append(dict(name="t%02d" % t, file=str(p), track=t, lz=False))
    json.dump(entries, open(OUT / "map.json", "w"), indent=1)
    img = OUT / "gate_side_a.dmk"
    r = subprocess.run([sys.executable, str(HERE / "make_side_dmk.py"), "--map", str(OUT / "map.json"),
                        "--out", str(img), "--decb-boot", str(ROOT / "build/loader.bin")],
                       capture_output=True, text=True)
    print(r.stdout.splitlines()[0] if r.stdout else r.stderr)
    if r.returncode:
        print(r.stdout + r.stderr)
        return 1
    bad = [t for t in raw_tracks if read_track(img, t, tmp) != (OUT / ("t%02d.bin" % t)).read_bytes()]
    print("raw tracks carried: %d (%s..%s), byte-identical to probe.dmk: %s"
          % (len(raw_tracks), raw_tracks[0], raw_tracks[-1], "ALL" if not bad else "NOT %s" % bad))
    print("DECB files: LOADER.BIN only")
    print("image: %s" % img)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
