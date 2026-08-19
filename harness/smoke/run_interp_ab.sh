#!/bin/bash
# harness/smoke/run_interp_ab.sh — P4.19: the A/B, WITH SOUND, for Jay's ear.
#
# ★★★ THIS ONE IS MEANT TO BE HEARD. Every measuring runner passes `-sound none` and
# `-nothrottle`; this is the gate on whether the music SOUNDS right, so sound is on and the
# machine runs at real speed. A tone rendered at 1,300% is not a tone.
#
# ★★ AND IT IS A TRUE A/B: BOTH PLAYERS ARE IN ONE BINARY, sharing the audio path, the DAC,
# the pulse shape and the tear-down. The ONLY difference is where the (period, width) pairs
# come from. Anything you hear is the decode, not the hardware.
#
#   PASS A  INTERPRET — msys_player.s walking MUSIC.SET1's own 1,024 bytes.
#   PASS B  CAPTURE   — the oracle's own recording of THE SAME SONG, replayed.
#
# ★★★ AND "THE SAME SONG" IS A CORRECTION, NOT A DETAIL. The first cut of this runner
# paired the interpreter's 12.7 s of s_Princess against `song_a` — the P4.4 capture of
# PlayCut0's WHOLE 37.6 s music stretch. Measured: 14 s against 37 s. That is not an A/B,
# it is two different pieces of two different lengths, and it is the same shape as P4.6's
# "the port sounds like the same piece repeated 3 times" and P4.15's "I captured the wrong
# songs." Pass B is now the per-song capture of song 7: 6,930 segments, 12,724 ms, 3,137 B.
# Measured after the fix: 14 s against 13 s, peaks 17,921 against 17,530.
#
# ★ s_Princess and not another song, for a reason that is not arbitrary: nine of the eleven
# per-song captures are contaminated by a second, non-MSYS sound source (P4.19 §3E).
# s_Princess is one of the two clean ones, so it is the only honest A/B available.
#
# 128 KB, the target. Launch path live-disk (CLAUDE.md §4).
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
IMGTOOL="${IMGTOOL:-/c/mame/imgtool.exe}"
DSK="build/run_interp_ab.dmk"
MAP="build/obj/interp.map"
BIN="build/interp_probe.bin"

[ -f "$BIN" ] || { echo "[interp-ab] missing $BIN — run build.bat"; exit 1; }
[ -f "$MAP" ] || { echo "[interp-ab] missing $MAP — run build.bat"; exit 1; }

# A copy of probe.dmk: the player is READ off track 32 of it, the way the intro will.
cp -f build/probe.dmk "$DSK" || exit 1
"$IMGTOOL" put coco_dmk_rsdos "$DSK" "$BIN" INTERP.BIN \
    --ftype=binary --ascii=binary >/dev/null 2>&1 \
    || { echo "[interp-ab] could not add INTERP.BIN to $DSK"; exit 1; }

. "$(dirname "$0")/ramsize.sh"

sym() { grep -E "^Symbol: $2 " "$1" | sed -E 's/.*= *//'; }
export P_ENTRY="$(sym "$MAP" probe_entry)"
export P_MODE="${P_MODE:-1}"     # 1 = interpret / gap / capture / gap, looping
export P_SONG="${P_SONG:-7}"
# ★ P_REPORT and P_OUT DELIBERATELY UNSET. With them set the Lua writes a report and calls
#   machine:exit(); unset, it does the boot/LOADM/EXEC and then leaves the window to you.

cat <<'BANNER'
[interp-ab]
[interp-ab] >> THIS RUN IS FOR YOUR EARS. Sound is ON, real speed.
[interp-ab]
[interp-ab] Boot, then LOADM"INTERP" + EXEC — about 20 s of disk before anything sounds.
[interp-ab] Then, on a loop:
[interp-ab]
[interp-ab]      13 s  INTERPRET   the note stream, decoded and walked
[interp-ab]      1.5 s silence
[interp-ab]      13 s  CAPTURE     the oracle's own recording of the same song
[interp-ab]      1.5 s silence
[interp-ab]
[interp-ab] Both are s_Princess, both 13 s, both through the same FIRQ, the same DAC and
[interp-ab] the same pulse. Interpret reads 1,024 bytes of score; capture replays 3,137
[interp-ab] bytes of recording. One variable: the decode.
[interp-ab]
[interp-ab] ★ FIXED SINCE THE RUN YOU JUST CLOSED. That one paired 14 s of s_Princess
[interp-ab] against 37 s of song_a -- PlayCut0's whole music stretch, a different and much
[interp-ab] longer piece. It was not an A/B and it was not answerable. Measured now:
[interp-ab] 14 s against 13 s, peak 17,921 against 17,530.
[interp-ab]
[interp-ab] WHAT I WOULD LISTEN FOR, because these are the two places the port is NOT the
[interp-ab] oracle and I cannot rule on either:
[interp-ab]
[interp-ab]   1. PITCH. The GIME timer quantises. Worst case is 10 cents (a tenth of a
[interp-ab]      semitone) and you ruled 12 cents inaudible at P4.6 — but you ruled that on
[interp-ab]      a different piece. Listen for anything sour, especially on held notes.
[interp-ab]   2. VOLUME. The pulse width IS the amplitude, and the port's smallest pulse
[interp-ab]      step is 2.79 us against the oracle's 7.83 us floor — so the quietest notes
[interp-ab]      come out about 7% loud. Listen to the attacks and decays.
[interp-ab]
[interp-ab] Timing is NOT a question: the port emitted 6,930 speaker toggles and the oracle
[interp-ab] emitted 6,930, over 774 frames against 762. That part is measured.
[interp-ab]
[interp-ab] IF THEY SOUND THE SAME, capture retires and all twelve songs wire through
[interp-ab] interpret. IF YOU PREFER CAPTURE, it stays for the cutscene and interpret is
[interp-ab] used for the intro — nothing is removed yet, so either ruling is cheap.
[interp-ab]
[interp-ab] Close the window when you are done.
[interp-ab]
BANNER

echo "[interp-ab] $RAMOPT  probe \$$P_ENTRY  mode $P_MODE  song $P_SONG"

"$MAME" coco3 \
    -rompath "$MAME_ROMS" \
    $RAMOPT \
    -cfg_directory dist/mame-cfg/rgb \
    -ext fdc -flop1 "$DSK" \
    -window -nomaximize -prescale 2 \
    -autoboot_script harness/smoke/interp_live.lua
