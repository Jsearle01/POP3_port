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
local DUMP2   = os.getenv("P_DUMP2") or "build/room_front2.bin"
local CURMODE = tonumber(os.getenv("P_CURMODE") or "0x7AFE")

local FB_BASE, FB_SIZE = 0x8000, 15360
local ROOM_MAGIC = 0x4B00
-- HAL_gfx_swaps, the HAL's own count of flips performed (gfx.s). The runner derives
-- this from the link map like every other HAL address here, and the default below is
-- only a standalone convenience: adding HAL_gfx_mirror moved all three HAL data
-- symbols by $89 at once, and a hardcoded address would have quietly measured the
-- wrong byte rather than failing.
local SWAPS = tonumber(os.getenv("P_SWAPS") or "0x7B91")
local gap_visible, gap_moving = nil, nil

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true

local f = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end
local function rd8(a) return mem:read_u8(a) end

-- The characters can MOVE, so a pixel check cannot assume where they are. Their x/y
-- are read out of the slot records at each capture and handed to the verifier, which
-- composites at the position the machine actually used. Without this, a correct move
-- reads as 231 wrong bytes.
local VIZ = tonumber(os.getenv("P_VIZ") or "0")
local PRI = tonumber(os.getenv("P_PRI") or "0")
local DRAWN = tonumber(os.getenv("P_DRAWN") or "0")
local LAST  = tonumber(os.getenv("P_LAST") or "0")
local LAST_STRIDE = tonumber(os.getenv("P_LAST_STRIDE") or "8")
local function log_positions(tag)
    if VIZ == 0 then return end
    local f2 = io.open("build/room_chars_pos.txt", "a")
    if not f2 then return end
    -- x, y AND the cel THAT WAS DRAWN INTO THE BUFFER BEING CAPTURED.
    --
    -- The cel is NOT read from the slot record: that holds the cel for the frame
    -- currently being decided, while the buffer we capture was drawn a frame earlier
    -- and may still hold the previous one. Reading the record made a correct draw
    -- look like 32 wrong bytes (P3.27). ch_drawn is written at DRAW time, indexed by
    -- (character, slot), so this reads what actually reached these pixels.
    --
    -- The displayed buffer is the one that is NOT the current draw target.
    -- ...and when the probe captures the BACK buffer, the cel to read is that
    -- buffer's, not the displayed one's. A checker that reads the wrong slot's cel
    -- reports a false failure, which is the same class of mistake four times over.
    local shown = DUMP_BACK and (rd8(CUR_BACK) % 2) or (1 - (rd8(CUR_BACK) % 2))
    -- POSITION COMES FROM ch_last, NOT FROM THE SLOT RECORD, for the same reason the
    -- cel does. The record holds the x/y the VM has decided for the frame being built;
    -- the buffer being captured was drawn earlier and still holds the PREVIOUS position
    -- until that buffer is redrawn. P3.27 fixed this for the cel and did not extend it
    -- to x/y, which is what made a correct draw read as 139 wrong bytes shifted exactly
    -- one byte column (got[c] == want[c+1] on every affected row).
    --
    -- ch_last is (x,y,w,h) per (character, slot), written when that slot last saved --
    -- and a position change always takes the peel path, so it IS where that buffer drew.
    local function lastxy(ch)
        -- STRIDE FROM THE MAP, NOT A LITERAL (P3.58). This held its own `* 4` while
        -- ch_last's entry grew to 8 bytes to carry the parity, so it read the vizier's
        -- record for both characters and reported the princess standing where he was.
        -- Third home of one constant; the runner now derives it from the symbols.
        local o = LAST + (ch * 2 + shown) * LAST_STRIDE
        return rd8(o), rd8(o + 1)
    end
    local vx, vy = lastxy(0)
    local px, py = lastxy(1)
    f2:write(string.format("%s %d %d %d %d %d %d\n", tag,
                           vx, vy, rd8(DRAWN + 0 * 2 + shown),
                           px, py, rd8(DRAWN + 1 * 2 + shown)))
    f2:close()
end


