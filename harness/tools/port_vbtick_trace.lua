-- port_vbtick_trace.lua — P3.91: does the flash fire once per PLAY, or once per BEAT?
--
-- Jay, on the P3.87 live gate: "the hourglass still appears before the flash to my eye."
-- Reading vm_beat_tick, the flash and the sand both sit BELOW this:
--
--     vb_tick   lda vm_bcnt
--               beq vb_done          ; terminal beat
--               deca
--               sta vm_bcnt
--               bne vb_done          ; <-- taken on every play but the LAST
--               inc vm_pend
--               ...flash block...    ; lda #SC_LIT_FRAMES / sta sc_lit
--               ...sand block...     ; sc_flow = (sc_flow + 1) mod 3
--
-- so both would fire only on the play that SPENDS the beat. Beat 13 has five plays, which
-- would put the glass on play 1 and its flash on play 5 — about half a second apart at the
-- measured step rate, and exactly what Jay reported.
--
-- ★ BOTH BLOCKS CARRY COMMENTS SAYING "once per PLAY". Under §2 the source is the trusted
-- default and the TRACE WINS ON FACT, so this settles it on the machine rather than by
-- reading — which is the whole reason it has been follow-up #1 for three dispatches.
--
-- ★★ AND IT DECIDES §3, NOT JUST THE DEFECT. scenery_frame's body is now scenery (drawn on
-- state change, P3.90). What still runs EVERY iteration is the sand: erase the previous
-- sand, save the background under it, draw it. If sc_flow really advances once per beat
-- then that per-frame cycle is redrawing an unchanged 9x2 image ~20 times a second, and
-- the "animation" half of the hourglass is barely animation at all.
--
-- Taps only, no inference: cad_idx ticks once per step [vm_nextframe], vm_beat once per
-- beat [vb_apply], sc_lit when the flash is armed, sc_flow when the sand advances.
local OUT = os.getenv("P_OUT") or "build/tmp/vbtick.log"
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
for _, k in ipairs({ "cad_idx", "vm_beat", "sc_lit", "sc_flow", "vm_scenery" }) do
    if not F[k] then log("FAIL no symbol " .. k); out:close(); return end
end

local step, beat = 0, -1
local ev = {}
local function rec(kind, extra)
    ev[#ev + 1] = { k = kind, s = step, b = beat, f = scr:frame_number(), x = extra }
end

_G._t1 = mem:install_write_tap(F.cad_idx, F.cad_idx, "s", function(o, d)
    step = step + 1; rec("step"); return d
end)
_G._t2 = mem:install_write_tap(F.vm_beat, F.vm_beat, "b", function(o, d)
    beat = beat + 1; rec("beat"); return d
end)
_G._t3 = mem:install_write_tap(F.sc_lit, F.sc_lit, "l", function(o, d)
    -- sc_lit is ARMED with SC_LIT_FRAMES and then counted DOWN once per drawn frame.
    -- Only the arming is the flash firing; the decrements are the strobe burning out.
    if d ~= 0 then rec("lit", d) end
    return d
end)
_G._t4 = mem:install_write_tap(F.sc_flow, F.sc_flow, "w", function(o, d)
    rec("flow", d); return d
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
    if fn < 5000 then return end

    -- ── the scenery beats only; everything before the glass is silent here ────────────
    log("# EVENTS from the first scenery beat (beat index = vb_apply calls - 1)")
    log("#   step = an animation step (cad_idx);  beat = vb_apply;  lit = the flash armed;")
    log("#   flow = the sand frame advanced")
    log("")
    local first = nil
    for i, e in ipairs(ev) do
        if e.k == "lit" or e.k == "flow" then first = first or i end
    end
    if not first then log("    (the flash never armed and the sand never advanced)") end

    local lo = math.max(1, (first or 1) - 12)
    local shown, lastbeat = 0, nil
    for i = lo, #ev do
        local e = ev[i]
        if e.k == "beat" then
            log(string.format("  --- beat %d begins at step %d (frame %d) ---", e.b, e.s, e.f))
            lastbeat = e.s
        elseif e.k ~= "step" then
            log(string.format("      %-5s %-4s at step %d (%d into the beat), frame %d",
                              e.k, e.x and ("=" .. e.x) or "", e.s,
                              lastbeat and (e.s - lastbeat) or -1, e.f))
        end
        shown = shown + 1
        if shown > 400 then break end
    end

    -- ── the counts that answer the question ──────────────────────────────────────────
    local lits, flows, steps_in = {}, {}, {}
    local curbeat = nil
    for _, e in ipairs(ev) do
        if e.k == "beat" then curbeat = e.b; steps_in[curbeat] = 0 end
        if e.k == "step" and curbeat then steps_in[curbeat] = steps_in[curbeat] + 1 end
        if e.k == "lit" and curbeat then lits[curbeat] = (lits[curbeat] or 0) + 1 end
        if e.k == "flow" and curbeat then flows[curbeat] = (flows[curbeat] or 0) + 1 end
    end
    log("")
    log("# PER BEAT: plays (steps) against how often the flash armed and the sand advanced")
    log("    beat   steps   flash armed   sand advanced")
    local ks = {}
    for k in pairs(steps_in) do ks[#ks + 1] = k end
    table.sort(ks)
    for _, b in ipairs(ks) do
        if (lits[b] or 0) > 0 or (flows[b] or 0) > 0 or (steps_in[b] or 0) > 0 then
            log(string.format("    %-6d %-7d %-13d %d",
                              b, steps_in[b] or 0, lits[b] or 0, flows[b] or 0))
        end
    end
    log("")
    log("# ONE PER STEP => the comments are right and the branch is not in the way.")
    log("# ONE PER BEAT => the flash is a single strobe, the sand is nearly static, and")
    log("#                the per-frame sand cycle is redrawing an unchanged image.")
    out:close()
    manager.machine:exit()
end)
