-- harness/tools/peel_census.lua
--
-- POP P3.44 — HOW MUCH OF THE PEEL IS SPENT ON CHARACTERS THAT DID NOT CHANGE?
--
-- P3.43 measured the peel at 25,402 cy — 86% of a whole frame budget — and P3.42
-- measured the frame-wide skip firing ZERO times in 694 live iterations. So the port
-- pays a full erase+save for every character every frame. The question this answers is
-- how much of that is work on a character whose own footprint did not change.
--
-- ---------------------------------------------------------------
-- READ THE ENGINE'S OWN DECISION, DO NOT RE-DERIVE IT
-- ---------------------------------------------------------------
-- `ch_scan` computes a PER-CHARACTER moved flag and then ORs it into the frame-wide one:
-- `ch_moved` ends `sta ch_move`, once per character, before `ora ch_anymove`. So a
-- WRITE-TAP on `ch_move` observes exactly what the engine decided, in order — character 0
-- (vizier) then character 1 (princess) — with no re-implementation of the comparison.
--
-- That distinction is the whole design of this tool. Reading `ch_last` / `ch_drawn` and
-- re-applying the x/y/cel test myself would produce a number that is right only if my
-- copy of the rule matches the engine's, and this project has shipped five variants of a
-- checker that assumed part of the state it was checking. Tapping the engine's own store
-- cannot disagree with the engine.
--
-- Ordering within the frame is established by `ch_anymove`'s opening `clr`, which is the
-- first thing `ch_scan` does — so a $00 write to ch_anymove opens a frame and the next two
-- ch_move writes are characters 0 and 1 in that order.
--
-- ---------------------------------------------------------------
-- AND THE GEOMETRY, WHICH IS A SEPARATE QUESTION
-- ---------------------------------------------------------------
-- P3.32 made the skip frame-wide because a STATIONARY character's pixels, left on screen
-- when its erase is skipped, get captured by a MOVING character's save where the two
-- overlap. So a per-character skip is only correct where the footprints are disjoint, and
-- the second half of this census is whether they ever overlap in this scene. That part IS
-- computed from observed state (the slot records' x/y and the resolved w/h), because the
-- engine does not compute it at all — it is the quantity the frame-wide OR exists to
-- avoid needing.
local OUT   = os.getenv("P_OUT")     or "build/peel_census.log"
local LOOP  = tonumber(os.getenv("P_LOOP")    or "0x207C")
local MOVE  = tonumber(os.getenv("P_MOVE")    or "0x6907")
local ANY   = tonumber(os.getenv("P_ANYMOVE") or "0x6909")
local VIZ   = tonumber(os.getenv("P_VIZ")     or "0x68E7")
local PRI   = tonumber(os.getenv("P_PRI")     or "0x68F4")
local FIRST = tonumber(os.getenv("P_FIRST")   or "1900")
local LAST  = tonumber(os.getenv("P_LAST")    or "3400")

local CH_X, CH_Y, CH_H, CH_W = 0, 1, 4, 5

local scr = manager.machine.screens:at(1)
local mem = manager.machine.devices[":maincpu"].spaces["program"]
local f   = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end

local state, t0 = "boot", nil
local armed, cur_frame = false, 0
-- moved[c] = how many frames character c reported "moved"; frames = how many we saw
local moved, frames, slot_in_frame = {0, 0}, 0, 0
local both, neither_m, only = 0, 0, {0, 0}
local pend = {}
local overlap_frames, geom_frames = 0, 0
local minsep = 999

-- Frame boundary: ch_scan's opening `clr ch_anymove`.
_G._any_tap = mem:install_write_tap(ANY, ANY, "anymove", function(off, data, mask)
    if armed and cur_frame >= FIRST and cur_frame <= LAST and data == 0 then
        -- close the previous frame's tally
        if slot_in_frame == 2 then
            frames = frames + 1
            for c = 1, 2 do if pend[c] == 1 then moved[c] = moved[c] + 1 end end
            if pend[1] == 1 and pend[2] == 1 then both = both + 1
            elseif pend[1] == 0 and pend[2] == 0 then neither_m = neither_m + 1
            elseif pend[1] == 1 then only[1] = only[1] + 1
            else only[2] = only[2] + 1 end
        end
        slot_in_frame, pend = 0, {}
    end
    return data
end)

-- Each `sta ch_move` is one character's own decision, in draw order.
_G._mv_tap = mem:install_write_tap(MOVE, MOVE, "chmove", function(off, data, mask)
    if armed and cur_frame >= FIRST and cur_frame <= LAST then
        slot_in_frame = slot_in_frame + 1
        if slot_in_frame <= 2 then pend[slot_in_frame] = (data ~= 0) and 1 or 0 end
    end
    return data
end)

-- The geometry, sampled once per engine iteration.
_G._loop_tap = mem:install_read_tap(LOOP, LOOP, "loop", function(off, data, mask)
    if not armed or cur_frame < FIRST or cur_frame > LAST then return data end
    local vx, vw = mem:read_u8(VIZ + CH_X), mem:read_u8(VIZ + CH_W)
    local px, pw = mem:read_u8(PRI + CH_X), mem:read_u8(PRI + CH_W)
    -- col = (x + 20)/4, the port's own placement expression (co_setup)
    local vc, pc = (vx + 20) // 4, (px + 20) // 4
    local lo, hi = vc, pc
    local lw, hw = vw, pw
    if pc < vc then lo, hi, lw, hw = pc, vc, pw, vw end
    local sep = hi - (lo + lw)          -- byte columns of clear space between them
    geom_frames = geom_frames + 1
    if sep < 0 then overlap_frames = overlap_frames + 1 end
    if sep < minsep then minsep = sep end
    return data
end)

local function report()
    log("# PEEL CENSUS — per-character change, read from the engine's own ch_move store")
    log(string.format("# sampled frames %d..%d", FIRST, LAST))
    if frames == 0 then
        log("# NO FRAMES TALLIED — the ch_move / ch_anymove taps never paired; nothing reported")
        return
    end
    log(string.format("# %d frames tallied", frames))
    log(string.format("# vizier   moved in %5d of %d frames (%.1f%%)", moved[1], frames, 100*moved[1]/frames))
    log(string.format("# princess moved in %5d of %d frames (%.1f%%)", moved[2], frames, 100*moved[2]/frames))
    log(string.format("# both moved %d (%.1f%%)  only vizier %d  only princess %d  NEITHER %d (%.1f%%)",
                      both, 100*both/frames, only[1], only[2], neither_m, 100*neither_m/frames))
    local wasted = only[1] + only[2] + 2*neither_m
    log(string.format("# per-CHARACTER peels that were unnecessary on the character's OWN state:"))
    log(string.format("#   %d of %d character-peels (%.1f%%) — a per-character skip's ceiling",
                      wasted, 2*frames, 100*wasted/(2*frames)))
    log("# (ceiling, not a saving: P3.32's frame-wide OR exists because a skipped erase")
    log("#  leaves that character's pixels on screen for the OTHER character's save, so a")
    log("#  per-character skip is only correct where the footprints are disjoint.)")
    log(string.format("# GEOMETRY: footprints overlapped in %d of %d samples (%.1f%%); closest approach %d byte columns",
                      overlap_frames, geom_frames, 100*overlap_frames/math.max(geom_frames,1), minsep))
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
