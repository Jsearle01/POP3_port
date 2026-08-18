-- region_write_probe.lua — P4.13 §1: does ANYTHING write into a region during a full run?
--
-- ★★★ WHY THIS EXISTS, AND WHY IT IS NOT OPTIONAL. P4.12 established `$6B91..$77FF` as free by
-- ARITHMETIC on the built images — the intro's linked span ends at `$6B90` and the trace ring
-- starts at `$7800`, so the 3,183 bytes between them look unused. That is a description, not
-- an observation, and a description of a region being free is not evidence that nothing
-- writes to it.
--
-- ★★ THE SAME REPORT THAT PRODUCED THAT FIGURE ALSO CORRECTED ONE: P4.11's "~1,840 B free"
-- came from reading one object file's contribution to `prog` as the whole section. Building
-- a buffer on a second map-derived figure without observing it would be the same bet twice.
--
-- ★ AND THE MAP IS KNOWN STALE IN AT LEAST ONE PLACE — `pop.link`'s comment puts stack space
-- at `$7B7B-$7EFF`, which overlaps the kernel's actual `$7900..$7D43`. One of the two is
-- wrong. That does not touch this range, but it is why the range gets a tap rather than a
-- reading.
--
--   P_LO / P_HI   the range, hex, inclusive
--   P_OUT         the report
--
-- Reports WHAT was written and FROM WHERE (the PC), because "something writes here" and
-- "the caption reloader writes here" are different findings and only the second is
-- actionable.
local LO   = tonumber(os.getenv("P_LO") or "6B91", 16)
local HI   = tonumber(os.getenv("P_HI") or "77FF", 16)
local OUT  = os.getenv("P_OUT") or "build/tmp/region_write.log"

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local out = io.open(OUT, "w")
local function log(s) out:write(s .. "\n"); out:flush() end

local n, first, last, byaddr, bypc = 0, nil, nil, {}, {}
-- ★★★ SWEEP MODE. P4.13 answered "is THIS region free" and the answer was no. The next
-- question is "what IS free", and the map has now been wrong twice about exactly that, so it
-- is answered the same way: mark every byte anything writes to across a whole run, then
-- report the untouched runs. Arithmetic only to confirm, never to propose.
local SWEEP = os.getenv("P_SWEEP")
local lastn = 0
local touched = {}

-- ★ A WRITE TAP, NOT A READ TAP. The question is whether the region is SAFE TO OWN, which is
-- about writes; reads of uninitialised memory are harmless and would bury the signal.
_G._tw = mem:install_write_tap(LO, HI, "region", function(off, data, mask)
    if SWEEP then
        -- the callback runs on EVERY write in the range, so it does exactly one thing
        touched[off] = true
        n = n + 1
        return data
    end
    n = n + 1
    local fn = scr:frame_number()
    first = first or { f = fn, a = off, d = data, pc = cpu.state["PC"].value }
    last = { f = fn, a = off, d = data }
    byaddr[off] = (byaddr[off] or 0) + 1
    local pc = cpu.state["PC"].value
    bypc[pc] = (bypc[pc] or 0) + 1
    return data
end)

log(string.format("# REGION WRITE PROBE — $%04X..$%04X (%d bytes)", LO, HI, HI - LO + 1))
log("# ★ A tap that never fires and a region that is never written look identical.")
log("#   The count is reported FIRST, and a zero is only meaningful because the same")
log("#   tap installed over a live region would show thousands.")

-- ★★ AND IT DRIVES ITS OWN LAUNCH, because MAME takes ONE autoboot script and the intro
-- has to actually RUN for the question to mean anything. The frame numbers are
-- introseq_live.lua's, which is the proven path: LOADM at 300, EXEC ~500 frames later once
-- the disk read has finished. A tap over a region on a machine sitting at a BASIC prompt
-- would report zero writes and prove nothing at all.
local nk = manager.machine.natkeyboard
nk.in_use = true
local state = "boot"
local t0 = nil

