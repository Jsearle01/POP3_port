#!/usr/bin/env python3
r"""
sprite_compiler.py — PRODUCTION compiled-sprite compiler for the POP CoCo3 port.

Consumes the P1.2 tooling's output (converted.s + opacity.s) and emits, per cel,
three straight-line 6809 routines:

    _draw_<cel>     paint the cel into the framebuffer
    _save_<cel>     copy the bytes the draw will touch into a peel buffer
    _erase_<cel>    put them back (POP peels; see "ERASE MODEL" below)

This SUPERSEDES poc/compiled-sprite/popcc.py, which was an explicitly throwaway
PA.9 measurement instrument. That POC's 6.44 cy/byte draw was an UPPER BOUND
because Glen Hewlett's optimizations were left out. They are in, here, and
measured from the real emitted instructions.

--------------------------------------------------------------------------------
THE PSHU BYTE ORDER — verified on hardware, not assumed
--------------------------------------------------------------------------------
    LDD #$A1A2 / LDX #$B1B2 / LDY #$C1C2 / PSHU D,X,Y
  leaves, ASCENDING from the final U:   A1 A2 B1 B2 C1 C2
  i.e.  run[0:2] -> D,   run[2:4] -> X,   run[4:6] -> Y.

Measured with src/harness/pshu_probe.s on the real 6809 under MAME (P1.3).
**The PA.9 POC had this inverted** (it assigned run[0:2]->Y ... run[4:6]->D), and
its simulator replayed the chunk list rather than modelling registers, so its
soundness check was structurally incapable of detecting the error. That is the
P1.2-fix lesson again: a checker downstream of an assumption cannot test it.
The simulator here executes REGISTERS, so an inverted mapping fails the diff.

--------------------------------------------------------------------------------
GLEN'S OPTIMIZATIONS (all four, per the P1.3 dispatch)
--------------------------------------------------------------------------------
 1. PSHU D,X,Y 6-byte bursts for opaque runs — 11 cycles for 6 bytes.
    Burst width is chosen by COST, not greedily: a 2-byte run is cheaper as
    STD d,U (6 cy, and U does not move) than as PSHU D (7 cy + a LEAU to
    reposition U). Glen mixes PSHU/STD/STX/STA for exactly this reason.
 2. Cross-push register reuse — D/X/Y liveness is tracked across the WHOLE
    routine, not per row. A load is emitted only when the needed value is not
    already live. Flat colour areas make the same 6-byte pattern recur, so all
    three loads vanish. (The POC tracked liveness per row only.)
 3. 16-bit RMW coalescing — two adjacent mixed bytes become
    LDD/ANDA/ANDB/ORA/ORB/STD (20 cy) instead of two 8-bit RMWs (28 cy).
    AND/OR halves are skipped when the mask/value makes them no-ops.
 4. Known-zero-background ORA-only merge — OFF BY DEFAULT, see below.

 Plus opaque-black exploitation (PA.9 §6.4): a black pixel MARKED OPAQUE in
 opacity.s is a stored value, so its byte is a plain store and joins a PSHU run
 instead of being an expensive mixed RMW. Unmarked black stays keyed.

--------------------------------------------------------------------------------
OPTIMIZATION 4 IS CONDITIONAL — and the default is the correct, slower form
--------------------------------------------------------------------------------
If the destination byte is known to be zero, a mixed byte needs no read at all:
it collapses to a plain store and joins the PSHU runs. That is a large win.

It is only valid if the back buffer is CLEARED before the cel is drawn. **POP
does not work that way**: POP PEELS — LAYRSAVE (HIRES.S) stores the background
under each character and PEEL restores it, precisely so the engine never has to
clear and redraw the whole screen. Under a peel model the background beneath a
sprite is live scenery, not zero, and an ORA-only merge would smear the sprite
over it.

So `--bg-zero` exists, is implemented, is measured (§ the report), and is OFF by
default. Turning it on is a statement about the engine's draw model that the
engine does not yet make. Correctness beats a lower cy/byte.

--------------------------------------------------------------------------------
ERASE MODEL — POP peels, so erase is restore-from-saved, not zero-fill
--------------------------------------------------------------------------------
Glen's _Restore_ reads a STATIC background image through a second pointer (LEAY
$6500,U) and PSHUs it back. POP's equivalent background is dynamic, so the
compiler emits a matched save/erase pair over EXACTLY the byte set the draw
touches (not the bounding box — transparent bytes are never written, so they
never need saving):

    _save_  : LDD/LDX from the framebuffer (U), STD/STX into the peel buffer (Y)
    _erase_ : LDD/LDX from the peel buffer (Y), PSHU D,X back into the frame (U)

U is the framebuffer cursor in all three; Y is the peel-buffer cursor and walks
forward monotonically, so save and erase agree byte-for-byte by construction.
Erase bursts are 4 bytes (PSHU D,X) because Y is occupied as the source pointer
— the same shape Glen's _Restore_ uses.

Usage:
  python harness/tools/sprite_compiler.py content/kid/kid_chtab1_064_thin
  python harness/tools/sprite_compiler.py --all content --out build/compiled
  python harness/tools/sprite_compiler.py --all content --bg-zero      (see above)
"""
import sys
import argparse
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "sprite_tool"))

