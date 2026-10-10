#!/usr/bin/env python3
r"""gate_probe_plan.py — P5.30: the gate bar two ways (Ruling 2), predicted, measured and priced.

THE PIECE. `$46` is bgtable1 #70, fronti[4]: the static FRONT piece `drawfrnt` lays for a GATE
block, with maddfore -- mask, then ora [FRAMEADV.S:1170; P5.8 caught the pair live at XCO 39 /
YCO 62 on screen 2]. bg_compose includes it (fore_plane.py --screen 2 lists both halves). It is
NOT what DrawGateBF draws: that routine lays $44 (gatebotORA) and $37 (gateB1) by gate STATE,
and only over a kid in the gate's block [FRAMEADV.S:829-842, 1765-1811] -- bg_compose omits
those, and so does this tool.

THE TWO WAYS, over screen 2 baked WITHOUT the bar (bake_screen.py --omit 46):
  A  "as a sprite": $46 converted in isolation by sprite_convert at its own Apple column
     (start_col = 7*XCO, so its colour parity is the real one) and drawn KEYED by blit_cel_full
     at its port position. Its edge pixels never saw their neighbours.
  B  "per-context": the bytes of screen 2's finished composite WITH the bar, over the box where
     the with-bar and without-bar composites differ. That is the bar baked against the
     background it sits on -- and it is exactly what the static page bake already holds.
Both framebuffers are PREDICTED here before anything runs. B's prediction must equal the
with-bar composite everywhere (checked). A's difference from it IS the artifact Jay rules on.

★ WHAT A PREDICTION IS WORTH (P5.29): the runtime matching it proves the 6809 drew what this
tool composed. Whether the with-bar composite is the ORACLE's colour is Jay's to judge, and
the colour model's fidelity is not what this measures.

★★ WHAT IT FOUND, AND WHY NO GATE PROBE WAS BUILT (P5.30 §3D). At every real $46 placement in
LEVEL0 (screens 2, 3 x2, 4) the sprite error is 0 px: the bar's rows 3..33 sit on BLACK in the
composite -- the gate's own B-section (drawgateb, the lit grill behind it) is state-dependent and
bg_compose does not draw it -- and rows 36..62 already carry the same bar pattern from a background
entry. P5.8's 14.3% was the worst of 25 SYNTHETIC lit contexts; no real context this toolchain can
composite reaches it. A GATEA/GATEB pair would have shown Jay two identical pictures, so the
probe program was dropped at the finding; --asm/--lz/--ref-* emit its inputs if a later dispatch
models drawgateb and wants it.

  python harness/tools/gate_probe_plan.py [--screen 2] [--price]                 measure + price
  python harness/tools/gate_probe_plan.py --lz L --asm A --ref-a RA --ref-b RB   + the probe's inputs
"""
import argparse
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "sprite_tool"))
import bake_screen as BS                                    # noqa: E402
import bg_compose as BC                                     # noqa: E402
import cel_blit_prep as P                                   # noqa: E402
import sprite_convert as SC                                 # noqa: E402
from celio import Cel                                       # noqa: E402

STRIDE = 80
BAR = 0x46
BAR_TABLE = BC.IMAGES / "IMG.BGTAB1.DUN"
BAR_INDEX = 70                    # bgtable1 #70 (image byte $46 -> table 0, index $46)
WORK = ROOT / "build/p530"


def bar_stream(xco, yco):
    """$46 converted in isolation at its real Apple column, shifted to its port phase."""
    WORK.mkdir(parents=True, exist_ok=True)
    path = WORK / ("bar46_x%d.s" % xco)
    SC.convert_one(BAR_TABLE, BAR_INDEX, path, "bar46", 7 * xco, False, False, trim=True, quiet=True)
    cel = Cel(str(path))
    px = 20 + 7 * xco
    phase, col = px % 4, px // 4
    rows, w = P.shift_pixels(cel, phase)
    segs = []
    for r in range(cel.h):
        segs += P.encode_row(rows[r], w)
    assert not P.verify(cel, phase, segs)
    return cel.h, w, segs, yco - cel.h + 1, col


