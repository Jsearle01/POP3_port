-- harness/smoke/introseq_live.lua
--
-- POP CoCo3 — P3.3 intro sequencer, LIVE VIEWING (Jay's 25.3 gate).
--
-- Starts the sequencer and then gets out of the way. Unlike introseq_test.lua
-- this script:
--   * does NOT dump framebuffers (30,720 Lua reads per capture stutters a
--     throttled run, and the screen IS the artifact here)
--   * does NOT borrow the MMU window for anything
--   * does NOT call machine:exit() — the window stays open until Jay closes it
--   * makes no PASS/FAIL claim of any kind. Visual authority is Jay's live MAME
--     (idiom §11); this script only gets the program running.
--
-- Run THROTTLED (no -nothrottle). That matters more here than on any previous
-- gate: the whole point is the TIMING — 100 frames of splash, 282 of the first
-- caption, 97, then 285 — and the flips that start and end them. Under
-- -nothrottle those durations are meaningless.
--
-- The image is POKED in rather than LOADMed. A program loading at $0200 fills
-- its first granule across $0200-$0AFF and overwrites DECB's DBUF0 ($0600),
-- DBUF1 ($0700), FAT RAM ($0800) and FCBs ($094A) while DECB is still using
-- them, so LOADM dies with ?FS ERROR before the second granule.
-- [karateka_coco3 docs/project/decb-loadm-boot-gates.md; measured again in P3.3]
-- Karateka's answer is src/boot/bootloader.s; POP has not ported it yet.

local BIN = os.getenv("P_BIN") or "build/intro_seq.bin"
local OUT = os.getenv("P_OUT") or "build/introseq_live.log"

local BOOT_FRAME = 240

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]

local log_file = io.open(OUT, "w")
local function log(s) if log_file then log_file:write(s .. "\n"); log_file:flush() end end

local function decb_image(path)
    local f = io.open(path, "rb"); if not f then return nil end
    local d = f:read("*a"); f:close()
    local segs, i, exec = {}, 1, nil
    while i <= #d do
        local t = string.byte(d, i)
        if t == 0 then
            local n = string.byte(d, i+1) * 256 + string.byte(d, i+2)
            local a = string.byte(d, i+3) * 256 + string.byte(d, i+4)
            segs[#segs+1] = { addr = a, len = n, data = d:sub(i + 5, i + 4 + n) }
            i = i + 5 + n
        elseif t == 0xFF then
            exec = string.byte(d, i+3) * 256 + string.byte(d, i+4); break
        else return nil end
    end
    return segs, exec
end

local SEGS, EXEC = decb_image(BIN)
local started = false

local function tick()
    if started then return end
    local fn = manager.machine.screens:at(1):frame_number()
    if fn < BOOT_FRAME then return end
    if not SEGS then log("# could not parse " .. BIN); started = true; return end
    for _, sg in ipairs(SEGS) do
        for j = 0, sg.len - 1 do
            mem:write_u8(sg.addr + j, string.byte(sg.data, j + 1))
        end
        log(string.format("# poked %6d bytes -> $%04X..$%04X",
                          sg.len, sg.addr, sg.addr + sg.len - 1))
    end
    cpu.state["PC"].value = EXEC
    log(string.format("# PC <- $%04X at frame %d -- the sequencer is running", EXEC, fn))
    log("# expect: splash ~1.7 s, \"Presents\" 4.7 s, gap 1.6 s, \"Mechner\" 4.7 s, then the splash holds")
    started = true
end

_G._notifier = emu.add_machine_frame_notifier(tick)
