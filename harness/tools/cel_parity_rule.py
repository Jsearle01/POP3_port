#!/usr/bin/env python3
r"""cel_parity_rule.py — predict a cel's artifact-colour PARITY from source data.

THE RULE, and it is explicit in the oracle rather than inferred [CTRLSUBS.S:805-838]:

    lda Fdx
    jsr addcharx        ; A := CharX + Fdx
    sec
    sbc #ScrnLeft       ; different coord system   (ScrnLeft = 58, EQ.S:479)
    sta FCharX
    asl FCharX          ; X := 2X        <-- THE DOUBLING
    rol FCharX+1
    ...
    lda Fcheck
    eor FCharFace       ; Look only at the hibits
    bmi :ok             ; They don't match --> even X-coord
                        ; They match       --> odd X-coord
    lda FCharX
    clc
    adc #1              ; +1  ==  make it odd

So the draw X is  2*(CharX + Fdx - ScrnLeft)  plus 0 or 1. **Because it is DOUBLED,
CharX cannot affect the parity at all** — the doubled term is always even, and the
low bit comes entirely from the Fcheck/CharFace comparison:

    ODD   iff  bit7(Fcheck) == bit7(CharFace)
    EVEN  otherwise

WHAT THIS EXPLAINS. P3.22 found the vizier's parity "derived correctly from CharX=197
(odd)" and the princess's did not (CharX=120, even, needed --flip-parity). Both are
ODD under this rule, and the vizier's agreement with CharX was COINCIDENCE: 197 happens
to be odd, and the rule happens to say odd. Reading a rule off one agreeing case is
what sent P3.22 and P3.23 hunting geometry that could never have explained it.

WHAT IT PREDICTS, and this is the part that matters. Fcheck varies BETWEEN CELS OF THE
SAME CHARACTER, so parity is a per-CEL property, not a per-character one. Any scheme
that converts a character's whole cel set at one parity is wrong for some of them.
"""
import pathlib
import re
import sys

# ★ P5.29: was pathlib.Path("C:/Projects/POP3_port") -- a stale second clone (CLAUDE.md §2G
# v1.3). Derived from this file instead, like hal_sync_check.py. Six other tools still carry
# the literal (P5.29 report §7); they are not swept here.
ROOT = pathlib.Path(__file__).resolve().parents[2]
FRAMEDEF = ROOT / "oracle/source/01 POP Source/Source/FRAMEDEF.S"

# CharFace = -1 for both cutscene characters at startP0/startV0 [SUBS.S:1131,1147]
FACE_LEFT = 0xFF
FACE_RIGHT = 0x01

ENTRY = re.compile(r"^:(\d+)\s+db\s+"
                   r"\$([0-9a-fA-F]{2}),"          # Fimage
                   r"\$?([0-9a-fA-F$+]+),"         # Fsword
                   r"(-?\d+),"                     # Fdx
                   r"(-?\d+),"                     # Fdy
                   r"\$?([0-9a-fA-F]{2})")         # Fcheck


def altset2():
    """cel number -> (Fimage, Fdx, Fdy, Fcheck, comment) from ALTSET2 (chtable6)."""
    lines = FRAMEDEF.read_text(errors="replace").splitlines()
    start = next(i for i, l in enumerate(lines) if l.strip() == "ALTSET2")
    out = {}
    for l in lines[start + 1:]:
        if "Sword images" in l:
            break
        m = ENTRY.match(l.strip())
        if m:
            note = l.split(";", 1)
            out[int(m.group(1))] = (int(m.group(2), 16), int(m.group(4)), int(m.group(5)),
                                    int(m.group(6), 16),
                                    note[1].strip() if len(note) > 1 else "")
    return out


def parity(fcheck, face=FACE_LEFT):
    """1 = odd, 0 = even. bit7 match -> odd."""
    return 0 if ((fcheck ^ face) & 0x80) else 1


