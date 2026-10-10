#!/usr/bin/env python3
r"""bake_chars.py — P5.27: the gameplay character bake. Promotes P5.20's references into content.

WHAT IT WRITES (content/chars/, every file GENERATED -- re-run this, do not hand-edit):

  <tab>/<tab>_<nnn>_src.s   sprite_convert output, start_col 0, trailing trim only. The PIXEL
                            home (CLAUDE.md §2F): the one file a cel's pixels live in.
  <tab>/<tab>_<nnn>_p0.s    cel_blit_prep phase 0 of that file: the SEGMENT STREAM, facing 0,
                            phase 0. ★ THE SHIPPING ARTIFACT: the runtime transform (P5.20's
                            xf_blit) draws every phase and both facings from this one stream.
                            ★ P5.33: WITH THE ORACLE'S MASK BORDER BAKED IN (border_rows): the
                            pixels the oracle's MASKTAB clears are OPAQUE BLACK merge pairs. The
                            _src.s pixel file is unchanged and carries no border; the border is a
                            draw rule computed here from the Apple source bytes.

★★★ TWO BAKES, TWO TRANSPARENCY MODELS -- READ THIS BEFORE ASSUMING THEY AGREE (P5.33, Jay's ruling
2026-10-10: "fix gameplay, leave the cutscene"). THIS bake (gameplay, content/chars) draws a
character the oracle's way: MLayMask, a one-pixel black border inside each 7-px source byte, small
interior gaps filled. The CUTSCENE's bake (content/cutscene, bake_scene.py / bake_walk.py /
cel_table.py) still treats index 0 as transparent with no border (P3.18 §3B) -- it is gated and
shipped, and the gap is invisible in its content. The same cel baked by both is NOT the same
stream. Revisit the cutscene when it is touched for another reason, and move the lz_unpack
256-count fix (§5.412) in that same change: both move prod.
  char_cels.s               the REGISTRY: per table, one byte per image slot = apple_w, the
                            Apple width in 7-px bytes (0 = empty slot). See APPLE_W below.

★★★ THIS IS NOT A NEW CONVERSION. It is exactly the path P5.20's generator ran for its
reference [xform_probe_gen.py: convert(..., start_col, False, False) -> stream(cel, 0)]:
same tool, same start_col (0, the generator's default -- and P1.2's source-derived default,
"a character's base column is always even"), same trailing trim, same encoder and the same
self-replay. P5.20's probe then matched the runtime transform of that stream byte-exact on
4,640 cases. Baking the same bytes inherits that result; --verify re-proves it against the
P5.20 artifacts themselves rather than against this code's own output.

★★ APPLE_W, AND WHY IT IS A SIDE TABLE. An integrated mirror needs the pad
d = 4*w0 - 7*apple_w per cel [P5.20 §3B]; the parity swap needs (7*apple_w) even. Both derive
from apple_w, and w0 is already the stream's own width byte, so apple_w is the one missing
fact. It is stored as the SOURCE fact rather than as d because (a) it is the precedent --
content/cutscene/cel_table.s carries "Apple sprite WIDTH in bytes ... the mirror anchor" at
+4, P3.72g, for the same reason; (b) d loses it: d and w0 give 7*apple_w back only through
the stream header, and the anchor arithmetic HIRES.S:1202-1208 does is in Apple widths; (c)
the cost of deriving d at run time is one 7x (shift/subtract) per draw, against a peel and a
blit of thousands of cycles. It lives in a side table, NOT a third header byte: the header
is the format blit_cel parses (P3.85) and the cutscene ships in it, so a third byte would
touch a shipped format for no saving -- one byte per cel either way.

  python harness/tools/bake_chars.py [--tables gameplay|guards|all] [--verify] [--measure]
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
from celio import Cel                                       # noqa: E402

IMG = ROOT / "oracle/source/01 POP Source/Images"
OUT = ROOT / "content/chars"
START_COL = 0

# P5.20's 290: "every non-empty cel of CHTAB1/2/3/4.GD/5" [xform_probe_gen.py --all-gameplay]
GAMEPLAY = ("IMG.CHTAB1", "IMG.CHTAB2", "IMG.CHTAB3", "IMG.CHTAB4.GD", "IMG.CHTAB5")
# The other levels' guards (§5.341 reserved tracks 23-27 for them as ESTIMATES).
GUARDS = ("IMG.CHTAB4.FAT", "IMG.CHTAB4.SHAD", "IMG.CHTAB4.SKEL", "IMG.CHTAB4.VIZ")


def short(table):
    """IMG.CHTAB4.GD -> chtab4gd: the same key xform_probe_gen's tags use."""
    return table.replace("IMG.", "").replace(".", "").lower()


