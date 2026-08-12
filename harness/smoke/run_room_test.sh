#!/bin/bash
# harness/smoke/run_room_test.sh
#
# POP P3.17 phase A — the princess's room, in 4-colour, off the real disk path.
#
# Boots coco3, LOADM"ROOM" + EXEC (NOT a poked image — CLAUDE.md §4 launch path
# `live-disk`, and P3.5 is why: the freeze, the LOADM ceiling and the EXEC overwrite
# all lived on the real path and were invisible to poke), then checks that the
# DISPLAYED buffer is the converted room byte for byte.
#
# `-ext fdc` is mandatory; the disk is a SCRATCH COPY because MAME opens a floppy
# read-write and saves back (idiom 24), and the raw asset track shares the image.
#
# Addresses come from the link map, never hardcoded — P3.10 cost a dispatch to a
# stale framebuffer block number.
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"

SRC_DSK="build/probe.dmk"
DSK="build/run_room.dmk"
BIN="build/cutscene_room.bin"
MAP="build/obj/room.map"
LOG="build/room_test.log"
PASS="build/room_test_PASS"
FAIL="build/room_test_FAIL"
WANT="content/cutscene/princess_room.raw"
GOT="build/room_front.bin"

[ -f "$BIN" ] || { echo "[run_room_test] missing $BIN — run build.bat first"; exit 1; }
[ -f "$MAP" ] || { echo "[run_room_test] missing $MAP — run build.bat first"; exit 1; }
[ -f "$SRC_DSK" ] || { echo "[run_room_test] missing $SRC_DSK — run build.bat first"; exit 1; }
cp -f "$SRC_DSK" "$DSK" || exit 1
rm -f "$LOG" "$PASS" "$FAIL" "$GOT" build/room_front2.bin build/room_chars_pos.txt   # appended per capture; stale rows read as extra captures

export P_ENGINE="0x$(grep -E "^Symbol: room_entry " "$MAP" | sed -E "s/.*= *//")"
export P_CURBACK="0x$(grep -E "^Symbol: HAL_gfx_cur_back " "$MAP" | sed -E "s/.*= *//")"
# lwlink lists `equ` symbols OFFSET BY THE SECTION BASE, so GFX_DB_A_BLOCK reads
# $7910, not $10. Subtracting the code base is what recovers the constant — the same
# arithmetic run_introseq_test.sh does, and taking the raw value instead writes
# garbage to the MMU and dumps a buffer that is not either framebuffer.
CODEBASE=$(grep -E "^Symbol: .02code " "$MAP" | sed -E 's/.*= *//')
BLK_A=$(grep -E "^Symbol: GFX_DB_A_BLOCK " "$MAP" | sed -E 's/.*= *//')
BLK_B=$(grep -E "^Symbol: GFX_DB_B_BLOCK " "$MAP" | sed -E 's/.*= *//')
export P_BLK_A=$(printf '0x%02X' $(( 0x$BLK_A - 0x$CODEBASE )))
export P_BLK_B=$(printf '0x%02X' $(( 0x$BLK_B - 0x$CODEBASE )))
export P_CURMODE="0x$(grep -E "^Symbol: HAL_gfx_cur_mode " "$MAP" | sed -E 's/.*= *//')"
export P_DUMP_BACK="${P_DUMP_BACK:-0}"

# ★ HOW MANY DISK CALLS THE STARTUP OWES, DERIVED FROM THE PACK (P3.78b).
# room (1) + flame bundle (1) + the pinned page and the first page of each rotating block,
# TWO calls each because a unit's second track is read skewed so it ends at the top of the
# window. The literal `3` this replaced predated the split and failed as a disk fault.
PACK=content/cutscene/chars/cel_pack.json
if [ -f "$PACK" ]; then
    NROT=$(python -c "import json,sys;p=json.load(open(sys.argv[1]));print(len({g['block'] for g in p['pages']}))" "$PACK") || NROT=3
    export P_WANT_LOADS=$(( 1 + 1 + 2 + NROT * 2 ))
