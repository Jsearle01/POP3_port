-- oracle_exit_column.lua — P3.100: THE ORACLE'S OWN DRAWN COLUMN, per cel, on the machine.
--
-- ★★★ WHY NOT THE SOURCE, AND WHY NOT THE PORT'S FORMULA. P3.98 read `MLayGen: LDA XCO /
-- SEC / SBC WIDTH / STA XCO` [HIRES.S:1202-1208] and concluded the port's exit stride was
-- faithful. P3.99 traced XCO on the running oracle and reported that confirmed — but it
-- measured "mirrored draws in this scene" (150 of them, widths 2,5,7,11,12) and concluded
-- about "the vizier's six walk cels", which is a wider set standing in for a narrower
-- question. And the port half of that comparison came from `cel_parity_rule.draw_x`, which
-- is a TRANSCRIPTION of MLayGen — so it could only ever agree. Both were withdrawn.
--
-- ★★ SO THE SIX CELS ARE NAMED HERE, AND NAMED IN THE ORACLE'S OWN NUMBERING.
-- content/cutscene/cel_table.s maps the port's cel numbers to the oracle's 1-based index
-- into CHTAB6: cels 48..53 (viz_walk1..the end of the loop) are images 74..79, of widths
-- 3,4,5,5,4,4 Apple bytes. The width is the fingerprint — if the oracle's own WIDTH for
-- those images is not 3,4,5,5,4,4, the mapping is wrong and the run says so.
--
-- WHAT IS TAPPED, AND WHY EACH ADDRESS IS THE RIGHT ONE [HIRES.LST, and the ten bytes of
-- MLayGen are matched against memory before the seed believes any of it]:
--
--   XSAVE  $F4   PREPREP's `LDA XCO / STA XSAVE` at $EF13. ★ THIS, NOT IMSAVE, IS THE
--                START-OF-LAY MARKER. The first cut of this tool opened a lay on the
--                IMSAVE write and got 700 phantom lays with no XSAVE, no WIDTH and a
--                garbage OFFSET: $F2 is written by more than PREPREP. XSAVE is HIRES-
--                private, written in exactly one place, and by the time it is written
--                IMSAVE already holds this lay's image number two instructions back.
--   IMSAVE $F2   the image NUMBER — PREPREP saves it BEFORE `setimage` turns IMAGE into
--                a pointer. Read at the XSAVE write.
--   OFFSET $03   the sub-byte shift, 0..6, from cvtx via loadobj [GAMEBG.S:1060-1073,
--                FRAMEADV.S:717-722]. An Apple byte is SEVEN pixels and MLayGen moves only
--                XCO, so XCO alone quantises the oracle's position to 7 px while the
--                port's column quantises to 4 — comparing them AS COLUMNS compares two
--                different rulers. The left edge is XCO*7 + OFFSET.
--   WIDTH  $F6   the image's own width byte, out of the image header. First write only:
--                CROP writes WIDTH again later ($EFF5 `inc WIDTH`, $F107 from VISWIDTH).
--   XCO    $01   every write inside the lay, in order.
--
-- ★ NO DISCRIMINATOR IS ASSUMED, AND THE FIRST ONE TRIED WAS WRONG. This began by reading
-- the mirror off LAY's `and #$7f / sta OPACITY` and that MISCLASSIFIED HALF THE DATA —
-- it produced two tables holding the same steps. The raw structure below is what settled
-- it, and it is unambiguous: inside a lay the FIRST XCO write is MLayGen's anchor and the
-- SECOND is DONE's restore back to XSAVE [HIRES.LST:816-820]. A lay that never took the
-- MLAY branch has no XCO write that differs from XSAVE. So mirrored iff xco[1] ~= XSAVE:
-- the branch, observed, not inferred from the coordinates it produces.
--
-- ★★ WRITE TAPS ONLY. On the 6502 a read-tap on a code address silently false-0s through
-- the opcode-fetch bypass [mame-idioms-apple2e-oracle.md §1].
--
-- ★★★ AND IT SEEDS ITSELF (P3.48b/P3.49) — THROUGH THE MACHINE'S OWN ARITHMETIC, NOT
-- THROUGH A CODE PATCH, BECAUSE THE CODE PATCH DID NOT STICK AND THE CONTROL CAUGHT IT.
--
-- The first seed here rewrote MLayGen's `SBC WIDTH` ($E5 $F6) to `SBC #$28`. It verified
-- MLayGen's ten bytes against the listing first, they matched, and it patched — and then
-- reported `0 lays whose first XCO write is the seeded anchor; 458 whose first is XSAVE`.
-- ★ THE WRITE WAS DROPPED: HIRES lives in LANGUAGE-CARD RAM at $EE00-$F800, which the
-- Apple IIe reads as RAM but write-protects unless the $C08x switch says otherwise. Reads
-- came back correct, which is exactly why the byte check passed and told us nothing.
-- ★★ THAT IS THE SEEDED FAILURE DOING ITS JOB: a probe whose seed silently no-ops would
-- have published a "PASSED" on an unpatched machine.
--
-- So the seed now moves an INPUT rather than the code. P_SEED=1 intercepts the WIDTH write
-- inside PREPREP — zero-page-adjacent HIRES scratch in main RAM, and a MAME write tap may
-- return a substituted value — and forces WIDTH to 40, but ONLY for images 74..79, so
-- nothing but the six cels under test is perturbed. MLayGen then anchors at XSAVE-40,
-- which wraps to $E0..$FF: a column no legitimate XCO (0..39) can take, so a tap reading
-- the wrong store cannot accidentally agree. The XCO tap reads WIDTH back to confirm the
-- substitution actually landed, so an ineffective seed is reported as an ineffective seed
-- and never as a verdict on the tap.
--
-- ARMED ON THE SCENE, NOT ON A FRAME NUMBER: PlayCut0's own ordered markers
-- SPEED 12 -> psandcount 0 -> SPEED 7, the last being the line before `lda #Vexit`
-- [SUBS.S:722-752, traced at P3.85].

