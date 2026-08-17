-- tone_cost.lua — P4.2 §2: the ONE measurement. What does a tone cost, per frame?
--
-- ★★★ WHY A SPIN COUNT AND NOT A CYCLE COUNTER. MAME's Lua exposes neither `cpu.clock`
-- nor `cpu:total_cycles()` on this build (both nil — probed at P3.102, recorded in
-- mame-idioms-coco3-port.md §0/§0a). The idioms file gives this project's own way round
-- it, and it is exact for the thing that matters here:
--
--   HAL_time_vbl_wait spins `cmpb <hal_frame_lo` (4 cyc) + `beq` taken (3 cyc) = 7 cycles
--   per iteration, burning every cycle the program is NOT working. So
--
--       idle  = spins * 7
--       work  = 29,859 - spins*7        [the VBL budget at $FFD9 double speed]
--
-- ★★ THE ABSOLUTE FIGURE IS ONLY AS GOOD AS THAT 7, BUT THE DIFFERENCE BETWEEN PHASES IN
-- ONE RUN IS EXACT — the same loop, the same machine, the same frame. Every conclusion
-- below is a difference against phase 0, and the absolute is reported alongside so the
-- reader can see which is which.
--
-- ★ §10a applies: a read-tap hit is not an execution count. Here the hit IS the loop
-- iteration — hal_vbl_spin is the branch target of a two-instruction spin and nothing
-- else reads it — but the seeded control below is what makes that a checked claim rather
-- than an argument.
--
-- THE SEEDED CONTROL. P_SEED=1 makes the probe's own foreground burn measurably larger by
-- holding the CPU in a Lua-driven stall... which is not available. Instead the control is
-- INTERNAL and free: phase 4 is a foreground bit-bang of a KNOWN number of toggles, so its
-- cost must be much larger than phases 1-3 and must exceed zero by a wide margin. A run in
-- which phase 4 does not dominate is a run whose counter is not counting work, and the
-- script says so rather than reporting the numbers.
local OUT   = os.getenv("P_OUT") or "build/tmp/tone_cost.log"
local SPIN  = tonumber(os.getenv("P_SPIN"), 16)
local ENTRY = tonumber(os.getenv("P_ENTRY"), 16)
local NPH   = tonumber(os.getenv("P_NPHASE") or "5")

local VBL_CYCLES  = 29859      -- gfx.s: 894,886 Hz x2 (double speed) / 59.92 Hz
local SPIN_CYCLES = 7

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true
local out = io.open(OUT, "w")
local function log(s) out:write(s .. "\n"); out:flush() end

local ST, PH, FQ, MG = ENTRY + 3, ENTRY + 4, ENTRY + 5, ENTRY + 7

local armed, spins, per = false, 0, {}
for i = 0, NPH - 1 do per[i] = { frames = 0, spins = 0, firqs = 0 } end

-- ⚠ ARMED AFTER EXEC (idioms §10): $02xx is executed by DECB itself during boot, so an
-- unarmed tap counts BASIC's spins and reads as the probe running impossibly early.
_G._t_spin = mem:install_read_tap(SPIN, SPIN, "spin", function(off, data, mask)
    if armed then spins = spins + 1 end
    return data
end)

local state, t0, reported = "boot", nil, false
_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if reported then return end
    if state == "boot" then
        if fn >= 300 then nk:post('LOADM"TONE"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if fn > t0 + 900 then nk:post('EXEC\n'); state, armed = "run", true end
        return
    end

    -- one sample per frame, attributed to the phase the probe says it is in
    if mem:read_u8(ST) == 1 then
        local p = mem:read_u8(PH)
        if per[p] then
            per[p].frames = per[p].frames + 1
            per[p].spins  = per[p].spins + spins
            per[p].firqs  = mem:read_u8(FQ) * 256 + mem:read_u8(FQ + 1)
        end
    end
    spins = 0

    if mem:read_u8(ST) ~= 2 then return end
    reported = true

    local magic = mem:read_u8(MG) * 256 + mem:read_u8(MG + 1)
    log("# TONE COST — cycles per frame, measured, both architectures")
    log(string.format("# probe magic $%04X (want $B0CE); VBL budget %d cycles at double speed",
                      magic, VBL_CYCLES))
    log("# work = VBL_budget - spins*7. The DIFFERENCE against phase 0 is the exact part;")
    log("# the absolute rests on the spin loop being 7 cycles [idioms §0a].")
    log("")
    local NAME = { [0] = "baseline (no audio)",
                   [1] = "FIRQ ~468 Hz tone",
                   [2] = "FIRQ ~999 Hz tone",
                   [3] = "FIRQ ~2000 Hz tone",
                   [4] = "BLOCKING bit-bang" }
    log("   phase  what                 frames  spins/f   work cyc/f   vs base   % of VBL")
    local base = nil
    for p = 0, NPH - 1 do
        local e = per[p]
        if e.frames > 0 then
            local sf = e.spins / e.frames
            local work = VBL_CYCLES - sf * SPIN_CYCLES
            if p == 0 then base = work end
            log(string.format("   %-6d %-20s %-7d %-9.1f %-12.0f %-9s %.1f%%",
                              p, NAME[p] or "?", e.frames, sf, work,
                              base and string.format("%+.0f", work - base) or "-",
                              100.0 * work / VBL_CYCLES))
        end
    end
    log("")
    log(string.format("# FIRQ entries observed in the last FIRQ phase: %d", per[3].firqs))

    -- ---- the control: phase 4 must dominate, or the counter is not counting work ----
    log("")
    local w = {}
    for p = 0, NPH - 1 do
        w[p] = per[p].frames > 0 and (VBL_CYCLES - (per[p].spins / per[p].frames) * SPIN_CYCLES) or nil
    end
    log("# ★ CONTROL — phase 4 bit-bangs a KNOWN 300 toggles per frame in the foreground.")
    log("#   If the counter measures work at all, phase 4 must cost far more than phase 0.")
    if not w[4] or not w[0] then
        log("# CONTROL FAILED: a phase produced no frames — nothing was measured.")
    elseif w[4] - w[0] < 2000 then
        log(string.format("# CONTROL FAILED: phase 4 exceeds baseline by only %.0f cycles. The spin",
                          w[4] - w[0]))
        log("#   count is not tracking work; reject these numbers (P3.48b).")
    else
        log(string.format("# CONTROL PASSED: phase 4 costs %+.0f cycles against baseline — the counter",
                          w[4] - w[0]))
        log("#   moves with work, so the FIRQ figures above are readable.")
    end
    out:close()
    manager.machine:exit()
end)
