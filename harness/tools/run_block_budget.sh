#!/bin/bash
# harness/tools/run_block_budget.sh
#
# P3.66 §1 — measure the 128 KB physical-block budget with the PORT RUNNING.
#
# Grafts harness/tools/block_budget.lua's MMU write tap onto room_test.lua rather than
# launching the machine itself. That is not tidiness: three hand-written launchers failed
# three different ways during this measurement — one sampled DECB at the BASIC prompt, one
# reported before gfx init had mapped the window, and one posted EXEC while DECB was still
# loading so the room never ran at all. room_test.lua's launch is the one that works, and
# the tap needs nothing from a launcher except that the port be running.
#
# Runs at -ramsize 128K deliberately: the whole question is what the GIME aliases away on
# a stock machine, and at 512 KB nothing aliases and the measurement is vacuous.
set -u

cd "$(dirname "$0")/../.." || exit 1
MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
SCRATCH="${TMPDIR:-/tmp}/pop_block_budget"
DSK="build/run_blocks.dmk"
OUT="build/block_budget.log"
FMAP="build/obj/flames.map"
MAP="build/obj/room.map"

[ -f build/probe.dmk ] || { echo "[block-budget] no build/probe.dmk — run build.bat"; exit 1; }
cp -f build/probe.dmk "$DSK" || exit 1
mkdir -p "$SCRATCH"
rm -f "$OUT"

# tap + room_test.lua + a notifier that rewrites the report as it goes. Writing it
# repeatedly matters: room_test.lua calls machine:exit() after its verdict, and a report
# scheduled for one fixed frame simply never fired.
{
    cat harness/tools/block_budget.lua
    cat harness/tools/bank_proof.lua
    cat harness/smoke/room_test.lua
    echo '_G._mmu_n = emu.add_machine_frame_notifier(function()'
    echo '  local s = manager.machine.screens:at(1):frame_number()'
    echo '  local up = manager.machine.devices[":maincpu"].spaces["program"]:read_u8(0x2003) >= 2'
    echo '  if up and s > 1560 then _G._bank_write() end'
    echo '  if s > 1700 and s % 60 == 0 then'
    echo '    _G._mmu_report(os.getenv("P_BUDGET_OUT"))'
    echo '    _G._bank_verify(os.getenv("P_BANK_OUT"), up)'
    echo '  end'
    echo 'end)'
} > "$SCRATCH/room_mmu.lua"

sym() { grep -E "^Symbol: $1 " "$2" | sed -E 's/.*= *//'; }
export P_ENGINE="0x$(sym room_entry "$MAP")"
export P_CURBACK="0x$(sym HAL_gfx_cur_back "$MAP")"
CODEBASE=$(sym '\.02code' "$MAP")
export P_BLK_A=$(printf '0x%02X' $(( 0x$(sym GFX_DB_A_BLOCK "$MAP") - 0x$CODEBASE )))
export P_BLK_B=$(printf '0x%02X' $(( 0x$(sym GFX_DB_B_BLOCK "$MAP") - 0x$CODEBASE )))
export P_CURMODE="0x$(sym HAL_gfx_cur_mode "$MAP")"
export P_SWAPS="0x$(sym HAL_gfx_swaps "$MAP")"
export P_VIZ="0x$(sym viz_slot "$FMAP")"
export P_PRI="0x$(sym pri_slot "$FMAP")"
export P_DRAWN="0x$(sym ch_drawn "$FMAP")"
export P_LAST="0x$(sym ch_last "$FMAP")"
export P_LAST_STRIDE=$(( (0x$(sym ch_drawn "$FMAP") - 0x$(sym ch_last "$FMAP")) / 4 ))
export P_OUT="build/block_budget_room.log"
export P_DUMP="build/block_budget_front.bin"
export P_DUMP2="build/block_budget_front2.bin"
export P_DUMP_BACK=0
export P_BUDGET_OUT="$OUT"
export P_BANK_OUT="build/bank_proof.log"
rm -f build/bank_proof.log

echo "[block-budget] coco3 at 128K, port launched by room_test.lua's own sequence"
"$MAME" coco3 -rompath "$MAME_ROMS" -ramsize 128K \
    -cfg_directory dist/mame-cfg/rgb -ext fdc -flop1 "$DSK" \
    -window -nomaximize -nothrottle -sound none -seconds_to_run 45 \
    -autoboot_script "$SCRATCH/room_mmu.lua" >/dev/null 2>&1

if [ ! -s "$OUT" ]; then
    echo "[block-budget] no report — did the room start? see build/block_budget_room.log"
    exit 1
fi
cat "$OUT"
echo
[ -s build/bank_proof.log ] && cat build/bank_proof.log
grep -q "not free" "$OUT" && exit 1
exit 0
