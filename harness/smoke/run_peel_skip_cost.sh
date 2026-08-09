#!/bin/bash
# harness/smoke/run_peel_skip_cost.sh
#
# POP P3.42 — quantify what the frame-wide peel-skip saves (P3.40 §3C, left open).
#
# Launch path is `live-disk` (CLAUDE.md §4): LOADM"ROOM" + EXEC off a mounted floppy.
# This is a MEASUREMENT, not a 25.3 gate — no visual claim is made from it.
#
# Addresses come from the link maps, never hardcoded — P3.10 cost a dispatch to a
# stale block number. room_loop is in the ROOM map; ch_anymove lives in the
# disk-resident character bundle, so it comes from the FLAMES map (same split
# run_room_test.sh documents).
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"

SRC_DSK="build/probe.dmk"
DSK="build/run_peelskip.dmk"
MAP="build/obj/room.map"
FMAP="build/obj/flames.map"
LOG="build/peel_skip_cost.log"

[ -f "$MAP" ]  || { echo "[run_peel_skip_cost] missing $MAP — run build.bat first";  exit 1; }
[ -f "$FMAP" ] || { echo "[run_peel_skip_cost] missing $FMAP — run build.bat first"; exit 1; }
[ -f "$SRC_DSK" ] || { echo "[run_peel_skip_cost] missing $SRC_DSK — run build.bat first"; exit 1; }
# MAME opens a floppy read-write and saves back (idiom 24) — mount a COPY.
cp -f "$SRC_DSK" "$DSK" || exit 1
rm -f "$LOG"

export P_LOOP="0x$(grep -E "^Symbol: room_loop "     "$MAP"  | sed -E 's/.*= *//')"
export P_SPIN="0x$(grep -E "^Symbol: hal_vbl_spin "  "$MAP"  | sed -E 's/.*= *//')"
export P_ANYMOVE="0x$(grep -E "^Symbol: ch_anymove " "$FMAP" | sed -E 's/.*= *//')"
export P_FIRST="${P_FIRST:-1900}"
export P_LAST="${P_LAST:-3400}"
export P_OUT="$LOG"

echo "[run_peel_skip_cost] room_loop $P_LOOP  hal_vbl_spin $P_SPIN  ch_anymove $P_ANYMOVE"

"$MAME" coco3 \
    -rompath "$MAME_ROMS" \
    -cfg_directory dist/mame-cfg/rgb \
    -ext fdc \
    -flop1 "$DSK" \
    -window -nomaximize \
    -nothrottle -sound none \
    -seconds_to_run 70 \
    -autoboot_script harness/tools/peel_skip_cost.lua \
    >/dev/null 2>&1

echo "[run_peel_skip_cost] --- measurement ---"
if [ -f "$LOG" ]; then sed 's/^/  /' "$LOG"; else echo "  (no log produced)"; exit 1; fi
echo "[run_peel_skip_cost] -------------------"
