-- harness/tools/erase_trace.lua
--
-- POP P3.72 §7 — WHY IS THE PRINCESS'S OLD FOOTPRINT NOT ERASED?
--
-- The measured defect: from her first column change (walk capture 03, cel 7 at col 37,
-- four captures BEFORE she turns), buffer B carries her entire old footprint at cols
-- 36-41 un-erased while buffer A carries a 14-byte residue at col 35. Her body draws
-- correctly at cols 42-45 in both. Nothing accumulates -- the wrong-byte count is only
-- ever 17 or 32 across 272 frames, which is two buffers each holding a fixed residue.
--
-- Exonerated already, by measurement, so this probe does not re-ask them: the mirror
-- (the failure predates her turn), the peel slot size (widest cel 42x8=336 B in a 344 B
-- slot), and the peel-skip gate (-DALWAYS_PEEL is bit-identical, verified by symbol).
--
-- SO THE QUESTION IS NARROW: at the frames around her move, does ch_moved fire for BOTH
-- of her slots, and does ch_last hold the extent that was actually drawn? Buffer B not
-- erasing AT ALL and buffer A erasing one column short are two different symptoms, and
-- the record distinguishes them.
--
-- THIS PROBE IS PASSIVE. It reads only $40xx -- the bundle's own state, in main RAM,
-- below the $8000 draw window -- and writes NO machine state at all. That is deliberate
-- and it is the P3.71 lesson: dump_front() wrote all four MMU registers and un-mapped
-- the cel bank on every capture, so the checker caused the fault it was measuring. A
-- probe that only reads cannot.
local ENGINE   = tonumber(os.getenv("P_ENGINE")   or "0x2000")
local CUR_BACK = tonumber(os.getenv("P_CURBACK")  or "0x7B06")
local PRI_SLOT = tonumber(os.getenv("P_PRI_SLOT") or "0x4080")
local CH_LAST  = tonumber(os.getenv("P_LAST")     or "0x4098")
local CH_DRAWN = tonumber(os.getenv("P_DRAWN")    or "0x40B8")
local CH_MOVE  = tonumber(os.getenv("P_MOVE")     or "0x4094")
local CH_ANY   = tonumber(os.getenv("P_ANYMOVE")  or "0x4096")
local CH_SEEN  = tonumber(os.getenv("P_SEEN")     or "0x4093")
-- ch_cel is what co_variant RESOLVED for the last character of the last pass -- i.e.
-- the princess, on CP_DRAW. Zero means the P3.71 null-cel guard fired and the slot was
-- stalled instead of drawn, which is the only gate ahead of co_draw (the draw itself is
-- unconditional). ch_slot says WHICH buffer that pass was working on.
local CH_CEL   = tonumber(os.getenv("P_CEL")      or "0x40CE")
local CH_SLOT  = tonumber(os.getenv("P_SLOT")     or "0x4090")
local OUT      = os.getenv("P_OUT") or "build/erase_trace.log"
local NFRAMES  = tonumber(os.getenv("P_NFRAMES") or "70")

local ROOM_MAGIC = 0x4B00
local mem = manager.machine.devices[":maincpu"].spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true

local f = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end
local function rd8(a) return mem:read_u8(a) end
local function rd16(a) return mem:read_u8(a) * 256 + mem:read_u8(a + 1) end

-- ch_last[] index = (character*2 + slot) * 8; the princess is character 1.
-- Entry: x, y, w, h, parity, facing (P3.71), 2 spare.
local function last(slot)
    local o = CH_LAST + (1 * 2 + slot) * 8
    return rd8(o), rd8(o + 1), rd8(o + 2), rd8(o + 3), rd8(o + 4), rd8(o + 5)
end

local state, t0, first_fn, n = "boot", nil, nil, 0

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
        state, first_fn = "trace", fn
        log("# room up at frame " .. fn)
        log("#  the princess only. slot = the buffer being DRAWN this frame.")
        log("# fr   back  rec(x,y,face,cel)   last0(x,y,w,h,par,face)   "
            .. "last1(x,y,w,h,par,face)   move any seen drawn0/1")
        return
    end
    if state ~= "trace" then return end

    local x0, y0, w0, h0, p0, f0 = last(0)
    local x1, y1, w1, h1, p1, f1 = last(1)
    log(string.format(
        "%5d  %d   %3d %3d %3d %3d   %3d %3d %2d %2d %2d %3d   %3d %3d %2d %2d %2d %3d"
        .. "   %d   %d   %02X  %3d/%-3d  cel=$%04X slot=%d",
        fn, rd8(CUR_BACK),
        rd8(PRI_SLOT + 0), rd8(PRI_SLOT + 1), rd8(PRI_SLOT + 2), rd8(PRI_SLOT + 3),
        x0, y0, w0, h0, p0, f0,
        x1, y1, w1, h1, p1, f1,
        rd8(CH_MOVE), rd8(CH_ANY), rd8(CH_SEEN),
        rd8(CH_DRAWN + 1 * 2 + 0), rd8(CH_DRAWN + 1 * 2 + 1),
        rd16(CH_CEL), rd8(CH_SLOT)))

    n = n + 1
    if n >= NFRAMES then
        log("# " .. n .. " frames traced")
        if f then f:close() end
        manager.machine:exit()
    end
end

emu.register_frame_done(tick)
