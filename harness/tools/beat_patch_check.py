"""beat_patch_check.py — P3.107: the beats the scene is called between carry no patch.

★★★ THE CONDITION THIS ENFORCES, AND WHY IT IS A CONDITION RATHER THAN A PROPERTY.

`patch_blit` saves every framebuffer byte a caption is about to overwrite into `SAVE_BUF`
at `$5400`, so the caption can be lifted again [intro_seq.s]. The TITLE caption's save is
**5,361 B** — `$5400..$68F1` — measured from the built bundle by
harness/tools/intro_patch_extent.py.

The scene reads its PACKED bundle to `$5800..$69FF`. **Those two regions overlap outright.**

They are safe together for exactly one reason: the scene is called between beat 4 and beat
5, and **both of those beats carry `BEAT_PATCH = 0`**, so nothing is live in `SAVE_BUF`
across the call. A caption added to either beat would put a live 5 KB save underneath the
scene's incoming bundle, and the symptom would be a corrupted caption restore three beats
later — nowhere near the change that caused it.

★★ A COMMENT DESCRIBING AN UNENFORCED DISCIPLINE HAS FAILED IN THIS PROJECT TWICE (P3.50's
dead code, P3.44's 45%-low "6809 floor"), and P3.104's whole finding was an assumption that
was true when written and enforced by nothing. So this is an assert, it runs in build.bat,
and it fails the build.

It reads the ASSEMBLED SOURCE rather than a copy of the beat table, because the table is the
one home and a transcription here would be the second.
"""
import argparse
import pathlib
import re
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass


def beats(src):
    """[(index, {field: token})] parsed from intro_seq.s's beat_table.

    The table is six `fcb`/`fdb` lines per beat in a fixed order — BEAT_TRACK, BEAT_WIPE,
    BEAT_PATCH, BEAT_PRE, BEAT_HOLD, BEAT_SONG — with comments naming each. Rather than
    counting lines (which a reformat would break), each row is taken by matching the
    field's own name in the trailing comment: the file labels every one.
    """
    text = pathlib.Path(src).read_text(encoding="utf-8", errors="replace")
    start = text.index("\nbeat_table")
    body = text[start:]
    out, cur, idx = [], {}, 0
    for line in body.splitlines():
        m = re.match(r"\s+(fcb|fdb)\s+([^;]+?)\s*;\s*(BEAT_[A-Z]+)", line)
        if not m:
            continue
        field, value = m.group(3), m.group(2).strip()
        if field == "BEAT_TRACK" and cur:
            out.append((idx, cur)); idx += 1; cur = {}
        cur[field] = value
    if cur:
        out.append((idx, cur))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", default="src/engine/intro_seq.s")
    ap.add_argument("--after-beat", type=int, default=3,
                    help="0-based index of the beat the scene is called AFTER")
    a = ap.parse_args()

    bts = beats(a.src)
    if not bts:
        sys.exit("[beat-patch] could not parse beat_table out of %s" % a.src)

    # the beat the scene is called after, and the one it returns into
    want = [a.after_beat, a.after_beat + 1]
    bad = []
    for i in want:
        row = next((f for n, f in bts if n == i), None)
        if row is None:
            sys.exit("[beat-patch] beat %d not found — %d beats parsed" % (i, len(bts)))
        patch = row.get("BEAT_PATCH", "?")
        if patch != "0":
            bad.append((i, patch))

    names = ", ".join("beat %d" % (i + 1) for i in want)
    if bad:
        detail = "; ".join("beat %d has BEAT_PATCH %s" % (i + 1, p) for i, p in bad)
        sys.exit(
            "[beat-patch] FAIL — %s\n"
            "  The scene is called between beat %d and beat %d, and its packed bundle lands\n"
            "  at $5800..$69FF. A live caption save occupies $5400..$68F1 (the TITLE patch is\n"
            "  5,361 B). A patch on either of those beats is still live across the call and\n"
            "  the scene's read lands on top of it.\n"
            "  Either move the caption, or move SAVE_BUF/the scene's landing zone apart."
            % (detail, want[0] + 1, want[1] + 1))

    print("[beat-patch] OK — %s carry BEAT_PATCH 0, so no caption save is live across the "
          "scene call (%d beats parsed)." % (names, len(bts)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
