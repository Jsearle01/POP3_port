#!/bin/bash
# harness/smoke/run_tile_test.sh
#
# POP P5.5 — LEVEL0 screen 1's static background, off the real disk path.
#
# Boots coco3, LOADM"TILE" + EXEC (NOT a poked image — CLAUDE.md §4 launch path
# `live-disk`, and P3.5 is why: the freeze, the LOADM ceiling and the EXEC overwrite all
# lived on the real path and were invisible to poke), then checks the DISPLAYED buffer
# against bake_screen.py's reference framebuffer BYTE FOR BYTE.
#
# `-ext fdc` is mandatory; the disk is a SCRATCH COPY because MAME opens a floppy
# read-write and saves back (idiom 24), and the packed page's raw track shares the image.
#
# Addresses come from the link map, never hardcoded — P3.10 cost a dispatch to a stale
# framebuffer block number.
#
# ★ 128 KB IS THE DEFAULT AND THE TARGET (CLAUDE.md §2K). ramsize.sh is the one home for
# that; MAME_RAM=512K in the environment runs the confirmation pass -- MAME_RAM is the
# variable ramsize.sh actually reads, and guessing RAMSIZE silently runs 128 KB twice.
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"

SRC_DSK="build/probe.dmk"
DSK="build/run_tile.dmk"
BIN="build/tile_probe.bin"
MAP="build/obj/tile.map"
LOG="build/tile_test.log"
PASS="build/tile_test_PASS"
FAIL="build/tile_test_FAIL"
WANT="build/assets/tile_screen1_ref.bin"
GOT="build/tile_front.bin"

[ -f "$BIN" ]     || { echo "[run_tile_test] missing $BIN — run build.bat first"; exit 1; }
[ -f "$MAP" ]     || { echo "[run_tile_test] missing $MAP — run build.bat first"; exit 1; }
[ -f "$WANT" ]    || { echo "[run_tile_test] missing $WANT — run build.bat first"; exit 1; }
[ -f "$SRC_DSK" ] || { echo "[run_tile_test] missing $SRC_DSK — run build.bat first"; exit 1; }
cp -f "$SRC_DSK" "$DSK" || exit 1
rm -f "$LOG" "$PASS" "$FAIL" "$GOT"

export P_ENGINE="0x$(grep -E "^Symbol: tile_entry " "$MAP" | sed -E "s/.*= *//")"
export P_CURBACK="0x$(grep -E "^Symbol: HAL_gfx_cur_back " "$MAP" | sed -E "s/.*= *//")"
export P_CURMODE="0x$(grep -E "^Symbol: HAL_gfx_cur_mode " "$MAP" | sed -E 's/.*= *//')"
# lwlink lists `equ` symbols OFFSET BY THE SECTION BASE, so GFX_DB_A_BLOCK reads $7910,
# not $10. Subtracting the code base is what recovers the constant — the same arithmetic
# run_room_test.sh and run_introseq_test.sh do, and taking the raw value instead writes
# garbage to the MMU and dumps a buffer that is not either framebuffer.
CODEBASE=$(grep -E "^Symbol: .02code " "$MAP" | sed -E 's/.*= *//')
BLK_A=$(grep -E "^Symbol: GFX_DB_A_BLOCK " "$MAP" | sed -E 's/.*= *//')
BLK_B=$(grep -E "^Symbol: GFX_DB_B_BLOCK " "$MAP" | sed -E 's/.*= *//')
export P_BLK_A=$(printf '0x%02X' $(( 0x$BLK_A - 0x$CODEBASE )))
export P_BLK_B=$(printf '0x%02X' $(( 0x$BLK_B - 0x$CODEBASE )))

# HOW MANY DISPLAY-LIST ENTRIES THE PAGE ACTUALLY HOLDS, read out of the baked page
# rather than written here. probe_ents is a one-byte count, and the check is worth having
# only if the expected value tracks the bake: a literal would pass a page that lost half
# its entries. Byte +3 of the raw page is n_entries (bake_screen.py's format).
if [ -f build/assets/tile_page.raw ]; then
    export P_WANT_ENTS=$(python -c "import sys;print(open('build/assets/tile_page.raw','rb').read(4)[3])")
fi

export P_OUT="$LOG"
export P_DUMP="$GOT"
SHOT="${P_SHOT:-build/tile_screen1.png}"
export P_PAL="${P_PAL:-build/tile_palette.bin}"
rm -f "$SHOT" "$P_PAL"

. "$(dirname "$0")/ramsize.sh"

echo "[run_tile_test] POP CoCo3 — LEVEL0 screen 1, 4-colour, LOADM off disk"
echo "[run_tile_test] tile_entry $P_ENGINE  cur_back $P_CURBACK  blocks $P_BLK_A/$P_BLK_B  ents ${P_WANT_ENTS:-?}"

"$MAME" coco3 \
    -rompath "$MAME_ROMS" \
    $RAMOPT \
    -cfg_directory dist/mame-cfg/rgb \
    -ext fdc \
    -flop1 "$DSK" \
    -window -nomaximize \
    -nothrottle -sound none \
    -seconds_to_run 60 \
    -autoboot_script harness/smoke/tile_test.lua \
    >/dev/null 2>&1

echo "[run_tile_test] --- verifier log ---"
if [ -f "$LOG" ]; then sed 's/^/  /' "$LOG"; else echo "  (no log produced)"; fi
echo "[run_tile_test] --------------------"

if [ ! -f "$PASS" ]; then
    echo "[run_tile_test] FAIL (in-emulator checks)"
    exit 1
fi

# AND THE PIXELS THEMSELVES. Every in-emulator check above is satisfied by a program
# that draws the wrong thing correctly; this is the one that is not.
python harness/tools/fb_compare.py --want "$WANT" --got "$GOT" --label "port vs bake reference"
rc=$?

# A PNG for Jay to look at, DECODED from the dump rather than grabbed off the screen
# (idiom 11b: a MAME snapshot is not square-pixel and, under -nothrottle, manufactures
# motion artifacts). render_fb.py is the tool that does this -- render_square.py's header
# claims the coco3 decode but its code only opens PIL images, so it cannot take a raw dump.
# Surfaced, never interpreted: CLAUDE.md §3 makes the image a human artifact, and the byte
# comparison above is what this runner decides on.
PALOPT=""
[ -s "$P_PAL" ] && PALOPT="--palette-file $P_PAL"
python harness/tools/render_fb.py "$GOT" -o "$SHOT" --bpp 2 --scale 3 $PALOPT \
    && echo "[run_tile_test] PNG for Jay: $SHOT"
echo "[run_tile_test] --------------------------------"
[ $rc -eq 0 ] && echo "[run_tile_test] PASS" || echo "[run_tile_test] FAIL (framebuffer comparison)"
exit $rc
