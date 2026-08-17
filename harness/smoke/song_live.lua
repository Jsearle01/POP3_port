-- song_live.lua — P4.5: drive DECB to LOADM"SONG" + EXEC.
--
-- ★ THE PROVEN LAUNCH PATTERN, and P4.5's first cut did not use it. It passed
-- `-autoboot_command` with a 3-second delay, which fires before DECB has a prompt — Jay:
-- "so it didn't laod the diskin mame, at least i didnt see it." Every working runner in
-- this project instead posts keystrokes from a frame notifier once the boot has settled
-- [mame-idioms-coco3-port.md §1/§2: no autoboot, DECB is the entry point; natkeyboard:post
-- AFTER boot settles], and the frame numbers below are the ones room_live/walk_test use.
--
-- ★★ THE GAP AFTER LOADM IS NOT COSMETIC. LOADM returns to the prompt only when the disk
-- read has finished; posting EXEC too early types into a busy DECB and the characters land
-- in the line-input buffer instead. 900 frames is what the other runners allow.
--
-- ★★★ ONE HOME FOR THE LAUNCH, TWO USES. With P_OUT set this runs HEADLESS and checks the
-- probe bytes, so the slice can be proven to work before Jay is asked to listen to it;
-- without it, it just drives the keyboard and leaves the window to him. The alternative
-- was a second script with a copy of the boot sequence, and a copy is how the two drift.
local OUT   = os.getenv("P_OUT")
local ENTRY = tonumber(os.getenv("P_ENTRY") or "2000", 16)
local TO    = tonumber(os.getenv("P_TO") or "3000")

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local nk  = manager.machine.natkeyboard
nk.in_use = true
local scr = manager.machine.screens:at(1)

local ST, RUNS, FQ, MG = ENTRY + 3, ENTRY + 4, ENTRY + 6, ENTRY + 8
local SPIN = tonumber(os.getenv("P_SPIN") or "0", 16)

-- ★★ THE COST, FROM THIS RUN'S OWN CONTROL. The probe's foreground is nothing but
-- HAL_time_vbl_wait, and status 1 (playing, FIRQ live) versus status 3 (torn down, FIRQ
-- gone) are the SAME loop on the SAME machine with and without the music. So the spin
-- difference is the player's cost, and needs no separate baseline run to be wrong about.
-- Method and the 7-cycle constant: mame-idioms-coco3-port.md §0a, as P4.2 used.
local spins, per = 0, {}
local function u16(a) return mem:read_u8(a) * 256 + mem:read_u8(a + 1) end

local out = OUT and io.open(OUT, "w") or nil
local function log(s) if out then out:write(s .. "\n"); out:flush() end end

if SPIN ~= 0 then
    _G._t_spin = mem:install_read_tap(SPIN, SPIN, "spin", function(off, data, mask)
        spins = spins + 1
        return data
    end)
end

local state, t0, reported, maxst, done_at = "boot", nil, false, 0, nil
_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if reported then return end
    if state == "boot" then
        if fn >= 300 then nk:post('LOADM"SONG"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if fn > t0 + 900 then nk:post('EXEC\n'); state = "run" end
        return
    end
    if not out then return end

    local st = mem:read_u8(ST)
    if st > maxst and st <= 3 then maxst = st end
    if SPIN ~= 0 and (st == 1 or st == 3) then
        per[st] = per[st] or { f = 0, s = 0 }
        per[st].f = per[st].f + 1
        per[st].s = per[st].s + spins
    end
    spins = 0
-- ★ THE TORN-DOWN STATE IS THE CONTROL, SO IT NEEDS FRAMES OF ITS OWN. The first cut
-- exited the instant status reached 3 and the cost block never had a baseline to compare
-- against — a control with zero samples, which is the shape P4.2's timing seed hit too.
    if st == 3 then
        done_at = done_at or fn
        if fn <= done_at + 150 then return end
    elseif fn <= TO then
        return
    end
    reported = true

    log("# THE SLICE, HEADLESS — does it load, play and tear down?")
    log(string.format("# probe_status high-water %d of 3 (1=playing 2=finished 3=torn down)", maxst))
    log(string.format("# runs consumed %d of 321   FIRQ entries %d   magic $%04X (want $504E)",
                      u16(RUNS), u16(FQ), u16(MG)))
    if maxst >= 3 and u16(MG) == 0x504E then
        log("# PASS — it loaded, played to the terminator and tore the FIRQ down.")
    elseif maxst == 0 then
        log("# FAIL — the probe never started. The LOADM/EXEC did not take.")
    else
        log(string.format("# FAIL — stalled at status %d.", maxst))
    end
    if SPIN ~= 0 and per[1] and per[3] and per[1].f > 30 and per[3].f > 30 then
        local VBL, SC = 29859, 7
        local wp = VBL - (per[1].s / per[1].f) * SC
        local wq = VBL - (per[3].s / per[3].f) * SC
        log("")
        log("# ★ MEASURED COST — the same wait loop, with the player live and torn down.")
        log(string.format("#   playing   %6.1f spins/f -> %6.0f cyc/f   (%d frames)",
                          per[1].s / per[1].f, wp, per[1].f))
        log(string.format("#   torn down %6.1f spins/f -> %6.0f cyc/f   (%d frames)",
                          per[3].s / per[3].f, wq, per[3].f))
        log(string.format("#   THE PLAYER COSTS %+.0f cyc/frame = %.1f%% of the VBL budget",
                          wp - wq, 100.0 * (wp - wq) / VBL))
        log("#   P4.2 predicted ~866 cyc/f (2.9%) for a 943 Hz stream; this song averages")
        log("#   603 Hz, for which the same model predicts ~554 cyc/f (1.9%).")
    end
    out:close()
    manager.machine:exit()
end)
