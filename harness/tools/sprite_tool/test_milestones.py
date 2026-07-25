#!/usr/bin/env python3
"""
test_milestones.py — reproducible gates for the sprite tool's headless-provable core.
Run: python harness/tools/sprite_tool/test_milestones.py
"""
import sys, os, glob, tempfile, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from celio import Cel, roundtrip_ok
from placement_table import Table, ROOT
from frame_assembly import assemble_animation, assemble_static
from pixel_map import ASPECT_W, ASPECT_H, PIXEL_ASPECT, CELL_W, CELL_H, screen_to_sprite, sprite_to_screen_rect
import opacity as O
from lint import lint as opacity_lint

class _Stub:
    def __init__(s, h, w, px): s.h, s.w, s.pixels = h, w, px

def m1_roundtrip():
    cels = glob.glob(os.path.join(ROOT, "content", "*", "scene6_*", "converted.s"))
    fails = [p for p in cels if not roundtrip_ok(p)[0]]
    print(f"M1 lossless round-trip: {len(cels)} scene-6 cels, {len(fails)} fail")
    for p in fails[:10]:
        print("   FAIL", p, roundtrip_ok(p)[1])
    return len(cels) > 0 and not fails

def m2_assembly():
    t = Table()
    af = assemble_animation(t, "climb_crawl", 0)
    exp = {"A3E9": 21*4+3, "A3C5": 22*4+2}     # sub-byte X = col*4+sub
    ok = all(p.x == exp[p.cel_id] for p in af.placed if p.cel_id in exp) and len(af.placed) == 2
    sf = assemble_static(t, "AB4A")
    ok = ok and sf.placed[0].x == 5*4+0
    print(f"M2 table-driven assembly: climb_crawl[f0] {af.W}x{af.H}px, sub-byte X {'ok' if ok else 'WRONG'}")
    return ok

