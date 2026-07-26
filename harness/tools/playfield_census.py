#!/usr/bin/env python3
r"""
playfield_census.py — PA.13 recon: how black is POP's playfield where the prince's
silhouette actually sits?

Measures the WORLD, from real data only. No per-cel placement enumeration, no
gameplay trace, no estimating from the armchair.

INPUTS (all vendored, ec78dbf)
  Images/IMG.BGTAB1.DUN, IMG.BGTAB2.DUN   dungeon background image tables
  Images/IMG.BGTAB1.PAL, IMG.BGTAB2.PAL   PALACE tables (.PAL is the palace THEME,
                                          not a palette — cf. EditorDisk "1 = dunj,
                                          2 = palace" and "Add stripe (palace bg set
                                          only)", FRAMEADV.S)
  Levels/LEVEL0..LEVEL14                  the real 15 levels
  Source/BGDATA.S                         piece-ID -> section image tables

FACTS ESTABLISHED FROM SOURCE (code, not comments)
  * Level file layout (EQ.S, `dum blueprnt`):
        BLUETYPE 24*30 | BLUESPEC 24*30 | LINKLOC 256 | LINKMAP 256 | MAP 24*4 | INFO 256
    = 720+720+256+256+96+256 = 2304 bytes, which is exactly the file size.
  * `idmask = %00011111` (EQ.S) masks the piece ID out of a BLUETYPE byte.
  * Screen grid = 10 columns x 3 rows = 30 blocks (FRAMEADV: colno 0-9, rowno 0-2).
  * Block = 4 BYTES wide (XCO = colno*4, FRAMEADV) = 28 px; BlockHeight = 63 lines,
    DHeight = 3 (TABLES.S). Cross-checks against TABLES.S BlockTable, which spans
    14 units/block in the 140-res coordinate system = 28 px in 280-res.
  * Section placement (BGDATA.S): "A & B sections have l.l. of (X = BlockLeft,
    Y = BlockBot-3); C & D sections have l.l. of (X = BlockLeft, Y = BlockBot)".
    So D is the 3-line floor slab at the block bottom and **A is the section
    occupying the band immediately above the floor — the band the prince's body
    stands in**. That is the contact zone this census measures.
  * Image ID decode (GRAFIX.S:828): `lda IMAGE / bpl :bg1 / and #$7f` — bit 7
    selects bgtable2, low **7** bits are the index. (The comment at GRAFIX.S:199
    says "low 6 bits"; the code says $7f. CLAUDE.md §2 ranks comments lowest.)

WHAT IS "BLACK"
  POP's Apple II backgrounds are 1bpp HGR masks: a pixel is ON (lit) or OFF. OFF is
  black — there is no separate black index. So "black" = pixel not set, and a region
  with no piece drawn over it at all is black by construction.

Usage:  python harness/tools/playfield_census.py
"""
import pathlib
import re
import collections

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
SRC = ROOT / "oracle" / "source" / "01 POP Source"
IMAGES, LEVELS = SRC / "Images", SRC / "Levels"

# BOTH tables' pointers are relative to $6000 IN THE FILE. GAMEEQ.S's
# `bgtable2 = $8400` is the RUNTIME load address, not the file's pointer base —
# verified by reading IMG.BGTAB2.DUN's own pointer table (first ptr $6069, which
# lands just past its 103-byte header). Decoding BGTAB2 at $8400 silently yields
# ZERO images and every $8x-$Ax piece then reads as 0% coverage.
BGTABLE1_BASE, BGTABLE2_BASE = 0x6000, 0x6000
BLOCK_W_BYTES, BLOCK_H, DHEIGHT = 4, 63, 3
COLS, ROWS, SCREENS = 10, 3, 24
IDMASK = 0x1F
PRINCE_H = 41            # tallest kid cel measured in P1.2 (CHTAB1 #40, 41 lines)

PIECE_NAMES = ["space","floor","spikes","posts","gate","dpressplate","pressplate",
               "panelwif","pillarbottom","pillartop","flask","loose","panelwof",
               "mirror","rubble","upressplate","exit","exit2","slicer","torch",
               "block","bones","sword","window","window2","archbot","archtop1",
               "archtop2","archtop3","archtop4"]


