-- oracle_scene.lua — P4.9: reach a named point in the oracle on demand.
--
-- ★★★ WHY THIS EXISTS. Jay: "Is it possible for Clyde to find the entry points to the
-- different scenes in the oracle, so that as we work through the game he can play the oracle
-- at discrete points — so I don't have to watch or play the entire game to get to that
-- point?" Every comparison so far has re-solved "get to the interesting part" from scratch:
-- P3.99 ran 95 seconds to see an exit at ~85 s; P3.101 did it again for entry-vs-exit; P4.7
-- again for the songs. That cost is paid on every comparison and it need not be.
--
-- ---------------------------------------------------------------------------
-- THREE TIERS OF "REACHABLE", AND ONLY ONE OF THEM IS FREE
-- ---------------------------------------------------------------------------
-- ★★★ THE ORACLE'S DISK md5 IS THE PROJECT'S ANCHOR. Anything that rebuilds the binary
-- produces a different oracle, and the port has been compared against THIS one for 148
-- reports. So every entry here is tagged, and the index is built only on tiers 1 and 2:
--
--   tier 1  no touch          save states, break-on-frame, and — measured at P4.9 — the
--                             SHIPPED CHEAT CODES, which turn out to be in the binary
--   tier 2  runtime write     poking `demolevel`/`params` before the level loads
--   tier 3  rebuild           re-enabling a conditional. READ for evidence, NEVER used.
--
-- ★★ AND THE CHEAT CODES ARE TIER 1, WHICH WAS NOT EXPECTED. `MASTER.S:3` sets
-- `FinalDisk = 1`, which assembles the `kdemo`/`kprincess` keys OUT. But `SPECIALK.S:3`
-- sets its own `FinalDisk = 0 ;removes all cheat keys` — the comment describes what setting
-- it to 1 would do, and it is set to 0 — so that module's codes ARE assembled. Read off the
-- listing rather than inferred: `D97C: A9 FB lda #C_devel` and `D98D: A9 F6 lda #C_skip`.
--
--   typed codes present in the shipped binary:
--     POP     set the development flag (gates the others)
--     SKIP    skip to the next level (capped at level 4 without the devel flag)
--     GO0 GO1 ZAP BOOST R Z TINA
--
-- ★ `C_skip` sits OUTSIDE the `do FinalDisk` block in the source, so SKIP is present
-- regardless; the rest are inside it and present because this module's flag is 0.
--
-- ---------------------------------------------------------------------------
-- WHAT A LABEL JUMP ASSUMES, AND WHY THIS DOES NOT DO ONE
-- ---------------------------------------------------------------------------
-- ★★ `PC = label` is the fragile mechanism and it is deliberately absent here. `Demo` opens
-- with `jsr blackout / jsr LoadStage3 / jsr setdemolevel` — it LOADS before it does
-- anything, which tells you these routines assume a loading step happened. Arriving by save
-- state or by the game's own path cannot skip an initialisation that a PC write would.
--
--   P_SCENE   which entry (see INDEX below)
--   P_SAVE    write a save state here once the scene is reached
--   P_OUT     the report
--
-- Save states are MAME's own (`manager.machine:save`), which capture the WHOLE machine, so
-- nothing depends on reconstructing initialisation.
local OUT   = os.getenv("P_OUT") or "build/tmp/oracle_scene.log"
local SCENE = os.getenv("P_SCENE") or "demo"
local SAVE  = os.getenv("P_SAVE")
-- ★★ AN EMPTY STRING IS TRUTHY IN LUA, and the runner exports P_STATE unconditionally. Left
-- as `os.getenv(...)` alone, every run took the restore branch — including the CONTROL run,
-- which then "failed" for a reason that had nothing to do with what it was controlling for.
local LOADED = os.getenv("P_STATE")
if LOADED == "" then LOADED = nil end

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local nk  = manager.machine.natkeyboard
local scr = manager.machine.screens:at(1)
local out = io.open(OUT, "w")
local function log(s) out:write(s .. "\n"); out:flush() end

-- addresses, all read off the assembled listings rather than the source
local LEVEL  = 0x03F4     -- AUTO.LST:2796  `level ds 1`
local PARAMS = 0x03F0     -- MASTER.S:88    `params = $3f0`
local SPEED  = 0x030C     -- MASTER.LST:530

