-- jitter_quantum.lua — P4.37: are the music's period deviations QUANTISED to the GIME
-- timer's tick?
--
-- ★★★ THE HYPOTHESIS UNDER TEST. P4.36 established that the port's residual musical
-- fuzziness is NOT interrupt latency: 90% of note periods contain no blit at all and still
-- deviate by a 76 us median, and the blitter's whole share of the deviation is 12.3%. That
-- leaves the player itself, and one property of it is measurable from outside:
--
--   the GIME timer's TINS0 tick is ~63.7 us, and 76 us is ~1.2 of them
--
-- If the player programs whole tick counts, then every period is an integer number of ticks
-- and every DEVIATION between consecutive periods is an integer number of ticks too. So the
-- deviations would not be smeared -- they would sit in SPIKES at 0, ~64, ~127, ~191 us.
--
-- ★★ THIS IS A FALSIFIABLE SHAPE, WHICH IS THE POINT. Latency, contention and rounding all
-- produce a smooth distribution; quantisation produces a comb. One histogram tells them
-- apart, and neither answer needs me to reason about the player's internals.
--
--   COMB   -> the fuzziness is the timer's resolution. The lever is the note table and the
--            TINS1-plus-divider path gen_msys_tables.py already documents.
--   SMOOTH -> it is not quantisation either, and the next suspect is the player's decode.
--
-- ★ ONLY PERIODS WITH NO BLIT ARE COUNTED. P4.36 showed a blit roughly doubles a period's
-- deviation; including them would smear a comb that is really there. bc_saved_s's address is
-- passed in -- it moved $3AD7 -> $3ADB when six bytes were added to blit_core at P4.29, and
-- a tool with it hard-coded reported "0 brackets", which reads as "the blitter never ran".
local OUT   = os.getenv("P_OUT")   or "build/tmp/jitter_quantum.log"
local IDX   = tonumber(os.getenv("P_IDX")   or "0EB7", 16)
local SAVED = tonumber(os.getenv("P_SAVED") or "3ADB", 16)
local DAC   = 0xFF20
local WIN_S = tonumber(os.getenv("P_WIN")   or "6.0")
local BIN   = tonumber(os.getenv("P_BIN")   or "8")     -- us per histogram bin
local NBIN  = tonumber(os.getenv("P_NBIN")  or "50")    -- so 0..400 us by default
local TICK  = tonumber(os.getenv("P_TICK")  or "63.695")

local mem = manager.machine.devices[":maincpu"].spaces["program"]
local nk  = manager.machine.natkeyboard
nk.in_use = true
local scr = manager.machine.screens:at(1)

local function now() return manager.machine.time:as_double() end

local armed, t0 = false, nil
local last_t, last_p = nil, nil
local nblit = 0
local dev, periods = {}, {}

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
        if last_p ~= nil and nblit == 0 then
            dev[#dev + 1] = math.abs(p - last_p)
            periods[#periods + 1] = p
        end
        last_p = p
    end
    last_t = t
    nblit = 0
    return d
end)

local done = false
_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if done then return end
    if fn == 300 then nk:post('LOADM"INTROSEQ"\n') end
    if fn == 1200 then nk:post('EXEC\n') end
    if fn < 9600 then return end
    done = true

    local f = io.open(OUT, "w")
    f:write("# deviation between consecutive note periods, blit-free periods only.\n")
    f:write(string.format("# %d bins of %d us. GIME TINS0 tick assumed %.3f us; the tick\n",
            NBIN, BIN, TICK))
    f:write("# marks below are drawn from that, NOT fitted to the data.\n#\n")
    if #dev < 64 then
        f:write(string.format("# only %d samples — INCONCLUSIVE.\n", #dev))
        f:close(); manager.machine:exit(); return
    end

    local h, over = {}, 0
    for i = 1, NBIN do h[i] = 0 end
    for i = 1, #dev do
        local b = math.floor(dev[i] / BIN) + 1
        if b >= 1 and b <= NBIN then h[b] = h[b] + 1 else over = over + 1 end
    end
    local peak = 0
    for i = 1, NBIN do if h[i] > peak then peak = h[i] end end

    f:write(string.format("# n=%d in range, %d above %d us\n#\n", #dev - over, over, NBIN * BIN))
    for i = 1, NBIN do
        local lo = (i - 1) * BIN
        local mark = ""
        for k = 0, 6 do
            local c = k * TICK
            if lo <= c and c < lo + BIN then mark = string.format("  <= %d x tick", k) end
        end
        f:write(string.format("  %4d us %-40s %5d%s\n", lo,
                string.rep("#", math.floor(40 * h[i] / math.max(1, peak))), h[i], mark))
    end

    -- how much of the mass sits within a quarter-tick of a whole number of ticks
    local near, tot = 0, 0
    for i = 1, #dev do
        if dev[i] < 7 * TICK then
            tot = tot + 1
            local r = dev[i] / TICK
            local frac = math.abs(r - math.floor(r + 0.5))
            if frac <= 0.25 then near = near + 1 end
        end
    end
    f:write("#\n")
    if tot > 0 then
        f:write(string.format("  within a quarter-tick of a WHOLE tick count: %d of %d  (%.1f%%)\n",
                near, tot, 100.0 * near / tot))
        f:write("  (a smooth distribution would give about 50%; a comb, much more)\n")
    end
    f:close()
    manager.machine:exit()
end)
