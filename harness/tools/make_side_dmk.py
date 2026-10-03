#!/usr/bin/env python3
r"""make_side_dmk.py — P5.22: author one disk SIDE from an explicit track map.

TOOLING ONLY. build.bat's shipped build/probe.dmk path is not touched by this file and does not
call it.

MODELLED ON karateka's tools/make_game_dmk.sh and tools/make_decb_boot_disk.sh (read-only
sibling, CLAUDE.md §2G), and on POP's own raw_tracks.py, which already writes bulk this way:

  * `imgtool create coco_dmk_rsdos --tracks=35 --sectors=18 --sectorlength=256 --interleave=0`
    -- DMK, SEQUENTIAL: the layout disk_read_range's m=1 whole-track read is fastest on (P3.6,
    karateka interleave-realization-mame.md).
  * payload by `imgtool writesector` at an explicit (track, logical sector) -- the TRACK MAP IS
    THE AUTHORING INPUT. Nothing is left to the DECB allocator.

TWO KINDS OF SIDE, because POP has two and they need not be answered the same way (P5.22 §4.2):

  --decb-boot FILE   a DECB side: FILE is `put` (lands on granule 0, track 0, as karateka's
                     BOOT.BIN does), every raw span is FAT-RESERVED $C9, and TRACK 17 STAYS THE
                     DIRECTORY -- a span may not cross it. 34 tracks of capacity.
  (default)          a RAW side: no DECB surface at all. Nothing on it is found by a directory;
                     the port's own driver reads it by track. Track 17 carries payload like any
                     other. 35 tracks.

★★ TWO HAZARDS THIS TOOL EXISTS TO KEEP AWAY FROM (karateka, measured; P5.22 §3):
  1. NEVER FORMAT THESE TRACKS WITH DECB `DSKINI`. DECB's sequential format (skip 0) writes
     inter-sector gaps too tight for the m=1 whole-track read -> LOST DATA, unreadable. DSKINI's
     default (skip 4) reads clean but ~2.5x slower. The imgtool-authored DMK gaps are what make
     the 1:1 layout read clean. (MAME models a WD1773; it is not one -- real-hardware
     confirmation of the gap margin is still owed.)
  2. THERE IS NO STOCK-TOOL FAST-COPY PATH. DECB BACKUP to a default-formatted disk is correct
     but slow; `DSKINI drive,0` + BACKUP produces an UNREADABLE disk (refuted on karateka).
     Distribution is an image copy or a flux write.

MAP FORMAT (JSON): a list of entries
    {"name": str, "file": path, "track": int, "lz": bool (default false)}
An "lz" entry is stored as consecutive self-delimiting chunks of <= 8,192 B unpacked, each in
lz_pack's shipped blob format -- $00 unpacked length, $02 packed length, $04 stream offset (=6)
-- so a loader can walk them, and src/engine/lz_unpack.s expands each one as-is.

Every sector written is READ BACK with imgtool and compared before the tool exits 0; the
written payload of each entry is saved beside the image (<out>.payload/<name>.bin) so a
reader of the disk can be checked against exactly what was laid.
"""
import argparse
import json
import pathlib
import shutil
import struct
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import lz_pack as LZ                                          # noqa: E402

SECTOR, SPT, NTRACK, DIR_TRACK, TRACK = 256, 18, 35, 17, 4608
CHUNK = 8192
FMT = "coco_dmk_rsdos"


class Img:
    def __init__(self, path, imgtool):
        self.path, self.imgtool = str(path), imgtool

    def run(self, *args):
        r = subprocess.run([self.imgtool, *args], capture_output=True, text=True)
        if r.returncode:
            raise SystemExit("imgtool %s failed: %s" % (args[0], (r.stderr or r.stdout)[:200]))
        return r.stdout

    def write(self, t, s, data, tmp):
        tmp.write_bytes(data)
        self.run("writesector", FMT, self.path, str(t), "0", str(s), str(tmp))

    def read(self, t, s, tmp):
        self.run("readsector", FMT, self.path, str(t), "0", str(s), str(tmp))
        return tmp.read_bytes()


def lz_chunks(raw):
    out = bytearray()
    for i in range(0, len(raw), CHUNK):
        part = raw[i:i + CHUNK]
        c = LZ.compress(part)
        if LZ.decompress(c, len(part)) != part:
            raise SystemExit("lz round-trip failed")
        out += struct.pack(">HHH", len(part), len(c), 6) + c
    return bytes(out)


