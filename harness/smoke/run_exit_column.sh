#!/bin/bash
# harness/smoke/run_exit_column.sh — P3.100 AC1/AC5.
#
# The PORT half of the one measurement P3.100 exists for: the engine's own drawn column,
# full 16 bits, tapped at the `std ch_dest`, for the vizier's six walk cels, split into
# the entry walk and the mirrored exit walk by the engine's own facing.
#
# TWO RUNS, and the second is the point:
#   1. P_SEED=1  the seeded control. The tap is handed a destination the engine itself
#                computed and must report it back, both bytes. A probe must detect its own
#                seeded failure before its silence counts (P3.48b/P3.49).
#   2.           the measurement.
#
# The control runs FIRST. A measurement published ahead of its own control is how three
# instrument faults in two dispatches came to be reported as findings.
#
# 128 KB, the target machine (CLAUDE.md §2K), via the one home for that fact.
# Launch path is live-disk (CLAUDE.md §4): LOADM"ROOM" + EXEC off a mounted floppy.
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
SRC_DSK="build/probe.dmk"
DSK="build/run_exit_column.dmk"
FMAP="build/obj/flames.map"
PACK=content/cutscene/chars/cel_pack.json

[ -f "$FMAP" ] || { echo "[exit_column] missing $FMAP — run build.bat first"; exit 1; }
[ -f "$PACK" ] || { echo "[exit_column] missing $PACK"; exit 1; }
cp -f "$SRC_DSK" "$DSK" || exit 1
mkdir -p build/tmp

# HOW FAR THE SCENE HAS TO RUN, derived from the pack the way run_walk_test.sh derives it
# — never a frame number written here. The exit is the LAST beat, so a short run does not
# under-report the exit, it MISSES it entirely, and a missing exit reads as "no rows".
#
# ★ THE HEADROOM IS NOT DECORATION. The pack's step count ends where the SCHEDULE ends,
# and the walk-out runs on past it — `goto viz_walk2` loops forever, carrying him off the
# right edge. The first run of this stopped at frame 4539 and caught FIVE exit steps, less
# than one cycle of six, which is not enough to see a cycle at all.
export P_TO="${P_TO:-$(python -c "
import json
m = json.load(open('$PACK'))
steps = sum(s['plays'] for s in m['schedule'])
print(steps * 7 + len(m['reads']) * 400 + 2600)")}"
SECS=$(( (P_TO + 3600) / 60 + 30 ))
echo "[exit_column] scene runs to ~frame $P_TO (${SECS}s emulated)"

. "$(dirname "$0")/ramsize.sh"
echo "[exit_column] $RAMOPT"

run() {   # $1 = tag, rest = extra env already exported
    export P_OUT="build/tmp/port_exit_column_$1.log"
    rm -f "$P_OUT"
    "$MAME" coco3 \
        -rompath "$MAME_ROMS" \
        $RAMOPT \
        -cfg_directory dist/mame-cfg/rgb \
        -ext fdc -flop1 "$DSK" \
        -window -nomaximize -nothrottle -sound none \
        -seconds_to_run $SECS \
        -autoboot_script harness/tools/port_exit_column.lua \
        >/dev/null 2>&1
    echo "[exit_column] --- $1 : $P_OUT ---"
    if [ -f "$P_OUT" ]; then sed 's/^/  /' "$P_OUT"; else echo "  (no log produced)"; return 1; fi
}

rc=0
P_SEED=1 P_SEED_AFTER="${P_SEED_AFTER:-40}" run seeded || rc=1
if ! grep -q "^# CONTROL PASSED" build/tmp/port_exit_column_seeded.log 2>/dev/null; then
    echo "[exit_column] SEEDED CONTROL DID NOT PASS — the tap is not an instrument."
    rc=1
fi

P_SEED=0 run measure || rc=1

echo "[exit_column] --------------------------------"
[ $rc -eq 0 ] && echo "[exit_column] OK" || echo "[exit_column] FAIL"
exit $rc
