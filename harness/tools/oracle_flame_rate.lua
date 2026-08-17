-- harness/tools/oracle_flame_rate.lua
--
-- POP P3.17 — HOW OFTEN DO THE ORACLE'S TORCH FLAMES ACTUALLY CHANGE?
--
-- The port redraws both flames every frame, at 60 Hz. The oracle cannot: its cutscene
-- runs through `play`, whose loop is `pause SPEED` then NextFrame/FrameAdv, with SPEED
-- set to 7 or 12 across PlayCut0 [SUBS.S:876, :658]. So an engine frame is many video
-- frames long and the flames step once per engine frame -- but `pause` is a delay whose
-- wall-clock value is not derivable from source, which is exactly why this is measured
-- rather than computed.
--
-- Samples the two flame boxes every video frame and logs the frames on which either
-- changes. The gaps between those frames ARE the flame period.
--
-- Geometry: the flames sit at Apple mono px 91-97 and 181-187 (ptorchx*7+ptorchoff),
-- rows 101-113. MAME's apple2e screen is 560 wide = 280 mono px doubled, so x is
-- doubled here; rows map 1:1.
local OUT   = os.getenv("P_OUT") or "build/oracle_flame_rate.log"
local FIRST = tonumber(os.getenv("P_FIRST") or "2700")
local LAST  = tonumber(os.getenv("P_LAST") or "4700")

local scr = manager.machine.screens:at(1)
local f = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end

local BOXES = { { 182, 195 }, { 362, 375 } }    -- x ranges, already doubled
local ROW0, ROW1 = 101, 113

local prev, last_change = nil, nil
local gaps = {}

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

log("# oracle torch-flame update rate — frames on which a flame changed")

local function tick()
    local fn = scr:frame_number()
    if fn < FIRST or fn > LAST then return end
    local h = sample()
    if prev ~= nil and h ~= prev then
        if last_change then
            local gap = fn - last_change
            gaps[gap] = (gaps[gap] or 0) + 1
            log(string.format("f%6d  changed  (+%d frames)", fn, gap))
        else
            log(string.format("f%6d  changed  (first)", fn))
        end
        last_change = fn
    end
    prev = h
    if fn == LAST then
        log("#")
        log("# gap histogram (frames between flame updates):")
        local keys = {}
        for k in pairs(gaps) do keys[#keys + 1] = k end
        table.sort(keys)
        local tot, n = 0, 0
        for _, k in ipairs(keys) do
            log(string.format("#   %3d frames : %d times", k, gaps[k]))
            tot = tot + k * gaps[k]; n = n + gaps[k]
        end
        if n > 0 then
            log(string.format("# mean %.1f frames between updates = %.1f Hz",
                              tot / n, 60.0 / (tot / n)))
        end
        manager.machine:exit()
    end
end

_G._notifier = emu.add_machine_frame_notifier(tick)
