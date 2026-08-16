# harness/smoke/ramsize.sh — ONE HOME for which machine the harness runs on.
#
# ★★ 128 KB IS THE DEFAULT BECAUSE IT IS THE TARGET AND THE HARDER CASE (CLAUDE.md §2K).
#
# The GIME masks a block number to the RAM actually installed, so on a stock 128 KB
# machine only $00-$0F exist and every number aliases mod 16 [src/hal/coco3-dsk/gfx.s:
# 405-417]. The framebuffers GFX_DB_A_BLOCK $10 and GFX_DB_B_BLOCK $14 alias to physical
# $00000 and $08000, and that leaves $0C-$0F — 32 KB, exactly one screen — for the cel
# bank. Every MMU assumption in the port is therefore under more pressure at 128 KB, and
# 512 KB can pass while one of them is wrong.
#
# ★ THERE IS A RECORDED INSTANCE. The same HAL note carries P3.10: buffer B at $18 was
# "fine on 512 KB and fatal on 128 KB: the port loaded, started, and died at the first
# framebuffer access." A 512-KB-first order would have called that build green.
#
# ★★★ AND UNTIL P3.98 THE DEFAULT WAS THE OTHER WAY, so `-ramsize` was passed ONLY when
# MAME_RAM was set and the bare command every acceptance criterion was satisfied by ran
# the NON-TARGET machine. §2K said one thing and ten runners did the other: a policy and
# a default that disagree are two homes for one fact. This file is the one home.
#
# Consequence for the record, worth stating rather than quietly fixing: any report before
# P3.98 that says "green" WITHOUT naming a size was 512 KB. That is not a reason to re-run
# history; it is a reason not to cite an old bare "green" as evidence about the target.
#
# ★★★ THE SWEEP IS COMPLETE AS OF P3.101, AND IT TOOK THREE PASSES TO GET THERE.
# P3.98 routed ten runners through this file. P3.100 found `run_cel_test.sh` and
# `run_compiled_test.sh` carrying NO `-ramsize` at all. P3.101 swept the rest and found
# SEVEN MORE (`run_change_census`, `run_erase_addr_probe`, `run_erase_trace`,
# `run_frame_baseline`, `run_peel_census`, `run_peel_skip_cost`, `run_peel_trace`) plus
# `harness/tools/run_block_budget.sh`, which had the RIGHT VALUE hardcoded — `-ramsize
# 128K` written into the command — which is the subtler failure: correct, and a second
# home, so it could not follow this file if the target ever moved.
#
# ★★ THE CHECK THAT FINDS THESE IS MECHANICAL AND THE POLICY IS NOT. Grep for the file
# that is supposed to be sourced, not for the rule that says to source it:
#
#     grep -rl '"$MAME" coco3' harness/ | while read f; do
#         grep -q ramsize.sh "$f" || echo "$f"
#     done
#
# Reading §2K again would have found none of the nine. Every runner that starts `mame
# coco3` must reach it through here — that is what "one home" means operationally.
#
#   MAME_RAM=512K  ...   run the confirmation machine instead
#
# 512 KB stays worth running when a change touches the MMU, the bank, the framebuffers or
# the loader — a DIVERGENCE between the two is itself informative, because it means
# something depends on aliasing.
MAME_RAM="${MAME_RAM:-128K}"
RAMOPT="-ramsize $MAME_RAM"
