-- harness/smoke/anim_live.lua
--
-- POP CoCo3 — P2.6 double-buffered animation, LIVE VIEWING (Jay's 25.3 gate).
--
-- DIRECT LOAD, NOT DECB. This pokes the linked binary straight into RAM and sets
-- PC. No LOADM, no EXEC, no keyboard.
--
-- WHY (measured, 2026-07-26): MAME's natkeyboard mis-delivers the SHIFTED double
-- quote on this target. `LOADM"ANIM"` arrived at the DECB prompt as
--     LOADMBANIMB
--     ?SN ERROR
-- i.e. each `"` came through as the letter B. A screen-memory dump confirmed the
-- typed line, so it is keystroke DELIVERY, not the disk and not the filename --
-- ANIM.BIN is present and the identical string loaded fine on other runs in the
-- same session. Intermittent, which is worse than broken.
--
-- For a LIVE gate the disk path proves nothing that matters: Jay is judging
-- whether the animation tears, not whether DECB can parse a filename. The disk
-- path stays covered by harness/smoke/run_anim_test.sh, which does use LOADM.
-- Removing the keyboard removes an intermittent failure from the one run that
-- has a human waiting on it.
--
-- Run THROTTLED (no -nothrottle): a no-throttle still-frame manufactures motion
-- artifacts and is not a live gate (idiom §11). Tearing is exactly the artifact
-- under judgement here, so the frame pacing has to be honest.

local BIN = os.getenv("P_BIN") or "build/anim_probe.bin"
local OUT = os.getenv("P_OUT") or "build/anim_live.log"

local LOAD_FRAME = 120          -- past reset; no DECB interaction needed

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]

local log_file = io.open(OUT, "w")
local function log(s) if log_file then log_file:write(s .. "\n"); log_file:flush() end end
log("# anim_live.lua -- direct load, throttled. No verdict is produced here.")

local function rd8(a) return mem:read_u8(a) end

local NAMES = {
  "16-colour ANIMATED",
  "4-colour  ANIMATED",
  "16-colour ANIMATED (switched back)",
  "4-colour  ANIMATED (switched back)",
  "16-colour NO-SWAP CONTRAST -- should visibly TEAR",
}

local started, seen = false, 0

local function tick()
  local fn = manager.machine.screens:at(1):frame_number()

  if not started then
    if fn < LOAD_FRAME then return end
    local fh = io.open(BIN, "rb")
    if not fh then log("# cannot open " .. BIN); started = true; return end
    local d = fh:read("*a"); fh:close()
    local i, exec = 1, nil
    while i <= #d do
      local t = string.byte(d, i)
      if t == 0 then
        local n = string.byte(d, i+1) * 256 + string.byte(d, i+2)
        local a = string.byte(d, i+3) * 256 + string.byte(d, i+4)
        for j = 0, n - 1 do mem:write_u8(a + j, string.byte(d, i + 5 + j)) end
        log(string.format("# poked %5d bytes -> $%04X", n, a))
        i = i + 5 + n
      elseif t == 0xFF then
        exec = string.byte(d, i+3) * 256 + string.byte(d, i+4); break
      else
        log("# bad DECB record"); break
      end
    end
    if exec then
      cpu.state["PC"].value = exec
      log(string.format("# PC <- $%04X at frame %d -- running", exec, fn))
    end
    started = true
    return
  end

  local st = rd8(0x0203)
  if st == seen + 1 and st >= 1 and st <= 5 then
    seen = st
    log(string.format("# stage %d  %-50s  $FF99=$%02X stride=%3d swaps=%d  (frame %d)",
                      st, NAMES[st], rd8(0x0204), rd8(0x0205),
                      rd8(0x0208) * 256 + rd8(0x0209), fn))
  end
  if seen == 5 and rd8(0x0206) * 256 + rd8(0x0207) == 0xDB16 then
    log("# all five stages done. Close MAME when finished.")
    seen = 6
  end
end

_G._ = emu.add_machine_frame_notifier(tick)
