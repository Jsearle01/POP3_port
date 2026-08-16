-- port_exit_walk.lua — P3.97: "his walk out still looks like he's skipping not walking.
-- almost like a frame is missing."  (Jay, P3.96 gate)
--
-- The sequence DATA is not it. The port's viz_exit and viz_walk match SEQTABLE.S cel for
-- cel, including the two things that are easy to get wrong: `goto viz_walk2` out of the
-- exit (entering the loop at 49, skipping the one-off 48) and `goto viz_walk1` at the end
-- of the loop (so 48 IS in every subsequent cycle). Both verified by reading.
--
-- ★ SO THE SUSPECT IS THE VARIANT, NOT THE SCRIPT. The walk-out is MIRRORED — viz_exit
-- ends `aboutface` before the goto — so it draws v48_m..v53_m, a different bake at a
-- different column parity. char_one's own contract [P3.71]:
--
--     cmpu #0
--     beq  cp_none          ; no cel: stall the slot, draw nothing
--
-- and its comment calls the result "visible as a stall, not as a crash". ★★ A STALL IS
-- EXACTLY WHAT "SKIPPING, LIKE A FRAME IS MISSING" LOOKS LIKE: the character holds the
-- previous cel for a step instead of advancing, so the gait loses a frame and the x keeps
-- moving under it.
--
-- ★ AND NO SUITE CAN SEE IT. verify_room_chars composites the cel the MACHINE says it
-- drew (ch_drawn, read at draw time), so a stalled frame is compared against the stalled
-- cel and agrees byte for byte. That is the same shape as every other defect in this arc
-- that only an eye caught.
--
-- So: log the vizier's cel number at every step through the exit, and check the sequence
-- against what viz_exit/viz_walk say it must be. A repeat is a stall; a gap is a skip.
local OUT  = os.getenv("P_OUT") or "build/tmp/exit_walk.log"
local FROM = tonumber(os.getenv("P_FROM") or "4300")
local TO   = tonumber(os.getenv("P_TO") or "5200")

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
local CH_CEL, CH_X, CH_FACE = 4, 0, 5
for _, k in ipairs({ "cad_idx", "viz_slot", "vm_beat" }) do
    if not F[k] then log("FAIL no symbol " .. k); out:close(); return end
end

local beat, rows = -1, {}
_G._tb = mem:install_write_tap(F.vm_beat, F.vm_beat, "b", function(o, d)
    beat = beat + 1; return d
end)
-- cad_idx ticks once per animation step, BEFORE vm_step advances the sequences, so the
-- cel read here is the one the step just finished showing. Sampling after the tick would
-- read the next step's cel and misalign every row by one.
_G._ts = mem:install_write_tap(F.cad_idx, F.cad_idx, "s", function(o, d)
    local fn = scr:frame_number()
    if fn >= FROM and fn <= TO then
        local x = mem:read_u8(F.viz_slot) * 256 + mem:read_u8(F.viz_slot + 1)
        if x >= 0x8000 then x = x - 0x10000 end
        -- ★ CH_CEL IS WHAT THE SCRIPT WANTS; ch_drawn IS WHAT REACHED THE SCREEN.
        -- char_one stalls the slot when co_variant returns 0 ("no cel: draw nothing"),
        -- and the sequence advances anyway — so the two diverge exactly where a frame
        -- goes missing. ch_drawn is written at DRAW time and indexed by (character, slot),
        -- which is why walk_test.lua reads it rather than the record.
        rows[#rows + 1] = { f = fn, b = beat,
                            cel = mem:read_u8(F.viz_slot + CH_CEL),
                            d0 = F.ch_drawn and mem:read_u8(F.ch_drawn) or -1,
                            d1 = F.ch_drawn and mem:read_u8(F.ch_drawn + 1) or -1,
                            x = x,
                            face = mem:read_u8(F.viz_slot + CH_FACE) }
    end
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

    log(string.format("# the vizier's cel at every step, frames %d..%d, %d steps",
                      FROM, TO, #rows))
    log("")
    log("    frame   beat  cel drw0 drw1 x      face   note")
    local prev = nil
    local stalls, seq = 0, {}
    for _, r in ipairs(rows) do
        local note = ""
        if prev and r.cel == prev then
            note = "<-- SAME CEL AS THE PREVIOUS STEP (a stall)"
            stalls = stalls + 1
        end
        if r.d0 >= 0 and r.d0 ~= r.cel and r.d1 ~= r.cel then
            note = note .. "  ** DRAWN " .. r.d0 .. "/" .. r.d1 .. " NOT " .. r.cel
        end
        log(string.format("    %-7d %-5d %-5d %-3d %-3d %-6d $%02X   %s",
                          r.f, r.b, r.cel, r.d0, r.d1, r.x, r.face, note))
        seq[#seq + 1] = r.cel
        prev = r.cel
    end

    log("")
    log(string.format("# %d steps where the cel did NOT change", stalls))
    log("# viz_walk's cycle is 48,49,50,51,52,53 repeating [goto viz_walk1];")
    log("# viz_exit enters it at 49 [goto viz_walk2], so the FIRST cycle out is")
    log("# 49,50,51,52,53 and every one after that is the full six.")
    out:close()
    manager.machine:exit()
end)