def draw_x(charx, fdx, fcheck, face=FACE_LEFT, awid=None):
    """The oracle's own FCharX, for the record. ScrnLeft = 58 [EQ.S:479].

    awid = the Apple sprite's width in BYTES. Pass it whenever the draw may be MIRRORED:
    a mirrored image is laid down one sprite-width to the LEFT of the same coordinate
    (MLayGen: LDA XCO / SEC / SBC WIDTH [HIRES.S:1202-1208]), which is what makes
    `aboutface,chx,N` a registration correction rather than a step. Omitting it for a
    right-facing character reproduces the P3.72g bug offline — the checker then predicts
    a position the engine does not draw at, and the two disagree by ~one byte column.
    """
    x = 2 * (charx + fdx - 58) + parity(fcheck, face)
    if awid is not None and face != FACE_LEFT:
        x -= 7 * awid                       # an Apple byte is 7 px
    return x


IMAGES = ROOT / "oracle/source/01 POP Source/Images"
CHTAB = IMAGES / "IMG.CHTAB6.A"          # kept: the table MOST cels come from

# ── WHICH FILE A CEL COMES FROM (P3.95) ──────────────────────────────────────────────
#
# ★★ A CEL NUMBER IS NOT AN INDEX INTO ONE FILE. `decodeim` [CTRLSUBS.S:1017-1037] turns a
# frame's (Fimage, Fsword) into a TABLE and an IMAGE:
#
#     FCharTable = (Fimage bit 7) as bit 2, plus (Fsword bits 6-7) as bits 0-1  -> 0..7
#     FCharImage = Fimage & $7F                                                 -> 0..127
#
# Everything here used to compute the second and hard-code the first as IMG.CHTAB6.A. For
# the 77 ALTSET2 frames that really are chtable6 that was right; for the eight `vcast-*`
# frames 78..85 it was not, and they were converted from 13-row 2-byte stubs where the
# real cels are 48-50 rows. Cels are stored bottom-up, so the port drew the vizier's FEET
# and nothing above them for a frame at his raise and at his turn — reported by Jay across
# three gates before it was found.
#
# ★ AND altset2() PARSED Fsword AND THREW IT AWAY, which is why nothing downstream could
# notice: the field that decides the file was read out of the source and discarded one
# line later. It is kept here instead, in ONE place, so the converter, the width lookup
# and the checker cannot disagree about which file a cel lives in.
#
# FILE NUMBER = SLOT + 1, from the oracle's own comments in three independent places:
#     GAMEBG.S:140     startable = 0  ;chtable1
#     CTRLSUBS.S:1053  lda #2         ;chtable3
#     GAMEBG.S:887     lda #5         ;chtable6
SLOT_FILE = {0: "IMG.CHTAB1", 1: "IMG.CHTAB2", 2: "IMG.CHTAB3",
             4: "IMG.CHTAB5", 5: "IMG.CHTAB6.A", 6: "IMG.CHTAB7"}
_TAB = {}


def _fsword():
    """cel -> Fsword, which altset2() drops. Same section, same entry shape."""
    lines = FRAMEDEF.read_text(errors="replace").splitlines()
    start = next(i for i, l in enumerate(lines) if l.strip() == "ALTSET2")
    out = {}
    for l in lines[start + 1:]:
        if "Sword images" in l:
            break
        m = ENTRY.match(l.strip())
        if m:
            sw = m.group(3).lstrip("$")
            try:
                out[int(m.group(1))] = int(sw, 16)
            except ValueError:
                pass                    # an expression rather than a literal; skip it
    return out


def chartable(cel):
    """(FCharTable, FCharImage) for a cel, exactly as `decodeim` computes them."""
    if not _TAB:
        sw = _fsword()
        for n, (fimg, _fdx, _fdy, _fchk, _lab) in altset2().items():
            ztemp = fimg & 0x80
            a = ((sw.get(n, 0) & 0xC0) >> 1)
            _TAB[n] = (((a + ztemp) & 0xFF) >> 5, fimg & 0x7F)
    return _TAB.get(cel)


def table_path(cel):
    """The image FILE this cel's frame names. Raises rather than guessing."""
    t = chartable(cel)
    if t is None:
        raise KeyError("cel %r is not in ALTSET2" % cel)
    slot = t[0]
    if slot not in SLOT_FILE:
        raise KeyError("cel %d names table slot %d, which has no file mapped — the "
                       "oracle loads one per level and this scene has never used it"
                       % (cel, slot))
    return IMAGES / SLOT_FILE[slot]


