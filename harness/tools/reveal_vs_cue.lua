-- reveal_vs_cue.lua — P4.25b: does the cutscene's PICTURE appear before its MUSIC, and by
-- how much?
--
-- ★★★ THE QUESTION THIS ANSWERS, AND WHY IT IS NOT THE ONE cue_times.lua ANSWERS.
-- cue_times reports each cue against the ORACLE's own call time, which is the right frame
-- for "is the port faithful". It cannot answer "what does the viewer experience", because
-- both of its anchors are in the port's own timeline and neither is the moment the picture
-- shows up. Jay asks whether the scene could be held back a second so the room and its
-- music arrive together -- and that is only worth doing if they are currently APART.
--
-- ★★ THE TWO EVENTS, AND BOTH ARE STATE WRITES RATHER THAN CONTROL FLOW (P4.24's rule):
--
--   REVEAL  the scene's own probe_status := 2 at SCENE_BASE+3. cutscene_room.s sets it in
--           room_ready, immediately after the second room_present -- so it is the first
--           instant the finished room is on the displayed page and the loop is about to
--           run. (The mirror is the true reveal and happens a few frames earlier still;
--           this is the conservative end of the interval, which is the safe direction: it
--           can only UNDER-state how early the picture is.)
--   CUE     the write of the song id to msys_index, which msys_play does first thing.
--
-- ★ A NEGATIVE ANSWER HERE (picture before music) MEANS A DELAY WOULD MAKE IT WORSE: it
-- would push the picture AND the cue back together and change nothing about their spacing.
local SCENE  = tonumber(os.getenv("P_SCENE") or "2500", 16)
local STATUS = SCENE + 3
local IDX    = tonumber(os.getenv("P_IDX") or "0EB7", 16)
local OUT    = os.getenv("P_OUT") or "build/tmp/reveal_vs_cue.log"
local FPS    = 59.92

local mem = manager.machine.devices[":maincpu"].spaces["program"]
local nk  = manager.machine.natkeyboard
nk.in_use = true
local scr = manager.machine.screens:at(1)

local reveal, cue, cue_id = nil, nil, nil

_G._tr = mem:install_write_tap(STATUS, STATUS, "reveal", function(o, d, m)
    if d == 2 and reveal == nil then reveal = scr:frame_number() end
    return d
end)

_G._tc = mem:install_write_tap(IDX, IDX, "cue", function(o, d, m)
    -- the cutscene's songs are ids 7..12; the intro's are 1..5, and 0 is a stop.
    if d >= 7 and cue == nil then cue, cue_id = scr:frame_number(), d end
    return d
end)

local state, t0, done = "boot", nil, false
_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if done then return end
    if state == "boot" then
        if fn >= 300 then nk:post('LOADM"LOADER"\n'); state, t0 = "loadm", fn end
        return
    end
    if state == "loadm" then
        if fn > t0 + 900 then nk:post('EXEC\n'); state = "run" end
        return
    end
    if (reveal == nil or cue == nil) and fn <= 7000 then return end
    done = true

    local f = io.open(OUT, "w")
    f:write("# the cutscene's picture against its music, both from state writes.\n#\n")
    f:write(string.format("# REVEAL  scene probe_status:=2 at $%04X\n", STATUS))
    f:write(string.format("# CUE     first cutscene song id written to msys_index $%04X\n#\n", IDX))
    if reveal == nil or cue == nil then
        f:write(string.format("# NO SAMPLE: reveal=%s cue=%s\n# VERDICT: INCONCLUSIVE\n",
                tostring(reveal), tostring(cue)))
    else
        f:write(string.format("  reveal   frame %d\n", reveal))
        f:write(string.format("  cue      frame %d   (song id %d)\n", cue, cue_id))
        local d = cue - reveal
        f:write(string.format("  delta    %d frames = %+.2f s\n#\n", d, d / FPS))
        if d > 0 then
            f:write("# the MUSIC is later than the PICTURE by the above.\n")
            f:write("# a delay before the reveal would CLOSE this gap.\n")
        else
            f:write("# the PICTURE is later than the music, or they coincide.\n")
            f:write("# ★ A DELAY BEFORE THE REVEAL WOULD NOT HELP: it moves both together.\n")
        end
    end
    f:close()
    manager.machine:exit()
end)
