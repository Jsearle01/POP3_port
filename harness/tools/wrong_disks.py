#!/usr/bin/env python3
r"""wrong_disks.py — P5.24: the realistic set of disks the side check must NOT accept.

Jay's ruling is "raw signature if it's unique and valid", so the signature is tested against
what a player might actually have in the drive, not against nothing:

  blank_unformatted.dmk   a DMK with NO sector IDs on any track -- a disk that turns but holds
                          no sectors. Hand-built: imgtool cannot make one. It is the case that
                          passes the presence gate (index pulses) and then has nothing to read.
  decb_empty.dmk          a freshly DECB-formatted disk (imgtool create)
  random_decb.dmk         a DECB disk carrying six files of random bytes (seeded, repeatable)
  side_a.dmk              POP's own side A (it carries a DIFFERENT signature)
  karateka_boot.dmk       karateka's DECB boot disk (COPY of its build/fixtures; read-only sibling)
  karateka_game.dmk       karateka's raw game disk (copy)
  pop_probe.dmk           POP's shipped image (copy)

Writes them to build/p524/disks/.
"""
import pathlib
import random
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "build/p524/disks"
IMG = shutil.which("imgtool") or r"C:\mame\imgtool.exe"
KARATEKA = ROOT.parent / "karateka_coco3" / "build/fixtures"


def unformatted_dmk(path, tracks=35, track_len=6400):
    """DMK: 16-byte header (write-protect 0, tracks, track length LE, flags: b4 = single-sided),
    then per track a 128-byte IDAM pointer table -- ALL ZERO, i.e. no sectors -- and the rest of
    the track filled with $4E gap bytes."""
    hdr = bytes([0, tracks]) + track_len.to_bytes(2, "little") + bytes([0x10]) + bytes(11)
    trk = bytes(128) + bytes([0x4E]) * (track_len - 128)
    path.write_bytes(hdr + trk * tracks)


def run(*args):
    subprocess.run([IMG, *args], check=True, capture_output=True)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    unformatted_dmk(OUT / "blank_unformatted.dmk")
    for name in ("decb_empty.dmk", "random_decb.dmk"):
        p = OUT / name
        if p.exists():
            p.unlink()
        run("create", "coco_dmk_rsdos", str(p), "--tracks=35", "--sectors=18", "--sectorlength=256",
            "--interleave=0")
    rng = random.Random(5240)
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="p524rnd_"))
    for i in range(6):
        f = tmp / ("R%d.DAT" % i)
        f.write_bytes(bytes(rng.randrange(256) for _ in range(20000)))
        run("put", "coco_dmk_rsdos", str(OUT / "random_decb.dmk"), str(f), "R%d.DAT" % i, "--ftype=data")
    shutil.copy(ROOT / "build/p522/side_a.dmk", OUT / "side_a.dmk")
    shutil.copy(KARATEKA / "boot_disk.dmk", OUT / "karateka_boot.dmk")
    shutil.copy(KARATEKA / "game.dmk", OUT / "karateka_game.dmk")
    shutil.copy(ROOT / "build/probe.dmk", OUT / "pop_probe.dmk")
    for p in sorted(OUT.glob("*.dmk")):
        print("  %-24s %7d B" % (p.name, p.stat().st_size))


if __name__ == "__main__":
    main()