local OUT   = os.getenv("P_OUT") or "build/tmp/oracle_exit_column.log"
-- 600 frames covers the whole walk-out: he is off the right edge by ~armed+360. The first
-- cut used 1600 and MAME kept calling the notifier after `manager.machine:exit()` (the
-- exit is deferred), so the report block ran ~200 times and appended 200 copies of itself
-- to the log. A `reported` guard now closes that; the shorter window is why it showed.
local AFTER = tonumber(os.getenv("P_AFTER") or "600")
-- P_SEED=1      — the P3.100 COLUMN control (WIDTH substituted, anchor must move)
-- P_SEED=speed  — the P3.101 TIMING control (SPEED substituted, step interval must move)
local SEEDMODE   = os.getenv("P_SEED") or "0"
local SEED       = (SEEDMODE == "1" or SEEDMODE == "width")
local SEED_SPEED = (SEEDMODE == "speed") and tonumber(os.getenv("P_SEED_SPEED") or "20") or nil
local RAWN  = tonumber(os.getenv("P_RAWN") or "30")

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local out = io.open(OUT, "w")
local function log(s) out:write(s .. "\n"); out:flush() end

-- hrparams zero page [HRPARAMS.S:43-50] and HIRES scratch [HIRES.LST:932-948]
local XCO, YCO, OFFSET, IMAGE, OPACITY, TABLE = 0x01, 0x02, 0x03, 0x04, 0x06, 0x07
local IMSAVE, XSAVE, YSAVE, WIDTH, HEIGHT = 0xF2, 0xF4, 0xF5, 0xF6, 0xF7
local SPEED = 0x030C                                  -- MASTER.LST:530
local PSAND = 0xE14A                                  -- GAMEBG.LST:311
local MLAYGEN = 0xF35E                                -- HIRES.LST:2083
local SEED_W = 40                                     -- the forced width, and the anchor step
-- the machine's own refresh, so both sides of the comparison land in milliseconds.
-- ⚠ a PROPERTY, not a method — `scr:refresh_attoseconds()` dies at runtime.
local HZ = 1.0e18 / scr.refresh_attoseconds

-- the vizier's six walk cels, in the ORACLE's numbering, from content/cutscene/cel_table.s
local IMG_LO, IMG_HI = 74, 79
local WANT_W = { [74] = 3, [75] = 4, [76] = 5, [77] = 5, [78] = 4, [79] = 4 }

