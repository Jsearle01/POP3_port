-- firq_latency.lua — P4.28b: HOW LATE is the music interrupt, in microseconds?
--
-- ★★★ THE QUESTION P4.28 LEFT OPEN. That pass measured the SYMPTOM: 81% of the cutscene's
-- pulse periods deviate >5% from the one before, against 11% in the intro. It did not show
-- WHY. The standing lead is `blit_core.s:120`, which masks `orcc #$50` -- IRQ **and FIRQ** --
-- because S becomes the blast destination, while the music is FIRQ-driven. This measures
-- the lateness directly, so the lead is confirmed or killed on a number rather than on a
-- plausible story.
--
-- ---------------------------------------------------------------------------
-- HOW THE EXPECTED PERIOD IS KNOWN, WHICH IS WHAT MAKES "LATE" MEANINGFUL
-- ---------------------------------------------------------------------------
-- The player reloads the GIME timer inside its own handler [msys_player.s:436-437]:
--
--     stb  FF95        ; LSB
--     sta  FF94        ; ...and writing $FF94 is what RESTARTS the timer
--
-- so the 12-bit counter it programs IS the interval the next FIRQ is scheduled for. The
-- handler emits the pulse first and reloads after, so per interrupt we get, in order:
-- pulse-open at $FF20, then the reload for the NEXT one.
--
--   expected(i+1) = counter(i) * TICK
--   actual(i+1)   = t_pulse(i+1) - t_pulse(i)
--   lateness      = actual - expected
--
-- ★★ TICK IS DERIVED, NOT QUOTED. The GIME's TINS bit selects the clock and getting that
-- constant wrong would silently scale every number, so it is fitted from the INTRO window
-- -- which P4.19 gated clean on Jay's ear -- as the median of actual/counter. A constant
-- taken from a datasheet I have not verified on this machine is exactly the kind of
-- assumption this project keeps getting bitten by; a constant fitted to the quiet window
-- makes the busy window's excess self-evidently the difference between them.
--
-- ★ 6809 read-taps work here [mame-idioms-coco3-port.md §10]; these are writes regardless.
local OUT   = os.getenv("P_OUT") or "build/tmp/firq_latency.log"
local IDX   = tonumber(os.getenv("P_IDX") or "0EB7", 16)
local DAC   = 0xFF20
local FF94  = 0xFF94
local FF95  = 0xFF95
local WIN_S = tonumber(os.getenv("P_WIN") or "3.0")

local mem = manager.machine.devices[":maincpu"].spaces["program"]
local nk  = manager.machine.natkeyboard
nk.in_use = true
local scr = manager.machine.screens:at(1)

local function now() return manager.machine.time:as_double() end

local W = {
    { name = "INTRO  s_Presents", song = 1 },
    { name = "SCENE  s_Princess", song = 7 },
}
local cur, lsb = nil, 0

_G._tc = mem:install_write_tap(IDX, IDX, "cue", function(o, d, m)
    for _, w in ipairs(W) do
        if d == w.song and w.t0 == nil then
            w.t0, w.ev = now(), {}
            cur = w
        end
    end
    return d
end)

_G._t5 = mem:install_write_tap(FF95, FF95, "lsb", function(o, d, m) lsb = d; return d end)

