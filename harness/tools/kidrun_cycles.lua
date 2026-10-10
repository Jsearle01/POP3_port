-- harness/tools/kidrun_cycles.lua
--
-- POP P5.31 — what one animation step of the running kid COSTS, by phase, off the built binary.
--
-- The debugger's `totalcycles` (mame-idioms-coco3-port.md §41): a breakpoint at each phase
-- boundary in kidrun_probe.s -- wk_t_seq (sequencer), wk_t_erase (the per-page peel restore),
-- wk_t_save (the save under the new frame), wk_t_draw (xf_blit), wk_t_fore (the foreground pass),
-- wk_t_end -- writes the low 32 bits of totalcycles into its own slot in scratch RAM, and this
-- script reads the slots at each video frame, logging every step whose counter has moved.
--
-- ★ WHAT THE NUMBERS INCLUDE: everything the CPU executes between two boundaries, which means any
-- VBL IRQ (HAL time handler) that lands inside a phase is in that phase's figure. xf_blit and
-- blit_cel mask most of their time; the peel and the sequencer do not. Stated, not subtracted.
-- The pacing wait and HAL_gfx_swap (which waits for VBL) are NOT phases: they are idle.
--
-- LAUNCH: the delivery path (LOADM"KIDRUN" + EXEC off the gate disk), headless, -debug.
local OUT = os.getenv("P_OUT") or "build/kidrun_cycles.log"
local NSTEPS = tonumber(os.getenv("P_NSTEPS") or "50")
local SETTLE = tonumber(os.getenv("P_SETTLE") or "600")    -- P5.31b: KIDRUN.BIN is the small loader
local SLOTS = 0x4100                       -- scratch: the staging area's tail, clear of the four peel
--                                            buffers ($3000-$359F since P5.32; $3400 was inside them)
-- P5.32: P_NACT=1 pokes the LOADER's kr_nact before EXEC -- the one-actor control, on the same
-- three-pass code. Unset = the probe's default, 2.
local NACT = os.getenv("P_NACT")

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local nk = manager.machine.natkeyboard
nk.in_use = true
local f = io.open(OUT, "w")
local function log(s) f:write(s .. "\n"); f:flush() end
pcall(function() manager.machine.debugger.execution_state = "run" end)

local sym = {}
for name in ("wk_t_seq wk_t_erase wk_t_save wk_t_draw wk_t_fore wk_t_end wk_steps wk_frame wk_x wk_k probe_status"):gmatch("%S+") do
    local v = os.getenv("S_" .. name)
    if not v then log("# missing S_" .. name); manager.machine:exit(); return end
    sym[name] = tonumber(v, 16)
end
local PH = {"wk_t_seq", "wk_t_erase", "wk_t_save", "wk_t_draw", "wk_t_fore", "wk_t_end"}

local state, t0, last = "boot", 0, -1
_G._kc = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if state == "boot" and fn >= 300 then
        -- ★ P5.32: A SNAPSHOT, WRITTEN BY ONE ACTION AT wk_t_end. P5.31 wrote each boundary to its own
        -- slot and read the slots once per video frame; with two actors a read could land after the
        -- NEXT step's seq/erase had run, so a row mixed two steps (erase came out as 2^32 - x). Now each
        -- boundary only sets a debugger temp, and the end breakpoint writes every delta, the frame, X,
        -- phase and the step number into SLOTS in one action -- a row is always one step.
        for i = 1, #PH - 1 do
            cpu.debug:bpset(sym[PH[i]], "1", string.format("temp%d=totalcycles; go", i - 1))
        end
        local S = SLOTS
        cpu.debug:bpset(sym.wk_t_end, "1", string.format(
            "temp5=totalcycles; pd@0x%X=temp1-temp0; pd@0x%X=temp2-temp1; pd@0x%X=temp3-temp2; " ..
            "pd@0x%X=temp4-temp3; pd@0x%X=temp5-temp4; pd@0x%X=temp5-temp0; " ..
            "pb@0x%X=pb@0x%X; pb@0x%X=pb@0x%X; pb@0x%X=pb@0x%X; pw@0x%X=pw@0x%X+1; go",
            S, S + 4, S + 8, S + 12, S + 16, S + 20,
            S + 24, sym.wk_frame, S + 25, sym.wk_x, S + 26, sym.wk_k, S + 28, sym.wk_steps))
        nk:post('LOADM"KIDRUN"\n'); state, t0 = "load", fn
    elseif state == "load" and fn > t0 + SETTLE then
        if NACT and NACT ~= "" then
            mem:write_u8(tonumber(os.getenv("S_kr_nact"), 16), tonumber(NACT))
            log("# poked kr_nact = " .. NACT .. " (actors)")
        end
        nk:post('EXEC\n'); state, t0 = "run", fn
        log("# step frame x k  seq erase save draw fore  total   (cycles)")
    elseif state == "run" then
        -- ★ P5.31b: EXEC starts the LOADER, which reads the probe in over whatever RAM held; until
        -- the probe has drawn its page (status 2), wk_steps is not the probe's counter at all.
        if mem:read_u8(sym.probe_status) ~= 2 and mem:read_u8(sym.probe_status) ~= 4 then return end
        local st = mem:read_u8(SLOTS + 28) * 256 + mem:read_u8(SLOTS + 29)    -- the snapshot's step
        -- the snapshot area holds the tile page's staging bytes until the first step writes it, so a
        -- snapshot counts only when its step agrees with the probe's own counter (equal, or one
        -- ahead in the instructions between the snapshot and the increment)
        local live = mem:read_u8(sym.wk_steps) * 256 + mem:read_u8(sym.wk_steps + 1)
        if live >= 1 and (st == live or st == live + 1) and st ~= last then
            last = st
            local d = {}
            for i = 1, 6 do d[i] = mem:read_u32(SLOTS + 4 * (i - 1)) end
            -- the trailing field is the video frame the step was SEEN complete on: the gaps
            -- between steps are the achieved cadence, measured rather than taken from WK_SPEED
            log(string.format("S %d %d %d %d  %d %d %d %d %d  %d %d", st, mem:read_u8(SLOTS + 24),
                mem:read_u8(SLOTS + 25), mem:read_u8(SLOTS + 26), d[1], d[2], d[3], d[4], d[5], d[6], fn))
        end
        if last >= NSTEPS or fn - t0 > 20000 then
            log(string.format("# DONE at step %d, frame +%d", last, fn - t0))
            manager.machine:exit()
        end
    end
end)
