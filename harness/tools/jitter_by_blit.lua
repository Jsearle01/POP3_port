-- jitter_by_blit.lua — P4.36: do the periods that CONTAIN a blit deviate more than the ones
-- that do not?
--
-- ★★★ WHY THIS EXISTS, AND WHY IT COMES BEFORE THE FIX. P4.31 attributed 67% of the music's
-- residual jitter (median |delta| 91 us) to blit_cel's per-row interrupt mask, and P4.35
-- left the narrower window -- masking only the two blast regions -- as "the whole of the
-- remaining lever". That plan restructures the port's HOTTEST code.
--
-- ★★ BUT P4.35's OWN CENSUS CONTAINS A NUMBER THAT CONTRADICTS IT: an ordinary note period
-- contains 0.09 blits on average, so only about NINE PERCENT of periods have a blit inside
-- them at all. If the blitter caused the bulk of the jitter, ~91% of periods would be clean
-- and the MEDIAN deviation would be near zero. It is 91 us.
--
-- ★ A COMPETING EXPLANATION, WHICH IS WHY THIS IS A TEST AND NOT A CONFIRMATION: the GIME
-- timer's TINS0 tick is ~63.7 us, and gen_msys_tables.py reports the note table quantised
-- against it ("worst quantisation +10.0 cents ... TINS0 div1 60", "pad 4855 us -> TINS0 76
-- ticks"). A median deviation of 91 us is about 1.4 ticks. Timer granularity and a prescale
-- that alternates tick counts would produce exactly this, BY DESIGN, with no interrupt
-- latency involved at all.
--
-- ---------------------------------------------------------------------------
-- THE TEST
-- ---------------------------------------------------------------------------
-- For every consecutive pair of note periods, record |period[i] - period[i-1]| AND whether
-- a blit started inside period[i]. Then report the two distributions side by side.
--
--   if BLIT periods deviate much more than CLEAN ones   the blitter is the cause and the
--                                                       narrower window is worth the risk
--   if the two distributions are the SAME               the blitter is NOT the cause, the
--                                                       jitter is the player's own timer
--                                                       resolution, and restructuring the
--                                                       blitter would buy nothing
--
-- ★★ THIS IS THE CHECK P4.31 SHOULD HAVE MADE BEFORE SIZING THE LEVER AT 67%. Correlation
-- with the suspect was assumed from the magnitude matching a masked row; it was never
-- tested against the periods that contain no blit.
local OUT   = os.getenv("P_OUT")   or "build/tmp/jitter_by_blit.log"
local IDX   = tonumber(os.getenv("P_IDX")   or "0EB7", 16)
local SAVED = tonumber(os.getenv("P_SAVED") or "3ADB", 16)
local DAC   = 0xFF20
local WIN_S = tonumber(os.getenv("P_WIN")   or "3.0")

local mem = manager.machine.devices[":maincpu"].spaces["program"]
local nk  = manager.machine.natkeyboard
nk.in_use = true
local scr = manager.machine.screens:at(1)

local function now() return manager.machine.time:as_double() end

local armed, t0 = false, nil
local last_t, last_p = nil, nil
local nblit = 0
local blit_d, clean_d = {}, {}

_G._tc = mem:install_write_tap(IDX, IDX, "cue", function(o, d, m)
    if d == 7 and not armed then armed, t0 = true, now() end
    return d
end)

_G._tb = mem:install_write_tap(SAVED, SAVED, "blit", function(o, d, m)
    if armed then nblit = nblit + 1 end; return d end)

_G._td = mem:install_write_tap(DAC, DAC, "dac", function(o, d, m)
    if not armed or d == 0 then return d end
    local t = now()
    if t - t0 > WIN_S then return d end
    if last_t ~= nil then
        local p = (t - last_t) * 1e6
        if last_p ~= nil then
            local dev = math.abs(p - last_p)
            -- ★ nblit counted the blits inside THIS period, which is the one whose
            -- deviation is being attributed. A blit in the PREVIOUS period would have
            -- lengthened that one instead, and is charged there.
            if nblit > 0 then blit_d[#blit_d + 1] = dev
            else                clean_d[#clean_d + 1] = dev end
        end
        last_p = p
    end
    last_t = t
    nblit = 0
    return d
end)

local function stats(f, name, a)
    if #a < 16 then
        f:write(string.format("  %-22s n=%d  (too few to report)\n", name, #a))
        return
    end
    table.sort(a)
    local s = 0
    for i = 1, #a do s = s + a[i] end
    local function q(x) return a[math.max(1, math.floor(#a * x))] end
    f:write(string.format("  %-22s n=%-5d  median %7.1f us   90th %8.1f us   mean %7.1f us\n",
            name, #a, q(0.50), q(0.90), s / #a))
end

local done = false
_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if done then return end
    if fn == 300 then nk:post('LOADM"LOADER"\n') end
    if fn == 1200 then nk:post('EXEC\n') end
    if fn < 9200 then return end
    done = true

    local f = io.open(OUT, "w")
    f:write("# music period deviation, split by whether a blit ran inside the period.\n")
    f:write("# Same run, same song, same window -- the ONLY difference between the two\n")
    f:write("# groups is the presence of the suspect.\n#\n")
    stats(f, "periods WITH a blit", blit_d)
    stats(f, "periods with NO blit", clean_d)
    f:write("#\n")
    if #blit_d >= 16 and #clean_d >= 16 then
        table.sort(blit_d); table.sort(clean_d)
        local mb = blit_d[math.floor(#blit_d * 0.5)]
        local mc = clean_d[math.floor(#clean_d * 0.5)]
        f:write(string.format("  median ratio  blit / clean = %.2f\n", mb / math.max(1, mc)))

-- ★★★ A RATIO IS NOT A SHARE, AND THE FIRST CUT OF THIS TOOL CONFLATED THEM. It printed
-- "THE BLITTER IS THE CAUSE" on a median ratio over 2.0 -- true, and irrelevant on its own,
-- because only ~10% of periods contain a blit at all. What decides whether narrowing the
-- mask is worth restructuring the hottest code is the blitter's share of the TOTAL
-- deviation, which is its EXCESS over the clean mean times the number of periods that have
-- one. That is computed here instead of asserted.
        local sb, sc = 0, 0
        for i = 1, #blit_d do sb = sb + blit_d[i] end
        for i = 1, #clean_d do sc = sc + clean_d[i] end
        local mean_b, mean_c = sb / #blit_d, sc / #clean_d
        local excess = #blit_d * (mean_b - mean_c)
        local total  = sb + sc
        local share  = 100.0 * excess / total
        f:write(string.format("  periods with a blit      %.1f%% of all periods\n",
                100.0 * #blit_d / (#blit_d + #clean_d)))
        f:write(string.format("  ★ BLITTER'S SHARE of total deviation  %.1f%%\n#\n", share))
        if share > 40.0 then
            f:write("# THE BLITTER IS THE DOMINANT CAUSE. Narrowing the mask is worth the risk\n")
            f:write("# to the hottest code.\n")
        elseif mb > mc * 2.0 then
            f:write("# ★ THE BLITTER IS REAL BUT MINOR. It roughly doubles the deviation in the\n")
            f:write("# periods it touches, and it touches few of them -- so narrowing the mask\n")
            f:write("# would recover only the share above. THE BULK IS PRESENT IN PERIODS WITH NO\n")
            f:write("# BLIT AT ALL, which means it is not interrupt latency: it is inside the\n")
            f:write("# player. TINS0's tick is ~63.7 us and the clean median is ~1.2 ticks, so\n")
            f:write("# the timer's own resolution is the first thing to examine.\n")
        else
            f:write("# ★ THE BLITTER IS **NOT** THE CAUSE OF THE BULK. The two distributions are\n")
            f:write("# comparable, so the residual jitter is NOT interrupt latency -- it is the\n")
            f:write("# player's own timer resolution (TINS0 ~63.7 us per tick; a 91 us median is\n")
            f:write("# ~1.4 ticks). Restructuring blit_core would buy little or nothing, and the\n")
            f:write("# lever for 'still a bit crappy' is the PLAYER, not the blitter.\n")
        end
    end
    f:close()
    manager.machine:exit()
end)
