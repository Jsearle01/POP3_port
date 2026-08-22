-- oracle_fore_trace.lua — P5.8: the FOREGROUND PLANE, finally observed.
--
-- §5.170 has read "inferred from source, not yet observed in trace" since P5.0, through six
-- dispatches. This closes the observation half.
--
-- WHAT IS TAPPED, AND WHY IT IS A WRITE TAP.
--   `DRAWFORE lda fgX / beq ]rts` [GRAFIX.S:603-604] -- fgX's byte 0 is the ENTRY COUNT, and
--   ADDFORE increments it as pieces are queued. A WRITE tap on that byte therefore fires once
--   per queued foreground piece and once more when ZEROLSTS clears the list, which is exactly
--   the signal "the foreground plane was used this frame, and by how much".
--
--   ★ IT MUST BE A WRITE TAP. On the 6502 a READ tap silently false-0s through the
--   opcode-fetch bypass [mame-idioms-apple2e-oracle.md §1], so tapping DRAWFORE's own `lda`
--   would report a plane that never runs. Reads of the list CONTENTS are plain mem:read_u8,
--   which is unaffected -- the same split oracle_demo_bg.lua documents.
--
-- WHAT IS READ AT THE PEAK. When the count reaches its high-water mark for a frame the whole
-- list is read out: fgIMG / fgX / fgY / fgOP per entry, so the report can NAME what lands in
-- the plane instead of counting it.
--
-- ORDERING. DRAWALL is jump-table slot 2 at $403 [GRAFIX.S:15-16], so its body address is read
-- from the machine and its JSR operands decoded in order. That gives DRAWMID's and DRAWFORE's
-- real addresses without assembling anything, and the ORDER of the calls is then a property of
-- the bytes rather than of the listing.
--
--   P_AFTER  comma list of frame offsets after arrival to sample (default 300)
--   P_OUT    output prefix (default build/tmp/fore)

local AFTERS = {}
for tok in (os.getenv("P_AFTER") or "300"):gmatch("[^,]+") do
    AFTERS[#AFTERS + 1] = tonumber(tok)
end
table.sort(AFTERS)
local OUT = os.getenv("P_OUT") or "build/tmp/fore"

-- EQ.S, resolved by walking the `ds` chain from each `dum` base (the same resolver P5.6 used
-- and validated against SCRNUM = $23).
local LEVEL   = 0x03F4
local VISSCRN = 0x00CB
local MAXFORE = 100
local fgX, fgY, fgIMG, fgOP = 0xAF21, 0xAF85, 0xAFE9, 0xB04D
local bgXc, midXc = 0xAC01, 0xB115

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)

local log = io.open(OUT .. ".log", "w")
local function say(s) if log then log:write(s .. "\n"); log:flush() end end
local function rd(a) return mem:read_u8(a) end

local frames, arrived, nwrites, done = 0, nil, 0, nil
local peak, peak_frame = 0, 0
local seen = {}                 -- image -> times observed in the fore list
local per_frame = {}            -- frame -> max count seen that frame

-- ARMING: a WRITE to `level` after the machine has booted, the same condition
-- oracle_scene.lua uses. P4.9 reported a PASS off uninitialised RAM by READING one.
_G._arm = mem:install_write_tap(LEVEL, LEVEL, "armlevel", function(off, data, mask)
    nwrites = nwrites + 1
    if not arrived and frames > 600 then arrived = frames end
    return data
end)

-- THE FOREGROUND COUNT. Fires on every ADDFORE and on ZEROLSTS's clear.
-- ★ VisScrn IS RECORDED WITH EVERY SAMPLE, and that is not decoration. The first run of
-- this tool sampled six instants and found the fore list EMPTY on all four that were on a
-- real screen and NON-EMPTY on the two that were mid-transition (VisScrn = $FF, level = $FF)
-- -- the same transition window P5.7 §7.2 flagged. A count without the screen it was taken
-- on cannot tell "the plane is unused in play" from "I looked during a level load".
local dump_at_peak
local by_scrn = {}              -- VisScrn -> {frames=, nonempty=, peak=}
_G._fore = mem:install_write_tap(fgX, fgX, "forecount", function(off, data, mask)
    if not arrived then return data end
    local f, vs = frames, rd(VISSCRN)
    if data > (per_frame[f] or 0) then per_frame[f] = data end
    if data > peak then peak, peak_frame, peak_scrn = data, f, vs end
    local r = by_scrn[vs]
    if not r then r = {frames = {}, nonempty = 0, peak = 0}; by_scrn[vs] = r end
    if not r.frames[f] then r.frames[f] = true; r.n = (r.n or 0) + 1 end
    if data > 0 then r.nonempty = r.nonempty + 1 end
    -- ★ DUMP AT THE PEAK, INSIDE THE TAP, because the list does not survive the frame.
    -- Sampling fgX at a frame boundary reads 0 on a screen whose plane is busy: ADDFORE
    -- fills the list, DRAWFORE consumes it and ZEROLSTS clears it, all within one frame.
    -- The first run of this tool sampled four instants on screen 1, read 0 every time, and
    -- was one step from reporting "the foreground plane is unused in play." The write tap
    -- says 43 non-empty writes on that same screen.
    if data > r.peak then
        r.peak = data
        if data <= MAXFORE then dump_at_peak(vs, data) end
    end
    return data
end)

