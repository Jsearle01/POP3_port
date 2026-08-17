-- port_phase_cost.lua — P3.87: WHERE inside a room_loop iteration do the extra frames go?
--
-- port_pace_split.lua established the mechanism and the split:
--
--   * the room loop never idles (787 iterations, 787 draws — flm_due is ALWAYS past)
--   * an iteration costs 3 video frames baseline and the animation step can only fire on
--     an iteration boundary, so a 6-frame cad_tab lands exactly on the 2nd one: SIX.
--   * a 4- or 5-frame iteration pushes that boundary out and the step becomes 8 or 10.
--     That is the whole of the 19% — there is no gradual overrun anywhere in it.
--   * and the slip is NOT jitter, it is CONTENT, deterministic per beat:
--         beats 1 / 6 / 10  (song holds, nothing moves)      6.00, 6.02, 6.00
--         beats 16 / 17 / 18 (after the hourglass switches)   10.00, 10.00, 10.00
--     Fifty-four consecutive steps at exactly 10 is not a load average.
--
-- ★ AND BEAT 16 IS A HOLD, exactly like beats 1/6/10. Same kind of beat, same pinned-only
-- cels, +4 frames per step. So the extra cost is not the characters' animation — it is
-- something switched on between beat 14 (6.25) and beat 16 (10.00), i.e. across Vexit.
--
-- THIS TOOL DOES NOT GUESS WHICH. It read-taps the four phase entries of one iteration —
--
--     rl_draw       $2091   the top of a drawing iteration
--     flicker       $20E6   torches, stars, sand, hourglass
--     chars_frame   $3B14   the VM: decide, peel, draw both characters
--     room_present  $22D2   VBL wait, VOFFSET move, re-map
--
-- — and reports each phase's cost per beat. §10a of the idioms file is why the PC is
-- checked at every hit: a read-tap fires on DATA and DUMMY reads of the same address too,
-- so a hit is not a call. PC == addr+1 means the opcode was fetched and executed; PC ==
-- addr means the byte was merely read. Counting hits without that discriminator measured
-- a NOPped-out routine at 0.23 calls/iteration in P3.43.
--
-- The clock is (frame_number, vpos) — scanline resolution, not frame resolution, because
-- a 3-frame iteration split four ways cannot be resolved by whole frames.
local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true
local out = io.open("build/tmp/port_phase_cost.log", "w")
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

local PHASE = {
    { name = "rl_draw",      addr = R.rl_draw },
    { name = "flicker",      addr = R.flicker },
    { name = "chars_frame",  addr = F.chars_frame },
    { name = "room_present", addr = R.room_present },
}
for _, p in ipairs(PHASE) do
    if not p.addr then log("FAIL no symbol " .. p.name); out:close(); return end
end
local VM_BEAT, CEL_PLAN, PLAN_STRIDE = F.vm_beat, F.cel_plan, 6
log("# phase entries: " .. (function()
    local t = {}
    for _, p in ipairs(PHASE) do t[#t + 1] = string.format("%s $%04X", p.name, p.addr) end
    return table.concat(t, "  ")
end)())

-- ★ NOTHING BUT A FRAME NUMBER IS READ INSIDE A TAP. The first version called scr:vpos()
-- for scanline resolution and mem:read_u8(vm_beat) for the beat; `vpos` does not exist on
-- this MAME's screen object, the callback threw, and every hit was COUNTED (the increment
-- happens first) while nothing was recorded. Entry counts came out clean and plausible —
-- 786/786/786/786 — over an empty event list, which is the failure mode worth naming: a
-- tap that dies mid-callback still looks like it worked from the outside.
--
-- So the beat comes from its own WRITE tap instead. vb_apply does `stu vm_beat` exactly
-- once per beat transition, so counting those writes IS the beat index and no read of
-- emulated memory is needed anywhere.
local beat = -1
_G._tb = mem:install_write_tap(VM_BEAT, VM_BEAT, "beat", function(o, d)
    beat = beat + 1; return d
end)