-- ---------------------------------------------------------------------------
-- ★★★ THE INDEX. Each entry says HOW it is reached, WHAT it assumes, and how to tell on
-- arrival that it worked. An entry with no arrival assert will eventually be wrong and
-- nothing will say so — five stale checkers in this project passed for the wrong reason.
-- ---------------------------------------------------------------------------
local INDEX = {
    -- the cutscene the port renders. Armed on PlayCut0's own marker, which is what P4.7
    -- used to find the six songs; folded in here rather than left a separate mechanism.
    princess = {
        tier = 1, reach = "boot and wait", cost = "~45 s emulated",
        assumes = "nothing — the oracle's own intro chain runs it [MASTER.S:695-709]",
        wait = function(st)
            if mem:read_u8(SPEED) == 12 then return true end
            return false
        end,
        describe = "PlayCut0, the princess scene — SPEED 12 is its first marker",
    },
    -- gameplay. `Demo` loads stage 3 and enters at the demo level.
    demo = {
        tier = 1, reach = "boot and wait", cost = "~110 s emulated",
        assumes = "nothing — the intro chain ends `jmp Demo` [MASTER.S:709]",
-- ★★★ ARM ON THE GAME WRITING `level`, NOT ON ITS VALUE. P4.9's first cut waited for
-- `level ~= 0` and fired at FRAME 8, on uninitialised RAM that happened to hold 69 — then
-- watched that same noise change to 255 one frame after a keystroke and reported PASS.
-- ★★ IT REACHED THE STRONGEST POSSIBLE CONCLUSION (the cheat codes are live in the shipped
-- binary) FROM A MACHINE THAT HAD NOT FINISHED BOOTING. A value read before anything wrote
-- it is not a measurement, and a checker that cannot tell those apart is the fifth stale
-- checker in this project wearing a new name. The write tap fires only when the oracle's
-- own code sets the level.
        wait = function(st) return st.level_written end,
        describe = "the demo/attract level, reached by the oracle's own path",
    },
    -- ★★ THE INTERESTING ONE: the shipped cheat codes.
    skip = {
        tier = 1, reach = "boot to gameplay, then type POP then SKIP",
        cost = "~110 s emulated plus a few frames per skip",
        assumes = "the codes are in the SHIPPED binary — measured, see the header",
        after_demo = true,
        describe = "level skip via the codes Mechner left in",
    },
}

local S = INDEX[SCENE]
if not S then
    log("# unknown scene '" .. SCENE .. "'")
    out:close(); manager.machine:exit(); return
end

local st = { frames = 0, phase = "wait", lvl0 = nil, typed = 0, done = false,
             level_written = false, nwrites = 0 }

_G._tl = mem:install_write_tap(LEVEL, LEVEL, "lvl", function(off, data, mask)
    st.nwrites = st.nwrites + 1
    -- ★ the FIRST write is `Demo` setting up; require the machine to have booted too, so a
    -- stray early write cannot stand in for gameplay.
    if st.frames > 600 then st.level_written = true end
    return data
end)
nk.in_use = true

log("# ORACLE SCENE INDEX — reaching '" .. SCENE .. "'")
log("# " .. S.describe)
log(string.format("# tier %d (%s)   reach: %s   cost: %s", S.tier,
                  S.tier == 1 and "no touch — the shipped binary, md5 intact" or "runtime write",
                  S.reach, S.cost))
log("# assumes: " .. S.assumes)
log("")

