-- glass_vs_cue.lua — P4.32: where does the hourglass SOUND sit against the hourglass ANIMATION?
--
-- ★★★ JAY'S QUESTION, VERBATIM: "where is the hourglass drop sound in reference to the actual
-- hourglass animation". He has heard the scene with all six cues in it and wants the
-- relationship, not an assurance.
--
-- ---------------------------------------------------------------------------
-- THE THREE EVENTS, ALL FROM STATE, NONE FROM CONTROL FLOW
-- ---------------------------------------------------------------------------
-- The scene's beat schedule publishes the hourglass as PER-BEAT FLAGS in `vm_scenery`
-- ($4054 in the flame bundle), written once per beat by vb_apply from byte 5 of the row:
--
--   SC_GLASS0 $01   the glass BODY appears, state 0
--   SC_FLOW   $02   the sand runs, cycling flow0..flow2 one per play
--   SC_GLASS1 $04   the body switches to state 1
--   SC_FLASH  $08   `lda #5 / sta lightning` — the strobe over its arrival
--
-- So a write to vm_scenery IS the animation event: the frame SC_GLASS0 first appears is the
-- frame the glass starts being drawn, and SC_FLOW's first appearance is the frame the sand
-- starts running. The cue is msys_index ($0EB7), the same tap P4.23 proved and every
-- dispatch since has used.
--
-- ★★ 6809 READ-TAPS WORK HERE [mame-idioms-coco3-port.md §10] but all three of these are
-- WRITES, which is the stronger form: one event per state change, carrying the value.
--
-- ★ WHAT THE ORACLE DOES, for the comparison [SUBS.S:715-745]:
--       jsr addglass1      ;hourglass appears
--       ... sta SPEED ; jsr play
--       sta psandcount     ;sand starts flowing
--       lda #s_Magic / jsr PlaySongI
-- -- glass first, then a play, then the sand, and the cue LAST. This measures whether the
-- port reproduces that ORDER and with what spacing.
local OUT     = os.getenv("P_OUT") or "build/tmp/glass_vs_cue.log"
local IDX     = tonumber(os.getenv("P_IDX") or "0EB7", 16)
local SCEN    = tonumber(os.getenv("P_SCEN") or "4054", 16)
local DONEB   = 0xFE07                      -- cel_scene_done: the scene's own window

local mem = manager.machine.devices[":maincpu"].spaces["program"]
local nk  = manager.machine.natkeyboard
nk.in_use = true
local scr = manager.machine.screens:at(1)

local SC_GLASS0, SC_FLOW, SC_GLASS1, SC_FLASH = 0x01, 0x02, 0x04, 0x08

local ev, n = {}, 0
local scene0, prev = nil, nil

local function add(kind, detail)
    if n >= 60 then return end
    n = n + 1
    ev[n] = { f = scr:frame_number(), kind = kind, detail = detail }
end

_G._tc = mem:install_write_tap(IDX, IDX, "cue", function(o, d, m)
    if d >= 7 and d <= 12 then add("CUE", string.format("song id %d", d)) end
    return d
end)

local last_scen = nil
_G._tv = mem:install_write_tap(SCEN, SCEN, "scen", function(o, d, m)
    if last_scen ~= d then
        local bits = {}
        if d & SC_GLASS0 ~= 0 then bits[#bits+1] = "GLASS0" end
        if d & SC_FLOW   ~= 0 then bits[#bits+1] = "FLOW"   end
        if d & SC_GLASS1 ~= 0 then bits[#bits+1] = "GLASS1" end
        if d & SC_FLASH  ~= 0 then bits[#bits+1] = "FLASH"  end
        add("SCENERY", (#bits > 0) and table.concat(bits, "+") or "none")
        last_scen = d
    end
    return d
end)

local done = false
_G._n = emu.add_machine_frame_notifier(function()
    local fn = scr:frame_number()
    if done then return end
    if fn == 300 then nk:post('LOADM"INTROSEQ"\n') end
    if fn == 1200 then nk:post('EXEC\n') end
    local d = mem:read_u8(DONEB)
    if prev ~= nil and prev ~= 0 and d == 0 and scene0 == nil then scene0 = fn end
    prev = d
    if fn < 9200 then return end
    done = true

    local f = io.open(OUT, "w")
    f:write("# the hourglass ANIMATION against the hourglass SOUND.\n")
    f:write("# SCENERY = a write to vm_scenery, which is the per-beat flag the room draws\n")
    f:write("# the glass and the sand from. CUE = msys_play's write of the song id.\n#\n")
    f:write(string.format("# scene starts at frame %s; offsets below are from it.\n#\n",
            tostring(scene0)))
    local base = scene0 or 0
    for i = 1, n do
        f:write(string.format("  %+7.2f s   %-8s %s\n",
                (ev[i].f - base) / 59.92, ev[i].kind, ev[i].detail))
    end
    f:write("#\n")
    -- the relationship Jay asked for, stated rather than left to be read off
-- ★★★ ONLY EVENTS INSIDE THE SCENE COUNT, AND THE FIRST CUT OF THIS DID NOT CHECK.
-- vm_scenery lives in the flame bundle, which is ORDINARY RAM until the bundle is read and
-- expanded -- so before the scene it holds whatever was there, and this run logged FLOW and
-- FLASH events at -90 s, -19 s and -13 s from exactly that. Taking the FIRST FLOW without a
-- window picked up the garbage and reported "sand starts -> s_Magic: +131.02 s", which is
-- absurd on its face and was caught by being absurd. cel_load_startup's own comment warns
-- about this class for the constant page; it applies to the bundle's variables too.
    local g0, flow, magic = nil, nil, nil
    for i = 1, n do
        local e = ev[i]
        if scene0 == nil or e.f >= scene0 then
            if e.kind == "SCENERY" and g0 == nil and e.detail:find("GLASS0") then g0 = e.f end
            if e.kind == "SCENERY" and flow == nil and e.detail:find("FLOW") then flow = e.f end
            if e.kind == "CUE" and magic == nil and e.detail == "song id 11" then magic = e.f end
        end
    end
    if g0 and magic then
        f:write(string.format("  glass appears -> s_Magic :  %+.2f s\n", (magic - g0) / 59.92))
    end
    if flow and magic then
        f:write(string.format("  sand starts   -> s_Magic :  %+.2f s\n", (magic - flow) / 59.92))
    end
    f:write("#\n# ORACLE ORDER [SUBS.S:715-745]: addglass1 (glass) -> play -> psandcount\n")
    f:write("# (sand) -> PlaySongI (s_Magic). Glass first, cue LAST.\n")
    f:close()
    manager.machine:exit()
end)
