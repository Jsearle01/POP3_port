-- port_flash_trace.lua — P3.85c: what does the port actually put on the palette, and for
-- how long?
--
-- Jay, on the live gate: "you got the flash wrong. it changes the blue color to a light
-- greenish color but doesn't 'flash white at all."
--
-- ★ THE COLOUR VALUE IS NOT THE SUSPECT, and ruling it out first is why this tool watches
-- DURATION. The port's four palette bytes are $00/$26/$1B/$3F [hal gfx.s:255-262]. Read as
-- RGB (bit5..0 = R1 G1 B1 R0 G0 B0) those are black, orange, cyan and WHITE — and the
-- first three are what the scene already shows correctly, so the RGB reading is the one in
-- force and $3F is genuinely white.
--
-- What was never measured is the DUTY CYCLE, and I invented it. The oracle brackets every
-- play with flashon...flashoff [SUBS.S:857-867], so the screen is white for most of a play.
-- char_draw.s writes white for ONE drawn frame and restores on the next. A single ~16 ms
-- white frame over a mostly-cyan scene does not read as a flash; blended, it reads as the
-- cyan going pale, which is the report.
--
-- So: log every write to $FFB0-$FFB3 with its frame, and print the RUNS — how many
-- consecutive frames the palette was white against how many it was normal. That is the
-- number the fix has to change, and it is measured here rather than assumed twice.
local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true
local out = io.open("build/tmp/port_flash.log", "w")
local function log(s) out:write(s .. "\n"); out:flush() end

local writes = {}
local taps = {}
for a = 0xFFB0, 0xFFB3 do
    taps[#taps + 1] = mem:install_write_tap(a, a, "t", function(offset, data)
        writes[#writes + 1] = {scr:frame_number(), a, data}
        return data
    end)
end
_G._taps = taps

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
    if fn < 4200 then return end

    log("# every palette write after the room is up")
    -- reconstruct the four registers frame by frame, so a WHITE frame is a fact about the
    -- displayed palette rather than about one store
    local pal, byframe = {[0xFFB0] = 0x00, [0xFFB1] = 0x26, [0xFFB2] = 0x1B, [0xFFB3] = 0x3F}, {}
    local last = nil
    for _, w in ipairs(writes) do
        local f, a, d = w[1], w[2], w[3]
        if f ~= last and last then
            byframe[#byframe + 1] = {last, pal[0xFFB0], pal[0xFFB1], pal[0xFFB2], pal[0xFFB3]}
        end
        pal[a] = d
        last = f
        log(string.format("    f%-6d $%04X = $%02X", f, a, d))
    end
    if last then
        byframe[#byframe + 1] = {last, pal[0xFFB0], pal[0xFFB1], pal[0xFFB2], pal[0xFFB3]}
    end

    log("")
    log("# the palette after each frame that wrote it — WHITE means all four are $3F")
    local nwhite = 0
    for _, b in ipairs(byframe) do
        local white = (b[2] == 0x3F and b[3] == 0x3F and b[4] == 0x3F and b[5] == 0x3F)
        if white then nwhite = nwhite + 1 end
        log(string.format("    f%-6d %02X %02X %02X %02X   %s",
                          b[1], b[2], b[3], b[4], b[5], white and "<- WHITE" or ""))
    end
    log("")
    log(string.format("# %d writes, %d frames left the palette all-white", #writes, nwhite))
    log("# a flash that reads as a flash needs a RUN of white frames, not one each time.")
    out:close()
    manager.machine:exit()
end)