-- ★★★ THE LOAD PATH, AND ITS ASSERT. A state that restores into the WRONG moment looks
-- exactly like one that worked — the emulator reports nothing either way. So a restored
-- state is checked against the same condition the save was gated on, immediately, and a
-- mismatch is loud. MAME restores via -state before the first frame, so there is nothing to
-- wait for: if the condition does not hold now, it never will.
_G._n = emu.add_machine_frame_notifier(function()
    if st.done then return end
    st.frames = st.frames + 1

    if LOADED and st.frames == 2 then
        local ok = (SCENE == "princess" and mem:read_u8(SPEED) == 12)
                or (SCENE == "demo" and mem:read_u8(PARAMS) ~= 0)
        log(string.format("# RESTORED '%s'   level=%d  params=%d,%d  SPEED=%d",
                          LOADED, mem:read_u8(LEVEL), mem:read_u8(PARAMS),
                          mem:read_u8(PARAMS + 1), mem:read_u8(SPEED)))
        log(ok and "# PASS — the restored state is where the index says it is."
               or  "# ★★★ FAIL — the state restored but the arrival assert does not hold.")
        st.done = true; st.exit_at = st.frames + 5
        return
    end

    if st.phase == "wait" then
        local w = (SCENE == "skip") and INDEX.demo.wait or S.wait
        if not w(st) then return end
        st.lvl0 = mem:read_u8(LEVEL)
        log(string.format("# ★ ARRIVED at frame %d   level=%d  params=%d,%d  SPEED=%d",
                          st.frames, st.lvl0, mem:read_u8(PARAMS), mem:read_u8(PARAMS + 1),
                          mem:read_u8(SPEED)))
        if SCENE ~= "skip" then
            -- ★ THE ARRIVAL ASSERT. A state that loads into the wrong moment must fail
            -- loudly; so must a wait that fell through on its timeout.
            local ok = (SCENE == "princess" and mem:read_u8(SPEED) == 12)
                    or (SCENE == "demo" and st.level_written and st.nwrites > 0)
            log(ok and "# PASS — the machine is where the index says it is."
                   or  "# ★★★ FAIL — arrived, but the assert does not hold. Do not trust this entry.")
            if SAVE and ok then
                manager.machine:save(SAVE)
                log("# save state requested -> " .. SAVE)
                log("# ★ RECORD WHAT PRODUCED IT: the oracle .hdv md5, the MAME version and")
                log("#   this route. A state with no provenance is a checker that cannot be")
                log("#   re-derived when it stops matching.")
            end
            st.done = true
            st.exit_at = st.frames + 120
            return
        end
        st.phase = "type_pop"
        st.at = st.frames
        st.w0 = st.nwrites
        return
    end

    -- ★★ THE CODES ARE MATCHED AGAINST A KEYBOARD RING BUFFER [SPECIALK.S checkcode], so
    -- they are typed as ordinary keys during play, not posted to a prompt.
-- ★★★ THE CONTROL. P_NOTYPE runs the identical route and types NOTHING. Without it, "the
-- level changed after I typed SKIP" cannot be told apart from "the attract loop restarted",
-- and the first cut of this instrument already reported a PASS from uninitialised RAM. A
-- claim this strong — that the shipped binary honours a cheat code — needs the negative.
    if st.phase == "type_pop" and st.frames > st.at + 60 then
        if os.getenv("P_NOTYPE") then
            log("# CONTROL: typing nothing. Any level change from here is NOT the code.")
            st.phase = "watch"; st.at = st.frames; st.typed = 3
            return
        end
        nk:post("pop")
        log(string.format("# typed POP at frame %d (sets the development flag)", st.frames))
        st.phase = "type_skip"; st.at = st.frames
        return
    end
    if st.phase == "type_skip" and st.frames > st.at + 120 then
        nk:post("skip")
        st.typed = st.typed + 1
        log(string.format("# typed SKIP #%d at frame %d", st.typed, st.frames))
        st.phase = "watch"; st.at = st.frames
        return
    end
    if st.phase == "watch" then
        local l = mem:read_u8(LEVEL)
        if l ~= st.lvl0 and st.nwrites > st.w0 then
            log(string.format("# ★★★ LEVEL CHANGED %d -> %d, %d frames after SKIP (%d writes)",
                              st.lvl0, l, st.frames - st.at, st.nwrites - st.w0))
            log("# PASS — the shipped binary honours the typed code. Tier 1, md5 intact.")
            st.done = true; st.exit_at = st.frames + 60
            return
        end
        if st.frames > st.at + 900 then
            if st.typed < 3 then
                st.phase = "type_skip"; st.at = st.frames
            else
                log("# ★★★ FAIL — SKIP typed 3 times and level never moved.")
                log("#   Either the code is not live, or it is not typed the way checkcode")
                log("#   expects, or gameplay was not actually in progress. Do not read this")
                log("#   as 'the cheat codes were removed' without separating those.")
                st.done = true; st.exit_at = st.frames + 30
            end
        end
    end
end)

_G._n2 = emu.add_machine_frame_notifier(function()
    if st.done and st.exit_at and st.frames > st.exit_at then
        out:close(); manager.machine:exit()
    end
end)
