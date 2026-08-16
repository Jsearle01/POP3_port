-- port_exit_column.lua — P3.100: THE ENGINE'S OWN DRAWN COLUMN, full 16 bits, at the write.
--
-- ★★★ WHY THIS EXISTS. P3.97 reported the port's exit stride as "+5,+3,+5,+1,+9,-3" and
-- P3.98/P3.99 concluded from it that the stride was faithful. Both were withdrawn at P3.99:
-- those numbers came from `cel_parity_rule.draw_x`, an OFFLINE FORMULA, run over traced
-- CharX -- and draw_x is itself a transcription of the oracle's own formula, so the
-- comparison could not have failed. A FORMULA AGREEING WITH ITSELF IS NOT EVIDENCE.
--
-- ★★ AND THE INSTRUMENT HAS BEEN WRONG THREE TIMES IN TWO DISPATCHES, always the same
-- shape -- a real value read at the wrong time or of the wrong width:
--
--   1. `ch_dest` sampled at the `cad_idx` tick     -> STALE ($A230 constant, awid 0),
--      because ch_dest is written inside co_setup during the draw pass.
--   2. moved to a write tap                        -> right instant, but installed on
--      `ch_dest` ALONE, so it caught only the HIGH byte of a 16-bit value. A column error
--      is invisible in the high byte: 80 B per row means a whole row is one high-byte
--      step, and every column inside a row shares it.
--   3. the wrong record offset                     -> port_exit_walk.lua read facing at
--      slot+5, which is CH_H. CH_FACE is +3 [char_draw.s:300].
--
-- SO THIS TOOL DOES FOUR THINGS THE LAST ONE DID NOT:
--
--   A. TWO taps, `ch_dest` and `ch_dest+1`, so the full 16-bit value is assembled from
--      both byte writes of the one `std ch_dest` [char_draw.s:1495].
--   B. Filters to the DRAW pass. `co_setup` has three callers -- co_erase, co_save and
--      co_draw -- and the ERASE pass deliberately feeds it a PAST save's face/awid
--      [char_draw.s:1011-1016], so within one step the same cel is set up twice with
--      different anchors. "The anchor for cel N" is not one number, and any measurement
--      that does not say which pass it means is measuring two things at once.
--   C. Filters to the vizier (ch_idx 0) and to HIS SIX WALK CELS, 48..53. A WIDER SET
--      CANNOT ANSWER A NARROWER QUESTION: P3.99 measured "mirrored draws in this scene"
--      and concluded about "the vizier's walk".
--   D. Splits ENTRY from EXIT by the engine's own facing, not by a frame number. co_setup
--      treats face<0 as NORMAL and face>=0 as MIRRORED [char_draw.s:1472-1473], and Vexit
--      is the only `aboutface` the vizier makes -- so face<0 on cels 48..53 IS the entry
--      walk and face>=0 IS the exit walk. The entry walk is the control: Jay reports it
--      does not skip.
--
-- ★ AND IT SEEDS ITSELF. P3.48b/P3.49: a probe must detect its own seeded failure before
-- its silence counts. P_SEED=1 waits for a real draw, takes the destination the engine
-- itself computed, then patches `addd ch_base / std ch_dest` into `ldd #that / std
-- ch_dest` -- a 3-byte-for-3-byte swap ($F3 ext -> $CC imm). From that instant the engine
-- stores a KNOWN 16-bit value, and every subsequent tap must report it exactly, both
-- bytes. A tap that cannot see a column it was handed cannot see one it was not.
--
-- P_OUT   log path            P_SEED  1 = run the seeded control instead of the measurement
-- P_TO    last frame to run   P_SEED_AFTER  real draws to observe before patching

local OUT   = os.getenv("P_OUT")  or "build/tmp/port_exit_column.log"
local TO    = tonumber(os.getenv("P_TO") or "6000")
-- P_SEED=1 (or "col") — the P3.100 COLUMN control.
-- P_SEED=time        — the P3.101 TIMING control: slow the cadence table and require the
--                      measured step interval to move with it. ★ A TIMING TAP NEEDS ITS
--                      OWN CONTROL. The column seed says nothing about whether the frame
--                      numbers attached to those columns mean anything, and this dispatch
--                      is entirely about the frame numbers.
local SEEDMODE = os.getenv("P_SEED") or "0"
local SEED  = (SEEDMODE == "1" or SEEDMODE == "col")
local TSEED = (SEEDMODE == "time")
local SEEDN = tonumber(os.getenv("P_SEED_AFTER") or "40")
local TSEED_VAL = tonumber(os.getenv("P_SEED_CAD") or "12")
local TSEED_AFTER = tonumber(os.getenv("P_SEED_TICKS") or "60")

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true
local out = io.open(OUT, "w")
local function log(s) out:write(s .. "\n"); out:flush() end

