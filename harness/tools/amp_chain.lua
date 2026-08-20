-- amp_chain.lua — P4.43: where does the port's amplitude get small?
--
-- ★★★ THE NARROW QUESTION LEFT BY P4.42. On s_Princess the oracle's pulse widths run
-- 7.8-76.3 us (mean 16.2); the port's run 8.4-22.3 (mean 21.3). The port's mean is HIGHER
-- and its ceiling 3.4x LOWER -- it is saturating, and a 22.3 us pulse is only about eight
-- iterations of the 5-cycle spin where matching 76.3 us needs about twenty-seven.
--
-- The chain from envelope byte to emitted pulse is short [msys_player.s tb_widths]:
--
--     envelope value -> voice_apply (the MVOLTBL/MVT2 opcode transform) -> VS_AMP
--     VTBL+1 = amp/2 + 1     VTBL+3 = amp + amp/2 + 1
--     VTBL+2 = amp   + 1     VTBL+4 = amp*2   + 1
--     then scale_widths multiplies each by MSYS_WIDTH_NUM/4 and CLAMPS at 255
--
-- ★★ SO THE CLAMP IS NOT THE CULPRIT -- it saturates at 255, which is a 712 us pulse, and
-- nothing observed comes near it. Either VS_AMP arrives small, or the arithmetic above it
-- does. This reads BOTH ends of the chain on the running machine and lets them say which.
--
--   VS_AMP small        -> the fault is upstream: voice_apply or the envelope value
--   VS_AMP fine, VTBL+4 small -> the fault is the width arithmetic or the scaling
--
-- ★ Addresses are DERIVED, not guessed: msys_v1 is $0EBE in build/obj/msys.map and the
-- offsets are msys_player.s's own equs -- VS_AMP 12, VS_VTBL 22. Both are passed in, since
-- P4.29 moved a symbol under a tool that had one hard-coded and it reported zeroes.
local OUT  = os.getenv("P_OUT")  or "build/tmp/amp_chain.log"
local IDX  = tonumber(os.getenv("P_IDX")  or "0EB7", 16)
local V1   = tonumber(os.getenv("P_V1")   or "0EBE", 16)
local WIN  = tonumber(os.getenv("P_WIN")  or "6.0")
local AMP  = V1 + 12
local VT4  = V1 + 22 + 4
local VT2  = V1 + 22 + 2

local mem = manager.machine.devices[":maincpu"].spaces["program"]
local nk  = manager.machine.natkeyboard
nk.in_use = true
local scr = manager.machine.screens:at(1)
local function now() return manager.machine.time:as_double() end

local armed, t0 = false, nil
local hamp, hv4, hv2 = {}, {}, {}
local n = 0

_G._tc = mem:install_write_tap(IDX, IDX, "cue", function(o, d, m)
    if d == 7 and not armed then armed, t0 = true, now() end
    return d
end)

-- VTBL+4 is written once per tick, AFTER the amplitude and the arithmetic. Sampling the
-- whole chain there gives one consistent snapshot rather than three unrelated ones.
_G._t4 = mem:install_write_tap(VT4, VT4, "vt4", function(o, d, m)
    if not armed or now() - t0 > WIN then return d end
    n = n + 1
    hv4[d] = (hv4[d] or 0) + 1
    local a = mem:read_u8(AMP); hamp[a] = (hamp[a] or 0) + 1
    local b = mem:read_u8(VT2); hv2[b] = (hv2[b] or 0) + 1
    return d
end)

local function dump(f, title, h, note)
    local keys = {}
    for k in pairs(h) do keys[#keys + 1] = k end
    table.sort(keys)
    local peak = 0
    for _, k in ipairs(keys) do if h[k] > peak then peak = h[k] end end
    f:write(string.format("## %s%s\n", title, note or ""))
    for _, k in ipairs(keys) do
        f:write(string.format("  %4d %-34s %6d\n", k,
                string.rep("#", math.floor(34 * h[k] / math.max(1, peak))), h[k]))
    end
    f:write("#\n")
end

local done = false
_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if done then return end
    if fn == 300 then nk:post('LOADM"INTROSEQ"\n') end
    if fn == 1200 then nk:post('EXEC\n') end
    if fn < 9600 then return end
    done = true
    local f = io.open(OUT, "w")
    f:write("# the port's amplitude chain during s_Princess, sampled once per tick at the\n")
    f:write(string.format("# write of VTBL+4 ($%04X). VS_AMP $%04X, VTBL+2 $%04X.\n#\n", VT4, AMP, VT2))
    if n < 32 then
        f:write(string.format("# only %d samples — INCONCLUSIVE.\n", n))
        f:close(); manager.machine:exit(); return
    end
    f:write(string.format("  ticks sampled  %d\n#\n", n))
    dump(f, "VS_AMP", hamp, "   (the amplitude the envelope produced)")
    dump(f, "VTBL+2", hv2, "   (= amp + 1, then scaled)")
    dump(f, "VTBL+4", hv4, "   (= amp*2 + 1, then scaled -- the WIDEST entry)")
    f:write("# ★ A 22.3 us pulse is about 8 spin iterations; matching the oracle's 76.3 us\n")
    f:write("# needs about 27. If VTBL+4 tops out near 8 then the chain is doing what it was\n")
    f:write("# told and VS_AMP is the small quantity; if VS_AMP is healthy and VTBL+4 is not,\n")
    f:write("# the arithmetic or the scaling is losing it.\n")
    f:close()
    manager.machine:exit()
end)
