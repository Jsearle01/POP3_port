# harness/smoke/retired.sh — ONE HOME for what "retired" means and why.
#
# ★★★ JAY, P3.103: "tell Clyde not to run the old tests. They don't matter anymore. We had
# gotten rid of them for a while, but he is running them again."
#
# ★★ RETIRED, NOT SKIPPED. A suite that is merely not-run-today gets reinstated the next
# time a fresh session goes looking for "the full suite" and finds a runner sitting there —
# which is exactly how it came back this time. The 512 KB default did the same thing across
# ten homes for three dispatches (P3.98, P3.100, P3.101). So the refusal lives IN the
# runner, with its reason attached, and it travels with the file.
#
# Sourced as:   . "$(dirname "$0")/retired.sh"; retired "<what it covered>" "<what covers it now>"
#
# POP_RUN_RETIRED=1 runs it anyway, for the case where someone is deliberately re-testing
# the P1/P2 substrate. That is an override with a name, not a default.
retired() {
    echo "[$(basename "$0" .sh)] RETIRED (P3.103) — this suite is no longer part of the run."
    echo "    covered:     $1"
    echo "    covered now: $2"
    if [ "${POP_RUN_RETIRED:-0}" = "1" ]; then
        echo "    POP_RUN_RETIRED=1 — running it anyway."
        return 0
    fi
    echo "    set POP_RUN_RETIRED=1 to run it anyway. See harness/smoke/run_suites.sh."
    exit 0
}