-- --- symbols, from the map, never literals --------------------------------------
local F = {}
for line in io.lines("build/obj/flames.map") do
    local n, a = line:match("^Symbol: (%S+) .*= *(%x+)$")
    if n then F[n] = tonumber(a, 16) end
end
local NEED = { "ch_dest", "ch_col", "ch_idx", "ch_cp", "ch_awid", "ch_face",
               "ch_base", "viz_slot", "CP_DRAW", "CP_ERASE", "vm_beat", "cs_px", "ch_par",
               "cad_tab", "CAD_LEN", "cad_idx", "vm_due", "vm_now" }
for _, k in ipairs(NEED) do
    if not F[k] then log("FAIL no symbol " .. k); out:close(); return end
end
-- ★ THE PASS CONSTANT IS DERIVED, NOT WRITTEN DOWN. lwlink lists `equ` symbols offset by
-- their section base, and CP_ERASE is `equ 0` -- so its map value IS that base and the
-- difference is the real constant. A literal 2 here would be a second home for a fact
-- char_draw.s already states.
local CP_DRAW = F.CP_DRAW - F.CP_ERASE
local CH_X, CH_FACE, CH_CEL = 0, 3, 4      -- [char_draw.s:298-301]
local WALK_LO, WALK_HI = 48, 53            -- viz_walk1..the end of the loop
-- CAD_LEN is an `equ` too, so the same section-base correction applies. Taken against
-- CP_ERASE (`equ 0`) rather than written as 6, for the reason above.
local CAD_LEN = F.CAD_LEN - F.CP_ERASE

-- ★ THE MACHINE'S OWN REFRESH, NOT 60. coco3 is 59.922748 Hz and apple2e is 60.0 — a
-- 0.13% difference, negligible against a 25% pace question but NOT negligible as a habit:
-- comparing two machines' FRAME COUNTS without either machine's frame RATE is the same
-- error as comparing a 7 px column against a 4 px one (P3.100 §3A). Both tools print Hz
-- and both convert to milliseconds, so the comparison is in a unit both machines share.
-- ⚠ `refresh_attoseconds` is a PROPERTY on MAME's screen device, not a method: written as
-- `scr:refresh_attoseconds()` it dies with "attempt to call a number value". Recorded in
-- mame-idioms-coco3-port.md §10 so the next tool does not rediscover it.
local HZ = 1.0e18 / scr.refresh_attoseconds

local function s16(a)
    local v = mem:read_u8(a) * 256 + mem:read_u8(a + 1)
    if v >= 0x8000 then v = v - 0x10000 end
    return v
end

-- --- the tap: BOTH bytes of the one `std ch_dest` ---------------------------------
local rows, pend_hi, orphans, cps = {}, nil, 0, {}
local seeded_at, seeded_at_frame, seed_val, seed_ok, seed_bad, seed_n = nil, 0, nil, true, nil, 0

_G._t_hi = mem:install_write_tap(F.ch_dest, F.ch_dest, "dest_hi", function(off, data, mask)
    pend_hi = data
    return data
end)

