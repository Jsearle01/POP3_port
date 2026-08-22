-- intro_load_trace.lua — P5.13: every disk read from power-on to the attract loop's
-- repeat, with WHAT WAS ON SCREEN during each one.
--
-- ★★ THE "WHAT WAS ON SCREEN" COLUMN IS THE POINT [§8]. A two-second read under a loading
-- screen and a two-second read during the cutscene are the same measurement and opposite
-- findings, so no duration is reported without it.
--
-- THREE TAPS, ALL EVENT-ACCURATE [§5.239 -- sampling cannot see a load that starts and ends
-- inside one frame]:
--
--   $FF4B  FDC data register, READ tap. Every byte the WD1773 moves passes through it, so
--          this sees the TRANSFER itself -- including DECB's boot LOADM, which the engine's
--          own counter cannot see because the engine is not running yet.
--          (6809 read taps fire; the 6502 ones silently false-0 [mame-idioms].)
--   $FF40  DSKREG, WRITE tap. DRIVE-ENGAGED time, which is what the machine actually waits
--          for: the WD1773 paces the 6809 with HALT, so from load_tracks starting to
--          `clr DSKREG` the CPU is stopped -- through seek, settle and rotational latency
--          as well as the bytes.
--   $FF20  DAC, WRITE tap. ★ THE MUSIC QUESTION [§3.2]. msys_player drives this from a FIRQ
--          [msys_player.s:144 `DAC equ $FF20`], and disk_read_range masks interrupts. If the
--          DAC stops being written across a drive-engaged span, the song stopped. This is
--          the one Jay's ear would catch and no other instrument would.
--
-- Both idioms above are lifted from introseq_test.lua, which measured them for the intro
-- alone; this extends them across the whole attract cycle and adds the DAC.

local OUT     = os.getenv("P_OUT") or "build/tmp/intro_loads.txt"
local SWAPS   = tonumber(os.getenv("P_SWAPS") or "0")
local CURBACK = tonumber(os.getenv("P_CURBACK") or "0")
local RUNLEN  = tonumber(os.getenv("P_LEN") or "12000")

local FDC_DATA, DSKREG, DAC = 0xFF4B, 0xFF40, 0xFF20
-- ★ AC4: WHERE THE NON-DISK WAIT GOES. lz_unpack writes its stop address to `lz_end` on
-- entry [lz_unpack.s: `sty lz_end`], so a WRITE tap there fires once per expansion and
-- timestamps it. 512 KB removes READS, not DECOMPRESSION, so this is the measurement that
-- decides whether the premise holds.
local LZEND = tonumber(os.getenv("P_LZEND") or "0")
-- ★ AND ITS DURATION. lz_unpack writes `lz_cnt` on every literal run and every match
-- [lz_unpack.s: `sta lz_cnt` in both arms], so a write tap there fires throughout the
-- expansion and first-to-last bounds it. One entry timestamp cannot give a duration; this
-- can.
local LZCNT = tonumber(os.getenv("P_LZCNT") or "0")
local lz_calls, lz_busy = {}, {}

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local out = io.open(OUT, "w")
local function say(s) out:write(s .. "\n"); out:flush() end
local function rd(a) return mem:read_u8(a) end

local frame = 0
local spans = {}            -- drive-engaged spans
local cur = nil
local fdc_bytes = 0
local dac_per_frame = {}    -- frame -> DAC writes
local swaps_at = {}         -- frame -> HAL_gfx_swaps value
local first_swap = nil

_G._fdc = mem:install_read_tap(FDC_DATA, FDC_DATA, "fdc", function(off, data, mask)
    fdc_bytes = fdc_bytes + 1
    if cur then cur.bytes = cur.bytes + 1 end
    return data
end)

