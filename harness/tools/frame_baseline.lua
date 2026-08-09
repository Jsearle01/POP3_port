-- harness/tools/frame_baseline.lua
--
-- POP P3.43 — RE-BASELINE THE FRAME. Measure what the engine actually costs, and
-- decompose it, instead of dividing by a model.
--
-- ---------------------------------------------------------------
-- WHY
-- ---------------------------------------------------------------
-- Every budget verdict in the P3.33-P3.42 arc has the shape "baseline + new cost,
-- against 29,673". The NEW COST was contested and so it was modelled, written,
-- assembled, executed and corrected across six dispatches. THE BASELINE WAS NEVER RUN.
-- It is P3.19's arithmetic model (19,652 cy), re-derived once by more arithmetic, and
-- flagged as inherited twice without being tested.
--
-- P3.42 measured the whole engine iteration at ~57,000 cy — 2.9x that model — and the
-- assumption-free form of the result needs no cycle constants at all: the loop takes
-- 2.161 VIDEO FRAMES per iteration, and a frame costed at 0.66 of a budget cannot
-- consume 2.16 budgets. This tool replaces the model with a measured, DECOMPOSED
-- figure, so the next verdict divides by something that was run.
--
-- ---------------------------------------------------------------
-- METHOD: the same VBL spin clock, plus RUN-TIME ABLATION
-- ---------------------------------------------------------------
-- MAME 0.281's Lua wrapper exposes no cycle counter and `machine.time` is quantised to
-- the scheduler timeslice (idioms §0), so cost is measured off the VBL spin-wait:
-- `hal_vbl_spin` is `cmpb <hal_frame_lo` (4) + `beq` taken (3) = 7 cy/iteration and it
-- burns every cycle the engine is not working. Per engine iteration:
--
--     work = frames_elapsed * 29,859  -  spins * 7
--
-- Intra-iteration cycles CANNOT be measured this way — there is no counter to read at a
-- boundary — so the decomposition is by ABLATION and DIFFERENCE: run the same scene with
-- one component removed and subtract. Each component is removed AT RUN TIME, by patching
-- the call site or forcing a branch, so **no `src/` file is touched** and every mode
-- measures the same build.
--
--     full       nothing removed
--     nopeel     ch_anymove reads forced to 0 -> the erase and save passes return
--                immediately; only the draw pass does work
--     nochars    `jsr [CHARS_TAB]` -> NOPs; the whole character path is gone
--     noflicker  `jsr flicker`     -> NOPs; the torches are gone
--     neither    both call sites NOPped; what is left is the loop, the swap and the IRQ
--
-- ---------------------------------------------------------------
-- WHAT KEEPS THIS HONEST
-- ---------------------------------------------------------------
-- 1. **The patch is verified before it is applied.** The expected opcode bytes are
--    checked against memory and the run ABORTS on a mismatch. Patching an address that
--    does not hold the instruction you think it does produces a plausible number from a
--    corrupted program — a wrong answer that looks like an answer.
-- 2. **The ablation is confirmed by a second, independent signal**: entry taps on
--    blit_save / blit_erase / blit_cel count the blits actually performed. `nopeel` must
--    drive save and erase to ZERO while the draw count is unchanged; `nochars` must drive
--    all three to zero. A mode whose blit counts did not move did not ablate anything, and
--    its "saving" would be noise.
-- 3. **The screen is WRONG in every ablated mode** (frozen torches, frozen characters).
--    That is expected and it is why none of this is a visual gate — it is a cost
--    measurement and nothing here is offered as a 25.3 observation.
local OUT      = os.getenv("P_OUT")     or "build/frame_baseline.log"
local MODE     = os.getenv("P_MODE")    or "full"
local LOOP     = tonumber(os.getenv("P_LOOP")    or "0x207C")
local SPIN     = tonumber(os.getenv("P_SPIN")    or "0x7980")
local ANYMOVE  = tonumber(os.getenv("P_ANYMOVE") or "0x6909")
local FLICKER  = tonumber(os.getenv("P_FLICKER") or "0x20AF")
local CHARSTAB = tonumber(os.getenv("P_CHARSTAB") or "0x5040")
local B_SAVE   = tonumber(os.getenv("P_BSAVE")   or "0x39BF")
local B_ERASE  = tonumber(os.getenv("P_BERASE")  or "0x39F8")
local B_CEL    = tonumber(os.getenv("P_BCEL")    or "0x391B")
local CHARSFRAME = tonumber(os.getenv("P_CHARSFRAME") or "0x3A4A")
local FIRST    = tonumber(os.getenv("P_FIRST")   or "1900")
local LAST     = tonumber(os.getenv("P_LAST")    or "3400")
local CY_PER_FRAME = 29859
local SPIN_CY      = 7

local scr = manager.machine.screens:at(1)
local mem = manager.machine.devices[":maincpu"].spaces["program"]
local f   = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end

