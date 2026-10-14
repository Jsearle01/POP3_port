#!/usr/bin/env python3
r"""guard_model.py — P5.37 §2: the guard's game-frame update, transcribed from the oracle's source (the
SECOND derivation; the 6809 build is the third), run over game frames 180-217 against the oracle's own records.

Authority: the routines are the adamgreen `build` source (§2 tier 3), transcribed line-for-line where the
window's path runs (P5.36 §3B measured that path); the TABLES they read (seqtab, frame defs, the seq/object
constants) are taken from the oracle's assembled listings, not retyped; the yardstick is the oracle's S= record
per game frame (tier 2). Any branch the window is not measured to take raises `Unmodelled(<label>)` instead of
guessing -- a raise is a finding, not a crash.

Order per game frame = DoShad [TOPCTRL.S:701-740]:
  LoadShadwOp, rereadblocks, unholy, ShadCtrl (SHADCTRL -> AutoCtrl -> GenCtrl), animchar (CharScrn = VisScrn),
  then if onscreen: gravity, addfall, setupchar, rereadblocks, getedges, enemycoll, checkfloor, checkpress,
  checkspikes, checkimpale, checkslice2; SaveShad.

Replayed inputs (the §2I test-bed divergences, stated): the kid's record per frame (Op = Kid after DoKid,
LoadShadwOp), EnemyAlert per frame. Seeded: the guard record and the map at game frame 179.

  python harness/tools/guard_model.py            # model vs oracle, frame by frame
  python harness/tools/guard_model.py --control enemyalert|map   # negative controls (must diverge)
"""
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OBJ = ROOT / "oracle/source/obj"
PATH_TXT = ROOT / "build/p536/oracle_path.txt"
MAPDUMP = ROOT / "build/p537/blueprint_aux_8882.bin"
GF0 = 180                    # first game frame of the window (first AUTOCTRL, P5.36 §3A)
GF1 = 217
FIELDS = ("Posn X Y Face BlockX BlockY Action XVel YVel SeqL SeqH Scrn Repeat ID Sword Life").split()


class Unmodelled(Exception):
    pass


# ------------------------------------------------------------------ the oracle's assembled data
def lst_bytes(name):
    """addr -> byte from one .LST (bytes sit in columns 6-14; later lines win, as the assembler's org/ds do)."""
    mem = {}
    for l in (OBJ / name).read_text(errors="replace").splitlines():
        m = re.match(r"^([0-9A-F]{4}): ", l)
        if not m:
            continue
        a = int(m.group(1), 16)
        for i, b in enumerate(l[6:15].split()):
            mem[a + i] = int(b, 16)
    return mem


def lst_sym(name, lsts=("AUTO.LST", "CTRL.LST", "CTRLSUBS.LST", "SEQTABLE.LST")):
    """A `name = value` equate as the oracle assembled it (first listing that defines it)."""
    for lst in lsts:
        for l in (OBJ / lst).read_text(errors="replace").splitlines():
            m = re.match(r"^\s*:\s+=([0-9A-F]{4})\s+\d+\s+(\S+)\s*=", l)
            if m and m.group(2) == name:
                return int(m.group(1), 16)
    raise SystemExit("no `%s =` in %s" % (name, lsts))


SEQ = lst_bytes("SEQTABLE.LST")
FRM = lst_bytes("FRAMEDEF.LST")
SEQTAB, FDEF, ALTSET1 = 0x3000, 0x2800, 0x2CB0          # SEQTABLE org; FRAMEDEF `Fdef`, `altset1`
S = {n: lst_sym(n) for n in (
    "guardengarde", "advance", "retreat", "readyblock", "alertturn", "turnengarde", "goalertstand",
    "resheathe", "bumpengback", "space", "floor", "spikes", "pillartop", "gate", "panelwif", "loose",
    "panelwof", "mirror", "slicer", "block", "archtop1", "swordthres", "toofar", "tooclose",
    "offguardthres", "jumpthres", "runthres", "ScrnLeft", "ScrnRight", "chx", "chy", "aboutface", "goto",
    "up", "down", "act", "setfall", "ifwtless", "die", "jaru", "jard", "tap", "nextlevel", "effect",
    "idmask", "angle", "Ffootmark", "fcheckmark")}