def m3_mapping():
    print(f"M3 aspect: {ASPECT_W}:{ASPECT_H} = {PIXEL_ASPECT} (narrower-than-tall={PIXEL_ASPECT<1}); cell {CELL_W}x{CELL_H}")
    allok = True
    for z in (1, 2, 3, 5):
        bad = 0
        for sx in range(12):
            for sy in range(12):
                x0, y0, cw, ch = sprite_to_screen_rect(sx, sy, z)
                for dx, dy in [(0, 0), (cw-1, 0), (0, ch-1), (cw-1, ch-1), (cw//2, ch//2)]:
                    if screen_to_sprite(x0+dx, y0+dy, z) != (sx, sy):
                        bad += 1
        allok = allok and bad == 0
        print(f"   zoom {z}x: {'PASS' if bad==0 else f'FAIL {bad}'}")
    return allok

def m4b_derive_verify():
    def g(h, w): return [[0] * (w * 4) for _ in range(h)]
    ok = True
    # mixed (byte-aligned)
    c = _Stub(2, 2, g(2, 2)); op = O.blank_opacity(c)
    for rr in range(2):
        for k in range(4): op[rr][k] = True
    k, p = O.derive(c, op); v, _ = O.verify(c, op, k, p); ok = ok and k == 'mixed' and v
    # masked (sub-byte, column-uniform)
    c = _Stub(2, 1, g(2, 1)); op = O.blank_opacity(c)
    for rr in range(2): op[rr][0] = op[rr][1] = True
    k, p = O.derive(c, op); v, _ = O.verify(c, op, k, p); ok = ok and k == 'masked' and p == [0xF0] and v
    # row-varying sub-byte -> STENCIL (universal per-pixel; no STOP now)
    c = _Stub(2, 1, g(2, 1)); op = O.blank_opacity(c)
    op[0][0] = op[0][1] = True; op[1][0] = True
    k, p = O.derive(c, op); v, _ = O.verify(c, op, k, p); ok = ok and k == 'stencil' and v
    # stencil sidecar round-trips
    import sidecar as SC, tempfile as _tf
    d = _tf.mkdtemp(prefix="stencil_")
    try:
        SC.write_sidecar(d, "cel", k, p)
        ok = ok and SC.read_sidecar(d) == (k, p)
    finally:
        shutil.rmtree(d, ignore_errors=True)
    print(f"M4b derive+verify (mixed/masked/stencil, cheapest-fits, no STOP): {'PASS' if ok else 'FAIL'}")
    return ok

def m5_save():
    from save import save_cel, read_state
    import sidecar as SC
    src = os.path.join(ROOT, "content", "player", "scene6_climb_A3C5", "converted.s")
    tmp = tempfile.mkdtemp(prefix="spritetool_")
    try:
        cd = os.path.join(tmp, "A3C5"); os.makedirs(cd)
        shutil.copy2(src, os.path.join(cd, "converted.s"))
        tbl = os.path.join(tmp, "table.txt")
        open(tbl, "w", newline="").write("[registry]\r\nA3C5   content/player/scene6_climb_A3C5\r\n")
        orig = open(os.path.join(cd, "converted.s"), newline="").read()
        cel = Cel(os.path.join(cd, "converted.s")); op = O.blank_opacity(cel)
        for rr in range(cel.h):
            for k in range(4):
                if cel.pixels[rr][k] == 0: op[rr][k] = True     # byte-col 0 opaque -> mixed
        r = save_cel(cel, cd, "scene6_climb_A3C5", op, "A3C5", tbl)
        after = open(os.path.join(cd, "converted.s"), newline="").read()
        ok = (after == orig and r["state"] == "authored" and r["kind"] == "mixed" and r["byte_identical"]
              and SC.read_sidecar(cd) == O.derive(cel, op) and read_state(tbl, "A3C5") == "authored")
        print(f"M5 save: opacity-only converted.s byte-identical + sidecar + state=authored: {'PASS' if ok else 'FAIL'}")
        return ok
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

def c_reload():
    def g(h, w): return [[0] * (w * 4) for _ in range(h)]
    ok = True
    # mixed
    c = _Stub(2, 2, g(2, 2)); op = O.blank_opacity(c)
    for rr in range(2):
        for k in range(4): op[rr][k] = True
    k, p = O.derive(c, op); r, _, _ = O.reload_is_lossless(c, k, p); ok = ok and r and k == 'mixed'
    # masked
    c = _Stub(2, 1, g(2, 1)); op = O.blank_opacity(c)
    for rr in range(2): op[rr][0] = op[rr][1] = True
    k, p = O.derive(c, op); r, _, _ = O.reload_is_lossless(c, k, p); ok = ok and r and k == 'masked'
    # stencil
    c = _Stub(2, 1, g(2, 1)); op = O.blank_opacity(c); op[0][0] = op[0][1] = True; op[1][0] = True
    k, p = O.derive(c, op); r, _, _ = O.reload_is_lossless(c, k, p); ok = ok and r and k == 'stencil'
    print(f"C reload round-trip (mixed/masked/stencil decode->re-derive lossless): {'PASS' if ok else 'FAIL'}")
    return ok

def p1_color():
    """Part 1: color edit -> save -> reload lossless (Gate A); recolor on authored re-derives with
    full coverage (Gate B); recolor a marked-opaque pixel drops its opacity mark (Gate C)."""
    from edit_model import CelEdit
    from save import save_cel
    import sidecar as SC
    src = os.path.join(ROOT, "content", "player", "scene6_climb_A3C5")
    if not os.path.exists(os.path.join(src, "opacity.s")):
        print("p1_color: (A3C5 not authored — skipped)"); return True
    tmp = tempfile.mkdtemp(prefix="p1_"); cd = os.path.join(tmp, "A3C5"); os.makedirs(cd)
    try:
        shutil.copy2(os.path.join(src, "converted.s"), os.path.join(cd, "converted.s"))
        shutil.copy2(os.path.join(src, "opacity.s"), os.path.join(cd, "opacity.s"))
        tbl = os.path.join(tmp, "t.txt")
        open(tbl, "w", newline="").write("[registry]\r\nA3C5   content/player/scene6_climb_A3C5   authored\r\n")
        ce = CelEdit("A3C5", Cel(os.path.join(cd, "converted.s")), cd, "scene6_climb_A3C5", "A3C5")
        # Gate A
        sp = next(((c, r) for r in range(ce.cel.h) for c in range(ce.cel.w*4) if ce.cel.pixels[r][c] == 1), None)
        ce.begin_stroke(); ce.paint(sp[0], sp[1], "white")
        save_cel(ce.cel, cd, "scene6_climb_A3C5", ce.opacity, "A3C5", tbl)
        re = Cel(os.path.join(cd, "converted.s"))
        gA = re.pixels[sp[1]][sp[0]] == 3 and roundtrip_ok(os.path.join(cd, "converted.s"))[0]
        # Gate B
        k, p = O.derive(ce.cel, ce.opacity)
        gB = O.reload_is_lossless(ce.cel, k, p)[0]
        if k == "mixed":
            cov = set((r, c) for scol, w, sr, nr, op in p for r in range(sr, sr+nr) for c in range(scol, scol+w))
            gB = gB and not [(r, c) for r in range(ce.cel.h) for c in range(ce.cel.w) if (r, c) not in cov]
        # Gate C
        op_sp = next(((c, r) for r in range(ce.cel.h) for c in range(ce.cel.w*4)
                      if ce.cel.pixels[r][c] == 0 and ce.opacity[r][c]), None)
        gC = True
        if op_sp:
            ce.begin_stroke(); ce.paint(op_sp[0], op_sp[1], "orange")
            gC = (ce.cel.pixels[op_sp[1]][op_sp[0]] == 1 and ce.opacity[op_sp[1]][op_sp[0]] is False)
        ok = gA and gB and gC
        print(f"P1 color (A round-trip={gA}, B recolor-coverage={gB}, C mark-drop={gC}): {'PASS' if ok else 'FAIL'}")
        return ok
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

def p3_revert():
    """Part 3 (buffer-based): Revert/Undo-Revert availability matches the table, the buffer is
    one-shot, AND — the load-bearing gate — Undo-Revert restores the undo stack in EXACT
    original order (strokes A,B,C -> after undo-revert, Undo steps back C, then B, then A)."""
    import copy as _copy
    from frame_assembly import assemble_animation
    from edit_model import FrameEdit
    t = Table(); fe = FrameEdit(t, assemble_animation(t, "climb_crawl", 0))
    ce = fe.cels[fe.selected]
    def chg(r, c):    # a palette entry guaranteed to change pixel (r,c)
        return "white" if ce.cel.pixels[r][c] != 3 else "orange"
    p = [x for x in fe.frame.placed if x.cel_id == fe.selected][0]
    cx, cy = (p.x - fe.frame.x0), (p.y - fe.frame.y0)      # local (0,0) on the selected cel
    # --- availability table ---
    ok = (not fe.is_dirty() and not fe.can_undo_revert())                       # clean
    fe.paint_canvas(cx, cy, chg(0, 0)); ok = ok and fe.is_dirty() and not fe.can_undo_revert()   # dirty
    fe.revert_all();          ok = ok and not fe.is_dirty() and fe.can_undo_revert()             # just reverted
    fe.paint_canvas(cx, cy, chg(0, 0)); ok = ok and fe.is_dirty() and not fe.can_undo_revert()   # reverted+edited
    fe2 = FrameEdit(t, assemble_animation(t, "climb_crawl", 0))
    fe2.paint_canvas(cx, cy, "orange"); fe2.revert_all()
    ok = ok and fe2.undo_revert() and fe2.is_dirty()
    fe2.revert_all(); fe2.touched(); ok = ok and not fe2.can_undo_revert()      # switch/touch grays + clears buffer
    avail = ok

    # --- ordering gate: three distinct strokes A,B,C on the selected cel, each begin_stroke()'d ---
    fe3 = FrameEdit(t, assemble_animation(t, "climb_crawl", 0))
    ge = fe3.cels[fe3.selected]
    pts = [(0, 0), (1, 0), (2, 0)]                              # three distinct local pixels
    s0 = _copy.deepcopy(ge.cel.pixels)                          # baseline canvas
    states = [_copy.deepcopy(s0)]                              # states[i] = canvas after i strokes
    for (px, py) in pts:                                        # strokes A, B, C
        ge.begin_stroke(); ge.paint(px, py, "white" if ge.cel.pixels[py][px] != 3 else "orange")
        states.append(_copy.deepcopy(ge.cel.pixels))
    stack_depth_before = len(ge.undo)                          # == 3
    fe3.revert_all()                                           # canvas->Old, stack CLEARED
    reverted_empty = (ge.undo == [] and ge.cel.pixels == s0)
    fe3.undo_revert()                                          # restore canvas + ordered stack
    restored_top = (ge.cel.pixels == states[3] and len(ge.undo) == 3)
    # Undo must now step back in ORIGINAL order: C (->states[2]), then B (->states[1]), then A (->states[0])
    order_ok = True
    for expect in (states[2], states[1], states[0]):
        ge.undo_stroke()
        order_ok = order_ok and (ge.cel.pixels == expect)
    ordering = (stack_depth_before == 3 and reverted_empty and restored_top and order_ok)

    result = avail and ordering
    print(f"P3 revert/undo-revert (availability={avail}, ordering C->B->A original-order={ordering}): "
          f"{'PASS' if result else 'FAIL'}")
    return result

def p3b_button_state():
    """UI availability: Save==dirty, Undo==undo-stack-nonempty, Redo==redo-stack-nonempty (cleared
    on a new edit), plus the §2 revert-transition rows. Signal-level (what refresh_buttons reads)."""
    from frame_assembly import assemble_animation
    from edit_model import FrameEdit
    t = Table(); fe = FrameEdit(t, assemble_animation(t, "climb_crawl", 0))
    ge = fe.cels[fe.selected]
    def color(px, py): return "white" if ge.cel.pixels[py][px] != 3 else "orange"
    def press_paint(px, py):                          # mirrors on_press: begin_stroke ALL, paint selected
        for ce in fe.cels.values(): ce.begin_stroke()
        ge.paint(px, py, color(px, py))
    def undo():
        for ce in fe.cels.values(): ce.undo_stroke()
    def sig(): return (fe.is_dirty(), fe.can_undo(), fe.can_redo(), fe.can_undo_revert())   # (Save,Undo,Redo,UndoRevert)
    ok = True
    ok = ok and sig() == (False, False, False, False)                 # clean: Save/Undo/Redo/UndoRevert all grayed
    press_paint(0, 0); ok = ok and sig() == (True, True, False, False)   # dirty: Save+Undo enabled, Redo grayed
    undo();            ok = ok and sig()[:3] == (False, False, True)     # undone to baseline: Redo enabled
    press_paint(1, 0); ok = ok and sig() == (True, True, False, False)   # new edit CLEARS redo -> Redo re-grays
    # §2 transition: after Revert -> Save/Undo/Redo/Revert grayed, Undo-Revert enabled
    fe.revert_all();   after_revert = sig(); ok = ok and after_revert == (False, False, False, True)
    # §2 transition: after Undo-Revert -> Save+Undo enabled (stack restored), Undo-Revert grayed
    fe.undo_revert();  ar = sig(); ok = ok and ar[0] and ar[1] and not ar[3]
    print(f"P3b button-state (avail table + §2 revert transitions): {'PASS' if ok else 'FAIL'}")
    return ok

def m5b_lint():
    errs, conv = opacity_lint()
    print(f"M5b lint (real tree clean): {len(errs)} errors, {len(conv)} converted — {'PASS' if not errs else 'FAIL'}")
    return not errs

if __name__ == "__main__":
    r = [("M1", m1_roundtrip()), ("M2", m2_assembly()), ("M3-math", m3_mapping()),
         ("M4b", m4b_derive_verify()), ("M5", m5_save()), ("M5b", m5b_lint()),
         ("C-reload", c_reload()), ("P1-color", p1_color()), ("P3-revert", p3_revert()),
         ("P3b-buttons", p3b_button_state())]
    print()
    for name, ok in r:
        print(f"  {name}: {'PASS' if ok else 'FAIL'}")
    sys.exit(0 if all(ok for _, ok in r) else 1)
