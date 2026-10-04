#!/usr/bin/env python3
r"""bake_chars_check.py — P5.27: the bake against the oracles that already exist, and its size.

★ NO NEW ORACLE. Every comparison here is against an artifact an earlier dispatch produced
and measured, read from disk -- not against this dispatch's own regeneration of it:

  ref     P5.20's census batches, build/xform/b###_gen.s (2026-10-01): the `<tag>_src` stream
          each one carries is THE stream xf_blit drew in the 4,640 cases, and `<tag>_r00` is the
          generated facing-0 phase-0 reference beside it. Baked p0 must equal both, byte-exact.
  blob    P5.22's build/p522/cast_seg.bin: the 91,906 B the disk arc priced (§5.338), saved by
          disk_capacity.py. The bake, concatenated in the same order, must equal it.
  cases   P5.20's case records vs this dispatch's --baked records (`k` prefix): per (cel,
          facing, phase, mode), the reference framebuffer, column, A and B must be unchanged --
          i.e. the probe is asked the identical question; only where its stream came from moved.
  verdict P5.20's b###.log.json vs the k###.log.json the --baked probe run writes: per case, ok
          and cycles.
  control the nine P1.2 cels in content/kid, content/guard, re-converted today by the same
          call and compared byte for byte (AC7).

Then the sizes, in §5.338's own unit: segment-stream bytes ([h,w]+segments per cel) and
lz_pack in 8,192 B chunks (disk_capacity.lz, imported, not copied), and tracks of 4,608 B.

  python harness/tools/bake_chars_check.py [--no-verdict]
"""
import argparse
import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "sprite_tool"))
import bake_chars as B                                      # noqa: E402
import sprite_convert as SC                                 # noqa: E402
import disk_capacity as DC                                  # noqa: E402

XF = ROOT / "build/xform"
TRACK = DC.TRACK

CONTROL = [  # P1.2's sample, as named: (dir, table, index)
    ("content/kid/kid_chtab1_040_large", "IMG.CHTAB1", 40),
    ("content/kid/kid_chtab1_047_median", "IMG.CHTAB1", 47),
    ("content/kid/kid_chtab1_064_thin", "IMG.CHTAB1", 64),
    ("content/kid/kid_chtab2_002_median", "IMG.CHTAB2", 2),
    ("content/kid/kid_chtab2_003_large", "IMG.CHTAB2", 3),
    ("content/kid/kid_chtab3_006_large", "IMG.CHTAB3", 6),
    ("content/kid/kid_chtab3_011_median", "IMG.CHTAB3", 11),
    ("content/guard/guard_gd_001_median", "IMG.CHTAB4.GD", 1),
    ("content/guard/guard_gd_015_large", "IMG.CHTAB4.GD", 15),
]


def labelled_fcb(path):
    """label -> bytes, for every label line followed by fcb lines in a generated batch."""
    out, cur = {}, None
    for line in pathlib.Path(path).read_text(encoding="utf-8").splitlines():
        s = line.split(";")[0].rstrip()
        if s and not s[0].isspace() and not s.startswith("*"):
            cur = s.strip() if re.fullmatch(r"[A-Za-z_][\w]*", s.strip()) else None
            if cur:
                out[cur] = []
        elif cur and s.strip().lower().startswith("fcb"):
            for tok in s.strip()[3:].split(","):
                tok = tok.strip()
                out[cur].append(int(tok[1:], 16) if tok.startswith("$") else int(tok))
        elif s.strip():
            cur = None
    return out


