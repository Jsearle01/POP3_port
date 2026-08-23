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
-- So this script drives LOADM"LOADER" + EXEC, and the interesting check is not
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
local WIPES     = tonumber(os.getenv("P_WIPES") or "0x200A")   -- completed sweeps
local WPLEFT    = tonumber(os.getenv("P_WPLEFT") or "0x23E0")  -- columns still to sweep
local NO_BORROW = (os.getenv("P_NOBORROW") == "1")

local ENGINE      = 0x2000        -- P3.5: clear of DECB's line buffer
local ADDR_STATUS = ENGINE + 3
local ADDR_BEAT   = ENGINE + 4
local ADDR_PHASE  = ENGINE + 5
local ADDR_MAGIC  = ENGINE + 6
local SEQ_MAGIC   = 0x5E92

local FB_BASE   = 0x8000        -- the MMU draw window
local FB_SIZE   = 30720         -- 160 B/row x 192 rows, 16-colour mode
local MMU       = 0xFFA4        -- GFX_DB_MMU
local BLOCKS    = 4             -- GFX_DB_BLOCKS
local BLOCK_A   = tonumber(os.getenv("P_BLK_A") or "0x10")
local BLOCK_B   = tonumber(os.getenv("P_BLK_B") or "0x14")

local BOOT_FRAME = 300
local SETTLE     = 1200
local TIMEOUT    = 20000

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

-- ACTUAL disk time. Every byte the WD1773 moves passes through its data register,
-- so a read tap there sees the transfer itself -- including DECB's boot LOADM, which
-- the engine's own counter cannot see because the engine is not running yet. This
-- measures the thing rather than inferring it from tracks x seconds-per-track.
-- (6809 read taps fire; the 6502 ones silently false-0. Idioms, mame-idioms.)
local FDC_DATA  = 0xFF4B
local DISK_GAP  = 12            -- frames of silence that end one operation
local cur_frame = 0             -- kept by tick: calling frame_number() per byte is
                                -- tens of thousands of calls and needlessly slow
