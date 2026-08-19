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



# ★★★ WHICH PATTERNS ARE ACTUALLY REACHABLE, MEASURED ACROSS EVERY SHIPPED SONG SET.
# The oracle carries 32 harmonic patterns and 16 envelopes; the 39 songs in MUSIC.SET1/2/3
# reference 5 and 6 of them. The other 1,357 bytes are dead weight, and they matter because
# the player's home is $0E00..$1FFF -- 4,608 bytes against 4,456 untrimmed. A 152-byte
# margin on a boundary lwlink overruns SILENTLY (build.bat: "lwlink places overlapping
# sections silently, and did so three times in P3.2") is not a margin.
#
# ★★ THE UNION IS COMPUTED, NOT LISTED. A hand-maintained list of "the patterns we use"
# would be a second home for a fact the song data already contains (CLAUDE.md §2F), and it
# would go stale the first time a set changed -- which is exactly how the link script's
# region map came to be wrong about four addresses.
#
# ★ AND THE DROPPED SLOTS STILL RESOLVE. The pointer tables stay full length, every
# unreferenced entry aimed at a silent stub, so a stream that reaches one plays NOTHING
# rather than reading past the table and calling it a pattern.
def scan_sets(paths):
    used_hm, used_mv = {0}, {0}          # MINIT points MBASS1 at HM1 and MVAR6 at MV0
    seen = []
    for path in paths:
        f = pathlib.Path(path)
        if not f.exists():
            continue
        page = M.load_page(f)
        lo, hi = page[0:0x68], page[0x68:0xD0]
        for sid in range(13):
            addr = hi[sid] * 256 + lo[sid]
            if not (0xD000 <= addr < 0xD400):
                continue
            pl = M.Player(page, 0xD000, sid)
            pl.pad_us = PAD_US
            try:
                pl.run(sid)
            except Exception:
                continue
            for v in (pl.voice1, pl.voice2):
                if v is None:
                    continue
                for kind, off, b0, b1, det in v.trace:
                    if kind == "instr":
                        used_hm.add(int(det.split("HM")[1].split(",")[0]) - 1)
                    elif kind == "note":
                        used_mv.add(int(det.split("instr")[1].split()[0]))
        seen.append(f.name)
    if not seen:
        raise SystemExit("[gen_msys_tables] no song set scanned — refusing to trim blind")
    return sorted(used_hm), sorted(used_mv), seen


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
        mult = 7 if i < 0x19 else 1
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
    w("* msys_env — the 16 envelope patterns [MSYS.S:43-59]. $7F = sustain until the")
    w("* note is nearly over; bit 7 = end, hold the last amplitude.")
    w("* ★ ONLY THE %d OF 16 THAT ANY SHIPPED SONG REFERENCES (%s) — see scan_sets."
      % (len(used_mv), ",".join(str(i) for i in used_mv)))
    for i in used_mv:
        w("msys_mv%-8d fcb     %s" % (i, ",".join("$%02X" % b for b in M.MV[i])))
    w("msys_mv_none    fcb     $FF         ; end-of-envelope = hold; never heard")
    w("msys_envtbl")
    for i in range(len(M.MV)):
        w("                fdb     %s" % ("msys_mv%d" % i if i in used_mv
                                          else "msys_mv_none"))
    w("")

    # ---- HM (harmonic) patterns --------------------------------------------
    w("* msys_harm — the 32 harmonic patterns [MSYS.S:60-134].")
    w("* ★★ A VALUE OF 1 IS SILENCE, NOT THE QUIETEST LEVEL. It selects VTBL+0, which")
    w("*    NEWMM4 never rewrites and which is therefore always zero -- so that segment")
    w("*    emits no pulse at all. The default pattern is `1,3,128`: silent, sound,")
    w("*    repeat, which is why the oracle's speaker toggles once every TWO segments.")
    w("* Bit 7 set = jump back to (value & $7F) and continue -- the pattern LOOPS.")
    w("* ★ ONLY THE %d OF 32 THAT ANY SHIPPED SONG REFERENCES (HM%s) — see scan_sets."
      % (len(used_hm), ", HM".join(str(i + 1) for i in used_hm)))
    for i in used_hm:
        w("msys_hm%-9d fcb     %s" % (i, ",".join("$%02X" % b for b in M.HM[i])))
    w("* ★★ THE STUB IS SILENT, NOT ABSENT. Value 1 selects VTBL+0, which is always zero,")
    w("*    and $80 loops back to index 0 — so a stream reaching a dropped instrument")
    w("*    plays NOTHING instead of reading past the table and calling it a pattern.")
    w("msys_hm_none    fcb     1,$80")
    w("msys_harmtbl")
    for i in range(len(M.HM)):
        w("                fdb     %s" % ("msys_hm%d" % i if i in used_hm
                                          else "msys_hm_none"))
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
    hm = sum(len(M.HM[i]) for i in used_hm) + 2
    mv = sum(len(M.MV[i]) for i in used_mv) + 1
    hm_all = sum(len(h) for h in M.HM)
    mv_all = sum(len(v) for v in M.MV)
    print("  scanned %s -> harmonic %d of 32, envelope %d of 16"
          % (", ".join(seen), len(used_hm), len(used_mv)))
    print("  data: page 1024  harm %d+64  env %d+32  period 300  length 75  "
          "amp 16  htp 32  voice 8" % (hm, mv))
    total = 1024 + hm + 64 + mv + 32 + 300 + 75 + 16 + 32 + 8
    print("  TOTAL %d B   (untrimmed would be %d; %d B dropped as unreachable)"
          % (total, 1024 + hm_all + 64 + mv_all + 32 + 300 + 75 + 16 + 32 + 8,
             (hm_all - hm) + (mv_all - mv)))


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
