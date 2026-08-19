-- interp_live.lua — P4.19: drive DECB to LOADM"INTERP" + EXEC, and record what the
-- INTERPRETED player actually emitted.
--
-- ★★★ WHY A TAP AND NOT A LIVENESS CHECK. P4.5 shipped two pulse-width defects in a row
-- and nothing in the harness could see either, because a wrong pulse consumes the same
-- rows and tears down identically. This player is a much bigger surface — a grammar walk,
-- an envelope, a harmonic pattern, two voices and a timer table — and "it played and
-- stopped" would distinguish almost none of its failure modes.
--
-- ★★ SO THIS DUMPS THE (pulse, rest) PAIRS, in the SAME format as the oracle captures in
-- build/tmp/boot/. That makes the port's output diffable against BOTH the decoded model
-- AND the oracle's own trace by one tool (msys_decode.py --compare), which is the only
-- way to tell a decode bug from a timer bug from a handler bug.
--
-- ★ The launch is the proven pattern [mame-idioms-coco3-port.md §1/§2]: no autoboot
-- command, natkeyboard:post from a frame notifier once boot has settled, and 900 frames
-- after LOADM before EXEC because LOADM only returns to the prompt when the read is done.
--
--   P_OUT     the (pulse, rest) dump; also the PASS/FAIL report on P_REPORT
--   P_REPORT  the status report
--   P_MODE    poked into probe_mode: 0 = one interpret pass, 2 = one capture pass
--   P_SONG    poked into probe_song
local OUT    = os.getenv("P_OUT")
local REPORT = os.getenv("P_REPORT")
local ENTRY  = tonumber(os.getenv("P_ENTRY") or "2000", 16)
local TO     = tonumber(os.getenv("P_TO") or "3000")
local MODE   = tonumber(os.getenv("P_MODE") or "0")
local SONG   = tonumber(os.getenv("P_SONG") or "7")

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local nk  = manager.machine.natkeyboard
nk.in_use = true
local scr = manager.machine.screens:at(1)

local ST     = ENTRY + 3
local TICKS  = ENTRY + 4
local PASS   = ENTRY + 6
local MG     = ENTRY + 8
local MODEA  = ENTRY + 10
local SONGA  = ENTRY + 11
local FRAMES = ENTRY + 12
local DSTAT  = ENTRY + 14
local DFIRST = ENTRY + 15
local DCARRY = ENTRY + 17

local function u16(a) return mem:read_u8(a) * 256 + mem:read_u8(a + 1) end

-- ---------------------------------------------------------------------------
-- the tap. $FF20 non-zero = the pulse OPENS, zero = it CLOSES.
-- ★ The pair recorded is (pulse, rest) where rest runs to the NEXT open — the same
-- convention oracle_song_capture.lua used, so the two files are directly comparable.
-- ---------------------------------------------------------------------------
local pairs_n, t_open, t_close = 0, nil, nil
local rows = {}
local function now()
    local t = manager.machine.time
    return t.seconds + t.attoseconds / 1.0e18
end

_G._t_dac = mem:install_write_tap(0xFF20, 0xFF20, "dac", function(off, data, mask)
    local t = now()
    if data ~= 0 then
        if t_close and t_open then
            local pulse = (t_close - t_open) * 1.0e6
            local rest  = (t - t_close) * 1.0e6
            -- ★ the FIRST pair spans from boot to the first pulse and is not a segment;
            -- an unguarded pulse term put a 20.8 s row at index 0 and shifted every
            -- subsequent comparison by one, which reads as "100% mismatched".
            if pulse > 0 and pulse < 1000 and rest > 0 and rest < 5.0e5 then
                pairs_n = pairs_n + 1
                rows[pairs_n] = string.format("%.3f %.3f", pulse, rest)
            end
        end
        t_open = t
    elseif t_open then
        t_close = t
    end
    return data
end)

