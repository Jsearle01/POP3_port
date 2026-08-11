-- harness/tools/oracle_palert_rate.lua
--
-- POP P3.72d — HOW FAST DOES THE ORACLE ACTUALLY TURN THE PRINCESS?
--
-- Jay rejected the port's Palert live: "her ovement is way to fast". The port runs her
-- at 3.86 frames/cel. The source says PlayCut0 plays her turn at SPEED 1 and the
-- vizier's approach at SPEED 7 [SUBS.S:658-683], but `pause` is a MINIMUM and the draw
-- can overrun it, so the source cannot settle the wall-clock rate. This measures it.
--
-- WHY NOT oracle_flame_rate.lua. That tool's premise is "the flames advance once per
-- play iteration", and this run showed it does not hold: over f2688-f5560 the flame box
-- changes on a 2-3 frame cycle almost continuously, including through stretches where
-- the play period is plainly 6-7. The flames have their own flicker rate. Any figure
-- derived from that box is a flame rate, not a play rate.
--
-- SO WATCH THE CHARACTER. The princess's cel changes exactly once per `play` while
-- Palert runs, and she is otherwise STATIC for the whole scene (Pstand before, Pstand
-- mirrored after). Her turn is therefore a burst of exactly 8 changes with a long quiet
-- stretch either side, which makes it self-identifying -- no need to know the frame the
-- cutscene starts on.
--
-- GEOMETRY. MAME's apple2e screen is 560 px wide = 280 Apple mono px doubled; rows map
-- 1:1 [oracle_flame_rate.lua, verified there]. She stands at CharX 120, i.e. FCharX
-- 2*(120-58)+1 = 125 Apple px, and her cel is about 40 px wide over rows 109-151. The
-- box below is Apple px 100-155 -> screen x 200-310, which clears BOTH torches (Apple
-- px 91-97 and 181-187 -> screen 182-195 and 362-375) and clears the vizier, who starts
-- at CharX 197 = FCharX 278 -> screen x 556 and only reaches her late in the scene.
--
-- PASSIVE: pixel reads only. No soft switches, no memory writes, no taps -- and on 6502
-- read-taps would silently false-0 anyway [CLAUDE.md 2A].
local OUT   = os.getenv("P_OUT")   or "build/oracle_palert.log"
local FIRST = tonumber(os.getenv("P_FIRST") or "2000")
local LAST  = tonumber(os.getenv("P_LAST")  or "9000")

local X0, X1 = tonumber(os.getenv("P_X0") or "200"), tonumber(os.getenv("P_X1") or "310")
local Y0, Y1 = tonumber(os.getenv("P_Y0") or "104"), tonumber(os.getenv("P_Y1") or "152")

local scr = manager.machine.screens:at(1)
local f = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end

local function sample()
    local h = 0
    for y = Y0, Y1 do
        for x = X0, X1, 2 do
            h = (h * 31 + scr:pixel(x, y)) % 4294967296
        end
    end
    return h
end

local prev, last_change = nil, nil

log(string.format("# the princess's box: screen x %d-%d, rows %d-%d", X0, X1, Y0, Y1))
log("# every frame on which her pixels change, with the gap since the previous change")

local function tick()
    local fn = scr:frame_number()
    if fn < FIRST or fn > LAST then return end
    local h = sample()
    if prev ~= nil and h ~= prev then
        log(string.format("f%6d  changed  (+%s frames)", fn,
                          last_change and tostring(fn - last_change) or "first"))
        last_change = fn
    end
    prev = h
    if fn == LAST then
        log("# done")
        if f then f:close() end
        manager.machine:exit()
    end
end

-- Held in a global: a frame notifier that goes out of scope is garbage-collected and
-- the trace silently stops [CLAUDE.md 2A, the frame-notifier GC gotcha].
_G._notifier = emu.add_machine_frame_notifier(tick)
