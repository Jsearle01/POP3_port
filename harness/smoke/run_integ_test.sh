#!/bin/bash
# harness/smoke/run_integ_test.sh — P3.107: the INTEGRATED sequence, end to end.
#
# ★★ THE SUITE THAT LOOKS AT WHAT SHIPS. introseq/room/walk all boot a STANDALONE image;
# the integrated scene is reached by a `jsr` from the intro's beat loop, runs from $2500,
# and returns. "A pass earned in one configuration does not carry to another", and until
# this file the integrated configuration had no suite at all.
#
# Every address comes from the maps of the build that just ran — re-pointed, not re-cited.
# 128 KB, the target, through the one home. Launch path live-disk (CLAUDE.md §4).
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
SRC_DSK="build/probe.dmk"
DSK="build/run_integ.dmk"
IMAP="build/obj/introseq.map"
SMAP="build/obj/scene.map"

[ -f "$IMAP" ] || { echo "[integ] missing $IMAP — run build.bat first"; exit 1; }
[ -f "$SMAP" ] || { echo "[integ] missing $SMAP — run build.bat first"; exit 1; }
cp -f "$SRC_DSK" "$DSK" || exit 1
mkdir -p build/tmp

sym() { grep -E "^Symbol: $2 " "$1" | sed -E 's/.*= *//'; }

export P_ENTRY="$(sym "$IMAP" intro_seq_entry)"
export P_STATUS="$(sym "$IMAP" probe_status)"
export P_BEAT="$(sym "$IMAP" probe_beat)"
export P_RANGE="$(sym "$IMAP" disk_read_range)"
export P_SWAP="$(sym "$IMAP" HAL_gfx_swap)"
export P_DRAWBASE="$(sym "$IMAP" HAL_gfx_draw_base)"
export P_SCENEBASE="$(sym "$SMAP" room_entry)"

# cel_scene_done is CEL_VARBASE+5, and CEL_VARBASE comes out of build.bat — its one home —
# rather than being written here a second time.
CELVAR=$(sed -n 's/^set CEL_VARBASE=\(0x[0-9A-Fa-f]*\).*/\1/p' build.bat | head -1)
[ -n "$CELVAR" ] || { echo "[integ] CEL_VARBASE not found in build.bat"; exit 1; }
export P_DONE=$(printf '%X' $(( CELVAR + 5 )))

# BEAT_COUNT likewise from the source that defines it, not from memory.
export P_NBEATS=$(sed -n 's/^BEAT_COUNT *equ *\([0-9]*\).*/\1/p' src/engine/intro_seq.s | head -1)
export P_TO="${P_TO:-13000}"
SECS=$(( (P_TO + 1200) / 60 + 30 ))

. "$(dirname "$0")/ramsize.sh"
echo "[integ] $RAMOPT  intro \$$P_ENTRY  scene \$$P_SCENEBASE  done \$$P_DONE  beats $P_NBEATS"
echo "[integ] running to frame $P_TO (${SECS}s emulated)"

export P_OUT="build/tmp/integ_test.log"
rm -f "$P_OUT"
"$MAME" coco3 \
    -rompath "$MAME_ROMS" \
    $RAMOPT \
    -cfg_directory dist/mame-cfg/rgb \
    -ext fdc -flop1 "$DSK" \
    -window -nomaximize -nothrottle -sound none \
    -seconds_to_run $SECS \
    -autoboot_script harness/smoke/integ_test.lua \
    >/dev/null 2>&1

echo "[integ] --- $P_OUT ---"
if [ -f "$P_OUT" ]; then sed 's/^/  /' "$P_OUT"; else echo "  (no log produced)"; exit 1; fi

rc=0
grep -q "^#    PASS" "$P_OUT" || { echo "[integ] the scene did not reach-and-return"; rc=1; }
echo "[integ] --------------------------------"
[ $rc -eq 0 ] && echo "[integ] PASS" || echo "[integ] FAIL"
exit $rc
