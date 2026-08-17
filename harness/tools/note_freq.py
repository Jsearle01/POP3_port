"""note_freq.py — P4.3 §1: does the oracle's music fit the CoCo3 FIRQ floor?

★★★ THE QUESTION. P4.2 found, while measuring something else, that the GIME's countdown
timer is 12 bits — ceiling 4095 — so at TINS=1 (279.365 ns) the LOWEST tone an interrupt
player can produce is ~468 Hz. Nobody had checked that against the actual notes. If the
music goes below it, the FIRQ design has a hole before a line of the player is written.

★★ THE MAPPING IS DERIVED FROM THE LOOP, NOT ESTIMATED. MSYS.S's tone segment [MSEG,
around line 507] is:

    MSEG    LDY R+3          3      R+8 = NOTE[index]   the note period
    MBASS1  LDA HM1,Y        4      R+6 = VTBL[...]     the VOLUME / pulse width
            BMI MSEGL4       2
            INC R+3          5
            TAY              2
            LDA VTBL-1,Y     4
            STA R+6          3
            SEC              2
            SBC R+8          3      A = R+6 - R+8
            TAY              2
    MADJLP  INY / BNE        5/it   -> (R8 - R6) mod 256 iterations
    MLBL300 LDY #1           2
    MLMDI   LDA R+8          3
            SEC              2
    MDLOOP  SBC #1 / BNE     5/it   -> R8 iterations
            DEY / BNE        4
            LDY R+6          3
            BEQ MFIZZLE      2
    M30A    LDA $C030        4      <-- SPEAKER TOGGLE
    MVDIT   DEY / BNE        5/it   -> R6 iterations
    M30B    LDA $C030        4      <-- SPEAKER TOGGLE
    MFIZZLE DEX              2
            BNE MSEG         3

★★★ THE VOLUME TERM CANCELS, AND THAT IS THE WHOLE TRICK. The three loops cost
5*(R8-R6) + 5*R8 + 5*R6 = 10*R8 — independent of R6. So the PERIOD is set by the note and
the PULSE WIDTH by the volume: constant-period, variable-duty, which is how a one-bit
speaker gets amplitude at all. Two toggles per pass = one full square-wave cycle.

    period_cycles = 56 + 10 * NOTE        (56 = the straight-line path, counted above)
    f = CPU_HZ / period_cycles

★ THE OVERHEAD IS THE ONLY SOFT NUMBER, so this reports the answer's SENSITIVITY to it
rather than quoting one figure — a constant counted by hand from a listing is exactly the
kind of thing this project has been bitten by (counted != assembled != executed, P3.39,
P3.41). At the low notes the 10*NOTE term is 45x the overhead, so the verdict does not
depend on it; the tool shows that instead of asserting it.
"""
import argparse
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

# The Apple II's 6502. 1.020484 MHz is the standard NTSC figure (14.31818 MHz / 14).
CPU_HZ = 1020484.0

# MSYS.S:30-36, transcribed. Index 0 is NOTE+0.
NOTE = [122, 254, 238, 226, 214, 202, 190, 178, 170, 158, 150, 142, 134,
        126, 118, 112, 106, 100, 94, 88, 84, 78, 74, 70, 66,
        250, 234, 222, 210, 198, 186, 174, 166, 154, 146, 138, 130,
        122, 114, 108, 102, 96, 90, 84, 80, 74, 70, 66, 62,
        58, 54, 51, 48, 45, 42, 39, 37, 34, 32, 30, 28,
        26, 24, 22, 21, 19, 18, 17, 16, 15, 14, 13, 12,
        11, 10, 9]

# P4.2, measured: the GIME timer is 12 bits, so at TINS = 279.365 ns the longest
# half-period is 4095 ticks and the lowest tone is 1 / (2 * 4095 * 279.365ns).
TINS_NS = 279.365
TIMER_MAX = 4095
FLOOR_HZ = 1.0 / (2 * TIMER_MAX * TINS_NS * 1e-9)


def freq(n, overhead):
    return CPU_HZ / (overhead + 10.0 * n)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--overhead", type=int, default=56,
                    help="straight-line cycles per MSEG pass (counted from the listing)")
    a = ap.parse_args()

    print("# THE ORACLE'S NOTE TABLE AS FREQUENCIES, against the CoCo3 FIRQ floor")
    print("# period = %d + 10*NOTE cycles at %.0f Hz; volume cancels (see the header)."
          % (a.overhead, CPU_HZ))
    print("# GIME floor: 1/(2 * %d * %.3f ns) = %.1f Hz" % (TIMER_MAX, TINS_NS, FLOOR_HZ))
    print()

    below = [(i, n, freq(n, a.overhead)) for i, n in enumerate(NOTE)
             if freq(n, a.overhead) < FLOOR_HZ]
    lo = min(NOTE)
    hi = max(NOTE)
    print("  entries          %d" % len(NOTE))
    print("  period range     %d .. %d  ->  %.1f Hz .. %.1f Hz"
          % (hi, lo, freq(hi, a.overhead), freq(lo, a.overhead)))
    print("  span             %.2f octaves"
          % (__import__("math").log2(freq(lo, a.overhead) / freq(hi, a.overhead))))
    print()

    print("  idx  NOTE  freq Hz   vs floor")
    for i, n in enumerate(NOTE):
        f = freq(n, a.overhead)
        if f < FLOOR_HZ * 1.15:          # show the neighbourhood, not just the failures
            mark = "★ BELOW by %.0f Hz (%.1f%%)" % (FLOOR_HZ - f, 100 * (FLOOR_HZ - f) / FLOOR_HZ) \
                   if f < FLOOR_HZ else "  above by %.0f Hz" % (f - FLOOR_HZ)
            print("  %-4d %-5d %-9.1f %s" % (i, n, f, mark))
    print()

    if below:
        print("# ★★★ %d of %d TABLE ENTRIES FALL BELOW THE FLOOR." % (len(below), len(NOTE)))
        print("#   lowest: NOTE[%d] = %d = %.1f Hz, which is %.1f%% below %.1f Hz."
              % (below[0][0], below[0][1], below[0][2],
                 100 * (FLOOR_HZ - below[0][2]) / FLOOR_HZ, FLOOR_HZ))
        print("#   ★ This is about the TABLE. Whether any SONG reaches these entries is a")
        print("#     separate question — what is used is not what exists.")
    else:
        print("# No table entry falls below the floor.")

    # ---- sensitivity: does the verdict depend on the hand-counted overhead? ----------
    print()
    print("# ★ SENSITIVITY OF THE VERDICT TO THE HAND-COUNTED OVERHEAD")
    print("#   overhead   sub-floor entries   lowest Hz")
    for ov in (0, 28, 56, 84, 120):
        b = [n for n in NOTE if freq(n, ov) < FLOOR_HZ]
        print("#   %-10d %-19d %.1f" % (ov, len(b), freq(max(NOTE), ov)))
    print("#   At the low notes 10*NOTE is ~45x the overhead, so the verdict is the same")
    print("#   across every plausible count. The exact frequency is not; the VERDICT is.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
