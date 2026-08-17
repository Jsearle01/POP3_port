-- harness/smoke/mode_live.lua
--
-- POP CoCo3 — P2.5 mode probe, LIVE VIEWING (Jay's 25.3 gate).
--
-- Drives DECB to LOADM"MODE" + EXEC and then gets out of the way. Unlike
-- mode_test.lua this script:
--   * does NOT dump framebuffers (30,720 Lua reads per stage stutters a
--     throttled run and there is nothing to capture here — the screen is the
--     artifact)
--   * does NOT call machine:exit() — the window stays open until Jay closes it
--   * makes no PASS/FAIL claim of any kind. Visual authority is Jay's live MAME
--     (idiom §11); this script only gets the program running.
--
-- Run THROTTLED (no -nothrottle): a no-throttle still-frame manufactures
-- artifacts and is not a live gate (idiom §11).
--
-- The segment-aware LOADM gate is carried over from P2.4: a linked binary has
-- two segments and $0200 lands FIRST, so gating on $0200 alone posts EXEC into
-- a still-running LOADM.

local BIN = os.getenv("P_BIN") or "build/mode_probe.bin"
local OUT = os.getenv("P_OUT") or "build/mode_live.log"

local BOOT_FRAME = 300
local SETTLE     = 1200

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local nk  = manager.machine.natkeyboard
nk.in_use = true

local function decb_segments(path)
    local f = io.open(path, "rb"); if not f then return nil end
    local d = f:read("*a"); f:close()
    local segs, i = {}, 1
    while i <= #d do
        local t = string.byte(d, i)
        if t == 0 then
            local n = string.byte(d, i+1) * 256 + string.byte(d, i+2)
            local a = string.byte(d, i+3) * 256 + string.byte(d, i+4)
            segs[#segs+1] = { addr = a, len = n,
                              first = string.byte(d, i + 5),
                              last  = string.byte(d, i + 5 + n - 1) }
            i = i + 5 + n
        elseif t == 0xFF then break
        else return nil end
    end
    return segs
end
local SEGS = decb_segments(BIN)

local log_file = io.open(OUT, "w")
local function log(s) if log_file then log_file:write(s .. "\n"); log_file:flush() end end
log("# mode_live.lua -- live viewing, throttled. No verdict is produced here.")

local function rd8(a) return mem:read_u8(a) end

local state, loaded_at, seen = "boot", nil, 0
local NAMES = { "16-colour", "4-colour", "16-colour (switched back)", "4-colour (switched back)" }

local function tick()
    local fn = manager.machine.screens:at(1):frame_number()

    if state == "boot" then
        if fn >= BOOT_FRAME then
            nk:post('LOADM"MODE"\n')
            log(string.format("# posted LOADM\"MODE\" at frame %d", fn))
            state = "loadm"
        end
        return
    end

    if state == "loadm" then
        if nk.empty and not loaded_at then
            loaded_at = fn
        elseif loaded_at then
            local b0, b1, b2 = rd8(0x0200), rd8(0x0201), rd8(0x0202)
            local ok = (b0 == 0x7E and b1 == 0x02 and b2 == 0x08)
            if ok and SEGS then
                for _, s in ipairs(SEGS) do
                    if rd8(s.addr) ~= s.first or rd8(s.addr + s.len - 1) ~= s.last then
                        ok = false; break
                    end
                end
            end
            if ok then
                log(string.format("# image loaded at frame %d (%d segments); posting EXEC",
                                  fn, SEGS and #SEGS or 0))
                nk:post('EXEC\n')
                state = "running"
            elseif fn >= loaded_at + SETTLE then
                log("# LOADM did not land -- check the disk image")
                state = "idle"
            end
        end
        return
    end

    if state == "running" then
        local st = rd8(0x0203)
        if st == seen + 1 and st >= 1 and st <= 4 then
            seen = st
            log(string.format("# stage %d  %-28s  $FF99=$%02X  stride=%d  (frame %d)",
                              st, NAMES[st], rd8(0x0204), rd8(0x0205), fn))
        end
        if seen == 4 and rd8(0x0206) * 256 + rd8(0x0207) == 0xD00D then
            log("# cycle complete -- holding the final 4-colour frame. Close MAME when done.")
            state = "idle"
        end
    end
end

_G._ = emu.add_machine_frame_notifier(tick)
