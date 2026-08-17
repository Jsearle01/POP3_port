-- port_pace_split.lua — P3.87: ATTRIBUTE the 19% step-rate slip by SPLIT, not by elimination.
--
-- P3.85d measured the symptom and eliminated one suspect:
--
--     6 frames x263   7 x1   8 x61   10 x66     mean 6.99, cad_tab asks 6
--
-- ★ AND THE HISTOGRAM IS ALMOST ENTIRELY EVEN. 6, 8, 10 with a single 7 in 391 steps is
-- not the shape of a draw that gradually overruns a budget — a spread cost lands on 7 and
-- 9 as often as on 8 and 10. It is the shape of a step that can only fire on a GRID, and
-- the grid pitch is 2 frames.
--
-- That grid is the room loop: vm_nextframe is reached only through chars_frame, which the
-- room calls only on a draw iteration [cutscene_room.s rl_draw], and room_present ends
-- every iteration on a VBL wait. So the step interval is not the draw's cost — it is the
-- SUM OF WHOLE ITERATIONS, and 8 means one iteration in that step cost 4 frames where the
-- others cost 2.
--
-- THIS TOOL DOES NOT ARGUE THAT; IT SPLITS IT. Three write taps, no inference between:
--
--   rl_now   ($230C, hi byte)  — EVERY room_loop iteration, idle spins included
--   flm_idx  ($2309)           — only the iterations that DRAW and FLIP
--   cad_idx  ($3F9F)           — the animation step [one write per step, vm_nextframe]
--
-- and vm_beat is read at the step tap. vm_beat_tick runs AFTER the cad_idx write, so the
-- pointer still holds the beat that was in force across the interval just ended — which is
-- the beat that interval should be attributed to, not the one about to start.
--
-- The four questions it answers, each as a table rather than a claim:
--   1. is the interval a whole number of draw iterations?      (grid, or not)
--   2. what does an 8 decompose into — 2+2+4, or 4+2+2?        (WHICH iteration is heavy)
--   3. are the slips uniform, or concentrated in some beats?   (content, or overhead)
--   4. do idle spins exist at all?                             (is the torch ever ahead?)
local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true
local out = io.open("build/tmp/port_pace_split.log", "w")
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

local need = { cad_idx = F.cad_idx, vm_beat = F.vm_beat, cel_plan = F.cel_plan,
               flm_idx = R.flm_idx, rl_now = R.rl_now }
for k, v in pairs({ "cad_idx", "vm_beat", "cel_plan", "flm_idx", "rl_now" }) do
    if not need[v] then log("FAIL no symbol " .. v); out:close(); return end
end
log(string.format("# cad_idx $%04X  vm_beat $%04X  cel_plan $%04X  flm_idx $%04X  rl_now $%04X",
                  need.cad_idx, need.vm_beat, need.cel_plan, need.flm_idx, need.rl_now))

local PLAN_STRIDE = 6

