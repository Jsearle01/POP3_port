-- harness/smoke/probe_test.lua
--
-- POP CoCo3 — P1.1 loop-probe verifier. The TEST half of the CLAUDE.md §1
-- contract (25.1 = build.bat + run_*_test).
--
-- Boots coco3, gets src/harness/loop_probe.s running, then checks its
-- observables against a SPEC and writes PASS/FAIL sentinels.
--
-- This script is deliberately parameterised by environment so that a
-- DELIBERATELY WRONG spec can be injected — a harness that cannot fail is
-- not a test (dispatch §2(e)).
--
--   P_MODE        "disk" (DECB LOADM+EXEC via natkeyboard) | "direct" (poke+setPC)
--   P_BIN         path to loop_probe.bin        (direct mode; forward slashes)
--   P_OUT         log path                      (forward slashes)
--   P_PASS        PASS sentinel path
--   P_FAIL        FAIL sentinel path
--   P_EXPECT_VBLS expected VBL count            (spec; probe hard-codes 120)
--   P_EXPECT_A    expected frame-A fill byte    (spec; probe uses $1B)
--   P_EXPECT_B    expected frame-B fill byte    (spec; probe uses $E4)
--
-- IDIOMS USED (mame-idioms-coco3-port.md — looked up, not rediscovered):
--   §0  no Lua cycle counter -> time is measured in VBLs via frame_number()
--   §1  the CoCo3 has NO autoboot; the entry point is DECB
--   §2  autoboot-script and interactive input are mutually exclusive ->
--       drive DECB with natkeyboard:post, after boot settles
--   §10 the tap/notifier GC gotcha -> keep the notifier in _G._
--   §12 Windows paths in Lua must use forward slashes; write output with
--       io.open, never print() (the console is not captured headless)

local MODE      = os.getenv("P_MODE") or "disk"
local BIN       = os.getenv("P_BIN")
local OUT       = os.getenv("P_OUT")  or "build/probe_test.log"
local PASS_PATH = os.getenv("P_PASS") or "build/probe_test_PASS"
local FAIL_PATH = os.getenv("P_FAIL") or "build/probe_test_FAIL"

local EXPECT_VBLS = tonumber(os.getenv("P_EXPECT_VBLS") or "120")
local EXPECT_A    = tonumber(os.getenv("P_EXPECT_A")    or "27")   -- $1B
local EXPECT_B    = tonumber(os.getenv("P_EXPECT_B")    or "228")  -- $E4

-- Fixed observable block published by loop_probe.s (see its header).
local ADDR_STATUS = 0x0203
local ADDR_VBLS   = 0x0204
local ADDR_MAGIC  = 0x0206
local PROBE_MAGIC = 0xBEEF
local FB_A, FB_B, FB_LEN = 0x8000, 0xC000, 15360
local EXEC_ADDR   = 0x0200

local BOOT_FRAME  = 300     -- DECB settled (karateka smoke uses 300)
local SETTLE      = 900     -- max frames to wait for LOADM to land the image
local TIMEOUT     = 2400    -- hard stop (~40 s emulated)
local VBL_TOL     = 2       -- MAME-vs-6809 frame agreement tolerance

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard

-- NATKEYBOARD GOTCHA 1 (measured P1.1): natkeyboard.in_use defaults to FALSE,
-- and arming it in the same frame as the first post SCRAMBLES that post
-- (observed: 'PRINT 7*6' arrived as 'PREPRINT' -> ?SN ERROR). Arm it at script
-- load, frames before any keystroke.
nk.in_use = true

-- NATKEYBOARD GOTCHA 2 (measured P1.1): posting is ASYNCHRONOUS and slow on
-- this target — a 12-character LOADM took ~130 frames to drain. Fixed frame
-- gaps between posts race it. Gate every subsequent post on `nk.empty`.
-- (Both "\n" and "\r" work as ENTER here; "\n" is used below.)

local log_file = io.open(OUT, "w")
local function log(s)
    if log_file then log_file:write(s .. "\n"); log_file:flush() end
end

log("# probe_test.lua — POP P1.1 loop-probe verifier")
log(string.format("# mode=%s expect_vbls=%d expect_A=$%02X expect_B=$%02X",
                  MODE, EXPECT_VBLS, EXPECT_A, EXPECT_B))
log("#")

-- ---------------------------------------------------------------- helpers
local function rd8(a)  return mem:read_u8(a) end
local function rd16(a) return mem:read_u8(a) * 256 + mem:read_u8(a + 1) end

-- Parse a DECB binary and poke it in (direct mode). Segment records are
-- type 0: [00][len16][addr16][data]; terminator type $FF: [FF][xx16][exec16].
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
            log(string.format("# direct: %d bytes -> $%04X", n, a))
            i = i + 5 + n
        elseif t == 0xFF then
            exec = string.byte(d, i+3) * 256 + string.byte(d, i+4); break
        else
            return nil, string.format("bad DECB record type $%02X at offset %d", t, i)
        end
    end
    return exec
end

-- Scan a framebuffer; return (mismatch_count, first_bad_addr, first_bad_val).
local function fb_scan(base, want)
    local bad, first_a, first_v = 0, nil, nil
    for i = 0, FB_LEN - 1 do
        local v = rd8(base + i)
        if v ~= want then
            bad = bad + 1
            if not first_a then first_a, first_v = base + i, v end
        end
    end
    return bad, first_a, first_v
end

