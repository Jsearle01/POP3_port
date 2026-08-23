-- beat_timeline.lua — P5.16c: where every frame of the intro actually goes.
--
-- Jay, gating P5.16b: "there appears to a longer thsn neccessary delay between prolog2 and
-- the silent title." There is NO DISK anywhere near that transition any more — the trace
-- shows the last read ending at frame 4677 and nothing after it — so whatever he is seeing
-- is the program, not the drive, and the beat table is the place to look.
--
-- ★ THE POINT IS THE BOUNDARY, NOT THE BEAT. probe_status carries beat+2 and probe_phase
-- carries 0=pre / 1=caption up / 2=cleared, and intro_seq.s writes BOTH at the moments that
-- define a beat's shape. Write taps on the two of them therefore reconstruct the whole
-- timeline exactly -- including the gap between a beat's hold ending and the next beat's
-- picture arriving, which is the thing under question and which no single counter shows.
--
-- Taps, not sampling: a phase that changes and changes back inside one frame is invisible
-- to a per-frame read [intro_load_trace.lua's own note]. Both handles held in _G or they
-- are garbage-collected and silently stop firing [mame-idioms-coco3-port.md].

local OUT   = os.getenv("P_OUT") or "build/tmp/beat_timeline.txt"
local HZ    = 59.92
local STATUS, BEAT, PHASE = 0x2003, 0x2004, 0x2005
local SWAPS = tonumber(os.getenv("P_SWAPS") or "0")
local RUNLEN = tonumber(os.getenv("P_LEN") or "12000")

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local out = io.open(OUT, "w")
local frame = 0
local ev = {}
local function say(s) out:write(s .. "\n"); out:flush() end
local function rd(a) return mem:read_u8(a) end

-- ★★ THE DAC, BECAUSE THE QUESTION IS "HOW LONG AFTER THE SONG ENDS" (P5.16c). Jay:
-- "prolog2 seems to be displayed for a long time after the song ends. longer than needed."
-- BEAT_HOLD is a FIXED FRAME COUNT taken from the oracle's frames, but the port's song is
-- whatever msys_player actually renders — so if the rendition is shorter than the hold, the
-- beat sits silent for the difference and no counter in the program knows. msys_player
-- drives $FF20 from a FIRQ [msys_player.s:144 `DAC equ $FF20`], so the LAST write to it
-- inside a beat is when that beat's music stopped, to the frame.
--
-- ★★★ AND IT IS THE VALUE CHANGING THAT IS SOUND, NOT THE WRITE HAPPENING. Measured at
-- P5.16c: the DAC is written to the last frame of every beat, which reads as "the music
-- never stops" and is wrong. msys_player's FIRQ keeps running once the song's data is
-- exhausted and keeps storing the SAME level — a steady DC level is silence, and a tap that
-- counts writes cannot tell it from a note. So the last frame at which the value DIFFERS
-- from the previous one is where the sound actually stopped.
local DAC = 0xFF20
local dac_last, dac_first, dac_prev = {}, {}, -1
_G._td = mem:install_write_tap(DAC, DAC, "dac", function(off, data, mask)
    local v = data & 0xFF
    if v ~= dac_prev then
        dac_prev = v
        dac_last[#ev] = frame
        if dac_first[#ev] == nil then dac_first[#ev] = frame end
    end
end)

_G._ts = mem:install_write_tap(STATUS, STATUS, "st", function(off, data, mask)
    ev[#ev + 1] = { f = frame, what = "status", v = data & 0xFF }
end)
_G._tp = mem:install_write_tap(PHASE, PHASE, "ph", function(off, data, mask)
    ev[#ev + 1] = { f = frame, what = "phase", v = data & 0xFF }
end)

local NAME = { [2] = "1 splash/presents", [3] = "2 byline", [4] = "3 title",
               [5] = "4 prolog1 (+scene)", [6] = "5 prolog2", [7] = "6 silent title",
               [8] = "done" }
local PH = { [0] = "pre", [1] = "up", [2] = "cleared" }

_G._n = emu.add_machine_frame_notifier(function()
    frame = frame + 1
    if frame == 300 then
        manager.machine.natkeyboard:post('LOADM"LOADER"\n')
    elseif frame == 801 then
        manager.machine.natkeyboard:post("EXEC\n")
    elseif frame == RUNLEN then
        say("# beat_timeline — every probe_status / probe_phase write, with the gap it opened")
        say("#")
        say("#   frame     s   d(s)  event")
        local prev = nil
        for _, e in ipairs(ev) do
            local label
            if e.what == "status" then
                label = string.format("STATUS %d  = beat %s", e.v, NAME[e.v] or "?")
            else
                label = string.format("  phase %d = %s", e.v, PH[e.v] or "?")
            end
            say(string.format("  %6d %6.2f %6.2f  %s", e.f, e.f / HZ,
                              prev and (e.f - prev) / HZ or 0, label))
            prev = e.f
        end
        say("")
        say("# ★ THE BOUNDARIES, beat by beat — from a beat's STATUS write to the next one's.")
        local last_st, last_f, last_i = nil, nil, nil
        for i, e in ipairs(ev) do
            if e.what == "status" then
                if last_st then
                    -- the last DAC write anywhere inside this beat's span of events
                    local lastdac, firstdac = nil, nil
                    for k = last_i, i - 1 do
                        if dac_first[k] and not firstdac then firstdac = dac_first[k] end
                        if dac_last[k] then lastdac = dac_last[k] end
                    end
                    local tail = lastdac and string.format(
                        "music %6.2f..%6.2f s, then %6.2f s SILENT",
                        (firstdac - last_f) / HZ, (lastdac - last_f) / HZ,
                        (e.f - lastdac) / HZ) or "no music in this beat"
                    say(string.format("    beat %-20s %6d frames %6.2f s | %s",
                                      NAME[last_st] or "?", e.f - last_f,
                                      (e.f - last_f) / HZ, tail))
                end
                last_st, last_f, last_i = e.v, e.f, i
            end
        end
        out:close()
        manager.machine:exit()
    end
end)
