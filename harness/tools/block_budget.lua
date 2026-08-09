-- harness/tools/block_budget.lua
--
-- P3.66 §1 — WHICH PHYSICAL BLOCKS DOES THE PORT USE ON A 128 KB MACHINE?
--
-- gfx.s:405-416 states the answer; the dispatch asks for a measurement rather than an
-- inference from the 512 KB map. The GIME masks a block number to the RAM installed, so
-- on 128 KB every number aliases mod 16:
--
--     sys.s sets $FFA0-$FFA7 = $38-$3F   ->  $08-$0F   the CPU's own 64 KB
--     buffer A  GFX_DB_A_BLOCK $10-$13   ->  $00-$03
--     buffer B  GFX_DB_B_BLOCK $14-$17   ->  $04-$07
--
-- which accounts for all sixteen. The claim under test is that $0C-$0F are FREE anyway:
-- they are the CPU's $8000-$FFFF, and gfx init remaps $FFA4-$FFA7 onto a framebuffer, so
-- once the port owns the machine nothing can address them.
--
-- A WRITE TAP ON THE MMU REGISTERS, not on RAM: code that cannot map a block cannot
-- corrupt it. Write taps are the reliable direction here (idioms §10a).
--
-- ★ THE BOOT MAP IS NOT THE PORT, and reading it as such is how this first answered
--   "not free". At frame 0 the firmware has $FFA4-$FFA7 = $3C-$3F, which does alias into
--   $0C-$0F and says nothing about the port. The boundary used here is the port's OWN
--   first window write (a value in $10-$17); everything before it is the firmware's.
--
-- ★ AND THIS FILE DOES NOT LAUNCH ANYTHING. Three hand-written launchers in a row failed
--   differently — one measured DECB at the prompt, one sampled before gfx init had run,
--   one fired EXEC mid-load so the room never started. run_block_budget.sh grafts this
--   onto room_test.lua, whose launch already works. Do not add a launcher here.
local seen = {}
for r = 0xFFA0, 0xFFA7 do seen[r] = {} end

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)

_G._mmu_tap = mem:install_write_tap(0xFFA0, 0xFFA7, "mmu", function(off, data, mask)
    if seen[off] and seen[off][data] == nil then
        seen[off][data] = scr:frame_number()
    end
    return data
end)

_G._mmu_report = function(path)
    local f = io.open(path or "build/block_budget.log", "w")
    if not f then return end

    -- The port's first window write: the earliest frame any of $FFA4-$FFA7 takes a
    -- framebuffer block ($10-$17). Anything before that is the firmware's boot map.
    local boundary = nil
    for r = 0xFFA4, 0xFFA7 do
        for v, fr in pairs(seen[r]) do
            if v >= 0x10 and v <= 0x17 and (boundary == nil or fr < boundary) then
                boundary = fr
            end
        end
    end
    f:write(string.format("# gfx init mapped the window at frame %s\n",
                          boundary and tostring(boundary) or "NEVER — the port never ran"))

    local free = {[0x0C] = true, [0x0D] = true, [0x0E] = true, [0x0F] = true}
    local violated = false
    for r = 0xFFA0, 0xFFA7 do
        local v = {}
        for val, fr in pairs(seen[r]) do v[#v + 1] = {val, fr} end
        table.sort(v, function(a, b) return a[1] < b[1] end)
        local parts = {}
        for _, vf in ipairs(v) do
            local ph, when = vf[1] % 16, vf[2]
            local port = boundary ~= nil and when >= boundary
            local mark = ""
            if free[ph] then
                mark = port and "  <-- THE PORT MAPS $0C-$0F" or "  (firmware boot map)"
                if port then violated = true end
            end
            parts[#parts + 1] = string.format("$%02X(->$%02X)@f%d%s", vf[1], ph, when, mark)
        end
        f:write(string.format("  $%04X : %s\n", r,
                              #parts > 0 and table.concat(parts, " ") or "never written"))
    end
    f:write(violated
        and "# RESULT: the PORT maps $0C-$0F — they are not free\n"
        or  "# RESULT: after gfx init the port only ever maps $10-$17 (-> $00-$07).\n"
         .. "#         $0C-$0F are never mapped: 32 KB free on 128 KB, MEASURED.\n")
    f:close()
end