_AWID = {}


def awid(cel):
    """Apple sprite width in BYTES for a cel number, read from ITS OWN table file.

    ONE HOME for the mirror anchor (P3.72g). gen_cel_table.py emits the same number into
    the engine's cel_table and co_setup applies it; every offline consumer that models a
    facing must take it from here, or the checker and the engine place mirrored cels a
    byte-column apart and the disagreement looks like a draw bug.

    ★ P3.95: this read IMG.CHTAB6.A for every cel, so the eight frames that live in
    IMG.CHTAB7 got the width of an unrelated 2-byte stub. Same root cause as the pixels.
    """
    if not _AWID:
        import sprite_convert as SC
        for n in altset2():
            try:
                _AWID[n] = SC.get_cel(str(table_path(n)), chartable(n)[1])["w"]
            except Exception:
                pass                    # empty slot; the caller gets None and skips it
    return _AWID.get(cel)


# ── GAMEPLAY (P5.29): the same rule over Fdef, ALTSET1 and SWORDTAB ──────────────────
#
# ★★ altset2() ABOVE IS LEFT EXACTLY AS IT WAS, because the shipped cutscene is baked through
# it and must not move. But its ENTRY regex silently SKIPS any line whose fields are
# expressions or bare decimals -- and the gameplay tables are full of them:
#
#     :135 db $0d,$80,-5+5,51-63,$00+1        Fdx/Fdy are expressions
#     :206 db $a3,0,0,0,0                     Fcheck is a bare decimal
#
# Those are real frames (135-140 are the CHTAB3 #13-18 climb cels; 206 is CHTAB5 #35). A
# count taken through the regex (P5.28's "220 frames", P5.27's "named by NO frame def") is
# missing them without a word. So the gameplay side evaluates every field as the
# assembler does -- terms joined by + and -, each $hex or decimal -- and refuses a line it
# cannot read rather than dropping it.

_LINE = re.compile(r"^:(\d+)\s+db\s+(.*)$")


def _expr(s):
    """A Merlin `db` operand: terms joined by + / -, each $hex or decimal."""
    s = s.strip().replace(" ", "")
    total, sign, tok = 0, 1, ""
    for ch in s + "+":
        if ch in "+-" and tok:
            total += sign * (int(tok[1:], 16) if tok.startswith("$") else int(tok))
            sign, tok = (1 if ch == "+" else -1), ""
        elif ch in "+-":
            sign = -sign if ch == "-" else sign
        else:
            tok += ch
    return total


def frame_table(name):
    """{n: (Fimage, Fsword, Fdx, Fdy, Fcheck)} for Fdef / ALTSET1 / ALTSET2, every field
    EVALUATED. All-zero entries (blank slots) are kept; the caller decides."""
    lines = FRAMEDEF.read_text(errors="replace").splitlines()
    start = next(i for i, l in enumerate(lines) if l.strip() == name)
    out = {}
    for l in lines[start + 1:]:
        s = l.split(";", 1)[0].strip()
        if s in ("Fdef", "ALTSET1", "ALTSET2", "SWORDTAB") or "Sword images" in l:
            break
        m = _LINE.match(s)
        if not m:
            continue
        f = [_expr(t) & 0xFF if i in (0, 1, 4) else _expr(t)
             for i, t in enumerate(m.group(2).split(","))]
        if len(f) != 5:
            raise SystemExit("FRAMEDEF %s :%s has %d fields, not 5: %r" % (name, m.group(1), len(f), s))
        out[int(m.group(1))] = tuple(f)
    return out


def swordtab():
    """{n: (image, dx, dy)} -- SETUPSWORD's table [CTRLSUBS.S:867-895]; the image is always
    chtable3 (decodeswim, CTRLSUBS.S:1050)."""
    lines = FRAMEDEF.read_text(errors="replace").splitlines()
    start = next(i for i, l in enumerate(lines) if l.strip() == "SWORDTAB")
    out = {}
    for l in lines[start + 1:]:
        m = _LINE.match(l.split(";", 1)[0].strip())
        if m:
            f = [_expr(t) for t in m.group(2).split(",")]
            out[int(m.group(1))] = (f[0] & 0xFF, f[1], f[2])
    return out


