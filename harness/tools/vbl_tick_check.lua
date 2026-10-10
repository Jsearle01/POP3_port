-- harness/tools/vbl_tick_check.lua
--
-- POP P5.34 — DOES THE PROGRAM LOSE VBL TICKS? (P5.34 §4B; P5.31 is the precedent: xf_blit's
-- per-row window ran with DP != 0, the HAL's handler incremented the wrong byte, and the kid's
-- steps came out 5-8 frames against a requested 6.)
--
-- The HAL's VBL handler counts frames into $0010-$0011 (big-endian; time.s, hal_frame_hi/lo).
-- Over a window of real video frames (MAME's own screen frame number) while the kid-run probe is
-- running, the counter must advance by EXACTLY as many frames. Any shortfall is lost ticks.
-- PASSIVE: reads two bytes and the frame number; writes nothing except kr_nact before EXEC.
local OUT = os.getenv("P_OUT") or "build/vbl_tick_check.log"
local WINDOW = tonumber(os.getenv("P_WINDOW") or "1200")
local NACT = os.getenv("P_NACT")
local STATUS = tonumber(os.getenv("S_probe_status"), 16)
local KRNACT = tonumber(os.getenv("S_kr_nact") or "0", 16)
local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local nk = manager.machine.natkeyboard
nk.in_use = true
local f = io.open(OUT, "w")
local function log(s) f:write(s .. "\n"); f:flush() end
local function cnt() return mem:read_u8(0x10) * 256 + mem:read_u8(0x11) end
local state, t0, c0, f0, settle = "boot", 0, 0, 0, 0
_G._vt = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if state == "boot" and fn >= 300 then
        nk:post('LOADM"KIDRUN"\n'); state, t0 = "load", fn
    elseif state == "load" and fn > t0 + 600 then
        if NACT and NACT ~= "" then mem:write_u8(KRNACT, tonumber(NACT)) end
        nk:post('EXEC\n'); state, t0 = "run", fn
    elseif state == "run" and mem:read_u8(STATUS) == 4 then
        settle = settle + 1
        if settle == 120 then                      -- two seconds into the run, then measure
            c0, f0 = cnt(), fn; state = "measure"
            log(string.format("# window starts: frame %d, HAL count %d", fn, c0))
        end
    elseif state == "measure" and fn - f0 >= WINDOW then
        local dc = (cnt() - c0) & 0xFFFF
        log(string.format("# window ends:   frame %d, HAL count %d", fn, cnt()))
        log(string.format("VBL actors=%s  real frames %d  HAL ticks %d  LOST %d",
            NACT or "2", fn - f0, dc, (fn - f0) - dc))
        manager.machine:exit()
    elseif state == "run" and fn - t0 > 6000 then
        log("# timeout: the probe never reached status 4"); manager.machine:exit()
    end
end)
