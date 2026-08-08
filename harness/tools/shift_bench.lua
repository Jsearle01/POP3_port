-- harness/tools/shift_bench.lua
--
-- POP P3.41 — EXECUTE the shift loop and time it against the VBL.
--
-- P3.40's 93% verdict rests on P3.39's ASSEMBLED-BUT-NOT-EXECUTED figures, and P3.39
-- is the dispatch that turned a counted 98% into an assembled 114%. This closes that
-- gap the only way it can be closed.
--
-- METHOD: elapsed video frames over 20,000 iterations at each of two row widths. The
-- VBL is the clock every rate and cadence measurement in this project already uses;
-- at 20,000 iterations a one-frame error is 0.006% of the result. Two widths, because
-- P3.21 was wrong by 2.2x from applying one row width's rate to another's — and the
-- difference between them IS the per-byte cost, with the remainder the per-row
-- overhead. Both figures P3.40 depends on fall out of one run, neither assumed.
--
--     cy(7) - cy(6)        = per-byte  (one extra unrolled rung)
--     cy(6) - 6*per-byte   = per-row overhead
--
-- LAUNCH PATH: poke. This is a leaf-routine cycle measurement, not a gate — nothing
-- here is presented as a 25.3 observation, and CLAUDE.md §4's objection to poke is
-- about hiding load/launch bugs in gated behaviour, which this is not.
local BIN   = os.getenv("P_BIN") or "build/bench.bin"
local BASE  = tonumber(os.getenv("P_BASE") or "0x3000")
local PHASE = tonumber(os.getenv("P_PHASE") or "0x3090")
local ITER  = tonumber(os.getenv("P_ITER") or "20000")
local OUT   = os.getenv("P_OUT") or "build/shift_bench.log"
-- 6809 cycles per video frame, the figure every budget in this arc is stated against
-- (P3.19: 29,859 per frame, less the 186 cy page flip = 29,673 usable; the raw frame
-- is what a wall-clock measurement sees).
local CY_PER_FRAME = 29859

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local f = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end

local state, t7, t6 = "boot", nil, nil

local function load_bin()
    local fh = io.open(BIN, "rb")
    if not fh then log("# cannot open " .. BIN); return false end
    local d = fh:read("*a"); fh:close()
    for i = 1, #d do mem:write_u8(BASE + i - 1, d:byte(i)) end
    log(string.format("# poked %d bytes at $%04X", #d, BASE))
    return true
end

local function tick()
    local fn = scr:frame_number()
    if state == "boot" then
        if fn >= 240 then                        -- let the machine settle
            if not load_bin() then manager.machine:exit(); return end
            cpu.state["PC"].value = BASE
            state = "run7"
            t7 = fn
            log("# started, PC = $" .. string.format("%04X", BASE))
        end
        return
    end
    local ph = mem:read_u8(PHASE)
    if state == "run7" and ph >= 2 then
        local frames = fn - t7
        local cy = frames * CY_PER_FRAME / ITER
        log(string.format("w=7  %d frames over %d iterations -> %.1f cy/row",
                          frames, ITER, cy))
        t6 = fn
        state = "run6"
    elseif state == "run6" and ph >= 3 then
        local frames = fn - t6
        local cy6 = frames * CY_PER_FRAME / ITER
        log(string.format("w=6  %d frames over %d iterations -> %.1f cy/row",
                          frames, ITER, cy6))
        log("# (the w=7 and w=6 rates differ by exactly one unrolled rung)")
        manager.machine:exit()
    elseif fn > (t7 or 0) + 3600 then
        log("# TIMEOUT — phase stuck at " .. ph)
        manager.machine:exit()
    end
end

_G._notifier = emu.add_machine_frame_notifier(tick)
