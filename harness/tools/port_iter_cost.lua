-- port_iter_cost.lua — P3.102 §1: does the port's EXIT iteration cost more than its ENTRY
-- iteration, in TIME, even though the achieved step RATE is flat?
--
-- ★★★ THE QUESTION, AND WHY THE RATE CANNOT ANSWER IT. P3.101 measured the oracle's walk-out
-- at 1.074x its walk-in and the port's at 0.988x, and read the port's flatness as a
-- divergence. But the port's step fires only on a room-loop iteration boundary, and an
-- iteration is a whole number of video frames — so the port's achievable intervals are
-- 6, 8, 10 with NOTHING BETWEEN. ★ A PORT DOING THE ORACLE'S EXTRA WORK COULD NOT SHOW
-- 1.074. It could only show 1.000 or a whole-frame jump. Which is 0.988 and a block.
--
-- ★★ SO THE RATE IS THE WRONG INSTRUMENT AND THE ITERATION'S COST IS THE RIGHT ONE. If the
-- exit's work per iteration is higher than the entry's while the rate is flat, the grid is
-- the whole explanation and the port is faithful in WORK while diverging in APPEARANCE. If
-- the work is the same, the grid explains nothing and the divergence is real.
--
-- ★ THE LEAD IS THE ORCHESTRATOR'S AND IT IS TESTED, NOT ADOPTED. The mirror anchor led on
-- shape for four dispatches and was exonerated by measurement (P3.100).
--
-- HOW WORK IS SEPARATED FROM SLACK, which is the whole trick:
--
--   room_loop           [ ------- work ------- ][ ---- spin ---- ] room_loop
--                       ^                       ^
--                       iteration start         HAL_time_vbl_wait entry
--
-- `HAL_time_vbl_wait` spins on the frame counter [hal/coco3-dsk/time.s:129-141], so
-- everything before it is the frame's real cost and everything after is the loop waiting
-- for the raster. TOTAL is quantised to whole frames by construction; WORK IS NOT. That is
-- exactly why total cannot show a 7% change and work can.
--
-- ★ AND A READ-TAP HIT IS NOT AN EXECUTION COUNT [mame-idioms-coco3-port.md §10a] — data
-- and dummy reads of the same address fire too. Two consequences, both handled: the spin
-- count is used only as a RATIO between two populations in the same run, never as an
-- absolute; and the whole instrument is put through a seeded control that must move it.
--
-- P_SEED=1 forces `ch_anymove` to 0 on every write, which suppresses the frame-wide peel —
-- strictly LESS work, so measured work must FALL. ★ It also counts how many substitutions
-- actually CHANGED the value, because P3.101's version of this seed wrote 1 over a flag
-- that was already 1, perturbed nothing, and the run blamed the instrument.

local OUT   = os.getenv("P_OUT") or "build/tmp/port_iter_cost.log"
local TO    = tonumber(os.getenv("P_TO") or "5800")
local SEED  = os.getenv("P_SEED") == "1"
local BUCK  = tonumber(os.getenv("P_BUCKET") or "100")

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true
local out = io.open(OUT, "w")
local function log(s) out:write(s .. "\n"); out:flush() end

local function syms(path)
    local t = {}
    for line in io.lines(path) do
        local n, a = line:match("^Symbol: (%S+) .*= *(%x+)$")
        if n then t[n] = tonumber(a, 16) end
    end
    return t
end
local R, F = syms("build/obj/room.map"), syms("build/obj/flames.map")
for _, k in ipairs({ "room_loop", "HAL_time_vbl_wait", "hal_vbl_spin" }) do
    if not R[k] then log("FAIL no room symbol " .. k); out:close(); return end
end
for _, k in ipairs({ "viz_slot", "pri_slot", "ch_anymove" }) do
    if not F[k] then log("FAIL no flames symbol " .. k); out:close(); return end
end
local CH_FACE, CH_CEL = 3, 4               -- [char_draw.s:300-301]
local WALK_LO, WALK_HI = 48, 53
local HZ = 1.0e18 / scr.refresh_attoseconds        -- a PROPERTY, not a method
-- the CPU clock as MAME reports it, so "cycles" is stated in a unit with a source rather
-- than a remembered 1.79 MHz. The port runs double-speed ($FFD9), and whether MAME folds
-- that into `clock` is exactly the kind of thing not to assume — so MICROSECONDS is the
-- primary unit here and cycles are derived and labelled.
-- ⚠ `cpu.clock` IS NOT AVAILABLE on this MAME's device binding — it returns nil and the
-- report dies with "bad argument #4 to 'format' (number expected, got nil)" at the first
-- line that uses it. Probed rather than assumed, and MICROSECONDS remain the primary unit
-- regardless: the port switches the GIME to double speed at runtime [$FFD9], so even a
-- clock MAME did report would need checking before it could be called cycles.
local CLK = nil
for _, get in ipairs({ function() return cpu.clock end,
                       function() return cpu:clock() end,
                       function() return cpu.unscaled_clock end }) do
    local ok, v = pcall(get)
    if ok and type(v) == "number" and v > 0 then CLK = v; break end
