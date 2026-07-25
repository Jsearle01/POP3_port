-- harness/smoke/cel_test.lua
--
-- POP CoCo3 — P1.2 CEL COLOUR SPOT-CHECK, run inside P1.1's harness.
--
-- Boots coco3, loads src/harness/cel_probe.s (which displays a converted POP cel
-- in the shipping 320x192x4 mode), then reads the FRAMEBUFFER BACK and checks
-- that the palette indices the converter emitted are the palette indices that
-- actually reach the GIME display.
--
-- WHAT THIS PROVES (objective):   converter output == on-screen palette indices.
-- WHAT IT DOES NOT PROVE:         that those colours are the RIGHT colours.
--                                 That is Jay's eye (CLAUDE.md §4). This script
--                                 reports the index histogram; it does not judge.
--
--   P_BIN       cel_probe.bin (DECB binary; direct-load path)
--   P_EXPECT    text file: first line "H W", then H lines of W space-separated
--               decimal byte values — the expected framebuffer content
--   P_OUT/P_PASS/P_FAIL  as probe_test.lua
--
-- Idioms: §0 frame_number; §10 keep the notifier in _G._; §12 forward slashes,
-- io.open not print.

local BIN       = os.getenv("P_BIN")    or "build/cel_probe.bin"
local EXPECT    = os.getenv("P_EXPECT") or "build/cel_expect.txt"
local OUT       = os.getenv("P_OUT")    or "build/cel_test.log"
local PASS_PATH = os.getenv("P_PASS")   or "build/cel_test_PASS"
local FAIL_PATH = os.getenv("P_FAIL")   or "build/cel_test_FAIL"

local ADDR_STATUS, ADDR_H, ADDR_W, ADDR_MAGIC = 0x0203, 0x0204, 0x0205, 0x0206
local MAGIC   = 0xCE10
local FB_A    = 0x8000
local STRIDE  = 80
local BOOT_FRAME, TIMEOUT = 300, 2400

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)

local log_file = io.open(OUT, "w")
local function log(s) if log_file then log_file:write(s .. "\n"); log_file:flush() end end

