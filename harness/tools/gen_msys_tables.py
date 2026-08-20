"""gen_msys_tables.py — P4.19: emit the MSYS interpreter's resident data for the 6809.

★★★ WHAT THIS EMITS IS THE SPECIFICATION, NOT A TRANSCRIPTION. `msys_decode.py` holds the
decoded grammar and its tables; this turns the same tables into `lwasm` source so there is
exactly ONE home for each fact (CLAUDE.md §2F). Change a table in `msys_decode.py`, rebuild,
and the port and the validator cannot disagree.

★★ THE ONE TABLE THAT IS NOT A COPY IS THE TIMER TABLE. The oracle sets a note's pitch by
counting 6502 cycles in `MSEG`'s delay loops; the port sets it by loading the GIME timer.
So `msys_period` is COMPUTED from the counted loop:

    segment_us = (5*NOTE*(1+MLBL300) + 9*MLBL300 + 47 + fit) / 1.020484 MHz

and then quantised to the best available (TINS, divider, count) triple.

★★★ WHY A DIVIDER EXISTS AT ALL — AND IT IS THE ONE PLACE THIS PLAYER IS NOT THE ORACLE.
The GIME timer is 12 bits. At TINS=0 (63.695 us/tick) it reaches every period the music
needs but quantises the TOP of the range to +122 cents -- an audible 1.2 semitones. At
TINS=1 (279.365 ns/tick) it is 228x finer and cannot reach past 1.144 ms, which is most of
the music. Neither alone is good enough, and P4.6 already rejected a two-clock HYBRID for
the captured stream.

★ The divider resolves it: run TINS=1 and count N interrupts per segment, emitting the
pulse only on the first. That buys TINS=1's resolution at any period. N<=3 brings the worst
error over the twelve title songs from 32.7 cents to 10.0 -- BELOW the 12 cents Jay ruled
inaudible at P4.6 -- for 1.49 interrupts per segment instead of 1.

  maxdiv 1:  32.7 cents worst,  1.00 int/seg
  maxdiv 2:  19.4 cents worst,  1.42 int/seg
  maxdiv 3:  10.0 cents worst,  1.49 int/seg      <-- chosen
  maxdiv 4:   9.9 cents worst,  1.59 int/seg      (no gain)

★ AND THIS IS A §2I DIVERGENCE, DECLARED: the oracle has no divider and no timer. The output
is the same pitch to within a tenth of a semitone, and that is the whole justification --
measured, not argued.
"""
import argparse
import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import msys_decode as M                                            # noqa: E402

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

CPU_HZ = 1020484.0          # the Apple II 6502 the periods were counted against
COCO3_HZ = 1789772.5        # the CoCo3 at double speed ($FFD9), which the HAL sets
TINS0_US = 63.695           # GIME timer tick, TINS=0
TINS1_US = 0.279365         # GIME timer tick, TINS=1
TIMER_MAX = 4095
MAXDIV = 3

# PlaySongI's per-tick poll overhead, fitted to the clean s_Princess capture (§3).
PAD_US = 4855.0


def quantise(us, maxdiv=MAXDIV):
    """Best (tins, divider, count) for a segment of `us` microseconds."""
    best = None
    for div in range(1, maxdiv + 1):
        n = round(us / TINS1_US / div)
        if 1 <= n <= TIMER_MAX:
            c = 1200 * math.log2((n * TINS1_US * div) / us)
            if best is None or abs(c) < abs(best[3]):
                best = (1, div, n, c)
    n = round(us / TINS0_US)
    if 1 <= n <= TIMER_MAX:
        c = 1200 * math.log2((n * TINS0_US) / us)
        if best is None or abs(c) < abs(best[3]):
            best = (0, 1, n, c)
    if best is None:
        raise SystemExit("no timer setting reaches %.1f us" % us)
    return best


def segment_us(note, mult):
    return (5 * note * (1 + mult) + 9 * mult + 47 + M.SEG_FIT) / CPU_HZ * 1e6



