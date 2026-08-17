#!/bin/bash
# harness/smoke/run_exit_column_oracle.sh — P3.100 AC2/AC5, the ORACLE half.
#
# The oracle's own drawn column for the vizier's six walk cels during the exit, measured
# on the running machine. NEITHER SIDE OF THIS COMPARISON MAY COME FROM A FORMULA: the
# port's `cel_parity_rule.draw_x` is a transcription of MLayGen, so an offline comparison
# of the two agrees by construction and cannot detect a difference (P3.99).
#
# Control first, same order and same reason as the port runner.
# The oracle image is READ-ONLY — run_oracle_trace.sh copies it before the emulator opens.
set -u

cd "$(dirname "$0")/../.." || exit 1
mkdir -p build/tmp

rc=0

echo "[exit_column_oracle] === seeded control ==="
P_LUA=harness/tools/oracle_exit_column.lua \
P_OUT=build/tmp/oracle_exit_column_seeded.log \
P_SECS="${P_SECS_SEED:-115}" P_SEED=1 \
    bash harness/smoke/run_oracle_trace.sh || rc=1
if ! grep -q "^# CONTROL PASSED" build/tmp/oracle_exit_column_seeded.log 2>/dev/null; then
    echo "[exit_column_oracle] SEEDED CONTROL DID NOT PASS — the tap is not an instrument."
    rc=1
fi

echo "[exit_column_oracle] === measurement ==="
P_LUA=harness/tools/oracle_exit_column.lua \
P_OUT=build/tmp/oracle_exit_column.log \
P_SECS="${P_SECS:-150}" P_SEED=0 \
    bash harness/smoke/run_oracle_trace.sh >/dev/null 2>&1 || rc=1
if [ -f build/tmp/oracle_exit_column.log ]; then
    sed 's/^/  /' build/tmp/oracle_exit_column.log
else
    echo "  (no log produced)"; rc=1
fi

echo "[exit_column_oracle] --------------------------------"
[ $rc -eq 0 ] && echo "[exit_column_oracle] OK" || echo "[exit_column_oracle] FAIL"
exit $rc
