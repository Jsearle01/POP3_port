#!/usr/bin/env python3
r"""bg_compose.py - P5.0. POP's background renderer, offline, into an Apple HGR page.

WHAT THIS IS FOR. The dispatch asks for the demo level's static background rendered in
4-colour. The port has no tile renderer, and acquiring the room as a picture (the route
P3.2 and P3.17 took for the cutscene) does not scale: 24 screens x 15,360 B is 368 KB.
So the room is COMPOSED from the oracle's own tile data here, offline, and the composition
is then checked BYTE FOR BYTE against the running oracle's HGR page.

★★★ THE CHECK IS THE POINT, NOT THE PICTURE. A compositor that "looks about right" is the
exact failure P1.2 recorded: 1152/1152 pixels passed on upside-down cels because both
sides of that comparison were downstream of the same converter. Here the reference is the
oracle's own framebuffer, dumped out of MAME (harness/tools/oracle_demo_bg.lua) - outside
this pipeline entirely. If this file's arithmetic is wrong, the diff says so.

WHAT IT IMPLEMENTS, AND FROM WHERE - all oracle source, all cited:
  FRAMEADV.S:44   SURE          the 10 x 3 block sweep, three rows bottom-to-top, then the
                                D-row of the screen above
  FRAMEADV.S:346  RedBlockSure  drawc/drawmc drawb/drawmb drawd/drawmd drawa/drawma drawfrnt
  FRAMEADV.S:561  getprev       the three rightmost blocks of the screen to the left
  FRAMEADV.S:616  getbelow      the row below, shifted one block left
  FRAMEADV.S:2041 getobjid      blueprint type/spec, with the two pressplate rewrites
  GRAFIX.S:203    ADDBACK       the display list (YCO >= 192 is DROPPED, unsigned)
  GRAFIX.S:565    DRAWBACK      list order is draw order
  HIRES.S:1740    FASTLAY       XCO is a BYTE column, YCO is the BOTTOM row, rows bottom-first
  HIRES.S:1892    FASTMASK      MASKTAB[byte & $7F] AND'd into the destination
  HRTABLES.S:226  MASKTAB
  BGDATA.S                      the piece -> image tables, verbatim
  TABLES.S:141    BlockBot      [2, 65, 128, 191, 254] indexed by block-Y + 1

WHAT IT DOES NOT IMPLEMENT, AND SAYS SO RATHER THAN SILENTLY SKIPPING.
  The MOVABLE pieces whose image depends on live game state that no blueprint holds:
  the torch FLAME (drawtorchb -> setupflame, a per-frame animation), the slicer's blade,
  the flask bubbles, the gate's bar position, the sword gleam. Each is recorded in
  `omitted` and printed, so a diff against the oracle is read against a KNOWN list of
  absences rather than treated as noise.
"""
import argparse
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
LEVELS = ROOT / "oracle/source/01 POP Source/Levels"
IMAGES = ROOT / "oracle/source/01 POP Source/Images"

# ---------------------------------------------------------------- piece ids
(space, floor, spikes, posts, gate, dpressplate, pressplate, panelwif,
 pillarbottom, pillartop, flask, loose, panelwof, mirror, rubble, upressplate,
 exitp, exit2, slicer, torch, block, bones, sword, window, window2, archbot,
 archtop1, archtop2, archtop3, archtop4) = range(30)

PIECE_NAMES = ("space floor spikes posts gate dpressplate pressplate panelwif "
               "pillarbottom pillartop flask loose panelwof mirror rubble upressplate "
               "exit exit2 slicer torch block bones sword window window2 archbot "
               "archtop1 archtop2 archtop3 archtop4").split()

# ---------------------------------------------------------------- BGDATA.S, verbatim
def _h(s):
    return [int(s[i:i + 2], 16) for i in range(0, len(s), 2)]


def _hc(s):
    """Transcribe a BGDATA.S `hex a,b,c` list. Comma-separated on purpose: the run-on
    form is exactly where a hand-copied table silently loses a byte and shifts every
    piece id after it."""
    v = [int(t, 16) for t in s.replace("\n", "").split(",")]
    assert len(v) == 30, "BGDATA tables are 30 entries, got %d" % len(v)
    return v


maska = _hc("00,03,03,03,03,03,03,03,03,00,03,03,00,03,03,03,"
            "03,00,00,03,00,03,00,03,00,03,00,00,00,00")
