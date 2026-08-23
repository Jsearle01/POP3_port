#!/usr/bin/env python3
"""register_owner_check.py — THE REGISTER RATCHET (P5.19, proposed at P5.17 §4.1).

WHAT IT STOPS. POP has 59 code-level GIME/MMU/SAM accesses outside its HAL, spread over six
files, and TEN registers with two owners -- one inside the HAL and one outside. That is not a
hypothetical: $FF92/$FF93 share one set of interrupt latches, msys_player.s writes them and so
does the HAL, and the collision presented as a timing bug when enabling FIRQ killed VBL.

★★★ AND THE 110th REFERENCE WAS ALREADY ADDED BEFORE ANYONE PROPOSED THIS CHECK. P5.16's
tc_map borrows $FFA4/$FFA5 -- the framebuffer's own MMU slots -- to reveal a cached track. It
saves and restores them and it is correct, and it made intro_seq.s a SECOND OWNER of a pair the
HAL owns. Nothing in the diff said so. Six commits later P5.17's audit found it by enumeration.
That is the exact event this file exists to turn into a build failure.

WHAT IT COMPARES, AND WHY NOT A COUNT
-------------------------------------
Rows are (register, file) -- OWNERSHIP, not traffic. A count regresses silently when one site
is deleted and another added, and P5.17 §7 warns against conflating "the engine touches no
registers" with "one sanctioned owner": 71 of the MMU accesses are the cel bank, engine-owned
by design and running every frame. The goal was never zero. So:

  a NEW file touching a register        -> a new row -> FAILS
  a NEW register in an existing file    -> a new row -> FAILS
  another write in a file that already owns that register -> no new row -> passes

The third case is deliberate. Adding a fifth `sta CEL_MMU` to a file that is already the
sanctioned owner of $FFA6 tells a reviewer nothing; a seventh file writing $FFA6 tells them
everything.

HOW A DELIBERATE ADDITION IS APPROVED
-------------------------------------
By adding the row to docs/project/register-owners.tsv IN THE SAME COMMIT as the code. There is
no flag and no override. The point is that the new owner appears as a diff line with a note
beside it, in front of the reviewer, instead of as an absence -- which is what $FFA4/$FFA5 was.

THE METHOD IS P5.17 §3A's, AND IT HAD TO BE WRONG TWICE BEFORE IT WAS RIGHT
---------------------------------------------------------------------------
A naive `grep '$FF..'` over src/engine returns 117 hits of which 85 ARE COMMENT TEXT -- this
codebase quotes register addresses in prose constantly, and correctly. A check that fires on
prose is a check that gets switched off, exactly as hal_sync_check.py reasons about line
endings. The same grep also MISSES every access made through an `equ` alias -- CEL_MMU,
BANK_MMU, TC_MMU, SAM_SLOW/FAST, PALETTE, msys_player's FF90-FF95 -- which are the majority of
the real ones. Both errors are in the method and they point opposite ways. So a line counts
only if it survives all four of:

  1. not a full-line comment (`*` in column 1, or `;`)
  2. not the inline half after `;`
  3. not an `equ` DEFINITION (the definition is not an access)
  4. carries a load/store/modify mnemonic

...and aliases are resolved to the register they name, `+n` offsets included, so `sta CEL_MMU+1`
is recorded against $FFA7, which is what it writes.

SCOPE. src/ excluding src/hal (the HAL is the sanctioned owner; hal_sync_check.py guards it)
and excluding the probe allowlist. Registers $FF80-$FFDF: GIME video/interrupt, MMU, palette,
SAM. The PIA at $FF00-$FF7F is a different subsystem and is not in scope -- said here so the
next reader knows it was decided rather than missed.

★ THE ALLOWLIST IS BY EXPLICIT FILENAME, NEVER BY PATTERN OR DIRECTORY. A probe's job is to
poke hardware, so probes are exempt -- but adding one must be a visible act. It is also why the
list is filenames and not `src/harness/*`: src/engine/tile_probe.s is a probe by name, header
and behaviour while living in the engine tree, and a directory rule would either miss it or
force a file to move to satisfy a checker.
"""
import argparse
import pathlib
import re
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

LO, HI = 0xFF80, 0xFFDF
MNEM = re.compile(r'\b(ld[abdxyus]|st[abdxyus]|clr|inc|dec|tst|com|and|or[ab]|eor|bit)\b', re.I)
EQU = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s+equ\s+\$([0-9A-Fa-f]{4})\s*$', re.I)
LITERAL = re.compile(r'\$FF([89ABCD][0-9A-F])', re.I)


def code_lines(path):
    """Yield (lineno, code) for lines that are not comments and not equ definitions."""
    for i, raw in enumerate(path.read_text(errors="replace").splitlines(), 1):
        s = raw.strip()
        if not s or s[0] in "*;":
            continue                      # note 1
        code = raw.split(";")[0]          # note 2
        if re.search(r'\bequ\b', code, re.I):
            continue                      # note 3
        yield i, code


def aliases(roots):
    """SYMBOL -> register, for every `SYMBOL equ $FFxx` in range, anywhere in the tree."""
    out = {}
    for root in roots:
        for f in sorted(pathlib.Path(root).rglob("*.s")):
            for raw in f.read_text(errors="replace").splitlines():
                m = EQU.match(raw.split(";")[0])
                if m and LO <= int(m.group(2), 16) <= HI:
                    out[m.group(1)] = int(m.group(2), 16)
    return out


