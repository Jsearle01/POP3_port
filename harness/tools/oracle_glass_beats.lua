-- oracle_glass_beats.lua — P3.85: trace the three beats between Pback and Vexit.
--
-- PlayCut0 [SUBS.S:722-737], immediately after Pback's thirteen plays:
--
--     ldx #0 / jsr addglass1        ; the hourglass APPEARS      <- marker A
--     lda #5 / sta lightning        ; ...with a 5-frame flash
--     lda #12 / sta SPEED           ; and the pace CHANGES
--     lda #5  / jsr play
--     lda #0  / sta psandcount      ; the sand STARTS FLOWING    <- marker B
--     lda #s_Magic / jsr PlaySongI  ; a third cue, never traced
--     lda #7  / sta SPEED           ; ...and the pace goes back  <- marker C
--     lda #Vexit                    ; he turns to leave
--
-- So A->B is the five plays at SPEED 12 and B->C is s_Magic. Both are measured here for
-- the same reason the other two cues were (P3.72l): PlaySongI BLOCKS for as long as the
-- song lasts and its X operand is only the sound-OFF fallback (P3.52), so the source
-- cannot give the duration and the trace must.
--
-- ★ THIS TOOL WATCHES THE VARIABLES, NOT THE SCREEN — after two screen-watching versions
-- gave two different wrong answers. Addresses from the assembler listings in
-- oracle/source/obj/*.LST, which carry them next to the `ds` that reserves them:
--
--     SPEED       $030C   [MASTER.LST:530]
--     lightning   $0088   [MASTER.LST:406]
--     psandcount  $E14A   [GAMEBG.LST:311]
--
-- Why the screen could not do it, recorded so the next reader does not retry it:
--
--  (1) A PER-OBJECT BOX ON THE GLASS CATCHES THE PRINCESS. She stands across the same
--      columns until Pback backs her away, so "the glass appeared" and "she turned" were
--      the same signal — the first version reported both boxes changing at f3487, which
--      is Palert.
--
--  (2) ★ COUNTING NON-BLACK PIXELS MISSES A SHAPE CHANGE THAT KEEPS THE COUNT. The second
--      version reported a 26.6-second hold across the stretch where the sand is supposed
--      to be flowing, because the three flow cels have near-equal ink and a census of "how
--      many pixels are lit" cannot see one replace another. A hold measured by a lossy
--      summary reads as LONGER than it is, silently and always in that direction.
--
--  (3) And even with a hash, a beat is only visible as a gap if NOTHING moves during it —
--      but the sand flows through s_Magic, so the cue this dispatch needs is precisely the
--      one the gap method cannot see. The screen was the wrong instrument for it.
--
-- WRITE taps, not read taps: on the 6502 a read tap silently false-0s through the
-- opcode-fetch bypass [mame-idioms-apple2e-oracle.md], but a store is not a fetch.
local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local out = io.open("build/oracle_glass_beats.log", "w")
local function log(s) out:write(s .. "\n"); out:flush() end

local VARS = {
    {name = "SPEED",      addr = 0x030C},
    {name = "lightning",  addr = 0x0088},
    {name = "psandcount", addr = 0xE14A},
}

local marks = {}          -- every write, in order
local taps = {}
for _, v in ipairs(VARS) do
    taps[#taps + 1] = mem:install_write_tap(v.addr, v.addr, "t", function(offset, data)
        marks[#marks + 1] = {scr:frame_number(), v.name, data}
        return data
    end)
end
_G._taps = taps

_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if fn < 9200 then return end

    -- Collapse: only report a write that CHANGES the value, and for psandcount only the
    -- store of 0 that starts the flow (the sand counter is decremented every frame).
    log("# every value-changing write, f4000 onward")
    local last = {}
    local kept = {}
    for _, m in ipairs(marks) do
        local fnw, nm, d = m[1], m[2], m[3]
        if fnw >= 4000 and last[nm] ~= d then
            last[nm] = d
            kept[#kept + 1] = m
            log(string.format("    f%-6d %-11s = %d", fnw, nm, d))
        end
    end

    -- The three markers, by their source-level identity rather than by appearance.
    local A, B, C
    for _, m in ipairs(kept) do
        local fnw, nm, d = m[1], m[2], m[3]
        if not A and nm == "SPEED" and d == 12 then A = fnw end
        if A and not B and nm == "psandcount" and d == 0 then B = fnw end
        if B and not C and nm == "SPEED" and d == 7 then C = fnw end
    end
    log("")
    if A and B and C then
        log(string.format("A  SPEED = 12, glass + flash   f%d", A))
        log(string.format("B  psandcount = 0, sand flows  f%d   A->B %4d frames  %.2f s"
                          .. "   <- the five plays at SPEED 12", B, B - A, (B - A) / 59.94))
        log(string.format("C  SPEED = 7, Vexit follows    f%d   B->C %4d frames  %.2f s"
                          .. "   <- s_Magic", C, C - B, (C - B) / 59.94))
    else
        log(string.format("INCOMPLETE — A=%s B=%s C=%s", tostring(A), tostring(B),
                          tostring(C)))
    end
    out:close()
    manager.machine:exit()
end)
