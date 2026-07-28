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
rm -f "$LOG" "$PASS" "$FAIL" "$GOT"

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
export P_OUT="$LOG"
export P_DUMP="$GOT"

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

# THE CHECK THAT MATTERS: the displayed buffer IS the converted room, byte for byte.
python - "$WANT" "$GOT" <<'PY'
import pathlib, sys
want = pathlib.Path(sys.argv[1]).read_bytes()
got  = pathlib.Path(sys.argv[2]).read_bytes()
if len(got) != len(want):
    print("  FAIL room framebuffer: %d bytes, expected %d" % (len(got), len(want)))
    sys.exit(1)
bad = [i for i, (a, b) in enumerate(zip(got, want)) if a != b]
if not bad:
    print("  PASS displayed buffer == converted princess room: %d bytes byte-identical"
          % len(got))
    sys.exit(0)
i = bad[0]
print("  FAIL room framebuffer: %d bytes differ; first at row %d col %d (got $%02X want $%02X)"
      % (len(bad), i // 80, i % 80, got[i], want[i]))
sys.exit(1)
PY
rc=$?
echo "[run_room_test] --------------------------------"
[ $rc -eq 0 ] && echo "[run_room_test] PASS" || echo "[run_room_test] FAIL (asset comparison)"
exit $rc
