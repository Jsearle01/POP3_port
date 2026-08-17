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
# ★ `integ` IS THE ONLY ONE THAT LOOKS AT WHAT SHIPS (P3.107). introseq/room/walk each
# boot a STANDALONE image with its own LOADM; the integrated scene is reached by a jsr from
# the intro's beat loop, runs from $2500 and returns. It is listed LAST because the other
# three are faster and a failure in them explains a failure in it.
SUITES="introseq room walk integ"

# ── RETIRED at P3.103, with what covers their ground now ─────────────────────────────
#   probe     P1.1 loop probe        -> room/walk boot through the same HAL
#   cel       P1.2 cel colour check  -> room's flame-pixel check + walk's composite diff
#   compiled  P1.3 compiled sprites  -> nothing; the engine replaced them with streams
#   mode      P2.5 mode cycling      -> ★ PARTIAL: setup covered, cycling not (unused)
#   anim      P2.6 double buffer     -> walk's page-signature guard + room's displayed diff
#
# ★ THE GENERATION STAYS. build.bat still assembles PROBE/MODE/ANIM and writes them to
# build/probe.dmk, and that is deliberate: the live suites boot from that same disk, and
# the cel pages are placed at explicit tracks after those files. Removing them moves the
# tracks. What was costing time was RUNNING them, and that is what stopped.
RETIRED="probe cel compiled mode anim"

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
