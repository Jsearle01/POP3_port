-- harness/tools/peel_trace.lua
--
-- POP P3.72 §7 (second split) — IS THE PEEL CONTENT CORRECT?
--
-- The erase-record split (erase_trace.lua) exonerated everything around the peel: both
-- buffers converge (ch_drawn 11/11, both ch_last '129 151 6 43 0 1'), co_variant never
-- returns 0, ch_move fires, and neither character's peel slot is overrun (vizier widest
-- 470 B in 480, princess widest 336 B in 344). The records are RIGHT and the pixels are
-- still wrong, so the fault is inside the save/restore pair itself.
--
-- THIS SPLITS SAVE FROM ERASE. blit_save copies the framebuffer background into the peel
-- at the position the record names; blit_erase copies it back. So:
--
--   peel content == the room at ch_last's footprint  ->  SAVE is correct, ERASE is at fault
--   peel content != it                               ->  SAVE is at fault
--
-- Dumped rather than judged in-emulator: the comparison wants the room asset, and Lua
-- has no business deciding what a correct background looks like.
--
-- PASSIVE. Reads $40xx (records) and $6Fxx-$72xx (the peel), both main RAM below the
-- $8000 draw window. Writes no machine state -- the P3.71 lesson, where a checker that
-- wrote four MMU registers caused the fault it was measuring.
local ENGINE   = tonumber(os.getenv("P_ENGINE")   or "0x2000")
local PRI_SLOT = tonumber(os.getenv("P_PRI_SLOT") or "0x4080")
local CH_LAST  = tonumber(os.getenv("P_LAST")     or "0x4098")
local CH_DRAWN = tonumber(os.getenv("P_DRAWN")    or "0x40B8")
local OUT      = os.getenv("P_OUT") or "build/peel_trace.log"
local DUMPFMT  = os.getenv("P_DUMPFMT") or "build/peel_%s_s%d.bin"
-- CH_PEEL/CH_STRIDE are record offsets [char_draw.s]: the peel base and the slot stride
-- come from the RECORD, not from a constant repeated here.
local CH_PEEL, CH_STRIDE = 8, 11

local ROOM_MAGIC = 0x4B00
local mem = manager.machine.devices[":maincpu"].spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true

local f = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end
local function rd8(a) return mem:read_u8(a) end
local function rd16(a) return mem:read_u8(a) * 256 + mem:read_u8(a + 1) end

local function last(slot)
    local o = CH_LAST + (1 * 2 + slot) * 8
    return rd8(o), rd8(o + 1), rd8(o + 2), rd8(o + 3), rd8(o + 4), rd8(o + 5)
end

-- WHICH FRAMES. Chosen off the erase_trace run: 1786 is her last frame at x=120, 1790 is
-- the transition, 1795 is where both buffers have converged, 1801 is settled.
local WANT = {[1786] = true, [1790] = true, [1795] = true, [1801] = true}

local state, t0 = "boot", nil

local function dump(tag)
    local base   = rd16(PRI_SLOT + CH_PEEL)
    local stride = rd16(PRI_SLOT + CH_STRIDE)
    for slot = 0, 1 do
        local x, y, w, h, p, fc = last(slot)
        local a = base + slot * stride
        local t = {}
        for i = 0, w * h - 1 do t[#t + 1] = string.char(rd8(a + i)) end
        local o = io.open(string.format(DUMPFMT, tag, slot), "wb")
        if o then o:write(table.concat(t)); o:close() end
        log(string.format("%s slot%d peel $%04X  last x=%d y=%d w=%d h=%d par=%d face=%d"
                          .. "  drawn=%d", tag, slot, a, x, y, w, h, p, fc,
                          rd8(CH_DRAWN + 1 * 2 + slot)))
    end
end

local function tick()
    local fn = scr:frame_number()
    if state == "boot" then
        if fn >= 300 then nk:post('LOADM"ROOM"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if fn > t0 + 900 then nk:post('EXEC\n'); state = "run" end
        return
    end
    if state == "run" then
        if rd16(ENGINE + 6) ~= ROOM_MAGIC then return end
        state = "trace"
        log("# room up at frame " .. fn)
        log(string.format("# peel base $%04X stride %d (from the RECORD)",
                          rd16(PRI_SLOT + CH_PEEL), rd16(PRI_SLOT + CH_STRIDE)))
        return
    end
    if state ~= "trace" then return end
    if WANT[fn] then dump(tostring(fn)) end
    if fn > 1805 then
        log("# done")
        if f then f:close() end
        manager.machine:exit()
    end
end

emu.register_frame_done(tick)
