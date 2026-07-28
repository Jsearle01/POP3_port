#!/usr/bin/env python3
"""raw_tracks.py — write a raw asset onto whole tracks of an RS-DOS image, and
reserve those granules in the FAT so DECB never allocates over them.

WHY RAW TRACKS AND NOT A FILE. `disk_read_range` (the HAL's WD1773 primitive,
shared with karateka) reads WHOLE TRACKS via the controller's multiple-record
mode: seek, read 18 sectors, advance. It knows nothing about directories or
granule chains, which is the point — it is 60 lines instead of DECB's DOS, and it
runs after DECB has been left behind. So the asset has to sit somewhere it can be
addressed by track number.

--------------------------------------------------------------------------------
DMK, NOT JVC — AND SEQUENTIAL INTERLEAVE (P3.6)
--------------------------------------------------------------------------------
This used to compute byte offsets straight into a JVC `.dsk`, because JVC is a
purely LOGICAL container: `off(T,S) = (T*18 + S-1) * 256`, no physical order at
all. That is exactly why it had to go. MAME synthesises a physical angular order
for JVC, and the one it picks is close to pessimal for a whole-track read — POP
measured **3.31 s/track**, karateka **3.33 s/track**, both about **0.89
revolutions per SECTOR** where a whole track should cost about one.

DMK stores the authored order, and imgtool will author it:

    imgtool create coco_dmk_rsdos <img> --tracks=35 --sectors=18 \
            --sectorlength=256 --interleave=0

**Interleave 0 = SEQUENTIAL, and sequential is the fastest.** That inverts the
usual RS-DOS convention, where sectors are spread so a sector-at-a-time reader
has time to breathe. A HALT-paced `m=1` Read-Multiple reads the whole track under
ONE command and keeps pace inside it, so it wants the next sector to be the next
sector — any spread costs a revolution. karateka swept it and the time rises
monotonically with interleave (il=0: 10.66 s; il=1: 12.27; il=9: 25.07; il=13:
31.46 — worse than JVC).
[karateka_coco3 docs/project/interleave-realization-mame.md]

So sectors are placed with `imgtool writesector` by LOGICAL id, and the physical
placement comes from `--interleave` at create time. The read side is unchanged:
the primitive still asks for ids 1..18.

WHY THIS DOES NOT CORRUPT THE DISK. karateka settled the question against Disk
Basic Unravelled II (`docs/project/decb-loadm-boot-gates.md`, gate G1) and the
answer is narrower than it looks:

  * the FAT is track 17 sector 2; $FF means free; bits 6&7 set means "last
    granule" with the used-sector count in bits 0-5
  * the ALLOCATOR skips any granule that is not $FF and never consults the
    directory
  * FREE reads only the FAT; DIR reads only the directory

So marking a granule used with NO directory entry is fully tolerated: the
allocator will not reuse it, FREE reports the right number, and DIR shows no
phantom file. Each reserved granule is written **$C9** — last-granule, 9 sectors —
so no forward link dangles.

TRACK 17 IS THE DIRECTORY and is mid-disk, not at the end. Granules 0..33 are
tracks 0..16; granules 34..67 are tracks 18..34. A raw span must not cross track
17, which is why the default span sits above it.
"""
import argparse
import pathlib
import subprocess
import sys
import tempfile

SECTOR = 256
SECS_PER_TRACK = 18
TRACK_BYTES = SECTOR * SECS_PER_TRACK          # 4,608
DIR_TRACK = 17
FAT_SECTOR = 2                                 # track 17, sector 2
GRANULES = 68
GRAN_LAST_FULL = 0xC9                          # bits 6&7 set + 9 sectors used
FORMAT = 'coco_dmk_rsdos'


def granules_for_track(t):
    """The two granule numbers living on track t. Track 17 has none."""
    if t == DIR_TRACK:
        return []
    g = t * 2 if t < DIR_TRACK else 34 + (t - DIR_TRACK - 1) * 2
    return [g, g + 1]


class Image:
    """Sector access through imgtool, which is what makes DMK usable here: the
    container's raw track encoding (IDAM/DAM/gap/CRC) stays imgtool's problem."""

    def __init__(self, imgtool, path):
        self.imgtool = imgtool
        self.path = path
        self.tmp = pathlib.Path(tempfile.gettempdir()) / 'raw_tracks_sec.bin'

    def _run(self, *args):
        r = subprocess.run([self.imgtool, *args],
                           stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        if r.returncode != 0:
            sys.exit(f"imgtool {' '.join(args[:2])} failed: "
                     f"{r.stderr.decode(errors='replace').strip()}")

    def read(self, track, sector):
        self._run('readsector', FORMAT, self.path, str(track), '0', str(sector),
                  str(self.tmp))
        return bytearray(self.tmp.read_bytes())

    def write(self, track, sector, data):
        if len(data) != SECTOR:
            sys.exit(f"sector payload must be {SECTOR} bytes, got {len(data)}")
        self.tmp.write_bytes(bytes(data))
        self._run('writesector', FORMAT, self.path, str(track), '0', str(sector),
                  str(self.tmp))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--dsk', required=True, help='the DMK image')
    ap.add_argument('--asset', required=True, help='raw payload; padded to whole tracks')
    ap.add_argument('--track', type=int, required=True, help='first track')
    ap.add_argument('--tracks', type=int, required=True, help='whole tracks to occupy')
    ap.add_argument('--imgtool', default='imgtool')
    ap.add_argument('--reserve', action='store_true',
                    help='mark the granules used in the FAT (recommended)')
    a = ap.parse_args()

    payload = pathlib.Path(a.asset).read_bytes()
    data = payload
    span = a.tracks * TRACK_BYTES
    if len(data) > span:
        sys.exit(f"{a.asset} is {len(data)} B, more than {a.tracks} tracks ({span} B)")
    if a.track <= DIR_TRACK < a.track + a.tracks:
        sys.exit(f"tracks {a.track}..{a.track + a.tracks - 1} cross the directory "
                 f"track {DIR_TRACK} — that is silent corruption, pick another span")
    data = data + bytes(span - len(data))

    img = Image(a.imgtool, a.dsk)
    n = 0
    for t in range(a.track, a.track + a.tracks):
        for s in range(1, SECS_PER_TRACK + 1):
            off = ((t - a.track) * SECS_PER_TRACK + (s - 1)) * SECTOR
            img.write(t, s, data[off:off + SECTOR])
            n += 1

    reserved = []
    if a.reserve:
        fat = img.read(DIR_TRACK, FAT_SECTOR)
        for t in range(a.track, a.track + a.tracks):
            for g in granules_for_track(t):
                if g >= GRANULES:
                    sys.exit(f"granule {g} is past the {GRANULES}-granule FAT")
                fat[g] = GRAN_LAST_FULL
                reserved.append(g)
        img.write(DIR_TRACK, FAT_SECTOR, fat)

    print(f"{a.asset}: {len(payload)} B -> {a.dsk} "
          f"tracks {a.track}..{a.track + a.tracks - 1} "
          f"({n} sectors via writesector, {span - len(payload)} B pad)")
    if reserved:
        print(f"  FAT: granules {reserved[0]}..{reserved[-1]} marked ${GRAN_LAST_FULL:02X} "
              f"(used, no directory entry — DECB will not allocate over them)")


if __name__ == '__main__':
    main()