end
local function cyc(sec)
    return CLK and string.format("%+.0f cycles @ %.0f Hz", sec * CLK, CLK)
                or "cycles not stated — MAME does not expose the device clock here"
end

local function now() return manager.machine.time:as_double() end

local iters, cur, spins, vblwait_t = {}, nil, 0, nil

_G._t_loop = mem:install_read_tap(R.room_loop, R.room_loop, "loop", function(off, data, mask)
    local t = now()
    if cur then
        cur.t_end = t
        cur.spin  = spins
        cur.work  = cur.vbl and (cur.vbl - cur.t_start) or nil
        cur.total = t - cur.t_start
        iters[#iters + 1] = cur
    end
    spins = 0
    cur = { t_start = t, f = scr:frame_number(),
            cel  = mem:read_u8(F.viz_slot + CH_CEL),
            face = mem:read_u8(F.viz_slot + CH_FACE),
            -- ★ THE PRINCESS IS SAMPLED TOO. PlayCut0 hands Pslump 28 plays WHILE Vexit is
            -- still looping [SUBS.S:742-748], so she is animating underneath the whole
            -- walk-out — and "the frame got dearer" and "the vizier got dearer" are
            -- different claims (P3.101 §3D.5, enumerated and never measured).
            pcel = F.pri_slot and mem:read_u8(F.pri_slot + CH_CEL) or -1,
            pface = F.pri_slot and mem:read_u8(F.pri_slot + CH_FACE) or -1,
            -- and his drawn COLUMN, because the one candidate P3.101 left standing is that
            -- the block is the stretch where his cel straddles the right clip edge
            -- (VIS_R = 74). If work is a function of column, that is what it looks like.
            col = (function()
                     if not F.ch_col then return -1 end
                     local v = mem:read_u8(F.ch_col) * 256 + mem:read_u8(F.ch_col + 1)
                     if v >= 0x8000 then v = v - 0x10000 end
                     return v
                   end)(),
            cw = F.ch_w and mem:read_u8(F.ch_w) or -1 }
    return data
end)

-- FIRST entry per iteration only: the idle arm of room_loop calls it once and the draw arm
-- calls it once inside room_present, but a mid-iteration re-entry would move work-end.
_G._t_vbl = mem:install_read_tap(R.HAL_time_vbl_wait, R.HAL_time_vbl_wait, "vblwait",
    function(off, data, mask)
        if cur and cur.vbl == nil then cur.vbl = now() end
        return data
    end)

_G._t_spin = mem:install_read_tap(R.hal_vbl_spin, R.hal_vbl_spin, "spin", function(off, data, mask)
    spins = spins + 1
    return data
end)

-- ★★ THE READ-BACK IS COUNTED, NOT LATCHED, AND IT ONLY COUNTS ONCE THE SEED HAS FIRED.
-- The first version set `seed_landed = false` on any frame where ch_anymove was non-zero —
-- including the boot frames BEFORE the engine had ever written it, when the byte still held
-- whatever DECB left there. One such frame condemned a seed that had in fact landed (work
-- fell 61.6 ms -> 38.2 ms in the same run). ★ A verification that can fail before the thing
-- it verifies exists is not a verification.
local seed_seen, seed_changed, seed_bad, seed_chk = 0, 0, 0, 0
if SEED then
    _G._t_any = mem:install_write_tap(F.ch_anymove, F.ch_anymove, "anymove", function(off, data, mask)
        seed_seen = seed_seen + 1
        if data ~= 0 then seed_changed = seed_changed + 1 end
        return 0
    end)
end

local state, t0, reported = "boot", nil, false
_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if reported then return end
    if state == "boot" then
        if fn >= 300 then nk:post('LOADM"ROOM"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if fn > t0 + 900 then nk:post('EXEC\n'); state = "run" end
        return
    end
    if SEED and seed_seen > 0 then
        seed_chk = seed_chk + 1
        if mem:read_u8(F.ch_anymove) ~= 0 then seed_bad = seed_bad + 1 end
    end
    if fn <= TO then return end
    reported = true

    -- ---- classify: the vizier's six walk cels, split by HIS OWN facing ---------------
    -- Same discriminator P3.100/P3.101 used: co_setup treats face<0 as NORMAL and face>=0
    -- as MIRRORED [char_draw.s:1472-1473], and Vexit is the only aboutface he makes.
    local function half(it)
        if it.cel < WALK_LO or it.cel > WALK_HI then return nil end
        return (it.face < 0x80) and "EXIT" or "ENTRY"
    end

    local acc = {}
    for _, it in ipairs(iters) do
        local h = half(it)
        if h and it.work and it.total and it.total < 0.5 then
            local a = acc[h] or { n = 0, w = 0, t = 0, s = 0, wmin = 9, wmax = 0 }
            a.n = a.n + 1; a.w = a.w + it.work; a.t = a.t + it.total; a.s = a.s + it.spin
            if it.work < a.wmin then a.wmin = it.work end
            if it.work > a.wmax then a.wmax = it.work end
            acc[h] = a
        end
    end

    log(string.format("# PORT ITERATION COST — work vs slack, %s", SEED and "SEEDED (peel off)" or "REAL"))
    log(string.format("# refresh %.6f Hz (1 frame = %.3f ms); CPU clock: %s",
                      HZ, 1000.0 / HZ, CLK and string.format("%.0f Hz", CLK) or "not exposed by MAME here"))
    log(string.format("# %d room_loop iterations recorded to frame %d", #iters, TO))
    if SEED then
        log(string.format("# ★ SEED: ch_anymove -> 0 on every write; %d writes, %d of them CHANGED the",
                          seed_seen, seed_changed))
        log(string.format("#   value; read-back: %d of %d sampled frames held 0 (%s)",
                          seed_chk - seed_bad, seed_chk,
                          seed_bad == 0 and "CONFIRMS the seed holds"
                                        or "some frames did not — see below"))
        if seed_changed == 0 then
            log("# SEED INEFFECTIVE: no substitution changed the value — nothing was perturbed,")
            log("#   so no change in the measurement is expected and none is evidence (P3.101).")
        end
    end
    log("")
    log("# WORK is room_loop -> the first HAL_time_vbl_wait entry: the frame's real cost.")
    log("# SLACK is the rest of the iteration, spent spinning on the frame counter.")
    log("# ★ TOTAL IS QUANTISED TO WHOLE FRAMES BY CONSTRUCTION AND WORK IS NOT, which is")
    log("#   the entire reason the achieved step RATE cannot answer this question.")
    log("")
    log("    half    iters   WORK ms   (min..max)      TOTAL ms  slack ms  spin hits/iter")
    for _, h in ipairs({ "ENTRY", "EXIT" }) do
        local a = acc[h]
        if a and a.n > 0 then
            log(string.format("    %-7s %-7d %-9.3f (%.3f..%.3f) %-9.3f %-9.3f %.1f",
                              h, a.n, a.w / a.n * 1000, a.wmin * 1000, a.wmax * 1000,
                              a.t / a.n * 1000, (a.t - a.w) / a.n * 1000, a.s / a.n))
        else
            log(string.format("    %-7s (none)", h))
        end
    end
    if acc.ENTRY and acc.EXIT and acc.ENTRY.n > 0 and acc.EXIT.n > 0 then
        local we, wx = acc.ENTRY.w / acc.ENTRY.n, acc.EXIT.w / acc.EXIT.n
        local te, tx = acc.ENTRY.t / acc.ENTRY.n, acc.EXIT.t / acc.EXIT.n
        log("")
        log(string.format("# ★ WORK  exit/entry = %.3f   (%.3f ms -> %.3f ms, %+.3f ms; %s)",
                          wx / we, we * 1000, wx * 1000, (wx - we) * 1000, cyc(wx - we)))
        log(string.format("# ★ TOTAL exit/entry = %.3f   (%.3f ms -> %.3f ms)", tx / te, te * 1000, tx * 1000))
        log("# The oracle's step-rate ratio for the same two walks is 1.074 [P3.101].")
    end

    -- ---- work over time, so the 100-frame block is visible as a cost or is not --------
    log("")
    log(string.format("# WORK PER ITERATION over the scene, %d-frame buckets. The 10-frame block", BUCK))
    log("# P3.101 measured runs f4702..f4802; if it is a cost event it is a bump HERE.")
    log(string.format("# ★ A 4-FRAME ITERATION IS %.3f ms. Work BELOW that rounds to 4 frames and a",
                      4000.0 / HZ))
    log("#   step (two iterations) lands on 8; work ABOVE it rounds to 5 and the step is 10.")
    log("    frames        iters  WORK ms   TOTAL ms  frames/iter  viz  col  ch_w  pri")
    local i = 1
    while i <= #iters do
        local lo = iters[i].f - (iters[i].f % BUCK)
        local n, w, t, s, j = 0, 0, 0, 0, i
        while j <= #iters and iters[j].f < lo + BUCK do
            if iters[j].work and iters[j].total and iters[j].total < 0.5 then
                n = n + 1; w = w + iters[j].work; t = t + iters[j].total; s = s + iters[j].spin
            end
            j = j + 1
        end
        if n > 0 and lo >= 2800 then
            log(string.format("    %-5d..%-7d %-6d %-9.3f %-9.3f %-12.2f %-4d %-4d %-5d %d",
                              lo, lo + BUCK - 1, n, w / n * 1000, t / n * 1000,
                              (t / n) * HZ, iters[i].cel, iters[i].col, iters[i].cw,
                              iters[i].pcel))
        end
        i = j
    end
    out:close()
    manager.machine:exit()
end)
