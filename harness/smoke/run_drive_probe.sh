#!/bin/bash
# harness/smoke/run_drive_probe.sh — P5.22: what does drive 1 do when it holds side B, the wrong
# disk, no disk, or does not exist? Four MAME configurations, one probe (src/harness/drive_probe.s),
# drive 0 as the control in every run. Headless; poke path; not a suite.
set -u
cd "$(dirname "$0")/../.." || exit 1
MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
LWASM="${LWASM:-lwasm}"
A="${SIDE_A:-build/p522/side_a.dmk}"
B="${SIDE_B:-build/p522/side_b.dmk}"
"$LWASM" -9 --decb -o build/p522/drive_probe.bin src/harness/drive_probe.s || exit 1
. "$(dirname "$0")/ramsize.sh"
. "$(dirname "$0")/cfgdir.sh"
cp -f "$A" build/p522/dp_a.dmk; cp -f "$B" build/p522/dp_b.dmk; cp -f "$A" build/p522/dp_a2.dmk
run() {   # $1 = label, rest = drive-1 arguments
    local label="$1"; shift
    export P_BIN=build/p522/drive_probe.bin P_OUT="build/p522/drive_$label.log"
    rm -f "$P_OUT"
    "$MAME" coco3 -rompath "$MAME_ROMS" $RAMOPT $CFGOPT -ext fdc -flop1 build/p522/dp_a.dmk "$@" \
        -video none -sound none -nothrottle -seconds_to_run 120 \
        -autoboot_script harness/tools/drive_probe.lua >/dev/null 2>&1
    echo "$label $(cat "$P_OUT" 2>/dev/null || echo 'NO LOG')"
}
run right   -flop2 build/p522/dp_b.dmk
run wrong   -flop2 build/p522/dp_a2.dmk
run empty
run nodrive -ext:fdc:wd17xx:1 ""
