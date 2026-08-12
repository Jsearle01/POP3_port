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
# SINCE P3.31 THE SCENE HAS A GAIT IN IT, and that changes what this gate is for. The
# vizier walks left from x=197 at a measured 3.18 video frames per step, against a
# 2.60-frame floor that the cadence table asks for and the draw overruns. Whether that
# is the right PACE is not a thing any byte comparison can answer -- CLAUDE.md §4:
# motion-bearing gates need a live run, and "density is not motion" (P3.29). This is
# the runner for it. A rejection is a policy revisit, not a defect.
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
echo "[run_room_live] boot, LOADM\"ROOM\", EXEC — then THREE track reads (room, flame bundle,"
echo "[run_room_live]   and the \$C000 cel bank added at P3.71) and the room appears."
echo "[run_room_live] UNDER GATE: Palert — SHE HEARS THE DOOR AND TURNS. New at P3.71/P3.72."
echo "[run_room_live]   Watch the OPENING: she hears him and turns to the door over eight cels."
echo "[run_room_live]   After the turn she stands MIRRORED for the rest of the scene — that"
echo "[run_room_live]   facing is what her turn is for."
echo "[run_room_live]   Then the vizier walks in from the right and stops; his GAIT is under gate"
echo "[run_room_live]   as before."
echo "[run_room_live]"
echo "[run_room_live] P3.78 — THE IMAGE IS NOW SPLIT ACROSS GIME BLOCKS AND PAGED PER BEAT."
echo "[run_room_live]   NEW AND UNGATED: he raises his arms (Vraise), she backs away (Pback),"
echo "[run_room_live]   he turns and walks out (Vexit), she slumps (Pslump)."
echo "[run_room_live]"
echo "[run_room_live] * TWO DELIBERATE FREEZES. A disk read is staged inside each of the two"
echo "[run_room_live]   song holds -- over his first stop, and again before he raises his arms."
echo "[run_room_live]   The torches STOP for 3.19 s and 2.89 s (measured). No DMA: the CPU is"
echo "[run_room_live]   the transfer. Jay accepted 1.7 s at P3.75 for ONE track; a page is two,"
echo "[run_room_live]   so this is over that -- a decision to make, not a bug to find."
echo "[run_room_live]"
echo "[run_room_live] ** IT DOES NOT FINISH, AND THIS IS THE KNOWN FAULT. As he walks OUT he"
echo "[run_room_live]   leaves the right edge and the blitter has no per-row clip yet, so the"
echo "[run_room_live]   draw runs past the row end. Expect the picture to break up there."
echo "[run_room_live]   Everything BEFORE that point is what is worth looking at."
echo "[run_room_live]"
echo "[run_room_live] NOT IN YET: the hourglass and its white flash (they belong between Pback"
echo "[run_room_live]   and Vexit), the s_Magic hold, the 16-colour swap, the Prolog2 handoff."
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
