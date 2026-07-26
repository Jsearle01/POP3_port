-- harness/smoke/mode_test.lua
--
-- POP CoCo3 — P2.5 mode-cycling verifier.
--
-- Boots coco3, LOADMs the linked mode probe, and captures each of the four
-- stages as the probe cycles 16-colour -> 4-colour -> 16-colour -> 4-colour.
--
-- WHAT IT CAN AND CANNOT PROVE. It corroborates; it does not certify appearance.
--   * It CAN check the HAL's published geometry, and that the framebuffer holds
--     the exact bar pattern the active mode's stride implies. A wrong stride
--     produces a skewed image, and a skew shows up here as a row-1 mismatch.
--   * It CANNOT check colour. The GIME palette registers are WRITE-ONLY, and
--     what a palette byte looks like depends on the monitor mode. "The colours
--     are right in each mode" is Jay's eye on a live RGB run (CLAUDE.md §4,
--     idioms §11) — this script never claims it.
--
-- FRAMEBUFFER DUMPS, NOT MAME SNAPSHOTS (idioms §11b): a MAME screen:snapshot()
-- is stretched and, under -nothrottle, manufactures motion artifacts. The raw
-- framebuffer decoded at native 1:1 is the honest image, so each stage is dumped
-- and rendered offline.
--
--   P_BIN   path to mode_probe.bin (forward slashes)
--   P_OUT   log path
--   P_DUMP  directory for per-stage framebuffer dumps
--   P_PASS / P_FAIL  sentinel paths
--
-- IDIOMS USED: §1 no autoboot -> DECB is the entry point; §2 natkeyboard:post
-- after boot settles; §10 keep the notifier in _G._; §12 forward slashes, io.open
-- not print, -seconds_to_run is emulated seconds.

local BIN       = os.getenv("P_BIN")  or "build/mode_probe.bin"
local OUT       = os.getenv("P_OUT")  or "build/mode_test.log"
local DUMP      = os.getenv("P_DUMP") or "build/mode_dumps"
local PASS_PATH = os.getenv("P_PASS") or "build/mode_test_PASS"
local FAIL_PATH = os.getenv("P_FAIL") or "build/mode_test_FAIL"

local ADDR_STAGE  = 0x0203
local ADDR_VRES   = 0x0204
local ADDR_STRIDE = 0x0205
local ADDR_MAGIC  = 0x0206
local PROBE_MAGIC = 0xD00D
-- P2.6: set_mode double-buffers and maps the BACK buffer here (HAL_gfx_draw_base).
local FB_BASE     = 0x6000

-- Expected per stage: {mode name, $FF99, stride, bars, bytes/bar, fb bytes}
-- $FF99 values are the CONFIRMED ones (GIME-RM §10), not derived here.
local STAGES = {
  { n = 1, name = "16-colour", vres = 0x1E, stride = 160, bars = 16, per = 10, size = 30720 },
  { n = 2, name = "4-colour",  vres = 0x15, stride =  80, bars =  4, per = 20, size = 15360 },
  { n = 3, name = "16-colour", vres = 0x1E, stride = 160, bars = 16, per = 10, size = 30720 },
  { n = 4, name = "4-colour",  vres = 0x15, stride =  80, bars =  4, per = 20, size = 15360 },
}

local BOOT_FRAME = 300
local SETTLE     = 900
local TIMEOUT    = 3600

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local nk  = manager.machine.natkeyboard
nk.in_use = true

-- Parse the DECB segment table without writing (P2.4): a linked binary has two
-- segments and $0200 lands FIRST, so gating on $0200 alone posts EXEC into a
-- still-running LOADM.
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
log("# mode_test.lua -- POP P2.5 mode-cycling verifier")
log("#")

local function rd8(a) return mem:read_u8(a) end

