-- harness/tools/peel_skip_cost.lua
--
-- POP P3.42 — WHAT DOES THE FRAME-WIDE PEEL-SKIP ACTUALLY SAVE?
--
-- P3.40 §3C flagged this and did not quantify it: `ch_scan`'s moved test is
-- FRAME-WIDE ("if anything moved, everybody peels"), and under a stagger something
-- moves nearly every frame, so the skip would effectively never fire. That is not a
-- correctness problem -- the 19,652 baseline already assumes a full peel every frame
-- -- but it forfeits whatever the skip was buying on quiet frames, and nobody had
-- measured it. This measures it.
--
-- ---------------------------------------------------------------
-- METHOD, and why it is spins rather than a cycle counter
-- ---------------------------------------------------------------
-- MAME 0.281's Lua device wrapper exposes NO cycle counter (`cpu:total_cycles()` and
-- `cpu.clock` are both nil -- mame-idioms-coco3-port.md §0), and `machine.time` is
-- quantised to the scheduler timeslice, so an intra-frame delta reads as ~4 cycles and
-- makes the work look free. The established substitute is the VBL SPIN-WAIT ITSELF
-- (§0a): `hal_vbl_spin` is a two-instruction loop, `cmpb <hal_frame_lo` (4) + `beq`
-- taken (3) = 7 cycles per iteration, and it burns EVERY cycle the engine is not
-- working. So counting spins measures IDLE directly, and
--
--     work = frames_elapsed * 29,859  -  spins * 7
--
-- is the engine's real per-iteration cost. This is a measurement, not a model.
--
-- ---------------------------------------------------------------
-- WHAT IS TAGGED AGAINST WHAT
-- ---------------------------------------------------------------
-- One WINDOW = `room_loop` entry N -> `room_loop` entry N+1: exactly one engine
-- iteration (flicker, chars_frame, swap). `ch_anymove` is read at the CLOSE of the
-- window, because that is the value `ch_scan` computed for the `vm_frameadv` that ran
-- INSIDE it -- reading it at the open would tag each window with the previous
-- iteration's decision, which is the off-by-one this project has now shipped four
-- times (assume the position / the provenance / the cel / that the cel is current).
--
-- Windows are then bucketed by that flag:
--
--     anymove = 1  -> the full peel ran (erase + save, both characters)
--     anymove = 0  -> the peel was SKIPPED; draw only
--
-- and the DIFFERENCE OF THE MEANS is what the skip saves. Both populations come from
-- the same run, the same scene and the same cels, so the difference is the peel and
-- not a scene change.
--
-- 6809 read-taps fire on opcode fetch (idioms §10), which is why this can tap an
-- EXECUTION address at all; the 6502 oracle side cannot. Taps are kept in `_G` or they
-- are garbage-collected and silently stop firing (§10, the tap-GC gotcha) -- an empty
-- log would otherwise read as "the skip never fires", which is a conclusion.
local OUT      = os.getenv("P_OUT")   or "build/peel_skip_cost.log"
local LOOP     = tonumber(os.getenv("P_LOOP")   or "0x207C")
local SPIN     = tonumber(os.getenv("P_SPIN")   or "0x7980")
local ANYMOVE  = tonumber(os.getenv("P_ANYMOVE") or "0x6909")
local FIRST    = tonumber(os.getenv("P_FIRST")  or "1900")
local LAST     = tonumber(os.getenv("P_LAST")   or "3400")
-- 894,886 Hz * 2 (HAL_gfx_init writes $FFD9 SAM double-speed) / 59.94 Hz.
local CY_PER_FRAME = 29859
local SPIN_CY      = 7

local scr = manager.machine.screens:at(1)
local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local f   = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end

local state, t0 = "boot", nil
local armed     = false
local spins     = 0
local open_fn   = nil
local cur_frame = 0
-- bucket[flag] = {n, frames, spins}
local bucket = { [0] = {n=0, frames=0, spins=0}, [1] = {n=0, frames=0, spins=0} }
local fhist  = { [0] = {}, [1] = {} }
-- THE RAW BYTE, not just the bucket it fell into. An empty bucket is the exact shape
-- of a broken instrument -- a wrong address holding non-zero garbage clamps to 1 and
-- reads as "the skip never fires", which is a CONCLUSION. So the raw distribution is
-- logged too: a live flag is 0 or 1 and nothing else, and anything else falsifies the
-- address rather than the finding. (Seven silent instrument failures in this project;
-- a checker must not assume any part of the state it checks.)
local rawhist = {}

