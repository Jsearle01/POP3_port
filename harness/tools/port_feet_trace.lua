-- port_feet_trace.lua — P3.95: the vizier vanishes except his feet, for a frame or two.
--
-- Jay, across three gates, narrowing each time:
--   P3.87  "right as the viser starts his turn, all of him but his feet dissapear for a
--           frame or so"
--   P3.94  "he still has a frame of two where he dissapears except for his feet. there are
--           eithr at the end of thr raise phase or very beginning of the his turn"
--
-- ★ "EXCEPT FOR HIS FEET" IS THE WHOLE CLUE, and it says which way to look. Cels are
-- stored BOTTOM-UP — the oracle's YCO is the BOTTOM scanline, so data row 0 lands on the
-- lowest line and row h-1 on the top [idioms §, GAMEBG]. His feet are therefore the FIRST
-- rows blitted. "Everything but the feet vanished" is not a draw that did not happen; it
-- is a draw that STARTED AND STOPPED EARLY — a row count too small for one frame.
--
-- ch_h and ch_w come from co_dims, read from the RESOLVED VARIANT's own header, which is
-- the only thing that knows how big the draw is. So a wrong h means a header read from the
-- wrong place. ★ AND THE LOCATION HE GIVES IS WHERE THE PAGE CHANGES: cel_plan moves block
-- $0E -> $0F at Vexit (the turn) and $0F -> $0D at the beat after. A wrong-page header read
-- at a beat boundary is P3.78's failure exactly, whose recorded signature was `w=1 h=192`
-- — two bytes of somebody else's pixels read as a header.
--
-- So: log every co_dims result with its character, its cel, its beat and its frame, and
-- flag any height that is not that character's usual one. No inference — the anomaly
-- either appears in the table or it does not.
local OUT   = os.getenv("P_OUT") or "build/tmp/feet.log"
local FROM  = tonumber(os.getenv("P_FROM") or "4000")
local TO    = tonumber(os.getenv("P_TO") or "4500")

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true
local out = io.open(OUT, "w")
local function log(s) out:write(s .. "\n"); out:flush() end

local F = {}
for line in io.lines("build/obj/flames.map") do
    local n, a = line:match("^Symbol: (%S+) .*= *(%x+)$")
    if n then F[n] = tonumber(a, 16) end
end
for _, k in ipairs({ "ch_w", "ch_h", "ch_idx", "ch_cel", "vm_beat", "ch_bankerr" }) do
    if not F[k] then log("FAIL no symbol " .. k); out:close(); return end
end

local beat = -1
_G._tb = mem:install_write_tap(F.vm_beat, F.vm_beat, "b", function(o, d)
    beat = beat + 1; return d
end)

-- co_dims writes ch_h then ch_w. Tap the SECOND and read the first: at that instant both
-- belong to the same resolved variant, and neither has been overwritten by the next call.
local ev = {}
_G._tw = mem:install_write_tap(F.ch_w, F.ch_w, "w", function(o, d)
    local fn = scr:frame_number()
    if fn < FROM or fn > TO then return d end
    ev[#ev + 1] = { f = fn, b = beat, w = d,
                    h = mem:read_u8(F.ch_h),
                    c = mem:read_u8(F.ch_idx),
                    cel = mem:read_u8(F.ch_cel) * 256 + mem:read_u8(F.ch_cel + 1) }
    return d
end)

local state, t0 = "boot", nil
_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if state == "boot" then
        if fn >= 300 then nk:post('LOADM"ROOM"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if fn > t0 + 900 then nk:post('EXEC\n'); state = "run" end
        return
    end
    if fn <= TO then return end

    log(string.format("# co_dims results, frames %d..%d, %d samples", FROM, TO, #ev))
    log(string.format("# ch_bankerr = %d (0 = the per-beat page guard never refused a frame)",
                      mem:read_u8(F.ch_bankerr)))

    -- what is NORMAL for each character, so an outlier is defined by the data
    local hist = { [0] = {}, [1] = {} }
    for _, e in ipairs(ev) do
        local t = hist[e.c]
        if t then t[e.h] = (t[e.h] or 0) + 1 end
    end
    for c = 0, 1 do
        local ks = {}
        for k in pairs(hist[c]) do ks[#ks + 1] = k end
        table.sort(ks)
        local parts = {}
        for _, k in ipairs(ks) do parts[#parts + 1] = string.format("h%d x%d", k, hist[c][k]) end
        log(string.format("# %s heights: %s", c == 0 and "vizier " or "princess",
                          table.concat(parts, "  ")))
    end

    -- ★ THE OUTLIERS. "A frame or two" out of hundreds, so rarity is the signature: any
    -- height seen fewer than 1% as often as that character's most common one.
    log("")
    log("# RARE HEIGHTS — a height that appears a handful of times among hundreds")
    for c = 0, 1 do
        local top = 0
        for _, n in pairs(hist[c]) do if n > top then top = n end end
        for _, e in ipairs(ev) do
            if e.c == c and hist[c][e.h] * 100 < top then
                log(string.format("    f%-6d beat %-3d %s cel $%04X  w=%-3d h=%-3d  (h seen %d times)",
                                  e.f, e.b, c == 0 and "vizier " or "princess",
                                  e.cel, e.w, e.h, hist[c][e.h]))
            end
        end
    end

    log("")
    log("# TIMELINE around the raise/turn — every sample, so a short h is visible in context")
    local last = nil
    for _, e in ipairs(ev) do
        if e.b ~= last then
            log(string.format("  --- beat %d (frame %d) ---", e.b, e.f))
            last = e.b
        end
        log(string.format("    f%-6d %s cel $%04X  w=%-3d h=%-3d",
                          e.f, e.c == 0 and "vizier " or "princess", e.cel, e.w, e.h))
    end
    out:close()
    manager.machine:exit()
end)
