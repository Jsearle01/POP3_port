#!/usr/bin/env python3
r"""bake_scene.py — bake every cel the port's scene draws, at its phase AND its facing.

SUPERSEDES bake_walk.py, which baked the vizier's nine and knew nothing about facing or
about the princess. P3.65 (piece G) needs both:

  * Palert ends `aboutface,chx,9`  [SEQTABLE.S:1565] — the princess TURNS to the door and
    rests there, so her standing cel is drawn MIRRORED for the rest of the scene.
  * Vexit ends `aboutface,chx,16`  [SEQTABLE.S:1550] — the vizier turns and walks OUT on
    the walk cels, mirrored. (Not built yet; the table has the shape for it.)

WHY THE MIRROR IS BAKED AND NOT RUN. The oracle mirrors at draw time: OPACITY bit 7 routes
LAY to MLAY [HIRES.S:655]. blit_cel walks segment runs left to right, so a runtime mirror
would need reverse traversal AND bit-reversal within every byte, against a merge path
already at a 6809 floor of 22 cy/byte. sprite_convert has had `--mirror` since Karateka's
guard-facing work; this is the first POP use of it.

THE COLOUR RULE, WHICH IS THE PART THAT CAN GO WRONG SILENTLY. --mirror reverses the pixel
list and PRESERVES each pixel's already-chosen colour; the chroma was decided at the
PRE-mirror screen columns. So a mirrored cel is only correct at a render column whose
parity matches, and for an even pixel width that is the OPPOSITE parity — which is what
--flip-parity exists for [sprite_convert.py:152-167]. Both are applied here from the cel's
real render column, not guessed.

PHASES AND FACINGS COME FROM THE TRACE, NOT FROM THIS FILE. beat_recost walks the port's
plan the way ANIMCHAR does, stepping both characters per `play N`, so what a cel needs is
derived from where the machine actually puts it.
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path("C:/Projects/POP3_port")
sys.path.insert(0, str(ROOT / "harness/tools"))
import cel_parity_rule as R                                    # noqa: E402
import beat_recost as B                                        # noqa: E402

TABLE = ROOT / "oracle/source/01 POP Source/Images/IMG.CHTAB6.A"
OUT = ROOT / "content/cutscene/chars"
CONVERT = ROOT / "harness/tools/sprite_convert.py"
PREP = ROOT / "harness/tools/cel_blit_prep.py"

# THE SCENE AS THE PORT PLAYS IT — the current scene with Palert restored in front of it.
# `play N` advances BOTH characters, so the princess's opening runs while the vizier still
# stands at the door. The later beats (Vraise/Pback/Vexit/Pslump) are NOT here yet; adding
# them is adding rows to this list.
#
# ★ Palert IS BACK (P3.71), AND THE THING THAT BLOCKED IT IS GONE.
#
#   P3.65 measured it as not fitting and the arithmetic was right at the time: her eight
#   turn cels took the bundle to 17,929 B against a 14,848 B window, over by 3,081, and
#   lz_pack refused it —
#
#       vizier cels 6,906 + princess cels 5,841 + table 880 + torch 1,777 + code 2,525
#
#   — but every one of those cel bytes is now in the $C000 image rather than the bundle.
#   The bundle holds the code, the torch and the scripts; the cels answer to a 16,384 B
#   bank instead of the 14,848 B between FLAME_BASE and the disk parameter block. The
#   diagnosis "the wall is that the port has no per-beat load" was ALSO right and is
#   still true — it is simply no longer binding, because a bank the whole scene fits in
#   does not need staging. Jay's P3.45 question is deferred again, on better terms.
PLAN = [("p", "Palert", 9),
        ("v", "Vwalk", 30),
        ("v", "Vstop", 4),
        ("v", "Vstand", 0)]       # 0 = hold; the script's last entry

STEM = {}                         # (who, cel) -> file stem


def stem_for(who, cel):
    return STEM.setdefault((who, cel), "%s%d" % ("v" if who == "viz" else "p", cel))


def trace_scene():
    labels, toks = B.sequences()
    alt = R.altset2()
    viz = B.Char(197, R.FACE_LEFT, "Vstand", labels)
    pri = B.Char(120, R.FACE_LEFT, "Pstand", labels)
    plays = []
    for w, seq, n in PLAN:
        if w == "v":
            viz.jump(seq, labels)
        if w == "p":
            pri.jump(seq, labels)
        for _ in range(n):
            viz.step(toks, labels, alt)
            pri.step(toks, labels, alt)
        plays.append((w, seq, n))
    return viz, pri


def needed():
    """{(who, cel, facing): (phases, x)} — facing 0 = left/normal, 1 = right/mirrored.

    THE X COMES BACK TOO, AND IT IS NOT COSMETIC (P3.72). --start-col decides the cel's
    COLOUR PARITY: sprite_convert picks each pixel's chroma from the screen column it
    will be rendered at. This baked every cel at the character's STARTING CharX, which is
    silently correct for anyone who has not moved -- and every cel in the scene was such a
    cel until Palert, whose `aboutface,chx,9` [SEQTABLE.S:1565] shifts the princess nine
    units before her standing cel is next drawn.

    Measured: her eight turn cels all bake at the column they are drawn at, and the
    MIRRORED cel 11 alone bakes at start-col 124 while the machine draws it at 142. So
    the x is taken from where the trace actually puts the cel, not from where the
    character began. The phase was already derived this way; only the column was not.
    """
    viz, pri = trace_scene()
    out = {}
    for who, ch in (("viz", viz), ("pri", pri)):
        for cel, ph, x, face in ch.drawn:
            out.setdefault((who, cel, 0 if face == R.FACE_LEFT else 1),
                           [set(), x])[0].add(ph)
    return {k: (tuple(sorted(v[0])), v[1]) for k, v in out.items()}


def convert_src(who, cel, mirror, render_col, quiet=True):
    """Convert the cel; mirrored variants get their own source at their own column."""
    alt = R.altset2()
    fimg, fdx, fdy, fchk, lab = alt[cel]
    stem = stem_for(who, cel) + ("_m" if mirror else "")
    src = OUT / ("%s_src.s" % stem)
    cmd = [sys.executable, str(CONVERT), "--table", str(TABLE),
           "--index", str(fimg & 0x7F), "--out", str(src), "--label", "%s_src" % stem,
           "--start-col", str(render_col)]
    if mirror:
        cmd.append("--mirror")
    if quiet:
        cmd.append("--quiet")
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0 or not src.exists():
        return None, (r.stderr or r.stdout or "")[:80]
    # THE EVEN-WIDTH FLIP, applied from the cel's own measured width rather than assumed.
    if mirror:
        m = re.search(r"fcb\s+(\d+)\s*,\s*(\d+)", src.read_text(errors="replace"))
        if m and (int(m.group(2)) * 4) % 2 == 0:
            r2 = subprocess.run(cmd + ["--flip-parity"], capture_output=True, text=True)
            if r2.returncode != 0:
                return None, "flip-parity pass failed"
    return src, None


def main():
    alt = R.altset2()
    want = needed()
    print("=== baking the scene: %d (cel, facing) combinations ===" % len(want))
    ok = fail = 0
    includes, table = [], {}
    for (who, cel, facing) in sorted(want):
        fimg, fdx, fdy, fchk, lab = alt[cel]
        # THE X THE TRACE PUTS THIS CEL AT, not the character's starting CharX — see
        # needed(). Baking the colour parity at a column the cel is never rendered at is
        # invisible for a character that never moves and wrong for one that does.
        face = R.FACE_LEFT if facing == 0 else 0
        rc = R.draw_x(want[(who, cel, facing)][1], fdx, fchk, face)
        src, err = convert_src(who, cel, facing == 1, rc)
        if src is None:
            print("  %s cel %-3d facing %d: CONVERT FAILED %s" % (who, cel, facing, err))
            fail += 1
            continue
        stem = stem_for(who, cel) + ("_m" if facing else "")
        for ph in want[(who, cel, facing)][0]:
            label = "%s_p%d" % (stem, ph)
            dst = OUT / ("%s.s" % label)
            b = subprocess.run([sys.executable, str(PREP), str(src), "--phase", str(ph),
                                "--label", label, "--out", str(dst)],
                               capture_output=True, text=True)
            good = "replay OK" in (b.stdout or "")
            print("  %-4s cel %-3d %-8s col %-4d phase %d  %s"
                  % (who, cel, "MIRRORED" if facing else "normal", rc, ph,
                     "OK" if good else "REPLAY FAILED"))
            if good:
                ok += 1
                includes.append(label)
                table[(cel, facing, ph)] = label
            else:
                fail += 1
                print("      %s" % (b.stdout or b.stderr or "").strip()[:110])
    print("\n  %d baked, %d failed" % (ok, fail))
    if fail:
        return 1
    emit(includes, table)
    return 0


def emit(includes, table):
    """TWO outputs now (P3.71), because the cels no longer live where the code does.

    cel_image.s   -> its own link unit at $C000, read off disk into a GIME bank. Holds
                     WALK_LO/WALK_N as its first two bytes, then walk_tab, then the cel
                     data. THE IMAGE DESCRIBES ITSELF: char_draw is in a different link
                     unit and cannot resolve a symbol across that boundary, so it reads
                     the bounds out of the image rather than keeping a second copy of
                     them. A duplicated layout constant is exactly what CHAR_TAB was.
    walk_scripts.s -> stays inside the bundle, included by char_draw.s. The scripts are
                     code-adjacent and tiny; only the cel PIXELS had to move.
    """
    lo = min(c for c, _f, _p in table)
    hi = max(c for c, _f, _p in table)
    L = ["* cel_image.s " + chr(0x2014) + " the scene's bake, and the lookup over it.",
         "* GENERATED by harness/tools/bake_scene.py " + chr(0x2014) + " do not hand-edit.",
         "*",
         "* LINKED AT $C000 AND READ OFF DISK INTO A GIME BANK (P3.69/P3.71). It is NOT",
         "* part of the flame bundle any more: the bundle had reached 11,921 B against a",
         "* 14,848 B window with five beats still to add, and the cels are the half of it",
         "* that never executes, so they are the half that can live behind a window",
         "* register. cutscene_room.s maps blocks at $FFA6/$FFA7 and re-applies that map",
         "* after every swap (HAL_gfx_swap writes all four window registers, so the",
         "* mapping cannot survive one " + chr(0x2014) + " P3.68).",
         "*",
         "* THE FIRST TWO BYTES ARE THE BOUNDS, and they are load-bearing: char_draw.s",
         "* reads WALK_LO/WALK_N from $C000/$C001 at run time because it links into a",
         "* different object and cannot see these symbols.",
         "*",
         "* EIGHT SLOTS PER CEL: two facings x four phases (P3.65, piece G). The facing",
         "* half is chosen by co_variant from CH_FACE; -1 is left and NORMAL, 0 is right",
         "* and MIRRORED [FRAMEADV.S:1970]. Cels drawn at one facing leave the other half",
         "* zero, which co_variant treats as 'fall back to the record's own pointer'.",
         "*",
         "* Which phases and facings each cel needs is DERIVED, not written: beat_recost",
         "* walks the port's plan the way ANIMCHAR does. Nothing here may disagree with it.",
         "*"]
    for cel in range(lo, hi + 1):
        got = [(f, p) for (c, f, p) in table if c == cel]
        if got:
            L.append("*   cel %-3d %s" % (cel, ", ".join(
                "%s ph%d" % ("mirrored" if f else "normal", p) for f, p in sorted(got))))
    L += ["",
          "                section prog",
          "* EXPORTED because link/pop_cels.link names it as the entry. lwlink resolves",
          "* `entry` against exported symbols only; a plain label gives",
          "* \"External symbol cel_image not found\" at link time. The image is never",
          "* executed -- the entry exists so the .bin carries a load address decb_to_raw",
          "* can check against build.bat's --base.",
          "                export  cel_image",
          "cel_image",
          "* --- the self-describing header, and it must stay FIRST -----------",
          "                fcb     %d              ; WALK_LO, read from $C000" % lo,
          "                fcb     %d              ; WALK_N,  read from $C001" % (hi - lo + 1),
          "* --- walk_tab at $C002: eight slots per cel, two facings x four phases ---",
          "cel_walk_tab"]
    for cel in range(lo, hi + 1):
        row = []
        for f in (0, 1):
            for p in range(4):
                row.append(table.get((cel, f, p), "0"))
        L.append("                fdb     " + ",".join(row) + "   ; cel %d" % cel)
    L.append("")
    for lab in includes:
        L.append('                include "content/cutscene/chars/%s.s"' % lab)
    L.append("")
    pathlib.Path(OUT / "cel_image.s").write_text("\n".join(L) + "\n", encoding="utf-8")

    # THE SCRIPTS STAY IN THE BUNDLE. They are two dozen bytes of sequence cursor that
    # char_draw dereferences directly; moving them behind a window register would buy
    # nothing and would put a second thing behind the map.
    S = ["* walk_scripts.s " + chr(0x2014) + " the scene's scripts. The CELS are in cel_image.s.",
         "* GENERATED by harness/tools/bake_scene.py " + chr(0x2014) + " do not hand-edit."]
    S += scripts()
    pathlib.Path(OUT / "walk_scripts.s").write_text("\n".join(S) + "\n", encoding="utf-8")
    print("  cel_image.s: cels %d..%d, %d slots, %d cel includes"
          % (lo, hi, (hi - lo + 1) * 8, len(includes)))
    print("  walk_scripts.s: the two scene scripts")


# The two scene scripts, DERIVED FROM THE SAME PLAN as the phases, because they are the
# same fact: which sequence runs for how many steps is what decides the positions, and the
# positions are what decide the phases. Written by hand in one place and derived in the
# other, they would drift, and the symptom would be a cel drawn at a phase nobody baked.
LABEL = {"Vstand": "viz_stand", "Vwalk": "viz_walk", "Vstop": "viz_stop",
         "Pstand": "pri_stand", "Palert": "pri_alert"}


def scripts():
    out = {"v": [["Vstand", 0]], "p": [["Pstand", 0]]}
    for w, seq, n in PLAN:
        for who in ("v", "p"):
            if w == who:
                out[who].append([seq, 0])
            out[who][-1][1] += n
    L = ["",
         "* THE SCENE SCRIPTS: (sequence, plays), derived from bake_scene.PLAN.",
         "* A count of 0 means the sequence holds and the script is finished.",
         "* `play N` advances BOTH characters [SUBS.S:876], so the vizier's leading Vstand",
         "* is exactly as long as the princess's opening — he waits at the door while she",
         "* hears it."]
    for who, name in (("v", "viz_script"), ("p", "pri_script")):
        rows = [r for r in out[who] if r[1] > 0]
        L.append(name)
        for seq, n in rows[:-1]:
            L.append("                fdb     %s" % LABEL[seq])
            L.append("                fcb     %d" % n)
        L.append("                fdb     %s" % LABEL[rows[-1][0]])
        L.append("                fcb     0               ; hold")
    return L


if __name__ == "__main__":
    sys.exit(main())
