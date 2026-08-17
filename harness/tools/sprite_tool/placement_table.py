#!/usr/bin/env python3
"""
placement_table.py — read POP's scene placement table into a structured model.

Wraps the CLAUDE.md §2F single-home table format:
  [registry]   sprite_id  cel_file
  [placement]  placement_id sprite_id col sub row     (static single position)
  [fuji]       sprite_id col sub row
  [animation]  <name>:  then rows "frame dwell cel:col,sub,row ..."  (animated, per-frame/part)
               optional "@loop <first_fid> <last_fid>" — the repeating span (see anim_loop)

Read fresh each open; no persisted manifest (§2F).
"""
import os, re

# ROOT = repo root, by depth: harness/tools/sprite_tool/<this file> -> 4x dirname.
# POP places the tool at the SAME depth as karateka, so this is unchanged.
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

# PORT NOTE (P1.2): karateka hard-defaulted to content/scene6/scene6_placement.txt --
# one scene, because that was the scene it was authoring. POP has no scene table yet
# (CLAUDE.md §2F: placement lives in the table, and the table IS the living scene
# registry; it is created when POP's first scene is placed). Default to a repo-level
# table and allow an env override, so the tool is usable before that exists.
DEFAULT = os.environ.get("POP_PLACEMENT_TABLE",
                         os.path.join(ROOT, "content", "placement.txt"))

class Part:
    """A composited cel. SINGLE position (row1=None) or a VERTICAL TILE (row1/step set): the
    same cel drawn at row, row+step, ... up to and including row1 — used for the arch's pillars
    (e.g. a 2-row cel tiled every 2 rows to build a tall vertical strip)."""
    def __init__(self, cel_id, col, sub, row, row1=None, step=None):
        self.cel_id, self.col, self.sub, self.row = cel_id, col, sub, row
        self.row1, self.step = row1, step
    @property
    def x_px(self):  return self.col * 4 + self.sub   # sub-byte pixel origin (4 px/byte)
    @property
    def y_px(self):  return self.row
    @property
    def tiled(self): return self.row1 is not None
    def rows(self):
        """Every row this part draws at (one value if single)."""
        if not self.tiled:
            return [self.row]
        return list(range(self.row, self.row1 + 1, self.step))

class Frame:
    def __init__(self, fid, dwell, parts):
        self.fid, self.dwell, self.parts = fid, dwell, parts

class Table:
    def __init__(self, path=DEFAULT):
        self.path = path
        self.registry = {}    # sprite_id -> cel_file (repo-relative)
        self.placement = {}   # placement_id -> (sprite_id, col, sub, row)
        self.fuji = {}        # sprite_id -> (col, sub, row)
        self.anim = {}        # block_name -> [Frame, ...]
        self.anim_loop = {}   # block_name -> (first_fid, last_fid) from @loop, or absent
        self._parse()

    def _parse(self):
        section, block = None, None
        # PORT NOTE (P1.2): karateka always had a scene table, so a missing file was
        # never a case. POP's table does not exist until its first scene is placed
        # (CLAUDE.md §2F), and a hard FileNotFoundError here kills the authoring tool
        # before it can open a single cel. An absent table is an EMPTY table: the
        # registry/placement/animation maps stay empty and the tool falls back to the
        # per-category cel list, which is exactly the right view pre-placement.
        if not os.path.exists(self.path):
            return
        with open(self.path, encoding="utf-8") as fh:
            for line in fh:
                s = line.split("#", 1)[0].strip()
                if not s:
                    continue
                if s == "[registry]":  section = "reg";  continue
                if s == "[placement]": section = "plc";  continue
                if s == "[fuji]":      section = "fuji"; continue
                if s == "[animation]": section = "anim"; block = None; continue
                p = s.split()
                if section == "reg":
                    self.registry[p[0]] = p[1]
                elif section == "plc":
                    self.placement[p[0]] = (p[1], int(p[2]), int(p[3]), int(p[4]))
                elif section == "fuji":
                    self.fuji[p[0]] = (int(p[1]), int(p[2]), int(p[3]))
                elif section == "anim":
                    if len(p) == 1 and s.endswith(":"):
                        block = s[:-1]; self.anim[block] = []; continue
                    if p[0] == "@loop":            # directive, not a frame: the repeating span
                        self.anim_loop[block] = (p[1], p[2]); continue
                    fid, dwell, toks = p[0], int(p[1]), p[2:]
                    parts = []
                    for t in toks:
                        cel, csr = t.split(":")
                        v = [int(x) for x in csr.split(",")]
                        if len(v) == 3:                      # col,sub,row  — single position
                            parts.append(Part(cel, v[0], v[1], v[2]))
                        elif len(v) == 5:                    # col,sub,row0,row1,step — vertical tile
                            parts.append(Part(cel, v[0], v[1], v[2], v[3], v[4]))
                        else:
                            raise ValueError(f"[animation] {block} {fid}: part '{t}' must be "
                                             f"cel:col,sub,row or cel:col,sub,row0,row1,step")
                    self.anim[block].append(Frame(fid, dwell, parts))

    def cel_path(self, cel_id):
        return os.path.join(ROOT, self.registry[cel_id], "converted.s")

    def loop_span(self, block):
        """(first_index, last_index) of the block's repeating span, or None if it has no @loop.
        Raises if @loop names a frame the block doesn't have — a silent wrong loop is worse."""
        if block not in self.anim_loop:
            return None
        first, last = self.anim_loop[block]
        ids = [f.fid for f in self.anim[block]]
        for fid in (first, last):
            if fid not in ids:
                raise ValueError(f"[animation] {block}: @loop names unknown frame '{fid}' "
                                 f"(block has {ids})")
        i, j = ids.index(first), ids.index(last)
        if i > j:
            raise ValueError(f"[animation] {block}: @loop {first}..{last} runs backwards")
        return i, j
