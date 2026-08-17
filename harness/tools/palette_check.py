#!/usr/bin/env python3
r"""palette_check.py — the bundle's copy of the palette must equal the HAL's table.

P3.85c, and it exists because of a specific failure. char_draw.s carries `sc_pal`, the four
bytes the lightning flash restores after it paints the screen white. It had $1B for entry 2
where src/hal/coco3-dsk/gfx.s's `gfx_pal4` has $19 — a value taken from an inline
`lda #$1B / sta $FFB2` in the HAL's init path rather than from the table the machine
actually loads. The two disagree inside the HAL itself.

★ THE SYMPTOM WAS NOT A FLASH BUG. The white lasted one frame and was never seen; what was
seen was the RESTORE, which wrote a greener, lighter blue and left it there for the rest of
the scene. Jay, on the live gate: "it changes the blue color to a light greenish color but
doesn't 'flash white at all." A restore that writes the wrong value is indistinguishable
from an effect that changed the colour on purpose, which is why nothing upstream caught it:
the build was green, both suites were green, and the scene rendered.

WHY A CHECK AND NOT AN IMPORT. gfx_pal4 is not exported, and the flame bundle links
separately from the room that holds the HAL, so the bytes have to be duplicated. A
duplicate is fine; a duplicate nothing compares is not. If the 16-colour swap ever lands,
gfx_pal4 moves and this fails the build instead of silently repainting the scene.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
HAL = ROOT / "src/hal/coco3-dsk/gfx.s"
BUNDLE = ROOT / "src/engine/char_draw.s"


def hal_pal4():
    """The four bytes after `gfx_pal4:` — the table HAL_gfx_set_mode actually loads."""
    txt = HAL.read_text(errors="replace")
    m = re.search(r"^gfx_pal4:\s*$", txt, re.M)
    if not m:
        return None, "no gfx_pal4 label in %s" % HAL.name
    out = []
    for line in txt[m.end():].splitlines():
        s = line.split(";")[0].split("*")[0]
        f = re.match(r"\s*fcb\s+\$([0-9A-Fa-f]{1,2})\s*$", s)
        if f:
            out.append(int(f.group(1), 16))
            if len(out) == 4:
                return out, None
        elif s.strip():
            break
    return None, "gfx_pal4 has %d entries, expected 4" % len(out)


def bundle_pal():
    """`sc_pal fcb $xx,$xx,$xx,$xx` from the bundle."""
    txt = BUNDLE.read_text(errors="replace")
    m = re.search(r"^sc_pal\s+fcb\s+(.+)$", txt, re.M)
    if not m:
        return None, "no sc_pal in %s" % BUNDLE.name
    vals = []
    for x in m.group(1).split(";")[0].split(","):
        x = x.strip()
        if x.startswith("$"):
            vals.append(int(x[1:], 16))
    if len(vals) != 4:
        return None, "sc_pal has %d entries, expected 4" % len(vals)
    return vals, None


def main():
    hal, err = hal_pal4()
    if err:
        print("  FAIL palette-check: %s — the check is UNCHECKED, which is a build error"
              % err)
        return 1
    bun, err = bundle_pal()
    if err:
        print("  FAIL palette-check: %s — the check is UNCHECKED, which is a build error"
              % err)
        return 1
    if hal != bun:
        print("  FAIL the flash's restore palette does not match the HAL's gfx_pal4:")
        names = ("black", "orange", "blue", "white")
        for i, (h, b) in enumerate(zip(hal, bun)):
            print("      entry %d %-7s gfx_pal4 $%02X   sc_pal $%02X %s"
                  % (i, names[i], h, b, "" if h == b else "  <- DIFFERS"))
        print("      The flash restores sc_pal after painting white, so a wrong byte here")
        print("      REPAINTS THE SCENE PERMANENTLY the first time the flash fires. It")
        print("      does not look like a flash bug; it looks like the colour changed.")
        return 1
    print("  [palette] the flash's restore matches gfx_pal4 (%s)"
          % " ".join("$%02X" % v for v in hal))
    return 0


if __name__ == "__main__":
    sys.exit(main())
