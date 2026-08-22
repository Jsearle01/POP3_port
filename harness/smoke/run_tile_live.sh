#!/bin/bash
# harness/smoke/run_tile_live.sh
#
# POP P5.5 — THE GATE RUNNER. LEVEL0 screen 1 on a real, throttled, windowed CoCo 3,
# booted the delivery way: LOADM"TILE" + EXEC off a mounted floppy.
#
# This is the `live-disk` launch path of CLAUDE.md §4 and it is the only one that gates
# delivery. run_tile_test.sh is the automated check and runs headless at full tilt; this
# one exists so Jay can WATCH it, so it throttles, keeps the window, and does not exit.
#
# ★ WHAT THIS GATE CAN AND CANNOT SHOW. The tile page is a STATIC picture: there is no
# motion under gate here, so a still would in principle serve. It is run live anyway
# because the thing being gated is not only the pixels but the PATH -- that the machine
# boots, DECB loads the file, EXEC reaches the renderer, the track read succeeds and the
# picture appears without a flash of garbage. None of that is visible in a framebuffer dump.
#
# RGB, screen_config=1 — the mode CLAUDE.md §4 fixes for this project, via
# dist/mame-cfg/rgb. State the mode when reporting the gate.
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"

SRC_DSK="build/probe.dmk"
DSK="build/run_tile_live.dmk"

[ -f "$SRC_DSK" ] || { echo "[tile-live] missing $SRC_DSK — run build.bat first"; exit 1; }
# A SCRATCH COPY, always: MAME opens a floppy read-write and saves back (idiom 24), and
# this image carries the packed page on a raw track that no DECB directory protects.
cp -f "$SRC_DSK" "$DSK" || exit 1

. "$(dirname "$0")/ramsize.sh"
. "$(dirname "$0")/cfgdir.sh"

echo "[tile-live] POP CoCo3 — LEVEL0 screen 1, live disk, RGB, $MAME_RAM"
echo "[tile-live] the script types LOADM\"TILE\" then EXEC; the picture should hold."

exec "$MAME" coco3 \
    -rompath "$MAME_ROMS" \
    $RAMOPT \
    $CFGOPT \
    -ext fdc \
    -flop1 "$DSK" \
    -window -nomaximize \
    -autoboot_script harness/smoke/tile_live.lua
