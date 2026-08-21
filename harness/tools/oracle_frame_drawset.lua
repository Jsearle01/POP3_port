-- oracle_frame_drawset.lua — P5.2: WHICH CELS does the oracle draw in ONE frame?
--
-- ★★★ THIS IS A DIFFERENT NUMBER FROM P5.1's RESIDENCY WINDOWS, AND THE PROJECT HAS MERGED
-- THAT PAIR TWICE. W0's 8,219 B is what must be in RAM because the controller cannot
-- intervene. This is what must be in the 15,872-byte CPU WINDOW because it is about to be
-- read by a draw. Different set, different interval.
--
-- ---------------------------------------------------------------------------
-- THE INSTRUMENT: TAP `setimage`'s OUTPUT, NOT THE IMAGE LISTS
-- ---------------------------------------------------------------------------
-- Every draw the oracle performs goes through `setimage` [HIRES.S:270]:
--
--     setimage  lda IMAGE / asl / sec / sbc #1 / tay
--               lda (TABLE),y / sta IMAGE          <- $04, the cel address LOW
--               iny / lda (TABLE),y / sta IMAGE+1  <- $05, the cel address HIGH
--
-- so a WRITE TAP ON $05 fires exactly once per cel about to be laid, and carries the
-- resolved address. `FASTLAY`, `FASTMASK` and `LAY` all call it.
--
-- ★ AND THE CEL'S OWN FIRST TWO BYTES ARE ITS WIDTH AND HEIGHT [HIRES.S:180-186], which
-- means the SIZE can be read at the tap and no table has to be identified at all. The bank
-- is already correct at that instant: FASTLAY sets `]ramrd2` to the table's bank BEFORE it
-- calls setimage, precisely so `(TABLE),y` reads the right memory.
--
-- ★★ WHY A **WRITE** TAP. On the 6502 a READ tap silently false-0s through the opcode-fetch
-- bypass [mame-idioms-apple2e-oracle.md §1]. Write taps are unaffected, and PA.6 already
-- counted cels this way (a write tap on $01/XCO binned by CURPC).
--
-- ★★ AND `mem:read_u8` IS BANK-DEPENDENT [P5.1 §3E]. That is a hazard when reading a game
-- VARIABLE, because MAIN/AUX validity is anti-correlated and you cannot tell which you got.
-- Here it is the opposite of a hazard: the bank is guaranteed correct by the caller, and
-- zero page is ALTZP-selected the same way for the tap's own address. Nothing is guessed.
--
-- ★★★ THE BIN IS A GAME FRAME, NOT A DISPLAY FRAME, AND THAT IS A 6x DIFFERENCE.
-- POP animates at ~10 fps [PA.2: 178,968 cyc per game step], so one game frame spans about
-- six 59.92 Hz display frames and a full-screen composite spans more. Binning per display
-- frame splits one draw across several bins and UNDER-REPORTS the set by up to 6x -- the
-- first cut of this instrument did exactly that and reported a 1,118 B maximum that
-- excluded every room change.
--
-- THE BOUNDARY IS `ZEROLSTS` [GRAFIX.S], WHICH WRITES `genCLS` AT `imlists` = $AC00.
-- `DoFast` and `DoSure` [TOPCTRL.S:942,961] both open with `jsr zerolsts`, so one write to
-- $AC00 = one frame's image lists being reset, and the bin that follows holds that frame's
-- list building AND its DRAWALL. Exactly the interval the window question is about.
--
-- ★ TWO BOUNDARIES REJECTED FIRST, AND WHY, SO THE NEXT READER DOES NOT RE-TRY THEM:
--   `PAGE` ($00), which `PAGEFLIP` [SUBS.S:397] writes once per game frame -- but so do
--   nine other sites, and the run produced 5,973 bins over 1,700 display frames.
--   `FrameCount` ($0306), the game's own frame counter -- but `KEEPTIME` [SPECIALK.S:1261]
--   opens `lda level / beq ]rts ;not in demo or during playback`, and THE DEMO IS LEVEL 0,
--   so it never ticks here at all. A counter that is switched off in the very mode being
--   measured is the kind of instrument that reads as "nothing happened".
--
-- SURE also writes genCLS (to 1), so a full composite emits two bins; the analysis reports
-- the single-bin maximum AND the maximum over any three consecutive bins, which bounds a
-- room change without tuning anything.
--
--   P_START  frame to begin recording at (default 1200)
--   P_AFTER  frames to record for (default 9000)
--   P_OUT    output path (default build/tmp/frame_drawset.txt)
local START = tonumber(os.getenv("P_START") or "1200")
local AFTER = tonumber(os.getenv("P_AFTER") or "9000")
local OUT   = os.getenv("P_OUT") or "build/tmp/frame_drawset.txt"

local cpu = manager.machine.devices[":maincpu"]
local mem = cpu.spaces["program"]
local scr = manager.machine.screens:at(1)
local nk  = manager.machine.natkeyboard
nk.in_use = true

local out = io.open(OUT, "w")
local function say(s) out:write(s .. "\n") end

local IMAGE, TABLE_, BANK = 0x04, 0x07, 0x12   -- EQ.S `dum $00`
local GENCLS = 0xAC00                          -- the frame boundary; see the header
local LEVEL = 0x03F4

local frames, armed, nwrites, done = 0, nil, 0, false
local seen = {}          -- key -> true, reset each frame
local line = {}          -- this frame's records

-- ARM ON THE GAME WRITING `level`, not on its value — P4.9 reported a PASS off
-- uninitialised RAM by reading one.
_G._tl = mem:install_write_tap(LEVEL, LEVEL, "lvl", function(off, data, mask)
    nwrites = nwrites + 1
    if not armed and frames > 600 then armed = frames end
    return data
end)

-- The instrument itself.
_G._ti = mem:install_write_tap(IMAGE + 1, IMAGE + 1, "img", function(off, data, mask)
    if not armed or done or frames < armed + START then return data end
    local hi = data & 0xFF
    local lo = mem:read_u8(IMAGE)
    local addr = lo | (hi << 8)
    if addr < 0x0800 then return data end          -- not a cel pointer
    local w = mem:read_u8(addr)
    local h = mem:read_u8(addr + 1)
    if w == 0 or h == 0 or w > 40 or h > 200 then return data end
    local bank = mem:read_u8(BANK)
    local tb = mem:read_u8(TABLE_) | (mem:read_u8(TABLE_ + 1) << 8)
    -- DISTINCT cels only: drawing the same cel twice costs the window nothing extra.
    local key = string.format("%d:%04X:%04X", bank, tb, addr)
    if not seen[key] then
        seen[key] = true
        line[#line + 1] = string.format("%d/%04X/%04X/%d/%d", bank, tb, addr, w, h)
    end
    return data
end)

-- THE BIN BOUNDARY. Every write to genCLS closes the accumulated set.
_G._tp = mem:install_write_tap(GENCLS, GENCLS, "gencls", function(off, data, mask)
    if not armed or done or frames < armed + START then return data end
    if #line > 0 then
        say(string.format("F %d %s", frames, table.concat(line, " ")))
    else
        say(string.format("F %d -", frames))
    end
    line = {}
    seen = {}
    return data
end)

_G._n = emu.add_machine_frame_notifier(function()
    frames = frames + 1
    if done then return end

    if armed and frames >= armed + START + AFTER then
        say("# end at frame " .. frames)
        out:close()
        done = true
        manager.machine:exit()
    end
end)
