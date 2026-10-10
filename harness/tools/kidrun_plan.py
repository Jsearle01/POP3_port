#!/usr/bin/env python3
r"""kidrun_plan.py — P5.31: the walking kid's sequence CHECKED, its data EMITTED, its steps PREDICTED.

1. THE SEQUENCE, TWO WAYS (verify_sequences.py's principle -- a check whose two sides share a
   derivation agrees with itself when wrong). src/engine/kidrun_probe.s carries `startrun`
   TRANSCRIBED BY HAND; seq_graph.parse_seqtable() reads SEQTABLE.S itself, with ANIMCHAR's
   operand counts. Both are walked with ANIMCHAR's semantics (opcodes precede the frame they
   affect; chx := CharX - delta facing left [ADDCHARX, CTRLSUBS.S:353]) for WALK_CHECK steps and
   must emit the same (frame, CharX) every step, or this exits 1.
2. THE ORACLE'S TRACE. P5.21's oracle_step_trace.lua logged the demo's kid at every game frame;
   at display frame 7949 he starts `startrun` from CharX 191, CharY 55, facing left, on LEVEL0
   screen 1 -- the walk starts there. The positions for frames 1..11 are checked against ORACLE
   (transcribed from build/tmp/oracle_step_trace.txt below) and, if that file is present, against
   the file itself.
3. THE DATA: build/gen/kidrun_gen.s -- the equates, the image -> stream table, the 14 run cels'
   baked streams and the frame table (section wkdata), and xf_blit's tables PACKED (wkdata2;
   kidrun_probe.s expands them with the shipped lz_unpack).
4. THE PREDICTION, at the steps --predict names: the tile reference, the kid drawn at that step's
   position (from seq_graph's walk, NOT the transcription) with a REFERENCE stream coloured where
   the ORACLE draws him (sprite_convert at a column of parity PL, P5.29), then the page's
   foreground list replayed over him. A peel error -- anything a previous step left behind -- is a
   difference against this, because the prediction has no history at all.
   ★ What it is worth: the runtime equals this composition at those steps. Whether the run LOOKS
   right in motion -- cadence, smoothness -- is Jay's, live (CLAUDE.md §4).
"""
import argparse
import pathlib
import re
import struct
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
WALK_CHECK = 80
WK_PEEL = 400
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


def transcription():
    """kidrun_probe.s's hand-written `startrun`, as tokens."""
    text = SRC.read_text(encoding="utf-8").splitlines()
    i = next(n for n, l in enumerate(text) if l.startswith("wk_startrun"))
    toks, labels = [], {}
    for l in text[i:]:
        s = l.split(";")[0]
        m = re.match(r"^(wk_\w+)\s+(.*)$", s)
        if m:
            labels[m.group(1)] = len(toks)
            s = " " + m.group(2)
        s = s.strip()
        if s.startswith("fcb"):
            for t in s[3:].split(","):
                t = t.strip()
                toks.append(("op", t) if t.startswith("SEQ_") else ("num", int(t)))
        elif s.startswith("fdb"):
            toks.append(("addr", s[3:].strip()))
            break
    return toks, labels


def walk(toks, labels, start, nsteps, opname):
    """ANIMCHAR over a token list. opname maps a token's op to goto/chx/act/tap."""
    i, x, out = labels[start], X0, []
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
            x = (x - toks[i + 1][1]) & 0xFF
            i += 2
        elif op in ("act", "tap"):
            i += 2
        else:
            raise SystemExit("walk: opcode %r is not implemented by kidrun_probe.s" % (v,))
    return out


