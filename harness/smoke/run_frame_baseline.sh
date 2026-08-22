#!/bin/bash
# harness/smoke/run_frame_baseline.sh
#
# POP P3.43 — RE-BASELINE THE FRAME: measure the engine's real per-iteration cost and
# decompose it by run-time ablation, replacing P3.19's 19,652 cy MODEL.
#
# Runs the same build five times, removing one component per run, and differences the
# results. No `src/` file is touched — every mode ablates at run time.
#
# Launch path is `live-disk` (CLAUDE.md §4). This is a MEASUREMENT, not a 25.3 gate:
# the ablated modes deliberately freeze the torches or the characters, so the screen is
# WRONG in four of the five runs by construction.
#
# Addresses come from the link maps, never hardcoded (P3.10). room_loop / flicker /
# CHARS_TAB are in the ROOM map; the blit primitives and ch_anymove live in the
# disk-resident character bundle, so they come from the FLAMES map.
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"

SRC_DSK="build/probe.dmk"
MAP="build/obj/room.map"
FMAP="build/obj/flames.map"
SUM="build/frame_baseline.txt"

[ -f "$MAP" ]  || { echo "[run_frame_baseline] missing $MAP — run build.bat first";  exit 1; }
[ -f "$FMAP" ] || { echo "[run_frame_baseline] missing $FMAP — run build.bat first"; exit 1; }

sym()  { grep -E "^Symbol: $2 " "$1" | sed -E 's/.*= *//'; }

export P_LOOP="0x$(sym "$MAP"  room_loop)"
export P_SPIN="0x$(sym "$MAP"  hal_vbl_spin)"
export P_FLICKER="0x$(sym "$MAP"  flicker)"
# CHARS_TAB is an `equ`, and lwlink lists `equ` symbols OFFSET BY THE SECTION BASE — it
# reads $5040, not $3040. Subtracting cutscene_room's own `prog` base recovers the
# constant; this is the same arithmetic run_room_test.sh does for GFX_DB_*_BLOCK, and
# taking the raw value instead sends the ablation at an address that holds no such
# instruction. (It did: the first run of this tool ABORTED here rather than patching
# something else, which is what the byte check is for.)
CR_BASE=$(grep -F 'Symbol: \02prog (build/obj/cutscene_room.o)' "$MAP" | sed -E 's/.*= *//')
CT_RAW=$(sym "$MAP" CHARS_TAB)
export P_CHARSTAB=$(printf '0x%04X' $(( 0x$CT_RAW - 0x$CR_BASE )))
export P_ANYMOVE="0x$(sym "$FMAP" ch_anymove)"
export P_BSAVE="0x$(sym "$FMAP" blit_save)"
export P_BERASE="0x$(sym "$FMAP" blit_erase)"
export P_BCEL="0x$(sym "$FMAP" blit_cel)"
export P_CHARSFRAME="0x$(sym "$FMAP" chars_frame)"
# P3.44 — the three peel/draw call sites. BLIT_TAB is taken from `blit_tab` in
# flame_cels.o, which is a REAL LABEL and therefore unbiased; char_draw's `BLIT_TAB` equ
# is listed biased by its own section base ($6A84) and is used only as a cross-check.
BLITTAB=$(grep -F 'Symbol: blit_tab (build/obj/flame_cels.o)' "$FMAP" | sed -E 's/.*= *//')
CD_BASE=$(grep -F 'Symbol: \02prog (build/obj/char_draw.o)' "$FMAP" | sed -E 's/.*= *//')
BT_EQU=$(sym "$FMAP" BLIT_TAB)
BT_CHK=$(printf '%04X' $(( 0x$BT_EQU - 0x$CD_BASE )))
if [ "$BT_CHK" != "$BLITTAB" ]; then
    echo "[run_frame_baseline] BLIT_TAB disagreement: label \$$BLITTAB vs un-biased equ \$$BT_CHK — refusing"
    exit 1
fi
export P_BLITTAB="0x$BLITTAB"
export P_CHARLO="0x$CD_BASE"
export P_CHARHI=$(printf '0x%04X' $(( 0x$CD_BASE + 0x600 )))
export P_FIRST="${P_FIRST:-1900}"
export P_LAST="${P_LAST:-3400}"

echo "[run_frame_baseline] room_loop $P_LOOP  flicker $P_FLICKER  CHARS_TAB $P_CHARSTAB  ch_anymove $P_ANYMOVE"
: > "$SUM"

for MODE in ${P_MODES:-full nopeel nochars noflicker neither nodraw nosave noerase}; do
    DSK="build/run_fb_$MODE.dmk"
    # MAME opens a floppy read-write and saves back (idiom 24) — mount a COPY per run.
    cp -f "$SRC_DSK" "$DSK" || exit 1
    export P_MODE="$MODE"
    export P_OUT="build/frame_baseline_$MODE.log"
    rm -f "$P_OUT"
    echo "[run_frame_baseline] --- mode $MODE ---"
# 128 KB, the target (CLAUDE.md §2K), through the ONE HOME for that fact — this runner
# carried no -ramsize at all until P3.101's sweep, so every reading it has ever produced
# was taken on the 512 KB machine. See harness/smoke/ramsize.sh.
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
        -autoboot_script harness/tools/frame_baseline.lua \
        >/dev/null 2>&1
    if [ -f "$P_OUT" ]; then sed 's/^/  /' "$P_OUT"; cat "$P_OUT" >> "$SUM"
    else echo "  (no log produced)"; fi
    rm -f "$DSK"
done

echo "[run_frame_baseline] --- decomposition ---"
python harness/tools/frame_baseline_report.py "$SUM"
