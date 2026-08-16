#!/bin/bash
# harness/smoke/run_peel_trace.sh
#
# POP P3.72 §7 — the erase record, per frame, across the princess's one move.
# See harness/tools/peel_trace.lua for what is being asked and what is already
# exonerated. Addresses come from the maps, never hardcoded (P3.10 cost a dispatch to a
# stale block number); the slot records live in the disk-resident bundle, so they come
# from the FLAMES map while the engine's own symbols come from the ROOM map.
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
SRC_DSK="build/probe.dmk"
DSK="build/run_peel.dmk"
MAP="build/obj/room.map"
FMAP="build/obj/flames.map"

[ -f "$MAP" ]  || { echo "[peel_trace] missing $MAP — run build.bat first";  exit 1; }
[ -f "$FMAP" ] || { echo "[peel_trace] missing $FMAP — run build.bat first"; exit 1; }
cp -f "$SRC_DSK" "$DSK" || exit 1
rm -f build/peel_trace.log

sym() { grep -E "^Symbol: $2 " "$1" | sed -E 's/.*= *//'; }

export P_ENGINE="0x$(sym "$MAP" room_entry)"
export P_CURBACK="0x$(sym "$MAP" HAL_gfx_cur_back)"
export P_PRI_SLOT="0x$(sym "$FMAP" pri_slot)"
export P_LAST="0x$(sym "$FMAP" ch_last)"
export P_DRAWN="0x$(sym "$FMAP" ch_drawn)"
export P_MOVE="0x$(sym "$FMAP" ch_move)"
export P_ANYMOVE="0x$(sym "$FMAP" ch_anymove)"
export P_SEEN="0x$(sym "$FMAP" ch_seen)"
export P_NFRAMES="${P_NFRAMES:-70}"

echo "[peel_trace] pri_slot $P_PRI_SLOT  ch_last $P_LAST  ch_move $P_MOVE"

# 128 KB, the target (CLAUDE.md §2K), through the ONE HOME for that fact — this runner
# carried no -ramsize at all until P3.101's sweep, so every reading it has ever produced
# was taken on the 512 KB machine. See harness/smoke/ramsize.sh.
. "$(dirname "$0")/ramsize.sh"

"$MAME" coco3 \
    -rompath "$MAME_ROMS" \
    $RAMOPT \
    -cfg_directory dist/mame-cfg/rgb \
    -ext fdc -flop1 "$DSK" \
    -window -nomaximize -nothrottle -sound none \
    -seconds_to_run 60 \
    -autoboot_script harness/tools/peel_trace.lua \
    >/dev/null 2>&1

if [ -f build/peel_trace.log ]; then sed 's/^/  /' build/peel_trace.log
else echo "  (no log produced)"; exit 1; fi
