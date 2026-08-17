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

. "$(dirname "$0")/retired.sh"
retired "P3.31 — the vizier's walk, byte-exact across 28 captures, booted STANDALONE" \
        "the integrated sequence: the walk-out was gated inside the intro at P3.107 and the exit-walk skip it was built to catch was closed at P3.103. Jay's ruling, P4.2: 'walk and room should be deprecated anyway. they have been gated in the intro sequence.' ★ LOST with it: the per-page signature guard, the bank-mapped-at-capture assertion, the phase-occupancy census and the two-run stability check. Named because they were this suite's real value and integ replaces none of them."

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
export P_BANKERR="0x$(sym "$FMAP" ch_bankerr)"
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

# THE CEL IMAGE'S BOUNDS, read from the image itself — its first two bytes ARE WALK_LO
# and WALK_N, which is the same self-describing header char_draw.s reads at run time.
# Taking them from the artefact rather than from a constant here means the bank guard
# cannot go stale when a beat is added to bake_scene.PLAN.
#
# ★ IT IS cel_res.raw NOW, NOT cel_image.raw (P3.78). The image is SPLIT: the pinned page
# carries the magic and the bounds, and five rotating pages take turns at $E000. This
# still reads the bytes the engine reads, out of the half that is always mapped.
CELRAW=build/assets/cel_res.raw
[ -f "$CELRAW" ] || { echo "[run_walk_test] missing $CELRAW — run build.bat first"; exit 1; }
# OFFSETS 2 AND 3, NOT 0 AND 1 (P3.77): the image opens with a two-byte signature
# ($C3,$5A) that char_draw checks before drawing from the bank, so the bounds moved along.
export P_WALK_LO=$(od -An -tu1 -N1 -j2 "$CELRAW" | tr -d ' ')
export P_WALK_N=$(od -An -tu1 -N1 -j3 "$CELRAW" | tr -d ' ')
echo "[run_walk_test] pinned page covers cels $P_WALK_LO..$((P_WALK_LO + P_WALK_N - 1))"

