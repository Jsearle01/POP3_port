#!/usr/bin/env python3
r"""side_maps.py — P5.22: the PROPOSED track maps for the two sides, as make_side_dmk.py input.

A PROPOSAL against measured sizes, not a layout the port reads: the bake does not exist (C), so
side B carries the measured classes P5.22 could build (tilesets 00/01, the gameplay cast, the
fifteen blueprints) and NAMES the rest as reservations sized from estimates. Side A re-lays what
the shipped image carries today. Neither replaces build/probe.dmk.

Writes build/p522/side_a.json, side_b.json (make_side_dmk.py maps), side_b_dir.bin, and prints the
table the report carries.
"""
import json
import pathlib
import struct
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import make_side_dmk as M                                     # noqa: E402

TRACK = 4608
OUT = ROOT / "build/p522"


def tracks_for(path, lz):
    raw = pathlib.Path(path).read_bytes()
    data = M.lz_chunks(raw) if lz else raw
    return -(-len(data) // TRACK), len(raw), len(data)


def main():
    A = ROOT / "build/assets"
    # ---------------- side B: raw, no DECB surface ----------------
    real = [("tiles_set00", OUT / "tiles_set00.bin", True),
            ("tiles_set01", OUT / "tiles_set01.bin", True),
            ("levels", OUT / "levels.bin", True),
            ("cast", OUT / "cast_seg.bin", True)]
    # ESTIMATES, reserved by name and NOT authored (no bytes exist to lay):
    #   tileset 02 -- P5.12 §3C: ~80,022 B expanded, at the mean measured LZ ratio of sets 00/01
    #   the cast's other four guard sets -- P5.12 §3E: whole-game cast 95,086 vs this census's
    #     63,550 B footprint; scaled by the measured segment/footprint and LZ ratios
    #   scenery -- P5.12 flag 3: LEVEL0 alone is 6,879 B; fifteen levels, unmeasured
    #   music -- the oracle's eleven songs; one song page is 1,024 B and LZ's 1.19x
    m00 = (67345, 8600 + 6 * 9)
    m01 = (93333, 15988 + 6 * 12)
    ratio = (m00[0] + m01[0]) / (m00[1] + m01[1])
    est = [("tiles_set02 (EST)", 80022 / ratio),
           ("cast, guards FAT/SHAD/SKEL/VIZ (EST)", (95086 - 63550) * 91906 / 63550 / (91906 / 41426)),
           # PER TILESET, not per level: P5.7 §3E measured animated scenery as one storable cel
           # set PER KIND ("6,105 B is the storable figure, not 24,420"), and a kind's art comes
           # from its tileset's own tables -- so, like the tiles, it repeats across a set's levels.
           # The first cut of this line scaled by fifteen levels and claimed 8 tracks.
           ("scenery x3 tilesets (EST)", 3 * 6879 / 2.96),
           ("music, 11 songs (EST)", 11 * 1024 / 1.19)]
    entries, t = [], 1
    rows = [("side B", 0, 1, "side directory + signature", "authored")]
    order = [real[0], real[1], ("tiles_set02 (EST)",), real[2], real[3]]
    for item in order:
        if len(item) == 1:
            n = -(-int(dict(est)[item[0]]) // TRACK)
            rows.append(("side B", t, n, item[0], "reserved"))
            t += n
            continue
        name, path, lz = item
        n, raw, packed = tracks_for(path, lz)
        if name == "cast" and t > 17:
            pass
        entries.append(dict(name=name, file=str(path), track=t, lz=lz))
        rows.append(("side B", t, n, "%s (%d -> %d B)" % (name, raw, packed), "authored"))
        t += n
    for name, b in est[1:]:
        n = -(-int(b) // TRACK)
        rows.append(("side B", t, n, name, "reserved"))
        t += n
    # the directory: signature + one (track, tracks) pair per AUTHORED entry
    # P5.24: the 16-byte signature + format version that make_side_dmk.py --sig-text writes on
    # side A (there at T17 S18) -- here it heads side B's directory sector, T0 S1.
    d = bytearray(b"POP COCO3 SIDE B" + bytes([1]))
    for e in entries:
        n, _, _ = tracks_for(e["file"], e["lz"])
        d += struct.pack(">BB", e["track"], n) + e["name"].encode()[:14].ljust(14, b"\0")
    (OUT / "side_b_dir.bin").write_bytes(bytes(d))
    entries.insert(0, dict(name="side_dir", file=str(OUT / "side_b_dir.bin"), track=0, lz=False))
    json.dump(entries, open(OUT / "side_b.json", "w"), indent=1)
    side_b_used = t

    # ---------------- side A: DECB boot (LOADER.BIN), the shipped content re-laid ----------------
    a_items = [("intro_prog", A / "intro_prog.raw", False), ("intro_bundle", A / "intro_bundle.raw", False),
               ("intro_screen", A / "intro_screen.lz", False), ("prolog1", A / "prolog1.lz", False),
               ("prolog2", A / "prolog2.lz", False), ("princess_room", A / "princess_room.lz", False),
               ("flames", A / "flames.lz", False), ("msys_player", A / "msys_player.raw", False),
               ("scene_prog", A / "scene_prog.raw", False), ("cel_res", A / "cel_res.raw", True),
               ("cel_pg0", A / "cel_pg0.raw", True), ("cel_pg1", A / "cel_pg1.raw", True),
               ("cel_pg2", A / "cel_pg2.raw", True), ("cel_pg3", A / "cel_pg3.raw", True),
               ("tile_page", A / "tile_page.lz", False)]
    a_entries, a_rows, t = [], [("side A", 0, 1, "LOADER.BIN (DECB, granule 0) -- the boot surface", "authored")], 1
    for name, path, lz in a_items:
        if t == 17:
            a_rows.append(("side A", 17, 1, "DECB directory + FAT", "format"))
            t = 18
        n, raw, packed = tracks_for(path, lz)
        if t < 17 <= t + n - 1:
            a_rows.append(("side A", 17, 1, "DECB directory + FAT", "format"))
            t = 18
        a_entries.append(dict(name=name, file=str(path), track=t, lz=lz))
        a_rows.append(("side A", t, n, "%s (%d%s B)" % (name, raw, (" -> %d" % packed) if lz else ""), "authored"))
        t += n
    json.dump(a_entries, open(OUT / "side_a.json", "w"), indent=1)
    side_a_used = t + (0 if t > 17 else 1)

    print("%-7s %5s %6s  %-62s %s" % ("side", "track", "tracks", "content", ""))
    for r in rows + a_rows:
        print("%-7s %5s %6d  %-62s %s" % (r[0], ("%d" % r[1]) if r[2] == 1 else "%d-%d" % (r[1], r[1] + r[2] - 1),
                                        r[2], r[3], r[4]))
    print()
    print("side B: %d of 35 tracks claimed (incl. reservations), %d free" % (side_b_used, 35 - side_b_used))
    print("side A: tracks 0..%d claimed (track 17 = directory), %d of 35 free" % (t - 1, 35 - t))


if __name__ == "__main__":
    main()
