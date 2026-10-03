#!/usr/bin/env python3
r"""disk_capacity.py — P5.22: what a side holds, what is on the shipped one, and what LZ buys per class.

Measures; decides nothing. Three parts:

  A. THE SHIPPED IMAGE, READ BACK. build/probe.dmk's FAT (track 17 sector 2) and directory,
     via imgtool -- every granule classed as a DECB file's, a raw-reserved track's ($C9 with no
     directory owner, raw_tracks.py's mark), or free. So "the image is full" is read off the
     artefact, not off build.bat's comments.

  B. THE PER-SIDE BUDGET, in bytes AND whole tracks (disk_read_range reads whole tracks, so a
     partial track is a rounding loss):
        raw              35 tracks x 18 x 256                        = 161,280 B
        DECB-formatted   track 17 is the directory + FAT, the other 34 tracks are 68 granules
                         of 9 sectors                                = 156,672 B
     karateka's "~153 KB DECB-usable vs 157.5 KB raw" is these two numbers in KiB.

  C. lz_pack.compress per ASSET CLASS -- the shipped codec, verified by decompressing every
     blob -- with the absolute bytes beside every ratio, and each class's input NAMED, because a
     ratio without its base has cost this project twice. Every input is CoCo form (2 bpp, the
     port's representation), never Apple form.
"""
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "sprite_tool"))
import lz_pack as LZ                                          # noqa: E402

TRACK = 4608
GRAN = 2304
IMG = shutil.which("imgtool") or r"C:\mame\imgtool.exe"


CHUNK = 8192    # the unit the port MAPS (one GIME block). lz_pack's offsets are 16-bit, so a
#                 67-93 KB tileset cannot be one stream anyway -- and could not be decoded in place.


def lz(data):
    """Compressed size, in 8 KB-block chunks for anything larger than a block."""
    data = bytes(data)
    total = 0
    for i in range(0, len(data), CHUNK if len(data) > CHUNK else max(len(data), 1)):
        part = data[i:i + CHUNK] if len(data) > CHUNK else data
        c = LZ.compress(part)
        if LZ.decompress(c, len(part)) != part:
            raise SystemExit("lz round-trip failed")
        total += len(c)
        if len(data) <= CHUNK:
            break
    return total


def tracks(n):
    return -(-n // TRACK)


# ------------------------------------------------------------------ A
def read_image(dsk):
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="p522cap_"))
    fat_p = tmp / "fat.bin"
    subprocess.run([IMG, "readsector", "coco_dmk_rsdos", str(dsk), "17", "0", "2", str(fat_p)],
                   check=True, capture_output=True)
    fat = fat_p.read_bytes()[:68]
    dir_ent = []
    for s in range(3, 12):
        p = tmp / ("d%d.bin" % s)
        subprocess.run([IMG, "readsector", "coco_dmk_rsdos", str(dsk), "17", "0", str(s), str(p)],
                       check=True, capture_output=True)
        b = p.read_bytes()
        for i in range(0, 256, 32):
            e = b[i:i + 32]
            if e[0] in (0x00, 0xFF):
                continue
            name = e[0:8].decode("latin-1").rstrip() + "." + e[8:11].decode("latin-1").rstrip()
            dir_ent.append((name, e[13]))
    shutil.rmtree(tmp, ignore_errors=True)
    owner = {}
    for name, g in dir_ent:
        seen = 0
        while g < 68 and seen < 68:
            owner[g] = name
            nxt = fat[g]
            if nxt >= 0xC0:
                break
            g = nxt
            seen += 1
    cls = {}
    for g in range(68):
        if fat[g] == 0xFF:
            cls[g] = "free"
        elif g in owner:
            cls[g] = "file:" + owner[g]
        else:
            cls[g] = "raw"
    return cls, dir_ent


def granule_track(g):
    return g // 2 if g < 34 else g // 2 + 1         # granules 34.. skip track 17


# ------------------------------------------------------------------ C inputs
def fcb_bytes(path):
    out = []
    for line in pathlib.Path(path).read_text().splitlines():
        s = line.split(";")[0].strip()
        if s.lower().startswith("fcb"):
            for t in s[3:].split(","):
                t = t.strip()
                if t:
                    out.append(int(t[1:], 16) if t.startswith("$") else int(t))
    return bytes(out)


