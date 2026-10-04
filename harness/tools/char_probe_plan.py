#!/usr/bin/env python3
r"""char_probe_plan.py — P5.28: the character probe's draw list, and its PREDICTED framebuffer.

Reads content/chars/probe_place.json (the one home for placement, CLAUDE.md §2F) and emits:

  --asm   the 6809 draw list the probe links: per draw, the baked stream, the address of its
          apple_w byte IN THE REGISTRY (content/chars/char_cels.s -- read there at run time,
          never re-derived), yco, col, phase, facing. The 6809 does the placement arithmetic
          itself (char_probe.s), so the prediction below checks that arithmetic too.
  --ref   the framebuffer the probe MUST produce, composed offline before it runs: the tile
          bake's own reference (tile_screen1_ref.bin, which the tile suite already holds the
          port to, 15,360/15,360) with each draw's REFERENCE stream replayed on top by
          cel_blit_prep.simulate -- the independent 6809-semantics replay.

THE REFERENCE, per draw, is P5.20's (xform_probe_gen.cel_cases), so the prediction asks the
port exactly the question the probe answered byte-exact on 6,688 cases -- now over a real
background at a real position:
  facing 0, phase k : the BAKED pixel file (content/chars/<tab>/<tab>_<nnn>_src.s), cel_blit_prep
                      phase k, at byte column `col`
  facing 1, phase k : sprite_convert --mirror (+ --flip-parity iff 7*apple_w is even), cel_blit_prep
                      phase k, at byte column `col`
Rows: the cel's bottom row is yco = char_y + fdy, so its top is yco - h + 1.

★ CLEARANCE IS CHECKED, NOT ASSERTED. Every draw's frame (the reference's AND the routine's,
which sits d px left for a mirror and one byte wider at a non-zero phase) must be on screen
and must not touch a FOREGROUND rectangle (fore_plane.py) or the gate bars bg_compose omits
(drawfrnt with PRECED=gate, block column 0 of row 0). Plane ordering stays untested: this
proves only that the placement does not depend on it.
"""
import argparse
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "sprite_tool"))
import sprite_convert as SC                                 # noqa: E402
import cel_blit_prep as P                                   # noqa: E402
import bake_chars as B                                      # noqa: E402
import fore_plane as FP                                     # noqa: E402
import bg_compose as BC                                     # noqa: E402
from celio import Cel                                       # noqa: E402

STRIDE = 80
PLACE = ROOT / "content/chars/probe_place.json"
TILE_REF = ROOT / "build/assets/tile_screen1_ref.bin"
WORK = ROOT / "build/charp"


def oracle_pl(d):
    """The draw's colour phase facing LEFT, from FRAMEDEF.S through cel_parity_rule -- the
    ORACLE's Fcheck, not content/chars/frame_table.s (which the 6809 reads) and not the bake."""
    import cel_parity_rule as R
    fi, fs, fdx, fdy, fc = R.frame_table("Fdef")[d["frame"]]
    slot, img = R.decode_table(fi, fs)
    want = {"IMG.CHTAB1": 0, "IMG.CHTAB2": 1, "IMG.CHTAB3": 2, "IMG.CHTAB5": 4}.get(d["table"], 3)
    if (slot, img) != (want, d["image"]) or fdy != d["fdy"]:
        raise SystemExit("probe_place.json: frame %d is %s #%d dy %d in FRAMEDEF, not %s #%d dy %d"
                         % (d["frame"], slot, img, fdy, d["table"], d["image"], d["fdy"]))
    return R.parity(fc, R.FACE_LEFT)


def ref_stream(d, rule="oracle"):
    """The REFERENCE for one draw. rule="oracle" (P5.29): coloured where the oracle draws it --
    facing 0 at a column of parity PL; facing 1 mirrored at (1-PL) XOR (apple_w odd), flipped
    iff 7*apple_w is even (xform_probe_gen.cel_cases, bake_scene's Jay-gated model).
    rule="p528": P5.28's, kept ONLY as the control that reproduces the colour Jay rejected."""
    t = B.short(d["table"])
    stem = "%s_%03d" % (t, d["image"])
    raw = SC.get_cel(B.IMG / d["table"], d["image"])
    aw = raw["w"]
    if rule == "oracle":
        pl = oracle_pl(d)
        sc = pl if d["facing"] == 0 else (1 - pl) ^ (aw & 1)
    else:
        sc = 0
    path = WORK / ("%s_%s_f%d_src.s" % (stem, rule, d["facing"]))
    path.parent.mkdir(parents=True, exist_ok=True)
    SC.convert_one(B.IMG / d["table"], d["image"], path, "%s_r" % stem, sc,
                   d["facing"] == 1 and (7 * aw) % 2 == 0, d["facing"] == 1, trim=True, quiet=True)
    cel = Cel(str(path))
    rows, w = P.shift_pixels(cel, d["phase"])
    segs = []
    for r in range(cel.h):
        segs += P.encode_row(rows[r], w)
    return cel.h, w, segs


def registry_aw(table, image):
    """apple_w from the COMMITTED registry (char_cels.s, parsed by the same reader the probe's
    --baked mode uses), and h/w0 from the committed stream's own header -- nothing derived."""
    import xform_probe_gen as G
    t = B.short(table)
    stem = "%s_%03d" % (t, image)
    p0 = "content/chars/%s/%s_p0.s" % (t, stem)
    aw = G.baked_registry().get((t, image))
    if not aw:
        raise SystemExit("%s #%d has no apple_w in content/chars/char_cels.s" % (table, image))
    hdr = B.fcb_values(ROOT / p0)
    return aw, hdr[1], hdr[0], stem, p0


