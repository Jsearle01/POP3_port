#!/bin/bash
# harness/smoke/run_room_live.sh
#
# POP P3.17 phase A — the princess's room, LIVE at normal speed (Jay's 25.3 gate).
#
# THROTTLED on purpose (no -nothrottle) and the window stays open until closed. The
# room is static, so this gate is about the PICTURE and the palette rather than
# motion — but it is still the running machine on the real launch path
# (LOADM"ROOM"+EXEC off a mounted floppy, CLAUDE.md §4 launch path `live-disk`),
# not a poked image and not a rendered framebuffer.
#
# The byte comparison in run_room_test.sh already proves the displayed buffer IS the
# converted room. What this adds is the thing a byte comparison cannot judge: whether
# the 4-colour palette looks right on a real screen. That is Jay's eye, and the
# palette here is deliberately Karateka's starting point, not a final choice.
#
# MONITOR=composite looks at the other monitor type; MAME_RAM=128K runs it on a
# 128 KB machine.
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
MONITOR="${MONITOR:-rgb}"

SRC_DSK="build/probe.dmk"
DSK="build/run_room_live.dmk"
BIN="build/cutscene_room.bin"

[ -f "$BIN" ] || { echo "[run_room_live] missing $BIN — run build.bat first"; exit 1; }
[ -f "$SRC_DSK" ] || { echo "[run_room_live] missing $SRC_DSK — run build.bat first"; exit 1; }
cp -f "$SRC_DSK" "$DSK" || exit 1

RAMOPT=""
[ -n "${MAME_RAM:-}" ] && RAMOPT="-ramsize $MAME_RAM"

echo "[run_room_live] POP CoCo3 — the princess's room, 4-colour, normal speed, $MONITOR${MAME_RAM:+, $MAME_RAM}"
echo "[run_room_live] boot, LOADM\"ROOM\", EXEC — then one disk read (~1.3 s) and the room appears."
echo "[run_room_live] palette is Karateka's 4c starting point: black / orange / blue / white."
echo "[run_room_live] close the window when you are done."

export P_PROG="ROOM"
export P_BIN="$BIN"
export P_OUT="build/room_live.log"

"$MAME" coco3 \
    -rompath "$MAME_ROMS" \
    $RAMOPT \
    -cfg_directory "dist/mame-cfg/$MONITOR" \
    -ext fdc \
    -flop1 "$DSK" \
    -window -nomaximize -prescale 2 \
    -sound none \
    -autoboot_script harness/smoke/room_live.lua
