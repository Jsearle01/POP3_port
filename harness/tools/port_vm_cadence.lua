-- harness/tools/port_vm_cadence.lua
--
-- POP P3.25 — DOES THE VM ACTUALLY STEP AT THE 13/5 CADENCE?
--
-- P3.23 measured the oracle's SPEED 7 at 2.6 video frames per animation step and
-- established that frame counts transfer 1:1, so the port should step on a 3,3,2,3,2
-- cycle averaging 2.6. That is a table in char_draw.s; this measures whether the
-- machine achieves it.
--
-- MEASURED ON THE CEL BYTE, not on a counter the VM increments. The slot record's
-- CH_CEL (offset 3) changes when the interpreter selects a new cel, so the gaps
-- between changes ARE the step interval as the screen sees it. A counter would tell
-- me what the VM thinks it did; the cel tells me what it did.
--
-- The demo sequence holds each cel for four steps, so a change appears every fourth
-- step -- the gap histogram is therefore in units of 4 steps, and the MEAN divided by
-- 4 is the per-step cadence. Reported both ways.
local OUT   = os.getenv("P_OUT") or "build/port_vm_cadence.log"
local PRI   = tonumber(os.getenv("P_PRI") or "0")
local FIRST = tonumber(os.getenv("P_FIRST") or "1600")
local LAST  = tonumber(os.getenv("P_LAST") or "3400")

local scr = manager.machine.screens:at(1)
local mem = manager.machine.devices[":maincpu"].spaces["program"]
local f = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end

local prev, last_fn, gaps, n = nil, nil, {}, 0
-- Same boot sequence port_flame_rate.lua uses: this tool must reach the program
-- itself, so it types LOADM and EXEC rather than assuming something else loaded it.
local nk = manager.machine.natkeyboard
nk.in_use = true
local state, t0 = "boot", nil

local function tick()
    local fn = scr:frame_number()
    if state == "boot" then
        if fn >= 120 then nk:post('LOADM"ROOM"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if fn > t0 + 900 then nk:post('EXEC\n'); state = "wait" end
        return
    end
    if state == "wait" then
        if mem:read_u8(0x2008) > 0 then state = "watch" end   -- flicker loop running
        return
    end
    if PRI == 0 or fn < FIRST then return end
    if fn > LAST then
        local keys = {}
        for k in pairs(gaps) do keys[#keys + 1] = k end
        table.sort(keys)
        log("# gaps between CEL CHANGES (video frames):")
        local tot, cnt = 0, 0
        for _, k in ipairs(keys) do
            log(string.format("#   %3d frames : %d times", k, gaps[k]))
            tot = tot + k * gaps[k]; cnt = cnt + gaps[k]
        end
        if cnt > 0 then
            local mean = tot / cnt
            log(string.format("# mean %.2f frames between cel changes over %d samples",
                              mean, cnt))
            log("# the demo changes cel EVERY step, so frames-between-cel-changes IS")
            log("#   frames-per-step. (It held a cel for 4 steps until P3.29 densified")
            log("#   it; the /4 that used to be here would now divide by the wrong")
            log("#   number -- a stale constant in a measuring tool reads as a")
            log("#   measurement. P3.31: the fragment it left behind was a Lua SYNTAX")
            log("#   ERROR, so this whole file has not parsed since. A measuring tool")
            log("#   that cannot load reports nothing, and nothing looks like silence.)")
            log(string.format("# oracle floor 6.00 (measured, P3.72d); overrun %+.2f frames",
                              mean - 6.00))
        else
            log("# NO CEL CHANGES seen — the VM did not step")
        end
        manager.machine:exit()
        return
    end
    local cel = mem:read_u8(PRI + 3)
    if prev == nil then
        prev, last_fn = cel, fn
    elseif cel ~= prev then
        if last_fn then
            local g = fn - last_fn
            gaps[g] = (gaps[g] or 0) + 1
            n = n + 1
        end
        prev, last_fn = cel, fn
    end
end

_G._notifier = emu.add_machine_frame_notifier(tick)
