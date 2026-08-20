-- intro_song_cost.lua — P4.21 §1: what the music costs INSIDE a hold, measured.
--
-- ★★★ THE CONTROL IS IN THE SAME RUN, AND THAT IS THE POINT. `hold_frames` spins in
-- HAL_time_vbl_wait; the spin count per frame is whatever CPU the foreground had left
-- over. Beat 1 carries BEAT_SONG = s_Presents and beat 5 carries BEAT_SONG 0 — the SAME
-- loop, on the SAME machine, in the SAME run, with and without the player. So the
-- difference is the player's cost and needs no separate baseline to be wrong about.
-- Method and the 7-cycle constant: mame-idioms-coco3-port.md §0a, as P4.2 and P4.6 used.
--
-- ★★ IT ALSO COUNTS THE FIRQ, because since P4.21 the player's handler services the VBL
-- as well (the GIME's $FF92/$FF93 share one set of latches, so one handler must own them).
-- Interrupts/frame times cycles/interrupt is the other half of the cost and the spin
-- difference alone would hide it.
local SPIN  = tonumber(os.getenv("P_SPIN") or "0", 16)
local ST    = tonumber(os.getenv("P_STATUS") or "0", 16)
local OUT   = os.getenv("P_OUT") or "build/tmp/intro_song_cost.log"
local VBL, SC = 29859, 7            -- cycles per frame; cycles per spin iteration

local mem = manager.machine.devices[":maincpu"].spaces["program"]
local nk  = manager.machine.natkeyboard
nk.in_use = true
local scr = manager.machine.screens:at(1)

local spins, firqs = 0, 0
local per = {}                       -- [status] = {frames=, spins=, firqs=}

_G._t1 = mem:install_read_tap(SPIN, SPIN, "spin", function(o, d, m)
    spins = spins + 1; return d
end)
-- the FIRQ acknowledges by reading $FF93 exactly once per entry
_G._t2 = mem:install_read_tap(0xFF93, 0xFF93, "firq", function(o, d, m)
    firqs = firqs + 1; return d
end)

local out = io.open(OUT, "w")
local state, t0 = "boot", nil
_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if state == "boot" then
        if fn >= 300 then nk:post('LOADM"LOADER"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if fn > t0 + 900 then nk:post('EXEC\n'); state = "run" end
        return
    end
    local st = mem:read_u8(ST)
    per[st] = per[st] or { frames = 0, spins = 0, firqs = 0 }
    local b = per[st]
    b.frames = b.frames + 1
    b.spins  = b.spins + spins
    b.firqs  = b.firqs + firqs
    spins, firqs = 0, 0

    if fn > 11000 then
        out:write("# THE MUSIC'S COST INSIDE A HOLD — beat 1 plays, beat 5 is silent.\n")
        out:write("# probe_status carries beat+2, so status 2 = beat 1, status 6 = beat 5.\n")
        out:write(string.format("# %-8s %8s %12s %10s %10s\n",
                                "status", "frames", "spins/frame", "firq/frame", "cyc/frame"))
        local base
        for s = 2, 7 do
            local x = per[s]
            if x and x.frames > 30 then
                local sp = x.spins / x.frames
                local fq = x.firqs / x.frames
                out:write(string.format("  %-8d %8d %12.1f %10.2f\n", s, x.frames, sp, fq))
                if s == 6 then base = sp end
            end
        end
        if base and per[2] and per[2].frames > 30 then
            local sp1 = per[2].spins / per[2].frames
            local lost = (base - sp1) * SC
            out:write(string.format(
                "\n# beat 1 (song)   %.1f spins/frame\n# beat 5 (silent) %.1f spins/frame\n",
                sp1, base))
            out:write(string.format(
                "# ★ the music costs %.0f cycles/frame = %.2f%% of the %d-cycle VBL budget\n",
                lost, lost * 100 / VBL, VBL))
            out:write(string.format("# ★ FIRQ rate in the song: %.2f per frame\n",
                                    per[2].firqs / per[2].frames))
        else
            out:write("\n# ★ NOT ENOUGH SAMPLES — the control beat never ran long enough.\n")
        end
        out:close()
        manager.machine:exit()
    end
end)
