#!/bin/bash
# harness/smoke/run_introseq_live.sh
#
# POP CoCo3 — P3.3 intro sequencer, LIVE at normal speed (Jay's 25.3 gate).
#
# THROTTLED on purpose — no -nothrottle. The gate here is the TIMING and the
# flips, and both are meaningless at 500% speed.
#
# `-cfg_directory dist/mame-cfg/rgb` forces Monitor Type = RGB; MAME's default
# is Composite, in which the same palette byte is a different colour
# (CLAUDE.md §4). Pass MONITOR=composite to look at the other one.
#
# The window stays open until you close it. The sequence runs once and then
# holds on the clean splash — that is where the oracle goes on to the title.
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
MONITOR="${MONITOR:-rgb}"
BIN="build/intro_seq.bin"

[ -f "$BIN" ] || { echo "[run_introseq_live] missing $BIN — run build.bat first"; exit 1; }

echo "[run_introseq_live] POP CoCo3 P3.3 — the two opening credits, normal speed, $MONITOR"
echo "[run_introseq_live] splash 1.7 s -> \"Broderbund Software Presents\" 4.7 s -> clear 1.6 s"
echo "[run_introseq_live]        -> \"A Game by Jordan Mechner\" 4.7 s -> clear, then holds"
echo "[run_introseq_live] close the window when you are done."

export P_BIN="$BIN"
export P_OUT="build/introseq_live.log"

"$MAME" coco3 \
    -rompath "$MAME_ROMS" \
    -cfg_directory "dist/mame-cfg/$MONITOR" \
    -window -nomaximize -prescale 2 \
    -sound none \
    -autoboot_script harness/smoke/introseq_live.lua