from celio import Cel
import sidecar as SC

T = 4                     # transparent token (distinct from opaque black = 0)
PXB = 4                   # CoCo3 2bpp: 4 px/byte, MSB-first
STRIDE = 80               # 320 px / 4 px per byte


# ------------------------------------------------------------------ cel -> tokens
def expand_opacity(cel, side):
    """opacity.s payload -> h x (w*4) bool grid. True = that index-0 pixel is OPAQUE.

    Contract (sprite_tool/opacity.py, verbatim): opacity is meaningful ONLY for
    index-0 (black) pixels — is this black pixel OPAQUE (shadow, stored solid) or
    KEYED (transparent)? Non-0 pixels are always drawn.
    """
    op = [[False] * (cel.w * 4) for _ in range(cel.h)]
    if not side:
        return op, "none"
    kind, payload = side
    if kind == "mixed":
        for sc, w, sr, nr, opq in payload:
            if opq:
                for r in range(sr, min(sr + nr, cel.h)):
                    for c in range(sc, min(sc + w, cel.w)):
                        for k in range(4):
                            op[r][c * 4 + k] = True
    elif kind == "masked":
        for c, b in enumerate(payload[:cel.w]):
            for k in range(4):
                if (b >> (6 - 2 * k)) & 3:
                    for r in range(cel.h):
                        op[r][c * 4 + k] = True
    elif kind == "stencil":
        for r, row in enumerate(payload[:cel.h]):
            for c, b in enumerate(row[:cel.w]):
                for k in range(4):
                    if (b >> (6 - 2 * k)) & 3:
                        op[r][c * 4 + k] = True
    return op, kind


def tokenize(cel, op):
    """pixels + opacity -> token grid. 0..3 opaque (0 = opaque black, DRAWN), T = keyed."""
    out = []
    for r in range(cel.h):
        row = []
        for c in range(cel.w * 4):
            v = cel.pixels[r][c]
            row.append(v if v != 0 else (0 if op[r][c] else T))
        out.append(row)
    return out


def pack(tokens):
    """token rows -> per-byte (value, keepmask, cls). cls: skip|store|mixed."""
    packed = []
    for row in tokens:
        wb = (len(row) + PXB - 1) // PXB
        pr = []
        for b in range(wb):
            val = keep = nop = ntr = 0
            for k in range(PXB):
                x = b * PXB + k
                t = row[x] if x < len(row) else T
                sh = 6 - 2 * k
                if t == T:
                    ntr += 1
                    keep |= 0b11 << sh
                else:
                    nop += 1
                    val |= (t & 0b11) << sh
            pr.append((val, keep, 'skip' if nop == 0 else ('store' if ntr == 0 else 'mixed')))
        packed.append(pr)
    return packed


# ------------------------------------------------------------------ 6809 costs
def idx(d):
    """Indexed addressing extra cycles for a constant offset from a register."""
    if d == 0:
        return 0
    if -16 <= d <= 15:
        return 1                     # 5-bit offset
    if -128 <= d <= 127:
        return 1                     # 8-bit offset
    return 4                         # 16-bit offset


