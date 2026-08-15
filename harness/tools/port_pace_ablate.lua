-- port_pace_ablate.lua — P3.87: the iteration length is QUANTISED, so components must be
-- measured by ablation, not by subtraction inside one run.
--
-- ★ WHY THE PHASE TABLE CANNOT ANSWER THIS. room_present ends every iteration on a VBL
-- wait, so an iteration is a WHOLE NUMBER of video frames whatever the work inside it
-- costs. port_phase_cost read scene beat 14 at 3.06 frames against beat 10's 3.00 and the
-- difference is not the hourglass's cost — it is the hourglass fitting inside a 3-frame
-- iteration that had room. A component's cost is invisible until it crosses a boundary,
-- and then the whole frame appears at once. That is exactly the shape of the symptom:
-- 6 / 8 / 10 with nothing in between.
--
-- So: run the same build with one component removed AT RUN TIME and compare the step
-- rate per beat. The idioms file's rule for this (§10a, P3.43) is the one that matters —
-- the patch is VERIFIED against the bytes that must be there and the run ABORTS on a
-- mismatch, because patching an address that does not hold the instruction you think it
-- does yields a plausible number from a corrupted program.
--
-- P_ABLATE:
--   none      — the shipping build, for the baseline
--   scenery   — `jsr scenery_frame` -> NOPs; no hourglass body, no sand, no flash
--   chars     — `jsr [CHARS_TAB]`   -> NOPs; the whole character path is gone
--   flicker   — `jsr flicker`       -> NOPs; the torches and stars are gone
--
-- The screen is WRONG in every ablated mode. None of this is a visual gate.
local MODE = os.getenv("P_ABLATE") or "none"
local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true
local out = io.open(os.getenv("P_OUT") or "build/tmp/port_pace_ablate.log", "w")
local function log(s) out:write(s .. "\n"); out:flush() end

local function readmap(path)
    local m = {}
    for line in io.lines(path) do
        local n, a = line:match("^Symbol: (%S+) .*= *(%x+)$")
        if n then m[n] = tonumber(a, 16) end
    end
    return m
end
local F = readmap("build/obj/flames.map")
local R = readmap("build/obj/room.map")
log("# ablate=" .. MODE)

