-- harness/tools/oracle_window_stars.lua
--
-- POP P3.17 — HOW MANY STARS ACTUALLY TWINKLE, AND WHERE?
--
-- The port draws four, from `stary hex 62,65,6d,72` and `pstars`' `ldx #3` loop
-- [GAMEBG.S:114, SUBS.S:360]. Jay, watching both, reports the oracle has many more
-- than that. Source says four; the machine is the authority (CLAUDE.md §2), so this
-- asks the machine.
--
-- Scans the whole left-hand window area every frame and records EVERY pixel position
-- that ever changes, rather than sampling the four positions the source predicts --
-- otherwise the measurement can only ever confirm what it already assumed, which is
-- the mistake that let a 1 px flame offset through earlier in this dispatch.
--
-- Geometry: MAME's apple2e screen is 560 wide = 280 mono px doubled. The window is at
-- the far left, so x 0..140 covers mono px 0..70. Rows 1:1.
local OUT   = os.getenv("P_OUT") or "build/oracle_window_stars.log"
local FIRST = tonumber(os.getenv("P_FIRST") or "2700")
local LAST  = tonumber(os.getenv("P_LAST") or "4600")
local X0, X1 = 0, 140
local Y0, Y1 = 80, 140

local scr = manager.machine.screens:at(1)
local f = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end

local prev, seen = nil, {}

log("# oracle window — every pixel position that changes, and how often")

local function tick()
    local fn = scr:frame_number()
    if fn < FIRST or fn > LAST then return end
    local cur = {}
    for y = Y0, Y1 do
        for x = X0, X1, 2 do
            cur[#cur + 1] = scr:pixel(x, y)
        end
    end
    if prev then
        local i = 0
        for y = Y0, Y1 do
            for x = X0, X1, 2 do
                i = i + 1
                if cur[i] ~= prev[i] then
                    local k = string.format("%d,%d", x, y)
                    seen[k] = (seen[k] or 0) + 1
                end
            end
        end
    end
    prev = cur
    if fn == LAST then
        local keys = {}
        for k in pairs(seen) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b)
            local ax, ay = a:match("(%d+),(%d+)")
            local bx, by = b:match("(%d+),(%d+)")
            if tonumber(ay) ~= tonumber(by) then return tonumber(ay) < tonumber(by) end
            return tonumber(ax) < tonumber(bx)
        end)
        log(string.format("# %d distinct positions changed between f%d and f%d",
                          #keys, FIRST, LAST))
        for _, k in ipairs(keys) do
            local x, y = k:match("(%d+),(%d+)")
            log(string.format("#   screen x=%3s y=%3s  (mono px %d, row %s)  %d changes",
                              x, y, tonumber(x) / 2, y, seen[k]))
        end
        manager.machine:exit()
    end
end

_G._notifier = emu.add_machine_frame_notifier(tick)
