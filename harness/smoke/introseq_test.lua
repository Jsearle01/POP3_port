-- harness/smoke/introseq_test.lua
--
-- POP CoCo3 — P3.3 intro-sequencer verifier.
--
-- Boots coco3, starts the linked sequencer, and captures the DISPLAYED image at
-- each of the five states the two credits pass through, plus the frame number of
-- every transition so the beat timing can be checked against the oracle's.
--
-- ---------------------------------------------------------------------------
-- READING THE FRONT BUFFER WITHOUT DISTURBING THE PROGRAM
-- ---------------------------------------------------------------------------
-- The CPU can only see the BACK buffer: gfx_map_blocks maps whichever buffer is
-- being drawn into the $8000 window, and the displayed one is reachable only
-- through the GIME's VOFFSET, which is write-only. So at the moment that matters
-- -- the caption is up -- reading $8000 returns the CLEAN page, the opposite of
-- what is on screen.
--
-- This script therefore maps the FRONT buffer into the window for the duration
-- of one read and puts the back buffer straight back. That is safe here in a way
-- that a soft-switch poke would not be, and the distinction is the point:
--
--   * the MMU affects CPU ADDRESSING ONLY. The display is driven by VOFFSET and
--     does not care what the CPU has mapped, so nothing on screen changes.
--   * the program is parked in hold_frames -- a HAL_time_vbl_wait loop -- for
--     the next several hundred frames, touching nothing in $8000-$FFFF. The VBL
--     handler lives in the kernel at $79xx and does not either.
--   * the registers are write-only, so "restore what was there" is computed from
--     HAL_gfx_cur_back rather than read back. Both block numbers are the HAL's
--     own published constants.
--
-- The counter-example is fresh: P3.3's first oracle trace wrote the Apple RAMRD
-- soft switches every frame to checksum both banks and corrupted the run outright
-- -- state the GAME owns, changed underneath it. The MMU window is state the
-- DEBUGGER can borrow, provided it is given back.
--
-- ---------------------------------------------------------------------------
-- WHY THIS POKES THE IMAGE IN INSTEAD OF USING LOADM
-- ---------------------------------------------------------------------------
-- LOADM cannot load this program, and the reason is structural rather than a
-- size limit. DECB's own storage sits at DBUF0=$0600, DBUF1=$0700, the FAT RAM
-- at $0800 and the FCBs at $094A; it zeroes $0600-$0989 at init.
-- [karateka_coco3 docs/project/decb-loadm-boot-gates.md, from Disk Basic
--  Unravelled II]  A program loading at $0200 fills its FIRST granule across
-- $0200-$0AFF, which lands squarely on all four -- so DECB loses the granule
-- chain it is in the middle of following and raises ?FS ERROR before granule 2.
--
-- Measured here rather than assumed: single-granule files at $0200 load fine
-- (that is why PROBE/MODE/ANIM all work); multi-granule files at $0200 fail;
-- the SAME multi-granule file at $4000 loads perfectly. Size is incidental --
-- the collision is with DECB's workspace.
--
-- P3.2's splash was never LOADMed either (build/introrun.lua pokes it), so this
-- is not a regression; it is the disk-boot arc surfacing. Karateka already
-- solved it -- src/boot/bootloader.s runs from framebuffer space, masks
-- interrupts, takes its own stack and raw-reads whole tracks into low RAM,
-- entered by LOADM"BOOT":EXEC -- and porting that is its own task.
--
-- IDIOMS USED: §10 keep the notifier in _G._; §12 forward slashes, io.open not
-- print, -seconds_to_run is emulated seconds.

local BIN       = os.getenv("P_BIN")  or "build/intro_seq.bin"
local OUT       = os.getenv("P_OUT")  or "build/introseq_test.log"
local DUMP      = os.getenv("P_DUMP") or "build/introseq_dumps"
local PASS_PATH = os.getenv("P_PASS") or "build/introseq_test_PASS"
local FAIL_PATH = os.getenv("P_FAIL") or "build/introseq_test_FAIL"
local CUR_BACK  = tonumber(os.getenv("P_CURBACK") or "0x7B06")