local state, t0, reported, maxst, done_at = "boot", nil, false, 0, nil
_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if reported then return end
    if state == "boot" then
        if fn >= 300 then nk:post('LOADM"INTERP"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if fn > t0 + 900 then
            -- ★ poked AFTER the load, or LOADM overwrites them
            mem:write_u8(MODEA, MODE)
            mem:write_u8(SONGA, SONG)
            nk:post('EXEC\n'); state = "run"
        end
        return
    end
    if not REPORT then return end

    local st = mem:read_u8(ST)
    if st > maxst and st <= 3 then maxst = st end
    if st == 3 then
        done_at = done_at or fn
        if fn <= done_at + 60 then return end
    elseif fn <= TO then
        return
    end
    reported = true

    local r = io.open(REPORT, "w")
    r:write("# THE INTERPRETED PLAYER, HEADLESS — grammar walk, FIRQ, DAC, tear-down.\n")
    r:write(string.format("# probe_mode %d  song %d  pass %d\n", MODE, SONG,
                          mem:read_u8(PASS)))
    -- ★ the RAW byte too: probe_start writes $EE if the disk read of the player failed,
    -- and the high-water counter only tracks 1..3, so a disk failure and "never started"
    -- were indistinguishable in the report.
    r:write(string.format("# probe_status high-water %d of 3 (1=playing 2=finished "
                          .. "3=torn down)   raw now $%02X   ($EE = the player's disk "
                          .. "read failed)\n", maxst, mem:read_u8(ST)))
    r:write(string.format("# msys ticks %d   VBL frames %d   magic $%04X (want $504E)\n",
                          u16(TICKS), u16(FRAMES), u16(MG)))
    r:write(string.format("# toggle pairs emitted %d\n", pairs_n))
    -- ★★ THE READ, MEASURED. dr_status is the WD1773's own last status byte, so it tells
    -- "never seeked" from "seeked, no sector" from "read but CRC-failed"; the first two
    -- bytes at $0A00 say whether anything landed (the player starts with a JMP, $7E).
    r:write(string.format("# player disk read: WD1773 status $%02X   carry %s   "
                          .. "first bytes at $0A00 $%04X (want $7Exx — a JMP)\n",
                          mem:read_u8(DSTAT),
                          (mem:read_u8(DCARRY) == 0xA5) and "NEVER RAN"
                            or tostring(mem:read_u8(DCARRY)),
                          u16(DFIRST)))
    -- ★★★ THE DISK VERDICT COMES FIRST, AND IT NAMES ITSELF. A failed player read used to
    -- fall through to "the LOADM/EXEC did not take" — the wrong subsystem, and that exact
    -- misdirection is what P4.19 spent a session inside. A probe that reports the wrong
    -- cause is worse than one that reports nothing.
    if mem:read_u8(DCARRY) == 1 then
        r:write("# FAIL — THE PLAYER'S DISK READ. Nothing that looks like the entry table\n")
        r:write("#        landed at $0A00 (want $7E, a JMP). The probe never ran the\n")
        r:write("#        player; this says nothing about the player itself.\n")
    elseif mem:read_u8(DCARRY) == 0xA5 then
        r:write("# FAIL — the probe never reached the player read at all.\n")
    elseif maxst >= 3 and u16(MG) == 0x504E and pairs_n > 100 then
        r:write("# PASS — it loaded, walked the stream, sounded and tore the FIRQ down.\n")
    elseif maxst == 0 then
        r:write("# FAIL — the probe never started. The LOADM/EXEC did not take.\n")
    elseif pairs_n <= 100 then
        r:write(string.format("# FAIL — only %d toggle pairs. It ran but barely sounded.\n",
                              pairs_n))
    else
        r:write(string.format("# FAIL — stalled at status %d.\n", maxst))
    end
    r:close()

    if OUT then
        local f = io.open(OUT, "w")
        f:write(string.format("# P4.19 — the PORT's own output, song %d, mode %d.\n", SONG, MODE))
        f:write("# pulse_us rest_us, one toggle pair per line — the same format as the\n")
        f:write("# oracle captures in build/tmp/boot/, so both diff against one tool.\n")
        for i = 1, pairs_n do f:write(rows[i] .. "\n") end
        f:close()
    end
    manager.machine:exit()
end)