# ---------------------------------------------------------------- image tables
def load_table(path, base):
    """POP image table: [count][ptr lo,hi]*count then records [w][h][w*h bytes]."""
    b = path.read_bytes()
    n = b[0]
    out = {}
    for i in range(1, n + 1):
        p = 1 + 2 * (i - 1)
        off = (b[p] | (b[p + 1] << 8)) - base
        if not (0 <= off < len(b) - 1):
            continue
        w, h = b[off], b[off + 1]
        data = b[off + 2: off + 2 + w * h]
        if len(data) == w * h and w and h:
            out[i] = dict(w=w, h=h, data=data)
    return out


def ink(img):
    """Count ON (lit) pixels. HGR: 7 px per byte, bit7 is the colour-set flag."""
    return sum(bin(x & 0x7F).count("1") for x in img["data"])


def resolve(imgid, t1, t2):
    """IMAGE byte -> the image record. Bit 7 selects bgtable2; low 7 bits index."""
    if imgid == 0:
        return None
    tab, idx = (t2, imgid & 0x7F) if imgid & 0x80 else (t1, imgid)
    return tab.get(idx)


# ---------------------------------------------------------------- BGDATA tables
def bgdata_tables():
    """Parse the piece-ID-indexed hex/dfb tables out of BGDATA.S."""
    txt = (SRC / "Source" / "BGDATA.S").read_text(errors="replace")
    want = ("maska", "piecea", "pieceay", "maskb", "pieceb", "pieceby",
            "piecec", "pieced", "fronti", "fronty", "frontx")
    tables, cur = {}, None
    for line in txt.splitlines():
        s = line.split(";", 1)[0].rstrip()
        m = re.match(r"^(\w+)\s+(hex|dfb)\s+(.*)$", s)
        if m and m.group(1) in want:
            cur = m.group(1); tables[cur] = []
            payload, kind = m.group(3), m.group(2)
        else:
            m2 = re.match(r"^\s+(hex|dfb)\s+(.*)$", s)
            if m2 and cur:
                payload, kind = m2.group(2), m2.group(1)
            else:
                if s and not s.startswith(" ") and not s.startswith("*"):
                    cur = None
                continue
        for v in payload.split(","):
            v = v.strip()
            if not v:
                continue
            tables[cur].append(int(v, 16) if kind == "hex" else int(v, 10))
    return tables


# ---------------------------------------------------------------- levels
def level_blocks():
    """Every block's piece ID across all levels. Returns Counter and a per-level grid."""
    counts = collections.Counter()
    grids = {}
    for p in sorted(LEVELS.glob("LEVEL*"), key=lambda q: int(q.name[5:])):
        b = p.read_bytes()
        assert len(b) == 2304, f"{p.name}: {len(b)} bytes, expected 2304"
        bluetype = b[0:720]
        g = []
        for scr in range(SCREENS):
            blocks = [bluetype[scr * 30 + i] & IDMASK for i in range(30)]
            g.append([blocks[r * COLS:(r + 1) * COLS] for r in range(ROWS)])
            counts.update(blocks)
        grids[p.name] = g
    return counts, grids