fi
export P_SWAPS="0x$(grep -E "^Symbol: HAL_gfx_swaps " "$MAP" | sed -E 's/.*= *//')"
# The character slot records live in the disk-resident bundle (P3.22), so their
# addresses come from the FLAMES map, not the room map.
FMAP="build/obj/flames.map"
export P_VIZ="0x$(grep -E "^Symbol: viz_slot " "$FMAP" | sed -E 's/.*= *//')"
export P_PRI="0x$(grep -E "^Symbol: pri_slot " "$FMAP" | sed -E 's/.*= *//')"
export P_DRAWN="0x$(grep -E "^Symbol: ch_drawn " "$FMAP" | sed -E 's/.*= *//')"
export P_LAST="0x$(grep -E "^Symbol: ch_last " "$FMAP" | sed -E 's/.*= *//')"
# THE ch_last STRIDE, DERIVED — never a literal in the Lua (P3.58). ch_last holds four
# (character, slot) entries, so (ch_drawn - ch_last)/4 is its per-entry size. When that
# entry grew from 4 to 8 bytes to carry the cel's parity, the Lua's own hard-coded `* 4`
# read the vizier's record for BOTH characters and reported the princess standing exactly
# where he was. One home, computed from symbols the map already carries.
CHLAST=$(grep -E "^Symbol: ch_last " "$FMAP" | sed -E 's/.*= *//')
CHDRAWN=$(grep -E "^Symbol: ch_drawn " "$FMAP" | sed -E 's/.*= *//')
export P_LAST_STRIDE=$(( (0x$CHDRAWN - 0x$CHLAST) / 4 ))

export P_OUT="$LOG"
export P_DUMP="$GOT"
export P_DUMP2="build/room_front2.bin"

RAMOPT=""
[ -n "${MAME_RAM:-}" ] && RAMOPT="-ramsize $MAME_RAM"

echo "[run_room_test] POP CoCo3 — the princess's room, 4-colour, LOADM off disk"
echo "[run_room_test] room_entry $P_ENGINE  cur_back $P_CURBACK  blocks $P_BLK_A/$P_BLK_B"

"$MAME" coco3 \
    -rompath "$MAME_ROMS" \
    $RAMOPT \
    -cfg_directory dist/mame-cfg/rgb \
    -ext fdc \
    -flop1 "$DSK" \
    -window -nomaximize \
    -nothrottle -sound none \
    -seconds_to_run 60 \
    -autoboot_script harness/smoke/room_test.lua \
    >/dev/null 2>&1

echo "[run_room_test] --- verifier log ---"
if [ -f "$LOG" ]; then sed 's/^/  /' "$LOG"; else echo "  (no log produced)"; fi
echo "[run_room_test] --------------------"

if [ ! -f "$PASS" ]; then
    echo "[run_room_test] FAIL (in-emulator checks)"
    exit 1
fi

# THE CHECKS THAT MATTER, and phase B needs TWO captures: a still picture passes
# every in-emulator check above, so stillness has to be refuted explicitly.
python harness/tools/verify_room_flicker.py --room "$WANT" --first "$GOT" \
       --second "build/room_front2.bin" --pos build/room_chars_pos.txt
rc1=$?

# AND THE PIXELS THEMSELVES. The flicker check above only proves bytes changed inside
# the boxes — it cannot see a wrong colour or a corrupted merge, which is how blue
# pixels reached Jay's eye instead of this suite's.
CELS=$(cat build/room_cels.txt 2>/dev/null || echo "1 1")
python harness/tools/verify_room_flame_pixels.py --room "$WANT" --shot "$GOT" \
       --seg-dir "${P_SEG_DIR:-build/flames_seg}" \
       --cel0 ${CELS% *} --cel1 ${CELS#* } --pos build/room_chars_pos.txt
rc2=$?
[ $rc1 -ne 0 ] && rc=$rc1 || rc=$rc2
echo "[run_room_test] --------------------------------"
[ $rc -eq 0 ] && echo "[run_room_test] PASS" || echo "[run_room_test] FAIL (asset comparison)"
exit $rc
