-- port_flash_duty.lua — P3.94: what does the flash actually LOOK like, in video frames?
--
-- Jay, on the P3.93 gate: "i only see one long strobe."
--
-- P3.93 fixed the rate and verified it as a rate: sc_lit is armed five times, once per
-- play of the hourglass beat, at frames 4186 / 4196 / 4204 / 4210 / 4218. That is correct
-- and it is not what he is looking at. ★ THE ARMING RATE IS NOT THE DUTY CYCLE. What
-- reaches the eye is the PALETTE, and the palette is white from the moment sc_lit is armed
-- until it counts down to zero — a duration measured in DRAWN FRAMES (one decrement per
-- scenery_frame call, i.e. per room_loop iteration), not in video frames.
--
-- An iteration is ~3.6 video frames at this point in the scene, so SC_LIT_FRAMES = 3 is
-- about ELEVEN video frames of white, while the strobes are only 8-10 frames apart. If
-- that is right the white periods overlap and there is no dark gap at all: five arms, one
-- continuous white. Which is exactly what he reported.
--
-- ★ SC_LIT_FRAMES IS A DURATION IN THE WRONG UNIT, and this project has had that exact bug
-- before: P3.25's cadence counter decremented once per LOOP ITERATION while the table was
-- in video frames, so "a 2.60-iteration step took 3.09 frames". The table was in the right
-- unit; the counter was not. Same shape, one object along.
--
-- SO MEASURE THE PALETTE, NOT THE COUNTER. A write tap on $FFB0 records every change to
-- the colour the screen is actually showing, in video frames, and the runs of white
-- against the runs of normal ARE the duty cycle. No inference between the instrument and
-- what the eye receives.
local OUT = os.getenv("P_OUT") or "build/tmp/flash_duty.log"
local FROM = tonumber(os.getenv("P_FROM") or "4150")
local TO   = tonumber(os.getenv("P_TO") or "4300")
local PAL_WHITE = 0x3F

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true
local out = io.open(OUT, "w")
local function log(s) out:write(s .. "\n"); out:flush() end

local F = {}
for line in io.lines("build/obj/flames.map") do
    local n, a = line:match("^Symbol: (%S+) .*= *(%x+)$")
    if n then F[n] = tonumber(a, 16) end
end

-- Entry 0 is the room's BLACK ($00) and goes to white with the rest, so a single register
-- is enough to separate "white" from "normal" — and using one avoids counting a four-store
-- restore as four events.
local ev = {}
_G._tp = mem:install_write_tap(0xFFB0, 0xFFB0, "pal", function(o, d)
    local fn = scr:frame_number()
    if fn >= FROM and fn <= TO then ev[#ev + 1] = { f = fn, d = d } end
    return d
end)

-- ...and sc_lit, EVERY write including the zeroes. P3.91's trace filtered `d ~= 0` to
-- separate arming from countdown, which also hid the one write that says the strobe ENDED.
local lits = {}
if F.sc_lit then
    _G._tl = mem:install_write_tap(F.sc_lit, F.sc_lit, "lit", function(o, d)
        local fn = scr:frame_number()
        if fn >= FROM and fn <= TO then lits[#lits + 1] = { f = fn, d = d } end
        return d
    end)
end

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
    if fn <= TO then return end

    log(string.format("# $FFB0 writes, frames %d..%d  (white = $%02X)", FROM, TO, PAL_WHITE))
    log("")
    log("# every sc_lit write, zeroes included — the zero is the strobe ENDING")
    for _, e in ipairs(lits) do
        log(string.format("    f%-6d sc_lit = %d", e.f, e.d))
    end

    log("")
    log("# THE DUTY CYCLE AS THE EYE RECEIVES IT — runs of white against runs of normal")
    local cur, since, runs = nil, nil, {}
    for _, e in ipairs(ev) do
        local w = (e.d == PAL_WHITE)
        if cur == nil then cur, since = w, e.f
        elseif w ~= cur then
            runs[#runs + 1] = { w = cur, a = since, b = e.f }
            cur, since = w, e.f
        end
    end
    if cur ~= nil then runs[#runs + 1] = { w = cur, a = since, b = TO } end
    for _, r in ipairs(runs) do
        log(string.format("    %-6s f%-6d .. f%-6d  %3d video frames",
                          r.w and "WHITE" or "normal", r.a, r.b, r.b - r.a))
    end
    log("")
    log("# FIVE WHITE RUNS WITH DARK BETWEEN => five strobes, as intended.")
    log("# ONE LONG WHITE RUN            => the white outlasts the gap; SC_LIT_FRAMES is")
    log("#                                 a duration counted in the wrong unit.")
    out:close()
    manager.machine:exit()
end)
