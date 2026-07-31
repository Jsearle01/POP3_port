#!/usr/bin/env bash
# harness/smoke/run_peel_matrix.sh — the PEEL REGRESSION MATRIX (P3.30, AC4).
#
# WHY THIS EXISTS, and why it is a matrix rather than a case.
#
# Three accumulating bugs have lived in the peel, and every one was found only when a
# NEW USAGE PATTERN reached it — never by the tests that existed at the time:
#
#   P3.21  the peel rotated: erase restored the wrong slot's background
#   P3.25  the peel buffer was sized to one cel, so a wider cel overran it
#   P3.28  a cel change with no movement skipped the peel entirely
#
# The tests were not weak. They were exercising ONE CORNER of the peel's state space —
# a demo that changed state once every four steps. Each new dispatch's demo reached a
# little further in and found the next bug. This suite is the corner-sweep done on
# purpose instead of by accident.
#
# THE AXES, and what each exists to catch:
#
#   POSITION  fixed / changing every step
#             Movement is what makes erase-at-the-old-position load-bearing. P3.22
#             erased at the NEW position, which is harmless only while nothing moves.
#
#   CEL       fixed / changing every step
#             A cel change alters the footprint's CONTENT without necessarily altering
#             its position. P3.28 defect 1 lived here: the moved-test compared x and y
#             only, so a new cel drew over the old one's pixels with no restore.
#
#   OVERLAP   small step (footprints overlap) / large step (disjoint)
#             P3.28's lead was that overlap made peel ORDERING load-bearing. Ablation
#             disproved it — the disjoint case failed too — but the axis is kept
#             because it is cheap and it is what RETIRED that hypothesis.
#
#   DENSITY   is implicit in "every step": the sparse four-step demo passed while all
#             of these failed, which is the whole reason the suite exists.
#
# BOTH BUFFERS are exercised by construction: the page flips every frame while the VM
# steps every ~2.74, so any run of more than a few frames drives both slots. The
# per-(character,slot) state is what P3.21 and P3.25 corrupted.
#
# EVERY CASE ASSERTS TWO THINGS: zero wrong bytes AND capture-to-capture stability.
# The second is not decoration — an accumulating bug is invisible to a single capture,
# and variants B, D and E each showed 0 at ONE capture while failing at the other.
#
# WOULD IT HAVE CAUGHT THE THREE? P3.21 (rotation) and P3.25 (dimensions) both need a
# cel change plus movement across both buffers — case D. P3.28 defect 1 needs a cel
# change with the position FIXED — case C, which no demo before P3.28 ever ran.
set -u
cd "$(dirname "$0")/../.." || exit 1
exec python harness/tools/peel_matrix.py "$@"
