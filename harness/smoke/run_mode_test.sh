#!/bin/bash
# harness/smoke/run_mode_test.sh
#
# POP CoCo3 — P2.5 mode-cycling test.
#
# Boots build/probe.dmk in `mame coco3`, drives DECB to LOADM"MODE" + EXEC, and
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

SRC_DSK="build/probe.dmk"
DSK="build/run_mode.dmk"
BIN="build/mode_probe.bin"
LOG="build/mode_test.log"
PASS="build/mode_test_PASS"
FAIL="build/mode_test_FAIL"
DUMP="build/mode_dumps"

[ -f "$SRC_DSK" ] || { echo "[run_mode_test] missing $SRC_DSK — run build.bat first"; exit 1; }
[ -f "$BIN" ] || { echo "[run_mode_test] missing $BIN — run build.bat first"; exit 1; }

# MOUNT A SCRATCH COPY, NEVER build/probe.dmk ITSELF. MAME opens a floppy
# READ-WRITE and JVC images save back, so a guest that touches the disk -- or an
# exit taken mid-FDC-operation -- rewrites the built artifact. That happened in
# P3.3: after a run of diagnostic sessions the image came back "Corrupt image"
# from imgtool and every LOADM test failed, with nothing wrong in any of them.
# The standing idiom already says it (§3: ".dsk fixtures are throwaway --
# generate per-task, don't share"); this is that rule enforced in the runner
# rather than remembered.
cp -f "$SRC_DSK" "$DSK" || exit 1

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

# MAME_RAM=128K runs this on a 128 KB CoCo3. The framebuffer blocks are chosen
# so both sizes work (P3.10): the GIME masks a block number to the RAM actually
# installed, so on 128 KB every number aliases mod 16, and buffer B at $18 used
# to land straight on top of the program. Default is MAME 512K.
RAMOPT=""
[ -n "${MAME_RAM:-}" ] && RAMOPT="-ramsize $MAME_RAM"

"$MAME" coco3 \
    -rompath "$MAME_ROMS" \
    $RAMOPT \
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
