-- harness/smoke/walk_test.lua
--
-- POP P3.31 — THE VIZIER WALKS. Does he walk CORRECTLY, all the way along?
--
-- WHY THIS IS NOT room_test.lua WITH A BIGGER NUMBER. The room suite takes two captures
-- twelve frames apart, and it takes them AFTER a 600-frame star watch -- by which time
-- the vizier has walked fifteen cycles and is off near the left wall. Two adjacent
-- samples at the end of a walk can say "these two frames are right"; they cannot say
-- anything about the frames between the start and there, which is exactly where an
-- accumulating peel error lives. This captures from the first frame the room is up and
-- keeps capturing across the whole walk.
--
-- IT ALSO MEASURES TWO THINGS THAT CANNOT BE READ OFF A CAPTURE:
--
--   OCCUPANCY -- which sub-byte phases the walk actually puts each cel on. walk_phases.py
--   derives it from the sequence table; this reads it off the running machine, sampling
--   the slot record every frame. Two independent derivations of the same set is what
--   makes it a measurement rather than an assertion (P3.30 hand-computed it and got the
--   exact complement of the truth).
--
--   CADENCE -- the gaps between CEL CHANGES, which is frames-per-step as the screen sees
--   it. Measured off the cel byte, not off a counter the VM increments: a counter says
--   what the VM thinks it did.
local ENGINE  = tonumber(os.getenv("P_ENGINE") or "0x2000")
local CUR_BACK= tonumber(os.getenv("P_CURBACK") or "0x7B06")
local BLOCK_A = tonumber(os.getenv("P_BLK_A") or "0x10")
local BLOCK_B = tonumber(os.getenv("P_BLK_B") or "0x14")
local OUT     = os.getenv("P_OUT") or "build/walk_test.log"
local POS     = os.getenv("P_POS") or "build/walk_chars_pos.txt"
local SHOTFMT = os.getenv("P_SHOTFMT") or "build/walk_shot_%s.bin"
local SHOTS   = tonumber(os.getenv("P_SHOTS") or "16")
local GAP     = tonumber(os.getenv("P_GAP") or "10")
local VIZ     = tonumber(os.getenv("P_VIZ") or "0")
local PRI     = tonumber(os.getenv("P_PRI") or "0")
local DRAWN   = tonumber(os.getenv("P_DRAWN") or "0")
local LAST    = tonumber(os.getenv("P_LAST") or "0")

local FB_BASE, FB_SIZE = 0x8000, 15360
local ROOM_MAGIC = 0x4B00
local CH_X, CH_CEL = 0, 3            -- slot record offsets [char_draw.s]

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true

local f = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end
local function rd8(a) return mem:read_u8(a) end

local function map_blocks(first)
    for i = 0, 3 do mem:write_u8(0xFFA4 + i, first + i) end
end

