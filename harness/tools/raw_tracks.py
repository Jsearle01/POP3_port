#!/usr/bin/env python3
"""raw_tracks.py — write a raw asset onto whole tracks of an RS-DOS .dsk, and
reserve those granules in the FAT so DECB never allocates over them.

WHY RAW TRACKS AND NOT A FILE. `disk_read_range` (the HAL's WD1773 primitive,
shared with karateka) reads WHOLE TRACKS via the controller's multiple-record
mode: seek, read 18 sectors, advance. It knows nothing about directories or
granule chains, which is the point — it is 60 lines instead of DECB's DOS, and it
runs after DECB has been left behind. So the asset has to sit somewhere it can be
addressed by track number.

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
import sys

SECTOR = 256
SECS_PER_TRACK = 18
TRACK_BYTES = SECTOR * SECS_PER_TRACK          # 4,608
DIR_TRACK = 17
FAT_OFFSET = (DIR_TRACK * SECS_PER_TRACK + 1) * SECTOR   # track 17, sector 2
GRANULES = 68
GRAN_LAST_FULL = 0xC9                          # bits 6&7 set + 9 sectors used


def granules_for_track(t):
    """The two granule numbers living on track t. Track 17 has none."""
    if t == DIR_TRACK:
        return []
    g = t * 2 if t < DIR_TRACK else 34 + (t - DIR_TRACK - 1) * 2
    return [g, g + 1]


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--dsk', required=True)
    ap.add_argument('--asset', required=True, help='raw payload; padded to whole tracks')
    ap.add_argument('--track', type=int, required=True, help='first track')
    ap.add_argument('--tracks', type=int, required=True, help='whole tracks to occupy')
    ap.add_argument('--reserve', action='store_true',
                    help='mark the granules used in the FAT (recommended)')
    a = ap.parse_args()

    img = bytearray(pathlib.Path(a.dsk).read_bytes())
    data = pathlib.Path(a.asset).read_bytes()
    span = a.tracks * TRACK_BYTES
    if len(data) > span:
        sys.exit(f"{a.asset} is {len(data)} B, more than {a.tracks} tracks ({span} B)")
    if a.track <= DIR_TRACK < a.track + a.tracks:
        sys.exit(f"tracks {a.track}..{a.track + a.tracks - 1} cross the directory "
                 f"track {DIR_TRACK} — that is silent corruption, pick another span")
    end = (a.track + a.tracks) * TRACK_BYTES
    if end > len(img):
        sys.exit(f"tracks {a.track}..{a.track + a.tracks - 1} run past the end of "
                 f"{a.dsk} ({len(img)} B)")

    off = a.track * TRACK_BYTES
    img[off:off + span] = data + bytes(span - len(data))

    reserved = []
    if a.reserve:
        for t in range(a.track, a.track + a.tracks):
            for g in granules_for_track(t):
                if g >= GRANULES:
                    sys.exit(f"granule {g} is past the {GRANULES}-granule FAT")
                img[FAT_OFFSET + g] = GRAN_LAST_FULL
                reserved.append(g)

    pathlib.Path(a.dsk).write_bytes(bytes(img))
    print(f"{a.asset}: {len(data)} B -> {a.dsk} tracks {a.track}..{a.track + a.tracks - 1} "
          f"(offset ${off:06X}, {span} B, {span - len(data)} B pad)")
    if reserved:
        print(f"  FAT: granules {reserved[0]}..{reserved[-1]} marked ${GRAN_LAST_FULL:02X} "
              f"(used, no directory entry — DECB will not allocate over them)")


if __name__ == '__main__':
    main()
