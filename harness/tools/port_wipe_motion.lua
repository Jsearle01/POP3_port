-- harness/tools/port_wipe_motion.lua
--
-- POP P3.14 Phase 2 — WHERE DOES OUR PORT'S WIPE MOVE?
--
-- Deliberately the SAME instrument as oracle_wipe_motion.lua — same three sample
-- rows, same every-4th-column sampling, same "which columns changed since the
-- previous frame" output — so the two logs can be read side by side. Measuring the
-- port and the oracle through one instrument is the point; a different measurement
-- on each side would prove nothing about whether they match.
--
-- It samples MOTION, not endpoints. That distinction is the whole reason this task
-- exists: the missing wipe survived three static gates and a green endpoint suite.
--
-- Output: build/port_wipe_motion.log
local OUT = os.getenv("P_OUT") or "build/port_wipe_motion.log"
local STEP = tonumber(os.getenv("P_STEP") or "4")

local scr = manager.machine.screens:at(1)
local f = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end

-- the port has to be launched on the REAL path first (LOADM+EXEC off the floppy),
-- the same sequence run_introseq_live.sh uses
local nk = manager.machine.natkeyboard
nk.in_use = true
local state, t0 = "boot", nil
local function launch(fn)
    if state == "boot" and fn >= 300 then
        nk:post('LOADM"LOADER"\n')
        log("# posted LOADM at frame " .. fn)
        state, t0 = "loadm", fn
    elseif state == "loadm" and fn > t0 + 500 then
        nk:post('EXEC\n')
        log("# posted EXEC at frame " .. fn)
        state = "run"
    end
end

local W, H, ROWS, prev = nil, nil, nil, nil

local function sample()
    local t = {}
    for i, y in ipairs(ROWS) do
        local row = {}
        for x = 0, W - 1, STEP do
            row[#row + 1] = scr:pixel(x, y)
        end
        t[i] = row
    end
    return t
end

log("# port wipe motion — columns that CHANGED since the previous frame")

local function tick()
    local fn = scr:frame_number()
    launch(fn)
    if not W then
        W, H = scr.width, scr.height
        -- P_ROWS overrides the defaults, and on the CoCo3 it MUST: its 640x239
        -- screen includes GIME overscan, so proportional rows land in the SCREEN
        -- border and read quiet no matter what the picture does. The oracle's
        -- 560x192 has no such border, which is why the defaults work there.
        local env = os.getenv("P_ROWS")
        if env then
            ROWS = {}
            for v in env:gmatch("%d+") do ROWS[#ROWS + 1] = tonumber(v) end
        else
            ROWS = { math.floor(H * 0.04), math.floor(H * 0.50), math.floor(H * 0.94) }
        end
        log(string.format("# screen %dx%d, sample rows %d/%d/%d, every %d px",
                          W, H, ROWS[1], ROWS[2], ROWS[3], STEP))
        prev = sample()
        return
    end
    local cur = sample()
    local parts, any = {}, false
    for i = 1, #ROWS do
        local lo, hi, n = nil, nil, 0
        for k = 1, #cur[i] do
            if cur[i][k] ~= prev[i][k] then
                n = n + 1
                lo = lo or (k - 1) * STEP
                hi = (k - 1) * STEP
            end
        end
        if n > 0 then
            any = true
            parts[#parts + 1] = string.format("row%d[%3d..%3d n=%3d]", i, lo, hi, n)
        else
            parts[#parts + 1] = string.format("row%d[    quiet    ]", i)
        end
    end
    if any then
        log(string.format("f%6d  %s", fn, table.concat(parts, "  ")))
    end
    prev = cur
end

_G._notifier = emu.add_machine_frame_notifier(tick)
