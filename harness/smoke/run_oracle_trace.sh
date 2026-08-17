#!/bin/bash
# harness/smoke/run_oracle_trace.sh — run a Lua trace against the ORACLE, headless.
#
# The mount is the POP-verified one from mame-idioms-apple2e-oracle.md §0: an 800K ProDOS
# .hdv on a CFFA2 in slot 7, with the 6502-firmware card variant (cffa202, NOT cffa2 —
# that one needs an enhanced //e). a2cffa02.zip in the rompath is a HARD PREREQUISITE; the
# card carries its own firmware and MAME dies before boot without it.
#
# ORACLE SOURCE IS READ-ONLY (CLAUDE.md §2G-adjacent): the .hdv is COPIED to build/ and the
# emulator writes to the copy, so a trace can never mutate the reference image.
#
# P_LUA   the script to run          P_OUT   where it writes
# P_SECS  emulated seconds to run    (the cutscene starts ~45 s in and Vexit is ~90 s)
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
HDV="oracle/source/PrinceOfPersia_3.5.hdv"
SCRATCH="build/oracle_trace.hdv"
LUA="${P_LUA:-harness/tools/oracle_exit_stride.lua}"
SECS="${P_SECS:-150}"

[ -f "$HDV" ] || { echo "[oracle_trace] missing $HDV"; exit 1; }
if ! "$MAME" -rompath "$MAME_ROMS" -verifyroms a2cffa02 2>&1 | grep -q "is good"; then
    echo "[oracle_trace] a2cffa02.zip missing from $MAME_ROMS — the CFFA2 card needs it"
    exit 1
fi
cp -f "$HDV" "$SCRATCH" || exit 1
mkdir -p build/tmp

echo "[oracle_trace] $LUA — headless, ${SECS}s emulated"
"$MAME" apple2e \
    -rompath "$MAME_ROMS" \
    -sl7 cffa202 \
    -hard1 "$(pwd -W)/$SCRATCH" \
    -nothrottle -video none -sound none \
    -seconds_to_run "$SECS" \
    -autoboot_script "$LUA" >/dev/null 2>&1

echo "[oracle_trace] --- ${P_OUT:-build/tmp/oracle_exit_stride.log} ---"
cat "${P_OUT:-build/tmp/oracle_exit_stride.log}" 2>/dev/null | head -60
