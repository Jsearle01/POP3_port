#!/bin/bash
# harness/smoke/run_walk_test.sh
#
# POP P3.31 — THE VIZIER WALKS, and he must be byte-exact for the WHOLE walk.
#
# The room suite proves a frame. This proves a SEQUENCE: captures spread across the
# whole walk, each one composited offline from the source cel at the phase the machine's
# own x implies, each one diffed byte for byte. The distinction is not academic --
# every peel bug this arc has produced (P3.21, P3.25, P3.28) was invisible at one
# capture and obvious across several, because they accumulate.
#
# It also reports the two things a capture cannot show: which sub-byte phases the walk
# actually visits, and the achieved cadence measured off the cel byte.
#
# Launch path is `live-disk` (CLAUDE.md §4): LOADM"ROOM" + EXEC off a mounted floppy,
# not a poked image.
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"

SRC_DSK="build/probe.dmk"
DSK="build/run_walk.dmk"
BIN="build/cutscene_room.bin"
MAP="build/obj/room.map"
FMAP="build/obj/flames.map"

[ -f "$BIN" ] || { echo "[run_walk_test] missing $BIN — run build.bat first"; exit 1; }
[ -f "$FMAP" ] || { echo "[run_walk_test] missing $FMAP — run build.bat first"; exit 1; }
cp -f "$SRC_DSK" "$DSK" || exit 1


sym() { grep -E "^Symbol: $2 " "$1" | sed -E 's/.*= *//'; }

export P_ENGINE="0x$(sym "$MAP" room_entry)"
export P_CURBACK="0x$(sym "$MAP" HAL_gfx_cur_back)"
# lwlink lists `equ` symbols OFFSET BY THE SECTION BASE, so the block numbers have to
# have the code base subtracted back off (the same arithmetic run_room_test.sh does).
CODEBASE=$(sym "$MAP" '\.02code')
BLK_A=$(sym "$MAP" GFX_DB_A_BLOCK)
BLK_B=$(sym "$MAP" GFX_DB_B_BLOCK)
export P_BLK_A=$(printf '0x%02X' $(( 0x$BLK_A - 0x$CODEBASE )))
export P_BLK_B=$(printf '0x%02X' $(( 0x$BLK_B - 0x$CODEBASE )))
# The slot records live in the disk-resident bundle, so they come from the FLAMES map.
export P_VIZ="0x$(sym "$FMAP" viz_slot)"
export P_PRI="0x$(sym "$FMAP" pri_slot)"
export P_DRAWN="0x$(sym "$FMAP" ch_drawn)"
export P_LAST="0x$(sym "$FMAP" ch_last)"
# THE ch_last STRIDE, DERIVED — never a literal in the Lua (P3.58). ch_last holds four
# (character, slot) entries, so (ch_drawn - ch_last)/4 is its per-entry size. When that
# entry grew from 4 to 8 bytes to carry the cel's parity, the Lua's own hard-coded `* 4`
# read the vizier's record for BOTH characters and reported the princess standing exactly
# where he was. One home, computed from symbols the map already carries.
CHLAST=$(grep -E "^Symbol: ch_last " "$FMAP" | sed -E 's/.*= *//')
CHDRAWN=$(grep -E "^Symbol: ch_drawn " "$FMAP" | sed -E 's/.*= *//')
export P_LAST_STRIDE=$(( (0x$CHDRAWN - 0x$CHLAST) / 4 ))

export P_SHOTS="${P_SHOTS:-28}"
export P_GAP="${P_GAP:-10}"

RAMOPT=""
[ -n "${MAME_RAM:-}" ] && RAMOPT="-ramsize $MAME_RAM"

echo "[run_walk_test] viz_slot $P_VIZ  ch_drawn $P_DRAWN  ch_last $P_LAST"
echo "[run_walk_test] $P_SHOTS captures every $P_GAP frames, live-disk"

# TWO SEPARATE RUNS OF THE MACHINE, because "stable across separated captures" cannot be
# read inside one run of a MOVING character: every capture is at a different position, so
# differing results are what motion looks like, not what a bug looks like. Two runs put
# the same positions side by side. (P3.21's accumulating bug was 36 vs 33 on the same
# scene; that comparison is only available when the scene repeats.)
run_once() {   # $1 = run tag
    export P_OUT="build/walk_test_$1.log"
    export P_POS="build/walk_chars_pos_$1.txt"
    export P_SHOTFMT="build/walk_${1}_shot_%s.bin"
    rm -f "$P_OUT" "$P_POS" build/walk_${1}_shot_*.bin
    "$MAME" coco3 \
        -rompath "$MAME_ROMS" \
        $RAMOPT \
        -cfg_directory dist/mame-cfg/rgb \
        -ext fdc \
        -flop1 "$DSK" \
        -window -nomaximize \
        -nothrottle -sound none \
        -seconds_to_run 60 \
        -autoboot_script harness/smoke/walk_test.lua \
        >/dev/null 2>&1
}

run_once a
run_once b

echo "[run_walk_test] --- machine log (run a) ---"
if [ -f build/walk_test_a.log ]; then sed 's/^/  /' build/walk_test_a.log
else echo "  (no log produced)"; exit 1; fi

rc=0
for r in a b; do
    echo "[run_walk_test] --- pixel check, every capture (run $r) ---"
    python harness/tools/verify_room_chars.py --pos "build/walk_chars_pos_$r.txt" \
           --shots "build/walk_${r}_shot_%s.bin" > "build/walk_check_$r.txt"
    [ $? -ne 0 ] && rc=1
    sed 's/^/  /' "build/walk_check_$r.txt"
done

echo "[run_walk_test] --- run a vs run b ---"
if diff -q build/walk_chars_pos_a.txt build/walk_chars_pos_b.txt >/dev/null &&
   diff -q build/walk_check_a.txt build/walk_check_b.txt >/dev/null; then
    echo "  STABLE: both runs walked the same positions and produced the same result"
else
    echo "  UNSTABLE: the two runs differ —"
    diff build/walk_chars_pos_a.txt build/walk_chars_pos_b.txt | head -10
    diff build/walk_check_a.txt build/walk_check_b.txt | head -10
    rc=1
fi
echo "[run_walk_test] --------------------------------"
[ $rc -eq 0 ] && echo "[run_walk_test] PASS" || echo "[run_walk_test] FAIL"
exit $rc
