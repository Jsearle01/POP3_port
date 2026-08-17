#!/usr/bin/env python3
"""
compile_check.py — round-trip a converted POP cel through the PA.9 compiled-sprite
pipeline, proving the converter's output is COMPILER-CONSUMABLE.

  sprite_convert.py  ->  converted.s (+ opacity.s)  ->  [THIS]  ->  popcc compiler
                                                                     -> 6809 code
                                                                     -> simulate/verify

THE ADAPTER, stated exactly (P1.2 AC4).
  PA.9's poc/compiled-sprite/run_poc.py carries its own ad-hoc converted.s reader
  (`load_kar`). That reader is WRONG for POP cels, and provably so:

      header line:  `        fcb     24,2  ; height=24 rows, ...`   <- DECIMAL
      load_kar:     re.findall(r'\\$?([0-9A-Fa-f]{1,2})\\b', ...) then int(v, 16)
      result:       reads 24 as 0x24 = 36.  h=36 for a 24-row cel.

  It is latent in PA.9 because the four karateka cels its N3 stage sampled have
  every header digit < 10 (h/w of 2,4,3,6,7), where hex and decimal coincide.
  PA.9's published numbers are therefore NOT affected. POP cels are 24-41 rows
  tall, so it fires immediately.

  The adapter is: DO NOT re-parse. Use `sprite_tool/celio.Cel`, which is the
  canonical converted.s reader (it is the authoring tool's own I/O module and
  round-trips byte-identically), and `sprite_tool/sidecar` for opacity. Only the
  popcc CORE — tokenize / pack / Compiler / cycles / simulate — is imported.
  poc/compiled-sprite/ is NOT modified: it is an explicitly throwaway PA.9
  measurement instrument, not engine tooling.

Usage:
  python harness/tools/compile_check.py content/kid/kid_chtab1_064_thin
  python harness/tools/compile_check.py --all content
"""
import sys
import argparse
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE / "sprite_tool"))
sys.path.insert(0, str(ROOT / "poc" / "compiled-sprite"))

from celio import Cel                      # canonical converted.s reader
import sidecar as SC                       # canonical opacity.s reader
from popcc import tokenize, pack, Compiler, cycles, simulate, T   # PA.9 core only


def expand_opacity(cel, side):
    """sidecar payload -> h x (w*4) bool grid (True = that index-0 pixel is OPAQUE).

    Opacity is meaningful ONLY for index-0 pixels; non-0 are always drawn.
    [ref: sprite_tool/opacity.py module docstring, verbatim contract]
    """
    op = [[False] * (cel.w * 4) for _ in range(cel.h)]
    if not side:
        return op, "none"
    kind, payload = side
    if kind == "mixed":
        for sc, w, sr, nr, opq in payload:
            if not opq:
                continue
            for r in range(sr, min(sr + nr, cel.h)):
                for c in range(sc, min(sc + w, cel.w)):
                    for k in range(4):
                        op[r][c * 4 + k] = True
    elif kind == "masked":
        # one mask byte per byte-column, reused each row; bit-pair 11=opaque
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


def check(cel_dir, verbose=True):
    d = pathlib.Path(cel_dir)
    cel = Cel(str(d / "converted.s"))
    op, kind = expand_opacity(cel, SC.read_sidecar(str(d)))

    tok = tokenize(cel.pixels, op)
    pk = pack(tok)
    ins = Compiler().compile_cel(pk)
    cyc = cycles(ins)
    bad = simulate(ins, pk)

    cls = {"skip": 0, "store": 0, "mixed": 0}
    for row in pk:
        for b in row:
            cls[b[2]] += 1
    total = sum(cls.values())
    drawn = total - cls["skip"]

    r = dict(name=d.name, h=cel.h, w=cel.w, opacity=kind, total=total, drawn=drawn,
             skip=cls["skip"], store=cls["store"], mixed=cls["mixed"],
             instr=len(ins), cyc=cyc, bad=len(bad),
             cyb=cyc / max(1, total), cybd=cyc / max(1, drawn))
    if verbose:
        print(f"  {r['name']:<28} {cel.h:3d}x{cel.w:2d}B  opacity={kind:<7} "
              f"bytes {total:4d} (skip {r['skip']:4d} store {r['store']:4d} mixed {r['mixed']:3d})  "
              f"instr {r['instr']:4d} cyc {cyc:6d}  cy/B {r['cyb']:5.2f}  "
              f"{'SOUND' if not bad else 'UNSOUND(%d)' % len(bad)}")
        for y, x, k, w, g in bad[:3]:
            print(f"        MISMATCH r{y} c{x} [{k}] want ${w:02X} got ${g:02X}")
    return r


def main():
    ap = argparse.ArgumentParser(description="Round-trip converted POP cels through the PA.9 compiler")
    ap.add_argument("path", help="a cel dir, or a content root with --all")
    ap.add_argument("--all", action="store_true", help="walk <path>/*/*/converted.s")
    args = ap.parse_args()

    if args.all:
        dirs = sorted(p.parent for p in pathlib.Path(args.path).glob("*/*/converted.s"))
    else:
        dirs = [pathlib.Path(args.path)]

    print(f"=== compile_check: {len(dirs)} cel(s) -> PA.9 compiled-sprite pipeline ===")
    rows, unsound = [], 0
    for d in dirs:
        r = check(d)
        rows.append(r)
        unsound += (r["bad"] > 0)

    tb = sum(r["total"] for r in rows)
    tc = sum(r["cyc"] for r in rows)
    nd = sum(r["drawn"] for r in rows)
    nm = sum(r["mixed"] for r in rows)
    print(f"\n=== AGGREGATE (n={len(rows)}) ===")
    print(f"  SOUNDNESS           : {'ALL PASS' if unsound == 0 else f'{unsound} UNSOUND'}")
    print(f"  footprint bytes     : {tb:,}   drawn {nd:,}   skipped {tb-nd:,} "
          f"({100*(tb-nd)/max(1,tb):.0f}%)")
    print(f"  mixed / drawn       : {nm:,} / {nd:,} = {100*nm/max(1,nd):.1f}%")
    print(f"  cycles              : {tc:,}")
    print(f"  cy/byte (footprint) : {tc/max(1,tb):.2f}")
    print(f"  cy/byte (drawn only): {tc/max(1,nd):.2f}")
    return 1 if unsound else 0


if __name__ == "__main__":
    sys.exit(main())