-- ARM ONLY ONCE THE PROGRAM IS RUNNING. $7980 is HAL code, but before ROOM.BIN lands
-- that address is whatever DECB left there, and an unarmed tap counts BASIC's reads as
-- engine idle (idioms §0: "unarmed taps fire at ~f22 and read as the routine running
-- impossibly early").
_G._spin_tap = mem:install_read_tap(SPIN, SPIN, "vbl_spin", function(off, data, mask)
    if armed then spins = spins + 1 end
    return data
end)

_G._loop_tap = mem:install_read_tap(LOOP, LOOP, "room_loop", function(off, data, mask)
    if not armed then return data end
    local fn = cur_frame
    if open_fn ~= nil and fn >= FIRST and fn <= LAST then
        local raw  = mem:read_u8(ANYMOVE)
        rawhist[raw] = (rawhist[raw] or 0) + 1
        local flag = raw
        if flag > 1 then flag = 1 end
        local frames = fn - open_fn
        local b = bucket[flag]
        b.n      = b.n + 1
        b.frames = b.frames + frames
        b.spins  = b.spins + spins
        fhist[flag][frames] = (fhist[flag][frames] or 0) + 1
    end
    open_fn = fn
    spins   = 0
    return data
end)

-- INDEPENDENT CONFIRMATION THAT THE ADDRESS IS LIVE, by a different mechanism than the
-- read above. `ch_scan` opens with `clr ch_anymove` and then stores the running OR once
-- per character, so a correct address MUST see a $00 write every frame followed by the
-- per-character stores. If this tap sees nothing, the address is dead and the read
-- histogram above is measuring a constant somewhere else; if it sees the $00 writes but
-- the frame always CLOSES at $01, then the skip genuinely never fires. The two taps
-- cannot both be fooled by the same error, which is the point of using both.
local wrhist, wr_zero_frames, wr_last = {}, 0, nil
_G._any_tap = mem:install_write_tap(ANYMOVE, ANYMOVE, "anymove_w", function(off, data, mask)
    if armed and cur_frame >= FIRST and cur_frame <= LAST then
        wrhist[data] = (wrhist[data] or 0) + 1
        if data == 0 and wr_last ~= 0 then wr_zero_frames = wr_zero_frames + 1 end
        wr_last = data
    end
    return data
end)

local function report()
    log("# PEEL-SKIP COST — measured on the live scene, off the VBL spin-wait")
    log(string.format("# window = room_loop($%04X) to room_loop; idle = spins($%04X) * %d cy",
                      LOOP, SPIN, SPIN_CY))
    log(string.format("# frame = %d cy (894,886 Hz x2 double-speed / 59.94 Hz)", CY_PER_FRAME))
    log(string.format("# sampled frames %d..%d", FIRST, LAST))
    local mean = {}
    for _, flag in ipairs({1, 0}) do
        local b = bucket[flag]
        if b.n > 0 then
            local mf = b.frames / b.n
            local ms = b.spins / b.n
            local work = mf * CY_PER_FRAME - ms * SPIN_CY
            mean[flag] = work
            log(string.format("# anymove=%d  %5d windows  %6.3f frames/iter  %8.1f spins  -> work %8.0f cy",
                              flag, b.n, mf, ms, work))
        else
            log(string.format("# anymove=%d  NO WINDOWS SAMPLED", flag))
        end
    end
    local tot = bucket[0].n + bucket[1].n
    if tot > 0 then
        log(string.format("# skip fired on %d of %d iterations (%.1f%%)",
                          bucket[0].n, tot, 100 * bucket[0].n / tot))
    end
    if mean[0] and mean[1] then
        log(string.format("# PEEL COST = %.0f - %.0f = %.0f cy per iteration (%.1f%% of a frame)",
                          mean[1], mean[0], mean[1] - mean[0],
                          100 * (mean[1] - mean[0]) / CY_PER_FRAME))
    else
        log("# ONE BUCKET IS EMPTY — no difference can be taken; see the window counts above")
    end
    local rkeys = {}
    for k in pairs(rawhist) do rkeys[#rkeys+1] = k end
    table.sort(rkeys)
    local rparts = {}
    for _, k in ipairs(rkeys) do
        rparts[#rparts+1] = string.format("$%02X:%d", k, rawhist[k])
    end
    log(string.format("# RAW ch_anymove values seen: %s", table.concat(rparts, " ")))
    log("#   (a live flag is $00 or $01 and nothing else; anything else means the")
    log("#    ADDRESS is wrong, not that the skip never fires)")
    local wkeys = {}
    for k in pairs(wrhist) do wkeys[#wkeys+1] = k end
    table.sort(wkeys)
    local wparts = {}
    for _, k in ipairs(wkeys) do
        wparts[#wparts+1] = string.format("$%02X:%d", k, wrhist[k])
    end
    log(string.format("# WRITE-tap on ch_anymove (independent of the read): %s",
                      table.concat(wparts, " ")))
    log(string.format("# ch_scan's opening `clr` seen %d times — the address IS live and written",
                      wr_zero_frames))
    for _, flag in ipairs({1, 0}) do
        local keys = {}
        for k in pairs(fhist[flag]) do keys[#keys+1] = k end
        table.sort(keys)
        local parts = {}
        for _, k in ipairs(keys) do
            parts[#parts+1] = string.format("%d:%d", k, fhist[flag][k])
        end
        log(string.format("# frames/iter histogram anymove=%d  %s", flag, table.concat(parts, " ")))
    end
end

-- Same boot as port_vm_cadence.lua / run_room_test.sh: LOADM + EXEC off the mounted
-- floppy, not a poked image (CLAUDE.md §4).
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
        -- probe_frames advances only once the room's loop is turning over.
        if mem:read_u8(0x2008) > 0 then armed, state = true, "watch" end
        return
    end
    if fn > LAST then
        report()
        manager.machine:exit()
    end
end

_G._notifier = emu.add_machine_frame_notifier(tick)
