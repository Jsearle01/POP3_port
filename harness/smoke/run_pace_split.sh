#!/bin/bash
# harness/smoke/run_pace_split.sh — P3.87: attribute the step-rate slip by split.
#
# Headless trace, no window. Boots off the real floppy (LOADM"ROOM" + EXEC) so the
# pacing measured is the pacing the delivery path produces, then taps rl_now, flm_idx
# and cad_idx and slices the step stream into loop iterations. See the Lua header.
#
# NOT a gate. -nothrottle is fine here: this reads VARIABLES, not the screen, and the
# idioms file's nothrottle caveat is about still-frames of motion (§6).
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"

SRC_DSK="build/probe.dmk"
DSK="build/run_pace_split.dmk"

[ -f "$SRC_DSK" ] || { echo "[pace_split] missing $SRC_DSK — run build.bat first"; exit 1; }
cp -f "$SRC_DSK" "$DSK" || exit 1
mkdir -p build/tmp

RAMOPT=""
[ -n "${MAME_RAM:-}" ] && RAMOPT="-ramsize $MAME_RAM"

LUA="${PACE_LUA:-harness/tools/port_pace_split.lua}"

echo "[pace_split] $LUA — headless, live-disk boot"
"$MAME" coco3 \
    -rompath "$MAME_ROMS" \
    $RAMOPT \
    -ext fdc \
    -flop1 "$DSK" \
    -nothrottle -video none -sound none \
    -autoboot_script "$LUA" >/dev/null 2>&1

echo "[pace_split] --- build/tmp/port_pace_split.log ---"
cat build/tmp/port_pace_split.log