-- the pulse OPENS: one FIRQ, taken. Record when.
_G._td = mem:install_write_tap(DAC, DAC, "dac", function(o, d, m)
    if cur == nil or d == 0 then return d end
    local t = now()
    if t - cur.t0 > WIN_S then cur = nil; return d end
    cur.ev[#cur.ev + 1] = { t = t, ctr = nil }
    return d
end)

-- the reload for the NEXT interrupt, written after the pulse in the same handler.
_G._t4 = mem:install_write_tap(FF94, FF94, "msb", function(o, d, m)
    if cur == nil then return d end
    local e = cur.ev[#cur.ev]
    if e and e.ctr == nil then e.ctr = (d % 16) * 256 + lsb end
    return d
end)

local function analyse(f, w, tick)
    if w.t0 == nil or not w.ev or #w.ev < 64 then
        f:write(string.format("   NO DATA (%d events)\n#\n", w.ev and #w.ev or 0))
        return nil
    end
    local late, n, worst, over_period, sum_p = {}, 0, 0, 0, 0
    for i = 2, #w.ev do
        local prev, e = w.ev[i - 1], w.ev[i]
        if prev.ctr and prev.ctr > 0 then
            local expected = prev.ctr * tick * 1e6      -- us
            local actual   = (e.t - prev.t) * 1e6       -- us
            local d = actual - expected
            n = n + 1
            late[n] = d
            sum_p = sum_p + expected
            if d > worst then worst = d end
            if d > expected then over_period = over_period + 1 end
        end
    end
    if n < 32 then f:write("   NO DATA (too few paired events)\n#\n"); return nil end
    table.sort(late)
    local function pct(q) return late[math.max(1, math.floor(n * q))] end
    local mean_p = sum_p / n
    f:write(string.format("   paired interrupts   %d\n", n))
    f:write(string.format("   mean expected period %.1f us\n", mean_p))
    f:write(string.format("   lateness  median    %+.1f us\n", pct(0.50)))
    f:write(string.format("             90th      %+.1f us\n", pct(0.90)))
    f:write(string.format("             99th      %+.1f us\n", pct(0.99)))
    f:write(string.format("             worst     %+.1f us   (= %.2f x the period)\n",
            worst, worst / math.max(1, mean_p)))
    f:write(string.format("   interrupts delayed by MORE THAN A WHOLE PERIOD:  %d  (%.1f%%)\n#\n",
            over_period, 100.0 * over_period / n))
    return { median = pct(0.50), worst = worst, mean_p = mean_p,
             over = 100.0 * over_period / n }
end

local done = false
_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if done then return end
    if fn == 300 then nk:post('LOADM"INTROSEQ"\n') end
    if fn == 1200 then nk:post('EXEC\n') end
    if fn < 9000 then return end
    done = true

    -- ★ FIT THE TIMER TICK ON THE QUIET WINDOW (see the header).
    local tick, a = nil, W[1]
    if a.t0 and a.ev and #a.ev > 64 then
        local r, m = {}, 0
        for i = 2, #a.ev do
            local prev, e = a.ev[i - 1], a.ev[i]
            if prev.ctr and prev.ctr > 0 then
                m = m + 1; r[m] = (e.t - prev.t) / prev.ctr
            end
        end
        table.sort(r)
        if m > 32 then tick = r[math.floor(m / 2)] end
    end

    local f = io.open(OUT, "w")
    f:write("# how late the music FIRQ is taken, against the period the player programmed\n")
    f:write("# into the GIME timer for it [msys_player.s:436-437].\n#\n")
    if tick == nil then
        f:write("# COULD NOT FIT THE TIMER TICK from the intro window — INCONCLUSIVE.\n")
        f:close(); manager.machine:exit(); return
    end
    f:write(string.format("# timer tick fitted on the INTRO window: %.4f us/count\n", tick * 1e6))
    f:write(string.format("# %.1f s per window, same run, same player.\n#\n", WIN_S))

    local res = {}
    for i, w in ipairs(W) do
        f:write(string.format("## %s\n", w.name))
        res[i] = analyse(f, w, tick)
    end

    if res[1] and res[2] then
        f:write("# ★ THE VERDICT LINE\n")
        if res[2].over > 5.0 or res[2].worst > res[2].mean_p then
            f:write("# The scene DELAYS the music interrupt past its own period. A FIRQ that\n")
            f:write("# arrives after the next one was due cannot produce the note it was for:\n")
            f:write("# that is the pulse train Jay is hearing. blit_core.s:120's orcc #$50 masks\n")
            f:write("# IRQ **and FIRQ**, and the intro -- which does no blitting -- is the control.\n")
        else
            f:write("# The scene does NOT delay the interrupt materially. The lead is DEAD and the\n")
            f:write("# defect is in the note data or the decode, not in interrupt latency.\n")
        end
    end
    f:close()
    manager.machine:exit()
end)
