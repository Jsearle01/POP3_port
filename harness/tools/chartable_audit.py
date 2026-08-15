#!/usr/bin/env python3
r"""chartable_audit.py — P3.95: which frames does the bake read out of the WRONG FILE?

THE BAKE IMPLEMENTS HALF OF `decodeim` [CTRLSUBS.S:1017-1037]. That routine turns one
frame's (Fimage, Fsword) into TWO values:

    FCharTable = (Fimage bit 7) as bit 2, plus (Fsword bits 6-7) as bits 0-1   -> 0..7
    FCharImage = Fimage & $7F                                                  -> 0..127

bake_scene.convert_src() computes `fimg & 0x7F` correctly and then passes a HARD-CODED
`--table IMG.CHTAB6.A` for every cel. The table number is never computed, so an image
index is being applied to whichever file the bake was told to use rather than to the file
the frame names.

★ AND cel_parity_rule.altset2() PARSES Fsword AND THROWS IT AWAY — it returns
(Fimage, Fdx, Fdy, Fcheck, comment). The field that decides which file to open is read out
of the source and discarded one line later, which is why nothing downstream could notice.

FILE NUMBER = SLOT + 1, from the oracle's own comments, three independent places:
    GAMEBG.S:140   startable = 0   ;chtable1
    CTRLSUBS.S:1053  lda #2        ;chtable3
    GAMEBG.S:887   lda #5          ;chtable6
so FCharTable 5 is `chtable6` = IMG.CHTAB6.*, and FCharTable 6 is `chtable7` = IMG.CHTAB7.

Symptom this explains, reported by Jay across three gates: the vizier "disappears except
for his feet" for a frame or two at the raise and at the turn. Frames 78..85 (`vcast-*`)
resolve to FCharTable 6, and the bake read IMG.CHTAB6.A -> 13-row, 2-byte stubs where
IMG.CHTAB7 has the 48-to-50-row cels. Cels are stored bottom-up, so a 13-row draw IS the
feet.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path("C:/Projects/POP3_port")
sys.path.insert(0, str(ROOT / "harness/tools"))
FRAMEDEF = ROOT / "oracle/source/01 POP Source/Source/FRAMEDEF.S"

# The same shape cel_parity_rule.ENTRY matches, but keeping Fsword.
ENTRY = re.compile(r"^:(\d+)\s+db\s+"
                   r"\$([0-9a-fA-F]{2}),"
                   r"\$([0-9a-fA-F]{2}),"
                   r"(-?\d+),(-?\d+),"
                   r"\$?([0-9a-fA-F]{2})")

# FCharTable -> the file the oracle loads into that slot. Slot = file number - 1.
SLOT_FILE = {0: "IMG.CHTAB1", 1: "IMG.CHTAB2", 2: "IMG.CHTAB3",
             3: "IMG.CHTAB4.*", 4: "IMG.CHTAB5", 5: "IMG.CHTAB6.*",
             6: "IMG.CHTAB7", 7: "(slot 7 — no file identified)"}
BAKED_AS = 5          # what bake_scene hard-codes: IMG.CHTAB6.A


def decodeim(fimage, fsword):
    """CTRLSUBS.S:1017-1037, verbatim in arithmetic."""
    ztemp = fimage & 0x80
    a = (fsword & 0xC0) >> 1
    a = (a + ztemp) & 0xFF
    return a >> 5, fimage & 0x7F


def section(name):
    lines = FRAMEDEF.read_text(errors="replace").splitlines()
    start = next(i for i, l in enumerate(lines) if l.strip() == name)
    out = {}
    for l in lines[start + 1:]:
        if "Sword images" in l or l.strip().startswith("ALTSET"):
            break
        m = ENTRY.match(l.strip())
        if m:
            note = l.split(";", 1)
            out[int(m.group(1))] = (int(m.group(2), 16), int(m.group(3), 16),
                                    note[1].strip() if len(note) > 1 else "")
    return out


def main():
    alt = section("ALTSET2")
    print("  ALTSET2 (chtable6 alternate set) — %d frames" % len(alt))
    by_slot = {}
    for n, (fimg, fsw, note) in sorted(alt.items()):
        tab, idx = decodeim(fimg, fsw)
        by_slot.setdefault(tab, []).append((n, idx, note))

    print()
    print("  frames grouped by the table the ORACLE names:")
    for tab in sorted(by_slot):
        rows = by_slot[tab]
        mark = "  <-- baked correctly" if tab == BAKED_AS else "  <-- ** BAKED FROM THE WRONG FILE"
        print("    FCharTable %d = %-16s  %3d frames%s"
              % (tab, SLOT_FILE.get(tab, "?"), len(rows), mark))

    wrong = [(n, i, c) for t, rs in by_slot.items() if t != BAKED_AS for (n, i, c) in rs]
    print()
    if not wrong:
        print("  VERDICT: every ALTSET2 frame names the file the bake uses.")
        return 0
    print("  ** %d frames name a file the bake never opens:" % len(wrong))
    for n, idx, note in sorted(wrong):
        print("      frame %-4d image %-4d %s" % (n, idx, note))
    print()
    print("  Each was converted from IMG.CHTAB6.A at the same index, so it carries")
    print("  whatever that file holds there — real cel data, wrong cel.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
