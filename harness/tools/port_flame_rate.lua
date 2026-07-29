-- harness/tools/port_flame_rate.lua
--
-- POP P3.17 — how often do OUR torch flames change? Same instrument as
-- oracle_flame_rate.lua, so the two logs compare directly.
--
-- The oracle measured 2.6 video frames between updates (22.8 Hz): 2-3 frames under
-- PlayCut0's SPEED 7 and 6 under SPEED 12. The port drew every frame at 60 Hz, which
-- Jay spotted by eye, and now paces the STATE at FLAME_DIV while still drawing every
-- frame. This is the check that the pacing actually took effect -- a change in the
-- source is not evidence about the machine.
--
-- Geometry: the CoCo3 screen is 640x239 — 320 px doubled horizontally, with vertical
-- overscan, so screen x = framebuffer px * 2 and screen y = row + 24. The flames sit
-- at framebuffer px 112-118 and 200-207, rows 101-113.
local OUT = os.getenv("P_OUT") or "build/port_flame_rate.log"

local scr = manager.machine.screens:at(1)
local nk = manager.machine.natkeyboard
nk.in_use = true

local f = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]

local BOXES = { { 224, 237 }, { 400, 415 } }    -- framebuffer px * 2
local ROW0, ROW1 = 101 + 24, 113 + 24
local WATCH = 600

local state, t0, loaded, started = "boot", nil, nil, nil
local prev, last_change, gaps = nil, nil, {}

local function sample()
    local h = 0
    for _, b in ipairs(BOXES) do
        for y = ROW0, ROW1 do
            for x = b[1], b[2], 2 do
                h = (h * 31 + scr:pixel(x, y)) % 4294967296
            end
        end
    end
    return h
end

log("# port torch-flame update rate")

local function tick()
    local fn = scr:frame_number()
    if state == "boot" then
        if fn >= 120 then nk:post('LOADM"ROOM"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if loaded == nil and mem:read_u8(0x2000) == 0x7E then loaded = fn end
        if fn > t0 + 900 then nk:post('EXEC\n'); state = "wait" end
        return
    end
    if state == "wait" then
        -- probe_frames at $2008 moves once the flicker loop is running
        if mem:read_u8(0x2008) > 0 then state, started = "watch", fn end
        return
    end
    if fn > started + WATCH then
        log("#")
        log("# gap histogram (video frames between flame updates):")
        local keys = {}
        for k in pairs(gaps) do keys[#keys + 1] = k end
        table.sort(keys)
        local tot, n = 0, 0
        for _, k in ipairs(keys) do
            log(string.format("#   %3d frames : %d times", k, gaps[k]))
            tot = tot + k * gaps[k]; n = n + gaps[k]
        end
        if n > 0 then
            log(string.format("# mean %.2f frames between updates = %.1f Hz",
                              tot / n, 60.0 / (tot / n)))
        else
            log("# NO CHANGES AT ALL in " .. WATCH .. " frames")
        end
        manager.machine:exit()
        return
    end
    local h = sample()
    if prev ~= nil and h ~= prev then
        if last_change then
            local gap = fn - last_change
            gaps[gap] = (gaps[gap] or 0) + 1
        end
        last_change = fn
    end
    prev = h
end

_G._notifier = emu.add_machine_frame_notifier(tick)
