-- port_residue_writers.lua — P3.90: WHO writes the bytes that go stale when the hourglass
-- body is cached?
--
-- P3.87 cached the static glass body per buffer, reached the boundary it was aiming at
-- (the last three beats went 10.00 -> 8.00 f/play) and was reverted because a
-- framebuffer diff at matched step indices showed RESIDUE — growing, 138 -> 576 bytes,
-- appearing the moment the glass appears. A 7-byte `rmb` control diffed IDENTICAL, so it
-- is the logic and not the bundle growing.
--
-- ★ AND THE PART THAT DID NOT ADD UP, WHICH IS WHY THIS EXISTS RATHER THAN A THEORY: the
-- residue is at the VIZIER'S EXIT COLUMNS 44..57, not at the glass's 38..44. The leading
-- explanation (a character's erase punches the body, its own save re-captures the punched
-- state, and only the next frame's redraw clears it) fits the GROWTH and does not fit the
-- LOCATION. P3.88 reported it as a fit, not an attribution, and §4 of P3.90 makes it the
-- gate on the whole optimisation: do not cost the removal until this is known.
--
-- METHOD: tap a handful of framebuffer bytes inside the residue and record WHO WROTE
-- THEM — the PC at the moment of the write, resolved to the nearest preceding symbol out
-- of the link maps. Run it on the shipping build and on the cached-body build and diff
-- the writer sets. Whatever writes the correct background in one and not the other IS the
-- mechanism; no inference in between.
--
-- ★ THE FRAMEBUFFER IS BANKED, so a tap on a LOGICAL address fires for whichever buffer
-- is mapped at that instant. That is what is wanted here (both buffers are of interest),
-- but it means the buffer identity has to be recorded alongside, not assumed — so
-- HAL_gfx_cur_back is sampled at every hit.
local OUT   = os.getenv("P_OUT") or "build/tmp/residue_writers.log"
local ROW   = tonumber(os.getenv("P_ROW") or "120")
local COL0  = tonumber(os.getenv("P_COL0") or "53")
local COL1  = tonumber(os.getenv("P_COL1") or "57")
local FROM  = tonumber(os.getenv("P_FROM") or "4200")
local TO    = tonumber(os.getenv("P_TO") or "4950")
local FB_BASE, STRIDE = 0x8000, 80

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true
local out = io.open(OUT, "w")
local function log(s) out:write(s .. "\n"); out:flush() end

-- ── symbol resolution: nearest preceding label, so a PC lands in a ROUTINE ───────────
-- The enclosing routine is the fact, not the address (P3.46b). A bare PC in a log is a
-- number nobody can act on; the routine it sits inside is the finding.
local syms = {}
local function readmap(path, tag)
    local f = io.open(path, "r")
    if not f then return end
    f:close()
    for line in io.lines(path) do
        local n, a = line:match("^Symbol: (%S+) .*= *(%x+)$")
        if n then
            local v = tonumber(a, 16)
            if v and v < 0x10000 then syms[#syms + 1] = { a = v, n = n, t = tag } end
        end
    end
end
readmap("build/obj/flames.map", "F")
readmap("build/obj/room.map", "R")
table.sort(syms, function(p, q) return p.a < q.a end)

local function whose(pc)
    local best
    for _, s in ipairs(syms) do
        if s.a <= pc then best = s else break end
    end
    if not best then return string.format("$%04X", pc) end
    return string.format("%s+%d", best.n, pc - best.a)
end

local CURBACK = nil
for _, s in ipairs(syms) do if s.n == "HAL_gfx_cur_back" then CURBACK = s.a end end

local hits, order = {}, {}
local lo = FB_BASE + ROW * STRIDE + COL0
local hi = FB_BASE + ROW * STRIDE + COL1
log(string.format("# tapping $%04X..$%04X (row %d cols %d..%d), frames %d..%d",
                  lo, hi, ROW, COL0, COL1, FROM, TO))

_G._tap = mem:install_write_tap(lo, hi, "res", function(offset, data)
    local fn = scr:frame_number()
    if fn < FROM or fn > TO then return data end
    local pc = 0
    local ok, v = pcall(function() return cpu.state["PC"].value end)
    if ok then pc = v end
    local back = CURBACK and mem:read_u8(CURBACK) or -1
    local key = whose(pc)
    local h = hits[key]
    if not h then
        h = { n = 0, first = fn, last = fn, vals = {}, backs = {} }
        hits[key] = h; order[#order + 1] = key
    end
    h.n = h.n + 1; h.last = fn
    h.vals[data] = (h.vals[data] or 0) + 1
    h.backs[back] = (h.backs[back] or 0) + 1
    return data
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
    if fn <= TO then return end

    log("")
    log("# WRITERS into the residue window, by enclosing routine")
    log("    routine                    writes   frames        buffers   values")
    for _, k in ipairs(order) do
        local h = hits[k]
        local vs, bs = {}, {}
        for v, c in pairs(h.vals) do vs[#vs + 1] = string.format("$%02X x%d", v, c) end
        for b, c in pairs(h.backs) do bs[#bs + 1] = string.format("%d:%d", b, c) end
        table.sort(vs); table.sort(bs)
        log(string.format("    %-26s %-8d %d..%-8d %-9s %s",
                          k, h.n, h.first, h.last, table.concat(bs, " "),
                          table.concat(vs, " ")))
    end
    if #order == 0 then log("    (no writes at all in the window)") end
    out:close()
    manager.machine:exit()
end)