# ---------------------------------------------------------------- the census
def main():
    print("=== PA.13 — POP playfield blackness census (real data only) ===\n")

    themes = {}
    for name, suffix in (("DUNGEON", "DUN"), ("PALACE", "PAL")):
        t1 = load_table(IMAGES / f"IMG.BGTAB1.{suffix}", BGTABLE1_BASE)
        t2 = load_table(IMAGES / f"IMG.BGTAB2.{suffix}", BGTABLE2_BASE)
        themes[name] = (t1, t2)
        print(f"  {name:<8} bgtable1: {len(t1):3d} images   bgtable2: {len(t2):3d} images")

    bg = bgdata_tables()
    for k in ("piecea", "pieced", "fronti"):
        print(f"  BGDATA {k:<8}: {len(bg[k])} entries")
    counts, grids = level_blocks()
    total_blocks = sum(counts.values())
    print(f"  levels    : {len(grids)} x {SCREENS} screens x 30 blocks = {total_blocks:,} real blocks\n")

    # ---- 1. what does each piece type draw in the PRINCE BODY BAND (A section)? ----
    print("=== 1. Per-piece-type: what occupies the prince's body band (A-section)? ===")
    print("    A-section lower-left = (BlockLeft, BlockBot-3), i.e. directly above the floor slab.")
    print(f"    Block is {BLOCK_W_BYTES*7} px wide x {BLOCK_H} lines; prince cel is up to {PRINCE_H} lines.\n")
    print(f"    {'id':>3} {'piece':<14}{'A img':>7}{'A dims':>10}{'A ink%':>8}"
          f"{'band cover%':>12}   {'blocks in levels':>17}")
    rows = []
    for pid in range(30):
        name = PIECE_NAMES[pid]
        a = bg["piecea"][pid]
        img = resolve(a, *themes["DUNGEON"])
        n = counts.get(pid, 0)
        band_px = BLOCK_W_BYTES * 7 * PRINCE_H
        # RedBlockSure (FRAMEADV.S) draws, for each block: own A, own D, the LEFT
        # neighbour's B, the below-left's C, and the A front piece. The band above a
        # block's floor is therefore inked by A + B(from the left neighbour) + front.
        # Charging B to its OWN piece id is the right aggregate: every block both
        # donates a B rightward and receives one leftward, so the world-weighted
        # total is unchanged.
        contrib = [bg["piecea"][pid], bg["pieceb"][pid], bg["fronti"][pid]]
        tot_ink = sum(ink(im) for im in (resolve(c, *themes["DUNGEON"]) for c in contrib) if im)
        if img is None:
            dims, inkpct = "-", 0.0
        else:
            px = img["w"] * 7 * img["h"]
            dims = f"{img['w']*7}x{img['h']}"
            inkpct = 100 * ink(img) / px
        cover = 100 * tot_ink / band_px
        rows.append((pid, name, a, dims, inkpct, cover, n))
        print(f"    {pid:>3} {name:<14}{('$%02X'%a) if a else '  -':>7}{dims:>10}"
              f"{inkpct:>7.1f}%{cover:>11.1f}%   {n:>17,}")

    # ---- 2. weight by REAL level block frequency -------------------------------
    print("\n=== 2. Weighted by the REAL world (all 15 levels, every screen) ===")
    print(f"    {'rank':>4} {'piece':<14}{'blocks':>9}{'% of world':>12}{'band cover%':>13}")
    cum = 0.0
    for i, (pid, n) in enumerate(counts.most_common(10), 1):
        r = next(x for x in rows if x[0] == pid)
        pct = 100 * n / total_blocks
        cum += pct
        print(f"    {i:>4} {PIECE_NAMES[pid]:<14}{n:>9,}{pct:>11.1f}%{r[5]:>12.1f}%")
    print(f"         (top 10 = {cum:.1f}% of all blocks)")

    weighted_cover = sum(counts.get(r[0], 0) * r[5] for r in rows) / total_blocks
    print(f"\n    WEIGHTED band ink coverage across the whole world: {weighted_cover:.2f}%")
    print(f"    => prince body band is {100-weighted_cover:.2f}% BLACK by area")

    # ---- 3. the sharper number: what is DIRECTLY BEHIND a standing prince? -----
    # He stands on a block whose D-section is a floor. His body occupies that same
    # block's A band. So: over blocks that can be stood on, how black is the band?
    print("\n=== 3. Contact-zone census: blocks the prince can STAND ON ===")
    standable = [pid for pid in range(30) if bg["pieced"][pid] != 0]
    print(f"    'standable' = piece has a D-section (floor slab) drawn: "
          f"{len(standable)} of 30 types")
    sn = sum(counts.get(p, 0) for p in standable)
    print(f"    {sn:,} of {total_blocks:,} blocks ({100*sn/total_blocks:.1f}%) are standable")
    if sn:
        wc = sum(counts.get(p, 0) * next(x[5] for x in rows if x[0] == p) for p in standable) / sn
        print(f"    band ink coverage over standable blocks: {wc:.2f}%"
              f"  =>  {100-wc:.2f}% BLACK")

    # ---- 4. per-theme cross-check ---------------------------------------------
    print("\n=== 4. Palace theme cross-check (same piece IDs, different art) ===")
    for tname in ("DUNGEON", "PALACE"):
        tot = cnt = 0
        for pid in range(30):
            n = counts.get(pid, 0)
            if n == 0:
                continue
            band_px = BLOCK_W_BYTES * 7 * PRINCE_H
            ti = sum(ink(im) for im in
                     (resolve(c, *themes[tname]) for c in
                      (bg["piecea"][pid], bg["pieceb"][pid], bg["fronti"][pid])) if im)
            tot += n * 100 * ti / band_px
            cnt += n
        print(f"    {tname:<8} weighted band ink {tot/cnt:6.2f}%  =>  {100-tot/cnt:6.2f}% BLACK")


if __name__ == "__main__":
    main()
