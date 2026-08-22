-- oracle_phase_trace.lua — P5.10: how many SUB-BYTE PHASES each cel is actually drawn at.
--
-- ★★ THIS IS A MEASUREMENT, NOT A DERIVATION, AND THAT IS THE POINT. The phase a cel lands on
-- is x mod 4, and x accumulates through `Fdx` along whatever path the player took. Deriving
-- the reachable phase set needs a starting x -- and §5.246's lesson is that a seed chosen for
-- convenience answers the question by itself. A trace has no seed: the machine's own x is
-- whatever the game made it.
--
-- WHAT IS TAPPED. `setimage` [HIRES.S:270] is the single funnel every draw passes through, and
-- the same write tap oracle_frame_drawset.lua uses -- IMAGE+1, the high byte of the resolved
-- cel pointer -- fires once per draw. At that instant the draw's position is already staged:
--
--     XCO     $01   screen X in BYTES, 0..39     [HIRES.S:158]
--     OFFSET  $03   bits to shift right, 0..6    [HIRES.S:160]
--
-- so the Apple pixel column is XCO*7 + OFFSET, and the port's is that plus the 20 px of the
-- 280->320 centring. The CoCo3 sub-byte phase is therefore (XCO*7 + OFFSET + 20) mod 4.
--
-- ★★ OFFSET IS NOT WRITTEN BY EVERY DRAW, AND THE FIRST VERSION OF THIS TOOL READ IT ANYWAY.
-- `:setaddl` [GRAFIX.S:742] does `lda midOFF,x / sta OFFSET` and is called ONLY from the
-- `:lay` and `:layrsave` paths. `:fastlay` never calls it, and neither DRAWBACK nor DRAWFORE
-- has an OFF field at all -- bgX/bgY/bgIMG/bgOP and fgX/fgY/fgIMG/fgOP carry no offset
-- [EQ.S:306-314], because those planes are BYTE-ALIGNED. Only the mid list has midOFF
-- [EQ.S:327-328], which is exactly the plane characters draw in.
--
-- So a byte-aligned draw leaves whatever OFFSET the last SUB-BYTE draw wrote, and reading it
-- reports one character's phase for every tile on the screen. The first run did precisely
-- that and the TILE CONTROL caught it: tiles came back spread over all four phases, which
-- P5.7's arithmetic (28c mod 4 = 0) excludes.
--
-- THE FIX, SECOND ATTEMPT, because the first one was order-dependent and the control caught
-- that too. Clearing `fresh` on an XCO WRITE assumes every path stores XCO before OFFSET.
-- DRAWMID does [GRAFIX.S:690-691 then :setaddl at 742], but DRAWKIDMETER does not: it stores
-- OFFSET from KidStrOFF and XCO from KidStrX in the other order [GAMEBG.S:553-556], so the
-- rule threw away a legitimate offset and the meter bullets came back on the wrong phases.
--
-- `fresh` is therefore cleared BY THE DRAW ITSELF, not by the XCO write. That is correct for
-- all three observed orderings:
--     lay      XCO, OFFSET(set), draw(use+clear)      -- sub-byte, offset used
--     fastlay  XCO, draw(clear)                       -- byte-aligned, offset 0
--     meter    OFFSET(set), XCO, draw(use+clear)      -- sub-byte, offset used
-- A cel that reports BOTH sub-byte and byte-aligned draws is flagged, because that is the
-- one shape this rule cannot distinguish (a single entry calling setimage twice).
--
-- ★ WRITE TAP, NOT A POLL [§5.239]. XCO/OFFSET are staged and consumed inside one draw; a
-- frame-boundary read would find whatever the last draw left.
--
-- ★ AND READS ARE mem:read_u8, NOT a read tap: on the 6502 a read tap false-0s through the
-- opcode-fetch bypass [mame-idioms-apple2e-oracle.md §1].
--
--   P_AFTER  frames after arrival to start recording (default 200)
--   P_LEN    frames to record for (default 3000)
--   P_OUT    output path (default build/tmp/phase_trace.txt)

local START = tonumber(os.getenv("P_AFTER") or "200")
local LEN   = tonumber(os.getenv("P_LEN") or "3000")
local OUT   = os.getenv("P_OUT") or "build/tmp/phase_trace.txt"

local LEVEL   = 0x03F4
local VISSCRN = 0x00CB
local XCO, OFFSET, IMAGE, TABLE_, BANK = 0x01, 0x03, 0x04, 0x07, 0x12

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local out = io.open(OUT, "w")
local function say(s) out:write(s .. "\n") end
local function rd(a) return mem:read_u8(a) end

local frames, armed, done = 0, nil, nil
local fresh, offv = false, 0
local phases = {}          -- "bank:table:addr" -> {[phase]=count}
local dims   = {}          -- key -> "wxh"
local ndraw  = 0

_G._tl = mem:install_write_tap(LEVEL, LEVEL, "lvl", function(off, data, mask)
    if not armed and frames > 600 then armed = frames end
    return data
end)

-- ...and only a sub-byte draw stores OFFSET after it [GRAFIX.S:742 :setaddl].
_G._to = mem:install_write_tap(OFFSET, OFFSET, "off", function(off, data, mask)
    fresh, offv = true, data & 0xFF
    return data
end)

_G._ti = mem:install_write_tap(IMAGE + 1, IMAGE + 1, "img", function(off, data, mask)
    if not armed or done or frames < armed + START then return data end
    local addr = rd(IMAGE) | ((data & 0xFF) << 8)
    if addr < 0x0800 then return data end
    local w, h = rd(addr), rd(addr + 1)
    if w == 0 or h == 0 or w > 40 or h > 200 then return data end
    local bank = rd(BANK)
    local tb = rd(TABLE_) | (rd(TABLE_ + 1) << 8)
    local xc = rd(XCO)
    local px = xc * 7 + (fresh and offv or 0)
    local ph = (px + 20) % 4
    local key = string.format("%d:%04X:%04X", bank, tb, addr)
    local e = phases[key]
    if not e then e = {}; phases[key] = e; dims[key] = string.format("%dx%d", w, h) end
    e[ph] = (e[ph] or 0) + 1
    if fresh then e.sub = (e.sub or 0) + 1 else e.aligned = (e.aligned or 0) + 1 end
    e.xco = e.xco or {}
    e.xco[xc] = true
    fresh = false                       -- consumed by this draw
    ndraw = ndraw + 1
    return data
end)

_G._n = emu.add_machine_frame_notifier(function()
    frames = frames + 1
    if done then
        if frames > done + 10 then out:close(); manager.machine:exit() end
        return
    end
    if not armed or frames < armed + START + LEN then return end
    say("# oracle_phase_trace: " .. ndraw .. " draws over " .. LEN .. " frames")
    say("# key = bank:tablebase:celaddr  wxh  n0 n1 n2 n3  n_sub n_aligned  X<xco list>")
    local ks = {}
    for k in pairs(phases) do ks[#ks + 1] = k end
    table.sort(ks)
    for _, k in ipairs(ks) do
        local e = phases[k]
        local xs = {}
        for x in pairs(e.xco or {}) do xs[#xs + 1] = x end
        table.sort(xs)
        say(string.format("C %s %s %d %d %d %d %d %d X%s", k, dims[k],
                          e[0] or 0, e[1] or 0, e[2] or 0, e[3] or 0,
                          e.sub or 0, e.aligned or 0, table.concat(xs, ",")))
    end
    done = frames
end)

say("# arming on a WRITE to level $03F4")
