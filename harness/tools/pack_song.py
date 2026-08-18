"""pack_song.py — P4.5/P4.6: turn the MEASURED speaker stream into a table the 6809 can walk.

★★★ THE SLICE IS DRIVEN BY MEASUREMENT, NOT BY A DECODE. `MUSIC.SET*` has never been
decoded (open since P4.1) and does not need to be for a vertical slice: what the port has
to reproduce is what the SPEAKER DID, and `oracle_speaker_intervals.lua` recorded exactly
that — one (pulse, rest) pair per segment, off the running machine.

★★ RUN-LENGTH ENCODED, because the raw stream is enormously repetitive: a held note is the
same pair over and over. 3,924 segments compress to a few hundred runs, which is the
difference between a table that fits in the port and one that does not.

---------------------------------------------------------------------------
THE PITCH, AND WHY THERE IS A FRACTION
---------------------------------------------------------------------------
P4.4 measured the rates the music actually uses: 101 Hz .. 943 Hz. The GIME timer is 12
bits, so at TINS=1 (279.365 ns/tick) the LOWEST rate it can express is 874 Hz.

★★★ AND P4.6 CLOSES THE HYBRID OFF. 74.8% of this song sits at 600-800 Hz — periods of
1.25..1.67 ms, against TINS=1's 1.144 ms ceiling. THE SECOND CLOCK CANNOT REACH THE BAND
IT WOULD BE BUILT FOR. So the remaining lever on the detune is not another clock, it is
better quantisation of the one clock:

    exact  = (segment_period_us - LATENCY_US) / 63.695
    ticks  = floor(exact)          the row's base value
    frac   = round(256*(exact-ticks))   how often the player uses ticks+1 instead

A Bresenham accumulator in the FIRQ handler alternates the two, so the MEAN period is
right where no single tick value can be closer than half a tick. `--dither` turns it on;
without it every row carries frac=0 and `ticks = round(exact)`, which is exactly the
as-built quantisation. ★ Two tables, one code path, one variable — the A/B Jay asked for.

★★★ AND THE PERIOD IS NOT ticks*63.695 — IT IS ticks*63.695 PLUS A LATENCY, TWICE OVER.
Measured off the port's own $FF20 writes (song_live.lua P_PULSE), the offset splits into
two clean populations by MECHANISM, not by pitch:

    steady        +170.2 us   FIRQ entry + the handler's prologue, before the timer write
    run-advance   +225.2 us   the same, plus the whole of load_run walking the table

★★ ~127 us of the steady figure is not code at all: SockmasterGime.md records that the
GIME runs nnn+2 ticks (1986 part) or nnn+1 (1987), so two ticks of it are the chip and no
amount of tightening the handler removes them. Ignoring the whole offset is what left
P4.5's slice playing 7.2% LONG — about 1.2 semitones flat, an error twenty times the
quantisation the A/B was built to test. A gate on that would have measured the defect.

---------------------------------------------------------------------------
THE AMPLITUDE IS A PULSE WIDTH, AND THE HANDLER'S OWN OVERHEAD IS PART OF IT
---------------------------------------------------------------------------
The Apple emits a narrow pulse whose WIDTH is the amplitude — 7.8..22.5 us inside segments
of 1,061..9,883 us. The CoCo3 has a 6-bit DAC, so amplitude COULD be a level; the slice
renders it as a width anyway, because the mandate is that it SOUND right (CLAUDE.md §2I)
and a narrow pulse train and a square wave of the same pitch have audibly different timbre.

★★★ AND THE MAPPING MUST ACCOUNT FOR THE INSTRUCTIONS AROUND THE DELAY LOOP. The emitted
pulse is not 5*n cycles: it is the loop PLUS whatever closes it. P4.5 ignored that constant
and every pulse came out ~6.6 us wide — the same family of error as the fixed 4 us pulse it
replaced, in the other direction. Measured at 12 cycles, the handler was then rewritten to
count in B so the close is `stb DAC` with the width load hoisted above the open, which
brought it to 5 — and that matters at the quiet end, where 12 cycles put a floor of 9.5 us
under a 7.8 us target. The constant is --pulse-overhead-cyc and it is MEASURED.

    n = round((pulse_us * 1.7897725 - OVERHEAD_CYC) / 5),  clamped to 1..255

★★ THE FOUR WIDTHS IN THIS CAPTURE ARE THE ENVELOPE. The 6.5 s window contains exactly
four distinct pulse widths and none of them varies inside a held note — so whichever of
MSYS's HM1..HM29 amplitude patterns were running, they are already IN this data. There is
nothing further to reproduce and nothing to decode.
"""
import argparse
import collections
import pathlib
import statistics
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
    ap.add_argument("--dither", action="store_true",
                    help="carry the fractional tick; without it every row is frac=0")
    ap.add_argument("--latency-us", type=float, default=0.0,
                    help="the handler's timer-restart latency on a STEADY interrupt")
    ap.add_argument("--latency-adv-us", type=float, default=None,
                    help="ditto on the interrupt that ends a run and walks the table; "
                         "defaults to --latency-us")
    ap.add_argument("--pulse-overhead-cyc", type=float, default=0.0,
                    help="cycles in the emitted pulse outside the delay loop")
    a = ap.parse_args()

    pairs = read_pairs(a.pairs)
    if not pairs:
        sys.exit("[pack_song] no pairs read")

    pmin = min(p for p, _ in pairs)
    pmax = max(p for p, _ in pairs)

    def width(pulse_us):
        cyc = pulse_us * CPU_MHZ - a.pulse_overhead_cyc
        return max(1, min(255, int(round(cyc / DLY_CYC))))

    def emitted_us(n):
        return (a.pulse_overhead_cyc + DLY_CYC * n) / CPU_MHZ

    lat_adv = a.latency_us if a.latency_adv_us is None else a.latency_adv_us

    # ---- quantise -------------------------------------------------------------
    # ★★★ TWO PASSES, BECAUSE THE LATENCY DEPENDS ON THE RUN LENGTH AND THE RUN LENGTH
    # DEPENDS ON THE QUANTISATION. The interrupt that ends a run also walks the table
    # before it restarts the timer, so ONE segment in each run is longer by the whole of
    # load_run — 55 us, measured. Pass 1 quantises with the steady latency only, to find
    # the runs; pass 2 re-quantises each run against ITS OWN count-weighted latency.
    def quantise(lat):

        out = []
        for pulse, rest in pairs:
            exact = (pulse + rest - lat) / TICK_US
            if a.dither:
                t = int(exact)
                f = int(round(256.0 * (exact - t)))
                if f >= 256:
                    t, f = t + 1, 0
            else:
                t, f = int(round(exact)), 0
            out.append([t, f, width(pulse)])
        return out

    def rle(q):
        runs = []
        for x in q:
            if runs and runs[-1][:3] == x and runs[-1][3] < 255:
                runs[-1][3] += 1
            else:
                runs.append([x[0], x[1], x[2], 1])
        return runs

    counts = []
    for r in rle(quantise(a.latency_us)):
        counts.extend([r[3]] * r[3])

    quant, over, err = [], 0, []
    for i, (pulse, rest) in enumerate(pairs):
        n = counts[i] if i < len(counts) else 1
        lat = (lat_adv + (n - 1) * a.latency_us) / n
        exact = (pulse + rest - lat) / TICK_US
        if a.dither:
            t = int(exact)
            f = int(round(256.0 * (exact - t)))
            if f >= 256:
                t, f = t + 1, 0
        else:
            t, f = int(round(exact)), 0
        if t > TMAX - 1:
            over += 1
            t, f = TMAX - 1, 0
        if t < 1:
            t, f = 1, 0
        got = (t + f / 256.0) * TICK_US + lat
        err.append(100.0 * (got - (pulse + rest)) / (pulse + rest))
        quant.append([t, f, width(pulse)])

    runs = rle(quant)

    if len(runs) > a.max_runs:
        sys.exit(f"[pack_song] {len(runs)} runs exceeds --max-runs {a.max_runs}")

    total_us = sum(p + r for p, r in pairs)
    abserr = statistics.mean(abs(e) for e in err)
    signerr = statistics.mean(err)
    maxerr = max(abs(e) for e in err)
    wmap = sorted(collections.Counter(w for _, _, w in quant).items())

    lines = [
        f"* {pathlib.Path(a.out).name} — GENERATED by harness/tools/pack_song.py. Do not hand-edit.",
        "*",
        "* ★★★ THIS IS A MEASUREMENT, NOT A TRANSCRIPTION. Every row was recorded off the",
        "* running oracle's speaker by harness/tools/oracle_speaker_intervals.lua — the port",
        "* replays what the Apple's speaker actually did, with no decode of MUSIC.SET* in",
        "* between (that file has never been decoded; open since P4.1).",
        "*",
        "* Row: fdb ticks / fcb frac / fcb width / fcb count",
        "*   ticks   GIME 12-bit timer at TINS=0 (63.695 us/tick); the SEGMENT rate",
        "*   frac    DITHER NUMERATOR, in 256ths of a tick — NOT a DAC level. This many",
        "*           segments in 256 take ticks+1, so the MEAN period comes out right.",
        "*   width   iterations of the handler's 5-cycle delay loop; the pulse, i.e. the",
        "*           AMPLITUDE. The emitted pulse is overhead + 5*width cycles.",
        "*   count   how many identical segments this row stands for (1..255)",
        "* A row of ticks=0 terminates.",
        "*",
        "* ★★ WHAT THIS FILE ACTUALLY ACHIEVES — stated because P4.5's header claimed a",
        "* fidelity the data did not have (it said the width was a 'dac_level', and the",
        "* mapping ignored the handler's own overhead so every pulse ran ~6.6 us wide).",
        "*",
        f"* dither         {'ON — frac carried' if a.dither else 'OFF — every row frac=0, ticks=round(exact)'}",
        f"* latency        steady {a.latency_us:.2f} us / run-advance {lat_adv:.2f} us,",
        "*                 weighted per row by the run length and subtracted before",
        "*                 quantising. ~127 us of it is the GIME running nnn+2, not code.",
        f"* pulse overhead {a.pulse_overhead_cyc:.1f} cycles outside the delay loop",
        f"* period error   mean |err| {abserr:.3f}%   signed mean {signerr:+.3f}%   worst {maxerr:.3f}%",
        f"* pulse widths   {pmin:.2f} .. {pmax:.2f} us measured ->",
    ]
    for n, cnt in wmap:
        lines.append(f"*                 {n} iters = {emitted_us(n):5.2f} us emitted  ({cnt} segments)")
    lines += [
        f"* source pairs   {len(pairs)}",
        f"* runs           {len(runs)}  ({len(runs)*5 + 2} bytes)",
        f"* total duration {total_us/1000.0:.1f} ms",
        f"* over ceiling   {over} segment(s) clamped to {TMAX-1} ticks",
        "",
        f"{a.label}",
    ]
    for t, f, w, n in runs:
        lines.append(f"                fdb     {t}")
        lines.append(f"                fcb     {f},{w},{n}")
    lines.append("                fdb     0               ; terminator")
    lines.append("")
    pathlib.Path(a.out).write_text("\n".join(lines), encoding="utf-8", newline="\n")

    print(f"[pack_song] {a.label}: {len(pairs)} segments -> {len(runs)} runs "
          f"({len(runs)*5 + 2} B) -> {a.out}")
    print(f"[pack_song]   dither {'on' if a.dither else 'off'}; latency {a.latency_us:.2f} us; "
          f"pulse overhead {a.pulse_overhead_cyc:.1f} cyc")
    print(f"[pack_song]   period error mean |{abserr:.3f}%| signed {signerr:+.3f}% worst {maxerr:.3f}%; "
          f"{total_us/1000.0:.1f} ms")
    print(f"[pack_song]   widths -> " +
          ", ".join(f"{n}={emitted_us(n):.1f}us" for n, _ in wmap))
    if over:
        print(f"[pack_song]   ★ {over} segment(s) exceeded the tick ceiling and were clamped")
    return 0


if __name__ == "__main__":
    sys.exit(main())
