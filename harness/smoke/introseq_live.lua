-- harness/smoke/introseq_live.lua
--
-- POP CoCo3 — P3.3 intro sequencer, LIVE VIEWING (Jay's 25.3 gate).
--
-- Starts the sequencer and then gets out of the way. Unlike introseq_test.lua
-- this script:
--   * does NOT dump framebuffers (30,720 Lua reads per capture stutters a
--     throttled run, and the screen IS the artifact here)
--   * does NOT borrow the MMU window for anything
--   * does NOT call machine:exit() — the window stays open until Jay closes it
--   * makes no PASS/FAIL claim of any kind. Visual authority is Jay's live MAME
--     (idiom §11); this script only gets the program running.
--
-- Run THROTTLED (no -nothrottle). That matters more here than on any previous
-- gate: the whole point is the TIMING — 100 frames of splash, 282 of the first
-- caption, 97, then 285 — and the flips that start and end them. Under
-- -nothrottle those durations are meaningless.
--
-- THE IMAGE IS LOADMed FROM DISK -- the real path. P3.4 took the screen out of
-- the program image (raw tracks 27..33, read by the program itself), dropping
-- INTROSEQ.BIN to one granule; P3.5 moved the engine to $2000, clear of Color
-- BASIC's line-input buffer at $02DC where the typed EXEC lands -- which is what
-- used to corrupt the program between LOADM and EXEC and made this file's poked
-- path the only one that worked.
--
-- Expect ~11.2 s of disk before the first picture: boot + LOADM + the bundle is
-- 8.2 s of drive-engaged time, then the packed splash is 3.0 s. Across the whole
-- intro it is 17.2 s, of which only 2.8 s is bytes actually moving -- the rest is
-- spin-up, seek and rotational latency. Both numbers are MEASURED, by an FDC
-- data-register tap and a DSKREG tap in introseq_test.lua; the ~47 s this comment
-- used to claim predates the splash bank (P3.11) and compression (P3.12).

local BIN = os.getenv("P_BIN") or "build/intro_seq.bin"
local OUT = os.getenv("P_OUT") or "build/introseq_live.log"

local BOOT_FRAME = 240

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]

local log_file = io.open(OUT, "w")
local function log(s) if log_file then log_file:write(s .. "\n"); log_file:flush() end end

local BOOT2 = 300
local nk = manager.machine.natkeyboard
nk.in_use = true
local state, t0 = "boot", nil

local function tick()
    local fn = manager.machine.screens:at(1):frame_number()
    if state == "boot" and fn >= BOOT2 then
        nk:post('LOADM"LOADER"\n')
        log("# posted LOADM at frame " .. fn)
        state = "loadm"; t0 = fn
    elseif state == "loadm" and fn > t0 + 500 then
        nk:post('EXEC\n')
        log("# posted EXEC at frame " .. fn .. " -- ~11.2 s of disk before the first picture")
        state = "run"
    end
end

_G._notifier = emu.add_machine_frame_notifier(tick)