local checks, failed = {}, 0
local function check(name, ok, detail)
    checks[#checks + 1] = name
    if not ok then failed = failed + 1 end
    log(string.format("%-28s %s %s", name, ok and "PASS" or "FAIL", detail or ""))
end

-- TWO REGISTERS, NOT FOUR (P3.71) — see the same note in walk_test.lua. Writing all
-- four un-mapped the $C000 cel bank on every capture; the 15,360 B read at $8000..$BBFF
-- only ever needed $FFA4 and $FFA5.
local function map_blocks(first)
    for i = 0, 1 do mem:write_u8(0xFFA4 + i, first + i) end
end

-- P_DUMP_BACK captures the DRAWN buffer rather than the displayed one. It exists for
-- the single-buffer probe (P3.29): with the page flip disabled the drawn buffer is
-- never displayed, so a capture of the front would show a static room and prove
-- nothing. Diagnostic only — the shipped suite captures the front, which is what the
-- viewer actually sees.
local DUMP_BACK = (os.getenv("P_DUMP_BACK") or "0") ~= "0"

local function dump_front(path)
    local back = rd8(CUR_BACK)
    local back_blk  = (back == 0) and BLOCK_A or BLOCK_B
    local front_blk = (back == 0) and BLOCK_B or BLOCK_A
    map_blocks(DUMP_BACK and back_blk or front_blk)
    local t = {}
    for i = 0, FB_SIZE - 1 do t[#t + 1] = string.char(rd8(FB_BASE + i)) end
    map_blocks(back_blk)
    local o = io.open(path, "wb")
    if not o then return false end
    o:write(table.concat(t)); o:close()
    log(string.format("# displayed buffer %s -> %s", (back == 0) and "B" or "A", path))
    return true
end

local state, t0, started, shot1, loaded = "boot", nil, nil, nil, nil
-- star_off from the engine: rows 98/101/109/114 at bytes 9/8/8/9, stride 80
-- measured on the running oracle, not derived: mono px 20/14/16/19 on rows
-- 98/101/109/114 -> bytes 10/8/9/9 under the +20 centring
local STAR_OFF = { 98*80+10, 101*80+8, 109*80+9, 114*80+9 }
local star_watch, star_seen, star_prev, star_checked = nil, 0, nil, false
local star_each = {}

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
        -- OBSERVE THE LOAD, THEN SETTLE. A fixed delay is a bet on how long DECB
        -- takes, and phase B lost that bet: ROOM.BIN grew from 1,239 to 4,369 bytes
        -- when the compiled flames landed in it, the load ran past the old 500-frame
        -- delay, and EXEC was posted while DECB was still busy — P3.6's bug exactly,
        -- which presents as the program simply never running. $2000 holds
        -- `jmp room_start` once the image is placed, so the load is observable.
        -- ...but $2000 holding the jmp only means DECB wrote the FIRST byte, and
        -- ROOM.BIN is 4.4 KB now, so the load runs on well past that. Detecting it
        -- and settling 90 frames posted EXEC EARLIER than the old blind delay did,
        -- and the keystroke was swallowed mid-load. Jay saw it from the outside:
        -- "all i see is the load command and then it closes" — EXEC never typed.
        --
        -- This test runs under -nothrottle, so waiting costs nothing: wait out any
        -- plausible load, then post. (The LIVE runner cannot afford this and needs a
        -- real completion signal instead.)
        if loaded == nil and rd8(0x2000) == 0x7E then
            loaded = fn
            log("# LOADM first byte landed at frame " .. fn)
        end
        if fn > t0 + 900 then
            -- Is the image still intact at the moment we hand over? This separates
            -- "the program was clobbered" from "EXEC never reached BASIC" — two very
            -- different bugs that present identically as "nothing happened".
            log(string.format("# at EXEC: $2000=%02X %02X %02X, $7900=%02X, text row0=%s",
                              rd8(0x2000), rd8(0x2001), rd8(0x2002), rd8(0x7900),
                              (function()
                                  local s = ""
                                  for i = 0, 31 do
                                      local c = rd8(0x0400 + i) & 0x7F
                                      s = s .. ((c >= 32 and c < 127) and string.char(c) or ".")
                                  end
                                  return s
                              end)()))
            nk:post('EXEC\n')
            log("# posted EXEC at frame " .. fn)
            state, started = "running", fn
        end
        return
    end
    -- running / second
    local magic = rd8(ENGINE + 6) * 256 + rd8(ENGINE + 7)

    -- THE STARTUP GAP, sampled every frame from EXEC onward.
    --
    -- Jay timed this by eye — "like 2 seconds between the static screen being rendered
    -- and the torches to be drawn and start animating" — and eye-timing was the only
    -- instrument this suite had, because every check here fires AFTER the flames are
    -- already running and so cannot see how long getting there took. HAL_gfx_swaps
    -- leaving 0 is the frame VOFFSET first moved, which is the frame the room became
    -- visible; probe_frames leaving 0 is the first flicker drawn.
    if not gap_visible and rd8(SWAPS) ~= 0 then gap_visible = fn end
    if not gap_moving and rd8(ENGINE + 8) ~= 0 then gap_moving = fn end
    if state == "second" then
        -- TWELVE FRAMES LATER, and the number is derived rather than picked. One
        -- capture proves a picture; two prove MOTION, which is the whole of phase B's
        -- claim -- but only if the pair is guaranteed to straddle a state change.
        --
        -- It was 4, and 4 was never enough. The loop now runs at 60 Hz and a
        -- FLAME_DIV=3 step is 3 video frames (measured: mean 3.00), so 4 frames
        -- straddles a change only when the phase falls right. It was worse before the
        -- rate fix -- a doubled VBL wait made the loop 30 Hz and a step SIX frames --
        -- and that is how the fragility surfaced: the check passed for months on luck
        -- and failed the moment the startup fix moved the phase by 13 frames,
        -- reporting "a still picture" for flames that were animating correctly.
        --
        -- 12 = four full steps at the current rate and two at the old one, so it holds
        -- at any phase and would have held across the rate change itself.
        if fn >= shot1 + 12 then
            log_positions("second")
            check("second_capture", dump_front(DUMP2),
                  string.format("frames %d and %d", shot1, fn))
            check("flicker_running", rd8(ENGINE + 8) > 0,
                  string.format("probe_frames=%d", rd8(ENGINE + 8)))
            -- 30 frames = half a second, comfortably under what an eye reads as a
            -- pause and comfortably over the few frames the second expand costs. The
            -- old design sat at ~2 s here; a regression puts a track read back between
            -- the picture and the motion, which is hundreds of frames, not tens.
            if gap_visible and gap_moving then
                local d = gap_moving - gap_visible
                check("startup_gap_small", d <= 30,
                      string.format("room visible f%d -> flames moving f%d = %d frames "
                                    .. "(%.2f s)", gap_visible, gap_moving, d, d / 59.92))
            else
                check("startup_gap_small", false,
                      "never observed both the first swap and the first flicker frame")
            end
            finish("room displayed, two captures")
        end
        return
    end
    if magic == ROOM_MAGIC and rd8(ENGINE + 8) == 0 then
        return          -- room is up, but the flame bundle is still loading
    end

    -- THE STARS. They light roughly one frame in 25 and burn 5-8 frames, so two
    -- captures four frames apart will usually miss them entirely — which is exactly
    -- why the flicker checks below say nothing about them. Watch instead: the back
    -- buffer is mapped at $8000, and pstars redraws all four into it every frame.
    if star_watch == nil then star_watch, star_seen, star_prev = fn, 0, {} end
    -- PER STAR, not lumped. Jay reports seeing only one blink and asks whether a star
    -- might be drawn and then lost before it reaches the displayed buffer. That
    -- predicts something different from a biased RNG: if stars are LOST, all four
    -- change in the back buffer and only one survives to the front; if the SELECTION
    -- is biased, only one ever changes anywhere. A lumped count cannot tell those
    -- apart, which is why it has been reporting a healthy-looking 22 all along.
    if fn < star_watch + 600 then
        for i, off in ipairs(STAR_OFF) do
            local v = rd8(0x8000 + off)
            if star_prev[i] ~= nil and star_prev[i] ~= v then
                star_each[i] = (star_each[i] or 0) + 1
                star_seen = star_seen + 1
            end
            star_prev[i] = v
        end
        return
    end
    if not star_checked then
        star_checked = true
        local parts = {}
        for i = 1, 4 do parts[#parts + 1] = string.format("star%d=%d", i - 1, star_each[i] or 0) end
        local lit = 0
        for i = 1, 4 do if (star_each[i] or 0) > 0 then lit = lit + 1 end end
        check("stars_twinkle", lit == 4,
              string.format("%d of 4 stars ever changed in 600 frames (%s)",
                            lit, table.concat(parts, " ")))
    end
    if magic == ROOM_MAGIC then
        check("room_reached_screen", true,
              string.format("magic $%04X at frame %d", magic, fn))
        -- TWO reads: the room track once and the flame bundle once. It was three
        -- until Jay timed the gap — "like 2 seconds between the static screen being
        -- rendered and the torches" — and the third read turned out to be the room
        -- fetched a SECOND time to fill the other buffer, after the picture was
        -- already on screen. The blob now lives in main RAM and expands twice from
        -- there, so this count is the assertion that the delay has not crept back:
        -- a regression to 3 is exactly the visible pause returning.
        -- THREE READS FROM P3.71, not two: room blob, flame bundle, and the cel image
        -- into the $C000 bank. This is re-KEYED rather than relaxed -- the count is a
        -- real assertion, because a read that silently does not happen is a black scene
        -- or a screen of garbage cels, and `>= 2` would pass for both. It is also the
        -- P3.50 shape from the safe side: a guard keyed to the expected-good value,
        -- where the good value legitimately moved and the guard correctly fired.
        check("disk_reads_ok", rd8(ENGINE + 4) == 3,
              string.format("loads=%d (want 3: room + flame bundle + cel image), status $%02X",
                            rd8(ENGINE + 4), rd8(ENGINE + 5)))
        -- The GIME's VRES register is write-only: reading $FF99 returns bus noise,
        -- not what was written ($1B came back for a register set to $15). Check the
        -- HAL's own record of the active mode instead — real state, and readable.
        check("mode_is_4_colour", rd8(CURMODE) == 0,
              string.format("HAL_gfx_cur_mode=%d (want 0 = 320x192x4)", rd8(CURMODE)))
        -- record which cel each torch is showing, so the offline pixel check
        -- composites the right one instead of guessing
        local c0, c1 = rd8(ENGINE + 9), rd8(ENGINE + 10)
        log(string.format("# cels on screen: torch0=%d torch1=%d", c0, c1))
        local cf = io.open("build/room_cels.txt", "w")
        if cf then cf:write(c0 .. " " .. c1); cf:close() end
        -- DO THE TWO BUFFERS AGREE? Every check in this file reads ONE buffer, so
        -- none can see the page flip alternating between two different pictures --
        -- which is what a perfectly regular 2-frame change period implies, and which
        -- the eye blends into colours present in neither.
        do
            local back = rd8(CUR_BACK)
            local bblk = (back == 0) and BLOCK_A or BLOCK_B
            local fblk = (back == 0) and BLOCK_B or BLOCK_A
            local diff, first = 0, nil
            for _, col in ipairs({28, 29, 50, 51}) do
                for row = 101, 113 do
                    local o = 0x8000 + row * 80 + col
                    map_blocks(fblk); local fv = rd8(o)
                    map_blocks(bblk); local bv = rd8(o)
                    if fv ~= bv then
                        diff = diff + 1
                        if not first then first = string.format("row %d col %d: front $%02X back $%02X", row, col, fv, bv) end
                    end
                end
            end
            -- OBSERVATION, not a check. With the swap correctly after the VBL wait,
            -- the front holds the state just drawn and the back the previous one, so
            -- they differ by one step BY CONSTRUCTION. That is benign: the displayed
            -- buffer is always the fresh one, which verify_room_flame_pixels asserts
            -- directly. Asserting equality here demanded something the design does
            -- not promise -- and it only passed before because the old ordering
            -- swapped mid-frame, which was the actual defect.
            log(string.format("# pages differ in %d of 52 flame bytes (expected, one step apart)%s",
                              diff, first and ("; " .. first) or ""))
        end
        log_positions("first")
        check("front_buffer_dumped", dump_front(DUMP), "")
        shot1 = fn
        state = "second"
    elseif fn > started + 1800 then
        -- What is BASIC actually showing? Jay watching from outside said the load
        -- command appears and nothing follows, which is worth confirming from the
        -- text screen rather than inferring from silence.
        for row = 0, 15 do
            local s = ""
            for i = 0, 31 do
                local c = rd8(0x0400 + row * 32 + i) & 0x7F
                s = s .. ((c >= 32 and c < 127) and string.char(c) or ".")
            end
            if s:gsub("%.", "") ~= "" then log(string.format("# text %2d |%s|", row, s)) end
        end
        check("room_reached_screen", false,
              string.format("magic $%04X, status %d, loads %d, dskerr $%02X after 30 s",
                            magic, rd8(ENGINE + 3), rd8(ENGINE + 4), rd8(ENGINE + 5)))
        finish("timed out")
    end
end

_G._notifier = emu.add_machine_frame_notifier(tick)