_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if state == "boot" then
        if fn >= 300 then
            nk:post('LOADM"' .. (os.getenv("P_PROG") or "INTROSEQ") .. '"\n')
            log(string.format("# posted LOADM at frame %d", fn))
            state, t0 = "loadm", fn
        end
        return
    end
    if state == "loadm" then
        if fn > t0 + 500 then
            nk:post('EXEC\n')
            log(string.format("# posted EXEC at frame %d -- the intro runs from here", fn))
            state = "run"
        end
        return
    end
-- ★ THE BUCKET SIZE IS THE MEASUREMENT HERE, NOT A PROGRESS INDICATOR. P4.13 printed every
-- 600 frames and one bucket read 612 -> 612 across ten seconds: a quiet stretch, visible
-- only because the totals happened to straddle it. If the question is WHEN a region is
-- written, the bucket has to be smaller than the thing being looked for.
    local every = tonumber(os.getenv("P_EVERY") or "600")
    if fn % every ~= 0 then return end
    local d = n - (lastn or 0)
    lastn = n
    log(string.format("# frame %-6d  +%-7d  total %d%s", fn, d, n, d == 0 and "   <- QUIET" or ""))
end)

emu.register_stop(function()
    log("")
    if SWEEP then
        log(string.format("# ★★★ SWEEP — %d writes over $%04X..$%04X", n, LO, HI))
        log("# UNTOUCHED RUNS, in descending size. A run here was written to by NOTHING for")
        log("# the entire run — which is the only claim worth making about free space.")
        local runs, s0 = {}, nil
        for a = LO, HI + 1 do
            if a <= HI and not touched[a] then
                s0 = s0 or a
            elseif s0 then
                runs[#runs + 1] = { s0, a - 1, a - s0 }
                s0 = nil
            end
        end
        table.sort(runs, function(x, y) return x[3] > y[3] end)
        local need = tonumber(os.getenv("P_NEED") or "2590")
        for i = 1, math.min(#runs, 20) do
            local r = runs[i]
            log(string.format("#   $%04X..$%04X  %6d B%s", r[1], r[2], r[3],
                              r[3] >= need and "   <- fits the largest song" or ""))
        end
        local big = runs[1] and runs[1][3] or 0
        log("")
        if big >= need then
            log(string.format("# ★ LARGEST RUN %d B >= %d B needed.", big, need))
        else
            log(string.format("# ★★★ LARGEST RUN %d B, SHORT BY %d B of the %d needed.",
                              big, need - big, need))
        end
        out:close(); return
    end
    log(string.format("# ★★★ TOTAL WRITES INTO THE REGION: %d", n))
    if n == 0 then
        log("# CLEAN — nothing wrote into it for the whole run.")
    else
        local ks, ps = {}, {}
        for k in pairs(byaddr) do ks[#ks + 1] = k end
        for k in pairs(bypc) do ps[#ps + 1] = k end
        table.sort(ks); table.sort(ps)
        log(string.format("# first: frame %d  $%04X <- $%02X  from PC $%04X",
                          first.f, first.a, first.d, first.pc))
        log(string.format("# last:  frame %d  $%04X <- $%02X", last.f, last.a, last.d))
        log(string.format("# %d distinct addresses touched, %d distinct writers", #ks, #ps))
        log("# ADDRESSES (first 24):")
        for i = 1, math.min(#ks, 24) do
            log(string.format("#   $%04X  x%d", ks[i], byaddr[ks[i]]))
        end
        log("# WRITERS, by PC (first 24) — ★ this is the actionable half:")
        for i = 1, math.min(#ps, 24) do
            log(string.format("#   PC $%04X  x%d", ps[i], bypc[ps[i]]))
        end
        log("# ★★★ NOT CLEAN. Do not place a buffer here on this evidence.")
    end
    out:close()
end)
