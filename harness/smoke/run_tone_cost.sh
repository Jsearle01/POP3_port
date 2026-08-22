#!/bin/bash
# harness/smoke/run_tone_cost.sh — P4.2 §2: the one measurement.
#
# What does a tone cost per frame, in each of the two architectures the sound design forks
# on — a GIME-timer FIRQ toggling the DAC, and the oracle's own foreground bit-bang?
#
# ★ MEASURE, DO NOT MODEL. Modelling has lost twice in this project (P3.21 by 2.2x;
# P3.22's 92% prediction against a measured 10.0 Hz), and counted != assembled != executed
# (P3.39, P3.41). So the tone generator is BUILT, run on the machine, and counted.
#
# ★★ IT DOES NOT CLAIM AUDIBILITY. The probe writes the DAC and never touches the PIA
# sound-enable: the CPU cost is the same either way, and whether a sound comes out is
# Jay's ears, not this runner's.
#
# 128 KB, the target, through the one home. Launch path live-disk (CLAUDE.md §4).
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
SRC_DSK="build/probe.dmk"
DSK="build/run_tone.dmk"
MAP="build/obj/tone.map"

[ -f "$MAP" ] || { echo "[tone_cost] missing $MAP — run build.bat first"; exit 1; }
cp -f "$SRC_DSK" "$DSK" || exit 1
mkdir -p build/tmp

# ★★★ TONE.BIN GOES ON THE COPY, NOT ON THE SHIPPING DISK. build.bat put it on
# build/probe.dmk for exactly one build, and DECB allocated its granules over a RESERVED
# cel-page track: the engine's bank guard fired and run_walk_test reported "0 of 19 beats".
# The shipping disk has 13,824 B free and every raw track on it is spoken for, so the
# instrument takes its granules here where nothing else needs them.
IMGTOOL="${IMGTOOL:-/c/mame/imgtool.exe}"
"$IMGTOOL" put coco_dmk_rsdos "$DSK" build/tone_probe.bin TONE.BIN \
    --ftype=binary --ascii=binary >/dev/null 2>&1 \
    || { echo "[tone_cost] could not add TONE.BIN to $DSK"; exit 1; }

sym() { grep -E "^Symbol: $2 " "$1" | sed -E 's/.*= *//'; }

export P_ENTRY="$(sym "$MAP" probe_entry)"
export P_SPIN="$(sym "$MAP" hal_vbl_spin)"
export P_NPHASE=5
export P_OUT="build/tmp/tone_cost.log"

[ -n "$P_ENTRY" ] || { echo "[tone_cost] probe_entry not in $MAP"; exit 1; }
[ -n "$P_SPIN" ]  || { echo "[tone_cost] hal_vbl_spin not in $MAP"; exit 1; }

. "$(dirname "$0")/ramsize.sh"
. "$(dirname "$0")/cfgdir.sh"
echo "[tone_cost] $RAMOPT  probe \$$P_ENTRY  spin \$$P_SPIN"

rm -f "$P_OUT"
"$MAME" coco3 \
    -rompath "$MAME_ROMS" \
    $RAMOPT \
    $CFGOPT \
    -ext fdc -flop1 "$DSK" \
    -window -nomaximize -nothrottle -sound none \
    -seconds_to_run 60 \
    -autoboot_script harness/smoke/tone_cost.lua \
    >/dev/null 2>&1

echo "[tone_cost] --- $P_OUT ---"
if [ -f "$P_OUT" ]; then sed 's/^/  /' "$P_OUT"; else echo "  (no log produced)"; exit 1; fi

rc=0
grep -q "^# CONTROL PASSED" "$P_OUT" || { echo "[tone_cost] CONTROL DID NOT PASS"; rc=1; }
echo "[tone_cost] --------------------------------"
[ $rc -eq 0 ] && echo "[tone_cost] OK" || echo "[tone_cost] FAIL"
exit $rc
