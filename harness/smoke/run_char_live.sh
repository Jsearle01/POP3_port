#!/bin/bash
# harness/smoke/run_char_live.sh
#
# POP P5.28 — THE GATE RUNNER for the first character on a gameplay screen. Throttled,
# windowed, LOADM"CHAR" + EXEC off a mounted floppy (CLAUDE.md §4 `live-disk`), RGB via
# dist/mame-cfg/rgb, and it does not exit. tile_live.lua drives it with P_FILE=CHAR.
#
# SRC_DSK overrides the image, the same way run_introseq_live.sh's does -- e.g. to run a copy
# written to a real floppy. Default: build/char_gate.dmk.
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"

SRC_DSK="${SRC_DSK:-build/char_gate.dmk}"
DSK="build/run_char_live.dmk"
MAP="build/obj/charprobe.map"

[ -f "$SRC_DSK" ] || { echo "[char-live] missing $SRC_DSK — run build.bat first"; exit 1; }
cp -f "$SRC_DSK" "$DSK" || exit 1

export P_ENGINE="0x$(grep -E "^Symbol: tile_entry " "$MAP" | sed -E "s/.*= *//")"
export P_FILE="CHAR" P_OUT="build/char_live.log"
# CHAR.BIN is ~9.5 KB, five granules against TILE.BIN's one: give LOADM longer before EXEC
# is typed (a keystroke that lands while DECB is still loading is lost). 900 frames is the
# settle tile_test.lua uses; LOADM's first byte lands ~540 frames after it is typed. The first
# gate ran at 1500 (25 s of a silent prompt) and Jay typed EXEC himself, which is harmless to
# the program but leaves the log watching only after the picture is already up.
export P_EXEC_WAIT="${P_EXEC_WAIT:-900}"

. "$(dirname "$0")/ramsize.sh"
. "$(dirname "$0")/cfgdir.sh"

echo "[char-live] POP CoCo3 — LEVEL0 screen 1 + the kid x3, live disk, RGB, $MAME_RAM"
echo "[char-live] the script types LOADM\"CHAR\" then EXEC; the picture should hold."

exec "$MAME" coco3 -rompath "$MAME_ROMS" $RAMOPT $CFGOPT -ext fdc -flop1 "$DSK" \
    -window -nomaximize -autoboot_script harness/smoke/tile_live.lua
