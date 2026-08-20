#!/usr/bin/env python3
"""disk_file_readback_check.py - every DECB file on the image, read back and compared
to the artefact it was built from.

WHY THIS EXISTS (P4.25b). `imgtool put` returned exit code 0 and wrote a directory entry
for ROOM.BIN pointing at granules 18,19 - which are track 9, which `raw_tracks.py` then
overwrote with the packed prolog1 screen. The build printed no warning. Reading the file
back gave 2,102 bytes beginning `78 00 13 48`, not even a DECB segment header.

  *** THE PUT SUCCEEDED. THE FILE WAS DESTROYED AFTERWARDS, BY THE SAME BUILD. ***

So an exit code cannot see this class of fault and neither can the directory listing: the
listing reported a plausible size for a file that no longer existed. The only thing that
can see it is reading the bytes back off the image and comparing them to what went on.

HOW THE COLLISION HAPPENS, because the fix is an ORDER and orders drift back:
  * DECB allocates files from granule 0 upward. Granule g is track g//2 (+1 past the
    track-17 directory).
  * The raw assets live at explicit tracks 9,18,24,25,27,29,30,32 - granules 18 and up.
  * So the file set is safe only while it stays under granule 18, i.e. under about 41 KB.
    It had been, for the whole project, until the scene program grew 55 bytes.
  * `raw_tracks.py --reserve` marks its granules $C9 so the allocator skips them - but
    only for files put AFTER the reservation. build.bat now puts ROOM.BIN there.

This check does not care about any of that reasoning. It compares bytes, so it stays true
if the layout changes again.

Usage:
    disk_file_readback_check.py --dsk build/probe.dmk [--imgtool PATH] \
        NAME.BIN=path/to/artefact.bin  [NAME.BIN=path ...]
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile


def find_imgtool(explicit):
    if explicit:
        return explicit
    env = os.environ.get("IMGTOOL")
    if env:
        return env
    found = shutil.which("imgtool")
    if found:
        return found
    for cand in (r"C:\mame\imgtool.exe", "/c/mame/imgtool.exe"):
        if os.path.exists(cand):
            return cand
    return "imgtool"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dsk", required=True)
    ap.add_argument("--imgtool", default=None)
    ap.add_argument("pairs", nargs="+", metavar="NAME=PATH")
    args = ap.parse_args()

    imgtool = find_imgtool(args.imgtool)
    tmp = tempfile.mkdtemp(prefix="readback_")
    failures = 0

    print("# every DECB file on %s, read back and compared byte for byte." % args.dsk)
    print("# an `imgtool put` that returns 0 is not evidence the file survived the build.")
    print("#")
    print("#   %-14s %8s  %8s  %s" % ("file", "on disk", "artefact", "verdict"))

    for pair in args.pairs:
        if "=" not in pair:
            print("  bad pair %r - expected NAME.BIN=path" % pair)
            failures += 1
            continue
        name, src = pair.split("=", 1)
        if not os.path.exists(src):
            print("  %-16s %8s  %8s  MISSING ARTEFACT %s" % (name, "-", "-", src))
            failures += 1
            continue

        out = os.path.join(tmp, name)
        r = subprocess.run([imgtool, "get", "coco_dmk_rsdos", args.dsk, name, out],
                           capture_output=True, text=True)
        if r.returncode != 0 or not os.path.exists(out):
            print("  %-16s %8s  %8d  GET FAILED (%s)"
                  % (name, "-", os.path.getsize(src), (r.stderr or r.stdout).strip()[:60]))
            failures += 1
            continue

        got = open(out, "rb").read()
        want = open(src, "rb").read()
        if got == want:
            print("  %-16s %8d  %8d  ok" % (name, len(got), len(want)))
            continue

        failures += 1
        first = next((i for i in range(min(len(got), len(want))) if got[i] != want[i]),
                     min(len(got), len(want)))
        print("  %-16s %8d  %8d  *** DIFFERS at byte %d ***"
              % (name, len(got), len(want), first))
        print("      on disk  %s" % got[first:first + 8].hex(" "))
        print("      artefact %s" % want[first:first + 8].hex(" "))
        gran = None
        if len(want):
            gran = (len(want) + 2303) // 2304
        print("      the artefact needs %s granule(s); a file that reaches granule 18 "
              "lands on track 9, the first raw asset span." % gran)

    shutil.rmtree(tmp, ignore_errors=True)
    print("#")
    if failures:
        print("# VERDICT: FAIL - %d file(s) on the image are not what the build produced." % failures)
        return 1
    print("# VERDICT: PASS - every file on the image matches its artefact.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
