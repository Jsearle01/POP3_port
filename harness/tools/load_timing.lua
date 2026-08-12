-- harness/tools/load_timing.lua
--
-- POP P3.75b — WHAT IS ACTUALLY IN A DISK READ? (Jay: "can we reduce the loadtime by
-- leaving the disk motor running?")
--
-- The room does three load_tracks calls — room blob (1 track), flame bundle (1 track),
-- cel image (3 tracks) — and each one spins the motor up, reads, then drops DSKREG to
-- turn the motor off again. So the question decomposes:
--
--     load 1 = spin-up + 1 track
--     load 2 = spin-up + 1 track
--     load 3 = spin-up + 3 tracks
--
-- Two equations, two unknowns: (load3 - load1) / 2 is a TRACK, and load1 minus that is
-- the SPIN-UP. That says directly how much keeping the motor running could save.
--
-- Measured off probe_loads, which load_tracks increments on success — so it counts reads
-- that completed, not reads that were attempted.
--
-- PASSIVE: reads probe_loads and the frame counter. Writes nothing. (P3.71: a checker
-- that writes can cause the fault it measures.)
local ENGINE = tonumber(os.getenv("P_ENGINE") or "0x2000")
local OUT    = os.getenv("P_OUT") or "build/load_timing.log"

local LOADS = ENGINE + 4          -- probe_loads [cutscene_room.s]
local ROOM_MAGIC = 0x4B00

local mem = manager.machine.devices[":maincpu"].spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true

local f = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end
local function rd8(a) return mem:read_u8(a) end
local function rd16(a) return rd8(a) * 256 + rd8(a + 1) end

local state, t0, exec_fn, prev, marks = "boot", nil, nil, 0, {}

local function tick()
    local fn = scr:frame_number()
    if state == "boot" then
        if fn >= 300 then nk:post('LOADM"ROOM"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if fn > t0 + 900 then
            nk:post('EXEC\n'); state, exec_fn = "run", fn
            log("# EXEC posted at frame " .. fn)
        end
        return
    end

    local n = rd8(LOADS)
    if n ~= prev then
        local at = fn
        local since = marks[#marks] and (at - marks[#marks]) or (at - exec_fn)
        marks[#marks + 1] = at
        log(string.format("# load %d complete at frame %-6d  (+%d frames, %.2f s)",
                          n, at, since, since / 60.0))
        prev = n
    end

    if rd16(ENGINE + 6) == ROOM_MAGIC and n >= 3 then
        log(string.format("# room up at frame %d — EXEC to room = %d frames, %.2f s",
                          fn, fn - exec_fn, (fn - exec_fn) / 60.0))
        if #marks >= 3 then
            -- LOADS 2 AND 3, NOT 1 AND 3. Load 1's interval starts at EXEC, so it also
            -- carries the engine's own init — gfx setup, mode switch, palette — and using
            -- it puts that time into the "spin-up" term. Loads 2 and 3 are both
            -- read-to-read, so the only difference between them is TRACKS.
            local l2 = marks[2] - marks[1]      -- spin-up + 1 track
            local l3 = marks[3] - marks[2]      -- spin-up + 3 tracks
            local track = (l3 - l2) / 2.0
            local spin = l2 - track
            log("#")
            log("# --- decomposed ---")
            log(string.format("#   one TRACK          %6.1f frames  %.2f s",
                              track, track / 60.0))
            -- THE SECOND TERM IS NOT ALWAYS THE SPIN-UP (P3.76). The arithmetic assumes
            -- every load pays the same fixed cost, which was true while dr_spinup ran
            -- unconditionally. Now that the room holds the drive across all three reads,
            -- loads 2 and 3 skip it — so what is left in this term is the per-call
            -- overhead that is STILL unconditional: the FDC Restore to track 0 and the
            -- seek back out. Measured: 0.60 s before the change, 0.20 s after, and the
            -- 0.40 s difference is dr_spinup's delay loop (393,216 cy at 0.894 MHz =
            -- 0.44 s, which is where it should be).
            log(string.format("#   per-call OVERHEAD  %6.1f frames  %.2f s  "
                              .. "(spin-up if cold, else Restore+seek)",
                              spin, spin / 60.0))
            log(string.format("#   3 x that overhead costs %.2f s of the %.2f s startup",
                              3 * spin / 60.0, (fn - exec_fn) / 60.0))
            log("#   (build.bat's 3.31 s/track is the PRE-DMK JVC figure, P3.6)")
        end
        if f then f:close() end
        manager.machine:exit()
    end
end

emu.register_frame_done(tick)
