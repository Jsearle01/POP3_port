#!/usr/bin/env python3
"""
save.py — Milestone 5: save an edited cel (converted.s + opacity sidecar + registry state).

Rules (from the plan):
  - converted.s written through the M1 lossless writer. OPACITY-ONLY edit => BYTE-IDENTICAL
    (black stays index-0; only the sidecar/state change). Colour edits change those bytes only.
  - Sidecar (opacity.s) written where opaque work exists; deleted when none remains.
  - Registry opacity STATE is a CONSEQUENCE of saving, never hand-set:
      save-with-opaque -> 'authored' (+ sidecar);  save-with-only-trans -> 'none' (no sidecar).
    Converter's born state 'converted' is NEVER touched for cels the user didn't open.
  - .bak per file; save only edited cels.
"""
import os, re, shutil, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from celio import Cel
import opacity as O
import sidecar as SC

def _bak(path):
    if os.path.exists(path):
        shutil.copy2(path, path + ".bak")

# ---- registry three-state in scene6_placement.txt [registry] (optional 3rd column) ----
def read_state(table_path, sprite_id):
    section = None
    for line in open(table_path, encoding="utf-8"):
        s = line.split("#", 1)[0].strip()
        if s == "[registry]": section = "reg"; continue
        if s.startswith("["):  section = None; continue
        if section == "reg":
            p = s.split()
            if p and p[0] == sprite_id:
                return p[2] if len(p) >= 3 else "converted"
    return None

def write_state(table_path, sprite_id, state):
    """Set sprite_id's [registry] state column (add/update); preserve everything else verbatim."""
    with open(table_path, "r", newline="") as f:
        raw = f.read()
    nl = "\r\n" if "\r\n" in raw else "\n"
    ends = raw.endswith(nl)
    lines = raw.split(nl)
    if ends: lines = lines[:-1]
    section = None
    for i, line in enumerate(lines):
        s = line.split("#", 1)[0].strip()
        if s == "[registry]": section = "reg"; continue
        if s.startswith("["):  section = None; continue
        if section == "reg" and s:
            p = s.split()
            if p[0] == sprite_id:
                comment = line.split("#", 1)[1] if "#" in line else None
                cols = [p[0], p[1], state]
                new = f"{cols[0]:<7} {cols[1]:<40} {cols[2]}"
                if comment is not None:
                    new += "   #" + comment
                lines[i] = new
                break
    out = nl.join(lines) + (nl if ends else "")
    with open(table_path, "w", newline="") as f:
        f.write(out)

class SaveIOError(Exception):
    """A file/.bak write failed; save.py rolled back so no half-written state remains."""

def _restore(path):
    if os.path.exists(path + ".bak"):
        shutil.copy2(path + ".bak", path)

def save_cel(cel, cel_dir, label, opacity_grid, sprite_id, table_path):
    """Derive+verify the opacity descriptor, then write converted.s + sidecar + state.
    Returns {state, kind, byte_identical}. Raises:
      - O.CannotEncode / AssertionError (STOP — marking unrepresentable; nothing written)
      - SaveIOError (a file write failed; rolled back to the pre-save state)."""
    kind, payload = O.derive(cel, opacity_grid)          # raises CannotEncode if unrepresentable
    ok, detail = O.verify(cel, opacity_grid, kind, payload)
    if not ok:
        raise AssertionError(f"opacity descriptor did NOT verify ({detail}) — STOP")

    conv = os.path.join(cel_dir, "converted.s")
    sc = SC.path_for(cel_dir)
    before = open(conv, newline="").read() if os.path.exists(conv) else None
    state_before = read_state(table_path, sprite_id)
    try:
        _bak(conv); _bak(sc)                             # back up before touching either
        cel.write(conv)                                  # M1 lossless writer
        after = open(conv, newline="").read()
        byte_identical = (before is not None and after == before)
        if kind == 'none':
            SC.remove_sidecar(cel_dir); state = 'none'
        else:
            SC.write_sidecar(cel_dir, label, kind, payload); state = 'authored'
        if state_before is not None:                     # only cels IN the [registry] track state;
            write_state(table_path, sprite_id, state)    #   standalone content cels use the sidecar alone
    except (IOError, OSError) as ex:                     # roll back — no half-written state
        _restore(conv); _restore(sc)
        if state_before is not None:
            try: write_state(table_path, sprite_id, state_before)
            except Exception: pass
        raise SaveIOError(f"write failed ({ex}); rolled back to pre-save state") from ex
    return {"state": state, "kind": kind, "byte_identical": byte_identical}
