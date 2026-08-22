#!/bin/bash
# harness/smoke/run_compiled_test.sh — P1.3: run a COMPILED sprite on the real GIME.
#
# Compiles a cel with harness/tools/sprite_compiler.py, assembles the emitted
# 6809 with LWTools into src/harness/compiled_probe.s, boots it under MAME, and
# diffs the framebuffer against what the cel should look like — INCLUDING the
# canary in transparent bytes, which is how transparency is proven preserved
# rather than painted black.
#
# Usage:  harness/smoke/run_compiled_test.sh <cel_dir>
set -u

. "$(dirname "$0")/retired.sh"
retired "P1.3 compiled sprites — sprite_compiler.py's emitted 6809 on the real GIME" \
        "nothing, and nothing needs to: the engine REPLACED compiled sprites with segment streams [src/engine/flame_cels.s:56], so this tested a tool that produces nothing the port ships"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$REPO_ROOT"

CEL_DIR="${1:-content/kid/kid_chtab1_040_large}"
NAME="$(basename "$CEL_DIR")"
MAME="${MAME:-/c/mame/mame}"; MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
LWASM="${LWASM:-/c/WIN_LWTools/lwasm}"
mkdir -p build
LOG=build/compiled_test.log; PASS=build/compiled_test_PASS; FAIL=build/compiled_test_FAIL
rm -f "$PASS" "$FAIL" "$LOG"

echo "[run_compiled_test] cel: $CEL_DIR"

# Orientation guard first (P1.2-fix): a flipped cel must never reach a green run.
python harness/tools/verify_orientation.py "$CEL_DIR" || {
    echo "[run_compiled_test] FAIL — orientation guard rejected $CEL_DIR" >&2; exit 1; }

python harness/tools/sprite_compiler.py "$CEL_DIR" --out build/compiled || exit 1

# Slice out just the draw routine; compiled_probe.s supplies the cp_draw label.
python3 - "$NAME" <<'PYEOF'
import pathlib, sys
name = sys.argv[1]
src = pathlib.Path(f"build/compiled/{name}.s").read_text()
i = src.index(f"_draw_{name}:")
j = src.index("\n", src.index("        rts", i))
body = src[i:j].split("\n", 1)[1]
pathlib.Path("build/cp_include.s").write_text(body + "\n", newline="\n")
PYEOF

"$LWASM" --decb -I . -o build/compiled_probe.bin src/harness/compiled_probe.s || {
    echo "[run_compiled_test] ERROR: assembly failed" >&2; exit 1; }
echo "[run_compiled_test] assembled build/compiled_probe.bin ($(wc -c < build/compiled_probe.bin) bytes)"

# Expected framebuffer, derived from the CEL (not from the compiler's emission).
python3 - "$CEL_DIR" > build/compiled_expect.txt <<'PYEOF'
import sys, pathlib
sys.path.insert(0,"harness/tools"); sys.path.insert(0,"harness/tools/sprite_tool")
from celio import Cel
import sidecar as SC
from sprite_compiler import expand_opacity, tokenize, pack
d = pathlib.Path(sys.argv[1])
cel = Cel(str(d/"converted.s"))
op,_ = expand_opacity(cel, SC.read_sidecar(str(d)))
packed = pack(tokenize(cel, op))
CANARY = 0xA5
print(f"{cel.h} {cel.w}")
for row in packed:
    vals=[]
    for val, keep, cls in row:
        vals.append(CANARY if cls=='skip' else (val if cls=='store' else (CANARY & keep) | val))
    print(" ".join(str(v) for v in vals))
PYEOF
echo "[run_compiled_test] expected: $(head -1 build/compiled_expect.txt) (rows bytes)"

export P_BIN=build/compiled_probe.bin P_EXPECT=build/compiled_expect.txt
export P_OUT="$LOG" P_PASS="$PASS" P_FAIL="$FAIL"

# -cfg_directory: MAME's Monitor Type default is COMPOSITE (value 0, confirmed via
# `mame -listxml coco3`). CLAUDE.md §4 makes RGB the project's gate, so it must be
# set explicitly or the visual gate silently runs in the wrong mode — which is how
# the harness palette read yellow instead of orange until Jay spotted it.
# ★ 128 KB, THE TARGET (CLAUDE.md §2K), THROUGH THE ONE HOME FOR THAT FACT — see the same
# note in run_cel_test.sh. These two were the pair P3.98's sweep left carrying no -ramsize
# at all, so every "green" they have ever reported was on the non-target machine.
. "$(dirname "$0")/ramsize.sh"
. "$(dirname "$0")/cfgdir.sh"

"$MAME" coco3 -rompath "$MAME_ROMS" $RAMOPT $CFGOPT \
    -ext fdc -window -nomaximize \
    -nothrottle -sound none -seconds_to_run 30 \
    -autoboot_script harness/smoke/compiled_test.lua >/dev/null 2>&1

echo "[run_compiled_test] --- verifier log ---"
[ -f "$LOG" ] && sed 's/^/  /' "$LOG" || echo "  (no log)"
echo "[run_compiled_test] --------------------"
if [ -f "$PASS" ]; then echo "[run_compiled_test] PASS"; exit 0
else echo "[run_compiled_test] FAIL"; [ -f "$FAIL" ] && sed 's/^/  /' "$FAIL"; exit 1; fi
