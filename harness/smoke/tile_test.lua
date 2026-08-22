-- harness/smoke/tile_test.lua
--
-- POP P5.5 — the first GAMEPLAY pixels: LEVEL0 screen 1's static background, off the
-- real disk path, on the real GIME.
--
-- The claim is narrow and is checked exactly: after LOADM"TILE" + EXEC the machine is
-- in 4-colour mode, the packed page arrived off track TILE_TRK, expanded, and the
-- DISPLAYED buffer holds bake_screen.py's reference framebuffer BYTE FOR BYTE. The
-- byte-for-byte half is the point -- "a dungeon appeared" is the check P3.12 showed is
-- worth nothing.
--
-- The front buffer is read by borrowing the MMU exactly as room_test.lua does:
-- HAL_gfx_cur_back names the DRAW buffer, so the displayed one is the other, and it is
-- mapped into the draw window only while the CPU is stopped inside this notifier.
--
-- ★ TWO REGISTERS, NOT FOUR (P3.71, and room_test.lua carries the same note). The
-- 15,360 B read at $8000..$BBFF only ever needs $FFA4/$FFA5; writing all four would
-- un-map whatever sits at $FFA6, which here is the tile page itself.
--
-- 4-colour geometry: 80 bytes/row x 192 rows = 15,360 B.

local ENGINE   = tonumber(os.getenv("P_ENGINE") or "0x2000")
local CUR_BACK = tonumber(os.getenv("P_CURBACK") or "0x7B06")
local BLOCK_A  = tonumber(os.getenv("P_BLK_A") or "0x10")
local BLOCK_B  = tonumber(os.getenv("P_BLK_B") or "0x14")
local CURMODE  = tonumber(os.getenv("P_CURMODE") or "0x7AFE")
local OUT      = os.getenv("P_OUT") or "build/tile_test.log"
local DUMP     = os.getenv("P_DUMP") or "build/tile_front.bin"
local PAL      = os.getenv("P_PAL") or "build/tile_palette.bin"
local WANT_ENTS = tonumber(os.getenv("P_WANT_ENTS") or "0")

local FB_BASE, FB_SIZE = 0x8000, 15360
local PAGE_MAGIC = 0x7B1E           -- bake_screen.py's; NOT the cutscene's $C35A
-- GFX_MODE_320x192x4 is ZERO and 320x192x16 is one [src/hal.inc:327]. Worth stating
-- rather than guessing: the first version of this file wrote 1 and failed a run whose
-- framebuffer was byte-exact -- a check disagreeing with a picture that is provably right
-- is the check being wrong.
local MODE_4COL  = 0

-- The probe block, in the order tile_probe.s declares it. These offsets are the ONE
-- place this file may state them, and src/engine/tile_probe.s is the other; the link
-- map is the arbiter (probe_status = tile_entry+3).
local P_STATUS, P_DSKERR, P_MAGIC, P_ENTS = 3, 4, 5, 7

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true

local f = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end
local function rd8(a) return mem:read_u8(a) end
local function rd16(a) return rd8(a) * 256 + rd8(a + 1) end

