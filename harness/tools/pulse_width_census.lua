-- pulse_width_census.lua — P4.38: is the port's DUTY right, or only its PITCH?
--
-- ★★★ THE UNTESTED HALF OF A DOCUMENTED CLAIM. msys_player.s:59-64 records, under
-- CLAUDE.md §2I, three of the oracle's mechanisms as deliberately not ported:
--
--     "MADJLP subtracts the pulse width from the delay so the period is independent of the
--      amplitude, MDLOOP counts the period out in 5-cycle steps, MVDIT counts the width...
--      They are not ported and they are not missed: THE OUTPUT IS THE SAME PITCH AND THE
--      SAME DUTY."
--
-- P4.37 produced evidence FOR the pitch half: 44% of blit-free note periods are identical to
-- the one before them inside 8 us -- about 8 cents on a 1743 us period, under the 12 cents
-- Jay ruled inaudible at P4.6. Held notes are exact.
--
-- ★★ THE DUTY HALF HAS NEVER BEEN CHECKED, AND "FUZZY" IS A TIMBRE WORD. On a 1-bit
-- speaker the duty IS the timbre: the pulse's WIDTH carries the amplitude, and the port
-- renders it as a spin -- `lda #$FC / sta DAC / decb / bne / stb DAC` -- so the width is
-- B x 5 cycles, quantised to whatever values VTBL holds.
--
-- ---------------------------------------------------------------------------
-- WHAT IS MEASURED
-- ---------------------------------------------------------------------------
-- Every DAC write at $FF20 is either the pulse OPENING (data non-zero, $FC full scale) or
-- CLOSING (data zero). The interval between an open and its close is the rendered width, in
-- microseconds, straight off the bus -- no model of the player involved.
--
--   * the DISTINCT widths and how often each occurs -- the port's whole timbre alphabet
--   * against the ORACLE's measured range, 7.8-22.5 us [P4.4, its speaker at $C030]
--
-- ★ A port whose widths are FEWER, COARSER or in the WRONG RANGE has a different duty from
-- the oracle whatever its pitch does, and that is what a listener calls fuzzy or thin.
-- ★★ Nothing here assumes an answer: the census prints the alphabet it finds.
local OUT   = os.getenv("P_OUT") or "build/tmp/pulse_width_census.log"
local IDX   = tonumber(os.getenv("P_IDX") or "0EB7", 16)
local DAC   = 0xFF20
local WIN_S = tonumber(os.getenv("P_WIN") or "6.0")

local mem = manager.machine.devices[":maincpu"].spaces["program"]
local nk  = manager.machine.natkeyboard
nk.in_use = true
local scr = manager.machine.screens:at(1)

local function now() return manager.machine.time:as_double() end

local armed, t0 = false, nil
local open_t = nil
local widths, nw = {}, 0
local hist = {}                    -- rounded us -> count
local nopen, nclose = 0, 0

_G._tc = mem:install_write_tap(IDX, IDX, "cue", function(o, d, m)
    if d == 7 and not armed then armed, t0 = true, now() end
    return d
end)

_G._td = mem:install_write_tap(DAC, DAC, "dac", function(o, d, m)
    if not armed then return d end
    local t = now()
    if t - t0 > WIN_S then return d end
    if d ~= 0 then
        open_t = t; nopen = nopen + 1
    elseif open_t ~= nil then
        nclose = nclose + 1
        local w = (t - open_t) * 1e6
        nw = nw + 1; widths[nw] = w
        local k = math.floor(w * 10 + 0.5) / 10      -- 0.1 us resolution
        hist[k] = (hist[k] or 0) + 1
        open_t = nil
    end
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
    f:write("# the port's rendered pulse WIDTHS, straight off the DAC at $FF20.\n")
    f:write("# open = a non-zero write, close = the zero that follows it. The interval is\n")
    f:write("# the duty, which on a 1-bit speaker is the timbre.\n#\n")
    if nw < 32 then
        f:write(string.format("# only %d pulses (%d opens, %d closes) — INCONCLUSIVE.\n",
                nw, nopen, nclose))
        f:close(); manager.machine:exit(); return
    end

    local keys = {}
    for k in pairs(hist) do keys[#keys + 1] = k end
    table.sort(keys)
    local peak = 0
    for _, k in ipairs(keys) do if hist[k] > peak then peak = hist[k] end end

    local s, mn, mx = 0, widths[1], widths[1]
    for i = 1, nw do
        s = s + widths[i]
        if widths[i] < mn then mn = widths[i] end
        if widths[i] > mx then mx = widths[i] end
    end
    f:write(string.format("  pulses            %d   (opens %d, closes %d)\n", nw, nopen, nclose))
    f:write(string.format("  distinct widths   %d\n", #keys))
    f:write(string.format("  range             %.1f .. %.1f us   (mean %.1f)\n#\n", mn, mx, s / nw))
    f:write("  ORACLE, measured at P4.4 off its speaker: 7.8 .. 22.5 us\n#\n")
    f:write("# --- the alphabet the port actually emits ---------------------\n")
    for _, k in ipairs(keys) do
        f:write(string.format("  %6.1f us %-40s %5d\n", k,
                string.rep("#", math.floor(40 * hist[k] / peak)), hist[k]))
    end
    f:write("#\n# READ IT LIKE THIS: the oracle's speaker is a 1-bit toggle whose width the\n")
    f:write("# player varies continuously; the port's is a spin of B x 5 cycles off VTBL, so\n")
    f:write("# its alphabet is however many entries VTBL holds. FEWER distinct widths, or a\n")
    f:write("# range that does not overlap the oracle's, is a different timbre whatever the\n")
    f:write("# pitch does -- and the pitch is already known good (P4.37).\n")
    f:close()
    manager.machine:exit()
end)
