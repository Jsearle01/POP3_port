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
IMAGES = ROOT / "oracle/source/01 POP Source/Images"

# The same shape cel_parity_rule.ENTRY matches, but keeping Fsword.
ENTRY = re.compile(r"^:(\d+)\s+db\s+"
                   r"\$([0-9a-fA-F]{2}),"
                   r"\$([0-9a-fA-F]{2}),"
                   r"(-?\d+),(-?\d+),"
                   r"\$?([0-9a-fA-F]{2})")

# FCharTable -> the file the oracle loads into that slot. Slot = file number - 1.
# Concrete names, so the comparison below is against a path and not a pattern. The
# INDEPENDENCE that matters here is the decode arithmetic, which this file implements from
# CTRLSUBS.S directly; the slot->file mapping is the oracle's own (file number = slot + 1)
# and is deliberately the same fact in both places, which is what makes disagreement
# meaningful rather than a naming difference.
SLOT_FILE = {0: "IMG.CHTAB1", 1: "IMG.CHTAB2", 2: "IMG.CHTAB3",
             4: "IMG.CHTAB5", 5: "IMG.CHTAB6.A", 6: "IMG.CHTAB7"}


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
    """★ A CHECK, NOT A ONE-OFF DIAGNOSIS.

    This began as the script that found the bug, comparing every frame against the
    hard-coded IMG.CHTAB6.A. That question is answered, so it now asks the one that stays
    useful: does the TABLE the bake will open agree with the table `decodeim` names, for
    every frame, computed two independent ways?

    The bug it guards is invisible to every other check in the project. A cel baked from
    the wrong table is a well-formed file of a plausible size holding real cel data — so
    the assembler is happy, the packer is happy, the link map is happy, and the pixel
    checkers compare the engine's output against the same wrong artifact and agree. It
    took an eye on a running machine, across three gates, to see it at all.
    """
    import cel_parity_rule as R

    alt = section("ALTSET2")
    print("  ALTSET2 — %d frames; checking the table each one names" % len(alt))
    by_slot, bad = {}, []
    for n, (fimg, fsw, note) in sorted(alt.items()):
        tab, idx = decodeim(fimg, fsw)
        by_slot.setdefault(tab, []).append(n)
        # the bake's own answer, from the shared home, against this file's independent one
        try:
            got = R.table_path(n)
            got_tab, got_idx = R.chartable(n)
        except KeyError as e:
            bad.append((n, "table_path refused: %s" % e))
            continue
        want = IMAGES / SLOT_FILE.get(tab, "?")
        if got_tab != tab or got_idx != idx:
            bad.append((n, "decodeim says table %d image %d; cel_parity_rule says %d/%d"
                        % (tab, idx, got_tab, got_idx)))
        elif got.name != want.name:
            bad.append((n, "table %d should be %s; the bake would open %s"
                        % (tab, want.name, got.name)))
        elif not got.exists():
            bad.append((n, "resolves to %s, which does not exist" % got.name))

    for tab in sorted(by_slot):
        print("    FCharTable %d = %-16s %3d frames"
              % (tab, SLOT_FILE.get(tab, "?"), len(by_slot[tab])))

    print()
    if not bad:
        print("  ok   every ALTSET2 frame's table resolves to the file decodeim names")
        return 0
    for n, why in bad:
        print("  FAIL frame %-4d %s" % (n, why))
    return 1


if __name__ == "__main__":
    sys.exit(main())
