#!/bin/bash
# harness/smoke/run_kidrun_cycles.sh — P5.31: cycles per animation step of the running kid, by
# phase (sequencer, peel restore, save, draw, foreground), off the built binary via the debugger's
# totalcycles. Headless, LOADM path. Writes build/kidrun_cycles.log; harness/tools/kidrun_cost.py
# summarises it.
set -u
cd "$(dirname "$0")/../.." || exit 1
MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
MAP="build/obj/kidrun.map"
cp -f build/kidrun_gate.dmk build/run_kidrun_cyc.dmk || exit 1
for n in wk_t_seq wk_t_erase wk_t_save wk_t_draw wk_t_fore wk_t_end wk_steps wk_frame wk_x wk_k probe_status; do
    export "S_$n=$(grep -E "^Symbol: $n " "$MAP" | sed -E 's/.*= *//')"
done
export P_OUT="build/kidrun_cycles.log" P_NSTEPS="${P_NSTEPS:-50}"
. "$(dirname "$0")/ramsize.sh"
. "$(dirname "$0")/cfgdir.sh"
"$MAME" coco3 -rompath "$MAME_ROMS" $RAMOPT $CFGOPT -ext fdc -flop1 build/run_kidrun_cyc.dmk \
    -video none -sound none -nothrottle -debug -debugger none -seconds_to_run 600 \
    -autoboot_script harness/tools/kidrun_cycles.lua >/dev/null 2>&1
tail -3 build/kidrun_cycles.log