# ★★★ EVERY PATTERN IS EMITTED. THIS SCAN REPORTS; IT DOES NOT TRIM — AND THAT IS A
# CORRECTION, MADE BECAUSE JAY DID NOT BELIEVE IT.
#
# P4.19 first shipped a TRIM: emit only the harmonic and envelope patterns the songs
# reference, drop the other 1,357 bytes. Jay: "so youre sure that no song or sound effect
# uses anything trimmed? I find it hard to believe that jordan would waste binary space on
# unneded code." He was right, and the trim was wrong in two ways at once:
#
#   1. THE SCAN WALKED ONLY IDS 0..12. The address table is $68 = 104 entries per half,
#      and MUSIC.SET2 has SEVENTEEN songs. Four were never looked at.
#   2. IT FOLLOWED CONTROL FLOW, and swallowed failures with `except: continue` -- so a
#      song that halted early contributed only the patterns seen before it stopped.
#
# A scan of every ALIGNED event slot inside each song's real extent -- no control flow, no
# early exit -- finds HM22, MV8 and MV10, all three of which the trim had DROPPED.
#
# ★★ AND THE JUSTIFICATION HAD ALREADY EVAPORATED. The trim existed to buy margin when the
# player was LOADM'd into a 4,608-byte window. It is now read off a disk track into
# $0A00..$1FFF -- 5,632 bytes against 4,456 untrimmed, 1,176 to spare. It was saving
# nothing and betting on a scan that was wrong.
#
# ★ What survives is the REPORT: which patterns the shipped sets actually reach, printed at
# build time, so the fact is available without anything depending on it.
def scan_sets(paths):
    """Every ALIGNED event slot in every song of every set. No control flow, no early
    exit -- the stream pointer steps by exactly two from a song's start, so every even
    offset is a real event slot whether or not execution gets there."""
    used_hm, used_mv = {0}, {0}          # MINIT points MBASS1 at HM1 and MVAR6 at MV0
    seen = []
    for path in paths:
        f = pathlib.Path(path)
        if not f.exists():
            continue
        page = M.load_page(f)
        lo, hi = page[0:0x68], page[0x68:0xD0]
        # ★ ALL 104 TABLE ENTRIES, not the 13 the first version assumed.
        addrs = sorted({hi[i] * 256 + lo[i] for i in range(0x68)
                        if 0xD000 <= hi[i] * 256 + lo[i] < 0xD400})
        for a, e in zip(addrs, addrs[1:] + [0xD400]):
            for off in range(a - 0xD000, e - 0xD000 - 1, 2):
                b0, b1 = page[off], page[off + 1]
                if b1 == 0:
                    if b0 >= 9:                      # SYMPH01 instrument select
                        x = b0 - 9
                        used_hm.add(x & 0x1F if x >= 32 else x)
                elif b1 & 0x3F:                      # a NOTE -> 4-bit envelope index
                    used_mv.add(((b1 & 0xC0) >> 4) | (b0 & 0x03))
        seen.append("%s(%d songs)" % (f.name, len(addrs)))
    return sorted(used_hm), sorted(used_mv), seen