piecea = _hc("00,01,05,07,0a,01,01,0a,10,00,01,00,00,14,20,4b,"
             "01,00,00,01,00,97,00,01,00,a7,a9,aa,ac,ad")
pieceay = [0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -4, -4, -4]
maskb = _hc("00,04,04,04,04,04,04,00,04,00,04,00,00,04,04,04,"
            "00,04,04,04,04,04,04,00,04,04,00,00,00,00")
pieceb = _hc("00,02,06,08,0b,1b,02,9e,1a,1c,02,00,9e,4a,21,1b,"
             "4d,4e,02,51,84,98,02,91,92,02,00,00,00,00")
pieceby = [0, 0, 0, 0, 0, 1, 0, 3, 0, 3, 0, 0, 3, 0, 0, -1,
           0, 0, 0, -1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0]
bstripe = _hc("00,47,47,00,00,47,47,00,00,00,47,47,00,00,47,47,"
              "00,00,47,00,00,00,47,00,00,47,00,00,00,00")
piecec = _hc("00,00,00,09,0c,00,00,9f,00,1d,00,00,9f,00,00,00,"
             "4f,50,00,00,85,00,00,93,94,00,00,00,00,00")
pieced = _hc("00,15,15,15,15,18,19,16,15,00,15,00,17,15,2e,4c,"
             "15,15,15,15,86,15,15,15,15,15,ab,00,00,00")
fronti = _hc("00,00,00,45,46,00,00,46,48,49,87,00,46,0f,13,00,"
             "00,00,00,00,83,00,00,00,00,a8,00,ae,ae,ae")
fronty = [0, 0, 0, -1, 0, 0, 0, 0, -1, 3, -3, 0, 0, -1, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, -36, -36, -36]
frontx = _hc("00,00,00,01,03,00,00,03,01,01,02,00,03,01,00,00,"
             "00,00,00,00,00,00,00,00,00,01,00,00,00,00")

gatebotSTA, gatebotORA, gateB1, gatecmask = 0x43, 0x44, 0x37, 0x0d
gate8c = _h("2f30313233343536")
gate8b = _h("3e3d3c3b3a393837")
CUmask, CUpiece, CUpost = 0x11, 0x12, 0x0e
stairs, door, doormask, toprepair = 0x6b, 0x6c, 0x6d, 0x6e
archtop3sp = 0xa1
spikea = _h("0022242628" "2a28242200")
spikeb = _h("0023252729" "2b29252300")
spikeExt, spikeRet = 5, 9
slicerseq = [4, 3, 1, 2, 5, 4, 4]
slicertop = _h("00585a5c5e")
slicerbot = _h("57595b5d5f")
slicerfrnt = _h("6566676869")
looseb = 0x1b
loosea = _h("011e011f1f0101011f1f1f")
looseby = [0, 1, 0, -1, -1, 0, 0, 0, -1, -1, -1]
loosed = _h("152c152d2d1515152d2d2d")
Ffalling = 10
specialflask = 0x95
panelb0, panelc0, numpans = 0x9e, 0x9f, 3
panelb = _h("9e9a81")
panelc = _h("9f9b82")
archpanel = 0xa1
numbpans = 3
spaceb = _h("00a3a5a6")
spaceby = [0, -20, -20, 0]
floorb = _h("02a2a4a4")
floorby = [0, 0, 0, 0]
numblox = 2
blockb = _h("846f")
blockc = _h("8585")
blockd = _h("8686")
blockfr = _h("8383")

MASKTAB = _h(
    "FFFCF8F8F1F0F0F0" "E3E0E0E0E1E0E0E0" "C7C4C0C0C1C0C0C0" "C3C0C0C0C1C0C0C0"
    "8F8C888881808080" "8380808081808080" "8784808081808080" "8380808081808080"
    "9F9C989891909090" "8380808081808080" "8784808081808080" "8380808081808080"
    "8F8C888881808080" "8380808081808080" "8784808081808080" "8380808081808080")

# opacity codes [HIRES.S header]
OP_AND, OP_ORA, OP_STA, OP_EOR, OP_MASK = 0, 1, 2, 3, 4

# TABLES.S:141-160.  Index = block-Y + 1.
ScrnBot, Blox = 191, 63
BlockBot = [ScrnBot - 3 * Blox, ScrnBot - 2 * Blox, ScrnBot - Blox, ScrnBot, ScrnBot + Blox]

