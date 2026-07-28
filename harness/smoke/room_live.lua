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

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local state, t0, loaded = "boot", nil, nil

local function tick()
    local fn = scr:frame_number()
    if state == "boot" and fn >= 120 then
        nk:post('LOADM"ROOM"\n')
        log("# posted LOADM at frame " .. fn)
        state, t0 = "loadm", fn
    elseif state == "loadm" then
        -- WAIT FOR THE LOAD, THEN SETTLE — do not simply wait a long time. A blind
        -- 500-frame delay put the room on screen 15 s after launch, which is a
        -- miserable thing to watch and is why Jay saw nothing. $2000 holds
        -- `jmp room_start` once DECB has placed the image, so the load is
        -- OBSERVABLE; the settle after it is what P3.6 actually needed (EXEC was
        -- posted while DECB was still busy and the machine ate its first letter).
        if loaded == nil and mem:read_u8(0x2000) == 0x7E then
            loaded = fn
            log("# LOADM landed at frame " .. fn)
        elseif loaded ~= nil and fn > loaded + 90 then
            nk:post('EXEC\n')
            log("# posted EXEC at frame " .. fn .. " — one track (~1.3 s), then the room")
            state = "run"
        end
    end
end

_G._notifier = emu.add_machine_frame_notifier(tick)
