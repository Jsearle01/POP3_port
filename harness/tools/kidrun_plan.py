#!/usr/bin/env python3
r"""kidrun_plan.py — P5.31/P5.32: the running kid AND the standing guard -- their sequences CHECKED,
their data EMITTED, their steps PREDICTED.

1. THE SEQUENCES, TWO WAYS (verify_sequences.py's principle -- a check whose two sides share a
   derivation agrees with itself when wrong). src/engine/kidrun_probe.s carries `startrun` and
   `guardengarde` TRANSCRIBED BY HAND; seq_graph.parse_seqtable() reads SEQTABLE.S itself, with
   ANIMCHAR's operand counts. Both are walked with ANIMCHAR's semantics (opcodes precede the frame
   they affect; chx through ADDCHARX -- negated facing left [CTRLSUBS.S:353]) for WALK_CHECK steps
   and must emit the same (frame, CharX) every step, or this exits 1.
2. THE ORACLE'S TRACE, for the KID: P5.21's oracle_step_trace.lua logged the demo's kid at every
   game frame; at display frame 7949 he starts `startrun` from CharX 191, CharY 55, facing left, on
   LEVEL0 screen 1. Frames 1..11 are checked against ORACLE and the trace file itself.
   ★ THE GUARD HAS NO TRACE HERE. The trace's opponent record (S=...) is constant through the run --
   the demo's guard is on another screen -- so his positions are checked against seq_graph only
   (and `ready` has no chx: he does not move).
3. THE DATA: build/gen/kidrun_gen.s -- equates, both image -> stream tables, the baked streams
   first-fit into two spans, the frame table.
4. THE PREDICTION, at the steps --predict names, with NO HISTORY: the tile reference, the kid at
   that step's position, then the GUARD over him ("enemy is always in front", FRAMEADV.S:2191-2193,
   `compare`), each from a REFERENCE stream coloured where the ORACLE draws it, then the
   page's foreground list replayed over both. Alongside each, kidrun_ref_N.json: both frames'
   rectangles and the bytes where BOTH draws are opaque -- P3.32's discriminating test is
   byte-exactness THERE (kidrun_overlap.py).
"""
import argparse
import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "sprite_tool"))
import seq_graph as SG                                      # noqa: E402
import cel_parity_rule as R                                 # noqa: E402
import cel_blit_prep as P                                   # noqa: E402
import sprite_convert as SC                                 # noqa: E402
import bake_screen as BS                                    # noqa: E402
import lz_pack as LZ                                        # noqa: E402
import xf_tables as XT                                      # noqa: E402
import bake_chars as B                                      # noqa: E402
from celio import Cel                                       # noqa: E402

STRIDE = 80
X0, Y0 = 191, 55                 # the oracle demo's start (trace frame 7949)
XMIN = 122                       # the floor ends at the pit (block columns 2-3); wrap before it
SPEED = 6                        # display frames per animation step: the oracle's run frames held
#                                  6.22 on average over P5.21's trace (kidrun_cost.py) -- 6 is the nearest
#                                  constant; the oracle itself varies 4..8 with how much it draws
# ★ P5.32: THE GUARD. CharX 160 on the same floor, facing RIGHT -- toward the kid, who starts to his
# right running left. His frame spans port px ~189..224; the kid's runs from ~286 down to ~154 each
# lap, so the kid runs THROUGH him mid-lap (the overlap P5.32 §2 requires; this file fails without it).
GD_X = 160
GD_TABLE = "IMG.CHTAB4.GD"       # chtable4 = chset; level 0 -> GD [demo_frame_census.SLOT_FILE]
GD_NIMG = 32
WALK_CHECK = 80
WK_PEEL = 400
GD_PEEL = 320
SRC = ROOT / "src/engine/kidrun_probe.s"
WORK = ROOT / "build/p531"
# P5.21's oracle trace, the kid record's Posn and CharX at each game frame of this run:
#   F 7949 K=01BF..  F 7953 K=02BF..  F 7957 K=03BF..  F 7961 K=04BF..  F 7965 K=05B7..
#   F 7971 K=06B4..  F 7979 K=07B1..  F 7985 K=08AC..  F 7990 K=09AB..  F 7996 K=0AA9..
#   F 8002 K=0BA5..  F 8008 K=35A5.. (runstop -- AutoCtrl, out of scope)
ORACLE = [(1, 191, 7949), (2, 191, 7953), (3, 191, 7957), (4, 191, 7961), (5, 183, 7965),
          (6, 180, 7971), (7, 177, 7979), (8, 172, 7985), (9, 171, 7990), (10, 169, 7996),
          (11, 165, 8002)]
