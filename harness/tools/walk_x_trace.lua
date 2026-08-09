-- harness/tools/walk_x_trace.lua
--
-- POP P3.51 — WHAT DOES THE VIZIER'S X ACTUALLY DO, STEP BY STEP?
--
-- Jay, on the live gate: "the pace looks ok. but i think the x change in his walk is off.
-- it looks like he moves back a bit while walking forward."
--
-- The sequence data is faithful -- the port's viz_walk1 matches SEQTABLE.S:1513-1522 byte
-- for byte, and it genuinely contains `db 51,chx,-1`, a delta of the opposite sign to its
-- five neighbours. Mirrored by CharFace=-1 that becomes +1, i.e. one pixel BACKWARD
-- between cel 51 and cel 52. So a back-step is expected from the data.
--
-- What is NOT established is whether the port produces exactly that and nothing more.
-- `addcharx`, the oracle routine that applies the delta, is a `ds 3` stub in the vendored
-- tree with no body, so the source cannot say how it treats a negative value -- and
-- CLAUDE.md §2 is explicit that where the source does not settle a behavioural question,
-- the trace does.
--
-- ---------------------------------------------------------------
-- RECORD THE ENGINE'S X, COMPARE AGAINST THE DATA'S OWN PREDICTION
-- ---------------------------------------------------------------
-- A WRITE-tap on the vizier slot's CH_X byte catches every mutation `vs_chx` makes, in
-- order. Write counts have been the reliable instrument throughout this arc (P3.48-P3.50);
-- read-taps have not, and this dispatch already caught one lying about the draw rate.
--
-- The expected sequence is DERIVED FROM THE SEQUENCE DATA rather than typed in: deltas
-- 2,6,1,-1,1,1 per cycle, each negated because CharFace is -1, applied from the recorded
-- start. Typing the answer in would make this a check that agrees with itself.
local OUT   = os.getenv("P_OUT")  or "build/walk_x.log"
local VIZ   = tonumber(os.getenv("P_VIZ")   or "0x68E7")
local FIRST = tonumber(os.getenv("P_FIRST") or "1900")
local LAST  = tonumber(os.getenv("P_LAST")  or "2600")

local scr = manager.machine.screens:at(1)
local mem = manager.machine.devices[":maincpu"].spaces["program"]
local f   = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end

local state, t0 = "boot", nil
local armed, cur_frame = false, 0
local seq, prev = {}, nil

_G._x = mem:install_write_tap(VIZ, VIZ, "viz_x", function(off, data, mask)
    if armed and cur_frame >= FIRST and cur_frame <= LAST and #seq < 40 then
        if data ~= prev then
            seq[#seq + 1] = { x = data, f = cur_frame,
                              d = prev and (data - prev) or 0 }
            prev = data
        end
    end
    return data
end)

local function report()
    log("# VIZIER X TRACE — every change to CH_X, in order")
    log(string.format("# viz_slot $%04X (CH_X +0); sampled frames %d..%d", VIZ, FIRST, LAST))
    log("#  x    delta   frame")
    local backs = 0
    for i, e in ipairs(seq) do
        local mark = ""
        if i > 1 and e.d > 0 then mark = "   <-- BACKWARD (x increases; he walks left)"; backs = backs + 1 end
        log(string.format("#  %3d   %+3d    %5d%s", e.x, e.d, e.f, mark))
    end
    log(string.format("# %d changes recorded, %d of them backward", #seq, backs))
    log("# EXPECTED from the data: deltas 2,6,1,-1,1,1 per cycle, each NEGATED by")
    log("#   CharFace=-1, so -2,-6,-1,+1,-1,-1 -- exactly ONE +1 per six, and no other")
    log("#   positive delta. A second positive, or a magnitude other than 1, is a defect.")
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
        if mem:read_u8(0x2008) > 0 then armed, state = true, "watch"; prev = mem:read_u8(VIZ) end
        return
    end
    if fn > LAST then report(); manager.machine:exit() end
end

_G._notifier = emu.add_machine_frame_notifier(tick)