IMM = {'A': 2, 'B': 2, 'D': 3, 'X': 3, 'Y': 4}          # LDr immediate (Y is page-2)
LD_IDX = {'A': 4, 'B': 4, 'D': 5, 'X': 5, 'Y': 6}       # LDr indexed base
ST_IDX = {'A': 4, 'B': 4, 'D': 5, 'X': 5, 'Y': 6}       # STr indexed base


class Emitter:
    """Emits (mnemonic, operand, cycles, effect) and tracks U + D/X/Y liveness."""

    def __init__(self):
        self.ins = []
        self.u = 0                                   # U's cel-local byte offset
        self.live = {'D': None, 'X': None, 'Y': None}

    def emit(self, m, o, c, eff=None):
        self.ins.append(dict(m=m, o=o, c=c, eff=eff))

    # -- register liveness (OPTIMIZATION 2) --------------------------------
    def need(self, r, val16):
        """Ensure register r holds val16. Emits a load ONLY on a change."""
        if self.live[r] == val16:
            return True                              # elided — the whole point
        self.emit(f'LD{r}', f'#${val16:04X}', IMM[r], ('ld', r, val16))
        self.live[r] = val16
        return False

    def clobber(self, *regs):
        for r in regs:
            self.live[r] = None

    def setu(self, target):
        """Move U to a cel-local offset, if it is not already there."""
        if self.u == target:
            return
        d = target - self.u
        self.emit('LEAU', f'{d},U', 4 + idx(d), ('leau', d))
        self.u = target

    def cycles(self):
        return sum(i['c'] for i in self.ins)


# ------------------------------------------------------------------ DRAW
def emit_draw(packed, bg_zero=False):
    """Compile the draw. Returns an Emitter.

    Row order is top-to-bottom; within a row, opaque runs are emitted
    right-to-left because PSHU pre-decrements U.
    """
    e = Emitter()
    h, w = len(packed), len(packed[0])

    for y in range(h):
        x = w - 1
        while x >= 0:
            val, keep, cls = packed[y][x]

            if cls == 'skip':
                x -= 1
                continue

            if cls == 'mixed' and not bg_zero:
                # OPTIMIZATION 3: coalesce with the byte to the LEFT if it is
                # also mixed -> one 16-bit RMW instead of two 8-bit ones.
                if x >= 1 and packed[y][x - 1][2] == 'mixed':
                    v0, k0, _ = packed[y][x - 1]
                    v1, k1, _ = packed[y][x]
                    off = y * STRIDE + (x - 1)
                    d = off - e.u
                    e.emit('LDD', f'{d},U', LD_IDX['D'] + idx(d), ('load16', off))
                    if k0 != 0xFF:
                        e.emit('ANDA', f'#${k0:02X}', 2, ('anda', k0))
                    if k1 != 0xFF:
                        e.emit('ANDB', f'#${k1:02X}', 2, ('andb', k1))
                    if v0:
                        e.emit('ORA', f'#${v0:02X}', 2, ('ora', v0))
                    if v1:
                        e.emit('ORB', f'#${v1:02X}', 2, ('orb', v1))
                    e.emit('STD', f'{d},U', ST_IDX['D'] + idx(d), ('store16', off))
                    e.clobber('D')
                    x -= 2
                    continue
                # single mixed byte: 8-bit RMW
                off = y * STRIDE + x
                d = off - e.u
                e.emit('LDA', f'{d},U', LD_IDX['A'] + idx(d), ('load8', off))
                if keep != 0xFF:
                    e.emit('ANDA', f'#${keep:02X}', 2, ('anda', keep))
                if val:
                    e.emit('ORA', f'#${val:02X}', 2, ('ora', val))
                e.emit('STA', f'{d},U', ST_IDX['A'] + idx(d), ('store8', off))
                e.clobber('D')
                x -= 1
                continue

            # ---- an opaque run (stores; plus mixed bytes when bg is known zero)
            def storeable(bx):
                c = packed[y][bx][2]
                return c == 'store' or (bg_zero and c == 'mixed')

            run_end = x
            while x >= 0 and storeable(x):
                x -= 1
            run_start = x + 1
            vals = [packed[y][c][0] for c in range(run_start, run_end + 1)]
            emit_run(e, vals, y, run_start)

    e.emit('RTS', '', 5)
    return e