def decode_table(fimage, fsword):
    """decodeim [CTRLSUBS.S:1017-1037] -> (slot, image): the same arithmetic chartable() does."""
    return ((((fsword & 0xC0) >> 1) + (fimage & 0x80)) & 0xFF) >> 5, fimage & 0x7F


def gameplay_uses():
    """Every way a gameplay cel is drawn, as {(slot, image): {PL: [why, ...]}}.

    PL = the PARITY of the draw X when the character FACES LEFT (unmirrored). Facing right,
    the same frame's X has the OPPOSITE parity: for a character cel parity() flips with the
    face bit; for a sword the X is the character's FCharX plus SWORDTAB's dx, NOT doubled
    [CTRLSUBS.S:887-888 -> ADDFCHARX], so it inherits the flip and adds dx's parity.

      character cel (Fdef, ALTSET1):  PL = parity(Fcheck, FACE_LEFT)
      sword cel (frame's Fsword&$3F): PL = parity(Fcheck, FACE_LEFT) XOR (dx odd)

    Fdef is the kid's and the guard's main set; ALTSET1 is the guard's (usealtsets,
    CTRLSUBS.S:1680-1707). ALTSET2 is the cutscene's and is not a gameplay use."""
    uses = {}
    sw = swordtab()
    for tab in ("Fdef", "ALTSET1"):
        for n, (fi, fs, fdx, fdy, fc) in frame_table(tab).items():
            if fi == 0 and fs == 0:
                continue
            pl = parity(fc, FACE_LEFT)
            if fi:
                uses.setdefault(decode_table(fi, fs), {}).setdefault(pl, []).append("%s:%d" % (tab, n))
            k = fs & 0x3F
            if k and k in sw and sw[k][0]:
                spl = pl ^ (sw[k][1] & 1)
                uses.setdefault((2, sw[k][0]), {}).setdefault(spl, []).append("%s:%d sword%d" % (tab, n, k))
    return uses


GROUPS = [("Vwalk", [48, 49, 50, 51, 52, 53], 197),
          ("Vstand", [54], 197),
          ("Vstop", [55, 56], 197),
          ("Vexit", [57, 58, 59, 60, 61, 62, 63, 64, 65, 66], 197),
          ("Vraise", [85, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 83, 84], 197),
          ("Pstand", [11], 120),
          ("Palert", [2, 3, 4, 5, 6, 7, 8, 9], 120),
          ("Pslump", [1, 18], 120)]


def main():
    alt = altset2()
    print("PARITY RULE  [CTRLSUBS.S:805-838]:  ODD iff bit7(Fcheck) == bit7(CharFace)")
    print("CharX is DOUBLED before the +1, so it cannot affect parity at all.")
    print("CharFace = -1 ($FF) for both cutscene characters [SUBS.S:1131,1147].\n")
    print("  %-8s %-4s %-7s %-5s %-6s %-8s %s"
          % ("seq", "cel", "Fcheck", "Fdx", "parity", "FCharX", "label"))
    mixed = {}
    for name, cels, charx in GROUPS:
        seen = set()
        for n in cels:
            if n not in alt:
                continue
            fimg, fdx, fdy, fchk, lab = alt[n]
            p = parity(fchk)
            seen.add(p)
            print("  %-8s %-4d $%02X     %-5d %-6s %-8d %s"
                  % (name, n, fchk, fdx, "ODD" if p else "EVEN",
                     draw_x(charx, fdx, fchk), lab[:26]))
        if len(seen) > 1:
            mixed[name] = True
    print()
    if mixed:
        print("  MIXED PARITY WITHIN A SEQUENCE: %s" % ", ".join(sorted(mixed)))
        print("  -> parity is a per-CEL property. Converting a character's set at one")
        print("     parity is wrong for some of its own frames.")
    else:
        print("  every sequence listed is internally uniform")
    return 0


if __name__ == "__main__":
    sys.exit(main())