local ev, hits, datahits = {}, {}, {}
_G._taps = {}
for i, p in ipairs(PHASE) do
    hits[p.name], datahits[p.name] = 0, 0
    _G._taps[i] = mem:install_read_tap(p.addr, p.addr, p.name, function(offset, data)
        local pc
        local ok, v = pcall(function() return cpu.state["PC"].value end)
        if ok then pc = v end
        if pc == p.addr + 1 then                      -- executed, not merely read (§10a)
            hits[p.name] = hits[p.name] + 1
            ev[#ev + 1] = { k = p.name, f = scr:frame_number(), b = beat }
        else
            datahits[p.name] = datahits[p.name] + 1
        end
        return data
    end)
end

local state, t0 = "boot", nil
_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if state == "boot" then
        if fn >= 300 then nk:post('LOADM"ROOM"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if fn > t0 + 900 then nk:post('EXEC\n'); state = "run" end
        return
    end
    if fn < 5000 then return end

    local LINES = 1
    local function t(e) return e.f end
    log(string.format("# %d events, last beat %d", #ev, beat))
    log("# entry counts (executed / merely-read — §10a discriminator)")
    for _, p in ipairs(PHASE) do
        log(string.format("    %-13s exec %-6d data %-6d", p.name,
                          hits[p.name], datahits[p.name]))
    end

    -- Slice into iterations: rl_draw .. next rl_draw. Inside one, the phases must appear
    -- in order; an iteration missing a phase is DROPPED rather than guessed at.
    local order = { "rl_draw", "flicker", "chars_frame", "room_present" }
    local acc = {}                       -- beat -> {n, phase sums, total}
    local iters = {}
    local cur = nil
    for _, e in ipairs(ev) do
        if e.k == "rl_draw" then
            if cur then cur.endt = t(e); iters[#iters + 1] = cur end
            cur = { b = e.b, m = { rl_draw = t(e) } }
        elseif cur then
            cur.m[e.k] = cur.m[e.k] or t(e)
        end
    end

    local dropped = 0
    for _, it in ipairs(iters) do
        local ok = it.endt ~= nil
        for _, k in ipairs(order) do if not it.m[k] then ok = false end end
        local total = ok and (it.endt - it.m.rl_draw) or 0
        if ok and total > 0 and total < 12 * LINES then     -- drop the staged-read hold
            local a = acc[it.b]
            if not a then
                a = { n = 0, tot = 0, pre = 0, flick = 0, chars = 0, pres = 0 }
                acc[it.b] = a
            end
            a.n = a.n + 1
            a.tot   = a.tot   + total
            a.pre   = a.pre   + (it.m.flicker      - it.m.rl_draw)
            a.flick = a.flick + (it.m.chars_frame  - it.m.flicker)
            a.chars = a.chars + (it.m.room_present - it.m.chars_frame)
            a.pres  = a.pres  + (it.endt           - it.m.room_present)
        else
            dropped = dropped + 1
        end
    end
    log(string.format("# %d iterations, %d dropped (staged-read holds / partial)",
                      #iters, dropped))

    log("")
    log("# PER-BEAT ITERATION COST, IN VIDEO FRAMES (1.00 = 29,859 cy)")
    log("#   pre     = rl_draw -> flicker      (the cadence bookkeeping)")
    log("#   flicker = flicker -> chars_frame  (torches, stars, sand, HOURGLASS)")
    log("#   chars   = chars_frame -> present  (VM decide + peel + draw, + staged read)")
    log("#   present = present -> next rl_draw (VBL wait, VOFFSET, re-map)")
    log("")
    log("    beat   n     total    pre   flicker   chars  present")
    local bk = {}
    for k in pairs(acc) do bk[#bk + 1] = k end
    table.sort(bk)
    for _, b in ipairs(bk) do
        local a = acc[b]
        log(string.format("    %-6d %-5d %6.2f  %6.2f  %6.2f  %6.2f  %6.2f",
                          b, a.n, a.tot / a.n / LINES, a.pre / a.n / LINES,
                          a.flick / a.n / LINES, a.chars / a.n / LINES,
                          a.pres / a.n / LINES))
    end
    out:close()
    manager.machine:exit()
end)
