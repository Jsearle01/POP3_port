-- harness/tools/torch_slot_proof.lua
--
-- POP P3.48 — PROVE the torch's four-slot peel discipline OPERATES.
--
-- ---------------------------------------------------------------
-- WHY A GREEN SUITE IS NOT THE EVIDENCE HERE
-- ---------------------------------------------------------------
-- From P3.17 to P3.48 `fl_buf` was pinned at 0 (its only write sat below an `rts`), so
-- `fl_slot` was always 0: both buffers shared slots 0-1, slots 2-3 were never touched,
-- and every erase restored into the twin of the buffer it was saved from. THE SUITE WAS
-- GREEN THROUGHOUT. It stayed green because the room beneath the torches is static and
-- identical in both buffers, so copying background between twins almost always wrote the
-- right bytes.
--
-- A check that was green while the property was absent cannot demonstrate the property is
-- present. So this tool does not look for the absence of failure; it observes the
-- mechanism directly and asserts the property positively.
--
-- ---------------------------------------------------------------
-- THE TWO THINGS PROVEN, AND HOW
-- ---------------------------------------------------------------
-- 1. PARITY AGREES WITH THE HAL, EVERY FRAME. `flicker` now derives its slot base from
--    HAL_gfx_cur_back. A WRITE-tap on `fl_slot` catches each derivation at the instant it
--    happens and reads HAL_gfx_cur_back in the same breath, so the two are compared at the
--    point of use rather than reconstructed afterwards. The invariant asserted is
--        fl_slot == (HAL_gfx_cur_back AND 1) * 2
--    and any frame that violates it is counted and reported, not averaged away.
--
-- 2. ALL FOUR SLOTS ARE LIVE — WRITTEN *AND* READ. Each slot owns PEEL_BYTES of peel
--    buffer at peel_base + slot*PEEL_BYTES. A write-tap over each range counts the SAVE
--    (background captured into that slot); a read-tap counts the ERASE (that background
--    read back out). Both are needed: a slot that is written and never read is not
--    participating in a restore, which is the property the :363 comment is about.
--
--    NOTE ON READ-TAPS (idioms 10a): a read-tap hit is not proof of EXECUTION, because it
--    also fires on data reads. Here the data read IS the thing being measured — the peel
--    buffer is data, and the erase reading it is exactly the event of interest — so the
--    caution does not apply. No hit is being treated as an instruction.
--
-- Slots 2 and 3 reading zero would mean the revival did not take (HARD-STOP #3), and is
-- reported as such rather than as a small number.
local OUT      = os.getenv("P_OUT")      or "build/torch_slot_proof.log"
local FLSLOT   = tonumber(os.getenv("P_FLSLOT")   or "0x2299")
local CURBACK  = tonumber(os.getenv("P_CURBACK")  or "0x7B8F")
local PEELBASE = tonumber(os.getenv("P_PEELBASE") or "0x22C1")
local PEELSZ   = tonumber(os.getenv("P_PEELSZ")   or "26")
local FIRST    = tonumber(os.getenv("P_FIRST")    or "1900")
local LAST     = tonumber(os.getenv("P_LAST")     or "3400")

local scr = manager.machine.screens:at(1)
local mem = manager.machine.devices[":maincpu"].spaces["program"]
local f   = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end

local state, t0 = "boot", nil
local armed, cur_frame = false, 0
local slot_seen  = {}                 -- fl_slot values written
local agree, disagree = 0, 0
local bad_examples = {}
local wr = {0, 0, 0, 0}               -- peel writes per slot (the SAVE)
local rd = {0, 0, 0, 0}               -- peel reads  per slot (the ERASE)

_G._slot_tap = mem:install_write_tap(FLSLOT, FLSLOT, "fl_slot", function(off, data, mask)
    if armed and cur_frame >= FIRST and cur_frame <= LAST then
        slot_seen[data] = (slot_seen[data] or 0) + 1
        local want = (mem:read_u8(CURBACK) & 1) * 2
        if data == want then
            agree = agree + 1
        else
            disagree = disagree + 1
            if #bad_examples < 6 then
                bad_examples[#bad_examples + 1] =
                    string.format("frame %d: fl_slot=%d but cur_back&1*2=%d", cur_frame, data, want)
            end
        end
    end
    return data
end)

for s = 0, 3 do
    local lo = PEELBASE + s * PEELSZ
    local hi = lo + PEELSZ - 1
    local idx = s + 1
    _G["_pw" .. s] = mem:install_write_tap(lo, hi, "peelw" .. s, function(off, data, mask)
        if armed and cur_frame >= FIRST and cur_frame <= LAST then wr[idx] = wr[idx] + 1 end
        return data
    end)
    _G["_pr" .. s] = mem:install_read_tap(lo, hi, "peelr" .. s, function(off, data, mask)
        if armed and cur_frame >= FIRST and cur_frame <= LAST then rd[idx] = rd[idx] + 1 end
        return data
    end)
end

-- DIAGNOSTIC (P3.48): the erase is gated on `t_prev`, which the caller loads from
-- fl_prev[slot]. A slot whose peel is written but never read means that gate never opened,
-- so watch fl_prev itself rather than reason about why.
local FLPREV = tonumber(os.getenv("P_FLPREV") or "0x229A")
local fpw, fpr = {0, 0, 0, 0}, {0, 0, 0, 0}
local fp_last = {-1, -1, -1, -1}
for s = 0, 3 do
    local idx = s + 1
    _G["_fpw" .. s] = mem:install_write_tap(FLPREV + s, FLPREV + s, "fpw" .. s, function(off, data, mask)
        if armed and cur_frame >= FIRST and cur_frame <= LAST then
            fpw[idx] = fpw[idx] + 1; fp_last[idx] = data
        end
        return data
    end)
    _G["_fpr" .. s] = mem:install_read_tap(FLPREV + s, FLPREV + s, "fpr" .. s, function(off, data, mask)
        if armed and cur_frame >= FIRST and cur_frame <= LAST then fpr[idx] = fpr[idx] + 1 end
        return data
    end)
end

-- fl_prev[3] turned out to be written AND read with a non-zero value, so the gate opens —
-- yet slot 3's peel is never read. The next thing between the gate and the peel is
-- `t_prev` itself, which torch_step tests. Sample it AT THE TEST, keyed by the live slot,
-- so the gate's actual input is observed rather than inferred from its source.
local TPREV = tonumber(os.getenv("P_TPREV") or "0x22C0")
local tp_zero, tp_nonzero = {0, 0, 0, 0}, {0, 0, 0, 0}
_G._tp_tap = mem:install_read_tap(TPREV, TPREV, "t_prev", function(off, data, mask)
    if armed and cur_frame >= FIRST and cur_frame <= LAST then
        -- fl_slot holds the BASE for this buffer; torch 1 uses base+1. Which torch we are
        -- in is not directly observable, so bucket by base and count both outcomes.
        local base = mem:read_u8(FLSLOT)
        local i = (base & 3) + 1
        if data == 0 then tp_zero[i] = tp_zero[i] + 1 else tp_nonzero[i] = tp_nonzero[i] + 1 end
    end
    return data
end)

local function report()
    log("# TORCH SLOT PROOF — does the four-slot discipline OPERATE?")
    log(string.format("# fl_slot $%04X  HAL_gfx_cur_back $%04X  peel_base $%04X  PEEL_BYTES %d",
                      FLSLOT, CURBACK, PEELBASE, PEELSZ))
    log(string.format("# sampled frames %d..%d", FIRST, LAST))

    local keys = {}
    for k in pairs(slot_seen) do keys[#keys + 1] = k end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = string.format("%d:%d", k, slot_seen[k]) end
    log(string.format("# fl_slot values written: %s   (pre-fix this was `0:<all>`)",
                      table.concat(parts, " ")))

    log(string.format("# PARITY vs HAL: agree %d, DISAGREE %d", agree, disagree))
    for _, e in ipairs(bad_examples) do log("#   " .. e) end
    if disagree == 0 and agree > 0 then
        log("# -> fl_slot == (HAL_gfx_cur_back AND 1)*2 on EVERY sampled frame.")
    end

    log("# peel slot activity (writes = the SAVE, reads = the ERASE):")
    local live = 0
    for s = 0, 3 do
        local i = s + 1
        local ok = (wr[i] > 0 and rd[i] > 0)
        if ok then live = live + 1 end
        log(string.format("#   slot %d  $%04X..$%04X  writes %6d  reads %6d  %s",
                          s, PEELBASE + s * PEELSZ, PEELBASE + s * PEELSZ + PEELSZ - 1,
                          wr[i], rd[i], ok and "LIVE" or "*** NOT LIVE ***"))
    end
    log(string.format("# %d of 4 slots are written AND read.", live))
    log("# t_prev AT THE GATE, bucketed by the frame's fl_slot base:")
    for b = 0, 3 do
        local i = b + 1
        if tp_zero[i] + tp_nonzero[i] > 0 then
            log(string.format("#   base %d : t_prev==0 (erase SKIPPED) %5d,  t_prev!=0 (erase RUNS) %5d",
                              b, tp_zero[i], tp_nonzero[i]))
        end
    end
    log("# fl_prev[] — the gate's source (0 = 'nothing drawn here yet', skip):")
    for s = 0, 3 do
        local i = s + 1
        log(string.format("#   fl_prev[%d] $%04X  writes %5d  reads %5d  last value $%02X",
                          s, FLPREV + s, fpw[i], fpr[i], fp_last[i] < 0 and 0 or fp_last[i]))
    end
    if live == 4 and disagree == 0 then
        log("# VERDICT: the four-slot discipline OPERATES.")
    else
        log("# VERDICT: NOT PROVEN — see the lines above.")
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
        if mem:read_u8(0x2008) > 0 then armed, state = true, "watch" end
        return
    end
    if fn > LAST then report(); manager.machine:exit() end
end

_G._notifier = emu.add_machine_frame_notifier(tick)
