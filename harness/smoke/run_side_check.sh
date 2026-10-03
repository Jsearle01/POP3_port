#!/bin/bash
# harness/smoke/run_side_check.sh — P5.24: Jay's four drive-1 cases + the signature's uniqueness.
#
# Builds a HAL object WITH -DHAL_DISK_DRIVE_SELECT (build/p524/hal_build_ds.o -- NOT the shipped
# build/obj/hal_build.o, which stays exactly as build.bat makes it), links side_check_probe.s
# against it, and runs the same eight-step table in every configuration below. Headless; poke.
#
#   harness/smoke/run_side_check.sh            all configurations
# Disks come from harness/tools/wrong_disks.py (build/p524/disks/) and the P5.22 sides.
set -u
cd "$(dirname "$0")/../.." || exit 1
MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
LWASM="${LWASM:-lwasm}"
LWLINK="${LWLINK:-lwlink}"
D=build/p524
mkdir -p $D/run
"$LWASM" --obj -DOBJTARGET -DHAL_GFX_MODE_SERVICE -DHAL_DISK_DRIVE_SELECT -DDR_VARBASE=0x6A00 -I . \
    -o $D/hal_build_ds.o src/harness/hal_build.s || exit 1
"$LWASM" --obj -DOBJTARGET -DDR_VARBASE=0x6A00 -I . -o $D/side_check_probe.o src/harness/side_check_probe.s || exit 1
"$LWLINK" --decb --script=link/pop_tile.link --entry=sc_entry --map=$D/side_check.map \
    -o $D/side_check.bin $D/side_check_probe.o $D/hal_build_ds.o || exit 1
ENTRY="0x$(grep -E '^Symbol: sc_entry ' $D/side_check.map | sed -E 's/.*= *//')"

. "$(dirname "$0")/ramsize.sh"
. "$(dirname "$0")/cfgdir.sh"
run() {   # $1 label, $2 drive-0 image, rest = drive-1 arguments
    local label="$1" d0="$2"; shift 2
    cp -f "$d0" $D/run/d0.dmk
    export P_BIN=$D/side_check.bin P_ENTRY="$ENTRY" P_OUT=$D/run/$label.log
    rm -f "$P_OUT"
    "$MAME" coco3 -rompath "$MAME_ROMS" $RAMOPT $CFGOPT -ext fdc -flop1 $D/run/d0.dmk "$@" \
        -video none -sound none -nothrottle -seconds_to_run 400 \
        -autoboot_script harness/tools/side_check.lua >/dev/null 2>&1
    echo "== $label"
    cat "$P_OUT" 2>/dev/null || echo "NO LOG"
}
w() { cp -f "$1" $D/run/d1.dmk; echo "-flop2 $D/run/d1.dmk"; }
A=build/p522/side_a.dmk; B=build/p522/side_b.dmk
# Jay's four cases (drive 0 = side A throughout), and the flipped single drive
run right       $A $(w $B)
run wrong       $A $(w $D/disks/karateka_boot.dmk)
run empty       $A
run nodrive     $A -ext:fdc:wd17xx:1 ""
run flipped     $B -ext:fdc:wd17xx:1 ""
# uniqueness: everything else a player might have in drive 1
for x in blank_unformatted decb_empty random_decb side_a karateka_game pop_probe; do
    run "u_$x" $A $(w $D/disks/$x.dmk)
done
