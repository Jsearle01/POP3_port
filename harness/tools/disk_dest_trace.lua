-- disk_dest_trace.lua — P4.24 §1: where does each track ACTUALLY land?
--
-- ★★★ THE PREVIOUS ATTEMPT AT THIS WAS OFF BY ONE READ, AND THE ORDER OF TWO STORES IS
-- WHY. `load_tracks` fills the parameter block as:
--
--         sta     dr_r_track          <- the track, FIRST
--         stb     dr_r_count
--         stx     dr_dest             <- the destination, LAST
--
-- P4.23 tapped the write to `dr_r_track` and then READ `dr_dest`, which at that instant
-- still held the PREVIOUS read's destination. Every address in that table belonged to the
-- read before it — which is how track 29 came to be reported at $FE00 while the code says
-- ROOM_BLOB = FLAME_LOAD. Two sources disagreed and neither was the machine.
--
-- ★★ SO TAP THE LAST STORE. A write to `dr_dest` means the block is complete: the track,
-- the count and the destination are all in place and none of them is stale.
--
-- ★ THE GENERAL FORM, worth more than this one fix: when sampling a multi-field structure
-- from a tap, trigger on the field that is written LAST, or read nothing but the field the
-- tap fired on.
local DR    = tonumber(os.getenv("P_DRVAR") or "6A00", 16)
local DONE  = 0xFE07
local OUT   = os.getenv("P_OUT") or "build/tmp/disk_dest.log"
local FPS   = 59.92

local mem = manager.machine.devices[":maincpu"].spaces["program"]
local nk  = manager.machine.natkeyboard
nk.in_use = true
local scr = manager.machine.screens:at(1)

local ev, n = {}, 0
local scene_start, prev = nil, nil

-- dr_dest is DR+2 and is written LAST; read the rest of the block here, all settled.
_G._t = mem:install_write_tap(DR + 3, DR + 3, "dest", function(o, d, m)
    n = n + 1
    ev[n] = { fn = scr:frame_number(),
              track = mem:read_u8(DR + 5),
              count = mem:read_u8(DR + 6),
              dest  = mem:read_u8(DR + 2) * 256 + d }
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
    if prev ~= nil and prev ~= 0 and d == 0 and not scene_start then scene_start = fn end
    prev = d
    if fn <= 9000 then return end
    done = true
    local f = io.open(OUT, "w")
    f:write("# every disk read: track, sector count and the destination it ACTUALLY got,\n")
    f:write("# sampled on the LAST store into the parameter block so nothing is stale.\n")
    f:write(string.format("# scene entry at frame %s\n#\n", tostring(scene_start)))
    f:write(string.format("# %-8s %-7s %-6s %-8s %s\n",
                          "frame", "rel", "track", "sectors", "-> dest"))
    for i = 1, n do
        local e = ev[i]
        local rel = scene_start and string.format("%+.2fs", (e.fn - scene_start) / FPS) or "-"
        f:write(string.format("  %-8d %-7s %-6d %-8d -> $%04X\n",
                              e.fn, rel, e.track, e.count, e.dest))
    end
    f:write(string.format("\n# %d reads\n", n))
    f:close()
    manager.machine:exit()
end)