def scan(roots, alias, skip):
    """-> {(reg, file): [(line, how)]}  for every ACCESS outside the skip set."""
    hits = {}
    for root in roots:
        for f in sorted(pathlib.Path(root).rglob("*.s")):
            rel = f.as_posix()
            if rel in skip:
                continue
            for ln, code in code_lines(f):
                if not MNEM.search(code):        # note 4
                    continue
                for hx in LITERAL.findall(code):
                    hits.setdefault((0xFF00 | int(hx, 16), rel), []).append((ln, "$FF" + hx))
                for sym, base in alias.items():
                    m = re.search(r'\b' + re.escape(sym) + r'\b(\s*\+\s*(\d+))?', code)
                    if not m:
                        continue
                    reg = base + (int(m.group(2)) if m.group(2) else 0)
                    if LO <= reg <= HI:
                        hits.setdefault((reg, rel), []).append((ln, m.group(0)))
    return hits


def read_baseline(path):
    allow, owners = set(), {}
    section = None
    if not path.exists():
        return allow, owners, False
    for raw in path.read_text(encoding="utf-8").splitlines():
        s = raw.strip()
        if not s or s.startswith("#"):
            continue
        if s.startswith("[") and s.endswith("]"):
            section = s[1:-1].lower()
            continue
        if section == "allowlist":
            allow.add(s)
        elif section == "owners":
            parts = raw.split("\t")
            if len(parts) >= 2:
                owners[(int(parts[0].lstrip("$"), 16), parts[1].strip())] = parts[2:]
    return allow, owners, True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--baseline", default="docs/project/register-owners.tsv")
    ap.add_argument("--roots", nargs="*", default=["src"])
    ap.add_argument("--exclude", nargs="*", default=["src/hal"])
    ap.add_argument("--write", action="store_true",
                    help="regenerate the baseline from the tree (a DELIBERATE act, never CI)")
    args = ap.parse_args()

    base = pathlib.Path(args.baseline)
    allow, owners, had = read_baseline(base)

    roots = [r for r in args.roots]
    alias = aliases(roots)
    skip = set(allow)
    for ex in args.exclude:
        for f in pathlib.Path(ex).rglob("*.s"):
            skip.add(f.as_posix())

    hits = scan(roots, alias, skip)

    if args.write:
        lines = [
            "# register-owners.tsv — WHO OUTSIDE THE HAL TOUCHES A GIME/MMU/SAM REGISTER.",
            "# Generated by harness/tools/register_owner_check.py --write, then HAND-ANNOTATED.",
            "# A new row is a new OWNER and must be added in the same commit as the code that",
            "# creates it. That is the approval: the reviewer sees a line, not an absence.",
            "#",
            "# reg\tfile\taccessor\thot|cold\tnote",
            "",
            "[allowlist]",
            "# Probes poke hardware; that is their job. BY EXPLICIT FILENAME, never by pattern —",
            "# adding one must be a visible act, and tile_probe.s is a probe living in the engine",
            "# tree, which no directory rule would classify correctly.",
        ]
        lines += sorted(allow) if allow else []
        lines += ["", "[owners]"]
        for (reg, f), sites in sorted(hits.items(), key=lambda kv: (kv[0][1], kv[0][0])):
            how = sites[0][1]
            prev = owners.get((reg, f), [])
            hot = prev[1] if len(prev) > 1 else "?"
            note = prev[2] if len(prev) > 2 else "%d site(s)" % len(sites)
            lines.append("$%04X\t%s\t%s\t%s\t%s" % (reg, f, how, hot, note))
        base.parent.mkdir(parents=True, exist_ok=True)
        base.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print("[reg-owner] baseline written: %d owner row(s), %d allowlisted file(s)"
              % (len(hits), len(allow)))
        return 0

    if not had:
        print("[reg-owner] ★ no baseline at %s — run with --write once, then review it by hand."
              % base)
        return 1

    new = sorted(set(hits) - set(owners), key=lambda k: (k[1], k[0]))
    gone = sorted(set(owners) - set(hits), key=lambda k: (k[1], k[0]))

    for reg, f in new:
        ln, how = hits[(reg, f)][0]
        print("[reg-owner] ★ NEW OWNER: $%04X is now touched by %s (%s:%d, `%s`)"
              % (reg, f, f, ln, how.strip()))
    if new:
        print("[reg-owner] A register with two owners is how $FF92/$FF93 cost a debugging round,")
        print("[reg-owner] and how $FFA4/$FFA5 gained a second owner unnoticed for six commits.")
        print("[reg-owner] If this is deliberate, add the row to %s in THIS commit." % base)

    for reg, f in gone:
        print("[reg-owner] stale row: $%04X %s no longer accesses it — drop the row." % (reg, f))

    if new or gone:
        print("[reg-owner] %d new, %d stale. This is a build failure, not a warning."
              % (len(new), len(gone)))
        return 1

    twoown = len({r for r, _ in hits})
    print("[reg-owner] OK — %d owner row(s) over %d register(s), %d file(s) allowlisted."
          % (len(hits), twoown, len(allow)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
