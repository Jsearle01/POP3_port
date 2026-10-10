#!/bin/bash
# harness/smoke/run_kidrun_test.sh
#
# POP P5.31 — THE KID RUNS: one step of the run, captured and compared byte for byte.
#
#   harness/smoke/run_kidrun_test.sh N      (N = the step to stop after; default 16 -- P5.32)
#
# LOADM"KIDRUN" + EXEC off build/kidrun_gate.dmk (probe.dmk's tracks, KIDRUN.BIN in INTRO.BIN's
# place), with the probe's wk_stop poked to N first: it runs N animation steps -- sequencer,
# per-page peel, transform, foreground pass, VBL flips -- stops before the Nth flip, and tile_probe
# then shows that step on both buffers. The capture is compared with kidrun_plan.py's PREDICTION
# for step N, which has no history at all: anything an earlier step left behind (a peel error) is
# a difference.
#
# ★ A still of one step is NOT the gate (CLAUDE.md §4: motion needs a live run). This checks the
# pixels at a step; run_kidrun_live.sh is what Jay watches.
#
# (Not run_walk_test.sh: that name belongs to the retired P3.31 vizier walk -- retired.sh.)
set -u
cd "$(dirname "$0")/../.." || exit 1

# P5.32: default step 16 -- the kid INSIDE the guard's frame (92 both-opaque cells), the step where the
# per-actor interleave control got 73 bytes wrong. A suite run with no argument is the overlap test.
N="${1:-16}"
MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
SRC_DSK="${SRC_DSK:-build/kidrun_gate.dmk}"
DSK="build/run_kidrun.dmk"
BIN="build/kidrun_probe.bin"
MAP="build/obj/kidrun.map"
LOG="build/kidrun_test.log"
WANT="build/assets/kidrun_ref_${N}.bin"
GOT="build/kidrun_front_${N}.bin"

for f in "$BIN" "$MAP" "$WANT" "$SRC_DSK"; do
    [ -f "$f" ] || { echo "[run_kidrun_test] missing $f — build.bat (kidrun_plan.py --predict includes $N?)"; exit 1; }
done
cp -f "$SRC_DSK" "$DSK" || exit 1
rm -f "$LOG" build/kidrun_test_PASS build/kidrun_test_FAIL "$GOT"

sym() { grep -E "^Symbol: $1 " "$MAP" | sed -E "s/.*= *//"; }
export P_ENGINE="0x$(sym tile_entry)"
export P_CURBACK="0x$(sym HAL_gfx_cur_back)"
export P_CURMODE="0x$(sym HAL_gfx_cur_mode)"
# equ symbols are listed offset by the section base -- see run_tile_test.sh
CODEBASE=$(grep -E "^Symbol: .02code " "$MAP" | sed -E 's/.*= *//')
export P_BLK_A=$(printf '0x%02X' $(( 0x$(sym GFX_DB_A_BLOCK) - 0x$CODEBASE )))
export P_BLK_B=$(printf '0x%02X' $(( 0x$(sym GFX_DB_B_BLOCK) - 0x$CODEBASE )))
export P_WANT_ENTS=$(python -c "print(open('build/assets/tile_page.raw','rb').read(4)[3])")
export P_OUT="$LOG" P_DUMP="$GOT" P_FILE="KIDRUN" P_MARK="build/kidrun_test"
# ★ P5.31b: KIDRUN.BIN IS THE LOADER (src/boot/kidrun_boot.s), ~1.3 KB, and the probe comes off raw
# tracks AFTER EXEC. So the LOADM settle is the loader's, and the run limit carries the reads.
# (P5.31's 18,460 B LOADM measured 1,206 frames; an earlier "53 s" here misread a CRASH -- the
# lz_unpack overrun -- as a slow load. Jay: "it does not take 53 sec to load.")
export P_SETTLE="${P_SETTLE:-600}"
export P_RUN_LIMIT="${P_RUN_LIMIT:-1500}"
# the stop word is the LOADER's: the probe's own wk_stop is inside read A and would be overwritten
KBMAP="build/obj/kidboot.map"
export P_POKE16="$(grep -E "^Symbol: kr_stop " "$KBMAP" | sed -E "s/.*= *//")=$N"
SHOT="build/kidrun_step${N}.png"
export P_PAL="build/kidrun_palette.bin"

. "$(dirname "$0")/ramsize.sh"
. "$(dirname "$0")/cfgdir.sh"
echo "[run_kidrun_test] step $N, $MAME_RAM, stop word kr_stop at \$${P_POKE16%%=*} (copied to wk_stop \$$(sym wk_stop))"

"$MAME" coco3 -rompath "$MAME_ROMS" $RAMOPT $CFGOPT -ext fdc -flop1 "$DSK" -video none \
    -nothrottle -sound none -seconds_to_run 90 \
    -autoboot_script harness/smoke/tile_test.lua >/dev/null 2>&1

grep -E "terminal|VERDICT|poked| FAIL" "$LOG" 2>/dev/null | sed 's/^/  /'
[ -f build/kidrun_test_PASS ] || { echo "[run_kidrun_test] FAIL (in-emulator checks)"; exit 1; }
python harness/tools/fb_compare.py --want "$WANT" --got "$GOT" --label "kid run, step $N, vs PREDICTED"
rc=$?
# P5.32: P3.32's discriminating test -- the guard's frame and the overlapped cells, byte by byte
META="build/assets/kidrun_ref_${N}.json"
if [ -f "$META" ]; then
    python harness/tools/kidrun_overlap.py --want "$WANT" --got "$GOT" --meta "$META" || rc=1
fi
python harness/tools/render_fb.py "$GOT" -o "$SHOT" --bpp 2 --scale 3 --palette-file "$P_PAL" >/dev/null \
    && echo "[run_kidrun_test] PNG for Jay: $SHOT"
[ $rc -eq 0 ] && echo "[run_kidrun_test] PASS" || echo "[run_kidrun_test] FAIL (framebuffer comparison)"
exit $rc
