-- harness/tools/side_read.lua — P5.22: drive side_read_probe.s and time every disk_read_range.
--
-- LAUNCH PATH: poke (a leaf measurement; nothing here is a 25.3 observation). Disk BASIC boots with
-- the authored side in drive 0 (-ext fdc), the linked probe's DECB segments are poked, PC is set.
--
-- TIMING is off WRITE TAPS on sr_status (2 = the read starts, 1/3 = it ends), stamped with the
-- emulated machine time and the frame number. A read is seconds long and frames are 16.69 ms, so
-- either is fine at this scale; both are logged.
local BIN  = os.getenv("P_BIN")
local OUT  = os.getenv("P_OUT")
local ENTRY = tonumber(os.getenv("P_ENTRY"))
local SR_BUF, TRACK = 0x2400, 4608

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local f = io.open(OUT, "w")
local function log(s) f:write(s .. "\n"); f:flush() end

local ST, GO, PTR = ENTRY + 3, ENTRY + 4, ENTRY + 6
local state, pending, t_start, f_start, t0 = "boot", nil, 0, 0, 0

local function now() return manager.machine.time:as_double() end

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

local function tick()
    local fn = scr:frame_number()
    if state == "boot" then
        if fn < 300 then return end
        poke_decb()
        mem:write_u8(ST, 0); mem:write_u8(GO, 0)
        _G._sr_tap = mem:install_write_tap(ST, ST, "sr", function(off, data, mask)
            local v = data & 0xFF
            if v == 2 then t_start, f_start = now(), scr:frame_number()
            elseif v == 1 or v == 3 then pending = {v, now() - t_start, scr:frame_number() - f_start}
            end
            return data
        end)
        cpu.state["PC"].value = ENTRY
        state, t0 = "run", fn
        log(string.format("# started at frame %d, entry $%04X", fn, ENTRY))
        return
    end
    if pending then
        local ptr = mem:read_u8(PTR) * 256 + mem:read_u8(PTR + 1)
        local trk, cnt = mem:read_u8(ptr), mem:read_u8(ptr + 1)
        local hex = {}
        for i = 0, cnt * TRACK - 1 do hex[#hex + 1] = string.format("%02X", mem:read_u8(SR_BUF + i)) end
        log(string.format("R %d %d %d %.6f %d %s", trk, cnt, pending[1], pending[2], pending[3], table.concat(hex)))
        pending = nil
        mem:write_u8(GO, 1)
    elseif mem:read_u8(ST) == 4 then
        log("DONE")
        manager.machine:exit()
    elseif fn - t0 > 60 * 300 then
        log(string.format("# TIMEOUT, status %d PC=$%04X", mem:read_u8(ST), cpu.state["PC"].value))
        manager.machine:exit()
    end
end
_G._sr_n = emu.add_machine_frame_notifier(tick)
