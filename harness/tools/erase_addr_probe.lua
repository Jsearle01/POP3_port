-- harness/tools/erase_addr_probe.lua
--
-- POP P3.49 — WHAT ADDRESS DOES THE ERASE ACTUALLY READ?
--
-- P3.48 measured slot 3 (buffer 1's torch 1) written 9022 times and read 0, while the
-- erase demonstrably RAN (t_prev never 0 at the gate, fl_prev[3] non-zero). So the erase
-- reads something that is not slot 3's peel range, and the address is unestablished.
--
-- ---------------------------------------------------------------
-- CAPTURE THE ADDRESS, DO NOT DEDUCE IT
-- ---------------------------------------------------------------
-- `torch_call` selects its compiled routine with `ldx a,x` off one of three dispatch
-- tables, then `ldy t_peel`. A read-tap on a TABLE therefore fires exactly on that kind of
-- call -- erase_tab for an erase, save_tab for a save -- which is the one moment when
-- "which operation is this" is unambiguous. `t_peel` is sampled there, so the recorded
-- address is the one that call will use.
--
-- Both tables are watched, because the discriminating comparison is erase-vs-save FOR THE
-- SAME SLOT: the save lands in the right range (9022 writes), so if the erase's t_peel
-- differs from the save's, that difference IS the defect. Deducing it from one side would
-- assume the other.
--
-- ---------------------------------------------------------------
-- THE CONTROL RUNS FIRST AND MUST CHANGE THE OUTPUT (P_SEED=1)
-- ---------------------------------------------------------------
-- P3.48b built a discriminator, got a clean answer, and then found that disabling the
-- mechanism entirely produced the SAME reading -- the probe could not see what it claimed
-- to measure. So this probe is not trusted until its seeded failure is demonstrated.
--
-- The seed turns `torch_step`'s `beq ts_nosave` into `bra`, so the erase never runs. The
-- probe MUST then report zero erase dispatches while the save count is unchanged. If it
-- does not, the probe is rejected rather than its reading believed.
--
-- The gate is located by INSTRUCTION PATTERN (`lda t_prev` = B6 <t_prev>, take the branch
-- after it), not by a byte offset from torch_step -- counting lengths put it 13 bytes
-- early on the first attempt, and the guard refused to patch the operand it landed on.
local OUT       = os.getenv("P_OUT")       or "build/erase_addr.log"
local ERASE_TAB = tonumber(os.getenv("P_ERASETAB") or "0x3024")
local SAVE_TAB  = tonumber(os.getenv("P_SAVETAB")  or "0x3012")
local TAB_LEN   = 18                       -- 9 cels x 2 bytes
local TPEEL     = tonumber(os.getenv("P_TPEEL")    or "0x22BE")
local TPREV     = tonumber(os.getenv("P_TPREV")    or "0x22C1")
local FLSLOT    = tonumber(os.getenv("P_FLSLOT")   or "0x229A")
local PEELBASE  = tonumber(os.getenv("P_PEELBASE") or "0x22C2")
local PEELSZ    = tonumber(os.getenv("P_PEELSZ")   or "26")
local TORCHSTEP = tonumber(os.getenv("P_TORCHSTEP") or "0x2144")
local SEED      = (os.getenv("P_SEED") or "0") ~= "0"
local FIRST     = tonumber(os.getenv("P_FIRST") or "1900")
local LAST      = tonumber(os.getenv("P_LAST")  or "3400")

local scr = manager.machine.screens:at(1)
local mem = manager.machine.devices[":maincpu"].spaces["program"]
local f   = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end

local state, t0 = "boot", nil
local armed, cur_frame = false, 0
local seeded, seed_err = false, nil
-- seen[kind][base] = { [t_peel] = count }
local seen = { erase = {}, save = {} }
local n    = { erase = 0, save = 0 }

local function which_slot(addr)
    if addr < PEELBASE then return "below peel_base" end
    local off = addr - PEELBASE
    local s = off // PEELSZ
    if s > 3 then return string.format("beyond slot 3 (+%d)", off) end
    if off % PEELSZ ~= 0 then return string.format("slot %d +%d (MISALIGNED)", s, off % PEELSZ) end
    return string.format("slot %d", s)
end

local function tab_tap(base, kind)
    return mem:install_read_tap(base, base + TAB_LEN - 1, "tab_" .. kind, function(off, data, mask)
        if armed and cur_frame >= FIRST and cur_frame <= LAST then
            local peel = mem:read_u8(TPEEL) * 256 + mem:read_u8(TPEEL + 1)
            local b    = mem:read_u8(FLSLOT)
            seen[kind][b] = seen[kind][b] or {}
            seen[kind][b][peel] = (seen[kind][b][peel] or 0) + 1
            n[kind] = n[kind] + 1
        end
        return data
    end)
end
_G._et = tab_tap(ERASE_TAB, "erase")
_G._st = tab_tap(SAVE_TAB,  "save")

-- ARTEFACT TEST (P3.49): P3.48's proof installed ~13 taps and reported slot 3's peel range
-- as read ZERO times. This tool has two taps and shows the erase dispatching against
-- exactly that range. Re-install the SAME slot-3 read/write tap here: if it fires with few
-- taps installed and not with many, the P3.48 reading was a tap-population artefact and
-- not a defect in the engine.
local sr, sw = {0,0,0,0}, {0,0,0,0}
for s = 0, 3 do
    local lo, hi, i = PEELBASE + s * PEELSZ, PEELBASE + (s+1) * PEELSZ - 1, s + 1
    _G["_sr" .. s] = mem:install_read_tap(lo, hi, "sr" .. s, function(off, data, mask)
        if armed and cur_frame >= FIRST and cur_frame <= LAST then sr[i] = sr[i] + 1 end
        return data
    end)
    _G["_sw" .. s] = mem:install_write_tap(lo, hi, "sw" .. s, function(off, data, mask)
        if armed and cur_frame >= FIRST and cur_frame <= LAST then sw[i] = sw[i] + 1 end
        return data
    end)
end

local function find_gate()
    for a = TORCHSTEP, TORCHSTEP + 40 do
        if mem:read_u8(a) == 0xB6
           and mem:read_u8(a + 1) * 256 + mem:read_u8(a + 2) == TPREV then
            return a + 3
        end
    end
    return nil
end

local function seed_break()
    local gate = find_gate()
    if not gate then
        seed_err = string.format("no `lda t_prev` ($B6 $%04X) in $%04X..+40", TPREV, TORCHSTEP)
        return false
    end
    local op = mem:read_u8(gate)
    if op ~= 0x27 then
        seed_err = string.format("$%04X holds $%02X, expected $27 (BEQ) — NOT PATCHING", gate, op)
        return false
    end
    mem:write_u8(gate, 0x20)
    log(string.format("# SEEDED: $%04X $27 -> $20 (BEQ->BRA); the erase is disabled", gate))
    return true
end

local function report()
    log(string.format("# ERASE ADDRESS PROBE   mode=%s", SEED and "SEEDED (erase disabled)" or "REAL"))
    log(string.format("# erase_tab $%04X  save_tab $%04X  t_peel $%04X  fl_slot $%04X  peel_base $%04X",
                      ERASE_TAB, SAVE_TAB, TPEEL, FLSLOT, PEELBASE))
    log(string.format("# sampled frames %d..%d", FIRST, LAST))
    log(string.format("# dispatches: erase %d, save %d", n.erase, n.save))
    for _, kind in ipairs({ "save", "erase" }) do
        local bases = {}
        for b in pairs(seen[kind]) do bases[#bases + 1] = b end
        table.sort(bases)
        for _, b in ipairs(bases) do
            local addrs = {}
            for a in pairs(seen[kind][b]) do addrs[#addrs + 1] = a end
            table.sort(addrs)
            for _, a in ipairs(addrs) do
                log(string.format("#   %-5s  fl_slot base %d  t_peel $%04X  = %-22s  x%d",
                                  kind, b, a, which_slot(a), seen[kind][b][a]))
            end
        end
    end
    log("# RANGE TAPS, same run as the dispatch capture above:")
    for s = 0, 3 do
        log(string.format("#   slot %d  $%04X..$%04X  writes %6d  reads %6d",
                          s, PEELBASE + s * PEELSZ, PEELBASE + (s+1) * PEELSZ - 1, sw[s+1], sr[s+1]))
    end
    if SEED then
        if n.erase == 0 and n.save > 0 then
            log("# CONTROL PASSED: the seed drove erase dispatches to 0 while saves continued.")
            log("#   The probe registers the difference it claims to measure.")
        else
            log("# CONTROL FAILED: the probe did not register the seeded failure — its clean")
            log("#   reading would be worthless. Reject this probe (P3.48b).")
        end
    end
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
            if SEED and not seeded then
                seeded = true
                if not seed_break() then log("# SEED ABORTED: " .. seed_err); manager.machine:exit(); return end
            end
            armed, state = true, "watch"
        end
        return
    end
    if fn > LAST then report(); manager.machine:exit() end
end

_G._notifier = emu.add_machine_frame_notifier(tick)
