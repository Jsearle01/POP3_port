#!/usr/bin/env python3
"""PA.9 THROWAWAY PROTOTYPE — POP cel -> CoCo3 4-colour -> compiled 6809 sprite.

NOT the production compiler. NOT engine code. A build-time measurement instrument
for PA.9 only: it exists to produce a real cy/byte number on POP's OWN cels and to
prove the pipeline can emit CORRECT code.

Pipeline
  1. decode  : IMG.CHTAB* -> Apple HGR 1bpp cel      (HIRES.S:184-186 [w][h][bytes])
  2. render  : HGR 1bpp   -> CoCo3 2bpp + TRANSPARENCY token
  3. compile : token grid -> 6809 instruction list
  4. count   : MC6809 cycles, counted from the emitted instructions
  5. simulate: execute the instruction list against a virtual framebuffer and
               diff against the expected render  (the soundness check)

Token model (Jay's "value 5" scheme, made explicit)
  0,1,2,3 = OPAQUE palette indices.  0 is opaque BLACK and IS drawn.
  T (=4)  = TRANSPARENT.  Never stored; background shows through.
  The distinction is resolved HERE, at compile time.  The emitted code contains
  no mask table, no runtime transparency test -- that is the whole point.
"""
import sys, re, pathlib, collections

T = 4                                   # transparent token (distinct from opaque black = 0)
PXB = 4                                 # CoCo3 2bpp: 4 pixels per byte, MSB-first
STRIDE = 80                             # 320px / 4px per byte

# ---------------------------------------------------------------- 1. decode
def load_table(path, base=0x6000):
    b = path.read_bytes(); n = b[0]; cels = []
    for i in range(1, n + 1):
        p = 1 + 2 * (i - 1)
        off = (b[p] | (b[p + 1] << 8)) - base
        w, h = b[off], b[off + 1]
        data = b[off + 2: off + 2 + w * h]
        cels.append(dict(idx=i, w=w, h=h, data=data))
    return cels

def hgr_pixels(cel):
    """Apple HGR: 7 px per byte, LSB-first, bit7 = colour-set (not a pixel)."""
    rows = []
    for r in range(cel['h']):
        row = []
        for c in range(cel['w']):
            byte = cel['data'][r * cel['w'] + c]
            for k in range(7):
                row.append((byte >> k) & 1)
        rows.append(row)
    return rows

# ---------------------------------------------------------------- 2. render
def tokenize(pixels, opacity):
    """STAGE-1 CONTRACT (karateka harness/tools/sprite_tool/opacity.py, verbatim):
       "Opacity is meaningful ONLY for index-0 (black) pixels: is this black pixel
        OPAQUE (shadow, stored solid) or KEYED (transparent)? Non-0 pixels (1/2/3)
        are always drawn."
    pixels : h x (w*4) palette indices 0..3
    opacity: h x (w*4) bool, True = that index-0 pixel is OPAQUE BLACK (drawn)
    -> token grid: 0..3 opaque (0 = opaque black), T = transparent.
    THIS is where the distinction is resolved. Nothing downstream tests it."""
    out = []
    for r, row in enumerate(pixels):
        o = []
        for c, v in enumerate(row):
            if v != 0:
                o.append(v)                       # colour: always drawn
            elif opacity[r][c]:
                o.append(0)                       # index-0 marked OPAQUE -> drawn black
            else:
                o.append(T)                       # index-0 unmarked -> transparent
        out.append(o)
    return out

def hgr_to_coco(rows):
    """STRUCTURAL STAND-IN for POP cels (stated in the report): POP cels are Apple
    HGR 1bpp masks drawn in OR/mask mode, so OFF = keyed by construction. ON pixels
    get an opaque index by a simple run rule. Returns (pixels, opacity)."""
    px, op = [], []
    for row in rows:
        pr, orow = [], []
        for x, p_ in enumerate(row):
            if not p_:
                pr.append(0); orow.append(False)          # index-0, KEYED
            else:
                left  = x > 0 and row[x-1]
                right = x + 1 < len(row) and row[x+1]
                pr.append(3 if (left and right) else (2 if x % 2 == 0 else 1))
                orow.append(False)
        px.append(pr); op.append(orow)
    return px, op

def pack(tokens):
    """token rows -> per-byte (value, keepmask, cls).
       cls: 'skip' all-transparent | 'store' all-opaque | 'mixed'
       keepmask: bits of the DEST byte to preserve (transparent positions)."""
    packed = []
    for row in tokens:
        wb = (len(row) + PXB - 1) // PXB
        pr = []
        for b in range(wb):
            val = 0; keep = 0; nop = 0; ntr = 0
            for k in range(PXB):
                x = b * PXB + k
                t = row[x] if x < len(row) else T
                shift = 6 - 2 * k                     # MSB-first
                if t == T:
                    ntr += 1; keep |= (0b11 << shift)
                else:
                    nop += 1; val |= (t & 0b11) << shift
            cls = 'skip' if nop == 0 else ('store' if ntr == 0 else 'mixed')
            pr.append((val, keep, cls))
        packed.append(pr)
    return packed

