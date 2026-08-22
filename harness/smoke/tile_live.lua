-- harness/smoke/tile_live.lua
--
-- POP CoCo3 — P5.5's tile page, LIVE VIEWING (Jay's 25.3 gate).
--
-- Starts the renderer and then gets out of the way. Like introseq_live.lua and unlike
-- tile_test.lua this script:
--   * does NOT dump framebuffers (15,360 Lua reads stutters a throttled run, and the
--     screen IS the artifact here)
--   * does NOT borrow the MMU window for anything
--   * does NOT call machine:exit() — the window stays open until Jay closes it
--   * makes no PASS/FAIL claim of any kind. Visual authority is Jay's live MAME; this
--     script only gets the program running.
--
-- Run THROTTLED. There is no motion to time here, but the DISK is the thing the live path
-- exists to show: boot, LOADM, EXEC, one track read, the picture. Under -nothrottle that
-- sequence goes by in an instant and a load failure looks the same as a load.
--
-- It DOES post progress to the log, because "nothing appeared" needs to distinguish "EXEC
-- was never typed" from "the renderer stopped part way".
--
-- ★ THE PROBE IS WATCHED, NOT SAMPLED. The first version read the probe block ONCE at
-- EXEC+180 frames and logged `status=1`, which reads as "the renderer stopped after
-- setting the mode" and is not what happened: THROTTLED, one whole track off a real FDC
-- takes longer than three seconds, and the read was still in flight. The headless suite
-- reaches status 4 and a byte-exact framebuffer on the same image. A fixed delay is a bet
-- on how long the disk takes -- the same bet room_test.lua lost on LOADM -- so this logs
-- every TRANSITION of the status byte instead, and a stall is then visible as a status
-- that stops advancing rather than as a number sampled at the wrong moment.

local OUT = os.getenv("P_OUT") or "build/tile_live.log"
local ENTRY = tonumber(os.getenv("P_ENGINE") or "0x2000")

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local nk  = manager.machine.natkeyboard
nk.in_use = true

local log_file = io.open(OUT, "w")
local function log(s) if log_file then log_file:write(s .. "\n"); log_file:flush() end end

local state, t0, last_st = "boot", nil, -1

local STATUS_NAME = {[0] = "boot", [1] = "mode set", [2] = "page in",
                     [3] = "drawn", [4] = "SHOWN"}

local function tick()
    local fn = manager.machine.screens:at(1):frame_number()
    if state == "boot" and fn >= 300 then
        nk:post('LOADM"TILE"\n')
        log("# posted LOADM at frame " .. fn)
        state, t0 = "loadm", fn
    elseif state == "loadm" and fn > t0 + 500 then
        nk:post('EXEC\n')
        log("# posted EXEC at frame " .. fn)
        state, t0 = "run", fn
    elseif state == "run" then
        local st = mem:read_u8(ENTRY + 3)
        if st ~= last_st then
            last_st = st
            log(string.format("# frame %d  status=%d (%s)  dskerr=%02X magic=%02X%02X ents=%d",
                              fn, st, STATUS_NAME[st] or "?", mem:read_u8(ENTRY + 4),
                              mem:read_u8(ENTRY + 5), mem:read_u8(ENTRY + 6),
                              mem:read_u8(ENTRY + 7)))
            if st == 4 then
                log("# the picture is up. The window stays open until you close it.")
            end
        end
    end
end

-- The subscription must be HELD or the GC unsubscribes it and the callback silently stops
-- firing [mame-idioms-coco3-port.md] — which here would read as "EXEC was never typed".
_G._notifier = emu.add_machine_frame_notifier(tick)
log("# tile_live: waiting for the BASIC prompt")