# ---------------------------------------------------------------------------
# ★★★ ENV_OVERRIDE — THE ONE PLACE THE PORT'S MUSIC DATA IS NOT THE ORACLE'S.
#
# Jay, across P4.29-P4.43: the cutscene's music is "fuzzy", "dirty", and -- the observation
# that cracked it -- "the sound seems corect everywhere except the princess song, why only
# there". If ten of eleven songs are right, the PLAYER is right, and seven measurements of
# the player all came back clean because it is.
#
# WHY ONLY s_PRINCESS [P4.41]: it is the ONLY song in the game that uses envelope 5, and
# envelope 5 is the only one in use whose pattern ends on a HIGH value --
#
#     envelopes 0,1,3,4   ... 01 00 FF   -> "$FF = hold the last amplitude" holds SILENCE
#     envelope 5           01 0B 0D FF   -> holds $0D, 13 of a maximum 14
#
# so it sustains near maximum where every other song fades to nothing.
#
# MEASURED, both machines, same song [P4.42/P4.43]:
#     oracle   mean pulse width 15.7 us   (its own songs run 11.2 .. 23.6)
#     port     mean pulse width 21.3 us   with 89% of pulses at the maximum
# The port is 36% louder on this song and sits near the top of the oracle's whole range
# where the oracle's own s_Princess is mid-range.
#
# ★★ AND THE PORT IS NOT MISCOMPUTING ANYTHING. VS_AMP is 3, which is $0D >> 2, which is
# what voice command 01's LSR/LSR transform specifies; scale_widths clamps at 255 and never
# approaches it. The chain implements the oracle's spec exactly. What differs is how much
# TIME is spent at the held value, and that is not something a faithful port can fix by
# being more faithful.
#
# ★★★ SO THIS IS A §2I DIVERGENCE, TAKEN ON JAY'S RULING: "lets try the envelope change for
# 5." The mandate is that the port SOUNDS right, the oracle's data is evidence rather than a
# requirement, and §2.1 makes his ear the authority.
#
# WHAT THE CHANGE IS, AND WHY THIS SHAPE: the amplitude transform is an integer >> 2, so it
# quantises hard -- 12..15 -> 3, 8..11 -> 2. There is exactly ONE step available below the
# present value, and it is a 33% reduction, which is the size of the 36% excess measured.
# Dropping the sustain from $0D to $0B keeps the attack (silent -> 2) and lowers only what
# is HELD, which is the part that plays for the rest of every note.
#
#     oracle   01 0B 0D FF    ->  amp 0, 2, 3, hold 3
#     port     01 0B FF       ->  amp 0, 2,    hold 2
#
# ★ REVERSIBLE BY DELETING THREE LINES, and the emitted table says so at its head. If Jay's
# ear prefers the oracle's value, this dict goes away and nothing else changes.
# ★★★ TRIED AND REVERTED (P4.45). The softened sustain was MEASURABLY REAL and AUDIBLY
# NOTHING: it moved the port's mean pulse width on s_Princess from 21.3 us to 16.4 us --
# within 4% of the oracle's own 15.7 -- and Jay's verdict on the result was "doesnt sound
# any different". So amplitude is NOT what he is hearing as fuzzy, and that is worth more
# than the fix would have been: it is the one elimination in this arc made by the ear
# rather than by an instrument.
#
# ★★ AND A §2I DIVERGENCE HAS TO BUY SOMETHING. This one bought nothing, so the oracle's
# bytes go back. The mechanism stays here, empty, because the NEXT candidate will want it
# and because the measurement above should not have to be re-derived to know that this
# lever was pulled and did not move.
ENV_OVERRIDE = {}


