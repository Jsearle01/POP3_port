#!/bin/bash
# harness/smoke/run_mode_test.sh
#
# POP CoCo3 — P2.5 mode-cycling test.
#
# Boots build/probe.dsk in `mame coco3`, drives DECB to LOADM"MODE" + EXEC, and
# captures the four mode-switch stages (16 -> 4 -> 16 -> 4).
#
# Corroborates the HAL's published geometry and the on-screen bar pattern, and
# dumps each stage's framebuffer for offline 1:1 rendering. It does NOT certify
# colour — that is Jay's eye on a live RGB run (CLAUDE.md §4).
#
# `-ext fdc` is MANDATORY: a bare coco3 has no disk controller, LOADM does
# nothing, and the probe silently never runs (idiom §12 / P1.1).
# `-cfg_directory dist/mame-cfg/rgb` forces Monitor Type = RGB; MAME's own
# default is Composite, in which the same palette byte is a different colour.
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"

DSK="build/probe.dsk"
BIN="build/mode_probe.bin"
LOG="build/mode_test.log"
PASS="build/mode_test_PASS"
FAIL="build/mode_test_FAIL"
DUMP="build/mode_dumps"

[ -f "$DSK" ] || { echo "[run_mode_test] missing $DSK — run build.bat first"; exit 1; }
[ -f "$BIN" ] || { echo "[run_mode_test] missing $BIN — run build.bat first"; exit 1; }

rm -f "$LOG" "$PASS" "$FAIL"
rm -rf "$DUMP"; mkdir -p "$DUMP"

echo "[run_mode_test] POP CoCo3 P2.5 mode-cycling test"
echo "[run_mode_test] stages: 16-colour -> 4-colour -> 16-colour -> 4-colour"

# Lua reads its parameters from the environment; paths use FORWARD SLASHES —
# a backslash in a Lua string is an invalid escape and the script dies silently
# with MAME running the full duration and no output (idiom §12).
export P_BIN="$BIN"
export P_OUT="$LOG"
export P_DUMP="$DUMP"
export P_PASS="$PASS"
export P_FAIL="$FAIL"

"$MAME" coco3 \
    -rompath "$MAME_ROMS" \
    -cfg_directory dist/mame-cfg/rgb \
    -ext fdc \
    -flop1 "$DSK" \
    -window -nomaximize \
    -nothrottle -sound none \
    -seconds_to_run 60 \
    -autoboot_script harness/smoke/mode_test.lua \
    >/dev/null 2>&1

echo "[run_mode_test] --- verifier log ---"
if [ -f "$LOG" ]; then sed 's/^/  /' "$LOG"; else echo "  (no log produced)"; fi
echo "[run_mode_test] --------------------"

if [ -f "$PASS" ]; then
    echo "[run_mode_test] PASS"
    exit 0
else
    echo "[run_mode_test] FAIL"
    [ -f "$FAIL" ] && sed 's/^/  /' "$FAIL"
    exit 1
fi