_G._dsk = mem:install_write_tap(DSKREG, DSKREG, "dskreg", function(off, data, mask)
    local on = (data ~= 0)
    if on and not cur then
        cur = { first = frame, bytes = 0, dac0 = 0, swap0 = SWAPS ~= 0 and rd(SWAPS) or 0 }
    elseif not on and cur then
        cur.last = frame
        spans[#spans + 1] = cur
        cur = nil
    end
    return data
end)

_G._dac = mem:install_write_tap(DAC, DAC, "dac", function(off, data, mask)
    dac_per_frame[frame] = (dac_per_frame[frame] or 0) + 1
    if cur then cur.dac0 = cur.dac0 + 1 end
    return data
end)

-- ★ THE PROGRAM HAS TO BE STARTED, and the first run of this tool forgot to. It reported
-- zero disk spans over 200 emulated seconds, which reads as "the intro does no I/O" and is
-- actually "the intro never ran": the delivery path is LOADM + EXEC off the floppy
-- [CLAUDE.md §4 `live-disk`], and nothing types them unless the script does.
local nk = manager.machine.natkeyboard
nk.in_use = true
local state, t0, boot_done = "boot", nil, nil

if LZCNT ~= 0 then
    _G._lzc = mem:install_write_tap(LZCNT, LZCNT, "lzc", function(off, data, mask)
        lz_busy[frame] = (lz_busy[frame] or 0) + 1
        return data
    end)
end

if LZEND ~= 0 then
    _G._lz = mem:install_write_tap(LZEND, LZEND, "lz", function(off, data, mask)
        lz_calls[#lz_calls + 1] = frame
        return data
    end)
end

_G._n = emu.add_machine_frame_notifier(function()
    frame = frame + 1
    if state == "boot" then
        if frame >= 300 then
            nk:post('LOADM"LOADER"\n')
            state, t0 = "loadm", frame
        end
        return
    elseif state == "loadm" then
        if frame > t0 + 500 then
            nk:post('EXEC\n')
            state, boot_done = "run", frame
            say("# posted EXEC at frame " .. frame .. " — everything after this is the port")
        end
        return
    end
    if SWAPS ~= 0 then
        local s = rd(SWAPS)
        swaps_at[frame] = s
        if not first_swap and s ~= 0 then first_swap = frame end
    end
    if frame < RUNLEN then return end

    say("# intro_load_trace — " .. frame .. " frames at 59.92 Hz = "
        .. string.format("%.1f s", frame / 59.92))
    say(string.format("# FDC data-register reads (bytes transferred): %d", fdc_bytes))
    say(string.format("# first page flip (HAL_gfx_swaps != 0): frame %s",
                      first_swap and tostring(first_swap) or "never"))
    say("")
    -- ★ A COUNT DURING A SPAN MEANS NOTHING WITHOUT ITS NEIGHBOURS. dac=0 during a read is
    -- "the song stopped" only if the song was playing on either side of it; otherwise it is
    -- "no song was playing". Same for flips. So each span is reported with the 60 frames
    -- before and after, and the verdict is derived from the comparison, not from the zero.
    local function window(a, b, tbl)
        local n = 0
        for f = a, b do n = n + (tbl[f] or 0) end
        return n
    end
    local function swapwin(a, b)
        if SWAPS == 0 or not swaps_at[a] or not swaps_at[b] then return -1 end
        return swaps_at[b] - swaps_at[a]
    end
    say("# Each span with its NEIGHBOURHOOD: 60 frames before | during | 60 after.")
    say("# STOPPED = activity on both sides and none during. QUIET = none on any side.")
    say("  #   first   last frames  secs   bytes | dac:bef dur aft | flips:bef dur aft | verdict")
    local tot = 0
    for i, s in ipairs(spans) do
        local n = s.last - s.first
        tot = tot + n
        local sw = (SWAPS ~= 0 and swaps_at[s.last] and swaps_at[s.first])
                   and (swaps_at[s.last] - swaps_at[s.first]) or -1
        local db = window(math.max(1, s.first - 60), s.first - 1, dac_per_frame)
        local da = window(s.last + 1, s.last + 60, dac_per_frame)
        local fb, fd, fa = swapwin(math.max(1, s.first - 60), s.first - 1),
                           swapwin(s.first, s.last), swapwin(s.last + 1, s.last + 60)
        local dv = (db > 0 and da > 0 and s.dac0 == 0) and "MUSIC STOPPED"
                or (db == 0 and da == 0 and s.dac0 == 0) and "music quiet either side"
                or "music ran"
        local fv = (fb > 0 and fa > 0 and fd == 0) and "SCREEN FROZE"
                or (fb == 0 and fa == 0) and "screen static either side"
                or "screen ran"
        say(string.format("  %-3d %6d %6d %6d %5.2f %7d | %7d %3d %3d | %9d %3d %3d | %s; %s",
                          i, s.first, s.last, n, n / 59.92, s.bytes,
                          db, s.dac0, da, fb, fd, fa, dv, fv))
    end
    -- AC2/AC4: the milestones, and the gaps where the disk is IDLE. Decompression can only
    -- live in a gap, because DSKREG is asserted for the whole of every span.
    say("")
    say("# GAPS between spans -- disk idle. Decompression, beats and waits all live here.")
    say("  after#   from     to  frames   secs   flips in the gap")
    local prev = nil
    for i, s in ipairs(spans) do
        if prev and s.first - prev > 30 then
            local f = swapwin(prev, s.first)
            say(string.format("  %-6d %6d %6d %7d %6.2f %6d",
                              i - 1, prev, s.first, s.first - prev,
                              (s.first - prev) / 59.92, f))
        end
        prev = s.last
    end
    say("")
    local mx = 0
    for f = 1, frame do if swaps_at[f] and swaps_at[f] > mx then mx = swaps_at[f] end end
    say(string.format("# HAL_gfx_swaps is a byte and wraps; max seen %d. Flip milestones:", mx))
    local seenv = {}
    for f = 1, frame do
        local v = swaps_at[f]
        if v and not seenv[v] and (v % 32 == 0) then
            seenv[v] = f
            say(string.format("    swaps=%3d first at frame %6d (%.1f s)", v, f, f / 59.92))
        end
    end
    say("")
    if LZEND ~= 0 then
        say(string.format("# lz_unpack entries (write to lz_end $%04X): %d", LZEND, #lz_calls))
        local last = nil
        for _, f in ipairs(lz_calls) do
            if not last or f - last > 2 then
                -- walk forward while lz_cnt is still being written: that is the expansion
                local e = f
                while lz_busy[e + 1] or lz_busy[e + 2] do e = e + 1 end
                say(string.format("    expansion at frame %6d (%.1f s) -> ends %6d, "
                                  .. "%d frames = %.2f s", f, f / 59.92, e, e - f,
                                  (e - f) / 59.92))
            end
            last = f
        end
        local tb = 0
        for _, v in pairs(lz_busy) do tb = tb + 1 end
        say(string.format("    frames in which lz_cnt was written at all: %d = %.2f s total",
                          tb, tb / 59.92))
    else
        say("# lz_end not resolved -- decompression NOT attributed.")
    end
    say("")
    say(string.format("# %d spans, %d frames engaged = %.2f s of %.1f s (%.1f%%)",
                      #spans, tot, tot / 59.92, frame / 59.92, 100 * tot / frame))
    out:close()
    manager.machine:exit()
end)

say("# arming")
