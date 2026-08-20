-- oracle_pstand_lead.lua — P4.26 recon: how long does the ORACLE hold before s_Princess?
--
-- ★★★ THE QUESTION, AND WHY IT DECIDES SOMETHING. The port's cutscene reveals its room 45
-- frames before its music starts. P4.26 established that this is not a defect in the
-- loading: it is the scene's FIRST BEAT playing -- `cel_plan.s` beat 0 is `Pstand, plays 7,
-- song 0`, the cue lives on beat 1, `cad_tab` is a flat 6 frames per step, and the deferred
-- switch puts beat 1 on step 8. 8 x 6 = 48 predicted against 45 measured.
--
-- The port's PLAN is derived from the oracle's own script by bake_scene.py, so the SHAPE
-- (a silent Pstand before the cue) should be the oracle's too. What is NOT derived is the
-- RATE: `cad_tab` is the port's step cadence, and P3.87 measured the port's animation
-- running ~19% slow against the oracle -- a slip Jay closed by DECISION rather than by a
-- fix, explicitly refusing a drift-free `vm_due`.
--
--   if the oracle's lead is ~45 frames   the port is faithful and there is nothing to close
--   if the oracle's lead is much shorter the residual is P3.87's accepted pace, surfacing
--                                        at the one place a silent beat precedes a cue
--
-- ★★ SO THIS MEASURES ONE INTERVAL AND REPORTS IT NEXT TO THE PORT'S. Nothing is inferred
-- about which answer is wanted.
--
-- ---------------------------------------------------------------------------
-- THE TWO TAPS, AND WHY EACH ONE IS LEGAL ON A 6502
-- ---------------------------------------------------------------------------
-- ★★★ [mame-idioms-apple2e-oracle.md §1] 6502 read-taps on CODE addresses silently
-- false-0 through the opcode-fetch bypass. Both taps here are on DATA/IO, which is exactly
-- why P4.4's $C030 speaker tap and P4.7's $031A song tap both work.
--
--   THE CUE   `musicon` $031A. `PlaySongI` reads it four instructions in, with the song
--             number already in Y (`tay` two instructions earlier). One read, one event,
--             carrying WHICH and WHEN -- the same technique oracle_song_ids.lua proved.
--             $031A HAS OTHER READERS, so every PC is reported as a histogram rather than
--             filtered silently: a filter you cannot see is a filter you cannot check.
--
--   THE PAGE  $C054/$C055, the hires page-select soft switches. These are I/O, not code,
--             and touching one is how the Apple II reveals a finished page -- the oracle's
--             equivalent of the port's room_present. Both READ and WRITE forms are tapped
--             because either access works the switch on this machine and assuming one is
--             how an instrument comes back empty and reads as "it never happened".
--
-- ---------------------------------------------------------------------------
-- THE ANCHOR: PlayCut0's OWN MARKER, ARMED ON THE **WRITE**
-- ---------------------------------------------------------------------------
-- ★ oracle_scene.lua's `princess` INDEX entry reaches this point by waiting for SPEED
-- ($030C, MASTER.LST:530) to read 12 -- PlayCut0's first marker, and the same anchor
-- P4.23's oracle column used, so the numbers below are directly comparable with it.
--
-- ★★ BUT THIS ARMS ON THE **WRITE**, NOT ON THE VALUE, WHICH IS THAT FILE'S OWN P4.9
-- LESSON APPLIED ONE ENTRY OVER. Its `demo` entry records that waiting for a VALUE fired at
-- frame 8 on uninitialised RAM that happened to hold the right number, and reported PASS
-- from a machine that had not finished booting -- "a value read before anything wrote it is
-- not a measurement". `princess` still waits on the value; a write tap costs the same and
-- cannot do that.
--
-- ★★★ AND NOT THE SAVE STATE, WHICH DOES NOT COMPOSE WITH -autoboot_script. Measured here:
-- with `-state princess` the script does not run AT ALL -- no log, no error, exit 0 -- while
-- the identical command without it runs fine and installs every tap. That is a silent
-- no-op of exactly the shape this project keeps getting bitten by, so it is recorded in
-- mame-idioms-apple2e-oracle.md rather than left as a puzzle for the next dispatch.
-- Booting to the arm costs ~45 s emulated, which is ~4 s of wall clock at 1200%.
local OUT   = os.getenv("P_OUT") or "build/tmp/oracle_pstand_lead.log"
local SECS  = tonumber(os.getenv("P_SECS") or "12")  -- seconds after the arm

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)

local SPEED   = 0x030C          -- MASTER.LST:530 — PlayCut0's marker
local MUSICON = 0x031A          -- GAMEEQ.S:536
local PAGE1   = 0xC054
local PAGE2   = 0xC055

-- SOUNDNAMES.S, the CUTSCENE set. ids overlap between sets; these are PlayCut0's.
local NAME = { [7] = "s_Princess", [8] = "s_Squeek", [9] = "s_Vizier",
               [10] = "s_Buildup", [11] = "s_Magic", [12] = "s_StTimer" }

local f0 = nil                  -- the frame the run starts (== the arm)
local cues, ncue = {}, 0
local flips, nflip = {}, 0
local pcs = {}

local function fn() return scr:frame_number() end

local function note_flip(which, how)
    if f0 == nil then return end
    if nflip >= 40 then return end
    nflip = nflip + 1
    flips[nflip] = { f = fn() - f0, which = which, how = how }
end

_G._tm = mem:install_read_tap(MUSICON, MUSICON, "mon", function(off, data, mask)
    if f0 == nil then return data end
    local pc = cpu.state["PC"].value
    pcs[pc] = (pcs[pc] or 0) + 1
    -- ★ ONLY THE REAL PlaySongI. $031A has other readers -- P4.26b's histogram showed
    -- $E479 firing once against $0CAE 292 times (the play loop, Y=100/255). The histogram
    -- below still reports every PC unfiltered, so this filter is visible and checkable.
    if pc ~= 0xE479 then return data end
    if ncue < 40 then
        ncue = ncue + 1
        cues[ncue] = { f = fn() - f0, pc = pc, y = cpu.state["Y"].value }
    end
    return data
end)

_G._t1r = mem:install_read_tap(PAGE1, PAGE1, "p1r", function(o, d, m) note_flip(1, "r"); return d end)
_G._t2r = mem:install_read_tap(PAGE2, PAGE2, "p2r", function(o, d, m) note_flip(2, "r"); return d end)
_G._t1w = mem:install_write_tap(PAGE1, PAGE1, "p1w", function(o, d, m) note_flip(1, "w"); return d end)
_G._t2w = mem:install_write_tap(PAGE2, PAGE2, "p2w", function(o, d, m) note_flip(2, "w"); return d end)

-- THE ARM. A write of 12 to SPEED is PlayCut0 announcing itself; nothing else can set f0.
-- ★★ SPEED WRITES ARE PlayCut0's OWN PUNCTUATION, AND THEY BOUND THE SONG BLOCKS EXACTLY.
-- `PlaySongI` BLOCKS while the music plays, and the oracle's very next act after s_Squeek is
-- `lda #7 / sta SPEED` -- so that write IS the frame the block ended. Measuring the boundary
-- beats deriving it from a frames-per-play estimate, which is what the existing song rows in
-- bake_scene.PLAN had to do (761 and 358 were both "measured interval minus N plays at ~6 f").
local speeds, nsp = {}, 0
_G._ts = mem:install_write_tap(SPEED, SPEED, "speed", function(o, d, m)
    if f0 == nil and d == 12 then f0 = fn(); return d end
    if f0 ~= nil and nsp < 40 then
        nsp = nsp + 1
        speeds[nsp] = { f = fn() - f0, v = d }
    end
    return d
end)

