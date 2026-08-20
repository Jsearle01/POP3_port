-- preload_fb_diff.lua — P4.25: did the cel preload's MMU borrow damage the framebuffer?
--
-- ★★★ THE QUESTION, EXACTLY. `cel_preload` points $FFA6/$FFA7 at the cutscene's cel bank,
-- reads eight tracks through CPU $C000-$FDFF, and puts the registers back. If the restore
-- is wrong, the CPU's view of $C000-$FDFF afterwards is CEL DATA rather than the back
-- buffer -- and every subsequent draw goes into the cel bank instead of the screen. That
-- failure does not announce itself as a crash; it looks like a rendering bug much later.
-- So this diffs the whole draw window ACROSS the borrow, byte for byte.
--
-- ★★ THE TWO SAMPLE POINTS ARE TAPS ON STATE, NOT FRAME POLLS, AND THAT IS THE WHOLE
-- DESIGN. A once-per-frame poll cannot sample "after the preload returned and before beat 1
-- reads its picture" -- those are microseconds apart, inside one frame. Two write taps land
-- exactly:
--
--   BEFORE  the write of 2 to probe_loads   -- the bundle and the player are in; the
--                                              preload has not issued its first read
--   AFTER   the write of 2 to probe_status  -- beat 1 is starting; the preload has
--                                              returned and restored, and load_screen
--                                              has not yet written a byte
--
-- Between those two points the ONLY thing that has run is cel_preload. set_mode cleared
-- both buffers at boot and nothing has drawn, so the correct answer is zero differing
-- bytes -- and a wrong restore cannot produce zero, because the cel pages are 30 KB of
-- non-zero image data sitting under exactly the half of the window that was borrowed.
--
-- ★ P4.24's lesson is why the taps carry their own evidence: an instrument that samples a
-- multi-field structure on the wrong field reports a plausible wrong answer. Here each tap
-- fires on the single byte whose value IS the trigger, and the log prints the frame, the
-- byte counts and the address of the first difference, so a zero can be told apart from a
-- tap that never fired.
local ENGINE = tonumber(os.getenv("P_ENGINE") or "2000", 16)
local LOADS  = ENGINE + 8          -- probe_loads
local STATUS = ENGINE + 3          -- probe_status
local WIN_LO = 0x8000              -- the draw window the HAL maps through $FFA4-$FFA7
local WIN_HI = 0xFDFF              -- $FE00 up is the MC3 constant page and I/O
local BORROW = 0xC000              -- ...and $FFA6/$FFA7 cover from here up
local OUT    = os.getenv("P_OUT") or "build/tmp/preload_fb_diff.log"

local mem = manager.machine.devices[":maincpu"].spaces["program"]
local nk  = manager.machine.natkeyboard
nk.in_use = true
local scr = manager.machine.screens:at(1)

local before, after = nil, nil
local f_before, f_after = nil, nil

local function snap()
    local t = {}
    for a = WIN_LO, WIN_HI do t[a] = mem:read_u8(a) end
    return t
end

_G._tl = mem:install_write_tap(LOADS, LOADS, "loads", function(o, d, m)
    if d == 2 and before == nil then before, f_before = snap(), scr:frame_number() end
    return d
end)

_G._ts = mem:install_write_tap(STATUS, STATUS, "status", function(o, d, m)
    if d == 2 and before ~= nil and after == nil then after, f_after = snap(), scr:frame_number() end
    return d
end)

local state, t0, done = "boot", nil, false
_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if done then return end
    if state == "boot" then
        if fn >= 300 then nk:post('LOADM"LOADER"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if fn > t0 + 900 then nk:post('EXEC\n'); state = "run" end
        return
    end
    if after == nil and fn <= 4000 then return end
    done = true

    local f = io.open(OUT, "w")
    f:write("# the draw window across cel_preload's MMU borrow, byte for byte.\n")
    f:write(string.format("# window $%04X..$%04X (%d B); the borrowed half is $%04X up.\n#\n",
            WIN_LO, WIN_HI, WIN_HI - WIN_LO + 1, BORROW))
    if before == nil or after == nil then
        f:write(string.format("# NO SAMPLE: before=%s after=%s -- the taps did not both fire.\n",
                tostring(before ~= nil), tostring(after ~= nil)))
        f:write("# VERDICT: INCONCLUSIVE\n")
        f:close()
        manager.machine:exit()
        return
    end
    local ndiff, nlow, nhigh, first = 0, 0, 0, nil
    local nz_before, nz_after = 0, 0
    for a = WIN_LO, WIN_HI do
        if before[a] ~= 0 then nz_before = nz_before + 1 end
        if after[a]  ~= 0 then nz_after  = nz_after  + 1 end
        if before[a] ~= after[a] then
            ndiff = ndiff + 1
            if a < BORROW then nlow = nlow + 1 else nhigh = nhigh + 1 end
            if not first then first = a end
        end
    end
    f:write(string.format("# BEFORE  frame %d  (write of 2 to probe_loads)\n", f_before))
    f:write(string.format("# AFTER   frame %d  (write of 2 to probe_status)\n", f_after))
    f:write(string.format("# elapsed %d frames = %.2f s of disk\n#\n",
            f_after - f_before, (f_after - f_before) / 59.92))
    f:write(string.format("  non-zero bytes BEFORE      %d\n", nz_before))
    f:write(string.format("  non-zero bytes AFTER       %d\n", nz_after))
    f:write(string.format("  bytes differing            %d\n", ndiff))
    f:write(string.format("    below $%04X (untouched)  %d\n", BORROW, nlow))
    f:write(string.format("    at/above $%04X (borrowed) %d\n", BORROW, nhigh))
    if first then f:write(string.format("  first difference at        $%04X\n", first)) end
    f:write("#\n")
    if ndiff == 0 then
        f:write("# VERDICT: PASS -- the framebuffer is byte-identical across the borrow.\n")
    else
        f:write("# VERDICT: FAIL -- the MMU restore did not put the window back.\n")
    end
    f:close()
    manager.machine:exit()
end)
