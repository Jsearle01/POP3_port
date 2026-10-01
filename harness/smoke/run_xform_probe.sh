#!/bin/bash
# harness/smoke/run_xform_probe.sh
#
# POP P5.20 — the shifted and mirrored blit, built as a PROBE and checked against a generated
# reference. Not a suite, not a gate, and not on the shipping disk: build.bat does not
# assemble src/harness/xform_probe.s and nothing in the port links it.
#
#   harness/smoke/run_xform_probe.sh [generator args...]
#
# With no arguments, the dispatch's sample: Apple-1-byte, odd-width and even-width cels,
# chosen so blast segments carry every tail length (0-3) and runs of up to 7 bytes.
# `--all-gameplay` runs every non-empty cel of CHTAB1/2/3/4.GD/5 (the census).
#
# LAUNCH PATH: poke (harness/tools/xform_probe.lua) -- a leaf-routine measurement.
# Cycles come from the debugger's totalcycles, so the machine runs under -debug; headless.
set -u
cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
LWASM="${LWASM:-lwasm}"

if [ $# -eq 0 ]; then
    set -- --cel IMG.CHTAB1:64 --cel IMG.CHTAB3:64 --cel IMG.CHTAB3:32 --cel IMG.CHTAB2:16 \
           --cel IMG.CHTAB4.GD:31 --cel IMG.CHTAB1:65 --cel IMG.CHTAB3:23 --cel IMG.CHTAB4.GD:7
fi

# XF_PREFIX keeps one run's batches from deleting another's: the census is `b`, the shipped
# cross-check (`--shipped p11 --shipped v54`) is conventionally `s`.
XF_PREFIX="${XF_PREFIX:-b}"
python harness/tools/xform_probe_gen.py --out-prefix "$XF_PREFIX" "$@" || exit 1

. "$(dirname "$0")/ramsize.sh"
. "$(dirname "$0")/cfgdir.sh"
echo "[run_xform_probe] ramsize $MAME_RAM"

rc=0
for gen in build/xform/${XF_PREFIX}[0-9][0-9][0-9]_gen.s; do
    b=$(basename "$gen" _gen.s)
    cp -f "$gen" build/xform/xf_gen.s
    "$LWASM" -9 --decb -I . -o "build/xform/xf_$b.bin" --symbol-dump="build/xform/xf_$b.sym" \
        --list="build/xform/xf_$b.lst" src/harness/xform_probe.s || { echo "[run_xform_probe] $b: assembly FAILED"; exit 1; }
    export P_BIN="build/xform/xf_$b.bin" P_SYMS="build/xform/xf_$b.sym" P_OUT="build/xform/$b.log"
    rm -f "$P_OUT"
    "$MAME" coco3 -rompath "$MAME_ROMS" $RAMOPT $CFGOPT -video none -sound none -nothrottle \
        -debug -debugger none -seconds_to_run 3600 \
        -autoboot_script harness/tools/xform_probe.lua >/dev/null 2>&1
    echo "[run_xform_probe] --- $b ---"
    python harness/tools/xform_probe_check.py --cases "build/xform/${b}_cases.json" --log "$P_OUT" || rc=1
done
[ $rc -eq 0 ] && echo "[run_xform_probe] PASS" || echo "[run_xform_probe] FAIL"
exit $rc
