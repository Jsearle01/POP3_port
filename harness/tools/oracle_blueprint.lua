-- harness/tools/oracle_blueprint.lua -- P5.37 §1: the ORACLE'S OWN loaded level, and its RDBLOCK answers.
--
--   * BROAD: $B700-$BFFF (BLUETYPE, BLUESPEC, LINKLOC, LINKMAP, MAP, INFO; EQ.S:258-265, blueprnt = $B700)
--     dumped from PHYSICAL RAM -- the main bank (:ram m_pointer) AND the aux bank (:aux:ext80 m_ram), read
--     as save-state items, so the dump does not depend on which bank the //e has switched in -- at three
--     points: just after the demo level loads, at the game-frame-179 boundary, and after the window.
--   * NARROW: an instruction trace (apple2e idioms §4e) over display frames P_T0..P_T1 with SP, A, X, Y on
--     every line (`S=sss A=aa X=xx Y=yy|PPPP: instr`): RDBLOCK's arguments (A screen, X block x, Y block y
--     at $D0D0, CTRLSUBS.S:136-138) and its result (A at its final rts), for oracle_blueprint.py.
-- Arming and frame numbers are oracle_rnd_trace.lua's (frames since start; armed on the first write to
-- `level` $03F4 after frame 600) -- the numbering of P5.21/P5.31/P5.35/P5.36.
local OUTDIR = os.getenv("P_OUTDIR") or "build/p537"
local TRACE = os.getenv("P_TRACE") or "C:/Users/jayse/DEV/POP3_port/build/p537/oracle_bp.tr"
local T0 = tonumber(os.getenv("P_T0") or "8840")
local T1 = tonumber(os.getenv("P_T1") or "9260")
local DUMPS = {7900, 8882, 9254}
local mem = manager.machine.devices[":maincpu"].spaces["program"]
local dbg = manager.machine.debugger
pcall(function() dbg.execution_state = "run" end)
local log = io.open(OUTDIR .. "/oracle_bp.txt", "w")
local function say(s) log:write(s .. "\n"); log:flush() end

local function item(tag, name)
    local d = manager.machine.devices[tag]
    return emu.item(d.items[name])
end
local MAIN = item(":ram", "0/m_pointer")
local AUX = item(":aux:ext80", "0/m_ram")

local function dump(fr)
    for _, bank in ipairs({{"main", MAIN}, {"aux", AUX}}) do
        local f = io.open(string.format("%s/blueprint_%s_%d.bin", OUTDIR, bank[1], fr), "wb")
        local t = {}
        for a = 0xB700, 0xBFFF do t[#t + 1] = string.char(bank[2]:read(a)) end
        f:write(table.concat(t)); f:close()
    end
    say(string.format("# dumped $B700-$BFFF, main and aux, at frame %d", fr))
end

local frames, armed, tracing, done = 0, nil, false, false
_G._bl = mem:install_write_tap(0x03F4, 0x03F4, "lvl", function(off, data, mask)
    if not armed and frames > 600 then armed = frames; say("# armed at frame " .. frames) end
    return data
end)
_G._bn = emu.add_machine_frame_notifier(function()
    frames = frames + 1
    if done or not armed then return end
    for _, d in ipairs(DUMPS) do if frames == d then dump(d) end end
    if not tracing and frames >= T0 then
        dbg:command('trace ' .. TRACE .. ',0,,{tracelog "S=%03X A=%02X X=%02X Y=%02X|",sp,a,x,y}')
        tracing = true
        say("# trace ON at frame " .. frames)
    elseif tracing and frames >= T1 then
        dbg:command("trace off")
        say("# trace OFF at frame " .. frames)
    end
    if frames > DUMPS[#DUMPS] and frames > T1 then
        done = true; log:close(); manager.machine:exit()
    end
end)
say("# oracle_blueprint: waiting to arm")
