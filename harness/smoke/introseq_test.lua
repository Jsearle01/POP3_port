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
-- THIS LOADS FROM DISK. THE REAL PATH, FOR THE FIRST TIME.
-- ---------------------------------------------------------------------------
-- P3.2 and P3.3 both poked the image into memory and set PC, because LOADM could
-- not carry them: a program at $0200 fills its first granule across $0200-$0AFF,
-- straight through DECB's DBUF0 ($0600), DBUF1 ($0700), FAT RAM ($0800) and FCBs
-- ($094A), and dies with ?FS ERROR before granule 2.
-- [karateka_coco3 docs/project/decb-loadm-boot-gates.md; measured in P3.3]
--
-- P3.4 removed the reason rather than the symptom. The screen is no longer in the
-- program image at all -- it sits on raw tracks 27..33 and the program reads it
-- into the back buffer itself. What is left to LOADM is 1,369 bytes: one granule,
-- ending below $0600, which DECB carries without complaint.
--
-- So this script drives LOADM"INTROSEQ" + EXEC, and the interesting check is not
-- that a picture appears but that it appears AT ALL: the loaded file provably
-- does not contain it.
--
-- IDIOMS USED: §1 no autoboot -> DECB is the entry point; §2 natkeyboard:post
-- after boot settles; §10 keep the notifier in _G._; §12 forward slashes, io.open
-- not print, -seconds_to_run is emulated seconds.

local BIN       = os.getenv("P_BIN")  or "build/intro_seq.bin"
local OUT       = os.getenv("P_OUT")  or "build/introseq_test.log"
local DUMP      = os.getenv("P_DUMP") or "build/introseq_dumps"
local PASS_PATH = os.getenv("P_PASS") or "build/introseq_test_PASS"
local FAIL_PATH = os.getenv("P_FAIL") or "build/introseq_test_FAIL"
local CUR_BACK  = tonumber(os.getenv("P_CURBACK") or "0x7B06")
local SWAPS     = tonumber(os.getenv("P_SWAPS") or "0x7B07")
local NO_BORROW = (os.getenv("P_NOBORROW") == "1")

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
local SETTLE     = 1200
local TIMEOUT    = 7200

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local nk  = manager.machine.natkeyboard
nk.in_use = true

-- Parse the DECB segment table without writing (P2.4): a linked binary has two
-- segments and $0200 lands FIRST, so gating on $0200 alone posts EXEC into a
-- still-running LOADM.
local function decb_segments(path)
    local f = io.open(path, "rb"); if not f then return nil end
    local d = f:read("*a"); f:close()
    local segs, i = {}, 1
    while i <= #d do
        local t = string.byte(d, i)
        if t == 0 then
            local n = string.byte(d, i+1) * 256 + string.byte(d, i+2)
            local a = string.byte(d, i+3) * 256 + string.byte(d, i+4)
            segs[#segs+1] = { addr = a, len = n,
                              first = string.byte(d, i + 5),
                              last  = string.byte(d, i + 5 + n - 1) }
            i = i + 5 + n
        elseif t == 0xFF then break
        else return nil end
    end
    return segs, #d
end
local SEGS, BIN_BYTES = decb_segments(BIN)

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
    if not NO_BORROW then map_blocks(front_blk) end
    local t = {}
    for i = 0, FB_SIZE - 1 do t[#t+1] = string.char(rd8(FB_BASE + i)) end
    if not NO_BORROW then map_blocks(back_blk) end
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

local state, loaded_at, started = "boot", nil, nil
local loads_seen, last_load = 0, nil
local last_st, last_ph = -1, -1

local function tick()
    local fn = manager.machine.screens:at(1):frame_number()

    if state == "boot" then
        if fn >= BOOT_FRAME then
            nk:post('LOADM"INTROSEQ"\n')
            log(string.format("# disk: posted LOADM\"INTROSEQ\" at frame %d", fn))
            state = "loadm"
        end
        return
    end

    if state == "loadm" then
        if nk.empty and not loaded_at then
            loaded_at = fn
        elseif loaded_at then
            local all_in, bad = (rd8(0x0200) == 0x7E), nil
            if all_in and SEGS then
                for _, sg in ipairs(SEGS) do
                    local g0, g1 = rd8(sg.addr), rd8(sg.addr + sg.len - 1)
                    if g0 ~= sg.first or g1 ~= sg.last then
                        bad = string.format("$%04X..$%04X (%d B): got %02X..%02X want %02X..%02X",
                                            sg.addr, sg.addr + sg.len - 1, sg.len, g0, g1,
                                            sg.first, sg.last)
                        all_in = false; break
                    end
                end
            end
            if all_in then
                check("loadm_from_disk", true,
                      string.format("%d B, %d segments, at frame %d — the real path",
                                    BIN_BYTES, #SEGS, fn))
                nk:post('EXEC\n')
                state = "running"
                started = fn
            elseif fn >= loaded_at + SETTLE then
                check("loadm_from_disk", false,
                      string.format("$0200 = %02X after %d frames; %s", rd8(0x0200),
                                    SETTLE, bad or "segment table unreadable"))
                finish("LOADM failed")
            end
        end
        return
    end

    if state == "running" then
        local st, ph = rd8(ADDR_STATUS), rd8(ADDR_PHASE)
        -- time each disk read as it lands. The load cost is a number this task
        -- owes, not something to eyeball from when the picture turns up.
        local n = rd8(0x0208)
        if n > (loads_seen or 0) then
            log(string.format("# frame %5d  disk read %d complete (+%d frames, %.1f s)",
                              fn, n, fn - (last_load or started), (fn - (last_load or started)) / 60))
            loads_seen, last_load = n, fn
        end
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
                -- THE PROOF: three successful reads (bundle + the screen, twice),
                -- and a program image far too small to have carried the screen.
                check("disk_reads_completed", rd8(0x0208) == 3,
                      string.format("probe_loads = %d (want 3: bundle + screen x2); "
                                    .. "WD1773 status $%02X", rd8(0x0208), rd8(0x0209)))
                check("image_cannot_contain_screen", BIN_BYTES < 30720,
                      string.format("INTROSEQ.BIN is %d B; the framebuffer it put on "
                                    .. "screen is 30,720 B", BIN_BYTES))
                finish("both credits ran")
            end
        end
        -- a heartbeat while running: is the program advancing at all, and are
        -- VBLs still arriving? "stalled" without those two is not a diagnosis.
        if st ~= (last_st or -1) or ph ~= (last_ph or -1) then
            last_st, last_ph = st, ph

            log(string.format("# frame %5d  status=%d phase=%d swaps=%d",
                              fn, st, ph, rd8(SWAPS) * 256 + rd8(SWAPS + 1)))
        end
        if fn > (started or 0) + TIMEOUT then
            check("sequence_completed", false,
                  string.format("stalled at status %d phase %d, %d of %d states seen; "
                                .. "disk reads done=%d WD1773 status=$%02X nmi_done=%d "
                                .. "dr_track=%d dr_r_count=%d dr_dest=$%04X",
                                st, ph, want_i - 1, #WANT,
                                rd8(0x0208), rd8(0x0209), rd8(0xFE00),
                                rd8(0x1F00), rd8(0x1F06),
                                rd8(0x1F02) * 256 + rd8(0x1F03)))
            finish("timeout")
        end
    end
end

_G._notifier = emu.add_machine_frame_notifier(tick)