def emit_run(e, vals, y, start):
    """Emit stores for `vals` at row y, columns start.. — cost-driven (OPT 1)."""
    i = len(vals)                                    # emit right-to-left
    while i > 0:
        # --- try the widest PSHU burst that pays for itself -------------
        best = None
        for take in (6, 4, 2):
            if i < take:
                continue
            chunk = vals[i - take:i]
            target_u = y * STRIDE + start + i        # U must sit just past the chunk
            cost = 0
            if e.u != target_u:
                cost += 4 + idx(target_u - e.u)      # LEAU
            # PSHU register mapping — HARDWARE-VERIFIED (see module docstring)
            regs = [('D', chunk[0], chunk[1])]
            if take >= 4:
                regs.append(('X', chunk[2], chunk[3]))
            if take >= 6:
                regs.append(('Y', chunk[4], chunk[5]))
            for r, hi, lo in regs:
                if e.live[r] != (hi << 8) | lo:
                    cost += IMM[r]                   # OPT 2: only if not live
            cost += 5 + take                          # PSHU itself
            per = cost / take
            if best is None or per < best[0]:
                best = (per, take, chunk, target_u, regs)

        # --- the direct-store alternative (no U movement) ----------------
        alt = None
        if i >= 2:
            hi, lo = vals[i - 2], vals[i - 1]
            off = y * STRIDE + start + i - 2
            d = off - e.u
            c = ST_IDX['D'] + idx(d) + (0 if e.live['D'] == (hi << 8) | lo else IMM['D'])
            alt = (c / 2, 2, (hi, lo), off, d)
        else:
            v = vals[i - 1]
            off = y * STRIDE + start + i - 1
            d = off - e.u
            c = ST_IDX['A'] + idx(d) + 2             # LDA # + STA
            alt = (c / 1, 1, (v,), off, d)

        if best is not None and best[0] <= alt[0]:
            _, take, chunk, target_u, regs = best
            e.setu(target_u)
            for r, hi, lo in regs:
                e.need(r, (hi << 8) | lo)
            order = {6: 'D,X,Y', 4: 'D,X', 2: 'D'}[take]
            e.emit('PSHU', order, 5 + take, ('pshu', take))
            e.u -= take
            i -= take
        elif alt[1] == 2:
            _, _, (hi, lo), off, d = alt
            e.need('D', (hi << 8) | lo)
            d = off - e.u
            e.emit('STD', f'{d},U', ST_IDX['D'] + idx(d), ('store16', off))
            i -= 2
        else:
            _, _, (v,), off, d = alt
            d = off - e.u
            e.emit('LDA', f'#${v:02X}', 2, ('lda_imm', v))
            e.emit('STA', f'{d},U', ST_IDX['A'] + idx(d), ('store8', off))
            e.clobber('D')
            i -= 1


# ------------------------------------------------------------------ SAVE / ERASE
def touched_offsets(packed, bg_zero=False):
    """Every framebuffer byte offset the draw writes, ascending. Transparent
    bytes are never written, so they are never saved either."""
    offs = []
    for y, row in enumerate(packed):
        for x, (_, _, cls) in enumerate(row):
            if cls != 'skip':
                offs.append(y * STRIDE + x)
    return offs


def emit_save(offs):
    """Framebuffer (U) -> peel buffer (Y++). Pairs adjacent offsets into 16-bit moves."""
    e = Emitter()
    i = 0
    while i < len(offs):
        if i + 1 < len(offs) and offs[i + 1] == offs[i] + 1:
            d = offs[i] - e.u
            e.emit('LDD', f'{d},U', LD_IDX['D'] + idx(d), ('load16', offs[i]))
            e.emit('STD', ',Y++', ST_IDX['D'] + 3, ('save16', offs[i]))
            e.clobber('D')
            i += 2
        else:
            d = offs[i] - e.u
            e.emit('LDA', f'{d},U', LD_IDX['A'] + idx(d), ('load8', offs[i]))
            e.emit('STA', ',Y+', ST_IDX['A'] + 2, ('save8', offs[i]))
            e.clobber('D')
            i += 1
    e.emit('RTS', '', 5)
    return e


