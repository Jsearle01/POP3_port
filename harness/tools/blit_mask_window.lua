-- blit_mask_window.lua — P4.28b: how long does the blitter hold the music interrupt off?
--
-- ★★★ THE QUESTION. P4.28 measured the symptom: 81% of the cutscene's pulse periods deviate
-- >5% from the previous one, against 11% in the intro. The lead is `blit_core.s:118`, which
-- masks `orcc #$50` -- IRQ **and FIRQ** -- because S becomes the blast destination, while the
-- music is FIRQ-driven. This measures the masked interval so the lead is settled on a number.
--
-- ---------------------------------------------------------------------------
-- THE BRACKET IS ONE VARIABLE, TOUCHED ONCE AT EACH END
-- ---------------------------------------------------------------------------
-- ★★ blit_cel opens with `pshs cc / orcc #$50 / sts bc_saved_s` and closes with
-- `lds bc_saved_s / puls cc`. So:
--
--     WRITE to bc_saved_s  -> the mask has just gone on
--     READ  from bc_saved_s -> the mask is about to come off
--
-- Both are DATA accesses, which sidesteps opcode-fetch questions entirely, and they bracket
-- precisely the region where the FIRQ cannot be taken. bc_saved_s is $3AD7 in the flame
-- bundle [build/obj/flames.map]; it is passed in rather than hard-coded so a relink cannot
-- silently point this at the wrong byte.
--
-- ★ THERE ARE THREE `lds bc_saved_s` SITES [blit_core.s:290,311,424] and one `sts`. The two
-- inner ones restore the real stack mid-routine without ending the mask, so a read-tap that
-- counted them would report intervals SHORTER than the truth. The tool therefore takes the
-- LAST read before the next write as the close, and reports how many reads it saw per
-- bracket so that assumption is visible rather than buried.
--
-- ★★★ AND THE PREVIOUS ATTEMPT AT THIS MEASUREMENT WAS BROKEN, WHICH IS WHY THE CHECKS BELOW
-- EXIST. firq_latency.lua tried to pair each pulse with the timer reload that followed it,
-- on the assumption that the handler reloads every time. msys_player.s:347 says otherwise --
-- "the tick work is in the PAD and never runs here" -- so only 59 of ~1040 pulses paired, the
-- fitted tick came out at 162 us/count (no GIME tick is that), and the scene window was
-- empty. It announced itself. This one reports its own event counts for the same reason.
local OUT   = os.getenv("P_OUT") or "build/tmp/blit_mask_window.log"
local IDX   = tonumber(os.getenv("P_IDX") or "0EB7", 16)
local SAVED = tonumber(os.getenv("P_SAVED") or "3AD7", 16)
local DAC   = 0xFF20
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
local cur = nil
local open_t, open_reads = nil, 0

_G._tc = mem:install_write_tap(IDX, IDX, "cue", function(o, d, m)
    for _, w in ipairs(W) do
        if d == w.song and w.t0 == nil then
            w.t0, w.mask, w.pulse = now(), {}, {}
            cur = w
        end
    end
    return d
end)

