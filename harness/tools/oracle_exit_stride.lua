-- oracle_exit_stride.lua — P3.99: does the ORACLE's exit walk lurch the way the port's does?
--
-- Jay, at the P3.96 gate: "his walk out still looks like he's skipping not walking. almost
-- like a frame is missing."
--
-- P3.97 measured the port: the drawn column moves +5, +3, +5, +1, +9, -3 through the walk
-- cycle, against the entry walk's smooth -4, -12, -3, +2, -1, -2. The cel sequence, the
-- drawn cel and the CharX deltas are all exactly the oracle's, so what differs is the
-- ANCHOR — the exit is MIRRORED, and a mirrored image is laid one sprite-width to the LEFT
-- of its coordinate. The walk cels are 3,4,5,5,4,4 Apple bytes wide, so the anchor swings
-- 14 px across the cycle.
--
-- ★ P3.98 concluded from source that this is FAITHFUL: the oracle branches to MLAY for a
-- mirrored image [HIRES.S:654] and MLayGen does `LDA XCO / SEC / SBC WIDTH / STA XCO`
-- [HIRES.S:1202-1208], while LayGen — the normal path — has no such arithmetic. The port's
-- draw_x is a transcription of that, citation and all. But §2 ranks the TRACE above the
-- source, and this project has twice been wrong about an apparent defect that was
-- Mechner's own data (P3.51's back-step). So: run it.
--
-- WHAT IS MEASURED. XCO ($01) is the x coordinate every lay routine draws at, and MLayGen
-- REWRITES it after subtracting the width — so the LAST value written to XCO before a draw
-- IS the anchored column. Logging every XCO write with the IMAGE pointer beside it gives
-- the oracle's own drawn column per cel, directly comparable to the port's numbers.
--
-- ★★ WRITE TAPS ONLY. On the 6502 a read-tap on a code address silently false-0s through
-- the opcode-fetch bypass [mame-idioms-apple2e-oracle.md §1]; a store is not a fetch, so a
-- write tap is sound. This is why the marker is XCO and not the MLayGen entry address.
--
-- ARMED ON THE SCENE, NOT ON A FRAME NUMBER. `SPEED` going back to 7 is PlayCut0's own
-- marker immediately before `lda #Vexit` [SUBS.S:729-752, traced at P3.85], so the window
-- opens where the exit begins however long the boot took.
local OUT   = os.getenv("P_OUT") or "build/tmp/oracle_exit_stride.log"
local AFTER = tonumber(os.getenv("P_AFTER") or "1400")   -- frames to record once armed

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local out = io.open(OUT, "w")
local function log(s) out:write(s .. "\n"); out:flush() end

-- addresses from the assembler listings, beside the `ds` that reserves them
local XCO, YCO, IMAGE, TABLE = 0x0001, 0x0002, 0x0004, 0x0007   -- AUTO.LST:2686-2692
local SPEED = 0x030C                                            -- MASTER.LST:530

local PSAND = 0xE14A                                            -- GAMEBG.LST:311

-- ★ ARM ON THE SEQUENCE, NOT ON ONE VALUE. PlayCut0 writes SPEED 7 in more than one
-- place, so the first one after boot is NOT the line before `lda #Vexit` — the first cut
-- of this tool armed at f3597, which is well before the vizier even approaches. The three
-- markers P3.85 traced are ordered and unambiguous [SUBS.S:722-752]:
--
--     A  SPEED = 12       the hourglass beat begins
--     B  psandcount = 0   the sand starts flowing
--     C  SPEED = 7        ...and the next line is `lda #Vexit`
--
-- so C only counts once A and B have been seen, in that order.
local seenA, seenB, armed_at, rows = false, false, nil, {}

_G._tspeed = mem:install_write_tap(SPEED, SPEED, "sp", function(offset, data)
    if data == 12 then seenA = true end
    if data == 7 and seenA and seenB and armed_at == nil then
        armed_at = scr:frame_number()
    end
    return data
end)
_G._tsand = mem:install_write_tap(PSAND, PSAND, "ps", function(offset, data)
    if data == 0 and seenA then seenB = true end
    return data
end)

_G._txco = mem:install_write_tap(XCO, XCO, "x", function(offset, data)
    if armed_at == nil then return data end
    local fn = scr:frame_number()
    if fn > armed_at + AFTER then return data end
    rows[#rows + 1] = { f = fn, x = data,
                        y = mem:read_u8(YCO),
                        img = mem:read_u8(IMAGE) + mem:read_u8(IMAGE + 1) * 256,
                        tab = mem:read_u8(TABLE) + mem:read_u8(TABLE + 1) * 256 }
    return data
end)

_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if armed_at == nil or fn <= armed_at + AFTER then return end

    log(string.format("# armed at frame %d (SPEED -> 7, the line before `lda #Vexit`)",
                      armed_at))
    log(string.format("# %d XCO writes in the %d frames after", #rows, AFTER))
    log("")
    log("# ★ CONSECUTIVE WRITES IN THE SAME FRAME ARE THE ANCHOR AT WORK: SETUPCHAR puts")
    log("#   the coordinate in, then MLayGen subtracts the image's WIDTH and puts it back.")
    log("#   A pair whose difference VARIES from draw to draw is the per-cel width moving.")
    log("")
    log("    frame    XCO   YCO   IMAGE   TABLE   note")
    local prevf, prevx = nil, nil
    for _, r in ipairs(rows) do
        local note = ""
        if prevf == r.f and prevx ~= nil then
            note = string.format("<-- rewritten, %+d", r.x - prevx)
        end
        log(string.format("    %-8d %-5d %-5d $%04X  $%04X  %s",
                          r.f, r.x, r.y, r.img, r.tab, note))
        prevf, prevx = r.f, r.x
    end
    out:close()
    manager.machine:exit()
end)
