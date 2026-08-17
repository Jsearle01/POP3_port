#!/bin/bash
# harness/smoke/run_song_slice.sh — P4.5: the vertical slice, WITH SOUND, for Jay's ear.
#
# ★★★ THIS ONE IS MEANT TO BE HEARD. Every other runner in this project passes
# `-sound none` because it is measuring pixels or cycles; this is the gate on whether the
# music SOUNDS right, so sound is on and the machine is THROTTLED to real speed. A tone
# rendered at 1,300% is not a tone.
#
# ★★ AND IT DOES NOT TOUCH THE SHIPPING DISK. P4.2's instrument went onto build/probe.dmk
# for one build, DECB allocated its granules over a reserved cel-page track, and the
# engine's bank guard fired in a suite that had nothing to do with audio. SONG.BIN goes on
# a COPY, made here, at run time.
#
# What is playing: 6.5 s of s_Princess, MEASURED off the running oracle's speaker
# (oracle_speaker_intervals.lua) and packed to a table (pack_song.py). Nothing is decoded
# from MUSIC.SET* — that file has never been decoded and this slice does not need it.
#
# TINS=0, single mode, on purpose: it is the WORSE case (-2.02% at the top of the range),
# and Jay ruled "I can't rule on the 3% without hearing it".
#
# 128 KB, the target, through the one home. Launch path live-disk (CLAUDE.md §4).
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
IMGTOOL="${IMGTOOL:-/c/mame/imgtool.exe}"
SRC_DSK="build/probe.dmk"
DSK="build/run_song.dmk"
MAP="build/obj/song.map"

[ -f "build/song_probe.bin" ] || { echo "[song] missing build/song_probe.bin — run build.bat"; exit 1; }
[ -f "$MAP" ] || { echo "[song] missing $MAP — run build.bat"; exit 1; }
cp -f "$SRC_DSK" "$DSK" || exit 1
mkdir -p build/tmp

# SONG.BIN onto the COPY — see the note above.
"$IMGTOOL" put coco_dmk_rsdos "$DSK" build/song_probe.bin SONG.BIN \
    --ftype=binary --ascii=binary >/dev/null 2>&1 \
    || { echo "[song] could not add SONG.BIN to $DSK"; exit 1; }

. "$(dirname "$0")/ramsize.sh"

sym() { grep -E "^Symbol: $2 " "$1" | sed -E 's/.*= *//'; }
echo "[song] $RAMOPT  probe \$$(sym "$MAP" probe_entry)  runs \$$(sym "$MAP" probe_runs)"
echo "[song]"
echo "[song] ★ THIS RUN IS FOR YOUR EARS. Sound is ON and the machine runs at real speed."
echo "[song]"
echo "[song] Boot, then LOADM\"SONG\" + EXEC. ~20 s of disk, then 6.5 seconds of music:"
echo "[song]   the opening of PlayCut0 — principally s_Princess — replayed from the"
echo "[song]   oracle's own speaker timings."
echo "[song]"
echo "[song] TWO THINGS TO JUDGE, both yours:"
echo "[song]   1. THE 3%. TINS=0 runs the top of the range 2.02% flat — about a third of a"
echo "[song]      semitone. If you can't hear it, the TINS hybrid never gets built."
echo "[song]   2. THE TIMBRE. This emits a narrow PULSE, like the Apple, not a square wave."
echo "[song]"
echo "[song] NOT built: the hybrid; any decode of MUSIC.SET*; the other four songs."
echo "[song] Close the window when you are done."

"$MAME" coco3 \
    -rompath "$MAME_ROMS" \
    $RAMOPT \
    -cfg_directory dist/mame-cfg/rgb \
    -ext fdc -flop1 "$DSK" \
    -window -nomaximize -prescale 2 \
    -autoboot_script harness/smoke/song_live.lua
