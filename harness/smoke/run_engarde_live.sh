#!/bin/bash
# harness/smoke/run_engarde_live.sh
#
# POP P5.37 — THE MOTION GATE: the guard goes en garde and comes forward, live. Throttled, windowed,
# LOADM"GUARD" + EXEC off a mounted floppy (CLAUDE.md §4 `live-disk`), RGB via dist/mame-cfg/rgb, and it
# does not exit. The en garde and the advance are motion -- a still cannot gate them.
#
# What runs: the oracle's game frames 180-217 on LEVEL0 SCREEN 4, the guard driven by his AI
# (src/engine/guard_ai.s) at 9 display frames per game frame, the last frame held 1.5 s, then again from
# the game-frame-179 seed. ★ A TEST BED: the kid is REPLAYED into the AI and NOT DRAWN; the guard's sword
# is a separate sprite and is not drawn (out of scope).
set -u
cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
SRC_DSK="${SRC_DSK:-build/engarde_gate.dmk}"
DSK="build/run_engarde_live.dmk"
MAP="build/obj/engarde.map"

[ -f "$SRC_DSK" ] || { echo "[engarde-live] missing $SRC_DSK — run build.bat first"; exit 1; }
cp -f "$SRC_DSK" "$DSK" || exit 1

export P_ENGINE="0x$(grep -E "^Symbol: tile_entry " "$MAP" | sed -E "s/.*= *//")"
export P_FILE="GUARD" P_OUT="build/engarde_live.log"
export P_EXEC_WAIT="${P_EXEC_WAIT:-600}"

. "$(dirname "$0")/ramsize.sh"
. "$(dirname "$0")/cfgdir.sh"

echo "[engarde-live] POP CoCo3 — the guard goes en garde, LEVEL0 screen 4, live disk, RGB, $MAME_RAM"
echo "[engarde-live] the script types LOADM\"GUARD\", waits for the load, then EXEC."

exec "$MAME" coco3 -rompath "$MAME_ROMS" $RAMOPT $CFGOPT -ext fdc -flop1 "$DSK" \
    -window -nomaximize -autoboot_script harness/smoke/tile_live.lua