# TABLES.S:79-107 (BlockTable / PixelTable), :178-185 (FloorY) -- generated, as the source generates them
BLOCKTABLE = [((x + 68) // 14 - 9) & 0xFF for x in range(256)]
PIXELTABLE = [(x + 68) % 14 for x in range(256)]
FLOORY = [(191 - 3 * 63 - 10) & 0xFF, 191 - 2 * 63 - 10, 191 - 63 - 10, 191 - 10, (191 + 63 - 10) & 0xFF]


def s8(v):
    return v - 256 if v >= 128 else v


# ------------------------------------------------------------------ the oracle's records
def records():
    """game frame -> (K bytes, S bytes, vars); game frame 180 = the frame of the first AUTOCTRL (path gf 187)."""
    out = {}
    for l in PATH_TXT.read_text().splitlines():
        m = re.match(r"^F (\d+) gf=(\d+) K=([0-9A-F]{32}) S=([0-9A-F]{32}) (.*)$", l)
        if not m:
            continue
        v = dict(kv.split("=") for kv in m.group(5).split())
        out[int(m.group(2)) - 7] = (bytes.fromhex(m.group(3)), bytes.fromhex(m.group(4)),
                                    {k: int(x, 16) for k, x in v.items()}, int(m.group(1)))
    return out


# ------------------------------------------------------------------ the machine state the window touches
class St:
    pass


def rec_to(c, b):
    (c.Posn, c.X, c.Y, c.Face, c.BlockX, c.BlockY, c.Action, c.XVel, c.YVel, sl, sh, c.Scrn, c.Repeat,
     c.ID, c.Sword, c.Life) = b
    c.Seq = sl | sh << 8


def to_rec(c):
    return bytes([c.Posn, c.X, c.Y, c.Face, c.BlockX, c.BlockY, c.Action, c.XVel, c.YVel, c.Seq & 0xFF,
                  c.Seq >> 8, c.Scrn, c.Repeat, c.ID, c.Sword, c.Life])


class Guard:
    def __init__(self, bluetype, bmap):
        self.type, self.map = bytearray(bluetype), bmap
        self.C, self.O = St(), St()
        self.z = St()                # globals: clr*, JSTK*, btn, timers, Fdx/Fcheck, tempblock*
        for n in ("clrF clrB clrU clrD clrbtn JSTKX JSTKY btn justblocked gdtimer refract alertguard "
                  "droppedout EnemyAlert Fdx Fdy Fcheck Fimage Fsword tempblockx tempblocky tempscrn").split():
            setattr(self.z, n, 0)
        self.calls = []              # (routine, args, result) -- the map reads, for the control and the 6809 compare

    # -------------------------------------------------------------- map [CTRLSUBS.S:136-275]
    def adj(self, scrn, which):
        return self.map[(scrn - 1) * 4 + which] if scrn else 0

    def rdblock(self, scrn, x, y, who):
        x, y = s8(x & 0xFF), s8(y & 0xFF)
        arg = (scrn, x, y)                          # as passed (A, X, Y at RDBLOCK's entry)
        while True:
            if x < 0:
                x += 10; scrn = self.adj(scrn, 0)
            elif x >= 10:
                x -= 10; scrn = self.adj(scrn, 1)
            elif y < 0:
                y += 3; scrn = self.adj(scrn, 2)
            elif y >= 3:
                y -= 3; scrn = self.adj(scrn, 3)
            else:
                break
        z = self.z
        z.tempscrn, z.tempblockx, z.tempblocky = scrn, x, y
        r = S["block"] if scrn == 0 else self.type[(scrn - 1) * 30 + y * 10 + x] & S["idmask"]
        if self.override and who in self.override.get(self.gf, ()):
            r = self.override[self.gf][who]
        self.calls.append((self.gf, who) + arg + (r,))
        return r

    def getunderft(self, who="getunderft"):
        C = self.C
        return self.rdblock(C.Scrn, C.BlockX, C.BlockY, who)

    def getinfront(self, n=1, who="getinfront"):
        C = self.C
        d = -1 if C.Face & 0x80 else 1             # plus1 = -1,1 indexed by CharFace+1
        return self.rdblock(C.Scrn, C.BlockX + n * d, C.BlockY, who)

    def cmpspace(self, a):                          # CTRLSUBS.S:1506-1522
        if a in (S["space"], S["pillartop"], S["panelwof"], S["block"]) or a >= S["archtop1"]:
            return 0
        return 1

    # -------------------------------------------------------------- char helpers [CTRLSUBS.S]
    def addcharx(self, a):                          # :353-363
        if self.C.Face & 0x80:
            a = -a
        return (self.C.X + a) & 0xFF

    def jumpseq(self, n):                           # :700-711
        x = SEQTAB + 2 * (n - 1)
        self.C.Seq = SEQ[x] | SEQ[x + 1] << 8

    def getseq(self):                               # :1629-1639
        b = SEQ[self.C.Seq]
        self.C.Seq = (self.C.Seq + 1) & 0xFFFF
        return b

    def getframeinfo(self):                         # :1648-1715 (usealtsets: CharID 2, posn 150-189 -> altset1)
        C, z = self.C, self.z
        p = C.Posn
        if C.ID == 0 or C.ID == 24:
            base = FDEF + 5 * (p - 1)
        elif C.ID >= 5:
            raise Unmodelled("usealtsets:usealt2")
        else:
            if C.ID >= 2 and 102 <= p < 107:
                p += 70
            base = ALTSET1 + 5 * (p - 149 - 1) if 150 <= p < 190 else FDEF + 5 * (p - 1)
        z.Fimage, z.Fsword, z.Fdx, z.Fdy, z.Fcheck = (FRM[base + i] for i in range(5))

    def getbasex(self):                             # :329-340
        a = (-(self.z.Fcheck & S["Ffootmark"]) + self.z.Fdx) & 0xFF
        return self.addcharx(s8(a))

    def rereadblocks(self):                         # CTRL.S:1929-1931 = GetFrameInfo + GetBaseBlock
        self.getframeinfo()
        self.C.BlockX = BLOCKTABLE[(self.getbasex() - S["angle"]) & 0xFF]   # :666-670, GETBLOCKXP

    def getopdist(self):                            # :2052-2102
        C, O = self.C, self.O
        if C.Scrn != O.Scrn:
            return 127
        if O.X >= C.X:
            a = O.X - C.X
            if a > 127:
                a = 127
        else:
            a = C.X - O.X
            if a > 127:
                a = 127
            a = -a
        if C.Face & 0x80:
            a = -a
        a &= 0xFF
        if (C.Face ^ O.Face) & 0x80:
            if a < 127 - 13:
                a = (a + 13) & 0xFF
        return a

    # -------------------------------------------------------------- AUTO.S
    def DoRelease(self):                            # :822-832
        z = self.z
        z.clrF = z.clrB = z.clrU = z.clrD = z.clrbtn = z.JSTKX = z.JSTKY = z.btn = 0

    def A_DoAdvance(self):                          # :834-839 (DoFwd)
        self.z.clrF = self.z.JSTKX = 0xFF

    def A_DoRetreat(self):                          # :841-847
        self.z.clrB = 0xFF; self.z.JSTKX = 1

    def A_DoEngarde(self):                          # :873-876
        self.z.clrD = 0xFF
        self.A_DoAdvance()

    def AUTOCTRL(self):                             # :160-193
        z = self.z
        self.DoRelease()
        if self.C.ID == 0:
            raise Unmodelled("AUTOCTRL:KidProg")
        for t in ("justblocked", "gdtimer", "refract"):
            if getattr(z, t):
                setattr(z, t, getattr(z, t) - 1)
        if self.C.ID in (24, 4) or self.C.ID < 2:
            raise Unmodelled("AUTOCTRL:non-guard")
        self.GuardProg()

    def GuardProg(self):                            # :455-460
        if self.C.Sword < 2:
            self.Alert()
        else:
            self.EnGarde()

    def Alert(self):                                # :467-506
        C, O, z = self.C, self.O, self.z
        if not (O.Life & 0x80):                     # KidLife: Op = Kid (LoadShadwOp)
            return
        a = self.getopdist()
        if O.BlockY == C.BlockY and a >= 0xF8:
            return self._eng()
        if z.alertguard:
            z.alertguard = 0
            if a < 128:
                return self._eng()
            if a >= 0xFC:
                pass
            else:
                raise Unmodelled("Alert:DoTurn")
        if a >= 128:
            return
        return self._eng()

    def _eng(self):
        if self.z.EnemyAlert == 0:
            return
        self.A_DoEngarde()                          # level 0: no SongCue wait

    def EnGarde(self):                              # :513-606
        C, O, z = self.C, self.O, self.z
        if C.Posn == 166 or C.Posn < 150:
            return
        if z.EnemyAlert < 2:
            if z.EnemyAlert == 1:
                return
            raise Unmodelled("EnGarde:EnemyAlert0")
        a = self.getopdist()
        if not (a & 0x80) and a >= 12 and 102 <= O.Posn < 118:
            if O.Action == 5:
                return
        a = self.getopdist()
        if a < S["toofar"]:
            raise Unmodelled("EnGarde:InRange/tooclose")
        if z.refract:
            return
        if C.Face != O.Face:
            p = O.Posn
            if 7 <= p < 15:
                if self.getopdist() >= S["runthres"]:
                    return
                raise Unmodelled("EnGarde:runwait-strike")
            if 34 <= p < 44:
                if self.getopdist() >= S["jumpthres"]:
                    return
                raise Unmodelled("EnGarde:jumpwait-strike")
        if self.cmpspace(self.getinfront(1, "getinfront")) == 0 or \
                self.cmpspace(self.getinfront(2, "get2infront")) == 0:
            return self.A_DoRetreat()
        return self.A_DoAdvance()

    # -------------------------------------------------------------- CTRL.S
    def clrall(self):                               # :625-632
        z = self.z
        z.clrB = z.clrF = z.clrU = z.clrD = 0
        return 1

    def C_DoEngarde(self):                          # :1607-1624 (guard)
        z = self.z
        a = self.clrall()
        z.clrF = z.clrbtn = a
        self.C.Sword = 2
        self.jumpseq(S["guardengarde"])

    def C_DoAdvance(self):                          # :1007-1024
        if self.C.Posn in (158, 170, 171):
            self.z.clrF = 1
            self.jumpseq(S["advance"])

    def C_DoRetreat(self):                          # :991-1004
        if self.C.Posn in (158, 170, 171):
            self.z.clrB = 1
            self.jumpseq(S["retreat"])

    def GENCTRL(self):                              # :648-685
        C, z = self.C, self.z
        if not (C.Life & 0x80):
            raise Unmodelled("GENCTRL:dead")
        if C.Action in (5, 4):
            self.clrall(); return
        if C.Sword == 2:
            return self.FightCtrl()
        if C.ID < 2:
            raise Unmodelled("GENCTRL:kid/shad")
        return self.GuardCtrl()

    def GuardCtrl(self):                            # :736-754
        z = self.z
        if self.C.Posn != 166 or not (z.clrD & 0x80):
            return
        if z.clrF & 0x80:
            return self.C_DoEngarde()
        raise Unmodelled("GuardCtrl:alertturn")

    def FightCtrl(self):                            # :759-888
        C, z = self.C, self.z
        if C.Action >= 2:
            return
        if self.getunderft() != S["loose"] and z.EnemyAlert < 2:
            if C.ID < 2:
                raise Unmodelled("FightCtrl:dropgd-kid/shad")
        else:
            a = self.getopdist()
            if a >= S["swordthres"]:
                if a < 128:
                    if C.ID < 2:
                        raise Unmodelled("FightCtrl:dropgd-kid/shad")
                elif a < 0xFC:
                    raise Unmodelled("FightCtrl:DoTurnEng")
        # :onalert
        if C.Posn == 161:
            raise Unmodelled("FightCtrl:blocked")
        if z.clrbtn & 0x80:
            raise Unmodelled("FightCtrl:strike")
        if z.clrD & 0x80:
            raise Unmodelled("FightCtrl:lower-sword")
        if z.clrU & 0x80:
            raise Unmodelled("FightCtrl:DoBlock")
        if z.clrF & 0x80:
            return self.C_DoAdvance()
        if z.clrB & 0x80:
            return self.C_DoRetreat()

    def SHADCTRL(self):                             # :509-534
        C = self.C
        if C.ID == 24:
            raise Unmodelled("SHADCTRL:mouse")
        if not (C.Life & 0x80):
            raise Unmodelled("SHADCTRL:dead")
        self.AUTOCTRL()                             # ManCtrl = 0
        self.GENCTRL()

    # -------------------------------------------------------------- COLL.S ANIMCHAR :994-1156
    def animchar(self):
        C, z = self.C, self.z
        while True:
            a = self.getseq()
            if a == S["chx"] & 0xFF:
                C.X = self.addcharx(s8(self.getseq()))
            elif a == S["chy"] & 0xFF:
                C.Y = (C.Y + self.getseq()) & 0xFF
            elif a == S["aboutface"] & 0xFF:
                C.Face ^= 0xFF
            elif a == S["goto"] & 0xFF:
                lo = self.getseq(); hi = self.getseq()
                C.Seq = lo | hi << 8
            elif a == S["act"] & 0xFF:
                C.Action = self.getseq()
            elif a == S["setfall"] & 0xFF:
                C.XVel = self.getseq(); C.YVel = self.getseq()
            elif a == S["tap"] & 0xFF:
                t = self.getseq()
                if t in (0, 1):
                    z.alertguard = 1
            elif a in (S[k] & 0xFF for k in ("up", "down", "ifwtless", "die", "jaru", "jard", "nextlevel",
                                              "effect")):
                raise Unmodelled("animchar:%02X" % a)
            else:
                C.Posn = a
                return

    # -------------------------------------------------------------- the physics that runs on an onscreen guard
    def gravity(self):                              # SUBS.S:1618
        if self.C.Action == 4:
            raise Unmodelled("gravity:freefall")

    def addfall(self):                              # SUBS.S:1651
        C = self.C
        C.Y = (C.Y + C.YVel) & 0xFF
        if C.Action == 4:
            raise Unmodelled("addfall:freefall")

    def enemycoll(self):                            # COLL.S:1389-1424 (AMtimer 0 on level 0)
        C = self.C
        if C.Action != 1 or not (C.Life & 0x80) or C.Sword < 2:
            return
        a = self.getunderft("enemycoll")
        if a in (S["block"], S["panelwif"], S["gate"]):
            raise Unmodelled("enemycoll:collide-under")
        if C.Face & 0x80:
            return
        z = self.z
        a = self.rdblock(z.tempscrn, z.tempblockx - 1, z.tempblocky, "enemycoll-behind")   # rdblock1
        if a in (S["panelwif"], S["gate"]):
            raise Unmodelled("enemycoll:collide-behind")

    def checkfloor(self):                           # CTRL.S:106-133, onground :313-324
        C = self.C
        if C.Action in (6, 2):
            return
        if C.Action in (5, 4, 3):
            raise Unmodelled("checkfloor:action%d" % C.Action)
        if not (self.z.Fcheck & S["fcheckmark"]):
            return
        a = self.getunderft("checkfloor")
        if a == S["block"]:
            raise Unmodelled("checkfloor:InsideBlock")
        if self.cmpspace(a) == 0:
            raise Unmodelled("checkfloor:startfall")

    # -------------------------------------------------------------- TOPCTRL.S DoShad :701-740
    def DoShad(self, kid, vis_scrn):
        C, O = self.C, self.O
        if C.Face == 86:
            return
        rec_to(O, kid)                              # LoadShadwOp: Op := Kid
        self.rereadblocks()
        # unholy: level 0 -> rts
        self.SHADCTRL()
        if C.Scrn != vis_scrn:
            return
        self.animchar()
        if C.X < S["ScrnLeft"] - 14 or C.X >= S["ScrnRight"] + 14:
            return
        self.gravity()
        self.addfall()
        self.getframeinfo()                         # setupchar: only its GETFRAMEINFO touches state read later
        self.rereadblocks()
        # getedges: writes edge temps only
        self.enemycoll()
        self.checkfloor()
        # checkpress / checkspikes / checkimpale / checkslice2: not transcribed -- see the report


def run(control=None, quiet=False):
    R = records()
    bp = MAPDUMP.read_bytes()
    g = Guard(bp[0:720], bp[1952:2048])
    g.override = {}
    rec_to(g.C, R[GF0 - 1][1])
    v = R[GF0 - 1][2]
    for n in ("justblocked", "gdtimer", "refract", "alertguard", "droppedout"):
        setattr(g.z, n, v[n])
    if control == "map":
        # the map control: the block two in front reads as a gap in 208-217 -> EnGarde must retreat, not advance
        g.override = {gf: {"get2infront": S["space"]} for gf in range(208, GF1 + 1)}
    bad, first = 0, None
    for gf in range(GF0, GF1 + 1):
        kid, srec, v, F = R[gf]
        g.gf = gf
        g.z.EnemyAlert = v["EnemyAlert"] if control != "enemyalert" else 1
        g.DoShad(kid, vis_scrn=kid[11])            # VisScrn = the kid's screen in this window
        got = to_rec(g.C)
        if got != srec:
            bad += 1
            first = first or gf
        if not quiet:
            diff = [FIELDS[i] for i in range(16) if got[i] != srec[i]]
            print("gf %d F%d  model %s  oracle %s  %s" % (gf, F, got.hex().upper(), srec.hex().upper(),
                                                           "==" if not diff else "DIFF " + ",".join(diff)))
    return bad, first, g


def main():
    control = sys.argv[sys.argv.index("--control") + 1] if "--control" in sys.argv else None
    try:
        bad, first, g = run(control)
    except Unmodelled as e:
        print("guard_model: UNMODELLED branch reached: %s" % e)
        return 2
    n = GF1 - GF0 + 1
    reads = {}
    for gf, who, sc, x, y, r in g.calls:
        reads[who] = reads.get(who, 0) + 1
    print("\nmap reads by the model: %s" % reads)
    if "--xref" in sys.argv:
        # every controller-extent map read, against the oracle's traced RDBLOCK: same (gf, scrn, x, y, answer), same order
        import oracle_blueprint as OB
        calls, _base, _bs = OB.trace_calls()
        orc = [(c["gf"], c["scrn"], s8(c["x"]), s8(c["y"]), c.get("ret")) for c in calls
               if c["ext"][0] == "guard-ctrl" and GF0 <= c["gf"] <= GF1]
        mod = [(gf, sc, x, y, r) for gf, who, sc, x, y, r in g.calls
               if who in ("getunderft", "getinfront", "get2infront")]
        same = orc == mod
        print("xref: guard-controller map reads -- oracle %d, model %d: %s"
              % (len(orc), len(mod), "IDENTICAL (coordinates, answers, order)" if same else "DIFFER"))
        if not same:
            for i, (a, b) in enumerate(zip(orc, mod)):
                if a != b:
                    print("  first difference #%d: oracle %r model %r" % (i, a, b)); break
            bad += 1
    if control:
        print("guard_model: CONTROL %s -> %d of %d frames differ (first at gf %s) -- %s"
              % (control, bad, n, first, "DISCRIMINATES" if bad else "★ DOES NOT DISCRIMINATE"))
        return 0 if bad else 1
    print("guard_model: %d of %d game frames byte-identical to the oracle's S= record%s"
          % (n - bad, n, "" if not bad else " (first difference gf %d)" % first))
    return 0 if not bad else 1


if __name__ == "__main__":
    sys.exit(main())
