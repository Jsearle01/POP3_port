-- harness/tools/oracle_palert_shift.lua
--
-- POP P3.72e — DOES THE PRINCESS MOVE ACROSS HER TURN, ON THE ORACLE?
--
-- Jay, watching both live: "the port has her moving forward during the turn. she doesn't
-- move in the oracle and then moves back when the vizier gets close." The port shifts her
-- four byte-columns right (col 36 -> 40) across Palert.
--
-- WHY THE ARITHMETIC CANNOT SETTLE IT. Palert ends `aboutface,chx,9` [SEQTABLE.S:1565],
-- and the oracle's mirrored blit anchors differently from its normal one --
--
--     MLayGen:  LDA XCO / SEC / SBC WIDTH / STA XCO      [HIRES.S:1202-1208]
--
-- -- so a mirrored image is laid WIDTH to the left of the same coordinate. `chx,9` is
-- compensating for that flip. Whether the two cancel exactly cannot be reasoned across
-- two pixel-unit systems (Apple 7 px/byte vs CoCo 4, CharX in two-pixel units): the
-- oracle's WIDTH is in Apple byte-columns and chx is in CharX units. So measure it.
--
-- THE MEASUREMENT. Take one frame with her standing BEFORE the turn and one AFTER, and
-- report the leftmost and rightmost screen column in her row band that differs between
-- them. She is the only thing in that band that changes, so:
--
--     she did NOT move  -> the differing span is about one cel wide
--     she moved right   -> the span is a cel plus the shift, and its right edge moves
--
-- Columns are reported so the port can be held to the same numbers.
--
-- PASSIVE: pixel reads only. (On 6502 a read-TAP would silently false-0 [CLAUDE.md 2A];
-- this takes no taps at all.)
local OUT    = os.getenv("P_OUT") or "build/oracle_palert_shift.log"
local BEFORE = tonumber(os.getenv("P_BEFORE") or "3480")
local AFTER  = tonumber(os.getenv("P_AFTER")  or "3600")
local X0, X1 = tonumber(os.getenv("P_X0") or "150"), tonumber(os.getenv("P_X1") or "420")
local Y0, Y1 = tonumber(os.getenv("P_Y0") or "104"), tonumber(os.getenv("P_Y1") or "152")

local scr = manager.machine.screens:at(1)
local f = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end

local function grab()
    local t = {}
    for x = X0, X1 do
        local h = 0
        for y = Y0, Y1 do h = (h * 31 + scr:pixel(x, y)) % 4294967296 end
        t[x] = h
    end
    return t
end

local before = nil

local function tick()
    local fn = scr:frame_number()
    if fn == BEFORE then
        before = grab()
        log(string.format("# captured BEFORE at f%d", fn))
    elseif fn == AFTER and before then
        local after = grab()
        local lo, hi, n = nil, nil, 0
        for x = X0, X1 do
            if before[x] ~= after[x] then
                lo = lo or x; hi = x; n = n + 1
            end
        end
        log(string.format("# captured AFTER  at f%d", fn))
        if lo then
            log(string.format("# columns differing: screen x %d..%d  (%d of %d)",
                              lo, hi, n, X1 - X0 + 1))
            log(string.format("# in APPLE px (screen/2): %.1f..%.1f, span %.1f px",
                              lo / 2, hi / 2, (hi - lo + 1) / 2))
        else
            log("# NOTHING differs — she did not move and did not change cel")
        end
        if f then f:close() end
        manager.machine:exit()
    end
end

_G._notifier = emu.add_machine_frame_notifier(tick)
