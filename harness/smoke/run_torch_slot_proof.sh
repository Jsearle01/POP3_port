#!/bin/bash
# harness/smoke/run_torch_slot_proof.sh
#
# POP P3.48 — prove the torch's four-slot peel discipline OPERATES (not merely that
# nothing broke: it was green for thirty dispatches while the discipline was dead).
#
# Launch path is `live-disk` (CLAUDE.md §4): LOADM"ROOM" + EXEC off a mounted floppy.
# Measurement/proof only; no visual claim is made from it.
#
# Addresses from the link maps, never hardcoded (P3.10). PEEL_BYTES is an `equ`, so
# lwlink lists it OFFSET BY THE SECTION BASE — un-biased here, the same arithmetic
# run_room_test.sh does for GFX_DB_*_BLOCK and run_frame_baseline.sh for CHARS_TAB.
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"

SRC_DSK="build/probe.dmk"
DSK="build/run_torchslot.dmk"
MAP="build/obj/room.map"
LOG="build/torch_slot_proof.log"

[ -f "$MAP" ] || { echo "[run_torch_slot_proof] missing $MAP — run build.bat first"; exit 1; }
cp -f "$SRC_DSK" "$DSK" || exit 1     # MAME writes floppies back (idiom 24) — mount a copy
rm -f "$LOG"

sym() { grep -E "^Symbol: $2 " "$1" | sed -E 's/.*= *//'; }

CR_BASE=$(grep -F 'Symbol: \02prog (build/obj/cutscene_room.o)' "$MAP" | sed -E 's/.*= *//')
PEELSZ_RAW=$(sym "$MAP" PEEL_BYTES)

export P_FLSLOT="0x$(sym "$MAP" fl_slot)"
export P_CURBACK="0x$(sym "$MAP" HAL_gfx_cur_back)"
export P_PEELBASE="0x$(sym "$MAP" peel_base)"
export P_PEELSZ=$(( 0x$PEELSZ_RAW - 0x$CR_BASE ))
export P_FIRST="${P_FIRST:-1900}"
export P_LAST="${P_LAST:-3400}"
export P_OUT="$LOG"

echo "[run_torch_slot_proof] fl_slot $P_FLSLOT  cur_back $P_CURBACK  peel_base $P_PEELBASE  PEEL_BYTES $P_PEELSZ"
[ "$P_PEELSZ" -gt 0 ] || { echo "[run_torch_slot_proof] PEEL_BYTES un-biased to $P_PEELSZ — refusing"; exit 1; }

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
    -seconds_to_run 70 \
    -autoboot_script harness/tools/torch_slot_proof.lua \
    >/dev/null 2>&1

echo "[run_torch_slot_proof] --- proof ---"
if [ -f "$LOG" ]; then sed 's/^/  /' "$LOG"; else echo "  (no log produced)"; exit 1; fi
rm -f "$DSK"
grep -q "VERDICT: the four-slot discipline OPERATES" "$LOG"
