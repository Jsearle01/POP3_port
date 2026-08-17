#!/bin/bash
# harness/smoke/run_cel_test.sh — POP P1.2 cel colour spot-check runner.
#
# Builds a converted POP cel into src/harness/cel_probe.s, boots it in
# `mame coco3` through the P1.1 harness, reads the framebuffer back, and checks
# the on-screen palette indices against the converter's output byte for byte.
#
# Usage:  harness/smoke/run_cel_test.sh <cel_dir>
#   e.g.  harness/smoke/run_cel_test.sh content/kid/kid_chtab1_064_thin
#
# What it proves: converter output == what the GIME displays.
# What it does NOT prove: that those colours are RIGHT. That is Jay's eye
# (CLAUDE.md §4). The script reports the palette histogram; it does not judge.
set -u

. "$(dirname "$0")/retired.sh"
retired "P1.2 cel colour spot-check — converter output against on-screen palette indices" \
        "room's flame-pixel check (78 bytes byte-identical against cel 3/8) and walk's verify_room_chars composite diff across 28 captures — the same check over far more cels"

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

CEL_DIR="${1:-content/kid/kid_chtab1_064_thin}"
MAME="${MAME:-/c/mame/mame}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
LWASM="${LWASM:-/c/WIN_LWTools/lwasm}"

if [ ! -f "$CEL_DIR/converted.s" ]; then
    echo "[run_cel_test] ERROR: $CEL_DIR/converted.s not found" >&2; exit 1
fi

mkdir -p build
LOG=build/cel_test.log; PASS=build/cel_test_PASS; FAIL=build/cel_test_FAIL
rm -f "$PASS" "$FAIL" "$LOG"

echo "[run_cel_test] cel: $CEL_DIR"

# ---------------------------------------------------------------------------
# ORIENTATION GUARD (P1.2-fix). Runs BEFORE the framebuffer check, because the
# framebuffer check structurally cannot see a vertical flip: it compares the
# framebuffer to the converter's output, and both are downstream of the
# converter, so a consistent flip round-trips clean. It passed 1152/1152 pixels
# on cels that were upside down; Jay's eye caught it, not the bytes.
# This guard compares against the ORIGINAL POP cel binary instead.
# Skipped (not failed) for synthetic cels with no ORIGIN header.
if ! python harness/tools/verify_orientation.py "$CEL_DIR"; then
    echo "[run_cel_test] FAIL — orientation guard rejected $CEL_DIR" >&2
    exit 1
fi

# One home for the cel choice: this generated include (src/harness/cel_probe.s
# includes it). lwasm resolves `include` relative to the SOURCE dir, not the CWD,
# so the assemble below passes `-I .` to make repo-relative paths work.
printf '                include "%s/converted.s"\n' "$CEL_DIR" > build/cel_include.s

"$LWASM" --decb -I . -o build/cel_probe.bin src/harness/cel_probe.s || {
    echo "[run_cel_test] ERROR: assembly failed" >&2; exit 1; }
echo "[run_cel_test] built build/cel_probe.bin ($(wc -c < build/cel_probe.bin) bytes)"

# Expected framebuffer content, straight from converted.s via the canonical
# reader (sprite_tool/celio) — NOT a second ad-hoc parser.
python - "$CEL_DIR" > build/cel_expect.txt <<'PYEOF'
import sys, pathlib
sys.path.insert(0, "harness/tools/sprite_tool")
from celio import Cel
cel = Cel(str(pathlib.Path(sys.argv[1]) / "converted.s"))
print(f"{cel.h} {cel.w}")
for r in range(cel.h):
    print(" ".join(str(b) for b in cel.row_bytes(r)))
PYEOF
echo "[run_cel_test] expected: $(head -1 build/cel_expect.txt) (rows bytes)"

export P_BIN=build/cel_probe.bin P_EXPECT=build/cel_expect.txt
export P_OUT="$LOG" P_PASS="$PASS" P_FAIL="$FAIL"

# ★ 128 KB, THE TARGET (CLAUDE.md §2K), THROUGH THE ONE HOME FOR THAT FACT. P3.98 swept
# the runners onto ramsize.sh and MISSED THIS ONE AND run_compiled_test.sh — they carried
# no -ramsize at all, so they ran at MAME's coco3 default. A sweep that leaves two files
# behind restores exactly the condition it was written to end: a policy and a default that
# disagree. Found by grepping for the file that is supposed to be sourced, which is the
# check that catches this and re-reading the policy is not.
. "$(dirname "$0")/ramsize.sh"

"$MAME" coco3 \
    -rompath "$MAME_ROMS" \
    $RAMOPT \
    -cfg_directory dist/mame-cfg/rgb \
    -ext fdc \
    -window -nomaximize \
    -nothrottle -sound none \
    -seconds_to_run 30 \
    -autoboot_script harness/smoke/cel_test.lua \
    >/dev/null 2>&1

echo "[run_cel_test] --- verifier log ---"
if [ -f "$LOG" ]; then sed 's/^/  /' "$LOG"; else echo "  (no log produced)"; fi
echo "[run_cel_test] --------------------"

if [ -f "$PASS" ]; then echo "[run_cel_test] PASS"; exit 0
else echo "[run_cel_test] FAIL"; [ -f "$FAIL" ] && sed 's/^/  /' "$FAIL"; exit 1; fi
