#!/usr/bin/env python3
"""
edit_model.py — Milestone 4 paint model: color + opacity layers, undo/redo, changed-set.

Palette -> (color index, opacity):
  white -> 3    blue -> 2    orange -> 1        (colours: always drawn; opacity N/A)
  black -> 0, OPAQUE (shadow, stored solid)     trans -> 0, KEYED (transparent)
Black and trans are the SAME colour (index 0), different opacity — the shadow-task feature.

FIXED dims: painting only changes pixel CONTENTS (colour + opacity); never a cel's
size/origin (registration can't drift). Edits route to the owning/selected cel.
"""
import copy, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from celio import Cel
import opacity as O
import sidecar as SC

PALETTE = {
    'white':  (3, None), 'blue': (2, None), 'orange': (1, None),
    'black':  (0, True),  'trans': (0, False),
}

class CelEdit:
    """One editable cel: its pixel grid + opacity grid, undo/redo, original snapshot."""
    def __init__(self, cel_id, cel, cel_dir, label, sprite_id):
        self.cel_id, self.cel, self.cel_dir, self.label, self.sprite_id = \
            cel_id, cel, cel_dir, label, sprite_id
        self.opacity = O.blank_opacity(cel)
        self.reload_error = None
        # PART C: reload an authored cel's saved shadow (opacity.s sidecar) into the edit layer,
        # so re-open shows it and a paint+save refines rather than overwrites. Gated: the reloaded
        # marks must re-derive to the byte-identical descriptor, else STOP (keep blank + surface).
        sc = SC.read_sidecar(cel_dir)
        if sc:
            ok, decoded, detail = O.reload_is_lossless(cel, sc[0], sc[1])
            if ok:
                self.opacity = decoded
            else:
                self.reload_error = f"{cel_id}: {detail}"
        self.orig_pixels = copy.deepcopy(cel.pixels)
        self.orig_opacity = copy.deepcopy(self.opacity)
        self.undo, self.redo = [], []

    def begin_stroke(self):
        self.undo.append((copy.deepcopy(self.cel.pixels), copy.deepcopy(self.opacity)))
        self.redo.clear()
        if len(self.undo) > 200: self.undo.pop(0)

    def paint(self, px, py, entry):
        """Set local pixel (px,py) to a palette entry. Caller wraps a stroke in begin_stroke()."""
        if not (0 <= py < self.cel.h and 0 <= px < self.cel.w * 4):
            return False
        color, opaque = PALETTE[entry]
        self.cel.pixels[py][px] = color
        if color == 0:
            self.opacity[py][px] = bool(opaque)
        else:
            self.opacity[py][px] = False        # colour pixel: opacity N/A (kept False)
        return True

    def undo_stroke(self):
        if not self.undo: return False
        self.redo.append((copy.deepcopy(self.cel.pixels), copy.deepcopy(self.opacity)))
        self.cel.pixels, self.opacity = self.undo.pop()
        return True

    def redo_stroke(self):
        if not self.redo: return False
        self.undo.append((copy.deepcopy(self.cel.pixels), copy.deepcopy(self.opacity)))
        self.cel.pixels, self.opacity = self.redo.pop()
        return True

    def changed(self):
        """Set of (px,py) differing from the on-open original (colour or opacity)."""
        out = set()
        for r in range(self.cel.h):
            for c in range(self.cel.w * 4):
                if (self.cel.pixels[r][c] != self.orig_pixels[r][c]
                        or self.opacity[r][c] != self.orig_opacity[r][c]):
                    out.add((c, r))
        return out

    def is_edited(self):
        return bool(self.changed())

    # ---- Part 3 (buffer-based): full-edit-state snapshot for the one-shot revert buffer ----
    # The snapshot captures the canvas (pixels+opacity) AND the ordered stroke stacks, so
    # Undo-Revert restores the undo stack WHOLESALE — same structure, EXACT original order.
    # It is restored as-is (a copy of the stored list), never replayed/rebuilt, so no inversion.
    def snapshot(self):
        return (copy.deepcopy(self.cel.pixels), copy.deepcopy(self.opacity),
                copy.deepcopy(self.undo), copy.deepcopy(self.redo))

    def restore(self, snap):
        self.cel.pixels = copy.deepcopy(snap[0]); self.opacity = copy.deepcopy(snap[1])
        self.undo = copy.deepcopy(snap[2]); self.redo = copy.deepcopy(snap[3])

    def revert_to_baseline(self):
        """Snap New back to the Old/last-saved baseline; reset the stroke stacks to it."""
        self.cel.pixels = copy.deepcopy(self.orig_pixels)
        self.opacity = copy.deepcopy(self.orig_opacity)
        self.undo.clear(); self.redo.clear()

    def mark_saved(self):
        """After a save, the current state becomes the new Old baseline (clean)."""
        self.orig_pixels = copy.deepcopy(self.cel.pixels)
        self.orig_opacity = copy.deepcopy(self.opacity)

