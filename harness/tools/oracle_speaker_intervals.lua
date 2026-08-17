-- oracle_speaker_intervals.lua — P4.4: what does the speaker ACTUALLY do?
--
-- ★★★ WHY THIS EXISTS. P4.1 and P4.2 both described the oracle's audio as a bit-banged
-- square wave "fully described by frequency and duration". P4.3 read the player end to end
-- and both were wrong: MSYS is a one-bit PULSE-WIDTH MODULATOR. The note sets a SEGMENT
-- RATE; the amplitude sets a PULSE WIDTH inside it; and a compensating delay loop
-- (MADJLP) exists specifically so the width cannot affect the rate.
--
-- So the 468 Hz "floor" question was a real number about the wrong quantity, and no amount
-- of reading the NOTE table could have answered it. ★★ THIS REPLACES INFERENCE WITH
-- OBSERVATION: read the intervals between speaker toggles on the running machine and let
-- them say what the rates and widths are.
--
-- ---------------------------------------------------------------------------
-- WHAT IS TAPPED, AND THE ONE THING THAT COULD MAKE IT LIE
-- ---------------------------------------------------------------------------
-- $C030 is the Apple's speaker soft switch. `LDA $C030` toggles it — the ADDRESS is what
-- matters, not the value, so this is a READ tap.
--
-- ★★ AND THE PROJECT'S STANDING WARNING IS ABOUT EXACTLY THIS: on the 6502, read-taps on
-- CODE addresses silently false-0 through the opcode-fetch bypass [mame-idioms-apple2e-
-- oracle.md §1], which is why every previous oracle tool here uses WRITE taps. $C030 is
-- not a code address — it is an I/O read performed as DATA by an LDA — so the bypass does
-- not apply. ★★★ BUT THAT IS AN ARGUMENT, AND AN ARGUMENT IS NOT A MEASUREMENT: a tap that
-- silently never fires reads exactly like "the music is silent". So the run FAILS LOUDLY on
-- a zero count and reports the count first, before any characterisation.
--
-- ---------------------------------------------------------------------------
-- TIME, NOT FRAMES
-- ---------------------------------------------------------------------------
-- The intervals of interest are ~microseconds to ~milliseconds. A frame is 16.7 ms, so
-- frame_number() is useless here. `manager.machine.time` is an attotime; seconds +
-- attoseconds/1e18 gives a double with far more resolution than needed.
--
-- ★ WHAT THE STRUCTURE SHOULD LOOK LIKE, from P4.3's reading — stated as a PREDICTION so
-- the data can contradict it:
--     toggle A ... [pulse width] ... toggle B ... [rest of segment] ... toggle A ...
-- so intervals should ALTERNATE short/long, with
--     segment period = short + long        <- the NOTE's rate
--     short                                <- the AMPLITUDE level
-- If they do not alternate, P4.3's reading is wrong and that is the finding.
--
-- P_SONG names which song this run is about, for the record; it does not select it — the
-- arming markers do.
local OUT   = os.getenv("P_OUT") or "build/tmp/oracle_speaker.log"
local SONG  = os.getenv("P_SONG") or "s_Princess (title set, id 7)"
local AFTER = tonumber(os.getenv("P_AFTER") or "400")     -- frames to record once armed
local MAXEV = tonumber(os.getenv("P_MAXEV") or "60000")
local RAWN  = tonumber(os.getenv("P_RAWN") or "40")

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local out = io.open(OUT, "w")
local function log(s) out:write(s .. "\n"); out:flush() end

local SPKR  = 0xC030
local SPEED = 0x030C          -- MASTER.LST:530
local PSAND = 0xE14A          -- GAMEBG.LST:311

-- ★ ARMED ON THE SCENE'S OWN MARKER. PlayCut0 sets SPEED 7 three lines before
-- `lda #Vapproach` [SUBS.S:683] — the FIRST of the two SPEED-7 writes, which P3.101
-- established opens the ENTRY walk. s_Princess plays before that, so the window opens at
-- the cutscene's start: SPEED 12 at f2681 is the earliest marker PlayCut0 writes.
-- Arming on a VALUE rather than a frame keeps this reproducible however long the boot took.
local armed_at, nev, ev = nil, 0, {}
local t_prev = nil

local function now()
    local t = manager.machine.time
    return t.seconds + t.attoseconds / 1.0e18
end

_G._tsp = mem:install_write_tap(SPEED, SPEED, "sp", function(off, data, mask)
    if data == 12 and armed_at == nil then armed_at = scr:frame_number() end
    return data
end)

