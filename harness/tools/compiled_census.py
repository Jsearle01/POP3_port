#!/usr/bin/env python3
r"""compiled_census.py — P5.21: compiled sprites on GAMEPLAY content, on P5.20's sample and unit.

Measures what reopening the compiled-sprite gate would cost; it reopens nothing. For each of the
290 gameplay cels P5.20 censused (the facing-0, phase-0 conversions xform_probe_gen.py wrote to
build/xform/cels/), run the production compiler (sprite_compiler.compile_cel, unmodified,
bg_zero=False -- the only setting valid under the peel) and then:

  * SIZE: assemble every emitted DRAW routine with lwasm and take each routine's exact byte count
    from the symbol table -- not an instruction-count estimate. Against the cel's raw packed 2bpp
    bitmap (P3.18's base for its 8.2x) AND against its shipped segment stream (what the port
    actually stores).
  * CYCLES: the compiler's own static count (straight-line code, so static == executed apart from
    the call), divided by the SAME phase-0 footprint P5.20 used, ceil(7*apple_w/4)*h, so it sits
    beside P5.20's measured blit_cel figure for the same cels at the same pose.
"""
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "sprite_tool"))
import sprite_compiler as SC                                  # noqa: E402
import xform_probe_gen as G                                   # noqa: E402
from celio import Cel                                         # noqa: E402

LWASM = shutil.which("lwasm") or r"C:\WIN_LWTools\lwasm.exe"


def main():
    poses = {c["tag"]: c for c in json.load(open(ROOT / "build/xform/p_peel_poses.json"))}
    draws = {}
    for p in (ROOT / "build/xform").glob("b[0-9][0-9][0-9].log.json"):
        for r in json.load(open(p))["results"]:
            draws[(r["tag"], r["f"], r["k"], r["mode"])] = r["cyc"]

    tmp = pathlib.Path(tempfile.mkdtemp(prefix="p521cc_"))
    asm = ["        org     $0000"]
    rows = []
    for tag, meta in sorted(poses.items()):
        src = ROOT / "build/xform/cels" / ("%s_f0.s" % tag)
        d = tmp / tag
        d.mkdir()
        shutil.copy(src, d / "converted.s")
        r = SC.compile_cel(d, bg_zero=False)
        if r["bad"]:
            raise SystemExit("%s: the compiler's own simulator rejects it (%d)" % (tag, len(r["bad"])))
        label = "d_" + tag
        for kind, e in (("d", r["draw"]), ("s", r["save"]), ("e", r["erase"])):
            lab = "%s_%s" % (kind, tag)
            asm.append(SC.render_asm(lab, e, kind, ""))
            asm.append("%s_end" % lab)
        cel = Cel(str(src))
        stream = G.stream(cel, 0)
        rows.append(dict(tag=tag, label=label, footprint=meta["footprint"], raw=cel.w * cel.h,
                         seg=len(stream), dcy=r["dcy"], scy=r["scy"], ecy=r["ecy"],
                         blit=draws.get((tag, 0, 0, "base"))))
    (tmp / "all.s").write_text("\n".join(asm) + "\n", newline="\n")
    sym = tmp / "all.sym"
    p = subprocess.run([LWASM, "-9", "--raw", "-o", str(tmp / "all.bin"), "--symbol-dump=" + str(sym),
                        str(tmp / "all.s")], capture_output=True, text=True)
    if p.returncode:
        raise SystemExit("lwasm failed:\n" + p.stdout + p.stderr)
    addr = {}
    for ln in sym.read_text().splitlines():
        m = re.match(r"^(\S+)\s+EQU\s+\$([0-9A-Fa-f]+)", ln)
        if m:
            addr[m.group(1)] = int(m.group(2), 16)
    for r in rows:
        r["code"] = addr[r["label"] + "_end"] - addr[r["label"]]
        t = r["tag"]
        r["scode"] = addr["s_%s_end" % t] - addr["s_%s" % t]
        r["ecode"] = addr["e_%s_end" % t] - addr["e_%s" % t]
    shutil.rmtree(tmp, ignore_errors=True)

    S = lambda k: sum(r[k] for r in rows)
    fp = S("footprint")
    print("cels %d   phase 0, facing 0, bg_zero=False (the peel model)" % len(rows))
    print()
    print("SIZE (draw routines only, assembled):")
    print("   raw packed bitmap   %7d B" % S("raw"))
    print("   segment stream      %7d B   (%.2fx raw)  -- what the port stores" % (S("seg"), S("seg") / S("raw")))
    print("   compiled DRAW code  %7d B   = %.2fx raw (P3.18 cutscene: 8.2x)  = %.2fx the segment stream"
          % (S("code"), S("code") / S("raw"), S("code") / S("seg")))
    allc = S("code") + S("scode") + S("ecode")
    print("   + compiled SAVE %d B + ERASE %d B  -> draw+save+erase %d B = %.2fx raw"
          % (S("scode"), S("ecode"), allc, allc / S("raw")))
    print()
    print("CYCLES per phase-0 footprint B (P5.20's unit), same 290 cels, same pose (facing 0, phase 0):")
    print("   compiled draw (static count)   %6.2f" % (S("dcy") / fp))
    print("   compiled save + erase          %6.2f" % ((S("scy") + S("ecy")) / fp))
    print("   blit_cel (MEASURED, P5.20)     %6.2f" % (S("blit") / fp))
    print("   ratio blit_cel / compiled draw %6.1fx" % (S("blit") / S("dcy")))


if __name__ == "__main__":
    main()
