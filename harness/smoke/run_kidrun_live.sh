#!/bin/bash
# harness/smoke/run_kidrun_live.sh
#
# POP P5.31 — THE MOTION GATE. The kid runs `startrun` across LEVEL0 screen 1, live: throttled,
# windowed, LOADM"KIDRUN" + EXEC off a mounted floppy (CLAUDE.md §4 `live-disk` -- the only path
# that gates delivery), RGB via dist/mame-cfg/rgb, and it does not exit. A still cannot gate this
# (CLAUDE.md §4: "Endpoints are not motion"); this is the run Jay watches.
#
# SRC_DSK overrides the image. ★ P5.31b: KIDRUN.BIN is now a ~1.3 KB LOADER (src/boot/kidrun_boot.s)
# that reads the probe off raw tracks after EXEC, the intro's shape -- P5.31's 18,460 B LOADM took
# 20.1 s on these interleave-0 disks. The script waits 600 frames after typing LOADM before EXEC.
set -u
cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
SRC_DSK="${SRC_DSK:-build/kidrun_gate.dmk}"
DSK="build/run_kidrun_live.dmk"
MAP="build/obj/kidrun.map"

[ -f "$SRC_DSK" ] || { echo "[kidrun-live] missing $SRC_DSK — run build.bat first"; exit 1; }
cp -f "$SRC_DSK" "$DSK" || exit 1

export P_ENGINE="0x$(grep -E "^Symbol: tile_entry " "$MAP" | sed -E "s/.*= *//")"
export P_FILE="KIDRUN" P_OUT="build/kidrun_live.log"
export P_EXEC_WAIT="${P_EXEC_WAIT:-600}"

. "$(dirname "$0")/ramsize.sh"
. "$(dirname "$0")/cfgdir.sh"

echo "[kidrun-live] POP CoCo3 — the kid runs, LEVEL0 screen 1, live disk, RGB, $MAME_RAM"
echo "[kidrun-live] the script types LOADM\"KIDRUN\", waits for the load, then EXEC."

exec "$MAME" coco3 -rompath "$MAME_ROMS" $RAMOPT $CFGOPT -ext fdc -flop1 "$DSK" \
    -window -nomaximize -autoboot_script harness/smoke/tile_live.lua
