-- port_exit_stall.lua — P3.101: WHAT costs the extra two frames, for one hundred frames?
--
-- ★★★ THE BLOCK IS MEASURED AND UNATTRIBUTED. The port's exit walk holds each cel a modal
-- 8 frames, and between f4702 and f4802 it holds ten CONSECUTIVE cels for 10 — a 25%
-- slowdown lasting 1.67 s, one and two-thirds walk cycles, inside a single beat, with 8s
-- either side. The oracle's exit has nothing of the shape: its longest excursion is one
-- 8 among 6s and 7s [oracle_exit_column.lua, this dispatch].
--
-- ★★ AND THE STEP INTERVAL IS A COST MEASUREMENT IN DISGUISE. `vm_nextframe` fires when
-- `vm_now - vm_due >= 0` and the check runs ONCE PER LOOP ITERATION, so the achieved
-- interval is the first iteration boundary at or after the due frame [char_draw.s:1993-
-- 2009]. A step that takes 10 frames where the table asked 6 is not a scheduling
-- decision — it is the loop iterating more slowly. So: count ITERATIONS PER FRAME across
-- the window and the 10-block must show as a dip. If it does not, the premise is wrong
-- and that is worth more than the answer.
--
-- WHAT ELSE IS SAMPLED, and all of it is state the scene already publishes:
--   vm_beat     the schedule cursor — already known not to change across the block
--   vm_scenery  the scenery flags
--   sc_flow     the hourglass sand's flow state (P3.93/P3.94)
--   ch_anymove  the frame-wide peel gate: when anything moves, EVERYBODY peels
--               [char_draw.s:793-837], so this is the single biggest per-frame cost swing
--               the engine has, and it is a whole-frame flag rather than a per-character
--               one.
--   probe_loads the staged cel-page disk reads, which freeze the loop for seconds
--
-- ★ THE LOOP TAP IS A READ-TAP ON AN EXECUTION ADDRESS, which works on 6809 and does not
-- on the 6502 oracle [mame-idioms-coco3-port.md §10]. §10a also applies: a tap hit is not
-- an execution check. Here the count is compared against a SEEDED control rather than
-- trusted — P_SEED=1 forces `ch_anymove` to 0 every frame, which suppresses the peel, and
-- the iteration rate must RISE. A counter that does not move when the work halves is not
-- counting work. (It forced the flag to 1 first, which was a no-op — see the seed below.)
local OUT   = os.getenv("P_OUT") or "build/tmp/port_exit_stall.log"
local FROM  = tonumber(os.getenv("P_FROM") or "4400")
local TO    = tonumber(os.getenv("P_TO") or "5100")
local BUCK  = tonumber(os.getenv("P_BUCKET") or "20")
local SEED  = os.getenv("P_SEED") == "1"

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
for _, k in ipairs({ "room_loop", "probe_loads" }) do
    if not R[k] then log("FAIL no room symbol " .. k); out:close(); return end
end
for _, k in ipairs({ "vm_beat", "vm_scenery", "sc_flow", "ch_anymove", "viz_slot",
                     "ch_dest", "ch_idx", "ch_w", "ch_col" }) do
    if not F[k] then log("FAIL no flames symbol " .. k); out:close(); return end
end
local CH_CEL = 4
local HZ = 1.0e18 / scr.refresh_attoseconds   -- a PROPERTY, not a method

local iters, cur_frame, rows = 0, 0, {}
_G._t_loop = mem:install_read_tap(R.room_loop, R.room_loop, "loop", function(off, data, mask)
    iters = iters + 1
    return data
end)

