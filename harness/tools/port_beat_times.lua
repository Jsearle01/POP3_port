-- port_beat_times.lua — P3.85d: when does each beat START on the port, against the oracle?
--
-- Jay, comparing the two live: "so the zizier pace is a bit slow and it looks like the
-- hourglass appears a bit too early."
--
-- Both are timing claims and both are measurable, so neither is argued here. The oracle's
-- boundaries are already traced [oracle_glass_beats.lua, P3.85b]:
--
--     room up               f2688
--     s_Buildup             f4256 -> f4656   (400 frames)
--     hourglass + flash     f4732            <- 2,044 frames after the room = 34.1 s
--     sand starts           f4773
--     s_Magic               f4773 -> f4886   (113 frames)
--
-- ★ THE LANDMARK IS "ROOM UP", NOT "MACHINE ON", and that is the whole reason this is
-- comparable at all. The two machines boot differently, load differently and reach the
-- scene at different absolute times; the only honest common origin is the first frame the
-- scene itself is on screen. Comparing absolute frame numbers across the two would be
-- measuring the loaders.
--
-- vm_beat is the schedule cursor — a POINTER into cel_plan, not an index — so the beat
-- number is (vm_beat - cel_plan) / PLAN_STRIDE. Both symbols come from the link map so
-- neither is written down here.
local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true
local out = io.open("build/tmp/port_beats.log", "w")
local function log(s) out:write(s .. "\n"); out:flush() end

local M = {}
for line in io.lines("build/obj/flames.map") do
    local n, a = line:match("^Symbol: (%S+) .*= *(%x+)$")
    if n then M[n] = tonumber(a, 16) end
end
local VM_BEAT, CEL_PLAN = M.vm_beat, M.cel_plan
local STRIDE = 6
if not VM_BEAT or not CEL_PLAN then
    log("FAIL vm_beat/cel_plan not in flames.map"); out:close(); return
end
log(string.format("# vm_beat $%04X  cel_plan $%04X  stride %d", VM_BEAT, CEL_PLAN, STRIDE))

-- room-up landmark: the first frame the framebuffer is not blank. Taken from the SCREEN
-- rather than from a flag, because "the picture is on" is what Jay's clock starts on too.
local room_up = nil
local seen = {}
local order = {}

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

    if not room_up then
        local lit = 0
        for y = 40, 180, 20 do
            for x = 40, 600, 40 do
                local p = scr:pixel(x, y)
                if p ~= 0 and p ~= 0xff000000 then lit = lit + 1 end
            end
        end
        if lit > 30 then
            room_up = fn
            log(string.format("# room up at f%d", fn))
        end
        return
    end

    local ptr = mem:read_u8(VM_BEAT) * 256 + mem:read_u8(VM_BEAT + 1)
    if ptr ~= 0 and ptr >= CEL_PLAN then
        local b = (ptr - CEL_PLAN) / STRIDE
        if b == math.floor(b) and b < 24 and not seen[b] then
            seen[b] = fn
            order[#order + 1] = b
        end
    end

    if fn > room_up + 3400 then
        log("")
        log("# beat -> first frame it was current, and frames since the room came up")
        for _, b in ipairs(order) do
            log(string.format("    beat %-2d  f%-6d  room+%-5d  %6.2f s",
                              b, seen[b], seen[b] - room_up, (seen[b] - room_up) / 59.94))
        end
        log("")
        log("# ★ THE COMPARISON. Oracle: hourglass at room+2044 (34.1 s).")
        if seen[13] then
            local d = seen[13] - room_up
            log(string.format("#   Port:   hourglass at room+%d (%.2f s) — %s the oracle by "
                              .. "%d frames (%.2f s)", d, d / 59.94,
                              d < 2044 and "EARLY vs" or "LATE vs",
                              math.abs(2044 - d), math.abs(2044 - d) / 59.94))
        else
            log("#   Port:   beat 13 never became current inside the window")
        end
        out:close()
        manager.machine:exit()
    end
end)