def emit(path, songs_path, music, sets):
    used_hm, used_mv, seen = scan_sets(sets)
    out = []
    w = out.append
    w("* build/gen/msys_tables.s — GENERATED by harness/tools/gen_msys_tables.py.")
    w("* Do not edit; edit msys_decode.py's tables and rebuild (CLAUDE.md §2F).")
    w("* ★ NO `section` DIRECTIVE: this file is INCLUDED inside msys_player.s's section.")
    w("*   lwasm cannot nest sections, and a second one here would fail the object build")
    w("*   while the absolute build passed -- the exact split CLAUDE.md §2G warns about.")
    w("")

    # ---- the timer table: one 3-byte row per pitch index -------------------
    # byte 0: $00 or $20 -- the value for $FF91 (TINS)
    # byte 1: divider, 1..3 -- interrupts per segment
    # bytes 2-3: the 12-bit timer count, MSB first (the handler writes LSB then MSB)
    w("* msys_period — pitch index 0..74 -> (FF91, divider, timer count).")
    w("* ★ Row 0 is the PAUSE pitch and is never sounded; it is present so the index")
    w("*   arithmetic needs no bias.")
    worst = (0.0, None)
    w("msys_period")
    for i, note in enumerate(M.NOTE):
        # ★★★ INDEX 0 IS A REST AND TAKES MULT 1, NOT 7 — AND THIS ONE CHARACTER WAS THE
        # CHOPPINESS. `NEWNOTE` masks the pitch bits and BRANCHES PAST the multiplier when
        # they are zero:
        #     AND #%11111100 / STA R+13 / BEQ MNOBC1   <- MNOBC1 is AFTER `LDA #7`
        #     LSR / LSR / ... / CMP #$19 / BGE MNOBC1
        #     LDA #7 / STA MLBL300+1
        # so `pitch < $19` only reaches the multiplier when the pitch is NON-ZERO. Applying
        # the rule by index alone gave row 0 the x7 timing: 4.905 ms per silent segment
        # against the correct 1.258, and a rest is 28 of them.
        # ★★ MEASURED CONSEQUENCE: s_Presents' 23 rests ran 153.7 ms instead of 46.8, which
        # is 1.3% of the toggle pairs and 47% of the elapsed time. Jay: "very choppy."
        mult = 7 if 0 < i < 0x19 else 1
        us = segment_us(note, mult)
        tins, div, cnt, cents = quantise(us)
        if abs(cents) > worst[0]:
            worst = (abs(cents), (i, note, mult, tins, div, cnt, cents))
        w("                fcb     $%02X,%d" % (0x20 if tins else 0x00, div))
        w("                fdb     %d           ; idx %2d NOTE %3d x%d  %8.1f us  %+5.1f c"
          % (cnt, i, note, mult, us, cents))
    w("")
    w("MSYS_PERIOD_ROW equ     4")
    w("")

    # ---- the pad ------------------------------------------------------------
    tins, div, cnt, cents = quantise(PAD_US, maxdiv=1)
    w("* ★★ THE PER-TICK PAD IS THE ORACLE'S CALLER, MEASURED. `PlaySongI` loops")
    w("*    `jsr StartGame? / jsr xmplay` [MASTER.S:1389-1400] and the poll costs a")
    w("*    constant %.0f us between the last toggle of one tick and the first of the" % PAD_US)
    w("*    next. It is 13%% of every song's duration; without it every song runs short.")
    w("* ★★★ AND IT IS ALSO THE PORT'S DECODE BUDGET: the DAC is parked for the whole")
    w("*    window, so the envelope step and the note fetch run THERE and never inside")
    w("*    a sounding segment.")
    w("MSYS_PAD_FF91   equ     $%02X" % (0x20 if tins else 0x00))
    w("MSYS_PAD_TICKS  equ     %d              ; %.0f us, %+.1f cents" % (cnt, PAD_US, cents))
    w("")

    # ---- the pulse-width scale -------------------------------------------
    # ★★★ THE PORT RUNS AT DOUBLE SPEED, SO A WIDTH OF N IS NOT THE SAME PULSE.
    # Both players count the width in a 5-cycle delay loop, but the CoCo3 is at
    # 1.7898 MHz against the Apple's 1.0205 -- so an unscaled width comes out 1.754x
    # NARROW. Measured on the first target run: the oracle's 7.83 us minimum pulse
    # emitted as 5.59. The pulse width IS the amplitude (P4.5, Jay: "i need more
    # volume"), so this is a volume error, not a rounding one.
    ratio = COCO3_HZ / CPU_HZ
    num = int(round(ratio * 4))
    w("* ★★ msys_width_scale — %.4f as %d/4. The port's 1.7898 MHz against the" % (ratio, num))
    w("*    oracle's 1.0205: an unscaled width is 1.754x narrow, and the width is the")
    w("*    AMPLITUDE. Applied to each VTBL entry, not to the amplitude, because the")
    w("*    oracle's `+1` per entry is part of the width it counts.")
    w("* ★★★ AND IT MUST ROUND, NOT TRUNCATE. The smallest width in the music is 1, and")
    w("*    1*7>>2 is 1 -- the scale would be a no-op at exactly the amplitude P4.5's")
    w("*    ear-gate failure was about. +2 before the shift makes 1 -> 2, 2 -> 4, 3 -> 5.")
    w("MSYS_WIDTH_NUM  equ     %d" % num)
    w("MSYS_WIDTH_ROUND equ    2")
    w("MSYS_WIDTH_SHIFT equ    2")
    w("")

    # ---- LENGTH -------------------------------------------------------------
    w("* msys_length — segments per MPLAY tick, by pitch index [MSYS.S:37-42].")
    w("msys_length")
    for i in range(0, len(M.LENGTH), 12):
        w("                fcb     " + ",".join(str(x) for x in M.LENGTH[i:i + 12]))
    w("")

    # ---- AMPTBL / HTPTBL ----------------------------------------------------
    w("* msys_amptbl — the 16 instrument amplitudes [MSYS.S:249].")
    w("msys_amptbl     fcb     " + ",".join(str(x) for x in M.AMPTBL))
    w("")
    w("* msys_htptbl — per-instrument transpose [MSYS.S:247-248].")
    w("msys_htptbl")
    for i in range(0, 32, 16):
        w("                fcb     " + ",".join(str(x) for x in M.HTPTBL[i:i + 16]))
    w("")

    # ---- the voice transform ------------------------------------------------
    # ★ MVOLTBL/MVT2 are 6502 OPCODES patched into MPLAY.  They do not port; what
    #   ports is the FUNCTION each pair computes, as a selector the handler switches on.
    w("* ★★ msys_voice — MVOLTBL/MVT2 [MSYS.S:244-245] ARE 6502 OPCODES, patched into")
    w("*    two one-byte slots in MPLAY's amplitude path. They do not port. What ports is")
    w("*    the FUNCTION each pair computes, as a selector:")
    w("*      0 = a>>2   1 = a>>1   2 = a      3 = a<<1   4 = a<<2")
    w("*      5 = a^$0F  6 = a+$07  7 = leave the amplitude ALONE (the BNE skips the store)")
    sel = []
    for i in range(8):
        op1, op2 = M.MVOLTBL[i], M.MVT2[i]
        table = {(0x4A, 0x4A): 0, (0x4A, 0xEA): 1, (0xEA, 0xEA): 2,
                 (0x0A, 0xEA): 3, (0x0A, 0x0A): 4, (0x49, 0x0F): 5,
                 (0x69, 0x07): 6, (0xD0, 0x04): 7}
        if (op1, op2) not in table:
            raise SystemExit("unmodelled voice pair %02X %02X" % (op1, op2))
        sel.append(table[(op1, op2)])
    w("msys_voice      fcb     " + ",".join(str(x) for x in sel))
    w("")

    # ---- MV (envelope) patterns --------------------------------------------
    w("* ★★★ ONE ENVELOPE IS DELIBERATELY NOT THE ORACLE'S — see ENV_OVERRIDE in")
    w("* gen_msys_tables.py for the measurement and the ruling. Every other pattern is")
    w("* MUSIC.SET1's own bytes.")
    w("* msys_env — the 16 envelope patterns [MSYS.S:43-59]. $7F = sustain until the")
    w("* note is nearly over; bit 7 = end, hold the last amplitude.")
    w("* ★ ALL SIXTEEN. The shipped sets reach %d of them (%s); the rest are emitted"
      % (len(used_mv), ",".join(str(i) for i in used_mv)))
    w("*   anyway — see scan_sets for why a trim was tried and withdrawn.")
    for i in range(len(M.MV)):
        pat = ENV_OVERRIDE.get(i, M.MV[i])
        if i in ENV_OVERRIDE:
            w("* ★★★ ENVELOPE %d IS OVERRIDDEN — see ENV_OVERRIDE. Oracle: %s"
              % (i, ",".join("$%02X" % b for b in M.MV[i])))
        w("msys_mv%-8d fcb     %s" % (i, ",".join("$%02X" % b for b in pat)))
    w("msys_envtbl")
    for i in range(len(M.MV)):
        w("                fdb     msys_mv%d" % i)
    w("")

    # ---- HM (harmonic) patterns --------------------------------------------
    w("* msys_harm — the 32 harmonic patterns [MSYS.S:60-134].")
    w("* ★★ A VALUE OF 1 IS SILENCE, NOT THE QUIETEST LEVEL. It selects VTBL+0, which")
    w("*    NEWMM4 never rewrites and which is therefore always zero -- so that segment")
    w("*    emits no pulse at all. The default pattern is `1,3,128`: silent, sound,")
    w("*    repeat, which is why the oracle's speaker toggles once every TWO segments.")
    w("* Bit 7 set = jump back to (value & $7F) and continue -- the pattern LOOPS.")
    w("* ★ ALL THIRTY-TWO. The shipped sets reach %d of them (HM%s); the rest are"
      % (len(used_hm), ", HM".join(str(i + 1) for i in used_hm)))
    w("*   emitted anyway — see scan_sets for why a trim was tried and withdrawn.")
    for i in range(len(M.HM)):
        w("msys_hm%-9d fcb     %s" % (i, ",".join("$%02X" % b for b in M.HM[i])))
    w("msys_harmtbl")
    for i in range(len(M.HM)):
        w("                fdb     msys_hm%d" % i)
    pathlib.Path(path).write_text("\n".join(out) + "\n", encoding="utf-8")

    # ---- the song page ------------------------------------------------------
    page = M.load_page(music)
    s = ["* build/gen/msys_songs.s — GENERATED. The oracle's $D000 music page, verbatim.",
         "*",
         "* ★★ SHIPPED WHOLE AND UNREPACKED. 1,024 bytes carries the 13-entry address",
         "*    table AND all thirteen songs; repacking would buy 46 bytes and create a",
         "*    second home for the offsets (CLAUDE.md §2F). MADRLO is +$00, MADRHI +$68,",
         "*    the songs run $D0FE..$D3FF.",
         "* ★ Source: oracle/source/Other/MUSIC.SET1, an 18-sector RW18 track image;",
         "*   the music is offset 512..1535 (P4.16 §3A).",
         "* ★ NO `section` DIRECTIVE -- included inside msys_player.s's section.",
         "",
         "MSYS_SONG_BASE  equ     $D000       ; the address the table's pointers are in",
         "msys_song_page"]
    for i in range(0, len(page), 16):
        s.append("                fcb     " +
                 ",".join("$%02X" % b for b in page[i:i + 16]))
    pathlib.Path(songs_path).write_text("\n".join(s) + "\n", encoding="utf-8")

    c, (i, note, mult, tins, div, cnt, cents) = worst
    ptins, _, pcnt, _ = quantise(PAD_US, maxdiv=1)
    print("gen_msys_tables: %s + %s" % (path, songs_path))
    print("  timer table 75 rows, worst quantisation %+.1f cents "
          "(idx %d, NOTE %d x%d -> TINS%d div%d %d)"
          % (cents, i, note, mult, tins, div, cnt))
    print("  pad %.0f us -> TINS%d %d ticks" % (PAD_US, ptins, pcnt))
    hm = sum(len(h) for h in M.HM)
    mv = sum(len(v) for v in M.MV)
    print("  scanned %s" % ", ".join(seen))
    print("    reachable: harmonic %d of 32 %s" % (len(used_hm),
                                                   sorted(i + 1 for i in used_hm)))
    print("               envelope %d of 16 %s" % (len(used_mv), used_mv))
    print("    ALL are emitted; the scan reports, it does not trim.")
    print("  data: page 1024  harm %d+64  env %d+32  period 300  length 75  "
          "amp 16  htp 32  voice 8" % (hm, mv))
    print("  TOTAL %d B" % (1024 + hm + 64 + mv + 32 + 300 + 75 + 16 + 32 + 8))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="build/gen/msys_tables.s")
    ap.add_argument("--songs-out", default="build/gen/msys_songs.s")
    ap.add_argument("--music", default="oracle/source/Other/MUSIC.SET1")
    ap.add_argument("--scan", action="append", default=None,
                    help="song sets to scan for reachable patterns; repeatable. "
                         "Defaults to every MUSIC.SET* beside --music.")
    args = ap.parse_args()
    sets = args.scan
    if not sets:
        d = pathlib.Path(args.music).parent
        sets = sorted(str(f) for f in d.glob("MUSIC.SET*"))
    pathlib.Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    emit(args.out, args.songs_out, args.music, sets)


if __name__ == "__main__":
    main()
