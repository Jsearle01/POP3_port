-- port_exit_cost.lua — P3.87: the cost lives in chars_frame; WHAT is it drawing?
--
-- port_phase_cost.lua localised the slip with no room left for argument. Per room_loop
-- iteration, in video frames, `flicker` is a FLAT 1.00 at every beat in the scene — so
-- the hourglass, the sand and the torches are not it — and `pre` and `present` are ~0:
--
--     scene beat 1 / 6 / 10   song holds, nothing moves      chars 1.88 .. 2.00
--     scene beat 4 / 8        Vwalk, he crosses the room     chars 3.00 .. 3.07
--     scene beat 16 / 17 / 18 after Vexit                    chars 3.96 .. 3.97
--
-- ★ AND SCENE BEAT 16 IS A HOLD, the same kind of beat as 1/6/10 — `("-", "", 12)`, no
-- jump, both characters simply continuing. It costs DOUBLE what those holds cost and a
-- full frame more than an active walk. So the question is not "why is drawing expensive"
-- but "what is still being drawn after the vizier has left."
--
-- Vexit ends `goto Vwalk2` [FRAMEDEF.S], so his sequence does not stop when he is out of
-- the room — he keeps walking, forever, past the left edge. Two things follow and they
-- cost differently, which is why this samples rather than assumes:
--
--   ch_anymove stays 1  — a character that never stops moving never lets the frame skip
--     the peel, so the erase and save passes run for the rest of the scene. That is the
--     step from 2.0 to 3.0 frames and it is the SAME cost a walk beat pays.
--   the blit CLIPS      — once CH_X takes him off the left edge every row of his cel is
--     partially or wholly outside the buffer. That is a different, extra cost, and it is
--     the candidate for the step from 3.0 to 4.0.
--
-- Neither is inferred here. CH_X for both characters and ch_anymove are polled ONCE PER
-- VIDEO FRAME from the frame notifier — never from inside a tap, which is what broke the
-- first version of port_phase_cost — and reported against the beat.
local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true
local out = io.open("build/tmp/port_exit_cost.log", "w")
local function log(s) out:write(s .. "\n"); out:flush() end

local function readmap(path)
    local m = {}
    for line in io.lines(path) do
        local n, a = line:match("^Symbol: (%S+) .*= *(%x+)$")
        if n then m[n] = tonumber(a, 16) end
    end
    return m
end
local F = readmap("build/obj/flames.map")
local R = readmap("build/obj/room.map")
log(string.format("# viz_slot $%04X  pri_slot $%04X  ch_anymove $%04X  char_one $%04X",
                  F.viz_slot, F.pri_slot, F.ch_anymove, F.char_one))

local beat = -1
_G._tb = mem:install_write_tap(F.vm_beat, F.vm_beat, "beat", function(o, d)
    beat = beat + 1; return d
end)

-- char_one entry count: 2 per pass, so 6 in a peeling frame and 2 in a draw-only one.
-- §10a — the PC discriminates an execution from a read of the same byte.
local calls, iters = 0, 0
_G._t1 = mem:install_read_tap(F.char_one, F.char_one, "co", function(o, d)
    local ok, v = pcall(function() return cpu.state["PC"].value end)
    if ok and v == F.char_one + 1 then calls = calls + 1 end
    return d
end)
_G._t2 = mem:install_write_tap(R.flm_idx, R.flm_idx, "it", function(o, d)
    iters = iters + 1; return d
end)

local function s16(a)
    local v = mem:read_u8(a) * 256 + mem:read_u8(a + 1)
    if v >= 0x8000 then v = v - 0x10000 end
    return v
end

local acc, prevbeat, lastc, lasti = {}, nil, 0, 0
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
    if fn < 5000 then
        if beat >= 0 then
            local a = acc[beat]
            if not a then
                a = { n = 0, vx = {}, px = {}, mv = 0, c0 = calls, i0 = iters, f0 = fn }
                acc[beat] = a
            end
            a.n = a.n + 1
            a.vx[#a.vx + 1] = s16(F.viz_slot)
            a.px[#a.px + 1] = s16(F.pri_slot)
            a.mv = a.mv + mem:read_u8(F.ch_anymove)
            a.c1, a.i1, a.f1 = calls, iters, fn
        end
        return
    end

    log("")
    log("# PER BEAT — the vizier's CH_X (oracle CharX units, 2 px each), and whether the")
    log("# frame was allowed to skip the peel. char_one runs 2x per pass: 6 calls in a")
    log("# peeling iteration, 2 in a draw-only one.")
    log("")
    log("    beat  frames   viz x: first -> last   pri x   anymove%   char_one/iter")
    local bk = {}
    for k in pairs(acc) do bk[#bk + 1] = k end
    table.sort(bk)
    for _, b in ipairs(bk) do
        local a = acc[b]
        local di = (a.i1 or 0) - a.i0
        local dc = (a.c1 or 0) - a.c0
        log(string.format("    %-5d %-8d %6d -> %-6d %6d   %5.1f%%     %-6.2f f%d..f%d",
                          b, a.n, a.vx[1], a.vx[#a.vx], a.px[#a.px],
                          100 * a.mv / a.n, di > 0 and dc / di or 0, a.f0, a.f1 or 0))
    end

    -- ★ WHERE IS THE LEFT EDGE? CharX is in two-pixel units and the mode is 320 px wide,
    -- so x < 0 is off the left of the buffer and x >= 160 is off the right. Report the
    -- frame at which he crosses, so the cost step can be compared against a real edge
    -- rather than against a beat boundary that merely happens to be nearby.
    log("")
    log("# the vizier's crossing, by beat")
    for _, b in ipairs(bk) do
        local a = acc[b]
        for i, x in ipairs(a.vx) do
            if x < 0 and (i == 1 or a.vx[i - 1] >= 0) then
                log(string.format("    beat %d: CH_X goes negative at frame %d (x=%d)",
                                  b, a.f0 + i - 1, x))
            end
        end
    end
    out:close()
    manager.machine:exit()
end)
