-- blit_fb_at_n.lua — P4.29: dump the drawn framebuffer after exactly N blits.
--
-- ★★★ WHY THE CAPTURE IS KEYED ON WORK AND NOT ON TIME. This exists to prove the P4.29
-- unmask window does not corrupt the picture, which means comparing the SAME frame between
-- two builds -- and the two builds do not run at the same speed. The window costs the scene
-- ~6% of its pace, so "N frames after the scene starts" lands on a DIFFERENT animation step
-- in each build and would report a difference that is pace, not corruption.
--
-- ★★ COUNTING BLITS FIXES THAT. Both builds draw the same cels in the same order from the
-- same schedule; only the wall clock differs. After the Nth blit the drawn buffer must hold
-- byte-for-byte the same picture, so ANY difference is the window writing where it should
-- not.
--
-- THE CORRUPTION THIS IS LOOKING FOR IS SPECIFIC. If an interrupt is ever taken while S is
-- a framebuffer pointer, the 6809 pushes PC and CC through it -- three bytes, at wherever
-- the blast left S. That is exactly the P3.78d bug this file's own header records: "two
-- wrong bytes out of thirty-nine, localised, at a first column". A handful of wrong bytes,
-- not a scrambled screen, so a byte-exact comparison is the only check that would see it.
--
-- ★ THE COUNTER IS bc_saved_s's WRITE, one per blit_cel entry. Its address is passed in --
-- adding six bytes of code to blit_core moved it from $3AD7 to $3ADB during this very
-- dispatch, and the tool that had it hard-coded reported "0 brackets", which reads exactly
-- like "the blitter never ran".
local OUT   = os.getenv("P_OUT") or "build/tmp/blit_fb.bin"
local LOG   = os.getenv("P_LOG") or "build/tmp/blit_fb.log"
local SAVED = tonumber(os.getenv("P_SAVED") or "3ADB", 16)
local NTH   = tonumber(os.getenv("P_NTH") or "400")
local BASE  = tonumber(os.getenv("P_BASE") or "8000", 16)   -- the draw window
local LEN   = tonumber(os.getenv("P_LEN") or "15360")       -- 320x192x4 = 15,360 B

local mem = manager.machine.devices[":maincpu"].spaces["program"]
local nk  = manager.machine.natkeyboard
nk.in_use = true
local scr = manager.machine.screens:at(1)

local n, fired = 0, false

_G._tw = mem:install_write_tap(SAVED, SAVED, "blit", function(o, d, m)
    if fired then return d end
    n = n + 1
    if n < NTH then return d end
    fired = true
    -- dump inside the tap: the blit that just STARTED has not drawn yet, so this is the
    -- state after exactly NTH-1 completed blits — deterministic either way, and identical
    -- between builds as long as the same constant is used for both.
    local f = io.open(OUT, "wb")
    local t = {}
    for a = BASE, BASE + LEN - 1 do t[#t + 1] = string.char(mem:read_u8(a)) end
    f:write(table.concat(t))
    f:close()
    local g = io.open(LOG, "w")
    g:write(string.format("# drawn buffer $%04X..$%04X (%d B) captured at blit #%d\n",
            BASE, BASE + LEN - 1, LEN, n))
    g:write(string.format("# frame %d\n", scr:frame_number()))
    g:close()
    return d
end)

local done = false
_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if done then return end
    if fn == 300 then nk:post('LOADM"LOADER"\n') end
    if fn == 1200 then nk:post('EXEC\n') end
    if fn < 9000 and not fired then return end
    if fn < 9000 then return end
    done = true
    if not fired then
        local g = io.open(LOG, "w")
        g:write(string.format("# NEVER REACHED blit #%d (saw %d) — INCONCLUSIVE\n", NTH, n))
        g:close()
    end
    manager.machine:exit()
end)
