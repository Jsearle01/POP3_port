-- harness/smoke/anim_test.lua
--
-- POP CoCo3 — P2.6 double-buffered animation verifier (Clyde's self-check bar).
--
-- WHAT THIS CAN PROVE, AND WHAT IT CANNOT.
--   CAN: the MECHANISM is live. The VBL IRQ is firing (the HAL frame counter
--        advances), swaps are actually happening (HAL_gfx_swaps advances), the
--        back-buffer index alternates, and swaps track frames roughly 1:1 --
--        which is what says the loop is VBL-paced rather than free-running.
--   CANNOT: whether it LOOKS smooth. Tearing is a temporal artifact of WHEN a
--        VOFFSET write lands relative to the raster. No byte check sees it.
--        Jay's live MAME eye is the gate (CLAUDE.md §4, idiom §11); this script
--        never claims otherwise.
--
-- The point of running it first is narrow but real: if the counters are frozen,
-- the animation is broken in a way Jay should not be asked to look at.
--
--   P_BIN / P_OUT / P_PASS / P_FAIL as usual.

local BIN       = os.getenv("P_BIN")  or "build/anim_probe.bin"
local OUT       = os.getenv("P_OUT")  or "build/anim_test.log"
local PASS_PATH = os.getenv("P_PASS") or "build/anim_test_PASS"
local FAIL_PATH = os.getenv("P_FAIL") or "build/anim_test_FAIL"

local A_STAGE, A_VRES, A_STRIDE = 0x0203, 0x0204, 0x0205
local A_MAGIC, A_SWAPS, A_FRAMES, A_BACK = 0x0206, 0x0208, 0x020A, 0x020C
local MAGIC = 0xDB16

-- stage -> expected mode. Stage 5 is the CONTRAST stage: buffering deliberately
-- defeated, so its swap counter must NOT advance. That asymmetry is the check
-- that the swap counter means something.
local STAGES = {
  { n=1, name="16-colour",           vres=0x1E, stride=160, swaps=true  },
  { n=2, name="4-colour",            vres=0x15, stride=80,  swaps=true  },
  { n=3, name="16-colour back",      vres=0x1E, stride=160, swaps=true  },
  { n=4, name="4-colour back",       vres=0x15, stride=80,  swaps=true  },
  { n=5, name="16-colour NO-SWAP",   vres=0x1E, stride=160, swaps=false },
}

local EXEC_SETTLE = 90     -- frames to let DECB reach its prompt (P3.6)
local settle_at
-- TIMEOUT is an ABSOLUTE frame number, so it has to cover the EXEC settle too
-- (P3.6 added 90 frames before the program even starts).
local BOOT_FRAME, SETTLE, TIMEOUT = 300, 1200, 16000

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
            local n = string.byte(d, i+1)*256 + string.byte(d, i+2)
            local a = string.byte(d, i+3)*256 + string.byte(d, i+4)
            segs[#segs+1] = { addr=a, len=n, first=string.byte(d, i+5),
                              last=string.byte(d, i+5+n-1) }
            i = i + 5 + n
        elseif t == 0xFF then break else return nil end
    end
    return segs
end
local SEGS = decb_segments(BIN)

local log_file = io.open(OUT, "w")
local function log(s) if log_file then log_file:write(s.."\n"); log_file:flush() end end
log("# anim_test.lua -- P2.6 double-buffer MECHANISM check. Appearance is Jay's gate.")
log("#")

local function rd8(a) return mem:read_u8(a) end
local function rd16(a) return rd8(a)*256 + rd8(a+1) end

local checks = {}
local function check(name, ok, detail)
    checks[#checks+1] = {ok=ok}
    log(string.format("%-34s %-4s %s", name, ok and "PASS" or "FAIL", detail or ""))
end

local function finish(reason)
    log("#"); log("# "..reason)
    local failed = 0
    for _,c in ipairs(checks) do if not c.ok then failed = failed + 1 end end
    log(string.format("# checks=%d passed=%d failed=%d", #checks, #checks-failed, failed))
    local v = (failed == 0 and #checks > 0) and "PASS" or "FAIL"
    log("# VERDICT: "..v)
    local f = io.open(v == "PASS" and PASS_PATH or FAIL_PATH, "w")
    if f then f:write(reason.."\n"); f:close() end
    if log_file then log_file:close(); log_file = nil end
    manager.machine:exit()
end

local state, loaded_at, cur = "boot", nil, 0
local entry = {}     -- per-stage snapshot at first sight
local back_seen = {} -- per-stage set of back-buffer indices observed

local function screen_dump()
    -- what DECB actually received. A mangled command line is a keyboard race,
    -- not a disk fault, and the two look identical from the memory side.
    for r = 0, 15 do
        local t = {}
        for c = 0, 31 do
            local b = rd8(0x0400 + r*32 + c)
            t[#t+1] = (b >= 0x40 and b <= 0x5F) and string.char(b)
                   or ((b >= 0x60 and b <= 0x7F) and string.char(b - 0x20) or ".")
        end
        local s = table.concat(t)
        if s:gsub("%.", "") ~= "" then log("# screen |" .. s .. "|") end
    end
end

local function tick()
    local fn = manager.machine.screens:at(1):frame_number()

    if state == "boot" then
        if fn >= BOOT_FRAME then
            nk:post('LOADM"ANIM"\n'); log("# posted LOADM\"ANIM\" at frame "..fn)
            state = "loadm"
        end
        return
    end

    if state == "loadm" then
        if nk.empty and not loaded_at then loaded_at = fn
        elseif loaded_at then
            local ok, why = (rd8(0x0200) == 0x7E), nil
            if not ok then why = string.format("$0200 = $%02X, want $7E", rd8(0x0200)) end
            if ok and SEGS then
                for _,s in ipairs(SEGS) do
                    local g0, g1 = rd8(s.addr), rd8(s.addr+s.len-1)
                    if g0 ~= s.first or g1 ~= s.last then
                        why = string.format("seg $%04X..$%04X: got %02X..%02X want %02X..%02X",
                                            s.addr, s.addr+s.len-1, g0, g1, s.first, s.last)
                        ok = false; break
                    end
                end
            end
            -- SETTLE before posting EXEC. The image verifying says only that the
            -- BYTES are in memory; DECB may still be finishing the LOADM and getting
            -- back to its prompt, and a keystroke posted into that window is DROPPED
            -- -- Jay watched the first 'E' of EXEC get eaten. It surfaced when the
            -- disk moved to DMK (P3.6) and loads got 2.5x faster: the race was always
            -- there; the slow JVC load had been hiding it.
            if ok and not settle_at then
                settle_at = fn
                log(string.format("# image loaded at frame %d (%d segments)", fn, #SEGS))
            elseif ok and fn >= settle_at + EXEC_SETTLE and nk.empty then
                log(string.format("# posting EXEC at frame %d", fn))
                nk:post('EXEC\n'); state = "running"
            elseif fn >= loaded_at + SETTLE then
                check("loadm_image_present", false, why or "image never landed"); screen_dump(); finish("LOADM failed")
            end
        end
        return
    end

    if state == "running" then
        local st = rd8(A_STAGE)

        if st >= 1 and st <= 5 and st ~= cur then
            -- close out the previous stage before opening the next
            if cur >= 1 and entry[cur] then
                local s = STAGES[cur]
                local e = entry[cur]
                local dsw = rd16(A_SWAPS) - e.swaps
                local dfr = fn - e.mame        -- MAME frames: an independent clock
                if s.swaps then
                    check(string.format("stage%d_%s_swaps_advanced", s.n, s.name),
                          dsw > 30, string.format("+%d swaps over +%d MAME frames", dsw, dfr))
                    -- VBL-PACED, not free-running. The honest invariant is
                    -- swaps <= VBL frames: every swap waited for at least one
                    -- vertical blank, so none landed mid-scanline. Demanding 1:1
                    -- would be over-specifying -- a frame that takes longer than
                    -- one VBL to draw legitimately yields fewer swaps than frames.
                    check(string.format("stage%d_%s_vbl_paced", s.n, s.name),
                          dfr > 0 and dsw <= dfr,
                          string.format("%d swaps <= %d MAME frames", dsw, dfr))
                    local n = 0; for _ in pairs(back_seen[cur] or {}) do n = n + 1 end
                    check(string.format("stage%d_%s_back_alternates", s.n, s.name),
                          n == 2, string.format("back-buffer indices seen: %d", n))
                else
                    -- the contrast stage must NOT swap; if this "passes" while the
                    -- others also pass, the counter is measuring something real
                    check(string.format("stage%d_%s_no_swaps", s.n, s.name),
                          dsw == 0, string.format("+%d swaps (want 0), over +%d MAME frames", dsw, dfr))
                    check(string.format("stage%d_%s_still_vbl_paced", s.n, s.name),
                          dfr > 100, string.format("stage lasted +%d MAME frames", dfr))
                end
            end

            cur = st
            entry[st] = { swaps = rd16(A_SWAPS), frames = rd16(A_FRAMES), mame = fn }
            back_seen[st] = {}
            local s = STAGES[st]
            log(string.format("# --- stage %d (%s) at frame %d ---", st, s.name, fn))
            check(string.format("stage%d_%s_vres", st, s.name), rd8(A_VRES) == s.vres,
                  string.format("$FF99 $%02X (want $%02X)", rd8(A_VRES), s.vres))
            check(string.format("stage%d_%s_stride", st, s.name), rd8(A_STRIDE) == s.stride,
                  string.format("stride %d (want %d)", rd8(A_STRIDE), s.stride))
        end

        if cur >= 1 then back_seen[cur][rd8(A_BACK)] = true end

        if rd16(A_MAGIC) == MAGIC then
            -- close the final stage
            local s, e = STAGES[cur], entry[cur]
            if e then
                local dsw = rd16(A_SWAPS) - e.swaps
                local dfr = fn - e.mame
                check(string.format("stage%d_%s_no_swaps", s.n, s.name), dsw == 0,
                      string.format("+%d swaps (want 0), over +%d MAME frames", dsw, dfr))
                check(string.format("stage%d_%s_still_vbl_paced", s.n, s.name), dfr > 100,
                      string.format("stage lasted +%d MAME frames", dfr))
            end
            check("all_five_stages_ran", cur == 5, string.format("last stage %d", cur))
            check("vbl_irq_live", rd16(A_FRAMES) > 500,
                  string.format("HAL frame counter reached %d", rd16(A_FRAMES)))
            check("magic_is_DB16", true, "probe reported completion")
            finish("animation cycle complete")
            return
        end

        if fn > TIMEOUT then
            check("completed_before_timeout", false,
                  string.format("stage=%d swaps=%d frames=%d", cur, rd16(A_SWAPS), rd16(A_FRAMES)))
            finish("timeout")
        end
    end
end

_G._ = emu.add_machine_frame_notifier(tick)