ORACLE_NEXT = 8008
SEQ_OPS = {"SEQ_GOTO": "goto", "SEQ_CHX": "chx", "SEQ_ACT": "act", "SEQ_TAP": "tap"}


def transcription(start, end):
    """kidrun_probe.s's hand-written sequence from label `start` up to label `end`, as tokens."""
    text = SRC.read_text(encoding="utf-8").splitlines()
    i = next(n for n, l in enumerate(text) if l.startswith(start))
    toks, labels = [], {}
    for l in text[i:]:
        s = l.split(";")[0]
        if s and not s[0].isspace():
            m = re.match(r"^(\w+)\s*(.*)$", s)
            if m.group(1) == end:
                break
            labels[m.group(1)] = len(toks)
            s = " " + m.group(2)
        s = s.strip()
        if s.startswith("fcb"):
            for t in s[3:].split(","):
                t = t.strip()
                toks.append(("op", t) if t.startswith("SEQ_") else ("num", int(t)))
        elif s.startswith("fdb"):
            toks.append(("addr", s[3:].strip()))
    return toks, labels


def walk(toks, labels, start, nsteps, opname, x0, face_left):
    """ANIMCHAR over a token list. chx through ADDCHARX: CharX - d facing left, + d facing right."""
    i, x, out = labels[start], x0, []
    while len(out) < nsteps:
        kind, v = toks[i]
        if kind == "num":
            out.append((v, x))
            i += 1
            continue
        op = opname(v)
        if op == "goto":
            i = labels[toks[i + 1][1]]
        elif op == "chx":
            d = toks[i + 1][1]
            x = (x - d if face_left else x + d) & 0xFF
            i += 2
        elif op in ("act", "tap"):
            i += 2
        else:
            raise SystemExit("walk: opcode %r is not implemented by kidrun_probe.s" % (v,))
    return out


def check_sequence():
    items, labels, entries = SG.parse_seqtable()
    assert entries[1] == "startrun"
    res = {}
    for who, mine_lab, end, ref_lab, x0, left in (
            ("kid", "wk_startrun", "wk_startrun_end", "startrun", X0, True),
            ("guard", "gd_guardengarde", "gd_guardengarde_end", "guardengarde", GD_X, False)):
        tt, tl = transcription(mine_lab, end)
        mine = walk(tt, tl, mine_lab, WALK_CHECK, lambda v: SEQ_OPS[v], x0, left)
        ref = walk(items, labels, ref_lab, WALK_CHECK, lambda v: v, x0, left)
        bad = [(n, a, b) for n, (a, b) in enumerate(zip(mine, ref)) if a != b]
        print("kidrun_plan: %-6s `%s` -- hand transcription vs seq_graph's parse of SEQTABLE.S, %d steps: %s"
              % (who, ref_lab, WALK_CHECK, "IDENTICAL" if not bad else "DIVERGE at %r" % bad[:3]))
        if bad:
            raise SystemExit(1)
        res[who] = ref
    ref = res["kid"]
    obad = [(f, x, ref[n]) for n, (f, x, _fr) in enumerate(ORACLE) if ref[n] != (f, x)]
    print("kidrun_plan: kid positions vs the ORACLE's trace (frames 1..11, display frames %d..%d): %s"
          % (ORACLE[0][2], ORACLE[-1][2], "IDENTICAL" if not obad else "DIFFER %r" % obad))
    if obad:
        raise SystemExit(1)
    tr = ROOT / "build/tmp/oracle_step_trace.txt"
    if tr.exists():
        got, opp = [], set()
        for line in tr.read_text().splitlines():
            m = re.match(r"^F (\d+) K=([0-9A-F]{4})\S* S=(\S+)", line)
            if m and ORACLE[0][2] <= int(m.group(1)) < ORACLE_NEXT:
                got.append((int(m.group(2)[:2], 16), int(m.group(2)[2:], 16), int(m.group(1))))
                opp.add(m.group(3))
        print("kidrun_plan: ... and against build/tmp/oracle_step_trace.txt itself: %s"
              % ("IDENTICAL" if got == ORACLE else "DIFFER %r" % got))
        if got != ORACLE:
            raise SystemExit(1)
        print("kidrun_plan: the trace's opponent record over the same frames: %d distinct value(s) -- "
              "%s" % (len(opp), "constant: no guard on screen 1 in the demo, so the guard is checked "
                      "against seq_graph only" if len(opp) == 1 else "CHANGING"))
    durs = [b[2] - a[2] for a, b in zip(ORACLE, ORACLE[1:] + [(0, 0, ORACLE_NEXT)])]
    print("kidrun_plan: the oracle held frames 1..11 for %s display frames (mean %.2f -> %.2f fps)"
          % (durs, sum(durs) / len(durs), 60.0 * len(durs) / sum(durs)))
    return res