# ---------------------------------------------------------------- cel tables
def read_table(path):
    b = path.read_bytes()
    n = b[0]
    cels = []
    for i in range(n):
        p = b[1 + 2 * i] | (b[2 + 2 * i] << 8)
        if not p:
            cels.append(None)
            continue
        off = p - 0x6000
        w, h = b[off], b[off + 1]
        cels.append((w, h, b[off + 2: off + 2 + w * h]))
    return cels


# ---------------------------------------------------------------- the HGR page
def hgr_base(y):
    return (y & 7) * 0x400 + ((y >> 3) & 7) * 0x80 + (y >> 6) * 0x28


class Page:
    """An 8,192-byte HGR page, addressed exactly as FASTLAY addresses it."""

    def __init__(self):
        self.b = bytearray([0x80] * 0x2000)      # CLS: black2 [HIRES.S:135]

    def lay(self, cel, xco, yco, op):
        w, h, data = cel
        top = yco - h
        if top < 0:
            top = -1
        y = yco
        src = 0
        while y != top:
            if 0 <= y < 192:
                base = hgr_base(y) + xco
                for i in range(w):
                    a = (base + i) & 0x1FFF
                    v = data[src + i]
                    if op == OP_STA:
                        self.b[a] = v
                    elif op == OP_ORA:
                        self.b[a] |= v
                    elif op == OP_AND:
                        self.b[a] &= v
                    elif op == OP_EOR:
                        self.b[a] ^= v
                    elif op == OP_MASK:
                        self.b[a] &= MASKTAB[v & 0x7F]
            src += w
            y -= 1


# ---------------------------------------------------------------- the blueprint
class Blueprint:
    def __init__(self, raw):
        self.type = raw[0:720]
        self.spec = raw[720:1440]
        self.linkloc = raw[1440:1696]
        self.linkmap = raw[1696:1952]
        self.map = raw[1952:2048]
        self.info = raw[2048:2304]

    def adj(self, scrn, which):
        """which: 0 left, 1 right, 2 up, 3 down.  [CTRLSUBS.S:243-270]"""
        if scrn == 0:
            return 0
        return self.map[(scrn - 1) * 4 + which]


