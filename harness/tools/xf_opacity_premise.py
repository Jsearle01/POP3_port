#!/usr/bin/env python3
r"""xf_opacity_premise.py — P5.34 AC1: is an OPACITY byte safe to push through xf_blit's own tables?

P5.33's route (§6 there) carries the stream's mask through the shift as an opacity byte
op = ~mask -- per pixel 11 where opaque, 00 where transparent -- through the SAME F/C tables the
colour byte uses, and writes dest = (dest AND M[out_op]) OR out. That rests on two claims, checked
here exhaustively against the tables AS LINKED (the xftab segment of a built binary, not the
generator that wrote them):

  1. every table maps a byte whose four pixels are each 0 or 3 to a byte with the same property:
     XF_T1, XF_T2, and F and C of all 13 XF_TABS pairs (shift, shift+mirror, shift+mirror+swap,
     swap-only), so op_out = op_carry | F[op] and op_carry' = C[op] stay pure opacity bytes;
  2. XF_M[v] == ~v for exactly those bytes -- so the existing M table turns out_op into the AND mask
     with no new table.

  python harness/tools/xf_opacity_premise.py [--bin build/kidrun_probe.bin]
"""
import argparse
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1].parent
XF_M, XF_T1, XF_T2, XF_TABS, NPAIRS = 0x4200, 0x4300, 0x4400, 0x4500, 13


def segments(path):
    d = pathlib.Path(path).read_bytes()
    out, i = {}, 0
    while i < len(d):
        t, n, a = d[i], (d[i + 1] << 8) | d[i + 2], (d[i + 3] << 8) | d[i + 4]
        if t == 0xFF:
            break
        out[a] = d[i + 5:i + 5 + n]
        i += 5 + n
    return out


def px(b):
    return [(b >> 6) & 3, (b >> 4) & 3, (b >> 2) & 3, b & 3]


def pure(b):
    return all(p in (0, 3) for p in px(b))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bin", default=str(ROOT / "build/kidrun_probe.bin"))
    a = ap.parse_args()
    segs = segments(a.bin)
    if XF_M not in segs or len(segs[XF_M]) < 3 * 256 + NPAIRS * 512:
        raise SystemExit("no xftab segment at $%04X in %s" % (XF_M, a.bin))
    mem = segs[XF_M]

    def at(addr, j):
        return mem[addr - XF_M + j]

    def permuted(base):
        return lambda b: at(base, b ^ 0x80)          # stored so that base+128 [signed b] = f(b)

    ops = [b for b in range(256) if pure(b)]
    tables = [("XF_T1 (mirror)", permuted(XF_T1)), ("XF_T2 (mirror+swap)", permuted(XF_T2))]
    names = {0: "plain", 1: "mirror", 2: "mirror+swap"}
    for p in range(NPAIRS):
        k, t = (p // 3 + 1, p % 3) if p < 9 else (p - 9, 3)
        lab = "k=%d %s" % (k, names.get(t, "swap-only"))
        tables.append(("F %s (pair %d)" % (lab, p), permuted(XF_TABS + 512 * p)))
        tables.append(("C %s (pair %d)" % (lab, p), permuted(XF_TABS + 512 * p + 256)))
    checks = fails = 0
    for name, f in tables:
        bad = [(b, f(b)) for b in ops if not pure(f(b))]
        checks += len(ops)
        fails += len(bad)
        if bad:
            print("  FAIL %-34s %d of %d opacity bytes leave the 00/11 set: %r" % (name, len(bad), len(ops), bad[:4]))
    print("xf_opacity_premise: %d tables (XF_T1, XF_T2, F and C of %d pairs) x %d opacity bytes = %d checks: %d fail"
          % (len(tables), NPAIRS, len(ops), checks, fails))
    mbad = [b for b in ops if at(XF_M, b) != (~b & 0xFF)]
    print("xf_opacity_premise: XF_M[v] == ~v over the %d opacity bytes: %d fail%s"
          % (len(ops), len(mbad), "" if not mbad else " %r" % mbad))
    # and the constants the blast uses (P5.34 §3B): F[$FF] and C[$FF] per pair
    print("xf_opacity_premise: per pair, F[$FF] / C[$FF] (a blast byte's opacity in / out):")
    for p in range(NPAIRS):
        print("    pair %2d  F[$FF]=$%02X  C[$FF]=$%02X" % (p, permuted(XF_TABS + 512 * p)(0xFF),
                                                        permuted(XF_TABS + 512 * p + 256)(0xFF)))
    return 1 if (fails or mbad) else 0


if __name__ == "__main__":
    sys.exit(main())
