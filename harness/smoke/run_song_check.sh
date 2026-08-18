#!/bin/bash
# harness/smoke/run_song_check.sh — P4.6: the slice, headless. Liveness, FIDELITY and cost.
#
# ★★★ WHY THIS EXISTS SEPARATELY FROM THE EAR GATE. P4.5's headless check proved the table
# was consumed and the FIRQ torn down, and could not distinguish a 4 us pulse from a 22 us
# one — both consume 321 runs and terminate identically. Jay heard the difference in three
# seconds ("i need more volume") and the suite was green throughout. So this run now TIMES
# THE $FF20 WRITES: what came out, not what was intended.
#
# ★★ AND IT MEASURES THE TWO CONSTANTS THE PACKER NEEDS. The emitted pulse is the delay
# loop PLUS the instructions around it, and the emitted period is the tick value PLUS the
# handler's restart latency. Both are properties of the handler, both are printed here, and
# both go back into build.bat as --pulse-overhead-cyc / --latency-us. Modelling them is
# what put P4.5's pulses 6.6 us wide.
#
# ★ THE ABLATIONS ARE THE COST SPLIT (P4.6 §2). +1,275 cyc/f was measured against ~554
# predicted, and "counted != assembled != executed" means the gap has to be taken apart by
# running variants, not by re-deriving the estimate. P_ABLATE builds one:
#
#   P_ABLATE=none      the slice as built                      (default)
#   P_ABLATE=nodither  auto-reload; no per-interrupt timer write
#   P_ABLATE=nocount   no probe_firqs increment
#   P_ABLATE=nopulse   pulse forced to one iteration
#
# 128 KB, the target, through the one home. Launch path live-disk (CLAUDE.md §4).
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
IMGTOOL="${IMGTOOL:-/c/mame/imgtool.exe}"
SRC_DSK="build/probe.dmk"
ABL="${P_ABLATE:-none}"
DSK="build/run_song_$ABL.dmk"
MAP="build/obj/song.map"
BIN="build/song_probe.bin"

[ -f "$MAP" ] || { echo "[song_check] missing $MAP — run build.bat"; exit 1; }
mkdir -p build/tmp

# ---- the ablation build, if one was asked for -------------------------------------
# ★ The TABLES are not regenerated: an ablation must change the player and nothing else,
# or the cost difference is not attributable to the piece removed.
if [ "$ABL" != "none" ]; then
    case "$ABL" in
        nodither) DEF=SP_NODITHER ;;
        nocount)  DEF=SP_NOCOUNT  ;;
        nopulse)  DEF=SP_NOPULSE  ;;
        *) echo "[song_check] unknown P_ABLATE=$ABL"; exit 1 ;;
    esac
    BIN="build/song_probe_$ABL.bin"
    MAP="build/obj/song_$ABL.map"
    lwasm --obj -DOBJTARGET -D$DEF -I . -o "build/obj/song_probe_$ABL.o" src/harness/song_probe.s \
        || { echo "[song_check] assemble failed"; exit 1; }
    lwlink --decb --script=link/pop_engine.link --entry=probe_entry --map="$MAP" \
        -o "$BIN" "build/obj/song_probe_$ABL.o" build/obj/hal_build.o \
        || { echo "[song_check] link failed"; exit 1; }
    echo "[song_check] ablation $ABL (-D$DEF) -> $BIN"
fi

[ -f "$BIN" ] || { echo "[song_check] missing $BIN"; exit 1; }

# ★★★ SONG.BIN GOES ON A COPY. P4.2 put its instrument on build/probe.dmk for one build and
# DECB allocated the granules over a RESERVED cel-page track: the engine's bank guard fired
# and run_walk_test reported "0 of 19 beats" in a suite with nothing to do with audio.
cp -f "$SRC_DSK" "$DSK" || exit 1
"$IMGTOOL" put coco_dmk_rsdos "$DSK" "$BIN" SONG.BIN \
    --ftype=binary --ascii=binary >/dev/null 2>&1 \
    || { echo "[song_check] could not add SONG.BIN to $DSK"; exit 1; }

sym() { grep -E "^Symbol: $2 " "$1" | sed -E 's/.*= *//'; }

export P_ENTRY="$(sym "$MAP" probe_entry)"
export P_SPIN="$(sym "$MAP" hal_vbl_spin)"
export P_TICKS="$(sym "$MAP" sp_ticks)"
export P_WIDTH="$(sym "$MAP" sp_width)"
export P_PTR="$(sym "$MAP" sp_ptr)"
export P_DUR="${P_DUR:-6506.7}"   # the measured length of the source stream, ms
export P_PULSE="${P_PULSE:-1}"
export P_MODE="${P_MODE:-0}"   # 0 = table A, 2 = table B; the control needs a terminating pass
export P_OUT="build/tmp/song_check_${ABL}_m$P_MODE.log"

for s in P_ENTRY P_SPIN P_TICKS P_WIDTH P_PTR; do
    eval "v=\$$s"
    [ -n "$v" ] || { echo "[song_check] $s not in $MAP"; exit 1; }
done

. "$(dirname "$0")/ramsize.sh"
echo "[song_check] $RAMOPT  ablate=$ABL  probe \$$P_ENTRY  spin \$$P_SPIN  ticks \$$P_TICKS"

rm -f "$P_OUT"
"$MAME" coco3 \
    -rompath "$MAME_ROMS" \
    $RAMOPT \
    -cfg_directory dist/mame-cfg/rgb \
    -ext fdc -flop1 "$DSK" \
    -window -nomaximize -nothrottle -sound none \
    -seconds_to_run 60 \
    -autoboot_script harness/smoke/song_live.lua \
    >/dev/null 2>&1

echo "[song_check] --- $P_OUT ---"
if [ -f "$P_OUT" ]; then sed 's/^/  /' "$P_OUT"; else echo "  (no log produced)"; exit 1; fi

rc=0
grep -q "^# PASS" "$P_OUT" || { echo "[song_check] DID NOT PASS"; rc=1; }
echo "[song_check] --------------------------------"
[ $rc -eq 0 ] && echo "[song_check] OK" || echo "[song_check] FAIL"
exit $rc