local disk_runs, disk_cur = {}, nil
_G._fdc_tap = mem:install_read_tap(FDC_DATA, FDC_DATA, "fdc_time", function(off, data, mask)
    if disk_cur and (cur_frame - disk_cur.last) <= DISK_GAP then
        disk_cur.last = cur_frame
        disk_cur.n = disk_cur.n + 1
    else
        if disk_cur then disk_runs[#disk_runs + 1] = disk_cur end
        disk_cur = { first = cur_frame, last = cur_frame, n = 1 }
    end
    return data
end)

-- ...and the DRIVE-ENGAGED time, which is what the machine actually waits for. The
-- transfer is only part of it: the WD1773 paces the 6809 with HALT, so from
-- load_tracks starting to `clr DSKREG` releasing the drive, the CPU is stopped --
-- through seek, head settle and rotational latency as well as the bytes.
local DSKREG = 0xFF40
local motor_on, motor_frames, motor_spans = nil, 0, {}
_G._dsk_tap = mem:install_write_tap(DSKREG, DSKREG, "dskreg", function(off, data, mask)
    local on = (data ~= 0)
    if on and not motor_on then
        motor_on = cur_frame
    elseif not on and motor_on then
        motor_frames = motor_frames + (cur_frame - motor_on)
        motor_spans[#motor_spans + 1] = { first = motor_on, last = cur_frame }
        motor_on = nil
    end
    return data
end)

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
    log(string.format("# %-16s displayed buffer %s (cur_back=%d swaps=%d loads=%d) -> %s",
                      tag, (back == 0) and "B" or "A", back,
                      rd8(SWAPS) * 256 + rd8(SWAPS + 1), rd8(ENGINE + 8), path))
    if tag == "1a_wipe_mid" then
        log(string.format("#                  sweep had %d of %d columns left to go",
                          rd8(WPLEFT), 140))
    end
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
    if disk_cur then disk_runs[#disk_runs + 1] = disk_cur; disk_cur = nil end
    local tot_f, tot_b = 0, 0
    log("# --- actual disk time (WD1773 data-register tap) ---")
    for i, r in ipairs(disk_runs) do
        local d = r.last - r.first + 1
        tot_f = tot_f + d; tot_b = tot_b + r.n
        log(string.format("#   op %d  frames %5d..%-5d  %5.2f s  %6d bytes",
                          i, r.first, r.last, d / 60, r.n))
    end
    log(string.format("# TOTAL transfer %.2f s over %d bursts, %d bytes",
                      tot_f / 60, #disk_runs, tot_b))
    for i, s in ipairs(motor_spans) do
        log(string.format("#   drive engaged %d  frames %5d..%-5d  %5.2f s",
                          i, s.first, s.last, (s.last - s.first) / 60))
    end
    log(string.format("# TOTAL drive-engaged %.2f s over %d operations",
                      motor_frames / 60, #motor_spans))
    log(string.format("# checks=%d passed=%d failed=%d", #checks, #checks - failed, failed))
    local verdict = (failed == 0 and #checks > 0) and "PASS" or "FAIL"
    log("# VERDICT: " .. verdict)
    local p = io.open(verdict == "PASS" and PASS_PATH or FAIL_PATH, "w")
    if p then p:write(reason .. "\n"); p:close() end
    if log_file then log_file:close(); log_file = nil end
    manager.machine:exit()
end

-- The five states, in order. Each is (status, phase) -> capture tag.
-- probe_status now identifies the BEAT (2 = first, 3 = second, 4 = finished) and
-- probe_phase the point within it (0 base held, 1 caption up, 2 caption cleared).
-- how many swaps happen before the intro sequencer is entered at all. The stage-1
-- loader (src/boot/loader.s) draws the "loading" word and swaps once to show it.
local LOADER_SWAPS = 1

local WANT = {
    -- the beat is entered BEFORE its screen is read, so this one also waits
    -- for the reads to land; otherwise it captures an empty framebuffer.
    -- beat 0 FLIPS, it does not sweep: PubCredit calls setdhires after
    -- unpacksplash, so the oracle reveals that picture whole. Gate on the swap.
    -- (Third time this gate has moved. It tracks how the base ARRIVES, which is
    -- exactly what these dispatches keep changing -- so it is gated on the
    -- arrival mechanism each time, never on a count that stands in for it.)
    -- ★ P4.46: the stage-1 loader puts the "loading" word up with a swap of its own
    -- BEFORE the intro is entered, so the intro's first swap is now the second the HAL
    -- counts. Named rather than bumped to 2, because a bare number is what made this
    -- gate move three times: the fact is "one swap belongs to the loader".
    { st = 2, ph = 0, tag = "1_base", swaps = LOADER_SWAPS + 1 },  -- gate on the SWAP, not on a
    -- read count: the count was only ever a proxy for "the base is on screen",
    -- and the splash bank (P3.11) changed how many reads that takes. The swap
    -- is the thing the proxy stood for, so gate on it directly.
    { st = 2, ph = 1, tag = "2_presents_up" },
    { st = 2, ph = 2, tag = "3_presents_clear" },
    { st = 3, ph = 1, tag = "4_byline_up" },
    { st = 3, ph = 2, tag = "5_byline_clear" },
    { st = 4, ph = 1, tag = "6_title_up" },
    -- the prologue beats carry their OWN picture and have no caption, so phase 1
    -- means "the picture is up" rather than "a caption is up"
    -- MID-SWEEP: the only capture that can tell a wipe from a flip. Taken while
    -- beat 3's sweep is roughly half done, it must show the new picture on the left
    -- and the old one on the right with ONE boundary between them. A plain swap
    -- passes every other check in this file; it cannot pass this one.
    -- ★ P4.47: THE HELD TITLE, and the gate is st=5 rather than st=4 for a reason.
    -- A keep beat sets phase 2 and falls straight out of the beat, so `st=4, ph=2`
    -- lasts no observable time at all -- the same once-per-frame race the sequencer
    -- comment warns about. The state that DOES persist is the top of beat 3: status
    -- has advanced, phase 2 is carried over, and the title is still on the front
    -- buffer while the scene preload and prolog1's read run. That is precisely what
    -- Jay asked to see, so it is what gets captured.
    { st = 5, ph = 2, tag = "7_title_held" },
    { st = 5, ph = 2, tag = "1a_wipe_mid", wpleft = { 40, 100 } },
    { st = 5, ph = 1, tag = "8_prolog1" },
    { st = 6, ph = 1, tag = "9_prolog2" },
    -- the reprise: the splash re-established from disk, then the SAME title caption
    { st = 7, ph = 1, tag = "10_title_reprise" },
    -- P4.47: the reprise never comes down -- SilentTitle has no CleanScreen.
    { st = 8, ph = 2, tag = "11_title_held" },
}
local want_i = 1

local state, loaded_at, started = "boot", nil, nil
local intro_due, intro_ok = nil, false   -- P4.46: the stage-1 loader's hand-off
local loads_seen, last_load = 0, nil
local held = 0
local last_st, last_ph = -1, -1

local function tick()
    local fn = manager.machine.screens:at(1):frame_number()
    cur_frame = fn

    if state == "boot" then
        if fn >= BOOT_FRAME then
            nk:post('LOADM"LOADER"\n')
            log(string.format("# disk: posted LOADM\"INTROSEQ\" at frame %d", fn))
            state = "loadm"
        end
        return
    end

    if state == "loadm" then
        if nk.empty and not loaded_at then
            loaded_at = fn
        elseif loaded_at then
            -- ★★★ P4.46: THE LOADM TARGET IS THE STAGE-1 LOADER, NOT THE INTRO. The intro is
            -- no longer a DECB file -- the loader reads its program off a raw track and jumps
            -- to `intro_seq_boot`, past the `set_mode` whose buffer-clear would wipe the
            -- "loading" screen. So this stage cannot test $2000 for a JMP: nothing is there
            -- yet. LOADER.BIN's own segment table is the check here, and the intro is verified
            -- separately once EXEC has let the loader fetch it (`intro_arrived`, below).
            local all_in, bad = true, nil
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
                -- ★★ THE INTRO'S ARRIVAL IS ITS OWN CHECK, AND IT IS THE ONE THAT WOULD
                -- CATCH A BAD HAND-OFF. The loader draws its screen, reads the intro's
                -- program off track 33 and jumps to intro_seq_boot; if that read fails or
                -- the entry offset drifts, $2000 never becomes a JMP and everything after
                -- this is garbage. Without this the failure would present as beats that
                -- never happen, which reads as a rendering bug.
                intro_due = fn + 900
            elseif fn >= loaded_at + SETTLE then
                check("loadm_from_disk", false,
                      string.format("$%04X = %02X after %d frames; %s", ENGINE, rd8(ENGINE),
                                    SETTLE, bad or "segment table unreadable"))
                finish("LOADM failed")
            end
        end
        return
    end

    if state == "running" then
        -- P4.46: did the loader actually fetch the intro and hand over?
        if not intro_ok then
            if rd8(ENGINE) == 0x7E then
                intro_ok = true
                check("intro_arrived", true,
                      string.format("$%04X = 7E at frame %d -- the loader read it off"
                                    .. " its track and jumped to intro_seq_boot", ENGINE, fn))
            elseif intro_due and fn >= intro_due then
                check("intro_arrived", false,
                      string.format("$%04X = %02X, %d frames after EXEC -- the loader did"
                                    .. " not deliver the intro", ENGINE, rd8(ENGINE),
                                    fn - started))
                finish("the loader did not hand over")
                return
            end
        end
        local st, ph = rd8(ADDR_STATUS), rd8(ADDR_PHASE)
        -- time each disk read as it lands. The load cost is a number this task
        -- owes, not something to eyeball from when the picture turns up.
        local n = rd8(ENGINE + 8)
        if n > (loads_seen or 0) then
            log(string.format("# frame %5d  disk read %d complete (+%d frames, %.1f s)",
                              fn, n, fn - (last_load or started), (fn - (last_load or started)) / 60))
            loads_seen, last_load = n, fn
        end
        local w = WANT[want_i]
        if w and st == w.st and ph == w.ph
           and rd8(ENGINE + 8) >= (w.loads or 0)
           and (rd8(SWAPS) * 256 + rd8(SWAPS + 1)) >= (w.swaps or 0)
           and rd8(WIPES) >= (w.wipes or 0)
           and (not w.wpleft or (rd8(WPLEFT) >= w.wpleft[1]
                                 and rd8(WPLEFT) <= w.wpleft[2])) then
               -- a state can be true the instant a swap lands and still be
               -- mid-transition; w.after lets a capture settle first.
               held = (held or 0) + 1
               if held <= (w.after or 0) then return end
            mark(w.tag, fn)
            check("capture_" .. w.tag, dump_front(w.tag), "")
            want_i = want_i + 1
            held = 0
            if want_i > #WANT then
                local magic = rd8(ADDR_MAGIC) * 256 + rd8(ADDR_MAGIC + 1)
                check("seq_magic", magic == SEQ_MAGIC,
                      string.format("$%04X (want $%04X)", magic, SEQ_MAGIC))
                check("beats_completed", rd8(ADDR_BEAT) == 5,
                      string.format("last beat index %d (want 5 = six beats)", rd8(ADDR_BEAT)))
                -- THE PROOF: every read the sequence makes, and a program image far too
                -- small to have carried the screen.
                --
                -- ★★ SIX SINCE P3.107, NOT FOUR, AND THE TWO NEW ONES ARE THE INTEGRATION.
                -- The count is itemised rather than bumped: a number raised until the suite
                -- goes green is not a check, and this one is the only thing standing between
                -- "the scene was called" and "the scene was silently skipped".
                --
                --   1  the caption bundle, at startup                  tracks 25-26
                --   2  the splash, first time                           tracks 27-28
                --   3  prolog1                                          tracks 9-10
                --   4  ★ the SCENE'S PROGRAM, read to $2500 after beat 4   track 24
                --   5  ★ the captions AGAIN — the scene's bundle expanded over them at
                --      $3000, and beat 6 patches BUNDLE_TITLE            tracks 25-26
                --   6  prolog2                                          tracks 18-19
                --   7  ★★ the splash AGAIN, for beat 6's reprise         tracks 27-28
                --
                -- ★★★ SEVEN, AND THE SEVENTH WAS A 128 KB FACT. The splash used to be read
                -- ONCE and served from the bank thereafter. The bank was BANK_BLOCK $3C, four
                -- blocks $3C-$3F — and the GIME masks a block number to installed RAM, so on
                -- a stock 128 KB machine those ARE $0C-$0F, which is exactly the scene's cel
                -- bank ($0C pinned, $0D/$0E/$0F rotating). The scene overwrote the cached
                -- splash, so run_scene cleared bank_valid and beat 6 re-read it.
                --
                -- ★ At 512 KB the two did not collide and the sixth read would have been
                -- enough — which is why this suite runs at 128 KB first (CLAUDE.md §2K).
                -- ★★ EIGHT SINCE P4.21, and the eighth is the MUSIC PLAYER. It is read to
                -- $0A00 in the same opening burst as the captions, because the LOADM
                -- ceiling binds only on what must be resident at handover (CLAUDE.md §2L)
                -- and 4,456 bytes of player does not belong in that image. Raising this
                -- number is the one honest response to a read that was deliberately added;
                -- what it must NOT become is a number nobody can account for, so the list
                -- below names every one.
                --
                -- ★★★ SIXTEEN SINCE P4.25, AND THE EIGHT NEW ONES ARE THE CUTSCENE'S CEL
                -- PAGES — moved out of the scene and into the intro's opening batch, because
                -- reading them at scene start put the cutscene's first musical cue 12.4 s
                -- late (P4.23/P4.24) and Jay ruled that unacceptable. They are the pinned
                -- page (tracks 11-12) plus the startup pages, two tracks each:
                --
                --   9,10   the pinned page   CEL_RES_TRK 11, then 12, into block $0C
                --   11,12  startup page 0    tracks 13,14  -> block $0D
                --   13,14  startup page 1    tracks 15,16  -> block $0E
                --   15,16  startup page 2    tracks 20,21  -> block $0F
                --   17,18  startup page 3    tracks 22,23  -> block $18   [P5.15]
                --
                -- ★★ AND THE COUNT IS THE PROOF THAT THE MOVE COST NO EXTRA DISK. Removing
                -- the splash bank — whose blocks ARE those cel blocks at 128 KB — could have
                -- forced beat 1 to re-read its second base, a ninth 2.6 s read. It did not:
                -- fb_copy_front takes that base from the FRONT buffer instead. 8 + 8 = 16,
                -- exactly, and a 17th here would mean the bank's removal was not paid for.
                --
                -- ★★★ EIGHTEEN SINCE P5.15, AND THE TWO NEW ONES ARE NOT AN EXTRA COST —
                -- THEY ARE A MOVED ONE. Page 3 used to arrive DURING the cutscene, read into
                -- block $0D over page 0's remains at beat 12, because at 128 KB there was no
                -- fourth rotating block to put it in. That read is the 3.20 s freeze P5.13
                -- measured as the ONE disk operation visible in the whole intro. The 512 KB
                -- target P5.14 moved to has block $18 free, so page 3 gets a block of its
                -- own and is loaded here with the other three: the same two tracks, read
                -- against a black screen instead of against a running scene.
                --
                -- So the number to check is 18 and the schedule to check is CEL_N_READS = 0.
                -- A 17 here would mean the preload dropped a page; a 19 would mean the
                -- cutscene read one anyway, which is precisely the thing this removed.
                --
                -- ★★★ SIXTEEN SINCE P5.16, AND IT WENT DOWN BECAUSE OF WHAT IT STOPPED
                -- DOING TWICE. The RAM track cache reads each of the intro's asset tracks
                -- exactly once and copies at every later use, so two reads disappear
                -- outright rather than moving: the captions, which used to be read at boot
                -- AND again after the scene expanded its bundle over them, and the splash,
                -- which used to be read for beat 1 AND again for beat 6's reprise. The
                -- other two (prolog1, prolog2) moved from their beats into the batch.
                --
                --    4   tc_preload: prolog1 (9), prolog2 (18), captions (25), splash (27)
                --    1   the music player (32)
                --   10   the cutscene's cel pages, five units of two tracks   [P5.15]
                --    1   the scene's program (24), at beat 4 — see below
                --   --
                --   16
                --
                -- ★★ THE SCENE'S PROGRAM IS DELIBERATELY NOT CACHED, and this count is
                -- where that decision is visible. Caching it made the cutscene fail: the
                -- scene ran, room_load_cels failed, and cel_scene_done was never even
                -- cleared. Bisected — with that one row removed and every other row cached,
                -- integ passes and the flag sets at frame 9255. The root cause is not yet
                -- established, so the row stays out and this number stays 16. If it ever
                -- becomes 15, someone cached it again without fixing that.
                check("disk_reads_completed", rd8(ENGINE + 8) == 16,
                      string.format("probe_loads = %d (want 16: FOUR CACHE PRELOADS + THE "
                                    .. "MUSIC PLAYER + TEN CEL-PAGE TRACKS + the scene's "
                                    .. "program; the captions and the splash are no longer "
                                    .. "read twice; WD1773 status $%02X",
                                    rd8(ENGINE + 8), rd8(ENGINE + 9)))
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
                                rd8(ENGINE + 8), rd8(ENGINE + 9), rd8(0xFE00),
                                rd8(0x1F00), rd8(0x1F06),
                                rd8(0x1F02) * 256 + rd8(0x1F03)))
            finish("timeout")
        end
    end
end

_G._notifier = emu.add_machine_frame_notifier(tick)
