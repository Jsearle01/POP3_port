#!/bin/bash
# harness/smoke/run_engarde_cycles.sh — P5.37 AC14: what one GAME FRAME of the en-garde window costs, by
# phase, off the gate's own binary and disk: the AI (guard_ai.s ga_frame: DoKid + DoShad -- the first LOGIC
# the project has measured), the placement, then P5.32's three passes and the foreground. Headless, LOADM
# path, -debug, the debugger's totalcycles (idiom §41). Writes build/engarde_cycles.log, with the `# CLOCK`
# line the cost tool requires (P5.35: the clock is READ). harness/tools/engarde_cost.py summarises it.
set -u
cd "$(dirname "$0")/../.." || exit 1
MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
MAP="build/obj/engarde.map"
cp -f build/engarde_gate.dmk build/run_engarde_cyc.dmk || exit 1
export P_PH="wk_t_ai wk_t_aiend wk_t_erase wk_t_save wk_t_draw wk_t_fore wk_t_end"
for n in $P_PH wk_steps wk_frame wk_x wk_k probe_status; do
    export "S_$n=$(grep -E "^Symbol: $n " "$MAP" | sed -E 's/.*= *//')"
done
export "S_kr_nact=$(grep -E "^Symbol: kr_nact " build/obj/engardeboot.map | sed -E 's/.*= *//')"
export P_FILE="GUARD" P_OUT="${P_OUT:-build/engarde_cycles.log}" P_NSTEPS="${P_NSTEPS:-38}"
. "$(dirname "$0")/ramsize.sh"
. "$(dirname "$0")/cfgdir.sh"
"$MAME" coco3 -rompath "$MAME_ROMS" $RAMOPT $CFGOPT -ext fdc -flop1 build/run_engarde_cyc.dmk \
    -video none -sound none -nothrottle -debug -debugger none -seconds_to_run 600 \
    -autoboot_script harness/tools/kidrun_cycles.lua >/dev/null 2>&1
tail -3 "$P_OUT"
python harness/tools/engarde_cost.py "$P_OUT"