_G._t_lo = mem:install_write_tap(F.ch_dest + 1, F.ch_dest + 1, "dest_lo", function(off, data, mask)
    if pend_hi == nil then orphans = orphans + 1; return data end
    local dest = pend_hi * 256 + data
    pend_hi = nil
    local cp = mem:read_u8(F.ch_cp)
    cps[cp] = (cps[cp] or 0) + 1
    if seeded_at ~= nil then
        seed_n = seed_n + 1
        if dest ~= seed_val then
            seed_ok = false
            seed_bad = seed_bad or string.format("frame %d reported $%04X, seeded $%04X",
                                                 scr:frame_number(), dest, seed_val)
        end
        return data
    end
    if cp ~= CP_DRAW then return data end
    if mem:read_u8(F.ch_idx) ~= 0 then return data end
    local cel = mem:read_u8(F.viz_slot + CH_CEL)
    if cel < WALK_LO or cel > WALK_HI then return data end
    local face = mem:read_u8(F.ch_face)
    rows[#rows + 1] = { f = scr:frame_number(), cel = cel,
                        face = face, mirror = (face < 0x80),
                        awid = mem:read_u8(F.ch_awid),
                        col  = s16(F.ch_col),
                        dest = dest,
                        base = s16(F.ch_base),
-- ★ cs_px IS THE COMPARABLE NUMBER, NOT col. co_setup divides it by four to get a CoCo
-- byte column, and the remainder is carried by the baked variant the 4-phase shifter
-- draws — so `col` alone throws away up to 3 px of the answer. The oracle's own column is
-- in SEVEN-pixel Apple bytes with a separate OFFSET, so its `col` is a different
-- quantisation of the same line and the two cannot be compared as columns at all. Both
-- sides reduce to a left-edge PIXEL, and cs_px is the port's, before the divide.
--
-- cs_px carries co_setup's +20 centring for the 320 px screen [char_draw.s:1448]; the
-- oracle's FCharX does not, so the 280-res figure printed below is cs_px - 20.
                        px   = s16(F.cs_px),
                        par  = mem:read_u8(F.ch_par),
                        x    = s16(F.viz_slot + CH_X) }
    return data
end)

-- --- P3.101: THE VM'S OWN STEP ACCOUNTING, so f/play is measured and not inferred ----
--
-- `vm_nextframe` fires a step when `vm_now - vm_due >= 0`, then sets
-- `vm_due := vm_now + cad_tab[cad_idx]` [char_draw.s:1993-2009]. TWO THINGS FOLLOW and
-- both matter for what Jay is seeing:
--
--   1. The check runs ONCE PER LOOP ITERATION, not once per frame. An iteration costs
--      more than a frame, so the achieved interval is the first iteration boundary AT OR
--      AFTER the due frame — 6 becomes 7 or 8 depending on where that boundary falls, and
--      the ACHIEVED INTERVAL IS THEREFORE A FUNCTION OF THE FRAME'S DRAW COST.
--   2. The re-base is off `vm_now`, not off `vm_due`, so each step's overrun is kept
--      rather than paid back. Drift-free `vm_due` was offered at P3.87 and Jay refused
--      it; the pace is accepted policy, and this tap is not here to relitigate it.
--
-- So `cad_idx`'s write is the STEP, and it is tapped directly rather than inferred from
-- when a cel changed — a cel that repeats across two buffers is two draws of one step,
-- and counting draws as steps is exactly the "wrong width" fault one level along.
local steps = {}
local tseed_at, tseed_was, tseed_landed = nil, {}, true
_G._t_cad = mem:install_write_tap(F.cad_idx, F.cad_idx, "cad_idx", function(off, data, mask)
    steps[#steps + 1] = { f = scr:frame_number(), idx = data,
                          due = s16(F.vm_due), now = s16(F.vm_now),
                          cel = mem:read_u8(F.viz_slot + CH_CEL),
                          beat = s16(F.vm_beat),
                          face = mem:read_u8(F.viz_slot + CH_FACE) }
    return data
end)

-- --- the seed: `addd ch_base` -> `ldd #<a destination the engine really used>` ------
-- $F3 <ext16> and $CC <imm16> are both three bytes, so the store that follows is
-- untouched and the instruction stream stays aligned. The pattern is matched in full --
-- including the `std ch_dest` behind it -- before a byte is written, exactly as
-- erase_addr_probe.lua does, because a patch applied at a wrong address is a fault that
-- looks like a finding.
local function seed_patch(dest)
    local want = { 0xF3, (F.ch_base >> 8) & 0xFF, F.ch_base & 0xFF,
                   0xFD, (F.ch_dest >> 8) & 0xFF, F.ch_dest & 0xFF }
    for a = 0x2000, 0x7FF0 do
        local hit = true
        for i = 1, 6 do
            if mem:read_u8(a + i - 1) ~= want[i] then hit = false; break end
        end
        if hit then
            mem:write_u8(a, 0xCC)
            mem:write_u8(a + 1, (dest >> 8) & 0xFF)
            mem:write_u8(a + 2, dest & 0xFF)
            log(string.format("# SEEDED at $%04X: `addd ch_base` -> `ldd #$%04X`", a, dest))
            return a
        end
    end
    return nil