def check_sequence():
    tt, tl = transcription()
    mine = walk(tt, tl, "wk_startrun", WALK_CHECK,
                lambda v: {"SEQ_GOTO": "goto", "SEQ_CHX": "chx", "SEQ_ACT": "act", "SEQ_TAP": "tap"}[v])
    items, labels, entries = SG.parse_seqtable()
    assert entries[1] == "startrun"
    ref = walk(items, labels, "startrun", WALK_CHECK, lambda v: v)
    bad = [(n, a, b) for n, (a, b) in enumerate(zip(mine, ref)) if a != b]
    print("kidrun_plan: `startrun` -- hand transcription vs seq_graph's parse of SEQTABLE.S, %d steps: %s"
          % (WALK_CHECK, "IDENTICAL" if not bad else "DIVERGE at %r" % bad[:3]))
    if bad:
        raise SystemExit(1)
    obad = [(f, x, ref[n]) for n, (f, x, _fr) in enumerate(ORACLE) if ref[n] != (f, x)]
    print("kidrun_plan: positions vs the ORACLE's trace (frames 1..11, display frames %d..%d): %s"
          % (ORACLE[0][2], ORACLE[-1][2], "IDENTICAL" if not obad else "DIFFER %r" % obad))
    if obad:
        raise SystemExit(1)
    tr = ROOT / "build/tmp/oracle_step_trace.txt"
    if tr.exists():
        got = []
        for line in tr.read_text().splitlines():
            m = re.match(r"^F (\d+) K=([0-9A-F]{4})", line)
            if m and ORACLE[0][2] <= int(m.group(1)) < ORACLE_NEXT:
                got.append((int(m.group(2)[:2], 16), int(m.group(2)[2:], 16), int(m.group(1))))
        print("kidrun_plan: ... and against build/tmp/oracle_step_trace.txt itself: %s"
              % ("IDENTICAL" if got == ORACLE else "DIFFER %r" % got))
        if got != ORACLE:
            raise SystemExit(1)
    durs = [b[2] - a[2] for a, b in zip(ORACLE, ORACLE[1:] + [(0, 0, ORACLE_NEXT)])]
    print("kidrun_plan: the oracle held frames 1..11 for %s display frames (mean %.2f -> %.2f fps)"
          % (durs, sum(durs) / len(durs), 60.0 * len(durs) / sum(durs)))
    return ref


def frame_row(f):
    fi, fs, fdx, fdy, fc = R.frame_table("Fdef")[f]
    slot, img = R.decode_table(fi, fs)
    return slot, img, fdx, fdy, fc


def stream_of(img):
    return B.fcb_values(ROOT / "content/chars/chtab1" / ("chtab1_%03d_p0.s" % img))


def steps(n):
    """The walk with the harness's wrap, as kidrun_probe.s runs it: positions from seq_graph."""
    items, labels, _ = SG.parse_seqtable()
    out, seq = [], []
    while len(out) < n:
        if not seq:
            seq = walk(items, labels, "startrun", 400, lambda v: v)
        f, x = seq.pop(0)
        slot, img, fdx, fdy, fc = frame_row(f)
        assert slot == 0 and 1 <= img <= 14, (f, slot, img)
        pl = R.parity(fc, R.FACE_LEFT)
        px = 20 + 2 * (x - fdx - 58) + pl
        s = stream_of(img)
        h, w0 = s[0], s[1]
        k, col = px % 4, px // 4
        top = Y0 + fdy - h + 1
        w = w0 + (1 if k else 0)
        out.append(dict(step=len(out) + 1, frame=f, x=x, img=img, pl=pl, px=px, col=col, k=k,
                        top=top, h=h, w=w))
        if x < XMIN:
            seq = []
    return out


def predict(st, fb, variants, fore):
    """The kid at this step, from a REFERENCE stream coloured at the oracle's parity, then fore."""
    path = WORK / ("kidrun_ref_img%d_pl%d.s" % (st["img"], st["pl"]))
    path.parent.mkdir(parents=True, exist_ok=True)
    SC.convert_one(B.IMG / "IMG.CHTAB1", st["img"], path, "r", st["pl"], False, False, trim=True, quiet=True)
    cel = Cel(str(path))
    rows, w = P.shift_pixels(cel, st["k"])
    segs = []
    for r in range(cel.h):
        segs += P.encode_row(rows[r], w)
    base = st["top"] * STRIDE + st["col"]
    init = {o - base: v for o, v in enumerate(fb)}
    out = P.simulate(segs, cel.h, w, STRIDE, initial=init)
    fb2 = bytes(out[o - base] for o in range(len(fb)))
    return BS.replay_fore(fb2, variants, fore)