_G._tspk = mem:install_read_tap(SPKR, SPKR, "spkr", function(off, data, mask)
    if armed_at == nil then return data end
    nev = nev + 1
    if #ev < MAXEV then
        local t = now()
        if t_prev then ev[#ev + 1] = (t - t_prev) * 1.0e6 end   -- microseconds
        t_prev = t
    end
    return data
end)

local reported = false
_G._n = emu.add_machine_frame_notifier(function()
    if reported or armed_at == nil then return end
    if scr:frame_number() <= armed_at + AFTER then return end
    reported = true

    log("# THE SPEAKER, MEASURED — $C030 toggle intervals on the running oracle")
    log(string.format("# song under measurement: %s", SONG))
    log(string.format("# armed at frame %d (PlayCut0's SPEED 12); recorded %d frames",
                      armed_at, AFTER))
    log("")

    -- ★ THE COUNT FIRST. A silent tap and a silent machine are the same picture.
    log(string.format("# ★ TOGGLES OBSERVED: %d (%d intervals kept, cap %d)",
                      nev, #ev, MAXEV))
    if nev == 0 then
        log("# ★★★ ZERO TOGGLES. Either the machine made no sound in this window or the")
        log("#     read-tap on $C030 does not fire. THOSE ARE DIFFERENT AND THIS RUN CANNOT")
        log("#     TELL THEM APART — do not read silence as a finding (P3.48b).")
        out:close(); manager.machine:exit(); return
    end
    log("#   Non-zero, so the tap fires: a 6502 read-tap on an I/O address is not subject")
    log("#   to the opcode-fetch bypass that defeats taps on code addresses.")
    log("")

    -- ---- the raw shape, before any interpretation -------------------------------
    log(string.format("# RAW — the first %d intervals, in microseconds, in order.", RAWN))
    log("# P4.3 predicts these ALTERNATE short/long: pulse width, then rest of segment.")
    local line = {}
    for i = 1, math.min(RAWN, #ev) do
        line[#line + 1] = string.format("%.1f", ev[i])
        if #line == 10 then log("    " .. table.concat(line, "  ")); line = {} end
    end
    if #line > 0 then log("    " .. table.concat(line, "  ")) end
    log("")

    -- ---- does it alternate? ------------------------------------------------------
    -- Classify each interval against the running median; if the structure is
    -- short/long/short/long the parity split is clean and the two populations separate.
    local sorted = {}
    for i = 1, #ev do sorted[i] = ev[i] end
    table.sort(sorted)
    local med = sorted[math.floor(#sorted / 2)]
    local odd_short, even_short = 0, 0
    for i = 1, #ev do
        if ev[i] < med then
            if i % 2 == 1 then odd_short = odd_short + 1 else even_short = even_short + 1 end
        end
    end
    local n = #ev
    log(string.format("# ALTERNATION CHECK — median interval %.1f us. Of the %d intervals,",
                      med, n))
    log(string.format("#   %d below-median fall on ODD positions and %d on EVEN.",
                      odd_short, even_short))
    local skew = math.max(odd_short, even_short) / math.max(1, odd_short + even_short)
    if skew > 0.85 then
        log("#   ★ STRONGLY ALTERNATING — consistent with P4.3's pulse/segment reading.")
    else
        log("#   ★★★ NOT ALTERNATING. P4.3's pulse-then-rest structure is NOT what the")
        log("#       speaker is doing, and that reading needs revisiting.")
    end
    log("")

    -- ---- the two populations, and the segment period ------------------------------
    local shorts, longs = {}, {}
    for i = 1, #ev do
        if ev[i] < med then shorts[#shorts + 1] = ev[i] else longs[#longs + 1] = ev[i] end
    end
    local function stats(t)
        if #t == 0 then return 0, 0, 0 end
        local s = {}
        for i = 1, #t do s[i] = t[i] end
        table.sort(s)
        local sum = 0
        for i = 1, #s do sum = sum + s[i] end
        return s[1], s[#s], sum / #s
    end
    local slo, shi, savg = stats(shorts)
    local llo, lhi, lavg = stats(longs)
    log("# THE TWO POPULATIONS")
    log(string.format("#   short (the PULSE):   n=%-6d min %.1f  max %.1f  mean %.1f us",
                      #shorts, slo, shi, savg))
    log(string.format("#   long  (the REST):    n=%-6d min %.1f  max %.1f  mean %.1f us",
                      #longs, llo, lhi, lavg))
    log("")

    -- segment period = consecutive pairs, which is what sets the PITCH
    local segs = {}
    for i = 1, #ev - 1, 2 do segs[#segs + 1] = ev[i] + ev[i + 1] end
    local glo, ghi, gavg = stats(segs)
    log("# ★★★ THE SEGMENT PERIOD — pulse + rest, which is what the NOTE sets.")
    log(string.format("#   n=%d   min %.1f us   max %.1f us   mean %.1f us", #segs, glo, ghi, gavg))
    if glo > 0 and ghi > 0 then
        log(string.format("#   => RATE RANGE ACTUALLY USED: %.0f Hz .. %.0f Hz (mean %.0f Hz)",
                          1.0e6 / ghi, 1.0e6 / glo, 1.0e6 / gavg))
        log("#   ★ This is the REACHED set — what this song plays, not what the table can")
        log("#     express. A NOTE entry no song references is not a constraint.")
    end

    -- a coarse histogram of segment periods, so multi-modality is visible
    log("")
    log("# SEGMENT PERIOD HISTOGRAM (us buckets, log-ish spacing)")
    local edges = { 0, 100, 200, 400, 800, 1600, 3200, 6400, 12800, 1e9 }
    local hist = {}
    for i = 1, #edges - 1 do hist[i] = 0 end
    for _, v in ipairs(segs) do
        for i = 1, #edges - 1 do
            if v >= edges[i] and v < edges[i + 1] then hist[i] = hist[i] + 1; break end
        end
    end
    for i = 1, #edges - 1 do
        if hist[i] > 0 then
            log(string.format("#   %6.0f..%-8.0f us  %-7d  (%.0f..%.0f Hz)",
                              edges[i], edges[i + 1], hist[i],
                              1.0e6 / edges[i + 1], edges[i] > 0 and 1.0e6 / edges[i] or 0))
        end
    end
    out:close()
    manager.machine:exit()
end)
