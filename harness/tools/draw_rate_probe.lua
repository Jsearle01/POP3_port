-- harness/tools/draw_rate_probe.lua
--
-- POP P3.51 — HOW OFTEN DOES THE ROOM ACTUALLY DRAW, now that the render is gated?
--
-- The cadence gate should make room_loop skip flicker/chars_frame/swap on frames where no
-- animation step is due. Two read-tap counts from frame_baseline disagreed about whether
-- it does -- chars_frame 1.00 per iteration against flicker 0.71 -- and read-tap counts
-- are exactly the reading this project has been burned by (idioms §10a: a hit is not proof
-- of execution, the inflation is not uniform, and P3.49 found a range read-tap reporting a
-- flat zero for a region that was demonstrably read).
--
-- WRITE-taps have been consistent throughout that history: every per-slot write count in
-- P3.48/P3.49/P3.50 reconciled exactly against frame counts and instruction widths. So
-- this counts a WRITE that happens exactly once per drawn frame -- `inc probe_frames`,
-- the last thing room_loop does after the swap -- and divides by elapsed video frames.
--
--     draws / video frame = 1.000  ->  the gate is not gating
--     draws / video frame ~ 1/3.15 ->  it draws once per animation step, as designed
--
-- No inference, no per-iteration bookkeeping, and nothing that depends on what a read-tap
-- does: one counter against one clock.
local OUT    = os.getenv("P_OUT")    or "build/draw_rate.log"
local PFRAMES = tonumber(os.getenv("P_PFRAMES") or "0x2008")
local VMDUE   = tonumber(os.getenv("P_VMDUE")   or "0x3C70")
local FIRST  = tonumber(os.getenv("P_FIRST")  or "1900")
local LAST   = tonumber(os.getenv("P_LAST")   or "3400")

local scr = manager.machine.screens:at(1)
local mem = manager.machine.devices[":maincpu"].spaces["program"]
local f   = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end

local state, t0 = "boot", nil
local armed, cur_frame = false, 0
local draws, steps, first_fn, last_fn = 0, 0, nil, nil

_G._pf = mem:install_write_tap(PFRAMES, PFRAMES, "probe_frames", function(off, data, mask)
    if armed and cur_frame >= FIRST and cur_frame <= LAST then
        draws = draws + 1
        if first_fn == nil then first_fn = cur_frame end
        last_fn = cur_frame
    end
    return data
end)

-- `std vm_due` fires once per animation step (two byte-writes; halved below).
_G._vd = mem:install_write_tap(VMDUE, VMDUE + 1, "vm_due", function(off, data, mask)
    if armed and cur_frame >= FIRST and cur_frame <= LAST then steps = steps + 1 end
    return data
end)

local function report()
    local span = (last_fn or 0) - (first_fn or 0)
    log("# DRAW RATE — one write-counter against the video clock")
    log(string.format("# probe_frames $%04X  vm_due $%04X  sampled frames %d..%d", PFRAMES, VMDUE, FIRST, LAST))
    log(string.format("# draws %d over %d video frames", draws, span))
    if span > 0 and draws > 0 then
        log(string.format("# %.3f draws per video frame  =  one draw every %.2f frames",
                          draws / span, span / draws))
    end
    log(string.format("# animation steps %d (std vm_due = 2 writes -> %d steps)", steps, steps // 2))
    if steps > 0 and draws > 0 then
        log(string.format("# %.2f draws per animation step", draws / (steps / 2)))
    end
end

local nk = manager.machine.natkeyboard
nk.in_use = true

local function tick()
    cur_frame = scr:frame_number()
    local fn = cur_frame
    if state == "boot" then
        if fn >= 120 then nk:post('LOADM"ROOM"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if fn > t0 + 900 then nk:post('EXEC\n'); state = "wait" end
        return
    end
    if state == "wait" then
        if mem:read_u8(PFRAMES) > 0 then armed, state = true, "watch" end
        return
    end
    if fn > LAST then report(); manager.machine:exit() end
end

_G._notifier = emu.add_machine_frame_notifier(tick)
