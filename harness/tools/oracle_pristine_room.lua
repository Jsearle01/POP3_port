-- harness/tools/oracle_pristine_room.lua
--
-- POP P3.17 — catch the princess's room BEFORE any character is drawn on it.
--
-- WHY A SPECIFIC FRAME MATTERS. The room is one packed picture (cutprincess1:
-- SngExpand + copy page 1 to page 2), and the characters are NOT in it: startP0 puts
-- the princess at CharX=120 in a Pstand sequence and startV0 the vizier at CharX=197
-- in Vstand, and both are drawn by the engine from the FIRST `play` frame. So the
-- background asset exists on screen for a short window: after the expand, before the
-- first play.
--
-- Picking a frame by eye is what went wrong before -- I dumped where my motion
-- instrument showed movement, which is precisely where characters are. This finds the
-- moment by measurement: watch the displayed screen, and dump on the FIRST large
-- change after the prologue (the room arriving), not on any later one.
--
-- The dump itself flips RAMRD to MAIN, because reads through the CPU space otherwise
-- return AUX (POP keeps RAMRDaux set) -- see oracle_ram_dump.lua. Writing soft
-- switches under a running game is normally forbidden here (P3.3 lost a trace doing it
-- every frame); this is the one safe shape, a single flip immediately before exit.
--
--   P_AFTER  ignore changes before this frame (default 2600, past the prologue)
--   P_THRESH fraction of sampled columns that must change to count as "a new screen"
--   P_OUT    output prefix
local AFTER  = tonumber(os.getenv("P_AFTER") or "2600")
local THRESH = tonumber(os.getenv("P_THRESH") or "0.5")
local OUT    = os.getenv("P_OUT") or "build/oracle_pristine"

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)

local RAMRDOFF = 0xC002
local STEP = 4
local W, H, ROWS, prev, done = nil, nil, nil, nil, false

local function sample()
    local t = {}
    for _, y in ipairs(ROWS) do
        for x = 0, W - 1, STEP do t[#t + 1] = scr:pixel(x, y) end
    end
    return t
end

local function grab(path, lo)
    local t = {}
    for a = lo, lo + 0x1FFF do t[#t + 1] = string.char(mem:read_u8(a)) end
    local f = io.open(path, "wb")
    if not f then return false end
    f:write(table.concat(t)); f:close()
    return true
end

local function tick()
    if done then return end
    local fn = scr:frame_number()
    if not W then
        W, H = scr.width, scr.height
        ROWS = { math.floor(H * 0.25), math.floor(H * 0.50), math.floor(H * 0.75) }
        prev = sample()
        return
    end
    local cur = sample()
    if fn >= AFTER then
        local n = 0
        for i = 1, #cur do if cur[i] ~= prev[i] then n = n + 1 end end
        if n >= THRESH * #cur then
            done = true
            mem:write_u8(RAMRDOFF, 0)               -- reads see MAIN
            grab(OUT .. "_page1.bin", 0x2000)
            grab(OUT .. "_page2.bin", 0x4000)
            local f = io.open(OUT .. "_dump.log", "w")
            if f then
                f:write(string.format(
                    "# caught a new screen at frame %d (%d of %d sampled points changed)\n",
                    fn, n, #cur))
                f:close()
            end
            manager.machine:exit()
            return
        end
    end
    prev = cur
end

_G._notifier = emu.add_machine_frame_notifier(tick)
