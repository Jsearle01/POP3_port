#!/bin/bash
# harness/smoke/run_interp_3way.sh — P4.19: the ORACLE COMPARE. Three clips, one song.
#
# ★★★ WHY THIS EXISTS AND run_interp_ab.sh DOES NOT REPLACE IT. The A/B compares the port
# against the PORT — interpret against a replayed recording. Both are a CoCo3 DAC driven by
# a GIME timer. It isolates the DECODE, which is the right question for "did I read the
# format correctly", and it is the WRONG question for "does it sound like Prince of Persia."
#
# ★★ THE ORACLE IS A DIFFERENT MACHINE and cannot share a MAME session — a 6502 driving a
# one-bit speaker against a 6809 driving a 6-bit DAC. So the oracle comparison has to be
# recorded, and this records all three the same way, cut to the same window:
#
#   1_oracle.wav     Apple IIe, s_Princess inside its own boot
#   2_interpret.wav  CoCo3, msys_player.s walking MUSIC.SET1's bytes
#   3_capture.wav    CoCo3, the oracle's per-song recording replayed
#
# ★ EXACT WINDOWS, NOT DISCOVERED ONES (harness/tools/wav_window.py). s_Princess is CALLED
# at t=44.867 s after the oracle's boot [oracle_song_capture.lua's own header] and runs
# 12.724 s. Cutting each clip by "where the noise starts" would let a timing difference
# hide as a trimming difference.
#
# ★★ THE LEVELS ARE NOT NORMALISED AND SHOULD NOT BE COMPARED ACROSS MACHINES. The Apple
# idles at 6144 and the CoCo3 at 8192, and the speaker and the DAC have nothing in common
# electrically. PITCH, TEMPO and TIMBRE are the comparable things.
#
# Oracle source is READ-ONLY: MAME writes to a copy (CLAUDE.md §2).
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
IMGTOOL="${IMGTOOL:-/c/mame/imgtool.exe}"
HDV="oracle/source/PrinceOfPersia_3.5.hdv"
# ★ its OWN image, not run_interp_ab.dmk: the live A/B window may still have that one
#   mounted, and MAME holds it open — the first run of this script died on
#   "Device or resource busy" while Jay was listening.
DSK="build/run_interp_3way.dmk"
MAP="build/obj/interp.map"
BIN="build/interp_probe.bin"
OUTDIR="build/tmp/3way"

# s_Princess in the ORACLE's boot, and how long it runs. Both measured, not guessed.
ORACLE_AT="${P_ORACLE_AT:-44.867}"
DUR="${P_DUR:-12.724}"

[ -f "$HDV" ] || { echo "[3way] missing $HDV"; exit 1; }
[ -f "$BIN" ] || { echo "[3way] missing $BIN — run build.bat"; exit 1; }
mkdir -p "$OUTDIR"

. "$(dirname "$0")/ramsize.sh"
sym() { grep -E "^Symbol: $2 " "$1" | sed -E 's/.*= *//'; }
export P_ENTRY="$(sym "$MAP" probe_entry)"
export P_SONG="${P_SONG:-7}"
unset P_OUT P_REPORT 2>/dev/null || true

# ---------------------------------------------------------------- 1. the oracle
SCRATCH="build/oracle_3way.hdv"
cp -f "$HDV" "$SCRATCH" || exit 1
RAW="$OUTDIR/raw_oracle.wav"
rm -f "$RAW"
echo "[3way] oracle: apple2e + cffa202, 62 emulated seconds..."
"$MAME" apple2e \
    -rompath "$MAME_ROMS" \
    -sl7 cffa202 \
    -hard1 "$(pwd -W)/$SCRATCH" \
    -nothrottle -video none \
    -seconds_to_run 62 \
    -wavwrite "$RAW" >/dev/null 2>&1
python harness/tools/wav_window.py --wav "$RAW" --out "$OUTDIR/1_oracle.wav" \
    --start "$ORACLE_AT" --dur "$DUR" --label "ORACLE (Apple IIe)"

# ---------------------------------------------------------------- 2 & 3. the port
# ★ The probe is EXEC'd at frame 1200 (20 s) and the disk read then takes about a second,
#   so both port passes start sounding at ~21 s. That is the SAME launch for both, which is
#   what lets one offset serve them.
rm -f "$DSK"
"$IMGTOOL" create coco_dmk_rsdos "$DSK" >/dev/null 2>&1 || exit 1
"$IMGTOOL" put coco_dmk_rsdos "$DSK" "$BIN" INTERP.BIN \
    --ftype=binary --ascii=binary >/dev/null 2>&1 || exit 1

port_pass() {
    local mode="$1" name="$2" label="$3"
    local raw="$OUTDIR/raw_$name.wav"
    rm -f "$raw"
    echo "[3way] port ($label): coco3 $RAMOPT, 40 emulated seconds..."
    P_MODE="$mode" "$MAME" coco3 \
        -rompath "$MAME_ROMS" \
        $RAMOPT \
        -cfg_directory dist/mame-cfg/rgb \
        -ext fdc -flop1 "$DSK" \
        -video none -nothrottle \
        -seconds_to_run 40 \
        -wavwrite "$raw" \
        -autoboot_script harness/smoke/interp_live.lua >/dev/null 2>&1
    python harness/tools/wav_window.py --wav "$raw" --out "$OUTDIR/$name.wav" \
        --start "${P_PORT_AT:-21.0}" --dur "$DUR" --label "$label"
}

port_pass 0 2_interpret "PORT interpret"
port_pass 2 3_capture   "PORT capture"

cat <<BANNER

[3way] ---------------------------------------------------------------
[3way] Three clips, ${DUR}s each, same song (s_Princess), in $OUTDIR:
[3way]
[3way]   1_oracle.wav      the Apple IIe. The thing being ported.
[3way]   2_interpret.wav   the CoCo3 walking MUSIC.SET1's own 1,024 bytes.
[3way]   3_capture.wav     the CoCo3 replaying the oracle's recording.
[3way]
[3way] 1 vs 2 is the real question: does the decode sound like Prince of Persia.
[3way] 2 vs 3 is the narrower one: did I read the format correctly.
[3way] 1 vs 3 is the control -- it is the path you already approved at P4.5/P4.6,
[3way]        so if THAT one sounds wrong the fault is in the DAC path, not the decode.
[3way]
[3way] LEVELS ARE NOT COMPARABLE ACROSS MACHINES (a one-bit speaker against a 6-bit
[3way] DAC). Pitch, tempo and timbre are.
[3way] ---------------------------------------------------------------
BANNER
