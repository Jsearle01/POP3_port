"""pack_song.py — P4.5: turn the MEASURED speaker stream into a table the 6809 can walk.

★★★ THE SLICE IS DRIVEN BY MEASUREMENT, NOT BY A DECODE. `MUSIC.SET*` has never been
decoded (open since P4.1) and does not need to be for a vertical slice: what the port has
to reproduce is what the SPEAKER DID, and `oracle_speaker_intervals.lua` recorded exactly
that — one (pulse, rest) pair per segment, off the running machine.

★★ RUN-LENGTH ENCODED, because the raw stream is enormously repetitive: a held note is the
same pair over and over (twelve identical segments before the first change in P4.4's raw
dump). 3,924 segments compress to a few hundred runs, which is the difference between a
table that fits in the port and one that does not.

---------------------------------------------------------------------------
THE TIMER VALUE, AND WHY TINS=0
---------------------------------------------------------------------------
P4.4 measured the rates the music actually uses: 101 Hz .. 943 Hz. The GIME timer is 12
bits, so at TINS=1 (279.365 ns/tick) the LOWEST rate it can express is 874 Hz — the music
needs 101 Hz, which is 8.6x past the ceiling. ★ TINS=0 (63.695 us/tick) reaches the whole
range, at a cost of -2.02% at the very top. Jay: "I can't rule on the 3% without hearing
it", so the slice is built single-mode on TINS=0 — the WORSE case — and he judges it.

  ticks = round(segment_period_us / 63.695),  clamped to 1..4095

---------------------------------------------------------------------------
THE AMPLITUDE
---------------------------------------------------------------------------
The Apple emits a narrow pulse whose WIDTH is the amplitude — 7.8..22.5 us inside segments
of 1,061..9,883 us, a duty cycle of 0.7-2.1%. The CoCo3 has a 6-bit DAC, so amplitude is a
value rather than a width; but the slice reproduces the PULSE, because the mandate is that
it SOUND right (CLAUDE.md 2I) and a narrow pulse train and a square wave of the same pitch
have audibly different timbre.

So each run carries a DAC level scaled from the measured pulse width. ★ The mapping is
LINEAR over the observed range and that is a choice, not a measurement — stated here so it
is not mistaken for one, and easy to change once Jay has heard it.
"""
import argparse
import pathlib
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

TICK_US = 63.695        # TINS=0
TMAX    = 4095
CPU_MHZ = 1.7897725     # 6809 at $FFD9 double speed
DLY_CYC = 5             # `deca / bne` in the FIRQ handler: 2 + 3 cycles


def read_pairs(path):
    out = []
    for line in pathlib.Path(path).read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        a, b = line.split()
        out.append((float(a), float(b)))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pairs", required=True)
    ap.add_argument("--out", required=True, help="the .s table")
    ap.add_argument("--label", default="song_data")
    ap.add_argument("--max-runs", type=int, default=2000)
    a = ap.parse_args()

    pairs = read_pairs(a.pairs)
    if not pairs:
        sys.exit("[pack_song] no pairs read")

    # amplitude scale, from the observed pulse-width range
    pmin = min(p for p, _ in pairs)
    pmax = max(p for p, _ in pairs)

    def width(pulse_us):
        """pulse width in us -> iterations of the handler's 5-cycle delay loop.

        ★★★ THE PULSE WIDTH IS THE AMPLITUDE, AND P4.5's FIRST CUT DROPPED IT. That version
        emitted a FIXED ~4 us pulse (a bare `sta`/`clr` pair) and scaled the DAC level
        instead — a 0.28% duty cycle against the oracle's measured 0.55-1.6%. Jay, hearing
        it: "i need more volume." It was 2-6x under, and it was also less faithful than the
        header claimed, because reproducing the pulse is the whole reason this renders a
        pulse train rather than a square wave.
        ★ So the width is carried per run, from the measurement, and the DAC sits at FULL
        SCALE — which is the Apple's own arrangement: one amplitude, duty does the work.
        """
        cyc = pulse_us * CPU_MHZ
        return max(1, min(255, int(round(cyc / DLY_CYC))))

    # quantise, then run-length encode on (ticks, level)
    quant = []
    over = 0
    for pulse, rest in pairs:
        seg = pulse + rest
        t = int(round(seg / TICK_US))
        if t > TMAX:
            over += 1
            t = TMAX
        t = max(1, t)
        quant.append((t, width(pulse)))

    runs = []
    for q in quant:
        if runs and runs[-1][0] == q[0] and runs[-1][1] == q[1] and runs[-1][2] < 255:
            runs[-1][2] += 1
        else:
            runs.append([q[0], q[1], 1])

    if len(runs) > a.max_runs:
        sys.exit(f"[pack_song] {len(runs)} runs exceeds --max-runs {a.max_runs}")

    total_us = sum(p + r for p, r in pairs)
    lines = [
        f"* {pathlib.Path(a.out).name} — GENERATED by harness/tools/pack_song.py. Do not hand-edit.",
        "*",
        "* ★★★ THIS IS A MEASUREMENT, NOT A TRANSCRIPTION. Every row was recorded off the",
        "* running oracle's speaker by harness/tools/oracle_speaker_intervals.lua — the port",
        "* replays what the Apple's speaker actually did, with no decode of MUSIC.SET* in",
        "* between (that file has never been decoded; open since P4.1).",
        "*",
        "* Row: fdb timer_ticks / fcb dac_level / fcb repeat_count",
        "*   timer_ticks  GIME 12-bit timer at TINS=0 (63.695 us/tick); the SEGMENT rate",
        "*   pulse_width  iterations of the handler's 5-cycle delay; the MEASURED pulse width",
        "*   repeat_count how many identical segments this row stands for (1..255)",
        "* A row of ticks=0 terminates.",
        "*",
        f"* source pairs   {len(pairs)}",
        f"* runs           {len(runs)}",
        f"* pulse width    {pmin:.2f} .. {pmax:.2f} us  -> {width(pmin)} .. {width(pmax)} delay iterations",
        f"* total duration {total_us/1000.0:.1f} ms",
        f"* over ceiling   {over} segment(s) clamped to {TMAX} ticks",
        "",
        f"{a.label}",
    ]
    for t, lv, n in runs:
        lines.append(f"                fdb     {t}")
        lines.append(f"                fcb     {lv},{n}")
    lines.append("                fdb     0               ; terminator")
    lines.append("")
    pathlib.Path(a.out).write_text("\n".join(lines), encoding="utf-8", newline="\n")

    print(f"[pack_song] {len(pairs)} segments -> {len(runs)} runs -> {a.out}")
    print(f"[pack_song]   {len(runs)*4 + 2} bytes; {total_us/1000.0:.1f} ms of music")
    print(f"[pack_song]   pulse {pmin:.2f}..{pmax:.2f} us -> {width(pmin)}..{width(pmax)} delay iters")
    if over:
        print(f"[pack_song]   ★ {over} segment(s) exceeded the 4095-tick ceiling and were clamped")
    return 0


if __name__ == "__main__":
    sys.exit(main())
