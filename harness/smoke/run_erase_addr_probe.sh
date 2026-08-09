#!/bin/bash
# harness/smoke/run_erase_addr_probe.sh
#
# POP P3.49 — capture the address buffer-1 torch-1's erase actually reads.
#
# CONTROL FIRST: run with P_SEED=1 and confirm the probe registers the seeded failure
# (erase dispatches -> 0, saves unchanged) BEFORE any clean reading is believed. P3.48b
# built a probe that read the same with the mechanism removed; this one has to earn it.
#
# Launch path is `live-disk` (CLAUDE.md §4). Diagnosis only; no visual claim, no build.
#
# Addresses from the link map, never hardcoded (P3.10). draw_tab/save_tab/erase_tab and
# PEEL_BYTES are `equ`s, so lwlink lists them OFFSET BY THE SECTION BASE — un-biased here,
# the same arithmetic run_room_test.sh does for GFX_DB_*_BLOCK.
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"

SRC_DSK="build/probe.dmk"
DSK="build/run_eraseaddr.dmk"
MAP="build/obj/room.map"
LOG="${P_OUT:-build/erase_addr.log}"

[ -f "$MAP" ] || { echo "[run_erase_addr_probe] missing $MAP — run build.bat first"; exit 1; }
cp -f "$SRC_DSK" "$DSK" || exit 1     # MAME writes floppies back (idiom 24) — mount a copy
rm -f "$LOG"

sym() { grep -E "^Symbol: $2 " "$1" | sed -E 's/.*= *//'; }
CR_BASE=$(grep -F 'Symbol: \02prog (build/obj/cutscene_room.o)' "$MAP" | sed -E 's/.*= *//')
unbias() { printf '0x%04X' $(( 0x$(sym "$MAP" "$1") - 0x$CR_BASE )); }

export P_ERASETAB=$(unbias erase_tab)
export P_SAVETAB=$(unbias save_tab)
export P_PEELSZ=$(( 0x$(sym "$MAP" PEEL_BYTES) - 0x$CR_BASE ))
export P_TPEEL="0x$(sym "$MAP" t_peel)"
export P_TPREV="0x$(sym "$MAP" t_prev)"
export P_FLSLOT="0x$(sym "$MAP" fl_slot)"
export P_PEELBASE="0x$(sym "$MAP" peel_base)"
export P_TORCHSTEP="0x$(sym "$MAP" torch_step)"
export P_FIRST="${P_FIRST:-1900}"
export P_LAST="${P_LAST:-3400}"
export P_OUT="$LOG"

# A BUILD THAT DID NOT RUN LOOKS EXACTLY LIKE ONE THAT RAN AND RETURNS 0 (P3.48b). The
# parity fix moves peel_base from $22C9 (unfixed) to $22C2 (fixed), so the map itself says
# which binary is on the disk. Refuse to measure the wrong one.
echo "[run_erase_addr_probe] peel_base $P_PEELBASE  fl_slot $P_FLSLOT  erase_tab $P_ERASETAB  save_tab $P_SAVETAB  seed=${P_SEED:-0}"
# Keyed on the UNFIXED value rather than on one expected fixed value: the fixed layout
# shifts depending on whether the fl_buf declaration is also removed ($22C2 with it, $22C1
# without), and a guard that demands one exact address fails open when the other is built.
if [ "${P_REQUIRE_FIXED:-1}" = "1" ] && [ "$P_PEELBASE" = "0x22C9" ]; then
    echo "[run_erase_addr_probe] peel_base is $P_PEELBASE — the UNFIXED layout. The parity fix is not in this build. Refusing."
    exit 1
fi

"$MAME" coco3 \
    -rompath "$MAME_ROMS" \
    -cfg_directory dist/mame-cfg/rgb \
    -ext fdc \
    -flop1 "$DSK" \
    -window -nomaximize \
    -nothrottle -sound none \
    -seconds_to_run 70 \
    -autoboot_script harness/tools/erase_addr_probe.lua \
    >/dev/null 2>&1

echo "[run_erase_addr_probe] --- result ---"
if [ -f "$LOG" ]; then sed 's/^/  /' "$LOG"; else echo "  (no log produced)"; exit 1; fi
rm -f "$DSK"
