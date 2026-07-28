-- harness/tools/oracle_ram_dump.lua
--
-- POP P3.17 — dump the oracle's hires pages from a KNOWN bank.
--
-- WHY THE OBVIOUS VERSION IS WRONG. The hires pages are at $2000/$4000 in MAIN
-- memory (HIRES.S:157), and reading them with mem:read_u8 looks right and is not:
-- the CPU program space honours the RAMRD soft switch, and POP sets RAMRDaux
-- constantly (unpacking, LoadStage2, the aux language card). A read at $2000 returns
-- whichever bank is switched in at that instant — for this game usually AUX, which is
-- where LoadStage2 puts bgtab1-2 and chtab4.
--
-- The symptom was diagnostic once measured: the region never changed across ~2,000
-- frames, and 444 of its 512 hires "screen hole" bytes were non-zero. Screen holes are
-- unused by the display and near-empty on a real page. That was data, decoded as a
-- picture.
--
-- MAME's apple2e exposes no named RAM shares to Lua, so the bank is selected the way
-- the hardware does it: touch the soft switch, then read.
--     $C002 RAMRDOFF -> reads see MAIN
--     $C003 RAMRDON  -> reads see AUX
--
-- WRITING SOFT SWITCHES UNDER A RUNNING GAME IS NORMALLY FORBIDDEN HERE — P3.3 lost a
-- trace doing it every frame. This is the one safe shape: a single flip, at the end,
-- immediately before machine:exit(). The game state is wrecked and it does not matter,
-- because nothing runs afterwards. Dumping mid-run and continuing would be the P3.3
-- error again.
--
-- Dumps all four combinations (main/aux x page1/page2) so the caller can decide
-- offline which is a real screen by measurement rather than by assumption.
--
--   P_FRAME  frame to dump at
--   P_OUT    output prefix
local FRAME = tonumber(os.getenv("P_FRAME") or "4750")
local OUT = os.getenv("P_OUT") or "build/oracle_ram"

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local done = false

local RAMRDOFF, RAMRDON = 0xC002, 0xC003

local function grab(path, lo)
    local t = {}
    for a = lo, lo + 0x1FFF do
        t[#t + 1] = string.char(mem:read_u8(a))
    end
    local f = io.open(path, "wb")
    if not f then return false end
    f:write(table.concat(t))
    f:close()
    return true
end

local function tick()
    if done then return end
    if scr:frame_number() < FRAME then return end
    done = true
    local fn = scr:frame_number()

    mem:write_u8(RAMRDOFF, 0)                  -- reads see MAIN
    grab(OUT .. "_main_page1.bin", 0x2000)
    grab(OUT .. "_main_page2.bin", 0x4000)

    mem:write_u8(RAMRDON, 0)                   -- reads see AUX
    grab(OUT .. "_aux_page1.bin", 0x2000)
    grab(OUT .. "_aux_page2.bin", 0x4000)

    local f = io.open(OUT .. "_dump.log", "w")
    if f then
        f:write(string.format("# frame %d — main/aux x page1/page2 dumped\n", fn))
        f:close()
    end
    manager.machine:exit()
end

_G._notifier = emu.add_machine_frame_notifier(tick)
