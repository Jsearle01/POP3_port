#!/bin/bash
# harness/smoke/run_oracle_live.sh
#
# THE ORACLE, LIVE AND AT REAL SPEED — for Jay's eye, beside the port.
#
# The mount is the POP-VERIFIED one from mame-idioms-apple2e-oracle.md §0, the single
# section of that file the inherited-unverified banner does NOT cover:
#
#     mame apple2e -sl7 cffa202 -hard1 <abs>/PrinceOfPersia_3.5.hdv
#
#   * a2cffa02.zip in the rompath is a HARD PREREQUISITE — the CFFA2 card carries its own
#     firmware and MAME dies before boot without it. Checked below, because a missing
#     device ROM is fatal-before-boot and therefore invisible to any check that only
#     looks at the media path.
#   * cffa202 (6502 firmware), NOT cffa2 (65C02, needs an enhanced //e).
#   * NOT -flop1: that is Karateka's 5.25" mount and the wrong media class. POP's oracle
#     is an 800K 3.5" ProDOS volume on hard1, and .hdv is natively accepted.
#   * hard1 does not exist on a bare apple2e — the instance materialises only once the
#     CFFA2 card occupies a slot.
#
# THROTTLED ON PURPOSE (no -nothrottle). The whole point is the PACE, so it has to run at
# 100%. A scratch copy is used even though a windowed run was measured not to write the
# image back (idioms §0) — cheap insurance on the graded artefact.
#
# ★ TIMING, so nothing is missed. From boot:
#     ~45 s   the princess's room appears
#     ~58 s   PALERT — she hears the door and turns. 43 frames, 0.72 s. It is quick.
#     ~78 s   the vizier approaches and stops
#   Measured at P3.72d: her turn is f3487-f3530, his approach a steady 6 frames/step.
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
HDV="oracle/source/PrinceOfPersia_3.5.hdv"
SCRATCH="build/oracle_live.hdv"

[ -f "$HDV" ] || { echo "[oracle_live] missing $HDV"; exit 1; }
if ! "$MAME" -rompath "$MAME_ROMS" -verifyroms a2cffa02 2>&1 | grep -q "is good"; then
    echo "[oracle_live] a2cffa02.zip missing from $MAME_ROMS — the CFFA2 card needs it"
    echo "[oracle_live] and MAME will die before boot. See idioms §0."
    exit 1
fi
cp -f "$HDV" "$SCRATCH" || exit 1

echo "[oracle_live] Prince of Persia, Apple IIe, 800K ProDOS on a CFFA2 in slot 7."
echo "[oracle_live] REAL SPEED — this is the pace reference."
echo "[oracle_live]   ~45 s  the princess's room appears"
echo "[oracle_live]   ~58 s  PALERT — she turns to the door. 0.72 s; it goes by fast."
echo "[oracle_live]   ~78 s  the vizier approaches and stops"
echo "[oracle_live] close the window when you are done."

"$MAME" apple2e \
    -rompath "$MAME_ROMS" \
    -sl7 cffa202 \
    -hard1 "$(pwd -W)/$SCRATCH" \
    -window -nomaximize -prescale 3 \
    -sound none
