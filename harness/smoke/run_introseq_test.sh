#!/bin/bash
# harness/smoke/run_introseq_test.sh
#
# POP CoCo3 — P3.3 intro-sequencer test.
#
# Boots coco3, starts the linked sequencer, captures the DISPLAYED screen at all
# five states of the two credits, records the frame of every transition, and
# checks each capture byte-for-byte against an offline replay of the same assets.
#
# THE IMAGE IS LOADMed FROM DISK -- the real path, first time in the project.
# P3.4 took the screen out of the program image (it lives on raw tracks 27..33 and
# the program reads it itself), which drops INTROSEQ.BIN to one granule and puts
# it back inside what DECB can carry. `-ext fdc` is MANDATORY: a bare coco3 has no
# disk controller, LOADM does nothing, and the program silently never runs.
#
# The disk is mounted as a SCRATCH COPY -- MAME opens a floppy read-write and JVC
# saves back (idiom 24). Doubly important now: the raw asset tracks share the
# image, so a write-back would corrupt the screen as well as the files.
#
# `$CFGOPT` forces Monitor Type = RGB; MAME's own
# default is Composite, in which the same palette byte is a different colour.
#
# HAL_gfx_cur_back's address is read out of the link map rather than hardcoded:
# the kernel moved $7000 -> $7900 in P3.3 and will move again when assets go to
# banked RAM. A stale constant here would read a byte of unrelated code and pick
# the wrong buffer to dump, which looks like a rendering bug.
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"

SRC_DSK="build/probe.dmk"
DSK="build/run_introseq.dmk"
# ~~ P4.46: the LOADM target is now the STAGE-1 LOADER, not the intro. The intro is no
# ~~ longer a DECB file at all -- the loader reads its program off a raw track and jumps
# ~~ to intro_seq_boot, past the set_mode whose buffer-clear would wipe the "loading"
# ~~ screen. So the segment check below verifies LOADER.BIN landed, and a second check
# ~~ after EXEC verifies the intro itself arrived at $2000.
BIN="build/loader.bin"
MAP="build/obj/introseq.map"
LOG="build/introseq_test.log"
PASS="build/introseq_test_PASS"
FAIL="build/introseq_test_FAIL"
DUMP="build/introseq_dumps"

[ -f "$SRC_DSK" ] || { echo "[run_introseq_test] missing $SRC_DSK — run build.bat first"; exit 1; }
[ -f "$BIN" ] || { echo "[run_introseq_test] missing $BIN — run build.bat first"; exit 1; }
[ -f "$MAP" ] || { echo "[run_introseq_test] missing $MAP — run build.bat first"; exit 1; }

CURBACK=$(grep -E "^Symbol: HAL_gfx_cur_back " "$MAP" | sed -E 's/.*= *//')
[ -n "$CURBACK" ] || { echo "[run_introseq_test] HAL_gfx_cur_back not in $MAP"; exit 1; }

cp -f "$SRC_DSK" "$DSK" || exit 1

rm -f "$LOG" "$PASS" "$FAIL"
rm -rf "$DUMP"; mkdir -p "$DUMP"

echo "[run_introseq_test] POP CoCo3 P3.3 intro sequencer"
echo "[run_introseq_test] beats: Broderbund splash -> \"Presents\" -> clear -> \"Mechner\" -> clear"
echo "[run_introseq_test] HAL_gfx_cur_back = \$$CURBACK (from $MAP)"

export P_BIN="$BIN"
export P_OUT="$LOG"
export P_DUMP="$DUMP"
export P_PASS="$PASS"
export P_FAIL="$FAIL"
export P_CURBACK="0x$CURBACK"
# The framebuffer block numbers come from the MAP, not from constants copied into
# this script. They moved in P3.10 (buffer B $18 -> $14, so the two buffers stay
# adjacent and clear of the CPU map on a 128 KB machine) and a stale copy here
# dumps the WRONG buffer -- which passes every capture check and then fails the
# byte comparison, pointing at the engine instead of at the harness.
CODEBASE=$(grep -E "^Symbol: .02code " "$MAP" | sed -E 's/.*= *//')
BLK_A=$(grep -E "^Symbol: GFX_DB_A_BLOCK " "$MAP" | sed -E 's/.*= *//')
BLK_B=$(grep -E "^Symbol: GFX_DB_B_BLOCK " "$MAP" | sed -E 's/.*= *//')
export P_BLK_A=$(printf '0x%02X' $(( 0x$BLK_A - 0x$CODEBASE )))
export P_BLK_B=$(printf '0x%02X' $(( 0x$BLK_B - 0x$CODEBASE )))
echo "[run_introseq_test] framebuffer blocks A=$P_BLK_A B=$P_BLK_B (from $MAP)"
export P_NOBORROW="${NOBORROW:-0}"
export P_SWAPS="0x$(grep -E "^Symbol: HAL_gfx_swaps_hi " "$MAP" | sed -E "s/.*= *//")"
# the sweep probes, also from the map — P3.10 cost a dispatch to a hardcoded one
export P_WIPES="0x$(grep -E "^Symbol: probe_wipes " "$MAP" | sed -E "s/.*= *//")"
export P_WPLEFT="0x$(grep -E "^Symbol: wp_nleft " "$MAP" | sed -E "s/.*= *//")"

# MAME_RAM=128K runs this on a 128 KB CoCo3. The framebuffer blocks are chosen
# so both sizes work (P3.10): the GIME masks a block number to the RAM actually
# installed, so on 128 KB every number aliases mod 16, and buffer B at $18 used
# to land straight on top of the program. Default is MAME 512K.
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
    -seconds_to_run 200 \
    -autoboot_script harness/smoke/introseq_test.lua \
    >/dev/null 2>&1

echo "[run_introseq_test] --- verifier log ---"
if [ -f "$LOG" ]; then sed 's/^/  /' "$LOG"; else echo "  (no log produced)"; fi
echo "[run_introseq_test] --------------------"

if [ ! -f "$PASS" ]; then
    echo "[run_introseq_test] FAIL (capture stage)"
    [ -f "$FAIL" ] && sed 's/^/  /' "$FAIL"
    exit 1
fi

echo "[run_introseq_test] --- offline asset comparison ---"
python harness/tools/verify_introseq.py --dumps "$DUMP" | sed 's/^/  /'
rc=${PIPESTATUS[0]}
echo "[run_introseq_test] --------------------------------"

if [ "$rc" -eq 0 ]; then
    echo "[run_introseq_test] PASS"
    exit 0
fi
echo "[run_introseq_test] FAIL (asset comparison)"
exit 1
