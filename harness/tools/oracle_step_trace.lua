-- harness/tools/oracle_step_trace.lua — P5.21: EVERY draw, and every character's state, per game frame.
--
-- Derived from oracle_frame_drawset.lua (P5.2), and deliberately the SAME instrument where they
-- overlap -- same arming (the game's own write to `level`), same frame counter, same bin
-- boundary (the write to genCLS at $AC00 that ZEROLSTS makes) -- so frame numbers here are P5.2's
-- and P5.7's. Two things it adds, because P5.2's question did not need them and this one does:
--
--   1. NOT distinct-only. P5.2 kept one record per cel per bin ("drawing the same cel twice costs
--      the window nothing extra"). That is right for residency and wrong for a DRAW VOLUME, which
--      is what P5.10/P5.11/P5.20 have been dividing by. Every write is logged, with XCO, YCO,
--      OFFSET and OPACITY, so the analysis can see a cel drawn twice -- and can see the
--      layrsave/lay pair, which calls setimage twice for ONE draw.
--   2. THE CHARACTERS' OWN RECORDS. Kid ($50) and Shad ($60) [GAMEEQ.S:389-393, 600-632], sixteen
--      bytes each, sampled at the bin boundary: Posn, X, Y, Face, BlockX, BlockY, Action, XVel,
--      YVel, Seq(2), Scrn, Repeat, ID, Sword, Life. The stagger's hit condition is a property of
--      ONE character, and a sword cel in chtable3 cannot be attributed to a character from the
--      draw alone.
--
-- WRITE taps only: 6502 read taps false-0 through the opcode-fetch bypass [apple2e idioms §1].
--
--   P_FROM / P_TO   absolute frame window to log (default 7000..10000; P5.2's demo is 7930..9584)
--   P_OUT           output
local FROM = tonumber(os.getenv("P_FROM") or "7000")
local TO   = tonumber(os.getenv("P_TO") or "10000")
local OUT  = os.getenv("P_OUT") or "build/tmp/oracle_step_trace.txt"

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local nk  = manager.machine.natkeyboard
nk.in_use = true

local out = io.open(OUT, "w")
local function say(s) out:write(s .. "\n") end

local XCO, YCO, OFFSET, IMAGE, OPACITY, TABLE_, BANK = 0x01, 0x02, 0x03, 0x04, 0x06, 0x07, 0x12
local GENCLS, LEVEL = 0xAC00, 0x03F4
local KID, SHAD = 0x50, 0x60

local frames, armed, done = 0, nil, false
local line = {}

local function inwin() return armed and not done and frames >= FROM and frames <= TO end

_G._tl = mem:install_write_tap(LEVEL, LEVEL, "lvl", function(off, data, mask)
    if not armed and frames > 600 then armed = frames end
    return data
end)

_G._ti = mem:install_write_tap(IMAGE + 1, IMAGE + 1, "img", function(off, data, mask)
    if not inwin() then return data end
    local addr = mem:read_u8(IMAGE) | ((data & 0xFF) << 8)
    if addr < 0x0800 then return data end
    local w, h = mem:read_u8(addr), mem:read_u8(addr + 1)
    if w == 0 or h == 0 or w > 40 or h > 200 then return data end
    local tb = mem:read_u8(TABLE_) | (mem:read_u8(TABLE_ + 1) << 8)
    -- ★ WHO CALLED setimage. Not every setimage is a draw: the first run of this tool found the
    -- same cel at one spot with OPACITY 4 and 132, and others at stale-looking y, in 261 of 266
    -- frames. JSR pushes (return-1) high then low, so the caller's return address is at S+1/S+2.
    -- MAME's 6502 names the stack pointer "SP"; "S" is nil (measured: the first cut read 0 and
    -- every caller came back as $0001/$0100).
    local sp = 0
    if not pcall(function() sp = cpu.state["SP"].value end) then
        pcall(function() sp = cpu.state["S"].value end)
    end
    local ret = (mem:read_u8(0x100 + ((sp + 1) & 0xFF)) | (mem:read_u8(0x100 + ((sp + 2) & 0xFF)) << 8)) + 1
    line[#line + 1] = string.format("%d/%04X/%04X/%d/%d/%d/%d/%d/%02X/%04X", mem:read_u8(BANK), tb, addr,
        w, h, mem:read_u8(XCO), mem:read_u8(YCO), mem:read_u8(OFFSET), mem:read_u8(OPACITY), ret & 0xFFFF)
    return data
end)

local function rec(base)
    local t = {}
    for i = 0, 15 do t[#t + 1] = string.format("%02X", mem:read_u8(base + i)) end
    return table.concat(t)
end

_G._tp = mem:install_write_tap(GENCLS, GENCLS, "gencls", function(off, data, mask)
    if not inwin() then return data end
    say(string.format("F %d K=%s S=%s %s", frames, rec(KID), rec(SHAD),
        #line > 0 and table.concat(line, " ") or "-"))
    line = {}
    return data
end)

_G._n = emu.add_machine_frame_notifier(function()
    frames = frames + 1
    if done then return end
    if armed and frames > TO then
        say("# end at frame " .. frames .. " (armed at " .. armed .. ")")
        out:close()
        done = true
        manager.machine:exit()
    end
end)