-- ★★★ P3.101 — TWO MARKERS NOW, BECAUSE THE ENTRY IS THE CONTROL AND IT HAPPENS FIRST.
--
-- PlayCut0 sets `lda #7 / sta SPEED` TWICE [SUBS.S:683 and :752], and the two are the two
-- halves of this dispatch:
--
--     the FIRST  — three lines before `lda #Vapproach`, so it opens the ENTRY walk
--     the SECOND — the line before `lda #Vexit`, so it opens the EXIT walk
--
-- and between them sits `lda #12 / sta SPEED` for the hourglass beat. ★ SO THE ORACLE
-- RUNS THE ENTRY AND THE EXIT AT THE SAME NOMINAL SPEED, 7, AND ANY DIFFERENCE BETWEEN
-- THEIR ACHIEVED RATES IS THE ORACLE OVERRUNNING ITS OWN FLOOR — `lda SPEED / jsr pause`
-- is a MINIMUM [SUBS.S:876-881], not a target. That is measurable and it has never been
-- measured; P3.99 armed on the second marker only and could not see the entry at all.
--
-- P3.99's ordered guard (SPEED 12 → psandcount 0 → SPEED 7) still identifies the SECOND
-- one, and it is still needed: SPEED 7 is written more than once, and the first cut of
-- that tool armed at f3597 — which is exactly the marker this dispatch wants for the
-- entry, and was a bug when the exit was the question.
local seenA, seenB, armed_at, vexit_at = false, false, nil, nil
local speed_hist, cur_speed = {}, nil
local lays, cur = {}, nil
local off_writes = {}
local seeded, seed_err, mlg_ok, mlg_at = false, nil, false, nil
local reported = false

