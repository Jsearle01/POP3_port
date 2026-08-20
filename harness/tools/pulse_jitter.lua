-- pulse_jitter.lua — P4.28 recon: is the cutscene's music PHYSICALLY jittered, and by how much?
--
-- ★★★ JAY, ON THE CUTSCENE: "terribly low quality, sounds muffled and indistinct not like the
-- oracle … the first song played after the scene displays is the worst sounding". The intro's
-- songs gated clean at P4.19 on his ear. Same player, same song page, same music SET -- and
-- MASTER.S:112-126 was checked, `s_Princess = 7` IS Set 1, so it is not the wrong data.
--
-- ★★ THE STANDING LEAD: `blit_core.s:120` masks `orcc #$50` -- IRQ **and FIRQ** -- because S
-- becomes the blast destination. The music is FIRQ-driven. The intro does NO blitting; the
-- cutscene blits two characters and two torches every frame. So every blit silences the
-- interrupt that makes the sound.
--
-- ★ BUT THE LEAD HAS A HOLE, AND THIS TOOL EXISTS TO SETTLE IT RATHER THAN TO CONFIRM IT.
-- s_Princess's beat is a PINNED-ONLY HOLD where ch_anymove skips the peel -- the cheapest
-- drawing in the scene. If masking were the whole story the worst audio would land on the
-- BUSIEST beat, not the quietest. So this measures the SYMPTOM directly and compares two
-- windows; it does not assume the cause.
--
-- ---------------------------------------------------------------------------
-- WHAT IS MEASURED, AND WHY IT IS THE THING JAY HEARS
-- ---------------------------------------------------------------------------
-- msys_player.s: "SEGMENT — one FIRQ. One full square-wave period of the note. The pulse
-- fires here." The handler does `sta DAC` (the pulse OPENS, A = width), spins B times, then
-- `stb DAC` with B=0 (the pulse CLOSES). $FF20 is the DAC.
--
--   * the interval between consecutive pulse-OPENS is the note's PERIOD
--   * a FIRQ that could not be taken on time stretches exactly that interval
--   * within a held note the period is constant, so ANY variation is delay
--
-- So the metric is the frame-to-frame variation of the period, which is pitch/timbre
-- distortion in the most literal available sense.
--
-- ★★ 6809 READ-TAPS WORK on this target [mame-idioms-coco3-port.md §10] -- the false-0
-- opcode-fetch bypass is the 6502 oracle's problem, not the coco3's. This uses a WRITE tap
-- regardless, because a write is what the pulse IS.
--
-- ---------------------------------------------------------------------------
-- TWO WINDOWS, ARMED ON THE CUE ITSELF
-- ---------------------------------------------------------------------------
-- `msys_play` writes the song id to msys_index ($0EB7) as its first act -- P4.23's tap, and
-- the one instrument in this area that has never been wrong. Window A opens on the INTRO's
-- s_Presents (id 1), window B on the CUTSCENE's s_Princess (id 7). Same player, same build,
-- same run: the only difference between the two windows is what else the machine is doing.
local OUT    = os.getenv("P_OUT") or "build/tmp/pulse_jitter.log"
local IDX    = tonumber(os.getenv("P_IDX") or "0EB7", 16)
local DAC    = 0xFF20
local WIN_S  = tonumber(os.getenv("P_WIN") or "3.0")     -- seconds of song per window

local mem = manager.machine.devices[":maincpu"].spaces["program"]
local nk  = manager.machine.natkeyboard
nk.in_use = true
local scr = manager.machine.screens:at(1)

local function now() return manager.machine.time:as_double() end

-- window = { name, song, t0, opens = {times}, active }
local W = {
    { name = "INTRO  s_Presents", song = 1 },
    { name = "SCENE  s_Princess", song = 7 },
}
local cur = nil

_G._tc = mem:install_write_tap(IDX, IDX, "cue", function(o, d, m)
    for _, w in ipairs(W) do
        if d == w.song and w.t0 == nil then
            w.t0, w.opens = now(), {}
            cur = w
        end
    end
    return d
end)