def occluders():
    bp = BC.Blueprint((BC.LEVELS / "LEVEL0").read_bytes())
    r = BC.Renderer(bp, BC.read_table(BC.IMAGES / "IMG.BGTAB1.DUN"),
                    BC.read_table(BC.IMAGES / "IMG.BGTAB2.DUN"), level=0, bgset1=0)
    r.sure(1)
    out = [("fore $%02X" % e["image"], e["rows"], e["bytes"]) for e in FP.rects(r, r.fg)]
    # the gate bars bg_compose cannot draw (they need the kid's position): drawfrnt at block
    # column 0 of row 0, blockxco 0, Ay 62. Claimed as the whole block, rows 0..62, Apple
    # bytes 0..3 -> port bytes 5..11 -- generous on purpose, since it is not drawn at all.
    out.append(("gate bars (omitted by bg_compose)", [0, 62], [5, 11]))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--asm", required=True)
    ap.add_argument("--ref", required=True)
    a = ap.parse_args()
    place = json.load(open(PLACE))
    fb = bytearray(TILE_REF.read_bytes())
    assert len(fb) == STRIDE * 192
    occ = occluders()
    asm = ["* GENERATED by harness/tools/char_probe_plan.py from content/chars/probe_place.json",
           "* -- do not hand-edit. Per draw: stream, &apple_w (registry), yco, col, phase, facing.",
           "cp_list"]
    incs, bad, drawn = set(), 0, []
    print("char_probe_plan: %d draws on %s screen %d" % (len(place["draws"]), place["screen"]["level"],
                                                      place["screen"]["screen"]))
    for d in place["draws"]:
        aw, w0, h, stem, p0 = registry_aw(d["table"], d["image"])
        yco = d["char_y"] + d["fdy"]
        top = yco - h + 1
        hh, w, segs = ref_stream(d)
        assert hh == h
        # the routine's own frame, by the same arithmetic char_probe.s performs
        if d["facing"] == 0:
            rcol, rk = d["col"], d["phase"]
        else:
            pp = 4 * d["col"] + d["phase"] - (4 * w0 - 7 * aw)
            rcol, rk = pp // 4, pp % 4
        rw = w0 + (1 if rk else 0)
        span = [min(d["col"], rcol), max(d["col"] + w - 1, rcol + rw - 1)]
        hits = [n for n, rows, byts in occ
                if not (rows[1] < top or rows[0] > yco or byts[1] < span[0] or byts[0] > span[1])]
        # the draws must not overlap EACH OTHER either: an overlap would make the picture
        # depend on draw order, which is the question this probe stays out of
        hits += ["draw '%s'" % n for n, rows, byts in drawn
                 if not (rows[1] < top or rows[0] > yco or byts[1] < span[0] or byts[0] > span[1])]
        drawn.append((d["name"], [top, yco], span))
        edge = top < 0 or yco > 191 or span[0] < 0 or span[1] > 79
        bad += bool(hits) + edge
        pl = oracle_pl(d)
        print("  %-9s frame %3d %s #%d aw %d PL %d  rows %d..%d  ref bytes %d..%d  routine %d..%d (phase %d)  %s%s"
              % (d["name"], d["frame"], d["table"], d["image"], aw, pl, top, yco, d["col"],
                 d["col"] + w - 1, rcol, rcol + rw - 1, rk,
                 "CLEAR" if not hits else "OVERLAPS " + ", ".join(hits),
                 "  OFF-SCREEN" if edge else ""))
        base = top * STRIDE + d["col"]
        init = {o - base: v for o, v in enumerate(fb)}
        out = P.simulate(segs, h, w, STRIDE, initial=init)
        for o in range(len(fb)):
            fb[o] = out[o - base]
        t = B.short(d["table"])
        incs.add(p0)
        asm.append("                fdb     %s_p0,%s_aw+%d,fdef_tab+(%d-fdef_tab_first)*FRAME_ENTSZ"
                   % (stem, t, d["image"] - 1, d["frame"]))
        asm.append("                fcb     %d,%d,%d,%d            ; %s"
                   % (yco, d["col"], d["phase"], d["facing"], d["name"]))
    asm.append("                fdb     0")
    asm.append("* the baked streams, the registry and the frame table, from content/chars as committed")
    asm.append("                ifdef   OBJTARGET")
    asm.append("                section chdata")
    asm.append("                endc")
    for p in sorted(incs):
        asm.append("                include \"%s\"" % p)
    asm.append("                include \"content/chars/char_cels.s\"")
    asm.append("                include \"content/chars/frame_table.s\"")
    pathlib.Path(a.asm).parent.mkdir(parents=True, exist_ok=True)
    pathlib.Path(a.asm).write_text("\n".join(asm) + "\n", encoding="utf-8", newline="\n")
    pathlib.Path(a.ref).write_bytes(bytes(fb))
    diff = sum(1 for x, y in zip(fb, TILE_REF.read_bytes()) if x != y)
    print("  predicted framebuffer -> %s (%d B differ from the bare tile reference)" % (a.ref, diff))
    if bad:
        raise SystemExit("char_probe_plan: %d draw(s) overlap the foreground or leave the screen" % bad)
    return 0


if __name__ == "__main__":
    sys.exit(main())
