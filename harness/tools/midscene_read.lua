-- harness/tools/midscene_read.lua
--
-- POP P3.75c — DOES A DISK READ INTO A MAPPED BANK BLOCK WORK MID-SCENE?
--
-- The one thing the swap design rests on that has never been run. The startup read into
-- $C000 happens before the room loop with nothing animating; a read DURING the scene is a
-- different proposition — the framebuffer is mapped at $FFA4/$FFA5, the bank at
-- $FFA6/$FFA7, and load_tracks drops to SAM_SLOW, masks interrupts and clears DSKREG on
-- the way out, all while the flame loop is meant to be running.
--
-- The engine carries a one-shot test block that re-reads the SAME cel tracks to the SAME
-- address at frame RT_AT, so a working read is a NO-OP and a broken one shows as the bank
-- changing under a scene that is drawing from it.
--
-- WHAT IS MEASURED:
--   * the freeze — frames between the pre and post markers
--   * dr_status — did the read report success
--   * $C000/$C001 (the image's own WALK_LO/WALK_N) before, during and after
--   * whether the scene keeps advancing afterwards (probe_frames still climbing)
--
-- PASSIVE: reads only. Writes no machine state. (P3.71.)
local ENGINE = tonumber(os.getenv("P_ENGINE") or "0x2000")
local PRE    = tonumber(os.getenv("P_RT_PRE") or "0")
local POST   = tonumber(os.getenv("P_RT_POST") or "0")
local ERR    = tonumber(os.getenv("P_RT_ERR") or "0")
local FRAMES = tonumber(os.getenv("P_FRAMES") or "0")
local LOADS  = tonumber(os.getenv("P_LOADS") or "0")
local OUT    = os.getenv("P_OUT") or "build/midscene_read.log"

local ROOM_MAGIC = 0x4B00
local mem = manager.machine.devices[":maincpu"].spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true

local f = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end
local function rd8(a) return mem:read_u8(a) end
local function rd16(a) return rd8(a) * 256 + rd8(a + 1) end

local state, t0 = "boot", nil
local pre_fn, post_fn, room_fn = nil, nil, nil
local lo0, n0 = nil, nil

local function tick()
    local fn = scr:frame_number()
    if state == "boot" then
        if fn >= 300 then nk:post('LOADM"ROOM"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if fn > t0 + 900 then nk:post('EXEC\n'); state = "run" end
        return
    end
    if state == "run" then
        if rd16(ENGINE + 6) ~= ROOM_MAGIC then return end
        state, room_fn = "watch", fn
        lo0, n0 = rd8(0xC000), rd8(0xC001)
        log(string.format("# room up at frame %d; bank reads %d/%d", fn, lo0, n0))
        return
    end
    if state ~= "watch" then return end

    if pre_fn == nil and rd8(PRE) == 0xA5 then
        pre_fn = fn
        log(string.format("# READ STARTS at frame %d (+%d after the room)",
                          fn, fn - room_fn))
    end
    if pre_fn and post_fn == nil and rd8(POST) == 0x5A then
        post_fn = fn
        local lo, n = rd8(0xC000), rd8(0xC001)
        log(string.format("# READ RETURNS at frame %d", fn))
        log(string.format("#   FREEZE       %d frames = %.2f s", fn - pre_fn,
                          (fn - pre_fn) / 60.0))
        -- probe_loads is THE success signal: load_tracks increments it only when the
        -- read returned no error. dr_status carries the raw FDC status, in which a
        -- TRAILING RNF is expected and benign for the m=1 whole-track path
        -- [disk_read.s:58-60] — reading it as a verdict is reading the wrong byte.
        log(string.format("#   dr_status    $%02X (raw; RNF b4 is benign here)", rd8(ERR)))
        log(string.format("#   probe_loads  %d (was 3 at startup) — %s", rd8(LOADS),
                          rd8(LOADS) > 3 and "READ SUCCEEDED" or "READ FAILED"))
        log(string.format("#   bank now     %d/%d (was %d/%d) — %s", lo, n, lo0, n0,
                          (lo == lo0 and n == n0) and "INTACT" or "CHANGED"))
        log(string.format("#   probe_frames %d", rd8(FRAMES)))
    end
    if post_fn and fn > post_fn + 240 then
        local lo, n = rd8(0xC000), rd8(0xC001)
        log(string.format("# 240 frames later: bank %d/%d (%s), probe_frames %d — %s",
                          lo, n, (lo == lo0 and n == n0) and "INTACT" or "CHANGED",
                          rd8(FRAMES),
                          rd8(FRAMES) > 0 and "the scene kept running" or "SCENE STALLED"))
        if f then f:close() end
        manager.machine:exit()
    end
    if fn > room_fn + 1200 and pre_fn == nil then
        log("# the test block never fired — RT_AT not reached?")
        if f then f:close() end
        manager.machine:exit()
    end
end

emu.register_frame_done(tick)
