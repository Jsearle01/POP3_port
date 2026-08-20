-- pulse_gap_census.lua — P4.33: what is inside the music's MILLISECOND gaps?
--
-- ★★★ THE QUESTION P4.31 LEFT OPEN, AND IT IS DELIBERATELY HYPOTHESIS-FREE. Re-expressing
-- the residual jitter in absolute microseconds split it into two populations:
--
--     within 200 us (one masked blit row)   1153  (67.1%)
--     over 1000 us                           144  (8.4%)   <- up to 6.7 ms
--
-- The first is the blitter's row window and the narrower mask addresses it. **The second
-- cannot be a row-level mask** and is not yet identified. 144 events in 3.0 s is ~48/s,
-- near the frame rate, which is a LEAD and not a diagnosis -- and this session has cost
-- two reverts from exactly that kind of confident inference (P4.25b-2's consumed animation
-- step, P4.26's `vm_due` no-op).
--
-- ★★ SO THIS COUNTS RATHER THAN GUESSES. For every gap over 1 ms it records what else the
-- machine did inside it, from four independent state taps, and prints the census. Whatever
-- correlates is the lead worth pursuing; whatever does not is eliminated.
--
--   BLIT   a write to bc_saved_s -- one per blit_cel entry
--   SWAP   a write to HAL_gfx_swaps -- one per page flip
--   VBL    a write to hal_frame_lo -- the VBL IRQ handler's own increment [time.s:135],
--          so this says whether the FRAME interrupt was being taken during the gap
--   STATE  msys_state at the gap's end -- 1 = the player is in its PAD interrupt, which is
--          where msys_player.s:347 says the per-tick decode work happens
--
-- ★ ALREADY ELIMINATED BEFORE WRITING THIS, so the census does not have to: HAL_gfx_swap's
-- VBL wait does NOT mask -- `HAL_time_vbl_wait` spins on hal_frame_lo with interrupts on
-- [time.s], testing CC.I only to pick its synthetic fallback. A masked frame-long wait was
-- the obvious candidate and it is not there.
--
-- ★★ EVERY ADDRESS IS PASSED IN. bc_saved_s moved $3AD7 -> $3ADB when six bytes of code
-- were added to blit_core during P4.29, and the tool that had it hard-coded reported
-- "0 brackets" -- which reads exactly like "the blitter never ran".
local OUT   = os.getenv("P_OUT") or "build/tmp/pulse_gap_census.log"
local IDX   = tonumber(os.getenv("P_IDX")   or "0EB7", 16)
local DAC   = 0xFF20
local SAVED = tonumber(os.getenv("P_SAVED") or "3ADB", 16)
local SWAPS = tonumber(os.getenv("P_SWAPS") or "7B91", 16)
local FRAME = tonumber(os.getenv("P_FRAME") or "0011", 16)
local STATE = tonumber(os.getenv("P_STATE") or "0EBB", 16)
local WIN_S = tonumber(os.getenv("P_WIN")   or "3.0")
local BIG   = tonumber(os.getenv("P_BIG")   or "1000")   -- us

local mem = manager.machine.devices[":maincpu"].spaces["program"]
local nk  = manager.machine.natkeyboard
nk.in_use = true
local scr = manager.machine.screens:at(1)

local function now() return manager.machine.time:as_double() end

local armed, t0 = false, nil
local last_pulse = nil
local nblit, nswap, nvbl = 0, 0, 0
local gaps, ng = {}, 0
local small_blits, small_n = 0, 0

_G._tc = mem:install_write_tap(IDX, IDX, "cue", function(o, d, m)
    if d == 7 and not armed then armed, t0 = true, now() end
    return d
end)

_G._tb = mem:install_write_tap(SAVED, SAVED, "blit", function(o, d, m)
    if armed then nblit = nblit + 1 end; return d end)
_G._tw = mem:install_write_tap(SWAPS, SWAPS, "swap", function(o, d, m)
    if armed then nswap = nswap + 1 end; return d end)
_G._tf = mem:install_write_tap(FRAME, FRAME, "vbl", function(o, d, m)
    if armed then nvbl = nvbl + 1 end; return d end)

_G._td = mem:install_write_tap(DAC, DAC, "dac", function(o, d, m)
    if not armed or d == 0 then return d end
    local t = now()
    if t - t0 > WIN_S then return d end
    if last_pulse ~= nil then
        local us = (t - last_pulse) * 1e6
        if us > BIG then
            if ng < 200 then
                ng = ng + 1
                gaps[ng] = { us = us, blit = nblit, swap = nswap, vbl = nvbl,
                             st = mem:read_u8(STATE) }
            end
        else
            small_n = small_n + 1
            small_blits = small_blits + nblit
        end
    end
    last_pulse = t
    nblit, nswap, nvbl = 0, 0, 0
    return d
end)

local done = false
_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if done then return end
    if fn == 300 then nk:post('LOADM"INTROSEQ"\n') end
    if fn == 1200 then nk:post('EXEC\n') end
    if fn < 9200 then return end
    done = true

    local f = io.open(OUT, "w")
    f:write("# what is inside the music's gaps. One line per gap over " .. BIG .. " us,\n")
    f:write("# counting what the machine did between the two pulses that bound it.\n#\n")
    if ng == 0 then
        f:write("# NO GAPS OVER THE THRESHOLD -- either the window missed the song or the\n")
        f:write("# taps are wrong. INCONCLUSIVE, not 'the problem is gone'.\n")
        f:close(); manager.machine:exit(); return
    end

    local sb, ss, sv, npad = 0, 0, 0, 0
    local worst = gaps[1]
    for i = 1, ng do
        local g = gaps[i]
        sb = sb + g.blit; ss = ss + g.swap; sv = sv + g.vbl
        if g.st == 1 then npad = npad + 1 end
        if g.us > worst.us then worst = g end
    end

    f:write(string.format("  gaps over %d us      %d\n", BIG, ng))
    f:write(string.format("  worst gap           %.0f us  (blits %d, swaps %d, vbl %d, state %d)\n",
            worst.us, worst.blit, worst.swap, worst.vbl, worst.st))
    f:write("#\n  PER BIG GAP, on average:\n")
    f:write(string.format("    blits inside      %.2f\n", sb / ng))
    f:write(string.format("    swaps inside      %.2f\n", ss / ng))
    f:write(string.format("    VBL ticks inside  %.2f\n", sv / ng))
    f:write(string.format("    player in PAD     %d of %d  (%.0f%%)\n", npad, ng, 100.0 * npad / ng))
    if small_n > 0 then
        f:write(string.format("#\n  for CONTRAST, the ordinary gaps (<= %d us, n=%d):\n", BIG, small_n))
        f:write(string.format("    blits inside      %.2f  (average)\n", small_blits / small_n))
    end
    f:write("#\n# --- the twenty widest, in order -------------------------------\n")
    table.sort(gaps, function(a, b) return a.us > b.us end)
    for i = 1, math.min(20, ng) do
        local g = gaps[i]
        f:write(string.format("  %8.0f us   blits %3d   swaps %2d   vbl %2d   state %d\n",
                g.us, g.blit, g.swap, g.vbl, g.st))
    end
    f:write("#\n# READ IT LIKE THIS: a marker that appears in the big gaps at a much higher\n")
    f:write("# rate than in the ordinary ones is the lead. One that appears at the same rate\n")
    f:write("# is eliminated. Nothing here is a diagnosis on its own.\n")
    f:close()
    manager.machine:exit()
end)
