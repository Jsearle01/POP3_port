#!/bin/bash
# harness/smoke/run_song_wav.sh — P4.6 §3: record BOTH renditions to WAV.
#
# ★★★ TWO QUESTIONS, KEPT APART, because conflating them is what makes an ear gate
# unanswerable. Jay: "it's going to be hard to gate something without knowing what it would
# sound like the other way."
#
#   PORT vs PORT   isolated the DETUNE — same code, same pulse, one variable. ASKED AND
#                  ANSWERED at P4.6: "i don't hear a difference", so the dither is retired
#                  and that comparison no longer exists to be made.
#   PORT vs ORACLE (this script) is the separate question of whether it sounds RIGHT AT ALL,
#                  and it CANNOT isolate anything: a 6-bit DAC driven by a GIME timer and a
#                  one-bit speaker driven by a 6502 differ in more ways than one.
#
# So this produces two files and makes no claim about which difference is which.
#
#   P_WHICH=oracle   the Apple II, playing s_Princess inside PlayCut0
#   P_WHICH=port     the CoCo3 slice, looping (probe_mode 1)
#   P_WHICH=both     (default)
#
# ★ MAME's -wavwrite records the emulated audio output of the whole session, from frame 0.
# It is NOT trimmed to the music, and the offsets below are where to skip to. `-sound none`
# is therefore NOT passed here — it would produce a valid, silent file, which is exactly the
# failure mode this project keeps meeting: an artifact that looks produced and is empty.
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
IMGTOOL="${IMGTOOL:-/c/mame/imgtool.exe}"
WHICH="${P_WHICH:-both}"
mkdir -p build/tmp

# ★ AND THEN TRIM IT. A 25 MB file with the music 44 seconds in is a transport-control
# exercise, not a listening one. wav_trim.py finds the activity against the file's OWN idle
# level and reports the peak it kept — so a trim that produced silence cannot pass for one
# that worked.
report() {
    local f="$1" what="$2" after="$3"
    if [ -s "$f" ]; then
        local sz
        sz=$(stat -c %s "$f" 2>/dev/null || echo 0)
        echo "[song_wav] $what -> $f  ($((sz/1024)) KB)"
        [ "$sz" -lt 100000 ] && echo "[song_wav]   ★ SUSPICIOUSLY SMALL — check it is not silence."
        python harness/tools/wav_trim.py --wav "$f" --out "${f%.wav}_trim.wav" --after "$after" \
            || echo "[song_wav]   ★ trim failed — use the untrimmed file"
    else
        echo "[song_wav] ★ $what produced NO file. That is a failure, not a quiet recording."
    fi
}

# ---------------------------------------------------------------- the oracle
if [ "$WHICH" = "oracle" ] || [ "$WHICH" = "both" ]; then
    HDV="oracle/source/PrinceOfPersia_3.5.hdv"
    SCRATCH="build/oracle_wav.hdv"
    [ -f "$HDV" ] || { echo "[song_wav] missing $HDV"; exit 1; }
    # ORACLE SOURCE IS READ-ONLY: the emulator writes to a copy, never to the reference.
    cp -f "$HDV" "$SCRATCH" || exit 1
    OUT="build/tmp/oracle_princess.wav"
    rm -f "$OUT"
    echo "[song_wav] oracle: apple2e + cffa202, 70 emulated seconds..."
    "$MAME" apple2e \
        -rompath "$MAME_ROMS" \
        -sl7 cffa202 \
        -hard1 "$(pwd -W)/$SCRATCH" \
        -nothrottle -video none \
        -seconds_to_run 70 \
        -wavwrite "$OUT" >/dev/null 2>&1
    # PlayCut0 arms at frame 2681 of a 60 Hz screen -- about 44.7 s in [P4.4].
    report "$OUT" "ORACLE (Apple II speaker)" 40
fi

# ---------------------------------------------------------------- the port
if [ "$WHICH" = "port" ] || [ "$WHICH" = "both" ]; then
    MAP="build/obj/song.map"
    [ -f "build/song_probe.bin" ] || { echo "[song_wav] missing build/song_probe.bin — run build.bat"; exit 1; }
    DSK="build/run_song_wav.dmk"
    cp -f build/probe.dmk "$DSK" || exit 1
    "$IMGTOOL" put coco_dmk_rsdos "$DSK" build/song_probe.bin SONG.BIN \
        --ftype=binary --ascii=binary >/dev/null 2>&1 \
        || { echo "[song_wav] could not add SONG.BIN to $DSK"; exit 1; }
    sym() { grep -E "^Symbol: $2 " "$1" | sed -E 's/.*= *//'; }
    export P_ENTRY="$(sym "$MAP" probe_entry)"
    export P_MODE=1                 # looping with a gap, so the capture has whole passes
    unset P_OUT P_SPIN P_PULSE 2>/dev/null || true
    OUT="build/tmp/port_princess.wav"
    rm -f "$OUT"
    . "$(dirname "$0")/ramsize.sh"
    echo "[song_wav] port: coco3 $RAMOPT, 45 emulated seconds (boot + LOADM + several passes)..."
    "$MAME" coco3 \
        -rompath "$MAME_ROMS" \
        $RAMOPT \
        -cfg_directory dist/mame-cfg/rgb \
        -ext fdc -flop1 "$DSK" \
        -video none -nothrottle \
        -seconds_to_run 45 \
        -wavwrite "$OUT" \
        -autoboot_script harness/smoke/song_live.lua >/dev/null 2>&1
    # EXEC is posted 1200 frames in; the disk read then takes a few seconds.
    report "$OUT" "PORT (CoCo3 DAC) — s_Princess, looping" 20
fi

echo "[song_wav] done. These are for LISTENING, not for a script to grade."