def key(c):
    return (c["tag"], c["f"], c["k"], c["mode"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-verdict", action="store_true", help="skip the probe-log comparison")
    a = ap.parse_args()
    recs = json.load(open(ROOT / "build/chars/bake.json"))
    game = [r for r in recs if r["table"] in B.GAMEPLAY]
    guards = [r for r in recs if r["table"] in B.GUARDS]
    baked = {B.p520_tag(r["table"], r["idx"]): bytes(B.fcb_values(ROOT / r["p0"])) for r in recs}
    fails = 0

    # ------------------------------------------------------------- AC5 (ref)
    print("=" * 92)
    print("AC5 — every baked p0 vs P5.20's census batches (build/xform/b###_gen.s)")
    print("=" * 92)
    batches = sorted(XF.glob("b[0-9][0-9][0-9]_gen.s"))
    ref_src, ref_r00 = {}, {}
    for p in batches:
        for lab, v in labelled_fcb(p).items():
            if lab.endswith("_src"):
                ref_src[lab[:-4]] = bytes(v)
            elif lab.endswith("_r00"):
                ref_r00[lab[:-4]] = bytes(v)
    print("   %d batches; %d `_src` streams, %d `_r00` references found" % (len(batches), len(ref_src), len(ref_r00)))
    n_ok = 0
    for r in game:
        tag = B.p520_tag(r["table"], r["idx"])
        mine = baked[tag]
        for name, ref in (("_src", ref_src.get(tag)), ("_r00", ref_r00.get(tag))):
            if ref is None:
                print("   MISSING %s%s in P5.20's batches" % (tag, name))
                fails += 1
            elif ref != mine:
                diffs = [(i, x, y) for i, (x, y) in enumerate(zip(mine, ref)) if x != y]
                print("   DIFFER %s%s: len %d vs %d; %d differing bytes, first %r"
                      % (tag, name, len(mine), len(ref), len(diffs), diffs[:5]))
                fails += 1
        if ref_src.get(tag) == mine and ref_r00.get(tag) == mine:
            n_ok += 1
    print("   ★ %d / %d gameplay cels byte-exact against BOTH P5.20 streams" % (n_ok, len(game)))

    # ------------------------------------------------------------- AC5 (blob)
    print()
    print("AC5 — the bake, concatenated in disk_capacity's order, vs P5.22's build/p522/cast_seg.bin")
    order = sorted(B.p520_tag(r["table"], r["idx"]) for r in game)
    cat = b"".join(baked[t] for t in order)
    blob = (ROOT / "build/p522/cast_seg.bin").read_bytes()
    same = cat == blob
    fails += 0 if same else 1
    print("   bake %d B, blob %d B: %s" % (len(cat), len(blob), "BYTE-IDENTICAL" if same else "DIFFER"))

    # ------------------------------------------------------------- cases
    print()
    print("AC6 (static) — P5.20's case records vs the --baked records")
    old = {key(c): c for p in sorted(XF.glob("b[0-9][0-9][0-9]_cases.json"))
           for c in json.load(open(p))["cases"] if c.get("mode") in ("base", "xform")}
    new = {key(c): c for p in sorted(XF.glob("k[0-9][0-9][0-9]_cases.json"))
           for c in json.load(open(p))["cases"] if c.get("mode") in ("base", "xform")}
    if not new:
        print("   no k### case files -- run run_xform_probe.sh --all-gameplay --baked (XF_PREFIX=k)")
        fails += 1
    else:
        same_keys = set(old) == set(new)
        bad = [k for k in old if k in new and any(old[k][f] != new[k][f]
                                                  for f in ("want", "col", "a", "b", "h", "stream", "fn"))]
        print("   %d cases before, %d after; same case set: %s; differing in want/col/A/B/h/stream/fn: %d"
              % (len(old), len(new), same_keys, len(bad)))
        fails += 0 if (same_keys and not bad) else 1

    # ------------------------------------------------------------- verdict
    if not a.no_verdict:
        print()
        print("AC6 — the probe's verdicts and cycles: P5.20 (b) vs baked (k)")
        def logs(pre):
            out = {}
            for p in sorted(XF.glob("%s[0-9][0-9][0-9].log.json" % pre)):
                for r in json.load(open(p))["results"]:
                    out[key(r)] = r
            return out
        ob, nk = logs("b"), logs("k")
        if not nk:
            print("   no k### logs yet")
            fails += 1
        else:
            nok = sum(1 for r in nk.values() if r["ok"])
            cyc = sum(1 for k in ob if k in nk and ob[k]["cyc"] == nk[k]["cyc"])
            okeq = sum(1 for k in ob if k in nk and ob[k]["ok"] == nk[k]["ok"])
            print("   P5.20: %d cases, %d ok    baked: %d cases, %d ok" % (len(ob), sum(1 for r in ob.values() if r["ok"]), len(nk), nok))
            print("   verdict identical per case: %d / %d    cycle count identical per case: %d / %d"
                  % (okeq, len(ob), cyc, len(ob)))
            fails += 0 if (nok == len(nk) == len(ob) and cyc == len(ob)) else 1

    # ------------------------------------------------------------- AC7
    print()
    print("=" * 92)
    print("AC7 — the nine P1.2 cels, re-converted today by the same call (start_col 0, trim)")
    print("=" * 92)
    ctl = ROOT / "build/chars/control"
    for d, table, idx in CONTROL:
        name = pathlib.PurePosixPath(d).name
        out = ctl / name / "converted.s"
        out.parent.mkdir(parents=True, exist_ok=True)
        info = SC.convert_one(B.IMG / table, idx, out, name, 0, False, False, trim=True, quiet=True)
        old_b = (ROOT / d / "converted.s").read_bytes()
        new_b = out.read_bytes()
        ov, nv = B.fcb_values(ROOT / d / "converted.s"), B.fcb_values(out)
        t = B.short(table)
        bk = B.fcb_values(ROOT / "content/chars" / t / ("%s_%03d_src.s" % (t, idx)))
        print("   %-32s file %-9s  pixels(old vs today) %-9s  pixels(today vs bake) %s"
              % (name, "IDENTICAL" if old_b == new_b else "DIFFER",
                 "IDENTICAL" if ov == nv else "DIFFER", "IDENTICAL" if nv == bk else "DIFFER"))
        if ov != nv:
            print("      old %dx%d  today %dx%d   (header: rows, bytes/row)" % (ov[0], ov[1], nv[0], nv[1]))
            if ov[0] == nv[0] and ov[1] == nv[1]:
                rows = [r for r in range(ov[0]) if ov[2 + r * ov[1]:2 + (r + 1) * ov[1]] != nv[2 + r * nv[1]:2 + (r + 1) * nv[1]]]
                print("      rows differing: %d of %d" % (len(rows), ov[0]))
            else:
                h = ov[0]
                lead = nv[1] - ov[1]
                shifted = all(nv[2 + r * nv[1] + lead:2 + (r + 1) * nv[1]] == ov[2 + r * ov[1]:2 + (r + 1) * ov[1]]
                              and not any(nv[2 + r * nv[1]:2 + r * nv[1] + lead]) for r in range(h)) if lead > 0 else False
                print("      today = old with %d leading all-zero byte column(s) restored: %s" % (lead, shifted))
        elif old_b != new_b:
            ol, nl = old_b.decode().splitlines(), new_b.decode().splitlines()
            print("      text lines differing: %r" % [(i, ol[i], nl[i]) for i in range(min(len(ol), len(nl))) if ol[i] != nl[i]][:4])

    # ------------------------------------------------------------- sizes
    print()
    print("=" * 92)
    print("AC8/AC9 — SIZE. Segment-stream bytes ([h,w]+segments), lz_pack in 8,192 B chunks")
    print("          (disk_capacity.lz), tracks of %d B. NOT residency, NOT draw volume." % TRACK)
    print("=" * 92)

    def lzrow(what, tags):
        data = b"".join(baked[t] for t in tags)
        c = DC.lz(data)
        print("   %-46s %4d cels  %7d B  -> lz %6d B  %5.2fx   %2d -> %2d tracks"
              % (what, len(tags), len(data), c, len(data) / c, DC.tracks(len(data)), DC.tracks(c)))
        return len(data), c

    s290, c290 = lzrow("gameplay 290 (CHTAB1/2/3/4.GD/5), tag order", order)
    print("   ★ delta vs §5.338 (91,906 B / 41,426 B / 9 tracks): stream %+d B, lz %+d B, tracks %+d"
          % (s290 - 91906, c290 - 41426, DC.tracks(c290) - 9))
    clo = json.load(open(ROOT / "build/chars/closure.json"))["closure"]
    ctags = sorted(B.p520_tag(t, i) for t, i in clo)
    s271, c271 = lzrow("closure 271 (P5.9's W-inf kid U guard)", ctags)
    print("   the 19 the closure omits: stream %d B, lz delta %d B" % (s290 - s271, c290 - c271))
    print()
    print("   per table (each its own lz run -- what a per-table or per-level load would read):")
    tot_s = tot_c = 0
    for table in B.GAMEPLAY + B.GUARDS:
        tags = sorted(B.p520_tag(r["table"], r["idx"]) for r in recs if r["table"] == table)
        s, c = lzrow("  " + table, tags)
        if table in B.GAMEPLAY:
            tot_s += s
            tot_c += c
    print("   gameplay tables lz'd separately, summed: %d B -> %d B lz (%d tracks)" % (tot_s, tot_c, DC.tracks(tot_c)))
    gtags = sorted(B.p520_tag(r["table"], r["idx"]) for r in guards)
    lzrow("guard sets FAT+SHAD+SKEL+VIZ, one run", gtags)

    print()
    print("bake_chars_check: %s" % ("PASS" if not fails else "FAIL (%d)" % fails))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
