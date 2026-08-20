-- timer_trace.lua — P4.22 §1: attribute the long segments by watching the timer itself.
--
-- ★★★ BOUNDED IS NOT ATTRIBUTED. P4.21 established that 23 segments run ~154 ms and that
-- 154 ms is what a TINS=1 count would produce if it were clocked at TINS=0. That is
-- arithmetic agreeing with a measurement, which is a HYPOTHESIS, not a cause: the same
-- 154 ms could equally be a stalled FIRQ, a missed interrupt with an auto-reloading timer,
-- or a segment that is genuinely that long in the data.
--
-- ★★ SO WATCH WHAT WAS PROGRAMMED, NOT WHAT CAME OUT. Every write to $FF91 (INIT1, whose
-- bit 5 is TINS) and to $FF94/$FF95 (the 12-bit timer) is recorded with a timestamp, as is
-- every read of $FF93 (one per FIRQ entry) and every write to $FF20 (the pulse). A long
-- gap then reads back as: what clock was selected, what count was loaded, and whether the
-- FIRQ kept firing through it.
--
-- ★ THE FOUR SPLITS THE DISPATCH ASKS FOR ALL FALL OUT OF ONE RUN:
--     fixed vs variable position   -- run it twice and diff the gap list
--     FIRQ stall vs long segment   -- did $FF93 reads continue during the gap?
--     VBL-correlated               -- was the gap adjacent to a VBORD dispatch?
--     data-driven                  -- what count/clock was in force?
--
--   P_OUT    the event log
--   P_GAPUS  a gap this long (us) or more is interesting (default 20000)
local OUT    = os.getenv("P_OUT") or "build/tmp/timer_trace.log"
local GAPUS  = tonumber(os.getenv("P_GAPUS") or "20000")
local ENTRY  = tonumber(os.getenv("P_ENTRY") or "2000", 16)
local SONG   = tonumber(os.getenv("P_SONG") or "1")

local mem = manager.machine.devices[":maincpu"].spaces["program"]
local nk  = manager.machine.natkeyboard
nk.in_use = true
local scr = manager.machine.screens:at(1)

local function now()
    local t = manager.machine.time
    return t.seconds + t.attoseconds / 1.0e18
end

-- rolling state: what the player last programmed
local ff91, hi, lo = -1, -1, -1
local firqs, vbls = 0, 0
local last_pulse = nil
local gaps, ng = {}, 0
local ev, nev = {}, 0          -- a short ring of recent programming events

local function note(kind, val)
    nev = nev + 1
    ev[(nev - 1) % 16 + 1] = string.format("%s=%s@%.4f", kind, val, now())
end

_G._t91 = mem:install_write_tap(0xFF91, 0xFF91, "i1", function(o, d, m)
    ff91 = d; note("FF91", string.format("$%02X", d)); return d
end)
_G._t94 = mem:install_write_tap(0xFF94, 0xFF94, "th", function(o, d, m)
    hi = d; note("FF94", string.format("$%02X", d)); return d
end)
_G._t95 = mem:install_write_tap(0xFF95, 0xFF95, "tl", function(o, d, m)
    lo = d; note("FF95", string.format("$%02X", d)); return d
end)
_G._t93 = mem:install_read_tap(0xFF93, 0xFF93, "ak", function(o, d, m)
    firqs = firqs + 1
    if (d & 0x08) ~= 0 then vbls = vbls + 1 end
    return d
end)

-- the pulse marks a sounding segment; the interval between pulses is the segment period
_G._t20 = mem:install_write_tap(0xFF20, 0xFF20, "da", function(o, d, m)
    if d == 0 then return d end
    local t = now()
    if last_pulse then
        local gap = (t - last_pulse) * 1e6
        if gap >= GAPUS then
            ng = ng + 1
            local count = (hi & 0x0F) * 256 + lo
            local tins  = (ff91 & 0x20) ~= 0 and 1 or 0
            local usTick = tins == 1 and 0.279365 or 63.695
            gaps[ng] = {
                idx = ng, at = t, gap = gap,
                ff91 = ff91, count = count, tins = tins,
                pred = count * usTick,
                firqs = firqs, vbls = vbls,
                recent = table.concat(ev, " ", 1, math.min(nev, 16)),
            }
        end
    end
    last_pulse = t
    firqs, vbls = 0, 0
    return d
end)

local state, t0, done = "boot", nil, false
_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if done then return end
    if state == "boot" then
        if fn >= 300 then nk:post('LOADM"INTERP"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if fn > t0 + 900 then
            mem:write_u8(ENTRY + 10, 0)          -- probe_mode 0: one interpret pass
            mem:write_u8(ENTRY + 11, SONG)
            nk:post('EXEC\n'); state = "run"
        end
        return
    end
    if fn < 3400 then return end
    done = true
    local f = io.open(OUT, "w")
    f:write(string.format("# P4.22 — long segments, attributed. song %d, gaps >= %.0f us\n",
                          SONG, GAPUS))
    f:write("#\n# For each gap: what clock and count were IN FORCE, what that count predicts\n")
    f:write("# at that clock, and whether the FIRQ kept firing through the gap.\n#\n")
    f:write(string.format("# %-4s %10s %6s %7s %11s %7s %6s\n",
                          "n", "gap_us", "TINS", "count", "predict_us", "FIRQs", "VBLs"))
    for i = 1, ng do
        local g = gaps[i]
        f:write(string.format("  %-4d %10.1f %6d %7d %11.1f %7d %6d\n",
                              g.idx, g.gap, g.tins, g.count, g.pred, g.firqs, g.vbls))
    end
    f:write(string.format("\n# %d gaps >= %.0f us\n", ng, GAPUS))
    if ng > 0 then
        f:write("# recent register writes before the FIRST gap:\n#   "
                .. gaps[1].recent .. "\n")
        f:write("# recent register writes before the LAST gap:\n#   "
                .. gaps[ng].recent .. "\n")
    end
    f:close()
    manager.machine:exit()
end)