class Renderer:
    def __init__(self, bp, bg1, bg2, level=0, bgset1=0):
        self.bp = bp
        self.tabs = (bg1, bg2)
        self.level = level
        self.bgset1 = bgset1            # 0 = dungeon, 1 = palace
        self.bg = []                    # ADDBACK list
        self.fg = []                    # ADDFORE list
        self.omitted = {}

    # -- getobjid [FRAMEADV.S:2041] -------------------------------------
    def getobjid(self, scrn, idx):
        if scrn == 0:
            return space, self.state          # GOnull: null screen is space
        base = (scrn - 1) * 30
        self.state = self.bp.spec[base + idx]
        t = self.bp.type[base + idx] & 0x1F
        if t == pressplate:
            v = self.bp.linkmap[self.state] & 0x1F
            return (dpressplate if v >= 2 else pressplate), self.state
        if t == upressplate:
            v = self.bp.linkmap[self.state] & 0x1F
            if v >= 2:
                self.state = 0
                return floor, 0
            return upressplate, self.state
        return t, self.state

    # -- the queue ------------------------------------------------------
    def addback(self, image, xco, yco, op):
        if not (0 <= yco < 192):          # GRAFIX.S:214  cmp #192 / bcs
            return
        if len(self.bg) >= 199:
            return
        self.bg.append((image, xco & 0xFF, yco, op))

    def addfore(self, image, xco, yco, op):
        if not (0 <= yco < 192):
            return
        if len(self.fg) >= 99:
            return
        self.fg.append((image, xco & 0xFF, yco, op))

    def omit(self, why):
        self.omitted[why] = self.omitted.get(why, 0) + 1

    # -- the block sections --------------------------------------------
    def drawc(self, st):
        o = st["objid"]
        vis = o in (space, pillartop, panelwof) or o >= archtop1
        if not vis:
            return
        self.dodrawc(st)
        self.domaskb(st)

    def dodrawc(self, st):
        x = st["BELOW"][st["colno"]]
        if x == block:
            y = st["SBELOW"][st["colno"]]
            if y >= numblox:
                y = 0
            img = blockc[y]
        else:
            img = piecec[x]
            if img == 0:
                return
            if img == panelc0:
                y = st["SBELOW"][st["colno"]]
                if y >= numpans:
                    return
                img = panelc[y]
        if img == 0:
            return
        self.addback(img, st["blockxco"], st["Dy"], OP_ORA)

    def domaskb(self, st):
        img = maskb[st["PRECED"]]
        if img == 0:
            return
        self.addback(img, st["blockxco"], st["Dy"], OP_AND)

    def drawmc(self, st):
        if st["objid"] not in (space, panelwof, pillartop):
            return
        if st["BELOW"][st["colno"]] == gate:
            self.omit("gate C-section (drawgatec: live gate position)")

    def drawb(self, st):
        if st["objid"] == block:
            return
        x = st["PRECED"]
        sp = st["spreced"]
        if x == space:
            if sp >= numbpans + 1:
                return
            img = spaceb[sp]
            if img == 0:
                return
            return self.addback(img, st["blockxco"], st["Ay"] + spaceby[sp], OP_ORA)
        if x == floor:
            y = sp if sp < numbpans + 1 else 0
            img = floorb[y]
            if img == 0:
                return
            return self.addback(img, st["blockxco"], st["Ay"] + floorby[y], OP_ORA)
        if x == block:
            y = sp if sp < numblox else 0
            img = blockb[y]
            if img:
                return self.addback(img, st["blockxco"], st["Ay"] + pieceby[x], OP_ORA)
            return
        img = pieceb[x]
        if img == 0:
            return                       # :stripe — palace only, and BGset1 == 0 here
        if img == panelb0:
            if sp >= numpans:
                return
            img = panelb[sp]
            if img == 0:
                return
        self.addback(img, st["blockxco"], st["Ay"] + pieceby[x], OP_ORA)
        if self.bgset1 == 1 and bstripe[x]:
            self.addback(bstripe[x], st["blockxco"], st["Ay"] - 32, OP_ORA)

    def drawmb(self, st):
        p = st["PRECED"]
        if p == gate:
            self.omit("gate B-section (drawgateb: live gate position)")
        elif p == spikes:
            sp = st["spreced"]
            i = spikeExt if sp & 0x80 else sp
            img = spikeb[i] if i < len(spikeb) else 0
            if img:
                self.addback(img, st["blockxco"], st["Ay"] - 1, OP_ORA)
        elif p == loose:
            self.omit("loose-floor B-section (drawlooseb)")
        elif p == torch:
            if st["blockxco"] != 0:
                self.omit("torch FLAME (drawtorchb -> setupflame: per-frame animation)")
        elif p == exitp:
            self.omit("exit B-section (drawexitb: live door position)")

    def drawd(self, st):
        o = st["objid"]
        op = OP_STA
        if o == block:
            y = st["state"] if st["state"] < numblox else 0
            img = blockd[y]
        else:
            if o == panelwof:
                op = OP_ORA
            img = pieced[o]
        if img == 0:
            return
        self.addback(img, st["blockxco"], st["Dy"], op)

    def drawmd(self, st):
        if st["objid"] == loose:
            self.omit("loose-floor D-section (drawloosed)")

    def addamask(self, st):
        img = maska[st["objid"]]
        if img == 0:
            return
        self.addback(img, st["blockxco"], st["Ay"], OP_AND)

    def getpiecea(self, o, state):
        if o == loose:
            y = state
            if y & 0x80:
                y &= 0x7F
                if y >= Ffalling + 1:
                    y = 1
            return loosea[y] if y < len(loosea) else 0
        return piecea[o]

    def adda(self, st, forced=None, xindex=None):
        o = st["objid"]
        img = self.getpiecea(o, st["state"]) if forced is None else forced
        if img == 0:
            return
        x = o if xindex is None else xindex
        self.addback(img, st["blockxco"], st["Ay"] + pieceay[x], OP_ORA)

    def drawa(self, st):
        p = st["PRECED"]
        if p == archtop1:
            if st["objid"] == panelwof:
                return self.adda(st, forced=archpanel)
            return self.adda(st)
        if p in (panelwif, panelwof, pillartop, block):
            self.addamask(st)
        self.adda(st)

    def drawma(self, st):
        o = st["objid"]
        if o == spikes:
            s = st["state"]
            i = spikeExt if (s & 0x80) else s
            img = spikea[i] if i < len(spikea) else 0
            if img:
                self.addback(img, st["blockxco"], st["Ay"] - 1, OP_ORA)
        elif o == slicer:
            self.omit("slicer blade (drawslicera: live blade phase)")
        elif o == flask:
            self.omit("flask bubbles (drawflaska: per-frame animation)")
        elif o == sword:
            self.omit("sword gleam (drawsworda: per-frame animation)")

    def drawfrnt(self, st):
        if st["PRECED"] == gate:
            self.omit("gate bars over character (DrawGateBF?: needs kid position)")
        o = st["objid"]
        if o == slicer:
            return self.omit("slicer front (drawslicerf)")
        if o == flask:
            self.omit("flask front (state-dependent)")
        img = fronti[o]
        if img == 0:
            return
        yco = st["Ay"] + fronty[o]
        xco = st["blockxco"] + frontx[o]
        if o >= archtop2:
            return self.addfore(img, xco, yco, OP_STA)
        if self.bgset1 != 1 and o == posts:
            return self.addfore(img, xco, yco, OP_STA)
        if o == block:
            y = st["state"] if st["state"] < numblox else 0
            return self.addfore(blockfr[y], xco, yco, OP_STA)
        # maddfore: the SAME image twice, mask then or  [FRAMEADV.S:1170]
        self.addfore(img, xco, yco, OP_MASK)
        self.addfore(img, xco, yco, OP_ORA)

    def red_block_sure(self, st):
        self.drawc(st); self.drawmc(st)
        self.drawb(st); self.drawmb(st)
        self.drawd(st); self.drawmd(st)
        self.drawa(st); self.drawma(st)
        self.drawfrnt(st)

    def red_d_sure(self, st):
        self.drawc(st); self.drawmc(st)
        self.drawb(st)
        self.drawd(st); self.drawmd(st)
        self.drawfrnt(st)

    # -- SURE [FRAMEADV.S:44] -------------------------------------------
    def sure(self, scrnum):
        bp = self.bp
        self.state = 0
        scrnLeft = bp.adj(scrnum, 0)
        scrnAbove = bp.adj(scrnum, 2)
        scrnBelow = bp.adj(scrnum, 3)
        scrnBelowL = bp.adj(scrnBelow, 0)

        # getprev
        PREV, sprev = [0, 0, 0], [0, 0, 0]
        if scrnum == 0 or scrnLeft == 0:
            PREV = [block, block, block]
            sprev = [0, 0, 0]
        else:
            for i, idx in enumerate((9, 19, 29)):
                o, s = self.getobjid(scrnLeft, idx)
                PREV[i], sprev[i] = o, s

        BELOW = [0] * 10
        SBELOW = [0] * 10

        def getbelow(rowno, below_scrn, belowl_scrn):
            if rowno < 2:
                BELOW[0] = PREV[rowno + 1]
                SBELOW[0] = sprev[rowno + 1]
                y = rowno * 10 + 10
                for x in range(1, 10):
                    o, s = self.getobjid(scrnum, y)
                    BELOW[x], SBELOW[x] = o, s
                    y += 1
                return
            if below_scrn == 0:
                for x in range(1, 10):
                    BELOW[x] = floor        # :belowblack — SBELOW deliberately stale
            else:
                for y in range(8, -1, -1):
                    o, s = self.getobjid(below_scrn, y)
                    BELOW[y + 1], SBELOW[y + 1] = o, s
            if belowl_scrn == 0:
                BELOW[0] = space if self.level == 12 else block
            else:
                o, s = self.getobjid(belowl_scrn, 9)
                BELOW[0], SBELOW[0] = o, s

        for rowno in (2, 1, 0):
            Dy = BlockBot[1 + rowno]
            Ay = Dy - 3
            yindex = rowno * 10
            PRECED, spreced = PREV[rowno], sprev[rowno]
            getbelow(rowno, scrnBelow, scrnBelowL)
            for colno in range(10):
                blockxco = colno * 4
                objid, state = self.getobjid(scrnum, yindex)
                st = dict(objid=objid, state=state, PRECED=PRECED, spreced=spreced,
                          colno=colno, rowno=rowno, blockxco=blockxco, Dy=Dy, Ay=Ay,
                          BELOW=BELOW, SBELOW=SBELOW)
                self.red_block_sure(st)
                PRECED, spreced = objid, state
                yindex += 1

        # the D-row of the screen ABOVE  [FRAMEADV.S:98-160]
        Dy, Ay = 2, -1
        yindex = 20
        PRECED, spreced = 0, 0
        getbelow(2, scrnum, scrnLeft)
        for colno in range(10):
            blockxco = colno * 4
            if scrnAbove == 0:
                objid, state = floor, self.state
            else:
                objid, state = self.getobjid(scrnAbove, yindex)
            st = dict(objid=objid, state=state, PRECED=PRECED, spreced=spreced,
                      colno=colno, rowno=2, blockxco=blockxco, Dy=Dy, Ay=Ay,
                      BELOW=BELOW, SBELOW=SBELOW)
            self.red_d_sure(st)
            PRECED, spreced = objid, state
            yindex += 1

    # -- DRAWALL [GRAFIX.S:484] ----------------------------------------
    def paint(self):
        pg = Page()
        for image, xco, yco, op in self.bg + self.fg:
            tab = self.tabs[1] if image & 0x80 else self.tabs[0]
            idx = (image & 0x7F) - 1
            if not (0 <= idx < len(tab)) or tab[idx] is None:
                self.omit("image $%02X out of range" % image)
                continue
            pg.lay(tab[idx], xco, yco, op)
        return pg


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--level", default="LEVEL0")
    ap.add_argument("--screen", type=int, default=1)
    ap.add_argument("--bgset", default="DUN", choices=("DUN", "PAL"))
    ap.add_argument("--out", default=None, help="write the 8,192-byte HGR page here")
    ap.add_argument("--compare", default=None, help="an oracle HGR page to diff against")
    ap.add_argument("--scan", action="store_true",
                    help="render all 24 screens and report which best matches --compare")
    args = ap.parse_args()

    bp = Blueprint((LEVELS / args.level).read_bytes())
    bg1 = read_table(IMAGES / ("IMG.BGTAB1.%s" % args.bgset))
    bg2 = read_table(IMAGES / ("IMG.BGTAB2.%s" % args.bgset))
    bgset1 = 0 if args.bgset == "DUN" else 1

    ref = pathlib.Path(args.compare).read_bytes() if args.compare else None

    def render(scr):
        r = Renderer(bp, bg1, bg2, level=int(args.level.replace("LEVEL", "")), bgset1=bgset1)
        r.sure(scr)
        return r, r.paint()

    if args.scan and ref is not None:
        print("screen  matching bytes / 7680 visible   (the 512 non-display bytes excluded)")
        best = None
        for s in range(1, 25):
            _, pg = render(s)
            same = sum(1 for y in range(192) for i in range(40)
                       if pg.b[hgr_base(y) + i] == ref[hgr_base(y) + i])
            print("  %2d    %5d  (%.1f%%)" % (s, same, 100.0 * same / 7680))
            if best is None or same > best[1]:
                best = (s, same)
        print("BEST: screen %d with %d/7680 (%.1f%%)" % (best[0], best[1], 100.0 * best[1] / 7680))
        return 0

    r, pg = render(args.screen)
    print("level %s screen %d, bgset %s" % (args.level, args.screen, args.bgset))
    print("  background list %d entries, foreground list %d" % (len(r.bg), len(r.fg)))
    if r.omitted:
        print("  OMITTED (state-dependent, not in the blueprint):")
        for k, v in sorted(r.omitted.items()):
            print("    x%-3d %s" % (v, k))
    else:
        print("  OMITTED: nothing — every piece on this screen is blueprint-determined")
    if args.out:
        pathlib.Path(args.out).write_bytes(bytes(pg.b))
        print("  -> %s (8,192 B)" % args.out)
    if ref is not None:
        same = diff = 0
        rowdiff = {}
        for y in range(192):
            b = hgr_base(y)
            for i in range(40):
                if pg.b[b + i] == ref[b + i]:
                    same += 1
                else:
                    diff += 1
                    rowdiff[y] = rowdiff.get(y, 0) + 1
        print("  vs %s: %d/%d visible bytes match (%.2f%%), %d differ"
              % (args.compare, same, same + diff, 100.0 * same / (same + diff), diff))
        if rowdiff:
            rows = sorted(rowdiff)
            print("  differing rows: %d of 192, worst %s"
                  % (len(rows), sorted(rowdiff.items(), key=lambda kv: -kv[1])[:6]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