def stream_of(img):
    return B.fcb_values(ROOT / "content/chars/chtab1" / ("chtab1_%03d_p0.s" % img))


def gd_stream_of(img):
    return B.fcb_values(ROOT / "content/chars/chtab4gd" / ("chtab4gd_%03d_p0.s" % img))


def kid_steps(n):
    """The kid's run with the harness's wrap, as kidrun_probe.s runs it: positions from seq_graph."""
    items, labels, _ = SG.parse_seqtable()
    out, seq = [], []
    while len(out) < n:
        if not seq:
            seq = walk(items, labels, "startrun", 400, lambda v: v, X0, True)
        f, x = seq.pop(0)
        fi, fs, fdx, fdy, fc = R.frame_table("Fdef")[f]
        slot, img = R.decode_table(fi, fs)
        assert slot == 0 and 1 <= img <= 14, (f, slot, img)
        pl = R.parity(fc, R.FACE_LEFT)
        px = 20 + 2 * (x - fdx - 58) + pl
        s = stream_of(img)
        h, w0 = s[0], s[1]
        k, col = px % 4, px // 4
        top = Y0 + fdy - h + 1
        w = w0 + (1 if k else 0)
        out.append(dict(step=len(out) + 1, frame=f, x=x, img=img, pl=pl, px=px, col=col, k=k,
                        top=top, h=h, w=w, rcol=col, rk=k))
        if x < XMIN:
            seq = []
    return out


def gd_steps(n):
    """The guard: `guardengarde` from seq_graph, frames through usealtsets [CTRLSUBS.S:1685]."""
    items, labels, _ = SG.parse_seqtable()
    alt, fdef = R.frame_table("ALTSET1"), R.frame_table("Fdef")
    out = []
    for f, x in walk(items, labels, "guardengarde", n, lambda v: v, GD_X, False):
        fi, fs, fdx, fdy, fc = (alt if 150 <= f < 190 else fdef)[f]
        slot, img = R.decode_table(fi, fs)
        assert slot == 3 and 1 <= img <= GD_NIMG, (f, slot, img)
        pl = R.parity(fc, 0)                               # CharFace 0: facing right
        fcx = 2 * (x + fdx - 58) + pl                      # ADDCHARX facing right: CharX + Fdx
        s = gd_stream_of(img)
        h, w0 = s[0], s[1]
        aw = SC.get_cel(B.IMG / GD_TABLE, img)["w"]
        px = 20 + fcx - 4 * w0                             # xf_blit's mirrored frame ENDS at FCharX
        rpx = 20 + fcx - 7 * aw                            # the reference: 7*apple_w px, also ending there
        top = Y0 + fdy - h + 1
        k, col = px % 4, px // 4
        out.append(dict(step=len(out) + 1, frame=f, x=x, img=img, pl=pl, px=px, col=col, k=k,
                        top=top, h=h, w=w0 + (1 if k else 0), aw=aw, rcol=rpx // 4, rk=rpx % 4,
                        sword=fs & 0x3F))
    return out


def segs_of(path, k):
    cel = Cel(str(path))
    rows, w = P.shift_pixels(cel, k)
    segs = []
    for r in range(cel.h):
        segs += P.encode_row(rows[r], w)
    return cel.h, w, segs


def lay(fb, h, w, segs, top, col):
    base = top * STRIDE + col
    init = {o - base: v for o, v in enumerate(fb)}
    out = P.simulate(segs, h, w, STRIDE, initial=init)
    return bytes(out[o - base] for o in range(len(fb)))


def kid_ref(st):
    path = WORK / ("kidrun_ref_img%d_pl%d.s" % (st["img"], st["pl"]))
    path.parent.mkdir(parents=True, exist_ok=True)
    SC.convert_one(B.IMG / "IMG.CHTAB1", st["img"], path, "r", st["pl"], False, False, trim=True, quiet=True)
    return segs_of(path, st["rk"])


