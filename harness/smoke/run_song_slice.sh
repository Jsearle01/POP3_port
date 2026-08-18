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
export P_ENTRY="$(sym "$MAP" probe_entry)"
# probe_mode 1 = A, gap, B, gap, LOOPING. P4.6 built the comparison Jay asked for:
# "it's going to be hard to gate something without knowing what it would sound like the
# other way." A single rendition judged alone answers a different question than the one
# being asked, and looping it means he can go back and forth rather than remember.
export P_MODE=1

echo "[song] $RAMOPT  probe \$$P_ENTRY  mode $P_MODE (A / gap / B / gap, looping)"
echo "[song]"
echo "[song] >> THIS RUN IS FOR YOUR EARS. Sound is ON, real speed."
echo "[song]"
echo "[song] Boot, then LOADM\"SONG\" + EXEC. ~20 s of disk, then, on repeat:"
echo "[song]     6.5 s  TABLE A   the as-built quantisation"
echo "[song]     1.5 s  silence"
echo "[song]     6.5 s  TABLE B   the same song, periods dithered so the mean is right"
echo "[song]     1.5 s  silence"
echo "[song]"
echo "[song] THE ONLY DIFFERENCE BETWEEN A AND B IS THE TUNING. Same player, same code"
echo "[song] path, same pulse widths, same table size - only the numbers differ."
echo "[song]   A: per-segment period error mean 0.92%, worst 1.20%, and BIASED - the song"
echo "[song]      runs 0.69% sharp overall, because 2,936 of its 3,924 segments share a"
echo "[song]      handful of periods that all round the same way."
echo "[song]   B: mean 0.005%, at the price of up to one tick of jitter per segment -"
echo "[song]      right on average, less steady instant to instant."
echo "[song]"
echo "[song] >> AND WHAT P4.5 GAVE YOU WAS NEITHER. It played 7.2% LONG - about 1.2"
echo "[song] semitones flat - because the GIME runs nnn+2 ticks and the handler's own"
echo "[song] latency was unmeasured. Both are measured now. If A and B sound alike, that"
echo "[song] is a real answer: the dither comes out and the player gets 0.9% of a frame back."
echo "[song]"
echo "[song] For port-vs-ORACLE, a different question, run run_song_wav.sh."
echo "[song] NOT built: any decode of MUSIC.SET*; the other four songs."
echo "[song] Close the window when you are done."

"$MAME" coco3 \
    -rompath "$MAME_ROMS" \
    $RAMOPT \
    -cfg_directory dist/mame-cfg/rgb \
    -ext fdc -flop1 "$DSK" \
    -window -nomaximize -prescale 2 \
    -autoboot_script harness/smoke/song_live.lua