local state, t0   = "boot", nil
local armed       = false
local spins       = 0
local open_fn     = nil
local cur_frame   = 0
local n, sum_fr, sum_sp = 0, 0, 0
local fhist       = {}
local blits       = { save = 0, erase = 0, cel = 0 }
local entries     = { chars = 0, flicker = 0 }
local any_reads   = 0
local aborted     = nil

-- `jsr flicker` assembles as BD <addr>; `jsr [CHARS_TAB]` as AD 9F <addr> (indirect
-- extended). Both are checked byte for byte before anything is written.
local NOP = 0x12
local patches = {
    flicker  = { addr = LOOP,     want = {0xBD, (FLICKER  >> 8) & 0xFF, FLICKER  & 0xFF} },
    chars    = { addr = nil,      want = {0xAD, 0x9F, (CHARSTAB >> 8) & 0xFF, CHARSTAB & 0xFF} },
}

-- The chars call site is not at a symbol, so it is FOUND by scanning the loop for the
-- indirect-extended JSR opcode (AD 9F) rather than by counting bytes from room_loop — an
-- offset would go stale the moment an instruction above it changed length, and would then
-- patch the middle of some other instruction.
--
-- THE SEARCH DOES NOT ASSUME THE OPERAND, IT CROSS-CHECKS IT. The address is looked up
-- independently from the link map (P_CHARSTAB) and the two must agree; a mismatch is
-- reported with BOTH values rather than resolved in favour of either. That is what caught
-- the section-base offset on this tool's first run: the map lists `equ` symbols biased by
-- the section base, so CHARS_TAB read $5040 where the instruction holds $3040.
-- Uniqueness is required too — two indirect JSRs in the loop would make "the one I found"
-- an assumption.
local function find_chars_call()
    local hits = {}
    for a = LOOP, LOOP + 0x80 do
        if mem:read_u8(a) == 0xAD and mem:read_u8(a + 1) == 0x9F then
            hits[#hits + 1] = a
        end
    end
    if #hits == 0 then
        aborted = string.format("no indirect-extended JSR (AD 9F) in $%04X..$%04X", LOOP, LOOP + 0x80)
        return nil
    end
    if #hits > 1 then
        aborted = string.format("%d indirect-extended JSRs in the loop — which one is the chars call is an assumption", #hits)
        return nil
    end
    local a = hits[1]
    local operand = mem:read_u8(a + 2) * 256 + mem:read_u8(a + 3)
    if operand ~= CHARSTAB then
        aborted = string.format("JSR [$%04X] found at $%04X but the map says CHARS_TAB=$%04X — the two disagree",
                                operand, a, CHARSTAB)
        return nil
    end
    patches.chars.want = {0xAD, 0x9F, (operand >> 8) & 0xFF, operand & 0xFF}
    return a
end

local function verify_and_nop(name)
    local p = patches[name]
    if name == "chars" then p.addr = find_chars_call() end
    if not p.addr then
        aborted = string.format("could not locate the %s call site in $%04X..$%04X", name, LOOP, LOOP + 0x80)
        return false
    end
    for i, b in ipairs(p.want) do
        local got = mem:read_u8(p.addr + i - 1)
        if got ~= b then
            aborted = string.format("%s call site $%04X byte %d is $%02X, expected $%02X — NOT PATCHING",
                                    name, p.addr, i - 1, got, b)
            return false
        end
    end
    for i = 1, #p.want do mem:write_u8(p.addr + i - 1, NOP) end
    log(string.format("# ablated %s: $%04X, %d bytes -> NOP (opcode bytes verified first)",
                      name, p.addr, #p.want))
    return true
end

_G._spin_tap = mem:install_read_tap(SPIN, SPIN, "vbl_spin", function(off, data, mask)
    if armed then spins = spins + 1 end
    return data
end)

-- FORCING A VALUE AT A READ, the idiom §10 form, done with a tap rather than the
-- debugger (headless -debug hangs without execution_state="run"). Memory keeps its real
-- value; only what the CPU sees is changed, so ch_scan's own store logic is untouched
-- and just the erase/save gate flips.
if MODE == "nopeel" then
    _G._any_force = mem:install_read_tap(ANYMOVE, ANYMOVE, "anymove_force", function(off, data, mask)
        if armed then any_reads = any_reads + 1; return 0 end
        return data
    end)
end

-- WHERE THE HIT CAME FROM. A read-tap fires on any read of the address — an opcode
-- fetch OR a data read — so a non-zero count is not by itself proof the routine ran.
-- `nochars` left a residual blit_cel count with the character path NOPped, and the honest
-- way to settle what that is, is to look rather than to reason: log the PC for the first
-- few hits. (pcall'd because the state accessor is not guaranteed across MAME builds, and
-- a diagnostic that throws would take the measurement down with it.)
local cpudev = manager.machine.devices[":maincpu"]
local function pc_now()
    local ok, v = pcall(function() return cpudev.state["PC"].value end)
    if ok and v then return v end
    return nil
end
local diag = {}

local function blit_tap(addr, key)
    return mem:install_read_tap(addr, addr, "blit_" .. key, function(off, data, mask)
        if armed and cur_frame >= FIRST and cur_frame <= LAST then
            blits[key] = blits[key] + 1
            if #diag < 12 and key == "cel" then
                local pc = pc_now()
                diag[#diag + 1] = string.format("$%04X read; PC=%s", addr,
                                                pc and string.format("$%04X", pc) or "unavailable")
            end
        end
        return data
    end)
end
_G._bs = blit_tap(B_SAVE, "save")
_G._be = blit_tap(B_ERASE, "erase")
_G._bc = blit_tap(B_CEL, "cel")

-- GATE THE ABLATION ON THE THING ABLATED. The blit counts are secondary colour; the
-- primary evidence that `nochars` removed the character path is that `chars_frame` STOPS
-- BEING ENTERED, and likewise `flicker` for `noflicker`. Counting the routine itself
-- needs no argument about which caller reaches which primitive — which is exactly the
-- argument the blit_cel residual would otherwise force.
local function entry_tap(addr, key)
    return mem:install_read_tap(addr, addr, "entry_" .. key, function(off, data, mask)
        if armed and cur_frame >= FIRST and cur_frame <= LAST then
            entries[key] = entries[key] + 1
        end
        return data
    end)
end
_G._ec = entry_tap(CHARSFRAME, "chars")
_G._ef = entry_tap(FLICKER,    "flicker")

_G._loop_tap = mem:install_read_tap(LOOP, LOOP, "room_loop", function(off, data, mask)
    if not armed then return data end
    local fn = cur_frame
    if open_fn ~= nil and fn >= FIRST and fn <= LAST then
        local fr = fn - open_fn
        n = n + 1; sum_fr = sum_fr + fr; sum_sp = sum_sp + spins
        fhist[fr] = (fhist[fr] or 0) + 1
    end
    open_fn = fn
    spins   = 0
    return data
end)

local function report()
    log(string.format("# FRAME BASELINE — mode=%s", MODE))
    if aborted then
        log("# ABORTED: " .. aborted)
        log("# no measurement is reported, because the program was not in the state assumed")
        return
    end
    log(string.format("# frame = %d cy; idle = spins($%04X) * %d; sampled frames %d..%d",
                      CY_PER_FRAME, SPIN, SPIN_CY, FIRST, LAST))
    if n == 0 then
        log("# NO ITERATIONS SAMPLED — the loop tap never fired; nothing is reported")
        return
    end
    local mf = sum_fr / n
    local ms = sum_sp / n
    local work = mf * CY_PER_FRAME - ms * SPIN_CY
    log(string.format("# %d iterations  %.3f frames/iter  %.1f spins/iter", n, mf, ms))
    log(string.format("# RESULT mode=%s work=%.0f cy/iter (%.3f frame budgets) idle=%.0f cy",
                      MODE, work, work / CY_PER_FRAME, ms * SPIN_CY))
    log(string.format("# ENTRIES per iter: chars_frame=%.2f flicker=%.2f   (the ablation gate)",
                      entries.chars / n, entries.flicker / n))
    log(string.format("# blits in window: save=%d erase=%d cel=%d  (per iter: %.2f/%.2f/%.2f)",
                      blits.save, blits.erase, blits.cel,
                      blits.save / n, blits.erase / n, blits.cel / n))
    for _, d in ipairs(diag) do log("# diag blit_cel " .. d) end
    if MODE == "nopeel" then
        log(string.format("# ch_anymove reads forced to 0: %d (%.1f per iteration)", any_reads, any_reads / n))
    end
    local keys = {}
    for k in pairs(fhist) do keys[#keys+1] = k end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts+1] = string.format("%d:%d", k, fhist[k]) end
    log(string.format("# frames/iter histogram  %s", table.concat(parts, " ")))
end

local nk = manager.machine.natkeyboard
nk.in_use = true

local function tick()
    cur_frame = scr:frame_number()
    local fn = cur_frame
    if state == "boot" then
        if fn >= 120 then nk:post('LOADM"ROOM"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if fn > t0 + 900 then nk:post('EXEC\n'); state = "wait" end
        return
    end
    if state == "wait" then
        if mem:read_u8(0x2008) > 0 then
            -- Patch only once the program is loaded and turning over: before that these
            -- addresses hold whatever DECB left there (idioms §0, the unarmed-tap trap).
            local ok = true
            if MODE == "nochars"   or MODE == "neither" then ok = verify_and_nop("chars")   and ok end
            if MODE == "noflicker" or MODE == "neither" then ok = verify_and_nop("flicker") and ok end
            if not ok then report(); manager.machine:exit(); return end
            armed, state = true, "watch"
        end
        return
    end
    if fn > LAST then
        report()
        manager.machine:exit()
    end
end

_G._notifier = emu.add_machine_frame_notifier(tick)
