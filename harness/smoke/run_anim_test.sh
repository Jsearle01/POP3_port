#!/bin/bash
# harness/smoke/run_anim_test.sh
#
# POP CoCo3 — P2.6 double-buffered animation test.
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
DSK="build/run_anim.dmk"
BIN="build/anim_probe.bin"
LOG="build/anim_test.log"
PASS="build/anim_test_PASS"
FAIL="build/anim_test_FAIL"

[ -f "$SRC_DSK" ] || { echo "[run_anim_test] missing $SRC_DSK — run build.bat first"; exit 1; }
[ -f "$BIN" ] || { echo "[run_anim_test] missing $BIN — run build.bat first"; exit 1; }

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

echo "[run_anim_test] POP CoCo3 P2.6 double-buffered animation test"
echo "[run_anim_test] stages: 16c -> 4c -> 16c -> 4c animated, then a NO-SWAP contrast stage"

# Lua reads its parameters from the environment; paths use FORWARD SLASHES —
# a backslash in a Lua string is an invalid escape and the script dies silently
# with MAME running the full duration and no output (idiom §12).
export P_BIN="$BIN"
export P_OUT="$LOG"
export P_PASS="$PASS"
export P_FAIL="$FAIL"

"$MAME" coco3 \
    -rompath "$MAME_ROMS" \
    -cfg_directory dist/mame-cfg/rgb \
    -ext fdc \
    -flop1 "$DSK" \
    -window -nomaximize \
    -nothrottle -sound none \
    -seconds_to_run 260 \
    -autoboot_script harness/smoke/anim_test.lua \
    >/dev/null 2>&1

echo "[run_anim_test] --- verifier log ---"
if [ -f "$LOG" ]; then sed 's/^/  /' "$LOG"; else echo "  (no log produced)"; fi
echo "[run_anim_test] --------------------"

if [ -f "$PASS" ]; then
    echo "[run_anim_test] PASS"
    exit 0
else
    echo "[run_anim_test] FAIL"
    [ -f "$FAIL" ] && sed 's/^/  /' "$FAIL"
    exit 1
fi