-- ---------------------------------------------------------------- verdict
local checks = {}
local function check(name, ok, detail)
    checks[#checks+1] = { name = name, ok = ok, detail = detail }
    log(string.format("%-28s %-4s %s", name, ok and "PASS" or "FAIL", detail or ""))
end

local function finish(reason)
    log("#")
    log("# " .. reason)
    local failed = 0
    for _, c in ipairs(checks) do if not c.ok then failed = failed + 1 end end
    log(string.format("# checks=%d passed=%d failed=%d",
                      #checks, #checks - failed, failed))

    local verdict = (failed == 0 and #checks > 0) and "PASS" or "FAIL"
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

-- ---------------------------------------------------------------- run loop
local state    = "boot"
local f_start, f_done = nil, nil
local loaded_at = nil

_G._probe_notifier = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    local pc = cpu.state["PC"].value

    -- ---- boot: wait for DECB to settle (PC in ROM) ----
    if state == "boot" then
        if fn >= BOOT_FRAME and pc >= 0x8000 then
            if MODE == "direct" then
                local exec, err = decb_load(BIN)
                if not exec then
                    check("decb_load", false, err or "unknown"); finish("direct load failed"); return
                end
                cpu.state["PC"].value = exec
                log(string.format("# direct: PC <- $%04X at frame %d", exec, fn))
                state = "running"
            else
                -- §1/§2: no autoboot; drive DECB through the natural keyboard.
                nk:post('LOADM"PROBE"\n')
                log(string.format('# disk: posted LOADM"PROBE" at frame %d', fn))
                state = "loadm"
            end
        elseif fn > TIMEOUT then
            check("boot", false, string.format("DECB never settled by frame %d (PC=$%04X)", fn, pc))
            finish("boot timeout")
        end
        return
    end

    -- ---- disk mode: wait for the keys to drain AND LOADM to finish ----
    if state == "loadm" then
        if nk.empty and not loaded_at then
            loaded_at = fn
            log(string.format("# disk: keystrokes drained at frame %d", fn))
        elseif loaded_at then
            -- POLL for the image rather than waiting a fixed number of frames.
            -- LOADM takes ~400 frames here (MAME drive spin-up + seek), and any
            -- fixed settle either races the load or wastes emulated seconds.
            -- Waiting on the observable is the robust form.
            local b0, b1, b2 = rd8(0x0200), rd8(0x0201), rd8(0x0202)
            if b0 == 0x7E and b1 == 0x02 and b2 == 0x08 then
                log(string.format("# disk: image present at frame %d ($0200 = %02X %02X %02X)",
                                  fn, b0, b1, b2))
                nk:post('EXEC\n')
                log(string.format("# disk: posted EXEC at frame %d", fn))
                state = "running"
            elseif fn >= loaded_at + SETTLE then
                check("loadm_image_present", false,
                      string.format("$0200 = %02X %02X %02X after %d frames; want 7E 02 08",
                                    b0, b1, b2, SETTLE))
                finish("LOADM failed")
            end
        end
        return
    end

    -- ---- running: watch the probe's published status ----
    if state == "running" then
        local st = rd8(ADDR_STATUS)
        if st == 1 and not f_start then
            f_start = fn
            log(string.format("# probe RUNNING at frame %d (PC=$%04X)", fn, pc))
        elseif st == 2 and f_start and not f_done then
            f_done = fn
            log(string.format("# probe COMPLETE at frame %d", fn))
            state = "verify"
        elseif fn > TIMEOUT then
            check("probe_reached_completion", false,
                  string.format("status=%d at frame %d (PC=$%04X); never reached 2", st, fn, pc))
            finish("run timeout")
        end
        return
    end

    -- ---- verify: one shot, against the SPEC ----
    if state == "verify" then
        local magic  = rd16(ADDR_MAGIC)
        local status = rd8(ADDR_STATUS)
        local vbls   = rd16(ADDR_VBLS)

        check("magic_is_BEEF", magic == PROBE_MAGIC,
              string.format("want $%04X got $%04X", PROBE_MAGIC, magic))
        check("status_is_complete", status == 2,
              string.format("want 2 got %d", status))
        check("probe_vbl_count", vbls == EXPECT_VBLS,
              string.format("want %d got %d", EXPECT_VBLS, vbls))

        local badA, aA, vA = fb_scan(FB_A, EXPECT_A)
        check("framebuffer_A_fill", badA == 0,
              badA == 0 and string.format("all %d bytes = $%02X", FB_LEN, EXPECT_A)
                        or string.format("%d/%d bytes wrong; first $%04X = $%02X (want $%02X)",
                                         badA, FB_LEN, aA, vA, EXPECT_A))

        local badB, aB, vB = fb_scan(FB_B, EXPECT_B)
        check("framebuffer_B_fill", badB == 0,
              badB == 0 and string.format("all %d bytes = $%02X", FB_LEN, EXPECT_B)
                        or string.format("%d/%d bytes wrong; first $%04X = $%02X (want $%02X)",
                                         badB, FB_LEN, aB, vB, EXPECT_B))

        -- The timing evidence: the 6809 counted VBLs off the GIME VBORD latch;
        -- MAME counted frames off the video timing. Two independent clocks must
        -- agree, or the "VBL" the probe is polling is not a vertical blank.
        local delta = f_done - f_start
        check("mame_frames_match_vbls", math.abs(delta - EXPECT_VBLS) <= VBL_TOL,
              string.format("MAME frame delta %d vs expected %d (tol +/-%d)",
                            delta, EXPECT_VBLS, VBL_TOL))

        finish(string.format("run complete: f_start=%d f_done=%d", f_start, f_done))
    end
end)