local checks = {}
local function check(name, ok, detail)
    checks[#checks+1] = { name = name, ok = ok }
    log(string.format("%-30s %-4s %s", name, ok and "PASS" or "FAIL", detail or ""))
end

-- Dump the active framebuffer so it can be rendered at native 1:1 offline.
local function dump_fb(stage)
    local path = string.format("%s/stage%d_%s.bin", DUMP, stage.n, stage.name)
    local f = io.open(path, "wb")
    if not f then log("# could not open " .. path); return false end
    local t = {}
    for i = 0, stage.size - 1 do t[#t+1] = string.char(rd8(FB_BASE + i)) end
    f:write(table.concat(t)); f:close()
    log(string.format("# stage %d: dumped %d bytes -> %s", stage.n, stage.size, path))
    return true
end

-- The bar pattern the active stride implies. Checking row 1 as well as row 0 is
-- what actually tests the stride: a wrong stride still paints row 0 correctly.
local function verify_pattern(stage)
    local bad = nil
    for row = 0, 1 do
        local base = FB_BASE + row * stage.stride
        for bar = 0, stage.bars - 1 do
            local want
            if stage.bars == 16 then want = bar * 0x11 else want = bar * 0x55 end
            for k = 0, stage.per - 1 do
                local got = rd8(base + bar * stage.per + k)
                if got ~= want then
                    bad = string.format("row %d bar %d +%d: got $%02X want $%02X",
                                        row, bar, k, got, want)
                    break
                end
            end
            if bad then break end
        end
        if bad then break end
    end
    check(string.format("stage%d_%s_pattern", stage.n, stage.name), bad == nil,
          bad or string.format("%d bars x %d B = %d B/row, rows 0-1 exact",
                               stage.bars, stage.per, stage.bars * stage.per))
end

local function finish(reason)
    log("#"); log("# " .. reason)
    local failed = 0
    for _, c in ipairs(checks) do if not c.ok then failed = failed + 1 end end
    log(string.format("# checks=%d passed=%d failed=%d", #checks, #checks - failed, failed))
    local verdict = (failed == 0 and #checks > 0) and "PASS" or "FAIL"
    log("# VERDICT: " .. verdict)
    local p = io.open(verdict == "PASS" and PASS_PATH or FAIL_PATH, "w")
    if p then p:write(reason .. "\n"); p:close() end
    if log_file then log_file:close(); log_file = nil end
    manager.machine:exit()
end

local state, loaded_at, seen = "boot", nil, 0

local function tick()
    local fn = manager.machine.screens:at(1):frame_number()

    if state == "boot" then
        if fn >= BOOT_FRAME then
            nk:post('LOADM"MODE"\n')
            log(string.format("# disk: posted LOADM\"MODE\" at frame %d", fn))
            state = "loadm"
        end
        return
    end

    if state == "loadm" then
        if nk.empty and not loaded_at then
            loaded_at = fn
        elseif loaded_at then
            local b0, b1, b2 = rd8(0x0200), rd8(0x0201), rd8(0x0202)
            local all_in = (b0 == 0x7E and b1 == 0x02 and b2 == 0x08)
            if all_in and SEGS then
                for _, s in ipairs(SEGS) do
                    if rd8(s.addr) ~= s.first or rd8(s.addr + s.len - 1) ~= s.last then
                        all_in = false; break
                    end
                end
            end
            if all_in then
                log(string.format("# disk: image present at frame %d (%d segments verified)",
                                  fn, SEGS and #SEGS or 0))
                nk:post('EXEC\n')
                state = "running"
            elseif fn >= loaded_at + SETTLE then
                check("loadm_image_present", false,
                      string.format("$0200 = %02X %02X %02X after %d frames", b0, b1, b2, SETTLE))
                finish("LOADM failed")
            end
        end
        return
    end

    if state == "running" then
        local st = rd8(ADDR_STAGE)
        if st == seen + 1 and st >= 1 and st <= 4 then
            seen = st
            local stage = STAGES[st]
            local vres, stride = rd8(ADDR_VRES), rd8(ADDR_STRIDE)
            log(string.format("# --- stage %d (%s) at frame %d ---", st, stage.name, fn))
            -- The HAL's published geometry, read back from the probe's mirror.
            check(string.format("stage%d_%s_vres", st, stage.name), vres == stage.vres,
                  string.format("$FF99 recorded $%02X (want $%02X, GIME-RM §10)", vres, stage.vres))
            check(string.format("stage%d_%s_stride", st, stage.name), stride == stage.stride,
                  string.format("stride %d (want %d)", stride, stage.stride))
            verify_pattern(stage)
            dump_fb(stage)
        end

        if rd8(ADDR_MAGIC) * 256 + rd8(ADDR_MAGIC + 1) == PROBE_MAGIC then
            check("all_four_stages_ran", seen == 4,
                  string.format("observed %d of 4 stages", seen))
            check("magic_is_D00D", true, "probe reported completion")
            finish("mode cycle complete")
            return
        end

        if fn > TIMEOUT then
            check("completed_before_timeout", false,
                  string.format("stage=%d magic=$%02X%02X at frame %d",
                                seen, rd8(ADDR_MAGIC), rd8(ADDR_MAGIC + 1), fn))
            finish("timeout")
        end
    end
end

-- idiom §10: the notifier is garbage-collected unless a global holds it.
_G._ = emu.add_machine_frame_notifier(tick)
