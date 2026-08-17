-- port_step_rate.lua — P3.85d: what is the port's REAL step interval, and what sets it?
--
-- Jay, comparing port and oracle live: "the zizier pace is a bit slow." Measured, it is:
-- Vraise + Pback is exactly 14 plays and the oracle spends 76 frames on it (5.43 f/play,
-- bracketed by s_Buildup's end and the addglass1 write); the port spends 103 (7.36).
--
-- ★ AND cad_tab IS FLAT 6, SO THE TABLE IS NOT WHAT SETS THE PACE. That matters more than
-- the discrepancy, because char_draw.s already carries the warning against fixing this the
-- obvious way: "a minimum tuned to cancel an overrun becomes wrong the moment the overrun
-- changes, which is precisely how cad_tab came to sit at 3.83 against a rate nobody had
-- measured." Lowering 6 until the average looks right would be that mistake again.
--
-- So this measures WHICH of two mechanisms is in force, because they need opposite fixes:
--
--   QUANTISATION — the room paces on the flame cadence (flm_cad 2,2,3, ~2.33 frames) and a
--     step can only fire on a room iteration. A 6-frame target then lands on the 3rd
--     iteration at 7.0, and the intervals cluster on MULTIPLES OF ~2.33 with almost nothing
--     in between. Fix: shape the cadence so the ITERATION counts average right (2,2,3),
--     which is what a cadence table is for.
--
--   DRAW OVERRUN — the step is late because the frame's drawing does not fit the budget.
--     Then the intervals are spread and lumpy, they track what is on screen, and no table
--     can go below the floor. Fix: the draw, not the schedule.
--
-- cad_idx advances exactly once per step [vm_nextframe], so a write tap on it is a step
-- tick with no inference in between.
local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true
local out = io.open("build/tmp/port_step.log", "w")
local function log(s) out:write(s .. "\n"); out:flush() end

local M = {}
for line in io.lines("build/obj/flames.map") do
    local n, a = line:match("^Symbol: (%S+) .*= *(%x+)$")
    if n then M[n] = tonumber(a, 16) end
end
if not M.cad_idx then log("FAIL no cad_idx in flames.map"); out:close(); return end
log(string.format("# cad_idx $%04X", M.cad_idx))

local steps = {}
_G._tap = mem:install_write_tap(M.cad_idx, M.cad_idx, "t", function(offset, data)
    steps[#steps + 1] = scr:frame_number()
    return data
end)

local state, t0 = "boot", nil
_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if state == "boot" then
        if fn >= 300 then nk:post('LOADM"ROOM"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if fn > t0 + 900 then nk:post('EXEC\n'); state = "run" end
        return
    end
    if fn < 5000 then return end

    local hist, n, tot = {}, 0, 0
    for i = 2, #steps do
        local g = steps[i] - steps[i - 1]
        if g > 0 and g < 40 then                 -- drop the song holds; they are not steps
            hist[g] = (hist[g] or 0) + 1
            n = n + 1
            tot = tot + g
        end
    end
    log("")
    log("# interval between consecutive steps (holds over 40 frames excluded)")
    local keys = {}
    for k in pairs(hist) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        log(string.format("    %2d frames  x%-4d %s", k, hist[k],
                          string.rep("#", math.min(60, hist[k]))))
    end
    log("")
    log(string.format("# %d steps, mean %.2f frames/play   (cad_tab says 6; oracle is 5.43)",
                      n, tot / n))
    log("# CLUSTERED on ~2.33 multiples (4-5 and 7) => quantisation by the room's loop.")
    log("# SPREAD and lumpy                        => the draw does not fit; fix the draw.")
    out:close()
    manager.machine:exit()
end)
