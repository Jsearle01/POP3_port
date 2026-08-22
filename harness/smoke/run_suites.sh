#!/bin/bash
# harness/smoke/run_suites.sh — ONE HOME for what "the suites" means.
#
# ★★★ WHY THIS FILE EXISTS. Jay, P3.103: "tell Clyde not to run the old tests. They don't
# matter anymore. We had gotten rid of them for a while, but he is running them again."
#
# They came back because there was no such thing as "the suite set" — there was a directory
# of `run_*_test.sh` and every fresh session reconstructed the list by globbing it. A list
# rebuilt from a glob cannot remember a decision. So the list lives here, once, and the
# retired runners refuse to run on their own (harness/smoke/retired.sh).
#
# ★★ THE SAME SHAPE AS THE 512 KB DEFAULT, which reasserted itself across three dispatches
# because it lived in ten places and nobody removed it (P3.98, P3.100, P3.101). Retire, do
# not skip.
#
#   MAME_RAM=512K  ...  the confirmation machine; 128 KB is the target and the default.
set -u

cd "$(dirname "$0")/../.." || exit 1

# ── THE SUITES ───────────────────────────────────────────────────────────────────────
# The three that describe the SCENE. Each boots live-disk (CLAUDE.md §4) and compares real
# framebuffer bytes against what the content says they should be.
# ★★★ TWO SUITES SINCE P4.2, and the pair that went is the pair that mattered most.
# `room` and `walk` booted the STANDALONE ROOM.BIN — P3.107 recorded them as a coverage gap
# for exactly that reason, and Jay closed it by ruling rather than by re-pointing:
# "walk and room should be deprecated anyway. they have been gated in the intro sequence."
#
# ★★ WHAT WENT WITH THEM IS NAMED IN retired.sh AND IT IS NOT SMALL: the byte-exact pixel
# comparison, the per-page signature guard, the bank-mapped-at-capture assertion, the
# phase-occupancy census and the two-run stability check. `integ` replaces NONE of those —
# it checks that the scene is reached, returns, and that no read is revealed half-built.
# The scene's PIXELS are now gated by Jay's eye alone. That is the decision, stated.
# ★ `tile` JOINS AT P5.5, AND IT BRINGS BACK THE THING THE PARAGRAPH ABOVE MOURNS.
# The retired pair took the BYTE-EXACT PIXEL COMPARISON with them: since P4.2 no suite has
# compared a real framebuffer against what the content says it should be, and the scene's
# pixels have been gated by Jay's eye alone. run_tile_test.sh does exactly that check again
# -- 15,360 bytes of displayed buffer against bake_screen.py's reference -- for the
# gameplay background. It does NOT restore the rest of what went (no page-signature guard,
# no phase-occupancy census, no two-run stability check, and nothing about the scene); it
# restores the pixel comparison, on a different picture.
SUITES="introseq integ tile"

# ── RETIRED at P3.103, with what covers their ground now ─────────────────────────────
#   probe     P1.1 loop probe        -> room/walk boot through the same HAL
#   cel       P1.2 cel colour check  -> room's flame-pixel check + walk's composite diff
#   compiled  P1.3 compiled sprites  -> nothing; the engine replaced them with streams
#   mode      P2.5 mode cycling      -> ★ PARTIAL: setup covered, cycling not (unused)
#   anim      P2.6 double buffer     -> walk's page-signature guard + room's displayed diff
#                                        ★ which is ITSELF retired now (P4.2) — so the
#                                        page-signature guard is covered by nothing.
#   room      P3.17 the room          -> the integrated gate (P3.107); pixels by Jay's eye
#   walk      P3.31 the vizier's walk -> as above; the skip it caught was closed at P3.103
#
# ★ THE GENERATION STAYS. build.bat still assembles PROBE/MODE/ANIM and writes them to
# build/probe.dmk, and that is deliberate: the live suites boot from that same disk, and
# the cel pages are placed at explicit tracks after those files. Removing them moves the
# tracks. What was costing time was RUNNING them, and that is what stopped.
RETIRED="probe cel compiled mode anim room walk"

echo "[suites] running: $SUITES"
echo "[suites] retired at P3.103 (see harness/smoke/retired.sh): $RETIRED"
. "$(dirname "$0")/ramsize.sh"
echo "[suites] $RAMOPT"
echo

rc=0
for t in $SUITES; do
    printf '[suites] === %s ===\n' "$t"
    if bash "harness/smoke/run_${t}_test.sh" > "build/tmp/suite_${t}.log" 2>&1; then
        tail -1 "build/tmp/suite_${t}.log"
    else
        rc=1
        echo "  FAIL — build/tmp/suite_${t}.log"
        tail -20 "build/tmp/suite_${t}.log" | sed 's/^/    /'
    fi
done

echo
[ $rc -eq 0 ] && echo "[suites] ALL PASS" || echo "[suites] FAIL"
exit $rc
