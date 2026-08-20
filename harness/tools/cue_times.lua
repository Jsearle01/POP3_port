-- cue_times.lua — P4.23: WHEN does each song actually start, and WHICH one?
--
-- ★★★ THE FIRST ATTEMPT AT THIS WAS A BROKEN INSTRUMENT AND IT IS WORTH SAYING WHY. It
-- read-tapped the entry table's `msys_play` slot ($0A03) on the theory that a `jsr` there
-- would show up as a read. It reported 198 cues, all at the same frame, all inside the
-- INTRO -- opcode fetches, not calls. An instrument that cannot be wrong in an obvious way
-- is worth more than one that is subtly right: 198 identical timestamps announced itself.
--
-- ★★ SO TAP THE STATE, NOT THE CONTROL FLOW. `msys_play` writes the song id to
-- `msys_index` as its first act, exactly once per call. A write tap there gives WHEN and
-- WHICH in one event and cannot fire on anything else.
--
-- ★ The scene's window comes from `cel_scene_done` ($FE07), which the scene clears on
-- entry and the terminal beat sets -- so cue offsets are reported against the scene's own
-- start rather than against boot, which is what makes them comparable with the oracle's
-- PlayCut0-relative call times.
local IDX   = tonumber(os.getenv("P_IDX") or "0EB7", 16)
local DONE  = 0xFE07
local OUT   = os.getenv("P_OUT") or "build/tmp/cue_times.log"
local FPS   = 59.92

local NAME = { [1] = "s_Presents", [2] = "s_Byline", [3] = "s_Title", [4] = "s_Prolog",
               [5] = "s_Sumup", [7] = "s_Princess", [8] = "s_Squeek", [9] = "s_Vizier",
               [10] = "s_Buildup", [11] = "s_Magic", [12] = "s_StTimer" }

-- the oracle's own call times, from the per-song capture headers, relative to PlayCut0's
-- arm at 44.7 s. These are MEASURED off the running oracle, not estimated.
local ORACLE = { [7] = 0.2, [8] = 14.1, [9] = 16.7, [10] = 26.3, [11] = 34.9, [12] = 42.7 }

local mem = manager.machine.devices[":maincpu"].spaces["program"]
local nk  = manager.machine.natkeyboard
nk.in_use = true
local scr = manager.machine.screens:at(1)

local cues, nc = {}, 0
local scene_start, scene_end, prev = nil, nil, nil

_G._t = mem:install_write_tap(IDX, IDX, "cue", function(o, d, m)
    nc = nc + 1
    cues[nc] = { fn = scr:frame_number(), song = d }
    return d
end)

local state, t0, done = "boot", nil, false
_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if done then return end
    if state == "boot" then
        if fn >= 300 then nk:post('LOADM"INTROSEQ"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if fn > t0 + 900 then nk:post('EXEC\n'); state = "run" end
        return
    end
    local d = mem:read_u8(DONE)
    if prev ~= nil then
        if prev ~= 0 and d == 0 and not scene_start then scene_start = fn end
        if d ~= 0 and scene_start and not scene_end then scene_end = fn end
    end
    prev = d
    if fn <= 11000 then return end
    done = true

    local f = io.open(OUT, "w")
    f:write("# every song start, by frame, and the cutscene's against the ORACLE's own\n")
    f:write("# call times (measured off the running oracle, relative to PlayCut0's arm).\n#\n")
    f:write(string.format("# scene frames %s..%s = %.1f s\n#\n",
            tostring(scene_start), tostring(scene_end),
            (scene_start and scene_end) and (scene_end - scene_start) / FPS or 0))
    f:write(string.format("# %-12s %7s %10s %10s %10s\n",
                          "song", "frame", "port", "oracle", "delta"))
    for i = 1, nc do
        local c = cues[i]
        local nm = NAME[c.song] or ("id " .. c.song)
        if scene_start and c.fn >= scene_start then
            local rel = (c.fn - scene_start) / FPS
            local o = ORACLE[c.song]
            if o then
                f:write(string.format("  %-12s %7d %9.1fs %9.1fs %+9.1fs\n",
                                      nm, c.fn, rel, o, rel - o))
            else
                f:write(string.format("  %-12s %7d %9.1fs %10s %10s\n",
                                      nm, c.fn, rel, "-", "-"))
            end
        else
            f:write(string.format("  %-12s %7d %9s   (intro)\n", nm, c.fn, "-"))
        end
    end
    f:write(string.format("\n# %d song starts in all\n", nc))
    if nc == 0 then
        f:write("# ★ NONE — the tap saw no write to msys_index. Check P_IDX against the map.\n")
    end
    f:close()
    manager.machine:exit()
end)
