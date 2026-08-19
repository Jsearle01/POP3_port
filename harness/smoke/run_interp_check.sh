#!/bin/bash
# harness/smoke/run_interp_check.sh — P4.19: the INTERPRETED player, headless, on 128 KB.
#
# ★★★ WHAT THIS CHECKS THAT A LIVENESS RUN CANNOT. The player walks a grammar: pitch,
# a six-bit duration, a 4-bit instrument split across two bytes, an envelope, a harmonic
# pattern, a one-deep call and a second voice. Almost every way of getting one of those
# wrong still loads, sounds and tears down. So this DUMPS THE EMITTED (pulse, rest) PAIRS
# and diffs them against the decoded model — and the model is itself already diffed
# against the oracle's own capture (msys_decode.py). Three artifacts, one comparator.
#
# ★★ 128 KB FIRST (CLAUDE.md §2K). The player is 4,417 bytes of `section code` and touches
# no MMU, but 128 KB is the target and it is the strictly harder case.
#
# ★ Launch path: live-disk (CLAUDE.md §4) — real LOADM+EXEC off a mounted floppy.
#
#   P_MODE=0   one INTERPRET pass, then stop            (the default; the measured path)
#   P_MODE=2   one CAPTURE pass, then stop              (the A/B's other half, measured)
#   P_SONG=n   which song to interpret. Default 7 (s_Princess) — the ONLY song whose
#              oracle capture is uncontaminated, and therefore the only clean comparison.
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
IMGTOOL="${IMGTOOL:-/c/mame/imgtool.exe}"
SRC_DSK="build/probe.dmk"
DSK="build/run_interp.dmk"
MAP="build/obj/interp.map"
BIN="build/interp_probe.bin"

[ -f "$MAP" ] || { echo "[interp_check] missing $MAP — run build.bat"; exit 1; }
[ -f "$BIN" ] || { echo "[interp_check] missing $BIN — run build.bat"; exit 1; }
mkdir -p build/tmp

# ★★★ A FRESH DISK, NOT A COPY OF probe.dmk -- and for two reasons, one of which is a
# hazard and one of which is arithmetic. The hazard: P4.2 put its instrument on
# build/probe.dmk and DECB allocated the granules over a RESERVED cel-page track, so a
# suite with nothing to do with audio reported "0 of 19 beats". The arithmetic: probe.dmk
# has 13,824 bytes free and this binary is 16,332 -- it does not fit, and a copy would
# fail every time. The interpreter reads no cel data, so it needs none of that image.
rm -f "$DSK"
"$IMGTOOL" create coco_dmk_rsdos "$DSK" >/dev/null 2>&1     || { echo "[interp_check] could not create $DSK"; exit 1; }
"$IMGTOOL" put coco_dmk_rsdos "$DSK" "$BIN" INTERP.BIN \
    --ftype=binary --ascii=binary >/dev/null 2>&1 \
    || { echo "[interp_check] could not add INTERP.BIN to $DSK"; exit 1; }

sym() { grep -E "^Symbol: $2 " "$1" | sed -E 's/.*= *//'; }

export P_ENTRY="$(sym "$MAP" probe_entry)"
[ -n "$P_ENTRY" ] || { echo "[interp_check] probe_entry not in $MAP"; exit 1; }

export P_MODE="${P_MODE:-0}"
export P_SONG="${P_SONG:-7}"
export P_TO="${P_TO:-4200}"
export P_OUT="build/tmp/interp_song_${P_SONG}_m${P_MODE}.txt"
export P_REPORT="build/tmp/interp_check_${P_SONG}_m${P_MODE}.log"

. "$(dirname "$0")/ramsize.sh"
echo "[interp_check] $RAMOPT  probe \$$P_ENTRY  mode $P_MODE  song $P_SONG"

rm -f "$P_OUT" "$P_REPORT"
"$MAME" coco3 \
    -rompath "$MAME_ROMS" \
    $RAMOPT \
    -cfg_directory dist/mame-cfg/rgb \
    -ext fdc -flop1 "$DSK" \
    -window -nomaximize -nothrottle -sound none \
    -seconds_to_run "${P_SECS:-95}" \
    -autoboot_script harness/smoke/interp_live.lua \
    >/dev/null 2>&1

echo "[interp_check] --- $P_REPORT ---"
if [ -f "$P_REPORT" ]; then sed 's/^/  /' "$P_REPORT"; else echo "  (no log produced)"; exit 1; fi

rc=0
grep -q "^# PASS" "$P_REPORT" || { echo "[interp_check] DID NOT PASS"; rc=1; }

# ---- the fidelity diff, against the decoded model ----------------------------
# ★ Only meaningful on the interpret pass; the capture pass is measuring the OTHER path.
if [ "$P_MODE" = "0" ] && [ -f "$P_OUT" ]; then
    echo "[interp_check] --- the PORT against the DECODED MODEL ---"
    python harness/tools/msys_decode.py --song "$P_SONG" --compare "$P_OUT" \
        | sed 's/^/  /'
    CAP="build/tmp/boot/song_${P_SONG}_"*.txt
    for c in $CAP; do
        [ -f "$c" ] || continue
        echo "[interp_check] --- the MODEL against the ORACLE CAPTURE ---"
        python harness/tools/msys_decode.py --song "$P_SONG" --compare "$c" \
            | sed 's/^/  /'
    done
fi

echo "[interp_check] --------------------------------"
[ $rc -eq 0 ] && echo "[interp_check] OK" || echo "[interp_check] FAIL"
exit $rc
