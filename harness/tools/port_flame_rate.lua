-- harness/tools/port_flame_rate.lua
--
-- POP P3.72i — HOW OFTEN DO THE PORT'S TORCH FLAMES ACTUALLY CHANGE?
--
-- The counterpart to oracle_flame_rate.lua, so the two are read off the same kind of
-- signal and can be compared. Jay: "i want you to verify the flame flicker rate from the
-- oracle." The oracle, measured with the room up and nothing else moving (f3000-3400):
-- mean 2.3 frames between updates, 26.2 Hz.
--
-- WHY THE PORT MIGHT DIFFER, and it is structural rather than a tuning value. flicker
-- runs only on room_loop's rl_draw path, which is gated by chars_due -- so the flames
-- advance once per CHARACTER STEP, not on their own clock. The step rate was re-anchored
-- to the oracle's 6 frames at P3.72d, which would put the flames at 6 frames against the
-- oracle's 2.3. In the oracle pburn is called from the play loop and does not answer to
-- the animation cadence at all.
--
-- Read off probe_cel0/probe_cel1 -- the cel numbers the engine PUBLISHES after the swap,
-- so they describe what reached the screen rather than what the VM intends.
local ENGINE = tonumber(os.getenv("P_ENGINE") or "0x2000")
local OUT    = os.getenv("P_OUT") or "build/port_flame_rate.log"
local NFR    = tonumber(os.getenv("P_NFRAMES") or "400")

local CEL0, CEL1 = ENGINE + 9, ENGINE + 10      -- probe_cel0/1 [cutscene_room.s:171]
local ROOM_MAGIC = 0x4B00

local mem = manager.machine.devices[":maincpu"].spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true

local f = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end
local function rd8(a) return mem:read_u8(a) end
local function rd16(a) return rd8(a) * 256 + rd8(a + 1) end

local state, t0, first, prev, lastch, n = "boot", nil, nil, nil, nil, 0
local gaps = {}

local function tick()
    local fn = scr:frame_number()
    if state == "boot" then
        if fn >= 300 then nk:post('LOADM"ROOM"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if fn > t0 + 900 then nk:post('EXEC\n'); state = "run" end
        return
    end
    if state == "run" then
        if rd16(ENGINE + 6) ~= ROOM_MAGIC then return end
        state, first = "trace", fn
        log("# room up at frame " .. fn)
        return
    end
    if state ~= "trace" then return end

    local h = rd8(CEL0) * 256 + rd8(CEL1)
    if prev ~= nil and h ~= prev then
        if lastch then
            local g = fn - lastch
            gaps[g] = (gaps[g] or 0) + 1
        end
        lastch = fn
    end
    prev = h
    n = n + 1
    if n >= NFR then
        local keys, tot, cnt = {}, 0, 0
        for k in pairs(gaps) do keys[#keys + 1] = k end
        table.sort(keys)
        log("# gap histogram (frames between torch-cel changes):")
        for _, k in ipairs(keys) do
            log(string.format("#   %3d frames : %d times", k, gaps[k]))
            tot = tot + k * gaps[k]; cnt = cnt + gaps[k]
        end
        if cnt > 0 then
            log(string.format("# mean %.1f frames between updates = %.1f Hz",
                              tot / cnt, 60.0 / (tot / cnt)))
        end
        log("# oracle, same signal, room up: 2.3 frames = 26.2 Hz")
        if f then f:close() end
        manager.machine:exit()
    end
end

emu.register_frame_done(tick)