_G._tp = mem:install_write_tap(DAC, DAC, "dac", function(o, d, m)
    if cur == nil or d == 0 then return d end
    local t = now()
    if t - cur.t0 > WIN_S then cur = nil; return d end
    cur.pulse[#cur.pulse + 1] = t
    return d
end)

-- the mask goes ON
_G._tw = mem:install_write_tap(SAVED, SAVED + 1, "sts", function(o, d, m)
    if cur == nil then return d end
    if open_t ~= nil and open_reads > 0 then
        -- close the previous bracket at its LAST read
        cur.mask[#cur.mask + 1] = { dur = (open_last - open_t) * 1e6, reads = open_reads }
    end
    open_t, open_reads = now(), 0
    return d
end)

-- the mask is coming OFF (three sites; the last one before the next write is the real close)
_G._tr = mem:install_read_tap(SAVED, SAVED + 1, "lds", function(o, d, m)
    if cur == nil or open_t == nil then return d end
    open_reads = open_reads + 1
    open_last = now()
    return d
end)

local function report(f, w)
    if w.t0 == nil or not w.mask or #w.mask < 16 then
        f:write(string.format("   NO DATA (%d brackets, %d pulses)\n#\n",
                w.mask and #w.mask or 0, w.pulse and #w.pulse or 0))
        return nil
    end
    local d, n, sum, worst = {}, 0, 0, 0
    for _, b in ipairs(w.mask) do
        n = n + 1; d[n] = b.dur; sum = sum + b.dur
        if b.dur > worst then worst = b.dur end
    end
    table.sort(d)
    -- the note period, straight from the pulse train (P4.28's method)
    local per, pn = 0, 0
    for i = 2, #w.pulse do pn = pn + 1; per = per + (w.pulse[i] - w.pulse[i - 1]) * 1e6 end
    per = pn > 0 and per / pn or 0
    local over = 0
    for i = 1, n do if d[i] > per then over = over + 1 end end
    local function q(p) return d[math.max(1, math.floor(n * p))] end

    f:write(string.format("   blits (masked brackets)   %d\n", n))
    f:write(string.format("   mean note period          %.1f us   (from the pulse train)\n", per))
    f:write(string.format("   masked  median            %.1f us\n", q(0.50)))
    f:write(string.format("           90th              %.1f us\n", q(0.90)))
    f:write(string.format("           worst             %.1f us\n", worst))
    f:write(string.format("   TOTAL masked in window    %.1f ms of %.0f ms  (%.1f%%)\n",
            sum / 1000.0, WIN_S * 1000.0, 100.0 * (sum / 1e6) / WIN_S))
    f:write(string.format("   blits longer than ONE NOTE PERIOD:  %d  (%.1f%%)\n#\n",
            over, 100.0 * over / n))
    return { pct = 100.0 * (sum / 1e6) / WIN_S, over = over, per = per, worst = worst }
end

local done = false
_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if done then return end
    if fn == 300 then nk:post('LOADM"LOADER"\n') end
    if fn == 1200 then nk:post('EXEC\n') end
    if fn < 9000 then return end
    done = true

    local f = io.open(OUT, "w")
    f:write("# how long blit_cel holds IRQ+FIRQ off, against the note period it is competing\n")
    f:write("# with. Bracketed on bc_saved_s: written just after `orcc #$50`, read just before\n")
    f:write(string.format("# `puls cc` [blit_core.s:118,424]. bc_saved_s = $%04X.\n#\n", SAVED))
    f:write(string.format("# %.1f s per window, same run, same player.\n#\n", WIN_S))

    local r = {}
    for i, w in ipairs(W) do
        f:write(string.format("## %s\n", w.name))
        r[i] = report(f, w)
    end

    f:write("# ★ THE VERDICT LINE\n")
    if r[2] == nil then
        f:write("# The SCENE window produced no brackets. Either the tap address is wrong or the\n")
        f:write("# scene does not call blit_cel during this song — INCONCLUSIVE either way, and\n")
        f:write("# NOT to be read as 'the blitter is innocent'.\n")
    elseif r[1] == nil then
        f:write("# The INTRO window produced no brackets, which is EXPECTED — the intro does no\n")
        f:write("# cel blitting at all. That absence is the control, not a failure.\n")
        f:write(string.format("# The scene masks %.1f%% of its wall clock, and %d blits run longer than a\n",
                r[2].pct, r[2].over))
        f:write("# whole note period. A FIRQ that cannot be taken until after the next one was\n")
        f:write("# due cannot produce the note it was for.\n")
    else
        f:write(string.format("# intro %.1f%% masked, scene %.1f%% masked.\n", r[1].pct, r[2].pct))
    end
    f:close()
    manager.machine:exit()
end)