local function dump_front(path)
    local back = rd8(CUR_BACK)
    local back_blk  = (back == 0) and BLOCK_A or BLOCK_B
    local front_blk = (back == 0) and BLOCK_B or BLOCK_A
    map_blocks(front_blk)
    local t = {}
    for i = 0, FB_SIZE - 1 do t[#t + 1] = string.char(rd8(FB_BASE + i)) end
    map_blocks(back_blk)
    local o = io.open(path, "wb")
    if not o then return false end
    o:write(table.concat(t)); o:close()
    return true
end

-- POSITION AND CEL COME FROM WHERE THE CAPTURED BUFFER DREW, not from the slot record.
-- The record holds what the VM has decided for the frame being built; the buffer being
-- captured was drawn earlier and still holds the previous state until it is redrawn.
-- Reading the record instead is the mistake this project has now made five ways
-- (P3.27 for the cel, P3.29 for the position) -- ch_drawn and ch_last are written at
-- DRAW time, indexed by (character, slot), so they are what reached these pixels.
local pf = io.open(POS, "w")
local function log_positions(tag)
    if VIZ == 0 or not pf then return end
    local shown = 1 - (rd8(CUR_BACK) % 2)
    local function lastxy(ch)
        local o = LAST + (ch * 2 + shown) * 4
        return rd8(o), rd8(o + 1)
    end
    local vx, vy = lastxy(0)
    local px, py = lastxy(1)
    pf:write(string.format("%s %d %d %d %d %d %d\n", tag,
                           vx, vy, rd8(DRAWN + 0 * 2 + shown),
                           px, py, rd8(DRAWN + 1 * 2 + shown)))
    pf:flush()
end

local state, t0, started, loaded = "boot", nil, nil, nil
local shot_n, next_shot, first_fn = 0, nil, nil
local occ, prev_cel, last_change, gaps, steps = {}, nil, nil, {}, 0
local xs = {}

local function finish(reason)
    log("# --- PHASE OCCUPANCY, measured on the running machine ---")
    local cels = {}
    for c in pairs(occ) do cels[#cels + 1] = c end
    table.sort(cels)
    for _, c in ipairs(cels) do
        local ph = {}
        for p = 0, 3 do if occ[c][p] then ph[#ph + 1] = p end end
        log(string.format("#   cel %d -> phases {%s}", c, table.concat(ph, ",")))
    end
    log("# --- CADENCE: gaps between cel changes (video frames) ---")
    local keys, tot, cnt = {}, 0, 0
    for k in pairs(gaps) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        log(string.format("#   %2d frames : %d times", k, gaps[k]))
        tot = tot + k * gaps[k]; cnt = cnt + gaps[k]
    end
    if cnt > 0 then
        log(string.format("# mean %.2f frames per step over %d steps "
                          .. "(the walk changes cel EVERY step, so a gap IS a step)",
                          tot / cnt, cnt))
        log(string.format("# floor is 2.60 (13/5 = 3,3,2,3,2); overrun %+.2f frames",
                          tot / cnt - 2.60))
    end
    log(string.format("# x ran %s", table.concat(xs, " ")))
    log("# VERDICT: " .. reason)
    if f then f:close() end
    if pf then pf:close() end
    manager.machine:exit()
end

local function tick()
    local fn = scr:frame_number()
    if state == "boot" then
        if fn >= 300 then nk:post('LOADM"ROOM"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if loaded == nil and rd8(0x2000) == 0x7E then
            loaded = fn
            log("# LOADM first byte landed at frame " .. fn)
        end
        if fn > t0 + 900 then
            nk:post('EXEC\n')
            log("# posted EXEC at frame " .. fn)
            state, started = "running", fn
        end
        return
    end
    local magic = rd8(ENGINE + 6) * 256 + rd8(ENGINE + 7)
    if state == "running" then
        if magic == ROOM_MAGIC and rd8(ENGINE + 8) > 0 then
            log(string.format("# room up at frame %d, loads=%d status $%02X",
                              fn, rd8(ENGINE + 4), rd8(ENGINE + 5)))
            first_fn, next_shot, state = fn, fn, "walking"
        elseif fn > started + 1800 then
            log(string.format("# NEVER REACHED THE ROOM: magic $%04X status %d loads %d "
                              .. "dskerr $%02X", magic, rd8(ENGINE + 3),
                              rd8(ENGINE + 4), rd8(ENGINE + 5)))
            finish("FAIL — the room never came up")
        end
        return
    end

    -- SAMPLE EVERY FRAME. The VM steps every ~3 frames, so per-frame sampling sees every
    -- (cel, x) pair the walk visits; a sample per capture would see one in ten.
    local cel = rd8(VIZ + CH_CEL)
    local x = rd8(VIZ + CH_X)
    if cel >= 48 and cel <= 53 then
        occ[cel] = occ[cel] or {}
        occ[cel][(x + 20) % 4] = true
    end
    if prev_cel == nil then
        prev_cel, last_change = cel, fn
    elseif cel ~= prev_cel then
        local g = fn - last_change
        gaps[g] = (gaps[g] or 0) + 1
        steps = steps + 1
        if #xs < 60 then xs[#xs + 1] = string.format("%d:%d", cel, x) end
        prev_cel, last_change = cel, fn
    end

    if fn >= next_shot and shot_n < SHOTS then
        shot_n = shot_n + 1
        local tag = string.format("%02d", shot_n)
        log_positions(tag)
        local ok = dump_front(string.format(SHOTFMT, tag))
        log(string.format("# capture %s at frame %d (+%d): %s",
                          tag, fn, fn - first_fn, ok and "ok" or "WRITE FAILED"))
        next_shot = fn + GAP
    elseif shot_n >= SHOTS then
        finish(string.format("%d captures over %d frames", shot_n, fn - first_fn))
    end
end

_G._notifier = emu.add_machine_frame_notifier(tick)
