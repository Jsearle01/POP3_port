-- harness/tools/bank_proof.lua
--
-- P3.66 §3 de-risk — DO THE BANK BLOCKS SURVIVE A WHOLE SCENE, AND IS BORROWING THE
-- WINDOW TO REACH THEM HARMLESS?
--
-- §1 proved the port never MAPS $0C-$0F after gfx init: an argument about reachability.
-- This is the claim banking actually rests on — write a pattern into a bank block, run the
-- scene, and check it is still there.
--
-- ★ IT WRITES THROUGH $FFA6 WHILE THE ROOM IS RUNNING, ON PURPOSE. The first version wrote
--   at frame 20, when blocks $0C-$0F are still the CPU's $8000-$FFFF under the firmware's
--   boot map — and clobbered DECB's workspace, so the port never loaded. The probe then
--   reported "every byte intact after the whole scene" about a machine that had not run
--   the scene. That is the fifth instrument fault of this dispatch in the same family, so
--   _bank_verify now REFUSES to pass unless it is told the room came up.
--
-- ★ AND THE BORROW IS THE DESIGN UNDER TEST. In 4-colour the framebuffer is 15,360 B and
--   occupies $8000..$BBFF, so window blocks 2 and 3 ($FFA6/$FFA7, CPU $C000-$FFFF) map
--   memory the framebuffer never reaches. Pointing $FFA6 at a bank block should therefore
--   be invisible to the scene — and the suite running green around this write is the
--   evidence for that. The port's own next swap calls gfx_map_blocks and restores all four
--   registers, so nothing has to be put back by hand.
local BLOCK = 0x3E                 -- physical $0E on a 128 KB machine
local WIN = 0xC000                 -- CPU address of window block 2
local N = 0x800                    -- 2 KB of pattern

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]

local function pat(i) return (i * 7 + 0x5A) % 256 end

_G._bank_written = false

-- Called once, with the room already up: borrow $FFA6, stamp the block, leave it. The
-- next HAL_gfx_swap remaps all four window registers and takes it back.
_G._bank_write = function()
    if _G._bank_written then return end
    mem:write_u8(0xFFA6, BLOCK)
    for i = 0, N - 1 do mem:write_u8(WIN + i, pat(i)) end
    _G._bank_written = true
end

-- ran_ok MUST be the caller's evidence that the scene actually played. Without it this
-- reports on whatever the machine happened to be doing, which is exactly how the previous
-- version passed while the port sat unloaded.
_G._bank_verify = function(path, ran_ok)
    local f = io.open(path or "build/bank_proof.log", "w")
    if not f then return end
    if not ran_ok then
        f:write("# the room never came up — INCONCLUSIVE, and not a pass.\n")
        f:close()
        return
    end
    if not _G._bank_written then
        f:write("# the pattern was never written — INCONCLUSIVE, and not a pass.\n")
        f:close()
        return
    end
    mem:write_u8(0xFFA6, BLOCK)
    local bad, first = 0, nil
    for i = 0, N - 1 do
        if mem:read_u8(WIN + i) ~= pat(i) then
            bad = bad + 1
            if first == nil then first = i end
        end
    end
    f:write(string.format("# %d B stamped into physical block $%02X through $FFA6, room running\n",
                          N, BLOCK % 16))
    if bad == 0 then
        f:write("# RESULT: every byte intact after the scene ran on — the bank is USABLE,\n")
        f:write("#         not merely unmapped, and borrowing $FFA6 did not disturb the room.\n")
    else
        f:write(string.format("# RESULT: %d of %d bytes CHANGED (first at +$%04X) — something writes it\n",
                              bad, N, first or 0))
    end
    f:close()
end
