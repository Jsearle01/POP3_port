-- harness/tools/change_census.lua
--
-- POP P3.45 — HOW OFTEN DOES ANYTHING ON SCREEN ACTUALLY CHANGE?
--
-- P3.44 measured the frame at 57,074 cy — 192% of budget — and found no single
-- component removal fixes it (peel free = 107%, draw free = 102%). Its option 5 was not
-- an optimisation but a question: the port redraws and flips EVERY video frame, while
-- PA.2 measured the oracle flipping every 6.0 frames. If the port need not redraw every
-- frame, the arithmetic changes by more than any optimisation could.
--
-- This measures the ceiling on that: the fraction of engine iterations in which NOTHING
-- that reaches the screen changed. Those are the iterations a change-gated loop could
-- skip outright — 57,074 cy down to the ~343 cy P3.43 measured for loop + swap + IRQ.
--
-- ---------------------------------------------------------------
-- THE THREE THINGS THAT CHANGE, AND HOW EACH IS DETECTED
-- ---------------------------------------------------------------
-- 1. THE VM STEPS. `vm_nextframe` reaches `std vm_due` exactly on a step boundary and
--    nowhere else, so a WRITE-tap on vm_due is one event per animation step. Detected at
--    the engine's own store, not re-derived from the cadence table — the table says what
--    it intends, the store says what happened.
--
-- 2. A TORCH STEPS. `flicker` calls `next_flame` and stores `fl_state0` only when
--    `fl_step` is set, which is every FLAME_DIV-th iteration. A write-tap on fl_state0 is
--    one event per flame advance. (`torch_step` runs every iteration regardless — it
--    redraws the SAME cel into the alternate buffer — so tapping the draw would count
--    redraws, not changes. The state byte is the change.)
--
-- 3. A STAR LIGHTS OR GOES OUT. `ps_draw` writes `bg` for a dark star and `bg EOR eor`
--    for a lit one, so a star's appearance changes only when its lit/dark state flips —
--    NOT while it ages. `star_cnt` is decremented every frame a star is lit, so counting
--    writes to it would count ageing as change. The lit MASK is sampled per iteration and
--    compared instead, which is the quantity that actually reaches the screen.
--
-- ---------------------------------------------------------------
-- WHAT THIS IS NOT
-- ---------------------------------------------------------------
-- It is a CEILING on what a change-gated loop could skip, not a saving. Skipping a
-- redraw is only sound if the DISPLAYED buffer is already correct, which is a design
-- question this dispatch reports rather than settles. Nothing here is a recommendation
-- and nothing is built.
local OUT   = os.getenv("P_OUT")   or "build/change_census.log"
local LOOP  = tonumber(os.getenv("P_LOOP")   or "0x207C")
local VMDUE = tonumber(os.getenv("P_VMDUE")  or "0x3C70")
local FLST  = tonumber(os.getenv("P_FLST")   or "0x229E")
local STARS = tonumber(os.getenv("P_STARS")  or "0x22B5")
local FIRST = tonumber(os.getenv("P_FIRST")  or "1900")
local LAST  = tonumber(os.getenv("P_LAST")   or "3400")

local scr = manager.machine.screens:at(1)
local mem = manager.machine.devices[":maincpu"].spaces["program"]
local f   = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end

local state, t0 = "boot", nil
local armed, cur_frame = false, 0
local vm_hit, fl_hit = false, false
local prev_mask = nil
local iters, vm_n, fl_n, st_n, quiet, first_fn, last_fn = 0, 0, 0, 0, 0, nil, nil
local combo = {}          -- how the three sources co-occur

_G._vm_tap = mem:install_write_tap(VMDUE, VMDUE + 1, "vm_due", function(off, data, mask)
    if armed then vm_hit = true end
    return data
end)

_G._fl_tap = mem:install_write_tap(FLST, FLST, "fl_state0", function(off, data, mask)
    if armed then fl_hit = true end
    return data
end)

_G._loop_tap = mem:install_read_tap(LOOP, LOOP, "loop", function(off, data, mask)
    if not armed then return data end
    local fn = cur_frame
    -- lit MASK, not the counters: ageing is not a visible change
    local m = 0
    for i = 0, 3 do
        if mem:read_u8(STARS + i) ~= 0 then m = m | (1 << i) end
    end
    if fn >= FIRST and fn <= LAST and prev_mask ~= nil then
        iters = iters + 1
        if first_fn == nil then first_fn = fn end
        last_fn = fn
        local st = (m ~= prev_mask)
        if vm_hit then vm_n = vm_n + 1 end
        if fl_hit then fl_n = fl_n + 1 end
        if st      then st_n = st_n + 1 end
        if not vm_hit and not fl_hit and not st then quiet = quiet + 1 end
        local key = (vm_hit and "V" or "-") .. (fl_hit and "F" or "-") .. (st and "S" or "-")
        combo[key] = (combo[key] or 0) + 1
    end
    prev_mask = m
    vm_hit, fl_hit = false, false
    return data
end)

local function report()
    log("# CHANGE CENSUS — how often anything that reaches the screen changes")
    log(string.format("# sampled frames %d..%d", FIRST, LAST))
    if iters == 0 then
        log("# NO ITERATIONS SAMPLED — nothing reported")
        return
    end
    log(string.format("# %d iterations over %d video frames (%.3f frames/iter)",
                      iters, (last_fn or 0) - (first_fn or 0), ((last_fn or 0) - (first_fn or 0)) / iters))
    log(string.format("# VM stepped     in %5d of %d iterations (%.1f%%)", vm_n, iters, 100*vm_n/iters))
    log(string.format("# a torch stepped in %5d of %d iterations (%.1f%%)", fl_n, iters, 100*fl_n/iters))
    log(string.format("# a star changed  in %5d of %d iterations (%.1f%%)", st_n, iters, 100*st_n/iters))
    log(string.format("# NOTHING CHANGED in %5d of %d iterations (%.1f%%)  <- the skippable ceiling",
                      quiet, iters, 100*quiet/iters))
    local keys = {}
    for k in pairs(combo) do keys[#keys+1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        log(string.format("#   %s : %5d (%.1f%%)", k, combo[k], 100*combo[k]/iters))
    end
    log("# key: V=VM step  F=torch step  S=star lit/dark change  '-'=no change")
end

local nk = manager.machine.natkeyboard
nk.in_use = true

local function tick()
    cur_frame = scr:frame_number()
    local fn = cur_frame
    if state == "boot" then
        if fn >= 120 then nk:post('LOADM"ROOM"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if fn > t0 + 900 then nk:post('EXEC\n'); state = "wait" end
        return
    end
    if state == "wait" then
        if mem:read_u8(0x2008) > 0 then armed, state = true, "watch" end
        return
    end
    if fn > LAST then report(); manager.machine:exit() end
end

_G._notifier = emu.add_machine_frame_notifier(tick)
