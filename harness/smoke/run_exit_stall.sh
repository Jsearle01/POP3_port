#!/bin/bash
# harness/smoke/run_exit_stall.sh — P3.101: attribute (or fail to attribute) the 10-block.
#
# The port's exit walk holds each cel a modal 8 frames and holds ten consecutive cels for
# 10 between f4702 and f4802. This counts loop iterations per frame across that window,
# because the achieved step interval IS the iteration rate [char_draw.s:1993-2009].
#
# Control first, and the control is a real one: forcing `ch_anymove` on makes every frame
# peel, which is strictly more work, so the counter must fall. A counter that does not move
# when the work doubles is not counting work.
#
# 128 KB, the target, through the one home. Launch path live-disk.
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
SRC_DSK="build/probe.dmk"
DSK="build/run_exit_stall.dmk"

[ -f "build/obj/room.map" ] || { echo "[exit_stall] run build.bat first"; exit 1; }
cp -f "$SRC_DSK" "$DSK" || exit 1
mkdir -p build/tmp

. "$(dirname "$0")/ramsize.sh"
echo "[exit_stall] $RAMOPT"

run() {   # $1 = tag
    export P_OUT="build/tmp/port_exit_stall_$1.log"
    rm -f "$P_OUT"
    "$MAME" coco3 \
        -rompath "$MAME_ROMS" \
        $RAMOPT \
        -cfg_directory dist/mame-cfg/rgb \
        -ext fdc -flop1 "$DSK" \
        -window -nomaximize -nothrottle -sound none \
        -seconds_to_run 160 \
        -autoboot_script harness/tools/port_exit_stall.lua \
        >/dev/null 2>&1
    echo "[exit_stall] --- $1 : $P_OUT ---"
    if [ -f "$P_OUT" ]; then sed 's/^/  /' "$P_OUT"; else echo "  (no log produced)"; return 1; fi
}

rc=0
P_SEED=1 run seeded || rc=1
P_SEED=0 run measure || rc=1

# The control is a COMPARISON between the two runs, so it is checked here rather than
# inside the Lua: suppressing the peel is strictly less work, so the rate must RISE.
# ★ It was written the other way round first — forcing the peel ON — and `ch_anymove` is
# already 1 on every frame of this window, so the substitution wrote a value the target
# already held. No change followed, and the run reported that as a failure OF THE COUNTER.
s=$(grep -m1 "^# BEFORE the 10-block" build/tmp/port_exit_stall_seeded.log  2>/dev/null | grep -oE '[0-9]+\.[0-9]+ it/f' | grep -oE '^[0-9.]+')
m=$(grep -m1 "^# BEFORE the 10-block" build/tmp/port_exit_stall_measure.log 2>/dev/null | grep -oE '[0-9]+\.[0-9]+ it/f' | grep -oE '^[0-9.]+')
echo "[exit_stall] --------------------------------"
if [ -n "$s" ] && [ -n "$m" ]; then
    echo "[exit_stall] iteration rate: unseeded $m it/f, peel-suppressed $s it/f"
    if grep -q "^# SEED INEFFECTIVE" build/tmp/port_exit_stall_seeded.log; then
        echo "[exit_stall] SEED INEFFECTIVE — a verdict on the seed, not on the counter."
        rc=1
    elif awk -v a="$s" -v b="$m" 'BEGIN{exit !(a > b + 0.01)}'; then
        echo "[exit_stall] CONTROL PASSED: suppressing the peel raised the counter — it counts work."
    else
        echo "[exit_stall] CONTROL FAILED: the counter did not rise when the work fell (P3.48b)."
        rc=1
    fi
else
    echo "[exit_stall] CONTROL FAILED: could not read both iteration rates."
    rc=1
fi
[ $rc -eq 0 ] && echo "[exit_stall] OK" || echo "[exit_stall] FAIL"
exit $rc