-- ---------------------------------------------------------------
-- find the call site by its BYTES, not by an offset from a label
-- ---------------------------------------------------------------
-- An offset counted from a symbol goes stale the moment an instruction above it changes
-- length, and then patches the middle of something else. Scanning for the exact encoding
-- with the map-derived operand is self-checking, and UNIQUENESS is required: two matches
-- would make "the one I found" an assumption.
local function find_direct(target, lo, hi, what)
    local hi8, lo8 = (target >> 8) & 0xFF, target & 0xFF
    local hits = {}
    for a = lo, hi do
        if mem:read_u8(a) == 0xBD and mem:read_u8(a + 1) == hi8
           and mem:read_u8(a + 2) == lo8 then
            hits[#hits + 1] = a
        end
    end
    if #hits ~= 1 then
        log(string.format("ABORT %d `jsr $%04X` (%s) sites in $%04X..$%04X — expected 1",
                          #hits, target, what, lo, hi))
        return nil
    end
    return hits[1]
end
local function find_indirect(operand, lo, hi, what)
    local hits = {}
    for a = lo, hi do
        if mem:read_u8(a) == 0xAD and mem:read_u8(a + 1) == 0x9F
           and mem:read_u8(a + 2) * 256 + mem:read_u8(a + 3) == operand then
            hits[#hits + 1] = a
        end
    end
    if #hits ~= 1 then
        log(string.format("ABORT %d `jsr [$%04X]` (%s) sites — expected 1", #hits, operand, what))
        return nil
    end
    return hits[1]
end

local NOP, patched = 0x12, nil
local function apply()
    if MODE == "none" then return true end
    local site, n
    if MODE == "scenery" then
        site, n = find_direct(F.scenery_frame, F.chars_frame, F.chars_frame + 0x200,
                              "scenery_frame"), 3
    elseif MODE == "flicker" then
        site, n = find_direct(R.flicker, R.room_loop, R.room_loop + 0x300, "flicker"), 3
    elseif MODE == "nopeel" then
        -- ch_scan decides ch_anymove for the whole frame. NOP the call and clear the
        -- flag once: nothing sets it again, so the erase and save passes return
        -- immediately at char_one and only the draw pass does work. This is the SAME
        -- state the song holds reach naturally, which is what makes it the right control.
        site, n = find_direct(F.ch_scan, F.vm_frameadv, F.vm_frameadv + 0x20, "ch_scan"), 3
        if site then mem:write_u8(F.ch_anymove, 0) end
    elseif MODE == "chars" then
        local tab = R.CHARS_TAB or 0x3040
        site, n = find_indirect(tab, R.room_loop, R.room_loop + 0x300, "CHARS_TAB"), 4
    else
        log("ABORT unknown P_ABLATE " .. MODE); return false
    end
    if not site then return false end
    for i = 0, n - 1 do mem:write_u8(site + i, NOP) end
    patched = site
    log(string.format("# ablated %s: %d NOPs at $%04X", MODE, n, site))
    return true
end

-- ---------------------------------------------------------------
-- the same step/beat split as port_pace_split, so runs are comparable line for line
-- ---------------------------------------------------------------
-- ★ THE CYCLE CLOCK. An iteration is a whole number of frames, so its LENGTH says only
-- which side of a boundary the work fell on — never how far over. HAL_time_vbl_wait spins
-- `cmpb <hal_frame_lo` (4) + `beq` taken (3) = 7 cy and burns every cycle the engine is
-- not working, so counting spins per iteration recovers the work:
--
--     work = frames * 29,859 - spins * 7
--
-- which is the difference between "this iteration overran by 400 cycles" and "it overran
-- by a whole frame". Only that number can say whether the walk is fixable by making the
-- draw cheaper, or whether it needs the flip rate changed.
local spins = 0
_G._tsp = mem:install_read_tap(R.hal_vbl_spin, R.hal_vbl_spin, "sp", function(o, d)
    spins = spins + 1; return d
end)
local CY_PER_FRAME, SPIN_CY = 29859, 7

local beat, steps, iters = -1, {}, {}
_G._tb = mem:install_write_tap(F.vm_beat, F.vm_beat, "b", function(o, d)
    beat = beat + 1; return d
end)
_G._ts = mem:install_write_tap(F.cad_idx, F.cad_idx, "s", function(o, d)
    steps[#steps + 1] = { f = scr:frame_number(), b = beat }; return d
end)
_G._ti = mem:install_write_tap(R.flm_idx, R.flm_idx, "i", function(o, d)
    iters[#iters + 1] = { f = scr:frame_number(), s = spins, b = beat }; return d
end)

local state, t0, ok = "boot", nil, true
_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if state == "boot" then
        if fn >= 300 then nk:post('LOADM"ROOM"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if fn > t0 + 900 then
            nk:post('EXEC\n'); state = "run"
        end
        return
    end
    if state == "run" then
        -- patch AFTER the program is in RAM and before it has drawn much of anything
        if fn > t0 + 1100 then
            ok = apply(); state = ok and "armed" or "dead"
            if not ok then out:close(); manager.machine:exit() end
        end
        return
    end
    if fn < 5000 then return end

    local ivh, beath, n, tot = {}, {}, 0, 0
    for s = 2, #steps do
        local g = steps[s].f - steps[s - 1].f
        local b = steps[s - 1].b
        if g > 0 and g < 40 then
            n = n + 1; tot = tot + g
            ivh[g] = (ivh[g] or 0) + 1
            beath[b] = beath[b] or {}
            beath[b][g] = (beath[b][g] or 0) + 1
        end
    end
    local ith, work = {}, {}
    for i = 2, #iters do
        local g = iters[i].f - iters[i - 1].f
        if g > 0 and g < 40 then
            ith[g] = (ith[g] or 0) + 1
            local b = iters[i - 1].b
            local w = g * CY_PER_FRAME - (iters[i].s - iters[i - 1].s) * SPIN_CY
            local a = work[b]
            if not a then a = { n = 0, w = 0, fr = 0, wmax = 0 }; work[b] = a end
            a.n = a.n + 1; a.w = a.w + w; a.fr = a.fr + g
            if w > a.wmax then a.wmax = w end
        end
    end

    log("")
    log("# ITERATION PITCH (frames per room_loop draw iteration)")
    local ks = {}
    for k in pairs(ith) do ks[#ks + 1] = k end
    table.sort(ks)
    local itn, itt = 0, 0
    for _, k in ipairs(ks) do
        log(string.format("    %2d  x%d", k, ith[k])); itn = itn + ith[k]; itt = itt + k * ith[k]
    end
    log(string.format("    mean %.2f frames/iteration", itt / itn))

    log("")
    log("# WORK PER ITERATION, IN CYCLES — spins*7 removed, so this is the engine only.")
    log("# 3 frames = 89,577 cy. An iteration over that costs a 4th frame and the step slips.")
    log("    beat   iters   frames/it   work/it    peak      vs 3 frames")
    local wk = {}
    for k in pairs(work) do wk[#wk + 1] = k end
    table.sort(wk)
    for _, b in ipairs(wk) do
        local a = work[b]
        local w = a.w / a.n
        log(string.format("    %-6d %-7d %-11.2f %-10.0f %-9.0f %+.0f%%",
                          b, a.n, a.fr / a.n, w, a.wmax, 100 * (w - 3 * CY_PER_FRAME) / (3 * CY_PER_FRAME)))
    end

    log("")
    log("# STEP INTERVAL")
    ks = {}
    for k in pairs(ivh) do ks[#ks + 1] = k end
    table.sort(ks)
    for _, k in ipairs(ks) do log(string.format("    %2d  x%d", k, ivh[k])) end
    log(string.format("    %d steps, MEAN %.2f f/play   (cad_tab asks 6)", n, tot / n))

    log("")
    log("# BY BEAT (beat N here = scene beat N-1)")
    ks = {}
    for k in pairs(beath) do ks[#ks + 1] = k end
    table.sort(ks)
    for _, b in ipairs(ks) do
        local parts, bn, bt = {}, 0, 0
        local gk = {}
        for g in pairs(beath[b]) do gk[#gk + 1] = g end
        table.sort(gk)
        for _, g in ipairs(gk) do
            parts[#parts + 1] = string.format("%dx%d", g, beath[b][g])
            bn = bn + beath[b][g]; bt = bt + g * beath[b][g]
        end
        log(string.format("    beat %-3d n=%-4d mean %5.2f   %s", b, bn, bt / bn,
                          table.concat(parts, "  ")))
    end
    out:close()
    manager.machine:exit()
end)
