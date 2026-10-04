#!/bin/bash
# harness/smoke/run_char_test.sh
#
# POP P5.28 — THE FIRST CHARACTER ON A GAMEPLAY SCREEN, off the real disk path.
#
# The character probe is tile_probe.s built with -DCHAR_PROBE: LEVEL0 screen 1 exactly as the
# tile suite draws it, then three draws of the kid's standing cel through xf_blit -- identity,
# a non-zero phase, mirrored (content/chars/probe_place.json). LOADM"CHAR" + EXEC off its own
# gate disk (build/char_gate.dmk: probe.dmk's tracks, with CHAR.BIN in INTRO.BIN's place, so
# the packed tile page is on track 34 as usual and probe.dmk itself is not touched).
#
# The verdict is a BYTE comparison against the framebuffer char_probe_plan.py PREDICTED before
# anything ran: the tile bake's reference with each draw's reference stream replayed on top.
#
# Everything else is tile_test.lua's, reused with P_FILE / P_MARK, so the in-emulator checks
# (status 4, clean disk read, page magic, all 80 entries, mode, capture) are the tile suite's.
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"

SRC_DSK="${SRC_DSK:-build/char_gate.dmk}"
DSK="build/run_char.dmk"
BIN="build/char_probe.bin"
MAP="build/obj/charprobe.map"
LOG="build/char_test.log"
PASS="build/char_test_PASS"
FAIL="build/char_test_FAIL"
WANT="build/assets/char_ref.bin"
GOT="build/char_front.bin"

for f in "$BIN" "$MAP" "$WANT" "$SRC_DSK"; do
    [ -f "$f" ] || { echo "[run_char_test] missing $f — run build.bat first"; exit 1; }
done
cp -f "$SRC_DSK" "$DSK" || exit 1
rm -f "$LOG" "$PASS" "$FAIL" "$GOT"

export P_ENGINE="0x$(grep -E "^Symbol: tile_entry " "$MAP" | sed -E "s/.*= *//")"
export P_CURBACK="0x$(grep -E "^Symbol: HAL_gfx_cur_back " "$MAP" | sed -E "s/.*= *//")"
export P_CURMODE="0x$(grep -E "^Symbol: HAL_gfx_cur_mode " "$MAP" | sed -E 's/.*= *//')"
# equ symbols are listed offset by the section base -- see run_tile_test.sh
CODEBASE=$(grep -E "^Symbol: .02code " "$MAP" | sed -E 's/.*= *//')
BLK_A=$(grep -E "^Symbol: GFX_DB_A_BLOCK " "$MAP" | sed -E 's/.*= *//')
BLK_B=$(grep -E "^Symbol: GFX_DB_B_BLOCK " "$MAP" | sed -E 's/.*= *//')
export P_BLK_A=$(printf '0x%02X' $(( 0x$BLK_A - 0x$CODEBASE )))
export P_BLK_B=$(printf '0x%02X' $(( 0x$BLK_B - 0x$CODEBASE )))
[ -f build/assets/tile_page.raw ] && \
    export P_WANT_ENTS=$(python -c "import sys;print(open('build/assets/tile_page.raw','rb').read(4)[3])")

export P_OUT="$LOG" P_DUMP="$GOT" P_FILE="CHAR" P_MARK="build/char_test"
# CHAR.BIN is 13.9 KB (seven granules) since P5.29: LOADM is still loading at tile_test.lua's
# default 900 frames, the EXEC keystroke is lost and the program never starts (status 0,
# BASIC's palette). Measured: 900 fails, 2,000 passes; 1,800 is the default here.
export P_SETTLE="${P_SETTLE:-1800}"
SHOT="${P_SHOT:-build/char_screen1.png}"
export P_PAL="${P_PAL:-build/char_palette.bin}"
rm -f "$SHOT" "$P_PAL"

. "$(dirname "$0")/ramsize.sh"
. "$(dirname "$0")/cfgdir.sh"

if [ "${MAME_VIDEO:-none}" = "none" ]; then VIDOPT="-video none"; else VIDOPT="-window -nomaximize"; fi

echo "[run_char_test] POP CoCo3 — LEVEL0 screen 1 + three kid draws, LOADM off disk, $MAME_RAM"
echo "[run_char_test] tile_entry $P_ENGINE  cur_back $P_CURBACK  blocks $P_BLK_A/$P_BLK_B  ents ${P_WANT_ENTS:-?}"

"$MAME" coco3 -rompath "$MAME_ROMS" $RAMOPT $CFGOPT -ext fdc -flop1 "$DSK" $VIDOPT \
    -nothrottle -sound none -seconds_to_run 60 \
    -autoboot_script harness/smoke/tile_test.lua >/dev/null 2>&1

echo "[run_char_test] --- verifier log ---"
if [ -f "$LOG" ]; then sed 's/^/  /' "$LOG"; else echo "  (no log produced)"; fi
echo "[run_char_test] --------------------"
[ -f "$PASS" ] || { echo "[run_char_test] FAIL (in-emulator checks)"; exit 1; }

python harness/tools/fb_compare.py --want "$WANT" --got "$GOT" --label "port vs PREDICTED (tile reference + three reference draws)"
rc=$?

# Surfaced for Jay, never interpreted (CLAUDE.md §3).
PALOPT=""
[ -s "$P_PAL" ] && PALOPT="--palette-file $P_PAL"
python harness/tools/render_fb.py "$GOT" -o "$SHOT" --bpp 2 --scale 3 $PALOPT \
    && echo "[run_char_test] PNG for Jay: $SHOT"
[ $rc -eq 0 ] && echo "[run_char_test] PASS" || echo "[run_char_test] FAIL (framebuffer comparison)"
exit $rc