def tile_blobs():
    import game_census as GC
    import bake_screen as BS
    per_level, per_set = {}, {0: {}, 1: {}}
    for n in range(15):
        name = GC.SETNAME[GC.BGSET[n]]
        if name is None:
            continue
        uni = {}
        for s in range(1, 25):
            try:
                _, variants, order, _ = BS.bake("LEVEL%d" % n, s, name)
            except SystemExit:
                continue
            if not order:
                continue
            for key in variants:
                uni[key] = bytes(key[0])
        per_level[n] = b"".join(uni[k] for k in sorted(uni, key=repr))
        per_set[GC.BGSET[n]].update(uni)
    sets = {ts: b"".join(d[k] for k in sorted(d, key=repr)) for ts, d in per_set.items()}
    return per_level, sets


def cast_blobs():
    import xform_probe_gen as G
    from celio import Cel
    poses = json.load(open(ROOT / "build/xform/p_peel_poses.json"))
    seg, raw, by_table = bytearray(), bytearray(), {}
    for c in sorted(poses, key=lambda c: c["tag"]):
        cel = Cel(str(ROOT / "build/xform/cels" / ("%s_f0.s" % c["tag"])))
        s = bytes(G.stream(cel, 0))
        r = b"".join(bytes(cel.row_bytes(i)) for i in range(cel.h))
        seg += s
        raw += r
        t = c["tag"].split("_")[1]
        a, b = by_table.get(t, (bytearray(), bytearray()))
        a += s
        b += r
        by_table[t] = (a, b)
    return bytes(seg), bytes(raw), by_table


