-- harness/tools/xform_probe.lua
--
-- POP P5.20 — run the transformed-blit probe and time every case off the BUILT BINARY.
--
-- ★ THE CYCLE COUNT IS THE DEBUGGER'S `totalcycles`, NOT A FRAME COUNT. mame-idioms-coco3
-- §0 records that Lua exposes no cycle counter; the debugger's expression evaluator does.
-- Under `-debug -debugger none` (headless; the probe unpauses it), a breakpoint before the
-- driver's `jsr` stores totalcycles in temp0 and one after it writes the difference into
-- RAM, where this script reads it. Calibrated before use on a hand-counted five-instruction
-- sequence (ldy/ldb/lda b,y/mul/nop = 24 cy): 24, eight times out of eight.
--
-- LAUNCH PATH: poke. A leaf-routine measurement, not a gate (CLAUDE.md §4 concerns hiding
-- load/launch bugs in gated behaviour; nothing here is a 25.3 observation).
local BIN  = os.getenv("P_BIN")
local SYMS = os.getenv("P_SYMS")
local OUT  = os.getenv("P_OUT")

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local f = io.open(OUT, "w")
local function log(s) f:write(s .. "\n"); f:flush() end

pcall(function() manager.machine.debugger.execution_state = "run" end)

local sym = {}
for line in io.lines(SYMS) do
    local name, val = line:match("^(%S+)%s+[Ee][Qq][Uu]%s+%$(%x+)")
    if name then sym[name] = tonumber(val, 16) end
end
for _, n in ipairs({"xp_entry", "xp_call", "xp_ret", "XP_STATUS", "XP_GO", "XP_CYC",
                    "XP_BUF", "XP_CASES"}) do
    if not sym[n] then log("# missing symbol " .. n); manager.machine:exit(); return end
end

local function poke_decb()
    local fh = io.open(BIN, "rb"); local d = fh:read("*a"); fh:close()
    local p, n, exec = 1, 0, nil
    while p <= #d do
        local t = d:byte(p)
        local len = d:byte(p + 1) * 256 + d:byte(p + 2)
        local addr = d:byte(p + 3) * 256 + d:byte(p + 4)
        if t == 0xFF then exec = addr; break end
        for i = 0, len - 1 do mem:write_u8(addr + i, d:byte(p + 5 + i)) end
        n = n + len
        p = p + 5 + len
    end
    return n, exec
end

local state, idx, t0 = "boot", 0, 0
local function tick()
    local fn = scr:frame_number()
    if state == "boot" then
        if fn < 100 then return end
        local n, exec = poke_decb()
        local dbg = cpu.debug
        dbg:bpset(sym.xp_call, "1", "temp0=totalcycles; go")
        dbg:bpset(sym.xp_ret, "1", string.format("pd@0x%X=totalcycles-temp0; go", sym.XP_CYC))
        mem:write_u8(sym.XP_STATUS, 0)
        mem:write_u8(sym.XP_GO, 0)
        cpu.state["PC"].value = exec
        log(string.format("# poked %d B, exec $%04X, call $%04X ret $%04X", n, exec, sym.xp_call, sym.xp_ret))
        state, t0 = "run", fn
        return
    end
    local st = mem:read_u8(sym.XP_STATUS)
    if st == 1 then
        local rec = sym.XP_CASES + 10 * idx
        local dlen = mem:read_u8(rec + 8) * 256 + mem:read_u8(rec + 9)
        local cyc = mem:read_u32(sym.XP_CYC)
        local hex = {}
        for i = 0, dlen - 1 do hex[#hex + 1] = string.format("%02X", mem:read_u8(sym.XP_BUF + i)) end
        log(string.format("C %d %d %s", idx, cyc, table.concat(hex)))
        idx = idx + 1
        mem:write_u8(sym.XP_STATUS, 0)
        mem:write_u8(sym.XP_GO, 1)
    elseif st == 2 then
        log("DONE " .. idx)
        manager.machine:exit()
    elseif fn - t0 > 20000 then
        log(string.format("# TIMEOUT at case %d, PC=$%04X", idx, cpu.state["PC"].value))
        manager.machine:exit()
    end
end
_G._xf_tick = emu.add_machine_frame_notifier(tick)
