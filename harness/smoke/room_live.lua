-- harness/smoke/room_live.lua
--
-- POP P3.17 — start the princess's room and get out of the way (Jay's 25.3 gate).
--
-- Like introseq_live.lua and for the same reasons: no framebuffer dumps (the screen
-- IS the artifact here), no MMU borrowing, no machine:exit() — the window stays open
-- until Jay closes it — and NO PASS/FAIL claim of any kind. Visual authority is Jay's
-- live MAME; this script only gets the program running on the real path.
--
-- LOADM"ROOM" + EXEC off a mounted floppy. Not a poke: P3.5 is why (the freeze, the
-- LOADM ceiling and the EXEC overwrite all lived on the real launch path and were
-- invisible to the poked one).
local OUT = os.getenv("P_OUT") or "build/room_live.log"

local scr = manager.machine.screens:at(1)
local nk = manager.machine.natkeyboard
nk.in_use = true

local log_file = io.open(OUT, "w")
local function log(s) if log_file then log_file:write(s .. "\n"); log_file:flush() end end

local state, t0 = "boot", nil

local function tick()
    local fn = scr:frame_number()
    if state == "boot" and fn >= 300 then
        nk:post('LOADM"ROOM"\n')
        log("# posted LOADM at frame " .. fn)
        state, t0 = "loadm", fn
    elseif state == "loadm" and fn > t0 + 500 then
        -- the settle matters: P3.6 lost the first letter of EXEC by posting it while
        -- DECB was still finishing the load
        nk:post('EXEC\n')
        log("# posted EXEC at frame " .. fn .. " — one track (~1.3 s), then the room")
        state = "run"
    end
end

_G._notifier = emu.add_machine_frame_notifier(tick)