def fcb(vals):
    vals = list(vals)
    return ["                fcb     " + ",".join("$%02X" % v for v in vals[i:i + 16])
            for i in range(0, len(vals), 16)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--asm", required=True)
    ap.add_argument("--predict", default="", help="comma-separated step numbers")
    ap.add_argument("--ref-dir", default=str(ROOT / "build/assets"))
    a = ap.parse_args()
    check_sequence()

    sts = steps(120)
    loop = next(s["step"] for s in sts if s["x"] < XMIN)
    worst_peel = max(s["h"] * s["w"] for s in sts)
    off = [s for s in sts if s["col"] < 0 or s["col"] + s["w"] > STRIDE or s["top"] < 0]
    print("kidrun_plan: %d steps per lap (wrap after step %d, CharX %d < %d); peel needs <= %d B "
          "of %d per page; frames on screen: %s"
          % (loop, loop, sts[loop - 1]["x"], XMIN, worst_peel, WK_PEEL, "ALL" if not off else off[:2]))
    if worst_peel > WK_PEEL or off:
        raise SystemExit(1)
    for s in sts[:loop]:
        print("   step %2d frame %2d CharX %3d img %2d PL %d -> port px %3d = byte %2d phase %d, rows %d..%d"
              % (s["step"], s["frame"], s["x"], s["img"], s["pl"], s["px"], s["col"], s["k"],
                 s["top"], s["top"] + s["h"] - 1))

    # ★ THE TABLES ARE NOT PACKED. The first build of this probe packed them and expanded them with
    # the shipped lz_unpack, and the 6809 ran its writer past the end into its own blob: lz_unpack
    # copies a count of 256*k as 256*(k+1) (lz_pack.decompress_6809). Recorded, measured against
    # every shipped asset (all exact), and routed around: the tables link raw at $4200 as in the
    # character probe, and the streams split across the two LOADM-safe spans left.
    raw = bytes(XT.table_bytes())
    nv = LZ.decompress_6809(LZ.compress(raw), len(raw))
    print("kidrun_plan: (the tables through the 6809's lz_unpack model would decode %s -- not packed)"
          % ("EXACT" if nv == raw else "WRONG, %d B for %d" % (len(nv), len(raw))))
    L = ["* GENERATED by harness/tools/kidrun_plan.py -- do not hand-edit.",
         "WK_X0           equ     %d" % X0,
         "WK_XMIN         equ     %d" % XMIN,
         "WK_Y            equ     %d" % Y0,
         "WK_SPEED        equ     %d" % SPEED,
         "WK_NIMG         equ     14",
         "* image n (CHTAB1 #n) -> its baked stream",
         "wk_img"]
    for n in range(1, 15):
        L.append("                fdb     chtab1_%03d_p0" % n)
    L.append("* the frame table follows the code, in prog")
    L.append("                include \"content/chars/frame_table.s\"")
    # the 14 streams into the two spans, first fit in image order
    # P5.31b: kd2 moved $6B00 -> $2000. The probe is now read off raw tracks by its loader
    # (src/boot/kidrun_boot.s), whole tracks only, and no track-sized read can cover $6B00-$77FF
    # without covering the driver's block at $6A00 or the kernel at $7900. At $2000 it rides in
    # read A with prog; $3000 is the staging area / peel, so the span ends there.
    caps = [("kd1", 0x6A00 - 0x6000), ("kd2", 0x3000 - 0x2000)]
    used = {s: 0 for s, _ in caps}
    where = {}
    for n in range(1, 15):
        size = len(stream_of(n))
        for s, cap in caps:
            if used[s] + size <= cap:
                used[s] += size
                where.setdefault(s, []).append(n)
                break
        else:
            raise SystemExit("kidrun_plan: stream %d (%d B) fits neither span %r" % (n, size, used))
    for s, _ in caps:
        L += ["                ifdef   OBJTARGET", "                section %s" % s, "                endc"]
        for n in where.get(s, []):
            L.append("                include \"content/chars/chtab1/chtab1_%03d_p0.s\"" % n)
    pathlib.Path(a.asm).parent.mkdir(parents=True, exist_ok=True)
    pathlib.Path(a.asm).write_text("\n".join(L) + "\n", encoding="utf-8", newline="\n")
    print("kidrun_plan: -> %s (streams: kd1 %d B of %d, kd2 %d B of %d)"
          % (a.asm, used["kd1"], caps[0][1], used["kd2"], caps[1][1]))

    if a.predict:
        _r, variants, _o, _c, fore = BS.bake("LEVEL0", 1, "DUN")
        tile = (ROOT / "build/assets/tile_screen1_ref.bin").read_bytes()
        for n in [int(v) for v in a.predict.split(",")]:
            fb = predict(sts[n - 1], tile, variants, fore)
            p = pathlib.Path(a.ref_dir) / ("kidrun_ref_%d.bin" % n)
            p.write_bytes(fb)
            print("kidrun_plan: step %d predicted -> %s (%d B differ from the bare page)"
                  % (n, p, sum(1 for x, y in zip(fb, tile) if x != y)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