def emit_erase_rect(h, w):
    """RECTANGLE restore — the model POP actually uses.

    LAYRSAVE (HIRES.S) does `inc WIDTH ; extra byte to cover shift right`, then
    CROP, and saves the resulting RECTANGLE; PEEL puts it back through
    fastlaySTA, an unmasked rectangle blit. So POP's peel cost is a function of
    the cel's BOUNDING BOX, not of how many bytes the sprite actually inks — it
    is CONSTANT with respect to opacity.

    That matters for the opaque-black trade (PA.9 §6.4): under a byte-set erase,
    marking black opaque draws more bytes and therefore costs more to restore,
    which can swallow the draw saving. Under POP's rectangle peel it cannot —
    the erase is the same either way, so the draw saving is kept.

    Rows are contiguous, so this bursts PSHU D,X (4 bytes) with ,--Y
    auto-decrement on the peel-buffer pointer — Glen's _Restore_ shape.
    """
    e = Emitter()
    for y in range(h - 1, -1, -1):
        x = w
        while x > 0:
            if x >= 4:
                e.setu(y * STRIDE + x)
                e.emit('LDX', ',--Y', LD_IDX['X'] + 3, ('rload16', 2))
                e.emit('LDD', ',--Y', LD_IDX['D'] + 3, ('rload16', 0))
                e.emit('PSHU', 'D,X', 5 + 4, ('rpshu', 4, y * STRIDE + x - 4))
                e.u -= 4
                x -= 4
            elif x >= 2:
                e.setu(y * STRIDE + x)
                e.emit('LDD', ',--Y', LD_IDX['D'] + 3, ('rload16', 0))
                e.emit('PSHU', 'D', 5 + 2, ('rpshu', 2, y * STRIDE + x - 2))
                e.u -= 2
                x -= 2
            else:
                e.setu(y * STRIDE + x)
                e.emit('LDA', ',-Y', LD_IDX['A'] + 2, ('rload8', 0))
                e.emit('PSHU', 'A', 5 + 1, ('rpshu', 1, y * STRIDE + x - 1))
                e.u -= 1
                x -= 1
            e.clobber('D', 'X')
    e.emit('RTS', '', 5)
    return e


def emit_erase(offs):
    """Peel buffer (Y) -> framebuffer (U). PSHU D,X bursts of 4 (Y is the source
    pointer, so Y cannot join the burst) — the shape Glen's _Restore_ uses."""
    e = Emitter()
    # walk descending so PSHU's pre-decrement fills upward
    i = len(offs)
    while i > 0:
        run = 1
        while run < 4 and i - run - 1 >= 0 and offs[i - run - 1] == offs[i - run] - 1:
            run += 1
        if run >= 4:
            base = offs[i - 4]
            e.setu(base + 4)
            e.emit('LDD', '-4,Y', LD_IDX['D'] + 1, ('rload16', 0))
            e.emit('LDX', '-2,Y', LD_IDX['X'] + 1, ('rload16', 2))
            e.emit('PSHU', 'D,X', 5 + 4, ('rpshu', 4, base))
            e.emit('LEAY', '-4,Y', 4 + 1, ('leay', -4))
            e.u -= 4
            i -= 4
        elif run >= 2:
            base = offs[i - 2]
            d = base - e.u
            e.emit('LDD', '-2,Y', LD_IDX['D'] + 1, ('rload16', 0))
            e.emit('STD', f'{d},U', ST_IDX['D'] + idx(d), ('rstore16', base))
            e.emit('LEAY', '-2,Y', 4 + 1, ('leay', -2))
            i -= 2
        else:
            base = offs[i - 1]
            d = base - e.u
            e.emit('LDA', '-1,Y', LD_IDX['A'] + 1, ('rload8', 0))
            e.emit('STA', f'{d},U', ST_IDX['A'] + idx(d), ('rstore8', base))
            e.emit('LEAY', '-1,Y', 4 + 1, ('leay', -1))
            i -= 1
        e.clobber('D', 'X')
    e.emit('RTS', '', 5)
    return e


