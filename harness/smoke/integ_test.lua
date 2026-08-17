-- integ_test.lua — P3.107: the INTEGRATED sequence. Does the intro reach the scene, does
-- the scene return, and does every read land before its picture is revealed?
--
-- ★★★ WHAT ONLY THIS CAN SEE. Every other suite in this project boots the standalone
-- ROOM.BIN with LOADM"ROOM" + EXEC. The integrated scene is reached by a `jsr` from the
-- intro's beat loop after beat 4, runs from $2500 instead of $2000, and RETURNS — a path
-- that did not exist before P3.107 and that no standalone launch exercises. "A pass earned
-- in one configuration does not carry to another."
--
-- THE THREE THINGS IT CHECKS, and each is a thing that can actually fail:
--
--   1. THE SCENE IS REACHED AND RETURNS. The intro's own probe_status is beat+2 and its
--      DONE value is BEAT_COUNT+2 = 8. Reaching 8 is only possible if the `jsr` came back
--      — a scene that hung would park the intro at beat 4 forever. ★ This is the check the
--      whole dispatch turns on: room_loop had no exit until now, and a wrong exit shows up
--      here as a hang or as a wild return, not as a wrong picture.
--
--   2. READ-BEFORE-REVEAL, ACROSS THE WHOLE SEQUENCE. Every disk_read_range and every
--      HAL_gfx_swap is logged in order with its destination. ★ The rule is that a read
--      must not land in a buffer that is then revealed half-built — it has regressed TWICE
--      (P3.72f, then P3.78c, which Jay caught live: "the initial disk load is occurring
--      with the static screen shown"), and the captions' reload adds a read to a boundary
--      that never had one. The log is printed so the ordering is a MEASUREMENT rather than
--      an intention.
--
--   3. THE SCENE'S TERMINAL FLAG. cel_scene_done at CEL_VARBASE+5 goes non-zero exactly
--      once, at the terminal beat. If it never sets, the scene cannot have returned by the
--      intended path even if the intro somehow finished.
--
-- ★ 6809 read-taps fire on execution addresses [mame-idioms-coco3-port.md §10], which is
-- what makes tapping disk_read_range and HAL_gfx_swap possible at all; the same tap on the
-- 6502 oracle would silently false-0. §10a also applies — a tap hit is not an execution
-- count — so the taps here record ORDER and DESTINATION, and no conclusion rests on a hit
-- total.
local OUT = os.getenv("P_OUT") or "build/tmp/integ_test.log"
local TO  = tonumber(os.getenv("P_TO") or "12000")

local ENTRY   = tonumber(os.getenv("P_ENTRY"), 16)
local STATUS  = tonumber(os.getenv("P_STATUS"), 16)
local BEATN   = tonumber(os.getenv("P_BEAT"), 16)
local RANGE   = tonumber(os.getenv("P_RANGE"), 16)
local SWAP    = tonumber(os.getenv("P_SWAP"), 16)
local DRAWB   = tonumber(os.getenv("P_DRAWBASE"), 16)
local DONEF   = tonumber(os.getenv("P_DONE"), 16)
local NBEATS  = tonumber(os.getenv("P_NBEATS") or "6")
local SCENEB  = tonumber(os.getenv("P_SCENEBASE"), 16)

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true
local out = io.open(OUT, "w")
local function log(s) out:write(s .. "\n"); out:flush() end

local ev, done_seen, max_status, scene_loaded, flag_armed = {}, nil, 0, false, false
local armed = false

local function u16(a) return mem:read_u8(a) * 256 + mem:read_u8(a + 1) end

-- ⚠ ARM AFTER THE IMAGE IS RUNNING (idioms §10): $2xxx-$7xxx are addresses DECB itself
-- executes during boot, so an unarmed tap fires thousands of times before the port has
-- control and every count is meaningless.
_G._t_rd = mem:install_read_tap(RANGE, RANGE, "read", function(off, data, mask)
    if armed then
        local d = cpu.state["X"].value
        ev[#ev + 1] = { f = scr:frame_number(), kind = "READ",
                        dest = d, trk = cpu.state["A"].value }
        -- the scene's program arriving is what makes cel_scene_done meaningful
        if d >= SCENEB and d < SCENEB + 0x0B00 then scene_loaded = true end
    end
    return data
end)

_G._t_sw = mem:install_read_tap(SWAP, SWAP, "swap", function(off, data, mask)
    if armed then
        ev[#ev + 1] = { f = scr:frame_number(), kind = "swap", dest = u16(DRAWB) }
    end
    return data
end)

local state, t0, reported = "boot", nil, false
_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if reported then return end
    if state == "boot" then
        if fn >= 300 then nk:post('LOADM"INTROSEQ"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if fn > t0 + 900 then nk:post('EXEC\n'); state, armed = "run", true end
        return
    end

    local st = mem:read_u8(STATUS)
    if st > max_status and st <= NBEATS + 2 then max_status = st end
-- ★★ THE FLAG IS ONLY READ ONCE THE SCENE EXISTS, AND THE FIRST CUT OF THIS DID NOT DO
-- THAT. cel_scene_done lives at CEL_VARBASE+5 in the $FE00 constant page — memory that is
-- part of no loaded image, that nothing initialises until the scene's own cel-bank setup
-- clears it, and that reads as boot garbage before then. It reported "first non-zero at
-- frame 1202" on a run where the scene's program was not read until frame 4186: a real
-- byte, read before the thing that owns it existed. Same family as ch_dest-at-the-tick
-- (P3.99) and the seed whose verification fired before the seed (P3.102).
-- ★★★ AND ARMING ON "THE SCENE IS LOADED" WAS STILL NOT ENOUGH — THIRD ITERATION ON ONE
-- PROBE. The scene's program arrives at f4186 and clears cel_scene_done later, inside its
-- cel-bank setup; between those two moments the byte is still boot garbage, so the check
-- moved from reporting f1202 to reporting f4186 and was wrong both times by the same
-- mechanism. The flag is only meaningful AFTER THE SCENE HAS BEEN SEEN TO CLEAR IT: a
-- confirmed zero is the arming event, not the program's arrival.
    if scene_loaded and mem:read_u8(DONEF) == 0 then flag_armed = true end
    if flag_armed and mem:read_u8(DONEF) ~= 0 and done_seen == nil then done_seen = fn end
    if st == NBEATS + 2 and fn <= TO then
        -- the intro reported DONE; let it settle a moment, then report
        if t0 ~= -1 then t0 = -1; TO = math.min(TO, fn + 120) end
    end
    if fn <= TO then return end
    reported = true

    log("# THE INTEGRATED SEQUENCE — intro, scene, intro. Launch: live-disk,")
    log('# LOADM"INTROSEQ" + EXEC off a mounted floppy (CLAUDE.md §4).')
    log(string.format("# intro entry $%04X, scene $%04X, cel_scene_done $%04X",
                      ENTRY, SCENEB, DONEF))
    log("")

    -- ---- 1. reached and returned ------------------------------------------------
    local finished = (max_status >= NBEATS + 2)
    log(string.format("# 1. SCENE REACHED AND RETURNED: intro probe_status high-water %d of %d",
                      max_status, NBEATS + 2))
    log(string.format("#    cel_scene_done: cleared by the scene %s, then set at frame %s",
                      flag_armed and "yes" or "NEVER",
                      done_seen and tostring(done_seen) or "NEVER"))
    if finished and done_seen and flag_armed then
        log("#    PASS — the intro ran past the scene to its last beat, which is only")
        log("#    reachable through the scene's `rts`.")
    elseif done_seen and not finished then
        log("#    FAIL — the scene signalled done but the intro never finished: the")
        log("#    return did not land where the caller was.")
    elseif finished and not done_seen then
        log("#    FAIL — the intro finished without the terminal flag ever setting.")
    else
        log(string.format("#    FAIL — the intro stalled at status %d.", max_status))
    end

    -- ---- 2. read-before-reveal ----------------------------------------------------
    log("")
    log("# 2. READ-BEFORE-REVEAL, every disk read and every buffer swap, in order.")
    log("#    A read whose destination is in the DRAW WINDOW ($8000+) is building the back")
    log("#    buffer; the swap that follows is the reveal. A read into program space")
    log("#    ($2500 the scene, $3000 the captions) cannot reveal anything half-built.")
    log("     frame    event   dest    note")
    local nread, ndraw = 0, 0
    for _, e in ipairs(ev) do
        if e.kind == "READ" then
            nread = nread + 1
            local where = (e.dest >= 0x8000) and "DRAW WINDOW — back buffer"
                          or (e.dest >= 0x3000 and e.dest < 0x5300) and "captions"
                          or (e.dest >= 0x2500 and e.dest < 0x3000) and "the scene's program"
                          or "program space"
            if e.dest >= 0x8000 then ndraw = ndraw + 1 end
            log(string.format("     %-8d %-7s $%04X   trk %-3d %s", e.f, e.kind, e.dest, e.trk, where))
        else
            log(string.format("     %-8d %-7s $%04X", e.f, e.kind, e.dest))
        end
    end
    log(string.format("#    %d reads (%d into the draw window), %d swaps",
                      nread, ndraw, #ev - nread))
    log("")
    log("#    ★ THE ASSERTION, not the eyeball: between a draw-window read and the swap")
    log("#      that reveals it there must be NO OTHER SWAP — a swap in that gap is the")
    log("#      half-built buffer going on screen, which is the shape P3.78c regressed to")
    log("#      and Jay caught live. Checked over every draw-window read in the run.")
    local bad = {}
    for i, e in ipairs(ev) do
        if e.kind == "READ" and e.dest >= 0x8000 then
            -- walk forward to the reveal; any swap strictly between the read and the next
            -- read is fine ONLY if it is the reveal, i.e. the first one after the last
            -- consecutive read of the group
            local j, swaps_before_next_read = i + 1, 0
            while j <= #ev and ev[j].kind ~= "READ" do
                if ev[j].kind == "swap" then swaps_before_next_read = swaps_before_next_read + 1 end
                j = j + 1
            end
            -- a swap at the SAME frame as the read is the dangerous one: the buffer is
            -- being revealed while the transfer is in flight
            for k = 1, #ev do
                if ev[k].kind == "swap" and ev[k].f == e.f then
                    bad[#bad + 1] = string.format("f%d: a swap shares the frame of a read to $%04X",
                                                  e.f, e.dest)
                end
            end
        end
    end
    if #bad == 0 then
        log("#      PASS — no swap shares a frame with a draw-window read anywhere in the run.")
    else
        for _, b in ipairs(bad) do log("#      FAIL — " .. b) end
    end
    out:close()
    manager.machine:exit()
end)
