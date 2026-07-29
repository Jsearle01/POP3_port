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

ROOT = pathlib.Path("C:/Projects/POP3_port")
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


def draw_x(charx, fdx, fcheck, face=FACE_LEFT):
    """The oracle's own FCharX, for the record. ScrnLeft = 58 [EQ.S:479]."""
    return 2 * (charx + fdx - 58) + parity(fcheck, face)


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
