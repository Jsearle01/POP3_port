-- harness/tools/drive_probe.lua — P5.22: run drive_probe.s and log what drive 1 (and drive 0) did.
-- LAUNCH PATH: poke. A hardware-behaviour measurement, not a gate.
local BIN, OUT = os.getenv("P_BIN"), os.getenv("P_OUT")
local ENTRY = 0x3000
local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local f = io.open(OUT, "w")
local state, f0 = "boot", 0

local function poke_decb()
    local fh = io.open(BIN, "rb"); local d = fh:read("*a"); fh:close()
    local p = 1
    while p <= #d do
        local t = d:byte(p)
        local len = d:byte(p + 1) * 256 + d:byte(p + 2)
        local addr = d:byte(p + 3) * 256 + d:byte(p + 4)
        if t == 0xFF then return end
        for i = 0, len - 1 do mem:write_u8(addr + i, d:byte(p + 5 + i)) end
        p = p + 5 + len
    end
end

_G._dp_n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if state == "boot" then
        if fn < 300 then return end
        poke_decb()
        mem:write_u8(ENTRY + 3, 0)
        cpu.state["PC"].value = ENTRY
        state, f0 = "run", fn
    elseif state == "run" then
        if mem:read_u8(ENTRY + 3) == 1 then
            local hex = {}
            for i = 0, 63 do hex[#hex + 1] = string.format("%02X", mem:read_u8(ENTRY + 7 + i)) end
            f:write(string.format("RES %d %s\n", fn - f0, table.concat(hex)))
            f:close()
            state = "done"
            manager.machine:exit()
        elseif fn - f0 > 60 * 60 then
            f:write(string.format("TIMEOUT PC=$%04X\n", cpu.state["PC"].value))
            f:close()
            state = "done"
            manager.machine:exit()
        end
    end
end)
