-- harness/tools/oracle_star_colors.lua
--
-- POP P3.17 — WHAT COLOUR IS EACH STAR WHEN IT LIGHTS?
--
-- The port's star 3 currently lights RED, and Jay reports it should be white like
-- star 1. That value was never measured: six frame captures caught only star 0 lit
-- (white -> blue), and the other three lit colours were DERIVED by assuming the same
-- EOR applies everywhere. A derived value that contradicts Jay's eye is exactly the
-- kind of thing to settle on the machine (CLAUDE.md §2: trace over source, Jay over
-- both).
--
-- This records, for every pixel position in the window that ever changes, the full set
-- of distinct colours it takes and how often. That answers the question without
-- needing the Apple-mono -> CoCo-pixel mapping at all: the four stars sit on four
-- distinct ROWS (98/101/109/114) and rows are 1:1, so each is identified by row alone.
--
-- Deliberately does NOT sample the four positions the port believes in. Sampling only
-- where you expect an answer can only ever confirm what you already assumed -- the same
-- trap that hid the 1 px flame offset and the RNG's star selection earlier in P3.17.
local OUT   = os.getenv("P_OUT") or "build/oracle_star_colors.log"
local FIRST = tonumber(os.getenv("P_FIRST") or "2700")
local LAST  = tonumber(os.getenv("P_LAST") or "9000")
local X0, X1 = 0, 140
local Y0, Y1 = 90, 125

local scr = manager.machine.screens:at(1)
local f = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end

local prev = nil
local hist = {}         -- "x,y" -> { [colour] = count }

log("# oracle window stars — every changing position and the colours it takes")
log(string.format("# frames %d..%d, x %d..%d, y %d..%d", FIRST, LAST, X0, X1, Y0, Y1))

local function tick()
    local fn = scr:frame_number()
    if fn < FIRST or fn > LAST then return end

    local cur = {}
    local i = 0
    for y = Y0, Y1 do
        for x = X0, X1, 2 do
            i = i + 1
            cur[i] = scr:pixel(x, y)
        end
    end

    if prev then
        i = 0
        for y = Y0, Y1 do
            for x = X0, X1, 2 do
                i = i + 1
                if cur[i] ~= prev[i] then
                    local k = string.format("%d,%d", x, y)
                    hist[k] = hist[k] or {}
                    -- record BOTH sides of the transition: the colour it left and the
                    -- colour it arrived at, so a rarely-lit star still reports its lit
                    -- value from a single transition rather than needing to be sampled
                    -- during the few frames it happens to be on.
                    hist[k][prev[i]] = (hist[k][prev[i]] or 0) + 1
                    hist[k][cur[i]]  = (hist[k][cur[i]] or 0) + 1
                end
            end
        end
    end
    prev = cur

    if fn >= LAST then
        local keys = {}
        for k in pairs(hist) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b)
            local ax, ay = a:match("(-?%d+),(-?%d+)")
            local bx, by = b:match("(-?%d+),(-?%d+)")
            if tonumber(ay) ~= tonumber(by) then return tonumber(ay) < tonumber(by) end
            return tonumber(ax) < tonumber(bx)
        end)
        log(string.format("# %d distinct positions changed", #keys))
        for _, k in ipairs(keys) do
            local x, y = k:match("(-?%d+),(-?%d+)")
            local parts = {}
            for colour, n in pairs(hist[k]) do
                parts[#parts + 1] = { colour = colour, n = n }
            end
            table.sort(parts, function(a, b) return a.n > b.n end)
            local desc = {}
            for _, p in ipairs(parts) do
                desc[#desc + 1] = string.format("$%08X x%d", p.colour & 0xFFFFFFFF, p.n)
            end
            log(string.format("row %3s  x %3s  :  %s", y, x, table.concat(desc, "  |  ")))
        end
        manager.machine:exit()
    end
end

_G._notifier = emu.add_machine_frame_notifier(tick)