def draw_onto(fb, h, w, segs, top, col):
    base = top * STRIDE + col
    init = {o - base: v for o, v in enumerate(fb)}
    out = P.simulate(segs, h, w, STRIDE, initial=init)
    return bytearray(out[o - base] for o in range(len(fb)))


def bbox(a, b, rows=None, cols=None):
    diff = [o for o in range(len(a)) if a[o] != b[o]
            and (rows is None or rows[0] <= o // STRIDE <= rows[1])
            and (cols is None or cols[0] <= o % STRIDE <= cols[1])]
    if not diff:
        return None
    r = [o // STRIDE for o in diff]
    c = [o % STRIDE for o in diff]
    return min(r), max(r), min(c), max(c)


def px_diff(a, b, offs):
    """(pixels differing, of which black<->lit) over byte offsets offs."""
    n = bl = 0
    for o in offs:
        for j in range(4):
            pa, pb = (a[o] >> (6 - 2 * j)) & 3, (b[o] >> (6 - 2 * j)) & 3
            if pa != pb:
                n += 1
                bl += (pa == 0) != (pb == 0)
    return n, bl


def bars_on(level, screen):
    r = BC.Renderer(BC.Blueprint((BC.LEVELS / level).read_bytes()),
                    BC.read_table(BC.IMAGES / "IMG.BGTAB1.DUN"),
                    BC.read_table(BC.IMAGES / "IMG.BGTAB2.DUN"), level=0, bgset1=0)
    r.sure(screen)
    return sorted({(x, y) for i, x, y, op in r.fg if i == BAR})


def fcb(vals):
    vals = list(vals)
    return ["                fcb     " + ",".join("$%02X" % v for v in vals[i:i + 12])
            for i in range(0, len(vals), 12)]


def price(level):
    """Every $46 placement in the level: per-context bytes, sprite stream bytes, sprite error."""
    print("PRICE — every $46 placement in %s (static: one variant per placement, not per state)" % level)
    tot_ctx = tot_spr = n = 0
    for s in range(1, 25):
        bars = bars_on(level, s)
        if not bars:
            continue
        full = BS.bake(level, s, "DUN")[0]
        nobar = BS.bake(level, s, "DUN", omit=(BAR,))[0]
        for xco, yco in bars:
            h, w, segs, top, col = bar_stream(xco, yco)
            win_r, win_c = (top - 1, yco + 1), (col - 1, col + w)
            bb = bbox(full, nobar, win_r, win_c)
            ctx = (bb[1] - bb[0] + 1) * (bb[3] - bb[2] + 1) if bb else 0
            spr = draw_onto(nobar, h, w, segs, top, col)
            offs = [r * STRIDE + c for r in range(win_r[0], win_r[1] + 1) for c in range(win_c[0], win_c[1] + 1)
                    if 0 <= r < 192]
            e, bl = px_diff(spr, full, offs)
            print("  screen %2d  XCO %2d YCO %3d  per-context box %s = %3d B   sprite stream %3d B   "
                  "sprite error %2d px (%d black<->lit)" % (s, xco, yco, bb, ctx, 2 + len(segs), e, bl))
            tot_ctx += ctx
            tot_spr += 2 + len(segs)
            n += 1
    print("  %d placement(s): per-context %d B, as sprites %d B (static page bake: already in the page, +0 B)"
          % (n, tot_ctx, tot_spr))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--level", default="LEVEL0")
    ap.add_argument("--screen", type=int, default=2)
    ap.add_argument("--lz", default=None)
    ap.add_argument("--asm", default=None)
    ap.add_argument("--ref-a", default=None)
    ap.add_argument("--ref-b", default=None)
    ap.add_argument("--price", action="store_true")
    a = ap.parse_args()

    full = BS.bake(a.level, a.screen, "DUN")[0]
    nobar = BS.bake(a.level, a.screen, "DUN", omit=(BAR,))[0]
    bars = bars_on(a.level, a.screen)
    if len(bars) != 1:
        raise SystemExit("screen %d has %d $46 placements; this probe draws exactly one" % (a.screen, len(bars)))
    xco, yco = bars[0]
    h, w, segs, top, col = bar_stream(xco, yco)
    print("gate_probe_plan: %s screen %d, $46 at XCO %d YCO %d -> port byte %d phase %d, rows %d..%d, "
          "%dx%d stream %d B" % (a.level, a.screen, xco, yco, col, (20 + 7 * xco) % 4, top, yco, w, h, 2 + len(segs)))

    pred_a = draw_onto(nobar, h, w, segs, top, col)
    r0, r1, c0, c1 = bbox(full, nobar)
    pred_b = bytearray(nobar)
    for r in range(r0, r1 + 1):
        pred_b[r * STRIDE + c0:r * STRIDE + c1 + 1] = full[r * STRIDE + c0:r * STRIDE + c1 + 1]
    assert bytes(pred_b) == full, "per-context box does not reproduce the with-bar composite"
    print("  per-context box: rows %d..%d, bytes %d..%d = %d B; prediction B == the with-bar composite: EXACT"
          % (r0, r1, c0, c1, (r1 - r0 + 1) * (c1 - c0 + 1)))

    foot = [r * STRIDE + c for r in range(top, yco + 1) for c in range(col, col + w)]
    e, bl = px_diff(pred_a, full, foot)
    eb = sum(1 for o in foot if pred_a[o] != full[o])
    allpx, allbl = px_diff(pred_a, full, range(len(full)))
    print("  ★ AS A SPRITE vs the with-bar composite: %d px differ over the bar's %d-px footprint "
          "(%d black<->lit), %d bytes; %d px over the whole screen" % (e, 7 * h, bl, eb, allpx))

    if not (a.lz and a.asm and a.ref_a and a.ref_b):
        if a.price:
            print()
            price(a.level)
        return 0
    lz = pathlib.Path(a.lz).read_bytes()
    L = ["* GENERATED by harness/tools/gate_probe_plan.py -- do not hand-edit.",
         "GP_TOP          equ     %d" % top,
         "GP_COL          equ     %d" % col,
         "GP_R0           equ     %d" % r0,
         "GP_CH           equ     %d" % (r1 - r0 + 1),
         "GP_C0           equ     %d" % c0,
         "GP_CW           equ     %d" % (c1 - c0 + 1),
         "* --- A: $46 converted in isolation, keyed segment stream (cel_blit_prep format) ---",
         "gp_bar          fcb     %d,%d" % (h, w)]
    L += fcb(segs)
    L += ["* --- B: the with-bar composite over the box ---", "gp_ctx"]
    ctx = []
    for r in range(r0, r1 + 1):
        ctx += list(full[r * STRIDE + c0:r * STRIDE + c1 + 1])
    L += fcb(ctx)
    L += ["* --- the PACKED no-bar page, LOADM'd straight into LZ_STAGE ($3000; -DPAGE_PRELOADED) ---",
          "                ifdef   OBJTARGET",
          "                section gpage",
          "                endc",
          "gp_page_lz"]
    L += fcb(lz)
    pathlib.Path(a.asm).parent.mkdir(parents=True, exist_ok=True)
    pathlib.Path(a.asm).write_text("\n".join(L) + "\n", encoding="utf-8", newline="\n")
    pathlib.Path(a.ref_a).write_bytes(bytes(pred_a))
    pathlib.Path(a.ref_b).write_bytes(bytes(pred_b))
    print("  -> %s, %s, %s (packed page %d B)" % (a.asm, a.ref_a, a.ref_b, len(lz)))
    if a.price:
        print()
        price(a.level)
    return 0


if __name__ == "__main__":
    sys.exit(main())
