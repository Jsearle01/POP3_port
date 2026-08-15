-- port_blit_work.lua — P3.87: chars_frame costs 2.0 frames idle, 3.0 walking and 4.0
-- after Vexit. What is the WORK, per beat?
--
-- The two obvious explanations are already refuted by measurement, which is why this
-- exists rather than a conclusion:
--
--   NOT the hourglass — `flicker` is a flat 1.00 frames at every beat in the scene,
--     hourglass or no hourglass, sand or no sand [port_phase_cost.lua].
--   NOT clipping off the edge — CharX 132..166 across scene beat 16 maps through
--     co_setup's `px = 2*(x-58)+20, col = px/4` to columns 43..59 of 80. He is FULLY ON
--     SCREEN for that beat, and the beat already costs the full 5.00 frames/iteration
--     flat from its first step [port_exit_cost.lua].
--
-- So the cost is in what the character path BLITS. co_dims writes ch_h then ch_w on every
-- char_one call that resolves a cel, from the RESOLVED VARIANT's own header — which is
-- the authority on how big this draw is, and the only one (a sub-byte phase can add a
-- column). Tapping the second write and reading the first gives the exact extent of every
-- blit the frame performs, with no model in between.
--
-- The three passes are counted at their own entry points rather than inferred from ch_cp,
-- so an erase that returned early is not counted as an erase. §10a: PC == addr+1.
local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true
local out = io.open("build/tmp/port_blit_work.log", "w")
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

local beat, acc = -1, {}
local function A()
    local a = acc[beat]
    if not a then
        a = { it = 0, dims = 0, area = 0, erase = 0, save = 0, draw = 0,
              cel = 0, blast = 0, wmax = 0, hmax = 0, byw = {} }
        acc[beat] = a
    end
    return a
end

_G._tb = mem:install_write_tap(F.vm_beat, F.vm_beat, "beat", function(o, d)
    beat = beat + 1; return d
end)
_G._ti = mem:install_write_tap(R.flm_idx, R.flm_idx, "it", function(o, d)
    if beat >= 0 then A().it = A().it + 1 end; return d
end)

-- co_dims: `sta ch_h` then `sta ch_w`. Tap the SECOND and read the first — at that
-- instant both belong to the same resolved variant.
_G._tw = mem:install_write_tap(F.ch_w, F.ch_w, "w", function(o, d)
    if beat >= 0 then
        local a = A()
        local h = mem:read_u8(F.ch_h)
        a.dims = a.dims + 1
        a.area = a.area + d * h
        if d > a.wmax then a.wmax = d end
        if h > a.hmax then a.hmax = h end
        a.byw[d] = (a.byw[d] or 0) + 1
    end
    return d
end)

local ENTRY = { { "erase", F.co_erase }, { "save", F.co_save }, { "draw", F.co_draw },
                { "cel", F.blit_cel }, { "blast", F.blit_blast } }
_G._te = {}
for i, e in ipairs(ENTRY) do
    local key, addr = e[1], e[2]
    _G._te[i] = mem:install_read_tap(addr, addr, key, function(o, d)
        local ok, v = pcall(function() return cpu.state["PC"].value end)
        if ok and v == addr + 1 and beat >= 0 then A()[key] = A()[key] + 1 end
        return d
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

    log("# PER-ITERATION CHARACTER WORK, BY BEAT (beat N here = scene beat N-1)")
    log("#   dims  = char_one calls that resolved a cel")
    log("#   area  = sum of w*h over those, in BYTES of cel — the real work unit")
    log("#   e/s/d = co_erase / co_save / co_draw entries actually reached")
    log("#   cel   = blit_cel entries;  blast = blit_blast entries")
    log("")
    log("    beat  iters   dims   area/iter   e/it   s/it   d/it   cel/it  wmax hmax")
    local bk = {}
    for k in pairs(acc) do bk[#bk + 1] = k end
    table.sort(bk)
    for _, b in ipairs(bk) do
        local a = acc[b]
        if a.it > 0 then
            log(string.format("    %-5d %-7d %-6.2f %-11.0f %-6.2f %-6.2f %-6.2f %-7.2f %-4d %-4d",
                              b, a.it, a.dims / a.it, a.area / a.it, a.erase / a.it,
                              a.save / a.it, a.draw / a.it, a.cel / a.it, a.wmax, a.hmax))
        end
    end

    log("")
    log("# CEL WIDTH HISTOGRAM per beat (bytes) — a wider variant is a wider blit")
    for _, b in ipairs(bk) do
        local a = acc[b]
        if a.it > 0 then
            local ks = {}
            for k in pairs(a.byw) do ks[#ks + 1] = k end
            table.sort(ks)
            local parts = {}
            for _, k in ipairs(ks) do parts[#parts + 1] = string.format("w%d x%d", k, a.byw[k]) end
            log(string.format("    beat %-4d %s", b, table.concat(parts, "  ")))
        end
    end
    out:close()
    manager.machine:exit()
end)
