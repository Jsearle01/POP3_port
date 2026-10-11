-- harness/tools/oracle_rnd_trace.lua -- P5.35 recon instrument for the ORACLE (apple2e), written in
-- build/p535 and promoted here so the AutoCtrl scoping can be re-run. Findings:
-- reports/20261011-110617-p5-35-autoctrl-findings.md. Self-check at P5.35: reproduced P5.21's
-- oracle_step_trace.txt K/S records 320/320.
-- ★ KNOWN DEFECT, kept so the logs it wrote stay interpretable: ctx()'s `id=` reads $4C (CharRepeat);
-- CharID is $4D. Tell kid from guard by return address ($3D18 kid / $3CC8 guard) and gp=, not id=.
--
-- Logs EVERY write to RNDseed ($9E, aux ZP; GAMEEQ.S:426 -> AUTO/GRAFIX .LST "009E RNDseed") with
-- old value, new value, PC, the caller's return address (and the one below it), and the AI context
-- (CharID $4C, guardprog $DD, CharPosn $40, CharSword $4E, KidPosn $50, ShadPosn $60, PlayCount $A0).
-- Also logs every AUTOCTRL entry, detected as DoRelease's write to clrF ($D4) whose return address is
-- $549C (AUTO.LST: AUTOCTRL=$5499, "jsr DoRelease" 3 bytes). And the game-frame boundary (write to
-- genCLS $AC00) with the Kid/Shad records, in oracle_step_trace.lua's exact format, so frame numbers
-- can be checked against build/tmp/oracle_step_trace.txt.
--
-- WRITE taps only (apple2e idioms §1: 6502 read taps false-0). Taps kept in _G (§2 GC gotcha).
-- Frame counter and arming are oracle_step_trace.lua's (frame notifier count since start; armed on
-- the first write to `level` $03F4 after frame 600).
local TO  = tonumber(os.getenv("P_TO") or "12500")
local OUT = os.getenv("P_OUT") or "build/p535/oracle_rnd_trace.txt"

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local nk  = manager.machine.natkeyboard
nk.in_use = true

local out = io.open(OUT, "w")
local function say(s) out:write(s .. "\n") end

local frames, armed, done = 0, nil, false
local nrnd, nauto = 0, 0

local function sp()
    local v = 0
    if not pcall(function() v = cpu.state["SP"].value end) then
        pcall(function() v = cpu.state["S"].value end)
    end
    return v
end
local function ret_at(s, k)  -- k-th return address on the stack (k=0 top)
    local lo = mem:read_u8(0x100 + ((s + 1 + 2 * k) & 0xFF))
    local hi = mem:read_u8(0x100 + ((s + 2 + 2 * k) & 0xFF))
    return ((lo | (hi << 8)) + 1) & 0xFFFF
end
local function pc()
    local v = 0
    pcall(function() v = cpu.state["PC"].value end)
    return v
end
local function ctx()
    return string.format("id=%d gp=%d cp=%d csw=%d kp=%d ksw=%d sp=%d ssw=%d sf=%d pc#=%d lvl=%d",
        mem:read_u8(0x4C), mem:read_u8(0xDD), mem:read_u8(0x40), mem:read_u8(0x4E),
        mem:read_u8(0x50), mem:read_u8(0x5E), mem:read_u8(0x60), mem:read_u8(0x6E),
        mem:read_u8(0x63), mem:read_u8(0xA0), mem:read_u8(0x03F4))
end

_G._tl = mem:install_write_tap(0x03F4, 0x03F4, "lvl", function(off, data, mask)
    if not armed and frames > 600 then
        armed = frames
        say(string.format("# armed at frame %d (level write %d)", frames, data & 0xFF))
    end
    return data
end)

_G._tr = mem:install_write_tap(0x9E, 0x9E, "rndseed", function(off, data, mask)
    if done then return data end
    local s = sp()
    local old = mem:read_u8(0x9E)
    local new = data & 0xFF
    local lcg = ((5 * old + 23) & 0xFF) == new and "" or " NONLCG"
    nrnd = nrnd + 1
    say(string.format("R %d %02X>%02X pc=%04X r0=%04X r1=%04X %s%s", frames, old, new, pc(),
        ret_at(s, 0), ret_at(s, 1), ctx(), lcg))
    return data
end)

_G._ta = mem:install_write_tap(0xD4, 0xD4, "clrF", function(off, data, mask)
    if done or not armed then return data end
    local s = sp()
    if ret_at(s, 0) == 0x549C then
        nauto = nauto + 1
        say(string.format("A %d r1=%04X %s", frames, ret_at(s, 1), ctx()))
    end
    return data
end)

local function rec(base)
    local t = {}
    for i = 0, 15 do t[#t + 1] = string.format("%02X", mem:read_u8(base + i)) end
    return table.concat(t)
end

_G._tp = mem:install_write_tap(0xAC00, 0xAC00, "gencls", function(off, data, mask)
    if done or not armed then return data end
    say(string.format("F %d K=%s S=%s seed=%02X gp=%d", frames, rec(0x50), rec(0x60),
        mem:read_u8(0x9E), mem:read_u8(0xDD)))
    return data
end)

_G._n = emu.add_machine_frame_notifier(function()
    frames = frames + 1
    if done then return end
    if frames % 1000 == 0 then say(string.format("# frame %d rnd=%d auto=%d", frames, nrnd, nauto)) end
    if frames > TO then
        say(string.format("# end at frame %d (armed at %s) rnd=%d auto=%d", frames, tostring(armed), nrnd, nauto))
        out:close()
        done = true
        manager.machine:exit()
    end
end)
