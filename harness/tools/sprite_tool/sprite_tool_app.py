#!/usr/bin/env python3
"""
sprite_tool_app.py — hand-authoring sprite tool (M1-M5 wired).

  python harness/tools/sprite_tool/sprite_tool_app.py [block frame_index | placement_id]
  default: climb_crawl 0

Load/assemble a frame from the §2F table (sub-byte), aspect-correct render (non-square 4x5
cells, integer zoom, nearest), paint colour + opacity (white/blue/orange/black-opaque/trans),
undo/redo, changed-pixel highlight, cel selector for overlap routing, coord+owner readout,
and SAVE (converted.s byte-identical for opacity-only + opacity sidecar + registry state,
derive-and-verify, .bak). FIXED dims — painting never changes a cel's size/origin.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from placement_table import Table
from frame_assembly import assemble_animation, assemble_static, assemble_cel
import catalog
from pixel_map import CELL_W, CELL_H, screen_to_sprite
from render import render_frame
from edit_model import FrameEdit, PALETTE
import opacity as O
from save import save_cel, SaveIOError

SWATCH_RGB = {"white": "#FFFFFF", "blue": "#00AAFF", "orange": "#FF5500",
              "black": "#000000", "trans": "#808080"}
ARM = "#FFE400"      # armed-swatch highlight border

MARGIN = 10

def build_frame(table, args):
    if len(args) >= 2:
        return assemble_animation(table, args[0], int(args[1])), (args[0], int(args[1]))
    if len(args) == 1:
        return assemble_static(table, args[0]), (args[0],)
    return assemble_animation(table, "climb_crawl", 0), ("climb_crawl", 0)

def main():
    table = Table()
    frame, _ = build_frame(table, sys.argv[1:])   # placeholder; select_category() loads the real first entry
    edit = FrameEdit(table, frame)

    try:
        import tkinter as tk
        from PIL import ImageTk
    except Exception as e:
        print(f"GUI needs Tkinter + Pillow on a machine with a display: {e}")
        print(f"(headless: frame '{frame.label}' {frame.W}x{frame.H}px, cels {list(edit.cels)} — "
              f"assembly/edit model work; run on your desktop for the UI.)")
        return

    root = tk.Tk()
    root.title(f"sprite tool — {frame.label}")
    root.minsize(1120, 720)      # below this the toolbar rows clip and controls vanish silently
    state = {"zoom": 4, "entry": "black", "img": None, "painting": False}

    # TWO toolbar rows. The selectors get their own row because an OptionMenu sizes itself to the
    # SELECTED label: switching group to `climb_crawl f0` (14 chars) from `run s0` (6) widened the
    # row, overflowed the window, and Tk clipped the right-hand button cluster from its left edge —
    # the Play button silently vanished. Separate rows + fixed menu widths remove the contention.
    bar = tk.Frame(root); bar.pack(fill="x")
    selbar = tk.Frame(root); selbar.pack(fill="x")
    # FIXED width (monospace) + left-anchored so the readout's changing text never resizes the
    # label and shoves the palette/controls to its right.
    coord = tk.Label(bar, text="move over a pixel…", font=("Consolas", 10), width=46, anchor="w")
    coord.pack(side="left", padx=6)
    # palette — each swatch shows its colour; the ARMED one gets a bright highlight border
    swatches = {}
    def arm(n):
        state["entry"] = n
        for nm, fr in swatches.items():
            fr.config(bg=ARM if nm == n else bar.cget("bg"),
                      highlightbackground=ARM if nm == n else bar.cget("bg"))
    for name in ("white", "blue", "orange", "black", "trans"):
        fr = tk.Frame(bar, bg=bar.cget("bg"), bd=0, padx=3, pady=3); fr.pack(side="left")
        tk.Button(fr, text=name, bg=SWATCH_RGB[name],
                  fg="#000000" if name in ("white", "orange", "trans") else "#FFFFFF",
                  activebackground=SWATCH_RGB[name], width=6,
                  command=lambda n=name: (arm(n))).pack()
        swatches[name] = fr
    # THREE-LEVEL scoping: category -> group -> frame/cel. The group level exists because a
    # category's flat list gets unwieldy (player alone is 77 entries); a group is one [animation]
    # block (its frames, in file order) or the standalone cels.
    cats = catalog.categories(table)
    init_cat = "player"
    entry_by_label = {}                                  # label -> (kind, arg) for the current group
    entry_order = []                                     # labels in list order (playback walks this)
    tk.Label(selbar, text="category:").pack(side="left")
    catvar = tk.StringVar(value=init_cat)
    tk.OptionMenu(selbar, catvar, *cats,
                  command=lambda c: select_category(c)).pack(side="left")
    # GROUP selector (secondary) -> one animation block, or the loose cels.
    tk.Label(selbar, text="group:").pack(side="left", padx=(8, 0))
    groupvar = tk.StringVar(value="")
    groupmenu = tk.OptionMenu(selbar, groupvar, "")
    groupmenu.config(width=16, anchor="w")           # FIXED width: label length can't reflow the row
    groupmenu.pack(side="left")
    # FRAME/CEL selector (scoped to category+group): anim frames assembled, other cels standalone.
    tk.Label(selbar, text="frame/cel:").pack(side="left", padx=(8, 0))
    framevar = tk.StringVar(value="")
    framemenu = tk.OptionMenu(selbar, framevar, "")
    framemenu.config(width=24, anchor="w")           # FIXED width (longest label is a cel dir name)
    framemenu.pack(side="left")
    prev_label = [None]
    prev_cat = [init_cat]
    prev_group = [None]
    # cel selector (overlap routing only) — also on the selector row, same reason.
    tk.Label(selbar, text="paint cel:").pack(side="left", padx=(8, 0))
    celvar = tk.StringVar(value=edit.selected)
    def on_cel(*_): edit.selected = celvar.get()
    celmenu = tk.OptionMenu(selbar, celvar, *edit.cels.keys(), command=on_cel)
    celmenu.config(width=10, anchor="w")
    celmenu.pack(side="left")

    # canvas in a frame with vertical + horizontal scrollbars, so a zoomed image can be panned.
    cframe = tk.Frame(root); cframe.pack(fill="both", expand=True)
    vbar = tk.Scrollbar(cframe, orient="vertical")
    hbar = tk.Scrollbar(cframe, orient="horizontal")
    canvas = tk.Canvas(cframe, width=1040, height=640, bg="#282828",
                       xscrollcommand=hbar.set, yscrollcommand=vbar.set)
    vbar.config(command=canvas.yview); hbar.config(command=canvas.xview)
    vbar.pack(side="right", fill="y"); hbar.pack(side="bottom", fill="x")
    canvas.pack(side="left", fill="both", expand=True)
    # mouse wheel = vertical pan; Shift+wheel = horizontal (Windows delta is ±120 per notch)
    canvas.bind("<MouseWheel>",       lambda e: canvas.yview_scroll(-e.delta // 120, "units"))
    canvas.bind("<Shift-MouseWheel>", lambda e: canvas.xview_scroll(-e.delta // 120, "units"))
    # prominent SAVE banner (bottom): only save writes it, so redraw() can't clobber the result.
    savebar = tk.Label(root, text="ready — paint, then Save (Ctrl-S)", anchor="w",
                       font=("Consolas", 12, "bold"), fg="white", bg="#444",
                       padx=10, pady=8, justify="left", wraplength=1100)
    savebar.pack(side="bottom", fill="x")
    status = tk.Label(root, text="", anchor="w", font=("Consolas", 9))
    status.pack(side="bottom", fill="x")

    def opac_map():  return {cid: ce.opacity for cid, ce in edit.cels.items()}
    def chg_map():   return {cid: ce.changed() for cid, ce in edit.cels.items()}

    def _pos_text():
        """`frame 6/12 dwell 11 VBL (184 ms)` — where you are in the group while stepping.
        Reads prev_label[0] (what _load actually loaded), not framevar, so it can't lag."""
        if not entry_order or prev_label[0] not in entry_order:
            return ""
        i = entry_order.index(prev_label[0])
        txt = f"frame {i+1}/{len(entry_order)}"
        block = groupvar.get()
        if block in table.anim:
            d = table.anim[block][i].dwell
            txt += f"  dwell {d} VBL ({round(d * 1000 / 59.94)} ms)"
        return txt

    LABEL_H = 18
    def redraw():
        z = state["zoom"]
        # OLD (baseline) never changes while painting — render it once and cache. Re-render only
        # when the baseline or zoom changes (frame load / save / revert / zoom). This halves the
        # per-stroke render cost, which was the paint lag.
        if state.get("old_dirty", True) or state.get("old_zoom") != z:
            old = render_frame(frame, zoom=z, boundaries=True,
                               pixels_by_cel={cid: ce.orig_pixels for cid, ce in edit.cels.items()},
                               opacity_by_cel={cid: ce.orig_opacity for cid, ce in edit.cels.items()})
            state["old_img"] = ImageTk.PhotoImage(old)
            state["old_w"], state["old_h"] = old.width, old.height
            state["old_dirty"] = False; state["old_zoom"] = z
        new = render_frame(frame, zoom=z, boundaries=True,
                           opacity_by_cel=opac_map(), changed_by_cel=chg_map())
        state["new_img"] = ImageTk.PhotoImage(new)
        old_w, old_h = state["old_w"], state["old_h"]
        canvas.delete("all")
        # OLD (read-only, left) | NEW (editable, right)
        canvas.create_text(MARGIN, 2, anchor="nw", text="OLD  (read-only)", fill="#bbbbbb",
                           font=("Consolas", 10, "bold"))
        canvas.create_image(MARGIN, LABEL_H, anchor="nw", image=state["old_img"])
        nx = MARGIN + old_w + 36
        state["new_x0"], state["new_y0"] = nx, LABEL_H
        canvas.create_text(nx, 2, anchor="nw", text="NEW  (paint here — yellow = changed)",
                           fill="#ffe400", font=("Consolas", 10, "bold"))
        canvas.create_image(nx, LABEL_H, anchor="nw", image=state["new_img"])
        canvas.config(scrollregion=(0, 0, nx + new.width + MARGIN, LABEL_H + new.height + MARGIN))
        status.config(text=f"zoom {z}x  cell {CELL_W*z}x{CELL_H*z}px (4:5)  "
                           f"active={edit.selected}  edited={[c.cel_id for c in edit.edited_cels()]}"
                           f"   {_pos_text()}")
        refresh_buttons()      # Revert/Undo-Revert enabled/grayed per the state machine

    def _load(label):
        """Load an entry (assembled anim frame or standalone cel) into frame/edit; rewire cels; redraw."""
        nonlocal frame, edit
        kind, arg = entry_by_label[label]
        if kind == "anim":
            frame = assemble_animation(table, arg[0], arg[1])
        else:                                             # kind == "cel": standalone content cel
            frame = assemble_cel(arg)
        edit = FrameEdit(table, frame)
        state["old_dirty"] = True                          # new frame -> re-render the OLD cache
        prev_label[0] = label
        m = celmenu["menu"]; m.delete(0, "end")           # rebuild the cel (overlap) selector
        for cid in edit.cels:
            m.add_command(label=cid, command=lambda c=cid: (celvar.set(c), on_cel()))
        celvar.set(edit.selected)
        root.title(f"sprite tool — {frame.label}")
        redraw()
        errs = edit.reload_errors()
        if errs:                                          # Part C gate: never a silent lossy reload
            savebar.config(text="RELOAD STOP: " + " | ".join(errs), fg="white", bg="#b02020")

    def _ask_save_discard_cancel(name):
        """Modal Save/Discard/Cancel. Returns 'save' | 'discard' | 'cancel'."""
        dlg = tk.Toplevel(root); dlg.title("Unsaved changes")
        dlg.transient(root); dlg.grab_set(); dlg.resizable(False, False)
        tk.Label(dlg, text=f"You have live changes in {name}.",
                 font=("Consolas", 11), padx=18, pady=14).pack()
        res = {"v": "cancel"}
        def pick(v): res["v"] = v; dlg.destroy()
        row = tk.Frame(dlg); row.pack(pady=(0, 12))
        tk.Button(row, text="Save", width=10, command=lambda: pick("save")).pack(side="left", padx=5)
        tk.Button(row, text="Discard", width=10, command=lambda: pick("discard")).pack(side="left", padx=5)
        tk.Button(row, text="Cancel", width=10, command=lambda: pick("cancel")).pack(side="left", padx=5)
        dlg.protocol("WM_DELETE_WINDOW", lambda: pick("cancel"))
        dlg.wait_window()
        return res["v"]

    def _guard():
        """Unsaved-changes guard on switch. Returns 'proceed' or 'cancel'. Save saves; Discard
        reverts to baseline (shared with the Revert-to-Old op); never a silent discard."""
        if not edit.is_dirty():
            return "proceed"
        ans = _ask_save_discard_cancel(frame.label)
        if ans == "cancel":
            return "cancel"
        if ans == "save":
            do_save()
        else:                               # discard
            edit.revert_all()               # same revert-to-baseline op as the Revert button
        return "proceed"

    def select_entry(label):
        if label == prev_label[0]:
            return
        stop_play()                      # a manual pick takes over from playback
        if _guard() == "cancel":
            framevar.set(prev_label[0] or ""); return
        _load(label)

    def select_group(group):
        stop_play()
        if _guard() == "cancel":
            groupvar.set(prev_group[0] or ""); return
        prev_group[0] = group
        entries = catalog.entries_for(table, catvar.get(), group)
        entry_by_label.clear(); entry_by_label.update({l: (k, a) for l, k, a in entries})
        entry_order[:] = [l for l, _k, _a in entries]
        m = framemenu["menu"]; m.delete(0, "end")
        for l, _k, _a in entries:
            m.add_command(label=l, command=lambda ll=l: (framevar.set(ll), select_entry(ll)))
        if entries:
            framevar.set(entries[0][0]); _load(entries[0][0])
        refresh_buttons()

    def select_category(cat):
        stop_play()
        if _guard() == "cancel":
            catvar.set(prev_cat[0]); return
        prev_cat[0] = cat
        groups = catalog.groups_for(table, cat)
        m = groupmenu["menu"]; m.delete(0, "end")
        for g in groups:
            m.add_command(label=g, command=lambda gg=g: (groupvar.set(gg), select_group(gg)))
        if groups:
            groupvar.set(groups[0]); select_group(groups[0])

    # ---- playback -------------------------------------------------------------------------
    # Walks the current GROUP's frames in file order at each frame's own dwell. Dwell is in VBL
    # (the oracle's timebase, one VBL = one display frame), so ms = dwell * 1000/59.94. Where the
    # block declares @loop, the repeating span is honoured: frames before it play in once, then the
    # span repeats forever (that IS what the oracle does). Without @loop the whole block cycles.
    VBL_MS = 1000.0 / 59.94

    def _anim_block():
        """The block name if the current group is an animation, else None (cels don't play)."""
        g = groupvar.get()
        return g if g in table.anim else None

    def stop_play(_=None):
        if state.get("after_id"):
            root.after_cancel(state["after_id"]); state["after_id"] = None
        if state.get("playing"):
            state["playing"] = False
            savebar.config(text="playback stopped", fg="white", bg="#444")
        refresh_buttons()

    def _step():
        if not state["playing"]:
            return
        block = _anim_block()
        if block is None or not entry_order:
            stop_play(); return
        i = state["play_i"]
        label = entry_order[i]
        _load(label); framevar.set(label)
        dwell = table.anim[block][i].dwell
        span = table.loop_span(block)
        if span and i == span[1]:            # end of the repeating span -> back to its start
            state["play_i"] = span[0]
        else:
            state["play_i"] = (i + 1) % len(entry_order)
        state["after_id"] = root.after(max(16, int(dwell * VBL_MS)), _step)

    def do_play(_=None):
        if state.get("playing"):
            stop_play(); return
        block = _anim_block()
        if block is None:
            savebar.config(text="playback needs an animation group (this group is standalone cels)",
                           fg="white", bg="#666"); return
        if _guard() == "cancel":             # never discard live edits to start a preview
            return
        try:
            span = table.loop_span(block)    # validates @loop against the block's frames
        except ValueError as ex:
            savebar.config(text=f"@loop ERROR: {ex}", fg="white", bg="#b02020"); return
        state["playing"] = True
        state["play_i"] = entry_order.index(framevar.get()) if framevar.get() in entry_order else 0
        note = (f"looping {table.anim_loop[block][0]}..{table.anim_loop[block][1]}"
                if span else "looping the whole block (no @loop declared)")
        savebar.config(text=f"playing {block} — {note}.  Painting is disabled while playing; "
                            f"press Play again (or Space) to stop.", fg="white", bg="#1b5e9f")
        refresh_buttons()
        _step()

    def do_step(delta):
        """Manual single-step in FILE ORDER — deliberately NOT honouring @loop, so every frame is
        reachable (the loop skips e0/st forever). Clamps at both ends rather than wrapping, so
        'I have seen every frame' is unambiguous. Routes through select_entry so the unsaved-edit
        guard applies: _load() rebuilds the edit model, and a raw step would drop live edits."""
        stop_play()
        if not entry_order:
            return
        i = entry_order.index(prev_label[0]) if prev_label[0] in entry_order else 0
        j = max(0, min(len(entry_order) - 1, i + delta))
        if j == i:
            savebar.config(text=f"at the {'first' if delta < 0 else 'last'} frame of this group "
                                f"({len(entry_order)} total)", fg="white", bg="#666")
            return
        framevar.set(entry_order[j]); select_entry(entry_order[j])

    def canvas_to_frame(e):
        # map widget coords -> CANVAS coords first (so painting stays correct after scrolling).
        # canvasx/canvasy return FLOATS — int() them or screen_to_sprite yields float sprite coords
        # that then fail to index the pixel arrays (pixels[float]), which silently killed painting.
        cx, cy = int(canvas.canvasx(e.x)), int(canvas.canvasy(e.y))
        return screen_to_sprite(cx - state.get("new_x0", MARGIN), cy - state.get("new_y0", MARGIN), state["zoom"])

    def on_move(e):
        fx, fy = canvas_to_frame(e)
        cpx, cpy = frame.x0 + fx, frame.y0 + fy
        owners = [(p.cel_id, p.cel.pixels[cpy - p.y][cpx - p.x]) for p in frame.placed if p.covers(cpx, cpy)]
        if 0 <= fx < frame.W and 0 <= fy < frame.H and owners:
            note = "  [OVERLAP -> active]" if len(owners) > 1 else ""
            coord.config(text=f"({fx},{fy}) " + " ".join(f"{c}={v}" for c, v in owners) + note)
        else:
            coord.config(text=f"({fx},{fy}) background")

    def on_press(e):
        if state.get("playing"): return                   # frames are being swapped under us
        for ce in edit.cels.values(): ce.begin_stroke()   # snapshot all for a coherent undo step
        state["painting"] = True
        on_drag(e)
    def _coalesced_redraw():
        # collapse a burst of drag events into one redraw per idle cycle (painting itself is
        # cheap; the per-event full re-render was the lag).
        if not state.get("redraw_pending"):
            state["redraw_pending"] = True
            root.after_idle(lambda: (state.update(redraw_pending=False), redraw()))
    def on_drag(e):
        if not state["painting"] or state.get("playing"): return
        fx, fy = canvas_to_frame(e)
        if 0 <= fx < frame.W and 0 <= fy < frame.H:
            edit.paint_canvas(fx, fy, state["entry"]); _coalesced_redraw()
    def on_release(e):
        state["painting"] = False
        redraw()                          # final authoritative redraw at stroke end

    def do_undo(_=None):
        for ce in edit.cels.values(): ce.undo_stroke()
        redraw()
    def do_redo(_=None):
        for ce in edit.cels.values(): ce.redo_stroke()
        redraw()
    def zoom_in(_=None): state["zoom"] = min(12, state["zoom"]+1); redraw()
    def zoom_out(_=None): state["zoom"] = max(1, state["zoom"]-1); redraw()

    def do_save(_=None):
        import tkinter.messagebox as mb
        edited = edit.edited_cels()
        if not edited:
            savebar.config(text="nothing edited — nothing to save", fg="white", bg="#666"); return
        ok_msgs, stop_msgs = [], []
        for ce in edited:
            try:
                r = save_cel(ce.cel, ce.cel_dir, ce.label, ce.opacity, ce.sprite_id, table.path)
                conv = "converted.s byte-identical" if r["byte_identical"] else "converted.s colour-changed"
                sc = f"opacity.s ({r['kind']}) written" if r["state"] == "authored" else "no sidecar (none)"
                ok_msgs.append(f"Saved {ce.cel_id} — {conv}, {sc}, registry→{r['state']}")
                ce.mark_saved()                 # the saved state is the new Old baseline (clean)
                state["old_dirty"] = True        # baseline changed -> re-render the OLD cache
            except O.CannotEncode as ex:
                stop_msgs.append(f"NOT SAVED — {ce.cel_id}: marking needs per-pixel (row-varying) "
                                 f"opacity; mixed/masked can't encode it → stencil_punch path. [{ex}]")
            except AssertionError as ex:
                stop_msgs.append(f"NOT SAVED — {ce.cel_id}: {ex}")
            except SaveIOError as ex:                     # hard error → modal popup + rolled back
                mb.showerror("Save failed (rolled back)",
                             f"{ce.cel_id}: {ex}\nThe pre-save state was restored (no half-written files).")
                stop_msgs.append(f"SAVE FAILED (rolled back) — {ce.cel_id}: {ex}")
        edit.touched()                          # a save invalidates the one-shot Undo-Revert
        if stop_msgs:
            savebar.config(text="  ||  ".join(stop_msgs + ok_msgs), fg="white", bg="#b02020")
        else:
            savebar.config(text="  |  ".join(ok_msgs), fg="white", bg="#1b7f1b")
        redraw()   # updates the info line only; the save banner above is untouched

    def do_revert(_=None):
        if edit.is_dirty():
            edit.revert_all(); redraw()         # snap New->Old; enables Undo-Revert
    def do_undo_revert(_=None):
        if edit.undo_revert():
            redraw()                            # restore the just-reverted edits

    def refresh_buttons():
        # every action button advertises whether its action is valid (reads existing signals only)
        playing = bool(state.get("playing"))
        save_btn.config(state="disabled" if playing else ("normal" if edit.is_dirty() else "disabled"))
        undo_btn.config(state="disabled" if playing else ("normal" if edit.can_undo() else "disabled"))
        redo_btn.config(state="disabled" if playing else ("normal" if edit.can_redo() else "disabled"))
        revert_btn.config(state="disabled" if playing else ("normal" if edit.is_dirty() else "disabled"))
        undorevert_btn.config(state="disabled" if playing
                              else ("normal" if edit.can_undo_revert() else "disabled"))
        play_btn.config(text="■ Stop" if playing else "▶ Play",
                        state="normal" if (playing or _anim_block()) else "disabled")
        multi = len(entry_order) > 1
        prev_btn.config(state="normal" if (multi and not playing) else "disabled")
        next_btn.config(state="normal" if (multi and not playing) else "disabled")

    undo_btn = tk.Button(bar, text="undo", command=do_undo); undo_btn.pack(side="right")
    redo_btn = tk.Button(bar, text="redo", command=do_redo); redo_btn.pack(side="right")
    revert_btn = tk.Button(bar, text="Revert to Old", command=do_revert); revert_btn.pack(side="right", padx=(8, 0))
    undorevert_btn = tk.Button(bar, text="Undo Revert", command=do_undo_revert); undorevert_btn.pack(side="right")
    save_btn = tk.Button(bar, text="SAVE", command=do_save); save_btn.pack(side="right", padx=6)
    next_btn = tk.Button(bar, text="▶|", width=3, command=lambda: do_step(+1))
    next_btn.pack(side="right", padx=(0, 2))
    play_btn = tk.Button(bar, text="▶ Play", command=do_play); play_btn.pack(side="right")
    prev_btn = tk.Button(bar, text="|◀", width=3, command=lambda: do_step(-1))
    prev_btn.pack(side="right", padx=(8, 0))
    tk.Button(bar, text="+", command=zoom_in).pack(side="right")
    tk.Button(bar, text="-", command=zoom_out).pack(side="right")
    canvas.bind("<Motion>", on_move)
    canvas.bind("<ButtonPress-1>", on_press)
    canvas.bind("<B1-Motion>", on_drag)
    canvas.bind("<ButtonRelease-1>", on_release)
    root.bind("<Control-z>", do_undo); root.bind("<Control-y>", do_redo)
    root.bind("<Control-s>", do_save); root.bind("+", zoom_in); root.bind("-", zoom_out)
    root.bind("<space>", do_play)                 # Space = play/stop toggle
    root.bind("<Right>", lambda _e: do_step(+1))  # arrows = single-step, file order
    root.bind("<Left>",  lambda _e: do_step(-1))
    root.protocol("WM_DELETE_WINDOW", lambda: (stop_play(), root.destroy()))
    arm(state["entry"])          # show the initially-armed swatch
    select_category(init_cat)    # populate the scoped frame/cel list + load the first entry
    root.mainloop()

if __name__ == "__main__":
    main()
