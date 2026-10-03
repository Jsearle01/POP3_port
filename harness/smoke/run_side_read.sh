#!/bin/bash
# harness/smoke/run_side_read.sh — P5.22: read an authored side back through disk_read_range.
#
#   harness/smoke/run_side_read.sh build/p522/side_b.dmk
#
# Links src/harness/side_read_probe.s against the port's own build/obj/hal_build.o (run build.bat
# first), mounts a SCRATCH COPY of the side (MAME writes floppies back, idiom 24), pokes the probe,
# and compares every track the 6809 read against the same image read independently by imgtool.
# Not a suite; not on probe.dmk; headless.
set -u
cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
LWASM="${LWASM:-lwasm}"
LWLINK="${LWLINK:-lwlink}"
SIDE="${1:?usage: run_side_read.sh <side.dmk>}"
SCR="build/p522/side_read_scratch.dmk"

[ -f build/obj/hal_build.o ] || { echo "[side_read] run build.bat first (needs hal_build.o)"; exit 1; }
"$LWASM" --obj -DOBJTARGET -DDR_VARBASE=0x6A00 -I . -o build/p522/side_read_probe.o src/harness/side_read_probe.s || exit 1
"$LWLINK" --decb --script=link/pop_tile.link --entry=side_entry --map=build/p522/side_read.map \
    -o build/p522/side_read.bin build/p522/side_read_probe.o build/obj/hal_build.o || exit 1
ENTRY="0x$(grep -E '^Symbol: side_entry ' build/p522/side_read.map | sed -E 's/.*= *//')"
cp -f "$SIDE" "$SCR" || exit 1

. "$(dirname "$0")/ramsize.sh"
. "$(dirname "$0")/cfgdir.sh"
export P_BIN=build/p522/side_read.bin P_OUT=build/p522/side_read.log P_ENTRY="$ENTRY"
rm -f "$P_OUT"
echo "[side_read] $SIDE  entry $ENTRY  ramsize $MAME_RAM"
"$MAME" coco3 -rompath "$MAME_ROMS" $RAMOPT $CFGOPT -ext fdc -flop1 "$SCR" \
    -video none -sound none -nothrottle -seconds_to_run 600 \
    -autoboot_script harness/tools/side_read.lua >/dev/null 2>&1
python harness/tools/side_read_check.py --dsk "$SIDE" --log "$P_OUT"
