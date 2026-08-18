#!/bin/bash
# harness/smoke/run_oracle_scene.sh — P4.9: reach a named point in the oracle.
#
# ★★★ THE md5 IS CHECKED HERE, AND IT WAS NOT CHECKED ANYWHERE BEFORE. The dispatch said
# "the oracle's disk md5 is already verified at run time"; it was not — no runner, tool or
# script in this repo hashed it. `mame-idioms-apple2e-oracle.md` records the reference md5
# in prose and nothing consulted it. A scene index is a checker of sorts, and an index tied
# to an unverified reference is exactly the stale-checker shape this project has hit five
# times, so the tie is made real here rather than asserted.
#
#   P_SCENE   princess | demo | skip
#   P_SAVE    write a MAME save state once the scene is reached
#   P_SECS    emulated seconds to allow
#
# ORACLE SOURCE IS READ-ONLY: the .hdv is copied to build/ and the emulator writes to the
# copy, so no run can mutate the reference image.
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
HDV="oracle/source/PrinceOfPersia_3.5.hdv"
SCENE="${P_SCENE:-demo}"
# ★ PER-SCENE SCRATCH. A shared name made two concurrent runs fight over the same file
# ("Device or resource busy"), which is the kind of harness defect that reads as an oracle
# failure. Each scene gets its own copy.
SCRATCH="build/oracle_scene_${SCENE}.hdv"
SECS="${P_SECS:-200}"
STATEDIR="build/oracle_states"

# ★ THE ANCHOR. 148 reports have compared the port against THIS image.
ORACLE_MD5="c4f0b13e49b77dd0fbc5063e27e53a24"

[ -f "$HDV" ] || { echo "[scene] missing $HDV"; exit 1; }
got=$(md5sum "$HDV" | cut -d' ' -f1)
if [ "$got" != "$ORACLE_MD5" ]; then
    echo "[scene] ★★★ ORACLE md5 MISMATCH"
    echo "[scene]   expected $ORACLE_MD5"
    echo "[scene]   got      $got"
    echo "[scene] Every entry in the scene index was derived against the expected image."
    echo "[scene] A changed oracle INVALIDATES the index; it does not merely shift it."
    exit 1
fi
echo "[scene] oracle md5 $got — matches the anchor"

if ! "$MAME" -rompath "$MAME_ROMS" -verifyroms a2cffa02 2>&1 | grep -q "is good"; then
    echo "[scene] a2cffa02.zip missing from $MAME_ROMS — the CFFA2 card needs it"
    exit 1
fi
cp -f "$HDV" "$SCRATCH" || exit 1
mkdir -p build/tmp "$STATEDIR"

export P_SCENE="$SCENE"
export P_STATE="${P_STATE:-}"
STATEOPT=""
[ -n "${P_STATE:-}" ] && STATEOPT="-state ${P_STATE}"
export P_OUT="${P_OUT:-build/tmp/oracle_scene_$SCENE.log}"
rm -f "$P_OUT"

echo "[scene] $SCENE — ${SECS}s emulated, headless"
"$MAME" apple2e \
    -rompath "$MAME_ROMS" \
    -sl7 cffa202 \
    -hard1 "$(pwd -W)/$SCRATCH" \
    -state_directory "$STATEDIR" $STATEOPT \
    -nothrottle -video none -sound none \
    -seconds_to_run "$SECS" \
    -autoboot_script harness/tools/oracle_scene.lua >/dev/null 2>&1

echo "[scene] --- $P_OUT ---"
if [ -f "$P_OUT" ]; then sed 's/^/  /' "$P_OUT"; else echo "  (no log produced)"; exit 1; fi

rc=0
grep -q "^# PASS" "$P_OUT" || { echo "[scene] DID NOT REACH IT"; rc=1; }
echo "[scene] --------------------------------"
[ $rc -eq 0 ] && echo "[scene] OK" || echo "[scene] FAIL"
exit $rc