_G._td = mem:install_write_tap(DAC, DAC, "dac", function(o, d, m)
    if cur == nil then return d end
    if d == 0 then return d end                 -- the pulse CLOSING, not opening
    local t = now()
    if t - cur.t0 > WIN_S then cur = nil; return d end
    cur.opens[#cur.opens + 1] = t
    return d
end)

local done = false
_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if done then return end
    if fn == 300 then nk:post('LOADM"INTROSEQ"\n') end
    if fn == 1200 then nk:post('EXEC\n') end
    if fn < 9000 then return end
    done = true

    local f = io.open(OUT, "w")
    f:write("# the DAC pulse train, measured. One FIRQ = one square-wave period of the note\n")
    f:write("# [msys_player.s], so the interval between pulse-OPENS is the period itself and\n")
    f:write("# a FIRQ that could not be taken on time stretches exactly that interval.\n#\n")
    f:write(string.format("# %.1f s window per song, same run, same player, same song page.\n#\n", WIN_S))

    for _, w in ipairs(W) do
        f:write(string.format("## %s\n", w.name))
        if w.t0 == nil or #w.opens < 32 then
            f:write(string.format("   NO DATA (%d pulses) — the song did not play in this run.\n#\n",
                    w.opens and #w.opens or 0))
        else
            -- periods, in microseconds
            local p, n = {}, 0
            for i = 2, #w.opens do
                n = n + 1
                p[n] = (w.opens[i] - w.opens[i - 1]) * 1e6
            end
            -- ★ COMPARE EACH PERIOD TO THE ONE BEFORE IT. Within a held note the period is
            -- constant, so a big step is a LATE FIRQ rather than a new note. A note change is
            -- a single step; delay is many. Both are counted and reported, unsmoothed.
            local jits, worst, big = 0, 0, 0
            for i = 2, n do
                local a, b = p[i - 1], p[i]
                local dev = math.abs(b - a) / a * 100.0
                if dev > worst then worst = dev end
                if dev > 5.0 then jits = jits + 1 end
                if dev > 25.0 then big = big + 1 end
            end
            local sum = 0
            for i = 1, n do sum = sum + p[i] end
            f:write(string.format("   pulses            %d\n", #w.opens))
            f:write(string.format("   mean period       %.1f us  (%.0f Hz)\n",
                    sum / n, 1e6 / (sum / n)))
            f:write(string.format("   periods > 5%% off the previous    %d of %d  (%.1f%%)\n",
                    jits, n - 1, 100.0 * jits / math.max(1, n - 1)))
            f:write(string.format("   periods > 25%% off the previous   %d  (%.1f%%)\n",
                    big, 100.0 * big / math.max(1, n - 1)))
            f:write(string.format("   worst single deviation           %.1f%%\n", worst))

-- ★★★ AND THE SAME DEVIATIONS IN ABSOLUTE MICROSECONDS, WHICH IS WHAT DISTINGUISHES THE
-- REMAINING CAUSES. After P4.29 the blitter masks for ONE ROW at a time -- roughly 90-290
-- cycles, so 50-160 us at 1.78 MHz -- against a note period near 1743 us. If the residual
-- deviations are in that band, the row window is the whole story and narrowing it further
-- is the lever. If they are HUNDREDS of microseconds or more, something else is holding the
-- interrupt off and narrowing the blit window would not touch it. A percentage cannot tell
-- those apart; microseconds can.
            local abs = {}
            for i = 2, n do abs[#abs + 1] = math.abs(p[i] - p[i - 1]) end
            table.sort(abs)
            local function q(x) return abs[math.max(1, math.floor(#abs * x))] end
            f:write(string.format("   |delta| median  %8.1f us\n", q(0.50)))
            f:write(string.format("            90th    %8.1f us\n", q(0.90)))
            f:write(string.format("            99th    %8.1f us\n", q(0.99)))
            f:write(string.format("            max     %8.1f us\n", abs[#abs]))
            local band, big = 0, 0
            for i = 1, #abs do
                if abs[i] <= 200.0 then band = band + 1 end
                if abs[i] > 1000.0 then big = big + 1 end
            end
            f:write(string.format("   within 200 us (one masked row)   %d  (%.1f%%)\n",
                    band, 100.0 * band / #abs))
            f:write(string.format("   over 1000 us (NOT the blitter)   %d  (%.1f%%)\n#\n",
                    big, 100.0 * big / #abs))
        end
    end

    local a, b = W[1], W[2]
    if a.t0 and b.t0 and #a.opens > 32 and #b.opens > 32 then
        f:write("# ★ THE COMPARISON. Both windows are the same player in the same run; the only\n")
        f:write("# difference is what else the machine is doing. If the scene's numbers are much\n")
        f:write("# worse, the music is being DELAYED by the scene, and blit_core's orcc #$50 is\n")
        f:write("# the first place to look. If they are similar, the lead is dead and the defect\n")
        f:write("# is in the note data or the decode, not in interrupt latency.\n")
    end
    f:close()
    manager.machine:exit()
end)
