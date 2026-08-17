#!/usr/bin/env python3
"""
catalog.py — enumerate content categories + the frames/cels in each (Part A).

Category = a content/<category>/ dir that holds cels. POP's categories are the cel
tables' subjects -- kid, guard, shadow, skeleton, vizier, fat, princess, scenery,
hud, title, font, unsorted, ... (karateka's were player/akuma/bird/broderbund/...).
The mechanism is category-name agnostic: any content/ subdir holding */converted.s
is a category. Within a category:
  - cels that belong to an [animation] block show as ASSEMBLED frames (existing sub-byte assembly);
  - all other cels show as INDIVIDUAL cels (standalone, authorable at their own dims).
No composition is invented for non-animation cels — individual is the correct current-state view.
"""
import os, glob
from placement_table import ROOT

CONTENT = os.path.join(ROOT, "content")

def categories(table):
    """content/ subdirs that actually contain cels, sorted; 'unsorted' = uncategorized."""
    out = []
    for d in sorted(os.listdir(CONTENT)):
        p = os.path.join(CONTENT, d)
        if os.path.isdir(p) and glob.glob(os.path.join(p, "*", "converted.s")):
            out.append(d)
    return out

def _block_category(table, block):
    cats = set()
    for fr in table.anim[block]:
        for part in fr.parts:
            if part.cel_id in table.registry:
                cats.add(table.registry[part.cel_id].split("/")[1])
    return cats

CELS_GROUP = "(individual cels)"

def groups_for(table, cat):
    """The category's GROUPS, for the secondary selector: one per [animation] block whose cels
    live in `cat`, plus CELS_GROUP for the standalone cels. Scopes the frame list, which grows
    unwieldy once a category holds several animations (player: climb_crawl + run + its cast)."""
    blocks = [b for b in table.anim if cat in _block_category(table, b)]
    out = list(blocks)
    if _loose_cels(table, cat, blocks):
        out.append(CELS_GROUP)
    return out

def _anim_dirs(table, blocks):
    dirs = set()
    for block in blocks:
        for fr in table.anim[block]:
            for part in fr.parts:
                if part.cel_id in table.registry:
                    dirs.add(os.path.normpath(os.path.join(ROOT, table.registry[part.cel_id])))
    return dirs

def _loose_cels(table, cat, blocks):
    """Cel dirs in `cat` that no animation block uses."""
    used = _anim_dirs(table, blocks)
    return [d for d in sorted(glob.glob(os.path.join(CONTENT, cat, "*")))
            if os.path.isdir(d) and os.path.exists(os.path.join(d, "converted.s"))
            and os.path.normpath(d) not in used]

def entries_for(table, cat, group=None):
    """List of (label, kind, arg):
         kind='anim' arg=(block, index) — an assembled animation frame
         kind='cel'  arg=cel_dir        — a standalone individual cel
       group=None  -> everything in the category (animation frames first, then loose cels)
       group=<block name> -> only that block's frames, in file order
       group=CELS_GROUP   -> only the loose cels"""
    blocks = [b for b in table.anim if cat in _block_category(table, b)]
    out = []
    if group is None or group != CELS_GROUP:
        for block in ([group] if group in blocks else blocks if group is None else []):
            for i, fr in enumerate(table.anim[block]):
                out.append((f"{block} {fr.fid}", "anim", (block, i)))
    if group is None or group == CELS_GROUP:
        for celdir in _loose_cels(table, cat, blocks):
            out.append((os.path.basename(celdir), "cel", celdir))
    return out
