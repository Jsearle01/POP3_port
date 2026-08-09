#!/usr/bin/env python3
r"""bundle_offsets_check.py — do the room's bundle offsets match what the bundle LINKED at?

WHY THIS EXISTS, AND WHY A GREEN BUILD WAS NOT ENOUGH. The cutscene bundle is a separate
image: cutscene_room.s is LOADM'd to $2000 and reads the bundle to $3000 at run time, so
it reaches into it by arithmetic — `BLIT_TAB equ FLAME_BASE+40` — while the bundle's own
layout is decided by the linker. Nothing connects the two. They are two files
independently asserting the same fact, with no reference for a linker to resolve.

P3.54 moved the layout: retiring flame_cels.s's third dispatch table shifted everything
after it up by 18, blit_tab +58 -> +40 and chars_tab +64 -> +46. The room was updated and
char_draw.s, which held its own copy, was not. What followed is the part worth recording:
the build SUCCEEDED, the program LOADED, it initialised hardware, set its video mode,
performed two disk reads, reached its main loop, and its animation state machine advanced
one step. Only then did the stale offset call through $303A — cel data by then — and hang.

Every early signal said healthy. So "it links" and "it boots" are not evidence here, and
this is the check that was missing rather than a second opinion about one that exists.

P3.62 removed char_draw.s's copy entirely (it is linked into the bundle and can import the
symbols). One home is left, in cutscene_room.s, because that one is irreducible — a
separate program genuinely must know the number. This compares that home against the map.

Exit 1 on any mismatch, missing symbol or unparseable declaration: a check that cannot
find its inputs must fail, not pass quietly.
"""
import argparse
import pathlib
import re
import sys

# room source symbol -> the symbol it must equal in the flames link map
PAIRS = {"BLIT_TAB": "blit_tab", "CHARS_TAB": "chars_tab"}


def room_offsets(src):
    """{name: absolute address} from the room's `equ FLAME_BASE+n` declarations."""
    txt = pathlib.Path(src).read_text(errors="replace")
    m = re.search(r"^FLAME_BASE\s+equ\s+\$([0-9A-Fa-f]+)", txt, re.M)
    if not m:
        raise SystemExit("  FAIL no FLAME_BASE declaration in %s" % src)
    base = int(m.group(1), 16)
    out = {}
    for name in PAIRS:
        d = re.search(r"^%s\s+equ\s+FLAME_BASE\+(\d+)" % name, txt, re.M)
        if not d:
            raise SystemExit("  FAIL %s is not declared as FLAME_BASE+n in %s"
                             % (name, src))
        out[name] = (base + int(d.group(1)), int(d.group(1)))
    return base, out


def map_symbols(mapfile):
    txt = pathlib.Path(mapfile).read_text(errors="replace")
    return {m.group(1): int(m.group(2), 16)
            for m in re.finditer(r"^Symbol: (\S+) .*= *([0-9A-Fa-f]+)", txt, re.M)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--room", default="src/engine/cutscene_room.s")
    ap.add_argument("--map", default="build/obj/flames.map")
    a = ap.parse_args()

    base, room = room_offsets(a.room)
    syms = map_symbols(a.map)

    bad = 0
    for name, sym in PAIRS.items():
        want_addr, off = room[name]
        got = syms.get(sym)
        if got is None:
            print("  FAIL %s: %s is not in %s" % (name, sym, a.map))
            bad = 1
            continue
        if got != want_addr:
            print("  FAIL %s = FLAME_BASE+%d = $%04X, but %s LINKED at $%04X "
                  "(off by %+d)" % (name, off, want_addr, sym, got, got - want_addr))
            bad = 1
        else:
            print("  ok   %-10s FLAME_BASE+%-3d = $%04X == %s" % (name, off, got, sym))

    if bad:
        print("  the room would call into the middle of the bundle. Fix the `equ`s in %s"
              % a.room)
        return 1
    print("  [bundle-offsets] room offsets agree with the linked bundle (base $%04X)"
          % base)
    return 0


if __name__ == "__main__":
    sys.exit(main())
