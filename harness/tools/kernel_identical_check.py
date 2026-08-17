"""kernel_identical_check.py — P3.106: the scene's dropped kernel IS the resident one.

★★★ WHAT THIS GUARDS. The scene's disk-resident image (link/pop_scene.link) is linked WITH
`hal_build.o` so its `HAL_*` calls resolve, and the build then DROPS that segment
(`decb_to_raw --span-end`) because the kernel is already resident at $7900 from the intro's
LOADM — and re-reading it from a track while it is executing the read would overwrite the
routine mid-transfer.

**That is only safe if the two kernels are the same bytes at the same address.** They are,
by construction: both links take the same `build/obj/hal_build.o` and both scripts say
`section code load 7900`.

★★ "BY CONSTRUCTION" IS THE EXACT SHAPE OF ASSUMPTION THIS PROJECT HAS BEEN BITTEN BY:
"the two programs never run at once" (P3.104), "both cels trim with lead=0" (P3.103), "the
scene isn't changed by integration" (P3.104 §4a), the 512 KB default across ten homes
(P3.98-P3.101). Each was true when written and enforced by nothing. So it is asserted here
rather than trusted, and the assertion is two lines of comparison against the artefacts the
build actually produces — not against the inputs it was supposed to use.

Fails the build on any divergence, which is what makes it a check rather than a comment.
"""
import argparse
import pathlib
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass


def segments(path):
    """[(load_addr, bytes)] from an lwlink --decb image."""
    d = pathlib.Path(path).read_bytes()
    out, i = [], 0
    while i < len(d):
        t = d[i]
        ln = (d[i + 1] << 8) | d[i + 2]
        ad = (d[i + 3] << 8) | d[i + 4]
        if t == 0xFF:
            break
        out.append((ad, d[i + 5:i + 5 + ln]))
        i += 5 + ln
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--resident", required=True,
                    help="the image that is LOADM'd and stays resident (the intro)")
    ap.add_argument("--staged", required=True,
                    help="the image whose kernel segment the build drops (the scene)")
    ap.add_argument("--addr", type=lambda s: int(s, 0), default=0x7900)
    a = ap.parse_args()

    def kernel(path):
        segs = [(ad, b) for ad, b in segments(path) if ad == a.addr]
        if not segs:
            sys.exit(f"[kernel-identical] no segment at ${a.addr:04X} in {path}")
        if len(segs) > 1:
            sys.exit(f"[kernel-identical] {len(segs)} segments at ${a.addr:04X} in {path}")
        return segs[0][1]

    r, s = kernel(a.resident), kernel(a.staged)
    if r == s:
        print(f"[kernel-identical] OK — ${a.addr:04X} is byte-identical in both images "
              f"({len(r)} B). The staged image's kernel segment may be dropped.")
        return 0

    # Say WHERE, because "they differ" sends the reader back to the whole file.
    n = min(len(r), len(s))
    first = next((i for i in range(n) if r[i] != s[i]), n)
    sys.exit(f"[kernel-identical] FAIL — ${a.addr:04X} differs between\n"
             f"    resident {a.resident} ({len(r)} B)\n"
             f"    staged   {a.staged} ({len(s)} B)\n"
             f"  first difference at offset {first} (${a.addr + first:04X}). The scene's "
             f"dropped kernel is NOT the one that will be resident, so dropping it would "
             f"leave the scene calling a kernel it was not linked against.")


if __name__ == "__main__":
    sys.exit(main())
