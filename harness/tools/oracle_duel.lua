-- harness/tools/oracle_duel.lua -- P5.38 §1: the ORACLE through its first exchange, one boot.
--
-- oracle_path.lua's records and oracle_blueprint.lua's register trace in ONE run, so the two share frame
-- numbers by construction:
--   * at every game-frame boundary (the write to genCLS $AC00) from P_T0-40 to P_T1: the Kid/Shad records and
--     the globals the AI reads (oracle_path.lua's list), in oracle_path.txt's format;
--   * an instruction trace from display frame P_T0 to P_T1 with SP, A, X, Y on every line
--     (`S=sss A=aa X=xx Y=yy|PPPP: instr`, oracle_blueprint.py's LINE) -- RND's result is A at its rts, RDBLOCK's
--     arguments are A/X/Y at its entry.
-- Arming and frame numbers are oracle_rnd_trace.lua's (frames since start; armed on the first write to
-- `level` $03F4 after frame 600) -- the numbering of P5.21..P5.37. WRITE taps only (apple2e idioms §1).
local OUT = os.getenv("P_OUT") or "build/p538/oracle_duel.txt"
local TRACE = os.getenv("P_TRACE") or "C:/Users/jayse/DEV/POP3_port/build/p538/oracle_duel.tr"
local T0 = tonumber(os.getenv("P_T0") or "8840")
local T1 = tonumber(os.getenv("P_T1") or "10950")
local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local dbg = manager.machine.debugger
pcall(function() dbg.execution_state = "run" end)
local out = io.open(OUT, "w")
local function say(s) out:write(s .. "\n"); out:flush() end

local VARS = {
    {"refract", 0xA1}, {"justblocked", 0x7E}, {"gdtimer", 0x7F}, {"alertguard", 0xE4},
    {"droppedout", 0xE7}, {"offguard", 0x8A}, {"EnemyAlert", 0xD1}, {"KidStrength", 0xCE},
    {"OppStrength", 0xCC}, {"MaxOppStr", 0xDC}, {"guardprog", 0xDD}, {"RNDseed", 0x9E},
    {"milestone", 0x0212}, {"heroic", 0xD3}, {"gotsword", 0x030A},
    {"clrF", 0xD4}, {"clrB", 0xD5}, {"clrU", 0xD6}, {"clrD", 0xD7}, {"clrbtn", 0xD8},
    {"JSTKX", 0x18}, {"JSTKY", 0x19}, {"btn", 0x3D},
}
local frames, armed, tracing, done, gf = 0, nil, false, false, 0
local function rec(base)
    local t = {}
    for i = 0, 15 do t[#t + 1] = string.format("%02X", mem:read_u8(base + i)) end
    return table.concat(t)
end
local function vars()
    local t = {}
    for _, v in ipairs(VARS) do t[#t + 1] = string.format("%s=%02X", v[1], mem:read_u8(v[2])) end
    return table.concat(t, " ")
end
_G._dl = mem:install_write_tap(0x03F4, 0x03F4, "lvl", function(off, data, mask)
    if not armed and frames > 600 then armed = frames; say("# armed at frame " .. frames) end
    return data
end)
_G._dg = mem:install_write_tap(0xAC00, 0xAC00, "gencls", function(off, data, mask)
    if done or not armed then return data end
    gf = gf + 1
    if frames >= T0 - 40 and frames <= T1 then
        say(string.format("F %d gf=%d K=%s S=%s %s", frames, gf, rec(0x50), rec(0x60), vars()))
    end
    return data
end)
_G._dn = emu.add_machine_frame_notifier(function()
    frames = frames + 1
    if done or not armed then return end
    if not tracing and frames >= T0 then
        dbg:command('trace ' .. TRACE .. ',0,,{tracelog "S=%03X A=%02X X=%02X Y=%02X|",sp,a,x,y}')
        tracing = true
        say("# trace ON at frame " .. frames)
    elseif tracing and frames >= T1 then
        dbg:command("trace off")
        say(string.format("# trace OFF at frame %d; game frames counted since arming: %d", frames, gf))
        done = true
        out:close()
        manager.machine:exit()
    end
end)
say("# oracle_duel: waiting to arm")
