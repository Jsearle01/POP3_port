#!/bin/bash
# harness/smoke/run_change_census.sh
#
# POP P3.45 — how often anything on screen actually changes (the skippable ceiling).
# Launch path is `live-disk` (CLAUDE.md §4). Measurement only; no visual claim, no build.
# Addresses from the link maps, never hardcoded (P3.10).
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"

SRC_DSK="build/probe.dmk"
DSK="build/run_changecensus.dmk"
MAP="build/obj/room.map"
FMAP="build/obj/flames.map"
LOG="build/change_census.log"

[ -f "$MAP" ]  || { echo "[run_change_census] missing $MAP — run build.bat first";  exit 1; }
[ -f "$FMAP" ] || { echo "[run_change_census] missing $FMAP — run build.bat first"; exit 1; }
cp -f "$SRC_DSK" "$DSK" || exit 1     # MAME writes floppies back (idiom 24) — mount a copy
rm -f "$LOG"

sym() { grep -E "^Symbol: $2 " "$1" | sed -E 's/.*= *//'; }

export P_LOOP="0x$(sym "$MAP"  room_loop)"
export P_FLST="0x$(sym "$MAP"  fl_state0)"
export P_STARS="0x$(sym "$MAP" star_cnt)"
export P_VMDUE="0x$(sym "$FMAP" vm_due)"
export P_FIRST="${P_FIRST:-1900}"
export P_LAST="${P_LAST:-3400}"
export P_OUT="$LOG"

echo "[run_change_census] vm_due $P_VMDUE  fl_state0 $P_FLST  star_cnt $P_STARS"

# 128 KB, the target (CLAUDE.md §2K), through the ONE HOME for that fact — this runner
# carried no -ramsize at all until P3.101's sweep, so every reading it has ever produced
# was taken on the 512 KB machine. See harness/smoke/ramsize.sh.
. "$(dirname "$0")/ramsize.sh"

"$MAME" coco3 \
    -rompath "$MAME_ROMS" \
    $RAMOPT \
    -cfg_directory dist/mame-cfg/rgb \
    -ext fdc \
    -flop1 "$DSK" \
    -window -nomaximize \
    -nothrottle -sound none \
    -seconds_to_run 70 \
    -autoboot_script harness/tools/change_census.lua \
    >/dev/null 2>&1

echo "[run_change_census] --- census ---"
if [ -f "$LOG" ]; then sed 's/^/  /' "$LOG"; else echo "  (no log produced)"; exit 1; fi
rm -f "$DSK"