class FrameEdit:
    """Editable cels for an assembled frame; routes canvas paint to the selected cel."""
    def __init__(self, table, frame):
        self.table, self.frame = table, frame
        self.cels = {}
        for pc in frame.placed:
            # cel_dir carried on the PlacedCel (works for table cels AND standalone content cels
            # not in the registry — Part A). label/sprite_id default to the cel dir's basename.
            cel_dir = pc.cel_dir
            self.cels[pc.cel_id] = CelEdit(pc.cel_id, pc.cel, cel_dir, os.path.basename(cel_dir), pc.cel_id)
        self.selected = frame.placed[-1].cel_id if frame.placed else None

    def reload_errors(self):
        return [ce.reload_error for ce in self.cels.values() if ce.reload_error]

    # ---- Part 2/3: dirty flag + Revert-to-Old / one-shot Undo-Revert state machine ----
    def is_dirty(self):
        return any(ce.is_edited() for ce in self.cels.values())

    def can_undo(self):
        """Undo is valid iff some cel has a stroke to undo (aggregate — do_undo undoes all cels)."""
        return any(ce.undo for ce in self.cels.values())

    def can_redo(self):
        """Redo is valid iff some cel has a redone-able stroke (empty after a new paint clears redo)."""
        return any(ce.redo for ce in self.cels.values())

    def revert_all(self):
        """Revert every cel to its baseline (the guard's Discard + the Revert-to-Old button share
        this). Captures a one-shot pre-revert snapshot so Undo-Revert can restore it."""
        self._pre_revert = {cid: ce.snapshot() for cid, ce in self.cels.items()}
        for ce in self.cels.values():
            ce.revert_to_baseline()
        self._just_reverted = True

    def can_undo_revert(self):
        return bool(getattr(self, "_just_reverted", False) and getattr(self, "_pre_revert", None))

    def undo_revert(self):
        if not self.can_undo_revert():
            return False
        # Restore each cel's canvas AND ordered undo stack wholesale from the one-shot buffer,
        # then CONSUME the buffer (§3). dirty is implicitly set (canvas now differs from Old).
        for cid, snap in self._pre_revert.items():
            self.cels[cid].restore(snap)
        self._just_reverted = False
        self._pre_revert = None
        return True

    def touched(self):
        """Any edit/save/switch invalidates the one-shot Undo-Revert AND clears the buffer
        (§3: the buffer is cleared by any edit/save/switch, not merely grayed)."""
        self._just_reverted = False
        self._pre_revert = None

    def mark_saved(self):
        for ce in self.cels.values():
            ce.mark_saved()
        self._just_reverted = False
        self._pre_revert = None

    def paint_canvas(self, canvas_px, canvas_py, entry):
        """Paint a CANVAS pixel: route to the selected owning cel; returns the cel_id painted or None."""
        cpx, cpy = self.frame.x0 + canvas_px, self.frame.y0 + canvas_py
        owners = [p for p in self.frame.placed if p.covers(cpx, cpy)]
        target = next((p for p in owners if p.cel_id == self.selected), owners[-1] if owners else None)
        if target is None:
            return None
        ce = self.cels[target.cel_id]
        ce.paint(cpx - target.x, cpy - target.y, entry)
        self.touched()                    # an edit invalidates the one-shot Undo-Revert
        return target.cel_id

    def edited_cels(self):
        return [ce for ce in self.cels.values() if ce.is_edited()]