local checks, failed = {}, 0
local function check(name, ok, detail)
    checks[#checks + 1] = name
    if not ok then failed = failed + 1 end
    log(string.format("%-28s %s %s", name, ok and "PASS" or "FAIL", detail or ""))
end

local function map_blocks(first)
    for i = 0, 1 do mem:write_u8(0xFFA4 + i, first + i) end
end

local function dump_front(path)
    local back = rd8(CUR_BACK)
    local back_blk  = (back == 0) and BLOCK_A or BLOCK_B
    local front_blk = (back == 0) and BLOCK_B or BLOCK_A
    map_blocks(front_blk)
    local t = {}
    for i = 0, FB_SIZE - 1 do t[#t + 1] = string.char(rd8(FB_BASE + i)) end
    map_blocks(back_blk)
    local o = io.open(path, "wb")
    if not o then return false end
    o:write(table.concat(t)); o:close()
    log(string.format("# displayed buffer %s -> %s", (back == 0) and "B" or "A", path))
    return true
end

local state, t0, started, loaded = "boot", nil, nil, nil

local function finish(reason)
    log(string.format("# checks=%d passed=%d failed=%d", #checks, #checks - failed, failed))
    log("# VERDICT: " .. ((failed == 0) and "PASS" or "FAIL") .. "  (" .. reason .. ")")
    local mark = io.open((failed == 0) and "build/tile_test_PASS" or "build/tile_test_FAIL", "w")
    if mark then mark:write(reason .. "\n"); mark:close() end
    manager.machine:exit()
end

local function tick()
    local fn = scr:frame_number()
    if state == "boot" then
        if fn >= 300 then
            nk:post('LOADM"TILE"\n')
            state, t0 = "loadm", fn
        end
        return
    end
    if state == "loadm" then
        -- OBSERVE THE LOAD, THEN SETTLE — room_test.lua's note applies verbatim, and
        -- the reason it is not a bare delay is that TILE.BIN's size is not fixed: it
        -- grows with the renderer. $2000 holding $7E is DECB's first byte landing, not
        -- the load finishing, so the settle stays generous. Under -nothrottle waiting
        -- costs nothing.
        if loaded == nil and rd8(0x2000) == 0x7E then
            loaded = fn
            log("# LOADM first byte landed at frame " .. fn)
        end
        if fn > t0 + 900 then
            log(string.format("# at EXEC: $2000=%02X %02X %02X, $7900=%02X",
                              rd8(0x2000), rd8(0x2001), rd8(0x2002), rd8(0x7900)))
            nk:post('EXEC\n')
            log("# posted EXEC at frame " .. fn)
            state, started = "running", fn
        end
        return
    end

    local st = rd8(ENGINE + P_STATUS)

    -- THE PROGRAM ENDS IN A HALT LOOP, so there is no completion event to wait for
    -- other than the status byte reaching its terminal value. It is checked every
    -- frame and the run gives up after 600 frames, which separates "it never ran"
    -- (status 0) from "it stopped part way" (status 1/2/3) -- two different bugs that
    -- both present as a black screen.
    if st == 4 or fn > started + 600 then
        log(string.format("# terminal: status=%d dskerr=%02X magic=%04X ents=%d at frame %d",
                          st, rd8(ENGINE + P_DSKERR), rd16(ENGINE + P_MAGIC),
                          rd8(ENGINE + P_ENTS), fn))
        check("status reached 4 (shown)", st == 4, string.format("status=%d", st))
        check("disk read clean", rd8(ENGINE + P_DSKERR) == 0,
              string.format("dskerr=%02X", rd8(ENGINE + P_DSKERR)))
        check("page magic verified", rd16(ENGINE + P_MAGIC) == PAGE_MAGIC,
              string.format("magic=%04X want %04X", rd16(ENGINE + P_MAGIC), PAGE_MAGIC))
        if WANT_ENTS > 0 then
            check("whole display list drawn", rd8(ENGINE + P_ENTS) == WANT_ENTS,
                  string.format("ents=%d want %d", rd8(ENGINE + P_ENTS), WANT_ENTS))
        end
        check("mode is 320x192x4", rd8(CURMODE) == MODE_4COL,
              string.format("cur_mode=%d", rd8(CURMODE)))
        check("framebuffer captured", dump_front(DUMP), DUMP)
        -- THE PALETTE, OUT OF THE MACHINE. render_fb.py decodes framebuffer BYTES, and a
        -- byte is only a colour once a palette says so; without this the PNG shows the
        -- tool's default palette rather than the port's ($00/$26/$1B/$3F, gfx.s descriptor
        -- 0). It is read from $FFB0-$FFB3 rather than copied out of gfx.s, so the image
        -- cannot disagree with the machine that produced it -- and if the GIME does not
        -- read back, the logged values say so instead of a confident wrong picture.
        do
            local t = {}
            for i = 0, 15 do t[#t + 1] = string.char(rd8(0xFFB0 + i)) end
            local o = io.open(PAL, "wb")
            if o then o:write(table.concat(t)); o:close() end
            log(string.format("# palette $FFB0..$FFB3 = %02X %02X %02X %02X -> %s",
                              rd8(0xFFB0), rd8(0xFFB1), rd8(0xFFB2), rd8(0xFFB3), PAL))
        end
        -- NO scr:snapshot HERE. Idiom 11b: a MAME screen snapshot is not square-pixel
        -- and is not the way this project makes a coco3 PNG -- the runner decodes the
        -- 15,360 B dump above with render_square.py instead, at native 1:1.
        finish(st == 4 and "terminal status" or "timeout")
    end
end

-- ★ THE RETURNED SUBSCRIPTION MUST BE HELD or Lua's GC unsubscribes the notifier and
-- the callback silently stops firing, which reads as "the program never ran"
-- [mame-idioms-coco3-port.md]. `_G._notifier` is the same home every other test uses.
_G._notifier = emu.add_machine_frame_notifier(tick)
log("# tile_test: entry $" .. string.format("%04X", ENGINE) ..
    "  cur_back $" .. string.format("%04X", CUR_BACK) ..
    "  blocks $" .. string.format("%02X", BLOCK_A) .. "/$" .. string.format("%02X", BLOCK_B))