def gd_ref(g):
    """facing 1: mirrored at (1-PL) XOR (apple_w odd), flipped iff 7*apple_w is even --
    char_probe_plan.ref_stream's oracle rule (xform_probe_gen.cel_cases, bake_scene's Jay-gated model)."""
    aw, pl = g["aw"], g["pl"]
    path = WORK / ("kidrun_gd_img%d_pl%d.s" % (g["img"], pl))
    path.parent.mkdir(parents=True, exist_ok=True)
    SC.convert_one(B.IMG / GD_TABLE, g["img"], path, "g", (1 - pl) ^ (aw & 1), (7 * aw) % 2 == 0, True,
                   trim=True, quiet=True)
    return segs_of(path, g["rk"])


def predict(kst, gst, tile, variants, fore):
    """The step with no history: tile, kid, guard over him, fore. Plus both draws' opaque masks."""
    kh, kw, ksegs = kid_ref(kst)
    gh, gw, gsegs = gd_ref(gst)
    assert kh == kst["h"] and gh == gst["h"]
    fb = lay(tile, kh, kw, ksegs, kst["top"], kst["rcol"])
    fb = lay(fb, gh, gw, gsegs, gst["top"], gst["rcol"])
    zero = bytes(len(tile))
    km = lay(zero, kh, kw, ksegs, kst["top"], kst["rcol"])
    gm = lay(zero, gh, gw, gsegs, gst["top"], gst["rcol"])
    both = [o for o in range(len(tile)) if km[o] and gm[o]]
    return BS.replay_fore(fb, variants, fore), both


def rect(s):
    return [s["top"], s["top"] + s["h"] - 1, s["col"], s["col"] + s["w"] - 1]


