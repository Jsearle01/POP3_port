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

-- P5.37: the phase boundaries (P_PH, space-separated, last = the end) and the file LOADM types (P_FILE).
-- Unset = the kid-run probe's six and KIDRUN -- the log is then byte-for-byte the format kidrun_cost.py reads.
local PH = {}
for n in (os.getenv("P_PH") or "wk_t_seq wk_t_erase wk_t_save wk_t_draw wk_t_fore wk_t_end"):gmatch("%S+") do
    PH[#PH + 1] = n
end
local FILE = os.getenv("P_FILE") or "KIDRUN"
local sym = {}
local need = {"wk_steps", "wk_frame", "wk_x", "wk_k", "probe_status"}
for _, n in ipairs(PH) do need[#need + 1] = n end
for _, name in ipairs(need) do
    local v = os.getenv("S_" .. name)
    if not v then log("# missing S_" .. name); manager.machine:exit(); return end
    sym[name] = tonumber(v, 16)
end
-- the snapshot's layout: N-1 phase deltas, the total, then frame / x / k, the step word, the absolute clock
local ND = #PH - 1
local O_TOT, O_META, O_STEP, O_ABS = 4 * ND, 4 * ND + 4, 4 * ND + 8, 4 * ND + 12

local state, t0, last = "boot", 0, -1
local clk0, clk1 = nil, nil
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
        local act = {string.format("temp%d=totalcycles", ND)}
        for i = 0, ND - 1 do
            act[#act + 1] = string.format("pd@0x%X=temp%d-temp%d", S + 4 * i, i + 1, i)
        end
        act[#act + 1] = string.format("pd@0x%X=temp%d-temp0", S + O_TOT, ND)
        act[#act + 1] = string.format("pb@0x%X=pb@0x%X; pb@0x%X=pb@0x%X; pb@0x%X=pb@0x%X; pw@0x%X=pw@0x%X+1; " ..
            "pd@0x%X=temp0; go", S + O_META, sym.wk_frame, S + O_META + 1, sym.wk_x, S + O_META + 2, sym.wk_k,
            S + O_STEP, sym.wk_steps, S + O_ABS)
        cpu.debug:bpset(sym[PH[#PH]], "1", table.concat(act, "; "))
        nk:post('LOADM"' .. FILE .. '"\n'); state, t0 = "load", fn
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
        local st = mem:read_u8(SLOTS + O_STEP) * 256 + mem:read_u8(SLOTS + O_STEP + 1)  -- the snapshot's step
        -- the snapshot area holds the tile page's staging bytes until the first step writes it, so a
        -- snapshot counts only when its step agrees with the probe's own counter (equal, or one
        -- ahead in the instructions between the snapshot and the increment)
        local live = mem:read_u8(sym.wk_steps) * 256 + mem:read_u8(sym.wk_steps + 1)
        if live >= 1 and (st == live or st == live + 1) and st ~= last then
            last = st
            local d = {}
            for i = 0, ND - 1 do d[#d + 1] = string.format("%d", mem:read_u32(SLOTS + 4 * i)) end
            -- the trailing field is the video frame the step was SEEN complete on: the gaps
            -- between steps are the achieved cadence, measured rather than taken from WK_SPEED
            log(string.format("S %d %d %d %d  %s  %d %d", st, mem:read_u8(SLOTS + O_META),
                mem:read_u8(SLOTS + O_META + 1), mem:read_u8(SLOTS + O_META + 2), table.concat(d, " "),
                mem:read_u32(SLOTS + O_TOT), fn))
            -- ★ P5.35: THE CLOCK, MEASURED. The absolute totalcycles at the start of each step's
            -- sequencer (SLOTS+32) against the video frame it was seen on: over the run, CPU cycles per
            -- real frame. P5.31-P5.34 divided by an ASSUMED 29,859 while tile_probe left the SAM slow.
            local abs = mem:read_u32(SLOTS + O_ABS)
            if not clk0 then clk0 = {fn, abs} end
            clk1 = {fn, abs}
        end
        if last >= NSTEPS or fn - t0 > 20000 then
            if clk0 and clk1 and clk1[1] > clk0[1] then
                log(string.format("# CLOCK %.1f cycles per real frame (%d cycles over %d frames, step starts)",
                    ((clk1[2] - clk0[2]) & 0xFFFFFFFF) / (clk1[1] - clk0[1]),
                    (clk1[2] - clk0[2]) & 0xFFFFFFFF, clk1[1] - clk0[1]))
            end
            log(string.format("# DONE at step %d, frame +%d", last, fn - t0))
            manager.machine:exit()
        end
    end
end)