# ------------------------------------------------------------------ SIMULATE
def simulate(ins, packed, canary=0xA5, bg_zero=False):
    """Execute the emitted instructions with REAL REGISTERS against a virtual
    framebuffer, then diff against what the cel should look like.

    This is the anchored check: it does NOT replay the emitter's intent, it
    executes A/B/X/Y/U and the hardware-verified PSHU semantics. An inverted
    register mapping (the PA.9 POC's bug) fails here.
    """
    h, w = len(packed), len(packed[0])
    ORIGIN = 4096
    mem = bytearray([canary]) * (ORIGIN + (h + 2) * STRIDE + 4096)
    A = B = 0
    X = Y = 0
    U = ORIGIN

    for it in ins:
        m, o, eff = it['m'], it['o'], it['eff']
        if m == 'RTS':
            break
        if m == 'LEAU':
            U += eff[1]
        elif m == 'LDD' and o.startswith('#'):
            v = int(o[2:], 16); A, B = v >> 8, v & 0xFF
        elif m == 'LDX' and o.startswith('#'):
            X = int(o[2:], 16)
        elif m == 'LDY' and o.startswith('#'):
            Y = int(o[2:], 16)
        elif m == 'LDA' and o.startswith('#'):
            A = int(o[2:], 16)
        elif m == 'LDD':
            a = ORIGIN + eff[1]; A, B = mem[a], mem[a + 1]
        elif m == 'LDA':
            A = mem[ORIGIN + eff[1]]
        elif m == 'ANDA':
            A &= eff[1]
        elif m == 'ANDB':
            B &= eff[1]
        elif m == 'ORA':
            A |= eff[1]
        elif m == 'ORB':
            B |= eff[1]
        elif m == 'STA':
            mem[ORIGIN + eff[1]] = A
        elif m == 'STD':
            a = ORIGIN + eff[1]; mem[a] = A; mem[a + 1] = B
        elif m == 'PSHU':
            # HARDWARE-VERIFIED order: ascending from the final U -> A,B,XH,XL,YH,YL
            if o == 'D,X,Y':
                U -= 6
                mem[U], mem[U+1] = A, B
                mem[U+2], mem[U+3] = X >> 8, X & 0xFF
                mem[U+4], mem[U+5] = Y >> 8, Y & 0xFF
            elif o == 'D,X':
                U -= 4
                mem[U], mem[U+1] = A, B
                mem[U+2], mem[U+3] = X >> 8, X & 0xFF
            else:
                U -= 2
                mem[U], mem[U+1] = A, B

    bad = []
    for y in range(h):
        for x in range(w):
            val, keep, cls = packed[y][x]
            got = mem[ORIGIN + y * STRIDE + x]
            if cls == 'skip':
                want = canary                                  # background preserved
            elif cls == 'store':
                want = val
            else:
                want = val if bg_zero else ((canary & keep) | val)
            if got != want:
                bad.append((y, x, cls, want, got))
    return bad


# ------------------------------------------------------------------ ASM OUTPUT
def render_asm(label, e, kind, meta):
    lines = [f"* {label} — {kind}", f"* {meta}", "*",
             "* GENERATED by harness/tools/sprite_compiler.py — do not hand-edit.",
             f"{label}:"]
    for it in e.ins:
        if it['m'] == 'RTS':
            lines.append("        rts")
        else:
            lines.append(f"        {it['m'].lower():<7} {it['o']:<14} * {it['c']:2d}")
    return "\n".join(lines) + "\n"


def compile_cel(cel_dir, bg_zero=False):
    d = pathlib.Path(cel_dir)
    cel = Cel(str(d / "converted.s"))
    op, okind = expand_opacity(cel, SC.read_sidecar(str(d)))
    packed = pack(tokenize(cel, op))

    draw = emit_draw(packed, bg_zero)
    offs = touched_offsets(packed, bg_zero)
    save = emit_save(offs)
    erase = emit_erase(offs)
    bad = simulate(draw.ins, packed, bg_zero=bg_zero)

    cls = {'skip': 0, 'store': 0, 'mixed': 0}
    for row in packed:
        for b in row:
            cls[b[2]] += 1
    total = sum(cls.values())
    drawn = total - cls['skip']

    return dict(name=d.name, cel=cel, packed=packed, opacity=okind,
                draw=draw, save=save, erase=erase, bad=bad,
                total=total, drawn=drawn, **cls,
                dcy=draw.cycles(), ecy=erase.cycles(), scy=save.cycles())


