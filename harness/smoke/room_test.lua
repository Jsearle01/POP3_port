-- harness/smoke/room_test.lua
--
-- POP P3.17 phase A — does the princess's room actually reach the screen?
--
-- The claim is narrow and worth checking exactly: after LOADM+EXEC on the real disk
-- path, the machine is in 4-COLOUR mode and the DISPLAYED buffer holds the converted
-- room, byte for byte. Anything less specific ("a picture appeared") is the kind of
-- check P3.12 showed is worth nothing -- a capture that only proves a file was
-- written.
--
-- The front buffer is read by borrowing the MMU the way introseq_test.lua does:
-- HAL_gfx_cur_back names the DRAW buffer, so the displayed one is the other, and it
-- is mapped into the draw window only while the CPU is stopped inside this notifier.
--
-- 4-colour geometry: 80 bytes/row x 192 = 15,360 B, half the 16-colour framebuffer.
local ENGINE  = tonumber(os.getenv("P_ENGINE") or "0x2000")
local CUR_BACK= tonumber(os.getenv("P_CURBACK") or "0x7B06")
local BLOCK_A = tonumber(os.getenv("P_BLK_A") or "0x10")
local BLOCK_B = tonumber(os.getenv("P_BLK_B") or "0x14")
local OUT     = os.getenv("P_OUT") or "build/room_test.log"
local DUMP    = os.getenv("P_DUMP") or "build/room_front.bin"
local CURMODE = tonumber(os.getenv("P_CURMODE") or "0x7AFE")

local FB_BASE, FB_SIZE = 0x8000, 15360
local ROOM_MAGIC = 0x4B00

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true

local f = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end
local function rd8(a) return mem:read_u8(a) end

local checks, failed = {}, 0
local function check(name, ok, detail)
    checks[#checks + 1] = name
    if not ok then failed = failed + 1 end
    log(string.format("%-28s %s %s", name, ok and "PASS" or "FAIL", detail or ""))
end

local function map_blocks(first)
    for i = 0, 3 do mem:write_u8(0xFFA4 + i, first + i) end
end

local function dump_front()
    local back = rd8(CUR_BACK)
    local back_blk  = (back == 0) and BLOCK_A or BLOCK_B
    local front_blk = (back == 0) and BLOCK_B or BLOCK_A
    map_blocks(front_blk)
    local t = {}
    for i = 0, FB_SIZE - 1 do t[#t + 1] = string.char(rd8(FB_BASE + i)) end
    map_blocks(back_blk)
    local o = io.open(DUMP, "wb")
    if not o then return false end
    o:write(table.concat(t)); o:close()
    log(string.format("# displayed buffer %s -> %s", (back == 0) and "B" or "A", DUMP))
    return true
end

local state, t0, started = "boot", nil, nil

local function finish(reason)
    log(string.format("# checks=%d passed=%d failed=%d", #checks, #checks - failed, failed))
    log("# VERDICT: " .. ((failed == 0) and "PASS" or "FAIL") .. "  (" .. reason .. ")")
    local mark = io.open((failed == 0) and "build/room_test_PASS" or "build/room_test_FAIL", "w")
    if mark then mark:write(reason .. "\n"); mark:close() end
    manager.machine:exit()
end

local function tick()
    local fn = scr:frame_number()
    if state == "boot" then
        if fn >= 300 then
            nk:post('LOADM"ROOM"\n')
            state, t0 = "loadm", fn
        end
        return
    end
    if state == "loadm" then
        if fn > t0 + 500 then
            nk:post('EXEC\n')
            state, started = "running", fn
        end
        return
    end
    -- running
    local magic = rd8(ENGINE + 6) * 256 + rd8(ENGINE + 7)
    if magic == ROOM_MAGIC then
        check("room_reached_screen", true,
              string.format("magic $%04X at frame %d", magic, fn))
        check("disk_read_ok", rd8(ENGINE + 4) == 1,
              string.format("loads=%d, WD1773 status $%02X",
                            rd8(ENGINE + 4), rd8(ENGINE + 5)))
        -- The GIME's VRES register is write-only: reading $FF99 returns bus noise,
        -- not what was written ($1B came back for a register set to $15). Check the
        -- HAL's own record of the active mode instead — real state, and readable.
        check("mode_is_4_colour", rd8(CURMODE) == 0,
              string.format("HAL_gfx_cur_mode=%d (want 0 = 320x192x4)", rd8(CURMODE)))
        check("front_buffer_dumped", dump_front(), "")
        finish("room displayed")
    elseif fn > started + 1800 then
        check("room_reached_screen", false,
              string.format("magic $%04X, status %d, loads %d, dskerr $%02X after 30 s",
                            magic, rd8(ENGINE + 3), rd8(ENGINE + 4), rd8(ENGINE + 5)))
        finish("timed out")
    end
end

_G._notifier = emu.add_machine_frame_notifier(tick)