dump_at_peak = function(vs, n)
    if n == 0 then return end
    local kinds = {}
    for i = 1, n do
        local img, x, y, op = rd(fgIMG + i), rd(fgX + i), rd(fgY + i), rd(fgOP + i)
        local k = string.format("$%02X/%s", img,
                  op == 2 and "sta" or op == 1 and "ora" or op == 0 and "and"
                  or op == 4 and "mask" or ("?" .. op))
        kinds[k] = (kinds[k] or 0) + 1
        seen[img] = (seen[img] or 0) + 1
    end
    local ks = {}
    for k in pairs(kinds) do ks[#ks + 1] = k end
    table.sort(ks)
    local parts = {}
    for _, k in ipairs(ks) do parts[#parts + 1] = string.format("%s x%d", k, kinds[k]) end
    say(string.format("# PEAK on VisScrn %d: %d entries -- %s",
                      vs, n, table.concat(parts, ", ")))
    -- ★ AND THE KID'S BOX AT THE SAME INSTANT, so AC5's overlap is an intersection of two
    -- things read from ONE machine state rather than two figures from different frames.
    -- FCharX is the SCREEN-space copy [GAMEEQ.S:636], 2 bytes, and doubled by SETUPCHAR's
    -- `asl FCharX` -- so it is in HALF-pixels and FCharX/2 is the pixel column.
    say(string.format("#   kid: KidX %d KidY %d posn %d | FCharX %d FCharY %d image %d",
                      rd(0x51), rd(0x52), rd(0x50),
                      rd(0x71) + rd(0x72) * 256, rd(0x73), rd(0x70)))
    for i = 1, n do
        say(string.format("#     fg %2d IMAGE $%02X XCO %3d YCO %3d OP %d",
                          i, rd(fgIMG + i), rd(fgX + i), rd(fgY + i), rd(fgOP + i)))
    end
end

local function dump_list(tag)
    local n = rd(fgX)
    say(string.format("# %s frame %d  fgX=%d  bgX=%d  midX=%d  level=%d VisScrn=%d",
                      tag, frames, n, rd(bgXc), rd(midXc), rd(LEVEL), rd(VISSCRN)))
    if n == 0 or n > MAXFORE then return end
    for i = 1, n do
        local img, x, y, op = rd(fgIMG + i), rd(fgX + i), rd(fgY + i), rd(fgOP + i)
        seen[img] = (seen[img] or 0) + 1
        say(string.format("#    entry %2d  IMAGE $%02X  XCO %3d  YCO %3d  OPACITY $%02X (%s)",
                          i, img, x, y, op,
                          op == 0x8D and "sta" or op == 0x0D and "ora"
                          or op == 0x2D and "and/mask" or "?"))
    end
end

-- DRAWALL's body and the ORDER of its JSRs, decoded from memory.
local function decode_drawall()
    local a = rd(0x403 + 1) + rd(0x403 + 2) * 256      -- `jmp DRAWALL` at $403
    say(string.format("# DRAWALL body at $%04X (from the jump table at $0403)", a))
    local order, p = {}, a
    for _ = 1, 40 do
        local op = rd(p)
        if op == 0x20 then                              -- JSR abs
            order[#order + 1] = rd(p + 1) + rd(p + 2) * 256
            p = p + 3
        elseif op == 0x4C then                          -- JMP abs — DRAWALL ends on one
            order[#order + 1] = -(rd(p + 1) + rd(p + 2) * 256)
            break
        elseif op == 0xAD or op == 0x8D then p = p + 3
        elseif op == 0xF0 or op == 0xD0 then p = p + 2
        else p = p + 1 end
    end
    local s = {}
    for i, v in ipairs(order) do
        s[#s + 1] = string.format("%s$%04X", v < 0 and "jmp " or "", math.abs(v))
    end
    say("# DRAWALL call order: " .. table.concat(s, " -> "))
    return order
end

_G._n = emu.add_machine_frame_notifier(function()
    frames = frames + 1
    if done then
        if frames > done + 20 then log:close(); manager.machine:exit() end
        return
    end
    if not arrived then return end
    if frames == arrived + 2 then decode_drawall() end
    for _, off in ipairs(AFTERS) do
        if frames == arrived + off then dump_list("SAMPLE +" .. off) end
    end
    if frames < arrived + AFTERS[#AFTERS] + 60 then return end
    say("")
    say(string.format("# PEAK fore-list count %d at frame %d (VisScrn %d)",
                      peak, peak_frame, peak_scrn or -1))
    say("# BY SCREEN — VisScrn, frames observed, writes with a non-empty list, peak count:")
    local vs = {}
    for k in pairs(by_scrn) do vs[#vs + 1] = k end
    table.sort(vs)
    for _, k in ipairs(vs) do
        local r = by_scrn[k]
        say(string.format("#   VisScrn %3d : %4d frames, %4d non-empty writes, peak %d %s",
                          k, r.n or 0, r.nonempty, r.peak,
                          k == 255 and "  <- level transition, not play" or ""))
    end
    local nz, tot = 0, 0
    for _, v in pairs(per_frame) do if v > 0 then nz = nz + 1 end; tot = tot + 1 end
    say(string.format("# frames with a NON-EMPTY fore list: %d of %d frames that wrote fgX",
                      nz, tot))
    local ks = {}
    for k in pairs(seen) do ks[#ks + 1] = k end
    table.sort(ks)
    for _, k in ipairs(ks) do
        say(string.format("# fore IMAGE $%02X seen %d time(s)", k, seen[k]))
    end
    done = frames
end)

say("# oracle_fore_trace: arming on a WRITE to level $03F4")