-- ★★★ THE SEED FORCES THE PEEL **OFF**, AND THE FIRST VERSION FORCED IT **ON** — WHICH
-- WAS A NO-OP, AND THE CONTROL REPORTED IT AS A FAILURE OF THE COUNTER.
--
-- `ch_anymove` reads 1 on every sampled frame of this window already (the vizier is
-- walking, and the gate is frame-wide: if anything moved, everybody peels
-- [char_draw.s:793-837]). Substituting 1 for 1 changed nothing, the iteration rate did not
-- move, and the run printed "the counter did not fall when the work rose" — a verdict on
-- the counter drawn from a perturbation that never perturbed anything.
--
-- ★★ THAT IS P3.100's SEED LESSON IN ITS THIRD FORM. First the seed's WRITE was discarded;
-- then the seed had no BEFORE population to compare against; now the seed wrote a value
-- the target already held. All three produce "no effect observed", and none of them is
-- evidence about the instrument. So the seed now forces 0 — strictly LESS work, so the
-- rate must RISE — and the tool counts how many frames already held the forced value and
-- says SEED INEFFECTIVE outright if that is most of them.
local SEED_VAL = 0
local seed_landed, seed_seen, seed_noop = true, 0, 0
if SEED then
    _G._t_any = mem:install_write_tap(F.ch_anymove, F.ch_anymove, "anymove", function(off, data, mask)
        seed_seen = seed_seen + 1
        if data == SEED_VAL then seed_noop = seed_noop + 1 end
        return SEED_VAL
    end)
end

-- per-frame draw counts, by character — the princess's own beats run under the vizier's
-- walk-out (PlayCut0 hands Pslump 28 plays while Vexit is still looping), so "the frame
-- got more expensive" and "the vizier got more expensive" are different claims.
local dr = { [0] = 0, [1] = 0 }
-- ★ AND THE CLIP WINDOW, PER DRAW, FOR THE VIZIER. The 10-block coincides with his column
-- crossing VIS_R (=74): during it he goes col 68 -> 75, which is exactly the stretch where
-- the cel STRADDLES the right edge — partly drawn, partly suppressed. Coincidence is not
-- attribution, so the numbers that would settle it are recorded rather than argued: bc_keep
-- is the count of bytes the blitter actually writes and ch_w is how many the cel has, so
-- `bc_keep < ch_w and bc_keep > 0` IS "partially clipped", straight off the machine
-- [char_draw.s:1497-1535]. If the dip's window and the partial-clip window are the same
-- window, that is an attribution; if they are not, the clip is refuted and the cost is
-- something else.
local vw, pend_lead, pend_keep = nil, nil, nil
-- ★★ bc_keep IS TAPPED AT ITS OWN WRITE, NOT READ AT THE ch_dest WRITE, AND THE FIRST CUT
-- GOT THAT WRONG. co_setup stores ch_dest and computes the clip window AFTERWARDS
-- [char_draw.s:1495 then 1497-1535], so reading bc_keep at the ch_dest tap returns the
-- PREVIOUS draw's window. It came back pinned at 6 while the column ran 43 -> 128, which is
-- not a clip window, it is a stale byte — the same "real value, wrong moment" fault as
-- P3.99's ch_dest-at-the-tick and P3.100's high-byte-only tap, now three dispatches running.
_G._t_keep = mem:install_write_tap(F.bc_keep, F.bc_keep, "bc_keep", function(off, data, mask)
    pend_keep = data
    return data
end)
if F.bc_lead then
    _G._t_lead = mem:install_write_tap(F.bc_lead, F.bc_lead, "bc_lead", function(off, data, mask)
        pend_lead = data
        return data
    end)
end
_G._t_lo = mem:install_write_tap(F.ch_dest + 1, F.ch_dest + 1, "dest_lo", function(off, data, mask)
    local i = mem:read_u8(F.ch_idx)
    if dr[i] ~= nil then dr[i] = dr[i] + 1 end
    if i == 0 then
        local col = mem:read_u8(F.ch_col) * 256 + mem:read_u8(F.ch_col + 1)
        if col >= 0x8000 then col = col - 0x10000 end
        vw = { w = mem:read_u8(F.ch_w), col = col, lead = pend_lead or -1, keep = pend_keep or -1 }
    end
    return data
end)