def main():
    print("=" * 96)
    print("A — THE SHIPPED IMAGE, read back (build/probe.dmk)")
    print("=" * 96)
    cls, dirs = read_image(ROOT / "build/probe.dmk")
    use = {}
    for g, c in cls.items():
        use.setdefault(granule_track(g), []).append(c)
    files = sorted({c for c in cls.values() if c.startswith("file:")})
    for name, _ in dirs:
        n = sum(1 for c in cls.values() if c == "file:" + name)
        print("   DECB file %-12s %2d granule(s)" % (name, n))
    nraw = sum(1 for c in cls.values() if c == "raw")
    nfree = sum(1 for c in cls.values() if c == "free")
    nfile = sum(1 for c in cls.values() if c.startswith("file:"))
    print("   granules: %d DECB-file, %d raw-reserved, %d free, of 68   (+ track 17 = directory)"
          % (nfile, nraw, nfree))
    line = []
    for t in range(35):
        if t == 17:
            line.append("%2d:DIR" % t)
            continue
        k = use.get(t, [])
        tag = ("raw" if all(c == "raw" for c in k) else "free" if all(c == "free" for c in k)
               else "file" if all(c.startswith("file:") for c in k) else "mix")
        line.append("%2d:%s" % (t, tag))
    for i in range(0, 35, 9):
        print("   " + "  ".join(line[i:i + 9]))

    print()
    print("=" * 96)
    print("B — PER-SIDE BUDGET")
    print("=" * 96)
    raw_side = 35 * TRACK
    decb_side = 68 * GRAN
    print("   raw, 35 tracks                      %7d B   %2d tracks   (= 157.5 KiB)" % (raw_side, 35))
    print("   DECB-formatted, track 17 reserved   %7d B   %2d tracks   (= 153.0 KiB) -- the tax is ONE TRACK, %d B"
          % (decb_side, 34, raw_side - decb_side))
    print("   side A as shipped                   %d DECB-file granules = %.1f tracks of files; %d raw tracks; %d free granules"
          % (nfile, nfile / 2, nraw // 2, nfree))

    print()
    print("=" * 96)
    print("C — lz_pack.compress PER ASSET CLASS (CoCo form; every blob round-trip-verified)")
    print("=" * 96)
    rows = []
    blobdir = ROOT / "build/p522"
    blobdir.mkdir(parents=True, exist_ok=True)

    def save(name, data):
        (blobdir / name).write_bytes(bytes(data))

    def row(cls_, what, data):
        c = lz(data)
        rows.append((cls_, what, len(data), c))
        print("   %-14s %-58s %8d -> %7d   %5.2fx  (%2d -> %2d tracks)"
              % (cls_, what, len(data), c, len(data) / c if c else 0, tracks(len(data)), tracks(c)))

    A_ = ROOT / "build/assets"
    row("screen", "intro_screen.raw (dithered full screen, SHIPPED lz)", (A_ / "intro_screen.raw").read_bytes())
    row("screen", "prolog1.raw", (A_ / "prolog1.raw").read_bytes())
    row("screen", "princess_room.raw (4-colour room, SHIPPED lz)",
        (ROOT / "content/cutscene/princess_room.raw").read_bytes())
    row("tile page", "tile_page.raw (LEVEL0 scr 1 baked page, SHIPPED lz)", (A_ / "tile_page.raw").read_bytes())

    per_level, sets = tile_blobs()
    for ts, blob in sets.items():
        row("tile variants", "tileset %02d, deduped variants, one blob (P5.12's unit)" % ts, blob)
        save("tiles_set%02d.bin" % ts, blob)
    naive = b"".join(per_level[n] for n in sorted(per_level))
    row("tile variants", "per-level packs, 10 measured levels, NOT deduped (%d levels)" % len(per_level), naive)
    save("tiles_per_level.bin", naive)
    big = max(per_level, key=lambda n: len(per_level[n]))
    row("tile variants", "LEVEL%d alone (largest level, the per-level load unit)" % big, per_level[big])
    row("tile variants", "LEVEL0 alone", per_level[0])

    seg, raw, by_table = cast_blobs()
    row("cast", "290 gameplay cels, SEGMENT STREAMS (phase 0, facing 0)", seg)
    row("cast", "290 gameplay cels, RAW 2bpp BITMAPS (same cels)", raw)
    save("cast_seg.bin", seg)
    save("cast_raw.bin", raw)
    lv = b"".join((ROOT / "oracle/source/01 POP Source/Levels" / ("LEVEL%d" % n)).read_bytes() for n in range(15))
    row("level data", "15 level blueprints, Apple form, used as-is (not in P5.12's figure)", lv)
    save("levels.bin", lv)
    for t, (s, r) in sorted(by_table.items()):
        row("cast", "  %s segment streams" % t, s)
        row("cast", "  %s raw bitmaps" % t, r)
    for i in range(4):
        row("cast(cutscene)", "cel_pg%d.raw (SHIPPED UNCOMPRESSED, 2 tracks)" % i, (A_ / ("cel_pg%d.raw" % i)).read_bytes())
    row("cast(cutscene)", "cel_res.raw (pinned page, SHIPPED UNCOMPRESSED)", (A_ / "cel_res.raw").read_bytes())

    scen = b"".join(fcb_bytes(p) for p in sorted((ROOT / "build/flames_seg").glob("*.s")))
    scen += b"".join(fcb_bytes(p) for p in sorted((ROOT / "build/glass_seg").glob("*.s")))
    row("scenery", "torch flames x2 sets + hourglass, segment streams (cutscene)", scen)
    row("scenery", "flames.raw = that bundle + its code + char_draw (SHIPPED lz)", (A_ / "flames.raw").read_bytes())

    song = fcb_bytes(ROOT / "build/gen/msys_songs.s")
    row("sound", "msys song page (note stream, gen_msys_tables)", song)
    row("sound", "msys_player.raw = player code + tables + song page", (A_ / "msys_player.raw").read_bytes())

    row("code", "intro_prog.raw (intro sequencer program)", (A_ / "intro_prog.raw").read_bytes())
    row("code", "scene_prog.raw (cutscene program)", (A_ / "scene_prog.raw").read_bytes())

    json.dump([dict(cls=a, what=b, raw=c, lz=d) for a, b, c, d in rows],
              open(ROOT / "build/p522_classes.json", "w"), indent=1)


if __name__ == "__main__":
    main()
