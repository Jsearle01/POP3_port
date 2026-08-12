#!/usr/bin/env python3
r"""cel_link.py — P3.78. Assemble, link, check and place the SPLIT cel image.

build.bat used to do this inline, because the image was one object linked at $C000. It
is now a pinned page plus N rotating ones, N is decided by the packer from the content,
and the link is a TWO-PASS build:

    1. assemble + link every rotating page at $E000, each its own unit
    2. read their link MAPS and write the walk table from the addresses the linker
       actually chose  (cel_table.py — see its header for why this cannot be a label)
    3. assemble + link the pinned page at $C000, table included
    4. flatten each with decb_to_raw and place it on its own whole tracks

A `for %%N in (0 1 2 3 4)` in the batch file would hard-code the page count in a second
place, and the count is exactly the thing the packer is allowed to change when the scene
gains a beat. One home for that fact: content/cutscene/chars/cel_pack.json.

Everything it runs is echoed, so build.bat's output is still the whole story.
"""
import argparse
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path("C:/Projects/POP3_port")
TOOLS = ROOT / "harness/tools"


def run(cmd, quiet=False):
    if not quiet:
        print("  > " + " ".join(str(c) for c in cmd))
    r = subprocess.run([str(c) for c in cmd], capture_output=True, text=True)
    out = (r.stdout or "") + (r.stderr or "")
    for line in out.splitlines():
        print("    " + line)
    return r.returncode


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pack", default="content/cutscene/chars/cel_pack.json")
    ap.add_argument("--dsk", required=True)
    ap.add_argument("--imgtool", required=True)
    a = ap.parse_args()

    pk = pathlib.Path(a.pack)
    if not pk.exists():
        print("*** %s is missing — run harness/tools/bake_scene.py ***" % a.pack)
        return 1
    man = json.loads(pk.read_text(encoding="utf-8"))
    obj = ROOT / "build/obj"
    obj.mkdir(parents=True, exist_ok=True)

    # ── pass 1: the rotating pages ──────────────────────────────────────────────────
    print("--- cel image, pass 1: %d rotating pages at $%04X ---"
          % (len(man["pages"]), man["rot_base"]))
    maps = []
    for pg in man["pages"]:
        i = pg["index"]
        src = "content/cutscene/chars/cel_pg%d.s" % i
        if run(["lwasm", "--obj", "-DOBJTARGET", "-I", ".",
                "-o", "build/obj/cel_pg%d.o" % i, src]):
            return 1
        if run(["lwlink", "--decb", "--script=link/pop_cels_pg.link",
                "--entry=cel_page%d" % i, "--map=build/obj/cel_pg%d.map" % i,
                "-o", "build/cel_pg%d.bin" % i, "build/obj/cel_pg%d.o" % i]):
            return 1
        maps.append("build/obj/cel_pg%d.map" % i)

    # ── pass 2: the table, from the maps ────────────────────────────────────────────
    print("--- cel image, pass 2: the walk table, from the pages' link maps ---")
    if run([sys.executable, TOOLS / "cel_table.py", "--pack", a.pack,
            "--out", "build/obj/cel_walk_tab.s"]
           + sum([["--map", m] for m in maps], [])):
        return 1

    # ── pass 3: the pinned page ─────────────────────────────────────────────────────
    print("--- cel image, pass 3: the pinned page at $%04X ---" % man["res_base"])
    if run(["lwasm", "--obj", "-DOBJTARGET", "-I", ".",
            "-o", "build/obj/cel_res.o", "content/cutscene/chars/cel_res.s"]):
        return 1
    if run(["lwlink", "--decb", "--script=link/pop_cels_res.link",
            "--map=build/obj/cel_res.map", "-o", "build/cel_res.bin",
            "build/obj/cel_res.o"]):
        return 1

    # ★ THE PINNED PAGE HAS ITS OWN CEILING, AND IT IS 8,192 NOT 7,680.
    # $FFA6's block is reachable end to end ($C000-$DFFF); it is $FFA7's that loses its
    # top 512 B. Getting the two the same way round matters: a pinned page checked
    # against 7,680 would reject a legal pack, and one checked against 16,384 would let
    # the table's own cels run into the rotating page's address space.
    from cel_table import read_map                              # noqa: E402
    _syms, load, length = read_map("build/obj/cel_res.map")
    cap = man["rot_base"] - man["res_base"]
    if load != man["res_base"]:
        print("*** the pinned page linked at $%04X, not $%04X ***" % (load, man["res_base"]))
        return 1
    if length > cap:
        print("*** the pinned page is %s B against a %s B block ***"
              % (format(length, ","), format(cap, ",")))
        return 1
    print("  pinned page: linked $%04X length %s B (%s B spare of %s)"
          % (load, format(length, ","), format(cap - length, ","), format(cap, ",")))

    # ── pass 4: flatten and place ───────────────────────────────────────────────────
    print("--- cel image, pass 4: flatten, SKEW, and place on raw tracks ---")
    # ★★ THE SKEW IS APPLIED HERE, and it is the difference between a working page and a
    # machine reset. See cel_pack's read-geometry note in full; the mechanism is:
    #
    #   the unit is padded to CAP (the size of the window it is read into)
    #   track A = padded[0 : 4608]           read to base
    #   track B = padded[CAP-4608 : CAP]     read to base + CAP - 4608
    #
    # so the second read ENDS at the top of the window instead of running 1,536 bytes
    # past it into the constant page and the GIME registers. The tracks overlap by
    # (2*4608 - CAP) bytes and both carry the same bytes there, so either order gives the
    # padded unit back exactly. That identity is ASSERTED below rather than assumed — it
    # is the one property the whole scheme rests on and it is free to check.
    T = man["track_bytes"]
    units = [("res", "build/cel_res.bin", man["res_base"], man["res_cap"],
              man["res_track"])]
    units += [("pg%d" % p["index"], "build/cel_pg%d.bin" % p["index"], p["base"],
               p["cap"], p["track"]) for p in man["pages"]]
    for name, binf, base, cap, trk in units:
        raw = pathlib.Path("build/assets/cel_%s.raw" % name)
        if run([sys.executable, TOOLS / "decb_to_raw.py", "--bin", binf,
                "--out", str(raw), "--base", hex(base)]):
            return 1
        body = raw.read_bytes()
        if len(body) > cap:
            print("*** %s is %d B against a %d B window ***" % (name, len(body), cap))
            return 1
        body = body + b"\x00" * (cap - len(body))
        skewed = body[:T] + body[cap - T:]
        # the reconstruction the machine will perform, checked here
        rebuilt = bytearray(cap)
        rebuilt[0:T] = skewed[:T]
        rebuilt[cap - T:cap] = skewed[T:]
        if bytes(rebuilt) != body:
            print("*** %s: the two skewed tracks do not rebuild the unit ***" % name)
            return 1
        skew_path = pathlib.Path("build/assets/cel_%s_disk.raw" % name)
        skew_path.write_bytes(skewed)
        print("  %-5s %5d B -> padded %d, tracks at +0 and +%d (read to $%04X/$%04X)"
              % (name, len(raw.read_bytes()), cap, cap - T, base, base + cap - T))
        if run([sys.executable, TOOLS / "raw_tracks.py", "--dsk", a.dsk,
                "--asset", str(skew_path), "--track", trk, "--tracks", 2, "--reserve",
                "--imgtool", a.imgtool]):
            return 1
    print("--- cel image: %d units placed, %d tracks ---" % (len(units), 2 * len(units)))
    return 0


if __name__ == "__main__":
    sys.path.insert(0, str(TOOLS))
    sys.exit(main())