def main():
    ap = argparse.ArgumentParser(description="POP production compiled-sprite compiler")
    ap.add_argument("paths", nargs="+")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--out", default=None, help="write compiled .s files here")
    ap.add_argument("--bg-zero", action="store_true",
                    help="assume the destination is already zero (see module docstring: "
                         "NOT valid under POP's peel model; measurement only)")
    args = ap.parse_args()

    dirs = []
    for p in args.paths:
        if args.all:
            dirs += sorted(q.parent for q in pathlib.Path(p).glob("*/*/converted.s"))
        else:
            dirs.append(pathlib.Path(p))

    print(f"=== sprite_compiler: {len(dirs)} cel(s)"
          + ("  [--bg-zero: known-zero background]" if args.bg_zero else "") + " ===")
    print(f"  {'cel':<28}{'dims':>9} {'opac':<8}{'bytes':>6}{'drawn':>6}{'mix':>5}"
          f"{'draw':>7}{'erase':>7}{'save':>7}  {'d cy/B':>7}{'d+e cy/B':>9}  sound")
    rows = []
    for d in dirs:
        r = compile_cel(d, args.bg_zero)
        rows.append(r)
        de = r['dcy'] + r['ecy']
        print(f"  {r['name']:<28}{r['cel'].h:>4}x{r['cel'].w:<4}{r['opacity']:<8}"
              f"{r['total']:>6}{r['drawn']:>6}{r['mixed']:>5}"
              f"{r['dcy']:>7}{r['ecy']:>7}{r['scy']:>7}"
              f"{r['dcy']/r['total']:>7.2f}{de/r['total']:>9.2f}"
              f"  {'OK' if not r['bad'] else 'UNSOUND(%d)' % len(r['bad'])}")
        for y, x, k, wv, g in r['bad'][:2]:
            print(f"        MISMATCH r{y} c{x} [{k}] want ${wv:02X} got ${g:02X}")
        if args.out:
            o = pathlib.Path(args.out); o.mkdir(parents=True, exist_ok=True)
            meta = (f"{r['cel'].h} rows x {r['cel'].w} bytes, {r['total']} footprint bytes, "
                    f"{r['drawn']} drawn, {r['mixed']} mixed, opacity={r['opacity']}")
            (o / f"{r['name']}.s").write_text(
                render_asm(f"_draw_{r['name']}", r['draw'], "DRAW", meta) + "\n" +
                render_asm(f"_save_{r['name']}", r['save'], "SAVE (framebuffer -> peel buffer)", meta) + "\n" +
                render_asm(f"_erase_{r['name']}", r['erase'], "ERASE (peel buffer -> framebuffer)", meta),
                newline="\n")

    tb = sum(r['total'] for r in rows)
    nd = sum(r['drawn'] for r in rows)
    nm = sum(r['mixed'] for r in rows)
    dc = sum(r['dcy'] for r in rows)
    ec = sum(r['ecy'] for r in rows)
    unsound = sum(1 for r in rows if r['bad'])
    print(f"\n=== AGGREGATE (n={len(rows)}) ===")
    print(f"  SOUNDNESS            : {'ALL PASS' if not unsound else f'{unsound} UNSOUND'}")
    print(f"  footprint bytes      : {tb:,}   drawn {nd:,}   mixed {nm:,} ({100*nm/max(1,nd):.1f}% of drawn)")
    print(f"  draw cycles          : {dc:,}      -> {dc/tb:.2f} cy/footprint-byte")
    print(f"  erase cycles         : {ec:,}      -> {ec/tb:.2f} cy/footprint-byte")
    print(f"  draw+erase           : {dc+ec:,}      -> {(dc+ec)/tb:.2f} cy/footprint-byte")
    print(f"  vs PA.9 POC upper bound 6.44 draw : {6.44/(dc/tb):.2f}x better"
          if dc else "")
    return 1 if unsound else 0


if __name__ == "__main__":
    sys.exit(main())
