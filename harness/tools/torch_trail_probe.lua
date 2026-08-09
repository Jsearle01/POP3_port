-- harness/tools/torch_trail_probe.lua
--
-- POP P3.48b — DOES BUFFER 1's TORCH 1 ACCUMULATE? A tap-free discriminator.
--
-- P3.48 measured slot 3 (buffer 1, torch 1) as written 347 times and read zero times,
-- while the erase gate demonstrably opened. Two explanations survived: a real erase-path
-- defect, or the read-tap failing to fire. Tap counts cannot settle a question about
-- taps, so this reads MEMORY instead and asks the question the defect would answer:
--
--     if buffer 1's torch 1 is never restored, its box accumulates flame pixels.
--
-- A correctly erased-and-redrawn torch box differs from the pristine room by ONE cel's
-- worth of pixels, and that difference does not grow. An unrestored one differs by the
-- UNION of every cel drawn there since the last erase, and grows until it saturates.
--
-- ---------------------------------------------------------------
-- HOW BOTH BUFFERS ARE READ
-- ---------------------------------------------------------------
-- The buffers are physical MMU blocks; only the back one is mapped at $8000 normally.
-- `map_blocks` writes $FFA4-$FFA7 to bring either into the window, exactly as
-- harness/smoke/room_test.lua's dump_front does (the verified idiom), and the back
-- buffer's mapping is restored immediately afterwards so the engine is undisturbed.
--
-- Sampled at two well-separated frames so GROWTH is visible, not just magnitude — a
-- single sample cannot distinguish "a big cel" from "an accumulating trail".
local OUT      = os.getenv("P_OUT")     or "build/torch_trail.log"
local CUR_BACK = tonumber(os.getenv("P_CURBACK") or "0x7B8F")
local BLOCK_A  = tonumber(os.getenv("P_BLK_A")   or "0x10")
local BLOCK_B  = tonumber(os.getenv("P_BLK_B")   or "0x14")
local FB_BASE  = 0x8000
local STRIDE   = 80
local TOP      = tonumber(os.getenv("P_FLAME_TOP") or "101")
local ROWS     = 13
local T0COL    = tonumber(os.getenv("P_T0COL") or "28")
local T1COL    = tonumber(os.getenv("P_T1COL") or "50")
local WIDTH    = 2
local SHOT1    = tonumber(os.getenv("P_SHOT1") or "2200")
local SHOT2    = tonumber(os.getenv("P_SHOT2") or "3300")

local scr = manager.machine.screens:at(1)
local mem = manager.machine.devices[":maincpu"].spaces["program"]
local f   = io.open(OUT, "w")
local function log(s) if f then f:write(s .. "\n"); f:flush() end end

local function map_blocks(first)
    for i = 0, 3 do mem:write_u8(0xFFA4 + i, first + i) end
end

-- One torch box out of whichever buffer is currently mapped.
local function grab_box(col)
    local t = {}
    for r = 0, ROWS - 1 do
        for c = 0, WIDTH - 1 do
            t[#t + 1] = string.format("%02X", mem:read_u8(FB_BASE + (TOP + r) * STRIDE + col + c))
        end
    end
    return table.concat(t)
end

local function sample(tag)
    local back = mem:read_u8(CUR_BACK)
    local back_blk = (back == 0) and BLOCK_A or BLOCK_B
    for _, which in ipairs({ {"A", BLOCK_A}, {"B", BLOCK_B} }) do
        map_blocks(which[2])
        log(string.format("%s buf%s torch0 %s", tag, which[1], grab_box(T0COL)))
        log(string.format("%s buf%s torch1 %s", tag, which[1], grab_box(T1COL)))
    end
    map_blocks(back_blk)          -- leave the engine exactly as it was
    log(string.format("# %s: cur_back=%d (back block $%02X)", tag, back, back_blk))
end

-- SEEDED-FAILURE CONTROL (P_SEED=1). A probe that has never been shown to FAIL is not
-- evidence when it passes — this project's peel suite earns its verdicts by being proven
-- to fail when seeded, and this probe had produced byte-identical output for two
-- different binaries, which demonstrates determinism and nothing about sensitivity.
--
-- The seed disables the erase outright: `torch_step` opens `lda t_prev / beq ts_nosave`,
-- so turning that BEQ ($27) into a BRA ($20) skips the restore on every call, for every
-- slot. If the probe cannot see THAT, it cannot see a missing restore on one slot either,
-- and its clean reading of the real build means nothing.
--
-- The opcode is verified before it is written; a mismatch aborts rather than patching a
-- byte whose meaning is assumed (the guard that saved P3.43 from a corrupted program).
local SEED      = (os.getenv("P_SEED") or "0") ~= "0"
local TORCHSTEP = tonumber(os.getenv("P_TORCHSTEP") or "0x2144")
local TPREV     = tonumber(os.getenv("P_TPREV") or "0x22C1")
local seeded, seed_err = false, nil

-- The gate is FOUND, not counted to. A byte offset from torch_step would go stale the
-- moment an instruction above it changed length -- and did on the first attempt: +3 landed
-- on the $8E of `ldy #ptorchflame`, and the guard refused rather than patching it. Scan
-- for `lda t_prev` (B6 <t_prev>) and take the BEQ that must follow it.
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
        seed_err = string.format("no `lda t_prev` ($B6 $%04X) in $%04X..$%04X", TPREV, TORCHSTEP, TORCHSTEP + 40)
        return false
    end
    local op = mem:read_u8(gate)
    if op ~= 0x27 then
        seed_err = string.format("$%04X holds $%02X, expected $27 (BEQ) — NOT PATCHING", gate, op)
        return false
    end
    mem:write_u8(gate, 0x20)                    -- BEQ -> BRA: the erase never runs
    log(string.format("# SEEDED: $%04X $27 -> $20 (BEQ->BRA); the erase is disabled", gate))
    return true
end

local state, t0, done1 = "boot", nil, false
local nk = manager.machine.natkeyboard
nk.in_use = true

local function tick()
    local fn = scr:frame_number()
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
            state = "watch"
        end
        return
    end
    if not done1 and fn >= SHOT1 then
        log(string.format("# geometry: top %d rows %d width %d  torch0 col %d  torch1 col %d",
                          TOP, ROWS, WIDTH, T0COL, T1COL))
        sample("shot1"); done1 = true
        return
    end
    if done1 and fn >= SHOT2 then
        sample("shot2")
        manager.machine:exit()
    end
end

_G._notifier = emu.add_machine_frame_notifier(tick)
