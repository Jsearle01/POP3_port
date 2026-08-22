-- oracle_demo_bg.lua — P5.0: the DEMO LEVEL's first screen, as the oracle draws it.
--
-- Boots the oracle and waits for its OWN path into `Demo`, armed on the same condition
-- oracle_scene.lua uses: a WRITE to `level` after the machine has finished booting, not a
-- READ of its value (P4.9 reported a PASS off uninitialised RAM by reading one). Then runs
-- forward far enough for FirstFrame to have produced a screen, and takes three things:
--
--   * both HGR pages out of MAIN memory, raw, so a compositor can be diffed against them
--     BYTE FOR BYTE rather than eyeballed;
--   * the working blueprint out of AUX $B700, so "this is level 0" is a checked fact and
--     not an inference from the route taken to get here;
--   * a screenshot, which is what Jay looks at.
--
-- WHY NOT THE SAVE STATE. `-state demo_arrive` restores and MAME exits before the autoboot
-- script loads: no log, no error, exit 0. The full boot is ~110 emulated seconds and runs
-- at ~2500% here, so it costs about ten wall-clock seconds. Measured, not assumed — the
-- fast path was tried first and is what failed. [P5.0]
--
-- AUX IS REACHED THROUGH ITS OWN MEMORY SHARE, NOT THROUGH A SOFT SWITCH. Poking
-- $C005/$C003 from Lua would change the machine's state under the running game.
--
-- READS ARE mem:read_u8, NOT install_read_tap: on the 6502 a read tap silently false-0s
-- through the opcode-fetch bypass [mame-idioms-apple2e-oracle.md §1]. The WRITE tap used
-- for arming is unaffected by that.
--
--   P_AFTER  frames to run after arrival before dumping (default 400)
--   P_OUT    output prefix (default build/oracle_demo)
-- P_AFTER may be a COMMA LIST: one run, several dumps, each suffixed with its offset.
-- The demo plays itself and walks the kid off screen 1, so "which screen is showing" is a
-- function of WHEN you look; sampling several instants in one boot is far cheaper than
-- re-booting 110 emulated seconds per guess.
local AFTERS = {}
for tok in (os.getenv("P_AFTER") or "400"):gmatch("[^,]+") do
    AFTERS[#AFTERS + 1] = tonumber(tok)
end
table.sort(AFTERS)
local AFTER = AFTERS[#AFTERS]
local OUT   = os.getenv("P_OUT") or "build/oracle_demo"

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local log = io.open(OUT .. ".log", "w")
local function say(s) log:write(s .. "\n"); log:flush() end

local LEVEL  = 0x03F4        -- AUTO.LST:2796  `level ds 1`
local PARAMS = 0x03F0        -- MASTER.S:88    `params = $3f0` = bluepTRK/bluepREG
local SCRNUM = 0x0023        -- EQ.S `dum $18`: SCRNUM is the 12th byte -> $18+11
-- GAMEEQ.S `dum Kid` / `dum Op` / `dum Shad` — the three persistent character records.
-- Char ($0040) is the SCRATCH copy of whichever character is being processed, so it is
-- not what to read at an arbitrary instant; these three are.
local KID, OPP, SHAD = 0x0050, 0x039C, 0x0060
-- ★ SCRNUM IS A LOOP CURSOR, NOT A DISPLAY LATCH. `SUBS.S:1444-1449` counts it down over
-- every screen, so reading it at an arbitrary instant says where the WALK is, not what is
-- on the glass. VisScrn ($CB, GAMEEQ.S:469) is the source of truth: DoSure (TOPCTRL.S:942)
-- and DoFast (TOPCTRL.S:965) both do `lda VisScrn / sta SCRNUM`. P5.1 worked around this by
-- identifying the screen by MATCHING its pixels; the latch makes that unnecessary.
local VISSCRN = 0x00CB

local frames, done = 0, false
local arrived, nwrites = nil, 0

-- THE ARMING TAP. `level` is written by `StartGame`; the frame-count guard is what
-- separates the game writing it from power-on noise.
_G._tl = mem:install_write_tap(LEVEL, LEVEL, "lvl", function(off, data, mask)
    nwrites = nwrites + 1
    if not arrived and frames > 600 then arrived = frames end
    return data
end)

local function dump_main(path, lo, hi)
    local t = {}
    for a = lo, hi do t[#t + 1] = string.char(mem:read_u8(a)) end
    local f = io.open(path, "wb")
    if not f then return false end
    f:write(table.concat(t)); f:close()
    return true
end

-- AUX RAM. Enumerated rather than guessed: print what shares exist if the expected one is
-- absent, so a MAME-version rename is a legible failure and not a silent zero-fill.
local aux_share = nil
local function find_aux()
    if aux_share ~= nil then return aux_share end
    local shares = manager.machine.memory.shares
    aux_share = shares[":auxram"] or shares["auxram"] or false
    if not aux_share then
        say("# no auxram share. shares present:")
        for k, _ in pairs(shares) do say("#   " .. tostring(k)) end
    end
    return aux_share
end

local function dump_aux(path, lo, hi)
    local aux = find_aux()
    if not aux then return false end
    local t = {}
    for a = lo, hi do t[#t + 1] = string.char(aux:read_u8(a)) end
    local f = io.open(path, "wb")
    if not f then return false end
    f:write(table.concat(t)); f:close()
    return true
end

_G._n = emu.add_machine_frame_notifier(function()
    frames = frames + 1
    if done then
        if frames > done + 20 then log:close(); manager.machine:exit() end
        return
    end
    if not arrived then return end
    if frames == arrived then
        say(string.format("# ARRIVED at frame %d  level=%d  params=%d,%d  (%d writes)",
                          frames, mem:read_u8(LEVEL), mem:read_u8(PARAMS),
                          mem:read_u8(PARAMS + 1), nwrites))
    end
    for _, off in ipairs(AFTERS) do
        if frames == arrived + off then
            local sfx = (#AFTERS > 1) and ("_" .. off) or ""
            say(string.format("# DUMP at frame %d (+%d)  level=%d  SCRNUM=%d",
                              frames, off, mem:read_u8(LEVEL), mem:read_u8(SCRNUM))
                .. string.format("  VisScrn=%d", mem:read_u8(VISSCRN)))
            -- ★ THE ACTORS' POSITIONS, at the same instant as the pages (P5.5).
            -- P5.1 closed with an open flag: "the character residual in the screen-diff
            -- table is unseparated -- I cannot prove those bytes are characters rather
            -- than compositor error WITHOUT THE ACTORS' POSITIONS." This is that. The
            -- records are GAMEEQ.S's `dum Kid` / `dum Op` / `dum Shad` blocks, resolved
            -- by walking the `ds` chain from each `dum` base rather than by reading a
            -- number out of a report: Posn, X, Y, Face, BlockX, BlockY, Action, then
            -- (+11) Scrn and (+13) ID.
            for _, ch in ipairs({{"kid", KID}, {"op", OPP}, {"shad", SHAD}}) do
                local b = ch[2]
                say(string.format("#   %-4s posn=%3d x=%3d y=%3d face=%3d blk=%d,%d "
                                  .. "action=%d scrn=%3d id=%3d",
                                  ch[1], mem:read_u8(b), mem:read_u8(b + 1),
                                  mem:read_u8(b + 2), mem:read_u8(b + 3),
                                  mem:read_u8(b + 4), mem:read_u8(b + 5),
                                  mem:read_u8(b + 6), mem:read_u8(b + 11),
                                  mem:read_u8(b + 13)))
            end
            dump_main(OUT .. sfx .. "_hgr1.bin", 0x2000, 0x3FFF)
            dump_main(OUT .. sfx .. "_hgr2.bin", 0x4000, 0x5FFF)
            scr:snapshot(OUT .. sfx .. ".png")
            say("# -> " .. OUT .. sfx .. "_hgr{1,2}.bin + .png")
        end
    end
    if frames < arrived + AFTER then return end
    done = frames
end)
