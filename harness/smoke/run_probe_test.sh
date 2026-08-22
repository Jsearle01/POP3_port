#!/bin/bash
# harness/smoke/run_probe_test.sh — POP CoCo3 P1.1 loop-probe test runner.
#
# The TEST half of the CLAUDE.md §1 contract (25.1 = build.bat + run_*_test).
# Boots build/probe.dmk in `mame coco3`, drives DECB to LOADM+EXEC the probe,
# verifies its observables against a spec, prints PASS/FAIL.
#
# Usage:
#   harness/smoke/run_probe_test.sh                    # spec as built  -> PASS
#   harness/smoke/run_probe_test.sh --expect-vbls 999  # wrong spec     -> FAIL
#   harness/smoke/run_probe_test.sh --mode direct      # skip DECB; poke + set PC
#
# Modes:
#   disk   (default) DECB LOADM"PROBE" + EXEC via natkeyboard:post. This is the
#          path the shipped game boots through, so it is the one that matters.
#          [idiom §1 no autoboot; §2 natkeyboard:post]
#   direct Lua parses the DECB binary, pokes it in, sets PC. Faster and immune
#          to DECB typing latency; this is the mode the later oracle-comparison
#          framebuffer dumps will use. Cross-check, not a replacement.
#
# Env overrides: MAME (binary), MAME_ROMS (rompath).
set -u

. "$(dirname "$0")/retired.sh"
retired "the P1.1 loop probe — that the HAL harness boots and its observables hold" \
        "room and walk both boot live-disk through the same HAL, so a broken HAL fails them first"

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

MAME="${MAME:-/c/mame/mame}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"

MODE="disk"
EXPECT_VBLS=120
EXPECT_A=27         # $1B
EXPECT_B=228        # $E4

while [ $# -gt 0 ]; do
    case "$1" in
        --mode)         MODE="$2";        shift 2 ;;
        --expect-vbls)  EXPECT_VBLS="$2"; shift 2 ;;
        --expect-a)     EXPECT_A="$2";    shift 2 ;;
        --expect-b)     EXPECT_B="$2";    shift 2 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done

SRC_DSK="build/probe.dmk"
DSK="build/run_probe.dmk"
BIN="build/loop_probe.bin"
LOG="build/probe_test.log"
PASS="build/probe_test_PASS"
FAIL="build/probe_test_FAIL"

if [ ! -f "$SRC_DSK" ] || [ ! -f "$BIN" ]; then
    echo "[run_probe_test] ERROR: $SRC_DSK / $BIN missing — run build.bat first." >&2
    exit 1
fi

# MOUNT A SCRATCH COPY, NEVER build/probe.dmk ITSELF. MAME opens a floppy
# READ-WRITE and JVC images save back, so a guest that touches the disk -- or an
# exit taken mid-FDC-operation -- rewrites the built artifact. That happened in
# P3.3: after a run of diagnostic sessions the image came back "Corrupt image"
# from imgtool and every LOADM test failed, with nothing wrong in any of them.
# The standing idiom already says it (§3: ".dsk fixtures are throwaway --
# generate per-task, don't share"); this is that rule enforced in the runner
# rather than remembered.
cp -f "$SRC_DSK" "$DSK" || exit 1

rm -f "$PASS" "$FAIL" "$LOG"

echo "[run_probe_test] POP CoCo3 P1.1 loop-probe test"
echo "[run_probe_test] mode=$MODE  spec: vbls=$EXPECT_VBLS fillA=$EXPECT_A fillB=$EXPECT_B"

# Lua reads its parameters from the environment. Paths use FORWARD SLASHES —
# a backslash in a Lua string is an invalid escape and the script dies
# SILENTLY, with MAME running the full duration and no output (idiom §12).
export P_MODE="$MODE"
export P_BIN="$BIN"
export P_OUT="$LOG"
export P_PASS="$PASS"
export P_FAIL="$FAIL"
export P_EXPECT_VBLS="$EXPECT_VBLS"
export P_EXPECT_A="$EXPECT_A"
export P_EXPECT_B="$EXPECT_B"

# -seconds_to_run is EMULATED seconds, not wall-clock (idiom §12).
# The Lua exits the machine itself as soon as it has a verdict; this is a cap.
# `-ext fdc` is MANDATORY. A bare `coco3` has NO disk controller: it boots to
# Extended Color BASIC, LOADM does nothing, and the probe silently never runs
# (observed here as status=0, PC=$CFFD). idiom §12's quick-command line omits
# it; karateka docs/project/disk-boot-decb-overlap.md:67 has the correct form.
# disk11.rom (Disk Extended Color BASIC) ships inside coco3.zip.
# MAME_RAM=128K runs this on a 128 KB CoCo3. The framebuffer blocks are chosen
# so both sizes work (P3.10): the GIME masks a block number to the RAM actually
# installed, so on 128 KB every number aliases mod 16, and buffer B at $18 used
# to land straight on top of the program. Default is MAME 512K.
# ONE HOME for which machine this runs on: 128 KB, the target (CLAUDE.md 2K).
. "$(dirname "$0")/ramsize.sh"
. "$(dirname "$0")/cfgdir.sh"

"$MAME" coco3 \
    -rompath "$MAME_ROMS" \
    $RAMOPT \
    $CFGOPT \
    -ext fdc \
    -flop1 "$DSK" \
    -window -nomaximize \
    -nothrottle -sound none \
    -seconds_to_run 30 \
    -autoboot_script harness/smoke/probe_test.lua \
    >/dev/null 2>&1

echo "[run_probe_test] --- verifier log ---"
if [ -f "$LOG" ]; then sed 's/^/  /' "$LOG"; else echo "  (no log produced)"; fi
echo "[run_probe_test] --------------------"

if [ -f "$PASS" ]; then
    echo "[run_probe_test] PASS"
    exit 0
else
    echo "[run_probe_test] FAIL"
    [ -f "$FAIL" ] && sed 's/^/  /' "$FAIL"
    exit 1
fi
