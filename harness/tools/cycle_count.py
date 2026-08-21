#!/usr/bin/env python3
r"""cycle_count.py - P5.2. Cycles for a straight-line 6809 routine, decoded from the BUILT
binary rather than counted off the source.

★ WHY THE BINARY. "Measure, do not estimate" — and the assembler is exactly the place a
source-level count and reality can part company (an operand that assembles direct-page when
you counted extended is a 2-cycle error per access, repeated). This walks the emitted bytes.

★ AND WHY A TABLE OF COUNTS IS A MEASUREMENT AND NOT A GUESS ON A 6809: every instruction
here has ONE documented, data-independent cycle count. There are no cache effects, no
pipeline, and no variable-latency memory. [MC6809 Programming Manual, vendored at
docs/ground-truth/] The only conditional cost in this file's scope is a taken branch, and
these routines are straight-line.

It handles the small subset the arrangement path uses and REFUSES anything else, loudly —
a decoder that silently skips an opcode would under-count, which is the failure this exists
to avoid.
"""
import pathlib
import sys

# opcode -> (mnemonic, total bytes, cycles).  Only what these routines contain.
OPS = {
    0x34: ("pshs", 2, None),     # 5 + 1 per byte pushed; postbyte decides
    0x35: ("puls", 2, None),     # 5 + 1 per byte pulled
    0x1A: ("orcc #", 2, 3),
    0x1C: ("andcc #", 2, 3),
    0xB6: ("lda ext", 3, 5),
    0xB7: ("sta ext", 3, 5),
    0x96: ("lda dp", 2, 4),
    0x97: ("sta dp", 2, 4),
    0xBD: ("jsr ext", 3, 8),
    0x9D: ("jsr dp", 2, 7),
    0x39: ("rts", 1, 5),
    0xFC: ("ldd ext", 3, 6),
    0xDC: ("ldd dp", 2, 5),
    0xFD: ("std ext", 3, 6),
    0x10: ("prefix10", 0, 0),    # handled below
    0x86: ("lda imm", 2, 2),
    0xC6: ("ldb imm", 2, 2),
    0x27: ("beq rel", 2, 3),
    0x26: ("bne rel", 2, 3),
    0x4C: ("inca", 1, 2),
    0x12: ("nop", 1, 2),
}
# 10-prefixed
OPS10 = {
    0x83: ("cmpd imm", 4, 5),
    0xB3: ("cmpd ext", 4, 7),
    0x93: ("cmpd dp", 3, 6),
    0x27: ("lbeq", 4, 5),        # 5 not taken / 6 taken on 6809
}


def pshs_cycles(post):
    return 5 + bin(post).count("1") + (1 if post & 0x40 else 0) + (1 if post & 0x80 else 0) \
        + (1 if post & 0x10 else 0) + (1 if post & 0x20 else 0)


def decode(buf, org, start, stop_after_rts=True, limit=64):
    """-> list of (addr, bytes, mnemonic, cycles)"""
    out = []
    i = start - org
    for _ in range(limit):
        a = org + i
        op = buf[i]
        if op == 0x10:
            sub = buf[i + 1]
            if sub not in OPS10:
                raise SystemExit("unhandled 10-prefixed opcode $10%02X at $%04X" % (sub, a))
            mn, ln, cy = OPS10[sub]
        else:
            if op not in OPS:
                raise SystemExit("unhandled opcode $%02X at $%04X — add it rather than "
                                 "letting the count skip it" % (op, a))
            mn, ln, cy = OPS[op]
            if op in (0x34, 0x35):
                post = buf[i + 1]
                # PSHS/PULS: 5 + one cycle per BYTE moved. CC/A/B/DP are 1 byte each,
                # X/Y/U/PC are 2. [MC6809 PM]
                n = 0
                for bit, w in ((0x01, 1), (0x02, 1), (0x04, 1), (0x08, 1),
                               (0x10, 2), (0x20, 2), (0x40, 2), (0x80, 2)):
                    if post & bit:
                        n += w
                cy = 5 + n
                mn = "%s $%02X" % (mn, post)
        raw = " ".join("%02X" % b for b in buf[i:i + ln])
        out.append((a, raw, mn, cy))
        i += ln
        if stop_after_rts and mn == "rts":
            break
    return out


def main():
    if len(sys.argv) < 4:
        print("usage: cycle_count.py <raw.bin> <org-hex> <sym-hex> [limit]")
        return 1
    buf = pathlib.Path(sys.argv[1]).read_bytes()
    org = int(sys.argv[2], 16)
    sym = int(sys.argv[3], 16)
    limit = int(sys.argv[4]) if len(sys.argv) > 4 else 64
    rows = decode(buf, org, sym, limit=limit)
    tot = 0
    print("  addr   bytes           insn              cy")
    for a, raw, mn, cy in rows:
        print("  $%04X  %-14s  %-16s %3d" % (a, raw, mn, cy))
        tot += cy
    print("  %-40s %3d cycles" % ("TOTAL (body, excluding the JSR to it)", tot))
    print("  %-40s %3d cycles" % ("with `jsr` extended (8 cy)", tot + 8))
    return 0


if __name__ == "__main__":
    sys.exit(main())
