-- harness/tools/oracle_path.lua -- P5.36 §1/§2: the ORACLE's executed path through the AI's first window,
-- and the state the port must be seeded from.
--
-- Built on oracle_rnd_trace.lua's frame counting and arming (same frame numbers as P5.21/P5.31/P5.35:
-- a machine-frame count since start, armed on the first write to `level` $03F4 after frame 600).
--   * A full INSTRUCTION TRACE (apple2e idioms §4e: `trace <file>,0,,{tracelog ...}`, braces required in
--     the trace-command action) from display frame P_T0 to P_T1, each line carrying the 6502 SP so the
--     post-processor (oracle_path.py) can follow call extents: which routines a controller call ENTERS.
--   * At every game-frame boundary (the write to genCLS $AC00, oracle_step_trace's record point) in the
--     window: the Kid/Shad records and every variable P5.36 §2 names. Most are AUX zero page ($00xx);
--     a write tap runs inside the game, whose ALTZP is on, so mem:read_u8 sees the game's copy.
--     milestone ($0212) and gotsword ($030A) are main/aux RAM as currently mapped for reads.
-- WRITE taps only (idioms §1: 6502 read taps false-0). Headless -debug needs execution_state="run" (§4a).
local OUT = os.getenv("P_OUT") or "build/p536/oracle_path.txt"
local TRACE = os.getenv("P_TRACE") or "C:/Users/jayse/DEV/POP3_port/build/p536/oracle_path.tr"
local T0 = tonumber(os.getenv("P_T0") or "8840")
local T1 = tonumber(os.getenv("P_T1") or "9260")
local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local dbg = manager.machine.debugger
local out = io.open(OUT, "w")
local function say(s) out:write(s .. "\n"); out:flush() end
pcall(function() dbg.execution_state = "run" end)

local VARS = {   -- P5.36 §2, addresses from the oracle's listings (GAMEEQ via AUTO.LST)
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

_G._pl = mem:install_write_tap(0x03F4, 0x03F4, "lvl", function(off, data, mask)
    if not armed and frames > 600 then
        armed = frames
        say(string.format("# armed at frame %d", frames))
    end
    return data
end)
_G._pg = mem:install_write_tap(0xAC00, 0xAC00, "gencls", function(off, data, mask)
    if done or not armed then return data end
    gf = gf + 1
    if frames >= T0 - 40 and frames <= T1 then
        say(string.format("F %d gf=%d K=%s S=%s %s", frames, gf, rec(0x50), rec(0x60), vars()))
    end
    return data
end)
_G._pn = emu.add_machine_frame_notifier(function()
    frames = frames + 1
    if done then return end
    if armed and not tracing and frames >= T0 then
        dbg:command('trace ' .. TRACE .. ',0,,{tracelog " S=%02X",sp}')
        tracing = true
        say(string.format("# trace ON at frame %d", frames))
    elseif tracing and frames >= T1 then
        dbg:command("trace off")
        say(string.format("# trace OFF at frame %d; game frames counted since arming: %d", frames, gf))
        done = true
        out:close()
        manager.machine:exit()
    end
end)
say("# oracle_path: waiting to arm")