def rect_overlap(a, b):
    r0, r1 = max(a[0], b[0]), min(a[1], b[1])
    c0, c1 = max(a[2], b[2]), min(a[3], b[3])
    return max(0, r1 - r0 + 1) * max(0, c1 - c0 + 1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--asm", required=True)
    ap.add_argument("--predict", default="", help="comma-separated step numbers")
    ap.add_argument("--ref-dir", default=str(ROOT / "build/assets"))
    a = ap.parse_args()
    check_sequence()

    sts = kid_steps(120)
    gds = gd_steps(120)
    loop = next(s["step"] for s in sts if s["x"] < XMIN)
    worst_peel = max(s["h"] * s["w"] for s in sts)
    gd_peel = max(g["h"] * g["w"] for g in gds)
    off = [s for s in sts + gds if s["col"] < 0 or s["col"] + s["w"] > STRIDE or s["top"] < 0
           or s["rcol"] < 0]
    print("kidrun_plan: %d steps per lap (wrap after step %d, CharX %d < %d); peel needs <= %d B of %d "
          "(kid), %d B of %d (guard) per page; frames on screen: %s"
          % (loop, loop, sts[loop - 1]["x"], XMIN, worst_peel, WK_PEEL, gd_peel, GD_PEEL,
             "ALL" if not off else off[:2]))
    if worst_peel > WK_PEEL or gd_peel > GD_PEEL or off:
        raise SystemExit(1)
    ov = []
    for s, g in zip(sts[:2 * loop], gds):
        o = rect_overlap(rect(s), rect(g))
        ov.append(o)
        if s["step"] <= loop:
            print("   step %2d  kid frame %2d CharX %3d img %2d PL %d px %3d byte %2d ph %d rows %d..%d | "
                  "guard frame %3d CharX %3d img %2d PL %d px %3d byte %2d ph %d rows %d..%d | frames overlap %3d B"
                  % (s["step"], s["frame"], s["x"], s["img"], s["pl"], s["px"], s["col"], s["k"],
                     s["top"], s["top"] + s["h"] - 1, g["frame"], g["x"], g["img"], g["pl"], g["px"],
                     g["col"], g["k"], g["top"], g["top"] + g["h"] - 1, o))
    olap = [n + 1 for n, o in enumerate(ov) if o]
    print("kidrun_plan: the frames OVERLAP at steps %s (laps 1-2)" % olap)
    if not olap:
        raise SystemExit("kidrun_plan: the kid never overlaps the guard -- P5.32 §5.2 calls that a failed setup")
    print("kidrun_plan: the guard's frames carry Fsword index %s -- SWORDTAB, a separate CHTAB3 sprite, "
          "NOT drawn (P5.32 §8: the sword is out of scope)" % sorted({g["sword"] for g in gds}))

    raw = bytes(XT.table_bytes())
    nv = LZ.decompress_6809(LZ.compress(raw), len(raw))
    print("kidrun_plan: (the tables through the 6809's lz_unpack model would decode %s -- not packed)"
          % ("EXACT" if nv == raw else "WRONG, %d B for %d" % (len(nv), len(raw))))
    gimgs = sorted({g["img"] for g in gds})
    L = ["* GENERATED by harness/tools/kidrun_plan.py -- do not hand-edit.",
         "WK_X0           equ     %d" % X0,
         "WK_XMIN         equ     %d" % XMIN,
         "WK_Y            equ     %d" % Y0,
         "WK_SPEED        equ     %d" % SPEED,
         "WK_NIMG         equ     14",
         "GD_X            equ     %d" % GD_X,
         "GD_NIMG         equ     %d" % GD_NIMG,
         "* image n (CHTAB1 #n) -> its baked stream",
         "wk_img"]
    for n in range(1, 15):
        L.append("                fdb     chtab1_%03d_p0" % n)
    L.append("* image n (CHTAB4.GD #n) -> its baked stream; 0 = not linked into this probe")
    L.append("gd_img")
    for n in range(1, GD_NIMG + 1):
        L.append("                fdb     %s" % (("chtab4gd_%03d_p0" % n) if n in gimgs else "0"))
    L.append("* the frame table follows the code, in prog")
    L.append("                include \"content/chars/frame_table.s\"")
    # the streams into the two spans, first fit
    # P5.31b: kd2 moved $6B00 -> $2000. The probe is now read off raw tracks by its loader
    # (src/boot/kidrun_boot.s), whole tracks only, and no track-sized read can cover $6B00-$77FF
    # without covering the driver's block at $6A00 or the kernel at $7900. At $2000 it rides in
    # read A with prog; $3000 is the staging area / peel, so the span ends there.
    # P5.32: kd3 = $6B00-$77FF again, for the guard's streams (kd1+kd2 have ~700 B left; the guard's
    # three are ~1.4 KB). No whole-track read can land there, so the loader reads ONE track into $3400
    # first, copies the span up, and only then does reads A and B (src/boot/kidrun_boot.s).
    # P5.32: kd2 starts $2200, not $2000 -- the three-pass probe's prog runs to ~$20EC.
    caps = [("kd1", 0x6A00 - 0x6000), ("kd2", 0x3000 - 0x2200), ("kd3", 0x7800 - 0x6B00)]
    used = {s: 0 for s, _ in caps}
    where = {}
    items = [("content/chars/chtab1/chtab1_%03d_p0.s" % n, len(stream_of(n))) for n in range(1, 15)]
    items += [("content/chars/chtab4gd/chtab4gd_%03d_p0.s" % n, len(gd_stream_of(n))) for n in gimgs]
    for path, size in items:
        for s, cap in caps:
            if used[s] + size <= cap:
                used[s] += size
                where.setdefault(s, []).append(path)
                break
        else:
            raise SystemExit("kidrun_plan: stream %s (%d B) fits neither span %r" % (path, size, used))
    for s, _ in caps:
        L += ["                ifdef   OBJTARGET", "                section %s" % s, "                endc"]
        for path in where.get(s, []):
            L.append("                include \"%s\"" % path)
    pathlib.Path(a.asm).parent.mkdir(parents=True, exist_ok=True)
    pathlib.Path(a.asm).write_text("\n".join(L) + "\n", encoding="utf-8", newline="\n")
    print("kidrun_plan: -> %s (streams: kd1 %d B of %d, kd2 %d B of %d, kd3 %d B of %d; guard images %s in %s)"
          % (a.asm, used["kd1"], caps[0][1], used["kd2"], caps[1][1], used["kd3"], caps[2][1], gimgs,
             sorted({s for s, ps in where.items() for p in ps if "chtab4gd" in p})))

    if a.predict:
        _r, variants, _o, _c, fore = BS.bake("LEVEL0", 1, "DUN")
        tile = (ROOT / "build/assets/tile_screen1_ref.bin").read_bytes()
        for n in [int(v) for v in a.predict.split(",")]:
            fb, both = predict(sts[n - 1], gds[n - 1], tile, variants, fore)
            p = pathlib.Path(a.ref_dir) / ("kidrun_ref_%d.bin" % n)
            p.write_bytes(fb)
            meta = dict(step=n, kid_rect=rect(sts[n - 1]), guard_rect=rect(gds[n - 1]),
                        rect_overlap=rect_overlap(rect(sts[n - 1]), rect(gds[n - 1])), both_opaque=both)
            p.with_suffix(".json").write_text(json.dumps(meta))
            print("kidrun_plan: step %d predicted -> %s (%d B differ from the bare page; frames overlap "
                  "%d B, both opaque in %d B)" % (n, p, sum(1 for x, y in zip(fb, tile) if x != y),
                                                  meta["rect_overlap"], len(both)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
