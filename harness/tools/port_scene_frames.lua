-- port_scene_frames.lua — P3.87: RENDER-NEUTRALITY over the whole scene, not over the
-- part a checker happens to composite.
--
-- ★★ WHY THIS EXISTS RATHER THAN "THE SUITES ARE GREEN". Both suites passed the hourglass
-- change on the first run, and NEITHER OF THEM LOOKS AT THE HOURGLASS. verify_room_chars
-- builds its expected framebuffer as "the room asset with the two baked cels composited
-- on" and its own docstring says what is excluded: "The torch columns are excluded because
-- the flames animate; nothing else is." The glass is not in that picture at all, so a hole
-- punched through the glass is not a byte it can call wrong. A green suite that does not
-- cover the change is the stale-checker failure with the roles swapped — the checker is
-- current, the COVERAGE is not.
--
-- So this compares the port against ITSELF: dump the DISPLAYED framebuffer at a fixed set
-- of frames spanning the glass beats, once per build, and diff. Any pixel that moves is a
-- real change; zero means the change was what it claimed to be. That is CLAUDE.md §2F.1's
-- render-neutral gate — framebuffer-diff byte-identical — applied to a speed change, which
-- is the only thing a speed change is allowed to be.
--
-- The displayed buffer is read by borrowing the MMU exactly as room_test.lua does.
local OUT   = os.getenv("P_FRAMES") or "build/tmp/frames"
local CUR_BACK = tonumber(os.getenv("P_CURBACK") or "0x7B06")
local BLOCK_A  = tonumber(os.getenv("P_BLK_A") or "0x10")
local BLOCK_B  = tonumber(os.getenv("P_BLK_B") or "0x14")
local FB_BASE, FB_SIZE = 0x8000, 15360

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true
local log_f = io.open(OUT .. ".log", "w")
local function log(s) log_f:write(s .. "\n"); log_f:flush() end

local function rd8(a) return mem:read_u8(a) end
local function map_blocks(first)
    for i = 0, 1 do mem:write_u8(0xFFA4 + i, first + i) end
end
local function dump_front(path)
    local back = rd8(CUR_BACK)
    local back_blk  = (back == 0) and BLOCK_A or BLOCK_B
    local front_blk = (back == 0) and BLOCK_B or BLOCK_A
    map_blocks(front_blk)
    local t = {}
    for i = 0, FB_SIZE - 1 do t[#t + 1] = string.char(rd8(FB_BASE + i)) end
    map_blocks(back_blk)
    local o = io.open(path, "wb")
    if not o then return false end
    o:write(table.concat(t)); o:close()
    return true
end

-- ★ SAMPLED BY STEP INDEX, NOT BY FRAME NUMBER, and getting this wrong would have made
-- the test meaningless. The change under test alters the PACE, so at frame 4000 the two
-- builds are at different points in the scene and EVERY capture would differ — a correct
-- change reported as a total mismatch. Step N, by contrast, is the same moment of the
-- same beat with the same cels, the same positions and the same sand frame in both
-- builds, so the displayed buffer must be byte-identical there.
--
-- What does NOT match at step N is the TORCH PHASE: the flames run on their own cadence
-- (flm_cad 2,2,3) and were deliberately decoupled from the step at P3.72k, so their phase
-- at a given step is a function of the pace. Those differences are expected and the diff
-- names WHERE it differs so they can be told apart from a real one — which is the whole
-- point of reading a diff rather than its exit code.
local FIRST_STEP = tonumber(os.getenv("P_FIRST_STEP") or "180")
local EVERY      = tonumber(os.getenv("P_EVERY") or "10")
local LAST_STEP  = tonumber(os.getenv("P_LAST_STEP") or "385")

local function readmap(path)
    local m = {}
    for line in io.lines(path) do
        local n, a = line:match("^Symbol: (%S+) .*= *(%x+)$")
        if n then m[n] = tonumber(a, 16) end
    end
    return m
end
local F = readmap("build/obj/flames.map")

local step, want = 0, nil
_G._ts = mem:install_write_tap(F.cad_idx, F.cad_idx, "s", function(o, d)
    step = step + 1
    if step >= FIRST_STEP and step <= LAST_STEP and (step - FIRST_STEP) % EVERY == 0 then
        want = step
    end
    return d
end)

local state, t0 = "boot", nil
_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if state == "boot" then
        if fn >= 300 then nk:post('LOADM"ROOM"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if fn > t0 + 900 then nk:post('EXEC\n'); state = "run" end
        return
    end
    if want then
        local p = string.format("%s_s%04d.bin", OUT, want)
        log(string.format("step %d (f%d) -> %s  %s", want, fn, p,
                          dump_front(p) and "ok" or "FAIL"))
        want = nil
    end
    if step > LAST_STEP then log_f:close(); manager.machine:exit() end
end)
