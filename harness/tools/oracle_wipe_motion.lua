-- harness/tools/oracle_wipe_motion.lua
--
-- POP P3.14 Phase 1 — WHERE DOES THE ORACLE'S WIPE ACTUALLY MOVE?
--
-- The whole wipe discovery is a lesson about endpoint measurement: a byte-diff of
-- two settled images, and a static PNG, are both blind to motion. So this does not
-- diff images. It samples the RUNNING oracle's screen every frame and reports, per
-- frame, WHICH COLUMNS CHANGED SINCE THE PREVIOUS FRAME. That is motion, measured.
--
-- Three sample rows, chosen to answer Jay's question directly:
--   * one inside the image's top border band
--   * one through the middle of the text area
--   * one inside the bottom border band
-- If the border rows stay quiet while the text row shows an edge marching left to
-- right, then the border is static IN MOTION TERMS -- which is what Jay observed and
-- what no still frame can establish.
--
-- Sampling every 4th column keeps this cheap enough to run over the whole intro
-- (screen:pixel() per sample; the full pixels() bitmap every frame is far too slow).
--
-- Output: build/oracle_wipe_motion.log — one line per frame that changed anything,
-- with the changed-column span per row band.
local OUT = os.getenv("P_OUT") or "build/oracle_wipe_motion.log"
local STEP = tonumber(os.getenv("P_STEP") or "4")

local scr = manager.machine.screens:at(1)
local f = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end

-- resolved on the first frame, once the screen geometry is known
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

log("# oracle wipe motion — columns that CHANGED since the previous frame")
local started = false

local function tick()
    local fn = scr:frame_number()
    if not W then
        W, H = scr.width, scr.height
        -- top border band, middle of the text, bottom border band
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
        started = true
    end
    prev = cur
end

_G._notifier = emu.add_machine_frame_notifier(tick)