_G._tspeed = mem:install_write_tap(SPEED, SPEED, "sp", function(off, data, mask)
    local fn = scr:frame_number()
    if SEED_SPEED and armed_at ~= nil then data = SEED_SPEED end
    if cur_speed ~= data then
        speed_hist[#speed_hist + 1] = { f = fn, v = data }
        cur_speed = data
    end
    -- the FIRST SPEED 7 opens the entry walk and starts the recording window
    if data == 7 and armed_at == nil then armed_at = fn end
    if data == 12 then seenA = true end
    -- the ordered guard still names the SECOND one: the line before `lda #Vexit`
    if data == 7 and seenA and seenB and vexit_at == nil then vexit_at = fn end
    return data
end)
_G._tsand = mem:install_write_tap(PSAND, PSAND, "ps", function(off, data, mask)
    if data == 0 and seenA then seenB = true end
    return data
end)

local function live()
    if armed_at == nil then return false end
    if vexit_at == nil then return true end          -- the entry half runs until Vexit
    return scr:frame_number() <= vexit_at + AFTER
end

-- START OF A LAY — PREPREP's STA XSAVE, the only writer of $F4
_G._txs = mem:install_write_tap(XSAVE, XSAVE, "xsave", function(off, data, mask)
    if not live() then return data end
    -- ★ KEPT ONLY IF IT IS ONE OF THE SIX. The window now spans the whole cutscene rather
    -- than 600 frames after Vexit, and every tile and every torch lays too — storing all
    -- of them was 27,521 records for a question about six images.
    if cur and cur.img and cur.img >= IMG_LO and cur.img <= IMG_HI then
        cur.sp = cur_speed
        cur.vexit = (vexit_at ~= nil and cur.f >= vexit_at)
        lays[#lays + 1] = cur
    end
    cur = { f = scr:frame_number(), xin = data,
            img = mem:read_u8(IMSAVE), off = mem:read_u8(OFFSET), xco = {} }
    return data
end)

-- WIDTH, first write per lay only: CROP writes it again later ($EFF5 `inc WIDTH`, $F107
-- from VISWIDTH). In SEED mode the value is SUBSTITUTED, for the six images only.
_G._tw = mem:install_write_tap(WIDTH, WIDTH, "width", function(off, data, mask)
    if not live() then return data end
    if seeded and cur == nil then return data end
    local im = mem:read_u8(IMSAVE)
    if seeded and im >= IMG_LO and im <= IMG_HI and cur and cur.w == nil then
        cur.w = data
        cur.forced = true
        return SEED_W
    end
    if cur and cur.w == nil then cur.w = data end
    return data
end)

-- ★ OFFSET's OWN WRITES, kept separately. The value read at PREPREP is what the lay will
-- shift by; logging the writes as well is what makes a disagreement between the two
-- visible rather than silent, which is the fault mode this whole dispatch is about.
_G._toff = mem:install_write_tap(OFFSET, OFFSET, "offset", function(off, data, mask)
    if live() then off_writes[data] = (off_writes[data] or 0) + 1 end
    return data
end)

_G._tx = mem:install_write_tap(XCO, XCO, "xco", function(off, data, mask)
    if live() and cur then
        if #cur.xco == 0 and cur.forced then cur.wback = mem:read_u8(WIDTH) end
        cur.xco[#cur.xco + 1] = data
    end
    return data
end)

-- MLayGen's ten bytes, from the listing — still checked, because the whole reading below
-- rests on `SBC WIDTH / STA XCO` being the instruction at that address on this machine.
-- ★ CHECKED IS NOT PATCHED, and the difference is the lesson: these bytes matched while
-- the patch that followed was being silently discarded.
local MLG = { 0x20, 0x0F, 0xEF,      -- JSR PREPREP
              0xA5, 0x01,            -- LDA XCO
              0x38,                  -- SEC
              0xE5, 0xF6,            -- SBC WIDTH
              0x85, 0x01 }           -- STA XCO
local function mlaygen_intact()
    local s = {}
    for i = 1, #MLG do
        local b = mem:read_u8(MLAYGEN + i - 1)
        s[i] = string.format("%02X", b)
        if b ~= MLG[i] then
            seed_err = string.format("$%04X holds %s, not MLayGen", MLAYGEN, table.concat(s, " "))
            return false
        end
    end
    return true
end

local function mirrored(L)
    return L.xin ~= nil and L.xco[1] ~= nil and L.xco[1] ~= L.xin
end

_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if reported or armed_at == nil then return end
    -- ★ THE BYTE CHECK IS RETRIED, NOT DEMANDED ON THE FIRST LOOK. $EE00-$F800 is
    -- language-card RAM and the game banks it in and out: read at the wrong instant,
    -- $F35E returns $E8 — ROM — and the first version of this aborted the whole run on
    -- that. Whether MLayGen is where the listing says is a question about the machine, not
    -- about the frame the notifier happened to fire on.
    if SEED and not mlg_ok and fn <= armed_at + 400 then
        if mlaygen_intact() then mlg_ok, mlg_at = true, fn end
    end
    if SEED and not seeded then
        seeded = true
        lays, cur = {}, nil               -- only post-seed lays count
        log(string.format("# SEEDED: PREPREP's WIDTH forced to %d for images %d..%d only.",
                          SEED_W, IMG_LO, IMG_HI))
        log(string.format("#   Every mirrored anchor for those six must now land at XSAVE-%d,", SEED_W))
        log("#   which wraps to $E0..$FF — a column no legitimate XCO (0..39) can take.")
        return
    end
    -- ★ THE WINDOW NOW CLOSES ON THE VEXIT MARKER, NOT ON THE ARM. Arming moved to the
    -- FIRST SPEED 7 (the entry), so `armed_at + N` would have ended the run in the middle
    -- of the hourglass beat and reported "no exit lays" — the same shape as P3.100's
    -- first port run, which stopped at frame 4539 and caught five exit steps.
    if vexit_at == nil then return end
    if fn <= vexit_at + (SEED and 700 or AFTER) then return end
    if cur and cur.img and cur.img >= IMG_LO and cur.img <= IMG_HI then
        cur.sp = cur_speed; cur.vexit = (vexit_at ~= nil and cur.f >= vexit_at)
        lays[#lays + 1] = cur
    end
    cur = nil
    reported = true

    log(string.format("# armed at frame %s (the FIRST SPEED 7, three lines before `lda #Vapproach`)",
                      tostring(armed_at)))
    log(string.format("# Vexit at frame %s (the SECOND SPEED 7, the line before `lda #Vexit`)",
                      tostring(vexit_at)))
    log(string.format("# %d lays of images %d..%d recorded", #lays, IMG_LO, IMG_HI))
    log(string.format("# screen refresh %.6f Hz, one frame = %.3f ms", HZ, 1000.0 / HZ))
    local sh = {}
    for _, s in ipairs(speed_hist) do sh[#sh + 1] = string.format("f%d:SPEED=%d", s.f, s.v) end
    log("# SPEED, every change, from the machine: " .. table.concat(sh, "  "))

    if SEED then
        -- ★ THE CONTROL IS SCOPED TO THE POPULATION THE MEASUREMENT USES. Other objects'
        -- lays are not perturbed and their first XCO write is not always MLayGen's (a
        -- clipped LayGen writes XCO from CROP), so validating the tap on them would be
        -- validating it on something else — which is the very substitution this dispatch
        -- exists to stop.
        local ok, bad, ineffective = 0, nil, 0
        for _, L in ipairs(lays) do
            if L.img and L.img >= IMG_LO and L.img <= IMG_HI and L.xin and L.xco[1] then
                if L.wback ~= SEED_W then
                    ineffective = ineffective + 1
                elseif L.xco[1] == (L.xin - SEED_W) & 0xFF then
                    ok = ok + 1
                else
                    bad = bad or string.format(
                        "img %d: XSAVE %d, first XCO write %d, seeded anchor should be %d",
                        L.img, L.xin, L.xco[1], (L.xin - SEED_W) & 0xFF)
                end
            end
        end
        log("# SEEDED CONTROL — does the tap read the store MLayGen actually makes?")
        log(mlg_ok
            and string.format("# MLayGen's ten bytes match the listing at $%04X (seen at frame %s).",
                              MLAYGEN, tostring(mlg_at))
            or  string.format("# ★ MLayGen's bytes never matched at $%04X in the window: %s",
                              MLAYGEN, tostring(seed_err)))
        log(string.format("# images %d..%d after the seed: %d anchored at XSAVE-%d, %d with the",
                          IMG_LO, IMG_HI, ok, SEED_W, ineffective))
        log(string.format("#   substitution not present in WIDTH, %s", bad and "and a mismatch" or "no mismatches"))
        if ineffective > 0 and ok == 0 then
            log("# SEED INEFFECTIVE: the width substitution never reached WIDTH. This is a")
            log("#   verdict on the SEED, not on the tap — do not read it as either.")
        elseif bad then
            log("# CONTROL FAILED: " .. bad)
            log("#   Reject this tap (P3.48b).")
        elseif ok < 12 then
            log(string.format("# CONTROL FAILED: only %d seeded anchors — fewer than two walk cycles,", ok))
            log("#   which is not enough for the control to have been able to disagree.")
        else
            log(string.format("# CONTROL PASSED: all %d seeded lays reported XSAVE-%d exactly — a", ok, SEED_W))
            log("#   column outside the legal 0..39 range, so it cannot be a coincidence of")
            log("#   the real geometry. The tap reads MLayGen's own store, at its own moment,")
            log("#   and it can tell an anchor from DONE's restore.")
        end
        out:close(); manager.machine:exit(); return
    end

    -- ---- raw structure, before any interpretation --------------------------------
    log("")
    local ow = {}
    for v, n in pairs(off_writes) do ow[#ow + 1] = string.format("%d x%d", v, n) end
    table.sort(ow)
    log("# every value written to OFFSET in the window: " .. table.concat(ow, ", "))
    log("")
    log(string.format("# RAW STRUCTURE of the first %d lays — every XCO write inside each, in", RAWN))
    log("# order. Nothing is filtered; the anchor is read OFF this, not asserted ahead of it.")
    log("    frame   img  width  OFFSET  XSAVE   XCO writes")
    for i = 1, math.min(RAWN, #lays) do
        local L = lays[i]
        local x = {}
        for _, v in ipairs(L.xco) do x[#x + 1] = tostring(v) end
        log(string.format("    %-7d %-4s %-6s %-7s %-7s %s",
                          L.f, tostring(L.img), tostring(L.w), tostring(L.off),
                          tostring(L.xin), table.concat(x, ",")))
    end

    -- ---- the six walk cels -------------------------------------------------------
    log("")
    log("# THE VIZIER'S SIX WALK CELS, oracle numbering: images 74..79 = port cels 48..53.")
    log("# WIDTH is read from the oracle's own image header; the port's cel_table carries")
    log("# 3,4,5,5,4,4 for the same six, so a mismatch here means the mapping is wrong.")
    -- ★ COUNTED OVER THE MIRRORED LAYS ONLY — the population the tables below report.
    -- Image NUMBERS are per-table, so images 74..79 of some OTHER chtable are different
    -- pictures entirely, and counting them here made the fingerprint read "1152 lays
    -- disagree" about a set that was never under test.
    local wseen, bad = {}, 0
    for _, L in ipairs(lays) do
        if L.img and L.img >= IMG_LO and L.img <= IMG_HI and L.w and mirrored(L) then
            wseen[L.img] = wseen[L.img] or L.w
            if L.w ~= WANT_W[L.img] then bad = bad + 1 end
        end
    end
    local ws = {}
    for i = IMG_LO, IMG_HI do ws[#ws + 1] = string.format("%d:w%s", i, tostring(wseen[i])) end
    log("#   widths seen: " .. table.concat(ws, "  ") ..
        (bad == 0 and "   MATCHES cel_table" or string.format("   %d lays disagree", bad)))

    for _, want in ipairs({ true, false }) do
        log("")
        log(want and "## MIRRORED lays — the exit walk (LAY took the MLAY branch)"
                  or  "## NORMAL lays — no anchor flip (the control: these are not the exit)")
        log("      frame   img  cel  w   OFF  XSAVE  in-px  anchor  LEFT-EDGE px  d(px)  XCO writes")
        local prev, n = nil, 0
        for _, L in ipairs(lays) do
            if L.img and L.img >= IMG_LO and L.img <= IMG_HI and L.w and mirrored(L) == want then
                n = n + 1
                local anchor = L.xco[1]
                local px  = anchor * 7 + L.off
                local d = prev and string.format("%+d", px - prev) or "   "
                local x = {}
                for _, v in ipairs(L.xco) do x[#x + 1] = tostring(v) end
                log(string.format("      %-7d %-4d %-4d %-3d %-4d %-6d %-6d %-7d %-13d %-6s %s",
                                  L.f, L.img, L.img - 26, L.w, L.off, L.xin, L.xin * 7 + L.off,
                                  anchor, px, d, table.concat(x, ",")))
                prev = px
            end
        end
        if n == 0 then log("      (none)") end
    end

    -- ================= P3.101 — WHEN, not where =====================================
    --
    -- ★ A STEP IS THE FIRST LAY OF A NEW IMAGE. The oracle lays each cel more than once
    -- per step (it draws to both hi-res pages), so counting lays as steps halves every
    -- interval — the same "wrong width" shape as the port's two-buffer draws.
    log("")
    log(string.rep("=", 78))
    log("# P3.101 — TIMING. The oracle's `lda SPEED / jsr pause` is a MINIMUM, not a target")
    log("# [SUBS.S:876-881], so the achieved rate is the floor plus whatever the frame cost.")
    log("# ENTRY and EXIT are both at SPEED 7 by PlayCut0's own writes, listed above — so a")
    log("# difference between their achieved rates is the ORACLE overrunning, not a policy.")

    for _, half in ipairs({ "ENTRY", "EXIT" }) do
        log("")
        log("## " .. half .. " timing — the oracle")
        local stepf, stepc, prevkey = {}, {}, nil
        for _, L in ipairs(lays) do
            local isexit = L.vexit and true or false
            if isexit == (half == "EXIT") and L.w and L.w > 0 then
                -- key on (image, frame-run): a new step is a change of image
                if L.img ~= prevkey then stepf[#stepf + 1] = L.f; stepc[#stepc + 1] = L.img end
                prevkey = L.img
            end
        end
        if #stepf < 3 then
            log("      (too few steps to time)")
        else
            local gaps, per, hist, gapped = {}, {}, {}, 0
            for i = 2, #stepf do
                local d = stepf[i] - stepf[i - 1]
                if d > 0 and d <= 20 then
                    gaps[#gaps + 1] = d; hist[d] = (hist[d] or 0) + 1
                    local c = stepc[i - 1]
                    per[c] = per[c] or { n = 0, s = 0 }
                    per[c].n = per[c].n + 1; per[c].s = per[c].s + d
                else
                    gapped = gapped + 1
                end
            end
            local sum = 0
            for _, d in ipairs(gaps) do sum = sum + d end
            local mean = #gaps > 0 and sum / #gaps or 0
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
            for c = IMG_LO, IMG_HI do
                if per[c] then ps[#ps + 1] = string.format("cel %d %.2f", c - 26, per[c].s / per[c].n) end
            end
            log("      per-cel hold: " .. table.concat(ps, "  "))
            local seq = {}
            for i = 1, math.min(#gaps, 42) do seq[#seq + 1] = tostring(gaps[i]) end
            log("      first intervals, in order: " .. table.concat(seq, ","))
        end
    end

    if SEED_SPEED then
        log("")
        log("# SEEDED TIMING CONTROL — does the measured interval move when SPEED does?")
        local held = mem:read_u8(SPEED)
        log(string.format("# SPEED substituted to %d on every write once armed; SPEED reads back %d",
                          SEED_SPEED, held))
        if held ~= SEED_SPEED then
            log("# SEED INEFFECTIVE: SPEED does not hold the substituted value. A verdict on the")
            log("#   SEED, not on the tap — do not read it as either (P3.100).")
        end
    end

    out:close()
    manager.machine:exit()
end)
