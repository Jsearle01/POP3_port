-- capture_run.lua — record the port end to end, in SEGMENTS, from one boot.
--
-- WHY SEGMENTS. MAME's `-aviwrite` is uncompressed 24-bpp DIB — 640x236x3 at 60 fps is
-- ~27 MB per emulated second [mame-idioms-coco3-port.md §27] — and the whole sequence is
-- ~11,400 frames, which is ~5 GB. That is past what a single RIFF file should be asked to
-- hold. MAME's Lua exposes `video:begin_recording()` / `video:end_recording()`, so the run
-- is cut into files of a fixed frame count from ONE boot, and ffmpeg concatenates them.
-- One boot also means one deterministic timeline: the segments join exactly.
--
-- IT ALSO DROPS THE BOOT. Recording starts at P_START, after DECB has been driven through
-- LOADM + EXEC, so the ~20 s of black BASIC prompt is never written to disk at all --
-- cheaper than trimming 550 MB of it in ffmpeg afterwards.
--
-- The launch path is the REAL one (CLAUDE.md §4 `live-disk`): boot, LOADM"LOADER", EXEC off
-- a mounted floppy. Frame numbers of every state change are logged so the encode can be
-- trimmed against measured values rather than guessed ones.
--
--   P_START  frame to start recording at (default 1200; the port's first swap is ~1284)
--   P_STATUS address of the intro's probe_status (default $2003, from build/obj/introseq.map)
--   P_DONE   the value that means "sequence finished" (default 8 = BEAT_COUNT+2)
--   P_TAIL   frames to keep after DONE, so the last picture is seen (default 270, ~4.5 s)
--   P_END    hard frame cap, in case DONE never arrives (default 12600)
--   P_SEG    frames per segment          (default 2700, ~1.2 GB each)
--   P_PREFIX segment filename prefix     (default "pop_seg")
--   P_OUT    log path
--
-- NOTE: `-aviwrite` and this API both write into MAME's snapshot_directory (default snap/),
-- NOT the working directory. That is idiom §27's first gotcha and it reads as "no file
-- produced" when the file exists.
local START  = tonumber(os.getenv("P_START") or "1200")
local FINISH = tonumber(os.getenv("P_END") or "12600")
local STATUS = tonumber(os.getenv("P_STATUS") or "8195")     -- $2003
local DONE   = tonumber(os.getenv("P_DONE") or "8")          -- BEAT_COUNT + 2
local TAIL   = tonumber(os.getenv("P_TAIL") or "270")
local SEG    = tonumber(os.getenv("P_SEG") or "2700")
local PREFIX = os.getenv("P_PREFIX") or "pop_seg"
local OUT    = os.getenv("P_OUT") or "build/tmp/capture_run.log"

local log_file = io.open(OUT, "w")
local function log(s) log_file:write(s .. "\n"); log_file:flush() end

local vid = manager.machine.video
local nk  = manager.machine.natkeyboard
nk.in_use = true

local BOOT2 = 300          -- same as introseq_live.lua: DECB is ready by here
local state, t0 = "boot", nil
local seg, recording = 0, false
local mem = manager.machine.devices[":maincpu"].spaces["program"]
local stop_at = nil

log(string.format("# capture_run: start %d, end %d, %d frames per segment", START, FINISH, SEG))

local function start_seg(fn)
    seg = seg + 1
    local name = string.format("%s_%02d.avi", PREFIX, seg)
    vid:begin_recording(name, "avi")
    recording = true
    log(string.format("# frame %6d  BEGIN  %s", fn, name))
end

local function stop_seg(fn)
    if not recording then return end
    vid:end_recording()
    recording = false
    log(string.format("# frame %6d  END", fn))
end

_G._n = emu.add_machine_frame_notifier(function()
    local fn = manager.machine.screens:at(1):frame_number()

    if state == "boot" and fn >= BOOT2 then
        nk:post('LOADM"LOADER"\n')
        log("# frame " .. fn .. "  posted LOADM\"LOADER\"")
        state = "loadm"; t0 = fn
    elseif state == "loadm" and fn > t0 + 500 then
        nk:post('EXEC\n')
        log("# frame " .. fn .. "  posted EXEC")
        state = "run"
    end

    -- ★ END WHERE THE PROGRAM ENDS, not at a guessed frame. probe_status carries
    -- beat+2 and settles at BEAT_COUNT+2 when the sequencer reaches sq_hold.
    if state == "run" and not stop_at and mem:read_u8(STATUS) == DONE then
        stop_at = fn + TAIL
        log(string.format("# frame %6d  probe_status = %d (DONE); stopping at %d",
                          fn, DONE, stop_at))
    end

    if fn >= FINISH or (stop_at and fn >= stop_at) then
        if recording then
            stop_seg(fn)
            log("# done — " .. seg .. " segment(s)")
            log_file:close()
        end
        manager.machine:exit()
        return
    end

    if fn >= START then
        if not recording then
            start_seg(fn)
        elseif (fn - START) % SEG == 0 then
            stop_seg(fn)
            start_seg(fn)
        end
    end
end)