end

-- --- boot: live-disk, LOADM"ROOM" + EXEC (CLAUDE.md §4) ---------------------------
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

    -- ★ THE TIMING SEED, AND IT VERIFIES THAT IT FIRED (P3.100: the oracle's code patch
    -- matched its bytes, wrote, and was silently discarded — reads came back correct
    -- because the check confirmed the ADDRESS and never the WRITABILITY). Every byte of
    -- cad_tab is read back after the write, and if the read-back disagrees the run reports
    -- SEED INEFFECTIVE and never a verdict on the tap.
    -- ★ SEEDED AFTER A REAL "BEFORE" EXISTS. The first cut fired at t0+1400, which is
    -- before the scene has taken a single step — so the control compared 0 intervals
    -- against 270 and reported "too few steps either side", which is a control that could
    -- not have passed OR failed. Sixty ticks is ~8 seconds of scene at the measured rate.
    if TSEED and tseed_at == nil and #steps >= TSEED_AFTER then
        tseed_at = fn
        for i = 0, CAD_LEN - 1 do
            tseed_was[i] = mem:read_u8(F.cad_tab + i)
            mem:write_u8(F.cad_tab + i, TSEED_VAL)
        end
        for i = 0, CAD_LEN - 1 do
            if mem:read_u8(F.cad_tab + i) ~= TSEED_VAL then tseed_landed = false end
        end
        log(string.format("# SEEDED: cad_tab[0..%d] %d -> %d at frame %d; read-back %s",
                          CAD_LEN - 1, tseed_was[0] or -1, TSEED_VAL, fn,
                          tseed_landed and "CONFIRMS the write" or "DISAGREES — seed did not land"))
        return
    end

    if SEED and seeded_at == nil and #rows >= SEEDN then
        seed_val = rows[#rows].dest
        seeded_at_frame = fn
        seeded_at = seed_patch(seed_val)
        if seeded_at == nil then
            log("# SEED ABORTED: no `addd ch_base / std ch_dest` pattern in $2000..$7FF0")
            out:close(); manager.machine:exit(); return
        end
        return
    end
    -- The control does not need the whole scene: it needs enough draws after the patch to
    -- be able to disagree. 600 frames is ~85 steps at the measured 7-frame rate.
    if SEED and seeded_at ~= nil then
        if fn <= seeded_at_frame + 600 then return end
    elseif fn <= TO then return end

    -- ------------------------------------------------------------------
    if SEED then
        log("# SEEDED CONTROL — does the tap report a column it was handed?")
        log(string.format("# seeded value $%04X; %d taps after the patch", seed_val or 0, seed_n))
        if seed_n == 0 then
            log("# CONTROL FAILED: no taps at all after the seed — nothing was tested.")
        elseif seed_ok then
            log(string.format("# CONTROL PASSED: all %d post-seed taps reported $%04X, both bytes.",
                              seed_n, seed_val))
            log("#   The tap sees a KNOWN 16-bit destination. Its silence counts.")
        else
            log("# CONTROL FAILED: " .. tostring(seed_bad))
            log("#   Reject this tap (P3.48b).")
        end
        log(string.format("# orphan low-byte writes (no preceding high byte): %d", orphans))
        out:close(); manager.machine:exit(); return
    end

    log("# THE ENGINE'S DRAWN COLUMN — full 16-bit ch_dest, tapped at the `std`, DRAW pass")
    log("# only, vizier (ch_idx 0), cels 48..53 only. col is ch_col, the signed byte column")
    log("# co_setup placed the cel at; dest is ch_base + top*80 + col.")
    log(string.format("# %d draws captured through frame %d. orphan low-byte writes: %d",
                      #rows, TO, orphans))
    local cpl = {}
    for k, v in pairs(cps) do cpl[#cpl + 1] = string.format("cp %d x%d", k, v) end
    table.sort(cpl)
    log("# all ch_dest writes by pass: " .. table.concat(cpl, ", ") ..
        string.format("   (CP_DRAW = %d, derived from the map)", CP_DRAW))
    log("")

    for _, want in ipairs({ false, true }) do
        log(want and "## EXIT  — mirrored (ch_face >= 0), viz_exit -> goto viz_walk2"
                  or  "## ENTRY — normal (ch_face < 0), the control: Jay reports it does not skip")
        log("      frame   cel  awid  face  CharX   col   cs_px  LEFT-EDGE px  d(px)  dest")
        local prev = nil
        local n = 0
        for _, r in ipairs(rows) do
            if r.mirror == want then
                n = n + 1
                local px280 = r.px - 20            -- drop co_setup's 320-screen centring
                local d = prev and string.format("%+d", px280 - prev) or "     "
                log(string.format("      %-7d %-4d %-5d $%02X   %-7d %-5d %-6d %-13d %-6s $%04X",
                                  r.f, r.cel, r.awid, r.face, r.x, r.col, r.px, px280, d, r.dest))
                prev = px280
            end
        end
        if n == 0 then log("      (none)") end
        log("")
    end

    -- ================= P3.101 — WHEN, not where =====================================
    --
    -- The column is the oracle's exactly (P3.100) and all six cels are drawn in order, so
    -- what is left is TIME. A "step" here is the first draw of a new cel: the same cel
    -- appears twice per step, once into each double-buffer page, and counting draws as
    -- steps would halve every interval.
    log(string.rep("=", 78))
    log(string.format("# P3.101 — TIMING. Screen refresh %.6f Hz (from the machine, not a", HZ))
    log(string.format("# constant): one frame = %.3f ms. cad_tab asks for %d frames per step;",
                      1000.0 / HZ, mem:read_u8(F.cad_tab)))
    log("# the achieved interval is the first LOOP ITERATION at or after that, so it is a")
    log("# function of the frame's draw cost [char_draw.s:1993-2009].")
    if tseed_at then
        log(string.format("# ★ SEEDED RUN: cad_tab forced to %d at frame %d (was %d).",
                          TSEED_VAL, tseed_at, tseed_was[0] or -1))
    end

    for _, want in ipairs({ false, true }) do
        log("")
        log(want and "## EXIT timing — mirrored" or "## ENTRY timing — normal (the in-scene control)")
        -- first draw of each new cel = the step boundary
        local stepf, stepc, prevcel = {}, {}, nil
        for _, r in ipairs(rows) do
            if r.mirror == want then
                if r.cel ~= prevcel then
                    stepf[#stepf + 1] = r.f; stepc[#stepc + 1] = r.cel
                end
                prevcel = r.cel
            end
        end
        if #stepf < 3 then
            log("      (too few steps to time)")
        else
            -- ★ CONSECUTIVE steps only. The entry walk is played in more than one burst
            -- with the scene's other beats between them, and a gap across a burst boundary
            -- is not a step interval — averaging it in is how a pause becomes a "rate".
            local gaps, per, hist, gapped = {}, {}, {}, 0
            for i = 2, #stepf do
                local d = stepf[i] - stepf[i - 1]
                if d <= 20 then
                    gaps[#gaps + 1] = d
                    hist[d] = (hist[d] or 0) + 1
                    local c = stepc[i - 1]
                    per[c] = per[c] or { n = 0, s = 0 }
                    per[c].n = per[c].n + 1; per[c].s = per[c].s + d
                else
                    gapped = gapped + 1
                end
            end
            local sum = 0
            for _, d in ipairs(gaps) do sum = sum + d end
            local mean = sum / #gaps
            log(string.format("      %d steps, %d consecutive intervals (%d burst gaps dropped)",
                              #stepf, #gaps, gapped))
            log(string.format("      MEAN %.2f f/cel = %.1f ms/cel", mean, mean * 1000.0 / HZ))
            local hk = {}
            for k in pairs(hist) do hk[#hk + 1] = k end
            table.sort(hk)
            local hs = {}
            for _, k in ipairs(hk) do hs[#hs + 1] = string.format("%df x%d", k, hist[k]) end
            log("      interval histogram: " .. table.concat(hs, ", ") ..
                (#hk == 1 and "   (perfectly regular)" or "   ★ NOT REGULAR"))
            local ps = {}
            for c = WALK_LO, WALK_HI do
                if per[c] then ps[#ps + 1] = string.format("cel %d %.2f", c, per[c].s / per[c].n) end
            end
            log("      per-cel hold: " .. table.concat(ps, "  "))
            local seq = {}
            for i = 1, math.min(#gaps, 42) do seq[#seq + 1] = tostring(gaps[i]) end
            log("      first intervals, in order: " .. table.concat(seq, ","))
            -- ★ EVERY INTERVAL THAT IS NOT THE MODAL ONE, WITH THE FRAME IT STARTS AT AND
            -- THE BEAT IN FORCE. A mean hides a block: the exit's mean is 8.12 and it
            -- contains a run of ten consecutive 10s, which is 1.7 walk cycles held 25%
            -- long and then snapped back. Naming the frame is what makes it attributable.
            local mode, best = nil, -1
            for k, v in pairs(hist) do if v > best then mode, best = k, v end end
            local odd = {}
            for i = 2, #stepf do
                local d = stepf[i] - stepf[i - 1]
                if d <= 20 and d ~= mode then
                    local b = -1
                    for _, s in ipairs(steps) do
                        if s.f >= stepf[i - 1] then b = s.beat; break end
                    end
                    odd[#odd + 1] = string.format("f%d cel%d %df beat%d",
                                                  stepf[i - 1], stepc[i - 1], d, b)
                end
            end
            log(string.format("      modal interval %df; %d intervals differ from it:", mode, #odd))
            for i = 1, #odd, 4 do
                log("        " .. table.concat({ odd[i], odd[i+1], odd[i+2], odd[i+3] }, "   "))
            end
        end
    end

    -- the VM's own step ticks, as an independent count of the same thing
    log("")
    log("# cad_idx ticks (the VM's OWN step boundary, tapped at its write) — an independent")
    log("# count of the same steps, so a disagreement with the draw-derived figure above is")
    log("# visible rather than assumed away.")
    local tg, th = {}, {}
    for i = 2, #steps do
        local d = steps[i].f - steps[i - 1].f
        if d > 0 and d <= 20 then tg[#tg + 1] = d; th[d] = (th[d] or 0) + 1 end
    end
    local s2 = 0
    for _, d in ipairs(tg) do s2 = s2 + d end
    local hk2 = {}
    for k in pairs(th) do hk2[#hk2 + 1] = k end
    table.sort(hk2)
    local hs2 = {}
    for _, k in ipairs(hk2) do hs2[#hs2 + 1] = string.format("%df x%d", k, th[k]) end
    log(string.format("#   %d ticks, mean %.2f f/tick; histogram: %s",
                      #steps, #tg > 0 and s2 / #tg or 0, table.concat(hs2, ", ")))

    if TSEED then
        log("")
        log("# SEEDED TIMING CONTROL — does the measured interval move when the cadence does?")
        if not tseed_landed then
            log("# SEED INEFFECTIVE: cad_tab did not read back as written. This is a verdict on")
            log("#   the SEED, not on the tap — do not read it as either (P3.100).")
        elseif tseed_at == nil then
            log("# SEED NEVER FIRED: the run ended before the patch point.")
        else
            local before, after, nb, na = 0, 0, 0, 0
            for i = 2, #steps do
                local d = steps[i].f - steps[i - 1].f
                if d > 0 and d <= 30 then
                    if steps[i].f < tseed_at then before = before + d; nb = nb + 1
                    else after = after + d; na = na + 1 end
                end
            end
            local mb, ma = nb > 0 and before / nb or 0, na > 0 and after / na or 0
            log(string.format("#   mean step interval BEFORE the seed %.2f f (%d), AFTER %.2f f (%d)",
                              mb, nb, ma, na))
            if na < 10 or nb < 10 then
                log("# CONTROL FAILED: too few steps either side to be able to disagree.")
            elseif ma > mb + 2.0 then
                log(string.format("# CONTROL PASSED: forcing cad_tab %d -> %d moved the MEASURED interval",
                                  tseed_was[0] or -1, TSEED_VAL))
                log(string.format("#   from %.2f to %.2f frames. The tap reads the machine's real step", mb, ma))
                log("#   timing — a tap wired to anything else would not have moved.")
            else
                log("# CONTROL FAILED: the cadence changed and the measured interval did not.")
                log("#   Reject this tap (P3.48b).")
            end
        end
    end
    out:close()
    manager.machine:exit()
end)
