#!/usr/bin/env python3
r"""harness_offsets_check.py — every hard-coded address and record offset in the HARNESS,
checked against the build that is actually in the tree.

WHY THIS EXISTS. A stale checker does not fail. It PASSES FOR THE WRONG REASON, and every
one this project has found was found by accident while chasing something else:

  P3.65  a checker reading `vwalk48_src.s`, a file the bake no longer produced
  P3.71  a capture path that un-mapped the cel bank on every capture, so the instrument
         caused the failure it was measuring
  P3.80  room_test.lua reading ch_last at the pre-16-bit offsets — recorded character
         boxes at columns -31..-19, which is why "296 bytes disturbed" was blamed on a
         clip that had nothing to do with it, for two dispatches
  P3.82  verify_room_flame_pixels.py skipping every position line on `len(f) != 7` when
         room_test.lua has written 9 fields since P3.71 — dead for eleven dispatches
  P3.83  walk_test.lua counting beats only after first movement (16 of 18 for a scene
         that reaches all 18), and then counting pre-init garbage as beats (19 of 18)

Five instances, five accidents. This is the sweep made mechanical so the sixth is found on
purpose. It checks the things a checker can be stale ABOUT:

  1. RECORD LAYOUTS the harness reads out of engine memory (ch_last's entry, the slot
     record) against the `equ`s in char_draw.s.
  2. The POSITION-FILE FIELD COUNT that writers emit and readers require.
  3. SYMBOLS the runners look up, against the link maps.
  4. Literal addresses in Lua/Python that duplicate a symbol the map already has.

WHAT IT DELIBERATELY DOES NOT DO: guess. Anything it cannot resolve is reported as
UNCHECKED rather than passed, because "I could not find it" reading as "it is fine" is the
exact failure this file is about.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
CHAR = ROOT / "src/engine/char_draw.s"
SMOKE = ROOT / "harness/smoke"
TOOLS = ROOT / "harness/tools"


def engine_equs(path, names):
    """{name: value} for `NAME equ <int>` declarations in an engine source."""
    txt = path.read_text(errors="replace")
    out = {}
    for n in names:
        m = re.search(r"^%s\s+equ\s+(\d+)\s*$" % re.escape(n), txt, re.M)
        if m:
            out[n] = int(m.group(1))
    return out


def lua_locals(path, names):
    """{name: int} for `local NAME, NAME2 = 0, 4` style declarations."""
    txt = path.read_text(errors="replace")
    out = {}
    for n in names:
        m = re.search(r"^local\s+%s\s*=\s*(\d+)" % re.escape(n), txt, re.M)
        if m:
            out[n] = int(m.group(1))
            continue
        # the paired form: local A, B = 0, 4
        for m in re.finditer(r"^local\s+([\w, ]+?)\s*=\s*([\d, ]+)$", txt, re.M):
            keys = [k.strip() for k in m.group(1).split(",")]
            vals = [v.strip() for v in m.group(2).split(",")]
            if n in keys and len(keys) == len(vals):
                out[n] = int(vals[keys.index(n)])
    return out


def main():
    bad = unchecked = 0

    def ok(msg):
        print("  ok   %s" % msg)

    def fail(msg):
        nonlocal bad
        bad += 1
        print("  FAIL %s" % msg)

    def unk(msg):
        nonlocal unchecked
        unchecked += 1
        print("  ??   UNCHECKED: %s" % msg)

    # ── 1. the slot record, as the engine declares it vs as the harness reads it ───────
    eq = engine_equs(CHAR, ["CH_X", "CH_Y", "CH_FACE", "CH_CEL", "CH_H", "CH_AWID"])
    if "CH_CEL" not in eq:
        unk("char_draw.s CH_CEL not parseable")
    else:
        for lua in ("walk_test.lua", "room_test.lua"):
            p = SMOKE / lua
            if not p.exists():
                continue
            got = lua_locals(p, ["CH_X", "CH_CEL"])
            if "CH_CEL" not in got:
                # Not a gap: a reader that takes the cel from ch_drawn (written at DRAW
                # time) rather than from the slot record has no slot offset to go stale.
                # That is the CORRECT source — P3.27 fixed exactly this — so say so
                # instead of leaving a lead for someone to chase.
                if "DRAWN" in p.read_text(errors="replace"):
                    ok("%-14s reads the cel from ch_drawn, not the slot record — nothing "
                       "to be stale about" % lua)
                else:
                    unk("%s declares no CH_CEL and does not use ch_drawn" % lua)
                continue
            if got["CH_CEL"] != eq["CH_CEL"]:
                fail("%s CH_CEL = %d, char_draw.s says %d"
                     % (lua, got["CH_CEL"], eq["CH_CEL"]))
            else:
                ok("%-14s CH_CEL = %d == char_draw.s" % (lua, got["CH_CEL"]))

    # ── 2. ch_last's entry: the engine's stride vs what every reader assumes ───────────
    txt = CHAR.read_text(errors="replace")
    m = re.search(r"ldb\s+#(\d+)\s+;\s*(\d+) B per \(character, slot\)", txt)
    m2 = re.search(r"^ch_last\s+rmb\s+(\d+)", txt, re.M)
    stride = int(m.group(1)) if m else None
    if stride is None:
        m3 = re.search(r"ldb\s+#(\d+)\s*;\s*\d+ B per", txt)
        stride = int(m3.group(1)) if m3 else None
    if stride is None:
        unk("ch_last stride not parseable from char_draw.s")
    else:
        ok("ch_last stride = %d B/entry (engine)" % stride)
        if m2 and int(m2.group(1)) != stride * 4:
            fail("ch_last is rmb %s but 4 entries x %d B = %d"
                 % (m2.group(1), stride, stride * 4))
        else:
            ok("ch_last reserves %d B = 4 x %d" % (stride * 4, stride))
        # the runners derive P_LAST_STRIDE from the map; check they still do
        for sh in ("run_walk_test.sh", "run_room_test.sh"):
            p = SMOKE / sh
            if p.exists() and "P_LAST_STRIDE=$((" in p.read_text(errors="replace"):
                ok("%-18s derives P_LAST_STRIDE from the map" % sh)
            elif p.exists():
                fail("%s does not derive P_LAST_STRIDE — a literal will go stale" % sh)

    # ── 3. the position file: fields written vs fields required ───────────────────────
    writers = {}
    for lua in ("walk_test.lua", "room_test.lua"):
        p = SMOKE / lua
        if not p.exists():
            continue
        t = p.read_text(errors="replace")
        m = re.search(r'f2?:write\(string\.format\("([^"]+)"', t)
        if m:
            writers[lua] = len(re.findall(r"%[-\d.]*[dsx]", m.group(1)))
    for tool in ("verify_room_flame_pixels.py", "verify_room_chars.py",
                 "verify_room_flicker.py"):
        p = TOOLS / tool
        if not p.exists():
            continue
        # CODE ONLY — a `#` comment discussing the old field count is not a live check, and
        # scanning it produced a FAIL for the very fix that closed the real one.
        t = "\n".join(re.sub(r"#.*$", "", ln) for ln in
                      p.read_text(errors="replace").splitlines())
        for m in re.finditer(r"len\(f\)\s*!=\s*(\d+)", t):
            want = int(m.group(1))
            if not writers:
                unk("%s requires %d fields; no writer found to compare" % (tool, want))
                continue
            for lua, n in writers.items():
                if n != want:
                    fail("%s requires len(f) == %d but %s writes %d fields — every line "
                         "is skipped and the exclusion it guards is DEAD"
                         % (tool, want, lua, n))
                else:
                    ok("%-28s field count %d == %s" % (tool, want, lua))

    # ── 4. literal addresses in the harness that duplicate a mapped symbol ────────────
    maps = {}
    for mp in ("build/obj/room.map", "build/obj/flames.map"):
        f = ROOT / mp
        if f.exists():
            for line in f.read_text(errors="replace").splitlines():
                mm = re.match(r"^Symbol: (\S+) .*= *([0-9A-Fa-f]+)$", line)
                if mm:
                    maps.setdefault(int(mm.group(2), 16), mm.group(1))
    if not maps:
        unk("no link maps present — run build.bat first; literal addresses UNCHECKED")
    else:
        hits = 0
        for p in sorted(list(SMOKE.glob("*.lua")) + list(TOOLS.glob("*.lua"))):
            t = p.read_text(errors="replace")
            for mm in re.finditer(r'or\s+"(0x[0-9A-Fa-f]{4})"', t):
                v = int(mm.group(1), 16)
                if v in maps:
                    hits += 1
                    print("  note %s: default %s is %s in the map — a DEFAULT, and the "
                          "runner overrides it; harmless while it does"
                          % (p.name, mm.group(1), maps[v]))
        if hits == 0:
            ok("no harness literal collides with a live symbol")

    print()
    if bad:
        print("  [harness-offsets] %d STALE, %d unchecked" % (bad, unchecked))
        return 1
    print("  [harness-offsets] all checked offsets agree with the build"
          + (" (%d unchecked)" % unchecked if unchecked else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