-- one ordered event list; the ORDER inside a frame is what tells a step from the iteration
-- that carried it, and both share a frame number.
local ev = {}
local function rec(kind, extra)
    ev[#ev + 1] = { f = scr:frame_number(), k = kind, x = extra }
end

_G._t1 = mem:install_write_tap(need.rl_now, need.rl_now, "top", function(o, d)
    rec("top"); return d
end)
_G._t2 = mem:install_write_tap(need.flm_idx, need.flm_idx, "drw", function(o, d)
    rec("drw"); return d
end)
_G._t3 = mem:install_write_tap(need.cad_idx, need.cad_idx, "stp", function(o, d)
    local p = mem:read_u8(need.vm_beat) * 256 + mem:read_u8(need.vm_beat + 1)
    local b = -1
    if p >= need.cel_plan then b = (p - need.cel_plan) // PLAN_STRIDE end
    rec("stp", b)
    return d
end)

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

    -- ---------------------------------------------------------------
    -- slice the event stream into steps
    -- ---------------------------------------------------------------
    local steps = {}           -- {f, beat, idx into ev}
    for i, e in ipairs(ev) do
        if e.k == "stp" then steps[#steps + 1] = { f = e.f, beat = e.x, i = i } end
    end
    local kn = {}
    for _, e in ipairs(ev) do kn[e.k] = (kn[e.k] or 0) + 1 end
    log(string.format("# %d events, %d steps   (top=%d drw=%d stp=%d)",
                      #ev, #steps, kn.top or 0, kn.drw or 0, kn.stp or 0))

    -- ★ RAW FIRST, HISTOGRAM SECOND. A composition histogram is a summary of an ordering,
    -- and a summary cannot show an ordering that is not what the summariser assumed.
    log(""); log("# RAW EVENT TIMELINE — 60 events from the first step after the room is up")
    local lo = steps[2] and steps[2].i or 1
    local line, lf = {}, nil
    for i = lo, math.min(lo + 59, #ev) do
        local e = ev[i]
        if e.f ~= lf then
            if #line > 0 then log("    " .. table.concat(line, " ")) end
            line = { string.format("f%-6d", e.f) }; lf = e.f
        end
        line[#line + 1] = e.k .. (e.k == "stp" and ("(b" .. e.x .. ")") or "")
    end
    if #line > 0 then log("    " .. table.concat(line, " ")) end

    local ivh, comph, beath, drawgap, topgap = {}, {}, {}, {}, {}
    local slipped, honoured = {}, {}
    local n, tot = 0, 0

    for s = 2, #steps do
        local a, b = steps[s - 1], steps[s]
        local gap = b.f - a.f
        if gap > 0 and gap < 40 then            -- the staged read is a hold, not a step
            n = n + 1; tot = tot + gap
            ivh[gap] = (ivh[gap] or 0) + 1
            local bk = a.beat
            beath[bk] = beath[bk] or {}
            beath[bk][gap] = (beath[bk][gap] or 0) + 1

            -- the DRAW iterations that composed this interval, as their frame gaps.
            -- a.i is the step tap; the iteration that carried it wrote flm_idx just
            -- before, at the same frame — so walk forward from a.i and take every "drw"
            -- up to and including the one carrying b.
            local marks, last = {}, a.f
            for i = a.i, b.i do
                if ev[i].k == "drw" and ev[i].f >= a.f then
                    if #marks > 0 or ev[i].f > a.f then
                        marks[#marks + 1] = ev[i].f - last
                        last = ev[i].f
                    end
                end
            end
            if b.f > last then marks[#marks + 1] = b.f - last end
            local key = table.concat(marks, "+")
            comph[key] = (comph[key] or 0) + 1
            for _, g in ipairs(marks) do drawgap[g] = (drawgap[g] or 0) + 1 end
            if gap == 6 then honoured[key] = (honoured[key] or 0) + 1
            else slipped[key] = (slipped[key] or 0) + 1 end
        end
    end

    -- every loop iteration, drawing or idle
    local prev = nil
    for _, e in ipairs(ev) do
        if e.k == "top" then
            if prev then
                local g = e.f - prev
                if g < 40 then topgap[g] = (topgap[g] or 0) + 1 end
            end
            prev = e.f
        end
    end

    local function dump(title, h, note)
        log(""); log("# " .. title)
        local keys = {}
        for k in pairs(h) do keys[#keys + 1] = k end
        table.sort(keys, function(p, q)
            if type(p) == "number" then return p < q end
            return (h[p] > h[q]) or (h[p] == h[q] and p < q)
        end)
        for _, k in ipairs(keys) do
            log(string.format("    %-14s x%-4d %s", tostring(k), h[k],
                              string.rep("#", math.min(50, h[k]))))
        end
        if note then log("    " .. note) end
    end

    dump("STEP INTERVAL (frames between consecutive animation steps)", ivh)
    log(string.format("    %d steps, mean %.2f f/play  (cad_tab asks 6)", n, tot / n))

    dump("ROOM LOOP ITERATION PITCH — every iteration, idle spins included (rl_now)", topgap,
         "if this is 2 with nothing at 1, the loop never idles and 2 frames IS the grid")
    dump("DRAW ITERATION PITCH — only iterations that drew and flipped (flm_idx)", drawgap)
    dump("INTERVAL COMPOSITION — the draw-iteration gaps that make up each step", comph)
    dump("COMPOSITION of the HONOURED (6-frame) steps", honoured)
    dump("COMPOSITION of the SLIPPED steps", slipped)

    log(""); log("# STEP INTERVAL BY BEAT — is the slip uniform, or is it content?")
    local bk = {}
    for k in pairs(beath) do bk[#bk + 1] = k end
    table.sort(bk)
    for _, b in ipairs(bk) do
        local parts, bn, bt = {}, 0, 0
        local gk = {}
        for g in pairs(beath[b]) do gk[#gk + 1] = g end
        table.sort(gk)
        for _, g in ipairs(gk) do
            parts[#parts + 1] = string.format("%dx%d", g, beath[b][g])
            bn = bn + beath[b][g]; bt = bt + g * beath[b][g]
        end
        log(string.format("    beat %-3d  n=%-4d mean %.2f   %s",
                          b, bn, bt / bn, table.concat(parts, "  ")))
    end

    out:close()
    manager.machine:exit()
end)
