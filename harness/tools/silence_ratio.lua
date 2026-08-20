-- silence_ratio.lua — P4.40: how many of the port's segments are SILENT?
--
-- ★★★ THE LEAD, FROM P4.39. Every measurable property of the port's audio matches the
-- oracle -- pitch (held notes exact within 8 us), duty (21.3 us vs 21.2), audible spectrum
-- (83.2% vs 85.2% above 2 kHz) -- and Jay still hears it as dirty. But the two captures
-- disagree on HOW MANY pulses there are:
--
--     pulses per second   port 606   oracle 474    (port +28%)
--
-- and the oracle's own capture implies roughly a fifth of ITS segments emit nothing at all.
-- If the port sounds where the oracle rests, every individual pulse can be perfect and the
-- result is still continuous buzz instead of articulated notes -- which is invisible to
-- every measurement made so far, because each one looks at pulses that ARE emitted.
--
-- ---------------------------------------------------------------------------
-- HOW BOTH POPULATIONS ARE COUNTED, WHICH IS THE WHOLE TRICK
-- ---------------------------------------------------------------------------
-- The handler decides per segment [msys_player.s]:
--
--     ldb  a,u          ; the amplitude from VTBL. VTBL+0 is ALWAYS zero
--     beq  fh_quiet     ; <- a SILENT segment: no DAC write at all
--     lda  #$FC / sta DAC ... stb DAC        ; <- a SOUNDING segment
--   fh_quiet
--     dec  msys_segn    ; ★ REACHED ON BOTH PATHS -- the sounding path falls into it
--
-- So `msys_segn`'s decrement counts EVERY segment and the DAC counts only the sounding
-- ones. Silent = the difference. ★ That the sounding path falls through into fh_quiet is
-- what makes one tap able to count both; it was checked in the source, not assumed.
--
-- ★★ AND A SEGMENT IS NOT AN INTERRUPT. `VS_DIV` sets a prescale (msys_divn) so only the
-- first interrupt of a segment reaches this decision at all; counting FIRQs would give a
-- different and wrong denominator.
local OUT   = os.getenv("P_OUT")  or "build/tmp/silence_ratio.log"
local IDX   = tonumber(os.getenv("P_IDX")  or "0EB7", 16)
local SEGN  = tonumber(os.getenv("P_SEGN") or "0EBC", 16)
local DAC   = 0xFF20
local WIN_S = tonumber(os.getenv("P_WIN")  or "6.0")

local mem = manager.machine.devices[":maincpu"].spaces["program"]
local nk  = manager.machine.natkeyboard
nk.in_use = true
local scr = manager.machine.screens:at(1)

local function now() return manager.machine.time:as_double() end

local armed, t0 = false, nil
local nseg, nsound = 0, 0
local runs, cur = {}, 0          -- lengths of consecutive-silent runs

_G._tc = mem:install_write_tap(IDX, IDX, "cue", function(o, d, m)
    if d == 7 and not armed then armed, t0 = true, now() end
    return d
end)

local sounded_this_seg = false

_G._td = mem:install_write_tap(DAC, DAC, "dac", function(o, d, m)
    if not armed or d == 0 then return d end
    if now() - t0 > WIN_S then return d end
    nsound = nsound + 1
    sounded_this_seg = true
    return d
end)

_G._ts = mem:install_write_tap(SEGN, SEGN, "segn", function(o, d, m)
    if not armed then return d end
    if now() - t0 > WIN_S then return d end
    nseg = nseg + 1
    if sounded_this_seg then
        if cur > 0 then runs[#runs + 1] = cur; cur = 0 end
    else
        cur = cur + 1
    end
    sounded_this_seg = false
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
    f:write("# the port's SILENT segments against its sounding ones, over s_Princess.\n")
    f:write("# segments counted at `dec msys_segn`, which BOTH paths reach; sounding\n")
    f:write("# counted at the DAC. Silent = the difference.\n#\n")
    if nseg < 64 then
        f:write(string.format("# only %d segments — INCONCLUSIVE.\n", nseg))
        f:close(); manager.machine:exit(); return
    end
    local silent = nseg - nsound
    f:write(string.format("  segments total     %d\n", nseg))
    f:write(string.format("  sounding           %d   (%.1f%%)\n", nsound, 100.0 * nsound / nseg))
    f:write(string.format("  ★ SILENT           %d   (%.1f%%)\n#\n", silent, 100.0 * silent / nseg))
    f:write("  ORACLE, implied by its own capture (P4.39): about 22% silent\n#\n")
    if #runs > 0 then
        local mx, s = 0, 0
        for i = 1, #runs do s = s + runs[i]; if runs[i] > mx then mx = runs[i] end end
        f:write(string.format("  silent RUNS        %d   mean %.1f segments, longest %d\n#\n",
                #runs, s / #runs, mx))
    else
        f:write("  silent RUNS        none — every segment sounded\n#\n")
    end
    local pct = 100.0 * silent / nseg
    if pct < 8.0 then
        f:write("# ★ THE PORT RESTS FAR LESS THAN THE ORACLE. It sounds where the oracle is\n")
        f:write("# silent, so the articulation between notes is filled in with tone. Every\n")
        f:write("# pulse can still be correct in pitch, width and spectrum -- and it is -- while\n")
        f:write("# the result is a continuous buzz. This is the lead worth pursuing.\n")
    elseif pct > 16.0 then
        f:write("# ★ THE PORT RESTS ABOUT AS MUCH AS THE ORACLE. The silence hypothesis is\n")
        f:write("# NOT supported and the +28% pulse rate has another explanation.\n")
    else
        f:write("# ★ BETWEEN THE TWO. Report the number; it neither confirms nor refutes.\n")
    end
    f:close()
    manager.machine:exit()
end)
