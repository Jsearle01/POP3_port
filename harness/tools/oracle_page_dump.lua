-- harness/tools/oracle_page_dump.lua
--
-- POP P3.17 — dump the ORACLE's hires pages during the princess cutscene.
--
-- The princess's room is not a picture in the oracle: it is a tiled block layout
-- assembled by the background renderer. Rebuilding it from BGTAB data would mean
-- porting that renderer, which is the engine and out of scope for A+B. So the room
-- is acquired the way the dispatch allows -- dumped from the running oracle and
-- converted -- which is also how P3.2 acquired its reference.
--
-- Dumps MAIN memory $2000-$3FFF (hires page 1) and $4000-$5FFF (page 2) at a chosen
-- frame. Both, because which one is displayed depends on where in the flip the frame
-- lands, and comparing the two offline is cheaper than reading the soft switches.
--
-- Reads go through mem:read_u8 (a debugger read), NOT an install_read_tap: on the
-- 6502 read taps silently false-0 via the opcode-fetch bypass (mame-idioms-apple2e
-- §1). Direct reads are unaffected.
--
--   P_FRAME  frame to dump at (default 2900, mid-cutscene)
--   P_OUT    output prefix (default build/oracle_room)
local FRAME = tonumber(os.getenv("P_FRAME") or "2900")
local OUT = os.getenv("P_OUT") or "build/oracle_room"

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local done = false

local function dump(path, lo, hi)
    local t = {}
    for a = lo, hi do
        t[#t + 1] = string.char(mem:read_u8(a))
    end
    local f = io.open(path, "wb")
    if f then
        f:write(table.concat(t))
        f:close()
        return true
    end
    return false
end

local function tick()
    if done then return end
    local fn = scr:frame_number()
    if fn < FRAME then return end
    done = true
    local ok1 = dump(OUT .. "_page1.bin", 0x2000, 0x3FFF)
    local ok2 = dump(OUT .. "_page2.bin", 0x4000, 0x5FFF)
    local log = io.open(OUT .. "_dump.log", "w")
    if log then
        log:write(string.format("# dumped at frame %d\n", fn))
        log:write(string.format("# page1 $2000-$3FFF: %s\n", tostring(ok1)))
        log:write(string.format("# page2 $4000-$5FFF: %s\n", tostring(ok2)))
        log:close()
    end
    manager.machine:exit()
end

_G._notifier = emu.add_machine_frame_notifier(tick)
