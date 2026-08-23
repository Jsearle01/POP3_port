-- scene_fetch_probe.lua — P5.16: watch the scene program's cache fetch, byte by byte.
--
-- The intro reaches its last beat and the scene never runs, which means run_scene declined
-- — and run_scene declines when SCENE_BASE does not open with a JMP ($7E). Two things can
-- produce that and they need opposite fixes: the fetch never happened (tc_fetch returned
-- non-zero and the caller branched past both it and the preload), or the fetch happened and
-- copied the wrong bytes. Only memory can tell them apart.
--
-- Taps rather than samples, for the reason the load tracer already records: a copy that
-- starts and finishes inside one frame is invisible to per-frame sampling. A WRITE tap on
-- SCENE_BASE fires on the first byte the fetch lands there, whenever it lands.

local OUT = os.getenv("P_OUT") or "build/tmp/scene_fetch.txt"
local SCENE = tonumber(os.getenv("P_SCENE") or "0x2700")
local TC_TRK, TC_SEC, TC_BLK = 0x22BB, 0x22BC, 0x22BD
local TC_DST = 0x22C0
local PROBE_STATUS, PROBE_BEAT = 0x2003, 0x2004

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local out = io.open(OUT, "w")
local frame = 0
local function say(s) out:write(s .. "\n"); out:flush() end
local function rd(a) return mem:read_u8(a) end

-- every tc_fetch request, named by what it asked for
local reqs = {}
_G._t1 = mem:install_write_tap(TC_TRK, TC_TRK, "trk", function(off, data, mask)
    reqs[#reqs + 1] = { f = frame, trk = data & 0xFF, st = rd(PROBE_STATUS) }
end)
-- the first byte to land at SCENE_BASE, and what it was
local scene_writes = {}
_G._t2 = mem:install_write_tap(SCENE, SCENE, "scene", function(off, data, mask)
    if #scene_writes < 8 then
        scene_writes[#scene_writes + 1] = { f = frame, v = data & 0xFF }
    end
end)

say(string.format("# scene_fetch_probe — SCENE_BASE $%04X", SCENE))

-- ★ _G, or it is GC'd and silently stops firing [mame-idioms-coco3-port.md]
_G._n = emu.add_machine_frame_notifier(function()
    frame = frame + 1
    if frame == 300 then
        manager.machine.natkeyboard:post('LOADM"LOADER"\n')
    elseif frame == 801 then
        manager.machine.natkeyboard:post("EXEC\n")
    elseif frame == 9000 then
        say(string.format("# %d tc_fetch/tc_preload requests", #reqs))
        for _, r in ipairs(reqs) do
            say(string.format("    frame %6d  track %3d  probe_status %d", r.f, r.trk, r.st))
        end
        say("")
        if #scene_writes == 0 then
            say(string.format("# ★ NOTHING WAS EVER WRITTEN TO $%04X — "
                              .. "the fetch did not happen.", SCENE))
        else
            say(string.format("# first bytes written to $%04X:", SCENE))
            for _, w in ipairs(scene_writes) do
                say(string.format("    frame %6d  $%02X", w.f, w.v))
            end
        end
        say("")
        say(string.format("# NOW: $%04X..$%04X = %02X %02X %02X %02X %02X %02X",
                          SCENE, SCENE + 5, rd(SCENE), rd(SCENE + 1), rd(SCENE + 2),
                          rd(SCENE + 3), rd(SCENE + 4), rd(SCENE + 5)))
        say(string.format("# tc_trk=%d tc_sec=%d tc_blk=$%02X tc_dst=$%02X%02X",
                          rd(TC_TRK), rd(TC_SEC), rd(TC_BLK), rd(TC_DST), rd(TC_DST + 1)))
        say(string.format("# probe_status=%d probe_beat=%d",
                          rd(PROBE_STATUS), rd(PROBE_BEAT)))
        out:close()
        manager.machine:exit()
    end
end)