def p520_tag(table, idx):
    return "c_%s_%d" % (short(table), idx)


def cels_of(table):
    return [c for c in SC.load_chtable(IMG / table) if c is not None and c["w"] and c["h"]]


def slots_of(table):
    return len(SC.load_chtable(IMG / table))


BORDER = 4      # P5.33: a pixel the oracle's MASK clears -- OPAQUE BLACK. Never stored in a cel file.


def border_rows(raw, cel):
    """P5.33 -- THE ORACLE'S CHARACTER MASK, BAKED. The oracle draws every character with
    OPACITY = mask [DrawNormal, GAMEBG.S:432-437]: screen := (screen AND MASKTAB[byte]) OR image
    [LayMask, HIRES.S:945-961], and MASKTAB clears each lit bit AND one either side, within the
    character's own 7-pixel SOURCE byte [HRTABLES.S:219-234]. So a pixel the cel leaves at 0 but the
    mask clears is OPAQUE BLACK, not transparent.

    Computed here by ARITHMETIC -- (b | b<<1 | b>>1) per source byte -- not by reading MASKTAB:
    the predictions (char_mask.py) read MASKTAB literally, so the two routes check each other.
    The pixel grid is the Apple's 1:1 (sprite_convert: column byte*7+bit), bottom-up rows flipped.

    Returns visual rows of pixel values: the cel's colour (1-3), BORDER (opaque black), or 0
    (transparent), widened past the trailing trim where the border reaches beyond it."""
    aw, h, data = raw["w"], raw["h"], raw["data"]
    width = max(4 * cel.w, ((7 * aw + 3) // 4) * 4)
    out = []
    for vr in range(h):
        d = h - 1 - vr
        src = data[d * aw:(d + 1) * aw]
        row = list(cel.pixels[vr]) + [0] * (width - len(cel.pixels[vr]))
        for p in range(aw):
            b = src[p] & 0x7F
            dil = (b | (b << 1) | (b >> 1)) & 0x7F
            for i in range(7):
                c = 7 * p + i
                if (dil >> i) & 1 and row[c] == 0:
                    row[c] = BORDER
        out.append(row)
    # the stream's width: the rightmost byte holding anything opaque (trailing trim, as before)
    used = max((c // 4 for r in out for c, v in enumerate(r) if v), default=0) + 1
    return [r[:4 * used] for r in out], used


def stream_bytes(cel, raw):
    """[h, w] + segments: cel_blit_prep's encoder, phase 0, with a replay of its own as a gate.
    P5.33: the rows carry BORDER pixels; encode_row needs no change -- classify() counts any
    non-zero pixel as opaque, pack_row() masks it with &3 (BORDER -> 0, black), and a merge keeps
    the destination only where the pixel is 0 -- so a border pixel is a merge pair's mask bits
    CLEARED and src bits ZERO. Index 0 still means transparent to the blitter."""
    rows, w = border_rows(raw, cel)
    segs = []
    for r in range(cel.h):
        segs += P.encode_row(rows[r], w)
    # replay over a hostile background: colour -> colour, BORDER -> 0, 0 -> background
    bg = {r * 80 + c: 0xB4 for r in range(cel.h) for c in range(w)}
    fb = P.simulate(segs, cel.h, w, initial=bg)
    for r in range(cel.h):
        for c in range(w):
            exp = 0
            for k in range(4):
                v = rows[r][c * 4 + k]
                sh = 6 - 2 * k
                exp |= ((v & 3) if v else ((0xB4 >> sh) & 3)) << sh
            if fb.get(r * 80 + c, 0xB4) != exp:
                raise SystemExit("%s: stream failed its own replay at row %d byte %d" % (cel.label, r, c))
    return cel, w, segs


def fcb_values(path):
    """Every byte an fcb-only .s file assembles to, in order (xform_probe_gen.fcb_values)."""
    vals = []
    for line in pathlib.Path(path).read_text().splitlines():
        s = line.split(";")[0].strip()
        if s.lower().startswith("fcb"):
            for tok in s[3:].split(","):
                tok = tok.strip()
                vals.append(int(tok[1:], 16) if tok.startswith("$") else int(tok))
    return vals


def bake(tables):
    """-> list of per-cel records, in table/index order."""
    recs = []
    for table in tables:
        t = short(table)
        for c in cels_of(table):
            stem = "%s_%03d" % (t, c["idx"])
            d = OUT / t
            d.mkdir(parents=True, exist_ok=True)
            src = d / ("%s_src.s" % stem)
            SC.convert_one(IMG / table, c["idx"], src, "%s_src" % stem, START_COL,
                           False, False, trim=True, quiet=True)
            cel = Cel(str(src))
            cel_, w, segs = stream_bytes(cel, SC.get_cel(IMG / table, c["idx"]))
            p0 = d / ("%s_p0.s" % stem)
            # ★ encoding EXPLICIT: emit_asm's header carries an em dash, and write_text's
            # default is the locale's (cp1252 here: one byte 0x97, not UTF-8's three), so
            # the same bake would produce different bytes on a different machine.
            p0.write_text(P.emit_asm("%s_p0" % stem, cel, 0, segs, w), encoding="utf-8",
                          newline="\n")
            recs.append(dict(table=table, t=t, idx=c["idx"], stem=stem, apple_w=c["w"],
                             h=cel.h, w0=w, d=4 * w - 7 * c["w"],
                             src=src.relative_to(ROOT).as_posix(),
                             p0=p0.relative_to(ROOT).as_posix(), nbytes=2 + len(segs)))
    return recs


def registry(recs, tables):
    by = {}
    for r in recs:
        by.setdefault(r["table"], {})[r["idx"]] = r
    L = ["* char_cels.s — the gameplay character REGISTRY (P5.27).",
         "* GENERATED by harness/tools/bake_chars.py — do not hand-edit.",
         "*",
         "* Per table: <tab>_n = image slots; <tab>_aw = one byte per slot, 1-based image n at",
         "* offset n-1, holding APPLE_W -- the cel's Apple width in 7-px bytes (0 = empty slot).",
         "*",
         "* ★ APPLE_W IS THE MIRROR'S PAD, NOT A SIZE. The runtime mirror reverses all 4*w0 px of",
         "* the stored frame (w0 = the stream header's width byte); the bake's mirror reverses the",
         "* 7*apple_w it converted. The draw sits d = 4*w0 - 7*apple_w px left [P5.20 §3B], and the",
         "* blue<->orange swap applies iff 7*apple_w is even [bake_scene.py:626-631]. Same fact,",
         "* same reason, as content/cutscene/cel_table.s +4 (P3.72g).",
         "*",
         "* Each cel's pixels live in <tab>/<tab>_<nnn>_src.s (§2F) and its shipping stream in",
         "* <tab>/<tab>_<nnn>_p0.s (facing 0, phase 0). Row comments: file, h x w0, apple_w, d.",
         ""]
    for table in tables:
        t = short(table)
        n = slots_of(table)
        L.append("%s_n           equ     %d" % (t, n))
        L.append("%s_aw" % t)
        for i in range(1, n + 1):
            r = by.get(table, {}).get(i)
            if r:
                L.append("        fcb     %d      ; #%-3d %s  %dx%d  aw=%d d=%+d"
                         % (r["apple_w"], i, pathlib.PurePosixPath(r["p0"]).name, r["h"], r["w0"],
                            r["apple_w"], r["d"]))
            else:
                L.append("        fcb     0      ; #%-3d (empty slot)" % i)
        L.append("")
    (OUT / "char_cels.s").write_text("\n".join(L), encoding="utf-8", newline="\n")


def main():
    ap = argparse.ArgumentParser(description="P5.27 character bake")
    ap.add_argument("--tables", choices=("gameplay", "guards", "all"), default="all")
    a = ap.parse_args()
    tables = {"gameplay": GAMEPLAY, "guards": GUARDS, "all": GAMEPLAY + GUARDS}[a.tables]
    recs = bake(tables)
    registry(recs, tables)
    (ROOT / "build/chars").mkdir(parents=True, exist_ok=True)
    (ROOT / "build/chars/bake.json").write_text(json.dumps(recs))
    for table in tables:
        rs = [r for r in recs if r["table"] == table]
        print("bake_chars: %-16s %3d cels  %6d stream B" % (table, len(rs), sum(r["nbytes"] for r in rs)))
    print("bake_chars: %d cels -> %s" % (len(recs), OUT.relative_to(ROOT)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