local done = false
_G._n = emu.add_machine_frame_notifier(function()
    if done then return end
    if f0 == nil then return end                -- not armed yet: still booting to PlayCut0
    if fn() - f0 < SECS * 60 then return end
    done = true

    local f = io.open(OUT, "w")
    f:write("# the ORACLE's lead-in: PlayCut0's arm -> the first cutscene song.\n")
    f:write("# frame 0 = the princess save state's resume point, which IS the arm\n")
    f:write("# (SPEED $030C == 12). Same anchor P4.23's oracle column used.\n#\n")

    f:write("# --- hires page-select touches ($C054/$C055) ---------------------\n")
    if nflip == 0 then
        f:write("#   none in the window. The page was already selected before the arm.\n")
    else
        for i = 1, nflip do
            f:write(string.format("  frame %5d   page %d  (%s)\n",
                    flips[i].f, flips[i].which, flips[i].how == "r" and "read" or "write"))
        end
    end

    f:write("#\n# --- song cues ($031A read, id in Y) -----------------------------\n")
    local first_princess = nil
    for i = 1, ncue do
        local nm = NAME[cues[i].y] or string.format("id %d", cues[i].y)
        f:write(string.format("  frame %5d   %-12s  (Y=%2d, PC=$%04X)\n",
                cues[i].f, nm, cues[i].y, cues[i].pc))
        if cues[i].y == 7 and first_princess == nil then first_princess = cues[i].f end
    end
    if ncue == 0 then f:write("#   NONE — the tap never fired; treat as INCONCLUSIVE.\n") end

    f:write("#\n# --- PC histogram for the $031A tap (unfiltered) -----------------\n")
    for pc, c in pairs(pcs) do
        f:write(string.format("#   $%04X  x%d\n", pc, c))
    end

    f:write("#\n# --- SPEED writes: PlayCut0's punctuation, which bounds each block ---\n")
    for i = 1, nsp do
        f:write(string.format("  frame %5d   SPEED = %d\n", speeds[i].f, speeds[i].v))
    end

    f:write("#\n")
    if first_princess then
        f:write(string.format("  ORACLE  arm -> s_Princess = %d frames = %.2f s\n",
                first_princess, first_princess / 60.0))
        f:write("  PORT    room revealed -> s_Princess = 45 frames = 0.75 s  (reveal_vs_cue.lua)\n")
        f:write("  PORT    beat 0 = Pstand x7 plays at cad_tab 6 = 42 frames by construction\n#\n")
        if first_princess >= 30 then
            f:write("# READS AS: the oracle holds a comparable lead. The port's 45 frames are\n")
            f:write("# the same silent first beat, and the port is faithful here.\n")
        else
            f:write("# READS AS: the oracle's lead is SHORTER than the port's. The port's extra\n")
            f:write("# frames are its own step rate (cad_tab 6), i.e. P3.87's accepted pace --\n")
            f:write("# NOT the loading, and NOT beat 0's existence.\n")
        end
    else
        f:write("# s_Princess (Y=7) never fired in the window — INCONCLUSIVE.\n")
    end
    f:close()
    manager.machine:exit()
end)
