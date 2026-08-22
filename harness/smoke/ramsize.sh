# harness/smoke/ramsize.sh — ONE HOME for which machine the harness runs on.
#
# ★★★ 512 KB IS THE DEFAULT AS OF P5.14, BY JAY'S RULING (2026-08-22):
#     "lets move to the 512kb as the standard."
#
# THE MEASUREMENT BEHIND IT, so the default is traceable to a fact and not to a preference.
# P5.12 costed the whole game against the free-block budget, in BLOCKS rather than bytes
# because a cel cannot straddle a block boundary:
#
#                                   128 KB (8 free)      512 KB (56 free)
#     per-level loading                 16  OVER by 8        16  fits, 40 spare
#     everything resident               44  OVER by 36       44  fits, ~12 spare
#
# and P5.12 §3A found the DEMO alone needs 10 blocks against 8. So 128 KB does not hold the
# game at any granularity, and the intro is the only thing that ever fit it.
#
# ★★ WHAT THE 512 KB DEFAULT DOES **NOT** MEAN — read this before assuming 128 KB is dead.
# P5.14 converted the TARGET and deliberately did not SPEND the space: every block the port
# uses is still $0C-$0F for the cel bank, $10-$17 for the framebuffers and $38-$3F for the
# program, exactly as before. Those are real blocks on a 512 KB machine AND they alias
# correctly on a 128 KB one, so the port still runs on 128 KB today. It stops running there
# the first time anything claims a block above $0F. Until then, MAME_RAM=128K is a live
# configuration and the suites pass on it.
#
# ★ THE INVERTED PRECEDENT IS KEPT, because it is still true and still the reason to run
# both. P3.10: buffer B at $18 was "fine on 512 KB and fatal on 128 KB: the port loaded,
# started, and died at the first framebuffer access." 512 KB can pass while a masking
# assumption is wrong; the reverse does not happen. The direction of that asymmetry has not
# changed — what changed is which machine we ship to. So:
#
#     MAME_RAM=128K  ...  run the legacy machine, which still works and still catches
#                         masking errors 512 KB cannot see
#
# and a DIVERGENCE between the two remains informative: it means something depends on
# aliasing, which after P5.14 also means something has started using the new space.
#
# ★★★ THE HISTORY, KEPT DELIBERATELY. Until P3.98 the default was 512 KB and `-ramsize` was
# passed only when MAME_RAM was set, so the bare command every acceptance criterion was
# satisfied by ran the NON-TARGET machine — a policy and a default disagreeing, which is two
# homes for one fact. Any report before P3.98 saying "green" WITHOUT naming a size was
# 512 KB; that is not a reason to re-run history, it is a reason not to cite an old bare
# "green" as evidence about a machine.
#
# The sweep that made this file the single home took three passes: P3.98 routed ten runners
# through it, P3.100 found two carrying no `-ramsize` at all, and P3.101 swept seven more
# plus `harness/tools/run_block_budget.sh`, which had the RIGHT VALUE hardcoded — the subtler
# failure, because a correct second home still cannot follow this file when the target moves.
# ★ AND THE TARGET HAS NOW MOVED, which is exactly the event that hardcoding could not
# survive. `run_block_budget.sh` still hardcodes 128K ON PURPOSE: its whole subject is what
# the GIME aliases away on a stock machine, so it is a 128 KB question by definition.
#
# ★★ THE CHECK THAT FINDS A STRAY IS MECHANICAL AND THE POLICY IS NOT. Grep for the file
# that must be sourced, not for the rule that says to source it:
#
#     grep -rl '"$MAME" coco3' harness/ | while read f; do
#         grep -q ramsize.sh "$f" || echo "$f"
#     done
#
MAME_RAM="${MAME_RAM:-512K}"
RAMOPT="-ramsize $MAME_RAM"