local ADDR_STATUS = 0x0203
local ADDR_BEAT   = 0x0204
local ADDR_PHASE  = 0x0205
local ADDR_MAGIC  = 0x0206
local SEQ_MAGIC   = 0x5E92

local FB_BASE   = 0x8000        -- the MMU draw window
local FB_SIZE   = 30720         -- 160 B/row x 192 rows, 16-colour mode
local MMU       = 0xFFA4        -- GFX_DB_MMU
local BLOCKS    = 4             -- GFX_DB_BLOCKS
local BLOCK_A   = 0x10          -- GFX_DB_A_BLOCK, physical $20000
local BLOCK_B   = 0x18          -- GFX_DB_B_BLOCK, physical $30000

local BOOT_FRAME = 300
local TIMEOUT    = 7200

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]

-- Load the linked image the way P3.2 did: parse the DECB segment table and poke
-- each segment in, then set PC to the transfer address. Same bytes LOADM would
-- have placed, same entry -- only the courier differs.
local function decb_image(path)
    local f = io.open(path, "rb"); if not f then return nil end
    local d = f:read("*a"); f:close()
    local segs, i, exec = {}, 1, nil
    while i <= #d do
        local t = string.byte(d, i)
        if t == 0 then
            local n = string.byte(d, i+1) * 256 + string.byte(d, i+2)
            local a = string.byte(d, i+3) * 256 + string.byte(d, i+4)
            segs[#segs+1] = { addr = a, len = n, data = d:sub(i + 5, i + 4 + n) }
            i = i + 5 + n
        elseif t == 0xFF then
            exec = string.byte(d, i+3) * 256 + string.byte(d, i+4); break
        else return nil end
    end
    return segs, exec
end
local SEGS, EXEC = decb_image(BIN)

local log_file = io.open(OUT, "w")
local function log(s) if log_file then log_file:write(s .. "\n"); log_file:flush() end end
log("# introseq_test.lua -- POP P3.3 intro-sequencer verifier")
log("#")

local function rd8(a) return mem:read_u8(a) end

local checks = {}
local function check(name, ok, detail)
    checks[#checks+1] = { name = name, ok = ok }
    log(string.format("%-28s %-4s %s", name, ok and "PASS" or "FAIL", detail or ""))
end

local function map_blocks(first)
    for i = 0, BLOCKS - 1 do mem:write_u8(MMU + i, first + i) end
end

-- Dump what is ON SCREEN. See the header for why borrowing the window is sound.
local function dump_front(tag)
    local back = rd8(CUR_BACK)
    local back_blk  = (back == 0) and BLOCK_A or BLOCK_B
    local front_blk = (back == 0) and BLOCK_B or BLOCK_A
    map_blocks(front_blk)
    local t = {}
    for i = 0, FB_SIZE - 1 do t[#t+1] = string.char(rd8(FB_BASE + i)) end
    map_blocks(back_blk)                       -- give it back, immediately
    local path = string.format("%s/%s.bin", DUMP, tag)
    local f = io.open(path, "wb")
    if not f then log("# could not open " .. path); return false end
    f:write(table.concat(t)); f:close()
    log(string.format("# %-16s displayed buffer %s -> %s",
                      tag, (back == 0) and "B" or "A", path))
    return true
end

local marks = {}
local function mark(tag, fn)
    marks[#marks+1] = { tag = tag, fn = fn }
    log(string.format("# frame %5d  %s", fn, tag))
end

local function finish(reason)
    log("#")
    log("# --- transitions ---")
    local prev
    for _, m in ipairs(marks) do
        log(string.format("#   %-16s frame %5d%s", m.tag, m.fn,
            prev and string.format("   (+%d)", m.fn - prev) or ""))
        prev = m.fn
    end
    log("# " .. reason)
    local failed = 0
    for _, c in ipairs(checks) do if not c.ok then failed = failed + 1 end end
    log(string.format("# checks=%d passed=%d failed=%d", #checks, #checks - failed, failed))
    local verdict = (failed == 0 and #checks > 0) and "PASS" or "FAIL"
    log("# VERDICT: " .. verdict)
    local p = io.open(verdict == "PASS" and PASS_PATH or FAIL_PATH, "w")
    if p then p:write(reason .. "\n"); p:close() end
    if log_file then log_file:close(); log_file = nil end
    manager.machine:exit()
end

-- The five states, in order. Each is (status, phase) -> capture tag.
local WANT = {
    { st = 1, ph = 0, tag = "1_base" },
    { st = 2, ph = 1, tag = "2_presents_up" },
    { st = 2, ph = 2, tag = "3_presents_clear" },
    { st = 3, ph = 1, tag = "4_byline_up" },
    { st = 4, ph = 2, tag = "5_done" },
}
local want_i = 1

local state, started = "boot", nil

local function tick()
    local fn = manager.machine.screens:at(1):frame_number()

    if state == "boot" then
        -- Let DECB finish coming up first. The program takes the machine over
        -- completely (its own stack, its own $FF90), but starting it mid-boot
        -- would race DECB's own initialisation.
        if fn >= BOOT_FRAME then
            if not SEGS then
                check("image_readable", false, "could not parse " .. BIN)
                finish("bad image")
                return
            end
            for _, sg in ipairs(SEGS) do
                for j = 0, sg.len - 1 do
                    mem:write_u8(sg.addr + j, string.byte(sg.data, j + 1))
                end
                log(string.format("# poked %6d bytes -> $%04X..$%04X",
                                  sg.len, sg.addr, sg.addr + sg.len - 1))
            end
            -- read it back before trusting it; a short poke would look like a
            -- rendering bug several hundred frames later
            local bad = nil
            for _, sg in ipairs(SEGS) do
                if rd8(sg.addr) ~= string.byte(sg.data, 1)
                   or rd8(sg.addr + sg.len - 1) ~= string.byte(sg.data, sg.len) then
                    bad = string.format("$%04X..$%04X", sg.addr, sg.addr + sg.len - 1)
                end
            end
            check("image_in_memory", bad == nil,
                  bad and ("segment " .. bad .. " did not stick")
                       or string.format("%d segments verified at both ends", #SEGS))
            if bad then finish("poke failed"); return end
            cpu.state["PC"].value = EXEC
            log(string.format("# PC <- $%04X", EXEC))
            state = "running"
            started = fn
        end
        return
    end

    if state == "running" then
        local st, ph = rd8(ADDR_STATUS), rd8(ADDR_PHASE)
        local w = WANT[want_i]
        if w and st == w.st and ph == w.ph then
            mark(w.tag, fn)
            check("capture_" .. w.tag, dump_front(w.tag), "")
            want_i = want_i + 1
            if want_i > #WANT then
                local magic = rd8(ADDR_MAGIC) * 256 + rd8(ADDR_MAGIC + 1)
                check("seq_magic", magic == SEQ_MAGIC,
                      string.format("$%04X (want $%04X)", magic, SEQ_MAGIC))
                check("beats_completed", rd8(ADDR_BEAT) == 1,
                      string.format("last beat index %d", rd8(ADDR_BEAT)))
                finish("both credits ran")
            end
        end
        if fn > (started or 0) + TIMEOUT then
            check("sequence_completed", false,
                  string.format("stalled at status %d phase %d, %d of %d states seen",
                                st, ph, want_i - 1, #WANT))
            finish("timeout")
        end
    end
end

_G._notifier = emu.add_machine_frame_notifier(tick)