# --- the split image's rotating half, and how far the scene has to run ---------------
# ★ EVERY ONE OF THESE COMES OUT OF THE PACK OR THE MAPS, never written here. The number
# of beats, the number of staged reads and the scene's length in steps are decisions the
# packer makes from bake_scene.PLAN; a copy of any of them in this file would be a check
# that passes for the wrong reason the first time a beat is added.
PACK=content/cutscene/chars/cel_pack.json
[ -f "$PACK" ] || { echo "[run_walk_test] missing $PACK — run bake_scene.py"; exit 1; }
# CEL_VARBASE is build.bat's, so it is read out of build.bat. cel_pg_sig is +1 into it,
# which is char_draw.s's layout — the one thing here that is a transcription, and it is
# two lines from the equ it transcribes in both files.
CELVAR=$(sed -n 's/^set CEL_VARBASE=\(0x[0-9A-Fa-f]*\).*/\1/p' build.bat | head -1)
[ -n "$CELVAR" ] || { echo "[run_walk_test] CEL_VARBASE not found in build.bat"; exit 1; }
export P_PGSIG=$(printf '0x%X' $(( CELVAR + 1 )))
export P_BEAT="0x$(sym "$FMAP" vm_beat)"
# THE HOURGLASS (P3.88) — the scenery flags and the sand frame, so the checker composites
# the glass instead of omitting it, and a second capture window lands on it. Both suites
# passed P3.87's broken glass change; the object was in neither the expected picture nor
# the capture range.
export P_SCENERY="0x$(sym "$FMAP" vm_scenery)"
export P_SCFLOW="0x$(sym "$FMAP" sc_flow)"
export P_SHOTS_GLASS="${P_SHOTS_GLASS:-8}"
# The schedule table's own bounds, so beats_visited counts CURSOR VALUES INSIDE IT and
# not the garbage vm_beat holds before the first tick ($FFFF and $C000 both appear in
# the boot traces, both non-zero, both were being counted -- which is how the check
# came to report "19 of 18" and pass for the wrong reason.
export P_PLAN_LO="0x$(sym "$FMAP" cel_plan)"
export P_PLAN_HI="0x$(sym "$FMAP" cel_plan_end)"
# ★★★ FMAP, NOT MAP (P3.107). cel_rd_err is defined in char_draw.s, which links into the
# disk-resident FLAMES bundle — it has never been in room.map, so `sym "$MAP" cel_rd_err`
# returned EMPTY and P_RDERR was the string "0x". The Lua's guard is `if RDERR ~= 0`, and
# nil ~= 0, so the check RAN and read whatever byte that resolved to. It printed 0 for
# dispatches — not because no staged read failed, but because the wrong byte happened to be
# zero — and printed 224 the moment the bundle grew by a few bytes.
#
# ★★ FIFTH IN THE STALE-CHECKER FAMILY, and the first to be caught by its own noise rather
# than by a dispatch looking for it. Every other bundle symbol in this file already uses
# $FMAP (P_VIZ, P_PRI, P_DRAWN, P_LAST); this one line did not.
export P_RDERR="0x$(sym "$FMAP" cel_rd_err)"
export P_LOADS="0x$(sym "$MAP" probe_loads)"
export P_NBEATS=$(python -c "import json;print(len(json.load(open('$PACK'))['schedule']))")
export P_NREADS=$(python -c "import json;print(len(json.load(open('$PACK'))['reads']))")
# THE SCENE'S LENGTH, DERIVED: sum of the beats' plays x the MEASURED step rate (7 frames,
# P3.72k — the rate the machine keeps, not cad_tab's 6), plus headroom for the two staged
# reads, which freeze the loop for a couple of seconds each and are the whole point of
# running this far. Rounded up generously: running long costs wall-clock, stopping early
# costs the check.
export P_RUNTO=$(python -c "
import json
m = json.load(open('$PACK'))
steps = sum(s['plays'] for s in m['schedule'])
print(steps * 7 + len(m['reads']) * 400 + 600)")
echo "[run_walk_test] ${P_NBEATS} beats, ${P_NREADS} staged reads, scene runs ~${P_RUNTO} frames"
# -seconds_to_run has to cover boot + LOADM + the startup reads + all of that.
SECS=$(( (P_RUNTO + 3600) / 60 + 30 ))

# ONE HOME for which machine this runs on: 128 KB, the target (CLAUDE.md 2K).
. "$(dirname "$0")/ramsize.sh"

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
        -seconds_to_run $SECS \
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

# ★ TWO WAYS THIS SUITE CAN PASS WHILE OBSERVING NOTHING, both now closed (P3.77).
#
# It arms on the first cel change and compares whatever it captured. If the scene never
# moves it captures NOTHING, compares nothing, both runs agree, and it reports PASS. That
# happened twice: once when the s_Princess hold pushed the whole window into a song
# (P3.72l), and again here when a seeded bank mismatch made the engine refuse to draw —
# "0 of 0 captures unmapped ... PASS". A suite that cannot fail on an empty scene is not
# testing the scene.
for r in a b; do
    # grep -c PRINTS 0 and EXITS 1 when it matches nothing, so `|| echo 0` appended a
    # second line and the numeric test below broke silently — the assertion never fired
    # on the very run that proved it was needed. `|| true` keeps grep's own 0.
    n=$(grep -c "^# capture " "build/walk_test_$r.log" 2>/dev/null || true)
    [ -z "$n" ] && n=0
    if [ "$n" -eq 0 ]; then
        echo "  FAIL run $r: ZERO captures — the scene never moved, so nothing was tested"
        rc=1
    fi
    if grep -q "engine_bank_guard FIRED" "build/walk_test_$r.log" 2>/dev/null; then
        echo "  FAIL run $r: the engine's own bank guard fired — it refused to draw"
        rc=1
    fi
    # ★ THE THREE P3.78 ASSERTIONS, AND THEY ARE CHECKED HERE RATHER THAN TRUSTED TO THE
    # LOG. A line reading "FAIL" in a file nothing greps is not an assertion — it is a
    # comment. That is the third instance of this shape in the arc (P3.71's guard keyed to
    # the expected-good value, P3.72h's vacuously-true parity test, P3.77's zero-capture
    # check broken by grep -c's exit status), so every one of them is matched explicitly
    # AND its PASS line is required to be present, which is what catches the check that
    # never ran at all.
    for a in page_sig_matched_every_frame beats_visited staged_reads; do
        if grep -q "^# $a FAIL" "build/walk_test_$r.log" 2>/dev/null; then
            echo "  FAIL run $r: $(grep -m1 "^# $a " "build/walk_test_$r.log" | sed 's/^# //')"
            rc=1
        elif ! grep -q "^# $a PASS" "build/walk_test_$r.log" 2>/dev/null; then
            echo "  FAIL run $r: $a never reported — the check did not run"
            rc=1
        fi
    done
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
