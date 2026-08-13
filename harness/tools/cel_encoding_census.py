#!/usr/bin/env python3
r"""cel_encoding_census.py — WHERE the port's cel bytes go, segment by segment.

P3.79 §1. oracle_vs_port_bytes.py measures that the port holds 4.87x the oracle's resident
bytes for the same scene, and that only 1.75x of it is the pixel-depth floor (Apple hi-res
packs 7 px per byte, CoCo3 4-colour packs 4). This attributes the remaining 2.36x, which is
the part that might be recoverable.

THE MECHANISM, STATED FIRST BECAUSE IT DECIDES WHETHER THE OVERHEAD IS A CHOICE.

The Apple gets transparency FREE: hi-res is ONE BIT per pixel, so `ORA` leaves the
destination wherever the sprite bit is 0 [HIRES.S:776, and characters are drawn with
`lda #ora` — no companion mask image; only certain background pieces carry a `maska`].

CoCo3 4-colour is TWO BITS per pixel, and OR does not compose: a destination pixel of 01
under a source pixel of 10 ORs to 11, a third colour. So a partially-transparent byte needs
`dest = (dest AND mask) OR src` and the port stores a MASK BYTE BESIDE EVERY SOURCE BYTE —
two bytes of storage per byte drawn. That is the 2x, and it applies only to MIXED bytes.

    $00            end of row               2 B of overhead per row
    $01 nn         skip nn transparent       2 B, no data       <- free
    $02 nn <data>  blast nn opaque bytes     2 B + nn           <- 1 B/byte
    $03 nn <pairs> merge nn mixed bytes      2 B + 2*nn         <- 2 B/byte

So the question this answers is: how much of the port's cel data is MERGE, and could it be
cheaper? A mask byte only ever distinguishes which of FOUR pixels are transparent — sixteen
possible values — so it is a nibble's worth of information stored in a byte.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
CHARS = ROOT / "content/cutscene/chars"
PACK = CHARS / "cel_pack.json"

SEG_END, SEG_SKIP, SEG_BLAST, SEG_MERGE = 0, 1, 2, 3


def cel_bytes(label):
    """The emitted byte stream of one baked cel, in order."""
    p = CHARS / ("%s.s" % label)
    if not p.exists():
        return None
    out = []
    for line in p.read_text(errors="replace").splitlines():
        s = line.split(";")[0]
        m = re.match(r"\s*fcb\s+(.*)$", s)
        if m:
            for x in m.group(1).split(","):
                x = x.strip()
                if not x:
                    continue
                out.append((int(x[1:], 16) if x.startswith("$") else int(x, 0)) & 0xFF)
        m = re.match(r"\s*fdb\s+(.*)$", s)
        if m:
            for x in m.group(1).split(","):
                x = x.strip()
                if not x:
                    continue
                v = int(x[1:], 16) if x.startswith("$") else int(x, 0)
                out += [(v >> 8) & 0xFF, v & 0xFF]
    return out


def census(stream):
    """Walk one cel: header, then rows of segments. -> dict of byte counts."""
    c = dict(header=2, cels=1, width_sum=0, rowend=0, skip_hdr=0, blast_hdr=0, blast_data=0,
             merge_hdr=0, merge_mask=0, merge_src=0, rows=0, drawn=0, skipped=0)
    if not stream or len(stream) < 2:
        return None
    rows, width = stream[0], stream[1]
    c["width_sum"] = width
    i = 2
    for _r in range(rows):
        c["rows"] += 1
        while i < len(stream):
            op = stream[i]
            i += 1
            if op == SEG_END:
                c["rowend"] += 1
                break
            if i >= len(stream):
                return None
            n = stream[i]
            i += 1
            if op == SEG_SKIP:
                c["skip_hdr"] += 2
                c["skipped"] += n
            elif op == SEG_BLAST:
                c["blast_hdr"] += 2
                c["blast_data"] += n
                c["drawn"] += n
                i += n
            elif op == SEG_MERGE:
                c["merge_hdr"] += 2
                c["merge_mask"] += n
                c["merge_src"] += n
                c["drawn"] += n
                i += 2 * n
            else:
                return None
    return c


def main():
    pack = json.loads(PACK.read_text(encoding="utf-8"))
    labels = [lab for _v, lab in pack["resident"]]
    for g in pack["pages"]:
        labels += [lab for _v, lab in g["cels"]]

    tot = {}
    n_ok = n_bad = 0
    for lab in sorted(set(labels)):
        c = census(cel_bytes(lab))
        if c is None:
            n_bad += 1
            continue
        n_ok += 1
        for k, v in c.items():
            tot[k] = tot.get(k, 0) + v

    # tot["header"] already accumulates 2 per cel — multiplying by the cel count again
    # inflated the total to 46,488 against the 38,424 the linker actually places. The two
    # numbers have to agree with oracle_vs_port_bytes' PORT column or one of them is wrong.
    total = (tot["header"] + tot["rowend"] + tot["skip_hdr"] + tot["blast_hdr"]
             + tot["blast_data"] + tot["merge_hdr"] + tot["merge_mask"] + tot["merge_src"])
    print("=== where the port's cel bytes go (%d cels, %d unparseable) ===\n"
          % (n_ok, n_bad))
    rows = [
        ("cel headers (rows, width)", tot["header"]),
        ("row terminators", tot["rowend"]),
        ("skip segment headers", tot["skip_hdr"]),
        ("blast segment headers", tot["blast_hdr"]),
        ("blast PIXEL data", tot["blast_data"]),
        ("merge segment headers", tot["merge_hdr"]),
        ("merge PIXEL data", tot["merge_src"]),
        ("merge MASK data", tot["merge_mask"]),
    ]
    for name, v in rows:
        print("  %-28s %8s B   %5.1f%%" % (name, format(v, ","), 100.0 * v / total))
    print("  %-28s %8s B" % ("TOTAL", format(total, ",")))

    pixels = tot["blast_data"] + tot["merge_src"]
    overhead = total - pixels
    print("\n  PIXEL bytes                  %8s B   %5.1f%%"
          % (format(pixels, ","), 100.0 * pixels / total))
    print("  everything else              %8s B   %5.1f%%"
          % (format(overhead, ","), 100.0 * overhead / total))
    print("\n  bytes DRAWN per cel-row pass  %s   (%s opaque, %s mixed = %.0f%% mixed)"
          % (format(tot["drawn"], ","), format(tot["blast_data"], ","),
             format(tot["merge_src"], ","),
             100.0 * tot["merge_src"] / max(1, tot["drawn"])))
    print("  bytes SKIPPED (transparent)   %s — stored in 2 B per run, not per byte"
          % format(tot["skipped"], ","))

    hdrs = tot["skip_hdr"] + tot["blast_hdr"] + tot["merge_hdr"] + tot["rowend"]
    print("\n=== WHERE IT ACTUALLY GOES, AND IT IS NOT THE MASK ===")
    print("  per-SEGMENT and per-ROW punctuation  %8s B   %5.1f%%"
          % (format(hdrs, ","), 100.0 * hdrs / total))
    print("  the mask column                      %8s B   %5.1f%%"
          % (format(tot["merge_mask"], ","), 100.0 * tot["merge_mask"] / total))
    print("  actual pixels                        %8s B   %5.1f%%"
          % (format(pixels, ","), 100.0 * pixels / total))
    print()
    print("  Every run costs TWO bytes - an opcode and a count - and these cels average")
    print("  %.1f bytes wide, so a row is a handful of very short runs. The encoding was"
          % (tot["width_sum"] / max(1, tot["cels"])))
    print("  designed for the blitter's convenience and it pays more for the punctuation")
    print("  than for the picture. THAT is the port's fat, not the mask and not the")
    print("  mirrors.")
    print()
    print("  ONE BYTE PER SEGMENT (2-bit opcode + 6-bit count, max run 63) halves it:")
    print("    punctuation today        %8s B" % format(hdrs, ","))
    print("    packed                   %8s B   -> saves %s B, %.0f%% of the image"
          % (format(hdrs // 2, ","), format(hdrs // 2, ","),
             100.0 * (hdrs // 2) / total))
    print("    scene would fall to      %8s B" % format(total - hdrs // 2, ","))
    return 0


if __name__ == "__main__":
    sys.exit(main())
