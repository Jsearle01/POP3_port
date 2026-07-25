#!/usr/bin/env python3
"""
lint.py — Milestone 5b: opacity-state determinacy lint over every [registry] cel.

Invariants (HARD ERROR on violation — the lost-shadow catch):
  authored          <=> a valid, parseable opacity sidecar exists
  converted / none  <=> NO sidecar
Also reports the 'converted' set (the self-maintaining "needs review" list).
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from placement_table import Table, ROOT
import sidecar as SC
from save import read_state

def lint(table_path=None):
    t = Table(table_path) if table_path else Table()
    errors, converted = [], []
    for sid, cel_file in t.registry.items():
        cel_dir = os.path.join(ROOT, cel_file)
        state = read_state(t.path, sid)
        try:
            sc = SC.read_sidecar(cel_dir)
        except Exception as e:
            errors.append(f"{sid}: sidecar unparseable ({e})")
            continue
        has_sc = sc is not None
        if state == "authored" and not has_sc:
            errors.append(f"{sid}: state 'authored' but NO sidecar (lost shadow)")
        elif state in ("converted", "none", None) and has_sc:
            errors.append(f"{sid}: state '{state}' but a sidecar EXISTS (orphan)")
        if state in ("converted", None):
            converted.append(sid)
    return errors, converted

def main():
    errors, converted = lint()
    print(f"opacity lint: {len(errors)} error(s); {len(converted)} cel(s) in 'converted' (needs-review) set")
    for e in errors:
        print("  ERROR", e)
    if converted:
        print("  converted set:", " ".join(sorted(converted)))
    return 1 if errors else 0

if __name__ == "__main__":
    sys.exit(main())
