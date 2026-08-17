#!/bin/bash
# harness/smoke/run_iter_cost.sh — P3.102 §1/AC1.
#
# Does the port's exit iteration cost more than its entry iteration, even though the
# achieved step rate is flat? The rate is quantised to whole frames and cannot show a 7%
# change; the iteration's WORK is not quantised and can.
#
# Control FIRST, and it is a real perturbation this time: suppressing the frame-wide peel
# is strictly less work, so measured work must FALL. P3.101's version of this seed forced
# the same flag ON, which it already was — 2,773 writes, nothing perturbed, and the run
# blamed the counter. The Lua now reports how many substitutions CHANGED the value.
#
# 128 KB, the target, through the one home (CLAUDE.md §2K). Launch path live-disk (§4).
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
SRC_DSK="build/probe.dmk"
DSK="build/run_iter_cost.dmk"

[ -f build/obj/room.map ] || { echo "[iter_cost] run build.bat first"; exit 1; }
cp -f "$SRC_DSK" "$DSK" || exit 1
mkdir -p build/tmp

. "$(dirname "$0")/ramsize.sh"
echo "[iter_cost] $RAMOPT"

export P_TO="${P_TO:-5800}"
SECS=$(( (P_TO + 3600) / 60 + 30 ))

run() {   # $1 = tag
    export P_OUT="build/tmp/port_iter_cost_$1.log"
    rm -f "$P_OUT"
    "$MAME" coco3 \
        -rompath "$MAME_ROMS" \
        $RAMOPT \
        -cfg_directory dist/mame-cfg/rgb \
        -ext fdc -flop1 "$DSK" \
        -window -nomaximize -nothrottle -sound none \
        -seconds_to_run $SECS \
        -autoboot_script harness/tools/port_iter_cost.lua \
        >/dev/null 2>&1
    echo "[iter_cost] --- $1 : $P_OUT ---"
    if [ -f "$P_OUT" ]; then sed 's/^/  /' "$P_OUT"; else echo "  (no log produced)"; return 1; fi
}

rc=0
P_SEED=1 run seeded || rc=1
P_SEED=0 run measure || rc=1

work_of() {  # $1 = log, $2 = ENTRY|EXIT
    awk -v h="$2" '$1==h && $2 ~ /^[0-9]+$/ {print $3; exit}' "$1"
}
se=$(work_of build/tmp/port_iter_cost_seeded.log ENTRY)
me=$(work_of build/tmp/port_iter_cost_measure.log ENTRY)

echo "[iter_cost] --------------------------------"
if grep -q "the seed did not land" build/tmp/port_iter_cost_seeded.log 2>/dev/null; then
    echo "[iter_cost] SEED DID NOT LAND — a verdict on the seed, not on the instrument."
    rc=1
elif [ -z "$se" ] || [ -z "$me" ]; then
    echo "[iter_cost] CONTROL FAILED: could not read both ENTRY work figures."
    rc=1
else
    echo "[iter_cost] ENTRY work/iteration: unseeded $me ms, peel-suppressed $se ms"
    if awk -v a="$se" -v b="$me" 'BEGIN{exit !(a < b * 0.95)}'; then
        echo "[iter_cost] CONTROL PASSED: suppressing the peel cut measured work — it measures work."
    else
        echo "[iter_cost] CONTROL FAILED: work did not fall when the work fell (P3.48b)."
        rc=1
    fi
fi
[ $rc -eq 0 ] && echo "[iter_cost] OK" || echo "[iter_cost] FAIL"
exit $rc
