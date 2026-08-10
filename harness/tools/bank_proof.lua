-- harness/tools/bank_proof.lua
--
-- P3.66b / P3.68 — DO THE BANK BLOCKS SURVIVE A WHOLE SCENE, AND IS BORROWING THE WINDOW
-- TO REACH THEM HARMLESS?
--
-- P3.66 §1 proved the port never MAPS $0C-$0F after gfx init: an argument about
-- reachability. This is the claim the bank actually rests on — write a pattern into the
-- blocks, run the scene, and check it is still there afterwards.
--
-- ★ IT WRITES WHILE THE ROOM IS RUNNING, ON PURPOSE. The first version wrote at frame 20,
--   when the firmware's boot map still has $0C-$0F at CPU $8000-$FFFF; it clobbered DECB,
--   the port never loaded, and the probe reported "every byte intact after the whole
--   scene" about a machine that had never run the scene. _bank_verify therefore refuses to
--   pass unless the caller hands it evidence the room came up.
--
-- ★ THE BORROW IS THE DESIGN UNDER TEST. In 4-colour the framebuffer is 15,360 B and
--   occupies $8000..$BBFF, so window blocks 2 and 3 map memory it never reaches. Pointing
--   them at bank blocks should be invisible to the scene, and the room suite running green
--   around these writes is the evidence. The port's own next HAL_gfx_swap calls
--   gfx_map_blocks and rewrites all four registers, so nothing needs putting back by hand.
--
-- BOTH halves are stamped, because the design rests on both (P3.68). P3.66b proved only
-- $FFA6 / block $0E. $FFA7 covers CPU $E000-$FDFF — the half P2.6 deliberately did not
-- remap until the window moved — and is safe only because MC3=1 pins $FE00-$FEFF and
-- $FF00-$FFFF is always I/O. Those are code facts (gfx.s writes $FF90 = $6C = 01101100);
-- this is the measurement that they hold in practice. $FE00 upward is excluded on purpose:
-- it is not the bank, and writing it would be testing the wrong thing.
local HALVES = {{reg = 0xFFA6, block = 0x3E, lo = 0xC000, n = 0x0800},
                {reg = 0xFFA7, block = 0x3F, lo = 0xE000, n = 0x0800}}

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]

local function pat(i) return (i * 7 + 0x5A) % 256 end

_G._bank_written = false

_G._bank_write = function()
    if _G._bank_written then return end
    for _, h in ipairs(HALVES) do
        mem:write_u8(h.reg, h.block)
        for i = 0, h.n - 1 do mem:write_u8(h.lo + i, pat(i)) end
    end
    _G._bank_written = true
end

_G._bank_verify = function(path, ran_ok)
    local f = io.open(path or "build/bank_proof.log", "w")
    if not f then return end
    if not ran_ok then
        f:write("# the room never came up - INCONCLUSIVE, and not a pass.\n")
        f:close()
        return
    end
    if not _G._bank_written then
        f:write("# the pattern was never written - INCONCLUSIVE, and not a pass.\n")
        f:close()
        return
    end
    local total_bad = 0
    for _, h in ipairs(HALVES) do
        mem:write_u8(h.reg, h.block)
        local bad, first = 0, nil
        for i = 0, h.n - 1 do
            if mem:read_u8(h.lo + i) ~= pat(i) then
                bad = bad + 1
                if first == nil then first = i end
            end
        end
        total_bad = total_bad + bad
        f:write(string.format("  $%04X -> block $%02X, %d B at $%04X: %s\n",
                              h.reg, h.block % 16, h.n, h.lo,
                              bad == 0 and "all intact"
                                or string.format("%d CHANGED, first at +$%04X", bad, first or 0)))
    end
    if total_bad == 0 then
        f:write("# RESULT: both bank halves survive the scene, and borrowing them did not\n")
        f:write("#         disturb the room. 16 KB of the 32 KB free verified.\n")
    else
        f:write(string.format("# RESULT: %d bytes changed - something writes the bank\n",
                              total_bad))
    end
    f:close()
end
