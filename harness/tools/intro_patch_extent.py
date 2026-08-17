"""intro_patch_extent.py — P3.105 §3: how many bytes does a caption patch save?

★★ THE QUESTION, FROM P3.104's SUSPECT 3. The intro's `SAVE_BUF` is at `$5400` and the
scene reads its PACKED bundle to `FLAME_LOAD` at `$5800..$69FF`. That is 1,024 B of
clearance. `patch_blit` saves every framebuffer byte it is about to overwrite into
`SAVE_BUF` so the caption can be lifted again [intro_seq.s:793-858], and P3.104 reported
the gap without measuring what goes into it — a suspect with a number attached, not a
finding. This is the number.

THE FORMAT, from `patch_blit`'s own header [intro_seq.s:805-808]:

    fdb first_row / fcb n_rows / per row: fcb n_runs, per run: fcb col, len, data*

and the save is one byte per byte written, so the extent is simply the sum of every run's
`len`. ★ The three patches live at fixed offsets in the bundle
[intro_seq.s:156-159]: PAL $000, PRESENTS $040, BYLINE $400, TITLE $800.

★ READ FROM THE BUILT ASSET, not from the generator. `build/assets/intro_bundle.raw` is
the artefact that reaches the disk; the generator is a second home and could drift from it.
"""
import io
import pathlib
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

BUNDLE = pathlib.Path("build/assets/intro_bundle.raw")
SAVE_BUF = 0x5400
FLAME_LOAD = 0x5800                 # the scene's packed-bundle landing zone
PATCHES = [("PRESENTS", 0x040), ("BYLINE", 0x400), ("TITLE", 0x800)]


def extent(buf, off):
    """Total bytes patch_blit would save, and the row range it touches."""
    first_row = (buf[off] << 8) | buf[off + 1]
    n_rows = buf[off + 2]
    p = off + 3
    total, runs = 0, 0
    for _ in range(n_rows):
        n_runs = buf[p]; p += 1
        for _ in range(n_runs):
            col, ln = buf[p], buf[p + 1]
            p += 2 + ln
            total += ln
            runs += 1
    return first_row, n_rows, runs, total, p - off


def main():
    if not BUNDLE.exists():
        print("missing %s — run build.bat first" % BUNDLE)
        return 1
    buf = io.open(BUNDLE, "rb").read()
    print("# CAPTION PATCH SAVE EXTENT — measured from %s (%d B)" % (BUNDLE, len(buf)))
    print("# SAVE_BUF $%04X; the scene's packed bundle lands at $%04X; clearance %d B."
          % (SAVE_BUF, FLAME_LOAD, FLAME_LOAD - SAVE_BUF))
    print()
    print("  patch      first_row  rows  runs   SAVED B   SAVE_BUF end   verdict")
    worst = 0
    for name, off in PATCHES:
        fr, nr, runs, total, blen = extent(buf, off)
        end = SAVE_BUF + total
        worst = max(worst, total)
        print("  %-10s %-10d %-5d %-6d %-9d $%04X          %s"
              % (name, fr, nr, runs, total, end,
                 "clear" if end <= FLAME_LOAD else "★ OVERRUNS $%04X" % FLAME_LOAD))
    print()
    head = FLAME_LOAD - SAVE_BUF - worst
    print("# worst case %d B of %d available — %d B of headroom (%.0f%% used)."
          % (worst, FLAME_LOAD - SAVE_BUF, head, 100.0 * worst / (FLAME_LOAD - SAVE_BUF)))
    if head < 0:
        print("# ★★★ SUSPECT 3 CONFIRMED: a caption patch's save runs into the scene's")
        print("#     packed-bundle landing zone.")
    else:
        print("# ★ SUSPECT 3 CLEARED: the gap is sufficient, with the margin above.")
        print("#   Note what this does and does not cover: it is measured against the patches")
        print("#   THIS BUILD produces. A larger caption would eat the margin, so the check")
        print("#   belongs in the build rather than in a dispatch — see the report.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
