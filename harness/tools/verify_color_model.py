#!/usr/bin/env python3
"""
verify_color_model.py — prove POP's converter carries Karateka's colour model
BYTE-IDENTICALLY.

WHY THIS EXISTS. The P1.2 dispatch and Jay's ruling both say the HGR->4-colour
colour model TRANSFERS FOR FREE: POP and Karateka are both Apple II HGR sources,
and the artifact-colour physics (screen-col parity, NTSC chroma, the gap>=2
threshold, colour-cell fill) is display-hardware behaviour, not game behaviour.
"We did not change it" is easy to assert and easy to violate by accident during
a port. This makes it CHECKABLE: it extracts the two colour functions from both
files and compares them character for character.

A pass here is the objective half of AC2. It says the CODE is identical; it does
not say the colours are right for POP — that is the spot-check, and ultimately
Jay's eye (CLAUDE.md §4).

Usage:  python harness/tools/verify_color_model.py
Exit:   0 = identical, 1 = drift (prints a unified diff)
"""
import sys
import pathlib
import difflib

POP  = pathlib.Path(__file__).resolve().parent / "sprite_convert.py"
KAR  = pathlib.Path("C:/Projects/karateka_coco3/harness/tools/sprite_convert.py")

# The functions that ARE the colour model. Everything else in either file is
# I/O plumbing and is expected to differ.
FUNCS = ["_classify_row_convert", "convert_sprite_to_coco3"]


def extract(path, name):
    """Return `def name(...)` through the end of its body, verbatim.

    The function ends at the first subsequent line that starts at column 0 and
    is not blank — i.e. the real dedent. Slicing to the *next* `def` instead
    would swallow any banner comment sitting between the two functions and
    report it as colour-model drift; that is a property of the extractor, not
    of the model. (Observed exactly that on the first run.)
    """
    lines = path.read_text(encoding="utf-8").splitlines()
    start = next((i for i, l in enumerate(lines) if l.startswith(f"def {name}(")), None)
    if start is None:
        raise SystemExit(f"FATAL: {path} has no `def {name}(`")
    end = len(lines)
    for i in range(start + 1, len(lines)):
        l = lines[i]
        if l.strip() and not l[0].isspace():
            end = i
            break
    return "\n".join(lines[start:end]).rstrip() + "\n"


def main():
    if not KAR.exists():
        print(f"SKIP: karateka reference not present at {KAR}")
        print("      (read-only sibling per CLAUDE.md §2G; cannot verify without it)")
        return 2

    ok = True
    print(f"POP : {POP}")
    print(f"KAR : {KAR}   [read-only reference]")
    print()

    for fn in FUNCS:
        a = extract(KAR, fn)
        b = extract(POP, fn)
        if a == b:
            print(f"  {fn:<28} IDENTICAL  ({len(a)} chars, {a.count(chr(10))} lines)")
        else:
            ok = False
            print(f"  {fn:<28} *** DRIFT ***")
            for line in difflib.unified_diff(
                    a.splitlines(), b.splitlines(),
                    fromfile=f"karateka/{fn}", tofile=f"pop/{fn}", lineterm=""):
                print("      " + line)

    print()
    if ok:
        print("VERDICT: COLOUR MODEL UNCHANGED — POP carries karateka's model verbatim.")
        return 0
    print("VERDICT: COLOUR MODEL DRIFTED — out of scope per P1.2 §6; investigate.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