local state, t0 = "boot", nil
local reported = false
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

    if fn >= FROM and fn <= TO then
        if SEED and mem:read_u8(F.ch_anymove) ~= SEED_VAL then seed_landed = false end
        rows[#rows + 1] = { f = fn, it = iters,
                            beat = mem:read_u8(F.vm_beat) * 256 + mem:read_u8(F.vm_beat + 1),
                            scen = mem:read_u8(F.vm_scenery),
                            flow = mem:read_u8(F.sc_flow),
                            any  = mem:read_u8(F.ch_anymove),
                            cel  = mem:read_u8(F.viz_slot + CH_CEL),
                            d0 = dr[0], d1 = dr[1], vw = vw,
                            lds  = mem:read_u8(R.probe_loads) }
    end
    iters = 0; dr[0] = 0; dr[1] = 0
    if fn <= TO then return end
    reported = true

    log(string.format("# ITERATIONS PER FRAME across the exit walk, frames %d..%d, %d-frame buckets.",
                      FROM, TO, BUCK))
    log(string.format("# refresh %.6f Hz. The step fires at the first iteration at or after the due", HZ))
    log("# frame, so ITERATIONS/FRAME is what sets the achieved interval: at 0.50 it/f a")
    log("# 6-frame request cannot land before frame 8, and at 0.40 it/f it cannot land")
    log("# before 10. The 10-block should therefore appear here as a dip, or the premise")
    log("# that the block is a COST is wrong.")
    if SEED then
        log(string.format("# ★ SEEDED: ch_anymove forced to %d on every write (%d substitutions, %d of",
                          SEED_VAL, seed_seen, seed_noop))
        log(string.format("#   which already held %d); read-back %s", SEED_VAL,
                          seed_landed and "CONFIRMS it holds" or "DISAGREES — seed did not land"))
    end
    log("")
    log("    frames         it/f    viz/f  pri/f  col  ch_w bc_lead bc_keep clip  beat")
    local i = 1
    while i <= #rows do
        local n, s, j, a0, a1 = 0, 0, i, 0, 0
        while j <= #rows and rows[j].f < rows[i].f + BUCK do
            s = s + rows[j].it; a0 = a0 + rows[j].d0; a1 = a1 + rows[j].d1
            n = n + 1; j = j + 1
        end
        local r = rows[i]
        local v = r.vw or { w = -1, col = -1, lead = -1, keep = -1 }
        local clip = (v.keep >= 0 and v.w > 0)
                     and (v.keep == 0 and "OFF" or (v.keep < v.w and "PARTIAL" or "full")) or "?"
        log(string.format("    %-5d..%-6d %-7.2f %-6.2f %-6.2f %-4d %-4d %-7d %-7d %-5s %d",
                          r.f, r.f + BUCK - 1, n > 0 and s / n or 0,
                          n > 0 and a0 / n or 0, n > 0 and a1 / n or 0,
                          v.col, v.w, v.lead, v.keep, clip, r.beat))
        i = j
    end

    -- the numbers that matter, as a single line each
    local function mean(lo, hi)
        local s, n = 0, 0
        for _, r in ipairs(rows) do
            if r.f >= lo and r.f <= hi then s = s + r.it; n = n + 1 end
        end
        return n > 0 and s / n or 0, n
    end
    local a, na = mean(FROM, 4701)
    local b, nb = mean(4702, 4802)
    local c, nc = mean(4803, TO)
    log("")
    log(string.format("# BEFORE the 10-block  f%d..4701   %.3f it/f  (%d frames)", FROM, a, na))
    log(string.format("# INSIDE  the 10-block f4702..4802   %.3f it/f  (%d frames)", b, nb))
    log(string.format("# AFTER   the 10-block f4803..%d   %.3f it/f  (%d frames)", TO, c, nc))
    if SEED then
        log("")
        if not seed_landed then
            log("# SEED INEFFECTIVE: ch_anymove did not read back as 1. A verdict on the SEED,")
            log("#   not on the counter — do not read it as either (P3.100).")
        elseif seed_seen == 0 then
            log("# SEED NEVER FIRED: no ch_anymove writes were intercepted.")
        elseif seed_noop > seed_seen * 0.9 then
            log(string.format("# SEED INEFFECTIVE: %d of %d writes already held %d — the substitution was",
                              seed_noop, seed_seen, SEED_VAL))
            log("#   a no-op, so no change in the counter is expected and none is evidence.")
        else
            log("# SEEDED CONTROL: compare this run's it/f against the unseeded run's. Forcing")
            log("#   the peel OFF is strictly less work, so the counter must RISE. If it does")
            log("#   not, it is not counting work and the block above is not a cost (P3.48b).")
        end
    end
    out:close()
    manager.machine:exit()
end)
