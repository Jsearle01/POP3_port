#!/bin/bash
# harness/smoke/run_engarde_test.sh
#
# POP P5.37 — THE GUARD GOES EN GARDE: the oracle's game frames 180-217 on the 6809, compared with the
# ORACLE (engarde_test.py), not with the host transcription (guard_model.py) -- two derivations, one
# yardstick (P5.37 §3.3).
#
#   harness/smoke/run_engarde_test.sh [gate|ea|map]
#
#   gate  (default) the gate's own disk and mode: drawn, 38 game frames, then every log compared
#   ea    the EnemyAlert NEGATIVE CONTROL: forced to 1 -- the guard must stay put and the check FAIL
#   map   the MAP NEGATIVE CONTROL: screen 4 block (3,0) reads as space -- EnGarde must take DoRetreat
#         and the check FAIL. Both controls run the logic only (the retreat's cels are not linked).
#
# LOADM"GUARD" + EXEC off build/engarde_gate.dmk; the loader's kr_stop = 39 (the seed, then stop after the 38th game
# frame) and kr_nact = the run mode (kidrun_probe.s -DGA_WINDOW). At the terminal status tile_test.lua
# dumps the AI's logs (P_DUMPMEM). ★ This is not the gate: run_engarde_live.sh is what Jay watches.
set -u
cd "$(dirname "$0")/../.." || exit 1

MODE="${1:-gate}"
case "$MODE" in
    gate) NACT=2 ;;
    ea)   NACT=16 ;;
    map)  NACT=32 ;;
    *) echo "[run_engarde_test] mode is gate, ea or map"; exit 1 ;;
esac
MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
SRC_DSK="build/engarde_gate.dmk"
DSK="build/run_engarde.dmk"
MAP="build/obj/engarde.map"
KBMAP="build/obj/engardeboot.map"
LOG="build/engarde_test.log"

for f in "$MAP" "$KBMAP" "$SRC_DSK" build/gen/engarde_expect.json; do
    [ -f "$f" ] || { echo "[run_engarde_test] missing $f — build.bat"; exit 1; }
done
cp -f "$SRC_DSK" "$DSK" || exit 1
rm -f "$LOG" build/engarde_test_PASS build/engarde_test_FAIL build/engarde_front.bin \
      build/engarde_log.bin build/engarde_gp.bin build/engarde_rlog.bin build/engarde_tq.bin build/engarde_vars.bin

sym() { grep -E "^Symbol: $1 " "$MAP" | sed -E "s/.*= *//"; }
ksym() { grep -E "^Symbol: $1 " "$KBMAP" | sed -E "s/.*= *//"; }
export P_ENGINE="0x$(sym tile_entry)"
export P_CURBACK="0x$(sym HAL_gfx_cur_back)"
export P_CURMODE="0x$(sym HAL_gfx_cur_mode)"
CODEBASE=$(grep -E "^Symbol: .02code " "$MAP" | sed -E 's/.*= *//')
export P_BLK_A=$(printf '0x%02X' $(( 0x$(sym GFX_DB_A_BLOCK) - 0x$CODEBASE )))
export P_BLK_B=$(printf '0x%02X' $(( 0x$(sym GFX_DB_B_BLOCK) - 0x$CODEBASE )))
export P_WANT_ENTS=$(python -c "print(open('build/assets/tile_page4.raw','rb').read(4)[3])")
export P_OUT="$LOG" P_DUMP="build/engarde_front.bin" P_FILE="GUARD" P_MARK="build/engarde_test"
export P_SETTLE="${P_SETTLE:-600}"
export P_RUN_LIMIT="${P_RUN_LIMIT:-1500}"
export P_POKE16="$(ksym kr_stop)=39"   # step 1 is the seed; 2-39 are game frames 180-217
export P_POKE8="$(ksym kr_nact)=$NACT"
export P_DUMPMEM="$(python harness/tools/engarde_test.py --dumpspec)"
export P_PAL="build/engarde_palette.bin"

. "$(dirname "$0")/ramsize.sh"
. "$(dirname "$0")/cfgdir.sh"
echo "[run_engarde_test] $MODE (run mode $NACT), $MAME_RAM, 38 game frames"

"$MAME" coco3 -rompath "$MAME_ROMS" $RAMOPT $CFGOPT -ext fdc -flop1 "$DSK" -video none \
    -nothrottle -sound none -seconds_to_run 90 \
    -autoboot_script harness/smoke/tile_test.lua >/dev/null 2>&1

grep -E "terminal|VERDICT|poked| FAIL" "$LOG" 2>/dev/null | sed 's/^/  /'
[ -f build/engarde_test_PASS ] || { echo "[run_engarde_test] FAIL (in-emulator checks)"; exit 1; }
python harness/tools/engarde_test.py --mode "$MODE"
rc=$?
[ $rc -eq 0 ] && echo "[run_engarde_test] PASS ($MODE)" || echo "[run_engarde_test] FAIL ($MODE)"
exit $rc