# ---------------------------------------------------------------- 3. compile
class Compiler:
    """Emits (mnemonic, operand, cycles, effect) tuples.  Tracks D/X/Y contents so
    immediate loads are only emitted when the needed value is not already live --
    this is what makes PSHU bursts cheap, and is why Glen's file has 46 PSHU but
    only 13 LDD #."""
    def __init__(self):
        self.ins = []; self.reg = {'D': None, 'X': None, 'Y': None}

    def emit(self, m, o, c, eff=None):
        self.ins.append(dict(m=m, o=o, c=c, eff=eff))

    def load(self, r, val16):
        if self.reg[r] == val16:
            return 0
        self.reg[r] = val16
        cyc = {'D': 3, 'X': 3, 'Y': 4}[r]             # LDD/LDX imm 3, LDY imm 4 (page-2)
        self.emit(f'LD{r}', f'#${val16:04X}', cyc)
        return cyc

    def compile_cel(self, packed):
        """Walk rows BOTTOM-UP, each row RIGHT-TO-LEFT: PSHU pre-decrements U, so
        stores march toward lower addresses, matching Glen's layout."""
        h = len(packed); w = len(packed[0])
        # U starts just past the cel's last (bottom-right) byte
        self.emit('LEAU', f'{(h-1)*STRIDE+w},U', 5, ('leau', (h - 1) * STRIDE + w))
        u = (h - 1) * STRIDE + w                       # U offset, cel-local
        for y in range(h - 1, -1, -1):
            x = w - 1
            while x >= 0:
                val, keep, cls = packed[y][x]
                if cls == 'skip':
                    x -= 1; continue
                if cls == 'mixed':
                    d = (y * STRIDE + x) - u           # signed offset from U
                    self.emit('LDA', f'{d},U', 4 + self._ix(d), ('load', y * STRIDE + x))
                    self.emit('ANDA', f'#${keep:02X}', 2, ('and', keep))
                    self.emit('ORA', f'#${val:02X}', 2, ('or', val))
                    self.emit('STA', f'{d},U', 4 + self._ix(d), ('store1', y * STRIDE + x))
                    self.reg['D'] = None               # A clobbered -> D unknown
                    x -= 1; continue
                # gather a run of consecutive 'store' bytes ending at x
                run = []
                while x >= 0 and packed[y][x][2] == 'store':
                    run.append(packed[y][x][0]); x -= 1
                run.reverse()                          # left-to-right values
                start = x + 1
                u = self._emit_run(run, y, start, u)
            # end row
        return self.ins

    @staticmethod
    def _ix(d):
        return 1 if -128 <= d <= 127 else 4

    def _emit_run(self, run, y, start, u):
        """Emit stores for run (left-to-right byte values) at row y, cols start..
        Uses PSHU bursts of 6/4/2 where possible (U must already point just past
        the run's right edge), else STD/STA at explicit offsets."""
        end = start + len(run)                          # one past last col
        target_u = y * STRIDE + end                     # PSHU needs U here
        i = len(run)
        while i > 0:
            if i >= 2:
                if u != target_u - (len(run) - i):
                    d = (target_u - (len(run) - i)) - u
                    self.emit('LEAU', f'{d},U', 4 + self._ix(d), ('leau_rel', d))
                    u += d
                take = 6 if i >= 6 else (4 if i >= 4 else 2)
                chunk = run[i - take:i]
                regs = []
                for j in range(0, take, 2):
                    v = (chunk[j] << 8) | chunk[j + 1]
                    r = ['Y', 'X', 'D'][j // 2] if take == 6 else (['X', 'D'][j // 2] if take == 4 else 'D')
                    self.load(r, v); regs.append(r)
                order = {6: 'D,X,Y', 4: 'D,X', 2: 'D'}[take]
                self.emit('PSHU', order, 5 + take, ('pshu', take, chunk))
                u -= take; i -= take
            else:
                col = start + (i - 1); d = (y * STRIDE + col) - u
                self.emit('LDA', f'#${run[i-1]:02X}', 2)
                self.emit('STA', f'{d},U', 4 + self._ix(d), ('store1', y * STRIDE + col))
                self.reg['D'] = None
                i -= 1
        return u

# ---------------------------------------------------------------- 5. simulate
def simulate(ins, packed, canary=0xA5):
    """Execute the instruction list against a virtual buffer prefilled with a
    canary, then verify: opaque positions hold the sprite value; transparent
    positions still hold the canary (background preserved)."""
    h = len(packed); w = len(packed[0])
    size = (h + 2) * STRIDE + 256
    mem = bytearray([canary]) * size
    ORIGIN = 64                                       # cel-local 0 lands here
    u = ORIGIN; A = None; D = {'D': None, 'X': None, 'Y': None}
    for it in ins:
        m, e = it['m'], it['eff']
        if m == 'LEAU':
            u += e[1] if e and e[0] == 'leau' else e[1]
        elif m.startswith('LD') and m[2] in 'DXY':
            D[m[2]] = int(it['o'][2:], 16)
        elif m == 'LDA':
            if it['o'].startswith('#'): A = int(it['o'][2:], 16)
            else: A = mem[e[1] + ORIGIN]
        elif m == 'ANDA': A &= e[1]
        elif m == 'ORA':  A |= e[1]
        elif m == 'STA':  mem[e[1] + ORIGIN] = A
        elif m == 'PSHU':
            take, chunk = e[1], e[2]
            for v in reversed(chunk):
                u -= 1; mem[u] = v
    bad = []
    for y in range(h):
        for x in range(w):
            val, keep, cls = packed[y][x]
            got = mem[y * STRIDE + x + ORIGIN]
            if cls == 'skip':
                want = canary
            elif cls == 'store':
                want = val
            else:
                want = (canary & keep) | val
            if got != want:
                bad.append((y, x, cls, want, got))
    return bad

def cycles(ins): return sum(i['c'] for i in ins)