-- ---------------------------------------------------------------- expected
local exp_h, exp_w, expect = 0, 0, {}
do
    local f = io.open(EXPECT, "r")
    if not f then log("# FATAL: cannot open " .. EXPECT) end
    if f then
        local hdr = f:read("*l")
        exp_h, exp_w = hdr:match("(%d+)%s+(%d+)")
        exp_h, exp_w = tonumber(exp_h), tonumber(exp_w)
        for r = 1, exp_h do
            local row, line = {}, f:read("*l")
            for v in line:gmatch("%d+") do row[#row + 1] = tonumber(v) end
            expect[r] = row
        end
        f:close()
    end
end

log("# cel_test.lua — POP P1.2 cel colour spot-check")
log(string.format("# expected cel: %d rows x %d bytes (%d px wide)", exp_h, exp_w, exp_w * 4))
log("#")

local function decb_load(path)
    local f = io.open(path, "rb"); if not f then return nil, "cannot open " .. path end
    local d = f:read("*a"); f:close()
    local i, exec = 1, nil
    while i <= #d do
        local t = string.byte(d, i)
        if t == 0 then
            local n = string.byte(d, i+1) * 256 + string.byte(d, i+2)
            local a = string.byte(d, i+3) * 256 + string.byte(d, i+4)
            for j = 0, n - 1 do mem:write_u8(a + j, string.byte(d, i + 5 + j)) end
            i = i + 5 + n
        elseif t == 0xFF then
            exec = string.byte(d, i+3) * 256 + string.byte(d, i+4); break
        else return nil, string.format("bad DECB record $%02X", t) end
    end
    return exec
end

local checks = {}
local function check(name, ok, detail)
    checks[#checks+1] = {name = name, ok = ok, detail = detail}
    log(string.format("%-28s %-4s %s", name, ok and "PASS" or "FAIL", detail or ""))
end

local function finish(reason)
    log("#"); log("# " .. reason)
    local failed = 0
    for _, c in ipairs(checks) do if not c.ok then failed = failed + 1 end end
    local verdict = (failed == 0 and #checks > 0) and "PASS" or "FAIL"
    log(string.format("# checks=%d passed=%d failed=%d", #checks, #checks - failed, failed))
    log("# VERDICT: " .. verdict)
    if log_file then log_file:close(); log_file = nil end
    local p = io.open(verdict == "PASS" and PASS_PATH or FAIL_PATH, "w")
    if p then
        p:write(verdict .. "\n")
        for _, c in ipairs(checks) do
            if not c.ok then p:write("  FAILED: " .. c.name .. " — " .. (c.detail or "") .. "\n") end
        end
        p:close()
    end
    manager.machine:exit()
end

local state = "boot"
_G._cel_notifier = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    local pc = cpu.state["PC"].value

    if state == "boot" then
        if fn >= BOOT_FRAME and pc >= 0x8000 then
            local exec, err = decb_load(BIN)
            if not exec then check("load", false, err); finish("load failed"); return end
            cpu.state["PC"].value = exec
            log(string.format("# loaded, PC <- $%04X at frame %d", exec, fn))
            state = "running"
        elseif fn > TIMEOUT then
            check("boot", false, "never settled"); finish("boot timeout")
        end
        return
    end

    if state == "running" then
        if mem:read_u8(ADDR_STATUS) == 2 then
            log(string.format("# cel drawn, complete at frame %d", fn))
            state = "verify"
        elseif fn > TIMEOUT then
            check("cel_probe_completed", false,
                  string.format("status=%d PC=$%04X", mem:read_u8(ADDR_STATUS), pc))
            finish("run timeout")
        end
        return
    end

    if state == "verify" then
        check("magic_is_CE10",
              mem:read_u8(ADDR_MAGIC) * 256 + mem:read_u8(ADDR_MAGIC + 1) == MAGIC,
              string.format("got $%04X", mem:read_u8(ADDR_MAGIC) * 256 + mem:read_u8(ADDR_MAGIC + 1)))

        local gh, gw = mem:read_u8(ADDR_H), mem:read_u8(ADDR_W)
        check("cel_dims_match_source", gh == exp_h and gw == exp_w,
              string.format("guest %dx%dB vs converted.s %dx%dB", gh, gw, exp_h, exp_w))

        -- The spot-check proper: framebuffer == converter output, byte for byte.
        local bad, first = 0, nil
        local hist = {[0]=0,[1]=0,[2]=0,[3]=0}
        for r = 1, exp_h do
            for c = 1, exp_w do
                local got  = mem:read_u8(FB_A + (r-1) * STRIDE + (c-1))
                local want = expect[r][c]
                if got ~= want then
                    bad = bad + 1
                    if not first then
                        first = string.format("row %d byte %d: want $%02X got $%02X", r-1, c-1, want, got)
                    end
                end
                for k = 0, 3 do hist[(got >> (6 - 2*k)) & 3] = hist[(got >> (6 - 2*k)) & 3] + 1 end
            end
        end
        check("framebuffer_matches_converter", bad == 0,
              bad == 0 and string.format("all %d bytes (%d px) identical", exp_h * exp_w, exp_h * exp_w * 4)
                       or string.format("%d/%d bytes differ; first %s", bad, exp_h * exp_w, first))

        -- Objective colour data. Reported, NOT judged.
        local tot = exp_h * exp_w * 4
        log("#")
        log("# ON-SCREEN PALETTE INDEX HISTOGRAM (objective; colour judgement is Jay's)")
        log(string.format("#   0 Black  %5d  %5.1f%%", hist[0], 100*hist[0]/tot))
        log(string.format("#   1 Orange %5d  %5.1f%%", hist[1], 100*hist[1]/tot))
        log(string.format("#   2 Blue   %5d  %5.1f%%", hist[2], 100*hist[2]/tot))
        log(string.format("#   3 White  %5d  %5.1f%%", hist[3], 100*hist[3]/tot))

        finish("spot-check complete")
    end
end)
