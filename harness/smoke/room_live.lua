-- harness/smoke/room_live.lua
--
-- POP P3.17 — start the princess's room and get out of the way (Jay's 25.3 gate).
--
-- Like introseq_live.lua and for the same reasons: no framebuffer dumps (the screen
-- IS the artifact here), no MMU borrowing, no machine:exit() — the window stays open
-- until Jay closes it — and NO PASS/FAIL claim of any kind. Visual authority is Jay's
-- live MAME; this script only gets the program running on the real path.
--
-- LOADM"ROOM" + EXEC off a mounted floppy. Not a poke: P3.5 is why (the freeze, the
-- LOADM ceiling and the EXEC overwrite all lived on the real launch path and were
-- invisible to the poked one).
local OUT = os.getenv("P_OUT") or "build/room_live.log"

local scr = manager.machine.screens:at(1)
local nk = manager.machine.natkeyboard
nk.in_use = true

local log_file = io.open(OUT, "w")
local function log(s) if log_file then log_file:write(s .. "\n"); log_file:flush() end end

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local state, t0, loaded = "boot", nil, nil
local ok_before, tries = 0, 0

-- The DECB text screen, decoded. $0400 is 32x16; & 0x7F maps the video codes onto
-- readable ASCII well enough to find a word in (spaces come back as backticks, which is
-- why this searches for substrings rather than parsing).
local function screen()
    local s = {}
    for i = 0, 511 do
        local c = mem:read_u8(0x0400 + i) & 0x7F
        s[#s + 1] = (c >= 32 and c < 127) and string.char(c) or "."
    end
    return table.concat(s)
end

-- How many times DECB has said OK. One more than before a command means it has finished
-- that command and is back at the prompt.
local function ok_count()
    local n, s, i = 0, screen(), 1
    while true do
        local f = s:find("OK", i, true)
        if not f then return n end
        n, i = n + 1, f + 2
    end
end

-- Has the posted string finished being typed in? MAME drains a natkeyboard post over
-- several frames; `empty` is the emulator's own answer and is preferred to a delay. It is
-- pcall'd because the accessor is not guaranteed across MAME builds -- if it is missing we
-- fall back to a generous frame count rather than to a wrong answer.
local function kb_idle()
    local ok, v = pcall(function() return nk.empty end)
    if ok and type(v) == "boolean" then return v end
    return nil    -- unknown: the caller's frame floor decides
end

local function tick()
    local fn = scr:frame_number()
    if state == "boot" and fn >= 120 then
        nk:post('LOADM"ROOM"\n')
        log("# posted LOADM at frame " .. fn)
        state, t0 = "loadm", fn
    elseif state == "loadm" then
        -- WAIT FOR THE LOAD, THEN SETTLE — do not simply wait a long time. A blind
        -- 500-frame delay put the room on screen 15 s after launch, which is a
        -- miserable thing to watch and is why Jay saw nothing. $2000 holds
        -- `jmp room_start` once DECB has placed the image, so the load is
        -- OBSERVABLE; the settle after it is what P3.6 actually needed (EXEC was
        -- posted while DECB was still busy and the machine ate its first letter).
        if loaded == nil and mem:read_u8(0x2000) == 0x7E then
            loaded = fn
            ok_before = ok_count()
            log("# LOADM landed at frame " .. fn)
        elseif loaded ~= nil and fn > loaded + 90 then
            state, t0 = "ready", fn
        end
    elseif state == "ready" then
        -- WAIT FOR DECB TO SAY IT IS READY, rather than counting frames at it. The old
        -- code posted EXEC 90 frames after the load and Jay watched it eat the E --
        -- "the first e in exec gets eaten and causes a syntax error" -- which is the
        -- SAME failure P3.6 hit and "fixed" with this settle. A fixed delay against a
        -- race is a bet, and it had already been lost once.
        --
        -- DECB prints OK when it finishes a command, so one more OK than there was
        -- before the LOADM means the interpreter is back at the prompt and scanning the
        -- keyboard. That is observable; 90 frames was a guess.
        if ok_count() > ok_before or fn > t0 + 300 then
            nk:post('EXEC')          -- no newline yet: see below
            state, t0 = "typed", fn
        end
    elseif state == "typed" then
        -- VERIFY WHAT THE GUEST ACTUALLY RECEIVED BEFORE COMMITTING IT (idioms §14f).
        -- Typing the command and pressing Enter in one post makes a dropped character
        -- unrecoverable -- the mangled line executes and errors. Posting the text, then
        -- reading the screen back, then sending Enter only if it reads EXEC, turns a
        -- silent corruption into a retry. If it is wrong we send Enter anyway to clear
        -- the line (DECB answers ?SN ERROR) and type it again.
        -- WAIT FOR THE QUEUE TO DRAIN, NOT A GUESSED NUMBER OF FRAMES. natkeyboard
        -- delivers a posted string over many frames, so a check 12 frames later found
        -- "no XEC at all" -- nothing had arrived yet -- and the retry loop was firing on
        -- MY impatience rather than on a dropped character. That is the same mistake one
        -- level along as the 90-frame settle it replaced.
        local drained = kb_idle()
        if (drained == true or (drained == nil and fn > t0 + 45)) and fn > t0 + 8 then
            if screen():find("EXEC", 1, true) then
                nk:post('\n')
                log("# posted EXEC at frame " .. fn .. " — one track (~1.3 s), then the room")
                state = "run"
            else
                tries = tries + 1
                -- LOG WHAT THE GUEST ACTUALLY HAS, not just that it is wrong: "XEC"
                -- means a dropped character, an empty line means this check looked too
                -- early, and those want opposite fixes.
                local sc = screen()
                local at = sc:find("XEC", 1, true)
                log(string.format("# EXEC mangled (try %d) — screen has %s; clearing and retyping",
                                  tries, at and ('"' .. sc:sub(at - 1, at + 2) .. '"') or "no XEC at all"))
                nk:post('\n')
                state, t0 = "ready", fn
                ok_before = -1          -- the error message brings its own OK
                if tries > 4 then
                    log("# giving up after 4 retries — type EXEC by hand")
                    state = "run"
                end
            end
        end
    end
end

_G._notifier = emu.add_machine_frame_notifier(tick)