def main():
    ap = argparse.ArgumentParser(description="author one disk side from an explicit track map")
    ap.add_argument("--map", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--decb-boot", default=None, help="a DECB binary to `put` (makes a DECB side)")
    ap.add_argument("--imgtool", default=shutil.which("imgtool") or r"C:\mame\imgtool.exe")
    a = ap.parse_args()

    out = pathlib.Path(a.out)
    entries = json.load(open(a.map))
    decb = a.decb_boot is not None
    usable = [t for t in range(NTRACK) if not (decb and t == DIR_TRACK)]

    # ---- lay out and CHECK the map before writing anything ----
    owner, laid = {}, []
    for e in entries:
        raw = pathlib.Path(e["file"]).read_bytes()
        data = lz_chunks(raw) if e.get("lz") else raw
        n = -(-len(data) // TRACK)
        span = list(range(e["track"], e["track"] + n))
        for t in span:
            if t >= NTRACK:
                raise SystemExit("%s: runs off the disk at track %d" % (e["name"], t))
            if decb and t == DIR_TRACK:
                raise SystemExit("%s: tracks %d..%d cross the DECB directory (track 17)"
                                 % (e["name"], span[0], span[-1]))
            if t in owner:
                raise SystemExit("%s: track %d already holds %s" % (e["name"], t, owner[t]))
            owner[t] = e["name"]
        laid.append((e, raw, data, span))

    out.parent.mkdir(parents=True, exist_ok=True)
    if out.exists():
        out.unlink()
    img = Img(out, a.imgtool)
    img.run("create", FMT, str(out), "--tracks=35", "--sectors=18", "--sectorlength=256", "--interleave=0")
    if decb:
        # the put lands on granule 0 (karateka's BOOT.BIN does the same); a raw span on that
        # track is caught when its granules are reserved below
        img.run("put", FMT, str(out), a.decb_boot, pathlib.Path(a.decb_boot).stem.upper()[:8] + ".BIN",
                "--ftype=binary", "--ascii=binary")

    tmp = pathlib.Path(tempfile.mkdtemp(prefix="p522side_")) / "s.bin"
    pay = out.with_suffix(out.suffix + ".payload")
    pay.mkdir(exist_ok=True)
    for e, raw, data, span in laid:
        buf = data + bytes(len(span) * TRACK - len(data))
        for k, t in enumerate(span):
            for s in range(1, SPT + 1):
                o = (k * SPT + (s - 1)) * SECTOR
                img.write(t, s, buf[o:o + SECTOR], tmp)
        (pay / (e["name"] + ".bin")).write_bytes(buf)

    if decb:
        # FAT-reserve every raw track's granules ($C9: last granule, 9 sectors -- karateka G1)
        fat = bytearray(img.read(DIR_TRACK, 2, tmp))
        for t in owner:
            for g in ((t * 2, t * 2 + 1) if t < DIR_TRACK else ((t - 1) * 2, (t - 1) * 2 + 1)):
                if fat[g] != 0xFF:
                    raise SystemExit("track %d (granule %d) is already allocated -- the boot file "
                                     "landed there" % (t, g))
                fat[g] = 0xC9
        img.write(DIR_TRACK, 2, bytes(fat), tmp)

    # ---- READ BACK every written sector ----
    bad = 0
    for e, raw, data, span in laid:
        buf = (pay / (e["name"] + ".bin")).read_bytes()
        for k, t in enumerate(span):
            for s in range(1, SPT + 1):
                o = (k * SPT + (s - 1)) * SECTOR
                if img.read(t, s, tmp) != buf[o:o + SECTOR]:
                    bad += 1
    print("%s side: %s" % ("DECB" if decb else "RAW", out))
    print("  %-22s %6s %6s %7s %7s" % ("entry", "track", "tracks", "source", "on disk"))
    for e, raw, data, span in laid:
        print("  %-22s %6d %6d %7d %7d%s" % (e["name"], span[0], len(span), len(raw), len(data),
                                            "  (lz, 8 KB chunks)" if e.get("lz") else ""))
    used = len(owner)
    print("  tracks used %d of %d usable (%s); free %d" % (used, len(usable),
          "track 17 = directory" if decb else "no DECB surface", len(usable) - used))
    if decb:
        print(img.run("dir", FMT, str(out)).strip())
    print("  readback: %s" % ("every written sector matches" if not bad else "%d SECTORS DIFFER" % bad))
    json.dump({"decb": decb, "entries": [dict(name=e["name"], track=span[0], tracks=len(span),
                                               bytes=len(data)) for e, raw, data, span in laid]},
              open(str(out) + ".map.json", "w"), indent=1)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
