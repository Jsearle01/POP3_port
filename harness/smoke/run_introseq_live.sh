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
# The window stays open until you close it.
#
# THE DISK IS MANDATORY, and was missing here until now: `-ext fdc` plus `-flop1`.
# A bare coco3 has no controller, so LOADM does nothing and the machine just sits
# at the BASIC prompt. The lua half of this pair has read from disk since P3.4;
# this shell half was still the P3.3 diskless version, which poked the binary in.
#
# The disk is a SCRATCH COPY — MAME opens a floppy read-write and saves back
# (idiom 24), and the raw asset tracks share the image, so a write-back would
# corrupt the screens as well as the files.
#
# MAME_RAM=128K runs it on a 128 KB machine.
set -u

# ★★★ SOUND IS ON BY DEFAULT SINCE P4.21, AND THAT CHANGES WHAT THIS RUNNER IS FOR.
# It passed `-sound none` from P3.3 onward, correctly: the intro had no audio and this was
# a gate on pixels and timing. Beat 1 now plays s_Presents through the interpreted player,
# so a silent run can no longer answer the question being asked of it.
# MUTE=1 restores the old behaviour when the look is what is under inspection.
# ★ MAME rejects `-sound sdl` on this build ("Value sdl not supported... falling back to
#   auto"). Auto IS the working default, so ask for it by name rather than pass a value the
#   emulator has to refuse -- a runner that prints a rejection every launch trains the
#   reader to ignore its output.
SOUNDOPT="-sound auto"
if [ "${MUTE:-0}" = "1" ]; then SOUNDOPT="-sound none"; fi

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
MONITOR="${MONITOR:-rgb}"
BIN="build/intro_seq.bin"
SRC_DSK="build/probe.dmk"
DSK="build/run_introseq_live.dmk"

[ -f "$BIN" ] || { echo "[run_introseq_live] missing $BIN — run build.bat first"; exit 1; }
[ -f "$SRC_DSK" ] || { echo "[run_introseq_live] missing $SRC_DSK — run build.bat first"; exit 1; }
cp -f "$SRC_DSK" "$DSK" || exit 1

# ONE HOME for which machine this runs on: 128 KB, the target (CLAUDE.md 2K).
. "$(dirname "$0")/ramsize.sh"

echo "[run_introseq_live] POP CoCo3 — the static intro, normal speed, $MONITOR${MAME_RAM:+, $MAME_RAM}"
echo "[run_introseq_live] boot, LOADM\"INTROSEQ\", EXEC — then six beats, every asset off disk:"
echo "[run_introseq_live]   splash -> \"Broderbund Software Presents\" -> clear"
echo "[run_introseq_live]          -> \"A Game by Jordan Mechner\" -> clear"
echo "[run_introseq_live]          -> \"Prince of Persia\" -> clear"
echo "[run_introseq_live]          -> prologue 1 -> prologue 2 -> title reprise -> clear, then holds"
echo "[run_introseq_live] 17.2 s of it is disk (measured); 11.2 s of that is before the first picture."
echo "[run_introseq_live] close the window when you are done."

export P_BIN="$BIN"
export P_OUT="build/introseq_live.log"

"$MAME" coco3 \
    -rompath "$MAME_ROMS" \
    -cfg_directory "dist/mame-cfg/$MONITOR" \
    $RAMOPT \
    -ext fdc \
    -flop1 "$DSK" \
    -window -nomaximize -prescale 2 \
    $SOUNDOPT \
    -autoboot_script harness/smoke/introseq_live.lua
